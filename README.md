# livecam-jp — 全国ライブカメラ地図アプリ

官公庁が公開している全国のライブカメラをクローラで台帳化し、死活監視して静的JSONで配信し、アプリ（iOS / Android / Web）が地図に表示する。詳細仕様は [SPEC.md](SPEC.md)。

- ランニングコストはドメイン代のみ。画像・映像は端末から一次ソースへ直接アクセス（自前中継なし）
- 差別化の核は「開いたら必ず映る」（死活監視）と「今見る価値があるか」（オンデバイス画像判定）

## 構成

| ディレクトリ | 役割 | 状態 |
|---|---|---|
| `crawler/` | Phase 1: カメラ台帳の収集（Python） | 実装済み（KTR・QSR YouTube・kawabou県別） |
| `monitor/` | Phase 2: 死活監視（Python, 30分ごと） | 実装済み |
| `site/` | Phase 3: 静的配信（GitHub Pages, `site/build.py` が生成）+ Web版（静的ページ） | 配信は実装済み / Web版は未着手 |
| `app/` | Phase 4: モバイルアプリ（Flutter, iOS/Android） | 未着手 |
| `tools/` | 候補レビューCLI | 実装済み |

## セットアップ

```bash
python -m venv .venv
.venv/Scripts/activate      # Windows / macOSは source .venv/bin/activate
pip install -r requirements.txt
pytest crawler/tests monitor/tests
```

## 日常の運用フロー

```bash
# 1. クロール（週次はGitHub Actionsが実行しPRを作る）
python -m crawler.main --all

# 2. 候補を人手レビュー（承認したものだけが cameras.json に入る）
python tools/review_cli.py

# 3. 死活監視（30分ごとにGitHub Actionsが実行）
python -m monitor.main

# 4. 配信ファイル生成（data/変更時にGitHub Actionsが実行）
python site/build.py
```

## データソースについて

関東地方整備局はじめ国交省の河川カメラは現在、**川の防災情報**（river.go.jp）に集約されている。クローラは各整備局ページから `scamId` を収集し、kawabou の公開JSON（`/kawabou/file/files/master/obs/scam/<id>.json`）で名前・正確な座標・静止画URL（cam.river.go.jp）を解決する。この構造は `crawler/sources/kawabou.py` のdocstringと `crawler/tests/fixtures/` の保存レスポンスを参照。

## 配信エンドポイント

GitHub Pages で配信している: `https://kotopapa.github.io/livecam-jp/v1/manifest.json`

GitHub Actions 3本が自動運用する（crawl 週次 / monitor 30分ごと / publish data変更時）。
