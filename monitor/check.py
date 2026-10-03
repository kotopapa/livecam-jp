"""カメラ1台の死活チェック（SPEC 7.1-7.2）。

- タイムアウト10秒、リトライ1回
- If-None-Match / If-Modified-Since を必ず送る
- 画像そのものは保存しない。dHashのみ履歴に残す
"""

from __future__ import annotations

import json
import re
import time
import urllib.parse
from datetime import datetime, timedelta, timezone
from typing import Any

import requests

from monitor.freeze import (HISTORY_MAX, as_utc, dhash64, is_black_frame,
                            is_local_daytime, is_placeholder, judge_frozen,
                            parse_utc)

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
                 "yamaguchi_kasen", "shimane_suibo", "fukuoka_kasen", "yachiyo_kansen"):
        # いずれも都度解決型: main.py が _resolved_image を事前解決してくる
        return _check_roadinfo(session, camera, state, now, prev_failures)
    if ftype in ("mie_douro", "sakura_bosaicam"):
        # どちらも画像が JSON 内の base64 のみ。main.py が _mie_bytes / _mie_time に入れてくる
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


def _hold(state: dict, prev_failures: int, http_status: int | None) -> dict:
    """判定材料が取れなかった回。失敗回数を増やしも戻しもせず、前回の判定を保つ"""
    state["consecutive_failures"] = prev_failures
    return {
        "state": "error" if prev_failures >= ERROR_AFTER_FAILURES else "unknown",
        "last_ok_at": state.get("last_ok_at"),
        "http_status": http_status,
        "frozen_since": None,
        "consecutive_failures": prev_failures,
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


STALE_LAST_MODIFIED_DAYS = 7


def _stale_last_modified(value: str | None, now) -> str | None:
    """Last-Modified が STALE_LAST_MODIFIED_DAYS より古ければその時刻(ISO)を返す。"""
    if not value:
        return None
    try:
        from email.utils import parsedate_to_datetime
        lm = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    lm = as_utc(lm)                 # RFC2822 の "-0000" は naive で返る
    if as_utc(now) - lm > timedelta(days=STALE_LAST_MODIFIED_DAYS):
        return lm.isoformat()
    return None


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
        if not resp.content:
            # HTTP 200・image/jpeg だが本文0バイト（石川県道路カメラで実発生。
            # カメラ側停止中にサーバが空ファイルを配信する）→ 失敗として数える
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

    # サーバが画像の更新日時を返し、それが古すぎるなら履歴を待たずに frozen 扱い
    # （季節営業のスキー場カメラ等。2026-08-29 イエティで3月末のまま配信されていた）
    stale_since = _stale_last_modified(state.get("last_modified"), now)
    if stale_since is not None:
        return {
            "state": "frozen",
            "last_ok_at": state.get("last_ok_at"),
            "http_status": resp.status_code,
            "frozen_since": stale_since,
            "consecutive_failures": 0,
            "avg_interval_sec": state.get("avg_interval_sec"),
        }

    # 更新間隔の実測: 画像が変わった時刻を記録
    if (not not_modified and history and history[-1].get("hash") is not None
            and h is not None and h != history[-1]["hash"]):
        times = state.get("change_times", [])
        times.append(now.isoformat())
        state["change_times"] = times[-10:]
        if len(times) >= 2:
            # 古いstateにオフセット無しの記録が混ざっていても
            # naive/aware比較でTypeErrorにならないようUTCへ揃える
            ts = [parse_utc(t) for t in times[-10:]]
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
        start = parse_utc(m.group(1))
    except ValueError:
        return False
    return (as_utc(now) - start).total_seconds() <= 48 * 3600


_YT_CANONICAL_WATCH_RE = re.compile(
    r'<link rel="canonical" href="https://www\.youtube\.com/watch\?v=([\w-]{11})"')


def resolve_youtube_channel_live(text: str) -> str | None:
    """/channel/<id>/live のページから、いま配信中（または待機枠）の動画IDを取り出す。

    配信があるとき canonical が watch?v=<ID> になり、無いときはチャンネルURLになる。
    アプリの `embed/live_stream?channel=` はチャンネルが配信中でも「この動画は
    再生できません」になることがある（2026-09 湯島・富士見台で発生）ため、
    status.json の video_id で動画IDの埋め込みに切り替えてもらう
    """
    m = _YT_CANONICAL_WATCH_RE.search(text)
    if not m:
        return None
    # canonical が指す枠が「配信予定のまま放置された古い枠」のことがある（足寄町
    # 2024-02 の枠に 2026-09 でも解決され、アプリに2年前の待機画面が出た）。
    # /live ページの player 情報には isLiveNow が入らないので、再生可（status OK）かつ
    # 予定枠（isUpcoming）でないときだけ採用する。配信中の判定は /streams の
    # ライブ印（find_live_in_streams）を優先し、こちらはその代替
    if '"status":"OK"' not in text or '"isUpcoming":true' in text:
        return None
    return m.group(1)


_YT_CHANNEL_LIVE_RE = re.compile(r"youtube\.com/(channel/UC[\w-]{22}|@[^/?#]+|c/[^/?#]+|user/[^/?#]+)/live(?:[?#]|$)")


def _youtube_channel_live_page_alive(text: str) -> bool | None:
    """チャンネルの /live ページが、いま配信中（または待機枠）の動画を指しているか。

    True=配信あり / False=配信なし（canonical がチャンネル自身） / None=判定材料なし（429・同意画面等）
    """
    if _YT_CANONICAL_WATCH_RE.search(text):
        if "ytInitialPlayerResponse" not in text:
            return None
        return resolve_youtube_channel_live(text) is not None
    if re.search(r'<link rel="canonical" href="https://www\.youtube\.com/(channel/|@)', text):
        return False
    return None


def list_live_in_streams(text: str) -> list[tuple[str, str]]:
    """チャンネルの /streams ページ（ytInitialData）から配信中の (動画ID, タイトル) を列挙する。

    一覧の各項目は lockupViewModel（`"contentId":"<ID>"`）で、配信中の項目だけ
    同じブロック内に `THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE` を持つ（2026-08 時点の構造）
    """
    # lockupViewModel の JSON は contentImage（サムネイルとライブ印）→ metadata（タイトル）
    # → contentId の順なので、印とタイトルは contentId の**前**にある。contentId から
    # 次の contentId までを見ると隣の項目の印を拾う（2026-09-30 富士見台で枠を取り違えた）
    out: list[tuple[str, str]] = []
    starts = [m.start() for m in re.finditer(r'"lockupViewModel":\{', text)]
    for i, pos in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(text)
        blk = text[pos:end]
        cid = re.search(r'"contentId":"([\w-]{11})"', blk)
        if not cid or "THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE" not in blk[:cid.start()]:
            continue
        vid = cid.group(1)
        m = re.search(r'"title":\{"content":"((?:[^"\\]|\\.)*)"', blk[:cid.start()])
        title = ""
        if m:
            try:
                title = json.loads('"' + m.group(1) + '"')
            except ValueError:
                title = m.group(1)
        out.append((vid, title))
    return out


# 定点カメラらしいタイトルの目印（同時に複数配信するチャンネルで枠を選ぶ）
_CAMERA_TITLE_HINTS = ("24時間", "24h", "24H", "ライブカメラ", "定点", "LIVE CAMERA", "Live Camera", "live camera")


def pick_live_stream(lives: list[tuple[str, str]], camera_name: str,
                     previous: str | None) -> str | None:
    """同時配信が複数あるとき、カメラ枠として最もそれらしい動画IDを選ぶ。

    優先順: 前回選んだ枠がまだ配信中 → 「24時間」「ライブカメラ」等の目印 →
    台帳のカメラ名との語の重なり → 一覧の先頭。富士見台どうぶつ病院は保護猫ルームの
    24時間枠と獣医師の解説ライブを同時に流し、先頭を取ると解説ライブになった（2026-09-30）
    """
    if not lives:
        return None
    if previous and any(v == previous for v, _ in lives):
        return previous
    tokens = {t for t in re.split(r"[\s（）()【】｜|・、/／-]+", camera_name) if len(t) >= 2}

    def score(item: tuple[str, str]) -> tuple[int, int]:
        vid, title = item
        hint = 1 if any(h in title for h in _CAMERA_TITLE_HINTS) else 0
        overlap = sum(1 for t in tokens if t in title)
        return (hint, overlap)

    return max(lives, key=score)[0]


def find_live_in_streams(text: str) -> str | None:
    """後方互換: 配信中の先頭の動画ID"""
    lives = list_live_in_streams(text)
    return lives[0][0] if lives else None


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
        elif prev_failures > 0:
            # 判定材料が無い応答（429・同意画面等のシェル・取得失敗）で、配信が終わったと
            # 判定済みのカメラを oEmbed の 200 だけで「正常」に戻さない。GitHub Actions では
            # watch ページが取れない回が混ざり、終わった枠が error⇄ok を往復して地図に
            # 出続けていた（2026-10-03 釜山 海雲台: 2026-09-23 に配信終了）
            return _hold(state, prev_failures, resp.status_code)
        # 失敗歴の無いカメラは従来どおり oEmbed の結果を採用する
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
    # YouTube への誘導型（watch リンク）は HTTP 200 のまま配信枠が終わる（「このライブ ストリームの
    # 記録は、ご覧いただけません」）。youtube_video と同じく watch ページで生死を見る（2026-10-01
    # 敦賀駅西口・山田農園ドッグランで、終わった枠へ案内していた）
    url = camera["feed"]["url"]
    if "youtube.com/watch" in url:
        if "ytInitialPlayerResponse" in resp.text:
            if not _youtube_watch_alive(resp.text, now):
                return _fail(state, now, prev_failures, resp.status_code)
        elif prev_failures > 0:
            return _hold(state, prev_failures, resp.status_code)
    elif _YT_CHANNEL_LIVE_RE.search(url):
        # チャンネルの「ライブ」への誘導型。配信が無いと /live はチャンネルのページになり
        # HTTP 200 のままなので、ここでも配信中かを見る（2026-10-03 保護猫カフェキズナ:
        # 最後の配信が2年前なのに「ライブ配信中」として地図に出ていた）。
        # 営業時間だけ配信する施設もあるので、非表示になるのは ERROR_AFTER_FAILURES 回続いたとき
        alive = _youtube_channel_live_page_alive(resp.text)
        if alive is False:
            return _fail(state, now, prev_failures, resp.status_code)
        if alive is None and prev_failures > 0:
            return _hold(state, prev_failures, resp.status_code)
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
