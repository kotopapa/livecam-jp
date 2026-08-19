"""富山県「とやま道路情報」パーサ（県管理道路カメラ約174台）。

サイトは静的JSON群で機械可読性が高い:
  https://www.toyama-douro.toyama.toyama.jp/json/camera_master.json
    → {"camera_272": {name, rosen, lat, lng, path, ...}, ...}
静止画は {BASE}{path}camimg{番号}.jpg の固定URL（10分前後で更新）。
robots.txt は404（制限なし）。利用規約の明示なし → license=unknown で人手レビュー。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.toyama-douro.toyama.toyama.jp/"
MASTER_URL = BASE + "json/camera_master.json"
KEY_RE = re.compile(r"^camera_(\d+)$")


def parse_master(raw: str) -> list[tuple[str, dict]]:
    """camera_master.json を (番号, レコード) のリストに変換する。"""
    data = json.loads(raw)
    out = []
    for key, rec in data.items():
        m = KEY_RE.match(key)
        if not m or not isinstance(rec, dict):
            continue
        out.append((m.group(1), rec))
    return sorted(out, key=lambda t: int(t[0]))


class ToyamaRoadParser(SourceParser):
    source_id = "toyama_road"
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
            result.errors.append(f"camera_master.json の形式が変わった可能性: {e}")
            return result

        for num, rec in cams:
            name = (rec.get("name") or "").strip()
            path = (rec.get("path") or "").strip()
            try:
                lat = float(rec["lat"])
                lng = float(rec["lng"])
            except (KeyError, TypeError, ValueError):
                lat = lng = None
            if not name or not path:
                continue
            rosen = (rec.get("rosen") or "").strip() or None
            result.candidates.append(CameraCandidate(
                id=f"toyama-road-{num}",
                name=name,
                category="road",
                prefecture="16",
                feed_type="still_image",
                feed_url=f"{BASE}{path}camimg{num}.jpg",
                fallback_url=BASE,
                operator="富山県",
                page_url=BASE,
                attribution="出典：富山県「とやま道路情報」",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact" if lat is not None else None,
                river_or_route=rosen,
                review_note="富山県道路カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("toyama_road: カメラが1件も取れない")
        return result
