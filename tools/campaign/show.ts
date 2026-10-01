// Prints a stop with its reference solution and the obvious answer: run.sh show 3-4
import { LEVELS, loadLevel } from "../../src/core/levels";
import { run } from "../../src/core/sim";
import { ascii } from "./solver";
for (const id of process.argv.slice(2)) {
  const i = LEVELS.findIndex((lv) => lv.id === id);
  const pz = loadLevel(i);
  const lay = pz.solutionLayout();
  console.log(`${id} par ${pz.par}`, JSON.stringify(LEVELS[i].depots), JSON.stringify(LEVELS[i].stations));
  console.log(ascii(pz, lay));
  const r = run(pz, lay);
  console.log("beats", r.beats);
}
