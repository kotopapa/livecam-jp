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
  地点マスタ `ja/place.json`（place_type 2=道路（アンダーパス）17か所・4=道路（平面）5か所・
  6=冠水センサー40か所（平面道路の「〇〇付近」。2026-09-21 ユーザー決定でアンダーパス以外の冠水も見える化））
  と最新値 `data/water_level_latest.json`（1分更新。type W/WC の水位計は a9 / a0 / c0=欠測・メンテナンス,
  a3=警戒水位超過, a2=注意水位超過, それ以外=平常水位。type S の冠水センサーは s0=1 で冠水検知。
  判定順は SPA の setKansokuLatest と同じ）。冠水センサーの「想定される冠水範囲」は `data/FLine.geojson`
  （properties.number=place_no、LineString/MultiLineString）で、点の `lines` に [[lat,lng],...] の配列で持たせる
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
- 柏市管路内水位観測システム（RisKma・建設技術研究所。https://kashiwa.riskma.jp/ ）
  道路・水路の浸水センサ 28か所（observatories の type 43）。`data.riskma.net/bosai/observatories?domain=kashiwa.riskma.jp`
  と `.../observatories/status/v2?domain=...&date=<UTC YYYY/MM/DD HH:mm>` の suijins[id].status
  （waiting=冠水なし / flooded=浸水注意（水路の注意ライン） / topFlooded=浸水検知 / maintenace）。
  **`Origin: https://kashiwa.riskma.jp` ヘッダ必須**（無いと 422）。規約は一般的な著作権表記＋
  「引用時は出典記載（記載例あり）」→ 出典明記で利用（2026-09-21）。他の *.riskma.jp も同型
- RisKma平塚市（https://hiratsuka.riskma.jp/ 、浸水センサ4か所=道路2・水路2。柏市と同じ data.riskma.net 経路）。
  2026-09-21 の *.riskma.jp 総当たり（1,695 市区町村ローマ字の DNS 解決で26テナント）で type 43 を持つのは
  柏・平塚・静岡市（shizuoka.riskma.jp → 職員向け「巴川予測システム」へ転送。122か所あるが一般公開ページでないため不採用）
- みち情報ネットふくい 冠水情報（福井県道路保全課。`hozen/yuki/sp/assets/jsons/floodings.json` 1リクエスト、
  県管理アンダーパス9か所。data.state.id 0=冠水なし / 1=注意 / 2=冠水、map.icons[0].lat/lng）。
  無断転載禁止の文言は静止画カメラと同じ扱い（2026-08-29 ユーザー判断で出典明記のうえ継続・県へ照会中）
- 加古川市 行政情報ダッシュボード（加古川市オープンデータAPI。`gis.opendata-api-kakogawa.jp/backend/water-level/onecoin/underpass`
  GeoJSON・認証なし、アンダーパス2か所、os_status 0=平時。市全域のワンコイン浸水センサ層は OAuth 必須で対象外。
  規約: API 利用サービスは「このサービスは、『加古川市オープンデータカタログサイト』のAPI機能を使用していますが、
  サービスの内容は加古川市によって保証されたものではありません。」を表示 → attribution に含める）
- 佐世保市道路冠水モニタリングシステム（https://sasebo.geoorm.com/ 、市道9路線）。トップ HTML の
  `<meta name="monitoring" data-list="…">` に JSON 配列（coordinate_lat/lon, monitoring_name, status 0=未検知 /
  1=5cm / 2=30cm / 3=50cm の冠水センサー段数, photo1_datetime）。著作権条項は柏市と同型（引用時は出典記載）
- 静岡県道路通行規制情報提供システム 冠水情報（https://douro.pref.shizuoka.jp/ 、県管理道路）
  `kisei/program/map/kansui.json.php` → rowcol_sotei（冠水想定箇所42・緯度経度）と rowcol_area（冠水を原因とする
  現在の規制。null なら無し。the_geom_line_string_3857 の WKT LINESTRING/MULTILINESTRING を経緯度に直して
  `lines` に持たせる）。規制は「県が規制をかけた区間」でセンサー状態ではない。想定箇所は level 0 で常時表示
- 兵庫県道路総合管理システム 道路規制情報（冠水・大雨を理由とする通行規制）。地点は KML
  `Map/RegulationMap.aspx`（Placemark name=規制番号, ExtendedData 規制ID / 地物種別, styleUrl #1=全面通行止 #2=大型
  #3=片側交互 #4=幅員減少 #5=一方通行 #9=その他。線は無い）。原因は地域別一覧 `kisei/RoadLan_Regulation_List.aspx?AreaID=<2..7>&Period=0`
  の「災害時通行規制情報」「気象状況」区分の行（路線 / 規制内容 / 期間 / 区間 / 理由、詳細リンクの RID=規制ID）から取り、
  理由・内容に 冠水/浸水/大雨/雨量/豪雨/台風/異常気象 を含むものだけを KML の座標で出す（工事・冬期は除外）
- 掛川市河川水位道路冠水等情報システム（https://kakegawa.anw-suite.com/waterlevel/ 、道路冠水観測装置7か所）
  `data_suii.cgi?road=<road_cd,…>` 1リクエスト → data[].kansuisu 0=正常 / 1=注意 / 2=危険 / 255=低温保護モード。
  座標は `common/js/map.js` の maker_road 固定値（KAKEGAWA_POINTS）。規約に「営利目的利用不可・無断転載禁止」が
  あるが 2026-09-21 ユーザー判断で採用（出典明記）。市への照会先は維持管理課 0537-21-1154

level: 0=通行可 / 1=通行注意 / 2=通行止め / -1=不明（観測停止・取得失敗）
"""
from __future__ import annotations

import json
import math
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
SOURCES_PAGE = REPO_ROOT / "site" / "underpass_sources.html"  # 出典一覧（アプリの凡例からリンク）
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
        "lines": "https://www.flood-info.city.saitama.jp/data/FLine.geojson",
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
    {
        "id": "kashiwa",
        "name": "柏市管路内水位観測システム",
        "operator": "柏市",
        "prefecture": "12",
        "url": "https://kashiwa.riskma.jp/",
        "api": "https://data.riskma.net/bosai/observatories/status/v2?domain=kashiwa.riskma.jp",
        "master": "https://data.riskma.net/bosai/observatories?domain=kashiwa.riskma.jp",
        "headers": {"Origin": "https://kashiwa.riskma.jp"},
        "attribution": "出典：柏市管路内水位観測システム（https://kashiwa.riskma.jp/）",
        "kind": "riskma",
    },
    {
        "id": "hiratsuka",
        "name": "RisKma平塚市（浸水センサ）",
        "operator": "平塚市",
        "prefecture": "14",
        "url": "https://hiratsuka.riskma.jp/",
        "api": "https://data.riskma.net/bosai/observatories/status/v2?domain=hiratsuka.riskma.jp",
        "master": "https://data.riskma.net/bosai/observatories?domain=hiratsuka.riskma.jp",
        "headers": {"Origin": "https://hiratsuka.riskma.jp"},
        "attribution": "出典：平塚市（RisKma平塚市）",
        "kind": "riskma",
    },
    {
        "id": "fukui",
        "name": "みち情報ネットふくい 冠水情報",
        "operator": "福井県",
        "prefecture": "18",
        "url": "https://www.hozen.pref.fukui.lg.jp/hozen/yuki/sp/flooding-list.html",
        "api": "https://www.hozen.pref.fukui.lg.jp/hozen/yuki/sp/assets/jsons/floodings.json",
        "attribution": "出典：みち情報ネットふくい（福井県）",
        "kind": "fukui",
    },
    {
        "id": "kakogawa",
        "name": "加古川市行政情報ダッシュボード",
        "operator": "加古川市",
        "prefecture": "28",
        "url": "https://gis.opendata-api-kakogawa.jp/",
        "api": "https://gis.opendata-api-kakogawa.jp/backend/water-level/onecoin/underpass",
        "attribution": "出典：加古川市オープンデータカタログサイト（行政情報ダッシュボード）。このサービスは、『加古川市オープンデータカタログサイト』のAPI機能を使用していますが、サービスの内容は加古川市によって保証されたものではありません。",
        "kind": "kakogawa",
    },
    {
        "id": "sasebo",
        "name": "佐世保市道路冠水モニタリングシステム",
        "operator": "佐世保市",
        "prefecture": "42",
        "url": "https://sasebo.geoorm.com/",
        "api": "https://sasebo.geoorm.com/",
        "attribution": "出典：佐世保市道路冠水モニタリングシステム（https://sasebo.geoorm.com/）",
        "kind": "sasebo",
    },
    {
        "id": "shizuoka_pref",
        "name": "静岡県道路通行規制情報 冠水情報",
        "operator": "静岡県",
        "prefecture": "22",
        "url": "https://douro.pref.shizuoka.jp/",
        "api": "https://douro.pref.shizuoka.jp/kisei/program/map/kansui.json.php",
        "attribution": "出典：静岡県道路通行規制情報提供システム",
        "kind": "shizuoka_pref",
    },
    {
        "id": "hyogo_reg",
        "name": "兵庫県道路総合管理システム 道路規制情報（冠水・大雨）",
        "operator": "兵庫県",
        "prefecture": "28",
        "url": "https://road.civil.pref.hyogo.lg.jp/",
        "api": "https://road.civil.pref.hyogo.lg.jp/RoadLan/InternetGeneral/Map/RegulationMap.aspx",
        "lists": [f"https://road.civil.pref.hyogo.lg.jp/RoadLan/InternetGeneral/kisei/RoadLan_Regulation_List.aspx?AreaID={a}&Period=0"
                  for a in range(2, 8)],
        "attribution": "出典：兵庫県道路総合管理システム",
        "kind": "hyogo_reg",
    },
    {
        "id": "kakegawa",
        "name": "掛川市河川水位道路冠水等情報システム",
        "operator": "掛川市",
        "prefecture": "22",
        "url": "https://kakegawa.anw-suite.com/waterlevel/",
        "api": "https://kakegawa.anw-suite.com/waterlevel/data_suii.cgi?road=1F73E70,1F73EA6,1F73A6E,1F73EB8,1F73BFF,1F73BEC,1F73E60",
        "attribution": "出典：掛川市河川水位道路冠水等情報システム",
        "kind": "kakegawa",
    },
]

# 掛川市の道路冠水観測装置（common/js/map.js の maker_road。2026-09-21 取得）
KAKEGAWA_POINTS = {
    "1F73E70": (34.760804, 137.972592), "1F73EA6": (34.768049, 137.975037), "1F73A6E": (34.761504, 137.998557),
    "1F73EB8": (34.768682, 138.008041), "1F73BFF": (34.684230, 137.973089), "1F73BEC": (34.675401, 138.043625),
    "1F73E60": (34.654673, 138.066594),
}
KAKEGAWA_STATUS = {0: (0, "正常"), 1: (1, "注意"), 2: (2, "危険")}

SASEBO_STATUS = {0: (0, "冠水なし"), 1: (1, "冠水を検知（5cm）"), 2: (2, "冠水を検知（30cm）"), 3: (2, "冠水を検知（50cm）")}

RISKMA_STATUS = {"waiting": (0, "冠水なし"), "flooded": (1, "浸水注意"), "topFlooded": (2, "浸水検知")}
FUKUI_STATE = {0: (0, "冠水なし"), 1: (1, "冠水注意"), 2: (2, "冠水")}

HYOGO_STYLE = {"1": (0, "通常"), "2": (1, "冠水通行注意"), "3": (2, "冠水通行止"), "99": (-1, "不明（故障）")}

JST = timezone(timedelta(hours=9))
SAITAMA_ROAD_TYPES = {2: "道路（アンダーパス）", 4: "道路（平面）", 6: "冠水センサー"}
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


def saitama_lines(geojson: dict[str, Any] | None) -> dict[str, list[list[list[float]]]]:
    """FLine.geojson → {place_no: [[[lat,lng],...], ...]}（想定される冠水範囲の折れ線）。"""
    out: dict[str, list[list[list[float]]]] = {}
    for f in (geojson or {}).get("features") or []:
        props = f.get("properties") or {}
        geom = f.get("geometry") or {}
        no = str(props.get("number") or "")
        coords = geom.get("coordinates") or []
        if geom.get("type") == "LineString":
            coords = [coords]
        elif geom.get("type") != "MultiLineString":
            continue
        lines = []
        for line in coords:
            pts = []
            for c in line:
                try:
                    pts.append([round(float(c[1]), 6), round(float(c[0]), 6)])
                except (TypeError, ValueError, IndexError):
                    continue
            if len(pts) >= 2:
                lines.append(pts)
        if no and lines:
            out.setdefault(no, []).extend(lines)
    return out


def parse_saitama(places: list[dict[str, Any]], latest: list[dict[str, Any]],
                  lines: dict[str, list[list[list[float]]]] | None = None) -> list[dict[str, Any]]:
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
        if p.get("place_type") == 6:
            name = f"{name}（冠水センサー）"
        if x and str(x.get("type") or "") == "S":
            s0 = str(x.get("s0") if x.get("s0") is not None else "")
            level, label = {"1": (2, "冠水を検知"), "0": (0, "冠水なし")}.get(s0, (-1, "欠測"))
            at = str(x.get("dt") or "")
        elif x and str(x.get("type") or "") in ("W", "WC"):
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
        pt = {"id": str(p.get("place_no")), "name": name, "lat": lat, "lng": lng,
              "level": level, "label": label, "at": at}
        if lines and str(p.get("place_no")) in lines:
            pt["lines"] = lines[str(p.get("place_no"))]
        out.append(pt)
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


def parse_riskma(master: dict[str, Any], status: dict[str, Any]) -> list[dict[str, Any]]:
    """RisKma の observatories（type 43=浸水センサ）+ status/v2 の suijins → 点。"""
    sj = status.get("suijins") if isinstance(status, dict) else None
    sj = sj if isinstance(sj, dict) else {}
    out = []
    for o in master.get("observatories") or []:
        if not isinstance(o, dict) or o.get("type") != 43:
            continue
        try:
            lat, lng = float(o["lat"]), float(o["lng"])
        except (KeyError, TypeError, ValueError):
            continue
        raw = str(o.get("name") or "").strip()
        # 柏市は「西原六丁目(浸水センサ)」、平塚市は「豊田打間木（道路）」。種別が名前に無ければ添える
        name = raw.replace("(浸水センサ)", "").strip()
        if not name:
            continue
        if "浸水センサ" in raw or not any(k in name for k in ("道路", "水路")):
            name = f"{name}（浸水センサ）"
        x = sj.get(str(o.get("id"))) or {}
        st = str(x.get("status") or "")
        if x.get("isTopFlooded") is True:
            st = "topFlooded"
        level, label = RISKMA_STATUS.get(st, (-1, "不明（メンテナンス）" if st else "欠測"))
        out.append({"id": str(o.get("id")), "name": name, "lat": lat, "lng": lng,
                    "level": level, "label": label, "at": str(x.get("date") or "")})
    return sorted(out, key=lambda p: p["name"])


def parse_fukui(data: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """みち情報ネットふくい floodings.json → アンダーパスごとの点。"""
    out = []
    for x in data if isinstance(data, list) else []:
        if not isinstance(x, dict):
            continue
        icons = ((x.get("map") or {}).get("icons") or [])
        icon = next((i for i in icons if isinstance(i, dict) and i.get("isMain")), icons[0] if icons else None)
        try:
            lat, lng = float(icon["lat"]), float(icon["lng"])
        except (KeyError, TypeError, ValueError):
            continue
        name = str(x.get("name") or "").strip()
        if not name:
            continue
        d = x.get("data") or {}
        state = d.get("state") or {}
        # 表示名（冠水なし/注意/冠水）を正とし、無ければ id で判定（三本木アンダーは id=1 でも名前が「冠水なし」のまま）
        sname = str(state.get("name") or "")
        lv = level_from_text(sname) if sname else None
        if "冠水なし" in sname:
            lv = 0
        elif lv is None and sname and "冠水" in sname:
            lv = 2
        if lv is not None:
            level, label = lv, sname
        else:
            st = state.get("id")
            level, label = FUKUI_STATE.get(st if isinstance(st, int) else -1, (-1, "不明"))
        at = str(d.get("updatedAt") or "")[:16]
        route = ((x.get("route") or {}).get("rname") or "").strip()
        out.append({"id": str(x.get("id")), "name": f"{name}（{route}）" if route else name, "lat": lat, "lng": lng,
                    "level": level, "label": label, "at": at})
    return sorted(out, key=lambda p: p["name"])


def parse_kakogawa(geojson: dict[str, Any]) -> list[dict[str, Any]]:
    """加古川市 onecoin/underpass GeoJSON → 点。os_status 0=平時、それ以外=浸水検知として扱う。"""
    out = []
    for f in (geojson or {}).get("features") or []:
        props = f.get("properties") or {}
        coords = (f.get("geometry") or {}).get("coordinates") or []
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (TypeError, ValueError, IndexError):
            continue
        name = " ".join(str(props.get("os_place_name") or "").split())
        if not name:
            continue
        st = props.get("os_status")
        if st in (0, "0"):
            level, label = 0, "冠水なし"
        elif st is None or st == "":
            level, label = -1, "不明"
        else:
            level, label = 2, "浸水検知"
        out.append({"id": name, "name": name, "lat": lat, "lng": lng, "level": level, "label": label, "at": ""})
    return sorted(out, key=lambda p: p["name"])


def parse_sasebo(page: str) -> list[dict[str, Any]]:
    """佐世保市のトップ HTML（meta name="monitoring" data-list）→ 市道ごとの点。"""
    import html as _html
    m = re.search(r'<meta[^>]*name="monitoring"[^>]*data-list="([^"]*)"', page)
    if not m:
        return []
    out = []
    for x in json.loads(_html.unescape(m.group(1))):
        if not isinstance(x, dict):
            continue
        try:
            lat, lng = float(x["coordinate_lat"]), float(x["coordinate_lon"])
        except (KeyError, TypeError, ValueError):
            continue
        name = str(x.get("monitoring_name") or "").strip()
        if not name:
            continue
        sub = str(x.get("monitoring_address_sub") or "").strip()
        st = x.get("status")
        level, label = SASEBO_STATUS.get(st if isinstance(st, int) else -1, (-1, "不明"))
        out.append({"id": str(x.get("monitoring_id")), "name": f"{name}{sub}", "lat": lat, "lng": lng,
                    "level": level, "label": label, "at": str(x.get("photo1_datetime") or "")})
    return sorted(out, key=lambda p: p["name"])


HYOGO_REG_STYLE = {"1": (2, "全面通行止め"), "2": (2, "大型車通行止め"), "3": (1, "片側交互通行"),
                   "4": (1, "幅員減少"), "5": (1, "一方通行"), "9": (1, "その他の規制")}
HYOGO_REG_WORDS = re.compile("冠水|浸水|大雨|雨量|豪雨|台風|異常気象")
_HYOGO_ROW = re.compile(
    r"<tr>\s*<td>(?P<route>[^<]*)</td>\s*<td>\s*<font[^>]*>\s*(?P<content>[^<]*?)\s*</font>\s*</td>\s*<td>(?P<period>[^<]*)</td>"
    r".*?[?&]RID=(?P<rid>\d+).*?</tr>\s*<tr>\s*<td>(?P<section>[^<]*)</td>\s*<td[^>]*>(?P<reason>[^<]*)</td>", re.S)


def hyogo_regulation_rows(page: str) -> list[dict[str, str]]:
    """規制一覧 HTML → 災害時・気象の区分にある行（工事・冬期は除く）。"""
    import html as _html
    rows = []
    parts = re.split(r'<a name="(DisasterTCInfo|EngineeringWorkInfo|WeatherStatus|WIS)"', page)
    # parts: [前, anchor1, 本文1, anchor2, 本文2, ...]
    for i in range(1, len(parts) - 1, 2):
        anchor, body = parts[i], parts[i + 1]
        if anchor not in ("DisasterTCInfo", "WeatherStatus"):
            continue
        for m in _HYOGO_ROW.finditer(body):
            d = {k: " ".join(_html.unescape(v or "").replace("\xa0", " ").split()) for k, v in m.groupdict().items()}
            d["kind"] = "災害時通行規制" if anchor == "DisasterTCInfo" else "気象状況"
            rows.append(d)
    return rows


def parse_hyogo_regulation(kml: bytes | str, pages: list[str]) -> list[dict[str, Any]]:
    """規制 KML（座標）＋地域別一覧（原因）→ 冠水・大雨を理由とする規制の点。"""
    root = ET.fromstring(kml)
    ns = root.tag[1:].split("}")[0] if root.tag.startswith("{") else ""
    q = (lambda t: f"{{{ns}}}{t}") if ns else (lambda t: t)
    by_id: dict[str, tuple[float, float, str]] = {}
    for pm in root.iter(q("Placemark")):
        coords = (pm.findtext(f".//{q('coordinates')}") or "").strip().split(",")
        rid = ""
        for d in pm.iter(q("Data")):
            if d.get("name") == "規制ID":
                rid = (d.findtext(q("value")) or "").strip()
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (ValueError, IndexError):
            continue
        if rid:
            by_id[rid] = (lat, lng, (pm.findtext(q("styleUrl")) or "").lstrip("#"))
    out = []
    seen = set()
    for page in pages:
        for r in hyogo_regulation_rows(page):
            if not HYOGO_REG_WORDS.search(r["reason"] + r["content"]):
                continue
            hit = by_id.get(r["rid"])
            if hit is None or r["rid"] in seen:
                continue
            seen.add(r["rid"])
            lat, lng, style = hit
            level, _ = HYOGO_REG_STYLE.get(style, (1, ""))
            if "全面通行止" in r["content"]:
                level = 2
            label = f"{r['content']}（{r['reason']}）" if r["reason"] else r["content"]
            name = f"{r['route']} {r['section']}".strip()
            out.append({"id": r["rid"], "name": name, "lat": lat, "lng": lng, "level": level,
                        "label": label, "at": r["period"]})
    return sorted(out, key=lambda p: p["name"])


def merc_to_latlng(x: float, y: float) -> list[float]:
    """EPSG:3857 → [lat, lng]（小数6桁）。"""
    lng = x / 20037508.34 * 180.0
    lat = math.degrees(2 * math.atan(math.exp(y / 6378137.0)) - math.pi / 2)
    return [round(lat, 6), round(lng, 6)]


def wkt_lines_3857(wkt: str | None) -> list[list[list[float]]]:
    """WKT の LINESTRING / MULTILINESTRING（EPSG:3857）→ [[[lat,lng],...], ...]。"""
    if not wkt:
        return []
    out = []
    for group in re.findall(r"\(([^()]+)\)", wkt):
        pts = []
        for pair in group.split(","):
            xy = pair.split()
            if len(xy) < 2:
                continue
            try:
                pts.append(merc_to_latlng(float(xy[0]), float(xy[1])))
            except ValueError:
                continue
        if len(pts) >= 2:
            out.append(pts)
    return out


def parse_shizuoka_pref(data: dict[str, Any]) -> list[dict[str, Any]]:
    """静岡県 kansui.json.php → 冠水想定箇所（level 0）と冠水規制区間（level 2・lines 付き）。"""
    out = []
    for r in (data or {}).get("rowcol_sotei") or []:
        if not isinstance(r, dict):
            continue
        try:
            lat, lng = float(r.get("緯度")), float(r.get("経度"))
        except (TypeError, ValueError):
            continue
        spot = " ".join(str(r.get("箇所名") or "").split())
        route = f"{r.get('道路種別') or ''}{r.get('路線名') or ''}".strip()
        name = f"{spot}（{route}・{r.get('市町名') or ''}）" if spot else f"{route}（{r.get('市町名') or ''}）"
        out.append({"id": f"sotei-{r.get('gid')}", "name": name, "lat": lat, "lng": lng,
                    "level": 0, "label": "冠水想定箇所（規制なし）", "at": ""})
    for r in (data or {}).get("rowcol_area") or []:
        if not isinstance(r, dict):
            continue
        lines = wkt_lines_3857(str(r.get("the_geom_line_string_3857") or ""))
        pt = wkt_lines_3857("LINESTRING(" + re.sub(r"[A-Z()]", "", str(r.get("the_geom_point_string_3857") or "")) + ",0 0)")
        if pt and pt[0]:
            lat, lng = pt[0][0]
        elif lines:
            mid = lines[0][len(lines[0]) // 2]
            lat, lng = mid
        else:
            continue
        city = "・".join(c for c in (str(r.get("city1") or ""), str(r.get("city2") or "")) if c)
        name = f"{r.get('rosen') or '規制区間'}（{city}）" if city else str(r.get("rosen") or "規制区間")
        p = {"id": f"kisei-{r.get('kisei_id')}-{r.get('kisei_eda')}", "name": name, "lat": lat, "lng": lng,
             "level": 2, "label": "冠水による通行規制", "at": ""}
        if lines:
            p["lines"] = lines
        out.append(p)
    return sorted(out, key=lambda q: (q["level"] == 0, q["name"]))


def parse_kakegawa(data: dict[str, Any]) -> list[dict[str, Any]]:
    """掛川市 data_suii.cgi の道路要素 → 点（座標は KAKEGAWA_POINTS）。"""
    out = []
    for x in (data or {}).get("data") or []:
        if not isinstance(x, dict) or x.get("dat_ptn") != "road" or str(x.get("open_flg") or "1") != "1":
            continue
        cd = str(x.get("road_cd") or "")
        if cd not in KAKEGAWA_POINTS:
            continue
        name = str(x.get("name") or "").strip()
        if not name:
            continue
        k = x.get("kansuisu")
        level, label = KAKEGAWA_STATUS.get(k if isinstance(k, int) else -1,
                                           (-1, "低温保護モード" if k == 255 else "不明"))
        lat, lng = KAKEGAWA_POINTS[cd]
        out.append({"id": cd, "name": name, "lat": lat, "lng": lng, "level": level, "label": label, "at": ""})
    return sorted(out, key=lambda p: p["name"])


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

    headers = UA | (src.get("headers") or {})
    try:
        url = src["api"]
        if src.get("kind") == "riskma":
            url += "&date=" + datetime.now(timezone.utc).strftime("%Y/%m/%d %H:%M").replace(" ", "%20")
        r = requests.get(url, headers=headers, timeout=30)
        r.raise_for_status()
        kind = src.get("kind")
        if kind == "shizumichi":
            return parse_shizumichi(r.json())
        if kind == "saitama":
            m = requests.get(src["master"], headers=UA, timeout=30)
            m.raise_for_status()
            lines = None
            try:
                g = requests.get(src["lines"], headers=UA, timeout=30)
                lines = saitama_lines(g.json()) if g.ok else None
            except Exception:  # noqa: BLE001
                pass
            return parse_saitama(m.json(), r.json(), lines)
        if kind == "takamatsu":
            return parse_takamatsu(r.json())
        if kind == "riskma":
            m = requests.get(src["master"], headers=headers, timeout=30)
            m.raise_for_status()
            return parse_riskma(m.json(), r.json())
        if kind == "kakegawa":
            return parse_kakegawa(r.json())
        if kind == "shizuoka_pref":
            return parse_shizuoka_pref(r.json())
        if kind == "hyogo_reg":
            pages = []
            for u in src["lists"]:
                try:
                    lr = requests.get(u, headers=headers, timeout=30)
                    if lr.ok:
                        pages.append(lr.text)
                except Exception:  # noqa: BLE001
                    pass
            return parse_hyogo_regulation(r.content, pages)
        if kind == "sasebo":
            return parse_sasebo(r.text)
        if kind == "fukui":
            return parse_fukui(r.json())
        if kind == "kakogawa":
            return parse_kakogawa(r.json())
        if kind == "hyogo":
            at = ""
            try:
                lst = requests.get(src["list"], headers=headers, timeout=30)
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


def levels_signature(doc: dict[str, Any]) -> list[tuple[str, str, int, int]]:
    """段階と、冠水範囲の折れ線の有無（本数）だけを比較する（時刻・水位の変化では更新しない）。"""
    return sorted((s["id"], p["id"], int(p["level"]), len(p.get("lines") or []))
                  for s in doc.get("sources", []) for p in s.get("points", []))


def render_sources_html(doc: dict[str, Any] | None) -> str:
    """出典一覧ページ。凡例に10行並べる代わりにここへリンクする（2026-09-21 要望）。"""
    import html as _html
    counts = {s.get("id"): len(s.get("points") or []) for s in (doc or {}).get("sources", [])}
    rows = []
    for src in SOURCES:
        n = counts.get(src["id"])
        rows.append(
            "<tr><td><a href=\"{url}\" target=\"_blank\" rel=\"noopener\">{name}</a></td>"
            "<td>{op}</td><td class=\"num\">{n}</td><td class=\"attr\">{attr}</td></tr>".format(
                url=_html.escape(src["url"]), name=_html.escape(src["name"]), op=_html.escape(src["operator"]),
                n="" if n is None else f"{n}か所", attr=_html.escape(src["attribution"])))
    total = sum(v for v in counts.values())
    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>道路・地下道の冠水状況の出典 | 全国ライブカメラ地図</title>
<style>
body {{ font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans", "Noto Sans JP", sans-serif;
       max-width: 720px; margin: 0 auto; padding: 24px 16px 64px; line-height: 1.7; color: #333; }}
h1 {{ font-size: 1.3rem; border-bottom: 2px solid #1E6FD9; padding-bottom: 8px; }}
.notice {{ background: #FFF8E1; border-radius: 8px; padding: 12px 16px; font-size: .95rem; }}
table {{ border-collapse: collapse; width: 100%; font-size: .9rem; margin-top: 1em; }}
th, td {{ border-bottom: 1px solid #ddd; padding: 8px 6px; text-align: left; vertical-align: top; }}
th {{ background: #F3F6FB; }}
td.num {{ white-space: nowrap; }}
td.attr {{ font-size: .82rem; color: #555; }}
footer {{ margin-top: 3em; font-size: .85rem; color: #777; }}
</style>
</head>
<body>
<h1>道路・地下道の冠水状況の出典</h1>
<p>アプリの地図レイヤー「道路・地下道の冠水状況」は、次の自治体が公開している冠水センサー・水位計の状態を、各提供元から取得して表示しています（{len(SOURCES)}情報源・{total}か所）。映像ではなく状態の表示です。</p>
<div class="notice">実際の通行可否は、現地の道路情報板と交通規制に従ってください。センサーの点検・故障・通信障害により、実際と異なる表示になることがあります。</div>
<table>
<thead><tr><th>情報源</th><th>運営</th><th>地点数</th><th>出典表記</th></tr></thead>
<tbody>
{chr(10).join(rows)}
</tbody>
</table>
<p>各データの著作権はそれぞれの提供元に帰属します。表示している状態は各提供元の公開情報を加工したもので、内容は提供元によって保証されたものではありません。</p>
<footer><a href="./index.html">全国ライブカメラ地図</a> · <a href="./terms.html">利用規約</a></footer>
</body>
</html>
"""


def sync_site() -> int:
    """data/underpass_status.json を site/v1/ へコピーし、出典一覧ページを書く（無ければ 0）。"""
    if not DATA_PATH.exists():
        return 0
    SITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    text = DATA_PATH.read_text(encoding="utf-8")
    SITE_PATH.write_text(text, encoding="utf-8")
    SOURCES_PAGE.write_text(render_sources_html(json.loads(text)), encoding="utf-8")
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
