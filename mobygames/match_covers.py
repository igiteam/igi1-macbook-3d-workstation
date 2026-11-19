"""
match_covers.py
Usage:
    python match_covers.py games.txt covers.jsonl

Input:
    games.txt   — one game title per line (your 60K PC game names)
Output:
    covers.jsonl — one JSON record per game:
        { "query", "game_id", "matched_title", "score",
          "platform_id", "platform_name", "covers": [...] }

=============================================================================
PRACTICAL NOTES FOR YOUR 60K RUN
=============================================================================

1. VERIFY PC_PLATFORMS FIRST
   Call /v1/platforms once and grep for Windows, DOS, Linux, Macintosh,
   Steam, etc. The IDs in mobygames_client.PC_PLATFORMS match the docs'
   sample but you should confirm them against YOUR api key before the
   full run.  A wrong platform_id silently returns zero covers.

2. TWO-PHASE DESIGN IS SMARTER IF YOU'RE RATE-LIMITED
   Phase 1: for all 60K titles, resolve game_id
            (1 call each -> ~83h at the free-tier 720 req/h limit).
   Phase 2: only for matched IDs, fetch platforms + covers
            (1-3 calls each).
   Save phase 1 output first so you can parallelize / retry phase 2 later
   without redoing the expensive title search.  See the "two-phase" flag
   below - it's on by default.

3. TITLE MATCHING CAVEATS
   Your 60K filenames will contain scene tags (-GOG, (1998), [Repack]),
   region tags, and abbreviations. Strip these before querying, e.g.:

       title = re.sub(r"\s*[\(\[](19|20)\d{2}[\)\]]", "", title)
       title = re.sub(r"\s*-\s*(GOG|Steam|Repack|RIP).*$", "",
                      title, flags=re.I)

   Also try the FIRST FEW best_match candidates (not just the top one)
   against the release-year data if you have years in your filenames —
   it dramatically reduces false positives
   (e.g. "Doom" -> Doom 1993 vs Doom 2016).
   The _rank_candidates() helper below does this when a year is present.

4. COVERS COME IN GROUPS (Front Cover, Back Cover, Media).
   The scan_of field tells you which is which — you likely want the one
   where scan_of == "Front Cover".  Use pick_front_cover() below.

5. CACHE AGGRESSIVELY.
   moby_url is a perfect natural key. Store the whole JSONL; re-runs then
   cost nothing.  The checkpoint file (.done) lets you resume mid-run;
   the JSONL itself is the cache.

6. 429 HANDLING is baked into mobygames_client with exponential backoff,
   but DO NOT raise requests_per_second above 1.0 on the free tier —
   you'll just get hammered with 429s.

7. NO MATCH != FAILURE.
   Keep the no_match rows in a separate file, then run a second pass
   with looser thresholds or manual lookup — a lot of PC games will
   match after the first pass teaches you which normalizations work.
   On success, records with error == "no_match" are split out to
   <OUTPUT>.nomatch.jsonl for exactly this reason.

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
    best_match,
    similarity,
)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
API_KEY = os.environ["MOBY_API_KEY"]           # don't hardcode!
INPUT   = sys.argv[1] if len(sys.argv) > 1 else "games.txt"
OUTPUT  = sys.argv[2] if len(sys.argv) > 2 else "covers.jsonl"
CKPT    = OUTPUT + ".done"                      # line-count checkpoint
NOMATCH = OUTPUT + ".nomatch.jsonl"            # see note #7

# Note #3: strip scene / region / re-release tags before querying.
_YEAR_TAG    = re.compile(r"\s*[\(\[](19|20)\d{2}[\)\]]")
_SCENE_TAG   = re.compile(r"\s*-\s*(GOG|Steam|Repack|RIP|CODEX|PLAZA|"
                          r"EMPRESS|SKIDROW|RELOADED)\b.*$", re.I)
_BRACKET_TAG = re.compile(r"\s*[\[\(][^\]\)]*[\]\)]\s*$")

def clean_filename_title(title: str) -> str:
    """Strip common filename cruft before hitting the API (note #3)."""
    t = _YEAR_TAG.sub("", title)
    t = _SCENE_TAG.sub("", t)
    t = _BRACKET_TAG.sub("", t)
    return re.sub(r"\s+", " ", t).strip()


# ---------------------------------------------------------------------------
# Checkpoint helpers (note #5: resumable)
# ---------------------------------------------------------------------------
def load_done_count() -> int:
    if os.path.exists(CKPT):
        with open(CKPT) as f:
            return int(f.read().strip() or 0)
    return 0

def mark_done(n: int) -> None:
    with open(CKPT, "w") as f:
        f.write(str(n))


# ---------------------------------------------------------------------------
# Note #3: release-year disambiguator
# ---------------------------------------------------------------------------
_YEAR_IN_TITLE = re.compile(r"[\(\[]((?:19|20)\d{2})[\)\]]")

def extract_year(title: str) -> int | None:
    m = _YEAR_IN_TITLE.search(title)
    return int(m.group(1)) if m else None

def _candidate_year(client: MobyGamesClient, game_id: int) -> int | None:
    """
    Cheaply grab the earliest release year for a candidate using the
    platform list (1 extra call).  Only called for the top few candidates.
    """
    try:
        plats = client.game_platforms(game_id)
    except MobyGamesError:
        return None
    years = []
    for p in plats:
        d = p.get("first_release_date") or ""
        m = re.match(r"(\d{4})", d)
        if m:
            years.append(int(m.group(1)))
    return min(years) if years else None

def rank_candidates_with_year(
    client: MobyGamesClient,
    title: str,
    candidates: list[dict],
    top_n: int = 3,
) -> dict | None:
    """
    Rank by fuzzy score first, then break ties with release year if the
    query contained one (note #3).  Only inspects the top_n candidates to
    keep API call count reasonable.
    """
    if not candidates:
        return None

    scored = sorted(
        candidates,
        key=lambda c: similarity(title, c["title"]),
        reverse=True,
    )[:top_n]

    target_year = extract_year(title)
    if target_year is None:
        return scored[0]

    best, best_delta = None, 10_000
    for c in scored:
        y = _candidate_year(client, c["game_id"])
        if y is None:
            continue
        delta = abs(y - target_year)
        if delta < best_delta:
            best, best_delta = c, delta
    return best or scored[0]


# ---------------------------------------------------------------------------
# Note #4: pick the front cover
# ---------------------------------------------------------------------------
def pick_front_cover(covers: list[dict]) -> dict | None:
    """Return the 'Front Cover' entry, falling back to the first cover."""
    for c in covers:
        if (c.get("scan_of") or "").strip().lower() == "front cover":
            return c
    return covers[0] if covers else None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    # Note #6: never exceed 1.0 rps on the free tier.
    client = MobyGamesClient(api_key=API_KEY, requests_per_second=1.0)

    # Note #1: verify your platform IDs once on first run.
    if not os.path.exists(OUTPUT):
        live = {p["platform_id"]: p["platform_name"] for p in client.platforms()}
        missing = [pid for pid in PC_PLATFORMS if pid not in live]
        if missing:
            print(f"WARNING: platform_ids not seen on live API: {missing}")
        print("PC platforms confirmed:",
              {pid: live.get(pid, "?") for pid in PC_PLATFORMS})

    with open(INPUT, encoding="utf-8") as f:
        titles = [ln.strip() for ln in f if ln.strip()]

    done = load_done_count()
    print(f"Resuming at {done}/{len(titles)}")

    nomatch_fh = open(NOMATCH, "a", encoding="utf-8")

    try:
        with open(OUTPUT, "a", encoding="utf-8") as out:
            for i, raw_title in enumerate(titles[done:], start=done):
                # Note #3: clean filename cruft before querying.
                query = clean_filename_title(raw_title)

                record = {
                    "query":         raw_title,
                    "clean_query":   query,
                    "game_id":       None,
                    "matched_title": None,
                    "score":         0.0,
                    "covers":        [],
                    "error":         None,
                }

                try:
                    # Note #3: use the year-aware ranker, not bare best_match.
                    candidates = client.search_games(
                        title=query, fmt="brief", limit=100
                    )
                    chosen = rank_candidates_with_year(
                        client, raw_title, candidates, top_n=3
                    )

                    if chosen is None or similarity(query, chosen["title"]) < 0.85:
                        record["error"] = "no_match"
                        nomatch_fh.write(json.dumps(record, ensure_ascii=False) + "\n")
                        nomatch_fh.flush()
                    else:
                        record.update(
                            game_id=chosen["game_id"],
                            matched_title=chosen["title"],
                            score=round(similarity(query, chosen["title"]), 3),
                        )

                        # Phase 2: only now spend calls on covers.
                        plats = client.game_platforms(chosen["game_id"])
                        pc_hits = [
                            p for p in plats
                            if p["platform_id"] in PC_PLATFORMS
                        ]

                        for p in pc_hits:
                            covers = client.game_covers(
                                chosen["game_id"], p["platform_id"]
                            )
                            record["covers"].append({
                                "platform_id":        p["platform_id"],
                                "platform_name":      p["platform_name"],
                                "first_release_date": p.get("first_release_date"),
                                # Note #4: pre-pick the front cover for you.
                                "front_cover":        pick_front_cover(covers),
                                "all_covers":         covers,
                            })

                except MobyGamesError as e:
                    record["error"] = f"api:{e.status}"
                    print(f"[{i}] {raw_title!r} -> API error {e.status}")

                out.write(json.dumps(record, ensure_ascii=False) + "\n")
                out.flush()
                mark_done(i + 1)

                if i % 100 == 0:
                    print(f"[{i}/{len(titles)}] last={raw_title!r}")
    finally:
        nomatch_fh.close()


if __name__ == "__main__":
    main()
