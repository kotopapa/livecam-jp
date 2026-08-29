"""check_camera の判定ロジックをフェイクHTTPでテストする。"""

from pathlib import Path

from monitor.check import check_camera

FIXTURES = Path(__file__).resolve().parent.parent.parent / "crawler" / "tests" / "fixtures"
PLACEHOLDER = (FIXTURES / "kawabou_placeholder.png").read_bytes()


class FakeResponse:
    def __init__(self, status=200, content=b"", headers=None):
        self.status_code = status
        self.content = content
        self.headers = headers or {}
        self.text = content.decode("utf-8", errors="replace")


class FakeSession:
    """呼び出しごとに responses から順に返す。"""

    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    def get(self, url, headers=None, timeout=None):
        self.requests.append({"url": url, "headers": headers or {}})
        return self.responses.pop(0)


def _camera(url="https://cam.example.jp/1.jpg"):
    return {
        "id": "test-1", "lat": 35.68, "lng": 139.75,
        "feed": {"type": "still_image", "url": url, "headers": {}, "requires_referer": False},
        "source": {"page_url": "https://example.jp/"},
    }


def test_placeholder_with_etag_keeps_failing():
    """プレースホルダ画像(200+ETag)が304で ok にすり抜けないこと。"""
    ph = FakeResponse(200, PLACEHOLDER, {"Content-Type": "image/png", "ETag": '"abc"'})
    state: dict = {}
    r1 = check_camera(FakeSession([ph]), _camera(), state)
    assert r1["state"] == "unknown" and r1["consecutive_failures"] == 1
    # 失敗時にETagを保存していないので、次回も条件なしで再取得され再び検知される
    r2 = check_camera(FakeSession([ph]), _camera(), state)
    r3 = check_camera(FakeSession([ph]), _camera(), state)
    assert r3["state"] == "error" and r3["consecutive_failures"] == 3


def test_ok_image_then_304_stays_ok():
    img = FakeResponse(200, b"\xff\xd8" + b"x" * 6000, {"Content-Type": "image/jpeg", "ETag": '"v1"'})
    state: dict = {}
    check_camera(FakeSession([img]), _camera(), state)      # dhash64はJPEGデコード失敗→hash None でも ok 扱い
    s = FakeSession([FakeResponse(304)])
    r2 = check_camera(s, _camera(), state)
    assert r2["state"] == "ok"
    assert s.requests[0]["headers"].get("If-None-Match") == '"v1"'


def test_http_error_counts_to_error():
    state: dict = {}
    for expected_state, n in [("unknown", 1), ("unknown", 2), ("error", 3)]:
        r = check_camera(FakeSession([FakeResponse(404), FakeResponse(404)]), _camera(), state)
        assert r["state"] == expected_state and r["consecutive_failures"] == n


def test_non_image_content_fails():
    html = FakeResponse(200, b"<html>maintenance</html>", {"Content-Type": "text/html"})
    state: dict = {}
    r = check_camera(FakeSession([html]), _camera(), state)
    assert r["state"] == "unknown" and r["consecutive_failures"] == 1


def test_empty_image_body_fails():
    # 実例(2026-08-29 石川県道路カメラ 中能登町金丸): HTTP 200・image/jpeg だが
    # Content-Length 0。カメラ停止中にサーバが空ファイルを配信する
    empty = FakeResponse(200, b"", {"Content-Type": "image/jpeg", "Last-Modified": "Sat, 29 Aug 2026 07:12:01 GMT"})
    state: dict = {}
    r = check_camera(FakeSession([empty]), _camera(), state)
    assert r["state"] == "unknown" and r["consecutive_failures"] == 1
    assert "last_modified" not in state


def _yt_camera(ftype="youtube_video", url="abc123DEF45"):
    return {
        "id": "yt-1", "lat": 35.0, "lng": 139.0,
        "feed": {"type": ftype, "url": url, "headers": {}, "requires_referer": False},
        "source": {"page_url": "https://example.jp/"},
    }


def test_youtube_video_uses_oembed_and_ok_on_200():
    s = FakeSession([FakeResponse(200, b'{"title":"x"}'),
                     FakeResponse(200, b'<html>shell</html>')])
    r = check_camera(s, _yt_camera(), {})
    assert r["state"] == "ok"
    req = s.requests[0]["url"]
    assert req.startswith("https://www.youtube.com/oembed?url=")
    assert "abc123DEF45" in req


def test_youtube_video_dead_becomes_error_after_3():
    """削除/非公開IDは oEmbed が 403/404 → 3回連続で error（アプリ側で非表示）。"""
    state: dict = {}
    for expected, n in [("unknown", 1), ("unknown", 2), ("error", 3)]:
        r = check_camera(FakeSession([FakeResponse(403), FakeResponse(403)]), _yt_camera(), state)
        assert r["state"] == expected and r["consecutive_failures"] == n


def test_youtube_channel_checks_live_url():
    s = FakeSession([FakeResponse(200, b"<html>live</html>")])
    r = check_camera(s, _yt_camera("youtube_channel", "UCxxChannelIdxx"), {})
    assert r["state"] == "ok"
    assert s.requests[0]["url"] == "https://www.youtube.com/channel/UCxxChannelIdxx/live"


def test_youtube_channel_gone_fails():
    r = check_camera(FakeSession([FakeResponse(404), FakeResponse(404)]),
                     _yt_camera("youtube_channel", "UCxxChannelIdxx"), {})
    assert r["state"] == "unknown" and r["consecutive_failures"] == 1


def test_youtube_playlist_uses_playlist_oembed():
    s = FakeSession([FakeResponse(200, b'{"title":"pl"}')])
    r = check_camera(s, _yt_camera("youtube_video", "videoseries?list=PLxxYYzz"), {})
    assert r["state"] == "ok"
    assert "playlist%3Flist%3DPLxxYYzz" in s.requests[0]["url"]


def test_youtube_video_not_live_fails():
    """48時間より前に始まった配信のアーカイブは死とみなす。"""
    oembed = FakeResponse(200, b'{"title":"x"}')
    watch = FakeResponse(
        200, b'ytInitialPlayerResponse {"isLiveNow":false,'
             b'"startTimestamp":"2020-01-01T00:00:00+00:00"}')
    r = check_camera(FakeSession([oembed, watch]), _yt_camera(), {})
    assert r["state"] == "unknown" and r["consecutive_failures"] == 1


def test_youtube_video_unplayable_fails():
    oembed = FakeResponse(200, b'{"title":"x"}')
    watch = FakeResponse(
        200, b'ytInitialPlayerResponse "status":"UNPLAYABLE"')
    r = check_camera(FakeSession([oembed, watch]), _yt_camera(), {})
    assert r["state"] == "unknown"


def test_youtube_video_nightly_pause_stays_ok():
    """開始が直近(48h以内)の終了済み配信は夜間停止型として生存扱い。"""
    from datetime import datetime, timedelta, timezone
    recent = (datetime.now(timezone.utc) - timedelta(hours=5)).isoformat()
    oembed = FakeResponse(200, b'{"title":"x"}')
    watch = FakeResponse(
        200, ('ytInitialPlayerResponse {"isLiveNow":false,'
              '"startTimestamp":"%s"}' % recent).encode())
    r = check_camera(FakeSession([oembed, watch]), _yt_camera(), {})
    assert r["state"] == "ok"


def test_youtube_video_live_ok():
    oembed = FakeResponse(200, b'{"title":"x"}')
    watch = FakeResponse(200, b'ytInitialPlayerResponse "isLiveNow":true')
    r = check_camera(FakeSession([oembed, watch]), _yt_camera(), {})
    assert r["state"] == "ok"


def test_youtube_video_shell_response_keeps_ok():
    """同意画面等で判定材料がない場合はoEmbed結果を採用(誤爆防止)。"""
    oembed = FakeResponse(200, b'{"title":"x"}')
    shell = FakeResponse(200, b'<html>consent</html>')
    r = check_camera(FakeSession([oembed, shell]), _yt_camera(), {})
    assert r["state"] == "ok"


def test_yamaguchi_kasen_uses_resolved_image():
    """都度解決型 yamaguchi_kasen: main.py が解決した URL を取得し image_url/image_time を返す。"""
    from crawler.sources.yamaguchi_kasen import resolve_image_urls
    html = (FIXTURES / "yamaguchi_kasen_list.html").read_text(encoding="utf-8")
    url, at = resolve_image_urls(html)["001"]
    cam = _camera()
    cam["feed"] = {"type": "yamaguchi_kasen",
                   "url": "https://y-bousai.pref.yamaguchi.lg.jp/citizen/camera/krc_camera_list.aspx",
                   "camera_ref": "001", "headers": {}, "requires_referer": False}
    cam["_resolved_image"] = {"url": url, "time": at}
    s = FakeSession([FakeResponse(200, b"\xff\xd8" + b"x" * 6000, {"Content-Type": "image/jpeg"})])
    r = check_camera(s, cam, {})
    assert s.requests[0]["url"] == url
    assert r["state"] == "ok" and r["image_url"] == url and r["image_time"] == at
    # 未解決なら失敗として数える
    cam.pop("_resolved_image")
    r2 = check_camera(FakeSession([]), cam, {})
    assert r2["state"] == "unknown" and r2["consecutive_failures"] == 1


def test_shimane_suibo_uses_resolved_image():
    """都度解決型 shimane_suibo: main.py が解決した URL を取得し image_url/image_time を返す。"""
    from crawler.sources.shimane_suibo import resolve_image_urls
    text = (FIXTURES / "shimane_suibo_camera.json").read_text(encoding="utf-8")
    url, at = resolve_image_urls(text)["8193_90_1"]
    cam = _camera()
    cam["feed"] = {"type": "shimane_suibo",
                   "url": "https://www.suibou-shimane.jp/dyn/camera/camera.json",
                   "camera_ref": "8193_90_1", "headers": {}, "requires_referer": False}
    cam["_resolved_image"] = {"url": url, "time": at}
    s = FakeSession([FakeResponse(200, b"\xff\xd8" + b"x" * 6000, {"Content-Type": "image/jpeg"})])
    r = check_camera(s, cam, {})
    assert s.requests[0]["url"] == url
    assert r["state"] == "ok" and r["image_url"] == url and r["image_time"] == at
    cam.pop("_resolved_image")
    r2 = check_camera(FakeSession([]), cam, {})
    assert r2["state"] == "unknown" and r2["consecutive_failures"] == 1
