// Tiny DOM helpers and the shared SVG pieces (train tokens, stars, result squares).

import type { Outcome } from "../core/sim";

export const COLORS = {
  enamel: "#e4e7e1",
  well: "#f4f5f0",
  dot: "#c3c9be",
  ink: "#1d2622",
  bezel: "#26332e",
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
};

export const LIVERIES = ["#d94f70", "#178a83", "#7552c4", "#e07426"];
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
export function trainSvg(color: number, width = 36): SVGSVGElement {
  const hgt = width * 0.5;
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
