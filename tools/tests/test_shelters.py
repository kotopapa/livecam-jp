"""tools.shelters の CSV→JSON 変換と都道府県コード変換のテスト。"""

import json

from tools import shelters

EVAC_CSV = "﻿" + """NO,共通ID,都道府県名及び市町村名,施設・場所名,住所,洪水,崖崩れ、土石流及び地滑り,高潮,地震,津波,大規模な火事,内水氾濫,火山現象,指定避難所との住所同一,緯度,経度,備考
1,E0110000001202,北海道札幌市,もみじ台中学校,北海道札幌市厚別区もみじ台西1-1-1,1,1,,1,,1,,,1,43.03806002377,141.48471007692,
2,E0110000003201,北海道札幌市,熊の沢公園,北海道札幌市厚別区もみじ台西6,,,,,,1,,,,43.029200723126,141.49060815161,
3,E1410000001201,神奈川県横浜市,横浜公園,神奈川県横浜市中区横浜公園,,,,1,,1,,,,35.44383,139.64027,
4,E1410000002201,神奈川県横浜市,座標なし,神奈川県横浜市中区,1,,,,,,,,,,,
5,E4620100001201,鹿児島県鹿児島市,天文館,鹿児島県鹿児島市東千石町,,,,,,,,1,,999,130.55,
"""

SHELTER_CSV = "﻿" + """NO,共通ID,都道府県名及び市町村名,施設・場所名,住所,指定緊急避難場所との住所同一,その他市町村長が必要と認める事項,受入対象者,緯度,経度,備考
1,E0110000001111,北海道札幌市,もみじ台中学校,北海道札幌市厚別区もみじ台西1-1-1,1,,,43.03806002,141.4847101,
2,E1410000009111,神奈川県横浜市,避難所のみ会館,神奈川県横浜市中区本町,,,,35.45,139.63,
"""


def test_pref_code_by_name():
    assert shelters.pref_code("北海道札幌市") == "01"
    assert shelters.pref_code("神奈川県横浜市") == "14"
    assert shelters.pref_code("和歌山県和歌山市") == "30"
    assert shelters.pref_code("鹿児島県鹿児島市") == "46"
    assert shelters.pref_code("沖縄県那覇市") == "47"
    assert shelters.pref_code("東京都千代田区") == "13"


def test_pref_code_fallback_to_common_id():
    assert shelters.pref_code("", "E1310100001201") == "13"
    assert shelters.pref_code("不明", "") is None
    assert shelters.pref_code("不明", "E9910100001201") is None


def test_convert_rows():
    evac = shelters.read_csv_text(EVAC_CSV)
    shel = shelters.read_csv_text(SHELTER_CSV)
    assert evac[0]["NO"] == "1"  # BOMが列名に残らない
    by_pref, stats = shelters.convert(evac, shel)

    assert set(by_pref) == {"01", "14"}
    assert stats["skipped_coord"] == 2  # 空座標 + 範囲外
    assert stats["shelter_only"] == 1
    assert stats["matched"] == 1

    hokkaido = {r["id"]: r for r in by_pref["01"]}
    momiji = hokkaido["E0110000001202"]
    assert momiji["n"] == "もみじ台中学校"
    assert momiji["a"] == "北海道札幌市厚別区もみじ台西1-1-1"
    assert momiji["lat"] == 43.03806 and momiji["lng"] == 141.48471  # 小数5桁
    assert momiji["f"] == [0, 1, 3, 5]  # 洪水,土砂,地震,火事
    assert momiji["s"] == 1
    kuma = hokkaido["E0110000003201"]
    assert kuma["f"] == [5] and "s" not in kuma

    kanagawa = {r["id"]: r for r in by_pref["14"]}
    assert kanagawa["E1410000001201"]["f"] == [3, 5]
    only = kanagawa["E1410000009111"]
    assert only["s"] == 1 and only["f"] == [] and only["n"] == "避難所のみ会館"


def test_write_outputs(tmp_path):
    evac = shelters.read_csv_text(EVAC_CSV)
    shel = shelters.read_csv_text(SHELTER_CSV)
    by_pref, _ = shelters.convert(evac, shel)
    index = shelters.write_outputs(by_pref, "2026-09-01T00:00:00Z",
                                   "Mon, 24 Aug 2026 06:19:57 GMT", out_dir=tmp_path)
    assert index["total"] == 4
    assert index["counts"] == {"01": 2, "14": 2}
    assert "国土地理院" in index["attribution"]
    assert "市町村" in index["notice"]
    assert index["hazards"][1] == "土砂"
    on_disk = json.loads((tmp_path / "01.json").read_text(encoding="utf-8"))
    assert on_disk["version"] == "2026-09-01T00:00:00Z"
    assert len(on_disk["shelters"]) == 2
    assert json.loads((tmp_path / "index.json").read_text(encoding="utf-8"))["total"] == 4


def test_parse_http_date_is_aware_and_locale_independent():
    # strptime("%a, %d %b %Y %H:%M:%S %Z") は曜日/月名がロケール依存で、
    # %Z が tzinfo を設定しない（naive になる）。email.utils なら常に aware。
    dt = shelters.parse_http_date("Mon, 01 Jan 2024 00:00:00 GMT")
    assert dt is not None and dt.tzinfo is not None
    assert dt.utcoffset().total_seconds() == 0
    # 数値オフセット表記（旧実装は %Z にマッチせず ValueError で捨てていた）
    dt2 = shelters.parse_http_date("Mon, 01 Jan 2024 09:00:00 +0900")
    assert dt2 == dt          # 同一時刻として比較できる
    assert shelters.parse_http_date("not a date") is None
    assert shelters.parse_http_date(None) is None


def test_latest_compares_across_timezone_notations():
    older = "Mon, 01 Jan 2024 00:00:00 GMT"       # = 09:00 JST
    newer = "Mon, 01 Jan 2024 10:00:00 +0900"     # = 01:00 GMT（こちらが新しい）
    assert shelters._latest(older, newer) == newer
    assert shelters._latest(newer, older) == newer
