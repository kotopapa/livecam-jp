"""sizenken 解決ヘルパーのテスト。"""

from crawler.sources.sizenken import resolve_image_url

PAGE = "https://www.sizenken.biodic.go.jp/view_new.php?no=85"
HTML = '''
<img src="camera_img/85_c/image/2026/08/25/NCS20260825060048060.jpg">
<img src="camera_img/85_c/image/2026/08/25/NCS20260825070048060.jpg" class="latest">
'''


def test_resolve_latest_image():
    hit = resolve_image_url(PAGE, HTML)
    assert hit is not None
    url, t = hit
    assert url == ("https://www.sizenken.biodic.go.jp/camera_img/85_c/image/"
                   "2026/08/25/NCS20260825070048060.jpg")
    assert t == "20260825070048"


def test_resolve_missing():
    assert resolve_image_url(PAGE, "<html>no image</html>") is None
