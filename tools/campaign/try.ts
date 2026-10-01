// Prints and saves candidates for a recipe: run.sh try '<recipe json>' [fromSeed] [count] [sheet]
import { writeFileSync } from "node:fs";
import { candidate, describe, freeze, type Recipe } from "./gen";
const r: Recipe = JSON.parse(process.argv[2]);
const from = Number(process.argv[3] ?? 1);
const want = Number(process.argv[4] ?? 8);
const sheet = process.argv[5] ?? "sheet";
let got = 0;
const items: unknown[] = [];
const t0 = Date.now();
for (let s = from; s < from + 600 && got < want; s++) {
  const c = candidate(r, s);
  if (!c) continue;
  got++;
  console.log(describe(c) + "\n");
  items.push({ label: `seed ${c.seed} · par ${c.best.track} · ${(c.rate * 100).toFixed(0)}%`, data: freeze(c) });
}
writeFileSync(`tools/campaign/out/${sheet}.json`, JSON.stringify(items));
console.error(`${got} in ${Date.now() - t0}ms`);
