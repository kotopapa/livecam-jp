"""tools.facilities の CSV正規化・ライセンス判定・県コード変換・住所補完のテスト。"""

import json

import pytest

from tools import facilities


# ------------------------------------------------------------ 分類

def test_classify_kinds():
    assert facilities.classify("消防水利施設一覧") == "fire_water"
    assert facilities.classify("【名古屋市】市有防火水槽一覧") == "fire_water"
    assert facilities.classify("消火栓一覧（2024年4月1日時点）") == "fire_water"
    assert facilities.classify("給水拠点一覧データ") == "water"
    assert facilities.classify("応急給水施設一覧（2025年4月1日更新）") == "water"
    assert facilities.classify("災害時給水ステーション") == "water"
    assert facilities.classify("緊急貯水槽") == "water"
    assert facilities.classify("備蓄倉庫一覧") == "stock"
    assert facilities.classify("防災倉庫一覧") == "stock"


def test_classify_rejects_statistics_and_unrelated():
    # 施設一覧ではなく統計・名簿の類は拾わない
    assert facilities.classify("四條畷市_消火栓及び貯水槽の数") is None
    assert facilities.classify("【福知山市】統計書　17－15．消防水利の状況") is None
    assert facilities.classify("札幌市指定給水装置工事事業者一覧") is None
    assert facilities.classify("給水普及状況") is None
    assert facilities.classify("大町防災倉庫(施設カルテ)") is None
    assert facilities.classify("指定緊急避難場所一覧") is None
    assert facilities.classify("") is None


# ------------------------------------------------------------ ライセンス

@pytest.mark.parametrize("lid,ltitle,label", [
    ("cc-by-40-intl", "Creative Commons Attribution 4.0 International", "CC BY"),
    ("CC-BY-4.0", "CC-BY-4.0", "CC BY"),
    ("cc-by", "Creative Commons Attribution", "CC BY"),
    ("cc-by-21-jp", "Creative Commons Attribution 2.1 JP", "CC BY"),
    ("PDL1.0", "Public Data License 1.0", "PDL 1.0"),
    ("cc-zero", "Creative Commons CCZero", "CC0"),
    ("odc-by", "Open Data Commons Attribution License", "ODC-BY"),
    (None, "政府標準利用規約（第2.0版）", "政府標準利用規約2.0系"),
    ("Truecc-by-40-intl", "Truecc-by-40-intl", "CC BY"),  # 登録側の打ち間違い
])
def test_license_accepted(lid, ltitle, label):
    ok, got, reason = facilities.license_status(lid, ltitle)
    assert ok is True
    assert got == label
    assert reason == ""


@pytest.mark.parametrize("lid,ltitle", [
    ("cc-nc", "Creative Commons Non-Commercial (Any)"),
    ("cc-by-nc-4.0", "Creative Commons Attribution NonCommercial 4.0"),
    ("cc-by-nd", "Creative Commons Attribution No Derivatives"),
    ("other-copyright", "Other"),
    ("notspecified", "License not specified"),
    ("gfdl", "GNU Free Documentation License"),
    (None, None),
])
def test_license_rejected(lid, ltitle):
    ok, _, reason = facilities.license_status(lid, ltitle)
    assert ok is False
    assert reason


def test_license_nc_beats_by():
    """cc-by-nc は cc-by を含むので、非商用の判定が先に効かないといけない。"""
    ok, _, reason = facilities.license_status("cc-by-nc-sa-4.0", "CC BY-NC-SA 4.0")
    assert ok is False
    assert reason == "非商用または改変禁止"


# ------------------------------------------------------------ 県コード

def test_pref_code_from_jis():
    assert facilities.pref_code_from_jis("462209") == "46"   # 全国地方公共団体コード6桁
    assert facilities.pref_code_from_jis("46220") == "46"    # 5桁
    assert facilities.pref_code_from_jis("13") == "13"
    assert facilities.pref_code_from_jis("1") == "01"
    assert facilities.pref_code_from_jis("48") is None       # 存在しない県コード
    assert facilities.pref_code_from_jis("") is None
    assert facilities.pref_code_from_jis(None) is None


def test_pref_code_from_text():
    assert facilities.pref_code_from_text("鹿児島県南さつま市本町中央") == "46"
    assert facilities.pref_code_from_text("和歌山県") == "30"
    assert facilities.pref_code_from_text("神奈川県横浜市中区") == "14"
    assert facilities.pref_code_from_text("北海道札幌市") == "01"
    assert facilities.pref_code_from_text("大阪") == "27"
    # 「石川町」(福島県)を石川県にしない
    assert facilities.pref_code_from_text("石川町") is None
    assert facilities.pref_code_from_text("") is None


# ------------------------------------------------------------ CSV 正規化

def test_normalize_header_handles_fullwidth_and_bom():
    assert facilities.normalize_header("﻿全国地方公共団体コード") == "全国地方公共団体コード"
    assert facilities.normalize_header("所在地＿連結標記") == "所在地_連結標記"
    assert facilities.normalize_header("建物名等（方書）") == "建物名等(方書)"
    assert facilities.normalize_header("Ｎｏ") == "No"
    assert facilities.normalize_header(" 緯度 ") == "緯度"


def test_read_csv_text_drops_blank_lines_and_unnamed_columns():
    rows = facilities.read_csv_text("﻿A,B,,C\n1,2,x,3\n\n,,,\n4,5,y,6\n")
    assert rows == [{"A": "1", "B": "2", "C": "3"}, {"A": "4", "B": "5", "C": "6"}]


def test_decode_csv_utf8_and_cp932():
    assert facilities.decode_csv("緯度,経度\n".encode("utf-8-sig")) == "緯度,経度\n"  # BOMは除かれる
    assert facilities.decode_csv("緯度,経度\n".encode("cp932")) == "緯度,経度\n"
    assert facilities.decode_csv("緯度,経度\n".encode("utf-8")) == "緯度,経度\n"


def test_parse_coord():
    assert facilities.parse_coord("31.420235", "130.320918") == (31.42024, 130.32092)
    # 列が入れ替わっている自治体を救う
    assert facilities.parse_coord("130.320918", "31.420235") == (31.42024, 130.32092)
    assert facilities.parse_coord("", "") is None
    assert facilities.parse_coord("0", "0") is None          # 日本の範囲外
    assert facilities.parse_coord("999", "130.55") is None
    assert facilities.parse_coord("あ", "い") is None


# ------------------------------------------------------------ 行 → レコード

STANDARD_CSV = "﻿" + """全国地方公共団体コード,ID,地方公共団体名,種別,所在地_全国地方公共団体コード,町字ID,所在地_連結表記,所在地_都道府県,所在地_市区町村,所在地_町字,所在地_番地以下,建物名等(方書),緯度,経度,口径,備考
462209,,鹿児島県南さつま市,消火栓,,,,鹿児島県,南さつま市,本町中央,,,31.420235,130.320918,150,加世田中央分団
462209,,鹿児島県南さつま市,防火水槽,,,鹿児島県南さつま市加世田川畑1-1,鹿児島県,南さつま市,加世田川畑,1-1,,31.419433,130.322463,,
462209,,鹿児島県南さつま市,消火栓,,,,鹿児島県,南さつま市,大浦町,,,,,150,座標なし住所あり
462209,,鹿児島県南さつま市,消火栓,,,,,,,,,,,150,座標も住所もなし
"""

LEGACY_CSV = """都道府県コード又は市区町村コード,NO,都道府県名,市区町村名,種別,住所,方書,緯度,経度,口径,備考
132110,1,東京都,武蔵野市,防火水槽,東京都武蔵野市吉祥寺本町1-1,,35.70292,139.57960,,
"""

NAMED_CSV = """番号,緯度,経度,施設名,種別,確保水量（立方メートル）,所在地
1,35.68950,139.69171,新宿区立西新宿公園,応急給水槽,1500,東京都新宿区西新宿4-1
"""


def test_rows_to_records_standard_format():
    rows = facilities.read_csv_text(STANDARD_CSV)
    recs, stats = facilities.rows_to_records(rows, "fire_water", 0, "南さつま市")
    assert stats["rows"] == 4
    # 座標も住所も無い行だけ捨てる
    assert len(recs) == 3
    assert stats["no_coord"] == 2
    first = recs[0]
    assert first == {"id": "0-0", "n": "消火栓", "a": "鹿児島県南さつま市本町中央",
                     "k": "fire_water", "o": "南さつま市", "s": 0, "_pref": "46",
                     "lat": 31.42024, "lng": 130.32092}
    # 所在地_連結表記があればそれを優先
    assert recs[1]["a"] == "鹿児島県南さつま市加世田川畑1-1"
    assert recs[1]["n"] == "防火水槽"
    # 座標なし・住所ありは lat 無しで残す（あとでジオコーディングに回す）
    assert "lat" not in recs[2]
    assert recs[2]["a"] == "鹿児島県南さつま市大浦町"


def test_rows_to_records_legacy_format_and_id_offset():
    recs, _ = facilities.rows_to_records(
        facilities.read_csv_text(LEGACY_CSV), "fire_water", 3, "武蔵野市", id_start=10)
    assert len(recs) == 1
    assert recs[0]["id"] == "3-10"       # 同一データセットの2本目以降のCSVでもIDが衝突しない
    assert recs[0]["_pref"] == "13"
    assert recs[0]["o"] == "武蔵野市"
    assert recs[0]["a"] == "東京都武蔵野市吉祥寺本町1-1"


def test_rows_to_records_falls_back_to_short_kind_name():
    """名称列も種別列も無いCSV（北九州市など）は短い種別名を表示名にする。"""
    rows = facilities.read_csv_text("水利番号(栓),緯度,経度\n1,33.88,130.87\n")
    recs, stats = facilities.rows_to_records(rows, "fire_water", 0, "北九州市", default_pref="40")
    assert recs[0]["n"] == "消防水利"
    assert recs[0]["a"] == ""
    assert stats["no_name"] == 1


def test_rows_to_records_prefers_facility_name_over_kind():
    recs, _ = facilities.rows_to_records(
        facilities.read_csv_text(NAMED_CSV), "water", 1, "東京都水道局", default_pref="13")
    assert recs[0]["n"] == "新宿区立西新宿公園"
    assert recs[0]["a"] == "東京都新宿区西新宿4-1"
    assert recs[0]["k"] == "water"
    assert recs[0]["_pref"] == "13"


def test_rows_to_records_default_pref_when_row_has_no_hint():
    rows = facilities.read_csv_text("管轄,水利番号,所在地,緯度,経度\n第一,1,西五反田1-1,35.62,139.72\n")
    recs, stats = facilities.rows_to_records(rows, "fire_water", 0, "品川区", default_pref="13")
    assert recs[0]["_pref"] == "13"
    assert recs[0]["o"] == "品川区"
    assert stats["no_pref"] == 0
    # 県が特定できなければ捨てる
    recs2, stats2 = facilities.rows_to_records(rows, "fire_water", 0, "品川区")
    assert recs2 == [] and stats2["no_pref"] == 1


# ------------------------------------------------------------ 住所からの座標補完

class _FakeGeocoder:
    """crawler.geocode.Geocoder の差し替え。ネットに出ずに成功/失敗を再現する。"""

    def __init__(self, cache_path=None):
        self.cache = {}
        self.calls = []

    def geocode(self, address):
        self.calls.append(address)
        if address == "東京都墨田区吾妻橋1-23-20":
            return (35.71060, 139.80190)
        return None


def test_fill_missing_coords_marks_geocoded_and_counts_failures(monkeypatch):
    import crawler.geocode
    fake = _FakeGeocoder()
    monkeypatch.setattr(crawler.geocode, "Geocoder", lambda cache_path=None: fake)

    recs = [
        {"id": "0-0", "a": "東京都墨田区吾妻橋1-23-20", "lat": 1.0, "lng": 2.0},  # 既に座標あり
        {"id": "0-1", "a": "東京都墨田区吾妻橋1-23-20"},
        {"id": "0-2", "a": "存在しない住所"},
    ]
    stats = facilities.fill_missing_coords(recs)
    assert stats == {"target": 2, "filled": 1, "failed": 1, "skipped_over_limit": 0}
    assert recs[1]["lat"] == 35.7106 and recs[1]["g"] == 1
    assert "lat" not in recs[2] and "g" not in recs[2]
    assert recs[0].get("g") is None          # 元から座標がある行は触らない
    assert fake.calls == ["東京都墨田区吾妻橋1-23-20", "存在しない住所"]


def test_fill_missing_coords_respects_limit(monkeypatch):
    import crawler.geocode
    fake = _FakeGeocoder()
    monkeypatch.setattr(crawler.geocode, "Geocoder", lambda cache_path=None: fake)
    recs = [{"id": f"0-{i}", "a": f"住所{i}"} for i in range(5)]
    stats = facilities.fill_missing_coords(recs, limit=2)
    assert stats["target"] == 5
    assert stats["skipped_over_limit"] == 3
    assert len(fake.calls) == 2


def test_fill_missing_coords_uses_cache_without_consuming_limit(monkeypatch):
    """キャッシュ済みの住所は上限を消費しない（月次実行で新規分だけ問い合わせる）。"""
    import crawler.geocode
    fake = _FakeGeocoder()
    fake.cache = {"住所0": None, "住所1": None}
    monkeypatch.setattr(crawler.geocode, "Geocoder", lambda cache_path=None: fake)
    recs = [{"id": f"0-{i}", "a": f"住所{i}"} for i in range(3)]
    stats = facilities.fill_missing_coords(recs, limit=1)
    assert stats["skipped_over_limit"] == 0
    assert len(fake.calls) == 3


# ------------------------------------------------------------ 出力

def test_split_by_pref_renumbers_sources_per_pref():
    sources = [{"title": "A"}, {"title": "B"}, {"title": "C"}]
    recs = [
        {"id": "0-0", "n": "a", "k": "water", "s": 0, "_pref": "13", "lat": 35.0, "lng": 139.0},
        {"id": "2-0", "n": "b", "k": "water", "s": 2, "_pref": "13", "lat": 35.1, "lng": 139.1},
        {"id": "1-0", "n": "c", "k": "stock", "s": 1, "_pref": "46", "lat": 31.0, "lng": 130.0},
        {"id": "1-1", "n": "d", "k": "stock", "s": 1, "_pref": "46"},  # 座標が無いものは配信しない
    ]
    by_pref = facilities.split_by_pref(recs, sources)
    assert sorted(by_pref) == ["13", "46"]
    assert [r["s"] for r in by_pref["13"]["recs"]] == [0, 1]
    assert [x["title"] for x in by_pref["13"]["sources"]] == ["A", "C"]
    assert len(by_pref["46"]["recs"]) == 1
    assert [x["title"] for x in by_pref["46"]["sources"]] == ["B"]
    # 配信できた件数を出典ごとに数え直す（座標が無くて落ちた1件は数えない）
    assert [x["count"] for x in sources] == [1, 1, 1]


def test_split_by_pref_dedupes_same_point_same_name():
    """住所ジオコーディングで同一座標に積み上がる重複を落とす。"""
    sources = [{"title": "A"}, {"title": "B"}]
    recs = [
        {"id": "0-0", "n": "消火栓", "k": "fire_water", "s": 0, "_pref": "24",
         "lat": 34.85, "lng": 136.45, "g": 1},
        {"id": "0-1", "n": "消火栓", "k": "fire_water", "s": 0, "_pref": "24",
         "lat": 34.85, "lng": 136.45, "g": 1},
        {"id": "1-0", "n": "防火水槽", "k": "fire_water", "s": 1, "_pref": "24",
         "lat": 34.85, "lng": 136.45},          # 種別が違えば残す
    ]
    by_pref = facilities.split_by_pref(recs, sources)
    assert len(by_pref["24"]["recs"]) == 2
    assert [r["id"] for r in by_pref["24"]["recs"]] == ["0-0", "1-0"]


def test_write_outputs_and_sync_site(tmp_path):
    sources = [{"title": "消防水利施設一覧", "url": "https://example.jp/dataset/x",
                "license": "CC BY", "kind": "fire_water"}]
    recs = [{"id": "0-0", "n": "消火栓", "a": "鹿児島県南さつま市本町中央", "k": "fire_water",
             "o": "南さつま市", "s": 0, "_pref": "46", "lat": 31.42024, "lng": 130.32092}]
    out = tmp_path / "facilities"
    by_pref = facilities.split_by_pref(recs, sources)
    index = facilities.write_outputs(by_pref, sources, [{"title": "除外例", "reason": "不明"}],
                                     "2026-08-31T00:00:00Z", {"filled": 0}, out_dir=out)
    assert index["total"] == 1
    assert index["counts"] == {"46": 1}
    assert index["kind_counts"] == {"fire_water": 1}
    assert index["rejected"][0]["reason"] == "不明"
    assert index["attribution"] and index["notice"]

    pref = json.loads((out / "46.json").read_text(encoding="utf-8"))
    assert pref["pref"] == "46"
    assert pref["facilities"][0]["n"] == "消火栓"
    assert "_pref" not in pref["facilities"][0]
    assert pref["sources"][0]["url"] == "https://example.jp/dataset/x"

    site = tmp_path / "site"
    assert facilities.sync_site(src=out, dst=site) == 2      # 46.json と index.json
    assert (site / "index.json").exists()
    # 2回目でも古いファイルが残らない
    (out / "46.json").unlink()
    assert facilities.sync_site(src=out, dst=site) == 1
    assert not (site / "46.json").exists()


def test_write_outputs_clears_stale_pref_files(tmp_path):
    out = tmp_path / "facilities"
    out.mkdir()
    (out / "99.json").write_text("{}", encoding="utf-8")
    facilities.write_outputs({}, [], [], "2026-08-31T00:00:00Z", out_dir=out)
    assert not (out / "99.json").exists()
    assert (out / "index.json").exists()


def test_sync_site_without_source_dir(tmp_path):
    assert facilities.sync_site(src=tmp_path / "nope", dst=tmp_path / "dst") == 0


# ------------------------------------------------------------ XLSX

def _xlsx_bytes(sheets: dict[str, list[list]]) -> bytes:
    """{シート名: [[セル,...],...]} → XLSXバイト列。"""
    import io as _io

    import openpyxl
    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    for name, rows in sheets.items():
        ws = wb.create_sheet(title=name)
        for row in rows:
            ws.append(row)
    buf = _io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def test_read_xlsx_finds_header_below_description_rows():
    """先頭に説明行が数行ある自治体XLSX（東京消防庁型）でもヘッダ行を見つける。"""
    body = _xlsx_bytes({"消火栓": [
        ["東京消防庁 消火栓一覧"],
        ["※この表は令和7年4月1日現在のものです。"],
        [],
        ["水利種別コード", "水利種別", "緯度", "経度", "所属"],
        [1, "公設上水道消火栓", 35.690628, 139.761033, "丸の内"],
        [1, "公設上水道消火栓", 35.6912, 139.7601, "丸の内"],
    ]})
    rows = facilities.read_xlsx(body)
    assert len(rows) == 2
    assert rows[0] == {"水利種別コード": "1", "水利種別": "公設上水道消火栓",
                       "緯度": "35.690628", "経度": "139.761033", "所属": "丸の内"}
    # 数値セルが "1.0" や "35.690628000000004" にならない
    assert rows[0]["水利種別コード"] == "1"


def test_read_xlsx_concatenates_multiple_sheets_and_skips_legend_sheets():
    body = _xlsx_bytes({
        "凡例": [["このファイルについて"], ["問い合わせ先: 消防本部"]],
        "消火栓": [["種別", "所在地", "緯度", "経度"],
                   ["消火栓", "宮崎県川南町平田1407-39", 32.1992362, 131.5276887]],
        "防火水槽": [["種別", "所在地", "緯度", "経度"],
                     ["防火水槽", "宮崎県川南町川南1200", 32.2001, 131.5301]],
    })
    rows = facilities.read_xlsx(body)
    assert [r["種別"] for r in rows] == ["消火栓", "防火水槽"]   # 凡例シートは無視される


def test_read_xlsx_blank_cells_and_blank_rows():
    body = _xlsx_bytes({"S": [
        ["名称", "所在地", "緯度", "経度", ""],          # 列名が空の列は捨てる
        ["西小学校防災倉庫", "東京都墨田区吾妻橋1-23-20", None, None, "x"],
        [None, None, None, None, None],                  # 空行は捨てる
        ["", "", "", "", ""],
        ["東小学校防災倉庫", "", 35.71, 139.80, ""],
    ]})
    rows = facilities.read_xlsx(body)
    assert len(rows) == 2
    assert rows[0] == {"名称": "西小学校防災倉庫", "所在地": "東京都墨田区吾妻橋1-23-20",
                       "緯度": "", "経度": ""}
    assert rows[1]["所在地"] == ""


def test_read_xlsx_rows_feed_rows_to_records():
    body = _xlsx_bytes({"Sheet1": [
        ["令和6年4月1日現在"],
        ["市町村コード", "消火栓種類", "水利番号", "所在地", "設置場所"],
        [232114, "消火栓", "1-1", "愛知県豊田市八草町荒山 731-4", "歩道"],
    ]})
    recs, stats = facilities.rows_to_records(facilities.read_xlsx(body),
                                             "fire_water", 0, "豊田市")
    assert stats["rows"] == 1
    assert recs[0]["_pref"] == "23"
    # 「設置場所」（歩道／車道）ではなく種別列を名称にする
    assert recs[0]["n"] == "消火栓"
    assert recs[0]["a"] == "愛知県豊田市八草町荒山 731-4"
    assert "lat" not in recs[0]        # 座標なし → ジオコーディングに回る


def test_read_xlsx_without_header_like_row_returns_nothing():
    body = _xlsx_bytes({"S": [["集計表"], ["合計", 120], ["前年比", "1.2%"]]})
    assert facilities.read_xlsx(body) == []


def test_xlsx_error_detects_legacy_xls_and_garbage():
    assert facilities.xlsx_error(b"PK\x03\x04rest") is None
    assert facilities.xlsx_error(b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1more") == "旧形式のXLS（openpyxl非対応）"
    assert facilities.xlsx_error(b"<html>404</html>") == "XLSXとして解釈できない内容"
    assert facilities.read_xlsx(b"not a zip at all") == []


def test_read_xlsx_normalizes_fullwidth_header_names():
    body = _xlsx_bytes({"S": [
        ["　名称　", "所在地＿連結標記", "緯度", "経度"],
        ["中央防災倉庫", "福岡県福岡市中央区", 33.58, 130.39],
    ]})
    rows = facilities.read_xlsx(body)
    assert set(rows[0]) == {"名称", "所在地_連結標記", "緯度", "経度"}


@pytest.mark.parametrize("res,expected", [
    ({"format": "CSV", "url": "https://x/download/a.csv"}, "csv"),
    ({"format": "XLSX", "url": "https://x/download/a.xlsx"}, "xlsx"),
    ({"format": "", "url": "https://x/download/syoukasenn2023.xlsx"}, "xlsx"),   # 久山町
    ({"format": "XLS", "url": "https://x/download/syoubousuiri.xls"}, "xls"),    # 厚木市
    ({"format": "XLS", "url": "https://x/download/a.xlsx"}, "xlsx"),   # 拡張子を優先
    ({"format": "CSV", "url": "https://x/api/download?id=3"}, "csv"),  # 拡張子なし
    ({"format": "PDF", "url": "https://x/a.pdf"}, None),
    ({"format": "HTML", "url": "https://x/page.html"}, None),
    ({"format": "", "url": ""}, None),
])
def test_resource_format(res, expected):
    assert facilities.resource_format(res) == expected


# ------------------------------------------------------------ ジオコーディング用の住所補完

def test_geocode_query_qualifies_address_without_prefecture():
    # 福岡市の消防水利は所在地に県も市も入っていない
    assert facilities.geocode_query("西区姪の浜4丁目0004番地1号", "40", "福岡市") \
        == "福岡県福岡市西区姪の浜4丁目0004番地1号"
    # 市区町村名が既に入っていれば県名だけ足す
    assert facilities.geocode_query("宇治市六地蔵1丁目", "26", "宇治市") == "京都府宇治市六地蔵1丁目"
    # 県名が入っていればそのまま
    assert facilities.geocode_query("愛知県豊田市八草町荒山689-2", "23", "豊田市") \
        == "愛知県豊田市八草町荒山689-2"
    assert facilities.geocode_query("", "13", "品川区") == ""


def test_fill_missing_coords_falls_back_to_qualified_address(monkeypatch):
    """既存キャッシュ（住所そのまま）を優先し、無いときだけ県・市を補って問い合わせる。"""
    import crawler.geocode
    fake = _FakeGeocoder()
    fake.cache = {"西区姪の浜1丁目": [33.58, 130.35]}
    monkeypatch.setattr(crawler.geocode, "Geocoder", lambda cache_path=None: fake)
    recs = [
        {"id": "0-0", "a": "西区姪の浜1丁目", "o": "福岡市", "_pref": "40"},   # キャッシュ済み
        {"id": "0-1", "a": "西区姪の浜2丁目", "o": "福岡市", "_pref": "40"},   # 新規
    ]
    facilities.fill_missing_coords(recs)
    assert fake.calls == ["西区姪の浜1丁目", "福岡県福岡市西区姪の浜2丁目"]


def test_rows_to_records_prefers_written_pref_over_broken_jis_code():
    """コードの打ち間違いで別の県に飛ばさない（紀美野町の消防水利XLSXが実例）。

    市区町村コードが 030306（＝岩手県と読めてしまう）でも、都道府県名と住所が
    和歌山県なので和歌山県(30)に入れる。
    """
    rows = facilities.read_csv_text(
        "市区町村コード,NO,都道府県名,市区町村名,種別,住所,緯度(世界測地系),経度(世界測地系)\n"
        "030306,100,和歌山県,紀美野町,消火栓,和歌山県海草郡紀美野町東野,34.16826,135.36252\n")
    recs, _ = facilities.rows_to_records(rows, "fire_water", 0, "紀美野町")
    assert recs[0]["_pref"] == "30"


def test_rows_to_records_uses_jis_code_when_no_pref_name():
    """県名がどこにも書かれていないCSV/XLSX（福岡市型）ではJISコードを使う。"""
    rows = facilities.read_csv_text(
        "全国地方公共団体コード,地方公共団体名,種別,所在地_連結表記,緯度,経度\n"
        "401307,福岡県福岡市,消火栓,西区姪の浜4丁目0004番地1号,,\n")
    recs, _ = facilities.rows_to_records(rows, "fire_water", 0, "福岡市")
    assert recs[0]["_pref"] == "40"
    assert recs[0]["a"] == "西区姪の浜4丁目0004番地1号"
