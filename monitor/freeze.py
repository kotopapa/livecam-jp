"""フリーズ判定（SPEC 7.2）。

- 画像の知覚ハッシュ dHash 64bit を Pillow だけで計算
- 履歴（最大48件=24時間分）が全て同一ハッシュ かつ 最古から6時間以上 → frozen 候補
- ただし夜間の真っ暗画像による誤判定を防ぐため、
  「日の出時刻±1時間を跨いだ比較」のときのみ frozen を確定する
"""

from __future__ import annotations

import io
import math
from datetime import datetime, timedelta, timezone

from PIL import Image

HISTORY_MAX = 48
FROZEN_AFTER_HOURS = 6

# 「画像なし」プレースホルダの既知dHash。
# cam.river.go.jp は存在しないカメラにも HTTP 200 でプレースホルダPNGを返すため、
# ステータスコードでは検知できない（フィクスチャ: crawler/tests/fixtures/kawabou_placeholder.png）
PLACEHOLDER_HASHES = [
    0x10101c0c0010101,      # 川の防災情報 cam.river.go.jp の「画像がありません」
    0x153169713131d890,     # 道路情報提供システム road-info-prvs の no_data.jpeg
    0x2d27000100,           # 沖縄県河川情報システム img_cam/p-NN.jpg の「運用停止中」(黒地白文字)
    0x8304c4c300000,       # 金沢河川国道 防災情報(bousai-info-ishikawa) の「工事中」(青地黄文字)
]
PLACEHOLDER_MAX_DISTANCE = 2


def is_placeholder(h: int | None) -> bool:
    if h is None:
        return False
    return any(hamming(h, p) <= PLACEHOLDER_MAX_DISTANCE for p in PLACEHOLDER_HASHES)


def dhash64(image_bytes: bytes) -> int | None:
    """dHash 64bit。デコード不能なら None。"""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("L").resize((9, 8), Image.LANCZOS)
    except Exception:
        return None
    px = list(img.getdata())
    bits = 0
    for row in range(8):
        for col in range(8):
            left = px[row * 9 + col]
            right = px[row * 9 + col + 1]
            bits = (bits << 1) | (1 if left > right else 0)
    return bits


def is_black_frame(image_bytes: bytes) -> bool:
    """ほぼ真っ暗な画像か（映像信号なし・レンズ遮蔽・機器故障）。
    タイムスタンプ等の白文字が少量乗っていても検知できるよう、
    平均輝度と「明るい画素の割合」の両方で判定する。"""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("L").resize((64, 48))
    except Exception:
        return False
    px = list(img.getdata())
    if not px:
        return False
    mean = sum(px) / len(px)
    p90 = sorted(px)[int(len(px) * 0.9)]
    bright = sum(1 for v in px if v > 60) / len(px)
    # 実例(子浦川 吉野屋橋の信号なし画像): mean 18 / p90 16 / bright 1.7%
    return mean < 26 and p90 < 32 and bright < 0.03


def is_local_daytime(now: datetime, lng: float | None) -> bool:
    """経度から求めた概略の地方時で 9〜16時か（夜間の暗画像を誤検知しない）。"""
    if lng is None:
        return False
    hour = (now.astimezone(timezone.utc).hour + now.minute / 60 + lng / 15.0) % 24
    return 9 <= hour <= 16


def hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def sunrise_utc(lat: float, lng: float, on_date) -> datetime | None:
    """NOAA近似式による日の出時刻（UTC）。極端な高緯度などで解なしは None。

    誤差は数分程度で、±1時間の窓判定には十分。
    """
    n = on_date.timetuple().tm_yday
    lng_hour = lng / 15
    t = n + ((6 - lng_hour) / 24)          # 日の出の近似時刻
    m = (0.9856 * t) - 3.289
    l = m + (1.916 * math.sin(math.radians(m))) + (0.020 * math.sin(math.radians(2 * m))) + 282.634
    l %= 360
    ra = math.degrees(math.atan(0.91764 * math.tan(math.radians(l)))) % 360
    ra += (math.floor(l / 90) * 90) - (math.floor(ra / 90) * 90)
    ra /= 15
    sin_dec = 0.39782 * math.sin(math.radians(l))
    cos_dec = math.cos(math.asin(sin_dec))
    zenith = math.radians(90.833)
    cos_h = (math.cos(zenith) - (sin_dec * math.sin(math.radians(lat)))) / (
        cos_dec * math.cos(math.radians(lat)))
    if cos_h > 1 or cos_h < -1:
        return None
    h = (360 - math.degrees(math.acos(cos_h))) / 15
    t_local = h + ra - (0.06571 * t) - 6.622
    ut = (t_local - lng_hour) % 24
    return datetime(on_date.year, on_date.month, on_date.day, tzinfo=timezone.utc) + timedelta(hours=ut)


def judge_frozen(history: list[dict], now: datetime,
                 lat: float | None, lng: float | None) -> tuple[bool, str | None]:
    """ハッシュ履歴から frozen かどうかを判定する。

    history: [{"at": iso8601, "hash": int}, ...]（古い順）
    戻り値: (frozen?, frozen_since iso8601 or None)
    """
    if len(history) < 2:
        return False, None
    hashes = [h["hash"] for h in history if h.get("hash") is not None]
    if len(hashes) < 2 or len(set(hashes)) > 1:
        return False, None

    oldest = datetime.fromisoformat(history[0]["at"])
    if now - oldest < timedelta(hours=FROZEN_AFTER_HOURS):
        return False, None

    # 夜間誤判定の防止: 座標があるなら「日の出±1時間」を跨いで同一のときだけ frozen
    if lat is not None and lng is not None:
        for d in (now.date(), (now - timedelta(days=1)).date()):
            sr = sunrise_utc(lat, lng, d)
            if sr and oldest <= sr - timedelta(hours=1) and now >= sr + timedelta(hours=1):
                return True, history[0]["at"]
        return False, None      # まだ日の出窓を跨いでいない → 保留（ok扱い）

    # 座標不明ならば従来判定（6時間同一）
    return True, history[0]["at"]
