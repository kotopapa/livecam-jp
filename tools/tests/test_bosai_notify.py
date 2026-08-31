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
    resp = mock.Mock(); resp.status_code = 200
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
    resp = mock.Mock(); resp.status_code = 200; resp.json.return_value = reports
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


def test_same_office_parallel_products_are_merged():
    # 実例(2026-08-23 石垣島): 同一官署・同時刻でも気象警報(VPWW55)と
    # 土砂災害(VPWW56)は別報。官署単位で1報に絞ると土砂災害49が落ちる
    reports = [
        {"publishingOffice": "石垣島地方気象台",
         "reportDatetime": "2026-08-23T07:06:00+09:00",
         "dataTypeCode": "VPWW55",
         "warning": {"class10Items": [
             {"areaCode": "474010",
              "kinds": [{"code": "03", "status": "危険警報から警報"}]},
         ]}},
        {"publishingOffice": "石垣島地方気象台",
         "reportDatetime": "2026-08-23T07:06:00+09:00",
         "dataTypeCode": "VPWW56",
         "warning": {"class10Items": [
             {"areaCode": "474010",
              "kinds": [{"code": "49", "status": "継続"}]},
         ]}},
    ]
    resp = mock.Mock(); resp.status_code = 200; resp.json.return_value = reports
    with mock.patch.object(bosai_notify.requests, "get",
                           lambda url, timeout=30: resp):
        events, current = bosai_notify.check_special_warnings(
            {"active_special": []})
    assert current == ["47:49"]
    assert events == [("47", "49", "danger", "土砂災害危険警報")]


def _quake_get(entries):
    resp = mock.Mock(); resp.status_code = 200
    resp.json.return_value = entries
    return lambda url, timeout=30: resp


def _recent_at():
    from datetime import datetime
    return datetime.now(bosai_notify.JST).replace(microsecond=0).isoformat()


def test_quake_multiple_reports_same_eid_send_single_push():
    # 実例(2026-08-23 茨城県南部): 同一eidが震度速報3報+詳報1報で並び、
    # 震度速報は anm/mag が空文字列。4通ではなく詳報ベースの1通にする
    at = _recent_at()
    entries = [
        {"eid": "20260823020005", "maxi": "5-", "anm": "", "mag": "",
         "at": at, "rdt": at},
        {"eid": "20260823020005", "maxi": "5-", "anm": "", "mag": "",
         "at": at, "rdt": at},
        {"eid": "20260823020005", "maxi": "5-", "anm": "茨城県南部",
         "mag": "5.9", "at": at, "rdt": at},
        {"eid": "20260823020005", "maxi": "5-", "anm": "", "mag": "",
         "at": at, "rdt": at},
    ]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": []})
    assert len(events) == 1
    eid, title, body, topics = events[0]
    assert eid == "20260823020005"
    assert title == "震度5弱の地震が発生しました"
    assert body.startswith("茨城県南部で震度5弱（M5.9・")
    assert topics == ["quake5"]


def test_quake_sokuho_only_omits_empty_place_and_mag():
    # 震度速報しかない時点でも欠落文（「で震度」「M・」）にしない
    at = _recent_at()
    entries = [{"eid": "e1", "maxi": "5-", "anm": "", "mag": "",
                "at": at, "rdt": at}]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": []})
    assert len(events) == 1
    body = events[0][2]
    assert body.startswith("震度5弱を観測（")
    assert "で震度" not in body and "（M・" not in body


def test_quake_uses_highest_intensity_among_reports():
    # 速報5弱→詳報5強のときは5強で通知し、対応トピックへ送る
    at = _recent_at()
    entries = [
        {"eid": "e2", "maxi": "5-", "anm": "", "mag": "", "at": at, "rdt": at},
        {"eid": "e2", "maxi": "5+", "anm": "千葉県北西部", "mag": "6.1",
         "at": at, "rdt": at},
    ]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": []})
    assert len(events) == 1
    assert "震度5強" in events[0][1]
    assert events[0][3] == ["quake5", "quake5up"]


def test_quake_already_notified_eid_skipped():
    at = _recent_at()
    entries = [{"eid": "e3", "maxi": "5-", "anm": "宮城県沖", "mag": "5.5",
                "at": at, "rdt": at}]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": ["e3"]})
    assert events == []


def test_non_json_response_is_skipped_without_crash():
    # 気象庁が一時的にHTMLエラー等を返しても落ちず、状態も変えない
    resp = mock.Mock(); resp.status_code = 200; resp.json.side_effect = ValueError("no json")
    with mock.patch.object(bosai_notify.requests, "get", lambda url, timeout=30: resp):
        assert bosai_notify.check_quakes({"notified_quakes": []}) == []
        events, current = bosai_notify.check_special_warnings({"active_special": ["13:33"]})
    assert events == [] and current == ["13:33"]


def test_http_error_is_skipped():
    resp = mock.Mock(); resp.status_code = 503
    with mock.patch.object(bosai_notify.requests, "get", lambda url, timeout=30: resp):
        assert bosai_notify.check_quakes({"notified_quakes": []}) == []


def test_parse_jma_time_always_returns_jst():
    from datetime import datetime, timezone
    # 通常表記（+09:00）
    assert bosai_notify.parse_jma_time("2026-08-30T05:12:00+09:00").hour == 5
    # UTC表記(Z)が来ても本文の時刻がJSTになる（そのまま使うと9時間ずれる）
    assert bosai_notify.parse_jma_time("2026-08-29T20:12:00Z").strftime(
        "%Y-%m-%d %H:%M") == "2026-08-30 05:12"
    # オフセット無し（naive）はJSTとみなす。awareと比較できること
    naive = bosai_notify.parse_jma_time("2026-08-30T05:12:00")
    assert naive.tzinfo is not None
    assert naive == datetime(2026, 8, 29, 20, 12, tzinfo=timezone.utc)
    # 壊れた値でも例外を投げない（通知処理全体を落とさない）
    assert bosai_notify.parse_jma_time("").year == 1970
    assert bosai_notify.parse_jma_time(None).year == 1970


def test_quake_body_time_is_jst_even_when_source_is_utc():
    # 気象庁の at が "Z" 表記で来ても本文は JST 表記のままであること
    from datetime import datetime, timedelta, timezone
    at_utc = (datetime.now(timezone.utc) - timedelta(minutes=30)).replace(
        microsecond=0)
    entries = [{"eid": "e-utc", "maxi": "5-", "anm": "日向灘", "mag": "6.1",
                "at": at_utc.strftime("%Y-%m-%dT%H:%M:%S") + "Z",
                "rdt": at_utc.isoformat()}]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": []})
    assert len(events) == 1
    expected = at_utc.astimezone(bosai_notify.JST).strftime("%H:%M")
    assert f"{expected}頃" in events[0][2]


def test_quake_naive_timestamp_does_not_crash():
    # オフセットが欠けた at（naive）でも TypeError で全滅せず、JSTとして扱う
    from datetime import datetime, timedelta
    at = (datetime.now(bosai_notify.JST) - timedelta(minutes=10)).replace(
        microsecond=0).strftime("%Y-%m-%dT%H:%M:%S")
    entries = [{"eid": "e-naive", "maxi": "5+", "anm": "能登半島沖",
                "mag": "6.5", "at": at, "rdt": at}]
    with mock.patch.object(bosai_notify.requests, "get", _quake_get(entries)):
        events = bosai_notify.check_quakes({"notified_quakes": []})
    assert len(events) == 1 and at[11:16] + "頃" in events[0][2]
