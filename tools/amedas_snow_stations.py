"""アメダスの積雪深観測点の表を作り、アプリ同梱アセットに書く。

気象庁 `bosai/amedas/const/amedastable.json` のうち積雪を観測する地点
（elems の6文字目が '1'。2026-09 時点で336地点）を選び、国土地理院の
逆ジオコーダで市区町村コード（JIS 5桁）を付けて
`app/assets/data/amedas_snow_stations.json` に書く。
アプリの災害速報タブ「積雪」（冬季）が都道府県＞市区町村で並べるのに使う。

- 逆ジオコーダの結果は data/municipality_geocache.json（fill_municipality と共用）に控える
- 観測点の追加・移設は年に数回なので、冬前に一度回せば足りる

usage: python -m tools.amedas_snow_stations [--table amedastable.json]
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from tools.fill_municipality import CACHE, UA, cache_key, reverse_geocode

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "app" / "assets" / "data" / "amedas_snow_stations.json"
TABLE_URL = "https://www.jma.go.jp/bosai/amedas/const/amedastable.json"
SNOW_ELEM_INDEX = 5   # elems "11111111" の6文字目＝積雪深


def snow_stations(table: dict) -> list[dict]:
    """積雪深を観測する地点だけを id 順で返す（座標は度分→十進）"""
    out = []
    for sid, v in sorted(table.items()):
        elems = str(v.get("elems", ""))
        if len(elems) <= SNOW_ELEM_INDEX or elems[SNOW_ELEM_INDEX] != "1":
            continue
        lat = v["lat"][0] + v["lat"][1] / 60
        lng = v["lon"][0] + v["lon"][1] / 60
        out.append({"id": sid, "n": v.get("kjName") or sid,
                    "lat": round(lat, 4), "lng": round(lng, 4)})
    return out


def attach_municipality(stations: list[dict], cache: dict, sleep: float = 0.25) -> int:
    """GSI 逆ジオコーダで muni（JIS 5桁）を付ける。控えにあるものは問い合わせない"""
    fetched = 0
    for s in stations:
        key = cache_key(s["lat"], s["lng"])
        if key not in cache:
            try:
                cache[key] = reverse_geocode(s["lat"], s["lng"])
            except Exception as e:  # noqa: BLE001
                print(f"  逆ジオコーダ失敗 {s['id']} {s['n']}: {e}")
                continue
            fetched += 1
            time.sleep(sleep)
        if cache[key]:
            s["m"] = cache[key]
    return fetched


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", help="amedastable.json のローカルファイル（省略時は取得）")
    args = ap.parse_args()
    if args.table:
        table = json.loads(Path(args.table).read_text(encoding="utf-8"))
    else:
        req = urllib.request.Request(TABLE_URL, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
            table = json.load(r)
    stations = snow_stations(table)
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    fetched = attach_municipality(stations, cache)
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=0, sort_keys=True), encoding="utf-8")
    missing = [s for s in stations if "m" not in s]
    OUT.write_text(json.dumps({
        "source": TABLE_URL,
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "stations": stations,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"積雪観測点 {len(stations)}（逆ジオコーダ新規 {fetched}、市区町村なし {len(missing)}）→ {OUT}")
    for s in missing:
        print("  市区町村なし:", s["id"], s["n"], s["lat"], s["lng"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
