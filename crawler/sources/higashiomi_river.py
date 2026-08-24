"""東近江市「河川監視カメラ」(higashiomi-camera.mysystems.jp) パーサ。

閲覧ページが自動更新に使う JSON API
  https://ni0zipku.user.webaccel.jp/api/json-cameralist.php
が全9台（河川6・道路アンダーパス3）の名称・河川名・住所・正確な座標・
最新画像パス(filepath)・撮影時刻(creation_time)を返す。
画像はタイムスタンプ名（命名規則はカメラごとに異なる）で固定URLがないため、
都度解決型 feed=higashiomi_river（1リクエストで全台解決）。
原寸画像は https://hhdf6nia.user.webaccel.jp/<filepath>（閲覧ページの
previewimg と同じ配信先。imageflux はサムネイル用）。
欠測時は filepath が /dummy.jpg になるので解決対象から外す。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

SITE = "https://higashiomi-camera.mysystems.jp/"
LIST_URL = "https://ni0zipku.user.webaccel.jp/api/json-cameralist.php"
IMAGE_BASE = "https://hhdf6nia.user.webaccel.jp"

CATEGORY = {"河川": "river", "道路": "road"}


def _iso(creation_time: str) -> str | None:
    # "2026-08-25 07:28:19"
    t = (creation_time or "").strip()
    if len(t) < 16:
        return None
    return t.replace(" ", "T") + ("+09:00" if len(t) >= 19 else ":00+09:00")


def resolve_image_urls(list_json_text: str) -> dict[str, tuple[str, str]]:
    """json-cameralist.php から {cameraid: (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    try:
        data = json.loads(list_json_text)
    except ValueError:
        return {}
    out: dict[str, tuple[str, str]] = {}
    for cam in data if isinstance(data, list) else []:
        ref = cam.get("cameraid")
        path = (cam.get("filepath") or "").replace("\\/", "/")
        iso = _iso(cam.get("creation_time") or "")
        if not ref or not path or not iso or path.endswith("/dummy.jpg"):
            continue
        out[ref] = (IMAGE_BASE + "/" + path.lstrip("/"), iso)
    return out


class HigashiomiRiverParser(SourceParser):
    source_id = "higashiomi_river"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(LIST_URL)
        if not page.ok:
            result.errors.append(f"higashiomi_river: HTTP {page.status}")
            return result
        try:
            cams = json.loads(page.text)
        except ValueError:
            result.errors.append("higashiomi_river: json-cameralist.phpを解釈できない")
            return result
        for cam in cams if isinstance(cams, list) else []:
            ref = (cam.get("cameraid") or "").strip()
            name = (cam.get("name") or "").strip()
            try:
                lat, lng = float(cam.get("lat")), float(cam.get("lng"))
            except (TypeError, ValueError):
                continue
            if not (ref and name):
                continue
            river = (cam.get("river") or "").strip()
            category = CATEGORY.get((cam.get("category") or "").strip(), "other")
            place = (cam.get("place") or "").strip()
            disp = f"{name}（{river}）" if river else name
            result.candidates.append(CameraCandidate(
                id=f"higashiomi-river-{ref}",
                name=disp,
                category=category,
                prefecture="25",
                municipality="25213",
                river_or_route=river or None,
                feed_type="higashiomi_river",
                feed_url=LIST_URL,
                camera_ref=ref,
                fallback_url=f"{SITE}cameradetail.php?cameraid={ref}",
                operator="東近江市（都市整備部 管理課）",
                page_url=f"{SITE}cameradetail.php?cameraid={ref}",
                attribution="映像提供：東近江市 河川監視カメラ",
                license="unknown",
                refresh_sec=300,
                lat=lat, lng=lng, coord_accuracy="exact",
                address_hint=f"滋賀県東近江市{place}" if place else None,
                review_note=("東近江市の河川監視カメラ（サイトに利用規約記載なし・レビューで確認）。"
                             f"座標はJSON APIの値。設置場所: {cam.get('address') or place}"),
            ))
        if not result.candidates:
            result.errors.append("higashiomi_river: カメラが1件も取れない")
        return result
