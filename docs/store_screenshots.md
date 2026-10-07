# ストア用スクリーンショットの作り方（2026-09-17）

App Store / Google Play に載せる宣伝用スクリーンショットの作成手順。
「実機キャプチャ（デバッグリボン・広告なし）」→「エディタで文言・端末フレームを付けて書き出し」の2段階。

## 1. 実機キャプチャ（自動巡回）

**アプリ本体には撮影用のコードを残していない**（リリースに影響させないため）。撮影に必要なものは
`tools/screenshot_capture/` にまとめてあり、撮るときだけ当てて、終わったら戻す。

- `screenshot_mode.patch`: `config.dart` に `screenshotMode`（`--dart-define=SCREENSHOT_MODE=true`）を足し、
  デバッグリボン・AdMob バナー／レクタングル・ATT ダイアログ・一覧タブ起動時の位置情報許可要求を止める。
  pubspec に dev 依存 `integration_test` を足す。**コードが変わって `git apply` が失敗したら、同じ内容を手で入れてから
  `git diff -- app/lib app/pubspec.yaml > tools/screenshot_capture/screenshot_mode.patch` で作り直す**（2026-10-07 に作り直し済み）
- `integration_test/screenshots_test.dart`: 地図・詳細・レイヤー・各タブを順に開き、撮りたい場面で `debugPrint('SNAP <名前>')` を出す。
  Google マップは platform view なので `binding.takeScreenshot()` には映らない。**合図を見て外から `xcrun simctl io <udid> screenshot` で撮る**
- `run_capture.sh <udid> <出力dir> [maps|details|tabs|header|all]`: `flutter drive` の出力から `SNAP` 行を拾って simctl で撮る
- `test_driver/integration_test.dart`: 結果を受け取るだけ（撮影はしない）
- `CAPTURE_SET=maps|details|tabs` で組を絞れる（Android は25枚まとめると VM Service が落ちるので分割必須）。`header` はヘッダ画像用の候補
  （東京都心の `map_tokyo_pins_cand1〜4`）だけを撮る
- 地図の移動は `GoogleMapsFlutterPlatform.instance.moveCamera`（mapId は 0 から試して通ったものを使う）。アプリ側の操作扱いになるので、
  動かすたびに下部シートが畳まれ「いま起きていること」カードが閉じる。レイヤー選択前は `map_sheet_handle` で開き直す。起動時のお知らせ帯は×で消す
- 地図を動かしたあとはタイルとピンの描画に 6〜8 秒待つ（待ち時間は `wait`。足りなければ増やす）

```bash
# 当てる
git apply tools/screenshot_capture/screenshot_mode.patch
cp -R tools/screenshot_capture/integration_test tools/screenshot_capture/test_driver app/
cd app && flutter pub get
# …撮影（下記）…
# 戻す
cd .. && git checkout -- app/lib app/pubspec.yaml app/pubspec.lock
rm -rf app/integration_test app/test_driver
cd app && flutter pub get && flutter build ios --config-only
xcrun simctl status_bar <udid> clear && xcrun simctl location <udid> clear
```

### iOS（iPhone 17 シミュレータ・1206×2622）

**一度も `flutter run` していないシミュレータを使う**（ATT・位置情報の許可ダイアログが出た機体は初回フレームが描画されない。
その場合は `xcrun simctl erase <udid>`）。

```bash
SIM=<simulator udid>   # xcrun simctl list devices available
xcrun simctl boot $SIM
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""
xcrun simctl location $SIM set 35.681,139.767
tools/screenshot_capture/run_capture.sh $SIM "$PWD/app/store_assets/captures/ios" all   # maps / details / tabs / header も可
```

### Android（Pixel 8 エミュレータ・1080×2400）

注: 下のコマンドは Google マップ化前の `takeScreenshot` 方式のまま（2026-10-07 時点で未更新）。Android で撮る場合は
`CAPTURE_VIA=adb` 相当の合図方式（`SNAP` 行を見て `adb exec-out screencap -p`）に `run_capture.sh` を直す必要がある。

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

撮れる画面（2026-10-07 の再撮影で全て確認。ヘッダ用の map_tokyo_pins_current は header の候補から選んで保存する。map_tokyo_pins_clean・map_tokyo_clean は廃止）: map_japan / map_tokyo / map_tokyo_pins / map_fuji / detail_kawaguchiko / detail_fuji / detail_oshino / detail_river / detail_coast / detail_live / detail_tokyotower / detail_sakurajima /
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

## iPhone Duo（折りたたみ iPhone）用（2026-10 追加）

Apple の新しい端末区分。2026-10-23 発売（iOS 27.1）。**2027年4月からスクリーンショットが必須**になる。

| ディスプレイ | 画面 | 提出サイズ（縦） |
|---|---|---|
| 内側 7.6インチ | 669×951pt @3x | 2007×2853（横 2853×2007） |
| 外側 5.4インチ | 466×678pt @3x | 1398×2034（横 2034×1398） |

縦横比はどちらも約1.42（iPhone の約2.16よりかなり横長）。PNG/JPEG・アルファ不可・1〜10枚。ストア用は縦向きのみ作る。

### 撮影

- **Xcode 27.1 以降と iOS 27.1 ランタイムが要る**（2026-10-07 時点でこの Mac は Xcode 27.0 のため未導入）。Xcode 27.1 を入れたら Device Hub（Window → Devices and Simulators）の「Simulators」から iPhone Duo を追加し、iOS 27.1 ランタイムを入れる
- 確認: `xcrun simctl list devicetypes | grep Duo`、`xcrun simctl list devices available | grep Duo` で udid を得る
- 手順は iOS と同じ（上の「1. 実機キャプチャ」）。`tools/screenshot_capture/` のパッチと integration_test を当て、`SIM=<Duo の udid>` で `CAPTURE_DIR=store_assets/captures/ios-duo flutter drive …` を回す。`CAPTURE_VIA=simctl` は使えない点も同じ
- **内側ディスプレイ（開いた状態、2007×2853）で撮る**。外側用は書き出し時に内側画像から縮小して作る（縦横比が同じなので比率は崩れない）。Duo のシミュレータで内側が選べない場合は、折りたたみ状態の切替（Simulator の Device メニュー）を開いた状態にする
- 一度 ATT・位置情報の許可ダイアログを出したシミュレータは初回フレームが描画されないので、`SCREENSHOT_MODE=true` の版だけを起動する（iOS の注意と同じ）
- 撮れた PNG は `app/store_assets/captures/ios-duo/` に置き、エディタ用に `store_screenshots/public/screenshots/apple/iphone-duo/ja/` へコピーする。ファイル名は iPhone と同じ（`01_detail_river.png` など。`app-store-screenshots.json` の `slidesByDevice.iphone-duo` が参照している）。**画像が無いうちは枠の中に「Drop a screenshot here」が出るだけで落ちない**

### エディタと書き出し

- ツールバーの端末選択に「iPhone Duo」がある（iOS タブ）。キャンバスは内側 2007×2853。端末枠は PNG モックではなく CSS の角丸矩形（画面比 669:951＋画面幅2%のベゼル。`device-frames.tsx` の `IPhoneDuo`、定数は `constants.ts` の `DUO_*`）
- 8枚の構成と文言は iPhone 版を写してある。縦横比が違うので x・幅は 2007/1320 倍、文字は 0.8 倍で換算した初期値。**強調語（「川」「地図」など）の位置は自動追従しないので、画像を入れてから目視で合わせ直す**
- 「Export bundle」で内側 2007×2853 と外側 1398×2034 の2サイズが zip に入る。ヘッドレスは `node tools/export.mjs /tmp/export_duo.zip --device=iphone-duo`（JSON の device を一時的に書き換えて元に戻す。Android も `--device=android` で同様）
- 出力先: `app/store_assets/ios/screenshots/2007x2853/ja/` と `app/store_assets/ios/screenshots/1398x2034/ja/`（zip 内は `ios/iphone-duo/<WxH>/ja/NN-layout.png`。iPhone の同名ファイルと混ざらないよう、取り出すときに端末区分のフォルダ名を除く）

## ヘッダ・検索結果（iOS 27 の App Store、2026-10-07）

- App Store Connect「ヘッダと検索結果」用の画像。素案は `store_screenshots/header_assets/DESIGN_HEADER.md`（Codex）、原稿は `header.html`/`header.js`（site/lp/data.json の実在カメラ位置を光点で描く）、再生成は `cd store_screenshots && node header_assets/render.mjs`
- 提出用は `app/store_assets/ios/product_page/`: 汎用 `generic_5244x2950.png`（ヘッダと検索結果を兼ねる。PNG・アルファ無し）、ヘッダ専用 `header_3840x1646.png`、検索結果用 `search_3840x2560.png`（3:2）
- 価格・「無料」・URL・©・受賞・他ストアのロゴ・Apple のバッジは入れない。重要な要素は中央のセーフエリア（上下13%・左右12%が切られても残る範囲）に置く。提出前に ASC のプレビューで 21:9 と 3:2 の見え方を確認する
