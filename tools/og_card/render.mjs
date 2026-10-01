// LP の SNS カード画像（site/lp/og.png、1200×630）を新しい LP の冒頭画面から撮る。
// 使い方: site/ で python3 -m http.server 8765 → このファイルを store_screenshots/ にコピーして
// node _og.mjs /tmp/og.png → sips -Z 1200 /tmp/og.png --out site/lp/og.png。og:image の ?v= を上げる（X の控えを更新させる）

import { chromium } from 'playwright';
const out = process.argv[2]; const b = await chromium.launch({args:['--use-angle=metal']});
const p = await b.newPage({viewport:{width:1200,height:630}, deviceScaleFactor:2});
await p.goto('http://localhost:8765/',{waitUntil:'load'}); await p.waitForTimeout(7500);
await p.addStyleTag({content:`.hint,.cta,.hud.bl,.hud.br,.rail,.cursor,.lens,.grain{display:none!important}
 .hero-copy{top:52%!important}
 .hero-lead{font-size:17px!important;max-width:500px!important}
 .og-badge{position:fixed;right:56px;top:20px;z-index:80;font:600 13px "JetBrains Mono";letter-spacing:.24em;color:#5BF0D1}`});
await p.evaluate(()=>{ const d=document.createElement('div'); d.className='og-badge'; d.textContent='FREE · iOS / ANDROID'; document.body.appendChild(d); document.querySelector('.hud.tr').style.display='none'; });
await p.waitForTimeout(1500);
await p.screenshot({path:out}); await b.close();
