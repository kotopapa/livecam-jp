from tools.hotel_keywords import build_table, common_prefix, sjis_quote


def test_sjis_quote_matches_jalan_encoding():
    # 2026-09-03 に実測した じゃらん検索URLの keyword 値
    assert sjis_quote("富士河口湖町") == "%95x%8Em%89%CD%8C%FB%8C%CE%92%AC"


def test_common_prefix_folds_split_municipalities():
    assert common_prefix(["釧路市音別", "釧路市阿寒", "釧路市釧路"]) == "釧路市"
    assert common_prefix(["羽幌町", "羽幌町天売焼尻"]) == "羽幌町"
    assert common_prefix(["十日町市"]) == "十日町市"


def test_build_table_keys_by_jis5():
    class20s = {
        "4720700": {"name": "石垣市"},
        "0120600": {"name": "釧路市釧路"},
        "0120601": {"name": "釧路市阿寒"},
        "1410000": {"name": "横浜市"},
        "9999999": {"name": ""},
    }
    t = build_table(class20s)
    assert t["47207"][0] == "石垣市"
    assert t["01206"][0] == "釧路市"
    assert t["14100"][0] == "横浜市"
    assert "99999" not in t
    assert all(len(v) == 2 and v[1] for v in t.values())
