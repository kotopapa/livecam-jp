"""X アカウントの運営主体を表示名・プロフィール本文から分類する。

    python -m tools.x_account_classify   # セルフテスト

アプリでは種別を必ず併記する（防災アプリで運営主体を誤認させないため）。

  official     自治体公式（都道府県・市区町村の部署が運営）
  gov_related  自治体の外郭・関連施設（防災センター、消防組合など）
  company      民間企業
  organization 団体（防災士会・NPO・大学・学会など）
  individual   個人
  unknown      判断できない（採用しない）
"""
from __future__ import annotations

import re

# 自治体の部署を示す語
DEPT = ("危機管理", "防災課", "防災局", "防災部", "防災安全", "消防防災", "危機対策",
        "災害対策", "防災危機管理", "総務部", "県庁", "市役所", "町役場", "村役場",
        "防災総室", "防災対策課", "復興防災")
# 「公式」を名乗る語
OFFICIAL = ("公式", "オフィシャル")
# 民間企業
COMPANY = ("株式会社", "（株）", "㈱", "有限会社", "合同会社", "支店", "当社", "弊社",
           "Inc.", "Co.,", "Corp")
# 団体
ORG = ("防災士会", "協会", "ＮＰＯ", "NPO", "学会", "部会", "大学", "研究会", "連合会",
       "振興会", "委員会", "ボランティア", "サークル", "同好会")
# 個人を示唆
INDIV = ("個人", "非公式", "非公認", "bot", "ＢＯＴ", "趣味", "私見", "ROM専", "つぶやき",
         "代男", "代女", "です。よろしく")

PREF_SUFFIX = ("都", "道", "府", "県")


def _strip_suffix(name: str) -> str:
    """「神奈川県」→「神奈川」。市区町村はそのまま"""
    if len(name) > 2 and name[-1] in PREF_SUFFIX:
        return name[:-1]
    return name


def classify(display_name: str, desc: str, gov_name: str = "") -> tuple[str, str]:
    """(種別, 判定理由) を返す"""
    blob = f"{display_name} {desc}"
    core = _strip_suffix(gov_name) if gov_name else ""

    # 明示的な否定が最優先（「非公認のアカウントです」等）
    for kw in ("非公認", "非公式"):
        if kw in blob:
            return "individual", f"本文に「{kw}」"

    if any(k in blob for k in COMPANY):
        hit = next(k for k in COMPANY if k in blob)
        return "company", f"本文に「{hit}」"

    if any(k in blob for k in ORG):
        hit = next(k for k in ORG if k in blob)
        return "organization", f"本文に「{hit}」"

    # 県を対象にしているのに本文が「◯◯市/町/村」を指している場合は取り違え
    if core and gov_name and gov_name[-1] in PREF_SUFFIX:
        m = re.search(core + r"(市|町|村|区)", blob)
        if m:
            return "other_area", f"本文は「{core}{m.group(1)}」（対象は{gov_name}）"

    has_dept = any(k in blob for k in DEPT)
    has_official = any(k in blob for k in OFFICIAL)
    name_match = bool(core) and core in blob

    # 自治体公式: 自治体名 + 部署名、または 自治体名 + 「公式」
    if name_match and has_dept:
        return "official", "自治体名＋部署名"
    if name_match and has_official:
        return "official", "自治体名＋「公式」"
    if has_dept and has_official:
        return "official", "部署名＋「公式」"
    # 「◯◯県の…アカウントです」＋防災/災害 の言い回し（例: おおさか防災ネット）
    if name_match and "アカウント" in blob and any(k in blob for k in ("防災", "災害", "避難", "気象")):
        return "official", "自治体名＋「アカウント」＋防災語"

    # 施設系（防災センター・学習センター等）は自治体関連だが災害速報ではない
    if name_match and any(k in blob for k in ("センター", "消防組合", "広域連合", "学習館")):
        return "gov_related", "自治体の施設"

    if any(k in blob for k in INDIV):
        hit = next(k for k in INDIV if k in blob)
        return "individual", f"本文に「{hit}」"

    return "unknown", "判定材料が不足"


LABEL_JA = {
    "official": "自治体公式",
    "gov_related": "自治体関連施設",
    "company": "民間企業",
    "organization": "団体",
    "individual": "個人",
    "other_area": "別自治体（対象違い）",
    "unknown": "不明",
}


def _selftest() -> None:
    cases = [
        ("相模原市災害情報", "相模原市危機管理局危機管理統括部です。", "相模原市", "official"),
        ("茨城県防災・危機管理課", "茨城県の防災・危機管理課です。", "茨城県", "official"),
        ("北海道支店 防災・鉄構", "株式会社です", "北海道", "company"),
        ("茨城県の防災士会（仮）", "非公認のアカウントです。", "茨城県", "individual"),
        ("通りすがりのアルパカ", "災害ボラで五城目町に出入りしていました。", "秋田県", "unknown"),
        ("埼玉県防災学習センター", "埼玉県防災学習センターは、地震や暴風などの疑似体験を", "埼玉県", "gov_related"),
        ("静岡県出身40代男", "40代男。南海トラフ地震が怖いので", "静岡県", "individual"),
        ("日本防災士協会　沖縄県支部　広報", "日本防災士会は、会員相互の", "沖縄県", "organization"),
        ("山形市防災対策課", "山形市防災対策課の公式アカウントです。", "山形県", "other_area"),
        ("おおさか防災ネット（大阪府）", "おおさか防災ネットの大阪府のアカウントです。災害・防災に関する情報を提供します。", "大阪府", "official"),
        ("宮城県防災", "宮城県総務部危機対策課です。", "宮城県", "official"),
    ]
    for name, desc, gov, want in cases:
        got, why = classify(name, desc, gov)
        assert got == want, f"{name}: {got} != {want} ({why})"
    print("classify セルフテスト OK")


if __name__ == "__main__":
    _selftest()
