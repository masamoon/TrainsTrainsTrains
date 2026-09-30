# TrainsTrainsTrains

A small puzzle game about drawing track and setting signals so every train reaches the platform of its own colour.
Play the campaign stop by stop, or the Daily Line: one shared puzzle a day with six departures and a result you can share.

The design direction (identity, rules, campaign and daily structure) is in [docs/DESIGN.md](docs/DESIGN.md).
Screenshots are in [docs/screens](docs/screens).

## Project layout

- `scripts/core`: the game with no UI. `Puzzle` and `Layout` hold a board and the player's track, `Sim` runs it beat by beat, `Levels` has the campaign, `DailyGen` builds the Daily Line from the date, `Save` keeps progress.
- `scripts/ui`: screens and drawing. Everything is drawn in code from the palette in `Pal.gd`.
- `tests/run_tests.gd`: rule checks, every campaign level's reference solution, and a year of Daily Line puzzles.

## Running

Open the project in Godot 4.5. To run the tests headless:

```
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
```

To regenerate the screenshots (needs a display, for example `xvfb-run`):

```
godot --path . --rendering-method gl_compatibility --resolution 720x1280 --script res://tests/screenshots.gd
```

Pushes to `main` build the web export and deploy it to GitHub Pages. `scripts/serve_web.py` serves a local web export from `build/web`.

Fonts: Barlow and Barlow Condensed, SIL Open Font License (`assets/fonts/OFL.txt`).
