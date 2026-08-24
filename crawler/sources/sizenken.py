"""環境省インターネット自然研究所（sizenken.biodic.go.jp）のライブカメラ（都度解決型ヘルパー）。

https://www.sizenken.biodic.go.jp/view_new.php?no=<番号> のHTMLに、最新画像として
camera_img/<番号>_c/image/<YYYY>/<MM>/<DD>/NCS<YYYYMMDDHHMMSS><ms>.jpg が埋め込まれる。
日付・時刻がURLに含まれるため固定URLが存在しない。

feed.type = "sizenken"、feed.url = 上記viewページURL。
monitor/main.py がページを取得して resolve_image_url() で最新URLを解決し、
status.json の image_url で配信する（kochi_suibo と同じ流儀）。

discoveryパーサではないため REGISTRY には登録しない。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

IMG_RE = re.compile(
    r'(camera_img/\d+_c/image/\d{4}/\d{2}/\d{2}/NCS(\d{14})\d*\.jpg)')


def resolve_image_url(page_url: str, html: str) -> tuple[str, str] | None:
    """viewページHTMLから (最新画像URL, 撮影時刻YYYYMMDDHHMMSS) を返す。
    複数出現する場合は時刻が最大のものを採用する。"""
    best: tuple[str, str] | None = None
    for m in IMG_RE.finditer(html):
        cand = (urljoin(page_url, "/" + m.group(1)), m.group(2))
        if best is None or cand[1] > best[1]:
            best = cand
    return best
