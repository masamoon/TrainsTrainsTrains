// The campaign line map. Stops unlock in order.

import { dateLabel, numberLabel, today } from "../core/daily";
import { LEVELS, LINES } from "../core/levels";
import type { Save } from "../core/save";
import { COLORS, h, livery, starPoints, starsSvg, svg } from "./dom";
import { type Screen, go } from "./nav";

const W = 400;
const STEP = 124;
const BAND = 104; // room below a line's first stop for its name band and tail
const GAP = 40; // room above a line's last stop
const BOTTOM = 34;

// Stop and name-band positions, drawn bottom to top: Line 1 at the bottom.
const places = (() => {
  const stops: { x: number; y: number }[] = [];
  const bands: number[] = [];
  let y = 0;
  LINES.forEach((ln, line) => {
    bands[line] = y - 26;
    y -= BAND;
    ln.stops.forEach((_, s) => {
      stops.push({ x: W * (s % 2 === 0 ? 0.26 : 0.74), y });
      if (s < ln.stops.length - 1) y -= STEP;
    });
    y -= GAP;
  });
  const height = -y + BOTTOM;
  const shift = (v: number) => v + height - BOTTOM;
  return { stops: stops.map((p) => ({ x: p.x, y: shift(p.y) })), bands: bands.map(shift), height };
})();

const stopPos = (i: number) => places.stops[i];

export function mapScreen(save: Save): Screen {
  const back = h("button", { class: "bar-btn", onclick: () => go("#/") }, "‹ Home");
  const total = h("div", { class: "bar-right", style: "display:flex;align-items:center;gap:6px;padding-right:10px;font-weight:700;font-size:18px" }, starsSvg(1, 18, 1), String(save.totalStars()));
  total.setAttribute("aria-label", `${save.totalStars()} stars`);
  const bar = h("header", { class: "bar" }, back, h("div", { class: "bar-title" }, h("h1", {}, "LINE MAP")), total);

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
    h("div", {}, h("div", { class: "eyebrow" }, `DAILY WYE ${numberLabel(day)} · ${dateLabel(day)}`), h("div", { style: "font-weight:600;font-size:17px" }, status)),
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
  const reached = save.nextLevelIndex();
  const lw = 11;
  let track = "";
  LINES.forEach((ln, line) => {
    const first = LEVELS.findIndex((lv) => lv.line === line);
    const last = first + ln.stops.length - 1;
    const color = livery(ln.color);
    const p0 = stopPos(first);
    const bandY = places.bands[line];
    // Tail from the name band up to the first stop.
    track +=
      first <= reached
        ? `<line x1="${p0.x}" y1="${bandY}" x2="${p0.x}" y2="${p0.y}" stroke="${color}" stroke-width="${lw}"/>`
        : `<line x1="${p0.x}" y1="${bandY}" x2="${p0.x}" y2="${p0.y}" stroke="${COLORS.dot}" stroke-width="${lw * 0.7}" stroke-dasharray="6 10" stroke-linecap="round"/>`;
    for (let i = first; i < last; i++) {
      const a = stopPos(i);
      const b = stopPos(i + 1);
      const d = `M${a.x} ${a.y} C${a.x} ${a.y - STEP / 2} ${b.x} ${b.y + STEP / 2} ${b.x} ${b.y}`;
      track +=
        i < reached
          ? `<path d="${d}" fill="none" stroke="${color}" stroke-width="${lw}"/>`
          : `<path d="${d}" fill="none" stroke="${COLORS.dot}" stroke-width="${lw * 0.7}" stroke-dasharray="6 10" stroke-linecap="round"/>`;
    }
    // Name band: a bezel strip with the line's roundel.
    const open = first <= reached;
    const label = `LINE ${line + 1} · ${ln.name.toUpperCase()}`;
    track += `<rect x="18" y="${bandY - 19}" width="${W - 36}" height="38" rx="9" fill="${open ? COLORS.bezel : "#8d978f"}"/>`;
    track += `<circle cx="42" cy="${bandY}" r="9" fill="${open ? color : COLORS.dot}" stroke="${COLORS.lit}" stroke-width="3"/>`;
    track += `<text x="62" y="${bandY + 7}" font-family="Barlow Condensed" font-weight="700" font-size="19" letter-spacing="0.6" fill="${COLORS.lit}">${label}</text>`;
  });
  const map = svg(`<svg class="map-svg" viewBox="0 0 ${W} ${places.height}" role="group" aria-label="Line map">${track}</svg>`);

  LEVELS.forEach((lv, i) => {
    const c = stopPos(i);
    const line = livery(LINES[lv.line].color);
    const n = lv.stop + 1;
    const left = lv.stop % 2 === 1;
    const tx = left ? c.x - 38 : c.x + 38;
    const anchor = left ? "end" : "start";
    const stars = save.stars(lv.id);
    let g = "";
    if (i < reached) {
      g += `<circle class="hit" cx="${c.x}" cy="${c.y}" r="21" fill="${line}"/>`;
      g += `<text x="${c.x}" y="${c.y + 7}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="21" fill="#fff">${n}</text>`;
      g += `<text x="${tx}" y="${c.y - 3}" text-anchor="${anchor}" font-family="Barlow" font-weight="600" font-size="18" fill="${COLORS.ink}">${lv.name}</text>`;
      for (let s = 0; s < 3; s++) {
        const sx = left ? tx - 3 * 18 + 9 + s * 18 : tx + 9 + s * 18;
        g += `<polygon points="${starPoints(sx, c.y + 16, 8)}" fill="${s < stars ? COLORS.amber : COLORS.dot}"/>`;
      }
    } else if (i === reached) {
      g += `<circle cx="${c.x}" cy="${c.y}" r="34" fill="${line}" fill-opacity="0.18"/>`;
      g += `<circle class="hit" cx="${c.x}" cy="${c.y}" r="24" fill="#fff" stroke="${COLORS.ink}" stroke-width="5.5"/>`;
      g += `<text x="${c.x}" y="${c.y + 8}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="23" fill="${COLORS.ink}">${n}</text>`;
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
      g += `<text x="${c.x}" y="${c.y + 6}" text-anchor="middle" font-family="Barlow Condensed" font-weight="700" font-size="17" fill="#8d978f">${n}</text>`;
      g += `<text x="${tx}" y="${c.y + 6}" text-anchor="${anchor}" font-family="Barlow" font-weight="500" font-size="17" fill="#8d978f">${lv.name}</text>`;
    }
    const open = i <= reached;
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
    group.setAttribute("class", open ? "map-stop" : "map-stop locked");
    group.innerHTML = `<circle cx="${c.x}" cy="${c.y}" r="44" fill="transparent"/>${g}`;
    const where = lv.line > 0 ? `Line ${lv.line + 1}, stop ${n}` : `Stop ${n}`;
    const label = `${where}, ${lv.name}${open ? (i < reached ? `, ${stars} of 3 stars` : ", next") : ", locked"}`;
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
