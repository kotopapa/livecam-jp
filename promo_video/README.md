# プロモーション動画（30秒・縦 1080×1920・30fps）

Remotion で作っている（`remotion/`）。シーンは `remotion/src/promo/Scenes.tsx`、共通部品（3Dのスマホ・文字の出し方・カウントアップ）は `lib.tsx`。

```bash
cd promo_video/remotion
npm i
# 素材（実機キャプチャ。git 対象外）を public/cap/ に置く
for f in detail_river map_japan map_tokyo_pins_clean detail_sakurajima detail_live detail_tokyotower layer_rain_radar layer_typhoon bosai_warning layer_shelters ranking stockpile list layer_kikikuru_land; do cp ../../app/store_assets/captures/ios/$f.png public/cap/; done
# BGM と効果音（外部音源なし・一から合成。numpy/scipy が要る）
python3 ../audio/make_audio.py   # → public/audio/promo.wav
npx remotion studio            # プレビュー
npx remotion render Promo out/promo_1080x1920.mp4 --crf=16
```

書き出し後、SNS 向けに yuv420p・BT.709・無音の音声トラック付きへ変換している（ffmpeg は imageio-ffmpeg 同梱のもの）。
実画面は描き換えない。台風・警報の場面には「撮影時の画面例・現在の情報ではありません」と出典を必ず出す。

## 音
- `audio/make_audio.py` が BGM（120 BPM、D–A–Bm–G）と効果音（切り替えの衝撃音・風切り音・文字のポップ音・カウントの刻みとチャイム）を合成する。外部の音源は使っていないので権利の心配はない
- 120 BPM は1拍 0.5 秒で、シーンの切り替わりは全て拍の頭に乗る。シーンの秒数や演出のフレームを変えたら、スクリプトの効果音の時刻（シーン開始秒＋フレーム/30）も直す
- ラウドネスは SNS 向けに -14 LUFS 前後。スマホのスピーカーで埋もれないよう低域を控えめにしている
