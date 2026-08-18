"""HBC北海道放送「情報カメラ」パーサ（道内34地点の静止画網）。

一覧: https://www.hbc.co.jp/info-cam/cam_list.html / cam_list2.html（素のリンク集）
地点ページに 720px静止画（media/<name>_720.jpg、JSで自動リロード＝随時更新）と
Googleマップ埋め込みがある。座標は embed URL の !2z（base64のDMS表記、
マーカー実位置）を第一に使う。!2d/!3d はズーム依存の「地図ビューポート中心」で
海上など大きくずれることがあるため、!2z が無いときのフォールバックに留める。
"""

from __future__ import annotations

import base64
import binascii
import re
from urllib.parse import unquote, urljoin

from bs4 import BeautifulSoup

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

BASE = "https://www.hbc.co.jp/info-cam/"
LIST_URLS = (BASE + "cam_list.html", BASE + "cam_list2.html")
IMG_RE = re.compile(r"media/([A-Za-z0-9_-]+)_720\.jpg")
GMAP_RE = re.compile(r"google\.com/maps/embed\?pb=[^\"']*!2d([\d.]+)[^\"']*!3d([\d.]+)")
GMAP_Z_RE = re.compile(r"google\.com/maps/embed\?pb=[^\"']*!2z([A-Za-z0-9+/%=_-]+)")
DMS_RE = re.compile(
    r"(\d+)\xb0(\d+)'([\d.]+)\"([NS])\s+(\d+)\xb0(\d+)'([\d.]+)\"([EW])")
MAX_PAGES = 45


def decode_marker_dms(token: str) -> tuple[float, float] | None:
    """!2z の base64 トークン（例: 43°03'40.3"N 141°21'08.6"E）を (lat, lng) に。"""
    try:
        raw = base64.b64decode(unquote(token) + "==")
        text = raw.decode("utf-8", "replace")
    except (binascii.Error, ValueError):
        return None
    m = DMS_RE.search(text)
    if not m:
        return None
    lat = int(m.group(1)) + int(m.group(2)) / 60 + float(m.group(3)) / 3600
    if m.group(4) == "S":
        lat = -lat
    lng = int(m.group(5)) + int(m.group(6)) / 60 + float(m.group(7)) / 3600
    if m.group(8) == "W":
        lng = -lng
    return (round(lat, 6), round(lng, 6))


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
    if not img:
        return None
    # マーカー実位置（!2z）を優先。無ければビューポート中心（!2d/!3d）
    z = GMAP_Z_RE.search(html)
    if z:
        dms = decode_marker_dms(z.group(1))
        if dms:
            return (img.group(1), dms[0], dms[1])
    gm = GMAP_RE.search(html)
    if gm:
        return (img.group(1), float(gm.group(2)), float(gm.group(1)))
    return (img.group(1), None, None)  # type: ignore[return-value]


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
