"""さいたま市「水位情報システム」(flood-info.city.saitama.jp) 河川カメラパーサ。

ja/place.json に全観測点(名称・住所・正確な座標・camera_flg)がある。
画像はタイムスタンプ名 /camera/<3桁ID>/<YYYYMMDD>/<YYYYMMDDHHMM>.jpg で、
data/camera_latest.json({"001": "2026-08-21 19:50:00", ...})が全カメラの
最新時刻を返す（都度解決型 feed=saitama_flood。1リクエストで全台解決）。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.flood-info.city.saitama.jp/"
PLACE_URL = BASE + "ja/place.json"
LATEST_URL = BASE + "data/camera_latest.json"


def resolve_image_urls(latest_json_text: str) -> dict[str, tuple[str, str]]:
    """camera_latest.json から {3桁ID: (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    try:
        data = json.loads(latest_json_text)
    except ValueError:
        return {}
    out: dict[str, tuple[str, str]] = {}
    for cid, ts in data.items():
        # "2026-08-21 19:50:00" → 20260821 / 202608211950
        digits = ts.replace("-", "").replace(":", "").replace(" ", "")
        if len(digits) < 12:
            continue
        day, hm = digits[:8], digits[:12]
        iso = ts.replace(" ", "T") + "+09:00"
        out[cid] = (f"{BASE}camera/{cid}/{day}/{hm}.jpg", iso)
    return out


class SaitamaFloodParser(SourceParser):
    source_id = "saitama_flood"
    seed_url = PLACE_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(PLACE_URL)
        if not page.ok:
            result.errors.append(f"saitama_flood: HTTP {page.status}")
            return result
        try:
            places = json.loads(page.text)
        except ValueError:
            result.errors.append("saitama_flood: place.jsonを解釈できない")
            return result
        for p in places:
            if not p.get("camera_flg"):
                continue
            no = p.get("place_no")
            lat, lng = p.get("lat"), p.get("lng")
            name = (p.get("name") or "").strip()
            if not (no and lat and lng and name):
                continue
            cid = f"{int(no):03d}"
            result.candidates.append(CameraCandidate(
                id=f"saitama-flood-{cid}",
                name=name,
                category="river",
                prefecture="11",
                municipality="11100",
                feed_type="saitama_flood",
                feed_url=LATEST_URL,
                camera_ref=cid,
                fallback_url=BASE,
                operator="さいたま市",
                page_url=BASE,
                attribution="映像提供：さいたま市（水位情報システム）",
                license="unknown",
                refresh_sec=600,
                lat=float(lat), lng=float(lng), coord_accuracy="exact",
                address_hint=p.get("address"),
                review_note="さいたま市の河川カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("saitama_flood: カメラが1件も取れない")
        return result
