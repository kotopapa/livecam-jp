"""災害情報 X アカウント一覧（data/x_accounts.json）を配信用に絞る。

    site/build.py から呼ばれ site/v1/x_accounts.json を書く。

配信するのは採用済みの `prefectures` / `municipalities` / `national_offices` だけ。
`candidates`（未採用の候補）・`excluded`（除外理由）・`unresolved_prefectures` は
調査用の内部情報なので配信しない。各項目も表示に必要な欄に絞る。
"""
from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / "data" / "x_accounts.json"
OUT = REPO_ROOT / "site" / "v1" / "x_accounts.json"

SECTIONS = ("prefectures", "municipalities", "national_offices")
PUBLIC_FIELDS = ("area_code", "area_codes", "area_name", "handle", "display_name",
                 "operator", "profile", "type", "dedicated", "source")
PROFILE_MAX = 120


def _public_entry(e: dict) -> dict | None:
    if not e.get("handle") or not e.get("display_name"):
        return None
    if e.get("type") not in ("official", "national", "gov_related"):
        # 採用リストに民間・個人が紛れても配信しない（誤認防止）
        return None
    out = {k: e[k] for k in PUBLIC_FIELDS if k in e and e[k] not in (None, "")}
    prof = out.get("profile")
    if isinstance(prof, str):
        prof = " ".join(prof.split())
        if len(prof) > PROFILE_MAX:
            prof = prof[:PROFILE_MAX - 1] + "…"
        out["profile"] = prof
    return out


def public_payload(data: dict) -> dict:
    """配信用の dict を返す。"""
    payload = {"generated": data.get("generated", "")}
    for key in SECTIONS:
        items = []
        for e in data.get(key) or []:
            if isinstance(e, dict):
                pe = _public_entry(e)
                if pe:
                    items.append(pe)
        payload[key] = items
    return payload


def sync_site(src: Path = SRC, out: Path = OUT) -> int:
    """site/v1/x_accounts.json を書き、配信件数を返す。元データが無ければ 0。"""
    if not src.exists():
        return 0
    data = json.loads(src.read_text(encoding="utf-8"))
    payload = public_payload(data)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")
    return sum(len(payload[k]) for k in SECTIONS)
