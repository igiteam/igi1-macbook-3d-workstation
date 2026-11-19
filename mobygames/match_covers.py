"""
match_covers_json.py

Usage:
    MOBY_API_KEY=xxx python match_covers_json.py pc_games_winejs.json out.json

Input:
    pc_games_winejs.json  — array of objects: {title, url, section, page,
                            scraped, cover_url}.  cover_url is currently a
                            placeholder (pc-no-cover.png) for everything.
Output:
    out.json              — same array; on a confident MobyGames match,
                            cover_url is OVERWRITTEN with the MobyGames
                            front-cover URL.  Unmatched records keep the
                            original placeholder.  A few audit fields
                            (moby_game_id, moby_title, moby_score,
                            moby_status) are added to every record.

=============================================================================
PRACTICAL NOTES FOR YOUR 60K RUN
=============================================================================

1. VERIFY PC_PLATFORMS FIRST
   Call /v1/platforms once and grep for Windows, DOS, Linux, Macintosh,
   Steam, etc.  The IDs in mobygames_client.PC_PLATFORMS match the docs'
   sample but you should confirm them against YOUR key before the full
   run.  A wrong platform_id silently returns zero covers.

2. TWO-PHASE DESIGN IS SMARTER IF YOU'RE RATE-LIMITED
   Phase 1: resolve game_id for every title (1 call each -> ~83h at the
            free-tier 720 req/h limit).
   Phase 2: only for matched IDs, fetch platforms + covers (1-3 calls
            each).
   This script does both in one pass but writes results incrementally, so
   if you Ctrl-C mid-run you can resume from the checkpoint.

3. TITLE MATCHING CAVEATS
   Titles will contain scene tags (-GOG, (1998), [Repack]), region tags,
   and abbreviations.  clean_filename_title() strips them before query.
   rank_candidates_with_year() inspects the top-3 fuzzy candidates against
   release years to reduce false positives
   (e.g. "Doom" -> Doom 1993 vs Doom 2016).

4. COVERS COME IN GROUPS (Front Cover, Back Cover, Media).
   pick_front_cover() prefers scan_of == "Front Cover".

5. CACHE AGGRESSIVELY.
   moby_url is a perfect natural key.  Re-runs cost nothing for records
   that already have moby_status == "matched" or "no_match".

6. 429 HANDLING is baked into mobygames_client with exponential backoff.
   Do NOT raise requests_per_second above 1.0 on the free tier.

7. NO MATCH != FAILURE.
   Unmatched records keep the placeholder cover_url and get
   moby_status == "no_match", so a second looser pass or manual lookup
   can fill them in later.

=============================================================================
"""
import json
import os
import re
import sys

from mobygames_client import (
    MobyGamesClient,
    PC_PLATFORMS,
    MobyGamesError,
    similarity,
)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
API_KEY  = os.environ["MOBY_API_KEY"]
INPUT    = sys.argv[1] if len(sys.argv) > 1 else "pc_games_winejs.json"
OUTPUT   = sys.argv[2] if len(sys.argv) > 2 else "pc_games_with_covers.json"
CKPT     = OUTPUT + ".idx"

PLACEHOLDER     = "https://cdn.gitgpt.chat/rtx/images/pc-no-cover.png"
MATCH_THRESHOLD = 0.85


# ---------------------------------------------------------------------------
# Note #3: strip scene / region / re-release tags before querying.
# ---------------------------------------------------------------------------
_YEAR_TAG    = re.compile(r"\s*[\(\[](19|20)\d{2}[\)\]]")
_SCENE_TAG   = re.compile(r"\s*-\s*(GOG|Steam|Repack|RIP|CODEX|PLAZA|"
                          r"EMPRESS|SKIDROW|RELOADED)\b.*$", re.I)
_BRACKET_TAG = re.compile(r"\s*[\[\(][^\]\)]*[\]\)]\s*$")
_YEAR_IN_TITLE = re.compile(r"[\(\[]((?:19|20)\d{2})[\)\]]")

def clean_filename_title(title: str) -> str:
    t = _YEAR_TAG.sub("", title)
    t = _SCENE_TAG.sub("", t)
    t = _BRACKET_TAG.sub("", t)
    return re.sub(r"\s+", " ", t).strip()

def extract_year(title: str) -> int | None:
    m = _YEAR_IN_TITLE.search(title)
    return int(m.group(1)) if m else None


# ---------------------------------------------------------------------------
# Note #3: release-year disambiguator for the top-3 fuzzy candidates.
# ---------------------------------------------------------------------------
def _candidate_year(client: MobyGamesClient, game_id: int) -> int | None:
    try:
        plats = client.game_platforms(game_id)
    except MobyGamesError:
        return None
    years = []
    for p in plats:
        m = re.match(r"(\d{4})", p.get("first_release_date") or "")
        if m:
            years.append(int(m.group(1)))
    return min(years) if years else None

def rank_candidates_with_year(client, raw_title, candidates, top_n=3):
    if not candidates:
        return None
    scored = sorted(candidates,
                    key=lambda c: similarity(raw_title, c["title"]),
                    reverse=True)[:top_n]
    target_year = extract_year(raw_title)
    if target_year is None:
        return scored[0]

    best, best_delta = None, 10_000
    for c in scored:
        y = _candidate_year(client, c["game_id"])
        if y is None:
            continue
        d = abs(y - target_year)
        if d < best_delta:
            best, best_delta = c, d
    return best or scored[0]


# ---------------------------------------------------------------------------
# Note #4: pick the front cover.
# ---------------------------------------------------------------------------
def pick_front_cover(covers: list[dict]) -> dict | None:
    for c in covers:
        if (c.get("scan_of") or "").strip().lower() == "front cover":
            return c
    return covers[0] if covers else None


# ---------------------------------------------------------------------------
# Checkpoint helpers (note #5).
# ---------------------------------------------------------------------------
def load_ckpt() -> int:
    if os.path.exists(CKPT):
        with open(CKPT) as f:
            return int(f.read().strip() or 0)
    return 0

def save_ckpt(n: int) -> None:
    with open(CKPT, "w") as f:
        f.write(str(n))


# ---------------------------------------------------------------------------
# Per-record enrichment
# ---------------------------------------------------------------------------
def enrich(client: MobyGamesClient, item: dict) -> dict:
    """
    Return a new dict: original fields + MobyGames audit fields.
    On a confident match, item["cover_url"] is OVERWRITTEN with the
    MobyGames front-cover image URL.  Otherwise it keeps the placeholder.
    """
    out = dict(item)
    out.update(
        moby_game_id = None,
        moby_title   = None,
        moby_score   = 0.0,
        moby_status  = "no_match",
    )

    raw_title = item.get("title") or ""
    query = clean_filename_title(raw_title)
    if not query:
        return out

    try:
        candidates = client.search_games(title=query, fmt="brief", limit=100)
        chosen = rank_candidates_with_year(client, raw_title, candidates, top_n=3)

        if chosen is None or similarity(query, chosen["title"]) < MATCH_THRESHOLD:
            return out  # keeps placeholder cover_url

        out.update(
            moby_game_id = chosen["game_id"],
            moby_title   = chosen["title"],
            moby_score   = round(similarity(query, chosen["title"]), 3),
        )

        # Phase 2: fetch covers only for matched ids.
        plats = client.game_platforms(chosen["game_id"])
        pc_hits = [p for p in plats if p["platform_id"] in PC_PLATFORMS]
        for p in pc_hits:
            covers = client.game_covers(chosen["game_id"], p["platform_id"])
            front = pick_front_cover(covers)
            if front and front.get("image"):
                # NOTE: overwrite the placeholder in-place.
                out["cover_url"] = front["image"]
                out["moby_status"] = "matched"
                break  # first PC platform with a front cover wins

    except MobyGamesError as e:
        out["moby_status"] = f"api_error:{e.status}"

    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    # Note #6: never exceed 1 rps on the free tier.
    client = MobyGamesClient(api_key=API_KEY, requests_per_second=1.0)

    with open(INPUT, encoding="utf-8") as f:
        items = json.load(f)
    print(f"Loaded {len(items)} records from {INPUT}")

    # Note #1: one-time platform sanity check.
    live = {p["platform_id"]: p["platform_name"] for p in client.platforms()}
    missing = [pid for pid in PC_PLATFORMS if pid not in live]
    if missing:
        print(f"WARNING: platform_ids not seen on live API: {missing}")
    print("PC platforms:", {pid: live.get(pid, "?") for pid in PC_PLATFORMS})

    # Resume from checkpoint if present (note #5).
    done = load_ckpt()
    if done and os.path.exists(OUTPUT):
        with open(OUTPUT, encoding="utf-8") as f:
            out_items = json.load(f)
        out_items = out_items[:done]
        print(f"Resuming at record {done}/{len(items)}")
    else:
        out_items = []
        done = 0

    def flush():
        tmp = OUTPUT + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(out_items, f, ensure_ascii=False, indent=2)
        os.replace(tmp, OUTPUT)
        save_ckpt(len(out_items))

    BATCH = 25
    try:
        for i in range(done, len(items)):
            out_items.append(enrich(client, items[i]))

            if (i + 1) % BATCH == 0:
                flush()
                matched = sum(1 for x in out_items if x["moby_status"] == "matched")
                print(f"[{i+1}/{len(items)}] matched so far: {matched}")
    finally:
        flush()
        matched = sum(1 for x in out_items if x["moby_status"] == "matched")
        nomatch = sum(1 for x in out_items if x["moby_status"] == "no_match")
        errs    = sum(1 for x in out_items if x["moby_status"].startswith("api_error"))
        print(f"\nDone. matched={matched} no_match={nomatch} errors={errs}")
        print(f"Output: {OUTPUT}")


if __name__ == "__main__":
    main()
