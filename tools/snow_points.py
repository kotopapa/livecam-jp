"""道路管理者が公開する積雪深センサーの値を集約し、配信用 JSON にまとめる。

アプリの災害速報タブ「積雪」（冬季）は気象庁アメダスの336地点だけでは疎なので、国土交通省と
各県の道路管理者が公開する積雪深の観測値を足して表示する。値は30分おきに集約して配信する
（端末が各サイトへ直接取りに行かない）。

情報源（10。取得経路は SOURCES と各 fetch_* に記載）
- mlit      国土交通省 道路情報提供システム（道路気象。`pc/pcKisho_83_3.html` の
            `backup/<14桁>/<乱数>/` 配下 `Kisho/<整備局CD 81〜90>.json`。sekisetsushin_flag=1 のセンサー）
- tottori   鳥取県 雪みちナビ（yukinavi2.geojson）
- hiroshima ひろしま道路ナビ（getWinter.php）
- ishikawa  石川みち情報ネット（getSnowMaster + getSnow）
- gifu      岐阜県 道の情報（石川と同じ API 形式）
- fukui     みち情報ネットふくい（weathers.json。福井県設置分のみ。気象庁分はアメダスと重複するので除く）
- toyama    富山県道路情報（snow_master.json + snow.json）
- shimane   島根県 道路カメラ情報（data/point.json5 + data/recent_weather.json5）
- okayama   岡山県冬期道路気象情報システム（stations_internal.json + トップページ内の座標表）
- hyogo     兵庫県道路総合管理システム（積雪深 KML の座標 + 地域別一覧 HTML の数値）

出力する点の条件
- 積雪深が数値で取れ、観測時刻が取得時点から24時間以内の地点だけ（欠測・古い値は出さない）
- **気象庁の解析積雪深（PNG タイル）と照合し、周囲 5km が「積雪なし」なのにセンサーが 10cm 以上、
  または 1cm 以上かつ気温 3℃ 以上の地点は誤計測として出さない**（2026-10-31: 無雪期に七尾 166cm・
  京丹波 136cm などの超音波積雪計の誤計測がそのまま配信され、利用者から指摘。各県サイトも生の値を
  出す作りなので配信側で弾く）。解析タイルが取れない回は気温 8℃ 以上の地点だけ弾く
- 気温 t（℃、小数1桁）は取れた情報源だけ付ける（照合に使う。アプリは未使用）
- 積雪深 d は cm の整数（四捨五入）。0 も出す（「積雪なし」）
- 時刻 at は JST の壁時計 "YYYY-MM-DD HH:MM"
- 市区町村コード m は mlit 以外は座標から国土地理院の逆ジオコーダで引く
  （data/municipality_geocache.json を fill_municipality と共用。1回の実行で最大300件）

配信: data/snow_points.json → site/v1/snow_points.json（site/build.py が sync_site でコピー）。
(情報源, 点ID, 積雪深) の集合が変わったときだけ書く。monitor.yml で30分おきに実行。
取得に失敗した情報源は前回の値をそのまま残す。JST で 10/15〜5/15 のあいだだけ動く（--force で無視）。
"""
from __future__ import annotations

import argparse
import html as htmllib
import json
import math
import re
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:  # `python tools/snow_points.py` で起動されたときに tools.* を引けるように
    sys.path.insert(0, str(REPO_ROOT))

DATA_PATH = REPO_ROOT / "data" / "snow_points.json"
SITE_PATH = REPO_ROOT / "site" / "v1" / "snow_points.json"
UA = {"User-Agent": "livecam-jp snow-points (+https://kotopapa.github.io/livecam-jp/)"}
JST = timezone(timedelta(hours=9))
MAX_AGE = timedelta(hours=24)
MAX_DEPTH_CM = 1500          # これを超える値はセンサー異常とみなして捨てる
JMA_SNOW_BASE = "https://www.jma.go.jp/bosai/jmatile/data/snow/"   # 解析積雪深タイル（妥当性の照合用）
ANALYSIS_ZOOM = 8            # 偶数ズームしか生成されない（maxNativeZoom 10）。z8 は 1px ≈ 600m で 5km メッシュに十分
CHECK_RADIUS_KM = 5.0        # この距離だけ四方にずらした点も含めて「周囲に積雪なし」を判定する
IMPLAUSIBLE_MIN_CM = 10      # 解析が積雪なしのとき、これ以上の値は気温によらず誤計測とみなす
IMPLAUSIBLE_TEMP_C = 3.0     # 解析が積雪なしのとき、気温がこれ以上なら 1cm 以上の値も誤計測とみなす
FALLBACK_TEMP_C = 8.0        # 解析タイルが取れない回に、気温だけで誤計測とみなす下限
GEOCODE_LIMIT = 300          # 1回の実行で逆ジオコーダに問い合わせる最大件数
HOST_INTERVAL = 1.5          # 同一ホストへの連続アクセスの間隔（秒）

MLIT_BASE = "https://www.road-info-prvs.mlit.go.jp/roadinfo/"
HYOGO_BASE = "https://road.civil.pref.hyogo.lg.jp/RoadLan/InternetGeneral/"

SOURCES: list[dict[str, str]] = [
    {"id": "mlit", "name": "国土交通省 道路情報提供システム（道路気象）", "short": "国交省",
     "operator": "国土交通省", "url": MLIT_BASE, "attribution": "出典：国土交通省 道路情報提供システム"},
    {"id": "tottori", "name": "鳥取県 雪みちナビ（鳥取県防災情報ポータル）", "short": "鳥取県",
     "operator": "鳥取県", "url": "https://www.tori-bousai.jp/", "attribution": "出典：鳥取県 雪みちナビ"},
    {"id": "hiroshima", "name": "ひろしま道路ナビ（広島県）", "short": "広島県",
     "operator": "広島県", "url": "https://www.roadnavi.pref.hiroshima.lg.jp/",
     "attribution": "出典：広島県 ひろしま道路ナビ"},
    {"id": "hyogo", "name": "兵庫県道路総合管理システム", "short": "兵庫県",
     "operator": "兵庫県", "url": HYOGO_BASE + "Common/RoadLan_Top.aspx",
     "attribution": "出典：兵庫県道路総合管理システム"},
    {"id": "ishikawa", "name": "石川みち情報ネット（石川県）", "short": "石川県",
     "operator": "石川県", "url": "https://douro.pref.ishikawa.lg.jp/", "attribution": "出典：石川県 石川みち情報ネット"},
    {"id": "shimane", "name": "島根県 道路カメラ情報", "short": "島根県",
     "operator": "島根県", "url": "https://www.roadi.pref.shimane.jp/", "attribution": "出典：島根県 道路カメラ情報"},
    {"id": "gifu", "name": "道の情報（岐阜県）", "short": "岐阜県",
     "operator": "岐阜県", "url": "https://douro.pref.gifu.lg.jp/", "attribution": "出典：岐阜県 道の情報"},
    {"id": "fukui", "name": "みち情報ネットふくい（福井県）", "short": "福井県",
     "operator": "福井県", "url": "https://www.hozen.pref.fukui.lg.jp/hozen/yuki/",
     "attribution": "出典：福井県 みち情報ネットふくい"},
    {"id": "toyama", "name": "富山県道路情報（富山県）", "short": "富山県",
     "operator": "富山県", "url": "https://www.toyama-douro.toyama.toyama.jp/",
     "attribution": "出典：富山県 富山県道路情報"},
    {"id": "okayama", "name": "岡山県冬期道路気象情報システム", "short": "岡山県",
     "operator": "岡山県", "url": "https://road-camera.pref.okayama.jp/",
     "attribution": "出典：岡山県冬期道路気象情報システム"},
]
SOURCE_KEYS = ("id", "name", "short", "operator", "url", "attribution")


# ---------------------------------------------------------------- 共通の下ごしらえ

def parse_depth(v: Any) -> float | None:
    """積雪深の生の値 → cm。"-"・"--"・空・null・数値以外は欠測として None。"""
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        x = float(v)
    else:
        s = str(v).strip().replace("cm", "").replace("　", "").strip()
        if not s or set(s) <= {"-", "－", "ー", "―"}:
            return None
        try:
            x = float(s)
        except ValueError:
            return None
    if math.isnan(x) or x < 0 or x > MAX_DEPTH_CM:
        return None
    return x


def parse_temp(v: Any) -> float | None:
    """気温の生の値 → ℃（小数1桁）。欠測・数値以外は None。負の値を受ける点が parse_depth と違う。"""
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        x = float(v)
    else:
        s = str(v).strip().replace("℃", "").replace("　", "").strip()
        if not s or set(s) <= {"-", "－", "ー", "―"}:
            return None
        try:
            x = float(s)
        except ValueError:
            return None
    if math.isnan(x) or not -60 <= x <= 60:
        return None
    return round(x, 1)


def round_cm(x: float) -> int:
    """四捨五入（銀行丸めにしない）。"""
    return int(math.floor(x + 0.5))


def fmt_at(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M")


def parse_at(s: Any) -> datetime | None:
    """観測時刻の文字列 → JST の aware datetime。次の形式を受ける。
    "2026-10-30 20:50:00" / "2026/10/30 20:50" / "202610302000"（12桁）/ "20261030200000"（14桁）"""
    if not s:
        return None
    t = str(s).strip()
    m = re.fullmatch(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T](\d{1,2}):(\d{2})(?::\d{2})?", t)
    if not m:
        m = re.fullmatch(r"(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(?:\d{2})?", t)
    if not m:
        return None
    try:
        return datetime(*(int(g) for g in m.groups()), tzinfo=JST)
    except ValueError:
        return None


def make_point(pid: Any, name: str, lat: Any, lng: Any, depth: Any, at: Any,
               route: str = "", muni: str = "", temp: Any = None) -> dict[str, Any] | None:
    """生の1地点 → 内部表現。座標や名前が無ければ None。d は欠測なら None（後段で落とす）。
    temp（気温）は妥当性の照合に使う。"""
    try:
        la, ln = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    if not (20 < la < 46 and 122 < ln < 154) or not name or pid in (None, ""):
        return None
    p: dict[str, Any] = {"id": str(pid), "n": name.strip(), "lat": round(la, 6), "lng": round(ln, 6)}
    r = " ".join(str(route or "").split())
    if r:
        p["r"] = r
    if re.fullmatch(r"\d{5}", str(muni or "")):
        p["m"] = str(muni)
    d = parse_depth(depth)
    p["d"] = None if d is None else round_cm(d)
    dt = parse_at(at)
    p["at"] = fmt_at(dt) if dt else ""
    t = parse_temp(temp)
    if t is not None:
        p["t"] = t
    return p


def keep_fresh(points: list[dict[str, Any]], now: datetime) -> list[dict[str, Any]]:
    """数値の積雪深があり、観測時刻が24時間以内（未来すぎるものも除く）の地点だけ。"""
    out = []
    for p in points:
        if p.get("d") is None:
            continue
        dt = parse_at(p.get("at"))
        if dt is None:
            continue
        age = now.astimezone(JST) - dt
        if age > MAX_AGE or age < -timedelta(hours=1):
            continue
        out.append(p)
    return out


# ---------------------------------------------------------------- 解析（純粋関数）

def parse_mlit(doc: dict[str, Any]) -> list[dict[str, Any]]:
    """道路情報提供システムの Kisho/<CD>.json → 点。積雪深センサー（sekisetsushin_flag=1）のみ。"""
    out = []
    for recs in (doc or {}).values():
        for r in recs if isinstance(recs, list) else []:
            if not isinstance(r, dict) or str(r.get("sekisetsushin_flag")) != "1":
                continue
            try:
                g = json.loads(r["gis_point"]) if isinstance(r.get("gis_point"), str) else r.get("gis_point")
                lng, lat = g["coordinates"][0], g["coordinates"][1]
            except (KeyError, TypeError, ValueError, IndexError):
                continue
            p = make_point(r.get("sensor_id"), str(r.get("pc_hyoji_meisho") or ""), lat, lng,
                           r.get("snow_amount"), r.get("date_time"),
                           route=r.get("rosen_meisho") or "", muni=_mlit_muni(r.get("cities_cd")),
                           temp=r.get("temperature"))
            if p:
                out.append(p)
    return out


def _mlit_muni(code: Any) -> str:
    """cities_cd は政令市だと市のコード（下3桁 100）で来る。アプリは区単位（アメダスと同じ）で引くので、
    その場合は空にして逆ジオコーダに任せる。"""
    c = str(code or "")
    return "" if len(c) != 5 or c.endswith("00") else c


def parse_tottori(doc: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    for f in (doc or {}).get("features") or []:
        pr = f.get("properties") or {}
        if pr.get("積雪") != "○":
            continue
        try:
            lng, lat = f["geometry"]["coordinates"][:2]
        except (KeyError, TypeError, ValueError):
            continue
        p = make_point(pr.get("id"), str(pr.get("name") or ""), lat, lng, pr.get("積雪深"), pr.get("日時"),
                       route=pr.get("name2") or "", temp=pr.get("気温"))
        if p:
            out.append(p)
    return out


def parse_hiroshima(doc: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    for r in (doc or {}).get("results") or []:
        p = make_point(r.get("id"), str(r.get("site") or ""), r.get("lat"), r.get("lon"),
                       r.get("snow_depth"), r.get("date"), route=r.get("rosenname") or "",
                       temp=r.get("temperature"))
        if p:
            out.append(p)
    return out


def parse_kyoku_api(master: dict[str, Any], snow: dict[str, Any]) -> list[dict[str, Any]]:
    """石川・岐阜の getSnowMaster + getSnow → 点。master に無い id は出さない（type があれば 0 のみ）。"""
    ms = {}
    for m in (master or {}).get("vals") or []:
        if m.get("type", 0) in (0, "0", None):
            ms[m.get("id")] = m
    out = []
    for s in (snow or {}).get("vals") or []:
        m = ms.get(s.get("id"))
        if not m:
            continue
        p = make_point(s.get("id"), str(m.get("pointName") or ""), m.get("latitude"), m.get("longitude"),
                       s.get("snow"), s.get("ts"), route=m.get("route") or "", temp=s.get("temperature"))
        if p:
            out.append(p)
    return out


def parse_fukui(doc: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """weathers.json → 点。isSnowDepth=1 かつ設置者が「福井県」のもの（気象庁分はアメダスと重複）。"""
    out = []
    for w in doc if isinstance(doc, list) else []:
        if w.get("isSnowDepth") != 1 or (w.get("category") or {}).get("name") != "福井県":
            continue
        icons = (w.get("map") or {}).get("icons") or [{}]
        d = w.get("data") or {}
        p = make_point(w.get("id"), str(w.get("name") or ""), icons[0].get("lat"), icons[0].get("lng"),
                       d.get("snowDepth"), d.get("observedAt"), route=(w.get("route") or {}).get("name") or "",
                       temp=d.get("temperature"))
        if p:
            out.append(p)
    return out


def parse_toyama(master: dict[str, Any], snow: dict[str, Any]) -> list[dict[str, Any]]:
    """snow_master.json + snow.json → 点。各地点の最新時刻の snowcover を使う。"""
    out = []
    for key, m in (master or {}).items():
        data = ((snow or {}).get(key) or {}).get("snow_data") or {}
        if not data:
            continue
        latest = max(data)
        p = make_point(key, str(m.get("name") or ""), m.get("lat"), m.get("lng"),
                       (data[latest] or {}).get("snowcover"), latest, route=m.get("rosen") or "",
                       temp=(data[latest] or {}).get("temp"))
        if p:
            out.append(p)
    return out


_JSON5_TOKEN = re.compile(r"""'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"|([A-Za-z_$][\w$]*)(?=\s*:)|,(?=\s*[\]}])""", re.S)


def json5_loads(text: str) -> Any:
    """JSON5（キーが引用符なし・値がシングルクォート・末尾カンマ）を json.loads できる形にして読む。
    文字列リテラルを先にトークンとして切り出すので、値の中の ' や : や , があっても壊れない。"""
    def fix(m: re.Match[str]) -> str:
        sq, dq, key = m.group(1), m.group(2), m.group(3)
        if sq is not None:
            # \' は ' に戻してから JSON 文字列として書き直す（その他のエスケープはそのまま解釈）
            body = re.sub(r"\\(.)", lambda e: "'" if e.group(1) == "'" else e.group(0), sq)
            try:
                return json.dumps(json.loads('"' + body.replace('"', '\\"') + '"'), ensure_ascii=False)
            except ValueError:
                return json.dumps(body, ensure_ascii=False)
        if dq is not None:
            return m.group(0)
        if key is not None:
            return json.dumps(key)
        return ""  # 末尾カンマ
    return json.loads(_JSON5_TOKEN.sub(fix, text.lstrip("﻿")))


def parse_shimane(point_text: str, recent_text: str) -> list[dict[str, Any]]:
    recent = {str(r.get("point_id")): r for r in json5_loads(recent_text) if isinstance(r, dict)}
    out = []
    for m in json5_loads(point_text):
        r = recent.get(str(m.get("point_id")))
        if not r:
            continue
        p = make_point(m.get("point_id"), str(m.get("name") or ""), m.get("lat"), m.get("lng"),
                       r.get("snow_depth"), r.get("ts"), route=m.get("route") or "", temp=r.get("temperature"))
        if p:
            out.append(p)
    return out


OKAYAMA_COORD_RE = re.compile(r"\b(po\d+)\s*:\s*\{\s*lat\s*:\s*([\d.]+)\s*,\s*lng\s*:\s*([\d.]+)\s*\}")


def parse_okayama(stations: list[dict[str, Any]], top_html: str) -> list[dict[str, Any]]:
    coords = {m[1]: (m[2], m[3]) for m in OKAYAMA_COORD_RE.finditer(top_html)}
    out = []
    for s in stations if isinstance(stations, list) else []:
        if str(s.get("id")) not in coords:
            continue
        lat, lng = coords[str(s["id"])]
        # 休止中の観測点は値があっても採らない（d=None にして後段で落とす。全点休止の期間も「解析できた」扱い）
        depth = None if s.get("suspended") else s.get("snow")
        p = make_point(s.get("id"), str(s.get("name") or ""), lat, lng, depth, s.get("data_time"),
                       route=s.get("road") or "", temp=s.get("temp"))
        if p:
            out.append(p)
    return out


def parse_hyogo_kml(kml: bytes | str) -> dict[str, dict[str, Any]]:
    """積雪深 KML → {積雪センサID: {n, lat, lng}}。"""
    root = ET.fromstring(kml)
    ns = root.tag[1:].split("}")[0] if root.tag.startswith("{") else ""
    q = (lambda t: f"{{{ns}}}{t}") if ns else (lambda t: t)
    out: dict[str, dict[str, Any]] = {}
    for pm in root.iter(q("Placemark")):
        name = (pm.findtext(q("name")) or "").strip()
        coords = (pm.findtext(f".//{q('coordinates')}") or "").strip().split(",")
        sid = ""
        for d in pm.iter(q("Data")):
            if d.get("name") == "積雪センサID":
                sid = (d.findtext(q("value")) or "").strip()
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (ValueError, IndexError):
            continue
        if sid and name:
            out[sid] = {"n": name, "lat": lat, "lng": lng}
    return out


HYOGO_ROW_RE = re.compile(
    r'<td align="left">\s*([^<]*?)\s*</td>\s*<td[^>]*>\s*([^<]*?)\s*cm\s*</td>'
    r'(?:\s*<td[^>]*>\s*[^<]*?\s*cm\s*</td>\s*<td[^>]*>\s*([^<]*?)\s*℃\s*</td>)?.*?SDSID=(\d+)', re.S)


def parse_hyogo_list(page: str) -> dict[str, dict[str, Any]]:
    """地域別一覧 HTML 1ページ分 → {積雪センサID: {r: 路線, d: 積雪(cm) or None, t: 気温 or None}}。"""
    out = {}
    for m in HYOGO_ROW_RE.finditer(page):
        route = " ".join(htmllib.unescape(m[1]).split())
        out[m[4]] = {"r": route, "d": parse_depth(m[2]), "t": parse_temp(m[3])}
    return out


def hyogo_list_time(page: str, now: datetime) -> datetime | None:
    """一覧の「10月30日 21時0分現在」→ JST の datetime。年は現在の JST から補い、未来になるなら前年。"""
    m = re.search(r"(\d{1,2})月(\d{1,2})日\s*(\d{1,2})時(\d{1,2})分現在", page)
    if not m:
        return None
    jnow = now.astimezone(JST)
    try:
        dt = datetime(jnow.year, int(m[1]), int(m[2]), int(m[3]), int(m[4]), tzinfo=JST)
        if dt > jnow + timedelta(days=1):
            dt = dt.replace(year=jnow.year - 1)
    except ValueError:
        return None
    return dt


def parse_hyogo(kml: bytes | str, pages: list[str], now: datetime) -> list[dict[str, Any]]:
    """KML（座標）と一覧 HTML（数値）を積雪センサIDで結合。観測時刻は一覧の「現在」表示。"""
    geo = parse_hyogo_kml(kml)
    out = []
    seen: set[str] = set()
    for page in pages:
        at = hyogo_list_time(page, now)
        for sid, v in parse_hyogo_list(page).items():
            g = geo.get(sid)
            if not g or sid in seen:
                continue
            seen.add(sid)
            p = make_point(sid, g["n"], g["lat"], g["lng"], v["d"], fmt_at(at) if at else "", route=v["r"],
                           temp=v.get("t"))
            if p:
                out.append(p)
    return out


# ---------------------------------------------------------------- 取得

class Fetcher:
    """同一ホストへの間隔を空け、UA を付けて取得する。証明書検証は有効のまま。"""

    def __init__(self, interval: float = HOST_INTERVAL) -> None:
        import requests
        self.s = requests.Session()
        self.s.headers.update(UA)
        self.interval = interval
        self.last: dict[str, float] = {}

    def _wait(self, url: str) -> None:
        from urllib.parse import urlsplit
        host = urlsplit(url).netloc
        gap = self.interval - (time.monotonic() - self.last.get(host, -1e9))
        if gap > 0:
            time.sleep(gap)
        self.last[host] = time.monotonic()

    def get(self, url: str, **kw: Any) -> bytes:
        self._wait(url)
        r = self.s.get(url, timeout=30, **kw)
        r.raise_for_status()
        return r.content

    def post(self, url: str, data: dict[str, str]) -> bytes:
        self._wait(url)
        r = self.s.post(url, data=data, timeout=30)
        r.raise_for_status()
        return r.content

    def text(self, url: str, enc: str = "utf-8") -> str:
        return self.get(url).decode(enc, "replace").lstrip("﻿")

    def json(self, url: str) -> Any:
        return json.loads(self.text(url))


def data_dir_of(page: str) -> str | None:
    """気象ページの script src から `backup/<14桁>/<乱数>/`（5分ごとに変わるデータ置き場）を取る。"""
    from tools.road_regulation import data_dir
    return data_dir(page)


def fetch_mlit(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    page = fx.text(MLIT_BASE + "pc/pcKisho_83_3.html")
    d = data_dir_of(page)
    if not d:
        raise RuntimeError("データディレクトリが見つからない")
    doc: dict[str, Any] = {}
    for cd in range(81, 91):
        try:
            doc.update({f"{cd}_{k}": v for k, v in fx.json(f"{MLIT_BASE}{d}Kisho/{cd}.json").items()})
        except Exception as e:  # noqa: BLE001  取れない整備局は飛ばす
            print(f"  mlit: CD{cd} 取得失敗 {type(e).__name__}", file=sys.stderr)
    return parse_mlit(doc)


def fetch_tottori(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    return parse_tottori(fx.json("https://tori-bousai.jp/arcgis/yukinavi2.geojson"))


def fetch_hiroshima(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    return parse_hiroshima(fx.json(
        "https://www.roadnavi.pref.hiroshima.lg.jp/getWinter.php?camera=true&romen=true&area=all&sort=sortno"))


def _fetch_kyoku(host: str) -> Callable[[Fetcher, datetime], list[dict[str, Any]]]:
    def run(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
        return parse_kyoku_api(fx.json(f"https://{host}/api/getSnowMaster"), fx.json(f"https://{host}/api/getSnow"))
    return run


def fetch_fukui(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    return parse_fukui(fx.json("https://www.hozen.pref.fukui.lg.jp/hozen/yuki/assets/jsons/weathers.json"))


def fetch_toyama(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    base = "https://www.toyama-douro.toyama.toyama.jp/json/"
    return parse_toyama(fx.json(base + "snow_master.json"), fx.json(base + "snow.json"))


def fetch_shimane(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    base = "https://www.roadi.pref.shimane.jp/data/"
    return parse_shimane(fx.text(base + "point.json5"), fx.text(base + "recent_weather.json5"))


def fetch_okayama(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    top = "https://road-camera.pref.okayama.jp/"
    return parse_okayama(fx.json(top + "stations_internal.json"), fx.text(top))


HIDDEN_RE = re.compile(r'<input[^>]*type="hidden"[^>]*>', re.I)
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')


def hyogo_hidden_fields(page: str) -> dict[str, str]:
    """ASP.NET WebForms の hidden input（__VIEWSTATE 等）を全部集める。"""
    out = {}
    for tag in HIDDEN_RE.findall(page):
        a = dict(ATTR_RE.findall(tag))
        if a.get("name"):
            out[a["name"]] = htmllib.unescape(a.get("value", ""))
    return out


def fetch_hyogo(fx: Fetcher, now: datetime) -> list[dict[str, Any]]:
    kml = fx.get(HYOGO_BASE + "Map/SnowDepthMapGeneral.aspx")
    pages: list[str] = []
    for area in range(2, 8):
        url = f"{HYOGO_BASE}Yukimiti/RoadLan_SnowDepth_List.aspx?AreaID={area}&Period=0"
        try:
            page = fx.text(url)
        except Exception as e:  # noqa: BLE001
            print(f"  hyogo: AreaID={area} 取得失敗 {type(e).__name__}", file=sys.stderr)
            continue
        pages.append(page)
        for n in range(2, 40):  # 1ページ10件。次のリンクがあるあいだ POST で送る
            if f'id="lnkPage{n:02d}"' not in page:
                break
            form = hyogo_hidden_fields(page)
            form["__EVENTTARGET"] = f"lnkPage{n:02d}"
            form["__EVENTARGUMENT"] = ""
            try:
                page = fx.post(url, form).decode("utf-8", "replace")
            except Exception as e:  # noqa: BLE001  取れなかったページは飛ばす
                print(f"  hyogo: AreaID={area} p{n} 取得失敗 {type(e).__name__}", file=sys.stderr)
                break
            pages.append(page)
    return parse_hyogo(kml, pages, now)


FETCHERS: dict[str, Callable[[Fetcher, datetime], list[dict[str, Any]]]] = {
    "mlit": fetch_mlit, "tottori": fetch_tottori, "hiroshima": fetch_hiroshima,
    "ishikawa": _fetch_kyoku("douro.pref.ishikawa.lg.jp"), "gifu": _fetch_kyoku("douro.pref.gifu.lg.jp"),
    "fukui": fetch_fukui, "toyama": fetch_toyama, "shimane": fetch_shimane,
    "okayama": fetch_okayama, "hyogo": fetch_hyogo,
}


def fetch_source(sid: str, fx: Fetcher, now: datetime) -> list[dict[str, Any]] | None:
    """1情報源の全地点（欠測・古い値を含む）。失敗、または地点が1つも解析できなければ None。"""
    try:
        pts = FETCHERS[sid](fx, now)
    except Exception as e:  # noqa: BLE001
        print(f"{sid}: 取得失敗 {type(e).__name__}: {e}", file=sys.stderr)
        return None
    if not pts:
        print(f"{sid}: 地点を1つも解析できず（構造が変わった可能性）", file=sys.stderr)
        return None
    return pts


# ---------------------------------------------------------------- 妥当性の照合（気象庁 解析積雪深）

def latest_analysis_time(target_times: Any) -> str | None:
    """targetTimes.json（実況と予測が混在・降順とは限らない）から最新の実況（basetime==validtime）を選ぶ。
    アプリの JmaLayers.latestSnowTime と同じ規則。"""
    best = None
    for e in target_times if isinstance(target_times, list) else []:
        if not isinstance(e, dict):
            continue
        b, v, els = e.get("basetime"), e.get("validtime"), e.get("elements")
        if not isinstance(b, str) or b != v or (isinstance(els, list) and "snowd" not in els):
            continue
        if best is None or b > best:
            best = b
    return best


def tile_pixel(lat: float, lng: float, z: int = ANALYSIS_ZOOM) -> tuple[int, int, int, int]:
    """緯度経度 → (タイル x, タイル y, タイル内 px, py)。Web メルカトル・256px。"""
    n = 2 ** z
    x = (lng + 180.0) / 360.0 * n
    la = math.radians(lat)
    y = (1.0 - math.log(math.tan(la) + 1.0 / math.cos(la)) / math.pi) / 2.0 * n
    tx, ty = int(math.floor(x)), int(math.floor(y))
    return tx, ty, min(255, int((x - tx) * 256)), min(255, int((y - ty) * 256))


class SnowAnalysis:
    """気象庁の解析積雪深タイル（snowd）を読んで「その場所に積雪があるか」を返す。
    タイルは塗りのある画素＝積雪あり、透明＝積雪なし（データ無し・海も透明）。取れないタイルは None。"""

    def __init__(self, fx: Fetcher, basetime: str) -> None:
        self.fx = fx
        self.basetime = basetime
        self._tiles: dict[tuple[int, int], Any] = {}
        self.fetched = 0

    @classmethod
    def load(cls, fx: Fetcher) -> SnowAnalysis | None:
        try:
            bt = latest_analysis_time(fx.json(JMA_SNOW_BASE + "targetTimes.json"))
        except Exception as e:  # noqa: BLE001
            print(f"解析積雪深: targetTimes 取得失敗 {type(e).__name__}", file=sys.stderr)
            return None
        return cls(fx, bt) if bt else None

    def _tile(self, x: int, y: int) -> Any:
        key = (x, y)
        if key not in self._tiles:
            from io import BytesIO
            from PIL import Image
            url = f"{JMA_SNOW_BASE}{self.basetime}/none/{self.basetime}/surf/snowd/{ANALYSIS_ZOOM}/{x}/{y}.png"
            try:
                self._tiles[key] = Image.open(BytesIO(self.fx.get(url))).convert("RGBA")
            except Exception as e:  # noqa: BLE001
                print(f"解析積雪深: タイル {x}/{y} 取得失敗 {type(e).__name__}", file=sys.stderr)
                self._tiles[key] = None
            self.fetched += 1
        return self._tiles[key]

    def has_snow(self, lat: float, lng: float) -> bool | None:
        x, y, px, py = tile_pixel(lat, lng)
        im = self._tile(x, y)
        if im is None:
            return None
        return im.getpixel((px, py))[3] > 0

    def zero_around(self, lat: float, lng: float, radius_km: float = CHECK_RADIUS_KM) -> bool | None:
        """その点と四方 radius_km の計5点がすべて積雪なしなら True。どれかに積雪があれば False。
        どれかのタイルが取れなければ None（判定しない）。"""
        dlat = radius_km / 111.0
        dlng = radius_km / (111.0 * max(0.2, math.cos(math.radians(lat))))
        result = True
        for la, ln in ((lat, lng), (lat + dlat, lng), (lat - dlat, lng), (lat, lng + dlng), (lat, lng - dlng)):
            s = self.has_snow(la, ln)
            if s is None:
                return None
            if s:
                result = False
        return result


def is_implausible(p: dict[str, Any], zero_around: bool | None) -> bool:
    """センサー値が誤計測とみなせるか。zero_around は解析積雪深で周囲に積雪が無いか（None=判定できず）。
    - 周囲に積雪なし かつ 10cm 以上 → 誤計測（春の残雪は解析にも出るので、季節によらず使える）
    - 周囲に積雪なし かつ 1cm 以上 かつ 気温 3℃ 以上 → 誤計測
    - 解析が取れないときは 気温 8℃ 以上 かつ 1cm 以上 だけ誤計測
    積雪深 0 の点はそのまま出す。"""
    d = p.get("d") or 0
    t = p.get("t")
    if d <= 0:
        return False
    if zero_around is None:
        return t is not None and t >= FALLBACK_TEMP_C
    if not zero_around:
        return False
    if d >= IMPLAUSIBLE_MIN_CM:
        return True
    return t is not None and t >= IMPLAUSIBLE_TEMP_C


def drop_implausible(points: list[dict[str, Any]], analysis: SnowAnalysis | None
                     ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """→ (残す点, 落とした点)。積雪深 0 の点はタイルを見ずに残す。"""
    kept, dropped = [], []
    for p in points:
        if (p.get("d") or 0) <= 0:
            kept.append(p)
            continue
        zero = analysis.zero_around(p["lat"], p["lng"]) if analysis else None
        (dropped if is_implausible(p, zero) else kept).append(p)
    return kept, dropped


# ---------------------------------------------------------------- 市区町村コード

def attach_municipality(points: list[dict[str, Any]], cache: dict[str, Any],
                        budget: int = GEOCODE_LIMIT, sleep: float = 1.0) -> int:
    """m が無い点に国土地理院の逆ジオコーダで市区町村コードを付ける。控えにあるものは問い合わせない。
    問い合わせは budget 件まで（残りは次回）。戻り値は実際に問い合わせた件数。"""
    from tools.fill_municipality import cache_key, reverse_geocode
    used = 0
    for p in points:
        if p.get("m"):
            continue
        key = cache_key(p["lat"], p["lng"])
        if key not in cache:
            if used >= budget:
                continue
            try:
                cache[key] = reverse_geocode(p["lat"], p["lng"])
            except Exception as e:  # noqa: BLE001
                print(f"  逆ジオコーダ失敗 {p['id']}: {type(e).__name__}", file=sys.stderr)
                time.sleep(3)
                used += 1
                continue
            used += 1
            time.sleep(sleep)
        if cache.get(key):
            p["m"] = cache[key]
    return used


# ---------------------------------------------------------------- 組み立て・配信

def iso(now: datetime) -> str:
    return now.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build(previous: dict[str, Any] | None, fetched: dict[str, list[dict[str, Any]] | None],
          now: datetime) -> dict[str, Any]:
    """配信 JSON。fetched は生の地点（鮮度判定前）。取得に失敗した情報源（None）は前回の内容を残す。"""
    prev = {s["id"]: s for s in (previous or {}).get("sources", [])}
    sources = []
    for src in SOURCES:
        pts = fetched.get(src["id"])
        if pts is None:
            if src["id"] not in prev:
                continue
            # 取得失敗が続いても古い値を出し続けないよう、前回の点も24時間以内のものだけ残す
            kept = dict(prev[src["id"]])
            kept["points"] = keep_fresh(kept.get("points") or [], now)
            sources.append(kept)
            continue
        fresh = sorted(keep_fresh(pts, now), key=lambda p: p["id"])
        sources.append({k: src[k] for k in SOURCE_KEYS} | {
            "fetched_at": iso(now),
            "points": [{k: p[k] for k in ("id", "n", "r", "lat", "lng", "m", "d", "at", "t") if k in p} for p in fresh]})
    return {"version": iso(now), "sources": sources}


def signature(doc: dict[str, Any]) -> list[tuple[str, str, int]]:
    """(情報源, 点ID, 積雪深) の集合。これが変わったときだけ配信を更新する。"""
    return sorted((s["id"], p["id"], int(p["d"])) for s in doc.get("sources", []) for p in s.get("points", []))


def in_season(now: datetime) -> bool:
    """JST で 10/15〜5/15 のあいだ。"""
    j = now.astimezone(JST)
    md = (j.month, j.day)
    return md >= (10, 15) or md <= (5, 15)


def sync_site() -> int:
    if not DATA_PATH.exists():
        return 0
    doc = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    SITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    SITE_PATH.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    return 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="季節ゲートを無視する")
    ap.add_argument("--only", help="この情報源だけ取得する（カンマ区切り。デバッグ用）")
    args = ap.parse_args(argv)

    try:  # 官公庁サイトの中間証明書対策（crawler/main.py と同じ。検証は無効にしない）
        import truststore
        truststore.inject_into_ssl()
    except ImportError:
        pass

    now = datetime.now(timezone.utc)
    if not args.force and not in_season(now):
        print("季節外（10/15〜5/15 のみ取得）")
        return 0

    previous = json.loads(DATA_PATH.read_text(encoding="utf-8")) if DATA_PATH.exists() else None
    only = set(args.only.split(",")) if args.only else None
    fx = Fetcher()
    fetched: dict[str, list[dict[str, Any]] | None] = {}
    for src in SOURCES:
        if only and src["id"] not in only:
            fetched[src["id"]] = None
            continue
        fetched[src["id"]] = fetch_source(src["id"], fx, now)
        pts = fetched[src["id"]]
        print(f"{src['id']}: " + ("失敗（前回の値を維持）" if pts is None
                                   else f"解析 {len(pts)}地点・数値あり {sum(p['d'] is not None for p in pts)}"))
    if all(v is None for v in fetched.values()):
        print("全情報源が取得失敗（前回の配信を維持）")
        return 0

    from tools.fill_municipality import CACHE
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    # 鮮度判定を先に済ませ、配信する点だけを逆ジオコーダにかける
    for sid, pts in fetched.items():
        if pts is not None:
            fetched[sid] = keep_fresh(pts, now)
    # 気象庁の解析積雪深と照合し、無雪なのに積雪ありと言うセンサー（誤計測）を落とす
    analysis = SnowAnalysis.load(Fetcher(interval=0.2))
    if analysis is None:
        print("解析積雪深が取れないため、気温だけで照合")
    for sid, pts in fetched.items():
        if not pts:
            continue
        fetched[sid], dropped = drop_implausible(pts, analysis)
        for p in dropped:
            print(f"{sid}: 誤計測として除外 {p['n']} {p['d']}cm 気温{p.get('t', '?')}℃ ({p['at']})")
    if analysis:
        print(f"解析積雪深 {analysis.basetime} タイル {analysis.fetched}枚で照合")
    budget = GEOCODE_LIMIT
    queried = 0
    for pts in fetched.values():
        if pts:
            n = attach_municipality(pts, cache, budget - queried)
            queried += n
    if queried:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    doc = build(previous, fetched, now)
    counts = {s["id"]: len(s["points"]) for s in doc["sources"]}
    total = sum(counts.values())
    if previous is not None and signature(previous) == signature(doc) and not queried and not _meta_changed(previous, doc):
        print(f"変化なし（{total}地点）")
        return 0
    DATA_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"snow_points.json 更新: {total}地点 " + " ".join(f"{k}={v}" for k, v in counts.items()))
    return 0


def _meta_changed(a: dict[str, Any], b: dict[str, Any]) -> bool:
    """情報源の構成（id の並び）が変わったか。取得失敗での欠落・復活を拾う。"""
    return [s["id"] for s in a.get("sources", [])] != [s["id"] for s in b.get("sources", [])]


if __name__ == "__main__":
    raise SystemExit(main())
