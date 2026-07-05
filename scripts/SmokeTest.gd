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
	_run_test_battery_smoke(main)
	_run_layout_smoke(main)
	_run_context_menu_smoke(main)
	_run_productive_output_smoke(main)
	_run_contract_route_compliance_smoke(main)
	_run_detour_pressure_smoke(main)
	_run_completion_quality_smoke(main)
	_run_actual_efficiency_balance_smoke(main)
	_run_contract_exploit_playtest_smoke(main)
	_run_debug_money_smoke(main)
	_run_local_material_accounting_smoke(main)
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
	_run_station_resource_badge_layout_smoke(main)
	_run_generated_pool_smoke(main)
	_run_rail_sudoku_schema_smoke(main)
	_run_mixed_crossing_schema_smoke(main)
	_run_mixed_order_compatibility_smoke(main)
	_run_circular_exploit_gauntlet_smoke(main)
	_run_mobile_compact_ui_smoke(main)
	_run_regional_tile_map_smoke(main)
	_run_grade_regional_pressure_smoke(main)
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

func _run_test_battery_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["target"] = 10
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal_pair(Vector2i(5, 5), "block")
	main._buy_train()
	main._toggle_test_battery()
	_require(bool(main.local.get("test_battery_running", false)), "Test battery should start from local play.")
	for i in range(90):
		if main.screen != main.Screen.LOCAL:
			break
		main._process(1.0 / 60.0)
	_require(main.screen == main.Screen.RESULTS, "Test battery should accelerate until a winning solution completes.")
	main.start_scenario("coal_valley")
	main.local["target"] = 10
	main._buy_train()
	main._toggle_test_battery()
	for i in range(12):
		if not bool(main.local.get("test_battery_running", false)):
			break
		main._process(1.0 / 60.0)
	_require(not bool(main.local.get("test_battery_running", false)), "Test battery should stop on a no-route failure.")
	_require(bool(main.local.get("paused", false)), "Test battery failure should leave the simulation paused for inspection.")
	_require(String(main.local_message).to_lower().contains("no route"), "Test battery failure should explain the no-route problem.")

func _run_layout_smoke(main: Node) -> void:
	main.size = Vector2(1280, 720)
	main.start_scenario("coal_valley")
	main._update_board_layout()
	var grid: Vector2i = main.local["scenario"]["grid"]
	var board_size := Vector2(float(grid.x) * main.cell_size, float(grid.y) * main.cell_size)
	_require(main.cell_size >= 46.0, "Expanded local maps should keep cells at the readable minimum at 1280x720.")
	_require(board_size.x >= 820.0, "Expanded local map should give passing infrastructure more horizontal room at 1280x720.")
	_require(board_size.y >= 500.0, "Integrated local UI should keep the board readable while reserving tray space at 1280x720.")
	_require(main.side_panel != null and main.side_text != null, "Local play should create an integrated bottom info tray for contract details.")
	_require(main.dispatch_line_box == null and main.dispatch_train_box == null and main.dispatch_preview == null, "Local play should not create persistent dispatch management panels.")
	_require(main.grid_origin.y + board_size.y <= main.size.y + main.side_panel.offset_top + 1.0, "Integrated bottom info tray should not cover board tiles.")
	_require(main.tool_bar == null, "Local play should not create a persistent tool bar.")
	main.size = Vector2(2048, 1024)
	main._update_board_layout()
	_require(main.cell_size >= 64.0, "Wide browser play should scale the local map beyond the small-screen cell size while reserving tray space.")
	var wide_board_width: float = float(grid.x) * main.cell_size
	_require(abs(main.grid_origin.x - (main.size.x - wide_board_width) * 0.5) <= 1.0, "Wide local map should center horizontally when height limits the board scale.")
	_require(main.side_panel != null and main.tool_bar == null, "Wide local play should keep the integrated info tray without adding tool panels.")
	main.rebuild_ui()
	_require(main.hud_bar.get_child(0).custom_minimum_size.x >= 150.0, "Wide browser HUD buttons should scale up for desktop play.")
	main.screen = main.Screen.REGIONAL
	main.size = Vector2(2048, 1024)
	_require(main._regional_draw_tile_size() >= 118.0, "Wide browser regional map should use the available screen instead of staying capped at small tiles.")
	_require(main._regional_tile_at_screen(main._regional_node_position("coal_valley")).is_empty(), "Wide regional map should not cover tutorial contract nodes.")
	main.size = Vector2(1280, 720)
	_require(main._regional_draw_tile_size() >= 80.0, "Default browser regional map should stay readable at 1280x720.")
	_require(main._regional_tile_at_screen(main._regional_node_position("coal_valley")).is_empty(), "Default browser regional map should reserve space for tutorial contract nodes.")
	main.size = Vector2(3840, 2160)
	main.start_scenario("coal_valley")
	main._update_board_layout()
	_require(main._ui_scale() > 1.8, "High-DPI browser layout should detect the larger logical canvas.")
	_require(main.cell_size >= 150.0, "High-DPI browser local map should grow past the old desktop cap while reserving tray space.")
	main.rebuild_ui()
	_require(main.hud_bar.get_child(0).custom_minimum_size.x >= 280.0, "High-DPI browser HUD buttons should remain readable.")
	main.screen = main.Screen.REGIONAL
	_require(main._regional_draw_tile_size() >= 230.0, "High-DPI browser regional map should grow past the old regional tile cap.")
	main.size = Vector2(640, 480)
	main.start_scenario("coal_valley")
	main._update_board_layout()
	board_size = Vector2(float(grid.x) * main.cell_size, float(grid.y) * main.cell_size)
	_require(main.grid_origin.y + board_size.y <= main.size.y + main.side_panel.offset_top - 1.0, "Compact local tray should not cover the last row of board tiles.")
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
	_require(String(overlap_target.get("type", "")) == "station_train", "Occupied stations should expose combined station and train context actions.")
	var overlap_actions: Array = main._context_actions_for_target(String(overlap_target.get("type", "")), String(overlap_target.get("id", "")), overlap_target.get("pos", Vector2i(-999, -999)))
	_require(_action_labels_have(overlap_actions, "Train") and _action_labels_have(overlap_actions, "Assign"), "Occupied station menu should allow buying another train and acting on the parked train.")
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
	main.local["infra_cost"] = 300
	main.local["elapsed_time"] = 30.0
	var efficient_reward: int = main._completion_reward_money(main.local["scenario"], 2.0, true)
	main.local["infra_cost"] = 3000
	main.local["elapsed_time"] = 400.0
	var expensive_reward: int = main._completion_reward_money(main.local["scenario"], 2.0, true)
	_require(efficient_reward > expensive_reward, "Regional money reward should be higher for lower material usage and faster completion.")

func _run_contract_route_compliance_smoke(main: Node) -> void:
	main.start_scenario("steelworks")
	var clause_text: String = main._local_contract_clause_text()
	_require(clause_text.contains("Contract Clauses"), "Local maps should surface contract clauses before the player builds.")
	_require(clause_text.contains("West Line") and clause_text.contains("Central Yard") and clause_text.contains("East Line"), "Contract clauses should name the required station order.")
	_require(clause_text.contains("Trip proof") and clause_text.contains("handoff shuttles stay sandbox"), "Contract clauses should explain that non-processor shuttle handoffs do not count as contract proof.")
	_require(clause_text.contains("Gold target") and clause_text.contains("Flow") and clause_text.contains("clean routing"), "Contract clauses should expose the grade target before building.")
	_require(clause_text.contains("Compact service"), "Contract clauses should explain that circular detours lower grade.")
	main._refresh_inspect_chip()
	_require(not main.inspect_chip.visible, "Idle inspect chip should stay hidden so contract clauses do not cover the map.")
	_require(main.side_text.text.contains("Contract Clauses") and main.side_text.text.contains("Gold target"), "Local bottom info should carry contract clauses before the player builds.")
	main.local["target"] = 999
	main.local["fleet_goal"] = 1
	_place_path(main, [Vector2i(1, 4), Vector2i(2, 5), Vector2i(16, 5)])
	var line_id: String = main._create_or_get_line_for_source("west_line")
	main.lines[line_id]["route"] = ["west_line", "east_line"]
	main.lines[line_id]["name"] = main._line_name_for_route(main.lines[line_id]["route"], int(main.lines[line_id].get("ordinal", 1)))
	_require(not main._line_contract_ready(line_id), "Shortcut source-to-sink service should not satisfy a yard contract.")
	_require(main._line_cargo_preview(line_id).contains("Contract output inactive"), "Line preview should explain when shortcut routes do not count for the contract.")
	_require(main._line_cargo_preview(line_id).contains("Service plan: sandbox only"), "Line preview should label shortcut routes as sandbox-only instead of contract progress.")
	main.selected_line_id = line_id
	main._complete_line_stop_edit()
	_require(main.local_message.contains("sandbox only"), "Completing a shortcut service should immediately explain that contract output is inactive.")
	main._buy_train_for_line(line_id)
	for i in range(260):
		main._update_local(0.1)
	_require(int(main.local.get("processed", 0)) > 0, "Shortcut service can still move freight as a sandbox experiment.")
	_require(int(main.local.get("productive_progress", 0)) == 0, "Shortcut service should not count toward contract output.")
	_require(int(main.local.get("unqualified_output", 0)) > 0, "Shortcut service output should be tracked separately for feedback.")
	main.lines[line_id]["route"] = ["west_line", "central_yard", "east_line"]
	var ready_preview: String = main._line_cargo_preview(line_id)
	_require(ready_preview.contains("Gold target"), "Line preview should include the grade target for contract-ready service.")
	_require(ready_preview.contains("Service plan: contract-ready clean loop"), "Line preview should affirm compact contract-ready service.")
	_require(ready_preview.contains("Preview pressure") and ready_preview.contains("clean route shape"), "Line preview should forecast clean pressure for compact contract-ready service.")
	main._complete_line_stop_edit()
	_require(main.local_message.contains("contract-ready clean loop"), "Completing a compact required route should affirm that it can score contract output.")
	main._reapply_line_to_assigned_trains(line_id)
	var bypass_train := {
		"id": "Bypass",
		"route": ["west_line", "central_yard", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line"]
	}
	main._process_cargo_at_station(bypass_train, main.station_by_id["east_line"])
	_require(int(main.local.get("productive_progress", 0)) == 0, "A load should not count just because the route definition includes the yard; the trip must actually visit it.")
	var qualified_train := {
		"id": "Qualified",
		"route": ["west_line", "central_yard", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line", "central_yard"]
	}
	main._process_cargo_at_station(qualified_train, main.station_by_id["east_line"])
	_require(int(main.local.get("productive_progress", 0)) > 0, "A load that actually visited the required yard should count.")
	main.local["processed"] = 0
	main.local["productive_progress"] = 0
	main.local["unqualified_output"] = 0
	main._restart_trains_only()
	for i in range(360):
		main._update_local(0.1)
	_require(main._line_contract_ready(line_id), "Service that visits required contract stops in order should be contract-ready.")
	_require(int(main.local.get("productive_progress", 0)) > 0, "Contract-ready service should count delivered freight as contract output.")

func _run_detour_pressure_smoke(main: Node) -> void:
	main.start_scenario("steelworks")
	main.local["target"] = 60
	main.local["fleet_goal"] = 1
	main.local["service_mileage"] = 0.0
	main.local["empty_mileage"] = 0.0
	var mileage_probe := {
		"id": "Probe",
		"route": ["west_line", "central_yard"],
		"tile": Vector2i(1, 4),
		"pos": main._grid_to_screen(Vector2i(1, 4)),
		"path": [Vector2i(2, 5)],
		"path_index": 0,
		"cargo_amount": 0,
		"speed": 1000.0,
		"state": "Idle",
		"wait_time": 0.0,
		"total_wait": 0.0
	}
	main._update_train(mileage_probe, 0.1)
	_require(float(main.local.get("service_mileage", 0.0)) > 0.0, "Actual train movement should add service mileage.")
	_require(float(main.local.get("empty_mileage", 0.0)) > 0.0, "Actual empty train movement should add empty mileage.")
	main.local["service_mileage"] = 0.0
	main.local["empty_mileage"] = 0.0
	var line_id: String = main._create_or_get_line_for_source("west_line")
	main.lines[line_id]["route"] = ["west_line", "central_yard", "west_line", "east_line"]
	main.lines[line_id]["name"] = main._line_name_for_route(main.lines[line_id]["route"], int(main.lines[line_id].get("ordinal", 1)))
	_require(main._line_contract_ready(line_id), "Detour-heavy service should still be contract-ready when it visits required stops in order.")
	_require(main._line_cargo_preview(line_id).contains("Detour pressure"), "Line preview should warn that extra pre-delivery stops lower grade.")
	var required_stop_train := {
		"id": "RequiredStop",
		"name": "RequiredStop",
		"route": ["west_line", "central_yard", "west_line", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line"],
		"dwell": 0.0
	}
	main.local["detour_dwell"] = 0.0
	main._process_cargo_at_station(required_stop_train, main.station_by_id["central_yard"])
	_require(String(required_stop_train.get("dwell_state", "")) != "DetourStop", "Required contract stops should not receive detour dwell.")
	_require(float(main.local.get("detour_dwell", 0.0)) == 0.0, "Required contract stops should not add detour dwell time.")
	var runtime_detour_train := {
		"id": "RuntimeDetour",
		"name": "RuntimeDetour",
		"route": ["west_line", "central_yard", "west_line", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line", "central_yard"],
		"dwell": 0.0
	}
	main._process_cargo_at_station(runtime_detour_train, main.station_by_id["west_line"])
	_require(String(runtime_detour_train.get("dwell_state", "")) == "DetourStop", "Loaded loopback stops should create immediate detour dwell.")
	_require(float(runtime_detour_train.get("dwell", 0.0)) > 0.8, "Loaded loopback stops should dwell longer than a normal station stop.")
	_require(float(main.local.get("detour_dwell", 0.0)) > 0.0, "Runtime detour dwell should be tracked for player feedback.")
	var detour_train := {
		"id": "Detour",
		"route": ["west_line", "central_yard", "west_line", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line", "central_yard", "west_line", "east_line"]
	}
	main._record_productive_output(10, detour_train, "east_line")
	_require(int(main.local.get("productive_progress", 0)) == 10, "Detoured contract-valid trips should still count as output.")
	_require(int(main.local.get("detour_output", 0)) == 10, "Detoured contract-valid trips should be tracked separately for grade pressure.")
	_require(int(main.local.get("detour_stops", 0)) == 1, "Detour pressure should count unnecessary station stops before delivery.")
	main.local["productive_progress"] = 0
	var long_mileage_train := {
		"id": "LongMileage",
		"route": ["west_line", "central_yard", "east_line"],
		"cargo": "freight",
		"cargo_amount": 10,
		"contract_trip_visited": ["west_line", "central_yard", "east_line"],
		"contract_trip_distance": 42.0
	}
	main._record_productive_output(10, long_mileage_train, "east_line")
	_require(int(main.local.get("productive_progress", 0)) == 10, "Long physical loops should still count when the trip visits contract stops.")
	_require(int(main.local.get("excess_mileage_output", 0)) == 10, "Long physical loops should be tracked separately for mileage pressure.")
	_require(int(main.local.get("excess_mileage", 0)) > 0, "Mileage pressure should count loaded travel beyond the generous contract allowance.")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["infra_cost"] = 420
	main.local["elapsed_time"] = 55.0
	main.local["deadlocks"] = 0
	main.local["unqualified_output"] = 0
	main.local["detour_output"] = 0
	main.local["detour_stops"] = 0
	main.local["excess_mileage"] = 0
	main.local["excess_mileage_output"] = 0
	var clean_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	main.local["detour_output"] = int(main.local["target"])
	main.local["detour_stops"] = 6
	var loop_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(clean_reward > loop_reward, "Detour-heavy circular clears should pay less than direct contract service.")
	main.local["detour_output"] = 0
	main.local["detour_stops"] = 0
	main.local["excess_mileage"] = 22
	main.local["excess_mileage_output"] = int(main.local["target"])
	var long_mileage_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(clean_reward > long_mileage_reward, "Long-mileage circular clears should pay less than compact contract service.")
	main.local["excess_mileage"] = 0
	main.local["excess_mileage_output"] = 0
	main.local["service_mileage"] = 280.0
	main.local["empty_mileage"] = 180.0
	_require(main._operating_cost() > 0, "Operating cost should accrue from actual service and empty mileage.")
	var empty_loop_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(clean_reward > empty_loop_reward, "Empty-return circular clears should pay less than compact contract service.")
	var loop_summary: String = main._completion_quality_summary(main.local["scenario"], 1.0, true)
	_require(loop_summary.contains("Ops -$") and loop_summary.contains("Service"), "Completion summary should expose operating cost and service mileage pressure.")
	main.local["service_mileage"] = 0.0
	main.local["empty_mileage"] = 0.0
	main.lines[line_id]["route"] = ["west_line", "central_yard", "east_line", "central_yard", "west_line"]
	main.trains = [{"id": "RouteProbe", "line_id": line_id}]
	_require(main._active_route_repeat_score() == 0, "Contract-required yard revisits should not count as catch-all repeated-stop pressure.")
	var clean_route_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	main.lines[line_id]["route"] = ["west_line", "central_yard", "east_line", "central_yard", "west_line", "central_yard", "east_line", "central_yard"]
	_require(main._active_route_bloat_score() == 3, "Extra scheduled stops beyond the contract loop should be tracked as route bloat.")
	_require(main._active_route_repeat_score() > 0, "Extra repeated scheduled stops should be tracked as catch-all route pressure.")
	var bloated_preview: String = main._line_cargo_preview(line_id)
	_require(bloated_preview.contains("Service plan: contract-valid") and bloated_preview.contains("pressure grade and bonus"), "Line preview should distinguish valid but pressured loops from invalid shortcut exploits.")
	_require(bloated_preview.contains("Route discipline"), "Line preview should warn when scheduled circular stops exceed the contract loop.")
	_require(bloated_preview.contains("Catch-all pressure"), "Line preview should warn when catch-all routes repeat stations beyond the contract proof.")
	_require(bloated_preview.contains("Preview pressure") and bloated_preview.contains("Route +3") and bloated_preview.contains("Repeat +"), "Line preview should summarize route and repeat pressure before trains run.")
	var bloated_route_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(clean_route_reward > bloated_route_reward, "Overscheduled circular services should pay less than the contract loop shape.")
	main.start_scenario("coal_valley")
	main.local["target"] = 60
	main.local["fleet_goal"] = 1
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var sprawl_line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.trains = [{"id": "CompactRail", "line_id": sprawl_line_id}]
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	main.local["elapsed_time"] = 1.0
	main.local["max_output_gap"] = 1.0
	var compact_sprawl_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._network_sprawl_score(main.local["scenario"]) == 0, "Compact proof-path rail should not create sprawl pressure.")
	_place_path(main, [Vector2i(1, 5), Vector2i(1, 8), Vector2i(16, 8), Vector2i(16, 5)])
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var sprawled_preview: String = main._line_cargo_preview(sprawl_line_id)
	var sprawled_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._network_sprawl_score(main.local["scenario"]) > 0, "Map-wide comfort loops should count as rail sprawl beyond the proof budget.")
	_require(sprawled_preview.contains("Rail +"), "Line preview should warn about network sprawl before completion.")
	var created_sprawl_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_sprawl_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Rail sprawl"), "Local side panel should explain rail sprawl pressure while building.")
	if created_sprawl_side_text:
		main.side_text.free()
		main.side_text = null
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Rail +"), "Completion summary should expose network sprawl pressure.")
	_require(_grade_rank(compact_sprawl_grade) > _grade_rank(sprawled_grade), "Compact rail should grade above map-wide circular comfort loops.")

func _run_completion_quality_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["fleet_goal"] = 1
	main.local["infra_cost"] = 420
	main.local["elapsed_time"] = 55.0
	main.local["deadlocks"] = 0
	main.local["max_queue"] = 0
	main.local["unqualified_output"] = 0
	main.local["max_output_gap"] = 5.0
	var efficient_line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.lines[efficient_line_id]["route"] = ["coal_mine", "interchange"]
	main.trains = [{"id": "Efficient", "line_id": efficient_line_id, "productive_output": int(main.local["target"])}]
	var efficient_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	var efficient_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	var quality_summary: String = main._completion_quality_summary(main.local["scenario"], 1.0, true)
	main._update_status_labels()
	main._refresh_local_side_text()
	_require(quality_summary.contains("Grade payout"), "Completion results should explain the grade payout multiplier.")
	_require(quality_summary.contains("Route +0"), "Completion results should expose route discipline pressure.")
	_require(quality_summary.contains("Ops -$"), "Completion results should expose operating cost pressure.")
	_require(quality_summary.contains("Flow"), "Completion results should expose steady-output pressure.")
	_require(quality_summary.contains("Fleet -0/+0"), "Completion results should expose fleet discipline pressure.")
	_require(main._grade_coach_text(main.local["scenario"], 1.0, true).contains("Gold-ready"), "Efficient service should get encouraging grade coach feedback.")
	_require(main._local_contract_clause_text().contains("Grade Coach"), "Local contract chip should show grade coach feedback.")
	_require(main.side_text.text.contains("Grade Coach"), "Local bottom info should show grade coach feedback.")
	_require(main.top_status.text.contains("Grade"), "Local HUD should show the live completion grade forecast.")
	_require(main.top_status.text.contains("Ops $"), "Local HUD should show live operating cost.")
	main.local["max_output_gap"] = main._flow_gap_target() * 2.2
	var bursty_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	var bursty_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(_grade_rank(efficient_grade) > _grade_rank(bursty_grade), "Bursty circular-style delivery gaps should lower dispatch grade.")
	_require(efficient_reward > bursty_reward, "Steady output should pay better than long-gapped trickle output.")
	main.local["max_output_gap"] = 5.0
	var spam_line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.lines[spam_line_id]["route"] = ["coal_mine", "interchange"]
	main.trains = []
	_require(main._fleet_preview_text().contains("add 1 train") and main._fleet_preview_text().contains("clear waits"), "Fleet preview should tell players when they still need trains for the contract clear.")
	main.local["fleet_goal"] = 3
	main.trains = [{"id": "Shortfall", "line_id": spam_line_id}]
	main.local["productive_progress"] = int(main.local["target"])
	_require(not main._objective_complete(), "Under-fleet trickle output should not complete the contract before the fleet target is met.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, false).contains("Fleet -2/+0"), "Completion summary should expose fleet shortfall pressure.")
	_require(main._grade_coach_text(main.local["scenario"], 1.0, false).contains("add 2 contract trains"), "Grade coach should tell under-fleet players how to convert progress into a clear.")
	var created_shortfall_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_shortfall_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Fleet shortfall"), "Local side panel should explain that under-fleet progress is not yet a contract clear.")
	if created_shortfall_side_text:
		main.side_text.free()
		main.side_text = null
	main.local["fleet_goal"] = 3
	main.trains = [
		{"id": "Contributor", "line_id": spam_line_id, "productive_output": int(main.local["target"])},
		{"id": "ParkedA", "line_id": spam_line_id, "productive_output": 0},
		{"id": "ParkedB", "line_id": spam_line_id, "productive_output": 0}
	]
	_require(main._objective_complete(), "Assigned idle fleet padding may still create a rough clear once output target is met.")
	_require(not main._current_productive_for_grade(1.0), "Parked trains should not satisfy productive Gold fleet proof.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, false).contains("Contrib -2"), "Completion summary should expose idle fleet contribution pressure.")
	_require(main._grade_coach_text(main.local["scenario"], 1.0, false).contains("2 more contract trains delivering"), "Grade coach should tell players to get parked contract trains working.")
	var created_contrib_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_contrib_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Fleet contribution"), "Local side panel should explain that assigned parked trains are rough-clear padding, not Gold proof.")
	if created_contrib_side_text:
		main.side_text.free()
		main.side_text = null
	main.local["fleet_goal"] = 1
	main.local["productive_progress"] = int(main.local["target"])
	main.trains = [{"id": "RightSized", "line_id": spam_line_id}]
	_require(main._fleet_preview_text().contains("right-sized"), "Fleet preview should affirm a contract-sized fleet.")
	main.trains = [
		{"id": "Comfort1", "line_id": spam_line_id},
		{"id": "Comfort2", "line_id": spam_line_id}
	]
	_require(main._fleet_preview_text().contains("comfort train"), "Fleet preview should explain the one-train comfort margin.")
	main.trains = [
		{"id": "Spam1", "line_id": spam_line_id},
		{"id": "Spam2", "line_id": spam_line_id},
		{"id": "Spam3", "line_id": spam_line_id},
		{"id": "Spam4", "line_id": spam_line_id},
		{"id": "Spam5", "line_id": spam_line_id}
	]
	var overfleet_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	var overfleet_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(main._fleet_overage() == 4, "Train spam should be tracked as fleet overage.")
	_require(main._dispatch_speed_factor() < 1.0, "Train spam should create live dispatch overload instead of only a result-screen penalty.")
	_require(main._line_cargo_preview(spam_line_id).contains("dispatch overload"), "Line preview should warn about dispatch overload before more train spam.")
	_require(main._grade_coach_text(main.local["scenario"], 1.0, true).contains("extra trains"), "Grade coach should call out brute-force train spam.")
	var overfleet_summary: String = main._completion_quality_summary(main.local["scenario"], 1.0, true)
	_require(overfleet_summary.contains("Dispatch"), "Completion summary should expose dispatch overload pressure.")
	var created_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Dispatch overload"), "Local side panel should explain the live over-fleet speed penalty.")
	if created_side_text:
		main.side_text.free()
		main.side_text = null
	_require(_grade_rank(efficient_grade) > _grade_rank(overfleet_grade), "Brute-force over-fleeting should lower dispatch grade.")
	_require(efficient_reward > overfleet_reward, "Right-sized dispatch should pay better than brute-force train spam.")
	main.trains = []
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"]) * 2
	main.local["elapsed_time"] = main._reward_time_par(main.local["scenario"]) * 2.0
	main.local["deadlocks"] = 2
	main.local["unqualified_output"] = 40
	var overbuilt_grade: String = main._completion_quality_grade(main.local["scenario"], float(main.local["wait_target"]) * 2.0, false)
	var overbuilt_reward: int = main._completion_reward_money(main.local["scenario"], float(main.local["wait_target"]) * 2.0, false)
	_require(efficient_grade in ["gold", "silver"], "Efficient reliable clears should earn a high dispatch grade.")
	_require(overbuilt_grade in ["bronze", "rough"], "Overbuilt circular-style clears should earn a lower dispatch grade.")
	_require(efficient_reward > overbuilt_reward, "Efficient reliable clears should pay better than overbuilt unreliable clears.")

func _run_actual_efficiency_balance_smoke(main: Node) -> void:
	var base_money: int = int(main.campaign.get("money", 0))
	(main.campaign["completed"] as Array).erase("coal_valley")
	main.start_scenario("coal_valley")
	main.local["target"] = 30
	main.local["fleet_goal"] = 1
	main.local["wait_target"] = 40.0
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	main._place_signal_pair(Vector2i(5, 5), "block")
	main._place_signal_pair(Vector2i(11, 5), "block")
	main._buy_train()
	for i in range(900):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Compact balance route should clear through actual train movement.")
	var compact_grade: String = String(main.result_data.get("quality_grade", ""))
	var compact_reward: int = int(main.campaign.get("money", 0)) - base_money
	var compact_service: float = float(main.local.get("service_mileage", 0.0))
	main.campaign["money"] = base_money
	(main.campaign["completed"] as Array).erase("coal_valley")
	main.start_scenario("coal_valley")
	main.local["target"] = 30
	main.local["fleet_goal"] = 1
	main.local["wait_target"] = 40.0
	_place_path(main, [Vector2i(1, 5), Vector2i(1, 1), Vector2i(16, 1), Vector2i(16, 5)])
	main._place_signal_pair(Vector2i(1, 3), "block")
	main._place_signal_pair(Vector2i(8, 1), "block")
	main._place_signal_pair(Vector2i(16, 3), "block")
	main._buy_train()
	for i in range(1200):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Long balance route should remain playable and clear through actual train movement.")
	var long_grade: String = String(main.result_data.get("quality_grade", ""))
	var long_reward: int = int(main.campaign.get("money", 0)) - base_money
	var long_service: float = float(main.local.get("service_mileage", 0.0))
	_require(long_service > compact_service * 1.5, "Long actual route should produce substantially more service mileage than the compact route.")
	_require(_grade_rank(compact_grade) > _grade_rank(long_grade), "Compact actual route should earn a better grade than the long exploitable route.")
	_require(compact_reward > long_reward, "Compact actual route should pay better than the long exploitable route.")

func _run_contract_exploit_playtest_smoke(main: Node) -> void:
	_reset_run_state(main)
	var base_money: int = int(main.campaign.get("money", 0))
	main.start_scenario("run_01")
	main.local["money"] = 9000
	main.local["target"] = 40
	main.local["fleet_goal"] = 1
	_build_ghost_solution(main)
	main._compute_blocks()
	var clean_source_id := String(main.local["scenario"]["route"][0])
	main._buy_train_for_source(clean_source_id)
	for i in range(1600):
		if main.screen != main.Screen.LOCAL:
			break
		_step_fast(main, 0.1)
	_require(main.screen == main.Screen.RESULTS, "Clean generated branch service should clear through actual train movement.")
	var clean_grade: String = String(main.result_data.get("quality_grade", ""))
	var clean_reward: int = int(main.campaign.get("money", 0)) - base_money
	var clean_progress: int = int(main.local.get("productive_progress", 0))
	var clean_unqualified: int = int(main.local.get("unqualified_output", 0))
	_require(clean_progress >= int(main.local.get("target", 0)), "Clean branch service should count contract output.")
	_require(clean_unqualified == 0, "Clean branch service should not rely on outside-contract cargo.")
	_reset_run_state(main)
	main.campaign["money"] = base_money
	main.start_scenario("run_01")
	main.local["money"] = 9000
	main.local["target"] = 40
	main.local["fleet_goal"] = 1
	var route: Array = main.local["scenario"].get("route", [])
	var source_id := String(route[0])
	var sink_id := String(route[2])
	var source_pos: Vector2i = main.station_by_id[source_id]["pos"]
	var sink_pos: Vector2i = main.station_by_id[sink_id]["pos"]
	var shortcut_grid: Vector2i = main.local["scenario"].get("grid", Vector2i(18, 11))
	var bypass_y: int = int(clamp(source_pos.y - 1, 1, shortcut_grid.y - 2))
	_place_path(main, [source_pos, Vector2i(source_pos.x, bypass_y), Vector2i(sink_pos.x, bypass_y), sink_pos])
	main._place_signal_pair(Vector2i(5, bypass_y), "block")
	main._place_signal_pair(Vector2i(11, bypass_y), "block")
	var shortcut_line_id: String = main._create_or_get_line_for_source(source_id)
	main.lines[shortcut_line_id]["route"] = [source_id, sink_id, source_id]
	main.lines[shortcut_line_id]["name"] = main._line_name_for_route(main.lines[shortcut_line_id]["route"], int(main.lines[shortcut_line_id].get("ordinal", 1)))
	main._buy_train_for_line(shortcut_line_id)
	for i in range(1200):
		_step_fast(main, 0.1)
	_require(main.screen == main.Screen.LOCAL, "Shortcut circular service should not complete a branch contract just by moving raw cargo.")
	_require(int(main.local.get("delivered", 0)) > 0, "Shortcut circular service should still move raw cargo, proving the exploit attempt is being tested.")
	_require(int(main.local.get("productive_progress", 0)) == 0, "Shortcut circular service should produce no contract output without the required branch stop.")
	_require(int(main.local.get("unqualified_output", 0)) > 0, "Shortcut circular service should be tracked as outside-contract cargo.")
	var shortcut_grade: String = main._completion_quality_grade(main.local["scenario"], main._average_wait(), false)
	_require(_grade_rank(clean_grade) > _grade_rank(shortcut_grade), "Clean branch service should grade above shortcut circular cargo movement.")
	_require(clean_reward > 0, "Clean branch service should pay campaign money, while the incomplete shortcut exploit pays nothing.")

func _run_debug_money_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	var before: int = int(main.local["money"])
	main._debug_replenish_money()
	_require(int(main.local["money"]) == before + 5000, "Debug money button should add $5000 to the local budget.")

func _run_local_material_accounting_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	main.local["money"] = 1000
	main.local["materials"] = 0
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var before_chain_money: int = int(main.local["money"])
	var before_chain_used: int = int(main.local["infra_cost"])
	main._place_signal(Vector2i(5, 5), "chain")
	_require(main.signals.has(Vector2i(5, 5)), "Chain signals should place even when local materials are zero.")
	_require(int(main.local["money"]) == before_chain_money, "Local map construction should not spend money.")
	_require(int(main.local["infra_cost"]) == before_chain_used + 120, "Chain signal should add to material usage.")
	var before_platform_money: int = int(main.local["money"])
	var before_platform_used: int = int(main.local["infra_cost"])
	var platform_before: int = int(main.station_by_id["interchange"].get("platforms", 1))
	main._add_platform()
	_require(int(main.station_by_id["interchange"].get("platforms", 1)) == platform_before + 1, "Platforms should build with money only when materials are zero.")
	_require(int(main.local["money"]) == before_platform_money, "Platform should not spend local money.")
	_require(int(main.local["infra_cost"]) == before_platform_used + 200, "Platform should add to material usage.")
	_require(main._platform_padding_score() == 0, "One useful platform should stay inside the capacity allowance.")
	var efficient_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	for i in range(3):
		main._add_platform_at("interchange")
	_require(main._platform_padding_score() > 0, "Excess station platforms should count as platform padding pressure.")
	var padded_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(efficient_grade) > _grade_rank(padded_grade), "Platform padding should lower mastery grade compared with useful capacity.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Platform +"), "Completion summary should expose platform padding pressure.")
	var created_padding_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_padding_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Platform padding"), "Local side panel should warn about platform padding while building.")
	if created_padding_side_text:
		main.side_text.free()
		main.side_text = null

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
	var visible_lines: Array[String] = main._visible_service_line_ids()
	_require(visible_lines.has(first_line) and visible_lines.has(second_line), "Configured lines should be visible in the colored map overlay.")
	_require(main._line_color(first_line) != main._line_color(second_line), "Configured lines should receive distinct map colors.")
	main._refresh_local_side_text()
	_require(main.line_picker_scroll != null and main.line_picker_scroll.visible, "Configured lines should appear as compact editable chips in the existing bottom tray.")
	_require(main.line_picker_row != null and main.line_picker_row.get_child_count() >= 2, "Line picker should expose more than the last-created line.")
	_require(_control_inside_viewport(main.line_picker_scroll, main.size), "Line picker chips should stay inside the viewport instead of covering the map.")
	main._edit_line_from_picker(first_line)
	_require(main.editing_line_stops and String(main.selected_line_id) == first_line, "Line picker should edit an older existing line.")
	main._edit_line_from_picker(second_line)
	_require(main.editing_line_stops and String(main.selected_line_id) == second_line, "Line picker should switch editing to another existing line.")
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

func _run_station_resource_badge_layout_smoke(main: Node) -> void:
	main.size = Vector2(640, 480)
	main.start_scenario("coal_valley")
	main.station_by_id = {
		"close_coal_out": {"id": "close_coal_out", "name": "A", "pos": Vector2i(6, 3), "role": "source", "produces": "coal", "accepts": [], "stored": 90, "platforms": 1},
		"close_coal_need": {"id": "close_coal_need", "name": "B", "pos": Vector2i(7, 3), "role": "sink", "produces": "", "accepts": ["coal"], "platforms": 1},
		"close_timber_out": {"id": "close_timber_out", "name": "C", "pos": Vector2i(6, 4), "role": "source", "produces": "timber", "accepts": [], "stored": 90, "platforms": 1},
		"close_timber_need": {"id": "close_timber_need", "name": "D", "pos": Vector2i(7, 4), "role": "sink", "produces": "", "accepts": ["timber"], "platforms": 1}
	}
	var layout: Dictionary = main._station_resource_badge_layout()
	var rects: Array = []
	for station_layout in layout.values():
		for raw_rect in (station_layout as Dictionary).values():
			rects.append(raw_rect)
	_require(rects.size() == 4, "Close station cluster should place every demand/output badge.")
	var bounds: Rect2 = main._station_label_view_bounds()
	for raw_rect in rects:
		var rect: Rect2 = raw_rect
		_require(rect.position.x >= bounds.position.x - 0.5 and rect.position.y >= bounds.position.y - 0.5, "Station resource badges should stay inside the viewport.")
		_require(rect.position.x + rect.size.x <= bounds.position.x + bounds.size.x + 0.5 and rect.position.y + rect.size.y <= bounds.position.y + bounds.size.y + 0.5, "Station resource badges should stay above compact UI trays.")
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			_require(main._rect_overlap_area(rects[i], rects[j]) <= 0.1, "Close station demand/output badges should not overlap each other.")

func _run_generated_pool_smoke(main: Node) -> void:
	_reset_run_state(main)
	var run_count := 0
	var terrain_count := 0
	var hard_count := 0
	var branch_contract_count := 0
	var clause_types: Dictionary = {}
	var express_count := 0
	var lean_count := 0
	var clean_return_count := 0
	var compact_network_count := 0
	var compact_network_id := ""
	var bonus_count := 0
	var template_ids: Dictionary = {}
	var passing_signal_clause_count := 0
	var junction_chain_clause_count := 0
	var efficiency_lean_clause_count := 0
	var processor_proof_clause_count := 0
	for s in main.scenarios:
		if String(s.get("id", "")).begins_with(main.RUN_SCENARIO_PREFIX):
			run_count += 1
			var puzzle: Dictionary = s.get("contract_puzzle", {})
			_require(not puzzle.is_empty(), "%s should expose a normalized Rail Sudoku puzzle schema." % s.get("name", s.get("id", "")))
			template_ids[String(puzzle.get("template_id", ""))] = true
			if String(puzzle.get("template_id", "")) == "passing_siding":
				if (puzzle.get("service_clauses", []) as Array).any(func(clause): return String(clause).contains("Signal proof")):
					passing_signal_clause_count += 1
			if String(puzzle.get("template_id", "")) == "junction_sort":
				if (puzzle.get("service_clauses", []) as Array).any(func(clause): return String(clause).contains("Junction proof")):
					junction_chain_clause_count += 1
			if String(puzzle.get("template_id", "")) == "efficiency_run":
				if (puzzle.get("service_clauses", []) as Array).any(func(clause): return String(clause).contains("Lean proof")):
					efficiency_lean_clause_count += 1
			if String(puzzle.get("template_id", "")) == "processor_chain":
				if (puzzle.get("service_clauses", []) as Array).any(func(clause): return String(clause).contains("Processor proof")):
					processor_proof_clause_count += 1
			_require(String(s.get("template_id", "")) == String(puzzle.get("template_id", "")), "%s top-level template id should match its puzzle schema." % s.get("name", s.get("id", "")))
			_require((puzzle.get("required_deliveries", []) as Array).size() > 0, "%s should list required deliveries." % s.get("name", s.get("id", "")))
			_require((puzzle.get("route_clauses", []) as Array).size() > 0 and (puzzle.get("service_clauses", []) as Array).size() > 0, "%s should list route and service clauses." % s.get("name", s.get("id", "")))
			_require((puzzle.get("grade_thresholds", {}) as Dictionary).has("perfect"), "%s should define Perfect as a grade threshold." % s.get("name", s.get("id", "")))
			if int(s.get("bonus_money", 0)) > 0:
				bonus_count += 1
			var clause: Dictionary = s.get("contract_clause", {})
			var clause_type := String(clause.get("type", ""))
			clause_types[clause_type] = true
			if clause_type == "express_flow":
				express_count += 1
				_require(float(s.get("flow_gap_multiplier", 1.0)) < 1.0, "%s express clause should tighten flow target." % s.get("name", s.get("id", "")))
			elif clause_type == "lean_build":
				lean_count += 1
				_require(float(s.get("material_par_multiplier", 1.0)) < 1.0, "%s lean clause should tighten material par." % s.get("name", s.get("id", "")))
			elif clause_type == "clean_returns":
				clean_return_count += 1
				_require(float(s.get("empty_share_limit", 1.0)) < 0.42, "%s clean return clause should tighten empty-running grade limit." % s.get("name", s.get("id", "")))
			elif clause_type == "compact_network":
				compact_network_count += 1
				if compact_network_id == "":
					compact_network_id = String(s.get("id", ""))
				_require(s.has("sprawl_allowance_bonus"), "%s compact-network clause should define its sprawl allowance modifier." % s.get("name", s.get("id", "")))
			if not (s.get("terrain", []) as Array).is_empty():
				terrain_count += 1
			if int(s.get("difficulty", 1)) >= 3:
				hard_count += 1
			if _route_has_branching_obligation(s):
				branch_contract_count += 1
			_require(_ghost_avoids_blocking_terrain(s), "%s solution path should avoid mountains, rocks, and ocean." % s.get("name", s.get("id", "")))
			_require(_ghost_visits_required_stations(s), "%s solution path should connect its required stations." % s.get("name", s.get("id", "")))
			_require(_route_has_branching_obligation(s), "%s should require an off-axis route stop so a simple A-B double track is not sufficient." % s.get("name", s.get("id", "")))
			_require((s.get("requirements", []) as Array).any(func(req): return String(req).contains("Contract clause")), "%s requirements should explain its contract clause." % s.get("name", s.get("id", "")))
			_require((s.get("requirements", []) as Array).any(func(req): return String(req).contains("bonus challenge")), "%s requirements should mention its optional bonus challenge." % s.get("name", s.get("id", "")))
			_require(main._contract_bonus_challenge_text(s).contains("Bonus Challenge") and main._contract_bonus_challenge_text(s).contains("+$"), "%s should describe a rewarding optional bonus challenge." % s.get("name", s.get("id", "")))
	_require(run_count == main.RUN_POOL_SIZE, "Roguelike pool should generate exactly 30 map contracts.")
	_require(bonus_count == run_count, "Every generated contract should include an optional bonus reward.")
	_require(terrain_count >= 24, "Generated contracts should usually contain terrain constraints.")
	_require(hard_count >= 10, "Generated pool should include a late-run hard difficulty band.")
	_require(branch_contract_count == run_count, "Every generated contract should have a branching or loop obligation beyond A-to-B.")
	_require(clause_types.size() == 4 and express_count > 0 and lean_count > 0 and clean_return_count > 0 and compact_network_count > 0, "Generated contracts should rotate express, lean, clean-return, and compact-network clauses.")
	_require(template_ids.size() >= 5 and template_ids.has("branch_delivery") and template_ids.has("processor_chain") and template_ids.has("passing_siding") and template_ids.has("junction_sort") and template_ids.has("efficiency_run"), "Generated pool should cover all v1 Rail Sudoku templates.")
	_require(passing_signal_clause_count > 0, "Passing Siding puzzles should include a signal proof service clause.")
	_require(junction_chain_clause_count > 0, "Junction Sort puzzles should include a chain-signal proof service clause.")
	_require(efficiency_lean_clause_count > 0, "Efficiency Run puzzles should include a lean proof service clause.")
	_require(processor_proof_clause_count > 0, "Processor Chain puzzles should include a processor handoff proof service clause.")
	_require((main.campaign["run_available"] as Array).size() == main.RUN_CHOICES, "A fresh run should offer three contract choices.")
	main.screen = main.Screen.REGIONAL
	main.rebuild_ui()
	var regional_preview: String = main.side_text.text
	_require(regional_preview.contains("Rail Sudoku") and regional_preview.contains("Tile proofs:"), "Regional map should frame the core mode as a Rail Sudoku roguelike.")
	_require(regional_preview.contains("Adjacent Contracts") and regional_preview.contains("Stops:") and regional_preview.contains("Fleet") and regional_preview.contains("Target"), "Regional adjacent contract list should preview route and operating constraints before selection.")
	_require(regional_preview.contains("[ ]"), "Regional adjacent contract list should use checklist-style objective visibility.")
	_require(regional_preview.contains("Bonus Challenge"), "Regional adjacent contract list should preview optional bonus challenges.")
	_require(regional_preview.contains("Express Flow") or regional_preview.contains("Lean Build") or regional_preview.contains("Clean Returns") or regional_preview.contains("Compact Network"), "Regional adjacent contract list should preview the generated contract clause.")
	var first_id: String = String((main.campaign["run_available"] as Array)[0])
	main.start_scenario(first_id)
	_require(String(main.local["scenario"].get("template_id", "")) != "", "Selected regional puzzle should carry its template id into local play.")
	_require(typeof((main.local["scenario"].get("contract_puzzle", {}) as Dictionary).get("terrain_tags", [])) == TYPE_ARRAY, "Selected regional puzzle should carry terrain tags in its schema.")
	_require(main._local_contract_clause_text().contains("Flow") and (main._local_contract_clause_text().contains("Express Flow") or main._local_contract_clause_text().contains("Lean Build") or main._local_contract_clause_text().contains("Clean Returns") or main._local_contract_clause_text().contains("Compact Network")), "Generated local contract chip should expose clause and grade targets.")
	_require(main._local_contract_clause_text().contains("Bonus Challenge"), "Generated local contract chip should expose the optional bonus challenge.")
	_require(main._local_contract_clause_text().contains("Perfect"), "Generated local contract chip should expose Perfect as the bonus-backed top grade.")
	_require(main.top_status.text.contains("Bonus +$") and (main.top_status.text.contains("Express Flow") or main.top_status.text.contains("Lean Build") or main.top_status.text.contains("Clean Returns") or main.top_status.text.contains("Compact Network")), "Local HUD should show a compact contract summary without opening a map overlay.")
	main.start_scenario("run_01")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["fleet_goal"] = 1
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	_require(main._contract_bonus_challenge_met(main.local["scenario"], 1.0, true), "Clean generated contract play should be able to earn the optional bonus.")
	_require(main._completion_quality_grade(main.local["scenario"], 1.0, true) == "perfect", "Clean generated contract play that meets the bonus should earn Perfect.")
	_require(main._contract_bonus_reward_money(main.local["scenario"], 1.0, true) == int(main.local["scenario"].get("bonus_money", 0)), "Met optional bonus should add its configured reward.")
	_require(main._contract_bonus_coach_text(main.local["scenario"], 1.0, true).contains("Bonus ready"), "Met optional bonus should give positive bonus coach feedback.")
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"]) + 1
	_require(not main._contract_bonus_challenge_met(main.local["scenario"], 1.0, true), "Missing the clause-specific target should miss the optional bonus without blocking completion.")
	_require(main._contract_bonus_coach_text(main.local["scenario"], 1.0, true).contains("material"), "Lean-build bonus miss should point at material usage.")
	_require(main._result_replay_label("silver", true, false) == "Replay for Bonus", "Missed bonus should make the replay action invite a bonus attempt.")
	_require(main._result_replay_label("silver", false, false) == "Replay for Gold", "Non-gold clears without a bonus miss should invite a gold attempt.")
	_require(main._result_replay_label("gold", true, true) == "Replay Mastery", "Gold clears with bonus met should invite mastery replay.")
	_require(main._result_replay_label("perfect", true, true) == "Replay Perfect", "Perfect clears should have a distinct replay label.")
	var result_line_id: String = main._create_or_get_line_for_source("source")
	main.trains = [{"id": "ResultProbe", "line_id": result_line_id}]
	main.local["unqualified_output"] = 20
	main._complete_scenario()
	_require(String(main.result_data.get("replay_label", "")) == "Replay for Bonus", "Result screen should label replay with the most useful next challenge.")
	_require(String(main.result_data.get("text", "")).contains("Next Try: Chase the bonus"), "Result screen should include a concise next-try improvement target.")
	_require(String(main.result_data.get("text", "")).contains("Mastery Record: New best"), "Result screen should record the first mastery benchmark.")
	var first_record: Dictionary = (main.campaign["mastery_records"] as Dictionary).get("run_01", {})
	_require(not bool(first_record.get("bonus_met", true)), "First benchmark should remember that the bonus was missed.")
	var money_after_first_clear: int = int(main.campaign.get("money", 0))
	main.start_scenario("run_01")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["fleet_goal"] = 1
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var replay_line_id: String = main._create_or_get_line_for_source("source")
	main.trains = [{"id": "ReplayProbe", "line_id": replay_line_id, "productive_output": int(main.local["target"])}]
	main._complete_scenario()
	var replay_record: Dictionary = (main.campaign["mastery_records"] as Dictionary).get("run_01", {})
	_require(bool(replay_record.get("bonus_met", false)), "Replay should update mastery record when the optional bonus is earned.")
	_require(String(main.result_data.get("text", "")).contains("Mastery Record: New best"), "Replay improvement should be celebrated as a new mastery record.")
	_require(int(main.campaign.get("money", 0)) == money_after_first_clear, "Replay mastery records should not pay regional rewards twice.")
	main.screen = main.Screen.REGIONAL
	main.rebuild_ui()
	_require(main.side_text.text.contains("Mastery records:") and main.side_text.text.contains("bonus clears"), "Regional side panel should summarize mastery records.")
	var mastery_preview: String = main._regional_contract_preview_text(main._get_scenario("run_01"))
	_require(mastery_preview.contains("Best:") and mastery_preview.contains("bonus"), "Regional contract preview should show the prior best and bonus status for replayable contracts.")
	var visible_mastery_id: String = String((main.campaign["run_available"] as Array)[0])
	var visible_records: Dictionary = main.campaign["mastery_records"]
	visible_records[visible_mastery_id] = replay_record.duplicate(true)
	main.campaign["mastery_records"] = visible_records
	main.rebuild_ui()
	_require(main.side_text.text.contains("Best:") and main.side_text.text.contains("bonus"), "Regional adjacent contract list should show per-contract mastery badges.")
	var tutorial_records: Dictionary = main.campaign["mastery_records"]
	tutorial_records["coal_valley"] = {
		"grade": "gold",
		"grade_rank": 4,
		"bonus_met": false,
		"reward_money": 321,
		"avg_wait": 2.5
	}
	main.campaign["mastery_records"] = tutorial_records
	main.rebuild_ui()
	_require(main.side_text.text.contains("Coal Valley") and main.side_text.text.contains("Best: Gold"), "Regional tutorial list should show mastery badges for completed tutorial contracts.")
	main.start_scenario("run_02")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["processed"] = int(main.local["target"])
	main.local["max_output_gap"] = main._flow_gap_target() * 1.6
	_require(main._contract_bonus_coach_text(main.local["scenario"], 1.0, true).contains("flow gap"), "Express-flow bonus miss should point at delivery gaps.")
	main.start_scenario("run_03")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["service_mileage"] = 120.0
	main.local["empty_mileage"] = 90.0
	_require(main._contract_bonus_coach_text(main.local["scenario"], 1.0, true).contains("empty running"), "Clean-return bonus miss should point at empty running.")
	_require(compact_network_id != "", "Generated pool should expose a Compact Network contract for bonus testing.")
	main.start_scenario(compact_network_id)
	var compact_route: Array = main.local["scenario"].get("route", [])
	var compact_line_id: String = main._create_or_get_line_for_source(String(compact_route[0]))
	main.lines[compact_line_id]["route"] = compact_route.duplicate()
	main.trains = [{"id": "CompactBonusProbe", "line_id": compact_line_id}]
	main.local["money"] = 99999
	_build_ghost_solution(main)
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["max_output_gap"] = 1.0
	_require(main._contract_bonus_challenge_met(main.local["scenario"], 1.0, true), "Compact Network bonus should be met by proof-path rail inside the sprawl budget.")
	var compact_grid: Vector2i = main.local["scenario"].get("grid", Vector2i(18, 11))
	_place_path(main, [
		Vector2i(1, 1),
		Vector2i(1, compact_grid.y - 2),
		Vector2i(compact_grid.x - 2, compact_grid.y - 2),
		Vector2i(compact_grid.x - 2, 1),
		Vector2i(1, 1)
	])
	_require(not main._contract_bonus_challenge_met(main.local["scenario"], 1.0, true), "Compact Network bonus should be missed by map-wide circular rail sprawl.")
	_require(main._contract_bonus_coach_text(main.local["scenario"], 1.0, true).contains("rail sprawl"), "Compact Network bonus miss should point at rail sprawl.")
	main.start_scenario("run_02")
	_require(String(main.local["scenario"].get("template_id", "")) == "junction_sort", "run_02 should exercise the Junction Sort template.")
	var junction_route: Array = main.local["scenario"].get("route", [])
	var junction_line_id: String = main._create_or_get_line_for_source(String(junction_route[0]))
	main.lines[junction_line_id]["route"] = junction_route.duplicate()
	main.trains = []
	for i in range(main._fleet_goal()):
		main.trains.append({"id": "JunctionProbe%d" % i, "line_id": junction_line_id})
	main.local["productive_progress"] = int(main.local["target"])
	main.local["processed"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	main.local["elapsed_time"] = 1.0
	main.local["max_output_gap"] = 1.0
	var bare_junction_preview: String = main._line_cargo_preview(junction_line_id)
	_require(bare_junction_preview.contains("Chain 0/"), "Junction Sort line preview should show missing chain proof pressure.")
	_require(main._local_contract_clause_text().contains("Junction proof") and main._local_contract_clause_text().contains("0/"), "Local contract chip should show live missing junction proof progress.")
	var bare_junction_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_build_ghost_solution(main)
	var chain_target: int = main._junction_chain_target(main.local["scenario"])
	var junction_ghost: Array = main.local["scenario"].get("ghost", [])
	var junction_index := 1
	while main._chain_signal_gate_count() < chain_target and junction_index < junction_ghost.size() - 1:
		var chain_pos: Vector2i = junction_ghost[junction_index]
		main._place_signal_pair(chain_pos, "chain")
		junction_index += max(1, int(ceil(float(junction_ghost.size()) / float(max(1, chain_target)))))
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var chained_junction_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._chain_signal_gate_count() >= chain_target, "Junction Sort proof should count paired chain-signal gates.")
	_require(_grade_rank(chained_junction_grade) > _grade_rank(bare_junction_grade), "Junction Sort proof should make chain-protected service grade above a bare circular route.")
	_require(main._line_cargo_preview(junction_line_id).contains("chain-signal gates ready"), "Junction Sort preview should affirm the chain proof once enough gates exist.")
	main.start_scenario("run_03")
	_require(String(main.local["scenario"].get("template_id", "")) == "passing_siding", "run_03 should exercise the Passing Siding template.")
	var siding_route: Array = main.local["scenario"].get("route", [])
	var siding_line_id: String = main._create_or_get_line_for_source(String(siding_route[0]))
	main.lines[siding_line_id]["route"] = siding_route.duplicate()
	main.trains = []
	for i in range(main._fleet_goal()):
		main.trains.append({"id": "SidingProbe%d" % i, "line_id": siding_line_id})
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	main.local["elapsed_time"] = 1.0
	main.local["max_output_gap"] = 1.0
	var bare_siding_preview: String = main._line_cargo_preview(siding_line_id)
	_require(bare_siding_preview.contains("Signals 0/"), "Passing Siding line preview should show missing signal proof pressure.")
	_require(main._local_contract_clause_text().contains("Signal proof") and main._local_contract_clause_text().contains("0/"), "Local contract chip should show live missing signal proof progress.")
	var bare_siding_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_build_ghost_solution(main)
	var signal_target: int = main._passing_capacity_target(main.local["scenario"])
	var ghost: Array = main.local["scenario"].get("ghost", [])
	var ghost_index := 1
	while main._signal_gate_count() < signal_target and ghost_index < ghost.size() - 1:
		var signal_pos: Vector2i = ghost[ghost_index]
		main._place_signal_pair(signal_pos, "block")
		ghost_index += max(1, int(ceil(float(ghost.size()) / float(max(1, signal_target)))))
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var signaled_siding_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._signal_gate_count() >= signal_target, "Passing Siding signal proof should count paired signal gates.")
	_require(_grade_rank(signaled_siding_grade) > _grade_rank(bare_siding_grade), "Passing Siding proof should make signaled service grade above a bare circular route.")
	_require(main._line_cargo_preview(siding_line_id).contains("signal gates ready"), "Passing Siding preview should affirm the signal proof once enough gates exist.")
	main.start_scenario("run_04")
	_require(String(main.local["scenario"].get("template_id", "")) == "efficiency_run", "run_04 should exercise the Efficiency Run template.")
	var efficiency_route: Array = main.local["scenario"].get("route", [])
	var efficiency_line_id: String = main._create_or_get_line_for_source(String(efficiency_route[0]))
	main.lines[efficiency_line_id]["route"] = efficiency_route.duplicate()
	main.trains = []
	for i in range(main._fleet_goal()):
		main.trains.append({"id": "LeanProbe%d" % i, "line_id": efficiency_line_id})
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	main.local["elapsed_time"] = 1.0
	main.local["max_output_gap"] = 1.0
	var clean_efficiency_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._efficiency_proof_missing(main.local["scenario"]) == 0, "Clean Efficiency Run should satisfy the lean proof.")
	_require(main._line_cargo_preview(efficiency_line_id).contains("Lean proof: clean route"), "Efficiency Run preview should affirm the lean proof for compact service.")
	main.lines[efficiency_line_id]["route"] = efficiency_route.duplicate()
	main.lines[efficiency_line_id]["route"].append(String(efficiency_route[1]))
	main.trains.append({"id": "LeanSpamA", "line_id": efficiency_line_id})
	main.trains.append({"id": "LeanSpamB", "line_id": efficiency_line_id})
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"]) + 20
	var bloated_efficiency_preview: String = main._line_cargo_preview(efficiency_line_id)
	var bloated_efficiency_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._efficiency_proof_missing(main.local["scenario"]) == 3, "Bloated Efficiency Run should miss route, fleet, and material lean proof checks.")
	_require(bloated_efficiency_preview.contains("Lean proof:") and bloated_efficiency_preview.contains("trim loops"), "Efficiency Run preview should explain how to recover the lean proof.")
	_require(_grade_rank(clean_efficiency_grade) > _grade_rank(bloated_efficiency_grade), "Efficiency Run lean proof should make compact service grade above circular overbuild.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Lean 0/3"), "Efficiency Run summary should expose lean proof progress.")
	main.start_scenario("run_06")
	_require(String(main.local["scenario"].get("template_id", "")) == "processor_chain", "run_06 should exercise the Processor Chain template.")
	var processor_route: Array = main.local["scenario"].get("route", [])
	var processor_line_id: String = main._create_or_get_line_for_source(String(processor_route[0]))
	main.lines[processor_line_id]["route"] = processor_route.duplicate()
	main.trains = []
	for i in range(main._fleet_goal()):
		main.trains.append({"id": "ProcessorProbe%d" % i, "line_id": processor_line_id})
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	main.local["elapsed_time"] = 1.0
	main.local["max_output_gap"] = 1.0
	var bare_processor_preview: String = main._line_cargo_preview(processor_line_id)
	_require(main._processor_proof_missing(main.local["scenario"]) == 2, "Progress-only Processor Chain should miss both processor handoff proof checks.")
	_require(main._local_contract_clause_text().contains("Trip proof") and main._local_contract_clause_text().contains("split shuttles count only through those handoffs"), "Processor Chain contract chip should explain the valid handoff proof path.")
	_require(bare_processor_preview.contains("Processor proof: 0/2") and bare_processor_preview.contains("export processor-made steel"), "Processor Chain preview should explain missing processor handoff proof.")
	_require(main._local_contract_clause_text().contains("Processor proof") and main._local_contract_clause_text().contains("0/2"), "Local contract chip should show live missing processor proof progress.")
	var bare_processor_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	main.local["processor_feed"] = 80
	_require(main._processor_proof_missing(main.local["scenario"]) == 1, "Processor Chain should count coal feed as the first proof handoff.")
	main.local["processor_export"] = 40
	var proven_processor_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._processor_proof_missing(main.local["scenario"]) == 0, "Processor Chain should satisfy proof once processor-made steel is exported.")
	_require(_grade_rank(proven_processor_grade) > _grade_rank(bare_processor_grade), "Processor Chain proof should grade above progress-only steel output.")
	_require(main._line_cargo_preview(processor_line_id).contains("2/2 handoffs ready"), "Processor Chain preview should affirm the proof once both handoffs are observed.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Processor 2/2"), "Processor Chain summary should expose processor proof progress.")
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
		var used_before: int = int(main.local["infra_cost"])
		main._place_track(river_tile)
		_require(main.tracks.has(river_tile), "River tiles should allow bridge track.")
		_require(int(main.local["money"]) == money_before, "River bridge track should not spend local money.")
		_require(int(main.local["infra_cost"]) == used_before + 85, "River bridge track should add to material usage.")

func _run_circular_exploit_gauntlet_smoke(main: Node) -> void:
	_reset_run_state(main)
	var cases_passed := 0

	main.start_scenario("coal_valley")
	main.local["target"] = 60
	main.local["fleet_goal"] = 1
	_place_path(main, [Vector2i(1, 5), Vector2i(16, 5)])
	var compact_line_id: String = main._create_or_get_line_for_source("coal_mine")
	main.trains = [{"id": "GauntletCompact", "line_id": compact_line_id}]
	_set_clean_grade_state(main)
	var compact_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_place_path(main, [Vector2i(1, 5), Vector2i(1, 8), Vector2i(16, 8), Vector2i(16, 5)])
	var sprawled_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(compact_grade) > _grade_rank(sprawled_grade), "Exploit gauntlet: compact rail should beat map-wide circular rail.")
	cases_passed += 1

	main.start_scenario("run_01")
	var branch_route: Array = main.local["scenario"].get("route", [])
	var branch_line_id: String = main._create_or_get_line_for_source(String(branch_route[0]))
	main.lines[branch_line_id]["route"] = [String(branch_route[0]), String(branch_route[2]), String(branch_route[0])]
	_require(not main._line_contract_ready(branch_line_id), "Exploit gauntlet: source-sink shortcut should stay sandbox-only on branch contracts.")
	cases_passed += 1

	main.start_scenario("run_02")
	var junction_route: Array = main.local["scenario"].get("route", [])
	var junction_line_id: String = main._create_or_get_line_for_source(String(junction_route[0]))
	main.lines[junction_line_id]["route"] = junction_route.duplicate()
	main.trains = _gauntlet_train_list(main._fleet_goal(), junction_line_id, "GauntletJunction")
	_set_clean_grade_state(main)
	var bare_junction_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_build_ghost_solution(main)
	var chain_target: int = main._junction_chain_target(main.local["scenario"])
	var junction_ghost: Array = main.local["scenario"].get("ghost", [])
	var junction_index := 1
	while main._chain_signal_gate_count() < chain_target and junction_index < junction_ghost.size() - 1:
		main._place_signal_pair(junction_ghost[junction_index], "chain")
		junction_index += max(1, int(ceil(float(junction_ghost.size()) / float(max(1, chain_target)))))
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var proven_junction_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(proven_junction_grade) > _grade_rank(bare_junction_grade), "Exploit gauntlet: Junction Sort needs chain proof above a bare circular route.")
	cases_passed += 1

	main.start_scenario("run_03")
	var siding_route: Array = main.local["scenario"].get("route", [])
	var siding_line_id: String = main._create_or_get_line_for_source(String(siding_route[0]))
	main.lines[siding_line_id]["route"] = siding_route.duplicate()
	main.trains = _gauntlet_train_list(main._fleet_goal(), siding_line_id, "GauntletSiding")
	_set_clean_grade_state(main)
	var bare_siding_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_build_ghost_solution(main)
	var signal_target: int = main._passing_capacity_target(main.local["scenario"])
	var siding_ghost: Array = main.local["scenario"].get("ghost", [])
	var siding_index := 1
	while main._signal_gate_count() < signal_target and siding_index < siding_ghost.size() - 1:
		main._place_signal_pair(siding_ghost[siding_index], "block")
		siding_index += max(1, int(ceil(float(siding_ghost.size()) / float(max(1, signal_target)))))
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	var proven_siding_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(proven_siding_grade) > _grade_rank(bare_siding_grade), "Exploit gauntlet: Passing Siding needs signal proof above a bare circular route.")
	cases_passed += 1

	main.start_scenario("run_04")
	var efficiency_route: Array = main.local["scenario"].get("route", [])
	var efficiency_line_id: String = main._create_or_get_line_for_source(String(efficiency_route[0]))
	main.lines[efficiency_line_id]["route"] = efficiency_route.duplicate()
	main.trains = _gauntlet_train_list(main._fleet_goal(), efficiency_line_id, "GauntletLean")
	_set_clean_grade_state(main)
	var lean_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	main.lines[efficiency_line_id]["route"] = efficiency_route.duplicate()
	main.lines[efficiency_line_id]["route"].append(String(efficiency_route[1]))
	main.trains.append({"id": "GauntletLeanSpamA", "line_id": efficiency_line_id})
	main.trains.append({"id": "GauntletLeanSpamB", "line_id": efficiency_line_id})
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"]) + 20
	var overbuilt_preview: String = main._line_cargo_preview(efficiency_line_id)
	_require(overbuilt_preview.contains("Future inspection risk"), "Exploit gauntlet: overbuilt generated routes should preview future inspection risk before completion.")
	var overbuilt_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(lean_grade) > _grade_rank(overbuilt_grade), "Exploit gauntlet: Efficiency Run should beat overbuilt circular service.")
	cases_passed += 1

	main.start_scenario("run_06")
	var processor_route: Array = main.local["scenario"].get("route", [])
	var processor_line_id: String = main._create_or_get_line_for_source(String(processor_route[0]))
	main.lines[processor_line_id]["route"] = processor_route.duplicate()
	main.trains = _gauntlet_train_list(main._fleet_goal(), processor_line_id, "GauntletProcessor")
	_set_clean_grade_state(main)
	var bare_processor_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	main.local["processor_feed"] = 80
	main.local["processor_export"] = 40
	var proven_processor_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(_grade_rank(proven_processor_grade) > _grade_rank(bare_processor_grade), "Exploit gauntlet: Processor Chain needs real processor handoffs above progress-only output.")
	cases_passed += 1

	_require(cases_passed == 6, "Exploit gauntlet should cover shortcut, sprawl, junction, siding, efficiency, and processor circular exploit patterns.")

func _run_rail_sudoku_schema_smoke(main: Node) -> void:
	_reset_run_state(main)
	_require(int(main.campaign.get("daily_puzzle_seed", 0)) == main.DAILY_PUZZLE_SEED, "Daily puzzle seed should exist as a deterministic extra-mode hook.")
	var difficulty_counts := {1: 0, 2: 0, 3: 0}
	var multi_car_count := 0
	for s in main.scenarios:
		var id := String(s.get("id", ""))
		if not main._is_run_scenario_id(id):
			continue
		var difficulty := int(s.get("difficulty", 0))
		difficulty_counts[difficulty] = int(difficulty_counts.get(difficulty, 0)) + 1
		var budget: Dictionary = s.get("resource_budget", {})
		var variants: Array = s.get("solution_variants", [])
		var thresholds: Dictionary = s.get("star_thresholds", {})
		_require(String(s.get("resource_mode", "")) == "limited", "%s should be a limited-resource puzzle." % id)
		_require(int(budget.get("track", 0)) > 0 and int(budget.get("signals", 0)) > 0, "%s should define finite track and signal inventory." % id)
		_require(int(budget.get("block", 0)) > 0 and int(budget.get("chain", 0)) > 0, "%s should budget block and chain signal pieces separately." % id)
		_require(int(budget.get("trains", 0)) >= int(s.get("fleet_goal", 1)), "%s should allow at least the required fleet." % id)
		_require(variants.size() >= 2, "%s should expose at least two authored solution families." % id)
		for variant in variants:
			_require(int(variant.get("track_pieces", 9999)) <= int(budget.get("track", 0)), "%s variant %s should fit inside the track budget." % [id, String(variant.get("id", ""))])
			_require(_variant_connects_required_route(main, id, variant), "%s variant %s should connect every required route leg." % [id, String(variant.get("id", ""))])
		_require(int(thresholds.get("three_star_spare", 0)) > int(thresholds.get("two_star_spare", 0)), "%s should make 3 stars leaner than 2 stars." % id)
		if int(s.get("train_car_count", 1)) > 1:
			multi_car_count += 1
	_require(int(difficulty_counts.get(1, 0)) == 10 and int(difficulty_counts.get(2, 0)) == 10 and int(difficulty_counts.get(3, 0)) == 10, "Generated catalog should provide 10 puzzles at each of three difficulty levels.")
	_require(multi_car_count > 0, "At least some harder generated puzzles should use actual multi-car trains.")
	var first_id: String = String((main.campaign["run_available"] as Array)[0])
	var tile: Dictionary = main._regional_tile_for_scenario(first_id)
	_require(String(tile.get("template_id", "")) != "", "Regional contract tiles should expose the puzzle template before selection.")
	var sc: Dictionary = main._apply_run_pressure_to_scenario(main._get_scenario(first_id))
	var puzzle: Dictionary = sc.get("contract_puzzle", {})
	_require(String(puzzle.get("template_id", "")) == String(sc.get("template_id", "")), "Pressure-adjusted scenarios should preserve their template schema.")
	_require((puzzle.get("required_deliveries", []) as Array).size() >= 1, "Puzzle schema should list required deliveries.")
	_require((puzzle.get("route_clauses", []) as Array).any(func(clause): return String(clause).contains("simple supplier-to-receiver") or String(clause).contains("simple A-to-B")), "Puzzle schema should explicitly reject trivial A-to-B solutions.")
	_require(String(puzzle.get("bonus_clause", "")).contains("Bonus Challenge"), "Puzzle schema should include the optional bonus clause.")
	_require((puzzle.get("solution_variants", []) as Array).size() >= 2, "Puzzle schema should expose multiple solution families.")
	_require(int((puzzle.get("resource_budget", {}) as Dictionary).get("track", 0)) > 0, "Puzzle schema should expose the resource budget.")
	_require((puzzle.get("star_thresholds", {}) as Dictionary).has("three_star_spare"), "Puzzle schema should expose 1-3 star thresholds.")
	main.campaign["money"] = 1000
	main.campaign["permanent_upgrades"] = {"wider_offers": 1}
	main._generate_upgrade_shop()
	_require((main.campaign["upgrade_shop"] as Array).size() == 4, "Shop Network should add one more upgrade offer.")
	main.start_scenario(first_id)
	main.local["productive_progress"] = int(main.local["target"])
	main.local["delivered"] = int(main.local["target"])
	main.local["deadlocks"] = 0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])
	_require(main._puzzle_resource_summary_text(main.local["scenario"]).contains("Track"), "Local puzzle UI should summarize resource inventory.")
	main._complete_scenario()
	_require(String(main.result_data.get("text", "")).contains("Puzzle Rank"), "Resource puzzle results should show the 1-3 star rank.")
	var records: Dictionary = main.campaign.get("regional_tile_records", {})
	var active_key := String(tile.get("key", ""))
	_require(records.has(active_key), "Completed regional tile should store a grade/reward record.")
	var record: Dictionary = records.get(active_key, {})
	_require(String(record.get("template_id", "")) == String(tile.get("template_id", "")), "Tile completion record should remember the puzzle template.")
	_require(String(record.get("grade", "")) in ["perfect", "gold", "silver", "bronze", "rough"], "Tile completion record should remember the grade.")
	_require(int(record.get("reward", 0)) >= 0, "Tile completion record should remember the campaign reward.")
	_require(record.has("pressure_delta"), "Tile completion record should remember pressure delta.")

func _run_mixed_crossing_schema_smoke(main: Node) -> void:
	var mixed_count := 0
	var hard_industry_count := 0
	for s in main.scenarios:
		var id := String(s.get("id", ""))
		if not main._is_run_scenario_id(id):
			continue
		if int(s.get("difficulty", 1)) < 2:
			continue
		mixed_count += 1
		var orders: Array = s.get("orders", [])
		var mix: Array = s.get("service_mix", [])
		_require(bool(s.get("order_mode", false)), "%s should use explicit order mode beyond the basic tier." % id)
		_require(mix.size() >= 2, "%s should include at least two crossing service requirements." % id)
		_require(_orders_include_cargo(orders, "passengers"), "%s should include a passenger crossing order." % id)
		_require(_stations_include_type(s.get("stations", []), "passenger"), "%s should include passenger stations." % id)
		_require(typeof(s.get("service_routes", {})) == TYPE_DICTIONARY and (s.get("service_routes", {}) as Dictionary).has("passenger_north"), "%s should expose a passenger service route." % id)
		if int(s.get("difficulty", 1)) >= 3:
			_require(_orders_include_cargo(orders, "timber") or _orders_include_cargo(orders, "iron"), "%s should include a timber or iron crossing order in the hard tier." % id)
			hard_industry_count += 1
	_require(mixed_count == 20, "Tier 2 and 3 generated maps should all become mixed crossing contracts.")
	_require(hard_industry_count == 10, "Tier 3 generated maps should add timber/iron industry crossings.")

func _run_mixed_order_compatibility_smoke(main: Node) -> void:
	main.start_scenario("run_11")
	_require(bool(main.local.get("order_mode", false)), "Run 11 should use explicit mixed-order mode.")
	var passenger_order := _first_order_with_cargo(main.local.get("orders", []), "passengers")
	_require(not passenger_order.is_empty(), "Mixed contract should expose a passenger order.")
	var passenger_origin := String(passenger_order.get("origin", ""))
	var passenger_dest := String(passenger_order.get("destination", ""))
	var passenger_line: String = main._create_or_get_line_for_source(passenger_origin)
	_require(passenger_line != "", "Passenger source should create a focused passenger line.")
	_require(String(main.lines[passenger_line].get("service_class", "")) in ["passenger_local", "passenger_express"], "Passenger line should receive a passenger service class.")
	var freight_source := String(main.local["scenario"].get("route", [])[0])
	var freight_line: String = main._create_or_get_line_for_source(freight_source)
	main.selected_line_id = freight_line
	main._context_edit_service_for_station(passenger_origin)
	_require(String(main.selected_line_id) == passenger_line, "Station Edit should choose a line serving that station, not the unrelated last-selected line.")
	var wrong_train: Dictionary = main._new_train_record(main.station_by_id[passenger_origin]["pos"])
	wrong_train["line_id"] = freight_line
	wrong_train["route"] = main.lines[freight_line]["route"]
	main._apply_train_class_stats(wrong_train, "light_freight")
	main._process_order_at_station(wrong_train, main.station_by_id[passenger_origin])
	_require(int(wrong_train.get("cargo_amount", 0)) == 0, "Freight trains should not load passenger orders.")
	_require(int(main.local.get("wrong_service_loads", 0)) > 0, "Wrong service attempts should be tracked for feedback and grading.")
	var passenger_train: Dictionary = main._new_train_record(main.station_by_id[passenger_origin]["pos"])
	passenger_train["line_id"] = passenger_line
	passenger_train["route"] = main.lines[passenger_line]["route"]
	main._apply_train_class_stats(passenger_train, String(main.lines[passenger_line].get("service_class", "passenger_local")))
	main._process_order_at_station(passenger_train, main.station_by_id[passenger_origin])
	_require(String(passenger_train.get("cargo", "")) == "passengers", "Passenger trains should load passenger orders.")
	main._process_order_at_station(passenger_train, main.station_by_id[passenger_dest])
	_require(int(main.local.get("productive_progress", 0)) > 0, "Delivered passenger orders should count as contract progress.")
	main.local["wrong_service_loads"] = 0
	main.local["incompatible_stops"] = 0
	var focused_route: Array = main.lines[passenger_line]["route"].duplicate()
	main.lines[passenger_line]["route"] = focused_route
	main.trains = [{"id": "FocusedPassenger", "line_id": passenger_line}]
	_set_clean_grade_state(main)
	var focused_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	var all_stop_route: Array = []
	for station_id in main.station_by_id.keys():
		all_stop_route.append(String(station_id))
	all_stop_route.append(all_stop_route[0])
	main.lines[passenger_line]["route"] = all_stop_route
	main.lines[passenger_line]["service_class"] = "passenger_local"
	var catchall_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	_require(main._line_incompatible_stop_count(passenger_line) > 0, "All-stop passenger loops should include incompatible freight stops on mixed maps.")
	_require(_grade_rank(focused_grade) > _grade_rank(catchall_grade), "Focused crossing services should grade above catch-all circular service.")

func _run_mobile_compact_ui_smoke(main: Node) -> void:
	var viewports: Array[Vector2] = [Vector2(640, 480), Vector2(390, 844), Vector2(844, 390), Vector2(1280, 720), Vector2(2048, 1024)]
	for viewport in viewports:
		main.size = viewport
		main.start_scenario("run_11")
		main.rebuild_ui()
		main._refresh_local_side_text()
		var grid: Vector2i = main.local["scenario"]["grid"]
		var board_size := Vector2(float(grid.x) * main.cell_size, float(grid.y) * main.cell_size)
		_require(_control_inside_viewport(main.hud_bar, viewport), "HUD should stay inside viewport at %s." % viewport)
		_require(_control_inside_viewport(main.side_panel, viewport), "Compact contract tray should stay inside viewport at %s." % viewport)
		_require(main.grid_origin.y + board_size.y <= viewport.y + main.side_panel.offset_top - 1.0, "Compact contract tray should not cover board tiles at %s." % viewport)
		_require(main.side_text.text.split("\n").size() <= 5, "Default local tray should stay compact instead of showing debug text walls.")
		_require(not bool(main.local.get("debug_details_open", true)), "Verbose diagnostics should be opt-in, not default.")
		main._open_context_menu_at(Vector2(4, 4), "tile", "", Vector2i(0, 0))
		for child in main.context_menu_layer.get_children():
			if child is Control:
				_require(_control_inside_viewport(child, viewport), "Context menu buttons should stay inside viewport at %s." % viewport)
		main._close_context_menu()

func _run_regional_tile_map_smoke(main: Node) -> void:
	_reset_run_state(main)
	_require((main.campaign["regional_map"] as Array).size() == main.REGIONAL_GRID.x * main.REGIONAL_GRID.y, "Fresh run should generate a full 9x7 regional tile map.")
	_require(String(main.campaign.get("regional_position", "")) == main.REGIONAL_START_KEY, "Fresh run should start at the regional start tile.")
	_require(_regional_contract_tile_count(main) >= main.RUN_LENGTH, "Regional map should contain enough reachable contract tiles for a full run.")
	var first_map: String = JSON.stringify(main.campaign["regional_map"])
	_reset_run_state(main)
	_require(JSON.stringify(main.campaign["regional_map"]) == first_map, "Same regional seed should produce the same regional map.")
	for id in main.campaign.get("run_available", []):
		var tile: Dictionary = main._regional_tile_for_scenario(String(id))
		_require(_regional_key_adjacent(String(main.campaign["regional_position"]), String(tile.get("key", ""))), "Visible run choices should be adjacent to current regional position.")
	var first_id: String = String((main.campaign["run_available"] as Array)[0])
	var first_tile: Dictionary = main._regional_tile_for_scenario(first_id)
	main.start_scenario(first_id)
	main.local["productive_progress"] = int(main.local["target"])
	main._complete_scenario()
	_require(String(main.campaign["regional_position"]) == String(first_tile.get("key", "")), "Completing a contract should move regional position to that tile.")
	_require((main.campaign["regional_completed_tiles"] as Array).has(String(first_tile.get("key", ""))), "Completed regional tile should be recorded.")
	main.screen = main.Screen.REGIONAL
	var money_before: int = int(main.campaign["money"])
	main.campaign["upgrade_shop"] = ["reward_multiplier", "train_voucher", "material_efficiency"]
	main._purchase_upgrade("reward_multiplier")
	_require(int(main.campaign["money"]) == money_before - 260, "Upgrade purchases should spend campaign money.")
	_require(int((main.campaign["permanent_upgrades"] as Dictionary).get("reward_multiplier", 0)) == 1, "Permanent upgrade should be recorded in permanent upgrades.")
	main._purchase_upgrade("train_voucher")
	_require(int((main.campaign["run_upgrades"] as Dictionary).get("train_voucher", 0)) == 1, "Run upgrade should be recorded in run upgrades.")

func _run_grade_regional_pressure_smoke(main: Node) -> void:
	_reset_run_state(main)
	main.start_scenario("run_01")
	main.local["productive_progress"] = int(main.local["target"])
	var clean_preview_zero_debt: String = main._completion_inspection_preview_text(main.local["scenario"], 1.0, true)
	_require(clean_preview_zero_debt.contains("keeps the region forgiving"), "Clean generated clears with no inspection debt should promise stability, not fake relief.")
	var gold_effect_text: String = main._completion_regional_effect_text(main.local["scenario"], "gold")
	_require(main._completion_inspection_fine(main.local["scenario"], "gold") == 0, "Gold generated clears should not pay inspection fines.")
	_require(main._completion_inspection_rebate(main.local["scenario"], "gold") == 0, "Gold generated clears should not pay fake inspection rebates without debt.")
	var no_streak_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(main._completion_mastery_streak_bonus(main.local["scenario"], "gold") == 25, "First Gold generated clear should start a modest mastery streak bonus.")
	main.campaign["run_history"] = [
		{"quality_grade": "gold"},
		{"quality_grade": "perfect"},
		{"quality_grade": "gold"}
	]
	var streak_bonus: int = main._completion_mastery_streak_bonus(main.local["scenario"], "gold")
	var streak_reward: int = main._completion_reward_money(main.local["scenario"], 1.0, true)
	_require(streak_bonus == 100, "Gold/Perfect streak bonuses should be capped after sustained clean play.")
	_require(streak_reward == no_streak_reward + 75, "Clean mastery streaks should increase reward without changing the base grade.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Streak +$100"), "Completion summary should expose the mastery streak bonus.")
	_require(main._regional_contract_preview_text(main.local["scenario"]).contains("Mastery streak: 3 Gold+ in a row") and main._regional_contract_preview_text(main.local["scenario"]).contains("+$100"), "Regional contract previews should forecast the next clean-streak reward.")
	_require(main._local_contract_clause_text().contains("Mastery streak: 3 Gold+ in a row"), "Local contract chip should preserve clean-streak reward visibility while building.")
	main.campaign["run_history"] = []
	main._record_run_completion(main.local["scenario"], 1.0, true, "gold")
	var gold_traits: Dictionary = (main.campaign["regional_traits"] as Dictionary).duplicate(true)
	var gold_next: Dictionary = main._apply_run_pressure_to_scenario(main._get_scenario("run_02"))
	_require(main._regional_run_momentum_text().contains("Run momentum: clean"), "Gold regional clears should create clean momentum feedback.")
	_require(gold_effect_text.contains("Regional effect"), "Run results should explain grade impact on future regional pressure.")
	_require(gold_effect_text.contains("inspection"), "Run results should explain inspection impact from completion quality.")
	_require(String(((main.campaign["run_history"] as Array)[0] as Dictionary).get("quality_grade", "")) == "gold", "Run history should record the completion grade.")
	_require(int(gold_traits.get("inspection_debt", 0)) == 0, "Gold clears should not create inspection debt.")
	_require(main._regional_pressure_forecast_text(gold_traits).contains("calm"), "Gold regional clears should forecast calm future pressure when capacity is healthy.")
	_reset_run_state(main)
	var indebted_traits: Dictionary = main.campaign["regional_traits"]
	indebted_traits["inspection_debt"] = 6
	main.campaign["regional_traits"] = indebted_traits
	main.start_scenario("run_01")
	main.local["productive_progress"] = int(main.local["target"])
	var clean_preview_with_debt: String = main._completion_inspection_preview_text(main.local["scenario"], 1.0, true)
	var clean_debt_grade: String = main._completion_quality_grade(main.local["scenario"], 1.0, true)
	var clean_debt_rebate: int = main._completion_inspection_rebate(main.local["scenario"], clean_debt_grade)
	_require(clean_debt_rebate > 0, "Clean generated clears should earn an inspection rebate when paying down existing debt.")
	_require(clean_preview_with_debt.contains("Inspection relief") and clean_preview_with_debt.contains("rebate"), "Clean generated clears should show inspection debt recovery and rebate when the region is under scrutiny.")
	_require(main._completion_quality_summary(main.local["scenario"], 1.0, true).contains("Inspect -$0/+$%d" % clean_debt_rebate), "Completion quality summary should expose inspection recovery rebates.")
	var recovery_preview: String = main._regional_contract_preview_text(main.local["scenario"])
	_require(recovery_preview.contains("Recovery: Gold/Perfect clears reduce inspection debt"), "Regional contract previews should explain the recovery path when inspection debt exists.")
	_reset_run_state(main)
	main.start_scenario("run_01")
	main.local["productive_progress"] = int(main.local["target"])
	main.local["deadlocks"] = 2
	main.local["service_mileage"] = 280.0
	main.local["empty_mileage"] = 180.0
	var inspection_preview: String = main._completion_inspection_preview_text(main.local["scenario"], main._average_wait(), main._current_productive_for_grade(main._average_wait()))
	_require(inspection_preview.contains("Inspection risk") and inspection_preview.contains("inspection +") and inspection_preview.contains("fine"), "Live rough circular clears should preview inspection debt and fines before completion.")
	var rough_grade: String = main._completion_quality_grade(main.local["scenario"], main._average_wait(), main._current_productive_for_grade(main._average_wait()))
	var rough_fine: int = main._completion_inspection_fine(main.local["scenario"], rough_grade)
	_require(rough_fine > 0, "Rough circular clears should receive an inspection fine that cuts exploit payout.")
	_require(main._completion_mastery_streak_bonus(main.local["scenario"], rough_grade) == 0, "Rough circular clears should not earn mastery streak bonuses.")
	_require(main._completion_quality_summary(main.local["scenario"], main._average_wait(), main._current_productive_for_grade(main._average_wait())).contains("Inspect -$%d" % rough_fine), "Completion quality summary should expose the inspection fine.")
	_require(main._local_contract_clause_text().contains("Inspection risk"), "Local contract chip should preview inspection risk before accepting a rough circular clear.")
	var created_inspection_side_text := false
	if main.side_text == null:
		main.side_text = RichTextLabel.new()
		created_inspection_side_text = true
	main._refresh_local_side_text()
	_require(main.side_text.text.contains("Inspection risk"), "Local side feedback should warn that rough circular clears make later contracts harder.")
	if created_inspection_side_text:
		main.side_text.free()
		main.side_text = null
	main._record_run_completion(main.local["scenario"], float(main.local["wait_target"]) * 2.0, false, "rough")
	var rough_traits: Dictionary = (main.campaign["regional_traits"] as Dictionary).duplicate(true)
	var rough_next: Dictionary = main._apply_run_pressure_to_scenario(main._get_scenario("run_02"))
	_require(main._regional_run_momentum_text().contains("Run momentum: risky") and main._regional_run_momentum_text().contains("rebates"), "Rough circular clears should create risky momentum feedback with a recovery path.")
	_require(int(rough_traits.get("through_traffic", 0)) > int(gold_traits.get("through_traffic", 0)), "Rough circular clears should add more future through-traffic than gold clears.")
	_require(int(rough_traits.get("capacity_rating", 0)) < int(gold_traits.get("capacity_rating", 0)), "Rough circular clears should add less future capacity than gold clears.")
	_require(float(rough_traits.get("reliability", 1.0)) < float(gold_traits.get("reliability", 0.0)), "Rough circular clears should reduce future regional reliability.")
	_require(float(rough_traits.get("burstiness", 0.0)) > float(gold_traits.get("burstiness", 0.0)), "Rough circular clears should increase future operating surge.")
	_require(int(rough_traits.get("inspection_debt", 0)) > int(gold_traits.get("inspection_debt", 0)), "Rough circular clears should create inspection debt for future contracts.")
	var rough_forecast: String = main._regional_pressure_forecast_text(rough_traits)
	_require(rough_forecast.contains("Regional pressure") and rough_forecast.contains("Gold dispatch") and rough_forecast.contains("inspection L"), "Regional pressure forecast should explain that quality clears calm future maps.")
	_require(int(rough_next.get("regional_surge_level", 0)) > int(gold_next.get("regional_surge_level", 0)), "Rough circular clears should turn operating surge into explicit next-contract pressure.")
	_require(int(rough_next.get("regional_inspection_level", 0)) > int(gold_next.get("regional_inspection_level", 0)), "Rough circular clears should turn inspection debt into explicit next-contract pressure.")
	_require(int(rough_next.get("target", 0)) >= int(gold_next.get("target", 0)), "Rough regional pressure should not make the next contract easier.")
	_require(float(rough_next.get("wait_target", 999.0)) <= float(gold_next.get("wait_target", 0.0)), "Rough regional pressure should tighten the next contract wait target.")
	_require(main._regional_contract_preview_text(rough_next).contains("surge L") and main._regional_contract_preview_text(rough_next).contains("inspection L"), "Regional contract previews should show inherited surge and inspection pressure before selection.")
	main.start_scenario("run_02")
	_require(main._local_contract_clause_text().contains("Regional pressure applied"), "Local contract chip should explain inherited regional pressure.")
	main.screen = main.Screen.REGIONAL
	main.rebuild_ui()
	_require(main.side_text.text.contains("Regional pressure") and main.side_text.text.contains("surge L") and main.side_text.text.contains("inspection L"), "Regional side panel should show inherited pressure in adjacent contract previews.")
	_require(main.side_text.text.contains("Run momentum: risky"), "Regional side panel should summarize recent rough-clear momentum before the next contract.")

func _run_generated_contract_play_smoke(main: Node) -> void:
	for index in range(main.RUN_POOL_SIZE):
		var id := "run_%02d" % (index + 1)
		_reset_run_state(main)
		main.start_scenario(id)
		main.local["money"] = 9000
		main.local["fleet_goal"] = 1
		if bool(main.local.get("order_mode", false)):
			var target_total := 0
			var reduced_orders: Array = []
			for order in main.local.get("orders", []):
				var copy: Dictionary = (order as Dictionary).duplicate(true)
				copy["amount"] = 1
				reduced_orders.append(copy)
				target_total += 1
			main.local["orders"] = reduced_orders
			main.local["scenario"]["orders"] = reduced_orders
			main.local["target"] = target_total
			main.local["scenario"]["target"] = target_total
			main.local["fleet_goal"] = max(1, min(target_total, int(main.local.get("fleet_goal", 1))))
		elif main.local.get("kind", "") == "yard":
			main.local["target"] = 1
		elif main.local.get("kind", "") == "steel":
			main.local["target"] = 10
		else:
			main.local["target"] = 10
		_build_ghost_solution(main)
		if bool(main.local.get("order_mode", false)):
			_build_all_service_routes(main)
		main._compute_blocks()
		if bool(main.local.get("order_mode", false)):
			var bought_sources: Array[String] = []
			for order in main.local.get("orders", []):
				var order_source := String((order as Dictionary).get("origin", ""))
				if order_source != "" and not bought_sources.has(order_source):
					main._buy_train_for_source(order_source)
					bought_sources.append(order_source)
			var primary_source := String(main.local["scenario"]["route"][0])
			while main.trains.size() < int(main.local.get("fleet_goal", 1)):
				main._buy_train_for_source(primary_source)
		else:
			var legacy_source := String(main.local["scenario"]["route"][0])
			main._buy_train_for_source(legacy_source)
		for i in range(2200):
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
		_require(not choices.is_empty(), "Run should keep offering contracts until all maps are complete.")
		var id := String(choices[0])
		main.start_scenario(id)
		_force_complete_current_contract(main)
		guard += 1
	_require(int(main.campaign.get("run_step", 0)) == main.RUN_LENGTH, "Run progression should reach all generated maps.")
	_require(bool(main.campaign.get("run_won", false)), "Run should mark itself won after all generated maps.")
	_require((main.campaign.get("run_history", []) as Array).size() == main.RUN_LENGTH, "Run history should record every completed map.")
	var traits: Dictionary = main.campaign.get("regional_traits", {})
	_require(int(traits.get("through_traffic", 0)) > 0, "Completed run maps should add through-traffic pressure.")
	_require(float(traits.get("reliability", 0.0)) > 0.0, "Completed run maps should store reliability for later node interaction.")

func _run_reset_progress_smoke(main: Node) -> void:
	main.campaign["completed"] = ["coal_valley", "run_01"]
	main.campaign["run_completed"] = ["run_01", "run_02"]
	main.campaign["run_step"] = 2
	main.campaign["run_history"] = [{"id": "run_01"}, {"id": "run_02"}]
	main.campaign["mastery_records"] = {"run_01": {"grade": "gold", "bonus_met": true}}
	main.campaign["run_won"] = true
	main.campaign["permanent_upgrades"] = {"reward_multiplier": 2}
	main.campaign["run_upgrades"] = {"train_voucher": 1}
	main.campaign["regional_map"] = [{"key": "old"}]
	main.campaign["regional_completed_tiles"] = ["0,3", "1,3"]
	main.campaign["regional_tile_records"] = {"1,3": {"grade": "perfect"}}
	main.campaign["daily_puzzle_seed"] = 123
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
		"burstiness": 1.2,
		"inspection_debt": 8
	}
	main._reset_progress(false)
	_require(int(main.campaign["money"]) == 1500, "Reset Progress should restore starting money.")
	_require(int(main.campaign["traffic_load"]) == 18 and int(main.campaign["traffic_capacity"]) == 40, "Reset Progress should restore regional traffic defaults.")
	_require((main.campaign["completed"] as Array).is_empty(), "Reset Progress should clear completed tutorial/run IDs.")
	_require((main.campaign["run_completed"] as Array).is_empty(), "Reset Progress should clear run completions.")
	_require((main.campaign["run_history"] as Array).is_empty(), "Reset Progress should clear run history.")
	_require((main.campaign["mastery_records"] as Dictionary).is_empty(), "Reset Progress should clear mastery records.")
	_require(int(main.campaign["run_step"]) == 0 and not bool(main.campaign["run_won"]), "Reset Progress should return the run to 0 and not won.")
	_require((main.campaign["run_available"] as Array).size() == main.RUN_CHOICES, "Reset Progress should generate fresh contract choices.")
	_require((main.campaign["permanent_upgrades"] as Dictionary).is_empty() and (main.campaign["run_upgrades"] as Dictionary).is_empty(), "Reset Progress should clear permanent and run upgrades.")
	_require((main.campaign["regional_map"] as Array).size() == main.REGIONAL_GRID.x * main.REGIONAL_GRID.y, "Reset Progress should generate a fresh regional tile map.")
	_require((main.campaign["regional_tile_records"] as Dictionary).is_empty(), "Reset Progress should clear regional tile proof records.")
	_require(int(main.campaign.get("daily_puzzle_seed", 0)) == main.DAILY_PUZZLE_SEED, "Reset Progress should restore the deterministic daily puzzle hook.")
	var traits: Dictionary = main.campaign["regional_traits"]
	_require(int(traits.get("through_traffic", -1)) == 0 and float(traits.get("reliability", 0.0)) == 1.0 and int(traits.get("inspection_debt", -1)) == 0, "Reset Progress should restore inherited regional traits.")

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
	main.local["fleet_goal"] = 8
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
	_require(main._dispatch_speed_factor() == 1.0, "Density smoke should model a properly contracted eight-train service, not over-fleet slowdown.")
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
	main.campaign["regional_map_seed"] = 32027
	main.campaign["regional_map"] = []
	main.campaign["regional_position"] = main.REGIONAL_START_KEY
	main.campaign["regional_completed_tiles"] = []
	main.campaign["regional_tile_records"] = {}
	main.campaign["regional_visible_tiles"] = []
	main.campaign["active_regional_tile"] = ""
	main.campaign["daily_puzzle_seed"] = main.DAILY_PUZZLE_SEED
	main.campaign["permanent_upgrades"] = {}
	main.campaign["run_upgrades"] = {}
	main.campaign["upgrade_shop"] = []
	main.campaign["run_step"] = 0
	main.campaign["run_completed"] = []
	main.campaign["run_available"] = []
	main.campaign["run_history"] = []
	main.campaign["mastery_records"] = {}
	main.campaign["run_won"] = false
	main.campaign["regional_traits"] = {
		"coal_output": 0,
		"freight_output": 0,
		"steel_output": 0,
		"reliability": 1.0,
		"capacity_rating": 0,
		"through_traffic": 0,
		"burstiness": 0.0,
		"inspection_debt": 0
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

func _orders_include_cargo(orders: Array, cargo: String) -> bool:
	for order in orders:
		if String((order as Dictionary).get("cargo", "")) == cargo:
			return true
	return false

func _stations_include_type(stations: Array, station_type: String) -> bool:
	for station in stations:
		if String((station as Dictionary).get("station_type", "")) == station_type:
			return true
	return false

func _first_order_with_cargo(orders: Array, cargo: String) -> Dictionary:
	for order in orders:
		var data: Dictionary = order
		if String(data.get("cargo", "")) == cargo:
			return data
	return {}

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

func _build_all_service_routes(main: Node) -> void:
	var routes: Dictionary = main.local["scenario"].get("service_routes", {})
	for source_id in routes.keys():
		var route: Array = routes[source_id]
		for i in range(route.size() - 1):
			var from_id := String(route[i])
			var to_id := String(route[i + 1])
			if not main.station_by_id.has(from_id) or not main.station_by_id.has(to_id):
				continue
			main._place_track_path(main.station_by_id[from_id]["pos"], main.station_by_id[to_id]["pos"])

func _variant_connects_required_route(main: Node, id: String, variant: Dictionary) -> bool:
	main.start_scenario(id)
	var path: Array = variant.get("path", [])
	if path.size() < 2:
		return false
	for i in range(path.size() - 1):
		var from_cell: Vector2i = path[i]
		var to_cell: Vector2i = path[i + 1]
		main._place_track_path(from_cell, to_cell)
	var route: Array = main.local["scenario"].get("route", [])
	if route.size() < 2:
		return false
	for i in range(route.size() - 1):
		var from_id: String = String(route[i])
		var to_id: String = String(route[i + 1])
		if not main.station_by_id.has(from_id) or not main.station_by_id.has(to_id):
			return false
		var from_station: Dictionary = main.station_by_id[from_id]
		var to_station: Dictionary = main.station_by_id[to_id]
		var leg: Array = main._find_track_path_ignore_signals(from_station["pos"], to_station["pos"])
		if leg.is_empty():
			return false
	return true

func _set_clean_grade_state(main: Node) -> void:
	main.local["productive_progress"] = int(main.local.get("target", 0))
	main.local["delivered"] = int(main.local.get("target", 0))
	main.local["processed"] = int(main.local.get("target", 0))
	main.local["deadlocks"] = 0
	main.local["unqualified_output"] = 0
	main.local["detour_output"] = 0
	main.local["detour_stops"] = 0
	main.local["detour_dwell"] = 0.0
	main.local["excess_mileage"] = 0
	main.local["excess_mileage_output"] = 0
	main.local["service_mileage"] = 0.0
	main.local["empty_mileage"] = 0.0
	main.local["max_output_gap"] = 1.0
	main.local["elapsed_time"] = 1.0
	main.local["infra_cost"] = main._reward_material_par(main.local["scenario"])

func _gauntlet_train_list(count: int, line_id: String, prefix: String) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({"id": "%s%d" % [prefix, i], "line_id": line_id})
	return result

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

func _action_labels_have(actions: Array, label: String) -> bool:
	for action in actions:
		if String(action.get("label", "")) == label:
			return true
	return false

func _grade_rank(grade: String) -> int:
	if grade == "perfect":
		return 5
	if grade == "gold":
		return 4
	if grade == "silver":
		return 3
	if grade == "bronze":
		return 2
	return 1

func _regional_contract_tile_count(main: Node) -> int:
	var count := 0
	for tile in main.campaign.get("regional_map", []):
		if String(tile.get("scenario_id", "")) != "":
			count += 1
	return count

func _regional_key_adjacent(a_key: String, b_key: String) -> bool:
	var a := _regional_key_to_pos_for_test(a_key)
	var b := _regional_key_to_pos_for_test(b_key)
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func _regional_key_to_pos_for_test(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-999, -999)
	return Vector2i(int(parts[0]), int(parts[1]))

func _require(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
