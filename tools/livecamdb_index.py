"""ライブカメラDB(livecam.asia)を「一次ソースへの索引」として読み、当方に無いカメラの候補を抽出する。

- robots.txt は /wp-admin/ のみ禁止(2026-08-28確認)。取得は1.5秒間隔・キャッシュ付き
- 取り出すのは 名称/所在地/YouTube ID/地図座標/公式サイト外部リンク のみ(記事本文は保存しない)
- 採用は従来どおり一次ソースの確認と review_cli 経由。ここでは候補一覧(JSON)を作るだけ
使い方:
  python -m tools.livecamdb_index sitemap            # 詳細ページURL一覧を取得
  python -m tools.livecamdb_index fetch --limit 200  # 詳細ページを取得・抽出(再実行で続きから)
  python -m tools.livecamdb_index report             # 当方台帳との突合サマリ
"""
from __future__ import annotations
import base64, json, os, re, sys, time
from pathlib import Path
import requests

CACHE = Path(os.environ.get("LIVECAMDB_CACHE", "/private/tmp/claude-501/-Users-t-fujiwara-Dropbox-Sanclead------git--------------/7bb162be-a17a-450f-89d2-1e9b7ed45b55/scratchpad/livecamdb"))
UA = {"User-Agent": "Mozilla/5.0 (LiveCamJP-Index/1.0; +https://kotopapa.github.io/livecam-jp/)"}
INTERVAL = 1.0
YT_RE = re.compile(r'youtube\.com/embed/([\w-]{11})|youtube\.com/watch\?v=([\w-]{11})|live_stream\?channel=(UC[\w-]{22})')
MAP_RE = re.compile(r'google\.com/maps/embed\?pb=([^"\']+)')
EXT_RE = re.compile(r'href="(https?://[^"]+)"')
SKIP_HOSTS = ("livecam.asia", "x.com", "twitter.com", "facebook.com", "line.me", "google.", "wp.com", "bsky.app", "tiktok.com", "youtube.com/@livecamdb", "zetta-segment", "instagram.com", "apple.com", "gravatar")
PREF_SLUG = {"hokkaido":"01","aomori":"02","iwate":"03","miyagi":"04","akita":"05","yamagata":"06","fukushima":"07","ibaraki":"08","tochigi":"09","gunma":"10","saitama":"11","chiba":"12","tokyo":"13","kanagawa":"14","niigata":"15","toyama":"16","ishikawa":"17","fukui":"18","yamanashi":"19","nagano":"20","gifu":"21","shizuoka":"22","aichi":"23","mie":"24","shiga":"25","kyoto":"26","osaka":"27","hyogo":"28","nara":"29","wakayama":"30","tottori":"31","shimane":"32","okayama":"33","hiroshima":"34","yamaguchi":"35","tokushima":"36","kagawa":"37","ehime":"38","kochi":"39","fukuoka":"40","saga":"41","nagasaki":"42","kumamoto":"43","oita":"44","miyazaki":"45","kagoshima":"46","okinawa":"47"}

def get(url: str) -> str:
    r = requests.get(url, headers=UA, timeout=30); time.sleep(INTERVAL); r.raise_for_status(); return r.text

def cmd_sitemap():
    idx = get("https://livecam.asia/sitemap.xml")
    subs = [u for u in re.findall(r"<loc>([^<]+)</loc>", idx) if "post-sitemap" in u]
    urls = []
    for s in subs:
        urls += re.findall(r"<loc>([^<]+)</loc>", get(s))
    urls = sorted({u for u in urls if u.endswith(".html")})
    (CACHE / "urls.json").write_text(json.dumps(urls, ensure_ascii=False))
    print("post-sitemaps:", len(subs), "detail pages:", len(urls))

def parse(url: str, html: str) -> dict:
    t = re.search(r"<title>(.*?)</title>", html, re.S)
    title = re.sub(r"\s*[|｜-].*$", "", (t.group(1) if t else "").strip())
    yt_v, yt_c = set(), set()
    for m in YT_RE.finditer(html):
        if m.group(3): yt_c.add(m.group(3))
        else: yt_v.add(m.group(1) or m.group(2))
    lat = lng = None
    mm = MAP_RE.search(html)
    if mm:
        pb = mm.group(1)
        z = re.search(r"!2z([A-Za-z0-9_-]+)", pb)  # マーカー実位置(base64のDMS) — CLAUDE.md知見
        d = re.search(r"!2d(-?[\d.]+)!3d(-?[\d.]+)", pb)
        if d: lng, lat = float(d.group(1)), float(d.group(2))
    # 本文の最初の外部リンク群がカメラの一次ソース(静止画の直URL / YouTube / 公式ページ)。
    # シェア用リンク(x.com等)以降は除外
    ext = []
    for l in dict.fromkeys(EXT_RE.findall(html)):
        if "x.com/livecam_db" in l or "bsky.app" in l: break
        if any(h in l for h in SKIP_HOSTS): continue
        ext.append(l)
    # 「ライブカメラ情報」表: 名称/URL/映像先/設置先名称/設置先所在地/配信・管理/配信種類/配信方法/更新間隔/備考 等
    info: dict = {}
    url_rows: list = []
    import html as _html
    for tb in re.findall(r"<table.*?</table>", html, re.S):
        for tr in re.findall(r"<tr.*?</tr>", tb, re.S):
            cells = [re.sub(r"\s+", " ", _html.unescape(re.sub(r"<[^>]+>", " ", c))).strip()
                     for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", tr, re.S)]
            if len(cells) < 2 or not cells[0]:
                continue
            k, v = cells[0], cells[1]
            if k == "URL":
                url_rows = re.findall(r'href="(https?://[^"]+)"', tr)
            elif v and v not in ("–", "-", "－") and k not in info:
                info[k] = v[:200]
    parts = url.replace("https://livecam.asia/", "").split("/")
    pref = PREF_SLUG.get(parts[0], "")
    return {"url": url, "title": title, "pref": pref, "muni_slug": parts[1] if len(parts) > 2 else "", "yt_videos": sorted(yt_v), "yt_channels": sorted(yt_c), "lat": lat, "lng": lng, "ext_links": ext[:6], "src": (url_rows[0] if url_rows else (ext[0] if ext else None)), "urls": url_rows[:4], "info": info}

def cmd_fetch(limit: int):
    urls = json.loads((CACHE / "urls.json").read_text())
    out_p = CACHE / "pages.jsonl"
    done = set()
    if out_p.exists():
        for line in out_p.read_text().splitlines():
            try: done.add(json.loads(line)["url"])
            except Exception: pass
    todo = [u for u in urls if u not in done][:limit]
    with out_p.open("a") as f:
        for i, u in enumerate(todo, 1):
            try: rec = parse(u, get(u))
            except Exception as e: rec = {"url": u, "error": str(e)[:80]}
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            if i % 50 == 0: print(f"{i}/{len(todo)}", flush=True)
    print("fetched:", len(todo), "total:", len(done) + len(todo), "/", len(urls))

def cmd_report():
    repo = Path(__file__).resolve().parent.parent
    cams = json.load(open(repo / "data/cameras.json"))["cameras"]
    vids = {c["feed"]["url"] for c in cams if c["feed"]["type"] == "youtube_video"}
    vids |= {m.group(1) for c in cams for m in [re.search(r"[?&]v=([\w-]{11})", c["feed"]["url"])] if m}
    chans = {c["feed"]["url"] for c in cams if c["feed"]["type"] == "youtube_channel"}
    pages = {c["source"].get("page_url", "") for c in cams}
    recs = [json.loads(l) for l in (CACHE / "pages.jsonl").read_text().splitlines()]
    n = len(recs); yt = [r for r in recs if r.get("yt_videos") or r.get("yt_channels")]
    new_yt = [r for r in yt if not (set(r["yt_videos"]) & vids) and not (set(r["yt_channels"]) & chans)]
    non_yt = [r for r in recs if not r.get("error") and not r.get("yt_videos") and not r.get("yt_channels")]
    non_yt_new = [r for r in non_yt if not any(l in pages for l in r["ext_links"])]
    print(f"解析ページ {n} / YouTube埋め込み {len(yt)} (うち当方未登録 {len(new_yt)}) / 非YouTube {len(non_yt)} (公式リンク先が当方未登録 {len(non_yt_new)}) / 座標あり {sum(1 for r in recs if r.get('lat'))}")
    import collections
    print("県別(未登録YouTube):", collections.Counter(r["pref"] for r in new_yt).most_common(10))
    json.dump({"new_youtube": new_yt, "non_youtube_new": non_yt_new}, open(CACHE / "report.json", "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "sitemap": cmd_sitemap()
    elif cmd == "fetch":
        lim = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else 500
        cmd_fetch(lim)
    else: cmd_report()
