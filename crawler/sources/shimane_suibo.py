"""島根県「水防情報システム」(www.suibou-shimane.jp) 河川カメラパーサ。

dyn/dps/json/mapData90.json の data[] に全カメラ局（id="camera.8193_90_<n>",
name, lat, lng, type="10min"）が座標付きで載る。
画像はタイムスタンプ名 /dyn/camera/<YYYYMMDD>/<HHMM>/camera_l/<obsPoint>.jpg で、
dyn/camera/camera.json({"updateTime": "...", "list": {"8193_90_27": {"updateTime":
"2026-08-29-14-40", ...}}}) が全カメラの最新時刻を返す（都度解決型
feed=shimane_suibo。1リクエストで全台解決。saitama_flood と同じ流儀）。
list には "dummy": "yyyy-MM-dd-HH-mm" のような書式サンプルも混ざるので無視する。
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.suibou-shimane.jp/"
MAP_URL = BASE + "dyn/dps/json/mapData90.json"
LATEST_URL = BASE + "dyn/camera/camera.json"
PAGE_URL = BASE + "pc/map/top.html"

# 既存台帳との重複候補（2026-08-29 照合。除外はせずレビュー注記のみ）
DUP_NOTES = {
    "8193_90_62": "kawabou-122308260「白上川 1.2K 左岸 市原」(kawabou/島根県設置)と64m。同一カメラの可能性大",
    "8193_90_53": "curated-lcdb-a422326f「ひらたCATV湯谷川美談」(YouTube)と82m。別運営者・別映像",
    "8193_90_46": "curated-r2-e54499ad「出雲大社前駅 神門通り」と85m。別運営者・別映像",
    "8193_90_25": "shimane-road-0501「佐田」(道路)と同名・約300m。道路/河川で別カメラ",
}

_TS_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})$")


def resolve_image_urls(latest_json_text: str) -> dict[str, tuple[str, str]]:
    """camera.json から {obsPoint: (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    try:
        data = json.loads(latest_json_text)
    except ValueError:
        return {}
    items = data.get("list") if isinstance(data, dict) else None
    if not isinstance(items, dict):
        return {}
    out: dict[str, tuple[str, str]] = {}
    for point, info in items.items():
        if not isinstance(info, dict):
            continue  # "dummy": "yyyy-MM-dd-HH-mm" など
        m = _TS_RE.match(str(info.get("updateTime") or ""))
        if not m:
            continue
        y, mo, d, h, mi = m.groups()
        ref = str(info.get("obsPoint") or point)
        url = f"{BASE}dyn/camera/{y}{mo}{d}/{h}{mi}/camera_l/{ref}.jpg"
        out[ref] = (url, f"{y}-{mo}-{d}T{h}:{mi}:00+09:00")
    return out


def parse_map_points(map_json_text: str) -> list[dict]:
    """mapData90.json → [{ref, name, lat, lng}]。"""
    data = json.loads(map_json_text)
    rows = data.get("data") if isinstance(data, dict) else data
    out: list[dict] = []
    for p in rows or []:
        pid = str(p.get("id") or "")
        if not pid.startswith("camera."):
            continue
        ref = pid.split(".", 1)[1]
        name = str(p.get("name") or "").strip()
        try:
            lat, lng = float(p["lat"]), float(p["lng"])
        except (KeyError, TypeError, ValueError):
            continue
        if not (ref and name):
            continue
        out.append({"ref": ref, "name": name, "lat": lat, "lng": lng})
    return out


class ShimaneSuiboParser(SourceParser):
    source_id = "shimane_suibo"
    seed_url = MAP_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MAP_URL)
        if not page.ok:
            result.errors.append(f"shimane_suibo: HTTP {page.status}")
            return result
        try:
            points = parse_map_points(page.text)
        except (ValueError, AttributeError):
            result.errors.append("shimane_suibo: mapData90.jsonを解釈できない")
            return result
        for p in points:
            ref = p["ref"]
            note = ("島根県水防情報システムの河川カメラ(10分更新)。"
                    "サイトは免責のみで転載・リンク制限なし。利用条件はレビューで確認")
            if ref in DUP_NOTES:
                note += f"。重複候補: {DUP_NOTES[ref]}"
            result.candidates.append(CameraCandidate(
                id=f"shimane-suibo-{ref.replace('_', '-')}",
                name=p["name"],
                category="river",
                prefecture="32",
                feed_type="shimane_suibo",
                feed_url=LATEST_URL,
                camera_ref=ref,
                fallback_url=PAGE_URL,
                operator="島根県",
                page_url=PAGE_URL,
                attribution="映像提供：島根県（水防情報システム）",
                license="unknown",
                refresh_sec=600,
                lat=p["lat"], lng=p["lng"], coord_accuracy="exact",
                review_note=note,
            ))
        if not result.candidates:
            result.errors.append("shimane_suibo: カメラが1件も取れない")
        return result
