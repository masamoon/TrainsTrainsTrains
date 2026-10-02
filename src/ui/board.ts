// Draws a puzzle and the player's layout on a canvas, takes drawing input, and plays
// back a simulation run.

import { Layout, type LayoutData } from "../core/layout";
import {
  type Cell,
  type Depot,
  type Dir,
  E,
  N,
  type Puzzle,
  S,
  type Station,
  type Tunnel,
  W,
  ckey,
  dirBetween,
  edgeCells,
  edgeKey,
  opp,
  parseCell,
  same,
  vec,
} from "../core/puzzle";
import type { RunResult, SimEvent, TrainFrame } from "../core/sim";
import { COLORS, glyphPath, livery, outcomeColor } from "./dom";

export type Tool = "track" | "signal" | "erase";

const BEAT_MS = 300;

interface Pt {
  x: number;
  y: number;
}

export class Board {
  readonly canvas = document.createElement("canvas");
  private ctx = this.canvas.getContext("2d")!;
  tool: Tool = "track";
  editable = true;
  onEdit: (before: LayoutData) => void = () => {};
  onHint: (text: string) => void = () => {};
  onFinish: () => void = () => {};

  private cellSize = 40;
  private origin: Pt = { x: 0, y: 0 };
  private cssW = 0;
  private cssH = 0;

  private pressing = false;
  private dragged = false;
  private pressCell: Cell = { x: -1, y: -1 };
  private lastCell: Cell = { x: -1, y: -1 };
  private before: LayoutData | null = null;
  private stroke: Cell[] = []; // cells the current drag has visited
  private laid = new Set<string>(); // edges the current drag has laid
  private changed = false;

  private result: RunResult | null = null;
  private startedAt = 0;
  private clock = 0; // seconds of playback
  private playing = false;
  private fast = false;
  private fired = -1;
  private effects: { ev: SimEvent; born: number }[] = [];
  private raf = 0;

  constructor(
    public pz: Puzzle,
    public lay: Layout,
  ) {
    this.canvas.setAttribute("role", "img");
    this.canvas.setAttribute("aria-label", "Puzzle board. Drag across squares to lay track.");
    this.canvas.addEventListener("pointerdown", (e) => this.down(e));
    this.canvas.addEventListener("pointermove", (e) => this.move(e));
    this.canvas.addEventListener("pointerup", (e) => this.up(e));
    this.canvas.addEventListener("pointercancel", () => this.cancel());
    new ResizeObserver(() => this.resize()).observe(this.canvas);
  }

  setLayout(lay: Layout): void {
    this.lay = lay;
    this.draw();
  }

  // Geometry

  private resize(): void {
    const r = this.canvas.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    const dpr = window.devicePixelRatio || 1;
    this.cssW = r.width;
    this.cssH = r.height;
    this.canvas.width = Math.round(r.width * dpr);
    this.canvas.height = Math.round(r.height * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const pad = 8;
    this.cellSize = Math.floor(Math.min((r.width - pad * 2) / this.pz.w, (r.height - pad * 2) / this.pz.h));
    this.origin = {
      x: Math.floor((r.width - this.cellSize * this.pz.w) / 2),
      y: Math.floor((r.height - this.cellSize * this.pz.h) / 2),
    };
    this.draw();
  }

  center(p: Cell): Pt {
    return { x: this.origin.x + (p.x + 0.5) * this.cellSize, y: this.origin.y + (p.y + 0.5) * this.cellSize };
  }

  private sideMid(p: Cell, d: Dir): Pt {
    const c = this.center(p);
    const [dx, dy] = vec(d);
    return { x: c.x + dx * this.cellSize * 0.5, y: c.y + dy * this.cellSize * 0.5 };
  }

  // A point along the piece in cell `p` running from side `a` to side `b`.
  private pathPoint(p: Cell, a: Dir, b: Dir, t: number): Pt {
    const p0 = this.sideMid(p, a);
    const p2 = this.sideMid(p, b);
    if (a === opp(b)) return { x: p0.x + (p2.x - p0.x) * t, y: p0.y + (p2.y - p0.y) * t };
    const c = this.center(p);
    const u = 1 - t;
    return {
      x: u * u * p0.x + 2 * u * t * c.x + t * t * p2.x,
      y: u * u * p0.y + 2 * u * t * c.y + t * t * p2.y,
    };
  }

  private cellAt(e: PointerEvent): Cell {
    const r = this.canvas.getBoundingClientRect();
    return {
      x: Math.floor((e.clientX - r.left - this.origin.x) / this.cellSize),
      y: Math.floor((e.clientY - r.top - this.origin.y) / this.cellSize),
    };
  }

  // Input

  private down(e: PointerEvent): void {
    if (!this.editable || e.button > 0) return;
    this.canvas.setPointerCapture(e.pointerId);
    this.pressing = true;
    this.dragged = false;
    this.changed = false;
    this.pressCell = this.cellAt(e);
    this.lastCell = this.pressCell;
    this.stroke = [this.pressCell];
    this.laid.clear();
    this.before = this.lay.toData();
    this.draw();
  }

  private move(e: PointerEvent): void {
    if (!this.pressing) return;
    const c = this.cellAt(e);
    if (same(c, this.lastCell)) return;
    if (!this.dragged && this.tool === "erase") this.changed = this.lay.clearCell(this.pz, this.lastCell) || this.changed;
    this.dragged = true;
    // Walk cell by cell so a fast drag still lays continuous track.
    let guard = 0;
    while (!same(this.lastCell, c) && guard++ < 40) {
      const dx = c.x - this.lastCell.x;
      const dy = c.y - this.lastCell.y;
      const next =
        Math.abs(dx) >= Math.abs(dy)
          ? { x: this.lastCell.x + Math.sign(dx), y: this.lastCell.y }
          : { x: this.lastCell.x, y: this.lastCell.y + Math.sign(dy) };
      if (this.tool === "track") {
        if (this.lay.connect(this.pz, this.lastCell, next)) {
          this.changed = true;
          this.laid.add(edgeKey(this.lastCell, dirBetween(this.lastCell, next) as Dir));
        }
      } else if (this.tool === "erase") this.changed = this.lay.clearCell(this.pz, next) || this.changed;
      this.lastCell = next;
      this.stroke.push(next);
    }
    if (this.tool === "track" && this.laid.size > 0) this.lay.faceStroke(this.pz, this.stroke, this.laid);
    this.draw();
  }

  private up(_e: PointerEvent): void {
    if (!this.pressing) return;
    this.pressing = false;
    if (!this.dragged) this.tap(this.pressCell);
    if (this.changed && this.before) this.onEdit(this.before);
    this.draw();
  }

  private cancel(): void {
    this.pressing = false;
    this.draw();
  }

  private tap(p: Cell): void {
    const { pz, lay } = this;
    if (!pz.inside(p)) return;
    const dirs = lay.dirsAt(pz, p);
    const k = ckey(p);
    if (this.tool === "track") {
      if (dirs.length === 3) this.changed = lay.flipLever(pz, p);
      else if (pz.buildable(p) && dirs.length === 0) this.onHint("Drag across squares to lay track.");
      else if (pz.buildable(p) && dirs.length === 2) this.onHint("Tap a switch to flip it. Join three sides of a square to make one.");
    } else if (this.tool === "erase") {
      this.changed = lay.clearCell(pz, p);
      if (!this.changed && this.isFixed(p)) this.onHint("Shaded track came with the line. It can't be erased.");
    } else if (pz.buildable(p)) {
      if (dirs.length === 2) {
        if (!pz.allowStop) this.onHint("Stop signals open at stop 5.");
        else {
          if (lay.stops.has(k)) lay.stops.delete(k);
          else lay.stops.add(k);
          this.changed = true;
        }
      } else if (dirs.length === 3) {
        if (!pz.allowLamp) this.onHint("Colour signals open at stop 7.");
        else {
          const colors = pz.colorsUsed();
          const idx = colors.indexOf(lay.lamps.get(k) ?? -1);
          if (idx + 1 >= colors.length) lay.lamps.delete(k);
          else lay.lamps.set(k, colors[idx + 1]);
          this.changed = true;
        }
      } else if (dirs.length === 4) this.onHint("Signals can't go on a crossing.");
      else this.onHint("Put a stop signal on a straight or curve, or a colour signal on a switch.");
    }
  }

  // Playback

  play(result: RunResult): void {
    this.result = result;
    this.playing = true;
    this.editable = false;
    this.fired = -1;
    this.effects = [];
    this.fast = false;
    this.startedAt = performance.now();
    cancelAnimationFrame(this.raf);
    this.raf = requestAnimationFrame((t) => this.tick(t));
  }

  stop(): void {
    cancelAnimationFrame(this.raf);
    this.result = null;
    this.playing = false;
    this.effects = [];
    this.editable = true;
    this.draw();
  }

  isPlaying(): boolean {
    return this.playing;
  }

  private tick(now: number): void {
    if (!this.result) return;
    // The first frame's timestamp can come from just before play() was called; a negative
    // clock would index frame -1 and stop playback for good.
    this.clock = Math.max(0, ((now - this.startedAt) / 1000) * (this.fast ? 2.5 : 1));
    const beats = this.result.frames.length - 1;
    const beat = Math.floor((this.clock * 1000) / BEAT_MS);
    while (this.fired < Math.min(beat, beats)) {
      this.fired += 1;
      for (const ev of this.result.events) if (ev.t === this.fired) this.effects.push({ ev, born: this.clock });
    }
    this.effects = this.effects.filter((fx) => this.clock - fx.born < 1.6);
    if (this.playing && this.clock * 1000 >= (beats + 0.9) * BEAT_MS) {
      this.playing = false;
      this.onFinish();
    }
    this.draw();
    if (this.playing || this.effects.length > 0) this.raf = requestAnimationFrame((t) => this.tick(t));
  }

  // Drawing

  draw(): void {
    const { ctx, pz, cellSize: cs } = this;
    if (this.cssW === 0) return;
    ctx.clearRect(0, 0, this.cssW, this.cssH);
    const bw = pz.w * cs;
    const bh = pz.h * cs;
    this.rrect(this.origin.x - cs * 0.12, this.origin.y - cs * 0.12, bw + cs * 0.24, bh + cs * 0.24, cs * 0.3, COLORS.well);
    ctx.fillStyle = COLORS.dot;
    for (let y = 1; y < pz.h; y++) {
      for (let x = 1; x < pz.w; x++) {
        ctx.beginPath();
        ctx.arc(this.origin.x + x * cs, this.origin.y + y * cs, Math.max(1.3, cs * 0.035), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    for (const [k, kind] of pz.blocked) this.drawObstacle(parseCell(k), kind);
    for (const k of this.fixedCells()) {
      const p = parseCell(k);
      this.rrect(this.origin.x + p.x * cs + 1.5, this.origin.y + p.y * cs + 1.5, cs - 3, cs - 3, cs * 0.14, COLORS.fixed);
    }
    if (this.pressing && this.editable && pz.inside(this.lastCell)) {
      const x = this.origin.x + this.lastCell.x * cs;
      const y = this.origin.y + this.lastCell.y * cs;
      this.rrect(x + 2, y + 2, cs - 4, cs - 4, cs * 0.16, "rgba(31,79,143,0.08)", "rgba(31,79,143,0.4)", 2);
    }
    this.drawTrack();
    for (const tn of pz.tunnels) this.drawTunnel(tn);
    pz.depots.forEach((dp, i) => this.drawDepot(dp, i));
    for (const st of pz.stations) this.drawStation(st);
    this.drawSignals();
    if (this.result) this.drawTrains();
    for (const fx of this.effects) this.drawEffect(fx.ev, this.clock - fx.born);
  }

  private rrect(x: number, y: number, w: number, h: number, r: number, fill: string, stroke?: string, lw = 0): void {
    const { ctx } = this;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
    ctx.fillStyle = fill;
    ctx.fill();
    if (stroke && lw > 0) {
      ctx.strokeStyle = stroke;
      ctx.lineWidth = lw;
      ctx.stroke();
    }
  }

  private circle(p: Pt, r: number, fill: string): void {
    this.ctx.beginPath();
    this.ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    this.ctx.fillStyle = fill;
    this.ctx.fill();
  }

  private drawObstacle(p: Cell, kind: string): void {
    const cs = this.cellSize;
    const { ctx } = this;
    const x = this.origin.x + p.x * cs + cs * 0.04;
    const y = this.origin.y + p.y * cs + cs * 0.04;
    const s = cs * 0.92;
    const c = this.center(p);
    const variant = Math.abs(p.x * 7 + p.y * 13) % 3;
    if (kind === "woods") {
      this.rrect(x, y, s, s, cs * 0.16, COLORS.woods);
      const spots: [number, number, number][] =
        variant === 1
          ? [[0.14, -0.18, 0.18], [-0.14, 0.1, 0.24], [0.24, 0.26, 0.1]]
          : [[-0.18, -0.16, 0.2], [0.17, 0.14, 0.24], [-0.2, 0.24, 0.12]];
      for (const [dx, dy, r] of spots) this.circle({ x: c.x + dx * cs, y: c.y + dy * cs }, r * cs, COLORS.woodsDark);
    } else if (kind === "water") {
      this.rrect(x, y, s, s, cs * 0.16, COLORS.water);
      ctx.strokeStyle = COLORS.waterDark;
      ctx.lineWidth = Math.max(1.5, cs * 0.05);
      ctx.lineCap = "round";
      for (const row of [-0.14, 0.18]) {
        ctx.beginPath();
        for (let i = 0; i < 13; i++) {
          const px = c.x + (-0.32 + i * 0.053) * cs;
          const py = c.y + (row + Math.sin(i * 1.3 + variant) * 0.04) * cs;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }
    } else if (kind === "hill") {
      this.rrect(x, y, s, s, cs * 0.16, COLORS.hill);
      // Two peaks, alternating which is taller.
      const peaks: [number, number, number][] = variant === 1 ? [[-0.16, 0.3, 0.2], [0.18, 0.4, 0.17]] : [[-0.18, 0.4, 0.17], [0.16, 0.3, 0.2]];
      ctx.fillStyle = COLORS.hillDark;
      for (const [dx, hgt, half] of peaks) {
        ctx.beginPath();
        ctx.moveTo(c.x + (dx - half) * cs, c.y + 0.26 * cs);
        ctx.lineTo(c.x + dx * cs, c.y + (0.26 - hgt) * cs);
        ctx.lineTo(c.x + (dx + half) * cs, c.y + 0.26 * cs);
        ctx.closePath();
        ctx.fill();
      }
    } else {
      this.rrect(x, y, s, s, cs * 0.16, COLORS.town);
      const bx = c.x;
      const by = c.y + 0.26 * cs;
      ctx.beginPath();
      ctx.moveTo(bx - 0.26 * cs, by);
      ctx.lineTo(bx - 0.26 * cs, by - 0.3 * cs);
      ctx.lineTo(bx, by - 0.5 * cs);
      ctx.lineTo(bx + 0.26 * cs, by - 0.3 * cs);
      ctx.lineTo(bx + 0.26 * cs, by);
      ctx.closePath();
      ctx.fillStyle = COLORS.townDark;
      ctx.fill();
    }
  }

  // Pieces run a hair past the cell edge so neighbours join without a seam.
  private piece(p: Cell, a: Dir, b: Dir, color: string, width: number): void {
    const { ctx } = this;
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineCap = "butt";
    ctx.lineJoin = "round";
    const [ax, ay] = vec(a);
    const [bx, by] = vec(b);
    const s = this.sideMid(p, a);
    const e = this.sideMid(p, b);
    ctx.beginPath();
    ctx.moveTo(s.x + ax * 0.75, s.y + ay * 0.75);
    if (a === opp(b)) {
      ctx.lineTo(e.x + bx * 0.75, e.y + by * 0.75);
    } else {
      ctx.lineTo(s.x, s.y);
      const c = this.center(p);
      ctx.quadraticCurveTo(c.x, c.y, e.x, e.y);
      ctx.lineTo(e.x + bx * 0.75, e.y + by * 0.75);
    }
    ctx.stroke();
  }

  private drawTrack(): void {
    const { pz, lay, ctx } = this;
    const w = this.cellSize * 0.2;
    const cells = new Map<string, Cell>();
    for (const key of [...lay.edges, ...pz.staticEdges()]) for (const c of edgeCells(key)) cells.set(ckey(c), c);
    for (const p of cells.values()) {
      if (!pz.inside(p) || pz.inTunnel(p)) continue;
      const di = pz.depotIndexAt(p);
      const si = pz.stationIndexAt(p);
      if (di >= 0 || si >= 0) {
        const d = di >= 0 ? pz.depots[di].dir : pz.stations[si].dir;
        const c = this.center(p);
        const m = this.sideMid(p, d);
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = w;
        ctx.lineCap = "butt";
        ctx.beginPath();
        ctx.moveTo(c.x, c.y);
        ctx.lineTo(m.x, m.y);
        ctx.stroke();
        continue;
      }
      const dirs = lay.dirsAt(pz, p);
      if (dirs.length === 1) {
        // A stub: beside a depot or platform it waits for track; drawn by the player it
        // ends in a buffer stop.
        const d = dirs[0];
        const m = this.sideMid(p, d);
        const c = this.center(p);
        const [dx, dy] = vec(d);
        ctx.strokeStyle = COLORS.ink;
        ctx.lineWidth = w;
        ctx.beginPath();
        ctx.moveTo(m.x + dx, m.y + dy);
        if (lay.playerDirsAt(p).length === 0) {
          const end = { x: m.x + (c.x - m.x) * 0.45, y: m.y + (c.y - m.y) * 0.45 };
          ctx.lineTo(end.x, end.y);
          ctx.stroke();
          this.circle(end, w / 2, COLORS.ink);
        } else {
          ctx.lineTo(c.x, c.y);
          ctx.stroke();
          const nx = -dy * this.cellSize * 0.22;
          const ny = dx * this.cellSize * 0.22;
          ctx.lineWidth = w * 0.6;
          ctx.beginPath();
          ctx.moveTo(c.x - nx, c.y - ny);
          ctx.lineTo(c.x + nx, c.y + ny);
          ctx.stroke();
        }
      } else if (dirs.length === 2) {
        this.piece(p, dirs[0], dirs[1], COLORS.ink, w);
      } else if (dirs.length === 3) {
        const stem = lay.stemAt(pz, p) as Dir;
        const lever = lay.leverBranch(pz, p) as Dir;
        for (const b of lay.branchesAt(pz, p)) if (b !== lever) this.piece(p, stem, b, "rgba(29,38,34,0.22)", w);
        this.piece(p, stem, lever, COLORS.ink, w);
        this.circle(this.pathPoint(p, stem, lever, 0.72), w * 0.22, COLORS.lit);
      } else if (dirs.length === 4) {
        this.piece(p, N, S, COLORS.ink, w);
        this.piece(p, W, E, COLORS.well, w * 1.9);
        this.piece(p, W, E, COLORS.ink, w);
      }
    }
  }

  private fixedCells(): Set<string> {
    const cells = new Set<string>();
    for (const key of this.pz.fixedEdges()) for (const c of edgeCells(key)) if (this.pz.buildable(c)) cells.add(ckey(c));
    return cells;
  }

  private isFixed(p: Cell): boolean {
    return this.fixedCells().has(ckey(p));
  }

  // A tunnel shows as a dashed line under the hills, with a portal at each mouth,
  // the way a signal-box diagram draws one.
  private drawTunnel(tn: Tunnel): void {
    const { ctx } = this;
    const cs = this.cellSize;
    const d = dirBetween(tn.cells[0], tn.cells[1]) as Dir;
    const a = this.sideMid(tn.a, opp(d));
    const b = this.sideMid(tn.b, d);
    ctx.save();
    ctx.strokeStyle = COLORS.ink;
    ctx.lineWidth = cs * 0.12;
    ctx.lineCap = "butt";
    ctx.setLineDash([cs * 0.16, cs * 0.12]);
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
    ctx.restore();
    for (const [mouth, out] of [[tn.a, opp(d)], [tn.b, d]] as [Cell, Dir][]) {
      const m = this.sideMid(mouth, out);
      const [ox, oy] = vec(out);
      const angle = Math.atan2(oy, ox);
      // Portal: a dark arch facing out of the hill, with the track running into it.
      ctx.save();
      ctx.translate(m.x - ox * cs * 0.02, m.y - oy * cs * 0.02);
      ctx.rotate(angle);
      ctx.beginPath();
      ctx.moveTo(0, -cs * 0.3);
      ctx.lineTo(0, cs * 0.3);
      ctx.lineTo(-cs * 0.14, cs * 0.3);
      ctx.arc(-cs * 0.14, 0, cs * 0.3, Math.PI / 2, -Math.PI / 2, false);
      ctx.closePath();
      ctx.fillStyle = COLORS.bezel;
      ctx.fill();
      ctx.fillStyle = COLORS.ink;
      ctx.fillRect(-cs * 0.2, -cs * 0.1, cs * 0.2 + 0.75, cs * 0.2);
      ctx.restore();
    }
  }

  private drawDepot(dp: Depot, index: number): void {
    const { ctx } = this;
    const cs = this.cellSize;
    const c = this.center(dp.pos);
    this.rrect(c.x - cs * 0.4, c.y - cs * 0.4, cs * 0.8, cs * 0.8, cs * 0.18, COLORS.bezel);
    const [fx, fy] = vec(dp.dir);
    const sx = -fy;
    const sy = fx;
    const tip = { x: c.x + fx * cs * 0.14, y: c.y + fy * cs * 0.14 };
    ctx.strokeStyle = COLORS.lit;
    ctx.lineWidth = cs * 0.08;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(tip.x - fx * cs * 0.2 + sx * cs * 0.18, tip.y - fy * cs * 0.2 + sy * cs * 0.18);
    ctx.lineTo(tip.x, tip.y);
    ctx.lineTo(tip.x - fx * cs * 0.2 - sx * cs * 0.18, tip.y - fy * cs * 0.2 - sy * cs * 0.18);
    ctx.stroke();
    // Trains still waiting to leave, as small dots along the back edge.
    const waiting = this.waitingAt(index);
    waiting.forEach((color, i) => {
      const o = (i - (waiting.length - 1) / 2) * cs * 0.13;
      const at = { x: c.x - fx * cs * 0.26 + sx * o, y: c.y - fy * cs * 0.26 + sy * o };
      // Goods trains wait as small squares, passenger trains as dots.
      if (dp.goods) this.rrect(at.x - cs * 0.05, at.y - cs * 0.05, cs * 0.1, cs * 0.1, cs * 0.015, livery(color));
      else this.circle(at, cs * 0.055, livery(color));
    });
  }

  private waitingAt(depotIndex: number): number[] {
    const dp = this.pz.depots[depotIndex];
    if (!this.result) return dp.trains;
    // Trains are numbered by departure beat, then depot; rebuild that order.
    const order = this.pz.depots
      .flatMap((d, di) => d.trains.map((_, i) => ({ di, i, t: d.start + i * d.every })))
      .sort((a, b) => a.t - b.t || a.di - b.di);
    const upto = Math.min(Math.floor((this.clock * 1000) / BEAT_MS) + 1, this.result.frames.length - 1);
    const seen = new Set<number>();
    for (let f = 0; f <= upto; f++) for (const tr of this.result.frames[f]) seen.add(tr.id);
    return dp.trains.filter((_, i) => !seen.has(order.findIndex((o) => o.di === depotIndex && o.i === i)));
  }

  private drawStation(st: Station): void {
    const cs = this.cellSize;
    const c = this.center(st.pos);
    const col = livery(st.color);
    this.rrect(c.x - cs * 0.38, c.y - cs * 0.38, cs * 0.76, cs * 0.76, cs * 0.18, "#fff", col, Math.max(3, cs * 0.09));
    this.glyph(st.color, c, cs * 0.13, col);
    if (st.opens) this.drawTimetable(st);
  }

  // A timed platform carries a clock badge on its back corner: the beat it opens on, counting
  // down during a run and turning green once trains may arrive.
  private drawTimetable(st: Station): void {
    const { ctx } = this;
    const cs = this.cellSize;
    const c = this.center(st.pos);
    const [fx, fy] = vec(st.dir);
    const at = { x: c.x - fx * cs * 0.34 + -fy * cs * 0.34, y: c.y - fy * cs * 0.34 + fx * cs * 0.34 };
    const beat = this.result ? Math.floor((this.clock * 1000) / BEAT_MS) : 0;
    const left = (st.opens ?? 0) - beat;
    const r = cs * 0.21;
    this.circle(at, r + Math.max(1.5, cs * 0.03), COLORS.well);
    this.circle(at, r, left > 0 ? COLORS.bezel : COLORS.green);
    ctx.fillStyle = COLORS.lit;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    if (left > 0) {
      ctx.font = `700 ${Math.round(cs * 0.27)}px "Barlow Condensed", sans-serif`;
      ctx.fillText(String(left), at.x, at.y + cs * 0.01);
    } else {
      ctx.strokeStyle = COLORS.lit;
      ctx.lineWidth = Math.max(1.5, cs * 0.045);
      ctx.beginPath();
      ctx.moveTo(at.x - r * 0.45, at.y);
      ctx.lineTo(at.x - r * 0.1, at.y + r * 0.35);
      ctx.lineTo(at.x + r * 0.45, at.y - r * 0.35);
      ctx.stroke();
    }
  }

  private glyph(color: number, c: Pt, r: number, fill: string): void {
    const p = new Path2D(glyphToPath(color, c.x, c.y, r));
    this.ctx.fillStyle = fill;
    this.ctx.fill(p);
  }

  private currentFrame(): TrainFrame[] {
    if (!this.result) return [];
    const i = Math.min(Math.floor((this.clock * 1000) / BEAT_MS), this.result.frames.length - 1);
    return this.result.frames[Math.max(0, i)];
  }

  private drawSignals(): void {
    const { pz, lay } = this;
    const cs = this.cellSize;
    const holding = new Set(this.currentFrame().filter((t) => t.hold > 0).map((t) => ckey(t.pos)));
    for (const k of lay.stops) {
      const p = parseCell(k);
      const dirs = lay.dirsAt(pz, p);
      if (dirs.length !== 2) continue;
      // The signal head sits beside the track, away from the side a curve bends toward.
      const [ax, ay] = vec(dirs[0]);
      const [bx, by] = vec(dirs[1]);
      const ox = ax + bx;
      const oy = ay + by;
      const c = this.center(p);
      let hc: Pt;
      if (ox === 0 && oy === 0) hc = { x: c.x - ay * cs * 0.3, y: c.y + ax * cs * 0.3 };
      else {
        const len = Math.hypot(ox, oy);
        hc = { x: c.x - (ox / len) * cs * 0.2, y: c.y - (oy / len) * cs * 0.2 };
      }
      this.rrect(hc.x - cs * 0.13, hc.y - cs * 0.17, cs * 0.26, cs * 0.34, cs * 0.08, COLORS.bezel);
      const lit = !this.result || holding.has(k);
      this.circle(hc, cs * 0.075, lit ? COLORS.red : "rgba(216,67,46,0.45)");
    }
    for (const [k, color] of lay.lamps) {
      const p = parseCell(k);
      if (lay.dirsAt(pz, p).length !== 3) continue;
      const c = this.center(p);
      this.circle(c, cs * 0.17, COLORS.bezel);
      this.circle(c, cs * 0.11, livery(color));
    }
  }

  private drawTrains(): void {
    const frames = this.result!.frames;
    const k = Math.max(0, Math.min(Math.floor((this.clock * 1000) / BEAT_MS), frames.length - 1));
    const f = Math.min(Math.max((this.clock * 1000) / BEAT_MS - k, 0), 1);
    const here = frames[k];
    const next = frames[Math.min(k + 1, frames.length - 1)];
    const nextById = new Map(next.map((t) => [t.id, t]));
    const len = this.cellSize * 0.78;
    for (const tr of here) {
      if (tr.state !== "moving") continue; // finished trains show as an effect
      const tn = nextById.get(tr.id);
      let pos: Pt;
      let ahead: Pt;
      let alpha = 1;
      if (k + 1 >= frames.length || !tn || same(tn.pos, tr.pos)) {
        pos = this.pathPoint(tr.pos, tr.in, tr.out, 0.5);
        ahead = this.pathPoint(tr.pos, tr.in, tr.out, 0.55);
      } else {
        const t = 0.5 + f;
        if (t <= 1) {
          pos = this.pathPoint(tr.pos, tr.in, tr.out, t);
          const back = this.pathPoint(tr.pos, tr.in, tr.out, t - 0.05);
          ahead = { x: pos.x + (pos.x - back.x), y: pos.y + (pos.y - back.y) };
        } else {
          const entry = opp(tr.out);
          const out = tn.state === "moving" ? tn.out : tr.out;
          pos = this.pathPoint(tn.pos, entry, out, t - 1);
          ahead = this.pathPoint(tn.pos, entry, out, t - 0.95);
          if (tn.state !== "moving") alpha = Math.max(0, 1 - (t - 1) * 1.6);
        }
      }
      this.drawTrain(pos, Math.atan2(ahead.y - pos.y, ahead.x - pos.x), len, tr.color, alpha * this.coverAt(pos), tr.goods);
    }
    // Trains that appear this beat roll out of their depot.
    const hereIds = new Set(here.map((t) => t.id));
    if (k + 1 < frames.length) {
      for (const tr of next) {
        if (hereIds.has(tr.id) || tr.state !== "moving") continue;
        const [dx, dy] = vec(tr.out);
        this.drawTrain(this.pathPoint(tr.pos, tr.in, tr.out, 0.5), Math.atan2(dy, dx), len * (0.4 + 0.6 * f), tr.color, f, tr.goods);
      }
    }
  }

  // Trains under a hill show faintly, like an occupied section lamp.
  private coverAt(p: Pt): number {
    const cell = { x: Math.floor((p.x - this.origin.x) / this.cellSize), y: Math.floor((p.y - this.origin.y) / this.cellSize) };
    return this.pz.inTunnel(cell) ? 0.28 : 1;
  }

  private drawTrain(c: Pt, angle: number, length: number, color: number, alpha: number, goods = false): void {
    const { ctx } = this;
    const thick = length * 0.5;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(c.x, c.y);
    ctx.rotate(angle);
    ctx.beginPath();
    if (goods) {
      // A boxy wagon with ribs instead of a rounded nose and window.
      ctx.roundRect(-length / 2, -thick / 2, length, thick, thick * 0.14);
      ctx.fillStyle = livery(color);
      ctx.fill();
      ctx.fillStyle = "rgba(0,0,0,0.22)";
      for (const rx of [-0.36, 0.3]) ctx.fillRect(length * rx, -thick * 0.36, thick * 0.12, thick * 0.72);
      ctx.fillStyle = "#fff";
    } else {
      ctx.roundRect(-length / 2, -thick / 2, length, thick, thick / 2);
      ctx.fillStyle = livery(color);
      ctx.fill();
      ctx.beginPath();
      ctx.roundRect(length / 2 - thick * 0.72, -thick * 0.28, thick * 0.4, thick * 0.56, thick * 0.14);
      ctx.fillStyle = "#fff";
      ctx.fill();
    }
    ctx.rotate(-angle);
    const shift = goods ? 0 : -length * 0.14;
    const gx = Math.cos(angle) * shift;
    const gy = Math.sin(angle) * shift;
    ctx.fill(new Path2D(glyphToPath(color, gx, gy, thick * 0.2)));
    ctx.restore();
  }

  private drawEffect(ev: SimEvent, age: number): void {
    const { ctx } = this;
    const cs = this.cellSize;
    const c = this.center(ev.pos);
    const color = outcomeColor(ev.kind === "arrived" ? "arrived" : ev.kind === "wrong" || ev.kind === "early" ? "wrong" : "crashed");
    ctx.save();
    ctx.globalAlpha = Math.max(0, 1 - age / 1.6);
    ctx.strokeStyle = color;
    ctx.lineWidth = cs * 0.08;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(c.x, c.y, cs * (0.35 + age * 0.25), 0, Math.PI * 2);
    ctx.stroke();
    if (ev.kind === "crash" || ev.kind === "derail" || ev.kind === "lost") {
      for (let i = 0; i < 8; i++) {
        const a = (i * Math.PI * 2) / 8 + 0.3;
        ctx.beginPath();
        ctx.moveTo(c.x + Math.cos(a) * cs * 0.12, c.y + Math.sin(a) * cs * 0.12);
        ctx.lineTo(c.x + Math.cos(a) * (cs * 0.28 + age * cs * 0.3), c.y + Math.sin(a) * (cs * 0.28 + age * cs * 0.3));
        ctx.stroke();
      }
    }
    ctx.restore();
  }
}

// Canvas version of the SVG glyph: same shapes, as path data.
function glyphToPath(color: number, cx: number, cy: number, r: number): string {
  if (color % 4 === 0) return `M${cx + r} ${cy} A${r} ${r} 0 1 0 ${cx - r} ${cy} A${r} ${r} 0 1 0 ${cx + r} ${cy} Z`;
  if (color % 4 === 2) {
    const s = r * 0.9;
    return `M${cx - s} ${cy - s} H${cx + s} V${cy + s} H${cx - s} Z`;
  }
  const svgPath = glyphPath(color, cx, cy, r);
  return svgPath.match(/d="([^"]+)"/)![1];
}
