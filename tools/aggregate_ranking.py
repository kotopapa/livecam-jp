"""全国ランキングの日次集計（GitHub Actionsから実行）。

Firestoreの views/{前日JST}/cams/* を読み取り、data/global_ranking.json の
累計・直近7日へ反映し、処理済みドキュメントを削除する（ストレージ節約）。

- 認証: 環境変数 FIREBASE_SERVICE_ACCOUNT にサービスアカウントJSONを渡す
- Firestoreの読み取りはこのスクリプトの1日1回のみ（クライアントは読まない）
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone

import google.auth.transport.requests
from google.oauth2 import service_account

JST = timezone(timedelta(hours=9))
RANKING_PATH = "data/global_ranking.json"
KEEP_DAYS = 7
MAX_ENTRIES = 300  # 配信するランキング上位件数


def firestore_session(sa_info: dict):
    creds = service_account.Credentials.from_service_account_info(
        sa_info, scopes=["https://www.googleapis.com/auth/datastore"])
    creds.refresh(google.auth.transport.requests.Request())
    import requests
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s, sa_info["project_id"]


def list_day_counts(s, project: str, day: str) -> dict[str, int]:
    base = (f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents/views/{day}/cams")
    counts: dict[str, int] = {}
    token = None
    while True:
        params = {"pageSize": 300}
        if token:
            params["pageToken"] = token
        r = s.get(base, params=params, timeout=30)
        if r.status_code == 404:
            break
        r.raise_for_status()
        body = r.json()
        for doc in body.get("documents", []):
            cam_id = doc["name"].rsplit("/", 1)[1]
            n = int(doc.get("fields", {}).get("n", {}).get("integerValue", 0))
            if n > 0:
                counts[cam_id] = n
        token = body.get("nextPageToken")
        if not token:
            break
    return counts


def delete_docs(s, project: str, day: str, cam_ids: list[str]) -> None:
    base = (f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents")
    for i in range(0, len(cam_ids), 400):
        writes = [{"delete": f"{base}/views/{day}/cams/{cid}"}
                  for cid in cam_ids[i:i + 400]]
        r = s.post(f"{base}:commit", json={"writes": writes}, timeout=30)
        r.raise_for_status()


def main() -> int:
    sa_raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "")
    if not sa_raw:
        print("FIREBASE_SERVICE_ACCOUNT 未設定のためスキップ")
        return 0
    s, project = firestore_session(json.loads(sa_raw))

    yesterday = (datetime.now(JST) - timedelta(days=1)).strftime("%Y%m%d")
    counts = list_day_counts(s, project, yesterday)
    print(f"{yesterday}: {len(counts)}台 / {sum(counts.values())}回")

    # 既存状態へマージ
    try:
        state = json.load(open(RANKING_PATH, encoding="utf-8"))
    except FileNotFoundError:
        state = {"cameras": {}}
    cams = state["cameras"]
    for cid, n in counts.items():
        rec = cams.setdefault(cid, {"total": 0, "days": {}})
        rec["total"] += n
        rec["days"][yesterday] = rec["days"].get(yesterday, 0) + n
    # 直近KEEP_DAYS日より古い日次を落とす
    cutoff = (datetime.now(JST) - timedelta(days=KEEP_DAYS)).strftime("%Y%m%d")
    for rec in cams.values():
        rec["days"] = {d: c for d, c in rec["days"].items() if d >= cutoff}
    state["updated"] = datetime.now(JST).strftime("%Y-%m-%dT%H:%M:%S+09:00")

    json.dump(state, open(RANKING_PATH, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

    # 配信用（上位のみ・軽量化）: site/build.py が site/v1/ranking.json へ変換
    if counts:
        delete_docs(s, project, yesterday, list(counts.keys()))
        print("処理済みドキュメントを削除")
    return 0


if __name__ == "__main__":
    sys.exit(main())
