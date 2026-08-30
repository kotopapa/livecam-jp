"""hazard_check の純粋関数（ID抽出・差分・タイル座標）のテスト。ネットワークは使わない。"""

from tools import hazard_check as hc

OPENDATA_HTML = """
<h4>洪水浸水想定区域（想定最大規模）</h4>
<td>https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/{z}/{x}/{y}.png</td>
<td>https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_pref_data/13/{z}/{x}/{y}.png</td>
<td>https://disaportaldata.gsi.go.jp/raster/05_kyukeishakeikaikuiki/{z}/{x}/{y}.png</td>
<td>https://disaportaldata.gsi.go.jp/raster/05_kyukeishakeikaikuiki_data/01/{z}/{x}/{y}.png</td>
<td>https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/{z}/{x}/{y}.png</td>
"""


def test_extract_tile_ids_is_sorted_unique():
    ids = hc.extract_tile_ids(OPENDATA_HTML)
    assert ids == [
        "01_flood_l2_shinsuishin_data",
        "01_flood_l2_shinsuishin_pref_data",
        "05_kyukeishakeikaikuiki",
        "05_kyukeishakeikaikuiki_data",
    ]


def test_extract_tile_ids_empty_when_no_match():
    assert hc.extract_tile_ids("<html><body>none</body></html>") == []


def test_diff_ids():
    added, removed = hc.diff_ids(["a", "b", "c"], ["b", "c", "d"])
    assert added == ["d"]
    assert removed == ["a"]
    assert hc.diff_ids(["a"], ["a"]) == ([], [])


def test_broken_tiles_only_reports_200_to_non200():
    prev = {"x": {"10/1/1": 200, "10/2/2": 404, "12/9/9": 200}}
    curr = {"x": {"10/1/1": 404, "10/2/2": 200}}  # 12/9/9 は今回未検査
    assert hc.broken_tiles(prev, curr) == [("x", "10/1/1", 200, 404)]


def test_broken_tiles_network_error_counts_as_broken():
    prev = {"x": {"10/1/1": 200}}
    curr = {"x": {"10/1/1": 0}}
    assert hc.broken_tiles(prev, curr) == [("x", "10/1/1", 200, 0)]


def test_tile_xy_tokyo():
    # 東京駅付近 z10 → x=909,y=403（地理院タイル座標）
    assert hc.tile_xy(35.68, 139.76, 10) == (909, 403)
    assert hc.tile_url("01_flood_l2_shinsuishin_data", 10, 909, 403) == (
        "https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/10/909/403.png"
    )


def test_probe_keys_cover_all_ids_and_zooms():
    keys = hc.probe_keys()
    assert {k[0] for k in keys} == set(hc.APP_TILE_IDS)
    assert len(keys) == len(hc.APP_TILE_IDS) * len(hc.ZOOMS) * len(hc.POINTS)


def test_build_report_mentions_changes():
    r = hc.build_report(["new_id"], ["old_id"], [("x", "10/1/1", 200, 404)], "2026-09-01T00:00:00Z")
    assert "`new_id`" in r and "`old_id`" in r
    assert "| `x` | 10/1/1 | 200 | 404 |" in r
