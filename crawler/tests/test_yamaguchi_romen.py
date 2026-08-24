"""yamaguchi_romen 解決ヘルパーのテスト。"""

from pathlib import Path

from crawler.sources.yamaguchi_romen import BASE, resolve_image_urls

FIXTURE = Path(__file__).parent / "fixtures" / "yamaguchi_romen_index.html"


def test_resolve_image_urls():
    got = resolve_image_urls(FIXTURE.read_text(encoding="utf-8"))
    assert set(got) == {"C044A", "C0422", "C0401"}
    url, iso = got["C0422"]
    assert url == "https://www.cgr.mlit.go.jp/yamaguchi/romen/douroimage/20260824/1030/C0422.jpg"
    assert iso == "2026-08-24T10:30:00+09:00"
    # 地点コードと画像ファイル名が一致しない地点（宇田）は img src を優先する
    assert got["C0401"][0].endswith("/douroimage/20260824/1030/C0437.jpg")


def test_resolve_empty():
    assert resolve_image_urls("<html>no tables</html>", BASE) == {}


def test_time_fallback_from_url():
    html = ('<table class="point_table"><tr><th><a name="C9999">x</a></th></tr>'
            '<tr><td><img src="/yamaguchi/romen/douroimage/20260101/0740/C9999.jpg"/></td></tr>'
            '</table>')
    got = resolve_image_urls(html, BASE)
    assert got["C9999"][1] == "2026-01-01T07:40:00+09:00"
