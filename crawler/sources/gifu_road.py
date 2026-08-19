"""岐阜県「道の情報」パーサ（県管理道路カメラ約350地点）。

Next.js SPAだが、データはJSON API（Playwrightでの通信記録により特定）:
  https://douro.pref.gifu.lg.jp/api/getCameraMaster → 地点マスタ（座標つき）
  https://douro.pref.gifu.lg.jp/api/getCamera       → 地点ID→画像ファイル対応
静止画は img/camera/douro_XXX_YYYY.jpg の固定URL（地点により複数方面あり、
先頭の1枚を採用する）。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://douro.pref.gifu.lg.jp/"
MASTER_URL = BASE + "api/getCameraMaster"
CAMERA_URL = BASE + "api/getCamera"


def parse_vals(raw: str) -> list[dict]:
    data = json.loads(raw)
    return data.get("vals", []) if isinstance(data, dict) else data


def image_map(camera_vals: list[dict]) -> dict[int, str]:
    """getCamera の応答から 地点id→先頭画像パス を作る。"""
    out: dict[int, str] = {}
    for c in camera_vals:
        imgs = c.get("cameraImg")
        if isinstance(imgs, list) and imgs:
            img = imgs[0].get("img")
            if img:
                out[c["id"]] = img
        elif isinstance(imgs, str) and imgs:
            out[c["id"]] = imgs
    return out


class GifuRoadParser(SourceParser):
    source_id = "gifu_road"
    seed_url = MASTER_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        master = session.fetch(MASTER_URL)
        camera = session.fetch(CAMERA_URL)
        if not master.ok or not camera.ok:
            result.errors.append(
                f"gifu API取得失敗 master={master.status} camera={camera.status}")
            return result
        try:
            cams = parse_vals(master.text)
            imgs = image_map(parse_vals(camera.text))
        except (json.JSONDecodeError, KeyError, AttributeError) as e:
            result.errors.append(f"gifu APIの形式が変わった可能性: {e}")
            return result

        for c in cams:
            cid = c.get("id")
            name = (c.get("pointName") or "").strip()
            img = imgs.get(cid)
            if cid is None or not name or not img:
                continue
            try:
                lat, lng = float(c["latitude"]), float(c["longitude"])
            except (KeyError, TypeError, ValueError):
                continue
            result.candidates.append(CameraCandidate(
                id=f"gifu-road-{cid}",
                name=name,
                category="road",
                prefecture="21",
                feed_type="still_image",
                feed_url=BASE + img.lstrip("/"),
                fallback_url=BASE,
                operator="岐阜県",
                page_url=BASE,
                attribution="出典：岐阜県「道の情報」",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact",
                river_or_route=(c.get("route") or "").strip() or None,
                review_note=f"岐阜県道路カメラ（{c.get('office') or ''}）。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("gifu_road: カメラが1件も取れない")
        return result
