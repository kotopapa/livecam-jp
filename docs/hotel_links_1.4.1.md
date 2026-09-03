# カメラ詳細「この付近の宿を探す」（1.4.1）

観光目的で見られるカメラの詳細画面に、周辺の宿を探す導線を置く。調査記録は
[research_2026-09-03/hotel_deeplinks.md](research_2026-09-03/hotel_deeplinks.md)。

## 表示条件
- カテゴリが scenic / coast / volcano / healing の国内カメラ、または海外カメラ（カテゴリ不問）。
  河川・道路・ダム・港湾・その他には出さない（氾濫中の川の横に宿の広告を出さない）
- **利用者が特別警報（レベル5）の発表エリアに居る間**は伏せる（広告と同じ規則。
  `AppState.viewerInSpecialWarningArea`）。カメラの所在地では判定しない: 県外の人が警報エリアの
  カメラを見るのは普通で、復旧期には宿を出した方が支援につながる（2026-09-03 ユーザー決定）。
  現在地は `data/viewer_area.dart`（許可済みの最終既知位置→国土地理院 逆ジオコーダで県コード）。
  発表中だけ求める。**現在地が分からない人（位置情報オフ・海上・国外・取得失敗）には無条件で出す**
  （警報時ほどアクセスが増えるため。伏せるのは位置が取れていて発表エリアに居る人だけ）
- 座標が無いカメラには出さない
- リンクは外部ブラウザで開く。アフィリエイトの明示は画面には出さず、利用規約（site/terms.html 第6条）と
  プライバシーポリシー第5条で行う（2026-09-03 ユーザー判断）

## サイトと URL（`app/lib/data/hotel_links.dart`・`app/lib/config.dart` の `hotelSites`）
| サイト | 対象 | URL | VC広告スペースID |
|---|---|---|---|
| じゃらん | 国内 | `uw/uwp2011/uww2011init.do?keyword=<市区町村名(Shift_JIS)>` | 892691492 |
| 楽天トラベル | 国内 | `ds/vacant/searchVacant?f_ido=&f_kdo=&f_km=3.0&…`（日本測地系の秒。JSTの明日から1泊） | なし（導線のみ） |
| JTB | 国内 | `kokunai-hotel/list/<県ローマ字>/?lat=&lng=&sort=location&dateunspecified=1…` | 892691495 |
| Expedia | 海外 | `Hotel-Search?latLong=<lat>,<lng>&adults=2` | 892691493 |

- じゃらんの検索語は **Shift_JIS のパーセントエンコード**限定（UTF-8 は0件）。Dart に Shift_JIS が無いので
  `tools/hotel_keywords.py` が気象庁 area.json（class20s）から `app/assets/data/municipalities.json`
  （JIS 5桁 → [名称, エンコード済み検索語]、1,756件・74KB）を生成してアプリに同梱する。
  政令市の区コードは市（`XX100`）に丸めて引く。市町村合併があれば再生成する
- 楽天の座標変換式は楽天スマホ版の JS（`share/themes/ds/smart/js/area.js`）のものをそのまま使う
- JTB は県パスが必須（全国パスに座標を付けても効かない）。距離順の並びは JS 描画のため**実機で確認**
- Expedia は bot に 429 を返すため curl では結果を確認できていない。**実機で確認**

## 有効・無効の切替（アプリ更新不要）
`data/stockpile/products.json` の `merchants` に `jalan` / `rakuten_travel` / `jtb` / `expedia` を追加した。
備蓄品の店舗と同じ仕組みで、`enabled` を変えて publish すると `AffiliateLinks.remoteFlags` 経由で
`HotelLinks.sites` に反映される（詳細画面を開いたときにアプリ起動中1回だけ取得）。
取得できないときは `config.dart` の `enabled` が既定値。

## 実機テストで見るところ（リリース前）
1. 観光系カメラ（例: 河口湖・石垣島）で4サイトのうち3つ（じゃらん・楽天トラベル・JTB）が出る
2. 各ボタンが外部ブラウザで開き、カメラ周辺の宿一覧になる（JTB は「距離が近い順」、楽天は「…周辺」）
3. 海外カメラで Expedia が出て、地図がカメラ周辺になる
4. じゃらんの一覧が市区町村名の検索結果になる（文字化けしていない）
5. 河川・道路カメラには出ない
6. VC の管理画面でクリックが計上される（アプリメディア留意事項）

## テスト
- `app/test/hotel_links_test.dart`（URL・測地系変換・対象カテゴリ・配信フラグ・同梱アセット）
- `app/test/detail_test.dart`（表示・警報中の県で伏せる・防災カメラには出ない）
- `tools/tests/test_hotel_keywords.py`
