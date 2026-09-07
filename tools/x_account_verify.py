"""X（旧Twitter）アカウントの実在と表示名・説明を確認する。

    python -m tools.x_account_verify <handle> [<handle>...]

x.com のプロフィールページはログイン無しでも og メタデータを返すので、
表示名（title）と説明（og:description）で「自治体の災害情報アカウントか」を判定できる。
"""
from __future__ import annotations

import html
import json
import re
import sys
import time
import urllib.error
import urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")

# 災害情報アカウントとみなすキーワード（表示名または説明に含まれること）
DISASTER_KW = ("災害", "防災", "危機管理", "気象", "避難", "緊急", "河川", "水位")


def fetch(handle: str, timeout: int = 25) -> dict | None:
    """存在すれば {'handle','name','desc'}、存在しなければ None"""
    req = urllib.request.Request(f"https://x.com/{handle}", headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode("utf-8", "ignore")
            code = r.status
    except urllib.error.HTTPError as e:
        return {"handle": handle, "error": f"HTTP {e.code}"}
    except Exception as e:  # noqa: BLE001
        return {"handle": handle, "error": str(e)[:60]}

    t = re.search(r"<title>([^<]*)</title>", body)
    title = html.unescape(t.group(1)) if t else ""
    if "Log in" in title or not title or title.startswith("Profile / X"):
        return None
    m = re.match(r"(.*?)\s*\(@([A-Za-z0-9_]+)\)", title)
    if not m:
        return None
    d = re.search(r'<meta[^>]+property="og:description"[^>]+content="([^"]*)"', body)
    if not d:
        d = re.search(r'<meta[^>]+name="description"[^>]+content="([^"]*)"', body)
    return {
        "handle": m.group(2),
        "name": html.unescape(m.group(1)).strip(),
        "desc": html.unescape(d.group(1)).strip() if d else "",
        "http": code,
    }


def is_disaster(rec: dict) -> bool:
    blob = f"{rec.get('name','')} {rec.get('desc','')}"
    return any(k in blob for k in DISASTER_KW)


def main() -> int:
    handles = sys.argv[1:]
    out = []
    for i, h in enumerate(handles):
        r = fetch(h)
        if r is None:
            r = {"handle": h, "error": "not found"}
        else:
            r["disaster"] = is_disaster(r)
        out.append(r)
        print(json.dumps(r, ensure_ascii=False), flush=True)
        if i + 1 < len(handles):
            time.sleep(2.0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
