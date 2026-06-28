extends SceneTree

const OUT_DIR := "res://tmp/screens"
const OUT_NAME := "map3_passing_siding_two_train.png"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(2048, 1024))
	root.size = Vector2i(2048, 1024)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	main.size = Vector2(2048, 1024)
	await _settle()

	main.start_scenario("steelworks")
	main.local["money"] = 8000
	main.local["materials"] = 16
	main.local["fleet_goal"] = 2
	main.local["target"] = 999
	_build_passing_siding_layout(main)
	_add_passing_siding_signals(main)
	main._add_platform()
	var line_id: String = main._create_or_get_line_for_source("west_line")
	main.lines[line_id]["route"] = ["west_line", "central_yard", "east_line", "west_line"]
	main.lines[line_id]["name"] = main._line_name_for_route(main.lines[line_id]["route"])
	for i in range(2):
		main._buy_train_for_line(line_id)
	main.selected_train_id = "T01"
	main.selected_tool = "block"
	main.signal_help_open = true

	for i in range(9000):
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

func _build_passing_siding_layout(main: Node) -> void:
	main._place_track_path(Vector2i(1, 4), Vector2i(2, 5))
	main._place_track_path(Vector2i(2, 5), Vector2i(16, 5))
	main._place_track_path(Vector2i(3, 5), Vector2i(4, 4))
	main._place_track_path(Vector2i(4, 4), Vector2i(7, 4))
	main._place_track_path(Vector2i(7, 4), Vector2i(8, 5))
	main._place_track_path(Vector2i(11, 5), Vector2i(12, 4))
	main._place_track_path(Vector2i(12, 4), Vector2i(14, 4))
	main._place_track_path(Vector2i(14, 4), Vector2i(15, 5))
	main._compute_blocks()

func _add_passing_siding_signals(main: Node) -> void:
	_place_all_way_block(main, Vector2i(2, 5))
	_place_all_way_chain(main, Vector2i(3, 5))
	_place_all_way_block(main, Vector2i(4, 4))
	_place_all_way_block(main, Vector2i(7, 4))
	_place_all_way_chain(main, Vector2i(8, 5))
	_place_all_way_block(main, Vector2i(9, 5))
	_place_all_way_chain(main, Vector2i(11, 5))
	_place_all_way_block(main, Vector2i(12, 4))
	_place_all_way_block(main, Vector2i(14, 4))
	_place_all_way_chain(main, Vector2i(15, 5))
	main._compute_blocks()

func _place_all_way_block(main: Node, pos: Vector2i) -> void:
	main._replace_signal_set(pos, "block", main._signal_direction_options(pos))

func _place_all_way_chain(main: Node, pos: Vector2i) -> void:
	main._replace_signal_set(pos, "chain", main._signal_direction_options(pos))

func _settle() -> void:
	for i in range(5):
		await process_frame

func _save_view(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(name))
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("Saved ", path)
