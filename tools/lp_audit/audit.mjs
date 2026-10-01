// LP 監査: 段階スクロールで撮影＋エラー・FPS・LCP/CLS を計測
import { chromium } from 'playwright';
const [out, tag='r', stopsArg] = process.argv.slice(2);
const stops = (stopsArg||'0,.04,.08,.12,.17,.22,.27,.32,.37,.42,.47,.52,.57,.62,.67,.72,.77,.82,.88,.94,1').split(',').map(Number);
const b = await chromium.launch({args:['--enable-gpu','--use-angle=metal']});
for (const [name, vp, mobile] of [['d',{width:1440,height:900},false],['m',{width:390,height:844},true]]) {
  const ctx = await b.newContext({viewport:vp, deviceScaleFactor:1, isMobile:mobile, hasTouch:mobile});
  const p = await ctx.newPage();
  const errs=[]; p.on('pageerror',e=>errs.push(e.message)); p.on('console',m=>{if(m.type()==='error')errs.push(m.text())});
  await p.addInitScript(()=>{ window.__cls=0; new PerformanceObserver(l=>{for(const e of l.getEntries()) if(!e.hadRecentInput) window.__cls+=e.value}).observe({type:'layout-shift',buffered:true});
    new PerformanceObserver(l=>{const e=l.getEntries(); window.__lcp=e[e.length-1].startTime}).observe({type:'largest-contentful-paint',buffered:true}); });
  const t0=Date.now(); await p.goto('http://localhost:8765/', {waitUntil:'load', timeout:60000});
  const loadMs=Date.now()-t0; await p.waitForTimeout(6000);
  const fps = await p.evaluate(()=>new Promise(r=>{let n=0;const s=performance.now();function f(){n++; if(performance.now()-s<2000) requestAnimationFrame(f); else r(Math.round(n/2));} requestAnimationFrame(f);}));
  const H = await p.evaluate(()=>document.documentElement.scrollHeight);
  let cur=0;
  for (let i=0;i<stops.length;i++){
    const target=Math.round(stops[i]*(H-vp.height));
    // 段階スクロール（スクラブ演出を追従させる）
    const steps=12; for(let k=1;k<=steps;k++){ await p.mouse.wheel(0,(target-cur)/steps); await p.waitForTimeout(60);} cur=target;
    await p.evaluate(t=>window.scrollTo(0,t), target); await p.waitForTimeout(1400);
    await p.screenshot({path:`${out}/${tag}_${name}_${String(i).padStart(2,'0')}.png`});
  }
  const m = await p.evaluate(()=>({cls:window.__cls, lcp:window.__lcp}));
  console.log(JSON.stringify({name, loadMs, fps, H, ...m, errs}));
  await ctx.close();
}
await b.close();
