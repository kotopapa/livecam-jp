"""愛知県「川の防災情報」(kasen-aichi.jp) の河川カメラ パーサ。

入口: https://www.kasen-aichi.jp/CameraList_1.html （地域別に CameraList_<N>.html。N は連番ではない）
  <div class='camera-mini-image-header'>新川（新川下之一色）</div> …
  <a href='CameraImage_1_100001.html'><img src='Images/CameraImage/C0110111.jpg?time=…' />
静止画は Images/CameraImage/<ファイル名>.jpg の固定URL（約10分更新。?time= は付けなくてよい）。
座標は公開されていないので、個別ページ CameraImage_<N>_<ID>.html の「住所」を
address_hint にしてジオコーディングする（approx）。
一覧には国の簡易型カメラ（画像が https://cam.river.go.jp/… のもの）も混ざるが、
それは kawabou 側の持ち物なので拾わない（ENTRY_RE が Images/CameraImage/ だけに一致する）。
robots.txt は /mg/ のみ Disallow。
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.kasen-aichi.jp/"
LIST_URL = BASE + "CameraList_1.html"
LIST_LINK_RE = re.compile(r"CameraList_(\d+)\.html")
ENTRY_RE = re.compile(
    r"camera-mini-image-header'>([^<]+)</div>\s*"
    r"<div class='camera-mini-image-container'>\s*<a href='(CameraImage_\d+_(\d+)\.html)'[^>]*>\s*"
    r"<img src='(Images/CameraImage/[^'?]+)")
ADDRESS_RE = re.compile(r"<th>\s*住所\s*</th>\s*<td>\s*(?:<span>)?\s*([^<]+)", re.S)
RIVER_RE = re.compile(r"^([^（(]+)[（(]")


def parse_list(html: str) -> list[dict]:
    """一覧ページ → [{id, name, page, image}]"""
    out = []
    for name, page, cid, image in ENTRY_RE.findall(html):
        out.append({"id": cid, "name": name.strip(), "page": page, "image": image})
    return out


def parse_address(html: str) -> str | None:
    m = ADDRESS_RE.search(html)
    if not m:
        return None
    addr = m.group(1).strip()
    return addr or None


def address_hint(addr: str) -> str:
    """「…字三角地内」「…地先」などの末尾を落として検索に通りやすくする。"""
    a = re.sub(r"(地内|地先|付近|先)$", "", addr.strip())
    if re.match(r"^[^市町村]{1,4}区", a):     # 「中川区江松２丁目」のように市名が無い住所は名古屋市
        a = "名古屋市" + a
    return a if a.startswith("愛知県") else f"愛知県{a}"


class AichiKasenParser(SourceParser):
    source_id = "aichi_kasen"
    seed_url = LIST_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        first = session.fetch(LIST_URL)
        if not first.ok:
            result.errors.append(f"aichi_kasen: {LIST_URL}: HTTP {first.status}")
            return result
        pages = {"1": first.text}
        for n in sorted(set(LIST_LINK_RE.findall(first.text)), key=int):
            if n in pages:
                continue
            p = session.fetch(f"{BASE}CameraList_{n}.html")
            if p.ok:
                pages[n] = p.text
            else:
                result.errors.append(f"aichi_kasen: CameraList_{n}: HTTP {p.status}")
        seen: set[str] = set()
        for html in pages.values():
            for cam in parse_list(html):
                if cam["id"] in seen:
                    continue
                seen.add(cam["id"])
                detail = session.fetch(BASE + cam["page"])
                addr = parse_address(detail.text) if detail.ok else None
                m = RIVER_RE.match(cam["name"])
                result.candidates.append(CameraCandidate(
                    id=f"aichi-kasen-{cam['id']}",
                    name=cam["name"],
                    category="river",
                    prefecture="23",
                    feed_type="still_image",
                    feed_url=BASE + cam["image"],
                    fallback_url=BASE + cam["page"],
                    operator="愛知県",
                    page_url=BASE + cam["page"],
                    attribution="出典：愛知県 川の防災情報",
                    license="unknown",
                    refresh_sec=600,
                    river_or_route=m.group(1).strip() if m else None,
                    address_hint=address_hint(addr) if addr else None,
                    review_note="愛知県の河川カメラ。座標は住所のジオコーディング（概略）。利用条件はレビューで確認",
                ))
        if not result.candidates:
            result.errors.append("aichi_kasen: カメラが1件も取れない — ページ構造変化の可能性")
        return result
