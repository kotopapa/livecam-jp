// 光点の描画。data.json は site/lp/data.json（render.mjs が配信）。
// pts は [緯度*50-1200, 経度*50-6100, カテゴリ] の平らな整数配列（site/build.py の build_lp_data）
if (new URLSearchParams(location.search).get('guide') === '1') document.body.classList.add('guide');

const DENSE_RATIO = 0.7;   // 近傍点数の上位 (1-この値) の点を密集扱い（径3px・不透明度0.4）
const BOX = { x: 1150, y: 440, w: 2944, h: 1700 };  // 素案(620,1420)から2割拡大。下端2140、文字は2230〜（共通セーフエリア 384〜2566 内）

// 座標から固定のハッシュ（FNV-1a）を作る。乱数は使わない
function hash(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return (h >>> 0) / 4294967296;
}

async function draw() {
  const data = await (await fetch('data.json')).json();
  const pts = [];
  for (let i = 0; i < data.pts.length; i += 3) {
    const lat = (data.pts[i] + 1200) / 50, lng = (data.pts[i + 1] + 6100) / 50;
    if (lat < 20 || lat > 46.5 || lng < 122 || lng > 154) continue;
    pts.push({ lat, lng, id: data.pts[i] + '_' + data.pts[i + 1] + '_' + data.pts[i + 2] });
  }
  let minLat = 90, maxLat = -90, minLng = 999, maxLng = -999;
  for (const p of pts) {
    minLat = Math.min(minLat, p.lat); maxLat = Math.max(maxLat, p.lat);
    minLng = Math.min(minLng, p.lng); maxLng = Math.max(maxLng, p.lng);
  }
  const k = Math.cos(((minLat + maxLat) / 2) * Math.PI / 180);   // 経度方向の補正
  const spanX = (maxLng - minLng) * k, spanY = maxLat - minLat;
  const scale = Math.min(BOX.w / spanX, BOX.h / spanY);          // 等倍率（縦横別拡大なし）
  const ox = BOX.x + (BOX.w - spanX * scale) / 2, oy = BOX.y + (BOX.h - spanY * scale) / 2;
  for (const p of pts) {
    p.x = ox + (p.lng - minLng) * k * scale;
    p.y = oy + (maxLat - p.lat) * scale;
  }

  // 密集判定: 24px 格子で近傍(3x3)の点数を数える
  const CELL = 24, grid = new Map();
  const key = (cx, cy) => cx * 100000 + cy;
  for (const p of pts) {
    const kk = key(Math.floor(p.x / CELL), Math.floor(p.y / CELL));
    grid.set(kk, (grid.get(kk) || 0) + 1);
  }
  for (const p of pts) {
    const cx = Math.floor(p.x / CELL), cy = Math.floor(p.y / CELL);
    let n = 0;
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) n += grid.get(key(cx + dx, cy + dy)) || 0;
    p.n = n;
    p.hi = hash(p.id) < 0.05;
  }
  const sorted = pts.map(p => p.n).sort((a, b) => a - b);
  const thr = sorted[Math.floor(sorted.length * DENSE_RATIO)];
  for (const p of pts) p.dense = p.n > thr;

  const ctx = document.getElementById('map').getContext('2d');
  const dot = (x, y, d, color, alpha) => {
    ctx.globalAlpha = alpha; ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(x, y, d / 2, 0, Math.PI * 2); ctx.fill();
  };
  for (const p of pts) if (!p.hi) p.dense ? dot(p.x, p.y, 3, '#8DCBFF', 0.4) : dot(p.x, p.y, 5, '#8DCBFF', 0.65);
  for (const p of pts) if (p.hi) {
    const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, 18);
    g.addColorStop(0, 'rgba(179,240,237,0.2)'); g.addColorStop(1, 'rgba(179,240,237,0)');
    ctx.globalAlpha = 1; ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(p.x, p.y, 18, 0, Math.PI * 2); ctx.fill();
    dot(p.x, p.y, 8, '#B3F0ED', 0.9);
  }
  ctx.globalAlpha = 1;
  window.__stats = { n: pts.length, dense: pts.filter(p => p.dense).length, hi: pts.filter(p => p.hi).length };
}

Promise.all([document.fonts.load('250px "Dela Gothic One"', '日本の今を、地図で。'), document.fonts.ready])
  .then(draw).then(() => { window.__ready = true; });
