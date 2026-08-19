"""宮城県「道路管理ライブカメラ」パーサ（北部・大河原西部/東部の3地域）。

サイトはHTTP専用（httpsは接続不可）。地域ページのサムネイル一覧
  <li><a href="nabe.html"><p>国道347号 鍋越峠</p><img src="img/nabe.jpg">
の img がそのままライブ静止画（詳細ページも同じ画像を参照）。
座標は無いため地点名を address_hint にしてジオコーディングする。
※HTTP配信のため iOS では ATS 例外（roadgis.pref.miyagi.jp）を設定済み。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "http://roadgis.pref.miyagi.jp/roadgis/"
REGIONS = ["hokubu", "seibu", "tobu"]
ITEM_RE = re.compile(
    r'<a[^>]+href="(\w+)\.html"[^>]*>\s*<p>([^<]+)</p>\s*<img[^>]+src="(img/\w+\.jpg)"')


def parse_region(html: str) -> list[tuple[str, str, str]]:
    return [(m.group(1), m.group(2).strip(), m.group(3))
            for m in ITEM_RE.finditer(html)]


class MiyagiRoadParser(SourceParser):
    source_id = "miyagi_road"
    seed_url = BASE + "index.html"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for region in REGIONS:
            page = session.fetch(f"{BASE}{region}/index.html")
            if not page.ok:
                result.errors.append(f"miyagi {region}: HTTP {page.status}")
                continue
            for slug, name, img in parse_region(page.text):
                point = re.sub(r"^(国道|県道|主要地方道)[^ ]* ", "", name)
                result.candidates.append(CameraCandidate(
                    id=f"miyagi-road-{region}-{slug}",
                    name=name,
                    category="road",
                    prefecture="04",
                    feed_type="still_image",
                    feed_url=f"{BASE}{region}/{img}",
                    fallback_url=f"{BASE}{region}/index.html",
                    operator="宮城県",
                    page_url=f"{BASE}{region}/index.html",
                    attribution="出典：宮城県道路管理ライブカメラ",
                    license="unknown",
                    refresh_sec=600,
                    river_or_route=(name.split(" ")[0]
                                    if name.startswith(("国道", "県道")) else None),
                    address_hint=f"宮城県{point}",
                    review_note="宮城県道路カメラ(HTTP配信)。利用条件はレビューで確認",
                ))
        if not result.candidates:
            result.errors.append("miyagi_road: カメラが1件も取れない")
        return result
