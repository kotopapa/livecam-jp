"""niigata_road パーサの回帰テスト。

2026-08-21にサイト側がhrefの先頭スラッシュを外し
（/camera/pc/x.jpg → camera/pc/x.jpg）、CAM_REが不一致で0件になった。
両表記を受理することを固定する。
"""

from crawler.sources.niigata_road import CAM_RE, parse_top

HTML_SLASH = ("<a id='498' class='ad/,,寒川,,２分間隔,新潟県土木部,"
              "http://www.pref.niigata.lg.jp/doboku/' href='/camera/pc/kangawa.jpg'"
              " title='一般国道３４５号　寒川'>")
HTML_NOSLASH = ("<a id='497' class='ad/,,干溝,,２分間隔,新潟県土木部,"
                "http://www.pref.niigata.lg.jp/doboku/' href='camera/pc/himizo.jpg'"
                " title='一般国道２９１号　干溝'>")


def test_parse_top_accepts_both_href_forms():
    rows = parse_top(HTML_SLASH + HTML_NOSLASH)
    assert len(rows) == 2
    hrefs = [h for _, h, _ in rows]
    assert "/camera/pc/kangawa.jpg" in hrefs
    assert "camera/pc/himizo.jpg" in hrefs
    assert all(op == "新潟県土木部" for _, _, op in rows)


def test_cam_re_ignores_other_links():
    assert not CAM_RE.findall("<a id='1' class='x' href='/other/x.jpg' title='t'>")
