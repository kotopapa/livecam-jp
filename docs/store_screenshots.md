# ストア用スクリーンショットの作り方（2026-09-17）

App Store / Google Play に載せる宣伝用スクリーンショットの作成手順。
「実機キャプチャ（デバッグリボン・広告なし）」→「エディタで文言・端末フレームを付けて書き出し」の2段階。

## 1. 実機キャプチャ（自動巡回）

**アプリ本体には撮影用のコードを残していない**（リリースに影響させないため）。撮影に必要なものは
`tools/screenshot_capture/` にまとめてあり、撮るときだけ当てて、終わったら戻す。

- `screenshot_mode.patch`: `config.dart` に `screenshotMode`（`--dart-define=SCREENSHOT_MODE=true`）を足し、
  デバッグリボン・AdMob バナー／レクタングル・ATT ダイアログ・一覧タブ起動時の位置情報許可要求を止める。
  pubspec に dev 依存 `integration_test` を足す
- `integration_test/screenshots_test.dart`: 地図・詳細・レイヤー・各タブを順に開いて `binding.takeScreenshot()`
- `test_driver/integration_test.dart`: 受け取った PNG を `CAPTURE_DIR` に `<name>.png` で保存
- `--dart-define=CAPTURE_SET=maps|details|tabs` で組を絞れる（Android は25枚まとめると VM Service が落ちるので分割必須）

```bash
# 当てる
git apply tools/screenshot_capture/screenshot_mode.patch
cp -R tools/screenshot_capture/integration_test tools/screenshot_capture/test_driver app/
cd app && flutter pub get
# …撮影（下記）…
# 戻す
cd .. && git checkout -- app/lib/config.dart app/lib/main.dart app/lib/ui/ad_banner.dart app/lib/ui/list_screen.dart app/pubspec.yaml app/pubspec.lock
rm -rf app/integration_test app/test_driver
cd app && flutter pub get && flutter build ios --config-only
xcrun simctl status_bar <udid> clear && xcrun simctl location <udid> clear
```

### iOS（iPhone 17 シミュレータ・1206×2622）

```bash
cd app
SIM=<simulator udid>   # xcrun simctl list devices available
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""
xcrun simctl location $SIM set 35.681,139.767
CAPTURE_DIR=store_assets/captures/ios flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d $SIM --dart-define=SCREENSHOT_MODE=true
```

### Android（Pixel 8 エミュレータ・1080×2400）

```bash
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
for set in details maps tabs; do
  CAPTURE_DIR=store_assets/captures/android flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart \
    -d emulator-5554 --dart-define=SCREENSHOT_MODE=true --dart-define=CAPTURE_SET=$set
done
```

撮れる画面（29枚）: map_japan / map_tokyo / map_tokyo_pins / map_tokyo_pins_clean・map_tokyo_clean（「いま起きていること」カードを閉じた状態）/
map_fuji / detail_kawaguchiko / detail_fuji / detail_oshino / detail_river / detail_coast / detail_live / detail_tokyotower / detail_sakurajima /
layer_rain_radar / layer_rain_radar_kanto /
layer_kikikuru_land / layer_kikikuru_inund / layer_typhoon / layer_shelters / layer_hazard_flood /
list / ranking / bosai_quake / bosai_warning / bosai_heat / x_accounts / stockpile / settings

注意: カメラ画像は撮影時刻の実写なので、日中（9〜15時）に撮ると見栄えがよい。台風・洪水予報・地震は発表中のものがそのまま写る。

## 2. エディタで仕上げ・書き出し

`store_screenshots/` は ParthJadhav/app-store-screenshots のテンプレート（Next.js）。

```bash
cd store_screenshots
npm install --legacy-peer-deps   # 初回のみ（react 19 RC と @dnd-kit の peer 依存で --legacy-peer-deps が必要）
npm run dev                      # http://localhost:3000
```

- 文言・構成・端末の位置は `app-store-screenshots.json`（自動保存・git 管理）。ロケールは `ja` のみ
- 元画像は `public/screenshots/apple/iphone/ja/`・`public/screenshots/android/phone/ja/`（キャプチャからコピー）
- フォントは Noto Sans JP（`src/app/layout.tsx`）、テーマ `livecam-sky`（`src/lib/constants.ts`。ブランド色 #1E6FD9）
- 「Export bundle」で iPhone 4サイズ（6.9/6.5/6.3/6.1インチ）× ja の zip が落ちる。Android に切り替えて同様に書き出す
- 書き出し済み PNG は `app/store_assets/ios/screenshots/<WxH>/ja/` と `app/store_assets/android/screenshots/1080x1920/ja/`

### デザイン素案（Codex 作成・2026-09-17、同日「もっとリッチに」で改訂）

- 改訂版は多段グラデーション＋等高線の背景、端末の傾き（3〜7度）と二重の影、1枚目の大きな「2万台以上」、
  3・6枚目の濃紺反転、8枚目の「見る。備える。旅する。」の機能の壁。背景8種は `src/lib/constants.ts` の `LIVECAM_SURFACES`、
  装飾（等高線・下線・チップ・影）は `slide-canvas.tsx` に追加。粒子は `globals.css`
- 元画像は 2026-09-17 07:50 頃の撮り直し（関東は曇天のため川・東京タワーは灰色。富士山は 07:04 の晴れ間の版 `detail_fuji_0704.png` を使用）。
  晴れた日に詳細画面だけ撮り直して `public/screenshots/*/ja/01_detail_river.png` 等を差し替えると見栄えが上がる

- 素案は [store_screenshots/DESIGN.md](../store_screenshots/DESIGN.md)（コンセプト・8枚のコピー・タイポグラフィ・配色・座標・見送り案）。
  Codex CLI（ChatGPT.app 同梱 `/Applications/ChatGPT.app/Contents/Resources/codex`）に `codex exec -C store_screenshots -s workspace-write` で
  書き出し画像を添付して依頼し、JSON と `slide-canvas.tsx`（見出し 144px/900・行高1.2、ラベル 48px）へ反映させた
- 強調語は `textElements` で見出しの同じ位置に1語だけ青で重ねている。**コピーや caption 位置を変えたら強調語の位置も直す**（自動追従しない）
- 構成（8枚）: ①川の実写「近くの川を、家から確認。」②地図「いつもの道も、地図でひと目。」③台風レイヤー（濃紺）「台風の進路をわが家の目線で。」
  ④災害速報「地震も警報も通知で気づく。」⑤避難場所＋ハザードマップ（2台）「家族と決める避難先。」⑥ランキング（濃紺）「みんなが見てる今の注目地点。」
  ⑦備え「備蓄の期限、忘れる前に。」⑧富士山＋海岸（2台）「近所も、旅先も。今を見に行こう。」

### ヘッドレス書き出し（ブラウザ操作なし）

```bash
cd store_screenshots
npm run dev &                                # エディタを起動しておく
node tools/export.mjs /tmp/export_ios.zip    # 「Export bundle」を押して zip を保存（Playwright）
node tools/shot.mjs /tmp/editor.png          # エディタ画面の確認用キャプチャ
```

Android を書き出すときは `app-store-screenshots.json` の `"device"` を `"android"` にしてから実行し、終わったら `"iphone"` に戻す。
`tools/seed_deck.py` はキャプチャから初期 JSON を作る雛形（現在の JSON は Codex 版なので通常は使わない）。
