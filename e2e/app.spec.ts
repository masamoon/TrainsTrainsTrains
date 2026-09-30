import { expect, test } from "@playwright/test";
import { loadLevel } from "../src/core/levels";
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
