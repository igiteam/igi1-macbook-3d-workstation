"""
mobygames_client.py
A typed, rate-limited wrapper around the MobyGames v1 API.
"""
import time
import re
import unicodedata
import requests
from urllib.parse import quote
from dataclasses import dataclass, field
from typing import Optional, Iterable
from difflib import SequenceMatcher

BASE_URL = "https://api.mobygames.com/v1"

# PC-ish platform IDs (from /platforms — verify with a live call!)
PC_PLATFORMS = {
    1: "Linux",
    2: "DOS",
    3: "Windows",
    4: "PC Booter",
    5: "Windows 3.x",
    # Add more as your collection requires (e.g. Steam, Macintosh=74, etc.)
}


@dataclass
class MobyGamesClient:
    api_key: str
    requests_per_second: float = 1.0          # 1/sec on free tier
    session: requests.Session = field(default_factory=requests.Session)
    _last_request: float = 0.0

    def __post_init__(self):
        # URL-encode the key once, per the docs' warning about '+' chars
        self._encoded_key = quote(self.api_key, safe="")

    # ---------- low-level plumbing ----------

    def _throttle(self):
        min_interval = 1.0 / self.requests_per_second
        elapsed = time.monotonic() - self._last_request
        if elapsed < min_interval:
            time.sleep(min_interval - elapsed)
        self._last_request = time.monotonic()

    def _get(self, path: str, params: Optional[dict] = None) -> dict:
        self._throttle()
        params = dict(params or {})
        params["api_key"] = self._encoded_key
        url = f"{BASE_URL}{path}"

        for attempt in range(5):
            resp = self.session.get(url, params=params, timeout=30)

            if resp.status_code == 200:
                return resp.json()

            if resp.status_code == 429:
                # Back off per the Retry guidance
                wait = 2 ** attempt
                print(f"[429] Rate limited. Sleeping {wait}s...")
                time.sleep(wait)
                continue

            if resp.status_code in (400, 401, 404, 422):
                # Non-retryable; surface the API's error structure
                try:
                    err = resp.json()
                except ValueError:
                    err = {"error": resp.text}
                raise MobyGamesError(resp.status_code, err)

            resp.raise_for_status()

        raise MobyGamesError(429, {"error": "Exhausted retries on 429"})

    # ---------- endpoints ----------

    def genres(self) -> list[dict]:
        return self._get("/genres")["genres"]

    def platforms(self) -> list[dict]:
        return self._get("/platforms")["platforms"]

    def groups(self, limit: int = 100, offset: int = 0) -> list[dict]:
        return self._get("/groups", {"limit": limit, "offset": offset})["groups"]

    def search_games(
        self,
        title: Optional[str] = None,
        platform_ids: Optional[Iterable[int]] = None,
        genre_ids: Optional[Iterable[int]] = None,
        group_ids: Optional[Iterable[int]] = None,
        game_ids: Optional[Iterable[int]] = None,
        fmt: str = "brief",           # 'id' | 'brief' | 'normal'
        limit: int = 100,
        offset: int = 0,
    ) -> list:
        """
        Call /games with filters. Multi-valued params are sent by repeating
        the key, per MobyGames docs.
        """
        params: list[tuple[str, str]] = [
            ("format", fmt), ("limit", str(limit)), ("offset", str(offset))
        ]
        if title is not None:
            params.append(("title", title))
        for pid in platform_ids or []:
            params.append(("platform", str(pid)))
        for gid in genre_ids or []:
            params.append(("genre", str(gid)))
        for gid in group_ids or []:
            params.append(("group", str(gid)))
        for gid in game_ids or []:
            params.append(("id", str(gid)))

        # requests accepts list-of-tuples for repeated keys
        return self._get("/games", params)["games"]

    def game(self, game_id: int, fmt: str = "normal") -> dict:
        return self._get(f"/games/{game_id}", {"format": fmt})

    def game_platforms(self, game_id: int) -> list[dict]:
        return self._get(f"/games/{game_id}/platforms")["platforms"]

    def game_platform_details(self, game_id: int, platform_id: int) -> dict:
        return self._get(f"/games/{game_id}/platforms/{platform_id}")

    def game_covers(self, game_id: int, platform_id: int) -> list[dict]:
        """Returns flat list of cover objects (flattened from cover_groups)."""
        data = self._get(f"/games/{game_id}/platforms/{platform_id}/covers")
        out = []
        for group in data.get("cover_groups", []):
            for cover in group.get("covers", []):
                cover = dict(cover)
                cover["_countries"] = group.get("countries", [])
                cover["_group_comments"] = group.get("comments")
                out.append(cover)
        return out

    def game_screenshots(self, game_id: int, platform_id: int) -> list[dict]:
        return self._get(
            f"/games/{game_id}/platforms/{platform_id}/screenshots"
        )["screenshots"]


class MobyGamesError(Exception):
    def __init__(self, status: int, payload: dict):
        self.status = status
        self.payload = payload
        super().__init__(f"[{status}] {payload}")


# ---------------------------------------------------------------------------
# Matching helpers
# ---------------------------------------------------------------------------

_SUFFIXES = re.compile(
    r"\b(the|a|an|edition|goty|game of the year|remastered|"
    r"definitive|deluxe|complete|gold|enhanced)\b",
    re.IGNORECASE,
)

def normalize_title(s: str) -> str:
    """Aggressive normalization for fuzzy matching."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r"[™®©]", "", s)
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    s = _SUFFIXES.sub(" ", s)
    return re.sub(r"\s+", " ", s).strip()

def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize_title(a), normalize_title(b)).ratio()


@dataclass
class Match:
    query: str
    game_id: int
    title: str
    score: float
    moby_url: str


def best_match(client: MobyGamesClient, title: str, min_score: float = 0.85) -> Optional[Match]:
    """
    Search by title substring, score candidates, return the best one.
    Returns None if no candidate passes min_score.
    """
    candidates = client.search_games(title=title, fmt="brief", limit=100)
    if not candidates:
        return None

    scored = [
        Match(title, c["game_id"], c["title"], similarity(title, c["title"]), c["moby_url"])
        for c in candidates
    ]
    best = max(scored, key=lambda m: m.score)
    return best if best.score >= min_score else None
