"""気象庁 火山監視カメラパーサのフィクスチャ回帰テスト。"""

from pathlib import Path

from crawler.sources.jma_volcam import (GEOJSON_URL, JmaVolcamParser,
                                        resolve_image_url)
from crawler.validate import validate_camera_record

FIXTURES = Path(__file__).parent / "fixtures"
GEOJSON = (FIXTURES / "jma_camicon.geojson").read_text(encoding="utf-8")
PAGE = (FIXTURES / "jma_volcam_page.html").read_text(encoding="utf-8")


class FakePage:
    def __init__(self, text, ok=True, status=200):
        self.text = text
        self.ok = ok
        self.status = status
        self.error = None


class FakeSession:
    def fetch(self, url):
        if url == GEOJSON_URL:
            return FakePage(GEOJSON)
        if "reverse-geocoder" in url:
            if "lat=43" in url:
                return FakePage('{"results": {"muniCd": "01665"}}')
            return FakePage('{"results": {"muniCd": "22203"}}')
        return FakePage("", ok=False, status=404)


def test_resolve_image_url_picks_latest():
    url, at = resolve_image_url(PAGE)
    assert url == ("https://www.data.jma.go.jp/vois/data/obs/camera/"
                   "314_82008084/20260821151001.jpg")
    assert at == "2026-08-21T15:10:01+09:00"
    assert resolve_image_url("<html>no images</html>") is None


def test_discover_builds_valid_candidates():
    result = JmaVolcamParser().discover(FakeSession())
    assert len(result.candidates) == 2
    fuji = next(c for c in result.candidates if c.id == "jma-volcam-31401")
    assert fuji.prefecture == "22" and fuji.municipality == "22203"
    assert fuji.feed_type == "jma_volcam" and fuji.feed_url == "31401"
    assert fuji.lat == 35.361 and fuji.lng == 138.731
    errors = validate_camera_record(fuji.to_record("2026-08-21"))
    assert errors == [], errors
