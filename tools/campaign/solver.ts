// A randomised solver for campaign levels. It is a design tool, not part of the game:
// it searches for cheap layouts (routes found with noisy costs, levers and lamps worked out
// from where each colour must go, stop signals added where trains collide) and reports the
// cheapest it found and how often a random attempt works.

import { Layout } from "../../src/core/layout";
import { type Cell, type Dir, DIRS, Puzzle, ckey, edgeKey, opp, same, step } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";

export class Rng {
  private s: number;
  constructor(seed: number) {
    this.s = seed >>> 0;
  }
  next(): number {
    this.s = (this.s + 0x6d2b79f5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  int(lo: number, hi: number): number {
    return lo + Math.floor(this.next() * (hi - lo + 1));
  }
  pick<T>(a: T[]): T {
    return a[Math.floor(this.next() * a.length)];
  }
  shuffle<T>(a: T[]): T[] {
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }
}

export interface Step {
  cell: Cell;
  in: Dir;
  out: Dir;
}

// One stream that must be routed: trains of `color` from depot `depot`.
interface Demand {
  depot: number;
  color: number;
  stations: number[];
}

export function demands(pz: Puzzle): Demand[] {
  const out: Demand[] = [];
  pz.depots.forEach((dp, depot) => {
    for (const color of new Set(dp.trains)) {
      const stations = pz.stations.map((s, i) => (s.color === color ? i : -1)).filter((i) => i >= 0);
      out.push({ depot, color, stations });
    }
  });
  return out;
}

export interface Found {
  lay: Layout;
  track: number;
  paths: Cell[][];
  stops: number;
  routes: Route[];
}

export interface SolveOpts {
  attempts: number;
  seed?: number;
  maxStops?: number;
  noise?: number;
  shareBonus?: number;
  bypasses?: number;
}

export interface Report {
  best: Found | null;
  successes: number;
  attempts: number;
  bestTracks: number[];
}

export function solve(pz: Puzzle, opts: SolveOpts): Report {
  const rng = new Rng(opts.seed ?? 1);
  let best: Found | null = null;
  let successes = 0;
  const tracks: number[] = [];
  const ds = demands(pz);
  for (let a = 0; a < opts.attempts; a++) {
    const f = attempt(pz, ds, rng, opts);
    if (!f) continue;
    successes++;
    tracks.push(f.track);
    if (!best || f.track < best.track || (f.track === best.track && f.stops < best.stops)) best = f;
  }
  if (best) best = improve(pz, best, rng, pz.allowStop ? (opts.maxStops ?? 2) : 0);
  return { best, successes, attempts: opts.attempts, bestTracks: tracks.sort((x, y) => x - y).slice(0, 8) };
}

// Local search on a solution: reroute one route at a time with little noise, keeping any
// change that still works and saves track or signals.
function improve(pz: Puzzle, start: Found, rng: Rng, maxStops: number): Found {
  let cur = start;
  for (let pass = 0; pass < 4; pass++) {
    let better = false;
    for (let i = 0; i < cur.routes.length; i++) {
      for (let k = 0; k < 4; k++) {
        const others = cur.routes.filter((_, j) => j !== i);
        const lay = new Layout();
        for (const r of others) addEdges(pz, lay, r.path);
        const noise = new Map<string, number>();
        for (let y = 0; y < pz.h; y++) for (let x = 0; x < pz.w; x++) noise.set(`${x},${y}`, k === 0 ? 0 : rng.next() * 0.6);
        const old = cur.routes[i];
        const st = pz.stationIndexAt(old.path[old.path.length - 1].cell);
        const path = route(pz, lay, old.d.depot, st, noise, k === 0 ? 1 : rng.next(), rng);
        if (!path) continue;
        const routes = [...cur.routes];
        routes[i] = { d: old.d, path };
        const f = evaluate(pz, routes, maxStops, rng);
        if (f && (f.track < cur.track || (f.track === cur.track && f.stops < cur.stops))) {
          cur = f;
          better = true;
        }
      }
    }
    if (!better) break;
  }
  return cur;
}

export type Route = { d: Demand; path: Step[] };

function attempt(pz: Puzzle, ds: Demand[], rng: Rng, opts: SolveOpts): Found | null {
  const lay = new Layout();
  const routes: Route[] = [];
  const order = rng.shuffle([...ds]);
  const noise = new Map<string, number>();
  const amp = opts.noise ?? 1.2;
  for (let y = 0; y < pz.h; y++) for (let x = 0; x < pz.w; x++) noise.set(`${x},${y}`, rng.next() * amp);
  const share = opts.shareBonus ?? rng.next();
  for (const d of order) {
    const st = rng.pick(d.stations);
    const path = route(pz, lay, d.depot, st, noise, share, rng);
    if (!path) return null;
    addEdges(pz, lay, path);
    routes.push({ d, path });
  }
  const maxStops = pz.allowStop ? (opts.maxStops ?? 2) : 0;
  const first = evaluate(pz, routes, maxStops, rng);
  if (first) return first;
  // Passing loops: reroute a stretch where routes share track around a parallel bypass.
  for (let k = 0; k < (opts.bypasses ?? 3); k++) {
    if (!bypass(pz, routes, rng)) continue;
    const f = evaluate(pz, routes, maxStops, rng);
    if (f) return f;
  }
  return null;
}

function addEdges(pz: Puzzle, lay: Layout, path: Step[]): void {
  for (let i = 0; i < path.length - 1; i++) {
    const k = edgeKey(path[i].cell, path[i].out);
    if (!pz.staticEdges().has(k)) lay.edges.add(k);
  }
}

function evaluate(pz: Puzzle, routes: Route[], maxStops: number, rng: Rng): Found | null {
  const lay = new Layout();
  for (const r of routes) addEdges(pz, lay, r.path);
  if (!signals(pz, lay, routes)) return null;
  const track = lay.trackCount(pz);
  if (run(pz, lay).success) return found(lay, track, routes);
  if (maxStops === 0 || !addStops(pz, lay, routes, maxStops, rng)) return null;
  return found(lay, track, routes);
}

// Replaces part of one route that shares track with another by a parallel detour.
function bypass(pz: Puzzle, routes: Route[], rng: Rng): boolean {
  const ri = rng.int(0, routes.length - 1);
  const path = routes[ri].path;
  const others = new Set<string>();
  routes.forEach((r, i) => i !== ri && r.path.forEach((s) => others.add(ckey(s.cell))));
  const shared = path.map((s, i) => (i > 0 && i < path.length - 1 && others.has(ckey(s.cell)) ? i : -1)).filter((i) => i >= 0);
  if (shared.length === 0) return false;
  const lay = new Layout();
  for (const r of routes) addEdges(pz, lay, r.path);
  const own = new Set(path.map((s) => ckey(s.cell)));
  for (let tries = 0; tries < 6; tries++) {
    const mid = rng.pick(shared);
    const i = Math.max(1, mid - rng.int(0, 3));
    const j = Math.min(path.length - 2, mid + rng.int(1, 3));
    if (j - i < 1) continue;
    const a = path[i];
    const b = path[j];
    // Breadth-first over empty, buildable squares from a to b.
    const sk = (c: Cell, d: Dir) => `${c.x},${c.y},${d}`;
    const q: { c: Cell; inSide: Dir; trail: Step[] }[] = [];
    for (const o of DIRS) {
      if (o === a.in || o === a.out) continue;
      q.push({ c: a.cell, inSide: a.in, trail: [{ cell: a.cell, in: a.in, out: o }] });
    }
    const seen = new Set<string>();
    let hit: Step[] | null = null;
    while (q.length && !hit) {
      const cur = q.shift()!;
      const last = cur.trail[cur.trail.length - 1];
      const n = step(last.cell, last.out);
      const entry = opp(last.out);
      if (same(n, b.cell)) {
        if (entry !== b.in && entry !== b.out) hit = [...cur.trail, { cell: b.cell, in: entry, out: b.out }];
        continue;
      }
      if (cur.trail.length > 7 || !pz.buildable(n) || own.has(ckey(n)) || lay.dirsAt(pz, n).length > 0) continue;
      const key = sk(n, entry);
      if (seen.has(key)) continue;
      seen.add(key);
      for (const o of rng.shuffle([...DIRS])) {
        if (o === entry) continue;
        q.push({ c: n, inSide: entry, trail: [...cur.trail, { cell: n, in: entry, out: o }] });
      }
    }
    if (!hit) continue;
    routes[ri] = { d: routes[ri].d, path: [...path.slice(0, i), ...hit, ...path.slice(j + 1)] };
    return true;
  }
  return false;
}

function found(lay: Layout, track: number, routes: Route[]): Found {
  return { lay: lay.clone(), track, paths: routes.map((r) => r.path.map((s) => s.cell)), stops: lay.stops.size, routes: routes.map((r) => ({ ...r })) };
}

// Noisy cheapest route from a depot to a platform. Squares already carrying track are cheap
// so routes tend to share it.
function route(pz: Puzzle, lay: Layout, depot: number, station: number, noise: Map<string, number>, share: number, rng: Rng): Step[] | null {
  const dp = pz.depots[depot];
  const st = pz.stations[station];
  const start = dp.pos;
  const goal = st.pos;
  const fixed = pz.staticEdges();
  const sk = (c: Cell, d: Dir) => `${c.x},${c.y},${d}`;
  // States are (cell, side entered from). The depot is "entered" from behind.
  const startKey = sk(start, opp(dp.dir));
  const dist = new Map<string, number>([[startKey, 0]]);
  const prev = new Map<string, string>();
  const open = new Set<string>([startKey]);
  const turnCost = rng.next() * 0.3;
  let best = "";
  while (open.size > 0) {
    let cur = "";
    for (const k of open) if (cur === "" || dist.get(k)! < dist.get(cur)!) cur = k;
    open.delete(cur);
    const [cx, cy, cin] = cur.split(",").map(Number);
    const c = { x: cx, y: cy };
    const inSide = cin as Dir;
    if (same(c, goal)) {
      best = cur;
      break;
    }
    const outs: Dir[] = same(c, start) ? [dp.dir] : DIRS.filter((o) => o !== inSide);
    for (const out of outs) {
      if (pz.inTunnel(c) && out !== opp(inSide)) continue;
      const nxt = step(c, out);
      if (!pz.inside(nxt)) continue;
      const nk = ckey(nxt);
      const ek = edgeKey(c, out);
      if (same(nxt, goal)) {
        if (opp(out) !== st.dir) continue;
      } else {
        if (pz.depotIndexAt(nxt) >= 0 || pz.stationIndexAt(nxt) >= 0) continue;
        if (pz.blocked.has(nk) && !(pz.inTunnel(nxt) && fixed.has(ek))) continue;
      }
      // Cells beside tunnel mouths and fixed track: allowed, shape checked later.
      let cost: number;
      if (pz.inTunnel(nxt) || same(nxt, goal)) cost = 0.05;
      else {
        const has = lay.dirsAt(pz, nxt).length > 0;
        const edgeHas = lay.edges.has(ek) || fixed.has(ek);
        cost = edgeHas ? 0.1 + (1 - share) * 0.6 : has ? 0.6 + (1 - share) * 0.5 : 1;
        cost += noise.get(nk)!;
      }
      if (!same(c, start) && out !== opp(inSide)) cost += turnCost;
      const ns = sk(nxt, opp(out));
      const nd = dist.get(cur)! + cost;
      if (!dist.has(ns) || nd < dist.get(ns)!) {
        dist.set(ns, nd);
        prev.set(ns, cur);
        open.add(ns);
      }
    }
  }
  if (!best) return null;
  const states = [best];
  while (prev.has(states[0])) states.unshift(prev.get(states[0])!);
  const path: Step[] = [];
  const seen = new Set<string>();
  for (let i = 0; i < states.length; i++) {
    const [x, y, inSide] = states[i].split(",").map(Number);
    const c = { x, y };
    if (seen.has(ckey(c))) return null;
    seen.add(ckey(c));
    const out = i + 1 < states.length ? opp(Number(states[i + 1].split(",")[2]) as Dir) : (opp(st.dir) as Dir);
    path.push({ cell: c, in: inSide as Dir, out });
  }
  return path;
}

// Works out levers and lamps from where each colour has to go, and checks every route
// can actually be driven on the combined track.
export function signals(pz: Puzzle, lay: Layout, routes: { d: { color: number }; path: Step[] }[]): boolean {
  const need = new Map<string, Map<Dir, Set<number>>>();
  for (const { d, path } of routes) {
    for (let i = 1; i < path.length - 1; i++) {
      const s = path[i];
      const dirs = lay.dirsAt(pz, s.cell);
      if (!dirs.includes(s.in) || !dirs.includes(s.out)) return false;
      if (dirs.length === 2) continue;
      if (dirs.length === 4) {
        if (s.out !== opp(s.in)) return false;
        continue;
      }
      const stem = Layout.switchStem(dirs);
      if (s.in !== stem) {
        if (s.out !== stem) return false;
        continue;
      }
      const k = ckey(s.cell);
      if (!need.has(k)) need.set(k, new Map());
      const m = need.get(k)!;
      if (!m.has(s.out)) m.set(s.out, new Set());
      m.get(s.out)!.add(d.color);
    }
  }
  for (const [k, m] of need) {
    const branches = [...m.keys()];
    if (branches.length === 1) {
      lay.levers.set(k, branches[0]);
      continue;
    }
    const [a, b] = branches;
    const ca = m.get(a)!;
    const cb = m.get(b)!;
    for (const c of ca) if (cb.has(c)) return false;
    if (!pz.allowLamp) return false;
    if (ca.size === 1) {
      lay.lamps.set(k, [...ca][0]);
      lay.levers.set(k, a);
    } else if (cb.size === 1) {
      lay.lamps.set(k, [...cb][0]);
      lay.levers.set(k, b);
    } else return false;
  }
  return true;
}

// Depth-limited search for stop signals that clear every collision.
function addStops(pz: Puzzle, lay: Layout, routes: { path: Step[] }[], max: number, rng: Rng): boolean {
  const cand: string[] = [];
  const seen = new Set<string>();
  for (const r of routes)
    for (const s of r.path) {
      const k = ckey(s.cell);
      if (seen.has(k) || !pz.buildable(s.cell) || lay.dirsAt(pz, s.cell).length !== 2) continue;
      seen.add(k);
      cand.push(k);
    }
  rng.shuffle(cand);
  const tryDepth = (depth: number, from: number): boolean => {
    if (run(pz, lay).success) return true;
    if (depth === 0) return false;
    for (let i = from; i < cand.length; i++) {
      lay.stops.add(cand[i]);
      if (tryDepth(depth - 1, i + 1)) return true;
      lay.stops.delete(cand[i]);
    }
    return false;
  };
  for (let d = 1; d <= max; d++) if (tryDepth(d, 0)) return true;
  return false;
}

// The level as ASCII, with a layout drawn on it.
export function ascii(pz: Puzzle, lay?: Layout): string {
  const glyph: Record<string, string> = { woods: "T", water: "~", town: "H", hill: "^" };
  const lines: string[] = [];
  for (let y = 0; y < pz.h; y++) {
    let row = "";
    for (let x = 0; x < pz.w; x++) {
      const c = { x, y };
      const k = ckey(c);
      const di = pz.depotIndexAt(c);
      const si = pz.stationIndexAt(c);
      if (di >= 0) row += "D" + "NESW"[pz.depots[di].dir];
      else if (si >= 0) row += "S" + "rtvo"[pz.stations[si].color];
      else if (pz.inTunnel(c)) row += "==";
      else if (pz.blocked.has(k)) row += glyph[pz.blocked.get(k)!].repeat(2);
      else if (lay) {
        const dirs = lay.dirsAt(pz, c);
        const mark = lay.stops.has(k) ? "!" : lay.lamps.has(k) ? "rtvo"[lay.lamps.get(k)!] : " ";
        const shape = dirs.length === 0 ? "." : dirs.length === 4 ? "+" : dirs.length === 3 ? "Y" : dirs.includes(0) && dirs.includes(2) ? "|" : dirs.includes(1) && dirs.includes(3) ? "-" : "/";
        row += shape + (shape === "." ? " " : mark);
      } else row += ". ";
    }
    lines.push(row);
  }
  return lines.join("\n");
}
