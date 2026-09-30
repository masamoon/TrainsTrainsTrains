// What the player has built on a puzzle: track edges, switch levers, colour lamps and
// stop signals. A cell's shape comes from how many of its sides are connected:
// two make a straight or curve, three a switch (a Y whose stem is the odd side out),
// four a crossing.

import { type Cell, type Dir, type Puzzle, DIRS, ckey, dirBetween, edgeCells, edgeKey, opp, step } from "./puzzle";

export interface LayoutData {
  edges: string[];
  levers: [string, number][];
  lamps: [string, number][];
  stops: string[];
}

export class Layout {
  edges = new Set<string>();
  levers = new Map<string, Dir>();
  lamps = new Map<string, number>();
  stops = new Set<string>();

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

  // The branch a switch's lever points to. Defaults to the first branch clockwise from the stem.
  leverBranch(pz: Puzzle, p: Cell): Dir | -1 {
    const dirs = this.dirsAt(pz, p);
    const branches = Layout.switchBranches(dirs);
    if (branches.length === 0) return -1;
    const set = this.levers.get(ckey(p));
    if (set !== undefined && branches.includes(set)) return set;
    const stem = Layout.switchStem(dirs) as Dir;
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
        const stem = Layout.switchStem(dirs);
        if (entry !== stem) return stem;
        const lever = this.leverBranch(pz, p) as Dir;
        const lamp = this.lamps.get(ckey(p));
        if (lamp !== undefined && lamp !== color) {
          return Layout.switchBranches(dirs).find((b) => b !== lever) ?? lever;
        }
        return lever;
      }
      case 4:
        return opp(entry);
    }
    return -1;
  }

  flipLever(pz: Puzzle, p: Cell): boolean {
    const branches = Layout.switchBranches(this.dirsAt(pz, p));
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
    return changed;
  }

  // Drops signals that no longer fit the cell's shape.
  private tidy(pz: Puzzle, p: Cell): void {
    const n = this.dirsAt(pz, p).length;
    const k = ckey(p);
    if (n !== 3) {
      this.levers.delete(k);
      this.lamps.delete(k);
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
    };
  }

  static fromData(data: Partial<LayoutData> | undefined): Layout {
    const lay = new Layout();
    if (!data) return lay;
    for (const e of data.edges ?? []) lay.edges.add(e);
    for (const [k, d] of data.levers ?? []) lay.levers.set(k, d as Dir);
    for (const [k, c] of data.lamps ?? []) lay.lamps.set(k, c);
    for (const k of data.stops ?? []) lay.stops.add(k);
    return lay;
  }
}
