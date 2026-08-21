"""神戸市「河川モニタリングカメラシステム」(kobe-city-office.jp) パーサ。

トップページの「河川カメラ一覧」に30台(/kawa-camera/kyoku/<NN>)。
各詳細ページのGoogleマップリンク(ll=lat,lng)に正確な座標がある。
静止画は images/camera/mobile/<NN>.jpg の固定URL(ゼロ埋め2桁)。
※ドメインは市の委託系だがサイト名・内容で神戸市運営を確認済み。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://kobe-city-office.jp/"
LIST_RE = re.compile(r'href="/kawa-camera/kyoku/(\d+)">([^<]+)</a>')
LL_RE = re.compile(r"ll=([\d.]+),([\d.]+)")


class KobeRiverParser(SourceParser):
    source_id = "kobe_river"
    seed_url = BASE

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        top = session.fetch(BASE)
        if not top.ok:
            result.errors.append(f"kobe_river: HTTP {top.status}")
            return result
        pairs = LIST_RE.findall(top.text)
        for cid, name in pairs:
            detail = session.fetch(f"{BASE}kawa-camera/kyoku/{cid}")
            lat = lng = None
            if detail.ok:
                m = LL_RE.search(detail.text)
                if m:
                    lat, lng = float(m.group(1)), float(m.group(2))
            river = name.split(" ")[0] if " " in name else None
            result.candidates.append(CameraCandidate(
                id=f"kobe-river-{cid}",
                name=name.strip(),
                category="river",
                prefecture="28",
                municipality="28100",
                feed_type="still_image",
                feed_url=f"{BASE}images/camera/mobile/{cid}.jpg",
                fallback_url=BASE,
                operator="神戸市",
                page_url=f"{BASE}kawa-camera/kyoku/{cid}",
                attribution="映像提供：神戸市（河川モニタリングカメラシステム）",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact" if lat else "none",
                river_or_route=river,
                review_note="神戸市の河川監視カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("kobe_river: カメラが1件も取れない")
        return result
