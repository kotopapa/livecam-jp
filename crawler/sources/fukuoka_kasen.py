"""福岡県 河川防災情報（doboku-bousai.pref.fukuoka.lg.jp）河川監視カメラパーサ。

- 座標: 河川カメラ配置図 /river2/map/mapItv_0.html が iframe で読む静的GISデータ
  /river2/map/data/gisItv_0.html に、全局の JSオブジェクト
  `const itvJson = {"date": 'YYYYMMDDHHMM', '<局番>': {"an": 局名, "rn": 河川名,
  "lat": ..., "lng": ..., ...}, ...}` が埋め込まれている（10分更新、Shift_JIS）。
  緯度経度は県システムのマーカー実位置（DMS由来の小数、既存 kawabou の同一局と
  10〜50m一致）→ coord_accuracy=exact
- 所在地（市区町村）: /river2/camera/detail_<局番>.html の「所在地」（例: 福岡市博多区）
  → JIS X 0402 は本ファイルの MUNI_JIS 表で引く
- 画像: /camera/<YYYYMMDD>/<局番3桁>/<局番3桁>_<YYYYMMDDHHMM>_VGA.jpg（640x480。
  QQV=160x120 サムネイルもある）。タイムスタンプ名で固定URLがないため都度解決型
  （feed.type=fukuoka_kasen、feed.url=gisItv_0.html、camera_ref=3桁局番）。
  monitor/main.py が gisItv_0.html を1回取得し resolve_image_urls() で全台を解決して
  status.json の image_url で配信する（saitama_flood 等と同じ一覧1リクエスト型）。
  画像時刻は itvJson の "date"（サムネイル一覧 itv_table の obstime と同じ全局共通値）。
  休止中の局はその時刻の画像が 404 になる → monitor が error 判定する

利用条件: 「ご利用について」(river/html/usageguide/about.html) は速報値の免責のみで
転載・リンクに関する記述なし。県設置のため SPEC 3.3 により license=unknown で人手レビュー。
https は TLS ハンドシェイクに失敗するため http で取得する（アプリは ATS 全体許可済み）。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "http://doboku-bousai.pref.fukuoka.lg.jp"
GIS_URL = BASE + "/river2/map/data/gisItv_0.html"
MAP_URL = BASE + "/river2/map/mapItv_0.html"
DETAIL_URL = BASE + "/river2/camera/detail_{sn}.html"
TERMS_URL = BASE + "/river/html/usageguide/about.html"
PREF = "40"

DATE_RE = re.compile(r'"date"\s*:\s*\'(\d{12})\'')
ENTRY_RE = re.compile(
    r"'(\d+)'\s*:\s*\{(.*?)\n\s*\}", re.S)
FIELD_RE = re.compile(r'"(\w+)"\s*:\s*\'([^\']*)\'')
LOCATION_RE = re.compile(r'<td class="menu">所在地</td><td>([^<]*)</td>')

# 所在地 → JIS X 0402（福岡県 40）。政令市は区コードまで落とす
MUNI_JIS = {
    "北九州市門司区": "40101", "北九州市若松区": "40103", "北九州市戸畑区": "40105",
    "北九州市小倉北区": "40106", "北九州市小倉南区": "40107", "北九州市八幡東区": "40108",
    "北九州市八幡西区": "40109", "北九州市": "40100",
    "福岡市東区": "40131", "福岡市博多区": "40132", "福岡市中央区": "40133",
    "福岡市南区": "40134", "福岡市西区": "40135", "福岡市城南区": "40136",
    "福岡市早良区": "40137", "福岡市": "40130",
    "大牟田市": "40202", "久留米市": "40203", "直方市": "40204", "飯塚市": "40205",
    "田川市": "40206", "柳川市": "40207", "八女市": "40210", "筑後市": "40211",
    "大川市": "40212", "行橋市": "40213", "豊前市": "40214", "中間市": "40215",
    "小郡市": "40216", "筑紫野市": "40217", "春日市": "40218", "大野城市": "40219",
    "宗像市": "40220", "太宰府市": "40221", "古賀市": "40223", "福津市": "40224",
    "うきは市": "40225", "宮若市": "40226", "嘉麻市": "40227", "朝倉市": "40228",
    "みやま市": "40229", "糸島市": "40230", "那珂川市": "40231",
    "宇美町": "40341", "篠栗町": "40342", "志免町": "40343", "須恵町": "40344",
    "新宮町": "40345", "久山町": "40348", "粕屋町": "40349",
    "芦屋町": "40381", "水巻町": "40382", "岡垣町": "40383", "遠賀町": "40384",
    "小竹町": "40401", "鞍手町": "40402", "桂川町": "40421",
    "筑前町": "40447", "東峰村": "40448", "大刀洗町": "40503", "大木町": "40522",
    "広川町": "40544", "香春町": "40601", "添田町": "40602", "糸田町": "40604",
    "川崎町": "40605", "大任町": "40608", "赤村": "40609", "福智町": "40610",
    "苅田町": "40621", "みやこ町": "40625", "吉富町": "40642", "上毛町": "40646",
    "築上町": "40647",
}

# 既存 cameras.json に同一地点（150m以内、または同名で400m以内）のカメラがある局
# （2026-08-29 gisItv_0.html の座標で照合。除外せず note に記す。
#  kawabou-3102xxxxx は「川の防災情報」経由で採用済みの県土整備事務所カメラ＝同一カメラの可能性大）
NEAR_EXISTING = {
    "001": "fukuoka-city-c201 片峰新橋(福岡市)14m / kawabou-310242003 片峰新橋(福岡県土整備事務所)29m",
    "002": "fukuoka-city-c202 筒井橋(福岡市)13m / kawabou-310253001 筒井橋(那珂県土整備事務所)28m",
    "003": "kawabou-310253003 下曰佐(那珂県土整備事務所)94m / fukuoka-city-c203 下曰佐(福岡市)103m",
    "004": "kawabou-310242002 山王橋(福岡県土整備事務所)14m / fukuoka-city-c204 山王橋(福岡市)26m",
    "005": "kawabou-310242001 雨水橋(福岡県土整備事務所)27m / fukuoka-city-c205 雨水橋(福岡市)57m",
    "006": "kawabou-310250001 桜橋(北九州県土整備事務所)47m / kawabou-310241001 桜橋(上流側)(北九州市)260m",
    "007": "fukuoka-city-c207 隅田橋(福岡市)50m / kawabou-310253005 隅田橋(那珂県土整備事務所)130m",
    "016": "kawabou-310254001 畔切橋(南筑後県土整備事務所)30m",
    "017": "kawabou-310256002 上釣橋(北九州県土整備事務所宗像支所)89m",
    "018": "kawabou-310250002 藪瀬(北九州県土整備事務所)14m",
    "019": "kawabou-310255001 長音寺橋(京築県土整備事務所)50m",
    "023": "fukuoka-city-c223 塩原(福岡市)345m / kawabou-310253004 塩原(那珂県土整備事務所)368m（同名）",
    "033": "kawabou-310253002 平成橋(那珂県土整備事務所)100m",
    "037": "kawabou-310256001 四角橋(北九州県土整備事務所宗像支所)27m",
    "040": "kawabou-310243001 西縄手橋(久留米県土整備事務所)8m",
    "042": "kawabou-310249006 十篭橋(八女県土整備事務所)23m",
    "043": "kawabou-310249001 光延橋(八女県土整備事務所)39m",
    "044": "kawabou-310249002 中川原橋(八女県土整備事務所)52m",
    "045": "kawabou-310249004 下八重谷橋(八女県土整備事務所)25m",
    "046": "kawabou-310249003 串毛橋(八女県土整備事務所)102m",
    "047": "kawabou-310249005 蛍橋(八女県土整備事務所)21m",
    "048": "kawabou-310254003 新村橋(南筑後県土整備事務所)19m",
    "049": "kawabou-310254002 松原橋(南筑後県土整備事務所)27m",
    "169": "curated-still-lcdb-33debb5d 県道92号宗像篠栗線東郷第2(宗像市役所・道路)22m",
    "171": "curated-lcdb-bb3208a4 県道401号宗像若宮線田久第3(宗像市役所・道路)46m",
    "195": "curated-r2-d5f488ad 久留米市鳥類センター(別運営)135m",
    "204": "curated-still-lcdb-065678e0 筑後川千年分水路(筑後川河川事務所)139m",
    "233": "mlit-roadinfo-89c01792 重原(九州地整・道路)138m",
}


def parse_gis(html: str) -> tuple[str | None, dict[str, dict[str, str]]]:
    """gisItv_0.html → (画像時刻 YYYYMMDDHHMM, {3桁局番: {an, rn, lat, lng, flagStr, ...}})。"""
    m = DATE_RE.search(html)
    date = m.group(1) if m else None
    sites: dict[str, dict[str, str]] = {}
    for sn, body in ENTRY_RE.findall(html):
        fields = dict(FIELD_RE.findall(body))
        if "an" not in fields:
            continue
        sites[f"{int(sn):03d}"] = fields
    return date, dict(sorted(sites.items()))


def image_url(sn3: str, ts: str) -> str:
    return f"{BASE}/camera/{ts[:8]}/{sn3}/{sn3}_{ts}_VGA.jpg"


def resolve_image_urls(html: str) -> dict[str, tuple[str, str]]:
    """gisItv_0.html から {3桁局番: (最新画像URL, ISO時刻)} を返す（monitor用）。"""
    ts, sites = parse_gis(html)
    if not ts or not sites:
        return {}
    iso = f"{ts[:4]}-{ts[4:6]}-{ts[6:8]}T{ts[8:10]}:{ts[10:12]}:00+09:00"
    return {sn3: (image_url(sn3, ts), iso) for sn3 in sites}


def parse_location(html: str) -> str | None:
    m = LOCATION_RE.search(html)
    return m.group(1).strip() if m else None


def municipality_jis(location: str | None) -> str | None:
    if not location:
        return None
    # 長い名前（区付き）から順に前方一致
    loc = location.replace("惠", "恵")
    for name in sorted(MUNI_JIS, key=len, reverse=True):
        if loc.startswith(name):
            return MUNI_JIS[name]
    # 「行橋上稗田」のように市町村種別が抜けた表記 → 語幹で前方一致
    for name in sorted(MUNI_JIS, key=len, reverse=True):
        stem = name.rstrip("市町村")
        if len(stem) >= 2 and loc.startswith(stem):
            return MUNI_JIS[name]
    return None


class FukuokaKasenParser(SourceParser):
    source_id = "fukuoka_kasen"
    seed_url = GIS_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        page = session.fetch(GIS_URL)
        if not page.ok:
            result.errors.append(f"fukuoka_kasen: HTTP {page.status} {page.error or ''}")
            return result
        ts, sites = parse_gis(page.text)
        if not sites:
            result.errors.append("fukuoka_kasen: gisItv_0.html から局を読めない")
            return result

        for sn3, f in sites.items():
            an, rn = f.get("an", "").strip(), f.get("rn", "").strip()
            lat, lng = f.get("lat", ""), f.get("lng", "")
            try:
                latf, lngf = float(lat), float(lng)
            except ValueError:
                result.errors.append(f"fukuoka_kasen: {sn3} {an} は座標なし（lat={lat!r} lng={lng!r}）")
                latf = lngf = None
            if latf is not None and not (32.5 <= latf <= 34.5 and 129.5 <= lngf <= 131.5):
                result.errors.append(f"fukuoka_kasen: {sn3} {an} の座標が県外 ({lat},{lng})")
                latf = lngf = None

            detail_url = DETAIL_URL.format(sn=int(sn3))
            location = None
            detail = session.fetch(detail_url)
            if detail.ok:
                location = parse_location(detail.text)
            muni = municipality_jis(location)
            if location and not muni:
                result.errors.append(f"fukuoka_kasen: {sn3} 所在地「{location}」のJISコード不明")

            notes = ["福岡県河川防災情報の河川監視カメラ。利用条件はレビューで確認（免責のみ）"]
            if "休止" in an:
                notes.append("局名に「休止中」")
            if sn3 in NEAR_EXISTING:
                notes.append("既存と同一地点の可能性: " + NEAR_EXISTING[sn3])
            if latf is None:
                notes.append("座標未取得（gisItv_0.html に lat/lng なし）")

            name = f"{an}（{rn}）" if rn else an
            result.candidates.append(CameraCandidate(
                id=f"fukuoka-kasen-{sn3}",
                name=name,
                category="river",
                prefecture=PREF,
                municipality=muni,
                river_or_route=rn or None,
                feed_type="fukuoka_kasen",
                feed_url=GIS_URL,
                camera_ref=sn3,
                fallback_url=detail_url,
                operator="福岡県",
                page_url=MAP_URL,
                terms_url=TERMS_URL,
                attribution="映像提供：福岡県（福岡県河川防災情報）",
                license="unknown",
                refresh_sec=600,
                lat=latf, lng=lngf,
                coord_accuracy="exact" if latf is not None else None,
                address_hint=f"福岡県{location}" if location and latf is None else None,
                review_note="。".join(notes),
            ))
        if not result.candidates:
            result.errors.append("fukuoka_kasen: カメラが1件も取れない")
        return result
