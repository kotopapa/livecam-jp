"""官公庁YouTubeチャンネルの「配信中ライブ」収集パーサ。

チャンネルの /streams ページ（robots.txt で許可されていることを確認済み）から
ytInitialData を解析し、配信中のライブ動画を候補化する。1チャンネルに複数の
ライブが同時にある場合に使う（1チャンネル=1ライブなら mlit_youtube の
youtube_channel 方式のほうが動画ID変化に強い）。

- feed.type=youtube_video（動画ID固定埋め込み）。ライブ再起動でIDが変わるため
  週次クロール + crawler/main.py の承認済みfeed安全更新で追従する
- id は動画IDではなく「チャンネル+正規化タイトル」のハッシュ（配信再起動で
  変わらない安定ID）
- 座標はタイトルの地点名から address_hint を作りジオコーディング。
  解決しなければ pending のまま（推測で埋めない）
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

YT_INITIAL_RE = re.compile(r"var ytInitialData = (\{.*?\});</script>", re.S)


@dataclass(frozen=True)
class LiveChannel:
    key: str                     # ID用スラグ
    channel_id: str
    operator: str
    attribution: str
    default_pref: str            # JIS 2桁
    license: str = "unknown"
    terms_url: str | None = None
    default_category: str = "river"
    category_rules: tuple = ()   # (正規表現, category)
    pref_rules: tuple = ()       # (正規表現, JISコード, 県名)
    default_pref_name: str = ""


CHANNELS: list[LiveChannel] = [
    # 四国地方整備局CCTV: 1配信=1地点固定・タイトルに地点名(那賀川5・肱川4)
    LiveChannel(
        key="skr",
        channel_id="UCsV_76RlGzFVZQABftUKdSw",
        operator="国土交通省 四国地方整備局",
        attribution="出典：国土交通省 四国地方整備局（公式YouTubeライブ）",
        default_pref="36",
        default_pref_name="徳島県",
        category_rules=((r"ダム", "dam"),),
        pref_rules=(
            (r"那賀川|長安口|加茂谷|長生|桑野", "36", "徳島県"),
            (r"肱川|野村|鹿野川|都谷", "38", "愛媛県"),
        ),
    ),
    # 北陸地整 水災害対策センター: 水系グループ単位の巡回配信5本
    LiveChannel(
        key="hrr",
        channel_id="UCcwYr4sdrvx3XjdkyHnhtBA",
        operator="国土交通省 北陸地方整備局",
        attribution="出典：国土交通省 北陸地方整備局（公式YouTubeライブ）",
        default_pref="15",
        default_pref_name="",   # 巡回型は地点ジオコード不可（重心を後段で設定）
        pref_rules=(
            (r"黒部|常願寺|神通|庄川|小矢部", "16", ""),
            (r"手取川|梯川", "17", ""),
        ),
    ),
    # 北海道開発局 河川管理課: 16カ所巡回×2本
    LiveChannel(
        key="hkd",
        channel_id="UC_CPIys6tBqmwVXsH-X4ycg",
        operator="国土交通省 北海道開発局",
        attribution="出典：国土交通省 北海道開発局（公式YouTubeライブ）",
        default_pref="01",
        default_pref_name="",
    ),
]


def extract_live_streams(html: str) -> list[tuple[str, str]]:
    """チャンネル/streamsページから配信中ライブの (videoId, タイトル) を返す。"""
    m = YT_INITIAL_RE.search(html)
    if not m:
        return []
    try:
        data = json.loads(m.group(1))
    except json.JSONDecodeError:
        return []
    items: dict[str, str] = {}

    def walk(o):
        if isinstance(o, dict):
            if "lockupViewModel" in o:
                v = o["lockupViewModel"]
                vid = v.get("contentId") or ""
                try:
                    title = v["metadata"]["lockupMetadataViewModel"]["title"]["content"]
                except (KeyError, TypeError):
                    title = ""
                s = json.dumps(v, ensure_ascii=False)
                if vid and title and ("ライブ" in s or '"LIVE"' in s or "視聴中" in s):
                    items.setdefault(vid, title)
            if "videoRenderer" in o:
                v = o["videoRenderer"]
                vid = v.get("videoId") or ""
                title = "".join(r.get("text", "")
                                for r in (v.get("title") or {}).get("runs", []))
                s = json.dumps(v, ensure_ascii=False)
                if vid and title and ('"LIVE"' in s or "ライブ" in s):
                    items.setdefault(vid, title)
            for x in o.values():
                walk(x)
        elif isinstance(o, list):
            for x in o:
                walk(x)

    walk(data)
    return list(items.items())


def clean_title(title: str) -> str:
    """配信タイトルから地点名を取り出す（【ライブ】等の飾りを除去）。"""
    t = re.sub(r"【[^】]*】|\(ライブ[^)]*\)|ライブ配信|ライブカメラ|LIVE", "", title,
               flags=re.IGNORECASE)
    t = t.replace("　", " ")
    return re.sub(r"\s+", " ", t).strip(" -‐–|/")


def stable_id(prefix: str, channel_id: str, name: str) -> str:
    """配信再起動（videoId変化）でも変わらない安定ID。"""
    h = hashlib.sha1(f"{channel_id}:{name}".encode()).hexdigest()[:10]
    return f"yt-{prefix}-{h}"


class YoutubeLiveParser(SourceParser):
    source_id = "youtube_gov_live"
    seed_url = "https://www.youtube.com/"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for ch in CHANNELS:
            url = f"https://www.youtube.com/channel/{ch.channel_id}/streams"
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"{ch.key}: HTTP {page.status} {page.error or ''}")
                continue
            streams = extract_live_streams(page.text)
            if not streams:
                result.errors.append(
                    f"{ch.key}: 配信中ライブが取れない — 全停止か構造変化の可能性")
                continue
            for vid, title in streams:
                name = clean_title(title)
                if not name:
                    continue
                category = ch.default_category
                for pat, cat in ch.category_rules:
                    if re.search(pat, name):
                        category = cat
                        break
                pref, pref_name = ch.default_pref, ch.default_pref_name
                for pat, code, pname in ch.pref_rules:
                    if re.search(pat, name):
                        pref, pref_name = code, pname
                        break
                result.candidates.append(CameraCandidate(
                    id=stable_id(ch.key, ch.channel_id, name),
                    name=name,
                    category=category,
                    prefecture=pref,
                    feed_type="youtube_video",
                    feed_url=vid,
                    fallback_url=f"https://www.youtube.com/watch?v={vid}",
                    operator=ch.operator,
                    page_url=f"https://www.youtube.com/channel/{ch.channel_id}",
                    attribution=ch.attribution,
                    license=ch.license,
                    terms_url=ch.terms_url,
                    address_hint=f"{pref_name}{name}" if pref_name else None,
                    review_note="公式YouTubeライブ。概要欄に利用許諾文言なし（要確認）。"
                                "ライブ再起動で動画IDが変わるため週次クロールで追従",
                ))
        return result
