// Brainless recipes: rules a player could follow without thinking about the board. A
// block-signal board that any recipe solves is rejected (tools/lab/build.ts).
//
// Track: the board's reference track, and the obvious tracks a person draws first (every
// line on its own shortest route; joining lines already drawn; keeping lines apart, which
// gives each direction its own track wherever there is room).
// Signals: just outside every depot, before every junction, at both ends of every stretch, on every other square,
// on every square, or none at all.
import { Layout } from "../../src/core/layout";
import { type Cell, type Dir, type Puzzle, ckey, edgeKey, step } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { type Step, build, route } from "./player";

type Recipe = (pz: Puzzle, lay: Layout, cells: Cell[]) => Cell[];

const plain = (pz: Puzzle, lay: Layout, c: Cell) => pz.buildable(c) && lay.dirsAt(pz, c).length === 2;
const besideJunction = (pz: Puzzle, lay: Layout, c: Cell, depots: boolean) =>
  lay.dirsAt(pz, c).some((d) => {
    const n = step(c, d);
    return pz.inside(n) && (lay.dirsAt(pz, n).length >= 3 || (depots && pz.depotIndexAt(n) >= 0));
  });

export const RECIPES: Record<string, Recipe> = {
  "no signals": () => [],
  // Hold each line at its depot until the way is clear.
  "a signal just outside every depot": (pz, lay, cells) => cells.filter((c) => plain(pz, lay, c) && pz.depots.some((d) => ckey(step(d.pos, d.dir)) === ckey(c))),
  "a signal before every junction": (pz, lay, cells) => cells.filter((c) => plain(pz, lay, c) && besideJunction(pz, lay, c, false)),
  "signals at both ends of every stretch": (pz, lay, cells) => cells.filter((c) => plain(pz, lay, c) && besideJunction(pz, lay, c, true)),
  "a signal on every other square": (pz, lay, cells) => cells.filter((c, i) => plain(pz, lay, c) && i % 2 === 0),
  "a signal on every square": (pz, lay, cells) => cells.filter((c) => plain(pz, lay, c)),
};

// The obvious tracks: each habit draws every line in turn.
function obviousTracks(pz: Puzzle): { name: string; routes: { d: { depot: number; color: number; stations: number[] }; path: Step[] }[] }[] {
  const streams: { depot: number; color: number; stations: number[] }[] = [];
  pz.depots.forEach((dp, depot) => {
    for (const color of new Set(dp.trains)) streams.push({ depot, color, stations: pz.stations.map((s, i) => (s.color === color ? i : -1)).filter((i) => i >= 0) });
  });
  const out: ReturnType<typeof obviousTracks> = [];
  for (const habit of ["shortest", "joined", "apart"] as const) {
    const drawn = new Layout();
    const pen = new Map<string, number>();
    const routes: ReturnType<typeof obviousTracks>[number]["routes"] = [];
    for (const d of streams) {
      let best: Step[] | null = null;
      for (const st of d.stations) {
        const p = route(pz, d.depot, st, habit === "joined" ? drawn : null, habit === "apart" ? pen : new Map());
        if (p && (!best || p.length < best.length)) best = p;
      }
      if (!best) break;
      routes.push({ d, path: best });
      for (let i = 0; i < best.length - 1; i++) drawn.edges.add(edgeKey(best[i].cell, best[i].out));
      for (const s of best) pen.set(ckey(s.cell), 6);
    }
    if (routes.length === streams.length) out.push({ name: `${habit} routes`, routes });
  }
  return out;
}

// The ways trains leave each square along some routes.
function travel(paths: Step[][]): Map<string, Set<Dir>> {
  const out = new Map<string, Set<Dir>>();
  for (const p of paths)
    for (const s of p) {
      const k = ckey(s.cell);
      if (!out.has(k)) out.set(k, new Set());
      out.get(k)!.add(s.out);
    }
  return out;
}

// The first recipe (track + signals) that solves the board, or "" if none does. On
// block-signal boards each recipe is tried with signals both ways, and one way facing the
// way trains run (where both directions run: both ways, or no signal).
export function brainless(pz: Puzzle, reference: Layout, referencePaths: Step[][] = []): string {
  const tracks: { name: string; lay: Layout; runs: Map<string, Set<Dir>> }[] = [{ name: "reference track", lay: reference, runs: travel(referencePaths) }];
  for (const t of obviousTracks(pz)) {
    const lay = build(pz, t.routes, new Set());
    if (lay) tracks.push({ name: t.name, lay, runs: travel(t.routes.map((r) => r.path)) });
  }
  const facings = pz.blockSignals ? (["both ways", "one way, both ways where shared", "one way, none where shared"] as const) : (["both ways"] as const);
  for (const t of tracks) {
    const base = t.lay.clone();
    base.stops.clear();
    base.facing.clear();
    const cells: Cell[] = [];
    for (let y = 0; y < pz.h; y++) for (let x = 0; x < pz.w; x++) if (base.dirsAt(pz, { x, y }).length) cells.push({ x, y });
    for (const [name, recipe] of Object.entries(RECIPES)) {
      for (const facing of facings) {
        if (facing !== "both ways" && !t.runs.size) continue;
        const lay = base.clone();
        for (const c of recipe(pz, lay, cells)) {
          const k = ckey(c);
          const ways = [...(t.runs.get(k) ?? [])];
          if (facing === "one way, none where shared" && ways.length !== 1) continue;
          lay.stops.add(k);
          if (facing !== "both ways" && ways.length === 1) lay.facing.set(k, ways[0]);
        }
        if (run(pz, lay).success) return `${name} (${facing}) on the ${t.name}`;
      }
    }
  }
  return "";
}
