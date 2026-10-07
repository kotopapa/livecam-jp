# App Store「ヘッダ／検索結果」画像

デザイン指定は [DESIGN_HEADER.md](DESIGN_HEADER.md)（推奨A「日本の今が光る」）。

## 再生成

```bash
node store_screenshots/header_assets/render.mjs   # リポジトリ直下から。KEEP=1 を付けると out/_raw.png を残す
```

`site/lp/data.json`（国内の承認済みカメラ座標）を読み、`header.html` を Playwright で撮影する。
`header.html?guide=1` でセーフエリアの枠（ピンク破線=共通 / 黄=内側）を確認できる。
フォントは `fonts/DelaGothicOne-Regular.ttf`（SIL OFL、`fonts/OFL.txt`）。
カメラ台帳が増えたら `python site/build.py` で data.json を更新してから再生成する。

## 出力（out/）

| ファイル | 用途 |
|---|---|
| generic_5244x2950.png | 共通原稿（sRGB・アルファ無し） |
| header_3840x1646.png | 21:9 ヘッダ |
| search_3840x2560.png | 3:2 検索結果 |
| preview_*.png | 確認用（ガイド・幅390・左右12%上下13%を隠した厳しめ）。提出しない |

## 提出時の注意（DESIGN_HEADER.md 3章の要点）

- 価格・「無料」「登録不要」・割引・URL・©・受賞/ランキング・他社名/ロゴ・Appleバッジは入れない
- アプリ名・台数・機能一覧・英文ラベル・REC表示・飾り枠を足さない。文字は指定コピーのみ
- 全地点が常時リアルタイム配信という保証表現、行政公式に見える紋章、安全保証の表現は使わない
- 被災・事故・氾濫などの不安をあおる表現は使わない（4+相当）
- 光点はカメラ位置を示す表現であり、稼働状態や警報を表さない。架空の座標を足さない
- 提出前に App Store Connect の最新の素材要件と、実プレビューでの位置・重なりを確認する
