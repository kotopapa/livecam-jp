// Meteocons（Bas Milius、MIT）の塗り版（fill）SVG を PNG にして app/assets/weather/<name>.png に書く。
// 取得元: npm @meteocons/svg-static（https://cdn.jsdelivr.net/npm/@meteocons/svg-static/fill/<name>.svg）。
// 元の viewBox は 128×128。単一の 144px で置き、アプリ側で Image.asset(width:) で縮める。
// アプリに flutter_svg を入れないための事前変換。気象庁の天気コードとの対応表は
// app/lib/data/point_weather.dart の weatherIconSpec。ライセンス全文は LICENSE.txt に置く。
//
// 実行: Playwright は store_screenshots の node_modules を使うので、
//   cp tools/weather_icons.mjs store_screenshots/ && (cd store_screenshots && node weather_icons.mjs ../app/assets/weather)
import { chromium } from 'playwright';
import fs from 'node:fs';

const NAMES = [
  'clear-day', 'partly-cloudy-day', 'partly-cloudy-day-rain', 'partly-cloudy-day-snow',
  'partly-cloudy-day-sleet', 'overcast', 'overcast-day', 'overcast-rain', 'overcast-snow',
  'rain', 'snow', 'sleet', 'thunderstorms-rain', 'extreme-rain', 'extreme-snow', 'snowman',
];
const BASE = 'https://cdn.jsdelivr.net/npm/@meteocons/svg-static';
const SIZE = 144;
const out = process.argv[2] ?? '../app/assets/weather';
fs.mkdirSync(out, { recursive: true });
const lic = await fetch(`${BASE}/LICENSE`);
if (lic.ok) fs.writeFileSync(`${out}/LICENSE.txt`, await lic.text());
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1 });
const page = await ctx.newPage();
for (const n of NAMES) {
  const r = await fetch(`${BASE}/fill/${n}.svg`);
  if (!r.ok) { console.log('skip', n, r.status); continue; }
  const svg = (await r.text()).replace('<svg ', `<svg width="${SIZE}" height="${SIZE}" `);
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.screenshot({ path: `${out}/${n}.png`, omitBackground: true, clip: { x: 0, y: 0, width: SIZE, height: SIZE } });
}
await browser.close();
