"""東近江市 河川監視カメラ（higashiomi_river）のテスト。"""

from pathlib import Path

from crawler.sources.higashiomi_river import (LIST_URL, HigashiomiRiverParser,
                                              resolve_image_urls)
from crawler.validate import validate_camera_record

FIXTURE = Path(__file__).parent / "fixtures" / "higashiomi_cameralist.json"


def test_resolve_image_urls():
    text = FIXTURE.read_text(encoding="utf-8")
    resolved = resolve_image_urls(text)
    assert "jizo-br" not in resolved, "dummy.jpg(欠測)は解決しない"
    assert set(resolved) == {"shimofutamata-br", "daidogawa", "omori-under"}
    url, at = resolved["daidogawa"]
    assert url == ("https://hhdf6nia.user.webaccel.jp/daidogawa/"
                   "192.168.100.20_01_20260825072820831_TIMING.jpg")
    assert at == "2026-08-25T07:28:20+09:00"
    assert resolve_image_urls("<html>") == {}


def test_discover():
    text = FIXTURE.read_text(encoding="utf-8")

    class S:
        def fetch(self, url):
            assert url == LIST_URL

            class P:
                ok = True
                status = 200
            P.text = text
            return P()

    result = HigashiomiRiverParser().discover(S())
    assert not result.errors
    ids = [c.id for c in result.candidates]
    assert ids == ["higashiomi-river-shimofutamata-br", "higashiomi-river-jizo-br",
                   "higashiomi-river-daidogawa", "higashiomi-river-omori-under"]
    c = result.candidates[0]
    assert c.name == "下二俣橋（蛇砂川）" and c.category == "river"
    assert c.feed_type == "higashiomi_river" and c.camera_ref == "shimofutamata-br"
    assert c.lat == 35.08975989 and c.lng == 136.2140442 and c.coord_accuracy == "exact"
    assert c.municipality == "25213"
    road = result.candidates[-1]
    assert road.category == "road" and road.name == "大森町アンダーパス（名神下）"
    assert validate_camera_record(c.to_record("2026-08-25")) == []
