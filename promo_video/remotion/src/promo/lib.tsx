import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/NotoSansJP";

export const { fontFamily } = loadFont("normal", { weights: ["500", "700", "900"] });

export const C = {
  navy: "#07172D",
  navy2: "#0E2A52",
  blue: "#1E6FD9",
  blueDeep: "#0B4DB3",
  sky: "#8FD3FF",
  mint: "#6FE3D2",
  white: "#FFFFFF",
  ink: "#102E49",
};

const CLAMP = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
export const OUT = Easing.bezier(0.16, 1, 0.3, 1);
export const INOUT = Easing.bezier(0.65, 0, 0.35, 1);
export const IN = Easing.bezier(0.5, 0, 0.9, 0.4);

/** クランプ付き補間 */
export const iv = (f: number, input: number[], output: number[], easing = OUT) =>
  interpolate(f, input, output, { ...CLAMP, easing });

/** 弾むスプリング（0→1、行き過ぎあり） */
export const bouncy = (frame: number, fps: number, delay = 0, damping = 11, stiffness = 170) =>
  spring({ frame: frame - delay, fps, config: { damping, stiffness, mass: 0.9 } });

/** 行き過ぎのないスプリング */
export const smooth = (frame: number, fps: number, delay = 0, durationInFrames?: number) =>
  spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames });

// ------------------------------------------------------------------
// 文字
// ------------------------------------------------------------------
export type From = "bottom" | "top" | "left" | "right" | "pop" | "spin" | "drop";

/**
 * 1文字ずつ出る文字列。from で出方を変える（下から跳ねる／上から落ちる／左右から滑る／拡大ポップ／回転）
 * 強調は [[ ]] で囲む（color で色替え）
 */
export const Chars: React.FC<{
  text: string;
  from?: From;
  delay?: number;
  stagger?: number;
  size: number;
  color?: string;
  em?: string;
  weight?: number;
  style?: React.CSSProperties;
  exitAt?: number;
  exitTo?: From;
}> = ({ text, from = "bottom", delay = 0, stagger = 2, size, color = C.white, em = C.mint, weight = 900, style, exitAt, exitTo = "top" }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const parts: { ch: string; em: boolean }[] = [];
  for (const seg of text.split(/(\[\[.*?\]\])/).filter(Boolean)) {
    const isEm = seg.startsWith("[[");
    for (const ch of isEm ? seg.slice(2, -2) : seg) parts.push({ ch, em: isEm });
  }
  return (
    <div style={{ fontFamily, fontWeight: weight, fontSize: size, lineHeight: 1.05, color, whiteSpace: "nowrap", letterSpacing: "-0.02em", ...style }}>
      {parts.map((p, i) => {
        const pr = bouncy(frame, fps, delay + i * stagger);
        const d = size * 1.1;
        let tx = 0, ty = 0, sc = 1, rot = 0;
        if (from === "bottom") ty = (1 - pr) * d;
        if (from === "top") ty = -(1 - pr) * d;
        if (from === "drop") { ty = -(1 - pr) * d * 3; rot = (1 - pr) * (i % 2 ? 25 : -25); }
        if (from === "left") tx = -(1 - pr) * d * 2;
        if (from === "right") tx = (1 - pr) * d * 2;
        if (from === "pop") sc = pr;
        if (from === "spin") { sc = pr; rot = (1 - pr) * -180; }
        let op = iv(frame, [delay + i * stagger, delay + i * stagger + 4], [0, 1]);
        if (exitAt !== undefined) {
          const e = iv(frame, [exitAt + i * 1, exitAt + i * 1 + 8], [0, 1], IN);
          if (exitTo === "top") ty -= e * d * 1.4;
          if (exitTo === "bottom") ty += e * d * 1.4;
          if (exitTo === "left") tx -= e * 1400;
          if (exitTo === "right") tx += e * 1400;
          if (exitTo === "pop") sc *= 1 - e;
          op *= 1 - e;
        }
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              color: p.em ? em : undefined,
              transform: `translate(${tx}px, ${ty}px) rotate(${rot}deg) scale(${sc})`,
              transformOrigin: "50% 80%",
              opacity: op,
            }}
          >
            {p.ch === " " ? " " : p.ch}
          </span>
        );
      })}
    </div>
  );
};

/** 行ごと画面外から滑り込む（行き過ぎて戻る）。dir で上下左右 */
export const Slide: React.FC<{
  children: React.ReactNode;
  dir: "left" | "right" | "top" | "bottom";
  delay?: number;
  distance?: number;
  exitAt?: number;
  exitDir?: "left" | "right" | "top" | "bottom";
  style?: React.CSSProperties;
}> = ({ children, dir, delay = 0, distance = 1300, exitAt, exitDir, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(frame, fps, delay, 14, 140);
  const v = (d: string, amt: number) =>
    d === "left" ? [-amt, 0] : d === "right" ? [amt, 0] : d === "top" ? [0, -amt] : [0, amt];
  const [x0, y0] = v(dir, distance);
  let x = x0 * (1 - p), y = y0 * (1 - p);
  if (exitAt !== undefined) {
    const e = iv(frame, [exitAt, exitAt + 10], [0, 1], IN);
    const [x1, y1] = v(exitDir ?? dir, distance);
    x += -x1 * e; y += -y1 * e;
  }
  // 出番の前は見せない（待機位置が画面内に入る場合があるため）
  return <div style={{ position: "absolute", transform: `translate(${x}px, ${y}px)`, opacity: frame < delay ? 0 : 1, ...style }}>{children}</div>;
};

/** 背景の巨大文字（スマホの背後に置く）。拡大しながら着地 */
export const Giant: React.FC<{
  text: string;
  size: number;
  top: number;
  left?: number;
  color?: string;
  delay?: number;
  outline?: boolean;
  vertical?: boolean;
  drift?: number;
  style?: React.CSSProperties;
}> = ({ text, size, top, left, color = C.white, delay = 0, outline, vertical, drift = 0, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = bouncy(frame, fps, delay, 16, 120);
  return (
    <div
      style={{
        position: "absolute", top, left: left ?? 0, width: left === undefined ? "100%" : undefined,
        textAlign: left === undefined ? "center" : "left",
        fontFamily, fontWeight: 900, fontSize: size, lineHeight: 0.92, letterSpacing: "-0.04em",
        color: outline ? "transparent" : color,
        WebkitTextStroke: outline ? `4px ${color}` : undefined,
        writingMode: vertical ? "vertical-rl" : undefined,
        whiteSpace: "nowrap",
        transform: `translateX(${-drift * frame}px) scale(${1.5 - 0.5 * p})`,
        opacity: Math.min(1, p * 1.4),
        transformOrigin: "50% 50%",
        ...style,
      }}
    >
      {text}
    </div>
  );
};

/** カウントアップ（0→to、カンマ区切り） */
export const Counter: React.FC<{ to: number; delay?: number; dur?: number; style?: React.CSSProperties }> = ({ to, delay = 0, dur = 30, style }) => {
  const frame = useCurrentFrame();
  const v = Math.round(iv(frame, [delay, delay + dur], [0, to], Easing.out(Easing.cubic)));
  return <div style={{ fontFamily, fontWeight: 900, fontVariantNumeric: "tabular-nums", ...style }}>{v.toLocaleString("en-US")}</div>;
};

// ------------------------------------------------------------------
// スマホ（3D。前面に実画面、背面にボディ。backScreen を渡すと裏にも画面）
// ------------------------------------------------------------------
const SRC_W = 1206, SRC_H = 2622;

export const Screen: React.FC<{ src: string; zoom?: number; ox?: number; oy?: number; radius: number }> = ({ src, zoom = 1, ox = 50, oy = 50, radius }) => (
  <div style={{ position: "absolute", inset: 0, overflow: "hidden", borderRadius: radius, background: "#fff" }}>
    <Img
      src={staticFile(`cap/${src}.png`)}
      style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${zoom})`, transformOrigin: `${ox}% ${oy}%` }}
    />
  </div>
);

export const Phone: React.FC<{
  src: string;
  backSrc?: string;
  width: number;
  x: number; // 中心 x
  y: number; // 中心 y
  rx?: number; ry?: number; rz?: number;
  scale?: number;
  zoom?: number; ox?: number; oy?: number;
  opacity?: number;
}> = ({ src, backSrc, width, x, y, rx = 0, ry = 0, rz = 0, scale = 1, zoom, ox, oy, opacity = 1 }) => {
  const bezel = width * 0.045;
  const sw = width - bezel * 2;
  const sh = (sw * SRC_H) / SRC_W;
  const h = sh + bezel * 2;
  const R = width * 0.17;
  const face: React.CSSProperties = {
    position: "absolute", inset: 0, borderRadius: R, backfaceVisibility: "hidden",
  };
  const island = (
    <div style={{ position: "absolute", top: bezel + sw * 0.03, left: "50%", width: sw * 0.3, height: sw * 0.085, marginLeft: -(sw * 0.15), borderRadius: 999, background: "#000" }} />
  );
  return (
    <div
      style={{
        position: "absolute", left: x - width / 2, top: y - h / 2, width, height: h,
        transformStyle: "preserve-3d",
        transform: `perspective(2600px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg) scale(${scale})`,
        opacity,
      }}
    >
      {/* 前面 */}
      <div
        style={{
          ...face,
          background: "linear-gradient(135deg, #3a3f47, #111317 40%, #2b2f36)",
          boxShadow: "0 60px 120px rgba(0,0,0,.35), 0 20px 40px rgba(0,0,0,.25), inset 0 0 0 2px rgba(255,255,255,.18)",
        }}
      >
        <div style={{ position: "absolute", left: bezel, top: bezel, width: sw, height: sh }}>
          <Screen src={src} zoom={zoom} ox={ox} oy={oy} radius={R - bezel} />
        </div>
        {island}
      </div>
      {/* 背面 */}
      <div style={{ ...face, transform: "rotateY(180deg)", background: backSrc ? "linear-gradient(135deg, #3a3f47, #111317 40%, #2b2f36)" : "linear-gradient(145deg, #2d6fd6, #173f86 55%, #0c2754)", boxShadow: "inset 0 0 0 2px rgba(255,255,255,.2)" }}>
        {backSrc ? (
          <>
            <div style={{ position: "absolute", left: bezel, top: bezel, width: sw, height: sh }}>
              <Screen src={backSrc} radius={R - bezel} />
            </div>
            {island}
          </>
        ) : (
          <div style={{ position: "absolute", left: width * 0.08, top: width * 0.08, width: width * 0.42, height: width * 0.42, borderRadius: width * 0.1, background: "rgba(255,255,255,.12)", boxShadow: "inset 0 0 0 2px rgba(255,255,255,.18)" }} />
        )}
      </div>
    </div>
  );
};

/** 実画面の一部を切り抜いて全面に敷く（crop は元画像比 [左,上,幅,高さ]） */
export const CropFill: React.FC<{ src: string; crop: [number, number, number, number]; zoom?: number; style?: React.CSSProperties }> = ({ src, crop, zoom = 1, style }) => {
  const [l, t, w, h] = crop;
  // 1080×1920 を cover で埋める倍率
  const cw = w * SRC_W, ch = h * SRC_H;
  const s = Math.max(1080 / cw, 1920 / ch) * zoom;
  return (
    <AbsoluteFill style={{ overflow: "hidden", ...style }}>
      <Img
        src={staticFile(`cap/${src}.png`)}
        style={{
          position: "absolute", width: SRC_W * s, height: SRC_H * s, maxWidth: "none",
          left: 540 - (l * SRC_W + cw / 2) * s, top: 960 - (t * SRC_H + ch / 2) * s,
        }}
      />
    </AbsoluteFill>
  );
};

/** 画面下の小さな出典表記 */
export const Credit: React.FC<{ lines: string[]; dark?: boolean }> = ({ lines, dark }) => (
  <div style={{ position: "absolute", left: 60, bottom: 56, fontFamily, fontWeight: 500, fontSize: 24, lineHeight: 1.4, color: dark ? "rgba(16,46,73,.7)" : "rgba(255,255,255,.75)" }}>
    {lines.map((l) => (
      <div key={l}>{l}</div>
    ))}
  </div>
);

/** ピル型のラベル */
export const Pill: React.FC<{ children: React.ReactNode; bg?: string; color?: string; size?: number; style?: React.CSSProperties }> = ({ children, bg = C.white, color = C.blue, size = 52, style }) => (
  <div style={{ display: "inline-block", fontFamily, fontWeight: 900, fontSize: size, padding: `${size * 0.28}px ${size * 0.6}px`, borderRadius: 999, background: bg, color, whiteSpace: "nowrap", boxShadow: "0 16px 40px rgba(0,0,0,.18)", ...style }}>
    {children}
  </div>
);
