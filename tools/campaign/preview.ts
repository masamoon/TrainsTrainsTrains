// Contact sheet of levels for curation: draws each board with its reference solution.
import { Puzzle, type LevelData } from "../../src/core/puzzle";
import { Board } from "../../src/ui/board";

const grid = document.getElementById("grid")!;
const sheet = new URLSearchParams(location.search).get("sheet") ?? "sheet";
const items: { label: string; data: LevelData }[] = await (await fetch(`./out/${sheet}.json?${Date.now()}`)).json();
for (const it of items) {
  const pz = Puzzle.fromData(it.data);
  const board = new Board(pz, pz.solutionLayout());
  board.editable = false;
  const card = document.createElement("div");
  card.className = "card";
  const lbl = document.createElement("div");
  lbl.className = "lbl";
  lbl.textContent = it.label;
  card.append(board.canvas, lbl);
  grid.append(card);
}
document.body.dataset.ready = "1";
