// App Store ヘッダ／検索結果画像の書き出し。使い方: node render.mjs （README.md 参照）
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '../package.json'));   // store_screenshots/node_modules を使う
const { chromium } = require('playwright');
const sharp = require('sharp');

const lpData = path.join(here, '../../site/lp/data.json');
const out = path.join(here, 'out');
fs.mkdirSync(out, { recursive: true });

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.ttf': 'font/ttf' };
const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const file = u.pathname === '/data.json' ? lpData : path.join(here, decodeURIComponent(u.pathname === '/' ? '/header.html' : u.pathname));
  if (!file.startsWith(here) && file !== lpData) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (e, buf) => {
    if (e) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/json' }); res.end(buf);
  });
}).listen(0);
const base = `http://127.0.0.1:${server.address().port}/header.html`;

// 巨大ページは2枚目の撮影が背景色だけになる現象が出たため、撮影は1回だけ。ガイド付きプレビューは下で SVG を重ねて作る（header.html?guide=1 でも同じ枠が出る）
const browser = await chromium.launch({ args: ['--disable-gpu'] });
const page = await browser.newPage({ viewport: { width: 5244, height: 2950 }, deviceScaleFactor: 1 });
await page.goto(base);
await page.waitForFunction(() => window.__ready === true);
await page.evaluate(() => document.fonts.ready);
await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
const stats = await page.evaluate(() => window.__stats);
const clip = { x: 0, y: 0, width: 5244, height: 2950 };
await page.screenshot({ path: path.join(out, '_raw.png'), clip });
await browser.close();
server.close();
console.log('点の数', stats);

// アルファ無しの sRGB(RGB) にする
const flat = (img) => img.flatten({ background: '#050B13' }).removeAlpha().toColourspace('srgb');
const raw = path.join(out, '_raw.png');
const png = { compressionLevel: 9 };
await flat(sharp(raw)).png(png).toFile(path.join(out, 'generic_5244x2950.png'));
// 中央 21:9 → 3840×1646（高さ 5244/21*9 = 2247）
await flat(sharp(raw)).extract({ left: 0, top: 352, width: 5244, height: 2247 }).resize(3840, 1646).png(png).toFile(path.join(out, 'header_3840x1646.png'));
// 中央 3:2 → 3840×2560（幅 2950*1.5 = 4425）
await flat(sharp(raw)).extract({ left: 410, top: 0, width: 4425, height: 2950 }).resize(3840, 2560).png(png).toFile(path.join(out, 'search_3840x2560.png'));
// プレビュー
const guideSvg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="5244" height="2950">
<rect x="633" y="387" width="3978" height="2176" fill="none" stroke="#FF4D99" stroke-width="6" stroke-dasharray="40 24"/>
<rect x="852" y="542" width="3540" height="1876" fill="none" stroke="#FFD36A" stroke-width="4"/></svg>`);
const guidePng = await sharp(guideSvg).resize(5244, 2950).png().toBuffer();
const guided = await sharp(await flat(sharp(raw)).png().toBuffer()).composite([{ input: guidePng }]).png().toBuffer();
await sharp(guided).resize(1200).png().toFile(path.join(out, 'preview_guide.png'));
await sharp(path.join(out, 'header_3840x1646.png')).resize(390).png().toFile(path.join(out, 'preview_header_390.png'));
await sharp(path.join(out, 'search_3840x2560.png')).resize(390).png().toFile(path.join(out, 'preview_search_390.png'));
// 厳しめ: 左右12%・上下13%を同時に隠す
const l = Math.round(5244 * 0.12), t = Math.round(2950 * 0.13);
await flat(sharp(raw)).extract({ left: l, top: t, width: 5244 - 2 * l, height: 2950 - 2 * t }).resize(1200).png().toFile(path.join(out, 'preview_strict.png'));
if (!process.env.KEEP) { fs.rmSync(raw); }
console.log('完了');
