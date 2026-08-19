"""島根県「道路カメラ情報」パーサ（県管理道路カメラ約100台）。

サイトはNext.js SPAだが、カメラ台帳は静的配信の JSON5:
  https://www.roadi.pref.shimane.jp/data/point.json5
    → [{point_id:'0101', name:'大川端', route:'松江木次線',
        location:'松江市東忌部町', lat:35.37, lng:133.03, camera_stat:0}, ...]
静止画は https://www.roadi.pref.shimane.jp/data/snapshot/<point_id>.jpg。
camera_stat: 0=稼働, 1=メンテ, 2=カメラなし（アプリJSの分岐から判明）。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.roadi.pref.shimane.jp/"
MASTER_URL = BASE + "data/point.json5"


def json5_to_json(text: str) -> str:
    """このサイトのJSON5方言（無引用キー・単引用文字列）を標準JSONへ変換する。"""
    text = re.sub(r"([,{[]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:", r'\1"\2":', text)
    text = text.replace("'", '"')
    text = re.sub(r",\s*([}\]])", r"\1", text)  # 末尾カンマ
    return text


def parse_points(raw: str) -> list[dict]:
    return json.loads(json5_to_json(raw))


class ShimaneRoadParser(SourceParser):
    source_id = "shimane_road"
    seed_url = MASTER_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MASTER_URL)
        if not page.ok:
            result.errors.append(f"{MASTER_URL}: HTTP {page.status} {page.error or ''}")
            return result
        try:
            points = parse_points(page.text)
        except (json.JSONDecodeError, ValueError) as e:
            result.errors.append(f"point.json5 の形式が変わった可能性: {e}")
            return result

        for p in points:
            pid = str(p.get("point_id") or "")
            name = str(p.get("name") or "").strip()
            if not pid or not name:
                continue
            if p.get("camera_stat") == 2:  # カメラ未設置地点
                continue
            try:
                lat, lng = float(p["lat"]), float(p["lng"])
            except (KeyError, TypeError, ValueError):
                lat = lng = None
            location = str(p.get("location") or "").strip()
            display = f"{name}（{location}）" if location and location not in name else name
            result.candidates.append(CameraCandidate(
                id=f"shimane-road-{pid}",
                name=display,
                category="road",
                prefecture="32",
                feed_type="still_image",
                feed_url=f"{BASE}data/snapshot/{pid}.jpg",
                fallback_url=BASE,
                operator="島根県",
                page_url=BASE,
                attribution="出典：島根県「道路カメラ情報」",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact" if lat is not None else None,
                river_or_route=str(p.get("route") or "").strip() or None,
                review_note="島根県道路カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("shimane_road: カメラが1件も取れない")
        return result
