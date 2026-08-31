"""台帳の日付（first_seen / last_updated）がJST基準であることの回帰テスト。

GitHub Actions のランナーは UTC で動くため、date.today() を使うと
JST 00:00〜09:00 の実行が前日の日付になる。
"""

import contextlib
import os
import time as time_mod
from datetime import date, datetime, timezone

import pytest

from crawler import main as crawler_main

# UTC 2026-08-31 20:30 = JST 2026-09-01 05:30（UTC日付とJST日付が食い違う瞬間）
FIXED_UTC = datetime(2026, 8, 31, 20, 30, tzinfo=timezone.utc)


class FixedDatetime(datetime):
    @classmethod
    def now(cls, tz=None):
        if tz is None:
            return FIXED_UTC.replace(tzinfo=None)
        return FIXED_UTC.astimezone(tz)


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


def test_jst_today_uses_japan_date_not_runner_date(monkeypatch):
    monkeypatch.setattr(crawler_main, "datetime", FixedDatetime)
    assert crawler_main.jst_today() == "2026-09-01"
    # UTC日付（旧実装の date.today() 相当）とは別日であることを確認
    assert FIXED_UTC.date().isoformat() == "2026-08-31"


@needs_tzset
def test_jst_today_independent_of_process_timezone():
    with process_tz("UTC"):
        utc_run = crawler_main.jst_today()
    with process_tz("Asia/Tokyo"):
        jst_run = crawler_main.jst_today()
    with process_tz("America/Los_Angeles"):
        la_run = crawler_main.jst_today()
    assert utc_run == jst_run == la_run
    assert utc_run == datetime.now(crawler_main.JST).date().isoformat()


@needs_tzset
def test_jst_today_matches_local_date_on_a_japanese_machine():
    # 日本のマシンでは従来の date.today() と一致し続ける（挙動を変えない）
    with process_tz("Asia/Tokyo"):
        assert crawler_main.jst_today() == date.today().isoformat()
