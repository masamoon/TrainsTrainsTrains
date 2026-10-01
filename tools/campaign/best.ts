// Prints the cheapest solution the solver finds for existing levels: run.sh best 1-6 1-8
import { LEVELS, loadLevel } from "../../src/core/levels";
import { ascii, solve } from "./solver";
for (const id of process.argv.slice(2)) {
  const i = LEVELS.findIndex((lv) => lv.id === id);
  const pz = loadLevel(i);
  const r = solve(pz, { attempts: 2000, seed: 5, maxStops: 3 });
  if (!r.best) continue;
  const b = r.best;
  const xy = (k: string) => `[${k}]`;
  console.log(`${id} par ${pz.par} -> ${b.track}`);
  console.log(ascii(pz, b.lay));
  console.log(`paths: [${b.paths.map((p) => `[${p.map((c) => `[${c.x}, ${c.y}]`).join(", ")}]`).join(",\n")}],`);
  if (b.lay.stops.size) console.log(`stops: [${[...b.lay.stops].map(xy).join(", ")}],`);
  if (b.lay.lamps.size) console.log(`lamps: [${[...b.lay.lamps].map(([k, c]) => `[${k}, ${c}]`).join(", ")}],`);
  if (b.lay.levers.size) console.log(`levers: [${[...b.lay.levers].map(([k, d]) => `[${k}, "${"NESW"[d]}"]`).join(", ")}],`);
}
