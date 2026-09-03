"""座標はあるが市区町村コードが無い国内カメラに、国土地理院の逆ジオコーダで municipality を補う。

    python tools/fill_municipality.py            # data/cameras.json を更新（version も更新）
    python tools/fill_municipality.py --dry-run  # 件数だけ

背景（2026-09-03）: 承認済み国内カメラ 21,079 のうち 5,148 に municipality が無く、
カメラ詳細「この付近の宿を探す」のじゃらん（市区町村名キーワード）と、震度連動の
市区町村カメラ一覧が効かなかった。

- 対象: review.status=approved・国内（prefecture != 99）・lat/lng あり・municipality 無し・
  coord_accuracy が area（広域代表点）でないもの
- 逆ジオコーダ `mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress` の muniCd（JIS 5桁）。
  海上・国外は `{}`。先頭2桁が台帳の prefecture と違うもの（県境・座標ずれ）は書かずに報告する
- 結果は data/municipality_geocache.json に控える（再実行は速い）。約4req/秒に抑える
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAMERAS = ROOT / "data" / "cameras.json"
CACHE = ROOT / "data" / "municipality_geocache.json"
ENDPOINT = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress"
UA = {"User-Agent": "LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)"}


def cache_key(lat: float, lng: float) -> str:
    return f"{lat:.5f},{lng:.5f}"


def reverse_geocode(lat: float, lng: float) -> str | None:
    """muniCd（5桁）。海上・国外・失敗は None（失敗は呼び出し側で区別しない）"""
    q = urllib.parse.urlencode({"lat": f"{lat:.5f}", "lon": f"{lng:.5f}"})
    req = urllib.request.Request(f"{ENDPOINT}?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:  # noqa: S310
        j = json.load(r)
    res = j.get("results") if isinstance(j, dict) else None
    code = res.get("muniCd") if isinstance(res, dict) else None
    return code if isinstance(code, str) and len(code) == 5 else None


def targets(cams: list[dict]) -> list[dict]:
    return [
        c for c in cams
        if c.get("review", {}).get("status") == "approved"
        and c.get("prefecture") != "99"
        and c.get("lat") is not None and c.get("lng") is not None
        and not c.get("municipality")
        and c.get("coord_accuracy") != "area"
    ]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--interval", type=float, default=0.25)
    args = ap.parse_args()

    data = json.loads(CAMERAS.read_text(encoding="utf-8"))
    cams = data["cameras"]
    cache: dict = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    todo = targets(cams)
    print(f"対象 {len(todo)} 件（cache {len(cache)} 件）")
    if args.dry_run:
        return 0

    filled = 0
    mismatch: list[tuple[str, str, str, str]] = []
    nohit = 0
    errors = 0
    last_save = time.time()
    for i, c in enumerate(todo, 1):
        key = cache_key(c["lat"], c["lng"])
        if key in cache:
            code = cache[key]
        else:
            try:
                code = reverse_geocode(c["lat"], c["lng"])
            except Exception as e:  # noqa: BLE001
                errors += 1
                print(f"  ! {c['id']} {e}")
                time.sleep(3)
                continue
            cache[key] = code
            time.sleep(args.interval)
        if code is None:
            nohit += 1
        elif code[:2] != c.get("prefecture"):
            mismatch.append((c["id"], c["name"], c.get("prefecture", ""), code))
        else:
            c["municipality"] = code
            filled += 1
        if time.time() - last_save > 30:
            CACHE.write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
            last_save = time.time()
            print(f"  {i}/{len(todo)} filled={filled} nohit={nohit} mismatch={len(mismatch)} err={errors}")

    CACHE.write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if filled:
        data["version"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        CAMERAS.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"完了: filled={filled} nohit(海上等)={nohit} mismatch(県違い)={len(mismatch)} errors={errors}")
    for m in mismatch:
        print("  県違い:", *m)
    return 0


if __name__ == "__main__":
    sys.exit(main())
