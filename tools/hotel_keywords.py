"""カメラ詳細の「この付近の宿を探す」用 市区町村名テーブルを生成する。

    python tools/hotel_keywords.py            # app/assets/data/municipalities.json を更新

じゃらんのキーワード検索（uww2011init.do?keyword=）は **Shift_JIS のパーセント
エンコード**しか受け付けない（UTF-8 だと文字化けして0件になる。2026-09-03 実測）。
Dart 標準に Shift_JIS のエンコーダが無いので、市区町村コード（JIS 5桁）ごとに
名称と Shift_JIS エンコード済みの検索語をアプリ同梱のアセットとして持たせる。

名称の出典は気象庁の地域コード表（area.json の class20s）。
- キーは JIS 5桁（class20s コードの先頭5桁）。政令指定都市は市単位のみ
  （区コードはアプリ側で `XX100` 系に丸めて引く）
- 気象庁が1市町村を分割している所（釧路市音別・八雲町熊石 等）は共通接頭辞
  （＝市町村名）に畳む
"""
from __future__ import annotations

import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "app" / "assets" / "data" / "municipalities.json"
AREA_JSON = "https://www.jma.go.jp/bosai/common/const/area.json"


def sjis_quote(name: str) -> str:
    """じゃらん向け: Shift_JIS(cp932) のバイト列をパーセントエンコードする"""
    return urllib.parse.quote(name.encode("cp932"))


def common_prefix(names: list[str]) -> str:
    """分割された市町村名（釧路市音別・釧路市阿寒…）を共通接頭辞に畳む"""
    if len(names) == 1:
        return names[0]
    first = min(names, key=len)
    n = 0
    while n < len(first) and all(x[n] == first[n] for x in names):
        n += 1
    return first[:n] or names[0]


def build_table(class20s: dict[str, dict]) -> dict[str, list[str]]:
    by5: dict[str, list[str]] = {}
    for code, v in class20s.items():
        name = str(v.get("name") or "").strip()
        if not name or len(code) < 5:
            continue
        by5.setdefault(code[:5], []).append(name)
    table: dict[str, list[str]] = {}
    for code in sorted(by5):
        name = common_prefix(sorted(set(by5[code])))
        if not name:
            continue
        table[code] = [name, sjis_quote(name)]
    return table


def fetch_area_json() -> dict:
    req = urllib.request.Request(AREA_JSON, headers={"User-Agent": "livecam-jp tools/hotel_keywords"})
    with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310 (固定URL)
        return json.load(r)


def main() -> int:
    area = fetch_area_json()
    table = build_table(area["class20s"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps({"source": AREA_JSON, "municipalities": table},
                   ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(table)} 市区町村 ({os.path.getsize(OUT)//1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
