from crawler.sources.roundshot import half_url

ENTRY = "https://zbag.roundshot.com/cams/964"
LOC = "https://storage4.roundshot.com/5cda5bf21a7198.55013080/2026-10-15/16-10-00/2026-10-15-16-10-00_full.jpg"


def test_half_url_from_location():
    url, t = half_url(ENTRY, LOC)
    assert url == LOC.replace("_full.jpg", "_half.jpg")
    assert t == "2026-10-15 16:10:00"


def test_half_url_relative_location():
    url, _ = half_url(ENTRY, "/k/2026-01-02/03-04-05/2026-01-02-03-04-05_full.jpg")
    assert url == "https://zbag.roundshot.com/k/2026-01-02/03-04-05/2026-01-02-03-04-05_half.jpg"


def test_half_url_rejects_unexpected():
    assert half_url(ENTRY, None) is None
    assert half_url(ENTRY, "https://example.com/login") is None
