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


def test_tokyo_suibo_csv():
    from crawler.sources.tokyo_suibo import parse_csv
    text = (FIXTURES / "tokyo_suibo_cameras.csv").read_text(encoding="utf-8")
    rows = parse_csv(text)
    assert len(rows) >= 100, f"東京都水防は100台以上のはず: {len(rows)}"
    r = rows[0]
    assert r["name"] == "飯田橋" and r["river"] == "神田川"
    assert r["video_id"] == "8p11ESAA15w"
    assert abs(r["lat"] - 35.70286) < 0.001


def test_youtube_live_streams_extract():
    from crawler.sources.youtube_live import (clean_title, extract_live_streams,
                                              stable_id)
    html = (FIXTURES / "youtube_live_streams.html").read_text(encoding="utf-8")
    streams = extract_live_streams(html)
    assert dict(streams) == {"AbC123xYz01": "【ライブ配信】那賀川 加茂谷",
                             "DeF456uVw02": "肱川 野村ダム左岸直下流 ライブカメラ"}
    assert clean_title("【ライブ配信】那賀川 加茂谷") == "那賀川 加茂谷"
    assert clean_title("肱川 野村ダム左岸直下流 ライブカメラ") == "肱川 野村ダム左岸直下流"
    # 安定ID: videoIdに依存せず、タイトルが同じなら同じID
    a = stable_id("skr", "UC1", "那賀川 加茂谷")
    assert a == stable_id("skr", "UC1", "那賀川 加茂谷")
    assert a != stable_id("skr", "UC1", "別の地点")


def test_refresh_approved_feeds():
    from crawler.main import refresh_approved_feeds
    cam = {"id": "yt-skr-abc", "feed": {"type": "youtube_video", "url": "OLD_ID"},
           "fallback": {"type": "web_page", "url": "https://youtube.com/watch?v=OLD_ID"},
           "last_updated": "2026-08-01"}
    rec = {"id": "yt-skr-abc", "feed": {"type": "youtube_video", "url": "NEW_ID"},
           "fallback": {"type": "web_page", "url": "https://youtube.com/watch?v=NEW_ID"},
           "last_updated": "2026-08-18"}
    n = refresh_approved_feeds([cam], [rec])
    assert n == 1 and cam["feed"]["url"] == "NEW_ID"
    assert cam["fallback"]["url"].endswith("NEW_ID")
    # still_image は対象外
    cam2 = {"id": "x", "feed": {"type": "still_image", "url": "a.jpg"}}
    rec2 = {"id": "x", "feed": {"type": "still_image", "url": "b.jpg"}}
    assert refresh_approved_feeds([cam2], [rec2]) == 0


def test_kkr_youtube_channels():
    from crawler.sources.mlit_youtube import extract_channels
    html = (FIXTURES / "mlit_kkr_youtube.html").read_text(encoding="utf-8",
                                                          errors="replace")
    channels = extract_channels(html, "https://www.kkr.mlit.go.jp/river/bousai/livecamera.html")
    ids = {c for c, _ in channels if c.startswith("UC")}
    assert len(ids) >= 14, f"近畿は14水系チャンネル以上のはず: {len(ids)}"
    assert "UCUGXTjGtxRHyoeTHHXCBSqg" in ids   # 淀川・宇治川


def test_curated_youtube_yaml():
    from crawler.sources.curated_youtube import CuratedYoutubeParser, load_curated
    cams = load_curated()
    assert len(cams) >= 15
    ids = [c["id"] for c in cams]
    assert len(ids) == len(set(ids)), "IDは一意であること"
    assert all(c.get("operator") for c in cams), "運営者不明のカメラは載せない"
    result = CuratedYoutubeParser().discover(None)
    assert len(result.candidates) == len(cams) and not result.errors
    shibuya = next(c for c in result.candidates if c.id == "curated-shibuya-ann")
    assert shibuya.feed_type == "youtube_video" and shibuya.coord_accuracy == "approx"
    assert validate_camera_record(shibuya.to_record("2026-08-18")) == []


def test_muni_youtube_extract():
    from crawler.sources.muni_youtube import clean_spot_name, extract_video_links
    html = (FIXTURES / "muni_ohtawara.html").read_text(encoding="utf-8", errors="replace")
    links = extract_video_links(html, "https://www.city.ohtawara.tochigi.jp/docs/2013082781499/")
    ids = dict(links)
    assert "OLLd7YiM3Tk" in ids, "蛇尾橋のvideoIdが取れるはず"
    assert len(ids) >= 8

    yoko = (FIXTURES / "muni_yokosuka_area01.html").read_text(encoding="utf-8", errors="replace")
    ylinks = extract_video_links(yoko, "https://www.city.yokosuka.kanagawa.jp/camera/area_01/index.html")
    assert len(ylinks) >= 9
    assert clean_spot_name("蛇尾橋付近（外部リンク）") == "蛇尾橋付近"


def test_mbc_webcam_extract():
    from crawler.sources.mbc_webcam import categorize, extract_cameras
    html = (FIXTURES / "mbc_webcam.html").read_text(encoding="utf-8", errors="replace")
    cams = extract_cameras(html)
    assert len(cams) >= 80, f"MBCはcamTitle付き85地点のはず: {len(cams)}"
    titles = [c["camTitle"] for c in cams]
    assert "国道10号 竜ヶ水" in titles
    assert categorize("国道10号 竜ヶ水", None) == "road"
    assert categorize("桜島（牛根麓）", None) == "volcano"
    assert categorize("甲突川", "甲突川") == "river"


def test_hbc_webcam_extract():
    from crawler.sources.hbc_webcam import extract_point, extract_point_links
    html = (FIXTURES / "hbc_cam_list.html").read_text(encoding="utf-8", errors="replace")
    links = extract_point_links(html, "https://www.hbc.co.jp/info-cam/cam_list.html")
    assert len(links) >= 15
    assert ("https://www.hbc.co.jp/info-cam/sapporo.html", "札幌") in links

    sap = (FIXTURES / "hbc_cam_sapporo.html").read_text(encoding="utf-8", errors="replace")
    img, lat, lng = extract_point(sap)
    assert img == "sapporohd"
    # !2z（マーカー実位置のDMS）を優先して使う。!2d/!3d はビューポート中心で
    # ズームによっては海上など大きくずれる（稚内で経度1.1度西など）
    assert abs(lat - 43.061194) < 1e-6 and abs(lng - 141.352389) < 1e-6


def test_hbc_webcam_marker_dms_decode():
    from crawler.sources.hbc_webcam import decode_marker_dms
    # 43°03'40.3"N 141°21'08.6"E の base64
    assert decode_marker_dms("NDPCsDAzJzQwLjMiTiAxNDHCsDIxJzA4LjYiRQ") == \
        (43.061194, 141.352389)
    assert decode_marker_dms("not-base64!!") is None


def test_kaiho_webcam_extract():
    from crawler.sources.kaiho_webcam import GAZOU_RE, LINK_RE, NAME_COORDS
    hub = (FIXTURES / "kaiho_live.html").read_text(encoding="utf-8", errors="replace")
    links = [(u, t.strip()) for u, t in LINK_RE.findall(hub)]
    assert len(links) == 12
    names = {t for _, t in links}
    assert names <= set(NAME_COORDS), f"対応表にない地点: {names - set(NAME_COORDS)}"

    point = (FIXTURES / "kaiho_point.html").read_text(encoding="utf-8", errors="replace")
    m = GAZOU_RE.search(point)
    assert m and m.group(1).endswith("gazou/tsurugisaki_lt.jpg")


def test_toyama_road_parse():
    from crawler.sources.toyama_road import parse_master
    raw = (FIXTURES / "toyama_camera_master.json").read_text(encoding="utf-8")
    cams = parse_master(raw)
    assert len(cams) == 5
    num, rec = cams[0]
    assert num.isdigit()
    assert float(rec["lat"]) > 35 and float(rec["lng"]) > 136
    assert rec["path"] == "kl/camimg/"


def test_hiroshima_road_parse():
    from crawler.sources.hiroshima_road import parse_list
    html = (FIXTURES / "hiroshima_camera_list.html").read_text(encoding="utf-8")
    cams = parse_list(html)
    assert len(cams) >= 10
    first = cams[0]
    assert first["id"].isdigit()
    assert first["point"]
    assert first["titen"]  # 住所（ジオコーディングに使う）


def test_fukushima_road_parse():
    from crawler.sources.fukushima_road import parse_cameras
    html = (FIXTURES / "fukushima_aizu.html").read_bytes().decode("cp932", "replace")
    cams = parse_cameras(html)
    assert len(cams) >= 8
    byid = {c["id"]: c for c in cams}
    assert byid["63"]["name"] == "三島町 宮下"
    assert byid["63"]["route"] == "国道252号"


def test_curated_world_yaml():
    from crawler.sources.curated_world import CuratedWorldParser, load_world
    cams = load_world()
    assert len(cams) >= 30
    ids = [c["id"] for c in cams]
    assert len(ids) == len(set(ids))
    result = CuratedWorldParser().discover(None)
    assert len(result.candidates) == len(cams) and not result.errors
    c = result.candidates[0]
    assert c.prefecture == "99" and c.country and len(c.country) == 2
    assert validate_camera_record(c.to_record("2026-08-19")) == []


def test_shimane_road_parse():
    from crawler.sources.shimane_road import parse_points
    raw = (FIXTURES / "shimane_point.json5").read_text(encoding="utf-8")
    pts = parse_points(raw)
    assert len(pts) >= 100
    p = pts[0]
    assert p["point_id"] == "0101" and p["name"] == "大川端"
    assert 34 < p["lat"] < 37 and 131 < p["lng"] < 134
