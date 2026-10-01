import { expect, test } from "@playwright/test";
import { LEVELS, loadLevel } from "../src/core/levels";
import { drag } from "./helpers";

test("home shows the campaign and today's Daily Line", async ({ page }) => {
  await page.goto("./");
  await expect(page.getByRole("heading", { name: "TrainsTrainsTrains" })).toBeVisible();
  await expect(page.getByRole("button", { name: "START" })).toBeVisible();
  await expect(page.getByText("DAILY LINE", { exact: true })).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("a first stop can be drawn and solved for three stars", async ({ page }) => {
  await page.goto("./");
  await page.getByRole("button", { name: "START" }).click();
  await page.getByRole("button", { name: /Stop 1, First Light/ }).click();
  await expect(page.getByRole("heading", { name: "FIRST LIGHT" })).toBeVisible();
  const pz = loadLevel(0);
  // Drag from the square beside the depot to the square beside the platform.
  await drag(page, pz, pz.solution.paths[0].slice(1, -1).map((c) => [c.x, c.y]));
  await expect(page.getByText(`Track 5 · par ${pz.par}`)).toBeVisible();
  await page.getByRole("button", { name: "DEPART" }).click();
  await expect(page.getByRole("heading", { name: "ALL TRAINS HOME" })).toBeVisible({ timeout: 10_000 });
  await expect(page.getByRole("img", { name: "3 of 3 stars" }).last()).toBeVisible();
  await page.getByRole("button", { name: "NEXT STOP" }).click();
  await expect(page.getByRole("heading", { name: "ROUND THE POND" })).toBeVisible();
  await page.getByRole("button", { name: "‹ Map" }).click();
  await expect(page.getByRole("button", { name: /Stop 1, First Light, 3 of 3 stars/ })).toBeVisible();
});

test("a failed departure explains what went wrong", async ({ page }) => {
  await page.goto("./#/level/1");
  const pz = loadLevel(0);
  await drag(page, pz, [[1, 1], [2, 1], [3, 1]]);
  await page.getByRole("button", { name: "DEPART" }).click();
  await expect(page.getByRole("heading", { name: "DERAILED" })).toBeVisible({ timeout: 10_000 });
  await page.getByRole("button", { name: "KEEP BUILDING" }).click();
  await page.getByRole("button", { name: "Undo" }).click();
  await expect(page.getByText(`Track 0 · par ${pz.par}`)).toBeVisible();
});

test("the Daily Line counts departures and ends with a shareable result", async ({ page, context }) => {
  test.setTimeout(90_000); // six full playbacks
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await page.goto("./#/daily");
  await expect(page.getByRole("button", { name: "DEPART · 6 LEFT" })).toBeVisible();
  const board = page.locator(".board-wrap canvas");
  const box = (await board.boundingBox())!;
  // A stretch of track across the middle is enough to spend departures.
  for (let i = 0; i < 6; i++) {
    if (i === 0) {
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await page.mouse.move(box.x + 10, box.y + box.height / 2, { steps: 8 });
      await page.mouse.up();
    }
    await page.getByRole("button", { name: `DEPART · ${6 - i} LEFT` }).click();
    if (i < 5) await page.getByRole("button", { name: "KEEP BUILDING" }).click({ timeout: 20_000 });
  }
  await expect(page.getByRole("heading", { name: "OUT OF DEPARTURES" })).toBeVisible({ timeout: 20_000 });
  await page.getByRole("button", { name: "COPY RESULT" }).click();
  const text = await page.evaluate(() => navigator.clipboard.readText());
  expect(text).toMatch(/^TrainsTrainsTrains No\. \d{4} · X\/6\n/);
  await page.getByRole("button", { name: "Show a solution" }).click();
  await expect(page.getByRole("button", { name: "NO DEPARTURES LEFT" })).toBeDisabled();
});

test("test mode can reset today's Daily Line", async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto("./#/daily");
  await expect(page.getByRole("button", { name: /Reset today's puzzle/ })).toHaveCount(0);
  await page.goto("./?test#/daily");
  const box = (await page.locator(".board-wrap canvas").boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + 10, box.y + box.height / 2, { steps: 8 });
  await page.mouse.up();
  await page.getByRole("button", { name: "DEPART · 6 LEFT" }).click();
  await page.getByRole("button", { name: "KEEP BUILDING" }).click({ timeout: 20_000 });
  await expect(page.getByRole("button", { name: "DEPART · 5 LEFT" })).toBeVisible();
  await page.getByRole("button", { name: /Reset today's puzzle/ }).click();
  await expect(page.getByRole("button", { name: "DEPART · 6 LEFT" })).toBeVisible();
  await expect(page.getByText("Track 0 ·")).toBeVisible();
});

test("the Valley Line follows Line 1, and trains run through a tunnel", async ({ page }) => {
  const levels: Record<string, unknown> = {};
  for (const lv of LEVELS) if (lv.line === 0 || lv.id === "2-1" || lv.id === "2-2") levels[lv.id] = { stars: 3 };
  await page.addInitScript((json) => localStorage.setItem("trainstrains.save.v1", json), JSON.stringify({ levels, daily: {} }));
  await page.goto("./#/map");
  await expect(page.getByRole("button", { name: /Line 2, stop 1, Old Main Line, 3 of 3 stars/ })).toBeVisible();
  await page.getByRole("button", { name: /Line 2, stop 3, Under the Hill, next/ }).click();
  await expect(page.getByText("LINE 2 · STOP 3")).toBeVisible();
  const pz = loadLevel(LEVELS.findIndex((lv) => lv.id === "2-3"));
  // Join the depot to one tunnel stub, and the other stub to the platform.
  await drag(page, pz, [[2, 1], [2, 2], [3, 2]]);
  await drag(page, pz, [[3, 5], [4, 5], [5, 5]]);
  await expect(page.getByText(`Track 6 · par ${pz.par}`)).toBeVisible();
  await page.getByRole("button", { name: "DEPART" }).click();
  await expect(page.getByRole("heading", { name: "ALL TRAINS HOME" })).toBeVisible({ timeout: 10_000 });
});

test("a timed platform turns away a train that comes too early", async ({ page }) => {
  const i = LEVELS.findIndex((lv) => lv.id === "7-1");
  const pz = loadLevel(i);
  // The reference layout without its stop signals gets there too soon.
  const lay = pz.solutionLayout();
  lay.stops.clear();
  const levels: Record<string, unknown> = {};
  for (const lv of LEVELS.slice(0, i)) levels[lv.id] = { stars: 3 };
  levels[pz.id] = { stars: 0, layout: lay.toData() };
  await page.addInitScript((json) => localStorage.setItem("trainstrains.save.v1", json), JSON.stringify({ levels, daily: {} }));
  await page.goto(`./#/level/${i + 1}`);
  await expect(page.getByText("New: timed platform")).toBeVisible();
  await page.getByRole("button", { name: "DEPART" }).click();
  await expect(page.getByRole("heading", { name: "TOO EARLY" })).toBeVisible({ timeout: 15_000 });
});

test("the map runs on to the last of more than a hundred stops", async ({ page }) => {
  const levels: Record<string, unknown> = {};
  for (const lv of LEVELS.slice(0, -1)) levels[lv.id] = { stars: 3 };
  await page.addInitScript((json) => localStorage.setItem("trainstrains.save.v1", json), JSON.stringify({ levels, daily: {} }));
  await page.goto("./#/map");
  const last = LEVELS[LEVELS.length - 1];
  await expect(page.getByRole("button", { name: new RegExp(`Line ${last.line + 1}, stop ${last.stop + 1}, ${last.name}, next`) })).toBeVisible();
  expect(LEVELS.length).toBeGreaterThanOrEqual(100);
});
