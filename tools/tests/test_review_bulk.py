"""一括承認（review_cli --bulk）の選定・適用ロジックのテスト。"""

import copy
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "tools"))

from review_cli import apply_bulk_approval, matches_filters  # noqa: E402


def make_rec(**over) -> dict:
    rec = {
        "id": "kawabou-100081001",
        "name": "豊平川KP19.8右岸カメラ",
        "lat": 43.01095,
        "lng": 141.3526472,
        "coord_accuracy": "exact",
        "category": "river",
        "prefecture": "01",
        "municipality": "01100",
        "river_or_route": "豊平川",
        "feed": {
            "type": "still_image",
            "url": "https://cam.river.go.jp/cam/now/100081001.jpg",
            "refresh_sec": None,
            "requires_referer": False,
            "headers": {},
        },
        "fallback": {"type": "web_page", "url": "https://www.river.go.jp/kawabou/pc/tm?scamId=100081001"},
        "operator": "国土交通省 札幌開発建設部",
        "source": {
            "page_url": "https://www.river.go.jp/kawabou/pc/tm?scamId=100081001",
            "terms_url": "https://www.river.go.jp/riyou",
            "license": "public_data_1.0",
            "attribution": "出典：国土交通省「川の防災情報」",
        },
        "review": {"status": "pending", "reviewed_at": None, "note": ""},
        "verification": {"image_changed": True, "content_type": "image/jpeg", "bytes": 12345},
    }
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(rec.get(k), dict):
            rec[k] = {**rec[k], **v}
        else:
            rec[k] = v
    return rec


class TestMatchesFilters:
    def test_license_and_verified(self):
        rec = make_rec()
        assert matches_filters(rec, license="public_data_1.0", verified=True)
        assert not matches_filters(rec, license="unknown")

    def test_pending_以外は常に対象外(self):
        rec = make_rec(review={"status": "approved"})
        assert not matches_filters(rec, license="public_data_1.0")

    def test_検証未確認はverifiedで落ちる(self):
        rec = make_rec(verification={"image_changed": False})
        assert not matches_filters(rec, verified=True)
        rec2 = make_rec()
        del rec2["verification"]
        assert not matches_filters(rec2, verified=True)

    def test_都道府県は複数指定(self):
        rec = make_rec(prefecture="14")
        assert matches_filters(rec, prefs=["13", "14"])
        assert not matches_filters(rec, prefs=["13"])

    def test_運営者は部分一致(self):
        rec = make_rec()
        assert matches_filters(rec, operator="国土交通省")
        assert not matches_filters(rec, operator="神奈川県")


class TestApplyBulkApproval:
    def test_承認してcamerasへ移りverificationは持ち込まない(self):
        rec = make_rec()
        cameras = {"version": None, "cameras": []}
        approved, skipped = apply_bulk_approval([rec], cameras, "bulk: test", "2026-08-18")
        assert approved == [rec["id"]] and skipped == []
        moved = cameras["cameras"][0]
        assert moved["review"]["status"] == "approved"
        assert moved["review"]["note"] == "bulk: test"
        assert "verification" not in moved

    def test_スキーマNGはpendingのまま残しnoteも保全(self):
        rec = make_rec(category="invalid-category",
                       review={"status": "pending", "reviewed_at": None, "note": "元のメモ"})
        cameras = {"version": None, "cameras": []}
        approved, skipped = apply_bulk_approval([rec], cameras, "bulk: test", "2026-08-18")
        assert approved == [] and len(skipped) == 1
        assert rec["review"]["status"] == "pending"
        assert rec["review"]["note"] == "元のメモ"
        assert cameras["cameras"] == []

    def test_既存IDはスキップ(self):
        rec = make_rec()
        cameras = {"version": None, "cameras": [copy.deepcopy(rec)]}
        approved, skipped = apply_bulk_approval([rec], cameras, "bulk: test", "2026-08-18")
        assert approved == []
        assert skipped[0][0] == rec["id"]
        assert len(cameras["cameras"]) == 1
