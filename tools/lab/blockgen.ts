// Generates block-signal campaign boards: scarce track shared both ways, a deadline at the
// best run plus a little slack, and checks that nothing brainless solves them.
//
// A board comes from a family:
// - "line": a long single line with passing bays, depots at both ends, and optional spurs
//   joining from the top or bottom edge (lab 1, 3 and 7);
// - "band": open ground split by a band of water, town or hills that track can cross only
//   at a few gaps or through a single bore (lab 4 and 6).
// Then, for every sensible way to draw the routes, every set of up to `maxSignals` signals
// (each one way or both ways) on the squares that matter is run without a deadline. The
// fastest run sets the deadline; the cheapest on-time answer becomes the reference.

import type { Layout } from "../../src/core/layout";
import { type Cell, type Dir, DIRS, type LevelData, Puzzle, ckey, opp, parseCell, same, step } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { Rng } from "../campaign/solver";
import { type Step, build, play } from "./player";
import { brainless } from "./recipes";

export type Theme = "woods" | "water" | "town" | "hill";
const CH: Record<Theme, string> = { woods: "T", water: "~", town: "H", hill: "^" };

export interface DepotSpec {
  trains: number[];
  goods?: boolean;
}

export interface Spec {
  family: "line" | "band";
  w: number;
  h?: number;
  theme: Theme;
  bays?: [number, number]; // line: passing bays
  spurs?: DepotSpec[]; // line: extra depots joining from the top or bottom edge
  gaps?: [number, number]; // band: openings through the band
  tunnel?: boolean; // band: hills with one bore instead of gaps
  depots: DepotSpec[]; // line: [west end, east end]; band: any number
  every?: [number, number];
  stagger?: [number, number]; // start of the second and later depots
  slack?: number; // deadline above the best run (default 2)
  maxSignals?: number; // most signals in an answer (default 3)
  model?: number; // the person model needs at least this many Departs (99: must be stuck)
  answers?: [number, number]; // on-time signal sets that aren't supersets of another
  minSignals?: number; // fewest signals any on-time answer may use
  lamps?: boolean;
}

export interface Candidate {
  seed: number;
  data: LevelData;
  best: number;
  deadline: number;
  answers: number;
  fewest: number;
  model: string;
  why?: string;
}

const N0: Dir = 0;
const E0: Dir = 1;
const S0: Dir = 2;
const W0: Dir = 3;

// Boards

export function lineBoard(rng: Rng, sp: Spec): LevelData {
  const w = sp.w;
  const h = 5;
  const ch = CH[sp.theme];
  const g = Array.from({ length: h }, () => Array(w).fill(ch));
  for (let x = 1; x < w - 1; x++) g[2][x] = ".";
  for (const y of [1, 3]) {
    g[y][1] = ".";
    g[y][w - 2] = ".";
  }
  const [lo, hi] = sp.bays ?? [1, 2];
  const bays = rng.int(lo, hi);
  const used = new Set<number>();
  for (let i = 0, tries = 0; i < bays && tries < 50; tries++) {
    const len = rng.int(2, 3);
    const x0 = rng.int(3, w - 4 - len + 1);
    const y = rng.pick([1, 3]);
    let free = true;
    for (let x = x0 - 1; x <= x0 + len; x++) if (used.has(x)) free = false;
    if (!free) continue;
    for (let x = x0; x < x0 + len; x++) g[y][x] = ".";
    for (let x = x0 - 1; x <= x0 + len; x++) used.add(x);
    i++;
  }
  const every = () => rng.int(...(sp.every ?? [3, 4]));
  const depots: LevelData["depots"] = [
    { at: [0, 1], dir: "E", trains: sp.depots[0].trains, start: 0, every: every(), ...(sp.depots[0].goods ? { goods: true } : {}) },
    { at: [w - 1, 3], dir: "W", trains: sp.depots[1].trains, start: rng.int(...(sp.stagger ?? [1, 4])), every: every(), ...(sp.depots[1].goods ? { goods: true } : {}) },
  ];
  const stations: LevelData["stations"] = [
    { at: [w - 1, 1], dir: "W", color: sp.depots[0].trains[0] },
    { at: [0, 3], dir: "E", color: sp.depots[1].trains[0] },
  ];
  // Spurs: a depot on the top edge whose trains run to a platform on the bottom edge (or
  // the other way), crossing or sharing the main line.
  for (const s of sp.spurs ?? []) {
    for (let tries = 0; tries < 50; tries++) {
      const xa = rng.int(3, w - 4);
      const xb = rng.int(3, w - 4);
      const top = rng.next() < 0.5;
      const [ya, yb] = top ? [0, h - 1] : [h - 1, 0];
      const near = (x: number, y: number) => depots.some((d) => Math.abs(d.at[0] - x) + Math.abs(d.at[1] - y) < 2) || stations.some((t) => Math.abs(t.at[0] - x) + Math.abs(t.at[1] - y) < 2);
      if (near(xa, ya) || near(xb, yb)) continue;
      g[top ? 1 : 3][xa] = ".";
      g[top ? 3 : 1][xb] = ".";
      g[ya][xa] = ".";
      g[yb][xb] = ".";
      depots.push({ at: [xa, ya], dir: top ? "S" : "N", trains: s.trains, start: rng.int(...(sp.stagger ?? [1, 4])), every: every(), ...(s.goods ? { goods: true } : {}) });
      stations.push({ at: [xb, yb], dir: top ? "N" : "S", color: s.trains[0] });
      break;
    }
  }
  return { rows: g.map((r) => r.join("")), depots, stations, allowStop: true, allowLamp: true, signals: "block" };
}

function bandBoard(rng: Rng, sp: Spec): LevelData {
  const w = sp.w;
  const h = sp.h ?? 8;
  const ch = CH[sp.theme];
  const g = Array.from({ length: h }, () => Array(w).fill("."));
  const top = Math.floor(h / 2) - 1;
  const thick = rng.int(2, 3);
  for (let y = top; y < top + thick; y++) for (let x = 0; x < w; x++) g[y][x] = sp.tunnel ? "^" : ch;
  const tunnels: LevelData["tunnels"] = [];
  const gx: number[] = [];
  if (sp.tunnel) {
    const x = rng.int(2, w - 3);
    gx.push(x);
    // A bore needs blocked mouths on both ends: make the band at least two thick there.
    if (thick === 1) for (let x2 = 0; x2 < w; x2++) g[top + 1][x2] = "^";
    tunnels.push([[x, top], [x, top + Math.max(thick, 2) - 1]]);
  } else {
    const [lo, hi] = sp.gaps ?? [1, 1];
    const n = rng.int(lo, hi);
    for (let i = 0, tries = 0; i < n && tries < 40; tries++) {
      const x = rng.int(1, w - 2);
      if (gx.some((o) => Math.abs(o - x) < 3)) continue;
      gx.push(x);
      for (let y = top; y < top + thick; y++) g[y][x] = ".";
      i++;
    }
  }
  // A few clusters off the band keep the open ground from being a free-for-all.
  for (let i = 0; i < rng.int(1, 3); i++) {
    const x = rng.int(1, w - 2);
    const y = rng.pick([rng.int(1, top - 2), rng.int(top + Math.max(thick, 2) + 1, h - 2)]);
    if (y < 1 || y >= h - 1 || g[y][x] !== ".") continue;
    g[y][x] = sp.theme === "hill" ? "T" : ch;
  }
  const bandEnd = top + (sp.tunnel ? Math.max(thick, 2) : thick);
  const depots: LevelData["depots"] = [];
  const stations: LevelData["stations"] = [];
  const taken = new Set<string>();
  const edgeCell = (north: boolean): { at: [number, number]; dir: string } | null => {
    for (let tries = 0; tries < 60; tries++) {
      const side = rng.int(0, 2); // west, east, or the top/bottom edge
      let at: [number, number];
      let dir: string;
      if (side === 0) [at, dir] = [[0, north ? rng.int(1, top - 1) : rng.int(bandEnd + 1, h - 2)], "E"];
      else if (side === 1) [at, dir] = [[w - 1, north ? rng.int(1, top - 1) : rng.int(bandEnd + 1, h - 2)], "W"];
      else [at, dir] = [[rng.int(1, w - 2), north ? 0 : h - 1], north ? "S" : "N"];
      if (at[1] < 0 || at[1] >= h || (north && at[1] >= top) || (!north && at[1] < bandEnd)) continue;
      const k = `${at[0]},${at[1]}`;
      const v = { x: dir === "E" ? 1 : dir === "W" ? -1 : 0, y: dir === "S" ? 1 : dir === "N" ? -1 : 0 };
      const port = `${at[0] + v.x},${at[1] + v.y}`;
      const close = [...taken].some((t) => {
        const c = parseCell(t);
        return Math.abs(c.x - at[0]) + Math.abs(c.y - at[1]) < 2;
      });
      if (close || g[at[1]][at[0]] !== "." || taken.has(port)) continue;
      const pc = parseCell(port);
      if (g[pc.y][pc.x] !== ".") continue;
      taken.add(k);
      taken.add(port);
      return { at, dir };
    }
    return null;
  };
  const every = () => rng.int(...(sp.every ?? [3, 5]));
  const colorsSeen = new Set<number>();
  sp.depots.forEach((d, i) => {
    const north = i % 2 === 0;
    const a = edgeCell(north);
    if (!a) throw new Error("no room");
    depots.push({ at: a.at, dir: a.dir, trains: d.trains, start: i === 0 ? 0 : rng.int(...(sp.stagger ?? [1, 4])), every: every(), ...(d.goods ? { goods: true } : {}) });
    for (const c of new Set(d.trains)) {
      if (colorsSeen.has(c)) continue;
      colorsSeen.add(c);
      const b = edgeCell(!north);
      if (!b) throw new Error("no room");
      stations.push({ at: b.at, dir: b.dir, color: c });
    }
  });
  return { rows: g.map((r) => r.join("")), depots, stations, tunnels, allowStop: true, allowLamp: true, signals: "block" };
}

// Routes

interface Demand {
  depot: number;
  color: number;
  station: number;
}

export function demands(pz: Puzzle): Demand[] {
  const out: Demand[] = [];
  pz.depots.forEach((dp, depot) => {
    for (const color of new Set(dp.trains)) {
      const station = pz.stations.findIndex((s) => s.color === color);
      out.push({ depot, color, station });
    }
  });
  return out;
}

// Simple paths from a depot to a platform no longer than the shortest plus `extra`.
export function routes(pz: Puzzle, d: Demand, extra: number, cap: number): Step[][] {
  const dp = pz.depots[d.depot];
  const st = pz.stations[d.station];
  const goal = st.pos;
  const passable = (c: Cell) => pz.inside(c) && (same(c, goal) || (!pz.solid(c) && pz.depotIndexAt(c) < 0 && pz.stationIndexAt(c) < 0));
  // Distance to the goal over passable cells, ignoring turns.
  const dist = new Map<string, number>([[ckey(goal), 0]]);
  const q: Cell[] = [goal];
  while (q.length) {
    const c = q.shift()!;
    for (const dd of DIRS) {
      const n = step(c, dd);
      if (!passable(n) || dist.has(ckey(n))) continue;
      if (pz.inTunnel(c) || pz.inTunnel(n)) {
        // Tunnels run straight along their bore.
        const tn = pz.tunnels.find((t) => t.cells.some((tc) => same(tc, c) || same(tc, n)));
        const axis = tn ? (tn.a.x === tn.b.x ? [N0, S0] : [E0, W0]) : [];
        if (!axis.includes(dd)) continue;
      }
      dist.set(ckey(n), dist.get(ckey(c))! + 1);
      q.push(n);
    }
  }
  const start = step(dp.pos, dp.dir);
  if (!dist.has(ckey(start))) return [];
  const limit = dist.get(ckey(start))! + extra;
  const out: Cell[][] = [];
  const cells: Cell[] = [dp.pos, start];
  const seen = new Set<string>([ckey(dp.pos), ckey(start)]);
  const go = (c: Cell, entry: Dir, len: number) => {
    if (out.length >= cap) return;
    for (const o of DIRS) {
      if (o === entry) continue;
      if (pz.inTunnel(c) && o !== opp(entry)) continue;
      const n = step(c, o);
      if (same(n, goal)) {
        if (opp(o) === st.dir) out.push([...cells, n]);
        continue;
      }
      if (!passable(n) || seen.has(ckey(n))) continue;
      if (len + 1 + (dist.get(ckey(n)) ?? 999) > limit) continue;
      if (pz.inTunnel(n) && !pz.inTunnel(c)) {
        const tn = pz.tunnels.find((t) => t.cells.some((tc) => same(tc, n)))!;
        const axis = tn.a.x === tn.b.x ? [N0, S0] : [E0, W0];
        if (!axis.includes(o)) continue;
      }
      seen.add(ckey(n));
      cells.push(n);
      go(n, opp(o), len + 1);
      cells.pop();
      seen.delete(ckey(n));
    }
  };
  go(start, opp(dp.dir), 0);
  return out.map((p) =>
    p.map((c, i) => ({
      cell: c,
      in: (i === 0 ? opp(dp.dir) : opp(dirTo(p[i - 1], c) as Dir)) as Dir,
      out: (i + 1 < p.length ? dirTo(c, p[i + 1]) : opp(st.dir)) as Dir,
    })),
  );
}

const dirTo = (a: Cell, b: Cell): number => DIRS.find((d) => same(step(a, d), b)) ?? -1;

// Signals

// The squares where a signal could matter: plain track next to a junction, crossing,
// depot or platform, plus the middle of every longer stretch.
function signalSquares(pz: Puzzle, lay: Layout): Cell[] {
  const plain = (c: Cell) => pz.buildable(c) && lay.dirsAt(pz, c).length === 2;
  const special = (c: Cell) => pz.inside(c) && (lay.dirsAt(pz, c).length >= 3 || pz.depotIndexAt(c) >= 0 || pz.stationIndexAt(c) >= 0 || pz.inTunnel(c));
  const out = new Map<string, Cell>();
  const seen = new Set<string>();
  for (let y = 0; y < pz.h; y++)
    for (let x = 0; x < pz.w; x++) {
      const c = { x, y };
      if (!plain(c) || seen.has(ckey(c))) continue;
      // Walk the stretch this square is on.
      const stretch: Cell[] = [c];
      seen.add(ckey(c));
      for (const d0 of lay.dirsAt(pz, c)) {
        let cur = c;
        let d = d0;
        const side: Cell[] = [];
        for (;;) {
          const n = step(cur, d);
          if (!plain(n) || seen.has(ckey(n))) break;
          seen.add(ckey(n));
          side.push(n);
          const next = lay.dirsAt(pz, n).find((e) => e !== opp(d));
          if (next === undefined) break;
          cur = n;
          d = next;
        }
        if (d0 === lay.dirsAt(pz, c)[0]) stretch.unshift(...side.reverse());
        else stretch.push(...side);
      }
      const ends = stretch.filter((s) => lay.dirsAt(pz, s).some((d) => special(step(s, d))));
      for (const s of ends) out.set(ckey(s), s);
      if (stretch.length >= 3) {
        const m = stretch[Math.floor(stretch.length / 2)];
        out.set(ckey(m), m);
      }
      if (stretch.length >= 7) {
        for (const f of [0.25, 0.75]) {
          const m = stretch[Math.floor(stretch.length * f)];
          out.set(ckey(m), m);
        }
      }
    }
  return [...out.values()];
}

interface Answer {
  combo: number;
  sigs: string[]; // "x,y" or "x,y@D"
  beats: number;
  track: number;
}

function withSigs(base: Layout, sigs: string[]): Layout {
  const lay = base.clone();
  for (const s of sigs) {
    const [k, f] = s.split("@");
    lay.stops.add(k);
    if (f) lay.facing.set(k, "NESW".indexOf(f) as Dir);
  }
  return lay;
}

// Every working signal set (up to `max`) for one track, skipping extensions of a set that
// already works. Runs without a deadline; the caller filters by beats.
function answersFor(pz: Puzzle, base: Layout, max: number, budget: number): { sigs: string[]; beats: number }[] {
  const cells = signalSquares(pz, base);
  const cand = cells.map((c) => {
    const k = ckey(c);
    return [k, ...base.dirsAt(pz, c).map((d) => `${k}@${"NESW"[d]}`)];
  });
  const out: { sigs: string[]; beats: number }[] = [];
  const works: string[][] = [];
  let runs = 0;
  const pick: string[] = [];
  const go = (from: number, size: number) => {
    if (runs > budget) return;
    if (pick.length === size) {
      const cellsPicked = pick.map((s) => s.split("@")[0]);
      if (works.some((w) => w.every((s) => cellsPicked.includes(s.split("@")[0]) && pick.includes(s)))) return;
      runs++;
      const r = run(pz, withSigs(base, pick));
      if (r.success) {
        out.push({ sigs: [...pick], beats: r.beats });
        works.push([...pick]);
      }
      return;
    }
    for (let i = from; i < cand.length; i++)
      for (const v of cand[i]) {
        pick.push(v);
        go(i + 1, size);
        pick.pop();
      }
  };
  for (let size = 0; size <= max; size++) go(0, size);
  return out;
}

// Generation

export function generate(sp: Spec, seed: number, verbose = false): Candidate | { seed: number; why: string } {
  const rng = new Rng(seed);
  let data: LevelData;
  try {
    data = sp.family === "line" ? lineBoard(rng, sp) : bandBoard(rng, sp);
  } catch (e) {
    return { seed, why: String(e) };
  }
  data.allowLamp = sp.lamps ?? true;
  const pz = Puzzle.fromData({ ...data, par: 1 });
  const ds = demands(pz);
  if (ds.some((d) => d.station < 0)) return { seed, why: "no platform" };
  const options = ds.map((d) => routes(pz, d, sp.family === "line" ? 6 : 4, sp.family === "line" ? 12 : 8));
  if (options.some((o) => !o.length)) return { seed, why: "unreachable" };
  // Combos of one route per demand, cheapest first.
  let combos: Step[][][] = [[]];
  for (const o of options) combos = combos.flatMap((c) => o.map((p) => [...c, p]));
  const lens = (c: Step[][]) => c.reduce((n, p) => n + p.length, 0);
  combos.sort((a, b) => lens(a) - lens(b));
  // Open ground gives many near-identical ways to draw the same idea: keep the cheapest.
  combos = combos.slice(0, sp.family === "line" ? 40 : 12);
  const answers: Answer[] = [];
  const bases: Layout[] = [];
  const max = sp.maxSignals ?? 3;
  combos.forEach((c, ci) => {
    const lay = build(pz, c.map((path, i) => ({ d: { depot: ds[i].depot, color: ds[i].color, stations: [ds[i].station] }, path })), new Set());
    bases[ci] = lay as Layout;
    if (!lay) return;
    for (const a of answersFor(pz, lay, max, sp.family === "line" ? 20000 : 5000)) answers.push({ combo: ci, sigs: a.sigs, beats: a.beats, track: lay.trackCount(pz) });
  });
  if (!answers.length) return { seed, why: "no answer" };
  const best = Math.min(...answers.map((a) => a.beats));
  const deadline = best + (sp.slack ?? 2);
  const onTime = answers.filter((a) => a.beats <= deadline);
  if (onTime.some((a) => a.sigs.length === 0)) return { seed, why: "works without signals" };
  const fewest = Math.min(...onTime.map((a) => a.sigs.length));
  if (sp.minSignals && fewest < sp.minSignals) return { seed, why: `only ${fewest} signals needed` };
  // Distinct answers: signal sets regardless of which track carries them.
  const distinct = new Set(onTime.map((a) => [...a.sigs].sort().join(" ")));
  if (sp.answers && (distinct.size < sp.answers[0] || distinct.size > sp.answers[1])) return { seed, why: `${distinct.size} answers` };
  // The reference: least track, then fewest signals, then fewest both-ways signals.
  onTime.sort((a, b) => a.track - b.track || a.sigs.length - b.sigs.length || a.sigs.filter((s) => !s.includes("@")).length - b.sigs.filter((s) => !s.includes("@")).length || a.beats - b.beats);
  const ref = onTime[0];
  const lay = withSigs(bases[ref.combo], ref.sigs);
  const paths = combos[ref.combo].map((p) => p.map((s) => [s.cell.x, s.cell.y] as [number, number]));
  data = { ...data, deadline, solution: freeze(lay, paths) };
  const dz = Puzzle.fromData({ ...data, par: 1 });
  dz.par = lay.trackCount(dz);
  if (!run(dz, dz.solutionLayout()).success) return { seed, why: "reference fails" };
  const easy = brainless(dz, lay, combos[ref.combo]);
  if (easy) return { seed, why: `recipe: ${easy}` };
  const m = play(dz, 12);
  const need = sp.model ?? 3;
  if (m.solved && m.departs < need) return { seed, why: `model solves in ${m.departs}` };
  data.par = dz.par;
  if (verbose) console.log(`seed ${seed}: best ${best}, ${distinct.size} answers, fewest ${fewest}, model ${m.solved ? m.departs : "stuck"}`);
  return { seed, data, best, deadline, answers: distinct.size, fewest, model: m.solved ? String(m.departs) : "stuck" };
}

const xy = (k: string): [number, number] => {
  const c = parseCell(k);
  return [c.x, c.y];
};

export function freeze(lay: Layout, paths: [number, number][][]): NonNullable<LevelData["solution"]> {
  const sol: NonNullable<LevelData["solution"]> = { paths };
  if (lay.stops.size) sol.stops = [...lay.stops].map(xy);
  if (lay.facing.size) sol.facing = [...lay.facing].map(([k, d]) => [...xy(k), "NESW"[d]] as [number, number, string]);
  if (lay.lamps.size) sol.lamps = [...lay.lamps].map(([k, c]) => [...xy(k), c] as [number, number, number]);
  if (lay.levers.size) sol.levers = [...lay.levers].map(([k, d]) => [...xy(k), "NESW"[d]] as [number, number, string]);
  if (lay.stems.size) sol.stems = [...lay.stems].map(([k, d]) => [...xy(k), "NESW"[d]] as [number, number, string]);
  return sol;
}
