// Builds the difficulty prototypes into src/core/lab.ts and reports how the player model
// fares on each: tools/campaign/run.sh ../lab/build
import { writeFileSync } from "node:fs";
import type { Layout } from "../../src/core/layout";
import { type LevelData, Puzzle, ckey, parseCell } from "../../src/core/puzzle";
import { run } from "../../src/core/sim";
import { ascii } from "../campaign/solver";
import { play } from "./player";
import { reference, stopSets } from "./proto";

type P = [number, number];
type Proto = { data: LevelData & { id: string; name: string }; paths: P[][]; stops?: P[]; why: string; pathsFrom?: string };

const SINGLE = ["TTTTTTTTT", "D.T...T.S", "T.......T", "S.TTTTT.D", "TTTTTTTTT"];
const singleEnds = (a: Partial<LevelData["depots"][number]>, b: Partial<LevelData["depots"][number]>): Pick<LevelData, "depots" | "stations"> => ({
  depots: [
    { at: [0, 1], dir: "E", trains: [0, 0], ...a },
    { at: [8, 3], dir: "W", trains: [1, 1], ...b },
  ],
  stations: [
    { at: [8, 1], dir: "W", color: 0 },
    { at: [0, 3], dir: "E", color: 1 },
  ],
});
const EAST_BAY: P[] = [[0, 1], [1, 1], [1, 2], [2, 2], [3, 2], [3, 1], [4, 1], [5, 1], [5, 2], [6, 2], [7, 2], [7, 1], [8, 1]];
const WEST_MAIN: P[] = [[8, 3], [7, 3], [7, 2], [6, 2], [5, 2], [4, 2], [3, 2], [2, 2], [1, 2], [1, 3], [0, 3]];

const BAYS = ["TTTTTTTTTTTTT", "D.T..TTT..T.S", "T...........T", "S.TTTTTTTTT.D", "TTTTTTTTTTTTT"];
function bayPath(east: boolean, bay1: boolean, bay2: boolean): P[] {
  const xs = [...Array(11).keys()].map((i) => i + 1);
  const mid: P[] = [];
  for (const x of east ? xs : [...xs].reverse()) {
    const up = (bay1 && (x === 3 || x === 4)) || (bay2 && (x === 8 || x === 9));
    const first = east ? x === 3 || x === 8 : x === 4 || x === 9;
    if (up && first) mid.push([x, 2], [x, 1]);
    else if (up) mid.push([x, 1], [x, 2]);
    else mid.push([x, 2]);
  }
  return east ? [[0, 1], [1, 1], ...mid, [11, 1], [12, 1]] : [[12, 3], [11, 3], ...mid, [1, 3], [0, 3]];
}

const BRIDGE = [".........", ".........", ".........", "~~~~.~~~~", "~~~~.~~~~", ".........", ".........", "........."];

const PROTOS: Proto[] = [
  {
    data: {
      id: "lab-1",
      name: "Waiting Room",
      rows: SINGLE,
      ...singleEnds({ start: 0, every: 3 }, { start: 3, every: 3 }),
      allowStop: true,
      introTitle: "Prototype: single line",
      introText: "One line, trains both ways. They can only pass where you make room.",
    },
    paths: [EAST_BAY, WEST_MAIN],
    stops: [[3, 1], [4, 1]],
    why: "Passing loop as a waiting room: both rose trains hold in the loop while both teal trains pass.",
  },
  {
    data: {
      id: "lab-2",
      name: "Passing Time",
      rows: SINGLE,
      ...singleEnds({ start: 0, every: 4 }, { start: 2, every: 4 }),
      allowStop: true,
      introTitle: "Prototype: single line, new timetable",
      introText: "The same line with a different timetable.",
    },
    paths: [EAST_BAY, WEST_MAIN],
    stops: [[3, 1], [4, 1], [4, 2]],
    why: "Same board, new timetable: now both directions have to be held, one of them inside the loop.",
  },
  {
    data: {
      id: "lab-3",
      name: "Two Bays",
      rows: BAYS,
      depots: [
        { at: [0, 1], dir: "E", trains: [0, 0], start: 0, every: 3 },
        { at: [12, 3], dir: "W", trains: [1, 1], start: 2, every: 3 },
      ],
      stations: [
        { at: [12, 1], dir: "W", color: 0 },
        { at: [0, 3], dir: "E", color: 1 },
      ],
      allowStop: true,
      introTitle: "Prototype: where to pass",
      introText: "A long single line with room to pass in two places. Pick the right one.",
    },
    paths: [bayPath(true, false, false), bayPath(false, false, true)],
    why: "Two possible passing places; only a few loop-and-signal combinations work.",
  },
  {
    data: {
      id: "lab-4",
      name: "One Bridge",
      rows: BRIDGE,
      depots: [
        { at: [0, 1], dir: "E", trains: [0, 0], start: 0, every: 5 },
        { at: [8, 6], dir: "W", trains: [1, 1], start: 3, every: 3 },
        { at: [8, 1], dir: "W", trains: [2, 2], start: 2, every: 5 },
      ],
      stations: [
        { at: [0, 6], dir: "E", color: 0 },
        { at: [4, 0], dir: "S", color: 1 },
        { at: [4, 7], dir: "N", color: 2 },
      ],
      allowStop: true,
      allowLamp: true,
      introTitle: "Prototype: one bridge",
      introText: "Three lines and one bridge, with traffic both ways.",
    },
    paths: [],
    why: "A chokepoint shared both ways: every train has to be timetabled over the same two squares.",
  },
  {
    data: {
      id: "lab-5",
      name: "Block Section",
      rows: SINGLE,
      ...singleEnds({ start: 0, every: 3 }, { start: 3, every: 3 }),
      allowStop: true,
      signals: "block",
      deadline: 21,
      introTitle: "Prototype: block signals",
      introText: "A train waits at a signal until the track ahead, up to the next signals, is empty. Everyone home by beat 21.",
    },
    paths: [EAST_BAY, WEST_MAIN],
    stops: [[3, 1], [5, 1], [4, 2]],
    why: "Waiting Room with block signals: a signal on each track of the loop lets the trains pass in time.",
  },
  {
    data: {
      id: "lab-6",
      name: "Bridge Section",
      rows: BRIDGE,
      depots: [
        { at: [0, 1], dir: "E", trains: [0, 0], start: 0, every: 5 },
        { at: [8, 6], dir: "W", trains: [1, 1], start: 3, every: 3 },
        { at: [8, 1], dir: "W", trains: [2, 2], start: 2, every: 5 },
      ],
      stations: [
        { at: [0, 6], dir: "E", color: 0 },
        { at: [4, 0], dir: "S", color: 1 },
        { at: [4, 7], dir: "N", color: 2 },
      ],
      allowStop: true,
      allowLamp: true,
      signals: "block",
      deadline: 29,
      introTitle: "Prototype: block signals",
      introText: "Signals guard the track ahead up to the next signals. One bridge, traffic both ways, everyone home by beat 29.",
    },
    paths: [],
    pathsFrom: "lab-4",
    why: "One Bridge with block signals and a deadline.",
  },
  {
    data: {
      id: "lab-7",
      name: "Two Sections",
      rows: BAYS,
      depots: [
        { at: [0, 1], dir: "E", trains: [0, 0], start: 0, every: 3 },
        { at: [12, 3], dir: "W", trains: [1, 1], start: 2, every: 3 },
      ],
      stations: [
        { at: [12, 1], dir: "W", color: 0 },
        { at: [0, 3], dir: "E", color: 1 },
      ],
      allowStop: true,
      signals: "block",
      deadline: 36,
      introTitle: "Prototype: block signals",
      introText: "A long single line with two places to pass. Signals guard the track ahead; everyone home by beat 36.",
    },
    paths: [],
    pathsFrom: "lab-3",
    why: "Two Bays with block signals and a deadline.",
  },
];

const xy = (k: string): P => {
  const c = parseCell(k);
  return [c.x, c.y];
};
function freeze(pz: Puzzle, lay: Layout, paths: P[][]): NonNullable<LevelData["solution"]> {
  const sol: NonNullable<LevelData["solution"]> = { paths };
  if (lay.stops.size) sol.stops = [...lay.stops].map(xy);
  if (lay.lamps.size) sol.lamps = [...lay.lamps].map(([k, c]) => [...xy(k), c] as [number, number, number]);
  if (lay.levers.size) sol.levers = [...lay.levers].map(([k, d]) => [...xy(k), "NESW"[d]] as [number, number, string]);
  if (lay.stems.size) sol.stems = [...lay.stems].map(([k, d]) => [...xy(k), "NESW"[d]] as [number, number, string]);
  void pz;
  return sol;
}

const out: (LevelData & { id: string })[] = [];
for (const pr of PROTOS) {
  const pz = Puzzle.fromData({ ...pr.data, par: 1 });
  let paths = pr.pathsFrom ? out.find((o) => o.id === pr.pathsFrom)!.solution!.paths : pr.paths;
  let stops = pr.stops;
  if (!paths.length && !pr.pathsFrom) {
    // Use the answer the player model found the long way round.
    const p = play(pz, 12);
    if (!p.solved) throw new Error(`${pr.data.name}: no reference`);
    paths = p.paths!.map((q) => q.map((c) => [c.x, c.y] as P));
    stops = [...p.lay!.stops].map(xy);
  }
  if (!stops) {
    const sets = stopSets(pz, paths, 4, 2000);
    if (!sets.length) throw new Error(`${pr.data.name}: reference needs more than four signals`);
    const fewest = Math.min(...sets.map((s) => s.length));
    stops = sets.find((s) => s.length === fewest)!.map(xy);
  }
  const lay = reference(pz, paths, stops);
  const res = run(pz, lay);
  if (!res.success) throw new Error(`${pr.data.name}: reference fails`);
  const par = lay.trackCount(pz);
  pz.par = par;
  const model = play(pz, 12);
  const budget = play(pz, 12, { track: par });
  console.log(`${pr.data.id} ${pr.data.name}: par ${par}, stops ${lay.stops.size}; model ${model.solved ? `solves in ${model.departs} departs (track ${model.track})` : "stuck"}; with par as a budget ${budget.solved ? `solves in ${budget.departs}` : "stuck"}\n${ascii(pz, lay)}\n`);
  out.push({ ...pr.data, par, solution: freeze(pz, lay, paths) });
  void ckey;
}

const ts = `// Difficulty prototypes for playtesting, at #/lab/1 and on. Lab 5 onward try block signals. Not part of the campaign: nothing
// here is saved as stars or counted in progress. Generated by tools/lab/build.ts.

import type { LevelData } from "./puzzle";

export type LabStop = LevelData & { id: string; name: string };

export const LAB: LabStop[] = ${JSON.stringify(out, null, 2)};
`;
writeFileSync("src/core/lab.ts", ts);
