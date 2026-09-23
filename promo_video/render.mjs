// promo_video/index.html を 900 フレームのコマ撮りで MP4 に書き出す。
// usage: node render.mjs [--preview] [--frames 0,45,90] [--out out/promo.mp4]
//   --frames  指定フレームだけ PNG で out/frames/ に保存（確認用）
//   --preview 540×960 で書き出す（速い）
// ffmpeg は imageio-ffmpeg 同梱のものを使う（FFMPEG 環境変数で上書き可）
import { createRequire } from 'node:module';
import { spawn, execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '../store_screenshots/package.json'));
const { chromium } = require('playwright');

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const preview = args.includes('--preview');
const frames = opt('--frames');
const out = path.resolve(here, opt('--out', preview ? 'out/promo_preview.mp4' : 'out/promo_1080x1920.mp4'));
const scale = preview ? 0.5 : 1;

const ffmpeg = process.env.FFMPEG || execFileSync('/Library/Frameworks/Python.framework/Versions/3.10/bin/python3',
  ['-c', 'import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())']).toString().trim();

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: scale });
page.on('console', m => { if (m.type() === 'error') console.error('[page]', m.text()); });
page.on('pageerror', e => console.error('[pageerror]', e.message));
await page.goto(pathToFileURL(path.join(here, 'index.html')).href + '?f=0');
await page.evaluate(() => window.ready);
const stage = await page.$('#stage');

const shot = async f => {
  await page.evaluate(n => window.render(n), f);
  return stage.screenshot({ type: 'png', animations: 'disabled' });
};

if (frames) {
  const dir = path.join(here, 'out/frames');
  mkdirSync(dir, { recursive: true });
  for (const f of frames.split(',').map(Number)) {
    writeFileSync(path.join(dir, `f${String(f).padStart(3, '0')}.png`), await shot(f));
  }
  console.log('frames ->', dir);
} else {
  mkdirSync(path.dirname(out), { recursive: true });
  const ff = spawn(ffmpeg, ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', '30', '-i', '-',
    '-c:v', 'libx264', '-preset', preview ? 'veryfast' : 'slow', '-crf', preview ? '23' : '16',
    '-pix_fmt', 'yuv420p', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
    '-r', '30', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  const total = await page.evaluate(() => window.FRAMES);
  const t0 = Date.now();
  for (let f = 0; f < total; f++) {
    const buf = await shot(f);
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (f % 150 === 0) console.log(`frame ${f}/${total} ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
  ff.stdin.end();
  await new Promise((res, rej) => ff.on('close', c => (c === 0 ? res() : rej(new Error('ffmpeg ' + c)))));
  console.log('video ->', out);
}
await browser.close();
