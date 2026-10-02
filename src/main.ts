// Screen router. Routes live in the URL hash so the game works under any Pages subpath.

import { initAnalytics, track } from "./analytics";
import { LAB } from "./core/lab";
import { LEVELS, isOpen } from "./core/levels";
import { Save } from "./core/save";
import "./styles.css";
import { homeScreen } from "./ui/home";
import { mapScreen } from "./ui/map";
import type { Screen } from "./ui/nav";
import { playScreen } from "./ui/play";

const save = new Save();
const app = document.getElementById("app")!;
let current: Screen | null = null;

function render(): void {
  current?.dispose?.();
  document.querySelectorAll(".dim").forEach((el) => el.remove());
  const route = location.hash.replace(/^#\/?/, "");
  const [name, arg] = route.split("/");
  const index = Number(arg) - 1;
  if (name === "map") current = mapScreen(save);
  else if (name === "level" && Number.isInteger(index) && index >= 0 && index < LEVELS.length && isOpen(index, save.nextLevelIndex()))
    current = playScreen(save, "level", index);
  else if (name === "daily") current = playScreen(save, "daily", 0);
  // Difficulty prototypes for playtesting; only reachable by link.
  else if (name === "lab" && Number.isInteger(index) && index >= 0 && index < LAB.length) current = playScreen(save, "lab", index);
  else current = homeScreen(save);
  app.replaceChildren(current.el);
  const where: Record<string, string | number> = { screen: name || "home" };
  if (name === "level" && LEVELS[index]) where.level = LEVELS[index].id;
  if (name !== "lab") track("$pageview", where);
  window.scrollTo(0, 0);
}

initAnalytics();
window.addEventListener("hashchange", render);
render();
