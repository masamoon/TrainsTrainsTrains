// Campaign levels. Colours: 0 rose, 1 teal, 2 violet, 3 tangerine.
// Each level carries a reference solution that the tests run through the simulator;
// par is that solution's track count.

import { HARBOUR_LINE } from "./lines/line03";
import { MARKET_LINE } from "./lines/line04";
import { MOOR_LINE } from "./lines/line05";
import { COAL_LINE } from "./lines/line06";
import { CLOCKWORK_LINE } from "./lines/line07";
import { JUNCTION_LINE } from "./lines/line08";
import { FESTIVAL_LINE } from "./lines/line09";
import { COAST_LINE } from "./lines/line10";
import { SUMMIT_LINE } from "./lines/line11";
import { NIGHT_MAIL } from "./lines/line12";
import { GRAND_TERMINUS } from "./lines/line13";
import { type LevelData, Puzzle } from "./puzzle";

export type Stop = LevelData & { id: string; name: string };

const BRANCH_LINE: Stop[] = [
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
    introTitle: "New: signal",
    introText:
      "Both trains reach the crossing on the same beat. Use Signal on a straight piece: a train waits there until the track ahead, up to the next signal, is clear. Each shaded stretch is one block.",
    solution: {
      paths: [
        [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3]],
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6]],
      ],
      stops: [[3, 1]],
      facing: [[3, 1, "S"]],
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
        [[0, 1], [1, 1], [1, 2], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3]],
        [[0, 5], [1, 5], [1, 4], [1, 3]],
      ],
      stops: [[1, 1]],
      facing: [[1, 1, "S"]],
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
        [[0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [6, 1], [7, 1]],
        [[6, 2], [6, 3], [6, 4], [6, 5], [7, 5]],
        [[4, 0], [4, 1], [4, 2], [4, 3], [4, 4], [4, 5], [4, 6], [4, 7]],
      ],
      stops: [[4, 1]],
      facing: [[4, 1, "S"]],
      lamps: [[6, 2, 2]],
      levers: [[6, 2, "S"]],
    },
  },
];

const VALLEY_LINE: Stop[] = [
  {
    id: "2-1",
    name: "Old Main Line",
    rows: ["TT.....", "T......", ".......", ".......", ".......", "......T", "~~...TT"],
    depots: [{ at: [0, 3], dir: "E", trains: [0, 1, 0], every: 3 }],
    stations: [
      { at: [6, 1], dir: "W", color: 0 },
      { at: [4, 6], dir: "N", color: 1 },
    ],
    fixed: [[[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [4, 2], [4, 1], [5, 1], [6, 1]]],
    allowStop: true,
    allowLamp: true,
    introTitle: "New: existing track",
    introText: "Shaded track is already laid. You can't erase it, but you can build onto it.",
    solution: { paths: [[[4, 3], [4, 4], [4, 5], [4, 6]]], lamps: [[4, 3, 0]], levers: [[4, 3, "N"]] },
  },
  {
    id: "2-2",
    name: "Passing Loop",
    rows: ["T.TTTT.T", "T.T..T.T", "T......T", "T.T..T.T", "T.TTTT.T"],
    depots: [
      { at: [1, 0], dir: "S", trains: [0] },
      { at: [6, 4], dir: "N", trains: [1] },
    ],
    stations: [
      { at: [6, 0], dir: "S", color: 0 },
      { at: [1, 4], dir: "N", color: 1 },
    ],
    introTitle: "Passing loop",
    introText: "Two trains, one line, opposite ways. Build a loop in the middle where they can pass.",
    solution: {
      paths: [
        [[1, 0], [1, 1], [1, 2], [2, 2], [3, 2], [3, 1], [4, 1], [4, 2], [5, 2], [6, 2], [6, 1], [6, 0]],
        [[6, 4], [6, 3], [6, 2], [5, 2], [4, 2], [4, 3], [3, 3], [3, 2], [2, 2], [1, 2], [1, 3], [1, 4]],
      ],
    },
  },
  {
    id: "2-3",
    name: "Under the Hill",
    rows: [".T.....", ".......", ".......", "^^^^^^.", "^^^^^^.", ".......", "T.....T"],
    depots: [{ at: [2, 0], dir: "S", trains: [0, 0], every: 3 }],
    stations: [{ at: [5, 6], dir: "N", color: 0 }],
    tunnels: [[[3, 3], [3, 4]]],
    allowStop: true,
    allowLamp: true,
    introTitle: "New: tunnel",
    introText: "The dashed line runs under the hills. Join track to both ends and trains go straight through.",
    solution: { paths: [[[2, 0], [2, 1], [2, 2], [3, 2], [3, 3], [3, 4], [3, 5], [4, 5], [5, 5], [5, 6]]] },
  },
  {
    id: "2-4",
    name: "Single Bore",
    rows: [".......", "..^^^..", "..^^^..", "..^^^..", "..^^^..", "..^^^..", "......."],
    depots: [
      { at: [0, 1], dir: "E", trains: [0] },
      { at: [6, 1], dir: "W", trains: [1], start: 4 },
    ],
    stations: [
      { at: [6, 5], dir: "W", color: 0 },
      { at: [0, 5], dir: "E", color: 1 },
    ],
    tunnels: [[[2, 3], [4, 3]]],
    allowStop: true,
    allowLamp: true,
    introTitle: "One way at a time",
    introText: "A tunnel has one track. Two trains meeting inside it crash.",
    solution: {
      paths: [
        [[0, 1], [1, 1], [1, 2], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [5, 4], [5, 5], [6, 5]],
        [[6, 1], [5, 1], [5, 2], [5, 3], [4, 3], [3, 3], [2, 3], [1, 3], [1, 4], [1, 5], [0, 5]],
      ],
      stops: [[5, 1]],
      facing: [[5, 1, "S"]],
      levers: [[5, 3, "S"]],
    },
  },
  {
    id: "2-5",
    name: "Slow Goods",
    rows: ["TT...TT", "T.....T", ".......", ".......", ".......", "T.....T", "TT...TT"],
    depots: [
      { at: [3, 0], dir: "S", trains: [1], goods: true },
      { at: [0, 3], dir: "E", trains: [0], start: 2 },
    ],
    stations: [
      { at: [6, 3], dir: "W", color: 0 },
      { at: [3, 6], dir: "N", color: 1 },
    ],
    allowStop: true,
    allowLamp: true,
    introTitle: "New: goods train",
    introText: "Goods trains are heavy and move every other beat, so they sit on a crossing for two beats.",
    solution: {
      paths: [
        [[3, 0], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [3, 6]],
        [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3]],
      ],
      stops: [[1, 3]],
      facing: [[1, 3, "E"]],
    },
  },
  {
      "id": "2-6",
      "name": "Waiting Room",
      "rows": [
        "TTTTTTTTT",
        "D.T...T.S",
        "T.......T",
        "S.TTTTT.D",
        "TTTTTTTTT"
      ],
      "depots": [
        {
          "at": [
            0,
            1
          ],
          "dir": "E",
          "trains": [
            0,
            0
          ],
          "start": 0,
          "every": 3
        },
        {
          "at": [
            8,
            3
          ],
          "dir": "W",
          "trains": [
            1,
            1
          ],
          "start": 3,
          "every": 3
        }
      ],
      "stations": [
        {
          "at": [
            8,
            1
          ],
          "dir": "W",
          "color": 0
        },
        {
          "at": [
            0,
            3
          ],
          "dir": "E",
          "color": 1
        }
      ],
      "allowStop": true,
      "allowLamp": true,
      "introTitle": "Which way it points",
      "introText": "A signal holds only trains heading the way its arrow points; trains the other way pass it. Tap a signal again to turn it round.",
      "solution": {
        "paths": [
          [
            [
              0,
              1
            ],
            [
              1,
              1
            ],
            [
              1,
              2
            ],
            [
              2,
              2
            ],
            [
              3,
              2
            ],
            [
              3,
              1
            ],
            [
              4,
              1
            ],
            [
              5,
              1
            ],
            [
              5,
              2
            ],
            [
              6,
              2
            ],
            [
              7,
              2
            ],
            [
              7,
              1
            ],
            [
              8,
              1
            ]
          ],
          [
            [
              8,
              3
            ],
            [
              7,
              3
            ],
            [
              7,
              2
            ],
            [
              6,
              2
            ],
            [
              5,
              2
            ],
            [
              4,
              2
            ],
            [
              3,
              2
            ],
            [
              2,
              2
            ],
            [
              1,
              2
            ],
            [
              1,
              3
            ],
            [
              0,
              3
            ]
          ]
        ],
        "stops": [
          [
            7,
            3
          ]
        ],
        "levers": [
          [
            1,
            2,
            "S"
          ],
          [
            3,
            2,
            "N"
          ],
          [
            5,
            2,
            "W"
          ],
          [
            7,
            2,
            "N"
          ]
        ],
        "stems": [
          [
            1,
            2,
            "E"
          ],
          [
            3,
            2,
            "W"
          ],
          [
            5,
            2,
            "E"
          ],
          [
            7,
            2,
            "W"
          ]
        ],
        "facing": [
          [
            7,
            3,
            "N"
          ]
        ]
      }
    },
    {
      "id": "2-7",
      "name": "Block Section",
      "deadline": 22,
      "rows": [
        "TTTTTTTTT",
        "D.T...T.S",
        "T.......T",
        "S.TTTTT.D",
        "TTTTTTTTT"
      ],
      "depots": [
        {
          "at": [
            0,
            1
          ],
          "dir": "E",
          "trains": [
            0,
            0
          ],
          "start": 0,
          "every": 3
        },
        {
          "at": [
            8,
            3
          ],
          "dir": "W",
          "trains": [
            1,
            1
          ],
          "start": 3,
          "every": 3
        }
      ],
      "stations": [
        {
          "at": [
            8,
            1
          ],
          "dir": "W",
          "color": 0
        },
        {
          "at": [
            0,
            3
          ],
          "dir": "E",
          "color": 1
        }
      ],
      "allowStop": true,
      "allowLamp": true,
      "introTitle": "New: timetable",
      "introText": "Everyone home by beat 22, so holding trains at the depot is too slow. Any signal ends a block for trains both ways, even one facing the other way.",
      "solution": {
        "paths": [
          [
            [
              0,
              1
            ],
            [
              1,
              1
            ],
            [
              1,
              2
            ],
            [
              2,
              2
            ],
            [
              3,
              2
            ],
            [
              3,
              1
            ],
            [
              4,
              1
            ],
            [
              5,
              1
            ],
            [
              5,
              2
            ],
            [
              6,
              2
            ],
            [
              7,
              2
            ],
            [
              7,
              1
            ],
            [
              8,
              1
            ]
          ],
          [
            [
              8,
              3
            ],
            [
              7,
              3
            ],
            [
              7,
              2
            ],
            [
              6,
              2
            ],
            [
              5,
              2
            ],
            [
              4,
              2
            ],
            [
              3,
              2
            ],
            [
              2,
              2
            ],
            [
              1,
              2
            ],
            [
              1,
              3
            ],
            [
              0,
              3
            ]
          ]
        ],
        "stops": [
          [
            5,
            1
          ],
          [
            4,
            2
          ]
        ],
        "facing": [
          [
            5,
            1,
            "S"
          ],
          [
            4,
            2,
            "E"
          ]
        ],
        "levers": [
          [
            1,
            2,
            "S"
          ],
          [
            3,
            2,
            "N"
          ],
          [
            5,
            2,
            "W"
          ],
          [
            7,
            2,
            "N"
          ]
        ],
        "stems": [
          [
            1,
            2,
            "E"
          ],
          [
            3,
            2,
            "W"
          ],
          [
            5,
            2,
            "E"
          ],
          [
            7,
            2,
            "W"
          ]
        ]
      }
    },
    {
      "id": "2-8",
      "name": "Two Sections",
      "deadline": 32,
      "rows": [
        "TTTTTTTTTTTTT",
        "D.T..TTT..T.S",
        "T...........T",
        "S.TTTTTTTTT.D",
        "TTTTTTTTTTTTT"
      ],
      "depots": [
        {
          "at": [
            0,
            1
          ],
          "dir": "E",
          "trains": [
            0,
            0
          ],
          "start": 0,
          "every": 3
        },
        {
          "at": [
            12,
            3
          ],
          "dir": "W",
          "trains": [
            1,
            1
          ],
          "start": 2,
          "every": 3
        }
      ],
      "stations": [
        {
          "at": [
            12,
            1
          ],
          "dir": "W",
          "color": 0
        },
        {
          "at": [
            0,
            3
          ],
          "dir": "E",
          "color": 1
        }
      ],
      "allowStop": true,
      "allowLamp": true,
      "introTitle": "Two sections",
      "introText": "A train waiting at a signal still fills the block behind it. Split the long line so trains can follow each other closely. Home by beat 32.",
      "solution": {
        "paths": [
          [
            [
              0,
              1
            ],
            [
              1,
              1
            ],
            [
              1,
              2
            ],
            [
              2,
              2
            ],
            [
              3,
              2
            ],
            [
              4,
              2
            ],
            [
              5,
              2
            ],
            [
              6,
              2
            ],
            [
              7,
              2
            ],
            [
              8,
              2
            ],
            [
              9,
              2
            ],
            [
              10,
              2
            ],
            [
              11,
              2
            ],
            [
              11,
              1
            ],
            [
              12,
              1
            ]
          ],
          [
            [
              12,
              3
            ],
            [
              11,
              3
            ],
            [
              11,
              2
            ],
            [
              10,
              2
            ],
            [
              9,
              2
            ],
            [
              9,
              1
            ],
            [
              8,
              1
            ],
            [
              8,
              2
            ],
            [
              7,
              2
            ],
            [
              6,
              2
            ],
            [
              5,
              2
            ],
            [
              4,
              2
            ],
            [
              3,
              2
            ],
            [
              2,
              2
            ],
            [
              1,
              2
            ],
            [
              1,
              3
            ],
            [
              0,
              3
            ]
          ]
        ],
        "stops": [
          [
            4,
            2
          ],
          [
            7,
            2
          ],
          [
            9,
            1
          ],
          [
            8,
            1
          ]
        ],
        "facing": [
          [
            4,
            2,
            "E"
          ],
          [
            7,
            2,
            "W"
          ],
          [
            8,
            1,
            "S"
          ]
        ],
        "levers": [
          [
            1,
            2,
            "S"
          ],
          [
            8,
            2,
            "E"
          ],
          [
            9,
            2,
            "N"
          ],
          [
            11,
            2,
            "N"
          ]
        ],
        "stems": [
          [
            1,
            2,
            "E"
          ],
          [
            8,
            2,
            "W"
          ],
          [
            9,
            2,
            "E"
          ],
          [
            11,
            2,
            "W"
          ]
        ]
      }
    },
];

// Block signals: a train at a signal waits until the track ahead, up to the next signals,
// is empty. Lines 3 on still use the old stop signal until they are rebuilt.
const block = (s: Stop): Stop => ({ ...s, signals: "block" });

// Lines run one after another on the map; stops unlock in order across them.
// Lines 3 on were found with the solver in tools/campaign, then picked by hand.
export const LINES: { name: string; color: number; stops: Stop[] }[] = [
  { name: "Branch Line", color: 0, stops: BRANCH_LINE.map(block) },
  { name: "Valley Line", color: 1, stops: VALLEY_LINE.map(block) },
  { name: "Harbour Line", color: 2, stops: HARBOUR_LINE },
  { name: "Market Line", color: 3, stops: MARKET_LINE },
  { name: "Moor Line", color: 1, stops: MOOR_LINE },
  { name: "Coal Line", color: 0, stops: COAL_LINE },
  { name: "Clockwork Line", color: 2, stops: CLOCKWORK_LINE },
  { name: "Junction Line", color: 3, stops: JUNCTION_LINE },
  { name: "Festival Line", color: 1, stops: FESTIVAL_LINE },
  { name: "Coast Line", color: 2, stops: COAST_LINE },
  { name: "Summit Line", color: 0, stops: SUMMIT_LINE },
  { name: "Night Mail", color: 3, stops: NIGHT_MAIL },
  { name: "Grand Terminus", color: 1, stops: GRAND_TERMINUS },
];

// The first stops are free to play; the rest will be sold later. Nothing is gated yet:
// `free` only marks where the line will fall.
export const FREE_STOPS = 20;

// While the campaign is being tested every stop can be played in any order. Set to false
// to have stops unlock one after another again.
export const ALL_OPEN = true;

export const isOpen = (index: number, reached: number): boolean => ALL_OPEN || index <= reached;

export const LEVELS: (Stop & { line: number; stop: number; free: boolean })[] = LINES.flatMap((ln, line) =>
  ln.stops.map((lv, stop) => ({ ...lv, line, stop })),
).map((lv, i) => ({ ...lv, free: i < FREE_STOPS }));

export const loadLevel = (index: number): Puzzle => Puzzle.fromData(LEVELS[index]);
