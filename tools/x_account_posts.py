"""X アカウントの過去投稿に防災関係の発信があるかを確認する。

    python -m tools.x_account_posts <handle> [<handle>...]

**用途は「そのアカウントを載せてよいか」の一次確認のみ**。定期収集はしない
（X API は2026年2月から従量課金で、この経路も埋め込みウィジェット用の公開JSON）。
**429 が非常に出やすい**。2026-09-06 の実測では 45秒間隔でも14件中13件が429になった。
1件あたり4分以上空けること（既定 240 秒）。まとめて叩くと数十分ブロックされる。

判定: 直近の投稿本文（full_text）のうち、防災語を含むものの件数と割合。
自治体の総合アカウントを「災害情報も流している」と認めるかの根拠に使う。
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
ENDPOINT = "https://syndication.twitter.com/srv/timeline-profile/screen-name/"

# 「災害時に役立つ発信か」を見る語。訓練・啓発だけの投稿と区別するため
# 実際の気象・災害事象の語を中心にする
DISASTER_KW = ("警報", "注意報", "避難", "地震", "震度", "津波", "大雨", "台風",
               "土砂災害", "洪水", "浸水", "噴火", "災害", "防災", "停電", "暴風")
# 実運用（速報）を示す強い語
ALERT_KW = ("警報", "注意報", "避難指示", "避難所", "震度", "津波", "土砂災害警戒情報")


def fetch_posts(handle: str, timeout: int = 30) -> list[str]:
    """直近の投稿本文。取得できなければ空リスト"""
    req = urllib.request.Request(ENDPOINT + handle, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}") from e
    texts = re.findall(r'"full_text":"((?:[^"\\]|\\.)*)"', body)
    out = []
    for t in texts:
        try:
            out.append(json.loads(f'"{t}"'))
        except ValueError:
            out.append(t)
    return out


def summarize(handle: str, posts: list[str]) -> dict:
    hit = [p for p in posts if any(k in p for k in DISASTER_KW)]
    alert = [p for p in posts if any(k in p for k in ALERT_KW)]
    return {
        "handle": handle,
        "posts": len(posts),
        "disaster_posts": len(hit),
        "alert_posts": len(alert),
        "ratio": round(len(hit) / len(posts), 3) if posts else 0.0,
        "examples": [re.sub(r"\s+", " ", p)[:70] for p in alert[:3]],
    }


def main() -> int:
    handles = sys.argv[1:]
    for i, h in enumerate(handles):
        try:
            posts = fetch_posts(h)
            print(json.dumps(summarize(h, posts), ensure_ascii=False), flush=True)
        except Exception as e:  # noqa: BLE001
            print(json.dumps({"handle": h, "error": str(e)[:60]}, ensure_ascii=False), flush=True)
        if i + 1 < len(handles):
            time.sleep(240)  # 429回避。45秒では足りない（2026-09-06 実測）
    return 0


if __name__ == "__main__":
    sys.exit(main())
