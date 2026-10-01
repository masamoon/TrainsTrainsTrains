import { describe, expect, it } from "vitest";
import { FLOOR_FROM, dateLabel, generate, meetsFloor, today } from "../src/core/daily";
import { Layout } from "../src/core/layout";
import { FREE_STOPS, LEVELS, loadLevel } from "../src/core/levels";
import { type LevelData, Puzzle, W, cell, edgeCells } from "../src/core/puzzle";
import { Save, shareText } from "../src/core/save";
import { run } from "../src/core/sim";

function puzzle(rows: string[], depots: LevelData["depots"], stations: LevelData["stations"], extra: Partial<LevelData> = {}): Puzzle {
  return Puzzle.fromData({ rows, depots, stations, par: 1, ...extra });
}

function draw(pz: Puzzle, lay: Layout, cells: [number, number][]): void {
  for (let i = 0; i < cells.length - 1; i++) {
    lay.connect(pz, cell(...cells[i]), cell(...cells[i + 1]));
  }
}

describe("rules", () => {
  it("delivers a train along a straight line and counts pieces", () => {
    const pz = puzzle(["....."], [{ at: [0, 0], dir: "E", trains: [0] }], [{ at: [4, 0], dir: "W", color: 0 }]);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0]]);
    expect(lay.trackCount(pz)).toBe(3);
    expect(run(pz, lay).success).toBe(true);
  });

  it("derails at a gap", () => {
    const pz = puzzle(["....."], [{ at: [0, 0], dir: "E", trains: [0] }], [{ at: [4, 0], dir: "W", color: 0 }]);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0]]);
    const res = run(pz, lay);
    expect(res.success).toBe(false);
    expect(res.outcomes[0].result).toBe("crashed");
  });

  it("flags a wrong platform", () => {
    const pz = puzzle(["....."], [{ at: [0, 0], dir: "E", trains: [1] }], [{ at: [4, 0], dir: "W", color: 0 }]);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0]]);
    expect(run(pz, lay).outcomes[0].result).toBe("wrong");
  });

  it("crashes head-on trains", () => {
    const pz = puzzle(
      [".....", "....."],
      [
        { at: [0, 0], dir: "E", trains: [0] },
        { at: [4, 0], dir: "W", trains: [1] },
      ],
      [
        { at: [0, 1], dir: "E", color: 1 },
        { at: [4, 1], dir: "W", color: 0 },
      ],
    );
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0]]);
    expect(run(pz, lay).success).toBe(false);
  });

  it("uses the odd side out as a switch stem and sorts by colour lamp", () => {
    const pz = puzzle(
      [".....", ".....", "....."],
      [{ at: [0, 1], dir: "E", trains: [0, 1], every: 3 }],
      [
        { at: [4, 0], dir: "W", color: 0 },
        { at: [4, 2], dir: "W", color: 1 },
      ],
    );
    const lay = new Layout();
    draw(pz, lay, [[1, 1], [2, 1], [3, 1], [3, 0]]);
    draw(pz, lay, [[3, 1], [3, 2]]);
    expect(Layout.switchStem(lay.dirsAt(pz, cell(3, 1)))).toBe(W);
    lay.levers.set("3,1", 0);
    expect(run(pz, lay).success).toBe(false);
    lay.lamps.set("3,1", 0);
    expect(run(pz, lay).success).toBe(true);
  });

  it("ends a loop early instead of running forever", () => {
    const pz = puzzle(["....", "....", "...."], [{ at: [0, 0], dir: "E", trains: [0] }], [{ at: [3, 2], dir: "N", color: 0 }]);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [2, 1], [1, 1], [1, 0]]);
    const res = run(pz, lay);
    expect(res.success).toBe(false);
    expect(res.beats).toBeLessThan(30);
  });

  it("queues a train behind one held at a stop signal", () => {
    const pz = puzzle(["......"], [{ at: [0, 0], dir: "E", trains: [0, 0], every: 1 }], [{ at: [5, 0], dir: "W", color: 0 }]);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0], [4, 0]]);
    lay.stops.add("3,0");
    expect(run(pz, lay).success).toBe(true);
    const copy = Layout.fromData(JSON.parse(JSON.stringify(lay.toData())));
    expect(copy.edges.size).toBe(lay.edges.size);
    expect(copy.stops.size).toBe(1);
  });
});

describe("tunnels, existing track and goods trains", () => {
  // A ridge of hills with a tunnel through the middle row.
  const ridge = (depots: LevelData["depots"]) =>
    puzzle([".......", "..^^^..", "......."], depots, [{ at: [6, 1], dir: "W", color: 0 }], { tunnels: [[[2, 1], [4, 1]]] });

  it("runs trains straight through a tunnel", () => {
    const pz = ridge([{ at: [0, 1], dir: "E", trains: [0, 0] }]);
    // Depot and platform sit right outside the mouths, so no track is needed.
    const res = run(pz, new Layout());
    expect(res.success).toBe(true);
    expect(res.frames.some((f) => f.some((t) => pz.inTunnel(t.pos)))).toBe(true);
  });

  it("won't take track on tunnel cells and crashes trains meeting inside", () => {
    const pz = ridge([
      { at: [0, 1], dir: "E", trains: [0] },
      { at: [5, 0], dir: "S", trains: [1] },
    ]);
    const lay = new Layout();
    expect(lay.connect(pz, cell(2, 1), cell(2, 0))).toBe(false);
    // The teal train comes down beside the east mouth and is switched west into the tunnel.
    lay.levers.set("5,1", W);
    const res = run(pz, lay);
    const crash = res.events.find((e) => e.kind === "crash");
    expect(crash && pz.inTunnel(crash.pos)).toBe(true);
  });

  it("rejects a tunnel that isn't under blocked ground", () => {
    expect(() => puzzle(["....."], [], [], { tunnels: [[[1, 0], [3, 0]]] })).toThrow();
  });

  it("moves goods trains every other beat", () => {
    const line = (goods: boolean) => puzzle(["......"], [{ at: [0, 0], dir: "E", trains: [0], goods }], [{ at: [5, 0], dir: "W", color: 0 }]);
    const fast = line(false);
    const slow = line(true);
    const lay = new Layout();
    draw(fast, lay, [[1, 0], [2, 0], [3, 0], [4, 0]]);
    expect(run(fast, lay).beats).toBe(5);
    const res = run(slow, lay);
    expect(res.success).toBe(true);
    expect(res.beats).toBe(9);
  });

  it("builds onto existing track without counting or erasing it", () => {
    const pz = puzzle(
      [".....", "....."],
      [{ at: [0, 0], dir: "E", trains: [0] }],
      [{ at: [4, 1], dir: "W", color: 0 }],
      { fixed: [[[0, 0], [1, 0], [2, 0]]] },
    );
    const lay = new Layout();
    draw(pz, lay, [[2, 0], [3, 0], [3, 1]]);
    expect(lay.trackCount(pz)).toBe(3); // (2,0) gained a piece; (1,0) is untouched
    expect(lay.clearCell(pz, cell(1, 0))).toBe(false);
    expect(lay.dirsAt(pz, cell(1, 0)).length).toBe(2);
    expect(run(pz, lay).success).toBe(true);
  });
});

describe("timed platforms", () => {
  const line = (opens: number) => puzzle(["......"], [{ at: [0, 0], dir: "E", trains: [0] }], [{ at: [5, 0], dir: "W", color: 0, opens }], { allowStop: true });

  it("turns away a train that arrives before the platform opens", () => {
    const pz = line(7);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0], [4, 0]]);
    const res = run(pz, lay);
    expect(res.outcomes[0].result).toBe("wrong");
    expect(res.events[0].kind).toBe("early");
    lay.stops.add("2,0");
    expect(run(pz, lay).success).toBe(true);
  });

  it("accepts a train arriving on the opening beat", () => {
    const pz = line(5);
    const lay = new Layout();
    draw(pz, lay, [[1, 0], [2, 0], [3, 0], [4, 0]]);
    expect(run(pz, lay).success).toBe(true);
  });
});

describe("campaign", () => {
  LEVELS.forEach((data, i) => {
    it(`${data.id} ${data.name}: reference solution solves for three stars`, () => {
      const pz = loadLevel(i);
      const lay = pz.solutionLayout();
      // Every piece of the reference solution is one a player could draw.
      for (const key of lay.edges) for (const c of edgeCells(key)) expect(pz.buildable(c), `${data.id} ${key}`).toBe(true);
      const res = run(pz, lay);
      expect(res.outcomes).toEqual(res.outcomes.map((o) => ({ ...o, result: "arrived" })));
      expect(pz.starsFor(lay.trackCount(pz))).toBe(3);
      if (pz.solution.stops.length || pz.solution.lamps.length) {
        const bare = lay.clone();
        bare.stops.clear();
        bare.lamps.clear();
        expect(run(pz, bare).success).toBe(false);
      }
    });
  });
});

describe("lines", () => {
  it("gives every stop a unique id", () => {
    expect(new Set(LEVELS.map((lv) => lv.id)).size).toBe(LEVELS.length);
  });

  it("has at least 100 stops, the first 20 free", () => {
    expect(LEVELS.length).toBeGreaterThanOrEqual(100);
    expect(LEVELS.filter((lv) => lv.free).map((lv) => lv.id)).toEqual(LEVELS.slice(0, FREE_STOPS).map((lv) => lv.id));
    expect(FREE_STOPS).toBe(20);
  });

  it("numbers stops in order along each line", () => {
    LEVELS.forEach((lv) => expect(lv.id).toBe(`${lv.line + 1}-${lv.stop + 1}`));
  });
});

describe("daily line", () => {
  it("generates a solvable puzzle for every day of a year", () => {
    for (let day = 1; day <= 400; day++) {
      const pz = generate(day, false);
      expect(run(pz, pz.solutionLayout()).success, `day ${day}`).toBe(true);
      expect(pz.par).toBeGreaterThan(0);
    }
  }, 60_000);

  it("needs at least one signal every day from No. 0003", () => {
    for (let day = FLOOR_FROM; day < FLOOR_FROM + 400; day++) {
      const pz = generate(day); // cached by the test above
      // The generator's own track crashes without its stop signal.
      const bare = pz.solutionLayout();
      bare.stops.clear();
      expect(pz.solution.stops.length, `day ${day}`).toBeGreaterThan(0);
      expect(run(pz, bare).success, `day ${day}`).toBe(false);
      // And the solver finds no track-only layout near par.
      expect(meetsFloor(pz), `day ${day}`).toBe(true);
      expect(pz.trainCount(), `day ${day}`).toBeGreaterThanOrEqual(5);
    }
  }, 60_000);

  it("keeps No. 0001 and No. 0002 as they were released", () => {
    const one = generate(1, false);
    const two = generate(2, false);
    expect([one.par, one.depots.map((d) => d.trains.join("")).join("|")]).toEqual([15, "0|1|2"]);
    expect([two.par, two.depots.map((d) => d.trains.join("")).join("|")]).toEqual([21, "00|1|2"]);
  });

  it("is deterministic", () => {
    const a = generate(42, false);
    const b = generate(42, false);
    expect([...a.blocked]).toEqual([...b.blocked]);
    expect(a.depots).toEqual(b.depots);
    expect(a.par).toBe(b.par);
  });

  it("numbers days from 30 Sep 2026", () => {
    expect(today(new Date(2026, 8, 30, 23, 59))).toBe(1);
    expect(today(new Date(2026, 9, 1, 0, 1))).toBe(2);
    expect(dateLabel(1)).toBe("WED 30 SEP");
  });
});

describe("save", () => {
  function memory() {
    const m = new Map<string, string>();
    return { getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => void m.set(k, v) };
  }

  it("keeps the best stars and unlocks stops in order", () => {
    const s = new Save(memory());
    s.setStars("1-1", 2);
    s.setStars("1-1", 1);
    expect(s.stars("1-1")).toBe(2);
    expect(s.nextLevelIndex()).toBe(1);
  });

  it("records daily departures, streaks and the share grid", () => {
    const store = memory();
    const s = new Save(store);
    s.recordDaily(9, ["arrived"], true, 5, new Layout().toData());
    s.recordDaily(10, ["crashed", "arrived"], false, 0, new Layout().toData());
    s.recordDaily(10, ["arrived", "arrived"], true, 7, new Layout().toData());
    s.recordDaily(10, ["arrived", "arrived"], true, 7, new Layout().toData()); // ignored once solved
    expect(s.daily(10).rows.length).toBe(2);
    expect(s.dailyStats(10)).toEqual({ played: 2, solved: 2, streak: 2, best: 2 });
    expect(new Save(store).daily(10).solved).toBe(true);
    expect(shareText(10, s.daily(10), 6)).toBe("TrainsTrainsTrains No. 0010 · 2/6\n🟥🟩\n🟩🟩\ntrack 7 · par 6");
  });
});
