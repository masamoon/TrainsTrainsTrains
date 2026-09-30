// Navigation between screens by URL hash.

export function go(route: string): void {
  if (location.hash === route) window.dispatchEvent(new HashChangeEvent("hashchange"));
  else location.hash = route;
}

export interface Screen {
  el: HTMLElement;
  dispose?: () => void;
}
