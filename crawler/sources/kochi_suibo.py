"""高知県水防情報システムの監視カメラ（都度解決型ヘルパー）。

https://suibo-kouho.suibou.pref.kochi.lg.jp/sp/static/camera/itv_detail_<n>.html
に `var itvNo = "034"; var obstime = "1027";` が埋め込まれており、
最新画像は /suibou/camera/img/<itvNo>_<obstime>.jpg（HHMM刻みで名前が変わる）。

feed.type = "kochi_suibo"、feed.url = 上記detailページURL。
monitor/main.py がページを取得して resolve_image_url() で最新URLを解決し、
status.json の image_url で配信する（他の都度解決型と同じ流儀）。

discoveryパーサではないため REGISTRY には登録しない。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

ITV_RE = re.compile(r'var itvNo\s*=\s*"(\d+)"')
OBS_RE = re.compile(r'var obstime\s*=\s*"(\d+)"')


def resolve_image_url(page_url: str, html: str) -> tuple[str, str] | None:
    """detailページHTMLから (最新画像URL, 観測時刻HHMM) を返す。"""
    m_no = ITV_RE.search(html)
    m_obs = OBS_RE.search(html)
    if not (m_no and m_obs):
        return None
    url = urljoin(page_url, f"/suibou/camera/img/{m_no.group(1)}_{m_obs.group(1)}.jpg")
    return url, m_obs.group(1)
