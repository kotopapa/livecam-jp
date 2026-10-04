"""tools/water_stations.py の対応付け規則。"""
from tools.water_stations import match_cameras, scam_id_of, levels_of


def _cam(cid, scam, lat, lng, twn):
    return {"id": cid, "lat": lat, "lng": lng, "_twnCd": twn,
            "feed": {"url": f"https://cam.river.go.jp/cam/now/{scam}.jpg"}}


def test_scam_id_of():
    assert scam_id_of({"feed": {"url": "https://cam.river.go.jp/cam/now/102305001.jpg"}}) == 102305001
    assert scam_id_of({"feed": {"url": "https://cam.river.go.jp/cam/now/cctv_090000_31C04212.jpg"}}) is None
    assert scam_id_of({"feed": {"url": "https://example.jp/a.jpg"}}) is None


def test_match_rules():
    town_lists = {
        901201: {"obsList": {
            "scam": [{"scamId": 102305001, "rvrCd": 83028377}, {"scamId": 102305023, "rvrCd": 83028269},
                     {"scamId": 102305099, "rvrCd": 83028269}],
            "cctv": [],
            "obsStg": [{"obsFcd": "A", "rvrCd": 83028269}, {"obsFcd": "B", "rvrCd": 83028269},
                       {"obsFcd": "C", "rvrCd": 83028377}],
        }},
    }
    masters = {
        "A": {"lat": 36.5500, "lon": 139.8800, "scamId": None},
        "B": {"lat": 36.5600, "lon": 139.8800, "scamId": 102305023},   # 併設（カメラ 023）
        "C": {"lat": 36.9000, "lon": 139.8800, "scamId": None},         # 同じ川だが 30km 以上離れている
    }
    cams = [
        _cam("k-023", 102305023, 36.5601, 139.8801, 901201),   # 併設 → B
        _cam("k-099", 102305099, 36.5510, 139.8805, 901201),   # 同じ川の最寄り → A（B は 1km）
        _cam("k-001", 102305001, 36.5000, 139.8800, 901201),   # 同じ川の C が遠すぎる → 無し
        _cam("k-none", 102305777, 36.5, 139.8, 901201),        # 一覧に無い
    ]
    out = match_cameras(cams, town_lists, masters)
    assert out["k-023"]["obs"] == "B" and out["k-023"]["dist_m"] < 20
    assert out["k-099"]["obs"] == "A" and out["k-099"]["dist_m"] < 200
    assert "k-001" not in out and "k-none" not in out


def test_levels_of():
    st = {"rsrvStg": 1.4, "warnStg": 2, "spclWarnStg": None, "dngStg": 3.7, "fldStg": 4.6}
    assert levels_of(st) == {"rsrv": 1.4, "warn": 2, "dng": 3.7, "fld": 4.6}
