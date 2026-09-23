from tools.amedas_snow_stations import attach_municipality, snow_stations


def test_snow_stations_filter_and_coords():
    table = {
        "14163": {"type": "A", "elems": "11111111", "lat": [43, 3.6], "lon": [141, 19.7], "kjName": "札幌"},
        "91197": {"type": "A", "elems": "11111011", "lat": [26, 12.4], "lon": [127, 41.2], "kjName": "那覇"},
        "11001": {"type": "C", "elems": "11112010", "lat": [45, 31.2], "lon": [141, 56.1], "kjName": "宗谷岬"},
    }
    st = snow_stations(table)
    assert [s["id"] for s in st] == ["14163"]
    assert st[0]["n"] == "札幌" and abs(st[0]["lat"] - 43.06) < 1e-4 and abs(st[0]["lng"] - 141.3283) < 1e-4


def test_attach_municipality_uses_cache(monkeypatch):
    import tools.amedas_snow_stations as m
    monkeypatch.setattr(m, "reverse_geocode", lambda lat, lng: "01101")
    stations = [{"id": "a", "n": "A", "lat": 43.06, "lng": 141.3283}, {"id": "b", "n": "B", "lat": 26.2, "lng": 127.68}]
    cache = {"26.20000,127.68000": None}
    fetched = attach_municipality(stations, cache, sleep=0)
    assert fetched == 1
    assert stations[0]["m"] == "01101" and "m" not in stations[1]
