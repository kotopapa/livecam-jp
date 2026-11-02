from monitor.main import channel_resolution_order


def test_never_resolved_first_then_oldest():
    cams = [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]
    state = {
        "a": {"live_resolved_at": "2026-11-02T03:00:00Z"},
        "b": {"live_resolved_at": "2026-11-01T22:00:00Z"},
        "c": {},
    }
    order = [c["id"] for c in channel_resolution_order(cams, state)]
    assert order == ["c", "d", "b", "a"]


def test_order_is_stable_for_ties():
    cams = [{"id": "y"}, {"id": "x"}]
    assert [c["id"] for c in channel_resolution_order(cams, {})] == ["x", "y"]
