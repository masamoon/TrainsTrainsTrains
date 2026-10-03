// Writes the chosen block-signal candidates into src/core/lines/:
//   tools/campaign/run.sh ../lab/blockfreeze <line numbers>
// Each stop takes the first candidate in tools/lab/out/<id>.json unless
// tools/lab/out/choice.json names another index ({"3-4": 1}).
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import type { LevelData } from "../../src/core/puzzle";
import type { Candidate } from "./blockgen";
import { BLOCK_PLAN } from "./blockplan";

const lines = process.argv.slice(2).flatMap((a) => a.split(",")).map(Number);
const choice: Record<string, number> = existsSync("tools/lab/out/choice.json") ? JSON.parse(readFileSync("tools/lab/out/choice.json", "utf8")) : {};
const NAMES = ["", "", "", "Harbour Line", "Market Line", "Moor Line", "Coal Line", "Clockwork Line", "Junction Line", "Festival Line", "Coast Line", "Summit Line", "Night Mail", "Grand Terminus"];

const used = new Set<string>();
for (const n of lines) {
  const plan = BLOCK_PLAN[n - 3];
  const levels: LevelData[] = [];
  const missing: string[] = [];
  for (const st of plan.stops) {
    const f = `tools/lab/out/${st.id}.json`;
    const cs: Candidate[] = existsSync(f) ? JSON.parse(readFileSync(f, "utf8")) : [];
    // No board twice in the campaign: skip candidates an earlier stop already took.
    const key = (x: Candidate) => JSON.stringify([x.data.rows, x.data.depots, x.data.stations]);
    const free = cs.filter((x) => !used.has(key(x)));
    const c = choice[st.id] !== undefined ? cs[choice[st.id]] : free[0];
    if (c) used.add(key(c));
    if (!c) {
      missing.push(st.id);
      continue;
    }
    levels.push({ ...c.data, id: st.id, name: st.name, introTitle: st.introTitle, introText: st.introText });
  }
  if (missing.length) {
    console.log(`line ${n}: MISSING ${missing.join(",")}`);
    continue;
  }
  const file = `src/core/lines/${plan.file}.ts`;
  const body = levels.map((lv) => "  " + lit(clean(lv), 1)).join(",\n");
  writeFileSync(
    file,
    `// Line ${n}, ${NAMES[n]}. Block signals with a timetable, generated with tools/lab/blockgen.ts\n// (plan in tools/lab/blockplan.ts) and picked by hand.\n\nimport type { Stop } from "../levels";\n\nexport const ${plan.constName}: Stop[] = [\n${body},\n];\n`,
  );
  console.log(`wrote ${file}`);
}

function clean(lv: LevelData): object {
  const out: Record<string, unknown> = {};
  const order = ["id", "name", "rows", "depots", "stations", "fixed", "tunnels", "allowStop", "allowLamp", "signals", "deadline", "introTitle", "introText", "par", "solution"];
  for (const k of order) {
    const v = (lv as unknown as Record<string, unknown>)[k];
    if (v === undefined || v === false || (Array.isArray(v) && v.length === 0)) continue;
    if (k === "par") continue; // recomputed from the solution
    out[k] = v;
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
