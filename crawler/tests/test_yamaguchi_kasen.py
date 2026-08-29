"""山口県土木防災情報システム 河川監視カメラ（yamaguchi_kasen）のテスト。"""

from pathlib import Path

from crawler.sources.yamaguchi_kasen import (LIST_URL, MAP_URL, STATION_INFO_URL,
                                             YamaguchiKasenParser, parse_city_codes,
                                             parse_map_coords, parse_station_info,
                                             resolve_image_urls)
from crawler.validate import validate_camera_record

FIX = Path(__file__).parent / "fixtures"
LIST_HTML = (FIX / "yamaguchi_kasen_list.html").read_text(encoding="utf-8")
MAP_HTML = (FIX / "yamaguchi_kasen_map.html").read_text(encoding="utf-8")
INFO_HTML = (FIX / "yamaguchi_kasen_station_info.html").read_text(encoding="utf-8")


def test_resolve_image_urls_latest_and_fallback():
    r = resolve_image_urls(LIST_HTML)
    assert set(r) == {"001", "002", "004", "006"}
    url, at = r["001"]
    assert url == ("https://y-bousai.pref.yamaguchi.lg.jp/img/cameraImage/"
                   "20260829/1550/133500000001_M.jpg")
    assert at == "2026-08-29T15:50:00+09:00"
    # 画像未到着(imageError)の局は表示スロット(hidePctImgDate=…1550)の1つ前で補う
    url4, at4 = r["004"]
    assert url4 == ("https://y-bousai.pref.yamaguchi.lg.jp/img/cameraImage/"
                    "20260829/1540/133500000004_M.jpg")
    assert at4 == "2026-08-29T15:40:00+09:00"
    # 全URLが局番ごとに一意
    assert len({u for u, _ in r.values()}) == 4
    assert resolve_image_urls("<html></html>") == {}


def test_resolve_without_slot_skips_error_images():
    html = LIST_HTML.replace('id="ctl00_ContentPlaceHolder1_hidePctImgDate"', 'id="x"')
    r = resolve_image_urls(html)
    assert "004" not in r and "001" in r


def test_parse_map_coords_only_river_camera_markers():
    c = parse_map_coords(MAP_HTML)
    assert c == {"001": (34.162, 132.180), "002": (34.215, 132.017),
                 "004": (34.264, 131.978), "006": (33.969, 132.092)}


def test_parse_station_info_and_city_codes():
    info = parse_station_info(INFO_HTML)
    assert info["001"] == {"office": "岩国", "city": "岩国市", "addr": "大字錦見3203",
                           "system": "錦川", "river": "錦川", "name": "臥龍橋",
                           "kana": "がりょうばし"}
    assert info["006"]["city"] == "柳井市" and info["006"]["river"] == "土穂石川"
    codes = parse_city_codes(LIST_HTML)
    assert codes["岩国市"] == "35208" and codes["柳井市"] == "35212"
    assert "山口県全域" not in codes


class _Session:
    def __init__(self):
        self.urls = []

    def fetch(self, url, use_cache=True):
        self.urls.append(url)

        class P:
            ok = True
            status = 200
        P.text = {LIST_URL: LIST_HTML, MAP_URL: MAP_HTML, STATION_INFO_URL: INFO_HTML}[url]
        return P()


def test_discover():
    s = _Session()
    result = YamaguchiKasenParser().discover(s)
    assert not result.errors
    assert s.urls == [LIST_URL, MAP_URL, STATION_INFO_URL]
    ids = [c.id for c in result.candidates]
    assert ids == ["yamaguchi-kasen-001", "yamaguchi-kasen-002",
                   "yamaguchi-kasen-004", "yamaguchi-kasen-006"]
    assert len(set(ids)) == len(ids)
    c = result.candidates[0]
    assert c.name == "臥龍橋（錦川）" and c.name_kana == "がりょうばし"
    assert c.feed_type == "yamaguchi_kasen" and c.feed_url == LIST_URL and c.camera_ref == "001"
    assert c.prefecture == "35" and c.municipality == "35208"
    assert c.river_or_route == "錦川"
    assert (c.lat, c.lng) == (34.162, 132.180) and c.coord_accuracy == "approx"
    assert c.license == "unknown" and c.terms_url
    assert c.fallback_url.endswith("krc_camera.aspx?stncd=001&obsdt=")
    assert c.address_hint == "山口県岩国市大字錦見3203"
    last = result.candidates[-1]
    assert last.municipality == "35212" and last.name == "新庄（土穂石川）"
    for cand in result.candidates:
        assert validate_camera_record(cand.to_record("2026-08-29")) == []
