"""静的配信ファイルの生成（SPEC 8.1）。

    python site/build.py            # data/ → site/v1/ を生成

生成物:
    site/v1/manifest.json
    site/v1/cameras.json            # 承認済み全件
    site/v1/cameras/<prefCode>.json # 都道府県別
    site/v1/status.json

アプリに配るのは approved のみ。verification 等の内部フィールドは落とす。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA = REPO_ROOT / "data"
OUT = REPO_ROOT / "site" / "v1"

MIN_APP_VERSION = "1.0.0"
# App Store 公開後にURLを設定する（強制アップデートダイアログの誘導先）
STORE_URL = "https://apps.apple.com/jp/app/id6802841521"
INTERNAL_FIELDS = {"verification"}


def _notice() -> str | None:
    p = DATA / "notice.txt"
    if not p.exists():
        return None
    t = p.read_text(encoding="utf-8").rstrip()  # 先頭の空行は旧版の重なり回避に使うので残す
    return t or None


def _recommended_apps() -> list[dict]:
    p = DATA / "recommended_apps.json"
    if not p.exists():
        return []
    try:
        return json.loads(p.read_text(encoding="utf-8")).get("apps", [])
    except (ValueError, AttributeError):
        return []


def build() -> int:
    cameras_src = json.loads((DATA / "cameras.json").read_text(encoding="utf-8"))
    approved = [
        {k: v for k, v in rec.items() if k not in INTERNAL_FIELDS}
        for rec in cameras_src.get("cameras", [])
        if rec.get("review", {}).get("status") == "approved"
    ]
    version = cameras_src.get("version")

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "cameras").mkdir(exist_ok=True)

    cameras_out = {"version": version, "cameras": approved}
    (OUT / "cameras.json").write_text(
        json.dumps(cameras_out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    by_pref: dict[str, list] = {}
    for rec in approved:
        by_pref.setdefault(rec["prefecture"], []).append(rec)
    for pref, recs in sorted(by_pref.items()):
        (OUT / "cameras" / f"{pref}.json").write_text(
            json.dumps({"version": version, "cameras": recs},
                       ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    status_path = DATA / "status.json"
    if status_path.exists():
        status = json.loads(status_path.read_text(encoding="utf-8"))
    else:
        status = {"generated_at": version, "statuses": {}}
    # 承認済み以外のstatusは配信しない
    ids = {r["id"] for r in approved}
    status["statuses"] = {k: v for k, v in status["statuses"].items() if k in ids}
    (OUT / "status.json").write_text(
        json.dumps(status, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "cameras": {"version": version, "url": "/v1/cameras.json", "count": len(approved)},
        "status": {"version": status.get("generated_at"), "url": "/v1/status.json"},
        "prefectures": sorted(by_pref),
        "min_app_version": MIN_APP_VERSION,
        "store_url": STORE_URL,
        # data/notice.txt があればアプリ内お知らせバナーとして配信（空なら非表示）。
        # bot の再ビルドでも消えないようファイルで持つ
        "notice": _notice(),
        # 設定画面「開発者の他のアプリ」（data/recommended_apps.json。無ければ空）
        "apps": _recommended_apps(),
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")

    # 全国ランキング（日次集計の成果物があれば上位のみ軽量化して配信）
    ranking_src = DATA / "global_ranking.json"
    if ranking_src.exists():
        state = json.loads(ranking_src.read_text(encoding="utf-8"))
        cams = state.get("cameras", {})
        # 当日分の暫定値を上乗せ（確定処理は翌日の集計で行われる）
        partial = state.get("today_partial", {}).get("counts", {})
        # 直近24時間の近似: 当日分(暫定) + 前日分×(24-経過時間)/24。
        # 集計は3時間おきに回るので当日分がほぼ最新になる
        from datetime import datetime, timedelta, timezone
        jst = timezone(timedelta(hours=9))
        now = datetime.now(jst)
        yesterday = (now - timedelta(days=1)).strftime("%Y%m%d")
        frac = max(0.0, (24 - now.hour - now.minute / 60) / 24)
        entries = []
        for cid in set(cams) | set(partial):
            if cid not in ids:
                continue  # 削除済みカメラはランキングから外す
            rec = cams.get(cid, {})
            extra = partial.get(cid, 0)
            days = rec.get("days", {})
            recent = sum(days.values()) + extra
            day = int(round(extra + days.get(yesterday, 0) * frac))
            entries.append({"id": cid, "recent": recent, "day": day,
                            "total": rec.get("total", 0) + extra})
        top_day = sorted(entries, key=lambda e: -e["day"])[:10]
        top_recent = sorted(entries, key=lambda e: -e["recent"])[:30]
        # 旧バージョンのアプリ向け(累計タブ)に total も残す
        top_total = sorted(entries, key=lambda e: -e["total"])[:30]
        favs = [{"id": cid, "count": n}
                for cid, n in state.get("favorites", {}).items()
                if cid in ids and n > 0]
        favs.sort(key=lambda e: -e["count"])
        (OUT / "ranking.json").write_text(json.dumps({
            "updated": state.get("updated"),
            "recent_days": 7,
            "day": [e for e in top_day if e["day"] > 0],
            "recent": [e for e in top_recent if e["recent"] > 0],
            "total": [e for e in top_total if e["total"] > 0],
            "favorites": favs[:30],
        }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"ranking.json 生成: {len(entries)}台")

    print(f"site/v1 生成: 承認済み {len(approved)}件, 都道府県 {len(by_pref)}")
    return 0


if __name__ == "__main__":
    sys.exit(build())
