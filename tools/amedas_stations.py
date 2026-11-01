"""アメダス全観測点の表を作り、アプリ同梱アセットに書く。

気象庁 `bosai/amedas/const/amedastable.json` のうち気温を観測する地点
（elems の1文字目が '1'。降水量だけの雨量計約370地点は除く。約920地点）を
`app/assets/data/amedas_stations.json` に書く。キーは id / n（観測点名）/
lat / lng（度分→十進）/ e（elems 文字列＝観測する要素のフラグ）。
アプリのカメラ詳細「この地点の天気」が最寄りの観測点を選ぶのに使う
（積雪タブ用の amedas_snow_stations.json とは別。こちらは市区町村コード無し）。

- 観測点の追加・移設は年に数回なので、年1回程度回せば足りる

usage: python -m tools.amedas_stations [--table amedastable.json]
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "app" / "assets" / "data" / "amedas_stations.json"
TABLE_URL = "https://www.jma.go.jp/bosai/amedas/const/amedastable.json"
UA = {"User-Agent": "LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)"}


def stations(table: dict) -> list[dict]:
    """気温を観測する地点を id 順で返す（座標は度分→十進、小数4桁）"""
    out = []
    for sid, v in sorted(table.items()):
        if not str(v.get("elems", "")).startswith("1"):
            continue
        try:
            lat = v["lat"][0] + v["lat"][1] / 60
            lng = v["lon"][0] + v["lon"][1] / 60
        except (KeyError, IndexError, TypeError):
            continue
        out.append({"id": sid, "n": v.get("kjName") or sid,
                    "lat": round(lat, 4), "lng": round(lng, 4),
                    "e": str(v.get("elems", ""))})
    return out


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
    st = stations(table)
    OUT.write_text(json.dumps({
        "source": TABLE_URL,
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "stations": st,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"観測点 {len(st)} → {OUT}（{OUT.stat().st_size} bytes）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
