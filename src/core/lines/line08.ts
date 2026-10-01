// Line 8, Junction Line. Generated with tools/campaign and curated by hand.

import type { Stop } from "../levels";

export const JUNCTION_LINE: Stop[] = [
  {
    id: "8-1",
    name: "Old Spur",
    rows: [".......", ".......", ".......", "T.....T", ".T...T.", ".TT.TT.", ".......", "......."],
    depots: [
      { at: [4, 7], dir: "N", trains: [0], every: 3, start: 3 },
      { at: [1, 0], dir: "S", trains: [1], every: 3, start: 2 },
    ],
    stations: [{ at: [6, 1], dir: "W", color: 0 }, { at: [1, 7], dir: "N", color: 1 }],
    fixed: [[[4, 6], [3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [4, 2], [5, 2], [5, 1]]],
    allowStop: true,
    allowLamp: true,
    introTitle: "Work with it",
    introText: "The old line is in the way. Cross it, branch off it, or share it.",
    solution: {
      paths: [
        [[4, 7], [4, 6], [3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [4, 2], [5, 2], [5, 1], [6, 1]],
        [[1, 0], [1, 1], [1, 2], [2, 2], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6], [2, 6], [1, 6], [1, 7]],
      ],
      stops: [[1, 2], [1, 1]],
      levers: [[3, 2, "E"], [3, 6, "W"]],
    },
  },
  {
    id: "8-2",
    name: "Points Failure",
    rows: ["........", "........", "........", "~H....H~", "~......~", "........", "~~....~~", ".~....~."],
    depots: [
      { at: [3, 7], dir: "N", trains: [0, 1, 0], every: 3, start: 2 },
      { at: [5, 7], dir: "N", trains: [2], every: 3, start: 0 },
    ],
    stations: [{ at: [7, 1], dir: "W", color: 0 }, { at: [1, 0], dir: "S", color: 1 }, { at: [4, 0], dir: "S", color: 2 }],
    fixed: [[[3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [3, 1], [2, 1], [1, 1]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[3, 7], [3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [3, 1], [4, 1], [5, 1], [6, 1], [7, 1]],
        [[5, 7], [5, 6], [5, 5], [5, 4], [4, 4], [4, 3], [4, 2], [4, 1], [4, 0]],
        [[3, 7], [3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [3, 1], [2, 1], [1, 1], [1, 0]],
      ],
      lamps: [[3, 1, 0]],
      levers: [[3, 1, "E"]],
    },
  },
  {
    id: "8-3",
    name: "Signal Box",
    rows: ["........", "........", ".....HHH", "........", "........", "........", "........", "..T....."],
    depots: [
      { at: [0, 4], dir: "E", trains: [0], every: 3, start: 1 },
      { at: [4, 7], dir: "N", trains: [1], every: 3, start: 3 },
      { at: [4, 0], dir: "S", trains: [2], every: 3, start: 3 },
    ],
    stations: [{ at: [6, 0], dir: "S", color: 0 }, { at: [7, 3], dir: "W", color: 1 }, { at: [0, 1], dir: "E", color: 2 }],
    fixed: [[[1, 4], [1, 3], [1, 2], [2, 2], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[4, 7], [4, 6], [4, 5], [4, 4], [5, 4], [6, 4], [6, 3], [7, 3]],
        [[0, 4], [1, 4], [1, 3], [1, 2], [2, 2], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1], [6, 0]],
        [[4, 0], [4, 1], [4, 2], [3, 2], [3, 1], [3, 0], [2, 0], [1, 0], [1, 1], [0, 1]],
      ],
      stops: [[4, 2]],
    },
  },
  {
    id: "8-4",
    name: "Engine Shed",
    rows: ["........", "........", "........", "........", ".^^^^^^^", ".^^^^^^^", "...TT...", "........"],
    depots: [
      { at: [0, 1], dir: "E", trains: [0, 1], every: 3, start: 3 },
      { at: [7, 1], dir: "W", trains: [2], every: 3, start: 1 },
    ],
    stations: [{ at: [6, 7], dir: "N", color: 0 }, { at: [2, 0], dir: "S", color: 1 }, { at: [0, 3], dir: "E", color: 2 }],
    fixed: [[[1, 1], [2, 1], [2, 2], [3, 2], [4, 2], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6], [6, 6]]],
    tunnels: [[[5, 4], [5, 5]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[7, 1], [6, 1], [5, 1], [5, 2], [4, 2], [3, 2], [2, 2], [2, 3], [1, 3], [0, 3]],
        [[0, 1], [1, 1], [2, 1], [2, 0]],
        [[0, 1], [1, 1], [2, 1], [2, 2], [3, 2], [4, 2], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6], [6, 6], [6, 7]],
      ],
      stops: [[1, 1]],
      lamps: [[2, 1, 1]],
      levers: [[2, 2, "S"], [2, 1, "N"], [5, 2, "S"]],
    },
  },
  {
    id: "8-5",
    name: "Turntable",
    rows: ["HHH.....", "........", "........", "........", "........", "........", "........", "TTT....."],
    depots: [
      { at: [0, 6], dir: "E", trains: [0], every: 3, start: 0, goods: true },
      { at: [3, 0], dir: "S", trains: [1], every: 3, start: 1 },
      { at: [0, 4], dir: "E", trains: [1], every: 3, start: 0 },
    ],
    stations: [{ at: [6, 0], dir: "S", color: 0 }, { at: [4, 7], dir: "N", color: 1 }],
    fixed: [[[1, 6], [1, 5], [1, 4], [1, 3], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [6, 1]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[0, 6], [1, 6], [1, 5], [1, 4], [1, 3], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [6, 1], [6, 0]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6], [4, 6], [4, 7]],
        [[0, 4], [1, 4], [2, 4], [3, 4], [4, 4], [4, 5], [5, 5], [5, 6], [4, 6], [4, 7]],
      ],
      stops: [[3, 5]],
    },
  },
  {
    id: "8-6",
    name: "Goods Yard",
    rows: ["........", "......HH", ".......H", "........", "........", ".......H", "......HH", "........"],
    depots: [
      { at: [0, 4], dir: "E", trains: [0, 1, 2], every: 4, start: 0 },
      { at: [2, 0], dir: "S", trains: [0], every: 3, start: 1 },
    ],
    stations: [{ at: [5, 0], dir: "S", color: 0 }, { at: [0, 6], dir: "E", color: 1 }, { at: [3, 7], dir: "N", color: 2 }],
    fixed: [[[1, 4], [1, 5], [1, 6], [2, 6], [3, 6]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[0, 4], [1, 4], [1, 3], [1, 2], [2, 2], [2, 1], [3, 1], [4, 1], [5, 1], [5, 0]],
        [[2, 0], [2, 1], [3, 1], [4, 1], [5, 1], [5, 0]],
        [[0, 4], [1, 4], [1, 5], [1, 6], [2, 6], [3, 6], [3, 7]],
        [[0, 4], [1, 4], [1, 5], [1, 6], [0, 6]],
      ],
      lamps: [[1, 4, 0], [1, 6, 2]],
      levers: [[1, 4, "N"], [1, 6, "E"]],
    },
  },
  {
    id: "8-7",
    name: "Diamond Crossing",
    rows: ["........", "........", "........", "........", "........", "T.TT....", "...TT...", "....T..."],
    depots: [
      { at: [7, 1], dir: "W", trains: [0], every: 3, start: 3 },
      { at: [2, 0], dir: "S", trains: [1], every: 3, start: 0 },
      { at: [7, 3], dir: "W", trains: [2], every: 3, start: 1 },
      { at: [5, 0], dir: "S", trains: [0], every: 3, start: 3 },
    ],
    stations: [{ at: [6, 7], dir: "N", color: 0 }, { at: [7, 5], dir: "W", color: 1 }, { at: [0, 3], dir: "E", color: 2 }],
    fixed: [[[5, 1], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], [6, 6]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[5, 0], [5, 1], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], [6, 6], [6, 7]],
        [[7, 1], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], [6, 6], [6, 7]],
        [[2, 0], [2, 1], [2, 2], [3, 2], [3, 3], [3, 4], [4, 4], [5, 4], [5, 5], [6, 5], [7, 5]],
        [[7, 3], [6, 3], [5, 3], [4, 3], [3, 3], [2, 3], [1, 3], [0, 3]],
      ],
      stops: [[3, 2]],
    },
  },
  {
    id: "8-8",
    name: "Junction Rush",
    rows: ["........", "T.......", "TT......", "T.......", "........", "........", "........", "........", "........"],
    depots: [
      { at: [7, 2], dir: "W", trains: [0, 1], every: 4, start: 1 },
      { at: [0, 4], dir: "E", trains: [2], every: 3, start: 2 },
      { at: [5, 8], dir: "N", trains: [1, 2], every: 3, start: 3 },
    ],
    stations: [{ at: [6, 0], dir: "S", color: 0 }, { at: [7, 4], dir: "W", color: 1 }, { at: [1, 0], dir: "S", color: 2 }],
    fixed: [[[6, 2], [6, 3], [6, 4]]],
    allowStop: true,
    allowLamp: true,
    introTitle: "Junction rush",
    introText: "A busy junction with old track everywhere. Use what you can.",
    solution: {
      paths: [
        [[7, 2], [6, 2], [6, 1], [6, 0]],
        [[5, 8], [5, 7], [5, 6], [5, 5], [4, 5], [4, 4], [3, 4], [2, 4], [2, 3], [2, 2], [2, 1], [1, 1], [1, 0]],
        [[5, 8], [5, 7], [5, 6], [5, 5], [6, 5], [6, 4], [7, 4]],
        [[7, 2], [6, 2], [6, 3], [6, 4], [7, 4]],
        [[0, 4], [1, 4], [2, 4], [2, 3], [2, 2], [2, 1], [1, 1], [1, 0]],
      ],
      stops: [[5, 7]],
      lamps: [[6, 2, 0], [5, 5, 2]],
      levers: [[6, 2, "N"], [5, 5, "W"]],
    },
  },
];
