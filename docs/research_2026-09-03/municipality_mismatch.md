# municipality 補完で県が一致しなかったカメラ（2026-09-03）

`tools/fill_municipality.py` で国土地理院の逆ジオコーダが返した市区町村コードの先頭2桁が、台帳の prefecture と違ったもの（77件）。
municipality は書いていない。座標か prefecture のどちらかが誤っている可能性がある。多拠点巡回（代表座標が他県）・県境・空港名（大阪国際空港は兵庫県伊丹市）などは正常なので、名称と座標を見て個別に判断する。

| id | 名称 | 台帳の県 | 逆ジオコーダの市区町村 |
|---|---|---|---|
| curated-dojocco-kenzakai | 安来 県境交差点（国道9号・雪道） | 32 | 31202 |
| curated-lcdb-02f06479 | 高峰マウンテンパーク第三リフト前 | 20 | 10425 |
| curated-lcdb-04bc2944 | 九州地方整備局山国川7拠点 | 44 | 40646 |
| curated-lcdb-0a43059b | AAB秋田県内気象情報 | 05 | 13103 |
| curated-lcdb-100c1d28 | BANTV琵琶湖リモート地蔵 | 25 | 26103 |
| curated-lcdb-3fe84875 | 犬山城御岳 | 21 | 23362 |
| curated-lcdb-41602ede | 大阪国際空港フライト追跡 | 27 | 28207 |
| curated-lcdb-53e75dba | 磐田ラジコンクラブ滑走路 | 13 | 22211 |
| curated-lcdb-55eda9b5 | 近畿地方整備局主要河川16拠点 | 18 | 27128 |
| curated-lcdb-55ff9333 | アンサーポイント気仙沼 | 04 | 03209 |
| curated-lcdb-59b08c08 | BANTV大津港 | 25 | 26103 |
| curated-lcdb-6f1dd9eb | 朝日新聞大阪国際空港 | 27 | 28207 |
| curated-lcdb-767f333d | BANTV琵琶湖 | 25 | 26103 |
| curated-lcdb-801cdf81 | バクノビジョン西新宿五丁目 | 47 | 13113 |
| curated-lcdb-82d7fe2f | 天空陵 | 44 | 43423 |
| curated-lcdb-a95f68ee | Baycom大和川 | 27 | 28107 |
| curated-lcdb-d0fe0348 | まえちゃんねっと浅間山 | 10 | 20203 |
| curated-lcdb-e6f2a439 | 高峰マウンテンパークスキー場 | 20 | 10425 |
| curated-link-kintoki-summit | 金時山 山頂（金太郎茶屋） | 14 | 22344 |
| curated-link-lcdb-11a7078b | 富士川5拠点巡回 | 22 | 11105 |
| curated-link-lcdb-1e6fa6e2 | 関東地方整備局遊水地放水路11拠点巡回 | 13 | 11105 |
| curated-link-lcdb-3634e2b8 | 阪高カーウォッシュ猪名川第2 | 27 | 28217 |
| curated-link-lcdb-5ee2d27e | 新興製作所関門海峡 | 40 | 35201 |
| curated-link-lcdb-951987b0 | 阪高カーウォッシュ猪名川第1 | 27 | 28217 |
| curated-link-lcdb-dabd6ab3 | 利根川烏川8拠点巡回 | 12 | 11105 |
| curated-r2-04bc137c | 英彦山 | 40 | 44203 |
| curated-still-lcdb-0f24c6af | 槍ヶ岳山荘槍ヶ岳 | 20 | 21203 |
| curated-still-lcdb-1a2171e5 | 明神山明石海峡大橋方面 | 29 | 27221 |
| curated-still-lcdb-229df837 | 葛城高原ロッジ葛城山山頂第2 | 29 | 27383 |
| curated-still-lcdb-4b6f6537 | 江戸川野田岩名 | 12 | 11214 |
| curated-still-lcdb-4e513118 | 明神山吉野大峯方面 | 29 | 27221 |
| curated-still-lcdb-551375ae | 国道34号不動山 | 41 | 42321 |
| curated-still-lcdb-65dcdb11 | 明神山二上山葛城山金剛山方面 | 29 | 27221 |
| curated-still-lcdb-80c894b8 | 江戸川野田尾崎 | 12 | 11214 |
| curated-still-lcdb-82ed5673 | 明神山比叡山方面 | 29 | 27221 |
| curated-still-lcdb-8788ae2b | 明神山若草山方面 | 29 | 27221 |
| curated-still-lcdb-8a8e8b07 | 【冬季限定】茶臼山高原スキー場駐車場 | 23 | 20410 |
| curated-still-lcdb-8cf731ab | 明神山信貴山比叡山方面 | 29 | 27221 |
| curated-still-lcdb-8ea56aff | 松川蟹ヶ沢下流 | 07 | 06202 |
| curated-still-lcdb-9a7e0d6b | 国道34号俵坂佐賀側 | 41 | 42321 |
| curated-still-lcdb-ae8fc2c4 | 明神山八経ヶ岳方面 | 29 | 27221 |
| curated-still-lcdb-b14ee15e | 葛城高原ロッジ葛城山山頂第1 | 29 | 27383 |
| curated-still-lcdb-b62c094f | 明神山法隆寺若草山方面 | 29 | 27221 |
| curated-still-lcdb-c20df577 | 宝満川端間 | 40 | 41203 |
| curated-still-lcdb-dfb98e94 | 明神山百舌鳥古市古墳群あべのハルカス明石海峡大橋方面 | 29 | 27221 |
| curated-still-lcdb-f9e31ba0 | 明神山大台ヶ原方面 | 29 | 27221 |
| curated-still-mountain-hotakadake-sanso-east | 穂高岳山荘 東側カメラ（涸沢側） | 20 | 21203 |
| curated-still-road-koya-ryujin-skyline-koya | 高野龍神スカイライン ごまさんスカイタワー前（高野町方向） | 30 | 29449 |
| curated-still-road-koya-ryujin-skyline-ryujin | 高野龍神スカイライン ごまさんスカイタワー前（龍神村方向） | 30 | 29449 |
| curated-still-scenic-daisen-kagaminari-sizenken68 | 大山鏡ヶ成から見た烏ヶ山 | 31 | 33214 |
| curated-still-scenic-shikoku-karst-himetsuru | 四国カルスト 姫鶴平（梼原町） | 39 | 38386 |
| fukui-road-928 | 冠山トンネル（岐阜・西濃圏域） | 18 | 21401 |
| ishikawa-road-901 | 熊無 | 17 | 16205 |
| ishikawa-road-902 | 内山 | 17 | 16209 |
| ishikawa-road-903 | 高窪 | 17 | 16210 |
| ishikawa-road-905 | 上久米田 | 17 | 18210 |
| ishikawa-road-906 | 山竹田 | 17 | 18210 |
| ishikawa-road-907 | 谷 | 17 | 18206 |
| ishikawa-road-908 | 小原 | 17 | 18206 |
| ishikawa-road-922 | 高窪トンネル付近 | 17 | 16210 |
| jwa-river-saitama-55201100006 | 毛長川舎人 | 11 | 13121 |
| jwa-river-saitama-55201100918 | 領家新芝川 | 11 | 13121 |
| jwa-river-wakayama-k02881 | 熊野川0.0左 | 30 | 24562 |
| jwa-river-wakayama-k02882 | 熊野川0.8左 | 30 | 24562 |
| jwa-river-wakayama-k02884 | 熊野川1.6左 | 30 | 24562 |
| jwa-river-wakayama-k87025 | 阪合部橋 | 30 | 29207 |
| jwa-river-wakayama-k87026 | 御蔵橋 | 30 | 29207 |
| jwa-river-wakayama-k87027 | 二見上流排水樋門 | 30 | 29207 |
| jwa-river-wakayama-k87028 | 野原西上流排水樋門 | 30 | 29207 |
| jwa-river-wakayama-k87029 | 五條4丁目 | 30 | 29207 |
| jwa-river-wakayama-k87030 | 東谷川排水樋門 | 30 | 29207 |
| jwa-river-wakayama-k88002 | 北檜杖 | 30 | 24562 |
| miyagi-road-hokubu-nabe | 国道347号 鍋越峠 | 04 | 06212 |
| mlit-hrr-road-761373 | 国道160号 大泊2カメラ（下）（大泊県境） | 17 | 16205 |
| tokyo-suibo-016 | 白子川 子安橋 | 13 | 11229 |
| tokyo-suibo-017 | 白子川 越後山橋 | 13 | 11229 |
| tokyo-suibo-025 | 境川 境橋 | 13 | 14153 |
