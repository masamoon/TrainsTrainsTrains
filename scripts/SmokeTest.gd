extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	_run_coal_smoke(main)
	_run_central_smoke(main)
	_run_steel_smoke(main)
	print("Smoke test complete.")
	quit(0)

func _run_coal_smoke(main: Node) -> void:
	main.start_scenario("coal_valley")
	for x in range(2, 12):
		main._place_track(Vector2i(x, 4))
	main._place_signal(Vector2i(4, 4), "block")
	main._place_signal(Vector2i(8, 4), "block")
	main._buy_train()
	for i in range(900):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Coal Valley should clear on a connected route.")

func _run_central_smoke(main: Node) -> void:
	main.start_scenario("central_yard")
	for p in main.local["scenario"]["ghost"]:
		main._place_track(p)
	main._place_signal(Vector2i(6, 3), "chain")
	main._place_signal(Vector2i(7, 5), "chain")
	main._place_signal(Vector2i(8, 4), "block")
	main._place_signal(Vector2i(10, 4), "block")
	main._buy_train()
	main._buy_train()
	for i in range(3600):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Central Yard should clear with both approaches connected.")

func _run_steel_smoke(main: Node) -> void:
	main.start_scenario("steelworks")
	for p in main.local["scenario"]["ghost"]:
		main._place_track(p)
	main._place_signal(Vector2i(5, 5), "block")
	main._place_signal(Vector2i(8, 4), "chain")
	main._buy_train()
	for i in range(1200):
		if main.screen != main.Screen.LOCAL:
			break
		main._update_local(0.1)
	_require(main.screen == main.Screen.RESULTS, "Steelworks should clear on a connected route.")

func _require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
