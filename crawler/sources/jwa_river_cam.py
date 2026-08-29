"""JWA製「川の防災情報」テンプレート（都道府県河川カメラ）の共通パーサ。

埼玉県 川の防災情報 (suibo-river.pref.saitama.lg.jp) と
和歌山県 河川／雨量防災情報 (kasensabo01.pref.wakayama.lg.jp) が同じ構造:

- `geojson/<pref>_camera.geojson` … 観測点の座標（properties: code/name/river/type、
  埼玉は kana/office/address も）
- `chitenconfig/CameraList.csv` … 台帳（事務所コード, 事務所名, 観測点番号, 地点名,
  ふりがな, 所在地, 地点種別, カメラID(上流側), 画像名, 使用フラグ, カメラID(下流側),
  画像名, 使用フラグ, …）。UTF-8 BOM（埼玉）/ EUC-JP（和歌山）
- 画像: `hyoujidata/camera/<カメラID>.jpg`（固定URL、320x240、10分更新）
  → feed.type=still_image

上流側・下流側の2カメラを持つ地点は別候補にする（名称に「（上流側）」「（下流側）」）。
geojson と CSV は (観測点番号, 地点種別) で結合する（和歌山は水位局とダムで同じ
観測点番号を使い回している）。

自治体設置カメラのため license=unknown（SPEC 3.3）。人手レビューで採用判断する。

重複の扱い:
- 承認済み台帳(cameras.json)に同じ画像URLがあるもの（和歌山の curated_still 30件）は
  既存IDを尊重してスキップ
- kawabou 経由で採用済みの同県カメラ（feed が cam.river.go.jp）と座標150m以内かつ
  名称が似ているものは note に「kawabou重複候補: <id>」を付けて残す（除外しない）
- さいたま市 saitama_flood のカメラと150m以内かつ名称類似のものはスキップ
  （同一カメラの可能性が高い。実測では該当なし）

seeds.yaml で `sites:` に県キー（SITES のキー）または設定dictを列挙すると対象県を
選べる。--source 実行時は SITES 全県を対象にする。
"""

from __future__ import annotations

import csv
import io
import json
import math
import re
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
CAMERAS_PATH = REPO_ROOT / "data" / "cameras.json"

# 県ごとの設定。seeds.yaml の sites: で上書き・追加できる
SITES: dict[str, dict[str, Any]] = {
    "saitama": {
        "base_url": "https://suibo-river.pref.saitama.lg.jp/",
        "geojson_path": "geojson/saitama_camera.geojson",
        "prefecture": "11",
        "operator": "埼玉県",
        "system_name": "埼玉県 川の防災情報",
        "terms_url": "https://suibo-river.pref.saitama.lg.jp/Templates/top_chuuijikou.pdf",
        # kawabou 経由で採用済みの同県カメラを重複候補として照合する operator 文字列
        "kawabou_operator": "埼玉県",
    },
    "wakayama": {
        "base_url": "https://kasensabo01.pref.wakayama.lg.jp/",
        "geojson_path": "geojson/wakayama_camera.geojson",
        "prefecture": "30",
        "operator": "和歌山県",
        "system_name": "和歌山県 河川／雨量防災情報",
        "terms_url": "https://kasensabo01.pref.wakayama.lg.jp/Templates/top_chuuijikou.pdf",
        "kawabou_operator": "和歌山県",
    },
}

CSV_PATH = "chitenconfig/CameraList.csv"
IMAGE_PATH = "hyoujidata/camera/{cam_id}.jpg"
DUP_DISTANCE_M = 150
CATEGORY_BY_TYPE = {"0": "river", "1": "river", "2": "dam", "3": "river"}

_PAREN_RE = re.compile(r"[（(]([^（()）]*)[）)]\s*$")
_WS_RE = re.compile(r"[\s　]+")


def decode_csv(content: bytes) -> str:
    """UTF-8(BOM付き含む) → EUC-JP → CP932 の順で復号する。"""
    for enc in ("utf-8-sig", "euc-jp", "cp932"):
        try:
            return content.decode(enc)
        except UnicodeDecodeError:
            continue
    return content.decode("utf-8", errors="replace")


def parse_camera_list(text: str) -> list[dict[str, str]]:
    """CameraList.csv を行dictに変換する（列位置固定・ヘッダ行は除外）。"""
    rows: list[dict[str, str]] = []
    for i, r in enumerate(csv.reader(io.StringIO(text))):
        if i == 0 or len(r) < 10:
            continue
        r = [c.strip() for c in r] + [""] * (14 - len(r))
        rows.append({
            "office_code": r[0], "office": r[1], "code": r[2], "name": r[3],
            "kana": r[4], "address": r[5], "type": r[6],
            "up_id": r[7], "up_flag": r[9], "down_id": r[10], "down_flag": r[12],
        })
    return rows


def parse_geojson(text: str) -> dict[tuple[str, str], dict[str, Any]]:
    """geojson を {(code, type): {lat, lng, name, river, kana, address, office}} にする。"""
    data = json.loads(text)
    out: dict[tuple[str, str], dict[str, Any]] = {}
    for ft in data.get("features", []):
        props = ft.get("properties") or {}
        geom = ft.get("geometry") or {}
        coords = geom.get("coordinates") or []
        code = str(props.get("code") or "").strip()
        if not code or len(coords) < 2:
            continue
        try:
            lng, lat = float(coords[0]), float(coords[1])
        except (TypeError, ValueError):
            continue
        out[(code, str(props.get("type") or "").strip())] = {
            "lat": lat, "lng": lng,
            "name": (props.get("name") or "").strip(),
            "river": (props.get("river") or "").strip(),
            "kana": (props.get("kana") or "").strip(),
            "address": (props.get("address") or "").strip(),
            "office": (props.get("office") or "").strip(),
        }
    return out


def split_name(name: str) -> tuple[str, str]:
    """「古東橋(ことうばし)」→ ("古東橋", "ことうばし")。末尾カッコを分離する。"""
    m = _PAREN_RE.search(name)
    if not m:
        return name.strip(), ""
    return name[:m.start()].strip(), m.group(1).strip()


def split_csv_name(name: str) -> tuple[str, str]:
    """CSVの地点名「橋本川　古東橋　水位観測所」→ (地点名 "古東橋", 河川 "橋本川")。
    埼玉形式「青木水門(芝川・新芝川)」→ ("青木水門", "芝川・新芝川")。"""
    parts = [p for p in _WS_RE.split(name.strip()) if p]
    if len(parts) >= 2:                      # 和歌山形式（全角空白区切り）
        river = parts[0]
        rest = [p for p in parts[1:] if p != "水位観測所"]
        return ("".join(rest) or parts[1]), river
    base, paren = split_name(name)           # 埼玉形式（カッコ内が河川名）
    if paren:
        return base, paren
    return name.strip(), ""


def _distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    dy = (lat1 - lat2) * 111_320
    dx = (lng1 - lng2) * 111_320 * math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot(dx, dy)


def _name_similar(a: str, b: str) -> bool:
    from crawler.normalize import normalize_name   # 循環import回避（normalize→sources）
    na, nb = normalize_name(a), normalize_name(b)
    if not na or not nb:
        return False
    if na in nb or nb in na:
        return True
    return SequenceMatcher(None, na, nb).ratio() >= 0.6


def load_existing_cameras() -> list[dict[str, Any]]:
    if not CAMERAS_PATH.exists():
        return []
    try:
        return json.loads(CAMERAS_PATH.read_text(encoding="utf-8-sig")).get("cameras", [])
    except (OSError, ValueError):
        return []


class JwaRiverCamParser(SourceParser):
    source_id = "jwa_river_cam"
    seed_url = SITES["saitama"]["base_url"]

    def __init__(self, sites: list[str | dict[str, Any]] | None = None,
                 existing: list[dict[str, Any]] | None = None):
        self.sites: list[dict[str, Any]] = []
        for s in (sites or list(SITES)):
            if isinstance(s, str):
                if s not in SITES:
                    raise ValueError(f"jwa_river_cam: 未知の県キー {s}")
                self.sites.append(dict(SITES[s], key=s))
            else:
                key = s.get("key") or s.get("id") or urlparse(s["base_url"]).netloc
                self.sites.append(dict(SITES.get(key, {}), **s, key=key))
        self._existing = existing

    # ---- 既存台帳との照合 ------------------------------------------

    def _existing_index(self, site: dict[str, Any]) -> dict[str, Any]:
        cams = self._existing if self._existing is not None else load_existing_cameras()
        host = urlparse(site["base_url"]).netloc
        by_url: dict[str, str] = {}
        kawabou: list[dict[str, Any]] = []
        flood: list[dict[str, Any]] = []
        for cam in cams:
            url = (cam.get("feed") or {}).get("url") or ""
            if urlparse(url).netloc == host:
                by_url[url] = cam["id"]
            if cam.get("lat") is None or cam.get("lng") is None:
                continue
            if cam.get("prefecture") != site["prefecture"]:
                continue
            if (site.get("kawabou_operator") and "cam.river.go.jp" in url
                    and site["kawabou_operator"] in (cam.get("operator") or "")):
                kawabou.append(cam)
            if cam["id"].startswith("saitama-flood-"):
                flood.append(cam)
        return {"by_url": by_url, "kawabou": kawabou, "flood": flood}

    @staticmethod
    def _near_similar(cams: list[dict[str, Any]], lat: float, lng: float, name: str) -> list[dict[str, Any]]:
        hits = []
        for cam in cams:
            if abs(cam["lat"] - lat) > 0.002 or abs(cam["lng"] - lng) > 0.002:
                continue
            if _distance_m(cam["lat"], cam["lng"], lat, lng) > DUP_DISTANCE_M:
                continue
            if _name_similar(cam["name"], name):
                hits.append(cam)
        return hits

    # ---- discover ---------------------------------------------------

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        for site in self.sites:
            self._discover_site(session, site, result)
        if not result.candidates:
            result.errors.append("jwa_river_cam: カメラが1件も取れない")
        return result

    def _discover_site(self, session: HttpSession, site: dict[str, Any], result: DiscoverResult) -> None:
        key = site["key"]
        base = site["base_url"].rstrip("/") + "/"
        geo_page = session.fetch(base + site["geojson_path"])
        if not geo_page.ok:
            result.errors.append(f"jwa_river_cam/{key}: geojson HTTP {geo_page.status}")
            return
        csv_page = session.fetch(base + CSV_PATH)
        if not csv_page.ok:
            result.errors.append(f"jwa_river_cam/{key}: CameraList.csv HTTP {csv_page.status}")
            return
        try:
            points = parse_geojson(geo_page.text)
        except ValueError:
            result.errors.append(f"jwa_river_cam/{key}: geojsonを解釈できない")
            return
        rows = parse_camera_list(decode_csv(csv_page.content or b""))
        if not rows:
            result.errors.append(f"jwa_river_cam/{key}: CameraList.csvが空")
            return
        by_code: dict[str, list[dict[str, Any]]] = {}
        for (code, _t), pt in points.items():
            by_code.setdefault(code, []).append(pt)

        index = self._existing_index(site)
        seen_ids: set[str] = set()
        skipped_existing = 0
        skipped_flood = 0
        dup_notes = 0

        for row in rows:
            pt = points.get((row["code"], row["type"]))
            if pt is None and len(by_code.get(row["code"], [])) == 1:
                pt = by_code[row["code"]][0]
            if pt and pt["name"]:
                name, kana = split_name(pt["name"])
                river, _ = split_name(pt["river"])
                kana = kana or pt["kana"] or row["kana"]
            else:
                name, river = split_csv_name(row["name"])
                kana = row["kana"]
            if not name:
                continue
            address = (pt or {}).get("address") or row["address"]
            office = (pt or {}).get("office") or row["office"]
            category = CATEGORY_BY_TYPE.get(row["type"], "river")

            cams = []
            if row["up_id"] and row["up_flag"] == "1":
                cams.append((row["up_id"], "上流側"))
            if row["down_id"] and row["down_flag"] == "1":
                cams.append((row["down_id"], "下流側"))
            both = len(cams) == 2

            for cam_id, side in cams:
                if cam_id in seen_ids:
                    continue
                seen_ids.add(cam_id)
                feed_url = base + IMAGE_PATH.format(cam_id=cam_id)
                if feed_url in index["by_url"]:
                    skipped_existing += 1       # 既存ID（curated等）を尊重
                    continue
                full_name = f"{name}（{side}）" if both else name
                note_parts = [f"{site['system_name']}の河川カメラ（{office}）。利用条件はレビューで確認"]
                lat = pt["lat"] if pt else None
                lng = pt["lng"] if pt else None
                if lat is not None and lng is not None:
                    if self._near_similar(index["flood"], lat, lng, name):
                        skipped_flood += 1      # さいたま市 saitama_flood と同一カメラ
                        continue
                    hits = self._near_similar(index["kawabou"], lat, lng, name)
                    for hit in hits:
                        note_parts.append(f"kawabou重複候補: {hit['id']}（{hit['name']}）")
                    dup_notes += 1 if hits else 0
                else:
                    note_parts.append("geojsonに座標なし")
                result.candidates.append(CameraCandidate(
                    id=f"jwa-river-{key}-{cam_id.lower()}",   # スキーマはID小文字
                    name=full_name,
                    name_kana=kana or None,
                    category=category,
                    prefecture=site["prefecture"],
                    river_or_route=river or None,
                    feed_type="still_image",
                    feed_url=feed_url,
                    fallback_url=base,
                    operator=site["operator"],
                    page_url=base,
                    terms_url=site.get("terms_url"),
                    attribution=f"映像提供：{site['operator']}（{site['system_name']}）",
                    license="unknown",
                    refresh_sec=600,
                    lat=lat, lng=lng,
                    coord_accuracy="exact" if lat is not None else None,
                    address_hint=(f"{address}" if address else None),
                    review_note=" / ".join(note_parts),
                ))
        print(f"    [{key}] 候補 {sum(1 for c in result.candidates if c.id.startswith(f'jwa-river-{key}-'))}件, "
              f"既存URLスキップ {skipped_existing}件, saitama_flood同一スキップ {skipped_flood}件, "
              f"kawabou重複候補 {dup_notes}件")
