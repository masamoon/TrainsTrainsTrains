// Checks a prototype: the reference works, and the player model's verdict.
// A prototype's reference is paths plus stop signals; stems, levers and lamps follow from
// the paths (build in player.ts), so straight-through junctions work.
import type { Layout } from "../../src/core/layout";
import { type Cell, type Dir, type LevelData, Puzzle, ckey, dirBetween, opp } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { ascii } from "../campaign/solver";
import { type Step, build, lastBad, play } from "./player";

// A signal: its square, plus the way it faces when it is a one-way block signal (NESW).
export type Sig = [number, number] | [number, number, string];
export const sigKey = ([x, y, f]: Sig): string => ckey({ x, y }) + (f ? "@" + f : "");
export const parseSig = (k: string): Sig => {
  const [c, f] = k.split("@");
  const [x, y] = c.split(",").map(Number);
  return f ? [x, y, f] : [x, y];
};

export function routesOf(pz: Puzzle, paths: [number, number][][]) {
  return paths.map((p) => {
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
}

export function reference(pz: Puzzle, paths: [number, number][][], stops: Sig[] = []): Layout {
  const routes = routesOf(pz, paths);
  const lay = build(pz, routes, new Set(stops.map(sigKey)));
  if (!lay) throw new Error(`reference can't be built (trouble at ${lastBad})`);
  return lay;
}

export function check(data: LevelData, paths: [number, number][][], stops: Sig[] = [], verbose = true) {
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
// paths work. Empty when the track itself can't be made to work with stops alone. On
// block-signal boards each square can hold a signal facing either way or both ways; keys
// are "x,y" or "x,y@D" (see sigKey).
export function stopSets(pz: Puzzle, paths: [number, number][][], max = 3, limit = 50): string[][] {
  const lay0 = reference(pz, paths);
  const cells = [...new Set(paths.flat().map(([x, y]) => ckey({ x, y })))].filter((k) => {
    const [x, y] = k.split(",").map(Number);
    return pz.buildable({ x, y }) && lay0.dirsAt(pz, { x, y }).length === 2;
  });
  const cand: string[][] = cells.map((k) => {
    const [x, y] = k.split(",").map(Number);
    return pz.blockSignals ? [k, ...lay0.dirsAt(pz, { x, y }).map((d) => `${k}@${"NESW"[d]}`)] : [k];
  });
  // Smallest sets first, so the limit only cuts off the largest. A set that works is not
  // extended further.
  const out: string[][] = [];
  const works = new Set<string>();
  const pick: string[] = [];
  const go = (from: number, size: number) => {
    if (out.length >= limit) return;
    if (pick.length === size) {
      const lay = lay0.clone();
      for (const s of pick) {
        const [k, f] = s.split("@");
        lay.stops.add(k);
        if (f) lay.facing.set(k, "NESW".indexOf(f) as Dir);
      }
      if (run(pz, lay).success) {
        out.push([...pick]);
        works.add(pick.join(" "));
      }
      return;
    }
    for (let i = from; i < cand.length; i++) {
      for (const v of cand[i]) {
        pick.push(v);
        // Skip extensions of a set that already works.
        if (!works.has(pick.join(" "))) go(i + 1, size);
        pick.pop();
      }
    }
  };
  for (let size = 0; size <= max; size++) go(0, size);
  return out;
}
