# livecam-jp 開発メモ（Claude Code用）

まず [SPEC.md](SPEC.md) を読むこと。特に:
- **2章 絶対制約**（C1〜C6）と **10章 判断ルール** は毎回確認。レート制限の緩和・cameras.jsonへの自動承認・画像の自前中継は禁止
- カメラの採用は必ず `tools/review_cli.py` の人手レビュー経由

## コマンド

```bash
python -m pytest crawler/tests monitor/tests tools/tests   # テスト
python -m crawler.main --all --dry-run          # クロール（書き込みなし）
python -m crawler.main --all --no-verify --no-geocode --limit 5  # 高速動作確認
python -m monitor.main                          # 死活監視
python site/build.py                            # 配信ファイル生成
```

## 実装上の知見（2026-08-17時点）

- **国交省の河川カメラは「川の防災情報」(river.go.jp) に集約されている**。整備局の事務所ページは kawabou へのリンク集で、URLに `scamId` が入っている。`crawler/sources/kawabou.py` がこの公開JSON（`/kawabou/file/files/master/obs/scam/<id>.json`）を解決し、正確な緯度経度と静止画URL（`cam.river.go.jp/cam/now/*.jpg`）を得る。SPAの内部ファイルなので構造変化に注意（フィクスチャ: `crawler/tests/fixtures/`）
- kawabou の prefCd は独自形式（101〜4701。北海道は101〜105に分割）。JIS変換は `kawabou.pref_jis()` / `municipality_jis()`
- 官公庁サイトは中間証明書が不完全なことがある → `truststore.inject_into_ssl()` をエントリポイントで実行済み
- **cam.river.go.jp は存在しない/休止中カメラにも HTTP 200 でプレースホルダPNGを返す**。ステータスコードでは死活を検知できないため、既知プレースホルダのdHash（`monitor/freeze.py` の PLACEHOLDER_HASHES）で判定する。新種のプレースホルダを見つけたらハッシュを追記すること
- kawabou には自治体設置カメラも混ざる（ownName が「神奈川県」等）。SPEC 3.3 に従い license=unknown で手動レビュー行きにしている
- kawabou 静止画の更新間隔は10分前後。クローラの2回取得検証（300秒間隔）では「画像が同一」の検証NG注記が付きやすいが、多くは正常。レビュー時にプレビューで判断する
- パーサを追加したら `crawler/sources/__init__.py` の REGISTRY と `crawler/seeds.yaml` に登録し、フィクスチャ+テストを必ず追加
- **data/cameras.json をスクリプトで直接編集したら、トップレベルの `version` を必ず現在UTCに更新すること**。アプリは manifest の cameras.version が変わったときだけ再取得するため、忘れると配信されない（2026-08-19のHBC座標修正で実際に発生）
- HBC情報カメラの座標はGoogleマップ埋め込みの `!2z`（base64のDMS、マーカー実位置）を使う。`!2d/!3d` はビューポート中心で海上にずれることがある（`crawler/sources/hbc_webcam.py`）

## iOSビルドの知見（2026-08-20追記）

- **`flutter pub get` を実行すると `app/ios/Flutter/ephemeral/.../FlutterGeneratedPluginSwiftPackage/Package.swift` の platforms が `.iOS("13.0")` にリセットされる**（Flutter 3.44系の挙動）。Firebase系SwiftPMパッケージはiOS 15.0必須のため、そのままXcodeビルドすると「requires minimum platform version 15.0」エラーになる。`flutter build ios --config-only` だけがプロジェクトの17.0を反映する。**対策としてRunner.xcschemeのビルド前スクリプトにsedによる自動修正を組み込み済み**（xcode_backend.sh prepare の直後）。pub get / pub add / flutter test を実行した後は `flutter build ios --config-only` を実行しておくと安全

## 道路カメラの知見（2026-08-18追記）

- **国交省の道路カメラは「道路情報提供システム」(road-info-prvs.mlit.go.jp) に集約されている**（道路版kawabou）。`pcImage_<整備局CD>_1.html` の hidden input `kokudoJson` に正確な座標・JIS市区町村コード付きの全カメラJSONが埋め込まれている（CD: 81=北海道〜90=沖縄）。パーサ: `crawler/sources/mlit_roadinfo.py`
- **prvsの静止画は固定URLがない**（15分刻みタイムスタンプ・直近3世代）。feed.type=`mlit_roadinfo`（都度解決型）とし、monitorが毎回最新URLを解決して status.json の `image_url` で配信する。アプリはそれを読む
- prvsの欠測プレースホルダ no_data.jpeg のdHashは `monitor/freeze.py` に登録済み
- 関東(83)・北陸(84)・中部(85)は事務所サイト直のパーサ（固定URL・mlit_ktr_road / mlit_hrr_road / mlit_cbr_road）を優先。prvs側CDは重複回避のため対象外にしている
- 中国地整の道路ポータル www.road.cgr.mlit.go.jp は **robots.txt が Disallow: / のためクロール禁止**（prvs経由で取得する）
