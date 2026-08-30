"""重ねるハザードマップ（国土地理院）タイルの月次チェック。

アプリ（app/lib/data/hazard_layers.dart）が参照するタイルIDについて
 (a) 既知の地点のタイルが、前回200だったのに404/エラーになっていないか
 (b) オープンデータ一覧ページに載るタイルIDの一覧が前回から増減していないか
を調べ、変化があればレポート(Markdown)を出力する。GitHub Issue化はワークフロー側で行う。

使い方: python tools/hazard_check.py [--seen data/hazard_layers_seen.json] [--report out.md]
  終了コード 0=変化なし / 3=変化あり（レポート出力）。ネットワーク全滅などは 1。
アクセスは 1req/s 以下（SPEC C4 に準拠）。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
import time
from pathlib import Path

import requests

OPENDATA_URL = "https://disaportal.gsi.go.jp/hazardmap/copyright/opendata.html"
TILE_BASE = "https://disaportaldata.gsi.go.jp/raster"
SEEN_PATH = Path("data/hazard_layers_seen.json")
UA = {"User-Agent": "LiveCamJP-hazard-check/1.0 (+https://kotopapa.github.io/livecam-jp/)"}
INTERVAL_SEC = 1.0

# アプリが参照するタイルID（hazard_layers.dart と同期させること）
APP_TILE_IDS = [
    "01_flood_l2_shinsuishin_data",
    "05_kyukeishakeikaikuiki",
    "05_dosekiryukeikaikuiki",
    "05_jisuberikeikaikuiki",
    "04_tsunami_newlegend_data",
    "03_hightide_l2_shinsuishin_data",
]

# 検査地点（lat, lng）。データの有無は地点×IDで異なるため、200→非200の遷移だけを異常とみなす
POINTS = {
    "tokyo": (35.68, 139.76),
    "osaka": (34.69, 135.50),
    "hiroshima": (34.40, 132.46),
    "sendai": (38.27, 140.87),
    "nagoya": (35.17, 136.90),
}
ZOOMS = (10, 12)

_ID_RE = re.compile(r"disaportaldata\.gsi\.go\.jp/raster/([A-Za-z0-9_]+)")


def tile_xy(lat: float, lng: float, z: int) -> tuple[int, int]:
    """緯度経度 → XYZタイル座標（Web Mercator）"""
    import math

    n = 2 ** z
    x = int((lng + 180.0) / 360.0 * n)
    lat_r = math.radians(lat)
    y = int((1.0 - math.log(math.tan(lat_r) + 1.0 / math.cos(lat_r)) / math.pi) / 2.0 * n)
    return x, y


def tile_url(tile_id: str, z: int, x: int, y: int) -> str:
    return f"{TILE_BASE}/{tile_id}/{z}/{x}/{y}.png"


def probe_keys() -> list[tuple[str, str]]:
    """(タイルID, 'z/x/y') の検査対象一覧"""
    keys = []
    for tile_id in APP_TILE_IDS:
        for z in ZOOMS:
            for lat, lng in POINTS.values():
                x, y = tile_xy(lat, lng, z)
                keys.append((tile_id, f"{z}/{x}/{y}"))
    return keys


def extract_tile_ids(html: str) -> list[str]:
    """オープンデータ一覧HTMLから raster/<ID> のIDをソート済み・重複なしで返す"""
    return sorted(set(_ID_RE.findall(html)))


def diff_ids(prev: list[str], curr: list[str]) -> tuple[list[str], list[str]]:
    """(追加されたID, 消えたID)"""
    p, c = set(prev), set(curr)
    return sorted(c - p), sorted(p - c)


def broken_tiles(prev: dict[str, dict[str, int]], curr: dict[str, dict[str, int]]) -> list[tuple[str, str, int, int]]:
    """前回200だったタイルが今回200でないもの: (id, z/x/y, 前回, 今回)"""
    out = []
    for tile_id, tiles in prev.items():
        for key, code in tiles.items():
            if code != 200:
                continue
            now = curr.get(tile_id, {}).get(key)
            if now is None:
                continue  # 今回未検査（地点・ズーム変更）は対象外
            if now != 200:
                out.append((tile_id, key, code, now))
    return out


def build_report(added: list[str], removed: list[str], broken: list[tuple[str, str, int, int]],
                 checked_at: str) -> str:
    lines = [f"重ねるハザードマップの月次チェック（{checked_at}）で変化を検出しました。", ""]
    if broken:
        lines.append("## 前回200だったタイルが取得できません")
        lines.append("")
        lines.append("| タイルID | z/x/y | 前回 | 今回 |")
        lines.append("|---|---|---|---|")
        for tile_id, key, before, now in broken:
            lines.append(f"| `{tile_id}` | {key} | {before} | {now} |")
        lines.append("")
        lines.append("アプリ側 `app/lib/data/hazard_layers.dart` のタイルIDが廃止・改名されていないか確認してください。")
        lines.append("")
    if added or removed:
        lines.append("## オープンデータ一覧ページのタイルID増減")
        lines.append("")
        for i in added:
            lines.append(f"- 追加: `{i}`")
        for i in removed:
            lines.append(f"- 削除: `{i}`")
        lines.append("")
    lines.append(f"一覧ページ: {OPENDATA_URL}")
    return "\n".join(lines) + "\n"


# --- ネットワーク ---

def _get(url: str, timeout: int = 30) -> requests.Response:
    time.sleep(INTERVAL_SEC)
    return requests.get(url, headers=UA, timeout=timeout)


def fetch_opendata_ids() -> list[str]:
    r = _get(OPENDATA_URL)
    r.raise_for_status()
    ids = extract_tile_ids(r.text)
    if not ids:
        raise RuntimeError("一覧ページからタイルIDを抽出できませんでした（ページ構造の変化？）")
    return ids


def probe_tiles() -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    for tile_id, key in probe_keys():
        z, x, y = key.split("/")
        try:
            code = _get(tile_url(tile_id, int(z), int(x), int(y)), timeout=20).status_code
        except requests.RequestException:
            code = 0
        result.setdefault(tile_id, {})[key] = code
    return result


def load_seen(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seen", type=Path, default=SEEN_PATH)
    ap.add_argument("--report", type=Path, default=None, help="変化があったときにMarkdownを書き出す先")
    args = ap.parse_args(argv)

    prev = load_seen(args.seen)
    checked_at = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    try:
        ids = fetch_opendata_ids()
    except Exception as e:  # noqa: BLE001
        print(f"一覧ページ取得失敗: {e}", file=sys.stderr)
        return 1
    tiles = probe_tiles()
    if all(code == 0 for t in tiles.values() for code in t.values()):
        print("タイルサーバーに全く到達できません（ネットワーク障害の可能性）。今回は判定しません", file=sys.stderr)
        return 1

    added, removed = diff_ids(prev.get("ids", []), ids)
    broken = broken_tiles(prev.get("tiles", {}), tiles)
    first_run = not prev
    if first_run:
        added, removed = [], []

    seen = {"checked_at": checked_at, "opendata_url": OPENDATA_URL, "ids": ids, "tiles": tiles}
    args.seen.parent.mkdir(parents=True, exist_ok=True)
    args.seen.write_text(json.dumps(seen, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    ok_count = sum(1 for t in tiles.values() for c in t.values() if c == 200)
    print(f"ids={len(ids)} tiles_ok={ok_count}/{sum(len(t) for t in tiles.values())} "
          f"added={len(added)} removed={len(removed)} broken={len(broken)}{' (初回)' if first_run else ''}")

    if not (added or removed or broken):
        return 0
    report = build_report(added, removed, broken, checked_at)
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return 3


if __name__ == "__main__":
    sys.exit(main())
