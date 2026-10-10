"""site/build.py の配信軽量化（slim_camera・日次版番号・status_lite）。"""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load_build():
    spec = importlib.util.spec_from_file_location("livecam_site_build2", ROOT / "site" / "build.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


build = _load_build()


def _rec():
    return {
        "id": "a-1", "name": "テスト橋", "name_kana": "", "lat": 35.0, "lng": 139.0,
        "coord_accuracy": "exact", "category": "river", "prefecture": "13", "country": None,
        "municipality": "13101", "river_or_route": "",
        "feed": {"type": "still", "url": "https://e/x.jpg", "refresh_sec": None,
                 "requires_referer": False, "headers": {}, "camera_ref": None},
        "fallback": {"type": "web_page", "url": "https://e/page"},
        "operator": "国交省",
        "source": {"page_url": "https://e/p", "terms_url": None, "license": "unknown", "attribution": "出典"},
        "water_level": {"obs": "123", "dist_m": 0},
        "review": {"status": "approved"}, "first_seen": "2026-01-01", "last_updated": "2026-02-02",
        "verification": {"ok": True},
    }


def test_slim_camera_drops_internal_and_empty():
    out = build.slim_camera(_rec())
    for k in ("review", "first_seen", "last_updated", "verification", "name_kana", "country", "river_or_route"):
        assert k not in out
    assert out["feed"] == {"type": "still", "url": "https://e/x.jpg"}
    assert out["fallback"] == {"url": "https://e/page"}
    assert out["source"] == {"page_url": "https://e/p", "license": "unknown", "attribution": "出典"}
    assert out["id"] == "a-1" and out["lat"] == 35.0 and out["municipality"] == "13101"


def test_slim_camera_keeps_values():
    r = _rec()
    r["feed"].update(refresh_sec=60, requires_referer=True, headers={"Referer": "x"}, camera_ref="c1")
    out = build.slim_camera(r)
    assert out["feed"]["refresh_sec"] == 60 and out["feed"]["requires_referer"] is True
    assert out["feed"]["headers"] == {"Referer": "x"} and out["feed"]["camera_ref"] == "c1"
    assert out["water_level"] == {"obs": "123", "dist_m": 0}, "0 は値として残す"
    r["lat"] = 0.0
    assert build.slim_camera(r)["lat"] == 0.0


def test_delivery_version(monkeypatch):
    monkeypatch.delenv("URGENT_PUBLISH", raising=False)
    assert build.delivery_version("2026-10-07T12:34:56Z") == "2026-10-07"
    monkeypatch.setenv("URGENT_PUBLISH", "0")
    assert build.delivery_version("2026-10-07T12:34:56Z") == "2026-10-07"
    monkeypatch.setenv("URGENT_PUBLISH", "1")
    assert build.delivery_version("2026-10-07T12:34:56Z") == "2026-10-07T12:34:56Z"
    # 台帳の urgent_version が現在の version と一致するあいだは完全な時刻（定期 publish でも戻らない）
    monkeypatch.delenv("URGENT_PUBLISH", raising=False)
    assert build.delivery_version("2026-10-07T12:34:56Z", "2026-10-07T12:34:56Z") == "2026-10-07T12:34:56Z"
    # 台帳が次に変わると自動で日次に戻る
    assert build.delivery_version("2026-10-07T15:00:00Z", "2026-10-07T12:34:56Z") == "2026-10-07"


def test_status_lite():
    st = {"generated_at": "2026-10-07T00:00:00Z", "statuses": {
        "ok1": {"state": "ok", "checked_at": "x"},
        "err": {"state": "error"},
        "frz": {"state": "frozen"},
        "img": {"state": "ok", "image_url": "https://e/i.jpg"},
        "vid": {"state": "ok", "video_id": "abc"},
        "off": {"state": "ok", "live": False},
    }}
    lite = build.build_status_lite(st)
    assert lite["default_state"] == "ok" and lite["generated_at"] == st["generated_at"]
    assert set(lite["statuses"]) == {"err", "frz", "img", "vid", "off"}
