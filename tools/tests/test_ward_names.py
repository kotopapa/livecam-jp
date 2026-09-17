import io
import zipfile

from tools.ward_names import extract_wards, render_dart


def _xlsx(rows):
    """最小の xlsx（共有文字列＋ルビ付き）を作る"""
    strings = []
    def sidx(text, ruby=None):
        strings.append((text, ruby))
        return len(strings) - 1
    cells = []
    for i, (code, pref, name, ruby) in enumerate(rows, start=2):
        c = sidx(code), sidx(pref), sidx(name, ruby)
        cells.append(
            f'<row r="{i}"><c r="A{i}" t="s"><v>{c[0]}</v></c><c r="B{i}" t="s"><v>{c[1]}</v></c>'
            f'<c r="C{i}" t="s"><v>{c[2]}</v></c></row>')
    ss = "".join(
        f"<si><t>{t}</t>" + (f'<rPh sb="0" eb="3"><t>{r}</t></rPh>' if r else "") + "</si>"
        for t, r in strings)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("xl/sharedStrings.xml", f'<sst>{ss}</sst>')
        z.writestr("xl/worksheets/sheet1.xml", f'<worksheet><sheetData>{"".join(cells)}</sheetData></worksheet>')
    return buf.getvalue()


def test_extract_wards_strips_ruby_and_skips_cities_and_tokyo():
    data = _xlsx([
        ("141003", "神奈川県", "横浜市", None),
        ("141020", "神奈川県", "横浜市神奈川区", None),
        ("431010", "熊本県", "熊本市中央区", "クマモトシ"),  # ルビ付き（総務省の実データ）
        ("131016", "東京都", "千代田区", None),  # 23区は含めない
        ("011002", "北海道", "札幌市", None),
    ])
    assert extract_wards(data) == {"14102": "横浜市神奈川区", "43101": "熊本市中央区"}


def test_render_dart():
    out = render_dart({"14102": "横浜市神奈川区"}, "https://example.com/x.xlsx")
    assert "const Map<String, String> wardNames = {" in out
    assert "  '14102': '横浜市神奈川区'," in out
    assert out.endswith("};\n")
