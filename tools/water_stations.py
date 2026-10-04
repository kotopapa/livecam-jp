"""川の防災情報（river.go.jp）の河川カメラに、最寄りの水位観測所を紐付ける。

アプリの河川カメラ詳細画面に水位の時系列グラフを出すための一度限りの対応付け
（2026-10-04 ユーザー要望）。水位の時系列そのものはアプリが詳細画面を開いたときに
端末から直接取得する（サーバー側では収集しない。川の防災情報は規約でツールによる
定期収集を控えるよう求めているため、この対応付けも一度限り・1.2秒間隔・控え付きで回す）。

使うファイル（SPA 内部のため構造変化に注意）:
- map/twn/twnarea.json                       … 全市町村（twnCd・prefCd）
- obslist/obs/twnlist/<twnCd>.json           … 市町村の観測所一覧。obsStg[] は水位観測所
                                               （obsFcd・rvrCd・基準水位）、scam[]/cctv[] は
                                               カメラ（scamId・rvrCd）
- master/obs/stg/<obsFcd>.json               … 観測所マスタ（lat/lon・scamId・基準水位）

対応付けの規則:
1. 観測所マスタの scamId がカメラの scamId と一致 → その観測所（併設）
2. 同じ市町村で同じ河川コード（rvrCd）の観測所のうち最寄り（3km 以内）
3. 無ければ紐付けない

出力:
- data/water_stations.json … {obsFcd: {name, lat, lon, rvr, ofc, obs, levels{rsrv,warn,spcl,dng,fld}}}
- data/cameras.json の各カメラに water_level: {"obs": obsFcd, "dist_m": N}（version も更新）
- 取得の控え: data/water_stations_cache/（twn/<twnCd>.json, stg/<obsFcd>.json）

実行: python -m tools.water_stations [--dry] [--limit N]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    import truststore
    truststore.inject_into_ssl()
except Exception:  # noqa: BLE001
    pass
import requests

ROOT = Path(__file__).resolve().parents[1]
CAMERAS = ROOT / "data" / "cameras.json"
OUT = ROOT / "data" / "water_stations.json"
CACHE = ROOT / "data" / "water_stations_cache"
BASE = "https://www.river.go.jp/kawabou/file/files/"
UA = "LiveCamJP-WaterStations/1.0 (+https://github.com/kotopapa/livecam-jp; one-off)"
INTERVAL = 1.2
MAX_DIST_M = 3000

_session = requests.Session()
_last = 0.0


def fetch_json(path: str, cache_path: Path) -> dict | None:
    """控えがあればそれを返し、無ければ取得して控える（404 は {} を控える）。"""
    global _last
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8")) or None
    wait = INTERVAL - (time.monotonic() - _last)
    if wait > 0:
        time.sleep(wait)
    r = _session.get(BASE + path, headers={"User-Agent": UA}, timeout=30)
    _last = time.monotonic()
    data: dict = {}
    if r.status_code == 200:
        try:
            data = r.json()
        except ValueError:
            data = {}
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return data or None


def dist_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    return math.hypot((lat1 - lat2) * 111000, (lon1 - lon2) * 111000 * math.cos(math.radians(lat1)))


def pref_jis(pref_cd: int) -> str:
    """kawabou prefCd（101〜4701。北海道は101〜105）→ JIS 2桁"""
    return f"{pref_cd // 100:02d}"


def scam_id_of(camera: dict) -> int | None:
    url = camera.get("feed", {}).get("url") or ""
    if "cam.river.go.jp/cam/now/" not in url:
        return None
    tail = url.rsplit("/", 1)[-1].split(".")[0]
    return int(tail) if tail.isdigit() else None


def levels_of(st: dict) -> dict:
    out = {}
    for key, src in (("rsrv", "rsrvStg"), ("warn", "warnStg"), ("spcl", "spclWarnStg"),
                     ("dng", "dngStg"), ("fld", "fldStg")):
        v = st.get(src)
        if isinstance(v, (int, float)):
            out[key] = v
    return out


def match_cameras(cameras: list[dict], town_lists: dict[int, dict],
                  masters: dict[str, dict]) -> dict[str, dict]:
    """{camera_id: {"obs": obsFcd, "dist_m": N}}。純粋関数（テスト用）。"""
    by_scam: dict[int, str] = {}
    for fcd, m in masters.items():
        sid = m.get("scamId")
        if sid:
            by_scam[int(sid)] = fcd
    cam_rvr: dict[int, int] = {}
    town_stations: dict[int, list[dict]] = {}
    for twn, tl in town_lists.items():
        ol = tl.get("obsList") or {}
        for c in (ol.get("scam") or []) + (ol.get("cctv") or []):
            if c.get("scamId") and c.get("rvrCd"):
                cam_rvr[int(c["scamId"])] = int(c["rvrCd"])
        town_stations[twn] = ol.get("obsStg") or []
    out: dict[str, dict] = {}
    for cam in cameras:
        sid = scam_id_of(cam)
        if sid is None or cam.get("lat") is None:
            continue
        lat, lng = cam["lat"], cam["lng"]
        if sid in by_scam and by_scam[sid] in masters:
            m = masters[by_scam[sid]]
            d = dist_m(lat, lng, m["lat"], m["lon"]) if m.get("lat") else 0
            out[cam["id"]] = {"obs": by_scam[sid], "dist_m": int(d)}
            continue
        rvr = cam_rvr.get(sid)
        twn = cam.get("_twnCd")
        if rvr is None or twn is None:
            continue
        best = None
        for st in town_stations.get(twn, []):
            if int(st.get("rvrCd") or 0) != rvr:
                continue
            m = masters.get(st["obsFcd"])
            if not m or not m.get("lat"):
                continue
            d = dist_m(lat, lng, m["lat"], m["lon"])
            if d <= MAX_DIST_M and (best is None or d < best[1]):
                best = (st["obsFcd"], d)
        if best:
            out[cam["id"]] = {"obs": best[0], "dist_m": int(best[1])}
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="処理するカメラ数の上限（動作確認用）")
    ap.add_argument("--id-prefix", default="", help="この接頭辞の id だけ処理（動作確認用）")
    args = ap.parse_args()

    raw = CAMERAS.read_text(encoding="utf-8")
    ledger = json.loads(raw)
    cams = [c for c in ledger["cameras"]
            if c.get("review", {}).get("status") == "approved" and scam_id_of(c) and c.get("municipality")]
    if args.id_prefix:
        cams = [c for c in cams if c["id"].startswith(args.id_prefix)]
    if args.limit:
        cams = cams[:args.limit]
    print(f"対象カメラ {len(cams)}", flush=True)

    twnarea = fetch_json("map/twn/twnarea.json", CACHE / "twnarea.json") or {}
    towns = []
    for v in (twnarea.values() if isinstance(twnarea, dict) else twnarea):
        if isinstance(v, list):
            towns.extend(v)
        elif isinstance(v, dict):
            towns.append(v)
    jis_to_twn: dict[str, list[int]] = {}
    for t in towns:
        if not isinstance(t, dict) or "twnCd" not in t:
            continue
        twn = int(t["twnCd"])
        pref = int(t.get("prefCd") or twn // 1000)
        jis = f"{pref_jis(pref)}{twn % 1000:03d}"
        jis_to_twn.setdefault(jis, []).append(twn)
    print(f"市町村 {len(jis_to_twn)}", flush=True)

    need_towns: set[int] = set()
    for c in cams:
        twns = jis_to_twn.get(c["municipality"], [])
        c["_twnCd"] = twns[0] if len(twns) == 1 else None
        if len(twns) > 1:   # 北海道の振興局またがり: 候補を全部見る
            c["_twnCds"] = twns
        need_towns.update(twns)
    town_lists: dict[int, dict] = {}
    for i, twn in enumerate(sorted(need_towns)):
        tl = fetch_json(f"obslist/obs/twnlist/{twn}.json", CACHE / "twn" / f"{twn}.json")
        if tl:
            town_lists[twn] = tl
        if i % 50 == 0:
            print(f"  市町村一覧 {i}/{len(need_towns)}", flush=True)
    # 北海道: カメラの scamId が載っている市町村を採る
    for c in cams:
        if c.get("_twnCds"):
            sid = scam_id_of(c)
            for twn in c["_twnCds"]:
                ol = (town_lists.get(twn) or {}).get("obsList") or {}
                if any(int(x.get("scamId") or 0) == sid for x in (ol.get("scam") or []) + (ol.get("cctv") or [])):
                    c["_twnCd"] = twn
                    break

    # 候補観測所: カメラと同じ市町村・同じ河川の水位観測所
    cam_rvr: dict[int, int] = {}
    for tl in town_lists.values():
        ol = tl.get("obsList") or {}
        for x in (ol.get("scam") or []) + (ol.get("cctv") or []):
            if x.get("scamId") and x.get("rvrCd"):
                cam_rvr[int(x["scamId"])] = int(x["rvrCd"])
    need_stations: set[str] = set()
    for c in cams:
        rvr = cam_rvr.get(scam_id_of(c)); twn = c.get("_twnCd")
        if rvr is None or twn is None:
            continue
        for st in ((town_lists.get(twn) or {}).get("obsList") or {}).get("obsStg") or []:
            if int(st.get("rvrCd") or 0) == rvr:
                need_stations.add(st["obsFcd"])
    print(f"候補観測所 {len(need_stations)}", flush=True)
    masters: dict[str, dict] = {}
    for i, fcd in enumerate(sorted(need_stations)):
        m = fetch_json(f"master/obs/stg/{fcd}.json", CACHE / "stg" / f"{fcd}.json")
        info = (m or {}).get("obsInfo")
        if info and info.get("lat"):
            masters[fcd] = info
        if i % 100 == 0:
            print(f"  観測所マスタ {i}/{len(need_stations)}", flush=True)

    mapping = match_cameras(cams, town_lists, masters)
    print(f"紐付け {len(mapping)} / {len(cams)}", flush=True)
    used = {v["obs"] for v in mapping.values()}
    stations = {}
    for fcd in sorted(used):
        m = masters[fcd]
        stations[fcd] = {
            "name": m.get("obsNm"), "lat": m["lat"], "lon": m["lon"],
            "rvr": m.get("rvrNm"), "ofc": m.get("ofcCd"), "obs": m.get("obsCd"),
            "levels": levels_of(m),
        }
    if args.dry:
        print(json.dumps(list(mapping.items())[:5], ensure_ascii=False, indent=1))
        return 0
    OUT.write_text(json.dumps({"version": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                               "source": "国土交通省「川の防災情報」", "stations": stations},
                              ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    n = 0
    for c in ledger["cameras"]:
        if c["id"] in mapping:
            if c.get("water_level") != mapping[c["id"]]:
                c["water_level"] = mapping[c["id"]]; n += 1
        elif "water_level" in c:
            del c["water_level"]; n += 1
    if n:
        ledger["version"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        CAMERAS.write_text(json.dumps(ledger, ensure_ascii=False, indent=1) + ("\n" if raw.endswith("\n") else ""),
                           encoding="utf-8")
    print(f"台帳更新 {n} 件、観測所 {len(stations)} 件", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
