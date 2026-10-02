// Plays one puzzle: a campaign stop or today's Daily Wye.

import { track } from "../analytics";
import { DEPARTURES, dateLabel, generate, msUntilTomorrow, numberLabel, today } from "../core/daily";
import { Layout, type LayoutData } from "../core/layout";
import { LAB } from "../core/lab";
import { LEVELS, LINES, loadLevel } from "../core/levels";
import { Puzzle } from "../core/puzzle";
import { type Save, shareText } from "../core/save";
import { type RunResult, run } from "../core/sim";
import { type Tool, Board } from "./board";
import { COLORS, LIVERY_NAMES, h, overlay, resultRows, starsSvg, toast, trainSvg } from "./dom";
import { type Screen, go } from "./nav";

export function playScreen(save: Save, mode: "level" | "daily" | "lab", index: number): Screen {
  const day = today();
  const daily = mode === "daily";
  const lab = mode === "lab";
  const pz: Puzzle = daily ? generate(day) : lab ? Puzzle.fromData(LAB[index]) : loadLevel(index);
  const saved = daily ? save.daily(day).layout : save.levelLayout(pz.id);
  let lay = saved ? Layout.fromData(saved) : new Layout();
  const undo: LayoutData[] = [];
  let result: RunResult | null = null;
  let current: { close: () => void } | null = null;
  let countdownTimer = 0;

  const board = new Board(pz, lay);

  // Top bar
  const bar = h(
    "header",
    { class: "bar" },
    h("button", { class: "bar-btn", onclick: () => go(daily || lab ? "#/" : "#/map") }, daily || lab ? "‹ Home" : "‹ Map"),
    h(
      "div",
      { class: "bar-title" },
      h("div", { class: "eyebrow" }, daily ? `DAILY WYE ${numberLabel(day)}` : lab ? `PROTOTYPE ${index + 1} OF ${LAB.length}` : `LINE ${LEVELS[index].line + 1} · STOP ${LEVELS[index].stop + 1}`),
      h("h1", {}, daily ? dateLabel(day) : pz.name.toUpperCase()),
    ),
    h("button", { class: "bar-btn bar-right", onclick: clear }, "Clear"),
  );

  // Departures: each depot's trains in order.
  const departures = h(
    "div",
    { class: "departures", "aria-label": "Departures: " + pz.depots.map((d) => d.trains.map((c) => LIVERY_NAMES[c % 4] + (d.goods ? " goods" : "")).join(", ")).join("; ") },
    h("span", { class: "eyebrow", "aria-hidden": "true" }, "DEPARTURES"),
    ...pz.depots.map((dp) => h("div", { class: "chip", "aria-hidden": "true" }, ...dp.trains.map((c) => trainSvg(c, 30, dp.goods)))),
  );

  const trackLabel = h("span", {});
  const starsBox = h("span", { style: "display:flex" });
  const status = h("div", { class: "status" }, trackLabel, starsBox);

  let rowsBox: HTMLElement | null = null;
  let info: HTMLElement | null = null;
  if (daily) {
    rowsBox = h("div", {});
    info = h("div", { class: "info" }, rowsBox, h("p", { class: "muted" }, "Six departures to get every train to its platform. Each one adds a row to your result."));
  } else if (pz.introTitle) {
    info = h("div", { class: "info" }, h("div", {}, h("p", { style: "font-weight:700;font-size:16px" }, pz.introTitle), h("p", { class: "muted" }, pz.introText)));
  }

  const signalsOpen = pz.allowStop || pz.allowLamp;
  const toolButtons = new Map<Tool, HTMLButtonElement>();
  const toolRow = h("div", { class: "tools", role: "toolbar", "aria-label": "Tools" });
  for (const [key, label] of [["track", "Track"], ["signal", "Signal"], ["erase", "Erase"]] as [Tool, string][]) {
    const b = h("button", { class: "tool", "aria-pressed": "false", onclick: () => setTool(key) }, toolIcon(key), label);
    toolButtons.set(key, b);
    toolRow.append(b);
  }
  const undoBtn = h("button", { class: "tool", onclick: doUndo }, toolIcon("undo"), "Undo");
  toolRow.append(undoBtn);

  const departBtn = h("button", { class: "btn btn-primary btn-wide", style: "min-height:58px;font-size:26px", onclick: depart }, "DEPART");

  const boardWrap = h("div", { class: "board-wrap" }, board.canvas);
  // Test mode (?test in the URL) adds a way to replay today's Daily Wye.
  const testMode = new URLSearchParams(location.search).has("test");
  const resetBtn = daily && testMode ? h("button", { class: "btn btn-ghost", onclick: resetToday }, "Reset today's puzzle (test mode)") : null;
  const body = h("div", { class: "col play-body" }, departures, boardWrap, status, info, toolRow, departBtn, resetBtn);
  const el = h("main", { class: "screen" }, bar, body);

  board.onEdit = (before) => {
    undo.push(before);
    if (undo.length > 100) undo.shift();
    persist();
    refresh();
  };
  board.onHint = toast;
  board.onFinish = finished;

  setTool("track");
  refresh();
  if (daily && save.dailyFinished(day)) {
    board.editable = false;
    requestAnimationFrame(() => showDailyResult(false));
  }

  function setTool(t: Tool): void {
    board.tool = t;
    for (const [k, b] of toolButtons) b.setAttribute("aria-pressed", String(k === t));
  }

  function refresh(): void {
    const n = lay.trackCount(pz);
    trackLabel.textContent = `Track ${n} · par ${pz.par}`;
    starsBox.replaceChildren(starsSvg(n > 0 ? pz.starsFor(n) : 0, 20));
    const running = board.isPlaying();
    const finished = daily && save.dailyFinished(day);
    for (const [k, b] of toolButtons) b.disabled = running || finished || (k === "signal" && !signalsOpen);
    undoBtn.disabled = running || finished || undo.length === 0;
    departBtn.disabled = false;
    if (running) {
      departBtn.className = "btn btn-dark btn-wide";
      departBtn.textContent = "STOP";
    } else {
      departBtn.className = "btn btn-primary btn-wide";
      departBtn.textContent = "DEPART";
      if (daily) {
        const d = save.daily(day);
        const left = DEPARTURES - d.rows.length;
        departBtn.textContent = d.solved ? "SOLVED TODAY" : left <= 0 ? "NO DEPARTURES LEFT" : `DEPART · ${left} LEFT`;
        departBtn.disabled = save.dailyFinished(day);
      }
    }
    if (rowsBox) {
      const rows = save.daily(day).rows;
      rowsBox.replaceChildren(rows.length ? resultRows(rows, 14) : "");
      rowsBox.hidden = rows.length === 0;
    }
  }

  function persist(): void {
    if (daily) {
      if (!save.dailyFinished(day)) save.setDailyLayout(day, lay.toData());
    } else save.setLevelLayout(pz.id, lay.toData());
  }

  function setLayout(l: Layout): void {
    lay = l;
    board.setLayout(l);
    persist();
    refresh();
  }

  function doUndo(): void {
    if (board.isPlaying() || undo.length === 0) return;
    setLayout(Layout.fromData(undo.pop()!));
  }

  function clear(): void {
    if (board.isPlaying() || (daily && save.dailyFinished(day))) return;
    if (lay.edges.size === 0) return;
    undo.push(lay.toData());
    setLayout(new Layout());
  }

  function depart(): void {
    if (board.isPlaying()) {
      board.stop();
      refresh();
      return;
    }
    if (lay.edges.size === 0) {
      toast("Lay some track first: drag from a depot.");
      return;
    }
    closeOverlay();
    result = run(pz, lay);
    if (daily) {
      save.recordDaily(day, result.outcomes.map((o) => o.result), result.success, lay.trackCount(pz), lay.toData());
      const d = save.daily(day);
      const outcomes = result.outcomes.map((o) => o.result);
      track("daily_departure", {
        day,
        departure: d.rows.length,
        solved: result.success,
        crashed: outcomes.filter((o) => o === "crashed").length,
        wrong: outcomes.filter((o) => o === "wrong").length,
      });
      if (save.dailyFinished(day)) {
        const signals = lay.stops.size + lay.lamps.size;
        track("daily_finished", { day, solved: d.solved, departures: d.rows.length, track: d.track, par: pz.par, signals, streak: save.dailyStats(day).streak });
      }
    } else if (!lab) {
      track("level_departure", { level: pz.id, success: result.success });
    }
    board.play(result);
    refresh();
  }

  function finished(): void {
    refresh();
    if (daily) {
      if (save.dailyFinished(day)) showDailyResult();
      else showFailure(true);
    } else if (result?.success) showLevelSuccess();
    else showFailure(false);
  }

  function openOverlay(kind: "card" | "ticket" = "card", label = ""): HTMLElement {
    closeOverlay();
    const o = overlay(kind);
    if (label) o.body.setAttribute("aria-label", label);
    current = o;
    return o.body;
  }

  function closeOverlay(): void {
    current?.close();
    current = null;
    clearInterval(countdownTimer);
  }

  function backToBuilding(): void {
    closeOverlay();
    board.stop();
    if (daily && save.dailyFinished(day)) board.editable = false;
    refresh();
  }

  function showFailure(isDaily: boolean): void {
    const ev = result?.events.find((e) => e.kind !== "arrived");
    const who = LIVERY_NAMES[(ev?.color ?? 0) % 4];
    let title = "CRASH";
    let text = `The ${who} train ran into another train. Try a stop signal or a different route.`;
    if (ev?.kind === "derail") {
      title = "DERAILED";
      text = `The ${who} train ran off the end of its track.`;
    } else if (ev?.kind === "wrong") {
      title = "WRONG PLATFORM";
      text = `The ${who} train reached a platform of another colour.`;
    } else if (ev?.kind === "early") {
      title = "TOO EARLY";
      text = `The ${who} train reached its platform before it opened. Hold it back with a stop signal or a longer route.`;
    } else if (ev?.kind === "lost") {
      title = "STILL RUNNING";
      text = `The ${who} train never reached a platform. Look for loops and trains stuck in a queue.`;
    }
    const b = openOverlay("card", title);
    b.append(h("h2", { style: `color:${title === "WRONG PLATFORM" || title === "TOO EARLY" ? "var(--ticket-soft)" : COLORS.red}` }, title), h("p", { style: "margin:0;line-height:1.4" }, text));
    if (isDaily) {
      const rows = save.daily(day).rows;
      b.append(h("p", { class: "muted", style: "font-weight:600" }, `Departure ${rows.length} of ${DEPARTURES}`), resultRows(rows, 22));
    }
    const ok = h("button", { class: "btn btn-primary btn-wide", onclick: backToBuilding }, "KEEP BUILDING");
    b.append(ok);
    ok.focus();
  }

  function showLevelSuccess(): void {
    const n = lay.trackCount(pz);
    const s = pz.starsFor(n);
    if (lab) return showLabSuccess(n, s);
    track("level_completed", { level: pz.id, line: LEVELS[index].line + 1, stop: LEVELS[index].stop + 1, stars: s, track: n, par: pz.par, first: save.stars(pz.id) === 0 });
    save.setStars(pz.id, s);
    const b = openOverlay("card", "All trains home");
    b.classList.add("center");
    const big = starsSvg(s, 46);
    big.style.alignSelf = "center";
    let msg = `Track ${n}, par ${pz.par}.`;
    if (s < 3) msg += ` Use ${pz.par} or fewer pieces for three stars.`;
    b.append(h("h2", {}, "ALL TRAINS HOME"), big, h("p", { class: "muted" }, msg));
    let primary: HTMLButtonElement;
    const line = LINES[LEVELS[index].line];
    const endOfLine = index + 1 >= LEVELS.length || LEVELS[index + 1].line !== LEVELS[index].line;
    if (index + 1 < LEVELS.length) {
      primary = h("button", { class: "btn btn-primary btn-wide", onclick: () => go(`#/level/${index + 2}`) }, endOfLine ? "NEXT LINE" : "NEXT STOP");
      if (endOfLine) {
        const nextLine = LEVELS[index + 1].line;
        b.append(h("p", { style: "margin:0" }, `That's the whole ${line.name}. Line ${nextLine + 1}, the ${LINES[nextLine].name}, is open.`));
      }
      b.append(primary);
    } else {
      primary = h("button", { class: "btn btn-primary btn-wide", onclick: () => go("#/map") }, "BACK TO THE MAP");
      b.append(h("p", { style: "margin:0" }, `That's the whole ${line.name}, and every line so far. Try today's Daily Wye next.`), primary);
    }
    b.append(h("button", { class: "btn btn-ghost", onclick: backToBuilding }, "Improve this stop"));
    primary.focus();
  }

  // Prototypes keep no stars: just the result and the way to the next one.
  function showLabSuccess(n: number, s: number): void {
    const b = openOverlay("card", "All trains home");
    b.classList.add("center");
    const big = starsSvg(s, 46);
    big.style.alignSelf = "center";
    b.append(h("h2", {}, "ALL TRAINS HOME"), big, h("p", { class: "muted" }, `Track ${n}, par ${pz.par}.`));
    const last = index + 1 >= LAB.length;
    const primary = h("button", { class: "btn btn-primary btn-wide", onclick: () => go(last ? "#/" : `#/lab/${index + 2}`) }, last ? "HOME" : "NEXT PROTOTYPE");
    b.append(primary, h("button", { class: "btn btn-ghost", onclick: backToBuilding }, "Keep building"));
    primary.focus();
  }

  function showDailyResult(focus = true): void {
    const d = save.daily(day);
    const b = openOverlay("ticket", "Daily Wye result");
    b.append(h("div", { class: "card-head" }, h("span", { class: "eyebrow" }, dateLabel(day)), h("span", { class: "number" }, numberLabel(day))));
    if (d.solved) {
      b.append(h("h2", {}, "ALL TRAINS HOME"), h("p", { class: "muted" }, `Solved on departure ${d.rows.length} of ${DEPARTURES} · track ${d.track}, par ${pz.par}`));
    } else {
      b.append(h("h2", {}, "OUT OF DEPARTURES"), h("p", { class: "muted" }, `Six departures used. Par for today was ${pz.par} pieces of track.`));
    }
    b.append(h("div", { style: "border-top:2px dashed var(--ticket-rule)" }), resultRows(d.rows, 30));
    const st = save.dailyStats(today());
    const pct = st.played === 0 ? 0 : Math.round((100 * st.solved) / st.played);
    b.append(
      h(
        "div",
        { class: "stats" },
        ...[
          [String(st.played), "Played"],
          [`${pct}%`, "Solved"],
          [String(st.streak), "Streak"],
          [String(st.best), "Best"],
        ].map(([n, label]) => h("div", {}, h("b", {}, n), h("span", {}, label))),
      ),
    );
    const copy = h("button", { class: "btn btn-primary btn-wide", onclick: copyResult }, "COPY RESULT");
    b.append(copy);
    if (!d.solved) {
      b.append(
        h(
          "button",
          {
            class: "btn btn-ghost",
            onclick: () => {
              closeOverlay();
              board.stop();
              lay = pz.solutionLayout();
              board.setLayout(lay);
              board.editable = false;
              refresh();
            },
          },
          "Show a solution",
        ),
      );
    }
    b.append(h("button", { class: "btn btn-ghost", onclick: backToBuilding }, "Look at the board"));
    if (testMode) b.append(h("button", { class: "btn btn-ghost", onclick: resetToday }, "Reset today's puzzle (test mode)"));
    const countdown = h("p", { class: "muted center", "aria-live": "off" });
    b.append(countdown);
    const tick = () => {
      const s = Math.floor(msUntilTomorrow() / 1000);
      const pad = (v: number) => String(v).padStart(2, "0");
      countdown.textContent = `Next Daily Wye in ${pad(Math.floor(s / 3600))}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`;
    };
    tick();
    countdownTimer = window.setInterval(tick, 1000);
    if (focus) copy.focus();
  }

  function resetToday(): void {
    save.resetDaily(day);
    go("#/daily");
  }

  async function copyResult(): Promise<void> {
    const text = shareText(day, save.daily(day), pz.par);
    const solved = save.daily(day).solved;
    try {
      await navigator.clipboard.writeText(text);
      track("result_copied", { day, solved, method: "clipboard" });
      toast("Result copied. Paste it anywhere.");
    } catch {
      if (navigator.share)
        navigator
          .share({ text })
          .then(() => track("result_copied", { day, solved, method: "share_sheet" }))
          .catch(() => {});
      else toast("Copy is blocked here. Long-press to select the result instead.");
    }
  }

  return {
    el,
    dispose: () => {
      closeOverlay();
      board.stop();
    },
  };
}

function toolIcon(key: Tool | "undo"): SVGSVGElement {
  const paths: Record<string, string> = {
    track: `<path d="M3 17 C9 17 9 5 17 5" fill="none" stroke="currentColor" stroke-width="3.2"/>`,
    signal: `<rect x="6" y="2" width="8" height="12" rx="3" fill="currentColor"/><circle cx="10" cy="8" r="2.4" fill="${COLORS.red}"/><rect x="9" y="14" width="2" height="5" fill="currentColor"/>`,
    erase: `<path d="M4 4 L16 16 M16 4 L4 16" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>`,
    undo: `<path d="M7 5 L3 9 L7 13 M3 9 H12 A5 5 0 0 1 12 19 H9" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>`,
  };
  const t = document.createElement("template");
  t.innerHTML = `<svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">${paths[key]}</svg>`;
  return t.content.firstElementChild as SVGSVGElement;
}
