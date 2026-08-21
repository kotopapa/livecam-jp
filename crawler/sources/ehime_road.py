"""愛媛県「えひめの道」(pref.ehime.jp/dkanri) 道路カメラパーサ。

地点マスタ json/ehime_maps.json が {id: {name, lng, lat}} 形式（57地点・
座標つき）。静止画は json/<id>_resent_png.jpg の固定URL（同名で上書き更新）。
凍結情報システムのため一部地点は夏期 noimage になるが、URL自体は固定で
monitorのプレースホルダ/凍結検知に任せる。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.pref.ehime.jp/dkanri/"
MAPS_URL = BASE + "json/ehime_maps.json"
IMG_URL = BASE + "json/{cid}_resent_png.jpg"
PAGE_URL = BASE + "index.html"


class EhimeRoadParser(SourceParser):
    source_id = "ehime_road"
    seed_url = MAPS_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MAPS_URL)
        if not page.ok:
            result.errors.append(f"ehime_road: HTTP {page.status}")
            return result
        try:
            master = json.loads(page.text)
        except ValueError:
            result.errors.append("ehime_road: JSONを解釈できない")
            return result
        for cid, v in master.items():
            name = (v.get("name") or "").strip()
            try:
                lat, lng = float(v["lat"]), float(v["lng"])
            except (KeyError, TypeError, ValueError):
                continue
            if not name:
                continue
            route = None
            m = re.search(r"[（(]([^）)]+)[）)]?号|(国道\d+号)", name)
            m2 = re.search(r"（(国|主|一)）\s*(\d+号|[^（）]+線)", name)
            if m2:
                kind = {"国": "国道", "主": "主要地方道", "一": "一般県道"}[m2.group(1)]
                route = f"{kind}{m2.group(2)}"
            result.candidates.append(CameraCandidate(
                id=f"ehime-road-{cid.replace('_', '-')}",
                name=name,
                category="road",
                prefecture="38",
                feed_type="still_image",
                feed_url=IMG_URL.format(cid=cid),
                fallback_url=PAGE_URL,
                operator="愛媛県",
                page_url=PAGE_URL,
                attribution="出典：えひめの道ライブカメラ（愛媛県）",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng, coord_accuracy="exact",
                river_or_route=route,
                review_note="愛媛県道路カメラ（凍結情報システム）。冬期メインで夏期は"
                            "一部noimage。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("ehime_road: カメラが1件も取れない")
        return result
