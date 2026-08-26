"""真っ暗画像の検知テスト。"""
import io
from datetime import datetime, timezone

from PIL import Image, ImageDraw

from monitor.freeze import is_black_frame, is_local_daytime


def _jpeg(color, text=None):
    img = Image.new("RGB", (720, 480), color)
    if text:
        ImageDraw.Draw(img).text((150, 20), text, fill=(230, 230, 230))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_black_with_timestamp_is_black():
    assert is_black_frame(_jpeg((12, 12, 12), "2026-08-27 08:10:15 羽咋土木 子浦川"))


def test_normal_scene_is_not_black():
    assert not is_black_frame(_jpeg((90, 120, 80)))


def test_night_scene_with_lights_is_not_black():
    img = Image.new("RGB", (720, 480), (10, 10, 10))
    d = ImageDraw.Draw(img)
    for x in range(0, 720, 40):
        d.rectangle([x, 200, x + 20, 260], fill=(200, 200, 160))
    buf = io.BytesIO(); img.save(buf, format="JPEG")
    assert not is_black_frame(buf.getvalue())


def test_local_daytime_by_longitude():
    # 石川県(東経137度)の 08:10 JST = 23:10 UTC 前日 → 地方時 ≒ 08:18 → 9時前なので夜扱い
    assert not is_local_daytime(datetime(2026, 8, 26, 23, 10, tzinfo=timezone.utc), 137.0)
    # 10:30 JST = 01:30 UTC → 地方時 ≒ 10:38 → 日中
    assert is_local_daytime(datetime(2026, 8, 27, 1, 30, tzinfo=timezone.utc), 137.0)
    assert not is_local_daytime(datetime(2026, 8, 27, 1, 30, tzinfo=timezone.utc), None)
