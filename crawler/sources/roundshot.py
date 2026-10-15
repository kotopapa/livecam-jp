"""Roundshot（roundshot.com）の固定入口 → 最新画像の都度解決ヘルパー。

`https://<host>.roundshot.com/cams/<id>` は最新の日付入り画像
`https://storageN.roundshot.com/<key>/yyyy-mm-dd/hh-mm-ss/yyyy-mm-dd-hh-mm-ss_full.jpg`
へ 302 する。_full は 2.8〜5MB と重いので、同じパスの `_half.jpg`（約830KB）を配信する。

feed.type = "roundshot"、feed.url = 固定入口。monitor/main.py が入口の Location だけを取り
（リダイレクトは辿らない）、half_url() で _half.jpg に置き換えて status.json の image_url で配信する。
2026-10-15 追加（ツェルマット・ユングフラウ等の海外名峰カメラ）。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

FULL_RE = re.compile(r"(?P<d>\d{4}-\d{2}-\d{2})-(?P<t>\d{2}-\d{2}-\d{2})_full\.jpg$")


def half_url(entry_url: str, location: str | None) -> tuple[str, str] | None:
    """入口の Location から (_half.jpg の URL, 撮影時刻 'yyyy-mm-dd hh:mm:ss' ) を返す。"""
    if not location:
        return None
    url = urljoin(entry_url, location)
    m = FULL_RE.search(url)
    if not m:
        return None
    half = url[:m.start()] + f"{m.group('d')}-{m.group('t')}_half.jpg"
    return half, f"{m.group('d')} {m.group('t').replace('-', ':')}"


def resolve_image_url(session, entry_url: str, timeout: float = 30) -> tuple[str, str] | None:
    """入口へ1リクエスト（リダイレクトは辿らず本文も読まない）して最新画像URLを解決する。"""
    resp = session.head(entry_url, allow_redirects=False, timeout=timeout)
    if resp.status_code not in (301, 302, 303, 307, 308):
        return None
    return half_url(entry_url, resp.headers.get("Location"))
