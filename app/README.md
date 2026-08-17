# Phase 4: モバイルアプリ（Flutter, iOS/Android）

仕様は [SPEC.md](../SPEC.md) 9章。Web版はこのディレクトリではなく `site/` の静的ページ（SPEC 9.0）。

## 前提

- 配信エンドポイントが稼働していること: `https://kotopapa.github.io/livecam-jp/v1/manifest.json`
- Flutter（Dart 3）/ iOS 17.0+ / Android 8.0+

## プロジェクト作成

```bash
cd app
flutter create --org jp.livecam --project-name livecam_jp .
```

## 実装順（SPEC 9章に対応）

1. データ層: `manifest.json` → `cameras.json` → `status.json` の取得・キャッシュ（オフライン動作必須、ETag対応）
2. 地図画面: flutter_map + 地理院タイル。カテゴリ別ピン色（8種）・クラスタリング。`error` は非表示、`frozen` は半透明
3. 詳細画面: `feed.type` 分岐（still_image / youtube_channel=IFrame / web_page）。取得時刻の大きな表示、`coord_accuracy` 表示
4. アクセス制御: 再取得最短60秒（変更不可）、同時接続3、If-None-Match、画面外は取得しない（SPEC 9.4）
5. お気に入り（一括更新は順次・同時3）・検索・絞り込み
6. 免責・出典表示（SPEC 9.5。オンボーディングと詳細画面フッター。削ってはいけない）
7. ウィジェット: 各OSネイティブ実装 + `home_widget` 連携（仕上げ段階）

## 依存パッケージ（採用理由を明記して最小限に保つ）

| パッケージ | 用途 |
|---|---|
| `flutter_map` | 地図表示（地理院タイル。Google Maps SDKは課金アカウントが必要なため不使用） |
| `youtube_player_iframe` | YouTube再生（IFrame Player API準拠 = SPEC C6遵守） |
| `shared_preferences` / `sqflite` | お気に入り・キャッシュメタの永続化 |
| `home_widget` | ネイティブウィジェットとのデータ連携（仕上げ段階で追加） |

追加する場合はこの表に用途を書き足すこと。

## 配信エンドポイント

`lib/config.dart` 等に `https://kotopapa.github.io/livecam-jp/v1/` を定数として持たせる。
