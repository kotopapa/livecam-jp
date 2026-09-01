"""stockpile_check の判定・除去・レポートのテスト。ネットワークは使わない。"""

import json

import pytest

from tools import stockpile_check as sc


DOC = {
    "version": "2026-09-01T00:00:00Z",
    "categories": [
        {"key": "water_food", "items": [
            {"id": "w-water", "name": "長期保存水",
             "search": {"yahoo": "長期保存水 5年", "rakuten": "長期保存水 5年",
                        "amazon": "長期保存水 5年"},
             "products": [
                 {"shop": "yahoo", "title": "A", "url": "https://example.com/a"},
                 {"shop": "rakuten", "title": "B", "url": "https://example.com/b"},
             ]},
            {"id": "w-rice", "name": "アルファ米",
             "search": {"yahoo": "アルファ米 5年", "rakuten": "アルファ米 5年",
                        "amazon": "アルファ米 5年"},
             "products": [{"shop": "yahoo", "title": "C", "url": "https://example.com/c"}]},
        ]},
        {"key": "light_power", "items": [
            {"id": "l-lantern", "name": "LEDランタン",
             "search": {"yahoo": "LEDランタン 乾電池", "rakuten": "LEDランタン 乾電池",
                        "amazon": "LEDランタン 乾電池"}},
        ]},
    ],
}


# --- classify ------------------------------------------------------------

def test_classify_200_is_alive():
    assert sc.classify(200, "https://example.com/a", "https://example.com/a") == "alive"


def test_classify_200_with_harmless_redirect_is_alive():
    # httpsへの正規化や末尾スラッシュ程度のリダイレクトは生存扱い
    assert sc.classify(200, "https://example.com/a/", "https://example.com/a") == "alive"


@pytest.mark.parametrize("status", [404, 410])
def test_classify_notfound_is_dead(status):
    assert sc.classify(status, None, "https://example.com/a") == "dead"


@pytest.mark.parametrize("final", [
    "https://shopping.yahoo.co.jp/search?p=%E6%B0%B4",
    "https://search.rakuten.co.jp/search/mall/水/",
    "https://www.amazon.co.jp/s?k=water",
    "https://item.rakuten.co.jp/shop/error/",
    "https://shopping.yahoo.co.jp/",           # トップへ飛ばされた
])
def test_classify_redirect_to_search_is_dead(final):
    assert sc.classify(200, final, "https://example.com/a") == "dead"


@pytest.mark.parametrize("status", [403, 429, 500, 503])
def test_classify_blocked_or_server_error_is_unknown(status):
    # モールのbot対策・一時障害では消さない（判定保留）
    assert sc.classify(status, None, "https://example.com/a") == "unknown"


def test_classify_connection_failure_is_unknown():
    assert sc.classify(None, None, "https://example.com/a") == "unknown"


def test_looks_like_search_or_error():
    assert sc.looks_like_search_or_error("https://a.example/search?p=x")
    assert sc.looks_like_search_or_error("https://a.example/")
    assert not sc.looks_like_search_or_error("https://a.example/item/12345")


# --- apply_removals ------------------------------------------------------

def test_apply_removals_drops_only_dead_products():
    out, removed = sc.apply_removals(DOC, {"https://example.com/b"})
    urls = [p["url"] for _, _, p in sc.iter_products(out)]
    assert urls == ["https://example.com/a", "https://example.com/c"]
    assert len(removed) == 1
    assert removed[0]["url"] == "https://example.com/b"
    assert removed[0]["category"] == "water_food"


def test_apply_removals_keeps_search_terms():
    out, _ = sc.apply_removals(DOC, {"https://example.com/a", "https://example.com/b",
                                     "https://example.com/c"})
    for cat in out["categories"]:
        for item in cat["items"]:
            assert item["search"]["yahoo"]
            assert item["search"]["rakuten"]
            assert item["search"]["amazon"]
    assert sc.count_products(out) == 0
    # 項目そのものは消えない
    assert sc.count_items(out) == sc.count_items(DOC)


def test_apply_removals_removes_empty_products_key():
    out, _ = sc.apply_removals(DOC, {"https://example.com/c"})
    rice = out["categories"][0]["items"][1]
    assert "products" not in rice
    assert rice["search"]["yahoo"] == "アルファ米 5年"


def test_apply_removals_does_not_mutate_input():
    before = json.dumps(DOC, ensure_ascii=False, sort_keys=True)
    sc.apply_removals(DOC, {"https://example.com/a"})
    assert json.dumps(DOC, ensure_ascii=False, sort_keys=True) == before


def test_apply_removals_noop_when_nothing_dead():
    out, removed = sc.apply_removals(DOC, set())
    assert removed == []
    assert sc.count_products(out) == 3


# --- 集計 / レポート -----------------------------------------------------

def test_iter_products_and_counts():
    assert sc.count_products(DOC) == 3
    assert sc.count_items(DOC) == 3
    keys = [(c, i) for c, i, _ in sc.iter_products(DOC)]
    assert keys[0] == ("water_food", "w-water")


def test_items_without_products_are_skipped():
    assert all(item_id != "l-lantern" for _, item_id, _ in sc.iter_products(DOC))


def test_build_report_lists_removed_and_threshold_note():
    removed = [{"category": "water_food", "item": "w-water", "name": "長期保存水",
                "shop": "yahoo", "title": "A", "url": "https://example.com/a",
                "result": "HTTP 404"}]
    r = sc.build_report(removed, [], "2026-09-01T00:00:00Z", alive=2, threshold=1)
    assert "https://example.com/a" in r
    assert "HTTP 404" in r
    assert "要対応" in r


def test_build_report_no_threshold_note_when_below():
    removed = [{"category": "c", "item": "i", "name": "n", "shop": "s", "title": "t",
                "url": "u", "result": "HTTP 404"}]
    r = sc.build_report(removed, [], "2026-09-01T00:00:00Z", alive=2, threshold=3)
    assert "要対応" not in r


def test_build_report_unknown_section():
    unknown = [{"shop": "amazon", "url": "https://example.com/x", "result": "HTTP 503"}]
    r = sc.build_report([], unknown, "2026-09-01T00:00:00Z", alive=1, threshold=3)
    assert "保留" in r
    assert "https://example.com/x" in r


# --- check_all（HTTPはスタブ） -------------------------------------------

def test_check_all_uses_stub(monkeypatch):
    responses = {
        "https://example.com/a": (200, "https://example.com/a"),
        "https://example.com/b": (404, None),
        "https://example.com/c": (503, None),
    }
    monkeypatch.setattr(sc, "probe", lambda session, url: responses[url])
    dead, unknown, alive = sc.check_all(DOC, session=object())
    assert [d["url"] for d in dead] == ["https://example.com/b"]
    assert [u["url"] for u in unknown] == ["https://example.com/c"]
    assert alive == 1


# --- sync_site -----------------------------------------------------------

def test_sync_site_copies_json(tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    (src / "products.json").write_text("{}", encoding="utf-8")
    (src / "README.txt").write_text("x", encoding="utf-8")
    dst = tmp_path / "dst"
    assert sc.sync_site(src, dst) == 1
    assert (dst / "products.json").exists()
    assert not (dst / "README.txt").exists()


def test_sync_site_missing_src(tmp_path):
    assert sc.sync_site(tmp_path / "nope", tmp_path / "dst") == 0


def test_build_report_falls_back_to_item_id_when_no_name():
    # check_all が返すレコードは name を持たない（item だけ）。列が空にならないこと
    removed = [{"category": "water_food", "item": "w-water", "shop": "yahoo", "title": "A",
                "url": "https://example.com/a", "result": "HTTP 404"}]
    r = sc.build_report(removed, [], "2026-09-01T00:00:00Z", alive=2, threshold=3)
    assert "w-water" in r
