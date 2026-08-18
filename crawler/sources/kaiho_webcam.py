"""海上保安庁「海の安全情報」ライブカメラパーサ（灯台・海上交通センター等の静止画）。

ハブ: https://www6.kaiho.mlit.go.jp/livecamera.html（静的リンク集・12地点）
各地点ページに静止画（../../../../gazou/<key>.jpg → www6.kaiho.mlit.go.jp/gazou/）。
座標はページに記載がないため、地点名→座標の手動対応表（NAME_COORDS）を使う。
表にない新地点は座標なしで pending に残る（推測で埋めない）。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

HUB_URL = "https://www6.kaiho.mlit.go.jp/livecamera.html"
LINK_RE = re.compile(r'<a href="([^"]+/livecamera/index\.html)"[^>]*>([^<]+)</a>')
GAZOU_RE = re.compile(r'(?:src|href)="([^"]*gazou/[A-Za-z0-9_-]+\.jpg)"')

# 地点名 → (lat, lng, カテゴリ, 都道府県)。設置施設の所在地（approx）
NAME_COORDS = {
    "観音埼レーダー施設": (35.2540, 139.7410, "coast", "14"),
    "剱埼灯台": (35.1410, 139.6760, "coast", "14"),
    "伊勢湾海上交通センター（北西）": (34.5835, 137.0170, "port", "23"),
    "伊勢湾海上交通センター（南西）": (34.5825, 137.0165, "port", "23"),
    "鳥羽海上保安部庁舎": (34.4810, 136.8430, "port", "24"),
    "大王埼灯台": (34.2780, 136.8990, "coast", "24"),
    "音戸ノ瀬戸北口": (34.1950, 132.5330, "port", "34"),
    "音戸ノ瀬戸南口１": (34.1880, 132.5350, "port", "34"),
    "音戸ノ瀬戸南口２": (34.1875, 132.5360, "port", "34"),
    "名古屋港海上交通センター（東）": (35.0495, 136.8485, "port", "23"),
    "名古屋港海上交通センター（西）": (35.0490, 136.8475, "port", "23"),
    "名古屋港ガーデンふ頭": (35.0890, 136.8820, "port", "23"),
}


class KaihoWebcamParser(SourceParser):
    source_id = "kaiho_webcam"
    seed_url = HUB_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        hub = session.fetch(HUB_URL)
        if not hub.ok:
            result.errors.append(f"hub HTTP {hub.status} {hub.error or ''}")
            return result
        links = [(u, t.strip()) for u, t in LINK_RE.findall(hub.text)]
        if not links:
            result.errors.append("地点リンクが取れない — ページ構造が変わった可能性")
            return result

        seen: set[str] = set()
        for url, name in links:
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                continue
            m = GAZOU_RE.search(page.text)
            if not m:
                continue
            img_url = urljoin(url, m.group(1))
            key = re.sub(r"[^a-z0-9]+", "-",
                         img_url.rsplit("/", 1)[-1].removesuffix(".jpg").lower()).strip("-")
            if not key or key in seen:
                continue
            seen.add(key)
            coords = NAME_COORDS.get(name)
            result.candidates.append(CameraCandidate(
                id=f"kaiho-{key}",
                name=name,
                category=coords[2] if coords else "coast",
                prefecture=coords[3] if coords else "00",
                feed_type="still_image",
                feed_url=img_url,
                fallback_url=url,
                operator="海上保安庁",
                page_url=url,
                attribution="出典：海上保安庁「海の安全情報」",
                license="unknown",
                refresh_sec=600,
                lat=coords[0] if coords else None,
                lng=coords[1] if coords else None,
                coord_accuracy="approx" if coords else None,
                review_note="灯台・海上交通センターのカメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("kaiho: カメラが1件も取れない")
        return result
