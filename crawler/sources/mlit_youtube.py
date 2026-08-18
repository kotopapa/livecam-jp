"""官公庁YouTubeチャンネル（水系別・1チャンネル1配信型）のライブカメラパーサ。

整備局の案内ページから youtube.com/channel/UC... リンクを抽出する。
対応整備局は SEEDS のテーブルで管理（九州・近畿）。
（@handle 形式に出会った場合はチャンネルページの channelId メタから解決する。
 YouTube Data API は使わない。）

1チャンネル=1カメラとは限らないため review.status は常に pending とし、
チャンネル名から複数カメラの疑いがあるものは note に記す。
座標は持たないので geocode 後も pending のまま人手で確定する
（運用上は同水系カメラ群の重心を代表点（coord_accuracy=area）にして承認している）。
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from crawler.sources.base import CameraCandidate, DiscoverResult, HttpSession, SourceParser

_CHANNEL_RE = re.compile(r"youtube\.com/channel/(UC[\w-]{10,})")
_HANDLE_RE = re.compile(r"youtube\.com/(@[\w.-]+)")
_META_CHANNEL_RE = re.compile(
    r'"channelId"\s*:\s*"(UC[\w-]{10,})"|itemprop="identifier"\s+content="(UC[\w-]{10,})"')


@dataclass(frozen=True)
class YoutubeSeed:
    key: str                    # ID接頭辞（mlit-<key>-yt-...）
    seed_url: str
    operator: str
    attribution: str
    default_pref: str
    terms_url: str | None = None
    pref_rules: tuple = ()      # (名前の正規表現, JISコード)


SEEDS = [
    YoutubeSeed(
        key="qsr",
        seed_url="http://www.qsr.mlit.go.jp/useful/kasen_youtube.html",
        operator="国土交通省 九州地方整備局",
        attribution="出典：国土交通省 九州地方整備局（公式YouTube）",
        default_pref="40",
        terms_url="https://www.qsr.mlit.go.jp/site_info/index_c6.html",
    ),
    YoutubeSeed(
        key="kkr",
        seed_url="https://www.kkr.mlit.go.jp/river/bousai/livecamera.html",
        operator="国土交通省 近畿地方整備局",
        attribution="出典：国土交通省 近畿地方整備局（公式YouTube）",
        default_pref="27",
        terms_url="https://www.kkr.mlit.go.jp/guide/rules.html",
        pref_rules=(
            (r"由良川|桂川|木津川", "26"),
            (r"猪名川|円山川|加古川|揖保川", "28"),
            (r"名張川", "24"),
            (r"野洲川|瀬田川", "25"),
            (r"大和川", "29"),
            (r"紀の川|新宮川|熊野川", "30"),
            (r"九頭竜川", "18"),
        ),
    ),
]


def resolve_handle(session: HttpSession, handle: str) -> str | None:
    """@handle → UC チャンネルID。チャンネルページのメタ情報から取る。"""
    res = session.fetch(f"https://www.youtube.com/{handle}")
    if not res.ok:
        return None
    m = _META_CHANNEL_RE.search(res.text)
    return (m.group(1) or m.group(2)) if m else None


def extract_channels(html: str, base_url: str) -> list[tuple[str, str]]:
    """ページから (チャンネルID or @handle, リンクテキスト) を抽出する。"""
    soup = BeautifulSoup(html, "html.parser")
    out: list[tuple[str, str]] = []
    for a in soup.find_all("a", href=True):
        href = urljoin(base_url, a["href"])
        key = None
        m = _CHANNEL_RE.search(href)
        if m:
            key = m.group(1)
        else:
            hm = _HANDLE_RE.search(href)
            if hm:
                key = hm.group(1)
        if not key:
            continue
        name = a.get_text(strip=True)
        if not name:
            row = a.find_parent(["tr", "li", "p", "td"])
            name = row.get_text(" ", strip=True)[:50] if row else ""
        out.append((key, name))
    return out


class MlitYoutubeParser(SourceParser):
    source_id = "mlit_qsr_youtube"     # 歴史的経緯でこのID（九州+近畿を担当）
    seed_url = SEEDS[0].seed_url

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for seed in SEEDS:
            page = session.fetch(seed.seed_url)
            if not page.ok:
                result.errors.append(
                    f"{seed.key}: seed fetch failed {page.status} {page.error or ''}")
                continue
            seen: set[str] = set()
            found = 0
            for key, name in extract_channels(page.text, seed.seed_url):
                channel_id = key
                if key.startswith("@"):
                    channel_id = resolve_handle(session, key)
                    if channel_id is None:
                        result.errors.append(f"{seed.key}: {key} channelId解決不可")
                        continue
                if channel_id in seen:
                    continue
                seen.add(channel_id)

                note = "1チャンネル=1カメラか要確認。座標は手動で設定すること。"
                if re.search(r"一覧|まとめ|チャンネル|全体|主要", name):
                    note = "複数カメラ切替配信の疑いが強い。" + note
                pref = seed.default_pref
                for pat, code in seed.pref_rules:
                    if re.search(pat, name):
                        pref = code
                        break

                slug = re.sub(r"[^a-z0-9]", "", channel_id.lower())
                result.candidates.append(CameraCandidate(
                    id=f"mlit-{seed.key}-yt-{slug}",
                    name=name or channel_id,
                    category="river",
                    prefecture=pref,
                    feed_type="youtube_channel",
                    feed_url=channel_id,
                    operator=seed.operator,
                    page_url=seed.seed_url,
                    terms_url=seed.terms_url,
                    license="youtube_gov",
                    attribution=seed.attribution,
                    review_note=note,
                ))
                found += 1
            if found == 0:
                result.errors.append(
                    f"{seed.key}: no YouTube channels found — ページ構造が変わった可能性")
        return result
