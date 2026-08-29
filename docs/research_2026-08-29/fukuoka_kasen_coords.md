# 福岡県 河川防災情報 河川監視カメラ — 座標の出所と精度（2026-08-29）

## 結論

- **座標はサイト内にあった**。河川カメラ配置図 `http://doboku-bousai.pref.fukuoka.lg.jp/river2/map/mapItv_0.html`
  が iframe で読む静的GISデータ `/river2/map/data/gisItv_0.html`（Shift_JIS）に
  `const itvJson = {"date": 'YYYYMMDDHHMM', '<局番>': {"an": 局名, "rn": 河川名, "lat": ..., "lng": ...,
  "flag": 'itv_0', "flagStr": '通常', "time": ...}, ...}` として全局が埋め込まれている（10分更新）。
- 208局中 **207局に緯度経度あり**（`281 久保橋(久原川)` のみ lng 空欄 → lat=None で候補化、推測で埋めない）。
- **精度: exact**。根拠:
  - 値が DMS 由来の小数（例 33.584722222 = 33°35'05"）で県システムのマーカー実位置
  - 既存 cameras.json の同一局（kawabou 経由の県土整備事務所カメラ 24 局、福岡市カメラ 7 局）と 8〜130m で一致
  - 国土地理院 逆ジオコーダ（mreversegeocoder.gsi.go.jp）で 207 点の市区町村コードを照合 → 個別ページの「所在地」と **不一致 0**
- 動的サーブレット `bousaiweb.servletBousaiContents?...&style=itv_map_json`（配置図JSの `getMapItvDataUrl`）は
  `/pc/` が 404、`/river/` が空応答。静的化された gisItv_0.html が唯一の入手経路。

## 探索経路（再現用）

1. サムネイル一覧 `itv_table` の JS（init_telemeter.js / changeUrl.js）から静的URL定義を発見:
   `static_mapitv_nm = "/map/mapItv"` → `/river2/map/mapItv_0.html`
2. mapItv_0.html 内 `frameURL = "./data/gisItv_0.html"` → GISデータ本体
3. 水位観測所の GIS（`gisRiver_0_1.html`、159局）は局番体系がカメラと別で照合不可（カメラ 4=山王橋 vs 水位 4=なし）
4. 所在地（市区町村）は `/river2/camera/detail_<局番>.html` の「所在地」（例: 福岡市博多区、行橋上稗田、須惠町）。
   JIS X 0402 は `crawler/sources/fukuoka_kasen.py` の MUNI_JIS 表で変換（異体字「惠」・「市」抜け表記を吸収）

## 画像

- `/camera/<YYYYMMDD>/<局3桁>/<局3桁>_<YYYYMMDDHHMM>_VGA.jpg`（640x480、37〜61KB。QQV=160x120 サムネイル）
- 時刻は itvJson の `"date"`（全局共通。itv_table の obstime と同値）。detail ページの `obstime` は水位データ時刻で画像時刻ではない
  （例: 局4 は detail 1600 / 画像 1605。局188 は detail が 2026-06-10 のまま＝観測停止中だが画像は 1605 が 200）
- 休止局（局名に「休止中」: 40 西縄手橋・46 串毛橋、および 241/238 など time が古い局）はその時刻の画像が 404 → monitor が error 判定
- https は TLS ハンドシェイク失敗。http で取得（アプリは ATS NSAllowsArbitraryLoads 済み）

## 実装

- `crawler/sources/fukuoka_kasen.py`（feed.type=`fukuoka_kasen`、都度解決型・gisItv_0.html 1リクエストで全台解決。
  monitor/main.py の bulk_resolvers に登録、check.py・schema・アプリ FeedType/imageUrlFor/detail_screen に配線）
- dry-run: 候補 208 件（座標あり 207、exact 207、スキーマNG 0）。クロールは gisItv 1 + detail 208 = 209 リクエスト（1req/s）

## 既存との重複候補（除外せず review_note に記載。NEAR_EXISTING 参照）

- kawabou-3102xxxxx（「川の防災情報」経由で採用済みの各県土整備事務所カメラ）24 局: 001 002 003 004 005 006 007 016 017 018 019 033 037 040 042 043 044 045 046 047 048 049 + 023(345m 同名)
  → 同一カメラの可能性大。レビューで kawabou 側と統合するか片方に寄せるか判断
- fukuoka-city-c2xx（福岡市防災気象情報）7 局: 001 002 003 004 005 007 023
- 別運営の近接（150m以内）: 169/171（宗像市道路カメラ）、195（久留米市鳥類センター）、204（筑後川千年分水路）、233（九州地整 重原）
