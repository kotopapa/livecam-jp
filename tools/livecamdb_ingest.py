"""ライブカメラDB索引(reconciled.json)から当方台帳の候補YAMLを作る。

still  : 静止画の直接URLを持つ未登録分。ページを再取得してマーカー実位置(!2z)を取り、
         掲載元ページを解決し、画像応答を確認して curated_still 形式で出力
出典ページは必ず掲載元側(URL欄の公式ページ → 既知ホストの掲載規則 → 画像の親ディレクトリ →
運営者サイト)。livecam.asia を出典にはしない。
"""
from __future__ import annotations
import base64, hashlib, json, re, sys, time
from pathlib import Path
from urllib.parse import urlparse, urljoin
import requests

S = Path("/private/tmp/claude-501/-Users-t-fujiwara-Dropbox-Sanclead------git--------------/7bb162be-a17a-450f-89d2-1e9b7ed45b55/scratchpad/livecamdb")
UA = {"User-Agent": "Mozilla/5.0 (LiveCamJP-Index/1.0; +https://kotopapa.github.io/livecam-jp/)"}
DMS_RE = re.compile(r"(\d+)°(\d+)'([\d.]+)\"([NS])\s+(\d+)°(\d+)'([\d.]+)\"([EW])")

def marker_latlng(html: str):
    m = re.search(r'google\.com/maps/embed\?pb=([^"\']+)', html)
    if not m: return None
    z = re.search(r"!2z([A-Za-z0-9_-]+)", m.group(1))
    if not z: return None
    try:
        raw = z.group(1); txt = base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)).decode("utf-8", "replace")
    except Exception:
        return None
    d = DMS_RE.search(txt)
    if not d: return None
    lat = int(d.group(1)) + int(d.group(2)) / 60 + float(d.group(3)) / 3600
    lng = int(d.group(5)) + int(d.group(6)) / 60 + float(d.group(7)) / 3600
    if d.group(4) == "S": lat = -lat
    if d.group(8) == "W": lng = -lng
    return round(lat, 6), round(lng, 6)

def is_img(u: str) -> bool:
    return any(k in (u or "").lower() for k in (".jpg", ".jpeg", ".png", "snapshotjpeg", "getoneshot", "image.cgi", "oneshotimage"))

def html_ok(u: str) -> bool:
    try:
        r = requests.get(u, headers=UA, timeout=15, stream=True); ct = r.headers.get("Content-Type", ""); r.close()
        return r.status_code == 200 and "text/html" in ct
    except Exception:
        return False

KNOWN_PAGE = {
    "cam.river.go.jp": lambda u: (lambda m: f"https://www.river.go.jp/kawabou/pc/tm?itmkndCd=100&scamId={m.group(1)}" if m else None)(re.search(r"/cam/now/(\d+)\.jpg", u)),
}

def resolve_page(src: str, urls: list[str], operator: str) -> str | None:
    for u in urls[1:]:
        if not is_img(u) and "youtube" not in u: return u
    host = urlparse(src).netloc
    if host in KNOWN_PAGE:
        p = KNOWN_PAGE[host](src)
        if p: return p
    # 画像の親ディレクトリを順に試す
    parts = src.rsplit("/", 1)[0]
    for _ in range(3):
        cand = parts + "/"
        if html_ok(cand): return cand
        if "/" not in parts[8:]: break
        parts = parts.rsplit("/", 1)[0]
    root = f"{urlparse(src).scheme}://{host}/"
    return root if html_ok(root) else None

def category(title: str, operator: str) -> str:
    t = title + operator
    if re.search(r"ダム", t): return "dam"
    if re.search(r"火山|噴火|火口", t): return "volcano"
    if re.search(r"漁港|港", t): return "port"
    if re.search(r"海岸|海水浴|浜|ビーチ|サーフ|海", t): return "coast"
    if re.search(r"国道|県道|道路|号|峠|交差点|IC|インター|バイパス|トンネル|路面|除雪", t): return "road"
    if re.search(r"川|河川|橋|水位|排水|樋|堰|放水路|遊水", t): return "river"
    if re.search(r"山|岳|高原|展望|湖|滝|渓谷|公園|城|神社|寺", t): return "scenic"
    return "other"

PREF_BY_NAME = {"北海道":"01","青森":"02","岩手":"03","宮城":"04","秋田":"05","山形":"06","福島":"07","茨城":"08","栃木":"09","群馬":"10","埼玉":"11","千葉":"12","東京":"13","神奈川":"14","新潟":"15","富山":"16","石川":"17","福井":"18","山梨":"19","長野":"20","岐阜":"21","静岡":"22","愛知":"23","三重":"24","滋賀":"25","京都":"26","大阪":"27","兵庫":"28","奈良":"29","和歌山":"30","鳥取":"31","島根":"32","岡山":"33","広島":"34","山口":"35","徳島":"36","香川":"37","愛媛":"38","高知":"39","福岡":"40","佐賀":"41","長崎":"42","熊本":"43","大分":"44","宮崎":"45","鹿児島":"46","沖縄":"47"}

def pref_from_address(addr: str) -> str:
    for n, c in PREF_BY_NAME.items():
        if addr.startswith(n): return c
    return ""

def clean_name(title: str) -> str:
    t = re.sub(r"\(.*?\)$|（.*?）$", "", title).strip()
    return re.sub(r"ライブカメラ$", "", t).strip() or title

def main(kind: str, limit: int):
    rows = json.load(open(S / "reconciled.json"))
    target = [r for r in rows if not r["dup"] and not r["ng"] and r["kind"] == kind][:limit]
    out_p = S / f"ingest_{kind}.jsonl"
    done = set()
    if out_p.exists():
        for l in out_p.read_text().splitlines():
            try: done.add(json.loads(l)["url"])
            except Exception: pass
    todo = [r for r in target if r["url"] not in done]
    print(f"{kind}: 対象 {len(target)} / 済 {len(done)} / 今回 {len(todo)}", flush=True)
    with out_p.open("a") as f:
        for i, r in enumerate(todo, 1):
            rec = {"url": r["url"], "title": r["title"], "src": r["src"], "operator": r["operator"], "address": r["address"], "pref": r["pref"]}
            try:
                html = requests.get(r["url"], headers=UA, timeout=30).text; time.sleep(1.0)
                if kind == "youtube":
                    vid = r.get("vid") or (lambda m: m.group(1) if m else None)(re.search(r"(?:v=|youtu\.be/|embed/)([\w-]{11})", html))
                    chan = r.get("chan") or (lambda m: m.group(1) if m else None)(re.search(r"youtube\.com/(?:channel/)?(UC[\w-]{22})", html))
                    rec["video_id"], rec["channel_id"] = vid, chan
                    if vid:
                        oe = requests.get("https://www.youtube.com/oembed", params={"url": f"https://www.youtube.com/watch?v={vid}", "format": "json"}, headers=UA, timeout=15)
                        rec["oembed"] = oe.status_code
                        pl = requests.post("https://www.youtube.com/youtubei/v1/player", json={"videoId": vid, "context": {"client": {"clientName": "WEB", "clientVersion": "2.20240101.00.00"}}}, headers={**UA, "Content-Type": "application/json"}, timeout=15)
                        vd = (pl.json().get("videoDetails") or {}) if pl.status_code == 200 else {}
                        rec["is_live"] = bool(vd.get("isLive")); rec["is_live_content"] = bool(vd.get("isLiveContent")); rec["yt_title"] = vd.get("title"); rec["yt_author"] = vd.get("author")
                        time.sleep(0.5)
                ll = marker_latlng(html)
                rec["lat"], rec["lng"] = (ll if ll else (r["lat"], r["lng"]))
                rec["coord_src"] = "marker" if ll else "embed_center"
                urls = re.findall(r'href="(https?://[^"]+)"', html)
                # URL行のリンク群は reconciled に無いので再抽出（先頭の外部リンク群）
                ext = []
                for l in dict.fromkeys(urls):
                    if "x.com/livecam_db" in l or "bsky.app" in l: break
                    if "livecam.asia" in l or any(h in l for h in ("x.com", "facebook", "line.me", "google.", "wp.com", "tiktok", "instagram")): continue
                    ext.append(l)
                if kind == "youtube":
                    # 掲載元: 公式ページ(非YouTube)があればそれ、無ければチャンネルページ
                    official = [u for u in ext if "youtube.com" not in u and "youtu.be" not in u]
                    rec["page_url"] = official[0] if official else (f"https://www.youtube.com/channel/{rec.get('channel_id')}" if rec.get("channel_id") else r["src"])
                    rec["image_ok"] = None
                else:
                    rec["page_url"] = resolve_page(r["src"], ext, r["operator"])
                    ir = requests.get(r["src"], headers=UA, timeout=20, stream=True); ct = ir.headers.get("Content-Type", ""); head = ir.raw.read(8); ir.close()
                    rec["image_ok"] = ir.status_code == 200 and (ct.startswith("image/") or head[:3] == b"\xff\xd8\xff" or head[:4] == b"\x89PNG")
            except Exception as e:
                rec["error"] = str(e)[:100]
            rec["category"] = category(r["title"], r["operator"])
            if not rec["pref"]: rec["pref"] = pref_from_address(r["address"])
            rec["name"] = clean_name(r["title"])
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            if i % 100 == 0: print(f"{i}/{len(todo)}", flush=True)
    print("done", flush=True)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "still", int(sys.argv[2]) if len(sys.argv) > 2 else 100000)
