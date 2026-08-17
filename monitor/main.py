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
