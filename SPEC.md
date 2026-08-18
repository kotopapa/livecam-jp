# 全国ライブカメラ地図アプリ — 実装仕様書

> このドキュメントは Claude Code が単独で実装を進められることを目的に書かれている。
> 不明点が出た場合は「11. 判断が必要になったときのルール」に従うこと。

---

## 0. TL;DR（最初に読む3行）

1. 官公庁が公開している全国のライブカメラを **クローラで台帳化** し、**死活監視して静的JSONで配信** し、**アプリ（iOS / Android / Web）が地図に表示する**。
2. ランニングコストは **ドメイン代のみ**。有償API・有償データ配信サービスは一切使わない。画像/映像は自前サーバーを経由させず、端末から一次ソースへ直接取りに行く。
3. 差別化の核は「カメラ数」ではなく **「開いたら必ず映る」= 死活監視** と **「今見る価値があるか」= オンデバイス画像判定**。ここを削ったらプロダクトの意味がなくなる。

---

## 1. プロダクト概要

### 1.1 解決する課題

日本のライブカメラは、国土交通省の各地方整備局・各国道事務所・各河川事務所・都道府県・市町村が**それぞれ独立したサイト**で公開しており、統一フォーマットも統一APIも存在しない。ユーザーは「今この川がどうなっているか」を見るために、毎回検索してサイトを渡り歩く必要がある。

既存のライブカメラアプリの最大の不満は **リンク切れ・映らないカメラが放置されていること**（App Storeの日本語レビューでも「常にリンクを監視して更新しないと意味がない」と指摘されている）。

### 1.2 プロダクトの約束

- 地図に出ているカメラは **必ず映る**（映らないものは自動的に地図から沈む）
- 画像には **必ず取得時刻** が添えられる（古い画像を「今」として見せない）
- **出典が必ず明示される**（どの機関のカメラかが分かる）

### 1.3 スコープ

**対象**: 官公庁カメラ（政府標準利用規約系）に加え、2026-08-18のオーナー決定により
**民間設置のライブカメラも条件付きで対象**とする（2026-08-18改訂: 個人運営を含む）:
- 公開YouTubeライブ配信であること（IFrame埋め込みが許可されているもの）
- 個人運営の場合は継続配信の実績があること（レビューで個別判断）
- feed は YouTube IFrame 経由のみ（C6と同じ。HLS抽出は絶対にしない）
- 運営者名を出典として明記し、削除依頼があれば即時対応する
- 発見はチャンネル・配信元の個別確認で行う（民間まとめサイトのクロールは引き続き禁止=C4）

**スコープ外（作らない）**:
- 海外カメラ
- 水位・雨量などの数値データ重ね合わせ（有償配信が必要なため）
- タイムラプス保存・録画（ストレージ課金が発生するため）
- プッシュ通知（監視バッチとAPNs運用が必要。v2で検討）
- ユーザー投稿カメラ（アプリ内投稿機能は作らない）

---

## 2. 絶対制約（これを破る実装は却下）

| # | 制約 | 理由 |
|---|---|---|
| C1 | **画像・映像を自前サーバーで中継しない**。アプリは一次ソースへ直接アクセスする | 転送量課金ゼロ。「再配信」ではなく「参照」となり法的にも軽い |
| C2 | **有償データサービスを使わない**（水防災オープンデータ提供サービス等） | 本プロジェクトの前提はコストゼロ運用 |
| C3 | **一次ソースへのアクセスは礼儀正しく**。静止画の再取得間隔は最短60秒、監視バッチは1カメラあたり最短30分。ETag / If-Modified-Since を必ず使う | 災害時に官公庁サーバーはアクセス集中で落ちる。そこに負荷を足すのは実害 |
| C4 | **robots.txt と各サイトの利用規約を尊重する**。民間まとめサイト（cametan.com 等）はクロール対象外 | 著作権・規約遵守 |
| C5 | **出典表示を省略しない**。台帳の全レコードに出典と規約URLを持つ | 政府標準利用規約／公共データ利用規約の条件 |
| C6 | **YouTube映像は IFrame Player 経由で再生**する。HLSを直接抜いてAVPlayerに流さない | YouTube利用規約 |

---

## 3. ライセンスの前提

### 3.1 官公庁コンテンツ

国の機関のウェブサイトのコンテンツは **政府標準利用規約（第2.0版）**、および2024年7月以降は後継の **公共データ利用規約（第1.0版）** の下で公開されている。要点：

- 複製・公衆送信・翻案が自由。**商用利用も可能**
- **CC BY 4.0 と互換**
- 条件は **出典の記載**
- 例外あり：「別のルールを適用するコンテンツ」がサイトごとに個別指定されている
- 外部API連携で取得しているコンテンツは、その提供元の利用条件に従う

→ **実装上の帰結**：クロール時に各サイトの利用規約ページのURLを必ず記録し、台帳に残す。規約が政府標準利用規約系でないサイトは `license: unknown` としてフラグを立て、**手動レビュー待ちキューに入れる**（自動で採用しない）。

### 3.2 官公庁のYouTubeチャンネル

一部の地方整備局・事務所はYouTubeで河川カメラをライブ配信している。チャンネル概要欄に「当公式YouTubeで公開している情報は複製、公衆送信、翻訳等、自由に利用できます（YouTube運用ポリシーに従うこと）」という趣旨の記載があるものが多い。

→ チャンネル概要欄のライセンス文言を取得して台帳に記録すること。

### 3.3 都道府県・市町村

自治体ごとに利用規約が異なる。CC BY 相当のものが多いが、**必ず個別確認**。自動判定できない場合は `license: unknown` で手動レビュー行き。

---

## 4. リポジトリ構成

モノレポ。

```
livecam-jp/
├── SPEC.md                     # このファイル
├── crawler/                    # Phase 1: カメラ台帳の収集（Python 3.12）
│   ├── sources/                # ソース別のパーサ（1ファイル1機関）
│   │   ├── base.py
│   │   ├── mlit_ktr.py         # 関東地方整備局
│   │   ├── mlit_qsr.py         # 九州地方整備局
│   │   ├── mlit_youtube.py     # 官公庁YouTubeチャンネル
│   │   ├── pref_kanagawa.py
│   │   └── ...
│   ├── seeds.yaml              # クロール起点URL一覧
│   ├── geocode.py              # 住所・河川名 → 緯度経度
│   ├── normalize.py            # 正規化・重複排除
│   ├── validate.py             # スキーマ検証
│   └── main.py
├── monitor/                    # Phase 2: 死活監視（Python 3.12）
│   ├── check.py
│   ├── freeze.py               # フリーズ判定
│   └── main.py
├── data/
│   ├── cameras.json            # カメラ台帳（人手レビュー済み・正）
│   ├── candidates.json         # クローラが見つけた未レビュー候補
│   ├── status.json             # 死活監視結果（バッチが自動更新）
│   └── schema/
│       ├── camera.schema.json
│       └── status.schema.json
├── site/                       # Phase 3: 静的配信（GitHub Pages）
│   └── v1/                     # 配信されるJSON群（ビルド生成物）
├── app/                        # Phase 4: モバイルアプリ（Flutter, iOS/Android）
│                               #   Web版は site/ の静的ページ
├── tools/
│   └── review_cli.py           # 候補レビュー用CLI
└── .github/workflows/
    ├── crawl.yml               # 週次
    ├── monitor.yml             # 30分ごと
    └── publish.yml             # data/ 変更時
```

---

## 5. データモデル

### 5.1 カメラ台帳 `cameras.json`

```jsonc
{
  "version": "2026-08-17T00:00:00Z",
  "cameras": [
    {
      "id": "mlit-ktr-tamagawa-denenchofu",   // 安定した一意ID。source_prefix + slug
      "name": "多摩川 田園調布（上）",
      "name_kana": "たまがわ でんえんちょうふ",
      "lat": 35.5942,
      "lng": 139.6647,
      "coord_accuracy": "exact",              // exact | approx | town_level | area（河川単位等の広域代表点）
      "category": "river",                    // river | road | volcano | dam | coast | port | scenic | healing(動物・星空等の癒し系) | other
      "prefecture": "13",                     // JIS X 0401 都道府県コード（文字列2桁）
      "municipality": "13111",                // JIS X 0402 市区町村コード（任意）
      "river_or_route": "多摩川",             // 河川名 or 路線名（任意）

      "feed": {
        "type": "still_image",                // still_image | youtube_channel | youtube_video | hls | web_page | mlit_roadinfo
        "url": "https://.../camera01.jpg",
        "refresh_sec": 300,                   // 一次ソース側の更新間隔（判明している場合）
        "requires_referer": false,            // Referer必須か
        "headers": {}                         // 必要な追加ヘッダ
      },

      "fallback": {
        "type": "web_page",
        "url": "https://www.ktr.mlit.go.jp/..."  // アプリ内で開く元ページ（feedが死んだとき用）
      },

      "operator": "国土交通省 関東地方整備局 京浜河川事務所",
      "source": {
        "page_url": "https://www.ktr.mlit.go.jp/keihin/keihin_index034.html",
        "terms_url": "https://www.ktr.mlit.go.jp/...",
        "license": "gov_std_2.0",             // gov_std_2.0 | public_data_1.0 | cc_by_4.0 | youtube_gov | unknown
        "attribution": "出典：国土交通省 関東地方整備局"
      },

      "review": {
        "status": "approved",                 // approved | pending | rejected
        "reviewed_at": "2026-08-17",
        "note": ""
      },

      "first_seen": "2026-08-01",
      "last_updated": "2026-08-17"
    }
  ]
}
```

**`feed.type` ごとのアプリ側の扱い：**

| type | 意味 | アプリの実装 |
|---|---|---|
| `still_image` | 定期更新される静止画URL | URLSession で取得。最短60秒間隔。ETag対応 |
| `mlit_roadinfo` | 道路情報提供システム（road-info-prvs.mlit.go.jp）の都度解決型カメラ。`url` は解決元ページ、`camera_ref` に管理ID。**静止画の固定URLが存在しない**（15分刻みタイムスタンプ付き・直近3世代のみ） | アプリは `status.json` の `image_url`（monitorが実行のたびに再解決して配信）を使う。取れないときは `fallback` の元ページへ誘導 |
| `youtube_channel` | チャンネルIDを保持。`url` は `UC...` のチャンネルID | `https://www.youtube.com/embed/live_stream?channel=<ID>` を WKWebView で読む。**動画IDが変わっても追従するのでAPIクォータ消費ゼロ** |
| `youtube_video` | 固定の動画ID | 同上（`embed/<videoId>`）。チャンネル方式が使えない場合のみ |
| `hls` | 公開されているHLSのm3u8 | AVPlayer。**YouTube由来のものは絶対にここに入れない** |
| `web_page` | 個別取得できずページごと開くしかない | SFSafariViewController で開く。地図には出すが「アプリ内再生非対応」バッジを付ける |

### 5.2 死活監視結果 `status.json`

台帳とは別ファイルにする（更新頻度が違うため）。

```jsonc
{
  "generated_at": "2026-08-17T06:00:00Z",
  "statuses": {
    "mlit-ktr-tamagawa-denenchofu": {
      "state": "ok",              // ok | frozen | error | unknown
      "last_ok_at": "2026-08-17T05:58:00Z",
      "http_status": 200,
      "frozen_since": null,       // frozen のとき、いつから同一画像か
      "consecutive_failures": 0,
      "avg_interval_sec": 300,    // 実測した更新間隔（アプリのポーリング間隔決定に使う）
      "image_url": null,          // 都度解決型feed（mlit_roadinfo）のみ: monitorが解決した最新静止画URL
      "image_time": null          // image_url の画像取得時刻（提供元申告）
    }
  }
}
```

**アプリの表示ルール：**
- `ok` → 通常表示
- `frozen`（6時間以上同一画像） → 地図上でグレー表示。詳細画面に「画像が更新されていません」を表示
- `error`（連続3回以上失敗） → **地図に出さない**
- `unknown` → 通常表示するが「状態未確認」

---

## 6. Phase 1 — クローラ（`crawler/`）

### 6.1 目的

全国の官公庁ライブカメラを発見し、`candidates.json` に構造化して書き出す。**自動で `cameras.json` に入れてはいけない。必ず人手レビューを挟む。**

### 6.2 クロール起点（`seeds.yaml`）

以下を初期シードとする。各シードは「リンク集ページ」なので、そこから1階層下の各事務所ページを辿る。

```yaml
seeds:
  # 全国横断のリンク集
  - id: mlit_road_national
    url: https://www.mlit.go.jp/road/bosai/LIVEcamera.html
    note: 全国の道路ライブカメラのリンク集。各地方整備局・都道府県へのハブ
    depth: 2

  - id: kawa_bousai
    url: https://www.river.go.jp/
    note: 川の防災情報。JS必須のためレンダリングが必要
    depth: 1
    render: true

  # 地方整備局（河川）
  - id: mlit_ktr_river
    url: https://www.ktr.mlit.go.jp/guide/guide00000012.html
    depth: 2
  - id: mlit_qsr_river
    url: http://www.qsr.mlit.go.jp/useful/river_livecam.html
    depth: 2
  - id: mlit_kkr_river
    url: https://www.kkr.mlit.go.jp/river/bousai/livecamera.html
    depth: 2
  - id: mlit_cgr_river
    url: http://river-livecam.cgr.mlit.go.jp/
    depth: 1
  - id: mlit_thr_river
    url: https://www.thr.mlit.go.jp/bumon/b00037/k00290/river-hp/kasen/livecamera/index.html
    depth: 2

  # 官公庁YouTube配信（優先度: 最高）
  - id: mlit_qsr_youtube
    url: http://www.qsr.mlit.go.jp/useful/kasen_youtube.html
    parser: mlit_youtube
    depth: 1

  # 自治体オープンデータ（CKAN）
  - id: opendata_ckan
    parser: ckan_search
    endpoints:
      - https://opendata-api-kakogawa.jp/ckan/api/3/action/package_search
    query: "河川監視カメラ OR ライブカメラ"
```

**シードは足りない。** クローラ実装後、以下を自分で拡張すること：
- 残りの地方整備局（北海道開発局・東北・北陸・中部・四国・沖縄総合事務局）
- 47都道府県の河川防災情報システム・道路情報提供システム
- 火山監視カメラ（気象庁・砂防事務所）

**除外リスト（クロールしない）：**
- 民間のライブカメラまとめサイト全般（著作権・規約上NG）
- 個人・企業が設置したカメラ（v1では扱わない）
- ログインが必要なもの

### 6.3 各パーサが返すもの

`sources/base.py` に以下のインターフェースを定義する。

```python
class SourceParser(ABC):
    source_id: str
    seed_url: str

    @abstractmethod
    def discover(self, session: HttpSession) -> list[CameraCandidate]:
        """このソースからカメラ候補を列挙する。
        失敗しても例外を投げず、部分的な結果 + errors を返すこと。
        """
```

`CameraCandidate` は `cameras.json` のスキーマと同じ形だが、以下が未確定でよい：
- `lat` / `lng`（`geocode.py` が後段で埋める）
- `review.status` は常に `"pending"`

### 6.4 静止画URLの発見方法

HTMLからの発見は以下の順で試す：

1. `<img src>` で拡張子が `.jpg`/`.png` かつ URLに `cam`, `live`, `camera`, `cctv` を含むもの
2. JavaScriptで定期リロードしているURL（`setInterval` の周辺のURL文字列）
3. `<iframe src>` の中身を再帰的に見る
4. ネットワークリクエストの観測（Playwright使用時）

**発見したURLは必ず2回、5分あけて取得して検証する：**
- 2回とも200が返るか
- 2回の画像のハッシュが**異なる**か（同じならフリーズしているか静止画バナー）
- Content-Type が image/* か
- 画像サイズが極端に小さくないか（< 5KB は「準備中」画像の可能性）

この検証を通らないものは `review.note` に理由を書いて `pending` のまま残す。

### 6.5 YouTubeチャンネルの扱い

1. ページ内の `youtube.com/channel/UC...` / `youtube.com/@handle` / `youtu.be/...` を抽出
2. ハンドル形式ならチャンネルページを取得して `UC...` 形式のIDに解決する（**YouTube Data APIは使わない**。ページ内の `channelId` メタタグから取得する）
3. チャンネル概要欄のテキストを取得し、ライセンス文言があれば `source.attribution` に記録
4. `feed.type = "youtube_channel"`, `feed.url = "UCxxxx"` として登録

**重要**：1チャンネル = 1カメラとは限らない。複数カメラを1チャンネルで切り替え配信している場合があるので、チャンネル名・配信タイトルから判断し、曖昧なら `pending` にする。

### 6.6 座標の解決（`geocode.py`）

ここが最大の手作業ポイント。以下の優先順で解決する：

1. **ページ内に緯度経度がある**（地図表示しているサイトはJSに埋まっていることが多い）→ `coord_accuracy: exact`
2. **自治体オープンデータのCSV/APIに座標がある** → `coord_accuracy: exact`
3. **住所が明記されている** → 国土地理院ジオコーディングAPI（`https://msearch.gsi.go.jp/address-search/AddressSearch?q=<住所>`、無料・出典表示要）→ `coord_accuracy: approx`
4. **河川名＋観測所名しかない** → 解決せず `pending`。手動レビューで埋める

ジオコーディングAPIへのアクセスは **1秒に1回以下**。結果は必ずローカルキャッシュ（`crawler/.cache/geocode.json`）し、再実行時に再問い合わせしないこと。

**座標が取れないカメラを推測で埋めてはいけない。** 防災用途で位置が間違っているのは致命的。`pending` のまま残す方が正しい。

### 6.7 重複排除（`normalize.py`）

同じカメラが複数のリンク集に出てくる。以下で名寄せする：

1. `feed.url` の完全一致 → 同一
2. 緯度経度が50m以内 かつ カメラ名の正規化後の類似度が0.8以上 → 同一候補として `review.note` に併記し `pending`
3. 自動マージは `feed.url` 完全一致のときのみ

カメラ名の正規化：全角→半角、カッコ内除去、「ライブカメラ」「（上流）」等の接尾辞を分離。

### 6.8 レビューCLI（`tools/review_cli.py`）

`candidates.json` を1件ずつ表示し、`cameras.json` へ承認・却下する対話ツール。

表示すべき情報：
- カメラ名、運営者、出典URL
- 取得した画像のプレビュー（ターミナルにサムネイル or ローカルHTMLを開く）
- 解決された座標を地図URL（`https://maps.google.com/?q=lat,lng`）で開けるように
- 検証結果（画像が変化したか、サイズ、Content-Type）

操作：`a` 承認 / `r` 却下 / `e` 編集 / `s` スキップ / `q` 終了。承認したものだけ `cameras.json` へ移す。

### 6.9 クローラの実行

```bash
# 全ソースを回して candidates.json を更新
python -m crawler.main --all

# 特定ソースのみ
python -m crawler.main --source mlit_ktr_river

# ドライラン（書き込まない）
python -m crawler.main --all --dry-run
```

GitHub Actions で **週次実行**（`.github/workflows/crawl.yml`）。差分が出たら PR を自動作成する（直接 main にコミットしない）。

---

## 7. Phase 2 — 死活監視（`monitor/`）

### 7.1 実行頻度と負荷制御

- GitHub Actions で **30分ごと** に実行
- 1回の実行で全カメラをチェックするが、**同一ホストへの同時接続は2、リクエスト間隔は1秒以上**
- タイムアウト10秒、リトライ1回
- User-Agent に連絡先URLを含める：`LiveCamJP-Monitor/1.0 (+https://github.com/<user>/livecam-jp)`
- `If-None-Match` / `If-Modified-Since` を必ず送る

カメラ数が増えて1実行に収まらなくなったら、カメラをN群に分割して巡回すること（全カメラの最低チェック間隔は1時間を維持する）。

### 7.2 判定ロジック

**`still_image` の場合：**

```
取得成功 かつ Content-Type が image/*
  → 画像の知覚ハッシュ（dHash 64bit）を計算
  → 直近の履歴（最大48件、= 24時間分）と比較
  → 全て同一ハッシュ かつ 最古の記録から6時間以上経過 → frozen
  → それ以外 → ok
取得失敗（4xx/5xx/timeout）
  → consecutive_failures++
  → 3回連続で error
```

夜間は真っ暗な画像が続くため誤って `frozen` 判定されやすい。**日の出前後（各カメラ座標での日の出時刻±1時間）を跨いだ比較でのみ frozen 判定する**こと。

**`youtube_channel` の場合：**

`https://www.youtube.com/embed/live_stream?channel=<ID>` を取得し、レスポンスHTMLに配信中を示す情報が含まれるか確認する。含まれなければ `error`。
（YouTube Data API は使わない。クォータを消費しないこと）

**`web_page` の場合：**

ページのHTTPステータスのみ確認。200なら `ok`。

### 7.3 履歴の保持

ハッシュ履歴は `monitor/.state/hashes.json` に保持し、リポジトリにコミットする（GitHub Actions は実行間で状態を持たないため）。48件を超えたら古いものから捨てる。**画像そのものは保存しない**（著作権・容量の両面で）。

---

## 8. Phase 3 — 配信（`site/`）

### 8.1 エンドポイント

GitHub Pages（または Cloudflare Pages）で静的配信する。

| パス | 内容 | 更新頻度 | Cache-Control |
|---|---|---|---|
| `/v1/manifest.json` | 各ファイルのバージョンとURL | 台帳変更時 | `max-age=300` |
| `/v1/cameras.json` | 承認済みカメラ全件（gzip） | 台帳変更時 | `max-age=3600` |
| `/v1/cameras/<prefCode>.json` | 都道府県別（分割配信） | 同上 | `max-age=3600` |
| `/v1/status.json` | 死活監視結果 | 30分ごと | `max-age=300` |

`manifest.json`：

```jsonc
{
  "schema_version": 1,
  "cameras": { "version": "2026-08-17T00:00:00Z", "url": "/v1/cameras.json", "count": 1842 },
  "status":  { "version": "2026-08-17T06:00:00Z", "url": "/v1/status.json" },
  "min_app_version": "1.0.0",
  "notice": null   // 緊急告知があれば文字列。アプリ上部にバナー表示
}
```

`notice` は運用の逃げ道として重要。仕様変更や障害時にアプリを更新せずユーザーに伝えられる。

### 8.2 アプリの取得戦略

- 起動時：`manifest.json` のみ取得（軽い）
- `cameras.version` が手元と違えば `cameras.json` を取得して差し替え
- `status.json` は起動時 + 5分以上経過していれば再取得
- いずれも失敗したらローカルキャッシュで動作を継続する（**オフラインでも地図とカメラ一覧は見える**）

---

## 9. Phase 4 — アプリ（`app/` / `site/`）

### 9.0 プラットフォーム方針

| プラットフォーム | 実装 | 置き場所 |
|---|---|---|
| iOS / Android | **Flutter** 単一コードベース | `app/` |
| Web | **静的ページ**（MapLibre GL JS + 地理院タイル）。Flutter Webは使わない（バンドルが重く地図用途に不向き） | `site/`（GitHub Pagesで配信JSONと同居） |
| ホーム画面ウィジェット | 各OSネイティブ（iOS: WidgetKit / Android: AppWidget）。`home_widget` でFlutter側とデータ連携 | `app/` 内 |

Web版は最小構成（地図＋詳細表示）とし、先行してデータ配信の実地検証を兼ねる。

### 9.1 技術スタック

- Flutter（Dart 3）/ iOS 17.0+ / Android 8.0+
- 地図：**flutter_map + 地理院タイル**（国土地理院。出典表示のみで無料）。Google Maps SDKは使わない（課金アカウントが必要なため）
- 永続化：軽量なもの（お気に入り・キャッシュメタが対象。sqflite / shared_preferences 程度）
- 画像キャッシュ：取得時刻メタ・ETagを持つ自前ディスクキャッシュ
- YouTube再生：`youtube_player_iframe`（IFrame Player API準拠 = C6遵守）
- 依存パッケージ：**実績のあるものを最小限**。採用理由を `app/README.md` に列挙する
- Web版：ビルド不要のプレーンなHTML/JS 1ページ + MapLibre GL JS。画像は `<img>` の直接参照（一次ソースはCORSヘッダを返さないため、JSからのfetchはしない。キャッシュはブラウザ任せ）

### 9.2 画面構成

**① スプラッシュ / オンボーディング（初回のみ）**

- アプリの約束（映らないカメラは自動で非表示 / 取得時刻を必ず表示 / 出典を必ず明示）
- **免責（9.5）をオンボーディングの最終ページで必ず表示する**。スキップしても免責は飛ばせない
- 「必ず映る」と言い切る表現は使わない（`frozen` は表示されるため）

**② 地図画面（メイン）**

- 全国の承認済みカメラをピン表示。**カテゴリ別のピン色**（河川=青、道路=灰、火山=赤、ダム=緑、海岸=水色、港湾=紫、景観=橙、癒し=ピンク、その他=茶）
- ズームレベルに応じてクラスタリング（件数バッジ）
- `status.state == "error"` のカメラは**表示しない**
- `frozen` はピンを半透明にする
- **位置未確定（`coord_accuracy` が `exact` 以外）のピンは色で区別する**（黄色の縁取り等）。`area` は河川単位の代表点であることを詳細画面にも明示する
- 現在地ボタン、検索バー、絞り込み、都道府県ジャンプ
- ピンをタップ → 下部にプレビューカード（サムネイル + 名前 + 運営者 + 取得時刻 + お気に入り）→ タップで詳細画面

**③ 詳細画面**

- 画像/映像の表示（`feed.type` による分岐。still_image=画像 / youtube_channel=IFrame Player + 「YouTubeで見る」「チャンネルページを見る」導線 / web_page=外部ブラウザ）
- **取得時刻を必ず大きく表示**（「3分前」ではなく「06:12 取得」と絶対時刻も出す）
- 手動更新ボタン（**最短60秒のクールダウンを強制**。間隔はユーザーが変更できない）
- 出典表示（運営者名 + 元ページへのリンク）
- `coord_accuracy` が `exact` 以外は「位置はおおよそ」と明示する
- お気に入り追加
- 共有（画像ではなく**元ページのURL**を共有する。画像の再配布はしない）
- 近くのカメラ（半径10km以内を距離順に）
- **フッターに免責（9.5）を常設**

**④ 一覧・検索・絞り込み**

- 一覧：サムネイル + 名前 + 運営者 + 取得時刻 + 現在地からの距離
- 検索：カメラ名・河川名・路線名・自治体名でインクリメンタルサーチ、現在地から近い順
- 絞り込み：カテゴリ（スキーマの8種）、都道府県、現在映っているもののみ、お気に入りのみ、YouTubeのみ

**⑤ お気に入り画面**

- 各カードにサムネイルと取得時刻
- 一括更新（順次取得。同時実行は3まで）

**⑥ 設定画面**

- 地図の表示設定、データ通信設定（Wi-Fiのみ等）
- このアプリについて、利用規約、プライバシーポリシー、OSSライセンス、**出典・ライセンス一覧（9.5）**
- **置いてはいけない項目**：更新間隔の変更（60秒固定）、プッシュ通知（1.3でスコープ外）

**⑦ 取得エラー画面**

- 表示中のカメラの取得に失敗したときの案内（再試行 / 地図に戻る）。考えられる原因を添える

**⑧ ウィジェット（ネイティブ実装）**

- お気に入り1台の最新画像 + 取得時刻
- 更新は15分間隔（システム都合で伸びることを前提に、画像に取得時刻を焼き込む）

**Web版（`site/`）**：②③相当の最小構成のみ。お気に入りは localStorage（任意）

### 9.3 オンデバイス画像判定

サーバーを使わず端末で完結させる。**外部モデルは不要**。以下は画像統計量だけで実装できる（Dartで自前実装。プラットフォーム共通）：

| 判定 | 手法 | 用途 |
|---|---|---|
| 夜間・真っ暗 | 平均輝度 < 閾値 かつ 輝度分散が小さい | 「今は暗くて見えません」バッジ |
| レンズ曇り・濃霧 | ラプラシアン分散（エッジ量）が低い | 「視界不良」バッジ |
| 積雪 | 高輝度・低彩度画素の比率 | 「雪」タグ、絞り込み |
| 夕焼け | 暖色系（H: 10-40°）の高彩度画素比率 + 日没時刻との一致 | 「今きれい」ランキング |

前回画像とのdHash差分で端末側のフリーズ検知もできる（`monitor/freeze.py` と同じアルゴリズム）。

**「今見る価値があるカメラ」ランキング**は、お気に入り + 現在地周辺のカメラに対してのみ計算する（全国分を端末で回さない）。

### 9.4 アクセス制御（重要）

一次ソースへの負荷を抑えるため、アプリ側で以下を**強制**する（Web版も同様）：

- 同一カメラの再取得は最短60秒（`status.avg_interval_sec` が判明していればそれに従う）
- 画面に見えていないカメラは取得しない
- バックグラウンドでの定期取得はしない（v1）
- 同時接続は3まで
- `If-None-Match` を送り、304 なら再ダウンロードしない（Web版はブラウザキャッシュに任せる）

### 9.5 表示上の必須要素

- **免責**：オンボーディング（初回起動時）と詳細画面のフッターに以下の趣旨を表示する。
  > カメラ映像は限られた範囲の状況を示すものです。カメラの性能上、光環境や気象条件により不鮮明になる場合があります。避難の判断は、水位情報・気象警報・自治体の避難情報に従ってください。本アプリは参考情報を提供するものです。
- **出典**：各カメラの詳細画面に運営者名と元ページリンク。設定画面に一括の出典一覧
- **地図タイルの出典**：地理院タイルの出典表示（「地理院タイル」等）を地図上に常時表示する

---

## 10. 判断が必要になったときのルール

Claude Code は以下に該当する場合、**自動で進めず必ず確認を求めること**：

| 状況 | 対応 |
|---|---|
| 利用規約が政府標準利用規約系でない／判別できないサイトを見つけた | `license: unknown` で `pending`。採用可否を人に聞く |
| クロール先が robots.txt で拒否している | クロールしない。人に報告 |
| 座標が確定できない | 推測で埋めず `pending` |
| 一次ソースが429/403を返し始めた | 即座にそのソースへのアクセスを停止し、レート設定を見直して人に報告 |
| 有償APIや課金サービスを使えば解決する | **使わずに**、代替案と諦める場合のトレードオフを提示する |
| 個人・企業設置のカメラを見つけた | 1.3の条件（公開YouTubeライブ・埋め込み可）を満たせば license=unknown で候補化し人手レビューへ。満たさなければ rejected |

**やってよいこと**：パーサの追加、シードの拡張、スキーマの後方互換な拡張、テストの追加、リファクタ。

**やってはいけないこと**：`cameras.json` への自動承認、画像の自前サーバーへの保存・中継、YouTube HLSの直接取得、レート制限の緩和、免責・出典表示の削除。

---

## 11. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| App Store審査でリンク集アプリ（Guideline 4.2）と判定される | リリース不可 | 死活監視・地図統合・オンデバイス判定という独自価値を審査メモで明示。単なるWebView羅列にしない |
| 官公庁サイトのHTML変更でパーサが壊れる | カメラが消える | パーサごとにテストHTMLをフィクスチャで保持。週次クロールで取得数が前回比80%を下回ったらCIを失敗させる |
| 災害時のアクセス集中で一次ソースに負荷 | 社会的な実害 | C3のレート制限。`notice` で緊急時に取得間隔を延ばす指示をアプリへ配れるようにする |
| カメラの位置が誤っている | 誤った避難判断 | 位置未確定（exact以外）はピン色と詳細画面で明示する。`area`（河川単位の代表点）は「おおよその位置」であることを必ず表示 |
| 台帳の整備が終わらない | リリースできない | 全国一斉を狙わない。都道府県単位で承認が終わった順に配信する（`cameras.json` は部分公開で構わない） |

---

## 12. 用語

- **一次ソース**：カメラを実際に運営・公開している機関のサーバー
- **台帳**：`cameras.json`。人手レビュー済みのカメラ定義の正
- **候補**：`candidates.json`。クローラの出力。未レビュー
- **frozen**：HTTPは成功するが画像が長時間変化していない状態
