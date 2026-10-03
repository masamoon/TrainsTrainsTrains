// The block-signal campaign plan for Lines 3 to 13: one spec per stop. Stop ids and names
// stay as they were, so saved stars keep their place. `tools/lab/blockpick.ts` generates
// candidates and freezes the chosen ones into src/core/lines/.

import type { Spec } from "./blockgen";

export interface BlockStop {
  id: string;
  name: string;
  introTitle?: string;
  introText?: string;
  spec: Spec;
}

export interface BlockLine {
  file: string; // src/core/lines/<file>.ts
  constName: string;
  stops: BlockStop[];
}

const r = 0;
const t = 1;
const v = 2;
const o = 3;
const one = (c: number) => ({ trains: [c] });
const two = (c: number) => ({ trains: [c, c] });
const three = (c: number) => ({ trains: [c, c, c] });
const goods = (c: number, n = 1) => ({ trains: Array(n).fill(c), goods: true });

// Single lines with passing bays.
const line = (w: number, west: Spec["depots"][number], east: Spec["depots"][number], more: Partial<Spec> = {}): Spec => ({
  family: "line",
  w,
  theme: "woods",
  bays: [1, 2],
  depots: [west, east],
  ...more,
});
// Open ground split by a band crossed at a few gaps or one bore.
const band = (w: number, h: number, depots: Spec["depots"], more: Partial<Spec> = {}): Spec => ({
  family: "band",
  w,
  h,
  theme: "water",
  gaps: [1, 1],
  depots,
  ...more,
});

const stuck = { model: 99 };

export const BLOCK_PLAN: BlockLine[] = [
  {
    file: "line03",
    constName: "HARBOUR_LINE",
    stops: [
      {
        id: "3-1",
        name: "Double Hold",
        introTitle: "Passing places",
        introText: "One line, trains both ways. Wait in a bay while the others pass, and get everyone home in time.",
        spec: line(9, two(r), one(t), { theme: "water", bays: [1, 1], model: 2 }),
      },
      { id: "3-2", name: "Ferry Crossing", spec: line(9, two(r), two(t), { theme: "water", bays: [1, 1] }) },
      { id: "3-3", name: "Shared Berth", spec: line(10, two(r), two(t), { theme: "water" }) },
      { id: "3-4", name: "Quayside", spec: line(10, two(r), one(t), { theme: "water", spurs: [one(v)] }) },
      { id: "3-5", name: "Pier Queue", spec: line(11, three(r), one(t), { theme: "water" }) },
      { id: "3-6", name: "Lighthouse", spec: line(11, two(r), two(t), { theme: "water", ...stuck }) },
      { id: "3-7", name: "Tide Table", spec: line(11, two(r), one(t), { theme: "water", spurs: [one(v)], ...stuck }) },
      {
        id: "3-8",
        name: "Harbour Rush",
        introTitle: "Harbour rush",
        introText: "A long quay, three lines and two bays.",
        spec: line(12, two(r), two(t), { theme: "water", bays: [2, 2], spurs: [one(v)], ...stuck }),
      },
    ],
  },
  {
    file: "line04",
    constName: "MARKET_LINE",
    stops: [
      {
        id: "4-1",
        name: "Three Ways",
        introTitle: "One way through",
        introText: "The town has one street through it. Every line has to cross it, some each way.",
        spec: band(8, 7, [one(r), one(t), one(v)], { theme: "town", model: 2 }),
      },
      { id: "4-2", name: "Stallholders", spec: band(7, 7, [two(r), one(t), one(v)], { theme: "town" }) },
      { id: "4-3", name: "Corn Exchange", spec: band(8, 7, [two(r), two(t), one(v)], { theme: "town" }) },
      { id: "4-4", name: "Market Cross", spec: band(8, 8, [one(r), two(t), two(v)], { theme: "town" }) },
      { id: "4-5", name: "Weighbridge", spec: band(8, 8, [two(r), two(t), one(v)], { theme: "town", ...stuck }) },
      {
        id: "4-6",
        name: "Haberdashers",
        introTitle: "Two streets",
        introText: "Two ways through town now. Which line takes which?",
        spec: band(9, 8, [two(r), two(t), one(v)], { theme: "town", gaps: [2, 2] }),
      },
      { id: "4-7", name: "Clock Tower", spec: band(9, 8, [two(r), two(t), one(v)], { theme: "town", gaps: [2, 2], ...stuck }) },
      {
        id: "4-8",
        name: "Market Day",
        introTitle: "Market day",
        introText: "Everyone wants the one street at once.",
        spec: band(9, 8, [two(r), two(t), two(v)], { theme: "town", ...stuck }),
      },
    ],
  },
  {
    file: "line05",
    constName: "MOOR_LINE",
    stops: [
      {
        id: "5-1",
        name: "Single Line Working",
        introTitle: "Follow on",
        introText: "A long single line. A signal partway along lets a second train set off before the first is home.",
        spec: line(12, two(r), two(t), { bays: [1, 1], model: 2 }),
      },
      { id: "5-2", name: "Bog Cotton", spec: line(12, two(r), two(t)) },
      { id: "5-3", name: "Grouse Butts", spec: line(12, three(r), one(t)) },
      { id: "5-4", name: "Cairn Tunnel", spec: line(12, two(r), two(t), { bays: [2, 2] }) },
      { id: "5-5", name: "Peat Cutting", spec: line(13, two(r), two(t), { ...stuck }) },
      { id: "5-6", name: "Two Way Moor", spec: line(13, three(r), two(t), { bays: [2, 2], ...stuck }) },
      { id: "5-7", name: "Heather Bore", spec: line(13, two(r), two(t), { spurs: [one(v)], ...stuck }) },
      {
        id: "5-8",
        name: "Moor Rush",
        introTitle: "Moor rush",
        introText: "The longest line yet, busy both ways.",
        spec: line(13, three(r), three(t), { bays: [2, 2], ...stuck }),
      },
    ],
  },
  {
    file: "line06",
    constName: "COAL_LINE",
    stops: [
      {
        id: "6-1",
        name: "Slow Train Coming",
        introTitle: "Stuck behind",
        introText: "Goods trains move every other beat. Anything behind one waits, so let it go first or last.",
        spec: line(10, { trains: [r], goods: true }, two(t), { model: 2 }),
      },
      { id: "6-2", name: "Coal Drop", spec: line(11, goods(r), two(t)) },
      { id: "6-3", name: "Pit Head", spec: line(11, two(r), goods(t, 2)) },
      { id: "6-4", name: "Coke Ovens", spec: band(8, 7, [goods(r), two(t), one(v)], { theme: "woods" }) },
      { id: "6-5", name: "Wagon Way", spec: line(12, goods(r), two(t), { spurs: [one(v)], ...stuck }) },
      { id: "6-6", name: "Two Goods", spec: line(12, goods(r), goods(t), { bays: [2, 2], ...stuck }) },
      { id: "6-7", name: "Slag Heap", spec: band(8, 8, [goods(r), two(t), two(v)], { theme: "woods", ...stuck }) },
      {
        id: "6-8",
        name: "Coal Rush",
        introTitle: "Coal rush",
        introText: "Coal one way, passengers the other.",
        spec: line(13, { trains: [r, r], goods: true }, three(t), { bays: [2, 2], ...stuck }),
      },
    ],
  },
  {
    file: "line07",
    constName: "CLOCKWORK_LINE",
    stops: [
      {
        id: "7-1",
        name: "Not Before Ten",
        introTitle: "To the beat",
        introText: "From here the timetable gives you one beat to spare, not two.",
        spec: line(10, two(r), two(t), { slack: 1, model: 2 }),
      },
      { id: "7-2", name: "Late Shift", spec: line(11, two(r), two(t), { slack: 1 }) },
      { id: "7-3", name: "Platform Clock", spec: band(8, 7, [two(r), one(t), one(v)], { theme: "town", slack: 1 }) },
      { id: "7-4", name: "Half Past", spec: line(11, three(r), one(t), { slack: 1, ...stuck }) },
      { id: "7-5", name: "Escapement", spec: line(12, two(r), two(t), { slack: 1, spurs: [one(v)], ...stuck }) },
      { id: "7-6", name: "Two Clocks", spec: band(8, 8, [two(r), two(t), one(v)], { theme: "town", slack: 1, ...stuck }) },
      { id: "7-7", name: "Pendulum", spec: line(12, two(r), two(t), { slack: 1, bays: [2, 2], ...stuck }) },
      {
        id: "7-8",
        name: "Rush Hour Timetable",
        introTitle: "Timetable",
        introText: "Every beat counts.",
        spec: line(13, three(r), two(t), { slack: 1, bays: [2, 2], ...stuck }),
      },
    ],
  },
  {
    file: "line08",
    constName: "JUNCTION_LINE",
    stops: [
      {
        id: "8-1",
        name: "Old Spur",
        introTitle: "Sort after the gap",
        introText: "Two colours share a depot. Send them through the gap together, then sort them with a colour signal.",
        spec: band(8, 8, [{ trains: [r, t] }, one(v)], { theme: "woods", lamps: true, model: 2 }),
      },
      { id: "8-2", name: "Points Failure", spec: band(8, 8, [{ trains: [r, t] }, two(v)], { theme: "woods", lamps: true }) },
      { id: "8-3", name: "Signal Box", spec: band(8, 8, [{ trains: [r, t, r] }, one(v)], { theme: "woods", lamps: true }) },
      { id: "8-4", name: "Engine Shed", spec: band(9, 8, [{ trains: [r, t] }, two(v)], { theme: "woods", lamps: true, gaps: [2, 2] }) },
      { id: "8-5", name: "Turntable", spec: band(9, 8, [{ trains: [r, t, r] }, two(v)], { theme: "woods", lamps: true, ...stuck }) },
      { id: "8-6", name: "Goods Yard", spec: band(9, 8, [{ trains: [r, t] }, goods(v)], { theme: "woods", lamps: true, ...stuck }) },
      { id: "8-7", name: "Diamond Crossing", spec: band(9, 8, [{ trains: [r, t] }, two(v), one(r)], { theme: "woods", lamps: true, ...stuck }) },
      {
        id: "8-8",
        name: "Junction Rush",
        introTitle: "Junction rush",
        introText: "Sort, merge and pass, all through one gap.",
        spec: band(9, 8, [{ trains: [r, t, r] }, two(v), one(t)], { theme: "woods", lamps: true, ...stuck }),
      },
    ],
  },
  {
    file: "line09",
    constName: "FESTIVAL_LINE",
    stops: [
      {
        id: "9-1",
        name: "Bunting",
        introTitle: "Fourth colour",
        introText: "Tangerine trains join in.",
        spec: band(8, 8, [one(r), one(t), one(v), one(o)], { theme: "town", model: 2 }),
      },
      { id: "9-2", name: "Bandstand", spec: line(12, two(r), two(t), { theme: "town", spurs: [one(o)] }) },
      { id: "9-3", name: "Four Ways", spec: band(8, 8, [two(r), one(t), one(v), one(o)], { theme: "town" }) },
      { id: "9-4", name: "Carousel", spec: line(12, two(o), two(t), { theme: "town", spurs: [one(v)], ...stuck }) },
      { id: "9-5", name: "Fireworks", spec: band(9, 8, [two(r), two(t), one(v), one(o)], { theme: "town", gaps: [2, 2], ...stuck }) },
      { id: "9-6", name: "Ferris Wheel", spec: line(13, two(r), two(o), { theme: "town", spurs: [one(v)], bays: [2, 2], ...stuck }) },
      { id: "9-7", name: "Last Orders", spec: band(9, 8, [two(r), two(t), two(o)], { theme: "town", ...stuck }) },
      {
        id: "9-8",
        name: "Festival Rush",
        introTitle: "Festival rush",
        introText: "Four colours and one way through.",
        spec: band(9, 8, [two(r), two(t), one(v), two(o)], { theme: "town", ...stuck }),
      },
    ],
  },
  {
    file: "line10",
    constName: "COAST_LINE",
    stops: [
      { id: "10-1", name: "Sea Wall", spec: line(12, two(r), two(t), { theme: "water", spurs: [one(v)] }) },
      { id: "10-2", name: "Rock Pools", spec: band(8, 8, [two(r), two(t), one(v)], { gaps: [1, 2] }) },
      { id: "10-3", name: "Breakwater", spec: line(13, three(r), two(t), { theme: "water", ...stuck }) },
      { id: "10-4", name: "Salt Marsh", spec: band(9, 8, [two(r), one(t), two(v)], { gaps: [1, 2], ...stuck }) },
      { id: "10-5", name: "Cliff Tunnel", spec: band(8, 8, [two(r), two(t), one(v)], { theme: "hill", tunnel: true, ...stuck }) },
      { id: "10-6", name: "Esplanade", spec: line(13, two(r), three(t), { theme: "water", spurs: [one(v)], ...stuck }) },
      { id: "10-7", name: "Lifeboat Station", spec: band(9, 8, [two(r), goods(t), two(v)], { ...stuck }) },
      {
        id: "10-8",
        name: "Coast Rush",
        introTitle: "Coast rush",
        introText: "The tide is in and every line wants the causeway.",
        spec: band(9, 8, [three(r), two(t), two(v)], { ...stuck }),
      },
    ],
  },
  {
    file: "line11",
    constName: "SUMMIT_LINE",
    stops: [
      {
        id: "11-1",
        name: "Rack and Pinion",
        introTitle: "One bore",
        introText: "The only way over is a single-track tunnel. A train inside it fills the whole block.",
        spec: band(8, 8, [two(r), one(t)], { theme: "hill", tunnel: true, model: 2 }),
      },
      { id: "11-2", name: "Snow Shed", spec: band(8, 8, [two(r), two(t)], { theme: "hill", tunnel: true }) },
      { id: "11-3", name: "Switchback", spec: band(8, 8, [two(r), one(t), one(v)], { theme: "hill", tunnel: true }) },
      { id: "11-4", name: "Avalanche Gallery", spec: band(8, 8, [two(r), two(t), one(v)], { theme: "hill", tunnel: true, ...stuck }) },
      { id: "11-5", name: "Col", spec: band(9, 8, [goods(r), two(t), one(v)], { theme: "hill", tunnel: true, ...stuck }) },
      { id: "11-6", name: "Spiral Tunnel", spec: band(9, 8, [two(r), two(t), two(v)], { theme: "hill", tunnel: true, ...stuck }) },
      { id: "11-7", name: "Observatory", spec: band(9, 8, [three(r), two(t), one(v)], { theme: "hill", tunnel: true, ...stuck }) },
      {
        id: "11-8",
        name: "Summit Rush",
        introTitle: "Summit rush",
        introText: "Everyone over the top through one bore.",
        spec: band(9, 8, [two(r), two(t), two(v), one(o)], { theme: "hill", tunnel: true, ...stuck }),
      },
    ],
  },
  {
    file: "line12",
    constName: "NIGHT_MAIL",
    stops: [
      { id: "12-1", name: "Sorting Van", spec: line(12, three(r), two(t), { spurs: [one(v)] }) },
      { id: "12-2", name: "Mail Bag", spec: band(9, 8, [three(r), two(t), one(v)], { theme: "woods" }) },
      { id: "12-3", name: "Lamplighter", spec: line(13, three(r), three(t), { ...stuck }) },
      { id: "12-4", name: "Night Ferry", spec: band(9, 8, [two(r), three(t), two(v)], { gaps: [1, 2], ...stuck }) },
      { id: "12-5", name: "Owl Express", spec: line(13, three(r), two(t), { spurs: [two(v)], ...stuck }) },
      { id: "12-6", name: "Postal Order", spec: band(9, 8, [three(r), two(t), two(o)], { theme: "woods", ...stuck }) },
      { id: "12-7", name: "Milk Train", spec: line(13, goods(r, 2), three(t), { spurs: [one(v)], ...stuck }) },
      {
        id: "12-8",
        name: "Night Rush",
        introTitle: "Night rush",
        introText: "The last mail of the night, and everyone else too.",
        spec: line(13, three(r), three(t), { bays: [2, 2], spurs: [one(v)], ...stuck }),
      },
    ],
  },
  {
    file: "line13",
    constName: "GRAND_TERMINUS",
    stops: [
      { id: "13-1", name: "Concourse", spec: band(9, 8, [two(r), two(t), two(v)], { theme: "town", ...stuck }) },
      { id: "13-2", name: "Ticket Hall", spec: line(13, three(r), two(t), { theme: "town", spurs: [one(o)], ...stuck }) },
      { id: "13-3", name: "Left Luggage", spec: band(9, 8, [three(r), goods(t), two(v)], { theme: "town", ...stuck }) },
      { id: "13-4", name: "Departure Board", spec: line(13, three(r), three(t), { theme: "town", bays: [2, 2], slack: 1, ...stuck }) },
      { id: "13-5", name: "Platform Nine", spec: band(9, 8, [two(r), two(t), two(v), one(o)], { theme: "town", gaps: [2, 2], ...stuck }) },
      { id: "13-6", name: "Station Master", spec: band(9, 8, [three(r), two(t), two(v)], { theme: "hill", tunnel: true, ...stuck }) },
      { id: "13-7", name: "Great Roof", spec: line(13, three(r), three(t), { theme: "town", spurs: [one(v)], slack: 1, ...stuck }) },
      {
        id: "13-8",
        name: "Grand Terminus",
        introTitle: "Grand Terminus",
        introText: "Every line in, every line out, and the timetable to keep.",
        spec: band(9, 8, [three(r), two(t), two(v), two(o)], { theme: "town", slack: 1, ...stuck }),
      },
    ],
  },
];
