class_name Layout
extends RefCounted
## What the player has built on a puzzle: track edges, switch levers, colour lamps and
## stop signals. A cell's shape comes from how many of its sides are connected:
## two make a straight or curve, three a switch (a Y whose stem is the odd side out),
## four a crossing.

var edges := {} # Puzzle.edge_key -> true
var levers := {} # Vector2i -> branch direction
var lamps := {} # Vector2i -> colour index
var stops := {} # Vector2i -> true


func dirs_at(pz: Puzzle, p: Vector2i) -> Array:
	var out: Array = []
	var fixed := pz.static_edges()
	for d in 4:
		var key := Puzzle.edge_key(p, d)
		if edges.has(key) or fixed.has(key):
			out.append(d)
	return out


static func switch_stem(dirs: Array) -> int:
	if dirs.size() != 3:
		return -1
	for d in dirs:
		if not dirs.has(Puzzle.opp(d)):
			return d
	return -1


static func switch_branches(dirs: Array) -> Array:
	var stem := switch_stem(dirs)
	var out: Array = []
	for d in dirs:
		if d != stem:
			out.append(d)
	return out


## The branch a switch's lever points to. Defaults to the first branch clockwise from the stem.
func lever_branch(pz: Puzzle, p: Vector2i) -> int:
	var dirs := dirs_at(pz, p)
	var branches := switch_branches(dirs)
	if branches.is_empty():
		return -1
	if levers.has(p) and branches.has(levers[p]):
		return levers[p]
	var stem := switch_stem(dirs)
	for i in range(1, 4):
		var d := (stem + i) % 4
		if branches.has(d):
			return d
	return branches[0]


## The side a train leaves `p` by, having entered from side `entry`. -1 means it cannot.
func exit_for(pz: Puzzle, p: Vector2i, entry: int, color: int) -> int:
	var dirs := dirs_at(pz, p)
	if not dirs.has(entry):
		return -1
	match dirs.size():
		2:
			return dirs[1] if dirs[0] == entry else dirs[0]
		3:
			var stem := switch_stem(dirs)
			if entry != stem:
				return stem
			var lever := lever_branch(pz, p)
			if lamps.has(p) and lamps[p] != color:
				for b in switch_branches(dirs):
					if b != lever:
						return b
			return lever
		4:
			return Puzzle.opp(entry)
	return -1


func flip_lever(pz: Puzzle, p: Vector2i) -> bool:
	var branches := switch_branches(dirs_at(pz, p))
	if branches.size() != 2:
		return false
	var current := lever_branch(pz, p)
	levers[p] = branches[1] if branches[0] == current else branches[0]
	return true


func player_dirs_at(pz: Puzzle, p: Vector2i) -> Array:
	var out: Array = []
	for d in 4:
		if edges.has(Puzzle.edge_key(p, d)):
			out.append(d)
	return out


## Adds track between two neighbouring cells. Returns true if anything changed.
func connect_cells(pz: Puzzle, a: Vector2i, b: Vector2i) -> bool:
	var d := Puzzle.dir_between(a, b)
	if d < 0 or not pz.inside(a) or not pz.inside(b):
		return false
	var key := Puzzle.edge_key(a, d)
	if edges.has(key) or pz.static_edges().has(key):
		return false
	if not pz.buildable(a) or not pz.buildable(b):
		return false
	edges[key] = true
	_tidy(pz, a)
	_tidy(pz, b)
	return true


## Removes all player track touching a cell, plus its signals.
func clear_cell(pz: Puzzle, p: Vector2i) -> bool:
	var changed := false
	for d in 4:
		var key := Puzzle.edge_key(p, d)
		if edges.has(key):
			edges.erase(key)
			changed = true
			_tidy(pz, p + Puzzle.vec(d))
	for dict in [levers, lamps, stops]:
		if dict.has(p):
			dict.erase(p)
			changed = true
	return changed


## Drops signals that no longer fit the cell's shape.
func _tidy(pz: Puzzle, p: Vector2i) -> void:
	var n := dirs_at(pz, p).size()
	if n != 3:
		levers.erase(p)
		lamps.erase(p)
	if n != 2:
		stops.erase(p)


## Track pieces the player placed: every buildable cell with at least one drawn edge.
func track_count(pz: Puzzle) -> int:
	var cells := {}
	for key in edges:
		for c in Puzzle.edge_cells(key):
			if pz.buildable(c):
				cells[c] = true
	return cells.size()


func duplicate_layout() -> Layout:
	var lay := Layout.new()
	lay.edges = edges.duplicate()
	lay.levers = levers.duplicate()
	lay.lamps = lamps.duplicate()
	lay.stops = stops.duplicate()
	return lay


func to_dict() -> Dictionary:
	var e: Array = []
	for key in edges:
		e.append([key.x, key.y, key.z])
	var lv: Array = []
	for p in levers:
		lv.append([p.x, p.y, levers[p]])
	var lm: Array = []
	for p in lamps:
		lm.append([p.x, p.y, lamps[p]])
	var st: Array = []
	for p in stops:
		st.append([p.x, p.y])
	return {"edges": e, "levers": lv, "lamps": lm, "stops": st}


static func from_dict(data: Dictionary) -> Layout:
	var lay := Layout.new()
	for e in data.get("edges", []):
		lay.edges[Vector3i(int(e[0]), int(e[1]), int(e[2]))] = true
	for v in data.get("levers", []):
		lay.levers[Vector2i(int(v[0]), int(v[1]))] = int(v[2])
	for v in data.get("lamps", []):
		lay.lamps[Vector2i(int(v[0]), int(v[1]))] = int(v[2])
	for v in data.get("stops", []):
		lay.stops[Vector2i(int(v[0]), int(v[1]))] = true
	return lay
