"""ソース別パーサ。1ファイル1機関。

新しいパーサを追加したら REGISTRY に登録すること。
"""

from crawler.sources.curated_youtube import CuratedYoutubeParser
from crawler.sources.mlit_cbr_road import MlitCbrRoadParser
from crawler.sources.mlit_hrr_road import MlitHrrRoadParser
from crawler.sources.mlit_ktr import MlitKtrRiverParser
from crawler.sources.mlit_roadinfo import MlitRoadinfoParser
from crawler.sources.mlit_ktr_road import MlitKtrRoadParser
from crawler.sources.mlit_youtube import MlitYoutubeParser
from crawler.sources.muni_youtube import MuniYoutubeParser
from crawler.sources.tokyo_suibo import TokyoSuiboParser
from crawler.sources.youtube_live import YoutubeLiveParser

REGISTRY = {
    p.source_id: p
    for p in [
        CuratedYoutubeParser,
        MlitCbrRoadParser,
        MlitHrrRoadParser,
        MlitKtrRiverParser,
        MlitKtrRoadParser,
        MlitRoadinfoParser,
        MlitYoutubeParser,
        MuniYoutubeParser,
        TokyoSuiboParser,
        YoutubeLiveParser,
    ]
}
