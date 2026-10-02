// A model of how a person actually solves a Wye board, for measuring difficulty.
//
// The campaign generator rates a board by how often a *random* layout works. People don't
// search at random: they draw the short way, press Depart, look at where it went wrong and
// fix that spot. This model does the same and counts the Departs:
//
// 1. Draw every train's shortest route (joining track already drawn where that is shorter).
// 2. Depart. Take the first thing that goes wrong (a crash, an early arrival).
// 3. Try every fix a person would think of *at that spot*: a stop signal somewhere on one
//    of the routes involved before the trouble, removing a stop on them, or redrawing one
//    of them around the trouble. Keep whichever gets furthest (more trains home, then
//    later trouble). It must be better than before, or the model gives up.
//
// A board this model solves in a few Departs is easy however rare a random solution is:
// the run itself points at the fix. Hard boards are the ones where the fix for the first
// crash causes the next one, or where the answer needs track the short routes never draw.

import { Layout } from "../../src/core/layout";
import { type Cell, type Dir, DIRS, type Puzzle, ckey, edgeKey, opp, same, step } from "../../src/core/puzzle";
import { type RunResult, run } from "../../src/core/sim";

export interface Step {
  cell: Cell;
  in: Dir;
  out: Dir;
}

interface Demand {
  depot: number;
  color: number;
  stations: number[];
}

interface State {
  routes: { d: Demand; path: Step[] }[];
  stops: Set<string>;
}

export interface Played {
  solved: boolean;
  departs: number; // Departs used, counting the first
  track: number;
  lay: Layout | null;
  log: string[];
  paths?: Cell[][];
}

function demands(pz: Puzzle): Demand[] {
  const out: Demand[] = [];
  pz.depots.forEach((dp, depot) => {
    for (const color of new Set(dp.trains)) {
      const stations = pz.stations.map((s, i) => (s.color === color ? i : -1)).filter((i) => i >= 0);
      out.push({ depot, color, stations });
    }
  });
  return out;
}

// Cheapest route from a depot to a platform. `penalty` makes cells costly (a person
// steering round a crash); `drawn` makes existing track cheap when `share` is set.
export function route(pz: Puzzle, depot: number, station: number, drawn: Layout | null, penalty: Map<string, number>): Step[] | null {
  const dp = pz.depots[depot];
  const st = pz.stations[station];
  const fixed = pz.staticEdges();
  const sk = (c: Cell, d: Dir) => `${c.x},${c.y},${d}`;
  const startKey = sk(dp.pos, opp(dp.dir));
  const dist = new Map<string, number>([[startKey, 0]]);
  const prev = new Map<string, string>();
  const open = new Set<string>([startKey]);
  let best = "";
  while (open.size) {
    let cur = "";
    for (const k of open) if (cur === "" || dist.get(k)! < dist.get(cur)!) cur = k;
    open.delete(cur);
    const [cx, cy, cin] = cur.split(",").map(Number);
    const c = { x: cx, y: cy };
    if (same(c, st.pos)) {
      best = cur;
      break;
    }
    const outs: Dir[] = same(c, dp.pos) ? [dp.dir] : DIRS.filter((o) => o !== cin);
    for (const out of outs) {
      if (pz.inTunnel(c) && out !== opp(cin as Dir)) continue;
      const n = step(c, out);
      if (!pz.inside(n)) continue;
      const ek = edgeKey(c, out);
      if (same(n, st.pos)) {
        if (opp(out) !== st.dir) continue;
      } else {
        if (pz.depotIndexAt(n) >= 0 || pz.stationIndexAt(n) >= 0) continue;
        if (pz.blocked.has(ckey(n)) && !(pz.inTunnel(n) && fixed.has(ek))) continue;
      }
      let cost = 1;
      if (pz.inTunnel(n) || same(n, st.pos)) cost = 0.05;
      else if (drawn && (drawn.edges.has(ek) || fixed.has(ek))) cost = 0.1;
      else if (fixed.has(ek)) cost = 0.1;
      cost += penalty.get(ckey(n)) ?? 0;
      if (!same(c, dp.pos) && out !== opp(cin as Dir)) cost += 0.01; // prefer straight
      const ns = sk(n, opp(out));
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
    const out = i + 1 < states.length ? (opp(Number(states[i + 1].split(",")[2]) as Dir) as Dir) : (opp(st.dir) as Dir);
    path.push({ cell: c, in: inSide as Dir, out });
  }
  return path;
}

// Track, stems, levers and lamps for a set of routes, or null if they can't share track
// (a cell used two incompatible ways, or a switch that would have to send one colour both ways).
export let lastBad = "";

export function build(pz: Puzzle, routes: State["routes"], stops: Set<string>): Layout | null {
  lastBad = "";
  const lay = new Layout();
  const fixed = pz.staticEdges();
  for (const r of routes)
    for (let i = 0; i < r.path.length - 1; i++) {
      const k = edgeKey(r.path[i].cell, r.path[i].out);
      if (!fixed.has(k)) lay.edges.add(k);
    }
  const uses = new Map<string, { color: number; in: Dir; out: Dir }[]>();
  for (const r of routes)
    for (let i = 1; i < r.path.length - 1; i++) {
      const s = r.path[i];
      const k = ckey(s.cell);
      if (!uses.has(k)) uses.set(k, []);
      uses.get(k)!.push({ color: r.d.color, in: s.in, out: s.out });
    }
  for (const [k, us] of uses) {
    const [x, y] = k.split(",").map(Number);
    const dirs = lay.dirsAt(pz, { x, y });
    if (dirs.length === 4) {
      if (us.some((u) => u.out !== opp(u.in))) {
      lastBad = k;
      return null;
    }
      continue;
    }
    if (dirs.length !== 3) continue;
    // The stem is the side every route through the switch uses.
    let common = new Set<Dir>(dirs);
    for (const u of us) common = new Set([...common].filter((d) => d === u.in || d === u.out));
    if (common.size !== 1) {
      lastBad = k;
      return null;
    }
    const stem = [...common][0];
    lay.stems.set(k, stem);
    const want = new Map<Dir, Set<number>>();
    for (const u of us) {
      if (u.in !== stem) continue;
      if (!want.has(u.out)) want.set(u.out, new Set());
      want.get(u.out)!.add(u.color);
    }
    const bs = [...want.keys()];
    if (bs.length === 0) continue;
    if (bs.length === 1) {
      lay.levers.set(k, bs[0]);
      continue;
    }
    const [a, b] = bs;
    const ca = want.get(a)!;
    const cb = want.get(b)!;
    if ([...ca].some((c) => cb.has(c)) || !pz.allowLamp) {
      lastBad = k;
      return null;
    }
    if (ca.size === 1) {
      lay.lamps.set(k, [...ca][0]);
      lay.levers.set(k, a);
    } else if (cb.size === 1) {
      lay.lamps.set(k, [...cb][0]);
      lay.levers.set(k, b);
    } else {
      lastBad = k;
      return null;
    }
  }
  for (const s of stops) {
    const [x, y] = s.split(",").map(Number);
    if (lay.dirsAt(pz, { x, y }).length === 2 && pz.buildable({ x, y })) lay.stops.add(s);
  }
  return lay;
}

function score(res: RunResult): number {
  const home = res.outcomes.filter((o) => o.result === "arrived").length;
  const bad = res.events.filter((e) => e.kind !== "arrived");
  const first = bad.length ? Math.min(...bad.map((e) => e.t)) : 999;
  return home * 1000 + first;
}

export interface Limits {
  track?: number; // most track allowed (a hard budget)
  stops?: number; // most stop signals allowed
}

export function play(pz: Puzzle, maxDeparts = 12, limits: Limits = {}): Played {
  const ds = demands(pz);
  const log: string[] = [];
  // Draw the short way: each stream in turn, joining what is already drawn when shorter.
  const starts: State[] = [];
  // Three habits: ignore the other lines, join them where shorter, or keep clear of them.
  for (const habit of ["ignore", "join", "apart"] as const) {
    const share = habit === "join";
    const drawn = new Layout();
    const apart = new Map<string, number>();
    const routes: State["routes"] = [];
    let ok = true;
    for (const d of ds) {
      let best: Step[] | null = null;
      for (const st of d.stations) {
        const p = route(pz, d.depot, st, share ? drawn : null, habit === "apart" ? apart : new Map());
        if (p && (!best || p.length < best.length)) best = p;
      }
      if (!best) {
        ok = false;
        break;
      }
      routes.push({ d, path: best });
      for (let i = 0; i < best.length - 1; i++) drawn.edges.add(edgeKey(best[i].cell, best[i].out));
      for (const s of best) apart.set(ckey(s.cell), 3);
    }
    // Lines that can't share a square that way: redraw the later one round it.
    for (let fix = 0; ok && fix < 6 && !build(pz, routes, new Set()); fix++) {
      const i = [...routes.keys()].reverse().find((j) => routes[j].path.some((s) => ckey(s.cell) === lastBad));
      if (i === undefined) break;
      const r = routes[i];
      const pen = new Map(habit === "apart" ? apart : []);
      pen.set(lastBad, 6);
      const p = route(pz, r.d.depot, r.path.length ? pz.stationIndexAt(r.path[r.path.length - 1].cell) : r.d.stations[0], share ? drawn : null, pen);
      if (!p) break;
      routes[i] = { d: r.d, path: p };
    }
    if (ok && build(pz, routes, new Set())) starts.push({ routes, stops: new Set() });
  }
  if (!starts.length) return { solved: false, departs: 0, track: 0, lay: null, log: ["no buildable short routes"] };
  const evalState = (s: State) => {
    const lay = build(pz, s.routes, s.stops);
    if (!lay) return null;
    if (limits.track !== undefined && lay.trackCount(pz) > limits.track) return null;
    if (limits.stops !== undefined && lay.stops.size > limits.stops) return null;
    const res = run(pz, lay);
    return { lay, res, score: res.success ? 1e9 - lay.trackCount(pz) : score(res) };
  };
  let cur: State | null = null;
  let curE: NonNullable<ReturnType<typeof evalState>> | null = null;
  for (const s of starts) {
    const e = evalState(s);
    if (e && (!curE || e.score > curE.score)) [cur, curE] = [s, e];
  }
  if (!cur || !curE) return { solved: false, departs: 0, track: 0, lay: null, log: ["short routes over budget"] };
  let departs = 1;
  while (!curE.res.success && departs < maxDeparts) {
    const bad = curE.res.events.filter((e) => e.kind !== "arrived");
    const t0 = Math.min(...bad.map((e) => e.t));
    const spots = bad.filter((e) => e.t === t0).map((e) => e.pos);
    const near = (c: Cell) => spots.some((p) => Math.abs(p.x - c.x) + Math.abs(p.y - c.y) <= 1);
    const involved = cur.routes.map((r, i) => (r.path.some((s) => near(s.cell)) ? i : -1)).filter((i) => i >= 0);
    const moves: State[] = [];
    for (const i of involved) {
      const r = cur.routes[i];
      const upto = r.path.findIndex((s) => near(s.cell));
      for (let j = 1; j < Math.max(upto, 1); j++) {
        const k = ckey(r.path[j].cell);
        if (!cur.stops.has(k)) moves.push({ routes: cur.routes, stops: new Set([...cur.stops, k]) });
      }
      for (const s of r.path) {
        const k = ckey(s.cell);
        if (cur.stops.has(k)) moves.push({ routes: cur.routes, stops: new Set([...cur.stops].filter((x) => x !== k)) });
      }
      // Redraw this route round the trouble, alone or joining the rest.
      const others = new Layout();
      cur.routes.forEach((o, j) => {
        if (j !== i) for (let q = 0; q < o.path.length - 1; q++) others.edges.add(edgeKey(o.path[q].cell, o.path[q].out));
      });
      for (const share of [false, true])
        for (const w of [2, 4, 8]) {
          const pen = new Map<string, number>();
          for (const p of spots) {
            pen.set(ckey(p), w);
            for (const d of DIRS) {
              const n = step(p, d);
              pen.set(ckey(n), Math.max(pen.get(ckey(n)) ?? 0, w / 2));
            }
          }
          for (const st of r.d.stations) {
            const p = route(pz, r.d.depot, st, share ? others : null, pen);
            if (!p) continue;
            const routes = [...cur.routes];
            routes[i] = { d: r.d, path: p };
            moves.push({ routes, stops: cur.stops });
          }
        }
    }
    let best: State | null = null;
    let bestE: ReturnType<typeof evalState> = null;
    for (const m of moves) {
      const e = evalState(m);
      if (e && (!bestE || e.score > bestE.score)) [best, bestE] = [m, e];
    }
    departs++;
    if (!best || !bestE || bestE.score <= curE.score) {
      log.push(`stuck after ${departs - 1} departs`);
      return { solved: false, departs: departs - 1, track: curE.lay.trackCount(pz), lay: curE.lay, log };
    }
    cur = best;
    curE = bestE;
  }
  return { solved: curE.res.success, departs, track: curE.lay.trackCount(pz), lay: curE.lay, log, paths: cur.routes.map((r) => r.path.map((s) => s.cell)) };
}
