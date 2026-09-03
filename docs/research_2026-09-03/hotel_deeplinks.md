# 宿泊予約サイトへの「カメラ周辺の宿」導線 調査（2026-09-03）

目的: カメラ詳細画面から周辺の宿へ誘導する。各社の検索URLが緯度経度を受けるか、バリューコマース(VC)経由で任意URL(vc_url)が最終ページまで届くかを curl で実測した。
検証座標: 河口湖 35.5036,138.7648 / 石垣 24.3400,124.1560。VC sid=3780235。

## 結論一覧
| サイト | VC広告スペースID | vc_url 持ち回り | 座標検索 | 実装に使う形 |
|---|---|---|---|---|
| じゃらん | 892691492 | ○（末尾に vos/caadsess 付与） | ×（Web版に緯度経度パラメータなし。旧APIは2020年新規終了） | キーワード検索 `uw/uwp2011/uww2011init.do?keyword=<Shift_JIS %エンコード>`（市区町村名・地名）。UTF-8 だと文字化けして0件になる |
| JTB | 892691495 | ○（jtb.co.jp/affiliate/vcurl_entry.asp 経由で lat/lng/sort が保持される） | ○（サイト自身のナビリンクが `lat=&lng=&sort=location`(距離が近い順) を持ち回る） | `kokunai-hotel/list/<県ローマ字>/?lat=&lng=&sort=location&dateunspecified=1&room=1&roomassign=m2&staynight=1`。**県パスが必須**（`/list/?lat=` は全国ランキングになる）。並び順はJSで描画されるため距離順は実機で要確認 |
| エクスペディア | 892691493 | ○（eapid/affcid が付与） | ○（`Hotel-Search?latLong=<lat>,<lng>`。bot には 429 のため実機確認） | 海外カメラ向け。国内は他社優先 |
| Yahoo!トラベル | 892691497 | ○（`?ikCo=y_ValueComm` 付与） | ×（SPA。検索URLは公開されていない） | エリアページ `https://travel.yahoo.co.jp/<地方>/<エリアコード>/`（`/api/sitemap/area` に2,194 URL。8桁コード=1,663エリア。例 okinawa/36205001=石垣島、koshinetsu/21052202=軽井沢）。カメラ→エリアの対応表を作る必要あり |
| るるぶトラベル | 892691503 | ○（`?cid=1838590` 付与） | 不明（Expedia系プラットフォーム。`/search` はSPA、Googlebot に Disallow） | `https://www.rurubu.travel/area/japan/<県>/<エリア>`（sitemaps.xml pagetype_6 に1,178 URL、例 yamanashi/otsuki）。対応表が必要 |
| 楽天トラベル | VC に無し（アフィリエイト抜きで実装） | ― | ○ | 下記 |

## 楽天トラベル（座標検索URL・実測OK）
スマホ版「現在地から探す」の JS（trv.r10s.jp/share/themes/ds/smart/js/area.js）が組み立てる URL をそのまま使う。
- 座標は **日本測地系の秒**（f_ido=緯度, f_kdo=経度）。WGS84 からの変換式は同 JS のもの:
  `ido = 3600*(1.000106961*lat - 0.000017467*lng - 0.004602017)`、`kdo = 3600*(1.000083049*lng + 0.000046047*lat - 0.010041046)`（小数2桁切り捨て）
- `https://search.travel.rakuten.co.jp/ds/vacant/searchVacant?f_ido=127801.33&f_kdo=499564.5&f_landmark_name_id=APP_NGPS&f_km=2.0&f_adult_su=1&f_otona_su=1&f_heya_su=1&f_kin2=1&f_sort=hotel&f_image=1&f_hyoji=10&f_page=1&f_nen1=2026&f_tuki1=10&f_hi1=10&f_nen2=2026&f_tuki2=10&f_hi2=11`
  → 河口湖 2km で 39件、石垣で 60件（パンくずに「…周辺」）。**日付が必須**（空だと 400）。日付未定の `/ds/yado/list/?f_ido=` は0件。
- PC 地図: `https://web.travel.rakuten.co.jp/portal/my/rt_map.main?f_ido=&f_kdo=`（地図UI。スマホ向きではない）

## じゃらん補足
- 実測: 石垣市 71件 / 富士河口湖町 318件 / 名護市 744件 / 伊江島 12件 / 西表島 20件。地名の部分一致なので「東村」は東村山等も混ざる（15件）
- エリア固定ページ `https://www.jalan.net/<県コード>0000/LRG_<大エリア>/`（例 150000/LRG_150300 = 大月・都留）は ASCII で扱いやすいが、大エリア一覧は `/ikisaki/map/<県>/` に3〜4件しか載っておらず要収集
- Shift_JIS のパーセントエンコードは Dart 標準に無いので、**配信JSON側（build.py）で市区町村ごとに事前生成**して持たせる
- VC 経由の最終URL例: `https://www.jalan.net/uw/uwp2011/uww2011init.do?caadterm=3600&vos=afjlnpvczzzzx00002010&keyword=%95x%8Em...&convertedFlg=1`

## VC の挙動メモ
- referral → `atrrd.valuecommerce.com/resolve` → `vcentry3.valuecommerce.com/.../entry.php?VIEW_URL=<固定LP>&vc_url=<指定URL>` → 広告主側で vc_url へ最終遷移。VIEW_URL が固定LPなのは正常で、vc_url が優先される（Yahoo!ショッピングと同じ）
- jalan/JTB/Expedia/Yahoo/るるぶ とも、指定した vc_url に到達することを確認（追加パラメータ付与）。**アプリ内では外部ブラウザで開く**（VC アプリメディア留意事項）

## 実装方針（案）
1. 対象カテゴリは scenic / coast / volcano / healing / port 等の観光系のみ。river / road / dam では出さない。県内に警報が出ている間は非表示
2. 国内: 楽天(座標) ＋ JTB(座標・県パス) ＋ じゃらん(市区町村キーワード) を横並び。Yahoo/るるぶは対応表が要るので第2段階
3. 海外カメラ: エクスペディア `latLong`
4. 有効化は products.json の merchants と同じ配信フラグ方式にし、審査状況に応じて切替
