from tools.fill_municipality import cache_key, targets


def _cam(**kw):
    base = {
        "id": "x", "name": "x", "prefecture": "19", "lat": 35.5, "lng": 138.7,
        "coord_accuracy": "approx", "municipality": None,
        "review": {"status": "approved"},
    }
    base.update(kw)
    return base


def test_targets_selects_only_domestic_approved_without_municipality():
    cams = [
        _cam(id="ok"),
        _cam(id="has", municipality="19430"),
        _cam(id="world", prefecture="99"),
        _cam(id="rejected", review={"status": "rejected"}),
        _cam(id="nocoord", lat=None, lng=None),
        _cam(id="area", coord_accuracy="area"),
    ]
    assert [c["id"] for c in targets(cams)] == ["ok"]


def test_cache_key_rounds_to_5_decimals():
    assert cache_key(35.503612345, 138.7648) == "35.50361,138.76480"
