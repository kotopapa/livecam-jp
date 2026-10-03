"""site/build.py のお知らせ（data/notice.txt）の期限処理。"""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load_build():
    spec = importlib.util.spec_from_file_location("livecam_site_build", ROOT / "site" / "build.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_notice_until(tmp_path, monkeypatch):
    build = _load_build()
    monkeypatch.setattr(build, "DATA", tmp_path)
    (tmp_path / "notice.txt").write_text("until: 2026-10-11\n栃木県の道路カメラの位置を修正しました。\n", encoding="utf-8")
    assert build._notice(today="2026-10-04") == "栃木県の道路カメラの位置を修正しました。"
    assert build._notice(today="2026-10-11") == "栃木県の道路カメラの位置を修正しました。", "期限当日は有効"
    assert build._notice(today="2026-10-12") is None, "期限の翌日から取り下げ"
    # 期限行が無ければ従来どおり（先頭の空行は残す）
    (tmp_path / "notice.txt").write_text("\nお知らせ\n", encoding="utf-8")
    assert build._notice(today="2030-01-01") == "\nお知らせ"
    (tmp_path / "notice.txt").write_text("until: 2026-10-11\n", encoding="utf-8")
    assert build._notice(today="2026-10-04") is None, "本文が空なら非表示"


def test_current_notice_file_has_until():
    text = (ROOT / "data" / "notice.txt").read_text(encoding="utf-8")
    if text.strip():
        assert text.startswith("until: "), "配信中のお知らせには必ず until: の期限行を付ける（2026-10-04 運用）"
