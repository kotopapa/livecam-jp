// B案: 等高線（同心楕円8本）を描き、フォントと画像の読み込み完了を render_b.mjs に知らせる。
// 中心 (3680,1580)・回転-12度、i=0〜7 の横半径 650+180i・縦半径 900+180i、線幅5px #B6D6E5 不透明度0.55
if (new URLSearchParams(location.search).get('guide') === '1') document.body.classList.add('guide');
const svg = document.getElementById('contour-svg');
const NS = 'http://www.w3.org/2000/svg';
const g = document.createElementNS(NS, 'g');
// 描画領域の左上が原稿の (2760,0) なので、中心は (3680-2760, 1580)
g.setAttribute('transform', 'translate(920 1580) rotate(-12)');
for (let i = 0; i < 8; i++) {
  const e = document.createElementNS(NS, 'ellipse');
  e.setAttribute('rx', 650 + 180 * i); e.setAttribute('ry', 900 + 180 * i);
  e.setAttribute('fill', 'none'); e.setAttribute('stroke', '#B6D6E5'); e.setAttribute('stroke-width', 5);
  e.setAttribute('stroke-opacity', 0.55);
  g.appendChild(e);
}
svg.appendChild(g);
Promise.all([
  document.fonts.load('900 240px "Noto Sans JP"', '川も道路も、地図で見る。'),
  document.fonts.load('700 226px "Noto Sans JP"', 'ライブカメラ'),
  ...[...document.images].map(im => im.decode().catch(() => {})),
]).then(() => document.fonts.ready).then(() => { window.__ready = true; });
