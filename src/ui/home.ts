// Home: the wordmark, the campaign card and today's Daily Line ticket.

import { DEPARTURES, dateLabel, numberLabel, today } from "../core/daily";
import { LEVELS, LINE_NAME } from "../core/levels";
import type { Save } from "../core/save";
import { COLORS, h, livery, overlay, svg, trainSvg } from "./dom";
import { type Screen, go } from "./nav";

export function homeScreen(save: Save): Screen {
  const wordmark = h(
    "h1",
    { class: "wordmark", "aria-label": "TrainsTrainsTrains" },
    ...[0, 1, 2].map((i) => h("span", { style: `padding-left:${i * 24}px`, "aria-hidden": "true" }, trainSvg(i, 44), "TRAINS")),
  );

  const next = save.nextLevelIndex();
  const campaign = h(
    "section",
    { class: "card" },
    h("div", { class: "card-head" }, h("span", { class: "eyebrow" }, "CAMPAIGN"), h("span", { style: "font-weight:600" }, `${save.totalStars()} of ${LEVELS.length * 3} stars`)),
    h("h2", {}, `LINE 1 · ${LINE_NAME.toUpperCase()}`),
    progress(next),
    h("p", { class: "muted" }, next >= LEVELS.length ? "Every stop cleared. Replay any stop for more stars." : `Next stop: ${LEVELS[next].name}`),
    h("button", { class: "btn btn-primary btn-wide", onclick: () => go("#/map") }, next > 0 ? "CONTINUE" : "START"),
  );

  const day = today();
  const d = save.daily(day);
  let blurb = "One puzzle for everyone today. Six departures to get every train home.";
  if (d.solved) blurb = `Solved on departure ${d.rows.length} of ${DEPARTURES}. A new line opens at midnight.`;
  else if (d.rows.length >= DEPARTURES) blurb = "Out of departures today. A new line opens at midnight.";
  else if (d.rows.length > 0) blurb = `${d.rows.length} of ${DEPARTURES} departures used. Keep going.`;
  const streak = save.dailyStats(day).streak;
  const ticket = h(
    "section",
    { class: "ticket" },
    h("div", { class: "card-head" }, h("span", { class: "eyebrow" }, "DAILY LINE"), h("span", { class: "number" }, numberLabel(day))),
    h("h2", { class: "display", style: "margin:0;font-size:30px;line-height:1" }, dateLabel(day)),
    h("p", { class: "muted" }, blurb),
    h(
      "div",
      { class: "ticket-foot" },
      h("div", {}, h("div", { class: "eyebrow", style: "letter-spacing:0;font-family:var(--body);font-weight:500" }, "Streak"), h("div", { class: "display", style: "font-size:26px" }, `${streak} DAY${streak === 1 ? "" : "S"}`)),
      h("button", { class: "btn btn-ticket", onclick: () => go("#/daily") }, save.dailyFinished(day) ? "SEE RESULT" : "BOARD"),
    ),
  );

  const help = h("button", { class: "btn btn-ghost", style: "align-self:center", onclick: showHelp }, "How to play");
  const el = h("main", { class: "screen home" }, h("div", { class: "col" }, wordmark, campaign, ticket, help));
  return { el };
}

function showHelp(): void {
  const o = overlay();
  const lines = [
    "Drag across squares to lay track from each depot to the platform of the same colour and shape.",
    "Join three sides of a square to make a switch. Tap it to flip the lever.",
    "Signal adds a stop signal to a straight or curve (a train holds two beats), or a colour lamp to a switch (that colour follows the lever, others take the other branch).",
    "Press Depart. Trains move one square per beat. Two trains in one square crash.",
    "Use no more track than par for three stars.",
  ];
  o.body.setAttribute("aria-label", "How to play");
  o.body.append(
    h("h2", {}, "HOW TO PLAY"),
    ...lines.map((t) => h("p", { style: "margin:0;line-height:1.4" }, t)),
    h("button", { class: "btn btn-primary btn-wide", onclick: o.close }, "GOT IT"),
  );
  o.body.querySelector("button")?.focus();
}

// Campaign progress as a short line of stops.
function progress(reached: number): SVGSVGElement {
  const n = LEVELS.length;
  const w = 320;
  const y = 12;
  const stepX = (w - 24) / (n - 1);
  const cut = 12 + stepX * Math.min(reached, n - 1);
  const line = livery(0);
  let body = `<line x1="12" y1="${y}" x2="${cut}" y2="${y}" stroke="${line}" stroke-width="6" stroke-linecap="round"/>`;
  if (cut < w - 12) body += `<line x1="${cut}" y1="${y}" x2="${w - 12}" y2="${y}" stroke="${COLORS.dot}" stroke-width="5" stroke-dasharray="3 7" stroke-linecap="round"/>`;
  for (let i = 0; i < n; i++) {
    const cx = 12 + stepX * i;
    if (i < reached) body += `<circle cx="${cx}" cy="${y}" r="7" fill="${line}"/>`;
    else if (i === reached) body += `<circle cx="${cx}" cy="${y}" r="7.5" fill="#fff" stroke="${COLORS.ink}" stroke-width="3.5"/>`;
    else body += `<circle cx="${cx}" cy="${y}" r="5" fill="${COLORS.enamel}" stroke="${COLORS.dot}" stroke-width="2"/>`;
  }
  return svg(
    `<svg viewBox="0 0 ${w} 24" width="100%" role="img" aria-label="${Math.min(reached, n)} of ${n} stops cleared">${body}</svg>`,
  );
}
