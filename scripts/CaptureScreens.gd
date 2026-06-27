extends SceneTree

const OUT_DIR := "/Users/andrelopes/trains-trains-trains/tmp/screens"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	main.size = Vector2(1280, 720)
	await _settle()
	_save_view("regional_generated_ui.png")

	main.start_scenario("coal_valley")
	main._place_track_path(Vector2i(1, 4), Vector2i(12, 4))
	main._place_signal(Vector2i(4, 4), "block")
	main._place_signal(Vector2i(8, 4), "block")
	main._buy_train()
	main._toggle_speed()
	main._toggle_pause()
	for i in range(90):
		main._update_local(0.1)
	await _settle()
	_save_view("local_generated_board.png")

	main.start_scenario("central_yard")
	main._select_tool("train")
	await _settle()
	_save_view("central_yard_contract.png")

	quit(0)

func _settle() -> void:
	for i in range(4):
		await process_frame

func _save_view(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(OUT_DIR.path_join(name))
	print("Saved ", OUT_DIR.path_join(name))
