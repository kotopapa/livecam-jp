"""review_cli / crawl_kawabou_all の日付がJST基準であることの回帰テスト。

reviewed_at・first_seen は日本の日付で記録する。UTCで動く環境（GitHub Actions
ランナーや海外のマシン）で date.today() を使うと JST 00:00〜09:00 が前日になる。
"""

import contextlib
import os
import time as time_mod
from datetime import datetime, timezone

import pytest

from tools import crawl_kawabou_all, review_cli

MODULES = [review_cli, crawl_kawabou_all]

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


@pytest.mark.parametrize("module", MODULES, ids=lambda m: m.__name__)
def test_jst_today_uses_japan_date_not_runner_date(module, monkeypatch):
    monkeypatch.setattr(module, "datetime", FixedDatetime)
    assert module.jst_today() == "2026-09-01"


@pytest.mark.skipif(not hasattr(time_mod, "tzset"), reason="tzset がない環境")
@pytest.mark.parametrize("module", MODULES, ids=lambda m: m.__name__)
def test_jst_today_independent_of_process_timezone(module):
    with process_tz("UTC"):
        utc_run = module.jst_today()
    with process_tz("America/Los_Angeles"):
        la_run = module.jst_today()
    assert utc_run == la_run == datetime.now(module.JST).date().isoformat()
