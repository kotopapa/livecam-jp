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


def test_frozen_detected_from_trailing_identical_run():
    """シャード制（1台あたり約5時間に1回）では履歴48件が約10日分になる。
    直前まで画像が変わっていても、末尾の同一区間だけで凍結を判定できること
    （2026-09-07 埼玉県 栄橋の不具合報告: 19時間止まっても ok のままだった）"""
    # JST 09:44 = UTC 00:44。末尾4件（15時間分）が同一で、JST 05:17 の日の出を跨いでいる
    now = datetime(2026, 9, 7, 0, 44, tzinfo=timezone.utc)
    lat, lng = 35.836, 139.580
    history = []
    for i in range(44):                                    # 変化していた古い履歴
        at = now - timedelta(hours=5) * (48 - i)
        history.append({"at": at.isoformat(), "hash": 1000 + i})
    for i in range(4):                                     # 同一区間: -20h, -15h, -10h, -5h
        at = now - timedelta(hours=5) * (4 - i)
        history.append({"at": at.isoformat(), "hash": 42})
    frozen, since = judge_frozen(history, now, lat, lng)
    assert frozen
    assert since == history[44]["at"]
    # 同一区間が最新1件だけなら判定しない
    history[-2]["hash"] = 7
    frozen, _ = judge_frozen(history, now, lat, lng)
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


def test_cbr_road_placeholder_detected():
    from pathlib import Path
    from monitor.freeze import is_placeholder
    # 中部地整の道路カメラは配信停止中に「現在、この地点の画像配信は行っておりません」を
    # HTTP 200 で返す（2026-09-07 中川運河橋右岸ほか4台で確認）
    data = (Path(__file__).resolve().parents[2] / "crawler" / "tests" / "fixtures"
            / "cbr_road_placeholder.jpeg").read_bytes()
    assert is_placeholder(dhash64(data))
