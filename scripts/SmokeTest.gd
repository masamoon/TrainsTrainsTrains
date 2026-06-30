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
	_run_context_menu_smoke(main)
	_run_productive_output_smoke(main)
	_run_debug_money_smoke(main)
	_run_money_only_build_smoke(main)
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
	_run_train_card_issue_smoke(main)
	_run_yard_route_return_smoke(main)
	_run_target_progress_path_smoke(main)
	_run_paired_chain_signal_smoke(main)
	_run_dispatcher_assignment_smoke(main)
	_run_depot_dispatch_smoke(main)
	_run_multiple_lines_one_source_smoke(main)
	_run_restart_preserves_fleet_smoke(main)
	_run_station_resource_badge_smoke(main)
	_run_generated_pool_smoke(main)
	_run_generated_contract_play_smoke(main)
	_run_run_progression_smoke(main)
	_run_reset_progress_smoke(main)
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
	_require(board_size.y >= 560.0, "Map-first local UI should give the board most of the vertical screen at 1280x720.")
	_require(main.side_panel == null and main.dispatch_line_box == null and main.dispatch_train_box == null and main.dispatch_preview == null, "Local play should not create persistent management panels.")
	_require(main.tool_bar == null, "Local play should not create a persistent tool bar.")
	main.size = Vector2(2048, 1024)
	main._update_board_layout()
	_require(main.side_panel == null and main.tool_bar == null, "Wide local play should remain map-first without panels.")
	main.size = Vector2(640, 480)
	main.start_scenario("coal_valley")
	_require(_control_inside_viewport(main.hud_bar, main.size), "Compact local HUD controls should stay inside a mobile-sized viewport.")
	_require(main.hud_bar.get_child_count() >= 4, "Compact local HUD should expose pause, speed, train reset, and region controls.")

func _run_context_menu_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	var station_screen: Vector2 = main._grid_to_screen(Vector2i(1, 5))
	main.press_active = true
	main.press_start_pos = station_screen
	main.press_start_cell = Vector2i(1, 5)
	main._process(0.5)
	_require(main.context_menu_open, "Long-pressing a station should open contextual actions.")
	_require(main.context_menu_layer.get_child_count() >= 3, "Station radial menu should expose service/train/platform actions.")
	main._close_context_menu()
	main._context_create_service("coal_mine")
	_require(main.editing_line_stops and main.service_edit_bar.visible, "Creating a service from a station should enter compact service-edit mode.")
	main._handle_local_click(main._station_add_handle_center(Vector2i(1, 5)))
	main._handle_local_click(main._station_add_handle_center(Vector2i(16, 5)))
	_require((main.lines[main.selected_line_id]["route"] as Array).size() == 2, "Service-edit mode should add stops by tapping station plus handles.")
	main._complete_service_edit()
	_require(not main.editing_line_stops and not main.service_edit_bar.visible, "Completing service edit should hide the floating edit chip.")
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._open_context_menu_at(main._grid_to_screen(Vector2i(5, 5)), "track", "", Vector2i(5, 5))
	_require(main.context_menu_open and main.context_menu_layer.get_child_count() >= 3, "Holding track should expose signal and erase actions.")
	main._close_context_menu()
	main._place_signal(Vector2i(5, 5), "block")
	main._handle_local_click(main._grid_to_screen(Vector2i(5, 5)))
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 2, "Tapping an existing signal should pair it without opening a menu.")
	main._handle_local_click(main._grid_to_screen(Vector2i(5, 5)))
	_require(main._signal_dirs(Vector2i(5, 5)).size() == 1, "Tapping a paired signal should return it to single.")
	main._open_context_menu_at(main._grid_to_screen(Vector2i(5, 5)), "signal", "", Vector2i(5, 5))
	_require(main.context_menu_open and main.context_menu_layer.get_child_count() >= 3, "Holding a signal should expose rotate, pair, and erase actions.")
	main._close_context_menu()
	main._buy_available_train()
	main._context_assign_train(String(main.trains[0]["id"]))
	_require(String(main.trains[0].get("line_id", "")) == main.selected_line_id, "Train should be assignable through object-first context actions.")
	var overlap_target: Dictionary = main._context_target_at(station_screen)
	_require(String(overlap_target.get("type", "")) == "station", "Station context actions should remain reachable when a train overlaps the station.")
	main.selected_train_id = String(main.trains[0]["id"])
	main._handle_local_click(station_screen)
	_require(main.selected_train_id == "", "Tapping an occupied station should inspect the station instead of selecting the overlapping train.")

func _run_productive_output_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["fleet_goal"] = 4
	main.local["target"] = 12
	main._record_productive_output(12)
	_require(int(main.local.get("productive_progress", 0)) == 12, "Productive output should count delivered cargo even before the fleet objective is met.")
	_require(not main._objective_complete(), "Fleet target should remain a separate completion requirement.")

func _run_debug_money_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	var before: int = int(main.local["money"])
	main._debug_replenish_money()
	_require(int(main.local["money"]) == before + 5000, "Debug money button should add $5000 to the local budget.")

func _run_money_only_build_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 1000
	main.local["materials"] = 0
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var before_chain_money: int = int(main.local["money"])
	main._place_signal(Vector2i(5, 5), "chain")
	_require(main.signals.has(Vector2i(5, 5)), "Chain signals should place with money only when materials are zero.")
	_require(int(main.local["money"]) == before_chain_money - 120, "Chain signal should spend only money.")
	_require(int(main.local["materials"]) == 0, "Chain signal should not spend materials.")
	var before_platform_money: int = int(main.local["money"])
	var platform_before: int = int(main.station_by_id["interchange"].get("platforms", 1))
	main._add_platform()
	_require(int(main.station_by_id["interchange"].get("platforms", 1)) == platform_before + 1, "Platforms should build with money only when materials are zero.")
	_require(int(main.local["money"]) == before_platform_money - 200, "Platform should spend only money.")
	_require(int(main.local["materials"]) == 0, "Platform should not spend materials.")

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

func _run_train_card_issue_smoke(main: Node) -> void:
	var t := {
		"state": "NoRoute",
		"wait_reason": "Signal only opens west / left, but this train needs east / right.",
		"route": ["west_line", "central_yard"],
		"line_id": "line_west_line"
	}
	var label: String = main._train_card_issue_label(t)
	_require(label.contains("Why:"), "Train cards should include a reason line for NoRoute trains.")
	_require(label.contains("Signal only opens"), "Train card reason should show the route failure cause.")

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

func _run_multiple_lines_one_source_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 5000
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var first_line: String = main._create_or_get_line_for_source("coal_mine")
	var second_line: String = main._create_new_line_for_source("coal_mine")
	_require(first_line != second_line, "A source should be able to create more than one independent line.")
	_require(main.lines.has(first_line) and main.lines.has(second_line), "Both source lines should exist in the dispatcher.")
	_require(String(main.lines[first_line].get("source_id", "")) == "coal_mine", "First line should remember its source station.")
	_require(String(main.lines[second_line].get("source_id", "")) == "coal_mine", "Second line should remember its source station.")
	main.lines[second_line]["route"] = ["coal_mine", "interchange"]
	main.lines[second_line]["name"] = main._line_name_for_route(main.lines[second_line]["route"], int(main.lines[second_line].get("ordinal", 1)))
	_require((main.lines[first_line]["route"] as Array).size() == 2, "Editing one line should not mutate the other line's route.")
	main._buy_train_for_line(first_line)
	main._buy_train_for_line(second_line)
	_require(main.trains.size() == 2, "One source should support trains assigned to separate lines.")
	_require(String(main.trains[0].get("line_id", "")) != String(main.trains[1].get("line_id", "")), "Trains should keep their separate line assignments.")

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

func _run_station_resource_badge_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	_require(main._station_output_badge_text(main.station_by_id["coal_mine"]) == "OUT COAL 240", "Source station badge should show available produced coal at a glance.")
	_require(main._station_need_badge_text(main.station_by_id["interchange"]) == "NEEDS COAL", "Sink station badge should show required coal at a glance.")
	main.start_scenario("run_06")
	_require(main._station_output_badge_text(main.station_by_id["coal_input"]) == "OUT COAL 240", "Steel input should show available coal.")
	_require(main._station_need_badge_text(main.station_by_id["steelworks"]) == "NEEDS COAL", "Processor badge should show required input cargo.")
	_require(main._station_output_badge_text(main.station_by_id["steelworks"]) == "OUT STEEL 0", "Processor badge should show available output buffer.")
	_require(main._station_need_badge_text(main.station_by_id["export_platform"]) == "NEEDS STEEL", "Export station badge should show required steel.")

func _run_generated_pool_smoke(main: Node) -> void:
	_reset_run_state(main)
	var run_count := 0
	var terrain_count := 0
	var hard_count := 0
	var branch_contract_count := 0
	for s in main.scenarios:
		if String(s.get("id", "")).begins_with(main.RUN_SCENARIO_PREFIX):
			run_count += 1
			if not (s.get("terrain", []) as Array).is_empty():
				terrain_count += 1
			if int(s.get("difficulty", 1)) >= 3:
				hard_count += 1
			if _route_has_branching_obligation(s):
				branch_contract_count += 1
			_require(_ghost_avoids_blocking_terrain(s), "%s solution path should avoid mountains, rocks, and ocean." % s.get("name", s.get("id", "")))
			_require(_ghost_visits_required_stations(s), "%s solution path should connect its required stations." % s.get("name", s.get("id", "")))
			_require(_route_has_branching_obligation(s), "%s should require an off-axis route stop so a simple A-B double track is not sufficient." % s.get("name", s.get("id", "")))
	_require(run_count == main.RUN_POOL_SIZE, "Roguelike pool should generate exactly 30 map contracts.")
	_require(terrain_count >= 24, "Generated contracts should usually contain terrain constraints.")
	_require(hard_count >= 10, "Generated pool should include a late-run hard difficulty band.")
	_require(branch_contract_count == run_count, "Every generated contract should have a branching or loop obligation beyond A-to-B.")
	_require((main.campaign["run_available"] as Array).size() == main.RUN_CHOICES, "A fresh run should offer three contract choices.")
	var first_id: String = String((main.campaign["run_available"] as Array)[0])
	main.start_scenario(first_id)
	var blocked_tile := Vector2i(-999, -999)
	for item in main.local["scenario"].get("terrain", []):
		if String(item.get("type", "")) in ["mountain", "rock", "ocean"]:
			blocked_tile = item["pos"]
			break
	if blocked_tile.x > -900:
		main._place_track(blocked_tile)
		_require(not main.tracks.has(blocked_tile), "Mountains, rocks, and ocean should block new player track.")
	var river_tile := Vector2i(-999, -999)
	for item in main.local["scenario"].get("terrain", []):
		if String(item.get("type", "")) == "river":
			river_tile = item["pos"]
			break
	if river_tile.x > -900:
		main.local["money"] = 1000
		var money_before: int = int(main.local["money"])
		main._place_track(river_tile)
		_require(main.tracks.has(river_tile), "River tiles should allow bridge track.")
		_require(int(main.local["money"]) == money_before - 85, "River bridge track should cost $85.")

func _run_generated_contract_play_smoke(main: Node) -> void:
	for id in ["run_01", "run_02", "run_03", "run_04", "run_05", "run_06"]:
		_reset_run_state(main)
		main.start_scenario(id)
		main.local["money"] = 9000
		main.local["fleet_goal"] = 1
		if main.local.get("kind", "") == "yard":
			main.local["target"] = 1
		elif main.local.get("kind", "") == "steel":
			main.local["target"] = 20
		else:
			main.local["target"] = 40
		_build_ghost_solution(main)
		main._compute_blocks()
		var source_id := String(main.local["scenario"]["route"][0])
		main._buy_train_for_source(source_id)
		for i in range(1600):
			if main.screen != main.Screen.LOCAL:
				break
			_step_fast(main, 0.1)
		var train_state := "none"
		var train_reason := "none"
		if not main.trains.is_empty():
			train_state = String(main.trains[0].get("state", ""))
			train_reason = String(main.trains[0].get("wait_reason", ""))
		_require(main.screen == main.Screen.RESULTS, "%s should be completable through actual train movement. State: %s Reason: %s Progress: %d/%d" % [id, train_state, train_reason, main._completion_progress(), int(main.local.get("target", 0))])
		_require((main.campaign["run_completed"] as Array).has(id), "Completing %s through play should record run completion." % id)

func _run_run_progression_smoke(main: Node) -> void:
	_reset_run_state(main)
	var guard := 0
	while int(main.campaign.get("run_step", 0)) < main.RUN_LENGTH and guard < 30:
		var choices: Array = main.campaign.get("run_available", [])
		_require(not choices.is_empty(), "Run should keep offering contracts until 20 maps are complete.")
		var id := String(choices[0])
		main.start_scenario(id)
		_force_complete_current_contract(main)
		guard += 1
	_require(int(main.campaign.get("run_step", 0)) == main.RUN_LENGTH, "Run progression should reach 20 completed maps.")
	_require(bool(main.campaign.get("run_won", false)), "Run should mark itself won after 20 completed maps.")
	_require((main.campaign.get("run_history", []) as Array).size() == main.RUN_LENGTH, "Run history should record all 20 completed maps.")
	var traits: Dictionary = main.campaign.get("regional_traits", {})
	_require(int(traits.get("through_traffic", 0)) > 0, "Completed run maps should add through-traffic pressure.")
	_require(float(traits.get("reliability", 0.0)) > 0.0, "Completed run maps should store reliability for later node interaction.")

func _run_reset_progress_smoke(main: Node) -> void:
	main.campaign["completed"] = ["coal_valley", "run_01"]
	main.campaign["run_completed"] = ["run_01", "run_02"]
	main.campaign["run_step"] = 2
	main.campaign["run_history"] = [{"id": "run_01"}, {"id": "run_02"}]
	main.campaign["run_won"] = true
	main.campaign["money"] = 9999
	main.campaign["traffic_load"] = 99
	main.campaign["traffic_capacity"] = 12
	main.campaign["regional_traits"] = {
		"coal_output": 100,
		"freight_output": 200,
		"steel_output": 300,
		"reliability": 0.4,
		"capacity_rating": 5,
		"through_traffic": 9,
		"burstiness": 1.2
	}
	main._reset_progress(false)
	_require(int(main.campaign["money"]) == 1500, "Reset Progress should restore starting money.")
	_require(int(main.campaign["traffic_load"]) == 18 and int(main.campaign["traffic_capacity"]) == 40, "Reset Progress should restore regional traffic defaults.")
	_require((main.campaign["completed"] as Array).is_empty(), "Reset Progress should clear completed tutorial/run IDs.")
	_require((main.campaign["run_completed"] as Array).is_empty(), "Reset Progress should clear run completions.")
	_require((main.campaign["run_history"] as Array).is_empty(), "Reset Progress should clear run history.")
	_require(int(main.campaign["run_step"]) == 0 and not bool(main.campaign["run_won"]), "Reset Progress should return the run to 0/20 and not won.")
	_require((main.campaign["run_available"] as Array).size() == main.RUN_CHOICES, "Reset Progress should generate fresh contract choices.")
	var traits: Dictionary = main.campaign["regional_traits"]
	_require(int(traits.get("through_traffic", -1)) == 0 and float(traits.get("reliability", 0.0)) == 1.0, "Reset Progress should restore inherited regional traits.")

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

func _reset_run_state(main: Node) -> void:
	main.campaign["money"] = 1500
	main.campaign["materials"] = 4
	main.campaign["traffic_load"] = 18
	main.campaign["traffic_capacity"] = 40
	main.campaign["completed"] = []
	main.campaign["run_seed"] = 32027
	main.campaign["run_step"] = 0
	main.campaign["run_completed"] = []
	main.campaign["run_available"] = []
	main.campaign["run_history"] = []
	main.campaign["run_won"] = false
	main.campaign["regional_traits"] = {
		"coal_output": 0,
		"freight_output": 0,
		"steel_output": 0,
		"reliability": 1.0,
		"capacity_rating": 0,
		"through_traffic": 0,
		"burstiness": 0.0
	}
	main._ensure_run_state()

func _force_complete_current_contract(main: Node) -> void:
	main.local["delivered"] = int(main.local.get("target", 0))
	main.local["processed"] = int(main.local.get("target", 0))
	main.local["productive_progress"] = int(main.local.get("target", 0))
	main.local["deadlocks"] = 0
	main.local["max_queue"] = 0
	main._complete_scenario()
	_require(main.screen == main.Screen.RESULTS, "Forced run contract should still use the normal results screen.")
	main._return_to_region()

func _ghost_avoids_blocking_terrain(scenario: Dictionary) -> bool:
	var ghost: Array = scenario.get("ghost", [])
	for p in ghost:
		for item in scenario.get("terrain", []):
			if item.get("pos", Vector2i(-999, -999)) == p and String(item.get("type", "")) in ["mountain", "rock", "ocean"]:
				var is_station := false
				for st in scenario.get("stations", []):
					if st.get("pos", Vector2i(-999, -999)) == p:
						is_station = true
						break
				if not is_station:
					return false
	return true

func _ghost_visits_required_stations(scenario: Dictionary) -> bool:
	var ghost: Array = scenario.get("ghost", [])
	for st in scenario.get("stations", []):
		if not _point_array_has(ghost, st.get("pos", Vector2i(-999, -999))):
			return false
	return true

func _route_has_branching_obligation(scenario: Dictionary) -> bool:
	var route: Array = scenario.get("route", [])
	if route.size() < 3:
		return false
	var by_id := {}
	for st in scenario.get("stations", []):
		by_id[String(st.get("id", ""))] = st
	if not by_id.has(String(route[0])):
		return false
	var base_y: int = int(by_id[String(route[0])].get("pos", Vector2i(-999, -999)).y)
	var unique_positions: Array[Vector2i] = []
	var off_axis := false
	for station_id in route:
		var key := String(station_id)
		if not by_id.has(key):
			return false
		var p: Vector2i = by_id[key].get("pos", Vector2i(-999, -999))
		if not unique_positions.has(p):
			unique_positions.append(p)
		if abs(p.y - base_y) >= 2:
			off_axis = true
	return unique_positions.size() >= 3 and off_axis

func _point_array_has(points: Array, target: Vector2i) -> bool:
	for p in points:
		if p == target:
			return true
	return false

func _build_ghost_solution(main: Node) -> void:
	var ghost: Array = main.local["scenario"].get("ghost", [])
	for i in range(ghost.size() - 1):
		main._place_track_path(ghost[i], ghost[i + 1])

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

func _control_inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	if control == null:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5

func _require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
