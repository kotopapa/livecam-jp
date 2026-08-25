"""MBC南日本放送「かごしまライブカメラ」パーサ（鹿児島県内85地点の静止画網）。

一覧 https://www.mbc.co.jp/web-cam/ のHTMLに、エリア別4変数のインラインJSON
（satsuma/osumi/taneyaku/amami）としてカメラ台帳が埋め込まれている。

- 静止画: https://www.mbc.co.jp/web-cam/img/<camImg>.jpg（随時更新・固定URL）
- camTitle が null の行は同一地点の別アングル → v1では採用しない
- youtube フィールドがある行はYouTube配信（既収載分はURL重複ガードで除外される）
- 設置者(camOwner)は気象庁・国道事務所・役場・地元企業など混在
  → operator に設置者、attribution に「映像提供：MBC南日本放送」を記録し
    license=unknown で人手レビューに委ねる
- 座標なし → camMap（例: 鹿児島市吉野町）に鹿児島県を前置してジオコーディング
"""

from __future__ import annotations

import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

PAGE_URL = "https://www.mbc.co.jp/web-cam/"
JSON_VARS = ("satsumaJson", "osumiJson", "taneyakuJson", "amamiJson")
VIDEO_ID_RE = re.compile(r"(?:youtu\.be/|youtube\.com/(?:watch\?v=|live/))([A-Za-z0-9_-]{6,})")


def extract_cameras(html: str) -> list[dict]:
    """4つのインラインJSONを結合して返す（camTitleのある行のみ）。"""
    out: list[dict] = []
    for var in JSON_VARS:
        m = re.search(rf"const\s+{var}\s*=\s*`(\[.*?\])`", html, re.S)
        if not m:
            continue
        try:
            out += [c for c in json.loads(m.group(1)) if c.get("camTitle")]
        except json.JSONDecodeError:
            continue
    return out


def _s(v) -> str:
    """フィールドは文字列以外(bool/null)が混ざるため安全に文字列化する。"""
    return v.strip() if isinstance(v, str) else ""


def categorize(title: str, river: str | None) -> str:
    if river:
        return "river"
    if re.search(r"桜島|新燃岳|硫黄|御岳|噴火", title):
        return "volcano"
    if re.search(r"国道|県道|道路|バイパス|峠", title):
        return "road"
    if re.search(r"港", title):
        return "port"
    if re.search(r"海岸|海水浴|ビーチ", title):
        return "coast"
    return "scenic"


class MbcWebcamParser(SourceParser):
    source_id = "mbc_webcam"
    seed_url = PAGE_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(PAGE_URL)
        if not page.ok:
            result.errors.append(f"HTTP {page.status} {page.error or ''}")
            return result
        cams = extract_cameras(page.text)
        if not cams:
            result.errors.append("インラインJSONが取れない — ページ構造が変わった可能性")
            return result

        seen: set[str] = set()
        for cam in cams:
            title = _s(cam.get("camTitle"))
            img = _s(cam.get("camImg"))
            slug = re.sub(r"[^a-z0-9]+", "-", img.lower()).strip("-").removeprefix("cam1-")
            if not title or not img or not slug or slug in seen:
                continue
            seen.add(slug)
            owner = _s(cam.get("camOwner")) or "MBC南日本放送"
            river = _s(cam.get("camRiver")) or None
            cam_map = _s(cam.get("camMap"))

            yt = VIDEO_ID_RE.search(_s(cam.get("youtube")))
            if yt:
                feed_type, feed_url = "youtube_video", yt.group(1)
                fallback = f"https://www.youtube.com/watch?v={feed_url}"
            else:
                # MBCサイトは画像の二次利用をお断りしているため(2026-08-25確認)、
                # 静止画は直接参照せず個別ページへの誘導型にする
                feed_type = "web_page"
                feed_url = f"https://www.mbc.co.jp/web-cam/movie.html?area={img}"
                fallback = PAGE_URL

            result.candidates.append(CameraCandidate(
                id=f"mbc-{slug}",
                name=title,
                category=categorize(title, river),
                prefecture="46",
                feed_type=feed_type,
                feed_url=feed_url,
                fallback_url=fallback,
                operator=owner,
                page_url=PAGE_URL,
                attribution=f"映像提供：MBC南日本放送（設置：{owner}）",
                license="unknown",
                river_or_route=river,
                refresh_sec=600,
                address_hint=f"鹿児島県{cam_map}" if cam_map else None,
                review_note="MBC「かごしまライブカメラ」経由。設置者の利用条件はレビューで確認",
            ))
        return result
