// エディタ画面そのものを撮る（確認用）。node shot.mjs <out.png>
import { chromium } from "playwright";
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1800, height: 1100 } });
await page.goto(process.argv[3] || "http://localhost:3000", { waitUntil: "networkidle" });
await page.waitForTimeout(4000);
await page.screenshot({ path: process.argv[2] || "editor.png" });
await browser.close();
