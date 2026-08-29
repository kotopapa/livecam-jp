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

## Push通知の知見（2026-08-22追記）

- **新FlutterテンプレートはAPNs自動登録が効かない**。scene lifecycle構成（FlutterImplicitEngineDelegate）ではfirebase_messagingの自動処理が動かず、APNsトークンがnullのままになる。AppDelegateで`registerForRemoteNotifications()`明示呼び出し＋`didRegisterForRemoteNotificationsWithDeviceToken`で`Messaging.messaging().apnsToken`を直接設定して解決
- **FCMトピック購読の一斉送信はレート制限で静かに全滅する**。47都道府県×2系統の購読/解除を並列で投げると全て失敗する（エラーはcatchErrorで握りつぶされ見えない）。`notify_applied_warning_topics`に適用済み集合を保存し差分のみ逐次awaitする方式にした（notification_settings.dart）
- 設定画面の「通知診断」で通知許可/APNsトークン/FCMトークンを確認できる。トークンがあれば `push-test.yml` の mode=inspect で購読状況照会、mode=subscribe でサーバー側から購読登録、mode=send（token指定）で直接送信テストができる
- 通知トピック: special-warning(-XX)=特別警報レベル5 / danger-warning(-XX)=危険警報レベル4(2026新体系)。送信はtools/bosai_notify.py（同一チェック内はトピックごと1通に集約）
- 気象庁のr8警報コードは2026-05-28新体系対応済み（43大雨/44洪水/48高潮/49土砂災害の危険警報=紫表示、34洪水/39土砂災害の特別警報追加）

## Push通知の知見（2026-08-23追記）

- **r8のmap.jsonは官署×報種別(dataTypeCode)で別報が同時刻に並ぶ**（気象警報=VPWW55と土砂災害=VPWW56など）。「官署ごとに最新1報」で絞ると土砂災害報が落ちる（石垣島で実発生）。アプリ表示・bosai_notifyとも官署×報種別で最新を取り合算する
- **quake/list.jsonは同一地震(eid)が複数報並ぶ**（震度速報はanm/magが空文字列）。eidでグループ化し、震源名・Mが埋まった報を優先して1通にする
- **デバッグ版⇄TestFlight版の入替えでトピック配信だけが静かに全滅する**。FCMトークンは同じままAPNsトークンだけ差し替わり、紐付けが腐る。直接送信(token宛)は届くのにトピックは不達で、iid照会では「購読済み」に見え、batchAddやSDKの購読し直しでも直らない。完全アンインストール→再インストール(トークン再発行)でのみ復旧。対策としてhealTokenAndReapply()（起動時にAPNs/FCMトークンを前回値と比較し、APNsのみ変化ならdeleteToken→再発行→全購読作り直し）を実装済み（notification_settings.dart）
- 切り分け手順: push-test.ymlで ①mode=send token指定(直接) ②topics指定(トピック) を**別タイトルで**送り分けると経路が特定できる

## カメラ調査の知見（2026-08-25追記）

- **鳥取県防災情報ポータル(tori-bousai.jp)**は道路(雪みちナビ)266台+河川178台+県営ダム5台がS3固定URL(`tori-bousai.s3.ap-northeast-1.amazonaws.com/{yukinavi|kasen}/camera/NNN/camera.jpg`)で、座標は一覧HTMLの`data-lat/lng`とarcgis geojsonに県公式値がある。他県の防災ポータルも同型の可能性大
- **環境省 sizenken(インターネット自然研究所)の画像URLは日付入り**で固定URL扱いにすると翌日から陳腐化する（既存4件が該当）。都度解決型パーサ`sizenken`をmonitorに追加し、アプリのFeedType対応と同時に投入する（未実装。候補11件は docs/research_followups_2026-08-25.md 参照）
- **YouTubeライブIDは頻繁に切り替わる**（商店街・店舗・観光協会・自治体で多発。石垣YAEYAMA LIVEは毎日変更）。可能なら`channel_id`指定(youtube_channel型)で登録する。oEmbed 401=埋め込み不可のライブは県河川防災系に多い（和歌山県約50本・別海町北方領土カメラ等）→**埋め込み不可でもライブ中なら誘導型(feed_type: web_page, URL=watch)で登録する方針**（2026-08-25ユーザー決定・101本適用済み）。アプリはYouTube watch URLならサムネイルを自動表示する
- **画像URL直リンク禁止を明記する運営者**: 水資源機構 吉野川管理所(早明浦・池田・新宮・富郷)、中山寺。→ 既存の早明浦(camDisp11)・富郷(camDisp31)は要再確認
- 調査エージェントのWebSearchは1セッション200回上限。まとめサイト(cametan/livecam.asia/wcmap)をリンク集として一次サイトへ辿る方式が有効。Nominatimは並列調査で429になるため国土地理院AddressSearch APIを代替に使う
- Canon(`/-wvhttp-01-/GetOneShot`)・Panasonic(`/SnapshotJPEG?Resolution=`)・AXIS(`/axis-cgi/jpg/image.cgi`)のネットワークカメラ直公開は動的DNS(netvolante.jp/mydns.jp/miemasu.net)で見つかる。運営者公式ページからリンクされているもののみ採用
- **都度解決型の追加パターン（2026-08-25）**: 1台ごとに参照ページ→`kochi_suibo`/`sizenken`型（monitor/main.py ref_camsブロック）、一覧1リクエストで全台→`saitama_flood`/`takashima_river`/`higashiomi_river`/`yamaguchi_romen`型（共通ループ）、POST解決→`shimanto_kasen`。新型を足したら schema enum・monitor/check.py・**アプリの FeedType と camera_repository.imageUrlFor** の4箇所に配線（アプリ側はリリースまで「再生非対応」表示になる）
- **youtube_channel型は /live が1本にしか解決しない**ため、1チャンネルで複数拠点を同時配信する運営者(アウトバーン・高野町・RNB等)には channel_id を付けない（同じ映像になる）
- 運営者の明示的な断り（「無断転載禁止」「直接リンクはご遠慮」）があるものは技術的に取れても実装しない: ロードネット滋賀・山口県道路見えるナビ・三好市観光カメラ（取得経路は docs/research_followups_2026-08-25.md に記録済み、照会して許諾が得られれば即実装可）
- **MBC南日本放送(mbc.co.jp)は画像の無断転載・二次利用お断りを明記** → 配信URLの直接参照は不可。既存67件は個別ページ(`/web-cam/movie.html?area=<img>`)への誘導型に変更済み、mbc_webcamパーサも誘導型を出す（2026-08-25ユーザー決定）

## 定期実行の知見（2026-08-28追記）

- **GitHub Actionsのcronは間引かれ・停止することがある**（2026-08-26〜27に5分cronが数時間おきになり、最後は8時間停止。大阪の大雨危険警報の通知が遅れた）。公開リポジトリで実行枠の問題ではなく、GitHub側のスケジュール取りこぼし
- 対策として**ユーザーのGAS（Google Apps Script）から5分おきに`bosai-notify.yml`、30分おきに`monitor.yml`を`workflow_dispatch` APIで起動**している（Fine-grained PAT: livecam-jp限定・Actions Read/write）。GitHub側のcronは予備として併存。実行履歴で`workflow_dispatch`が5分ごとに並んでいれば正常。止まっていたらGASのトリガー/トークン期限(無期限設定)を疑う
- 台帳の公開(publish)は全ユーザーに1MB(gzip)の再取得を発生させるため、1日1回程度にまとめる

## カメラ調査の知見（2026-08-29追記）

- **ライブカメラDB(livecam.asia)索引経由の取込**は tools/livecamdb_index.py（索引）→ tools/livecamdb_ingest.py（一次ソース確認）→ scratchpad の build_*_yaml.py / merge.py / approve_batch.py（消えたら再作成）で流す。座標はGoogleマップ埋め込みの `!2z`（マーカー実位置）を優先、`!2d/!3d` は中心で約200mずれる
- **YouTubeチャンネルの現在ライブは `/streams` の ytInitialData から取れる**。2026-08時点で一覧は `lockupViewModel`（`contentId` + `thumbnailBadgeViewModel.badgeStyle == THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE`）に変わっており、旧 `videoRenderer` は出ない。索引由来の「チャンネルURLのみ」記録はこれで6割程度が現在の枠に解決できた。ニュース番組・院内番号案内・ペット部屋などカメラ映像でない配信が混ざるので名称/タイトルで除外する
- **埼玉県川の防災情報と和歌山県河川雨量防災は同じJWAテンプレート**（`geojson/<pref>_camera.geojson` + `chitenconfig/CameraList.csv` + 固定URL `hyoujidata/camera/<ID>.jpg`）。`crawler/sources/jwa_river_cam.py` に県設定を足すだけで他県も対応できる。埼玉はkawabou由来と同一地点が72件あり保留中（候補のnoteに「kawabou重複候補」）
- **転載禁止文言のため誘導型に切替済み**: みち情報ネットふくい（`camera.html?id=`）・ひろしま道路ナビ（`camera_detail.php?id=`）。県へ照会中（docs/inquiries_2026-08-29.md）。許諾が出たらパーサの feed_type を still_image に戻す
- 掲載元システムの利用条件・取得構造の調査結果は docs/research_2026-08-29/system_parsers_terms.md（静岡SIPOS・名古屋市は要照会、NTTルパルクは不可、山口・島根・福岡は実装可/条件付き）

## アプリの知見（2026-08-29追記）

- **Dartの `DateTime.parse` は `+09:00` 付き文字列をUTCに変換して返す**。気象庁のファイル名（JST）を組み立てるときは `.toUtc().add(9h)` で明示的にJSTへ戻す（アメダスで9時間前のデータを読んでいた）。表示も `toLocal()` ではなく明示変換にする
- 気象庁の24時間降水量タイル(rasrf24h)の配色しきい値は 〜50/50/80/100/150/200/250/300mm（1時間雨量の 10/20/50/80… とは別）。凡例・ラベル色はタイル画素とアメダス実測値で照合済み
- quake/list.json の「顕著な地震の震源要素更新」報は cod が度分形式（`+3559.9+14005.7`）。同一eidの複数報は震度が空の報が混ざるので、値の埋まっている項目を合成し最大震度を採る（`JmaLayers.mergeQuakeReports`）
