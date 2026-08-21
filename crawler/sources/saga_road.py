"""佐賀県「佐賀県道路情報」(sagacat.or.jp) 道路カメラパーサ。

地図データ roadinfo/camimage/map/data/maps<N>.json (N=1..) に地区ごとの
カメラ台帳が入っている。1件は配列:
  [地区slug, 地区名, カメラID, 道路種別, 路線番号, 路線名, 住所, 地点名,
   "../data/<id>.jpg", 日付, _, _, _, lat, lng]
静止画は roadinfo/camimage/data/<id>.jpg の固定URL。
"""

from __future__ import annotations

import json

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.sagacat.or.jp/roadinfo/camimage/"
MAPS_URL = BASE + "map/data/maps{n}.json"
PAGE_URL = "https://www.sagacat.or.jp/kisei/"
MAX_MAPS = 10


class SagaRoadParser(SourceParser):
    source_id = "saga_road"
    seed_url = MAPS_URL.format(n=1)

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for n in range(1, MAX_MAPS + 1):
            page = session.fetch(MAPS_URL.format(n=n))
            if not page.ok:
                continue  # 地区数は可変。404は正常
            try:
                rows = json.loads(page.text)
            except ValueError:
                result.errors.append(f"saga_road maps{n}: JSONを解釈できない")
                continue
            for row in rows:
                if len(row) < 15:
                    continue
                (_, _, cid, road_kind, road_no, route, addr, point,
                 img, *_rest) = row[:9] + [None]
                lat, lng = float(row[13]), float(row[14])
                img_name = str(row[8]).rsplit("/", 1)[-1]
                route_label = f"{road_kind}{road_no}号" if road_no else road_kind
                result.candidates.append(CameraCandidate(
                    id=f"saga-road-{str(cid).lower()}",
                    name=f"{route} {point}".strip(),
                    category="road",
                    prefecture="41",
                    feed_type="still_image",
                    feed_url=BASE + "data/" + img_name,
                    fallback_url=PAGE_URL,
                    operator="佐賀県",
                    page_url=PAGE_URL,
                    attribution="出典：佐賀県道路情報（佐賀県県土整備部）",
                    license="unknown",
                    refresh_sec=600,
                    lat=lat, lng=lng, coord_accuracy="exact",
                    river_or_route=route_label,
                    address_hint=addr or None,
                    review_note="佐賀県道路カメラ。利用条件はレビューで確認",
                ))
        if not result.candidates:
            result.errors.append("saga_road: カメラが1件も取れない")
        return result
