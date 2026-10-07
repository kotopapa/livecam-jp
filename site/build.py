"""静的配信ファイルの生成（SPEC 8.1）。

    python site/build.py            # data/ → site/v1/ を生成

生成物:
    site/v1/manifest.json
    site/v1/cameras.json            # 承認済み全件
    site/v1/cameras/<prefCode>.json # 都道府県別
    site/v1/status.json
    site/v1/shelters/*.json         # 避難所（data/shelters/ のコピー。tools/shelters.py が月次生成）
    site/v1/facilities/*.json       # 防災拠点（data/facilities/ のコピー。tools/facilities.py が月次生成）
    site/v1/stockpile/*.json        # 備蓄推奨商品（data/stockpile/ のコピー。tools/stockpile_check.py が月次点検）
    site/v1/x_accounts.json         # 自治体・国の機関の災害情報Xアカウント（data/x_accounts.json の採用分。tools/x_accounts_publish.py）
    site/v1/underpass_status.json   # 地下道の冠水状況（data/underpass_status.json。tools/underpass.py）
    site/v1/road_regulation.json    # 道路の通行規制（data/road_regulation.json。tools/road_regulation.py）

アプリに配るのは approved のみ。verification 等の内部フィールドは落とす。
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA = REPO_ROOT / "data"
OUT = REPO_ROOT / "site" / "v1"

MIN_APP_VERSION = "1.0.0"
# App Store 公開後にURLを設定する（強制アップデートダイアログの誘導先）
STORE_URL = "https://apps.apple.com/jp/app/id6802841521"
# Google Play のアプリページ（Android の強制アップデート・招待・レビュー導線）
PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=jp.livecam.livecam_jp"
INTERNAL_FIELDS = {"review", "first_seen", "last_updated", "verification"}


def _is_empty(v) -> bool:
    """None / "" / {} / [] / False は省く（0 や 0.0 は値なので残す）"""
    return v is None or v is False or (isinstance(v, (str, dict, list)) and len(v) == 0)


def slim_camera(record: dict) -> dict:
    """配信用に台帳の1件を軽量化する（災害時の通信量削減）。アプリが読まない内部項目と、
    既定値と同じ空値を落とす。アプリ側の読み取りは app/lib/models/camera.dart の
    Camera.tryParse（欠けた項目は既定値で補われる）"""
    def clean(v):
        if isinstance(v, dict):
            v = {k: clean(x) for k, x in v.items()}
            return {k: x for k, x in v.items() if not _is_empty(x)}
        return v

    out = {k: v for k, v in record.items() if k not in INTERNAL_FIELDS}
    fb = out.get("fallback")
    if isinstance(fb, dict):
        out["fallback"] = {"url": fb.get("url")}  # type は配信しない
    out = clean(out)
    return {k: v for k, v in out.items() if not _is_empty(v)}


def delivery_version(version: str | None) -> str | None:
    """台帳の配信用版番号。アプリは版番号の一致だけで再取得を判断するので、
    UTC 時刻の日付部分だけにして再取得を1日1回にまとめる。
    URGENT_PUBLISH=1 のときは完全な時刻のまま出す（緊急の即時配信）"""
    if not version or os.environ.get("URGENT_PUBLISH") == "1":
        return version
    return version.split("T", 1)[0]


def build_status_lite(status: dict) -> dict:
    """死活状態の軽量版。state が ok 以外、または画像URL等の動的情報を持つものだけ入れ、
    それ以外は default_state（ok）とみなす"""
    keep = {}
    for k, v in status.get("statuses", {}).items():
        if v.get("state") != "ok" or any(v.get(f) for f in ("image_url", "image_time", "video_id")) \
                or "live" in v:
            keep[k] = v
    return {"generated_at": status.get("generated_at"), "default_state": "ok", "statuses": keep}


NOTICE_UNTIL_RE = re.compile(r"^until:\s*(\d{4}-\d{2}-\d{2})\s*\n", re.I)


def _notice(today: str | None = None) -> str | None:
    """data/notice.txt のお知らせ文。先頭行 `until: YYYY-MM-DD`（JST、その日まで有効）が
    あれば期限を過ぎた配信で自動的に取り下げる（閉じない利用者にも出続けないよう
    2026-10-04 ユーザー要望で7日程度の期限を付ける運用）。publish は monitor が
    30分ごとに起動するので、期限の翌日 0時台には消える"""
    p = DATA / "notice.txt"
    if not p.exists():
        return None
    raw = p.read_text(encoding="utf-8")
    m = NOTICE_UNTIL_RE.match(raw)
    if m:
        raw = raw[m.end():]
        if today is None:
            from datetime import datetime, timedelta, timezone
            today = datetime.now(timezone(timedelta(hours=9))).strftime("%Y-%m-%d")
        if today > m.group(1):
            return None
    t = raw.rstrip()  # 先頭の空行は旧版の重なり回避に使うので残す
    return t or None


def _recommended_apps() -> list[dict]:
    p = DATA / "recommended_apps.json"
    if not p.exists():
        return []
    try:
        return json.loads(p.read_text(encoding="utf-8")).get("apps", [])
    except (ValueError, AttributeError):
        return []


def build() -> int:
    cameras_src = json.loads((DATA / "cameras.json").read_text(encoding="utf-8"))
    approved = [
        slim_camera(rec)
        for rec in cameras_src.get("cameras", [])
        if rec.get("review", {}).get("status") == "approved"
    ]
    version = delivery_version(cameras_src.get("version"))

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "cameras").mkdir(exist_ok=True)

    cameras_out = {"version": version, "cameras": approved}
    (OUT / "cameras.json").write_text(
        json.dumps(cameras_out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    by_pref: dict[str, list] = {}
    for rec in approved:
        by_pref.setdefault(rec["prefecture"], []).append(rec)
    for pref, recs in sorted(by_pref.items()):
        (OUT / "cameras" / f"{pref}.json").write_text(
            json.dumps({"version": version, "cameras": recs},
                       ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    status_path = DATA / "status.json"
    if status_path.exists():
        status = json.loads(status_path.read_text(encoding="utf-8"))
    else:
        status = {"generated_at": cameras_src.get("version"), "statuses": {}}
    # 承認済み以外のstatusは配信しない
    ids = {r["id"] for r in approved}
    status["statuses"] = {k: v for k, v in status["statuses"].items() if k in ids}
    (OUT / "status.json").write_text(
        json.dumps(status, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    (OUT / "status_lite.json").write_text(
        json.dumps(build_status_lite(status), ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "cameras": {"version": version, "url": "/v1/cameras.json", "count": len(approved)},
        "status": {"version": status.get("generated_at"), "url": "/v1/status.json"},
        "status_lite": {"version": status.get("generated_at"), "url": "/v1/status_lite.json"},
        "prefectures": sorted(by_pref),
        "min_app_version": MIN_APP_VERSION,
        "store_url": STORE_URL,
        "play_store_url": PLAY_STORE_URL,
        # ルート沿いカメラの経路計算キー（openrouteservice）。publish の Secret ORS_API_KEY。
        # 未設定なら空文字でアプリは機能を出さない
        "route_ors_key": os.environ.get("ORS_API_KEY", ""),
        # data/notice.txt があればアプリ内お知らせバナーとして配信（空なら非表示）。
        # bot の再ビルドでも消えないようファイルで持つ
        "notice": _notice(),
        # 設定画面「開発者の他のアプリ」（data/recommended_apps.json。無ければ空）
        "apps": _recommended_apps(),
    }
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")

    # 全国ランキング（日次集計の成果物があれば上位のみ軽量化して配信）
    ranking_src = DATA / "global_ranking.json"
    if ranking_src.exists():
        state = json.loads(ranking_src.read_text(encoding="utf-8"))
        cams = state.get("cameras", {})
        # 当日分の暫定値を上乗せ（確定処理は翌日の集計で行われる）
        partial = state.get("today_partial", {}).get("counts", {})
        # 直近24時間の近似: 当日分(暫定) + 前日分×(24-経過時間)/24。
        # 集計は3時間おきに回るので当日分がほぼ最新になる
        from datetime import datetime, timedelta, timezone
        jst = timezone(timedelta(hours=9))
        now = datetime.now(jst)
        yesterday = (now - timedelta(days=1)).strftime("%Y%m%d")
        frac = max(0.0, (24 - now.hour - now.minute / 60) / 24)
        entries = []
        for cid in set(cams) | set(partial):
            if cid not in ids:
                continue  # 削除済みカメラはランキングから外す
            rec = cams.get(cid, {})
            extra = partial.get(cid, 0)
            days = rec.get("days", {})
            recent = sum(days.values()) + extra
            day = int(round(extra + days.get(yesterday, 0) * frac))
            entries.append({"id": cid, "recent": recent, "day": day,
                            "total": rec.get("total", 0) + extra})
        top_day = sorted(entries, key=lambda e: -e["day"])[:10]
        top_recent = sorted(entries, key=lambda e: -e["recent"])[:30]
        # 旧バージョンのアプリ向け(累計タブ)に total も残す
        top_total = sorted(entries, key=lambda e: -e["total"])[:30]
        favs = [{"id": cid, "count": n}
                for cid, n in state.get("favorites", {}).items()
                if cid in ids and n > 0]
        favs.sort(key=lambda e: -e["count"])
        (OUT / "ranking.json").write_text(json.dumps({
            "updated": state.get("updated"),
            "recent_days": 7,
            "day": [e for e in top_day if e["day"] > 0],
            "recent": [e for e in top_recent if e["recent"] > 0],
            "total": [e for e in top_total if e["total"] > 0],
            "favorites": favs[:30],
        }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"ranking.json 生成: {len(entries)}台")

    # 避難所データ（data/shelters/ を site/v1/shelters/ へコピー。無ければ何もしない）
    sys.path.insert(0, str(REPO_ROOT))
    from tools.shelters import sync_site
    n_shelters = sync_site()
    if n_shelters:
        print(f"shelters: {n_shelters}ファイルをコピー")

    # 防災拠点データ（給水拠点・備蓄倉庫・消防水利。data/facilities/ を site/v1/facilities/ へ）
    from tools.facilities import sync_site as sync_facilities
    n_facilities = sync_facilities()
    if n_facilities:
        print(f"facilities: {n_facilities}ファイルをコピー")

    # 防災備蓄チェックリストの推奨商品（data/stockpile/ を site/v1/stockpile/ へ）
    from tools.stockpile_check import sync_site as sync_stockpile
    n_stockpile = sync_stockpile()
    if n_stockpile:
        print(f"stockpile: {n_stockpile}ファイルをコピー")

    # 河川カメラの水位観測所（data/water_stations.json。tools/water_stations.py の一度限りの対応付け）
    ws = DATA / "water_stations.json"
    if ws.exists():
        (OUT / "water_stations.json").write_text(
            json.dumps(json.loads(ws.read_text(encoding="utf-8")), ensure_ascii=False,
                       separators=(",", ":")), encoding="utf-8")
        print("water_stations.json: コピー")
    # 地下道（アンダーパス）の冠水状況（data/underpass_status.json。tools/underpass.py が5分おきに更新）
    from tools.underpass import sync_site as sync_underpass
    if sync_underpass():
        print("underpass_status.json: コピー")
    # 道路の通行規制（data/road_regulation.json。tools/road_regulation.py が30分おきに更新）
    from tools.road_regulation import sync_site as sync_road_regulation
    if sync_road_regulation():
        print("road_regulation.json: コピー")

    # 自治体・国の機関の災害情報 X アカウント（data/x_accounts.json の採用分のみ配信）
    from tools.x_accounts_publish import sync_site as sync_x_accounts
    n_x = sync_x_accounts()
    if n_x:
        print(f"x_accounts: {n_x}件")

    n_lp = build_lp_data(approved)
    print(f"lp/data.json: 国内の点 {n_lp}")

    print(f"site/v1 生成: 承認済み {len(approved)}件, 都道府県 {len(by_pref)}")
    return 0


LP_CATS = ["river", "road", "volcano", "dam", "coast", "port", "scenic", "healing", "other"]


def build_lp_data(approved: list[dict]) -> int:
    """公式サイト（site/index.html）のモーション用データ site/lp/data.json。

    国内カメラの位置を 0.02° 格子に丸めて重複を除いた点（カテゴリ付き）と台数の内訳。
    点は [緯度*50-1200, 経度*50-6100, カテゴリ番号] を平らに並べた整数配列（軽量化のため）
    """
    cats = {c: 0 for c in LP_CATS}
    world = live = 0
    seen: set[tuple[int, int, int]] = set()
    for c in approved:
        cat = c.get("category") if c.get("category") in cats else "other"
        cats[cat] += 1
        if (c.get("feed") or {}).get("type") in ("youtube_video", "youtube_channel"):
            live += 1
        if str(c.get("id", "")).startswith("world-"):
            world += 1
            continue
        lat, lng = c.get("lat"), c.get("lng")
        if lat is None or lng is None or not (20 <= lat <= 46.5 and 122 <= lng <= 154):
            continue
        seen.add((round(lat * 50) - 1200, round(lng * 50) - 6100, LP_CATS.index(cat)))
    pts: list[int] = []
    for y, x, k in sorted(seen):
        pts += [y, x, k]
    out = REPO_ROOT / "site" / "lp"
    out.mkdir(parents=True, exist_ok=True)
    (out / "data.json").write_text(
        json.dumps({"total": len(approved), "world": world, "live": live,
                    "cats": cats, "catOrder": LP_CATS, "pts": pts},
                   separators=(",", ":")),
        encoding="utf-8",
    )
    update_lp_numbers(len(approved), cats)
    build_lp_names(approved)
    return len(seen)


LP_PREF_NAMES = (
    "北海道 青森 岩手 宮城 秋田 山形 福島 茨城 栃木 群馬 埼玉 千葉 東京 神奈川 新潟 富山 石川 福井 山梨 長野 "
    "岐阜 静岡 愛知 三重 滋賀 京都 大阪 兵庫 奈良 和歌山 鳥取 島根 岡山 広島 山口 徳島 香川 愛媛 高知 福岡 "
    "佐賀 長崎 熊本 大分 宮崎 鹿児島 沖縄").split()


def build_lp_names(approved: list[dict]) -> None:
    """公式サイトの演出用にカメラ名の一部を site/lp/names.json に書く。

    lens: 0.05° 格子ごとに代表1台 [緯度*100, 経度*100, カテゴリ番号, 名前]（地図に重ねた照準で名前を出す）
    ticker: 放送の字幕風に流すカメラ [名前, 都道府県, カテゴリ番号]（カテゴリと地域が偏らないよう選ぶ）
    名前は台帳の公開情報のみ。画像・URL は含めない
    """
    import hashlib
    dom = [c for c in approved
           if not str(c.get("id", "")).startswith("world-") and c.get("lat") is not None and c.get("name")]
    dom.sort(key=lambda c: c["id"])

    def rank(c: dict) -> tuple:
        live = (c.get("feed") or {}).get("type") in ("youtube_video", "youtube_channel")
        return (0 if live else 1, len(c["name"]), c["id"])

    cells: dict[tuple[int, int], dict] = {}
    for c in dom:
        k = (round(c["lat"] * 20), round(c["lng"] * 20))
        if k not in cells or rank(c) < rank(cells[k]):
            cells[k] = c
    cat_of = lambda c: LP_CATS.index(c["category"]) if c.get("category") in LP_CATS else LP_CATS.index("other")
    lens = [[round(c["lat"] * 100), round(c["lng"] * 100), cat_of(c), c["name"]] for c in cells.values()]

    quota = {"scenic": 34, "river": 26, "road": 18, "coast": 14, "volcano": 10,
             "dam": 10, "port": 10, "healing": 14, "other": 14}
    def h(c: dict) -> str:
        return hashlib.sha1(c["id"].encode()).hexdigest()
    ticker = []
    for cat, n in quota.items():
        pool = [c for c in dom if c.get("category") == cat and 3 <= len(c["name"]) <= 16]
        pool.sort(key=h)
        used_pref: dict[str, int] = {}
        for c in pool:
            pref = str(c.get("prefecture") or "")
            if used_pref.get(pref, 0) >= 2:
                continue
            used_pref[pref] = used_pref.get(pref, 0) + 1
            pi = int(pref) - 1 if pref.isdigit() and 1 <= int(pref) <= 47 else -1
            ticker.append([c["name"], LP_PREF_NAMES[pi] if pi >= 0 else "", cat_of(c)])
            if len([t for t in ticker if t[2] == LP_CATS.index(cat)]) >= n:
                break
    ticker.sort(key=lambda t: hashlib.sha1(t[0].encode()).hexdigest())
    out = REPO_ROOT / "site" / "lp"
    (out / "names.json").write_text(
        json.dumps({"lens": lens, "ticker": ticker}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def update_lp_numbers(total: int, cats: dict[str, int]) -> None:
    """site/index.html に文章として書いた台数（説明文・FAQ・構造化データ・機能カード）を
    台帳の実数に合わせる。「約」付きは百の位で四捨五入、「〜台以上」は百の位で切り捨て。
    画面の演出で数え上がる数字は lp/data.json から読むのでここでは触らない
    """
    def approx(n: int) -> str:
        return f"{int(n / 100 + 0.5) * 100:,}"

    def floor(n: int) -> str:
        return f"{n // 100 * 100:,}"

    num = r"[\d,]+"
    rules = [
        (rf"(約){num}(台のライブカメラ)", approx(total)),                # meta・og・構造化データ
        (rf"(カメラ約){num}(台です)", approx(total)),                    # FAQ
        (rf'(id="heroTotal">約){num}(</b>)', approx(total)),             # 見出し下（JS で上書きされる前の表示）
        (rf'(data-fallback-total="){num}(")', str(total)),             # data.json が読めないときの控え
        (rf"(河川カメラは約){num}(台)", approx(cats["river"])),              # 機能カード
        (rf"(約){num}(台の河川カメラ)", approx(cats["river"])),            # 構造化データの FAQ
        (rf'(id="riverN">){num}(</b>台以上)', floor(cats["river"])),    # 大雨の場面
        (rf"(道路カメラは約){num}(台)", approx(cats["road"])),               # 機能カード
    ]
    path = REPO_ROOT / "site" / "index.html"
    html = path.read_text(encoding="utf-8")
    new = html
    for pat, val in rules:
        new, n = re.subn(pat, lambda m, v=val: m.group(1) + v + m.group(2), new)
        if n == 0:
            print(f"警告: site/index.html に台数の書き換え先が見つからない: {pat}", file=sys.stderr)
    if new != html:
        path.write_text(new, encoding="utf-8")
        print("site/index.html: 台数の表記を台帳に合わせて更新")


if __name__ == "__main__":
    sys.exit(build())
