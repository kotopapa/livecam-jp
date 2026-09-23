import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { bouncy, C, Chars, Counter, Credit, CropFill, fontFamily, Giant, INOUT, iv, OUT, Phone, Pill, Slide, smooth } from "./lib";

// 各シーンの長さ（フレーム、30fps）。合計 900F = 30秒
export const DUR = { hook: 75, count: 90, map: 90, travel: 120, weather: 105, alert: 90, shelter: 90, daily: 90, all: 60, end: 90 };

// 1. 問いかけ ─ 巨大な「今」の前にスマホが回転しながら上がってくる
export const Hook: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(f, fps, 2, 13, 120);
  return (
    <AbsoluteFill style={{ background: `radial-gradient(circle at 50% 60%, ${C.navy2}, ${C.navy} 70%)` }}>
      <Giant text="今" size={1250} top={440} color={C.blue} delay={0} />
      <Phone src="detail_river" width={560} x={560} y={1330 + (1 - p) * 1100} ry={-38 + 26 * p + f * 0.12} rz={10 - 15 * p} rx={8} />
      <Slide dir="left" delay={0} style={{ left: 70, top: 150 }}>
        <Chars text="近くの[[川]]、" size={130} stagger={0} />
      </Slide>
      <Chars text="今、どう？" from="bottom" delay={10} stagger={3} size={210} style={{ position: "absolute", left: 62, top: 310 }} />
      <Credit lines={["撮影時の画面例　映像提供：葛飾区役所"]} />
    </AbsoluteFill>
  );
};

// 2. 規模 ─ 20,000 のカウントアップ、スマホが裏返って登場
export const Count: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = smooth(f, fps, 0, 28);
  return (
    <AbsoluteFill style={{ background: `linear-gradient(170deg, ${C.blue} 0%, ${C.blueDeep} 60%, #062E70 100%)` }}>
      <Giant text="全国" size={720} top={820} color="rgba(255,255,255,.55)" outline delay={4} drift={1.2} />
      <Counter to={20000} delay={0} dur={32} style={{ position: "absolute", top: 110, width: "100%", textAlign: "center", fontSize: 250, color: C.white, letterSpacing: "-0.03em", scale: `${iv(f, [0, 32, 38, 44], [0.7, 1, 1.08, 1])}` }} />
      <Chars text="台以上のライブカメラ" from="right" delay={20} stagger={1.5} size={88} style={{ position: "absolute", top: 490, width: "100%", textAlign: "center" }} />
      <Phone src="map_japan" width={540} x={540} y={1340} ry={180 - 192 * p + (f > 28 ? (f - 28) * 0.1 : 0)} rx={6} scale={0.8 + 0.2 * p} />
      <Credit lines={["撮影時の画面例　地理院タイル・気象庁"]} />
    </AbsoluteFill>
  );
};

// 3. 探す ─ 縦書きの巨大文字が上下から、寝ていたスマホが起き上がり地図に寄る
export const MapScene: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(f, fps, 0, 14, 110);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #F4F9FF, #DCEBFA)" }}>
      <Slide dir="top" delay={0} distance={1600} style={{ left: 20, top: 150 }}>
        <div style={{ fontFamily, fontWeight: 900, fontSize: 250, lineHeight: 1, writingMode: "vertical-rl", color: C.blue }}>地図で</div>
      </Slide>
      <Slide dir="bottom" delay={6} distance={1800} style={{ left: 810, top: 620 }}>
        <div style={{ fontFamily, fontWeight: 900, fontSize: 250, lineHeight: 1, writingMode: "vertical-rl", color: C.ink }}>さがす。</div>
      </Slide>
      <Phone
        src="map_tokyo_pins_clean" width={520} x={545} y={1080}
        rx={62 - 54 * p} rz={-12 * (1 - p)} ry={iv(f, [20, 90], [0, -10])}
        scale={0.85 + 0.15 * p}
        zoom={iv(f, [34, 80], [1, 1.45], INOUT)} ox={17} oy={62}
      />
      <Credit dark lines={["撮影時の画面例　地理院タイル"]} />
    </AbsoluteFill>
  );
};

// 4. 旅先 ─ 桜島の実映像を全面に敷き、3台のスマホが扇状に開く
export const Travel: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = bouncy(f, fps, 10, 13, 120), b = bouncy(f, fps, 16, 13, 120), c = bouncy(f, fps, 22, 13, 120);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <CropFill src="detail_sakurajima" crop={[0, 0.137, 1, 0.255]} zoom={iv(f, [0, 120], [1.35, 1.1], INOUT)} />
      <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(4,20,45,.55) 0%, rgba(4,20,45,0) 38%, rgba(4,20,45,0) 55%, rgba(4,20,45,.65) 100%)" }} />
      <Slide dir="right" delay={0} style={{ left: 70, top: 140 }}>
        <Chars text="旅先の、" size={150} stagger={0} />
      </Slide>
      <Chars text="今へ。" from="pop" delay={8} stagger={4} size={280} em={C.mint} style={{ position: "absolute", left: 60, top: 300 }} />
      <Phone src="detail_live" width={380} x={255} y={1420 + (1 - a) * 1200} rz={-14 * a} ry={22} />
      <Phone src="detail_tokyotower" width={380} x={825} y={1420 + (1 - c) * 1200} rz={14 * c} ry={-22} />
      <Phone src="detail_sakurajima" width={440} x={540} y={1330 + (1 - b) * 1200} rx={4} ry={iv(f, [20, 120], [8, -8])} scale={iv(f, [22, 120], [1, 1.04])} />
      <Credit lines={["撮影時の画面例", "映像提供：株式会社財宝・テレビ朝日（ANNnewsCH）・東京タワー"]} />
    </AbsoluteFill>
  );
};

// 5. 天気 ─ 表に雨雲、裏返すと台風。見出しが上下から入れ替わる
export const Weather: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = bouncy(f, fps, 0, 14, 120);
  const flip = iv(f, [44, 60], [0, 180], INOUT);
  return (
    <AbsoluteFill style={{ background: `linear-gradient(180deg, #0B1B3F, #1B2F7A)` }}>
      <div style={{ opacity: iv(f, [42, 50], [1, 0]) }}>
        <Giant text="雨雲" size={520} top={760} color="rgba(143,211,255,.22)" />
      </div>
      <div style={{ opacity: iv(f, [52, 60], [0, 1]) }}>
        <Giant text="台風" size={520} top={760} color="rgba(111,227,210,.22)" delay={52} />
      </div>
      <Phone src="layer_rain_radar" backSrc="layer_typhoon" width={540} x={540} y={1250 + (1 - enter) * 900} ry={-16 + flip + iv(f, [0, 105], [0, 12])} rx={4} />
      <Slide dir="top" delay={0} exitAt={42} exitDir="left" style={{ left: 70, top: 150 }}>
        <Chars text="[[雨雲]]も。" size={190} stagger={0} em={C.sky} />
      </Slide>
      <Slide dir="bottom" delay={50} style={{ left: 70, top: 150 }}>
        <Chars text="[[台風]]の進路も。" size={150} stagger={0} em={C.mint} style={{ marginTop: 20 }} />
      </Slide>
      <Credit lines={["撮影時の画面例・現在の情報ではありません", "出典：気象庁・地理院タイル・© OpenStreetMap contributors"]} />
    </AbsoluteFill>
  );
};

// 6. 通知 ─ 1文字ずつ跳ねる見出し、機能ラベルが左右から飛んでくる
export const Alert: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(f, fps, 6, 14, 120);
  const pill = (d: number) => bouncy(f, fps, d, 10, 180);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #F2F6FF, #D3E2FF)" }}>
      <Giant text="通知" size={560} top={900} color="rgba(30,111,217,.10)" delay={0} />
      <Chars text="警報も、地震も、" from="bottom" delay={0} stagger={2} size={116} color={C.ink} style={{ position: "absolute", left: 70, top: 150 }} />
      <Chars text="[[通知]]で。" from="drop" delay={12} stagger={4} size={230} color={C.ink} em={C.blue} style={{ position: "absolute", left: 62, top: 290 }} />
      <Phone src="bosai_warning" width={500} x={720 + (1 - p) * 900} y={1260} ry={-30 + 14 * p} rz={4} />
      <div style={{ position: "absolute", left: 60, top: 820, transform: `translateX(${(1 - pill(24)) * -900}px) rotate(-6deg)` }}>
        <Pill bg={C.blue} color={C.white}>特別警報</Pill>
      </div>
      <div style={{ position: "absolute", left: 110, top: 980, transform: `translateX(${(1 - pill(30)) * -900}px) rotate(4deg)` }}>
        <Pill bg={C.ink} color={C.white}>危険警報</Pill>
      </div>
      <div style={{ position: "absolute", left: 70, top: 1140, transform: `translateX(${(1 - pill(36)) * -900}px) rotate(-3deg)` }}>
        <Pill bg={C.mint} color={C.ink}>地震</Pill>
      </div>
      <Credit dark lines={["撮影時の画面例・現在の情報ではありません　出典：気象庁"]} />
    </AbsoluteFill>
  );
};

// 7. 避難先 ─ 見出しが上下から、スマホは左から回り込む
export const Shelter: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(f, fps, 4, 14, 110);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(170deg, #14B3A2, #0B6F80)" }}>
      <Giant text="避難先" size={400} top={820} color="rgba(255,255,255,.7)" outline delay={2} drift={-1} />
      <Slide dir="top" delay={0} style={{ left: 70, top: 150 }}>
        <Chars text="[[避難先]]も、" size={160} stagger={0} em="#FFF3B0" />
      </Slide>
      <Slide dir="bottom" delay={6} style={{ left: 70, top: 335 }}>
        <Chars text="ふだんから。" size={160} stagger={0} />
      </Slide>
      <Phone src="layer_shelters" width={520} x={600 - (1 - p) * 1100} y={1270} ry={40 - 28 * p + f * 0.08} rz={-4} rx={4} />
      <Credit lines={["撮影時の画面例　出典：国土地理院・地理院タイル", "最新の避難場所情報は市町村にご確認ください"]} />
    </AbsoluteFill>
  );
};

// 8. 日々の便利 ─ 2台が上下から逆向きに、見出しは左右から1文字ずつ
export const Daily: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = bouncy(f, fps, 0, 14, 120), b = bouncy(f, fps, 8, 14, 120);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #EAF5FF, #BCDDFF)" }}>
      <Chars text="みんなの[[注目]]も、" from="left" delay={0} stagger={2} size={112} color={C.ink} em={C.blue} style={{ position: "absolute", left: 70, top: 150 }} />
      <Phone src="ranking" width={430} x={330} y={1010 - (1 - a) * 1700} rz={-8} ry={18} />
      <Phone src="stockpile" width={430} x={760} y={1130 + (1 - b) * 1700} rz={8} ry={-18} />
      <Chars text="備えの[[期限]]も。" from="right" delay={20} stagger={2} size={112} color={C.ink} em={C.blue} style={{ position: "absolute", left: 70, top: 1640 }} />
      <Credit dark lines={["撮影時の画面例"]} />
    </AbsoluteFill>
  );
};

// 9. 全部 ─ 画面が横に流れ、見出しが回転しながら着地
const ALL = ["map_japan", "detail_sakurajima", "layer_rain_radar", "bosai_warning", "layer_shelters", "ranking", "stockpile", "list", "layer_kikikuru_land"];
export const All: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: `linear-gradient(180deg, ${C.blue}, ${C.blueDeep})` }}>
      <Chars text="ぜんぶ、" from="spin" delay={0} stagger={3} size={190} style={{ position: "absolute", left: 70, top: 170 }} />
      <Chars text="ひとつのアプリに。" from="bottom" delay={10} stagger={2} size={104} em={C.mint} style={{ position: "absolute", left: 70, top: 400 }} />
      {ALL.map((s, i) => {
        const x = 1400 + i * 340 - f * 52;
        return <Phone key={s} src={s} width={320} x={x} y={1220 + (i % 2 ? 60 : -60)} ry={-24} rz={i % 2 ? 4 : -4} />;
      })}
      <Credit lines={["撮影時の画面例"]} />
    </AbsoluteFill>
  );
};

// 10. 締め ─ 「今を、見に行こう。」とアプリ名、下からスマホ
export const End: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(f, fps, 14, 14, 110);
  const name = smooth(f, fps, 22, 16);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #FFFFFF, #E4F0FF)" }}>
      <Chars text="今を、" from="pop" delay={0} stagger={4} size={250} color={C.blue} style={{ position: "absolute", left: 62, top: 150 }} />
      <Chars text="見に行こう。" from="right" delay={8} stagger={2} size={150} color={C.ink} style={{ position: "absolute", left: 70, top: 420 }} />
      <div style={{ position: "absolute", left: 70, top: 690, fontFamily, fontWeight: 900, fontSize: 92, color: C.ink, opacity: name, transform: `translateY(${(1 - name) * 40}px)` }}>
        全国ライブカメラ地図
      </div>
      <div style={{ position: "absolute", left: 70, top: 830, transform: `scale(${bouncy(f, fps, 28, 9, 200)})`, transformOrigin: "0 50%" }}>
        <Pill bg={C.blue} color={C.white} size={58}>無料・登録不要</Pill>
      </div>
      <div style={{ position: "absolute", left: 70, top: 1000, fontFamily, fontWeight: 700, fontSize: 46, color: C.ink, opacity: iv(f, [34, 44], [0, 1]) }}>
        App Store / Google Play で検索
      </div>
      <Phone src="map_japan" width={560} x={540} y={1790 + (1 - p) * 700} ry={iv(f, [14, 90], [-20, -6], OUT)} rx={10} />
    </AbsoluteFill>
  );
};
