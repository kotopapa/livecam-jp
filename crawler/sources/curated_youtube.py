"""人手キュレーションの民間・報道系YouTubeライブカメラ（SPEC 1.3 条件付き民間スコープ）。

台帳は crawler/curated_youtube.yaml。機械クロールはせず、運営者を確認した
カメラだけを人手で追加する（民間まとめサイトのクロール禁止=C4は維持）。

- feed.type=youtube_video。報道系は配信枠の更新で動画IDが変わるため、
  台帳更新 + crawler/main.py の承認済みfeed安全更新で追従する
- 座標は設置地点の手動指定（coord_accuracy=approx）
- license=unknown（各運営者の利用条件はレビューで確認。削除依頼即応）
"""

from __future__ import annotations

from pathlib import Path

import yaml

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

YAML_PATH = Path(__file__).resolve().parent.parent / "curated_youtube.yaml"


def load_curated(path: Path = YAML_PATH) -> list[dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return data.get("cameras", [])


class CuratedYoutubeParser(SourceParser):
    source_id = "curated_youtube"
    seed_url = str(YAML_PATH)

    def discover(self, session: HttpSession) -> DiscoverResult:  # noqa: ARG002
        result = DiscoverResult()
        for cam in load_curated():
            try:
                note = ("民間・報道系の公式YouTubeライブ（キュレーション台帳）。"
                        "埋め込み再生のみ・削除依頼即応。")
                if cam.get("note"):
                    note += f" {cam['note']}"
                if cam.get("channel_id"):
                    feed_type = "youtube_channel"
                    feed_url = cam["channel_id"]
                    fallback = f"https://www.youtube.com/channel/{feed_url}/live"
                else:
                    feed_type = "youtube_video"
                    feed_url = cam["video_id"]
                    fallback = f"https://www.youtube.com/watch?v={feed_url}"
                result.candidates.append(CameraCandidate(
                    id=cam["id"],
                    name=cam["name"],
                    category=cam.get("category", "scenic"),
                    prefecture=str(cam.get("prefecture", "13")),
                    feed_type=feed_type,
                    feed_url=feed_url,
                    fallback_url=fallback,
                    operator=cam["operator"],
                    page_url=fallback,
                    attribution=f"映像提供：{cam['operator']}（YouTubeライブ）",
                    license="unknown",
                    terms_url=None,
                    lat=float(cam["lat"]), lng=float(cam["lng"]),
                    coord_accuracy=cam.get("accuracy", "approx"),
                    review_note=note,
                ))
            except (KeyError, TypeError, ValueError) as e:
                result.errors.append(f"curated行の不備 {cam.get('id')}: {e}")
        if not result.candidates:
            result.errors.append("curated_youtube.yaml にカメラがない")
        return result
