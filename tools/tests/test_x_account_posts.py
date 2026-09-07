from tools.x_account_posts import summarize


def test_counts_disaster_and_alert_posts_separately():
    posts = [
        "【大雨警報】県内全域に大雨警報が発表されました。",   # 防災・速報の両方
        "本日、防災訓練を実施しました。",                     # 防災のみ（啓発）
        "県産いちごのPRイベントを開催します。",               # 無関係
        "避難指示を発令しました。避難所を開設しています。",   # 防災・速報の両方
    ]
    s = summarize("example", posts)
    assert s["posts"] == 4
    assert s["disaster_posts"] == 3
    assert s["alert_posts"] == 2
    assert s["ratio"] == 0.75
    assert len(s["examples"]) == 2
    assert "大雨警報" in s["examples"][0]


def test_no_posts_does_not_divide_by_zero():
    s = summarize("empty", [])
    assert s["posts"] == 0
    assert s["ratio"] == 0.0
    assert s["examples"] == []


def test_examples_are_trimmed_to_one_line():
    s = summarize("x", ["震度5弱の地震が\n発生しました。\n\n落ち着いて行動してください。"])
    assert "\n" not in s["examples"][0]
    assert s["alert_posts"] == 1


def test_promotional_only_account_scores_zero():
    s = summarize("pr", ["ゆるキャラの投票をお願いします！", "観光キャンペーン開始"])
    assert s["disaster_posts"] == 0
    assert s["alert_posts"] == 0
