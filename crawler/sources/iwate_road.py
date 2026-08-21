"""岩手県「いわて道路情報提供サービス」(douro.com) 道路カメラパーサ。

地図用XML台帳 xml/cameralist.xml に全県設置カメラの名称・正確な座標・
カメラID(<err>)が入っている(UTF-8)。静止画は camera_img/<ID>_i.php の
固定URL。cameralist2/3.xml は国交省東北地整へのリンク集(別ソースで
収録済みの系統)のため対象外。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.douro.com/"
XML_URL = BASE + "xml/cameralist.xml"
IMG_URL = BASE + "camera_img/{cid}_i.php"
PAGE_URL = BASE + "allcamera.shtml"
POINT_RE = re.compile(
    r"<point>\s*<name>([^<]+)</name>\s*<lat>([\d.]+)</lat>\s*"
    r"<lng>([\d.]+)</lng>\s*<url>[^<]*</url>\s*<err>(\w+)</err>",
    re.DOTALL)


def parse_points(xml_text: str) -> list[tuple[str, float, float, str]]:
    return [(m.group(1).strip(), float(m.group(2)), float(m.group(3)),
             m.group(4))
            for m in POINT_RE.finditer(xml_text)]


class IwateRoadParser(SourceParser):
    source_id = "iwate_road"
    seed_url = XML_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(XML_URL)
        if not page.ok:
            result.errors.append(f"iwate_road: HTTP {page.status}")
            return result
        for name, lat, lng, cid in parse_points(page.text):
            route = None
            m = re.search(r"(国道\d+号|[^ ]+線)", name)
            if m:
                route = m.group(1)
            result.candidates.append(CameraCandidate(
                id=f"iwate-road-{cid}",
                name=name,
                category="road",
                prefecture="03",
                feed_type="still_image",
                feed_url=IMG_URL.format(cid=cid),
                fallback_url=PAGE_URL,
                operator="岩手県",
                page_url=PAGE_URL,
                attribution="出典：いわて道路情報提供サービス（岩手県）",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng, coord_accuracy="exact",
                river_or_route=route,
                review_note="岩手県道路カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("iwate_road: カメラが1件も取れない")
        return result
