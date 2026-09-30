// The Daily Line: one puzzle per calendar day, generated from the day number so every
// player gets the same board without a server.
//
// The generator lays out a working solution first (routes found across the grid, with
// crossings, a sorting switch or a tunnel where the day calls for them), checks it in the
// simulator, adding a stop signal if trains collide, and uses its track count as par.

import { Layout } from "./layout";
import { type Cell, DIRS, type Depot, type Dir, E, N, Puzzle, S, W, ckey, dirBetween, edgeKey, opp, step, tunnel } from "./puzzle";
import { run } from "./sim";

export const DEPARTURES = 6;
const EPOCH_UTC = Date.UTC(2026, 8, 30); // Daily Line No. 1
const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
const WEEKDAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

// Today's puzzle number from the player's local calendar date.
export function today(now = new Date()): number {
  const utc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.max(1, Math.floor((utc - EPOCH_UTC) / 86_400_000) + 1);
}

export function msUntilTomorrow(now = new Date()): number {
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  return next.getTime() - now.getTime();
}

const dateOf = (day: number) => new Date(EPOCH_UTC + (day - 1) * 86_400_000);

export function dateLabel(day: number): string {
  const d = dateOf(day);
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

export const numberLabel = (day: number): string => `No. ${String(day).padStart(4, "0")}`;

interface Profile {
  w: number;
  h: number;
  routes: number;
  sort: boolean;
  trains: number;
  tunnel: boolean;
  goods: boolean;
}

// Early in the week two lines, midweek three. Thursday adds a ridge with a tunnel, Friday
// a goods train, Saturday a sorting switch, and Sunday a sorting switch and a tunnel.
function profile(day: number): Profile {
  const base = { tunnel: false, goods: false };
  switch (dateOf(day).getUTCDay()) {
    case 1:
    case 2:
      return { ...base, w: 6, h: 7, routes: 2, sort: false, trains: 1 };
    case 6:
      return { ...base, w: 7, h: 8, routes: 2, sort: true, trains: 2 };
    case 0:
      return { ...base, w: 7, h: 8, routes: 2, sort: true, trains: 2, tunnel: true };
    case 4:
      return { ...base, w: 7, h: 8, routes: 3, sort: false, trains: 2, tunnel: true };
    case 5:
      return { ...base, w: 7, h: 8, routes: 3, sort: false, trains: 2, goods: true };
    default:
      return { ...base, w: 7, h: 8, routes: 3, sort: false, trains: 2 };
  }
}

// Small, fast, seedable PRNG (mulberry32).
class Rng {
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
}

const cache = new Map<number, Puzzle>();

export function generate(day: number, useCache = true): Puzzle {
  const hit = useCache ? cache.get(day) : undefined;
  if (hit) return hit;
  const rng = new Rng(Math.imul(day, 2654435761) ^ 97531);
  const prof = profile(day);
  for (let attempt = 0; attempt < 400; attempt++) {
    const pz = attemptOnce(rng, prof);
    if (pz) {
      pz.id = `daily-${day}`;
      pz.name = `Daily Line ${numberLabel(day)}`;
      cache.set(day, pz);
      return pz;
    }
  }
  throw new Error(`could not generate daily ${day}`);
}

interface Used {
  dirs: Dir[];
  crossable: boolean;
}
interface Step {
  cell: Cell;
  in: Dir;
  out: Dir;
}
interface Border {
  pos: Cell;
  dir: Dir;
}

function attemptOnce(rng: Rng, prof: Profile): Puzzle | null {
  const pz = new Puzzle();
  pz.w = prof.w;
  pz.h = prof.h;
  pz.allowStop = true;
  pz.allowLamp = true;
  placeObstacles(rng, pz);
  if (prof.tunnel && !placeRidge(rng, pz)) return null;

  const used = new Map<string, Used>();
  const reserved = new Set<string>();
  const paths: Cell[][] = [];
  const lamps: [Cell, number][] = [];
  const levers: [Cell, Dir][] = [];
  let color = 0;
  for (let r = 0; r < prof.routes; r++) {
    const dp = pickBorder(rng, pz, reserved, used);
    if (!dp) return null;
    reserved.add(ckey(dp.pos));
    reserved.add(ckey(step(dp.pos, dp.dir)));
    const st = pickBorder(rng, pz, reserved, used, dp);
    if (!st) return null;
    const path = route(rng, pz, used, reserved, step(dp.pos, dp.dir), opp(dp.dir), step(st.pos, st.dir), opp(st.dir));
    if (!path) return null;
    reserved.add(ckey(st.pos));
    reserved.add(ckey(step(st.pos, st.dir)));
    mark(pz, used, path);
    const trains: number[] = [];
    const count = rng.int(1, prof.trains);
    for (let i = 0; i < count; i++) trains.push(color);
    const depot: Depot = { pos: dp.pos, dir: dp.dir, trains, start: rng.int(0, 2), every: 3, goods: false };
    pz.depots.push(depot);
    pz.stations.push({ pos: st.pos, dir: st.dir, color });
    paths.push([dp.pos, ...path.map((s) => s.cell), st.pos]);

    if (prof.sort && r === 0) {
      const branch = sortBranch(rng, pz, used, reserved, path);
      if (!branch) return null;
      color += 1;
      lamps.push([branch.sw, color]);
      levers.push([branch.sw, branch.side]);
      pz.stations.push({ pos: branch.station.pos, dir: branch.station.dir, color });
      depot.trains = rng.next() < 0.5 ? [color - 1, color, color - 1] : [color, color - 1, color];
      depot.every = 4;
      paths.push([branch.sw, ...branch.path.map((s) => s.cell), branch.station.pos]);
    }
    color += 1;
  }

  if (prof.goods) pz.depots[rng.int(0, pz.depots.length - 1)].goods = true;

  pz.solution = { paths, stops: [], lamps, levers };
  pz.rebuild();
  const lay = pz.solutionLayout();
  if (!run(pz, lay).success) {
    const stop = findStop(rng, pz, lay);
    if (!stop) return null;
    pz.solution.stops = [stop];
    lay.stops.add(ckey(stop));
  }
  pz.par = lay.trackCount(pz);
  return pz;
}

function placeObstacles(rng: Rng, pz: Puzzle): void {
  const clusters = rng.int(3, 5);
  for (let i = 0; i < clusters; i++) {
    const roll = rng.next();
    const kind = roll < 0.5 ? "woods" : roll < 0.85 ? "water" : "town";
    let p: Cell = { x: rng.int(0, pz.w - 1), y: rng.int(0, pz.h - 1) };
    const size = rng.int(1, 3);
    for (let j = 0; j < size; j++) {
      if (pz.inside(p)) pz.blocked.set(ckey(p), kind);
      p = step(p, rng.int(0, 3) as Dir);
    }
  }
}

// A ridge of hills two squares thick with a tunnel straight through it. The ridge runs
// across the tunnel, so going round it costs track.
function placeRidge(rng: Rng, pz: Puzzle): boolean {
  for (let tries = 0; tries < 30; tries++) {
    const across = rng.next() < 0.5; // tunnel runs along x
    const long = across ? pz.w : pz.h; // along the tunnel
    const wide = across ? pz.h : pz.w; // along the ridge
    const at = (u: number, v: number): Cell => (across ? { x: u, y: v } : { x: v, y: u });
    const u0 = rng.int(2, long - 4); // first ridge square along the tunnel
    const r = rng.int(1, wide - 2); // the tunnel's row or column
    const lo = Math.max(0, r - rng.int(1, 3));
    const hi = Math.min(wide - 1, r + rng.int(1, 3));
    if (hi - lo + 1 > wide - 2) continue; // leave a way round
    for (let v = lo; v <= hi; v++) for (const u of [u0, u0 + 1]) pz.blocked.set(ckey(at(u, v)), "hill");
    for (const u of [u0 - 1, u0 + 2]) pz.blocked.delete(ckey(at(u, r)));
    pz.tunnels = [tunnel(pz, at(u0, r), at(u0 + 1, r))];
    pz.rebuild();
    return true;
  }
  return false;
}

// Squares with board track already on them (tunnel stubs) and the side it points to.
function stubs(pz: Puzzle): Map<string, Dir> {
  const out = new Map<string, Dir>();
  for (const tn of pz.tunnels) {
    const d = dirBetween(tn.cells[0], tn.cells[1]) as Dir;
    out.set(ckey(step(tn.a, opp(d))), d);
    out.set(ckey(step(tn.b, d)), opp(d));
  }
  return out;
}

// A depot or platform position on the border (not a corner), facing into the board.
function pickBorder(rng: Rng, pz: Puzzle, reserved: Set<string>, used: Map<string, Used>, other?: Border): Border | null {
  for (let tries = 0; tries < 60; tries++) {
    const side = rng.int(0, 3);
    let pos: Cell;
    let dir: Dir;
    if (side === 0) [pos, dir] = [{ x: rng.int(1, pz.w - 2), y: 0 }, S];
    else if (side === 1) [pos, dir] = [{ x: pz.w - 1, y: rng.int(1, pz.h - 2) }, W];
    else if (side === 2) [pos, dir] = [{ x: rng.int(1, pz.w - 2), y: pz.h - 1 }, N];
    else [pos, dir] = [{ x: 0, y: rng.int(1, pz.h - 2) }, E];
    const port = step(pos, dir);
    const fixed = pz.staticEdges();
    const bad = [pos, port].some(
      (c) => pz.blocked.has(ckey(c)) || reserved.has(ckey(c)) || used.has(ckey(c)) || DIRS.some((d) => fixed.has(edgeKey(c, d))),
    );
    if (bad) continue;
    if (other) {
      const oport = step(other.pos, other.dir);
      if (other.dir === dir || Math.abs(oport.x - port.x) + Math.abs(oport.y - port.y) < 4) continue;
    }
    return { pos, dir };
  }
  return null;
}

// Cheapest route from `start` (entered from side `startIn`) to `goal` (left by side
// `goalOut`). Earlier routes may be crossed only at right angles on their straights.
// Tunnels are taken straight through, and a tunnel stub is only ever joined end on.
function route(
  rng: Rng,
  pz: Puzzle,
  used: Map<string, Used>,
  reserved: Set<string>,
  start: Cell,
  startIn: Dir,
  goal: Cell,
  goalOut: Dir,
): Step[] | null {
  const stub = stubs(pz);
  const fixed = pz.staticEdges();
  const noise = new Map<string, number>();
  for (let y = 0; y < pz.h; y++) for (let x = 0; x < pz.w; x++) noise.set(`${x},${y}`, rng.next() * 0.9);
  const sk = (c: Cell, d: Dir) => `${c.x},${c.y},${d}`;
  const startKey = sk(start, startIn);
  const dist = new Map<string, number>([[startKey, 0]]);
  const prev = new Map<string, string>();
  const open = new Set<string>([startKey]);
  let best = "";
  while (open.size > 0) {
    let cur = "";
    for (const k of open) if (cur === "" || dist.get(k)! < dist.get(cur)!) cur = k;
    open.delete(cur);
    const [cx, cy, cin] = cur.split(",").map(Number);
    const c = { x: cx, y: cy };
    const inSide = cin as Dir;
    if (cx === goal.x && cy === goal.y) {
      if (inSide !== goalOut) {
        best = cur;
        break;
      }
      continue;
    }
    for (const out of [N, E, S, W]) {
      if (out === inSide) continue;
      if (used.has(ckey(c)) && out !== opp(inSide)) continue; // cross earlier lines straight over
      if (pz.inTunnel(c) && out !== opp(inSide)) continue;
      const sd = stub.get(ckey(c));
      if (sd !== undefined && inSide !== sd && out !== sd) continue;
      const nxt = step(c, out);
      const nk = ckey(nxt);
      if (!pz.inside(nxt)) continue;
      if (pz.blocked.has(nk) && !(pz.inTunnel(nxt) && fixed.has(edgeKey(c, out)))) continue;
      if (reserved.has(nk) && !(nxt.x === goal.x && nxt.y === goal.y)) continue;
      let cost = pz.inTunnel(nxt) ? 0.4 : 1 + noise.get(nk)!;
      const u = used.get(nk);
      if (u) {
        if (!u.crossable || u.dirs.includes(out) || u.dirs.includes(opp(out))) continue;
        cost += 1.5;
      }
      if (out !== opp(inSide)) cost += 0.15;
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
    const out = i + 1 < states.length ? opp(Number(states[i + 1].split(",")[2]) as Dir) : goalOut;
    if (inSide === out) return null;
    path.push({ cell: c, in: inSide as Dir, out });
  }
  return path.length >= 3 ? path : null;
}

function mark(pz: Puzzle, used: Map<string, Used>, path: Step[]): void {
  path.forEach((s, i) => {
    const u = used.get(ckey(s.cell));
    if (u) {
      u.dirs.push(s.in, s.out);
      u.crossable = false;
    } else {
      const straight = s.in === opp(s.out);
      const port = i === 0 || i === path.length - 1;
      used.set(ckey(s.cell), { dirs: [s.in, s.out], crossable: straight && !port && !pz.inTunnel(s.cell) });
    }
  });
}

// Turns a curve on route 0 into a switch and routes its new branch to another platform.
function sortBranch(rng: Rng, pz: Puzzle, used: Map<string, Used>, reserved: Set<string>, path: Step[]) {
  const candidates: { sw: Cell; side: Dir; next: Cell }[] = [];
  for (let i = 1; i < path.length - 1; i++) {
    const s = path[i];
    if (s.in === opp(s.out) || used.get(ckey(s.cell))!.dirs.length !== 2) continue;
    const side = opp(s.out);
    const nxt = step(s.cell, side);
    const nk = ckey(nxt);
    if (pz.inside(nxt) && !pz.blocked.has(nk) && !used.has(nk) && !reserved.has(nk)) {
      candidates.push({ sw: s.cell, side, next: nxt });
    }
  }
  if (candidates.length === 0) return null;
  for (let tries = 0; tries < 6; tries++) {
    const cand = candidates[rng.int(0, candidates.length - 1)];
    const st = pickBorder(rng, pz, reserved, used, { pos: cand.sw, dir: cand.side });
    if (!st) continue;
    const bpath = route(rng, pz, used, reserved, cand.next, opp(cand.side), step(st.pos, st.dir), opp(st.dir));
    if (!bpath) continue;
    reserved.add(ckey(st.pos));
    reserved.add(ckey(step(st.pos, st.dir)));
    const u = used.get(ckey(cand.sw))!;
    u.dirs.push(cand.side);
    u.crossable = false;
    mark(pz, used, bpath);
    return { ...cand, station: st, path: bpath };
  }
  return null;
}

// Looks for one stop signal that removes every collision.
function findStop(rng: Rng, pz: Puzzle, lay: Layout): Cell | null {
  const cells: Cell[] = [];
  const seen = new Set<string>();
  for (const path of pz.solution.paths) {
    for (const c of path) {
      if (pz.buildable(c) && lay.dirsAt(pz, c).length === 2 && !seen.has(ckey(c))) {
        seen.add(ckey(c));
        cells.push(c);
      }
    }
  }
  for (let i = cells.length - 1; i > 0; i--) {
    const j = rng.int(0, i);
    [cells[i], cells[j]] = [cells[j], cells[i]];
  }
  for (const c of cells) {
    lay.stops.add(ckey(c));
    const ok = run(pz, lay).success;
    lay.stops.delete(ckey(c));
    if (ok) return c;
  }
  return null;
}
