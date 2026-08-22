"""kochi_suibo 解決ヘルパーのテスト。"""

from crawler.sources.kochi_suibo import resolve_image_url

PAGE = "https://suibo-kouho.suibou.pref.kochi.lg.jp/sp/static/camera/itv_detail_34.html"
HTML = '''
<script>
var obstime = "1027";
var url_pc = "/suibou";
var itvNo = "034";
var actionFlag =0;
</script>
'''


def test_resolve_image_url():
    hit = resolve_image_url(PAGE, HTML)
    assert hit is not None
    url, obstime = hit
    assert url == ("https://suibo-kouho.suibou.pref.kochi.lg.jp"
                   "/suibou/camera/img/034_1027.jpg")
    assert obstime == "1027"


def test_resolve_missing_vars():
    assert resolve_image_url(PAGE, "<html>no vars</html>") is None
