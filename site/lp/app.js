/* 全国ライブカメラ地図 LP — 動き
 * 地図は実在カメラの位置（site/build.py が作る lp/data.json）を WebGL の光点で描く。
 * 地図の視点はスクロール位置に結び付けたキーフレーム（KEYS）で決め、文字の演出は GSAP の ScrollTrigger。
 */
(() => {
"use strict";
const REDUCED = matchMedia("(prefers-reduced-motion: reduce)").matches;
const MOBILE = matchMedia("(max-width: 700px)").matches;
const HOVER = matchMedia("(hover: hover)").matches;
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const fmt = n => Math.round(n).toLocaleString("ja-JP");
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;

const CAT_ORDER = ["river","road","volcano","dam","coast","port","scenic","healing","other"];
const CAT = {
  river:  {ja:"河川", en:"RIVER",   color:"#3D8BFF", d:"水位と流れ。台風・大雨の日に。"},
  road:   {ja:"道路", en:"ROAD",    color:"#A9B6CC", d:"国道・県道・峠。雪道と渋滞を出発前に。"},
  volcano:{ja:"火山", en:"VOLCANO", color:"#FF5A47", d:"桜島・浅間山・阿蘇。噴煙を監視カメラで。"},
  dam:    {ja:"ダム", en:"DAM",     color:"#2FCF7A", d:"放流と貯水。ダム管理所のカメラ。"},
  coast:  {ja:"海岸", en:"COAST",   color:"#1FD8F0", d:"波とビーチ。サーフィン・釣りの下見に。"},
  port:   {ja:"港湾", en:"PORT",    color:"#9C6BFF", d:"港・漁港・マリーナ・フェリー。"},
  scenic: {ja:"景観", en:"SCENIC",  color:"#FF9F2E", d:"富士山・夜景・桜・雲海・スキー場。"},
  healing:{ja:"癒し", en:"HEALING", color:"#FF6FB4", d:"動物・野鳥・水族館・星空・牧場。"},
  other:  {ja:"街",   en:"CITY",    color:"#C49A82", d:"駅前・交差点・商店街・庁舎。街のいま。"},
};
const ICON = {
  river:'<path d="M9 2c-3 3 3 5 0 8s3 5 0 8M15 2c-3 3 3 5 0 8s3 5 0 8" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"/>',
  road:'<path d="M11 2h2v3h6l2 2.5-2 2.5h-6v2h-4v-2H5L3 7.5 5 5h6zM11 14h2v8h-2z"/>',
  volcano:'<path d="M2 21 9 9h6l7 12zM11 2h2v4h-2zM6.3 4.5l1.4-1.4 2 2-1.4 1.4zM16.3 4.1l1.4 1.4-2 2-1.4-1.4z"/>',
  dam:'<path d="M3 4h18v6H3zM3 14q2.25-2 4.5 0t4.5 0 4.5 0 4.5 0v2q-2.25-2-4.5 0t-4.5 0-4.5 0-4.5 0zM3 19q2.25-2 4.5 0t4.5 0 4.5 0 4.5 0v2q-2.25-2-4.5 0t-4.5 0-4.5 0-4.5 0z"/>',
  coast:'<path d="M2 7q2.5-2 5 0t5 0 5 0 5 0v2.4q-2.5-2-5 0t-5 0-5 0-5 0zM2 12q2.5-2 5 0t5 0 5 0 5 0v2.4q-2.5-2-5 0t-5 0-5 0-5 0zM2 17q2.5-2 5 0t5 0 5 0 5 0v2.4q-2.5-2-5 0t-5 0-5 0-5 0z"/>',
  port:'<path d="M12 2a3 3 0 0 1 1 5.8V9h3v2h-3v8.9c2.9-.4 5-2.4 5.6-4.9H16l3-3 3 3h-1.5c-.8 4-4.3 7-8.5 7s-7.7-3-8.5-7H2l3-3 3 3H5.4c.6 2.5 2.7 4.5 5.6 4.9V11H8V9h3V7.8A3 3 0 0 1 12 2zm0 2a1 1 0 1 0 0 2 1 1 0 0 0 0-2z"/>',
  scenic:'<path d="M9 3 7.2 5H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-3.2L15 3zm3 5a5 5 0 1 1 0 10 5 5 0 0 1 0-10zm0 2.2a2.8 2.8 0 1 0 0 5.6 2.8 2.8 0 0 0 0-5.6z"/>',
  healing:'<circle cx="5" cy="10" r="2.3"/><circle cx="9" cy="5.5" r="2.3"/><circle cx="15" cy="5.5" r="2.3"/><circle cx="19" cy="10" r="2.3"/><path d="M12 11c3 0 7 5 6.5 8-.4 2.2-3.3 1.8-6.5 1.8S5.9 21.2 5.5 19c-.5-3 3.5-8 6.5-8z"/>',
  other:'<path d="M15 11V5l-3-3-3 3v2H3v14h18V11zM7 19H5v-2h2zm0-4H5v-2h2zm0-4H5V9h2zm6 8h-2v-2h2zm0-4h-2v-2h2zm0-4h-2V9h2zm0-4h-2V5h2zm6 12h-2v-2h2zm0-4h-2v-2h2z"/>',
};
const hex = h => [1,3,5].map(i => parseInt(h.substr(i,2),16)/255);
const CAT_RGB = CAT_ORDER.map(k => hex(CAT[k].color));

/* ---------------- 状態 ---------------- */
// S は毎フレーム KEYS から決まる地図の視点。focus/dim は場面の演出で別に動かす
const S = {zoom:1, cx:0, cy:0, tilt:0, spin:0, pillar:0, ox:0, oy:0, alpha:1, rain:0, alert:0, pulse:0, scan:0,
           form:0, focus:-1, dim:0};
const VIEW_FIELDS = ["zoom","cx","cy","tilt","spin","pillar","ox","oy","alpha","rain","alert","pulse","scan"];
let W = innerWidth, H = innerHeight, DPR = Math.min(MOBILE ? 1.5 : 2, devicePixelRatio || 1);
let DATA = null, NAMES = null, PTS = null; // PTS: Float32Array [lat,lng,cat,seed] * n
const fallbackTotal = +document.documentElement.dataset.fallbackTotal || 23000;

/* ---------------- 投影（シェーダーと同じ式） ---------------- */
const LAT0 = 36.2, LNG0 = 137.2, KX = Math.cos(LAT0 * Math.PI / 180);
const baseScale = () => Math.max(Math.min(W, H * 1.25), H * .6) / 20.5 * S.zoom;
function project(lat, lng, out) {
  const b = baseScale();
  const x = (lng - LNG0) * KX * b - S.cx * b, y = -(lat - LAT0) * b - S.cy * b;
  const ca = Math.cos(S.spin), sa = Math.sin(S.spin);
  const rx = x * ca - y * sa, ry = x * sa + y * ca;
  const y3 = ry * Math.cos(S.tilt), z3 = ry * Math.sin(S.tilt);
  const f = 900 / Math.max(120, 900 + z3);
  out[0] = W * .5 + S.ox * W + rx * f; out[1] = H * .52 + S.oy * H + y3 * f; out[2] = f;
  return out;
}

/* ---------------- WebGL の光点 ---------------- */
const glc = $("#gl");
const GL = (() => {
  if (REDUCED) return null;
  const gl = glc.getContext("webgl", {antialias:false, alpha:false, premultipliedAlpha:false, powerPreference:"high-performance"});
  if (!gl) return null;
  const VS = `
attribute vec2 a_pos; attribute vec4 a_meta; attribute vec3 a_col; attribute float a_end;
uniform vec2 u_res, u_off; uniform float u_base, u_cx, u_cy, u_spin, u_tilt, u_form, u_time, u_focus, u_dim, u_alpha, u_size, u_pillar, u_pulse, u_dpr, u_scan;
varying vec4 v_col; varying float v_flash;
void main(){
  float cat=a_meta.x, seed=a_meta.y;
  float x=(a_pos.y-137.2)*${KX.toFixed(6)}*u_base-u_cx*u_base;
  float y=-(a_pos.x-36.2)*u_base-u_cy*u_base;
  float ca=cos(u_spin), sa=sin(u_spin);
  float rx=x*ca-y*sa, ry=x*sa+y*ca;
  float y3=ry*cos(u_tilt), z3=ry*sin(u_tilt);
  float f=900./max(120.,900.+z3);
  vec2 p=vec2(u_res.x*.5+u_off.x+rx*f, u_res.y*.52+u_off.y+y3*f);
  float e=clamp((u_form-seed*.55)/.45,0.,1.); e=1.-pow(1.-e,3.);
  p=mix(a_meta.zw*u_res,p,e);
  p.y-=(5.+26.*(.5+.5*sin(seed*61.+u_time*1.3)))*u_pillar*f*a_end;
  gl_Position=vec4(p.x/u_res.x*2.-1.,1.-p.y/u_res.y*2.,0.,1.);
  bool on=u_focus<0.||abs(cat-u_focus)<.5;
  float a=on?1.:(.05+.95*(1.-u_dim));
  float tw=.72+.28*sin(u_time*(.8+seed*2.)+seed*40.);
  float fl=pow(max(0.,sin(u_time*.45+seed*917.)),80.);
  v_flash=fl*e;
  float hl=(on&&u_focus>=0.)?u_dim:0.;
  float sx=mod(u_time*.16,1.4)*u_res.x-.2*u_res.x; float sb=u_scan*exp(-pow((p.x-sx)/(u_res.x*.03),2.));
  v_flash=max(v_flash,sb*.8);
  v_col=vec4(a_col,u_alpha*a*tw*(1.+hl*.6+sb*1.4)*(.35+.65*e));
  float sz=u_size*clamp(u_base/52.,.75,2.6)*f*(1.+hl*.7)*(1.+u_pulse*.45*(.5+.5*sin(u_time*2.6-a_pos.x*.35)));
  gl_PointSize=(sz*3.2+fl*14.)*u_dpr;
}`;
  const FS_P = `precision mediump float; varying vec4 v_col; varying float v_flash;
void main(){ vec2 d=gl_PointCoord-.5; float r=length(d)*2.; if(r>1.) discard;
  float core=smoothstep(.34,.14,r); float glow=exp(-r*r*7.)*.3;
  float a=(core*.85+glow)*v_col.a*.62; vec3 c=mix(v_col.rgb,vec3(1.),core*.3+v_flash*.7);
  gl_FragColor=vec4(c*a,1.); }`;
  const FS_L = `precision mediump float; varying vec4 v_col; varying float v_flash;
void main(){ gl_FragColor=vec4(v_col.rgb*v_col.a*.32,1.); }`;
  function prog(fs) {
    const p = gl.createProgram();
    for (const [t, src] of [[gl.VERTEX_SHADER, VS], [gl.FRAGMENT_SHADER, fs]]) {
      const s = gl.createShader(t); gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) { console.warn(gl.getShaderInfoLog(s)); return null; }
      gl.attachShader(p, s);
    }
    gl.linkProgram(p);
    return gl.getProgramParameter(p, gl.LINK_STATUS) ? p : null;
  }
  const pP = prog(FS_P), pL = prog(FS_L);
  if (!pP || !pL) return null;
  let nPts = 0, nLines = 0; const bufP = gl.createBuffer(), bufL = gl.createBuffer();
  const STRIDE = 10; // pos2 meta4 col3 end1
  function upload(pts) {
    const n = pts.length / 4; nPts = n;
    const a = new Float32Array(n * STRIDE);
    const lines = []; let rnd = 7;
    const r = () => (rnd = (rnd * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < n; i++) {
      const lat = pts[i*4], lng = pts[i*4+1], cat = pts[i*4+2], seed = pts[i*4+3], c = CAT_RGB[cat];
      a.set([lat, lng, cat, seed, r(), r(), c[0], c[1], c[2], 0], i * STRIDE);
      if (i % 3 === 0) lines.push(i);
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, bufP); gl.bufferData(gl.ARRAY_BUFFER, a, gl.STATIC_DRAW);
    const b = new Float32Array(lines.length * 2 * STRIDE);
    lines.forEach((i, k) => {
      const src = a.subarray(i * STRIDE, i * STRIDE + STRIDE);
      b.set(src, k * 2 * STRIDE); b.set(src, (k * 2 + 1) * STRIDE); b[(k * 2 + 1) * STRIDE + 9] = 1;
    });
    nLines = lines.length * 2;
    gl.bindBuffer(gl.ARRAY_BUFFER, bufL); gl.bufferData(gl.ARRAY_BUFFER, b, gl.STATIC_DRAW);
  }
  function attribs(p, buf) {
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    const F = 4, st = STRIDE * F;
    [["a_pos",2,0],["a_meta",4,2],["a_col",3,6],["a_end",1,9]].forEach(([n, sz, off]) => {
      const loc = gl.getAttribLocation(p, n); if (loc < 0) return;
      gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, sz, gl.FLOAT, false, st, off * F);
    });
  }
  const U = {};
  function uniforms(p, t) {
    const u = n => (U[p] ||= {})[n] ??= gl.getUniformLocation(p, n);
    gl.uniform2f(u("u_res"), W, H); gl.uniform2f(u("u_off"), S.ox * W, S.oy * H);
    gl.uniform1f(u("u_base"), baseScale()); gl.uniform1f(u("u_cx"), S.cx); gl.uniform1f(u("u_cy"), S.cy);
    gl.uniform1f(u("u_spin"), S.spin); gl.uniform1f(u("u_tilt"), S.tilt); gl.uniform1f(u("u_form"), S.form);
    gl.uniform1f(u("u_time"), t); gl.uniform1f(u("u_focus"), S.focus); gl.uniform1f(u("u_dim"), S.dim);
    gl.uniform1f(u("u_alpha"), S.alpha); gl.uniform1f(u("u_size"), MOBILE ? 1.15 : 1.25); gl.uniform1f(u("u_pillar"), S.pillar);
    gl.uniform1f(u("u_pulse"), S.pulse); gl.uniform1f(u("u_dpr"), DPR); gl.uniform1f(u("u_scan"), S.scan);
  }
  function resize() { glc.width = W * DPR; glc.height = H * DPR; gl.viewport(0, 0, glc.width, glc.height); }
  function draw(t) {
    gl.clearColor(3/255, 6/255, 13/255, 1); gl.clear(gl.COLOR_BUFFER_BIT);
    if (!nPts) return;
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE);
    if (S.pillar > .01) { gl.useProgram(pL); attribs(pL, bufL); uniforms(pL, t); gl.drawArrays(gl.LINES, 0, nLines); }
    gl.useProgram(pP); attribs(pP, bufP); uniforms(pP, t); gl.drawArrays(gl.POINTS, 0, nPts);
  }
  return {upload, resize, draw};
})();

/* 2D の代替描画（WebGL が使えない環境・動きを減らす設定） */
const ctx2 = GL ? null : glc.getContext("2d");
function draw2D() {
  if (!ctx2 || !PTS) return;
  ctx2.setTransform(DPR,0,0,DPR,0,0); ctx2.fillStyle = "#03060D"; ctx2.fillRect(0,0,W,H);
  const o = [0,0,0];
  for (let i = 0; i < PTS.length; i += 4) {
    project(PTS[i], PTS[i+1], o); const c = CAT[CAT_ORDER[PTS[i+2]]].color;
    ctx2.globalAlpha = S.alpha * .9; ctx2.fillStyle = c; ctx2.fillRect(o[0]-1, o[1]-1, 2, 2);
  }
  ctx2.globalAlpha = 1;
}

/* ---------------- 重ね描き（格子・更新の波紋・警報の輪） ---------------- */
const fxc = $("#fx"), fx = fxc.getContext("2d");
const pings = [];
const ALERT_SPOTS = [[26.6,128.2,"#FF5A47"],[32.8,130.7,"#B36BFF"],[35.3,136.9,"#3D8BFF"],[37.4,138.9,"#FFB547"]];
function drawFx(t) {
  fx.setTransform(DPR,0,0,DPR,0,0); fx.clearRect(0,0,W,H);
  const o = [0,0,0], o2 = [0,0,0];
  // 経緯線
  fx.globalAlpha = .07 * S.alpha * S.form; fx.strokeStyle = "#7da3ff"; fx.lineWidth = 1; fx.beginPath();
  for (let la = 24; la <= 46; la += 2) { project(la,122.5,o); project(la,148.5,o2); fx.moveTo(o[0],o[1]); fx.lineTo(o2[0],o2[1]); }
  for (let lo = 122; lo <= 148; lo += 2) { project(24,lo,o); project(46,lo,o2); fx.moveTo(o[0],o[1]); fx.lineTo(o2[0],o2[1]); }
  fx.stroke();
  // 画像が更新されたカメラの波紋
  if (PTS && S.form > .95 && S.alpha > .3 && Math.random() < (MOBILE ? .12 : .22)) {
    const i = (Math.random() * PTS.length / 4 | 0) * 4;
    if (S.focus < 0 || PTS[i+2] === S.focus) pings.push({i, t});
  }
  for (let k = pings.length - 1; k >= 0; k--) {
    const p = pings[k], age = (t - p.t) / 1.6;
    if (age > 1) { pings.splice(k, 1); continue; }
    project(PTS[p.i], PTS[p.i+1], o);
    fx.globalAlpha = (1 - age) * .7 * S.alpha; fx.strokeStyle = CAT[CAT_ORDER[PTS[p.i+2]]].color;
    fx.beginPath(); fx.arc(o[0], o[1], 2 + age * 18 * o[2], 0, 6.283); fx.stroke();
  }
  // 「いま起きていること」場面の発表地点
  if (S.alert > .01) {
    for (const [la, lo, c] of ALERT_SPOTS) {
      project(la, lo, o);
      for (let r = 0; r < 3; r++) {
        const ph = ((t * .5 + r / 3) % 1);
        fx.globalAlpha = S.alert * (1 - ph) * .8; fx.strokeStyle = c; fx.lineWidth = 1.5;
        fx.beginPath(); fx.arc(o[0], o[1], 6 + ph * 70, 0, 6.283); fx.stroke();
      }
      fx.globalAlpha = S.alert; fx.fillStyle = c; fx.beginPath(); fx.arc(o[0], o[1], 4, 0, 6.283); fx.fill();
    }
    fx.lineWidth = 1;
  }
  fx.globalAlpha = 1;
}

/* ---------------- 雨雲レーダー（雨の場面） ---------------- */
const rdc = $("#radar"), rd = rdc.getContext("2d");
const RAMP = ["#A0D2FF","#218CFF","#0041FF","#FAF500","#FF9900","#FF2800","#B40068"];
let storms = [];
function makeStorms() {
  let s = 11; const r = () => (s = (s * 16807) % 2147483647) / 2147483647;
  storms = Array.from({length: 22}, () => {
    const pow = r(), cells = Array.from({length: 9 + (r() * 8 | 0)}, (_, k) => ({dx: (r() - .5) * 1.6, dy: (r() - .5) * .9, rad: .12 + r() * .38, pow: Math.max(0, pow - r() * .5)}));
    return {lat: 30.5 + r() * 9, lng: 127.5 + r() * 12, vx: .18 + r() * .25, ph: r() * 6, cells};
  });
}
function drawRadar(t) {
  const on = S.rain > .01;
  rdc.style.opacity = on ? (S.rain * .9).toFixed(3) : "0";
  if (!on) return;
  const q = 4, w = Math.ceil(W / q), h = Math.ceil(H / q);
  if (rdc.width !== w) { rdc.width = w; rdc.height = h; }
  rd.clearRect(0, 0, w, h);
  const o = [0,0,0], b = baseScale();
  for (const st of storms) {
    const lng0 = 127.5 + ((st.lng - 127.5 + t * st.vx * .25) % 13), lat0 = st.lat + Math.sin(t * .2 + st.ph) * .25;
    for (const c of st.cells) {
      project(lat0 + c.dy, lng0 + c.dx, o);
      const rr = c.rad * b * KX * o[2] * (1 + .2 * Math.sin(t * .8 + st.ph + c.dx * 3)) / q, x = o[0] / q, y = o[1] / q;
      if (x < -rr || x > w + rr || y < -rr || y > h + rr) continue;
      const top = Math.round(1 + c.pow * 5.4), g = rd.createRadialGradient(x, y, 0, x, y, rr);
      for (let k = 0; k <= top; k++) g.addColorStop(k / (top + 1.4), RAMP[top - k]);
      g.addColorStop(1, "rgba(160,210,255,0)");
      rd.globalAlpha = .7; rd.fillStyle = g; rd.beginPath(); rd.arc(x, y, rr, 0, 6.283); rd.fill();
    }
  }
}

/* ---------------- 雨粒 ---------------- */
const dpc = $("#drops"), dp = dpc.getContext("2d");
let drops = [];
function dropsResize() {
  dpc.width = W * DPR; dpc.height = H * DPR; dp.setTransform(DPR,0,0,DPR,0,0);
  drops = Array.from({length: Math.round(W / (MOBILE ? 5 : 3))}, () => ({x: Math.random() * W * 1.2, y: Math.random() * H, v: 16 + Math.random() * 18, l: 14 + Math.random() * 26, a: .25 + Math.random() * .5}));
}
function drawDrops() {
  if (S.rain < .01) return;
  dp.clearRect(0, 0, W, H); dp.lineWidth = 1;
  for (const d of drops) {
    d.y += d.v; d.x -= d.v * .2; if (d.y > H + 30) { d.y = -30; d.x = Math.random() * W * 1.25; }
    dp.strokeStyle = `rgba(185,210,255,${d.a})`; dp.beginPath(); dp.moveTo(d.x, d.y); dp.lineTo(d.x + d.l * .2, d.y - d.l); dp.stroke();
  }
}

/* ---------------- レイヤーの板（実際のカメラ位置から描く） ---------------- */
function planeProj(w, h) {
  const la0 = 30.6, la1 = 45.6, lo0 = 128.6, lo1 = 146.2, s = h / (la1 - la0) * .98;
  const offx = (w - (lo1 - lo0) * KX * s) / 2 + w * .02;
  return (lat, lng) => [offx + (lng - lo0) * KX * s, (la1 - lat) * s + h * .01];
}
function noise(x, y) { // 値ノイズ（軽量）
  const f = (i, j) => { const s = Math.sin(i * 127.1 + j * 311.7) * 43758.5453; return s - Math.floor(s); };
  const i = Math.floor(x), j = Math.floor(y), u = x - i, v = y - j, sm = t => t * t * (3 - 2 * t);
  return lerp(lerp(f(i,j), f(i+1,j), sm(u)), lerp(f(i,j+1), f(i+1,j+1), sm(u)), sm(v));
}
function drawPlane(kind, cv) {
  const w = cv.width, h = cv.height, c = cv.getContext("2d"), P = planeProj(w, h);
  const each = fn => { for (let i = 0; i < PTS.length; i += 4) { const [x, y] = P(PTS[i], PTS[i+1]); if (x > -5 && x < w + 5 && y > -5 && y < h + 5) fn(x, y, PTS[i+2], PTS[i+3], i); } };
  if (kind === 0) { // 雨雲レーダー
    c.fillStyle = "#06122a"; c.fillRect(0,0,w,h);
    each((x,y) => { c.fillStyle = "rgba(120,160,230,.35)"; c.fillRect(x-.6,y-.6,1.3,1.3); });
    let s = 5; const r = () => (s = (s * 16807) % 2147483647) / 2147483647;
    c.globalCompositeOperation = "lighter";
    for (let k = 0; k < 26; k++) {
      const x = w * (.1 + r() * .75), y = h * (.25 + r() * .65), rr = w * (.03 + r() * .09), top = 2 + (r() * 4.6 | 0);
      const g = c.createRadialGradient(x, y, 0, x, y, rr);
      for (let q = 0; q <= top; q++) g.addColorStop(q / (top + 1), RAMP[top - q]);
      g.addColorStop(1, "rgba(0,0,0,0)"); c.globalAlpha = .55; c.fillStyle = g; c.beginPath(); c.arc(x, y, rr, 0, 6.283); c.fill();
    }
    c.globalCompositeOperation = "source-over"; c.globalAlpha = 1;
  } else if (kind === 1) { // キキクル: 河川カメラの位置を危険度で塗る
    c.fillStyle = "#0b1322"; c.fillRect(0,0,w,h);
    const lv = ["#F2E700","#FF2800","#AA00AA","#0C000C"];
    each((x,y,cat) => {
      const n = noise(x / 46, y / 46);
      if (cat !== 0) { c.fillStyle = "rgba(180,195,220,.18)"; c.fillRect(x-.6,y-.6,1.2,1.2); return; }
      const k = n > .82 ? 2 : n > .7 ? 1 : n > .56 ? 0 : -1;
      c.fillStyle = k < 0 ? "rgba(255,255,255,.55)" : lv[k]; c.beginPath(); c.arc(x, y, k < 0 ? 1 : 2.1, 0, 6.283); c.fill();
    });
  } else if (kind === 2) { // ハザードマップ: 平野（カメラが密な所）を浸水想定の色で
    c.fillStyle = "#eef1f5"; c.fillRect(0,0,w,h);
    c.globalCompositeOperation = "multiply";
    each((x,y,cat,seed) => { const n = noise(x / 30 + 9, y / 30); c.fillStyle = n > .55 ? "rgba(214,90,170,.06)" : "rgba(247,181,210,.06)"; c.beginPath(); c.arc(x, y, 7 + seed * 6, 0, 6.283); c.fill(); });
    c.globalCompositeOperation = "source-over";
    each((x,y) => { c.fillStyle = "rgba(40,40,60,.55)"; c.fillRect(x-.5,y-.5,1,1); });
  } else if (kind === 3) { // 昔の地図
    c.fillStyle = "#e4d9bf"; c.fillRect(0,0,w,h);
    for (let k = 0; k < 2600; k++) { c.fillStyle = `rgba(90,70,40,${Math.random()*.06})`; c.fillRect(Math.random()*w, Math.random()*h, 1.5, 1.5); }
    c.strokeStyle = "rgba(110,80,40,.22)"; c.lineWidth = .8;
    each((x,y,cat,seed,i) => { if (i % 36) return; for (let q = 1; q <= 3; q++) { c.beginPath(); c.ellipse(x, y, q * 4 + seed * 4, q * 2.6 + seed * 3, seed * 3, 0, 6.283); c.stroke(); } });
    each((x,y) => { c.fillStyle = "rgba(50,35,20,.7)"; c.fillRect(x-.5,y-.5,1,1); });
    c.fillStyle = "rgba(50,35,20,.85)"; c.font = `600 ${Math.round(w/38)}px "Zen Old Mincho",serif`;
    const lb = [[35.68,139.76,"東京"],[34.69,135.5,"大阪"],[35.17,136.9,"名古屋"],[43.06,141.35,"札幌"],[33.59,130.4,"福岡"],[38.27,140.87,"仙臺"]];
    for (const [la, lo, s] of lb) { const [x, y] = P(la, lo); c.fillText(s, x + 6, y - 4); }
    c.font = `700 ${Math.round(w/30)}px "Zen Old Mincho",serif`; c.fillText("明治四十二年", w * .06, h * .92);
  } else { // 道路の通行止め
    c.fillStyle = "#0d1421"; c.fillRect(0,0,w,h);
    const road = []; each((x,y,cat) => { if (cat === 1) road.push([x, y]); });
    road.sort((a, b) => a[0] - b[0]);
    c.strokeStyle = "rgba(160,175,200,.28)"; c.lineWidth = 1;
    const cols = ["#3D8BFF","#9C6B3A","#B36BFF"];
    for (let i = 0; i < road.length; i++) {
      for (let j = i + 1; j < Math.min(road.length, i + 14); j++) {
        const dx = road[j][0] - road[i][0], dy = road[j][1] - road[i][1], d = dx*dx + dy*dy;
        if (d > 0 && d < (w * .022) ** 2) { c.beginPath(); c.moveTo(road[i][0], road[i][1]); c.lineTo(road[j][0], road[j][1]); c.stroke();
          if (noise(road[i][0] / 40, road[i][1] / 40) > .8) { c.save(); c.strokeStyle = cols[(i + j) % 3]; c.lineWidth = 3; c.beginPath(); c.moveTo(road[i][0], road[i][1]); c.lineTo(road[j][0], road[j][1]); c.stroke(); c.restore(); } }
      }
    }
  }
}

/* 番組表の小さな地図 */
function drawMini(cv, cat, color) {
  const w = cv.width, h = cv.height, c = cv.getContext("2d"), P = planeProj(w, h);
  c.clearRect(0,0,w,h);
  for (let i = 0; i < PTS.length; i += 4) {
    const [x, y] = P(PTS[i], PTS[i+1]); const hit = cat === -2 ? (i % 3 === 0) : cat === -1 ? false : PTS[i+2] === cat;
    c.fillStyle = hit ? color : "rgba(160,180,220,.13)"; c.globalAlpha = hit ? .9 : 1; c.fillRect(x - .7, y - .7, hit ? 1.8 : 1.2, hit ? 1.8 : 1.2);
  }
  if (cat === -1) { // ルート（東京→名古屋→大阪）
    const route = [[35.68,139.77],[35.45,139.3],[35.1,138.85],[34.97,138.39],[34.7,137.73],[35.17,136.88],[35.0,135.95],[34.7,135.5]];
    c.globalAlpha = 1; c.strokeStyle = color; c.lineWidth = 2.5; c.lineJoin = "round"; c.beginPath();
    route.forEach(([la, lo], k) => { const [x, y] = P(la, lo); k ? c.lineTo(x, y) : c.moveTo(x, y); }); c.stroke();
    for (let i = 0; i < PTS.length; i += 4) {
      const la = PTS[i], lo = PTS[i+1]; if (la < 34.5 || la > 35.9 || lo < 135.3 || lo > 139.9) continue;
      const near = route.some(([a, b]) => (a - la) ** 2 + (b - lo) ** 2 < .03);
      if (near) { const [x, y] = P(la, lo); c.fillStyle = "#fff"; c.fillRect(x - 1, y - 1, 2, 2); }
    }
  }
  c.globalAlpha = 1;
}

/* ---------------- 文字分割 ---------------- */
function split(el) {
  const text = el.textContent; el.textContent = ""; el.setAttribute("aria-label", text);
  for (const word of text.split(/(\s+)/)) {
    const w = document.createElement("span"); w.className = "w"; w.setAttribute("aria-hidden", "true");
    for (const ch of word) { const s = document.createElement("span"); s.className = "ch"; s.textContent = ch === " " ? " " : ch; w.appendChild(s); }
    el.appendChild(w);
  }
  const chs = el.querySelectorAll(".ch");
  if (el.dataset.grad) { // 1文字ずつ動かす span には background-clip が効かないので色を補間して塗る
    const st = el.dataset.grad.split(",").map(hx => [1,3,5].map(i => parseInt(hx.trim().substr(i,2),16)));
    chs.forEach((c, i) => { const t = chs.length > 1 ? i / (chs.length - 1) : 0, seg = t * (st.length - 1), k = Math.min(st.length - 2, Math.floor(seg)), f = seg - k;
      c.style.color = `rgb(${st[k].map((v, j) => Math.round(v + (st[k+1][j] - v) * f))})`; });
  }
  return chs;
}
$$(".split").forEach(split);

/* 文字が入れ替わるときの走査（チャンネル名・大きな英字） */
const GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#/·";
function scramble(el, to, dur = .6) {
  if (REDUCED || !window.gsap) { el.textContent = to; return; }
  const from = el.textContent, len = Math.max(from.length, to.length), o = {p: 0};
  gsap.killTweensOf(el._sc || {}); el._sc = o;
  gsap.to(o, {p: 1, duration: dur, ease: "none", onUpdate: () => {
    let s = ""; for (let i = 0; i < len; i++) { const th = i / len; s += o.p > th + .25 ? (to[i] || "") : o.p > th ? GLYPHS[Math.random() * GLYPHS.length | 0] : (from[i] || ""); }
    el.textContent = s;
  }, onComplete: () => { el.textContent = to; }});
}

/* ---------------- 部品の組み立て ---------------- */
const catList = $("#catList");
CAT_ORDER.forEach((k, i) => {
  const li = document.createElement("li"); li.className = "cat"; li.style.setProperty("--c", CAT[k].color);
  li.innerHTML = `<span class="ic" style="background:${CAT[k].color}"><svg viewBox="0 0 24 24" aria-hidden="true">${ICON[k]}</svg></span><div><h3>${CAT[k].ja}</h3><p>${CAT[k].d}</p></div><span class="no">CH.${String(i+1).padStart(2,"0")} ${CAT[k].en}</span>`;
  catList.appendChild(li);
});
const PLANES = ["01 · NOWCAST","02 · KIKIKURU","03 · HAZARD","04 · 1909","05 · ROAD CLOSED"];
const stack = $("#stack");
PLANES.forEach(tag => { const d = document.createElement("div"); d.className = "plane"; d.innerHTML = `<canvas width="800" height="525"></canvas><span class="tag">${tag}</span>`; stack.appendChild(d); });
const ldBars = $("#ldBars"); for (let i = 0; i < 28; i++) ldBars.appendChild(document.createElement("span"));

function buildTicker(list) {
  const tr = $("#ticker");
  const html = list.map(([n, p, c]) => `<span class="item"><i style="background:${CAT[CAT_ORDER[c]].color};color:${CAT[CAT_ORDER[c]].color}"></i><b>${n.replace(/[<>&]/g, "")}</b><small>${p}${p ? " · " : ""}${CAT[CAT_ORDER[c]].en}</small></span>`).join("");
  tr.innerHTML = html + html;
}
buildTicker([["渋谷スクランブル交差点","東京",8],["富士山","山梨",6],["桜島","鹿児島",2],["多摩川","東京",0],["宮ヶ瀬ダム","神奈川",3],["大洗海岸","茨城",4]]);

/* ---------------- データ ---------------- */
const dataReady = fetch("lp/data.json").then(r => r.json()).then(d => {
  DATA = d; const pts = d.pts, n = pts.length / 3; PTS = new Float32Array(n * 4);
  let s = 3; const r = () => (s = (s * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < n; i++) PTS.set([(pts[i*3] + 1200) / 50, (pts[i*3+1] + 6100) / 50, pts[i*3+2], r()], i * 4);
}).catch(() => {
  // データが取れないときは日本付近の乱数（演出だけは崩さない）
  PTS = new Float32Array(6000 * 4); for (let i = 0; i < 6000; i++) PTS.set([31 + Math.random() * 13, 130 + Math.random() * 12, Math.random() * 9 | 0, Math.random()], i * 4);
});
const fontsReady = Promise.race([document.fonts ? document.fonts.ready : Promise.resolve(), new Promise(r => setTimeout(r, 3500))]);

/* ---------------- 画面寸法 ---------------- */
function resize() {
  W = innerWidth; H = innerHeight;
  if (GL) GL.resize(); else if (ctx2) { glc.width = W * DPR; glc.height = H * DPR; }
  fxc.width = W * DPR; fxc.height = H * DPR; dropsResize();
}
addEventListener("resize", () => { resize(); if (window.ScrollTrigger) ScrollTrigger.refresh(); });
resize(); makeStorms();

/* ---------------- 視点のキーフレーム ---------------- */
// [位置の関数, 値]。値は [PC, スマホ] の組でもよい。位置は scrollY
let KEYS = [];
function buildKeys() {
  const top = id => { const e = document.getElementById(id); return e.getBoundingClientRect().top + scrollY; };
  const span = id => { const e = document.getElementById(id); return Math.max(1, e.offsetHeight - H); };
  const at = (id, f) => top(id) + f * span(id);
  const near = (id, f) => top(id) - H + f * (document.getElementById(id).offsetHeight + H);
  const home = {zoom:1, cx:0, cy:0, tilt:0, spin:0, pillar:0, ox:[.14, 0], oy:[0, -.1], alpha:1, rain:0, alert:0, pulse:0, scan:1};
  const k = (pos, v) => KEYS.push({pos, v: {...v}});
  KEYS = [];
  k(0, home);
  k(at("hero", .1), home);
  k(at("hero", .5), {zoom:[2.6, 2.4], cx:2.0, cy:.55, tilt:1.02, spin:-.24, pillar:1, ox:0, oy:.06, alpha:.8, rain:0, alert:0, pulse:0});
  k(at("hero", .72), {zoom:2.1, cx:1.4, cy:.3, tilt:.7, spin:-.12, pillar:.7, ox:0, oy:.03, alpha:1, rain:0, alert:0, pulse:0});
  const catsV = {zoom:[1.12, 1.05], cx:0, cy:0, tilt:0, spin:0, pillar:0, ox:[.2, 0], oy:[0, .12], alpha:1, rain:0, alert:0, pulse:0};
  k(at("hero", 1), catsV);
  k(near("rain", .06), catsV);
  k(at("rain", .08), {zoom:2.1, cx:-3.2, cy:2.1, tilt:.42, spin:.06, pillar:0, ox:0, oy:0, alpha:.6, rain:1, alert:0, pulse:0});
  k(at("rain", .84), {zoom:2.5, cx:-2.4, cy:1.6, tilt:.5, spin:.1, pillar:0, ox:0, oy:0, alpha:.6, rain:1, alert:0, pulse:0});
  const dimV = {zoom:1, cx:0, cy:0, tilt:0, spin:0, pillar:0, ox:[-.16, 0], oy:0, alpha:.2, rain:0, alert:0, pulse:0};
  k(at("rain", 1), dimV);
  k(at("layers", 1), {...dimV, ox:0});
  k(at("screens", .05), {...dimV, ox:0, zoom:.9, alpha:.14});
  k(at("screens", .97), {...dimV, ox:0, zoom:1.05, alpha:.14});
  k(near("alert", .3), {zoom:1, cx:-.6, cy:.6, tilt:.2, spin:0, pillar:0, ox:0, oy:0, alpha:.55, rain:0, alert:1, pulse:0});
  k(near("alert", .72), {zoom:1, cx:-.6, cy:.6, tilt:.2, spin:0, pillar:0, ox:0, oy:0, alpha:.55, rain:0, alert:1, pulse:0});
  const calm = {zoom:1.05, cx:0, cy:0, tilt:0, spin:0, pillar:0, ox:[.18, 0], oy:0, alpha:.32, rain:0, alert:0, pulse:0};
  k(near("stats", .5), calm);
  k(near("faq", .9), calm);
  k(near("dl", .55), {zoom:[1, .95], cx:0, cy:0, tilt:0, spin:.06, pillar:0, ox:0, oy:0, alpha:.7, rain:0, alert:0, pulse:1, scan:1});
  k(1e9, {zoom:[1, .95], cx:0, cy:0, tilt:0, spin:.06, pillar:0, ox:0, oy:0, alpha:.7, rain:0, alert:0, pulse:1, scan:1});
  KEYS.sort((a, b) => a.pos - b.pos);
}
const ease = t => t < .5 ? 4*t*t*t : 1 - Math.pow(-2*t + 2, 3) / 2;
const pick = v => Array.isArray(v) ? v[MOBILE ? 1 : 0] : v;
const TARGET = {};
function viewAt(y) {
  if (!KEYS.length) return;
  let i = KEYS.findIndex(k => k.pos > y); if (i <= 0) i = i === 0 ? 1 : KEYS.length - 1;
  const a = KEYS[i-1], b = KEYS[i], t = ease(clamp((y - a.pos) / Math.max(1, b.pos - a.pos), 0, 1));
  for (const f of VIEW_FIELDS) TARGET[f] = lerp(pick(a.v[f] ?? 0), pick(b.v[f] ?? 0), t);
}

/* ---------------- HUD ---------------- */
const clock = $("#clock");
setInterval(() => { const d = new Date(Date.now() + 9 * 3600e3); clock.textContent = "JST " + d.toISOString().substr(11,8) + " · " + d.toISOString().substr(0,10).replace(/-/g, "."); }, 250);
const coord = $("#coord"), tcEl = $("#tc"), chanEl = $("#chan"), railI = $("#rail i");
function hudScroll() {
  const max = document.documentElement.scrollHeight - H, p = clamp(scrollY / Math.max(1, max), 0, 1);
  railI.style.transform = `scaleY(${p})`;
  const fr = Math.round(p * 180 * 30), f = fr % 30, s = Math.floor(fr / 30) % 60, m = Math.floor(fr / 1800);
  tcEl.textContent = `TC 00:${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}:${String(f).padStart(2,"0")}`;
}

/* ---------------- 照準（カメラ名） ---------------- */
const lens = $(".lens"), lensB = $(".lens b"), lensS = $(".lens small");
let mouse = {x: -1, y: -1, moved: false}, lensOn = false;
if (!HOVER && !REDUCED) {
  let down = null, hideT = 0;
  addEventListener("pointerdown", e => down = {x: e.clientX, y: e.clientY, t: performance.now()}, {passive: true});
  addEventListener("pointerup", e => {
    if (!down || Math.hypot(e.clientX - down.x, e.clientY - down.y) > 8 || performance.now() - down.t > 400) return;
    if (e.target.closest("a,button,summary,details")) return;
    mouse = {x: e.clientX, y: e.clientY, moved: true}; clearTimeout(hideT); hideT = setTimeout(() => mouse.x = -1, 2600);
  }, {passive: true});
}
if (HOVER && !REDUCED) addEventListener("mousemove", e => {
  mouse = {x: e.clientX, y: e.clientY, moved: true};
  const b = baseScale(), lat = LAT0 - ((e.clientY - H * .52 - S.oy * H) / b + S.cy), lng = LNG0 + ((e.clientX - W * .5 - S.ox * W) / b + S.cx) / KX;
  coord.textContent = `N ${lat.toFixed(4)} · E ${lng.toFixed(4)}`;
}, {passive: true});
function updateLens() {
  const allow = lensOn && NAMES && S.tilt < .08 && S.alpha > .6 && S.form > .98 && mouse.x >= 0;
  if (!allow) { lens.style.opacity = 0; return; }
  if (!mouse.moved) return; mouse.moved = false;
  const o = [0,0,0]; let best = null, bd = 34 * 34; const L = NAMES.lens;
  for (let i = 0; i < L.length; i++) {
    if (S.focus >= 0 && L[i][2] !== S.focus) continue;
    project(L[i][0] / 100, L[i][1] / 100, o); const dx = o[0] - mouse.x, dy = o[1] - mouse.y, d = dx*dx + dy*dy;
    if (d < bd) { bd = d; best = [o[0], o[1], L[i]]; }
  }
  if (!best) { lens.style.opacity = 0; return; }
  const [x, y, e] = best, c = CAT[CAT_ORDER[e[2]]];
  lens.style.transform = `translate(${x}px,${y}px)`; lens.style.setProperty("--c", c.color); lens.style.opacity = 1;
  if (lensB.textContent !== e[3]) { lensB.textContent = e[3]; lensS.textContent = `${c.en} · N ${(e[0]/100).toFixed(2)} E ${(e[1]/100).toFixed(2)}`; Sound.tick(); }
}

/* ---------------- 環境音（WebAudio で合成。既定はオフ） ---------------- */
const Sound = (() => {
  let ac = null, master, rainG, drone, on = false;
  function init() {
    ac = new (window.AudioContext || window.webkitAudioContext)();
    master = ac.createGain(); master.gain.value = 0; master.connect(ac.destination);
    const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 420;
    drone = ac.createGain(); drone.gain.value = .14; lp.connect(drone); drone.connect(master);
    [55, 82.41, 110.3].forEach((f, i) => { const o = ac.createOscillator(); o.type = i === 2 ? "triangle" : "sine"; o.frequency.value = f;
      const lfo = ac.createOscillator(), lg = ac.createGain(); lfo.frequency.value = .07 + i * .05; lg.gain.value = 3; lfo.connect(lg); lg.connect(o.detune); lfo.start();
      const g = ac.createGain(); g.gain.value = i === 2 ? .25 : .5; o.connect(g); g.connect(lp); o.start(); });
    const buf = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const src = ac.createBufferSource(); src.buffer = buf; src.loop = true;
    const hp = ac.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 700;
    const pk = ac.createBiquadFilter(); pk.type = "peaking"; pk.frequency.value = 4200; pk.gain.value = 6;
    rainG = ac.createGain(); rainG.gain.value = 0; src.connect(hp); hp.connect(pk); pk.connect(rainG); rainG.connect(master); src.start();
  }
  function toggle() {
    if (!ac) init(); if (ac.state === "suspended") ac.resume();
    on = !on; master.gain.setTargetAtTime(on ? .55 : 0, ac.currentTime, .25);
    const b = $("#sound"); b.setAttribute("aria-pressed", on); $("#soundLbl").textContent = on ? "SOUND ON" : "SOUND OFF";
  }
  function frame() { if (ac && on) rainG.gain.setTargetAtTime(S.rain * .3, ac.currentTime, .3); }
  function tone(f0, f1, dur, vol, type = "sine") {
    if (!ac || !on) return;
    const o = ac.createOscillator(), g = ac.createGain(); o.type = type; o.frequency.setValueAtTime(f0, ac.currentTime); o.frequency.exponentialRampToValueAtTime(f1, ac.currentTime + dur);
    g.gain.setValueAtTime(vol, ac.currentTime); g.gain.exponentialRampToValueAtTime(.0001, ac.currentTime + dur); o.connect(g); g.connect(master); o.start(); o.stop(ac.currentTime + dur);
  }
  function thunder() {
    if (!ac || !on) return;
    const n = ac.createBufferSource(), buf = ac.createBuffer(1, ac.sampleRate * 2.5, ac.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / d.length, 2);
    n.buffer = buf; const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 160; const g = ac.createGain(); g.gain.value = .9;
    n.connect(lp); lp.connect(g); g.connect(master); n.start();
  }
  return {toggle, frame, tick: () => tone(1800, 1200, .05, .03, "square"), ping: () => { tone(880, 880, .5, .12); setTimeout(() => tone(1320, 1320, .6, .1), 140); }, thunder,
          blip: () => tone(520, 760, .12, .06, "triangle")};
})();
$("#sound").addEventListener("click", Sound.toggle);

/* ---------------- 毎フレーム ---------------- */
const t0 = performance.now(); let visible = true;
document.addEventListener("visibilitychange", () => { visible = !document.hidden; if (visible) requestAnimationFrame(frame); });
function frame(now) {
  if (!visible) return;
  const t = (now - t0) / 1000;
  viewAt(scrollY);
  const k = REDUCED ? 1 : .085;
  for (const f of VIEW_FIELDS) if (TARGET[f] !== undefined) S[f] += (TARGET[f] - S[f]) * k;
  if (GL) GL.draw(t); else draw2D();
  drawFx(t); drawRadar(t); drawDrops(); updateLens(); Sound.frame();
  if (!REDUCED) requestAnimationFrame(frame);
}

/* ---------------- 起動 ---------------- */
Promise.all([dataReady, fontsReady]).then(() => {
  if (GL && PTS) GL.upload(PTS);
  const total = DATA ? DATA.total : fallbackTotal;
  if (DATA) {
    $("#heroTotal").textContent = "約" + fmt(Math.round(DATA.total / 100) * 100);
    $("#riverN").textContent = fmt(Math.floor(DATA.cats.river / 100) * 100);
    $("#catNum").textContent = fmt(DATA.cats.river); $("#catNum").style.color = CAT.river.color;
  }
  $$(".plane canvas").forEach((cv, i) => drawPlane(i, cv));
  $$(".row").forEach(r => drawMini(r.querySelector("canvas"), +r.dataset.cat, getComputedStyle(r).getPropertyValue("--c").trim()));
  fetch("lp/names.json").then(r => r.json()).then(n => { NAMES = n; if (n.ticker && n.ticker.length) buildTicker(n.ticker); }).catch(() => {});
  if (REDUCED || !window.gsap || !window.ScrollTrigger) {
    S.form = 1; document.documentElement.classList.remove("is-loading"); $("#loader")?.remove();
    $("#heroNum").textContent = fmt(total);
    $$("[data-count]").forEach(el => el.textContent = fmt(DATA ? DATA[el.dataset.count] : 0));
    buildKeys(); viewAt(scrollY); Object.assign(S, TARGET); requestAnimationFrame(frame);
    addEventListener("scroll", () => requestAnimationFrame(frame), {passive: true});
    return;
  }
  start(total);
});

function countTo(el, to, dur, delay = 0) {
  const o = {v: parseFloat((el.textContent || "0").replace(/,/g, "")) || 0};
  return gsap.to(o, {v: to, duration: dur, delay, ease: "power3.out", onUpdate: () => el.textContent = fmt(o.v)});
}

function start(total) {
  gsap.registerPlugin(ScrollTrigger);
  const lenis = new Lenis({lerp: .085, smoothWheel: true});
  lenis.on("scroll", ScrollTrigger.update);
  gsap.ticker.add(t => lenis.raf(t * 1000)); gsap.ticker.lagSmoothing(0);
  $$('a[href^="#"]').forEach(a => a.addEventListener("click", e => { e.preventDefault(); lenis.scrollTo(a.getAttribute("href"), {duration: 2.2}); }));
  buildKeys(); ScrollTrigger.addEventListener("refresh", buildKeys);
  viewAt(0); Object.assign(S, TARGET);
  requestAnimationFrame(frame);

  /* ---- ローダー → 絞りが開く ---- */
  const ldNum = $("#ldNum"), ln = {v: 0}, bars = $$("#ldBars span");
  const barTw = gsap.to(bars, {scaleY: () => .2 + Math.random() * .8, opacity: () => .3 + Math.random() * .6, duration: .12, repeat: -1, repeatRefresh: true, stagger: {each: .02, from: "random"}});
  const intro = gsap.timeline();
  intro.to(ln, {v: total, duration: 1.25, ease: "power3.inOut", onUpdate: () => ldNum.textContent = String(Math.round(ln.v)).padStart(5, "0")})
    .add(() => { document.documentElement.classList.remove("is-loading"); barTw.kill(); })
    .to("#loader", {clipPath: "circle(0% at 50% 52%)", duration: 1.1, ease: "expo.inOut"}, "+=.15")
    .set("#loader", {display: "none"})
    .addLabel("in", "-=.75")
    .to(S, {form: 1, duration: 2.8, ease: "power2.out"}, "in-=.2")
    .fromTo(".hero-title > span:first-child .ch", {yPercent: 115, rotate: 6, opacity: 0}, {yPercent: 0, rotate: 0, opacity: 1, duration: 1.1, stagger: .035, ease: "expo.out"}, "in+=.15")
    .fromTo(".hero-title > span:last-child .ch", {yPercent: 115, rotate: -6, opacity: 0}, {yPercent: 0, rotate: 0, opacity: 1, duration: 1.1, stagger: .035, ease: "expo.out"}, "in+=.45")
    .to(".kicker", {opacity: 1, duration: .8}, "in+=.2")
    .fromTo(".hero-lead", {y: 18}, {y: 0, opacity: 1, duration: 1, ease: "power3.out"}, "in+=1")
    .to(".hud,.corner,.hint,.hero-meta,.rail", {opacity: 1, duration: .8, stagger: .04}, "in+=1.1")
    .to(".cta", {opacity: 1, y: 0, duration: .8, ease: "back.out(2)"}, "in+=1.3")
    .add(() => countTo($("#heroNum"), total, 2.2), "in+=1.1");
  $(".cta").style.transform = "translateX(-50%)"; gsap.set(".cta", {xPercent: -50, x: 0, y: -20, left: "50%"});

  /* ---- 場面ごとの HUD（チャンネル名・目盛り） ---- */
  const rail = $("#rail"), maxScroll = () => document.documentElement.scrollHeight - H;
  $$("main > section[data-ch]").forEach(sec => {
    const tick = document.createElement("b"); rail.appendChild(tick);
    const place = () => tick.style.top = (clamp((sec.getBoundingClientRect().top + scrollY) / Math.max(1, maxScroll()), 0, 1) * 100) + "%";
    place(); ScrollTrigger.addEventListener("refresh", place);
    ScrollTrigger.create({trigger: sec, start: "top 55%", end: "bottom 55%", onToggle: s => { tick.classList.toggle("on", s.isActive); if (s.isActive) { scramble(chanEl, "CH " + sec.dataset.ch, .5); Sound.blip(); } }});
  });
  lenis.on("scroll", hudScroll); hudScroll();

  /* ---- ヒーロー: 地図が傾いて関東へ飛ぶ ---- */
  ScrollTrigger.create({trigger: "#hero", start: "top bottom", end: "12% top", onToggle: s => lensOn = s.isActive}); lensOn = scrollY < innerHeight * .3;
  gsap.timeline({scrollTrigger: {trigger: "#hero", start: "top top", end: "bottom bottom", scrub: 1}})
    .to(".hero-copy", {yPercent: -18, opacity: 0, ease: "power2.in", duration: .14}, .02)
    .to(".hero-meta,.hint", {opacity: 0, duration: .08}, .02)
    .to(".fly", {"--scrim": 1, duration: .08}, .17)
    .to(".fly", {"--scrim": 0, duration: .06}, .93)
    .fromTo("#fc1", {opacity: 0, y: 40, filter: "blur(14px)"}, {opacity: 1, y: 0, filter: "blur(0px)", duration: .1}, .2)
    .to("#fc1", {opacity: 0, y: -40, filter: "blur(14px)", duration: .08}, .4)
    .fromTo("#fc2", {opacity: 0, scale: .92, filter: "blur(10px)"}, {opacity: 1, scale: 1, filter: "blur(0px)", duration: .1}, .5)
    .to("#fc2", {opacity: 0, scale: 1.06, duration: .08}, .9);

  /* ---- ON AIR 字幕（スクロールの速さで流れる） ---- */
  const track = $("#ticker"); let mx = 0, vel = 0;
  lenis.on("scroll", e => vel = e.velocity);
  gsap.ticker.add(() => { const w = track.scrollWidth / 2; mx -= 1.1 + Math.abs(vel) * .8; if (-mx > w) mx += w; track.style.transform = `translateX(${mx}px)`; vel *= .92; });

  /* ---- カテゴリ ---- */
  const catNum = $("#catNum"), catName = $("#catName"), catEn = $("#catEn"), items = $$(".cat");
  let cur = -2;
  function setCat(i) {
    if (i === cur) return; cur = i;
    items.forEach((el, j) => el.classList.toggle("on", j === i));
    gsap.to(S, {dim: i < 0 ? 0 : 1, duration: .6, ease: "power2.out"}); S.focus = i;
    if (i >= 0) { const k = CAT_ORDER[i]; catNum.style.color = CAT[k].color; catName.textContent = CAT[k].ja; scramble(catEn, CAT[k].en + " · CAMERAS", .45);
      countTo(catNum, DATA ? DATA.cats[k] : 0, .9); Sound.tick(); }
  }
  items.forEach((el, i) => ScrollTrigger.create({trigger: el, start: "top 62%", end: "bottom 62%", onToggle: s => s.isActive && setCat(i)}));
  ScrollTrigger.create({trigger: "#cats", start: "top 70%", end: "bottom 30%", onToggle: s => { lensOn = s.isActive; if (!s.isActive) setCat(-1); }});

  /* ---- 雨 ---- */
  gsap.timeline({scrollTrigger: {trigger: "#rain", start: "top 70%", end: "bottom bottom", scrub: 1}})
    .to(".tint.rain,#drops", {opacity: 1, duration: .1}, 0)
    .to(".radar-legend", {opacity: 1, duration: .06}, .12)
    .fromTo("#r1 .ch", {yPercent: 110, opacity: 0}, {yPercent: 0, opacity: 1, stagger: .015, duration: .1, ease: "back.out(2)"}, .06)
    .to(".flash", {opacity: .85, duration: .012, yoyo: true, repeat: 3, onStart: Sound.thunder}, .2)
    .fromTo("#r2 .ch", {xPercent: -60, opacity: 0, filter: "blur(8px)"}, {xPercent: 0, opacity: 1, filter: "blur(0px)", stagger: .015, duration: .1}, .28)
    .fromTo("#r3 .ch", {scale: 2.2, opacity: 0}, {scale: 1, opacity: 1, stagger: .015, duration: .1, ease: "expo.out"}, .44)
    .to("#rs", {opacity: 1, duration: .08}, .58)
    .to(".tint.rain,#drops", {opacity: 0, duration: .06}, .96);

  /* ---- レイヤー ---- */
  const planes = $$("#stack .plane"), names = $$("#lnames li"), stackH = () => $("#stack").clientHeight, gap = () => stackH() * (MOBILE ? .075 : .1);
  gsap.set(planes, {rotateX: 60, rotateZ: -32, y: () => stackH() * .5, z: 0, opacity: 0});
  const lt = gsap.timeline({scrollTrigger: {trigger: "#layers", start: "top 85%", end: "bottom bottom", scrub: 1,
    onUpdate: s => { const i = Math.min(4, Math.floor(s.progress * 5.6)); names.forEach((n, j) => n.classList.toggle("on", j <= i)); }}});
  lt.fromTo(".layers-copy", {x: -50, opacity: 0}, {x: 0, opacity: 1, duration: .1}, 0);
  planes.forEach((p, i) => lt.to(p, {opacity: 1, y: () => (2 - i) * gap(), z: i * 16, duration: .14, ease: "power3.out"}, .04 + i * .12));
  lt.to(planes, {rotateZ: -20, rotateX: 54, duration: .3}, .66)
    .to(planes, {y: i => (2 - i) * gap() * 1.45, duration: .2}, .7)
    .to(planes, {rotateZ: -14, duration: .1}, .9);  // 最後は消さずに場面ごと上へ流す（次の場面との間に空白を作らない）

  /* ---- スマホ画面: 円で切り替わる ---- */
  const imgs = $$("#scr img"), calls = $$(".callout"), dots = $$("#pdots i"), big = $("#bigword");
  const origins = ["86% 14%", "50% 78%", "20% 30%", "50% 50%", "80% 70%"];
  let shown = -1;
  const st = gsap.timeline({scrollTrigger: {trigger: "#screens", start: "top 90%", end: "bottom bottom", scrub: 1,
    onUpdate: s => { const i = Math.min(4, Math.floor(s.progress * 5)); dots.forEach((d, j) => d.classList.toggle("on", j === i)); if (i !== shown) { shown = i; scramble(big, imgs[i].dataset.k, .5); } }}});
  st.fromTo(".phone", {y: "70vh", rotate: -10, scale: .86}, {y: 0, rotate: 0, scale: 1, duration: .08, ease: "power3.out"}, 0);
  imgs.forEach((im, i) => {
    const a = i * .19 + .02;
    if (i > 0) st.fromTo(im, {clipPath: `circle(0% at ${origins[i]})`}, {clipPath: `circle(150% at ${origins[i]})`, duration: .07, ease: "power2.inOut"}, a - .02)
                 .fromTo(".phone .sweep", {yPercent: -130}, {yPercent: 460, duration: .07, ease: "none"}, a - .02);
    st.fromTo(calls[i], {opacity: 0, x: i % 2 ? 50 : -50, filter: "blur(8px)"}, {opacity: 1, x: 0, filter: "blur(0px)", duration: .05}, a + .02)
      .to(calls[i], {opacity: 0, x: i % 2 ? -20 : 20, duration: .04}, a + .15)
      .to(".phone", {rotate: i % 2 ? 3 : -3, duration: .19, ease: "sine.inOut"}, a);
  });
  st.to(".phone", {rotate: 0, scale: .94, duration: .04}, .96);
  gsap.to("#bigword", {xPercent: -12, scrollTrigger: {trigger: "#screens", start: "top bottom", end: "bottom top", scrub: 1}});

  /* ---- いま起きていること ---- */
  const rings = $$(".alert-core .ring");
  gsap.timeline({scrollTrigger: {trigger: "#alert", start: "top 70%", end: "bottom 30%", toggleActions: "play reverse play reverse", onEnter: Sound.ping, onEnterBack: Sound.ping}})
    .to(".tint.alert", {opacity: 1, duration: .8}, 0)
    .fromTo(".alert-core .btn", {scale: 0, rotate: -90}, {scale: 1, rotate: 0, duration: 1, ease: "elastic.out(1,.45)"}, 0)
    .fromTo(".alert-core .badge", {scale: 0}, {scale: 1, duration: .6, ease: "back.out(3)"}, .5)
    .fromTo("#ah .ch", {yPercent: 120, opacity: 0}, {yPercent: 0, opacity: 1, stagger: .03, duration: .8, ease: "expo.out"}, .2)
    .to("#feed div", {opacity: 1, y: 0, stagger: .14, duration: .5}, .7);
  rings.forEach((r, i) => gsap.fromTo(r, {scale: .34, opacity: .9}, {scale: 1.2, opacity: 0, duration: 2.4, repeat: -1, delay: i * .8, ease: "power2.out"}));

  /* ---- 数字 ---- */
  $$("[data-count]").forEach(el => ScrollTrigger.create({trigger: el, start: "top 88%", once: true,
    onEnter: () => { countTo(el, DATA ? DATA[el.dataset.count] : 0, 1.8); el.closest(".stat").classList.add("in"); }}));
  $$(".stat").forEach(s => ScrollTrigger.create({trigger: s, start: "top 88%", once: true, onEnter: () => s.classList.add("in")}));

  /* ---- 番組表・FAQ・ダウンロード ---- */
  $$(".row").forEach((el, i) => {
    gsap.from(el.children, {y: 40, opacity: 0, duration: .9, stagger: .06, ease: "power3.out", scrollTrigger: {trigger: el, start: "top 88%"}});
    ScrollTrigger.create({trigger: el, start: "top 60%", end: "bottom 40%", onToggle: s => el.classList.toggle("lit", s.isActive && !HOVER)});
  });
  gsap.utils.toArray(".guide-head h2, #faq h2, .qa").forEach(el => gsap.from(el, {y: 36, opacity: 0, duration: .9, ease: "power3.out", scrollTrigger: {trigger: el, start: "top 90%"}}));
  gsap.timeline({scrollTrigger: {trigger: "#dl", start: "top 62%"}})
    .fromTo("#dl1 .ch", {yPercent: 130, rotate: 10, opacity: 0}, {yPercent: 0, rotate: 0, opacity: 1, stagger: .06, duration: 1.1, ease: "expo.out"})
    .fromTo("#dl2 .ch", {yPercent: 130, rotate: -10, opacity: 0}, {yPercent: 0, rotate: 0, opacity: 1, stagger: .06, duration: 1.1, ease: "expo.out"}, "<.25")
    .from(".store", {y: 40, opacity: 0, stagger: .12, duration: .8, ease: "back.out(2)"}, "<.4")
    .from(".free", {opacity: 0, letterSpacing: "1em", duration: 1}, "<.2");
  ScrollTrigger.create({trigger: "#dl", start: "top 50%", end: "bottom top", onToggle: s => { lensOn = s.isActive; gsap.to(".cta", {autoAlpha: s.isActive ? 0 : 1, duration: .4}); }});

  /* ---- カーソル・磁石・傾き ---- */
  if (HOVER) {
    const cu = $(".cursor"), lab = $(".cursor span"); let cx = W / 2, cy = H / 2;
    addEventListener("mousemove", e => { cu.style.opacity = 1; gsap.to(cu, {x: e.clientX, y: e.clientY, duration: .18, ease: "power3.out", overwrite: true}); }, {passive: true});
    $$("a,button,summary,.row").forEach(el => {
      el.addEventListener("mouseenter", () => { cu.classList.add("big"); lab.textContent = el.matches("summary") ? "OPEN" : el.matches(".row") ? "WATCH" : el.matches("button") ? "PLAY" : "GO"; Sound.tick(); });
      el.addEventListener("mouseleave", () => cu.classList.remove("big"));
    });
    $$(".magnet").forEach(el => {
      el.addEventListener("mousemove", e => { const r = el.getBoundingClientRect(); gsap.to(el, {x: (e.clientX - r.left - r.width / 2) * .3, y: (e.clientY - r.top - r.height / 2) * .4, duration: .4}); });
      el.addEventListener("mouseleave", () => gsap.to(el, {x: 0, y: 0, duration: .8, ease: "elastic.out(1,.4)"}));
    });
    const stackEl = $("#stack");
    stackEl.parentElement.addEventListener("mousemove", e => { const px = e.clientX / W - .5, py = e.clientY / H - .5; gsap.to(stackEl, {rotateY: px * 8, rotateX: -py * 6, duration: .8}); });
  }
}
})();
