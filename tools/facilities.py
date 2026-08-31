"""自治体オープンデータ（CKAN）から防災拠点3種を収集して県別JSONに配信する。

    python -m tools.facilities                     # 全ポータルを巡回して data/facilities/ を生成
    python -m tools.facilities --portal bodik      # ポータルを絞る
    python -m tools.facilities --no-geocode        # 住所からの座標補完をしない
    python -m tools.facilities --dry-run           # 採否だけ判定して書き込まない

収集する種別（k）:
    water       給水拠点・応急給水施設・災害時給水ステーション・耐震性貯水槽
    stock       防災備蓄倉庫・防災倉庫・備蓄物資保管場所
    fire_water  消防水利（消火栓・防火水槽・プール等）

なぜCKANなのか:
    給水拠点／備蓄倉庫／消防水利は **国による全国集約が存在しない**。デジタル庁の
    「自治体標準オープンデータセット」に様式（消防水利施設一覧など）はあるが、データ本体は
    各自治体が個別に公開している。その最大の受け皿が BODIK ODCS(data.bodik.jp)で、
    東京都・札幌市・横浜市などは独自CKANを持つ。どれも CKAN の package_search API を
    認証なしで叩ける。したがって「CKANを横断検索してタイトルで拾う」のが唯一現実的な集約手段。

リソース形式:
    CSV と XLSX を読む（`read_csv_text` / `read_xlsx`）。XLSX配信は東京消防庁・福岡市・
    豊田市など件数の多い自治体に多く、1ファイル複数シート・先頭に説明行が入るのが普通なので
    シートごとにヘッダ行を探してから読む。旧形式のXLS（BIFF）は openpyxl で読めないため
    理由を rejected に残してスキップする。

絶対制約（SPEC 2章）との関係:
    - C3/C4: 1req/s以下（BODIKはrobots.txtのCrawl-delay:2に合わせて2秒）、robots.txt を必ず確認
    - C5:    データセットごとにライセンスを記録し、**再配布可のものだけ**を採用する。
             不明・非商用・改変禁止は採用せず、理由を data/facilities/index.json の
             rejected に残す（人が後から見て判断できるようにする）

出力:
    data/facilities/<JIS2桁>.json  {"version","pref","sources":[...],"facilities":[{id,n,a,lat,lng,k,o,s,g}]}
        s = その県ファイルの sources 配列のインデックス（URLを全件に複製すると数MB増えるため）
        g = 1 のとき住所から国土地理院APIで補完した座標（原データに座標が無かった）
    data/facilities/index.json     {"version","counts","total","kinds","sources","rejected",...}
    data/facilities_state.json     前回実行の統計（差分確認用）
    data/facilities_geocache.json  住所→座標のキャッシュ（コミットして月次実行を軽くする）

data/facilities/ はコミットして site/build.py が site/v1/facilities/ へコピーする
（site/v1/ は gitignore で publish.yml が毎回作り直すため）。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import logging
import re
import shutil
import sys
import time
import unicodedata
from datetime import date, datetime, timezone
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data" / "facilities"
STATE_PATH = REPO_ROOT / "data" / "facilities_state.json"
GEOCACHE_PATH = REPO_ROOT / "data" / "facilities_geocache.json"
SITE_DIR = REPO_ROOT / "site" / "v1" / "facilities"

USER_AGENT = "LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)"

log = logging.getLogger("facilities")


# ---------------------------------------------------------------- ポータル定義

# delay: そのホストへの最短リクエスト間隔（秒）。BODIK は robots.txt が Crawl-delay: 2
PORTALS = [
    {"key": "bodik", "name": "BODIK ODCS（九州・全国自治体共同カタログ）",
     "base": "https://data.bodik.jp", "delay": 2.0, "org_name_is_jis": True},
    {"key": "tokyo", "name": "東京都オープンデータカタログサイト",
     "base": "https://catalog.data.metro.tokyo.lg.jp", "delay": 1.5, "default_pref": "13"},
    # 山口県は組織名(name)が全国地方公共団体コード5桁。robots.txt に /api/ の禁止が無い
    {"key": "yamaguchi", "name": "山口県オープンデータカタログサイト",
     "base": "https://yamaguchi-opendata.jp/ckan", "delay": 1.5,
     "org_name_is_jis": True, "default_pref": "35"},
]

# robots.txt が API を拒否しているため対象にしないCKAN（SPEC C4 / 10章）。
# 許諾が得られれば PORTALS に移せる。data/facilities/index.json にも記録される
# CKAN の配布時 robots.txt は User-agent:* に Disallow: /api/ を含む。そのため素のCKANを
# 立てている自治体はほぼ全部ここに落ちる（2026-08-31 に1件ずつ robots.txt を取得して確認）。
# BODIK が使えるのは /api/ の禁止が Sogou/Baiduspider/Bytespider/CCBot 限定だから
_R_API = "robots.txt: Disallow: /api/"
BLOCKED_PORTALS = [
    {"key": "sapporo", "name": "DATA-SMART CITY SAPPORO",
     "base": "https://ckan.pf-sapporo.jp", "reason": _R_API},
    {"key": "yokohama", "name": "横浜市オープンデータポータル",
     "base": "https://data.city.yokohama.lg.jp", "reason": _R_API},
    {"key": "gifu", "name": "岐阜県オープンデータカタログ",
     "base": "https://gifu-opendata.pref.gifu.lg.jp", "reason": _R_API},
    {"key": "kanagawa", "name": "神奈川県オープンデータカタログ",
     "base": "https://catalog.opendata.pref.kanagawa.jp", "reason": _R_API},
    {"key": "akita", "name": "秋田県オープンデータポータル",
     "base": "https://ckan.pref.akita.lg.jp", "reason": _R_API},
    {"key": "odp_jig", "name": "ODP（鯖江市ほか・jig.jp）",
     "base": "https://ckan.odp.jig.jp", "reason": _R_API},
    {"key": "aizu", "name": "DATA for CITIZEN（会津若松市ほか）",
     "base": "https://data.data4citizen.jp", "reason": _R_API},
    {"key": "niigata", "name": "新潟市オープンデータ",
     "base": "http://opendata.city.niigata.lg.jp", "reason": _R_API},
    {"key": "minato", "name": "港区オープンデータカタログ",
     "base": "https://opendata.city.minato.tokyo.jp", "reason": _R_API},
    {"key": "utsunomiya", "name": "宇都宮市オープンデータポータル",
     "base": "https://catalog.city.utsunomiya.tochigi.jp", "reason": _R_API},
    {"key": "kanazawa", "name": "金沢市オープンデータカタログ",
     "base": "https://catalog-data.city.kanazawa.ishikawa.jp", "reason": _R_API},
    {"key": "machida", "name": "町田市オープンデータカタログ",
     "base": "http://opendata.city.machida.tokyo.jp", "reason": _R_API},
    {"key": "toyama_city", "name": "富山市オープンデータ",
     "base": "https://opdt.city.toyama.lg.jp", "reason": _R_API},
    {"key": "sagamihara", "name": "相模原市オープンデータ",
     "base": "http://opendata.city.sagamihara.kanagawa.jp", "reason": _R_API},
    {"key": "tendo", "name": "天童市オープンデータ",
     "base": "http://data.city.tendo.yamagata.jp", "reason": _R_API},
    {"key": "sumoto", "name": "洲本市オープンデータ",
     "base": "https://data.city.sumoto.lg.jp", "reason": _R_API},
    {"key": "geospatial", "name": "G空間情報センター",
     "base": "https://www.geospatial.jp/ckan",
     "reason": "robots.txt: Disallow: /*?* （クエリ付きURL全面禁止＝package_search不可）"},
]

# CKAN(Solr)へは title: フィールド検索で投げる。全文検索(q=消防水利)は日本語の形態素解析で
# 無関係なデータセットまで1000件超ヒットし、ページングでカタログに無駄な負荷をかけるため。
# 実測: 全文検索60リクエスト→87件 vs title:検索13リクエスト→87件（BODIK, 2026-08-31）
SEARCH_QUERIES = [
    "消防水利", "消火栓", "防火水槽",
    "給水拠点", "応急給水", "災害時給水", "給水ステーション",
    "耐震性貯水槽", "飲料水兼用貯水槽", "緊急貯水槽",
    "備蓄倉庫", "防災倉庫", "備蓄物資", "防災備蓄", "災害備蓄", "備蓄品",
    "井戸",   # 防災井戸／防災用井戸／災害時協力井戸（classify が井戸台帳を落とす）
]


# ---------------------------------------------------------------- 分類

# タイトルにこれを含むデータセットだけを採用する（前から順に評価し、最初に当たった種別）
KIND_TITLE_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("stock", ("備蓄倉庫", "防災倉庫", "備蓄物資", "防災備蓄", "備蓄品", "備蓄食料")),
    ("water", ("給水拠点", "応急給水", "災害時給水", "給水ステーション",
               "耐震性貯水槽", "飲料水兼用貯水槽", "緊急貯水槽",
               "災害用井戸", "防災井戸", "防災用井戸", "協力井戸")),
    ("fire_water", ("消防水利", "消火栓", "防火水槽")),
]

# 施設一覧ではなく統計・名簿・報告書のデータセットを弾く
TITLE_EXCLUDE = (
    "事業者", "業者", "名簿", "工事店", "統計", "年鑑", "統計書", "推移", "普及",
    "料金", "人口", "件数", "面積", "レポート", "指針", "カルテ", "の数", "状況",
    "計画", "収支", "実績", "使用量", "有収", "供給水量", "整備率", "充足率",
)

KIND_LABELS = {
    "water": "給水拠点・応急給水施設",
    "stock": "防災備蓄倉庫",
    "fire_water": "消防水利（消火栓・防火水槽）",
}
# 名称列も種別列も無いCSV（例: 北九州市は「水利番号,緯度,経度」だけ）の表示名。
# KIND_LABELS をそのまま使うと2万件に長い文字列が並ぶので短い名前にする
FALLBACK_NAMES = {"water": "給水拠点", "stock": "防災倉庫", "fire_water": "消防水利"}


def classify(title: str) -> str | None:
    """データセットのタイトル → 種別。対象外は None。"""
    t = unicodedata.normalize("NFKC", title or "")
    if any(x in t for x in TITLE_EXCLUDE):
        return None
    for kind, words in KIND_TITLE_KEYWORDS:
        if any(w in t for w in words):
            return kind
    return None


# ---------------------------------------------------------------- ライセンス

# 非商用・改変禁止は先に弾く（"cc-by-nc" は "cc-by" を含むため順序が重要）
_LICENSE_DENY = re.compile(
    r"(non[- ]?commercial|noncommercial|nc-|-nc\b|no[- ]?deriv|-nd\b|cc-nc|禁止|不可)", re.I)
_LICENSE_ALLOW = [
    (re.compile(r"cc[-_ ]?by", re.I), "CC BY"),
    (re.compile(r"(cc[-_ ]?zero|cc0|public\s*domain|パブリックドメイン)", re.I), "CC0"),
    (re.compile(r"(pdl\s*1|public\s*data\s*license)", re.I), "PDL 1.0"),
    (re.compile(r"(政府標準利用規約|公共データ利用規約)"), "政府標準利用規約2.0系"),
    (re.compile(r"odc[-_ ]?by", re.I), "ODC-BY"),
    (re.compile(r"open\s*data\s*commons\s*attribution", re.I), "ODC-BY"),
]


def license_status(license_id: str | None, license_title: str | None) -> tuple[bool, str, str]:
    """(採用可否, 表示ラベル, 理由)。

    再配布可（CC BY / CC0 / PDL1.0 / 政府標準利用規約2.0 / ODC-BY）だけを採用する。
    """
    raw = f"{license_id or ''} {license_title or ''}".strip()
    if not raw:
        return False, "不明", "ライセンス未記載"
    if _LICENSE_DENY.search(raw):
        return False, raw, "非商用または改変禁止"
    for pat, label in _LICENSE_ALLOW:
        if pat.search(raw):
            return True, label, ""
    return False, raw, "再配布可と判定できないライセンス"


# ---------------------------------------------------------------- 都道府県コード

PREFECTURES = {
    "北海道": "01", "青森県": "02", "岩手県": "03", "宮城県": "04", "秋田県": "05",
    "山形県": "06", "福島県": "07", "茨城県": "08", "栃木県": "09", "群馬県": "10",
    "埼玉県": "11", "千葉県": "12", "東京都": "13", "神奈川県": "14", "新潟県": "15",
    "富山県": "16", "石川県": "17", "福井県": "18", "山梨県": "19", "長野県": "20",
    "岐阜県": "21", "静岡県": "22", "愛知県": "23", "三重県": "24", "滋賀県": "25",
    "京都府": "26", "大阪府": "27", "兵庫県": "28", "奈良県": "29", "和歌山県": "30",
    "鳥取県": "31", "島根県": "32", "岡山県": "33", "広島県": "34", "山口県": "35",
    "徳島県": "36", "香川県": "37", "愛媛県": "38", "高知県": "39", "福岡県": "40",
    "佐賀県": "41", "長崎県": "42", "熊本県": "43", "大分県": "44", "宮崎県": "45",
    "鹿児島県": "46", "沖縄県": "47",
}
_PREF_ORDER = sorted(PREFECTURES, key=len, reverse=True)  # 「和歌山県」を「和歌山」より先に
_PREF_CODES = set(PREFECTURES.values())


def pref_code_from_text(text: str | None) -> str | None:
    """文字列（住所・都道府県名）に含まれる都道府県名 → JIS2桁。"""
    s = unicodedata.normalize("NFKC", (text or "").strip())
    if not s:
        return None
    for name in _PREF_ORDER:
        if name in s:
            return PREFECTURES[name]
    # 「県/府/都」抜きの表記も許す（例: 組織名が「大阪」）。
    # 「石川町(福島県)」を石川県にしないよう完全一致に限る
    for name in _PREF_ORDER:
        if s == name[:-1]:
            return PREFECTURES[name]
    return None


def pref_code_from_jis(code: str | None) -> str | None:
    """全国地方公共団体コード（5〜6桁）／都道府県コード → JIS2桁。"""
    s = re.sub(r"\D", "", str(code or ""))
    if not s:
        return None
    if len(s) >= 5:
        s = s[:2]
    elif len(s) <= 2:
        s = s.zfill(2)
    else:
        return None
    return s if s in _PREF_CODES else None


# ---------------------------------------------------------------- CSV 正規化

def normalize_header(name: str) -> str:
    """列名の表記ゆれを吸収（全角記号・空白・BOM）。"""
    s = unicodedata.normalize("NFKC", (name or "").replace("﻿", ""))
    return re.sub(r"\s+", "", s)


def _row_dict(cols: list[str], cells: list[str]) -> dict | None:
    """列名リスト＋セル列 → dict。全セル空なら None（空行）。

    同名の列が複数ある表（「設置場所」が2列など）では値が入っている方を残す。
    """
    row: dict[str, str] = {}
    for i, col in enumerate(cols):
        if not col:
            continue
        v = (cells[i] if i < len(cells) else "") or ""
        v = v.strip()
        if v or col not in row:
            row[col] = v
    return row if any(row.values()) else None


def read_csv_text(text: str) -> list[dict]:
    """CSV文字列 → 正規化済み列名のdict列。"""
    reader = csv.reader(io.StringIO(text.lstrip("﻿")))
    try:
        header = next(reader)
    except StopIteration:
        return []
    cols = [normalize_header(c) for c in header]
    rows = []
    for raw in reader:
        rec = _row_dict(cols, list(raw))
        if rec is not None:
            rows.append(rec)
    return rows


def decode_csv(body: bytes) -> str | None:
    """自治体CSVは UTF-8(BOM付) と CP932 が混在する。"""
    for enc in ("utf-8-sig", "cp932", "utf-8"):
        try:
            return body.decode(enc)
        except UnicodeDecodeError:
            continue
    return None


# ---------------------------------------------------------------- XLSX 正規化

# XLSX配信の自治体（東京消防庁・福岡市・豊田市など）は CSV と違い
#   ・1ファイルに複数シート（消火栓／防火水槽、消防署ごと、年度ごと）
#   ・先頭に「※この表は…」「令和6年4月1日現在」等の説明行が数行入る
# のが普通なので、シートごとにヘッダ行を探してから読む。
XLSX_HEADER_HINTS = (
    "名称", "施設名", "所在地", "住所", "緯度", "経度", "種別", "水利", "番号",
    "設置場所", "倉庫名", "備蓄", "口径", "町字", "市区町村", "都道府県",
    "地方公共団体コード", "方書", "管理者", "No", "ＮＯ", "貯水", "管轄",
)
# 説明文の中にヒント語が入っていても数えないための上限（ヘッダの列名は短い）
_HEADER_CELL_MAXLEN = 30


def _cell_text(value) -> str:
    """openpyxl のセル値 → 文字列。数値は「462209.0」にしない。"""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return repr(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value).strip()


def _header_score(cells: list[str]) -> int:
    """その行がヘッダ行らしいか（ヒント語に当たった列の数）。"""
    score = 0
    for c in cells:
        c = normalize_header(c)
        if not c or len(c) > _HEADER_CELL_MAXLEN:
            continue
        if any(h in c for h in XLSX_HEADER_HINTS):
            score += 1
    return score


def _sheet_rows(ws, max_header_scan: int = 25) -> list[dict]:
    """1シート → dict列。先頭数十行からヘッダ行を探し、その下を本文として読む。"""
    it = ws.iter_rows(values_only=True)
    head: list[list[str]] = []
    for raw in it:
        cells = [_cell_text(v) for v in raw]
        if any(cells):
            head.append(cells)
        if len(head) >= max_header_scan:
            break
    if not head:
        return []
    best_i, best_score = -1, 0
    for i, cells in enumerate(head):
        s = _header_score(cells)
        if s > best_score:      # 同点なら上の行を優先（説明行より本物のヘッダが下に来る）
            best_i, best_score = i, s
    if best_score < 2:
        return []               # 凡例シート・グラフシートなど。誤読より捨てる方が安全
    cols = [normalize_header(c) for c in head[best_i]]
    rows: list[dict] = []
    for cells in head[best_i + 1:]:
        rec = _row_dict(cols, cells)
        if rec is not None:
            rows.append(rec)
    for raw in it:
        rec = _row_dict(cols, [_cell_text(v) for v in raw])
        if rec is not None:
            rows.append(rec)
    return rows


def xlsx_error(body: bytes) -> str | None:
    """openpyxl で開けない理由（開けるなら None）。ダウンロード後に中身で判定する。

    CKAN の format 欄は当てにならない（XLS と書いてあって実体は XLSX、逆もある）。
    """
    if body[:2] == b"PK":
        return None
    if body[:8] == b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1":
        return "旧形式のXLS（openpyxl非対応）"
    return "XLSXとして解釈できない内容"


def read_xlsx(body: bytes, max_header_scan: int = 25) -> list[dict]:
    """XLSXバイト列 → 正規化済み列名のdict列（全シート連結）。読めなければ []。"""
    try:
        import openpyxl   # 遅延import: publish環境(site/build.py→sync_site)には無い
    except ImportError:
        log.warning("openpyxl が入っていないため XLSX を読めない")
        return []
    try:
        wb = openpyxl.load_workbook(io.BytesIO(body), read_only=True, data_only=True)
    except Exception as e:
        log.warning("XLSXを開けない (%s: %s)", type(e).__name__, e)
        return []
    rows: list[dict] = []
    try:
        for ws in wb.worksheets:
            try:
                rows.extend(_sheet_rows(ws, max_header_scan))
            except Exception as e:
                log.warning("シート %s を読めない (%s)", getattr(ws, "title", "?"),
                            type(e).__name__)
    finally:
        try:
            wb.close()
        except Exception:
            pass
    return rows


# CKAN の format 欄と URL の拡張子から、表として読めるリソースかを判定する
_FMT_CSV = ("csv",)
_FMT_XLSX = ("xlsx", "xlsm", "xltx", "excel", "msexcel", "vndmsexcel", "openxml")
_FMT_XLS = ("xls",)


def resource_format(res: dict) -> str | None:
    """リソース → "csv" / "xlsx" / "xls" / None（表として読めない）。

    実体を表す拡張子を format 欄より優先する（format に XLS と書きながら
    実体が .xlsx の自治体が実在する）。
    """
    ext = PurePosixPath(urlsplit(res.get("url") or "").path).suffix.lower().lstrip(".")
    fmt = re.sub(r"[^a-z]", "", (res.get("format") or "").lower())
    for token in (ext, fmt):
        if not token:
            continue
        if token in _FMT_CSV:
            return "csv"
        if token in _FMT_XLSX:
            return "xlsx"
        if token in _FMT_XLS:
            return "xls"
    return None


def _pick(row: dict, exact: tuple[str, ...], contains: tuple[str, ...] = (),
          exclude: tuple[str, ...] = ()) -> str:
    for key in exact:
        v = (row.get(key) or "").strip()
        if v:
            return v
    for col, v in row.items():
        if not (v or "").strip():
            continue
        if any(x in col for x in exclude):
            continue
        if any(x in col for x in contains):
            return v.strip()
    return ""


LAT_EXACT = ("緯度", "lat", "Lat", "LAT", "latitude")
LNG_EXACT = ("経度", "lon", "lng", "Lon", "LON", "longitude")
_COORD_EXCLUDE = ("度分秒", "日本測地系", "旧", "X座標", "Y座標", "度分")

NAME_EXACT = ("名称", "施設名", "施設・場所名", "拠点名", "倉庫名", "応急給水施設名称",
              "所在地名称", "拠点給水施設設置場所")
# 施設名でも種別でもない「置かれ方」の列（豊田市の設置場所は「歩道」「車道」）。
# 名称が他に無いときだけ、KIND_EXACT より後に使う
NAME_WEAK = ("設置場所", "場所")
_NAME_EXCLUDE = ("カナ", "英字", "フリガナ", "地方公共団体名", "都道府県名", "市区町村名",
                 "市町村名", "団体名", "分団名", "管理者", "コード", "区域", "地区")

ADDR_EXACT = ("所在地_連結表記", "所在地_連結標記", "所在地", "住所", "設置場所", "場所",
              "所在地名称", "住所(付近)", "設置場所-1(消火栓)", "設置場所-1(水槽)",
              "拠点給水施設設置場所")
ADDR_PARTS = (("所在地_都道府県", "所在地_市区町村", "所在地_町字", "所在地_番地以下"),
              ("都道府県名", "市区町村名", "住所"),
              ("都道府県", "市区町村", "大字"))

KIND_EXACT = ("種別", "水利種別名", "施設種別", "水利区分", "消火栓種類", "分類",
              "水利種別(消火栓)名", "水利種別(防火水槽)名", "設置区分")

JIS_EXACT = ("全国地方公共団体コード", "都道府県コード又は市区町村コード", "市区町村コード",
             "市町村コード", "所在地_全国地方公共団体コード", "地方公共団体コード")
PREF_NAME_EXACT = ("所在地_都道府県", "都道府県名", "都道府県")
MUNI_NAME_EXACT = ("地方公共団体名", "所在地_市区町村", "市区町村名", "市町村名", "市区町村")


def parse_coord(lat_s: str, lng_s: str) -> tuple[float, float] | None:
    """(lat, lng)。日本の範囲外・欠測は None。lat/lng が逆でも救う。"""
    try:
        lat = float(re.sub(r"[^\d.\-+]", "", lat_s or ""))
        lng = float(re.sub(r"[^\d.\-+]", "", lng_s or ""))
    except ValueError:
        return None
    if 20.0 <= lng <= 46.0 and 122.0 <= lat <= 154.0:
        lat, lng = lng, lat  # 列が入れ替わっている自治体がある
    if not (20.0 <= lat <= 46.0 and 122.0 <= lng <= 154.0):
        return None
    return round(lat, 5), round(lng, 5)


def _address(row: dict) -> str:
    a = _pick(row, ADDR_EXACT, contains=("所在地", "住所", "設置場所"),
              exclude=("コード", "ID", "都道府県", "市区町村", "町字", "番地"))
    if a:
        return a
    for parts in ADDR_PARTS:
        vals = [(row.get(p) or "").strip() for p in parts]
        if any(vals):
            return "".join(vals)
    return ""


def _muni(row: dict, fallback: str) -> str:
    for key in MUNI_NAME_EXACT:
        v = (row.get(key) or "").strip()
        if v:
            # 「福岡県福岡市」→「福岡市」
            for name in _PREF_ORDER:
                if v.startswith(name):
                    v = v[len(name):]
                    break
            if v:
                return v
    return fallback


def rows_to_records(rows: list[dict], kind: str, source_index: int,
                    org_title: str, default_pref: str | None = None,
                    id_start: int = 0) -> tuple[list[dict], dict]:
    """CSV行 → 配信レコード。

    座標が取れない行は lat/lng を持たないまま返し、あとで fill_missing_coords が
    住所からジオコーディングする。座標も住所も無い行だけここで捨てる。
    戻り値: ([rec...], stats)。rec の `_pref` は split_by_pref が使う一時フィールド。
    """
    stats = {"rows": len(rows), "no_pref": 0, "no_coord": 0, "no_name": 0}
    out: list[dict] = []
    for i, row in enumerate(rows):
        addr = _address(row)
        # **文字で書かれた県名をJISコードより優先する**。コードは打ち間違いが実在し
        # （紀美野町の消防水利XLSXは市区町村コードが 030306＝岩手県になっていて
        # 603件まるごと別の県に飛ぶ）、県名・住所の方が桁ずれを起こさない
        pref = (pref_code_from_text(_pick(row, PREF_NAME_EXACT))
                or pref_code_from_text(addr)
                or pref_code_from_jis(_pick(row, JIS_EXACT))
                or pref_code_from_text(org_title)
                or default_pref)
        if not pref:
            stats["no_pref"] += 1
            continue
        name = _pick(row, NAME_EXACT, contains=("名称", "施設名"), exclude=_NAME_EXCLUDE)
        kind_label = _pick(row, KIND_EXACT)
        if not name:
            # 施設名が無いCSV/XLSXでは種別を名前にする（「消火栓」「防火水槽」）。
            # 「設置場所」は種別が取れなかったときの最後の手段
            name = kind_label or _pick(row, NAME_WEAK) or FALLBACK_NAMES[kind]
            stats["no_name"] += 1
        muni = _muni(row, org_title)
        rec = {"id": f"{source_index}-{id_start + i}", "n": name[:60], "a": addr[:80],
               "k": kind, "o": muni, "s": source_index, "_pref": pref}
        coord = parse_coord(_pick(row, LAT_EXACT, contains=("緯度",), exclude=_COORD_EXCLUDE),
                            _pick(row, LNG_EXACT, contains=("経度",), exclude=_COORD_EXCLUDE))
        if coord:
            rec["lat"], rec["lng"] = coord
        else:
            stats["no_coord"] += 1
            if not addr:
                continue  # 座標も住所も無い行は救えない
        out.append(rec)
    return out, stats


# ---------------------------------------------------------------- HTTP

class Client:
    """CKAN/CSV 取得。ホストごとに最短間隔を守り、robots.txt を尊重する。"""

    def __init__(self, default_delay: float = 1.1):
        import requests  # 遅延import: publish環境(site/build.py→sync_site)には requests が無い
        try:
            import truststore  # 官公庁サイトは中間証明書が不完全なことがある
            truststore.inject_into_ssl()
        except ImportError:
            pass
        self._requests = requests
        self.session = requests.Session()
        self.session.headers["User-Agent"] = USER_AGENT
        self.default_delay = default_delay
        self._last: dict[str, float] = {}
        self._robots: dict[str, RobotFileParser | None] = {}

    def _wait(self, host: str, delay: float) -> None:
        gap = delay - (time.monotonic() - self._last.get(host, 0.0))
        if gap > 0:
            time.sleep(gap)
        self._last[host] = time.monotonic()

    def robots_ok(self, url: str) -> bool:
        parts = urlsplit(url)
        host = parts.netloc
        if host not in self._robots:
            rp = RobotFileParser()
            rp.set_url(f"{parts.scheme}://{host}/robots.txt")
            try:
                self._wait(host, self.default_delay)
                resp = self.session.get(rp.url, timeout=20)
                if resp.status_code >= 400:
                    rp = None
                else:
                    rp.parse(resp.text.splitlines())
            except self._requests.RequestException:
                rp = None
            self._robots[host] = rp
            if rp is None:
                log.info("robots.txt を取得できず: %s（既定で許可扱い）", host)
        rp = self._robots[host]
        return True if rp is None else rp.can_fetch(USER_AGENT, url)

    def get(self, url: str, params: dict | None = None, delay: float | None = None):
        host = urlsplit(url).netloc
        if not self.robots_ok(url):
            raise PermissionError(f"robots.txt が拒否: {url}")
        self._wait(host, delay if delay is not None else self.default_delay)
        return self.session.get(url, params=params, timeout=120)


def search_datasets(client: Client, portal: dict, queries: list[str]) -> list[dict]:
    """package_search を回してユニークなデータセットを集める。"""
    api = portal["base"] + "/api/3/action/package_search"
    found: dict[str, dict] = {}
    for q in queries:
        start = 0
        while True:
            try:
                resp = client.get(api, params={"q": f"title:{q}", "rows": 100, "start": start},
                                  delay=portal["delay"])
                resp.raise_for_status()
                result = resp.json()["result"]
            except (PermissionError, ValueError, KeyError) as e:
                log.warning("%s: 検索失敗 q=%s (%s)", portal["key"], q, e)
                break
            except Exception as e:  # requests の例外はここで握る（1ポータルの障害で全体を止めない）
                log.warning("%s: 検索失敗 q=%s (%s)", portal["key"], q, type(e).__name__)
                break
            for pkg in result.get("results", []):
                found[pkg["id"]] = pkg
            start += 100
            if start >= result.get("count", 0) or not result.get("results"):
                break
    return list(found.values())


# ---------------------------------------------------------------- 収集本体

def _org_pref(pkg: dict, portal: dict) -> str | None:
    org = pkg.get("organization") or {}
    if portal.get("org_name_is_jis"):
        code = pref_code_from_jis(org.get("name"))
        if code:
            return code
    return pref_code_from_text(org.get("title")) or portal.get("default_pref")


def collect(client: Client, portals: list[dict], limit_datasets: int | None = None
            ) -> tuple[list[dict], list[dict], list[dict]]:
    """(records, sources, rejected)。records の _pref はまだ県別に分けていない。"""
    records: list[dict] = []
    sources: list[dict] = []
    rejected: list[dict] = []
    for portal in portals:
        pkgs = search_datasets(client, portal, SEARCH_QUERIES)
        log.info("%s: 検索ヒット %d件", portal["key"], len(pkgs))
        picked = 0
        for pkg in sorted(pkgs, key=lambda p: p.get("name", "")):
            title = pkg.get("title") or ""
            kind = classify(title)
            if not kind:
                continue
            org_title = (pkg.get("organization") or {}).get("title") or ""
            page = f"{portal['base']}/dataset/{pkg.get('name')}"
            ok, label, reason = license_status(pkg.get("license_id"), pkg.get("license_title"))
            if not ok:
                rejected.append({"portal": portal["key"], "org": org_title, "title": title,
                                 "url": page, "license": label, "reason": reason})
                continue
            tabular = [(r, resource_format(r)) for r in pkg.get("resources", [])
                       if r.get("url")]
            tabular = [(r, f) for r, f in tabular if f]
            if not tabular:
                fmts = sorted({(r.get("format") or "?").upper() for r in pkg.get("resources", [])})
                rejected.append({"portal": portal["key"], "org": org_title, "title": title,
                                 "url": page, "license": label,
                                 "reason": f"表形式リソースなし（{','.join(fmts) or 'なし'}）"})
                continue
            if limit_datasets is not None and picked >= limit_datasets:
                break
            source_index = len(sources)
            src = {"portal": portal["name"], "org": org_title, "title": title, "url": page,
                   "license": label, "license_id": pkg.get("license_id"),
                   "updated": pkg.get("metadata_modified"), "kind": kind, "count": 0}
            rows_seen = 0   # 同一データセット内の複数ファイルでIDが衝突しないための連番オフセット
            kept = 0
            errors: list[str] = []   # 読めなかったリソースの理由（rejected に残す）
            for res, res_fmt in tabular:
                if not (res.get("url") or "").startswith("http"):
                    continue
                try:
                    resp = client.get(res["url"], delay=portal["delay"])
                    resp.raise_for_status()
                except PermissionError as e:
                    log.warning("robots.txt 拒否のため取得せず: %s", e)
                    errors.append("robots.txt拒否")
                    continue
                except Exception as e:
                    log.warning("取得失敗 %s (%s)", res["url"], type(e).__name__)
                    errors.append(f"取得失敗({type(e).__name__})")
                    continue
                if res_fmt == "csv":
                    text = decode_csv(resp.content)
                    if text is None:
                        log.warning("文字コード判別不可: %s", res["url"])
                        errors.append("文字コード判別不可")
                        continue
                    rows = read_csv_text(text)
                else:   # xlsx / xls（format欄は当てにならないので中身で判定する）
                    err = xlsx_error(resp.content)
                    if err:
                        log.warning("%s: %s", res["url"], err)
                        errors.append(err)
                        continue
                    rows = read_xlsx(resp.content)
                    if not rows:
                        errors.append("XLSXにヘッダ行を持つ表が無い")
                        continue
                recs, st = rows_to_records(rows, kind, source_index,
                                           org_title, _org_pref(pkg, portal), id_start=rows_seen)
                records.extend(recs)
                rows_seen += st["rows"]
                kept += len(recs)
                log.info("  %s / %s [%s]: %d行 → %d件（座標なし %d, 県不明 %d）",
                         org_title, title, res_fmt, st["rows"], len(recs),
                         st["no_coord"], st["no_pref"])
            if kept == 0:
                reason = "有効な行が0件"
                if errors:
                    reason += f"（{'; '.join(sorted(set(errors)))}）"
                rejected.append({"portal": portal["key"], "org": org_title, "title": title,
                                 "url": page, "license": label, "reason": reason})
                continue
            sources.append(src)   # count は split_by_pref で配信件数に置き換える
            picked += 1
    return records, sources, rejected


_PREF_BY_CODE = {v: k for k, v in PREFECTURES.items()}


def geocode_query(addr: str, pref: str | None, muni: str | None) -> str:
    """ジオコーディングに投げる住所を県・市区町村まで補って一意にする。

    福岡市の消防水利は所在地が「西区姪の浜4丁目0004番地1号」で県も市も入っていない。
    そのまま国土地理院APIに投げると新潟市西区などに当たってしまうため、
    県名・市区町村名が含まれていなければ前に付ける。
    """
    addr = (addr or "").strip()
    if not addr:
        return ""
    if pref_code_from_text(addr):
        return addr                      # すでに県名が入っている
    prefix = _PREF_BY_CODE.get(pref or "", "")
    muni = (muni or "").strip()
    if muni and muni not in addr:
        prefix += muni
    return prefix + addr


def fill_missing_coords(records: list[dict], limit: int = 2000) -> dict:
    """座標が無いレコードを国土地理院 AddressSearch で補完（1req/s・永続キャッシュ）。"""
    from crawler.geocode import Geocoder  # 遅延import（requests に依存するため）

    geo = Geocoder(cache_path=GEOCACHE_PATH)
    stats = {"target": 0, "filled": 0, "failed": 0, "skipped_over_limit": 0}
    tried = 0
    for rec in records:
        if "lat" in rec:
            continue
        stats["target"] += 1
        addr = rec.get("a") or ""
        if addr not in geo.cache:
            # 既存キャッシュ（住所そのまま）を無駄にしないため、当たらないときだけ補う
            addr = geocode_query(addr, rec.get("_pref"), rec.get("o"))
        cached = addr in geo.cache
        if not cached and tried >= limit:
            stats["skipped_over_limit"] += 1
            continue
        if not cached:
            tried += 1
        coord = geo.geocode(addr)
        if coord:
            rec["lat"], rec["lng"] = round(coord[0], 5), round(coord[1], 5)
            rec["g"] = 1  # 住所からの補完であることを明示（原データに座標なし）
            stats["filled"] += 1
        else:
            stats["failed"] += 1
    return stats


# ---------------------------------------------------------------- 出力

ATTRIBUTION = "出典：各自治体のオープンデータ（CC BY 等）／住所からの座標補完は国土地理院API"
NOTICE = (
    "本データは各自治体がオープンデータとして公開している「消防水利施設一覧」"
    "「応急給水施設一覧」「備蓄倉庫一覧」等を加工したものです。"
    "全国を網羅していません（公開している自治体のみ）。"
    "更新時期は自治体ごとに異なり、最新の状況と一致しない場合があります。"
    "消火栓・防火水槽は消防活動用の設備で、一般の方が使用するものではありません。"
    "給水拠点は災害時に開設されるもので、平常時に給水を受けられるとは限りません。"
    "正確な情報は各自治体にご確認ください。"
)


def split_by_pref(records: list[dict], sources: list[dict]) -> dict[str, dict]:
    """県別に振り分け、県ファイル内でだけ通用する source インデックスに詰め直す。

    同じ座標・同じ名称・同じ種別のレコードは1件にまとめる。住所しか無い自治体を
    ジオコーディングすると「町丁目に40本の消火栓が同一座標で積み上がる」ため
    （例: 亀山市は所在地が町丁目までしか無い）。同じ自治体が同種のCSVを
    複数本公開している場合の重複もここで落ちる。
    """
    by_pref: dict[str, dict] = {}
    seen: set[tuple] = set()
    for src in sources:
        src["count"] = 0
    for rec in records:
        if "lat" not in rec:
            continue
        pref = rec.pop("_pref", None)
        if not pref:
            continue
        key = (pref, rec["k"], rec["lat"], rec["lng"], rec["n"])
        if key in seen:
            continue
        seen.add(key)
        sources[rec["s"]]["count"] += 1
        bucket = by_pref.setdefault(pref, {"recs": [], "src_map": {}, "sources": []})
        gi = rec["s"]
        if gi not in bucket["src_map"]:
            bucket["src_map"][gi] = len(bucket["sources"])
            bucket["sources"].append(sources[gi])
        rec = dict(rec, s=bucket["src_map"][gi])
        bucket["recs"].append(rec)
    return by_pref


def write_outputs(by_pref: dict[str, dict], sources: list[dict], rejected: list[dict],
                  version: str, geocode_stats: dict | None = None,
                  out_dir: Path = DATA_DIR) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.json"):
        old.unlink()
    counts: dict[str, int] = {}
    kind_counts: dict[str, int] = {}
    for pref in sorted(by_pref):
        bucket = by_pref[pref]
        recs = bucket["recs"]
        counts[pref] = len(recs)
        for rec in recs:
            kind_counts[rec["k"]] = kind_counts.get(rec["k"], 0) + 1
        (out_dir / f"{pref}.json").write_text(
            json.dumps({"version": version, "pref": pref,
                        "sources": bucket["sources"], "facilities": recs},
                       ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    index = {
        "version": version,
        "counts": counts,
        "total": sum(counts.values()),
        "kinds": KIND_LABELS,
        "kind_counts": kind_counts,
        "record_fields": {
            "id": "県ファイル内で一意", "n": "名称", "a": "住所", "lat": "緯度", "lng": "経度",
            "k": "種別(water/stock/fire_water)", "o": "自治体名",
            "s": "県ファイルの sources 配列のインデックス",
            "g": "1なら住所から国土地理院APIで補完した座標",
        },
        "geocoded": (geocode_stats or {}).get("filled", 0),
        "blocked_portals": BLOCKED_PORTALS,
        "sources": sources,
        "rejected": rejected,
        "notice": NOTICE,
        "attribution": ATTRIBUTION,
    }
    (out_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    return index


def sync_site(src: Path = DATA_DIR, dst: Path = SITE_DIR) -> int:
    """data/facilities/ → site/v1/facilities/ へコピー（site/build.py からも呼ばれる）。"""
    if not src.exists():
        return 0
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in src.glob("*.json"):
        shutil.copy2(p, dst / p.name)
        n += 1
    return n


# ---------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--portal", action="append", choices=[p["key"] for p in PORTALS],
                    help="対象ポータル（繰り返し指定可。既定は全部）")
    ap.add_argument("--limit-datasets", type=int, metavar="N",
                    help="ポータルごとに採用するデータセット数の上限（動作確認用）")
    ap.add_argument("--no-geocode", action="store_true", help="住所からの座標補完をしない")
    ap.add_argument("--geocode-limit", type=int, default=2000,
                    help="1回の実行で新規に問い合わせる住所の上限（既定 2000）")
    ap.add_argument("--dry-run", action="store_true", help="ファイルを書かない")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    portals = [p for p in PORTALS if not args.portal or p["key"] in args.portal]
    client = Client()
    records, sources, rejected = collect(client, portals, args.limit_datasets)
    log.info("採用データセット %d件 / 除外 %d件 / レコード %d件",
             len(sources), len(rejected), len(records))

    geocode_stats = None
    if not args.no_geocode:
        geocode_stats = fill_missing_coords(records, args.geocode_limit)
        log.info("座標補完: 対象 %d件 → 補完 %d件（失敗 %d, 上限で見送り %d）",
                 geocode_stats["target"], geocode_stats["filled"],
                 geocode_stats["failed"], geocode_stats["skipped_over_limit"])
    dropped = sum(1 for r in records if "lat" not in r)
    if dropped:
        log.info("座標を得られず除外: %d件", dropped)

    by_pref = split_by_pref(records, sources)
    if args.dry_run:
        log.info("dry-run: %d県 合計 %d件", len(by_pref),
                 sum(len(b["recs"]) for b in by_pref.values()))
        return 0

    version = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    index = write_outputs(by_pref, sources, rejected, version, geocode_stats)
    sync_site()
    STATE_PATH.write_text(json.dumps({
        "version": version, "total": index["total"], "counts": index["counts"],
        "kind_counts": index["kind_counts"], "sources": len(sources),
        "rejected": len(rejected), "dropped_no_coord": dropped,
        "geocode": geocode_stats,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    log.info("生成: %d県 合計 %d件 → %s", len(index["counts"]), index["total"], DATA_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
