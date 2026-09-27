# Googleマップ化（flutter_map → google_maps_flutter）移行計画

2026-09-27 ユーザー決定: 地図画面のベース地図を Google マップにする（地理院淡色地図は「使い慣れない・見にくい」）。
今昔マップの縦線スワイプ比較は **地図を2枚重ねて同期する方式で維持**。1.6.0 として配信する（地図UI再設計と同時）。

## 料金・規約（2026-09 時点）
- Maps SDK for iOS / Android の地図表示（Dynamic Maps, mobile native）は無料・回数無制限。請求先アカウント（カード）は必須
- 他の Google API（Places / Geocoding 等）は使わない（地名検索は国土地理院・ORS のまま）
- 気象庁・ハザードマップ・今昔マップ・自前データを TileOverlay / Marker / Polyline で重ねるのは規約上可。Google ロゴ・帰属は SDK が表示する
- プライバシーポリシー・App Store「アプリのプライバシー」に Google Maps Platform（端末情報・位置情報）を追記する

## API キーの扱い（ソースに直書きしない）
- 控え: `app/secrets/google_maps.env`（gitignore。`GOOGLE_MAPS_API_KEY_IOS` / `GOOGLE_MAPS_API_KEY_ANDROID`）
- iOS: `app/ios/Flutter/Secrets.xcconfig`（gitignore）に `GOOGLE_MAPS_API_KEY = ...`。`Debug.xcconfig` / `Release.xcconfig` から `#include? "Secrets.xcconfig"`。`Info.plist` に `GMSApiKey = $(GOOGLE_MAPS_API_KEY)`。`AppDelegate.swift` が Info.plist から読んで `GMSServices.provideAPIKey`
- Android: `app/android/secrets.properties`（gitignore）に `GOOGLE_MAPS_API_KEY=...`。`app/build.gradle.kts` で読み `manifestPlaceholders["googleMapsApiKey"]`。`AndroidManifest.xml` の `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}"/>`
- キーはバンドルID / パッケージ名＋SHA-1（Play署名鍵・アップロード鍵・デバッグ鍵）で制限済み。CI（GitHub Actions）はアプリをビルドしないのでキー不要

## パッケージ
- `google_maps_flutter: ^2.18.2`、`google_maps_flutter_ios_sdk10: ^2.19.0`（SwiftPM 対応。既定の `google_maps_flutter_ios` は SwiftPM 非対応）。iOS 最低 16（プロジェクトは 17）、Android minSdk 24（プロジェクトは 26）
- `flutter_map` / `latlong2` は詳細画面の小地図（`detail_screen.dart`）でしばらく残す。地図画面の座標型は latlong2 の `LatLng` を内部で使い続け、境界で `gmaps.LatLng` に変換する（`lib/data/*` の型を変えない）

## 対応表（map_screen.dart）
| flutter_map | google_maps_flutter |
| --- | --- |
| `FlutterMap` + `MapOptions` | `GoogleMap(initialCameraPosition, onMapCreated, onCameraMove, onCameraIdle, minMaxZoomPreference, rotateGesturesEnabled:false, myLocationEnabled, myLocationButtonEnabled:false, zoomControlsEnabled:false, mapToolbarEnabled:false, compassEnabled:false)` |
| `MapController.move / fitCamera` | `GoogleMapController.animateCamera(CameraUpdate.newLatLngZoom / newLatLngBounds)` |
| `onPositionChanged(camera, hasGesture)` | `onCameraMove(CameraPosition)`（毎フレーム。setState は状態が変わった1回だけ）＋ `onCameraMoveStarted`（hasGesture 相当）|
| `onMapEvent(MoveEnd 等)` | `onCameraIdle`（可視領域は `controller.getVisibleRegion()` で取り直す）|
| `TileLayer`（気象庁・ハザード・積雪・今昔マップ）| `TileOverlay(tileProvider: <Dart の TileProvider>, transparency, zIndex)`。偶数ズーム対策は `EvenZoomTileProvider` のロジックを `getTile(x, y, zoom)` に移植（奇数ズームは親タイルを切り出して拡大、PNG にエンコードして返す）。時刻更新は `tileOverlayId` を変えず `controller.clearTileCache(id)` |
| `MarkerLayer`（カメラ・クラスタ・避難場所・防災拠点・冠水・震源・台風の点）| `Marker(icon: BitmapDescriptor)`。ピンは `CameraPin` と同じ見た目を Canvas で描いた PNG（カテゴリ×動画×お気に入り×未確定×凍結×選択の組合せをキャッシュ、devicePixelRatio 倍で描く）。クラスタは件数ごとに生成してキャッシュ。タップは `onTap` |
| `PolylineLayer` / `CircleLayer` / `PolygonLayer` | `Polyline` / `Circle` / `Polygon` |
| `_cullToViewport`（可視領域の間引き）| `onCameraIdle` で `getVisibleRegion()` を取り `LatLngBounds` で間引く |
| 現在地ドット | `myLocationEnabled: true`（位置権限があるとき）。追従は既存ロジック |
| 今昔マップの縦線／横線スワイプ | **GoogleMap を2枚重ねる**: 下=今の地図、上=今昔マップ TileOverlay 付きの GoogleMap を `ClipRect(_SplitClipper)` で切り抜き、上の地図は操作不可（`IgnorePointer`）にして下の地図の `onCameraMove` で `moveCamera` を同期。透過モードは1枚で `transparency` |
| 出典 | Google ロゴは SDK。出典帯には気象庁・ハザード・今昔マップだけを出し「地理院タイル」の文言は外す（詳細画面の小地図には残す）|

## 段階
1. **基盤＋ベース地図＋カメラピン**: パッケージ・キー配線・`GoogleMap` への置換・カメラ移動・可視領域・カメラピン/クラスタ（画像化）・現在地・ズーム/現在地ボタン・下部パネル。他のレイヤーは一旦コンパイルが通る形で無効化（TODO を残す）
2. **タイル系レイヤー**: 雨雲・24時間降水・キキクル・積雪・ハザードマップ・今昔マップ（2枚重ね）。時刻更新・偶数ズーム
3. **ベクタ系レイヤー**: 台風・震源・通行止め/冠水・避難場所・防災拠点・ルート沿い
4. **仕上げ**: テスト（`GoogleMap` はウィジェットテストで platform view のスタブ。地図画面を組むテストはモック化）、プライバシーポリシー、CLAUDE.md、リリースノート
