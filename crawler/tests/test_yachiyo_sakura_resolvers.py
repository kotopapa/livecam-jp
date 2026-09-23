import json
from pathlib import Path

from crawler.sources import sakura_bosaicam, yachiyo_kansen

FIX = Path(__file__).parent / "fixtures"


def test_yachiyo_resolves_latest_numbered_image():
    html = (FIX / "yachiyo_kansen_No1.html").read_text(encoding="utf-8")
    hit = yachiyo_kansen.resolve_image_url("https://www.yachiyo-1goukansen-suii.jp/No1.php", html)
    assert hit == ("https://www.yachiyo-1goukansen-suii.jp/camera1/2663.jpg", "2663")
    assert yachiyo_kansen.resolve_image_url("https://x/No1.php", "<html></html>") is None


def test_sakura_decodes_only_healthy_stations():
    d = json.loads((FIX / "sakura_wholemap.json").read_text(encoding="utf-8"))
    imgs = sakura_bosaicam.resolve_images(d)
    # 101/102 は正常（ICON_FLG 501）、103 は不具合（502）なので含めない
    assert set(imgs) == {"101", "102"}
    raw, at = imgs["101"]
    assert raw.startswith(b"\xff\xd8") and at == "2026/09/23 11:02"
    assert sakura_bosaicam.resolve_images({}) == {}
