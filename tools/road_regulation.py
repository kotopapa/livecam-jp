"""道路の通行規制（災害・気象由来）を配信用 JSON にまとめる。

国土交通省「道路情報提供システム」(https://www.road-info-prvs.mlit.go.jp/roadinfo/) の
「現在の通行規制」を集約する。直轄国道のほか、高速道路会社・都道府県から提供された規制も含まれる。

取得の仕組み（2026-09-21 確認）
- `pc/pcTukokisei_<整備局CD>_1.html` が読み込む `backup/<yyyymmddHHMMSS>/<乱数>/` が5分ごとに
  切り替わるデータディレクトリ。ページ内の script src から正規表現で取る
- `<dir>TukoKisei/<1次メッシュコード>.json` に規制の配列。要素: same_tukokisei_info_id（詳細のキー・
  同じ規制の区間で共通）, kisei_naiyo_cd（規制内容。01=通行止, 04=車線規制, 05=片側交互, 06=チェーン,
  09=移動規制 ほか）, kisei_naiyo_shosai_cd（01+002 は冬期通行止）, genin_jisho_cd（原因事象。05/06/07 は工事）,
  kisei_jishi_jyokyo（1=実施中）, doro_cd, kisei_kaishi_nichiji, iconData.point [lng,lat],
  geo_json（規制区間の LineString）
- 路線名・区間・規制原因の文字列は `pc/pcTukokiseiDetail_<id>.html`（div.detailData ごとに
  路線名/方向/規制開始地点/規制終了地点/規制内容/規制原因/規制開始日時 の表）から取る。
  一度取った詳細は前回の配信ファイルから引き継ぎ、新しい規制の分だけ取得する
- 工事（原因 05/06/07）・冬期通行止・予定（実施状況 1 以外）は対象外。災害・気象・事故等だけを出す
- 利用条件は道路情報提供システムの規約（リンクはトップページへ。カメラと同じ扱い）

配信: data/road_regulation.json → site/v1/road_regulation.json（site/build.py が sync_site で
コピー）。段階（level）や件数が変わったときだけ書く。monitor.yml で30分おきに実行。
level: 2=通行止め / 1=車線規制・片側交互通行など / -1=不明
"""
from __future__ import annotations

import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = REPO_ROOT / "data" / "road_regulation.json"
SITE_PATH = REPO_ROOT / "site" / "v1" / "road_regulation.json"
BASE = "https://www.road-info-prvs.mlit.go.jp/roadinfo/"
UA = {"User-Agent": "livecam-jp road-regulation (+https://kotopapa.github.io/livecam-jp/)"}

SOURCE = {
    "id": "mlit",
    "name": "国土交通省 道路情報提供システム（現在の通行規制）",
    "operator": "国土交通省",
    "url": BASE,
    "attribution": "出典：国土交通省 道路情報提供システム",
}

# 日本の道路がある1次メッシュ（台帳のカメラ座標から生成。137個）
MESHES = (
    "3622 3623 3624 3725 3926 3927 3928 3942 4027 4028 4042 4128 4229 4329 4429 4530 4629 4630 4631 4729 "
    "4730 4731 4828 4829 4830 4831 4839 4928 4929 4930 4931 4932 4933 4939 5029 5030 5031 5032 5033 5034 "
    "5035 5036 5039 5129 5130 5131 5132 5133 5134 5135 5136 5137 5138 5139 5229 5231 5232 5233 5234 5235 "
    "5236 5237 5238 5239 5240 5332 5333 5334 5335 5336 5337 5338 5339 5340 5433 5436 5437 5438 5439 5440 "
    "5536 5537 5538 5539 5540 5541 5636 5637 5638 5639 5640 5641 5738 5739 5740 5741 5839 5840 5841 5939 "
    "5940 5941 5942 6039 6040 6041 6140 6141 6240 6241 6243 6339 6340 6341 6342 6343 6439 6440 6441 6442 "
    "6443 6444 6445 6541 6542 6543 6544 6545 6641 6642 6643 6644 6645 6741 6742 6841 6842"
).split()

KOUJI_CAUSES = {"05", "06", "07"}
DATA_DIR_RE = re.compile(r"backup/\d{14}/[A-Za-z0-9]+/")
DETAIL_BLOCK_RE = re.compile(r'<div id="([A-Za-z0-9_]+)" class="detailData">(.*?)(?=<div id="[A-Za-z0-9_]+" class="detailData">|\Z)', re.S)
DETAIL_ROW_RE = re.compile(r'<td class="shosaiTitleCell"[^>]*>([^<]*)</td>\s*<td class="shosaiValueCell"[^>]*>(.*?)</td>', re.S)
TAG_RE = re.compile(r"<[^>]+>")
DETAIL_KIND_RE = re.compile(r'<div class="(?:existButtonWidth|noButtonWidth)">([^<]*)</div>')  # 複数区間なら exist、単独なら no


def data_dir(page_html: str) -> str | None:
    m = DATA_DIR_RE.search(page_html)
    return m.group(0) if m else None


def is_target(item: dict[str, Any]) -> bool:
    """工事・冬期通行止・予定を除き、実施中の災害/気象/事故等の規制だけを対象にする。"""
    if str(item.get("genin_jisho_cd") or "") in KOUJI_CAUSES:
        return False
    naiyo = str(item.get("kisei_naiyo_cd") or "")
    shosai = str(item.get("kisei_naiyo_shosai_cd") or "").lstrip("0") or "0"
    if naiyo == "01" and shosai == "2":
        return False
    if str(item.get("kisei_jishi_jyokyo") or "1") != "1":
        return False
    return True


def level_of(item: dict[str, Any]) -> int:
    return 2 if str(item.get("kisei_naiyo_cd") or "") in ("01", "08") else 1


def simplify(pts: list[list[float]], tol: float = 0.00012) -> list[list[float]]:
    """Douglas-Peucker で折れ線を間引く（tol は度。0.00012≒13m）。配信サイズ対策。"""
    if len(pts) <= 2:
        return pts
    def dist(p, a, b):
        (x, y), (x1, y1), (x2, y2) = p, a, b
        dx, dy = x2 - x1, y2 - y1
        if dx == 0 and dy == 0:
            return ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        return ((x - (x1 + t * dx)) ** 2 + (y - (y1 + t * dy)) ** 2) ** 0.5
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        k, dmax = -1, 0.0
        for m in range(i + 1, j):
            dm = dist(pts[m], pts[i], pts[j])
            if dm > dmax:
                k, dmax = m, dm
        if dmax > tol:
            keep[k] = True
            stack.append((i, k))
            stack.append((k, j))
    return [p for p, k in zip(pts, keep) if k]


def geo_lines(item: dict[str, Any]) -> list[list[list[float]]]:
    raw = item.get("geo_json")
    if not raw:
        return []
    try:
        g = json.loads(raw) if isinstance(raw, str) else raw
        geom = g.get("geometry") or {}
        coords = geom.get("coordinates") or []
        if geom.get("type") == "LineString":
            coords = [coords]
        elif geom.get("type") != "MultiLineString":
            return []
    except (ValueError, AttributeError):
        return []
    out = []
    for line in coords:
        pts = []
        for c in line:
            try:
                pts.append([round(float(c[1]), 6), round(float(c[0]), 6)])
            except (TypeError, ValueError, IndexError):
                continue
        if len(pts) >= 2:
            out.append(simplify(pts))
    return out


def parse_mesh(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """メッシュ JSON の配列 → {規制ID: 点情報}（同じ規制IDの区間は線を束ねる）。"""
    out: dict[str, dict[str, Any]] = {}
    for it in items if isinstance(items, list) else []:
        if not isinstance(it, dict) or not is_target(it):
            continue
        rid = str(it.get("same_tukokisei_info_id") or "")
        if not rid:
            continue
        pt = (it.get("iconData") or {}).get("point") or []
        try:
            lng, lat = float(pt[0]), float(pt[1])
        except (TypeError, ValueError, IndexError):
            lines0 = geo_lines(it)
            if not lines0:
                continue
            lat, lng = lines0[0][0]
        rec = out.setdefault(rid, {"id": rid, "lat": lat, "lng": lng, "level": level_of(it),
                                   "at": str(it.get("kisei_kaishi_nichiji") or "")[:16], "lines": [],
                                   "cause_cd": str(it.get("genin_jisho_cd") or ""),
                                   "content_cd": str(it.get("kisei_naiyo_cd") or "")})
        rec["lines"].extend(geo_lines(it))
        rec["level"] = max(rec["level"], level_of(it))
    return out


def parse_detail(html: str) -> dict[str, dict[str, str]]:
    """詳細 HTML → {規制ID: {kind, route, direction, from, to, content, cause, start, status}}。"""
    import html as _html
    out: dict[str, dict[str, str]] = {}
    for m in DETAIL_BLOCK_RE.finditer(html):
        rid, body = m.group(1), m.group(2)
        rows = {_html.unescape(k).strip(): " ".join(_html.unescape(TAG_RE.sub(" ", v)).split())
                for k, v in DETAIL_ROW_RE.findall(body)}
        kind = DETAIL_KIND_RE.search(body)
        out[rid] = {
            "kind": _html.unescape(kind.group(1)).strip() if kind else "",
            "route": rows.get("路線名", ""),
            "direction": rows.get("方向", ""),
            "from": rows.get("規制開始地点", ""),
            "to": rows.get("規制終了地点", ""),
            "content": rows.get("規制内容", ""),
            "cause": rows.get("規制原因", ""),
            "start": rows.get("規制開始日時", ""),
            "status": rows.get("規制実施状況", ""),
        }
    return out


def make_item(rec: dict[str, Any], detail: dict[str, str] | None) -> dict[str, Any]:
    d = detail or {}
    route = d.get("route") or "道路（路線名未取得）"
    section = d.get("from", "")
    if d.get("to") and d.get("to") not in ("-", d.get("from")):
        section = f"{section}～{d['to']}" if section else d["to"]
    label = d.get("content") or ("通行止め" if rec["level"] >= 2 else "規制")
    if d.get("cause"):
        label = f"{label}（{d['cause']}）"
    return {"id": rec["id"], "name": route, "section": section, "kind": d.get("kind", ""),
            "direction": d.get("direction", ""), "cause": d.get("cause", ""), "content": d.get("content", ""),
            "lat": rec["lat"], "lng": rec["lng"], "level": rec["level"], "label": label,
            "at": d.get("start") or rec.get("at", ""), "lines": rec.get("lines") or []}


def fetch_all(sleep_sec: float = 0.1) -> tuple[dict[str, dict[str, Any]], str] | None:
    import requests

    try:
        page = requests.get(BASE + "pc/pcTukokisei_83_1.html", headers=UA, timeout=30)
        page.raise_for_status()
    except Exception as e:  # noqa: BLE001
        print(f"prvs: ページ取得失敗 {type(e).__name__}: {e}", file=sys.stderr)
        return None
    d = data_dir(page.text)
    if not d:
        print("prvs: データディレクトリが見つからない（構造が変わった可能性）", file=sys.stderr)
        return None
    recs: dict[str, dict[str, Any]] = {}
    failed = 0
    for mesh in MESHES:
        try:
            r = requests.get(f"{BASE}{d}TukoKisei/{mesh}.json", headers=UA, timeout=30)
            if r.status_code == 200:
                for rid, rec in parse_mesh(r.json()).items():
                    if rid in recs:
                        recs[rid]["lines"].extend(rec["lines"])
                        recs[rid]["level"] = max(recs[rid]["level"], rec["level"])
                    else:
                        recs[rid] = rec
            else:
                failed += 1
        except Exception:  # noqa: BLE001
            failed += 1
        time.sleep(sleep_sec)
    if failed > len(MESHES) // 2:
        print(f"prvs: メッシュ取得失敗が多い（{failed}/{len(MESHES)}）", file=sys.stderr)
        return None
    return recs, d


def fetch_details(ids: list[str], sleep_sec: float = 0.2) -> dict[str, dict[str, str]]:
    import requests

    out: dict[str, dict[str, str]] = {}
    for rid in ids:
        try:
            r = requests.get(f"{BASE}pc/pcTukokiseiDetail_{rid}.html", headers=UA, timeout=30)
            if r.status_code == 200:
                # Content-Type に charset が無く requests が ISO-8859-1 と判定するので明示的に UTF-8 で読む
                out.update(parse_detail(r.content.decode("utf-8", "replace")))
        except Exception:  # noqa: BLE001
            pass
        time.sleep(sleep_sec)
    return out


def build(previous: dict[str, Any] | None, recs: dict[str, dict[str, Any]],
          details: dict[str, dict[str, str]], now: datetime) -> dict[str, Any]:
    items = [make_item(rec, details.get(rid)) for rid, rec in recs.items()]
    items.sort(key=lambda x: (-x["level"], x["name"], x["id"]))
    detail_cache = {rid: d for rid, d in details.items() if rid in recs}
    return {"version": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "sources": [SOURCE | {"fetched_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "items": items}],
            "detail_cache": detail_cache}


def signature(doc: dict[str, Any]) -> list[tuple[str, int, str, int]]:
    """規制ID・段階・ラベル・線の点数が変わったときだけ配信を更新する。"""
    return sorted((it["id"], int(it["level"]), it.get("label", ""), sum(len(l) for l in it.get("lines") or []))
                  for s in doc.get("sources", []) for it in s.get("items", []))


def sync_site() -> int:
    if not DATA_PATH.exists():
        return 0
    doc = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    doc.pop("detail_cache", None)  # 配信には要らない
    SITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    SITE_PATH.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    return 1


def main() -> int:
    previous = json.loads(DATA_PATH.read_text(encoding="utf-8")) if DATA_PATH.exists() else None
    fetched = fetch_all()
    if fetched is None:
        print("取得失敗（前回の配信を維持）")
        return 0
    recs, d = fetched
    cache = dict((previous or {}).get("detail_cache") or {})
    missing = [rid for rid in recs if not ((cache.get(rid) or {}).get("route") and (cache.get(rid) or {}).get("kind"))]
    cache.update(fetch_details(missing))
    doc = build(previous, recs, cache, datetime.now(timezone.utc))
    n2 = sum(1 for s in doc["sources"] for it in s["items"] if it["level"] >= 2)
    n = sum(len(s["items"]) for s in doc["sources"])
    if previous is not None and signature(previous) == signature(doc) and not missing:
        print(f"変化なし（規制 {n}件・通行止め {n2}件）")
        return 0
    DATA_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"road_regulation.json 更新: 規制 {n}件・通行止め {n2}件（{d}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
