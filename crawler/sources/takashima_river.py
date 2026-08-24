"""高島市「河川防災カメラシステム」(bousai.city.takashima.lg.jp/cctv) 河川カメラパーサ。

/cctv/api/cameras が認証なしJSONで全5台（名称・河川名・最新画像）を返す。
画像はタイムスタンプ名 assets/cameras/<id>/pictures/<YYYY>/<MM>/<DD>/<id>_<YYYYMMDDHHMMSS>.jpg
で固定URLがないため、都度解決型 feed=takashima_river（1リクエストで全台解決）。
latestPicture.createTime("YYYYMMDDHHMM") が観測時刻。

座標はサイトに無い（地図画像上のピクセル pointX/pointY のみ）。COORDS に
国土地理院AddressSearchの地名／ロードネット滋賀の同名地点／地図画像の
ピクセル校正から求めた概略値を持つ（coord_accuracy=approx）。

注意: https は自己署名証明書のため http を使う。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "http://bousai.city.takashima.lg.jp/cctv/"
API_URL = BASE + "api/cameras"

# id -> (lat, lng, 根拠)
COORDS: dict[int, tuple[float, float, str]] = {
    1: (35.4845, 136.0473, "GSI AddressSearch「高島市マキノ町上開田」"),
    2: (35.451, 136.035, "サイト地図画像(map.png)のピクセル位置を他4点で校正した概略値"),
    3: (35.4164, 136.0064, "GSI AddressSearch「高島市今津町岸脇」"),
    4: (35.35565, 135.918962, "ロードネット滋賀の同名地点「山神橋(朽木市場)」の座標"),
    5: (35.328, 135.997, "サイト地図画像(map.png)のピクセル位置を他4点で校正した概略値"),
}


def _iso(create_time: str) -> str | None:
    digits = "".join(ch for ch in (create_time or "") if ch.isdigit())
    if len(digits) < 12:
        return None
    y, mo, d, h, mi = digits[:4], digits[4:6], digits[6:8], digits[8:10], digits[10:12]
    return f"{y}-{mo}-{d}T{h}:{mi}:00+09:00"


def resolve_image_urls(api_json_text: str) -> dict[str, tuple[str, str]]:
    """api/cameras のJSONから {camera_ref(id文字列): (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    try:
        data = json.loads(api_json_text)
    except ValueError:
        return {}
    out: dict[str, tuple[str, str]] = {}
    for cam in data if isinstance(data, list) else []:
        cid = cam.get("id")
        pic = cam.get("latestPicture") or {}
        path = (pic.get("imageFile") or "").replace("\\/", "/").lstrip("/")
        iso = _iso(pic.get("createTime") or "")
        if cid is None or not path or not iso:
            continue
        out[str(cid)] = (BASE + path, iso)
    return out


class TakashimaRiverParser(SourceParser):
    source_id = "takashima_river"
    seed_url = API_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(API_URL)
        if not page.ok:
            result.errors.append(f"takashima_river: HTTP {page.status}")
            return result
        try:
            cams = json.loads(page.text)
        except ValueError:
            result.errors.append("takashima_river: api/camerasを解釈できない")
            return result
        for cam in cams if isinstance(cams, list) else []:
            cid = cam.get("id")
            name = (cam.get("name") or "").strip()
            river = ((cam.get("river") or {}).get("name") or "").strip()
            if cid is None or not name:
                continue
            if not cam.get("distributionEnabled", 1):
                continue
            coord = COORDS.get(int(cid))
            note = "高島市の河川防災カメラ。フッターは『copyright(c) Takashima city all rights reserved』のみで利用条件はレビューで確認。"
            if coord:
                note += f" 座標根拠: {coord[2]}（サイトに座標なし）"
            result.candidates.append(CameraCandidate(
                id=f"takashima-river-{int(cid)}",
                name=f"{name}（{river}）" if river else name,
                category="river",
                prefecture="25",
                municipality="25212",
                river_or_route=river or None,
                feed_type="takashima_river",
                feed_url=API_URL,
                camera_ref=str(cid),
                fallback_url=f"{BASE}cameras/{int(cid)}",
                operator="高島市（政策部 危機管理局）",
                page_url=f"{BASE}cameras/{int(cid)}",
                attribution="映像提供：高島市 河川防災カメラシステム",
                license="unknown",
                refresh_sec=600,
                lat=coord[0] if coord else None,
                lng=coord[1] if coord else None,
                coord_accuracy="approx" if coord else None,
                address_hint=f"滋賀県高島市 {river} {name}" if river else f"滋賀県高島市 {name}",
                review_note=note,
            ))
        if not result.candidates:
            result.errors.append("takashima_river: カメラが1件も取れない")
        return result
