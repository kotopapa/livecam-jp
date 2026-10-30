import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from tools import snow_points as sp

FIX = Path(__file__).parent / "fixtures"
JST = timezone(timedelta(hours=9))
NOW = datetime(2026, 10, 30, 12, 0, tzinfo=timezone.utc)   # JST 21:00


def txt(name: str, enc: str = "utf-8") -> str:
    return (FIX / f"snow_points_{name}").read_bytes().decode(enc)


def js(name: str):
    return json.loads(txt(name))


def by_id(points):
    return {p["id"]: p for p in points}


def test_parse_depth_and_round():
    for v in ("-", "--", "", None, "abc", " - ", "ー", True):
        assert sp.parse_depth(v) is None
    assert sp.parse_depth("0") == 0 and sp.parse_depth(" 12.5 cm ") == 12.5 and sp.parse_depth(3) == 3
    assert sp.parse_depth(-1) is None and sp.parse_depth(99999) is None
    assert sp.round_cm(0.5) == 1 and sp.round_cm(2.5) == 3 and sp.round_cm(12.4) == 12


def test_parse_at_formats():
    want = datetime(2026, 10, 30, 20, 50, tzinfo=JST)
    for s in ("2026-10-30 20:50:00", "2026/10/30 20:50", "202610302050", "20261030205000"):
        assert sp.parse_at(s) == want
    assert sp.parse_at("") is None and sp.parse_at("昨日") is None and sp.parse_at("2026/13/40 25:00") is None


def test_mlit_keeps_only_snow_sensors_and_drops_missing():
    pts = by_id(sp.parse_mlit(js("mlit.json")))
    # flag=0 の観測点は積雪深センサーではないので出ない。欠測 "-" は d=None で残り、後段で落ちる
    assert set(pts) == {"835800034", "833500007"}
    a = pts["835800034"]
    assert a["d"] == 13 and a["m"] == "13201" and a["r"] == "国道16号" and a["at"] == "2026-10-30 20:40"
    assert abs(a["lat"] - 35.620917) < 1e-9 and abs(a["lng"] - 139.342361) < 1e-9
    assert pts["833500007"]["d"] is None
    assert [p["id"] for p in sp.keep_fresh(list(pts.values()), NOW)] == ["835800034"]
    assert sp.data_dir_of(txt("mlit_page.html")) == "backup/20261030205000/a24GVNKx85JRG1rx/"


def test_tottori():
    pts = sp.parse_tottori(js("tottori.geojson"))
    assert len(pts) == 2          # 積雪センサーなし（"○" でない）の1件は出ない
    assert pts[0]["d"] == 5 and pts[0]["r"] and pts[0]["at"].startswith("2026-10-30")
    assert pts[1]["d"] == 0       # 0 は残す


def test_hiroshima():
    pts = sp.parse_hiroshima(js("hiroshima.json"))
    assert len(pts) == 3 and pts[0]["d"] == 8 and pts[1]["d"] is None
    assert len(sp.keep_fresh(pts, NOW)) == 1   # 空文字（無雪期）は出さない


def test_ishikawa_and_gifu_api():
    for name in ("ishikawa", "gifu"):
        pts = sp.parse_kyoku_api(js(f"{name}_master.json"), js(f"{name}_snow.json"))
        ids = {p["id"] for p in pts}
        assert "999999" not in ids and "888888" not in ids   # type!=0 と master に無い id は出ない
        assert len(pts) == 3
        assert pts[0]["d"] == 4 and pts[1]["d"] is None       # 3.6 → 4、空文字は欠測
        assert pts[0]["at"].startswith("2026-10-30")
    assert any(p.get("r") for p in sp.parse_kyoku_api(js("gifu_master.json"), js("gifu_snow.json")))


def test_fukui_only_prefecture_sensors():
    pts = sp.parse_fukui(js("fukui.json"))
    assert len(pts) == 2          # 気象庁分と isSnowDepth=0 は除く
    assert pts[0]["d"] == 21 and pts[0]["at"].startswith("2026-10-30") and pts[0]["r"]


def test_toyama_uses_latest_time_and_requires_master():
    pts = by_id(sp.parse_toyama(js("toyama_master.json"), js("toyama_snow.json")))
    assert len(pts) == 2 and "snow_777" not in pts
    vals = sorted((p["d"] is None, p["d"]) for p in pts.values())
    assert vals == [(False, 7), (True, None)]


def test_json5_survives_quotes_and_colons():
    v = sp.json5_loads("[{a:'x\\'y: z, w',b:\"q\",c:[1,2,],},]")
    assert v == [{"a": "x'y: z, w", "b": "q", "c": [1, 2]}]
    assert sp.json5_loads("{name:'a:b', url:'http://x/y'}") == {"name": "a:b", "url": "http://x/y"}


def test_shimane():
    pts = by_id(sp.parse_shimane(txt("shimane_point.json5"), txt("shimane_recent.json5")))
    assert set(pts) == {"0101", "0102", "0999"}
    assert pts["0101"]["d"] == 4 and pts["0101"]["at"] == "2026-10-30 20:50" and pts["0101"]["r"] == "松江木次線"
    assert pts["0102"]["d"] is None
    assert pts["0999"]["n"] == "O'Brien: 峠" and pts["0999"]["r"] == "県道1号, 2号" and pts["0999"]["d"] == 0


def test_okayama_skips_suspended_and_empty():
    pts = sp.parse_okayama(js("okayama.json"), txt("okayama.html"))
    assert len(pts) == 3
    d = by_id(pts)
    assert d["po03"]["d"] is None   # 休止中は値があっても採らない
    assert [p["id"] for p in sp.keep_fresh(pts, NOW)] == ["po01"]
    assert d["po01"]["d"] == 15 and d["po02"]["d"] is None and abs(d["po01"]["lat"] - 35.095969) < 1e-9
    assert d["po01"]["at"] == "2026-10-30 20:30"


def test_hyogo_join_kml_and_list():
    page = txt("hyogo_list.html")
    assert sp.hyogo_list_time(page, NOW) == datetime(2026, 10, 30, 21, 0, tzinfo=JST)
    rows = sp.parse_hyogo_list(page)
    assert set(rows) == {"92", "91", "60"} and rows["92"]["d"] == 12 and rows["91"]["d"] is None
    assert rows["92"]["r"].startswith("（国）")
    pts = by_id(sp.parse_hyogo((FIX / "snow_points_hyogo.kml").read_bytes(), [page], NOW))
    assert set(pts) == {"92", "91", "60"}
    assert pts["92"]["d"] == 12 and pts["92"]["at"] == "2026-10-30 21:00" and 34 < pts["92"]["lat"] < 36
    assert [p["id"] for p in sp.keep_fresh(list(pts.values()), NOW)] == ["92"]


def test_hyogo_list_time_year_wrap():
    # 1月2日に「12月31日」と出ているなら前年
    now = datetime(2027, 1, 1, 15, 30, tzinfo=timezone.utc)   # JST 1/2 0:30
    dt = sp.hyogo_list_time("12月31日 21時0分現在", now)
    assert dt == datetime(2026, 12, 31, 21, 0, tzinfo=JST)
    assert sp.hyogo_list_time("no time", now) is None


def test_hyogo_hidden_fields_collects_all():
    page = txt("hyogo_list.html")
    f = sp.hyogo_hidden_fields(page)
    assert f["__VIEWSTATE"] == "VS" and f["__EVENTVALIDATION"] == "EV" and "__VIEWSTATEGENERATOR" in f


def test_keep_fresh_24h_boundary():
    def p(at, d=1):
        return {"id": at, "d": d, "at": at}
    pts = [p("2026-10-29 21:00"), p("2026-10-29 20:59"), p("2026-10-30 20:50"), p("2026-10-30 23:00"),
           p("2026-10-30 21:00", None), p("")]
    got = [x["id"] for x in sp.keep_fresh(pts, NOW)]
    assert got == ["2026-10-29 21:00", "2026-10-30 20:50"]


def test_build_signature_and_failed_source_keeps_previous():
    mlit = sp.parse_mlit(js("mlit.json"))
    tot = sp.parse_tottori(js("tottori.geojson"))
    doc = sp.build(None, {"mlit": mlit, "tottori": tot}, NOW)
    ids = [s["id"] for s in doc["sources"]]
    assert ids == ["mlit", "tottori"]     # 取得していない情報源は前回も無ければ出ない
    s = doc["sources"][0]
    assert s["short"] == "国交省" and s["attribution"].startswith("出典：") and s["fetched_at"] == "2026-10-30T12:00:00Z"
    assert [p["id"] for p in s["points"]] == ["835800034"] and "lat" in s["points"][0]
    assert doc["version"] == "2026-10-30T12:00:00Z"
    # tottori が失敗 → 前回の内容をそのまま残す
    later = datetime(2026, 10, 30, 12, 30, tzinfo=timezone.utc)
    again = sp.build(doc, {"mlit": mlit, "tottori": None}, later)
    assert again["sources"][1] == doc["sources"][1]
    assert sp.signature(again) == sp.signature(doc)
    # 積雪深が変わると署名が変わる
    changed = json.loads(json.dumps(doc))
    changed["sources"][0]["points"][0]["d"] = 20
    assert sp.signature(changed) != sp.signature(doc)


def test_season_gate():
    j = lambda m, d: datetime(2026 if m >= 10 else 2027, m, d, 12, 0, tzinfo=JST)
    assert sp.in_season(j(10, 15)) and sp.in_season(j(12, 31)) and sp.in_season(j(5, 15))
    assert not sp.in_season(j(10, 14)) and not sp.in_season(j(7, 1)) and not sp.in_season(j(5, 16))


def test_attach_municipality_uses_cache_and_budget(monkeypatch):
    from tools import fill_municipality as fm
    calls = []
    monkeypatch.setattr(fm, "reverse_geocode", lambda la, ln: calls.append((la, ln)) or "15201")
    pts = [{"id": "a", "lat": 35.0, "lng": 135.0}, {"id": "b", "lat": 36.0, "lng": 136.0},
           {"id": "c", "lat": 37.0, "lng": 137.0, "m": "01101"}, {"id": "d", "lat": 38.0, "lng": 138.0}]
    cache = {fm.cache_key(38.0, 138.0): "17201"}
    used = sp.attach_municipality(pts, cache, budget=1, sleep=0)
    assert used == 1 and len(calls) == 1
    assert pts[0]["m"] == "15201" and "m" not in pts[1] and pts[2]["m"] == "01101" and pts[3]["m"] == "17201"


def test_sync_site(tmp_path, monkeypatch):
    data, site = tmp_path / "d.json", tmp_path / "v1" / "s.json"
    monkeypatch.setattr(sp, "DATA_PATH", data)
    monkeypatch.setattr(sp, "SITE_PATH", site)
    assert sp.sync_site() == 0
    doc = sp.build(None, {"mlit": sp.parse_mlit(js("mlit.json"))}, NOW)
    data.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    assert sp.sync_site() == 1
    assert json.loads(site.read_text(encoding="utf-8")) == doc


def test_mlit_muni_drops_designated_city_code():
    from tools.snow_points import _mlit_muni
    assert _mlit_muni("08542") == "08542"
    assert _mlit_muni("01100") == ""   # 政令市の市コードは区単位に引き直す
    assert _mlit_muni(None) == "" and _mlit_muni("123") == ""
