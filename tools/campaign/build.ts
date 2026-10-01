// Freezes the picked levels of the plan into src/core/lines/: run.sh build [line numbers...]
// Each pick is regenerated from its seed, then searched again harder for a cheaper solution.
import { readFileSync, writeFileSync } from "node:fs";
import { Puzzle, type LevelData } from "../../src/core/puzzle";
import { candidate, deepen, features, freeze } from "./gen";
import { PLAN } from "./plan";

const lines = process.argv.slice(2).map(Number);
for (const n of lines) {
  const plan = PLAN[n - 3];
  const picks: Record<string, { seed: number; alts: number[] }> = JSON.parse(readFileSync(`tools/campaign/out/picks-${n}.json`, "utf8"));
  const levels: LevelData[] = [];
  const missing: string[] = [];
  for (const st of plan.stops) {
    let data: LevelData;
    if (st.data) data = st.data;
    else {
      // The pick first, then its alternatives, until one passes the deeper checks.
      let ok: LevelData | null = null;
      for (const seed of [picks[st.id].seed, ...picks[st.id].alts]) {
        const c = candidate(st.recipe!, seed);
        if (!c) {
          console.log(`${st.id}: seed ${seed} no longer generates`);
          continue;
        }
        if (!deepen(c, st.recipe!, (m) => console.log(`${st.id}: ${m}`))) {
          console.log(`${st.id}: seed ${seed} fails the deeper checks, next`);
          continue;
        }
        const f = features(c.pz, c.best.lay);
        console.log(`${st.id} ${st.name}: seed ${seed}, par ${c.best.track}, rate ${(c.rate * 100).toFixed(1)}%, ${JSON.stringify(f)}`);
        ok = freeze(c);
        break;
      }
      if (!ok) {
        missing.push(st.id);
        continue;
      }
      data = ok;
    }
    levels.push({ id: st.id, name: st.name, ...data, introTitle: st.introTitle, introText: st.introText });
  }
  if (missing.length) {
    console.log(`MISSING ${missing.join(",")}`);
    continue;
  }
  const varName = plan.name.toUpperCase().replace(/[^A-Z]+/g, "_");
  const file = `src/core/lines/line${String(n).padStart(2, "0")}.ts`;
  const body = levels.map((lv) => "  " + lit(clean(lv), 1)).join(",\n");
  writeFileSync(file, `// Line ${n}, ${plan.name}. Generated with tools/campaign and curated by hand.\n\nimport type { Stop } from "../levels";\n\nexport const ${varName}: Stop[] = [\n${body},\n];\n`);
  console.log(`wrote ${file}`);
  writeFileSync(`tools/campaign/out/final-${n}.json`, JSON.stringify(levels.map((lv) => ({ label: `${lv.id} ${lv.name} · par ${Puzzle.fromData(lv).par}`, data: lv }))));
}

function clean(lv: LevelData): object {
  const out: Record<string, unknown> = {};
  const order = ["id", "name", "rows", "depots", "stations", "fixed", "tunnels", "allowStop", "allowLamp", "introTitle", "introText", "solution"];
  for (const k of order) {
    const v = (lv as unknown as Record<string, unknown>)[k];
    if (v !== undefined && v !== false) out[k] = v;
  }
  return out;
}

// TypeScript literal: short values on one line, objects with array members broken out.
function lit(v: unknown, depth: number): string {
  const pad = "  ".repeat(depth);
  if (Array.isArray(v)) {
    const flat = `[${v.map((x) => lit(x, depth + 1)).join(", ")}]`;
    if (flat.length <= 110 || v.every((x) => typeof x !== "object")) return flat;
    return `[\n${v.map((x) => `${pad}  ${lit(x, depth + 1)}`).join(",\n")},\n${pad}]`;
  }
  if (v && typeof v === "object") {
    const entries = Object.entries(v).filter(([, x]) => x !== undefined);
    const flat = `{ ${entries.map(([k, x]) => `${k}: ${lit(x, depth + 1)}`).join(", ")} }`;
    if (flat.length <= 110 && depth > 1) return flat;
    return `{\n${entries.map(([k, x]) => `${pad}  ${k}: ${lit(x, depth + 1)}`).join(",\n")},\n${pad}}`;
  }
  return JSON.stringify(v);
}
