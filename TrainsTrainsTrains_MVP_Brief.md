# TrainsTrainsTrains

## AI Agent Implementation Brief

Build an MVP for **TrainsTrainsTrains**, a compact rail logistics management game made in **Godot**.

The game is about building small rail networks, placing train signals, diagnosing congestion, and turning completed local maps into a simple regional network. The MVP should prove one core idea:

> It is fun to build tracks, place signals, watch trains move automatically, identify bottlenecks, and fix the network.

Do **not** build a full Transport Tycoon clone. Do **not** build a realistic train simulator. Do **not** build a large sandbox. The MVP should be a small, readable, scenario-based management game.

---

## 1. High-Level Game Concept

**TrainsTrainsTrains** is a rail logistics management game where the player solves compact local rail maps. Each local map focuses on track layout, train routing, signals, throughput, and congestion.

The game has two layers:

### Local Map Layer

The player actively plays a small rail scenario.

They:

- build tracks;
- place stations;
- place signals;
- create train routes;
- buy trains;
- deliver cargo;
- reduce delays;
- prevent deadlocks;
- complete objectives.

### Regional Map Layer

Completed local maps become permanent nodes in a larger regional network.

Each completed node generates simple outputs:

- **Money**
- **Materials**
- **Traffic Load**

The regional layer should stay very simple. It exists to give local maps long-term consequences, not to become a complicated economy.

---

## 2. Target Platform and Engine

Use:

- **Godot 4.x**
- **GDScript**
- **2D top-down view**
- Mouse-first controls, but with mobile/touch-friendly UI assumptions
- Simple, clear, readable graphics
- No 3D simulation for MVP

The game should feel like an animated railway diagram or miniature train board, not a photorealistic simulator.

---

## 3. MVP Scope

The MVP should include:

- One regional map screen
- Three handcrafted local scenarios
- Grid-based or node-based track placement
- Trains that move automatically along routes
- Cargo loading/unloading
- Basic money economy
- Simple materials economy
- Traffic Load / Traffic Capacity system
- Block signals
- Chain signals
- Basic congestion feedback
- Scenario results screen
- Persistent campaign state for completed nodes

The MVP should **not** include:

- procedural maps;
- terrain editing;
- realistic train physics;
- large maps;
- multiplayer;
- research trees;
- dozens of locomotives;
- city simulation;
- complex passenger simulation;
- advanced timetables;
- multiple eras;
- weather;
- politics;
- prestige;
- regional value;
- idle real-time passive income;
- monetization;
- account systems;
- mod support.

---

## 4. Core Design Pillars

### 4.1 Legibility First

Every delay must be explainable.

When a train stops, the player should be able to click it and understand why.

Examples:

- “Waiting because next block is occupied.”
- “Waiting because station platform is full.”
- “Waiting because junction exit is blocked.”
- “Waiting because no valid route exists.”

If the player cannot understand why something is stuck, the game fails.

### 4.2 Signals Are the Main Mechanic

Signals should not be decorative. They are the core management tool.

The player should solve problems by:

- dividing long track into blocks;
- adding passing loops;
- placing chain signals before junctions;
- keeping trains out of deadlock-prone areas;
- increasing throughput.

### 4.3 Small Maps, Meaningful Problems

Each local map should be small enough to understand at a glance.

The fun comes from watching a simple system become strained, then improving it.

### 4.4 Minimal Currencies

Only use:

- **Money**
- **Materials**
- **Traffic Load / Capacity**

Do not add Political Support, Regional Value, Prestige, Influence, etc.

---

## 5. Core Player Loop

Each local scenario follows this loop:

1. Start paused.
2. Read the contract objective.
3. Build initial track.
4. Place stations and signals.
5. Create train route.
6. Buy or assign trains.
7. Unpause.
8. Watch trains run.
9. Bottleneck appears.
10. Player pauses or slows time.
11. Player fixes layout with signals, siding, platforms, or extra track.
12. Demand increases.
13. Network strains again.
14. Player stabilizes the system.
15. Scenario completes.
16. Result screen converts performance into regional outputs.

---

## 6. Regional Map MVP

The regional map is a simple node graph.

Initial graph:

```text
[Coal Valley] ---- [Central Yard] ---- [Steelworks]
```

Each node can be:

- Locked
- Available
- Completed

The regional UI should show:

```text
Money: $X
Materials: Y
Traffic: Load / Capacity
```

Example:

```text
Money: $1,500
Materials: 4
Traffic: 18 / 40
```

### 6.1 Regional Stats

#### Money

Used to start projects, buy trains, and build infrastructure.

#### Materials

Used for stronger upgrades, larger stations, chain signals, or double-track construction.

#### Traffic Load

Represents how much pressure completed local maps add to the regional network.

Example:

```text
Coal Valley complete:
+$500 per cycle
+8 Traffic Load
```

#### Traffic Capacity

Represents how much traffic the regional network can handle.

Example:

```text
Central Yard complete:
+20 Traffic Capacity
```

If Traffic Load exceeds Capacity, show warning:

```text
Network Congested
Income reduced by 20%
Future maps start with extra traffic pressure
```

For MVP, this warning can be mostly cosmetic or apply a simple modifier.

---

## 7. Local Scenario MVP

Implement three handcrafted local maps.

---

### 7.1 Scenario 1: Coal Valley

Purpose:

Teach basic track placement, cargo routing, block signals, and passing loops.

Map concept:

```text
[Coal Mine] ---- single-track valley ---- [Interchange]
```

Player actions:

- connect Coal Mine to Interchange;
- create a freight route;
- buy freight trains;
- place block signals;
- build a passing loop;
- deliver coal.

Objective:

```text
Deliver 80 coal to Interchange.
Keep average train wait time under 40 seconds.
```

Completion reward:

```text
+$500 per cycle
+8 Traffic Load
```

Key teaching moment:

Two trains on a single-track line block each other. The player fixes this with a passing loop and block signals.

---

### 7.2 Scenario 2: Central Yard

Purpose:

Teach junction congestion, platforms, holding sidings, and chain signals.

Map concept:

```text
West Line ----\
               >---- [Central Yard] ---- East Line
South Line ---/
```

Player actions:

- route trains through a central yard;
- add platforms;
- add holding sidings;
- place chain signals before junctions;
- avoid deadlocks.

Objective:

```text
Process 20 trains through the yard.
Avoid deadlocks.
Keep maximum queue length below 4 trains.
```

Completion reward:

```text
+20 Traffic Capacity
```

Key teaching moment:

Block signals before junctions can allow trains to enter and block each other. Chain signals prevent trains from entering unless they can also exit.

---

### 7.3 Scenario 3: Steelworks

Purpose:

Teach a simple cargo chain and mixed freight flow.

Map concept:

```text
[Coal Input] ---- [Steelworks] ---- [Export Platform]
```

Player actions:

- bring coal into Steelworks;
- produce steel;
- export steel;
- manage two cargo flows;
- use block and chain signals to keep input/output moving.

Objective:

```text
Produce and export 40 steel.
Keep average train wait time under 35 seconds.
```

Completion reward:

```text
+$300 per cycle
+3 Materials per cycle
+10 Traffic Load
```

Key teaching moment:

More trains are not always better. Too many trains can overload station approaches and cause congestion.

---

## 8. Core Local Systems

### 8.1 Grid and Track System

Use a 2D grid or node-based graph.

Recommended MVP approach:

- Use a square grid.
- Each track tile stores connections in four directions: North, East, South, West.
- Curves and junctions are represented by connection masks.
- Trains follow graph paths from tile to tile.

Example track tile data:

```gdscript
class_name TrackTileData

var grid_pos: Vector2i
var connections: Array[Vector2i] = []
var has_station: bool = false
var signal: SignalData = null
```

Connection examples:

```text
Straight horizontal: East + West
Straight vertical: North + South
Curve: North + East
T-junction: West + East + South
Crossing: North + East + South + West
```

For MVP, avoid complex diagonals. Orthogonal track is enough.

---

### 8.2 Track Placement

Player should be able to:

- click and drag to place track;
- connect valid neighboring tiles;
- preview track before confirming;
- remove track if no train occupies it;
- place simple junctions automatically when multiple tracks connect.

MVP controls:

```text
Left click / tap: place track
Drag: draw track
Right click / erase mode: remove track
Signal tool: click track to place signal
Station tool: click valid track to place station
```

---

### 8.3 Stations

Station types:

```text
Cargo Station
Interchange / Export Station
Production Station
```

For MVP, passenger stations are optional. Focus on freight first.

Station data:

```gdscript
class_name StationData

var station_id: String
var display_name: String
var grid_pos: Vector2i
var accepted_cargo: Array[String]
var produced_cargo: String
var stored_cargo: Dictionary
var loading_rate: float
var unloading_rate: float
```

Example:

```text
Coal Mine:
Produces coal.
Loads coal into freight trains.

Interchange:
Accepts coal.
Counts toward delivery objective.

Steelworks:
Consumes coal.
Produces steel.

Export Platform:
Accepts steel.
Counts toward delivery objective.
```

---

### 8.4 Cargo

MVP cargo types:

```text
Coal
Steel
```

Coal Valley only uses coal.

Steelworks uses:

```text
Coal input → Steel output
```

Do not add more cargo types for MVP.

Cargo behavior:

- sources generate cargo over time;
- trains load cargo at source stations;
- trains unload cargo at destination stations;
- delivered cargo updates scenario objective.

---

### 8.5 Trains

Train behavior should be automatic.

Train data:

```gdscript
class_name TrainData

var train_id: String
var display_name: String
var cargo_type: String
var cargo_amount: int
var cargo_capacity: int
var speed: float
var route: RouteData
var current_tile: Vector2i
var target_tile: Vector2i
var state: String
var wait_reason: String
```

Train states:

```text
Idle
Moving
WaitingAtSignal
WaitingForPlatform
Loading
Unloading
Blocked
NoRoute
```

Train should move along a precomputed path.

For MVP, trains can move at constant speed between tile centers. No realistic acceleration required.

---

### 8.6 Routes

A route is a loop of station stops.

Example:

```text
Coal Mine → Interchange → Coal Mine
```

Route data:

```gdscript
class_name RouteData

var route_id: String
var stops: Array[String]
var assigned_trains: Array[String]
```

MVP route UI:

1. Select “Create Route.”
2. Click source station.
3. Click destination station.
4. Assign train.
5. Train loops automatically.

No timetable UI.

---

## 9. Signal System

The signal system is the most important MVP feature.

Implement two signal types first:

```text
Block Signal
Chain Signal
```

Priority signals can be added later if time allows.

---

### 9.1 Blocks

Signals divide track into blocks.

A block is a contiguous section of track between signals, stations, or junction boundaries.

Simplified MVP approach:

- Recalculate blocks after track or signal changes.
- Each track tile belongs to one block.
- Each block tracks whether a train occupies or reserves it.

Block data:

```gdscript
class_name TrackBlock

var block_id: int
var tiles: Array[Vector2i]
var occupied_by_train_id: String = ""
var reserved_by_train_id: String = ""
```

---

### 9.2 Block Signal

Rule:

> A train may pass a block signal only if the next block is clear and not reserved by another train.

Block signal states:

```text
Green: next block clear
Red: next block occupied or reserved
```

Use block signals for:

- simple track spacing;
- long mainlines;
- passing loops;
- station exits.

---

### 9.3 Chain Signal

Rule:

> A train may pass a chain signal only if the next block is clear and the train can reserve a clear path through the next junction or decision point.

Simplified MVP implementation:

When a train reaches a chain signal:

1. Check the next block.
2. Continue checking along the train’s planned path until:
   - a normal block signal is reached;
   - a station is reached;
   - a route exit point is reached;
   - an occupied/reserved block is found.
3. Only allow the train to pass if all checked blocks are clear and reservable.

Use chain signals for:

- junction entrances;
- station throats;
- crossings;
- places where a train must not stop inside the next area.

Chain signal states:

```text
Green: path through junction is clear
Red: exit path blocked
```

---

### 9.4 Signal Placement UX

When the player selects the signal tool:

- clicking empty track places a block signal by default;
- a small radial/context menu allows switching to chain signal;
- signal icon should show red/green state;
- hovering/clicking a signal shows:
  - signal type;
  - next block status;
  - reason for red state.

When placing signals, show block overlays.

Example overlays:

```text
Block A
Block B
Block C
```

This is essential for making the system understandable.

---

## 10. Congestion and Feedback

The MVP must explain problems clearly.

When clicking a stopped train, show:

```text
Train 03
State: Waiting at signal
Reason: Next block occupied by Train 01
Suggestion: Add passing loop or split long block with signals
```

When deadlock is detected:

```text
Deadlock detected
Reason: two trains are waiting on each other’s reserved blocks
Suggestion: replace junction entry block signals with chain signals
```

When station congestion occurs:

```text
Station congested
Reason: Interchange platform occupied
Suggestion: add second platform or holding siding
```

### 10.1 Basic Bottleneck Detection

Track:

- average wait time per train;
- total time waiting at red signals;
- number of trains queued before station;
- blocked cargo source storage;
- number of deadlocks.

MVP scenario scoring can use:

```text
Cargo delivered
Average wait time
Deadlock count
Infrastructure cost
Completion time
```

---

## 11. Local Scenario Results

After completion, show a results screen.

Example:

```text
Coal Valley Complete

Coal Delivered: 92 / 80
Average Train Wait: 28s
Deadlocks: 0
Infrastructure Cost: $1,200

Regional Effect:
+$500 per cycle
+8 Traffic Load
```

Scenario quality can adjust outputs later, but for MVP fixed rewards are acceptable.

Optional enhancement:

```text
If average wait < target:
Traffic Load reduced by 1

If deadlocks > 0:
Reliability warning shown
```

---

## 12. Art and UI Direction

Style:

- clean 2D top-down;
- readable tracks;
- chunky miniature trains;
- clear station icons;
- bright signal lights;
- simple cargo icons;
- soft grid;
- no visual clutter.

The player should always be able to see:

- where trains are going;
- what cargo they carry;
- which signals are red/green;
- where queues are forming.

UI should include:

### Local Map HUD

```text
Money
Objective progress
Average wait time
Train count
Pause/play/speed controls
Build tools
Signal tool
Route tool
```

### Regional Map HUD

```text
Money
Materials
Traffic Load / Capacity
Available nodes
Completed nodes
```

---

## 13. Godot Project Architecture

Recommended folder structure:

```text
res://
  scenes/
    main/
      Main.tscn
    regional/
      RegionalMap.tscn
      RegionalNode.tscn
    local/
      LocalMap.tscn
      GridMap.tscn
      Train.tscn
      Station.tscn
      Signal.tscn
      HUD.tscn
    ui/
      BuildToolbar.tscn
      RoutePanel.tscn
      TrainInfoPanel.tscn
      ResultsScreen.tscn

  scripts/
    autoload/
      GameState.gd
      ScenarioManager.gd
      EconomyManager.gd
    rail/
      TrackGraph.gd
      TrackTile.gd
      TrackBlock.gd
      SignalController.gd
      PathFinder.gd
      TrainController.gd
      RouteManager.gd
      StationController.gd
    regional/
      RegionalMapController.gd
      RegionalNodeController.gd
    ui/
      BuildToolbar.gd
      TrainInfoPanel.gd
      ResultsScreen.gd

  data/
    scenarios/
      coal_valley.tres
      central_yard.tres
      steelworks.tres
    regional/
      regional_nodes.tres
```

---

## 14. Suggested Godot Scene Structure

### Main.tscn

Root scene.

Responsibilities:

- load regional map;
- load selected local scenario;
- switch between screens.

Suggested tree:

```text
Main
  RegionalMap
  LocalMap
  ResultsScreen
```

Only one major screen visible at a time.

---

### LocalMap.tscn

Suggested tree:

```text
LocalMap
  GridLayer
  TrackLayer
  StationLayer
  SignalLayer
  TrainLayer
  OverlayLayer
  CanvasLayer
    HUD
    BuildToolbar
    RoutePanel
    TrainInfoPanel
```

---

### Train.tscn

Suggested tree:

```text
Train
  Sprite2D
  CargoIcon
  StateIcon
  CollisionShape2D
```

---

### Signal.tscn

Suggested tree:

```text
Signal
  Sprite2D
  LightSprite
```

Signal visuals:

- green light if passable;
- red light if blocked;
- different icon/shape for block vs chain signal.

---

## 15. Core Classes and Responsibilities

### GameState.gd

Autoload.

Stores campaign state:

```gdscript
var money: int
var materials: int
var traffic_load: int
var traffic_capacity: int
var completed_nodes: Dictionary
```

---

### ScenarioManager.gd

Loads scenario data.

Responsibilities:

- start scenario;
- reset local state;
- check objectives;
- trigger completion;
- send rewards to GameState.

---

### TrackGraph.gd

Maintains rail graph.

Responsibilities:

- store track tiles;
- store connections;
- validate placement;
- update graph after changes;
- provide pathfinding input.

---

### PathFinder.gd

Finds path between stations.

Use A* over track graph.

Inputs:

```text
start tile
destination tile
track graph
```

Outputs:

```text
Array[Vector2i] path
```

---

### SignalController.gd

Handles blocks and signals.

Responsibilities:

- recalculate blocks;
- update signal states;
- check if train can enter next block;
- reserve blocks;
- release blocks;
- support block signals;
- support chain signals.

---

### TrainController.gd

Controls train movement.

Responsibilities:

- follow route;
- request path;
- ask SignalController for permission;
- move tile-to-tile;
- load/unload cargo;
- update wait reason;
- report metrics.

---

### StationController.gd

Handles cargo.

Responsibilities:

- produce cargo;
- store cargo;
- load trains;
- unload trains;
- report delivered cargo to scenario objective.

---

### RouteManager.gd

Stores route definitions.

Responsibilities:

- create route;
- assign train;
- determine next stop;
- request path updates when track changes.

---

## 16. Implementation Milestones

Build in this exact order.

---

### Milestone 1: Static Grid and Track Placement

Goal:

Player can place and remove connected track tiles.

Requirements:

- visible grid;
- track placement tool;
- track removal tool;
- automatic connection masks;
- basic track sprites.

No trains yet.

---

### Milestone 2: Stations and Pathfinding

Goal:

Player can place stations and find path between them.

Requirements:

- station placement;
- station data;
- A* pathfinding over track graph;
- debug path visualization.

---

### Milestone 3: Single Train Movement

Goal:

One train moves from Station A to Station B and loops.

Requirements:

- train entity;
- route data;
- movement along path;
- station stop;
- loading/unloading placeholder.

---

### Milestone 4: Cargo Delivery

Goal:

Train carries coal from source to destination.

Requirements:

- Coal Mine produces coal;
- Interchange accepts coal;
- train loads/unloads;
- objective counts delivered coal.

---

### Milestone 5: Block Signals

Goal:

Two trains can share a route and obey red/green block signals.

Requirements:

- signal placement;
- block calculation;
- block occupancy;
- red/green signal states;
- train waits when next block occupied.

This is the first true fun test.

---

### Milestone 6: Passing Loop Scenario

Goal:

Coal Valley is playable.

Requirements:

- two or three trains;
- single-track conflict;
- passing loop works;
- player can complete coal delivery objective;
- average wait time tracked.

---

### Milestone 7: Chain Signals

Goal:

Junctions can be protected by chain signals.

Requirements:

- chain signal placement;
- path reservation through junction;
- train does not enter junction unless exit path is clear;
- deadlock warning if trains block each other.

---

### Milestone 8: Central Yard Scenario

Goal:

Central Yard teaches chain signals.

Requirements:

- yard map;
- multiple entrances;
- platform congestion;
- queue metric;
- process-trains objective.

---

### Milestone 9: Steelworks Scenario

Goal:

Simple cargo chain works.

Requirements:

- coal input;
- steel production;
- steel export;
- two cargo flows;
- completion objective.

---

### Milestone 10: Regional Map

Goal:

Completed scenarios persist and affect regional stats.

Requirements:

- node graph UI;
- locked/available/completed states;
- money/materials/traffic display;
- scenario rewards applied after completion.

---

## 17. MVP Acceptance Criteria

The MVP is acceptable when:

1. Player can complete Coal Valley.
2. Player can place block signals.
3. Player can create a passing loop that improves train flow.
4. Player can see why trains are stopped.
5. Player can complete Central Yard using chain signals.
6. Player can complete Steelworks and generate Materials.
7. Completing maps updates the regional map.
8. Regional map shows Money, Materials, and Traffic Load / Capacity.
9. The player can understand that completed maps generate benefits but also add traffic pressure.

---

## 18. Critical UX Requirements

Do not hide train logic.

Every train must expose:

```text
Current state
Current cargo
Current route
Current destination
Why it is waiting
```

Every signal must expose:

```text
Signal type
Current color
Reason for red state
Next block status
```

Every scenario must expose:

```text
Objective progress
Average wait time
Deadlocks
Delivered cargo
```

---

## 19. Simplifications Allowed

The AI agent may simplify implementation as long as the core loop remains intact.

Allowed simplifications:

- Orthogonal track only.
- No diagonal track.
- No realistic acceleration.
- No collisions if signal logic prevents conflicts.
- Fixed train speed.
- Fixed station loading time.
- Fixed rewards per scenario.
- Simple icons instead of final art.
- Debug UI acceptable for first prototype.

Not allowed to cut:

- trains moving on player-built tracks;
- automatic route following;
- cargo delivery;
- block signals;
- waiting at red signals;
- understandable wait reasons;
- local scenario completion;
- regional map update.

---

## 20. First Vertical Slice

Before building all three maps, build one vertical slice.

### Coal Valley Vertical Slice

Must include:

- one coal mine;
- one interchange;
- track placement;
- one freight route;
- at least two trains;
- block signals;
- passing loop;
- coal delivery objective;
- average wait time;
- completion screen.

The success test:

> The player sees two trains blocking each other, builds a passing loop, places signals, and watches the system flow better.

Do not proceed to the full MVP until this feels good.

---

## 21. Design Tone

The game should feel:

- clear;
- tactile;
- strategic;
- compact;
- readable;
- management-focused;
- satisfying when congestion is fixed.

The game should not feel:

- like a spreadsheet;
- like a realistic train simulator;
- like an idle game;
- like a city builder;
- like a giant sandbox;
- like a puzzle game with only one correct answer.

The player fantasy is:

> “I designed a small railway system, diagnosed its bottlenecks, fixed it with signals and infrastructure, and now this district strengthens my regional network.”

---

## 22. One-Sentence Implementation Goal

Build a Godot MVP where the player completes three compact train logistics scenarios by placing tracks and signals, then sees each completed map become a regional node that generates Money or Materials while adding Traffic Load to the wider network.
