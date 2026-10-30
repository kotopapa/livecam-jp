from tools import kawabou_snow_stations as ks


def test_snow_towns_filters_by_flag():
    twns = [{"twnCd": 102458, "snwExistFlg": 1}, {"twnCd": 102204, "snwExistFlg": 0}, {"twnCd": 1, "snwExistFlg": "1"}]
    assert ks.snow_towns(twns) == [102458, 1]
    assert ks.snow_towns({"twnList": twns}) == [102458, 1]
    assert ks.snow_towns(None) == []


def test_snow_obs_reads_obsSnow_and_skips_hidden():
    tl = {"obsList": {"obsStg": [{"obsFcd": "x"}],
                      "obsSnow": [{"obsFcd": "2329700300003", "obsNm": "旭岳", "dspFlg": 1},
                                  {"obsFcd": "2329700300004", "dspFlg": 0},
                                  {"obsNm": "idなし"}]}}
    assert ks.snow_obs(tl) == ["2329700300003"]
    assert ks.snow_obs({}) == []


def test_station_of_master():
    m = {"obsInfo": {"lat": 43.6466667, "lon": 142.795, "obsNm": "旭岳", "twnCd": 102458}}
    st = ks.station_of("2329700300003", m)
    assert st == {"id": "2329700300003", "n": "旭岳", "lat": 43.646667, "lng": 142.795}
    assert ks.station_of("x", {"obsInfo": {"lat": None, "lon": 1, "obsNm": "a"}}) is None
    assert ks.station_of("x", {"obsInfo": {"lat": 1, "lon": 1, "obsNm": ""}}) is None
