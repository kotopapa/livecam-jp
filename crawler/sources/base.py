"""クローラ共通基盤。

- HttpSession: レート制限・robots.txt遵守・ETagキャッシュ付きHTTPクライアント
- CameraCandidate: パーサが返す候補レコード（cameras.json と同形、未確定項目可）
- SourceParser: 各ソースパーサのインターフェース

絶対制約（SPEC.md 2章）:
- C3: 同一ホストへのリクエスト間隔は最低1秒。ETag / If-Modified-Since を必ず使う
- C4: robots.txt を尊重する
"""

from __future__ import annotations

import hashlib
import json
import time
import urllib.robotparser
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

USER_AGENT = "LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)"
CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache" / "http"
MIN_INTERVAL_SEC = 1.0
TIMEOUT_SEC = 15


@dataclass
class FetchResult:
    url: str
    status: int | None          # None = 接続エラー
    content: bytes | None
    content_type: str
    from_cache: bool = False
    error: str | None = None

    @property
    def ok(self) -> bool:
        return self.status is not None and 200 <= self.status < 300 and self.content is not None

    @property
    def text(self) -> str:
        if self.content is None:
            return ""
        for enc in ("utf-8", "cp932", "euc-jp"):
            try:
                return self.content.decode(enc)
            except UnicodeDecodeError:
                continue
        return self.content.decode("utf-8", errors="replace")


class HttpSession:
    """礼儀正しいHTTPセッション。

    - ホストごとに最低 MIN_INTERVAL_SEC 空ける
    - robots.txt を確認し、Disallow のURLは取得せず error を返す
    - ETag / Last-Modified をディスクキャッシュし、条件付きリクエストを送る
    """

    def __init__(self, cache_dir: Path = CACHE_DIR, min_interval: float = MIN_INTERVAL_SEC):
        self.session = requests.Session()
        self.session.headers["User-Agent"] = USER_AGENT
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.min_interval = min_interval
        self._last_request_at: dict[str, float] = {}
        self._robots: dict[str, urllib.robotparser.RobotFileParser | None] = {}

    # ---- robots.txt -------------------------------------------------

    def _robots_for(self, url: str) -> urllib.robotparser.RobotFileParser | None:
        host = urlparse(url).netloc
        if host not in self._robots:
            rp = urllib.robotparser.RobotFileParser()
            robots_url = f"{urlparse(url).scheme}://{host}/robots.txt"
            try:
                self._throttle(host)
                resp = self.session.get(robots_url, timeout=TIMEOUT_SEC)
                if resp.status_code == 200:
                    rp.parse(resp.text.splitlines())
                    self._robots[host] = rp
                else:
                    # robots.txt が無い/エラー → 制限なしとみなす
                    self._robots[host] = None
            except requests.RequestException:
                self._robots[host] = None
        return self._robots[host]

    def allowed(self, url: str) -> bool:
        rp = self._robots_for(url)
        if rp is None:
            return True
        return rp.can_fetch(USER_AGENT, url)

    # ---- rate limit -------------------------------------------------

    def _throttle(self, host: str) -> None:
        last = self._last_request_at.get(host)
        if last is not None:
            wait = self.min_interval - (time.monotonic() - last)
            if wait > 0:
                time.sleep(wait)
        self._last_request_at[host] = time.monotonic()

    # ---- cache ------------------------------------------------------

    def _cache_path(self, url: str) -> Path:
        return self.cache_dir / hashlib.sha256(url.encode()).hexdigest()[:32]

    def _load_cache(self, url: str) -> dict[str, Any] | None:
        p = self._cache_path(url)
        if not p.exists():
            return None
        try:
            meta = json.loads(p.with_suffix(".meta").read_text(encoding="utf-8"))
            meta["content"] = p.read_bytes()
            return meta
        except (OSError, json.JSONDecodeError):
            return None

    def _save_cache(self, url: str, resp: requests.Response) -> None:
        p = self._cache_path(url)
        etag = resp.headers.get("ETag")
        last_modified = resp.headers.get("Last-Modified")
        if not etag and not last_modified:
            return
        p.write_bytes(resp.content)
        p.with_suffix(".meta").write_text(
            json.dumps({
                "url": url,
                "etag": etag,
                "last_modified": last_modified,
                "content_type": resp.headers.get("Content-Type", ""),
            }, ensure_ascii=False),
            encoding="utf-8",
        )

    # ---- fetch ------------------------------------------------------

    def fetch(self, url: str, use_cache: bool = True, extra_headers: dict[str, str] | None = None) -> FetchResult:
        if not self.allowed(url):
            return FetchResult(url=url, status=None, content=None, content_type="",
                               error="robots.txt disallows this URL")

        headers: dict[str, str] = dict(extra_headers or {})
        cached = self._load_cache(url) if use_cache else None
        if cached:
            if cached.get("etag"):
                headers["If-None-Match"] = cached["etag"]
            if cached.get("last_modified"):
                headers["If-Modified-Since"] = cached["last_modified"]

        host = urlparse(url).netloc
        self._throttle(host)
        try:
            resp = self.session.get(url, headers=headers, timeout=TIMEOUT_SEC)
        except requests.RequestException as e:
            return FetchResult(url=url, status=None, content=None, content_type="", error=str(e))

        if resp.status_code == 304 and cached:
            return FetchResult(url=url, status=200, content=cached["content"],
                               content_type=cached.get("content_type", ""), from_cache=True)

        if resp.status_code in (403, 429):
            # SPEC 10章: 即座にこのソースへのアクセスを停止し人に報告する
            raise RateLimitedError(url, resp.status_code)

        if use_cache and resp.ok:
            self._save_cache(url, resp)
        return FetchResult(url=url, status=resp.status_code, content=resp.content,
                           content_type=resp.headers.get("Content-Type", ""))


class RateLimitedError(Exception):
    """一次ソースが403/429を返した。SPEC 10章によりクロールを止めて人に報告する。"""

    def __init__(self, url: str, status: int):
        self.url = url
        self.status = status
        super().__init__(f"{status} from {url} — stop crawling this source and report")


# ---- candidate model ------------------------------------------------


@dataclass
class CameraCandidate:
    """cameras.json のレコードと同形の候補。lat/lng は未確定でよい。"""

    id: str
    name: str
    category: str                       # river | road | volcano | dam | coast | port | scenic | other
    prefecture: str                     # JIS X 0401 2桁
    feed_type: str                      # still_image | youtube_channel | youtube_video | hls | web_page
    feed_url: str
    operator: str
    page_url: str
    attribution: str
    license: str = "unknown"
    terms_url: str | None = None
    name_kana: str | None = None
    lat: float | None = None
    lng: float | None = None
    coord_accuracy: str | None = None
    municipality: str | None = None
    river_or_route: str | None = None
    refresh_sec: int | None = None
    requires_referer: bool = False
    headers: dict[str, str] = field(default_factory=dict)
    camera_ref: str | None = None       # 都度解決型feedのカメラ管理ID（mlit_roadinfo等）
    fallback_url: str | None = None
    address_hint: str | None = None     # geocode.py が使う住所ヒント（出力には含めない）
    review_note: str = ""
    verification: dict[str, Any] | None = None

    def to_record(self, today: str) -> dict[str, Any]:
        """candidates.json / cameras.json のレコード形式に変換する。"""
        return {
            "id": self.id,
            "name": self.name,
            "name_kana": self.name_kana,
            "lat": self.lat,
            "lng": self.lng,
            "coord_accuracy": self.coord_accuracy,
            "category": self.category,
            "prefecture": self.prefecture,
            "municipality": self.municipality,
            "river_or_route": self.river_or_route,
            "feed": {
                "type": self.feed_type,
                "url": self.feed_url,
                "refresh_sec": self.refresh_sec,
                "requires_referer": self.requires_referer,
                "headers": self.headers,
                **({"camera_ref": self.camera_ref} if self.camera_ref else {}),
            },
            "fallback": {"type": "web_page", "url": self.fallback_url or self.page_url},
            "operator": self.operator,
            "source": {
                "page_url": self.page_url,
                "terms_url": self.terms_url,
                "license": self.license,
                "attribution": self.attribution,
            },
            "review": {"status": "pending", "reviewed_at": None, "note": self.review_note},
            "verification": self.verification,
            "first_seen": today,
            "last_updated": today,
        }


@dataclass
class DiscoverResult:
    candidates: list[CameraCandidate] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


class SourceParser(ABC):
    """1機関=1パーサ。失敗しても例外を投げず、部分結果 + errors を返すこと。

    例外は RateLimitedError（即時停止が必要なもの）のみ上に投げてよい。
    """

    source_id: str = ""
    seed_url: str = ""

    @abstractmethod
    def discover(self, session: HttpSession) -> DiscoverResult:
        raise NotImplementedError


def slugify(text: str) -> str:
    """ID用スラグ。日本語はそのまま使えないのでローマ字化は行わず、
    呼び出し側が英数字の識別子（URL断片など）を渡すこと。"""
    out = []
    for ch in text.lower():
        if ch.isalnum() and ch.isascii():
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-")
