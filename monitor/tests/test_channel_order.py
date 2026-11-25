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
