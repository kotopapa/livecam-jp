"""国交省中部地整 静岡河川事務所の海岸監視カメラ（津波・高潮監視）。

https://www.cbr.mlit.go.jp/shizukawa/bousai/livecamera/ 配下の
「駿河海岸エリア」「富士海岸エリア」の2ページに、サムネイル
`seishiga/eizou/<slug>_s.jpg` と alt=カメラ名 が並ぶ。
フルサイズは `_s` を外した `seishiga/eizou/<slug>.jpg`（固定URL・200 image/jpeg確認済み）。

座標はページに無いため、地点名（多くが実在の町名）から住所ヒントを
組み立てて GSI ジオコーディング（fill_coordinates の検証付き）に委ねる。
ヒント不明の地点は座標なしのまま pending に残る。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.cbr.mlit.go.jp/shizukawa/"
AREA_URLS = {
    "駿河海岸": BASE + "bousai/livecamera/suruga/",
    "富士海岸": BASE + "bousai/livecamera/kanbara/",
}
IMG_RE = re.compile(
    r'<img[^>]*src="[^"]*seishiga/eizou/([a-z0-9-]+)_s\.jpg[^"]*"[^>]*alt="([^"]+)"')

# 地点名 → 住所ヒント（GSI検証付きジオコーディング用）。
# 河口・施設名は最寄りの実在町名を当てる。不明地点は載せない（座標なし保留）
ADDRESS_HINTS = {
    "田尻北": "静岡県焼津市田尻北",
    "田尻": "静岡県焼津市田尻",
    "ディスカバリーパーク屋上": "静岡県焼津市田尻",       # ディスカバリーパーク焼津(田尻2968)
    "栃山川河口右岸": "静岡県焼津市利右衛門",
    "藤守川河口右岸": "静岡県焼津市藤守",
    "高新田": "静岡県焼津市高新田",
    "吉永": "静岡県焼津市吉永",
    "大井川河口右岸": "静岡県榛原郡吉田町川尻",
    "川尻": "静岡県榛原郡吉田町川尻",
    "住吉": "静岡県榛原郡吉田町住吉",
    "坂口谷川河口左岸": "静岡県榛原郡吉田町住吉",
    "榛原": "静岡県牧之原市静波",
    "蒲原中": "静岡県静岡市清水区蒲原",
    "小金": "静岡県静岡市清水区蒲原小金",
    "千本浜Ｃ１": "静岡県沼津市千本港町",
    "西間門Ｃ２": "静岡県沼津市西間門",
    "大諏訪Ｃ３": "静岡県沼津市大諏訪",
    "大塚Ｃ４": "静岡県沼津市大塚",
    "原Ｃ５": "静岡県沼津市原",
    "桃里Ｃ６": "静岡県沼津市桃里",
    "西柏原新田Ｃ７": "静岡県沼津市西柏原新田",
    "今井Ｃ８": "静岡県富士市今井",
    "鮫島Ｃ９": "静岡県富士市鮫島",
    "川成島Ｃ１０": "静岡県富士市川成島",
    "宮島Ｃ１１": "静岡県富士市宮島",
}


def parse_area(html: str) -> list[tuple[str, str]]:
    """(slug, カメラ名) のリスト。"""
    return [(m.group(1), m.group(2).strip()) for m in IMG_RE.finditer(html)]


class ShizukawaCoastParser(SourceParser):
    source_id = "shizukawa_coast"
    seed_url = BASE + "bousai/livecamera/"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        seen: set[str] = set()
        for area_name, url in AREA_URLS.items():
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"shizukawa_coast: HTTP {page.status} {url}")
                continue
            cams = parse_area(page.text)
            if not cams:
                result.errors.append(f"shizukawa_coast: {area_name} でカメラが1件も取れない")
                continue
            for slug, name in cams:
                if slug in seen:
                    continue
                seen.add(slug)
                # 表示名の全角付番(Ｃ１等)は名前から落とす
                clean = re.sub(r"Ｃ[０-９]+$", "", name)
                result.candidates.append(CameraCandidate(
                    id=f"shizukawa-coast-{slug}",
                    name=f"{area_name} {clean}",
                    category="coast",
                    prefecture="22",
                    feed_type="still_image",
                    feed_url=f"{BASE}seishiga/eizou/{slug}.jpg",
                    fallback_url=url,
                    operator="国土交通省中部地方整備局 静岡河川事務所",
                    page_url=url,
                    attribution="映像提供：国土交通省中部地方整備局 静岡河川事務所",
                    license="unknown",
                    refresh_sec=600,
                    address_hint=ADDRESS_HINTS.get(name),
                    river_or_route=area_name,
                    review_note="海岸監視カメラ（津波・高潮監視）。座標は地点名からの推定(approx)",
                ))
        return result
