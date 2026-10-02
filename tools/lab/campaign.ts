// Plays every campaign stop with the crash-guided player model: tools/campaign/run.sh ../lab/campaign
import { LEVELS, loadLevel } from "../../src/core/levels";
import { play } from "./player";

let solved = 0;
let fast = 0;
const byLine = new Map<number, number[]>();
for (let i = 0; i < LEVELS.length; i++) {
  const lv = LEVELS[i];
  const pz = loadLevel(i);
  const r = play(pz);
  if (r.solved) solved++;
  if (r.solved && r.departs <= 4) fast++;
  if (!byLine.has(lv.line)) byLine.set(lv.line, []);
  byLine.get(lv.line)!.push(r.solved ? r.departs : -1);
  console.log(`${lv.id.padEnd(5)} ${lv.name.padEnd(22)} par ${String(pz.par).padStart(2)} ${r.solved ? `solved in ${r.departs} departs, track ${r.track}` : `NOT solved (${r.log.join("; ")})`}`);
}
console.log(`\n${solved}/${LEVELS.length} solved by crash-guided repair; ${fast} within 4 departs`);
for (const [line, ds] of byLine) console.log(`line ${line + 1}: ${ds.map((d) => (d < 0 ? "x" : d)).join(" ")}`);
