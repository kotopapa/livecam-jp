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
    assert images == [("C01838", "https://www.ktr.mlit.go.jp/river/cctv/C01838.jpg")]
    assert page_camera_name(html) == "国道4号 栃福橋南"


def test_sobu_index_is_camera_page_too():
    html = read("mlit_ktr_road_sobu_index.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/sobu/sobu_index018.html")
    assert ("C01671", "https://www.ktr.mlit.go.jp/river/cctv/C01671.jpg") in images
    assert page_camera_name(html) == "大垂水区間"
    links = extract_camera_links(
        html, "https://www.ktr.mlit.go.jp/sobu/sobu_index018.html", "sobu")
    urls = [u for u, _ in links]
    assert "https://www.ktr.mlit.go.jp/sobu/sobu00063.html" in urls
    assert "https://www.ktr.mlit.go.jp/sobu/sobu00064.html" in urls


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
    assert images == [("C01770", "https://www.ktr.mlit.go.jp/river/cctv/C01770.jpg")]
    assert "幸魂大橋" in page_camera_name(cam)
    assert extract_address_hint(cam) == "埼玉県和光市新倉5丁目"


def test_takasaki_river_camera_on_road_page():
    html = read("mlit_ktr_road_takasaki_detail.html")
    images = extract_cctv_images(html, "https://www.ktr.mlit.go.jp/takasaki/x.html")
    assert images == [("C02030", "https://www.ktr.mlit.go.jp/river/cctv/C02030.jpg")]
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
