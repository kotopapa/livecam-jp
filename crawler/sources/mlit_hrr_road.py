"""北陸地方整備局・金沢河川国道事務所「みちナビ石川」道路カメラパーサ。

構造（2026-08 調査）:
- カメラ台帳は `icn-assets/map.data.js` に配列直書き:
  ["A", 緯度, 経度, "map/map_NN.html", "国道8号 九折（下）", No, エリア, "Y|W"]
  管轄コード A=国交省 / B=石川県 / C=NEXCO / D=金沢市。
  本パーサは A のみ採用（B/D は自治体枠として将来 license=unknown で扱う。C は対象外）
- 座標はJS直書き（高精度）。ジオコーディング不要
- 静止画は各 map_NN.html 内の `bosai/img/{6桁}.jpg`（10分間隔更新）
- コメントアウト行（休止カメラ）は除外する
- "W" は冬期のみ稼働 → review_note に記録
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

TERMS_URL = "https://www.hrr.mlit.go.jp/help.html"
MICHINAVI_BASE = "https://www.hrr.mlit.go.jp/kanazawa/douro/michinavi/"
DATA_JS_URL = MICHINAVI_BASE + "icn-assets/map.data.js"
ROW_RE = re.compile(
    r'\["A",\s*([\d.]+),\s*([\d.]+),\s*"(map/[^"]+\.html)",\s*"([^"]+)",\s*\d+,\s*"[A-Z]+",\s*"([YW])"\]')
IMG_ID_RE = re.compile(r"bosai/img/(\d+)\.jpg")
CITY_RE = re.compile(r"[一-龥ぁ-ゟ]{1,6}[市町村]")


def parse_data_js(js: str) -> list[tuple[float, float, str, str, str]]:
    """map.data.js の国交省行(A)を (lat, lng, mapページ相対パス, 名称, Y/W) で返す。

    コメントアウトされた行（休止カメラ）は除外する。
    """
    out = []
    for line in js.splitlines():
        if line.lstrip().startswith("//"):
            continue
        for m in ROW_RE.finditer(line):
            out.append((float(m.group(1)), float(m.group(2)),
                        m.group(3), m.group(4), m.group(5)))
    return out


def extract_img_id(html: str) -> str | None:
    m = IMG_ID_RE.search(html)
    return m.group(1) if m else None


def address_hint_from_map(html: str) -> str | None:
    """mapページの <h2>（例: 国道8号 津幡町九折）から市町村ヒントを作る。"""
    m = re.search(r"<h2>([^<]+)</h2>", html)
    if not m:
        return None
    city = CITY_RE.search(re.sub(r"国道\d+号", "", m.group(1)))
    return f"石川県{city.group(0)}" if city else None


class MlitHrrRoadParser(SourceParser):
    source_id = "mlit_hrr_road"
    seed_url = MICHINAVI_BASE

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        data = session.fetch(DATA_JS_URL)
        if not data.ok:
            result.errors.append(f"map.data.js HTTP {data.status} {data.error or ''}")
            return result
        rows = parse_data_js(data.text)
        if not rows:
            result.errors.append("map.data.js から国交省行(A)が取れない — 形式が変わった可能性")
            return result

        seen: set[str] = set()
        route_re = re.compile(r"国道\d+号")
        for lat, lng, map_path, name, season in rows:
            map_url = urljoin(MICHINAVI_BASE, map_path)
            page = session.fetch(map_url)
            if not page.ok:
                result.errors.append(f"{map_url}: HTTP {page.status} {page.error or ''}")
                continue
            img_id = extract_img_id(page.text)
            if not img_id or img_id in seen:
                continue
            seen.add(img_id)
            route_m = route_re.search(name)
            notes = ["座標は みちナビ石川 のデータファイル由来"]
            if season == "W":
                notes.append("冬期のみ稼働")
            result.candidates.append(CameraCandidate(
                id=f"mlit-hrr-road-{img_id}",
                name=name,
                category="road",
                prefecture="17",
                feed_type="still_image",
                feed_url=f"https://www.hrr.mlit.go.jp/bosai/img/{img_id}.jpg",
                operator="国土交通省 金沢河川国道事務所",
                page_url=map_url,
                attribution="出典：国土交通省 北陸地方整備局 金沢河川国道事務所（みちナビ石川）",
                license="public_data_1.0",
                terms_url=TERMS_URL,
                river_or_route=route_m.group(0) if route_m else None,
                refresh_sec=600,
                lat=lat, lng=lng, coord_accuracy="exact",
                address_hint=address_hint_from_map(page.text),
                review_note=" / ".join(notes),
            ))
        if not result.candidates:
            result.errors.append("hrr: カメラが1件も取れない — ページ構造が変わった可能性")
        return result
