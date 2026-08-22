"""check_special_warnings の判定と都道府県抽出をフェイクHTTPでテストする。"""

from unittest import mock

from tools import bosai_notify

R8_REPORTS = [
    {  # 東京: 大雨特別警報(33) 発表中
        "publishingOffice": "気象庁",
        "reportDatetime": "2026-08-20T10:00:00+09:00",
        "warning": {"class10Items": [
            {"areaCode": "130010",
             "kinds": [{"code": "33", "status": "発表"}]},
        ]},
    },
    {  # 同官署の古い報（無視されること）
        "publishingOffice": "気象庁",
        "reportDatetime": "2026-08-20T09:00:00+09:00",
        "warning": {"class10Items": [
            {"areaCode": "140010",
             "kinds": [{"code": "33", "status": "発表"}]},
        ]},
    },
    {  # 大阪管区: 高潮特別警報(38) は解除済み（除外されること）
        "publishingOffice": "大阪管区気象台",
        "reportDatetime": "2026-08-20T10:00:00+09:00",
        "warning": {"class10Items": [
            {"areaCode": "270000",
             "kinds": [{"code": "38", "status": "解除"}]},
        ]},
    },
]


def _fake_get(url, timeout=30):
    resp = mock.Mock()
    resp.json.return_value = R8_REPORTS
    return resp


def test_new_special_warning_carries_pref_code():
    with mock.patch.object(bosai_notify.requests, "get", _fake_get):
        events, current = bosai_notify.check_special_warnings(
            {"active_special": []})
    assert current == ["13:33"]
    assert events == [("13", "33", "special", "大雨特別警報")]


def test_danger_warning_uses_danger_family():
    reports = [{
        "publishingOffice": "横浜地方気象台",
        "reportDatetime": "2026-08-22T18:43:00+09:00",
        "warning": {"class10Items": [
            {"areaCode": "140010",
             "kinds": [{"code": "43", "status": "発表"}]},
        ]},
    }]
    resp = mock.Mock(); resp.json.return_value = reports
    with mock.patch.object(bosai_notify.requests, "get",
                           lambda url, timeout=30: resp):
        events, current = bosai_notify.check_special_warnings(
            {"active_special": []})
    assert current == ["14:43"]
    assert events == [("14", "43", "danger", "大雨危険警報")]


def test_aggregate_same_warning_multiple_prefs_into_one_national_push():
    events = [("13", "33", "special", "大雨特別警報"),
              ("14", "33", "special", "大雨特別警報"),
              ("12", "33", "special", "大雨特別警報")]
    pushes = bosai_notify.aggregate_warning_pushes(events)
    topics = [p[0] for p in pushes]
    # 全国1通 + 県別3通
    assert topics == ["special-warning", "special-warning-12",
                      "special-warning-13", "special-warning-14"]
    title, body = pushes[0][1], pushes[0][2]
    assert title == "大雨特別警報が発表されました"
    assert "千葉県・東京都・神奈川県" in body


def test_aggregate_mixed_warnings_summarized():
    events = [("13", "33", "special", "大雨特別警報"),
              ("14", "35", "special", "暴風特別警報")]
    pushes = bosai_notify.aggregate_warning_pushes(events)
    nat = pushes[0]
    assert nat[0] == "special-warning"
    assert nat[1] == "特別警報が発表されました"
    assert "東京都に大雨特別警報" in nat[2] and "神奈川県に暴風特別警報" in nat[2]


def test_aggregate_multiple_kinds_same_pref_merged():
    events = [("14", "33", "special", "大雨特別警報"),
              ("14", "35", "special", "暴風特別警報")]
    pushes = bosai_notify.aggregate_warning_pushes(events)
    pref_push = [p for p in pushes if p[0] == "special-warning-14"]
    assert len(pref_push) == 1
    assert "大雨特別警報・暴風特別警報" in pref_push[0][2]
    assert "ほか1件" in pref_push[0][1]


def test_aggregate_danger_family_separate_topic_and_tag():
    events = [("14", "43", "danger", "大雨危険警報"),
              ("13", "33", "special", "大雨特別警報")]
    pushes = bosai_notify.aggregate_warning_pushes(events)
    topics = [p[0] for p in pushes]
    assert "special-warning" in topics and "danger-warning" in topics
    danger_nat = [p for p in pushes if p[0] == "danger-warning"][0]
    assert "レベル4" in danger_nat[1] and "神奈川県" in danger_nat[2]


def test_already_active_warning_not_renotified():
    with mock.patch.object(bosai_notify.requests, "get", _fake_get):
        events, current = bosai_notify.check_special_warnings(
            {"active_special": ["13:33"]})
    assert events == []
    assert current == ["13:33"]
