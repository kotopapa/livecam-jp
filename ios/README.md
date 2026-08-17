# Phase 4: iOSアプリ

このディレクトリはXcodeで開発する。仕様は [SPEC.md](../SPEC.md) 9章。

## 前提

- M2完了（GitHub Pagesで `/v1/manifest.json` が配信されている）が着手条件
- Swift 6 / SwiftUI / iOS 17.0+ / 依存パッケージ原則ゼロ

## プロジェクト作成手順

1. Xcode → New Project → iOS App
   - Product Name: `LiveCamJP`（このフォルダ `ios/LiveCamJP/` に配置）
   - Interface: SwiftUI / Language: Swift
2. Capability: 位置情報（現在地ボタン用、When In Use）
3. ターゲット: iOS 17.0

## 実装順（SPEC 9章に対応）

1. データ層: `manifest.json` → `cameras.json` → `status.json` の取得・SwiftDataキャッシュ（オフライン動作必須）
2. 地図画面: MapKit `Map` + `Annotation` + `MKClusterAnnotation`。`error` は非表示、`frozen` は半透明
3. 詳細画面: `feed.type` 分岐（still_image=URLSession / youtube=WKWebView IFrame / web_page=SFSafariViewController）
4. アクセス制御: 再取得最短60秒、同時接続3、If-None-Match、画面外は取得しない（SPEC 9.4）
5. お気に入り・検索・ウィジェット・オンデバイス画像判定（SPEC 9.3）
6. 免責・出典表示（SPEC 9.5。削ってはいけない）

## 配信エンドポイントのURL

`Config.swift` 等に `https://kotopapa.github.io/livecam-jp/v1/` を定数として持たせる。
