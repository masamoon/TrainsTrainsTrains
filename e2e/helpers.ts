import type { Page } from "@playwright/test";
import type { Puzzle } from "../src/core/puzzle";

// Screen position of a board cell, using the same fit as Board.resize().
export async function cellPoint(page: Page, pz: Puzzle, x: number, y: number): Promise<{ x: number; y: number }> {
  const box = (await page.locator(".board-wrap canvas").boundingBox())!;
  const pad = 8;
  const cs = Math.floor(Math.min((box.width - pad * 2) / pz.w, (box.height - pad * 2) / pz.h));
  const ox = Math.floor((box.width - cs * pz.w) / 2);
  const oy = Math.floor((box.height - cs * pz.h) / 2);
  return { x: box.x + ox + (x + 0.5) * cs, y: box.y + oy + (y + 0.5) * cs };
}

export async function drag(page: Page, pz: Puzzle, path: [number, number][]): Promise<void> {
  const first = await cellPoint(page, pz, ...path[0]);
  await page.mouse.move(first.x, first.y);
  await page.mouse.down();
  for (const [x, y] of path.slice(1)) {
    const p = await cellPoint(page, pz, x, y);
    await page.mouse.move(p.x, p.y, { steps: 3 });
  }
  await page.mouse.up();
}
