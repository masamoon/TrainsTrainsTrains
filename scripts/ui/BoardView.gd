class_name BoardView
extends Control
## Draws a puzzle and the player's layout, takes drawing input, and plays back a
## simulation run.

signal edited(before: Dictionary)
signal hint(text: String)
signal playback_finished

const BEAT := 0.3

var pz: Puzzle
var lay: Layout = Layout.new()
var tool := "track"
var editable := true
var fast := false

var cell := 48.0
var origin := Vector2.ZERO

var _pressing := false
var _dragged := false
var _press_cell := Vector2i(-1, -1)
var _last_cell := Vector2i(-1, -1)
var _before := {}
var _changed := false

var _run := {}
var _clock := 0.0
var _playing := false
var _effects: Array = []
var _fired_beat := -1


func setup(puzzle: Puzzle, layout: Layout) -> void:
	pz = puzzle
	lay = layout
	stop_playback()
	_layout_board()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout_board)


func _layout_board() -> void:
	if pz == null:
		return
	cell = floor(minf(size.x / pz.w, size.y / pz.h))
	origin = ((size - Vector2(pz.w, pz.h) * cell) / 2).floor()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(200, 200)


# Geometry

func center(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell


func side_mid(p: Vector2i, d: int) -> Vector2:
	return center(p) + Vector2(Puzzle.vec(d)) * cell * 0.5


## A point along the piece in cell `p` that runs from side `a` to side `b`.
func path_point(p: Vector2i, a: int, b: int, t: float) -> Vector2:
	var p0 := side_mid(p, a)
	var p2 := side_mid(p, b)
	if a == Puzzle.opp(b):
		return p0.lerp(p2, t)
	var c := center(p)
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * c + t * t * p2


func cell_at(pos: Vector2) -> Vector2i:
	var rel := (pos - origin) / cell
	return Vector2i(floori(rel.x), floori(rel.y))


# Input

func _gui_input(event: InputEvent) -> void:
	if pz == null or not editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragged = false
			_changed = false
			_press_cell = cell_at(event.position)
			_last_cell = _press_cell
			_before = lay.to_dict()
		elif _pressing:
			_pressing = false
			if not _dragged:
				_tap(_press_cell)
			if _changed:
				edited.emit(_before)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var c := cell_at(event.position)
		if c != _last_cell:
			if not _dragged and tool == "erase":
				_changed = lay.clear_cell(pz, _last_cell) or _changed
			_dragged = true
			_walk_to(c)
		accept_event()


func _walk_to(target: Vector2i) -> void:
	var guard := 0
	while _last_cell != target and guard < 40:
		guard += 1
		var delta := target - _last_cell
		var step := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var nxt := _last_cell + step
		match tool:
			"track":
				_changed = lay.connect_cells(pz, _last_cell, nxt) or _changed
			"erase":
				_changed = lay.clear_cell(pz, nxt) or _changed
		_last_cell = nxt
	queue_redraw()


func _tap(p: Vector2i) -> void:
	if not pz.inside(p):
		return
	var dirs := lay.dirs_at(pz, p)
	match tool:
		"track":
			if dirs.size() == 3:
				_changed = lay.flip_lever(pz, p)
			elif pz.buildable(p) and dirs.is_empty():
				hint.emit("Drag across squares to lay track.")
			elif dirs.size() == 2 and pz.buildable(p):
				hint.emit("Tap a switch to flip it. Join three sides of a square to make one.")
		"erase":
			_changed = lay.clear_cell(pz, p)
		"signal":
			if not pz.buildable(p):
				return
			if dirs.size() == 2:
				if not pz.allow_stop:
					hint.emit("Stop signals open at stop 5.")
				elif lay.stops.has(p):
					lay.stops.erase(p)
					_changed = true
				else:
					lay.stops[p] = true
					_changed = true
			elif dirs.size() == 3:
				if not pz.allow_lamp:
					hint.emit("Colour signals open at stop 7.")
				else:
					var colors := pz.colors_used()
					var current: int = lay.lamps.get(p, -1)
					var idx := colors.find(current)
					if idx + 1 >= colors.size():
						lay.lamps.erase(p)
					else:
						lay.lamps[p] = colors[idx + 1]
					_changed = true
			elif dirs.size() == 4:
				hint.emit("Signals can't go on a crossing.")
			else:
				hint.emit("Put a stop signal on a straight or curve, or a colour signal on a switch.")


# Playback

func play(run: Dictionary, fast_mode := false) -> void:
	_run = run
	_clock = 0.0
	_playing = true
	_effects.clear()
	_fired_beat = -1
	fast = fast_mode
	editable = false
	set_process(true)


func stop_playback() -> void:
	_run = {}
	_playing = false
	_effects.clear()
	editable = true
	set_process(false)
	queue_redraw()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing and _effects.is_empty():
		set_process(false)
		return
	_clock += delta * (2.5 if fast else 1.0)
	var beats: int = _run.frames.size() - 1 if not _run.is_empty() else 0
	var beat := int(_clock / BEAT)
	while _fired_beat < mini(beat, beats):
		_fired_beat += 1
		for ev in _run.events:
			if ev.t == _fired_beat:
				_effects.append({"kind": ev.kind, "pos": ev.pos, "color": ev.color, "born": _clock})
	if _playing and _clock >= (beats + 0.9) * BEAT:
		_playing = false
		playback_finished.emit()
	var alive: Array = []
	for fx in _effects:
		if _clock - fx.born < 1.6:
			alive.append(fx)
	_effects = alive
	queue_redraw()


# Drawing

func _draw() -> void:
	if pz == null:
		return
	var board := Rect2(origin, Vector2(pz.w, pz.h) * cell)
	Pal.rounded_rect(self, board.grow(cell * 0.12), Pal.WELL, cell * 0.3)
	for y in range(1, pz.h):
		for x in range(1, pz.w):
			draw_circle(origin + Vector2(x, y) * cell, maxf(1.5, cell * 0.035), Pal.DOT, true, -1.0, true)
	for p in pz.blocked:
		_draw_obstacle(p, pz.blocked[p])
	if _pressing and editable and pz.inside(_last_cell):
		Pal.rounded_rect(self, Rect2(origin + Vector2(_last_cell) * cell, Vector2(cell, cell)).grow(-cell * 0.04), Color(Pal.BLUE, 0.08), cell * 0.16, Color(Pal.BLUE, 0.4), 2)
	_draw_track()
	for dp in pz.depots:
		_draw_depot(dp)
	for st in pz.stations:
		_draw_station(st)
	_draw_signals()
	if not _run.is_empty():
		_draw_trains()
	for fx in _effects:
		_draw_effect(fx)


func _draw_obstacle(p: Vector2i, kind: String) -> void:
	var r := Rect2(origin + Vector2(p) * cell, Vector2(cell, cell)).grow(-cell * 0.04)
	var c := r.get_center()
	var s := cell
	var h := absi(p.x * 7 + p.y * 13) % 3
	match kind:
		"woods":
			Pal.rounded_rect(self, r, Pal.WOODS, s * 0.16)
			var spots := [[Vector2(-0.18, -0.16), 0.2], [Vector2(0.17, 0.14), 0.24], [Vector2(-0.2, 0.24), 0.12]]
			if h == 1:
				spots = [[Vector2(0.14, -0.18), 0.18], [Vector2(-0.14, 0.1), 0.24], [Vector2(0.24, 0.26), 0.1]]
			for spot in spots:
				draw_circle(c + spot[0] * s, spot[1] * s, Pal.WOODS_DARK, true, -1.0, true)
		"water":
			Pal.rounded_rect(self, r, Pal.WATER, s * 0.16)
			for row in [-0.14, 0.18]:
				var pts := PackedVector2Array()
				for i in 13:
					var x := -0.32 + i * 0.053
					pts.append(c + Vector2(x, row + sin(i * 1.3 + h) * 0.04) * s)
				draw_polyline(pts, Pal.WATER_DARK, maxf(2.0, s * 0.05), true)
		_:
			Pal.rounded_rect(self, r, Pal.TOWN, s * 0.16)
			var base := c + Vector2(0, 0.26) * s
			var pts := PackedVector2Array([base + Vector2(-0.26, 0) * s, base + Vector2(-0.26, -0.3) * s, base + Vector2(0, -0.5) * s, base + Vector2(0.26, -0.3) * s, base + Vector2(0.26, 0) * s])
			draw_colored_polygon(pts, Pal.TOWN_DARK)


func _track_cells() -> Dictionary:
	var cells := {}
	for key in lay.edges:
		for c in Puzzle.edge_cells(key):
			cells[c] = true
	for key in pz.static_edges():
		for c in Puzzle.edge_cells(key):
			cells[c] = true
	return cells


func _draw_piece(p: Vector2i, a: int, b: int, col: Color, width: float) -> void:
	# Pieces run a hair past the cell edge so neighbours join without a seam.
	if a == Puzzle.opp(b):
		var ext := Vector2(Puzzle.vec(b)) * 1.0
		draw_line(side_mid(p, a) - ext, side_mid(p, b) + ext, col, width, true)
		return
	var pts := PackedVector2Array()
	pts.append(side_mid(p, a) + Vector2(Puzzle.vec(a)))
	for i in 13:
		pts.append(path_point(p, a, b, i / 12.0))
	pts.append(side_mid(p, b) + Vector2(Puzzle.vec(b)) * 1.0)
	draw_polyline(pts, col, width, true)


func _draw_track() -> void:
	var w := cell * 0.2
	for p in _track_cells():
		if not pz.inside(p):
			continue
		var di := pz.depot_index_at(p)
		var si := pz.station_index_at(p)
		if di >= 0 or si >= 0:
			var d: int = pz.depots[di].dir if di >= 0 else pz.stations[si].dir
			draw_line(center(p), side_mid(p, d), Pal.INK, w, true)
			continue
		var dirs := lay.dirs_at(pz, p)
		match dirs.size():
			1:
				# A stub: next to a depot or platform it just waits for track; drawn by
				# the player it ends in a buffer stop.
				var d: int = dirs[0]
				if lay.player_dirs_at(pz, p).is_empty():
					draw_line(side_mid(p, d) + Vector2(Puzzle.vec(d)), side_mid(p, d).lerp(center(p), 0.45), Pal.INK, w, true)
					draw_circle(side_mid(p, d).lerp(center(p), 0.45), w / 2, Pal.INK, true, -1.0, true)
				else:
					draw_line(side_mid(p, d) + Vector2(Puzzle.vec(d)), center(p), Pal.INK, w, true)
					var n := Vector2(Puzzle.vec(d)).orthogonal() * cell * 0.22
					draw_line(center(p) - n, center(p) + n, Pal.INK, w * 0.6, true)
			2:
				_draw_piece(p, dirs[0], dirs[1], Pal.INK, w)
			3:
				var stem := Layout.switch_stem(dirs)
				var lever := lay.lever_branch(pz, p)
				for b in Layout.switch_branches(dirs):
					if b != lever:
						_draw_piece(p, stem, b, Color(Pal.INK, 0.22), w)
				_draw_piece(p, stem, lever, Pal.INK, w)
				var tip := path_point(p, stem, lever, 0.72)
				draw_circle(tip, w * 0.22, Pal.LIT, true, -1.0, true)
			4:
				_draw_piece(p, Puzzle.N, Puzzle.S, Pal.INK, w)
				_draw_piece(p, Puzzle.W, Puzzle.E, Pal.WELL, w * 1.9)
				_draw_piece(p, Puzzle.W, Puzzle.E, Pal.INK, w)


func _draw_depot(dp: Dictionary) -> void:
	var c := center(dp.pos)
	var r := Rect2(c - Vector2(cell, cell) * 0.4, Vector2(cell, cell) * 0.8)
	Pal.rounded_rect(self, r, Pal.BEZEL, cell * 0.18)
	var fwd := Vector2(Puzzle.vec(dp.dir))
	var side := fwd.orthogonal()
	var tip := c + fwd * cell * 0.14
	var pts := PackedVector2Array([tip - fwd * cell * 0.2 + side * cell * 0.18, tip, tip - fwd * cell * 0.2 - side * cell * 0.18])
	draw_polyline(pts, Pal.LIT, cell * 0.08, true)
	# Trains still waiting to leave, as small dots along the depot's back edge.
	var waiting: Array = dp.trains.duplicate()
	if not _run.is_empty():
		waiting = _waiting_at(dp)
	var n := waiting.size()
	for i in n:
		var dot := c - fwd * cell * 0.26 + side * cell * 0.13 * (i - (n - 1) / 2.0)
		draw_circle(dot, cell * 0.055, Pal.livery(waiting[i]), true, -1.0, true)


func _waiting_at(dp: Dictionary) -> Array:
	var frame_i := clampi(int(_clock / BEAT) + 1, 0, _run.frames.size() - 1)
	var seen := {}
	for f in range(0, frame_i + 1):
		for tr in _run.frames[f]:
			seen[tr.id] = true
	var di := pz.depots.find(dp)
	var out: Array = []
	var ids := _depot_train_ids(di)
	for i in ids.size():
		if not seen.has(ids[i]):
			out.append(dp.trains[i])
	return out


func _depot_train_ids(di: int) -> Array:
	# Trains are numbered by departure beat, then by depot. Rebuild that order here.
	var list: Array = []
	for d in pz.depots.size():
		var dp: Dictionary = pz.depots[d]
		for i in dp.trains.size():
			list.append({"d": d, "i": i, "t": dp.start + i * dp.every})
	list.sort_custom(func(a, b): return a.t < b.t or (a.t == b.t and a.d < b.d))
	var ids: Array = []
	for d_i in pz.depots[di].trains.size():
		for k in list.size():
			if list[k].d == di and list[k].i == d_i:
				ids.append(k)
	return ids


func _draw_station(st: Dictionary) -> void:
	var c := center(st.pos)
	var col := Pal.livery(st.color)
	var r := Rect2(c - Vector2(cell, cell) * 0.38, Vector2(cell, cell) * 0.76)
	Pal.rounded_rect(self, r, Pal.WHITE, cell * 0.18, col, maxi(3, int(cell * 0.09)))
	Pal.draw_glyph(self, st.color, c, cell * 0.13, col)


func _draw_signals() -> void:
	var holding := {}
	if not _run.is_empty():
		for tr in _current_frame():
			if tr.hold > 0:
				holding[tr.pos] = true
	for p in lay.stops:
		var dirs := lay.dirs_at(pz, p)
		if dirs.size() != 2:
			continue
		# Put the signal head beside the track, on the side the piece curves away from.
		var off := Vector2(Puzzle.vec(dirs[0]) + Puzzle.vec(dirs[1]))
		var a := Vector2(Puzzle.vec(dirs[0]))
		var perp := a.orthogonal() if off == Vector2.ZERO else -off.normalized()
		var hc := center(p) + perp * cell * 0.3
		if off != Vector2.ZERO:
			hc = center(p) + perp * cell * 0.2
		var head := Rect2(hc - Vector2(cell * 0.13, cell * 0.17), Vector2(cell * 0.26, cell * 0.34))
		Pal.rounded_rect(self, head, Pal.BEZEL, cell * 0.08)
		var lamp := Pal.LAMP_RED if (holding.has(p) or _run.is_empty()) else Color(Pal.LAMP_RED, 0.45)
		draw_circle(head.get_center(), cell * 0.075, lamp, true, -1.0, true)
	for p in lay.lamps:
		if lay.dirs_at(pz, p).size() != 3:
			continue
		var c := center(p)
		draw_circle(c, cell * 0.17, Pal.BEZEL, true, -1.0, true)
		draw_circle(c, cell * 0.11, Pal.livery(lay.lamps[p]), true, -1.0, true)


func _current_frame() -> Array:
	var i := clampi(int(_clock / BEAT), 0, _run.frames.size() - 1)
	return _run.frames[i]


func _draw_trains() -> void:
	var k := clampi(int(_clock / BEAT), 0, _run.frames.size() - 1)
	var f := clampf(_clock / BEAT - k, 0.0, 1.0)
	var here: Array = _run.frames[k]
	var nxt: Array = _run.frames[mini(k + 1, _run.frames.size() - 1)]
	var next_by_id := {}
	for tr in nxt:
		next_by_id[tr.id] = tr
	var len := cell * 0.78
	for tr in here:
		if tr.state != "moving":
			continue # finished trains are shown by their effect
		var pos: Vector2
		var ahead: Vector2
		var alpha := 1.0
		var tn: Dictionary = next_by_id.get(tr.id, {})
		if k + 1 >= _run.frames.size() or tn.is_empty():
			pos = path_point(tr.pos, tr.in, tr.out, 0.5)
			ahead = path_point(tr.pos, tr.in, tr.out, 0.55)
		elif tn.pos == tr.pos:
			pos = path_point(tr.pos, tr.in, tr.out, 0.5)
			ahead = path_point(tr.pos, tr.in, tr.out, 0.55)
		else:
			var t := 0.5 + f
			if t <= 1.0:
				pos = path_point(tr.pos, tr.in, tr.out, t)
				ahead = path_point(tr.pos, tr.in, tr.out, minf(t + 0.05, 1.0))
				if t + 0.05 > 1.0:
					ahead = pos + (pos - path_point(tr.pos, tr.in, tr.out, t - 0.05))
			else:
				var entry := Puzzle.opp(tr.out)
				var out: int = tn.out if tn.state == "moving" else tr.out
				pos = path_point(tn.pos, entry, out, t - 1.0)
				ahead = path_point(tn.pos, entry, out, t - 0.95)
				if tn.state != "moving":
					alpha = clampf(1.0 - (t - 1.0) * 1.6, 0.0, 1.0)
		var angle := (ahead - pos).angle()
		Pal.draw_train(self, pos, angle, len, tr.color, alpha)
	# Trains that appear this beat roll out of their depot.
	for tr in nxt:
		var found := false
		for h in here:
			if h.id == tr.id:
				found = true
		if not found and tr.state == "moving" and k + 1 < _run.frames.size():
			var pos := path_point(tr.pos, tr.in, tr.out, 0.5)
			Pal.draw_train(self, pos, Vector2(Puzzle.vec(tr.out)).angle(), len * (0.4 + 0.6 * f), tr.color, f)


func _draw_effect(fx: Dictionary) -> void:
	var age: float = _clock - fx.born
	var c := center(fx.pos)
	var col := Pal.outcome_color("arrived" if fx.kind == "arrived" else ("wrong" if fx.kind == "wrong" else "crashed"))
	var a := clampf(1.0 - age / 1.6, 0.0, 1.0)
	var r := cell * (0.35 + age * 0.5)
	draw_arc(c, r, 0, TAU, 40, Color(col, a), cell * 0.08, true)
	if fx.kind == "crash" or fx.kind == "derail" or fx.kind == "lost":
		for i in 8:
			var ang := i * TAU / 8 + 0.3
			var d := Vector2(cos(ang), sin(ang))
			draw_line(c + d * cell * 0.12, c + d * (cell * 0.28 + age * cell * 0.3), Color(col, a), cell * 0.07, true)
