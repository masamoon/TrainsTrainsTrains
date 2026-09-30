class_name Puzzle
extends RefCounted
## A puzzle board: size, obstacles, depots, platforms and which tools it allows.
## Track the player draws lives in a separate Layout.

const N := 0
const E := 1
const S := 2
const W := 3
const DIR_VECS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_CHARS := "NESW"

var id := ""
var name := ""
var w := 7
var h := 7
var blocked := {} # Vector2i -> "woods" | "water" | "town"
var depots: Array = [] # {pos: Vector2i, dir: int, trains: Array[int], start: int, every: int}
var stations: Array = [] # {pos: Vector2i, dir: int, color: int}
var fixed_edges := {} # edge key -> true, pre-built track the player cannot change
var par := 0
var allow_stop := false
var allow_lamp := false
var intro_title := ""
var intro_text := ""
var solution := {} # {paths: Array, stops: Array, lamps: Dictionary, levers: Dictionary}

var _static_edges := {}
var _fixed_cells := {}


static func vec(d: int) -> Vector2i:
	return DIR_VECS[d]


static func opp(d: int) -> int:
	return (d + 2) % 4


static func dir_between(a: Vector2i, b: Vector2i) -> int:
	var delta := b - a
	for d in 4:
		if DIR_VECS[d] == delta:
			return d
	return -1


## Every edge between two neighbouring cells gets one key: the east or south edge of the
## upper-left cell.
static func edge_key(p: Vector2i, d: int) -> Vector3i:
	match d:
		N:
			return Vector3i(p.x, p.y - 1, 1)
		E:
			return Vector3i(p.x, p.y, 0)
		S:
			return Vector3i(p.x, p.y, 1)
		_:
			return Vector3i(p.x - 1, p.y, 0)


static func edge_cells(key: Vector3i) -> Array:
	var a := Vector2i(key.x, key.y)
	return [a, a + (Vector2i(1, 0) if key.z == 0 else Vector2i(0, 1))]


func rebuild() -> void:
	_static_edges.clear()
	_fixed_cells.clear()
	for dp in depots:
		_static_edges[edge_key(dp.pos, dp.dir)] = true
	for st in stations:
		_static_edges[edge_key(st.pos, st.dir)] = true
	for key in fixed_edges:
		_static_edges[key] = true
		for c in edge_cells(key):
			_fixed_cells[c] = true


func static_edges() -> Dictionary:
	return _static_edges


func is_fixed_cell(p: Vector2i) -> bool:
	return _fixed_cells.has(p)


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


func depot_index_at(p: Vector2i) -> int:
	for i in depots.size():
		if depots[i].pos == p:
			return i
	return -1


func station_index_at(p: Vector2i) -> int:
	for i in stations.size():
		if stations[i].pos == p:
			return i
	return -1


## True for cells that can carry player-drawn track.
func buildable(p: Vector2i) -> bool:
	return inside(p) and not blocked.has(p) and depot_index_at(p) < 0 and station_index_at(p) < 0 and not is_fixed_cell(p)


func colors_used() -> Array:
	var out: Array = []
	for st in stations:
		if not out.has(st.color):
			out.append(st.color)
	out.sort()
	return out


func train_count() -> int:
	var n := 0
	for dp in depots:
		n += dp.trains.size()
	return n


func stars_for(track: int) -> int:
	if track <= par:
		return 3
	if track <= par + maxi(2, int(ceil(par * 0.25))):
		return 2
	return 1


func solution_layout() -> Layout:
	var lay := Layout.new()
	for path in solution.get("paths", []):
		for i in range(path.size() - 1):
			var d := dir_between(path[i], path[i + 1])
			var key := edge_key(path[i], d)
			if not _static_edges.has(key):
				lay.edges[key] = true
	for p in solution.get("stops", []):
		lay.stops[p] = true
	var lamps: Dictionary = solution.get("lamps", {})
	for p in lamps:
		lay.lamps[p] = lamps[p]
	var levers: Dictionary = solution.get("levers", {})
	for p in levers:
		lay.levers[p] = levers[p]
	return lay


## Builds a puzzle from compact level data. `rows` uses "." for open ground, "T" woods,
## "~" water and "H" town. Directions are single letters N, E, S, W.
static func from_data(data: Dictionary) -> Puzzle:
	var pz := Puzzle.new()
	pz.id = data.get("id", "")
	pz.name = data.get("name", "")
	var rows: Array = data.rows
	pz.h = rows.size()
	pz.w = String(rows[0]).length()
	for y in pz.h:
		var row := String(rows[y])
		for x in pz.w:
			match row[x]:
				"T":
					pz.blocked[Vector2i(x, y)] = "woods"
				"~":
					pz.blocked[Vector2i(x, y)] = "water"
				"H":
					pz.blocked[Vector2i(x, y)] = "town"
	for dp in data.get("depots", []):
		pz.depots.append({
			"pos": Vector2i(dp.at[0], dp.at[1]),
			"dir": DIR_CHARS.find(dp.dir),
			"trains": dp.trains.duplicate(),
			"start": dp.get("start", 0),
			"every": dp.get("every", 3),
		})
	for st in data.get("stations", []):
		pz.stations.append({
			"pos": Vector2i(st.at[0], st.at[1]),
			"dir": DIR_CHARS.find(st.dir),
			"color": st.color,
		})
	pz.allow_stop = data.get("allow_stop", false)
	pz.allow_lamp = data.get("allow_lamp", false)
	pz.intro_title = data.get("intro_title", "")
	pz.intro_text = data.get("intro_text", "")
	var sol: Dictionary = data.get("solution", {})
	var paths: Array = []
	for path in sol.get("paths", []):
		var cells: Array = []
		for c in path:
			cells.append(Vector2i(c[0], c[1]))
		paths.append(cells)
	var stops: Array = []
	for c in sol.get("stops", []):
		stops.append(Vector2i(c[0], c[1]))
	var lamps := {}
	for entry in sol.get("lamps", []):
		lamps[Vector2i(entry[0], entry[1])] = entry[2]
	var levers := {}
	for entry in sol.get("levers", []):
		levers[Vector2i(entry[0], entry[1])] = DIR_CHARS.find(entry[2])
	pz.solution = {"paths": paths, "stops": stops, "lamps": lamps, "levers": levers}
	pz.rebuild()
	pz.par = data.get("par", 0)
	if pz.par <= 0:
		pz.par = pz.solution_layout().track_count(pz)
	return pz
