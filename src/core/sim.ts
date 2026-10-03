// Runs a puzzle in beats. Every beat each moving train advances one cell.
//
// - Goods trains move every other beat.
// - A train that meets a train standing still (held at a signal, or queued) waits behind it.
// - Two trains entering the same cell, or passing through each other, crash.
// - A train that runs off its track derails; one that reaches a platform of another
//   colour counts as the wrong platform, and so does one that reaches a timed platform
//   before it opens, or after the level's deadline (levels that have one).
// - Block signals (levels that use them): a train on a signal waits there until the block
//   ahead is empty. The block is all the track it could reach from the signal, through
//   switches and crossings, before the next signals. If two trains want one block on the
//   same beat, the one that left its depot first goes.
//
// The result holds one frame per beat for playback plus a per-train outcome.

import type { Layout } from "./layout";
import { type Cell, type Dir, type Puzzle, ckey, opp, parseCell, same, step } from "./puzzle";

const HOLD_BEATS = 2;

export type Outcome = "arrived" | "wrong" | "crashed";
export type EventKind = "arrived" | "wrong" | "early" | "late" | "crash" | "derail" | "lost";

export interface TrainFrame {
  id: number;
  color: number;
  pos: Cell;
  in: Dir; // side it entered its cell from
  out: Dir; // side it will leave by
  state: "moving" | Outcome;
  hold: number;
  goods: boolean;
}

export interface SimEvent {
  t: number;
  kind: EventKind;
  pos: Cell;
  color: number;
}

export interface RunResult {
  frames: TrainFrame[][];
  events: SimEvent[];
  outcomes: { color: number; result: Outcome }[];
  success: boolean;
  beats: number;
}

interface Train {
  id: number;
  color: number;
  depot: number;
  depart: number;
  state: "pending" | "active" | "done_now" | "done";
  pos: Cell;
  in: Dir;
  out: Dir;
  hold: number;
  rest: number; // beats a goods train still waits before its next move
  goods: boolean;
  end: Outcome | "";
  waiting?: boolean;
}

interface Plan {
  tr: Train;
  stay: boolean;
  to: Cell;
  in: Dir;
  out: Dir;
  end: Outcome | "derailed" | "early" | "late" | "";
  waiting?: boolean; // held at a block signal
}

export function run(pz: Puzzle, lay: Layout): RunResult {
  const trains: Train[] = [];
  pz.depots.forEach((dp, di) => {
    dp.trains.forEach((color, i) => {
      trains.push({
        id: 0,
        color,
        depot: di,
        depart: dp.start + i * dp.every,
        state: "pending",
        pos: dp.pos,
        in: opp(dp.dir),
        out: dp.dir,
        hold: 0,
        rest: 0,
        goods: dp.goods,
        end: "",
      });
    });
  });
  trains.sort((a, b) => a.depart - b.depart || a.depot - b.depot);
  trains.forEach((tr, i) => (tr.id = i));

  const frames: TrainFrame[][] = [];
  const events: SimEvent[] = [];
  const seen = new Set<string>();
  const lastDepart = Math.max(0, ...trains.map((t) => t.depart));
  const maxBeats = lastDepart + pz.w * pz.h * 3 + 20;
  let t = 0;
  spawn(trains, t);
  frames.push(frame(trains));
  while (t < maxBeats) {
    if (!trains.some((tr) => tr.state === "active" || tr.state === "pending")) break;
    stepBeat(pz, lay, trains, t, events);
    t += 1;
    spawn(trains, t);
    frames.push(frame(trains));
    for (const tr of trains) if (tr.state === "done_now") tr.state = "done";
    if (!trains.some((tr) => tr.state === "pending")) {
      // Same positions, headings and holds as an earlier beat: a loop or a deadlock.
      const sig = trains
        .filter((tr) => tr.state === "active")
        .map((tr) => `${tr.id}:${ckey(tr.pos)},${tr.out},${tr.hold},${tr.rest}`)
        .join(";");
      if (seen.has(sig)) break;
      seen.add(sig);
    }
  }
  for (const tr of trains) {
    if (tr.state === "active" || tr.state === "pending") {
      tr.end = "crashed";
      events.push({ t, kind: "lost", pos: tr.pos, color: tr.color });
      tr.state = "done";
    }
  }
  const outcomes = trains.map((tr) => ({ color: tr.color, result: tr.end as Outcome }));
  return { frames, events, outcomes, success: outcomes.every((o) => o.result === "arrived"), beats: t };
}

function spawn(trains: Train[], t: number): void {
  for (const tr of trains) {
    if (tr.state !== "pending" || tr.depart > t) continue;
    const occupied = trains.some((o) => o.state === "active" && same(o.pos, tr.pos));
    if (occupied) {
      tr.depart = t + 1;
      continue;
    }
    tr.state = "active";
    tr.depart = t;
  }
}

function frame(trains: Train[]): TrainFrame[] {
  return trains
    .filter((tr) => tr.state === "active" || tr.state === "done_now")
    .map((tr) => ({
      id: tr.id,
      color: tr.color,
      pos: tr.pos,
      in: tr.in,
      out: tr.out,
      state: tr.state === "done_now" ? (tr.end as Outcome) : "moving",
      hold: tr.waiting ? 1 : tr.hold,
      goods: tr.goods,
    }));
}

function stepBeat(pz: Puzzle, lay: Layout, trains: Train[], t: number, events: SimEvent[]): void {
  const plans: Plan[] = [];
  for (const tr of trains) {
    if (tr.state !== "active") continue;
    const plan: Plan = { tr, stay: false, to: tr.pos, in: tr.in, out: tr.out, end: "" };
    if (tr.hold > 0 || tr.rest > 0) {
      plan.stay = true;
    } else {
      const n = step(tr.pos, tr.out);
      const entry = opp(tr.out);
      plan.to = n;
      plan.in = entry;
      const si = pz.inside(n) ? pz.stationIndexAt(n) : -1;
      if (si >= 0) {
        const st = pz.stations[si];
        if (st.dir !== entry) plan.end = "derailed";
        else if (st.color !== tr.color) plan.end = "wrong";
        else if (t + 1 < (st.opens ?? 0)) plan.end = "early";
        else plan.end = pz.deadline && t + 1 > pz.deadline ? "late" : "arrived";
      } else if (pz.solid(n) || pz.depotIndexAt(n) >= 0) {
        plan.end = "derailed";
      } else {
        const exit = lay.exitFor(pz, n, entry, tr.color);
        if (exit === -1) plan.end = "derailed";
        else plan.out = exit;
      }
    }
    plans.push(plan);
  }

  if (pz.blockSignals) {
    // Leaving a signal into an occupied (or just claimed) block: wait at the signal.
    const claimed = new Set<string>();
    for (const p of plans) {
      const here = ckey(p.tr.pos);
      if (p.stay || p.end !== "" || !lay.governs(here, p.tr.out)) continue;
      const block = blockAhead(pz, lay, p.tr.pos, p.tr.out);
      const busy = plans.some((o) => o !== p && block.has(ckey(o.tr.pos))) || [...block].some((k) => claimed.has(k));
      if (busy) {
        p.stay = true;
        p.to = p.tr.pos;
        p.in = p.tr.in;
        p.out = p.tr.out;
        p.waiting = true;
      } else for (const k of block) claimed.add(k);
    }
  }

  // Trains queue behind anything standing still in the cell ahead.
  let changed = true;
  while (changed) {
    changed = false;
    const standing = new Set(plans.filter((p) => p.stay).map((p) => ckey(p.tr.pos)));
    for (const p of plans) {
      if (!p.stay && p.end !== "derailed" && standing.has(ckey(p.to))) {
        p.stay = true;
        p.to = p.tr.pos;
        p.in = p.tr.in;
        p.out = p.tr.out;
        p.end = "";
        changed = true;
      }
    }
  }

  // Collisions: shared destination cells, and trains passing through each other.
  const crashed = new Set<number>();
  const byCell = new Map<string, number[]>();
  plans.forEach((p, i) => {
    if (p.end === "derailed") return;
    const k = ckey(p.to);
    byCell.set(k, [...(byCell.get(k) ?? []), i]);
  });
  for (const list of byCell.values()) if (list.length > 1) list.forEach((i) => crashed.add(i));
  for (let i = 0; i < plans.length; i++) {
    for (let j = i + 1; j < plans.length; j++) {
      const a = plans[i];
      const b = plans[j];
      if (a.stay || b.stay || a.end === "derailed" || b.end === "derailed") continue;
      if (same(a.to, b.tr.pos) && same(b.to, a.tr.pos)) {
        crashed.add(i);
        crashed.add(j);
      }
    }
  }

  plans.forEach((p, i) => {
    const tr = p.tr;
    tr.waiting = false;
    tr.pos = p.to;
    tr.in = p.in;
    tr.out = p.out;
    if (p.waiting) {
      tr.hold = 0;
      tr.waiting = true;
    } else if (p.stay) {
      if (tr.hold > 0) tr.hold -= 1;
      else if (tr.rest > 0) tr.rest -= 1;
    } else if (crashed.has(i)) {
      finish(tr, "crashed", "crash", t + 1, events);
    } else if (p.end === "derailed") {
      finish(tr, "crashed", "derail", t + 1, events);
    } else if (p.end === "early" || p.end === "late") {
      finish(tr, "wrong", p.end, t + 1, events);
    } else if (p.end !== "") {
      finish(tr, p.end, p.end === "crashed" ? "crash" : p.end, t + 1, events);
    } else {
      if (tr.goods) tr.rest = 1;
      if (lay.stops.has(ckey(tr.pos)) && !pz.blockSignals) tr.hold = HOLD_BEATS;
    }
  });
}

function finish(tr: Train, outcome: Outcome, kind: EventKind, t: number, events: SimEvent[]): void {
  tr.state = "done_now";
  tr.end = outcome;
  tr.hold = 0;
  events.push({ t, kind, pos: tr.pos, color: tr.color });
}

// The side trains enter a one-way signal's square by (-1 for a both-ways signal or none).
// As in a signal box, a one-way signal's square belongs to the block behind it: a train
// waiting at the signal still occupies that block.
function rearOf(pz: Puzzle, lay: Layout, k: string): Dir | -1 {
  const f = lay.facing.get(k);
  if (f === undefined || !lay.stops.has(k)) return -1;
  return lay.dirsAt(pz, parseCell(k)).find((d) => d !== f) ?? -1;
}

// The block a block signal at `p` guards for a train leaving by side `out`: every cell of
// track reachable from there without passing another signal, plus the squares of one-way
// signals reached from behind. Depots and platforms are not part of any block.
export function blockAhead(pz: Puzzle, lay: Layout, p: Cell, out: Dir): Set<string> {
  const block = new Set<string>();
  const origin = ckey(p);
  const todo: [Cell, Dir][] = [[step(p, out), opp(out)]];
  while (todo.length) {
    const [c, entry] = todo.pop()!;
    const k = ckey(c);
    if (!pz.inside(c) || block.has(k) || k === origin) continue;
    if (pz.depotIndexAt(c) >= 0 || pz.stationIndexAt(c) >= 0) continue;
    if (lay.stops.has(k)) {
      if (rearOf(pz, lay, k) === entry) block.add(k);
      continue;
    }
    block.add(k);
    for (const d of lay.dirsAt(pz, c)) todo.push([step(c, d), opp(d)]);
  }
  return block;
}

// Every block on the board: the track split at block signals. A one-way signal's square
// joins the block behind it; both-ways signal squares, depots and platforms belong to none.
export function blocks(pz: Puzzle, lay: Layout): string[][] {
  const seen = new Set<string>();
  const out: string[][] = [];
  const index = new Map<string, number>();
  for (let y = 0; y < pz.h; y++)
    for (let x = 0; x < pz.w; x++) {
      const k = ckey({ x, y });
      if (seen.has(k) || lay.stops.has(k) || !pz.buildable({ x, y }) && !pz.inTunnel({ x, y })) continue;
      if (lay.dirsAt(pz, { x, y }).length === 0) continue;
      const block: string[] = [];
      const todo: Cell[] = [{ x, y }];
      while (todo.length) {
        const c = todo.pop()!;
        const ck = ckey(c);
        if (seen.has(ck) || lay.stops.has(ck) || !pz.inside(c) || pz.depotIndexAt(c) >= 0 || pz.stationIndexAt(c) >= 0) continue;
        seen.add(ck);
        block.push(ck);
        index.set(ck, out.length);
        for (const d of lay.dirsAt(pz, c)) todo.push(step(c, d));
      }
      if (block.length) out.push(block);
    }
  // One-way signals join the block behind them, or stand alone (say, just outside a depot).
  for (const k of lay.stops) {
    const r = rearOf(pz, lay, k);
    if (r < 0) continue;
    const i = index.get(ckey(step(parseCell(k), r as Dir)));
    if (i !== undefined) out[i].push(k);
    else out.push([k]);
  }
  return out;
}
