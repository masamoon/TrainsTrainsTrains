extends SceneTree
## Headless checks: godot --headless --path . --script res://tests/run_tests.gd

var failures := 0
var checks := 0
var sections_done := 0


func _init() -> void:
	_test_rules()
	_test_levels()
	_test_daily()
	_test_drawing()
	# A script error aborts a section silently, so make sure each one reached its end.
	check(sections_done == 4, "all test sections ran to the end")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + label)


func _puzzle(rows: Array, depots: Array, stations: Array, extra := {}) -> Puzzle:
	var data := {"rows": rows, "depots": depots, "stations": stations, "par": 1}
	data.merge(extra)
	return Puzzle.from_data(data)


func _draw_path(pz: Puzzle, lay: Layout, cells: Array) -> void:
	for i in range(cells.size() - 1):
		lay.connect_cells(pz, Vector2i(cells[i][0], cells[i][1]), Vector2i(cells[i + 1][0], cells[i + 1][1]))


func _test_rules() -> void:
	# Straight run arrives.
	var pz := _puzzle(["....."], [{"at": [0, 0], "dir": "E", "trains": [0]}], [{"at": [4, 0], "dir": "W", "color": 0}])
	var lay := Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0], [3, 0]])
	check(lay.track_count(pz) == 3, "track count counts drawn cells")
	var res := Sim.run(pz, lay)
	check(res.success, "straight line delivers")

	# Missing piece derails.
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0]])
	res = Sim.run(pz, lay)
	check(not res.success and res.outcomes[0].result == Sim.OUTCOME_CRASHED, "gap derails")

	# Wrong colour platform.
	pz = _puzzle(["....."], [{"at": [0, 0], "dir": "E", "trains": [1]}], [{"at": [4, 0], "dir": "W", "color": 0}])
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0], [3, 0]])
	res = Sim.run(pz, lay)
	check(res.outcomes[0].result == Sim.OUTCOME_WRONG, "wrong platform flagged")

	# Head-on trains crash.
	pz = _puzzle([".....", "....."], [
		{"at": [0, 0], "dir": "E", "trains": [0]},
		{"at": [4, 0], "dir": "W", "trains": [1]},
	], [
		{"at": [0, 1], "dir": "E", "color": 1},
		{"at": [4, 1], "dir": "W", "color": 0},
	])
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0], [3, 0]])
	res = Sim.run(pz, lay)
	check(not res.success, "head-on crash")

	# Switch stem is the odd side out; lamp routes by colour.
	pz = _puzzle([".....", ".....", "....."], [{"at": [0, 1], "dir": "E", "trains": [0, 1], "every": 3}], [
		{"at": [4, 0], "dir": "W", "color": 0},
		{"at": [4, 2], "dir": "W", "color": 1},
	])
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 1], [2, 1], [3, 1], [3, 0]])
	_draw_path(pz, lay, [[3, 1], [3, 2]])
	check(Layout.switch_stem(lay.dirs_at(pz, Vector2i(3, 1))) == Puzzle.W, "switch stem")
	lay.levers[Vector2i(3, 1)] = Puzzle.N
	res = Sim.run(pz, lay)
	check(not res.success, "lever alone sends both trains one way")
	lay.lamps[Vector2i(3, 1)] = 0
	res = Sim.run(pz, lay)
	check(res.success, "colour lamp sorts trains")

	# A loop ends early as lost instead of running forever.
	pz = _puzzle(["....", "....", "...."], [{"at": [0, 0], "dir": "E", "trains": [0]}], [{"at": [3, 2], "dir": "N", "color": 0}])
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0], [2, 1], [1, 1], [1, 0]])
	res = Sim.run(pz, lay)
	check(not res.success and res.beats < 30, "loop detected")

	# A train queues behind a held train instead of crashing into it.
	pz = _puzzle(["......"], [{"at": [0, 0], "dir": "E", "trains": [0, 0], "every": 1}], [{"at": [5, 0], "dir": "W", "color": 0}])
	lay = Layout.new()
	_draw_path(pz, lay, [[1, 0], [2, 0], [3, 0], [4, 0]])
	lay.stops[Vector2i(3, 0)] = true
	res = Sim.run(pz, lay)
	check(res.success, "queue behind stop signal")

	# Layout round trip.
	var copy := Layout.from_dict(JSON.parse_string(JSON.stringify(lay.to_dict())))
	check(copy.edges.size() == lay.edges.size() and copy.stops.size() == 1, "layout save round trip")
	sections_done += 1


func _test_levels() -> void:
	for i in Levels.count():
		var pz := Levels.load_level(i)
		var lay := pz.solution_layout()
		var res := Sim.run(pz, lay)
		check(res.success, "level %s reference solution solves (%s)" % [pz.id, str(res.outcomes)])
		check(pz.stars_for(lay.track_count(pz)) == 3, "level %s reference earns 3 stars" % pz.id)
		# Without its signals, levels that introduce them should fail.
		if not pz.solution.get("stops", []).is_empty() or not pz.solution.get("lamps", {}).is_empty():
			var bare := lay.duplicate_layout()
			bare.stops.clear()
			bare.lamps.clear()
			check(not Sim.run(pz, bare).success, "level %s needs its signals" % pz.id)
		print("level %s %-15s par %2d  beats %d" % [pz.id, pz.name, pz.par, res.beats])
	sections_done += 1


func _test_daily() -> void:
	var failed_days := 0
	var start := Time.get_ticks_msec()
	for day in range(1, 400):
		var pz := DailyGen.generate(day)
		if pz == null:
			failed_days += 1
			continue
		var res := Sim.run(pz, pz.solution_layout())
		if not res.success:
			failed_days += 1
			printerr("daily %d solution fails" % day)
	check(failed_days == 0, "every daily puzzle generates and solves (%d failed)" % failed_days)
	var a := DailyGen.generate(42)
	var b := DailyGen.generate(42)
	check(a.blocked == b.blocked and a.par == b.par and str(a.depots) == str(b.depots), "daily is deterministic")
	print("daily: 399 puzzles in %d ms" % (Time.get_ticks_msec() - start))
	for day in range(1, 8):
		var pz := DailyGen.generate(day)
		print("daily %d %s  %dx%d  trains %d  par %d  stop:%s lamp:%s" % [day, DailyGen.date_label(day), pz.w, pz.h, pz.train_count(), pz.par, not pz.solution.stops.is_empty(), not pz.solution.lamps.is_empty()])
	sections_done += 1


func _press(view: BoardView, cell: Vector2i, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = view.center(cell)
	view._gui_input(ev)


func _move(view: BoardView, cell: Vector2i) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = view.center(cell)
	view._gui_input(ev)


func _test_drawing() -> void:
	var pz := Levels.load_level(0)
	var view := BoardView.new()
	view.size = Vector2(500, 500)
	view.setup(pz, Layout.new())
	view._layout_board()
	# Drag from the depot along the reference route, skipping a cell to check path filling.
	_press(view, Vector2i(0, 1), true)
	_move(view, Vector2i(2, 1))
	_move(view, Vector2i(2, 3))
	_move(view, Vector2i(4, 3))
	_press(view, Vector2i(4, 3), false)
	check(view.lay.track_count(pz) == 5, "drag lays 5 pieces (got %d)" % view.lay.track_count(pz))
	check(Sim.run(pz, view.lay).success, "dragged route solves level 1")
	view.tool = "erase"
	_press(view, Vector2i(2, 2), true)
	_press(view, Vector2i(2, 2), false)
	check(not Sim.run(pz, view.lay).success, "erasing a piece breaks the route")
	view.free()
	sections_done += 1
