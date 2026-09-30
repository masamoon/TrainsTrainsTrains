class_name DailyGen
extends RefCounted
## The Daily Line: one puzzle per calendar day, generated from the day number so every
## player gets the same board without a server.
##
## The generator lays out a working solution first (routes found across the grid, with
## crossings and a sorting switch where they meet), checks it in the simulator, adding a
## stop signal if trains collide, and uses its track count as par.

const EPOCH := {"year": 2026, "month": 9, "day": 30} # Daily Line No. 1
const DEPARTURES := 6
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const WEEKDAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]


static func epoch_unix() -> int:
	return Time.get_unix_time_from_datetime_dict(EPOCH)


## Today's puzzle number from the player's local calendar date.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day})
	return maxi(1, int(floor(float(unix - epoch_unix()) / 86400.0)) + 1)


static func seconds_until_tomorrow() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (t.hour * 3600 + t.minute * 60 + t.second)


static func date_dict(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(epoch_unix() + (day - 1) * 86400)


static func date_label(day: int) -> String:
	var d := date_dict(day)
	return "%s %d %s" % [WEEKDAYS[d.weekday], d.day, MONTHS[d.month - 1]]


static func number_label(day: int) -> String:
	return "No. %04d" % day


## Early in the week two lines, midweek three, and a sorting switch at the weekend.
static func profile(day: int) -> Dictionary:
	match int(date_dict(day).weekday):
		1, 2:
			return {"w": 6, "h": 7, "routes": 2, "sort": false, "trains": 1}
		0, 6:
			return {"w": 7, "h": 8, "routes": 2, "sort": true, "trains": 2}
		_:
			return {"w": 7, "h": 8, "routes": 3, "sort": false, "trains": 2}


static func generate(day: int) -> Puzzle:
	var rng := RandomNumberGenerator.new()
	rng.seed = (day * 2654435761 + 97531) % 2147483647
	var prof := profile(day)
	for attempt in 400:
		var pz := _attempt(rng, prof)
		if pz != null:
			pz.id = "daily-%d" % day
			pz.name = "Daily Line " + number_label(day)
			return pz
	return null


static func _attempt(rng: RandomNumberGenerator, prof: Dictionary) -> Puzzle:
	var pz := Puzzle.new()
	pz.w = prof.w
	pz.h = prof.h
	pz.allow_stop = true
	pz.allow_lamp = true
	_place_obstacles(rng, pz)

	var used := {} # Vector2i -> {dirs: Array, crossable: bool}
	var reserved := {} # depot, platform and their port cells
	var paths: Array = []
	var lamps := {}
	var levers := {}
	var color := 0
	for r in prof.routes:
		var dp := _pick_border(rng, pz, reserved, used)
		if dp.is_empty():
			return null
		reserved[dp.pos] = true
		reserved[dp.pos + Puzzle.vec(dp.dir)] = true
		var st := _pick_border(rng, pz, reserved, used, dp)
		if st.is_empty():
			return null
		var path := _route(rng, pz, used, reserved, dp.pos + Puzzle.vec(dp.dir), Puzzle.opp(dp.dir), st.pos + Puzzle.vec(st.dir), Puzzle.opp(st.dir))
		if path.is_empty():
			return null
		reserved[st.pos] = true
		reserved[st.pos + Puzzle.vec(st.dir)] = true
		_mark(used, path)
		var trains: Array = []
		for i in rng.randi_range(1, prof.trains):
			trains.append(color)
		var depot := {"pos": dp.pos, "dir": dp.dir, "trains": trains, "start": rng.randi_range(0, 2), "every": 3}
		pz.depots.append(depot)
		pz.stations.append({"pos": st.pos, "dir": st.dir, "color": color})
		var cells: Array = [dp.pos]
		for step in path:
			cells.append(step.cell)
		cells.append(st.pos)
		paths.append(cells)

		if prof.sort and r == 0:
			var branch := _sort_branch(rng, pz, used, reserved, path, color + 1)
			if branch.is_empty():
				return null
			color += 1
			var sw: Vector2i = branch.switch
			lamps[sw] = color
			levers[sw] = branch.side
			pz.stations.append({"pos": branch.station.pos, "dir": branch.station.dir, "color": color})
			var mix: Array = [color - 1, color, color - 1] if rng.randf() < 0.5 else [color, color - 1, color]
			depot.trains = mix
			depot.every = 4
			var bcells: Array = [sw]
			for step in branch.path:
				bcells.append(step.cell)
			bcells.append(branch.station.pos)
			paths.append(bcells)
		color += 1

	pz.solution = {"paths": paths, "stops": [], "lamps": lamps, "levers": levers}
	pz.rebuild()
	var lay := pz.solution_layout()
	if not Sim.run(pz, lay).success:
		var stop := _find_stop(rng, pz, lay)
		if stop == Vector2i(-1, -1):
			return null
		pz.solution.stops = [stop]
		lay.stops[stop] = true
	pz.par = lay.track_count(pz)
	return pz


static func _place_obstacles(rng: RandomNumberGenerator, pz: Puzzle) -> void:
	var clusters := rng.randi_range(3, 5)
	for i in clusters:
		var roll := rng.randf()
		var kind := "woods" if roll < 0.5 else ("water" if roll < 0.85 else "town")
		var p := Vector2i(rng.randi_range(0, pz.w - 1), rng.randi_range(0, pz.h - 1))
		for j in rng.randi_range(1, 3):
			if pz.inside(p):
				pz.blocked[p] = kind
			p += Puzzle.vec(rng.randi_range(0, 3))


## A depot or platform position on the border (not a corner), facing into the board.
static func _pick_border(rng: RandomNumberGenerator, pz: Puzzle, reserved: Dictionary, used: Dictionary, other := {}) -> Dictionary:
	for tries in 60:
		var side := rng.randi_range(0, 3)
		var pos: Vector2i
		var dir: int
		match side:
			0:
				pos = Vector2i(rng.randi_range(1, pz.w - 2), 0)
				dir = Puzzle.S
			1:
				pos = Vector2i(pz.w - 1, rng.randi_range(1, pz.h - 2))
				dir = Puzzle.W
			2:
				pos = Vector2i(rng.randi_range(1, pz.w - 2), pz.h - 1)
				dir = Puzzle.N
			_:
				pos = Vector2i(0, rng.randi_range(1, pz.h - 2))
				dir = Puzzle.E
		var port := pos + Puzzle.vec(dir)
		if pz.blocked.has(pos) or pz.blocked.has(port) or reserved.has(pos) or reserved.has(port):
			continue
		if used.has(pos) or used.has(port):
			continue
		if not other.is_empty():
			var oport: Vector2i = other.pos + Puzzle.vec(other.dir)
			if other.dir == dir or absi(oport.x - port.x) + absi(oport.y - port.y) < 4:
				continue
		return {"pos": pos, "dir": dir}
	return {}


## Cheapest route from `start` (entered from side `start_in`) to `goal` (left by side
## `goal_out`). Earlier routes may be crossed only at right angles on their straights.
## Returns [{cell, in, out}].
static func _route(rng: RandomNumberGenerator, pz: Puzzle, used: Dictionary, reserved: Dictionary, start: Vector2i, start_in: int, goal: Vector2i, goal_out: int) -> Array:
	var noise := {}
	for y in pz.h:
		for x in pz.w:
			noise[Vector2i(x, y)] = rng.randf() * 0.9
	var start_state := Vector3i(start.x, start.y, start_in)
	var dist := {start_state: 0.0}
	var prev := {}
	var open: Array = [start_state]
	var best_goal := Vector3i(-1, -1, -1)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var cur: Vector3i = open[bi]
		open.remove_at(bi)
		var cell := Vector2i(cur.x, cur.y)
		var in_side := cur.z
		if cell == goal:
			if in_side != goal_out:
				best_goal = cur
				break
			continue
		for out in 4:
			if out == in_side:
				continue
			if used.has(cell) and out != Puzzle.opp(in_side):
				continue # crossing an earlier line must go straight over it
			var nxt := cell + Puzzle.vec(out)
			if not pz.inside(nxt) or pz.blocked.has(nxt):
				continue
			if reserved.has(nxt) and nxt != goal:
				continue
			var step_cost: float = 1.0 + noise[nxt]
			if used.has(nxt):
				var u: Dictionary = used[nxt]
				if not u.crossable or u.dirs.has(out) or u.dirs.has(Puzzle.opp(out)):
					continue
				step_cost += 1.5
			if out != Puzzle.opp(in_side):
				step_cost += 0.15
			var ns := Vector3i(nxt.x, nxt.y, Puzzle.opp(out))
			var nd: float = dist[cur] + step_cost
			if not dist.has(ns) or nd < dist[ns]:
				dist[ns] = nd
				prev[ns] = cur
				if not open.has(ns):
					open.append(ns)
	if best_goal.x < 0:
		return []
	var states: Array = [best_goal]
	while prev.has(states[0]):
		states.push_front(prev[states[0]])
	var path: Array = []
	var seen := {}
	for i in states.size():
		var s: Vector3i = states[i]
		var cell := Vector2i(s.x, s.y)
		if seen.has(cell):
			return []
		seen[cell] = true
		var out := goal_out
		if i + 1 < states.size():
			out = Puzzle.opp(states[i + 1].z)
		if s.z == out:
			return []
		path.append({"cell": cell, "in": s.z, "out": out})
	if path.size() < 3:
		return []
	return path


static func _mark(used: Dictionary, path: Array) -> void:
	for i in path.size():
		var step: Dictionary = path[i]
		if used.has(step.cell):
			used[step.cell].dirs.append_array([step.in, step.out])
			used[step.cell].crossable = false
		else:
			var straight: bool = step.in == Puzzle.opp(step.out)
			var port := i == 0 or i == path.size() - 1
			used[step.cell] = {"dirs": [step.in, step.out], "crossable": straight and not port}


## Turns a curve on route 0 into a switch and routes its new branch to another platform.
static func _sort_branch(rng: RandomNumberGenerator, pz: Puzzle, used: Dictionary, reserved: Dictionary, path: Array, color: int) -> Dictionary:
	var candidates: Array = []
	for i in range(1, path.size() - 1):
		var step: Dictionary = path[i]
		if step.in == Puzzle.opp(step.out) or used[step.cell].dirs.size() != 2:
			continue
		var side := Puzzle.opp(step.out)
		var nxt: Vector2i = step.cell + Puzzle.vec(side)
		if pz.inside(nxt) and not pz.blocked.has(nxt) and not used.has(nxt) and not reserved.has(nxt):
			candidates.append({"switch": step.cell, "side": side, "next": nxt})
	if candidates.is_empty():
		return {}
	for tries in 6:
		var cand: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var st := _pick_border(rng, pz, reserved, used, {"pos": cand.switch, "dir": cand.side})
		if st.is_empty():
			continue
		var bpath := _route(rng, pz, used, reserved, cand.next, Puzzle.opp(cand.side), st.pos + Puzzle.vec(st.dir), Puzzle.opp(st.dir))
		if bpath.is_empty():
			continue
		reserved[st.pos] = true
		reserved[st.pos + Puzzle.vec(st.dir)] = true
		used[cand.switch].dirs.append(cand.side)
		used[cand.switch].crossable = false
		_mark(used, bpath)
		cand.station = st
		cand.path = bpath
		return cand
	return {}


## Looks for one stop signal that removes every collision.
static func _find_stop(rng: RandomNumberGenerator, pz: Puzzle, lay: Layout) -> Vector2i:
	var cells: Array = []
	for path in pz.solution.paths:
		for c in path:
			if pz.buildable(c) and lay.dirs_at(pz, c).size() == 2 and not cells.has(c):
				cells.append(c)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	for c in cells:
		lay.stops[c] = true
		if Sim.run(pz, lay).success:
			lay.stops.erase(c)
			return c
		lay.stops.erase(c)
	return Vector2i(-1, -1)
