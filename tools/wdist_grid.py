"""気象庁「天気分布予報」（5km メッシュ・3 時間ごと・約 2 日分）を、カメラ詳細画面の
「この地点の天気」カード用の配信 JSON（2° ブロック）にまとめる。

気象庁のデータ（2026-11-02 実取得で確認。SPA 内部ファイルなので構造変化に注意）
- 一覧   https://www.jma.go.jp/bosai/jmatile/data/wdist/targetTimes.json
         [{basetime, validtime, member:"none", elements:[r3,r3_nd,s3,s3_nd,temp,temp_nd,temp_point,wm,wm_nd]}]
         basetime / validtime は UTC の yyyymmddHHMMSS。basetime は1つ（発表は1日3回程度）、
         validtime は3時間刻みで約11個。要素は validtime ごとに違う（temp が無い回がある）
- 気温   .../wdist/<basetime>/none/<validtime>/surf/temp_point/data.geojson
         gzip の GeoJSON（Content-Encoding なしで生 gzip のことがある。先頭 1f 8b なら展開）。
         32,496 点。coordinates=[lng,lat]、properties.value は整数 ℃ の文字列（負あり）
- 格子   lat = 0.025 + 0.05·gi、lng = 0.03125 + 0.0625·gj（全点がこの格子に乗る）
- 天気・降水量・降雪量はタイル PNG のみ .../surf/<wm|r3|s3>/{z}/{x}/{y}.png
         Web メルカトル 256px・偶数ズームのみ。z6（1px ≈ 2km）で格子点の画素を読む。透明＝データなし／未満

色（不透明）→ コード
  wm  1 晴れ (255,170,0) / 2 くもり (170,170,170) / 3 雨 (0,65,255) / 4 雨または雪 (160,210,255) / 5 雪 (242,242,255)
  r3  mm/3h  1: 1–5 (160,210,255) / 2: 5–10 (33,140,255) / 3: 10–15 (0,65,255) / 4: 15–20 (255,245,0) / 5: 20以上 (255,153,0)
  s3  cm/3h  1: 1–3 (160,210,255) / 2: 3–6 (33,140,255) / 3: 6以上 (0,65,255)
  透明は 0（r3 は 1mm 未満、s3 は 1cm 未満、wm はなし/不明）。照合は各成分 ±8 で最も近い凡例色

配信形式（アプリ側は app/lib/data/point_weather.dart）
- site/v1/wdist/index.json   {basetime, validtimes, generated, blocks:["22_122",...]}
- site/v1/wdist/<lat0>_<lng0>.json  lat0/lng0 は 2° 刻みの偶数。
    {basetime, validtimes, lat0, lng0, points:[{i,j,t,w,r,s}]}
    lat = lat0 + 0.025 + 0.05·i（i 0〜39）、lng = lng0 + 0.03125 + 0.0625·j（j 0〜31）
    t は気温の整数（無ければ null）、w/r/s は上のコード。配列長は validtimes と同じ。
    その validtime に要素が無いとき t は null、w/r/s は 0。点の集合は temp_point の格子点を正とする

publish（30分ごと）は毎回は生成しない。公開中の index.json と basetime が同じなら
公開中のブロックをそのままダウンロードして置く。違えば気象庁から生成する。どちらも取れなければ何も置かない。
"""
from __future__ import annotations

import gzip
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SITE_PATH = REPO_ROOT / "site" / "v1" / "wdist"
PUBLISHED_BASE = "https://kotopapa.github.io/livecam-jp/v1/wdist/"
JMA_BASE = "https://www.jma.go.jp/bosai/jmatile/data/wdist/"
UA = "livecam-jp wdist (+https://kotopapa.github.io/livecam-jp/)"
HOST_INTERVAL = 0.2
ZOOM = 6
TOL = 8
BLOCK_I = 40   # 2° / 0.05
BLOCK_J = 32   # 2° / 0.0625

PALETTES: dict[str, list[tuple[tuple[int, int, int], int]]] = {
    "wm": [((255, 170, 0), 1), ((170, 170, 170), 2), ((0, 65, 255), 3), ((160, 210, 255), 4), ((242, 242, 255), 5)],
    "r3": [((160, 210, 255), 1), ((33, 140, 255), 2), ((0, 65, 255), 3), ((255, 245, 0), 4), ((255, 153, 0), 5)],
    "s3": [((160, 210, 255), 1), ((33, 140, 255), 2), ((0, 65, 255), 3)],
}


def color_code(element: str, rgba: tuple[int, ...]) -> int:
    """画素の色 → コード。透明・凡例に近い色が無ければ 0。"""
    if len(rgba) > 3 and rgba[3] < 128:
        return 0
    best, best_d = 0, 10 ** 9
    for (r, g, b), code in PALETTES[element]:
        if abs(rgba[0] - r) <= TOL and abs(rgba[1] - g) <= TOL and abs(rgba[2] - b) <= TOL:
            d = abs(rgba[0] - r) + abs(rgba[1] - g) + abs(rgba[2] - b)
            if d < best_d:
                best, best_d = code, d
    return best


def tile_pixel(lat: float, lng: float, z: int = ZOOM) -> tuple[int, int, int, int]:
    """緯度経度 → (タイル x, タイル y, タイル内 px, py)。Web メルカトル・256px。"""
    n = 2 ** z
    x = (lng + 180.0) / 360.0 * n
    la = math.radians(lat)
    y = (1.0 - math.log(math.tan(la) + 1.0 / math.cos(la)) / math.pi) / 2.0 * n
    tx, ty = int(math.floor(x)), int(math.floor(y))
    return tx, ty, min(255, int((x - tx) * 256)), min(255, int((y - ty) * 256))


def grid_index(lat: float, lng: float) -> tuple[int, int]:
    """緯度経度 → 全国格子番号 (gi, gj)。lat = 0.025+0.05·gi、lng = 0.03125+0.0625·gj。"""
    return int(round((lat - 0.025) / 0.05)), int(round((lng - 0.03125) / 0.0625))


def block_of(gi: int, gj: int) -> tuple[int, int, int, int]:
    """格子番号 → (lat0, lng0, i, j)。lat0/lng0 は 2° 刻みの偶数。"""
    return (gi // BLOCK_I) * 2, (gj // BLOCK_J) * 2, gi % BLOCK_I, gj % BLOCK_J


def block_name(lat0: int, lng0: int) -> str:
    return f"{lat0}_{lng0}"


def grid_latlng(gi: int, gj: int) -> tuple[float, float]:
    return 0.025 + 0.05 * gi, 0.03125 + 0.0625 * gj


def parse_target_times(arr: Any) -> tuple[str, dict[str, set[str]]] | None:
    """targetTimes.json → (最新の basetime, {validtime: 要素の集合})。member が none 以外は除く。"""
    rows = [r for r in arr if isinstance(r, dict) and r.get("member", "none") == "none"
            and r.get("basetime") and r.get("validtime")]
    if not rows:
        return None
    base = max(r["basetime"] for r in rows)
    vt: dict[str, set[str]] = {}
    for r in rows:
        if r["basetime"] == base:
            vt.setdefault(r["validtime"], set()).update(r.get("elements") or [])
    return base, vt


def decode_geojson(raw: bytes) -> dict[str, Any]:
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def temp_points(gj: dict[str, Any]) -> dict[tuple[int, int], int]:
    out: dict[tuple[int, int], int] = {}
    for f in gj.get("features", []):
        try:
            lng, lat = f["geometry"]["coordinates"][:2]
            v = int(round(float(f["properties"]["value"])))
        except (KeyError, ValueError, TypeError):
            continue
        out[grid_index(lat, lng)] = v
    return out


def _read_tiles(fx: Any, element: str, base: str, vt: str, pix: dict[tuple[int, int], tuple[int, int, int, int]]
                ) -> dict[tuple[int, int], int] | None:
    """全格子点について要素のコードを読む。必要なタイルだけ取る。1枚も取れなければ None。"""
    from io import BytesIO
    from PIL import Image
    tiles: dict[tuple[int, int], Any] = {}
    ok = 0
    for key in sorted({(p[0], p[1]) for p in pix.values()}):
        url = f"{JMA_BASE}{base}/none/{vt}/surf/{element}/{ZOOM}/{key[0]}/{key[1]}.png"
        try:
            tiles[key] = Image.open(BytesIO(fx.get(url))).convert("RGBA")
            ok += 1
        except Exception:  # noqa: BLE001  タイルが無い（404）はデータなしと同じ
            tiles[key] = None
    if not ok:
        return None
    out: dict[tuple[int, int], int] = {}
    for g, (tx, ty, px, py) in pix.items():
        im = tiles.get((tx, ty))
        out[g] = color_code(element, im.getpixel((px, py))) if im is not None else 0
    return out


def generate(out_dir: Path, fx: Any) -> bool:
    """気象庁から生成して out_dir に書く。要素が1つも取れなければ False。"""
    parsed = parse_target_times(fx.json(JMA_BASE + "targetTimes.json"))
    if not parsed:
        return False
    base, vmap = parsed
    vts = sorted(vmap)
    temps: dict[str, dict[tuple[int, int], int]] = {}
    for vt in vts:
        if "temp_point" in vmap[vt]:
            try:
                temps[vt] = temp_points(decode_geojson(
                    fx.get(f"{JMA_BASE}{base}/none/{vt}/surf/temp_point/data.geojson")))
            except Exception as e:  # noqa: BLE001
                print(f"wdist: 気温 {vt} 取得失敗 {type(e).__name__}", file=sys.stderr)
    grid: set[tuple[int, int]] = set()
    for t in temps.values():
        grid |= set(t)
    if not grid:
        return False
    pix = {g: tile_pixel(*grid_latlng(*g)) for g in grid}
    codes: dict[str, dict[str, dict[tuple[int, int], int]]] = {"wm": {}, "r3": {}, "s3": {}}
    for vt in vts:
        for el in codes:
            if el in vmap[vt]:
                r = _read_tiles(fx, el, base, vt, pix)
                if r is not None:
                    codes[el][vt] = r
    blocks: dict[tuple[int, int], list[dict[str, Any]]] = {}
    for g in sorted(grid):
        lat0, lng0, i, j = block_of(*g)
        blocks.setdefault((lat0, lng0), []).append({
            "i": i, "j": j,
            "t": [temps[vt].get(g) if vt in temps else None for vt in vts],
            "w": [codes["wm"][vt][g] if vt in codes["wm"] else 0 for vt in vts],
            "r": [codes["r3"][vt][g] if vt in codes["r3"] else 0 for vt in vts],
            "s": [codes["s3"][vt][g] if vt in codes["s3"] else 0 for vt in vts],
        })
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.json"):
        old.unlink()
    names = []
    for (lat0, lng0), pts in sorted(blocks.items()):
        name = block_name(lat0, lng0)
        names.append(name)
        _dump(out_dir / f"{name}.json", {"basetime": base, "validtimes": vts, "lat0": lat0, "lng0": lng0, "points": pts})
    _dump(out_dir / "index.json", {"basetime": base, "validtimes": vts,
                                    "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                    "blocks": names})
    return True


def _dump(path: Path, obj: Any) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def reuse_published(out_dir: Path, fx: Any, base: str) -> bool:
    """公開中の index.json が basetime 同じなら、ブロック一式をダウンロードして置く。"""
    idx = json.loads(fx.get(PUBLISHED_BASE + "index.json").decode("utf-8"))
    if idx.get("basetime") != base or not idx.get("blocks"):
        return False
    files = {n: fx.get(f"{PUBLISHED_BASE}{n}.json") for n in idx["blocks"]}
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.json"):
        old.unlink()
    for n, raw in files.items():
        (out_dir / f"{n}.json").write_bytes(raw)
    (out_dir / "index.json").write_text(json.dumps(idx, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return True


def _make_fetcher() -> Any:
    from tools.snow_points import Fetcher
    fx = Fetcher(HOST_INTERVAL)
    fx.s.headers.update({"User-Agent": UA})
    return fx


def sync_site(fx: Any = None, out_dir: Path | None = None) -> int:
    """site/v1/wdist/ を用意する。置いたファイル数を返す（何も置けなければ 0）。例外は握りつぶす。"""
    out_dir = out_dir or SITE_PATH
    try:
        if fx is None:
            fx = _make_fetcher()
    except Exception as e:  # noqa: BLE001  requests / Pillow が無い環境
        print(f"wdist: スキップ（{type(e).__name__}: {e}）", file=sys.stderr)
        return 0
    base = None
    try:
        parsed = parse_target_times(fx.json(JMA_BASE + "targetTimes.json"))
        base = parsed[0] if parsed else None
    except Exception as e:  # noqa: BLE001
        print(f"wdist: targetTimes 取得失敗 {type(e).__name__}", file=sys.stderr)
    if base:
        try:
            if reuse_published(out_dir, fx, base):
                return len(list(out_dir.glob("*.json")))
        except Exception as e:  # noqa: BLE001
            print(f"wdist: 公開中の再利用なし（{type(e).__name__}）。生成する", file=sys.stderr)
        try:
            if generate(out_dir, fx):
                return len(list(out_dir.glob("*.json")))
        except Exception as e:  # noqa: BLE001
            print(f"wdist: 生成失敗 {type(e).__name__}: {e}", file=sys.stderr)
    else:
        # 気象庁が取れないときは公開中のものを（basetime 不問で）置く
        try:
            idx = json.loads(fx.get(PUBLISHED_BASE + "index.json").decode("utf-8"))
            if reuse_published(out_dir, fx, idx.get("basetime")):
                return len(list(out_dir.glob("*.json")))
        except Exception as e:  # noqa: BLE001
            print(f"wdist: 公開中も取れず {type(e).__name__}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    n = sync_site()
    print(f"wdist: {n}ファイル")
