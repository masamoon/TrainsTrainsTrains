// Checks campaign stops under block signals: reference, person model, recipes.
//   tools/campaign/run.sh ../lab/tut [first] [last]   (stop indexes, default all)
import { LEVELS, loadLevel } from "../../src/core/levels";
import { run } from "../../src/core/sim";
import { play } from "./player";
import { brainless } from "./recipes";
import { routesOf } from "./proto";
const [from, to] = [Number(process.argv[2] ?? 0), Number(process.argv[3] ?? LEVELS.length)];
for (let i = from; i < to; i++) {
  const lv = LEVELS[i];
  const pz = loadLevel(i);
  const lay = pz.solutionLayout();
  const r = run(pz, lay);
  const m = play(pz, 12);
  const sig = [...lay.stops].map((k) => k + (lay.facing.has(k) ? "@" + "NESW"[lay.facing.get(k)!] : "")).join(" ");
  let easy = "";
  try { easy = pz.blockSignals ? brainless(pz, lay, routesOf(pz, (lv.solution!.paths as any)).map((x) => x.path)) : ""; } catch (e) { easy = "?" + String(e).slice(0, 60); }
  const bare = lay.clone(); bare.stops.clear();
  console.log(`${lv.id} ${lv.name.padEnd(16)} ${pz.blockSignals ? "block" : "stop "} dl=${pz.deadline} ref:${r.success ? "ok@" + r.beats : "FAIL " + JSON.stringify(r.events.filter((e) => e.kind !== "arrived").slice(0, 2))} nosig:${run(pz, bare).success ? "ok" : "fail"} sig=[${sig}] model:${m.solved ? m.departs : "stuck"} recipe:${easy || "-"}`);
}
