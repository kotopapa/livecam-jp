"""JWA製「川の防災情報」テンプレート（埼玉・和歌山）jwa_river_cam のテスト。"""

from pathlib import Path

from crawler.sources.jwa_river_cam import (SITES, JwaRiverCamParser, decode_csv,
                                           parse_camera_list, parse_geojson,
                                           split_csv_name, split_name)
from crawler.validate import validate_camera_record

FX = Path(__file__).parent / "fixtures"
SAITAMA = "https://suibo-river.pref.saitama.lg.jp/"
WAKAYAMA = "https://kasensabo01.pref.wakayama.lg.jp/"

FILES = {
    SAITAMA + "geojson/saitama_camera.geojson": FX / "jwa_river_saitama_camera.geojson",
    SAITAMA + "chitenconfig/CameraList.csv": FX / "jwa_river_saitama_CameraList.csv",
    WAKAYAMA + "geojson/wakayama_camera.geojson": FX / "jwa_river_wakayama_camera.geojson",
    WAKAYAMA + "chitenconfig/CameraList.csv": FX / "jwa_river_wakayama_CameraList.csv",
}


class FakeSession:
    def __init__(self):
        self.urls = []

    def fetch(self, url):
        self.urls.append(url)
        path = FILES[url]

        class P:
            ok = True
            status = 200
            content = path.read_bytes()

            @property
            def text(self):
                return decode_csv(self.content)
        return P()


def test_helpers():
    assert split_name("古東橋(ことうばし)") == ("古東橋", "ことうばし")
    assert split_name("橋本川（はしもとがわ）") == ("橋本川", "はしもとがわ")
    assert split_name("青木水門") == ("青木水門", "")
    assert split_csv_name("橋本川　古東橋　水位観測所") == ("古東橋", "橋本川")
    assert split_csv_name("貴志川　小川橋（左岸）") == ("小川橋（左岸）", "貴志川")
    assert split_csv_name("青木水門(芝川・新芝川)") == ("青木水門", "芝川・新芝川")

    # 和歌山CSVはEUC-JP。復号して列が正しく取れる
    rows = parse_camera_list(decode_csv((FX / "jwa_river_wakayama_CameraList.csv").read_bytes()))
    assert rows[0]["office"] == "伊都振興局" and rows[0]["up_id"] == "C01500"
    assert rows[1]["down_id"] == "C11151" and rows[1]["down_flag"] == "1"
    pts = parse_geojson((FX / "jwa_river_wakayama_camera.geojson").read_text(encoding="utf-8"))
    assert ("502", "1") in pts and ("502", "2") in pts, "水位局とダムで同じ観測点番号"


def test_discover_saitama():
    parser = JwaRiverCamParser(sites=["saitama"], existing=[])
    result = parser.discover(FakeSession())
    assert not result.errors
    ids = [c.id for c in result.candidates]
    assert len(ids) == len(set(ids)) == 6
    c = next(c for c in result.candidates if c.id == "jwa-river-saitama-55201100150")
    assert c.name == "青木水門" and c.name_kana == "あおきすいもん"
    assert c.river_or_route == "芝川・新芝川"
    assert c.feed_type == "still_image"
    assert c.feed_url == SAITAMA + "hyoujidata/camera/55201100150.jpg"
    assert c.lat == 35.82152778 and c.lng == 139.7274722 and c.coord_accuracy == "exact"
    assert c.prefecture == "11" and c.operator == "埼玉県" and c.license == "unknown"
    assert c.terms_url == SITES["saitama"]["terms_url"]
    assert c.address_hint == "川口市辻"
    assert c.refresh_sec == 600
    assert validate_camera_record(c.to_record("2026-08-29")) == []


def test_discover_wakayama_downstream_and_dup_codes():
    parser = JwaRiverCamParser(sites=["wakayama"], existing=[])
    result = parser.discover(FakeSession())
    assert not result.errors
    by_id = {c.id: c for c in result.candidates}
    assert len(by_id) == len(result.candidates)
    # 上流側/下流側は別候補
    up, down = by_id["jwa-river-wakayama-c10151"], by_id["jwa-river-wakayama-c11151"]
    assert up.name == "北馬場（上流側）" and down.name == "北馬場（下流側）"
    assert up.river_or_route == "橋本川" and up.name_kana == "きたばば"
    assert up.lat == down.lat and up.coord_accuracy == "exact"
    assert down.feed_url == WAKAYAMA + "hyoujidata/camera/C11151.jpg"
    # 同じ観測点番号502を水位局(1)とダム(2)で使い回し → 種別で結合し座標が別
    kawabe = by_id["jwa-river-wakayama-c00400"]
    dam = by_id["jwa-river-wakayama-c04300"]
    assert kawabe.name == "川辺" and kawabe.category == "river" and kawabe.lat == 33.922966
    assert dam.name == "切目川ダム（上流側）" and dam.category == "dam" and dam.lat == 33.882115
    # geojsonに無い地点は座標なし(pending)
    ogawa = by_id["jwa-river-wakayama-c04900"]
    assert ogawa.lat is None and ogawa.coord_accuracy is None
    assert ogawa.name == "小川橋（左岸）" and "座標なし" in ogawa.review_note
    # geojsonにしか無い地点(K03161)は画像が特定できないので候補にしない
    assert not any("k03161" in i for i in by_id)
    for c in result.candidates:
        assert validate_camera_record(c.to_record("2026-08-29")) == []


def test_existing_url_skip_and_kawabou_dup_note():
    existing = [
        {   # curated_still で採用済み（和歌山）→ 同一URLはスキップ
            "id": "curated-still-lcdb-9b5f61e0", "name": "日高川野口橋上流側",
            "prefecture": "30", "lat": 33.905139, "lng": 135.175611, "operator": "和歌山県庁",
            "feed": {"type": "still_image",
                     "url": WAKAYAMA + "hyoujidata/camera/C10558.jpg"},
        },
        {   # kawabou 経由の埼玉県カメラ → 150m以内・名称類似で note
            "id": "kawabou-102817099", "name": "青木水門観測局", "prefecture": "11",
            "lat": 35.8216, "lng": 139.7275, "operator": "埼玉県",
            "feed": {"type": "still_image", "url": "https://cam.river.go.jp/cam/now/102817099.jpg"},
        },
        {   # 近いが名前が違う → 重複候補にしない
            "id": "kawabou-102817098", "name": "鴨川排水機場観測局", "prefecture": "11",
            "lat": 35.8216, "lng": 139.7275, "operator": "埼玉県",
            "feed": {"type": "still_image", "url": "https://cam.river.go.jp/cam/now/102817098.jpg"},
        },
        {   # さいたま市 saitama_flood と同一カメラ → スキップ
            "id": "saitama-flood-003", "name": "日進上", "prefecture": "11",
            "lat": 35.92855556, "lng": 139.5989722, "operator": "さいたま市",
            "feed": {"type": "saitama_flood", "url": "https://www.flood-info.city.saitama.jp/data/camera_latest.json"},
        },
    ]
    result = JwaRiverCamParser(existing=existing).discover(FakeSession())
    by_id = {c.id: c for c in result.candidates}
    assert "jwa-river-wakayama-c10558" not in by_id      # 既存IDを尊重
    assert "jwa-river-wakayama-c11558" in by_id          # 下流側は未採用なので候補化
    assert "jwa-river-saitama-55201100013" not in by_id  # saitama_flood と同一
    aoki = by_id["jwa-river-saitama-55201100150"]
    assert "kawabou重複候補: kawabou-102817099" in aoki.review_note
    assert "kawabou-102817098" not in aoki.review_note
    assert not any("kawabou重複候補" in c.review_note
                   for c in result.candidates if c.id != aoki.id)
