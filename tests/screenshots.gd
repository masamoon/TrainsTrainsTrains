extends SceneTree
## Renders each screen to docs/screens/*.png for review.
## xvfb-run godot --path . --rendering-method gl_compatibility --resolution 720x1280 --script res://tests/screenshots.gd

var main: Control


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://docs/screens")
	img.save_png("res://docs/screens/%s.png" % name)
	print("saved ", name)


func _run() -> void:
	main = load("res://scenes/main/Main.tscn").instantiate()
	main.save.path = "user://screenshot_save.json"
	var s: Save = main.save
	s.data.levels = {"1-1": {"stars": 3, "layout": {}}, "1-2": {"stars": 3, "layout": {}}, "1-3": {"stars": 2, "layout": {}}}
	var today := DailyGen.today()
	for back in range(1, 5):
		s.data.daily[str(today - back)] = {"rows": [["arrived", "arrived"]], "solved": true, "layout": {}, "track": 12}
	root.add_child(main)
	await _shot("home")

	main.show_map()
	await _shot("map")

	main.play_level(4)
	var play: Control = main.current
	await process_frame
	var pz: Puzzle = play.pz
	var lay := pz.solution_layout()
	play._set_layout(lay)
	await _shot("level")
	play._depart()
	for i in 70:
		await process_frame
	await _shot("level_running")

	main.play_daily()
	await _shot("daily")
	play = main.current
	await process_frame
	var dpz: Puzzle = play.pz
	s.data.daily[str(today)] = {"rows": [["crashed", "arrived", "wrong"], ["arrived", "arrived", "crashed"], ["arrived", "arrived", "arrived"]], "solved": true, "layout": dpz.solution_layout().to_dict(), "track": dpz.par + 2}
	main.play_daily()
	await _shot("daily_result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://screenshot_save.json"))
	quit()
