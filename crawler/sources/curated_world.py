"""人手キュレーションの世界（海外）YouTubeライブカメラ。

台帳は crawler/curated_world.yaml。国内の curated_youtube と同じ運用:
機械クロールはせず、IDを検証したカメラだけを人手で追加する。

- prefecture は "99"（海外）固定。country に ISO 3166-1 alpha-2 を持つ
- feed.type=youtube_video（embeddable=false のものは note の指示に従い
  承認後に web_page 誘導型へ変換する）
- license=unknown（削除依頼即応）
"""

from __future__ import annotations

from pathlib import Path

import yaml

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

YAML_PATH = Path(__file__).resolve().parent.parent / "curated_world.yaml"


def load_world(path: Path = YAML_PATH) -> list[dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return data.get("cameras", [])


class CuratedWorldParser(SourceParser):
    source_id = "curated_world"
    seed_url = str(YAML_PATH)

    def discover(self, session: HttpSession) -> DiscoverResult:  # noqa: ARG002
        result = DiscoverResult()
        for cam in load_world():
            try:
                note = "世界の有名スポット（キュレーション台帳）。埋め込み再生のみ・削除依頼即応。"
                if cam.get("note"):
                    note += f" {cam['note']}"
                vid = str(cam["video_id"])
                result.candidates.append(CameraCandidate(
                    id=str(cam["id"]),
                    name=str(cam["name"]),
                    category=str(cam.get("category", "scenic")),
                    prefecture="99",
                    country=str(cam["country"]),
                    feed_type="youtube_video",
                    feed_url=vid,
                    fallback_url=f"https://www.youtube.com/watch?v={vid}",
                    operator=str(cam["operator"]),
                    page_url=f"https://www.youtube.com/watch?v={vid}",
                    attribution=f"映像提供：{cam['operator']}（YouTubeライブ）",
                    license="unknown",
                    lat=float(cam["lat"]), lng=float(cam["lng"]),
                    coord_accuracy=str(cam.get("accuracy", "approx")),
                    review_note=note,
                ))
            except (KeyError, TypeError, ValueError) as e:
                result.errors.append(f"curated_world: 不正なエントリ {cam.get('id')}: {e}")
        if not result.candidates:
            result.errors.append("curated_world: 台帳が空")
        return result
