from tools.aggregate_ranking import pending_days


def test_pending_days_normal_is_yesterday_only():
    state = {"confirmed_through": "20261101"}
    assert pending_days(state, "20261103") == ["20261102"]


def test_pending_days_backlog_from_last_recorded_day():
    state = {"cameras": {"a": {"total": 1, "days": {"20261011": 1, "20261012": 1}}}}
    assert pending_days(state, "20261016") == ["20261013", "20261014", "20261015"]


def test_pending_days_empty_state_is_yesterday():
    assert pending_days({}, "20261103") == ["20261102"]


def test_pending_days_capped():
    state = {"confirmed_through": "20250101"}
    days = pending_days(state, "20261103", max_days=3)
    assert days == ["20261031", "20261101", "20261102"]


def test_pending_days_nothing_when_already_confirmed():
    assert pending_days({"confirmed_through": "20261102"}, "20261103") == []
