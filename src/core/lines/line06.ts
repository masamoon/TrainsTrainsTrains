// Line 6, Coal Line. Generated with tools/campaign and curated by hand.

import type { Stop } from "../levels";

export const COAL_LINE: Stop[] = [
  {
    id: "6-1",
    name: "Slow Train Coming",
    rows: [".......", ".......", ".......", ".......", "~......", "T.~~~..", "...~~.."],
    depots: [
      { at: [6, 1], dir: "W", trains: [0], every: 3, start: 3, goods: true },
      { at: [2, 0], dir: "S", trains: [1], every: 3, start: 0 },
    ],
    stations: [{ at: [6, 3], dir: "W", color: 0 }, { at: [5, 6], dir: "N", color: 1 }],
    allowStop: true,
    allowLamp: true,
    introTitle: "Stuck behind",
    introText: "Trains can't overtake. A passenger train behind a goods train has to go at its pace.",
    solution: {
      paths: [
        [[6, 1], [5, 1], [5, 2], [5, 3], [6, 3]],
        [[2, 0], [2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [4, 3], [4, 4], [5, 4], [5, 5], [5, 6]],
      ],
      stops: [[3, 1]],
      lamps: [[5, 3, 0]],
      levers: [[5, 3, "E"]],
    },
  },
  {
    id: "6-2",
    name: "Coal Drop",
    rows: ["TT.....", "TTT....", ".......", ".~.....", ".....~.", ".......", "....TTT", ".....TT"],
    depots: [
      { at: [0, 6], dir: "E", trains: [0, 1], every: 4, start: 0, goods: true },
      { at: [3, 7], dir: "N", trains: [2], every: 3, start: 2 },
    ],
    stations: [{ at: [6, 1], dir: "W", color: 0 }, { at: [0, 2], dir: "E", color: 1 }, { at: [0, 4], dir: "E", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[0, 6], [1, 6], [1, 5], [1, 4], [2, 4], [2, 3], [2, 2], [3, 2], [4, 2], [5, 2], [5, 1], [6, 1]],
        [[0, 6], [1, 6], [1, 5], [1, 4], [2, 4], [2, 3], [2, 2], [1, 2], [0, 2]],
        [[3, 7], [3, 6], [2, 6], [1, 6], [1, 5], [1, 4], [0, 4]],
      ],
      stops: [[3, 6]],
      lamps: [[1, 4, 2], [2, 2, 0]],
      levers: [[1, 4, "W"], [2, 2, "E"]],
    },
  },
  {
    id: "6-3",
    name: "Pit Head",
    rows: ["........", "........", "........", ".TT.....", "........", "TT......", ".TT.....", ".H......"],
    depots: [
      { at: [7, 2], dir: "W", trains: [0], every: 3, start: 1, goods: true },
      { at: [3, 0], dir: "S", trains: [1], every: 3, start: 2 },
      { at: [1, 0], dir: "S", trains: [2], every: 3, start: 0 },
    ],
    stations: [{ at: [6, 0], dir: "S", color: 0 }, { at: [7, 4], dir: "W", color: 1 }, { at: [6, 7], dir: "N", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[7, 2], [6, 2], [6, 1], [6, 0]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [4, 4], [5, 4], [6, 4], [7, 4]],
        [[1, 0], [1, 1], [2, 1], [3, 1], [4, 1], [4, 2], [4, 3], [5, 3], [5, 4], [5, 5], [5, 6], [6, 6], [6, 7]],
      ],
      stops: [[1, 1]],
    },
  },
  {
    id: "6-4",
    name: "Coke Ovens",
    rows: ["...TT...", "........", "........", "........", "...^^^^T", "...^^^^.", "........", "........"],
    depots: [
      { at: [0, 3], dir: "E", trains: [0], every: 3, start: 1, goods: true },
      { at: [7, 1], dir: "W", trains: [1, 0], every: 3, start: 0 },
    ],
    stations: [{ at: [6, 7], dir: "N", color: 0 }, { at: [1, 0], dir: "S", color: 1 }],
    tunnels: [[[4, 4], [4, 5]]],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [4, 4], [4, 5], [4, 6], [5, 6], [6, 6], [6, 7]],
        [[7, 1], [6, 1], [6, 0], [5, 0], [5, 1], [4, 1], [3, 1], [2, 1], [1, 1], [1, 0]],
        [[7, 1], [6, 1], [6, 2], [5, 2], [5, 3], [4, 3], [4, 4], [4, 5], [4, 6], [5, 6], [6, 6], [6, 7]],
      ],
      stops: [[3, 3]],
      lamps: [[6, 1, 1]],
      levers: [[6, 1, "N"]],
    },
  },
  {
    id: "6-5",
    name: "Wagon Way",
    rows: ["T.TTTTT.T", ".....T...", ".........", "......T..", "T.TT.TT.T"],
    depots: [
      { at: [1, 0], dir: "S", trains: [0], every: 3, start: 0, goods: true },
      { at: [7, 0], dir: "S", trains: [1, 1], every: 4, start: 3 },
    ],
    stations: [{ at: [8, 3], dir: "W", color: 0 }, { at: [1, 4], dir: "N", color: 1 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[1, 0], [1, 1], [2, 1], [3, 1], [4, 1], [4, 2], [5, 2], [6, 2], [7, 2], [7, 3], [8, 3]],
        [[7, 0], [7, 1], [7, 2], [6, 2], [5, 2], [4, 2], [4, 3], [3, 3], [2, 3], [1, 3], [1, 4]],
      ],
      stops: [[1, 1], [2, 1]],
      levers: [[7, 2, "S"], [4, 2, "S"]],
    },
  },
  {
    id: "6-6",
    name: "Two Goods",
    rows: [".T....T.", "HH....HH", ".H....H.", ".T....T.", "...HH...", "...HH...", "........", "........"],
    depots: [
      { at: [3, 0], dir: "S", trains: [0], every: 3, start: 2, goods: true },
      { at: [2, 7], dir: "N", trains: [1], every: 3, start: 2, goods: true },
      { at: [0, 6], dir: "E", trains: [2], every: 3, start: 1 },
    ],
    stations: [{ at: [5, 0], dir: "S", color: 0 }, { at: [7, 6], dir: "W", color: 1 }, { at: [5, 7], dir: "N", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[3, 0], [3, 1], [4, 1], [5, 1], [5, 0]],
        [[0, 6], [1, 6], [2, 6], [3, 6], [4, 6], [5, 6], [5, 7]],
        [[2, 7], [2, 6], [2, 5], [2, 4], [2, 3], [3, 3], [4, 3], [5, 3], [5, 4], [5, 5], [6, 5], [6, 6], [7, 6]],
      ],
      stops: [[1, 6]],
    },
  },
  {
    id: "6-7",
    name: "Slag Heap",
    rows: [".H......", ".H......", "...~~...", "....~...", "........", "........", "........", "........"],
    depots: [
      { at: [7, 1], dir: "W", trains: [0, 1], every: 3, start: 1, goods: true },
      { at: [3, 7], dir: "N", trains: [1, 2], every: 3, start: 2 },
    ],
    stations: [{ at: [3, 0], dir: "S", color: 0 }, { at: [7, 3], dir: "W", color: 1 }, { at: [5, 7], dir: "N", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[7, 1], [6, 1], [6, 0], [5, 0], [5, 1], [4, 1], [3, 1], [3, 0]],
        [[3, 7], [3, 6], [4, 6], [5, 6], [5, 5], [6, 5], [6, 4], [6, 3], [7, 3]],
        [[3, 7], [3, 6], [4, 6], [5, 6], [5, 7]],
        [[7, 1], [6, 1], [6, 2], [6, 3], [7, 3]],
      ],
      stops: [[6, 4]],
      lamps: [[6, 1, 0], [5, 6, 1]],
      levers: [[6, 1, "N"], [5, 6, "N"]],
    },
  },
  {
    id: "6-8",
    name: "Coal Rush",
    rows: ["........", "........", "~~....~~", "........", "........", "........", "........", "..T..T..", "..T..T.."],
    depots: [
      { at: [0, 4], dir: "E", trains: [0], every: 3, start: 2, goods: true },
      { at: [5, 0], dir: "S", trains: [2], every: 3, start: 2, goods: true },
      { at: [0, 6], dir: "E", trains: [1, 0, 1], every: 3, start: 3 },
    ],
    stations: [{ at: [7, 3], dir: "W", color: 0 }, { at: [4, 8], dir: "N", color: 1 }, { at: [0, 1], dir: "E", color: 2 }],
    allowStop: true,
    allowLamp: true,
    introTitle: "Coal rush",
    introText: "Two goods trains and the passenger service, all through the same yard.",
    solution: {
      paths: [
        [[0, 6], [1, 6], [1, 5], [2, 5], [3, 5], [4, 5], [4, 4], [4, 3], [5, 3], [6, 3], [7, 3]],
        [[0, 4], [1, 4], [1, 5], [2, 5], [3, 5], [4, 5], [4, 4], [4, 3], [5, 3], [6, 3], [7, 3]],
        [[0, 6], [1, 6], [1, 5], [2, 5], [3, 5], [4, 5], [4, 6], [4, 7], [4, 8]],
        [[5, 0], [5, 1], [4, 1], [3, 1], [2, 1], [1, 1], [0, 1]],
      ],
      stops: [[1, 4]],
      lamps: [[4, 5, 0]],
      levers: [[4, 5, "N"]],
    },
  },
];
