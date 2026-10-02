// Checks a prototype: the reference works, and the player model's verdict.
// A prototype's reference is paths plus stop signals; stems, levers and lamps follow from
// the paths (build in player.ts), so straight-through junctions work.
import type { Layout } from "../../src/core/layout";
import { type Cell, type Dir, type LevelData, Puzzle, ckey, dirBetween, opp } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { ascii } from "../campaign/solver";
import { type Step, build, lastBad, play } from "./player";

export function reference(pz: Puzzle, paths: [number, number][][], stops: [number, number][] = []): Layout {
  const routes = paths.map((p) => {
    const cells: Cell[] = p.map(([x, y]) => ({ x, y }));
    const depot = pz.depotIndexAt(cells[0]);
    const station = pz.stationIndexAt(cells[cells.length - 1]);
    if (depot < 0 || station < 0) throw new Error(`path must run depot to platform: ${JSON.stringify(p)}`);
    const path: Step[] = cells.map((c, i) => ({
      cell: c,
      in: (i === 0 ? opp(pz.depots[depot].dir) : opp(dirBetween(cells[i - 1], c) as Dir)) as Dir,
      out: (i === cells.length - 1 ? opp(pz.stations[station].dir) : dirBetween(c, cells[i + 1])) as Dir,
    }));
    for (const s of path) if ((s.in as number) < 0 || (s.out as number) < 0) throw new Error("path not continuous");
    return { d: { depot, color: pz.stations[station].color, stations: [station] }, path };
  });
  const lay = build(pz, routes, new Set(stops.map(([x, y]) => ckey({ x, y }))));
  if (!lay) throw new Error(`reference can't be built (trouble at ${lastBad})`);
  return lay;
}

export function check(data: LevelData, paths: [number, number][][], stops: [number, number][] = [], verbose = true) {
  const pz = Puzzle.fromData({ ...data, par: 1 });
  const lay = reference(pz, paths, stops);
  pz.par = lay.trackCount(pz);
  const res = run(pz, lay);
  const p = play(pz, 12);
  const pb = play(pz, 12, { track: pz.par });
  if (verbose) {
    console.log(`\n${data.name}: reference ${res.success ? "WORKS" : "FAILS " + JSON.stringify(res.events.filter((e) => e.kind !== "arrived").map((e) => [e.t, e.kind, e.pos.x, e.pos.y]))} par ${pz.par} stops ${lay.stops.size}`);
    console.log(ascii(pz, lay));
    console.log(`model: ${p.solved ? `SOLVED in ${p.departs}, track ${p.track}` : "stuck " + p.log.join(";")}; par as budget: ${pb.solved ? `SOLVED in ${pb.departs}, track ${pb.track}` : "stuck"}`);
    if (p.lay && p.solved) console.log(ascii(pz, p.lay));
  }
  return { ok: res.success, model: p, budget: pb, pz, lay };
}

// Every set of up to `max` stop signals (on plain track along the paths) that makes the
// paths work. Empty when the track itself can't be made to work with stops alone.
export function stopSets(pz: Puzzle, paths: [number, number][][], max = 3, limit = 50): string[][] {
  const lay0 = reference(pz, paths);
  const cand = [...new Set(paths.flat().map(([x, y]) => ckey({ x, y })))].filter((k) => {
    const [x, y] = k.split(",").map(Number);
    return pz.buildable({ x, y }) && lay0.dirsAt(pz, { x, y }).length === 2;
  });
  const out: string[][] = [];
  const pick: string[] = [];
  const go = (from: number) => {
    if (out.length >= limit) return;
    const lay = lay0.clone();
    for (const k of pick) lay.stops.add(k);
    if (run(pz, lay).success) {
      out.push([...pick]);
      return;
    }
    if (pick.length >= max) return;
    for (let i = from; i < cand.length; i++) {
      pick.push(cand[i]);
      go(i + 1);
      pick.pop();
    }
  };
  go(0);
  return out;
}
