// Generates candidates for every stop of one line and picks the one closest to the
// recipe's target solve rate: run.sh pick <line number> [candidates per stop] [only id]
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { type Candidate, candidate, deepen, describe, freeze } from "./gen";
import { PLAN } from "./plan";

const line = Number(process.argv[2]);
const per = Number(process.argv[3] ?? 6);
const only = process.argv[4];
const file = `tools/campaign/out/picks-${line}.json`;
const picks: Record<string, { seed: number; alts: number[] }> = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
const plan = PLAN[line - 3];
const sheet: unknown[] = [];
for (const st of plan.stops) {
  if (!st.recipe || (only && !only.split(",").includes(st.id))) continue;
  const r = st.recipe;
  const found: Candidate[] = [];
  const t0 = Date.now();
  for (let s = 1; s <= 1500 && found.length < per; s++) {
    const c = candidate(r, s);
    if (c && deepen(c, r)) found.push(c);
  }
  const target = r.target ?? 0.2;
  found.sort((a, b) => Math.abs(Math.log(a.rate / target)) - Math.abs(Math.log(b.rate / target)));
  console.log(`== ${st.id} ${st.name}: ${found.length} candidates in ${Date.now() - t0}ms`);
  for (const c of found) {
    console.log(describe(c) + "\n");
    sheet.push({ label: `${st.id} seed ${c.seed} · par ${c.best.track} · ${(c.rate * 100).toFixed(1)}%`, data: freeze(c) });
  }
  if (found.length) picks[st.id] = { seed: found[0].seed, alts: found.slice(1).map((c) => c.seed) };
  writeFileSync(file, JSON.stringify(picks, null, 1));
}
writeFileSync(`tools/campaign/out/line-${line}${only ? "-" + only : ""}.json`, JSON.stringify(sheet));
