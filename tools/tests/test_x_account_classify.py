from tools.x_account_classify import LABEL_JA, classify


def t(name, desc, gov):
    return classify(name, desc, gov)[0]


def test_official_needs_area_name_and_department():
    assert t("相模原市災害情報", "相模原市危機管理局危機管理統括部です。", "相模原市") == "official"
    assert t("宮城県防災", "宮城県総務部危機対策課です。", "宮城県") == "official"
    # 「◯◯県の…アカウントです」＋防災語
    assert t("おおさか防災ネット（大阪府）",
             "おおさか防災ネットの大阪府のアカウントです。災害・防災に関する情報を提供します。",
             "大阪府") == "official"


def test_private_and_personal_are_separated():
    assert t("北海道支店 防災・鉄構", "株式会社です", "北海道") == "company"
    assert t("日本防災士協会　沖縄県支部", "日本防災士会は、会員相互の", "沖縄県") == "organization"
    assert t("静岡県出身40代男", "40代男。南海トラフ地震が怖いので", "静岡県") == "individual"


def test_explicit_disclaimer_wins_over_official_wording():
    # 「非公認」と書いてあるものは、名称が自治体名でも公式にしない
    assert t("茨城県の防災士会（仮）", "非公認のアカウントです。", "茨城県") == "individual"


def test_area_mismatch_is_flagged():
    # 県を探しているのに市のアカウントを拾った場合
    assert t("山形市防災対策課", "山形市防災対策課の公式アカウントです。", "山形県") == "other_area"


def test_facility_is_not_the_disaster_desk():
    assert t("埼玉県防災学習センター",
             "埼玉県防災学習センターは、地震や暴風などの疑似体験を", "埼玉県") == "gov_related"


def test_unknown_when_no_evidence():
    assert t("通りすがりのアルパカ", "災害ボラで五城目町に出入りしていました。", "秋田県") == "unknown"


def test_every_type_has_a_japanese_label():
    for key in ("official", "gov_related", "company", "organization",
                "individual", "other_area", "unknown"):
        assert LABEL_JA[key]
