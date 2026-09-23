# プロモーション動画（30秒・縦 1080×1920・30fps）

Remotion で作っている（`remotion/`）。シーンは `remotion/src/promo/Scenes.tsx`、共通部品（3Dのスマホ・文字の出し方・カウントアップ）は `lib.tsx`。

```bash
cd promo_video/remotion
npm i
# 素材（実機キャプチャ。git 対象外）を public/cap/ に置く
for f in detail_river map_japan map_tokyo_pins_clean detail_sakurajima detail_live detail_tokyotower layer_rain_radar layer_typhoon bosai_warning layer_shelters ranking stockpile list layer_kikikuru_land; do cp ../../app/store_assets/captures/ios/$f.png public/cap/; done
npx remotion studio            # プレビュー
npx remotion render Promo out/promo_1080x1920.mp4 --crf=16
```

書き出し後、SNS 向けに yuv420p・BT.709・無音の音声トラック付きへ変換している（ffmpeg は imageio-ffmpeg 同梱のもの）。
実画面は描き換えない。台風・警報の場面には「撮影時の画面例・現在の情報ではありません」と出典を必ず出す。
