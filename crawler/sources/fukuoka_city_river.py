"""福岡市「防災気象情報」(bousai.city.fukuoka.lg.jp) 河川カメラパーサ。

トップページに全観測点のGeoJSON(変数 sampledata)が埋め込まれており、
_className=="camera" のフィーチャーに名称・住所・正確な座標・
固定画像URL(https://bousai.city.fukuoka.lg.jp/<cID>/moboImage.jpg)が入っている。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

TOP_URL = "https://bousai.city.fukuoka.lg.jp/"
NAME_RE = re.compile(
    r"([^<]+)<br><img src='(https://bousai\.city\.fukuoka\.lg\.jp/"
    r"(c\d+)/moboImage\.jpg)'")
ADDR_RE = re.compile(r"住所：([^<]+)")


def extract_geojson(html: str) -> dict | None:
    """埋め込み `sampledata ={...}` を括弧対応スキャンで取り出す。"""
    i = html.find("sampledata")
    if i < 0:
        return None
    i = html.find("{", i)
    depth, in_str, esc = 0, False, False
    for j in range(i, len(html)):
        ch = html[j]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(html[i:j + 1])
                except ValueError:
                    return None
    return None


class FukuokaCityRiverParser(SourceParser):
    source_id = "fukuoka_city_river"
    seed_url = TOP_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(TOP_URL)
        if not page.ok:
            result.errors.append(f"fukuoka_city_river: HTTP {page.status}")
            return result
        data = extract_geojson(page.text)
        if not data:
            result.errors.append("fukuoka_city_river: sampledataが取れない")
            return result
        for f in data.get("features", []):
            p = f.get("properties") or {}
            if p.get("_className") != "camera":
                continue
            m = NAME_RE.match(p.get("name", ""))
            if not m:
                continue
            addr = ADDR_RE.search(p.get("name", ""))
            coords = (f.get("geometry") or {}).get("coordinates") or []
            if len(coords) != 2:
                continue
            lng, lat = float(coords[0]), float(coords[1])
            result.candidates.append(CameraCandidate(
                id=f"fukuoka-city-{m.group(3)}",
                name=m.group(1).strip(),
                category="river",
                prefecture="40",
                feed_type="still_image",
                feed_url=m.group(2),
                fallback_url=TOP_URL,
                operator="福岡市",
                page_url=TOP_URL,
                attribution="映像提供：福岡市（防災気象情報）",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng, coord_accuracy="exact",
                address_hint=addr.group(1).strip() if addr else None,
                review_note="福岡市の河川カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("fukuoka_city_river: カメラが1件も取れない")
        return result
