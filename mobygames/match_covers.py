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
"""
import json, os, sys
from mobygames_client import (
    MobyGamesClient, best_match, PC_PLATFORMS, MobyGamesError
)

API_KEY = os.environ["MOBY_API_KEY"]           # don't hardcode!
INPUT   = sys.argv[1] if len(sys.argv) > 1 else "games.txt"
OUTPUT  = sys.argv[2] if len(sys.argv) > 2 else "covers.jsonl"
CKPT    = OUTPUT + ".done"                      # line-count checkpoint

def load_done_count() -> int:
    if os.path.exists(CKPT):
        with open(CKPT) as f:
            return int(f.read().strip() or 0)
    return 0

def mark_done(n: int):
    with open(CKPT, "w") as f:
        f.write(str(n))

def main():
    client = MobyGamesClient(api_key=API_KEY, requests_per_second=1.0)

    with open(INPUT, encoding="utf-8") as f:
        titles = [ln.strip() for ln in f if ln.strip()]

    done = load_done_count()
    print(f"Resuming at {done}/{len(titles)}")

    with open(OUTPUT, "a", encoding="utf-8") as out:
        for i, title in enumerate(titles[done:], start=done):
            record = {"query": title, "game_id": None,
                      "matched_title": None, "score": 0.0,
                      "covers": [], "error": None}
            try:
                m = best_match(client, title, min_score=0.85)
                if m is None:
                    record["error"] = "no_match"
                else:
                    record.update(game_id=m.game_id,
                                  matched_title=m.title,
                                  score=round(m.score, 3))

                    # Pick the right platform for this game
                    plats = client.game_platforms(m.game_id)
                    pc_hits = [p for p in plats if p["platform_id"] in PC_PLATFORMS]

                    # Prefer Windows, then DOS, then others; or fetch all:
                    for p in pc_hits:
                        covers = client.game_covers(m.game_id, p["platform_id"])
                        record["covers"].append({
                            "platform_id": p["platform_id"],
                            "platform_name": p["platform_name"],
                            "first_release_date": p.get("first_release_date"),
                            "covers": covers,
                        })
            except MobyGamesError as e:
                record["error"] = f"api:{e.status}"
                print(f"[{i}] {title} -> API error {e.status}")

            out.write(json.dumps(record, ensure_ascii=False) + "\n")
            out.flush()
            mark_done(i + 1)

            if i % 100 == 0:
                print(f"[{i}/{len(titles)}] last={title!r}")

if __name__ == "__main__":
    main()
