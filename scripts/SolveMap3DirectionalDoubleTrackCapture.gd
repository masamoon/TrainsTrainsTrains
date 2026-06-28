extends SceneTree

const OUT_DIR := "res://tmp/screens"
const OUT_NAME := "map3_directional_double_track_solution.png"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(2048, 1024))
	root.size = Vector2i(2048, 1024)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	main.size = Vector2(2048, 1024)
	await _settle()

	main.start_scenario("steelworks")
	main.local["money"] = 12000
	main.local["materials"] = 32
	main.local["target"] = 999
	_build_directional_double_track(main)
	_add_directional_signals(main)
	main.station_by_id["west_line"]["platforms"] = 2
	main.station_by_id["east_line"]["platforms"] = 2
	for i in range(3):
		main._add_platform()
	var line_id: String = main._create_or_get_line_for_source("west_line")
	main.lines[line_id]["route"] = ["west_line", "central_yard", "east_line", "central_yard", "west_line"]
	main.lines[line_id]["name"] = main._line_name_for_route(main.lines[line_id]["route"])
	for i in range(4):
		main._buy_train_for_line(line_id)
	main.selected_train_id = "T02"
	main.selected_tool = "block"
	main.signal_help_open = true

	for i in range(6000):
		if main.screen != main.Screen.LOCAL:
			break
		_step_fast(main, 0.1)
		if int(main.local.get("productive_progress", 0)) >= 60:
			break

	main.local["target"] = 60
	main._update_status_labels()
	main._refresh_local_side_text()
	main.queue_redraw()
	print("processed=", main.local.get("processed", 0), " productive=", main.local.get("productive_progress", 0), " trains=", main.trains.size(), " screen=", main.screen, " deadlocks=", main.local.get("deadlocks", 0), " avg_wait=", main._average_wait())
	for t in main.trains:
		print(t["id"], " state=", t["state"], " tile=", t["tile"], " next=", main._next_stop_name_for_train(t), " leg=", main._next_leg_name_for_train(t), " reason=", t.get("wait_reason", ""))
	await _settle()
	_save_view(OUT_NAME)
	quit(0)

func _build_directional_double_track(main: Node) -> void:
	main._place_track_path(Vector2i(1, 4), Vector2i(2, 5))
	main._place_track_path(Vector2i(2, 5), Vector2i(16, 5))
	main._place_track_path(Vector2i(16, 5), Vector2i(15, 4))
	main._place_track_path(Vector2i(15, 4), Vector2i(10, 4))
	main._place_track_path(Vector2i(10, 4), Vector2i(9, 5))
	main._place_track_path(Vector2i(9, 5), Vector2i(8, 4))
	main._place_track_path(Vector2i(8, 4), Vector2i(2, 4))
	main._place_track_path(Vector2i(2, 4), Vector2i(1, 4))
	main._compute_blocks()

func _add_directional_signals(main: Node) -> void:
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	var southeast: Array[Vector2i] = [Vector2i(1, 1)]
	var southwest: Array[Vector2i] = [Vector2i(-1, 1)]
	var northwest: Array[Vector2i] = [Vector2i(-1, -1)]
	var west_station: Array[Vector2i] = [Vector2i(1, 1)]
	var central_station: Array[Vector2i] = [Vector2i.RIGHT, Vector2i(-1, -1)]
	var east_station: Array[Vector2i] = [Vector2i(-1, -1)]

	main._replace_signal_set(Vector2i(1, 4), "chain", west_station)
	for x in [3, 5, 7, 10, 12, 14]:
		main._replace_signal_set(Vector2i(x, 5), "block", east)
	main._replace_signal_set(Vector2i(9, 5), "chain", central_station)
	main._replace_signal_set(Vector2i(16, 5), "chain", east_station)
	main._replace_signal_set(Vector2i(15, 4), "block", west)
	main._replace_signal_set(Vector2i(13, 4), "block", west)
	main._replace_signal_set(Vector2i(11, 4), "block", west)
	main._replace_signal_set(Vector2i(10, 4), "block", southwest)
	main._replace_signal_set(Vector2i(8, 4), "block", west)
	main._replace_signal_set(Vector2i(6, 4), "block", west)
	main._replace_signal_set(Vector2i(4, 4), "block", west)
	main._replace_signal_set(Vector2i(2, 4), "block", west)
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
