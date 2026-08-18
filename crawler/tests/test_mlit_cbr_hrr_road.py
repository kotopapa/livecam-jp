"""中部（名古屋国道）・北陸（みちナビ石川）道路パーサのフィクスチャ回帰テスト。"""

from pathlib import Path

from crawler.sources.mlit_cbr_road import MID_RE, parse_cms_fragment, parse_kml_coords
from crawler.sources.mlit_hrr_road import (address_hint_from_map, extract_img_id,
                                           parse_data_js)

FIXTURES = Path(__file__).parent / "fixtures"


def read(name: str) -> str:
    raw = (FIXTURES / name).read_bytes()
    for enc in ("utf-8", "cp932"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


class TestCbr:
    def test_cms_fragment(self):
        cams = parse_cms_fragment(read("mlit_cbr_road_cms_route1.html"))
        assert len(cams) >= 10, f"国道1号のCMS断片から10台以上: {len(cams)}"
        named = dict(cams)
        assert named["001_001"] == "吉田大橋左岸"

    def test_route_page_has_mid(self):
        m = MID_RE.search(read("mlit_cbr_road_route1_page.html"))
        assert m and m.group(1) == "1skhF6ElEd68VcaV2LtkrdLeFw-QBBzir"

    def test_kml_coords_join(self):
        coords = parse_kml_coords(read("mlit_cbr_road_route1.kml"))
        assert len(coords) >= 10
        lat, lng = coords["001_001"]
        assert abs(lat - 34.77) < 0.05 and abs(lng - 137.39) < 0.05  # 豊橋・吉田大橋


class TestHrr:
    def test_data_js_only_active_mlit_rows(self):
        rows = parse_data_js(read("mlit_hrr_road_map_data.js"))
        assert len(rows) >= 40, f"国交省行(A)が40件以上: {len(rows)}"
        names = [r[3] for r in rows]
        assert "国道8号 九折（下）" in names
        lat, lng, path, _, season = next(r for r in rows if r[3] == "国道8号 九折（下）")
        assert abs(lat - 36.6738) < 0.001 and abs(lng - 136.8113) < 0.001
        assert path == "map/map_03.html" and season in ("Y", "W")

    def test_data_js_skips_commented_lines(self):
        js = '''
        ["A",36.0,136.0,"map/map_01.html","国道8号 現役",1,"KN","Y"]
        // ["A",37.0,137.0,"map/map_02.html","国道8号 休止",2,"KN","Y"]
        '''
        rows = parse_data_js(js)
        assert [r[3] for r in rows] == ["国道8号 現役"]

    def test_map_page_img_id_and_hint(self):
        html = read("mlit_hrr_road_map03.html")
        assert extract_img_id(html) == "761160"
        assert address_hint_from_map(html) == "石川県津幡町"
