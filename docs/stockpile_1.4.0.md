# 防災備蓄チェックリスト（1.4.0）

購買文脈のある画面としてアプリに「防災の備え（備蓄チェックリスト）」を追加した。
世帯人数から必要量を自動計算し、チェック・消費期限・リマインド通知を持つ。
各項目からバリューコマース経由で提携ショップの検索結果に飛ばし、
画面内にAdMobのレクタングル広告を1つ置いて収益化する。

## 1. 追加・変更したファイル

### 新規

| ファイル | 役割 |
|---|---|
| `app/lib/data/stockpile.dart` | モデル・必要量の計算・保存(JSON)。**必要量の出典URLはこのファイルのコメントに全部書いてある** |
| `app/lib/data/stockpile_reminders.dart` | ローカル通知（期限の1か月前・点検日）。予約内容を作る純関数 `buildReminders()` と `flutter_local_notifications` の薄いラッパ |
| `app/lib/data/affiliate.dart` | バリューコマースのリンク組み立て。規約上の注意もここに集約 |
| `app/lib/ui/stockpile_screen.dart` | 画面 |
| `app/test/stockpile_test.dart` | テスト38件 |
| `docs/stockpile_1.4.0.md` | このファイル |

### 変更

| ファイル | 変更内容 |
|---|---|
| `app/lib/config.dart` | `vcSid` / `vcMerchants`（広告主リスト）/ `vcPidPrimary` / `vcReferralEndpoint` を追加 |
| `app/lib/l10n/*.arb`（7ファイル） | `stockpile*` を86キー追加（7言語すべて翻訳済み） |
| `app/lib/l10n/l10n.dart` | `stockpileCategoryNameOf()` / `stockpileUnitNameOf()` / `stockpileItemNameOf()` を追加 |
| `app/lib/ui/settings_screen.dart` | 「開発者を応援する」カードの直下に入口の `ListTile` を追加 |
| `app/lib/ui/bosai_screen.dart` | 気象警報タブの最下部に控えめな導線（`_stockpileLink()`）。警報0件のときも出す |
| `app/pubspec.yaml` | `flutter_local_notifications: ^22.3.0` / `timezone: ^0.11.1` |
| `app/android/app/src/main/AndroidManifest.xml` | `RECEIVE_BOOT_COMPLETED` と `ScheduledNotification(Boot)Receiver`（v16以降アプリ側での宣言が必須） |

`site/` `tools/` `data/` `app/ios/LiveCamWidget/` は触っていない。

## 2. 画面の構成

```
AppBar（… メニュー → 初期状態に戻す）
├ 世帯の人数カード      大人 −/+ ・子ども −/+ ・備蓄する日数(3日分 / 7日分)
├ 必要量のめやすカード  水 XXL / 食料 XX食 ＋ 根拠の注記
├ 進捗バー             n/m 完了
├ 水・食料             保存水・非常食(主食)・レトルト食品・缶詰〔・粉ミルク〕
├ 明かり・電源          懐中電灯・乾電池・モバイルバッテリー・携帯ラジオ
│   └ ★AdMob レクタングル(300×250)  ← リストの途中・スクロールして見える位置
├ 衛生                 簡易トイレ・トイレットペーパー・ウェットティッシュ・ゴミ袋〔・おむつ〕
├ 救急・衛生用品        救急セット・常備薬・マスク・消毒液
├ 避難用               防災リュック・アルミブランケット・軍手・ロープ
├ 貴重品・情報          現金・身分証のコピー・連絡先メモ・充電ケーブル
├ ＋ 項目を追加
├ リマインド            期限の1か月前に知らせる / 点検日に知らせる
└ 注記                 参考値である旨・出典リンク2件・**アフィリエイトの明示**
```

各行は `[✓] 品名 / 必要n単位・期限チップ  [🔍探す] [⋮]`。
`⋮` から「期限を登録／期限を消す／項目を削除」。削除はSnackBarで元に戻せる。
子ども専用の品目（粉ミルク・おむつ）は子どもの人数が0のとき非表示。

広告は既存の規則どおり **特別警報の発表中は出さない**
（`AppState.specialWarningActive`）。ユニットIDは既存の `admobRectangleUnitId`。

## 3. 必要量の根拠（2026-09-01 に実際にアクセスして確認）

コード内の出典コメントは `app/lib/data/stockpile.dart` の冒頭にある。

| 数値 | 出典 |
|---|---|
| 水 1人1日 **3L** | 内閣府 広報誌「ぼうさい」83号 <https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html> 「一日一人3リットルを目安に、3日分を用意」<br>首相官邸 <https://www.kantei.go.jp/jp/headline/bousai/sonae.html> 「飲料水 3日分（1人1日3リットルが目安）」<br>農林水産省 <https://www.maff.go.jp/j/zyukyu/foodstock/imadoki/imadoki02_10.html> 「一人当たり1日3リットル…最低3日分として9リットル」<br>東京都パンフレット（令和7年10月版） <https://www.bousai.metro.tokyo.lg.jp/_res/common/bichiku/pamph_r7_11.pdf> 「1日1人3リットルが目安量です」 |
| 備蓄日数 **最低3日・可能なら1週間** | 内閣府（上記）／消防庁 <https://www.fdma.go.jp/relocation/bousai_manual/pre/preparation081.html> 「目安として最低限3日間程度」／農林水産省 <https://nippon-food-shift.maff.go.jp/foodstock/> 「まずは3日分…目標は1週間分」／東京都 <https://www.bichiku.metro.tokyo.lg.jp/why/> |
| 食料 **1人1日3食** | ⚠ 公的資料は食料について「最低3日分」とだけ示し、**食数までは規定していない**。通常の食生活に合わせて1日3食として日数から換算している（その旨をコードのコメントと画面の注記に明記） |
| 簡易トイレ 1人1日 **5回** | 経済産業省が一次出典。内閣府 広報誌「ぼうさい」111号（出典表記：経済産業省製造産業局生活製品課） <https://www.bousai.go.jp/kohou/kouhoubousai/r06/111/news_08.html> 「成人の1日の平均排泄回数は1人あたり5回」「4人家族の場合、5×4×7＝140回分」<br>経産省の原典 <https://www.meti.go.jp/policy/mono_info_service/mono/jyutaku/toirebichiku.html> は User-Agent により403を返すことがある |

**乾電池の本数・モバイルバッテリー・救急用品などには公的な数量の根拠が無い**
（東京都パンフレットも「少し多めに」「家族の人数分」など定性的な記述のみ）。
これらは「1人1個」「世帯1個」程度の常識的なめやすを置き、画面に参考値である旨
（`stockpileDisclaimer`）を出し、ユーザーが項目を追加・削除できるようにしている。

画面下部の出典リンクは 内閣府「ぼうさい」83号 と 農水省「家庭備蓄ポータル」の2件。

## 4. アフィリエイト設定（バリューコマース）

### リンクの形式

```
https://ck.jp.ap.valuecommerce.com/servlet/referral
  ?sid=<サイトID>&pid=<MyLinkのpid＝広告スペースID>&vc_url=<URLエンコードした遷移先>
```

> **pid は「広告主プログラムID」ではない**（2026-09-01 に確認）。Yahoo!ショッピングの
> プログラムID 2025875 を pid に入れると `error/invalid_link.html` へ転送される。
> pid には VC 管理画面で「広告主 → 広告作成 → MyLink → 広告スペース選択」で生成した
> コードの `pid=`（9桁。例 8926902xx）を入れる。生成コードの sid/pid と config が一致
> していても `default_banner.html` に飛ぶ場合は、その広告スペースにその広告主の MyLink
> 広告が紐付いていない（別広告主で作った・提携が未承認 等）。
>
> 動作確認（default_banner / invalid_link に飛ばず 302 で遷移先に向かえばOK）:
> `curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' 'https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=<sid>&pid=<pid>&vc_url=https%3A%2F%2Fshopping.yahoo.co.jp%2F'`

`vc_url` は遷移先URL**全体**を `Uri.encodeComponent` でエンコードする
（`?` `&` `=` `:` `/` もエンコードされる）。組み立ては
`AffiliateLinks.referral()`、検索リンクは `AffiliateLinks.searchLink()`。

### 承認後の有効化（アプリ更新不要・1.4.0）

`data/stockpile/products.json` の `merchants` 節が config の `enabled` を上書きする:

```json
"merchants": {
  "yahoo":   {"enabled": true},
  "rakuten": {"enabled": false},
  "amazon":  {"enabled": false}
}
```

楽天・Amazon の提携が承認されたら ①上の curl で `VIEW_URL` が default_banner でないことを確認
②該当キーを `true` にして `version` を現在UTCに更新 ③publish。アプリは起動時に配信JSONを読み、
`AffiliateLinks.applyRemoteFlags()` で反映する（未取得・不正値は config の既定値）。
キーは `vcMerchants.key`（yahoo / rakuten / amazon）。pid が空の店舗は true にしても出ない。

### 現在の設定（`app/lib/config.dart`）

- `vcSid = '3780235'`
- `vcPidPrimary = '892690203'`（＝先頭の広告主 Yahoo!ショッピング）

| キー | 表示名 | pid | `enabled` | 検索URL |
|---|---|---|---|---|
| `yahoo` | Yahoo!ショッピング | `892690203` | **true**（提携済み） | `https://shopping.yahoo.co.jp/search?p=<検索語>` |
| `rakuten` | 楽天市場 | `892690205` | false（審査中） | `https://search.rakuten.co.jp/search/mall/<検索語>/` |
| `amazon` | Amazon.co.jp | `892690207` | false（審査中） | `https://www.amazon.co.jp/s?k=<検索語>` |

### 「探す」の挙動

- 有効な広告主が **1つだけ** → シートを出さずその店舗を直接開く（＝いまの状態）
- 有効な広告主が **2つ以上** → 店舗選択のボトムシートを出す

判定は `AffiliateLinks.needsPickerIn()` / `soleSearchLinkIn()`。
どちらの分岐もテストで担保している（`test/stockpile_test.dart`
「有効が1つなら直接開き、2つ以上なら店舗選択シートを出す」）。

### 遵守していること

- **必ず外部ブラウザで開く**（`LaunchMode.externalApplication`）。アプリ内WebViewは
  Cookieが分離されて成果が計測されないうえ、広告主によっては規約違反になる
- **アフィリエイトの明示**は利用規約（site/terms.html 第6条「広告およびアフィリエイトプログラム」）と
  プライバシーポリシー第5条で行う。画面内の表記は 2026-09-03 のユーザー判断で撤去した
  （ARB `stockpileAffiliateNotice` も削除。配信JSONの `notice` はアプリでは表示しない）
- 未承認の広告主のリンクは出さない（`enabled: false`）
- 1×1のインプレッション用画像（`ad.jp.ap.valuecommerce.com/servlet/gifbanner`）は
  Webサイト用なので**アプリでは使わない**。計測は referral リンクで行われる

### 広告主を増やす／有効にする手順

1. バリューコマースの管理画面で提携が**承認**されたことを確認する
2. `app/lib/config.dart` の `vcMerchants` の該当行の `enabled: false` を
   **`enabled: true` に変えるだけ**（楽天・Amazonは pid 記入済み）
3. 新しい広告主を足す場合は `vcMerchants` に1行足す。検索URLの組み立て関数
   （`_yahooSearchUrl` などと同じ形）を `config.dart` に追加して `searchUrl:` に渡す
4. `flutter test test/stockpile_test.dart` を通す
   （`config の広告主は sid/pid が揃っていて…` のテストの期待値も更新する）
5. 2つ以上有効になると「探す」が自動的に店舗選択シートに変わる。コード変更は不要

## 5. 通知の実装方式

- `flutter_local_notifications` 22.3.0 ＋ `timezone` 0.11.1 の**ローカル通知**のみ。
  サーバー(FCM)は使わない
- **iOSの通知許可は、この機能のスイッチをONにしたときに初めて求める**。
  プラグインの初期化では `requestAlertPermission: false` などを渡し、
  起動時にダイアログが出ないようにしている
  （`StockpileReminderService.ensureInitialized()` / `requestPermission()`）
- FCM（`NotificationSettings`）とは iOS の同じ通知許可を共有するため、
  どちらかで許可済みなら二重にダイアログは出ない。
  **`AppDelegate.swift` は変更していない**（`UNUserNotificationCenter.current().delegate`
  を上書きすると firebase_messaging の受信経路を壊すリスクがあるため）。
  その代わり、アプリが**フォアグラウンドのとき**は端末によってバナーが出ないことがある。
  リマインドは午前9時に鳴る性質のものなので実害は小さい
- 通知IDは `reminderIdBase`(7100) 〜 7199 の専用レンジ。再予約のたびに
  このレンジだけを取り消して作り直す（`cancelAll()` は使わない）
- Android は `AndroidScheduleMode.inexactAllowWhileIdle`。
  正確な時刻は不要なので `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` は要求しない
- iOSの保留通知は64件が上限。期限リマインドは40件までに制限（`maxExpiryReminders`）

### 時刻の扱い（`docs/time_audit_2026-09-01.md` の方針）

- 消費期限は **JSTの壁時計の日付**（`yyyy-MM-dd` の素のDateTime）として保存する
- 期限の判定（`expiryStatusOf`）は `startOfDay()` / `asWallClock()` を通し、
  日付だけで比較する。壁時計と絶対時刻を混ぜない
- 「1か月前」はカレンダー上の1か月（`DateTime(y, m - 1, d)`）
- 予約だけは絶対時刻が要るので、`Asia/Tokyo` のタイムゾーンを明示して
  `tz.TZDateTime` に変換する（`tz.setLocalLocation(tz.getLocation('Asia/Tokyo'))`）

### 通知の文言

予約時の表示言語でタイトル・本文を作り込む（`_reminderText()`）。
言語を切り替えても既に予約済みの通知は前の言語のまま。
次にこの画面を開いて設定を変えると作り直される。

## 6. 保存

`SharedPreferences` のキー `stockpile_v1` に JSON 1件。サーバーは使わない。
世帯人数・備蓄日数・チェック状態・期限・削除した既定品目・カスタム項目・
リマインドのON/OFF・点検日を保持する。
チェックも期限も無い品目はJSONに書かない（容量の節約）。
壊れたJSON・未知の値は既定値にフォールバックする（`StockpileStore.decode()`）。

## 7. 多言語

新規文言は86キー。7ロケール（ja / ja_Hira / en / zh / zh_Hant / ko / vi）すべてに翻訳済み。
`@description` はテンプレート（`app_ja.arb`）にのみ置く既存ルールに従っている。
やさしい日本語は平易な語＋（かっこ）で原語を併記。
店舗名（Yahoo!ショッピング・楽天市場・Amazon.co.jp）は固有名詞なので翻訳しない。

## 8. テスト・検証結果（2026-09-01）

- `dart analyze lib test` → **No issues found!**
- `flutter test` → **236 tests passed**（うち `test/stockpile_test.dart` が38件）
- `flutter build ios --config-only` → 成功。
  `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` の
  `platforms: [.iOS("17.0")]` を確認。`flutter_local_notifications-22.3.0` が
  SwiftPMの依存に入っていることも確認

`test/stockpile_test.dart` の内容:
必要量の計算8件／期限の判定6件／リマインドの予約6件／アフィリエイトURL7件／
保存と復元5件／ARB3件／画面3件。

## 9. 残課題・注意点

- **App Store のプライバシー／審査**: 外部の購買サイトへ誘導する画面が増えたので、
  審査で「アプリ内課金の回避」と誤解されないよう、備蓄品（物理商品）の購入導線である
  ことが分かる画面構成を保つこと（デジタルコンテンツは扱わない）
- 楽天・Amazon の提携が承認されたら §4 の手順で `enabled: true` にする
- Androidの `com.google.android.gms.ads.APPLICATION_ID` はまだテストID
  （既存の未解決事項。Playへ出す前に差し替えが必要）
- カスタム項目の「探す」は入力された品名をそのまま検索語に使う
- 点検日（3/11・9/1）はいまのところ固定。ユーザーが日付を選べるようにするなら
  `StockpileState.inspectionDays` が既に `MM-dd` のリストなのでUIを足すだけでよい
