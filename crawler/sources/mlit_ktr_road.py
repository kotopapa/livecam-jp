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
- 大宮・横浜・甲府・長野はURL規則が別系統のため事務所別ストラテジで対応:
  * 大宮: 地区ページの表（thead th=名前+個別ページ、tbody img=画像）を列順で対応付け
  * 横浜: 1ページに絶対配置divで画像と名前ラベル → left座標の近さで対応付け
  * 甲府: 地点ページ（Shift_JIS）の iframe src の CCTV番号 → Camera.jpg
  * 長野: 路線別マップの area onMouseOver レイヤ名 ↔ img name 属性で対応付け
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


# ---- 大宮国道（地区ページの表構造） ------------------------------------

OOMIYA_INDEX = "https://www.ktr.mlit.go.jp/oomiya/oomiya_livecamera01.html"
OOMIYA_IMG_RE = re.compile(r"/oomiya/livecamera/(\d+)_([A-Za-z])\.jpg")


def oomiya_cameras(html: str, page_url: str) -> list[tuple[str, str, str, str]]:
    """(画像キー, 画像URL, カメラ名, 個別ページURL)。表の列順で名前と画像を対応付ける。"""
    soup = BeautifulSoup(html, "html.parser")
    out: list[tuple[str, str, str, str]] = []
    for table in soup.find_all("table"):
        # thead/tbody が3列ごとに繰り返される構造のため、表全体の th と img を
        # 文書順で対応付ける（件数が一致しない表は対応付け不能としてスキップ）
        heads: list[tuple[str, str]] = []
        for th in table.find_all("th"):
            a = th.find("a", href=True)
            name = re.sub(r"^（\d+）\s*", "", th.get_text(" ", strip=True))
            heads.append((name, urljoin(page_url, a["href"]) if a else page_url))
        imgs: list[tuple[str, str]] = []
        for img in table.find_all("img", src=True):
            m = OOMIYA_IMG_RE.search(urljoin(page_url, img["src"]))
            if m:
                imgs.append((f"{m.group(1)}{m.group(2).lower()}",
                             f"https://www.ktr.mlit.go.jp/oomiya/livecamera/"
                             f"{m.group(1)}_{m.group(2)}.jpg"))
        if not imgs or len(heads) != len(imgs):
            continue
        for (name, link), (key, url) in zip(heads, imgs):
            out.append((key, url, name, link))
    return out


# ---- 横浜国道（箱根新道。絶対配置divのleft座標で名前と画像を対応付け） --

YOKOHAMA_URL = "https://www.ktr.mlit.go.jp/yokohama/live-camera/live.html"
YOKOHAMA_IMG_RE = re.compile(r"Now(\d+)([a-z])\.jpg")


def yokohama_cameras(html: str, page_url: str) -> list[tuple[str, str, str]]:
    """(画像キー, 画像URL, カメラ名)。"""
    soup = BeautifulSoup(html, "html.parser")

    def left_of(tag) -> int:
        m = re.search(r"left\s*:\s*(\d+)", tag.get("style", "") or "")
        return int(m.group(1)) if m else 0

    labels: list[tuple[int, str]] = []
    imgs: list[tuple[int, str, str]] = []
    for div in soup.find_all("div"):
        img = div.find("img", src=True)
        if img:
            m = YOKOHAMA_IMG_RE.search(img["src"])
            if m:
                imgs.append((left_of(div), f"{m.group(1)}{m.group(2)}",
                             urljoin(page_url, img["src"])))
                continue
        m = re.search(r"■\s*(.+?)\s*[(（]ライブ画像", div.get_text(" ", strip=True))
        if m:
            labels.append((left_of(div), m.group(1)))
    out = []
    for left, key, url in imgs:
        name = (min(labels, key=lambda t: abs(t[0] - left))[1] if labels else "")
        out.append((key, url, name))
    return out


# ---- 甲府河川国道（みちカメラ。地点ページの iframe から CCTV 番号を得る） --

KOUFU_INDEX = "https://www.ktr.mlit.go.jp/koufu/michi_camera/index.htm"
KOUFU_IFRAME_RE = re.compile(r"livecamera/CCTV/(\d+)/CAMframe\.html")
KOUFU_LINK_RE = re.compile(r"/koufu/livecamera/michi/[a-z0-9_]+\.html?$")


def koufu_camera(html: str, page_url: str) -> tuple[str, str, str | None] | None:
    """地点ページから (CCTV番号, カメラ名, 路線)。カメラページでなければ None。"""
    soup = BeautifulSoup(html, "html.parser")
    num = None
    for iframe in soup.find_all("iframe", src=True):
        m = KOUFU_IFRAME_RE.search(urljoin(page_url, iframe["src"]))
        if m:
            num = m.group(1)
            break
    if num is None:
        return None
    name, route = "", None
    if soup.title and soup.title.string:
        head = re.split(r"[|｜]", soup.title.get_text())[0].strip()
        m = re.match(r"(.+?)[:：](.+)", head)
        if m:
            route, name = m.group(1).strip(), m.group(2).strip()
        else:
            name = head
    return num, name, route


# ---- 長野国道（道路情報システム。マップの area ↔ img をレイヤ名で対応付け） --

NAGANO_MAPS = [
    ("https://www.ktr.mlit.go.jp/nagano/douroinfo/road/html/map/cameraMap_18.html", "国道18号"),
    ("https://www.ktr.mlit.go.jp/nagano/douroinfo/road/html/map/cameraMap_19.html", "国道19号"),
    ("https://www.ktr.mlit.go.jp/nagano/douroinfo/road/html/map/cameraMap_20.html", "国道20号"),
    ("https://www.ktr.mlit.go.jp/nagano/douroinfo/road/html/map/cameraMap_201.html", None),
]
NAGANO_IMG_RE = re.compile(r"/data/camera/cond_m/(\d+)_L\.jpg")
LAYER_RE = re.compile(r"MM_showHideLayers\('([^']+)'")


def nagano_map_cameras(html: str, page_url: str) -> list[tuple[str, str, str]]:
    """(画像コード, 画像URL, 地名)。"""
    soup = BeautifulSoup(html, "html.parser")
    img_by_layer: dict[str, tuple[str, str]] = {}
    for img in soup.find_all("img", src=True):
        m = NAGANO_IMG_RE.search(urljoin(page_url, img["src"]))
        if m and img.get("name"):
            img_by_layer[img["name"]] = (m.group(1), urljoin(page_url, img["src"]))
    out = []
    for area in soup.find_all("area"):
        alt = (area.get("alt") or "").strip()
        m = LAYER_RE.search(area.get("onmouseover", "") or "")
        if not (alt and m):
            continue
        pair = img_by_layer.pop(m.group(1), None)
        if pair:
            out.append((pair[0], pair[1], alt))
    return out


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

        self._discover_oomiya(session, result)
        self._discover_yokohama(session, result)
        self._discover_koufu(session, result)
        self._discover_nagano(session, result)
        return result

    # ---- 事務所別ストラテジ -----------------------------------------

    def _add(self, result: DiscoverResult, *, cam_id: str, name: str, pref: str,
             feed_url: str, operator: str, page_url: str, route: str | None,
             address: str | None, refresh: int = 600, extra_note: str = "") -> None:
        notes = ["県は事務所管轄からの推定"]
        if extra_note:
            notes.append(extra_note)
        result.candidates.append(CameraCandidate(
            id=cam_id, name=name, category="road", prefecture=pref,
            feed_type="still_image", feed_url=feed_url, operator=operator,
            page_url=page_url,
            attribution=f"出典：国土交通省 関東地方整備局 {operator.split()[-1]}",
            license="public_data_1.0", terms_url=TERMS_URL,
            river_or_route=route, refresh_sec=refresh,
            address_hint=address, review_note=" / ".join(notes)))

    def _discover_oomiya(self, session: HttpSession, result: DiscoverResult) -> None:
        index = session.fetch(OOMIYA_INDEX)
        if not index.ok:
            result.errors.append(f"oomiya: index HTTP {index.status} {index.error or ''}")
            return
        seen: set[str] = set()
        pages = [(OOMIYA_INDEX, "")] + extract_camera_links(index.text, OOMIYA_INDEX, "oomiya")
        for url, _ in pages[:MAX_PAGES_PER_OFFICE]:
            page = index if url == OOMIYA_INDEX else session.fetch(url)
            if not page.ok:
                result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                continue
            cams = oomiya_cameras(page.text, url)
            if not cams:
                continue
            title = page_camera_name(page.text) or ""
            route_m = ROUTE_RE.search(title)
            city_m = re.search(r"[一-龥]{1,6}[市町]", title)
            for key, img_url, name, link in cams:
                if key in seen or not name:
                    continue
                seen.add(key)
                self._add(result, cam_id=f"mlit-ktr-road-oomiya-{key}", name=name,
                          pref="11", feed_url=img_url,
                          operator="国土交通省 大宮国道事務所", page_url=link,
                          route=f"国道{route_m.group(1)}号" if route_m else None,
                          address=f"埼玉県{city_m.group(0)}" if city_m else None)
        if not seen:
            result.errors.append("oomiya: カメラが1件も取れない — ページ構造が変わった可能性")

    def _discover_yokohama(self, session: HttpSession, result: DiscoverResult) -> None:
        page = session.fetch(YOKOHAMA_URL)
        if not page.ok:
            result.errors.append(f"yokohama: HTTP {page.status} {page.error or ''}")
            return
        cams = yokohama_cameras(page.text, YOKOHAMA_URL)
        if not cams:
            result.errors.append("yokohama: カメラが1件も取れない — ページ構造が変わった可能性")
        for key, img_url, name in cams:
            self._add(result, cam_id=f"mlit-ktr-road-yokohama-{key}", name=name or key,
                      pref="14", feed_url=img_url,
                      operator="国土交通省 横浜国道事務所", page_url=YOKOHAMA_URL,
                      route="国道1号（箱根新道）", address="神奈川県箱根町")

    def _discover_koufu(self, session: HttpSession, result: DiscoverResult) -> None:
        index = session.fetch(KOUFU_INDEX)
        if not index.ok:
            result.errors.append(f"koufu: index HTTP {index.status} {index.error or ''}")
            return
        soup = BeautifulSoup(index.text, "html.parser")
        spot_urls: dict[str, None] = {}
        # 地点リンクはイメージマップの <area> にある（<a> ではない）
        for tag in soup.find_all(["a", "area"], href=True):
            href = urljoin(KOUFU_INDEX, tag["href"])
            if KOUFU_LINK_RE.search(urlparse(href).path):
                spot_urls.setdefault(href)
        seen: set[str] = set()
        for url in list(spot_urls)[:MAX_PAGES_PER_OFFICE]:
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                continue
            cam = koufu_camera(page.text, url)
            if cam is None:
                continue
            num, name, route = cam
            if num in seen:
                continue
            seen.add(num)
            self._add(result, cam_id=f"mlit-ktr-road-koufu-{num}", name=name or num,
                      pref="19",
                      feed_url=f"https://www.ktr.mlit.go.jp/koufu/livecamera/CCTV/{num}/Camera.jpg",
                      operator="国土交通省 甲府河川国道事務所", page_url=url,
                      route=route, address=None, refresh=1200,
                      extra_note="更新は約20分間隔（事務所ページ記載）")
        if not seen:
            result.errors.append("koufu: カメラが1件も取れない — ページ構造が変わった可能性")

    def _discover_nagano(self, session: HttpSession, result: DiscoverResult) -> None:
        seen: set[str] = set()
        for map_url, route in NAGANO_MAPS:
            page = session.fetch(map_url)
            if not page.ok:
                result.errors.append(f"{map_url}: HTTP {page.status} {page.error or ''}")
                continue
            for code, img_url, alt in nagano_map_cameras(page.text, map_url):
                if code in seen:
                    continue
                seen.add(code)
                self._add(result, cam_id=f"mlit-ktr-road-nagano-{code}", name=alt,
                          pref="20", feed_url=img_url,
                          operator="国土交通省 長野国道事務所", page_url=map_url,
                          route=route, address=f"長野県{alt}")
        if not seen:
            result.errors.append("nagano: カメラが1件も取れない — ページ構造が変わった可能性")
