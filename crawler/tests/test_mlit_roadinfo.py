"""道路情報提供システム(road-info-prvs)パーサのフィクスチャ回帰テスト。"""

from pathlib import Path

from crawler.sources.base import CameraCandidate
from crawler.sources.mlit_roadinfo import (extract_kokudo_json, iter_cameras,
                                           latest_image, resolve_image_urls)
from crawler.validate import validate_camera_record

FIXTURES = Path(__file__).parent / "fixtures"
PAGE = (FIXTURES / "mlit_roadinfo_pcimage_88.html").read_text(encoding="utf-8",
                                                              errors="replace")


def test_extract_and_iterate():
    data = extract_kokudo_json(PAGE)
    assert data is not None
    cams = list(iter_cameras(data))
    assert len(cams) >= 20, f"四国(88)は21台のはず: {len(cams)}"
    tanbara = next(c for c in cams if c["doro_gazo_joho_kanri_id"] == "8293013B")
    assert tanbara["image_name"] == "丹原千原"
    assert tanbara["todofuken_cd"] == "38" and tanbara["cities_cd"] == "38206"
    lng, lat = float(tanbara["gis_point"][0]), float(tanbara["gis_point"][1])
    assert 132 < lng < 134 and 33 < lat < 35   # 経度・緯度の順序を担保


def test_latest_image_and_resolver():
    data = extract_kokudo_json(PAGE)
    cam = next(c for c in iter_cameras(data)
               if c["doro_gazo_joho_kanri_id"] == "8293013B")
    url, at = latest_image(cam)
    assert url.startswith(
        "https://www.road-info-prvs.mlit.go.jp/roadinfo/img/doro_gazo/pc/")
    assert url.endswith("s_8293013B.jpeg") and at

    resolved = resolve_image_urls(PAGE)
    assert resolved["8293013B"][0] == url


def test_candidate_record_passes_schema():
    cand = CameraCandidate(
        id="mlit-roadinfo-8293013b", name="丹原千原", category="road",
        prefecture="38", municipality="38206", feed_type="mlit_roadinfo",
        feed_url="https://www.road-info-prvs.mlit.go.jp/roadinfo/pc/pcImage_88_1.html",
        camera_ref="8293013B",
        operator="国土交通省 四国地方整備局",
        page_url="https://www.road-info-prvs.mlit.go.jp/roadinfo/pc/pcImage_88_1.html",
        attribution="出典：国土交通省 四国地方整備局（道路情報提供システム）",
        license="unknown", terms_url="https://www.mlit.go.jp/link.html",
        river_or_route="国道11号", refresh_sec=900,
        lat=33.82527778, lng=132.9880556, coord_accuracy="exact")
    rec = cand.to_record("2026-08-18")
    assert rec["feed"]["camera_ref"] == "8293013B"
    assert validate_camera_record(rec) == []


def test_monitor_roadinfo_requires_resolution():
    """事前解決がなければ失敗として数える（誤ってfeed.urlを画像として叩かない）。"""
    from datetime import datetime, timezone
    from monitor.check import check_camera
    camera = {"feed": {"type": "mlit_roadinfo",
                       "url": "https://example.jp/pcImage_88_1.html",
                       "camera_ref": "8293013B", "headers": {}},
              "source": {"page_url": "https://example.jp/"}}
    result = check_camera(None, camera, {}, now=datetime.now(timezone.utc))
    assert result["state"] in ("unknown", "error")
    assert result["consecutive_failures"] == 1
