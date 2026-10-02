// What the player has built on a puzzle: track edges, switch levers, colour lamps and
// stop signals. A cell's shape comes from how many of its sides are connected:
// two make a straight or curve, three a switch, four a crossing. A switch is a Y: trains
// entering by its stem take the lever's branch, trains entering by a branch leave by the
// stem. The stem is the odd side out unless a stroke of track chose another (`stems`).

import { type Cell, type Dir, type Puzzle, DIRS, ckey, dirBetween, edgeCells, edgeKey, opp, step } from "./puzzle";

export interface LayoutData {
  edges: string[];
  levers: [string, number][];
  lamps: [string, number][];
  stops: string[];
  stems?: [string, number][];
}

export class Layout {
  edges = new Set<string>();
  levers = new Map<string, Dir>();
  lamps = new Map<string, number>();
  stops = new Set<string>();
  stems = new Map<string, Dir>();

  dirsAt(pz: Puzzle, p: Cell): Dir[] {
    const fixed = pz.staticEdges();
    return DIRS.filter((d) => {
      const k = edgeKey(p, d);
      return this.edges.has(k) || fixed.has(k);
    });
  }

  playerDirsAt(p: Cell): Dir[] {
    return DIRS.filter((d) => this.edges.has(edgeKey(p, d)));
  }

  static switchStem(dirs: Dir[]): Dir | -1 {
    if (dirs.length !== 3) return -1;
    return dirs.find((d) => !dirs.includes(opp(d))) ?? -1;
  }

  static switchBranches(dirs: Dir[]): Dir[] {
    const stem = Layout.switchStem(dirs);
    return stem < 0 ? [] : dirs.filter((d) => d !== stem);
  }

  // The stem of the switch at `p`: the side a stroke chose, else the odd side out.
  stemAt(pz: Puzzle, p: Cell): Dir | -1 {
    const dirs = this.dirsAt(pz, p);
    if (dirs.length !== 3) return -1;
    const set = this.stems.get(ckey(p));
    return set !== undefined && dirs.includes(set) ? set : Layout.switchStem(dirs);
  }

  branchesAt(pz: Puzzle, p: Cell): Dir[] {
    const stem = this.stemAt(pz, p);
    return stem < 0 ? [] : this.dirsAt(pz, p).filter((d) => d !== stem);
  }

  // The branch a switch's lever points to. Defaults to the first branch clockwise from the stem.
  leverBranch(pz: Puzzle, p: Cell): Dir | -1 {
    const branches = this.branchesAt(pz, p);
    if (branches.length === 0) return -1;
    const set = this.levers.get(ckey(p));
    if (set !== undefined && branches.includes(set)) return set;
    const stem = this.stemAt(pz, p) as Dir;
    for (let i = 1; i < 4; i++) {
      const d = ((stem + i) % 4) as Dir;
      if (branches.includes(d)) return d;
    }
    return branches[0];
  }

  // The side a train leaves `p` by, having entered from side `entry`. -1 means it cannot.
  exitFor(pz: Puzzle, p: Cell, entry: Dir, color: number): Dir | -1 {
    const dirs = this.dirsAt(pz, p);
    if (!dirs.includes(entry)) return -1;
    switch (dirs.length) {
      case 2:
        return dirs[0] === entry ? dirs[1] : dirs[0];
      case 3: {
        const stem = this.stemAt(pz, p);
        if (entry !== stem) return stem;
        const lever = this.leverBranch(pz, p) as Dir;
        const lamp = this.lamps.get(ckey(p));
        if (lamp !== undefined && lamp !== color) {
          return this.branchesAt(pz, p).find((b) => b !== lever) ?? lever;
        }
        return lever;
      }
      case 4:
        return opp(entry);
    }
    return -1;
  }

  flipLever(pz: Puzzle, p: Cell): boolean {
    const branches = this.branchesAt(pz, p);
    if (branches.length !== 2) return false;
    const current = this.leverBranch(pz, p);
    this.levers.set(ckey(p), branches[0] === current ? branches[1] : branches[0]);
    return true;
  }

  // Adds track between two neighbouring cells. Returns true if anything changed.
  connect(pz: Puzzle, a: Cell, b: Cell): boolean {
    const d = dirBetween(a, b);
    if (d === -1 || !pz.inside(a) || !pz.inside(b)) return false;
    const key = edgeKey(a, d);
    if (this.edges.has(key) || pz.staticEdges().has(key)) return false;
    if (!pz.buildable(a) || !pz.buildable(b)) return false;
    this.edges.add(key);
    this.tidy(pz, a);
    this.tidy(pz, b);
    return true;
  }

  // Faces the switches a stroke of track made so the stroke reads as one line through them.
  // `path` is every cell the stroke visited, in order; `added` the edges it laid. A switch
  // keeps its old line through it, so the stem is always one of its older sides:
  // - the stroke ran through it: the older side the stroke used (joining a line, or
  //   peeling off one, after following it for a square);
  // - the stroke ended or began on it: the older side its nearest turn heads toward, so
  //   a branch drawn going east and then down onto a line merges onto it eastbound.
  // Otherwise the switch keeps the odd side out as its stem. Its lever starts on the old line.
  faceStroke(pz: Puzzle, path: Cell[], added: Set<string>): void {
    const side = (a: Cell, b: Cell): Dir | -1 => dirBetween(a, b);
    path.forEach((p, i) => {
      const dirs = this.dirsAt(pz, p);
      if (dirs.length !== 3 || !pz.buildable(p)) return;
      const older = dirs.filter((d) => !added.has(edgeKey(p, d)));
      if (older.length !== 2) return;
      const prev = i > 0 ? side(p, path[i - 1]) : -1;
      const next = i < path.length - 1 ? side(p, path[i + 1]) : -1;
      let stem: number = -1;
      if (prev >= 0 && next >= 0) {
        const used = [prev, next].filter((d) => older.includes(d as Dir));
        if (used.length !== 1) return;
        stem = used[0];
      } else if (prev >= 0) {
        // The stroke's last turn before it came in.
        for (let j = i - 1; j > 0 && stem < 0; j--) {
          const turn = side(path[j - 1], path[j]);
          if (turn >= 0 && turn % 2 !== prev % 2) stem = older.includes(turn as Dir) ? turn : -2;
        }
      } else if (next >= 0) {
        // The stroke's first turn after it left.
        for (let j = i + 1; j < path.length - 1 && stem < 0; j++) {
          const heading = side(path[j], path[j + 1]);
          if (heading >= 0 && heading % 2 !== next % 2) stem = older.includes(opp(heading as Dir)) ? opp(heading as Dir) : -2;
        }
      }
      const k = ckey(p);
      if (stem < 0) {
        this.stems.delete(k);
        return;
      }
      if (this.stems.get(k) === stem) return;
      this.stems.set(k, stem as Dir);
      this.levers.set(k, older.find((d) => d !== stem) as Dir);
    });
  }

  // Removes all player track touching a cell, plus its signals.
  clearCell(pz: Puzzle, p: Cell): boolean {
    let changed = false;
    for (const d of DIRS) {
      const key = edgeKey(p, d);
      if (this.edges.delete(key)) {
        changed = true;
        this.tidy(pz, step(p, d));
      }
    }
    const k = ckey(p);
    changed = this.levers.delete(k) || changed;
    changed = this.lamps.delete(k) || changed;
    changed = this.stops.delete(k) || changed;
    this.stems.delete(k);
    return changed;
  }

  // Drops signals that no longer fit the cell's shape.
  private tidy(pz: Puzzle, p: Cell): void {
    const n = this.dirsAt(pz, p).length;
    const k = ckey(p);
    if (n !== 3) {
      this.levers.delete(k);
      this.lamps.delete(k);
      this.stems.delete(k);
    }
    if (n !== 2) this.stops.delete(k);
  }

  // Track pieces the player placed: every buildable cell with at least one drawn edge.
  trackCount(pz: Puzzle): number {
    const cells = new Set<string>();
    for (const key of this.edges) {
      for (const c of edgeCells(key)) if (pz.buildable(c)) cells.add(ckey(c));
    }
    return cells.size;
  }

  clone(): Layout {
    return Layout.fromData(this.toData());
  }

  toData(): LayoutData {
    return {
      edges: [...this.edges],
      levers: [...this.levers],
      lamps: [...this.lamps],
      stops: [...this.stops],
      stems: [...this.stems],
    };
  }

  static fromData(data: Partial<LayoutData> | undefined): Layout {
    const lay = new Layout();
    if (!data) return lay;
    for (const e of data.edges ?? []) lay.edges.add(e);
    for (const [k, d] of data.levers ?? []) lay.levers.set(k, d as Dir);
    for (const [k, c] of data.lamps ?? []) lay.lamps.set(k, c);
    for (const k of data.stops ?? []) lay.stops.add(k);
    for (const [k, d] of data.stems ?? []) lay.stems.set(k, d as Dir);
    return lay;
  }
}
