class_name Sim
extends RefCounted
## Runs a puzzle in beats. Every beat each moving train advances one cell.
##
## - A train that meets a train standing still (held at a signal, or queued) waits behind it.
## - Two trains entering the same cell, or passing through each other, crash.
## - A train that runs off its track derails; one that reaches a platform of another
##   colour counts as the wrong platform.
##
## The result holds one frame per beat for playback plus a per-train outcome.

const HOLD_BEATS := 2
const OUTCOME_ARRIVED := "arrived"
const OUTCOME_WRONG := "wrong"
const OUTCOME_CRASHED := "crashed"


static func run(pz: Puzzle, lay: Layout) -> Dictionary:
	var trains: Array = []
	for di in pz.depots.size():
		var dp: Dictionary = pz.depots[di]
		for i in dp.trains.size():
			trains.append({
				"color": dp.trains[i],
				"depot": di,
				"depart": dp.start + i * dp.every,
				"state": "pending",
				"pos": dp.pos,
				"in": Puzzle.opp(dp.dir),
				"out": dp.dir,
				"hold": 0,
				"end": "",
			})
	trains.sort_custom(func(a, b): return a.depart < b.depart or (a.depart == b.depart and a.depot < b.depot))
	for i in trains.size():
		trains[i].id = i

	var frames: Array = []
	var events: Array = []
	var seen := {}
	var last_depart := 0
	for tr in trains:
		last_depart = maxi(last_depart, tr.depart)
	var max_beats := last_depart + pz.w * pz.h * 3 + 20
	var t := 0
	_spawn(pz, trains, t)
	frames.append(_frame(trains))
	while t < max_beats:
		if not _any_active_or_pending(trains):
			break
		_step(pz, lay, trains, t, events)
		t += 1
		_spawn(pz, trains, t)
		frames.append(_frame(trains))
		for tr in trains:
			if tr.state == "done_now":
				tr.state = "done"
		if not _any_pending(trains):
			var sig := _signature(trains)
			if seen.has(sig):
				break
			seen[sig] = true
	for tr in trains:
		if tr.state == "active" or tr.state == "pending":
			tr.end = OUTCOME_CRASHED
			events.append({"t": t, "kind": "lost", "pos": tr.pos, "color": tr.color})
			tr.state = "done"
	var outcomes: Array = []
	var success := true
	for tr in trains:
		outcomes.append({"color": tr.color, "result": tr.end})
		if tr.end != OUTCOME_ARRIVED:
			success = false
	return {"frames": frames, "events": events, "outcomes": outcomes, "success": success, "beats": t}


static func _any_active_or_pending(trains: Array) -> bool:
	for tr in trains:
		if tr.state == "active" or tr.state == "pending":
			return true
	return false


static func _any_pending(trains: Array) -> bool:
	for tr in trains:
		if tr.state == "pending":
			return true
	return false


static func _signature(trains: Array) -> String:
	var parts: PackedStringArray = []
	for tr in trains:
		if tr.state == "active":
			parts.append("%d:%d,%d,%d,%d" % [tr.id, tr.pos.x, tr.pos.y, tr.out, tr.hold])
	return ";".join(parts)


static func _spawn(pz: Puzzle, trains: Array, t: int) -> void:
	for tr in trains:
		if tr.state != "pending" or tr.depart > t:
			continue
		var occupied := false
		for other in trains:
			if other.state == "active" and other.pos == tr.pos:
				occupied = true
		if occupied:
			tr.depart = t + 1
			continue
		tr.state = "active"
		tr.depart = t


static func _frame(trains: Array) -> Array:
	var out: Array = []
	for tr in trains:
		if tr.state == "active" or tr.state == "done_now":
			out.append({
				"id": tr.id,
				"color": tr.color,
				"pos": tr.pos,
				"in": tr.in,
				"out": tr.out,
				"state": tr.end if tr.state == "done_now" else "moving",
				"hold": tr.hold,
			})
	return out


static func _step(pz: Puzzle, lay: Layout, trains: Array, t: int, events: Array) -> void:
	var movers: Array = []
	for tr in trains:
		if tr.state != "active":
			continue
		var plan := {"tr": tr, "stay": false, "to": tr.pos, "in": tr.in, "out": tr.out, "end": ""}
		if tr.hold > 0:
			plan.stay = true
		else:
			var n: Vector2i = tr.pos + Puzzle.vec(tr.out)
			var entry := Puzzle.opp(tr.out)
			plan.to = n
			plan.in = entry
			var si := pz.station_index_at(n) if pz.inside(n) else -1
			if si >= 0:
				var st: Dictionary = pz.stations[si]
				if st.dir != entry:
					plan.end = "derailed"
				elif st.color == tr.color:
					plan.end = OUTCOME_ARRIVED
				else:
					plan.end = OUTCOME_WRONG
			elif not pz.inside(n) or pz.blocked.has(n) or pz.depot_index_at(n) >= 0:
				plan.end = "derailed"
			else:
				var exit := lay.exit_for(pz, n, entry, tr.color)
				if exit < 0:
					plan.end = "derailed"
				else:
					plan.out = exit
		movers.append(plan)

	# Trains queue behind anything standing still in the cell ahead.
	var changed := true
	while changed:
		changed = false
		var standing := {}
		for plan in movers:
			if plan.stay:
				standing[plan.tr.pos] = true
		for plan in movers:
			if not plan.stay and plan.end != "derailed" and standing.has(plan.to):
				plan.stay = true
				plan.to = plan.tr.pos
				plan.in = plan.tr.in
				plan.out = plan.tr.out
				plan.end = ""
				changed = true

	# Collisions: shared destination cells, and trains passing through each other.
	var crashed := {}
	var by_cell := {}
	for i in movers.size():
		var plan: Dictionary = movers[i]
		if plan.end == "derailed":
			continue
		var cell: Vector2i = plan.to
		if not by_cell.has(cell):
			by_cell[cell] = []
		by_cell[cell].append(i)
	for cell in by_cell:
		if by_cell[cell].size() > 1:
			for i in by_cell[cell]:
				crashed[i] = true
	for i in movers.size():
		for j in range(i + 1, movers.size()):
			var a: Dictionary = movers[i]
			var b: Dictionary = movers[j]
			if a.stay or b.stay or a.end == "derailed" or b.end == "derailed":
				continue
			if a.to == b.tr.pos and b.to == a.tr.pos:
				crashed[i] = true
				crashed[j] = true

	for i in movers.size():
		var plan: Dictionary = movers[i]
		var tr: Dictionary = plan.tr
		tr.pos = plan.to
		tr.in = plan.in
		tr.out = plan.out
		if plan.stay:
			if tr.hold > 0:
				tr.hold -= 1
		elif crashed.has(i):
			_finish(tr, OUTCOME_CRASHED, "crash", t + 1, events)
			continue
		elif plan.end == "derailed":
			_finish(tr, OUTCOME_CRASHED, "derail", t + 1, events)
			continue
		elif plan.end != "":
			_finish(tr, plan.end, plan.end, t + 1, events)
			continue
		elif lay.stops.has(tr.pos):
			tr.hold = HOLD_BEATS


static func _finish(tr: Dictionary, outcome: String, kind: String, t: int, events: Array) -> void:
	tr.state = "done_now"
	tr.end = outcome
	tr.hold = 0
	events.append({"t": t, "kind": kind, "pos": tr.pos, "color": tr.color})
