"""中部地方整備局・名古屋国道事務所「道路ライブカメラ」（めいこくWEB）パーサ。

構造（2026-08 調査）:
- カメラ一覧はCMSエンドポイント `/meikoku/cms/livecamera/?route=route{N}` が
  路線ごとに <li> 断片で返す（認証・JS実行不要の実質API）
- 静止画: `/meikoku/livecamera/data/{路線3桁}_{連番3桁}.jpeg`（同一URL上書き更新）
- 座標: 各路線ページ埋込の Google My Maps KML（mid をページから抽出）に
  カメラ名+静止画URL+緯度経度があり、静止画ファイル名で join できる。
  KML が取れない場合は座標なしで返し、ジオコーディングに委ねる
- 名古屋国道事務所のみ。中部地整の他事務所（静岡・岐阜国道等）は未対応
"""

from __future__ import annotations

import re

from bs4 import BeautifulSoup

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

TERMS_URL = "https://www.cbr.mlit.go.jp/policy.htm"
ROUTES = [1, 19, 22, 23, 41, 153, 155, 302]
CMS_URL = "https://www.cbr.mlit.go.jp/meikoku/cms/livecamera/?route=route{n}"
ROUTE_PAGE_URL = "https://www.cbr.mlit.go.jp/meikoku/route{n}/livecamera/"
IMG_RE = re.compile(r"livecamera/data/(\d{3})_(\d{3})\.jpe?g")
MID_RE = re.compile(r"google\.com/maps/d/[^\"']*mid=([A-Za-z0-9_-]+)")
KML_URL = "https://www.google.com/maps/d/kml?mid={mid}&forcekml=1"


def parse_cms_fragment(html: str) -> list[tuple[str, str]]:
    """CMS断片から (画像キー '001_001', カメラ名) を返す。"""
    soup = BeautifulSoup(html, "html.parser")
    out: dict[str, str] = {}
    for img in soup.find_all("img", src=True):
        m = IMG_RE.search(img["src"])
        if not m:
            continue
        key = f"{m.group(1)}_{m.group(2)}"
        cap = img.find_parent("figure")
        name = (img.get("alt") or "").strip()
        if cap and cap.find("figcaption"):
            name = cap.find("figcaption").get_text(strip=True) or name
        out.setdefault(key, name)
    return list(out.items())


def parse_kml_coords(kml: str) -> dict[str, tuple[float, float]]:
    """KMLから {画像キー: (lat, lng)} を返す。"""
    out: dict[str, tuple[float, float]] = {}
    for block in kml.split("<Placemark>")[1:]:
        img_m = IMG_RE.search(block)
        coord_m = re.search(r"<coordinates>\s*([\d.]+),([\d.]+)", block)
        if img_m and coord_m:
            key = f"{img_m.group(1)}_{img_m.group(2)}"
            lng, lat = float(coord_m.group(1)), float(coord_m.group(2))
            out[key] = (lat, lng)
    return out


class MlitCbrRoadParser(SourceParser):
    source_id = "mlit_cbr_road"
    seed_url = "https://www.cbr.mlit.go.jp/meikoku/traffic/livecamera/"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        seen: set[str] = set()
        for n in ROUTES:
            cms = session.fetch(CMS_URL.format(n=n))
            if not cms.ok:
                result.errors.append(f"route{n}: CMS HTTP {cms.status} {cms.error or ''}")
                continue
            cams = parse_cms_fragment(cms.text)
            if not cams:
                continue

            # 座標: 路線ページの My Maps KML（取れなくても続行）
            coords: dict[str, tuple[float, float]] = {}
            page_url = ROUTE_PAGE_URL.format(n=n)
            page = session.fetch(page_url)
            if page.ok:
                mid_m = MID_RE.search(page.text)
                if mid_m:
                    kml = session.fetch(KML_URL.format(mid=mid_m.group(1)))
                    if kml.ok:
                        coords = parse_kml_coords(kml.text)

            for key, name in cams:
                if key in seen or not name:
                    continue
                seen.add(key)
                latlng = coords.get(key)
                result.candidates.append(CameraCandidate(
                    id=f"mlit-cbr-road-{key.replace('_', '-')}",
                    name=name,
                    category="road",
                    prefecture="23",
                    feed_type="still_image",
                    feed_url=f"https://www.cbr.mlit.go.jp/meikoku/livecamera/data/{key}.jpeg",
                    operator="国土交通省 名古屋国道事務所",
                    page_url=page_url,
                    attribution="出典：国土交通省 中部地方整備局 名古屋国道事務所",
                    license="public_data_1.0",
                    terms_url=TERMS_URL,
                    river_or_route=f"国道{n}号",
                    refresh_sec=600,
                    lat=latlng[0] if latlng else None,
                    lng=latlng[1] if latlng else None,
                    coord_accuracy="exact" if latlng else None,
                    review_note="県は事務所管轄からの推定"
                                + ("" if latlng else " / 座標未解決（KML照合なし）"),
                ))
        if not seen:
            result.errors.append("cbr: カメラが1件も取れない — CMS構造が変わった可能性")
        return result
