import json

from tools.x_accounts_publish import public_payload, sync_site


def _data():
    return {
        "generated": "2026-09-07T00:00:00Z",
        "excluded": {"foo": "理由"},
        "prefectures": [
            {"area_code": "11", "area_name": "埼玉県", "handle": "saitama_kasen",
             "url": "https://x.com/saitama_kasen", "display_name": "埼玉県川の防災情報メール",
             "operator": "埼玉県 県土整備部 河川砂防課", "type": "official",
             "type_label": "自治体公式", "disaster_desk": True,
             "profile": "本文\n\n改行あり " + "x" * 200,
             "source": "https://www.pref.saitama.lg.jp/"},
            {"area_code": "99", "area_name": "テスト", "handle": "someone",
             "display_name": "個人", "type": "individual"},
            {"area_code": "98", "area_name": "壊れ", "display_name": "handleなし",
             "type": "official"},
        ],
        "municipalities": [],
        "national_offices": [
            {"area_codes": ["11", "12", "13"], "area_name": "江戸川",
             "handle": "mlit_edogawa", "display_name": "国土交通省 江戸川河川事務所",
             "type": "national", "note": "内部メモ", "policy": "https://example/pdf"},
        ],
        "candidates": [{"handle": "x", "display_name": "候補", "type": "official"}],
        "unresolved_prefectures": ["05 秋田県"],
    }


def test_public_payload_drops_internal_sections_and_non_official():
    p = public_payload(_data())
    assert set(p) == {"generated", "prefectures", "municipalities", "national_offices"}
    assert [e["handle"] for e in p["prefectures"]] == ["saitama_kasen"]
    assert p["national_offices"][0]["area_codes"] == ["11", "12", "13"]
    # 内部メモ・運用ポリシー・type_label は配信しない
    assert "note" not in p["national_offices"][0]
    assert "policy" not in p["national_offices"][0]
    assert "type_label" not in p["prefectures"][0]


def test_profile_is_flattened_and_truncated():
    p = public_payload(_data())
    prof = p["prefectures"][0]["profile"]
    assert "\n" not in prof and len(prof) <= 120 and prof.endswith("…")


def test_sync_site_writes_compact_json(tmp_path):
    src = tmp_path / "in.json"
    out = tmp_path / "v1" / "x_accounts.json"
    src.write_text(json.dumps(_data(), ensure_ascii=False), encoding="utf-8")
    assert sync_site(src, out) == 2
    written = json.loads(out.read_text(encoding="utf-8"))
    assert written["prefectures"][0]["handle"] == "saitama_kasen"
    assert sync_site(tmp_path / "missing.json", out) == 0
