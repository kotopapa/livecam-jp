"""死活監視バッチのエントリポイント。

    python -m monitor.main            # cameras.json の承認済み全カメラをチェック
    python -m monitor.main --shard 0/2  # N分割巡回（カメラ数が増えたら使用）

- 同一ホストへの同時接続は2、リクエスト間隔1秒以上（SPEC 7.1）
- 出力: data/status.json、状態: monitor/.state/hashes.json（コミットする）
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import requests

try:
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

from crawler.sources.base import mount_legacy_tls
from monitor.check import USER_AGENT, check_camera

REPO_ROOT = Path(__file__).resolve().parent.parent
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"
STATUS_PATH = REPO_ROOT / "data" / "status.json"
STATE_PATH = REPO_ROOT / "monitor" / ".state" / "hashes.json"

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


def run(shard: str | None = None) -> int:
    if not CAMERAS_PATH.exists():
        print("data/cameras.json がない", file=sys.stderr)
        return 1
    cameras = json.loads(CAMERAS_PATH.read_text(encoding="utf-8")).get("cameras", [])
    cameras = [c for c in cameras if c.get("review", {}).get("status") == "approved"]
    if shard:
        idx, total = (int(x) for x in shard.split("/"))
        cameras = [c for i, c in enumerate(cameras) if i % total == idx]

    state_all: dict = {}
    if STATE_PATH.exists():
        state_all = json.loads(STATE_PATH.read_text(encoding="utf-8"))

    # 既存statusを読み、今回チェックしない群（シャード外）の結果を保持する
    statuses: dict = {}
    if STATUS_PATH.exists():
        statuses = json.loads(STATUS_PATH.read_text(encoding="utf-8")).get("statuses", {})

    throttle = HostThrottle()
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    mount_legacy_tls(session)   # 山口県土木防災(弱いDH鍵)向け
    lock = threading.Lock()

    # 都度解決型feed（mlit_roadinfo）: 解決元ページ1枚で整備局分の最新URLが取れるので、
    # シャード外のカメラも含めて毎回解決し、status.json の image_url を新鮮に保つ
    all_cameras = json.loads(CAMERAS_PATH.read_text(encoding="utf-8")).get("cameras", [])
    roadinfo_cams = [c for c in all_cameras
                     if c.get("review", {}).get("status") == "approved"
                     and c["feed"]["type"] == "mlit_roadinfo"]
    if roadinfo_cams:
        from crawler.sources.mlit_roadinfo import resolve_image_urls
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
                st["image_url"], st["image_time"] = hit
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
                and c["feed"]["type"] in ("thr_camxml", "camidx_latest", "kochi_suibo", "sizenken")]
    if ref_cams:
        from crawler.sources.kochi_suibo import resolve_image_url as kochi_resolve
        from crawler.sources.sizenken import resolve_image_url as sizenken_resolve
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

    def work(camera: dict):
        host = monitor_host(camera)
        throttle.acquire(host)
        try:
            st = state_all.get(camera["id"], {})
            result = check_camera(session, camera, st)
        finally:
            throttle.release(host)
        with lock:
            state_all[camera["id"]] = st
            statuses[camera["id"]] = result

    threads: list[threading.Thread] = []
    max_workers = 8                      # 全体の同時実行（ホスト別制限は throttle が担保）
    sem = threading.Semaphore(max_workers)

    def bounded(camera):
        with sem:
            work(camera)

    for cam in cameras:
        t = threading.Thread(target=bounded, args=(cam,), daemon=True)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATUS_PATH.write_text(json.dumps(
        {"generated_at": now, "statuses": statuses},
        ensure_ascii=False, indent=1), encoding="utf-8")
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state_all, ensure_ascii=False), encoding="utf-8")

    counts: dict[str, int] = defaultdict(int)
    for s in statuses.values():
        counts[s["state"]] += 1
    print(f"checked {len(cameras)} cameras: {dict(counts)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="livecam-jp monitor")
    ap.add_argument("--shard", help="例 0/2 = 2分割の0番目")
    args = ap.parse_args()
    return run(args.shard)


if __name__ == "__main__":
    sys.exit(main())
