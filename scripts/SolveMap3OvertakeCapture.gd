extends SceneTree

const OUT_DIR := "res://tmp/screens"
const OUT_NAME := "map3_overtake_pass_solution.png"

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
	main.local["materials"] = 24
	main.local["target"] = 999
	_build_loop_with_overtake(main)
	_add_overtake_signals(main)
	main._add_platform()
	main._add_platform()
	main._add_platform()
	for i in range(4):
		main._buy_train_for_source("west_line")
	main.selected_train_id = "T02"
	main.selected_tool = "block"
	main.signal_help_open = true

	for i in range(4200):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
		if int(main.local.get("productive_progress", 0)) >= 60:
			break

	main.local["target"] = 60
	main._update_status_labels()
	main._refresh_local_side_text()
	main.queue_redraw()

	print("processed=", main.local.get("processed", 0), " productive=", main.local.get("productive_progress", 0), " trains=", main.trains.size(), " screen=", main.screen)
	for t in main.trains:
		print(t["id"], " state=", t["state"], " tile=", t["tile"], " next=", main._next_stop_name_for_train(t), " leg=", main._next_leg_name_for_train(t), " reason=", t.get("wait_reason", ""))
	await _settle()
	_save_view(OUT_NAME)
	quit(0)

func _build_loop_with_overtake(main: Node) -> void:
	main._place_track_path(Vector2i(1, 4), Vector2i(2, 5))
	main._place_track_path(Vector2i(2, 5), Vector2i(16, 5))
	main._place_track_path(Vector2i(3, 5), Vector2i(4, 4))
	main._place_track_path(Vector2i(4, 4), Vector2i(8, 4))
	main._place_track_path(Vector2i(8, 4), Vector2i(9, 5))
	main._place_track_path(Vector2i(16, 5), Vector2i(14, 7))
	main._place_track_path(Vector2i(14, 7), Vector2i(10, 7))
	main._place_track_path(Vector2i(10, 7), Vector2i(9, 5))
	main._place_track_path(Vector2i(9, 5), Vector2i(7, 3))
	main._place_track_path(Vector2i(7, 3), Vector2i(2, 3))
	main._place_track_path(Vector2i(2, 3), Vector2i(1, 4))
	main._compute_blocks()

func _add_overtake_signals(main: Node) -> void:
	var east: Array[Vector2i] = [Vector2i.RIGHT]
	var west: Array[Vector2i] = [Vector2i.LEFT]
	var northeast: Array[Vector2i] = [Vector2i(1, -1)]
	var southeast: Array[Vector2i] = [Vector2i(1, 1)]
	var northwest: Array[Vector2i] = [Vector2i(-1, -1)]
	var split: Array[Vector2i] = [Vector2i.RIGHT, Vector2i(1, -1)]
	main._replace_signal_set(Vector2i(3, 5), "chain", split)
	main._replace_signal_set(Vector2i(4, 4), "block", east)
	var pass_merge: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, -1)]
	main._replace_signal_set(Vector2i(8, 4), "block", pass_merge)
	main._replace_signal_set(Vector2i(5, 5), "block", east)
	main._replace_signal_set(Vector2i(8, 5), "block", east)
	main._replace_signal_set(Vector2i(11, 5), "block", east)
	main._replace_signal_set(Vector2i(13, 5), "block", east)
	main._replace_signal_set(Vector2i(15, 5), "block", east)
	main._replace_signal_set(Vector2i(14, 7), "block", west)
	main._replace_signal_set(Vector2i(12, 7), "block", west)
	main._replace_signal_set(Vector2i(10, 7), "chain", northwest)
	main._replace_signal_set(Vector2i(7, 3), "block", west)
	main._replace_signal_set(Vector2i(6, 3), "block", west)
	main._replace_signal_set(Vector2i(3, 3), "block", west)
	main._compute_blocks()

func _settle() -> void:
	for i in range(5):
		await process_frame

func _save_view(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(name))
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("Saved ", path)
