extends SceneTree

var failed := false

func _initialize() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if not main.has_method("start_scenario"):
		push_error("Main scene script did not load.")
		quit(1)
		return

	_run_coal_smoke(main)
	_run_layout_smoke(main)
	_run_debug_money_smoke(main)
	_run_signal_rotation_smoke(main)
	_run_paired_chain_signal_smoke(main)
	_run_dispatcher_assignment_smoke(main)
	_run_depot_dispatch_smoke(main)
	_run_restart_preserves_fleet_smoke(main)
	_run_signal_siding_smoke(main)
	_run_advanced_yard_smoke(main)
	_run_line_density_smoke(main)
	if failed:
		push_error("Smoke test failed.")
		quit(1)
		return
	print("Smoke test complete.")
	quit(0)

func _run_coal_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	main._place_signal_pair(Vector2i(4, 4), "block")
	main._place_signal_pair(Vector2i(8, 4), "block")
	main._buy_train()
	for i in range(900):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Coal Valley should clear on a connected route.")

func _run_layout_smoke(main: Node) -> void:
	main.size = Vector2(1280, 720)
	main.start_scenario("coal_valley")
	main._update_board_layout()
	var grid: Vector2i = main.local["scenario"]["grid"]
	var board_size := Vector2(float(grid.x) * main.cell_size, float(grid.y) * main.cell_size)
	_require(main.cell_size >= 55.0, "Local map cells should scale above the old 50px cap at 1280x720.")
	_require(board_size.x >= 760.0, "Local map should take more horizontal space than the side UI at 1280x720.")
	_require(board_size.y >= 490.0, "Local map should take more vertical space than the old compact layout at 1280x720.")
	var dispatcher_min_width: float = main.dispatch_line_box.custom_minimum_size.x + main.dispatch_train_box.custom_minimum_size.x + 8.0
	_require(dispatcher_min_width <= main._local_side_panel_inner_width(), "Dispatcher columns should fit inside the side panel at 1280px.")
	main.size = Vector2(2048, 1024)
	main._update_board_layout()
	_require(main._local_side_panel_width() >= 520.0, "Wide screens should use a wider side panel.")
	_require(dispatcher_min_width <= main._local_side_panel_inner_width(), "Dispatcher columns should fit inside the side panel at 2048px.")
	var panel_right_edge: float = main.size.x + main.side_panel.offset_right
	_require(panel_right_edge <= main.size.x, "Side panel should stay inside the right edge of the window.")

func _run_debug_money_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	var before: int = int(main.local["money"])
	main._debug_replenish_money()
	_require(int(main.local["money"]) == before + 5000, "Debug money button should add $5000 to the local budget.")

func _run_signal_rotation_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	main._place_signal(Vector2i(4, 4), "block")
	main._buy_train_for_source("coal_mine")
	_require(main.trains.size() == 1, "Rotation smoke should buy one train.")
	main._update_local(0.1)
	_require(main.trains[0]["state"] != "NoRoute", "A correctly facing signal should allow a route.")
	main._rotate_signal_at(Vector2i(4, 4))
	main._plan_next_path(main.trains[0])
	_require(main.trains[0]["state"] == "NoRoute", "Rotating a one-way signal against travel should affect pathing, not only visuals.")
	_require(String(main.trains[0]["wait_reason"]).contains("needs east"), "Wrong-way signal routes should explain the needed direction.")

func _run_paired_chain_signal_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	main._place_signal(Vector2i(4, 4), "chain")
	main._place_signal_pair(Vector2i(4, 4), main._pair_signal_type_for(Vector2i(4, 4)))
	_require(main._signal_type(Vector2i(4, 4)) == "chain", "Pairing an existing chain signal should preserve chain type.")
	_require(main._signal_dirs(Vector2i(4, 4)).size() == 2, "Pairing an existing chain signal should create two protected directions.")
	_require(main._signal_type_for_dir(Vector2i(4, 4), Vector2i.RIGHT) == "chain", "Paired chain should remain chain in the forward direction.")
	_require(main._signal_type_for_dir(Vector2i(4, 4), Vector2i.LEFT) == "chain", "Paired chain should remain chain in the reverse direction.")

func _run_dispatcher_assignment_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 2000
	var line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.selected_line_id = line_id
	main._clear_selected_line_stops()
	main._append_station_to_selected_line_at(Vector2i(1, 4))
	main._append_station_to_selected_line_at(Vector2i(12, 4))
	_require((main.lines[line_id]["route"] as Array).size() == 2, "Dispatcher smoke should allow editing line stops.")
	main._buy_available_train()
	_require(main.trains.size() == 1, "Dispatcher smoke should buy one available train.")
	_require(main._available_train_count() == 1, "Newly bought train should start as available stock.")
	main._assign_selected_train_to_selected_line()
	_require(main._available_train_count() == 0, "Assigned train should leave available stock.")
	_require(main._line_train_count(line_id) == 1, "Selected line should receive the assigned train.")
	_require(String(main._line_cargo_preview(line_id)).contains("coal"), "Line preview should describe expected coal cargo.")

func _run_depot_dispatch_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	var line_id: String = main._create_or_get_line_for_source("coal_mine")
	main._buy_train_for_line(line_id)
	main._buy_train_for_line(line_id)
	var on_source: int = main._tile_train_count(Vector2i(1, 4))
	var queued := 0
	for t in main.trains:
		if not main._is_train_on_map(t):
			queued += 1
	_require(main.trains.size() == 2, "Depot smoke should buy two trains on one line.")
	_require(on_source == 1, "Only one train should occupy a one-platform source tile after dispatch.")
	_require(queued == 1, "Extra trains should wait off-map in depot instead of stacking in the yard.")
	_require(main._block_occupied_by_other(-1, "") == "", "Off-map depot trains should not occupy signal blocks.")

func _run_restart_preserves_fleet_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	var line_id: String = main._create_or_get_line_for_source("coal_mine")
	main._buy_train_for_line(line_id)
	main._buy_train_for_line(line_id)
	var ids_before: Array[String] = []
	for t in main.trains:
		ids_before.append(String(t["id"]))
	main.selected_train_id = ids_before[1]
	main._restart_trains_only()
	var ids_after: Array[String] = []
	for t in main.trains:
		ids_after.append(String(t["id"]))
	_require(ids_after == ids_before, "Restart Trains should preserve existing train records and IDs.")
	_require(main.selected_train_id == ids_before[1], "Restart Trains should preserve selected train when it still exists.")
	_require(main.trains.size() == 2, "Restart Trains should not remove trains from the fleet.")
	_require(main._tile_train_count(Vector2i(1, 4)) == 1, "Restart Trains should visibly stage one assigned train at the line start when the platform is free.")

func _run_signal_siding_smoke(main: Node) -> void:
	main.start_scenario("central_yard")
	_place_path(main, [Vector2i(1, 4), Vector2i(12, 4)])
	_place_path(main, [Vector2i(5, 4), Vector2i(5, 5), Vector2i(9, 5), Vector2i(9, 4)])
	_require(not main._has_track_segment(Vector2i(6, 4), Vector2i(6, 5)), "Parallel siding should not auto-connect to adjacent mainline tiles.")
	_require(not main._has_track_segment(Vector2i(7, 4), Vector2i(7, 5)), "Parallel siding middle tiles should stay independent unless explicitly connected.")
	_require(not main._has_track_segment(Vector2i(8, 4), Vector2i(8, 5)), "Explicit segment placement should prevent accidental ladder junctions.")
	main._place_signal_pair(Vector2i(4, 4), "block")
	main._place_signal_pair(Vector2i(5, 5), "block")
	main._place_signal_pair(Vector2i(9, 5), "block")
	main._place_signal_pair(Vector2i(10, 4), "block")
	main._buy_train()
	main._buy_train()
	for i in range(900):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	var no_route_count := 0
	for t in main.trains:
		if t["state"] == "NoRoute":
			no_route_count += 1
	_require(main.trains.size() == 2, "Signal Siding should support a two-train lesson fleet.")
	_require(no_route_count == 0, "Signal Siding trains should retain valid routes.")
	_require(int(main.local.get("processed", 0)) > 0 or main.screen == main.Screen.RESULTS, "Signal Siding should move freight after signaling.")

func _run_advanced_yard_smoke(main: Node) -> void:
	main.start_scenario("steelworks")
	_place_path(main, [Vector2i(1, 3), Vector2i(7, 3), Vector2i(7, 4), Vector2i(12, 4)])
	_place_path(main, [Vector2i(4, 7), Vector2i(4, 6), Vector2i(7, 6), Vector2i(7, 4)])
	_place_path(main, [Vector2i(12, 4), Vector2i(12, 5), Vector2i(8, 5), Vector2i(7, 4)])
	main._place_signal(Vector2i(6, 3), "chain")
	main._place_signal(Vector2i(7, 5), "chain")
	main._place_signal(Vector2i(7, 4), "chain")
	main._rotate_signal_at(Vector2i(7, 4))
	main._rotate_signal_at(Vector2i(7, 4))
	main._place_signal(Vector2i(8, 4), "block")
	main._place_signal(Vector2i(10, 4), "block")
	main._place_signal(Vector2i(11, 4), "block")
	main._rotate_signal_at(Vector2i(11, 4))
	main._place_signal(Vector2i(8, 5), "block")
	main._place_signal(Vector2i(11, 5), "block")
	main._rotate_signal_at(Vector2i(11, 5))
	main._place_signal(Vector2i(3, 3), "block")
	main._place_signal(Vector2i(5, 3), "block")
	main._place_signal(Vector2i(5, 6), "block")
	main._place_signal(Vector2i(6, 6), "block")
	main._buy_train()
	main._buy_train()
	main._buy_train()
	main._buy_train()
	for i in range(1200):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	var no_route_count := 0
	for t in main.trains:
		if t["state"] == "NoRoute":
			no_route_count += 1
	_require(main.screen == main.Screen.LOCAL or main.screen == main.Screen.RESULTS, "Advanced Central Yard should remain playable after a short four-train run.")
	_require(main.trains.size() == 4, "Advanced Central Yard should support buying four trains.")
	_require(no_route_count == 0, "Advanced Central Yard trains should retain valid line routes during smoke.")

func _run_line_density_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 10000
	main.local["target"] = 100000
	main.station_by_id["coal_mine"]["platforms"] = 4
	main.station_by_id["interchange"]["platforms"] = 4
	_place_path(main, [Vector2i(1, 4), Vector2i(1, 5), Vector2i(12, 5), Vector2i(12, 4)])
	_place_path(main, [Vector2i(12, 4), Vector2i(12, 3), Vector2i(1, 3), Vector2i(1, 4)])
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	for x in range(2, 12, 2):
		main._replace_signal_set(Vector2i(x, 5), "block", east)
		main._replace_signal_set(Vector2i(x, 3), "block", west)
	main._compute_blocks()
	for i in range(8):
		main._buy_train_for_source("coal_mine")
	for i in range(2200):
		main._update_local(0.1)
	var no_route_count := 0
	var waiting_wrong_way := 0
	for t in main.trains:
		if t["state"] == "NoRoute":
			no_route_count += 1
		if String(t.get("wait_reason", "")).contains("other way"):
			waiting_wrong_way += 1
	_require(main.trains.size() == 8, "Density smoke should keep eight trains assigned to one line.")
	_require(no_route_count == 0, "Density smoke trains should all keep valid paths.")
	_require(waiting_wrong_way == 0, "Density smoke should not leave trains facing wrong-way signals.")
	_require(int(main.local.get("delivered", 0)) >= 800, "Density smoke should move substantial cargo with eight trains.")
	_require(main._average_wait() < 12.0, "Density smoke should keep a high-throughput line moving.")
	_require(int(main.local.get("deadlocks", 0)) == 0, "Density smoke should not deadlock a properly signaled line.")

func _place_path(main: Node, points: Array) -> void:
	for i in range(points.size() - 1):
		var a: Vector2i = points[i]
		var b: Vector2i = points[i + 1]
		main._place_track_path(a, b)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
