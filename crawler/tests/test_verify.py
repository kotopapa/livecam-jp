"""verify.verify_still_images のレート制限耐性テスト。

2026-08-21のcrawl実行で、検証フェーズ中に鹿児島県サーバの403で
RateLimitedError が捕捉されずクロール全体が落ちた。
403/429は当該ホストのみ停止し、他ホストの検証は継続すること。
"""

from __future__ import annotations

import io

from PIL import Image

from crawler import verify
from crawler.sources.base import CameraCandidate, FetchResult, RateLimitedError


def _png(color) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (64, 64), color).save(buf, format="PNG")
    data = buf.getvalue()
    # MIN_BYTES(5KB)を超えるようパディング（PNGは末尾ゴミを無視する）
    return data + b"\0" * (verify.MIN_BYTES - len(data) + 1)


def _cand(cid: str, url: str) -> CameraCandidate:
    return CameraCandidate(
        id=cid, name=cid, category="river", prefecture="46",
        feed_type="still_image", feed_url=url,
        operator="test", page_url="https://example.com/", attribution="test")


class _Session:
    """blockedホストにはRateLimitedError、他は正常画像を返すフェイク。"""

    def __init__(self, blocked_host: str):
        self.blocked_host = blocked_host
        self.calls: list[str] = []
        self._n = 0

    def fetch(self, url, use_cache=False, extra_headers=None) -> FetchResult:
        self.calls.append(url)
        if self.blocked_host in url:
            raise RateLimitedError(url, 403)
        self._n += 1
        # 呼び出しごとに色を変え「画像が変化した」状態にする
        return FetchResult(url=url, status=200, content=_png((self._n * 40 % 255, 0, 0)),
                           content_type="image/png")


def test_rate_limited_host_does_not_abort_verification():
    session = _Session("blocked.example.jp")
    cands = [
        _cand("ok-1", "https://ok.example.jp/cam1.jpg"),
        _cand("ng-1", "https://blocked.example.jp/cam1.jpg"),
        _cand("ng-2", "https://blocked.example.jp/cam2.jpg"),
        _cand("ok-2", "https://ok.example.jp/cam2.jpg"),
    ]
    verify.verify_still_images(session, cands, wait_sec=0, log=lambda *a: None)

    # 正常ホストは2回取得検証が完了している
    for c in (cands[0], cands[3]):
        assert c.verification["fetched_twice"] is True
        assert verify.RATE_LIMITED_NOTE not in (c.review_note or "")

    # 403ホストは「検証不可」を記録
    for c in (cands[1], cands[2]):
        assert c.verification["fetched_twice"] is False
        assert verify.RATE_LIMITED_NOTE in c.review_note

    # 403検知後、同ホストへは追加アクセスしない（最初の1回のみ）
    blocked_calls = [u for u in session.calls if "blocked.example.jp" in u]
    assert len(blocked_calls) == 1
