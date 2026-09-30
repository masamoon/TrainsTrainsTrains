// Regenerates the screenshots in docs/screens. Run with `npm run screens`.

import { type Page, test } from "@playwright/test";
import { generate } from "../src/core/daily";
import { Layout } from "../src/core/layout";
import { LEVELS, loadLevel } from "../src/core/levels";

const DAY = 3; // 2 Oct 2026
const OUT = "docs/screens";

test.skip(!process.env.SCREENS, "set SCREENS=1 to regenerate screenshots");
test.use({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, timezoneId: "UTC" });

function saveData(extra: { levels?: Record<string, unknown>; daily?: Record<string, unknown> } = {}) {
  const stars = [3, 3, 2, 3, 3, 2];
  const levels: Record<string, unknown> = {};
  stars.forEach((s, i) => (levels[LEVELS[i].id] = { stars: s }));
  const empty = new Layout().toData();
  const daily: Record<string, unknown> = {
    1: { rows: [["arrived", "crashed"], ["arrived", "arrived"]], solved: true, track: 14, layout: empty },
    2: { rows: [["arrived", "arrived", "arrived"]], solved: true, track: 17, layout: empty },
  };
  return { levels: { ...levels, ...extra.levels }, daily: { ...daily, ...extra.daily } };
}

async function open(page: Page, route: string, data: object): Promise<void> {
  await page.clock.setFixedTime(new Date("2026-10-02T10:00:00Z"));
  await page.addInitScript((json) => localStorage.setItem("trainstrains.save.v1", json), JSON.stringify(data));
  await page.goto(route);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
}

test("home", async ({ page }) => {
  await open(page, "./", saveData());
  await page.screenshot({ path: `${OUT}/home.png` });
});

test("map", async ({ page }) => {
  await open(page, "./#/map", saveData());
  await page.screenshot({ path: `${OUT}/map.png` });
});

test("level", async ({ page }) => {
  const pz = loadLevel(6);
  await open(page, "./#/level/7", saveData({ levels: { [pz.id]: { stars: 0, layout: pz.solutionLayout().toData() } } }));
  await page.screenshot({ path: `${OUT}/level.png` });
});

test("level running", async ({ page }) => {
  const pz = loadLevel(7);
  const data = saveData({ levels: { "1-7": { stars: 3 }, [pz.id]: { stars: 0, layout: pz.solutionLayout().toData() } } });
  await open(page, "./#/level/8", data);
  await page.getByRole("button", { name: "DEPART" }).click();
  await page.waitForTimeout(3300);
  await page.screenshot({ path: `${OUT}/level_running.png` });
});

test("daily", async ({ page }) => {
  await open(page, "./#/daily", saveData());
  await page.screenshot({ path: `${OUT}/daily.png` });
});

test("daily result", async ({ page }) => {
  const pz = generate(DAY);
  const layout = pz.solutionLayout();
  const today = { rows: [["crashed", "arrived", "arrived"], ["wrong", "arrived", "arrived"], ["arrived", "arrived", "arrived"]], solved: true, track: layout.trackCount(pz) + 2, layout: layout.toData() };
  today.rows = today.rows.map((r) => r.slice(0, pz.trainCount()).concat(Array(Math.max(0, pz.trainCount() - r.length)).fill("arrived")));
  await open(page, "./#/daily", saveData({ daily: { [DAY]: today } }));
  await page.screenshot({ path: `${OUT}/daily_result.png` });
});
