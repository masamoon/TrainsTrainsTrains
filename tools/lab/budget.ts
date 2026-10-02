// The campaign under hard limits: what if par were a budget, or stop signals were counted?
import { LEVELS, loadLevel } from "../../src/core/levels";
import { type Limits, play } from "./player";

const rows: [string, (par: number, stops: number) => Limits][] = [
  ["no limit", () => ({})],
  ["track <= par+2", (par) => ({ track: par + 2 })],
  ["track <= par", (par) => ({ track: par })],
  ["stops <= reference", (_p, st) => ({ stops: st })],
  ["track <= par, stops <= ref", (par, st) => ({ track: par, stops: st })],
];
for (const [name, lim] of rows) {
  let solved = 0;
  let departs = 0;
  for (let i = 0; i < LEVELS.length; i++) {
    const pz = loadLevel(i);
    const r = play(pz, 12, lim(pz.par, pz.solution.stops.length));
    if (r.solved) {
      solved++;
      departs += r.departs;
    }
  }
  console.log(`${name.padEnd(28)} solved ${solved}/${LEVELS.length}, avg departs ${(departs / solved).toFixed(1)}`);
}
