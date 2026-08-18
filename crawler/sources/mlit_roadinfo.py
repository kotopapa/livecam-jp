"""国交省「道路情報提供システム」(road-info-prvs.mlit.go.jp) パーサ。

道路版のkawabou。全国の直轄道路カメラが整備局コード（81=北海道〜90=沖縄）ごとに
集約されており、`pcImage_<CD>_1.html` の hidden input `kokudoJson` に全カメラの
JSONが埋め込まれている（JS実行不要・1リクエスト/整備局）。

レコード品質: 正確な経緯度（gis_point、[経度, 緯度] 順）、JIS都道府県/市区町村
コード、路線名、地点名、機器状態コード付き。

静止画URLは `img/doro_gazo/pc/<タイムスタンプ>/s_<管理ID>.jpeg` 形式で
**固定URLが存在しない**（約15分刻み・直近3世代のみ保持）。そのため:
- feed.type は `mlit_roadinfo`（都度解決型）。feed.url は解決元の pcImage ページ、
  feed.camera_ref に管理IDを持つ
- monitor が実行のたびに最新URLを解決して status.json の `image_url` で配信する
  （resolve_image_urls() を monitor からも使う）
- 欠測時は no_data.jpeg プレースホルダ（dHashは monitor/freeze.py に登録済み）

対象CD: 81,82,86,87,88,89,90。関東(83)・北陸(84)・中部(85)は事務所サイト直の
既存パーサ（固定URL・こちらの方がアプリに優しい）があるため対象外。
将来重複整理する場合は管理IDの照合が必要。
"""

from __future__ import annotations

import html as html_mod
import json
import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.road-info-prvs.mlit.go.jp/roadinfo/"
PC_IMAGE_URL = BASE + "pc/pcImage_{cd}_1.html"
IMG_BASE = BASE + "img/doro_gazo/pc/"
TERMS_URL = "https://www.mlit.go.jp/link.html"   # 国交省サイト利用規約（推定・要確認）
KOKUDO_JSON_RE = re.compile(r"id=[\"']kokudoJson[\"'][^>]*value='(.*?)'", re.S)

BUREAUS = {
    "81": "北海道開発局",
    "82": "東北地方整備局",
    "86": "近畿地方整備局",
    "87": "中国地方整備局",
    "88": "四国地方整備局",
    "89": "九州地方整備局",
    "90": "沖縄総合事務局",
}


def extract_kokudo_json(page_html: str) -> dict | None:
    """pcImage ページの hidden input からカメラJSONを取り出す。"""
    m = KOKUDO_JSON_RE.search(page_html)
    if not m:
        return None
    try:
        return json.loads(html_mod.unescape(m.group(1)))
    except json.JSONDecodeError:
        return None


def iter_cameras(data: dict):
    """kokudoJson の {路線キー: [{R_xxxx: カメラ}]} 構造を平坦化して yield する。"""
    for route_recs in data.values():
        for rec in route_recs:
            for cam in rec.values():
                if isinstance(cam, dict) and cam.get("doro_gazo_joho_kanri_id"):
                    yield cam


def latest_image(cam: dict) -> tuple[str, str] | None:
    """fileList の最新エントリから (画像URL, 取得時刻) を返す。"""
    files = cam.get("fileList") or []
    entries = [f for f in files if f.get("file")]
    if not entries:
        return None
    latest = max(entries, key=lambda f: f.get("get_datetime") or "")
    return IMG_BASE + latest["file"], latest.get("get_datetime") or ""


def resolve_image_urls(page_html: str) -> dict[str, tuple[str, str]]:
    """pcImage ページから {管理ID: (最新画像URL, 取得時刻)} を返す（monitor用）。"""
    data = extract_kokudo_json(page_html)
    if not data:
        return {}
    out: dict[str, tuple[str, str]] = {}
    for cam in iter_cameras(data):
        img = latest_image(cam)
        if img:
            out[cam["doro_gazo_joho_kanri_id"]] = img
    return out


class MlitRoadinfoParser(SourceParser):
    source_id = "mlit_roadinfo"
    seed_url = BASE + "pc/pcTop_00_0.html"

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        seen: set[str] = set()
        for cd, bureau in BUREAUS.items():
            page_url = PC_IMAGE_URL.format(cd=cd)
            page = session.fetch(page_url)
            if not page.ok:
                result.errors.append(f"CD{cd}: HTTP {page.status} {page.error or ''}")
                continue
            data = extract_kokudo_json(page.text)
            if not data:
                result.errors.append(f"CD{cd}: kokudoJson が見つからない — 構造が変わった可能性")
                continue
            for cam in iter_cameras(data):
                ref = cam["doro_gazo_joho_kanri_id"]
                if ref in seen:
                    continue
                seen.add(ref)
                try:
                    lng = float(cam["gis_point"][0])
                    lat = float(cam["gis_point"][1])
                except (KeyError, IndexError, TypeError, ValueError):
                    lat = lng = None
                name = (cam.get("image_name") or cam.get("kansoku_chiten_mei") or ref).strip()
                notes = ["道路情報提供システム（都度解決型feed）",
                         "規約は国交省サイト利用規約と推定（サイト内に明示リンクなし）。承認前に確認"]
                if cam.get("kiki_jotai_cd") not in (None, 1):
                    notes.append(f"機器状態コード {cam.get('kiki_jotai_cd')}（要確認）")
                result.candidates.append(CameraCandidate(
                    id=f"mlit-roadinfo-{ref.lower()}",
                    name=name,
                    category="road",
                    prefecture=cam.get("todofuken_cd") or "00",
                    feed_type="mlit_roadinfo",
                    feed_url=page_url,
                    camera_ref=ref,
                    operator=f"国土交通省 {bureau}" if cd != "90" else "内閣府 沖縄総合事務局",
                    page_url=page_url,
                    attribution=f"出典：{'国土交通省 ' + bureau if cd != '90' else '内閣府 沖縄総合事務局'}"
                                "（道路情報提供システム）",
                    license="unknown",
                    terms_url=TERMS_URL,
                    municipality=cam.get("cities_cd"),
                    river_or_route=cam.get("teikyo_rosen_mei"),
                    refresh_sec=900,
                    lat=lat, lng=lng,
                    coord_accuracy="exact" if lat is not None else None,
                    address_hint=cam.get("shozaichi"),
                    review_note=" / ".join(notes),
                ))
        if not result.candidates:
            result.errors.append("roadinfo: カメラが1件も取れない")
        return result
