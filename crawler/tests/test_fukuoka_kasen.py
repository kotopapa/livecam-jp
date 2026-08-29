"""福岡県 河川防災情報 河川監視カメラ（fukuoka_kasen）のテスト。"""

from pathlib import Path

from crawler.sources.fukuoka_kasen import (DETAIL_URL, GIS_URL, MAP_URL,
                                           FukuokaKasenParser, municipality_jis,
                                           parse_gis, parse_location,
                                           resolve_image_urls)
from crawler.validate import validate_camera_record

FIX = Path(__file__).parent / "fixtures"
GIS_HTML = (FIX / "fukuoka_kasen_gisItv.html").read_text(encoding="utf-8")
DETAIL_4 = (FIX / "fukuoka_kasen_detail_4.html").read_text(encoding="utf-8")
DETAIL_188 = (FIX / "fukuoka_kasen_detail_188.html").read_text(encoding="utf-8")


def test_parse_gis():
    ts, sites = parse_gis(GIS_HTML)
    assert ts == "202608291605"
    assert set(sites) == {"004", "007", "040", "188", "281"}
    s = sites["004"]
    assert s["an"] == "山王橋" and s["rn"] == "御笠川"
    assert (s["lat"], s["lng"]) == ("33.584722222222226", "130.43277777777777")
    assert sites["281"]["lng"] == ""          # 久保橋は経度欠落
    assert sites["040"]["an"] == "西縄手橋（休止中）"


def test_resolve_image_urls():
    r = resolve_image_urls(GIS_HTML)
    assert len(r) == 5
    url, at = r["004"]
    assert url == ("http://doboku-bousai.pref.fukuoka.lg.jp/camera/20260829/004/"
                   "004_202608291605_VGA.jpg")
    assert at == "2026-08-29T16:05:00+09:00"
    assert len({u for u, _ in r.values()}) == 5
    assert resolve_image_urls("<html></html>") == {}
    assert resolve_image_urls(GIS_HTML.replace('"date"', '"xdate"')) == {}


def test_location_and_municipality():
    assert parse_location(DETAIL_4) == "福岡市博多区"
    assert parse_location(DETAIL_188) == "行橋上稗田"
    assert municipality_jis("福岡市博多区") == "40132"
    assert municipality_jis("福岡市") == "40130"
    assert municipality_jis("北九州市小倉南区高津尾") == "40107"
    assert municipality_jis("行橋上稗田") == "40213"     # 「市」抜け表記
    assert municipality_jis("須惠町") == "40344"          # 異体字
    assert municipality_jis("みやこ町犀川本庄") == "40625"
    assert municipality_jis("") is None and municipality_jis("東京都") is None


class _Session:
    def __init__(self):
        self.urls = []

    def fetch(self, url, use_cache=True):
        self.urls.append(url)

        class P:
            ok = True
            status = 200
            error = None
        if url == GIS_URL:
            P.text = GIS_HTML
        elif url == DETAIL_URL.format(sn=4):
            P.text = DETAIL_4
        elif url == DETAIL_URL.format(sn=188):
            P.text = DETAIL_188
        else:
            P.ok = False
            P.status = 404
            P.text = ""
        return P()


def test_discover():
    s = _Session()
    result = FukuokaKasenParser().discover(s)
    assert s.urls[0] == GIS_URL and len(s.urls) == 6
    ids = [c.id for c in result.candidates]
    assert ids == ["fukuoka-kasen-004", "fukuoka-kasen-007", "fukuoka-kasen-040",
                   "fukuoka-kasen-188", "fukuoka-kasen-281"]
    c = result.candidates[0]
    assert c.name == "山王橋（御笠川）" and c.river_or_route == "御笠川"
    assert c.feed_type == "fukuoka_kasen" and c.feed_url == GIS_URL and c.camera_ref == "004"
    assert c.prefecture == "40" and c.municipality == "40132"
    assert (c.lat, c.lng) == (33.584722222222226, 130.43277777777777)
    assert c.coord_accuracy == "exact"
    assert c.license == "unknown" and c.terms_url and c.page_url == MAP_URL
    assert c.fallback_url == DETAIL_URL.format(sn=4)
    assert "kawabou-310242002" in c.review_note      # 既存との同一地点候補
    # 所在地ページが取れない局は municipality None（座標はあるので address_hint も無し）
    c7 = result.candidates[1]
    assert c7.municipality is None and c7.address_hint is None and c7.lat is not None
    # 休止中
    assert "休止中" in result.candidates[2].review_note
    # 市抜け表記の所在地
    assert result.candidates[3].municipality == "40213"
    # 座標欠落の局は lat None（推測で埋めない。SPEC 10章）
    c281 = result.candidates[4]
    assert c281.lat is None and c281.coord_accuracy is None
    assert any("281" in e and "座標なし" in e for e in result.errors)
    for cand in result.candidates:
        assert validate_camera_record(cand.to_record("2026-08-29")) == []
