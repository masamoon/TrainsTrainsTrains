// Renders tools/og/card.html, with the game's own Wye mark and signal scene, to public/og.png.
import { chromium } from "@playwright/test";
import { createServer } from "vite";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const server = await createServer({ root, logLevel: "error", server: { port: 5179 } });
await server.listen();
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.goto("http://localhost:5179/tools/og/card.html");
await page.evaluate(async () => {
  const dom = await import("/src/ui/dom.ts");
  document.getElementById("mark").append(dom.wyeMark(120));
  const scene = dom.signalScene();
  scene.setAttribute("width", "1056");
  document.getElementById("scene").prepend(scene);
  await document.fonts.ready;
});
await page.screenshot({ path: `${root}public/og.png` });
await browser.close();
await server.close();
