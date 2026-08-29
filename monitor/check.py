"""カメラ1台の死活チェック（SPEC 7.1-7.2）。

- タイムアウト10秒、リトライ1回
- If-None-Match / If-Modified-Since を必ず送る
- 画像そのものは保存しない。dHashのみ履歴に残す
"""

from __future__ import annotations

import re
import time
import urllib.parse
from datetime import datetime, timezone
from typing import Any

import requests

from monitor.freeze import (HISTORY_MAX, dhash64, is_black_frame,
                            is_local_daytime, is_placeholder, judge_frozen)

USER_AGENT = "LiveCamJP-Monitor/1.0 (+https://github.com/kotopapa/livecam-jp)"
TIMEOUT_SEC = 10
ERROR_AFTER_FAILURES = 3


def _get(session: requests.Session, url: str, headers: dict[str, str]) -> requests.Response | None:
    for attempt in range(2):                       # リトライ1回
        try:
            return session.get(url, headers=headers, timeout=TIMEOUT_SEC)
        except requests.RequestException:
            if attempt == 0:
                time.sleep(1)
    return None


def check_camera(session: requests.Session, camera: dict[str, Any],
                 state: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    """1台チェックして status レコードと更新済み state を返す。

    state: {"history": [{"at","hash"}], "etag": str, "last_modified": str,
            "consecutive_failures": int, "last_ok_at": str, "ok_times": [iso...]}
    """
    now = now or datetime.now(timezone.utc)
    feed = camera["feed"]
    ftype = feed["type"]
    prev_failures = state.get("consecutive_failures", 0)

    if ftype == "still_image":
        return _check_still(session, camera, state, now, prev_failures)
    if ftype in ("mlit_roadinfo", "jma_volcam", "thr_camxml", "camidx_latest",
                 "saitama_flood", "kochi_suibo", "sizenken", "shimanto_kasen", "takashima_river", "higashiomi_river", "yamaguchi_romen",
                 "yamaguchi_kasen"):
        # いずれも都度解決型: main.py が _resolved_image を事前解決してくる
        return _check_roadinfo(session, camera, state, now, prev_failures)
    if ftype == "mie_douro":
        return _check_mie_douro(camera, state, now, prev_failures)
    if ftype in ("youtube_channel", "youtube_video"):
        return _check_youtube(session, camera, state, now, prev_failures)
    # web_page / hls はステータスコードのみ確認
    return _check_page(session, camera, state, now, prev_failures)


def _fail(state: dict, now: datetime, prev_failures: int, http_status: int | None) -> dict:
    failures = prev_failures + 1
    state["consecutive_failures"] = failures
    return {
        "state": "error" if failures >= ERROR_AFTER_FAILURES else "unknown",
        "last_ok_at": state.get("last_ok_at"),
        "http_status": http_status,
        "frozen_since": None,
        "consecutive_failures": failures,
        "avg_interval_sec": state.get("avg_interval_sec"),
    }


def _headers(camera: dict, state: dict) -> dict[str, str]:
    h = {"User-Agent": USER_AGENT}
    h.update(camera["feed"].get("headers") or {})
    if camera["feed"].get("requires_referer"):
        h["Referer"] = camera.get("fallback", {}).get("url") or camera["source"]["page_url"]
    if state.get("etag"):
        h["If-None-Match"] = state["etag"]
    if state.get("last_modified"):
        h["If-Modified-Since"] = state["last_modified"]
    return h


def _check_roadinfo(session, camera, state, now, prev_failures) -> dict:
    """都度解決型（道路情報提供システム）。

    monitor/main.py の事前解決パスが camera["_resolved_image"] に
    {"url": 最新静止画URL, "time": 提供元申告の取得時刻} を入れてくる。
    解決できていなければ失敗として数える。
    """
    resolved = camera.get("_resolved_image") or {}
    url = resolved.get("url")
    if not url:
        return _fail(state, now, prev_failures, None)
    # タイムスタンプ付きURLは毎回変わるため、ETag/If-Modified-Since は意味を持たない
    state.pop("etag", None)
    state.pop("last_modified", None)
    result = _check_still(session, camera, state, now, prev_failures, url=url)
    result["image_url"] = url
    result["image_time"] = resolved.get("time") or None
    return result


def _check_still(session, camera, state, now, prev_failures, url: str | None = None) -> dict:
    resp = _get(session, url or camera["feed"]["url"], _headers(camera, state))
    if resp is None or resp.status_code >= 400:
        return _fail(state, now, prev_failures, resp.status_code if resp is not None else None)

    history: list[dict] = state.get("history", [])
    not_modified = resp.status_code == 304
    if not_modified:
        # 304 = 前回(成功時)と同一。前回ハッシュを引き継いで履歴に追加
        h = history[-1]["hash"] if history else None
    else:
        if not resp.headers.get("Content-Type", "").lower().startswith("image/"):
            return _fail(state, now, prev_failures, resp.status_code)
        h = dhash64(resp.content)
        if is_placeholder(h):
            # HTTP 200 だが「画像がありません」プレースホルダ → 失敗として数える
            return _fail(state, now, prev_failures, resp.status_code)
        if is_local_daytime(now, camera.get("lng")) and is_black_frame(resp.content):
            # 日中なのに真っ暗（映像信号なし等）。タイムスタンプだけ更新される
            # ため凍結判定では拾えない → 失敗として数える
            return _fail(state, now, prev_failures, resp.status_code)

    # ETag等の保存は全チェック通過後のみ。失敗時に保存すると次回304で検知をすり抜ける
    state["consecutive_failures"] = 0
    state["etag"] = resp.headers.get("ETag") or state.get("etag")
    state["last_modified"] = resp.headers.get("Last-Modified") or state.get("last_modified")

    # 更新間隔の実測: 画像が変わった時刻を記録
    if (not not_modified and history and history[-1].get("hash") is not None
            and h is not None and h != history[-1]["hash"]):
        times = state.get("change_times", [])
        times.append(now.isoformat())
        state["change_times"] = times[-10:]
        if len(times) >= 2:
            ts = [datetime.fromisoformat(t) for t in times[-10:]]
            deltas = [(b - a).total_seconds() for a, b in zip(ts, ts[1:])]
            state["avg_interval_sec"] = int(sum(deltas) / len(deltas))

    history.append({"at": now.isoformat(), "hash": h})
    state["history"] = history[-HISTORY_MAX:]
    state["last_ok_at"] = now.isoformat()

    frozen, frozen_since = judge_frozen(state["history"], now, camera.get("lat"), camera.get("lng"))
    return {
        "state": "frozen" if frozen else "ok",
        "last_ok_at": state["last_ok_at"],
        "http_status": 200 if not_modified else resp.status_code,
        "frozen_since": frozen_since if frozen else None,
        "consecutive_failures": 0,
        "avg_interval_sec": state.get("avg_interval_sec"),
    }


def _check_mie_douro(camera, state, now, prev_failures) -> dict:
    """三重県道路規制情報（画像がAPI応答内のbase64のみ）。

    monitor/main.py が camera_get_api.php を一括取得し、該当カメラの
    デコード済みバイト列を camera["_mie_bytes"]、観測時刻を
    camera["_mie_time"] に入れてくる。URLは存在しないため、バイト列に
    対して _check_still と同じハッシュ履歴・フリーズ判定を行う。
    """
    data = camera.get("_mie_bytes")
    if not data or len(data) < 2000:
        return _fail(state, now, prev_failures, None)
    h = dhash64(data)
    if is_placeholder(h):
        return _fail(state, now, prev_failures, 200)
    history: list[dict] = state.get("history", [])
    state["consecutive_failures"] = 0
    if (history and history[-1].get("hash") is not None and h != history[-1]["hash"]):
        times = state.get("change_times", [])
        times.append(now.isoformat())
        state["change_times"] = times[-10:]
    history.append({"at": now.isoformat(), "hash": h})
    state["history"] = history[-HISTORY_MAX:]
    state["last_ok_at"] = now.isoformat()
    frozen, frozen_since = judge_frozen(state["history"], now, camera.get("lat"), camera.get("lng"))
    return {
        "state": "frozen" if frozen else "ok",
        "last_ok_at": state["last_ok_at"],
        "http_status": 200,
        "frozen_since": frozen_since if frozen else None,
        "consecutive_failures": 0,
        "avg_interval_sec": state.get("avg_interval_sec"),
        "image_time": camera.get("_mie_time"),
    }


_YT_START_RE = re.compile(r'"startTimestamp":"([^"]+)"')


def _youtube_watch_alive(text: str, now: datetime) -> bool:
    """watchページからライブカメラとして生きているか判定する。

    - ライブ中/待機枠 → 生存
    - UNPLAYABLE(「記録はご覧いただけません」等) → 死
    - 配信終了(アーカイブ化)でも開始が48時間以内 → 夜間・営業時間停止型
      とみなして生存扱い(深夜チェックでの誤検知防止)。48時間超は死
    """
    if ('"isLiveNow":true' in text or '"isLive":true' in text
            or '"isUpcoming":true' in text):
        return True
    if '"status":"UNPLAYABLE"' in text:
        return False
    m = _YT_START_RE.search(text)
    if not m:
        return False  # ライブ由来でない通常動画
    try:
        start = datetime.fromisoformat(m.group(1).replace("Z", "+00:00"))
    except ValueError:
        return False
    return (now - start).total_seconds() <= 48 * 3600


def _check_youtube(session, camera, state, now, prev_failures) -> dict:
    """oEmbed / チャンネルURLの応答コードで判定する（Data APIは使わない）。

    embedページの本文判定は2026年夏頃から機能しない（生死どちらも同一の
    汎用シェルHTMLが返る）。代わりに:
    - youtube_video: oEmbed が 200 なら視聴可。4xx は削除/非公開/埋め込み
      不可のいずれかで、アプリ内では再生できないため障害扱いにする
    - youtube_channel: /channel/<id>/live が 404 ならチャンネル消滅。
      配信休止中でも200が返り、新配信開始で自動復帰する型なので存在確認のみ
    """
    feed = camera["feed"]
    if feed["type"] == "youtube_channel":
        url = f"https://www.youtube.com/channel/{feed['url']}/live"
    elif feed["url"].startswith("videoseries?list="):
        # プレイリスト埋め込み型（離島カメラ等）はプレイリストの存在で判定
        pl = feed["url"].split("list=", 1)[1].split("&")[0]
        target = urllib.parse.quote(
            f"https://www.youtube.com/playlist?list={pl}", safe="")
        url = f"https://www.youtube.com/oembed?url={target}&format=json"
    else:
        watch = urllib.parse.quote(
            f"https://www.youtube.com/watch?v={feed['url']}", safe="")
        url = f"https://www.youtube.com/oembed?url={watch}&format=json"
    resp = _get(session, url, {"User-Agent": USER_AGENT})
    if resp is None or resp.status_code >= 400:
        return _fail(state, now, prev_failures, resp.status_code if resp is not None else None)
    # youtube_video は「現在ライブ中(または待機枠)」かも確認する。
    # 配信終了してアーカイブ化/記録非公開になったIDは oEmbed 200 のままだが
    # ライブカメラとしては死んでいる（GAO・「記録はご覧いただけません」型）
    if feed["type"] == "youtube_video" and not feed["url"].startswith("videoseries"):
        watch = _get(session,
                     f"https://www.youtube.com/watch?v={feed['url']}",
                     {"User-Agent": USER_AGENT})
        if watch is not None and "ytInitialPlayerResponse" in watch.text:
            if not _youtube_watch_alive(watch.text, now):
                return _fail(state, now, prev_failures, resp.status_code)
        # 判定材料が無い応答(同意画面等のシェル)は oEmbed の結果を採用する
    state["consecutive_failures"] = 0
    state["last_ok_at"] = now.isoformat()
    return {
        "state": "ok",
        "last_ok_at": state["last_ok_at"],
        "http_status": resp.status_code,
        "frozen_since": None,
        "consecutive_failures": 0,
        "avg_interval_sec": None,
    }


def _check_page(session, camera, state, now, prev_failures) -> dict:
    resp = _get(session, camera["feed"]["url"], _headers(camera, state))
    if resp is None or resp.status_code >= 400:
        return _fail(state, now, prev_failures, resp.status_code if resp is not None else None)
    state["consecutive_failures"] = 0
    state["etag"] = resp.headers.get("ETag")
    state["last_modified"] = resp.headers.get("Last-Modified")
    state["last_ok_at"] = now.isoformat()
    return {
        "state": "ok",
        "last_ok_at": state["last_ok_at"],
        "http_status": resp.status_code,
        "frozen_since": None,
        "consecutive_failures": 0,
        "avg_interval_sec": None,
    }
