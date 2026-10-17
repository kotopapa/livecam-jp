"""座標調査の補助: OpenPOI API（名前付き施設の検索）＋国土地理院で都道府県一致を検証する。

    python -m tools.poi_lookup "犬吠埼灯台" --pref 12 [--near 35.7,140.86] [--muni 12202]

- OpenPOI API（https://docs.openpoiapi.com/ 、キー不要）の /v1/search /v1/suggest を呼ぶ。
  店・宿・駅・名前付き施設に強く、自然物・ランドマークは弱い。Nominatim が 429 になるときの代わりに使う
- 候補の座標は国土地理院の逆ジオコーダで都道府県（指定があれば市区町村）を確かめ、一致したものだけ返す
- OpenPOI で見つからなければ国土地理院 AddressSearch（地名・住所向き）に回る（method="gsi"）
- **座標の精度は常に "approx"**。OpenPOI の座標は数百 m ずれることがある。exact に上げてよいのは、
  呼び出し側が別の根拠（公式座標・OSM の橋名一致など）を持つときだけ
- 保存するときは licenses / attributions を配列のまま一緒に保存する（OpenPOI の規約）
- 控え: data/poi_cache.json（クエリ＋条件ごとに上位5件と取得日時。同じクエリは再取得しない）
- 礼儀: 1リクエストごとに 0.3 秒空ける（共有資源）
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

try:  # 国土地理院の証明書チェーンが素の urllib では検証できない環境がある
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

ROOT = Path(__file__).resolve().parent.parent
CACHE_PATH = ROOT / "data" / "poi_cache.json"
OPENPOI = "https://api.openpoiapi.com/v1"
GSI_SEARCH = "https://msearch.gsi.go.jp/address-search/AddressSearch"
GSI_REVERSE = "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress"
UA = {"User-Agent": "LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)"}
INTERVAL = 0.3
KEEP = 5  # 控えに残す上位件数
ACCURACY = "approx"

_cache: dict | None = None
_last_request = 0.0


def _get_json(url: str, params: dict) -> object:
    global _last_request
    wait = INTERVAL - (time.time() - _last_request)
    if wait > 0:
        time.sleep(wait)
    q = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{url}?{q}", headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:  # noqa: S310
            return json.load(r)
    finally:
        _last_request = time.time()


def _load_cache() -> dict:
    global _cache
    if _cache is None:
        _cache = json.loads(CACHE_PATH.read_text(encoding="utf-8")) if CACHE_PATH.exists() else {}
    return _cache


def save_cache() -> None:
    if _cache is not None:
        CACHE_PATH.write_text(json.dumps(_cache, ensure_ascii=False, indent=0, sort_keys=True) + "\n",
                              encoding="utf-8")


def _cached(key: str, fetch) -> list:
    cache = _load_cache()
    if key in cache:
        return cache[key]["results"]
    results = fetch()[:KEEP]
    cache[key] = {"results": results, "fetched": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")}
    return results


def normalize_poi(item: dict) -> dict:
    """OpenPOI の1件を共通形式へ。raw_id は応答に ID が無いので source+名称+座標で作る"""
    lat, lng = item.get("lat"), item.get("lng")
    return {
        "name": item.get("name") or "",
        "lat": lat,
        "lng": lng,
        "category": item.get("category") or "",
        "address": item.get("address") or "",
        "source": item.get("source") or "",
        "licenses": list(item.get("licenses") or []),
        "attributions": list(item.get("attributions") or []),
        "raw_id": item.get("id") or f"{item.get('source', '')}:{item.get('name', '')}:{lat},{lng}",
    }


def _poi_params(name, center, radius_m, bbox, limit) -> dict:
    p: dict = {"q": name, "limit": limit}
    if center:  # center は (lat, lng)。API は 経度,緯度
        p["center"] = f"{center[1]},{center[0]}"
        if radius_m:
            p["radius"] = int(radius_m)
    if bbox:  # (min_lng, min_lat, max_lng, max_lat)
        p["bbox"] = ",".join(str(v) for v in bbox)
    return p


def _poi_call(endpoint: str, name, center, radius_m, bbox, limit) -> list[dict]:
    key = f"openpoi:{endpoint}:{name}|{center}|{radius_m}|{bbox}|{limit}"

    def fetch() -> list[dict]:
        j = _get_json(f"{OPENPOI}/{endpoint}", _poi_params(name, center, radius_m, bbox, limit))
        items = j.get("results") if endpoint == "search" else j.get("suggestions")
        return [normalize_poi(i) for i in (items or []) if i.get("lat") is not None and i.get("lng") is not None]

    return _cached(key, fetch)


def openpoi_search(name, *, center=None, radius_m=None, bbox=None, limit=10) -> list[dict]:
    """/v1/search。スペース区切りは OR。center=(lat,lng) を付けると距離順"""
    return _poi_call("search", name, center, radius_m, bbox, limit)


def openpoi_suggest(name, *, center=None, radius_m=None, bbox=None, limit=10) -> list[dict]:
    """/v1/suggest。複数語は AND、かな/カナ/全半角を吸収。2文字以下は center か bbox が要る"""
    return _poi_call("suggest", name, center, radius_m, bbox, min(limit, 20))


def gsi_address(name: str) -> list[dict]:
    """国土地理院 AddressSearch（住所・地名向き。施設名は不可）。muni は addressCode"""
    def fetch() -> list[dict]:
        j = _get_json(GSI_SEARCH, {"q": name})
        out = []
        for f in j if isinstance(j, list) else []:
            lng, lat = f["geometry"]["coordinates"][:2]
            props = f.get("properties", {})
            out.append({"name": props.get("title", ""), "lat": lat, "lng": lng,
                        "muni": props.get("addressCode") or ""})
        return out

    return _cached(f"gsi:{name}", fetch)


def gsi_muni(lat: float, lng: float) -> str | None:
    """逆ジオコーダの市区町村コード（5桁）。海上・失敗は None"""
    def fetch() -> list:
        j = _get_json(GSI_REVERSE, {"lat": f"{lat:.5f}", "lon": f"{lng:.5f}"})
        res = j.get("results") if isinstance(j, dict) else None
        code = res.get("muniCd") if isinstance(res, dict) else None
        return [code] if isinstance(code, str) and len(code) == 5 else []

    r = _cached(f"rev:{lat:.5f},{lng:.5f}", fetch)
    return r[0] if r else None


def distance_m(a, b) -> float:
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))


def _name_rank(query: str, name: str) -> int:
    q = query.replace(" ", "").replace("　", "")
    n = name.replace(" ", "").replace("　", "")
    if n == q:
        return 0
    if q in n or n in q:
        return 1
    return 2


def resolve_camera_point(name: str, pref_code: str, *, near=None, muni: str | None = None,
                         radius_m: float | None = None) -> list[dict]:
    """名前から座標候補を返す。pref_code は JIS 2桁、near は (lat, lng)、muni は JIS 5桁。

    OpenPOI の候補のうち、逆ジオコーダで都道府県（muni 指定時は市区町村も）が一致するものだけを
    名称一致 → 距離の順に返す。無ければ国土地理院 AddressSearch に回る。
    accuracy は常に "approx"（exact に上げるのは呼び出し側に別の根拠があるときだけ）。
    licenses / attributions は保存時に配列のまま併記すること。
    """
    pref = str(pref_code).zfill(2)

    def ok(code: str | None) -> bool:
        return bool(code) and code[:2] == pref and (not muni or code == muni)

    def rank(c: dict):
        d = distance_m(near, (c["lat"], c["lng"])) if near else 0.0
        return (_name_rank(name, c["name"]), d)

    out: list[dict] = []
    for c in openpoi_search(name, center=near, radius_m=radius_m):
        code = gsi_muni(c["lat"], c["lng"])
        if ok(code):
            out.append({**c, "muni": code, "method": "openpoi", "accuracy": ACCURACY})
    if not out:
        for c in gsi_address(name):
            if ok(c["muni"] or gsi_muni(c["lat"], c["lng"])):
                out.append({"name": c["name"], "lat": c["lat"], "lng": c["lng"], "category": "", "address": "",
                            "source": "gsi", "licenses": [], "attributions": ["国土地理院 AddressSearch"],
                            "raw_id": f"gsi:{c['name']}:{c['lat']},{c['lng']}", "muni": c["muni"],
                            "method": "gsi", "accuracy": ACCURACY})
    out.sort(key=rank)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="OpenPOI＋国土地理院で座標候補を探す")
    ap.add_argument("name")
    ap.add_argument("--pref", required=True, help="JIS 都道府県コード（例 12）")
    ap.add_argument("--near", help="lat,lng")
    ap.add_argument("--muni", help="JIS 市区町村コード 5桁")
    ap.add_argument("--radius", type=float, help="--near からの半径 m")
    a = ap.parse_args(argv)
    near = tuple(float(v) for v in a.near.split(",")) if a.near else None
    try:
        res = resolve_camera_point(a.name, a.pref, near=near, muni=a.muni, radius_m=a.radius)
    finally:
        save_cache()
    if not res:
        print("候補なし")
        return 1
    for r in res:
        d = f"  {distance_m(near, (r['lat'], r['lng'])):.0f}m" if near else ""
        print(f"[{r['method']}] {r['name']}  {r['lat']:.6f},{r['lng']:.6f}  {r['muni']}  "
              f"{r['category']}  {r['address']}{d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
