"""国内限定ホストの status 合成（monitor/domestic.py）。"""

from datetime import datetime, timedelta, timezone

from monitor.domestic import is_domestic_only, merge_domestic

NOW = datetime(2026, 11, 22, 12, 0, tzinfo=timezone.utc)


def _cam(cid, url, ftype="still_image"):
    return {"id": cid, "feed": {"type": ftype, "url": url}}


GIFU = _cam("gifu-1", "https://douro.pref.gifu.lg.jp/cam/1.jpg")
FUKUOKA = _cam("fk-1", "https://doboku-bousai.pref.fukuoka.lg.jp/list", "fukuoka_kasen")
OTHER = _cam("other-1", "https://example.jp/a.jpg")
ERR = {"state": "error", "last_ok_at": "2026-10-22T00:00:00Z", "http_status": None,
       "frozen_since": None, "consecutive_failures": 99, "avg_interval_sec": 300}


def _dom(minutes_ago, statuses):
    at = (NOW - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {"generated_at": at, "statuses": statuses}


def test_is_domestic_only():
    assert is_domestic_only(GIFU)
    assert not is_domestic_only(OTHER)
    assert not is_domestic_only({"id": "yt", "feed": {"type": "youtube_channel", "url": "UCxxxx"}})


def test_without_domestic_result_direct_types_become_unknown():
    statuses = {"gifu-1": dict(ERR), "fk-1": dict(ERR), "other-1": dict(ERR)}
    merge_domestic(statuses, [GIFU, FUKUOKA, OTHER], None, NOW)
    assert statuses["gifu-1"]["state"] == "unknown"
    assert statuses["gifu-1"]["last_ok_at"] == "2026-10-22T00:00:00Z"
    assert statuses["gifu-1"]["consecutive_failures"] == 0
    # 画像 URL を監視が解決する型は、国内の結果が無ければ出さない
    assert statuses["fk-1"]["state"] == "error"
    # 国内限定でないホストには触らない
    assert statuses["other-1"] == ERR


def test_fresh_domestic_result_is_used_as_is():
    ok = {"state": "ok", "last_ok_at": "2026-11-22T11:50:00Z", "http_status": 200,
          "frozen_since": None, "consecutive_failures": 0, "avg_interval_sec": 600,
          "image_url": "https://doboku-bousai.pref.fukuoka.lg.jp/img/1.jpg",
          "image_time": "2026-11-22T20:50:00+09:00"}
    dead = dict(ERR, http_status=404)
    statuses = {"gifu-1": dict(ERR), "fk-1": dict(ERR)}
    merge_domestic(statuses, [GIFU, FUKUOKA], _dom(30, {"fk-1": ok, "gifu-1": dead}), NOW)
    assert statuses["fk-1"] == ok
    assert statuses["gifu-1"] == dead        # 国内から見ても止まっているものは隠したまま


def test_stale_domestic_result_falls_back():
    ok = {"state": "ok", "last_ok_at": "2026-11-22T05:00:00Z", "http_status": 200,
          "frozen_since": None, "consecutive_failures": 0, "avg_interval_sec": 600,
          "image_url": "https://doboku-bousai.pref.fukuoka.lg.jp/img/old.jpg"}
    gifu2 = _cam("gifu-2", "https://douro.pref.gifu.lg.jp/cam/2.jpg")
    statuses = {}
    dom = _dom(6 * 60, {"fk-1": ok, "gifu-1": dict(ok), "gifu-2": dict(ERR)})
    merge_domestic(statuses, [GIFU, gifu2, FUKUOKA], dom, NOW)
    assert statuses["gifu-1"]["state"] == "unknown"
    assert statuses["gifu-1"]["last_ok_at"] == "2026-11-22T05:00:00Z"
    assert statuses["gifu-2"]["state"] == "error"     # 国内で error と判定済みなら出さない
    assert statuses["fk-1"]["state"] == "error"       # 古い画像 URL は配らない
    assert "image_url" not in statuses["fk-1"]


def test_fresh_but_unresolved_image_stays_hidden():
    # 提供元が休止中: 国内から確認しても画像 URL が解決できない
    unresolved = {"state": "unknown", "last_ok_at": None, "http_status": None,
                  "frozen_since": None, "consecutive_failures": 1, "avg_interval_sec": None}
    statuses = {}
    merge_domestic(statuses, [FUKUOKA], _dom(10, {"fk-1": unresolved}), NOW)
    assert statuses["fk-1"]["state"] == "error"
