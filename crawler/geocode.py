"""住所 → 緯度経度（国土地理院ジオコーディングAPI）。

- https://msearch.gsi.go.jp/address-search/AddressSearch?q=<住所>
- 無料・出典表示要。アクセスは1秒に1回以下
- 結果は crawler/.cache/geocode.json に永続キャッシュし、再問い合わせしない
- 座標が取れない場合は None を返す。推測で埋めてはいけない（SPEC 6.6）
"""

from __future__ import annotations

import json
import time
import urllib.parse
from pathlib import Path

import requests

CACHE_PATH = Path(__file__).resolve().parent / ".cache" / "geocode.json"
API = "https://msearch.gsi.go.jp/address-search/AddressSearch?q="
USER_AGENT = "LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)"
MIN_INTERVAL = 1.1


class Geocoder:
    def __init__(self, cache_path: Path = CACHE_PATH):
        self.cache_path = cache_path
        self.cache: dict[str, list[float] | None] = {}
        if cache_path.exists():
            self.cache = json.loads(cache_path.read_text(encoding="utf-8"))
        self._last_call = 0.0

    def geocode(self, address: str) -> tuple[float, float] | None:
        """住所 → (lat, lng)。キャッシュ済みの失敗も再問い合わせしない。"""
        address = address.strip()
        if not address:
            return None
        if address in self.cache:
            v = self.cache[address]
            return (v[0], v[1]) if v else None

        wait = MIN_INTERVAL - (time.monotonic() - self._last_call)
        if wait > 0:
            time.sleep(wait)
        self._last_call = time.monotonic()

        try:
            resp = requests.get(API + urllib.parse.quote(address),
                                headers={"User-Agent": USER_AGENT}, timeout=15)
            resp.raise_for_status()
            results = resp.json()
        except (requests.RequestException, ValueError):
            # 通信失敗はキャッシュしない（次回再試行できるように）
            return None

        coord = None
        if results:
            # GeoJSON: coordinates = [lng, lat]
            lng, lat = results[0]["geometry"]["coordinates"]
            coord = [lat, lng]
        self.cache[address] = coord
        self._save()
        return (coord[0], coord[1]) if coord else None

    def _save(self) -> None:
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.cache_path.write_text(
            json.dumps(self.cache, ensure_ascii=False, indent=1), encoding="utf-8")


def fill_coordinates(candidates: list, geocoder: Geocoder | None = None) -> None:
    """座標未確定の候補に住所ヒントからのジオコーディングを試みる。

    成功: coord_accuracy = "approx"。失敗: pending のまま（座標None）。
    """
    geocoder = geocoder or Geocoder()
    for c in candidates:
        if c.lat is not None and c.lng is not None:
            continue
        if not c.address_hint:
            continue
        coord = geocoder.geocode(c.address_hint)
        if coord:
            c.lat, c.lng = coord
            c.coord_accuracy = "approx"
