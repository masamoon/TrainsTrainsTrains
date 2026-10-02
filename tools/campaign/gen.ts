// Generates candidate campaign levels from a recipe and scores them with the solver.
// Design tool only: chosen levels are frozen into src/core/levels.ts as plain data.

import type { Layout } from "../../src/core/layout";
import { type Cell, type Dir, DIRS, E, type LevelData, N, Puzzle, S, W, ckey, opp, step } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { type Found, Rng, ascii, obvious, solve } from "./solver";

export type Theme = "woods" | "water" | "town" | "hill" | "mixed";

export interface DepotSpec {
  trains: number[];
  goods?: boolean;
  every?: number;
}

export interface Recipe {
  w: number;
  h: number;
  theme: Theme;
  clusters?: [number, number];
  ridge?: boolean; // a ridge of hills with a tunnel through it
  depots: DepotSpec[];
  stations?: number[]; // colours; default one per colour used
  allowStop?: boolean;
  allowLamp?: boolean;
  fixed?: boolean; // turn one route of the cheapest solution into existing track
  timed?: number; // platforms that open late
  needStop?: boolean; // no 3-star solution without a stop signal
  strict?: boolean; // apply the easiness checks even though the stop introduces something
  needTunnel?: boolean; // the cheapest solution uses the tunnel
  rate?: [number, number]; // share of random solver attempts that succeed
  target?: number; // preferred rate when picking among candidates
  minPar?: number;
  maxPar?: number;
  stops?: [number, number]; // stop signals in the cheapest solution
  lamps?: [number, number]; // colour signals in the cheapest solution
  crossings?: number; // at least this many crossings in the cheapest solution
  corridor?: boolean; // a long narrow corridor (passing-loop levels)
  maxStops?: number;
  attempts?: number;
}

const KINDS: Record<Theme, string[]> = {
  woods: ["T", "T", "T", "~"],
  water: ["~", "~", "~", "T"],
  town: ["H", "H", "T"],
  hill: ["^", "^", "T"],
  mixed: ["T", "~", "H", "^"],
};

export function board(rng: Rng, r: Recipe): string[] {
  if (r.corridor) return corridor(rng, r);
  const g: string[][] = Array.from({ length: r.h }, () => Array(r.w).fill("."));
  const [lo, hi] = r.clusters ?? [2, 4];
  const n = rng.int(lo, hi);
  const sym = rng.int(0, 3); // 0 none, 1 mirror x, 2 mirror y, 3 point
  const set = (x: number, y: number, ch: string) => {
    if (x < 0 || y < 0 || x >= r.w || y >= r.h) return;
    g[y][x] = ch;
    if (sym === 1) g[y][r.w - 1 - x] = ch;
    if (sym === 2) g[r.h - 1 - y][x] = ch;
    if (sym === 3) g[r.h - 1 - y][r.w - 1 - x] = ch;
  };
  for (let i = 0; i < n; i++) {
    const ch = rng.pick(KINDS[r.theme]).replace("^", "T");
    let x = rng.int(0, r.w - 1);
    let y = rng.int(0, r.h - 1);
    const size = rng.int(1, 4);
    for (let j = 0; j < size; j++) {
      set(x, y, ch);
      const d = rng.int(0, 3) as Dir;
      x += [0, 1, 0, -1][d];
      y += [-1, 0, 1, 0][d];
    }
  }
  return g.map((row) => row.join(""));
}

// Solid ground with a three-wide corridor along the middle, shafts at both ends, and a
// few bays and pinch points.
function corridor(rng: Rng, r: Recipe): string[] {
  const ch = rng.pick(KINDS[r.theme]).replace("^", "T");
  const g: string[][] = Array.from({ length: r.h }, () => Array(r.w).fill(ch));
  const mid = Math.floor(r.h / 2);
  for (let y = mid - 1; y <= mid + 1; y++) for (let x = 0; x < r.w; x++) g[y][x] = ".";
  for (const x of [1, r.w - 2]) for (let y = 0; y < r.h; y++) g[y][x] = ".";
  const bays = rng.int(1, 3);
  for (let i = 0; i < bays; i++) {
    const x = rng.int(2, r.w - 3);
    const up = rng.next() < 0.5;
    const len = rng.int(1, mid - 1);
    for (let k = 1; k <= len; k++) g[up ? mid - 1 - k : mid + 1 + k][x] = ".";
  }
  const pinches = rng.int(1, 3);
  for (let i = 0; i < pinches; i++) {
    const x = rng.int(2, r.w - 3);
    g[rng.pick([mid - 1, mid + 1])][x] = ch;
  }
  return g.map((row) => row.join(""));
}

interface Border {
  pos: Cell;
  dir: Dir;
}

function border(rng: Rng, pz: Puzzle, taken: Set<string>, end?: "left" | "right"): Border | null {
  for (let tries = 0; tries < 200; tries++) {
    const side = rng.int(0, 3);
    let pos: Cell;
    let dir: Dir;
    if (side === 0) [pos, dir] = [{ x: rng.int(1, pz.w - 2), y: 0 }, S];
    else if (side === 1) [pos, dir] = [{ x: pz.w - 1, y: rng.int(1, pz.h - 2) }, W];
    else if (side === 2) [pos, dir] = [{ x: rng.int(1, pz.w - 2), y: pz.h - 1 }, N];
    else [pos, dir] = [{ x: 0, y: rng.int(1, pz.h - 2) }, E];
    if (end === "left" && pos.x > 1) continue;
    if (end === "right" && pos.x < pz.w - 2) continue;
    const port = step(pos, dir);
    if ([pos, port].some((c) => pz.blocked.has(ckey(c)) || taken.has(ckey(c)))) continue;
    if (pz.staticEdges().size && DIRS.some((d) => pz.staticEdges().has(`${port.x},${port.y},${d}`))) continue;
    // Keep ports apart so platforms and depots don't touch.
    let near = false;
    for (const k of taken) {
      const [x, y] = k.split(",").map(Number);
      if (Math.abs(x - pos.x) + Math.abs(y - pos.y) < 2) near = true;
    }
    if (near) continue;
    return { pos, dir };
  }
  return null;
}

function ridge(rng: Rng, rows: string[]): { rows: string[]; tunnel: [[number, number], [number, number]] } | null {
  const h = rows.length;
  const w = rows[0].length;
  const g = rows.map((r) => [...r]);
  const across = rng.next() < 0.5;
  const long = across ? w : h;
  const wide = across ? h : w;
  const at = (u: number, v: number): [number, number] => (across ? [u, v] : [v, u]);
  const u0 = rng.int(2, long - 4);
  const thick = rng.next() < 0.6 ? 2 : 3;
  if (u0 + thick > long - 2) return null;
  const r = rng.int(1, wide - 2);
  const lo = Math.max(0, r - rng.int(1, 4));
  const hi = Math.min(wide - 1, r + rng.int(1, 4));
  if (hi - lo + 1 > wide - 1) return null;
  for (let v = lo; v <= hi; v++)
    for (let u = u0; u < u0 + thick; u++) {
      const [x, y] = at(u, v);
      g[y][x] = "^";
    }
  for (const u of [u0 - 1, u0 + thick]) {
    const [x, y] = at(u, r);
    g[y][x] = ".";
  }
  return { rows: g.map((row) => row.join("")), tunnel: [at(u0, r), at(u0 + thick - 1, r)] };
}

export interface Candidate {
  seed: number;
  data: LevelData;
  pz: Puzzle;
  best: Found;
  rate: number;
  noStop: number; // cheapest found with no stop signals (Infinity if none)
}

export function features(pz: Puzzle, lay: Layout) {
  let crossings = 0;
  let switches = 0;
  for (let y = 0; y < pz.h; y++)
    for (let x = 0; x < pz.w; x++) {
      if (!pz.buildable({ x, y })) continue;
      const n = lay.dirsAt(pz, { x, y }).length;
      if (n === 4) crossings++;
      if (n === 3) switches++;
    }
  return { crossings, switches, stops: lay.stops.size, lamps: lay.lamps.size };
}

export function candidate(r: Recipe, seed: number, attempts = r.attempts ?? 160): Candidate | null {
  const rng = new Rng(seed * 7919 + 13);
  let rows = board(rng, r);
  let tunnels: LevelData["tunnels"];
  if (r.ridge) {
    const rd = ridge(rng, rows);
    if (!rd) return null;
    rows = rd.rows;
    tunnels = [rd.tunnel];
  }
  const data: LevelData = { rows, depots: [], stations: [], tunnels, allowStop: r.allowStop ?? true, allowLamp: r.allowLamp ?? true };
  let pz: Puzzle;
  try {
    pz = Puzzle.fromData({ ...data, par: 1 });
  } catch {
    return null;
  }
  const taken = new Set<string>();
  const claim = (b: Border) => {
    taken.add(ckey(b.pos));
    taken.add(ckey(step(b.pos, b.dir)));
  };
  // Keep tunnel stubs free.
  for (const tn of pz.tunnels) {
    const d = DIRS.find((dd) => step(tn.cells[0], dd).x === tn.cells[1].x && step(tn.cells[0], dd).y === tn.cells[1].y)!;
    taken.add(ckey(step(tn.a, opp(d))));
    taken.add(ckey(step(tn.b, d)));
  }
  const ends: ("left" | "right")[] = [];
  for (const [k, ds] of r.depots.entries()) {
    const end = r.corridor ? (k % 2 === 0 ? "left" : "right") : undefined;
    if (end) ends[ds.trains[0]] = end === "left" ? "right" : "left";
    const b = border(rng, pz, taken, end);
    if (!b) return null;
    claim(b);
    data.depots.push({
      at: [b.pos.x, b.pos.y],
      dir: "NESW"[b.dir],
      trains: ds.trains,
      every: ds.every ?? (ds.trains.length > 1 ? rng.int(3, 4) : 3),
      start: rng.int(0, 3),
      goods: ds.goods || undefined,
    });
  }
  const colours = r.stations ?? [...new Set(r.depots.flatMap((d) => d.trains))].sort();
  for (const c of colours) {
    const b = border(rng, pz, taken, ends[c]);
    if (!b) return null;
    claim(b);
    data.stations.push({ at: [b.pos.x, b.pos.y], dir: "NESW"[b.dir], color: c });
  }
  pz = Puzzle.fromData({ ...data, par: 1 });
  let rep = solve(pz, { attempts, seed: seed + 1, maxStops: r.maxStops });
  if (!rep.best) return null;

  if (r.fixed) {
    // Lay one route of the cheapest solution as existing track, then solve again.
    const paths = rep.best.paths.filter((p) => p.length > 4);
    if (!paths.length) return null;
    const p = rng.pick(paths);
    data.fixed = [p.slice(1, -1).map((c) => [c.x, c.y] as [number, number])];
    pz = Puzzle.fromData({ ...data, par: 1 });
    rep = solve(pz, { attempts, seed: seed + 2, maxStops: r.maxStops });
    if (!rep.best) return null;
  }
  if (r.timed) {
    // Open some platforms a few beats after the cheapest solution's first arrival there.
    const res = run(pz, rep.best.lay);
    const idx = rng.shuffle(data.stations.map((_, i) => i)).slice(0, r.timed);
    for (const i of idx) {
      const st = data.stations[i];
      const first = res.events.filter((e) => e.kind === "arrived" && e.pos.x === st.at[0] && e.pos.y === st.at[1]).map((e) => e.t);
      if (!first.length) return null;
      st.opens = Math.min(...first) + rng.int(2, 5);
    }
    pz = Puzzle.fromData({ ...data, par: 1 });
    rep = solve(pz, { attempts, seed: seed + 4, maxStops: r.maxStops ?? 3 });
    if (!rep.best) return null;
  }
  if (r.minPar && rep.best.track < r.minPar) return null;
  if (r.maxPar && rep.best.track > r.maxPar) return null;
  const f = features(pz, rep.best.lay);
  if (r.stops && (f.stops < r.stops[0] || f.stops > r.stops[1])) return null;
  if (r.lamps && (f.lamps < r.lamps[0] || f.lamps > r.lamps[1])) return null;
  if (r.crossings && f.crossings < r.crossings) return null;
  const rate = rep.successes / rep.attempts;
  if (r.rate && (rate < r.rate[0] || rate > r.rate[1])) return null;
  let noStop = Infinity;
  if (r.needStop) {
    const ns = solve(pz, { attempts: Math.min(attempts, 80), seed: seed + 3, maxStops: 0 });
    noStop = ns.best?.track ?? Infinity;
    if (noStop <= rep.best.track) return null;
  }
  if (r.needTunnel) {
    const used = rep.best.paths.some((p) => p.some((c) => pz.inTunnel(c)));
    if (!used) return null;
  }
  return { seed, data, pz, best: rep.best, rate, noStop };
}

export function freeze(c: Candidate): LevelData {
  const lay: Layout = c.best.lay;
  const dirChar = (d: number) => "NESW"[d];
  const xy = (k: string) => k.split(",").map(Number) as [number, number];
  const sol: NonNullable<LevelData["solution"]> = { paths: c.best.paths.map((p) => p.map((q) => [q.x, q.y] as [number, number])) };
  if (lay.stops.size) sol.stops = [...lay.stops].map(xy);
  if (lay.lamps.size) sol.lamps = [...lay.lamps].map(([k, col]) => [...xy(k), col] as [number, number, number]);
  if (lay.levers.size) sol.levers = [...lay.levers].map(([k, d]) => [...xy(k), dirChar(d)] as [number, number, string]);
  const out: LevelData = { ...c.data, solution: sol };
  if (!out.tunnels) delete out.tunnels;
  out.depots = out.depots.map((d) => Object.fromEntries(Object.entries(d).filter(([, v]) => v !== undefined))) as LevelData["depots"];
  return out;
}

export function describe(c: Candidate): string {
  const res = run(c.pz, c.best.lay);
  const head = `seed ${c.seed}: ${c.pz.w}x${c.pz.h} par ${c.best.track} stops ${c.best.stops} lamps ${c.best.lay.lamps.size} rate ${(c.rate * 100).toFixed(0)}% noStop ${c.noStop} beats ${res.beats}`;
  const trains = c.data.depots.map((d) => `[${d.trains.join("")}${d.goods ? "g" : ""}/${d.every ?? 3}+${d.start ?? 0}]`).join(" ");
  return `${head} ${trains}\n${ascii(c.pz, c.best.lay)}`;
}

// Searches harder for a cheaper reference, and re-checks that a stop signal is needed.
// Returns false when the candidate doesn't hold up.
// `strict` (every stop that doesn't introduce something) also rejects boards that are
// easier than their par suggests; see easyWhy.
export function deepen(c: Candidate, r: Recipe, log: (s: string) => void = () => {}, strict = false): boolean {
  const deep = solve(c.pz, { attempts: 1500, seed: 99, maxStops: r.maxStops ?? 3 });
  if (deep.best && (deep.best.track < c.best.track || (deep.best.track === c.best.track && deep.best.stops < c.best.stops))) {
    log(`par ${c.best.track} -> ${deep.best.track}`);
    c.best = deep.best;
  }
  let noStop = Infinity;
  if (r.needStop || (strict && c.best.stops > 0)) noStop = solve(c.pz, { attempts: 1000, seed: 98, maxStops: 0 }).best?.track ?? Infinity;
  if (r.needStop) {
    if (c.best.stops === 0) return false;
    if (noStop <= c.best.track) return false;
  }
  const f = features(c.pz, c.best.lay);
  if (r.stops && (f.stops < r.stops[0] || f.stops > r.stops[1])) return false;
  if (r.lamps && (f.lamps < r.lamps[0] || f.lamps > r.lamps[1])) return false;
  if (r.crossings && f.crossings < r.crossings) return false;
  if (strict) {
    const why = easyWhy(c.best.track, obvious(c.pz), f.stops > 0 ? noStop : Infinity, Math.max(c.rate, looseRate(c.pz)));
    if (why) {
      log(`too easy (${why})`);
      return false;
    }
  }
  return true;
}

// Every stop that doesn't introduce something must not be easier than its par suggests;
// a recipe can ask for the same of a stop that does (`strict`).
export function strict(st: { id: string; introTitle?: string; recipe?: Recipe }): boolean {
  return !!st.recipe?.strict || !st.introTitle;
}

// Why a board is easier than its par suggests, or "" if it isn't:
// obvious: every train on its own shortest route, patched with a few stop signals by trial
//   and error, already earns two stars;
// nostop: the stop signals in the reference solution are nearly optional (one tile over par
//   without any);
// rate: random attempts stumble on a solution too often.
export function easyWhy(par: number, ob: { patched: boolean; track: number }, noStop: number, rate: number): string {
  if (ob.patched && ob.track <= twoStar(par)) return "obvious";
  if (noStop <= par + 1) return "nostop";
  if (rate > 0.3) return "rate";
  return "";
}

// Share of random attempts that work when up to three stop signals are allowed (the recipe's
// rate may allow fewer, which undercounts boards that need several).
export function looseRate(pz: Puzzle): number {
  const r = solve(pz, { attempts: 400, seed: 3, maxStops: 3 });
  return r.successes / r.attempts;
}

// Most track that still earns two stars (starsFor in src/core/puzzle.ts).
export function twoStar(par: number): number {
  return par + Math.max(2, Math.ceil(par * 0.25));
}
