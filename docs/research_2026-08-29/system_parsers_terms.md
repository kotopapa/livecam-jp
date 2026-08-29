# 掲載元システム別 規約・取得構造調査（2026-08-29）

対象: livecam.asia 索引で「ページのみ」に分類された10システム。各サイトの一次ページ・JS・JSON・CSV・PDF を HTTP で直接取得して確認した（取得ログは scratchpad）。
判定の凡例: **実装可** = 直リンク禁止表記なし・機械取得可 / **条件付き** = 実装可だが座標や規約の一部に要確認事項あり / **要照会** = 運営者に照会しないと採用できない / **不可** = 明示的禁止 or 配信停止。

既存 cameras.json との重複確認は `operator` × feed ホストで集計した（数値は 2026-08-29 時点）。

---

## 1. 福岡県 河川防災情報（福岡県総合防災情報 doboku-bousai.pref.fukuoka.lg.jp）

- **判定: 条件付き（規約上は可。座標の所在が未特定）**
- 根拠
  - 利用案内「ご利用について」 http://doboku-bousai.pref.fukuoka.lg.jp/river/html/usageguide/about.html  
    > 本システムのデータは福岡県、国土交通省、福岡市及び北九州市が観測している雨量・水位・ダム諸量・カメラの情報を提供しております。なお、ここで提供している情報は、あくまで速報値（参考値）であり…  
    > 本システムで提供される情報はテレメータから自動的に送られてくるデータを、観測後直ちにお知らせする目的で作られています。
    → 著作権・転載・リンクに関する記述は無し（免責のみ）。サイト内に別の規約ページは見つからず（riyou.html 等は404）。
  - robots.txt: **https は TLS ハンドシェイク失敗（curl 000）、http は robots.txt 自体が取れない（トップ / は 403）**。http でのページ・画像取得は 200。アプリからは http 参照になる点に注意（ATS例外が必要）。
- 取得構造
  - 一覧: `http://doboku-bousai.pref.fukuoka.lg.jp/river/servlet/bousaiweb.servletBousaiContents?sv=3&mp=0&no=0&fn=0&cn=0&dk=15&nw=1&style=itv_table&pg=<1..35>`（Shift_JIS。1ページ6局 × 35ページ ≒ **210局**。各ページの `siteNoList = [4,273,...]` に局番号、`class="itvTbIm"` に河川名・地点名、`<img id="img_<sn>" src="/camera/<YYYYMMDD>/<sn3桁>/<sn3桁>_<YYYYMMDDHHMM>_QQV.jpg">` に最新画像）
  - 個別: `/river2/camera/detail_<sn>.html`（静的HTML。`var obstime = "202608291435"` に最新時刻。10分更新）
  - 画像URL: `/camera/<YYYYMMDD>/<sn3>/<sn3>_<YYYYMMDDHHMM>_QQV.jpg`（**タイムスタンプ名＝都度解決型**。QQV は 160x120 のサムネイル。他サイズのサフィックスは未確認）
  - **座標: サイト内で未発見**。GIS（/gis/）は gis_top/ へリダイレクトされ、カメラのレイヤJSONは特定できず。detail ページにも住所なし。→ 河川名＋地点名でのジオコーディング、または kawabou（川の防災情報）に福岡県設置カメラとして同一地点があるか照合が必要
- 台数: 約210（索引187）
- 既存パーサとの関係: 福岡市(fukuoka_city_river 24)・北九州市(23)・国交省事務所(筑後川72・遠賀川26)とは別。福岡県設置分は既存0。kawabou の ownName「福岡県」との重複確認が必要

## 2. 静岡県 SIPOS-RADAR 河川監視カメラ（www.cam.shizuoka4.jp / sipos.pref.shizuoka.jp）

- **判定: 要照会**
- 根拠
  - 注意事項 https://sipos.pref.shizuoka.jp/Caution/index.html  
    > 当ホームページに掲載されている個々の情報（文章、写真、イラスト、画像など）は、著作権の対象となっています。…「私的使用のための複製」や「引用」など著作権法上認められた場合を除き、無断で複製・転用することはできません。  
    > 本サイトへのリンクの際は、必ずトップページにお願いします。また、リンクによって生じる一切の責任は負いかねます。  
    > ◎情報提供元 株式会社ウェザーニューズ
    → 画像の転用禁止＋**リンクはトップページ限定**を明記。ディープリンク（画像直参照）はこの方針に反する
  - robots.txt: sipos.pref.shizuoka.jp は `Disallow:/ Allow:/index.html`（**クロール禁止**）。www.cam.shizuoka4.jp は robots.txt 404（制限なし）だが規約は SIPOS 側のものが適用されると解するのが妥当
- 取得構造（照会が通った場合用）
  - マスタ: `https://www.cam.shizuoka4.jp/data/master.js`（`var cam = {...}` に **167局**: typecamid/name/address/lat/lng/office/riverName、disflg 0=通常119・1=災害表示46・2=2）
  - 最新時刻: `/cam/<typecamid>.json` → `{"obsdate":"2026/08/29 14:42"}`（10分更新）
  - 画像: `/cam/<typecamid>/<YYYY>/<MM>/<DD>/<YYYYMMDDHHMM>00_00.jpg`（640x480。都度解決型。1台1リクエスト）
  - 障害告知: `/data/notice.json`
- 台数: 167（索引156+12）
- 既存: 静岡県 土木事務所の道路カメラ(shizuoka_doboku 45)とは別系統。国交省(浜松65・沼津55・静岡51)は kawabou 経由。重複なし

## 3. 埼玉県 川の防災情報（suibo-river.pref.saitama.lg.jp）／埼玉県河川監視カメラ viewer（saitamakasen.decloud.jp）

- **判定: 実装可（県公式 suibo-river 側の固定URLを使う。decloud 側は使わない）**
- 根拠
  - 注意事項PDF https://suibo-river.pref.saitama.lg.jp/Templates/top_chuuijikou.pdf（CMap復号で全文確認）  
    > ■免責事項 埼玉県は、利用者が本サービスを利用したことにより発生した、利用者の損害及び利用者が第三者に与えた損害について、その損害が直接的又は間接的かを問わず、一切の責任を負いません。…本サービスを利用するにあたっては、当免責事項を承諾したものとみなします。  
    > 本システムで提供する情報は、１０分毎に更新を行っています
    → 著作権・転載・リンクの制限記述なし
  - saitamakasen.decloud.jp は CTS社「PICTURE MAKER」の SaaS（ログイン画面 © CTS Co.,Ltd.）。robots は `Disallow:`（空）だが、画像は `saitamakasen-prd-*.s3.ap-northeast-1.amazonaws.com/<id>/snap/<YYYYMMDD_HHMMSS>.jpg` のタイムスタンプ名で、第三者SaaSの規約が未確認 → **参照しない**
- 取得構造（suibo-river 側）
  - 座標付き一覧: `https://suibo-river.pref.saitama.lg.jp/geojson/saitama_camera.geojson`（**264地点**、properties: code/name/kana/office/river/type(0=カメラのみ78,1=水位局113,3=危機管理型水位計73)/address）
  - 台帳: `/chitenconfig/CameraList.csv`（264行、UTF-8 BOM。列: 整備事務所コード,管轄事務所名,観測点番号,地点名,所在地,種別,カメラID(上流),画像名,使用フラグ,…,24時間表示外部サイトURL(decloud)）
  - 最新時刻: `/hyoujidata/cinfo_<scd>.csv`（事務所コード 100〜、13事務所）または `/hyoujidata/cinfo.csv`。列に `./hyoujidata/camera/<id>.jpg` と撮影時刻 `202608291444`
  - **画像: `https://suibo-river.pref.saitama.lg.jp/hyoujidata/camera/<観測点番号>.jpg`（固定URL、320x240、10分更新）** → feed.type=still_image でよい。`/hyoujidata/camera/normal/<id>.jpg` は平常時参考画像
  - 他県分: `geojson/saitama_ex_camera.geojson`（東京都42、metro.tokyo へのリンクのみ）
- 台数: 264（索引 233 = decloud 側 group_id 別）
- 既存: **kawabou 経由で「埼玉県」79件が cam.river.go.jp で採用済み** → 座標近傍で重複除去が必要。秩父県土23（titiburomenkamera）・さいたま市14（saitama_flood）・romenkamerakokai.saitama.jp 8（道路、未採用）は別系統。saitama_flood パーサとは無関係（あちらは市）

## 4. みち情報ネットふくい（www.hozen.pref.fukui.lg.jp/hozen/yuki/）

- **判定: 既存パーサあり（fukui_road、215台採用済み）。ただし規約文言の再確認を推奨**
- 根拠: トップHTML内の注意書き  
  > 当ホームページに掲載されている内容の無断転載を禁じます。
  → 2026-08-25 の採用時にこの文言が検討されたか記録がない。SPEC 10章に従い人に確認が必要（同種の「無断転載禁止」でロードネット滋賀・山口道路見えるナビは不採用にしている）
- 取得構造: `assets/jsons/cameras.json`（342件。organize で県・市町のみ抽出→215）、画像 `assets/images/camera/<id>.jpg` 固定URL。索引の 342 との差分は NEXCO・国交省・滋賀県分の除外
- 既存との関係: 完全重複（新規なし）

## 5. ひろしま道路ナビ（www.roadnavi.pref.hiroshima.lg.jp）

- **判定: 既存パーサあり（hiroshima_road、119台採用済み）。規約文言の再確認を推奨**
- 根拠: トップページ「免責事項」ポップアップ  
  > 1. 著作権について 当ホームページ（ひろしま道路ナビ）は、日本国の著作権法および国際条約による著作権保護の対象となっています。当ホームページの内容について、私的使用又は引用等著作権法上認められた行為を除き、広島県に無断で転載等を行うことはできません。
- 取得構造: `camera_list.php` → `snow_pic/<ID>.jpg` 固定URL（既存パーサどおり）。索引130件 vs 採用119（差分は座標未確定等）
- 既存との関係: 完全重複。広島県河川防災(kasen-bousai.pref.hiroshima.lg.jp 18件)は今回対象外だが同種の別システム

## 6. 和歌山県 河川／雨量防災情報（kasensabo01.pref.wakayama.lg.jp）

- **判定: 実装可**
- 根拠: 注意事項PDF https://kasensabo01.pref.wakayama.lg.jp/Templates/top_chuuijikou.pdf（CMap復号で全文確認）  
  > ■免責事項 和歌山県は、利用者が本サービスを利用したことにより発生した、利用者の損害及び利用者が第三者に与えた損害について、その損害が直接的又は間接的かを問わず、一切の責任を負いません。本サービスは一時的に運用を停止、中止、中断することがあります。  
  > 本システムで提供する情報は、１０分毎に更新を行っています
  → 著作権・転載・リンクの制限記述なし。robots.txt 404
- 取得構造（埼玉と同じベンダー(JWA)の「川の防災情報」テンプレート）
  - 座標: `/geojson/wakayama_camera.geojson`（**261地点**。type 0=カメラのみ156, 1=水位局99, 2=ダム6。properties: code/name/river）
  - 台帳: `/chitenconfig/CameraList.csv`（EUC-JP、258行。上流カメラ258＋下流カメラ86＝**画像344本**。列: 振興局コード,振興局名,観測点番号,地点名,所在地,種別,カメラID(上流),画像名,使用フラグ,カメラID(下流),…）
  - 最新時刻: `/hyoujidata/cinfo_<scd>.csv`（振興局 100〜800）
  - **画像: `https://kasensabo01.pref.wakayama.lg.jp/hyoujidata/camera/<カメラID>.jpg`（固定URL、320x240、10分更新）**
  - おまけ: `/geojson/wakayama_youtube.geojson` に県のYouTube河川カメラ48本（channel URL付き）
- 台数: 261地点／344画像（索引 95+29）
- 既存: 同ホストの still_image **30件**＋web_page 8件が curated で採用済み（feed URL は同じ hyoujidata/camera/C*.jpg 形式）→ パーサ化で残り約310本を追加可能。kasensabo02 は kasensabo01 へリダイレクトされる同一システム

## 7. 島根県 水防情報システム（www.suibou-shimane.jp）

- **判定: 条件付き（サイト自身は免責のみ。県HP共通の著作権方針の適用範囲を確認）**
- 根拠
  - システム内 https://www.suibou-shimane.jp/pc/map/top.html  
    > 免責事項 ・島根県は、本ページの利用によって発生する直接または間接の損失、損害について一切の責任を負いません。・本ページは、システムの都合上、利用を制限する場合があります。
    → 転載・リンクの制限なし。robots.txt 404
  - 県公式 https://www.pref.shimane.lg.jp/cl.html（島根県ホームページ全体の方針）  
    > 「私的使用のための複製」や「引用」などの著作権法上認められた場合を除き、無断で転用・引用することはできません。利用許諾については、各ホームページに記載されている所属へお問い合わせください。
    → これは pref.shimane.lg.jp の方針で、suibou-shimane.jp（別ドメイン・河川課運営）に直接は掲げられていない。既存 shimane_road（roadi.pref.shimane.jp 119件）を同条件で採用しているので整合を取るなら実装可。厳密には河川課(kasen@pref.shimane.lg.jp)へ一報が望ましい
  - 県案内 https://www.pref.shimane.lg.jp/bousai_info/bousai/bousai/suibo/system/index.html  
    > 本サービスで提供する画像情報は１０分毎に更新されます…メンテナンスのために予告なしに映像配信を停止する場合があります。
- 取得構造
  - 座標付き一覧: `https://www.suibou-shimane.jp/dyn/dps/json/mapData90.json`（`data[]`: id="camera.8193_90_<n>", name, lat, lng, type="10min"。**74局**）
  - 最新時刻（全台1リクエスト）: `/dyn/camera/camera.json` → `{"updateTime":"2026-08-29-14-40","list":{"8193_90_27":{"updateTime":"2026-08-29-14-40",...}}}`
  - 画像: `/dyn/camera/<YYYYMMDD>/<HHMM>/camera_l/<obsPoint>.jpg`（640x480。`camera_s` 等の小サイズもあると推定）→ **都度解決型（saitama_flood 型：一覧1リクエストで全台）**。camera.json の updateTime が古い局（8193_90_67 は 2026-04-01）は休止
  - 詳細: `/dyn/dps/json/cameraDetail.json`（水位連携）
- 台数: 74（索引59）
- 既存: 道路の shimane_road とは別系統。国交省(出雲54・浜田38)は kawabou。重複なし

## 8. 山口県 土木防災情報システム（y-bousai.pref.yamaguchi.lg.jp）

- **判定: 実装可**
- 根拠: 「このサイトの利用について」 https://y-bousai.pref.yamaguchi.lg.jp/citizen/mail/kms_internet_usage.html  
  > ■著作権 「山口県土木防災情報システム」に掲載されている個々の情報（文章、写真、イラスト、画像等）は著作権の対象となっています。ご利用にあたっては、著作権法の範囲内でご使用ください。  
  > ■リンク 「山口県土木防災情報システム」へのリンクは、原則として自由です。なお、リンク設定を行った場合は、「a18600@pref.yamaguchi.lg.jp」までお知らせください。
  → 転載禁止・直リンク禁止の表記なし（リンク自由・事後連絡の依頼あり）。robots.txt 404。※同県の「道路見えるナビ」(road.pref.yamaguchi.jp)は「無断転用・引用はご遠慮」で別扱い（既存11件は要再確認、research_followups 参照）
- 取得構造
  - 一覧（全台1リクエスト）: `https://y-bousai.pref.yamaguchi.lg.jp/citizen/camera/krc_camera_list.aspx`（**58局**。`<img class="Image" src="../../img/cameraImage/<YYYYMMDD>/<HHMM>/<12桁ID>_M.jpg">`、撮影日時テキスト付き。10分更新）
  - 個別: `/citizen/camera/krc_camera.aspx?stncd=<3桁>&obsdt=` → `_X.jpg`（1280x720）。`/img/normalImage/<ID>_M.jpg` は平常時画像
  - 画像: `/img/cameraImage/<YYYYMMDD>/<HHMM>/1335000000<stn>_{M|X}.jpg` → **都度解決型（yamaguchi_romen 型：一覧ページ1枚から全台解決）**
  - 座標: `/citizen/map/kco_map.aspx?menu=1&officecd=0&datakdcd=13` → 302 → `/static/citizen/pages/kco_map_13_0_<YYYYMMDDHHMM>.html` 内の `L.marker([34.162,132.180], {id:'marker_13_001_01'...krc_camera.aspx?stncd=001`（58局分、小数3桁≒100m精度）。住所は `/citizen/camera/krc_camera_station_info.aspx`（事務所/市町/住所/水系/河川/局名）
- 台数: 58（索引58）
- 既存: 山口県河川カメラは未採用。国交省山口(42+romen 9)とは別。重複なし

## 9. 名古屋市 道路・河川等監視情報システム（www.rdcamimage.city.nagoya.jp）

- **判定: 要照会（利用規約への「同意」ゲートあり）**
- 根拠: 初回アクセスで規約同意画面 https://www.rdcamimage.city.nagoya.jp/public_html/Default.asp が出る  
  > 道路・河川等監視情報システム（以下、「当サイト」という。）の利用にあたり、以下の記載事項に関し同意していただく必要があります。記載事項に同意して利用される方は、本ページ下部の「同意して利用する」をクリックし、当サイトを利用してください。  
  > （提供情報）当サイトで提供される情報は、名古屋市緑政土木局、国土交通省及び愛知県が道路・河川などの監視用に収集したカメラ画像情報です。（目的）…市民の方々へ提供するものです。提供する画像情報は、あくまで参考情報です。
  → 転載禁止の文言自体は無いが、同意を前提にした提供であり、アプリからの画像直参照は同意プロセスを迂回する形になる。市緑政土木局へ照会が必要。robots.txt 404
- 取得構造（照会が通った場合用）
  - 同意: `POST all_map.asp` (etsuran_start_click=true) でセッションCookie。**画像自体はCookieなしでも 200**
  - 一覧: `picture_malti_zenku.asp`（**71局**。`<img src="./cam_img_mobile/<3桁局番>0122<YYYYMMDDHHMMSS>001.jpg">`。観測点名・河川名・所在地(区・町名)テキストあり。座標は無し）
  - 画像: `cam_img_mobile/<局番3桁>01<2桁><YYYYMMDDHHMMSS><3桁>.jpg`（240x180。タイムスタンプ名＝都度解決型）
- 台数: 71（索引40）
- 既存: 愛知県32・国交省(名古屋国道103・庄内川33)は kawabou/prvs。名古屋市分は未採用

## 10. NTTル・パルク 駐車場カメラ（民間）

- **判定: 不可**
- 根拠
  - 企業サイト「サイトのご利用について」 https://www.ntt-leparc.co.jp/terms/  
    > 当ウェブサイトに掲載している内容（デザイン、図画、文書、音声、映像、Web構造、プログラム等）を、株式会社NTTル･パルクの許可なく無断複製、無断転載、その他二次利用行為は国内及び国外の著作権法により禁止します。
  - 配信元は `http://www.record-station.net/msknet/getmsk.php?id=G101M00013` 形式（索引ページに記載）だが、**record-station.net は DNS 解決不能（配信終了）**。索引483件中480件が既に「配信終了」ページ
  - 企業サイト内にライブカメラ公開ページは存在しない（parking/ 等にカメラ導線なし）
- 台数: 0（実質）
- 既存: なし

---

## 既存パーサとの重複まとめ

| システム | 既存 | 新規見込み |
|---|---|---|
| 福岡県河川 | 0（市24・北九州23は別） | 約210（座標要解決） |
| 静岡SIPOS | 0 | 167（要照会） |
| 埼玉県川の防災 | kawabou経由「埼玉県」79が重複候補 | 264−重複 ≒ 185 |
| 福井みち情報 | fukui_road 215 | 0 |
| ひろしま道路ナビ | hiroshima_road 119 | 0 |
| 和歌山県河川 | curated 30(+web 8) | 約310画像 |
| 島根水防 | 0（shimane_roadは道路） | 74 |
| 山口土木防災 | 0 | 58 |
| 名古屋市 | 0 | 71（要照会） |
| ルパルク | 0 | 0 |

## 実装の優先順位案（台数 × 容易さ）

1. **和歌山県河川（実装可・固定URL・geojson座標）** — 約310画像。既存30件と同じURL形式なので feed=still_image のまま。パーサ: CameraList.csv(EUC-JP)＋wakayama_camera.geojson を結合。既存30件は source を新パーサに付け替え
2. **埼玉県川の防災（実装可・固定URL・geojson座標）** — 264。同じJWAテンプレートなので和歌山と共通実装（`jwa_kasen` 系として base+prefix 差し替え）。kawabou 由来79件との近傍重複除去が必要
3. **山口県土木防災（実装可・都度解決型・座標あり）** — 58。yamaguchi_romen と同じ「一覧ページ1枚→全台」流儀で monitor に追加。schema enum / monitor/check.py / アプリ FeedType / camera_repository.imageUrlFor の4箇所配線が必要
4. **島根県水防（条件付き・都度解決型・JSON完備）** — 74。saitama_flood 型（camera.json 1リクエスト）。河川課へ一報の上で
5. **福岡県河川（条件付き・都度解決型・座標未特定）** — 約210。規約は問題ないが座標が無い。itv_table 35ページ巡回＋河川名/地点名ジオコーディング、または kawabou 側の福岡県カメラと照合してから
6. 静岡SIPOS（167）・名古屋市（71）は**照会待ち**。取得経路は上記に記録済みで許諾が得られれば即実装可
7. 福井・広島は新規なし。ただし「無断転載を禁じます」「無断で転載等を行うことはできません」の文言が確認されたため、既存採用分（215+119）の扱いをユーザー判断で再確認すること
8. ルパルクは対象外
