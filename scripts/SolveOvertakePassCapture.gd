extends SceneTree

const OUT_DIR := "res://tmp/screens"
const OUT_NAME := "overtake_pass_solution.png"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(2048, 1024))
	root.size = Vector2i(2048, 1024)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	main.size = Vector2(2048, 1024)
	await _settle()

	main.start_scenario("overtake_pass")
	main.local["money"] = 9000
	main.local["materials"] = 20
	main.local["target"] = 999
	_build_overtake_corridor(main)
	_add_overtake_signals(main)
	var line_id: String = main._create_or_get_line_for_source("west_line")
	for i in range(4):
		main._buy_train_for_line(line_id)
	main.selected_train_id = "T02"
	main.selected_tool = "block"
	main.signal_help_open = true

	for i in range(8000):
		if main.screen != main.Screen.LOCAL:
			break
		_step_fast(main, 0.1)
		if int(main.local.get("productive_progress", 0)) >= 40:
			break

	main.local["target"] = 40
	main._update_status_labels()
	main._refresh_local_side_text()
	main.queue_redraw()
	print("processed=", main.local.get("processed", 0), " productive=", main.local.get("productive_progress", 0), " trains=", main.trains.size(), " screen=", main.screen, " deadlocks=", main.local.get("deadlocks", 0), " avg_wait=", main._average_wait())
	for t in main.trains:
		var path: Array = t.get("path", [])
		var path_index := int(t.get("path_index", 0))
		var next_tile = path[path_index] if path_index < path.size() else Vector2i(-999, -999)
		var allowed := false
		if path_index < path.size():
			allowed = main._can_enter_next_tile(t, next_tile)
		print(t["id"], " state=", t["state"], " tile=", t["tile"], " path_index=", path_index, " path_size=", path.size(), " next_tile=", next_tile, " allowed=", allowed, " next=", main._next_stop_name_for_train(t), " leg=", main._next_leg_name_for_train(t), " reason=", t.get("wait_reason", ""))
	await _settle()
	_save_view(OUT_NAME)
	quit(0)

func _build_overtake_corridor(main: Node) -> void:
	main._place_track_path(Vector2i(1, 5), Vector2i(16, 5))
	main._place_track_path(Vector2i(3, 5), Vector2i(4, 4))
	main._place_track_path(Vector2i(4, 4), Vector2i(6, 4))
	main._place_track_path(Vector2i(6, 4), Vector2i(7, 5))
	main._place_track_path(Vector2i(8, 5), Vector2i(9, 4))
	main._place_track_path(Vector2i(9, 4), Vector2i(11, 4))
	main._place_track_path(Vector2i(11, 4), Vector2i(12, 5))
	main._place_track_path(Vector2i(13, 5), Vector2i(14, 4))
	main._place_track_path(Vector2i(14, 4), Vector2i(15, 4))
	main._place_track_path(Vector2i(15, 4), Vector2i(16, 5))
	main._compute_blocks()

func _add_overtake_signals(main: Node) -> void:
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	var southwest: Array[Vector2i] = [Vector2i(-1, 1)]
	var east_west: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT]
	var east_northwest: Array[Vector2i] = [Vector2i.RIGHT, Vector2i(-1, -1)]
	var west_station: Array[Vector2i] = [Vector2i.RIGHT]
	var east_station: Array[Vector2i] = [Vector2i(-1, -1)]

	main._replace_signal_set(Vector2i(1, 5), "chain", west_station)
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

func _settle() -> void:
	for i in range(5):
		await process_frame

func _save_view(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(name))
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("Saved ", path)
