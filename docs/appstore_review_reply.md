# App Review「Guideline 2.1 - Information Needed」への回答一式

App Store Connect の「Reply」欄（および今後の提出用に App Review Information → Notes）に貼り付ける英文と、
スクリーン録画の撮影手順をまとめたもの。2026-08-22作成。

---

## 1. スクリーン録画（ユーザー作業）

**実機（最新iOS）で撮影**し、Replyに添付する。設定 → コントロールセンターに「画面収録」を追加して撮影するのが簡単。

撮影シナリオ（3〜4分・この順で）:

1. ホーム画面からアプリを起動（起動から録画開始が必須要件）
2. **位置情報の許可ダイアログが出る場面を必ず収録**（初回起動時。既にインストール済みの場合は、設定→プライバシー→位置情報でアプリの許可を「次回確認」に戻すか、一度削除して再インストールしてから撮影）
3. 地図: 現在地中心の表示 → ピンをタップ → 詳細画面で静止画カメラの表示
4. 詳細画面: YouTubeライブのカメラを1つ開いて再生 → 「出典サイトを見る」ボタンを見せる → 「このカメラの不具合を報告」リンクをタップしフォームが開くところまで（送信は不要）
5. 凡例・絞り込みシート（カテゴリチップ・動画のみトグル）
6. 一覧タブ: 現在地から近い順の一覧 → 検索バーで「桜島」等を検索
7. 災害速報タブ: 都道府県 → 市区町村 → カメラ一覧の2段導線
8. お気に入り: カメラをお気に入り登録 → お気に入りタブで表示 → ランキング画面
9. 設定タブ: 特別警報Push通知の都道府県選択画面を開く

- アカウント登録/ログイン/課金/サブスクリプションは**存在しない**ので撮影不要
- ユーザー生成コンテンツも**存在しない**（不具合報告はGoogleフォームへの外部リンク）

## 2. App Store Connect への回答英文（コピペ用）

以下をReply欄に貼る。●部分は実機情報に合わせて書き換えること。

---

Thank you for reviewing our app. Please find the requested information below.

**1. Screen recording**
A screen recording captured on a physical device (●iPhone 15 Pro, iOS ●18.x) is attached. It begins at app launch and shows the typical user flow: the location permission prompt, the nationwide camera map, opening still-image and YouTube live cameras, category filtering, the distance-sorted list, the disaster-alert browser (prefecture → municipality → cameras), favorites/ranking, and the push-notification prefecture settings. The app has no account registration, no login, no purchases or subscriptions, and no user-generated content, so no such flows exist to record.

**2. Devices and OS tested**
- ●iPhone 15 Pro, iOS ●18.x (physical device, via TestFlight)
- iPhone 17 simulator, iOS ●26.x (development)
(●実際にテストした機種・OSに置き換える。複数あれば列挙)

**3. Purpose and target audience**
The app is a free map of 15,000+ publicly available live cameras across Japan (rivers, roads, coasts, ports, volcanoes, dams, scenery), plus a small curated set of world cameras. It helps residents check nearby rivers, coasts, and roads during heavy rain, typhoons, and tsunami advisories, and lets travelers check real-time conditions of destinations. Target audience: general public in Japan (rated 4+). The app aggregates links/images that government agencies and other operators already publish openly, in one convenient map UI.

**4. Setup and access instructions**
No setup, account, or credentials are required. Launch the app, allow location access (optional), and tap any pin on the map to view that camera. All features are available immediately to every user.

**5. External services used**
- Static data hosting: GitHub Pages (our own camera catalog and health-status JSON)
- Map tiles: GSI (Geospatial Information Authority of Japan) tiles for Japan; OpenStreetMap tiles for the world view
- Live camera imagery: fetched directly by the device from each operator's public server (e.g., Ministry of Land, Infrastructure, Transport and Tourism; Japan Coast Guard; prefectures and municipalities; research institutes; broadcasters). We do not proxy or re-host video/images.
- YouTube: official IFrame Player embeds for cameras streamed on YouTube (per YouTube Terms of Service)
- Weather warnings: Japan Meteorological Agency public JSON feeds
- Firebase: Crashlytics (crash reporting) and Cloud Messaging (optional emergency-warning push notifications). No ads, no payment processors, no authentication services, no AI services.

**6. Regional differences**
None. The app functions consistently in all regions. Content is Japan-focused but is identical for all users worldwide.

**7. Regulated industry / third-party material**
The app does not operate in a regulated industry. All camera imagery is publicly published by the respective operators (primarily Japanese national and local government agencies) and is displayed with attribution and a link to the operator's source page. Note that ATS (NSAllowsArbitraryLoads) is enabled solely because many government camera servers publish images over HTTP only (including IP-address-only disaster cameras); the app sends no user data over HTTP. YouTube content is played only via the official IFrame embed API. We honor takedown requests via an in-app report/contact form on every camera's detail page, and we remove cameras promptly upon an operator's request.

---

## 3. 今後の提出用メモ

- 上記2〜7は App Review Information → **Notes欄にも恒常的に記載**しておく（Appleの要望）
- スクリーンショットは実機の実画面を使用（タイトルアートのみは不可）
- 位置情報のPurpose string は設定済み: 「現在地周辺のライブカメラを表示するために位置情報を使用します」
