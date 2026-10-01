// Looks for a way to solve a puzzle with track alone: no stop signals and no colour lamps.
// The Daily Line uses it to show that a day needs at least one signal decision.
//
// A depot that sends trains of two colours always needs a lamp: without one, every train
// takes the same way through every switch. Otherwise each depot's trains run one line from
// its port to their platform. The search tries every pair (or triple) of simple lines that
// fit the track budget, where lines may only meet by crossing at right angles, and runs
// each combination that survives the timing check in the simulator.
//
// What it does not try: lines that share track through switches, and lines that loop over
// themselves. Both cost extra track, so inside a tight budget they rarely matter.

import { Layout } from "./layout";
import { type Cell, type Dir, DIRS, type Puzzle, ckey, edgeKey, opp, step } from "./puzzle";
import { run } from "./sim";

const MAX_PATHS = 6000; // per line; beyond this the search gives up
const CROSS_ALLOWANCE = 2; // crossings each other line may save, used to bound line length

export type SignalFree = { kind: "lamp-needed" } | { kind: "none-found" } | { kind: "found"; layout: Layout } | { kind: "too-big" };

interface Line {
  cells: number[]; // cell indices, port to port
  shape: number[]; // per cell: 0 can't be crossed, 1 straight east-west, 2 straight north-south
  track: number; // buildable cells
  times: number[][]; // per cell: beats at which a train enters it
}

export function signalFree(pz: Puzzle, budget: number): SignalFree {
  if (pz.depots.some((dp) => new Set(dp.trains).size > 1)) return { kind: "lamp-needed" };
  const lines: Line[][] = [];
  const shortest: number[] = [];
  for (const dp of pz.depots) {
    const st = pz.stations.filter((s) => s.color === dp.trains[0]);
    const min = Math.min(...st.map((s) => shortestTrack(pz, dp.pos, dp.dir, s.pos, s.dir)));
    if (!Number.isFinite(min)) return { kind: "none-found" };
    shortest.push(min);
  }
  const total = shortest.reduce((a, b) => a + b, 0);
  for (let i = 0; i < pz.depots.length; i++) {
    const dp = pz.depots[i];
    const limit = budget - (total - shortest[i]) + CROSS_ALLOWANCE * (pz.depots.length - 1);
    const found: Line[] = [];
    for (const st of pz.stations.filter((s) => s.color === dp.trains[0])) {
      if (!enumerate(pz, i, st.pos, st.dir, limit, found)) return { kind: "too-big" };
    }
    if (found.length === 0) return { kind: "none-found" };
    found.sort((a, b) => a.track - b.track);
    lines.push(found);
  }

  const goods = pz.depots.some((dp) => dp.goods);
  const order = lines.map((_, i) => i).sort((a, b) => lines[a].length - lines[b].length);
  const occ = new Int32Array(pz.w * pz.h).fill(-1); // index into `chosen`, or -1
  const chosen: Line[] = [];
  // Least track the lines still to pick can add, if each crosses everything it may.
  const save = CROSS_ALLOWANCE * (order.length - 1);
  const minRest = order.map((_, k) => order.slice(k + 1).reduce((n, i) => n + Math.max(0, shortest[i] - save), 0));

  const pick = (k: number, track: number): Layout | null => {
    if (k === order.length) {
      const lay = layoutOf(pz, chosen);
      return run(pz, lay).success ? lay : null;
    }
    for (const line of lines[order[k]]) {
      // Lines are sorted by track, so once even the best case is over budget, stop.
      if (track + line.track - save + minRest[k] > budget) break;
      let crossings = 0;
      let ok = true;
      for (let c = 0; c < line.cells.length && ok; c++) {
        const at = line.cells[c];
        if (occ[at] < 0) continue;
        const other = chosen[occ[at]];
        const oc = other.cells.indexOf(at);
        if (line.shape[c] === 0 || other.shape[oc] === 0 || line.shape[c] === other.shape[oc]) ok = false;
        // Without goods trains nobody ever stands still, so meeting at a crossing is a crash.
        else if (!goods && line.times[c].some((t) => other.times[oc].includes(t))) ok = false;
        else crossings += 1;
      }
      if (!ok) continue;
      const next = track + line.track - crossings;
      if (next + minRest[k] > budget) continue;
      chosen.push(line);
      for (const at of line.cells) if (occ[at] < 0) occ[at] = chosen.length - 1;
      const hit = pick(k + 1, next);
      chosen.pop();
      for (const at of line.cells) if (occ[at] === chosen.length) occ[at] = -1;
      if (hit) return hit;
    }
    return null;
  };
  const layout = pick(0, 0);
  return layout ? { kind: "found", layout } : { kind: "none-found" };
}

// The sides of a cell that already carry board track (depot and platform stubs, tunnels).
function staticDirs(pz: Puzzle, c: Cell): Dir[] {
  const fixed = pz.staticEdges();
  return DIRS.filter((d) => fixed.has(edgeKey(c, d)));
}

// Can a line step from `c` to its neighbour on side `out`?
function canStep(pz: Puzzle, c: Cell, inSide: Dir, out: Dir): boolean {
  if (out === inSide) return false;
  if (pz.inTunnel(c) && out !== opp(inSide)) return false;
  // Board track on the cell has to be part of the line, or the cell becomes a switch.
  if (staticDirs(pz, c).some((d) => d !== inSide && d !== out)) return false;
  const n = step(c, out);
  if (!pz.inside(n)) return false;
  if (pz.inTunnel(n)) return pz.staticEdges().has(edgeKey(c, out));
  return pz.buildable(n);
}

function shortestTrack(pz: Puzzle, dpPos: Cell, dpDir: Dir, stPos: Cell, stDir: Dir): number {
  const start = step(dpPos, dpDir);
  const goal = step(stPos, stDir);
  const sk = (c: Cell, d: Dir) => `${ckey(c)},${d}`;
  const dist = new Map<string, number>([[sk(start, opp(dpDir)), 1]]);
  const queue: [Cell, Dir][] = [[start, opp(dpDir)]];
  // Breadth first over (cell, side entered); every cell costs one, tunnels nothing, so a
  // 0-1 deque keeps it exact.
  while (queue.length > 0) {
    const [c, inSide] = queue.shift()!;
    const d0 = dist.get(sk(c, inSide))!;
    if (c.x === goal.x && c.y === goal.y && canFinish(pz, c, inSide, stDir)) return d0;
    for (const out of DIRS) {
      if (!canStep(pz, c, inSide, out)) continue;
      const n = step(c, out);
      const cost = pz.inTunnel(n) ? 0 : 1;
      const key = sk(n, opp(out));
      if (dist.has(key) && dist.get(key)! <= d0 + cost) continue;
      dist.set(key, d0 + cost);
      if (cost === 0) queue.unshift([n, opp(out)]);
      else queue.push([n, opp(out)]);
    }
  }
  return Infinity;
}

// A line ends at the platform port, leaving by the side that faces the platform.
function canFinish(pz: Puzzle, c: Cell, inSide: Dir, stDir: Dir): boolean {
  const out = opp(stDir);
  if (out === inSide) return false;
  return staticDirs(pz, c).every((d) => d === inSide || d === out);
}

// Every simple line from depot `di` to the platform at `stPos` with at most `limit` track.
// Returns false if there are too many to search.
function enumerate(pz: Puzzle, di: number, stPos: Cell, stDir: Dir, limit: number, out: Line[]): boolean {
  const dp = pz.depots[di];
  const start = step(dp.pos, dp.dir);
  const goal = step(stPos, stDir);
  const idx = (c: Cell) => c.y * pz.w + c.x;
  const seen = new Uint8Array(pz.w * pz.h);
  const cells: Cell[] = [];
  const sides: [Dir, Dir][] = [];
  let overflow = false;
  const beat = dp.goods ? 2 : 1;
  const departs = dp.trains.map((_, k) => dp.start + k * dp.every);

  const record = () => {
    const shape = cells.map((c, i) => {
      const [a, b] = sides[i];
      if (pz.inTunnel(c) || staticDirs(pz, c).length > 0 || a !== opp(b)) return 0;
      return a === DIRS[1] || a === DIRS[3] ? 1 : 2;
    });
    const times = cells.map((_, i) => departs.map((t) => t + 1 + i * beat));
    const track = cells.filter((c) => !pz.inTunnel(c)).length;
    out.push({ cells: cells.map(idx), shape, track, times });
    if (out.length > MAX_PATHS) overflow = true;
  };

  const walk = (c: Cell, inSide: Dir, track: number) => {
    if (overflow) return;
    const remaining = Math.abs(c.x - goal.x) + Math.abs(c.y - goal.y);
    if (track + remaining > limit + tunnelSlack(pz)) return;
    seen[idx(c)] = 1;
    cells.push(c);
    if (c.x === goal.x && c.y === goal.y) {
      if (canFinish(pz, c, inSide, stDir) && track <= limit) {
        sides.push([inSide, opp(stDir)]);
        record();
        sides.pop();
      }
    } else {
      for (const o of DIRS) {
        if (!canStep(pz, c, inSide, o)) continue;
        const n = step(c, o);
        if (seen[idx(n)]) continue;
        sides.push([inSide, o]);
        walk(n, opp(o), track + (pz.inTunnel(n) ? 0 : 1));
        sides.pop();
      }
    }
    cells.pop();
    seen[idx(c)] = 0;
  };
  walk(start, opp(dp.dir), 1);
  return !overflow;
}

// Tunnel cells are free, so the distance bound has to allow for them.
function tunnelSlack(pz: Puzzle): number {
  return pz.tunnels.reduce((n, tn) => n + tn.cells.length, 0);
}

function layoutOf(pz: Puzzle, lines: Line[]): Layout {
  const lay = new Layout();
  const fixed = pz.staticEdges();
  for (const line of lines) {
    for (let i = 0; i < line.cells.length - 1; i++) {
      const a = { x: line.cells[i] % pz.w, y: Math.floor(line.cells[i] / pz.w) };
      const b = line.cells[i + 1];
      const d = DIRS.find((dd) => {
        const n = step(a, dd);
        return n.y * pz.w + n.x === b && pz.inside(n);
      })!;
      const key = edgeKey(a, d);
      if (!fixed.has(key)) lay.edges.add(key);
    }
  }
  return lay;
}
