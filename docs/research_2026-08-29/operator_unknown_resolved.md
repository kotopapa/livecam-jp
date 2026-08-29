# livecamdb 運営者未特定・静止画 407件の掲載元ドメイン別解決（2026-08-29）

入力: `livecamdb_still_operator_unknown.json`（407件）。掲載元ドメインごとに掲載ページ・運営者ページ・規約ページを取得して運営者と利用条件を確認し、画像URLの応答を各ドメイン最大4件（1req/s）で再確認した。採用分は `operator_unknown_ok.yaml`（**348件**）、不採用は本書に理由を記録。cameras.json・curated_still.yaml は未変更。

判定凡例: **採用** = 転載禁止・直リンク禁止の記載なし（国交省は PDL1.0 準拠）／ **不採用** = 明示的禁止・要事前連絡・休止中・重複・応答なし。国交省以外は全件 `license=unknown` で人手レビュー前提。

既存 cameras.json との重複: 画像URL一致 4件（尾瀬岩鞍 ch4×2・ch1、北八ヶ岳 live1）を除外。座標200m以内の近接は別カメラ（別画像ID）だったため保持（下記「注意点」参照）。

## 集計（採用 348 / 不採用 59）

| 掲載元ドメイン | 件数 | 採用 | 不採用 | 運営者 | 判定根拠 |
|---|---|---|---|---|---|
| www.cbr.mlit.go.jp | 213 | 213 | 0 | 国交省中部地整（下記事務所別） | https://www.cbr.mlit.go.jp/policy.htm 「権利表記の記載がない限り『公共データ利用規約（第1.0版）』（PDL1.0）に準拠した利用条件の下で、利用することができます」「原則リンクフリー」 |
| www.live-cam.pref.niigata.jp | 30 | 28 | 2 | 国交省北陸地整 新潟国道17／長岡国道8／高田河川国道3／羽越河川国道1（サイト運営: 新潟県ICT推進協議会） | トップHTMLの `class` 属性6列目（設置者）で確定。https://www.live-cam.pref.niigata.jp/info/ は「© Niigata ICT Promote Council」表記のみで転載・リンク制限なし。既存66件(niigata_road)・kawabou/prvs と座標重複なし。cam8_1976/1916（市振の関・風波）はトップ一覧に無く設置者未確認→不採用 |
| www.qsr.mlit.go.jp | 12 | 12 | 0 | 北九州国道5／鹿児島国道2／宮崎河川国道2／佐伯河川国道1／佐賀国道2 | https://www.qsr.mlit.go.jp/pp/index.html 「公共データ利用規約（第1.0版）（PDL1.0）に準拠」「出典：国土交通省九州地方整備局ウェブサイト」。北九州国道は独自 sitepolicy.html でも PDL1.0 |
| www.machikuru.jp（画像 himawari.co.jp） | 9 | 9 | 0 | ひまわりネットワーク株式会社 | https://www.himawari.co.jp/corporate/sitepolicy/ 「本サイト内にある文章、イラスト、ロゴ、写真、動画、その他の全ての情報は、当社または第三者が著作権を有しております」「本サイトへのリンクは…営利・非営利を問わず自由」。直リンク禁止なし。既存2件と同条件（unknown） |
| (page_urlなし) 画像 www.seishiga.kkr.mlit.go.jp | 8 | 8 | 0 | 姫路河川国道5／滋賀国道3 | https://www.kkr.mlit.go.jp/link.html 「『公共データ利用規約（第1.0版）』に準拠」「原則リンクフリー」。page_url は事務所トップ（kkr.mlit.go.jp/himeji/, /shiga/）を補完 |
| yamagata-road.net | 8 | 0 | 8 | 山形県 村山総合支庁 建設部道路課 | **不採用**: camera.html 「記事、写真、画像などの無断使用を禁じます。」（福井・広島と同型。誘導型なら可） |
| nozawaski.com（画像 nozawaski.sakura.ne.jp） | 7 | 7 | 0 | 株式会社野沢温泉 | 禁止記載なし（プライバシーポリシーのみ） |
| www.city.usuki.oita.jp | 7 | 7 | 0 | 臼杵市 防災危機管理課 | /docs/2014031200023 「『私的使用による複製』や『引用』などの著作権法上認められる場合を除き」無断転載禁止・「担当課への事前相談」。**既存6件が同条件で採用済み**のため候補化。レビュー時に照会要否を判断 |
| ishiuchi.or.jp（画像 livecam.ishiuchi.jp） | 6 | 6 | 0 | 石打丸山スキー場（石打丸山索道事業協同組合） | 禁止記載なし。既存4件と同運営者 |
| webcam.heishin.jp | 6 | 0 | 6 | 兵神装備株式会社（滋賀事業所） | **不採用（保留）**: 「サイト利用規約（PDF）」 https://webcam.heishin.jp/img/terms.pdf が画像PDFで機械抽出不可。目視確認後に判断（scratchpad に保存済み）。画像は http→https 301 |
| www.tollroad-saga.jp | 4 | 0 | 4 | 佐賀県道路公社 | **不採用**: https://www.tollroad-saga.jp/about_site 「画像などの構成要素への直接リンクは禁止」「情報や写真などの無断複写・複製は知的所有権侵害」 |
| rusutsu.com（画像 kamori.co.jp） | 4 | 4 | 0 | ルスツリゾート（株式会社Niseko Alpine Developments／加森観光） | 禁止記載なし（宿泊約款・プライバシーのみ） |
| www.town.kagamino.lg.jp | 4 | 4 | 0 | 鏡野町 くらし安全課 | /site/userguide/5574.html 「適宜の方法により出所を明示することにより、引用・転載複製を行うことができます」「リンクは、原則自由」 |
| www.marinaakita.co.jp | 3 | 3 | 0 | マリーナ秋田（会社名はサイト内未記載） | 規約記載なし。運営会社名の確認をレビュー時に |
| www.listel-inawashiro.jp（画像 listel-hotels.com） | 3 | 2 | 1 | ホテルリステル猪苗代（長治観光株式会社） | 禁止記載なし。liveimage2 が2件で同一URL→1件に統合 |
| www.jma-net.go.jp（画像 wet.co.jp） | 3 | 0 | 3 | 岐阜地方気象台（配信は民間 wet.co.jp） | **不採用**: 索引で【休止中】。画像ホストが気象庁外で PDL 対象外 |
| www.marunuma.jp | 3 | 3 | 0 | 丸沼高原（日本製紙総合開発） | 禁止記載なし。冬季限定。既存はYouTube1件 |
| www.oze-iwakura.co.jp（画像 livecam.kannet.ne.jp） | 3 | 0 | 3 | 尾瀬岩鞍リゾート | **不採用**: 画像URLが既存 cameras.json と一致 |
| www.shima-net.jp | 3 | 3 | 0 | キララ★あがつま（画像提供: 株式会社測研・株式会社樋田塗装） | 規約記載なし。サイト運営主体が不明瞭（吾妻地域の地域サイト）→レビューで確認 |
| www.city.takasago.lg.jp | 3 | 3 | 0 | 高砂市 総務部危機管理室 | /soshikikarasagasu/citypromotionshitsu/2/6_2/1329.html 「高砂市の許可なく利用することはできません」。臼杵市と同型の自治体標準文言のため同扱いで候補化（**要照会候補**）。syouyou.jpg は初回0バイト→再取得で80KB |
| gala.co.jp | 3 | 3 | 0 | 株式会社ガーラ湯沢（JR東日本グループ） | 禁止記載なし。北エリア cam1 は「調整中」表示 |
| www.hotel-grandmer.com（画像 teiten.aomori-u.ac.jp） | 2 | 0 | 2 | ホテルグランメール山海荘／弘前大学・青森大学・青森電子計算センター | **不採用**: 「利用・転載などの際には、事前連絡が必要となります」「[出典：弘前大学・青森大学・青森電子計算センター]の明記が必要」→要照会 |
| www.hozen.pref.fukui.lg.jp（画像 seishiga.kkr / cbr） | 2 | 2 | 0 | 福井河川国道事務所1／岐阜国道事務所1 | 画像権利者は国交省（PDL1.0）。page_url は国交省側に差替え |
| toho-info.com | 2 | 0 | 2 | 東峰村 ふるさと推進課 | **不採用**: https://toho-info.com/sitepolicy/ 「コピー、配信、掲示、送信、削除、変更、翻案等を含む他の利用は固くお断り」 |
| www.kawaba.co.jp（画像 livecam.kannet.ne.jp） | 2 | 2 | 0 | 川場スキー場 | 禁止記載なし |
| fujikichi.jp | 2 | 0 | 2 | 常呂町岐阜観測所（個人） | **不採用**: 「このページへのリンクのみを認めます。画像ファイルへの直接リンクは禁止します。」 |
| www.nakashibetsu.jp | 2 | 0 | 2 | 中標津町 | **不採用**: 既存 cameras.json に同一カメラ（開陽台・市街地、別URL）収録済み |
| masyuko.or.jp | 2 | 2 | 0 | 一般社団法人摩周湖観光協会 | 既存1件と同運営者。画像は www. へ302（解決後URLで登録） |
| www.tsukuiko-gc.co.jp | 2 | 2 | 0 | 津久井湖ゴルフ倶楽部 | 禁止記載なし（/rules はプレー約款） |
| www.kitayatu.jp | 2 | 1 | 1 | 北八ヶ岳リゾート | live1 は既存重複。live2 は https へ302 |
| www.vill.otari.nagano.jp | 2 | 2 | 0 | 小谷村 総務課企画財政係 | 禁止記載なし |
| www.city.sado.niigata.jp（画像 live-cam.pref.niigata.jp） | 2 | 0 | 2 | 新潟県佐渡地域振興局 | **不採用**: 佐渡市ページ「老朽化のため、2025年11月末をもって撤去」。画像は静止応答のまま |
| www.matsunoyama.com | 2 | 2 | 0 | 松之山自治振興会 | 禁止記載なし |
| www.osaka-bousai.net | 2 | 0 | 2 | 大阪府 危機管理室 | **不採用（要照会）**: menseki.html 「複製頒布、出版、放送、上演等への二次利用…を行う場合は、事前に大阪府政策企画部危機管理室への問い合わせが必要」 |
| kouyachtclub.wixsite.com（画像 watson.jp） | 2 | 1 | 1 | 古宇ヨットクラブ | 規約なし。2件が同一URL→1件 |
| www.tcn-catv.co.jp | 2 | 0 | 2 | 東京ケーブルネットワーク株式会社 | **不採用**: /website_about/ 「全ての画像、文章のデータについて、無断転用・無断転載をお断り」＋「さくらカメラは公開期間外」 |
| www2.thr.mlit.go.jp | 1 | 1 | 0 | 東北地整 能代河川国道事務所 | https://www.thr.mlit.go.jp/policy.pdf（CIDフォントで機械抽出不可。他地整と同一書式のPDL1.0と推定、既存 thr 13件と同扱い） |
| www.thr.mlit.go.jp | 1 | 1 | 0 | 東北地整 三陸国道事務所 | 同上 |
| info-dam.hdb.hkd.mlit.go.jp | 1 | 1 | 0 | 北海道開発局（旭川開発建設部 十勝岳火山砂防） | /ky/ki/kouhou/ud49g7000000omnw.html PDL1.0準拠 |
| misawa-airport.co.jp | 1 | 1 | 0 | 三沢空港ターミナル株式会社 | 禁止記載なし |
| www.driveplaza.com | 1 | 0 | 1 | NEXCO東日本 | **不採用**: /site_info/usage.html 「他のサイトや印刷媒体に転載したり、商用目的として利用することはできません」 |
| www.makino-sake.co.jp | 1 | 0 | 1 | 牧野酒造 | **不採用**: 【調整中】 |
| warabidaira.com（画像 www5.wind.ne.jp） | 1 | 1 | 0 | わらび平森林公園キャンプ場 | 規約なし |
| parking.hokkaido-airports.co.jp | 1 | 0 | 1 | 北海道エアポート株式会社 | **不採用**: /ja/new-chitose/about/ 「複製、公衆送信などに使用することは禁止」＋トップページ以外への直接リンク非推奨 |
| mu-mu-tokoro.jp | 1 | 0 | 1 | ところ昆虫の家 | **不採用**: 「無断で使用、出版物への収録などは禁止いたします」「必ずトップページをリンク」 |
| www.maoi-net.jp | 1 | 0 | 1 | 長沼町 | **不採用**: chosakuken.html 「無断使用・複製・転載・販売・改変・印刷配布することを禁止」＋画像0バイト |
| www.sapporo-kokusai.jp | 1 | 0 | 1 | 札幌リゾート開発公社 | **不採用**: 画像0バイト（夏季停止と推定） |
| www.nhao.jp | 1 | 1 | 0 | 兵庫県立大学 西はりま天文台 | 規約なし。https へ302 |
| kankou385.jp | 1 | 1 | 0 | 宮古観光文化交流協会 | 禁止記載なし |
| www.jf-hiratsuka.org | 1 | 0 | 1 | 平塚市漁業協同組合 | **不採用**: 【休止中】 |
| www.odakyu-sc.com（画像 webcam.wni.co.jp） | 1 | 0 | 1 | 株式会社小田急SCディベロップメント | **不採用**: /sitepolicy/ 「複製・転用・転載・電磁的加工・送信・頒布・二次的使用…全ての行為」禁止・「原則としてトップページへリンク」 |
| www.marukoshi-futon.com | 1 | 0 | 1 | 丸越ふとん店 | **不採用**: 【休止中】 |
| www.ichifusa.jp | 1 | 0 | 1 | 不明 | **不採用**: 掲載ページが空で運営者を特定できない |
| www.sci.tohoku.ac.jp | 1 | 0 | 1 | 東北大学 理学研究科 | **不採用**: /policy/ 無断での複製・転用・転載禁止 |
| www.hakubaescal.com | 1 | 0 | 1 | 株式会社五竜 | **不採用**: /winter/policy/ 「コンテンツの無断複製、無断転載、その他二次利用行為は…禁止」 |
| www.alpico.co.jp | 1 | 1 | 0 | アルピコリゾート＆ライフ株式会社 | /shikinomori/gaiyo/menseki.php に転載・直リンク禁止なし |
| www.brnorikura.jp | 1 | 1 | 0 | BlueResort乗鞍 | 既存6件と同運営者 |
| www.taisyoike.co.jp | 1 | 1 | 0 | 上高地大正池ホテル | 禁止記載なし |
| blanche-ski.com（画像 office.nagawa.ne.jp） | 1 | 1 | 0 | ブランシュたかやまスキーリゾート | 禁止記載なし |
| www.city.nakano.nagano.jp | 1 | 0 | 1 | 中野市 | **不採用**: 掲載ページ404・市のライブカメラ一覧に十三崖の記載なし。/link_about.html は事前許可制 |
| ryuoo.com | 1 | 1 | 0 | 竜王スキーパーク | 禁止記載なし |
| tainairesort.jp（画像 9ronin.jp） | 1 | 1 | 0 | 胎内スキー場 | 禁止記載なし |
| www.new-greenpia.com | 1 | 1 | 0 | ニュー・グリーンピア津南 | 禁止記載なし |
| www.otochi.com | 1 | 1 | 0 | 山源木工 | 禁止記載なし |
| www.fsw.tv（画像 webcam.wni.co.jp） | 1 | 0 | 1 | 富士スピードウェイ株式会社 | **不採用**: /other/policy.html 事前許可なき転載禁止・「リンクをご希望の方は…ご連絡の上」 |
| umegashima.blogspot.com | 1 | 0 | 1 | 梅ヶ島温泉 | **不採用**: 【休止中】 |
| www.takahasiya.com（画像 webcam.wni.co.jp） | 1 | 1 | 0 | 高橋家（高尾山麓） | 規約なし（EUC-JPページ）。wni 配信は既存18件あり |
| www.city.murayama.lg.jp | 1 | 0 | 1 | 村山市 政策推進課 | **不採用**: 事前許可制＋「令和8年9月21日より約2ヶ月間ライブカメラサービスを停止」 |
| www3.city.sakata.lg.jp | 1 | 1 | 0 | 酒田市 | 市サイト共通ポリシー未確認。画像は www3.city.sakata.lg.jp へ301 |
| www.minamialps-net.jp | 1 | 1 | 0 | 山梨日日新聞社（芦安山岳館） | 禁止記載なし。新聞社運営のためレビュー要注意 |
| www.sly-rc.com | 1 | 1 | 0 | スポーツランドやまなし | 規約なし |

### 中部地整 事務所別（213件、URLパス／掲載ページ表記で確定）

| パス | 事務所 | 件数 | 掲載ページ |
|---|---|---|---|
| /hokusei/cctv/ | 北勢国道事務所（名阪国道・国道1号関BP） | 74 | hokusei/traffic/meihan_livecam/{a..e}.html |
| /takayama/cctv/cctv_img/ | 高山国道事務所 | 60 | takayama/cctv/cctv_all.html（「copyright © 国土交通省 中部地方整備局 高山国道事務所」） |
| /iikoku/CCTV/ | 飯田国道事務所 | 33 | iikoku/info/live/live_area{19,153}.html |
| /numazu/kanogawa/cctv/snapshot/ | 沼津河川国道事務所 | 33 | 索引の掲載元がサイトトップだったため page_url は /numazu/ に補完 |
| /gifu/cctv/cameraimage/ | 岐阜国道事務所 | 13(+1) | gifu/（+福井県みち情報ネット経由1） |

## 画像URL応答確認（各ドメイン最大4件、1req/s）

- 200 かつ本体あり: 上記採用ドメインすべて（cbr/qsr/kkr/thr/hkd/niigata/himawari/yamagata-road/tollroad/kamori/kagamino/usuki ほか）
- リダイレクト後 200: heishin(http→https), masyuko(→www), nhao(→https), kitayatu(→https), sakata.ed.jp(→www3.city.sakata.lg.jp), ichifusa(→https), sci.tohoku(→https)
- 200 だが 0 バイト: maoi-net, sapporo-kokusai（不採用）。takasago syouyou.jpg は再取得で 80KB
- 【休止中】【調整中】表記のものは画像が 200 でも古い可能性が高いため不採用にした

## 注意点

1. **近接重複（同一地点に既存の別画像ID）**: 高山国道「国道41号地蔵野洞門北」(30410020) は既存「飛騨谷橋南」(30410030) と座標が同一（地図中心由来）。飯田国道の治部坂峠南・市之瀬・陣場洞門は既存に飯田ケーブルテレビ再配信(bindweed.sakura.ne.jp)の同名カメラあり → 国交省公式の方を残し ICTV 分の整理を検討。佐賀国道「俵坂佐賀側」(S02350) は既存「不動山」(S02382) と同座標。
2. **にいがたLIVEカメラ経由の国交省28件**: 画像ホストは県ICT推進協議会。既存 niigata_road パーサは「国交省分は kawabou/prvs 収録済み」として除外していたが、座標200m以内の既存はなく未収録だった。prvs(mlit_roadinfo)側に同一カメラがある可能性があるので、レビュー時に名称照合を推奨。
3. **臼杵市(7)・高砂市(3)** は自治体標準の「無断転載禁止・事前相談」文言。臼杵市は既存6件の前例に合わせて候補化したが、厳密には照会対象。同型の福井県・広島県は誘導型に切替済みなので、方針を揃えるなら両市も誘導型にする。
4. **東北地整 policy.pdf** は CID フォントのため本文を機械抽出できなかった。他地整と同じ「リンク・著作権・プライバシーポリシー等」の書式で、既存 thr 13件も採用済み。目視で一度確認しておくとよい。
5. **heishin(6件)** は規約PDFが未読のため保留。`scratchpad/heishin_terms.pdf` を目視して禁止文言がなければ採用可（画像は https で応答）。
6. 座標は入力のまま（marker 249件 / embed_center 158件）。embed_center は地図中心で数十〜数百m ずれることがある（note に「地図中心(概略)」と明記）。
7. 画像が http のもの（himawari, wind.ne.jp, 一部 cbr 以外）は ATS 例外の対象。masyuko/nhao/kitayatu/sakata はリダイレクト解決後の https URL で登録した。
