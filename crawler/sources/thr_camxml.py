"""東北地整ライブカメラXML（都度解決型 feed=thr_camxml）の解決ヘルパ。

対象は「Camera XML + タイムスタンプ名画像」形式（例: 蔵王御釜
www2.thr.mlit.go.jp/shinjyou/zaou_live/video/okama.xml）。
feed.url にXMLのURLを入れる。最新画像は
  <XMLのURLから.xmlを除いたディレクトリ>/<PictureFilenameHistorical>
になる。monitor/main.py が毎回解決して status.json の image_url で配信する。
"""

from __future__ import annotations

import re

FILE_RE = re.compile(
    r"<PictureFilenameHistorical>(\d{12})\.jpg</PictureFilenameHistorical>")
DATE_RE = re.compile(r"<ObservationDate>([^<]+)</ObservationDate>")


def resolve_image_url(xml_url: str, xml_text: str) -> tuple[str, str] | None:
    """(最新画像URL, 取得時刻ISO) を返す。解決できなければ None"""
    m = FILE_RE.search(xml_text)
    if not m:
        return None
    ts = m.group(1)  # YYYYMMDDHHmm
    iso = (f"{ts[0:4]}-{ts[4:6]}-{ts[6:8]}T{ts[8:10]}:{ts[10:12]}:00+09:00")
    base = xml_url[:-4] if xml_url.endswith(".xml") else xml_url
    return f"{base}/{ts}.jpg", iso


IDX_TS_RE = re.compile(r"^(\d{12,14})", re.MULTILINE)


def resolve_camidx_url(idx_url: str, idx_text: str) -> tuple[str, str] | None:
    """camidx_latest型（横浜市水防災など）の解決。

    idxファイルの先頭行が最新タイムスタンプ。画像は
    <idxと同じディレクトリ>/<カメラID>_<ts>.jpg （IDはidxファイル名の先頭部）。
    """
    m = IDX_TS_RE.search(idx_text)
    if not m:
        return None
    ts = m.group(1)
    directory, fname = idx_url.rsplit("/", 1)
    cam_id = fname.split("_")[0]
    if len(ts) >= 12:
        iso = (f"{ts[0:4]}-{ts[4:6]}-{ts[6:8]}T{ts[8:10]}:{ts[10:12]}:"
               f"{ts[12:14] if len(ts) >= 14 else '00'}+09:00")
    else:
        iso = ""
    return f"{directory}/{cam_id}_{ts}.jpg", iso
