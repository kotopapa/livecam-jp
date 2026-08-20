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
    assert len(events) == 1
    title, body, pref = events[0]
    assert pref == "13"
    assert "東京都" in body and "大雨特別警報" in body


def test_already_active_warning_not_renotified():
    with mock.patch.object(bosai_notify.requests, "get", _fake_get):
        events, current = bosai_notify.check_special_warnings(
            {"active_special": ["13:33"]})
    assert events == []
    assert current == ["13:33"]
