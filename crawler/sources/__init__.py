"""ソース別パーサ。1ファイル1機関。

新しいパーサを追加したら REGISTRY に登録すること。
"""

from crawler.sources.curated_still import CuratedStillParser
from crawler.sources.curated_world import CuratedWorldParser
from crawler.sources.curated_youtube import CuratedYoutubeParser
from crawler.sources.ehime_road import EhimeRoadParser
from crawler.sources.fukui_road import FukuiRoadParser
from crawler.sources.fukushima_road import FukushimaRoadParser
from crawler.sources.gifu_road import GifuRoadParser
from crawler.sources.hiroshima_road import HiroshimaRoadParser
from crawler.sources.ishikawa_road import IshikawaRoadParser
from crawler.sources.iwate_road import IwateRoadParser
from crawler.sources.jma_volcam import JmaVolcamParser
from crawler.sources.hbc_webcam import HbcWebcamParser
from crawler.sources.kaiho_webcam import KaihoWebcamParser
from crawler.sources.kobe_river import KobeRiverParser
from crawler.sources.mbc_webcam import MbcWebcamParser
from crawler.sources.miyagi_road import MiyagiRoadParser
from crawler.sources.mlit_cbr_road import MlitCbrRoadParser
from crawler.sources.mlit_hrr_road import MlitHrrRoadParser
from crawler.sources.mlit_ktr import MlitKtrRiverParser
from crawler.sources.mlit_roadinfo import MlitRoadinfoParser
from crawler.sources.mlit_ktr_road import MlitKtrRoadParser
from crawler.sources.mlit_youtube import MlitYoutubeParser
from crawler.sources.muni_road import MuniRoadParser
from crawler.sources.niigata_road import NiigataRoadParser
from crawler.sources.muni_youtube import MuniYoutubeParser
from crawler.sources.saga_road import SagaRoadParser
from crawler.sources.shimane_road import ShimaneRoadParser
from crawler.sources.tokyo_suibo import TokyoSuiboParser
from crawler.sources.toyama_road import ToyamaRoadParser
from crawler.sources.youtube_live import YoutubeLiveParser

REGISTRY = {
    p.source_id: p
    for p in [
        CuratedStillParser,
        CuratedWorldParser,
        CuratedYoutubeParser,
        EhimeRoadParser,
        FukuiRoadParser,
        FukushimaRoadParser,
        GifuRoadParser,
        HiroshimaRoadParser,
        IshikawaRoadParser,
        IwateRoadParser,
        JmaVolcamParser,
        HbcWebcamParser,
        KaihoWebcamParser,
        KobeRiverParser,
        MbcWebcamParser,
        MiyagiRoadParser,
        MlitCbrRoadParser,
        MlitHrrRoadParser,
        MlitKtrRiverParser,
        MlitKtrRoadParser,
        MlitRoadinfoParser,
        MlitYoutubeParser,
        MuniRoadParser,
        NiigataRoadParser,
        MuniYoutubeParser,
        SagaRoadParser,
        ShimaneRoadParser,
        TokyoSuiboParser,
        ToyamaRoadParser,
        YoutubeLiveParser,
    ]
}
