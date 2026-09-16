"""app-store-screenshots.json を生成する。撮影済みキャプチャを public/screenshots/ へ複製する。
使い方: python3 seed_deck.py <repo>/store_screenshots <captures_ios_dir> [<captures_android_dir>]
"""
import json, shutil, sys, os, glob

root, ios_dir = sys.argv[1], sys.argv[2]
android_dir = sys.argv[3] if len(sys.argv) > 3 else None

def pick(d, key):
    exact = os.path.join(d, f"{key}.png")
    if os.path.exists(exact): return exact
    m = sorted(glob.glob(os.path.join(d, f"*_{key}.png")))
    return m[0] if m else None

# (label, headline, layout, screenshot key, secondary key, inverted, extra text elements)
PLAN = [
    ("全国2万台以上・無料・登録不要", "近くの川の今を、\nこの目で。", "hero", "detail_river", None, False, []),
    ("地図から探す", "地図をタップ、\n現地が映る。", "device-bottom", "map_tokyo_pins", None, False, []),
    ("台風情報・雨雲レーダー", "台風の進路も、\n地図で見える。", "device-top", "layer_typhoon", None, True, []),
    ("災害速報・プッシュ通知", "地震も警報も、\n通知で届く。", "device-bottom", "bosai_warning", None, False, []),
    ("避難場所・ハザードマップ", "逃げる場所も、\n同じ地図に。", "two-devices", "layer_shelters", "layer_hazard_flood", False, []),
    ("みんなのランキング", "今、見られている\nカメラがわかる。", "device-top", "ranking", None, True, []),
    ("備え", "備蓄の期限も、\nアプリが覚える。", "device-bottom", "stockpile", None, False, []),
    ("富士山・海岸・世界70カ国", "海も山も街も、\n今を見に行こう。", "two-devices", "detail_fuji", "detail_coast", False, []),
]

def build(device, cap_dir, sub):
    slides = []
    out_dir = os.path.join(root, "public", "screenshots", sub, "ja")
    os.makedirs(out_dir, exist_ok=True)
    n = 0
    for i, (label, headline, layout, key, key2, inverted, extras) in enumerate(PLAN, 1):
        def copy(k):
            nonlocal n
            if not k: return ""
            src = pick(cap_dir, k)
            if not src:
                print("missing capture:", k); return ""
            n += 1
            dst = os.path.join(out_dir, f"{n:02d}_{k}.png")
            shutil.copyfile(src, dst)
            return f"/screenshots/{sub}/ja/{n:02d}_{k}.png"
        s = {
            "id": f"{device}_{i:02d}",
            "layout": layout,
            "label": {"ja": label},
            "headline": {"ja": headline},
            "screenshot": copy(key),
        }
        if key2: s["screenshotSecondary"] = copy(key2)
        if layout == "hero":
            # 見出しと端末で高さの8割以上を使う（端末の上端を 31% に、幅を広めに）
            W, H = (1320, 2868) if device == "iphone" else (1080, 1920)
            dw = W * 0.82; dh = dw / (918 / 1990)
            s["transforms"] = {"device": {"x": (W - dw) / 2, "y": H * 0.31, "width": dw, "height": dh, "rotation": 0, "zIndex": 3}}
        if inverted: s["inverted"] = True
        if extras:
            W, H = (1320, 2868) if device == "iphone" else (1080, 1920)
            s["textElements"] = [{
                "id": f"text:{device}_{i}_{j}",
                "text": {"ja": t},
                "transform": {"x": W*0.15, "y": H*0.30, "width": W*0.70, "height": H*0.05, "rotation": 0, "zIndex": 5},
                "fontSize": W*size, "fontWeight": 700, "color": "#1E6FD9", "align": "center",
            } for j, (t, size) in enumerate(extras)]
        slides.append(s)
    return slides

state = {
    "schemaVersion": 2,
    "appName": "全国ライブカメラ地図",
    "themeId": "livecam-sky",
    "connectedCanvas": False,
    "locales": ["ja"],
    "locale": "ja",
    "device": "iphone",
    "orientation": "portrait",
    "appIcon": "/app-icon.png",
    "slidesByDevice": {"iphone": build("iphone", ios_dir, "apple/iphone")},
}
if android_dir:
    state["slidesByDevice"]["android"] = build("android", android_dir, "android/phone")
    state["slidesByDevice"]["feature-graphic"] = [{
        "id": "fg_01", "layout": "feature-graphic",
        "label": {"ja": "河川・道路・防災"},
        "headline": {"ja": "全国2万台のライブカメラを地図から"},
        "screenshot": "",
    }]
with open(os.path.join(root, "app-store-screenshots.json"), "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
print("written", len(state["slidesByDevice"]["iphone"]), "iphone slides")
