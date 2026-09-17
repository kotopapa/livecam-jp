"""政令指定都市の区名テーブルを生成する（app/lib/data/ward_names.dart）。

気象庁の地震情報（list.json の int[].city[].code）は政令指定都市を区単位の
コード（例: 1410200 = 横浜市神奈川区）で返すが、市区町村名を引いている
area.json の class20s は「横浜市北部／南部」のような単位しか持たない。
そのためアプリでは区名が引けず「市区町村 14102」と出ていた（2026-09-17）。

総務省「全国地方公共団体コード」の Excel（2枚目のシート＝政令指定都市の区）
から JIS 5桁 → 区名（「横浜市神奈川区」形式）を作る。東京23区は area.json で
引けるので含めない。

使い方: python tools/ward_names.py [--url <xlsx URL>]
"""
from __future__ import annotations

import argparse
import html
import io
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

# 総務省 電子自治体 > 全国地方公共団体コード（https://www.soumu.go.jp/denshijiti/code.html）
DEFAULT_URL = "https://www.soumu.go.jp/main_content/000925835.xlsx"
OUT = Path(__file__).resolve().parent.parent / "app" / "lib" / "data" / "ward_names.dart"


def _shared_strings(z: zipfile.ZipFile) -> list[str]:
    xml = z.read("xl/sharedStrings.xml").decode("utf-8")
    out = []
    for si in re.findall(r"<si>(.*?)</si>", xml, re.S):
        si = re.sub(r"<rPh[^>]*>.*?</rPh>", "", si, flags=re.S)  # ふりがな（ルビ）は除く
        out.append(html.unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S))))
    return out


def _rows(z: zipfile.ZipFile, sheet: str, ss: list[str]) -> list[list[str]]:
    xml = z.read(sheet).decode("utf-8")
    rows = []
    for row in re.findall(r"<row[^>]*>(.*?)</row>", xml, re.S):
        cells = []
        for m in re.finditer(r'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|>(.*?)</c>)', row, re.S):
            attrs, inner = m.group(2), m.group(3) or ""
            v = re.search(r"<v>(.*?)</v>", inner)
            val = v.group(1) if v else ""
            if 't="s"' in attrs and val:
                val = ss[int(val)]
            cells.append(html.unescape(val).strip())
        rows.append(cells)
    return rows


def extract_wards(xlsx_bytes: bytes) -> dict[str, str]:
    z = zipfile.ZipFile(io.BytesIO(xlsx_bytes))
    ss = _shared_strings(z)
    wards: dict[str, str] = {}
    for sheet in sorted(n for n in z.namelist() if re.match(r"xl/worksheets/sheet\d+\.xml$", n)):
        for r in _rows(z, sheet, ss):
            if len(r) < 3 or not r[0][:5].isdigit():
                continue
            code, name = r[0][:5], r[2]
            # 「〇〇市△△区」だけ（東京23区 131xx と市そのものは除く）
            if code.startswith("131") or not name.endswith("区") or "市" not in name:
                continue
            wards[code] = name
    return dict(sorted(wards.items()))


def render_dart(wards: dict[str, str], source: str) -> str:
    lines = [
        "// 生成ファイル: tools/ward_names.py（総務省 全国地方公共団体コード）。手で編集しない。",
        "// 政令指定都市の区名（JIS 5桁 → 「横浜市神奈川区」）。",
        "// 気象庁 area.json は政令市を「横浜市北部」等の単位でしか持たないため、",
        "// 地震情報の区コード（1410200 等）の名前はこの表で引く。",
        f"// 出典: {source}",
        "",
        "const Map<String, String> wardNames = {",
    ]
    for code, name in wards.items():
        lines.append(f"  '{code}': '{name}',")
    lines.append("};")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    with urllib.request.urlopen(args.url, timeout=60) as r:
        data = r.read()
    wards = extract_wards(data)
    if len(wards) < 150:
        print(f"区が少なすぎます: {len(wards)}", file=sys.stderr)
        return 1
    Path(args.out).write_text(render_dart(wards, args.url), encoding="utf-8")
    prefs = sorted({c[:2] for c in wards})
    print(f"{len(wards)} wards, prefectures {prefs} -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
