"""宮崎県「雨量・河川水位観測情報」(kasen.pref.miyazaki.jp) の河川監視カメラ パーサ。

https は接続できない（2026-11 時点でタイムアウト）ので http で取る。robots.txt は無い（404）。
一覧: /bousai/servlet/bousaiweb.servletBousaiContents?style=itv&…（Shift_JIS）
  本文の JS に "key<番号>":"…" の表が 6 つ入っている。
    sitenolist=名称  rnamelist=河川名  addlist=所在地（市町村と地区まで）
    managelist=種別（1 河川 / 3 簡易型河川 / 5 海岸・河口 / 2 砂防）
    actionlist=保守・調整中の印（1/2。画像は「調整中」の札なので拾わない）
静止画は固定URL。番号 300 以上は /cameraData/now/now_NNN.jpg、300 未満は /camera/CamData/NowNNN.jpg
（一覧の makeCameraTable() の記述どおり。河川型は数秒〜1分、簡易型は約5分更新）。
個別ページ: …servletBousaiContents?style=itv_img&dk=15&nw=1&sn=<番号>

座標は公開されていない。県全体の設置図
  /bousai/servlet/bousaiweb.model.servletBousaiSelectMap?model=camera&no=0&mp=0
が <div style="…left:189px;top:392px;" id="camera1" na="名称" rivna="河川名"> の形で
地図画像（itv_ken_000.jpg）上のピクセル位置を持つので、アフィン変換で緯度経度にする。
係数は、名称と河川名が kawabou の水位観測所と一致した 13 台（座標 exact）で 2026-11-22 に
求めた（1px ≒ 330m。1 台を外して当てはめた誤差は中央値 160m、最大 1km）。approx 扱い。
地図画像が差し替わると係数がずれるので、画像ファイル名が変わったら errors に出す。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "http://kasen.pref.miyazaki.jp"
LIST_URL = (BASE + "/bousai/servlet/bousaiweb.servletBousaiContents"
            "?style=itv&dk=15&nw=1&sv=1&xml=0&type=1&kf=1&gf=1&sf=1&ki=1&mp=0&no=0&fn=0")
MAP_URL = BASE + "/bousai/servlet/bousaiweb.model.servletBousaiSelectMap?model=camera&no=0&mp=0"
PAGE_URL = BASE + "/bousai/servlet/bousaiweb.servletBousaiContents?style=itv_img&dk=15&nw=1&sn={n}"
MAP_IMAGE = "itv_ken_000.jpg"

# 設置図のピクセル → 緯度経度（lat = a*x + b*y + c）
LAT_COEF = (-7.62934674e-07, -2.96180275e-03, 32.9076876)
LNG_COEF = (2.95237007e-03, -5.07027923e-06, 130.545410)

TABLE_RE = r"var\s+%s\s*=\s*\{(.*?)\}\s*;"
PAIR_RE = re.compile(r'"key(\d+)"\s*:\s*"([^"]*)"')
MAP_POINT_RE = re.compile(
    r'left:(-?\d+)px;\s*top:(-?\d+)px;?"\s+id="camera\d+"\s+na="([^"]*)"\s+rivna="([^"]*)"')
KIND = {"1": "河川", "3": "簡易型河川", "5": "海岸・河口", "2": "砂防"}


def _norm(s: str) -> str:
    return (s.replace("(", "（").replace(")", "）").replace("　", " ").strip())


def _table(html: str, name: str) -> dict[str, str]:
    m = re.search(TABLE_RE % name, html, re.S)
    return dict(PAIR_RE.findall(m.group(1))) if m else {}


def image_url(n: int) -> str:
    if n >= 300:
        return f"{BASE}/cameraData/now/now_{n:03d}.jpg"
    return f"{BASE}/camera/CamData/Now{n:03d}.jpg"


def parse_list(html: str) -> list[dict]:
    """一覧ページ → [{id, name, river, address, kind, maintenance}]（掲載順）"""
    names, rivers = _table(html, "sitenolist"), _table(html, "rnamelist")
    addrs, kinds = _table(html, "addlist"), _table(html, "managelist")
    actions = _table(html, "actionlist")
    out = []
    for key, name in names.items():
        out.append({
            "id": int(key),
            "name": _norm(name),
            "river": _norm(rivers.get(key, "")) or None,
            "address": _norm(addrs.get(key, "")) or None,
            "kind": KIND.get(kinds.get(key, ""), ""),
            "maintenance": actions.get(key, "") in ("1", "2"),
        })
    return out


def parse_map(html: str) -> dict[tuple[str, str], tuple[int, int]]:
    """設置図 → {(名称, 河川名): (x, y)}"""
    return {(_norm(na), _norm(rv)): (int(x), int(y))
            for x, y, na, rv in MAP_POINT_RE.findall(html)}


def pixel_to_latlng(x: int, y: int) -> tuple[float, float]:
    lat = LAT_COEF[0] * x + LAT_COEF[1] * y + LAT_COEF[2]
    lng = LNG_COEF[0] * x + LNG_COEF[1] * y + LNG_COEF[2]
    return round(lat, 5), round(lng, 5)


class MiyazakiKasenParser(SourceParser):
    source_id = "miyazaki_kasen"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        lst = session.fetch(LIST_URL)
        if not lst.ok:
            result.errors.append(f"miyazaki_kasen: 一覧: HTTP {lst.status}")
            return result
        cams = parse_list(lst.text)
        mp = session.fetch(MAP_URL)
        points: dict[tuple[str, str], tuple[int, int]] = {}
        if mp.ok:
            if MAP_IMAGE in mp.text:
                points = parse_map(mp.text)
            else:
                result.errors.append("miyazaki_kasen: 設置図の画像が変わった — 座標の係数を取り直すこと")
        else:
            result.errors.append(f"miyazaki_kasen: 設置図: HTTP {mp.status}")
        for cam in cams:
            if cam["maintenance"]:
                continue
            xy = points.get((cam["name"], cam["river"] or ""))
            lat, lng = pixel_to_latlng(*xy) if xy else (None, None)
            page = PAGE_URL.format(n=cam["id"])
            addr = cam["address"]
            result.candidates.append(CameraCandidate(
                id=f"miyazaki-kasen-{cam['id']}",
                name=f"{cam['river']} {cam['name']}" if cam["river"] else cam["name"],
                category="river",
                prefecture="45",
                feed_type="still_image",
                feed_url=image_url(cam["id"]),
                fallback_url=page,
                operator="宮崎県",
                page_url=page,
                attribution="出典：宮崎県 雨量・河川水位観測情報",
                license="unknown",
                refresh_sec=300 if cam["id"] >= 300 else 60,
                river_or_route=cam["river"],
                lat=lat,
                lng=lng,
                coord_accuracy="approx" if xy else None,
                address_hint=None if xy else (f"宮崎県{addr.replace(' ', '')}" if addr else None),
                review_note=f"宮崎県の河川監視カメラ（{cam['kind']}）。座標は県の設置図からの換算（概略）。"
                            "利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("miyazaki_kasen: カメラが1件も取れない — ページ構造変化の可能性")
        return result
