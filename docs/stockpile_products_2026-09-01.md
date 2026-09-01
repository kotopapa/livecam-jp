# 防災備蓄チェックリスト 推奨商品データ（2026-09-01 作成）

アプリの「防災備蓄チェックリスト」画面に出す推奨商品を、**アプリに埋め込まず配信JSONで持つ**ための
データと運用手順。廃番・在庫切れ・URL変更が頻繁に起きるため、アプリ更新なしで差し替えられるようにする。

- 配信元データ: `data/stockpile/products.json`（コミットする）
- 配信先: `site/v1/stockpile/products.json`（`site/build.py` がコピー。`site/v1/` は gitignore）
- 月次点検: `tools/stockpile_check.py` ＋ `.github/workflows/stockpile-check.yml`

---

## 1. 選定基準（この順に優先）

| 優先 | 基準 | 記録するフィールド |
|---|---|---|
| 1 | 一般社団法人 防災安全協会「**防災製品等推奨品**」の認定を受けているもの | `cert` = {name, no, url} |
| 2 | 内閣府・消防庁・農林水産省・自治体が**備蓄品目として挙げている**もの、およびその**数量の根拠** | `sources[]` = {name, url} |
| 3 | 各モールで**長期間販売され、レビュー数が多い定番品**（ロングセラー・官公庁納入実績） | `why` に記述 |
| 4 | 保存年数・容量・入数など**数値で比較できる仕様**が明記されているもの | `spec` |

**「私の主観でおすすめと書かない」** ため、`why` には必ず (a) 公的資料の数量根拠、
(b) 規格・認定（PSE / 労・検ラベル / 防炎ラベル / 推奨品認定）、(c) 客観的な販売実績のいずれかを書く。
根拠が確認できないものは商品として載せず、`search`（検索語）だけにする。

### やらないこと

- **価格・在庫を配信データに入れない**（変動するため。また各モールの規約上、価格の自動取得はしない）
- 商品ページのスクレイピングをしない。確認するのは**商品名・型番・仕様**と**URLの生存**のみ
- アクセスは 1req/s 以下（SPEC C3）

---

## 2. データ構造

```jsonc
{
  "version": "2026-09-01T00:00:00Z",     // 生成/更新UTC。アプリはこれで再取得を判断する
  "notice": "商品リンクにはアフィリエイトプログラムを利用しています",
  "disclaimer": "…（特定商品の推奨ではない旨）",
  "sources": [ {"name": "…", "url": "…"} ],   // 全体で参照している公的資料
  "categories": [
    {
      "key": "waterFood",                 // app/lib/data/stockpile.dart の StockpileCategory と同じキー
      "name": "水・食料",
      "items": [
        {
          "id": "water",                  // 既定品目は StockpileItemSpec.id と一致させる（アプリが突合する）
          "name": "長期保存水（5年保存）",
          "spec": "500ml×24本 / 保存期間5年",
          "why": "内閣府・首相官邸ほか「1人1日3リットル×3日分」。5年保存なら入替えが5年に1回で済む",
          "sources": [{"name": "内閣府 ぼうさい83号", "url": "https://…"}],
          "cert": {"name": "防災製品等推奨品", "no": "第○号", "url": "https://…"},  // 任意
          "search": {"yahoo": "…", "rakuten": "…", "amazon": "…"},   // 必須
          "products": [                                              // 任意。死んだら自動で外れる
            {"shop": "yahoo", "title": "…", "url": "https://…", "checked_at": "2026-09-01"}
          ]
        }
      ]
    }
  ]
}
```

### 決めごと

- `search` は**全カテゴリ・全項目に必ず入れる**。商品URLが全滅してもアプリはモール検索へ誘導できる
- `products` は任意。**実際にHTTPアクセスして200を確認したものだけ**載せ、`checked_at` を記録する
- `id` / `key` は `app/lib/data/stockpile.dart` の `StockpileItemSpec.id` / `StockpileCategory` に合わせる。
  アプリの既定品目に無い項目（LEDランタン・ヘルメット等）も載せてよい。アプリは知らない `id` を無視する
- 価格・在庫・レビュー数は入れない

### アプリ側の接続（2026-09-01 実装済み）

`app/lib/data/stockpile_products.dart` が配信JSONを読み、`app/lib/ui/stockpile_screen.dart` の
「探す」ボタンが解説シートを開く。

| 役割 | クラス／関数 |
|---|---|
| 取得・控え | `StockpileProductsRepository.load()` … ネットワーク → 失敗時のみ一時ディレクトリの控え。**新しい方を優先**する（古い控えで廃番・リコール品を出し続けないため） |
| パース | `StockpileProducts.fromJson()` … `categories[].items[]` を畳んで `品目ID → StockpileProductGuide` にする。品目が0件なら `null`（空のシートを開かせない） |
| 検索語 | `StockpileProductGuide.keywordFor(店舗キー)` … その店舗の語 → 他店舗の語 → `null`。`null` のときは画面が `StockpileItemSpec.searchKeyword` にフォールバックする |
| 画面 | `_openGuide()` … 解説があればシート、無ければ従来どおり直接ショップ検索へ |

シートの中身（上から）: 品目名 → 認証バッジ（`cert`。URLがあれば公式ページへ）→ `spec` →
**選び方のポイント**（`why`）→ **参考になる製品**（`products`。メーカー公式ページ）→
**商品を探す**（有効な広告主ごとのボタン。`search` の語でアフィリエイトURLを組み立てる）→
**出典**（`sources`）→ `disclaimer` → `notice`（アフィリエイト表記）。

決めごと:

- 見出しは7言語のARB（`stockpileGuideWhy` ほか6キー）。**`why` / `spec` / `products` / `disclaimer` /
  `notice` は配信JSONの日本語をそのまま出す**（日本のモールで買う日本語の製品情報なので、
  多言語化すると型番・仕様が追えなくなる）
- 商品リンク・検索リンクは必ず `LaunchMode.externalApplication`（アプリ内WebViewでは成果が計測されない）
- シートにもアフィリエイト表記を置く（ステマ規制。画面下部と二重だが、リンクの直前に必要）
- 未知の `id` は無視する。逆に**アプリ既定26品目に解説が欠けていないかは
  `app/test/stockpile_products_test.dart` が配信JSON実体を読んで検査する**（スキーマ変更の検知も兼ねる）

---

## 3. 月次点検の仕組み

`tools/stockpile_check.py`

| 判定 | 条件 | 動作 |
|---|---|---|
| alive | 200 で、リダイレクト先が検索・エラー・トップページでない | そのまま |
| dead | 404 / 410、またはリダイレクト先が検索ページ・エラーページ・トップ | **`products` から除去**（`search` は残す） |
| unknown | 403 / 429 / 5xx / 接続失敗 | **消さない**（モールのbot対策・一時障害の可能性があるため保留） |

- アクセスは 1req/s、UAは `LiveCamJP-Crawler/1.0 (+https://github.com/kotopapa/livecam-jp)`（既存と同じ）
- 終了コード: 0=変化なし / 3=変化あり（`products.json` を書き換えた） / 1=全URL判定不能
- `$GITHUB_OUTPUT` に `changed` / `issue` / `removed` / `unknown` を出す
- `removed >= 3`（`--issue-threshold`）で GitHub Issue を作成し、人手の再調査を促す

`.github/workflows/stockpile-check.yml`（毎月2日 JST 04:00 ＋ workflow_dispatch）

1. `python -m tools.stockpile_check --report $RUNNER_TEMP/stockpile_report.md`
2. `changed=true` なら `data/stockpile` を bot コミット → `gh workflow run publish.yml`
   （GITHUB_TOKEN の push は publish を起動しないため明示実行。shelters.yml と同じ）
3. `issue=true` なら `gh issue create --label stockpile-check`

手動で確認だけしたいとき:

```bash
python -m tools.stockpile_check --dry-run --report /tmp/report.md
```

---

## 4. 人手の再調査手順（Issueが立ったとき）

1. Issue 本文の「products から除去した商品」の表を見る
2. その項目の `search` の検索語でモールを検索し、**同等以上の仕様**（保存年数・入数・容量）の商品を探す
3. 選定基準1〜4に照らして採否を決める。**認定・公的資料・販売実績のいずれも確認できないものは載せない**
4. `data/stockpile/products.json` の該当項目の `products` に追記し、`checked_at` を当日の日付にする
5. `python -m tools.stockpile_check --dry-run` で 200 を確認してからコミットする
   （トップレベルの `version` はスクリプトが更新するが、手編集した場合は**必ず現在UTCに更新する**。
   アプリは `version` が変わったときだけ再取得する — `data/cameras.json` と同じ落とし穴）
6. 防災安全協会の推奨品一覧は年に数回更新される。年1回はこのドキュメントの認定番号を突き合わせる


---

## 5. 収録内容（2026-09-01 時点）

カテゴリ 6 / 項目 33 / 商品 79（全URLを2026-09-01にHTTPアクセスして200を確認）

| カテゴリ | 項目数 | 商品数 |
|---|---:|---:|
| `waterFood`（水・食料） | 7 | 21 |
| `lightPower`（明かり・電源） | 6 | 16 |
| `sanitation`（衛生） | 6 | 10 |
| `firstAid`（救急） | 4 | 10 |
| `evacuation`（避難用） | 6 | 17 |
| `valuables`（貴重品・情報） | 4 | 5 |
| **合計** | **33** | **79** |

`id` は `app/lib/data/stockpile.dart` の `StockpileItemSpec.id` と一致させてある（アプリ既定26品目すべてをカバー、カテゴリキーも一致）。以下の7項目はアプリの既定リストに無い追加項目で、アプリは知らない `id` を無視する（ユーザーがカスタム項目として追加したときの参考になる）:

- `waterFood` / `cassetteStove` … カセットコンロ
- `waterFood` / `gasCanister` … カセットボンベ
- `lightPower` / `lantern` … LEDランタン（乾電池式）
- `lightPower` / `batteryCharger` … 乾電池式充電器
- `sanitation` / `compressedTowel` … 圧縮タオル
- `evacuation` / `helmet` … 防災用ヘルメット・防災ずきん
- `evacuation` / `whistle` … ホイッスル（防災笛）

### 項目と商品の一覧

#### 水・食料（`waterFood`）

**長期保存水（5年以上保存）**（`water`）  
仕様: 500ml / 2L ボトル、賞味期限5年〜（製品により7〜15年）  
出典: [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [農林水産省 家庭備蓄ポータル「大事な水、どうやって備えますか？」](https://www.maff.go.jp/j/zyukyu/foodstock/imadoki/imadoki02_10.html) / [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf)  
- 富士ミネラルウォーター 非常用5年保存水（賞味期限5年6か月・硬度40mg/L・1971年から販売）  
  https://www.fujimineral.jp/products/hijou/
- 赤穂化成 備蓄水（室戸海洋深層水・5年保存）  
  https://web.ako-kasei.co.jp/catalogue/product/bichikusui

**主食（アルファ米・保存食セット）**（`stapleFood`）  
仕様: アルファ米 1食100g（出来上がり約260g・360kcal前後）／保存5年。注水または熱湯で調理  
出典: [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- 尾西食品 尾西の白飯 100g（保存5年・出来上がり260g・366kcal。同社は1944年にアルファ米を開発）  
  https://www.onisifoods.co.jp/products/hakuhan.html
- 尾西食品 尾西の五目ごはん 100g（保存5年・377kcal・肉魚不使用）  
  https://www.onisifoods.co.jp/products/gomoku.html
- サタケ マジックライス 保存食（全9種・各100g・保存5年・注水量でごはん/雑炊を選べる。1995年前後から30年のロングセラー）  
  https://www.satake-fb.co.jp/products/hozon/
- アルファー食品 安心米（保存5年・国産米100%・特定原材料等28品目不使用）  
  https://www.alpha-come.co.jp/product/longlife.php
- 尾西食品 尾西の長期保存食セット3日分（保存5年・主食＋パン＋保存水500ml×4本）  
  https://www.onisifoods.co.jp/products/longtermstoragefood_3.html

**主菜・副菜（常温で食べられるレトルト）**（`retortFood`）  
仕様: 1食170〜200g／賞味期間4年1か月〜5年6か月。温めずにそのまま食べられるタイプ  
出典: [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- 江崎グリコ 常備用カレー職人 中辛 170g（賞味期限66か月・温めずに食べられる。2012年発売のロングセラー）  
  https://www.glico.com/jp/product/food_curry/curryshokunin/45105/
- ハウス食品 温めずにおいしいカレー まろやか野菜カレー 200g（賞味期間4年1か月・日本災害食認証）  
  https://housefoods.jp/products/catalog/cd_1,092501,ret,curry,ata.html
- ホリカフーズ レスキューフーズ 一食ボックス カレーライス（賞味期間5年6か月・発熱剤同梱で火も水も不要）  
  https://www.foricafoods.co.jp/rescue/rm_curry_riceb.html
- カゴメ 野菜の保存食セット（野菜一日これ一本 長期保存用190g＋野菜たっぷりスープ160g・賞味期間5.5年）  
  https://www.kagome.co.jp/products/hozon-yasai/

**缶詰・缶詰パン**（`cannedFood`）  
仕様: パンの缶詰 1缶100g前後／保存3年6か月〜5年。フリーズドライ缶は最長25年  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html)  
- パン・アキモト パンの缶詰 PANCAN（100g・賞味期限5年・乳酸菌L-137配合。阪神・淡路大震災を機に開発）  
  https://www.panakimoto.com/products_pancan/
- パン・アキモト 救缶鳥（200g・賞味期限5年。期限1年前に回収して飢餓地域へ届ける仕組み）  
  https://www.panakimoto.com/products_kyucancho/
- アスト 新・食・缶ベーカリー（100g・5年保存4種／3年保存4種・卵不使用ラインあり）  
  https://www.ast-corp.jp/shop/ichiran/bakery/
- セイエンタプライズ サバイバルフーズ 大缶（422g・約10食分・賞味期限25年）  
  https://www.sei-inc.co.jp/lineup/l-chickenstew

**乳児用ミルク（液体ミルク・粉ミルク）**（`babyFormula`）  
仕様: 液体ミルク 125ml前後／常温そのまま授乳可。粉ミルクはスティックタイプが計量不要  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- （商品URLなし。`search` の検索語でモール検索へ誘導する）

**カセットコンロ**（`cassetteStove`）  
仕様: 最大発熱量 2.1〜3.5kW（1,800〜3,000kcal/h）／本体は製造から10年で買い替えが目安  
出典: [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [岩谷産業「カセットボンベの使用期限」（製造から約7年、こんろ本体は10年が目安）](https://www.iwatani.co.jp/jpn/consumer/products/cg/useful/bombe/)  
- 岩谷産業 カセットフー 達人スリムV CB-TS-5（3.4kW・連続燃焼約68分・約1.3kg。達人スリム系4世代目）  
  https://www.iwatani.co.jp/jpn/consumer/products/cg/stove/cb-ts-5/
- 岩谷産業 カセットフー タフまる CB-ODX-1（3.3kW・連続燃焼約75分・ダブル風防・耐荷重20kg。屋外の炊き出し向け）  
  https://www.iwatani.co.jp/jpn/consumer/products/cg/outdoor/cb-odx-1/
- ニチネン マイコンロ（KC-353A ほか。3.5kW／小型のKC-333Aは0.85kWで連続燃焼約230分とガス効率が高い）  
  https://www.nitinen.com/konro.html

**カセットボンベ**（`gasCanister`）  
仕様: 250g×3本パックが標準（120gの小型もあり）／使用期限は製造から約7年が目安  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [岩谷産業「カセットボンベの使用期限」（製造から約7年、こんろ本体は10年が目安）](https://www.iwatani.co.jp/jpn/consumer/products/cg/useful/bombe/)  
- 岩谷産業 カセットガス（オレンジ）3P CB-250-OR（250g×3本・日本/中国製）  
  https://www.iwatani.co.jp/jpn/consumer/products/cg/cb/cb-250-or/
- 岩谷産業 カセットガス パワーゴールド3P CB-250-3PG（イソブタン比率を高めた低温時対応）  
  https://www.iwatani.co.jp/jpn/consumer/products/cg/cb/cb-250-3pg/
- ニチネン マイ・ボンベL 250g（国内生産）  
  https://www.nitinen.com/item/421/

#### 明かり・電源（`lightPower`）

**懐中電灯（LED）**（`flashlight`）  
仕様: 14〜350lm／連続点灯 6〜55時間／単1〜単4形の乾電池式  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- パナソニック 電池がどれでもライト BF-BM10（単1〜単4形のどれか1本で点灯。単1形1本で約55時間）  
  https://panasonic.jp/flashlight/products/BF-BM10/spec.html
- GENTOS 閃 参 SG-535（350lm・単4形×3本・IP64・2m落下耐久。SG-505の公式後継）  
  https://www.gentos.jp/products/series/senn/senn-san/
- パナソニック LED防水ライト BF-SG01N（18lm・約77時間・水深20m30分の防水）  
  https://panasonic.jp/flashlight/products/BF-SG01N/spec.html

**LEDランタン（乾電池式）**（`lantern`）  
仕様: 110〜800lm／連続点灯 8時間〜1,000時間（最小照度時）／単3形または単1形  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf)  
- パナソニック 乾電池エボルタNEO付き LEDランタン BF-AL06N（最大110lm・最長約2,200時間・単3形×3本・防滴）  
  https://panasonic.jp/flashlight/products/BF-AL06N/spec.html
- パナソニック 多機能強力ランタン BF-BL45M（最大800lm・最小照度で約1,000時間・単1形×3本・IPX2）  
  https://panasonic.jp/flashlight/products/BF-BL45M/spec.html
- GENTOS Explorer EX-236D（430lm・Ecoで142時間・単3形×6本・IP68準拠。EX-136Sの公式後継）  
  https://www.gentos.jp/products/series/explorer/ex-236d/

**乾電池（アルカリ・長期保存タイプ）**（`batteries`） 🏅**防災製品等推奨品**  
仕様: 使用推奨期限10年のアルカリ乾電池。単1〜単4形を機器に合わせて  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- マクセル アルカリ乾電池 ボルテージ（使用推奨期限10年・10年間液もれ補償） 🏅  
  https://www.maxell.jp/consumer/voltage.html
- パナソニック 乾電池エボルタNEO（10年保存・液もれ防止製法Ag+）  
  https://panasonic.jp/battery/drycell/evoltaneo.html
- 東芝ライフスタイル アルカリ1（10年長期保存）  
  https://www.toshiba-lifestyle.com/jp/batteries/lr20an/

**モバイルバッテリー（PSE適合）**（`powerBank`）  
仕様: 10,000mAh前後（スマホ約2回分）／PD 18W以上／丸形PSEマーク必須  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- cheero Power Plus 5 10000mAh with Power Delivery 18W（CHE-101。公式ページにPSEマーク付商品と明記）  
  https://cheero.net/powerplus5_10000/

**乾電池式充電器**（`batteryCharger`）  
仕様: 単3形×4本でスマホを約0.5〜0.7回充電／LEDライト兼用機あり  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- パナソニック 乾電池式モバイルバッテリー BH-BZ40K（単3形×4本・LEDライト約80時間）  
  https://panasonic.jp/battery/products/BH-BZ40K/spec.html
- パナソニック USB入出力付急速充電器 BQ-CC87L（充電池の充電に加え、単3形乾電池でもスマホへ出力可・LEDライト約11時間）  
  https://panasonic.jp/battery/products/BQ-CC87L/spec.html
- 多摩電子工業 アルカリ乾電池4本交換式充電器 C変換付 FFD48SCW（単3形×4本・USB-C変換付）  
  https://tamadenco.co.jp/product/ffd48scw/

**防災ラジオ（手回し・ソーラー充電）**（`radio`）  
仕様: AM/FM（ワイドFM 76〜108MHz）対応／手回し1分で約14〜15分受信／乾電池も併用できる機種  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- ソニー ICF-B300（手回し／ソーラー／USB充電・ワイドFM・スマホ充電可・IPX4・395g）  
  https://www.sony.jp/radio/products/ICF-B300/
- 東芝ライフスタイル TY-JKR6（内蔵コンデンサー蓄電＋単4形乾電池・手回し1分でラジオ約15分・IP54・サイレン）  
  https://www.toshiba-lifestyle.com/jp/pro_radio/ty-jkr6/
- パナソニック RF-TJ20（ワイドFM・単4形×3本・手回し1分で約14分・サイレン・蓄光電源ボタン）  
  https://panasonic.jp/radio/products/RF-TJ20/spec.html

#### 衛生（`sanitation`）

**簡易トイレ・携帯トイレ**（`portableToilet`）  
仕様: 凝固剤＋排便袋のセット。1回分ずつの個包装／保存年数5〜15年  
出典: [内閣府 広報ぼうさい第111号（出典：経済産業省製造産業局生活製品課）](https://www.bousai.go.jp/kohou/kouhoubousai/r06/111/news_08.html) / [神奈川県「携帯トイレを備蓄しましょう」](https://www.pref.kanagawa.jp/docs/j8g/bousai/keitaitoirebitiku.html) / [東京都目黒区「災害時のトイレは家庭での備蓄が重要です」](https://www.city.meguro.tokyo.jp/bousai/bousaianzen/bousai/saigai_toilet.html) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf)  
- 総合サービス サニタクリーン／簡単トイレ（吸水シート一体型で凝固剤散布不要・1個で約1,000cc吸収・保管期間7年。累計出荷1億枚）  
  https://sanitaclean.com/disposal-toilet-products/
- まいにち マイレット S-100（100回分・抗菌性凝固剤7g×100・保存年数10年・約2.4kg）  
  https://www.mylet.jp/view/item/000000000008
- クリロン化成 BOS 非常用臭わないトイレセット（防臭袋BOS採用・1回/5回/15回/30回/50回/100回/400回）  
  https://bos-bos.com/product/toilet/
- エクセルシア ほっ！トイレ（石灰系タブレット式・保存年数5年）  
  https://www.excelsior-inc.com/products/hot-toilet/

**トイレットペーパー**（`toiletPaper`）  
仕様: 大人1人1日あたり約0.3ロール（3日で1ロール、7日で約2〜3ロール）  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf)  
- （商品URLなし。`search` の検索語でモール検索へ誘導する）

**ウェットティッシュ・からだ拭き**（`wetWipes`）  
仕様: からだ拭きは大判40×30cm前後／除菌タイプは120枚入前後。ノンアルコールは肌が弱い人・乳幼児向け  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/) / [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html)  
- 日本製紙クレシア アクティ からだふきタオル 超大判・超厚手（40×30cm・30枚入・ノンアルコール弱酸性）  
  https://acty.crecia.jp/product/raku-care.html
- 日本製紙クレシア スコッティ ウェットティシュー 除菌ノンアルコールタイプ（120枚・つめかえ式）  
  https://scottie.crecia.jp/wet/nonalcohol.html
- 大王製紙 エリエール 除菌できるノンアルコールタオル（42枚入・135×185mm・菌を99.9%除去）  
  https://www.elleair.jp/product/detail/jokin_13_0001

**ゴミ袋（大型・防臭）**（`garbageBags`）  
仕様: 災害ごみ用は90L・厚み0.045mm前後。汚物用は消臭タイプの中〜大サイズ  
出典: [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html) / [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- 日本サニパック 業務用ポリ袋 90L 透明 N9C（900×1000mm・0.045mm・30枚入）  
  https://www.sanipak.jp/products_search/general_garbage_bag_90l/item_n9c
- 日本サニパック ニオワイナ 消臭ポリ袋（硫化水素94.7%・アンモニア83%削減など消臭性能を数値公表）  
  https://www.sanipak.jp/series/niowaina.html

**圧縮タオル**（`compressedTowel`）  
仕様: フェイスタオル 35×85cm／バスタオル 120×60cm（圧縮後 約12.6×21×3.2cm）  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- 足立織物 非常用圧縮タオル（SK-FT1 フェイスタオル35×85cm／SK-BW バスタオル120×60cm・綿100%）  
  https://www.atec1945.co.jp/bousai-product/bousai-towel

**紙おむつ・おしりふき**（`diapers`）  
仕様: 乳幼児1人1日 おむつ10枚／おしりふき1パックが目安  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- （商品URLなし。`search` の検索語でモール検索へ誘導する）

#### 救急（`firstAid`）

**救急セット（応急手当セット）**（`firstAidKit`）  
仕様: 絆創膏・滅菌ガーゼ・包帯・三角巾・消毒液・はさみ・手袋などをまとめたもの  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- 日赤サービス 応急手当セット N115（115×190×50mm・日本赤十字社の救急法テキスト同梱）  
  https://www.jrcsc.co.jp/view/item/000000000007
- 日進医療器 リーダー 防災用救急セット（アルミ 20人用・50人用／木製・ポリ救急箱）  
  https://www.nissin-iryouki.jp/product/bousai

**常備薬・お薬手帳ケース**（`medicine`）  
仕様: 処方薬は最低3日分＋お薬手帳（またはその写し）。診察券・保険証をまとめられるケース  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- リヒトラブ ホスピタルポーチ A-7205（115×12×140mm・お薬手帳＋診察券＋保険証をまとめて携行）  
  https://www.lihit-lab.com/products/catalog/a-7205.html
- リヒトラブ おくすり手帳ホルダー HM532（114×159mm）  
  https://www.lihit-lab.com/products/catalog/hm532.html

**マスク（不織布）**（`mask`）  
仕様: 大人1人1日1枚（東京備蓄ナビ）。JIS T 9001（一般用マスク）適合品を選ぶ  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- 興和 三次元マスク（JIS T 9001 一般用マスク 規格適合番号 G42107003 を公式に明記・4層構造・日本製）  
  https://hc.kowa.co.jp/3jigen/detail_3jigen.php
- ユニ・チャーム 超立体マスク スタンダード（30枚入・JIS T 9001 認証マーク表示）  
  https://jp.unicharm-mask.com/ja/products/rittai-standard.html
- 玉川衛材 フィッティ 7DAYSマスク EXプラス 100枚入（50枚×2袋・サイズ5展開。備蓄向けの大容量分包）  
  https://www.tamagawa-eizai.co.jp/product/mask/7days_explus100/

**消毒液（手指用アルコール）**（`disinfectant`）  
仕様: 大人1人1日 アルコールスプレー0.1本（＝10日で1本）が目安。指定医薬部外品を選ぶ  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- 花王プロフェッショナル ハンドスキッシュEX 800mL（指定医薬部外品・エタノール65vol%。消防法上の危険物に該当せず「備蓄等にも適しています」と公式に明記）  
  https://pro.kao.com/jp/products/kps01/4901301507310/
- 健栄製薬 手ピカジェル（指定医薬部外品・エタノール76.9〜81.4vol%・60mL/300mL）  
  https://www.kenei-pharm.com/tepika/
- サラヤ アルソフト 手指消毒ローション（指定医薬部外品・250mL/60mL/480mL詰替）  
  https://family.saraya.com/products/alsoft/alsoft.html

#### 避難用（`evacuation`）

**防災リュック（非常用持ち出し袋セット）**（`backpack`）  
仕様: 1人用で容量18〜30L・総重量2〜5kg。同梱の保存食・保存水は5年前後  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [内閣府 広報ぼうさい第83号 特集3「地震に備える」](https://www.bousai.go.jp/kohou/kouhoubousai/h28/83/special_03.html)  
- LA・PITA 防災セット SHELTER プレミアム 1人用（約30品目・リュック約30L・総重量約5.0kg・保存食/保存水5年）  
  https://lapita.co.jp/item/10000170/
- 山善 防災バッグ 一次避難用 災害対策30点セット YBG-30（18L・1.97kg・防災士監修）  
  https://yamazenbizcom.jp/item/22666.html
- ミドリ安全 非常持出セット17（9点・保存年数5年）  
  https://ec.midori-anzen.com/shop/g/g4082100554/

**アルミブランケット（エマージェンシーシート）**（`blanket`）  
仕様: 使用時 約142×213cm／収納時 手のひら大／重量 48〜91g  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- SOL エマージェンシーブランケット 1人用 12132-6（約142×213cm・約65g・体熱の90%を反射。輸入元スター商事）  
  https://www.star-corp.co.jp/shop/products/detail/10124
- SOL エマージェンシーブランケット 備蓄用パック 12347-4（1パック200枚のバルク品。公式に「自治体や企業の防災用備蓄品としてお奨め」と明記）  
  https://www.star-corp.co.jp/shop/products/detail/20004
- ハイマウント サバイバルシートII 22130（約210×130cm・約48g・アルミ蒸着ポリエステル）  
  https://highmount.jp/brands/highmount/survival-sheet/

**軍手・作業用手袋**（`gloves`）  
仕様: 普段使いは背抜き手袋。片付け作業には EN 388 の耐切創レベルが表示された手袋  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- ショーワグローブ No.310 グリップ（背抜き手袋のロングセラーと公式に明記・10ゲージシームレス・抗菌防臭）  
  https://www.showaglove.co.jp/product/detail/professional/21
- ショーワグローブ S-TEX 581（EN 388:2016 / EN ISO 13997 耐切創レベルE・アラミド＋ステンレス繊維）  
  https://www.showaglove.co.jp/product/detail/industrial/660
- ショーワグローブ No.281 テムレス（透湿防水。濡れた瓦礫・冬季の作業向け）  
  https://www.showaglove.co.jp/product/detail/professional/421

**防災用ヘルメット・防災ずきん**（`helmet`） 🏅**防災製品等推奨品**  
仕様: ヘルメットは厚生労働省の保護帽規格の国家検定合格品（労・検ラベル）。区分は「飛来・落下物用」／「墜落時保護用」  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf) / [一般社団法人 日本ヘルメット工業会 FAQ（保護帽の交換目安）](https://japan-helmet.com/faq/) / [公益財団法人 日本防炎協会 防炎製品ラベル（対象品目に防災頭巾）](https://www.jfra.or.jp/member/s06.html)  
- DICプラスチック IZANO2（450g・折りたたみ時厚63mm・頭囲47〜62cm・「飛来落下物用」「墜落時保護用」の2区分で国家検定取得）  
  https://www.dic-plas.co.jp/products/helmet/izano2/index.html
- 加賀産業 オサメット KGO-1（約375g・収納時A4サイズ厚45mm・ABS樹脂・国家検定合格「飛来落下物用」）  
  https://www.kagahelmet.com/products/osamet/osamet-1.html
- トーヨーセフティー BLOOM No.100（約430g・折りたたみ345×195×80mm・日本製・国家検定合格「飛来落下物用」）  
  https://www.toyo-safety.co.jp/products/100/
- デビカ 防災ずきん 衝撃吸収パッド入り 143544/143545（W300×D90×H430mm・376g・難燃加工繊維） 🏅  
  https://debika.co.jp/products/detail.php?product_id=741
- デビカ 防災ずきんアルミ 143515（W260×D50×H450mm・378g・防炎加工。日本防炎協会認定品と公式に明記）  
  https://debika.co.jp/products/detail.php?product_id=269

**ホイッスル（防災笛）**（`whistle`）  
仕様: 音量 109〜115dB。可動部（コルク玉）のないピーレス構造は水濡れ・凍結に強い  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- Fox 40 Classic（115dB・3チャンバーのピーレス構造で可動部なし・自己排水）  
  https://www.fox40world.com/classic
- モルテン ホイッスル ドルフィンプロ WDFP（109dB／1m・コルクなし）  
  https://shop.moltensports.jp/products/wdfp

**ロープ（避難用・多用途）**（`rope`）  
仕様: 避難用は径12mm・長さ5〜6m・約50cm間隔のコブ加工＋カラビナ付き（使用荷重115〜150kgf）  
出典: [総務省消防庁 備蓄品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/store.pdf)  
- ユタカメイク 簡易避難用ロープ AK-700（12mm×5m・コブ11個・ポリエステル難燃素材・使用荷重115kgf以下・カラビナ付）  
  https://yutakamake.co.jp/product/rope/rope21/2112

#### 貴重品・情報（`valuables`）

**現金（小銭）**（`cash`）  
仕様: 10円玉を中心に小銭。公衆電話・自動販売機用  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- （商品URLなし。`search` の検索語でモール検索へ誘導する）

**身分証・書類の写しと防水ケース**（`idCopy`）  
仕様: スマホ用防水ケースは IPX8 相当（水深10〜30m相当の試験）。書類はA4が入る防水袋  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- サンワサプライ スマートフォン防水ケース PDA-SPCWP2W（IPX8相当・最大5.7インチ・48g）  
  https://www.sanwa.co.jp/product/syohin?code=PDA-SPCWP2W
- オウルテック 2WAY防水ケース OWL-WPCSP19（IPX8相当／水深30m相当の防水テスト合格・最大6.7インチ）  
  https://www.owltech.co.jp/product-top/cat_goods/cat_goods-waterproof-case/wpcsp19/
- Aquapac Waterproof Floating Phone Case – Plus（IPX8／水深10m・フロートパッド内蔵で水に浮く・ケースのまま操作可）  
  https://aquapac.net/products/waterproof-phone-case-plus

**連絡先メモ（耐水）**（`contactMemo`）  
仕様: 家族の連絡先・集合場所・災害用伝言ダイヤル(171)の使い方を書いた耐水メモ  
出典: [総務省消防庁 非常用持出品チェックシート](https://www.fdma.go.jp/relocation/bousai_manual/too/pdf/mocidashi.pdf)  
- （商品URLなし。`search` の検索語でモール検索へ誘導する）

**充電ケーブル**（`cable`）  
仕様: 端末に合う端子（USB-C / Lightning）で1〜1.8m。Lightning は Apple MFi 認証品  
出典: [東京都「東京備蓄ナビ」](https://www.bichiku.metro.tokyo.lg.jp/)  
- Anker PowerLine III Flow USB-C & ライトニングケーブル（0.9m/1.8m・Apple MFi認証済みと公式に明記・約25,000回の折り曲げ試験）  
  https://www.ankerjapan.com/products/a866
- サンワサプライ USB2.0 Type-Cケーブル KU-CCP6015W（1.5m・USB-IF認証品・PD 60W）  
  https://www.sanwa.co.jp/product/syohin?code=KU-CCP6015W

---

## 6. 「防災製品等推奨品」認定について（重要な調査結果）

一般社団法人 防災安全協会の認証制度。今回の調査で分かったこと:

| 事実 | 内容 |
|---|---|
| 公式ドメイン | **bousai-anzen.com**（`bousaisys.com` は実在しない＝DNS解決不可） |
| 制度ページ | https://bousai-anzen.com/system/ ／ https://bousai-anzen.com/system/certification02/ |
| **認定品一覧はHTMLに存在しない** | 一覧はPDFカタログ（『防災・防疫推奨品』約75MB）1本のみ。商品検索・カテゴリ別ページは無い |
| **「第○号」形式の認定番号は存在しない** | 協会の正式表記は「**推奨品番号**」（防災＝通し番号、防疫＝ゼロ埋め4桁）。カタログ全文に「第…号」の認定番号は無い |
| **カタログは無断転載禁止** | 奥付に「本カタログ掲載の推奨品データ等の無断転載を禁じます。頒価1,000円」と明記 |

### 本データでの扱い（決定）

- **カタログから抜き出した認定品リストは products.json に転載しない**。CLAUDE.md の方針
  （「無断転載禁止を明記している運営者のデータは技術的に取れても実装しない」）に従う。
- 代わりに、**メーカー自身の公式製品ページに認証取得の記載があるものだけ** `cert` を付けた。該当は2項目:

| 項目 | 商品 | 確認先 |
|---|---|---|
| `batteries` | マクセル アルカリ乾電池 ボルテージ | https://www.maxell.jp/consumer/voltage.html |
| `helmet` | デビカ 防災ずきん 衝撃吸収パッド入り 143544/143545 | https://debika.co.jp/products/detail.php?product_id=741 |

- `cert` が無いことは「認定されていない」ことを**意味しない**（協会側の一覧で突合できないだけ）。
  この旨は products.json の `cert_note` にも書いてあり、アプリはバッジを出すならこの2件のみにすること。
- 認定バッジを本格的に出したい場合は、**協会に照会してデータ利用の許諾を得る**のが正規ルート。
- 参考: LA・PITA 防災セット SHELTER は自社ページに「防災安全協会推奨リュック採用」と書いているが、
  協会側の一覧で突合できないため `cert` は付けていない。
- **混同注意**: 「日本防災士機構」は別団体で、公式に「防災商品・サービス等の評価や認定、推奨、監修は行っていない」と明言している。

### 認定以外に使える客観的な物差し

| 分野 | 物差し | 本データで採用した例 |
|---|---|---|
| ヘルメット | 厚生労働省 保護帽規格の**国家検定（労・検）**＋区分（飛来落下物用／墜落時保護用） | IZANO2（2区分取得）・オサメット・BLOOM No.100 |
| 防災ずきん | （公財）**日本防炎協会 防炎製品ラベル**（対象品目に防災頭巾を含む） | デビカ 防災ずきんアルミ 143515 |
| マスク | **JIS T 9001 一般用マスク 適合番号**（BFE/PFE/VFE は各社とも非公表） | 興和 三次元マスク（G42107003）・ユニ・チャーム 超立体 |
| 手袋 | **EN 388:2016 / EN ISO 13997 耐切創レベル** | ショーワグローブ S-TEX 581（レベルE） |
| 消毒液 | **指定医薬部外品**の承認＋**消防法上の危険物該否**（大量備蓄では後者が重要） | 花王 ハンドスキッシュEX（消防法非該当を公式明記） |
| モバイルバッテリー | **丸形PSEマーク**（2019年2月以降、無表示品は販売禁止） | cheero Power Plus 5（公式にPSE明記） |
| 食品 | 日本災害食学会の**日本災害食認証／本格レスキュー食認定** | ハウス 温めずにおいしいカレー・レスキューフーズ |
| ケーブル | **Apple MFi 認証** / **USB-IF 認証** | Anker PowerLine III Flow・サンワサプライ KU-CCP6015W |
| ボンベ | 岩谷産業の公式目安「**ボンベは製造から約7年 / こんろ本体は10年**」 | 入替え時期の根拠として `gasCanister` の why に記載 |

---

## 7. 除外したもの・採用しなかったもの

### 廃番・リコール・在庫希少（調査で判明。載せてはいけない）

| 商品 | 状況 |
|---|---|
| Anker PowerCore 10000（A1263） | 公式に販売終了＋2022/12/25〜2025/10/21販売分の**回収（リコール）告知**。備蓄品として選定不可 |
| ニチガス カセットボンベ | 2017-02-03 に**自主回収告知**（2011年12月以降製造分、ガス漏れの可能性） |
| サンワサプライ BTN-DC2NBK（乾電池式充電器） | 公式に「廃止（生産終了）」明記 |
| イワタニ 達人スリム CB-AS-1 | 公式製品ページが302リダイレクト＝**廃番**（「達人スリムIII は CB-AS-1」という通説は誤り。III は CB-SS-50、現行は達人スリムV CB-TS-5） |
| イワタニ 風まるII CB-KZ-2 | 公式ページ302＋現行一覧に非掲載＝**廃番の疑い**。炊き出し向けに流通量が多いので注意 |
| イワタニ 達人スリムIII CB-SS-50 | 個別ページは生きているが現行一覧に非掲載＝在庫限りの可能性。CB-TS-5 を採用した |
| ソニー ICF-B99 | 公式に「在庫希少商品」表示。後継相当の ICF-B300 を採用した |
| GENTOS EX-136S / 閃 SG-505 | 公式に廃番表示。後継の EX-236D / SG-535 を採用した |
| リヒトラブ HM501 / HM571 / HM591 | 生産終了（HM591 は代替品なし）。現行の HM532 / A-7205 を採用した |
| Anker A1367 / A1647 / A1640 | 公式ストアで Sold Out。販売終了か一時在庫切れか判別できないため採用せず |
| パナソニック BF-AL06K | 上位に BF-AL06N があり流通在庫のみの可能性。BF-AL06N を採用した |

### 公式ページに到達できず仕様を確認できなかったメーカー（採用せず）

- **エレコム（elecom.co.jp）全域** … HTTP 403。防水ケース・充電ケーブル・モバイルバッテリー・乾電池式充電器すべて未確認
- **アイリスオーヤマ（irisohyama.co.jp / irisplaza.co.jp）全域** … HTTP 403。LEDランタン・防災ラジオ・7日分非常食セットとも型番すら特定不能
- **無印良品（muji.com）** … タイムアウト／bot遮断
- **モノタロウ（monotaro.com）**、**経済産業省 トイレ備蓄ページ（meti.go.jp）** … HTTP 403
- ボローニャマックス（bolognemax.jp） … DNS解決不可（缶deボローニャは直営ストアのみ実在確認）
- 白十字（hakujuji.co.jp）、霧島湧水（kirishima-yuusui.jp） … 中間証明書の不備で WebFetch 失敗（CLAUDE.md の truststore 既知事象と同種）

### そのほか採用しなかったもの

- **モール（Yahoo!ショッピング / 楽天 / Amazon）の商品ページURL** … `products` には入れていない。
  理由は (a) 同じ商品でも出品者ごとにURLが乱立し寿命が短い、(b) Amazon等はbotアクセスを遮断するため
  月次の生存確認が「判定保留」ばかりになる、(c) スクレイピングを避ける方針。
  **モールへの導線は `search`（検索語）でアプリ側がアフィリエイト検索URLを組み立てる**設計にしてある。
  `products` にはメーカー公式製品ページ（`shop: "official"`）を入れており、仕様の裏取り先としても機能する。
- **7日分の非常食セット** … メーカー公式で仕様を確認できるものが無かった（防災専門店のオリジナル編成が主流）。
  `stapleFood` の3日分セット＋日数指定の検索語で代替している。
- **価格・在庫・レビュー数** … 変動するため配信データに一切入れない。

### 数値の裏取りができなかった主張（`why` に書いていない）

- 各社の発売年・販売実績年数・市場シェア … ほぼ全商品でメーカー公式に記載なし
- 官公庁・自治体の備蓄採用実績 … 一次情報で確認できたものは無い（SOL 備蓄用パックの「自治体や企業の防災用備蓄品としてお奨め」が唯一の公式表記）
- マスクの BFE / PFE / VFE の%値 … 調査した全社が非公表
- 「洞爺湖サミットで提供」「累計◯万個」などの販売サイト側の宣伝文句 … 公式で確認できないため不採用

---

## 8. 今後の運用（まとめ）

| 頻度 | やること | 誰が |
|---|---|---|
| 毎月2日 04:00 JST | `stockpile-check.yml` が全商品URLを叩き、死んだものを `products` から外して bot コミット → publish | 自動 |
| 除去3件以上 | GitHub Issue（label: `stockpile-check`）が立つ → §4 の手順で代替商品を再調査 | 人手 |
| 年1回（防災の日ごろ） | 廃番・リコール情報の洗い直し、防災安全協会の推奨品カタログの更新確認、公的資料の数値（1人1日3L等）の再確認 | 人手 |
| 随時 | アプリの既定品目（`app/lib/data/stockpile.dart`）を増減したら、対応する `id` を products.json にも足す | 人手 |

**忘れやすい注意点**

- `products.json` を手で編集したら **トップレベルの `version` を現在UTCに更新する**。
  アプリは `version` が変わったときだけ再取得するため、忘れると配信されない（`data/cameras.json` と同じ落とし穴）。
- 配信は publish（GitHub Pages）経由。`data/stockpile/**` が publish.yml の trigger paths に入っている。
- **モバイルバッテリー・液体ミルク・おむつ・処方薬は期限や適合サイズが変わる**ため、
  アプリ側の点検日リマインド（3月11日・9月1日）と合わせて運用する前提で `why` に注意書きを入れてある。
