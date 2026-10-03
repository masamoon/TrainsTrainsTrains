# Wye: design direction

A small, readable puzzle game. Draw track and set signals so every train reaches the platform of its own colour.
Two ways to play: a campaign of hand-made levels on a line map, and one shared Daily Wye puzzle per day.

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
| Ticket | `#F1E2B6` | Daily Wye card |
| Lamp green / amber / red | `#2F9A4C` / `#E9A21C` / `#D8432E` | arrived / wrong platform / crashed |
| Lit | `#FFF4CF` | switch lever lamp, depot arrow, text on dark buttons |
| Hill | `#D3C29C` / `#B09D74` | hills (ridges that tunnels run under) |
| Laid | `#E1E5DC` | squares of existing track that came with the level |

Train liveries always pair a colour with a shape, so the game reads without colour:
Rose `#D94F70` circle, Teal `#178A83` triangle, Violet `#7552C4` square, Tangerine `#E07426` diamond.

Type: Barlow Condensed Bold for titles, station boards and ticket numbers; Barlow for everything else (both SIL OFL, in `public/fonts`).

## Core puzzle

The board is a small grid (about 7 by 8). Some cells are woods, water or town and cannot hold track.

- **Depots** send out a fixed list of trains, one every few beats.
- **Platforms** accept trains of their own colour. Each has one side it can be entered from.
- **Track** is drawn by dragging between cells. A cell's shape comes from its connections:
  two make a straight or curve, three make a **switch** (a Y whose stem is the odd one out), four make a **crossing**.
- **Switches**: a train coming up the stem goes the way the lever points (tap to flip it). A train coming from either branch merges into the stem.
- **Colour signal** (on a switch): trains of the lamp's colour take the lever's branch, every other train takes the other.
- **Stop signal** (on plain track): a train holds there for two beats, then carries on. This is how you fix timing.
- **Existing track** (Line 2 on): some levels open with track already laid, on shaded squares.
  It can be built onto (a branch off it makes a switch) but not erased, and it doesn't count toward your track.
- **Tunnels** (Line 2 on): a straight dashed line under a ridge of hills, with a portal at each end, as signal-box diagrams draw them.
  The track outside each portal is already stubbed; join it up and trains run straight through, one square per beat, shown faintly while underground.
  A tunnel is a single track: two trains meeting inside it crash.
- **Goods trains** (Line 2 on): boxy wagons with ribs (square dots at their depot) that move every other beat.
  They change the timing without adding a tool: a goods train sits on a crossing for two beats.
- **Timed platforms** (Line 7 on): a platform with a clock badge opens on the beat shown.
  A train that arrives sooner is turned away (amber, like a wrong platform), so it has to be held back with stop signals or a longer route.
  During a run the badge counts down and turns green once the platform is open.

Press **Depart** and the simulation runs in beats. Every train moves one cell per beat.
Two trains in the same cell, or passing through each other, crash. A train that runs off the track derails.
A train that reaches a platform of another colour counts as the wrong platform.
The level is solved when every train reaches its own platform.

Scoring: 3 stars for a solution that uses no more track than par, 2 stars for par plus a little, 1 star for any solution.

## Campaign

A line map in the style of a metro diagram: each level is a stop, completed stops fill in and show their stars.
Lines stack up the map, each with its own colour and a name band at its foot; stops unlock in order across lines. For now `ALL_OPEN` in `levels.ts` opens every stop so the whole campaign can be played in any order.
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

Line 2, Valley Line (teal):

1. Old Main Line: a line is already laid; branch off it and sort with a colour signal. New: existing track.
2. Passing Loop: two trains head opposite ways down one line; build a loop where they pass (no signals on this stop).
3. Under the Hill: go through the ridge instead of round it. New: tunnel.
4. Single Bore: two trains share the tunnel in opposite directions; hold one back.
5. Slow Goods: a goods train sits on the crossing for two beats. New: goods train.
6. Goods Loop: a passing loop again, but the goods train shifts where the trains meet.
7. Ridge Junction: existing track through a tunnel, sorting on the far side, and a goods train crossing the branch.
8. Valley Rush: everything together; the goods line crosses right in front of the tunnel.

Lines 3 to 13 (eight stops each, 104 stops in all) mix those ideas on bigger boards, one theme per line.
Each line opens on a stop that teaches its idea and ends on a "rush" that uses everything so far.

| Line | Name | Focus |
| --- | --- | --- |
| 3 | Harbour Line | two stop signals in a row, sharing a trunk and sorting it, queues |
| 4 | Market Line | three colours from one depot (two colour signals), merging then sorting |
| 5 | Moor Line | single-line working in corridors, tunnels with crossings |
| 6 | Coal Line | goods trains holding up the trains behind them |
| 7 | Clockwork Line | **New: timed platform** |
| 8 | Junction Line | existing track to cross, branch off or share |
| 9 | Festival Line | the fourth colour (tangerine, diamond) and four-way sorting |
| 10 | Coast Line | larger mixed boards |
| 11 | Summit Line | tunnels with goods trains and timetables |
| 12 | Night Mail | timing-heavy: goods, timed platforms, long sorting runs |
| 13 | Grand Terminus | the hardest mixes |

These lines were generated rather than drawn: `tools/campaign` places depots and platforms on a themed board, solves it many times with randomised routes,
keeps boards whose solve rate matches the stop's place on the difficulty curve and that need what the stop is about (a stop signal, the tunnel, two lamps),
then searches the chosen board harder so par is tight. The chosen levels are frozen as plain data in `src/core/lines/`.

**Free and paid**: the first 20 stops (Line 1, Line 2 and the first four of Line 3) are marked `free` in the level data; the rest are planned as paid packs.
Nothing is gated yet: every stop is open and can be played in any order.

Every stop carries a reference solution. The tests check that it solves for three stars, that every piece of it is one a player could draw,
and, where it uses signals, that it fails without them.

### Mechanics we chose not to add

- **Chain or block signals** (hold until the way ahead is clear): they would solve the timing for the player, which is the puzzle. The stop signal stays the one timing tool.
- **Longer trains, one-way track**: each adds a rule every later level has to explain. Timed platforms were the one deferred idea brought in (Line 7), because they give stop signals a second job without a new tool.

## Daily Wye

One puzzle for everyone each day, generated from the date, so every player gets the same board with no server.

- Number: days since 30 Sep 2026, starting at No. 0001. Uses the player's local date, as Wordle does.
- Difficulty follows the week, above a floor that always needs a signal (below): two lines Monday and Tuesday, three from Wednesday, with a ridge and tunnel on Thursday,
  a goods train on Friday, a colour-sorting switch on Saturday, and sorting plus a tunnel on Sunday.
- Six departures. Each departure adds a row of squares, one per train: green arrived, amber wrong platform, red crashed or lost.
- The result copies as a short text grid with the puzzle number, departures used, and track against par.
- Stats kept locally: played, solved, current streak, best streak.

The generator builds a working solution first (routes found on the grid, crossings and switches where they meet, straight through a tunnel where one is cheaper), checks it in the simulator, then removes the track.
Par is the track count of that solution, so every Daily Wye is known to be solvable.

### Difficulty floor (from No. 0003, 2 Oct 2026)

Every day has to need at least one signal. The generator keeps trying boards until one clears the floor:

- Each depot sends three trains, two or three beats apart, so the lines are busy.
- The generator's own track must crash without a stop signal, and a single stop must fix it.
- A solver (`src/core/solver.ts`) searches every track-only layout of separate lines crossing at right angles. None may get within three pieces of par. Because a detour shifts timing two beats per two pieces, dodging the collision without a signal costs at least four extra pieces.
- Saturday and Sunday also send two colours from one depot, which can't be solved at all without a colour signal.
- A minimum par per weekday keeps boards from being trivially small: Monday 10, Tuesday 13, Wednesday to Friday 16, weekend 15.

No. 0001 and No. 0002 came out before the floor and are generated exactly as they were. The unit tests check the floor on 400 days.
The solver doesn't try lines that share track through switches or loop over themselves; both cost extra track, so within the budget they rarely matter.

## Difficulty lab

`tools/lab/player.ts` models how a person solves a board: draw the short way, Depart, fix the spot where it went wrong, repeat.
A board it solves in one or two Departs is easy however rare a random solution is. `run.sh ../lab/campaign` plays every stop this way.
Prototype boards built to defeat it live in `src/core/lab.ts` (built by `tools/lab/build.ts`) and play at `#/lab/1` onward. They keep no stars and aren't linked from the game. Block-signal boards must pass `tools/lab/recipes.ts`: no brainless recipe (hold at every depot, a signal before every junction, signals everywhere, on the obvious or kept-apart tracks) may solve them, and the deadline is the best run plus at most two beats.
Lab 5 to 7 try **block signals** (`signals: "block"` in level data, lab only): a train on a signal waits until the block ahead, all the track up to the next signals, is empty; two trains wanting one block on the same beat go in departure order.
Without pressure one signal at a depot serialises everything, so these boards also set a **deadline** (`deadline`: every train home by that beat), which turns the puzzle into splitting the line into blocks so trains can run at once.
On these boards each block is shaded its own colour, as a signal box diagram shades its sections, so players can see where a block ends while laying signals.
Block signals are **one-way**, as in TTD: a signal holds only trains heading the way its arrow points, and trains the other way pass it. Every signal still ends a block for everyone. Tapping a square cycles one way (away from the nearest depot), the other way, both ways, off. A one-way signal's square belongs to the block behind it, so a train waiting there still occupies that block; a both-ways signal's square, depots and platforms belong to no block. The builder sets each deadline to the best run plus two beats (less if a recipe would then solve the board), and the recipes also try one-way signals facing the way trains run.
