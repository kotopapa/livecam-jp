import json
from datetime import datetime, timezone
from pathlib import Path

from tools import road_regulation as rr

FIX = Path(__file__).parent / "fixtures"


def test_data_dir_and_mesh_filtering():
    assert rr.data_dir('src="../backup/20260921182500/B3mgubW41lRgDll9/bCBbuy3o.js"') == "backup/20260921182500/B3mgubW41lRgDll9/"
    assert rr.data_dir("<html></html>") is None
    items = json.loads((FIX / "road_regulation_mesh.json").read_text(encoding="utf-8"))
    recs = rr.parse_mesh(items)
    # 工事（原因05）と冬期通行止（01+002）は落ち、災害等の通行止（acf2ea4）だけ残る
    assert list(recs) == ["acf2ea4"]
    r = recs["acf2ea4"]
    assert r["level"] == 2 and 33 < r["lat"] < 34 and 133 < r["lng"] < 134
    assert r["lines"] and len(r["lines"][0]) >= 2 and r["at"].startswith("2026-")


def test_parse_detail_blocks_and_item_label():
    html = (FIX / "road_regulation_detail.html").read_text(encoding="utf-8")
    d = rr.parse_detail(html)
    assert set(d) == {"acf2ea4", "24355a76e84f766b"}
    a = d["acf2ea4"]
    assert a["route"] == "高知県道６号 高知伊予三島線" and a["cause"] == "災害等" and a["content"] == "通行止"
    assert a["kind"] == "通行止（都道府県道）" and a["start"] == "2026年08月18日 08:30" and a["status"] == "実施中"
    assert d["24355a76e84f766b"]["cause"] == "道路損壊"
    rec = {"id": "acf2ea4", "lat": 33.8, "lng": 133.4, "level": 2, "at": "2026-08-18 08:30", "lines": []}
    it = rr.make_item(rec, a)
    assert it["name"] == "高知県道６号 高知伊予三島線" and it["label"] == "通行止（災害等）"
    assert it["section"] == "高知県土佐郡大川村大北川" and it["at"] == "2026年08月18日 08:30"
    assert rr.make_item(rec, None)["label"] == "通行止め"


def test_build_signature_and_site_doc():
    now = datetime(2026, 9, 21, 0, 0, tzinfo=timezone.utc)
    recs = rr.parse_mesh(json.loads((FIX / "road_regulation_mesh.json").read_text(encoding="utf-8")))
    details = rr.parse_detail((FIX / "road_regulation_detail.html").read_text(encoding="utf-8"))
    doc = rr.build(None, recs, details, now)
    assert doc["sources"][0]["id"] == "mlit" and len(doc["sources"][0]["items"]) == 1
    assert "acf2ea4" in doc["detail_cache"] and "24355a76e84f766b" not in doc["detail_cache"]
    same = rr.build(doc, recs, details, datetime(2026, 9, 21, 1, 0, tzinfo=timezone.utc))
    assert rr.signature(same) == rr.signature(doc)


def test_simplify_keeps_ends_and_corners():
    straight = [[35.0, 139.0 + i * 0.0001] for i in range(50)]
    assert rr.simplify(straight) == [straight[0], straight[-1]]
    bent = [[35.0, 139.0], [35.0, 139.005], [35.005, 139.005], [35.005, 139.01]]
    assert rr.simplify(bent) == bent
    assert rr.simplify([[1.0, 2.0]]) == [[1.0, 2.0]]
