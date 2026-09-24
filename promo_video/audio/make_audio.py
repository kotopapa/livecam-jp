"""プロモーション動画の BGM と効果音を一から合成する（外部音源なし＝権利の心配なし）。

120 BPM（1拍 0.5 秒）。シーンの切り替わり（2.5/5.5/8.5/12.5/16/19/22/25/27 秒）は全て拍の頭に乗る。
効果音の時刻は remotion/src/promo/Scenes.tsx のフレーム（30fps）から計算している。
シーンの秒数や演出のフレームを変えたら EVENTS を合わせて直すこと。

usage: python promo_video/audio/make_audio.py  → promo_video/remotion/public/audio/promo.wav
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, istft, sosfilt, stft

SR = 48000
DUR = 30.0
N = int(SR * DUR)
BEAT = 0.5
RNG = np.random.default_rng(20260924)
OUT = Path(__file__).resolve().parents[1] / "remotion" / "public" / "audio" / "promo.wav"

t_all = np.arange(N) / SR


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def buf(sec: float) -> np.ndarray:
    return np.zeros(int(sec * SR))


def place(track: np.ndarray, sig: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(at * SR)
    if i >= len(track):
        return
    j = min(len(track), i + len(sig))
    track[i:j] += sig[: j - i] * gain


def lp(x, fc, order=2):
    return sosfilt(butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def expenv(n: int, decay: float, attack: float = 0.002) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def saw(freq: float, n: int, phase: float = 0.0) -> np.ndarray:
    t = np.arange(n) / SR
    return 2 * ((t * freq + phase) % 1.0) - 1


# ------------------------------------------------------------------
# 音色
# ------------------------------------------------------------------
def kick() -> np.ndarray:
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * expenv(n, 0.22)
    click = hp(RNG.standard_normal(n), 3000) * expenv(n, 0.004) * 0.25
    return np.tanh((body + click) * 1.6)


def clap() -> np.ndarray:
    n = int(0.3 * SR)
    noise = bp(RNG.standard_normal(n), 900, 3200)
    env = np.zeros(n)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        env += np.roll(expenv(n, 0.012 if k < 2 else 0.11), int(d * SR)) * (0.7 if k < 2 else 1.0)
    return noise * env * 1.2


def hat(open_: bool = False) -> np.ndarray:
    n = int((0.25 if open_ else 0.06) * SR)
    return hp(RNG.standard_normal(n), 7000, 4) * expenv(n, 0.09 if open_ else 0.022) * 0.8


def pluck(freq: float, dur: float = 0.22) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = 0.6 * np.sign(np.sin(2 * np.pi * freq * t)) + 0.4 * np.sin(2 * np.pi * 2 * freq * t)
    return lp(x, 3200) * expenv(n, 0.07)


def bass_note(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    x = saw(freq, n) + 0.5 * np.sin(2 * np.pi * freq / 2 * np.arange(n) / SR)
    env = expenv(n, dur * 0.8, 0.004)
    env[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
    return lp(x, 900, 2) * env


def supersaw(freqs: list[float], dur: float, detune=(-0.13, -0.06, 0, 0.06, 0.13)) -> tuple[np.ndarray, np.ndarray]:
    n = int(dur * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    for f in freqs:
        for k, d in enumerate(detune):
            ff = f * 2 ** (d / 12)
            s = saw(ff, n, RNG.random())
            pan = (k - 2) / 2.5
            L += s * (1 - pan) * 0.5
            R += s * (1 + pan) * 0.5
    return L, R


def boom() -> np.ndarray:
    """シーン切り替えの衝撃音（サブの落下＋ノイズ）"""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 30 + 55 * np.exp(-t / 0.25)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * expenv(n, 0.55)
    crack = lp(RNG.standard_normal(n), 2500) * expenv(n, 0.06)
    return np.tanh((sub * 0.8 + crack * 0.9) * 1.3)


def crash() -> np.ndarray:
    n = int(2.2 * SR)
    return hp(RNG.standard_normal(n), 5000, 2) * expenv(n, 0.7) * 0.35


def sweep_noise(dur: float, f0: float, f1: float, width: float = 0.35, up_gain=True) -> np.ndarray:
    """中心周波数が f0→f1 に動くノイズ（風切り音・ライザー）。STFT 上で帯域を動かす"""
    n = int(dur * SR)
    noise = RNG.standard_normal(n + 2048)
    f, tt, Z = stft(noise, SR, nperseg=1024)
    prog = np.clip(tt / dur, 0, 1)
    center = np.exp(np.log(f0) + (np.log(f1) - np.log(f0)) * prog)
    lf = np.log(np.maximum(f, 20))[:, None]
    mask = np.exp(-((lf - np.log(center)[None, :]) ** 2) / (2 * width**2))
    _, y = istft(Z * mask, SR, nperseg=1024)
    y = y[:n]
    env = np.sin(np.pi * np.clip(np.arange(n) / n, 0, 1)) ** (1.5 if not up_gain else 0.6)
    if up_gain:
        env *= np.linspace(0.2, 1, n) ** 2
    y = y / (np.abs(y).max() + 1e-9)
    return y * env


def whoosh(dur=0.38, up=True) -> np.ndarray:
    return sweep_noise(dur, 350 if up else 3500, 4000 if up else 300, 0.45, up_gain=False) * 0.55


def pop(freq: float) -> np.ndarray:
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 0.6 * np.exp(-t / 0.012))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * expenv(n, 0.045) * 0.6


def tick(freq: float) -> np.ndarray:
    n = int(0.03 * SR)
    return np.sin(2 * np.pi * freq * np.arange(n) / SR) * expenv(n, 0.006) * 0.35


def chime(freq: float) -> np.ndarray:
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    mod = 2.0 * np.exp(-t / 0.3) * np.sin(2 * np.pi * freq * 3.5 * t)
    return np.sin(2 * np.pi * freq * t + mod) * expenv(n, 0.45) * 0.5


def thud() -> np.ndarray:
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 70 + 90 * np.exp(-t / 0.02)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * expenv(n, 0.09) * 0.8


# ------------------------------------------------------------------
# 曲の構成
# ------------------------------------------------------------------
PROG = [(50, [62, 66, 69]), (45, [61, 64, 69]), (47, [62, 66, 71]), (43, [62, 67, 71])]  # D A Bm G（ベース, 和音）
GROOVE_START = 2.5


def chord_at(t: float):
    i = int(np.floor((t - GROOVE_START) / 2.0)) % 4
    return PROG[i]


def section(t: float) -> str:
    if t < 2.5:
        return "intro"
    if t < 12.5:
        return "a"
    if t < 16.0:
        return "break"
    if t < 25.0:
        return "b"
    if t < 27.0:
        return "build"
    return "end"


drums = np.zeros(N)
bass = np.zeros(N)
padL = np.zeros(N)
padR = np.zeros(N)
arp = np.zeros(N)
fxL = np.zeros(N)
fxR = np.zeros(N)
kick_times: list[float] = []

K, CL, HT, HO = kick(), clap(), hat(), hat(True)

# ドラム
for b in range(int(DUR / BEAT)):
    tb = b * BEAT
    sec = section(tb)
    if sec in ("a", "b"):
        place(drums, K, tb, 1.0); kick_times.append(tb)
        place(drums, HT, tb + BEAT / 2, 0.8)
        if b % 2 == 1:
            place(drums, CL, tb, 0.8)
        if sec == "b":
            place(drums, HT, tb + BEAT * 0.25, 0.35); place(drums, HT, tb + BEAT * 0.75, 0.35)
    elif sec == "intro":
        if tb in (0.0, 1.0):
            place(drums, K, tb, 0.9); kick_times.append(tb)
    elif sec == "break":
        if b % 2 == 0:
            place(drums, K, tb, 0.8); kick_times.append(tb)
        place(drums, HT, tb + BEAT / 2, 0.5)
    elif sec == "end" and tb < 29.0:
        place(drums, K, tb, 1.0); kick_times.append(tb)
        place(drums, HO, tb + BEAT / 2, 0.5)
        if b % 2 == 1:
            place(drums, CL, tb, 0.8)

# イントロのスネアロール（1.5→2.5秒）とビルド（25→27秒）で加速するロール
def roll(t0: float, t1: float, start_div: int, end_div: int, g0: float, g1: float):
    t = t0
    while t < t1 - 1e-6:
        p = (t - t0) / (t1 - t0)
        div = start_div + (end_div - start_div) * p
        place(drums, CL, t, g0 + (g1 - g0) * p)
        t += BEAT / div


roll(1.5, 2.5, 2, 8, 0.25, 0.7)
roll(25.0, 26.75, 1, 8, 0.25, 0.85)

# ベース（8分の裏で刻む）
for b in range(int(DUR / BEAT) * 2):
    tb = b * BEAT / 2
    sec = section(tb)
    if sec in ("a", "b") or (sec == "end" and tb < 29):
        if b % 2 == 1 or sec == "b":
            root = chord_at(tb)[0]
            place(bass, bass_note(midi(root), BEAT / 2 * 0.95), tb, 0.7)
    elif sec == "break" and b % 4 == 0:
        place(bass, bass_note(midi(chord_at(tb)[0]), BEAT * 1.9), tb, 0.6)

# パッド（コードごとに2秒。イントロは D を薄く）
for bar_t in np.arange(0.5, DUR, 2.0):
    t0 = float(bar_t)
    sec = section(t0 + 0.01)
    notes = chord_at(t0 + 0.01)[1] if t0 >= 2.5 else PROG[0][1]
    dur = 2.0 if t0 + 2.0 <= DUR else DUR - t0
    L, R = supersaw([midi(n - 12) for n in notes], dur)
    n = len(L)
    env = np.clip(np.arange(n) / (0.25 * SR), 0, 1) * np.clip((n - np.arange(n)) / (0.08 * SR), 0, 1)
    fc = {"intro": 1400, "a": 3200, "break": 1800, "b": 4200, "build": 2400, "end": 5000}[sec]
    g = {"intro": 0.16, "a": 0.2, "break": 0.2, "b": 0.22, "build": 0.18, "end": 0.24}[sec]
    place(padL, lp(L, fc) * env, t0, g)
    place(padR, lp(R, fc) * env, t0, g)
# 0〜0.5 秒の頭も和音で満たす
L, R = supersaw([midi(n - 12) for n in PROG[0][1]], 0.5)
place(padL, lp(L, 700) * np.linspace(0, 1, len(L)), 0.0, 0.08)
place(padR, lp(R, 700) * np.linspace(0, 1, len(R)), 0.0, 0.08)

# アルペジオ（16分。地図のシーン以降）
for s in range(int(DUR / (BEAT / 4))):
    tb = s * BEAT / 4
    sec = section(tb)
    if tb < 5.5 or sec in ("break", "build") or tb >= 29.0:
        continue
    notes = chord_at(tb)[1]
    seq = [notes[0], notes[1], notes[2], notes[1] + 12, notes[2], notes[0] + 12, notes[1], notes[2] + 12]
    place(arp, pluck(midi(seq[s % 8] + 12)), tb, 0.32 if sec == "a" else 0.4)

# 最後の和音（27秒の落下で鳴らし、30秒まで伸ばす）
L, R = supersaw([midi(n) for n in [50, 57, 62, 66, 69, 74]], 3.0)
env = np.exp(-np.arange(len(L)) / SR / 1.6)
place(padL, lp(L, 4000) * env, 27.0, 0.16)
place(padR, lp(R, 4000) * env, 27.0, 0.16)

# ------------------------------------------------------------------
# 効果音（Scenes.tsx のフレームから。シーン開始秒 + フレーム/30）
# ------------------------------------------------------------------
S = {"hook": 0.0, "count": 2.5, "map": 5.5, "travel": 8.5, "weather": 12.5, "alert": 16.0, "shelter": 19.0, "daily": 22.0, "all": 25.0, "end": 27.0}
F = 1 / 30
PENTA = [74, 76, 78, 81, 83, 86, 88, 90, 93]  # D メジャー・ペンタトニック（ポップ音の高さ）


def fx(sig, at, gain=1.0, pan=0.0):
    place(fxL, sig, at, gain * (1 - pan) ** 0.5 if pan > 0 else gain)
    place(fxR, sig, at, gain * (1 + pan) ** 0.5 if pan < 0 else gain)


BOOM, CRASH = boom(), crash()
for name in ["count", "map", "travel", "weather", "alert", "shelter", "daily", "all"]:
    fx(BOOM, S[name], 0.55)
fx(BOOM, S["end"], 0.9)
fx(CRASH, S["end"], 0.8)
fx(CRASH, S["count"], 0.45)
fx(CRASH, S["alert"], 0.4)

# イントロのライザー（0→2.5秒）とビルドのライザー（25→27秒）
fx(sweep_noise(2.4, 250, 9000, 0.5), 0.1, 0.35)
fx(sweep_noise(2.0, 200, 11000, 0.5), 25.0, 0.45)
# 天気の切り替え前のライザー（15→16秒）
fx(sweep_noise(1.0, 400, 7000, 0.45), 15.0, 0.25)

# 1. 問いかけ：スライドと、1文字ずつ跳ねる「今、どう？」
fx(whoosh(0.4), S["hook"] + 0.0, 0.8, -0.4)
fx(whoosh(0.5), S["hook"] + 2 * F, 0.5, 0.3)
for i in range(7):  # 「今どうなってる」7文字（delay 10・stagger 2）
    fx(pop(midi(PENTA[i])), S["hook"] + (10 + 2 * i) * F + 3 * F, 0.5)

# 2. カウントアップの刻み（0→32F）と着地のチャイム、文字が右から
for k in range(0, 32, 2):
    fx(tick(1200 + k * 45), S["count"] + k * F, 0.7)
fx(chime(midi(86)), S["count"] + 32 * F, 0.55)
fx(chime(midi(93)), S["count"] + 33 * F, 0.3)
fx(whoosh(0.45, up=False), S["count"] + 20 * F, 0.5, 0.5)
fx(whoosh(0.6), S["count"], 0.55)  # スマホが裏返る

# 3. 地図：縦書きが上下から、寄る動き
fx(whoosh(0.4, up=False), S["map"], 0.7, -0.5)
fx(whoosh(0.4), S["map"] + 6 * F, 0.7, 0.5)
fx(sweep_noise(1.5, 300, 2500, 0.4), S["map"] + 34 * F, 0.18)

# 4. 旅先：横から見出し、「今へ。」のポップ、3台のスマホ
fx(whoosh(0.4, up=False), S["travel"], 0.7, 0.5)
for i in range(5):  # 「旅先の今を」5文字（delay 8・stagger 3）
    fx(pop(midi(PENTA[1 + i])), S["travel"] + (8 + 3 * i) * F + 4 * F, 0.65)
for i, (d, pan) in enumerate([(10, -0.6), (16, 0.0), (22, 0.6)]):
    fx(whoosh(0.35), S["travel"] + d * F, 0.45, pan)

# 5. 天気：見出しが退場、スマホが裏返る、新しい見出しが下から
fx(whoosh(0.35), S["weather"], 0.6)
fx(whoosh(0.35, up=False), S["weather"] + 42 * F, 0.6, -0.6)
fx(sweep_noise(0.55, 500, 6000, 0.35), S["weather"] + 44 * F, 0.55)
fx(thud(), S["weather"] + 58 * F, 0.7)
fx(whoosh(0.4), S["weather"] + 50 * F, 0.55)
fx(whoosh(0.35, up=False), S["weather"] + 6 * F, 0.45, 0.5)  # 「地図に重ねて」が右から

# 6. 通知：1文字ずつ跳ねる、「通知で。」が落ちてくる、ラベルが左から
for i in range(6):  # 「警報も地震も」
    fx(tick(900 + i * 60), S["alert"] + (2 * i + 3) * F, 0.5)
for i in range(5):  # 「通知で届く」が落ちてくる
    fx(thud(), S["alert"] + (12 + 4 * i) * F + 8 * F, 0.55)
for i, d in enumerate([24, 30, 36]):
    fx(whoosh(0.3), S["alert"] + d * F, 0.4, -0.6)
    fx(pop(midi(PENTA[4 + i])), S["alert"] + (d + 6) * F, 0.6)

# 7. 避難先：上下から見出し、スマホが左から回り込む
fx(whoosh(0.4, up=False), S["shelter"], 0.6)
fx(whoosh(0.4), S["shelter"] + 6 * F, 0.6)
fx(whoosh(0.55), S["shelter"] + 4 * F, 0.5, -0.6)

# 8. 注目と備え：2台が上下から、文字が左右から
fx(whoosh(0.45, up=False), S["daily"], 0.55, -0.4)
fx(whoosh(0.45), S["daily"] + 8 * F, 0.55, 0.4)
for i in range(7):  # 「みんなの人気も」
    fx(tick(1000 + i * 70), S["daily"] + (2 * i + 4) * F, 0.35, -0.3)
for i in range(6):  # 「備蓄の期限も」
    fx(tick(1400 + i * 70), S["daily"] + (20 + 2 * i + 4) * F, 0.35, 0.3)

# 9. ぜんぶ：回転しながら着地、画面が流れる
for i in range(6):  # 「ここまで全部」
    fx(pop(midi(PENTA[i + 2])), S["all"] + (3 * i + 5) * F, 0.55)
fx(sweep_noise(1.9, 3000, 600, 0.5, up_gain=False), S["all"], 0.25)

# 10. 締め：「今を、」のポップ、名前、無料のラベル
fx(whoosh(0.4, up=False), S["end"], 0.5, 0.5)  # 「気になる場所の」が右から
for i in range(5):  # 「今を見よう」（delay 8・stagger 3）
    fx(pop(midi(PENTA[2 + i])), S["end"] + (8 + 3 * i) * F + 4 * F, 0.75)
fx(chime(midi(86)), S["end"] + 30 * F, 0.45)
fx(chime(midi(90)), S["end"] + 31 * F, 0.3)
fx(chime(midi(93)), S["end"] + 32 * F, 0.25)

# ------------------------------------------------------------------
# ミックス
# ------------------------------------------------------------------
# キックに合わせて伴奏を沈める（サイドチェイン風）
duck = np.ones(N)
for kt in kick_times:
    i = int(kt * SR)
    n = min(N - i, int(0.35 * SR))
    tt = np.arange(n) / SR
    duck[i:i + n] = np.minimum(duck[i:i + n], 1 - 0.55 * np.exp(-tt / 0.09))


def reverb(x: np.ndarray, sec=1.6, mix=0.22) -> np.ndarray:
    n = int(sec * SR)
    ir = RNG.standard_normal(n) * np.exp(-np.arange(n) / SR / (sec / 5))
    ir = lp(ir, 5000)
    wet = fftconvolve(x, ir)[: len(x)]
    wet *= np.abs(x).max() / (np.abs(wet).max() + 1e-9)
    return x * (1 - mix) + wet * mix


music_L = drums * 0.75 + bass * duck * 0.7 + padL * duck + reverb(arp, 1.2, 0.3) * duck
music_R = drums * 0.75 + bass * duck * 0.7 + padR * duck + reverb(arp, 1.2, 0.3) * duck
fxL_r, fxR_r = reverb(fxL, 1.4, 0.18), reverb(fxR, 1.4, 0.18)

L = music_L * 0.85 + fxL_r * 1.0
R = music_R * 0.85 + fxR_r * 1.0
L, R = hp(L, 35), hp(R, 35)
# 低域を少し削り、2kHz 以上に張りを足す（スマホのスピーカー向け）
L = L - 0.35 * lp(L, 90) + 0.35 * hp(L, 2500)
R = R - 0.35 * lp(R, 90) + 0.35 * hp(R, 2500)

# 終わりは 29.2 秒から静かに収める
fade = np.ones(N)
a = int(29.2 * SR)
fade[a:] = np.linspace(1, 0, N - a) ** 1.5
L *= fade
R *= fade

# ソフトクリップしてから -1 dBFS に揃える
st = np.stack([L, R], axis=1)
st = np.tanh(st / (np.abs(st).max() + 1e-9) * 1.15)
st = st / np.abs(st).max() * 10 ** (-1 / 20)
OUT.parent.mkdir(parents=True, exist_ok=True)
wavfile.write(OUT, SR, (st * 32767).astype(np.int16))
print("wrote", OUT, f"{DUR}s", "peak", np.abs(st).max().round(3))
