// エディタ (http://localhost:3000) を開き「Export bundle」を押して zip を保存する。
// 使い方: node export.mjs <out.zip> [<url>]
import { chromium } from "playwright";
const out = process.argv[2] || "export.zip";
const url = process.argv[3] || "http://localhost:3000";
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 }, acceptDownloads: true });
const page = await ctx.newPage();
page.on("console", (m) => { if (m.type() === "error") console.log("[console]", m.text()); });
await page.goto(url, { waitUntil: "networkidle" });
const btn = page.getByRole("button", { name: /Export bundle/ });
await btn.waitFor({ timeout: 60000 });
await page.waitForTimeout(4000);
const dl = page.waitForEvent("download", { timeout: 600000 });
await btn.click();
const d = await dl;
await d.saveAs(out);
console.log("saved", out);
await page.waitForTimeout(500);
await browser.close();
