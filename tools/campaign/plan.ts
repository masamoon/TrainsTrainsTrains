// The campaign plan for Lines 3 onward: one recipe per stop. `pick` generates candidates
// for a line and records the chosen seed in seeds.json; `build` freezes the chosen levels
// into src/core/lines/.

import type { LevelData } from "../../src/core/puzzle";
import type { Recipe } from "./gen";

export interface PlanStop {
  id: string;
  name: string;
  introTitle?: string;
  introText?: string;
  recipe?: Recipe;
  data?: LevelData; // hand-made
}

export interface PlanLine {
  name: string;
  color: number;
  stops: PlanStop[];
}

const d = (...trains: number[]) => ({ trains });
const g = (...trains: number[]) => ({ trains, goods: true });

export const PLAN: PlanLine[] = [
  {
    name: "Harbour Line",
    color: 2,
    stops: [
      {
        id: "3-1",
        name: "Double Hold",
        introTitle: "Signals add up",
        introText: "One stop signal holds a train for two beats. Two on the same line hold it for four.",
        recipe: { w: 7, h: 7, theme: "water", depots: [d(0), d(1)], needStop: true, stops: [2, 2], rate: [0.1, 1], maxPar: 13, target: 0.5 },
      },
      {
        id: "3-2",
        name: "Ferry Crossing",
        recipe: { w: 7, h: 8, theme: "water", depots: [d(0), d(1), d(2)], needStop: true, crossings: 2, rate: [0.05, 0.8], target: 0.3 },
      },
      {
        id: "3-3",
        name: "Shared Berth",
        introTitle: "Share the line",
        introText: "Two lines can share track: merge them at a switch, then sort them apart with a colour signal. It saves track.",
        recipe: { w: 7, h: 8, theme: "water", depots: [d(0), d(1)], lamps: [1, 1], rate: [0.05, 0.8], target: 0.3 },
      },
      {
        id: "3-4",
        name: "Quayside",
        recipe: { w: 7, h: 8, theme: "water", depots: [d(0, 1, 0), d(2)], needStop: true, rate: [0.03, 0.6], target: 0.2 },
      },
      {
        id: "3-5",
        name: "Pier Queue",
        recipe: { w: 7, h: 8, theme: "water", depots: [{ trains: [0, 0, 0], every: 2 }, d(1)], needStop: true, rate: [0.03, 0.6], target: 0.2 },
      },
      {
        id: "3-6",
        name: "Lighthouse",
        recipe: { w: 8, h: 8, theme: "water", depots: [d(0), d(0), d(1)], needStop: true, crossings: 1, rate: [0.02, 0.5], target: 0.15 },
      },
      {
        id: "3-7",
        name: "Tide Table",
        recipe: { w: 8, h: 8, theme: "water", depots: [d(0, 1), d(2, 1)], lamps: [1, 3], rate: [0.02, 0.4], target: 0.1 },
      },
      {
        id: "3-8",
        name: "Harbour Rush",
        introTitle: "Harbour rush",
        introText: "Three depots, three platforms and one crowded quay.",
        recipe: { w: 8, h: 8, theme: "water", depots: [d(0, 2, 0), d(1, 1), d(2)], needStop: true, rate: [0.005, 0.2], target: 0.05 },
      },
    ],
  },
  {
    name: "Market Line",
    color: 3,
    stops: [
      {
        id: "4-1",
        name: "Three Ways",
        introTitle: "Three colours",
        introText: "A colour signal picks out one colour. Chain two switches to split three.",
        recipe: { w: 7, h: 7, theme: "town", depots: [d(0, 1, 2)], lamps: [2, 2], rate: [0.1, 1], target: 0.5 },
      },
      {
        id: "4-2",
        name: "Stallholders",
        recipe: { w: 7, h: 8, theme: "town", depots: [d(2, 0, 1, 0)], lamps: [2, 2], needStop: true, rate: [0.05, 0.8], target: 0.3 },
      },
      {
        id: "4-3",
        name: "Corn Exchange",
        recipe: { w: 7, h: 8, theme: "town", depots: [d(0, 1), d(1, 0)], lamps: [1, 3], rate: [0.03, 0.6], target: 0.2 },
      },
      {
        id: "4-4",
        name: "Market Cross",
        recipe: { w: 8, h: 8, theme: "town", depots: [d(0, 1, 2), d(1)], needStop: true, rate: [0.02, 0.5], target: 0.15 },
      },
      {
        id: "4-5",
        name: "Weighbridge",
        recipe: { w: 8, h: 8, theme: "town", depots: [d(1, 0), d(2)], needStop: true, crossings: 1, rate: [0.02, 0.5], target: 0.15 },
      },
      {
        id: "4-6",
        name: "Haberdashers",
        introTitle: "One trunk",
        introText: "Three depots, three platforms. Run them all down one line and sort them at the end.",
        recipe: { w: 8, h: 8, theme: "town", depots: [d(0), d(1), d(2)], lamps: [2, 3], rate: [0.01, 0.5], target: 0.1 },
      },
      {
        id: "4-7",
        name: "Clock Tower",
        recipe: { w: 8, h: 8, theme: "town", depots: [d(0, 1, 2, 1), d(2)], needStop: true, rate: [0.01, 0.3], target: 0.08 },
      },
      {
        id: "4-8",
        name: "Market Day",
        introTitle: "Market day",
        introText: "Every stall wants a delivery at once.",
        recipe: { w: 8, h: 9, theme: "town", depots: [d(0, 1, 0), d(2, 1), d(1, 2)], needStop: true, rate: [0.003, 0.15], target: 0.04 },
      },
    ],
  },
  {
    name: "Moor Line",
    color: 1,
    stops: [
      {
        id: "5-1",
        name: "Single Line Working",
        introTitle: "Take turns",
        introText: "One track, two directions. Let one train clear the line before the other sets off.",
        recipe: { w: 8, h: 5, theme: "woods", corridor: true, depots: [d(0), d(1)], needStop: true, rate: [0.05, 1], target: 0.3, attempts: 240 },
      },
      {
        id: "5-2",
        name: "Bog Cotton",
        recipe: { w: 7, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(0), d(1)], needStop: true, crossings: 1, rate: [0.03, 0.8], target: 0.25 },
      },
      {
        id: "5-3",
        name: "Grouse Butts",
        recipe: { w: 8, h: 5, theme: "woods", corridor: true, depots: [d(0, 0), d(1, 1)], rate: [0.01, 0.6], target: 0.15, attempts: 300 },
      },
      {
        id: "5-4",
        name: "Cairn Tunnel",
        recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 1, 0), d(2)], needStop: true, rate: [0.02, 0.6], target: 0.15 },
      },
      {
        id: "5-5",
        name: "Peat Cutting",
        recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(0), d(1), d(2)], needStop: true, crossings: 1, rate: [0.01, 0.5], target: 0.1 },
      },
      {
        id: "5-6",
        name: "Two Way Moor",
        recipe: { w: 9, h: 5, theme: "woods", corridor: true, depots: [d(0, 0), d(1)], needStop: true, rate: [0.005, 0.5], target: 0.1, attempts: 300 },
      },
      {
        id: "5-7",
        name: "Heather Bore",
        recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 1), d(1, 0)], rate: [0.005, 0.4], target: 0.08 },
      },
      {
        id: "5-8",
        name: "Moor Rush",
        introTitle: "Moor rush",
        introText: "The tunnel is the quick way across. Everyone wants it.",
        recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 2, 0), d(1), d(2, 1)], needStop: true, rate: [0.003, 0.2], target: 0.04 },
      },
    ],
  },
  {
    name: "Coal Line",
    color: 0,
    stops: [
      {
        id: "6-1",
        name: "Slow Train Coming",
        introTitle: "Stuck behind",
        introText: "Trains can't overtake. A passenger train behind a goods train has to go at its pace.",
        recipe: { w: 7, h: 7, theme: "woods", depots: [g(0), d(1)], needStop: true, rate: [0.05, 1], target: 0.4 },
      },
      {
        id: "6-2",
        name: "Coal Drop",
        recipe: { w: 7, h: 8, theme: "woods", depots: [g(0, 1), d(2)], needStop: true, rate: [0.03, 0.8], target: 0.25 },
      },
      {
        id: "6-3",
        name: "Pit Head",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [g(0), d(1), d(2)], needStop: true, crossings: 2, rate: [0.02, 0.6], target: 0.15 },
      },
      {
        id: "6-4",
        name: "Coke Ovens",
        recipe: { w: 8, h: 8, theme: "woods", ridge: true, needTunnel: true, depots: [g(0), d(1, 0)], needStop: true, rate: [0.02, 0.6], target: 0.15 },
      },
      {
        id: "6-5",
        name: "Wagon Way",
        recipe: { w: 9, h: 5, theme: "woods", corridor: true, depots: [g(0), d(1, 1)], needStop: true, rate: [0.005, 0.6], target: 0.1, attempts: 300 },
      },
      {
        id: "6-6",
        name: "Two Goods",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [g(0), g(1), d(2)], needStop: true, crossings: 1, rate: [0.01, 0.4], target: 0.08 },
      },
      {
        id: "6-7",
        name: "Slag Heap",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [g(0, 1), d(1, 2)], needStop: true, rate: [0.005, 0.3], target: 0.06 },
      },
      {
        id: "6-8",
        name: "Coal Rush",
        introTitle: "Coal rush",
        introText: "Two goods trains and the passenger service, all through the same yard.",
        recipe: { w: 8, h: 9, theme: "mixed", depots: [g(0), g(2), d(1, 0, 1)], needStop: true, rate: [0.002, 0.15], target: 0.03 },
      },
    ],
  },
  {
    name: "Clockwork Line",
    color: 2,
    stops: [
      {
        id: "7-1",
        name: "Not Before Ten",
        introTitle: "New: timed platform",
        introText: "This platform opens on the beat shown on its clock. A train that arrives sooner is turned away, so hold it back.",
        recipe: { w: 7, h: 7, theme: "woods", depots: [d(0)], timed: 1, needStop: true, rate: [0.2, 1], maxPar: 8, target: 0.8 },
      },
      {
        id: "7-2",
        name: "Late Shift",
        recipe: { w: 7, h: 7, theme: "woods", depots: [d(0), d(1)], timed: 1, needStop: true, crossings: 1, rate: [0.05, 0.8], target: 0.3 },
      },
      {
        id: "7-3",
        name: "Platform Clock",
        recipe: { w: 7, h: 8, theme: "mixed", depots: [d(0, 1, 0)], timed: 1, needStop: true, rate: [0.03, 0.7], target: 0.25 },
      },
      {
        id: "7-4",
        name: "Half Past",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [d(0), d(1), d(2)], timed: 1, needStop: true, crossings: 1, rate: [0.02, 0.5], target: 0.15 },
      },
      {
        id: "7-5",
        name: "Escapement",
        recipe: { w: 8, h: 8, theme: "woods", depots: [d(0), d(0), d(1)], timed: 1, needStop: true, rate: [0.01, 0.5], target: 0.12 },
      },
      {
        id: "7-6",
        name: "Two Clocks",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [d(0, 1), d(2)], timed: 2, needStop: true, rate: [0.01, 0.4], target: 0.08 },
      },
      {
        id: "7-7",
        name: "Pendulum",
        recipe: { w: 8, h: 8, theme: "woods", depots: [g(0), d(1), d(2)], timed: 1, needStop: true, rate: [0.005, 0.3], target: 0.06 },
      },
      {
        id: "7-8",
        name: "Rush Hour Timetable",
        introTitle: "Timetable",
        introText: "Every platform keeps its own time.",
        recipe: { w: 8, h: 9, theme: "mixed", depots: [d(0, 1, 0), d(2), d(1)], timed: 2, needStop: true, rate: [0.002, 0.15], target: 0.03 },
      },
    ],
  },
  {
    name: "Junction Line",
    color: 3,
    stops: [
      {
        id: "8-1",
        name: "Old Spur",
        introTitle: "Work with it",
        introText: "The old line is in the way. Cross it, branch off it, or share it.",
        recipe: { w: 7, h: 8, theme: "woods", fixed: true, depots: [d(0), d(1)], needStop: true, rate: [0.05, 1], target: 0.4 },
      },
      {
        id: "8-2",
        name: "Points Failure",
        recipe: { w: 8, h: 8, theme: "mixed", fixed: true, depots: [d(0, 1, 0), d(2)], rate: [0.03, 0.8], target: 0.25 },
      },
      {
        id: "8-3",
        name: "Signal Box",
        recipe: { w: 8, h: 8, theme: "town", fixed: true, depots: [d(0), d(1), d(2)], needStop: true, rate: [0.02, 0.6], target: 0.15 },
      },
      {
        id: "8-4",
        name: "Engine Shed",
        recipe: { w: 8, h: 8, theme: "woods", fixed: true, ridge: true, depots: [d(0, 1), d(2)], needStop: true, rate: [0.02, 0.6], target: 0.15 },
      },
      {
        id: "8-5",
        name: "Turntable",
        recipe: { w: 8, h: 8, theme: "mixed", fixed: true, depots: [g(0), d(1), d(1)], needStop: true, rate: [0.01, 0.5], target: 0.1 },
      },
      {
        id: "8-6",
        name: "Goods Yard",
        recipe: { w: 8, h: 8, theme: "town", fixed: true, depots: [d(0, 1, 2), d(0)], rate: [0.01, 0.4], target: 0.08 },
      },
      {
        id: "8-7",
        name: "Diamond Crossing",
        recipe: { w: 8, h: 8, theme: "mixed", fixed: true, depots: [d(0), d(1), d(2), d(0)], needStop: true, crossings: 2, rate: [0.005, 0.3], target: 0.06 },
      },
      {
        id: "8-8",
        name: "Junction Rush",
        introTitle: "Junction rush",
        introText: "A busy junction with old track everywhere. Use what you can.",
        recipe: { w: 8, h: 9, theme: "mixed", fixed: true, depots: [d(0, 1), d(2), d(1, 2)], needStop: true, rate: [0.003, 0.3], target: 0.04 },
      },
    ],
  },
  {
    name: "Festival Line",
    color: 1,
    stops: [
      {
        id: "9-1",
        name: "Bunting",
        introTitle: "Fourth colour",
        introText: "Tangerine trains, with a diamond, join the timetable.",
        recipe: { w: 7, h: 8, theme: "woods", depots: [d(3), d(0)], needStop: true, crossings: 1, rate: [0.05, 1], target: 0.4 },
      },
      {
        id: "9-2",
        name: "Bandstand",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [d(3, 0, 3), d(1)], needStop: true, rate: [0.03, 0.7], target: 0.25 },
      },
      {
        id: "9-3",
        name: "Four Ways",
        introTitle: "Four colours",
        introText: "Three colour signals, four platforms.",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [d(0, 1, 2, 3)], lamps: [3, 3], rate: [0.02, 0.8], target: 0.2 },
      },
      {
        id: "9-4",
        name: "Carousel",
        recipe: { w: 8, h: 8, theme: "woods", depots: [d(0), d(1), d(2), d(3)], needStop: true, crossings: 2, rate: [0.01, 0.5], target: 0.12 },
      },
      {
        id: "9-5",
        name: "Fireworks",
        recipe: { w: 8, h: 8, theme: "mixed", depots: [d(3, 2), d(1, 0)], timed: 1, needStop: true, rate: [0.01, 0.5], target: 0.1 },
      },
      {
        id: "9-6",
        name: "Ferris Wheel",
        recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(3, 0), d(1), d(2)], needStop: true, rate: [0.005, 0.4], target: 0.08 },
      },
      {
        id: "9-7",
        name: "Last Orders",
        recipe: { w: 8, h: 9, theme: "mixed", depots: [g(3), d(0, 1, 0), d(2)], needStop: true, rate: [0.005, 0.3], target: 0.05 },
      },
      {
        id: "9-8",
        name: "Festival Rush",
        introTitle: "Festival rush",
        introText: "Four colours, everyone heading home at once.",
        recipe: { w: 8, h: 9, theme: "mixed", depots: [d(0, 3, 1), d(2, 0), d(3, 1)], needStop: true, rate: [0.002, 0.12], target: 0.03 },
      },
    ],
  },
  {
    name: "Coast Line",
    color: 2,
    stops: [
      { id: "10-1", name: "Sea Wall", recipe: { w: 8, h: 8, theme: "water", depots: [d(0, 1), d(2), d(3)], needStop: true, crossings: 2, rate: [0.01, 0.5], target: 0.12 } },
      { id: "10-2", name: "Rock Pools", recipe: { w: 8, h: 8, theme: "water", depots: [d(0), d(0), d(1), d(1)], needStop: true, rate: [0.01, 0.5], target: 0.1 } },
      { id: "10-3", name: "Breakwater", recipe: { w: 9, h: 5, theme: "water", corridor: true, depots: [d(0, 0), d(1, 1)], needStop: true, rate: [0.002, 0.4], target: 0.06, attempts: 300 } },
      { id: "10-4", name: "Salt Marsh", recipe: { w: 8, h: 8, theme: "water", depots: [g(2), d(0, 1, 0)], timed: 1, needStop: true, rate: [0.005, 0.4], target: 0.08 } },
      { id: "10-5", name: "Cliff Tunnel", recipe: { w: 8, h: 9, theme: "water", ridge: true, needTunnel: true, depots: [d(0, 1), d(2), d(3)], needStop: true, rate: [0.005, 0.3], target: 0.06 } },
      { id: "10-6", name: "Esplanade", recipe: { w: 8, h: 9, theme: "water", fixed: true, depots: [d(1, 2, 1), d(0), d(3)], needStop: true, rate: [0.003, 0.3], target: 0.05 } },
      { id: "10-7", name: "Lifeboat Station", recipe: { w: 8, h: 9, theme: "water", depots: [g(0), d(1, 2), d(3, 1)], needStop: true, rate: [0.003, 0.25], target: 0.04 } },
      {
        id: "10-8",
        name: "Coast Rush",
        introTitle: "Coast rush",
        introText: "A long day at the seaside, and everyone wants the last train.",
        recipe: { w: 8, h: 9, theme: "water", depots: [d(0, 1, 2), d(3), d(2, 3)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.03 },
      },
    ],
  },
  {
    name: "Summit Line",
    color: 0,
    stops: [
      { id: "11-1", name: "Rack and Pinion", recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [g(0), d(1), d(2)], needStop: true, crossings: 1, rate: [0.01, 0.5], target: 0.1 } },
      { id: "11-2", name: "Snow Shed", recipe: { w: 8, h: 8, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 1, 2), d(3)], timed: 1, needStop: true, rate: [0.005, 0.4], target: 0.08 } },
      { id: "11-3", name: "Switchback", recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 0), d(1, 1)], needStop: true, rate: [0.005, 0.4], target: 0.06 } },
      { id: "11-4", name: "Avalanche Gallery", recipe: { w: 8, h: 9, theme: "hill", ridge: true, fixed: true, depots: [d(1, 0), d(2), d(3)], needStop: true, rate: [0.003, 0.3], target: 0.05 } },
      { id: "11-5", name: "Col", recipe: { w: 9, h: 5, theme: "woods", corridor: true, depots: [g(0), d(1, 1)], timed: 1, needStop: true, rate: [0.002, 0.4], target: 0.05, attempts: 300 } },
      { id: "11-6", name: "Spiral Tunnel", recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [g(2), d(0, 3), d(1)], needStop: true, rate: [0.002, 0.25], target: 0.04 } },
      { id: "11-7", name: "Observatory", recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 1, 2), d(3, 0)], needStop: true, rate: [0.003, 0.3], target: 0.04 } },
      {
        id: "11-8",
        name: "Summit Rush",
        introTitle: "Summit rush",
        introText: "One tunnel through the mountain and a timetable to keep.",
        recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [g(1), d(0, 2, 0), d(3, 2)], timed: 1, needStop: true, rate: [0.001, 0.1], target: 0.02 },
      },
    ],
  },
  {
    name: "Night Mail",
    color: 3,
    stops: [
      { id: "12-1", name: "Sorting Van", recipe: { w: 8, h: 9, theme: "mixed", depots: [d(0, 1, 2, 3, 0)], timed: 1, needStop: true, rate: [0.005, 0.4], target: 0.08 } },
      { id: "12-2", name: "Mail Bag", recipe: { w: 8, h: 9, theme: "town", depots: [g(3), g(0), d(1, 2)], needStop: true, rate: [0.003, 0.3], target: 0.05 } },
      { id: "12-3", name: "Lamplighter", recipe: { w: 8, h: 9, theme: "mixed", fixed: true, depots: [d(0, 1), d(2, 3), d(1)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.05 } },
      { id: "12-4", name: "Night Ferry", recipe: { w: 9, h: 5, theme: "water", corridor: true, depots: [d(0, 0, 0), d(1, 1)], needStop: true, rate: [0.001, 0.3], target: 0.04, attempts: 300 } },
      { id: "12-5", name: "Owl Express", recipe: { w: 8, h: 9, theme: "hill", ridge: true, needTunnel: true, depots: [g(0), d(1, 3), d(2, 1)], timed: 1, needStop: true, rate: [0.002, 0.25], target: 0.04 } },
      { id: "12-6", name: "Postal Order", recipe: { w: 8, h: 9, theme: "town", depots: [d(0), d(1), d(2), d(3), d(0)], needStop: true, crossings: 2, rate: [0.002, 0.2], target: 0.03 } },
      { id: "12-7", name: "Milk Train", recipe: { w: 8, h: 9, theme: "mixed", depots: [g(1, 2), d(0, 3, 0), d(2)], timed: 2, needStop: true, rate: [0.001, 0.15], target: 0.025 } },
      {
        id: "12-8",
        name: "Night Rush",
        introTitle: "Night rush",
        introText: "The mail must get through before dawn.",
        recipe: { w: 8, h: 9, theme: "mixed", depots: [d(0, 1, 2), g(3), d(1, 0)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.03 },
      },
    ],
  },
  {
    name: "Grand Terminus",
    color: 1,
    stops: [
      { id: "13-1", name: "Concourse", recipe: { w: 8, h: 9, theme: "town", depots: [d(0, 3, 1), d(2)], needStop: true, rate: [0.003, 0.4], target: 0.05 } },
      { id: "13-2", name: "Ticket Hall", recipe: { w: 8, h: 9, theme: "town", fixed: true, depots: [g(0), d(1, 2), d(3)], timed: 1, needStop: true, rate: [0.002, 0.25], target: 0.035 } },
      { id: "13-3", name: "Left Luggage", recipe: { w: 8, h: 9, theme: "mixed", ridge: true, needTunnel: true, depots: [d(0, 1, 0), d(2, 3, 2), d(1)], needStop: true, rate: [0.001, 0.2], target: 0.03 } },
      { id: "13-4", name: "Departure Board", recipe: { w: 8, h: 9, theme: "town", depots: [d(0, 1), d(2, 3), d(1)], timed: 2, needStop: true, rate: [0.003, 0.3], target: 0.03 } },
      { id: "13-5", name: "Platform Nine", recipe: { w: 8, h: 9, theme: "mixed", depots: [g(1), d(0, 2, 0), d(3)], needStop: true, rate: [0.003, 0.3], target: 0.03 } },
      { id: "13-6", name: "Station Master", recipe: { w: 8, h: 9, theme: "town", fixed: true, ridge: true, depots: [d(3, 0, 3), d(1, 2)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.03 } },
      { id: "13-7", name: "Great Roof", recipe: { w: 8, h: 9, theme: "mixed", depots: [d(0, 1, 2, 1), g(3), d(2)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.025 } },
      {
        id: "13-8",
        name: "Grand Terminus",
        introTitle: "Grand Terminus",
        introText: "Everything you've learned, under one great roof. Good luck, signaller.",
        recipe: { w: 8, h: 9, theme: "mixed", ridge: true, needTunnel: true, depots: [d(0, 1, 2), g(3), d(2, 0)], timed: 1, needStop: true, rate: [0.003, 0.3], target: 0.02 },
      },
    ],
  },
];
