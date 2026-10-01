// Line 3, Harbour Line. Generated with tools/campaign and curated by hand.

import type { Stop } from "../levels";

export const HARBOUR_LINE: Stop[] = [
  {
    id: "3-1",
    name: "Double Hold",
    rows: ["....TTT", ".....TT", "....TT.", "...~...", "....TT.", ".....TT", "....TTT"],
    depots: [
      { at: [2, 0], dir: "S", trains: [0], every: 3, start: 1 },
      { at: [3, 6], dir: "N", trains: [1], every: 3, start: 0 },
    ],
    stations: [{ at: [0, 4], dir: "E", color: 0 }, { at: [0, 1], dir: "E", color: 1 }],
    allowStop: true,
    allowLamp: true,
    introTitle: "Signals add up",
    introText: "One stop signal holds a train for two beats. Two on the same line hold it for four.",
    solution: {
      paths: [
        [[2, 0], [2, 1], [1, 1], [1, 2], [1, 3], [1, 4], [0, 4]],
        [[3, 6], [3, 5], [3, 4], [2, 4], [1, 4], [1, 3], [1, 2], [1, 1], [0, 1]],
      ],
      stops: [[2, 4], [3, 5]],
      levers: [[1, 4, "W"], [1, 1, "W"]],
    },
  },
  {
    id: "3-2",
    name: "Ferry Crossing",
    rows: [".......", ".......", ".......", ".TT....", ".......", "~~.....", ".~~....", ".~....."],
    depots: [
      { at: [6, 2], dir: "W", trains: [0], every: 3, start: 1 },
      { at: [3, 0], dir: "S", trains: [1], every: 3, start: 2 },
      { at: [1, 0], dir: "S", trains: [2], every: 3, start: 0 },
    ],
    stations: [{ at: [5, 0], dir: "S", color: 0 }, { at: [6, 4], dir: "W", color: 1 }, { at: [5, 7], dir: "N", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[6, 2], [5, 2], [5, 1], [5, 0]],
        [[1, 0], [1, 1], [1, 2], [2, 2], [3, 2], [4, 2], [4, 3], [5, 3], [5, 4], [5, 5], [5, 6], [5, 7]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [4, 4], [5, 4], [6, 4]],
      ],
      stops: [[1, 2]],
    },
  },
  {
    id: "3-3",
    name: "Shared Berth",
    rows: [".......", ".....~.", "....~~.", ".......", ".......", ".......", ".....~.", ".....~~"],
    depots: [
      { at: [1, 7], dir: "N", trains: [0], every: 3, start: 0 },
      { at: [6, 5], dir: "W", trains: [1], every: 3, start: 1 },
    ],
    stations: [{ at: [6, 3], dir: "W", color: 0 }, { at: [0, 4], dir: "E", color: 1 }],
    allowStop: true,
    allowLamp: true,
    introTitle: "Share the line",
    introText: "Two lines can share track: merge them at a switch, then sort them apart with a colour signal. It saves track.",
    solution: {
      paths: [
        [[1, 7], [1, 6], [1, 5], [2, 5], [2, 4], [3, 4], [3, 3], [4, 3], [5, 3], [6, 3]],
        [[6, 5], [5, 5], [4, 5], [3, 5], [2, 5], [2, 4], [1, 4], [0, 4]],
      ],
      lamps: [[2, 4, 0]],
      levers: [[2, 4, "E"]],
    },
  },
  {
    id: "3-4",
    name: "Quayside",
    rows: [".......", "..TTT..", ".......", "~.....~", ".......", ".......", ".......", "~.....~"],
    depots: [
      { at: [4, 7], dir: "N", trains: [0, 1, 0], every: 4, start: 0 },
      { at: [6, 1], dir: "W", trains: [2], every: 3, start: 2 },
    ],
    stations: [{ at: [6, 6], dir: "W", color: 0 }, { at: [0, 1], dir: "E", color: 1 }, { at: [0, 6], dir: "E", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[4, 7], [4, 6], [3, 6], [3, 5], [3, 4], [3, 3], [3, 2], [2, 2], [1, 2], [1, 1], [0, 1]],
        [[6, 1], [5, 1], [5, 2], [4, 2], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6], [2, 6], [1, 6], [0, 6]],
        [[4, 7], [4, 6], [5, 6], [6, 6]],
      ],
      stops: [[4, 2], [5, 1], [5, 2]],
      lamps: [[4, 6, 1]],
      levers: [[4, 6, "W"], [3, 2, "W"], [3, 6, "W"]],
    },
  },
  {
    id: "3-5",
    name: "Pier Queue",
    rows: ["~~...~.", ".~.....", "...~.~.", ".....~.", ".~.....", ".~.~...", ".....~.", ".~...~~"],
    depots: [
      { at: [4, 7], dir: "N", trains: [0, 0, 0], every: 2, start: 0 },
      { at: [2, 7], dir: "N", trains: [1], every: 3, start: 0 },
    ],
    stations: [{ at: [2, 0], dir: "S", color: 0 }, { at: [6, 1], dir: "W", color: 1 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[2, 7], [2, 6], [2, 5], [2, 4], [3, 4], [4, 4], [4, 3], [4, 2], [4, 1], [5, 1], [6, 1]],
        [[4, 7], [4, 6], [4, 5], [4, 4], [3, 4], [2, 4], [2, 3], [2, 2], [2, 1], [2, 0]],
      ],
      stops: [[4, 6], [4, 5]],
      levers: [[4, 4, "N"], [2, 4, "N"]],
    },
  },
  {
    id: "3-6",
    name: "Lighthouse",
    rows: ["........", "......~~", "........", "....~...", "....~...", "......~.", ".~......", "........"],
    depots: [
      { at: [2, 0], dir: "S", trains: [0], every: 3, start: 0 },
      { at: [4, 7], dir: "N", trains: [0], every: 3, start: 3 },
      { at: [7, 6], dir: "W", trains: [1], every: 3, start: 2 },
    ],
    stations: [{ at: [7, 4], dir: "W", color: 0 }, { at: [0, 4], dir: "E", color: 1 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[4, 7], [4, 6], [4, 5], [5, 5], [5, 4], [6, 4], [7, 4]],
        [[2, 0], [2, 1], [2, 2], [3, 2], [4, 2], [5, 2], [5, 3], [5, 4], [6, 4], [7, 4]],
        [[7, 6], [6, 6], [5, 6], [4, 6], [3, 6], [2, 6], [2, 5], [2, 4], [1, 4], [0, 4]],
      ],
      stops: [[2, 2]],
    },
  },
  {
    id: "3-7",
    name: "Tide Table",
    rows: ["........", "........", "T.......", "T.....~~", "......~.", "........", ".~......", "~~...~.."],
    depots: [
      { at: [2, 0], dir: "S", trains: [0, 1], every: 4, start: 3 },
      { at: [7, 1], dir: "W", trains: [2, 1], every: 4, start: 2 },
    ],
    stations: [{ at: [0, 5], dir: "E", color: 0 }, { at: [4, 7], dir: "N", color: 1 }, { at: [7, 6], dir: "W", color: 2 }],
    allowStop: true,
    allowLamp: true,
    solution: {
      paths: [
        [[7, 1], [6, 1], [5, 1], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6], [4, 6], [4, 7]],
        [[2, 0], [2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6], [4, 6], [4, 7]],
        [[2, 0], [2, 1], [1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [0, 5]],
        [[7, 1], [6, 1], [5, 1], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6], [6, 6], [7, 6]],
      ],
      lamps: [[5, 6, 1], [2, 1, 1]],
      levers: [[5, 6, "W"], [2, 1, "E"]],
    },
  },
  {
    id: "3-8",
    name: "Harbour Rush",
    rows: ["........", "........", ".....TT.", "..~~....", "....~~..", ".TT.....", "........", "........"],
    depots: [
      { at: [7, 5], dir: "W", trains: [0, 2, 0], every: 3, start: 3 },
      { at: [3, 0], dir: "S", trains: [1, 1], every: 4, start: 2 },
      { at: [0, 4], dir: "E", trains: [2], every: 3, start: 1 },
    ],
    stations: [{ at: [5, 7], dir: "N", color: 0 }, { at: [0, 2], dir: "E", color: 1 }, { at: [5, 0], dir: "S", color: 2 }],
    allowStop: true,
    allowLamp: true,
    introTitle: "Harbour rush",
    introText: "Three depots, three platforms and one crowded quay.",
    solution: {
      paths: [
        [[0, 4], [1, 4], [1, 3], [1, 2], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [5, 0]],
        [[7, 5], [6, 5], [6, 4], [7, 4], [7, 3], [7, 2], [7, 1], [6, 1], [5, 1], [5, 0]],
        [[3, 0], [3, 1], [3, 2], [2, 2], [1, 2], [0, 2]],
        [[7, 5], [6, 5], [6, 6], [5, 6], [5, 7]],
      ],
      stops: [[1, 1]],
      lamps: [[6, 5, 2]],
      levers: [[6, 5, "N"]],
    },
  },
];
