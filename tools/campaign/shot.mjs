// Screenshots the contact sheet: node tools/campaign/shot.mjs <sheet> <out.png>
import { chromium } from "@playwright/test";
const [sheet, out] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 800 }, deviceScaleFactor: 1 });
await page.goto(`http://localhost:5199/tools/campaign/preview.html?sheet=${sheet}`);
await page.waitForSelector("body[data-ready]");
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(400);
await page.screenshot({ path: out, fullPage: true });
await browser.close();
