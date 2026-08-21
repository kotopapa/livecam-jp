"""気象庁 火山監視カメラパーサ。

一覧は volcam ページの地図用GeoJSON（camicon.geojson）に全カメラの
正確な座標とVCコードが入っている。画像は2分間隔のタイムスタンプ付きURL
（固定URLなし）のため feed.type=jma_volcam（都度解決型）とし、monitorが
カメラページ（volcam.php?VC=<code>）から最新URLを解決して status.json の
image_url で配信する（mlit_roadinfo と同じ方式）。

都道府県・市区町村は国土地理院の逆ジオコーダで座標から求める。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.data.jma.go.jp/vois/data/obs/volcam/"
GEOJSON_URL = BASE + "param/geojson/camicon.geojson"
PAGE_URL = BASE + "volcam.php?VC={code}"
IMG_RE = re.compile(r"\.\./camera/([\w]+)/(\d{14})\.jpg")
REVGEO_URL = ("https://mreversegeocoder.gsi.go.jp/reverse-geocoder/"
              "LonLatToAddress?lat={lat}&lon={lon}")


def resolve_image_url(page_html: str) -> tuple[str, str] | None:
    """カメラページから (最新画像URL, 取得時刻ISO) を返す（monitor用）。"""
    hits = IMG_RE.findall(page_html)
    if not hits:
        return None
    directory, ts = max(hits, key=lambda h: h[1])
    iso = (f"{ts[0:4]}-{ts[4:6]}-{ts[6:8]}T"
           f"{ts[8:10]}:{ts[10:12]}:{ts[12:14]}+09:00")
    return (f"https://www.data.jma.go.jp/vois/data/obs/camera/"
            f"{directory}/{ts}.jpg", iso)


def _reverse_geocode(session: HttpSession, lat: float,
                     lng: float) -> str | None:
    """座標→市区町村JISコード（5桁）。山頂等で取れない場合はNone"""
    for dlat, dlng in ((0, 0), (0.02, 0), (-0.02, 0), (0, 0.02), (0, -0.02)):
        page = session.fetch(REVGEO_URL.format(lat=lat + dlat, lon=lng + dlng))
        if not page.ok:
            continue
        try:
            muni = json.loads(page.text).get("results", {}).get("muniCd")
        except ValueError:
            continue
        if muni:
            return muni
    return None


class JmaVolcamParser(SourceParser):
    source_id = "jma_volcam"
    seed_url = GEOJSON_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(GEOJSON_URL)
        if not page.ok:
            result.errors.append(f"jma_volcam: HTTP {page.status}")
            return result
        try:
            features = json.loads(page.text).get("features", [])
        except ValueError:
            result.errors.append("jma_volcam: GeoJSONを解釈できない")
            return result
        for f in features:
            props = f.get("properties") or {}
            code = props.get("code")
            name = (props.get("name") or "").strip()
            coords = (f.get("geometry") or {}).get("coordinates") or []
            if not code or not name or len(coords) != 2:
                continue
            lng, lat = float(coords[0]), float(coords[1])
            muni = _reverse_geocode(session, lat, lng)
            pref = muni[:2] if muni else None
            if pref is None:
                result.errors.append(f"jma_volcam {code}: 逆ジオコーディング失敗")
                continue
            result.candidates.append(CameraCandidate(
                id=f"jma-volcam-{code}",
                name=f"{name}（火山監視カメラ）",
                category="volcano",
                prefecture=pref,
                municipality=muni,
                feed_type="jma_volcam",
                feed_url=str(code),
                fallback_url=PAGE_URL.format(code=code),
                operator="気象庁",
                page_url=PAGE_URL.format(code=code),
                attribution="出典：気象庁ホームページ（監視カメラ画像）",
                license="gov_std_2.0",
                refresh_sec=120,
                lat=lat, lng=lng, coord_accuracy="exact",
                review_note="気象庁の火山監視カメラ。政府標準利用規約（出典明記で利用可）",
            ))
        if not result.candidates:
            result.errors.append("jma_volcam: カメラが1件も取れない")
        return result
