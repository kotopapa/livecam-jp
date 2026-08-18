"""市町村公式ページのYouTubeライブカメラパーサ（静的HTMLのリンク列挙型）。

対応自治体は SEEDS のテーブルで管理。ページ内の youtu.be / watch?v= リンクと
リンクテキスト（地点名）を対にして候補化する。

- feed.type=youtube_video。配信再開で動画IDが変わるため、週次クロール +
  crawler/main.py の承認済みfeed安全更新で追従する
- 座標は「県名+市名+地点名」のヒントでジオコーディング（approx）。
  解決しないものは pending のまま
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

VIDEO_RE = re.compile(
    r"(?:youtu\.be/|youtube\.com/(?:watch\?v=|live/|embed/))([A-Za-z0-9_-]{6,})")


@dataclass(frozen=True)
class MuniSeed:
    key: str
    pages: tuple
    operator: str
    prefecture: str
    hint_prefix: str            # ジオコーディング用（例: 栃木県大田原市）
    category: str = "river"


SEEDS = [
    MuniSeed(key="ohtawara",
             pages=("https://www.city.ohtawara.tochigi.jp/docs/2013082781499/",),
             operator="大田原市", prefecture="09", hint_prefix="栃木県大田原市"),
    MuniSeed(key="kasugai",
             pages=("https://www.city.kasugai.lg.jp/shisei/machi/haisui/kansoku_system.html",),
             operator="春日井市", prefecture="23", hint_prefix="愛知県春日井市"),
    MuniSeed(key="shiki",
             pages=("https://www.city.shiki.lg.jp/soshiki/11/3173.html",),
             operator="志木市", prefecture="11", hint_prefix="埼玉県志木市"),
    MuniSeed(key="yokosuka",
             pages=("https://www.city.yokosuka.kanagawa.jp/camera/area_01/index.html",
                    "https://www.city.yokosuka.kanagawa.jp/camera/area_02/index.html",
                    "https://www.city.yokosuka.kanagawa.jp/camera/area_03/index.html"),
             operator="横須賀市", prefecture="14", hint_prefix="神奈川県横須賀市",
             category="other"),   # 災害監視（海岸・道路・河川の混在）
]


def extract_video_links(html: str, base_url: str) -> list[tuple[str, str]]:
    """(videoId, リンクテキスト) を抽出する。hrefのIDが正（data-id等は信用しない）。"""
    soup = BeautifulSoup(html, "html.parser")
    out: dict[str, str] = {}
    for a in soup.find_all("a", href=True):
        m = VIDEO_RE.search(urljoin(base_url, a["href"]))
        if not m:
            continue
        text = a.get_text(" ", strip=True)
        # 同じ動画に複数リンク（画像+テキスト）がある場合はテキスト付きを優先
        if m.group(1) not in out or (text and not out[m.group(1)]):
            out[m.group(1)] = text
    return list(out.items())


def clean_spot_name(text: str) -> str:
    t = re.sub(r"（?外部リンク）?|新しいウィンドウで開きます|ライブカメラ|ライブ配信", "", text)
    t = t.replace("　", " ")
    return re.sub(r"\s+", " ", t).strip(" ・:：")


class MuniYoutubeParser(SourceParser):
    source_id = "muni_youtube"
    seed_url = SEEDS[0].pages[0]

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for seed in SEEDS:
            found = 0
            for page_url in seed.pages:
                page = session.fetch(page_url)
                if not page.ok:
                    result.errors.append(
                        f"{seed.key}: HTTP {page.status} {page.error or ''}")
                    continue
                for vid, text in extract_video_links(page.text, page_url):
                    name = clean_spot_name(text)
                    if not name:
                        continue
                    import hashlib
                    h = hashlib.sha1(f"{seed.key}:{name}".encode()).hexdigest()[:10]
                    result.candidates.append(CameraCandidate(
                        id=f"muni-{seed.key}-{h}",
                        name=f"{seed.operator} {name}",
                        category=seed.category,
                        prefecture=seed.prefecture,
                        feed_type="youtube_video",
                        feed_url=vid,
                        fallback_url=f"https://www.youtube.com/watch?v={vid}",
                        operator=seed.operator,
                        page_url=page_url,
                        attribution=f"出典：{seed.operator}（公式YouTubeライブ）",
                        license="unknown",
                        address_hint=f"{seed.hint_prefix}{name}",
                        review_note="自治体公式YouTubeライブ。利用規約はレビューで確認。"
                                    "動画IDは週次クロールで追従",
                    ))
                    found += 1
            if found == 0:
                result.errors.append(f"{seed.key}: カメラリンクが取れない")
        return result
