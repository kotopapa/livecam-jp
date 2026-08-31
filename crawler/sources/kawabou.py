"""川の防災情報（https://www.river.go.jp/）の非公式・公開JSONファイル群クライアント。

kawabou（Vue SPA）は静的JSONファイルを https://www.river.go.jp/kawabou/file/files/
以下から取得して描画している。ここは国土交通省の公開ウェブコンテンツであり、
公共データ利用規約（第1.0版）系の下で参照できる（有償の水防災オープンデータ
提供サービスとは別物。こちらは通常のWeb公開ファイル）。

主要エンドポイント（2026-08 時点、crawler/tests/fixtures に実レスポンス保存済み）:
- map/pref/prefarea.json                     … 都道府県コード一覧（prefCd: 101〜4701）
- obslist/obs/preflist/<prefCd>.json         … 県内の観測所一覧。obsList.scam / obsList.cctv がカメラ
- master/obs/scam/<scamId>.json              … カメラ詳細。lat/lon・静止画URL（cam.river.go.jp）付き

注意: SPAの内部ファイルなので構造が変わりうる。取得失敗はエラーとして集計し、
週次クロールの取得数チェック（前回比80%未満でCI失敗）で検知する。
"""

from __future__ import annotations

import re
from typing import Any

from crawler.sources.base import CameraCandidate, DiscoverResult, HttpSession

BASE = "https://www.river.go.jp/kawabou/file/files"

KAWABOU_ATTRIBUTION = "出典：国土交通省「川の防災情報」"
KAWABOU_TERMS_URL = "https://www.river.go.jp/kawabou/kwb_apend/html/caution.html"  # 「取り扱い上の注意」(2026-08-31 実確認。旧URLはSPAシェルで規約本文なし)


def pref_jis(pref_cd: int) -> str:
    """kawabou の prefCd（101〜4701）→ JIS X 0401 2桁コード。

    北海道は 101〜105 に分割されているが JIS ではすべて 01。
    """
    return f"{pref_cd // 100:02d}"


def municipality_jis(pref_cd: int, twn_cd: int | None) -> str | None:
    """twnCd（例 1401130 = 川崎市）→ JIS X 0402 5桁（14130）。"""
    if not twn_cd:
        return None
    return f"{pref_cd // 100:02d}{twn_cd % 1000:03d}"


def fetch_pref_codes(session: HttpSession) -> list[int]:
    res = session.fetch(f"{BASE}/map/pref/prefarea.json")
    if not res.ok:
        raise RuntimeError(f"prefarea.json fetch failed: {res.status} {res.error}")
    import json
    data = json.loads(res.text)
    return sorted({p["prefCd"] for p in data["prefs"]})


def fetch_pref_camera_ids(session: HttpSession, pref_cd: int) -> tuple[list[dict[str, Any]], list[str]]:
    """県内のカメラ（scam + cctv）の一覧エントリを返す。"""
    import json
    errors: list[str] = []
    res = session.fetch(f"{BASE}/obslist/obs/preflist/{pref_cd}.json")
    if not res.ok:
        return [], [f"preflist/{pref_cd}: HTTP {res.status} {res.error or ''}"]
    try:
        data = json.loads(res.text)
    except json.JSONDecodeError as e:
        return [], [f"preflist/{pref_cd}: bad JSON ({e})"]
    entries: list[dict[str, Any]] = []
    for twn in data.get("twnInfo", []):
        obs = twn.get("obsList", {})
        for key in ("scam", "cctv"):
            for cam in obs.get(key, []):
                cam = dict(cam)
                cam["_twnCd"] = twn.get("twnCd")
                entries.append(cam)
    return entries, errors


def resolve_scam(session: HttpSession, scam_id: int | str) -> dict[str, Any] | None:
    """master/obs/scam/<scamId>.json から obsInfo を返す。失敗は None。"""
    import json
    res = session.fetch(f"{BASE}/master/obs/scam/{scam_id}.json")
    if not res.ok or b"obsInfo" not in (res.content or b""):
        return None
    try:
        return json.loads(res.text).get("obsInfo")
    except json.JSONDecodeError:
        return None


_SCAM_URL_RE = re.compile(r"river\.go\.jp/kawabou/[^\"'\s]*scamId=(\d+)")


def extract_scam_ids_from_html(html: str) -> list[int]:
    """HTML中の kawabou カメラリンクから scamId を抽出する（重複除去・出現順）。"""
    seen: dict[int, None] = {}
    for m in _SCAM_URL_RE.finditer(html):
        seen.setdefault(int(m.group(1)))
    return list(seen)


def candidate_from_obsinfo(
    obs: dict[str, Any],
    scam_id: int | str,
    *,
    id_prefix: str = "kawabou",
    operator_prefix: str = "国土交通省",
    page_url: str | None = None,
    attribution: str = KAWABOU_ATTRIBUTION,
) -> CameraCandidate | None:
    """kawabou の obsInfo → CameraCandidate。静止画URLが無いものは web_page 扱い。"""
    name = (obs.get("name") or "").strip()
    if not name:
        return None
    pref_cd = obs.get("prefCd")
    if not pref_cd:
        return None

    still = obs.get("currProvUrl") or obs.get("currentUrl")
    live = obs.get("liveUrl")
    kawabou_page = (
        f"https://www.river.go.jp/kawabou/pc/tm?itmkndCd=100&scamId={scam_id}"
        f"&ownCd={obs.get('ownCd', '')}&sysCamId={obs.get('sysCamId', '')}"
    )

    if still:
        feed_type, feed_url = "still_image", still
    elif live and "youtube" not in live:
        feed_type, feed_url = "hls" if ".m3u8" in live else "web_page", live
    else:
        feed_type, feed_url = "web_page", kawabou_page

    own_name = (obs.get("ownName") or "").strip()
    # kawabou には国交省管理以外に都道府県・市町村設置のカメラも載っている。
    # 自治体カメラはライセンス個別確認が必要（SPEC 3.3）なので unknown で手動レビュー行き
    is_municipal = bool(re.search(r"[都道府県市町村]$", own_name))
    if is_municipal:
        operator = own_name
    else:
        operator = f"{operator_prefix} {own_name}".strip() if own_name else operator_prefix

    lat, lon = obs.get("lat"), obs.get("lon")
    notes = []
    if obs.get("pause", 0) != 0:
        notes.append(f"pause={obs.get('pause')}（休止中の可能性）")
    if is_municipal:
        notes.append(f"{own_name}設置カメラ。利用規約の個別確認が必要（SPEC 3.3）")
    return CameraCandidate(
        id=f"{id_prefix}-{scam_id}",
        name=name,
        name_kana=(obs.get("nameKana") or None),
        lat=lat,
        lng=lon,
        coord_accuracy="exact" if (lat and lon) else None,
        category="river",
        prefecture=pref_jis(pref_cd),
        municipality=municipality_jis(pref_cd, obs.get("twnCd")),
        river_or_route=(obs.get("rvrNm") or None),
        feed_type=feed_type,
        feed_url=feed_url,
        refresh_sec=None,
        operator=operator,
        page_url=page_url or kawabou_page,
        fallback_url=kawabou_page,
        terms_url=KAWABOU_TERMS_URL,
        license="unknown" if is_municipal else "public_data_1.0",
        attribution=f"出典：{own_name}／国土交通省「川の防災情報」" if is_municipal else attribution,
        address_hint=(obs.get("addr") or None),
        review_note=" / ".join(notes),
    )


class KawabouPrefParser:
    """川の防災情報の県単位一括パーサ（全国展開用・M5）。

    リクエスト数が多い（県ごとに 1 + カメラ数）ので、対象県は
    seeds.yaml の kawabou_prefs で明示的に指定する。
    """

    source_id = "kawabou_pref"
    seed_url = BASE

    def __init__(self, pref_codes: list[int] | None = None):
        self.pref_codes = pref_codes or []

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for pref_cd in self.pref_codes:
            entries, errs = fetch_pref_camera_ids(session, pref_cd)
            result.errors.extend(errs)
            for entry in entries:
                scam_id = entry.get("scamId")
                if not scam_id:
                    continue
                obs = resolve_scam(session, scam_id)
                if obs is None:
                    result.errors.append(f"scam {scam_id}: master JSON not found")
                    continue
                cand = candidate_from_obsinfo(obs, scam_id)
                if cand:
                    result.candidates.append(cand)
        return result
