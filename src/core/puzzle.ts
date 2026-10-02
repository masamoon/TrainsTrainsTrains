// A puzzle board: size, obstacles, depots, platforms and which tools it allows.
// Track the player draws lives in a separate Layout.

import { Layout } from "./layout";

export type Dir = 0 | 1 | 2 | 3;
export const N: Dir = 0;
export const E: Dir = 1;
export const S: Dir = 2;
export const W: Dir = 3;
export const DIRS: Dir[] = [N, E, S, W];
const DIR_CHARS = "NESW";
const VECS: [number, number][] = [
  [0, -1],
  [1, 0],
  [0, 1],
  [-1, 0],
];

export interface Cell {
  x: number;
  y: number;
}

export type Obstacle = "woods" | "water" | "town" | "hill";

export interface Depot {
  pos: Cell;
  dir: Dir; // side the trains leave by
  trains: number[]; // colours, in departure order
  start: number;
  every: number;
  goods: boolean; // goods trains move every other beat
}

export interface Station {
  pos: Cell;
  dir: Dir; // side facing its track
  color: number;
  opens?: number; // first beat a train may arrive; unset for always open
}

// A tunnel runs straight under blocked ground between two mouths. Its track is part of
// the board: the square outside each mouth gets a stub for the player to join.
export interface Tunnel {
  a: Cell; // mouth cells, both blocked
  b: Cell;
  cells: Cell[]; // every cell from mouth a to mouth b
}

export interface Solution {
  paths: Cell[][];
  stops: Cell[];
  lamps: [Cell, number][];
  levers: [Cell, Dir][];
  stems?: [Cell, Dir][];
}

export const cell = (x: number, y: number): Cell => ({ x, y });
export const ckey = (c: Cell): string => `${c.x},${c.y}`;
export const parseCell = (k: string): Cell => {
  const [x, y] = k.split(",").map(Number);
  return { x, y };
};
export const same = (a: Cell, b: Cell): boolean => a.x === b.x && a.y === b.y;
export const vec = (d: Dir): [number, number] => VECS[d];
export const opp = (d: Dir): Dir => ((d + 2) % 4) as Dir;
export const step = (c: Cell, d: Dir): Cell => ({ x: c.x + VECS[d][0], y: c.y + VECS[d][1] });
const dirChar = (s: string): Dir => DIR_CHARS.indexOf(s) as Dir;

export function dirBetween(a: Cell, b: Cell): Dir | -1 {
  for (const d of DIRS) if (a.x + VECS[d][0] === b.x && a.y + VECS[d][1] === b.y) return d;
  return -1;
}

// Every edge between two neighbouring cells gets one key: the east (0) or south (1)
// edge of the upper-left cell.
export function edgeKey(p: Cell, d: Dir): string {
  switch (d) {
    case N:
      return `${p.x},${p.y - 1},1`;
    case E:
      return `${p.x},${p.y},0`;
    case S:
      return `${p.x},${p.y},1`;
    default:
      return `${p.x - 1},${p.y},0`;
  }
}

export function edgeCells(key: string): [Cell, Cell] {
  const [x, y, z] = key.split(",").map(Number);
  return [cell(x, y), z === 0 ? cell(x + 1, y) : cell(x, y + 1)];
}

export interface LevelData {
  id?: string;
  name?: string;
  rows: string[];
  depots: { at: [number, number]; dir: string; trains: number[]; start?: number; every?: number; goods?: boolean }[];
  // `opens`: a timed platform that turns away trains arriving before that beat.
  stations: { at: [number, number]; dir: string; color: number; opens?: number }[];
  // Track already laid when the level opens: it can be built onto but not erased.
  fixed?: [number, number][][];
  // Tunnel mouths, in pairs on the same row or column.
  tunnels?: [[number, number], [number, number]][];
  allowStop?: boolean;
  allowLamp?: boolean;
  // "block": signals guard the track ahead instead of holding for two beats (lab only for now).
  signals?: "stop" | "block";
  // Every train must be home by this beat (lab only for now).
  deadline?: number;
  introTitle?: string;
  introText?: string;
  par?: number;
  solution?: {
    paths: [number, number][][];
    stops?: [number, number][];
    lamps?: [number, number, number][];
    levers?: [number, number, string][];
    // Switches whose stem isn't the odd side out (a line running straight through).
    stems?: [number, number, string][];
  };
}

export class Puzzle {
  id = "";
  name = "";
  w = 7;
  h = 7;
  blocked = new Map<string, Obstacle>();
  depots: Depot[] = [];
  stations: Station[] = [];
  fixed: Cell[][] = [];
  tunnels: Tunnel[] = [];
  par = 0;
  allowStop = false;
  allowLamp = false;
  blockSignals = false;
  deadline = 0;
  introTitle = "";
  introText = "";
  solution: Solution = { paths: [], stops: [], lamps: [], levers: [] };
  private staticEdgeSet = new Set<string>();
  private fixedEdgeSet = new Set<string>();
  private tunnelCellSet = new Set<string>();

  // Call after changing depots, stations, fixed track or tunnels.
  rebuild(): void {
    this.staticEdgeSet.clear();
    this.fixedEdgeSet.clear();
    this.tunnelCellSet.clear();
    for (const dp of this.depots) this.staticEdgeSet.add(edgeKey(dp.pos, dp.dir));
    for (const st of this.stations) this.staticEdgeSet.add(edgeKey(st.pos, st.dir));
    for (const path of this.fixed) {
      for (let i = 0; i < path.length - 1; i++) {
        const d = dirBetween(path[i], path[i + 1]);
        if (d === -1) throw new Error(`fixed track is not continuous at ${ckey(path[i])}`);
        this.staticEdgeSet.add(edgeKey(path[i], d));
        this.fixedEdgeSet.add(edgeKey(path[i], d));
      }
    }
    for (const tn of this.tunnels) {
      const d = dirBetween(tn.cells[0], tn.cells[1]) as Dir;
      const run = [step(tn.a, opp(d)), ...tn.cells, step(tn.b, d)];
      for (let i = 0; i < run.length - 1; i++) this.staticEdgeSet.add(edgeKey(run[i], d));
      for (const c of tn.cells) this.tunnelCellSet.add(ckey(c));
    }
  }

  staticEdges(): Set<string> {
    return this.staticEdgeSet;
  }

  // Edges of track that came with the level (not depot or platform stubs).
  fixedEdges(): Set<string> {
    return this.fixedEdgeSet;
  }

  inTunnel(p: Cell): boolean {
    return this.tunnelCellSet.has(ckey(p));
  }

  // True where a train cannot go: off the board, or blocked ground with no tunnel.
  solid(p: Cell): boolean {
    return !this.inside(p) || (this.blocked.has(ckey(p)) && !this.tunnelCellSet.has(ckey(p)));
  }

  inside(p: Cell): boolean {
    return p.x >= 0 && p.y >= 0 && p.x < this.w && p.y < this.h;
  }

  depotIndexAt(p: Cell): number {
    return this.depots.findIndex((d) => same(d.pos, p));
  }

  stationIndexAt(p: Cell): number {
    return this.stations.findIndex((s) => same(s.pos, p));
  }

  // True for cells that can carry player-drawn track.
  buildable(p: Cell): boolean {
    return this.inside(p) && !this.blocked.has(ckey(p)) && this.depotIndexAt(p) < 0 && this.stationIndexAt(p) < 0;
  }

  colorsUsed(): number[] {
    return [...new Set(this.stations.map((s) => s.color))].sort((a, b) => a - b);
  }

  trainCount(): number {
    return this.depots.reduce((n, d) => n + d.trains.length, 0);
  }

  starsFor(track: number): number {
    if (track <= this.par) return 3;
    if (track <= this.par + Math.max(2, Math.ceil(this.par * 0.25))) return 2;
    return 1;
  }

  solutionLayout(): Layout {
    const lay = new Layout();
    for (const path of this.solution.paths) {
      for (let i = 0; i < path.length - 1; i++) {
        const d = dirBetween(path[i], path[i + 1]);
        if (d === -1) throw new Error(`solution path is not continuous at ${ckey(path[i])}`);
        const key = edgeKey(path[i], d);
        if (!this.staticEdgeSet.has(key)) lay.edges.add(key);
      }
    }
    for (const p of this.solution.stops) lay.stops.add(ckey(p));
    for (const [p, c] of this.solution.lamps) lay.lamps.set(ckey(p), c);
    for (const [p, d] of this.solution.stems ?? []) lay.stems.set(ckey(p), d);
    for (const [p, d] of this.solution.levers) lay.levers.set(ckey(p), d);
    return lay;
  }

  // Builds a puzzle from compact level data. `rows` uses "." for open ground, "T" woods,
  // "~" water, "H" town and "^" hills.
  static fromData(data: LevelData): Puzzle {
    const pz = new Puzzle();
    pz.id = data.id ?? "";
    pz.name = data.name ?? "";
    pz.h = data.rows.length;
    pz.w = data.rows[0].length;
    const kinds: Record<string, Obstacle> = { T: "woods", "~": "water", H: "town", "^": "hill" };
    data.rows.forEach((row, y) => {
      [...row].forEach((ch, x) => {
        if (kinds[ch]) pz.blocked.set(`${x},${y}`, kinds[ch]);
      });
    });
    pz.depots = data.depots.map((d) => ({
      pos: cell(d.at[0], d.at[1]),
      dir: dirChar(d.dir),
      trains: [...d.trains],
      start: d.start ?? 0,
      every: d.every ?? 3,
      goods: d.goods ?? false,
    }));
    pz.stations = data.stations.map((s) => ({ pos: cell(s.at[0], s.at[1]), dir: dirChar(s.dir), color: s.color, opens: s.opens }));
    pz.fixed = (data.fixed ?? []).map((p) => p.map(([x, y]) => cell(x, y)));
    pz.tunnels = (data.tunnels ?? []).map(([[ax, ay], [bx, by]]) => tunnel(pz, cell(ax, ay), cell(bx, by)));
    pz.allowStop = data.allowStop ?? false;
    pz.allowLamp = data.allowLamp ?? false;
    pz.blockSignals = data.signals === "block";
    pz.deadline = data.deadline ?? 0;
    pz.introTitle = data.introTitle ?? "";
    pz.introText = data.introText ?? "";
    const sol = data.solution;
    if (sol) {
      pz.solution = {
        paths: sol.paths.map((p) => p.map(([x, y]) => cell(x, y))),
        stops: (sol.stops ?? []).map(([x, y]) => cell(x, y)),
        lamps: (sol.lamps ?? []).map(([x, y, c]) => [cell(x, y), c]),
        levers: (sol.levers ?? []).map(([x, y, d]) => [cell(x, y), dirChar(d)]),
        stems: (sol.stems ?? []).map(([x, y, d]) => [cell(x, y), dirChar(d)]),
      };
    }
    pz.rebuild();
    pz.par = data.par ?? 0;
    if (pz.par <= 0) pz.par = pz.solutionLayout().trackCount(pz);
    return pz;
  }
}

// The cells of a tunnel between two mouths, checked: straight, all blocked, with open
// ground outside both mouths.
export function tunnel(pz: Puzzle, a: Cell, b: Cell): Tunnel {
  if (a.x !== b.x && a.y !== b.y) throw new Error(`tunnel ${ckey(a)} to ${ckey(b)} is not straight`);
  const d = dirBetween(a, { x: a.x + Math.sign(b.x - a.x), y: a.y + Math.sign(b.y - a.y) }) as Dir;
  const cells: Cell[] = [a];
  while (!same(cells[cells.length - 1], b)) cells.push(step(cells[cells.length - 1], d));
  if (cells.length < 2 || cells.some((c) => !pz.blocked.has(ckey(c)))) throw new Error(`tunnel ${ckey(a)} must run under blocked ground`);
  for (const out of [step(a, opp(d)), step(b, d)]) {
    if (!pz.inside(out) || pz.blocked.has(ckey(out))) throw new Error(`tunnel mouth at ${ckey(out)} opens onto blocked ground`);
  }
  return { a, b, cells };
}
