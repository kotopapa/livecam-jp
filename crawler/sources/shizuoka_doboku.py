"""静岡県 土木事務所ライブカメラ統合パーサ（熱海・沼津・富士・下田の4系統）。

各サイトのトップHTMLにlightbox用の一覧が埋め込まれている:
  <a id="img1" href="numadu/01_funabara/cam_funabara.jpg" rel="lightbox"
     title="(国)１３６号　船原トンネル(東側)">(国)136号 船原</a>
静止画は固定URL。座標は無いため地点名でジオコーディングする。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

SITES = [
    ("atami", "https://izu-e.pref.shizuoka.jp/", "熱海土木事務所"),
    ("numadu", "https://snowlive.pref.shizuoka.jp/", "沼津土木事務所"),
    ("fuji", "https://fujilive.pref.shizuoka.jp/", "富士土木事務所"),
    ("shimoda", "https://izu-s.pref.shizuoka.jp/", "下田土木事務所"),
]
CAM_RE = re.compile(
    r'href="(\w+/\d+_[\w]+/cam_[\w]+\.jpg)"[^>]*title="([^"]+)">([^<]+)</a>')


def parse_site(html: str) -> list[tuple[str, str, str]]:
    """(画像相対パス, title, ラベル) のリスト。"""
    return [(m.group(1), m.group(2).strip(), m.group(3).strip())
            for m in CAM_RE.finditer(html)]


class ShizuokaDobokuParser(SourceParser):
    source_id = "shizuoka_doboku"
    seed_url = SITES[0][1]

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for area, base, office in SITES:
            page = session.fetch(base)
            if not page.ok:
                result.errors.append(f"shizuoka {area}: HTTP {page.status}")
                continue
            for path, title, label in parse_site(page.text):
                slug = re.sub(r"[^a-z0-9]+", "-",
                              path.split("/")[1].lower())
                point = label.split(" ")[-1] if " " in label else label
                route = label.split(" ")[0] if " " in label else None
                if route:
                    route = (route.replace("(国)", "国道")
                             .replace("(主)", "主要地方道")
                             .replace("(県)", "県道"))
                result.candidates.append(CameraCandidate(
                    id=f"shizuoka-doboku-{area}-{slug}",
                    name=re.sub(r"<[^>]+>", "", title).replace("　", " ").strip(),
                    category="road",
                    prefecture="22",
                    feed_type="still_image",
                    feed_url=base + path,
                    fallback_url=base,
                    operator=f"静岡県 {office}",
                    page_url=base,
                    attribution=f"出典：静岡県{office}ライブカメラ",
                    license="unknown",
                    refresh_sec=600,
                    river_or_route=route,
                    address_hint=f"静岡県{point}",
                    review_note="静岡県土木事務所の道路カメラ。利用条件はレビューで確認",
                ))
        if not result.candidates:
            result.errors.append("shizuoka_doboku: カメラが1件も取れない")
        return result
