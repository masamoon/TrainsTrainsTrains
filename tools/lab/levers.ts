// Which board ingredients defeat crash-guided repair? Generates boards per recipe and plays
// each with the player model: tools/campaign/run.sh ../lab/levers [seeds]
import { type Recipe, candidate } from "../campaign/gen";
import { play } from "./player";

const d = (...trains: number[]) => ({ trains });
const g = (...trains: number[]) => ({ trains, goods: true });
const RECIPES: Record<string, Recipe> = {
  base: { w: 7, h: 8, theme: "mixed", depots: [d(0, 1, 0), d(2)] },
  "base+3trains": { w: 7, h: 8, theme: "mixed", depots: [d(0, 1, 0), d(2, 2, 2)] },
  dense: { w: 6, h: 6, theme: "mixed", clusters: [1, 2], depots: [d(0, 0, 0), d(1, 1, 1), d(2, 2)] },
  periods: { w: 7, h: 7, theme: "mixed", depots: [{ trains: [0, 0, 0], every: 3 }, { trains: [1, 1, 1], every: 4 }, { trains: [2, 2], every: 5 }] },
  goodsmerge: { w: 7, h: 7, theme: "mixed", depots: [g(0, 0), d(1, 1, 1)], stations: [0, 1] },
  tunnel: { w: 8, h: 7, theme: "hill", ridge: true, needTunnel: true, depots: [d(0, 0), d(1, 1)] },
  corridor: { w: 9, h: 5, theme: "woods", corridor: true, depots: [d(0, 0), d(1, 1)], attempts: 300 },
  corridor3: { w: 11, h: 5, theme: "woods", corridor: true, depots: [d(0, 0, 0), d(1, 1, 1)], attempts: 400 },
};
const seeds = Number(process.argv[2] ?? 30);
const only = process.argv[3];
for (const [name, r] of Object.entries(RECIPES)) {
  if (only && name !== only) continue;
  let made = 0;
  let beaten = 0;
  let departs = 0;
  const hard: string[] = [];
  for (let s = 1; s <= seeds * 4 && made < seeds; s++) {
    const c = candidate(r, s);
    if (!c) continue;
    made++;
    const p = play(c.pz);
    if (p.solved) departs += p.departs;
    else {
      beaten++;
      hard.push(String(s));
    }
  }
  const solved = made - beaten;
  console.log(`${name.padEnd(14)} boards ${made}  model stuck on ${beaten} (${Math.round((100 * beaten) / Math.max(made, 1))}%)  avg departs when solved ${(departs / Math.max(solved, 1)).toFixed(1)}  hard seeds ${hard.slice(0, 8).join(",")}`);
}
