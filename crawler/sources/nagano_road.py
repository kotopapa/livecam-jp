"""長野県 建設事務所 道路ライブカメラパーサ（avis.ne.jp ~chouken 系・6事務所）。

各建設事務所の詳細CGI(chouken_*prinfo.cgi?id=N)に地点名があり、
静止画は /~chouken/<district>/rp<3桁ID>b.jpg の固定URL(10分更新)。
一覧CGIはJS地図のためID連番プローブで列挙する(存在しないIDは画像404)。
座標は無いため地点名でジオコーディングする。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "http://www.avis.ne.jp"
DISTRICTS = [
    ("oomachi", "chouken_prinfo.cgi", "大町建設事務所"),
    ("saku", "chouken_sprinfo.cgi", "佐久建設事務所"),
    ("ueda", "chouken_uprinfo.cgi", "上田建設事務所"),
    ("kiso", "chouken_kprinfo.cgi", "木曽建設事務所"),
    ("nagano", "chouken_nprinfo.cgi", "長野建設事務所"),
    ("suzaka", "chouken_szkprinfo.cgi", "須坂建設事務所"),
]
MAX_ID = 30
NAME_RE = re.compile(
    r'>\s*([^<>\s][^<>]{1,28}?)\s*<[^>]*>\s*[^<>]*\d{4}年\d{2}月\d{2}日')
ROUTE_RE = re.compile(r"(国道\d+号|主要地方道[^\s　]+|一般県道[^\s　]+|[^\s　]{2,8}線)")


def parse_detail(html: str) -> str | None:
    """詳細CGIのHTMLから地点名(「YYYY年…現在の道路映像」直前のテキスト)を返す。"""
    text = re.sub(r"<script.*?</script>", "", html, flags=re.DOTALL)
    m = re.search(r">([^<>]{2,30})</[^>]+>[^<>]*<[^>]*>\s*\d{4}年", text)
    if m:
        return m.group(1).replace("　", " ").strip()
    # フォールバック: 日時行の直前の非空テキスト
    parts = [t.strip() for t in re.sub(r"<[^>]+>", "|", text).split("|")
             if t.strip()]
    for i, t in enumerate(parts):
        if re.match(r"\d{4}年\d{2}月\d{2}日", t) and i > 0:
            cand = parts[i - 1]
            if 2 <= len(cand) <= 30 and "注意" not in cand:
                return cand.replace("　", " ")
    return None


class NaganoRoadParser(SourceParser):
    source_id = "nagano_road"
    seed_url = BASE + "/cgi-usr/chouken_proadsel2.cgi"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for district, cgi, office in DISTRICTS:
            misses = 0
            for n in range(1, MAX_ID + 1):
                img_url = f"{BASE}/~chouken/{district}/rp{n:03d}b.jpg"
                img = session.fetch(img_url)
                if not img.ok or "image" not in (img.content_type or ""):
                    misses += 1
                    if misses >= 3:
                        break
                    continue
                misses = 0
                detail = session.fetch(
                    f"{BASE}/cgi-usr/{cgi}?id={n}&cntflg=0")
                name = parse_detail(detail.text) if detail.ok else None
                if not name:
                    name = f"{office} カメラ{n}"
                route = None
                m = ROUTE_RE.search(name)
                if m:
                    route = m.group(1)
                point = name.split(" ")[-1]
                result.candidates.append(CameraCandidate(
                    id=f"nagano-road-{district}-{n:03d}",
                    name=name,
                    category="road",
                    prefecture="20",
                    feed_type="still_image",
                    feed_url=img_url,
                    fallback_url=f"{BASE}/~chouken/{district}/top.html",
                    operator=f"長野県 {office}",
                    page_url=f"{BASE}/~chouken/{district}/top.html",
                    attribution=f"出典：長野県{office}（道路ライブカメラ）",
                    license="unknown",
                    refresh_sec=600,
                    river_or_route=route,
                    address_hint=f"長野県{point}",
                    review_note="長野県建設事務所の道路カメラ。利用条件はレビューで確認",
                ))
        if not result.candidates:
            result.errors.append("nagano_road: カメラが1件も取れない")
        return result
