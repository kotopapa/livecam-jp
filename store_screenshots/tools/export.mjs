// エディタ (http://localhost:3000) を開き「Export bundle」を押して zip を保存する。
// 使い方: node export.mjs <out.zip> [<url>] [--device=iphone|ipad|iphone-duo|android|...]
//   --device を付けると app-store-screenshots.json の "device" を一時的に書き換えて書き出し、終わったら元に戻す
//   （iPhone Duo は --device=iphone-duo。内側 2007x2853 と外側 1398x2034 の2サイズが zip に入る）
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const args = process.argv.slice(2);
const deviceArg = args.find((a) => a.startsWith("--device="))?.slice("--device=".length);
const pos = args.filter((a) => !a.startsWith("--"));
const out = pos[0] || "export.zip";
const url = pos[1] || "http://localhost:3000";
const jsonPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "app-store-screenshots.json");
const jsonOrig = fs.readFileSync(jsonPath, "utf8");
if (deviceArg) {
  const j = JSON.parse(jsonOrig);
  j.device = deviceArg;
  fs.writeFileSync(jsonPath, JSON.stringify(j, null, 2));
}
const restore = () => { if (deviceArg) fs.writeFileSync(jsonPath, jsonOrig); };
process.on("uncaughtException", (e) => { restore(); console.error(e); process.exit(1); });
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 }, acceptDownloads: true });
const page = await ctx.newPage();
page.on("console", (m) => { if (m.type() === "error") console.log("[console]", m.text()); });
// 画像が未配置（404）だと networkidle にならないので domcontentloaded で待つ
await page.goto(url, { waitUntil: "domcontentloaded" });
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
restore();
