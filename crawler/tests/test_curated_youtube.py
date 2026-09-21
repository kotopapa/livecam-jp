

def test_embed_false_becomes_web_page(monkeypatch, tmp_path):
    from crawler.sources import curated_youtube as cy
    y = tmp_path / "c.yaml"
    y.write_text(
        "cameras:\n"
        "  - id: t1\n    name: A\n    operator: op\n    channel_id: UCx\n    embed: false\n    lat: 35.0\n    lng: 139.0\n"
        "  - id: t2\n    name: B\n    operator: op\n    video_id: vid1\n    embed: false\n    lat: 35.0\n    lng: 139.0\n"
        "  - id: t3\n    name: C\n    operator: op\n    channel_id: UCy\n    lat: 35.0\n    lng: 139.0\n",
        encoding="utf-8")
    # load_curated の既定引数は定義時に固定されるので関数ごと差し替える
    monkeypatch.setattr(cy, "load_curated", lambda path=None: cy.load_curated.__wrapped__(y) if hasattr(cy.load_curated, "__wrapped__") else __import__("yaml").safe_load(y.read_text(encoding="utf-8"))["cameras"])
    res = cy.CuratedYoutubeParser().discover(None)
    by = {c.id: c for c in res.candidates}
    assert by["t1"].feed_type == "web_page" and by["t1"].feed_url == "https://www.youtube.com/channel/UCx/live"
    assert by["t2"].feed_type == "web_page" and by["t2"].feed_url == "https://www.youtube.com/watch?v=vid1"
    assert by["t3"].feed_type == "youtube_channel" and by["t3"].feed_url == "UCy"
    assert "誘導" in by["t1"].review_note
