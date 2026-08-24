import io
from datetime import datetime, timedelta, timezone

from PIL import Image

from monitor.freeze import dhash64, hamming, judge_frozen, sunrise_utc


def _img(color) -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", (64, 48), color)
    # 単色はdHash全ビット0になるので勾配を足す
    for x in range(64):
        for y in range(4):
            img.putpixel((x, y), ((x * 4 + color[0]) % 256, color[1], color[2]))
    img.save(buf, "JPEG")
    return buf.getvalue()


def test_dhash_stable_and_sensitive():
    a1 = dhash64(_img((10, 20, 30)))
    a2 = dhash64(_img((10, 20, 30)))
    b = dhash64(_img((200, 100, 0)))
    assert a1 == a2
    assert hamming(a1, b) > 0


def test_dhash_bad_bytes():
    assert dhash64(b"not an image") is None


def test_sunrise_tokyo_plausible():
    # 東京(35.68, 139.75) 8月の日の出はUTCで19〜21時台（前日）= JST 4〜6時台
    sr = sunrise_utc(35.68, 139.75, datetime(2026, 8, 17).date())
    assert sr is not None
    jst_hour = (sr.hour + 9) % 24
    assert 4 <= jst_hour <= 6, f"JST日の出が4-6時のはず: {jst_hour}"


def _history(hours: float, n: int, same: bool, end: datetime):
    out = []
    for i in range(n):
        at = end - timedelta(hours=hours) * (n - 1 - i) / max(n - 1, 1)
        out.append({"at": at.isoformat(), "hash": 42 if same else 42 + i})
    return out


def test_frozen_requires_6h_and_sunrise_window():
    # 日の出(JST~5時)を確実に跨ぐよう、JST 12時 = UTC 3時 を現在とする
    now = datetime(2026, 8, 17, 3, 0, tzinfo=timezone.utc)
    lat, lng = 35.68, 139.75
    # 12時間同一・日の出(JST~5時)跨ぎ → frozen
    frozen, since = judge_frozen(_history(12, 24, True, now), now, lat, lng)
    assert frozen and since is not None
    # 12時間だが画像が変化 → ok
    frozen, _ = judge_frozen(_history(12, 24, False, now), now, lat, lng)
    assert not frozen
    # 3時間同一（6時間未満） → ok
    frozen, _ = judge_frozen(_history(3, 6, True, now), now, lat, lng)
    assert not frozen


def test_night_dark_not_frozen():
    # JST 23時 = UTC 14時。直近7時間(JST 16-23時)同一でも日の出窓を跨いでいない → frozen にしない
    now = datetime(2026, 8, 17, 14, 0, tzinfo=timezone.utc)
    frozen, _ = judge_frozen(_history(7, 14, True, now), now, 35.68, 139.75)
    assert not frozen


def test_no_coords_falls_back_to_6h():
    now = datetime(2026, 8, 17, 3, 0, tzinfo=timezone.utc)
    frozen, _ = judge_frozen(_history(8, 16, True, now), now, None, None)
    assert frozen


def test_okinawa_kasen_placeholder_detected():
    from pathlib import Path
    from monitor.freeze import dhash64, is_placeholder
    fx = Path(__file__).resolve().parent.parent.parent / "crawler" / "tests" / "fixtures"
    h = dhash64((fx / "okinawa_kasen_placeholder.jpg").read_bytes())
    assert is_placeholder(h)
