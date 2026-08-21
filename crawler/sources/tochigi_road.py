"""栃木県「道路ライブカメラ」(kendo.pref.tochigi.lg.jp/roadcctv) パーサ。

PC版はASP.NET地図でスクレイプ困難だが、モバイル版 m/menu.html に
市町村グループ + 全カメラ(ID・地点名)の一覧がある(Shift_JIS)。
静止画は Portable/<3桁ID>_1.jpg の固定URL(15分更新)。
座標は無いため「栃木県+市町村+地点名」でジオコーディングする。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.kendo.pref.tochigi.lg.jp/roadcctv/"
MENU_URL = BASE + "m/menu.html"
IMG_URL = BASE + "Portable/{cid}_1.jpg"
PAGE_URL = BASE
ROW_RE = re.compile(
    r"<dt>([^<]+)</dt>|href=\"\.\./Portable/(\d+)_1\.htm\">([^<]+)<")


def parse_menu(html: str) -> list[tuple[str, str, str]]:
    """(市町村, カメラID, 地点名) のリスト。"""
    out = []
    city = None
    for m in ROW_RE.finditer(html):
        if m.group(1):
            city = m.group(1).strip()
        elif city:
            out.append((city, m.group(2), m.group(3).strip()))
    return out


def _place_hint(name: str) -> str:
    """地点名からジオコーディング用の地名部分を取り出す。"""
    s = re.sub(r"[（(][^）)]*[）)]", "", name)
    s = re.sub(r"(アンダー|トンネル|バイパス|交差点|大橋|橋)$", "", s)
    return s.strip() or name


class TochigiRoadParser(SourceParser):
    source_id = "tochigi_road"
    seed_url = MENU_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MENU_URL)
        if not page.ok:
            result.errors.append(f"tochigi_road: HTTP {page.status}")
            return result
        seen: set[str] = set()
        for city, cid, name in parse_menu(page.text):
            if cid in seen:
                continue
            seen.add(cid)
            result.candidates.append(CameraCandidate(
                id=f"tochigi-road-{cid}",
                name=f"{name}（{city}）",
                category="road",
                prefecture="09",
                feed_type="still_image",
                feed_url=IMG_URL.format(cid=cid),
                fallback_url=PAGE_URL,
                operator="栃木県",
                page_url=PAGE_URL,
                attribution="出典：栃木県道路ライブカメラ（県土整備部）",
                license="unknown",
                refresh_sec=900,
                address_hint=f"栃木県{city}{_place_hint(name)}",
                review_note="栃木県道路カメラ(アンダーパス冠水監視等)。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("tochigi_road: カメラが1件も取れない")
        return result
