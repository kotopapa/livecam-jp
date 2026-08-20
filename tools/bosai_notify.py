"""重大災害のプッシュ通知送信（GitHub Actionsから10分間隔で実行）。

- 震度5弱以上の地震（気象庁 quake/list.json）→ FCMトピック 'quake5'
- 特別警報の新規発表（気象庁 warning/map.json）→ FCMトピック 'special-warning'

通知済み管理は data/bosai_notify_state.json（変更時のみコミットされる）。
認証は FIREBASE_SERVICE_ACCOUNT（既存のランキング集計と同じ鍵）。
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

JST = timezone(timedelta(hours=9))
STATE_PATH = "data/bosai_notify_state.json"
QUAKE_URL = "https://www.jma.go.jp/bosai/quake/data/list.json"
WARNING_URL = "https://www.jma.go.jp/bosai/warning/data/r8/map.json"  # 旧warning/map.jsonは2026-05で凍結

STRONG_INTENSITY = {"5-", "5+", "6-", "6+", "7"}
# 震度→通知対象トピック（クライアントは選択レベルの1トピックだけ購読する）
INTENSITY_TOPICS = {
    "5-": ["quake5"],
    "5+": ["quake5", "quake5up"],
    "6-": ["quake5", "quake5up", "quake6low"],
    "6+": ["quake5", "quake5up", "quake6low"],
    "7":  ["quake5", "quake5up", "quake6low"],
}
INTENSITY_LABEL = {"5-": "5弱", "5+": "5強", "6-": "6弱", "6+": "6強", "7": "7"}
SPECIAL_WARNINGS = {
    "32": "暴風雪特別警報", "33": "大雨特別警報", "35": "暴風特別警報",
    "36": "大雪特別警報", "37": "波浪特別警報", "38": "高潮特別警報",
}
PREF_NAMES = {
    "01": "北海道", "02": "青森県", "03": "岩手県", "04": "宮城県", "05": "秋田県",
    "06": "山形県", "07": "福島県", "08": "茨城県", "09": "栃木県", "10": "群馬県",
    "11": "埼玉県", "12": "千葉県", "13": "東京都", "14": "神奈川県", "15": "新潟県",
    "16": "富山県", "17": "石川県", "18": "福井県", "19": "山梨県", "20": "長野県",
    "21": "岐阜県", "22": "静岡県", "23": "愛知県", "24": "三重県", "25": "滋賀県",
    "26": "京都府", "27": "大阪府", "28": "兵庫県", "29": "奈良県", "30": "和歌山県",
    "31": "鳥取県", "32": "島根県", "33": "岡山県", "34": "広島県", "35": "山口県",
    "36": "徳島県", "37": "香川県", "38": "愛媛県", "39": "高知県", "40": "福岡県",
    "41": "佐賀県", "42": "長崎県", "43": "熊本県", "44": "大分県", "45": "宮崎県",
    "46": "鹿児島県", "47": "沖縄県",
}


def fcm_token(sa_info: dict) -> tuple[str, str]:
    creds = service_account.Credentials.from_service_account_info(
        sa_info,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"])
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token, sa_info["project_id"]


def send_push(token: str, project: str, topic: str,
              title: str, body: str) -> None:
    r = requests.post(
        f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
        headers={"Authorization": f"Bearer {token}"},
        json={"message": {
            "topic": topic,
            "notification": {"title": title, "body": body},
            "apns": {"headers": {"apns-priority": "10"},
                     "payload": {"aps": {"sound": "default"}}},
        }},
        timeout=30)
    r.raise_for_status()
    print(f"push sent [{topic}] {title} / {body}")


def load_state() -> dict:
    try:
        return json.load(open(STATE_PATH, encoding="utf-8"))
    except FileNotFoundError:
        return {"notified_quakes": [], "active_special": []}


def check_quakes(state: dict) -> list[tuple[str, str, str, list[str]]]:
    """未通知の震度5弱以上を返す [(eid, title, body, topics)]"""
    out = []
    quakes = requests.get(QUAKE_URL, timeout=30).json()
    since = datetime.now(JST) - timedelta(hours=3)
    notified = set(state["notified_quakes"])
    for e in quakes:
        eid = str(e.get("eid", ""))
        maxi = e.get("maxi", "")
        at = datetime.fromisoformat(e.get("at", "1970-01-01T00:00:00+09:00"))
        if maxi not in STRONG_INTENSITY or eid in notified:
            continue
        if at < since:  # 古い地震は通知しない（初回実行時の大量通知防止）
            continue
        label = INTENSITY_LABEL.get(maxi, maxi)
        title = f"震度{label}の地震が発生しました"
        body = (f"{e.get('anm', '不明')}で震度{label}"
                f"（M{e.get('mag', '-')}・{at.strftime('%H:%M')}頃）。"
                "周辺のライブカメラを確認できます")
        out.append((eid, title, body, INTENSITY_TOPICS.get(maxi, ["quake5"])))
    return out


def check_special_warnings(state: dict) -> tuple[list[tuple[str, str]], list[str]]:
    """新規発表の特別警報 [(title, body)] と現在の発表中リストを返す。
    r8形式: 発表報ログの配列。官署ごとに最新報のみを現在状態として採用する。"""
    reports = requests.get(WARNING_URL, timeout=30).json()
    latest: dict[str, dict] = {}
    for rep in reports:
        office = rep.get("publishingOffice", "")
        dt = rep.get("reportDatetime", "")
        if office not in latest or dt > latest[office].get("reportDatetime", ""):
            latest[office] = rep
    current: set[str] = set()  # "pref:code"
    for rep in latest.values():
        warning = rep.get("warning") or {}
        for area in warning.get("class10Items") or []:
            code = area.get("areaCode", "")
            pref = code[:2]
            if pref not in PREF_NAMES:
                continue
            for w in area.get("kinds") or []:
                wc = w.get("code", "")
                status = w.get("status", "")
                if wc in SPECIAL_WARNINGS and status != "解除" and "なし" not in status:
                    current.add(f"{pref}:{wc}")
    previous = set(state["active_special"])
    out = []
    for key in sorted(current - previous):
        pref, wc = key.split(":")
        title = f"{SPECIAL_WARNINGS[wc]}が発表されました"
        body = f"{PREF_NAMES[pref]}に{SPECIAL_WARNINGS[wc]}。周辺のライブカメラを確認できます"
        out.append((title, body))
    return out, sorted(current)


def main() -> int:
    sa_raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "")
    if not sa_raw:
        print("FIREBASE_SERVICE_ACCOUNT 未設定のためスキップ")
        return 0
    state = load_state()
    quake_events = check_quakes(state)
    warning_events, current_special = check_special_warnings(state)

    changed = False
    if quake_events or warning_events:
        token, project = fcm_token(json.loads(sa_raw))
        for eid, title, body, topics in quake_events:
            for topic in topics:
                send_push(token, project, topic, title, body)
            state["notified_quakes"].append(eid)
            changed = True
        for title, body in warning_events:
            send_push(token, project, "special-warning", title, body)
            changed = True
    if sorted(current_special) != sorted(state["active_special"]):
        changed = True
    state["active_special"] = current_special
    state["notified_quakes"] = state["notified_quakes"][-200:]

    # stateは毎回書き出す（コミットは差分があるときだけワークフロー側で行う）
    json.dump(state, open(STATE_PATH, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("state updated" if changed else "変化なし")
    return 0


if __name__ == "__main__":
    sys.exit(main())
