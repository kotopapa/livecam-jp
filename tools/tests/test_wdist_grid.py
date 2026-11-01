"""tools/wdist_grid.py: 格子番号・色コード・ブロック分割・index・basetime 同じなら再生成しない分岐。"""
import gzip
import json
from io import BytesIO

from PIL import Image

from tools import wdist_grid as w

BASE = "20261101080000"
V1, V2 = "20261101120000", "20261101150000"
TT = [
    {"basetime": BASE, "validtime": V1, "member": "none", "elements": ["temp_point", "wm", "r3", "s3"]},
    {"basetime": BASE, "validtime": V2, "member": "none", "elements": ["wm"]},
]


def _png(rgba):
    b = BytesIO()
    Image.new("RGBA", (256, 256), rgba).save(b, "PNG")
    return b.getvalue()


def _geojson(pts):
    return json.dumps({"features": [{"geometry": {"coordinates": [lng, lat]}, "properties": {"value": str(v)}}
                                    for lat, lng, v in pts]}).encode()


class FakeFx:
    def __init__(self, published=None, fail_jma=False):
        self.published = published or {}
        self.fail_jma = fail_jma
        self.urls = []

    def get(self, url):
        self.urls.append(url)
        if url.startswith(w.PUBLISHED_BASE):
            name = url[len(w.PUBLISHED_BASE):]
            if name in self.published:
                return self.published[name]
            raise OSError("404")
        if self.fail_jma:
            raise OSError("down")
        if url.endswith("targetTimes.json"):
            return json.dumps(TT).encode()
        if url.endswith("data.geojson"):
            return gzip.compress(_geojson([(35.675, 139.78125, -2), (43.025, 141.40625, 3)]))
        if "/wm/" in url:
            return _png((0, 65, 255, 255))
        if "/r3/" in url:
            return _png((255, 245, 0, 255))
        raise OSError("404")

    def json(self, url):
        return json.loads(self.get(url).decode())


def test_grid_and_block():
    gi, gj = w.grid_index(35.675, 139.78125)
    assert w.grid_latlng(gi, gj) == (35.675, 139.78125) or all(
        abs(a - b) < 1e-9 for a, b in zip(w.grid_latlng(gi, gj), (35.675, 139.78125)))
    lat0, lng0, i, j = w.block_of(gi, gj)
    assert (lat0, lng0) == (34, 138)
    assert abs(lat0 + 0.025 + 0.05 * i - 35.675) < 1e-9
    assert abs(lng0 + 0.03125 + 0.0625 * j - 139.78125) < 1e-9
    assert 0 <= i < 40 and 0 <= j < 32


def test_color_code():
    assert w.color_code("wm", (255, 170, 0, 255)) == 1
    assert w.color_code("wm", (250, 172, 3, 255)) == 1
    assert w.color_code("wm", (0, 65, 255, 0)) == 0
    assert w.color_code("r3", (255, 153, 0, 255)) == 5
    assert w.color_code("s3", (0, 65, 255, 255)) == 3
    assert w.color_code("s3", (255, 0, 0, 255)) == 0


def test_generate(tmp_path):
    assert w.generate(tmp_path, FakeFx())
    idx = json.loads((tmp_path / "index.json").read_text())
    assert idx["basetime"] == BASE and idx["validtimes"] == [V1, V2]
    assert sorted(idx["blocks"]) == ["34_138", "42_140"]
    blk = json.loads((tmp_path / "34_138.json").read_text())
    assert blk["lat0"] == 34 and len(blk["points"]) == 1
    p = blk["points"][0]
    assert p["t"] == [-2, None] and p["w"] == [3, 3] and p["r"] == [4, 0] and p["s"] == [0, 0]


def test_reuse_when_same_basetime(tmp_path):
    pub = {"index.json": json.dumps({"basetime": BASE, "validtimes": [V1], "generated": "x", "blocks": ["1_2"]}).encode(),
           "1_2.json": b'{"a":1}'}
    fx = FakeFx(published=pub)
    assert w.sync_site(fx, tmp_path) == 2
    assert (tmp_path / "1_2.json").read_bytes() == b'{"a":1}'
    assert not any("temp_point" in u for u in fx.urls)


def test_regenerate_when_basetime_differs(tmp_path):
    pub = {"index.json": json.dumps({"basetime": "20261031080000", "blocks": ["1_2"]}).encode()}
    fx = FakeFx(published=pub)
    assert w.sync_site(fx, tmp_path) == 3
    assert (tmp_path / "34_138.json").exists() and not (tmp_path / "1_2.json").exists()


def test_nothing_when_all_down(tmp_path):
    assert w.sync_site(FakeFx(fail_jma=True), tmp_path) == 0
    assert not list(tmp_path.glob("*.json"))
