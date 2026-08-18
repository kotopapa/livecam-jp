"""関東地整・道路カメラパーサのフィクスチャ回帰テスト。

フィクスチャは2026-08-18取得。サイト構造が変わったら再取得して差分を見ること。
"""

from pathlib import Path

from crawler.sources.base import CameraCandidate
from crawler.sources.mlit_ktr_road import (extract_address_hint,
                                           extract_camera_links,
                                           extract_cctv_images,
                                           page_camera_name)
from crawler.validate import validate_camera_record

FIXTURES = Path(__file__).parent / "fixtures"


def read(name: str) -> str:
    raw = (FIXTURES / name).read_bytes()
    for enc in ("utf-8", "cp932"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def test_utsunomiya_index_links():
    html = read("mlit_ktr_road_utsunomiya_index.html")
    links = extract_camera_links(
        html, "https://www.ktr.mlit.go.jp/utunomiya/utunomiya_index002.html", "utunomiya")
    urls = [u for u, _ in links]
    assert len(urls) >= 14, f"宇都宮の一覧から14件以上の詳細リンクが取れるはず: {len(urls)}"
    assert "http://www.ktr.mlit.go.jp/utunomiya/utunomiya00306.html" in urls
    # area の alt がリンクテキストとして拾えている
    texts = dict(links)
    assert texts["http://www.ktr.mlit.go.jp/utunomiya/utunomiya00306.html"] == "国道４号 栃福橋南"


def test_utsunomiya_detail_camera():
    html = read("mlit_ktr_road_utsunomiya_detail.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/utunomiya/utunomiya00306.html")
    assert images == [("C01838", "https://www.ktr.mlit.go.jp/river/cctv/C01838.jpg",
                       "国道4号 栃福橋南")]
    assert page_camera_name(html) == "国道4号 栃福橋南"


def test_sobu_detail_is_camera_page_too():
    html = read("mlit_ktr_road_sobu_index.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/sobu/sobu00063.html")
    assert ("C01671", "https://www.ktr.mlit.go.jp/river/cctv/C01671.jpg",
            "大垂水区間") in images
    assert page_camera_name(html) == "大垂水区間"
    links = extract_camera_links(
        html, "https://www.ktr.mlit.go.jp/sobu/sobu00063.html", "sobu")
    urls = [u for u, _ in links]
    assert "https://www.ktr.mlit.go.jp/sobu/sobu00064.html" in urls


def test_sobu_live_index_multi_camera_alt_names():
    """一覧ページに複数カメラのimgが直接並ぶケース（altから個別名を取る）。"""
    html = read("mlit_ktr_road_sobu_index_live.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/sobu/sobu_index018.html")
    named = {c: alt for c, _, alt in images}
    assert named["C01671"] == "大垂水区間"
    assert named["C01685"] == "相模湖区間"


def test_kitasyuto_menu_and_camera_page():
    menu = read("mlit_ktr_road_kitasyuto_menu.html")
    links = extract_camera_links(
        menu, "https://www.ktr.mlit.go.jp/kitasyuto/public/CCTV_L.html", "kitasyuto")
    cam_links = [(u, t) for u, t in links if "CAM_" in u]
    assert len(cam_links) >= 20, f"北首都メニューから20件以上: {len(cam_links)}"
    # href に丸括弧を含むURLも拾えること
    assert any("(" in u for u, _ in cam_links)

    cam = read("mlit_ktr_road_kitasyuto_cam.html")
    images = extract_cctv_images(cam, "https://www.ktr.mlit.go.jp/kitasyuto/public/x.html")
    assert images == [("C01770", "https://www.ktr.mlit.go.jp/river/cctv/C01770.jpg", "")]
    assert "幸魂大橋" in page_camera_name(cam)
    assert extract_address_hint(cam) == "埼玉県和光市新倉5丁目"


def test_takasaki_river_camera_on_road_page():
    html = read("mlit_ktr_road_takasaki_detail.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/takasaki/x.html")
    assert images == [("C02030", "https://www.ktr.mlit.go.jp/river/cctv/C02030.jpg", "")]
    name = page_camera_name(html)
    assert "烏川" in name          # 河川カメラ混在の検知（RIVERISH_RE の対象）


def test_candidate_record_passes_schema():
    cand = CameraCandidate(
        id="mlit-ktr-road-c01838", name="国道4号 栃福橋南", category="road",
        prefecture="09", feed_type="still_image",
        feed_url="https://www.ktr.mlit.go.jp/river/cctv/C01838.jpg",
        operator="国土交通省 宇都宮国道事務所",
        page_url="https://www.ktr.mlit.go.jp/utunomiya/utunomiya00306.html",
        attribution="出典：国土交通省 関東地方整備局 宇都宮国道事務所",
        license="public_data_1.0",
        terms_url="https://www.ktr.mlit.go.jp/guide/copyright.html",
        river_or_route="国道4号", refresh_sec=600)
    assert validate_camera_record(cand.to_record("2026-08-18")) == []


def test_oomiya_district_table_pairing():
    from crawler.sources.mlit_ktr_road import oomiya_cameras
    html = read("mlit_ktr_road_oomiya_district.html")
    cams = oomiya_cameras(html, "https://www.ktr.mlit.go.jp/oomiya/oomiya00095.html")
    assert len(cams) >= 9, f"入間市高倉地区は9台のはず: {len(cams)}"
    named = {key: (name, link) for key, _, name, link in cams}
    assert named["25a"][0] == "小谷田交差点"
    assert named["25a"][1].endswith("/oomiya/oomiya00096.html")
    urls = {key: url for key, url, _, _ in cams}
    assert urls["25a"] == "https://www.ktr.mlit.go.jp/oomiya/livecamera/25_A.jpg"


def test_yokohama_left_position_pairing():
    from crawler.sources.mlit_ktr_road import yokohama_cameras
    html = read("mlit_ktr_road_yokohama.html")
    cams = yokohama_cameras(html, "https://www.ktr.mlit.go.jp/yokohama/live-camera/live.html")
    assert len(cams) == 2
    names = {key: name for key, _, name in cams}
    assert set(names.values()) == {"畑宿付近", "箱根峠付近"}


def test_koufu_spot_page():
    from crawler.sources.mlit_ktr_road import koufu_camera
    html = read("mlit_ktr_road_koufu_spot.html")
    cam = koufu_camera(html, "https://www.ktr.mlit.go.jp/koufu/livecamera/michi/mukawa.html")
    assert cam == ("11", "武川", "国道20号")


def test_koufu_index_links():
    from crawler.sources.mlit_ktr_road import KOUFU_LINK_RE
    from urllib.parse import urljoin, urlparse
    import re as _re
    html = read("mlit_ktr_road_koufu_index.html")
    links = {urljoin("https://www.ktr.mlit.go.jp/koufu/michi_camera/index.htm", h)
             for h in _re.findall(r'href="([^"]+\.html?)"', html)}
    spots = [u for u in links if KOUFU_LINK_RE.search(urlparse(u).path)]
    assert len(spots) >= 25, f"甲府の地点ページが25件以上取れるはず: {len(spots)}"


def test_nagano_map_layer_pairing():
    from crawler.sources.mlit_ktr_road import nagano_map_cameras
    html = read("mlit_ktr_road_nagano_map18.html")
    cams = nagano_map_cameras(
        html, "https://www.ktr.mlit.go.jp/nagano/douroinfo/road/html/map/cameraMap_18.html")
    assert len(cams) >= 15, f"R18マップから15台以上: {len(cams)}"
    named = {code: (url, alt) for code, url, alt in cams}
    assert "080139" in named
    assert named["080139"][1] == "信濃町野尻赤川"
    assert named["080139"][0] == \
        "https://www.ktr.mlit.go.jp/nagano/douroinfo/data/camera/cond_m/080139_L.jpg"


def test_prvs_coord_join():
    from crawler.sources.mlit_ktr_road import apply_prvs_coords, build_prvs_coord_maps
    data = {"10001&国道4号": [{"R_10001": {
        "doro_gazo_joho_kanri_id": "83C01838", "image_name": "栃福橋南",
        "gis_point": ["140.1394444", "37.10361111"],
        "todofuken_cd": "09", "cities_cd": "09407", "fileList": []}}]}
    by_c, by_name = build_prvs_coord_maps(data)
    assert "C01838" in by_c and "栃福橋南" in by_name

    from crawler.sources.base import CameraCandidate
    def cand(id_, name, url):
        return CameraCandidate(id=id_, name=name, category="road", prefecture="13",
                               feed_type="still_image", feed_url=url, operator="x",
                               page_url="https://example.jp/", attribution="出典：x")
    a = cand("a", "国道4号 栃福橋南", "https://www.ktr.mlit.go.jp/river/cctv/C01838.jpg")  # C番号一致
    b = cand("b", "栃福橋南交差点", "https://www.ktr.mlit.go.jp/oomiya/livecamera/25_A.jpg")  # 名称包含
    c = cand("c", "無関係", "https://www.ktr.mlit.go.jp/oomiya/livecamera/26_A.jpg")
    n = apply_prvs_coords([a, b, c], by_c, by_name)
    assert n == 2
    assert a.coord_accuracy == "exact" and abs(a.lat - 37.1036) < 0.001
    assert a.prefecture == "09" and a.municipality == "09407"
    assert b.coord_accuracy == "exact"
    assert c.lat is None


def test_address_from_name():
    from crawler.sources.mlit_ktr_road import address_from_name
    assert address_from_name("春日部市梅田本町二丁目 梅田陸橋(下り線)", "埼玉県") == "埼玉県春日部市梅田本町二丁目"
    assert address_from_name("さいたま市桜区田島 田島地下道(上り線12)", "埼玉県") == "埼玉県さいたま市桜区田島"
    assert address_from_name("烏川（城南大橋） 高崎市新後閑町", "群馬県") == "群馬県高崎市新後閑町"
    assert address_from_name("国道4号 栃福橋南", "栃木県") is None
