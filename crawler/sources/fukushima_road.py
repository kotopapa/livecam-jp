"""福島県 会津地区道路情報パーサ（会津若松建設事務所ほか・国道峠カメラ）。

入口: 県の案内ページ https://www.pref.fukushima.lg.jp/sec/41340a/livecamera.html
実体: https://fukushima-road.net/aizu/ （Shift_JIS）。
  <li><a href="javascript:CamWin(63)">5. 三島町 宮下 （国道２５２号）</a>
の名称リストと、CamWin(id) ポップアップが表示する中サイズ静止画
  https://absv2.f-road.info/cs1/ms/cam{id:03d}m.jpg  （httpsで配信・10分更新）
を対応づける。名称に市町村が入るため address_hint でジオコーディングする。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

LIST_URL = "https://fukushima-road.net/aizu/"
PAGE_URL = "https://www.pref.fukushima.lg.jp/sec/41340a/livecamera.html"
IMG_BASE = "https://absv2.f-road.info/cs1/ms/"
NAME_RE = re.compile(
    r"CamWin\((\d+)\)[\"']?>\s*\d+\.\s*([^<]{2,60})</a>")
ROUTE_RE = re.compile(r"[（(](国道[^）)]+)[）)]")
ZEN2HAN = str.maketrans("０１２３４５６７８９", "0123456789")


def parse_cameras(html: str) -> list[dict]:
    out = []
    seen: set[str] = set()
    for cam_id, label in NAME_RE.findall(html):
        if cam_id in seen:
            continue
        seen.add(cam_id)
        label = label.strip().translate(ZEN2HAN)
        route = None
        m = ROUTE_RE.search(label)
        if m:
            route = m.group(1)
            label = ROUTE_RE.sub("", label).strip()
        out.append({"id": cam_id, "name": label, "route": route})
    return out


class FukushimaRoadParser(SourceParser):
    source_id = "fukushima_road"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(LIST_URL)
        if not page.ok:
            result.errors.append(f"{LIST_URL}: HTTP {page.status} {page.error or ''}")
            return result
        cams = parse_cameras(page.text)
        for c in cams:
            num = int(c["id"])
            result.candidates.append(CameraCandidate(
                id=f"fukushima-road-{num:03d}",
                name=c["name"],
                category="road",
                prefecture="07",
                feed_type="still_image",
                feed_url=f"{IMG_BASE}cam{num:03d}m.jpg",
                fallback_url=LIST_URL,
                operator="福島県",
                page_url=PAGE_URL,
                attribution="出典：福島県 会津地区道路情報",
                license="unknown",
                refresh_sec=600,
                river_or_route=c["route"],
                address_hint=f"福島県{c['name']}",
                review_note="福島県会津の峠カメラ。座標は地名ジオコーディング。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("fukushima_road: カメラが1件も取れない — ページ構造変化の可能性")
        return result
