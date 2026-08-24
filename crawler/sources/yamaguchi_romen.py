"""山口河川国道事務所「道路路面情報提供（峠路面情報）」の都度解決型ヘルパー。

https://www.cgr.mlit.go.jp/yamaguchi/romen/ に9地点（西深川・鎖峠・宇田・杖坂・
生雲東分・徳佐・吉見峠・椿峠・樋口）の最新画像がまとめて載る。画像URLは
/yamaguchi/romen/douroimage/<YYYYMMDD>/<HHMM>/<code>.jpg のタイムスタンプ名で
固定URLがない。地点コード（<a name="C0422">）と画像ファイル名は一致しないことが
ある（宇田 C0401 → C0437.jpg）ため、必ず <img src> を読む。

feed.type = "yamaguchi_romen"、feed.url = 上記一覧ページ、feed.camera_ref = 地点コード。
monitor/main.py が一覧ページ1枚を取得して resolve_image_urls() で全台を解決し、
status.json の image_url で配信する（saitama_flood と同じ流儀）。

※ www.road.cgr.mlit.go.jp（robots Disallow: /）は使わない。事務所サイト側のみ。
discoveryパーサではないため REGISTRY には登録しない。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

BASE = "https://www.cgr.mlit.go.jp/yamaguchi/romen/"

# 地点ごとの <table class="point_table"> を切り出す
TABLE_RE = re.compile(r'<table[^>]*class="point_table"[^>]*>(.*?)</table>', re.S)
CODE_RE = re.compile(r'<a name="([A-Za-z0-9]+)"')
IMG_RE = re.compile(r'<img src="([^"]+/douroimage/[^"]+\.jpe?g)"', re.I)
TIME_RE = re.compile(r"撮影日時\s*</td>\s*<td[^>]*>\s*(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})")


def resolve_image_urls(html: str, page_url: str = BASE) -> dict[str, tuple[str, str]]:
    """一覧ページHTMLから {地点コード: (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    out: dict[str, tuple[str, str]] = {}
    for m in TABLE_RE.finditer(html):
        block = m.group(1)
        code = CODE_RE.search(block)
        img = IMG_RE.search(block)
        if not (code and img):
            continue
        url = urljoin(page_url, img.group(1))
        t = TIME_RE.search(block)
        if t:
            y, mo, d, h, mi = (int(x) for x in t.groups())
            iso = f"{y:04d}-{mo:02d}-{d:02d}T{h:02d}:{mi:02d}:00+09:00"
        else:
            # 時刻表記がなければURLの <YYYYMMDD>/<HHMM> から復元する
            u = re.search(r"/douroimage/(\d{8})/(\d{4})/", url)
            iso = (f"{u.group(1)[:4]}-{u.group(1)[4:6]}-{u.group(1)[6:]}"
                   f"T{u.group(2)[:2]}:{u.group(2)[2:]}:00+09:00") if u else ""
        out[code.group(1)] = (url, iso)
    return out
