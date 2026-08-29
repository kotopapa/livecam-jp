"""山口県土木防災情報システム（y-bousai.pref.yamaguchi.lg.jp）河川監視カメラパーサ。

- 一覧: /citizen/camera/krc_camera_list.aspx に58局の最新画像がまとめて載る
  （<img class="Image" src="../../img/cameraImage/<YYYYMMDD>/<HHMM>/133500000<局(3桁)>_M.jpg">。
  10分更新。hidden の hidePctImgDate が表示スロット<YYYYMMDDHHMM>）。
  画像はスロット開始から数分遅れて順次置かれるため、未到着の局は
  cameraErrorImage/imageError_M.png が入る。→ その局は1つ前のスロットのURLで補う
- 座標: /citizen/map/kco_map.aspx?menu=1&officecd=0&datakdcd=13 → 302 →
  /static/citizen/pages/kco_map_13_0_<時刻>.html 内の
  L.marker([lat,lng], {id:'marker_13_<局>_NN' ...}) を読む（小数3桁≒100m精度 → approx）
- 属性: /citizen/camera/krc_camera_station_info.aspx（事務所/市町/住所/水系/河川/局名/ふりがな）。
  市町→JIS コードは一覧ページの <select> option から取る

画像URLはタイムスタンプ名で固定URLがないため都度解決型（feed.type=yamaguchi_kasen、
feed.url=一覧ページ、camera_ref=3桁局番）。monitor/main.py が一覧1枚を取得して
resolve_image_urls() で全台を解決し status.json の image_url で配信する（yamaguchi_romen と同じ）。

利用条件: 「このサイトの利用について」に転載禁止・直リンク禁止の表記なし（リンク自由、
事後連絡の依頼あり）。県設置のため SPEC 3.3 により license=unknown で人手レビュー。
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta
from urllib.parse import urljoin

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://y-bousai.pref.yamaguchi.lg.jp/"
LIST_URL = BASE + "citizen/camera/krc_camera_list.aspx"
MAP_URL = BASE + "citizen/map/kco_map.aspx?menu=1&officecd=0&datakdcd=13"
STATION_INFO_URL = BASE + "citizen/camera/krc_camera_station_info.aspx"
TERMS_URL = BASE + "citizen/mail/kms_internet_usage.html"
SLOT_MINUTES = 10

# 既存 cameras.json に150m以内の別運営カメラがある局（2026-08-29 確認。除外せずnoteに記す）
NEAR_EXISTING = {
    "014": "curated-tys-nihogawa 仁保川（tys本社）から約120m（別運営・動画）",
    "057": "curated-road-cgr-yamaguchi-romen-nishifukawa 西深川（国道191号 峠路面カメラ）から約145m（別運営・道路）",
}

# 一覧の1局ぶん: open_krc_camera('NNN') → <img ... src="..."> → 属性テーブル。
# HTMLに class ="Image" / src="...""（引用符の重複）といった崩れがあるため属性は緩く読む
ITEM_RE = re.compile(
    r"open_krc_camera\s*\(\s*'(\d{3})'\s*\)\"?>\s*<img[^>]*?src=\"([^\"]+)\"(.*?)</table>",
    re.S)
SLOT_RE = re.compile(r'id="ctl00_ContentPlaceHolder1_hidePctImgDate"\s+value="(\d{12})"')
IMG_PATH_RE = re.compile(r"/cameraImage/(\d{8})/(\d{4})/(\d{12})_[MX]\.jpe?g", re.I)
MARKER_RE = re.compile(
    r"L\.marker\(\[\s*([\d.]+)\s*,\s*([\d.]+)\s*\]\s*,\s*\{\s*id:\s*'marker_13_(\d{3})_\d+'")
OPTION_RE = re.compile(r'<option value="(35\d{3})">([^<]+)</option>')
STATION_ROW_RE = re.compile(
    r'cellOffice">\s*<span[^>]*>(.*?)</span>.*?'
    r'cellCity">\s*<span[^>]*>(.*?)</span>.*?'
    r'cellAddr">\s*<span[^>]*>(.*?)</span>.*?<span[^>]*>(.*?)</span>.*?'
    r'cellRSystem">\s*<span[^>]*>(.*?)</span>.*?'
    r'cellRiver">\s*<span[^>]*>(.*?)</span>.*?'
    r"open_krc_camera\('(\d{3})'\)\">\s*<span[^>]*>(.*?)</span>.*?"
    r"\(<span[^>]*>(.*?)</span>\)",
    re.S)


def _iso_from_slot(slot: str) -> str:
    return (f"{slot[:4]}-{slot[4:6]}-{slot[6:8]}T{slot[8:10]}:{slot[10:12]}:00+09:00")


def _prev_slot(slot: str) -> str | None:
    try:
        t = datetime.strptime(slot, "%Y%m%d%H%M")
    except ValueError:
        return None
    return (t - timedelta(minutes=SLOT_MINUTES)).strftime("%Y%m%d%H%M")


def resolve_image_urls(html: str, page_url: str = LIST_URL) -> dict[str, tuple[str, str]]:
    """一覧HTMLから {局番3桁: (最新画像URL, ISO時刻)} を返す（monitor用）。

    画像未到着（imageError）の局は表示スロットの1つ前のスロットURLで補う。
    実在確認は monitor の取得（404なら失敗として数える）に任せる。
    """
    out: dict[str, tuple[str, str]] = {}
    slot_m = SLOT_RE.search(html)
    prev = _prev_slot(slot_m.group(1)) if slot_m else None
    for m in ITEM_RE.finditer(html):
        code, src = m.group(1), m.group(2)
        url = urljoin(page_url, src)
        p = IMG_PATH_RE.search(url)
        if p:
            out[code] = (url, _iso_from_slot(p.group(1) + p.group(2)))
        elif prev:
            out[code] = (
                f"{BASE}img/cameraImage/{prev[:8]}/{prev[8:]}/133500000{code}_M.jpg",
                _iso_from_slot(prev))
    return out


def parse_map_coords(html: str) -> dict[str, tuple[float, float]]:
    """地図ページの L.marker から {局番: (lat, lng)} を返す（河川カメラ marker_13_ のみ）。"""
    coords: dict[str, tuple[float, float]] = {}
    for lat, lng, code in MARKER_RE.findall(html):
        coords.setdefault(code, (float(lat), float(lng)))
    return coords


def parse_station_info(html: str) -> dict[str, dict[str, str]]:
    """局情報ページから {局番: {office, city, addr, system, river, name, kana}} を返す。"""
    out: dict[str, dict[str, str]] = {}
    for office, city, addr1, addr2, system, river, code, name, kana in STATION_ROW_RE.findall(html):
        clean = lambda s: re.sub(r"\s+", " ", s).strip()  # noqa: E731
        out[code] = {
            "office": clean(office), "city": clean(city),
            "addr": clean(addr1 + addr2), "system": clean(system),
            "river": clean(river), "name": clean(name), "kana": clean(kana),
        }
    return out


def parse_city_codes(list_html: str) -> dict[str, str]:
    """一覧ページの市町セレクトから {市町名: JIS 5桁} を返す。"""
    return {name.strip(): code for code, name in OPTION_RE.findall(list_html)}


class YamaguchiKasenParser(SourceParser):
    source_id = "yamaguchi_kasen"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        lst = session.fetch(LIST_URL, use_cache=False)
        if not lst.ok:
            result.errors.append(f"yamaguchi_kasen: 一覧 HTTP {lst.status}")
            return result
        codes = [m.group(1) for m in ITEM_RE.finditer(lst.text)]
        if not codes:
            result.errors.append("yamaguchi_kasen: 一覧からカメラ局を読めない")
            return result
        city_codes = parse_city_codes(lst.text)

        mp = session.fetch(MAP_URL, use_cache=False)
        coords = parse_map_coords(mp.text) if mp.ok else {}
        if not coords:
            result.errors.append(f"yamaguchi_kasen: 地図ページから座標を読めない (HTTP {mp.status})")

        info_page = session.fetch(STATION_INFO_URL, use_cache=False)
        info = parse_station_info(info_page.text) if info_page.ok else {}
        if not info:
            result.errors.append(f"yamaguchi_kasen: 局情報ページを読めない (HTTP {info_page.status})")

        seen: set[str] = set()
        for code in codes:
            if code in seen:
                continue
            seen.add(code)
            st = info.get(code, {})
            name = st.get("name")
            if not name:
                result.errors.append(f"yamaguchi_kasen: 局 {code} の名称が局情報に無い")
                continue
            river = st.get("river") or None
            city = st.get("city") or ""
            disp = f"{name}（{river}）" if river else name
            ll = coords.get(code)
            addr = f"山口県{city}{st.get('addr', '')}".strip() or None
            note = ("山口県土木防災情報システムの河川監視カメラ。座標は地図ページの"
                    "マーカー(小数3桁≒100m)。利用条件: リンク自由・転載禁止表記なし"
                    "(要レビュー)。画像は10分スロットで数分遅れて到着")
            if code in NEAR_EXISTING:
                note += f"。近傍既存: {NEAR_EXISTING[code]}"
            result.candidates.append(CameraCandidate(
                id=f"yamaguchi-kasen-{code}",
                name=disp,
                name_kana=st.get("kana") or None,
                category="river",
                prefecture="35",
                municipality=city_codes.get(city),
                river_or_route=river,
                feed_type="yamaguchi_kasen",
                feed_url=LIST_URL,
                camera_ref=code,
                fallback_url=f"{BASE}citizen/camera/krc_camera.aspx?stncd={code}&obsdt=",
                operator="山口県",
                page_url=LIST_URL,
                terms_url=TERMS_URL,
                attribution="映像提供：山口県（山口県土木防災情報システム）",
                license="unknown",
                refresh_sec=600,
                lat=ll[0] if ll else None, lng=ll[1] if ll else None,
                coord_accuracy="approx" if ll else None,
                address_hint=addr,
                review_note=note,
            ))
        if not result.candidates:
            result.errors.append("yamaguchi_kasen: カメラが1件も取れない")
        return result
