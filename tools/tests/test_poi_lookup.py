"""tools/poi_lookup.py のテスト。ネットワークには出ない（_get_json を差し替える）"""
import json
from pathlib import Path

import pytest

from tools import poi_lookup as pl

FIX = Path(__file__).parent / "fixtures"
SEARCH = json.loads((FIX / "openpoi_search_tokyo.json").read_text(encoding="utf-8"))
SUGGEST = json.loads((FIX / "openpoi_suggest_tokyo.json").read_text(encoding="utf-8"))


@pytest.fixture
def net(monkeypatch, tmp_path):
    """OpenPOI は fixture、逆ジオコーダは座標の経度で県を切り替える偽物"""
    monkeypatch.setattr(pl, "CACHE_PATH", tmp_path / "poi_cache.json")
    monkeypatch.setattr(pl, "_cache", None)
    monkeypatch.setattr(pl, "INTERVAL", 0)
    calls = []

    def fake(url, params):
        calls.append((url, dict(params)))
        if url.endswith("/search"):
            return SEARCH
        if url.endswith("/suggest"):
            return SUGGEST
        if url == pl.GSI_REVERSE:
            lon = float(params["lon"])
            return {"results": {"muniCd": "13101" if lon > 139.7 else "27100"}}
        if url == pl.GSI_SEARCH:
            return [{"geometry": {"coordinates": [133.0466, 35.4561]},
                     "properties": {"title": "嫁ヶ島", "addressCode": "32201"}}]
        raise AssertionError(url)

    monkeypatch.setattr(pl, "_get_json", fake)
    return calls


def test_normalize(net):
    r = pl.openpoi_search("東京駅")
    assert r and set(r[0]) >= {"name", "lat", "lng", "category", "address", "source",
                               "licenses", "attributions", "raw_id"}
    assert isinstance(r[0]["licenses"], list) and isinstance(r[0]["attributions"], list)
    assert len(r) <= pl.KEEP


def test_suggest_normalized(net):
    r = pl.openpoi_suggest("東京駅")
    assert r[0]["name"] == "東京駅" and r[0]["licenses"]


def test_center_param_is_lng_lat(net):
    pl.openpoi_search("東京駅", center=(35.0, 139.0), radius_m=500)
    p = net[0][1]
    assert p["center"] == "139.0,35.0" and p["radius"] == 500


def test_pref_filter(net):
    ok = pl.resolve_camera_point("東京駅", "13")
    assert ok and all(c["muni"].startswith("13") and c["accuracy"] == "approx" for c in ok)
    assert all(c["method"] == "openpoi" and c["attributions"] for c in ok)
    assert ok[0]["name"] == "東京駅"  # 名称一致が先
    # 違う県で絞ると OpenPOI 候補は残らず、地理院へ回る（県も合わなければ空）
    assert pl.resolve_camera_point("東京駅", "27") == [] or all(
        c["method"] == "gsi" for c in pl.resolve_camera_point("東京駅", "27"))


def test_muni_filter(net):
    assert pl.resolve_camera_point("東京駅", "13", muni="13101")
    assert not [c for c in pl.resolve_camera_point("東京駅", "13", muni="13102") if c["method"] == "openpoi"]


def test_gsi_fallback(net):
    # OpenPOI の候補が全て県違いなら地理院に回る
    res = pl.resolve_camera_point("嫁ヶ島", "32")
    assert res and res[0]["method"] == "gsi" and res[0]["accuracy"] == "approx"


def test_cache_reused(net):
    pl.openpoi_search("東京駅")
    n = len(net)
    pl.openpoi_search("東京駅")
    assert len(net) == n
    pl.save_cache()
    data = json.loads(pl.CACHE_PATH.read_text(encoding="utf-8"))
    assert data["openpoi:search:東京駅|None|None|None|10"]["fetched"]
    # 再読込しても再取得しない
    pl._cache = None
    pl.openpoi_search("東京駅")
    assert len(net) == n


def test_sorted_by_distance_when_same_name(net):
    near = (35.6827, 139.7667)
    res = pl.resolve_camera_point("東京駅", "13", near=near)
    ranks = [(pl._name_rank("東京駅", c["name"]),
              round(pl.distance_m(near, (c["lat"], c["lng"])))) for c in res]
    assert ranks == sorted(ranks)
