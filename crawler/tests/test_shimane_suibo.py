"""島根県水防情報システム 河川カメラ（shimane_suibo）のテスト。"""
from pathlib import Path

from crawler.sources.shimane_suibo import (LATEST_URL, MAP_URL,
                                           ShimaneSuiboParser,
                                           parse_map_points,
                                           resolve_image_urls)
from crawler.validate import validate_camera_record

FIX = Path(__file__).parent / "fixtures"
MAP_JSON = (FIX / "shimane_suibo_mapData90.json").read_text(encoding="utf-8")
LATEST_JSON = (FIX / "shimane_suibo_camera.json").read_text(encoding="utf-8")


def test_resolve_image_urls():
    resolved = resolve_image_urls(LATEST_JSON)
    assert "dummy" not in resolved  # 書式サンプル行は無視
    url, at = resolved["8193_90_27"]
    assert url == "https://www.suibou-shimane.jp/dyn/camera/20260829/1440/camera_l/8193_90_27.jpg"
    assert at == "2026-08-29T14:40:00+09:00"
    assert resolved["8193_90_67"][1] == "2026-04-01T21:00:00+09:00"  # 休止局も時刻は返す
    assert resolve_image_urls("not json") == {}
    assert resolve_image_urls('{"list": []}') == {}


def test_parse_map_points_skips_blank_name():
    pts = parse_map_points(MAP_JSON)
    refs = {p["ref"] for p in pts}
    assert refs == {"8193_90_1", "8193_90_68", "8193_90_27"}  # 8193_90_67 は名称空
    kasuga = next(p for p in pts if p["ref"] == "8193_90_1")
    assert kasuga["name"] == "春日" and abs(kasuga["lat"] - 35.4856) < 1e-3


def test_parser_discover():
    class S:
        def fetch(self, url):
            assert url == MAP_URL

            class P:
                ok = True
                status = 200
                text = MAP_JSON
            return P()
    result = ShimaneSuiboParser().discover(S())
    assert not result.errors
    assert len(result.candidates) == 3
    c = next(x for x in result.candidates if x.camera_ref == "8193_90_27")
    assert c.id == "shimane-suibo-8193-90-27"
    assert c.feed_type == "shimane_suibo" and c.feed_url == LATEST_URL
    assert c.prefecture == "32" and c.category == "river" and c.coord_accuracy == "exact"
    assert validate_camera_record(c.to_record("2026-08-29")) == []


def test_dup_note_attached():
    from crawler.sources.shimane_suibo import DUP_NOTES

    class S:
        def fetch(self, url):
            class P:
                ok = True
                status = 200
                text = MAP_JSON
            return P()
    result = ShimaneSuiboParser().discover(S())
    ichihara_like = [c for c in result.candidates if c.camera_ref in DUP_NOTES]
    assert not ichihara_like  # フィクスチャには重複候補局を含めていない
    plain = result.candidates[0]
    assert "重複候補" not in plain.review_note
