"""死活監視バッチのエントリポイント。

    python -m monitor.main            # cameras.json の承認済み全カメラをチェック
    python -m monitor.main --shard 0/2  # N分割巡回（カメラ数が増えたら使用）

- 同一ホストへの同時接続は2、リクエスト間隔1秒以上（SPEC 7.1）
- 出力: data/status.json、状態: monitor/.state/hashes.json（コミットする）
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse

import requests

try:
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

from crawler.sources.base import mount_legacy_tls
from monitor.domestic import is_domestic_only, merge_domestic
from monitor.check import (ERROR_AFTER_FAILURES, USER_AGENT, check_camera, list_live_in_streams, pick_live_stream,
                           resolve_youtube_channel_live)

REPO_ROOT = Path(__file__).resolve().parent.parent
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"
STATUS_PATH = REPO_ROOT / "data" / "status.json"
STATE_PATH = REPO_ROOT / "monitor" / ".state" / "hashes.json"
# 国内からしか届かないサイトの分（monitor/domestic.py）。国内の端末で --domestic を付けて回す
DOMESTIC_STATUS_PATH = REPO_ROOT / "data" / "status_domestic.json"
DOMESTIC_STATE_PATH = REPO_ROOT / "monitor" / ".state" / "hashes_domestic.json"

JST = timezone(timedelta(hours=9))

# 宮城県 河川流域情報システム（feed.type は camidx_latest を流用。解決は crawler.sources.miyagi_kasen）
MIYAGI_KASEN_HOST = "www.dobokusougou.pref.miyagi.jp"

HOST_MIN_INTERVAL = 1.0
HOST_MAX_CONCURRENCY = 2


class HostThrottle:
    """ホストごとに 同時2接続・1秒以上の間隔 を守る。"""

    def __init__(self):
        self._lock = threading.Lock()
        self._sem: dict[str, threading.Semaphore] = defaultdict(
            lambda: threading.Semaphore(HOST_MAX_CONCURRENCY))
        self._last: dict[str, float] = {}

    def acquire(self, host: str):
        self._sem[host].acquire()
        with self._lock:
            wait = HOST_MIN_INTERVAL - (time.monotonic() - self._last.get(host, 0))
        if wait > 0:
            time.sleep(wait)
        with self._lock:
            self._last[host] = time.monotonic()

    def release(self, host: str):
        self._sem[host].release()


def monitor_host(camera: dict) -> str:
    f = camera["feed"]
    if f["type"] in ("youtube_channel", "youtube_video"):
        return "www.youtube.com"
    return urlparse(f["url"]).netloc


# 低頻度で確認するホスト（運営者が定期的なデータ収集を控えるよう求めているもの）と、
# 確認を行うJST時刻。JST 03/09/15/21時の各1時間枠 = 1日4回（= UTC 18/00/06/12時台）
LOW_FREQ_HOSTS = ("cam.river.go.jp", "www.river.go.jp", "river.go.jp")
LOW_FREQ_HOURS_JST = (3, 9, 15, 21)


def _is_low_freq(camera: dict) -> bool:
    url = (camera.get("feed", {}) or {}).get("url") or ""
    page = (camera.get("source", {}) or {}).get("page_url") or ""
    return any(h in url or h in page for h in LOW_FREQ_HOSTS)


def _skip_low_freq(camera: dict, now: datetime) -> bool:
    """低頻度対象のカメラを、指定時刻の枠以外ではチェック対象から外す。

    枠はJSTで定義する。now は必ずJSTへ変換してから時刻を見るので、
    UTCで渡しても（ランナーのTZが何であっても）同じ枠になる。
    タイムゾーンなしの now は従来どおりUTCとみなす。
    """
    url = (camera.get("feed", {}) or {}).get("url") or ""
    page = (camera.get("source", {}) or {}).get("page_url") or ""
    if not any(h in url or h in page for h in LOW_FREQ_HOSTS):
        return False
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    return now.astimezone(JST).hour not in LOW_FREQ_HOURS_JST


# youtube_channel の配信ID解決に使う追加の時間（秒）。死活監視の予算を使い切ったあとも
# これだけは解決に回す（workflow の timeout-minutes 30 から通行規制・積雪の分を引いた範囲）
CHANNEL_EXTRA_SEC = int(os.environ.get("MONITOR_CHANNEL_EXTRA_SEC", "180"))


def group_by_channel(cams: list[dict]) -> list[list[dict]]:
    """解決順に並んだ youtube_channel のカメラを、チャンネルごとにまとめる。

    1 つのチャンネルが複数の拠点を同時配信している（東京都水防チャンネルは 30 台）ので、
    922 台に対してチャンネルは 550（2026-11-25）。カメラごとに /streams を取り直すと
    時間予算で毎回 6 割しか解決できなかった。まとめる順は、各チャンネルで最も古い
    カメラの順（渡された並びで最初に現れた順）
    """
    groups: dict[str, list[dict]] = {}
    for c in cams:
        groups.setdefault(c["feed"]["url"], []).append(c)
    return list(groups.values())


def carry_live_fields(prev: dict | None, result: dict) -> dict:
    """死活確認の結果に、前回までに解決した配信ID（video_id / live）を引き継ぐ。

    確認の結果は status を丸ごと置き換える。配信IDの解決は時間予算で毎回 6 割ほどしか
    回らないので、その回に確認だけ済んで解決が回らなかったカメラは video_id が消え、
    次に解決が回るまで（30〜60 分）アプリが live_stream?channel= の埋め込みに落ちて
    「この動画は再生できません」になっていた（2026-11-25 江古田川西原橋の利用者報告。
    936 台中 61 台がこの状態）。解決が回った回は resolve_channel が上書きする
    """
    if prev:
        for k in ("video_id", "live"):
            if k in prev and k not in result:
                result[k] = prev[k]
    return result


# oEmbed に題名が無い台がこの割合を超えた回は、YouTube 側の一時的な応答の変化とみなして
# 判定を見送る（配信中のカメラをまとめて隠さないため）。手元の実測は 180 台中 7 台（4%）
OEMBED_EMPTY_MAX_RATIO = 0.15
OEMBED_EMPTY_MIN_ALLOWED = 10


def apply_oembed_empty(statuses: dict, state_all: dict, empty_ids: list[str], checked: int) -> bool:
    """oEmbed が題名もチャンネルも返さなかった youtube_video を、失敗 1 回として数える。

    固定の動画IDは、配信が終わっても oEmbed が 200 のままで、ランナーからは watch ページも
    読めない回が大半なので、前回の判定を保ったまま地図に出続けていた（2026-11-25 江陵
    江門海岸。「動画を再生できません」）。check 側は保留で返し、ここで回全体の件数を見てから
    数える。ERROR_AFTER_FAILURES 回続くと error（地図に出さない）になり、配信が戻れば
    次の確認で ok に戻る。数えたら True、割合が高すぎて見送ったら False
    """
    if not empty_ids:
        return False
    if len(empty_ids) > max(OEMBED_EMPTY_MIN_ALLOWED, checked * OEMBED_EMPTY_MAX_RATIO):
        return False
    for cid in empty_ids:
        st = state_all.setdefault(cid, {})
        failures = st.get("consecutive_failures", 0) + 1
        st["consecutive_failures"] = failures
        rec = statuses.get(cid)
        if rec is not None:
            rec["consecutive_failures"] = failures
            rec["state"] = "error" if failures >= ERROR_AFTER_FAILURES else "unknown"
    return True


def channel_resolution_order(cams: list[dict], state_all: dict) -> list[dict]:
    """youtube_channel の解決順: 一度も解決していないもの → 解決が古い順。

    898 チャンネル（2026-11-02 時点）を台帳順に毎回先頭から解決すると、時間予算で
    毎回同じ所（約300台）で打ち切られ、後ろの約600台は video_id が永久に付かず、
    アプリが live_stream?channel= の埋め込みにフォールバックして「この動画は再生
    できません」になっていた（富士見台どうぶつ病院の利用者報告）。解決した時刻を
    監視の状態ファイル（配信しない）に持ち、古いものから順に回す
    """
    def key(c: dict):
        at = (state_all.get(c["id"]) or {}).get("live_resolved_at") or ""
        return (at, c["id"])
    return sorted(cams, key=key)


# 1回の実行の時間予算（秒）。GitHub Actions の timeout-minutes（25分）で打ち切られると
# その回の結果が全部捨てられるため、予算を過ぎたら新しい確認を始めずに、確認済みの分を
# 保存して終える（2026-10-06: 川の防災情報を確認する1日4回の枠で毎回25分を超え、
# 6時間おきに2回ずつ中断していた）。確認できなかったカメラは前回の結果を保つ
BUDGET_SEC = int(os.environ.get("MONITOR_BUDGET_SEC", str(20 * 60)))


def run(shard: str | None = None, domestic: bool = False) -> int:
    """domestic=False: 国内限定ホスト以外を確認して status.json に書く（GitHub Actions）。
    domestic=True: 国内限定ホストだけを確認して status_domestic.json に書く（国内の端末）"""
    status_path = DOMESTIC_STATUS_PATH if domestic else STATUS_PATH
    state_path = DOMESTIC_STATE_PATH if domestic else STATE_PATH
    started = time.monotonic()
    deadline = started + BUDGET_SEC
    if not CAMERAS_PATH.exists():
        print("data/cameras.json がない", file=sys.stderr)
        return 1
    cameras = json.loads(CAMERAS_PATH.read_text(encoding="utf-8")).get("cameras", [])
    cameras = [c for c in cameras if c.get("review", {}).get("status") == "approved"]
    approved_all = cameras
    cameras = [c for c in cameras if is_domestic_only(c) == domestic]
    if shard:
        idx, total = (int(x) for x in shard.split("/"))
        cameras = [c for i, c in enumerate(cameras) if i % total == idx]

    # 川の防災情報(kawabou)は「ツール等による定期的なデータ収集はお控えください」と
    # 明記されているため、30分ごとの全数チェックはせず1日4回の枠でのみ確認する
    # (規約: https://www.river.go.jp/kawabou/kwb_apend/html/caution.html 2026-08-31確認)
    cameras = [c for c in cameras if not _skip_low_freq(c, datetime.now(timezone.utc))]

    state_all: dict = {}
    if state_path.exists():
        state_all = json.loads(state_path.read_text(encoding="utf-8"))

    # 既存statusを読み、今回チェックしない群（シャード外）の結果を保持する
    statuses: dict = {}
    if status_path.exists():
        statuses = json.loads(status_path.read_text(encoding="utf-8")).get("statuses", {})

    throttle = HostThrottle()
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    mount_legacy_tls(session)   # 山口県土木防災(弱いDH鍵)向け
    lock = threading.Lock()

    # 都度解決型feed（mlit_roadinfo）: 解決元ページ1枚で整備局分の最新URLが取れるので、
    # シャード外のカメラも含めて毎回解決し、status.json の image_url を新鮮に保つ
    all_cameras = json.loads(CAMERAS_PATH.read_text(encoding="utf-8")).get("cameras", [])
    all_cameras = [c for c in all_cameras if is_domestic_only(c) == domestic]
    roadinfo_cams = [c for c in all_cameras
                     if c.get("review", {}).get("status") == "approved"
                     and c["feed"]["type"] == "mlit_roadinfo"]
    if roadinfo_cams:
        from crawler.sources.mlit_roadinfo import large_image_url, resolve_image_urls
        resolved: dict[str, tuple[str, str]] = {}
        for page_url in sorted({c["feed"]["url"] for c in roadinfo_cams}):
            try:
                throttle.acquire(urlparse(page_url).netloc)
                try:
                    resp = session.get(page_url, timeout=30)
                finally:
                    throttle.release(urlparse(page_url).netloc)
                if resp.status_code == 200:
                    resolved.update(resolve_image_urls(resp.text))
            except requests.RequestException as e:
                print(f"roadinfo解決失敗 {page_url}: {e}", file=sys.stderr)
        for cam in roadinfo_cams:
            hit = resolved.get(cam["feed"].get("camera_ref") or "")
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
            # シャード外でも最新URLだけは配信する（チェック自体はシャード担当回で行う)
            if hit:
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                # 詳細は原寸、一覧は縮小版（確認は縮小版で行う。プレースホルダの dHash は縮小版のもの）
                st["image_url"], st["image_time"] = large_image_url(hit[0]), hit[1]
                st["thumb_url"] = hit[0]
        # cameras(シャード抽出済み)のdictはall_camerasと別オブジェクトなので反映する
        by_id = {c["id"]: c for c in roadinfo_cams}
        for cam in cameras:
            src = by_id.get(cam["id"])
            if src and "_resolved_image" in src:
                cam["_resolved_image"] = src["_resolved_image"]

    # 都度解決型feed（jma_volcam）: 画像は2分刻みのタイムスタンプURLで1時間分しか
    # 残らないため、シャード外も含めて毎回最新URLを解決して配信する
    volcam_cams = [c for c in all_cameras
                   if c.get("review", {}).get("status") == "approved"
                   and c["feed"]["type"] == "jma_volcam"]
    if volcam_cams:
        from crawler.sources.jma_volcam import PAGE_URL, resolve_image_url
        volcam_host = "www.data.jma.go.jp"
        volcam_by_id = {}
        for cam in volcam_cams:
            page_url = PAGE_URL.format(code=cam["feed"]["url"])
            try:
                throttle.acquire(volcam_host)
                try:
                    resp = session.get(page_url, timeout=30)
                finally:
                    throttle.release(volcam_host)
            except requests.RequestException as e:
                print(f"volcam解決失敗 {page_url}: {e}", file=sys.stderr)
                continue
            hit = resolve_image_url(resp.text) if resp.status_code == 200 else None
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                volcam_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in volcam_by_id:
                cam["_resolved_image"] = volcam_by_id[cam["id"]]

    # 都度解決型feed（thr_camxml / camidx_latest）: 参照ファイルから最新画像名を解決する
    ref_cams = [c for c in all_cameras
                if c.get("review", {}).get("status") == "approved"
                and c["feed"]["type"] in ("thr_camxml", "camidx_latest", "kochi_suibo", "sizenken", "yachiyo_kansen")
                and urlparse(c["feed"]["url"]).netloc != MIYAGI_KASEN_HOST]
    if ref_cams:
        from crawler.sources.kochi_suibo import resolve_image_url as kochi_resolve
        from crawler.sources.sizenken import resolve_image_url as sizenken_resolve
        from crawler.sources.yachiyo_kansen import resolve_image_url as yachiyo_resolve
        from crawler.sources.thr_camxml import (resolve_camidx_url,
                                                resolve_image_url as thr_resolve)
        ref_by_id = {}
        for cam in ref_cams:
            ref_url = cam["feed"]["url"]
            host = urlparse(ref_url).netloc
            try:
                throttle.acquire(host)
                try:
                    resp = session.get(ref_url, timeout=30)
                finally:
                    throttle.release(host)
            except requests.RequestException as e:
                print(f"都度解決失敗 {ref_url}: {e}", file=sys.stderr)
                continue
            if resp.status_code != 200:
                continue
            if cam["feed"]["type"] == "thr_camxml":
                hit = thr_resolve(ref_url, resp.text)
            elif cam["feed"]["type"] == "kochi_suibo":
                hit = kochi_resolve(ref_url, resp.text)
            elif cam["feed"]["type"] == "sizenken":
                hit = sizenken_resolve(ref_url, resp.text)
            elif cam["feed"]["type"] == "yachiyo_kansen":
                hit = yachiyo_resolve(ref_url, resp.text)
            else:
                hit = resolve_camidx_url(ref_url, resp.text)
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                ref_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in ref_by_id:
                cam["_resolved_image"] = ref_by_id[cam["id"]]

    # 都度解決型feed（宮城県 河川カメラ）: 撮影時刻は全台共通なので、1 台分だけ問い合わせて
    # 残りは同じ時刻で組み立てる。問い合わせに失敗した回は前回の image_url を保つ
    mk_cams = [c for c in all_cameras
               if c.get("review", {}).get("status") == "approved"
               and c["feed"]["type"] == "camidx_latest"
               and urlparse(c["feed"]["url"]).netloc == MIYAGI_KASEN_HOST
               and c["feed"].get("camera_ref")]
    if mk_cams:
        from crawler.sources import miyagi_kasen
        hit = None
        for probe in mk_cams[:3]:     # 先頭の台が止まっていても次の台で試す
            pid = probe["feed"]["url"].rsplit("=", 1)[-1]
            try:
                throttle.acquire(MIYAGI_KASEN_HOST)
                try:
                    resp = session.post(miyagi_kasen.RESOLVE_URL,
                                        data=miyagi_kasen.resolve_form(pid), timeout=30)
                finally:
                    throttle.release(MIYAGI_KASEN_HOST)
            except requests.RequestException as e:
                print(f"宮城県 河川カメラの解決失敗: {e}", file=sys.stderr)
                continue
            hit = miyagi_kasen.resolve_stamp(resp.text) if resp.status_code == 200 else None
            if hit:
                break
        if hit:
            mk_by_id = {}
            for cam in mk_cams:
                url = miyagi_kasen.image_url(cam["feed"]["camera_ref"], hit[0])
                cam["_resolved_image"] = {"url": url, "time": hit[1]}
                mk_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = url, hit[1]
            for cam in cameras:
                if cam["id"] in mk_by_id:
                    cam["_resolved_image"] = mk_by_id[cam["id"]]

    # 都度解決型feed（roundshot）: 固定入口の302 Location から最新の _half.jpg を解決する。
    # 解決に失敗した回は前回の image_url を保つ（status.json に残っている分で確認を続ける）
    rs_cams = [c for c in all_cameras
               if c.get("review", {}).get("status") == "approved"
               and c["feed"]["type"] == "roundshot"]
    if rs_cams:
        from crawler.sources.roundshot import resolve_image_url as rs_resolve
        rs_by_id = {}
        for cam in rs_cams:
            entry = cam["feed"]["url"]
            host = urlparse(entry).netloc
            hit = None
            try:
                throttle.acquire(host)
                try:
                    hit = rs_resolve(session, entry)
                finally:
                    throttle.release(host)
            except requests.RequestException as e:
                print(f"roundshot解決失敗 {entry}: {e}", file=sys.stderr)
            st = statuses.setdefault(cam["id"], {
                "state": "unknown", "last_ok_at": None,
                "http_status": None, "frozen_since": None,
                "consecutive_failures": 0, "avg_interval_sec": None,
            })
            if hit:
                st["image_url"], st["image_time"] = hit
            elif st.get("image_url"):
                hit = (st["image_url"], st.get("image_time"))
            if hit:
                rs_by_id[cam["id"]] = {"url": hit[0], "time": hit[1]}
        for cam in cameras:
            if cam["id"] in rs_by_id:
                cam["_resolved_image"] = rs_by_id[cam["id"]]

    # 都度解決型feed（saitama_flood / takashima_river / higashiomi_river / shimane_suibo）:
    # 一覧JSON 1リクエストで全台解決（feed.url が一覧、camera_ref がキー）
    from crawler.sources.fukuoka_kasen import resolve_image_urls as fk_resolve
    from crawler.sources.higashiomi_river import resolve_image_urls as ho_resolve
    from crawler.sources.saitama_flood import resolve_image_urls as st_resolve
    from crawler.sources.shimane_suibo import resolve_image_urls as sn_resolve
    from crawler.sources.takashima_river import resolve_image_urls as tk_resolve
    bulk_resolvers = {
        "saitama_flood": st_resolve,
        "takashima_river": tk_resolve,
        "higashiomi_river": ho_resolve,
        "fukuoka_kasen": fk_resolve,
        "shimane_suibo": sn_resolve,
    }
    for ftype, resolver in bulk_resolvers.items():
        bulk_cams = [c for c in all_cameras
                     if c.get("review", {}).get("status") == "approved"
                     and c["feed"]["type"] == ftype]
        if not bulk_cams:
            continue
        bulk_map: dict[str, tuple[str, str]] = {}
        latest_url = bulk_cams[0]["feed"]["url"]
        host = urlparse(latest_url).netloc
        try:
            throttle.acquire(host)
            try:
                resp = session.get(latest_url, timeout=30)
            finally:
                throttle.release(host)
            if resp.status_code == 200:
                bulk_map = resolver(resp.text)
        except requests.RequestException as e:
            print(f"{ftype}解決失敗 {latest_url}: {e}", file=sys.stderr)
        bulk_by_id = {}
        for cam in bulk_cams:
            hit = bulk_map.get(cam["feed"].get("camera_ref") or "")
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                bulk_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in bulk_by_id:
                cam["_resolved_image"] = bulk_by_id[cam["id"]]

    # 都度解決型feed（shimanto_kasen）: result_time.php に POST point=pointN で最新時刻(12桁)を取る
    shimanto_cams = [c for c in all_cameras
                     if c.get("review", {}).get("status") == "approved"
                     and c["feed"]["type"] == "shimanto_kasen"]
    if shimanto_cams:
        from crawler.sources.shimanto_kasen import resolve_image_url as sm_resolve
        sm_by_id = {}
        for cam in shimanto_cams:
            result_url = cam["feed"]["url"]
            ref = cam["feed"].get("camera_ref") or ""
            host = urlparse(result_url).netloc
            try:
                throttle.acquire(host)
                try:
                    resp = session.post(result_url, data={"point": ref}, timeout=30)
                finally:
                    throttle.release(host)
            except requests.RequestException as e:
                print(f"shimanto解決失敗 {ref}: {e}", file=sys.stderr)
                continue
            if resp.status_code != 200:
                continue
            hit = sm_resolve(result_url, ref, resp.text)
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                sm_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in sm_by_id:
                cam["_resolved_image"] = sm_by_id[cam["id"]]

    # 都度解決型feed（yamaguchi_romen / yamaguchi_kasen）: 一覧ページ(HTML)1枚で全台を解決
    # （feed.url が一覧ページ、camera_ref がキー。resolver(html, page_url) を呼ぶ）
    from crawler.sources.yamaguchi_kasen import resolve_image_urls as kasen_resolve
    from crawler.sources.yamaguchi_romen import resolve_image_urls as romen_resolve
    page_resolvers = {
        "yamaguchi_romen": romen_resolve,
        "yamaguchi_kasen": kasen_resolve,
    }
    for ftype, resolver in page_resolvers.items():
        page_cams = [c for c in all_cameras
                     if c.get("review", {}).get("status") == "approved"
                     and c["feed"]["type"] == ftype]
        if not page_cams:
            continue
        page_map: dict[str, tuple[str, str]] = {}
        for page_url in sorted({c["feed"]["url"] for c in page_cams}):
            host = urlparse(page_url).netloc
            try:
                throttle.acquire(host)
                try:
                    resp = session.get(page_url, timeout=30)
                finally:
                    throttle.release(host)
                if resp.status_code == 200:
                    page_map.update(resolver(resp.text, page_url))
            except requests.RequestException as e:
                print(f"{ftype}解決失敗 {page_url}: {e}", file=sys.stderr)
        page_by_id = {}
        for cam in page_cams:
            hit = page_map.get(cam["feed"].get("camera_ref") or "")
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                page_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.setdefault(cam["id"], {
                    "state": "unknown", "last_ok_at": None,
                    "http_status": None, "frozen_since": None,
                    "consecutive_failures": 0, "avg_interval_sec": None,
                })
                st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in page_by_id:
                cam["_resolved_image"] = page_by_id[cam["id"]]

    # 都度解決型feed（mie_douro）: camera_get_api.php 1リクエストで全台のbase64画像を取得
    mie_cams = [c for c in all_cameras
                if c.get("review", {}).get("status") == "approved"
                and c["feed"]["type"] == "mie_douro"]
    if mie_cams:
        import base64
        api_url = mie_cams[0]["feed"]["url"]
        host = urlparse(api_url).netloc
        payload = {}
        try:
            throttle.acquire(host)
            try:
                resp = session.get(api_url, timeout=30)
            finally:
                throttle.release(host)
            if resp.status_code == 200:
                payload = resp.json()
        except (requests.RequestException, ValueError) as e:
            print(f"mie_douro解決失敗 {api_url}: {e}", file=sys.stderr)
        mie_by_id = {}
        for cam in mie_cams:
            ent = payload.get(cam["feed"].get("camera_ref") or "")
            if not isinstance(ent, dict):
                continue
            pic = ent.get("picture") or ""
            if "base64," in pic:
                try:
                    raw = base64.b64decode(pic.split("base64,", 1)[1])
                except Exception:
                    continue
                mie_by_id[cam["id"]] = (raw, ent.get("date"))
                cam["_mie_bytes"], cam["_mie_time"] = raw, ent.get("date")
        for cam in cameras:
            if cam["id"] in mie_by_id:
                cam["_mie_bytes"], cam["_mie_time"] = mie_by_id[cam["id"]]

    # 都度解決型feed（sakura_bosaicam）: wholemap.json 1リクエストで全台のbase64画像（mie_douro と同じ扱い）
    sakura_cams = [c for c in all_cameras
                   if c.get("review", {}).get("status") == "approved"
                   and c["feed"]["type"] == "sakura_bosaicam"]
    if sakura_cams:
        from crawler.sources.sakura_bosaicam import resolve_images as sakura_resolve
        api_url = sakura_cams[0]["feed"]["url"]
        host = urlparse(api_url).netloc
        imgs: dict = {}
        try:
            throttle.acquire(host)
            try:
                resp = session.get(api_url, timeout=30)
            finally:
                throttle.release(host)
            if resp.status_code == 200:
                imgs = sakura_resolve(resp.json())
        except (requests.RequestException, ValueError) as e:
            print(f"sakura_bosaicam解決失敗 {api_url}: {e}", file=sys.stderr)
        sakura_by_id = {}
        for cam in sakura_cams:
            hit = imgs.get(str(cam["feed"].get("camera_ref") or ""))
            if hit:
                sakura_by_id[cam["id"]] = hit
                cam["_mie_bytes"], cam["_mie_time"] = hit
        for cam in cameras:
            if cam["id"] in sakura_by_id:
                cam["_mie_bytes"], cam["_mie_time"] = sakura_by_id[cam["id"]]

    video_checked: list[str] = []   # この回に確認した youtube_video
    oembed_empty: list[str] = []    # うち、oEmbed が題名もチャンネルも返さなかったもの

    def work(camera: dict):
        host = monitor_host(camera)
        throttle.acquire(host)
        try:
            st = state_all.get(camera["id"], {})
            result = check_camera(session, camera, st)
        finally:
            throttle.release(host)
        with lock:
            if camera["feed"]["type"] == "youtube_video":
                video_checked.append(camera["id"])
            if result.pop("_oembed_empty", False):
                oembed_empty.append(camera["id"])
            state_all[camera["id"]] = st
            statuses[camera["id"]] = carry_live_fields(statuses.get(camera["id"]), result)

    threads: list[threading.Thread] = []
    max_workers = 8                      # 全体の同時実行（ホスト別制限は throttle が担保）
    sem = threading.Semaphore(max_workers)

    skipped = 0

    def bounded(camera):
        nonlocal skipped
        with sem:
            if time.monotonic() > deadline:
                with lock:
                    skipped += 1
                return
            work(camera)

    # 時間がかかる川の防災情報（1日4回の枠でだけ入る）は後ろに回し、予算切れの影響を
    # そちらに寄せる（次の枠で確認される）
    cameras = sorted(cameras, key=lambda c: _is_low_freq(c))
    for cam in cameras:
        t = threading.Thread(target=bounded, args=(cam,), daemon=True)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

    applied = apply_oembed_empty(statuses, state_all, oembed_empty, len(video_checked))
    if oembed_empty:
        print(f"youtube_video {len(video_checked)} 台のうち oEmbed に題名が無い {len(oembed_empty)} 台"
              + ("を配信終了として数えた" if applied else "は割合が高すぎるので判定を見送った"),
              file=sys.stderr)

    # youtube_channel: いまの配信の動画IDを毎回解決して status.json の video_id で配信する。
    # アプリはこれがあれば動画IDで埋め込む（live_stream?channel= は再生できないことがある）。
    # 配信の切り替わりに追従するため、シャード外も含めて全台を毎回解決する（2026-09-29）
    if skipped:
        print(f"時間予算 {BUDGET_SEC}s を超えたため {skipped} 台の確認を次回に回した", file=sys.stderr)
    channel_cams = channel_resolution_order(
        [c for c in all_cameras
         if c.get("review", {}).get("status") == "approved"
         and c["feed"]["type"] == "youtube_channel"],
        state_all)
    channel_deadline = deadline + CHANNEL_EXTRA_SEC
    resolved_channels = 0
    cut_channels = 0

    def resolve_channel(cam: dict, pages: dict[str, str | None]) -> None:
        nonlocal resolved_channels, cut_channels
        if time.monotonic() > channel_deadline:
            with lock:
                cut_channels += 1
            return
        # 配信中の判定は /streams のライブ印が確実（/live は放置された古い予定枠や
        # 切り替え前の枠を指すことがある）。/streams で見つからないときだけ /live を見る
        vid = None
        base = f"https://www.youtube.com/channel/{cam['feed']['url']}"
        with lock:
            prev_vid = (statuses.get(cam["id"]) or {}).get("video_id")
        live_match = cam["feed"].get("live_match") or None

        def _from_streams(text: str) -> str | None:
            return pick_live_stream(list_live_in_streams(text), cam["name"], prev_vid, live_match)

        # live_match 付き（複数配信チャンネル）は /live の後詰めをしない: /live は題名を返さず
        # 別拠点の枠を指しうる。/streams に該当が無ければ配信休止として扱う
        resolvers = [("/streams", _from_streams)]
        if not live_match:
            resolvers.append(("/live", resolve_youtube_channel_live))
        for path, resolver in resolvers:
            # 同じチャンネルの別のカメラが取ったページを使い回す（pages はチャンネルごと）
            if path not in pages:
                pages[path] = None
                try:
                    throttle.acquire("www.youtube.com")
                    try:
                        resp = session.get(base + path, timeout=30, headers={"Accept-Language": "ja"})
                    finally:
                        throttle.release("www.youtube.com")
                    if resp.status_code == 200:
                        pages[path] = resp.text
                except requests.RequestException as e:
                    print(f"youtube_channel解決失敗 {base}{path}: {e}", file=sys.stderr)
            text = pages[path]
            if text is not None:
                vid = resolver(text)
            if vid:
                break
        with lock:
            resolved_channels += 1
            st = statuses.setdefault(cam["id"], {
                "state": "unknown", "last_ok_at": None,
                "http_status": None, "frozen_since": None,
                "consecutive_failures": 0, "avg_interval_sec": None,
            })
            if vid:
                st["video_id"] = vid
                st["live"] = True
            else:
                # 配信なし（営業時間外・季節休止など）。アプリは埋め込みの代わりに
                # 「配信休止中」を出す（古い予定枠の待機画面を見せない）
                st.pop("video_id", None)
                st["live"] = False
            state_all.setdefault(cam["id"], {})["live_resolved_at"] = (
                datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))

    # youtube.com は throttle が同時2接続・1秒間隔を守るので、2本で回して待ち時間を重ねる
    # 同じチャンネルのカメラはまとめて解決し、ページの取得は 1 チャンネル 1 回にする
    channel_groups = group_by_channel(channel_cams)

    def resolve_groups(groups: list[list[dict]]) -> None:
        for group in groups:
            pages: dict[str, str | None] = {}
            for c in group:
                resolve_channel(c, pages)

    channel_threads = [threading.Thread(target=resolve_groups, args=(channel_groups[i::2],),
                                        daemon=True) for i in range(2)]
    for t in channel_threads:
        t.start()
    for t in channel_threads:
        t.join()
    if cut_channels:
        print(f"時間予算を超えたため youtube_channel の解決を打ち切り"
              f"（{resolved_channels}/{len(channel_cams)} 台。残りは次回、古い順に解決）",
              file=sys.stderr)
    else:
        print(f"youtube_channel {resolved_channels} 台の配信IDを解決", file=sys.stderr)

    if domestic:
        # 台帳から外れたカメラの結果を残さない
        keep = {c["id"] for c in all_cameras if c.get("review", {}).get("status") == "approved"}
        statuses = {k: v for k, v in statuses.items() if k in keep}
    else:
        # 国内限定ホストの分は国内の結果（無い・古いときは既定の扱い）に置き換える
        dom = None
        if DOMESTIC_STATUS_PATH.exists():
            dom = json.loads(DOMESTIC_STATUS_PATH.read_text(encoding="utf-8"))
        merge_domestic(statuses, approved_all, dom)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    status_path.parent.mkdir(parents=True, exist_ok=True)
    status_path.write_text(json.dumps(
        {"generated_at": now, "statuses": statuses},
        ensure_ascii=False, indent=1), encoding="utf-8")
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state_all, ensure_ascii=False), encoding="utf-8")

    counts: dict[str, int] = defaultdict(int)
    for s in statuses.values():
        counts[s["state"]] += 1
    print(f"checked {len(cameras)} cameras: {dict(counts)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="livecam-jp monitor")
    ap.add_argument("--shard", help="例 0/2 = 2分割の0番目")
    ap.add_argument("--domestic", action="store_true",
                    help="国内限定ホスト（monitor/domestic.py）だけを確認して status_domestic.json に書く")
    args = ap.parse_args()
    return run(args.shard, args.domestic)


if __name__ == "__main__":
    sys.exit(main())
