"""候補レビューCLI（SPEC 6.8）。

    python tools/review_cli.py            # pending を1件ずつレビュー
    python tools/review_cli.py --id X     # 特定IDのみ

操作: a 承認 / r 却下 / e 編集 / s スキップ / o 画像・地図を開く / q 終了
承認したものだけ cameras.json へ移す。却下は candidates.json に rejected として残す
（再クロール時に候補へ再登場させないため、却下済みも cameras.json に移して記録する）。
"""

from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from datetime import date, datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from crawler.validate import validate_camera_record  # noqa: E402

CANDIDATES_PATH = REPO_ROOT / "data" / "candidates.json"
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"


def load(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"version": None, "cameras": []}


def save(path: Path, data: dict) -> None:
    data["version"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data["cameras"] = sorted(data["cameras"], key=lambda r: r["id"])
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def show(rec: dict) -> None:
    v = rec.get("verification") or {}
    print("=" * 60)
    print(f"ID        : {rec['id']}")
    print(f"名前      : {rec['name']}")
    print(f"運営者    : {rec['operator']}")
    print(f"カテゴリ  : {rec['category']}  県: {rec['prefecture']}  河川/路線: {rec.get('river_or_route')}")
    print(f"座標      : {rec.get('lat')}, {rec.get('lng')}  ({rec.get('coord_accuracy')})")
    print(f"feed      : [{rec['feed']['type']}] {rec['feed']['url']}")
    print(f"出典page  : {rec['source']['page_url']}")
    print(f"規約      : [{rec['source']['license']}] {rec['source'].get('terms_url')}")
    print(f"帰属表示  : {rec['source']['attribution']}")
    if v:
        print(f"検証      : 画像変化={v.get('image_changed')} type={v.get('content_type')} {v.get('bytes')}B")
    if rec["review"].get("note"):
        print(f"note      : {rec['review']['note']}")


def open_resources(rec: dict) -> None:
    if rec.get("lat") is not None:
        webbrowser.open(f"https://maps.google.com/?q={rec['lat']},{rec['lng']}")
    f = rec["feed"]
    if f["type"] == "still_image":
        webbrowser.open(f["url"])
    elif f["type"] == "youtube_channel":
        webbrowser.open(f"https://www.youtube.com/embed/live_stream?channel={f['url']}")
    else:
        webbrowser.open(f["url"])


def edit(rec: dict) -> None:
    print("編集: 空Enterで現状維持")
    for path, label in [(("name",), "名前"), (("lat",), "lat"), (("lng",), "lng"),
                        (("coord_accuracy",), "coord_accuracy"),
                        (("category",), "category"), (("prefecture",), "prefecture"),
                        (("river_or_route",), "river_or_route"),
                        (("source", "license"), "license")]:
        cur = rec
        for k in path[:-1]:
            cur = cur[k]
        old = cur[path[-1]]
        val = input(f"  {label} [{old}]: ").strip()
        if not val:
            continue
        if path[-1] in ("lat", "lng"):
            try:
                cur[path[-1]] = float(val)
            except ValueError:
                print("  数値でない。無視")
        else:
            cur[path[-1]] = val


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", help="特定IDのみレビュー")
    args = ap.parse_args()

    candidates = load(CANDIDATES_PATH)
    cameras = load(CAMERAS_PATH)
    pending = [r for r in candidates["cameras"] if r["review"]["status"] == "pending"]
    if args.id:
        pending = [r for r in pending if r["id"] == args.id]
    if not pending:
        print("pending の候補なし")
        return 0

    print(f"{len(pending)}件の候補をレビューします。a=承認 r=却下 e=編集 s=スキップ o=開く q=終了")
    today = date.today().isoformat()
    decided: list[str] = []
    try:
        for rec in pending:
            show(rec)
            while True:
                cmd = input("[a/r/e/s/o/q] > ").strip().lower()
                if cmd == "o":
                    open_resources(rec)
                    continue
                if cmd == "e":
                    edit(rec)
                    show(rec)
                    continue
                break
            if cmd == "q":
                break
            if cmd == "s" or cmd == "":
                continue
            if cmd == "a":
                rec["review"] = {"status": "approved", "reviewed_at": today,
                                 "note": rec["review"].get("note", "")}
            elif cmd == "r":
                reason = input("却下理由: ").strip()
                rec["review"] = {"status": "rejected", "reviewed_at": today, "note": reason}
            else:
                continue
            out = {k: v for k, v in rec.items() if k != "verification"}
            errs = validate_camera_record(out)
            if errs and rec["review"]["status"] == "approved":
                print("!! スキーマNGのため承認できない:")
                for e in errs:
                    print(f"   {e}")
                rec["review"]["status"] = "pending"
                continue
            cameras["cameras"].append(out)
            decided.append(rec["id"])
    finally:
        if decided:
            candidates["cameras"] = [r for r in candidates["cameras"] if r["id"] not in decided]
            save(CANDIDATES_PATH, candidates)
            save(CAMERAS_PATH, cameras)
            print(f"{len(decided)}件を確定し cameras.json へ移した")
    return 0


if __name__ == "__main__":
    sys.exit(main())
