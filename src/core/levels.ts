// Campaign levels. Colours: 0 rose, 1 teal, 2 violet, 3 tangerine.
// Each level carries a reference solution that the tests run through the simulator;
// par is that solution's track count.

import { type LevelData, Puzzle } from "./puzzle";

export const LINE_NAME = "Branch Line";

export const LEVELS: (LevelData & { id: string; name: string })[] = [
  {
    id: "1-1",
    name: "First Light",
    rows: ["....T", ".....", ".....", ".....", "T...."],
    depots: [{ at: [0, 1], dir: "E", trains: [0] }],
    stations: [{ at: [4, 3], dir: "W", color: 0 }],
    introTitle: "Draw the line",
    introText: "Drag from the depot to the platform to lay track, then press Depart.",
    solution: { paths: [[[0, 1], [1, 1], [2, 1], [2, 2], [2, 3], [3, 3], [4, 3]]] },
  },
  {
    id: "1-2",
    name: "Round the Pond",
    rows: ["......", "..~~..", "..~~..", "..~~..", "......", "T....T"],
    depots: [{ at: [0, 2], dir: "E", trains: [0, 0], every: 3 }],
    stations: [{ at: [5, 2], dir: "W", color: 0 }],
    introTitle: "Go around",
    introText: "Track can't cross woods, water or town. Fewer pieces earn more stars.",
    solution: { paths: [[[0, 2], [1, 2], [1, 1], [1, 0], [2, 0], [3, 0], [4, 0], [4, 1], [4, 2], [5, 2]]] },
  },
  {
    id: "1-3",
    name: "Two Lines",
    rows: ["T.....", "......", "..TT..", "..TT..", "......", ".....H"],
    depots: [
      { at: [0, 2], dir: "E", trains: [0] },
      { at: [0, 3], dir: "E", trains: [1] },
    ],
    stations: [
      { at: [5, 2], dir: "W", color: 0 },
      { at: [5, 3], dir: "W", color: 1 },
    ],
    introTitle: "Match the colours",
    introText: "Each train must reach the platform with its own colour and shape.",
    solution: {
      paths: [
        [[0, 2], [1, 2], [1, 1], [2, 1], [3, 1], [4, 1], [4, 2], [5, 2]],
        [[0, 3], [1, 3], [1, 4], [2, 4], [3, 4], [4, 4], [4, 3], [5, 3]],
      ],
    },
  },
  {
    id: "1-4",
    name: "The Crossing",
    rows: [".....TT", "......T", ".......", ".......", ".......", ".~.....", ".~~....", "H......"],
    depots: [
      { at: [0, 2], dir: "E", trains: [0] },
      { at: [3, 0], dir: "S", trains: [1] },
    ],
    stations: [
      { at: [6, 5], dir: "W", color: 0 },
      { at: [3, 7], dir: "N", color: 1 },
    ],
    introTitle: "New: crossing",
    introText: "Draw one line straight over another to make a crossing. Two trains on it at once will crash.",
    solution: {
      paths: [
        [[0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [5, 3], [5, 4], [5, 5], [6, 5]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6], [3, 7]],
      ],
    },
  },
  {
    id: "1-5",
    name: "Hold the Line",
    rows: ["TT...TT", "T.....T", ".......", ".......", ".......", "T.....T", "TT...TT"],
    depots: [
      { at: [0, 3], dir: "E", trains: [0] },
      { at: [3, 0], dir: "S", trains: [1] },
    ],
    stations: [
      { at: [6, 3], dir: "W", color: 0 },
      { at: [3, 6], dir: "N", color: 1 },
    ],
    allowStop: true,
    introTitle: "New: stop signal",
    introText:
      "Both trains reach the crossing on the same beat. Use Signal on a straight piece: a train holds there for two beats.",
    solution: {
      paths: [
        [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6]],
      ],
      stops: [[3, 1]],
    },
  },
  {
    id: "1-6",
    name: "Junction",
    rows: [".....TT", "......T", ".......", ".......", ".......", "......~", "....~~~"],
    depots: [
      { at: [0, 1], dir: "E", trains: [0] },
      { at: [0, 5], dir: "E", trains: [0, 0], every: 3 },
    ],
    stations: [{ at: [6, 3], dir: "W", color: 0 }],
    allowStop: true,
    introTitle: "New: switch",
    introText: "Join three sides of a piece to make a switch. Trains from either branch merge onto the stem.",
    solution: {
      paths: [
        [[0, 1], [1, 1], [2, 1], [3, 1], [3, 2], [3, 3], [4, 3], [5, 3], [6, 3]],
        [[0, 5], [1, 5], [2, 5], [3, 5], [3, 4], [3, 3]],
      ],
      stops: [[2, 1]],
    },
  },
  {
    id: "1-7",
    name: "Sorting Office",
    rows: ["TT.....", "T......", ".......", ".......", ".......", "T......", "TT...~~"],
    depots: [{ at: [0, 3], dir: "E", trains: [0, 1, 0], every: 3 }],
    stations: [
      { at: [6, 1], dir: "W", color: 0 },
      { at: [6, 5], dir: "W", color: 1 },
    ],
    allowStop: true,
    allowLamp: true,
    introTitle: "New: colour signal",
    introText:
      "Tap a switch to flip its lever. Use Signal on a switch to add a lamp: trains of that colour follow the lever, all others take the other branch.",
    solution: {
      paths: [
        [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [5, 2], [5, 1], [6, 1]],
        [[5, 3], [5, 4], [5, 5], [6, 5]],
      ],
      lamps: [[5, 3, 0]],
      levers: [[5, 3, "N"]],
    },
  },
  {
    id: "1-8",
    name: "Rush Hour",
    rows: ["TT......", "T.......", "........", "~~......", "~~~.....", "~~......", "......TT", "HH....TT"],
    depots: [
      { at: [0, 2], dir: "E", trains: [0, 2, 0], every: 4 },
      { at: [4, 0], dir: "S", trains: [1, 1], every: 4, start: 2 },
    ],
    stations: [
      { at: [7, 1], dir: "W", color: 0 },
      { at: [7, 5], dir: "W", color: 2 },
      { at: [4, 7], dir: "N", color: 1 },
    ],
    allowStop: true,
    allowLamp: true,
    introTitle: "Rush hour",
    introText: "Everything at once. Sort the western trains and keep the northern line clear of them.",
    solution: {
      paths: [
        [[0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [5, 1], [6, 1], [7, 1]],
        [[5, 2], [5, 3], [5, 4], [5, 5], [6, 5], [7, 5]],
        [[4, 0], [4, 1], [4, 2], [4, 3], [4, 4], [4, 5], [4, 6], [4, 7]],
      ],
      stops: [[4, 1]],
      lamps: [[5, 2, 2]],
      levers: [[5, 2, "S"]],
    },
  },
];

export const loadLevel = (index: number): Puzzle => Puzzle.fromData(LEVELS[index]);
