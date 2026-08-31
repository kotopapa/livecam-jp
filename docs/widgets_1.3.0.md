# iOSホーム画面ウィジェット（1.3.0）

1.3.0 の目玉機能として WidgetKit のウィジェットを2種類追加した。Flutter本体は
`home_widget` パッケージで App Group にJSONを書き、`WidgetCenter.reloadTimelines`
を呼ぶだけ。表示・取得は Widget Extension（Swift/SwiftUI）が単独で行う。

| ウィジェット | kind | サイズ | 更新 | データ源 |
|---|---|---|---|---|
| お気に入りカメラ | `FavoriteCamerasWidget` | small(1台) / medium(2台) / large(4台) | 15分 | App Group の `favorites_widget_json`（本体が書く）→ 画像は一次ソースから直接取得（C1） |
| 災害速報 | `BosaiWidget` | small / medium / accessoryRectangular(ロック画面) | 10分 | 気象庁 `r8/map.json` と `quake/list.json` を拡張が直接取得。対象都道府県は App Group の `bosai_widget_settings_json` |

## 構成

```
app/lib/data/widget_bridge.dart      Flutter側。JSON生成(純粋関数)・URLスキーム解析・home_widget呼び出し
app/lib/app_state.dart               syncWidgets(): お気に入り変更/起動/復帰/台帳更新のたびに書き出し
app/lib/main.dart                    _hookWidgetLinks(): ウィジェット起動URL → navigationRequest
app/lib/ui/home_shell.dart           'camera/<id>' 要求でカメラ詳細を開く（台帳未読込なら読込後に開く）
app/lib/data/notification_settings.dart  対象都道府県を変えたら災害速報ウィジェットにも反映
app/ios/LiveCamWidget/               Widget Extension ターゲット（bundle id: jp.livecam.livecamJp.LiveCamWidget）
  LiveCamWidgetBundle.swift          @main WidgetBundle
  SharedStore.swift                  App Group の UserDefaults / キャッシュ置き場 / ディープリンクURL
  ImageLoader.swift                  URLSession取得 + ImageIOダウンサンプリング（メモリ上限対策）+ 前回画像キャッシュ
  JmaClient.swift                    気象庁JSONの解釈（bosai_screen.dart の移植）
  FavoriteCamerasWidget.swift        お気に入りカメラ
  BosaiWidget.swift                  災害速報
  Info.plist / LiveCamWidget.entitlements / Assets.xcassets
app/ios/Runner/Info.plist            CFBundleURLTypes (livecamjp://)
app/ios/Runner/Runner.entitlements   App Groups
app/test/widget_bridge_test.dart     JSON生成・URL解析のテスト
```

App Group ID: `group.jp.livecam.livecamJp`（Runner と LiveCamWidget の両方の entitlements に設定済み）

### ディープリンク

ウィジェットタップで `livecamjp://camera/<id>?homeWidget` / `livecamjp://bosai?homeWidget` /
`livecamjp://map?homeWidget` を開く。`?homeWidget` は home_widget プラグインが「自分宛のURL」と
判別する目印で、**省略するとFlutter側に届かない**。Flutter側は `parseWidgetDeepLink()` で
`camera/<id>` / `bosai` / `map` に変換し、プッシュ通知タップと同じ `AppState.navigationRequest`
に流す。

### 共有JSONの形

```json
// favorites_widget_json（登録が新しい順。最大8台）
{"generated_at":"2026-08-31T03:04:05.000Z",
 "cameras":[{"id":"...","name":"...","image_url":"http://...","category":"river",
             "prefecture":"13","operator":"...","updated_at":null,"headers":{"Referer":"..."}}]}
// bosai_widget_settings_json（空=全国。通知設定の対象都道府県と同じ）
{"prefs":["16","17"]}
```

`image_url` は静止画=feed.url、都度解決型=status.json の image_url、YouTube系=
`https://i.ytimg.com/vi/<id>/hqdefault.jpg`（映像そのものはIFrame経由のみ=C6）。
youtube_channel 型と画像が取れない型は null → プレースホルダ表示。

## Xcode側で人手が必要な作業

Extension ターゲットは `xcodeproj` gem で project.pbxproj に追加済み（Debug/Release/Profile、
Flutterのxcconfigをベースにしているためバージョンは `FLUTTER_BUILD_NAME/NUMBER` に追従する）。
残りは Apple Developer / Xcode の署名周りのみ:

1. **Apple Developer で App Group を有効化**
   - Certificates, Identifiers & Profiles → Identifiers → App Groups → `group.jp.livecam.livecamJp` を作成
   - App ID `jp.livecam.livecamJp` の Capabilities に App Groups を追加し、上記グループにチェック
   - App ID `jp.livecam.livecamJp.LiveCamWidget` を新規作成（Explicit）。Capabilities: App Groups（同グループ）
2. **Xcode で署名を確認**（Runner.xcworkspace を開く）
   - Runner ターゲット → Signing & Capabilities → App Groups に `group.jp.livecam.livecamJp` が出て赤エラーが無いこと
     （Automatic signing なら Xcode がプロファイルを再生成する。「Provisioning profile doesn't include the App Groups entitlement」が出たら Developer サイト側 1. が未完了）
   - LiveCamWidget ターゲット → Signing & Capabilities → Team `G2B7APMJ6L` / Automatic。App Groups が同じグループであること
   - 既存の手動プロファイルを使っている場合は、Runner用プロファイルを App Groups 込みで再発行し、LiveCamWidget 用プロファイルを新規発行する
3. **Archive にExtensionが含まれることの確認**
   - Product → Archive → Organizer で右クリック「Show in Finder」→ パッケージ内容 `Products/Applications/Runner.app/PlugIns/LiveCamWidget.appex` があること
   - Runner の Build Phases に「Embed Foundation Extensions」（Embed Frameworks の直後）があり、LiveCamWidget.appex が入っていること
   - App Store Connect へアップロード時、Extension の `CFBundleShortVersionString`/`CFBundleVersion` が本体と一致している必要がある（xcconfig 経由で自動一致）
4. **`flutter pub get` 後は `flutter build ios --config-only`**（CLAUDE.md「iOSビルドの知見」）。Extension自体は SwiftPM を使わないので影響しないが、本体の Package.swift platforms が 13.0 に戻る件は従来どおり

## 動作確認手順

### ビルド
```bash
cd app
flutter pub get && flutter build ios --config-only
dart analyze lib test && flutter test
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### 実機/シミュレータ
1. アプリを起動し、地図または一覧からカメラを2〜4台お気に入り登録する（登録時点で App Group に書き出し＋reloadTimelines）
2. ホーム画面長押し → 「+」→「全国ライブカメラ地図」→「お気に入りカメラ」を small/medium/large で追加
   - 画像と「取得 HH:mm」が出る。お気に入り未登録なら「アプリでお気に入りを登録してください」
   - タップ → 該当カメラの詳細画面が開く（終了状態からの起動でも台帳読込後に開く）
3. 「災害速報」を small/medium で追加。ロック画面のカスタマイズからも追加できる（accessoryRectangular）
   - 発表が無い時期は「発表なし」＋更新時刻＋「出典: 気象庁」
   - 設定 → 災害通知 → 対象都道府県を変更すると、medium の見出しに「（対象N都道府県）」が付き、その都道府県だけに絞られる
   - タップ → 災害速報タブ
4. 更新確認: Xcode の Debug → 「Attach to Process by PID or Name」で `LiveCamWidget` にアタッチすると getTimeline のログが取れる。
   手動で更新したい場合はアプリを一度前面に出す（resumed で syncWidgets → reloadTimelines）
5. 取得失敗のフォールバック: 機内モードでウィジェットを追加 → お気に入りは前回画像（無ければ「画像を取得できません」）、災害速報は前回スナップショット＋「（取得失敗）」

### Xcode プレビュー用の擬似データ
ギャラリーのプレビュー（`context.isPreview`）はネットワークを使わず固定サンプル（サンプルカメラ / 富山県 大雨特別警報）を表示する。

## 注意点

- **メモリ上限**: Widget Extension は約30MBで強制終了される。画像は `CGImageSourceCreateThumbnailAtIndex` で
  最大480px（large は400px）に縮小してから UIImage にし、逐次取得（同時1本）にしている。カメラ台数や解像度を増やすときはここを守る
- **一次ソースへの負荷（C3）**: お気に入りは15分に1回・1台1リクエスト、気象庁は10分に1回・2リクエスト。
  `TimelineReloadPolicy.after` は iOS 側で間引かれるため実際はこれより疎になる。短くしないこと
- **画像URLの陳腐化**: 都度解決型（mlit_roadinfo 等）の `image_url` は status.json 由来で、本体アプリが
  起動/復帰したときにしか書き換わらない。長時間アプリを開かないと古いURLのままになる（取得失敗→前回画像）。
  ウィジェットに直接 status.json を引かせる案は 1MB 級のダウンロードになるため見送り
- **Referer 必須カメラ**: `feed.requires_referer` のカメラは `headers.Referer=出典ページ` を JSON に載せ、Extension が付与する
- **home_widget と URL**: `HomeWidget.setAppGroupId` を呼ぶ前に `initiallyLaunchedFromHomeWidget` を呼ぶとエラーになる
  （`WidgetBridge.init` が順序を保証）。Android には未対応（`WidgetBridge.supported` が iOS のみ true）
- **警報コード**: 2026-05-28 新体系（危険警報 43/44/48/49、特別警報 34/39 追加）を `JmaClient.warningNames` に
  持つ。本体 `bosai_screen.dart` の `_warningNames` を変えたら Swift 側も揃えること
- **pbxproj**: 「Embed Foundation Extensions」は「Embed Frameworks」の直後に置く必要がある。末尾（Thin Binary/Crashlytics スクリプトの後）に置くと
  `Cycle inside Runner` でビルドが失敗する
