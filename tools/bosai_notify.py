"""重大災害のプッシュ通知送信（GitHub Actionsから10分間隔で実行）。

- 震度5弱以上の地震（気象庁 quake/list.json）→ FCMトピック 'quake5'
- 特別警報の新規発表（気象庁 warning/map.json）→ FCMトピック 'special-warning'(全国) と 'special-warning-<prefJIS>'(都道府県別)

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

STRONG_INTENSITY = {"4", "5-", "5+", "6-", "6+", "7"}
# 震度→通知対象トピック（クライアントは選択レベルの1トピックだけ購読する）
# quake4 は「震度4以上」を選んだ利用者向け(2026-08-30追加)
INTENSITY_TOPICS = {
    "4":  ["quake4"],
    "5-": ["quake4", "quake5"],
    "5+": ["quake4", "quake5", "quake5up"],
    "6-": ["quake4", "quake5", "quake5up", "quake6low"],
    "6+": ["quake4", "quake5", "quake5up", "quake6low"],
    "7":  ["quake4", "quake5", "quake5up", "quake6low"],
}
INTENSITY_LABEL = {"4": "4", "5-": "5弱", "5+": "5強", "6-": "6弱", "6+": "6強", "7": "7"}
SPECIAL_WARNINGS = {
    "32": "暴風雪特別警報", "33": "大雨特別警報", "34": "洪水特別警報",
    "35": "暴風特別警報", "36": "大雪特別警報", "37": "波浪特別警報",
    "38": "高潮特別警報", "39": "土砂災害特別警報",
}
# 2026-05-28新体系の「危険警報」(警戒レベル4相当)。danger-warning系トピックに送る
DANGER_WARNINGS = {
    "43": "大雨危険警報", "44": "洪水危険警報",
    "48": "高潮危険警報", "49": "土砂災害危険警報",
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
              title: str, body: str, tab: str = "") -> None:
    """tab: アプリが通知タップ時に開く災害速報内タブ('quake'|'warning'|'')"""
    r = requests.post(
        f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
        headers={"Authorization": f"Bearer {token}"},
        json={"message": {
            "topic": topic,
            "notification": {"title": title, "body": body},
            "data": {"screen": "bosai", "tab": tab},
            "apns": {"headers": {"apns-priority": "10"},
                     "payload": {"aps": {"sound": "default"}}},
        }},
        timeout=30)
    r.raise_for_status()
    print(f"push sent [{topic}] {title} / {body}")


def _fetch_json(url: str):
    """気象庁JSONを取得。HTTPエラー・非JSON応答(メンテ画面等)は None を返し、
    呼び出し側でそのチェックだけ見送る（1系統の障害で通知処理全体を落とさない）"""
    try:
        r = requests.get(url, timeout=30)
        if r.status_code != 200:
            print(f"取得失敗 {url}: HTTP {r.status_code}", file=sys.stderr)
            return None
        return r.json()
    except (requests.RequestException, ValueError) as e:
        print(f"取得失敗 {url}: {type(e).__name__}: {e}", file=sys.stderr)
        return None


def load_state() -> dict:
    try:
        return json.load(open(STATE_PATH, encoding="utf-8"))
    except FileNotFoundError:
        return {"notified_quakes": [], "active_special": []}


_INTENSITY_ORDER = {"4": 0, "5-": 0, "5+": 1, "6-": 2, "6+": 3, "7": 4}


def check_quakes(state: dict) -> list[tuple[str, str, str, list[str]]]:
    """未通知の震度5弱以上を返す [(eid, title, body, topics)]。

    list.json は同一地震(eid)を複数報（震度速報/震源情報/震源・震度情報）で
    掲載するため、eidでまとめて1通にする。震度速報は anm(震源地名)・mag が
    空文字列なので、埋まっている報を優先して本文を作る。
    """
    out = []
    quakes = _fetch_json(QUAKE_URL)
    if quakes is None:  # 気象庁側の一時障害。今回は地震チェックを見送り次回に持ち越す
        return out
    since = datetime.now(JST) - timedelta(hours=3)
    notified = set(state["notified_quakes"])
    groups: dict[str, list[dict]] = {}
    for e in quakes:
        eid = str(e.get("eid", ""))
        if not eid or eid in notified:
            continue
        groups.setdefault(eid, []).append(e)
    for eid, entries in groups.items():
        strong = [e.get("maxi", "") for e in entries
                  if e.get("maxi", "") in STRONG_INTENSITY]
        if not strong:
            continue
        maxi = max(strong, key=lambda m: _INTENSITY_ORDER[m])
        # 震源地名→M→報告時刻の順で埋まっている報を採用する
        best = max(entries, key=lambda e: (
            bool(e.get("anm")), bool(e.get("mag")), e.get("rdt", "")))
        at = datetime.fromisoformat(
            best.get("at") or "1970-01-01T00:00:00+09:00")
        if at < since:  # 古い地震は通知しない（初回実行時の大量通知防止）
            continue
        label = INTENSITY_LABEL.get(maxi, maxi)
        title = f"震度{label}の地震が発生しました"
        place = best.get("anm") or ""
        mag = best.get("mag") or ""
        detail = (f"M{mag}・" if mag else "") + f"{at.strftime('%H:%M')}頃"
        head = f"{place}で震度{label}" if place else f"震度{label}を観測"
        body = f"{head}（{detail}）。周辺のライブカメラを確認できます"
        out.append((eid, title, body, INTENSITY_TOPICS.get(maxi, ["quake5"])))
    return out


def check_special_warnings(state: dict) -> tuple[list[tuple[str, str, str]], list[str]]:
    """新規発表の特別警報 [(title, body, prefJIS)] と現在の発表中リストを返す。
    r8形式: 発表報ログの配列。官署は気象警報(VPWW55)と土砂災害(VPWW56)等を
    別々の報として出すため、官署×報種別ごとに最新報を採用して合算する
    （官署単位だと同時刻の土砂災害報が落ちる。2026-08-23石垣島で実際に発生）。"""
    reports = _fetch_json(WARNING_URL)
    if reports is None:  # 取得失敗時は状態を変えない（解除扱いにして再通知させない）
        return [], sorted(state["active_special"])
    latest: dict[tuple[str, str], dict] = {}
    for rep in reports:
        key = (rep.get("publishingOffice", ""), rep.get("dataTypeCode", ""))
        dt = rep.get("reportDatetime", "")
        if key not in latest or dt > latest[key].get("reportDatetime", ""):
            latest[key] = rep
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
                if (wc in SPECIAL_WARNINGS or wc in DANGER_WARNINGS) \
                        and status != "解除" and "なし" not in status:
                    current.add(f"{pref}:{wc}")
    previous = set(state["active_special"])
    out = []
    for key in sorted(current - previous):
        pref, wc = key.split(":")
        if wc in SPECIAL_WARNINGS:
            out.append((pref, wc, "special", SPECIAL_WARNINGS[wc]))
        else:
            out.append((pref, wc, "danger", DANGER_WARNINGS[wc]))
    return out, sorted(current)


TAIL = "。周辺のライブカメラを確認できます"


def aggregate_warning_pushes(events: list[tuple[str, str, str, str]]
                             ) -> list[tuple[str, str, str]]:
    """同一チェック内の新規発表を、送信トピックごとに1通へ集約する。

    events: [(prefJIS, code, family, 警報名)]
    返り値: [(topic, title, body)]。
    - 全国トピック({family}-warning)はfamilyごとに必ず1通
    - 都道府県別トピックは県ごとに1通（同県の複数種別は連結）
    """
    pushes: list[tuple[str, str, str]] = []
    for family, generic, tag in (("special", "特別警報", ""),
                                 ("danger", "危険警報", "（警戒レベル4相当）")):
        evs = sorted([e for e in events if e[2] == family])
        if not evs:
            continue
        names = sorted({e[3] for e in evs})
        pref_names = [PREF_NAMES[p] for p in sorted({e[0] for e in evs})]
        if len(names) == 1:
            title = f"{names[0]}が発表されました{tag}"
            shown = "・".join(pref_names[:8])
            if len(pref_names) > 8:
                shown += f" ほか{len(pref_names) - 8}県"
            body = f"{shown}に{names[0]}{TAIL}"
        else:
            title = f"{generic}が発表されました{tag}"
            pairs = [f"{PREF_NAMES[p]}に{n}" for p, _, _, n in evs]
            shown = "、".join(pairs[:3])
            if len(pairs) > 3:
                shown += f" ほか{len(pairs) - 3}件"
            body = f"{shown}{TAIL}"
        pushes.append((f"{family}-warning", title, body))

        by_pref: dict[str, list[str]] = {}
        for p, _, _, n in evs:
            by_pref.setdefault(p, []).append(n)
        for p in sorted(by_pref):
            ns = sorted(set(by_pref[p]))
            if len(ns) == 1:
                title = f"{ns[0]}が発表されました{tag}"
            else:
                title = f"{ns[0]}ほか{len(ns) - 1}件が発表されました{tag}"
            body = f"{PREF_NAMES[p]}に{'・'.join(ns)}{TAIL}"
            pushes.append((f"{family}-warning-{p}", title, body))
    return pushes


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
                send_push(token, project, topic, title, body, tab="quake")
            state["notified_quakes"].append(eid)
            changed = True
        # 同一チェック内の複数発表はトピックごとに1通へ集約する
        # (全国購読者への連打防止)。special=レベル5 / danger=レベル4
        for topic, title, body in aggregate_warning_pushes(warning_events):
            send_push(token, project, topic, title, body, tab="warning")
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
