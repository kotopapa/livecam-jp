"""宮城県 河川流域情報システム（MIRAI、dobokusougou.pref.miyagi.jp）の河川カメラ。

静止画は https://www.dobokusougou.pref.miyagi.jp/camera/miyagi/<area{N}_cam{M}>_<YYYYMMDDHHMMSS>.jpg
で、撮影時刻が URL に入る（10分更新。過去の世代は少なくとも 40 分は残る）。
area/cam の番号は台ごとに固定で、撮影時刻は全台共通なので、monitor は 1 台分だけ
最新の URL を問い合わせ、残りは同じ時刻で組み立てる（resolve_stamp / image_url）。
問い合わせはスマホ版ページ自身が出す POST /miyagi_sp/camera と同じ形（Cookie 不要）。
アプリを作り直さずに済むよう feed.type は既存の camidx_latest を使い、
feed.url はスマホ版の個別ページ、feed.camera_ref に "area1_cam2" を入れる
（monitor/main.py がホスト名で見分けて、この解決に回す）。

台帳は固定の表（2026-11-22 調査。県設置 42 台のうち、準備中の江尻橋と、対になる
水位観測局が無く位置を決められない大江川遊水地を除く 40 台）。
座標はカメラ本体ではなく、スマホ版ページで対になっている水位観測局の位置（approx）。
robots.txt は無い（404）。サイト内に転載・リンクの制限記載は無い。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

HOST = "www.dobokusougou.pref.miyagi.jp"
BASE = f"https://{HOST}"
LIST_URL = BASE + "/miyagi_sp/cameraPointList?&kindId=100"
PAGE_URL = BASE + "/miyagi_sp/cameraImage?kindId=100&jiseiId=1&areaId=1&kansokuPointId={id}"
RESOLVE_URL = BASE + "/miyagi_sp/camera"
IMAGE_RE = re.compile(r"/camera/miyagi/(area\d+_cam\d+)_(\d{14})\.jpg")

# (観測点ID, 名称, 河川, 画像の固定部, 緯度, 経度, 対の水位観測局の所在地)
CAMERAS = [
    ("104100001", "佐沼", "迫川", "area1_cam2", 38.68917, 141.19722, "宮城県登米市迫町佐沼字錦（錦橋）"),
    ("104100002", "若柳", "迫川", "area1_cam1", 38.775, 141.12417, "宮城県栗原市若柳字川北堤下"),
    ("104100003", "大河原", "白石川", "area4_cam4", 38.04944, 140.73667, "宮城県柴田郡大河原町字町189（尾形橋下）"),
    ("104100004", "市名坂", "七北田川", "area3_cam3", 38.31639, 140.88722, "宮城県仙台市泉区市名坂石止84-1"),
    ("104100005", "小角", "七北田川", "area3_cam10", 38.32694, 140.81333, "宮城県仙台市泉区実沢字新坂沢3-2"),
    ("104100006", "北目橋", "旧笊川", "area3_cam11", 38.21167, 140.89889, "宮城県仙台市太白区郡山南上河原１地先"),
    ("104100007", "天皇寺橋", "洞堀川", "area2_cam12", 38.43861, 140.88583, "宮城県黒川郡大和町吉岡天皇寺地先"),
    ("104100008", "西荒井", "渋井川", "area2_cam13", 38.55417, 140.94, "宮城県大崎市古川西荒井地内"),
    ("104100009", "赤井", "定川", "area2_cam14", 38.43611, 141.22972, "宮城県東松島市赤井川前3"),
    ("104100010", "高田中央橋", "吉田川", "area2_cam15", 38.43167, 140.88083, "宮城県黒川郡大和町吉田地内"),
    ("104100011", "下狼塚", "多田川", "area2_cam16", 38.57167, 140.88472, "宮城県加美郡加美町平柳城野60"),
    ("104100012", "大水門", "田尻川", "area2_cam17", 38.60056, 141.02028, "宮城県大崎市田尻町中目字下田14-5"),
    ("104100013", "上増田", "増田川", "area3_cam18", 38.16444, 140.8875, "宮城県名取市飯野坂1丁目"),
    ("104100014", "名鰭沼遊水地", "出来川", "area2_cam19", 38.51556, 141.15972, "宮城県遠田郡涌谷町新鰭31"),
    ("104100016", "栗駒公園線", "芋埣川", "area1_cam21", 38.77139, 141.0, "宮城県栗原市栗駒芋埣小山崎"),
    ("104100017", "白石", "白石川", "area4_cam22", 38.01139, 140.62028, "宮城県白石市字半沢屋敷西138"),
    ("104100018", "大林", "迫川", "area1_cam23", 38.78694, 141.08972, "宮城県栗原市若柳大林町裏"),
    ("104100019", "留場", "迫川", "area1_cam24", 38.7425, 141.02278, "宮城県栗原市築館字留場遠ノ木"),
    ("104100020", "大川本町", "大川", "area1_cam25", 38.90056, 141.56472, "宮城県気仙沼市川畑2-16（本町橋）"),
    ("104100021", "新橋", "二迫川", "area1_cam26", 38.80972, 140.94583, "宮城県栗原市鶯沢南郷市下久保44-3"),
    ("104100022", "鹿折大橋", "鹿折川", "area1_cam27", 38.92722, 141.58306, "宮城県気仙沼市西八幡前地先"),
    ("104100023", "小田", "小田川", "area4_cam28", 37.9625, 140.78361, "宮城県角田市角田字住社"),
    ("104100024", "小谷地", "夏川", "area1_cam29", 38.78194, 141.16, "宮城県登米市石越町小谷地"),
    ("104100025", "岩ヶ崎", "三迫川", "area1_cam30", 38.82806, 140.98583, "宮城県栗原市栗駒中野沼尻前"),
    ("104100026", "本関場", "荒川", "area4_cam31", 38.09528, 140.73083, "宮城県柴田郡村田町本関場"),
    ("104100027", "道合", "坂元川", "area4_cam32", 37.92417, 140.89833, "宮城県亘理郡山元町坂元"),
    ("104100028", "品井沼遊水地", "鶴田川", "area2_cam34", 38.44111, 141.06861, "宮城県宮城郡松島町幡谷検行裏"),
    ("104100029", "苦竹", "梅田川", "area3_cam35", 38.27111, 140.92194, "宮城県仙台市宮城野区新田5"),
    ("104100030", "締切沼遊水地", "南沢川", "area1_cam33", 38.61528, 141.31361, "宮城県登米市津山町柳津幣崎"),
    ("104100031", "郡山", "斎川", "area4_cam36", 38.00611, 140.63417, "宮城県白石市郡山字七屋敷8-1"),
    ("104100032", "八幡橋", "砂押川", "area3_cam37", 38.29194, 141.00861, "宮城県多賀城市八幡3-4-7"),
    ("104100033", "大沼", "小山田川", "area1_cam38", 38.64139, 141.09778, "宮城県登米市南方町西郷上字沼崎前"),
    ("104100034", "岩出山", "江合川", "area2_cam39", 38.66111, 140.86694, "宮城県大崎市岩出山上川原"),
    ("104100035", "高城", "高城川", "area2_cam40", 38.38361, 141.06778, "宮城県宮城郡松島町高城字帰命院"),
    ("104100036", "中新田", "鳴瀬川", "area2_cam41", 38.55944, 140.85917, "宮城県加美郡加美町並柳"),
    ("104100037", "矢目", "名蓋川", "area2_cam42", 38.55361, 140.91556, "宮城県大崎市古川矢目"),
    ("104100038", "新明治橋", "真野川", "area2_cam43", 38.45694, 141.3475, "宮城県石巻市大瓜地内"),
    ("104100039", "砂押川遊水地", "砂押川", "area3_cam45", 38.30694, 140.97667, "宮城県多賀城市市川字原谷地"),
    ("104100041", "勿来川遊水地", "勿来川", "area3_cam46", 38.31028, 140.97806, "宮城県多賀城市市川字中谷"),
    ("104100042", "矢野目", "五間堀川", "area4_cam47", 38.12167, 140.9025, "岩沼市下野郷地内"),
]


def resolve_form(point_id: str) -> dict[str, str]:
    """スマホ版ページ（js/cameraImage.js）が最新画像を取るときの POST と同じ値。"""
    return {
        "screenId": "1001", "jiseiId": "1", "kindId": "100", "kansokuDate": "",
        "areaId": "1", "kansokuPointId": point_id, "nextDate": "0", "nextPoint": "0",
        "imgUrl": f"http://{HOST}/camera/", "folderPath": "C:/camera/",
        "latestPath": "miyagi/", "normalpath": "normal/",
        "partsJsp": "/view/parts/partsCameraImage.jsp",
    }


def resolve_stamp(html: str) -> tuple[str, str] | None:
    """POST の応答 → (撮影時刻 YYYYMMDDHHMMSS, ISO8601)。全台共通の時刻。"""
    m = IMAGE_RE.search(html)
    if not m:
        return None
    ts = m.group(2)
    iso = f"{ts[:4]}-{ts[4:6]}-{ts[6:8]}T{ts[8:10]}:{ts[10:12]}:{ts[12:14]}+09:00"
    return ts, iso


def image_url(camera_ref: str, stamp: str) -> str:
    return f"{BASE}/camera/miyagi/{camera_ref}_{stamp}.jpg"


class MiyagiKasenParser(SourceParser):
    source_id = "miyagi_kasen"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        lst = session.fetch(LIST_URL)
        listed = set(re.findall(r"kansokuPointId=(\d+)", lst.text)) if lst.ok else None
        if listed is None:
            result.errors.append(f"miyagi_kasen: 一覧: HTTP {lst.status}")
        elif len(listed) != 42:
            result.errors.append(f"miyagi_kasen: 一覧の台数が {len(listed)}（表は 42 台前提）— 表を見直すこと")
        for pid, name, river, ref, lat, lng, addr in CAMERAS:
            if listed is not None and pid not in listed:
                continue
            page = PAGE_URL.format(id=pid)
            result.candidates.append(CameraCandidate(
                id=f"miyagi-kasen-{pid[-2:]}",
                name=f"{river} {name}",
                category="river",
                prefecture="04",
                feed_type="camidx_latest",
                feed_url=page,
                camera_ref=ref,
                fallback_url=page,
                operator="宮城県",
                page_url=page,
                attribution="出典：宮城県 河川流域情報システム",
                license="unknown",
                refresh_sec=600,
                river_or_route=river,
                lat=lat,
                lng=lng,
                coord_accuracy="approx",
                review_note="宮城県の河川カメラ。画像URLは撮影時刻入り（monitor が解決）。"
                            f"座標は対の水位観測局（{addr}）の位置（概略）。利用条件はレビューで確認",
            ))
        return result
