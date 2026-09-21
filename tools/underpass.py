"""地下道（アンダーパス）の冠水状況を配信用 JSON にまとめる。

自治体がセンサーで公開している「通行可 / 通行注意 / 通行止め」の状態を、
5分おきの bosai-notify.yml から取得して `data/underpass_status.json` に書く。
段階（level）が変わったときだけファイルを更新する（毎回の時刻更新で publish を
走らせない）。site/build.py が `site/v1/underpass_status.json` へコピーする。

情報源（2026-09-21 時点）
- 千葉市地下道冠水情報システム（オサシ・テクノス「フィールド監視システム」上の公開テナント）
  https://pub.os-alert.info/chiba/devmap → `devmap/JSONlist4`（GET・JSON）
  sigfox_states[] に地下道ごとの座標と status1（通行可能 等）、map_marker に
  グループ（地下道）ごとの alarm_level（0=通行可, 1=通行注意, 2=通行止め）が入る。
  同じ地下道に複数センサー（_状況1/_状況2）がある場合は group で1件にまとめる。
  他自治体のテナントは公開されていない（sendai/nagoya 等は JSON なし。2026-09-21確認）
- 静岡市道路通行規制情報「しずみちinfo」（https://shizuokashi-road.appspot.com/）
  API（オープンデータとして提供。config_pub.xml の WebAPIRoot=pub1/）
  `pub1/flood/underpath` → {Success, Data:[{ObserverPointName, AlertMode（正常 等）,
  WaterLevel, UpdateDate, Geometry{Coordinates:[lon,lat]}}]}。19か所
- さいたま市水位情報システム（https://www.flood-info.city.saitama.jp/ 、CC BY 4.0・出典明記）
  地点マスタ `ja/place.json`（place_type 2=道路（アンダーパス）17か所・4=道路（平面）5か所。
  6=冠水センサー40か所は平面道路の「〇〇付近」なので対象外）と最新値 `data/water_level_latest.json`
  （1分更新。type W/WC の水位計は a9 / a0 / c0=欠測・メンテナンス, a3=警戒水位超過, a2=注意水位超過,
  それ以外=平常水位。判定順は SPA の setKansokuLatest と同じ）
- たかまつマイセーフティマップ（高松市。https://safetymap.takamatsu-fact.com/ 、市オープンデータ CC BY 4.0）
  市道アンダーパスの冠水センサー18か所。地図が読む Geolonia 中継の FIWARE ライブデータ
  `api-ws-admin.geolonia.com/v1/channels/cityos-kawaga-takamatsu-FloodSituation/messages`（GET・認証なし。
  開発者ドキュメント非掲載）。msg.status 0=冠水なし / 1=冠水あり、dateIssued は UTC。
  24時間以上更新が無い地点は不明扱い（明神永之谷線は 2025-10 から停止中）
- 兵庫県道路総合管理システム「冠水情報」（https://road.civil.pref.hyogo.lg.jp/ 、県管理アンダーパス25か所）
  KML `RoadLan/InternetGeneral/Map/SubmergenceMap.aspx`（Placemark の styleUrl #1=通常 / #2=冠水通行注意 /
  #3=冠水通行止 / #99=不明（故障）。名前は半角カナ混じりなので NFKC 正規化）。更新時刻は地域別一覧
  `Submerg/RoadLan_Submergence_List.aspx?AreaID=2&Period=0` の「M月D日 H時M分現在」から取る。
  トップページは免責のみで転載・リンク制限の文言なし、robots.txt 無し（2026-09-21 確認）

level: 0=通行可 / 1=通行注意 / 2=通行止め / -1=不明（観測停止・取得失敗）
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = REPO_ROOT / "data" / "underpass_status.json"
SITE_PATH = REPO_ROOT / "site" / "v1" / "underpass_status.json"
UA = {"User-Agent": "livecam-jp underpass (+https://kotopapa.github.io/livecam-jp/)"}

SOURCES: list[dict[str, Any]] = [
    {
        "id": "chiba",
        "name": "千葉市地下道冠水情報システム",
        "operator": "千葉市",
        "prefecture": "12",
        "url": "https://pub.os-alert.info/chiba/devmap",
        "api": "https://pub.os-alert.info/chiba/devmap/JSONlist4",
        "attribution": "出典：千葉市地下道冠水情報システム",
        "kind": "os_alert",
    },
    {
        "id": "shizuoka",
        "name": "静岡市道路通行規制情報「しずみちinfo」",
        "operator": "静岡市",
        "prefecture": "22",
        "url": "https://shizuokashi-road.appspot.com/",
        "api": "https://shizuokashi-road.appspot.com/pub1/flood/underpath",
        "attribution": "出典：静岡市道路通行規制情報「しずみちinfo」",
        "kind": "shizumichi",
    },
    {
        "id": "saitama",
        "name": "さいたま市水位情報システム",
        "operator": "さいたま市",
        "prefecture": "11",
        "url": "https://www.flood-info.city.saitama.jp/",
        "api": "https://www.flood-info.city.saitama.jp/data/water_level_latest.json",
        "master": "https://www.flood-info.city.saitama.jp/ja/place.json",
        "attribution": "出典：さいたま市 水位情報システム（http://www.flood-info.city.saitama.jp）を加工して作成",
        "kind": "saitama",
    },
    {
        "id": "takamatsu",
        "name": "たかまつマイセーフティマップ",
        "operator": "高松市",
        "prefecture": "37",
        "url": "https://safetymap.takamatsu-fact.com/",
        "api": "https://api-ws-admin.geolonia.com/v1/channels/cityos-kawaga-takamatsu-FloodSituation/messages",
        "attribution": "出典：高松市（たかまつマイセーフティマップ）",
        "kind": "takamatsu",
    },
    {
        "id": "hyogo",
        "name": "兵庫県道路総合管理システム 冠水情報",
        "operator": "兵庫県",
        "prefecture": "28",
        "url": "https://road.civil.pref.hyogo.lg.jp/",
        "api": "https://road.civil.pref.hyogo.lg.jp/RoadLan/InternetGeneral/Map/SubmergenceMap.aspx",
        "list": "https://road.civil.pref.hyogo.lg.jp/RoadLan/InternetGeneral/Submerg/RoadLan_Submergence_List.aspx?AreaID=2&Period=0",
        "attribution": "出典：兵庫県道路総合管理システム",
        "kind": "hyogo",
    },
]

HYOGO_STYLE = {"1": (0, "通常"), "2": (1, "冠水通行注意"), "3": (2, "冠水通行止"), "99": (-1, "不明（故障）")}

JST = timezone(timedelta(hours=9))
SAITAMA_ROAD_TYPES = {2: "道路（アンダーパス）", 4: "道路（平面）"}
TAKAMATSU_STALE = timedelta(hours=24)

LEVEL_BY_TEXT = {"通行可能": 0, "通行可": 0, "通行注意": 1, "通行止め": 2, "通行止": 2}


def level_from_text(s: str | None) -> int | None:
    if not s:
        return None
    for k, v in LEVEL_BY_TEXT.items():
        if k in s:
            return v
    # しずみちinfo の AlertMode: 正常 / 注意 / 警戒・危険・通行止 系
    if "正常" in s:
        return 0
    if "注意" in s:
        return 1
    if any(k in s for k in ("警戒", "危険", "止")):
        return 2
    return None


def parse_shizumichi(data: dict[str, Any]) -> list[dict[str, Any]]:
    """しずみちinfo の flood/underpath → 地下道ごとの点。"""
    out = []
    for x in data.get("Data") or []:
        if not isinstance(x, dict):
            continue
        geo = x.get("Geometry") or {}
        coords = geo.get("Coordinates") if isinstance(geo, dict) else None
        if not (isinstance(coords, list) and len(coords) >= 2):
            continue
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (TypeError, ValueError):
            continue
        name = str(x.get("ObserverPointName") or "").strip()
        if not name:
            continue
        mode = str(x.get("AlertMode") or "")
        lv = level_from_text(mode)
        out.append({"id": str(x.get("ObserverPointCd") or name), "name": f"{name}（アンダーパス）",
                    "lat": lat, "lng": lng, "level": -1 if lv is None else lv,
                    "label": mode or "不明", "at": str(x.get("UpdateDate") or "")})
    return sorted(out, key=lambda p: p["name"])


def parse_saitama(places: list[dict[str, Any]], latest: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """さいたま市水位情報システムの place.json + water_level_latest.json → 道路地点ごとの点。"""
    by_no: dict[str, dict[str, Any]] = {}
    for x in latest or []:
        if isinstance(x, dict) and x.get("place_no") is not None:
            by_no[str(x["place_no"])] = x
    out = []
    for p in places or []:
        if not isinstance(p, dict) or p.get("place_type") not in SAITAMA_ROAD_TYPES:
            continue
        try:
            lat, lng = float(p["lat"]), float(p["lng"])
        except (KeyError, TypeError, ValueError):
            continue
        name = " ".join(str(p.get("name") or "").split())
        if not name:
            continue
        x = by_no.get(str(p.get("place_no")))
        level, label, at = -1, "欠測", ""
        if x and str(x.get("type") or "") in ("W", "WC"):
            def flag(k: str) -> bool:
                return str(x.get(k) or "0") == "1"
            if flag("a9") or flag("a0") or flag("c0"):
                level, label = -1, "欠測・メンテナンス"
            elif flag("a3"):
                level, label = 2, "警戒水位超過"
            elif flag("a2"):
                level, label = 1, "注意水位超過"
            else:
                level, label = 0, "平常水位"
            try:
                wl = float(x.get("wl"))
                if wl == wl and level >= 0:  # nan を除く
                    label = f"{label}（水位{wl:.2f}m）"
            except (TypeError, ValueError):
                pass
            at = str(x.get("dt") or "")
        out.append({"id": str(p.get("place_no")), "name": name, "lat": lat, "lng": lng,
                    "level": level, "label": label, "at": at})
    return sorted(out, key=lambda q: q["name"])


def parse_takamatsu(data: dict[str, Any], now: datetime | None = None) -> list[dict[str, Any]]:
    """たかまつマイセーフティマップの FloodSituation メッセージ → アンダーパスごとの点。"""
    now = now or datetime.now(timezone.utc)
    out = []
    for x in data.get("data") or []:
        m = x.get("msg") if isinstance(x, dict) else None
        if not isinstance(m, dict):
            continue
        coords = m.get("coords")
        if not (isinstance(coords, list) and len(coords) >= 2):
            continue
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (TypeError, ValueError):
            continue
        route = str(m.get("name") or "").strip()
        if not route:
            continue
        area = str(m.get("address") or "").split()
        name = f"{route}（{area[0]}）" if area else route
        issued = None
        try:
            issued = datetime.fromisoformat(str(m.get("dateIssued")).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            pass
        status = m.get("status")
        if issued is None or now - issued > TAKAMATSU_STALE:
            level, label = -1, "不明（更新停止）"
        elif status in (1, "1"):
            level, label = 2, "冠水あり"
        elif status in (0, "0"):
            level, label = 0, "冠水なし"
        else:
            level, label = -1, "不明"
        at = issued.astimezone(JST).strftime("%Y-%m-%d %H:%M") if issued else ""
        pid = str(x.get("id") or name).rsplit(".", 1)[-1]
        out.append({"id": pid, "name": name, "lat": lat, "lng": lng, "level": level, "label": label, "at": at})
    return sorted(out, key=lambda q: q["name"])


def parse_hyogo(kml: bytes | str, at: str = "") -> list[dict[str, Any]]:
    """兵庫県道路総合管理システムの冠水情報 KML → アンダーパスごとの点。"""
    root = ET.fromstring(kml)
    ns = root.tag[1:].split("}")[0] if root.tag.startswith("{") else ""
    q = (lambda t: f"{{{ns}}}{t}") if ns else (lambda t: t)
    out = []
    for pm in root.iter(q("Placemark")):
        name = unicodedata.normalize("NFKC", (pm.findtext(q("name")) or "").strip())
        coords = (pm.findtext(f".//{q('coordinates')}") or "").strip().split(",")
        if not name or len(coords) < 2:
            continue
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except ValueError:
            continue
        style = (pm.findtext(q("styleUrl")) or "").lstrip("#")
        level, label = HYOGO_STYLE.get(style, (-1, "不明"))
        sid = ""
        for d in pm.iter(q("Data")):
            if d.get("name") == "冠水センサID":
                sid = (d.findtext(q("value")) or "").strip()
        out.append({"id": sid or name, "name": name, "lat": lat, "lng": lng,
                    "level": level, "label": label, "at": at})
    return sorted(out, key=lambda p: p["name"])


def hyogo_list_time(html: str, now: datetime | None = None) -> str:
    """一覧ページの「9月21日 13時26分現在」→ "2026-09-21 13:26"（年は現在のJST年）。"""
    m = re.search(r"(\d{1,2})月(\d{1,2})日\s*(\d{1,2})時(\d{1,2})分現在", html)
    if not m:
        return ""
    year = (now or datetime.now(timezone.utc)).astimezone(JST).year
    return f"{year}-{int(m[1]):02d}-{int(m[2]):02d} {int(m[3]):02d}:{int(m[4]):02d}"


def parse_os_alert(data: dict[str, Any]) -> list[dict[str, Any]]:
    """フィールド監視システムの JSONlist4 → 地下道ごとの [{id,name,lat,lng,level,label,at}]。"""
    markers = data.get("map_marker") or {}
    groups: dict[str, dict[str, Any]] = {}
    for s in data.get("sigfox_states") or []:
        gcd = str(s.get("group_cd") or s.get("device_id") or "")
        if not gcd:
            continue
        try:
            lat = float(s.get("location_latitude"))
            lng = float(s.get("location_longitude"))
        except (TypeError, ValueError):
            continue
        name = str(s.get("group_name") or s.get("device_name") or "").strip()
        # 「〇〇地下道_状況1」のような装置名は地下道名に寄せる
        name = name.split("_")[0]
        g = groups.setdefault(gcd, {"id": gcd, "name": name, "lat": lat, "lng": lng,
                                    "level": None, "label": "", "at": ""})
        paused = int(s.get("is_observation_paused") or 0) == 1
        lv = None if paused else level_from_text(str(s.get("status1") or ""))
        # 複数センサーは最も悪い状態を採る
        if lv is not None and (g["level"] is None or lv > g["level"]):
            g["level"] = lv
            g["label"] = str(s.get("status1") or "")
        at = str(s.get("change_datetime") or "")
        if at > g["at"]:
            g["at"] = at
    for gcd, g in groups.items():
        m = markers.get(gcd) if isinstance(markers, dict) else None
        if isinstance(m, dict) and isinstance(m.get("alarm_level"), int):
            # map_marker の alarm_level（0/1/2）を正とする
            lv = int(m["alarm_level"])
            if 0 <= lv <= 2:
                g["level"] = lv
        if g["level"] is None:
            g["level"] = -1
        if not g["label"]:
            g["label"] = {0: "通行可能", 1: "通行注意", 2: "通行止め"}.get(g["level"], "不明")
    return sorted(groups.values(), key=lambda x: x["name"])


def fetch_source(src: dict[str, Any]) -> list[dict[str, Any]] | None:
    import requests  # publish 環境（site/build.py の sync_site）には requests が無いので遅延 import

    try:
        r = requests.get(src["api"], headers=UA, timeout=30)
        r.raise_for_status()
        kind = src.get("kind")
        if kind == "shizumichi":
            return parse_shizumichi(r.json())
        if kind == "saitama":
            m = requests.get(src["master"], headers=UA, timeout=30)
            m.raise_for_status()
            return parse_saitama(m.json(), r.json())
        if kind == "takamatsu":
            return parse_takamatsu(r.json())
        if kind == "hyogo":
            at = ""
            try:
                lst = requests.get(src["list"], headers=UA, timeout=30)
                at = hyogo_list_time(lst.text) if lst.ok else ""
            except Exception:  # noqa: BLE001
                pass
            return parse_hyogo(r.content, at)
        return parse_os_alert(r.json())
    except Exception as e:  # noqa: BLE001
        print(f"{src['id']}: 取得失敗 {type(e).__name__}: {e}", file=sys.stderr)
        return None


def build(previous: dict[str, Any] | None, fetched: dict[str, list[dict[str, Any]] | None],
          now: datetime) -> dict[str, Any]:
    """配信 JSON。取得失敗した情報源は前回の点を level=-1 で残す。"""
    prev_sources = {s["id"]: s for s in (previous or {}).get("sources", [])}
    sources = []
    for src in SOURCES:
        pts = fetched.get(src["id"])
        if pts is None:
            old = prev_sources.get(src["id"], {})
            pts = [dict(p, level=-1) for p in old.get("points", [])]
            fetched_at = old.get("fetched_at", "")
        else:
            fetched_at = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        sources.append({k: src[k] for k in ("id", "name", "operator", "prefecture", "url", "attribution")}
                       | {"fetched_at": fetched_at, "points": pts})
    return {"version": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "sources": sources}


def levels_signature(doc: dict[str, Any]) -> list[tuple[str, str, int]]:
    return sorted((s["id"], p["id"], int(p["level"])) for s in doc.get("sources", []) for p in s.get("points", []))


def sync_site() -> int:
    """data/underpass_status.json を site/v1/ へコピー（無ければ 0）。"""
    if not DATA_PATH.exists():
        return 0
    SITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    SITE_PATH.write_text(DATA_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    return 1


def main() -> int:
    previous = json.loads(DATA_PATH.read_text(encoding="utf-8")) if DATA_PATH.exists() else None
    fetched = {src["id"]: fetch_source(src) for src in SOURCES}
    doc = build(previous, fetched, datetime.now(timezone.utc))
    active = [(s["name"], p["name"], p["level"]) for s in doc["sources"] for p in s["points"] if p["level"] > 0]
    if previous is not None and levels_signature(previous) == levels_signature(doc):
        print(f"変化なし（注意/止め {len(active)}件）")
        return 0
    DATA_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"underpass_status.json 更新: 注意/止め {len(active)}件 {active[:5]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
