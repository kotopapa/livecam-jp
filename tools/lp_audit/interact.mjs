// 照準・音・カーソル・動きを減らす設定の確認
import { chromium } from 'playwright';
const out = process.argv[2]; const b = await chromium.launch();
const p = await b.newPage({viewport:{width:1440,height:900}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
await p.goto('http://localhost:8765/',{waitUntil:'load'}); await p.waitForTimeout(6500);
for (const [x,y] of [[1040,420],[1010,470],[980,520]]) { await p.mouse.move(x,y,{steps:6}); await p.waitForTimeout(300); }
await p.screenshot({path:`${out}/i_lens.png`});
await p.click('#sound'); await p.waitForTimeout(300);
const pressed = await p.getAttribute('#sound','aria-pressed'); const lbl = await p.textContent('#soundLbl');
await p.hover('.cta'); await p.waitForTimeout(400); await p.screenshot({path:`${out}/i_cta.png`, clip:{x:520,y:0,width:400,height:120}});
console.log(JSON.stringify({pressed, lbl, lens: await p.evaluate(()=>getComputedStyle(document.querySelector('.lens')).opacity), name: await p.textContent('.lens b'), errs}));
const r = await b.newContext({viewport:{width:1440,height:900}, reducedMotion:'reduce'}); const q = await r.newPage(); const e2=[]; q.on('pageerror',e=>e2.push(e.message));
await q.goto('http://localhost:8765/',{waitUntil:'load'}); await q.waitForTimeout(2500); await q.screenshot({path:`${out}/i_reduced_top.png`});
await q.evaluate(()=>window.scrollTo(0, 6000)); await q.waitForTimeout(800); await q.screenshot({path:`${out}/i_reduced_mid.png`});
console.log('reduced errs', JSON.stringify(e2)); await b.close();
