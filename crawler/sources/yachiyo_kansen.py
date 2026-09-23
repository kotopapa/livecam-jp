"""八千代市 1号幹線水位監視カメラ（都度解決型ヘルパー）。

https://www.yachiyo-1goukansen-suii.jp/No1.php〜No3.php（八千代台西・八千代台北・大和田）に
「現在の状況」として `<img src="camera1/2663.jpg">` のような連番ファイル名が埋め込まれ、
30秒ごとに番号が進む（固定URLなし）。最初の img（camera<N>/<番号>.jpg）が最新。

feed.type = "yachiyo_kansen"、feed.url = 上記 NoN.php。monitor/main.py がページを取得して
resolve_image_url() で最新URLを解決し、status.json の image_url で配信する（kochi_suibo と同じ流儀）。
対象は幹線下水道（高津川）の水位で、印旛沼流域（新川）に注ぐ。2026-09-23 追加。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

IMG_RE = re.compile(r'<img\s+src="(camera\d+/(\d+)\.jpg)"', re.I)


def resolve_image_url(page_url: str, html: str) -> tuple[str, str] | None:
    """NoN.php の HTML から (最新画像URL, 連番) を返す。最初の camera<N>/<番号>.jpg が現在の状況。"""
    m = IMG_RE.search(html)
    if not m:
        return None
    return urljoin(page_url, m.group(1)), m.group(2)
