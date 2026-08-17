"""官公庁YouTubeチャンネルのライブカメラパーサ。

シード: 九州地方整備局 http://www.qsr.mlit.go.jp/useful/kasen_youtube.html
ページ内の youtube.com/channel/UC... リンクを抽出する。
（このページは UC 形式のチャンネルIDを直接リンクしている。
 @handle 形式に出会った場合はチャンネルページの channelId メタから解決する。
 YouTube Data API は使わない。）

1チャンネル=1カメラとは限らないため review.status は常に pending とし、
チャンネル名から複数カメラの疑いがあるものは note に記す。
座標は持たないので geocode 後も pending のまま人手で確定する。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from crawler.sources.base import CameraCandidate, DiscoverResult, HttpSession, SourceParser

SEED_URL = "http://www.qsr.mlit.go.jp/useful/kasen_youtube.html"
TERMS_URL = "https://www.qsr.mlit.go.jp/site_info/index_c6.html"

_CHANNEL_RE = re.compile(r"youtube\.com/channel/(UC[\w-]{10,})")
_HANDLE_RE = re.compile(r"youtube\.com/(@[\w.-]+)")
_META_CHANNEL_RE = re.compile(r'"channelId"\s*:\s*"(UC[\w-]{10,})"|itemprop="identifier"\s+content="(UC[\w-]{10,})"')


def resolve_handle(session: HttpSession, handle: str) -> str | None:
    """@handle → UC チャンネルID。チャンネルページのメタ情報から取る。"""
    res = session.fetch(f"https://www.youtube.com/{handle}")
    if not res.ok:
        return None
    m = _META_CHANNEL_RE.search(res.text)
    return (m.group(1) or m.group(2)) if m else None


class MlitYoutubeParser(SourceParser):
    source_id = "mlit_qsr_youtube"
    seed_url = SEED_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        seed = session.fetch(self.seed_url)
        if not seed.ok:
            result.errors.append(f"seed fetch failed: {seed.status} {seed.error or ''}")
            return result

        soup = BeautifulSoup(seed.text, "html.parser")
        seen: set[str] = set()
        for a in soup.find_all("a", href=True):
            href = urljoin(self.seed_url, a["href"])
            channel_id: str | None = None
            m = _CHANNEL_RE.search(href)
            if m:
                channel_id = m.group(1)
            else:
                hm = _HANDLE_RE.search(href)
                if hm:
                    channel_id = resolve_handle(session, hm.group(1))
                    if channel_id is None:
                        result.errors.append(f"handle {hm.group(1)}: channelId を解決できず")
                        continue
            if not channel_id or channel_id in seen:
                continue
            seen.add(channel_id)

            # リンクテキスト（またはその行のテキスト）をカメラ名として使う
            name = a.get_text(strip=True)
            if not name:
                row = a.find_parent(["tr", "li", "p"])
                name = row.get_text(" ", strip=True)[:50] if row else channel_id
            note = "1チャンネル=1カメラか要確認。座標は手動で設定すること。"
            if re.search(r"一覧|まとめ|チャンネル|全体", name):
                note = "複数カメラ切替配信の疑いが強い。" + note

            # チャンネルIDには - _ が入りうるのでID規約([a-z0-9]と-のみ)に清書する
            slug = re.sub(r"[^a-z0-9]", "", channel_id.lower())
            result.candidates.append(CameraCandidate(
                id=f"mlit-qsr-yt-{slug}",
                name=name or channel_id,
                category="river",
                prefecture="40",       # 九州地整の代表値。レビュー時に正しい県へ直すこと
                feed_type="youtube_channel",
                feed_url=channel_id,
                operator="国土交通省 九州地方整備局",
                page_url=self.seed_url,
                terms_url=TERMS_URL,
                license="youtube_gov",
                attribution="出典：国土交通省 九州地方整備局（公式YouTube）",
                review_note=note,
            ))
        if not result.candidates:
            result.errors.append("no YouTube channels found — ページ構造が変わった可能性")
        return result
