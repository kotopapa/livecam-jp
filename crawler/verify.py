"""静止画URLの2回取得検証（SPEC 6.4）。

発見したURLは必ず2回、間隔をあけて取得して検証する:
- 2回とも200が返るか
- 2回の画像ハッシュが異なるか（同じならフリーズ or 静止バナー）
- Content-Type が image/* か
- 画像サイズが極端に小さくないか（< 5KB は「準備中」画像の可能性）
"""

from __future__ import annotations

import hashlib
import time

from crawler.sources.base import CameraCandidate, HttpSession
from monitor.freeze import dhash64, is_placeholder

MIN_BYTES = 5 * 1024
DEFAULT_WAIT_SEC = 300


def _fetch_image(session: HttpSession, cand: CameraCandidate):
    headers = dict(cand.headers)
    if cand.requires_referer:
        headers.setdefault("Referer", cand.page_url)
    # 検証は「変化したか」を見るのでキャッシュ(304)は使わない
    return session.fetch(cand.feed_url, use_cache=False, extra_headers=headers)


def verify_still_images(session: HttpSession, candidates: list[CameraCandidate],
                        wait_sec: int = DEFAULT_WAIT_SEC,
                        log=print) -> None:
    """still_image 候補を検証し、cand.verification / review_note を埋める。"""
    targets = [c for c in candidates if c.feed_type == "still_image"]
    if not targets:
        return

    log(f"検証: {len(targets)}件の静止画を1回目取得...")
    first: dict[str, tuple[int | None, bytes | None, str]] = {}
    for c in targets:
        r = _fetch_image(session, c)
        first[c.id] = (r.status, r.content, r.content_type)

    log(f"検証: {wait_sec}秒待機して2回目取得...")
    time.sleep(wait_sec)

    for c in targets:
        s1, b1, ct1 = first[c.id]
        r2 = _fetch_image(session, c)
        s2, b2 = r2.status, r2.content

        ok_status = s1 == 200 and s2 == 200
        ct = ct1 or r2.content_type
        ok_type = ct.lower().startswith("image/")
        size = len(b2 or b1 or b"")
        ok_size = size >= MIN_BYTES
        changed = None
        if b1 is not None and b2 is not None:
            changed = hashlib.sha256(b1).digest() != hashlib.sha256(b2).digest()

        c.verification = {
            "fetched_twice": True,
            "image_changed": changed,
            "content_type": ct or None,
            "bytes": size or None,
        }
        problems = []
        if not ok_status:
            problems.append(f"HTTP {s1}/{s2}")
        if not ok_type:
            problems.append(f"Content-Type={ct or '不明'}")
        if not ok_size:
            problems.append(f"サイズ{size}B(<5KB, 準備中画像の可能性)")
        if changed is False:
            problems.append(f"{wait_sec}秒間隔で画像が同一(フリーズ/バナーの可能性)")
        if is_placeholder(dhash64(b2 or b1 or b"")):
            problems.append("「画像がありません」プレースホルダ(配信休止中の可能性)")
        if problems:
            note = "検証NG: " + "、".join(problems)
            c.review_note = (c.review_note + " / " + note).strip(" /")
