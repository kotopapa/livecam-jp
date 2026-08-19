"""広島県「ひろしま道路ナビ」パーサ（県管理道路カメラ150台前後）。

一覧: https://www.roadnavi.pref.hiroshima.lg.jp/camera_list.php （全域）
各カメラは table.inner_table 単位で、
  <td class="rosenname">（主）矢野安浦線<BR/>中畑</td>
  <img src="snow_pic/131.jpg?timestamp=...">
  <td class="titen">呉市安浦町大字中畑</td>
静止画は snow_pic/<ID>.jpg の固定URL（10分更新）。robots.txt は404（制限なし）。
座標はサイトに無いため titen（住所）を address_hint にしてジオコーディングする。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.roadnavi.pref.hiroshima.lg.jp/"
LIST_URL = BASE + "camera_list.php"
BLOCK_RE = re.compile(
    r'class="rosenname">(?P<rosen>[^<]*)<BR\s*/?>(?P<point>[^<]*)</td>.*?'
    r'snow_pic/(?P<id>\d+)\.jpg.*?'
    r'class="titen">(?P<titen>[^<]*)</td>',
    re.DOTALL | re.IGNORECASE)


def parse_list(html: str) -> list[dict]:
    out = []
    seen: set[str] = set()
    for m in BLOCK_RE.finditer(html):
        cam_id = m.group("id")
        if cam_id in seen:
            continue
        seen.add(cam_id)
        out.append({
            "id": cam_id,
            "rosen": m.group("rosen").strip(),
            "point": m.group("point").strip(),
            "titen": m.group("titen").strip(),
        })
    return out


class HiroshimaRoadParser(SourceParser):
    source_id = "hiroshima_road"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(LIST_URL)
        if not page.ok:
            result.errors.append(f"{LIST_URL}: HTTP {page.status} {page.error or ''}")
            return result
        cams = parse_list(page.text)
        for c in cams:
            point = c["point"] or c["titen"]
            if not point:
                continue
            result.candidates.append(CameraCandidate(
                id=f"hiroshima-road-{c['id']}",
                name=point,
                category="road",
                prefecture="34",
                feed_type="still_image",
                feed_url=f"{BASE}snow_pic/{c['id']}.jpg",
                fallback_url=LIST_URL,
                operator="広島県",
                page_url=LIST_URL,
                attribution="出典：広島県「ひろしま道路ナビ」",
                license="unknown",
                refresh_sec=600,
                river_or_route=c["rosen"] or None,
                address_hint=f"広島県{c['titen']}" if c["titen"] else None,
                review_note="広島県道路カメラ。座標は住所ジオコーディング。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("hiroshima_road: カメラが1件も取れない — ページ構造変化の可能性")
        return result
