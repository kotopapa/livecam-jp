"""関東地方整備局の道路ライブカメラパーサ（静止画URL共通グループ）。

対象は静止画を共通エンドポイント https://www.ktr.mlit.go.jp/river/cctv/C{5桁}.jpg
から配信している4事務所（宇都宮国道・高崎河川国道・相武国道・北首都国道）。
各事務所の一覧ページ（イメージマップ or メニュー）→ カメラ詳細ページを辿り、
`/river/cctv/C*.jpg` の <img> を収集する。

構造メモ（2026-08 調査）:
- JS描画・JSON APIなし。全て静的HTML。座標の記載はどの事務所にもない
  → ジオコーディング + 手動レビューで確定する
- 北首都のみ frameset + Shift_JIS。ページ本文に住所（例: 埼玉県和光市新倉5丁目）が
  あるため address_hint に使う
- /river/cctv/ には河川カメラも同居する（例 C02030 烏川城南大橋）。名称に河川名を
  含むものは review_note で注意喚起する
- 大宮・横浜・甲府・長野の各事務所はURL規則が別系統（oomiya/livecamera/NN_A.jpg 等）
  のため本パーサの対象外。追加時は別ストラテジで拡張する
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

TERMS_URL = "https://www.ktr.mlit.go.jp/guide/copyright.html"
CCTV_IMG_RE = re.compile(r"/river/cctv/(C\d+)\.jpg")
NAV_SKIP_RE = re.compile(
    r"sitemap|contact|link_|copyright|privacy|accessibility|index\.htm$|/css/|/js/")
ROUTE_RE = re.compile(r"国道\s*([0-9０-９]+)\s*号")
ADDRESS_RE = re.compile(
    r"(?:東京都|北海道|京都府|大阪府|[一-龥]{2,3}県)"
    r"[一-龥ぁ-ゟァ-ヶ0-9０-９]{1,12}[市区町村][一-龥ぁ-ゟァ-ヶ0-9０-９丁目番地ー]{0,20}")
RIVERISH_RE = re.compile(r"[一-龥]{1,6}川[（(]")
MAX_PAGES_PER_OFFICE = 40


@dataclass(frozen=True)
class Office:
    key: str            # ktr.mlit.go.jp 配下のディレクトリ名
    operator: str
    prefecture: str     # JIS 2桁。事務所の管轄からの推定（県境カメラはレビューで修正）
    index_url: str
    default_route: str | None = None


OFFICES = [
    Office("utunomiya", "国土交通省 宇都宮国道事務所", "09",
           "https://www.ktr.mlit.go.jp/utunomiya/utunomiya_index002.html"),
    Office("takasaki", "国土交通省 高崎河川国道事務所", "10",
           "https://www.ktr.mlit.go.jp/takasaki/takasaki_index009.html"),
    Office("sobu", "国土交通省 相武国道事務所", "13",
           "https://www.ktr.mlit.go.jp/sobu/sobu_index018.html",
           default_route="国道20号"),
    Office("kitasyuto", "国土交通省 北首都国道事務所", "11",
           "https://www.ktr.mlit.go.jp/kitasyuto/public/CCTV_L.html",
           default_route="国道298号"),
]


def extract_camera_links(html: str, base_url: str, office_key: str) -> list[tuple[str, str]]:
    """一覧ページから同一事務所配下のカメラ詳細ページ (url, リンクテキスト) を返す。"""
    soup = BeautifulSoup(html, "html.parser")
    found: dict[str, str] = {}
    for tag in soup.find_all(["a", "area"], href=True):
        href = urljoin(base_url, tag["href"])
        parsed = urlparse(href)
        if parsed.netloc not in ("www.ktr.mlit.go.jp", "ktr.mlit.go.jp"):
            continue
        if f"/{office_key}/" not in parsed.path:
            continue
        if not re.search(r"\.html?$", parsed.path):
            continue
        if NAV_SKIP_RE.search(parsed.path) or href == base_url:
            continue
        text = (tag.get("alt") or tag.get_text(" ", strip=True) or "").strip()
        # 同じURLに area(altあり) と a(テキストなし) が並ぶことがあるので、名前付きを優先
        if href not in found or (text and not found[href]):
            found[href] = text
    return list(found.items())


def clean_alt(alt: str) -> str:
    """img の alt からカメラ名を取り出す（「ライブカメラ○○映像」→「○○」）。"""
    name = re.sub(r"ライブカメラ|映像", "", alt or "").replace("　", " ")
    return re.sub(r"\s+", " ", name).strip()


def extract_cctv_images(html: str, page_url: str) -> list[tuple[str, str, str]]:
    """ページ内の /river/cctv/C*.jpg 画像を (C番号, 正規化URL, alt由来の名前) で返す。"""
    soup = BeautifulSoup(html, "html.parser")
    out: dict[str, tuple[str, str]] = {}
    for img in soup.find_all("img", src=True):
        m = CCTV_IMG_RE.search(urljoin(page_url, img["src"]))
        if m:
            cnum = m.group(1)
            out.setdefault(cnum, (f"https://www.ktr.mlit.go.jp/river/cctv/{cnum}.jpg",
                                  clean_alt(img.get("alt", ""))))
    return [(c, url, alt) for c, (url, alt) in out.items()]


def page_camera_name(html: str) -> str | None:
    """<title> の先頭セグメントからカメラ名を取り出す。名前にならなければ None。"""
    soup = BeautifulSoup(html, "html.parser")
    if not soup.title or not soup.title.string:
        return None
    head = re.split(r"[|｜]", soup.title.get_text())[0]
    head = re.sub(r"[一-龥]{2,6}国道事務所|高崎河川国道事務所", "", head)
    head = head.replace("ライブカメラ", "").replace("　", " ")
    head = re.sub(r"\s+", " ", head).strip()
    return head or None


def extract_address_hint(html: str) -> str | None:
    text = BeautifulSoup(html, "html.parser").get_text(" ", strip=True)
    # フッターの事務所所在地を拾わないよう、本文前半のみを対象にする
    m = ADDRESS_RE.search(text[: len(text) // 2] if len(text) > 400 else text)
    return m.group(0) if m else None


class MlitKtrRoadParser(SourceParser):
    source_id = "mlit_ktr_road"
    seed_url = "https://www.mlit.go.jp/road/bosai/LIVEcamera.html"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        seen: set[str] = set()

        for office in OFFICES:
            index = session.fetch(office.index_url)
            if not index.ok:
                result.errors.append(
                    f"{office.key}: index fetch failed HTTP {index.status} {index.error or ''}")
                continue

            # 一覧ページ自身がカメラページを兼ねることがある（相武の大垂水区間など）
            pages: list[tuple[str, str]] = [(office.index_url, "")]
            pages += extract_camera_links(index.text, office.index_url, office.key)

            found_in_office = 0
            for url, link_text in pages[:MAX_PAGES_PER_OFFICE]:
                page = index if url == office.index_url else session.fetch(url)
                if not page.ok:
                    result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                    continue
                html = page.text
                images = extract_cctv_images(html, url)
                if not images:
                    continue
                page_name = page_camera_name(html) or link_text
                address = extract_address_hint(html)
                for cnum, img_url, alt_name in images:
                    if cnum in seen:
                        continue
                    seen.add(cnum)
                    if len(images) == 1:
                        cam_name = page_name or alt_name
                    else:
                        # 1ページ複数カメラは alt の個別名を優先する
                        cam_name = alt_name or (f"{page_name} ({cnum})" if page_name else "")
                    if not cam_name:
                        cam_name = cnum
                    route_m = ROUTE_RE.search(cam_name + " " + link_text)
                    notes = ["県は事務所管轄からの推定"]
                    if RIVERISH_RE.search(cam_name):
                        notes.append("名称に河川名を含む（河川カメラの可能性。カテゴリ要確認）")
                    result.candidates.append(CameraCandidate(
                        id=f"mlit-ktr-road-{cnum.lower()}",
                        name=cam_name,
                        category="road",
                        prefecture=office.prefecture,
                        feed_type="still_image",
                        feed_url=img_url,
                        operator=office.operator,
                        page_url=url,
                        attribution=f"出典：国土交通省 関東地方整備局 {office.operator.split()[-1]}",
                        license="public_data_1.0",
                        terms_url=TERMS_URL,
                        river_or_route=(f"国道{route_m.group(1)}号" if route_m
                                        else office.default_route),
                        refresh_sec=600,
                        address_hint=address,
                        review_note=" / ".join(notes),
                    ))
                    found_in_office += 1

            if found_in_office == 0:
                result.errors.append(
                    f"{office.key}: カメラが1件も取れない — ページ構造が変わった可能性")
        return result
