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


def test_carry_live_fields_keeps_resolved_video():
    from monitor.main import carry_live_fields
    prev = {"state": "ok", "video_id": "MtGWlABeo5k", "live": True}
    assert carry_live_fields(prev, {"state": "ok"}) == {
        "state": "ok", "video_id": "MtGWlABeo5k", "live": True}
    # 配信なしの判定（live=False・video_id 無し）も保つ
    assert carry_live_fields({"state": "ok", "live": False}, {"state": "error"}) == {
        "state": "error", "live": False}
    # 前回が無い・確認の結果が自分で値を持つときはそのまま
    assert carry_live_fields(None, {"state": "ok"}) == {"state": "ok"}
    assert carry_live_fields(prev, {"state": "ok", "video_id": "new"})["video_id"] == "new"


def test_group_by_channel_keeps_oldest_first_order():
    from monitor.main import group_by_channel
    cams = [
        {"id": "a", "feed": {"url": "CH1"}},
        {"id": "b", "feed": {"url": "CH2"}},
        {"id": "c", "feed": {"url": "CH1"}},
    ]
    assert [[c["id"] for c in g] for g in group_by_channel(cams)] == [["a", "c"], ["b"]]


def test_apply_oembed_empty_counts_failures_and_hides_after_three():
    from monitor.main import apply_oembed_empty
    statuses = {"a": {"state": "unknown", "consecutive_failures": 0}}
    state = {"a": {"consecutive_failures": 0}}
    for expected in ("unknown", "unknown", "error"):
        assert apply_oembed_empty(statuses, state, ["a"], 200) is True
        assert statuses["a"]["state"] == expected
    assert state["a"]["consecutive_failures"] == 3


def test_apply_oembed_empty_skips_when_too_many():
    """題名なしが多すぎる回は YouTube 側の応答の変化とみなし、何も変えない"""
    from monitor.main import apply_oembed_empty
    ids = [f"c{i}" for i in range(40)]
    statuses = {i: {"state": "unknown", "consecutive_failures": 0} for i in ids}
    state: dict = {}
    assert apply_oembed_empty(statuses, state, ids, 200) is False
    assert state == {} and all(s["consecutive_failures"] == 0 for s in statuses.values())
    # 少数（10 台まで）は母数が小さくても数える
    assert apply_oembed_empty(statuses, state, ids[:10], 20) is True
