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
