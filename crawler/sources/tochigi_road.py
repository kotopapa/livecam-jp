"""栃木県「道路ライブカメラ」(kendo.pref.tochigi.lg.jp/roadcctv) パーサ。

PC版はASP.NET地図でスクレイプ困難だが、モバイル版 m/menu.html に
市町村グループ + 全カメラ(ID・地点名)の一覧がある(Shift_JIS)。
静止画は Portable/<3桁ID>_1.jpg の固定URL(15分更新)。

座標は一覧に無いが、PC版の地域別地図 map/map01〜08.html が国土地理院の標準地図
タイル(ズーム11)を 840×525 に並べた画像で、カメラのアイコン(img#imgNNN、
camera.gif 20×21px)が CSS の left/top で置かれている。地図画像を地理院タイルと
照合して得た各地図の原点(GEOREF)から、アイコン位置を緯度経度に変換する
(2026-10-04。それまでは市町村名のジオコーディングで市役所付近に集まり、
宇都宮環状線のアンダーの位置が全く合っていないと不具合報告があった)。
県の地図はアイコンを手で置いているため精度は ±300m 程度 → coord_accuracy=approx。
地図に無いカメラだけ「栃木県+市町村+地点名」でジオコーディングする。
"""

from __future__ import annotations

import math
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.kendo.pref.tochigi.lg.jp/roadcctv/"
MENU_URL = BASE + "m/menu.html"
IMG_URL = BASE + "Portable/{cid}_1.jpg"
PAGE_URL = BASE
ROW_RE = re.compile(
    r"<dt>([^<]+)</dt>|href=\"\.\./Portable/(\d+)_1\.htm\">([^<]+)<")
MAP_NAMES = [f"map{i:02d}" for i in range(1, 9)]
MAP_URL = BASE + "map/{name}.html"
# 地域別地図の較正値: (ズーム, 原点タイルX, 原点タイルY, 画像左上のタイル内オフセットX px, 同Y px)
# 地図画像(840×525)を地理院 std タイル(z11)のモザイクと正規化相互相関で照合した結果。
# 地図画像が差し替わったら tools 側で再照合して更新する
GEOREF = {
    "map01": (11, 1816, 795, 664, 223),    # 県北部
    "map02": (11, 1816, 795, 138, 394),    # 県北西部
    "map03": (11, 1816, 795, 712, 488),    # 県北東部
    "map04": (11, 1816, 795, 156, 806),    # 県西部
    "map05": (11, 1816, 795, 764, 787),    # 県東部
    "map06": (11, 1816, 795, 106, 1284),   # 県南西部
    "map07": (11, 1816, 795, 750, 1262),   # 県南東部（宇都宮）
    "map08": (11, 1816, 795, 223, 1505),   # 県南部
}
# アイコン(camera.gif 20×21)の指し示す点: 左上から (-1, +18) px。地図枠(#mainPanel)の
# 2px の縁と、アイコンの左下にある脚の位置を OSM の同名アンダーパス12地点で実測した中央値
ICON_DX, ICON_DY = -1, 18
ICON_RE = re.compile(r'id="img(\d+)"[^>]*style="([^"]*)"')


def parse_menu(html: str) -> list[tuple[str, str, str]]:
    """(市町村, カメラID, 地点名) のリスト。"""
    out = []
    city = None
    for m in ROW_RE.finditer(html):
        if m.group(1):
            city = m.group(1).strip()
        elif city:
            out.append((city, m.group(2), m.group(3).strip()))
    return out


def parse_map_icons(html: str) -> dict[str, tuple[int, int]]:
    """地域別地図ページから {カメラID: (left, top)} を取り出す。"""
    out: dict[str, tuple[int, int]] = {}
    for m in ICON_RE.finditer(html):
        st = m.group(2)
        if "display:none" in st.replace(" ", ""):
            continue
        tp = re.search(r"top:\s*(-?\d+)px", st)
        lf = re.search(r"left:\s*(-?\d+)px", st)
        if tp and lf:
            out[m.group(1)] = (int(lf.group(1)), int(tp.group(1)))
    return out


def icon_to_latlng(map_name: str, left: int, top: int) -> tuple[float, float]:
    """地域別地図のアイコン位置(left/top px)を緯度経度にする。"""
    z, x0, y0, ox, oy = GEOREF[map_name]
    n = 2 ** z
    tx = x0 + (ox + left + ICON_DX) / 256
    ty = y0 + (oy + top + ICON_DY) / 256
    lon = tx / n * 360 - 180
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * ty / n))))
    return round(lat, 6), round(lon, 6)


def map_coordinates(pages: dict[str, str]) -> dict[str, tuple[float, float]]:
    """{地図名: HTML} から {カメラID: (lat, lng)} を作る。複数地図にあるものは平均。"""
    acc: dict[str, list[tuple[float, float]]] = {}
    for name, html in pages.items():
        if name not in GEOREF:
            continue
        for cid, (left, top) in parse_map_icons(html).items():
            acc.setdefault(cid, []).append(icon_to_latlng(name, left, top))
    return {cid: (round(sum(p[0] for p in pts) / len(pts), 6),
                  round(sum(p[1] for p in pts) / len(pts), 6))
            for cid, pts in acc.items()}


def _place_hint(name: str) -> str:
    """地点名からジオコーディング用の地名部分を取り出す。"""
    s = re.sub(r"[（(][^）)]*[）)]", "", name)
    s = re.sub(r"(アンダー|トンネル|バイパス|交差点|大橋|橋)$", "", s)
    return s.strip() or name


class TochigiRoadParser(SourceParser):
    source_id = "tochigi_road"
    seed_url = MENU_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(MENU_URL)
        if not page.ok:
            result.errors.append(f"tochigi_road: HTTP {page.status}")
            return result
        pages: dict[str, str] = {}
        for map_name in MAP_NAMES:
            mp = session.fetch(MAP_URL.format(name=map_name))
            if mp.ok:
                pages[map_name] = mp.text
            else:
                result.errors.append(f"tochigi_road: {map_name} HTTP {mp.status}")
        coords = map_coordinates(pages)
        seen: set[str] = set()
        for city, cid, name in parse_menu(page.text):
            if cid in seen:
                continue
            seen.add(cid)
            ll = coords.get(cid)
            result.candidates.append(CameraCandidate(
                id=f"tochigi-road-{cid}",
                name=f"{name}（{city}）",
                category="road",
                prefecture="09",
                feed_type="still_image",
                feed_url=IMG_URL.format(cid=cid),
                fallback_url=PAGE_URL,
                operator="栃木県",
                page_url=PAGE_URL,
                attribution="出典：栃木県道路ライブカメラ（県土整備部）",
                license="unknown",
                refresh_sec=900,
                lat=ll[0] if ll else None,
                lng=ll[1] if ll else None,
                coord_accuracy="approx" if ll else None,
                address_hint=None if ll else f"栃木県{city}{_place_hint(name)}",
                review_note="栃木県道路カメラ(アンダーパス冠水監視等)。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("tochigi_road: カメラが1件も取れない")
        return result
