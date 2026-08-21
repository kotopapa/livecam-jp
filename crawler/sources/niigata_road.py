"""新潟県「にいがたLIVEカメラ」道路カメラパーサ（県土木部設置分のみ）。

トップページのHTMLに全448台が埋め込まれている:
  <a id='498' class='ad/,,寒川,,２分間隔,新潟県土木部,...' href='/camera/pc/kangawa.jpg'
     title='一般国道３４５号　寒川'>
class属性のカンマ区切り6番目が運営者。以下は対象外にする:
- 新潟県土木部河川管理課(133台) → kawabou経由で収録済み(重複)
- 国交省各事務所 → kawabou/prvs経由で収録済み
- NEXCO東日本 → 転載禁止方針
座標はページに無いため、テキスト版一覧(select.php)の市町村グループから
地点名→市町村を突き合わせ、address_hint でジオコーディングする。
"""

from __future__ import annotations

import re
import unicodedata

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.live-cam.pref.niigata.jp/"
TOP_URL = BASE
TEXT_URL = BASE + "text/select.php?area={area}&class=1"
# hrefは「/camera/pc/x.jpg」と「camera/pc/x.jpg」の両表記が観測されている
# (2026-08-21にサイト側が先頭スラッシュなしへ変更し0件になった)
CAM_RE = re.compile(
    r"<a id='\d+' class='([^']*)' href='(/?camera/pc/[^']+)' title='([^']+)'")
CITY_HEAD_RE = re.compile(r"link_title[^>]*>>?\s*([^<\s　]+)[\s　]*\[一覧\]")
CITY_CAM_RE = re.compile(r"class='link'[^>]*>([^<]+)</a>")


def norm(s: str) -> str:
    """全角数字・空白ゆれを正規化して突き合わせ用キーにする。"""
    return unicodedata.normalize("NFKC", s).replace(" ", "").replace("　", "")


def parse_top(html: str) -> list[tuple[str, str, str]]:
    """(title, 画像path, 運営者) のリスト。"""
    out = []
    for cls, href, title in CAM_RE.findall(html):
        fields = cls.split(",")
        op = fields[5].strip() if len(fields) > 5 else ""
        out.append((title.strip(), href, op))
    return out


def parse_city_map(html: str) -> dict[str, str]:
    """テキスト版一覧から {正規化地点キー: 市町村名}。"""
    out: dict[str, str] = {}
    city = None
    for m in re.finditer(r"link_title[^>]*>([^<]+)</a>|class='link'[^>]*>([^<]+)</a>",
                         html):
        head, cam = m.group(1), m.group(2)
        if head:
            c = re.sub(r"[>\s　\[\]一覧]", "", head)
            city = c or city
        elif cam and city:
            # "国道7号 紫竹山IC" → 地点名部分をキーに
            out[norm(cam)] = city
    return out


class NiigataRoadParser(SourceParser):
    source_id = "niigata_road"
    seed_url = TOP_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        top = session.fetch(TOP_URL)
        if not top.ok:
            result.errors.append(f"niigata_road: HTTP {top.status}")
            return result

        city_map: dict[str, str] = {}
        for area in (1, 2, 3, 4):
            page = session.fetch(TEXT_URL.format(area=area))
            if page.ok:
                city_map.update(parse_city_map(page.text))

        seen: set[str] = set()
        for title, href, op in parse_top(top.text):
            if op != "新潟県土木部":
                continue
            if href in seen:
                continue
            seen.add(href)
            name = unicodedata.normalize("NFKC", title).replace("　", " ")
            point = name.split(" ")[-1] if " " in name else name
            route = None
            m = re.search(r"(国道\d+号|主要地方道[^ ]+|一般県道[^ ]+|[^ ]+線)", name)
            if m:
                route = m.group(1).replace("一般国道", "国道")
            # テキスト版のリンク名は「国道7号 紫竹山IC」形式。地点名末尾一致で市を引く
            city = None
            key_full = norm(name.replace("一般国道", "国道"))
            for k, v in city_map.items():
                if k == key_full or k.endswith(norm(point)):
                    city = v
                    break
            slug = re.sub(r"[^a-z0-9]+", "-",
                          href.rsplit("/", 1)[-1].split(".")[0].lower())
            result.candidates.append(CameraCandidate(
                id=f"niigata-road-{slug}",
                name=name.replace("一般国道", "国道"),
                category="road",
                prefecture="15",
                feed_type="still_image",
                feed_url=BASE.rstrip("/") + "/" + href.lstrip("/"),
                fallback_url=BASE,
                operator="新潟県",
                page_url=BASE,
                attribution="出典：にいがたLIVEカメラ（新潟県土木部）",
                license="unknown",
                refresh_sec=120,
                river_or_route=route,
                address_hint=f"新潟県{city or ''}{point}",
                review_note="新潟県土木部の道路カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("niigata_road: カメラが1件も取れない")
        return result
