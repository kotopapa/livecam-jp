# 次に追加する防災機能の調査（2026-08-31）

調査者: Claude Code（調査のみ。`app/` 配下は未変更、コミットなし）
アクセス条件: User-Agent `LiveCamJP/1.0 (+https://kotopapa.github.io/livecam-jp/)`、1req/s以下。
本書のURL・応答例は**すべて実際に curl で叩いて確認したもの**。確認できなかったものは「取得失敗」と明記した。

## 0. 現状（重複判定の基準）

すでにアプリが持っている防災機能:

| 既存機能 | 実装場所 | データ源 |
|---|---|---|
| 雨雲レーダー（過去3h〜1h先ナウキャスト＋6h先短時間予報） | `app/lib/data/jma_layers.dart` | `jmatile/data/nowc`, `jmatile/data/rasrf` |
| 24時間降水量（面タイル＋アメダス点） | 同上 | `rasrf24h`, `bosai/amedas` |
| 震源分布（24h/7d/30d） | 同上 | `bosai/quake/data/list.json` |
| ハザードマップ4種（洪水・土砂・津波・高潮） | `app/lib/data/hazard_layers.dart` | 国土地理院 `disaportaldata.gsi.go.jp/raster` |
| 指定緊急避難場所・指定避難所（14万件） | `app/lib/data/shelter_layers.dart` + 自前配信 `/v1/shelters/` | 国土地理院 指定緊急避難場所データ |
| 災害速報タブ（地震・津波・気象警報/注意報 → 周辺カメラ） | `app/lib/ui/bosai_screen.dart` | `quake/list.json`, `tsunami/list.json`, `warning/data/r8/map.json` |
| プッシュ通知（震度5弱以上・特別警報・危険警報、地域別トピック） | `tools/bosai_notify.py` + FCM | 同上 |

→ **面（タイル）としての「雨」と「ハザード」、点としての「震源」「避難場所」、リストとしての「警報」は充足している。**
空いているのは **(1) 危険度の空間分布＝キキクル、(2) 河川そのものの状態＝洪水予報・水位、(3) 地震の面的な影響＝市区町村別震度** の3方向。

---

## 1. 気象庁（jma.go.jp）系の候補

### 1.0 利用規約の判定（この節すべてに共通）

`https://www.jma.go.jp/jma/kishou/info/coment.html`（HTTP 200 で取得）原文:

> 　気象庁ホームページで公開している情報（以下「コンテンツ」といいます。）は、権利表記の記載がない限り「公共データ利用規約（第1.0版）」に準拠した利用条件の下で、利用することができます。
>
> (1)　出典の記載について
>     コンテンツを利用する際は出典を記載してください。出典の記載方法は以下のとおりです。
>     （出典記載例）
>     出典：気象庁ホームページ　（当該ページのURL）
>
> (2)　個別法令による利用の制約があるコンテンツについて
> 　一部のコンテンツには、個別法令により利用に制約がある場合があります。特に、以下に記載する法令についてはご注意ください。
>   気象業務法（e-Govのサイトに移動）
>       第十七条第一項に基づく気象庁ホームページの利用に当たっての制約（予報業務の許可）について
>       第二十三条に基づく気象庁ホームページの利用に当たっての制約（警報の制限）について
>
> (3)　本利用ルールが適用されないコンテンツについて
>   組織や特定の事業を表すシンボルマーク、ロゴ、キャラクターデザイン。
>   具体的かつ合理的な根拠の説明とともに、別の利用ルールの適用を明示しているコンテンツ。

**判定: 可（出典明記が条件。SPEC C5 と同じ運用）。** ただし2点の設計制約が付く:

- **気象業務法17条（予報業務の許可）** — 気象庁の予報をそのまま提示するのは可。**アプリが独自に「この後こうなる」と予報を作って出すのは不可**。→ 観測値・気象庁発表値の再掲に留め、閾値超過の判定はあくまで「気象庁/河川管理者が定めた基準値を観測値が超えた」という事実の提示にする。
- **気象業務法23条（警報の制限）** — 気象庁以外が「警報」を出してはならない。→ プッシュ通知の文面で「〇〇警報を発表しました（気象庁）」のように**発表主体を必ず明記**し、アプリ独自の警報名を作らない。既存の `tools/bosai_notify.py` の方針と同じ。

---

### 1.1 キキクル（危険度分布）タイル ★推奨A

- **機能名**: 土砂・浸水・洪水キキクルの地図レイヤー（＋危険度の高い地域のカメラ導線）
- **利用者の価値**: 既存の雨雲レーダーは「今どこに雨が降っているか」しか分からない。キキクルは「その雨で**どこが危ないか**」を1kmメッシュ／河川区間ごとに示す、気象庁の防災情報の中核。「危ない場所を見る」＝ライブカメラを開く動機そのもの。
- **データ源**:
  - 時刻一覧: `https://www.jma.go.jp/bosai/jmatile/data/risk/targetTimes.json`（HTTP 200 / 8,224 B）

    ```json
    [
      {"basetime": "20260831024000", "validtime": "20260831024000", "member": "immed0",
       "elements": ["land","inund","flood_mesh","rain_mesh","flood","designated_river",
                    "inland_flood","designated_river_nation","flood_riskline"]},
      {"basetime": "20260831023000", "validtime": "20260831023000", "member": "immed1", "elements": [...]},
      ...
      {"basetime": "20260830204000", "validtime": "20260830204000", "member": "none",  "elements": [...]}
    ]
    ```
    - エントリ37件＝**10分刻みで過去約6時間**。最新3件だけ `member` が `immed0/1/2`、それ以前は `none`。
    - `basetime == validtime` のみ（**予測時刻のエントリは無い**＝実況のみ）。
  - タイル: `https://www.jma.go.jp/bosai/jmatile/data/risk/{basetime}/{member}/{validtime}/surf/{element}/{z}/{x}/{y}.png`
    - 確認済み: `.../risk/20260831024000/immed0/20260831024000/surf/land/12/3637/1614.png` → **200 / image/png / 334 B**
    - 同様に `inund` / `flood` / `flood_riskline` / `designated_river` / `rain_mesh` すべて 200。
    - `member` を `none` にすると最新エントリでは **404**（member はエントリの値をそのまま使うこと）。
    - ズームは z3〜z15 まですべて 200 を確認（気象庁自身の表示範囲は `jmatile.properties` で `minZoom 4 / maxZoom 14`）。
  - element の意味: `land`＝土砂キキクル、`inund`＝浸水キキクル、`flood`＝洪水キキクル（河川線）、`designated_river` / `designated_river_nation`＝指定河川洪水予報の対象河川、`flood_riskline`＝洪水危険度の流路線、`rain_mesh`／`flood_mesh`＝根拠メッシュ。
- **更新頻度**: 10分。
- **規約**: 可（1.0 の判定に同じ）。出典「出典：気象庁ホームページ https://www.jma.go.jp/bosai/risk/ 」。
- **実装規模**: **小〜中（3〜5日）**。既存 `NowcastTime` とまったく同じ構造（targetTimes → タイルURL組み立て → `flutter_map` の `TileLayer`）で、`MapLayerKind` に `kikikuruLand / kikikuruInund / kikikuruFlood` を足すだけ。時間スライダも既存の雨雲UIを流用可。
- **既存機能との関係**: 雨雲レーダーの直接の上位互換ではなく**補完**（雨＝原因、キキクル＝結果）。ハザードマップ（静的な想定）とも別物（キキクルは「今」）。重複なし。
- **注意点**: 確認時（2026-08-31 12:00 JST）は全国的にほぼ無降水（アメダス1時間降水量の全国最大が 2.0mm）だったため、**取得できたタイルはすべて透明の 334 B**。凡例の配色（注意=黄／警戒=赤／危険=紫／災害切迫=黒紫）は、既存の `rain24hScale` を決めたときと同じ手順で **降雨時に実タイルの画素をサンプリングして確定すること**。推測で色を入れない。
- **推奨度: A**

### 1.2 指定河川洪水予報（氾濫危険情報など） ★推奨A（1.1とセット）

- **機能名**: 「氾濫危険情報が出ている河川」一覧＋その河川のカメラへの導線＋プッシュ通知
- **利用者の価値**: 本アプリのカメラの過半は河川カメラ。「多摩川に氾濫危険情報」→「多摩川のカメラを今すぐ見る」は、このアプリでしか成立しない導線。
- **データ源**:
  - `https://www.jma.go.jp/bosai/flood/data/r8/flood_xml.json` → **HTTP 200 / 3 B / `[]`**
    （確認時に発表中の洪水予報が全国で0件だったため中身が空。**発表時のフィールド構造は未確認**。要・出水期の再確認）
  - `https://www.jma.go.jp/bosai/flood/data/r8/flood_pdf.json` → 200 / 69,938 B。実物のレコード:

    ```json
    [{"filename":"350036001900_20260525050000_s00.pdf","reportDatetime":"2026-05-25T05:00:00Z",
      "riverCode":"350036001900","teiseiNumber":"00","infoType":"訓練","pdfKbSize":299}, ...]
    ```
    → PDF本体は `https://www.jma.go.jp/bosai/flood/data/r8/pdf/{filename}`。**PDFはアプリでは使わない**（表示に向かない）。
  - `https://www.jma.go.jp/bosai/flood/const/river_order.json` → 200 / 6,379 B。`{"810101000100":8, "810101008500":10, ...}` の河川コード→表示順マップ。河川コードの一覧として使える。
  - `https://www.jma.go.jp/bosai/flood/const/no_flood.json` → 200 / 10,650 B。洪水予報河川を持たない地域コードの一覧（`{"class10s":["014010","017010",...]}`）。「この地域は対象外」の説明に使える。
  - `https://www.jma.go.jp/bosai/flood/const/explain.txt` → 200 / 4,045 B。**2026年新体系の段階名と警戒レベルの対応が原文で取れる**:

    > レベル５氾濫特別警報・・・【警戒レベル５相当】
    > レベル４氾濫危険警報・・・【警戒レベル４相当】
    > レベル３氾濫警報・・・・・【警戒レベル３相当】
    > レベル２氾濫注意報・・・・【警戒レベル２】
    >
    > レベル４氾濫危険警報：地元の自治体が警戒レベル４避難指示を発令する目安となる情報です。（略）避難指示が発令されていなくても自ら避難の判断をしてください。
    >
    > 国や都道府県が管理する河川のうち、流域面積が大きく、洪水により大きな損害を生ずる河川については、国土交通省または都道府県と気象庁が共同で、河川を指定して洪水予報を行っています。

    → アプリ内の説明文とプッシュ文面はこの原文をそのまま使えばよい（自前の言い換えをしない＝気象業務法23条対策にもなる）。
  - 面での表現なら 1.1 の `designated_river` / `designated_river_nation` タイルで代替できる（こちらは今日時点で 200 を確認済み）。
- **更新頻度**: 発表・更新のつど（不定）。
- **規約**: 可（1.0 に同じ）。ただし**気象業務法23条**により「発表：気象庁・〇〇河川事務所」を必ず併記する。
- **実装規模**: 中（5日〜1週間）。難所は **河川コード↔台帳の `river_or_route` の突き合わせ**。台帳の実測（`data/cameras.json` version 2026-08-29T11:48:34Z / 21,622件）では **`category=river` が 14,044件、うち `river_or_route` 入りが 12,837件・河川名は3,165種**。表記ゆれがあるので `river_order.json` の河川コードと名寄せする対応表を `data/` に人手で作る運用が要る。指定河川洪水予報の対象は全国で数百河川なので、**対象河川だけ名寄せすれば足りる**（全3,165種を扱う必要はない）。
- **既存機能との関係**: 災害速報タブの3本目のリストとして自然に入る。プッシュは既存の `bosai_notify.py` のトピック機構をそのまま拡張できる。
- **推奨度: A**（ただし `flood_xml.json` の実データ構造の確認が前提。空配列しか見られていない）

### 1.3 地震の市区町村別震度（`int` 配列の活用） ★推奨A（最小コスト）

- **機能名**: 「この地震で震度○だった市区町村」→ その市区町村のカメラ
- **利用者の価値**: 現状の災害速報は震源の緯度経度から**距離**で周辺カメラを出している。しかし震度は距離だけでは決まらない（深発地震の異常震域など）。実際に揺れた自治体のカメラを出せるようになる。
- **データ源**: **すでに使っている** `https://www.jma.go.jp/bosai/quake/data/list.json`（200 / 550,775 B）に、未使用のフィールドがある:

  ```json
  {"ctt":"20260831033221","eid":"20260831032944","rdt":"2026-08-31T03:32:00+09:00",
   "ttl":"震源・震度情報","ift":"発表","ser":"1","at":"2026-08-31T03:29:00+09:00",
   "anm":"福島県会津","acd":"252","cod":"+37.2+139.3-10000/","mag":"2.7","maxi":"1",
   "int":[{"code":"07","maxi":"1","city":[{"code":"0736700","maxi":"1"}]}],
   "json":"20260831033221_20260831032944_VXSE5k_1.json", ...}
  ```
  - `int[].code` = 都道府県コード（`07`=福島）、`int[].city[].code` = **市区町村コード7桁**（`0736700`。頭2桁＋JIS X 0402 の下3桁に相当。台帳の `municipality`（5桁）とは桁合わせが必要）
  - さらに詳報は `https://www.jma.go.jp/bosai/quake/data/{json}` → 200 / 2,069 B（観測点レベルの震度まで入る）
  - **市区町村コードの対応を実測で確認済み**: `https://www.jma.go.jp/bosai/common/const/area.json`（200 / 262,108 B）の `class20s`（1,805件）に7桁コードが載っており、`0736700`→只見町、`1311100`→大田区、`0110000`→札幌市。**7桁コード = 台帳の `municipality`（JIS X 0402 の5桁）+ "00"**。つまり `code[:5]` で `cameras.json` の `municipality` とそのまま突き合わせられる（変換テーブル不要）。
- **更新頻度**: 発表のつど。**追加のネットワークアクセスはゼロ**（既に落としているJSONの未使用フィールド）。
- **規約**: 可。
- **実装規模**: **最小（1〜2日）**。`bosai_screen.dart` の地震詳細に「震度別の市区町村リスト」を出し、タップで既存の `NearbyCamerasScreen` を市区町村フィルタで開くだけ。
- **既存機能との関係**: 既存の「震源周辺カメラ」を置き換えずに補強する。
- **推奨度: A**

### 1.4 台風進路 ★推奨B

- **データ源**（実測）:
  - `https://www.jma.go.jp/bosai/typhoon/data/targetTc.json` → 200:

    ```json
    [{"tropicalCyclone":"TC2628","typhoonNumber":"b","category":"TD","issue":"2026-08-31T10:30:00+09:00"},
     {"tropicalCyclone":"TC2621","typhoonNumber":"a","category":"TD","issue":"2026-08-31T10:10:00+09:00"},
     {"tropicalCyclone":"TC2626","typhoonNumber":"2623","category":"LOW","issue":"2026-08-31T09:50:00+09:00"},
     {"tropicalCyclone":"TC2625","typhoonNumber":"2622","category":"TD","issue":"2026-08-31T04:05:00+09:00"}]
    ```
  - `https://www.jma.go.jp/bosai/typhoon/data/{tropicalCyclone}/specifications.json` → 200 / 3,361 B:

    ```json
    [{"part":"title","issue":{"JST":"2026-08-31T10:30:00+09:00",...},"typhoonNumber":"b","category":{"jp":"熱帯低気圧","en":"TD"}},
     {"part":{"jp":"実況","en":"Analysis"},"maximumWind":{"sustained":{"m/s":"15","kt":"30","note":"中心付近"},"gust":{"m/s":"23","kt":"45"}},
      "advancedHours":0,"category":{"jp":"熱帯低気圧","en":"TD"},"scale":"-","intensity":"-",
      "position":{"deg":[21.5,132.2],"dm":[[21,30],[132,10]],"accuracy":"ほぼ正確"},
      "location":"日本の南","course":"西北西","speed":{"note":{"jp":"ゆっくり"}},"pressure":"1000",
      "validtime":{"JST":"2026-08-31T09:00:00+09:00",...}}, ...]
    ```
    （`advancedHours` が 0/24/48/… と続き、予報円が入る）
  - 暴風域に入る確率タイル: `https://www.jma.go.jp/bosai/typhoon/data/prob50kt/targetTimes.json`（ページHTMLから参照を確認。未取得）
- **更新頻度**: 3時間（接近時1時間）。
- **規約**: 可（出典明記）。**予報円は気象庁の予報をそのまま描画するだけにする**（自前で外挿しない＝気象業務法17条）。
- **実装規模**: 中（1週間）。進路の折れ線・予報円・強風域を `flutter_map` の `CircleLayer`/`PolylineLayer` で描く。JSONの `part` 構造の場合分けがやや面倒。
- **既存機能との関係**: 重複なし。台風接近時に沿岸・港カメラへの導線になる。
- **推奨度: B**（価値は高いが、年に数回しか出番がない＝キキクルより優先度は下）

### 1.5 今後の雪（積雪深・降雪量タイル） ★推奨B

- **データ源**: `https://www.jma.go.jp/bosai/jmatile/data/snow/targetTimes.json` → 200 / 10,851 B、31件:

  ```json
  {"basetime":"20260830020000","validtime":"20260830020000",
   "elements":["snowd","amds_snowd","snowf01h","snowf01h_nd","snowf03h","snowf03h_nd","amds_snowf03h",
               "snowf06h",...,"snowf72h","snowf72h_nd","amds_snowf72h"]}
  ```
  実況エントリ25件（`amds_*` 付き＝アメダス実況込み）＋予報エントリ6件。`snowd`＝積雪深、`snowf{01,03,06,12,24,48,72}h`＝降雪量。タイルURLは他と同型で**実測確認済み**:
  `https://www.jma.go.jp/bosai/jmatile/data/snow/20260831020000/none/20260831080000/surf/snowd/8/227/100.png` → **200 / image/png / 334 B**（`snowf24h` も200）。`member` は `none`。
- **更新頻度**: 1時間。
- **規約**: 可。
- **実装規模**: 小（キキクルと同じ実装パターン。2〜3日）。
- **既存機能との関係**: 重複なし。**道路カメラ（雪みちナビ等）と強く噛み合う**が完全に季節もの。
- **推奨度: B**（12月にリリースする前提なら A）

### 1.6 天気予報（カメラ地点の天気） ★推奨B

- **データ源**: `https://www.jma.go.jp/bosai/forecast/data/forecast/{officeCode}.json`
  - 実測 `.../forecast/130000.json` → 200 / 5,367 B:

    ```json
    [{"publishingOffice":"気象庁","reportDatetime":"2026-08-31T11:00:00+09:00",
      "timeSeries":[{"timeDefines":["2026-08-31T11:00:00+09:00","2026-09-01T00:00:00+09:00","2026-09-02T00:00:00+09:00"],
        "areas":[{"area":{"name":"東京地方","code":"130010"},
                  "weatherCodes":["200","200","201"],
                  "weathers":["くもり　所により　雨", ...],
                  "winds":[...], "waves":[...]}, ...]}]}]
    ```
  - **全国1ファイル版もある（実測）**: `https://www.jma.go.jp/bosai/forecast/data/forecast/map.json` → **200 / 111,321 B**

    ```json
    [[{"reportDatetime":"2026-08-31T11:00:00+09:00",
       "timeSeries":[{"timeDefines":["2026-08-31T11:00:00+09:00","2026-09-01T00:00:00+09:00","2026-09-02T00:00:00+09:00"],
                      "areas":[{"area":{"name":"宗谷地方","code":"011000"},"weatherCodes":["211","101","200"]}]}, ...]}]]
    ```
    → 47府県ファイルを個別に引く必要がない（1リクエストで全国。C3の観点で望ましい）。
  - 地域コード表: `https://www.jma.go.jp/bosai/common/const/area.json` → **200 / 262,108 B**（`centers` 11 / `offices` 58 / `class10s` 142 / `class15s` 375 / `class20s` 1,805）。他に `forecast/const/forecast_area.json` の参照も確認（未取得）。
- **更新頻度**: 1日3回（5/11/17時）＋随時。
- **規約**: 可。予報を**そのまま**表示（加工しない）＝17条セーフ。
- **実装規模**: 小（2〜3日）。カメラ詳細画面に「この地点の天気（気象庁）」を1行。`map.json` 1本＋`area.json` のキャッシュで済む。
- **既存機能との関係**: 重複なし。防災というより体験改善（「今日この景色カメラは晴れているか」）。
- **推奨度: B**

### 1.7 噴火警報・噴火警戒レベル ★推奨C

- **データ源**（実測）:
  - `https://www.jma.go.jp/bosai/volcano/const/volcano_list.json` → 200 / 19,697 B。全火山の座標つき:

    ```json
    [{"code":"101","latlon":["44.133","145.161"],"name_jp":"知床硫黄山","name_en":"Shiretoko-Iozan"}, ...]
    ```
  - `https://www.jma.go.jp/bosai/volcano/data/warning/{code}.json` → 例 `506`（桜島）で 200 / 3,548 B:

    ```json
    {"controlTitle":"噴火警報・予報","publishingOffice":"福岡管区気象台  鹿児島地方気象台",
     "volcanoName":"桜島","headTitle":"火山名  桜島  噴火警報（火口周辺）",
     "reportDatetime":"2022-07-27T20:00:00+09:00", ...}
    ```
  - **噴火警戒レベルの全国一括サマリJSONは見つけられなかった（取得失敗）**。`data/warning/010000.json` `data/warning/00.json` `data/warning/volcano.json` `data/forecast_list.json` はいずれも 404。火山ごとに引くと111リクエストになり C3（礼儀正しいアクセス）に反する。
  - **ただし「降灰予報が出ている火山」は1リクエストで取れる**: `https://www.jma.go.jp/bosai/volcano/data/ashfall/japan.json` → **200 / 927 B**

    ```json
    {"506":{"name":"桜島","coordinate":"+3135.55+13039.40+1117/","type":"regular","reportDatetime":"2026-08-31T11:00:00+09:00"},
     "508":{"name":"薩摩硫黄島",...},"511":{"name":"諏訪之瀬島",...},"551":{"name":"霧島山（新燃岳）",...},
     "105":{"name":"雌阿寒岳",...},"503":{"name":"阿蘇山",...},"509":{"name":"口永良部島",...}}
    ```
    → 確認時点で活動中の7座。**まずこの7座だけ `data/warning/{code}.json` を引く**運用にすればリクエストは7で済む。
- **回避策**: GitHub Actions（既存の `monitor.yml` 相当）で日次に111ファイルを1req/sで巡回し、`site/v1/volcano.json` に集約して配信すれば端末側は1リクエストで済む。
- **規約**: 可。
- **実装規模**: 中（配信バッチ＋アプリ表示で5日）。
- **既存機能との関係**: 台帳に `category: volcano` のカメラがある。噴火警戒レベルとの併記は自然。ただし**更新頻度が極端に低い**（桜島の例で発表日時が2022年）。
- **推奨度: C**

### 1.8 気象庁防災情報XMLフィード（通知の拡張源） ★補助A

- **データ源**: `https://www.data.jma.go.jp/developer/xml/feed/extra.xml` → 200 / 158,362 B（Atom）。確認時のエントリ内訳:

  ```
  気象警報・注意報（Ｈ２７） 93 / 気象特別警報・警報・注意報 93 / 気象警報・注意報（Ｒ０６）（その他注意報） 47
  熱中症警戒アラート 26 / 台風解析・予報情報（５日予報）（Ｈ３０） 8 / 台風の暴風域に入る確率 4
  気象警報・注意報（Ｒ０６）（土砂） 2 / 地方気象情報 1 / 府県気象情報 1 ほか
  ```
  エントリ例:

  ```xml
  <entry>
    <title>地方気象情報</title>
    <id>https://www.data.jma.go.jp/developer/xml/data/20260831022641_0_VPCJ50_471000.xml</id>
    <updated>2026-08-31T02:26:41Z</updated>
    <author><name>沖縄気象台</name></author>
    <link type="application/xml" href="https://www.data.jma.go.jp/developer/xml/data/20260831022641_0_VPCJ50_471000.xml"/>
    <content type="text">【沖縄地方気象解説情報（発達する熱帯低気圧）】…</content>
  </entry>
  ```
  - 他に `regular.xml`（定時）/ `eqvol.xml`（地震火山）/ `other.xml` がある。
  - **洪水予報（VFDI50）・土砂災害警戒情報（VXWW50）・記録的短時間大雨情報・竜巻注意情報もこのフィード系で流れる**（確認時は該当エントリが無く、実物は未取得）。
- **位置づけ**: アプリから直接引くものではなく、**`tools/bosai_notify.py` を拡張して GitHub Actions 側で監視する**ための源。既存の r8 `map.json` ポーリングより取りこぼしが少ない。
- **規約・運用条件**: `https://xml.kishou.go.jp/xmlpull.html`（200 で取得）原文:

  > ■ダウンロード量超過時のアクセス遮断について
  > 気象庁防災情報XMLを公開しているURLに対し、1日10GB以上のダウンロードを伴うアクセスが確認された場合、アクセス元のIPアドレスを遮断します。遮断された場合、一度取得したファイルを再度取得しない等の改修をお願いいたします。
  >
  > ○高頻度フィード ※毎分更新し、直近少なくとも10分入電を掲載しております。
  > ○長期フィード ※毎時更新し、数日間の全入電を掲載しております。

  → **アプリの各端末から直接引くのは絶対に不可**（IP遮断のリスクを利用者に負わせる形になるうえ、10GB/日制限を全ユーザーで踏み抜く）。GitHub Actions の1プロセスから5分間隔で引き、取得済みの `<id>` を state に持って再取得しない実装にすること。高頻度フィードは直近10分しか載らないので**5分間隔が上限**（既存の `bosai-notify.yml` と同じ）。
- **推奨度: A（単体機能ではなく基盤）**

### 1.9 その他（確認結果のみ記録）

| 候補 | エンドポイント | 結果 |
|---|---|---|
| 気象衛星ひまわり | `https://www.jma.go.jp/bosai/himawari/data/satimg/targetTimes_jp.json` | **200 / 58,755 B**。`{"basetime":"20260829145230","validtime":"20260829145230"}` が2.5分刻み。タイルも実測済み: `https://www.jma.go.jp/bosai/himawari/data/satimg/20260829150000/jp/20260829150000/B13/TBB/5/28/12.jpg` → **200 / image/jpeg / 10,822 B**。推奨度C（防災価値より見栄え） |
| 潮位観測 | `https://www.jma.go.jp/bosai/tidelevel/const/tide_area.json` → **200 / 141,887 B**。市区町村ごとに観測点と**高潮の警戒基準値**を持つ:<br>`{"0120200":{"name":"函館市","class30s":[{"code":"01701200","standard":{"level4":130,"level5":180},"stations":[{"code":"102331","name":"函館",...}]}]}}`<br>`https://www.jma.go.jp/bosai/tidelevel/data/tide/tide_time.json` → 200（`{"time":"2026-08-31T11:34:45+09:00"}` のみ） | **実況潮位値のJSON URLは特定できなかった（取得失敗）**。`data/tide/{code}.json`・`data/tide/{yyyymmdd}/{code}.json` はいずれも404。推奨度C |
| **雷活動度・竜巻発生確度ナウキャスト** | 時刻一覧は **`https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_N3.json`（200、43件）**<br>`{"basetime":"20260831030000","validtime":"20260831040000","elements":["thns","thns_nd","trns","trns_nd"]}`<br>タイルは雨雲とまったく同じパスで element だけ差し替え:<br>`.../nowc/20260831025000/none/20260831025000/surf/thns/8/227/100.png` → **200**、`surf/trns/...` → **200** | **取得可**（`thns`＝雷活動度、`trns`＝竜巻発生確度）。`targetTimes_N1/N2` の `elements` には現れないが実体はある（`targetTimes_N3.json` が雷・竜巻用）。既存の雨雲レーダー実装をelement差し替えで再利用でき、**追加コストは最小**。推奨度B |
| 線状降水帯（`slmcs`）・落雷実況（`liden`）・10分雨量（`amds_rain10m`） | `targetTimes_N3.json` の古いエントリの `elements` に `["slmcs","slmcs_fcst","slmcs_unify","slmcs_unifyfcst","liden","amds_rain10m"]` が現れる。ただし `.../nowc/{bt}/none/{bt}/surf/slmcs/{z}/{x}/{y}.png` は **404**（`liden`・`amds_rain10m` も404） | **タイルURLは特定できず（取得失敗）**。現象が無い時刻だからか、別パスなのかは未確認 |
| 時系列情報（明日までの警報等の見通し） | `https://www.jma.go.jp/bosai/warning_timeline/data/center.json` → **200 / 65,349 B**<br>`{"reportDatetime":"2026-08-31T11:00:00+09:00","targetDatetime":"2026-08-31T12:00:00+09:00","timeSeries":[{"timeDefines":[{"dateTime":"2026-08-31T12:00:00+09:00","duration":"PT3H"},…]}]}` | 取得可。3時間刻みで明日までの警報見通し。既存の「気象警報」リストの補強に使える。推奨度C |
| 降灰予報 | 上記 `volcano/data/ashfall/japan.json` | 取得可（1.7参照） |
| 天気分布予報 | `https://www.jma.go.jp/bosai/jmatile/data/wdist/targetTimes.json` | 200 / 2,368 B。`elements:["r3","r3_nd","s3","s3_nd","temp","temp_nd","temp_point","wm","wm_nd"]`、13件（〜翌日15時）。推奨度C |
| **早期注意情報（警報級の可能性）** | `https://www.jma.go.jp/bosai/probability/data/probability/r8/map.json` → **200 / 132,449 B**（全国1ファイル）<br>`[[{"reportDatetime":"2026-08-31T11:00:00+09:00","timeSeries":[{"timeDefines":["2026-08-31T12:00:00+09:00", …計8区間…],"areas":[{"code":"011000","properties":[{"type":"大雨の警報級の可能性","probabilities":["","",…]},{"type":"土砂災害の警報級の可能性",…},{"type":"雪の警報級の可能性","probabilities":["なし","なし",…]},{"type":"風（風雪）の警報級の可能性",…}]}]}]}]]` | **取得可**。値は `高` / `中` / `なし` / `""`。1日2回更新。「明日にかけて大雨警報の可能性【高】」→ 事前にカメラをお気に入り登録、という導線が作れる。推奨度B |
| 推計震度分布 | 一覧は **`https://www.jma.go.jp/bosai/estimated_intensity_map/data/list.json` → 200 / 244,576 B（338件）**<br>`{"hypo":{"it":"2026-08-23T02:13:04","at":"2026-08-23T02:00:00","lat":36.0,"lon":140.1,"dep":70,"mag":5.9,"epi":"茨城県南部","kun":0,"maxi":4.9},"comment":"震度５弱のところでは、…","url":"202608230200_301","rank_cnt":{"i9":0,…,"i5":5656,"i4":122037,…},"bounds":[[35.11,139.35],[37.26,140.73]],"mesh_num":["5239","5240",…],"datum":2}` | **一覧は取得可**（`bounds` で「揺れが及んだ矩形」、`rank_cnt` で震度別メッシュ数が分かるので、`bounds` 内のカメラを出す用途にはこれだけで足りる）。**メッシュ本体（250mメッシュ震度）のURLは特定できず（取得失敗）**: `data/{url}.json`・`data/{url}/{mesh}.json`・`images/{url}/{z}/{x}/{y}.png` すべて404 |
| 線状降水帯予測マップ | `jmatile/data/kaikotan/targetTimes_sjfcstmap.json` ほか | 404。**未特定**（上の `slmcs` 系と同じ課題） |
| 熱中症警戒アラート | `https://www.wbgt.env.go.jp/alert.php` は 200（HTML）／`https://www.wbgt.env.go.jp/alert/dl/pref_alert.csv` は **404** | CSVの正しいパスは未特定。ただし **1.8 のXMLフィードに「熱中症警戒アラート」エントリが26件流れている**のでそちら経由なら取得可。推奨度C（本アプリの軸と噛み合わない） |

---

## 2. 国土交通省系（川の防災情報・道路）

### 2.1 川の防災情報（kawabou）の水位・雨量観測所 ★推奨A（ただし規約に条件あり）

- **機能名**: 河川水位（現在水位／危険水位の超過状況）＋ 危険水位到達のプッシュ通知
- **利用者の価値**: 河川カメラ 14,044台という本アプリ最大の資産に「数字」が付く。「氾濫危険水位を超えた観測所」→「その川のカメラ」という導線は、既存の全機能の中でいちばん強い。
- **データ源（すべて実測200）**: `https://www.river.go.jp/kawabou/file/files/` および `.../file/gjson/` 配下の**静的JSON**（JS実行・Cookie・Referer不要）。既存 `crawler/sources/kawabou.py` と同じ流儀。

  | 用途 | URL | 実測 |
  |---|---|---|
  | 最新観測時刻 | `.../file/system/tmCrntTime.json` | 200 / 34 B / `{"crntObsTime":"2026/08/31 11:45"}`。**5分刻みで生成**、観測値自体は10分間隔 |
  | **全国の基準超過観測所（1本で全国）** | `.../file/gjson/overobs/stg/{YYYYMMDD}/{HHmm}/over-obs-create.json` | **200 / 7,656 B / 全国19地点**。GeoJSON。`properties` に `obs_nm`,`obs_kana`,`rvr_cd`,`obs_time`,`stg_ovlvl`,`stg_ovdeg` |
  | 市区町村の観測所マスタ（閾値入り） | `.../file/files/obslist/obs/twnlist/{twnCd}.json` | 200 / 27,768 B（川口市の例）。`obsStg`25／`obsRn`6／`obsSwin`16／`cctv`／`scam` など |
  | 市区町村のリアルタイム実測値 | `.../file/files/obslist/tm/twnlist/{YYYYMMDD}/{HHmm}/{twnCd}.json` | 200 / 9,907 B。`tmStg[].stg`（水位m）, `stgHght`, `stgOvlvl`, `stg10mChg` |
  | 全国の洪水予報・水防警報・ダム放流通知レベル | `.../file/files/rw/lvl/{YYYYMMDD}/{HHmm}/rwLv.json` | **200 / 25,177 B / 全国1ファイル**。`{"pref":{"fldfr":[47件],"damdsch":[47件],"fldctl":[47件]}, "area":{…}}` |
  | 全国市区町村インデックス（bbox＋観測所有無フラグ） | `.../file/files/map/twn/twnarea.json` | 200 / **1,148,812 B**。`{"towns":[{"lat":…,"twnCd":102204,"twnNm":"旭川市","minLon":…,"maxLat":…,"stgExistFlg":1,"damExistFlg":1,…}]}` |
  | 観測所マスタ（1地点・緯度経度） | `.../file/files/master/obs/stg/{obsFcd}.json` | 200 / 3,753 B。`obsFcd` は13桁 = `ofcCd`5 + `itmkndCd`3 + `obsCd`5 |
  | bbox検索の動的API（参考） | `https://www.river.go.jp/api/tmPointList/{minLat},{maxLat},{minLon},{maxLon}` | 200。`itmkndCd`: 1=雨量 / 3=積雪 / 4=水位 / 7=ダム / 12=潮位 |

- **危険水位の閾値フィールド**（マスタ側。app.js のグラフ凡例コードで裏取り済み）:

  | フィールド | 意味 |
  |---|---|
  | `rsrvStg` | 水防団待機水位（Lv1） |
  | `warnStg` | 氾濫注意水位（Lv2） |
  | `spclWarnStg` | 避難判断水位（Lv3） |
  | `dngStg` | **氾濫危険水位（Lv4）** |
  | `fldStg` | 氾濫発生水位（Lv5） |
  | `dsgnHighStg` | 計画高水位 |

  実例（青木水門）: `{"obsNm":"青木水門","rsrvStg":3.15,"warnStg":3.75,"spclWarnStg":3.88,"dngStg":4.63,"fldStg":6.13}`
- **超過判定は計算不要**: 実測値側の `stgOvlvl` が段階を持っている（`90`=氾濫発生 / `80`,`70`=**氾濫危険水位超過** / `60`,`50`=避難判断 / `40`〜`20`=氾濫注意 / `10`=水防団待機 / `0`=平常）。→ **`over-obs-create.json` 1本（7.6KB）だけで「今どこが危ないか」が全国分わかる。**
- **更新頻度**: ファイル生成5分／観測値10分。過去1週間分以上が残っていることを実測（`20260824/1150` も 200）。
- **規約（★ここが判断ポイント）**: 規約本文は `https://www.river.go.jp/kawabou/kwb_apend/html/caution.html`（200 / 29,018 B）。※リポジトリの `kawabou.py` が持つ `KAWABOU_TERMS_URL = https://www.river.go.jp/riyou` は現在SPAシェルを返すだけで規約本文が無い（**要修正**）。

  著作権について（原文）:
  > 当ホームページで公開している情報（以下「コンテンツ」といいます。）は、どなたでも以下の１）～７）に従って、複製、公衆送信、翻訳・変形等の翻案等、自由に利用できます。商用利用も可能です。また、数値データ、簡単な表・グラフ等は著作権の対象ではありませんので、これらについては本利用ルールの適用はなく、自由に利用できます。
  >
  > 【出典記載例】出典：国土交通省 川の防災情報ホームページ（当該ページのURL）
  >
  > 本利用ルールは、政府標準利用規約（第2.0版）に準拠しています。／クリエイティブ・コモンズ・ライセンスの表示4.0 国際（…「CC BY」…）と互換性があり、本利用ルールが適用されるコンテンツはCC BYに従うことでも利用することができます。

  はじめに（原文）:
  > 当ホームページは一般の方々が通常のブラウザで閲覧されることを前提に情報を掲載しています。**ツール等による定期的なデータ収集は、サーバに過度の負担がかかりサービス提供に支障をきたすため、お控えいただきますようお願いいたします。**
  > **商用・非商用を問わず、定期的・定常的なデータ収集を行われる場合は、以下に記載するリンク先ページよりデータ配信を受けることができますのでご利用ください。**
  > ・河川情報数値データ配信事業 https://www.river.or.jp/koeki/opendata/index.html
  > なお、一定期間の通信量が著しく多い場合や高頻度のアクセスが確認された場合、利用元に対してアクセス制限を行う場合があります。

  誘導先の `river.or.jp/koeki/opendata/` を確認したところ、**これは本プロジェクトが C2 で使用禁止としている有償の「水防災オープンデータ提供サービス（河川情報数値データ配信事業）」そのもの**（原文「実費の負担を頂きながら、受信希望者に提供しています」）。

  **判定: ライセンスは可（CC BY 4.0互換・商用可・出典明記のみ）。取得方法は要照会。**
  - ✕ になりやすい実装: 全端末が5〜10分間隔で自動ポーリングする／GitHub Actions が5分ごとに全国を巡回する（＝「定期的・定常的なデータ収集」に正面から当たる）
  - △ 許容の余地がある実装: **変化しないマスタ（`twnarea.json`・観測所マスタ・閾値）は月次で自前ミラー**（既存の `tools/shelters.py` + `shelters.yml` の月次パイプラインと同じ形）、**変化する実測値は「利用者が画面を開いたときだけ」1〜2リクエスト**（バックグラウンド自動ポーリングをしない）
  - **SPEC 10「判断が必要になったときのルール」に該当する案件**（利用規約が判別しづらい／一次ソースへの負荷）。実装前に FRICS（`haisin-info@river.or.jp`）または国交省へ照会するのが安全。既存の kawabou カメラ利用と合わせて一括で聞ける。
- **実装規模**: 中（1週間）。パイプラインは既存 `kawabou.py` の `HttpSession` をそのまま流用可。
- **既存機能との関係**: 完全な新規。SPEC 1.3 のスコープ外項目「水位・雨量などの数値データ重ね合わせ（有償配信が必要なため）」は、**無償の静的JSONで取れることが判明したので前提が変わった**。ただし上記の取得方法の論点があるため、SPEC の書き換えはオーナー判断が要る。
- **推奨度: A（規約照会が済めば）／要照会**

### 2.2 ダム放流情報（kawabou dam） ★推奨B

- 2.1 とまったく同じパイプライン。市区町村ファイルの `tmDam` に入る。
- マスタ実測: `https://www.river.go.jp/kawabou/file/files/master/obs/dam/2137700700001.json` → 200 / 2,038 B（小河内ダム。`lat`,`lon`,`obsNm`,`rsysNm`,`jrsNm`,`lmtStg1..4` 制限水位ほか）
- 実測値（`.../obslist/tm/twnlist/20260831/1150/1301308.json` → 200 / 3,226 B）:

  ```json
  {"tmList":{"tmDam":[{"obsFcd":"2137700700001","obsTime":"2026/08/31 11:40",
    "storLvl":509.27,"storCap":120373,"storPcntEff":…,"allSink":…,"allDisch":…,
    "bsnrnHr10m":null,"bsnrnInc":null,"damdschLvl":null}]}}
  ```
  `storLvl`=貯水位(m) / `storCap`=貯水量(千m³) / `storPcntEff`=有効貯水率(%) / `allSink`=**全流入量(m³/s)** / `allDisch`=**全放流量(m³/s)** / `damdschLvl`=**ダム放流通知レベル**
- 全国の放流通知は `rw/lvl/.../rwLv.json` の `damdsch`（25KB）。基準超過ダムは `gjson/overobs/dam/.../over-obs-create.json` → 200 / 98 B（確認時は該当なし `features:[]`）
- 規約: 2.1 と同一（同じ論点が掛かる）。
- **推奨度: B**（台帳のダムカメラは215台。水位ほどのインパクトは無いが実装はほぼ無料で乗る）

### 2.3 道路規制情報（road-info-prvs） ★推奨C — **規約により不可（要照会）**、かつ既存実装への影響あり

- **データは取れる**（実測）:
  - 通行規制JSON（1次メッシュ単位）: `https://www.road-info-prvs.mlit.go.jp/roadinfo/backup/{生成時刻}/{ランダム鍵}/TukoKisei/{1次メッシュ}.json` → **200 / 32,441 B**（例 `5339.json`）。規制種別コード・原因コード・アイコン座標・規制区間の LineString GeoJSON 入り。
    - `{生成時刻}/{ランダム鍵}` は**生成のたびにローテーションする**（`.../backup/20260831114500/WCDgZ1P8hWbWowH8/h7ench5V.js` → 10分後には `.../20260831115500/CYmq2dWQWctO1O6G/dHahMVQ1.js`）。必ず2段解決になる。
  - **人間可読の一覧HTMLが整備局単位で10ファイル**: `https://www.road-info-prvs.mlit.go.jp/roadinfo/pc/pcTukokiseiList_{整備局CD}_1.html` → 200（関東83 で 143,944 B、九州89 で 106,044 B）。都道府県別・路線名・起終点住所・期間・原因・規制延長が入る。**全国10リクエストで「今どこが規制中か」が取れる。**
  - 更新頻度（原文）: 「本サイトで提供する情報は**5～10分間隔で更新**していますが…」「通行規制情報については…**情報を取得してからサイトに反映されるまでに10分程度**の時間を要する場合があります」
  - カバー範囲（原文）: 「国土交通省が管理する高速道路、国道、及び一部の自治体が管理する国道、都道府県道」／「東日本高速道路（株）…阪神高速道路株式会社、本州四国連絡高速道路株式会社、地方道路公社が管理する高速道路、一部の都道府県道、及び市町村が管理している道路は、**情報提供の対象外**」
- **規約**: `https://www.road-info-prvs.mlit.go.jp/roadinfo/pc/pcWhenUsing_00_0.html`（200 / 30,361 B）原文:

  > **リンクについて**
  > ▶ 本サイトに対するリンクは、トップページ（https://www.road-info-prvs.mlit.go.jp/roadinfo/）へのリンクに限り、原則リンクフリーとします。
  > ▶ **各画像への直接のリンクはご遠慮ください。**
  > ▶ 独自のフレームの中に、本サイトのコンテンツを取り込んだ形のリンクをしないでください。
  >
  > **著作権について**
  > ▶ 本サイトの掲載情報は、日本国の著作権法および国際条約による著作権保護の対象となっています。
  > ▶ 本サイトの内容について、私的使用又は引用等著作権法上認められた行為を除き、**国土交通省に無断で転載等を行うことはできません。**
  > ▶ 本サイトの内容の全部または一部について、**国土交通省に無断で改変を行うことはできません。**

  **判定: 不可（現状のまま実装してはいけない）。** kawabou と違い政府標準利用規約系ではなく、旧来型の「無断転載・改変禁止」。
- **⚠️ 既存実装への波及（この調査の副産物・要判断）**: 同じ条項の「各画像への直接のリンクはご遠慮ください」が、本リポジトリの `crawler/sources/mlit_roadinfo.py` / monitor の都度解決（`img/doro_gazo/pc/{timestamp}/s_{管理ID}.jpeg` を `status.json` の `image_url` として配信）に掛かる。`mlit_roadinfo.py` の `TERMS_URL = "https://www.mlit.go.jp/link.html"  # 国交省サイト利用規約（推定・要確認）` の「要確認」の答えがこれ。**SPEC 10 に従い、オーナー判断が必要**（MBC南日本放送で採ったのと同じ「誘導型に切替」か、国交省へ照会して許諾を取るか）。規制情報の実装可否と合わせて一括照会するのが効率的。
- **推奨度: C（照会が通るまで着手しない）**

### 2.4 JARTIC / NEXCO — 見送り

| 対象 | 実測 | 判定 |
|---|---|---|
| JARTIC オープンデータ | `https://www.jartic.or.jp/d/opendata/opendata.json` → 200 / 14,561 B。`typeD`=交通規制情報（警察の**恒久的**規制。速度制限・一方通行等）47都道府県ZIP、`typeB`/`typeC`=断面交通量・交差点制御。ページ原文「※各情報は、毎月月初に更新し、更新前の情報は取得できなくなります」 | **リアルタイム防災用途に不適**（統計・静的規制）。リアルタイム渋滞は法人向け有料 |
| JARTIC 交通量API（xROAD） | `https://api.jartic-open-traffic.org/geoserver` → 400 / `{"message":"Missing required request parameters: [request, srsName, typeNames, service, cql_filter, version, outputFormat]"}`。パラメータを揃えた WFS GetFeature は **200 / `{"message":"Forbidden"}`**（ソフトブロックの可能性があるため2回で試行中止） | **取得失敗**。サイト原文では「無料でご利用いただけますが…規約への同意が予め必要です」。仕様書PDF（1,096,606 B）はCIDエンコードでテキスト抽出できず `typeNames` の正値を確定できなかった。**そもそも「交通量」であって「規制・渋滞」ではない**ので防災優先度は低い |
| NEXCO東日本「ドラとら」 | `https://www.drivetraffic.jp/` → 200。交通データは **ZENRIN its-mo の商用地図SDK**（`api.its-mo.com/v3/loader?key=…`）経由。`robots.txt` は `Disallow: /sapa_signage` | **無料・無登録の機械可読フィードなし** |
| NEXCO西日本 / iHighway | サイトポリシーは分岐ハブページで規約本文は未取得（**未確認**） | オープンデータライセンスではない |

→ NEXCO区間の規制を無料・無登録で機械可読に取る手段は見つからなかった。唯一の例外は国交省側の `pcExpresswayJizenTukokisei_{整備局CD}_5.html`（事前通行規制区間・高速道路会社管理、200 / 18,749 B）だが、これも 2.3 の規約が掛かる。

---

## 3. その他（停電・避難情報・鉄道・自治体オープンデータ）

### 3.1 停電情報 ★推奨C — **技術的には取れるが規約で不可（要照会）**

大手電力10社を実際に叩いて、機械可読エンドポイントを特定できたのは **7社**。

| 社 | 形式 | エンドポイント | 実測 |
|---|---|---|---|
| 東北電力NW | JSON | `https://nw.tohoku-epco.co.jp/teideninfo/blackout/top.json` / `.../blackout/{JIS2桁}.json` / `.../blackout/{JIS5桁}.json` | 200 application/json |
| 関西電力送配電 | JSON | `https://www.kansai-td.co.jp/interchange/teiden-info/ja/00.json` / `.../{pref}.json` / `.../history.json` / `.../lastmodified-HP.json` | 200（確認時は停電なしで `{}`） |
| 九州電力送配電 | XML | `https://www.kyuden.co.jp/td_teiden/xml/00.xml` / `.../xml/c{prefId}.xml` | 200 text/xml |
| 沖縄電力 | XML | `https://www.okidenmail.jp/bosai/api/xml_map_koazaBetsu.php` / `https://www.okidenmail.jp/bosai/xml/history.xml` | 200 text/xml |
| 中部電力PG | XML | `https://teiden.powergrid.chuden.co.jp/p/resource/xml/teiden_area.xml` / `.../disclose/xml/{aichi,gifu,mie,nagano,sizuoka}.xml` | 200（確認時は空） |
| 四国電力送配電 | TopoJSON | `https://teidenchizushikoku.com/TEIDENINFOTOPOJSON.topojson` | 200（確認時は空。停電ポリゴン配信） |
| 北海道電力NW | HTMLのみ | `https://teiden-info.hepco.co.jp/municipality.html` | 200（JSON無し） |
| 中国電力NW | HTMLのみ | `https://www.teideninfo.energia.co.jp/` | 200（サーバーレンダリング） |
| 東京電力PG | **取得失敗** | `/flash/xml/{11桁}.xml` を特定したが AkamaiGHost が 302 → `/` | ヘッダ・Cookie・Referer・キャッシュバスタを試行して不可 |
| 北陸電力送配電 | **未確認** | `www.rikuden.co.jp` が **403** | SPEC 10 に従い即アクセス停止（**ユーザーへ報告事項**） |

データ品質は高い。東北電力NWの実応答（町丁名・発生時刻・復旧見通し・原因まで）:

```json
{"time":"2026年8月31日 11:45 現在","pref_code":"07","city_code":"204","city_name":"いわき市",
 "total":1,"details":[{"time":"8月30日 21:40","recovery_outlook":"故障箇所探査中",
 "reason":"調査中","towns":[{"name":"川前町川前","count":1}]}]}
```
市区町村コードはJIS、更新は5分間隔（11:45→12:00 を実測）。

**規約: 不可（要照会）。** 東北電力NWの原文:

> 本サービスで提供している情報やカンパニーロゴ、画像、デザイン等…に関する著作権その他の権利は、当社または原著作者その他の権利者に帰属します。**個人の私的利用を目的とする場合**、その他著作権法等の法令により認められる場合を除き、**事前に当社の承諾を得ることなく**、本サービスで提供している情報等を**複製、送信、頒布、改変、切除、転載等することはできません。**

- 官公庁の公共データ利用規約系ではなく、民間企業の一般的な著作権条項。**アプリでの表示は「送信・転載」に当たる**と読まれる。
- 他8社の規約原文は**未採取（未確認）**。東北の文言が業界標準の可能性が高いので、実装するなら**全社に照会が必要**。
- **推奨度: C**（照会コストに対して、防災アプリとしての中心性が低い）

### 3.2 自治体の避難情報（避難指示・高齢者等避難） ★不可

**結論: 全国横断で無料・無登録に取れる経路は実在しない。** 実地確認の内訳:

| 経路 | 確認結果 |
|---|---|
| **Lアラート**（FMMC運営） | 一般公開APIなし。規約・XML仕様書すら申込フォーム経由（`https://www.fmmc.or.jp/commons/download/rules.html`）。さらに **2026.06.12「Ｌアラートサービスの新規利用申し込み（情報伝達者）の受付停止について」/ 2026.07.22「Ｌアラートサービスの新規利用申し込みの受付停止について」** ＝ 現在そもそも新規受付停止。→ **不可** |
| SIP4D-CKAN（防災科研） | カタログAPIは無登録で 200（`https://catalog.bosai.go.jp/api/3/action/package_search?q=避難` → 5,796件、多くが cc-zero）。しかし実データ `https://api.sip-bousai.jp/SIP4D_ZIP/...` は **HTTP 401**。かつ災害ごとのアーカイブZIPでリアルタイムではない → **不可** |
| 全国避難所ガイド API（ファーストメディア） | Lアラート連携の開設避難所・混雑状況API。原文「サービス利用お申込み月に、**初期費用**をご請求いたします」「本番運用開始月より**利用費用**をご請求いたします」→ **有償・APIキー必須。C2により不可** |
| Yahoo!（crisis.yahoo.co.jp） | LINEヤフー共通利用規約 8.3「お客様は、本コンテンツを、当社サービスが予定している利用態様を超えて利用（**複製、送信、転載、改変**を含みます。）をしてはなりません。」→ **不可** |
| NHK | 公開APIは発見できず。著作権ページのURL特定は**失敗**（候補が404） |
| 都道府県ポータル | 静岡県は SPA の同一オリジンAPIがあり技術的には個別対応可能。ただし47都道府県すべて別実装・別規約で、**全国横断の集約点が存在しない** |

→ **この方向は諦めるのが正しい。** 代替として、キキクル（1.1）と指定河川洪水予報（1.2）は「自治体が避難指示を出す**判断材料**」そのものなので、避難情報の代わりに十分機能する（1.2 の `explain.txt` 原文がまさにそう説明している）。

### 3.3 国土地理院 指定緊急避難場所・指定避難所 — **既存機能と重複**

調査では全国一括CSV（`https://hinanmap.gsi.go.jp/hinanjocp/defaultFtpData/csv/mergeFromCity_1.csv` 11.7MB/83,437行、`mergeFromCity_2.csv` 17.0MB、Last-Modified 2026-08-24）と、公共データ利用規約1.0（CC BY 4.0互換）での利用可を確認したが、**これは `tools/shelters.py` + `app/lib/data/shelter_layers.dart` で既に実装済み**（14万件）。新規性なし。

ただし1点、規約付随の「ご利用上の注意」に配布時の義務がある点は確認しておく価値がある:

> 本データを用いた情報を**第三者に提供する場合は、上記1.〜3.の注意事項が正確に伝わるよう、十分にご留意ください**

（＝「最新でない可能性がある」「指定緊急避難場所と指定避難所は別物」「随時更新される」をアプリ内に明記する必要）。現行の `ShelterLayers.disclaimer = '最新かつ詳細な状況は各市町村にご確認ください'` は最低限を満たしているが、**「指定緊急避難場所と指定避難所の違い」の説明が明示されているかは要確認**。

### 3.4 未調査で残ったもの（正直な記録）

以下は今回の調査時間内に確認まで到達しなかった。**推測で書かない**という方針に従い「未確認」と記す。

- 鉄道運行情報（公共交通オープンデータセンター ODPT の登録要否・利用規約原文、各社の公開JSON）
  - なお ODPT は**アカウント登録とアクセストークンが必須**と一般に知られており、「無料・無登録」という前提には最初から合致しない可能性が高い（**未検証**）
- 国土数値情報（nlftp.mlit.go.jp）／e-Stat／data.go.jp の全国横断データセット（AED・給水拠点・消防水利・防災備蓄倉庫）と各利用約款の原文
- 電力9社（東北以外）の規約原文
- 海上保安庁の潮位、消防庁の災害情報

---

## 4. 総括と推奨3案

### 4.1 候補一覧（推奨度順）

| 推奨度 | 機能 | データ源 | 規約 | 実装 | 節 |
|---|---|---|---|---|---|
| **A** | キキクル（土砂・浸水・洪水）レイヤー | 気象庁 `jmatile/data/risk` | 可 | 3〜5日 | 1.1 |
| **A** | 指定河川洪水予報（氾濫危険情報） | 気象庁 `bosai/flood` + `risk` の `designated_river` タイル | 可 | 5日〜1週 | 1.2 |
| **A** | 地震の市区町村別震度 → 該当自治体のカメラ | 気象庁 `quake/list.json` の未使用 `int` フィールド | 可 | 1〜2日 | 1.3 |
| **A**（基盤） | 気象庁防災情報XMLフィードによる通知拡張 | `data.jma.go.jp/developer/xml/feed/extra.xml` | 可（10GB/日・毎分更新の制約あり） | 2〜3日 | 1.8 |
| **A / 要照会** | 河川水位（現在水位・氾濫危険水位の超過） | 川の防災情報 kawabou 静的JSON | ライセンスは可（CC BY互換）／**取得方法が「定期収集はお控えください」** | 1週 | 2.1 |
| **B** | 台風進路・予報円 | 気象庁 `bosai/typhoon` | 可 | 1週 | 1.4 |
| **B** | 今後の雪（積雪深・降雪量） | 気象庁 `jmatile/data/snow` | 可 | 2〜3日 | 1.5 |
| **B** | カメラ地点の天気予報 | 気象庁 `forecast/data/forecast/map.json` | 可 | 2〜3日 | 1.6 |
| **B** | 雷活動度・竜巻発生確度 | 気象庁 `jmatile/data/nowc` + `targetTimes_N3.json` | 可 | 1〜2日 | 1.9 |
| **B** | 早期注意情報（警報級の可能性） | 気象庁 `probability/data/probability/r8/map.json` | 可 | 2日 | 1.9 |
| **B / 要照会** | ダム放流情報 | kawabou `tmDam` / `rwLv.json` | 2.1 と同じ | 3日 | 2.2 |
| **C** | 噴火警戒レベル・降灰予報 | 気象庁 `volcano` | 可 | 5日 | 1.7 |
| **C** | 気象衛星ひまわり | 気象庁 `himawari` | 可 | 2日 | 1.9 |
| **C** | 時系列情報／天気分布予報／潮位 | 気象庁各種 | 可 | — | 1.9 |
| **C / 要照会** | 道路規制情報 | road-info-prvs | **不可（無断転載・改変禁止）** | — | 2.3 |
| **C / 要照会** | 停電情報 | 電力7社の JSON/XML | **不可（事前承諾なく複製・送信不可）** | — | 3.1 |
| **✕** | 自治体の避難指示（全国横断） | Lアラート等 | **経路が実在しない** | — | 3.2 |
| **✕** | 鉄道運行情報 | ODPT ほか | 未確認（登録必須の見込み） | — | 3.4 |
| — | 避難場所 | 国土地理院 | 可 | **既存機能と重複** | 3.3 |

### 4.2 推奨①: キキクル（危険度分布）レイヤー ＋ 危険度からのカメラ導線

**決め手**: 既存の雨雲レーダー実装（`jma_layers.dart` の `NowcastTime` → `TileLayer`）とURL構造がまったく同型で、**追加コストが実質「element名の追加」だけ**。それでいて「雨がどこに降っているか」から「その雨でどこが危ないか」へ、アプリの防災的な意味が一段上がる。規約はクリア（公共データ利用規約1.0・出典明記のみ）。季節を選ばず、6〜10月に効く。

**実装ステップ**

1. `jma_layers.dart` に `RiskTime`（`targetTimes.json` の `basetime`/`member`/`validtime` を保持）と `fetchRiskTimes()` を追加。既存 `NowcastTime` とほぼ同じ。**`member` は `none` 固定にしない**（最新3件は `immed0/1/2` で、`none` を渡すと404）。
2. `MapLayerKind` に `kikikuruLand` / `kikikuruInund` / `kikikuruFlood` を追加。`land`・`inund` は面、`flood` は河川線なのでUI上の説明を分ける。
3. 時間スライダは既存の雨雲UIを流用（37件＝過去6時間・10分刻み）。**予測時刻のエントリは存在しない**ので、雨雲のような「予測」表示はしない。
4. **凡例の配色は降雨時に実タイルの画素をサンプリングして確定する**（既存 `rain24hScale` を決めたときと同じ手順）。今回の調査時点は全国ほぼ無降水でタイルが全部透明（334 B）だったため、色を確定できていない。推測で入れない。
5. 出典: 「出典：気象庁ホームページ https://www.jma.go.jp/bosai/risk/ 」＋ 免責（既存の `HazardLayers.disclaimer` と同じ体裁で「避難判断は自治体の避難情報に従ってください」）。
6. 応用（第2段階）: 表示範囲内で危険度の高いタイル座標を拾い、その範囲のカメラを「今見る価値があるカメラ」として上位に出す。SPEC 0 の「今見る価値があるか」に直結する。

**懸念**
- タイルの色を実測できていないので、凡例の実装は出水期を待つか、過去の降雨時刻の `basetime` を指定して取得する必要がある（`targetTimes.json` は過去6時間しか持たないため、雨の日に取り直す運用になる）。
- レイヤーが増えすぎる問題。既存9種＋3種＝12種になるので、レイヤー選択UIを「雨・危険度・ハザード・避難」のグループ分けに直す作業が付随する（工数に含めた）。

### 4.3 推奨②: 河川の危険度（指定河川洪水予報 → 該当河川のカメラ ＋ プッシュ通知）

**決め手**: 台帳21,622台のうち **`category=river` が 14,044台（65%）**。本アプリの主軸は河川カメラであり、「氾濫危険警報が出た川のカメラを開く」は他のどのアプリにも作れない導線。既存のプッシュ基盤（`tools/bosai_notify.py` の state差分＋トピック集約）をそのまま拡張でき、通知の価値が「震度5弱・特別警報」だけだった段階から一段広がる。

**2段構えにするのが要点**:

- **第1段階（規約クリア・すぐ着手可）= 気象庁の指定河川洪水予報**
  1. `tools/bosai_notify.py` に `https://www.jma.go.jp/bosai/flood/data/r8/flood_xml.json` の監視を追加。**ただし確認時は `[]`（発表中0件）でフィールド構造が未確認**なので、まず**出水期に実データを1回取得してスキーマを固める**のが先。それまでは 1.8 の XMLフィード（`extra.xml`）で洪水予報（VFDI50）のエントリを拾う実装のほうが確実。
  2. 段階名・警戒レベルの文言は `https://www.jma.go.jp/bosai/flood/const/explain.txt` の原文をそのまま使う（レベル５氾濫特別警報／レベル４氾濫危険警報／レベル３氾濫警報／レベル２氾濫注意報）。自前の言い換えをしない＝気象業務法23条対策。
  3. 河川コード↔台帳 `river_or_route` の対応表を `data/` に作る。**指定河川洪水予報の対象は全国で数百河川なので、その分だけ名寄せすればよい**（台帳の河川名3,165種すべてを扱う必要はない）。`const/river_order.json`（6,379 B）が河川コードの一覧になる。
  4. 災害速報タブに3本目のリスト「河川」を追加。タップ→該当河川の `river_or_route` でカメラを絞り込む（`NearbyCamerasScreen` に河川名フィルタの引数を足す）。
  5. 地図側は 1.1 の `designated_river` / `flood_riskline` タイルを重ねるだけで面の表現になる。
- **第2段階（要照会）= kawabou の実水位**
  6. **先に照会する**。「マスタ（観測所一覧・座標・危険水位の閾値）を月次で1回ミラーし、実測値は利用者が画面を開いたときだけ取得する（バックグラウンドの定期取得はしない）」という設計で問題ないかを FRICS / 国交省に確認（既存の kawabou カメラ利用と合わせて一括で聞く）。
  7. 許諾が得られたら: マスタは `tools/` に月次スクリプトを追加して `site/v1/river_stations/` へ（既存 `tools/shelters.py` + `.github/workflows/shelters.yml` と同じ形）。実測は端末から `over-obs-create.json`（**全国7.6KB**）1本＋必要な市区町村ファイルだけ。
  8. カメラ詳細画面に「最寄りの水位観測所：〇〇 3.2m（氾濫注意水位 3.75m）」を1行出す。これが**カメラの映像に意味を与える**いちばん効く見せ方。

**懸念**
- `flood_xml.json` の実データ構造が未確認（今回は空配列しか見られなかった）。**出水期に必ず1回取り直すこと。** それまで本番実装に入るとスキーマを外す。
- kawabou 側は「ツール等による定期的なデータ収集はお控えください」「（有償の）河川情報数値データ配信事業をご利用ください」と**名指しで書かれている**。SPEC C2（有償サービスを使わない）と SPEC C3（礼儀正しいアクセス）が正面から衝突する数少ないケースで、**オーナー判断＋照会なしに進めてはいけない**。
- 河川名の名寄せは表記ゆれ（「荒川」が全国に複数、「芝川」は荒川水系…）があり、水系コード（`rsysCd`）まで見ないと誤同定する。第1段階では**国管理の主要河川に限定**して出すのが安全。

### 4.4 推奨③: 地震の市区町村別震度 → 揺れた自治体のカメラ

**決め手**: **追加のネットワークアクセスがゼロ。** 既に毎回取得している `quake/list.json` の `int` フィールドを使っていないだけ。しかも7桁の地域コードは `code[:5]` で台帳の `municipality`（16,063台に付与済み）とそのまま一致することを実測で確認した（`1311100`→`13111` 大田区）。**1〜2日で出せて、災害速報タブの精度が明確に上がる。**

現状は震源の緯度経度からの距離50km以内でカメラを出しているが、深発地震の異常震域では震源の近くがまったく揺れていないことがある。「実際に震度4以上だった自治体のカメラ」に切り替えられる。

**実装ステップ**

1. `bosai_screen.dart` の `_Quake` に `intensityByCity: Map<String,String>`（JIS5桁→震度）を追加し、`list.json` の `int[].city[]` からパースする（`code[:5]`）。同一 `eid` の複数報は既存の `mergeQuakeReports` と同じ方針で最大震度を採る。
2. 地震カードを展開すると「震度4以上の市区町村」を震度順に並べる。
3. タップで `NearbyCamerasScreen` を開く。引数に `municipalities: Set<String>` を足し、距離ではなく市区町村一致で絞る（該当0件のときだけ従来の距離検索にフォールバック）。
4. 詳報が要る場合は `https://www.jma.go.jp/bosai/quake/data/{list.jsonのjsonフィールド}` を開く（観測点レベルまで入る。実測 200 / 2,069 B）。
5. あわせて `estimated_intensity_map/data/list.json`（200 / 244,576 B）の `bounds` を使えば「揺れが及んだ矩形」も出せる（メッシュ本体のURLは特定できなかったので `bounds` のみ）。

**懸念**
- `int` は震度速報の段階では入らない報がある（既存の `mergeQuakeReports` が扱っている「震源・M が空」の報と同じ事情）。**震度別リストが空のときは従来の距離検索にフォールバックする**設計にしておく。
- 市区町村コードは合併で変わる。台帳側 `municipality` が古いカメラでは一致しない可能性があるので、一致0件時のフォールバックは必須。

### 4.5 あわせて上げておくべき「要判断」事項（SPEC 10 該当）

1. **`crawler/sources/mlit_roadinfo.py` の規約が確定した**。road-info-prvs の利用規約に「**各画像への直接のリンクはご遠慮ください**」「国土交通省に無断で転載等を行うことはできません」と明記されている。現行の都度解決（`img/doro_gazo/pc/{timestamp}/s_{管理ID}.jpeg` を `status.json` の `image_url` として配信）はこれに抵触する。`mlit_roadinfo.py` の `TERMS_URL = "https://www.mlit.go.jp/link.html"  # …（推定・要確認）` の答えがこれ。→ **MBC南日本放送と同じ「誘導型へ切替」か「国交省へ照会」かのオーナー判断が必要。**
2. **`crawler/sources/kawabou.py` の `KAWABOU_TERMS_URL` が実効URLでない**。`https://www.river.go.jp/riyou` はSPAシェル（規約本文なし）。正しくは `https://www.river.go.jp/kawabou/kwb_apend/html/caution.html`。あわせて `license` の実態は政府標準利用規約2.0 / CC BY 4.0互換。
3. **北陸電力送配電（www.rikuden.co.jp）が 403 を返した**ため、SPEC 10 に従い当該ソースへのアクセスを即停止した（以後アクセスしていない）。
4. SPEC 1.3 の「スコープ外：水位・雨量などの数値データ重ね合わせ（有償配信が必要なため）」は、**無償の静的JSONで取得可能であることが判明したので前提が変わった**。ただし取得方法に規約上の論点があるため、SPEC の書き換えはオーナー判断。
