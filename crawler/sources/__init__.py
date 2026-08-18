"""ソース別パーサ。1ファイル1機関。

新しいパーサを追加したら REGISTRY に登録すること。
"""

from crawler.sources.mlit_cbr_road import MlitCbrRoadParser
from crawler.sources.mlit_hrr_road import MlitHrrRoadParser
from crawler.sources.mlit_ktr import MlitKtrRiverParser
from crawler.sources.mlit_ktr_road import MlitKtrRoadParser
from crawler.sources.mlit_youtube import MlitYoutubeParser

REGISTRY = {
    p.source_id: p
    for p in [
        MlitCbrRoadParser,
        MlitHrrRoadParser,
        MlitKtrRiverParser,
        MlitKtrRoadParser,
        MlitYoutubeParser,
    ]
}
