# TrainsTrainsTrains: design direction

A small, readable puzzle game. Draw track and set signals so every train reaches the platform of its own colour.
Two ways to play: a campaign of hand-made levels on a line map, and one shared Daily Line puzzle per day.

## Visual identity: "Mimic Panel"

Styled like the illuminated track diagram in a signal box: an enamel panel, inked track, and lamps that show what is set.
Everything is drawn in code (no raster art), so it stays crisp at any size.

| Token | Hex | Use |
| --- | --- | --- |
| Enamel | `#E4E7E1` | screen ground |
| Well | `#F4F5F0` | puzzle board, cards |
| Ink | `#1D2622` | track, text |
| Bezel | `#26332E` | top bars, depots, signal heads |
| Enamel blue | `#1F4F8F` | primary action (Depart, Continue) |
| Ticket | `#F1E2B6` | Daily Line card |
| Lamp green / amber / red | `#2F9A4C` / `#E9A21C` / `#D8432E` | arrived / wrong platform / crashed |
| Lit route | `#FFF4CF` | route ahead of a moving train |

Train liveries always pair a colour with a shape, so the game reads without colour:
Rose `#D94F70` circle, Teal `#178A83` triangle, Violet `#7552C4` square, Tangerine `#E07426` diamond.

Type: Barlow Condensed Bold for titles, station boards and ticket numbers; Barlow for everything else (both SIL OFL, in `assets/fonts`).

## Core puzzle

The board is a small grid (about 7 by 8). Some cells are woods, water or town and cannot hold track.

- **Depots** send out a fixed list of trains, one every few beats.
- **Platforms** accept trains of their own colour. Each has one side it can be entered from.
- **Track** is drawn by dragging between cells. A cell's shape comes from its connections:
  two make a straight or curve, three make a **switch** (a Y whose stem is the odd one out), four make a **crossing**.
- **Switches**: a train coming up the stem goes the way the lever points (tap to flip it). A train coming from either branch merges into the stem.
- **Colour signal** (on a switch): trains of the lamp's colour take the lever's branch, every other train takes the other.
- **Stop signal** (on plain track): a train holds there for two beats, then carries on. This is how you fix timing.

Press **Depart** and the simulation runs in beats. Every train moves one cell per beat.
Two trains in the same cell, or passing through each other, crash. A train that runs off the track derails.
A train that reaches a platform of another colour counts as the wrong platform.
The level is solved when every train reaches its own platform.

Scoring: 3 stars for a solution that uses no more track than par, 2 stars for par plus a little, 1 star for any solution.

## Campaign

A line map in the style of a metro diagram: each level is a stop, completed stops fill in and show their stars.
Each stop teaches at most one new idea, flagged on the map ("New: crossing").

Line 1, Branch Line (first playable):

1. First Light: draw a line from depot to platform.
2. Round the Pond: route around obstacles.
3. Two Lines: two depots, two platforms, keep them apart.
4. The Crossing: two routes must cross.
5. Hold the Line: the routes cross at the same beat; a stop signal fixes it.
6. Junction: two depots share one platform through a merging switch.
7. Sorting Office: one depot sends two colours; a colour signal sorts them.
8. Rush Hour: everything together.

Stops unlock in order. Later lines can add longer trains, one-way track and timed platforms.

## Daily Line

One puzzle for everyone each day, generated from the date, so every player gets the same board with no server.

- Number: days since 30 Sep 2026, starting at No. 0001. Uses the player's local date, as Wordle does.
- Difficulty follows the week: two trains early in the week, three midweek, a colour-sorting switch at the weekend.
- Six departures. Each departure adds a row of squares, one per train: green arrived, amber wrong platform, red crashed or lost.
- The result copies as a short text grid with the puzzle number, departures used, and track against par.
- Stats kept locally: played, solved, current streak, best streak.

The generator builds a working solution first (routes found on the grid, crossings and switches where they meet), checks it in the simulator, then removes the track.
Par is the track count of that solution, so every Daily Line is known to be solvable.
