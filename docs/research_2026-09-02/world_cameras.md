# 海外の観光地・絶景ライブカメラ 調査（2026-09-02）

ユーザー依頼「海外の観光地や絶景のライブカメラを調査して個数を増やす」。
地域別の4調査（ヨーロッパ／南北アメリカ／アジア・オセアニア／中東・アフリカ・極地・自然）で
YouTube の24時間ライブ配信を一次ソース（チャンネル `/streams`・公式サイト）で確認し、
候補 475件を集めた。取り込みは scratchpad の `world/merge_world.py`（消えたら再作成）で
①既存の動画ID/名前/生成IDと重複排除 ②watch ページの `isLiveNow` を再確認 ③oEmbed で埋め込み可否を確認
④`world-<sha1(video_id)[:8]>` で採番し `crawler/curated_world.yaml` と `data/cameras.json` に追加、の順。
埋め込み不可（oEmbed 401）は 2026-08-25 の方針どおり誘導型（web_page, URL=watch）で登録。

取り込み結果は末尾「取り込み結果」を参照。

## 調査で分かった鉱脈（一次運営者・公式）

- **台湾の官公庁系が非常に厚い**: 東部海岸国家風景区（4K 10本）、阿里山（5本）、日月潭、墾丁、北観処、澎湖、各県市観光局
- **韓国 GiGAeyes Live TV（KTテレコップ）**: 江陵・ソウル駅・景福宮・大田など。FunJeju、高城郡・旌善郡・アルペンシア
- **afarTV**: 世界の火山（エトナ・スメル・ブロモ・ムラピ・マヨン・ポポカテペトル）と極地（グリーンランド氷山）
- **Africam**（ケニア・ジンバブエ・南ア・ボツワナのサファリ水場 19地点）、NamibiaCam、Explore.org、Cornell Lab Bird Cams
- **WEBCAM NEPAL LIVE**（エベレスト街道・アンナプルナ周辺 10本。全部埋め込み不可→誘導型）
- **ブラジル**: フロリアノポリス・バルネアリオ・カンボリウ・レシフェ・マナウス等の地元運営者。**アルゼンチン**: イグアス国立公園公式（開園時間のみ）
- **イタリア**: Paesaggi Digitali、I Love You Venice、Weather Italy。**スペイン**: meteo365es（埋め込み不可）、Mallorca Webcam。**ポルトガル**: マデイラ（Netmadeira）
- **北欧・北極圏**: Mittarfeqarfiit（グリーンランド空港）、Sikuki、フィンランド・ラップランドのオーロラカメラ、ノールカップ
- 各地の動物園・水族館の公式チャンネル（シアトル/バンクーバー水族館、セントルイス動物園、GaiaZOO、タロンガ等）→ `healing`

### 追加で辿れる（今回は件数を絞って未収録）
Strandweer.nu（オランダ海岸 +6）、Paesaggi Digitali（+約10）、I Love You Venice（+約10）、Mallorca Webcam（+6）、
Netmadeira/Madeira-Web、Coast Cams（デボン）、See Transylvania、croatia_live（シベニク周辺 +6）、
The Real Samui Webcam（店内カメラを除く残り）、Africam の地点不明分（Kalahari Salt Pan 等）。

## 見送り・確認できなかった有力候補

- **中東は新規0件**: Dubai Marina/Skyline、Tel Aviv(CGTN)、Doha(NTD)、Petra は現在ライブなし。検索に出るのは戦況 OSINT の再配信ばかり。Makkah Live は公式配信元を特定できず
- **YouTube 24時間枠が無い**（一次サイト側の配信のみ）: 米国 NPS 各公園、Banff/Lake Louise 公式、クラクフ・ザコパネ、ハルシュタット、ベルゲン、シャモニー、ザルツブルク、コペンハーゲン Nyhavn、モンテビデオ等の市営カメラ
- **配信終了・オフライン**: Brussels Grand Place、Athens 4K、Budapest（EarthCam/Hotel Victoria）、Stockholm 各種、Lofoten オーロラ、Cartagena、Panama Canal 公式、Mazatlán、マチュピチュ（Peru Vip）、Cristo Redentor、Bahamas、Stromboli 専用ch、Victoria Falls Safari Lodge、Giza、Nepal VR、Penang、Bali 系複数、Whitsunday/Cairns/Gold Coast/Perth
- **除外理由あり**: Golden Temple（音声のみ）、Kashi Vishwanath（第三者再配信の疑い）、Colorado Live Cams パイクスピーク（再配信の疑い、note 記載）

## 既存台帳で見つかった問題（要対応）

調査中に既存の海外カメラの劣化が複数見つかった。取り込み後に `world/health_world.py` で一斉点検する。

- **SkylineWebcams と feratel は YouTube の個別カメラ配信を終了**し、現在は巡回コンピレーションのみ。既存の同2運営者分（30件超: プラハ、ウィーン、ツェルマット、ミュンヘン等）は not live
- **動画IDの流用（同じIDで別地点を配信）**: `tYgGEC-ESTw` ボストン→レイキャビク、`pMaqsb26eSE` 釜山 松亭→済州 城山日出峰、Explore.org `vu7I315gQpU` パンダ→カトマイ水中、`J7ZrIDvqlic` シャークラグーン→ブルックス滝
- **配信終了**: Sydney Live Camera 3本、Dubrovnik（Live Cam Croatia）、コペンハーゲン（light2tube）、ベルリン（4GiTV）、マドリード（VexoVision）、リガ、ブダペスト（earthTV）、イスタンブール
- **IDが変わったもの（同地点）**: BusanLive 広安大橋 → `dx3hdEHNZV8`、DIKIPIDIA シンガポール → `N_Az11sKhlQ`
- 要確認: 既存「フィジー 珊瑚礁壁水中カメラ `Sq-X4Ga1oyc`」はチャンネル上ホンジュラス・ウティラ島のカメラの模様

## 作業上の知見
- WebSearch は1セッション200回で上限。以後は YouTube の検索結果ページ（ライブ絞り込み）と既知チャンネルの `/streams` 追跡が有効
- YouTube watch ページは並列取得で 429 になる。2〜3秒間隔の逐次取得、429時は30〜90秒待ちで安定
- 座標は運営者の説明欄にあればその値、無ければランドマーク概略（`approx`）。マルチカム巡回配信（カナリア諸島、WebCamera.pl 等）は代表地点
- 季節・時間帯限定の配信（オーロラ＝夜間、営巣＝季節、イグアス＝開園時間）は note に記載。監視の「48時間以内の配信終了は生存扱い」ルールで日中停止は吸収できるが、季節停止は退役判定に掛かる可能性あり

## 取り込み結果（2026-09-02）

- 候補 475件 → 重複排除で 457件（同一動画IDの重複18件: 火山・極地は2調査で重なった）→ isLiveNow 再確認で **454件を追加**、3件は配信終了で除外（ケベック シャトー・フロントナック、ソダンキュラ川、ナミビア クワンド川）
- **21,621 → 22,075台**（海外 312 → 766台）。カテゴリ: scenic 371 / healing 65 / volcano 18。埋め込み不可33件は誘導型
- 国別（上位）: US 59, TW 46, IT 30, BR 29, CA 20, ES 18, AU 15, ZA 15, KR 14, NP 12, TH 11, PT 11, MX 9, GB 9, NL 9, RO 9, FI 9, AR 8, NZ 8, NO 8, CL 7, KE 7, IS 6 … 計 62か国・地域
- スキーマ規則（country パターン・category enum・prefecture=99・coord_accuracy）を全件照合済み。`data/cameras.json` の version 更新済み

## 既存海外カメラの一斉点検（2026-09-02・取り込み後）

追加前からあった海外カメラのうち YouTube 由来 302台を `world/health_world.py` で点検（watch ページの isLiveNow）。
**156台が生存、146台が配信終了**。終了分はチャンネル `/streams` の現行ライブと照合（`world/retire_follow.py`）し、
自動マッチは目視で精査（別地点への誤マッチ9件を却下）:

- **追従 10台**（同地点の新しい配信IDへ差し替え）: ペリト・モレノ氷河、釜山 広安里、マイアミ サウスビーチ、フォルクストン、
  リスボン空港・ヒースロー（日替わりID）、ジャイアントパンダ（臥龍 林間→耿達に改名）、サンティアゴ市街（Ledrium 同地区）、クルー駅、シンガポール マリーナベイ
- **退役 136台**: SkylineWebcams 19・feratel 17・EarthCam 13 は個別カメラのYouTube配信を終了し巡回配信のみ。Sydney Live Camera 3、
  Explore.org のID流用分（ハミングバード・シャーク等 6）、その他個人チャンネルの配信終了。8/31 に yaml でコメントアウト済みだったが
  cameras.json に残っていた分も今回除去。オークランド ハーバーは同地点を新規候補で登録済みのため旧枠を退役
- **保留 0台**（直近7日以内終了の営業時間型は該当なし。シンガポールは追従で解決）

結果: **21,621 → 22,075（+454）→ 21,939台（退役136）**。海外は 312 → 630台（YouTube生存分＋静止画/誘導型）。

### 残課題
- cameras.json に**同一動画IDの二重登録が12件**ある（今回以前から。国内11件: 秋葉原・鴨川・盛岡・那覇新港×2・由布岳・横浜港・大山・鹿島灘・しまばら/秩父が浦(ID流用の疑い)・松戸ヤギ／海外1件: モントレー水族館クラゲ×2）。
  livecamdb 索引経由（`curated-lcdb-*`）で既登録と同じ配信を再登録したものが中心。片方を退役するか、監視側で同一IDを束ねる対応が必要
- SkylineWebcams・feratel・EarthCam の「巡回配信」枠はマルチカム（複数地点切替）なので単一地点としては登録しない方針。必要なら代表地点で healing/scenic として1本登録する案はある
