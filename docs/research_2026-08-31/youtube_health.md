# YouTubeライブカメラ 一斉死活確認（2026-08-31）

## 実施内容

台帳 `data/cameras.json` の承認済みカメラのうち、feed.type が `youtube_video` / `youtube_channel`、
および `web_page` で URL が youtube.com のもの **2,686台** を対象に、
`https://www.youtube.com/watch?v=<id>` を1req/s以下・ブラウザ相当UAで取得し `"isLiveNow":true` で判定した。
非ライブのものは動画のチャンネルの `/streams` を取得し、ytInitialData の lockupViewModel +
`THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE` から現行ライブを列挙して追従先を探した（チャンネル436件）。
削除・非公開は oEmbed（404=削除 / 403=非公開）で裏取りした。

| 区分 | 件数 |
|---|---|
| (a) 正常（配信中） | 2154 |
| (b) ID更新（配信枠が変わったので追従） | 201 |
| (c) 退役（rejectedへ） | 240 |
| (d) 要確認（今回は台帳変更なし） | 91 |
| 合計 | 2686 |

実行後の承認済み件数: **21,232件**（変更前 21,472件）。`site/build.py` 再生成済み。

---

## (a) 正常

2,154台が現在ライブ中。内訳は watch ページで isLiveNow=true が 2060台、youtube_channel型でチャンネルに現行ライブありが 53台、プレイリスト型（東京都島嶼）で 10台、watch ページでは非ライブ判定だがチャンネル /streams ではライブ表示（判定ゆらぎ・夜間の一時停止など）が 31台。いずれも台帳は変更していない。

---

## (b) ID更新（旧→新）

`data/cameras.json` の feed.url / fallback.url / source.page_url を新IDへ更新し、
`crawler/curated_youtube.yaml` `crawler/curated_world.yaml` `crawler/curated_still.yaml` の video_id / feed_url も同じIDに書き換えた（再クロールで戻らないようにするため）。
yaml側には `# 2026-08-31 配信枠更新: 旧 → 新` のコメントを直前に入れてある。

| ID | 名称 | 旧video | 新video | 新タイトル |
|---|---|---|---|---|
| `curated-akihabara-aisan` | 秋葉原 中央通り交差点 | `aEgbnkL8f1I` | `nr604DJB0sI` | 秋葉原ライブカメラ（愛三電機ビルより配信中） |
| `curated-akihabara-aisan-chuo-dori` | 秋葉原（愛三電機ビル・中央通り交差点） | `tz3LqWOMMOM` | `nr604DJB0sI` | 秋葉原ライブカメラ（愛三電機ビルより配信中） |
| `curated-dotonbori-mbs` | 道頓堀 グリコ看板前 | `0P2dOCRPSRM` | `czJhGgFsp38` | 【LIVE】大阪・道頓堀ライブカメラ　グリコ看板前の様子は？ Osaka Dotonbori #道頓堀 #ライブカメラ |
| `curated-ginza-sukiyabashi` | 銀座 数寄屋橋交差点 | `nP_xdzmt0AE` | `1Xm5bjdI5hU` | 【LIVE】銀座ライブカメラ　数寄屋橋スクランブル交差点 Sukiyabashi crossing in Ginza,  |
| `curated-golf-wakkanai-cc` | 稚内カントリークラブ コース | `Vxi-QVgKG1o` | `MLZCnoy7Dnw` | 【ゴルフ場LIVE】稚内カントリークラブの"今"をライブでお届け #稚内ライブ #絶景配信 #ゴルフ場 #北海道 #稚内 |
| `curated-hibaruyama-2` | しまばら火張山花公園 第2（国道251号・島原IC方面） | `Y5AX5hdA8no` | `Hy3-jLtrqOU` | 長崎県島原市「しまばら火張山花公園」からライブ映像 |
| `curated-iat-morioka` | 盛岡情報カメラ | `PxHYFalgxAg` | `WIKiWNwzkhU` | 【ライブ配信】盛岡情報カメラ |
| `curated-inawashiro` | 猪苗代湖（スキー場から） | `hmGMijkatDY` | `grGi5dgztyw` | 【ライブ配信】絶景・猪苗代スキー場  思い出2.0®幸せの鐘カメラ |
| `curated-ishigaki-730` | 石垣島 730交差点（国道390号） | `5CE32IQIgG0` | `_jcl6NuIiuw` | 石垣島７３０交差点ＬＩＶＥカメラ |
| `curated-kaiyohaku-tomidai` | 海洋博公園 熱帯ドリームセンター遠見台（エメラルドビーチ） | `lfN88SfMCh4` | `knXX-XmMKXg` | 海洋博公園 熱帯ドリームセンター 遠見台からの眺め |
| `curated-kintaka-naha-4screen` | 那覇新港・泊大橋・クルーズターミナル（4画面） | `HMK1dPnJZXI` | `MsFAwwIGohU` | ★🛑沖縄ライブカメラ同時モニター【LIVE】那覇新港 那覇空港北側 那覇市 ライブ カメラ NAHA OKINAWA p |
| `curated-kintaka-naha-cruise-terminal` | 那覇クルーズターミナル・泊港入口 | `Mc3OxQnVSrI` | `k7H1WGBspJ0` | 🟪🚢⚓️【LIVE】 沖縄ライブカメラ 那覇クルーズターミナル  沖縄県 那覇市   泊港入口  波の上 若狭 NAHA |
| `curated-kintaka-tomari-ohashi` | 泊大橋〜曙（国道58号 渋滞状況） | `lYoxW4wkOZQ` | `j1TZPBCL0j0` | 💙【LIVE】沖縄ライブカメラ 那覇市 泊大橋～曙  渋滞状況  沖縄県 NAHA OKINAWA Tomari Bri |
| `curated-kyoto-karasuma` | 京都 烏丸通（京都新聞社前） | `ixZ4rgr6y2E` | `Rd4XwLJRmVQ` | 【京都ライブカメラ】京都市中心部・烏丸通の様子（京都市中京区）Live view of Karasuma Street  |
| `curated-lcdb-00cd5a29` | 三ヶ日みかん神明川支流河川 | `-cW1KoSj6kM` | `96palHpngE4` | 2026.8.31、環境ライブ、神明川支流河川カメラ、live of micro river from japan, m |
| `curated-lcdb-02af06b7` | 御茶ノ水 | `0-9klkOuzDM` | `krbiU6l_WLs` | 東京都御茶ノ水ライブカメラ Tokyo Ochanomizu Live camera. World cam. |
| `curated-lcdb-049d9d8d` | 山口鉄道小田急小田原線 | `K8ztx0qFQDU` | `k7nvw74-Z5w` | 小田急小田原線ライブカメラ（小田急小田原線小田原～足柄間） |
| `curated-lcdb-09d5b15b` | 養老鉄道西大垣駅 | `5ep5jkBfcS8` | `kTs76E27ubM` | ※仮復旧【LIVE】岐阜県大垣市 - 西大垣駅 養老鉄道ライブ Gifu Ogaki LIVE camera のライブ配 |
| `curated-lcdb-0b4ca906` | 室蘭市広域センタービル庁舎窓口呼び出し状況 | `RCIVK-QfOfg` | `r0N5dMLwDas` | 室蘭市広域センタービル庁舎窓口呼び出し状況 |
| `curated-lcdb-124078be` | 日暮里駅 | `BZQE7Ztz5b4` | `YGosIeNUAY0` | 【LIVE】東京日暮里 鉄道ライブカメラ 2026-08-31 15:00- Nippori,Tokyo,Japan r |
| `curated-lcdb-12f35e20` | 上福岡駅池袋方面ホーム | `RllZxOzq2gk` | `I_uvMp-WX-0` | 【ふじみ野市 上福岡駅】 ライブカメラ｜東武東上線 池袋方面 （2026/8/31 19:14-） |
| `curated-lcdb-13659194` | 上福岡駅東口 | `kusZaJkUU5M` | `sdCM-lxg86c` | 【ふじみ野市 上福岡駅】 東口ライブカメラ｜東武東上線 川越方面（2026/8/31 19:11-) |
| `curated-lcdb-149d0ae4` | 805たんば福知山 | `yYY77lT8F8c` | `odEelidkKAw` | 兵庫県丹波市/福知山市ライブカメラ |
| `curated-lcdb-14d7ede1` | おぐら茶屋 | `J2kgoEIknM0` | `Tf4Fb_SWvKk` | LIVE CAMERA Kyoto【京都おすすめ】常寂光寺山門 と おぐら茶屋 |
| `curated-lcdb-16fe4ff5` | iinami伊倉ヶ浜ビーチ | `WjgjKEO_YOY` | `fbwFj3hGvVw` | 川南町伊倉ヶ浜ライブカメラ【宮崎県 波情報ライブカメラ ii-nami.com】 |
| `curated-lcdb-1c21513d` | 猪苗代スキー場スカイエリア | `ySUSc6zIMU0` | `3hADiYbSZDs` | 【ライブ配信】絶景・猪苗代スキー場（東北・福島）スカイエリア｜雲海と猪苗代湖 |
| `curated-lcdb-1c6d3ac0` | 富山短期大学立山連峰 | `WIPtEZBXepg` | `RtX4wMybrek` | 【4K】富山短期大学 立山連峰 ライブカメラ 2026/08/31 PM |
| `curated-lcdb-1f19f73b` | 亀戸スポーツセンタープール混雑状況 | `ssCzusYLEB8` | `9yIjDEVOQuI` | 8/31(月）　亀戸スポーツセンタープール混雑状況 |
| `curated-lcdb-1f71a470` | infinitymirageプロジェクト | `FjfoAKxhEcQ` | `iyUpD6I2EyA` | infinity~mirage 2026/08/31 19:00JST- |
| `curated-lcdb-2030469f` | 阪急電鉄今津線小林駅 | `yLt6mOT9JUo` | `V2gpDMYODm8` | 【鉄道ライブカメラ】阪急電車  阪急今津線 小林駅 Japan Train  Hankyu Imazu Line Oba |
| `curated-lcdb-228bbce6` | 【休止中】エクスアリーナ松戸店ヤギ | `Pz4XSbxM6cw` | `-19SL15ZBJc` | エクス動物園　リャマ日記 |
| `curated-lcdb-23a0035a` | 諏訪湖富士山 | `J9lDHGKyyz0` | `FZIXqsmcHe0` | 諏訪湖富士山ライブカメラ |
| `curated-lcdb-25da3b3a` | ケリーズグリーン | `uvnMK_mqebo` | `mEqul-aFk50` | Japanese Hair Salon ASMR Live ｜ Haircut & Transformation |
| `curated-lcdb-28c8e5a4` | DELICE SWEETS LAB自動販売機 | `jjwVDs8YPXc` | `aePBOhcyJ1M` | DELICE SWEETS LAB のライブ配信 |
| `curated-lcdb-326b6f96` | 蜃気楼富山方面 | `eUndIceBGdc` | `D2piwT_s4zg` | 【富山方面】蜃気楼ライブカメラ 2026/08/31 17:00JST- |
| `curated-lcdb-33d2c8b1` | 龍江川路駅方面 | `ebGkjBbqq0Y` | `rpNDZZCmm84` | 伊那谷ライブカメラ（南信州/飯田市） |
| `curated-lcdb-37823ccf` | 蜃気楼黒部方面 | `stg2fhzzYJg` | `WB1hDURJLhM` | 【黒部方面】蜃気楼ライブカメラ 2026/08/31 18:00JST- |
| `curated-lcdb-3dde73ab` | 八ヶ岳西麓 | `EDVNfGsNxoc` | `NIXM5xQQLCw` | 長野県茅野市　八ヶ岳西麓の空模様　「Yatsugatake Information Wall」 のライブ配信 |
| `curated-lcdb-3f2381cb` | アクアパーク川越チンアナゴ水槽 | `RRjgnrXuwMc` | `z3U_pxHe0Xc` | チンアナゴ水槽 |
| `curated-lcdb-427abb7a` | 磯部紙器富士山 | `luSoULjrp6I` | `cG31UYToI6k` | 富士山頂ライブ　頂きの始まりからのライブ配信 |
| `curated-lcdb-43c3d970` | 国道199号若戸大橋 | `eln7R58Fnfo` | `9kD7eUG7fcU` | 🇯🇵 LIVE｜若戸大橋（Wakato / Red Bridge）北九州｜Japan Live Camera｜2026/ |
| `curated-lcdb-4442cd04` | 裾野富士山 | `CReKLBGtDPo` | `34LGR-7zhdA` | 【LIVE】富士山ライブ｜裾野市から望む絶景 Mt.Fuji Live Cam Japan |
| `curated-lcdb-4e2fb78c` | あまぎスカイアドベンチャー | `saoQ31-kYeE` | `8Zz2h5LjsGU` | あまぎスカイアドベンチャー　公式ライブ配信 |
| `curated-lcdb-4ea69d4a` | 飯梨地区田んぼ | `7lsDvX-p-3s` | `0FJYU3swxWk` | 【島根の田んぼ】田んぼの様子をライブ配信中！２４時間いつでも確認できます！｜自然 田舎 緑 癒し 島根県 八なお米穀店（ |
| `curated-lcdb-50b6044d` | infinitymirageプロジェクト高所 | `mRU0EFTVFUY` | `i3DZP26nyhs` | infinity~mirage 2026/08/31 20:00JST- |
| `curated-lcdb-50c0f107` | 磯部紙器 富士山（静岡側からの眺望） | `ZzjVtXdSZxs` | `C_3a7XITqx4` | 🔴 Live: Mount Fuji Japan 24/7 ｜ Stunning View from Shizuoka  |
| `curated-lcdb-51f05525` | 秩父が浦船溜まり | `tlva1CCACYU` | `Hy3-jLtrqOU` | 長崎県島原市「しまばら火張山花公園」からライブ映像 |
| `curated-lcdb-54dac5d1` | 大垣市街地上空天気 | `RdO7yYgqbgE` | `gTyZN93K4Yg` | 【LIVE】岐阜県大垣市ライブカメラ #岐阜 #大垣 #ライブカメラ Gifu Ogaki LIVE camera |
| `curated-lcdb-574150f8` | ヴェルサイユリゾートファーム | `G38kbMne_IQ` | `H1DpFnz2Qwk` | 大放牧地カメラ配信　2026年8月31日 ｜ ヴェルサイユリゾートファーム |
| `curated-lcdb-5944a506` | Nature奥多摩駅運行状況 | `khKbTz4qZ08` | `jSQuZGG-7Mo` | 【LIVE】JR青梅線奥多摩駅運行ライブカメラ 東京最果　tokyo okutama-station Live Came |
| `curated-lcdb-5ee1003a` | ソラシドレコード多摩丘陵上空 | `nCcwcZ_KXRc` | `iPet4pnjotE` | On Air 2026/08/31 14:50 東京 多摩丘陵の空 ライブカメラ #いつでもイマソラ / Tokyo T |
| `curated-lcdb-6267f910` | 北上市街地 | `POzezS6GT1w` | `nfrcp6taKQI` | oak80jpn live 2026.08.31 04:35　お天気カメラ　岩手県北上市　ライブ配信 |
| `curated-lcdb-64a207b6` | 北海道録画センター旭川上空天気 | `r7W90hKKpKA` | `0u8El2HX1hI` | お天気カメラ 北海道旭川市  Live camera / Asahikawa, Hokkaido, Japan |
| `curated-lcdb-71343c83` | ルビーの里エクステリアガーデン | `N5pdmVfc91w` | `vuskz_gC9DE` | 【長野県駒ヶ根市】ルビーの里 エクステリアガーデン お天気ライブカメラ Live camera  from "Ruby  |
| `curated-lcdb-71cbd694` | OLAGATOCHI日本海オロロンライン | `wE4JRWOY3YI` | `aFfWHJnvAwY` | 【厚田の景観】2026年8月29日 03:08〜03:17 |
| `curated-lcdb-731f155b` | 蜃気楼射水方面 | `nNvWVYVR9RM` | `l4ghIbsyNOg` | 【射水方面】蜃気楼ライブカメラ 2026/08/31 16:00JST- |
| `curated-lcdb-76314914` | 湯布院由布岳 | `wXNx8Fw-_6s` | `BWF81ot-P5o` | 【4K Livecamera】ゆふいん、由布岳と夜景/Yufuin Onsen-Japan |
| `curated-lcdb-7995f28f` | 青苔荘 | `ArSIDRJB8Ms` | `oUUbF6lrYFQ` | 青苔荘ライブ |
| `curated-lcdb-7a428023` | iinami恋ヶ浦ビーチ | `GTAjAqCsEVs` | `cieYFJThjw0` | 串間市恋ヶ浦ライブカメラ【宮崎県 波情報ライブカメラ ii-nami.com】 |
| `curated-lcdb-7b1764bf` | ゆうだい温泉 | `Y6fd3ZyDNCc` | `pwuIDIwsARQ` | 入館状況ライブカメラで配信中 |
| `curated-lcdb-8068232e` | 十和田湖高原ゴルフクラブ | `ux9_82_PfjA` | `S-oQyX8a3_M` | 十和田湖高原ゴルフクラブ のライブ配信 |
| `curated-lcdb-8326e2ed` | 富士山静岡県側 | `go9G6P_muAw` | `iQqkMCs30HY` | 富士山ライブカメラ｜富士の麓に抱かれて ― 自然からの授かりと暮らす街｜静岡県富士市からのライブ中継 |
| `curated-lcdb-8479cdb3` | KINTAKA那覇新港上空天気 | `r8w1fMuHw6g` | `MktRaErggt0` | 💚【LIVE】沖縄ライブ カメラ 那覇市  那覇新港  那覇空港 滑走路北側 OKINAWA NAHA  PORT LI |
| `curated-lcdb-84fa524b` | iinami一ツ葉ビーチ | `DZfjOzoQ0-M` | `cz7omIVz8_M` | 宮崎市青島ライブカメラ【宮崎県 波情報ライブカメラ ii-nami.com】 |
| `curated-lcdb-85b1d8ae` | 小清水町お天気 | `BiRR9oveuY4` | `yuretMvFTkE` | 北海道小清水町のいまの天気 |
| `curated-lcdb-8848fcc0` | 高浜市役所1階窓口混雑状況 | `kya1dtYyRP8` | `u9nxKbp1acs` | 高浜市役所１階窓口混雑状況　ライブ配信 |
| `curated-lcdb-890cd24b` | 東条川加東 | `foqM3HkrVPs` | `sF0J0azgIOo` | 加東市東条川の眺望 |
| `curated-lcdb-92ff48cb` | KINTAKA那覇新港 | `FF7bifdSGB8` | `j1TZPBCL0j0` | 💙【LIVE】沖縄ライブカメラ 那覇市 泊大橋～曙  渋滞状況  沖縄県 NAHA OKINAWA Tomari Bri |
| `curated-lcdb-9a277756` | 阪急神戸線武庫之荘駅 | `rWjTmo1ntrU` | `8yUX4L7TyC4` | 【2026/8/31 (月) 16:30～翌4:25】鉄道ライブカメラ 阪急神戸線 武庫之荘駅 Hankyu Kobe  |
| `curated-lcdb-9b89a1c5` | 小浜島 | `dFrH4uIY0c8` | `KrwVmC7TXT4` | 8月31日(月)｜【LIVE】石垣島ライブカメラ（名蔵湾・フサキビーチ） ／ ISHIGAKIJIMA OKINAWA  |
| `curated-lcdb-a3b504c7` | KINTAKA那覇新港入口 | `WF9NsaLIBwU` | `MsFAwwIGohU` | ★🛑沖縄ライブカメラ同時モニター【LIVE】那覇新港 那覇空港北側 那覇市 ライブ カメラ NAHA OKINAWA p |
| `curated-lcdb-adf1d9da` | 西東京富士山方面 | `gN5KYUknCMI` | `g0fX2BZ94MQ` | 【今見える？】東京から見た富士山 ライブカメラ｜西東京・田無タワー方面から生中継 [Can You See It Now |
| `curated-lcdb-b489a6b9` | 大和西大寺駅 | `lj9if3eBQxY` | `W8PcGpc5-DA` | 大和西大寺駅ライブ（８年８月３１日２） |
| `curated-lcdb-b568242f` | iinami江口浜 | `_7wfiCjDzDY` | `Kbrx6vpTgFs` | 宮崎市木崎浜ライブカメラ【宮崎県 波情報ライブカメラ ii-nami.com】 |
| `curated-lcdb-b5c8a3f6` | 美山かやぶきの里 | `CMNPhsZEB08` | `eagAtywDxFI` | 2026/08/30 【LIVE CAMERA】#南丹市 #美山かやぶきの里  #ライブカメラ #livecamera  |
| `curated-lcdb-bee277ff` | 武蔵小杉駅ライブカメラ(神奈川県川崎市中原区) YouTub | `vdmsNidogzA` | `J4kCwSkAjmg` | 【LIVE】JR武蔵小杉駅北口（撮影：株式会社メタテクノ） |
| `curated-lcdb-c2452d32` | 北野病院採血待合案内 | `tzVe4m3cLSw` | `eI-8amqnDNY` | 北野病院　採血コーナー　待ち時間ライブ配信です。 |
| `curated-lcdb-c31f6308` | 脇坂工務店銭函海水浴場 | `FPng_SCs7LE` | `Spx0g69PmJo` | 🔴北海道小樽市 銭函海岸  ライブカメラ【脇坂工務店】/試験運用中 |
| `curated-lcdb-cf2ddec2` | さいたま市鉄道北浦和駅与野駅間 | `RJxnX65VDVo` | `_AOUzrOPRyg` | 【フリー動画】さいたま市鉄道ライブカメラ（JR上野東京ライン・京浜東北線・湘南新宿ライン・東北本線の運行情報）・Sait |
| `curated-lcdb-cfbff66e` | 金華山山頂 | `_T7uS8rAGtc` | `3jd8V_o17N0` | 自分の配信 |
| `curated-lcdb-d1840d96` | 東京湾木更津 | `zNwVCsLlPnk` | `4NuswmZU1Ns` | 2026/08/31 19:59 LIVE: Tokyo Bay Zen View - Kisarazu, Japan  |
| `curated-lcdb-deacebd6` | 阪急電鉄西宮車庫鉄道基地 | `pCSaRANSKpo` | `ujwFaBEcADw` | 2026/08/31 15:02 阪急電車 神戸線 西宮車庫 西宮北口 ライブカメラ 5 名神高速 |
| `curated-lcdb-df643fbd` | JR西日本大阪環状線福島駅方面 | `YvQk_N2jpSM` | `BzD751n3tiM` | 【LIVE】福島駅方面 大阪環状線・梅田貨物線ライブカメラ 2026/08/31 17:00～ Osaka, JAPAN |
| `curated-lcdb-e123abab` | 阪急電鉄西宮北口駅 | `wia5-TlFnfs` | `em_obLnZZe8` | 2026/08/31 15:00 西宮北口 ライブカメラ1 東向き お天気 風景 夜景 阪急電車 神戸線 西宮車庫 名神 |
| `curated-lcdb-e19a2658` | 五稜郭駅鉄道 | `ICvEjVyW3JE` | `eGc9d089oOI` | 2026.8,31【ライブ配信】函館本線・いさりび鉄道 |
| `curated-lcdb-e74d5340` | EMS増田町上空天気 | `lBUOoTWF34g` | `HA4LVFLboIA` | 横手市増田町の窓景 |
| `curated-lcdb-e91f884b` | 福岡空港国際線 | `JlKyqqcAKjA` | `rw-ggGDLWpo` | 【4K】福岡空港国際線ライブ live streaming from fukuoka japan airport |
| `curated-lcdb-e960de1a` | 赤羽駅周辺鉄道 | `_ggivg9LVU0` | `A0o4t8BCo_U` | 🚅[LIVE]鉄道ライブカメラ(東京 赤羽駅周辺) Tokyo Japan Train Live Camera |
| `curated-lcdb-ee0e9e1c` | 奥出雲鯛ノ巣山 | `radglujt_LE` | `lHW5iyEhDQk` | ☆鯛ノ巣山NOW☆　島根・奥出雲・阿井・鯛ノ巣山の四季ライブカメラ ⛰️🌾今日はどげな？　＃仁多米＃島根県＃奥出雲＃鯛ノ |
| `curated-lcdb-f51a1da6` | JR西日本大阪環状線 | `WMJvxr8t-1s` | `RK-Wi3-YkQQ` | 【LIVE】大阪環状線・梅田貨物線ライブカメラ 2026/08/31 17:00～ Osaka, JAPAN ｜ Tra |
| `curated-link-healing-lake-furen` | 風蓮湖 野鳥ライブカメラ（レイクサンセット） | `ml_6E371x_A` | `HXakj5mD26A` | 【🔴ライブカメラ】野鳥の宝庫『風蓮湖』　Hokkaido -Lake Furen- A Treasure Trove o |
| `curated-link-lcdb-01ae8a8b` | 富士山山中湖 | `yHXdTlBa1Gw` | `a_urNbES_Wc` | 【LIVE】富士山中湖 星空ライブカメラ |
| `curated-link-lcdb-03088c20` | 国道3号箱崎 | `odVWcR9CeZw` | `ha4U8rH9wFk` | 福岡県福岡市東区箱崎ライブカメラ |
| `curated-link-lcdb-22015bca` | JR苗穂駅 | `Oxk3p2CrWps` | `eBR__DrbMxo` | 苗穂JRライブ配信＜本線向きカメラ＞ |
| `curated-link-lcdb-3363c774` | 道の駅風穴の里 | `s8Lv2Pz8iWc` | `NX4Kod3I-iM` | 道の駅風穴の里 のライブ配信 |
| `curated-link-lcdb-38cef1c4` | 竹原市上空天気 | `qA_iGCA0gE4` | `F6Nq1aG6Imo` | 【ライブ配信】　ぼ～っと空を見上げたい時にどうぞ　　広島県  竹原市　 JAPAN 　LIVE Cam |
| `curated-link-lcdb-6414b2ef` | 叡山電車 | `64SwqUBkz2I` | `_eKatlNuNcg` | 【LIVE】叡山電車 Kyoto Local Railway【ライブカメラ】 |
| `curated-link-lcdb-64c0acd4` | 安曇野穂高山麓 | `rFKFmcZm8I0` | `wmdvPgcgM-M` | 安曇野穂高山麓ライブカメラ |
| `curated-link-lcdb-75938554` | 一映マリーナ | `399lRHS2qSs` | `NEMzh_WCeFE` | 一映マリーナ のライブ配信 |
| `curated-link-lcdb-9a68738d` | 熱海天空のホテル夢寿庵 | `iv9cLr_Q1p0` | `MTf4GaekUXU` | 熱海ライブカメラ　天空のホテル夢寿庵 |
| `curated-link-lcdb-af2e8b4b` | 猪苗代スキー場幸せの鐘 | `RS7n_Gu7eDk` | `grGi5dgztyw` | 【ライブ配信】絶景・猪苗代スキー場  思い出2.0®幸せの鐘カメラ |
| `curated-link-lcdb-b29e0f0b` | 六甲ターミナル待機場混雑状況 | `6LZWXi80MMg` | `x6UkBHv0Fj8` | 三井六甲ライブカメラ |
| `curated-link-lcdb-c5457dd0` | JR苗穂工場 | `RcHvD0ktWAc` | `GC4cLzkVMTQ` | 苗穂JRライブ配信＜苗穂工場向きカメラ＞ |
| `curated-link-lcdb-c65201c1` | 大井松田カートランド | `mUmktB1Lchg` | `DuShoTsNWCc` | 神奈川県足柄上郡 大井松田カートランドコース ライブカメラ |
| `curated-link-lcdb-cb6473b7` | レイクサンセット風蓮湖 | `T8SCVr4zcXQ` | `HXakj5mD26A` | 【🔴ライブカメラ】野鳥の宝庫『風蓮湖』　Hokkaido -Lake Furen- A Treasure Trove o |
| `curated-link-lcdb-dfab1d74` | 神戸舞子 | `AhaHem4fQzQ` | `X4QBQ6DifJ0` | 神戸　舞子ライブカメラ　海沿いの電車　JR神戸線　舞子駅　山陽電車　舞子公園駅　沿線ライブカメラ　Enjoy the s |
| `curated-link-lcdb-e8b419fa` | 坂上興産株式会社西区営業所 | `eBIWiBAHUrg` | `agZ_c39MKwI` | 坂上興産株式会社 西区営業所 のライブ配信 |
| `curated-link-lcdb-f2dcd7af` | ケンスイ瀬戸内海 | `llNNjI8g6x4` | `6x5SJ5ATEqE` | 広島県尾道市東尾道ライブカメラ |
| `curated-link-port-yoron-kuri-port` | 与論町供利港 | `fJQ54oqoQE8` | `sufZXPA740I` | 与論町供利港ライブ配信 |
| `curated-link-scenic-betsukai-hoppo` | 別海町 北方領土ライブカメラ（野付半島） | `VXz-FQIbsMg` | `ux24JqzmnXI` | 別海町 北方領土ライブカメラ |
| `curated-link-scenic-kinpusenji` | 総本山金峯山寺（吉野山） | `CQq2uqstWdc` | `UWWcduabPb0` | 総本山金峯山寺 のライブ配信 |
| `curated-michinoeki-nikko` | 道の駅日光 駐車場 | `OOc91hF0wJY` | `4KKjVhACVAY` | 道の駅日光駐車場ライブカメラ/ニコニコ本陣 |
| `curated-morioka-ekinishi` | 盛岡駅西通 | `vMik8XBp3jI` | `WIKiWNwzkhU` | 【ライブ配信】盛岡情報カメラ |
| `curated-nakano-hogoneko` | 保護猫ルーム（富士見台どうぶつ病院） | `HAPf9X3s1Nc` | `kXbJtgJdZ3g` | 【24時間配信】保護猫ルーム｜富士見台どうぶつ病院 |
| `curated-niseko-hirafu-yotei` | ニセコグラン・ヒラフ（羊蹄山側） | `UjmKoVmjcBE` | `SscKa-yoPLM` | Niseko Tokyu Grand HIRAFU Live Camera (Ace Hill Yotei Side) |
| `curated-obs-dodaira` | 堂平天文台 | `zPKguC8bF9M` | `_8zTVMDgWZw` | 堂平天文台ライブカメラ |
| `curated-onda-sports-park-ube` | 恩田スポーツパーク（宇部） | `Hwvs3OMa4ww` | `Zsg8Yh8IjmQ` | 恩田スポーツパーク　にぎわい交流施設前＆アドベンチャー公園 |
| `curated-other-dogpark-tenten-nagareyama` | Dogpark&Cafe TENTEN（流山） | `ihqB89fen2g` | `6v2y_Bf2nLQ` | Dogpark and cafe TENTEN のライブ配信 |
| `curated-other-goto-tsubaki-airport` | 五島つばき空港 | `ftudtfg66TU` | `FPkuQrFvjV8` | 五島つばき空港✈ライブカメラ |
| `curated-other-hashimoto-sugimura-parking` | 杉村やすらぎ広場（駐車場・国道371号橋本バイパス） | `f90BkYeFXqQ` | `Zp_aMlSqU3U` | 杉村やすらぎ広場のライブ配信（駐車場） |
| `curated-other-ishigaki-airport-flight-info` | 南ぬ島石垣空港 国内線フライトインフォメーション | `XBvOwSfafF0` | `GyjtMUInR3Q` | 南ぬ島石垣空港国内線フライトインフォメーション |
| `curated-port-aogashima-sanpo-village` | 青ヶ島 三宝港（青ヶ島村） | `mkr8aUEnWuM` | `jRfrZdNuTEI` | 三宝港ライブカメラ |
| `curated-port-daikoku-fishing-pier` | 大黒海づり施設 | `J0rHqWcXd8A` | `WaXELNLDAYk` | 大黒海づり施設 のライブ配信 |
| `curated-port-honmoku-fishing-pier` | 本牧海づり施設 | `FG_hauBt09E` | `ho2mWJlfMnw` | 本牧海づり施設 のライブ配信 |
| `curated-port-ishigaki-euglena-ritou-terminal` | 石垣島 ユーグレナ離島ターミナル側 | `aGGhY9UcUDU` | `RV-nBbWAHaQ` | 石垣島ユーグレナ離島ターミナル側ＬＩＶＥカメラ |
| `curated-port-isogo-fishing-pier` | 磯子海づり施設 | `jBEumQXYOhI` | `r6fstoK58Po` | 磯子海づり施設 のライブ配信 |
| `curated-r2-12a481d6` | 竹野浜海水浴場 | `17q7guoJFJo` | `eX0cNJ5r_TU` | 竹野浜の様子 |
| `curated-r2-3a6f26ed` | のぼりべつクマ牧場 子グマの寝室 | `PG8Z6Lk3nog` | `4h0KBhdNqwQ` | 8月31日 子グマの寝室ライブカメラ　のぼりべつクマ牧場 |
| `curated-r2-40d2fd8d` | 小諸市動物園 崖上のペンギン村 | `xHRjp3b9WTI` | `T0dOSkPrCeM` | The Cliffside Penguin Village　崖上のペンギン村LIVE　8/31②　小諸市動物園 |
| `curated-r2-40ddaa3e` | JR中央線 高尾駅周辺 | `RTlLkE_vGnI` | `L2Q8NFWP2ec` | 【LIVE】JR 中央線 高尾駅 周辺 ライブカメラ / 4K LIVE TOKYO JAPAN |
| `curated-r2-4457f7ee` | JR京都駅 新幹線・東海道線 | `g6ysLd1h5v4` | `SVYBVl35R3I` | 2026/08/31 12:00～【LIVE】Kyoto Station Live Cam JR京都駅 鉄道ライブカメラ |
| `curated-r2-49cfe2fc` | 浅草 隅田川・スカイツリー | `MwcMURMzJ7A` | `opuHdUC8pBM` | 2026-08-31 12:00 ～【4K】ライブカメラ-日本-浅草-隅田川-スカイツリー-屋形船 |
| `curated-r2-4f1fe3f9` | 新穂高ロープウェイ（西穂高口） | `qmqsvWrFfww` | `PbiRK9sVw9s` | 新穂高ロープウェイ ライブカメラ　SHINHOTAKAROPEWAY LIVECAMERA |
| `curated-r2-52ce9886` | 諏訪湖 | `1OUAHmT5yYA` | `p03CD_vsaL4` | ４Ｋ【LIVE】諏訪湖・八ヶ岳ライブカメラ２｜PTZ巡回ライブ｜ Nagano Japan 2026/08/31 17: |
| `curated-r2-7100fcda` | JR静岡駅 新幹線ホーム | `6bVCr2psYAo` | `iqlXpYer3S0` | 【LIVE】静岡駅ライブカメラ　東海道新幹線・東海道本線　JAPAN Shinkansen LIVE Camera |
| `curated-r2-7430ca73` | 鳥取市伏野海岸 | `HoeuEIpyfNU` | `oN2TvtMyDak` | 鳥取市伏野海岸ライブカメラ　The Sea of Japan live camera. |
| `curated-r2-81277eca` | 原宿駅前（明治神宮方面） | `RUB0oL0SHl0` | `cptolqWrjcw` | 【4KLIVE】原宿駅前ライブカメラ｜表参道口・明治神宮 / Harajuku Live Stream (Omotesa |
| `curated-r2-978dc333` | 鹿児島空港ライブカメラ | `pJC3BThpdio` | `41CFSwlGcLU` | 【ライブカメラ】鹿児島空港 Kagoshima Airport by KYT Live |
| `curated-r2-9895fb0c` | 新宿駅前(TBSニュースカメラ) | `BePkAsZnDjM` | `u7kCTaCX_J4` | 【ライブ】新宿駅前のライブカメラ 現在の様子は？ Shinjuku, Tokyo JAPAN ｜ TBS NEWS DI |
| `curated-r2-a33106fd` | JR中央本線 熊野権現踏切 | `G3_58aWKi_Q` | `SLbSOmAazhg` | JR 中央本線ライブカメラ③（春日居町 ⇔ 石和温泉）熊野権現踏切【8月】 |
| `curated-r2-b768c9cb` | 大山（大山観光局） | `VDtMfauGMew` | `dz7L2Dy42ds` | 【LIVE配信中】大山（だいせん）の今をお届け！ |
| `curated-r2-bbbd5737` | 函館駅前（路面電車） | `rCgvMJGdhNo` | `P1GBlL8wwoE` | 【Live-Japan】函館駅前ライブカメラ② ※20秒ごとにアングルが変わります #JR函館駅 #函館 #路面電車 # |
| `curated-r2-c134e484` | 小田原城 お堀端 | `AaHxFs2mZBk` | `iEVSOXCWi4Q` | 神奈川県小田原市城内ケルトお堀ライブカメラ |
| `curated-r2-c3b76507` | 湯原温泉 街並み | `gMi9OZ-EMQM` | `G5RhrIZCTBc` | 【LIVE】湯原温泉 ライブカメラ♨️ 砂湯入口・湯原ダム Yubara Onsen Live Camera |
| `curated-r2-e0e99638` | 由布院 由布岳と夜景 | `y_L2utOItek` | `BWF81ot-P5o` | 【4K Livecamera】ゆふいん、由布岳と夜景/Yufuin Onsen-Japan |
| `curated-r2-e54499ad` | 出雲大社前駅 神門通り | `8w5S2XlRWHo` | `Un7LPBYduNo` | 島根県出雲市一畑電車大社線 出雲大社前駅神門通りライブカメラ |
| `curated-r2-ecfdf983` | 猪苗代スキー場(幸せの鐘) | `hmGMijkatDY` | `grGi5dgztyw` | 【ライブ配信】絶景・猪苗代スキー場  思い出2.0®幸せの鐘カメラ |
| `curated-r2-f9606025` | 美瑛 四季の塔 | `riTcTDJ2UMA` | `CXb35rEdDWY` | 北海道上川郡美瑛町 四季の塔と天文台ライブカメラ |
| `curated-river-qsr-gokasegawa-live` | 五ヶ瀬川 映像配信（九州地方整備局 試験配信） | `Y0ErmD-el-0` | `hwuv5b8FM6I` | 【試験配信中】九州地方整備局　五ヶ瀬川映像【Live動画】 |
| `curated-river-qsr-omarugawa-live` | 小丸川 映像配信（九州地方整備局 試験配信） | `4DbsHMixQW4` | `n4ZPb3dUBNk` | 【試験配信中】九州地方整備局　小丸川映像【Live動画】 |
| `curated-river-qsr-oyodogawa-live` | 大淀川 映像配信（九州地方整備局 試験配信） | `roLilL1JvUQ` | `4Ov35pdyBMI` | 【試験配信中】九州地方整備局　大淀川映像　【Live動画】 |
| `curated-road-k55-kohoku-pa` | 東名高速 港北PA下り | `1ypCIGjesD8` | `5HULxYXaVtw` | 【ライブカメラ】東名高速道路 港北パーキングエリア 下り【24/7 Webcam in Tomei Expressway |
| `curated-road-kanteikyoku-matsudo-r6` | 国道6号 松戸二ツ木（かんてい局松戸店前） | `Qk5cHKWsRlE` | `z4rIwOcmyYI` | 【カメラ映像】 質屋かんてい局松戸店前 |
| `curated-road-yamagata-omotezao-bussan-a` | 山形 表蔵王 国道13号・蔵王温泉入口交差点（観光物産会館  | `0nzlGCw_zVQ` | `8cskyQ-Gehs` | 山形県山形市表蔵王ライブカメラ |
| `curated-road-yamagata-omotezao-bussan-b` | 山形 表蔵王 国道13号・山形バイパス（観光物産会館 南向き | `3rNxOptVoXI` | `tELxmiVah5E` | 山形県山形市表蔵王山形バイパスライブカメラ |
| `curated-sakai-machikado-carwash-daisen` | 街角カーウォッシュ堺市大仙陵古墳店 | `FFe6PpWbHqw` | `JmBMgDrUPnc` | @街角カーウォッシュ　堺市大仙陵古墳店 |
| `curated-scenic-daisen-kankokyoku-2026` | 大山（大山町観光案内所） | `VDtMfauGMew` | `dz7L2Dy42ds` | 【LIVE配信中】大山（だいせん）の今をお届け！ |
| `curated-scenic-ibuki-highschool-ibukiyama` | 伊吹山（伊吹高校4階から） | `OPq7PL4GNwM` | `Y9iKq2ieiV4` | 伊吹山ライブカメラ |
| `curated-scenic-kutv-kochi-sky` | KUTVテレビ高知 お天気カメラ（高知市北本町） | `th1n0fSSUjk` | `eJTCcO2dQS0` | KUTVテレビ高知のライブストリーミング |
| `curated-scenic-omihachiman-myohoji-gosenkannon` | 近江八幡 八幡堀脇 普陀山妙法寺（護船観音） | `Og8yAjN350g` | `1JEbIUan4FU` | ライブカメラ 滋賀県 近江八幡市　⭐️護船観音 普陀山妙法寺 |
| `curated-scenic-tottori-city-plusbits` | 鳥取市松並町 国道53号 | `qWT06bk-pnc` | `K0Mj74T94TY` | 【LIVE 】鳥取市ライブカメラ(Plusbits) |
| `curated-scenic-yokohama-kishamichi` | 横浜汽車道（クイーンズスクエア方面） | `h8SP6IGbAPM` | `3xdEwXLKH_g` | 🔴Live Cam Yokohama Japan :横浜汽車道ライブカメラ |
| `curated-shirahama-shirarahama` | 白良浜海水浴場（白浜町公式） | `-CQ426fZMH0` | `-yp5c9glulI` | 白良浜ライブカメラ |
| `curated-shrine-kuniyasu-tenma-keidai` | 国安天満神社 境内（稲美町） | `GE180njoRoM` | `hu5ljQ2FPw8` | 兵庫県加古郡稲美町国安天満神社ライブカメラ |
| `curated-shrine-kuniyasu-tenma-oike` | 国安天満神社 天満大池 | `8V9wAUw9T2E` | `mmXnWHHH5TQ` | 兵庫県加古郡稲美町国安天満大池ライブカメラ |
| `curated-sky-maihama-livecamera` | 舞浜上空（東京ディズニーリゾート方面） | `v_GOxe9PSvY` | `z-5S9dRd-Yg` | 【 ディズニーライブカメラ  DisneyLiveCam 】スカイ・フル・オブ・カラーズ スカカラ 花火 舞浜 浦安 天 |
| `curated-skytree-toyo` | 東京スカイツリー（吾妻橋から） | `1DEOe2cBalA` | `BSCkHwiNXmc` | 【 LIVE 】東京都 墨田区 スカイツリー 24時間 ライブ / Tokyo Skytree Live |
| `curated-still-street-asahi-kawaihoncho` | 旭区川井本町 | `Gu_5nAJH-p0` | `F1IL7zG2S3w` | 神奈川県横浜市旭区川井本町ライブカメラ |
| `curated-street-hakodate-sta-1` | 函館駅前ライブカメラ①（函館湾） | `n43Rbr8kB-Y` | `IbgRGQCcRUo` | 【Live-Japan】函館駅前ライブカメラ① #函館 #HAKODATE #函館湾 #JR函館駅 |
| `curated-street-kokubuncho-sendai` | 仙台 国分町 | `hV38YF80Wkk` | `H6iToFQx7os` | 国分町ライブ配信 |
| `curated-street-minami-nakazato-2` | 南区中里 | `FDFTnsXoh6U` | `GJL8uLIgDcs` | 神奈川県横浜市南区中里ライブカメラ |
| `curated-street-minami-nakazato-k21` | 南区中里 県道21号 | `kSp0Cresb28` | `K_XttvjWnrU` | 神奈川県横浜市南区中里県道21号線ライブカメラ |
| `curated-street-sankei-kunitachi` | 国立 富士見通り（サンケイハウジング前） | `n7L45-Ey_QE` | `NoO1Ra2sk9w` | chico sandesu のライブ配信 |
| `curated-street-seya-seya` | 瀬谷区瀬谷 | `3OrcuFjcTQ0` | `KASP59WY0R0` | 神奈川県横浜市瀬谷区瀬谷ライブカメラ |
| `curated-street-takatsuki-radio171` | 高槻 4Kライブカメラ（JR京都線・阪急京都線） | `AQ9NAMZp1-Y` | `RESSlZhcVcI` | 【4Kライブカメラ】(8/31～)  #jr西日本 #jr京都線 #阪急京都線 #東海道新幹線   #天気カメラ #ライ |
| `curated-temple-honkoji-ichikawa` | 本光寺（市川）本堂・駐車場 | `yGVFJOigXIY` | `oq5EdSSc6NU` | 日蓮宗 朝のお勤め 本光寺朝参り会 24時間ライブ配信 |
| `curated-tokushima-bizan-live` | 眉山・新町橋 | `J-fuUG0hCBQ` | `VWMsRnoA3e0` | 【LIVE配信】眉山ライブカメラ（徳島県徳島市）/Mt. Bizan in Tokushima Japan - Live |
| `curated-volcano-kyt-kuchinoerabujima` | 口永良部島（KYT情報カメラ） | `r4CcpvDcUZE` | `AYspakeTF14` | 口永良部島　ライブ配信 |
| `curated-zoo-x-zoo-llama-matsudo` | エクス動物園 リャマ（松戸） | `jKRnJrUE_Vg` | `-19SL15ZBJc` | エクス動物園　リャマ日記 |
| `world-09234044` | アシュランド(バージニア) | `wgkdREYOfw0` | `4XYbh4Pegzw` | Ashland, Virginia, USA ｜ LIVE Train Camera (PTZ) |
| `world-097529dc` | ポポカテペトル火山 | `d7-noaQdkSU` | `xytHO8TgCBE` | Volcán #Popocatépetl En Vivo ｜ Vista Tlamacas, Estado de Méx |
| `world-26d90f0b` | ペリト・モレノ氷河(エルカラファテ) | `9JzOVzuvQlg` | `RXUFzvf5Qek` | 🔴 CÁMARAS EN VIVO  ARGENTINA  PATAGONIA ｜ EL CALAFATE - GLAC |
| `world-33e2cf19` | 香港 アバディーン港 | `DkmX5xQer1c` | `B_PPdZmkpwo` | 24/7 HK Live - Hong Kong Aberdeen Harbour Live Camera - 香港市景 |
| `world-404621c0` | ホノルル アラモアナビーチ | `fQtvQSWW_SE` | `1V9nWQHwIwQ` | Hawaii live stream 4K.  Ala Moana, Magic Island, Honolulu. S |
| `world-46cd3130` | 香港 ビクトリアピーク | `b6LvHqv0VwI` | `a2vb2goV9QE` | 🔴【LIVE】 Hong Kong's ONLY 24/7 LIVE camera from The Peak with |
| `world-50207ade` | ハノイ ヴィンツイ橋 | `ew0xbUrUjnY` | `dhVyIpJ0CsM` | Hanoi Live Camera 24/7 ｜ Vinh Tuy Bridge Traffic ｜ Hanoi Sky |
| `world-6d0950f2` | セブンマイルビーチ(ケイマン) | `fz9zxPfI5Gg` | `nKsxaDEiJc0` | Christopher Columbus Live Webcam Seven Mile Beach |
| `world-7db0bd4b` | ホワイトハウス | `hTHld3T7NA0` | `5p_KGD4fJZs` | earthTV® White House Cam is back! |
| `world-7def4129` | ブルックリン橋 | `gUgn9Mn_VM8` | `tErYxn2UM5Y` | EarthCam Live:  Brooklyn Bridge Cam |
| `world-81c2d3f7` | アングリンズ・ピア(フロリダ) | `aPo-gk0y9tg` | `tAdTOOsrZBQ` | EarthCam Live:  Anglins Pier (Lauderdale-By-The-Sea, FL) |
| `world-93b84fae` | フォルクストン・ファンネル(ジョージア) | `xKUkjFJkKgc` | `vDdj-QLNkiY` | Folkston, Georgia, USA ｜ LIVE Train Camera (Fixed View — Loo |
| `world-98035ddc` | ヨークROCカメラ | `zTl7MUeMDMk` | `vByZX49lCic` | York ROC Camera No.1, Yorkshire UK - in Partnership with Net |
| `world-a014976c` | リスボン空港 | `KX8UuSWJkhI` | `fbG0z7apNAM` | 🔴 LIVE 24/7 Lisbon Airport Live Cam 31.08.2026 • Plane Spott |
| `world-ae1f87fc` | ラップランド オーロラ(ポシオ) | `_WtUWtodDVA` | `HuCjMGI8fKg` | LIVE 24/7 Northern Lights & Sky Cam ｜ Lapland Finland Webcam |
| `world-bd2d6e92` | ヒースロー空港 北滑走路 | `Thp35hChuhE` | `4sK0DqkOY_8` | Heathrow Airport Live - Monday 31st August 2026 |
| `world-dc54b887` | ホノルル アラモアナビーチ2 | `8j2G58ySSKo` | `xpg2OcXUR6Y` | 📸 Hawaii Live  Stream 4K from Ala Moana, Honolulu, Hawaii 🌴🌊 |
| `world-e80f6e06` | シンガポール マリーナベイ | `YJyMPPTc8xY` | `3ZGuyCXD6-8` | 🔴 SINGAPORE LIVE 24/7  🌆 + Lofi Beats to Chill, Study & Rela |
| `world-f2df8913` | ニャチャン ビーチ | `SCpZOgLKVfY` | `n8lmPY3dEfA` | Vietnam Nha Trang live camera online / 나트랑 / Вьетнам Нячанг  |
| `yt-skr-3aab4f4176` | 都谷川樋門（肱川水系 矢落川） | `Vfw6vNKboI0` | `vyR6lTNGGYo` | 都谷川樋門（肱川水系　矢落川） |
| `yt-skr-d0f67bd212` | 鹿野川ダム吐口ゲート（肱川水系 肱川） | `8WKyvbmRxec` | `e8gz8nKBjXc` | 鹿野川ダム吐口ゲート（肱川水系　肱川） |
| `yt-skr-f35db696be` | 肱川橋（肱川水系 肱川） | `ljl3V8lr268` | `mFFjsr7cBsc` | 肱川橋（肱川水系　肱川） |

※ 台帳に同一配信を指す重複エントリがあるものは、同じ新IDへまとめて追従させた（猪苗代スキー場、KIN-TAKA沖縄、エクス動物園ほか）。

---

## (c) 退役（review.status = rejected）

cameras.json は rejected 化＋note に理由と日付を記録。yaml 側は該当ブロックを `#` でコメントアウトし、直前に `# 2026-08-31 退役: <理由>` を入れた（当代島稲荷神社と同じ方式）。

### 理由別内訳

| 理由 | 件数 |
|---|---|
| チャンネルに現行ライブなし | 79 |
| YouTube上で非公開動画になっている(oEmbed 403) | 52 |
| 動画が削除または存在しない(oEmbed 404) | 17 |
| SkylineWebcams の個別配信が終了 | 17 |
| feratel の個別ライブが終了 | 17 |
| youtube_channel: チャンネルに現行ライブなし | 12 |
| チャンネルの現行ライブは全て他カメラで使用中 | 9 |
| EarthCam の当該地点の配信が終了 | 9 |
| explore.org の当該カメラの配信が終了 | 5 |
| 定点カメラ配信終了 | 2 |
| Virtual Railfan の当該地点の配信が終了 | 2 |
| iPanda の万里の長城ライブが終了 | 2 |
| Railcam UK の当該カメラの配信が終了 | 2 |
| earthTV の当該地点の配信が終了 | 2 |
| みかん畑カメラの配信枠が終了 | 1 |
| 弾正橋カメラが現行ライブ一覧に無い | 1 |
| SkylineWebcamsのサントリーニ単独配信が終了 | 1 |
| SkylineWebcamsのフィレンツェ単独配信が終了 | 1 |
| Victoria Harbour Cam 終了 | 1 |
| EarthCam リンカーンハーバーの配信終了 | 1 |
| EarthCam タイムズスクエアの24/7配信が終了 | 1 |
| TBS NEWS DIGの浅草・雷門前の配信枠が終了 | 1 |
| 朝日新聞LIVEの成田空港A滑走路の配信枠が終了 | 1 |
| KYTの垂水 | 1 |
| webcamsdemexico のカンクン配信が終了 | 1 |
| WEBCAM NEPAL のカトマンズ配信が終了 | 1 |
| Ledrium のファレジョネス配信が終了 | 1 |

### 国内（105件）

| ID | 名称 | 理由 |
|---|---|---|
| `curated-arimabaru-beach-motobu` | ありまばるビーチリゾート（本部町具志堅） | チャンネルに現行ライブなし（配信終了 2026-08-11） |
| `curated-asahiyama-seal` | 旭山動物園 アザラシ水中 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-asakusa-kaminarimon` | 浅草 雷門前 | TBS NEWS DIGの浅草・雷門前の配信枠が終了（現行ライブは新宿駅前・羽田空港など別地点） |
| `curated-biwako-bbc` | 琵琶湖・大津 | youtube_channel: チャンネルに現行ライブなし |
| `curated-busena-underwater-observatory` | ブセナ海中公園 海中展望塔 「リアル水族館」 | チャンネルに現行ライブなし（配信終了 2025-08-06） |
| `curated-chichibugahama` | 父母ヶ浜 | チャンネルに現行ライブなし（配信終了 2023-07-06） |
| `curated-chuzenji-zen` | 中禅寺湖・男体山（ZEN RESORT） | youtube_channel: チャンネルに現行ライブなし |
| `curated-coast-isao-studio-tokyo-bay` | 習志野 茜浜（東京湾・イサオスタジオ） | チャンネルに現行ライブなし（配信終了 2023-11-15） |
| `curated-farm-iwai-asahi-4` | イワイ牧場 せんば牛 牛舎-4（旭） | チャンネルに現行ライブなし（配信終了 2024-07-22） |
| `curated-hakata-port-tvq` | 博多港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-harimaya-bashi` | はりまや橋交差点 | youtube_channel: チャンネルに現行ライブなし |
| `curated-healing-yanbaru-aha-ikimono` | やんばる生き物LIVE 水場（道の駅やんばるパイナップルの丘安波） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-hijiori-onsen` | 肘折温泉（積雪定点） | youtube_channel: チャンネルに現行ライブなし |
| `curated-hotel-gamagori-classic` | 蒲郡クラシックホテル（三河湾・竹島） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-ichihara-umizuri-sanbashi` | オリジナルメーカー海づり公園 桟橋釣り場側カメラ | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2024-11-24） |
| `curated-inubosaki` | 犬吠埼 | youtube_channel: チャンネルに現行ライブなし |
| `curated-itami-asahi` | 伊丹空港（大阪国際空港） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-kamifurano-hinode` | 上富良野 日の出公園展望台 | youtube_channel: チャンネルに現行ライブなし |
| `curated-kasai-suizokuen` | 葛西臨海水族園 | youtube_channel: チャンネルに現行ライブなし |
| `curated-kumamoto-castle-kab` | 熊本市街・熊本城 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-laguna-garden-ginowan` | 宜野湾海浜公園・東シナ海（ラグナガーデンホテル） | チャンネルに現行ライブなし（配信終了 2026-08-12） |
| `curated-lcdb-0614b9c6` | 那須高原ペンションローレル | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-0df79d57` | 敦賀市清掃センター | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-103472d8` | モバイルテレビジョン首都高速道路首都高速1号羽田線浜崎橋JCT | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-14cf05e4` | 敦賀ゴルフガーデン | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-36d62885` | 鹿屋体育大学海洋スポーツセンター | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-39909785` | 豊田市矢作川第2 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-4c24c481` | 四日市中央通り第2 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-4ef91d2f` | 袖ケ浦市役所窓口案内状況 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-63b10989` | 東京AUTO洗車中野店 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-63fe8c3c` | 源整院琴似駐車場 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-65fde66e` | FMラヂオバリバリ | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-83f0ebaf` | 長野パラグライダースクールADDS北アルプス | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-84b44399` | モバイルテレビジョン首都高速道路高速湾岸線葛西有明付近 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-86f8f569` | 福地温泉来福の森 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-8b514dea` | 四日市中央通り第3 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-915ac311` | 四日市中央通り第1 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-982371e5` | 天神橋筋商店街 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-99f99749` | 八剣山ワイナリー | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-a5dec08b` | なかよしステーション神木 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-b02a2b44` | 三ヶ日みかん畑 | みかん畑カメラの配信枠が終了（チャンネルの現行ライブはヤフオク生中継で別内容） |
| `curated-lcdb-b6ce95f3` | 益田川漁業協同組合 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-ba89dd95` | モバイルテレビジョン首都高速道路都心環状線宝町付近 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-bc09e7bf` | ドローン酒屋荘川 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-d0b7f7af` | 姫路山陽新幹線 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-dbf3a757` | かたしな高原チャイルドロッヂエリア | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-e2f997ef` | 駒沢公園動物病院混雑状況 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-e640c118` | ナンスポゴルフ練習場 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-lcdb-edb1af04` | テルヤ電機養蜂 | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-f50525f6` | 石垣島舟蔵ビーチ | 動画が削除または存在しない(oEmbed 404) |
| `curated-lcdb-fba706d0` | モバイルテレビジョン首都高速道路都心環状線呉服橋付近 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-157fe911` | 淡路寄合池 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-1a0866d4` | 穴池 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-22d579ae` | 御荘港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-6946f864` | 三崎港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-7427988a` | モアイスケートパーク | 動画が削除または存在しない(oEmbed 404) |
| `curated-link-lcdb-810fbc40` | 東予港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-8abd9498` | 手稲山地区地すべり市道亀裂箇所 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-8d864daa` | 三島川之江港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-a987c402` | 西武ドーム3塁メインコンコース売店L’s側 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-lcdb-e86e4621` | 波止浜港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-other-hidakagawa-anaike` | 穴池（日高川町） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-link-scenic-ninnaji` | 仁和寺（京都観光混雑状況Live2） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-maehama-miyakotv` | 与那覇前浜ビーチ・来間大橋 | youtube_channel: チャンネルに現行ライブなし |
| `curated-muni-happo-masegawa` | 真瀬川ライブカメラ（八峰町） | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2026-02-24） |
| `curated-nagasaki-port` | 長崎港 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-naha-airport-ntv` | 那覇空港（日テレ） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-narita-a-asahi` | 成田空港 A滑走路 | 朝日新聞LIVEの成田空港A滑走路の配信枠が終了（現行ライブは銀座のみ） |
| `curated-nikko-akechidaira` | 第二いろは坂 明智平（国道120号） | youtube_channel: チャンネルに現行ライブなし |
| `curated-niseko-view-plaza` | 道の駅ニセコビュープラザ | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-ofunato-tvi` | 大船渡（お天気カメラ） | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2025-04-28） |
| `curated-ohori-nishinippon` | 大濠公園・福岡タワー方面 | チャンネルに現行ライブなし（配信終了 2021-04-17） |
| `curated-qsr-honmyogawa-6point` | 本明川 6地点切替（諫早） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-r2-35d9f43a` | 旭山動物園 ペンギン放飼場 | チャンネルに現行ライブなし（配信終了 2026-08-21） |
| `curated-r2-39214965` | 天神橋筋商店街 | 動画が削除または存在しない(oEmbed 404) |
| `curated-r2-435f68f9` | 梅田情報カメラ | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-r2-4d718994` | 宮島水族館 はつこい庵/スナメリ | チャンネルに現行ライブなし（配信終了 不明） |
| `curated-r2-54f03b09` | とかち村上牧場 モグモグLIVE | チャンネルに現行ライブなし（配信終了 2026-03-06） |
| `curated-r2-5e0c257b` | 志賀高原 横手山・渋峠 | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2026-08-21） |
| `curated-r2-6223b1f9` | VIVAアルパカ牧場 | チャンネルの現行ライブは全て他カメラで使用中（配信終了 不明） |
| `curated-r2-9ee7b650` | 長門湯本温泉 恩湯前 | チャンネルに現行ライブなし（配信終了 2026-04-04） |
| `curated-r2-b0cd4ffc` | 厚岸水鳥観察館 | チャンネルに現行ライブなし（配信終了 2026-08-19） |
| `curated-r2-f46f84a7` | 海王丸パーク・新湊大橋 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-rapport-yuya-nagato` | ラポールゆや テラス（国道191号・掛淵川） | チャンネルに現行ライブなし（配信終了 2026-08-14） |
| `curated-rcc-hiroshima` | 広島（お天気カメラ） | チャンネルに現行ライブなし（配信終了 2021-01-31） |
| `curated-road-asahikawa-autobahn-toko` | 旭川環状線 東光（アウトバーン スズキアリーナツインハープ東光店） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-ropeway-hakkaisan-sancho` | 八海山ロープウェー 山頂 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-seibuen-keirin-official-live` | 西武園競輪 公式インターネットライブ | youtube_channel: チャンネルに現行ライブなし |
| `curated-sendai-kitakanjo` | 仙台 北環状線（南吉成） | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2025-09-29） |
| `curated-still-matsumasa-kongozan` | 金剛山登山口（府道705号・千早駐車場） | youtube_channel: チャンネルに現行ライブなし |
| `curated-street-ofuna-kasamaguchi` | 大船駅 笠間口交差点 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-takayama-jinya` | 飛騨高山 陣屋前 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-takayama-nakabashi` | 飛騨高山 中橋 | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-tarumizu-kyt` | 垂水 海潟・錦江湾 | KYTの垂水（海潟・錦江湾）配信枠が終了（現行ライブは鹿児島空港のみ） |
| `curated-tokushima-bunkanomori` | 文化の森総合公園 シンボル広場 | チャンネルに現行ライブなし（配信終了 不明） |
| `curated-tokushimagas-yoshinogawa` | 吉野川河口（徳島ガス） | チャンネルに現行ライブなし（配信終了 2023-11-10） |
| `curated-tokyo-sta-train` | 東京駅トレインビュー | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-toyako` | 洞爺湖 | youtube_channel: チャンネルに現行ライブなし |
| `curated-tsuchiura-r125` | 土浦 国道125号（城北町） | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-tsukuba-ekimae-intec` | つくば駅前（株式会社インテック） | チャンネルに現行ライブなし（配信終了 不明） |
| `curated-tvi-morioka` | 盛岡（おてんきLIVE） | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2026-05-25） |
| `curated-univ-hiroshima-higashihiroshima` | 広島大学 東広島キャンパス | YouTube上で非公開動画になっている(oEmbed 403) |
| `curated-yukurina-resort-motobu` | ゆくりなリゾート沖縄 海風（本部町石川） | チャンネルに現行ライブなし（配信終了 2026-07-03） |
| `muni-ohtawara-712fd8f65b` | 大田原市 弾正橋付近 | 弾正橋カメラが現行ライブ一覧に無い（他8カメラは配信中） |
| `muni-yokosuka-a56592aaf1` | 横須賀市 川間川 | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2026-07-20） |

### 海外（135件）

| ID | 名称 | 理由 |
|---|---|---|
| `world-0273cc50` | セントルイス ゲートウェイアーチ | チャンネルに現行ライブなし（配信終了 2018-12-01） |
| `world-032a3283` | リヴィーニョ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-043b774b` | シドニー ハーバー(PTZ) | チャンネルに現行ライブなし（配信終了 2026-05-31） |
| `world-04488e3b` | シドニー 市街(PTZ) | チャンネルに現行ライブなし（配信終了 2024-10-08） |
| `world-060282c1` | サントリーニ島 | SkylineWebcamsのサントリーニ単独配信が終了（現行はギリシャ複数カメラのまとめ配信） |
| `world-06086ae6` | アラスカ ブルックス滝のヒグマ | explore.org の当該カメラの配信が終了（チャンネルの現行ライブは別カメラ） |
| `world-06ec65c7` | リマ ミラフローレス | チャンネルに現行ライブなし（配信終了 不明） |
| `world-086f93d3` | ローマ トレビの泉 | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-09e2bef0` | グアム タモン湾 | チャンネルに現行ライブなし（配信終了 2024-02-08） |
| `world-0f76b5d8` | バラナシ ガンジス川 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-11e69092` | ザルツブルク ミラベル宮殿 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-121467a4` | イシュグル パルダッチュグラート | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-125e4f22` | プーケット パトンビーチ | チャンネルに現行ライブなし（配信終了 2020-08-21） |
| `world-14c7a9bd` | シアトル スペースニードル | チャンネルに現行ライブなし（配信終了 2020-11-04） |
| `world-14dd4191` | メデジン エルポブラード | チャンネルに現行ライブなし（配信終了 2026-07-24） |
| `world-1766a76e` | ボラカイ島 ホワイトビーチ2 | チャンネルに現行ライブなし（配信終了 2025-11-20） |
| `world-19cfb657` | ボンダイビーチ | チャンネルに現行ライブなし（配信終了 2026-03-16） |
| `world-1b39dab1` | サン・カンディド(ドロミテ) | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-1ba97c80` | ゴールドコースト サーファーズパラダイス | チャンネルに現行ライブなし（配信終了 不明） |
| `world-1c1f9808` | セルファウス | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-1c5a4f1e` | プーケット ビーチ | チャンネルに現行ライブなし（配信終了 2025-04-11） |
| `world-1c5e023d` | エルサレム 嘆きの壁(別アングル) | チャンネルに現行ライブなし（配信終了 2024-08-12） |
| `world-1c61df4b` | フィジー ヴォモ島リゾート | チャンネルに現行ライブなし（配信終了 2026-03-22） |
| `world-1d228bd6` | ハミングバード給水器(ラグナニゲル) | explore.org の当該カメラの配信が終了（チャンネルの現行ライブは別カメラ） |
| `world-1d31e055` | 万里の長城(慕田峪) | iPanda の万里の長城ライブが終了（現行ライブはパンダのみ） |
| `world-214b01d7` | マルタ ヴァレッタ港 | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-21eb5910` | マッターホルン(ツェルマット) | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-28195703` | カトマンズ市街 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-287c7512` | クアラルンプール ペトロナスツインタワー | チャンネルに現行ライブなし（配信終了 2023-09-30） |
| `world-2aa05e26` | アトランタ ダウンタウン | 定点カメラ配信終了（チャンネルの現行ライブはニュース番組のみ） |
| `world-2bc8aa53` | ザイオン国立公園(カナーン山) | チャンネルに現行ライブなし（配信終了 2024-05-16） |
| `world-2cd653c5` | ペナン ジョージタウン | YouTube上で非公開動画になっている(oEmbed 403) |
| `world-2d64a446` | ビクトリア インナーハーバー | Victoria Harbour Cam 終了（現行ライブは別都市 Nanaimo Harbour Cam） |
| `world-3171c604` | フィレンツェ ドゥオーモ | SkylineWebcamsのフィレンツェ単独配信が終了（現行はイタリア複数カメラのまとめ配信） |
| `world-332e6b73` | アテネ アクロポリス | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-345d22dc` | 自由の女神 | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-3537604c` | ミラノ ドゥオーモ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-36cb7654` | ガラパゴス ゾウガメ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-38f502d2` | ケアンズ マリーナ | チャンネルに現行ライブなし（配信終了 不明） |
| `world-3b62917a` | ニューオーリンズ バーボンストリート | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-3be93a86` | シュトゥバイ氷河 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-3d894086` | ケルン大聖堂周辺 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-3eec5762` | プラハ旧市街広場 | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-4077683b` | ハンブルク港 | チャンネルに現行ライブなし（配信終了 2026-08-19） |
| `world-4190b683` | カトマンズ スワヤンブナート寺院 | WEBCAM NEPAL のカトマンズ配信が終了（現行ライブは別地点） |
| `world-444b4433` | サバンナ リバーストリート | チャンネルに現行ライブなし（配信終了 不明） |
| `world-450f748e` | ザールバッハ | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-4703109b` | バンフ | チャンネルに現行ライブなし（配信終了 不明） |
| `world-4c106408` | ペトラ エル・ハズネ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-4cad8407` | アムステルダム 運河 | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-525c9e3d` | カンクン | webcamsdemexico のカンクン配信が終了（現行ライブはメキシコ市内など別地点） |
| `world-53309ac5` | ネグリル セブンマイルビーチ | チャンネルに現行ライブなし（配信終了 2022-11-13） |
| `world-56722813` | ヨセミテ国立公園(4カメラ切替) | YouTube上で非公開動画になっている(oEmbed 403) |
| `world-5689b67d` | コーラルプレデターズ(太平洋水族館) | explore.org の当該カメラの配信が終了（チャンネルの現行ライブは別カメラ） |
| `world-5b63e063` | ミュンヘン マリエン広場 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-5c3d9393` | クレドゥ島(モルディブ) | チャンネルに現行ライブなし（配信終了 2022-01-14） |
| `world-5d899122` | クイーンズタウン | チャンネルに現行ライブなし（配信終了 2021-03-24） |
| `world-5f66a9a9` | チャールストン ダウンタウン | チャンネルに現行ライブなし（配信終了 2019-09-06） |
| `world-609bfded` | ブエノスアイレス オベリスコ | チャンネルに現行ライブなし（配信終了 不明） |
| `world-60ff70af` | ロンドン タワーブリッジ | YouTube上で非公開動画になっている(oEmbed 403) |
| `world-61393584` | ベネチア サンマルコ広場 | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-63136264` | リンカーンハーバー(NY眺望) | EarthCam リンカーンハーバーの配信終了（現行ライブは Coney Island で別地点） |
| `world-6533620e` | ハワイ島 ヒロ | チャンネルに現行ライブなし（配信終了 2022-05-25） |
| `world-66438b00` | カホンパス(カリフォルニア) | Virtual Railfan の当該地点の配信が終了（現行ライブは別地点） |
| `world-666e0864` | ピーターバラ駅 | Railcam UK の当該カメラの配信が終了（現行ライブは別カメラ） |
| `world-66bdb72e` | 香港 九龍市街 | チャンネルに現行ライブなし（配信終了 2025-11-12） |
| `world-6a145a17` | エルニド(パラワン) | チャンネルに現行ライブなし（配信終了 2021-12-31） |
| `world-6a63bfee` | フィジー ヴォモ島2 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-6c303f70` | コペンハーゲン市庁舎広場 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-6c4e156a` | サルバドール バーラ灯台 | チャンネルに現行ライブなし（配信終了 2024-10-27） |
| `world-6c5de37f` | コパカバーナビーチ(Skyline) | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-6fcbd369` | ローマ コロッセオ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-6fd394bf` | ハミングバード給水器(オーシャンサイド) | explore.org の当該カメラの配信が終了（チャンネルの現行ライブは別カメラ） |
| `world-7073ca8e` | ピッツタール氷河 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-70a20239` | オークランド ハーバー | チャンネルの現行ライブは全て他カメラで使用中（配信終了 2026-04-28） |
| `world-71200316` | 八達嶺長城 | iPanda の万里の長城ライブが終了（現行ライブはパンダのみ） |
| `world-736688ee` | シドニー オペラハウス・ハーバーブリッジ | チャンネルに現行ライブなし（配信終了 2024-10-08） |
| `world-7649f601` | チェンマイ市街 | チャンネルに現行ライブなし（配信終了 2024-06-05） |
| `world-776f8537` | ソウル 南山タワー | YouTube上で非公開動画になっている(oEmbed 403) |
| `world-783266dc` | パース市街 | チャンネルに現行ライブなし（配信終了 2021-09-15） |
| `world-799841d4` | ワシントンDC 議事堂 | 定点カメラ配信終了（現行ライブは24/7ニュース番組で議事堂カメラではない） |
| `world-79fd0510` | ハワイ島 ロイヤルコナリゾート | チャンネルに現行ライブなし（配信終了 2022-06-21） |
| `world-7b7b8c97` | サイパン マイクロビーチ | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-7e4b0fec` | アーリービーチ | チャンネルに現行ライブなし（配信終了 不明） |
| `world-80d379e0` | ババロビーチ(プンタカーナ) | チャンネルに現行ライブなし（配信終了 2022-12-25） |
| `world-86851cb0` | コルティナ・ダンペッツォ | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-88ae59a6` | ソルデン ゼーコグル | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-8a476419` | ヒンタートゥクス氷河 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-8ee73c22` | ポルト リベイラ | 動画が削除または存在しない(oEmbed 404) |
| `world-94dfb9b4` | アレナル火山(コスタリカ) | チャンネルに現行ライブなし（配信終了 2023-06-09） |
| `world-95b34327` | ドブロブニク旧市街 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-97e23bd7` | ソウル 光化門広場 | YouTube上で非公開動画になっている(oEmbed 403) |
| `world-9bfd2f21` | ワルシャワ 文化科学宮殿から | earthTV の当該地点の配信が終了（現行ライブは別地点/総集編） |
| `world-a52d6fb5` | イスタンブール ボスポラス海峡2 | チャンネルに現行ライブなし（配信終了 2020-01-24） |
| `world-a69bb98e` | ピッツバーグ ダウンタウン | チャンネルに現行ライブなし（配信終了 2023-01-15） |
| `world-a7353b51` | サンディエゴ ガスランプクォーター | チャンネルに現行ライブなし（配信終了 不明） |
| `world-a8ec400b` | インスブルック ノルトケッテ | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-a9c2f58e` | ダナン スカイライン | チャンネルに現行ライブなし（配信終了 2026-08-21） |
| `world-aafd5709` | タンパ スカイライン | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-ad498b9f` | ロフォーテン諸島(レーヌ) | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-ae10f21d` | バート・ガシュタイン | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-aee39e3d` | アーリービーチ2 | チャンネルに現行ライブなし（配信終了 2023-11-09） |
| `world-b0ff85a7` | ブダペスト 鎖橋 | earthTV の当該地点の配信が終了（現行ライブは別地点/総集編） |
| `world-b341c725` | グリンデルワルト・ファースト(アイガー) | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-b80d4659` | タイムズスクエア交差点 | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-b87725f1` | チェサピーク湾 船舶ウォッチ | チャンネルに現行ライブなし（配信終了 不明） |
| `world-bceb38e7` | ラスベガス ストリップ | 動画が削除または存在しない(oEmbed 404) |
| `world-be23214e` | バンコク チャオプラヤー川 | チャンネルに現行ライブなし（配信終了 2024-11-24） |
| `world-c186ce00` | リオデジャネイロ コパカバーナ | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-c4a923ae` | カーライル湾(バルバドス) | チャンネルに現行ライブなし（配信終了 不明） |
| `world-c85849da` | ピサの斜塔 | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-caf6156f` | イスタンブール ボスポラス海峡 | チャンネルに現行ライブなし（配信終了 2020-02-22） |
| `world-cc4d7d63` | ファレジョネス スキーリゾート | Ledrium のファレジョネス配信が終了（現行ライブはサンティアゴ市内の別カメラ） |
| `world-cda27a66` | ニューヨーク タイムズスクエア | EarthCam タイムズスクエアの24/7配信が終了（現行ライブはスペイン Tamariu で別地点） |
| `world-ced5d832` | テルアビブ スカイライン | チャンネルに現行ライブなし（配信終了 2026-05-01） |
| `world-d0a76ee9` | ブラウンカウンティ(インディアナ) | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-d2cea02e` | ベルリン ブランデンブルク門 | チャンネルに現行ライブなし（配信終了 2022-01-23） |
| `world-d3ae159b` | プノンペン ストリート136 | チャンネルに現行ライブなし（配信終了 2023-11-24） |
| `world-dae461c6` | フェニックス ダウンタウン | チャンネルに現行ライブなし（配信終了 不明） |
| `world-dba7fd4b` | ドバイ ダウンタウン(ブルジュハリファ) | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-de4b88c3` | マイヤーホーフェン | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-de5a8876` | バクー フレイムタワーズ | チャンネルに現行ライブなし（配信終了 2024-07-26） |
| `world-df02fb90` | イスタンブール スルタンアフメット | チャンネルに現行ライブなし（配信終了 不明） |
| `world-e1069f41` | マドリード プエルタ・デル・ソル | チャンネルに現行ライブなし（配信終了 不明） |
| `world-e64b90b8` | リグレー・フィールド(シカゴ) | EarthCam の当該地点の配信が終了（チャンネルの現行ライブは別地点） |
| `world-eb2b9ddc` | SWフロリダ ハクトウワシの巣 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-ec3f400a` | クスコ アルマス広場 | チャンネルに現行ライブなし（配信終了 不明） |
| `world-ee410dba` | クルー駅(イギリス) | Railcam UK の当該カメラの配信が終了（現行ライブは別カメラ） |
| `world-eeb3beb7` | 沖合水中シャークカメラ(ノースカロライナ) | explore.org の当該カメラの配信が終了（チャンネルの現行ライブは別カメラ） |
| `world-f0a98740` | ポジターノ(アマルフィ海岸) | SkylineWebcams の個別配信が終了（現行ライブは国別まとめ配信のみ） |
| `world-f2e23510` | オースティン スカイライン | チャンネルに現行ライブなし（配信終了 不明） |
| `world-f4b93894` | ロシェル鉄道公園(イリノイ) | Virtual Railfan の当該地点の配信が終了（現行ライブは別地点） |
| `world-f636c599` | ウィーン市庁舎広場 | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-f684cfd6` | オーバータウエルン | feratel の個別ライブが終了（現行ライブは地域まとめ配信のみ） |
| `world-fdeb1090` | ボラカイ島 ホワイトビーチ | チャンネルに現行ライブなし（配信終了 2023-01-17） |

---

## (d) 要確認（台帳は変更していない）

次のものは自動判定では死活を確定できないため保留した。次回の確認（できれば日本時間の日中）で再判定すること。

| ID | 名称 | 保留理由 |
|---|---|---|
| `curated-camp-shiunji-kinen-park` | 紫雲寺記念公園オートキャンプ場 | 配信終了が直近7日以内（2026-08-25）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-coast-kamogawa-seaside-2026` | 鴨川 前原海岸（鴨川シーサイド） | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-coast-tanabe-tenjinzaki` | 天神崎（丸山灯台・田辺湾） | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-gero-suimeikan` | 下呂温泉 水明館（日本庭園・飛騨川） | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-golf-chibacc-noda` | 千葉カントリークラブ 野田コース | 配信終了が直近7日以内（2026-08-25）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-golf-chibacc-umesato` | 千葉カントリークラブ 梅郷コース | 配信終了が直近7日以内（2026-08-25）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-hors-hasaki` | 波崎海洋研究施設 観測桟橋（鹿島灘） | 配信終了が直近7日以内（2026-08-25）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-kamogawa-maehara` | 鴨川 前原海岸 | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-0b91e964` | アルカフェ | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-0caed334` | 群言堂石見銀山 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-0dc2431d` | 平和島競艇 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-126a636a` | 友泉亭公園 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-190d0226` | 美容室b1hair | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-2024898b` | TeamCRCJapan | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-27d2f5d6` | スポーツクライミングジムレインボークリフ | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-2c29551c` | ラボットミュージアム | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-2ed068c2` | エビスサーキット西コースピット第1 | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-35b28ed7` | 長門湯本温泉恩湯 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-3bf08c6a` | 佐賀競馬 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-3fe57013` | 雨引観音護摩祈願 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-43baa9f9` | どれみふぁ空シマエナガ | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-442fbc17` | 富士砂防事務所 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-4acdad41` | びわこ競艇 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-4ecbd23a` | 有明スポーツセンター混雑状況 | チャンネルに現行ライブはあるが対応付けできない |
| `curated-lcdb-51cf7aca` | 大沼球場 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-582d11a4` | 浜松オートレース | チャンネルに現行ライブはあるが対応付けできない |
| `curated-lcdb-5b7b1814` | サウナゆげ蔵 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-639829a1` | FMたまん | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-67cc1186` | ソピアゴルフガーデン打席空き状況 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-6c3ebdfe` | 前橋競輪 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-6cf2dfc2` | 下関競艇 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-6d479625` | 三津浜港 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-75eeb60f` | 深川北スポーツセンター小プール混雑状況 | チャンネルに現行ライブはあるが対応付けできない |
| `curated-lcdb-76baf7c8` | 三国競艇 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-7f6e21dc` | トレインタイムス流鉄流山線 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-82fd9e99` | 龍江地域づくり委員会天竜川 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-8a925edb` | 厚岸水鳥観察館 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-8eb26476` | 明覚寺 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-938f0f35` | 白井自然農園 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-95fd94f8` | 早来カントリー倶楽部 | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-99d5c8e2` | 道の駅のつはる | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-a08b97af` | 銀河の湯あしょろ混雑状況 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-a41070b9` | 郡上八幡自然苑 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-aa9a6ada` | とらや店内 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-aaab5db1` | 南幌リバーサイドカートランド | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-abad3a48` | 伊勢崎オートレース | チャンネルに現行ライブはあるが対応付けできない |
| `curated-lcdb-ade89b0c` | エビスサーキット東コースラップ | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-b02e4670` | FM宝塚 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-b31abf41` | 肘折温泉銅山川 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-bb59ac5c` | FMよみたん | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-c6ebf65f` | 三越前はり灸整骨院混雑状況 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-c8355778` | フォレストパーク神野山 | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-cfef8da4` | 阿仁川下前田温泉下 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-d3aef79f` | エビスサーキット東コース第1コーナー | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-d7a000ec` | フラワーギャラリースローダンス | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-da057a14` | 熊野那智大社那智の瀧 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-dbba987d` | HBC北海道新型コロナウイルス記者会見 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-dff2fc45` | エフエムいたみ | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-e26aa23c` | セレクトちゃんねる上田市 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-eb3d00f7` | TokyoJAM世田谷上空 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-lcdb-ed170dd4` | HOPS浜崎海岸 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-coast-yoron-paradise-beach` | パラダイス・ビーチ（与論島） | 配信終了が直近7日以内（2026-08-25）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-0db20af1` | ひるがの高原別荘管理センター | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-182228fe` | 東砂スポーツセンタープール混雑状況 | チャンネルに現行ライブはあるが対応付けできない |
| `curated-link-lcdb-632dd5de` | 秋保温泉ホテル華乃湯駐車場 | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-84cab4f9` | 純水セルフ洗車高松西店 | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-8f9e7906` | 武蔵野の森総合スポーツプラザ入館者数表示モニター | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-b4a4a3ce` | セレーノディプリマヴェーラ | 配信終了が直近7日以内（2026-08-30）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-link-lcdb-ccd2590c` | 塩原温泉ホテルおおるり | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-mountain-akaishidake-sawarajima` | 赤石岳（椹島） | 配信終了が直近7日以内（2026-08-31）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-mountain-sanbesan-nishinohara` | 三瓶山 西の原（山の駅さんべ） | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-muni-kamoenai` | 神恵内村ライブカメラ | 配信終了が直近7日以内（2026-08-27）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-niseko-hirafu-annupuri` | ニセコグラン・ヒラフ（アンヌプリ側） | アンヌプリ側の枠が終了。現行ライブは「(.Base)」で画角が異なる |
| `curated-other-hikone-daitocho-livecam` | 彦根市大東町 定点カメラ | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-other-kochi-airport-parking` | 高知龍馬空港 駐車場混雑状況 | 配信終了が直近7日以内（2026-08-26）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-r2-4d786767` | 富良野スキー場 北の峰 | 冬季のみ運用の可能性（チャンネルに現行ライブなし（配信終了 不明））。シーズン前に再確認 |
| `curated-r2-7c0fa32e` | 富士山頂 東向き ソーラーカメラ（ご来光） | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-r2-db7d489e` | 富士山頂 西向き | 配信終了が直近7日以内（2026-08-27）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-rito-chichijima` | 父島（二見港） | プレイリストにライブ判定なし（要目視） |
| `curated-road-mobara-hayano-hobundo` | 県道27号 茂原大多喜線 茂原早野（豊文堂前） | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-ryukyushimpo-nahashiyakusho-mae` | 那覇市役所前交差点 | 那覇市役所前の配信枠が終了。現行は「りゅうちゃんカメラ（国際通り・県庁前）」で画角が異なる |
| `curated-scenic-yonago-ryosanyanagi` | 米子市両三柳 | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-teiten-ryugudori` | 国際通り 竜宮通り入口 | 配信終了が直近7日以内（2026-08-27）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-transit-cafe-chatan` | トランジットカフェ（北谷町宮城海岸） | 配信終了が直近7日以内（2026-08-24）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-univ-tohoku-aobayama` | 東北大学 青葉山キャンパス | 配信終了が直近7日以内（2026-08-29）。営業時間のみ/夜間停止の運用と区別できないため要再確認 |
| `curated-zao-360` | 蔵王温泉スキー場（360度） | 冬季のみ運用の可能性（チャンネルに現行ライブなし（配信終了 2026-01-02））。シーズン前に再確認 |
| `world-df40e70a` | サンティアゴ市街 | チャンネルに現行ライブはあるが対応付けできない |
| `yt-skr-40d3546d17` | 那賀川橋（那賀川水系 那賀川） | チャンネルに現行ライブはあるが対応付けできない |
| `yt-skr-6b773bb4d8` | 長安口ダム直下流（那賀川水系 那賀川） | チャンネルに現行ライブはあるが対応付けできない |
| `yt-skr-b106ea43f8` | 長生橋（那賀川水系 桑野川） | チャンネルに現行ライブはあるが対応付けできない |
| `yt-skr-c501dbe932` | 那賀川河川事務所（那賀川水系 桑野川） | チャンネルに現行ライブはあるが対応付けできない |

---

## 判定上の注意（次回のために）

- **確認した時刻が日本時間の深夜帯**（動画チェック 21:20〜22:05 JST、チャンネルチェック 24:50〜25:00 JST）。
  営業時間のみ配信する施設カメラ（競艇・競輪、店舗、温泉、プール、市役所窓口など）は当然オフになる。
  そのため **配信終了が直近7日以内のものは退役させず要確認に回した**（67件）。日中に再確認すれば大半は正常に戻るはず。
- 冬季のみ運用のスキー場・積雪カメラも退役させず要確認に回した（肘折温泉・富良野・蔵王）。
- `"isLiveNow":true` でも playabilityStatus が LIVE_STREAM_OFFLINE / UNPLAYABLE になることがある（配信は生きているが一時的に映像が止まっている）。end_ts が無ければライブ扱いにした。
- **oEmbed の 403 は「非公開動画」、404 は「削除/存在しない」**。watch ページの playabilityStatus はそれぞれ LOGIN_REQUIRED / ERROR になり、videoDetails が無いので**チャンネルIDが取れず追従できない**。
  今回の退役 69件（非公開52・削除17）はこの理由で追従不可。伊丹空港（朝日新聞）・熊本城（KAB）・東京駅トレインビュー・天神橋筋商店街など有名どころが含まれるので、
  運営者名から新しい配信枠を手で探せば復活できる可能性が高い。
- チャンネル `/streams` の取得は `https://www.youtube.com/channel/<UCxxx>/streams` でないと404になる（`/UCxxx/streams` は不可）。
- 名称とライブタイトルの対応付けは、**旧タイトルとの一致を最優先**にすると精度が高い（配信枠の作り直しはタイトルがほぼ同じ）。
  カメラ名だけで突き合わせると「Victoria Harbour Cam → Nanaimo Harbour Cam」のような別地点への誤追従が起きる（今回は目視で除外）。
- SkylineWebcams・feratel は個別地点のライブをやめて「国別まとめ配信」に集約した。EarthCam・explore.org・Virtual Railfan・Railcam も地点の入れ替えが激しい。海外カメラは今後も減り続ける前提で扱うのがよい。

## 生成物

- 作業ログ・生データ: `/private/tmp/.../scratchpad/ythealth/`（video_status.jsonl / channel_live.jsonl / classified_final.json / decisions.json）

---

# 追記: (d) 要確認91台の再確認（2026-09-01 19:45〜20:00 JST）

8/31の一斉確認は深夜（22〜23時台）に実施したため、営業時間のみ配信・夜間停止の運用と
「本当に終了した配信」を区別できなかった。9/1 の夕方に同じ手順（watch ページの isLiveNow +
チャンネル `/streams` の現行ライブ列挙）で91台を再取得した。スクリプト:
`scratchpad/ythealth2/recheck.py`、結果: `recheck_result.json`。

| 区分 | 件数 | 対応 |
|---|---|---|
| 旧IDのままライブ中 | 0 | — |
| チャンネルに現行ライブあり → 配信枠を特定できた | 36 | **台帳を更新（適用済み）** |
| チャンネルに現行ライブはあるが画角・対象が違う | 7 | 台帳変更なし（下記） |
| チャンネルにも現行ライブなし | 48 | 台帳変更なし（下記） |

## 更新した36台

同一チャンネルの現行ライブとタイトルが一致（日付部分の差し替えのみを含む）したもの。
`data/cameras.json` の feed.url / fallback.url / source.page_url と、
`crawler/curated_youtube.yaml`（26件）/ `crawler/curated_still.yaml`（6件）の video_id を新IDへ差し替えた
（`yt-skr-*` の四国地整4台はyamlに実体が無いため台帳のみ）。

江東区スポーツセンター3台（有明・深川北・東砂）、四国地整 那賀川水系4台、エビスサーキット3台、
千葉カントリークラブ2台、伊勢崎オートレース、下関競艇、紫雲寺記念公園、波崎観測桟橋、群言堂石見銀山、
レインボークリフ、長門湯本恩湯、雨引観音、ソピアゴルフ、伊那谷、白井自然農園、道の駅のつはる、
銀河の湯あしょろ、郡上八幡自然苑、肘折温泉、FMよみたん、三越前はり灸整骨院、TokyoJAM世田谷、
与論パラダイスビーチ、ひるがの高原、秋保温泉華乃湯、武蔵野の森、セレーノディプリマヴェーラ、
茂原早野。

## 画角・対象が違うため保留した7台

チャンネルは稼働しているが、台帳の地点と別の映像しか無いもの。**運営者に新しい該当枠が
できたか要再確認**。安易に差し替えると別地点の映像を出すことになるため保留した。

| ID | 名称 | 現行ライブ |
|---|---|---|
| `curated-lcdb-582d11a4` | 浜松オートレース | 伊勢崎の中継のみ（浜松は開催日のみ配信） |
| `world-df40e70a` | サンティアゴ市街 | Ledrium の別地点4本（Providencia/Costanera/Los Leones ほか） |
| `curated-niseko-hirafu-annupuri` | ニセコグラン・ヒラフ（アンヌプリ側） | (.Base) と (Ace Hill Yotei Side) のみ |
| `curated-ryukyushimpo-nahashiyakusho-mae` | 那覇市役所前交差点 | りゅうちゃんカメラ（国際通り・県庁前） |
| `curated-r2-7c0fa32e` | 富士山頂 東向き（ご来光） | 山麓・太郎坊カメラのみ（山頂は夏季のみ運用） |
| `curated-r2-db7d489e` | 富士山頂 西向き | 同上 |
| `curated-teiten-ryugudori` | 国際通り 竜宮通り入口 | 牧志交番前定点カメラ |

## チャンネルにも現行ライブが無い48台

深夜（8/31 22〜23時台）と夕方（9/1 19時台）の2回とも配信なし。ただし**まだ退役にはしていない**。
性質上、時間帯・開催日での停止と区別がつかないものが多いため:

- **開催日のみ**（競艇・競輪・競馬・野球大会など9台）: 平和島／びわこ／三国／佐賀競馬／前橋競輪／
  大沼球場／南幌カートランド／TeamCRC／アルカフェ — レース開催日に再開する。退役不可。
- **営業時間のみ**（美容室b1hair・サウナゆげ蔵・とらや店内・純水セルフ洗車・フラワーギャラリー・
  ラボットミュージアム・友泉亭公園・厚岸水鳥観察館・明覚寺・FMたまん・FM宝塚・エフエムいたみ など）:
  夕方19時台でも閉店後。**日中（平日10〜16時）の再確認が必要**。
- **冬季のみ**: 富良野スキー場 北の峰（LIVE_STREAM_OFFLINE）、蔵王温泉スキー場360度（2026-01-02終了）。
  シーズン前（11月）に再確認。
- **24時間配信をうたっているのに止まっているもの**（実際に停止の可能性が高い）:
  早来カントリー倶楽部「24時間ライブカメラ」、トランジットカフェ「24時間ライブカメラ」、
  赤石岳（椹島）、三瓶山 西の原、神恵内村、東北大学 青葉山、富士砂防事務所 CCTV、
  HBC大通公園、鴨川 前原海岸（2台）、天神崎、下呂温泉 水明館、彦根市大東町、米子市両三柳、
  高知龍馬空港 駐車場、塩原温泉ホテルおおるり、阿仁川、熊野那智大社 那智の瀧、
  流鉄流山線、浜崎海岸、セレクトちゃんねる上田市、三津浜港、どれみふぁ空、フォレストパーク神野山。
  → **日中の3回目の確認で復帰しなければ退役**とする。
- `curated-rito-chichijima`（父島 二見港）は再生リスト型でライブ判定が取れない。要目視。

## 恒久対策（未実施・提案）

YouTubeの配信枠は日次で切り替わる運営者が多く（スポーツセンター・整骨院・競艇・伊那谷など、
今回の36台の3分の1がこのパターン）、手動の一斉確認では追いつかない。
**週1回の自動スイープ**（`/streams` からタイトル一致で新IDへ自動追従し、一致しなかったものだけ
Issueで報告）をGitHub Actionsに載せるのが根本対策。1回あたり約2,700リクエスト・1req/sで45分程度。
