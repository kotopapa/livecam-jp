"""クローラのエントリポイント。

    python -m crawler.main --all                 # 全有効ソース
    python -m crawler.main --source mlit_ktr_river
    python -m crawler.main --all --dry-run       # 書き込まない
    python -m crawler.main --all --no-verify     # 2回取得検証を省略（開発用）
    python -m crawler.main --all --limit 30      # ソースごとに候補数を制限（開発用）

出力: data/candidates.json（review.status=pending のまま追記マージ）。
cameras.json へは絶対に自動投入しない（SPEC 6.1）。
"""

from __future__ import annotations

import argparse
import json
import sys

# 官公庁サイトは中間証明書が不完全なことがあり、certifi では検証に失敗する。
# OSの証明書ストアを使う（Windows/macOS/Linux対応）。
try:
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass
from datetime import date, datetime, timezone
from pathlib import Path

import yaml

from crawler import normalize, verify
from crawler.geocode import Geocoder, fill_coordinates
from crawler.sources import REGISTRY
from crawler.sources.base import HttpSession, RateLimitedError
from crawler.sources.kawabou import KawabouPrefParser
from crawler.validate import validate_camera_record

REPO_ROOT = Path(__file__).resolve().parent.parent
SEEDS_PATH = Path(__file__).resolve().parent / "seeds.yaml"
CANDIDATES_PATH = REPO_ROOT / "data" / "candidates.json"
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"


def load_enabled_sources() -> list:
    cfg = yaml.safe_load(SEEDS_PATH.read_text(encoding="utf-8"))
    parsers = []
    for src in cfg.get("sources", []):
        if not src.get("enabled"):
            continue
        sid = src["id"]
        if sid == "kawabou_pref":
            parsers.append(KawabouPrefParser(pref_codes=src.get("pref_codes") or []))
        elif sid in REGISTRY:
            parsers.append(REGISTRY[sid]())
        else:
            print(f"warning: seeds.yaml の {sid} に対応するパーサがない", file=sys.stderr)
    return parsers


def load_json(path: Path) -> dict:
    if path.exists():
        # utf-8-sig: 手編集などでBOMが混入しても読めるように
        return json.loads(path.read_text(encoding="utf-8-sig"))
    return {"version": None, "cameras": []}


def merge_candidates(existing: list[dict], new: list[dict], approved_ids: set[str]) -> list[dict]:
    """既存候補のレビュー情報を保持しつつ新結果をマージする。"""
    by_id = {r["id"]: r for r in existing}
    for rec in new:
        rid = rec["id"]
        if rid in approved_ids:
            continue                      # 承認済み・却下済みは候補に再登場させない
        if rid in by_id:
            old = by_id[rid]
            rec["first_seen"] = old.get("first_seen", rec["first_seen"])
            rec["review"] = old.get("review", rec["review"])   # 人手のメモを消さない
            by_id[rid] = rec
        else:
            by_id[rid] = rec
    return list(by_id.values())


def main() -> int:
    ap = argparse.ArgumentParser(description="livecam-jp crawler")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--all", action="store_true", help="seeds.yaml の全有効ソースを実行")
    g.add_argument("--source", help="特定ソースのみ実行（REGISTRY のID）")
    ap.add_argument("--dry-run", action="store_true", help="candidates.json に書き込まない")
    ap.add_argument("--no-verify", action="store_true", help="静止画の2回取得検証を省略")
    ap.add_argument("--verify-wait", type=int, default=verify.DEFAULT_WAIT_SEC,
                    help="検証の取得間隔秒（既定300）")
    ap.add_argument("--no-geocode", action="store_true", help="ジオコーディングを省略")
    ap.add_argument("--limit", type=int, default=0, help="ソースごとの候補数上限（開発用）")
    args = ap.parse_args()

    if args.all:
        parsers = load_enabled_sources()
    else:
        if args.source not in REGISTRY:
            print(f"unknown source: {args.source}（{', '.join(REGISTRY)}）", file=sys.stderr)
            return 2
        parsers = [REGISTRY[args.source]()]

    session = HttpSession()
    today = date.today().isoformat()
    all_candidates = []
    all_errors: list[str] = []

    for parser in parsers:
        print(f"=== {parser.source_id}")
        try:
            result = parser.discover(session)
        except RateLimitedError as e:
            # SPEC 10章: 即座に停止して人に報告
            print(f"!!! レート制限検知: {e}", file=sys.stderr)
            print("!!! このソースのクロールを停止しました。レート設定を見直してください。", file=sys.stderr)
            all_errors.append(str(e))
            continue
        if args.limit:
            result.candidates = result.candidates[:args.limit]
        print(f"    候補 {len(result.candidates)}件, エラー {len(result.errors)}件")
        for e in result.errors[:10]:
            print(f"    - {e}", file=sys.stderr)
        all_candidates.extend(result.candidates)
        all_errors.extend(result.errors)

    if not args.no_geocode:
        fill_coordinates(all_candidates, Geocoder())
    all_candidates = normalize.dedupe(all_candidates)
    if not args.no_verify:
        verify.verify_still_images(session, all_candidates, wait_sec=args.verify_wait)

    records = [c.to_record(today) for c in all_candidates]
    bad = 0
    for rec in records:
        errs = validate_camera_record(rec)
        if errs:
            bad += 1
            for e in errs[:3]:
                print(f"schema NG {rec['id']}: {e}", file=sys.stderr)
    records = [r for r in records if not validate_camera_record(r)]

    exact = sum(1 for r in records if r["coord_accuracy"] == "exact")
    located = sum(1 for r in records if r["lat"] is not None)
    print(f"合計: {len(records)}件（座標あり {located}件, うちexact {exact}件, スキーマNG除外 {bad}件）")

    if args.dry_run:
        print("dry-run: 書き込みなし")
        return 0

    cameras = load_json(CAMERAS_PATH)
    decided_ids = {r["id"] for r in cameras.get("cameras", [])}
    existing = load_json(CANDIDATES_PATH)
    merged = merge_candidates(existing.get("cameras", []), records, decided_ids)
    out = {
        "version": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cameras": sorted(merged, key=lambda r: r["id"]),
    }
    CANDIDATES_PATH.parent.mkdir(parents=True, exist_ok=True)
    CANDIDATES_PATH.write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"candidates.json 更新: {len(merged)}件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
