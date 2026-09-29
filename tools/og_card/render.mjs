import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({viewport:{width:1200,height:630}, deviceScaleFactor:1});
await p.goto('http://localhost:8766/_og/og.html', {waitUntil:'load'});
await p.waitForSelector('body[data-ready]'); await p.evaluate(()=>document.fonts.ready); await p.waitForTimeout(800);
await p.screenshot({path: process.argv[2]});
await b.close();
