"""正規化・重複排除（SPEC 6.7）。

1. feed.url の完全一致 → 同一（自動マージ。先勝ち）
2. 座標50m以内 かつ 正規化名の類似度0.8以上 → 同一候補の疑いを note に併記
3. 自動マージは 1 のみ
"""

from __future__ import annotations

import math
import re
import unicodedata
from difflib import SequenceMatcher

from crawler.sources.base import CameraCandidate

_SUFFIX_RE = re.compile(r"(ライブカメラ|カメラ|映像|リアルタイム)$")
_PAREN_RE = re.compile(r"[（(].*?[）)]")


def normalize_name(name: str) -> str:
    """全角→半角、カッコ内除去、接尾辞分離、空白除去。"""
    s = unicodedata.normalize("NFKC", name)
    s = _PAREN_RE.sub("", s)
    s = re.sub(r"\s+", "", s)
    s = re.sub(r"^\d+\.", "", s)          # 「1.多摩川河口…」の連番
    s = _SUFFIX_RE.sub("", s)
    return s


def _distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    # 短距離用の簡易平面近似で十分（50m判定）
    dy = (lat1 - lat2) * 111_320
    dx = (lng1 - lng2) * 111_320 * math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot(dx, dy)


def dedupe(candidates: list[CameraCandidate]) -> list[CameraCandidate]:
    """feed.url 完全一致は自動マージ。近接・類似名は note を付けて残す。"""
    by_url: dict[str, CameraCandidate] = {}
    result: list[CameraCandidate] = []
    for c in candidates:
        key = c.feed_url.strip()
        if key in by_url:
            continue                     # 先勝ちマージ
        by_url[key] = c
        result.append(c)

    located = [c for c in result if c.lat is not None and c.lng is not None]
    for i, a in enumerate(located):
        for b in located[i + 1:]:
            if abs(a.lat - b.lat) > 0.001 or abs(a.lng - b.lng) > 0.001:
                continue                 # 粗い足切り（~100m超）
            if _distance_m(a.lat, a.lng, b.lat, b.lng) > 50:
                continue
            sim = SequenceMatcher(None, normalize_name(a.name), normalize_name(b.name)).ratio()
            if sim >= 0.8:
                note = f"重複疑い: {b.id if a is not b else ''}({b.name}) と50m以内・類似度{sim:.2f}"
                a.review_note = (a.review_note + " / " + note).strip(" /")
                note_b = f"重複疑い: {a.id}({a.name}) と50m以内・類似度{sim:.2f}"
                b.review_note = (b.review_note + " / " + note_b).strip(" /")
    return result
