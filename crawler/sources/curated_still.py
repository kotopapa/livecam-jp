"""人手キュレーションの静止画ライブカメラ（ダム・山小屋・水族館等の単発カメラ）。

台帳は crawler/curated_still.yaml。機械クロールはせず、運営者と画像URLを
確認したカメラだけを人手で追加する（民間まとめサイトのクロール禁止=C4は維持）。

- feed.type=still_image（画像URL直接検証済みのもののみ載せる）
- タイムスタンプ名画像のみのカメラは feed_type/feed_url を明示指定できる
  （例: feed_type=thr_camxml + feed_url=<XML URL>。monitorが都度解決）
- 座標は設置地点の手動指定（coord_accuracy=approx）
- license=unknown（各運営者の利用条件はレビューで確認。削除依頼即応）
"""

from __future__ import annotations

from pathlib import Path

import yaml

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

YAML_PATH = Path(__file__).resolve().parent.parent / "curated_still.yaml"


def load_curated(path: Path = YAML_PATH) -> list[dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return data.get("cameras", [])


class CuratedStillParser(SourceParser):
    source_id = "curated_still"
    seed_url = str(YAML_PATH)

    def discover(self, session: HttpSession) -> DiscoverResult:  # noqa: ARG002
        result = DiscoverResult()
        for cam in load_curated():
            try:
                note = "静止画キュレーション台帳。利用条件はレビューで確認・削除依頼即応。"
                if cam.get("note"):
                    note += f" {cam['note']}"
                result.candidates.append(CameraCandidate(
                    id=cam["id"],
                    name=cam["name"],
                    category=cam.get("category", "other"),
                    prefecture=str(cam.get("prefecture", "13")),
                    feed_type=cam.get("feed_type", "still_image"),
                    feed_url=cam.get("feed_url") or cam["image_url"],
                    fallback_url=cam["page_url"],
                    operator=cam["operator"],
                    page_url=cam["page_url"],
                    attribution=f"映像提供：{cam['operator']}",
                    license="unknown",
                    refresh_sec=int(cam.get("refresh_sec", 600)),
                    lat=float(cam["lat"]), lng=float(cam["lng"]),
                    coord_accuracy="approx",
                    review_note=note,
                ))
            except (KeyError, TypeError, ValueError) as e:
                result.errors.append(f"curated_still {cam.get('id')}: {e}")
        if not result.candidates:
            result.errors.append("curated_still: 台帳が空")
        return result
