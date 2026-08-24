"""shimanto_kasen 解決ヘルパーのテスト。"""

from pathlib import Path

from crawler.sources.shimanto_kasen import (RESULT_TIME_URL, parse_points,
                                            resolve_image_url)

FIXTURES = Path(__file__).parent / "fixtures"


def test_resolve_image_url():
    hit = resolve_image_url(RESULT_TIME_URL, "point16", "202608250723")
    assert hit is not None
    url, iso = hit
    assert url == "http://kasen.midwest-kochi.jp/shimanto/point16/202608250723.jpg"
    assert iso == "2026-08-25T07:23:00+09:00"


def test_resolve_rejects_garbage():
    assert resolve_image_url(RESULT_TIME_URL, "point16", "<html>error</html>") is None
    assert resolve_image_url(RESULT_TIME_URL, "../etc", "202608250723") is None
    assert resolve_image_url(RESULT_TIME_URL, "point16", "") is None


def test_parse_points_from_index():
    html = (FIXTURES / "shimanto_kasen_index.html").read_text(encoding="utf-8")
    pts = parse_points(html)
    assert len(pts) == 17
    assert pts["point5"] == "松葉川"
    assert pts["point8"] == "興津（郷分）"
    assert pts["point17"] == "志和川"


def test_curated_yaml_covers_all_points():
    from crawler.sources.curated_still import load_curated
    html = (FIXTURES / "shimanto_kasen_index.html").read_text(encoding="utf-8")
    pts = parse_points(html)
    cams = [c for c in load_curated() if c.get("feed_type") == "shimanto_kasen"]
    assert {c["camera_ref"] for c in cams} == set(pts)
    for c in cams:
        assert c["feed_url"] == RESULT_TIME_URL
        assert pts[c["camera_ref"]] in c["name"]
