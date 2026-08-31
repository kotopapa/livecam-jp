"""候補レビューCLI（SPEC 6.8）。

    python tools/review_cli.py            # pending を1件ずつレビュー
    python tools/review_cli.py --id X     # 特定IDのみ

一括承認（人が明示的に範囲を指定する。フィルタ指定なしでは動かない）:

    python tools/review_cli.py --bulk --license public_data_1.0 --verified --dry-run
    python tools/review_cli.py --bulk --license unknown --pref 14 --operator 神奈川県

    フィルタ: --license / --pref(複数可) / --operator(部分一致) / --category
              / --feed-type / --verified(2回取得検証で画像変化を確認済みのみ)
    --dry-run で対象一覧の確認のみ。実行時は表示された件数をそのまま入力して確定する。

操作: a 承認 / r 却下 / e 編集 / s スキップ / o 画像・地図を開く / q 終了
承認したものだけ cameras.json へ移す。却下は candidates.json に rejected として残す
（再クロール時に候補へ再登場させないため、却下済みも cameras.json に移して記録する）。
"""

from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from crawler.validate import validate_camera_record  # noqa: E402

CANDIDATES_PATH = REPO_ROOT / "data" / "candidates.json"
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"

JST = timezone(timedelta(hours=9))


def jst_today() -> str:
    """JSTの今日（YYYY-MM-DD）。

    台帳の first_seen / last_updated / reviewed_at は日本の日付で記録する。
    GitHub Actions のランナーは UTC で動くため date.today() を使うと
    JST 00:00〜09:00 の実行が前日の日付になってしまう。
    """
    return datetime.now(JST).date().isoformat()


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


def matches_filters(rec: dict, *, license: str | None = None, prefs: list[str] | None = None,
                    operator: str | None = None, category: str | None = None,
                    feed_type: str | None = None, verified: bool = False,
                    with_coords: bool = False) -> bool:
    """一括承認のフィルタ判定。pending 以外は常に対象外。"""
    if rec["review"]["status"] != "pending":
        return False
    if with_coords and rec.get("lat") is None:
        return False
    if license is not None and rec["source"].get("license") != license:
        return False
    if prefs and rec.get("prefecture") not in prefs:
        return False
    if operator is not None and operator not in (rec.get("operator") or ""):
        return False
    if category is not None and rec.get("category") != category:
        return False
    if feed_type is not None and rec["feed"]["type"] != feed_type:
        return False
    if verified and not (rec.get("verification") or {}).get("image_changed"):
        return False
    return True


def apply_bulk_approval(selected: list[dict], cameras: dict, note: str,
                        reviewed_at: str) -> tuple[list[str], list[tuple[str, list[str]]]]:
    """選択済みレコードを承認して cameras に移す。スキーマNGは pending のまま残す。

    戻り値: (承認したID一覧, [(スキーマNGのID, エラー一覧), ...])
    """
    existing_ids = {r["id"] for r in cameras["cameras"]}
    approved: list[str] = []
    skipped: list[tuple[str, list[str]]] = []
    for rec in selected:
        if rec["id"] in existing_ids:
            skipped.append((rec["id"], ["cameras.json に既存"]))
            continue
        original_review = rec["review"]
        rec["review"] = {"status": "approved", "reviewed_at": reviewed_at, "note": note}
        out = {k: v for k, v in rec.items() if k != "verification"}
        errs = validate_camera_record(out)
        if errs:
            rec["review"] = original_review
            skipped.append((rec["id"], errs))
            continue
        cameras["cameras"].append(out)
        approved.append(rec["id"])
    return approved, skipped


def bulk_main(args) -> int:
    filters = dict(license=args.license, prefs=args.pref, operator=args.operator,
                   category=args.category, feed_type=args.feed_type, verified=args.verified,
                   with_coords=args.with_coords)
    if not any([args.license, args.pref, args.operator, args.category,
                args.feed_type, args.verified]):
        print("一括承認にはフィルタの指定が必須（範囲を明示しない承認はしない。SPEC 6.1）")
        return 1

    candidates = load(CANDIDATES_PATH)
    cameras = load(CAMERAS_PATH)
    selected = [r for r in candidates["cameras"] if matches_filters(r, **filters)]
    if not selected:
        print("フィルタに該当する pending 候補なし")
        return 0

    from collections import Counter
    by_pref = Counter(r.get("prefecture") for r in selected)
    by_op = Counter(r.get("operator") for r in selected)
    print(f"対象: {len(selected)}件")
    print(f"  都道府県: {len(by_pref)}県 {dict(by_pref.most_common(5))} ...")
    print("  運営者上位:")
    for op, n in by_op.most_common(5):
        print(f"    {n:6d}  {op}")
    print("  サンプル:")
    for r in selected[:3]:
        print(f"    {r['id']}  {r['name']}  [{r['source'].get('license')}]")

    if args.dry_run:
        print("(dry-run: 変更なし)")
        return 0

    typed = input(f"この範囲を一括承認する。確認のため件数 {len(selected)} を入力 > ").strip()
    if typed != str(len(selected)):
        print("件数不一致のため中止")
        return 1

    note = "bulk: " + " ".join(
        f"{k}={v}" for k, v in filters.items() if v not in (None, [], False))
    approved, skipped = apply_bulk_approval(
        selected, cameras, note, jst_today())
    if approved:
        approved_set = set(approved)
        candidates["cameras"] = [r for r in candidates["cameras"]
                                 if r["id"] not in approved_set]
        save(CANDIDATES_PATH, candidates)
        save(CAMERAS_PATH, cameras)
    print(f"承認 {len(approved)}件 / スキップ {len(skipped)}件")
    for cid, errs in skipped[:10]:
        print(f"  skip {cid}: {errs[0]}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", help="特定IDのみレビュー")
    ap.add_argument("--bulk", action="store_true", help="フィルタ指定による一括承認")
    ap.add_argument("--license", help="source.license の完全一致")
    ap.add_argument("--pref", action="append", help="都道府県コード(JIS)。複数指定可")
    ap.add_argument("--operator", help="運営者名の部分一致")
    ap.add_argument("--category", help="カテゴリの完全一致")
    ap.add_argument("--feed-type", help="feed.type の完全一致")
    ap.add_argument("--verified", action="store_true",
                    help="2回取得検証で画像変化を確認済みのみ")
    ap.add_argument("--with-coords", action="store_true",
                    help="座標が設定済みのもののみ（範囲指定の補助。単独ではフィルタにならない）")
    ap.add_argument("--dry-run", action="store_true", help="対象一覧の表示のみ")
    args = ap.parse_args()

    if args.bulk:
        return bulk_main(args)

    candidates = load(CANDIDATES_PATH)
    cameras = load(CAMERAS_PATH)
    pending = [r for r in candidates["cameras"] if r["review"]["status"] == "pending"]
    if args.id:
        pending = [r for r in pending if r["id"] == args.id]
    if not pending:
        print("pending の候補なし")
        return 0

    print(f"{len(pending)}件の候補をレビューします。a=承認 r=却下 e=編集 s=スキップ o=開く q=終了")
    today = jst_today()
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
