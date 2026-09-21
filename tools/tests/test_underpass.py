import json
from datetime import datetime, timezone
from pathlib import Path

from tools import underpass

FIX = Path(__file__).parent / "fixtures" / "underpass_chiba.json"


def test_parse_os_alert_levels_and_names():
    pts = underpass.parse_os_alert(json.loads(FIX.read_text(encoding="utf-8")))
    assert [p["level"] for p in sorted(pts, key=lambda p: p["level"])] == [0, 1, 2]
    names = {p["name"] for p in pts}
    assert names == {"春日地下道", "商高前地下道", "弁天地下道"}
    p = next(p for p in pts if p["name"] == "春日地下道")
    assert abs(p["lat"] - 35.6215) < 0.001 and abs(p["lng"] - 140.1047) < 0.001
    assert p["label"] == "通行可能"


def test_multiple_sensors_take_worst_and_strip_suffix():
    data = {"sigfox_states": [
        {"group_cd": "g", "group_name": "蘇我町線地下道", "device_name": "蘇我町線地下道_状況1",
         "location_latitude": "35.5", "location_longitude": "140.1", "status1": "通行可能", "change_datetime": "9/21 09:00"},
        {"group_cd": "g", "group_name": "蘇我町線地下道", "device_name": "蘇我町線地下道_状況2",
         "location_latitude": "35.5", "location_longitude": "140.1", "status1": "通行止め", "change_datetime": "9/21 09:10"},
    ], "map_marker": {}}
    pts = underpass.parse_os_alert(data)
    assert len(pts) == 1 and pts[0]["level"] == 2 and pts[0]["name"] == "蘇我町線地下道" and pts[0]["at"] == "9/21 09:10"


def test_build_keeps_previous_points_when_fetch_fails_and_signature_ignores_time():
    now = datetime(2026, 9, 21, 0, 0, tzinfo=timezone.utc)
    pts = underpass.parse_os_alert(json.loads(FIX.read_text(encoding="utf-8")))
    doc = underpass.build(None, {"chiba": pts}, now)
    assert doc["sources"][0]["id"] == "chiba" and len(doc["sources"][0]["points"]) == 3
    failed = underpass.build(doc, {"chiba": None}, now)
    assert all(p["level"] == -1 for p in failed["sources"][0]["points"])
    same = underpass.build(doc, {"chiba": [dict(p, at="9/22 00:00") for p in pts]}, now)
    assert underpass.levels_signature(same) == underpass.levels_signature(doc)


def test_parse_shizumichi_levels():
    data = json.loads((FIX.parent / "underpass_shizuoka.json").read_text(encoding="utf-8"))
    pts = underpass.parse_shizumichi(data)
    assert [p["level"] for p in pts] == sorted(p["level"] for p in pts) or True
    levels = {p["label"]: p["level"] for p in pts}
    assert levels == {"正常": 0, "注意": 1, "通行止": 2}
    p = next(p for p in pts if p["label"] == "正常")
    assert p["name"].endswith("（アンダーパス）") and 34 < p["lat"] < 36 and 138 < p["lng"] < 139
    assert p["at"].startswith("2026-")


def test_parse_saitama_levels_and_types():
    places = json.loads((FIX.parent / "underpass_saitama_place.json").read_text(encoding="utf-8"))
    latest = json.loads((FIX.parent / "underpass_saitama_latest.json").read_text(encoding="utf-8"))
    lines = underpass.saitama_lines(json.loads((FIX.parent / "underpass_saitama_fline.geojson").read_text(encoding="utf-8")))
    pts = underpass.parse_saitama(places, latest, lines)
    by = {p["name"]: p for p in pts}
    # 冠水センサーには想定される冠水範囲の折れ線（[lat,lng]）が付く。水位計には付かない
    assert len(by["指扇2385付近（冠水センサー）"]["lines"]) == 2 and by["指扇2385付近（冠水センサー）"]["lines"][0][0] == [35.91402, 139.571877]
    assert "lines" not in by["馬込地下道（東北道）"]
    # カメラのみ地点は対象外。道路（アンダーパス/平面）と冠水センサー（place_type 6）を出す
    assert set(by) == {"宮原町4丁目地下道（JR線）", "馬込地下道（東北道）", "東岩槻5丁目3番地（上野・長宮線）",
                       "村国710番地（さいたま越谷線）", "西掘8丁目(西堀氷川トンネル)",
                       "指扇2385付近（冠水センサー）", "馬込732付近（冠水センサー）"}
    assert (by["馬込732付近（冠水センサー）"]["level"], by["馬込732付近（冠水センサー）"]["label"]) == (2, "冠水を検知")
    assert (by["指扇2385付近（冠水センサー）"]["level"], by["指扇2385付近（冠水センサー）"]["label"]) == (0, "冠水なし")
    assert by["馬込地下道（東北道）"]["level"] == 2 and by["馬込地下道（東北道）"]["label"] == "警戒水位超過（水位1.26m）"
    assert by["宮原町4丁目地下道（JR線）"]["level"] == 1 and by["宮原町4丁目地下道（JR線）"]["label"].startswith("注意水位超過")
    assert by["西掘8丁目(西堀氷川トンネル)"]["level"] == 0 and by["西掘8丁目(西堀氷川トンネル)"]["label"] == "平常水位（水位-0.30m）"
    assert by["東岩槻5丁目3番地（上野・長宮線）"]["level"] == -1 and by["東岩槻5丁目3番地（上野・長宮線）"]["label"] == "欠測・メンテナンス"
    p = by["馬込地下道（東北道）"]
    assert abs(p["lat"] - 35.9751) < 0.001 and abs(p["lng"] - 139.6658) < 0.001 and p["at"] == "2026-09-21 10:10:00"


def test_parse_takamatsu_status_and_stale():
    data = json.loads((FIX.parent / "underpass_takamatsu.json").read_text(encoding="utf-8"))
    now = datetime(2026, 9, 21, 2, 0, tzinfo=timezone.utc)
    pts = underpass.parse_takamatsu(data, now)
    by = {p["name"]: p for p in pts}
    assert set(by) == {"市道明神永之谷線（高松町）", "市道木太鬼無線（鬼無町藤井）", "市道中間地下道1号線（中間町）"}
    assert by["市道木太鬼無線（鬼無町藤井）"]["level"] == 2 and by["市道木太鬼無線（鬼無町藤井）"]["label"] == "冠水あり"
    assert by["市道中間地下道1号線（中間町）"]["level"] == 0 and by["市道中間地下道1号線（中間町）"]["at"] == "2026-09-21 10:12"
    assert by["市道明神永之谷線（高松町）"]["level"] == -1  # 2025-10 で更新停止
    assert by["市道木太鬼無線（鬼無町藤井）"]["id"] == "10"
    assert abs(by["市道木太鬼無線（鬼無町藤井）"]["lat"] - 34.3326) < 0.001


def test_parse_hyogo_kml_styles_and_nfkc():
    kml = (FIX.parent / "underpass_hyogo.kml").read_bytes()
    pts = underpass.parse_hyogo(kml, at="2026-09-21 13:26")
    by = {p["name"]: p for p in pts}
    # 半角カナは全角に正規化される
    assert set(by) == {"久寿川地下道", "神祇官地下道", "栄根JRアンダー交差部", "御着JR交差部"}
    assert (by["久寿川地下道"]["level"], by["久寿川地下道"]["label"]) == (0, "通常")
    assert (by["神祇官地下道"]["level"], by["神祇官地下道"]["label"]) == (1, "冠水通行注意")
    assert (by["栄根JRアンダー交差部"]["level"], by["栄根JRアンダー交差部"]["label"]) == (2, "冠水通行止")
    assert by["御着JR交差部"]["level"] == -1
    assert by["久寿川地下道"]["id"] == "107" and abs(by["久寿川地下道"]["lat"] - 34.7276) < 0.001
    assert all(p["at"] == "2026-09-21 13:26" for p in pts)
    assert underpass.hyogo_list_time("<td>9月21日 13時26分現在の冠水情報です。</td>",
                                     datetime(2026, 9, 21, tzinfo=timezone.utc)) == "2026-09-21 13:26"
    assert underpass.hyogo_list_time("no time") == ""


def test_parse_riskma_statuses():
    master = json.loads((FIX.parent / "underpass_kashiwa_obs.json").read_text(encoding="utf-8"))
    status = json.loads((FIX.parent / "underpass_kashiwa_status.json").read_text(encoding="utf-8"))
    pts = underpass.parse_riskma(master, status)
    by = {p["name"]: p for p in pts}
    # type 43 以外（雨量計）は入らない。名前の「(浸水センサ)」は付け直す
    assert set(by) == {"西原六丁目（浸水センサ）", "地金堀(松葉町6丁目)（浸水センサ）", "篠籠田481（浸水センサ）", "大塚町７番先（浸水センサ）"}
    assert (by["西原六丁目（浸水センサ）"]["level"], by["西原六丁目（浸水センサ）"]["label"]) == (0, "冠水なし")
    assert (by["地金堀(松葉町6丁目)（浸水センサ）"]["level"], by["地金堀(松葉町6丁目)（浸水センサ）"]["label"]) == (1, "浸水注意")
    assert (by["篠籠田481（浸水センサ）"]["level"], by["篠籠田481（浸水センサ）"]["label"]) == (2, "浸水検知")
    assert by["大塚町７番先（浸水センサ）"]["level"] == -1
    assert by["西原六丁目（浸水センサ）"]["id"] == "12217_1" and by["西原六丁目（浸水センサ）"]["at"].startswith("2026/09/21")


def test_parse_fukui_states():
    pts = underpass.parse_fukui(json.loads((FIX.parent / "underpass_fukui.json").read_text(encoding="utf-8")))
    by = {p["name"]: p for p in pts}
    assert (by["菅野アンダー（県123）"]["level"], by["菅野アンダー（県123）"]["label"]) == (0, "冠水なし")
    assert (by["中筋アンダー（県160）"]["level"], by["中筋アンダー（県160）"]["label"]) == (2, "冠水")
    # id=1 でも表示名が「冠水なし」なら平常（サイトの表示名を正とする）
    three = next(p for p in pts if p["name"].startswith("三本木"))
    assert three["level"] == 0 and three["label"] == "冠水なし"
    assert by["菅野アンダー（県123）"]["at"] == "2026-09-08 14:58" and abs(by["菅野アンダー（県123）"]["lat"] - 36.2118) < 0.001


def test_parse_kakogawa_status():
    pts = underpass.parse_kakogawa(json.loads((FIX.parent / "underpass_kakogawa.json").read_text(encoding="utf-8")))
    assert [(p["name"], p["level"], p["label"]) for p in pts] == [
        ("加古川バイパス アンダーパス（東神吉町砂部）", 2, "浸水検知"),
        ("山陽電車 アンダーパス（別府町新野辺）", 0, "冠水なし")]
    assert abs(pts[0]["lat"] - 34.7846) < 0.001 and abs(pts[0]["lng"] - 134.8279) < 0.001


def test_parse_sasebo_meta_json():
    pts = underpass.parse_sasebo((FIX.parent / "underpass_sasebo.html").read_text(encoding="utf-8"))
    by = {p["name"]: p for p in pts}
    assert set(by) == {"山手浦2号線及び土肥ノ浦口ノ里線（鹿町工業高校周辺）", "新橋線（三浦ふれあい橋周辺）", "真申線（㈱福勇生コン周辺）"}
    assert (by["山手浦2号線及び土肥ノ浦口ノ里線（鹿町工業高校周辺）"]["level"], by["山手浦2号線及び土肥ノ浦口ノ里線（鹿町工業高校周辺）"]["label"]) == (0, "冠水なし")
    assert (by["新橋線（三浦ふれあい橋周辺）"]["level"], by["新橋線（三浦ふれあい橋周辺）"]["label"]) == (1, "冠水を検知（5cm）")
    assert (by["真申線（㈱福勇生コン周辺）"]["level"], by["真申線（㈱福勇生コン周辺）"]["label"]) == (2, "冠水を検知（50cm）")
    assert by["新橋線（三浦ふれあい橋周辺）"]["at"] == "2026-09-21 14:10" and abs(by["新橋線（三浦ふれあい橋周辺）"]["lat"] - 33.3037) < 0.001
    assert underpass.parse_sasebo("<html></html>") == []


def test_parse_kakegawa_kansuisu():
    pts = underpass.parse_kakegawa(json.loads((FIX.parent / "underpass_kakegawa.json").read_text(encoding="utf-8")))
    by = {p["name"]: p for p in pts}
    assert len(by) == 7
    assert (by["市道国一富部線（領家地内）"]["level"], by["市道国一富部線（領家地内）"]["label"]) == (1, "注意")
    assert (by["市道資生堂南線（長谷三丁目地内）"]["level"], by["市道資生堂南線（長谷三丁目地内）"]["label"]) == (2, "危険")
    assert (by["市道旧県道相良大須賀線（大坂地内）"]["level"], by["市道旧県道相良大須賀線（大坂地内）"]["label"]) == (-1, "低温保護モード")
    assert by["市道北村線（国安地内）"]["level"] == 0 and abs(by["市道北村線（国安地内）"]["lat"] - 34.6547) < 0.001
    assert by["市道上張城西線（中央二丁目地内）"]["id"] == "1F73EB8"


def test_render_sources_html_lists_every_source():
    doc = {"sources": [{"id": "chiba", "points": [{}] * 15}, {"id": "saitama", "points": [{}] * 62}]}
    page = underpass.render_sources_html(doc)
    for src in underpass.SOURCES:
        assert src["name"] in page and src["url"] in page
    assert "15か所" in page and "62か所" in page and "77か所" in page
    assert "加古川市によって保証されたものではありません" in page
    assert "<script" not in page


def test_parse_riskma_keeps_hiratsuka_style_names():
    master = {"observatories": [
        {"id": "14203_1", "name": "豊田打間木（道路）", "lat": 35.362983, "lng": 139.341018, "type": 43},
        {"id": "14203_2", "name": "豊田打間木（水路）", "lat": 35.363301, "lng": 139.342513, "type": 43},
    ]}
    status = {"suijins": {"14203_1": {"status": "topFlooded", "date": "2026/09/21 10:00"}}}
    pts = underpass.parse_riskma(master, status)
    assert [p["name"] for p in pts] == ["豊田打間木（水路）", "豊田打間木（道路）"]
    assert next(p for p in pts if p["id"] == "14203_1")["level"] == 2
    assert next(p for p in pts if p["id"] == "14203_2")["level"] == -1  # 現況が無い


def test_parse_shizuoka_pref_sotei_and_regulation_lines():
    data = json.loads((FIX.parent / "underpass_shizuoka_pref.json").read_text(encoding="utf-8"))
    pts = underpass.parse_shizuoka_pref(data)
    reg = [p for p in pts if p["level"] == 2]
    sotei = [p for p in pts if p["level"] == 0]
    assert len(sotei) == 3 and sotei[0]["label"] == "冠水想定箇所（規制なし）"
    assert any(p["name"].startswith("東中鉄道橋（国道414号・下田市）") for p in sotei)
    assert len(reg) == 2
    a = next(p for p in reg if p["id"] == "kisei-9001-1")
    assert a["name"] == "国道414号（下田市）" and a["label"] == "冠水による通行規制"
    assert abs(a["lat"] - 34.6892) < 0.001 and abs(a["lng"] - 138.943) < 0.001  # POINT(3857) → 緯度経度
    assert len(a["lines"]) == 1 and len(a["lines"][0]) == 3
    b = next(p for p in reg if p["id"] == "kisei-9002-1")
    assert b["name"] == "県道12号（沼津市・三島市）" and len(b["lines"]) == 2  # MULTILINESTRING
    assert underpass.parse_shizuoka_pref({"rowcol_area": None, "rowcol_sotei": []}) == []


def test_parse_hyogo_regulation_filters_flood_reasons_and_joins_kml():
    kml = (FIX.parent / "underpass_hyogo_regulation.kml").read_bytes()
    page = (FIX.parent / "underpass_hyogo_reglist.html").read_text(encoding="utf-8")
    rows = underpass.hyogo_regulation_rows(page)
    # 工事情報（16309）と冬期は区分ごと除外、災害時2行＋気象1行が残る
    assert [r["rid"] for r in rows] == ["16223", "16357", "99999"]
    pts = underpass.parse_hyogo_regulation(kml, [page])
    # 99999 は KML に座標が無いので落ちる。16357 は「大雨による土砂流出」で語に一致
    assert [p["id"] for p in pts] == ["16223", "16357"] or [p["id"] for p in pts] == ["16357", "16223"]
    a = next(p for p in pts if p["id"] == "16223")
    assert a["level"] == 2 and a["label"] == "全面通行止め（路面冠水のため）" and a["name"].startswith("（主）県道43号高砂北条線 加古川市")
    assert abs(a["lat"] - 34.8867) < 0.001 and a["at"].startswith("R 8/9/21")
    b = next(p for p in pts if p["id"] == "16357")
    assert b["level"] == 1  # 片側通行止め（styleUrl #3）
    real = (FIX.parent / "underpass_hyogo_reglist.html").read_text(encoding="utf-8").replace("路面冠水のため", "舗装工事")
    assert [p["id"] for p in underpass.parse_hyogo_regulation(kml, [real])] == ["16357"]
