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

- **Firebase 系パッケージ（firebase_core / messaging / crashlytics / analytics）は必ず一緒に上げる**。1つだけ `pub add` すると firebase_core だけ新しくなり、SwiftPM が「firebase-ios-sdk 12.18.0 と 12.17.0 が競合」で解決できず `flutter build ios --config-only` が失敗する（2026-09-07 firebase_analytics 追加時に発生）。`flutter pub upgrade firebase_core firebase_messaging firebase_crashlytics firebase_analytics` で揃える
- 利用状況の集計は Firebase Analytics（`app/lib/data/analytics.dart`）。名前付きルートを使っていないので各画面の initState から `Analytics.screen()` を明示的に呼ぶ。デバッグビルドは収集しない。プライバシーポリシー 3-4 に記載済み。App Store Connect の「アプリのプライバシー」に「製品の操作」「デバイスID」の申告が必要
- **バージョンを上げたら必ず `flutter build ios --config-only` を実行する**。Xcode は `ios/Flutter/Generated.xcconfig` の FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER を使うため、pubspec だけ書き換えてアーカイブすると前のバージョン番号で出る（2026-09-08 に 1.4.4 が 1.4.3 としてアーカイブされた）
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

## 国道50号カメラ調査の知見（2026-09-20追記）

- 国道50号（前橋〜水戸）の国交省カメラは 栃木3台（宇都宮国道: 足利陸橋・大平高架橋・小山大橋、mlit_ktr_road）と 茨城4台（常陸河川国道: 岡芹IC・福原・小原(和尚塚)・大塚、curated-still-lcdb）で、道路情報提供システム(CD83)の50号7台と一致＝全て収録済み。**群馬区間（高崎河川国道事務所）の50号カメラ（阿左美仲交差点・西久保町交差点・矢部富若歩道橋、旧URL `takasaki/camera/03015241C0xxxx.jpg`）は2026-09時点で配信終了（404）**。高崎の現行ページ（takasaki_index009）は国道17号・18号のみ
- 群馬県「ライブカメラ画像一覧」(kendobousai-gunma.jp/photo) は「写真・画像等の無断使用を禁じます」明記 → 不採用
- **ケーブルテレビ株式会社（CC9・栃木市/館林/結城/筑西/古河）の地域カメラ 44台**（`cc9.jp/community/livecamera/`、静止画 `cc9.jp/lc/web-cam/lifecam_*.jpg` 約1分更新）。リンク規定が「リンクは必ずトップページへ」のため画像直接表示ではなく誘導型（`#panel_tochigi` 等のパネルアンカー付き）で採用（curated_still.yaml）。まず国道50号の2台、続いてユーザー指示で残り39台（重複の藤岡大橋を除く）を追加し計41台。座標はまとめサイト掲載値か地名からの推定（approx）。**同一 feed_url の候補は crawler が重複として落とす**ので誘導型は URL にアンカーを付けて区別する
- review_cli の `--bulk` は件数入力の確認プロンプトがある（非対話なら `echo <件数> |` で渡す）。review_cli の保存は台帳の並び順を変えて diff が3万行になるので、HEAD の順序を保って追記し直した

## 千葉市カメラ調査の知見（2026-09-21追記）

- 千葉市内の公開カメラは少ない。河川は千葉県の簡易型河川監視カメラ4台（都川2・葭川・村田川。川の防災情報 ownCd=3073、県内168台は全て収録済み）のみで、**千葉市が独自に公開する河川カメラ・道路カメラは無い**（市の「地下道冠水情報システム」pub.os-alert.info/chiba/devmap は通行可/注意/止めの状態表示だけで映像なし。将来の情報源候補）。国交省千葉国道事務所のライブカメラは柏市の国道16号と道の駅とみうらだけ、道路情報提供システム(CD83)にも千葉県のカメラは無い
- 高速は NEXCO の iHighway 誘導型（千葉北IC・大宮IC・貝塚IC）。**貝塚IC が大阪府貝塚市の座標（OSM ジオコーディングの取り違え）で登録されていた**のを千葉市若葉区へ修正。iHighway 由来の座標は同名地名に注意
- YouTube: 本千葉町交差点（個人 hare teka、channel_id 登録）を追加。稲毛ヨットハーバー（千葉市スポーツ協会）は収録済み。bayfm 幕張・UQ 海浜幕張・ちーサービス緑区・千葉大学・東京情報大学は休止/調整中、千葉ポートタワーの旧ライブ（kankou.city.chiba.jp）は消滅
- **livecamera24.jp 系（運営者未特定）の4台（若葉区小倉町・中野町、中央区新宿・中央港）は 2026-09-21 ユーザー判断で採用**（curated_youtube.yaml、channel_id 登録、削除依頼即応）。同系の沖縄本島南部7本も同じ判断で追加できる。**同日夜に小倉町・中央港・本千葉町交差点は playableInEmbed=false（運営者が他サイト再生を無効化）と判明し誘導型（web_page、URL=channel/live）に変更**。curated_youtube.yaml の `embed: false` でパーサが誘導型を出す。livecamera24 は配信IDが日内でも変わるので watch URL ではなく channel/live を使う（サムネイルは出ない）。朝日新聞LIVE「千葉市街」は配信枠が消えたため退役（curated_still.yaml をコメントアウト）。**YouTube を追加したら埋め込み可否（watch ページの playableInEmbed）を必ず確認する**
- **印旛沼（2026-09-22 北印旛沼東岸の堤防決壊・西印旛沼が管理開始以来最高の5.04m）**: 川の防災情報・利根川下流河川事務所・水資源機構に印旛沼本体/印旛放水路/流入河川のカメラは無い（鏑木橋・馬渡・新妻・利根川3地点のみ）。追加したのは 京相農園の決壊箇所臨時ライブ（成田市、埋め込み可、停止しうる）・酒々井町 国道51号横断（誘導型）・佐倉市八木（livecamera24）。**同日に実装**: 佐倉市 河川等監視カメラ3台（feed.type `sakura_bosaicam`。`wholemap.json` の STATIONS[].CAMERA.PICT_ENCODED の base64、ICON_FLG 501 のみ有効。monitor は mie_douro と同じ `_mie_bytes` 経路、アプリは `_MieDouroView` の sakura 形式）、八千代市 1号幹線水位監視カメラ3台（feed.type `yachiyo_kansen`。`No1〜3.php` の最初の `<img src="cameraN/連番.jpg">` を monitor が解決し status.json の image_url で配信。kochi_suibo と同じ経路）。1.5.3 からアプリ再生対応。水位は川の防災情報 ofcCd=3073 obsCd=64（西印旛沼）/65（北印旛沼）
- **千葉県 YouTube 一斉点検（2026-09-23、70台）**: 38台に問題（配信終了20・非公開/エラー2・配信待機4・時間外7 など）。配信枠の更新13台・日替わりID（流鉄・木更津）をチャンネル登録化・退役11台（review.status=rejected）。**酒々井町上下水道課の排水路カメラはチャンネルの一覧に出ない（限定公開）が動画は配信中**。点検は watch ページの `playabilityStatus.status`（UNPLAYABLE=記録閲覧不可、LIVE_STREAM_OFFLINE=開始待ち、LOGIN_REQUIRED=非公開）と `isLiveNow`、後継はチャンネル `/streams` の lockupViewModel で探す
- ウェザーニュース（千葉市内28か所）は規約第9条で画像転載不可だが、**外部ページへの誘導型（web_page）なら可**（石垣で前例あり）。座標はページに無いので町名からの推定になる

## 地下道（アンダーパス）冠水状況の知見（2026-09-21追記）

- `tools/underpass.py` が5分おき（bosai-notify.yml）に自治体の公開センサー情報を取り `data/underpass_status.json` に書く。**段階（通行可0/注意1/止め2/不明-1）が変わったときだけ更新**して publish を起こす（時刻だけの変化では書かない）。site/build.py が `site/v1/underpass_status.json` へコピー。アプリは `app/lib/data/underpass.dart` → 地図レイヤー `MapLayerKind.underpass`（色付きピン＋タップで状態・情報源リンク）と「いま起きていること」カードの行（注意・止めがあるときだけ）
- 情報源: 千葉市地下道冠水情報システム（オサシ・テクノス「フィールド監視システム」 `pub.os-alert.info/chiba/devmap/JSONlist4`、map_marker.alarm_level が正）と 静岡市「しずみちinfo」（`shizuokashi-road.appspot.com/pub1/flood/underpath`。WebAPIRoot は resources/config_pub.xml、API はオープンデータ提供）。**しずみちinfo の AlertMode は「正常」しか実測できていない**（注意/警戒/通行止の表記は推定でキーワード判定。初回の実発生時に確認する）。全国的にはリアルタイム公開は稀（多くは冠水想定箇所マップのみ）。os-alert の他テナント（sendai/nagoya 等）は JSON なし
- 状態表示は映像ではないので、アプリでは「現地の道路情報板と交通規制に従う」注意書きを必ず添える
- **2026-09-21 ユーザー決定: アンダーパスに限らず、冠水センサーを導入している自治体の冠水も見える化する**。レイヤー名は「道路・地下道の冠水状況」。さいたま市の冠水センサー40か所（place_type 6、s0=1 で「冠水を検知」= level 2）を含め、市サイトが検知中に赤線で出す「想定される冠水範囲」（`data/FLine.geojson`）を点の `lines`（[[lat,lng],...] の配列）で配信し、アプリは注意以上のときだけ道路に沿った太線で描く。更新判定の signature には lines の本数も入れてある（初回配信のため）。市サイトの一覧でオレンジ行は「冠水センサーである」印で検知中の意味ではない（検知中かは地図アイコン色か詳細で判る）
- **冠水センサー再調査（2026-09-21、平面道路・内水氾濫・スマートシティ基盤を軸に4班）で 柏市 RisKma（浸水センサ28、`Origin` ヘッダ必須）・みち情報ネットふくい 冠水情報（9、静止画と同じ扱い）・加古川市オープンデータAPI（アンダーパス2、規約指定の一文を出典に含める）・佐世保市道路冠水モニタリング（市道9、トップ HTML の meta に JSON）を追加し、続いて掛川市（道路冠水観測装置7。「営利目的利用不可」の規約があるがユーザー判断で採用・出典明記）・平塚市 RisKma（4）を加え、**通行止め区間を地図に落とす**要望で 静岡県（`kansui.json.php`。冠水規制区間を WKT/EPSG:3857 から `lines` に変換、想定箇所42は level 0 で常時表示）と 兵庫県道路規制情報（KML 座標＋地域別一覧の「災害時」「気象状況」区分の行を RID で結合し、冠水/大雨系の理由だけ。線は無い）を追加（2026-09-21）。見送り: 戸田市 ArcGIS（国交省 c-sensor と同じデータ）、佐賀市 浸水情報提供システム（規約なし・座標が16MBの TopoJSON のみ。市へ照会すれば候補）。**RisKma の総当たり（2026-09-21）**: 1,695 市区町村・都道府県のローマ字で `*.riskma.jp` を DNS 解決し26テナントを確認（証明書ログには出ない）。浸水センサ型（type 43）があるのは柏市・平塚市（4か所、採用）・静岡市（`shizuoka.riskma.jp` は職員向け「巴川予測システム」へ転送、122か所あるが不採用）だけ。高崎・つくば・秩父・沼田・王寺・苫小牧・東京・光は API が拒否され、画面スクリプトにも浸水センサ機能が無い。伊達・田村は職員向け、袋井・宝達志水・新居浜・佐久穂・白石町・富山市・八王子は水位/カメラ/雨量のみ。手順: `dig <slug>.riskma.jp` → `data.riskma.net/bosai/observatories?domain=<host>`（Origin ヘッダ必須）で type を集計。福井の三本木アンダーは state.id=1 でも表示名「冠水なし」なので表示名を正としている
- **全国調査（2026-09-21、47都道府県＋総務省調査＋メーカー事例）の結果、センサー状態を機械可読で公開しているのは 千葉市・静岡市・さいたま市・高松市・兵庫県の5者だけ**。兵庫県道路総合管理システム（`RoadLan/InternetGeneral/Map/SubmergenceMap.aspx` の KML、styleUrl #1通常/#2注意/#3通行止/#99故障、県管理25か所。免責のみで転載・リンク制限なし）、さいたま市水位情報システム（`ja/place.json`＋`data/water_level_latest.json`、CC BY 4.0、道路22か所。平常時 -0.30m で降雨時だけ注意0.1/警戒0.2m を超える）、たかまつマイセーフティマップ（Geolonia 中継 `cityos-kawaga-takamatsu-FloodSituation/messages`、市オープンデータ CC BY 4.0。中継エンドポイントは開発者ドキュメント非掲載）を追加済み。国交省「浸水センサ表示システム」(c-sensor.river.go.jp、アンダーパス397基) は**二次利用不可・ツール収集お断り**のため不採用。岐阜県「道の情報」は同等の API（`api/getUnderpath`）を持つが公開画面が off・全地点欠測で県へ照会が要る。静岡県の `kansui.json.php` は冠水を原因とする規制区間（センサー状態ではない）。仙台市・奈良県・浜松市は職員更新の告知/規制情報のみ、名古屋市はカメラ画像のみ（規約同意画面あり）。他は静的な冠水想定箇所マップだけ。予防的通行規制（レベル4連動）を導入する自治体が2026-09以降増えているので、Web公開の再確認は年1回程度で足りる

## 道路の通行規制レイヤーの知見（2026-09-21追記）

- **2026-09-21 ユーザー決定: 冠水センサーと国交省の規制は1つのレイヤー「道路の通行止め・規制」に統合し、色＝原因（冠水=青/土砂=茶/気象=紫/その他=灰）、チップで原因の絞り込み、塗りつぶし＝通行止め／白抜き＝規制・注意／小さい丸＝センサー正常**（`app/lib/data/road_closures.dart` の `RoadClosures.merge` と `classifyCause`。原因語の分類表はここ）。旧 `MapLayerKind.underpass` / `roadRegulation` の描画コードは残すが選択肢には出さない。「いま起きていること」の冠水行は統合レイヤーを冠水フィルタで開く。出典一覧ページには国交省の行も載せる

- `tools/road_regulation.py` が monitor.yml（30分おき）で国交省「道路情報提供システム」の現在の通行規制を集約し `data/road_regulation.json` → `site/v1/road_regulation.json`（detail_cache は配信から除く）。アプリは `app/lib/data/road_regulation.dart` → `MapLayerKind.roadRegulation`（規制区間の線＋起点ピン、詳細シート）
- **取得の仕組み**: `pc/pcTukokisei_83_1.html` の script src に5分ごとに変わる `backup/<yyyymmddHHMMSS>/<乱数>/` があり、`<dir>TukoKisei/<1次メッシュ>.json` に規制配列（座標・区間の GeoJSON・コード類）。路線名・区間・原因の文字列は `pc/pcTukokiseiDetail_<same_tukokisei_info_id>.html` の div.detailData（複数ブロック）から取り、一度取った分は detail_cache に残す。**詳細ページは Content-Type に charset が無く requests が ISO-8859-1 と誤判定するので `content.decode("utf-8")`**（初回に文字化けで路線名が空になった）
- 対象は工事（原因事象 05/06/07）・冬期通行止（規制内容 01＋詳細 002）・予定（実施状況≠1）を除いた災害・気象・事故等。国道だけでなく高速道路会社・都道府県から提供された規制（「通行止（都道府県道）」等）も含まれる。2026-09-21 時点で338件（通行止め222件）
- 線は Douglas-Peucker（約13m）で間引く（間引き前は4.8万点・配信1.2MB）。1次メッシュ137個は台帳のカメラ座標から生成した固定リスト
- 高速道路（NEXCO iHighway の JSON。原因「雨・災害・地震」等、区間は IC 名、座標はタイル座標）、静岡県・兵庫県・福島県の規制システムは未統合の候補。JARTIC は月次 CSV のみ

## 定期実行の知見（2026-08-28追記）

- **GitHub Actionsのcronは間引かれ・停止することがある**（2026-08-26〜27に5分cronが数時間おきになり、最後は8時間停止。大阪の大雨危険警報の通知が遅れた）。公開リポジトリで実行枠の問題ではなく、GitHub側のスケジュール取りこぼし
- 対策として**ユーザーのGAS（Google Apps Script）から5分おきに`bosai-notify.yml`、30分おきに`monitor.yml`を`workflow_dispatch` APIで起動**している（Fine-grained PAT: livecam-jp限定・Actions Read/write）。GitHub側のcronは予備として併存。実行履歴で`workflow_dispatch`が5分ごとに並んでいれば正常。止まっていたらGASのトリガー/トークン期限(無期限設定)を疑う
- 台帳の公開(publish)は全ユーザーに1MB(gzip)の再取得を発生させるため、1日1回程度にまとめる
- **監視は10シャード制（1台あたり約5時間に1回）なので、ハッシュ履歴48件は約10日分**。凍結判定は「履歴全件が同一」ではなく「末尾の同一区間の先頭から6時間以上（＋日の出跨ぎ）」で行う（2026-09-07 栄橋の不具合報告: 配信元が19時間止まっても ok のままだった）。配信元サーバが同じ画像を毎回新しい Last-Modified で返すため、ヘッダでは検知できない
- 中部地整(cbr.mlit.go.jp)の道路カメラは配信停止中に「現在、この地点の画像配信は行っておりません」を HTTP 200 で返す → dHash を PLACEHOLDER_HASHES に登録済み（フィクスチャ cbr_road_placeholder.jpeg）

## カメラ調査の知見（2026-08-29追記）

- **ライブカメラDB(livecam.asia)索引経由の取込**は tools/livecamdb_index.py（索引）→ tools/livecamdb_ingest.py（一次ソース確認）→ scratchpad の build_*_yaml.py / merge.py / approve_batch.py（消えたら再作成）で流す。座標はGoogleマップ埋め込みの `!2z`（マーカー実位置）を優先、`!2d/!3d` は中心で約200mずれる
- **YouTubeチャンネルの現在ライブは `/streams` の ytInitialData から取れる**。2026-08時点で一覧は `lockupViewModel`（`contentId` + `thumbnailBadgeViewModel.badgeStyle == THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE`）に変わっており、旧 `videoRenderer` は出ない。索引由来の「チャンネルURLのみ」記録はこれで6割程度が現在の枠に解決できた。ニュース番組・院内番号案内・ペット部屋などカメラ映像でない配信が混ざるので名称/タイトルで除外する
- **埼玉県川の防災情報と和歌山県河川雨量防災は同じJWAテンプレート**（`geojson/<pref>_camera.geojson` + `chitenconfig/CameraList.csv` + 固定URL `hyoujidata/camera/<ID>.jpg`）。`crawler/sources/jwa_river_cam.py` に県設定を足すだけで他県も対応できる。埼玉はkawabou由来と同一地点が72件あり保留中（候補のnoteに「kawabou重複候補」）
- **みち情報ネットふくい・ひろしま道路ナビは転載禁止文言があるが、ユーザー判断(2026-08-29)で静止画の直接表示を継続**（端末が直接取得・出典明記）。県へ照会中（docs/inquiries_2026-08-29.md）。回答が「不可」なら誘導型（福井 `camera.html?id=`・広島 `camera_detail.php?id=`）に切替える
- 掲載元システムの利用条件・取得構造の調査結果は docs/research_2026-08-29/system_parsers_terms.md（静岡SIPOS・名古屋市は要照会、NTTルパルクは不可、山口・島根・福岡は実装可/条件付き）

## アプリの知見（2026-08-29追記）

- **Dartの `DateTime.parse` は `+09:00` 付き文字列をUTCに変換して返す**。気象庁のファイル名（JST）を組み立てるときは明示的にJSTへ戻す（アメダスで9時間前のデータを読んでいた）。**UTCフラグ付きの値の `.hour` / `.month` をそのまま表示してはいけない**（防災タブの震源表示が9時間ずれていた）
- **時刻は「絶対時刻(instant)」と「JSTの壁時計(wall clock)」の2種類しか作らない**。壁時計は `app/lib/util/jst.dart` の `jstNow()` / `toJstWallClock()`（**素のDateTime**で返る）を使い、URL・ファイル名の組み立てと素の日時との比較にだけ使う。`DateTime.now().toUtc().add(9h)` の戻り値をそのまま比較に使うと9時間ずれる（暑さ指数で実発生）。全面点検の結果と原則は [docs/time_audit_2026-09-01.md](docs/time_audit_2026-09-01.md)。Python側は JST の aware datetime に寄せる（`jst_today()` / `parse_jma_time()` / `as_utc()`）
- **気象庁のタイル（雨雲 hrpns・降水短時間予報 rasrf/rasrf24h・キキクル land/inund）は偶数ズームしか生成されない**（各 properties.xml の `zoomUse="even"`、maxNativeZoom 10〜11）。奇数ズームや z12 以上で同じ z を要求すると透明タイル（334バイト・HTTP 200）が返り何も描画されない（2026-09-08 不具合報告「キキクルが遠目でしか出ない」）。`EvenZoomTileProvider`（app/lib/data/even_zoom_tile_provider.dart）が奇数ズームでは1段下の偶数ズームの親タイルを取得して該当4分の1を拡大して返す（TileLayer は 256px のまま・maxNativeZoom 10）。**時刻更新でレイヤーの key を変えない**こと（urlTemplate の変更なら flutter_map が前の画像を残したまま差し替えるが、key を変えると一瞬消える）。設定ファイル: https://www.jma.go.jp/bosai/risk/ の `table/risk.properties__*.xml`、nowc/kaikotan も同様
- **積雪レイヤー（2026-09-16）**: 気象庁「今後の雪」のタイル `bosai/jmatile/data/snow/<basetime>/none/<validtime>/surf/{snowd|snowf24h}/{z}/{x}/{y}.png`（解析積雪深・解析降雪量）。targetTimes.json は実況（basetime==validtime）と予測が混在し降順とは限らないので `JmaLayers.latestSnowTime` で最新実況を選ぶ。偶数ズーム限定（snow.properties zoomUse="even"・maxNativeZoom 10）で雨雲と同じ扱い。凡例色は `bosai/snow/images/legend_deep_snowd.svg` / `legend_deep_snowf24h.svg` の実値（積雪深 5/20/50/100/150/200cm、24時間降雪量 10〜70cm）。9月は全面透明で見た目の確認は初雪待ち
- **洪水キキクル（flood）の PNG タイル `surf/flood` は全国常に透明**。気象庁の表示は pbf（ベクタ）の河川線で、PNG は `flood_mesh`（メッシュ形式）のみ描画がある
- 気象庁の24時間降水量タイル(rasrf24h)の配色しきい値は 〜50/50/80/100/150/200/250/300mm（1時間雨量の 10/20/50/80… とは別）。凡例・ラベル色はタイル画素とアメダス実測値で照合済み
- **地震情報の市区町村コード（list.json `int[].city[].code`）は政令指定都市を区単位で返す**（1410200=横浜市神奈川区）が、名前を引く area.json の class20s は「横浜市北部／南部」等の単位しか持たないため区名が引けず「市区町村 14102」と出ていた（2026-09-17）。総務省「全国地方公共団体コード」から生成した区名テーブル `app/lib/data/ward_names.dart`（20政令市171区、生成は `tools/ward_names.py`）を下敷きにして解決する。区の再編（浜松2024等）があれば再生成する
- quake/list.json の「顕著な地震の震源要素更新」報は cod が度分形式（`+3559.9+14005.7`）。同一eidの複数報は震度が空の報が混ざるので、値の埋まっている項目を合成し最大震度を採る（`JmaLayers.mergeQuakeReports`）
- **都度解決型の追加（2026-08-29）**: `shimane_suibo`（島根県水防情報。`dyn/camera/camera.json` 1リクエスト→`dyn/camera/<日付>/<時刻>/camera_l/<point>.jpg`、saitama_flood型）、`fukuoka_kasen`（福岡県河川防災情報。座標は `river2/map/data/gisItv_0.html` 埋め込みの itvJson(Shift_JIS)、https失敗のためhttp取得）、`yamaguchi_kasen`（一覧ページ型。サーバのDH鍵が弱く `crawler/sources/base.py` の LegacyTlsAdapter が必須）。いずれもアプリの FeedType 配線済み（リリースまで再生非対応表示）
- **監視は HTTP 200・image/* でも本文0バイトを失敗として数える**（石川県道路カメラで停止中カメラが空ファイル配信）
- 運営者不明分の再調査結果は docs/research_2026-08-29/operator_unknown_resolved.md。転載禁止で不採用にした運営者（yamagata-road.net・tollroad-saga・fujikichi 等）と、事前相談文言で見送った臼杵市・高砂市を記録。kawabou 重複候補（埼玉72・福岡24・島根1）は candidates.json に保留中

## Push通知の運用ルール（2026-08-30追記・厳守）

- **本番トピック（special-warning / danger-warning / quake* とその都道府県別）へテスト送信をしてはならない**。一般ユーザー700人超に「【テスト】」通知が届く事故を起こした。切り分けは必ず `push-test.yml` の **mode=send + token指定（直接送信のみ）** で行う。トピック経路の確認が必要なときは、本番と別のテスト専用トピック（例: `test-only`。アプリは購読しない）を使うか、ユーザーに事前に確認を取る
- push-test.yml は token 指定時にトピックへ送らないよう修正済み。topics の既定値も空

## ハザードマップ・避難場所の知見（2026-08-30追記）

- **ハザードマップ**は国土地理院「重ねるハザードマップ」のPNGタイル（`https://disaportaldata.gsi.go.jp/raster/<ID>/{z}/{x}/{y}.png`、z2〜17、データ無しは404）。ID一覧は https://disaportal.gsi.go.jp/hazardmap/copyright/opendata.html。土砂災害は `05_kyukeishakeikaikuiki` / `05_dosekiryukeikaikuiki` / `05_jisuberikeikaikuiki`（`_data/<県>`付きは県別）。東京中心で試すと土石流タイルは404だが大阪・広島では200（無いだけ）。凡例色はポータルの凡例画像の画素値（app/lib/data/hazard_layers.dart）。月次の `hazard-check.yml` がID一覧とタイル応答を前回(`data/hazard_layers_seen.json`)と比較し、変化時に Issue を作る。`tools/hazard_check.py` の APP_TILE_IDS は hazard_layers.dart と手動同期
- **避難場所**は国土地理院の全国一括CSV（`hinanmap.gsi.go.jp/hinanjocp/defaultFtpData/csv/mergeFromCity_2.csv`=指定緊急避難場所(災害種別フラグ)、`mergeFromCity_1.csv`=指定避難所。市町村別ファイルのURLは取得不可）。`tools/shelters.py` が県別JSON `data/shelters/<JIS>.json`（キー n/a/lat/lng/f/s）と index.json を生成、`shelters.yml` が毎月1日にLast-Modified変化時だけ再生成→publish。site/build.py が `data/shelters/` を `site/v1/shelters/` へコピー（`tools.shelters.sync_site`。**publish環境に requests は無いので遅延import**）。アプリは表示中の県分だけ取得し一時ディレクトリに version 付きでキャッシュ（app/lib/data/shelter_layers.dart）
- 利用条件: 国土地理院コンテンツ利用規約（出典明記）。避難場所は「最新でない場合がある・市町村に確認・災害種別ごとの指定」の注意を伝える必要あり（初回ダイアログ＋凡例下の免責で対応）
- **川の防災情報(kawabou)は「ツール等による定期的なデータ収集はお控えください」と規約に明記**（https://www.river.go.jp/kawabou/kwb_apend/html/caution.html 2026-08-31確認）。死活監視は `monitor/main.py` の `_skip_low_freq` で **1日4回（UTC 18/0/6/12時台＝JST 3/9/15/21時台）に制限**している。同サイトの他データ（Lアラート避難情報・水位JSON）を使う場合も同じ頻度方針を守ること
- **道路情報提供システム(mlit_roadinfo, 1,145台)は規約に「各画像への直接のリンクはご遠慮ください」の記載があるが、2026-08-31のユーザー判断で直接表示を継続**（福井・広島と同じ扱い）。国交省から是正等の連絡があった場合に誘導型へ切替える。規約: https://www.road-info-prvs.mlit.go.jp/roadinfo/pc/pcWhenUsing_00_0.html

## 防災拠点データの知見（2026-08-31追記）

- **給水拠点・防災備蓄倉庫・消防水利は国による全国集約が存在しない**（デジタル庁の自治体標準オープンデータセットは様式のみ）。自治体オープンデータをCKAN横断（BODIK ODCS ほか）で集める `tools/facilities.py` を実装。出力は `data/facilities/<JIS>.json`（キー n/a/lat/lng/k/o/s、`s` は県ファイル内 `sources[]` の添字）＋ index.json、`facilities.yml` が毎月1日に更新→publish
- **2026-08-31 ユーザー判断: 消防水利（消火栓・防火水槽）は対象外**（一般利用者向けでないため）。残る給水拠点905・備蓄倉庫109の計1,014件は**4都県8自治体**（船橋市/東京都水道局・墨田区・品川区・練馬区/名古屋市・豊田市/彦根市）のみ。カバーが狭いため**アプリの防災拠点レイヤーは 1.2.0 では非表示**（`app/lib/ui/map_screen.dart` の `showFacilitiesLayer=false`。実装は残してあり、配信データのカバーが広がったら true にする）。月次収集は継続
- 座標が無いデータは国土地理院AddressSearchで補完（`g:1` を付与）。`data/facilities_geocache.json` にキャッシュ済みなので次回以降は速い
- **robots.txt で `/api/` を禁止している札幌市・横浜市のポータルはクロールしない**（SPEC C4。`BLOCKED_PORTALS` に記録）
- **XLSX対応済み（2026-08-31）**: `read_xlsx()`＋`resource_format()`＋`xlsx_error()`。**148,871件→339,670件 / 22県→24県 / 78→91自治体**。伸びの9割は東京消防庁の消火栓・防火水槽（178,255件・座標あり）。自治体XLSXは1ファイル複数シート・先頭に説明行が数行あるのが普通なのでシートごとにヘッダ行を探す。**format欄よりURLの拡張子を優先**（XLSと書いて実体xlsxが実在）。旧形式XLSはマジックナンバー(`D0CF11E0`)で弾いて理由をrejectedに残す
- **山口県 `yamaguchi-opendata.jp/ckan` を追加**。**CKANの配布時robots.txtは `User-agent:*` に `Disallow: /api/` を含むので、素のCKANを立てている自治体はほぼ全部クロール不可**（岐阜・神奈川・秋田・金沢・港区など16件を`BLOCKED_PORTALS`に記録）。BODIKが使えるのは`/api/`禁止をSogou/Baidu等のUAグループ限定に書き換えているから
- **JISコードより「文字で書かれた県名」を優先する**（`rows_to_records`）。紀美野町の消防水利XLSXは市区町村コードが`030306`で、コード優先だと603件まるごと岩手県に飛んだ
- 埼玉・岡山・広島・島根・宮城は dataeye系ポータル（`/ckan_api/`・robots全面許可）に消防水利がありrobots的には取れるが、**パッケージにライセンス欄が1つも無い**ためSPEC C5に従い不採用。利用規約を確認できれば5県増える（次の一手）
- **YouTubeカメラの一斉点検（2026-08-31）**: 2,686台を watch ページの isLiveNow ＋ チャンネル `/streams`（`https://www.youtube.com/channel/<UC..>/streams` の形式でないと404）で判定し、追従201・退役240。要確認91台（営業時間のみ配信の施設カメラ・冬季のみのスキー場など。深夜に確認したため）は docs/research_2026-08-31/youtube_health.md に一覧。**日中に再確認する**こと。非公開/削除の69件はチャンネルIDが取れず自動追従不可（運営者名から新枠を探せば復活できる）

## 海外カメラ調査の知見（2026-09-02追記）

- 海外カメラは `crawler/curated_world.yaml`（人手台帳）→ `curated_world` パーサ → cameras.json。ID は `world-<sha1(video_id)[:8]>`。**yaml でコメントアウトしただけでは cameras.json から消えない**（8/31 退役分が残っていた）。退役時は cameras.json からも除去し version を更新する
- 2026-09-02 の調査で第1波 +454台・退役136台、第2波（空白地帯・ランドマーク・絶景）+402台（22,341台、海外1,032台）。手順・鉱脈・見送り理由・**YouTube枠が無い有名地点の公式カメラ一覧（静止画/独自プレーヤー。curated_still 化の候補）**は docs/research_2026-09-02/world_cameras.md。取り込み/点検スクリプト（`merge_world.py` / `health_world.py` / `retire_follow.py` / `apply_plan.py`）は scratchpad に置いたので消えたら同文書を元に再作成する
- **SkylineWebcams・feratel・EarthCam は個別カメラの YouTube 配信をやめ巡回コンピレーションのみ**になった。同運営者の個別枠は復活しない前提で扱う。Explore.org は動画IDを別カメラに付け替える（名称と映像が食い違う）ので定期点検が要る
- YouTube watch ページは並列取得で 429 になる。2〜3秒間隔＋429時30〜90秒待ちで安定。調査エージェントの WebSearch は1セッション200回で上限に達するので、後半は YouTube 検索結果ページ（ライブ絞り込み）と既知チャンネルの `/streams` 追跡が有効
- 追従判定のタイトル一致は誤マッチする（例: ハミングバード→ワシの巣、カホンパス→ジョージア）。自動追従は必ず目視で精査する
- cameras.json に同一動画IDの二重登録が12件ある（主に `curated-lcdb-*` と既登録の重複）。未解消
- 宗教団体が画面に聖句・祈りのテロップを重ねるカメラは中立性の観点で不採用。メッカ・メディナはサウジ放送庁の公式チャンネルのみ（再配信多数）。モスクワ中心部の24h固定カメラはYouTube上に無い（ロシアの都市カメラは VK/Rutube に移行）

## 沖縄・離島カメラの知見（2026-09-03追記）

- 沖縄の離島は**公開カメラ自体が無い島が大半**（慶良間・粟国・渡名喜・伊平屋・伊是名・北大東・久高・竹富・波照間・与那国(灯台以外)）。石垣島に集中。詳細は docs/research_2026-09-03/okinawa_cameras.md
- 石垣島の個人・企業チャンネルは配信枠が頻繁に切り替わる。1チャンネル1配信なら **youtube_channel（チャンネルID）で登録**すると追従不要（730交差点・離島ターミナル・舟蔵・空港FI・YAEYAMA LIVE・hotel cava・球美の里はこの形）
- 国内の取り込みでは市町村名→JISコード変換が必要（沖縄41市町村の表は取り込みスクリプト内。震度連動の市区町村カメラ一覧に効く）
- 自治体HPの「一般的な著作権表記」は転載禁止文言ではないので静止画の直接表示可（東村防災カメラ）。明示的な転載禁止（ウェザーニュース規約第9条、arksystem）は誘導型か不採用
- 運営会社名を確認できない設置事業者（livecamera24.jp 系）は見送り。特定できれば沖縄本島南部に7本追加できる

## 宿泊予約サイト導線の知見（2026-09-03追記）

- カメラ詳細「この付近の宿を探す」は観光系カテゴリ（scenic/coast/volcano/healing）と海外カメラのみ。設計と実機確認項目は docs/hotel_links_1.4.1.md
- **広告と宿導線を伏せる条件は「利用者が特別警報（レベル5）の発表エリアに居る」**（`AppState.viewerInSpecialWarningArea`。2026-09-03 ユーザー決定）。カメラの所在地では判定しない（県外の人が警報エリアのカメラを見るのは普通、復旧期は宿を出す方が支援になる）。現在地は発表中だけ `data/viewer_area.dart`（許可済みの最終既知位置→国土地理院逆ジオコーダ `mreversegeocoder.gsi.go.jp`）で求め、**不明（位置情報オフ等）なら無条件で出す**（警報時ほどアクセスが増えるためのユーザー判断）。危険警報（レベル4）は対象外
- **じゃらんのキーワード検索は Shift_JIS のパーセントエンコード限定**（UTF-8 は0件）。`tools/hotel_keywords.py` が気象庁 area.json から `app/assets/data/municipalities.json` を生成して同梱。市町村合併時に再生成
- 楽天トラベルの座標検索は日本測地系の秒（f_ido/f_kdo）＋宿泊日必須。JTB は県パス必須。各社URLの実測は docs/research_2026-09-03/hotel_deeplinks.md
- **VC の referral は中継の VIEW_URL が固定LPでも vc_url が最終的に優先される**。curl で確認するときは `atrrd…resolve?u=` の中の entry.php に `&vc_url=` を付けて追う
- 宿サイトの有効/無効も products.json の `merchants`（jalan/rakuten_travel/jtb/expedia）で切替
- **国内カメラの municipality（JIS 5桁）は約5,100件が未設定だった**（2026-09-03 時点）。`tools/fill_municipality.py` が国土地理院逆ジオコーダで補完する（控え: data/municipality_geocache.json、県違いは書かずに報告）。新規取り込みで municipality を付けられなかったときはこれを回す。じゃらん導線と震度連動の市区町村カメラ一覧に効く
- **気象庁 r8 map.json の一次細分区域コードのキーは `areaCode`**（`code` ではない）。`AppState.parseSpecialWarnings` は官署×dataTypeCode で最新報を採る
- **アフィリエイトの明示は画面に出さない**（備え・宿導線とも）。利用規約 site/terms.html 第6条とプライバシーポリシー第5条でカバーする（2026-09-03 ユーザー判断）。新しい購入導線を作るときも画面内表記は不要、規約の記載範囲に含まれているかだけ確認する

## 災害情報Xアカウントの知見（2026-09-07追記）

- 自治体・国の機関の災害情報Xアカウントは `data/x_accounts.json`（採用: prefectures / municipalities / national_offices、調査用: candidates / excluded / unresolved_prefectures）。**アプリ内にポストは出さず外部Xを開くだけ**（X APIは従量課金・埋め込みは未ログインで表示されない）。運営主体の種別（type）は必ず併記する
- 配信は `tools/x_accounts_publish.py` → `site/v1/x_accounts.json`（採用分・表示に要る欄だけ。type が official / national / gov_related 以外は落とす）。アプリは `app/lib/data/x_accounts.dart` が取得し6時間はメモリ控え、失敗時はディスク控え
- **採用条件は「県サイトのSNS一覧など一次ソースに掲載されていること」**。ハンドル名の推測で見つかる「〇〇県防災」の多くは個人・休眠・別自治体。防災専用が無い県は県の総合公式を `dedicated=false` で載せる（アプリで「総合アカウント」と併記）
- 実在確認は `tools/x_account_verify.py`（x.com の og メタデータ）。投稿確認 `tools/x_account_posts.py` は429が出やすく1件4分以上空ける
- 国の機関（河川事務所等）は管轄が複数県にまたがるので `area_codes` 配列で持つ（例: 江戸川河川事務所 = 11/12/13）

## 支援へのお礼（広告非表示期間）の知見（2026-09-20追記）

- **広告非表示は「買う」ものではなく、開発者支援（投げ銭）へのお礼**（2026-09-20 ユーザー決定。文言もそう書く）。`app/lib/data/ad_free.dart` の `AdFree.instance` が期限（SharedPreferences `ad_free_until`、UTC）と履歴（`tip_history`）を持ち、`AdBannerPlaceholder` / `AnchoredAdBanner` は期間中は読み込みもしない。日数は coffee 30 / sweets 90 / lunch 240 / devtools 730（月単価が上位ほど下がる設計）。期間中の再支援は残りに加算
- **ストア側（App Store Connect / Play Console）の変更は不要**。商品は消耗型4種のまま。消耗型は復元できないため期限は端末内のみ（再インストール・機種変更で消える）と支援画面に明記。「永久」は非消耗型を別に作らない限り約束しない
- 購入時に Analytics イベント `tip_purchased`（product）を送る。それ以前の支援者は端末からもストアからも特定できない（集計だけ可能）

## Android版の知見（2026-09-10追記）

- Android のリリース手順・Play Console の設定値・コード側の残作業は [docs/playstore_setup.md](docs/playstore_setup.md)。AdMob の Android ID は 2026-09-10 に本番値へ差し替え済み（AndroidManifest と config.dart）
- `flutter build apk/appbundle` は **core library desugaring 必須**（flutter_local_notifications v16+）。`android/app/build.gradle.kts` に `isCoreLibraryDesugaringEnabled = true` と `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")` を設定済み
- ホーム画面ウィジェットは iOS のみ（`WidgetBridge.supported`）。ATT（app_tracking_transparency）は Android では notSupported を返すだけで無害
- 署名鍵 `android/upload-keystore.jks` と `key.properties` は gitignore 対象。紛失すると Play へ更新できなくなる
- **Android の FCM 通知はチャンネル `bosai` を起動時に作る**（`app/lib/data/fcm_channel.dart`、重要度「高」）。マニフェストの default_notification_channel_id に書いてあるだけでは作られず、予備の「その他」チャンネル（ポップアップなし）に落ちる。送信側（bosai_notify.py / push-test.yml）は `android.priority: high` と `android.notification.channel_id: bosai` を付ける

## 台風情報・指定河川洪水予報の知見（2026-09-16追記）

- **台風情報**は気象庁の公開JSON `bosai/typhoon/data/targetTc.json`（発表中の熱帯低気圧一覧。`typhoonNumber` が英字 "a" 等なら「台風になる見込みの熱帯低気圧」、4桁 "2618" なら台風第18号）→ `data/<TC>/specifications.json`（実況・予報の位置・気圧・風速・予報円半径km・暴風警戒域 stormWarning.range）と `data/<TC>/forecast.json`（経路 track.preTyphoon/typhoon、予報円半径 m、暴風警戒域の包絡線 arc/line）。アプリは `app/lib/data/jma_typhoon.dart` で結合し、地図レイヤー `MapLayerKind.typhoon`（経路・予報進路・予報円・暴風警戒域を円で近似）と災害速報タブのカードに出す。5分メモリ控え。**複数発生時は地図左下に「すべて／台風第N号…」の切替チップ**を出し、選択中の台風だけ描く（`_typhoonId`、null=全部）。災害速報タブの「地図で進路を見る」と「いま起きていること」の台風行は `navigationRequest = 'map/typhoon/<TC番号>'` でその台風だけを選択して開く。選択中の台風が一覧から消えたら全表示に戻す
- **指定河川洪水予報**は `bosai/flood/data/r8/flood_xml.json`（発表中の報の配列。無ければ `[]`）。項目は気象庁ページの JS から確認: riverCode / riverName / reportDatetime / infoType（訓練は除外）/ item{code,name} / class20s（対象市町村→都道府県）/ officeCodes。コード 20台=氾濫注意(L2)・30台=氾濫警戒(L3)・40台=氾濫危険(L4)・50台=氾濫発生(L5)。**2026-09-20 善福寺川（東京都・レベル4氾濫危険警報）の実発表で確認: `class20s` は無く `item.areas`（河川）と `officeCodes`（130000=東京）だけ**。都道府県は class20s が無ければ officeCodes の先頭2桁で導く（アプリ・bosai_notify とも。未対応だったため初回はプッシュが送られなかった）。アプリは `app/lib/data/jma_flood.dart`、台帳の `river_or_route` と河川名で照合して `RiverCamerasScreen` に出す
- 災害速報タブの洪水予報の発表時刻は「9/20 21:50発表」と月日付き（前日の発表が翌日まで残るため。2026-09-21 ユーザー要望）
- 洪水予報のプッシュは `tools/bosai_notify.py` の `check_flood_forecasts`。氾濫危険=danger（レベル4）・氾濫発生=special（レベル5）として気象警報と同じトピックに流し、キー `<pref>:flood<band>:<riverCode>` を active_special に同居させる
- 洪水予報4段階・予報円・暴風警戒域・強風域・熱帯低気圧の各言語訳は気象庁 多言語辞書（`https://www.data.jma.go.jp/developer/jma_multilingual.xlsx`、シート「多言語辞書（本体）」、openpyxl で引ける）の公式訳に揃えた（2026-09-16）。「台風第N号」「強い/非常に強い/猛烈な」「降雪量」は辞書に無いので独自訳

## ルート沿いカメラの知見（2026-09-16追記）

- 地図の「ルート」ボタン → 出発地・目的地（国土地理院 AddressSearch で座標化。出発地は現在地も可）→ openrouteservice（`app/lib/data/route_corridor.dart`、自動車経路）→ 経路から 1/3/5km 以内のカメラだけを地図に表示し、一覧（`route_cameras_screen.dart`）は出発地からの経路上距離順。照合は Douglas–Peucker で間引いた線分との距離（外接矩形で前処理）
- **ORS の API キーはアプリに埋め込まず、配信 manifest の `route_ors_key` で渡す**（site/build.py が環境変数 ORS_API_KEY を読み、publish.yml が GitHub Secret から注入）。キーが空なら地図のルートボタン自体を出さない。無料枠は 1日2,000回・40回/分（キー単位）。openrouteservice.org でアカウントを作りキーを Secret に登録すれば、アプリ更新なしで有効になる
- 経路データの出典表記「経路: openrouteservice / © OpenStreetMap contributors」をシートと一覧に表示。運転中の操作禁止の注意も併記
- **地名の座標化は国土地理院 AddressSearch だけでは不十分**（住所専用で「赤レンガ倉庫」が福岡県赤村に部分一致した。2026-09-16）。ルート検索は 台帳のカメラ名 → ORS の Geocoding API（`geocode/search`、`lang=ja`、無料枠 1日1,000回。表示名は「名称（地域 市区町村）」）→ 地理院住所検索 の順で候補を集め、複数あれば選択ダイアログを出す（`RouteCorridor.geocode` / map_screen の candidates()）

## 「いま起きていること」カードの知見（2026-09-16追記）

- 地図の左上に重ねるカード（`app/lib/ui/situation_card.dart`、要約は `app/lib/data/situation.dart`）。特別警報・危険警報の県、台風、指定河川洪水予報、直近24時間の震度4以上があるときだけ出す（平時は何も出ない）。起動時と10分ごとに気象庁の4系統（r8 map.json / 台風 / 洪水予報 / 地震一覧）を並列取得し、失敗した系統は空として扱う
- カードの見出しタップで折りたたみ（見出し＋件数だけ）。左下の凡例もタイトルタップで折りたたみ（**隠すのは出典行だけ**。色と段階の文字は常に表示）。冠水状況の出典は10行並べず、`site/underpass_sources.html`（`tools/underpass.py` の `render_sources_html` が sync_site で生成）へリンクする1行にまとめた（2026-09-21 要望）。各地点の詳細シートには個別の出典を出す。どちらも SharedPreferences（`situation_collapsed` / `map_legend_collapsed`）に記憶（2026-09-21 要望「画面の大半が埋まる」）
- 閉じたカードは内容の識別子（`Situation.signature`）が同じあいだ再表示しない（SharedPreferences `situation_dismissed`）。内容が変われば再び出る
- 行タップは `navigationRequest`（'bosai/warning' / 'bosai/quake'）と台風レイヤー切替。Analytics イベント `situation_open`（kind）で何が開かれたかを取る
- ホーム画面（ダッシュボード）は新タブを増やさず、この「災害時にだけ現れるカード」方式にした（2026-09-16 ユーザー決定。案1）


## ストア用スクリーンショットの知見（2026-09-17追記）

- **撮影用のコードはアプリ本体に残さない**（2026-09-17 ユーザー指示。リリースに影響させない）。`tools/screenshot_capture/` の patch（`screenshotMode`＝`--dart-define=SCREENSHOT_MODE=true` でデバッグリボン・広告・ATT・起動時の位置情報許可要求を止める）と integration_test / test_driver を、撮るときだけ `app/` に当てて終わったら `git checkout` で戻す。手順は [docs/store_screenshots.md](docs/store_screenshots.md)
- **iOS で起動時に OS の許可ダイアログ（位置情報）が出ると Flutter の初回フレームが描画されず、25枚全部が起動画面（LaunchScreen）になる**。`xcrun simctl privacy grant` は drive の再インストールで消えるので、撮影モードでは一覧タブの起動時 `requestPermission` を止めて対処した
- `integration_test_driver_extended` の `onScreenshot` は **テスト終了後にまとめて呼ばれる**。そこで `simctl io screenshot` を撮っても全部同じ画面になる。画像はアプリ側 `binding.takeScreenshot()` のバイト列（1206×2622 の実解像度）を使う
- **ユーザーはデザインの素案を Codex に作らせる方針**（`/Applications/ChatGPT.app/Contents/Resources/codex exec`）。文言・配置を自前で決めず、素案→書き出し→目視確認の順で回す
- Android は25枚を1回で返すと VM Service ごと落ちる（`Service has disappeared`）ので `--dart-define=CAPTURE_SET=maps|details|tabs` で分割して撮る
- 編集・書き出しは `store_screenshots/`（ParthJadhav/app-store-screenshots のテンプレート。`npm install --legacy-peer-deps` → `npm run dev` → http://localhost:3000）。文言と構成は `app-store-screenshots.json`、フォントは Noto Sans JP、テーマ `livecam-sky`（ブランド色 #1E6FD9）。デザイン素案は `store_screenshots/DESIGN.md`（Codex 作成。強調語は textElements で重ねているので文言変更時は位置も直す）。ヘッドレス書き出しは `store_screenshots/tools/export.mjs`（Playwright）。書き出し済み PNG は `app/store_assets/ios/screenshots/<WxH>/ja/`・`app/store_assets/android/screenshots/`

## YouTube 全国点検の知見（2026-09-23追記）

- **点検手順**: ①watch ページの `playabilityStatus.status`（OK / UNPLAYABLE / LOGIN_REQUIRED / LIVE_STREAM_OFFLINE / ERROR）・`isLiveNow`・`playableInEmbed` を取り、②NG のものはチャンネル `/streams` の ytInitialData（lockupViewModel＋THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE）で現行ライブ一覧を取り、③各ライブの oEmbed でタイトル（401＝埋め込み不可）を取る。watch は2〜3秒間隔（429 対策）。3,251台で約2時間。スクリプトは scratchpad の yt_health_all.py / yt_follow_all.py / apply_yt_all.py（消えたらこの手順で再作成）。**`requests` は Homebrew の python3 に無いので `/Library/Frameworks/Python.framework/Versions/3.10/bin/python3` を使う**
- **判断規則（2026-09-23 適用）**: チャンネルの現行ライブが1本 → 追従（タイトルが明らかに別地点なら追従しない）。タイトルに日付が入る日替わり枠は youtube_channel に変更（**1チャンネル1配信のときだけ**。複数配信チャンネルの日替わり枠は動画IDで追従し要定期追従）。新枠が oEmbed 401 なら誘導型（web_page）。複数ライブはタイトルで該当カメラを人手で選ぶ（特定できなければ据え置き）。追従先が既登録カメラと同じ動画になるときは重複なので退役。現行ライブが無く動画も再生不可/削除/ログイン必須なら退役、`ok_notlive`（動画は生きているが配信休止）と LIVE_STREAM_OFFLINE は据え置き（営業時間・季節限定が多い）
- **台帳を直したら curated_youtube.yaml / curated_world.yaml / curated_still.yaml を必ず同期する**。週次 crawl.yml の `refresh_approved_feeds` が YAML の video_id で台帳の youtube_video を上書きするため、YAML が古いと追従が戻る。退役は YAML 側をコメントアウト（`# 2026-09-23 退役: 理由`）、追従は `# 2026-09-23 配信枠更新: 旧 → 新` の見出し付きで video_id を差し替える。台帳は review.status=rejected のまま残す（decided_ids に入るので候補に再登場しない）
- curated_world.yaml も `channel_id` / `embed: false` が使える（2026-09-23 に curated_youtube と同じ規則をパーサに追加）
- 結果（2026-09-23）: 追従311・誘導型40・チャンネル登録21・退役198。据え置き141台（複数ライブで特定できず94、配信休止32、別映像化9、休止中同一3、オフライン3）は次回点検で再確認する。日中に配信が始まる施設カメラが多いので**点検は日中に行う**
- **youtube_channel 型の埋め込み（`embed/live_stream?channel=`）は、チャンネルが配信中でも「この動画は再生できません」になることがある**（2026-09-23 湯島「猫島」。同じ配信を動画IDで埋め込むと再生できた）。不具合報告があったら同チャンネルの動画ID登録に切り替える。点検スクリプトは /live の解決で判定するためこの失敗は検知できない
