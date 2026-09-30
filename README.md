# TrainsTrainsTrains

A small puzzle game about drawing track and setting signals so every train reaches the platform of its own colour.
Play the campaign stop by stop, or the Daily Line: one shared puzzle a day with six departures and a result you can share.

**Play it:** https://masamoon.github.io/TrainsTrainsTrains/

**Test mode:** https://masamoon.github.io/TrainsTrainsTrains/?test#/daily adds a "Reset today's puzzle" button to the Daily Line, so you can play today's puzzle again as often as you like. Resetting clears only today's departures; streaks and other days are kept.

The design direction (identity, rules, campaign and daily structure) is in [docs/DESIGN.md](docs/DESIGN.md).
Screenshots are in [docs/screens](docs/screens).

## Project layout

It is a plain TypeScript web app built with Vite. There is no game engine: the board is drawn on a canvas and the rest is HTML and SVG.

- `src/core`: the game with no UI. `puzzle.ts` and `layout.ts` hold a board and the player's track, `sim.ts` runs it beat by beat, `levels.ts` has the campaign, `daily.ts` builds the Daily Line from the date, `save.ts` keeps progress in local storage.
- `src/ui`: screens and drawing. `board.ts` draws the board, takes drag input and plays back a run; `home.ts`, `map.ts` and `play.ts` are the screens.
- `tests/core.test.ts`: rule checks, every campaign stop's reference solution, and more than a year of Daily Line puzzles.
- `e2e`: browser tests that play a stop and a Daily Line, plus the screenshot script.

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

Fonts: Barlow and Barlow Condensed, SIL Open Font License (`public/fonts/OFL.txt`).
