"""石川県「石川みち情報ネット」パーサ（県管理道路カメラ約190台）。

Next.js SPAだが、データはJSON API（Playwrightでの通信記録により特定）:
  https://douro.pref.ishikawa.lg.jp/api/getCameraMaster
    → {"vals":[{id, route, pointName, longitude, latitude, area, ...}]}
静止画は https://douro.pref.ishikawa.lg.jp/img/camera/<id>.jpg の固定URL。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://douro.pref.ishikawa.lg.jp/"
MASTER_URL = BASE + "api/getCameraMaster"


def parse_master(raw: str) -> list[dict]:
    data = json.loads(raw)
    return data.get("vals", []) if isinstance(data, dict) else data


class IshikawaRoadParser(SourceParser):
    source_id = "ishikawa_road"
    seed_url = MASTER_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MASTER_URL)
        if not page.ok:
            result.errors.append(f"{MASTER_URL}: HTTP {page.status} {page.error or ''}")
            return result
        try:
            cams = parse_master(page.text)
        except (json.JSONDecodeError, AttributeError) as e:
            result.errors.append(f"getCameraMaster の形式が変わった可能性: {e}")
            return result

        for c in cams:
            cid = c.get("id")
            name = (c.get("pointName") or "").strip()
            if cid is None or not name:
                continue
            try:
                lat, lng = float(c["latitude"]), float(c["longitude"])
            except (KeyError, TypeError, ValueError):
                continue
            area = (c.get("area") or "").strip()
            result.candidates.append(CameraCandidate(
                id=f"ishikawa-road-{cid}",
                name=f"{name}（{area}）" if area and area not in name else name,
                category="road",
                prefecture="17",
                feed_type="still_image",
                feed_url=f"{BASE}img/camera/{cid}.jpg",
                fallback_url=BASE,
                operator="石川県",
                page_url=BASE,
                attribution="出典：石川県「石川みち情報ネット」",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact",
                river_or_route=(c.get("route") or "").strip() or None,
                review_note="石川県道路カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("ishikawa_road: カメラが1件も取れない")
        return result
