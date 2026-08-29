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


def list_collection_counts(s, project: str, path: str,
                           include_zero: bool = False) -> dict[str, int]:
    base = (f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents/{path}")
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
            if n != 0 or include_zero:
                counts[cam_id] = n
        token = body.get("nextPageToken")
        if not token:
            break
    return counts


def delete_docs(s, project: str, day: str, cam_ids: list[str]) -> None:
    """処理済みドキュメントを個別DELETEで削除する。
    失敗しても集計は成立している（翌日以降に再削除される）ため致命扱いしない。"""
    base = (f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents")
    failed = 0
    for cid in cam_ids:
        try:
            r = s.delete(f"{base}/views/{day}/cams/{cid}", timeout=30)
            if r.status_code >= 400:
                failed += 1
                print(f"delete NG {cid}: {r.status_code} {r.text[:120]}")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"delete NG {cid}: {e}")
    if failed:
        print(f"削除失敗 {failed}/{len(cam_ids)}件（翌日再試行）")


def main() -> int:
    sa_raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "")
    if not sa_raw:
        print("FIREBASE_SERVICE_ACCOUNT 未設定のためスキップ")
        return 0
    s, project = firestore_session(json.loads(sa_raw))

    yesterday = (datetime.now(JST) - timedelta(days=1)).strftime("%Y%m%d")
    counts_all = list_collection_counts(s, project, f"views/{yesterday}/cams",
                                        include_zero=True)
    counts = {k: v for k, v in counts_all.items() if v > 0}
    print(f"{yesterday}: {len(counts)}台 / {sum(counts.values())}回")

    # お気に入り累積（読むだけ・削除しない。±が相殺され現在の登録数になる）
    # お気に入り集計(favs/all/cams は登録済みカメラ数ぶんの読取)は1日1回だけ。
    # 3時間おきの実行では前回値を引き継ぐ
    today_str = datetime.now(JST).strftime("%Y%m%d")
    try:
        prev_state = json.load(open(RANKING_PATH, encoding="utf-8"))
    except FileNotFoundError:
        prev_state = {}
    if prev_state.get("favorites_date") == today_str:
        favs = prev_state.get("favorites", {})
        print("favorites: 本日分は集計済み(前回値を使用)")
    else:
        favs = list_collection_counts(s, project, "favs/all/cams")
    favs = {k: v for k, v in favs.items() if v > 0}
    print(f"favorites: {len(favs)}台 / {sum(favs.values())}件")

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
    # 当日分の暫定値（削除しない・stateの確定分には足さない）。
    # 翌日の実行で同じ日付が確定処理されるため二重計上にならない
    today = datetime.now(JST).strftime("%Y%m%d")
    today_counts = list_collection_counts(s, project, f"views/{today}/cams")
    state["today_partial"] = {"date": today, "counts": today_counts}
    print(f"today({today}) partial: {len(today_counts)}台")

    state["favorites"] = favs
    state["favorites_date"] = today_str
    state["updated"] = datetime.now(JST).strftime("%Y-%m-%dT%H:%M:%S+09:00")

    json.dump(state, open(RANKING_PATH, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

    # 配信用（上位のみ・軽量化）: site/build.py が site/v1/ranking.json へ変換
    if counts_all:
        delete_docs(s, project, yesterday, list(counts_all.keys()))
        print("処理済みドキュメントを削除")
    return 0


if __name__ == "__main__":
    sys.exit(main())
