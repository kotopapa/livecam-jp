"""みち情報ネットふくい パーサの回帰テスト。"""

from pathlib import Path

from crawler.sources.fukui_road import parse_cameras

FIXTURE = Path(__file__).parent / "fixtures" / "fukui_cameras.json"


def test_image_url_uses_data_image_not_record_id():
    # 実例(2026-08-29 坂東島): 台帳 id=573 だが画像は data.image=586.jpg。
    # id をファイル名に使うと他カメラの古い画像を指す
    cams = {c["id"]: c for c in parse_cameras(FIXTURE.read_text(encoding="utf-8"))}
    assert cams[1]["data"]["image"].endswith("/2.jpg")      # id=1 栂野 → 2.jpg
    assert cams[361]["data"]["image"].endswith("/85.jpg")   # id=361 金津IC → 85.jpg
