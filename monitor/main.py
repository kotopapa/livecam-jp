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
            st = statuses.get(cam["id"])
            if hit and st is not None:
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
                st = statuses.get(cam["id"])
                if st is not None:
                    st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in volcam_by_id:
                cam["_resolved_image"] = volcam_by_id[cam["id"]]

    # 都度解決型feed（thr_camxml）: 東北地整のCamera XMLから最新画像名を解決する
    thr_cams = [c for c in all_cameras
                if c.get("review", {}).get("status") == "approved"
                and c["feed"]["type"] == "thr_camxml"]
    if thr_cams:
        from crawler.sources.thr_camxml import resolve_image_url as thr_resolve
        thr_by_id = {}
        for cam in thr_cams:
            xml_url = cam["feed"]["url"]
            host = urlparse(xml_url).netloc
            try:
                throttle.acquire(host)
                try:
                    resp = session.get(xml_url, timeout=30)
                finally:
                    throttle.release(host)
            except requests.RequestException as e:
                print(f"thr_camxml解決失敗 {xml_url}: {e}", file=sys.stderr)
                continue
            hit = thr_resolve(xml_url, resp.text) if resp.status_code == 200 else None
            if hit:
                cam["_resolved_image"] = {"url": hit[0], "time": hit[1]}
                thr_by_id[cam["id"]] = cam["_resolved_image"]
                st = statuses.get(cam["id"])
                if st is not None:
                    st["image_url"], st["image_time"] = hit
        for cam in cameras:
            if cam["id"] in thr_by_id:
                cam["_resolved_image"] = thr_by_id[cam["id"]]

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
