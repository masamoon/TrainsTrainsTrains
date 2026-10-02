// The lab boards with block signals: how many signal sets work, and the fewest.
import { LAB } from "../../src/core/lab";
import { Puzzle } from "../../src/core/puzzle";
import { ascii } from "../campaign/solver";
import { run } from "../../src/core/sim";
import { reference, stopSets } from "./proto";
import { play } from "./player";

for (const data of LAB) {
  const pz = Puzzle.fromData({ ...data, signals: "block" });
  const paths = data.solution!.paths;
  const sets = stopSets(pz, paths, 4, 2000);
  const fewest = sets.length ? Math.min(...sets.map((s) => s.length)) : 0;
  const p = play(pz, 12);
  console.log(`${data.name}: ${sets.length} working sets of up to 4 signals, fewest ${fewest}: ${JSON.stringify(sets.filter((s) => s.length === fewest).slice(0, 6))}; model ${p.solved ? "solves in " + p.departs : "stuck"}`);
  const beats = sets.map((st) => run(pz, reference(pz, paths, st.map((k) => k.split(",").map(Number) as [number, number]))).beats);
  const best = Math.min(...beats);
  const hist: Record<number, number> = {};
  for (const b of beats) hist[b] = (hist[b] ?? 0) + 1;
  console.log(`  finish beats: ${JSON.stringify(hist)}; fastest ${best} by ${JSON.stringify(sets.filter((_, i) => beats[i] === best).slice(0, 4))}`);
  for (const slack of [0, 2, 4]) {
    const dz = Puzzle.fromData({ ...data, signals: "block", deadline: best + slack });
    const ok = stopSets(dz, paths, 4, 2000);
    const m = play(dz, 12);
    const mb = play(dz, 30);
    console.log(`  deadline ${best + slack}: ${ok.length} sets work; model ${m.solved ? "solves in " + m.departs : "stuck"}${mb.solved && !m.solved ? ` (in ${mb.departs} with 30 tries)` : ""}`);
  }
  if (sets.length) {
    const lay = reference(pz, paths, sets.find((s) => s.length === fewest)!.map((k) => k.split(",").map(Number) as [number, number]));
    console.log(ascii(pz, lay));
  }
}
