"""今昔マップ on the web（埼玉大学 谷謙二氏／今昔マップ運営委員会）の地域・時期・範囲の表を作り、
アプリ同梱アセットに書く。

配信元 `https://ktgis.net/kjmapw/kjmapdata.js` の kjmapDataSet[地域].age[].mapList[]（図郭ごとの
north/west/south/east）から、地域と時期ごとの外接範囲を求める。アプリの地図レイヤー「昔の地図」が
「地図の中心がどの地域に入っているか」「その地域にどの時期があるか」を判定するのに使う。

- タイル: `https://ktgis.net/kjmapw/kjtilemap/<地域>/<時期>/{z}/{x}/{y}.png`（TMS。y は南西始点）
- ズーム 8〜16。東北地方太平洋岸と関東は 8〜15（タイルサービスのページの記載）
- 利用条件: 画面に「今昔マップ on the web」の文字を入れる。タイルの複製配信は禁止（配信元を直接読む）
- 地域の追加は年に数回程度なので、たまに回せば足りる

usage: python -m tools.kjmap_regions [--js kjmapdata.js]
"""
from __future__ import annotations

import argparse
import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "app" / "assets" / "data" / "kjmap_regions.json"
JS_URL = "https://ktgis.net/kjmapw/kjmapdata.js"
UA = {"User-Agent": "LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)"}
# タイルサービスのページに「東北地方太平洋岸と関東は 8〜15」とある
ZMAX_15 = {"tohoku_pacific_coast", "kanto"}


def parse(js: str) -> list[dict]:
    """kjmapdata.js から地域の一覧（id, name, zmax, 範囲, 時期の配列）を作る"""
    head = js[: js.find("kjmapDataSet['")]
    names = {
        folder: name
        for name, folder in re.findall(
            r"\{\s*name:\s*['\"]([^'\"]+)['\"][^}]*folderName:\s*['\"]([a-z_0-9]+)['\"]", head, re.S)
    }
    regions = []
    for m in re.finditer(
            r"kjmapDataSet\['([a-z_0-9]+)'\] = new Object\(\);(.*?)"
            r"(?=kjmapDataSet\['[a-z_0-9]+'\] = new Object|\Z)", js, re.S):
        rid, body = m.group(1), m.group(2)
        eras = []
        for chunk in body.split("dataset.age.push(")[1:]:
            fm = re.search(r"folderName:\s*'([^']+)',\s*start:\s*(\d+),\s*end:\s*(\d+)", chunk)
            ns = [float(x) for x in re.findall(r"north:([\d.]+)", chunk)]
            ss = [float(x) for x in re.findall(r"south:([\d.]+)", chunk)]
            ws = [float(x) for x in re.findall(r"west:([\d.]+)", chunk)]
            es = [float(x) for x in re.findall(r"east:([\d.]+)", chunk)]
            if not fm or not ns:
                continue
            eras.append({
                "f": fm.group(1), "start": int(fm.group(2)), "end": int(fm.group(3)),
                "n": round(max(ns), 4), "w": round(min(ws), 4), "s": round(min(ss), 4), "e": round(max(es), 4),
            })
        if not eras:
            continue
        eras.sort(key=lambda a: a["start"])
        regions.append({
            "id": rid, "name": names.get(rid, rid), "zmax": 15 if rid in ZMAX_15 else 16,
            "n": max(a["n"] for a in eras), "w": min(a["w"] for a in eras),
            "s": min(a["s"] for a in eras), "e": max(a["e"] for a in eras),
            "eras": eras,
        })
    return regions


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--js", help="kjmapdata.js のローカルファイル（省略時は取得）")
    args = ap.parse_args()
    if args.js:
        js = Path(args.js).read_text(encoding="utf-8")
    else:
        req = urllib.request.Request(JS_URL, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
            js = r.read().decode("utf-8")
    regions = parse(js)
    OUT.write_text(json.dumps({
        "source": JS_URL,
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tile": "https://ktgis.net/kjmapw/kjtilemap/{region}/{era}/{z}/{x}/{y}.png",
        "regions": regions,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"今昔マップ 地域 {len(regions)}・時期 {sum(len(r['eras']) for r in regions)} → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
