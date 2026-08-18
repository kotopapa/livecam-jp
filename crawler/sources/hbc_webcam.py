"""HBC北海道放送「情報カメラ」パーサ（道内34地点の静止画網）。

一覧: https://www.hbc.co.jp/info-cam/cam_list.html / cam_list2.html（素のリンク集）
地点ページに 720px静止画（media/<name>_720.jpg、JSで自動リロード＝随時更新）と
Googleマップ埋め込みがあり、embed URLの !2d(経度)!3d(緯度) から座標が取れる。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.hbc.co.jp/info-cam/"
LIST_URLS = (BASE + "cam_list.html", BASE + "cam_list2.html")
IMG_RE = re.compile(r"media/([A-Za-z0-9_-]+)_720\.jpg")
GMAP_RE = re.compile(r"google\.com/maps/embed\?pb=[^\"']*!2d([\d.]+)[^\"']*!3d([\d.]+)")
MAX_PAGES = 45


def extract_point_links(html: str, base_url: str) -> list[tuple[str, str]]:
    soup = BeautifulSoup(html, "html.parser")
    out: dict[str, str] = {}
    for a in soup.find_all("a", href=True):
        href = urljoin(base_url, a["href"])
        if "/info-cam/" not in href or not href.endswith(".html"):
            continue
        if re.search(r"cam_list|index", href):
            continue
        text = a.get_text(strip=True)
        if text and href not in out:
            out[href] = text
    return list(out.items())


def extract_point(html: str) -> tuple[str, float, float] | None:
    """地点ページから (画像名, lat, lng) を返す。座標が無ければ None。"""
    img = IMG_RE.search(html)
    gm = GMAP_RE.search(html)
    if not img:
        return None
    if gm:
        lng, lat = float(gm.group(1)), float(gm.group(2))
    else:
        return (img.group(1), None, None)  # type: ignore[return-value]
    return (img.group(1), lat, lng)


def categorize(name: str) -> str:
    if re.search(r"峠|国道|道路", name):
        return "road"
    if re.search(r"空港", name):
        return "other"
    if re.search(r"港", name):
        return "port"
    return "scenic"


class HbcWebcamParser(SourceParser):
    source_id = "hbc_webcam"
    seed_url = LIST_URLS[0]

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()
        links: list[tuple[str, str]] = []
        for list_url in LIST_URLS:
            page = session.fetch(list_url)
            if not page.ok:
                result.errors.append(f"{list_url}: HTTP {page.status} {page.error or ''}")
                continue
            links += extract_point_links(page.text, list_url)
        if not links:
            result.errors.append("一覧リンクが取れない — ページ構造が変わった可能性")
            return result

        seen: set[str] = set()
        for url, name in links[:MAX_PAGES]:
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                continue
            point = extract_point(page.text)
            if point is None:
                continue
            img_name, lat, lng = point
            slug = re.sub(r"[^a-z0-9]+", "-", img_name.lower()).strip("-")
            if not slug or slug in seen:
                continue
            seen.add(slug)
            result.candidates.append(CameraCandidate(
                id=f"hbc-{slug}",
                name=f"{name}（HBC情報カメラ）",
                category=categorize(name),
                prefecture="01",
                feed_type="still_image",
                feed_url=f"{BASE}media/{img_name}_720.jpg",
                fallback_url=url,
                operator="HBC北海道放送",
                page_url=url,
                attribution="映像提供：HBC北海道放送（情報カメラ）",
                license="unknown",
                refresh_sec=600,
                lat=lat, lng=lng,
                coord_accuracy="exact" if lat is not None else None,
                review_note="HBC情報カメラ。利用条件はレビューで確認",
            ))
        if not result.candidates:
            result.errors.append("hbc: カメラが1件も取れない")
        return result
