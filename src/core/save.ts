// Local progress: campaign stars and builds, Daily Line attempts and streaks.

import { DEPARTURES, numberLabel } from "./daily";
import type { LayoutData } from "./layout";
import { LEVELS } from "./levels";
import type { Outcome } from "./sim";

const KEY = "trainstrains.save.v1";

interface LevelSave {
  stars: number;
  layout?: LayoutData;
}

export interface DailySave {
  rows: Outcome[][];
  solved: boolean;
  layout?: LayoutData;
  track: number;
}

interface SaveData {
  levels: Record<string, LevelSave>;
  daily: Record<string, DailySave>;
}

export interface Storage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export class Save {
  data: SaveData = { levels: {}, daily: {} };

  constructor(private store: Storage | null = safeLocalStorage()) {
    try {
      const raw = this.store?.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<SaveData>;
        this.data = { levels: parsed.levels ?? {}, daily: parsed.daily ?? {} };
      }
    } catch {
      // Unreadable storage: start fresh.
    }
  }

  private write(): void {
    try {
      this.store?.setItem(KEY, JSON.stringify(this.data));
    } catch {
      // Storage full or blocked: progress lasts for this session only.
    }
  }

  // Campaign

  stars(id: string): number {
    return this.data.levels[id]?.stars ?? 0;
  }

  setStars(id: string, stars: number): void {
    const lv = (this.data.levels[id] ??= { stars: 0 });
    lv.stars = Math.max(lv.stars, stars);
    this.write();
  }

  totalStars(): number {
    return LEVELS.reduce((n, lv) => n + this.stars(lv.id), 0);
  }

  // Index of the first stop not yet cleared; every stop up to it is open.
  nextLevelIndex(): number {
    const i = LEVELS.findIndex((lv) => this.stars(lv.id) === 0);
    return i < 0 ? LEVELS.length : i;
  }

  levelLayout(id: string): LayoutData | undefined {
    return this.data.levels[id]?.layout;
  }

  setLevelLayout(id: string, layout: LayoutData): void {
    (this.data.levels[id] ??= { stars: 0 }).layout = layout;
    this.write();
  }

  // Daily Line

  daily(day: number): DailySave {
    return this.data.daily[day] ?? { rows: [], solved: false, track: 0 };
  }

  setDailyLayout(day: number, layout: LayoutData): void {
    this.data.daily[day] = { ...this.daily(day), layout };
    this.write();
  }

  // Records one departure: a row of per-train results.
  recordDaily(day: number, row: Outcome[], solved: boolean, track: number, layout: LayoutData): void {
    const d = this.daily(day);
    if (d.solved || d.rows.length >= DEPARTURES) return;
    this.data.daily[day] = {
      rows: [...d.rows, row],
      solved,
      track: solved ? track : d.track,
      layout,
    };
    this.write();
  }

  // Test mode only: forget one day's departures so it can be played again.
  resetDaily(day: number): void {
    delete this.data.daily[day];
    this.write();
  }

  dailyFinished(day: number): boolean {
    const d = this.daily(day);
    return d.solved || d.rows.length >= DEPARTURES;
  }

  dailyStats(today: number): { played: number; solved: number; streak: number; best: number } {
    const days = Object.keys(this.data.daily)
      .map(Number)
      .sort((a, b) => a - b);
    let played = 0;
    let solved = 0;
    let best = 0;
    let run = 0;
    let last = -10;
    for (const day of days) {
      const d = this.data.daily[day];
      if (d.rows.length === 0) continue;
      played += 1;
      if (d.solved) {
        solved += 1;
        run = day === last + 1 ? run + 1 : 1;
        last = day;
        best = Math.max(best, run);
      }
    }
    let streak = 0;
    let day = this.daily(today).solved ? today : today - 1;
    while (this.daily(day).solved) {
      streak += 1;
      day -= 1;
    }
    return { played, solved, streak, best };
  }
}

export function shareText(day: number, d: DailySave, par: number): string {
  const squares: Record<Outcome, string> = { arrived: "🟩", wrong: "🟨", crashed: "🟥" };
  const score = d.solved ? `${d.rows.length}/${DEPARTURES}` : `X/${DEPARTURES}`;
  const lines = [`TrainsTrainsTrains ${numberLabel(day)} · ${score}`];
  for (const row of d.rows) lines.push(row.map((r) => squares[r]).join(""));
  if (d.solved) lines.push(`track ${d.track} · par ${par}`);
  return lines.join("\n");
}

function safeLocalStorage(): Storage | null {
  try {
    return typeof localStorage === "undefined" ? null : localStorage;
  } catch {
    return null;
  }
}
