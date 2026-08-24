"""四万十町 河川・海岸監視カメラ（kasen.midwest-kochi.jp、都度解決型ヘルパー）。

http://kasen.midwest-kochi.jp/shimanto/index.php に17地点（point1〜point17）の一覧があり、
画像は /shimanto/point<N>/<YYYYMMDDHHMM>.jpg（1分更新・タイムスタンプ名）で固定URLがない。
最新時刻は result_time.php に POST point=point<N> すると "202608250723" のような
12桁の文字列だけが返る（1台1リクエスト）。

feed.type = "shimanto_kasen"、feed.url = result_time.php のURL、feed.camera_ref = "point<N>"。
monitor/main.py が POST で最新時刻を取り resolve_image_url() で画像URLを組み立て、
status.json の image_url で配信する（kochi_suibo と同じ流儀。POSTなので専用ブロック）。

discoveryパーサではないため REGISTRY には登録しない（台帳は curated_still.yaml）。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

BASE = "http://kasen.midwest-kochi.jp/shimanto/"
RESULT_TIME_URL = BASE + "result_time.php"

TIME_RE = re.compile(r"^\s*(\d{12})\s*$")
POINT_RE = re.compile(r'<li class="(point\d+)"><a[^>]*>([^<]+)</a></li>')


def resolve_image_url(result_url: str, camera_ref: str,
                      text: str) -> tuple[str, str] | None:
    """result_time.php の応答（12桁 YYYYMMDDHHMM）から (最新画像URL, ISO時刻JST) を返す。"""
    m = TIME_RE.match(text or "")
    if not m or not re.fullmatch(r"point\d+", camera_ref or ""):
        return None
    ts = m.group(1)
    url = urljoin(result_url, f"{camera_ref}/{ts}.jpg")
    iso = f"{ts[:4]}-{ts[4:6]}-{ts[6:8]}T{ts[8:10]}:{ts[10:12]}:00+09:00"
    return url, iso


def parse_points(html: str) -> dict[str, str]:
    """index.php の地点リストから {"point5": "松葉川", ...} を返す（台帳の名称照合用）。"""
    out: dict[str, str] = {}
    for ref, name in POINT_RE.findall(html):
        out.setdefault(ref, name.strip())
    return out
