// Runs a puzzle in beats. Every beat each moving train advances one cell.
//
// - Goods trains move every other beat.
// - A train that meets a train standing still (held at a signal, or queued) waits behind it.
// - Two trains entering the same cell, or passing through each other, crash.
// - A train that runs off its track derails; one that reaches a platform of another
//   colour counts as the wrong platform.
//
// The result holds one frame per beat for playback plus a per-train outcome.

import type { Layout } from "./layout";
import { type Cell, type Dir, type Puzzle, ckey, opp, same, step } from "./puzzle";

const HOLD_BEATS = 2;

export type Outcome = "arrived" | "wrong" | "crashed";
export type EventKind = "arrived" | "wrong" | "crash" | "derail" | "lost";

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
}

interface Plan {
  tr: Train;
  stay: boolean;
  to: Cell;
  in: Dir;
  out: Dir;
  end: Outcome | "derailed" | "";
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
      hold: tr.hold,
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
        else plan.end = st.color === tr.color ? "arrived" : "wrong";
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
    tr.pos = p.to;
    tr.in = p.in;
    tr.out = p.out;
    if (p.stay) {
      if (tr.hold > 0) tr.hold -= 1;
      else if (tr.rest > 0) tr.rest -= 1;
    } else if (crashed.has(i)) {
      finish(tr, "crashed", "crash", t + 1, events);
    } else if (p.end === "derailed") {
      finish(tr, "crashed", "derail", t + 1, events);
    } else if (p.end !== "") {
      finish(tr, p.end, p.end === "crashed" ? "crash" : p.end, t + 1, events);
    } else {
      if (tr.goods) tr.rest = 1;
      if (lay.stops.has(ckey(tr.pos))) tr.hold = HOLD_BEATS;
    }
  });
}

function finish(tr: Train, outcome: Outcome, kind: EventKind, t: number, events: SimEvent[]): void {
  tr.state = "done_now";
  tr.end = outcome;
  tr.hold = 0;
  events.push({ t, kind, pos: tr.pos, color: tr.color });
}
