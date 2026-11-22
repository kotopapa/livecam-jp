"""国内からしか届かないサイトの扱い。

死活監視は GitHub Actions のランナー（海外の IP）で動く。そこからの接続だけを
タイムアウトか 403 で断るサイトがあり、国内の利用者には見えているカメラが
error（地図に出さない）になっていた（2026-11-22 の調査で 33 サイト・617 台）。

- GitHub 側の監視（python -m monitor.main）は、ここに挙げたホストのカメラを確認しない
- 国内の端末で回す監視（python -m monitor.main --domestic）が、ここに挙げたホストの
  カメラだけを確認して data/status_domestic.json に書く
- 配信する status は merge_domestic で合成する。国内の結果が新しければそれを使い、
  無い・古いときは下の「国内の結果が無いとき」の扱いにする

ホストを足す条件: そのホストの承認済みカメラが全台 error で、ランナーからは接続失敗
または 403、国内からは同じ URL で中身が取れること。一部の台だけ error のホストは
入れない（ランナーから届いている）。
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

# 2026-11-22 に国内から 1〜2 台ずつ取得して中身を確認したホスト（福岡県だけは注記のとおり）
DOMESTIC_ONLY_HOSTS = frozenset({
    "douro.pref.gifu.lg.jp",                 # 岐阜県 道路カメラ
    # 福岡県 河川カメラ。2026-11-22 時点は「システム休止中」（国内からは休止の案内ページ、
    # ランナーからは接続失敗）。再開したら国内の監視が画像 URL を解決して自動で戻る
    "doboku-bousai.pref.fukuoka.lg.jp",
    "www.douro.com",                         # 岩手県 道路カメラ
    "www.ccn-catv.co.jp",
    "www.douro.pref.mie.jp",                 # 三重県 道路カメラ
    "ttc.taxi-inf.jp",
    "omy.taxi-inf.jp",
    "webcam.mctv.jp",
    "suibo-kouho.suibou.pref.kochi.lg.jp",   # 高知県 水防
    "camserv02.heliosmate.net",
    "hce.hanshin.co.jp",
    "bousai.city.takashima.lg.jp",           # 高島市 河川
    "www.shima-net.jp",
    "www.masyuko.or.jp",
    "masyuko.or.jp",
    "gala.co.jp",
    "www.nakayamadera.or.jp",
    "www.m3.ws302.smilestart.ne.jp",
    "outemon.hirosaki-livecam.jp",
    "153.142.240.65",
    "www.iwayadam.jp",
    "www.misogawa.jp",
    "www.skbk.or.jp",
    "www.oogawara.or.jp",
    "www.rebun-island.jp",
    "hongwanji-live.securesite.jp",
    "camera.city.shibukawa.lg.jp",
    "amarube-cam.town.mikata-kami.lg.jp",
    "yadagawa-cam.town.mikata-kami.lg.jp",
    "skyvalley-cam.town.mikata-kami.lg.jp",
    "imago-cam.town.mikata-kami.lg.jp",
    "iwatechubu-eco.co.jp",
    "sanotajiri.la.coocan.jp",
})

# アプリが監視の解決した image_url でしか画像を出せない feed.type
# （app/lib/data/camera_repository.dart の imageUrlFor と揃える）。
# 国内の結果が無いと画像 URL が分からないので、未確認として出しても何も映らない
MONITOR_RESOLVED_TYPES = frozenset({
    "mlit_roadinfo", "jma_volcam", "thr_camxml", "camidx_latest", "saitama_flood",
    "kochi_suibo", "sizenken", "shimanto_kasen", "takashima_river", "higashiomi_river",
    "yamaguchi_romen", "yamaguchi_kasen", "shimane_suibo", "fukuoka_kasen",
    "yachiyo_kansen",
})

# 国内の結果をそのまま使う期限。国内の監視は 30 分おきに回す想定で、端末のスリープや
# 回線断で数回抜けても保つ。画像 URL が時刻入りの型は古い URL が消えるので長くしない
FRESH_HOURS = 3


def is_domestic_only(camera: dict) -> bool:
    url = (camera.get("feed") or {}).get("url") or ""
    return urlparse(url).netloc in DOMESTIC_ONLY_HOSTS


def _parse(ts: str | None) -> datetime | None:
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def is_fresh(domestic: dict | None, now: datetime) -> bool:
    at = _parse((domestic or {}).get("generated_at"))
    return at is not None and now - at <= timedelta(hours=FRESH_HOURS)


def merge_domestic(statuses: dict, cameras: list[dict], domestic: dict | None,
                   now: datetime | None = None) -> int:
    """国内限定ホストのカメラの status を合成する（statuses を書き換える）。変えた台数を返す。

    - 国内の結果が新しい: それをそのまま使う（監視が画像 URL を解決する型で image_url が
      無いものだけは error にする）
    - 国内の結果が無い・古い:
        - 国内で error と判定済みのものは error のまま（止まっているカメラを出さない）
        - 直接表示できる型（still_image・mie_douro・web_page など）は unknown（地図に出す）
        - 監視が画像 URL を解決する型は error（画像 URL が無く、出しても映らない）
    """
    now = now or datetime.now(timezone.utc)
    dom_statuses = (domestic or {}).get("statuses") or {}
    fresh = is_fresh(domestic, now)
    changed = 0
    for cam in cameras:
        if not is_domestic_only(cam):
            continue
        cid = cam["id"]
        dom = dom_statuses.get(cid)
        resolved_type = cam["feed"]["type"] in MONITOR_RESOLVED_TYPES
        if fresh and dom:
            new = dict(dom)
            if resolved_type and not new.get("image_url"):
                # 画像 URL を解決できていない（提供元の休止など）。出しても映らない
                new["state"] = "error"
        else:
            prev = dom or statuses.get(cid) or {}
            dead = bool(dom) and dom.get("state") == "error"
            new = {
                "state": "error" if (dead or resolved_type) else "unknown",
                "last_ok_at": prev.get("last_ok_at"),
                "http_status": None,
                "frozen_since": None,
                "consecutive_failures": 0,
                "avg_interval_sec": prev.get("avg_interval_sec"),
            }
        if statuses.get(cid) != new:
            changed += 1
        statuses[cid] = new
    return changed
