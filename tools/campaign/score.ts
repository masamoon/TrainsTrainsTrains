// Scores every campaign stop and flags the ones easier than their par suggests (see easyWhy
// in gen.ts; stops that introduce something are allowed to be easy): run.sh score [line]
// rate: share of random solver attempts that work (lower is harder to stumble on).
// obvious: whether each train on its own shortest route already works (WORKS), works once
//   patched with stop signals within two stars (PATCH), or neither (fails).
// nostop: cheapest solution found without stop signals.
// work: how much the player has to work out in the reference solution.
import { Layout } from "../../src/core/layout";
import { LEVELS, loadLevel } from "../../src/core/levels";
import { easyWhy, features, looseRate, twoStar } from "./gen";
import { obvious, solve } from "./solver";

const only = process.argv[2];
const flagged: string[] = [];
for (let i = 0; i < LEVELS.length; i++) {
  const lv = LEVELS[i];
  if (only && String(lv.line + 1) !== only) continue;
  const pz = loadLevel(i);
  const lay: Layout = pz.solutionLayout();
  const f = features(pz, lay);
  const ob = obvious(pz);
  const rate = looseRate(pz);
  const ns = pz.allowStop ? solve(pz, { attempts: 1000, seed: 98, maxStops: 0 }).best?.track ?? Infinity : Infinity;
  const w = work(f, ob.ok, pz.trainCount());
  const why = easyWhy(pz.par, ob, f.stops > 0 ? ns : Infinity, rate);
  const teaching = !!lv.introTitle || lv.line < 2;
  if (why && !teaching) flagged.push(`${lv.id}(${why})`);
  console.log(`${lv.id.padEnd(5)} ${lv.name.padEnd(22)} par ${String(pz.par).padStart(2)} rate ${(rate * 100).toFixed(0).padStart(3)}% obvious ${ob.ok ? "WORKS" : ob.patched && ob.track <= twoStar(pz.par) ? "PATCH" : "fails"} ${ob.track} work ${w} ${JSON.stringify(f)} trains ${pz.trainCount()} nostop ${ns}${why ? ` EASY:${why}` : ""}${teaching ? " teach" : ""}`);
}
if (flagged.length) console.log(`FLAGGED ${flagged.join(" ")}`);

export function work(f: ReturnType<typeof features>, obviousOk: boolean, trains: number): number {
  return f.stops * 2 + f.lamps * 2 + f.crossings + f.switches + trains + (obviousOk ? 0 : 3);
}
