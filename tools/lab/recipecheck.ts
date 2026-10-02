// Sanity check for the recipe gate: loosened lab boards should be caught.
import { LAB } from "../../src/core/lab";
import { Puzzle } from "../../src/core/puzzle";
import { brainless } from "./recipes";
for (const data of LAB.filter((l) => l.signals === "block")) {
  for (const [label, d] of [["as built", data], ["no deadline", { ...data, deadline: undefined }], ["deadline +6", { ...data, deadline: (data.deadline ?? 0) + 6 }], ["open board", { ...data, rows: data.rows.map((r) => r.replace(/[T~]/g, ".")), deadline: undefined }]] as const) {
    const pz = Puzzle.fromData(d);
    console.log(`${data.name} ${label}: ${brainless(pz, pz.solutionLayout()) || "no recipe solves it"}`);
  }
}
