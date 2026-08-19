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
INTERNAL_FIELDS = {"verification"}


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
        "notice": None,
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")

    # 全国ランキング（日次集計の成果物があれば上位のみ軽量化して配信）
    ranking_src = DATA / "global_ranking.json"
    if ranking_src.exists():
        state = json.loads(ranking_src.read_text(encoding="utf-8"))
        cams = state.get("cameras", {})
        entries = []
        for cid, rec in cams.items():
            if cid not in ids:
                continue  # 削除済みカメラはランキングから外す
            recent = sum(rec.get("days", {}).values())
            entries.append({"id": cid, "recent": recent,
                            "total": rec.get("total", 0)})
        top_recent = sorted(entries, key=lambda e: -e["recent"])[:300]
        top_total = sorted(entries, key=lambda e: -e["total"])[:300]
        (OUT / "ranking.json").write_text(json.dumps({
            "updated": state.get("updated"),
            "recent_days": 7,
            "recent": [e for e in top_recent if e["recent"] > 0],
            "total": [e for e in top_total if e["total"] > 0],
        }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"ranking.json 生成: {len(entries)}台")

    print(f"site/v1 生成: 承認済み {len(approved)}件, 都道府県 {len(by_pref)}")
    return 0


if __name__ == "__main__":
    sys.exit(build())
