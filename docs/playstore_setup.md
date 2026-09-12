# Android 版リリース手順（Google Play Console）

2026-09-10 作成。iOS 版 1.4.4 相当を Android で出すための手順と、コード側の残作業。
App Store 側の値は [appstore_metadata.md](appstore_metadata.md) を参照（説明文・審査メモは流用できる）。

## 0. 前提（現状の Android プロジェクト）

- `app/android/` は構成済み。applicationId `jp.livecam.livecam_jp`、minSdk 26（Android 8.0）、targetSdk は Flutter 既定（35以上）
- 署名: `android/key.properties` と `upload-keystore.jks`（gitignore 対象）。**紛失すると Play へ更新できなくなるので必ず別の場所にバックアップ**
- Firebase: `android/app/google-services.json` 配置済み（FCM / Crashlytics / Analytics は iOS と同じプロジェクト livecam-jp）
- 2026-09-10 に `flutter build apk --debug` が通ることを確認（flutter_local_notifications の要求で core library desugaring を有効化）
- ホーム画面ウィジェットは Android 未対応（`WidgetBridge.supported` が iOS のみ）。初回リリースでは見送り

## 1. Play Console でアプリを作る

1. https://play.google.com/console → 「アプリを作成」
2. 入力値

| 項目 | 値 |
|---|---|
| アプリ名 | 全国ライブカメラ地図（30文字以内。iOS と同じ） |
| デフォルトの言語 | 日本語（ja-JP） |
| アプリ／ゲーム | アプリ |
| 無料／有料 | 無料（**一度「無料」にすると有料へ変更不可**） |
| 申告 | デベロッパー プログラム ポリシー・米国輸出法に同意 |

3. **新規の個人デベロッパー アカウントの場合**（2023-11 以降に作成）: 製品版へ公開する前に「クローズド テスト」で **12名以上のテスターが14日間継続**して参加する必要がある。コンソールの「アプリのダッシュボード」に要件と進捗が出るので、先にテスター（家族・知人・X のフォロワー等）の Google アカウントを集めておく。組織アカウントなら不要

## 2. 「アプリの設定」（ダッシュボードの必須タスク）

| タスク | 回答 |
|---|---|
| プライバシー ポリシー | https://kotopapa.github.io/livecam-jp/privacy.html |
| アプリのアクセス権 | 「すべての機能を制限なく利用可能」（ログイン不要） |
| 広告 | **「はい、広告を含みます」**（AdMob） |
| コンテンツのレーティング | IARC アンケート。カテゴリ「ユーティリティ、生産性、コミュニケーション、その他」→ 暴力・性的内容・薬物なし、ユーザー生成コンテンツなし、位置情報の共有なし → 全年齢相当 |
| ターゲット ユーザー | 「13歳以上」を選ぶ（子ども向け設計ではない。広告があるので「子どもを対象に含む」を選ぶと家族向けポリシーの制約が増える） |
| ニュースアプリ | いいえ |
| データ セーフティ | 下記 3. |
| 政府機関のアプリ | いいえ |
| 金融機能 | なし |
| 健康 | 該当なし |

## 3. データ セーフティの回答（プライバシーポリシー 2026-09-07 版と一致させる）

「データを収集または共有しますか」→ **はい**

| データの種類 | 収集 | 共有 | 用途 | 備考 |
|---|---|---|---|---|
| 位置情報（おおよそ／正確） | **収集しない** | | | 端末内でのみ利用し送信しない（プライバシーポリシー 2） |
| アプリのアクティビティ → アプリの操作 | 収集 | なし | 分析 | Firebase Analytics の画面表示・camera_view、Firestore の匿名閲覧カウント |
| アプリの情報とパフォーマンス → クラッシュログ、診断 | 収集 | なし | 分析 | Crashlytics |
| デバイスまたはその他の ID | 収集 | 共有（広告） | 分析、広告 | Firebase のアプリインスタンス ID、AdMob の広告 ID |
| 購入履歴 | 収集 | なし | アプリの機能 | 「開発者を応援」のアプリ内課金（Google Play Billing が処理） |

- すべて「暗号化して送信」「ユーザーが削除をリクエストできる」→ 削除はサポート URL 経由（メール）と答える
- 「必須／任意」: 分析・診断は「必須」（利用者が無効化できない）。広告 ID は「必須」

## 4. ストアの掲載情報

| 項目 | 値・制限 |
|---|---|
| アプリ名 | 全国ライブカメラ地図（30） |
| 簡単な説明 | 80文字。案: 「全国約22,000台のライブカメラを地図から無料で。河川・道路・海岸の今と、雨雲・ハザードマップ・避難場所を重ねて確認。地震・警報の速報と通知にも対応」 |
| 詳しい説明 | 4000文字。App Store 用の説明文（2026-09-07 更新版）をそのまま。「App Store」「iPhone」の語が無いことを確認 |
| アプリのアイコン | 512×512 PNG（`flutter_launcher_icons` の元画像を書き出す） |
| フィーチャー グラフィック | **1024×500 必須**（iOS には無い。新規作成） |
| スマートフォンのスクリーンショット | 2〜8枚、16:9 または 9:16、最短辺 320px 以上。iPhone のスクショを流用可（Android 実機で撮り直すのが望ましい） |
| 7インチ／10インチ タブレット | 任意。タブレット対応を掲載するなら各1枚以上 |
| カテゴリ | 「天気」（iOS と同じ） |
| タグ | 天気、地図、災害 |
| 連絡先 | メールアドレス必須。ウェブサイト https://kotopapa.github.io/livecam-jp/ |

## 5. アプリの完全性（署名）

- 「Play アプリ署名」は既定で有効。**アップロード鍵 = `upload-keystore.jks`**、アプリ署名鍵は Google が保管
- 初回アップロード時にアップロード鍵の証明書が登録される。以後この鍵で署名した AAB しか受け付けない

## 6. ビルドとアップロード

```bash
cd app
flutter build appbundle --release      # build/app/outputs/bundle/release/app-release.aab
```

- versionCode は pubspec の `+N`（iOS のビルド番号と共通。Play は同じ versionCode を2回受け付けないので、iOS だけ上げた番号でも Android は次の番号を使う）
- 「テスト → 内部テスト」に AAB を上げて自分の端末で確認 → 「クローズド テスト」（新規個人アカウントは14日要件）→ 「製品版」
- 初回審査は数日かかることがある。データ セーフティと実際の SDK の挙動が食い違うと差し戻される

## 7. コード側の残作業（Play へ出す前に）

| # | 項目 | 場所 | 状態 |
|---|---|---|---|
| 1 | AdMob の Android アプリ ID とユニット ID | AndroidManifest.xml / config.dart | **済**（2026-09-10 本番IDに差し替え。アプリID ~2743659899、バナー /8466408213、レクタングル /6926095832） |
| 2 | 「開発者を応援」のアプリ内アイテムを Play Console → 収益化 → アプリ内アイテムに4件登録（ID は iOS と同じ `jp.livecam.tip.*`、消費型）。Play では**製品を有効化するために先に AAB を1本アップロード**しておく必要がある | Play Console | 未 |
| 3 | 応援画面の「EULA（Apple標準使用許諾契約）」リンクと「App Store のアプリ内課金で処理」文言を Android では Google 向けに切り替え | tip_screen.dart / ARB | **済**（2026-09-11。{store}/{vendor} 差し込み、EULA 行は iOS のみ） |
| 4 | 「App Store」「iOS の設定」を含む文言の Android 版（更新案内・招待・レビュー・通知許可の説明）。7言語 | ARB（updateRequiredBody / updateOpenStore / settingsNotifyDenied / settingsInvite* / settingsReviewSubtitle / tipNoticeBody） | **済**（2026-09-11。config.dart の storeName / storeVendorName を差し込む。通知許可の説明は「端末の設定」に統一） |
| 5 | ストア URL を Android では Play のものに（manifest の `store_url` は iOS 固定。`site/build.py` に `play_store_url` を追加し、アプリは Platform で使い分け） | site/build.py / manifest.dart / settings_screen.dart | **済**（2026-09-11。manifest に play_store_url、AppState.storeUrl がプラットフォームで選択） |
| 6 | 招待の QR・共有リンクも同様に Play の URL へ | settings_screen.dart | **済**（2026-09-11。_storeUrl 経由で Play の URL） |
| 7 | 通知チャンネル: FCM の既定チャンネル `bosai` はマニフェストで指定済み。Android 13+ の通知許可は flutter_local_notifications の `requestNotificationsPermission()` を使用（実装済み）。実機で通知が届くこと・タップで災害速報が開くことを確認 | notification_settings.dart | 要実機確認 |
| 8 | YouTube 埋め込み（WebView）・全画面・ピンチ拡大・位置情報許可ダイアログ・戻るボタンの挙動を Android 実機で確認 | | 要実機確認 |
| 9 | 16 KB ページサイズ対応（Play の 2025-11 以降の要件）。Flutter 3.44 と現在のプラグインは対応済みだが、Play Console のアップロード時警告を確認 | | 要確認 |
| 10 | Crashlytics の難読化マッピング: `com.google.firebase.crashlytics` Gradle プラグインが AAB ビルド時に自動アップロード（設定済み）。初回クラッシュがシンボル化されるか確認 | | 要確認 |

## 8. 公開後

- CLAUDE.md の「Push通知の運用ルール」は Android にも同じく適用（本番トピックへのテスト送信禁止）
- Android 版のバージョン更新は iOS と同じ pubspec の `version` を使う。Android だけ再提出するときも `+N` を進める
