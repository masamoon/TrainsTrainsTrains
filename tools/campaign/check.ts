import { LEVELS, loadLevel } from "../../src/core/levels";
import { ascii, solve } from "./solver";
const only = process.argv[2];
LEVELS.forEach((lv, i) => {
  if (only && lv.id !== only) return;
  const pz = loadLevel(i);
  const t0 = Date.now();
  const r = solve(pz, { attempts: 300, seed: 7 });
  console.log(`${lv.id} ${lv.name}: par ${pz.par}, best ${r.best?.track ?? "-"} (stops ${r.best?.stops ?? "-"}), ok ${r.successes}/${r.attempts} [${r.bestTracks.join(",")}] ${Date.now() - t0}ms`);
  if (only && r.best) console.log(ascii(pz, r.best.lay));
});
