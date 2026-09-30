// The campaign line map. Stops unlock in order.

import { dateLabel, numberLabel, today } from "../core/daily";
import { LEVELS, LINE_NAME } from "../core/levels";
import type { Save } from "../core/save";
import { COLORS, h, livery, starPoints, starsSvg, svg } from "./dom";
import { type Screen, go } from "./nav";

const W = 400;
const STEP = 124;
const TOP = 70;
const BOTTOM = 90;

const stopPos = (i: number) => ({
  x: W * (i % 2 === 0 ? 0.26 : 0.74),
  y: TOP + (LEVELS.length - 1 - i) * STEP,
});

export function mapScreen(save: Save): Screen {
  const back = h("button", { class: "bar-btn", onclick: () => go("#/") }, "‹ Home");
  const total = h("div", { class: "bar-right", style: "display:flex;align-items:center;gap:6px;padding-right:10px;font-weight:700;font-size:18px" }, starsSvg(1, 18, 1), String(save.totalStars()));
  total.setAttribute("aria-label", `${save.totalStars()} stars`);
  const bar = h(
    "header",
    { class: "bar" },
    back,
    h("div", { class: "bar-title" }, h("h1", {}, `LINE 1 · ${LINE_NAME.toUpperCase()}`)),
    total,
  );

  const map = lineMap(save);
  const scroll = h("div", { class: "map-scroll" }, map);

  const day = today();
  const d = save.daily(day);
  let status = "Not played yet today";
  if (d.solved) status = "Solved today";
  else if (save.dailyFinished(day)) status = "Out of departures";
  else if (d.rows.length > 0) status = "In progress";
  const strip = h(
    "div",
    { class: "strip" },
    h("div", {}, h("div", { class: "eyebrow" }, `DAILY LINE ${numberLabel(day)} · ${dateLabel(day)}`), h("div", { style: "font-weight:600;font-size:17px" }, status)),
    h("button", { class: "btn btn-ticket", style: "min-height:48px;font-size:19px", onclick: () => go("#/daily") }, "BOARD"),
  );

  const el = h("main", { class: "screen" }, bar, scroll, strip);
  // Bring the next stop into view once the map has a size.
  requestAnimationFrame(() => {
    const i = Math.min(save.nextLevelIndex(), LEVELS.length - 1);
    const scale = map.getBoundingClientRect().width / W;
    scroll.scrollTop = Math.max(0, stopPos(i).y * scale - scroll.clientHeight * 0.55);
  });
  return { el };
}

function lineMap(save: Save): SVGSVGElement {
  const n = LEVELS.length;
  const height = TOP + (n - 1) * STEP + BOTTOM;
  const reached = save.nextLevelIndex();
  const line = livery(0);
  const lw = 11;
  const first = stopPos(0);
  let track = `<line x1="${first.x}" y1="${first.y + 60}" x2="${first.x}" y2="${first.y}" stroke="${line}" stroke-width="${lw}" stroke-linecap="round"/>`;
  for (let i = 0; i < n - 1; i++) {
    const a = stopPos(i);
    const b = stopPos(i + 1);
    const d = `M${a.x} ${a.y} C${a.x} ${a.y - STEP / 2} ${b.x} ${b.y + STEP / 2} ${b.x} ${b.y}`;
    track +=
      i < reached
        ? `<path d="${d}" fill="none" stroke="${line}" stroke-width="${lw}"/>`
        : `<path d="${d}" fill="none" stroke="${COLORS.dot}" stroke-width="${lw * 0.7}" stroke-dasharray="6 10" stroke-linecap="round"/>`;
  }
  const map = svg(`<svg class="map-svg" viewBox="0 0 ${W} ${height}" role="group" aria-label="Line 1 stops">${track}</svg>`);

  LEVELS.forEach((lv, i) => {
    const c = stopPos(i);
    const left = i % 2 === 1;
    const tx = left ? c.x - 38 : c.x + 38;
    const anchor = left ? "end" : "start";
    const stars = save.stars(lv.id);
    let g = "";
    if (i < reached) {
      g += `<circle class="hit" cx="${c.x}" cy="${c.y}" r="21" fill="${line}"/>`;
      g += `<text x="${c.x}" y="${c.y + 7}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="21" fill="#fff">${i + 1}</text>`;
      g += `<text x="${tx}" y="${c.y - 3}" text-anchor="${anchor}" font-family="Barlow" font-weight="600" font-size="18" fill="${COLORS.ink}">${lv.name}</text>`;
      for (let s = 0; s < 3; s++) {
        const sx = left ? tx - 3 * 18 + 9 + s * 18 : tx + 9 + s * 18;
        g += `<polygon points="${starPoints(sx, c.y + 16, 8)}" fill="${s < stars ? COLORS.amber : COLORS.dot}"/>`;
      }
    } else if (i === reached) {
      g += `<circle cx="${c.x}" cy="${c.y}" r="34" fill="${line}" fill-opacity="0.18"/>`;
      g += `<circle class="hit" cx="${c.x}" cy="${c.y}" r="24" fill="#fff" stroke="${COLORS.ink}" stroke-width="5.5"/>`;
      g += `<text x="${c.x}" y="${c.y + 8}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="23" fill="${COLORS.ink}">${i + 1}</text>`;
      g += `<text x="${tx}" y="${c.y - 3}" text-anchor="${anchor}" font-family="Barlow" font-weight="700" font-size="19" fill="${COLORS.ink}">${lv.name}</text>`;
      const intro = lv.introTitle ?? "";
      if (intro.startsWith("New: ")) {
        const badge = `NEW · ${intro.slice(5).toUpperCase()}`;
        const bw = badge.length * 7.4 + 16;
        const bx = left ? tx - bw : tx;
        g += `<rect x="${bx}" y="${c.y + 6}" width="${bw}" height="23" rx="6" fill="${COLORS.bezel}"/>`;
        g += `<text x="${bx + 8}" y="${c.y + 23}" font-family="Barlow Condensed" font-weight="700" font-size="14" letter-spacing="0.5" fill="${COLORS.lit}">${badge}</text>`;
      }
    } else {
      g += `<circle cx="${c.x}" cy="${c.y}" r="16" fill="${COLORS.enamel}" stroke="${COLORS.dot}" stroke-width="3"/>`;
      g += `<text x="${c.x}" y="${c.y + 6}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="17" fill="#8d978f">${i + 1}</text>`;
      g += `<text x="${tx}" y="${c.y + 6}" text-anchor="${anchor}" font-family="Barlow" font-weight="500" font-size="17" fill="#8d978f">${lv.name}</text>`;
    }
    const open = i <= reached;
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
    group.setAttribute("class", open ? "map-stop" : "map-stop locked");
    group.innerHTML = `<circle cx="${c.x}" cy="${c.y}" r="44" fill="transparent"/>${g}`;
    const label = `Stop ${i + 1}, ${lv.name}${open ? (i < reached ? `, ${stars} of 3 stars` : ", next") : ", locked"}`;
    group.setAttribute("aria-label", label);
    if (open) {
      group.setAttribute("role", "button");
      group.setAttribute("tabindex", "0");
      const play = () => go(`#/level/${i + 1}`);
      group.addEventListener("click", play);
      group.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          play();
        }
      });
    } else {
      group.setAttribute("role", "img");
    }
    map.append(group);
  });
  return map;
}
