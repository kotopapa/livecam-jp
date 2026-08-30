"""国土地理院「指定緊急避難場所・指定避難所データ」の月次取り込み。

    python -m tools.shelters              # ダウンロード→data/shelters/ と site/v1/shelters/ を生成
    python -m tools.shelters --force      # Last-Modified が前回と同じでも再生成
    python -m tools.shelters --from-cache DIR   # DIR 内の mergeFromCity_{1,2}.csv を使う（ネット不要）

データ:
  指定緊急避難場所（災害種別フラグ付き）: mergeFromCity_2.csv
  指定避難所:                            mergeFromCity_1.csv
  共通ID = 'E' + 市町村コード5桁 + 連番5桁 + 3桁（先頭 2=緊急避難場所 / 1=避難所）。
  先頭11桁が同一施設のキーになるので、これで突合して s(指定避難所) を立てる。

出力（配信用の短いキー）:
  data/shelters/<JIS2桁>.json   {"version", "pref", "shelters":[{id,n,a,lat,lng,f,s}]}
  data/shelters/index.json      {"version","source_updated","counts","total","notice","attribution"}
  data/shelters_state.json      前回の Last-Modified と件数（変化が無ければダウンロード省略）

data/shelters/ はコミットして site/build.py が site/v1/shelters/ へコピーする
（site/v1/ は gitignore で publish.yml が毎回作り直すため）。

利用条件: 国土地理院コンテンツ利用規約（出典明記で利用可）。注意文は NOTICE を参照。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import logging
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data" / "shelters"
STATE_PATH = REPO_ROOT / "data" / "shelters_state.json"
SITE_DIR = REPO_ROOT / "site" / "v1" / "shelters"

BASE = "https://hinanmap.gsi.go.jp/hinanjocp/defaultFtpData/csv/"
URL_EVAC = BASE + "mergeFromCity_2.csv"   # 指定緊急避難場所
URL_SHELTER = BASE + "mergeFromCity_1.csv"  # 指定避難所
USER_AGENT = "LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)"
REQUEST_INTERVAL = 1.0  # 1req/s

ATTRIBUTION = "出典：国土地理院「指定緊急避難場所データ」"
NOTICE = (
    "本データは国土地理院「指定緊急避難場所データ」を加工したものです。"
    "市町村から提供された情報を掲載しているため、最新の情報でない場合や、"
    "掲載されていない指定緊急避難場所・指定避難所がある場合があります。"
    "正確な情報は当該市町村にご確認ください。"
    "指定緊急避難場所は災害種別ごとに指定されており、災害の種類によっては"
    "避難できない場合があります。データは随時更新されます。"
)

# 災害種別フラグ（f のインデックス）。CSV列名 → インデックス
HAZARD_COLUMNS = [
    ("洪水", 0),
    ("崖崩れ、土石流及び地滑り", 1),  # 土砂
    ("高潮", 2),
    ("地震", 3),
    ("津波", 4),
    ("大規模な火事", 5),
    ("内水氾濫", 6),
    ("火山現象", 7),
]
HAZARD_LABELS = ["洪水", "土砂", "高潮", "地震", "津波", "火事", "内水", "火山"]

PREFECTURES = {
    "北海道": "01", "青森県": "02", "岩手県": "03", "宮城県": "04", "秋田県": "05",
    "山形県": "06", "福島県": "07", "茨城県": "08", "栃木県": "09", "群馬県": "10",
    "埼玉県": "11", "千葉県": "12", "東京都": "13", "神奈川県": "14", "新潟県": "15",
    "富山県": "16", "石川県": "17", "福井県": "18", "山梨県": "19", "長野県": "20",
    "岐阜県": "21", "静岡県": "22", "愛知県": "23", "三重県": "24", "滋賀県": "25",
    "京都府": "26", "大阪府": "27", "兵庫県": "28", "奈良県": "29", "和歌山県": "30",
    "鳥取県": "31", "島根県": "32", "岡山県": "33", "広島県": "34", "山口県": "35",
    "徳島県": "36", "香川県": "37", "愛媛県": "38", "高知県": "39", "福岡県": "40",
    "佐賀県": "41", "長崎県": "42", "熊本県": "43", "大分県": "44", "宮崎県": "45",
    "鹿児島県": "46", "沖縄県": "47",
}
# 長い名前を先に照合する（「神奈川県」「和歌山県」「鹿児島県」は4文字）
_PREF_ORDER = sorted(PREFECTURES, key=len, reverse=True)

log = logging.getLogger("shelters")


def pref_code(muni_name: str, common_id: str = "") -> str | None:
    """「都道府県名及び市町村名」の先頭の都道府県名 → JIS2桁。

    名前で引けない場合は共通IDの市町村コード（2〜3文字目）で補う。
    """
    s = (muni_name or "").strip()
    for name in _PREF_ORDER:
        if s.startswith(name):
            return PREFECTURES[name]
    if common_id and len(common_id) >= 3 and common_id[1:3].isdigit():
        code = common_id[1:3]
        if code in PREFECTURES.values():
            return code
    return None


def _parse_coord(lat_s: str, lng_s: str) -> tuple[float, float] | None:
    try:
        lat = float((lat_s or "").strip())
        lng = float((lng_s or "").strip())
    except ValueError:
        return None
    # 日本の範囲外は不正扱い
    if not (20.0 <= lat <= 46.0 and 122.0 <= lng <= 154.0):
        return None
    return round(lat, 5), round(lng, 5)


def _facility_key(common_id: str) -> str:
    """共通IDの末尾3桁（種別+枝番）を除いた施設キー。"""
    return common_id[:-3] if len(common_id) == 14 else common_id


def convert(evac_rows: list[dict], shelter_rows: list[dict]) -> tuple[dict[str, list[dict]], dict]:
    """CSV行 → 都道府県別レコード。

    戻り値: ({pref: [rec,...]}, stats)
    rec = {id, n, a, lat, lng, f:[hazard idx...], s:1(指定避難所)}
    """
    stats = {"evac": len(evac_rows), "shelter": len(shelter_rows),
             "skipped_coord": 0, "skipped_pref": 0, "shelter_only": 0, "matched": 0}
    shelter_keys = {_facility_key(r.get("共通ID", "")) for r in shelter_rows}
    by_pref: dict[str, list[dict]] = {}
    seen_keys: set[str] = set()

    for r in evac_rows:
        cid = (r.get("共通ID") or "").strip()
        pref = pref_code(r.get("都道府県名及び市町村名", ""), cid)
        if not pref:
            stats["skipped_pref"] += 1
            continue
        coord = _parse_coord(r.get("緯度", ""), r.get("経度", ""))
        if not coord:
            stats["skipped_coord"] += 1
            continue
        key = _facility_key(cid)
        seen_keys.add(key)
        flags = [idx for col, idx in HAZARD_COLUMNS if (r.get(col) or "").strip() == "1"]
        is_shelter = key in shelter_keys or (r.get("指定避難所との住所同一") or "").strip() == "1"
        if key in shelter_keys:
            stats["matched"] += 1
        rec = {"id": cid, "n": (r.get("施設・場所名") or "").strip(),
               "a": (r.get("住所") or "").strip(),
               "lat": coord[0], "lng": coord[1], "f": flags}
        if is_shelter:
            rec["s"] = 1
        by_pref.setdefault(pref, []).append(rec)

    # 指定避難所のみ（緊急避難場所に無い施設）も配信する
    for r in shelter_rows:
        cid = (r.get("共通ID") or "").strip()
        key = _facility_key(cid)
        if key in seen_keys:
            continue
        pref = pref_code(r.get("都道府県名及び市町村名", ""), cid)
        if not pref:
            stats["skipped_pref"] += 1
            continue
        coord = _parse_coord(r.get("緯度", ""), r.get("経度", ""))
        if not coord:
            stats["skipped_coord"] += 1
            continue
        seen_keys.add(key)
        stats["shelter_only"] += 1
        by_pref.setdefault(pref, []).append({
            "id": cid, "n": (r.get("施設・場所名") or "").strip(),
            "a": (r.get("住所") or "").strip(),
            "lat": coord[0], "lng": coord[1], "f": [], "s": 1})
    return by_pref, stats


def read_csv_text(text: str) -> list[dict]:
    return list(csv.DictReader(io.StringIO(text.lstrip("﻿"))))


def write_outputs(by_pref: dict[str, list[dict]], version: str, source_updated: str | None,
                  out_dir: Path = DATA_DIR) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.json"):
        old.unlink()
    counts = {}
    for pref in sorted(by_pref):
        recs = by_pref[pref]
        counts[pref] = len(recs)
        (out_dir / f"{pref}.json").write_text(
            json.dumps({"version": version, "pref": pref, "shelters": recs},
                       ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    index = {
        "version": version,
        "source_updated": source_updated,
        "counts": counts,
        "total": sum(counts.values()),
        "hazards": HAZARD_LABELS,
        "notice": NOTICE,
        "attribution": ATTRIBUTION,
        "source_url": "https://hinanmap.gsi.go.jp/",
    }
    (out_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    return index


def sync_site(src: Path = DATA_DIR, dst: Path = SITE_DIR) -> int:
    """data/shelters/ → site/v1/shelters/ へコピー（site/build.py からも呼ばれる）。"""
    if not src.exists():
        return 0
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in src.glob("*.json"):
        shutil.copy2(p, dst / p.name)
        n += 1
    return n


def _load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except ValueError:
            pass
    return {}


def _session() -> requests.Session:
    import requests  # 遅延import: publish環境(site/build.py→sync_site)には requests が無い

    s = requests.Session()
    s.headers["User-Agent"] = USER_AGENT
    return s


def _head_last_modified(session: requests.Session, url: str) -> str | None:
    resp = session.head(url, timeout=30, allow_redirects=True)
    resp.raise_for_status()
    return resp.headers.get("Last-Modified")


def _download(session: requests.Session, url: str) -> tuple[str, str | None]:
    resp = session.get(url, timeout=300)
    resp.raise_for_status()
    resp.encoding = "utf-8"
    return resp.text, resp.headers.get("Last-Modified")


def _latest(*values: str | None) -> str | None:
    """複数の Last-Modified から新しい方を返す。"""
    best, best_dt = None, None
    for v in values:
        if not v:
            continue
        try:
            dt = datetime.strptime(v, "%a, %d %b %Y %H:%M:%S %Z")
        except ValueError:
            dt = None
        if best is None or (dt and best_dt and dt > best_dt) or (dt and best_dt is None):
            best, best_dt = v, dt
    return best


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--force", action="store_true", help="Last-Modified が同じでも再生成")
    ap.add_argument("--from-cache", metavar="DIR", help="DIR の mergeFromCity_{1,2}.csv を使う")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    state = _load_state()
    if args.from_cache:
        d = Path(args.from_cache)
        evac_text = (d / "mergeFromCity_2.csv").read_text(encoding="utf-8")
        shelter_text = (d / "mergeFromCity_1.csv").read_text(encoding="utf-8")
        source_updated = state.get("source_updated")
    else:
        session = _session()
        lm_evac = _head_last_modified(session, URL_EVAC)
        time.sleep(REQUEST_INTERVAL)
        lm_shelter = _head_last_modified(session, URL_SHELTER)
        source_updated = _latest(lm_evac, lm_shelter)
        prev = state.get("last_modified", {})
        if (not args.force and prev.get("evac") == lm_evac and prev.get("shelter") == lm_shelter
                and (DATA_DIR / "index.json").exists()):
            log.info("CSV は前回(%s)から更新なし。ダウンロードを省略", source_updated)
            sync_site()
            return 0
        time.sleep(REQUEST_INTERVAL)
        evac_text, lm_evac2 = _download(session, URL_EVAC)
        time.sleep(REQUEST_INTERVAL)
        shelter_text, lm_shelter2 = _download(session, URL_SHELTER)
        lm_evac, lm_shelter = lm_evac2 or lm_evac, lm_shelter2 or lm_shelter
        source_updated = _latest(lm_evac, lm_shelter)
        state["last_modified"] = {"evac": lm_evac, "shelter": lm_shelter}

    evac_rows = read_csv_text(evac_text)
    shelter_rows = read_csv_text(shelter_text)
    by_pref, stats = convert(evac_rows, shelter_rows)
    log.info("緊急避難場所 %d行 / 指定避難所 %d行 → 突合 %d, 避難所のみ %d, 座標不正除外 %d, 県不明除外 %d",
             stats["evac"], stats["shelter"], stats["matched"], stats["shelter_only"],
             stats["skipped_coord"], stats["skipped_pref"])

    version = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    index = write_outputs(by_pref, version, source_updated)
    sync_site()

    state.update({"source_updated": source_updated, "version": version,
                  "total": index["total"], "counts": index["counts"], "stats": stats})
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    log.info("生成: %d県 合計 %d件 → %s", len(index["counts"]), index["total"], DATA_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
