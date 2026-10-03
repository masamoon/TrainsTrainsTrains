// Generates candidates for block-signal campaign stops and keeps the best few:
//   tools/campaign/run.sh ../lab/blockpick <stop ids or line numbers> [--seeds N] [--keep K]
// Writes tools/lab/out/<id>.json (candidates, best first). blockfreeze.ts writes the lines.
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { type Candidate, generate } from "./blockgen";
import { BLOCK_PLAN } from "./blockplan";

const argv = process.argv.slice(2);
const opt = (name: string, def: number) => {
  const i = argv.indexOf(name);
  return i >= 0 ? Number(argv[i + 1]) : def;
};
const seeds = opt("--seeds", 60);
const keep = opt("--keep", 4);
const want = argv.filter((a, i) => !a.startsWith("--") && !argv[i - 1]?.startsWith("--")).flatMap((a) => a.split(","));
const stops = BLOCK_PLAN.flatMap((ln, li) => ln.stops.map((st) => ({ ...st, line: li + 3 }))).filter(
  (st) => want.includes(st.id) || want.includes(String(st.line)),
);
if (!existsSync("tools/lab/out")) mkdirSync("tools/lab/out");

// Fewer answers is harder; later lines aim lower. Ties go to less track.
const target = (line: number) => Math.max(2, 13 - line);
for (const st of stops) {
  const found: Candidate[] = [];
  const why: Record<string, number> = {};
  const t0 = Date.now();
  for (let seed = 1; seed <= seeds && found.length < keep * 3; seed++) {
    const c = generate(st.spec, seed * 7919 + st.line * 101);
    // The same board can come from different seeds: keep one.
    if ("data" in c) {
      const sig = JSON.stringify([c.data.rows, c.data.depots]);
      if (!found.some((f) => JSON.stringify([f.data.rows, f.data.depots]) === sig)) found.push(c);
    }
    else {
      const k = c.why.replace(/[0-9]+/g, "n");
      why[k] = (why[k] ?? 0) + 1;
    }
  }
  const score = (c: Candidate) => Math.abs(c.answers - target(st.line)) + (c.model === "stuck" ? 0 : 2);
  found.sort((a, b) => score(a) - score(b) || (a.data.par ?? 0) - (b.data.par ?? 0));
  const best = found.slice(0, keep);
  writeFileSync(`tools/lab/out/${st.id}.json`, JSON.stringify(best));
  console.log(
    `${st.id} ${st.name}: ${found.length} found in ${((Date.now() - t0) / 1000).toFixed(0)}s; ` +
      (best.length ? best.map((c) => `[dl ${c.deadline} par ${c.data.par} ans ${c.answers} sig ${c.fewest} model ${c.model}]`).join(" ") : "NONE") +
      ` rejects ${JSON.stringify(why)}`,
  );
}
