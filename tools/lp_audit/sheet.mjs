// 撮影画像を1枚のコンタクトシートにまとめる
import { chromium } from 'playwright'; import fs from 'fs'; import path from 'path';
const [dir, prefix, out, cols='4', w='360'] = process.argv.slice(2);
const files = fs.readdirSync(dir).filter(f=>f.startsWith(prefix)&&f.endsWith('.png')).sort();
const html = `<html><body style="margin:0;background:#111;display:grid;grid-template-columns:repeat(${cols},${w}px);gap:6px;padding:6px;font:11px monospace;color:#ccc">`+
  files.map(f=>`<div><img src="file://${path.join(dir,f)}" style="width:${w}px;display:block">${f}</div>`).join('')+`</body></html>`;
fs.writeFileSync(path.join(dir,'_sheet.html'),html);
const b=await chromium.launch(); const p=await b.newPage({viewport:{width:Number(cols)*(Number(w)+6)+6,height:400}});
await p.goto('file://'+path.join(dir,'_sheet.html')); await p.waitForTimeout(500);
await p.screenshot({path:out,fullPage:true}); await b.close();
