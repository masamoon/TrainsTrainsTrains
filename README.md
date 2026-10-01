# Wye

_The junction puzzle._ (Formerly the working title TrainsTrainsTrains; the repository keeps that name so the live link stays the same.)

A small puzzle game about drawing track and setting signals so every train reaches the platform of its own colour.
Play the campaign stop by stop, or the Daily Wye: one shared puzzle a day with six departures and a result you can share.

**Play it:** https://masamoon.github.io/TrainsTrainsTrains/

**Test mode:** https://masamoon.github.io/TrainsTrainsTrains/?test#/daily adds a "Reset today's puzzle" button to the Daily Wye, so you can play today's puzzle again as often as you like. Resetting clears only today's departures; streaks and other days are kept.

**Analytics:** `src/analytics.ts` sends anonymous play events to PostHog (screen views, Daily Wye departures and results, copied results, campaign stops). It stays off until `POSTHOG_KEY` is filled in, and it never runs in test mode or in the browser tests, so playtesting doesn't count as players. No cookies are set.

The design direction (identity, rules, campaign and daily structure) is in [docs/DESIGN.md](docs/DESIGN.md).
Screenshots are in [docs/screens](docs/screens).

## Project layout

It is a plain TypeScript web app built with Vite. There is no game engine: the board is drawn on a canvas and the rest is HTML and SVG.

- `src/core`: the game with no UI. `puzzle.ts` and `layout.ts` hold a board and the player's track, `sim.ts` runs it beat by beat, `levels.ts` has the campaign (Lines 1 and 2 by hand, Lines 3 to 13 in `lines/`), `daily.ts` builds the Daily Wye from the date, `save.ts` keeps progress in local storage.
- `src/ui`: screens and drawing. `board.ts` draws the board, takes drag input and plays back a run; `home.ts`, `map.ts` and `play.ts` are the screens.
- `tests/core.test.ts`: rule checks, every campaign stop's reference solution, and more than a year of Daily Wye puzzles.
- `e2e`: browser tests that play a stop and a Daily Wye, plus the screenshot script.
- `tools/campaign`: the level design tools behind Lines 3 to 13 (not shipped). See below.

## Running

Needs Node 22.

```
npm install
npm run dev        # local server with reload
npm test           # unit tests
npm run test:e2e   # browser tests (run `npx playwright install chromium` once first)
npm run build      # production build in dist/
npm run screens    # regenerate docs/screens
```

Every push and pull request runs the tests and the build. Pushes to `main` deploy `dist/` to GitHub Pages.

## Making campaign levels

Lines 3 to 13 were made with a solver rather than drawn square by square. `tools/campaign/plan.ts` gives each stop a recipe (board size, scenery, depots and their trains, and what the puzzle must need, such as a stop signal or the tunnel).
`pick` generates boards for a recipe, solves each one many times with randomised routes, and keeps those whose solve rate is near the stop's target difficulty; `build` re-solves the chosen board harder for a tight par and writes `src/core/lines/lineNN.ts`.

```
tools/campaign/pickall.sh 3 4        # candidates for Lines 3 and 4, into tools/campaign/out
tools/campaign/run.sh build 3 4      # freeze the picks into src/core/lines
npx vite --port 5199 & node tools/campaign/shot.mjs final-3 sheet.png   # contact sheet of a line
```

The frozen files are the source of truth: changing the solver or generator changes what a seed produces, so rebuild a line only to replace it.

Fonts: Barlow and Barlow Condensed, SIL Open Font License (`public/fonts/OFL.txt`).
