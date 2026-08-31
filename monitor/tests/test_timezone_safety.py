"""時刻処理がプロセスのタイムゾーンに依存しないことの回帰テスト。

GitHub Actions のランナーは UTC、開発機は JST で動くため、
「naive な datetime をローカルTZとして解釈する」処理が混ざると
両者で9時間ずれた結果になる（過去2件の不具合の原因）。
"""

import contextlib
import os
import time as time_mod
from datetime import datetime, timedelta, timezone

import pytest

from monitor.check import _stale_last_modified
from monitor.freeze import as_utc, is_local_daytime, judge_frozen, parse_utc
from monitor.main import _skip_low_freq

JST = timezone(timedelta(hours=9))


@contextlib.contextmanager
def process_tz(name: str):
    """プロセスのTZを一時的に切り替える（UTCランナーの再現）。"""
    old = os.environ.get("TZ")
    os.environ["TZ"] = name
    time_mod.tzset()
    try:
        yield
    finally:
        if old is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = old
        time_mod.tzset()


needs_tzset = pytest.mark.skipif(not hasattr(time_mod, "tzset"),
                                 reason="tzset がない環境")

KAWABOU_CAM = {"feed": {"url": "https://cam.river.go.jp/cam/now/104353114.jpg"},
               "source": {"page_url": "https://www.river.go.jp/kawabou/pc/tm?scamId=1"}}


def test_skip_low_freq_window_is_jst_for_any_input_tz():
    # 同一の瞬間（JST 15:30 = UTC 06:30）はどの表現でも「枠内」でなければならない。
    # 旧実装は now.hour をそのままUTC枠と比較していたため、
    # JSTで渡すと 15 が枠(18/0/6/12)に無く「枠外=スキップ」になっていた
    utc = datetime(2026, 8, 31, 6, 30, tzinfo=timezone.utc)
    assert _skip_low_freq(KAWABOU_CAM, utc) is False
    assert _skip_low_freq(KAWABOU_CAM, utc.astimezone(JST)) is False
    assert _skip_low_freq(KAWABOU_CAM, utc.replace(tzinfo=None)) is False

    out = datetime(2026, 8, 31, 7, 30, tzinfo=timezone.utc)   # JST 16:30 = 枠外
    assert _skip_low_freq(KAWABOU_CAM, out) is True
    assert _skip_low_freq(KAWABOU_CAM, out.astimezone(JST)) is True


def test_skip_low_freq_covers_all_four_jst_windows():
    for jst_hour in (3, 9, 15, 21):
        at = datetime(2026, 8, 31, jst_hour, 5, tzinfo=JST)
        assert _skip_low_freq(KAWABOU_CAM, at) is False, jst_hour
    for jst_hour in (0, 4, 10, 16, 22):
        at = datetime(2026, 8, 31, jst_hour, 5, tzinfo=JST)
        assert _skip_low_freq(KAWABOU_CAM, at) is True, jst_hour


@needs_tzset
def test_is_local_daytime_independent_of_process_timezone():
    # naive を渡してもUTC固定で解釈する（旧実装は astimezone() が
    # プロセスのローカルTZを使い、JST機とUTCランナーで結果が9時間ずれた）
    naive = datetime(2026, 8, 31, 3, 30)      # UTCとみなす → 東京(139.75)は12:39頃
    with process_tz("UTC"):
        utc_run = is_local_daytime(naive, 139.75)
    with process_tz("Asia/Tokyo"):
        jst_run = is_local_daytime(naive, 139.75)
    assert utc_run is jst_run is True


def test_is_local_daytime_uses_converted_minutes():
    # 30分オフセットのTZ(インド +05:30)で渡しても、UTC換算の分を使う
    ist = timezone(timedelta(hours=5, minutes=30))
    at = datetime(2026, 8, 31, 3, 30, tzinfo=timezone.utc)
    assert is_local_daytime(at, 139.75) is is_local_daytime(at.astimezone(ist), 139.75)


def test_as_utc_and_parse_utc_normalize():
    assert as_utc(datetime(2026, 8, 31, 3, 0)).tzinfo is timezone.utc
    assert as_utc(datetime(2026, 8, 31, 12, 0, tzinfo=JST)) == \
        datetime(2026, 8, 31, 3, 0, tzinfo=timezone.utc)
    assert parse_utc("2026-08-31T03:00:00") == parse_utc("2026-08-31T03:00:00Z")
    assert parse_utc("2026-08-31T12:00:00+09:00") == parse_utc("2026-08-31T03:00:00Z")


def _history(hours: float, n: int, end: datetime, iso=lambda d: d.isoformat()):
    return [{"at": iso(end - timedelta(hours=hours) * (n - 1 - i) / (n - 1)),
             "hash": 42} for i in range(n)]


def test_judge_frozen_accepts_naive_history_timestamps():
    # 古いstateにオフセット無しの "at" が残っていても TypeError で
    # 監視スレッドが落ちないこと（UTCとみなす）
    now = datetime(2026, 8, 17, 3, 0, tzinfo=timezone.utc)
    lat, lng = 35.68, 139.75
    aware = judge_frozen(_history(12, 24, now), now, lat, lng)
    naive = judge_frozen(
        _history(12, 24, now, iso=lambda d: d.replace(tzinfo=None).isoformat()),
        now, lat, lng)
    assert aware[0] is naive[0] is True


def test_judge_frozen_accepts_naive_now():
    now = datetime(2026, 8, 17, 3, 0, tzinfo=timezone.utc)
    frozen, _ = judge_frozen(_history(12, 24, now), now.replace(tzinfo=None),
                             35.68, 139.75)
    assert frozen is True


def test_stale_last_modified_normalizes_both_sides():
    now = datetime(2026, 8, 31, 0, 0, tzinfo=timezone.utc)
    # 7日より古い → frozen 扱いの時刻を返す
    assert _stale_last_modified("Mon, 01 Jan 2024 00:00:00 GMT", now) is not None
    # naive な now でも比較できる
    assert _stale_last_modified("Mon, 01 Jan 2024 00:00:00 GMT",
                                now.replace(tzinfo=None)) is not None
    # ローカル不明を表す "-0000"（naiveで返る）でも落ちない
    assert _stale_last_modified("Mon, 01 Jan 2024 00:00:00 -0000", now) is not None
    assert _stale_last_modified(None, now) is None
