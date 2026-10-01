// Tiny DOM helpers and the shared SVG pieces (train tokens, stars, result squares).

import type { Outcome } from "../core/sim";

export const COLORS = {
  enamel: "#e4e7e1",
  well: "#f4f5f0",
  dot: "#c3c9be",
  ink: "#1d2622",
  bezel: "#26332e",
  bezelSoft: "#b9c3bd",
  lit: "#fff4cf",
  green: "#2f9a4c",
  amber: "#e9a21c",
  red: "#d8432e",
  woods: "#a7b697",
  woodsDark: "#7f9170",
  water: "#a9c7d0",
  waterDark: "#7fa8b5",
  town: "#c9bfb0",
  townDark: "#a89c8a",
  hill: "#d3c29c",
  hillDark: "#b09d74",
  fixed: "#e1e5dc",
};

const LIVERIES = ["#d94f70", "#178a83", "#7552c4", "#e07426"];
export const LIVERY_NAMES = ["Rose", "Teal", "Violet", "Tangerine"];
export const livery = (c: number): string => LIVERIES[c % LIVERIES.length];

export function outcomeColor(r: Outcome): string {
  return r === "arrived" ? COLORS.green : r === "wrong" ? COLORS.amber : COLORS.red;
}

type Child = Node | string | null | undefined | false;

export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Record<string, unknown> = {},
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on") && typeof v === "function") {
      el.addEventListener(k.slice(2).toLowerCase(), v as EventListener);
    } else if (k === "class") {
      el.className = String(v);
    } else if (k === "style") {
      el.setAttribute("style", String(v));
    } else {
      el.setAttribute(k, v === true ? "" : String(v));
    }
  }
  for (const c of children) if (c !== null && c !== undefined && c !== false) el.append(c);
  return el;
}

export function svg(markup: string): SVGSVGElement {
  const t = document.createElement("template");
  t.innerHTML = markup.trim();
  return t.content.firstElementChild as SVGSVGElement;
}

// The white shape that pairs with each livery, so colour is never the only cue.
export function glyphPath(color: number, cx: number, cy: number, r: number): string {
  switch (color % 4) {
    case 0:
      return `<circle cx="${cx}" cy="${cy}" r="${r}"/>`;
    case 1:
      return `<path d="M${cx} ${cy - r * 1.1} L${cx + r * 1.05} ${cy + r * 0.8} L${cx - r * 1.05} ${cy + r * 0.8} Z"/>`;
    case 2:
      return `<rect x="${cx - r * 0.9}" y="${cy - r * 0.9}" width="${r * 1.8}" height="${r * 1.8}" rx="${r * 0.2}"/>`;
    default:
      return `<path d="M${cx} ${cy - r * 1.2} L${cx + r * 1.2} ${cy} L${cx} ${cy + r * 1.2} L${cx - r * 1.2} ${cy} Z"/>`;
  }
}

// A train seen from the side of the track: capsule, front window, its shape.
// Goods trains are boxy wagons with ribs.
export function trainSvg(color: number, width = 36, goods = false): SVGSVGElement {
  const hgt = width * 0.5;
  if (goods) {
    return svg(`<svg width="${width}" height="${hgt}" viewBox="0 0 40 20" aria-hidden="true">
    <rect x="0" y="1" width="40" height="18" rx="2.5" fill="${livery(color)}"/>
    <rect x="5" y="4" width="2.4" height="12" fill="rgba(0,0,0,0.22)"/><rect x="32.6" y="4" width="2.4" height="12" fill="rgba(0,0,0,0.22)"/>
    <g fill="#fff">${glyphPath(color, 20, 10, 3.6)}</g></svg>`);
  }
  return svg(`<svg width="${width}" height="${hgt}" viewBox="0 0 40 20" aria-hidden="true">
    <rect x="0" y="1" width="40" height="18" rx="9" fill="${livery(color)}"/>
    <rect x="28" y="5" width="7" height="10" rx="2.5" fill="#fff"/>
    <g fill="#fff">${glyphPath(color, 14, 10, 3.6)}</g></svg>`);
}

export function starPoints(cx: number, cy: number, r: number): string {
  const pts: string[] = [];
  for (let i = 0; i < 10; i++) {
    const rr = i % 2 === 0 ? r : r * 0.45;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    pts.push(`${(cx + Math.cos(a) * rr).toFixed(2)},${(cy + Math.sin(a) * rr).toFixed(2)}`);
  }
  return pts.join(" ");
}

export function starsSvg(filled: number, size = 20, count = 3): SVGSVGElement {
  const gap = size * 0.25;
  const w = count * size + (count - 1) * gap;
  let body = "";
  for (let i = 0; i < count; i++) {
    const cx = size / 2 + i * (size + gap);
    body += `<polygon points="${starPoints(cx, size / 2, size / 2)}" fill="${i < filled ? COLORS.amber : COLORS.dot}"/>`;
  }
  return svg(
    `<svg width="${w}" height="${size}" viewBox="0 0 ${w} ${size}" role="img" aria-label="${filled} of ${count} stars">${body}</svg>`,
  );
}

export function resultRows(rows: Outcome[][], square = 36): HTMLElement {
  const labels: Record<Outcome, string> = { arrived: "arrived", wrong: "wrong platform", crashed: "crashed" };
  return h(
    "div",
    { class: "rows", role: "img", "aria-label": rows.map((r, i) => `Departure ${i + 1}: ${r.map((o) => labels[o]).join(", ")}`).join(". ") },
    ...rows.map((row) =>
      h("div", {}, ...row.map((o) => h("i", { style: `width:${square}px;height:${square}px;background:${outcomeColor(o)}` }))),
    ),
  );
}

let toastTimer = 0;
export function toast(text: string): void {
  let el = document.querySelector<HTMLElement>(".toast");
  if (!el) {
    el = h("div", { class: "toast", role: "status", "aria-live": "polite" });
    document.body.append(el);
  }
  el.textContent = text;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el!.classList.remove("show"), 2400);
}

export function overlay(kind: "card" | "ticket" = "card"): { root: HTMLElement; body: HTMLElement; close: () => void } {
  const body = h("div", { class: kind, role: "dialog", "aria-modal": "true" });
  const root = h("div", { class: "dim" }, body);
  document.body.append(root);
  return { root, body, close: () => root.remove() };
}

// The Wye mark: the letter Y drawn as track, one line splitting in two at a switch,
// with a Rose and a Teal lamp on the branches. The favicon is the same drawing.
export function wyeMark(size = 64, label?: string): SVGSVGElement {
  const a11y = label ? `role="img" aria-label="${label}"` : `aria-hidden="true"`;
  return svg(`<svg width="${size}" height="${size}" viewBox="0 0 64 64" ${a11y}>
    <rect width="64" height="64" rx="14" fill="${COLORS.bezel}"/>
    <path d="M32 56 V36 C32 28 26 24 18 18 M32 36 C32 28 38 24 46 18" fill="none" stroke="${COLORS.lit}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="32" cy="36" r="3.2" fill="${COLORS.bezel}"/>
    <circle cx="15" cy="15" r="7" fill="${livery(0)}"/><g fill="#fff">${glyphPath(0, 15, 15, 2.6)}</g>
    <circle cx="49" cy="15" r="7" fill="${livery(1)}"/><g fill="#fff">${glyphPath(1, 49, 15, 2.6)}</g>
  </svg>`);
}

// The pitch in one picture: a Rose train held at a red stop signal while a Teal
// train takes the other branch of the junction. Shown on the home screen and in
// the link preview image, so the first thing anyone sees is a signal doing its job.
export function signalScene(label = "A Rose train waits at a red signal while a Teal train takes the branch"): SVGSVGElement {
  const train = (x: number, y: number, c: number): string =>
    `<rect x="${x}" y="${y - 9}" width="40" height="18" rx="9" fill="${livery(c)}"/>` +
    `<rect x="${x + 28}" y="${y - 5}" width="7" height="10" rx="2.5" fill="#fff"/>` +
    `<g fill="#fff">${glyphPath(c, x + 14, y, 3.6)}</g>`;
  return svg(`<svg viewBox="0 0 320 76" width="100%" role="img" aria-label="${label}">
    <rect width="320" height="76" rx="14" fill="${COLORS.bezel}"/>
    <path d="M14 54 H306 M150 54 C176 54 186 24 212 24 H306" fill="none" stroke="${COLORS.lit}" stroke-width="5" stroke-linecap="round"/>
    <circle cx="150" cy="54" r="3" fill="${COLORS.bezel}"/>
    ${train(66, 54, 0)}
    <path d="M122 46 V33" stroke="${COLORS.bezelSoft}" stroke-width="2.5" stroke-linecap="round"/>
    <circle cx="122" cy="26" r="11" fill="${COLORS.red}" opacity="0.28"/>
    <circle cx="122" cy="26" r="7.5" fill="#131b18"/>
    <circle cx="122" cy="26" r="5" fill="${COLORS.red}"/>
    ${train(236, 24, 1)}
  </svg>`);
}
