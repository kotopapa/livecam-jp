"""東京都水防チャンネル（都建設局の河川監視カメラYouTubeライブ）パーサ。

台帳ソースは東京都オープンデータカタログの
「河川監視カメラ位置情報データ」CSV（CC BY 4.0）:
    番号,観測所名（映像監視局）,河川名,URL（動画）,緯度,経度
1行=1カメラで、YouTube動画URL（ライブ）と正確な座標が揃っている。

- 映像は「東京都水防チャンネル」のYouTubeライブ（1チャンネルに多数配信のため
  feed.type は youtube_video = 動画ID固定埋め込み）
- ライブ配信は再起動で動画IDが変わることがある → 週次クロールでCSVから追従し、
  承認済みカメラのfeed.urlは crawler/main.py の安全更新で差し替える
"""

from __future__ import annotations

import csv
import io
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

CSV_URL = ("https://www.opendata.metro.tokyo.lg.jp/kensetsu/R4/"
           "130001_river-monitoring-cameras.csv")
TERMS_URL = "https://catalog.data.metro.tokyo.lg.jp/dataset/t000014d0000000028"
VIDEO_ID_RE = re.compile(
    r"(?:youtu\.be/|youtube\.com/(?:watch\?v=|live/|embed/))([A-Za-z0-9_-]{6,})")


def parse_csv(text: str) -> list[dict]:
    """CSVを行辞書のリストにする（BOM除去込み）。videoIdが取れない行は捨てる。"""
    rows = []
    reader = csv.DictReader(io.StringIO(text.lstrip("﻿")))
    for row in reader:
        row = { (k or "").strip(): (v or "").strip() for k, v in row.items() }
        m = VIDEO_ID_RE.search(row.get("URL（動画）", ""))
        if not m:
            continue
        try:
            num = int(row["番号"])
            lat = float(row["緯度"])
            lng = float(row["経度"])
        except (KeyError, ValueError):
            continue
        rows.append({
            "num": num,
            "name": row.get("観測所名（映像監視局）", ""),
            "river": row.get("河川名", ""),
            "video_id": m.group(1),
            "lat": lat,
            "lng": lng,
        })
    return rows


class TokyoSuiboParser(SourceParser):
    source_id = "tokyo_suibo"
    seed_url = CSV_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        resp = session.fetch(CSV_URL)
        if not resp.ok:
            result.errors.append(f"CSV HTTP {resp.status} {resp.error or ''}")
            return result
        rows = parse_csv(resp.text)
        if not rows:
            result.errors.append("CSVからカメラ行が取れない — 列構成が変わった可能性")
            return result
        for r in rows:
            result.candidates.append(CameraCandidate(
                id=f"tokyo-suibo-{r['num']:03d}",
                name=f"{r['river']} {r['name']}".strip(),
                category="river",
                prefecture="13",
                feed_type="youtube_video",
                feed_url=r["video_id"],
                fallback_url=f"https://www.youtube.com/watch?v={r['video_id']}",
                operator="東京都建設局",
                page_url=TERMS_URL,
                attribution="出典：東京都建設局（東京都水防チャンネル）",
                license="youtube_gov",
                terms_url=TERMS_URL,
                river_or_route=r["river"] or None,
                lat=r["lat"], lng=r["lng"], coord_accuracy="exact",
                review_note="位置データは東京都オープンデータ(CC BY 4.0)。"
                            "ライブ再起動で動画IDが変わるため週次クロールで追従",
            ))
        return result
