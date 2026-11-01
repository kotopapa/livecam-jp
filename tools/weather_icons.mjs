// 気象庁の天気予報アイコン（SVG）を PNG にして app/assets/weather/<code>.png に書く。
// 出典: 気象庁ホームページ（https://www.jma.go.jp/bosai/forecast/img/<code>.svg。公共データ利用規約）。
// アプリに flutter_svg を入れないための事前変換。実在するのは下の30コードだけで、
// 他の天気コードは app/lib/data/point_weather.dart の weatherIconBase で近いものに寄せる。
//
// 実行: Playwright は store_screenshots の node_modules を使うので、
//   cp tools/weather_icons.mjs store_screenshots/ && (cd store_screenshots && node weather_icons.mjs ../app/assets/weather)
import { chromium } from 'playwright';
import fs from 'node:fs';

const CODES = [100,101,102,104,110,112,115,200,201,202,204,210,212,215,300,301,302,303,308,311,313,314,400,401,402,403,406,411,413,414];
const out = process.argv[2] ?? '../app/assets/weather';
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 90, height: 60 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
for (const c of CODES) {
  const r = await fetch(`https://www.jma.go.jp/bosai/forecast/img/${c}.svg`);
  if (!r.ok) { console.log('skip', c, r.status); continue; }
  const svg = await r.text();
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.screenshot({ path: `${out}/${c}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 90, height: 60 } });
}
await browser.close();
