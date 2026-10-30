"""川の防災情報の積雪観測所（テレメータ）の表を同梱アセットとして生成する。

アプリの災害速報タブ「積雪」の「近くの観測点」で、最寄りに入った観測所の積雪深を
端末が開いたときだけ川の防災情報から直接取る（水位グラフと同じ扱い。同サイトは規約で
ツールによる定期的なデータ収集を控えるよう求めているので、サーバーでは集約しない）。
その観測所の名称・座標の表だけを、この道具で一度限り作る。

川の防災情報の内部ファイル（SPA 内部なので構造変化に注意。2026-10-30 確認）
- 全市町村 `map/twn/twnarea.json`（snwExistFlg=1 の市町村に積雪観測所がある。74 市町村）
- 市町村の観測所一覧 `obslist/obs/twnlist/<twnCd>.json` の obsList.obsSnow[]（obsFcd・obsNm）
- 観測所マスタ `master/obs/snw/<obsFcd>.json` の obsInfo（lat/lon/alti/obsNm/twnCd）
- 現況 `tmlist/snw/YYYYMMDD/HHmm/<obsFcd>.json`（10分スロット。obsValue.snwdp は cm、
  snwdpCcd≠0 は欠測。hrValues に時間値）… こちらはアプリが読む

出力: app/assets/data/kawabou_snow_stations.json
  {"source": ..., "generated": ..., "stations": [{"id": obsFcd, "n": 名称, "lat", "lng", "m": JIS5桁}]}
市区町村コードは twnCd（prefCd*1000 + JIS 下3桁）からではなく、アメダスと同じく国土地理院の
逆ジオコーダで引く（政令市は区単位になる。控え data/municipality_geocache.json を共用）。
観測所の追加は年に数回なので、冬前に一度回せば足りる。

実行: python tools/kawabou_snow_stations.py
"""
from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.fill_municipality import CACHE, UA, cache_key, reverse_geocode  # noqa: E402

BASE = "https://www.river.go.jp/kawabou/file/files/"
OUT = REPO_ROOT / "app" / "assets" / "data" / "kawabou_snow_stations.json"
INTERVAL = 1.2  # 川の防災情報への連続アクセスの間隔（秒）。水位観測所の対応付けと同じ


def snow_towns(twnarea: Any) -> list[int]:
    """twnarea.json → 積雪観測所のある市町村コード（twnCd）。"""
    items = twnarea if isinstance(twnarea, list) else next(
        (v for v in (twnarea or {}).values() if isinstance(v, list)), [])
    return [int(t["twnCd"]) for t in items if isinstance(t, dict) and str(t.get("snwExistFlg")) == "1" and t.get("twnCd")]


def snow_obs(twnlist: Any) -> list[str]:
    """twnlist/<twnCd>.json → 積雪観測所の obsFcd。dspFlg が 0 のものは出さない。"""
    ol = (twnlist or {}).get("obsList") or twnlist or {}
    return [str(o["obsFcd"]) for o in ol.get("obsSnow") or []
            if isinstance(o, dict) and o.get("obsFcd") and str(o.get("dspFlg", 1)) != "0"]


def station_of(obs: str, master: Any) -> dict[str, Any] | None:
    info = (master or {}).get("obsInfo") or {}
    try:
        lat, lng = float(info["lat"]), float(info["lon"])
    except (KeyError, TypeError, ValueError):
        return None
    name = str(info.get("obsNm") or "").strip()
    if not name:
        return None
    return {"id": obs, "n": name, "lat": round(lat, 6), "lng": round(lng, 6)}


def main() -> int:
    import requests

    sess = requests.Session()
    sess.headers.update(UA)

    def get(path: str) -> Any:
        r = sess.get(BASE + path, timeout=30)
        time.sleep(INTERVAL)
        r.raise_for_status()
        return r.json()

    towns = snow_towns(get("map/twn/twnarea.json"))
    print(f"積雪観測所のある市町村: {len(towns)}")
    obs_ids: list[str] = []
    for twn in towns:
        try:
            obs_ids.extend(snow_obs(get(f"obslist/obs/twnlist/{twn}.json")))
        except Exception as e:  # noqa: BLE001
            print(f"  twnlist {twn}: {type(e).__name__}", file=sys.stderr)
    obs_ids = list(dict.fromkeys(obs_ids))
    print(f"観測所: {len(obs_ids)}")

    stations: list[dict[str, Any]] = []
    for obs in obs_ids:
        try:
            st = station_of(obs, get(f"master/obs/snw/{obs}.json"))
        except Exception as e:  # noqa: BLE001
            print(f"  master {obs}: {type(e).__name__}", file=sys.stderr)
            continue
        if st:
            stations.append(st)

    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    queried = 0
    for st in stations:
        key = cache_key(st["lat"], st["lng"])
        if key not in cache:
            try:
                cache[key] = reverse_geocode(st["lat"], st["lng"])
            except Exception as e:  # noqa: BLE001
                print(f"  逆ジオコーダ {st['id']}: {type(e).__name__}", file=sys.stderr)
                time.sleep(3)
                continue
            queried += 1
            time.sleep(1.0)
        if cache.get(key):
            st["m"] = cache[key]
    if queried:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    stations.sort(key=lambda s: s["id"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "source": "国土交通省 川の防災情報（積雪観測所の名称・座標。値は端末が直接取得）",
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "stations": stations,
    }, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    no_m = sum(1 for s in stations if not s.get("m"))
    print(f"{OUT.relative_to(REPO_ROOT)}: {len(stations)}観測所（市区町村なし {no_m}、逆ジオコーダ {queried}件）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
