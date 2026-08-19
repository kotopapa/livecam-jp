"""市町村運営の道路カメラ統合パーサ（妙高市・郡上市・南小国町・新見市・高森町）。

県サイトを持たない/カバー外の自治体カメラを1ソースで扱う。
- 妙高市: XML台帳（座標・大画像URLつき） export_myoko_clist.xml
- 郡上市: live-camera.html のキャプションで「（郡上市）」の市所有分のみ採用
- 南小国町: /webcam/ の画像直前の見出しテキストが地点名（座標はジオコーディング）
- 新見市・高森町: 各2台の固定URL（座標は手動指定）
"""

from __future__ import annotations

import re

from crawler.sources.base import (CameraCandidate, DiscoverResult, HttpSession,
                                  SourceParser)

MYOKO_XML = "https://www.city.myoko.niigata.jp/live-camera/xml-data/export_myoko_clist.xml"
MYOKO_PAGE = "https://www.city.myoko.niigata.jp/live-camera/"
GUJO_PAGE = "https://www.city.gujo.gifu.jp/pages/live-camera.html"
MINAMIOGUNI_PAGE = "https://www.town.minamioguni.lg.jp/webcam/"

# 固定小規模サイト（実地確認済みの直URL・座標は設置交差点の手動指定）
FIXED_CAMERAS = [
    dict(id="muni-niimi-wl02", name="国道180号 千屋温泉入口", pref="33",
         operator="新見市", lat=35.058, lng=133.470, route="国道180号",
         feed="https://camera.city.niimi.okayama.jp/gazo/wl02/image.jpg",
         page="https://www.city.niimi.okayama.jp/kurashi/kurashi_detail/index/242.html"),
    dict(id="muni-niimi-wl03", name="国道182号 九の坂トンネル", pref="33",
         operator="新見市", lat=34.923, lng=133.555, route="国道182号",
         feed="https://camera.city.niimi.okayama.jp/gazo/wl03/image.jpg",
         page="https://www.city.niimi.okayama.jp/kurashi/kurashi_detail/index/242.html"),
    dict(id="muni-takamori-tateno", name="立野交差点", pref="43",
         operator="高森町", lat=32.884, lng=131.123, route="国道57号",
         feed="https://www.town.kumamoto-takamori.lg.jp/cam_tateno/TRIFORA.jpg",
         page="https://www.town.kumamoto-takamori.lg.jp/page/2017.html"),
    dict(id="muni-takamori-tochinoki", name="栃の木交差点", pref="43",
         operator="高森町", lat=32.828, lng=131.122, route="国道325号",
         feed="https://www.town.kumamoto-takamori.lg.jp/cam_tochinoki/TRIFORA.jpg",
         page="https://www.town.kumamoto-takamori.lg.jp/page/2017.html"),
]

MYOKO_CAM_RE = re.compile(
    r"<title>([^<]+)</title>.*?<cid>(\d+)</cid>.*?<adr>([^<]*)</adr>"
    r".*?<lat>([\d.]+)</lat>.*?<lng>([\d.]+)</lng>.*?<lgimg>([^<]+)</lgimg>",
    re.DOTALL)
GUJO_RE = re.compile(
    r'src="(/application/[^"]*photo280x210[^"]*)"[^>]*>.{0,200}?'
    r'([^<>]{2,30})[（(]郡上市[)）]', re.DOTALL)
# 南小国は2形式混在: ①panel型(ラベルは画像の後の panel__text) ②アンカーテキスト型
OGUNI_PANEL_RE = re.compile(
    r'<a href="([a-z\-]+\.jpg)"[^>]*>\s*<img[^>]*>\s*</a></div>\s*'
    r'<div class="panel__text">(?:<img[^>]*>)?([^<]{2,40})</div>', re.DOTALL)
OGUNI_ANCHOR_RE = re.compile(r'<a href="([a-z\-]+\.jpg)"[^>]*>([^<]{2,40})</a>')


def parse_oguni(html: str) -> list[tuple[str, str]]:
    """(ファイル名, 地点名) のリスト。両形式を統合して重複排除する。"""
    out: dict[str, str] = {}
    for fn, label in OGUNI_PANEL_RE.findall(html):
        out.setdefault(fn, label.strip())
    for fn, label in OGUNI_ANCHOR_RE.findall(html):
        if label.strip():
            out.setdefault(fn, label.strip())
    return list(out.items())


class MuniRoadParser(SourceParser):
    source_id = "muni_road"
    seed_url = MYOKO_XML

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()

        # --- 固定2市町 ---
        for c in FIXED_CAMERAS:
            result.candidates.append(CameraCandidate(
                id=c["id"], name=c["name"], category="road",
                prefecture=c["pref"], feed_type="still_image",
                feed_url=c["feed"], fallback_url=c["page"],
                operator=c["operator"], page_url=c["page"],
                attribution=f"映像提供：{c['operator']}",
                license="unknown", refresh_sec=600,
                lat=c["lat"], lng=c["lng"], coord_accuracy="approx",
                river_or_route=c["route"],
                review_note="市町村運営の道路カメラ。利用条件はレビューで確認"))

        # --- 妙高市（XML・座標つき） ---
        page = session.fetch(MYOKO_XML)
        if page.ok:
            for m in MYOKO_CAM_RE.finditer(page.text):
                title, cid, adr, lat, lng, lgimg = m.groups()
                result.candidates.append(CameraCandidate(
                    id=f"muni-myoko-{cid}", name=title.strip(),
                    category="road", prefecture="15",
                    feed_type="still_image", feed_url=lgimg.strip(),
                    fallback_url=MYOKO_PAGE, operator="妙高市",
                    page_url=MYOKO_PAGE,
                    attribution="映像提供：妙高市（協力: 上越ケーブルビジョン）",
                    license="unknown", refresh_sec=600,
                    lat=float(lat), lng=float(lng), coord_accuracy="exact",
                    review_note="妙高市ライブカメラ。利用条件はレビューで確認"))
        else:
            result.errors.append(f"myoko: HTTP {page.status}")

        # --- 郡上市（市所有分のみ） ---
        page = session.fetch(GUJO_PAGE)
        if page.ok:
            seen = set()
            for m in GUJO_RE.finditer(page.text):
                img, name = m.group(1), m.group(2).strip()
                if img in seen:
                    continue
                seen.add(img)
                cat = "river" if ("川" in name or "橋" in name) else "road"
                slug = re.sub(r"[^a-z0-9]+", "-",
                              img.split("/")[-2] + "-" + img.split("_")[-1].split(".")[0])
                result.candidates.append(CameraCandidate(
                    id=f"muni-gujo-{slug}", name=name, category=cat,
                    prefecture="21", feed_type="still_image",
                    feed_url="https://www.city.gujo.gifu.jp" + img,
                    fallback_url=GUJO_PAGE, operator="郡上市",
                    page_url=GUJO_PAGE, attribution="映像提供：郡上市",
                    license="unknown", refresh_sec=600,
                    address_hint=f"岐阜県郡上市{name[:6]}",
                    review_note="郡上市所有カメラ。利用条件はレビューで確認"))
        else:
            result.errors.append(f"gujo: HTTP {page.status}")

        # --- 南小国町 ---
        page = session.fetch(MINAMIOGUNI_PAGE)
        if page.ok:
            for fn, label in parse_oguni(page.text):
                hint = re.search(r"[（(]([^)）]+)[)）]", label)
                place = hint.group(1) if hint else label[:6]
                place = re.sub(r"^R\d+.*", "", place) or label[:6]
                result.candidates.append(CameraCandidate(
                    id=f"muni-oguni-{fn.replace('.jpg','')}",
                    name=label, category="road", prefecture="43",
                    feed_type="still_image",
                    feed_url=MINAMIOGUNI_PAGE + fn,
                    fallback_url=MINAMIOGUNI_PAGE, operator="南小国町",
                    page_url=MINAMIOGUNI_PAGE,
                    attribution="映像提供：南小国町",
                    license="unknown", refresh_sec=600,
                    address_hint=f"熊本県阿蘇郡南小国町{place}",
                    review_note="南小国町道路情報カメラ。利用条件はレビューで確認"))
        else:
            result.errors.append(f"minamioguni: HTTP {page.status}")

        if not result.candidates:
            result.errors.append("muni_road: カメラが1件も取れない")
        return result
