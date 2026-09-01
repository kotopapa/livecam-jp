"""防災備蓄チェックリストの推奨商品データ（data/stockpile/products.json）の月次点検。

    python -m tools.stockpile_check                    # URL生存確認 → 死んだ商品を products から除去
    python -m tools.stockpile_check --dry-run          # 判定だけして書き換えない
    python -m tools.stockpile_check --report out.md    # 変化があったら Markdown レポートを書く

商品は廃番・在庫切れ・URL変更が頻繁に起きるため、アプリには埋め込まず配信JSONで差し替える。
このスクリプトは products.json に載っている商品ページURLを月1回叩き、

  alive   : 200 で、商品ページのまま（リダイレクト先が検索・エラーページでない）
  dead    : 404 / 410、またはリダイレクト先が検索ページ・エラーページ（＝商品が消えた）
  unknown : 403 / 429 / 5xx / タイムアウト（モール側のbot対策の可能性。判定を保留して残す）

と分類し、dead の商品だけを `products` 配列から取り除く。**`search`（検索語）は必ず残す**ので、
商品URLが全滅してもアプリはモール検索へ誘導できる。

終了コード: 0=変化なし / 3=変化あり（products.json を書き換えた） / 1=ネットワーク全滅などで判定不能。
アクセスは 1req/s 以下（SPEC C3 / C4 に準拠）。

data/stockpile/ はコミットして site/build.py が site/v1/stockpile/ へコピーする
（site/v1/ は gitignore で publish.yml が毎回作り直すため）。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data" / "stockpile"
PRODUCTS_PATH = DATA_DIR / "products.json"
SITE_DIR = REPO_ROOT / "site" / "v1" / "stockpile"

USER_AGENT = "LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)"
REQUEST_INTERVAL = 1.0  # 1req/s
TIMEOUT = 30

# 「商品が消えた」を示す終了状態。これ以外の非200は unknown（保留）にする
DEAD_STATUS = {404, 410}
# リダイレクト先がこれらに該当したら「商品ページが無くなって検索/トップへ飛ばされた」とみなす
DEAD_PATH_MARKERS = (
    "/search",          # shopping.yahoo.co.jp/search, search.rakuten.co.jp/search/...
    "/s?k=",            # amazon.co.jp/s?k=...
    "/errors/",         # amazon.co.jp/errors/validateCaptcha 以外のエラーページ
    "/error",
    "/notfound",
    "/not_found",
    "/soldout",
    "/sorry",
)
# 除去が多すぎるときに人手の再調査を促す既定のしきい値
DEFAULT_ISSUE_THRESHOLD = 3


# ---------------------------------------------------------------- 純粋関数

def iter_products(doc: dict):
    """(category_key, item_id, product) を順に返す。"""
    for cat in doc.get("categories", []):
        for item in cat.get("items", []):
            for product in item.get("products", []) or []:
                yield cat.get("key", ""), item.get("id", ""), product


def count_products(doc: dict) -> int:
    return sum(1 for _ in iter_products(doc))


def count_items(doc: dict) -> int:
    return sum(len(cat.get("items", [])) for cat in doc.get("categories", []))


def _normalize_path(url: str) -> str:
    p = urlparse(url)
    return (p.path or "/").rstrip("/").lower() + ("?" + p.query.lower() if p.query else "")


def looks_like_search_or_error(url: str) -> bool:
    """URLが検索結果・エラーページに見えるか。"""
    target = _normalize_path(url)
    if target in ("", "/"):
        return True  # トップページへ飛ばされた＝商品ページが無い
    return any(m in target for m in DEAD_PATH_MARKERS)


def classify(status: int | None, final_url: str | None, requested_url: str) -> str:
    """HTTP結果 → 'alive' | 'dead' | 'unknown'。

    status が None（接続失敗・タイムアウト）は unknown。判定できないものは消さない。
    """
    if status is None:
        return "unknown"
    if status in DEAD_STATUS:
        return "dead"
    if status != 200:
        return "unknown"
    if final_url and final_url != requested_url and looks_like_search_or_error(final_url):
        return "dead"
    return "alive"


def apply_removals(doc: dict, dead_urls: set[str]) -> tuple[dict, list[dict]]:
    """dead と判定されたURLの商品を products から取り除いた新しい doc を返す。

    `search`・`cert`・その他の項目フィールドは一切触らない（商品URLが全滅しても
    アプリはモール検索へ誘導できる）。戻り値の2番目は取り除いた商品のリスト。
    """
    removed: list[dict] = []
    out = json.loads(json.dumps(doc))  # deep copy
    for cat in out.get("categories", []):
        for item in cat.get("items", []):
            products = item.get("products")
            if not products:
                continue
            kept = []
            for p in products:
                if p.get("url") in dead_urls:
                    removed.append({"category": cat.get("key", ""), "item": item.get("id", ""),
                                    "name": item.get("name", ""), **p})
                else:
                    kept.append(p)
            if kept:
                item["products"] = kept
            else:
                item.pop("products", None)
    return out, removed


def build_report(removed: list[dict], unknown: list[dict], checked_at: str,
                 alive: int, threshold: int) -> str:
    lines = [f"防災備蓄 推奨商品リンクの月次点検（{checked_at}）", "",
             f"- 生存: {alive}件 / 除去: {len(removed)}件 / 判定保留: {len(unknown)}件", ""]
    if removed:
        lines += ["## products から除去した商品", "",
                  "| カテゴリ | 項目 | ショップ | 商品名 | URL | 結果 |", "|---|---|---|---|---|---|"]
        for r in removed:
            item = r.get("name") or r.get("item", "")
            lines.append(f"| {r.get('category','')} | {item} | {r.get('shop','')} | "
                         f"{r.get('title','')} | {r.get('url','')} | {r.get('result','')} |")
        lines.append("")
        lines.append("`search`（検索語）は残してあるため、アプリはモール検索へ誘導できます。")
        lines.append("")
    if unknown:
        lines += ["## 判定を保留した商品（403/429/5xx・接続失敗。モールのbot対策の可能性）", "",
                  "| ショップ | URL | 結果 |", "|---|---|---|"]
        for u in unknown:
            lines.append(f"| {u.get('shop','')} | {u.get('url','')} | {u.get('result','')} |")
        lines.append("")
    if len(removed) >= threshold:
        lines += ["## 要対応", "",
                  f"除去が {threshold} 件以上あります。`docs/stockpile_products_2026-09-01.md` の"
                  "手順に沿って代替商品を再調査し、`data/stockpile/products.json` を更新してください。", ""]
    return "\n".join(lines) + "\n"


def sync_site(src: Path = DATA_DIR, dst: Path = SITE_DIR) -> int:
    """data/stockpile/ → site/v1/stockpile/ へコピー（site/build.py からも呼ばれる）。

    publish環境には requests が無いので、このモジュールは requests を遅延importしている。
    """
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


# ---------------------------------------------------------------- ネットワーク

def _session():
    import requests  # 遅延import: publish環境(site/build.py→sync_site)には requests が無い

    s = requests.Session()
    s.headers["User-Agent"] = USER_AGENT
    s.headers["Accept-Language"] = "ja,en;q=0.8"
    return s


def probe(session, url: str) -> tuple[int | None, str | None]:
    """HEAD→（405/501/403なら）GET で (status, final_url) を返す。接続失敗は (None, None)。"""
    import requests

    time.sleep(REQUEST_INTERVAL)
    try:
        r = session.head(url, timeout=TIMEOUT, allow_redirects=True)
        if r.status_code in (403, 405, 501) or r.status_code >= 500:
            time.sleep(REQUEST_INTERVAL)
            r = session.get(url, timeout=TIMEOUT, allow_redirects=True, stream=True)
            r.close()
        return r.status_code, r.url
    except requests.RequestException:
        return None, None


def check_all(doc: dict, session=None) -> tuple[list[dict], list[dict], int]:
    """全商品URLを叩いて (dead, unknown, alive件数) を返す。"""
    session = session or _session()
    dead: list[dict] = []
    unknown: list[dict] = []
    alive = 0
    seen: dict[str, str] = {}
    for cat_key, item_id, product in iter_products(doc):
        url = product.get("url", "")
        if not url:
            continue
        if url in seen:
            verdict, status = seen[url], None
        else:
            status, final = probe(session, url)
            verdict = classify(status, final, url)
            seen[url] = verdict
        rec = {"category": cat_key, "item": item_id, "shop": product.get("shop", ""),
               "title": product.get("title", ""), "url": url,
               "result": f"HTTP {status}" if status is not None else "接続失敗"}
        if verdict == "dead":
            dead.append(rec)
        elif verdict == "unknown":
            unknown.append(rec)
        else:
            alive += 1
    return dead, unknown, alive


def _gh_output(**kv) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as f:
        for k, v in kv.items():
            f.write(f"{k}={v}\n")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--products", type=Path, default=PRODUCTS_PATH)
    ap.add_argument("--report", type=Path, default=None, help="変化があったときのMarkdown出力先")
    ap.add_argument("--dry-run", action="store_true", help="判定だけして products.json を書き換えない")
    ap.add_argument("--issue-threshold", type=int, default=DEFAULT_ISSUE_THRESHOLD,
                    help="この件数以上除去したら issue=true を出力する")
    args = ap.parse_args(argv)

    doc = json.loads(args.products.read_text(encoding="utf-8"))
    total = count_products(doc)
    checked_at = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    dead, unknown, alive = check_all(doc)
    print(f"商品URL {total}件: 生存 {alive} / 除去 {len(dead)} / 保留 {len(unknown)}")

    if total and alive == 0 and not dead:
        print("全URLが判定不能でした（ネットワーク障害の可能性）。今回は書き換えません", file=sys.stderr)
        _gh_output(changed="false", issue="false", removed="0", unknown=str(len(unknown)))
        return 1

    changed = bool(dead)
    if changed and not args.dry_run:
        new_doc, removed = apply_removals(doc, {d["url"] for d in dead})
        new_doc["version"] = checked_at
        args.products.write_text(
            json.dumps(new_doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        sync_site()
        for r in removed:
            print(f"  除去: [{r.get('shop','')}] {r.get('title','')} {r.get('url','')}")

    issue = len(dead) >= args.issue_threshold
    _gh_output(changed=str(changed).lower(), issue=str(issue).lower(),
               removed=str(len(dead)), unknown=str(len(unknown)))

    if not (dead or unknown):
        return 0
    report = build_report(dead, unknown, checked_at, alive, args.issue_threshold)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return 3 if changed else 0


if __name__ == "__main__":
    sys.exit(main())
