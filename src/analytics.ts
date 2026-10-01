// Anonymous play analytics (PostHog). Off until POSTHOG_KEY is set, and always off in
// test mode (?test) and in automated browsers, so playtests don't count as players.
// No cookies: the anonymous id lives in localStorage next to the save.

import type { PostHog } from "posthog-js";

// Project API key from Wye's own PostHog organization (EU cloud), kept apart from other games. It is public by design.
const POSTHOG_KEY = "phc_xLdpxCcVwSjpA2PqpDW3938TVCAtjgTGtTqvwNZTvtJ2";
const POSTHOG_HOST = "https://eu.i.posthog.com";

type Props = Record<string, string | number | boolean>;

let client: PostHog | null = null;
const queue: [string, Props][] = [];

export function enabled(): boolean {
  if (!POSTHOG_KEY || typeof window === "undefined") return false;
  if (new URLSearchParams(location.search).has("test")) return false;
  return !navigator.webdriver;
}

export function initAnalytics(): void {
  if (!enabled()) return;
  // Loaded on demand so the game never waits on it.
  import("posthog-js")
    .then(({ default: posthog }) => {
      posthog.init(POSTHOG_KEY, {
        api_host: POSTHOG_HOST,
        persistence: "localStorage",
        autocapture: false,
        capture_pageview: false,
        capture_pageleave: false,
        disable_session_recording: true,
      });
      posthog.register({ game: "wye" });
      // Visits that come from a pasted Daily Wye result carry ?ref=share (see PLAY_URL).
      const ref = new URLSearchParams(location.search).get("ref");
      posthog.register_for_session({ ref: ref ?? "direct" });
      client = posthog;
      for (const [event, props] of queue.splice(0)) client.capture(event, props);
    })
    .catch(() => {
      // Blocked by an ad blocker or offline: play on without analytics.
    });
}

export function track(event: string, props: Props = {}): void {
  if (!enabled()) return;
  if (client) client.capture(event, props);
  else if (queue.length < 50) queue.push([event, props]);
}
