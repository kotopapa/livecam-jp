"""福井県「みち情報ネットふくい」パーサ（県・市町管理の道路カメラ約215台）。

データは静的JSON（Playwrightでの通信記録により特定）:
  https://www.hozen.pref.fukui.lg.jp/hozen/yuki/assets/jsons/cameras.json
    → [{id, name, organize:{name}, route:{name}, address, map:{icons:[{lat,lng}]}}]
静止画は assets/images/camera/<id>.jpg の固定URL。

organize（設置者）でフィルタする:
- NEXCO中日本/西日本 → 規約で転載禁止のため除外
- 国土交通省の事務所（福井河川国道等）→ prvs(mlit_roadinfo)と重複のため除外
- 滋賀県の事務所 → 県外管理のため除外
残り＝福井県の土木事務所と県内市町のカメラのみ採用する。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.hozen.pref.fukui.lg.jp/hozen/yuki/"
CAMERAS_URL = BASE + "assets/jsons/cameras.json"

EXCLUDE_KEYWORDS = ("高速", "河川国道", "国道事務所", "滋賀県")


def is_target(organize_name: str) -> bool:
    return not any(k in organize_name for k in EXCLUDE_KEYWORDS)


def parse_cameras(raw: str) -> list[dict]:
    return json.loads(raw)


class FukuiRoadParser(SourceParser):
    source_id = "fukui_road"
    seed_url = CAMERAS_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(CAMERAS_URL)
        if not page.ok:
            result.errors.append(f"{CAMERAS_URL}: HTTP {page.status} {page.error or ''}")
            return result
        try:
            cams = parse_cameras(page.text)
        except json.JSONDecodeError as e:
            result.errors.append(f"cameras.json の形式が変わった可能性: {e}")
            return result

        for c in cams:
            cid = c.get("id")
            name = (c.get("name") or "").strip()
            org = ((c.get("organize") or {}).get("name") or "").strip()
            if cid is None or not name or not org or not is_target(org):
                continue
            icons = ((c.get("map") or {}).get("icons")) or []
            if not icons:
                continue
            try:
                lat, lng = float(icons[0]["lat"]), float(icons[0]["lng"])
            except (KeyError, TypeError, ValueError):
                continue
            address = (c.get("address") or "").strip()
            # 設置者が市町ならその名を運営者に（それ以外は福井県）
            operator = org if org.endswith(("市", "町", "村")) else "福井県"
            result.candidates.append(CameraCandidate(
                id=f"fukui-road-{cid}",
                name=f"{name}（{address}）" if address and address not in name else name,
                category="road",
                prefecture="18",
                # サイト規約「掲載されている内容の無断転載を禁じます」(2026-08-29確認)
                # のため静止画は直接参照せず、カメラ一覧ページへの誘導型にする
                feed_type="web_page",
                feed_url=BASE + "camera-list.html",
                fallback_url=BASE + "camera-list.html",
                operator=operator,
                page_url=BASE + "camera-list.html",
                attribution="出典：福井県「みち情報ネットふくい」",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact",
                river_or_route=((c.get("route") or {}).get("name") or "").strip() or None,
                review_note=f"みち情報ネットふくい（設置: {org}）。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("fukui_road: カメラが1件も取れない")
        return result
