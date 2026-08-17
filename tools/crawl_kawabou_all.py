"""川の防災情報の全国スイープ（長時間バッチ・中断再開可能）。

    python tools/crawl_kawabou_all.py            # 全県（数時間かかる）
    python tools/crawl_kawabou_all.py --prefs 1301,1401
    python tools/crawl_kawabou_all.py --skip-verify

Phase A: 県ごとにカメラを列挙・解決し、県が終わるたびに candidates.json へマージ保存
Phase B: 新規still_imageを2回取得検証（1周目→2周目の間が各カメラ5分以上になるよう
         全件を順に2周する。周回自体が長いので追加の待機はほぼ不要）

進捗は crawler/.cache/kawabou_sweep.json に保存され、再実行すると続きから走る。
レート制限は HttpSession が担保（同一ホスト1秒以上、robots.txt遵守、ETag）。
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import date, datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

try:
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

from crawler.main import CANDIDATES_PATH, CAMERAS_PATH, load_json, merge_candidates  # noqa: E402
from crawler.sources import kawabou  # noqa: E402
from crawler.sources.base import HttpSession, RateLimitedError  # noqa: E402
from crawler.validate import validate_camera_record  # noqa: E402
from monitor.freeze import dhash64, is_placeholder  # noqa: E402

STATE_PATH = REPO_ROOT / "crawler" / ".cache" / "kawabou_sweep.json"
VERIFY_MIN_GAP_SEC = 300
SAVE_EVERY = 200


def log(msg: str) -> None:
    print(f"{datetime.now(timezone.utc).strftime('%H:%M:%S')} {msg}", flush=True)


def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    return {"done_prefs": [], "verified_ids": []}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state), encoding="utf-8")


def save_candidates(records: list[dict]) -> None:
    out = {
        "version": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cameras": sorted(records, key=lambda r: r["id"]),
    }
    CANDIDATES_PATH.write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")


def phase_a(session: HttpSession, pref_codes: list[int], state: dict) -> None:
    today = date.today().isoformat()
    cameras = load_json(CAMERAS_PATH)
    decided_ids = {r["id"] for r in cameras.get("cameras", [])}

    for pref_cd in pref_codes:
        if pref_cd in state["done_prefs"]:
            continue
        existing = load_json(CANDIDATES_PATH).get("cameras", [])
        known_urls = {r["feed"]["url"] for r in existing} | {
            r["feed"]["url"] for r in cameras.get("cameras", [])}
        known_scam_ids = set()
        for r in existing + cameras.get("cameras", []):
            tail = r["id"].rsplit("-", 1)[-1]
            if tail.isdigit():
                known_scam_ids.add(int(tail))

        entries, errs = kawabou.fetch_pref_camera_ids(session, pref_cd)
        for e in errs:
            log(f"ERROR pref {pref_cd}: {e}")
        new_records: list[dict] = []
        skipped = 0
        seen_in_pref: set[int] = set()
        for entry in entries:
            scam_id = entry.get("scamId")
            if not scam_id or scam_id in seen_in_pref:
                continue
            seen_in_pref.add(scam_id)
            if scam_id in known_scam_ids:
                skipped += 1
                continue
            obs = kawabou.resolve_scam(session, scam_id)
            if obs is None:
                log(f"ERROR scam {scam_id} (pref {pref_cd}): master JSON not found")
                continue
            cand = kawabou.candidate_from_obsinfo(obs, scam_id)
            if cand is None:
                continue
            if cand.feed_url in known_urls:
                skipped += 1
                continue
            rec = cand.to_record(today)
            if validate_camera_record(rec):
                log(f"ERROR scam {scam_id}: schema NG")
                continue
            known_urls.add(cand.feed_url)
            new_records.append(rec)

        merged = merge_candidates(existing, new_records, decided_ids)
        save_candidates(merged)
        state["done_prefs"].append(pref_cd)
        save_state(state)
        log(f"pref {pref_cd}: カメラ{len(entries)}件中 新規{len(new_records)}件 "
            f"既知スキップ{skipped}件 (累計候補 {len(merged)}件)")


def phase_b(session: HttpSession, state: dict) -> None:
    data = load_json(CANDIDATES_PATH)
    records = data.get("cameras", [])
    verified: set[str] = set(state.get("verified_ids", []))
    targets = [r for r in records
               if r["feed"]["type"] == "still_image"
               and r.get("verification") is None
               and r["id"] not in verified]
    if not targets:
        log("SWEEP: 検証対象なし")
        return
    log(f"検証対象 {len(targets)}件を2周取得（各カメラ最低{VERIFY_MIN_GAP_SEC}秒間隔）")

    first: dict[str, tuple[int | None, bytes | None, str, float]] = {}
    for i, r in enumerate(targets):
        res = session.fetch(r["feed"]["url"], use_cache=False)
        first[r["id"]] = (res.status, res.content, res.content_type, time.monotonic())
        if (i + 1) % SAVE_EVERY == 0:
            log(f"検証1周目 {i + 1}/{len(targets)}")

    for i, r in enumerate(targets):
        s1, b1, ct1, t1 = first[r["id"]]
        gap = VERIFY_MIN_GAP_SEC - (time.monotonic() - t1)
        if gap > 0:
            time.sleep(gap)
        res2 = session.fetch(r["feed"]["url"], use_cache=False)
        s2, b2 = res2.status, res2.content
        ct = ct1 or res2.content_type
        size = len(b2 or b1 or b"")
        changed = None
        if b1 is not None and b2 is not None:
            changed = b1 != b2
        r["verification"] = {
            "fetched_twice": True,
            "image_changed": changed,
            "content_type": ct or None,
            "bytes": size or None,
        }
        problems = []
        if not (s1 == 200 and s2 == 200):
            problems.append(f"HTTP {s1}/{s2}")
        if not (ct or "").lower().startswith("image/"):
            problems.append(f"Content-Type={ct or '不明'}")
        if size < 5 * 1024:
            problems.append(f"サイズ{size}B(<5KB)")
        if changed is False:
            problems.append("2回取得で画像が同一(更新間隔が長い可能性)")
        if is_placeholder(dhash64(b2 or b1 or b"")):
            problems.append("「画像がありません」プレースホルダ(配信休止中の可能性)")
        if problems:
            note = "検証NG: " + "、".join(problems)
            r["review"]["note"] = (r["review"]["note"] + " / " + note).strip(" /")
        verified.add(r["id"])
        if (i + 1) % SAVE_EVERY == 0:
            save_candidates(records)
            state["verified_ids"] = sorted(verified)
            save_state(state)
            log(f"検証2周目 {i + 1}/{len(targets)}")

    save_candidates(records)
    state["verified_ids"] = sorted(verified)
    save_state(state)
    ok = sum(1 for r in targets if (r.get("verification") or {}).get("image_changed"))
    log(f"SWEEP: 検証完了 {len(targets)}件（画像変化確認 {ok}件）")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prefs", help="カンマ区切りのprefCd。省略時は全県")
    ap.add_argument("--skip-verify", action="store_true")
    args = ap.parse_args()

    session = HttpSession()
    state = load_state()
    try:
        if args.prefs:
            codes = [int(x) for x in args.prefs.split(",")]
        else:
            codes = kawabou.fetch_pref_codes(session)
        log(f"SWEEP: 開始 対象{len(codes)}県 (完了済み {len(state['done_prefs'])}県)")
        phase_a(session, codes, state)
        log("SWEEP: Phase A 完了（全県の列挙・解決が終了）")
        if not args.skip_verify:
            phase_b(session, state)
        log("SWEEP: 全工程完了")
        return 0
    except RateLimitedError as e:
        log(f"FATAL: レート制限検知 {e} — スイープを停止。設定を見直して人に報告のこと")
        return 2
    except Exception as e:  # 長時間バッチなのでスタックトレースを必ず残す
        import traceback
        log(f"FATAL: {e}")
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
