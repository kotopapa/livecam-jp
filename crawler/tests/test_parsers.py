"""フィクスチャ（実サイトの保存HTML/JSON）に対するパーサ回帰テスト。

サイト構造が変わって取れなくなったときは、まずフィクスチャを再取得して
差分を見ること（SPEC 11: パーサごとにテストHTMLをフィクスチャで保持）。
"""

import json
from pathlib import Path

from crawler.normalize import dedupe, normalize_name
from crawler.sources import kawabou
from crawler.sources.base import CameraCandidate
from crawler.validate import validate_camera_record

FIXTURES = Path(__file__).parent / "fixtures"


def test_extract_scam_ids():
    html = (FIXTURES / "mlit_ktr_keihin_tamagawa.html").read_text(encoding="utf-8")
    ids = kawabou.extract_scam_ids_from_html(html)
    assert len(ids) >= 20, f"多摩川ページから20件以上のscamIdが取れるはず: {len(ids)}"
    assert 221320015 in ids


def test_candidate_from_obsinfo():
    obs = json.loads((FIXTURES / "kawabou_scam_221320015.json").read_text(encoding="utf-8"))["obsInfo"]
    cand = kawabou.candidate_from_obsinfo(obs, 221320015, id_prefix="mlit-ktr")
    assert cand is not None
    assert cand.feed_type == "still_image"
    assert cand.feed_url.startswith("https://cam.river.go.jp/")
    assert cand.coord_accuracy == "exact"
    assert abs(cand.lat - 35.5367) < 0.01
    assert cand.prefecture == "14"
    assert cand.municipality == "14130"      # 川崎市
    assert cand.river_or_route == "多摩川"

    rec = cand.to_record("2026-08-17")
    assert validate_camera_record(rec) == []


def test_pref_jis_hokkaido():
    assert kawabou.pref_jis(101) == "01"
    assert kawabou.pref_jis(105) == "01"
    assert kawabou.pref_jis(4701) == "47"


def test_normalize_name():
    assert normalize_name("１.多摩川河口水位観測所（川崎市川崎区殿町）") == "多摩川河口水位観測所"
    assert normalize_name("田園調布（上）ライブカメラ") == "田園調布"


def _cand(id_, name, url, lat=None, lng=None):
    return CameraCandidate(
        id=id_, name=name, category="river", prefecture="13",
        feed_type="still_image", feed_url=url, operator="x",
        page_url="https://example.jp/", attribution="出典：x",
        lat=lat, lng=lng)


def test_dedupe_url_exact():
    a = _cand("a-1", "多摩川A", "https://cam.example.jp/1.jpg")
    b = _cand("b-1", "多摩川A別名", "https://cam.example.jp/1.jpg")
    assert [c.id for c in dedupe([a, b])] == ["a-1"]


def test_dedupe_near_similar_flags_but_keeps():
    a = _cand("a-1", "田園調布(上)", "https://cam.example.jp/1.jpg", 35.5942, 139.6647)
    b = _cand("b-1", "田園調布（上）", "https://cam.example.jp/2.jpg", 35.59421, 139.66471)
    out = dedupe([a, b])
    assert len(out) == 2
    assert "重複疑い" in out[0].review_note and "重複疑い" in out[1].review_note
