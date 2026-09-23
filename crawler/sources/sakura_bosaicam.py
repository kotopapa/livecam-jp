"""佐倉市 河川等監視カメラ（都度解決型ヘルパー。画像は JSON 内の base64 のみ）。

https://bosaicam.city.sakura.lg.jp/sakura/data/wholemap.json（1分更新）の
STATIONS[] に STATION_ID / STATION_NM / CAMERA{ICON_FLG, PICT_DT, PICT_ENCODED} が入る。
PICT_ENCODED は `data:image/jpeg;base64,...`。ICON_FLG 501=正常、502=カメラ不具合
（不具合時は小さな PNG のプレースホルダが入る）。

feed.type = "sakura_bosaicam"、feed.url = wholemap.json、feed.camera_ref = STATION_ID。
monitor/main.py が1リクエストで全台を取り、mie_douro と同じく camera["_mie_bytes"] /
["_mie_time"] に入れて check.py のバイト列判定に回す。アプリは detail_screen の
_MieDouroView（sakura 形式）が同じ JSON を読んで表示する。2026-09-23 追加。
"""

from __future__ import annotations

import base64
from typing import Any

API_URL = "https://bosaicam.city.sakura.lg.jp/sakura/data/wholemap.json"


def resolve_images(payload: dict[str, Any]) -> dict[str, tuple[bytes, str]]:
    """wholemap.json → {STATION_ID: (JPEGバイト列, 撮影時刻)}。不具合（ICON_FLG≠501）や画像無しは含めない。"""
    out: dict[str, tuple[bytes, str]] = {}
    for st in (payload or {}).get("STATIONS") or []:
        if not isinstance(st, dict):
            continue
        cam = st.get("CAMERA") or {}
        sid = str(st.get("STATION_ID") or "")
        pic = str(cam.get("PICT_ENCODED") or "")
        if not sid or "base64," not in pic or str(cam.get("ICON_FLG") or "") != "501":
            continue
        try:
            raw = base64.b64decode(pic.split("base64,", 1)[1])
        except Exception:  # noqa: BLE001
            continue
        if not pic.startswith("data:image/"):
            continue
        out[sid] = (raw, str(cam.get("PICT_DT") or ""))
    return out
