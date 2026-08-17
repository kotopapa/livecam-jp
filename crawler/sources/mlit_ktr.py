"""関東地方整備局の河川ライブカメラパーサ。

シード: https://www.ktr.mlit.go.jp/guide/guide00000012.html（リンク集）
→ 1階層下の各事務所ページ（京浜河川事務所など）
→ さらに河川別ページ（多摩川・鶴見川など）に「川の防災情報」への
  カメラリンク（scamId 付きURL）が並ぶ。

2026-08 時点、KTR は静止画を自サイトに置かず kawabou へリンクしている。
そのため本パーサは KTR のページ群から scamId を収集し、kawabou の
master JSON で名前・座標・静止画URLを解決する。
"""

from __future__ import annotations

import re
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from crawler.sources import kawabou
from crawler.sources.base import DiscoverResult, HttpSession, SourceParser

SEED_URL = "https://www.ktr.mlit.go.jp/guide/guide00000012.html"
TERMS_URL = "https://www.ktr.mlit.go.jp/guide/copyright.html"
MAX_PAGES = 60          # 事務所ページ + 河川別ページの取得上限（暴走防止）


class MlitKtrRiverParser(SourceParser):
    source_id = "mlit_ktr_river"
    seed_url = SEED_URL

    def discover(self, session: HttpSession) -> DiscoverResult:
        result = DiscoverResult()

        seed = session.fetch(self.seed_url)
        if not seed.ok:
            result.errors.append(f"seed fetch failed: {seed.status} {seed.error or ''}")
            return result

        # 1) リンク集から ktr.mlit.go.jp 配下の事務所ページを列挙
        office_urls = self._office_links(seed.text)

        # 2) 事務所ページ（と、その中のカメラ系サブページ）から scamId を収集
        scam_ids: dict[int, str] = {}   # scamId -> 発見元ページURL
        visited: set[str] = set()
        queue = list(office_urls)
        while queue and len(visited) < MAX_PAGES:
            url = queue.pop(0)
            if url in visited:
                continue
            visited.add(url)
            page = session.fetch(url)
            if not page.ok:
                result.errors.append(f"{url}: HTTP {page.status} {page.error or ''}")
                continue
            html = page.text
            for sid in kawabou.extract_scam_ids_from_html(html):
                scam_ids.setdefault(sid, url)
            # 同一事務所内のカメラ系サブページを1階層だけ辿る
            if url in office_urls:
                for sub in self._camera_subpages(html, url):
                    if sub not in visited:
                        queue.append(sub)

        if not scam_ids:
            result.errors.append("no scamId links found — KTRのページ構造が変わった可能性")
            return result

        # 3) kawabou master JSON で解決
        for sid, found_on in scam_ids.items():
            obs = kawabou.resolve_scam(session, sid)
            if obs is None:
                result.errors.append(f"scam {sid}: master JSON not found (found on {found_on})")
                continue
            own = (obs.get("ownName") or "").strip()
            cand = kawabou.candidate_from_obsinfo(
                obs, sid,
                id_prefix="mlit-ktr",
                operator_prefix="国土交通省 関東地方整備局",
                page_url=found_on,
                attribution="出典：国土交通省 関東地方整備局"
                            + (f" {own}" if own else "")
                            + "（川の防災情報）",
            )
            if cand:
                # 自治体設置カメラ(license=unknown)の判定を上書きしない。
                # KTRの規約URLは国交省管理カメラにのみ適用する
                if cand.license == "public_data_1.0":
                    cand.terms_url = TERMS_URL
                result.candidates.append(cand)
        return result

    # ---- html helpers -----------------------------------------------

    def _office_links(self, html: str) -> list[str]:
        """リンク集ページの main_content 内リンクのうち、河川・ダム系のものを返す。"""
        soup = BeautifulSoup(html, "html.parser")
        main = soup.find(id="main_content") or soup
        urls: dict[str, None] = {}
        for a in main.find_all("a", href=True):
            href = urljoin(self.seed_url, a["href"])
            if "ktr.mlit.go.jp" not in href:
                continue
            text = a.get_text(strip=True) + " " + (a.find_next("p").get_text(strip=True) if a.find_next("p") else "")
            # 道路カメラは静止画が別系統なのでv1では河川・ダム系に絞る
            if re.search(r"河川|ダム|水位|リアルタイム|霞ヶ浦|渡良瀬", text):
                urls.setdefault(href)
        return list(urls)

    def _camera_subpages(self, html: str, base_url: str) -> list[str]:
        """事務所ページ内の「多摩川」「鶴見川」のような河川別サブページを返す。"""
        soup = BeautifulSoup(html, "html.parser")
        urls: dict[str, None] = {}
        for a in soup.find_all("a", href=True):
            href = urljoin(base_url, a["href"])
            if "ktr.mlit.go.jp" not in href or href == base_url:
                continue
            if not re.search(r"\.html?$", href.split("?")[0]):
                continue
            text = a.get_text(strip=True)
            if re.search(r"川$|ライブ|カメラ|映像", text) and len(text) <= 30:
                urls.setdefault(href)
        return list(urls)
