"""shizukawa_coast パーサのテスト。"""

from pathlib import Path

from crawler.sources.shizukawa_coast import ADDRESS_HINTS, parse_area

FIXTURE = Path(__file__).parent / "fixtures" / "shizukawa_suruga.html"


def test_parse_area_suruga():
    cams = parse_area(FIXTURE.read_text(encoding="utf-8"))
    assert len(cams) == 12
    slugs = {s for s, _ in cams}
    assert "suruga-ooigawakakou" in slugs
    names = {n for _, n in cams}
    assert "大井川河口右岸" in names


def test_known_names_have_hints():
    cams = parse_area(FIXTURE.read_text(encoding="utf-8"))
    # 駿河海岸エリアは全地点に住所ヒントがある
    for _, name in cams:
        assert name in ADDRESS_HINTS, name
