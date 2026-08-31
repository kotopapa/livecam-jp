# 時刻処理 全面点検（2026-09-01）

JST/UTC の取り違えによる「9時間ずれ」が短期間に2件実発生したため、アプリ(Dart)・
サーバー(Python)・iOSウィジェット(Swift)の時刻処理を全面点検した。

## 0. 発端となった実不具合

| 日付 | 内容 |
|---|---|
| 2026-08-30 | アメダスの `latest_time.txt`（`…+09:00`）を `DateTime.parse` した結果がUTCになり、JST前提のファイル名を組み立てて**9時間前のデータ**を読んでいた |
| 2026-09-01 | 暑さ指数(WBGT)で `HeatAlerts.nowJst()`（`DateTime.now().toUtc().add(9h)` ＝**UTCフラグ付き**）を、CSV由来の**素のDateTime**と `isAfter` で比較し、**予測が9時間先から**表示されていた |

いずれも根っこは同じで、**「絶対時刻(instant)」と「JSTの壁時計(wall clock)」の取り違え**である。

## 1. 今後の原則（これに沿っていれば事故らない）

時刻の値は次の**2種類しか作らない**。混ぜたら必ずどちらかに寄せる。

### (a) 絶対時刻 / instant

その瞬間を指す値。`DateTime.now()`（ローカルフラグ）、`DateTime.parse('…Z' / '…+09:00')`（UTCフラグ）、Python の aware `datetime`。

- **Dart の `isAfter` / `isBefore` / `difference` はエポック値で比較する**ので、
  ローカルフラグとUTCフラグを混ぜて比較しても**正しい**。ここは誤解しやすい。
- 表示するときは必ず `toLocal()`（または明示のTZ変換）を通す。
  **UTCフラグ付きの値の `.hour` / `.month` をそのまま表示してはいけない。**
- Python では naive と aware を比較すると `TypeError`。片方だけ naive にしない。

### (b) JSTの壁時計 / wall clock

「日本時間で何年何月何日何時」という**フィールドの入れ物**。Dart では**素の(naive) DateTime**、
Python では JST の aware `datetime`（`.astimezone(JST)` 済み）で表す。

- 用途は **URL・ファイル名の組み立て**と、**日本時間で書かれた素の日時との比較**だけ。
- Dart の素の DateTime は「端末TZの壁時計」として解釈されるため、
  **絶対時刻としては正しくない**。`DateTime.now()` と `difference` してはいけない。

### 禁止パターン

```dart
// ❌ UTCフラグが付いたままエポックが9時間先にずれた値になる
final now = DateTime.now().toUtc().add(const Duration(hours: 9));
if (csvValue.isAfter(now)) { ... }   // ← 9時間ずれる（2026-09-01 実発生）

// ✅ 壁時計が欲しいなら jstNow()、絶対時刻が欲しいなら DateTime.now()
```

Dart 側の実装は **`app/lib/util/jst.dart`** に集約した。
`jstNow()` / `toJstWallClock()` / `jstWallClockToUtc()` / `asWallClock()` /
`addDays()` / `daysBetween()` / `jstDayKey()`。

### データ源ごとの時刻の基準（取り違えやすい）

| データ源 | 基準 |
|---|---|
| 気象庁 タイル `basetime` / `validtime`（`yyyyMMddHHmmss`） | **UTC** |
| 気象庁 `quake/list.json` の `at` / `rdt` | `+09:00` 付き（`DateTime.parse` は**UTCフラグ**で返す） |
| 気象庁 アメダス `latest_time.txt` / `map/<key>.json` のファイル名 | **JST** |
| 環境省 熱中症警戒情報 `alert_<YYYYMMDD>_<HH>.csv` のファイル名 | **JST** |
| 環境省 WBGT 予測/実況CSVの中身 | **JST・オフセット無し（素の日時）** |
| kawabou のファイル名 | **JST** |
| 自前 `status.json` の `last_ok_at` / `generated_at` | UTC（`+00:00` / `Z`） |
| 自前 `status.json` の `image_time` | **JST・オフセット無し**（1,723台が該当） |

## 2. 点検結果サマリ

| 分類 | Dart(app) | Python(tools/monitor/site/crawler) | Swift(widget) | 計 |
|---|---|---|---|---|
| 高（実際に不具合） | 1 | 2 | 0 | **3** |
| 中（将来危ない） | 7 | 7 | 0 | **14** |
| 低（問題なし・記録のみ） | 9 | 9 | 3 | **21** |

---

## 3. Dart（`app/lib/`）

### 高

#### H-1. 震源・津波の「M月D日 H時頃」が9時間ずれる — `lib/ui/bosai_screen.dart:615`

```dart
return l10n.bosaiTimeMonthDayHour(at.month, at.day, at.hour);
```

`at` は気象庁 `list.json` の `"2026-08-31T18:49:00+09:00"` を `DateTime.parse` したもので
**UTCフラグ付き**。エポック値は正しいので直前の相対表記（`difference`）は正しく出るが、
`.month` / `.day` / `.hour` を直接読むと**UTCの値**になる。
防災タブの地震・津波一覧は72時間分を保持するため、**24時間より古い全エントリで
「9時間前・日付も前日にずれた」時刻が表示されていた**（日本の端末でも発生）。
地図側（`map_screen.dart`）は同じ値を `toLocal()` してから表示しており、
**同じ地震が画面によって9時間違う**状態だった。

**修正**: `at.toLocal()` を通してから表示。あわせて `_when()` の本体を
テスト可能なトップレベル関数 `formatQuakeWhen()` に切り出した。

### 中

#### M-1. 取得時刻の相対表記が日本以外の端末でずれる — `lib/util/time_format.dart:14`

オフセット無しの文字列（＝提供元のJST表記。`status.json` の `image_time`、1,723台）を
**端末ローカル**として扱い、`DateTime.now()`（端末ローカル）と引き算していた。
端末TZが日本以外だと差がTZオフセット分ずれ、「◯分前」が出ない／誤った値になる。

**修正**: オフセット付き（UTCフラグ）は従来どおり `toLocal()` と `DateTime.now()` で処理。
オフセット無しは**表示はJSTの壁時計そのまま**（＝日本の端末で見た目は完全に不変）、
比較の「今」だけ `jstNow()` にした。

#### M-2. 端末の画像読込時刻がオフセット無しで出力されていた — `lib/ui/detail_screen.dart:176`

`_imageLoadedAt.toIso8601String()` は**端末ローカルの素の値**なのでオフセットが付かず、
M-1 の修正後は「提供元のJST」として解釈されてしまう。
**修正**: `.toUtc().toIso8601String()`（末尾 `Z`）で渡す。日本の端末では表示不変。

#### M-3. `nowJst()` が「UTCフラグ付きでエポックが9時間先」の地雷値 — `lib/data/heat_alert.dart:176`

2026-09-01 の不具合の当事者。当時の修正で `nowJstNaive()` を追加して急場は
しのいでいたが、`nowJst()` 自体が残っており呼び出し側（`bosai_screen.dart` 3箇所）は
まだそちらを使っていた。現状はたまたまフィールド参照しかしていなかったため
実害は出ていなかったが、次に誰かが比較に使えば同じ事故が起きる。

**修正**: `nowJst()` を**削除**し、`nowJstNaive()` を `jstNow()`（`lib/util/jst.dart`）への
委譲に一本化。`bosai_screen.dart` の3箇所を `nowJstNaive()` に差し替え。
さらに受け取り側（`Wbgt.upcoming` / `loadMaster` / `fetchPoint` / `parseMaster` /
`HeatAlerts.candidateUrls`）で `asWallClock()` を通し、
**万一UTCフラグ付きを渡されても壁時計として読み直す**保険を入れた。

#### M-4. `jmaTimeToJst()` が同じ地雷値を返していた — `lib/data/jma_layers.dart:68`

`DateTime.utc(...).add(9h)` は**UTCフラグのままエポックが9時間先**。
`NowcastTime.validAtJst` / `RiskTime.validAtJst` としてレーダーのスライダーで
`difference` に使われていた（同じ基準どうしなので偶然打ち消し合って正しかった）。

**修正**: 絶対時刻用の `jmaTimeToUtc()` / `NowcastTime.validAt` / `RiskTime.validAt` を新設。
`jmaTimeToJst()` は**素のDateTime（壁時計）**を返すよう変更し、表示専用にした。
スライダーの差分計算（`map_screen.dart:1031`）は `validAt` に切り替え。

#### M-5〜M-7. `Duration(days: n)` によるカレンダー演算（夏時間のある端末で破綻）

`DateTime.add(Duration(days: 1))` は**絶対時間の加算**なので、DSTのあるTZの端末では
23時間／25時間になり、日付が動かない・時刻がずれる。日本にDSTは無いが、
**端末TZは日本とは限らない**（en/ko/vi/zh 対応済みのため海外ユーザーがいる）。

| 箇所 | 内容 |
|---|---|
| `heat_alert.dart` `candidateUrls` | 前日17時のフォールバックURL（`subtract(Duration(days:1))`）→ `addDays()` |
| `heat_alert.dart` `byPrefecture` | 「翌日」の判定 → `DateTime(y, m, d+1)` |
| `wbgt.dart` `upcoming` | 「翌日24時」の上限 → `DateTime(y, m, d+2)` |
| `bosai_screen.dart` `_wbgtTimeLabel` | 当日/翌日の判定 `day.difference(today).inDays` → `daysBetween()` |

`_wbgtTimeLabel` はテスト可能なトップレベル関数 `wbgtTimeLabel()` に切り出した。

#### M-8. ランキング送信の最終送信時刻が端末TZ変更で狂う — `lib/data/global_stats.dart:172`

`_lastFlush` を `toIso8601String()`（ローカルの素の文字列）で保存し、次回起動時に
`DateTime.tryParse` でローカルとして読み直していた。端末のTZを変えると送信抑制
（`_minFlushInterval`）の判定がずれる。
**修正**: `toUtc().toIso8601String()`（末尾 `Z`）で保存。読み出しは `DateTime.tryParse` の
ままでよい（`Z` なら絶対時刻、無ければ旧形式としてローカル解釈）。
あわせて JST日付キーの組み立てを `jstDayKey(jstNow())` に集約。

### 低（問題なし。記録のみ）

| 箇所 | 判断 |
|---|---|
| `jma_layers.dart:430` アメダス `latest_time.txt` | 2026-08-30 の修正済み。`.toUtc().add(9h)` の結果をフィールド参照だけに使っており正しい |
| `jma_layers.dart:294` `fetchQuakes` の `since` | `DateTime.now()`（ローカル）と `DateTime.parse('…+09:00')`（UTC）の比較。**Dartはエポックで比較するので正しい** |
| `bosai_screen.dart:530` 地震・津波の72時間フィルタ | 同上 |
| `map_screen.dart:430` 震源リストの日時 | `q.at.toLocal()` 済み。正しい |
| `bosai_screen.dart:751` 警報の最終取得時刻 | `DateTime.now()` を `toLocal()`（no-op）。正しい |
| `bosai_screen.dart:890` 熱中症の発表時刻 | `reportAt` はCSV由来の素のDateTime。フィールド参照でよい |
| `cache_store.dart` / `camera_repository.dart` | `_now()` が `DateTime.now().toUtc()`、保存も末尾 `Z`、比較もエポック。一貫して正しい |
| `view_history_store.dart` | 全てエポックms。TZ非依存 |
| `widget_bridge.dart:69` `generated_at` | `.toUtc().toIso8601String()`。正しい |
| `detail_screen.dart` / `list_screen.dart` / `facility_layers.dart` / `shelter_layers.dart` | クールダウン・再試行の間隔。ローカルどうしの引き算で完結 |
| `app_state.dart` 他のキャッシュバスター | `millisecondsSinceEpoch`。TZ非依存 |

---

## 4. Python（`tools/` `monitor/` `site/` `crawler/`）

### 高

#### H-2. 地震通知が例外で全滅し得る／通知本文が9時間ずれ得る — `tools/bosai_notify.py:137`

```python
at = datetime.fromisoformat(best.get("at") or "1970-01-01T00:00:00+09:00")
```

気象庁の `at` からオフセットが欠けると **naive** になり、`since = datetime.now(JST) - 3h`
（aware）との比較で `TypeError` → `check_quakes` が例外を投げ、
**bosai_notify のプロセスごと落ちて地震・特別警報の通知が全滅する**。
`Z` 表記で来た場合は `at.strftime('%H:%M')` がUTC時刻をそのまま本文に出し、
**通知文が9時間ずれる**。

**修正**: `parse_jma_time()` を追加。`Z` を `+00:00` に正規化 → `fromisoformat` →
naive はJSTとみなし → **常に `.astimezone(JST)` して返す**。
解釈不能値は epoch(JST) を返して「古い地震」扱いにし、例外を投げない。

#### H-3. 避難所データの Last-Modified 比較が常に失敗し得る — `tools/shelters.py:263`

```python
dt = datetime.strptime(v, "%a, %d %b %Y %H:%M:%S %Z")
```

(a) 曜日・月名が **`LC_TIME` ロケール依存**（`ja_JP` 等では必ず `ValueError`）、
(b) `%Z` は tzinfo を設定せず **naive** を返す、(c) `+0900` のような数値オフセット表記に
マッチせず `ValueError`。結果 `_latest()` が「最初の非空が勝つ」に劣化し、
**新旧判定を誤って再生成をスキップ／余計に実行する**。

**修正**: `parse_http_date()` を追加し、ロケール非依存で aware を返す
`email.utils.parsedate_to_datetime` へ移行。RFC2822 の `-0000` は naive で返るためUTC扱い。
戻り値は従来どおり元の文字列なので**出力フォーマットは不変**。

### 中

| ID | 箇所 | 内容と修正 |
|---|---|---|
| M-9 | `crawler/main.py:141` | `date.today()` が台帳の `first_seen` / `last_updated` になる。**GitHub Actions ランナーはUTC**なので JST 00:00〜09:00 の実行で前日日付が入る。`crawl.yml` は金 18:00 UTC = 土 03:00 JST 実行で**現に毎回この窓に入っていた**。→ `jst_today()` を追加して全廃 |
| M-10 | `tools/crawl_kawabou_all.py:69` | 同上。→ `jst_today()` |
| M-11 | `tools/review_cli.py:193, 235` | `review.reviewed_at` が同様。ローカル実行ならJSTだがUTC環境で前日日付。→ `jst_today()` |
| M-12 | `monitor/main.py:74, 83` | `LOW_FREQ_HOURS_UTC` と `now.hour` を直接比較し、**呼び出し側がUTCを渡すことに暗黙依存**。→ `LOW_FREQ_HOURS_JST = (3, 9, 15, 21)` に変更し、`now` を必ずJSTへ変換してから判定（**判定結果は従来と完全に同一**、TZ非依存になっただけ） |
| M-13 | `monitor/freeze.py:76` | `is_local_daytime` が `now.astimezone(utc).hour` と**変換前の** `now.minute` を混ぜていた。かつ naive を `astimezone()` に渡すと**プロセスのローカルTZで解釈**され、JST開発機とUTCランナーで9時間ずれる（黒画像の日中判定＝障害検知の可否が環境で変わる）。→ `as_utc()` で一度変換した値から hour/minute の両方を取る |
| M-14 | `monitor/freeze.py:124` / `monitor/check.py:178, 252` | `fromisoformat()` の aware/naive を意識せず `now` と減算。state（`monitor/.state/hashes.json`）は現状 796,990件すべて aware で無事だが、オフセット無しが1件混ざると `TypeError` で該当カメラの監視が落ちる。→ `parse_utc()` / `as_utc()` で両辺を正規化 |
| M-15 | `monitor/check.py:120-122` | `_stale_last_modified` が `lm` だけ補正し `now` は無補正。naive な `now` で `TypeError`。→ 両辺 `as_utc()` |

### 低（問題なし。記録のみ）

| 箇所 | 判断 |
|---|---|
| `tools/aggregate_ranking.py:87, 96, 120, 125, 132` | 前日/当日/cutoff/updated すべて `datetime.now(JST)` で一貫。`ranking.yml` の cron `30 17 * * *` = JST 02:30 で「前日分の確定」も整合 |
| `site/build.py:110-114` | `jst` で `now` / `yesterday` / 当日経過割合を計算しており正しい |
| `monitor/freeze.py:84-108` `sunrise_utc` | UTC日付基準は意図通り。`(now.date(), now.date()-1)` の2日走査で「直近のJSTの日の出」を必ず含む。日々の変化は約1分で±1時間窓に対し無害 |
| `version` / `generated_at` の UTC `"…Z"` 出力（`crawler/main.py:200`、`monitor/main.py:425`、`tools/review_cli.py:45`、`facilities.py:954`、`shelters.py:311`、`hazard_check.py:172`、`crawl_kawabou_all.py:61`） | すべて aware UTC → 文字列化のみ。アプリ側も等値比較しかしない |
| `tools/crawl_kawabou_all.py:45` `log()` | 実行ログの見た目のみ。据え置き |
| `crawler/sources/yamaguchi_kasen.py:71-74` | JSTの壁時計文字列を `strptime` → `-10min` → `strftime` するだけでTZ変換を挟まずプロセスTZ非依存。`_iso_from_slot` も `+09:00` を明示付与 |
| `crawler/sources/shimanto_kasen.py:29` / `mlit_roadinfo.py:77-78` | 12桁JST文字列の整形と固定長文字列の `max()` 比較のみ。datetime 化していない |
| `tools/facilities.py:334` | openpyxl のセル値（Excel由来 naive）を `isoformat()` するだけの表示用変換 |

---

## 5. Swift（`app/ios/LiveCamWidget/`）

**問題なし（低のみ）**。

- `TimeText.hm` / `TimeText.mdhm`（`SharedStore.swift:53-68`）は
  `f.timeZone = TimeZone(identifier: "Asia/Tokyo")` と `Locale("ja_JP")` を明示しており、
  端末TZ・ロケールに依存しない。
- `JmaClient.parseQuakes`（`JmaClient.swift:157`）は `ISO8601DateFormatter` で
  `at` を **`Date`（絶対時刻）** にしてから `since` と比較。Swift の `Date` は
  TZを持たない絶対時刻なので、Dart のようなフラグ取り違えは構造的に起きない。
- `FavoriteCamerasWidget` の `updated_at`（JSTの素の文字列）は**現状レンダリングしていない**。
  将来表示するなら Asia/Tokyo 固定のフォーマッタで扱うこと。

---

## 6. 追加したテスト

### Dart（`app/test/` 新規2ファイル・既存2ファイル更新）

- **`jst_test.dart`（新規・10件）** — `lib/util/jst.dart` の全関数。
  壁時計が素のDateTimeであること、`toJstWallClock` の逆変換、
  `asWallClock` が「UTCフラグ付きの壁時計もどき」を安全に読み直すこと、
  `addDays` / `daysBetween` が**米国の夏時間切替日（2026-03-08 / 2026-11-01）を
  またいでも壊れない**こと、`jstDayKey` の日付境界（`15:00Z` = 翌日JST）。
- **`time_audit_test.dart`（新規・15件）** — 実不具合の回帰。
  H-1（`formatQuakeWhen` が `toLocal()` 済みの日時を出す）、
  M-1/M-2（`formatTakenTime` のオフセット有無の分岐）、
  M-3（`Wbgt.upcoming` / `HeatAlerts.candidateUrls` に**旧 `nowJst()` 相当の
  UTCフラグ付き値を渡しても9時間ずれない**）、M-4（`validAt` と `validAtJst` の役割分担）、
  M-7（`wbgtTimeLabel` の当日/翌日判定）。
- **`risk_layers_test.dart`（更新）** — `validAtJst` が素のDateTimeになった件の期待値更新＋
  `validAt` の差が実時間差であることの確認を追加。
- **`time_format_test.dart`（更新）** — 「直近の時刻には相対表記が付く」を
  端末ローカルではなく `jstNow()` から組み立てるよう修正（オフセット無し＝JSTという契約に合わせた）。

### Python（新規3ファイル・既存2ファイル追記／新規20件）

- **`monitor/tests/test_timezone_safety.py`（新規・8件）** —
  `_skip_low_freq` がどのTZの `now` を渡してもJSTの枠で判定されること／4枠すべて／
  `is_local_daytime` がプロセスTZ非依存であること／分の取り違えがないこと／
  `as_utc` `parse_utc` の正規化／`judge_frozen` と `_stale_last_modified` が
  naive を渡されても落ちないこと。
- **`crawler/tests/test_jst_today.py`（新規・3件）** /
  **`tools/tests/test_jst_today.py`（新規・4件）** —
  `datetime` を UTC 8/31 20:30（= JST 9/1 05:30）に固定し、
  `jst_today()` が**ランナーのUTC日付ではなく日本の日付**を返すことを検出。
- **`tools/tests/test_bosai_notify.py`（追記・3件）** —
  `parse_jma_time` が常にJSTを返すこと／`Z` 表記でも通知本文の時刻がJSTになること／
  naive な `at` でクラッシュしないこと。
- **`tools/tests/test_shelters.py`（追記・2件）** —
  `parse_http_date` が aware かつロケール非依存であること／異なるTZ表記をまたいだ `_latest` 比較。

TZ非依存の担保は、Python 側が `os.environ["TZ"] + time.tzset()` の
コンテキストマネージャ（UTC / Asia/Tokyo / America/Los_Angeles を切替）、
Dart 側は**テスト自体をTZ非依存に書いたうえで、スイート全体を複数TZで実行**して確認した。

## 7. テスト結果

```
# Dart
dart analyze lib test                  → No issues found!
TZ=Asia/Tokyo          flutter test    → 198 passed   (点検前は 172)
TZ=UTC                 flutter test    → 198 passed
TZ=America/Los_Angeles flutter test    → 198 passed   (夏時間あり・UTC-8/-7)
TZ=Pacific/Kiritimati  flutter test    → 198 passed   (UTC+14)

# Python
TZ=Asia/Tokyo          pytest crawler/tests monitor/tests tools/tests → 247 passed
TZ=UTC                 pytest 〃                                       → 247 passed
TZ=America/Los_Angeles pytest 〃                                       → 247 passed
                                                       (点検前は 227)
```

既存テストの期待値変更は Dart の2ファイルのみ（いずれも今回の仕様変更に伴う正当な更新）。
Python は既存テストの書き換えゼロ。

## 8. 表示への影響

**日本時間の端末では、H-1 の修正以外に見た目の変化はない。**

- H-1: 防災タブの地震・津波一覧で、**24時間より古いエントリの日時が9時間ぶん正しくなる**
  （これは修正が目的の変化）。地図側の表示と一致するようになった。
- M-1 / M-2: 日本の端末では表示文字列は完全に同一。海外TZの端末でのみ相対表記が正しくなる。
- その他は内部表現の整理で、出力・表示は不変。

## 9. 残課題

1. **`jst_today()` が3ファイルに重複**（`crawler/main.py` / `tools/crawl_kawabou_all.py` /
   `tools/review_cli.py`）。それぞれ独立したエントリポイントなので今回は重複を許容した。
   共有モジュール（例: `crawler/timeutil.py`）へ寄せるかは要判断。
2. **`.github/workflows/facilities.yml:5` / `shelters.yml:5` のコメントと実挙動のずれ**。
   cron `0 19 1 * *` / `0 18 1 * *` はコメントの「毎月1日 JST 04:00 / 03:00」に対し、
   実際は**毎月2日**の JST 04:00 / 03:00 になる（1日にするには前月末日を指定する必要がある）。
   月次の全件再生成ジョブなので実害はなく、今回は報告に留めた。
3. **`FavoriteCamerasWidget` の `updated_at`** は現状レンダリングしていない。
   将来ウィジェットに撮影時刻を出すなら、`image_time` がJSTの素の文字列である点に注意し、
   Asia/Tokyo 固定のフォーマッタで扱うこと。
4. **`monitor` の state に古い naive 記録が混ざる可能性**は `parse_utc()` で吸収済みだが、
   `hashes.json` は 55MB・796,990件と大きい。将来スキーマを触るときに
   タイムスタンプ形式を明示的に統一しておくとよい。
