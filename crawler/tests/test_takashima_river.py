"""高島市 河川防災カメラ（takashima_river）のテスト。"""

from pathlib import Path

from crawler.sources.takashima_river import (API_URL, TakashimaRiverParser,
                                             resolve_image_urls)
from crawler.validate import validate_camera_record

FIXTURE = Path(__file__).parent / "fixtures" / "takashima_cameras.json"


def test_resolve_image_urls():
    text = FIXTURE.read_text(encoding="utf-8")
    resolved = resolve_image_urls(text)
    assert set(resolved) == {"1", "4"}, "latestPictureが無いカメラは解決しない"
    url, at = resolved["1"]
    assert url == ("http://bousai.city.takashima.lg.jp/cctv/"
                   "assets/cameras/1/pictures/2026/08/25/1_20260825072000.jpg")
    assert at == "2026-08-25T07:20:00+09:00"
    assert resolve_image_urls("not json") == {}
    assert resolve_image_urls('{"id": 1}') == {}


def test_discover():
    text = FIXTURE.read_text(encoding="utf-8")

    class S:
        def fetch(self, url):
            assert url == API_URL

            class P:
                ok = True
                status = 200
            P.text = text
            return P()

    result = TakashimaRiverParser().discover(S())
    assert not result.errors
    assert [c.id for c in result.candidates] == ["takashima-river-1", "takashima-river-4"]
    c = result.candidates[0]
    assert c.name == "上開田橋（知内川）"
    assert c.feed_type == "takashima_river" and c.camera_ref == "1"
    assert c.feed_url == API_URL
    assert c.prefecture == "25" and c.municipality == "25212"
    assert c.coord_accuracy == "approx" and 35.4 < c.lat < 35.5 and 136.0 < c.lng < 136.1
    assert c.license == "unknown"
    assert validate_camera_record(c.to_record("2026-08-25")) == []
