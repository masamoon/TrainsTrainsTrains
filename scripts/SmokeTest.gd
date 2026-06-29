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
	_run_diagonal_track_smoke(main)
	_run_signal_rotation_smoke(main)
	_run_signal_click_cycle_smoke(main)
	_run_corner_signal_click_smoke(main)
	_run_signal_gate_hit_smoke(main)
	_run_signal_gate_erase_replace_smoke(main)
	_run_station_signal_departure_smoke(main)
	_run_dwell_reason_display_smoke(main)
	_run_block_occupant_smoke(main)
	_run_train_next_leg_smoke(main)
	_run_idle_train_blocker_reason_smoke(main)
	_run_yard_route_return_smoke(main)
	_run_target_progress_path_smoke(main)
	_run_paired_chain_signal_smoke(main)
	_run_dispatcher_assignment_smoke(main)
	_run_depot_dispatch_smoke(main)
	_run_restart_preserves_fleet_smoke(main)
	_run_planning_guide_smoke(main)
	_run_signal_siding_smoke(main)
	_run_advanced_yard_smoke(main)
	_run_overtake_pass_smoke(main)
	_run_line_density_smoke(main)
	if failed:
		push_error("Smoke test failed.")
		quit(1)
		return
	print("Smoke test complete.")
	quit(0)

func _run_coal_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal_pair(Vector2i(5, 5), "block")
	main._place_signal_pair(Vector2i(11, 5), "block")
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
	_require(main.cell_size >= 46.0, "Expanded local maps should keep cells at the readable minimum at 1280x720.")
	_require(board_size.x >= 820.0, "Expanded local map should give passing infrastructure more horizontal room at 1280x720.")
	_require(board_size.y >= 500.0, "Expanded local map should give passing infrastructure more vertical room at 1280x720.")
	_require(main._local_side_panel_width() <= 400.0, "Default side panel should leave room for the expanded board at 1280px.")
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

func _run_diagonal_track_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	main._place_track_path(Vector2i(2, 2), Vector2i(5, 5))
	_require(main._has_track_segment(Vector2i(2, 2), Vector2i(3, 3)), "Diagonal drags should create diagonal rail segments.")
	_require(main._has_track_segment(Vector2i(3, 3), Vector2i(4, 4)), "Diagonal rail should continue through the drag path.")
	_require(not main._has_track_segment(Vector2i(2, 2), Vector2i(3, 2)), "Diagonal drags should not create square corner rail.")
	main._place_signal(Vector2i(3, 3), "block")
	_require(main._signal_dir(Vector2i(3, 3)) == Vector2i(1, 1) or main._signal_dir(Vector2i(3, 3)) == Vector2i(-1, -1), "Signals on diagonal rail should face along the diagonal segment.")

func _run_signal_rotation_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal(Vector2i(5, 5), "block")
	main._buy_train_for_source("coal_mine")
	_require(main.trains.size() == 1, "Rotation smoke should buy one train.")
	main._update_local(0.1)
	_require(main.trains[0]["state"] != "NoRoute", "A correctly facing signal should allow a route.")
	var gate_before: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.RIGHT)
	main._rotate_signal_at(Vector2i(5, 5))
	var gate_after: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.LEFT)
	_require(main.signals.has(Vector2i(5, 5)) and main._signal_dir(Vector2i(5, 5)) == Vector2i.LEFT, "Rotating a single straight signal should change facing without moving the signal to another cell.")
	_require(gate_before.distance_to(gate_after) < 1.0, "Rotating a single straight signal should keep the visible signal centered in its cell.")
	main._plan_next_path(main.trains[0])
	_require(main.trains[0]["state"] == "NoRoute", "Rotating a one-way signal against travel should affect pathing, not only visuals.")
	_require(String(main.trains[0]["wait_reason"]).contains("needs east"), "Wrong-way signal routes should explain the needed direction.")

func _run_paired_chain_signal_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal(Vector2i(5, 5), "chain")
	main._place_signal_pair(Vector2i(5, 5), main._pair_signal_type_for(Vector2i(5, 5)))
	_require(main._signal_type(Vector2i(5, 5)) == "chain", "Pairing an existing chain signal should preserve chain type.")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 2, "Pairing an existing chain signal should create two protected directions.")
	_require(main._signal_type_for_dir(Vector2i(5, 5), Vector2i.RIGHT) == "chain", "Paired chain should remain chain in the forward direction.")
	_require(main._signal_type_for_dir(Vector2i(5, 5), Vector2i.LEFT) == "chain", "Paired chain should remain chain in the reverse direction.")

func _run_signal_click_cycle_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal(Vector2i(5, 5), "chain")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 1, "First signal click should place a single signal.")
	main._place_signal(Vector2i(5, 5), "chain")
	_require(main._signal_type(Vector2i(5, 5)) == "chain", "Second signal click should keep the selected signal type.")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 2, "Second signal click should toggle to a double signal.")
	main._place_signal(Vector2i(5, 5), "chain")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 1, "Third signal click should toggle back to a single signal.")

func _run_corner_signal_click_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(5, 5), Vector2i(5, 7)])
	main._place_signal(Vector2i(5, 5), "block")
	var first_dir: Vector2i = main._signal_dir(Vector2i(5, 5))
	main._place_signal(Vector2i(5, 5), "block")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 2, "Clicking a corner signal again should make it paired, not rotate it.")
	_require(main._signal_dirs(Vector2i(5, 5)).has(first_dir), "Paired corner signal should keep the original facing.")
	_require(main._signal_dirs(Vector2i(5, 5)).has(Vector2i.LEFT), "Paired corner signal should add the other connected leg.")
	main._place_signal(Vector2i(5, 5), "block")
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 1, "Third corner signal click should toggle back to single.")
	_require(main._signal_dir(Vector2i(5, 5)) == first_dir, "Toggling back to single should preserve the original facing.")

func _run_signal_gate_hit_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal(Vector2i(5, 5), "block")
	var gate_pos: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.RIGHT)
	_require(main._hit_signal_pos(gate_pos) == Vector2i(5, 5), "Signal gate hit target should select the signal.")
	main.selected_tool = "block"
	main._handle_local_click(gate_pos)
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 2, "Clicking the visible signal gate with the signal tool should toggle the owning signal.")
	_require(not main.signals.has(Vector2i(6, 5)), "Clicking a signal gate on a tile boundary should not place an adjacent signal.")
	var cell_center: Vector2 = main._grid_to_screen(Vector2i(5, 5))
	var paired_east: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.RIGHT)
	var paired_west: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.LEFT)
	_require(paired_east.distance_to(cell_center) <= main.cell_size * 0.08, "Paired east-facing signal gate should sit near the owning cell center.")
	_require(paired_west.distance_to(cell_center) <= main.cell_size * 0.08, "Paired west-facing signal gate should sit near the owning cell center.")
	_require(paired_east.distance_to(paired_west) <= main.cell_size * 0.14, "Paired opposite signals should be adjacent, not split across neighboring segments.")
	_require(paired_east.distance_to(paired_west) < 1.0, "Paired opposite signal arrows should share the same centered signal body.")
	var nearby_track: Vector2 = main._grid_to_screen(Vector2i(6, 6))
	_require(main._hit_signal_pos(nearby_track).x <= -900, "Nearby track clicks should not select an adjacent signal gate.")

func _run_signal_gate_erase_replace_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal(Vector2i(5, 5), "block")
	var gate_pos: Vector2 = main._signal_gate_center(Vector2i(5, 5), Vector2i.RIGHT)
	main.selected_tool = "erase"
	main._handle_local_click(gate_pos)
	_require(not main.signals.has(Vector2i(5, 5)), "Erasing by clicking the visible signal gate should remove the signal.")
	_require(main.tracks.has(Vector2i(5, 5)) and main.tracks.has(Vector2i(6, 5)), "Erasing a signal gate should leave both rail tiles in place.")
	_require(main._has_track_segment(Vector2i(5, 5), Vector2i(6, 5)), "Erasing a signal gate should not delete the rail segment under the gate.")
	main.selected_tool = "block"
	main._handle_local_click(main._grid_to_screen(Vector2i(5, 5)))
	_require(main.signals.has(Vector2i(5, 5)), "A signal should be placeable again after erasing it.")
	main.selected_tool = "erase"
	gate_pos = main._signal_gate_center(Vector2i(5, 5), Vector2i.RIGHT)
	main._handle_local_click(gate_pos)
	_require(not main.signals.has(Vector2i(5, 5)), "Second erase should remove the replaced signal.")
	main.selected_tool = "block"
	main._handle_local_click(gate_pos)
	_require(main.signals.has(Vector2i(5, 5)), "Clicking the old visible gate position should replace the erased signal on its original tile.")
	_require(not main.signals.has(Vector2i(6, 5)), "Replacing at an erased gate should not create a neighbor signal.")

func _run_station_signal_departure_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var west: Array[Vector2i] = [Vector2i.LEFT]
	main._replace_signal_set(Vector2i(1, 5), "chain", west)
	main._buy_train_for_source("coal_mine")
	main._update_local(0.1)
	_require(main.trains[0]["state"] == "NoRoute", "A station signal should control train departures from that station tile.")
	_require(String(main.trains[0]["wait_reason"]).contains("needs east"), "Station signal departure blocks should explain the needed direction.")

func _run_dwell_reason_display_smoke(main: Node) -> void:
	var train := {
		"state": "YardStop",
		"wait_reason": "Signal only opens east / right, but this train needs northwest / left / up."
	}
	var reason: String = main._display_reason_for_train(train)
	_require(reason.begins_with("Working through the yard stop. Next move:"), "Yard dwell should present signal trouble as the next move, not the current action.")

func _run_block_occupant_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._buy_train_for_source("coal_mine")
	main._buy_train_for_source("coal_mine")
	main._compute_blocks()
	var block_id := int(main.block_for_tile.get(Vector2i(1, 5), -1))
	var occupants: Array[String] = main._block_occupants(block_id)
	_require(occupants.has("T01") or occupants.has("T02"), "Block debug should be able to identify the actual train occupying a highlighted block.")
	var without_t01: Array[String] = main._block_occupants(block_id, "T01")
	_require(not without_t01.has("T01"), "Block occupant lookup should respect the excluded train id.")

func _run_train_next_leg_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._buy_train_for_source("coal_mine")
	main._update_local(0.1)
	_require(main._next_stop_name_for_train(main.trains[0]) == "Interchange", "Selected train context should name the next stop.")
	_require(main._next_leg_name_for_train(main.trains[0]).contains("east"), "Selected train context should name the next rail leg.")

func _run_idle_train_blocker_reason_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	main._replace_signal_set(Vector2i(5, 5), "block", east)
	main.trains.clear()
	main.trains.append({
		"id": "T01",
		"name": "Train 01",
		"line_id": "test",
		"route": ["coal_mine", "interchange"],
		"stop_index": 1,
		"tile": Vector2i(5, 5),
		"pos": main._grid_to_screen(Vector2i(5, 5)),
		"path": [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)],
		"path_index": 0,
		"state": "Idle",
		"wait_reason": "",
		"cargo": "coal",
		"cargo_amount": 10,
		"capacity": 40
	})
	main.trains.append({
		"id": "T02",
		"name": "Train 02",
		"line_id": "test",
		"route": ["coal_mine", "interchange"],
		"stop_index": 1,
		"tile": Vector2i(8, 5),
		"pos": main._grid_to_screen(Vector2i(8, 5)),
		"path": [],
		"path_index": 0,
		"state": "Idle",
		"wait_reason": "",
		"cargo": "",
		"cargo_amount": 0,
		"capacity": 40
	})
	var reason: String = main._display_reason_for_train(main.trains[0])
	_require(reason.contains("Next signal section is occupied by T02"), "Idle train inspector should explain the next occupied signal section before the train state mutates.")

func _run_yard_route_return_smoke(main: Node) -> void:
	main.start_scenario("steelworks")
	_place_path(main, [Vector2i(1, 4), Vector2i(2, 5), Vector2i(9, 5), Vector2i(16, 5)])
	var line_id: String = main._create_or_get_line_for_source("west_line")
	var scenario_route: Array = main.local["scenario"]["route"]
	main.lines[line_id]["route"] = [scenario_route[0], scenario_route[1], scenario_route[2]]
	main._buy_train_for_line(line_id)
	_require(main.trains.size() == 1, "Yard route return smoke should buy one train.")
	var t: Dictionary = main.trains[0]
	t["tile"] = Vector2i(16, 5)
	t["pos"] = main._grid_to_screen(Vector2i(16, 5))
	t["path"] = []
	t["path_index"] = 0
	t["cargo"] = "freight"
	t["cargo_amount"] = 10
	t["stop_index"] = 2
	t["state"] = "Idle"
	main._handle_station_arrival(t)
	_require(t.get("cargo", "") == "" and int(t.get("cargo_amount", 0)) == 0, "East Line should unload yard freight.")
	_require(main._next_stop_name_for_train(t) == "West Line", "After East Line unload, yard route should return to West Line.")
	var path: Array = t.get("path", [])
	_require(not path.is_empty() and path[path.size() - 1] == Vector2i(1, 4), "After East Line unload, planned path should target West Line.")

func _run_target_progress_path_smoke(main: Node) -> void:
	main.start_scenario("central_yard")
	_place_path(main, [Vector2i(1, 4), Vector2i(2, 5), Vector2i(16, 5)])
	_place_path(main, [Vector2i(2, 5), Vector2i(1, 5)])
	var physical_path: Array[Vector2i] = main._find_track_path_ignore_signals(Vector2i(2, 5), Vector2i(16, 5))
	_require(not physical_path.is_empty(), "Progress path smoke should find connected rail.")
	_require(physical_path[0] == Vector2i(3, 5), "Path explanations for an east target should prefer the eastbound leg, not a return spur behind the train.")

func _run_dispatcher_assignment_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 2000
	var line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.selected_line_id = line_id
	main._clear_selected_line_stops()
	main._handle_local_click(main._grid_to_screen(Vector2i(1, 5)))
	_require((main.lines[line_id]["route"] as Array).is_empty(), "Line editing should ignore station body clicks while plus handles are shown.")
	main._handle_local_click(main._station_add_handle_center(Vector2i(1, 5)))
	main._handle_local_click(main._station_add_handle_center(Vector2i(16, 5)))
	_require((main.lines[line_id]["route"] as Array).size() == 2, "Dispatcher smoke should allow adding line stops from station plus handles.")
	_require(main._line_cargo_preview(line_id).contains("Coal Mine -> Interchange -> Coal Mine (repeat)"), "Line preview should show the implicit return to the first stop.")
	main._complete_line_stop_edit()
	_require(not main.editing_line_stops, "Complete Line should finish stop editing.")
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
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var line_id: String = main._create_or_get_line_for_source("coal_mine")
	main._buy_train_for_line(line_id)
	main._buy_train_for_line(line_id)
	var on_source: int = main._tile_train_count(Vector2i(1, 5))
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
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
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
	_require(main._tile_train_count(Vector2i(1, 5)) == 1, "Restart Trains should visibly stage one assigned train at the line start when the platform is free.")

func _run_planning_guide_smoke(main: Node) -> void:
	main.start_scenario("central_yard")
	_require(not main.planning_guide_open, "Planning guide should be hidden by default so scenarios do not present an answer stencil.")
	main._toggle_planning_guide()
	_require(main.planning_guide_open, "Planning guide toggle should show the optional example layout.")
	main._toggle_planning_guide()
	_require(not main.planning_guide_open, "Planning guide toggle should hide the optional example layout.")

func _run_signal_siding_smoke(main: Node) -> void:
	main.start_scenario("central_yard")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	_place_path(main, [Vector2i(5, 5), Vector2i(5, 7), Vector2i(12, 7), Vector2i(12, 5)])
	_require(not main._has_track_segment(Vector2i(7, 5), Vector2i(7, 6)), "Parallel siding should not auto-connect to adjacent mainline tiles.")
	_require(not main._has_track_segment(Vector2i(8, 5), Vector2i(8, 6)), "Parallel siding middle tiles should stay independent unless explicitly connected.")
	_require(not main._has_track_segment(Vector2i(9, 5), Vector2i(9, 6)), "Explicit segment placement should prevent accidental ladder junctions.")
	main._place_signal_pair(Vector2i(4, 5), "block")
	main._place_signal_pair(Vector2i(5, 7), "block")
	main._place_signal_pair(Vector2i(12, 7), "block")
	main._place_signal_pair(Vector2i(13, 5), "block")
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
	_place_path(main, [Vector2i(1, 4), Vector2i(2, 5), Vector2i(16, 5)])
	_place_path(main, [Vector2i(16, 5), Vector2i(14, 7), Vector2i(10, 7), Vector2i(9, 5)])
	_place_path(main, [Vector2i(9, 5), Vector2i(7, 3), Vector2i(2, 3), Vector2i(1, 4)])
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	var northwest: Array[Vector2i] = [Vector2i(-1, -1)]
	main._replace_signal_set(Vector2i(3, 5), "block", east)
	main._replace_signal_set(Vector2i(5, 5), "block", east)
	main._replace_signal_set(Vector2i(8, 5), "block", east)
	main._replace_signal_set(Vector2i(11, 5), "block", east)
	main._replace_signal_set(Vector2i(14, 5), "block", east)
	main._replace_signal_set(Vector2i(15, 5), "block", east)
	main._replace_signal_set(Vector2i(14, 7), "block", west)
	main._replace_signal_set(Vector2i(12, 7), "block", west)
	main._replace_signal_set(Vector2i(10, 7), "chain", northwest)
	main._replace_signal_set(Vector2i(7, 3), "block", west)
	main._replace_signal_set(Vector2i(5, 3), "block", west)
	main._replace_signal_set(Vector2i(3, 3), "block", west)
	main._compute_blocks()
	main._add_platform()
	main._add_platform()
	main._add_platform()
	for i in range(4):
		main._buy_train_for_source("west_line")
	for i in range(3600):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	var no_route_count := 0
	for t in main.trains:
		if t["state"] == "NoRoute":
			no_route_count += 1
	_require(main.screen == main.Screen.RESULTS, "Advanced Central Yard should clear with the right-hand loop solution.")
	_require(main.trains.size() == 4, "Advanced Central Yard should support buying four trains.")
	_require(no_route_count == 0, "Advanced Central Yard trains should retain valid line routes during smoke.")
	_require(int(main.result_data.get("productive_progress", 0)) >= 60 or int(main.local.get("productive_progress", 0)) >= 60, "Advanced Central Yard should hit the productive output target.")

func _run_overtake_pass_smoke(main: Node) -> void:
	main.start_scenario("overtake_pass")
	main.local["money"] = 9000
	main.local["materials"] = 20
	_build_overtake_pass_solution(main)
	_add_overtake_pass_signals(main)
	var line_id: String = main._create_or_get_line_for_source("west_line")
	for i in range(4):
		main._buy_train_for_line(line_id)
	for i in range(8000):
		if main.screen != main.Screen.LOCAL:
			break
		_step_fast(main, 0.1)
	_require(main.screen == main.Screen.RESULTS, "Overtake Pass should complete with four trains on short passing pockets.")
	_require(int(main.result_data.get("productive_progress", 0)) >= 40 or int(main.local.get("productive_progress", 0)) >= 40, "Overtake Pass should process its full freight target.")
	_require(int(main.local.get("deadlocks", 0)) == 0, "Overtake Pass solution should not deadlock.")
	_require(main._average_wait() <= float(main.local.get("wait_target", 120.0)), "Overtake Pass solution should stay inside the tuned wait target.")

func _build_overtake_pass_solution(main: Node) -> void:
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	_place_path(main, [Vector2i(3, 5), Vector2i(4, 4), Vector2i(6, 4), Vector2i(7, 5)])
	_place_path(main, [Vector2i(8, 5), Vector2i(9, 4), Vector2i(11, 4), Vector2i(12, 5)])
	_place_path(main, [Vector2i(13, 5), Vector2i(14, 4), Vector2i(15, 4), Vector2i(16, 5)])
	main._compute_blocks()

func _add_overtake_pass_signals(main: Node) -> void:
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	var southwest: Array[Vector2i] = [Vector2i(-1, 1)]
	var east_west: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT]
	var east_northwest: Array[Vector2i] = [Vector2i.RIGHT, Vector2i(-1, -1)]
	var east_station: Array[Vector2i] = [Vector2i(-1, -1)]
	main._replace_signal_set(Vector2i(1, 5), "chain", east)
	main._replace_signal_set(Vector2i(3, 5), "block", east_west)
	main._replace_signal_set(Vector2i(6, 4), "block", west)
	main._replace_signal_set(Vector2i(4, 4), "block", southwest)
	main._replace_signal_set(Vector2i(7, 5), "block", east_northwest)
	main._replace_signal_set(Vector2i(8, 5), "block", east_west)
	main._replace_signal_set(Vector2i(11, 4), "block", west)
	main._replace_signal_set(Vector2i(9, 4), "block", southwest)
	main._replace_signal_set(Vector2i(12, 5), "block", east_northwest)
	main._replace_signal_set(Vector2i(13, 5), "block", east_west)
	main._replace_signal_set(Vector2i(14, 4), "block", southwest)
	main._replace_signal_set(Vector2i(15, 4), "block", west)
	main._replace_signal_set(Vector2i(15, 5), "block", east)
	main._replace_signal_set(Vector2i(16, 5), "chain", east_station)
	main._compute_blocks()

func _run_line_density_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 10000
	main.local["target"] = 100000
	main.station_by_id["coal_mine"]["platforms"] = 4
	main.station_by_id["interchange"]["platforms"] = 4
	_place_path(main, [Vector2i(1, 5), Vector2i(1, 7), Vector2i(16, 7), Vector2i(16, 5)])
	_place_path(main, [Vector2i(16, 5), Vector2i(16, 3), Vector2i(1, 3), Vector2i(1, 5)])
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	for x in range(2, 16, 2):
		main._replace_signal_set(Vector2i(x, 7), "block", east)
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

func _step_fast(main: Node, delta: float) -> void:
	main._generate_station_cargo(delta)
	main._compute_blocks()
	main._dispatch_waiting_trains()
	main._refresh_reservations()
	var progress_before: int = main._objective_progress()
	for t in main.trains:
		main._update_train(t, delta)
		main._refresh_reservations()
	var progress_after: int = main._objective_progress()
	if progress_after > progress_before:
		main.elapsed_since_progress = 0.0
	else:
		main.elapsed_since_progress += delta
	main._detect_congestion(delta)
	if main._objective_complete():
		main._complete_scenario()

func _require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
