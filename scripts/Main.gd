extends Control

enum Screen { REGIONAL, LOCAL, RESULTS }

const SAVE_PATH := "user://trains_campaign.json"
const CELL := 48.0
const GRID_ORIGIN := Vector2(64, 132)
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var screen: int = Screen.REGIONAL
var scenarios: Array = []
var campaign := {
	"money": 1500,
	"materials": 4,
	"traffic_load": 18,
	"traffic_capacity": 40,
	"completed": []
}

var art_texture: Texture2D
var ui_panel_texture: Texture2D
var ui_button_texture: Texture2D
var ui_button_hover_texture: Texture2D
var ui_button_pressed_texture: Texture2D
var ui_button_selected_texture: Texture2D
var ui_hud_texture: Texture2D
var game_track_texture: Texture2D
var game_train_texture: Texture2D
var game_station_texture: Texture2D
var game_steelworks_texture: Texture2D
var game_signal_texture: Texture2D
var game_regional_node_texture: Texture2D
var font: Font
var font_size := 15
var hud_bar: HBoxContainer
var tool_bar: HBoxContainer
var side_panel: PanelContainer
var side_text: RichTextLabel
var top_status: Label
var tool_buttons: Dictionary = {}
var selected_tool := "track"
var selected_train_id := ""
var selected_signal_pos := Vector2i(-999, -999)
var dragging := false
var last_drag_cell := Vector2i(-999, -999)
var cell_size := CELL
var grid_origin := GRID_ORIGIN

var local := {}
var tracks: Dictionary = {}
var signals: Dictionary = {}
var station_by_id: Dictionary = {}
var station_by_pos: Dictionary = {}
var blocks: Dictionary = {}
var block_for_tile: Dictionary = {}
var trains: Array = []
var train_seq := 1
var local_message := ""
var result_data := {}
var elapsed_since_progress := 0.0
var last_progress_count := 0
var deadlock_cooldown := 0.0

func _ready() -> void:
	font = get_theme_default_font()
	art_texture = load("res://assets/generated/rail_miniatures.png")
	if art_texture == null:
		var art_image := Image.load_from_file("res://assets/generated/rail_miniatures.png")
		if art_image:
			art_texture = ImageTexture.create_from_image(art_image)
	_load_ui_skin()
	_define_scenarios()
	_load_campaign()
	rebuild_ui()
	queue_redraw()

func _load_ui_skin() -> void:
	ui_panel_texture = _load_texture("res://assets/generated/ui/ui_panel.png")
	ui_button_texture = _load_texture("res://assets/generated/ui/ui_button_normal.png")
	ui_button_hover_texture = _load_texture("res://assets/generated/ui/ui_button_hover.png")
	ui_button_pressed_texture = _load_texture("res://assets/generated/ui/ui_button_pressed.png")
	ui_button_selected_texture = _load_texture("res://assets/generated/ui/ui_button_selected.png")
	ui_hud_texture = _load_texture("res://assets/generated/ui/ui_hud_bar.png")
	game_track_texture = _load_texture("res://assets/generated/game/track.png")
	game_train_texture = _load_texture("res://assets/generated/game/train.png")
	game_station_texture = _load_texture("res://assets/generated/game/station.png")
	game_steelworks_texture = _load_texture("res://assets/generated/game/steelworks.png")
	game_signal_texture = _load_texture("res://assets/generated/game/signal.png")
	game_regional_node_texture = _load_texture("res://assets/generated/game/regional_node.png")

func _load_texture(path: String) -> Texture2D:
	var texture: Texture2D = load(path)
	if texture:
		return texture
	var image := Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	return null

func _texture_style(texture: Texture2D, margins: Vector4, content: Vector4 = Vector4(18, 10, 18, 10)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style

func _flat_style(bg: Color, border: Color = Color.html("#172028"), border_width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	return style

func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _flat_style(Color(1.0, 0.94, 0.72, 0.96), Color.html("#172028"), 3, 8))

func _style_button(button: Button, selected: bool = false) -> void:
	var base := Color.html("#20414c") if not selected else Color.html("#ffd96b")
	var hover := Color.html("#2e5964") if not selected else Color.html("#ffe58f")
	var pressed := Color.html("#ffeec0")
	var border := Color.html("#10242d")
	button.add_theme_stylebox_override("normal", _flat_style(base, border, 2, 6))
	button.add_theme_stylebox_override("hover", _flat_style(hover, border, 2, 6))
	button.add_theme_stylebox_override("pressed", _flat_style(pressed, border, 2, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color.html("#172028") if selected else Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.html("#172028") if selected else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.html("#172028"))
	button.add_theme_color_override("font_focus_color", Color.html("#172028") if selected else Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)

func _refresh_tool_button_styles() -> void:
	for tool in tool_buttons.keys():
		var button: Button = tool_buttons[tool]
		_style_button(button, tool == selected_tool)

func _add_backplate(texture: Texture2D, preset: int, offsets: Vector4, _margins: Vector4, modulate_color: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.modulate = modulate_color
	rect.z_index = 20
	rect.z_as_relative = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(preset)
	rect.offset_left = offsets.x
	rect.offset_top = offsets.y
	rect.offset_right = offsets.z
	rect.offset_bottom = offsets.w
	add_child(rect)
	return rect

func _process(delta: float) -> void:
	if screen != Screen.LOCAL:
		return
	if local.get("paused", true):
		return
	var step := delta * float(local.get("speed", 1.0))
	_update_local(step)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if screen == Screen.REGIONAL and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_regional_click(mb.position)
		elif screen == Screen.LOCAL:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				dragging = mb.pressed
				if mb.pressed:
					_handle_local_click(mb.position)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				if selected_tool == "train":
					_select_tool("track")
					local_message = "Buy Train canceled. Track tool selected."
					_refresh_local_side_text()
					return
				var old_tool := selected_tool
				selected_tool = "erase"
				_handle_local_click(mb.position)
				selected_tool = old_tool
	if event is InputEventKey and screen == Screen.LOCAL:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and selected_tool == "train":
			_select_tool("track")
			local_message = "Buy Train canceled. Track tool selected."
			_refresh_local_side_text()
	if event is InputEventMouseMotion and screen == Screen.LOCAL and dragging:
		if selected_tool in ["track", "erase"]:
			_handle_local_click((event as InputEventMouseMotion).position)

func _define_scenarios() -> void:
	scenarios = [
		{
			"id": "coal_valley",
			"name": "Coal Valley",
			"purpose": "Teach basic track placement, cargo routing, block signals, and passing loops.",
			"objective": "Deliver 80 coal to Interchange. Keep average train wait below 40s.",
			"briefing": "Demand: move coal from Coal Mine to Interchange.\nBuild one continuous route, then buy a train and start time.\nAdd block signals or a passing loop if trains begin waiting.",
			"start_message": "Build Coal Mine -> Interchange, buy one train, then press Pause to run.",
			"target": 80,
			"cargo": "coal",
			"kind": "coal",
			"start_budget": 1500,
			"grid": Vector2i(14, 9),
			"route": ["coal_mine", "interchange"],
			"stations": [
				{"id": "coal_mine", "name": "Coal Mine", "pos": Vector2i(1, 4), "role": "source", "produces": "coal", "accepts": [], "platforms": 1},
				{"id": "interchange", "name": "Interchange", "pos": Vector2i(12, 4), "role": "sink", "produces": "", "accepts": ["coal"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4)],
			"reward_money": 500,
			"reward_materials": 0,
			"reward_load": 8,
			"reward_capacity": 0,
			"wait_target": 40.0
		},
		{
			"id": "central_yard",
			"name": "Central Yard",
			"purpose": "Teach junction congestion, holding sidings, platforms, and chain signals.",
			"objective": "Process 20 freight trains through Central Yard.",
			"briefing": "Demand: freight must exit at East Line.\nBuild BOTH routes:\n1. West Line -> Central Yard -> East Line\n2. South Line -> Central Yard -> East Line\nBuy two trains. Use chain signals before the yard junction and block signals after exits.",
			"start_message": "Build the west and south approaches into Central Yard, then connect Central Yard to East Line. The first train uses West Line; the second uses South Line.",
			"target": 20,
			"cargo": "mixed freight",
			"kind": "yard",
			"start_budget": 1850,
			"grid": Vector2i(14, 9),
			"route": ["west_line", "central_yard", "east_line"],
			"alt_route": ["south_line", "central_yard", "east_line"],
			"stations": [
				{"id": "west_line", "name": "West Line", "pos": Vector2i(1, 3), "role": "source", "produces": "freight", "accepts": [], "platforms": 1},
				{"id": "south_line", "name": "South Line", "pos": Vector2i(4, 7), "role": "source", "produces": "freight", "accepts": [], "platforms": 1},
				{"id": "central_yard", "name": "Central Yard", "pos": Vector2i(7, 4), "role": "yard", "produces": "", "accepts": ["freight"], "platforms": 1},
				{"id": "east_line", "name": "East Line", "pos": Vector2i(12, 4), "role": "sink", "produces": "", "accepts": ["freight"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(4, 7), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(7, 5), Vector2i(7, 4)],
			"reward_money": 0,
			"reward_materials": 0,
			"reward_load": 0,
			"reward_capacity": 20,
			"wait_target": 45.0
		},
		{
			"id": "steelworks",
			"name": "Steelworks",
			"purpose": "Teach a simple coal-to-steel cargo chain and mixed freight flow.",
			"objective": "Produce and export 40 steel. Keep average train wait below 35s.",
			"briefing": "Demand: Coal Input feeds Steelworks; Steelworks exports steel to Export Platform.\nBuild Coal Input -> Steelworks -> Export Platform and buy one train.",
			"start_message": "Connect Coal Input to Steelworks and Export Platform, buy a train, then run the steel route.",
			"target": 40,
			"cargo": "steel",
			"kind": "steel",
			"start_budget": 2100,
			"grid": Vector2i(14, 9),
			"route": ["coal_input", "steelworks", "export_platform", "coal_input"],
			"stations": [
				{"id": "coal_input", "name": "Coal Input", "pos": Vector2i(1, 5), "role": "source", "produces": "coal", "accepts": [], "platforms": 1},
				{"id": "steelworks", "name": "Steelworks", "pos": Vector2i(7, 4), "role": "processor", "produces": "steel", "accepts": ["coal"], "platforms": 1},
				{"id": "export_platform", "name": "Export Platform", "pos": Vector2i(12, 4), "role": "sink", "produces": "", "accepts": ["steel"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4)],
			"reward_money": 300,
			"reward_materials": 3,
			"reward_load": 10,
			"reward_capacity": 0,
			"wait_target": 35.0
		}
	]

func rebuild_ui() -> void:
	for child in get_children():
		child.queue_free()
	tool_buttons.clear()
	_add_backplate(ui_hud_texture, Control.PRESET_TOP_WIDE, Vector4(6, 2, -6, 48), Vector4(220, 110, 220, 100), Color(1, 1, 1, 0.94))
	top_status = Label.new()
	top_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_status.offset_left = 80
	top_status.offset_top = 13
	top_status.offset_right = -64
	top_status.offset_bottom = 42
	top_status.add_theme_font_size_override("font_size", 18)
	top_status.add_theme_color_override("font_color", Color.html("#172028"))
	top_status.add_theme_color_override("font_shadow_color", Color(1, 0.93, 0.72, 0.72))
	top_status.add_theme_color_override("font_outline_color", Color(1, 0.94, 0.74, 0.75))
	top_status.add_theme_constant_override("outline_size", 2)
	top_status.z_index = 30
	top_status.z_as_relative = false
	top_status.add_theme_constant_override("shadow_offset_x", 1)
	top_status.add_theme_constant_override("shadow_offset_y", 1)
	add_child(top_status)

	if screen == Screen.REGIONAL:
		_build_regional_ui()
	elif screen == Screen.LOCAL:
		_build_local_ui()
	else:
		_build_results_ui()
	_update_status_labels()

func _build_regional_ui() -> void:
	_add_backplate(ui_panel_texture, Control.PRESET_TOP_LEFT, Vector4(32, 54, 760, 162), Vector4(160, 120, 160, 120), Color(1, 1, 1, 0.96))
	var title := Label.new()
	title.text = "TrainsTrainsTrains"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.html("#172028"))
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 84
	title.offset_top = 64
	title.offset_right = 520
	title.offset_bottom = 112
	add_child(title)

	var hint := Label.new()
	hint.text = "Pick an available local contract. Completed nodes feed the regional network."
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color.html("#28363f"))
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.offset_left = 86
	hint.offset_top = 112
	hint.offset_right = 740
	hint.offset_bottom = 146
	add_child(hint)

	side_panel = PanelContainer.new()
	_style_panel(side_panel)
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -360
	side_panel.offset_top = 64
	side_panel.offset_right = -10
	side_panel.offset_bottom = -16
	side_panel.z_index = 30
	side_panel.z_as_relative = false
	add_child(side_panel)
	side_text = RichTextLabel.new()
	side_text.fit_content = true
	side_text.scroll_active = false
	side_text.bbcode_enabled = true
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", 16)
	side_text.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.78, 0.55))
	side_text.add_theme_constant_override("outline_size", 1)
	side_panel.add_child(side_text)
	_refresh_regional_side_text()

func _build_local_ui() -> void:
	_add_backplate(ui_hud_texture, Control.PRESET_TOP_WIDE, Vector4(4, 42, -4, 188), Vector4(220, 110, 220, 100), Color(1, 1, 1, 0.92))
	hud_bar = HBoxContainer.new()
	hud_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_bar.offset_left = 18
	hud_bar.offset_top = 52
	hud_bar.offset_right = -18
	hud_bar.offset_bottom = 106
	hud_bar.add_theme_constant_override("separation", 10)
	hud_bar.z_index = 30
	hud_bar.z_as_relative = false
	add_child(hud_bar)

	_add_button(hud_bar, "Pause", func(): _toggle_pause())
	_add_button(hud_bar, "1x/2x", func(): _toggle_speed())
	_add_button(hud_bar, "Region", func(): _return_to_region())

	tool_bar = HBoxContainer.new()
	tool_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tool_bar.offset_left = 20
	tool_bar.offset_top = 116
	tool_bar.offset_right = -20
	tool_bar.offset_bottom = 180
	tool_bar.add_theme_constant_override("separation", 6)
	tool_bar.z_index = 30
	tool_bar.z_as_relative = false
	add_child(tool_bar)

	_add_tool_button("Track\n$25", "track")
	_add_tool_button("Erase", "erase")
	_add_tool_button("Block\n$80", "block")
	_add_tool_button("Chain\n$120", "chain")
	_add_button(tool_bar, "Loop\n$250", func(): _build_passing_loop())
	_add_button(tool_bar, "Platform\n$200", func(): _add_platform())
	_add_tool_button("Buy\nTrain", "train")
	_add_button(tool_bar, "Restart", func(): start_scenario(local.get("id", "coal_valley")))

	side_panel = PanelContainer.new()
	_style_panel(side_panel)
	side_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side_panel.offset_left = -430
	side_panel.offset_top = 112
	side_panel.offset_right = -12
	side_panel.offset_bottom = 430
	side_panel.z_index = 30
	side_panel.z_as_relative = false
	add_child(side_panel)
	side_text = RichTextLabel.new()
	side_text.bbcode_enabled = true
	side_text.scroll_active = true
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", 17)
	side_text.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.78, 0.55))
	side_text.add_theme_constant_override("outline_size", 1)
	side_panel.add_child(side_text)
	_refresh_local_side_text()

func _build_results_ui() -> void:
	_add_backplate(ui_panel_texture, Control.PRESET_CENTER, Vector4(-345, -235, 345, 245), Vector4(180, 130, 180, 130), Color(1, 1, 1, 0.96))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -265
	box.offset_top = -154
	box.offset_right = 265
	box.offset_bottom = 196
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "%s Complete" % result_data.get("name", "Scenario")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.html("#172028"))
	box.add_child(title)

	var details := RichTextLabel.new()
	details.custom_minimum_size = Vector2(600, 240)
	details.bbcode_enabled = true
	details.scroll_active = false
	details.add_theme_color_override("default_color", Color.html("#172028"))
	details.text = result_data.get("text", "")
	box.add_child(details)
	_add_button(box, "Continue to Regional Map", func(): _return_to_region())
	_add_button(box, "Replay Scenario", func(): start_scenario(result_data.get("id", "coal_valley")))

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(124, 66)
	_style_button(b)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _add_tool_button(text: String, tool: String) -> void:
	var button := _add_button(tool_bar, text, func(): _select_tool(tool))
	tool_buttons[tool] = button
	_refresh_tool_button_styles()

func _select_tool(tool: String) -> void:
	selected_tool = tool
	if selected_tool == "train":
		local_message = "Buy Train selected. Click a green source station to choose where the train starts."
	elif selected_tool == "block":
		local_message = "Block signal selected. Place it on straight exits to split track into clear sections."
	elif selected_tool == "chain":
		local_message = "Chain signal selected. Place it before junctions so trains wait until the exit path is clear."
	else:
		local_message = "Tool selected: %s" % tool.capitalize()
	_refresh_tool_button_styles()
	_update_status_labels()
	_refresh_local_side_text()
	queue_redraw()

func _toggle_pause() -> void:
	local["paused"] = !local.get("paused", true)
	local_message = "Simulation paused." if local["paused"] else "Trains are running."
	_refresh_local_side_text()

func _toggle_speed() -> void:
	local["speed"] = 2.0 if float(local.get("speed", 1.0)) < 2.0 else 1.0
	local_message = "Simulation speed: %sx" % int(local["speed"])
	_refresh_local_side_text()

func _return_to_region() -> void:
	screen = Screen.REGIONAL
	rebuild_ui()
	queue_redraw()

func _handle_regional_click(pos: Vector2) -> void:
	for s in scenarios:
		var node_pos: Vector2 = _regional_node_position(s["id"])
		if pos.distance_to(node_pos) <= 54.0:
			if _scenario_is_available(s["id"]):
				start_scenario(s["id"])
			return

func start_scenario(id: String) -> void:
	var scenario := _get_scenario(id)
	if scenario.is_empty():
		return
	screen = Screen.LOCAL
	selected_tool = "track"
	selected_train_id = ""
	selected_signal_pos = Vector2i(-999, -999)
	tracks.clear()
	signals.clear()
	station_by_id.clear()
	station_by_pos.clear()
	blocks.clear()
	block_for_tile.clear()
	trains.clear()
	train_seq = 1
	elapsed_since_progress = 0.0
	last_progress_count = 0
	deadlock_cooldown = 0.0
	local = {
		"id": scenario["id"],
		"name": scenario["name"],
		"kind": scenario["kind"],
		"objective": scenario["objective"],
		"target": scenario["target"],
		"wait_target": scenario["wait_target"],
		"money": int(scenario["start_budget"]) + int(campaign["materials"]) * 25,
		"materials": int(campaign["materials"]),
		"delivered": 0,
		"processed": 0,
		"steel_buffer": 0,
		"coal_buffer": 0,
		"production_remainder": 0.0,
		"storage": {},
		"infra_cost": 0,
		"deadlocks": 0,
		"max_queue": 0,
		"paused": true,
		"speed": 1.0,
		"route_toggle": false,
		"scenario": scenario
	}
	for st in scenario["stations"]:
		var copy: Dictionary = st.duplicate(true)
		copy["stored"] = 240 if copy.get("role", "") == "source" else 0
		station_by_id[copy["id"]] = copy
		station_by_pos[copy["pos"]] = copy["id"]
		tracks[copy["pos"]] = true
	_compute_blocks()
	local_message = scenario.get("start_message", "Start paused. Build track between stations, place signals, buy trains, then press Pause.")
	rebuild_ui()
	queue_redraw()

func _get_scenario(id: String) -> Dictionary:
	for s in scenarios:
		if s["id"] == id:
			return s
	return {}

func _scenario_is_available(id: String) -> bool:
	if id == "coal_valley":
		return true
	if id == "central_yard":
		return campaign["completed"].has("coal_valley")
	if id == "steelworks":
		return campaign["completed"].has("central_yard")
	return false

func _regional_node_position(id: String) -> Vector2:
	var y := size.y * 0.52
	if id == "coal_valley":
		return Vector2(size.x * 0.22, y)
	if id == "central_yard":
		return Vector2(size.x * 0.48, y)
	return Vector2(size.x * 0.74, y)

func _update_board_layout() -> void:
	if local.is_empty() or not local.has("scenario"):
		cell_size = CELL
		grid_origin = GRID_ORIGIN
		return
	var grid: Vector2i = local["scenario"].get("grid", Vector2i(14, 9))
	var top_reserved := 190.0
	var bottom_reserved := 28.0
	var horizontal_margin := 36.0
	var briefing_width := 470.0 if max(size.x, 640.0) >= 1024.0 else 0.0
	var briefing_gap := 18.0 if briefing_width > 0.0 else 0.0
	var max_cell_from_width: float = (max(size.x, 640.0) - horizontal_margin * 2.0 - briefing_width - briefing_gap) / float(grid.x)
	var max_cell_from_height: float = (max(size.y, 480.0) - top_reserved - bottom_reserved) / float(grid.y)
	cell_size = clamp(floor(min(max_cell_from_width, max_cell_from_height)), 48.0, 50.0)
	grid_origin = Vector2(horizontal_margin, top_reserved)

func _handle_local_click(pos: Vector2) -> void:
	var hit_train := _hit_train_id(pos)
	if hit_train != "":
		selected_train_id = hit_train
		selected_signal_pos = Vector2i(-999, -999)
		dragging = false
		_refresh_local_side_text()
		queue_redraw()
		return
	var hit_signal := _hit_signal_pos(pos)
	if hit_signal.x > -900 and selected_tool != "block" and selected_tool != "chain":
		selected_signal_pos = hit_signal
		selected_train_id = ""
		dragging = false
		_refresh_local_side_text()
		queue_redraw()
		return
	var gp := _screen_to_grid(pos)
	if not _is_in_grid(gp):
		_select_train_or_signal(pos)
		return
	if gp == last_drag_cell and selected_tool in ["track", "erase"]:
		return
	last_drag_cell = gp
	if selected_tool == "track":
		_place_track(gp)
	elif selected_tool == "erase":
		_erase_track(gp)
	elif selected_tool == "block":
		_place_signal(gp, "block")
	elif selected_tool == "chain":
		_place_signal(gp, "chain")
	elif selected_tool == "train":
		_buy_train_at(gp)
	_refresh_local_side_text()
	queue_redraw()

func _select_train_or_signal(pos: Vector2) -> void:
	selected_train_id = ""
	selected_signal_pos = Vector2i(-999, -999)
	selected_train_id = _hit_train_id(pos)
	if selected_train_id != "":
		_refresh_local_side_text()
		return
	selected_signal_pos = _hit_signal_pos(pos)
	if selected_signal_pos.x > -900:
		_refresh_local_side_text()
		return
	_refresh_local_side_text()

func _hit_train_id(pos: Vector2) -> String:
	_update_board_layout()
	for t in trains:
		if (t["pos"] as Vector2).distance_to(pos) < max(24.0, cell_size * 0.42):
			return t["id"]
	return ""

func _hit_signal_pos(pos: Vector2) -> Vector2i:
	_update_board_layout()
	for sig_pos in signals.keys():
		if _grid_to_screen(sig_pos).distance_to(pos) < max(24.0, cell_size * 0.42):
			return sig_pos
	return Vector2i(-999, -999)

func _place_track(gp: Vector2i) -> void:
	if not tracks.has(gp):
		if _spend(25, 0):
			tracks[gp] = true
			local["infra_cost"] += 25
			local_message = "Track placed. Drag to draw connected rail."
			_compute_blocks()

func _erase_track(gp: Vector2i) -> void:
	if station_by_pos.has(gp):
		local_message = "Stations are fixed contract points."
		return
	if _tile_has_train(gp, ""):
		local_message = "Cannot erase track occupied by a train."
		return
	if tracks.erase(gp):
		signals.erase(gp)
		local_message = "Track removed."
		_compute_blocks()

func _place_signal(gp: Vector2i, signal_type: String) -> void:
	if not tracks.has(gp):
		local_message = "Signals need track."
		return
	var material_cost := 1 if signal_type == "chain" else 0
	var money_cost := 120 if signal_type == "chain" else 80
	if signals.has(gp):
		signals[gp] = signal_type
		local_message = "Signal changed to %s." % signal_type
		_compute_blocks()
		return
	if _spend(money_cost, material_cost):
		signals[gp] = signal_type
		local["infra_cost"] += money_cost
		local_message = "%s signal placed. Signals split blocks and explain waits." % signal_type.capitalize()
		_compute_blocks()

func _build_passing_loop() -> void:
	var sc: Dictionary = local["scenario"]
	var mid := Vector2i(6, 4)
	if local.get("id", "") == "central_yard":
		mid = Vector2i(6, 5)
	elif local.get("id", "") == "steelworks":
		mid = Vector2i(5, 4)
	if not _spend(250, 0):
		return
	local["infra_cost"] += 250
	var loop_tiles := [mid + Vector2i(-1, -1), mid + Vector2i(0, -1), mid + Vector2i(1, -1), mid + Vector2i(-1, 0), mid, mid + Vector2i(1, 0)]
	for p in loop_tiles:
		if _is_in_grid(p):
			tracks[p] = true
	signals[mid + Vector2i(-1, 0)] = "block"
	signals[mid + Vector2i(1, -1)] = "block"
	local_message = "Passing loop added. It gives opposing trains a place to clear the main line."
	_compute_blocks()
	_refresh_local_side_text()
	queue_redraw()

func _add_platform() -> void:
	var target_id := "central_yard" if local.get("id", "") == "central_yard" else ""
	if target_id == "":
		for id in station_by_id.keys():
			if station_by_id[id].get("role", "") in ["sink", "processor"]:
				target_id = id
				break
	if target_id == "" or not _spend(200, 1):
		return
	station_by_id[target_id]["platforms"] = int(station_by_id[target_id].get("platforms", 1)) + 1
	local["infra_cost"] += 200
	local_message = "%s now has %d platforms." % [station_by_id[target_id]["name"], station_by_id[target_id]["platforms"]]
	_refresh_local_side_text()

func _buy_train_at(gp: Vector2i) -> void:
	if not station_by_pos.has(gp):
		local_message = "Click a green source station to buy a train there."
		return
	var station_id: String = station_by_pos[gp]
	var st: Dictionary = station_by_id[station_id]
	if st.get("role", "") != "source":
		local_message = "Trains must be bought at a source station, not at %s." % st.get("name", "that station")
		return
	_buy_train_for_source(station_id)

func _route_for_source(source_id: String) -> Array:
	var sc: Dictionary = local["scenario"]
	if sc.has("route") and sc["route"].size() > 0 and sc["route"][0] == source_id:
		return sc["route"].duplicate()
	if sc.has("alt_route") and sc["alt_route"].size() > 0 and sc["alt_route"][0] == source_id:
		return sc["alt_route"].duplicate()
	return []

func _buy_train() -> void:
	var sc: Dictionary = local["scenario"]
	var source_id: String = sc["route"][0]
	if local.get("id", "") == "central_yard" and local.get("route_toggle", false) and sc.has("alt_route"):
		source_id = sc["alt_route"][0]
	local["route_toggle"] = !local.get("route_toggle", false)
	_buy_train_for_source(source_id)

func _buy_train_for_source(source_id: String) -> void:
	var route := _route_for_source(source_id)
	if route.is_empty():
		local_message = "No route starts at that source station."
		return
	if not _spend(300, 0):
		return
	var start_station: Dictionary = station_by_id[route[0]]
	var start_pos: Vector2i = start_station["pos"]
	var t := {
		"id": "T%02d" % train_seq,
		"name": "Train %02d" % train_seq,
		"route": route,
		"stop_index": 1,
		"tile": start_pos,
		"pos": _grid_to_screen(start_pos),
		"path": [],
		"path_index": 0,
		"cargo": "",
		"cargo_amount": 0,
		"capacity": 40,
		"speed": 150.0,
		"dir": Vector2.RIGHT,
		"state": "Idle",
		"wait_reason": "",
		"wait_time": 0.0,
		"total_wait": 0.0,
		"dwell": 0.0,
		"handled_yard": false
	}
	_process_cargo_at_station(t, start_station)
	train_seq += 1
	trains.append(t)
	local["infra_cost"] += 300
	_plan_next_path(t)
	local_message = "%s bought at %s. Route: %s." % [t["name"], start_station["name"], " -> ".join(route)]
	selected_tool = "track"
	_refresh_tool_button_styles()
	_update_status_labels()
	_refresh_local_side_text()

func _spend(money: int, materials: int) -> bool:
	if int(local.get("money", 0)) < money:
		local_message = "Not enough money."
		return false
	if int(local.get("materials", 0)) < materials:
		local_message = "Not enough materials."
		return false
	local["money"] = int(local["money"]) - money
	local["materials"] = int(local["materials"]) - materials
	return true

func _update_local(delta: float) -> void:
	_generate_station_cargo(delta)
	_compute_blocks()
	var progress_before := _objective_progress()
	for t in trains:
		_update_train(t, delta)
	var progress_after := _objective_progress()
	if progress_after > progress_before:
		elapsed_since_progress = 0.0
	else:
		elapsed_since_progress += delta
	_detect_congestion(delta)
	_update_status_labels()
	_refresh_local_side_text()
	if _objective_progress() >= int(local["target"]):
		_complete_scenario()

func _generate_station_cargo(delta: float) -> void:
	local["production_remainder"] = float(local.get("production_remainder", 0.0)) + delta * 8.0
	var produced := int(local["production_remainder"])
	if produced <= 0:
		return
	local["production_remainder"] = float(local["production_remainder"]) - float(produced)
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		if st.get("role", "") == "source":
			st["stored"] = min(240, int(st.get("stored", 0)) + produced)

func _update_train(t: Dictionary, delta: float) -> void:
	if float(t.get("dwell", 0.0)) > 0.0:
		t["dwell"] = max(0.0, float(t["dwell"]) - delta)
		t["state"] = "Loading" if t.get("cargo_amount", 0) == 0 else "Unloading"
		return
	if (t["path"] as Array).is_empty() or int(t["path_index"]) >= (t["path"] as Array).size():
		_handle_station_arrival(t)
		return
	var next_tile: Vector2i = t["path"][int(t["path_index"])]
	var allowed := _can_enter_next_tile(t, next_tile)
	if not allowed:
		t["wait_time"] = float(t["wait_time"]) + delta
		t["total_wait"] = float(t["total_wait"]) + delta
		return
	t["wait_time"] = 0.0
	t["wait_reason"] = ""
	t["state"] = "Moving"
	var target := _grid_to_screen(next_tile)
	var pos: Vector2 = t["pos"]
	var dist := pos.distance_to(target)
	var step := float(t["speed"]) * delta
	if step >= dist:
		t["pos"] = target
		t["tile"] = next_tile
		t["path_index"] = int(t["path_index"]) + 1
	else:
		t["pos"] = pos.move_toward(target, step)

func _handle_station_arrival(t: Dictionary) -> void:
	var tile: Vector2i = t["tile"]
	if station_by_pos.has(tile):
		var st_id: String = station_by_pos[tile]
		var st: Dictionary = station_by_id[st_id]
		_process_cargo_at_station(t, st)
		if t.get("reset_to_source", false):
			var source_station: Dictionary = station_by_id[t["route"][0]]
			t["tile"] = source_station["pos"]
			t["pos"] = _grid_to_screen(source_station["pos"])
			t["path"] = []
			t["path_index"] = 0
			t["stop_index"] = 1
			t["reset_to_source"] = false
			t["handled_yard"] = false
			_process_cargo_at_station(t, source_station)
			_plan_next_path(t)
			return
		t["dwell"] = 0.8
		t["state"] = "Loading" if t.get("cargo_amount", 0) == 0 else "Unloading"
		t["handled_yard"] = false
		t["stop_index"] = (int(t["stop_index"]) + 1) % (t["route"] as Array).size()
	_plan_next_path(t)

func _process_cargo_at_station(t: Dictionary, st: Dictionary) -> void:
	var kind: String = local.get("kind", "")
	if kind == "coal":
		if st.get("role", "") == "source" and int(t["cargo_amount"]) == 0:
			var amount: int = min(int(t["capacity"]), int(st.get("stored", 0)))
			st["stored"] = int(st.get("stored", 0)) - amount
			t["cargo"] = "coal"
			t["cargo_amount"] = amount
		elif st.get("role", "") == "sink" and t.get("cargo", "") == "coal":
			local["delivered"] = int(local["delivered"]) + int(t["cargo_amount"])
			t["cargo_amount"] = 0
			t["cargo"] = ""
	elif kind == "yard":
		if st.get("role", "") == "source" and int(t["cargo_amount"]) == 0:
			t["cargo"] = "freight"
			t["cargo_amount"] = min(int(t["capacity"]), 10)
		elif st.get("role", "") == "yard":
			t["dwell"] = max(float(t.get("dwell", 0.0)), 1.2 / max(1, int(st.get("platforms", 1))))
		elif st.get("role", "") == "sink" and t.get("cargo", "") == "freight":
			local["processed"] = int(local["processed"]) + max(1, int(floor(float(t.get("cargo_amount", 0)) / 10.0)))
			t["cargo_amount"] = 0
			t["cargo"] = ""
			t["reset_to_source"] = true
	elif kind == "steel":
		if st["id"] == "coal_input" and int(t["cargo_amount"]) == 0:
			var coal = min(int(t["capacity"]), int(st.get("stored", 0)))
			st["stored"] = int(st.get("stored", 0)) - coal
			t["cargo"] = "coal"
			t["cargo_amount"] = coal
		elif st["id"] == "steelworks":
			if t.get("cargo", "") == "coal":
				local["coal_buffer"] = int(local["coal_buffer"]) + int(t["cargo_amount"])
				local["steel_buffer"] = int(local["steel_buffer"]) + int(int(t["cargo_amount"]) / 2)
				t["cargo"] = ""
				t["cargo_amount"] = 0
			if int(t["cargo_amount"]) == 0 and int(local.get("steel_buffer", 0)) > 0:
				var steel = min(int(t["capacity"]), int(local["steel_buffer"]))
				local["steel_buffer"] = int(local["steel_buffer"]) - steel
				t["cargo"] = "steel"
				t["cargo_amount"] = steel
		elif st["id"] == "export_platform" and t.get("cargo", "") == "steel":
			local["delivered"] = int(local["delivered"]) + int(t["cargo_amount"])
			t["cargo"] = ""
			t["cargo_amount"] = 0

func _plan_next_path(t: Dictionary) -> void:
	var route: Array = t["route"]
	if route.is_empty():
		return
	var target_station: Dictionary = station_by_id[route[int(t["stop_index"])]]
	var path := _find_path(t["tile"], target_station["pos"])
	if path.is_empty():
		t["state"] = "NoRoute"
		t["wait_reason"] = "No valid route exists. Build connected track between route stations."
	else:
		t["path"] = path
		t["path_index"] = 0
		t["state"] = "Idle"

func _find_path(start: Vector2i, goal: Vector2i) -> Array:
	if not tracks.has(start) or not tracks.has(goal):
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for n in _track_neighbors(current):
			if not came_from.has(n):
				came_from[n] = current
				frontier.append(n)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var p := goal
	while p != start:
		path.push_front(p)
		p = came_from[p]
	return path

func _can_enter_next_tile(t: Dictionary, next_tile: Vector2i) -> bool:
	var other := _tile_has_train(next_tile, t["id"])
	if other:
		t["state"] = "Blocked"
		t["wait_reason"] = "Next tile is occupied by %s." % other
		return false
	var cur: Vector2i = t["tile"]
	var direction := Vector2(next_tile - cur)
	if direction.length_squared() > 0.0:
		t["dir"] = direction.normalized()
	if signals.has(cur):
		var sig_type: String = signals[cur]
		if sig_type == "block":
			var b := int(block_for_tile.get(next_tile, -1))
			var blocker := _block_occupied_by_other(b, t["id"])
			if blocker != "":
				t["state"] = "WaitingAtSignal"
				t["wait_reason"] = "Next block is occupied by %s. Add a passing loop or split long blocks with signals." % blocker
				return false
		else:
			var chain_reason := _chain_signal_blocker(t)
			if chain_reason != "":
				t["state"] = "WaitingAtSignal"
				t["wait_reason"] = chain_reason
				return false
	return true

func _chain_signal_blocker(t: Dictionary) -> String:
	var checked_blocks := {}
	var path: Array = t["path"]
	for i in range(int(t["path_index"]), min(path.size(), int(t["path_index"]) + 7)):
		var p: Vector2i = path[i]
		var b := int(block_for_tile.get(p, -1))
		if not checked_blocks.has(b):
			checked_blocks[b] = true
			var blocker := _block_occupied_by_other(b, t["id"])
			if blocker != "":
				return "Chain signal is red: exit path is blocked by %s. Keep junction entries protected by chain signals." % blocker
		if i > int(t["path_index"]) and (signals.has(p) or station_by_pos.has(p)):
			break
	return ""

func _tile_has_train(tile: Vector2i, own_id: String) -> String:
	for t in trains:
		if t["id"] != own_id and t["tile"] == tile:
			return t["id"]
	return ""

func _block_occupied_by_other(block_id: int, own_id: String) -> String:
	if block_id < 0:
		return ""
	for t in trains:
		if t["id"] != own_id and int(block_for_tile.get(t["tile"], -2)) == block_id:
			return t["id"]
	return ""

func _detect_congestion(delta: float) -> void:
	var queue := 0
	for t in trains:
		if String(t.get("state", "")).begins_with("Waiting") or t.get("state", "") == "Blocked":
			queue += 1
	local["max_queue"] = max(int(local.get("max_queue", 0)), queue)
	deadlock_cooldown = max(0.0, deadlock_cooldown - delta)
	if queue >= 2 and elapsed_since_progress > 8.0 and deadlock_cooldown <= 0.0:
		local["deadlocks"] = int(local.get("deadlocks", 0)) + 1
		deadlock_cooldown = 10.0
		local_message = "Deadlock detected. Replace junction entry block signals with chain signals or add an exit path."

func _complete_scenario() -> void:
	var sc: Dictionary = local["scenario"]
	var avg_wait := _average_wait()
	var quality := "Clean run" if avg_wait <= float(local["wait_target"]) and int(local.get("deadlocks", 0)) == 0 else "Completed with reliability warnings"
	result_data = {
		"id": local["id"],
		"name": local["name"],
		"text": "[b]%s[/b]\n\nObjective Progress: %d / %d\nAverage Train Wait: %.1fs / %.0fs target\nDeadlocks: %d\nMaximum Queue: %d\nInfrastructure Cost: $%d\n\nRegional Effect:\n+$%d per cycle\n+%d Materials per cycle\n+%d Traffic Load\n+%d Traffic Capacity" % [
			quality,
			_objective_progress(),
			int(local["target"]),
			avg_wait,
			float(local["wait_target"]),
			int(local.get("deadlocks", 0)),
			int(local.get("max_queue", 0)),
			int(local.get("infra_cost", 0)),
			int(sc.get("reward_money", 0)),
			int(sc.get("reward_materials", 0)),
			int(sc.get("reward_load", 0)),
			int(sc.get("reward_capacity", 0))
		]
	}
	if not campaign["completed"].has(local["id"]):
		campaign["completed"].append(local["id"])
		campaign["money"] = int(campaign["money"]) + int(sc.get("reward_money", 0))
		campaign["materials"] = int(campaign["materials"]) + int(sc.get("reward_materials", 0))
		campaign["traffic_load"] = int(campaign["traffic_load"]) + int(sc.get("reward_load", 0))
		campaign["traffic_capacity"] = int(campaign["traffic_capacity"]) + int(sc.get("reward_capacity", 0))
		_save_campaign()
	screen = Screen.RESULTS
	rebuild_ui()
	queue_redraw()

func _objective_progress() -> int:
	if local.get("kind", "") == "yard":
		return int(local.get("processed", 0))
	return int(local.get("delivered", 0))

func _average_wait() -> float:
	if trains.is_empty():
		return 0.0
	var total := 0.0
	for t in trains:
		total += float(t.get("total_wait", 0.0))
	return total / float(trains.size())

func _compute_blocks() -> void:
	blocks.clear()
	block_for_tile.clear()
	var visited := {}
	var bid := 0
	for start in tracks.keys():
		if visited.has(start):
			continue
		var queue: Array[Vector2i] = [start]
		blocks[bid] = []
		while not queue.is_empty():
			var p: Vector2i = queue.pop_front()
			if visited.has(p):
				continue
			visited[p] = true
			block_for_tile[p] = bid
			blocks[bid].append(p)
			if signals.has(p) and p != start:
				continue
			for n in _track_neighbors(p):
				if not visited.has(n):
					queue.append(n)
		bid += 1

func _track_neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n := p + d
		if tracks.has(n):
			out.append(n)
	return out

func _screen_to_grid(p: Vector2) -> Vector2i:
	_update_board_layout()
	return Vector2i(int(floor((p.x - grid_origin.x) / cell_size)), int(floor((p.y - grid_origin.y) / cell_size)))

func _grid_to_screen(p: Vector2i) -> Vector2:
	_update_board_layout()
	return grid_origin + Vector2((float(p.x) + 0.5) * cell_size, (float(p.y) + 0.5) * cell_size)

func _is_in_grid(p: Vector2i) -> bool:
	var grid: Vector2i = local.get("scenario", {}).get("grid", Vector2i(14, 9))
	return p.x >= 0 and p.y >= 0 and p.x < grid.x and p.y < grid.y

func _update_status_labels() -> void:
	if top_status == null:
		return
	if screen == Screen.REGIONAL:
		var warning := "  Network Congested: income reduced" if int(campaign["traffic_load"]) > int(campaign["traffic_capacity"]) else ""
		top_status.text = "Money: $%d   Materials: %d   Traffic: %d / %d%s" % [campaign["money"], campaign["materials"], campaign["traffic_load"], campaign["traffic_capacity"], warning]
	elif screen == Screen.LOCAL:
		top_status.text = "%s   Money: $%d   Materials: %d   Progress: %d / %d   Avg Wait: %.1fs   Trains: %d   Tool: %s" % [
			local.get("name", ""),
			local.get("money", 0),
			local.get("materials", 0),
			_objective_progress(),
			local.get("target", 0),
			_average_wait(),
			trains.size(),
			selected_tool.capitalize()
		]
	else:
		top_status.text = "Scenario results"

func _refresh_regional_side_text() -> void:
	if side_text == null:
		return
	var lines := "[b]Regional Network[/b]\n\n"
	lines += "Completed local maps permanently add outputs to this small region.\n\n"
	for s in scenarios:
		var state := "Completed" if campaign["completed"].has(s["id"]) else ("Available" if _scenario_is_available(s["id"]) else "Locked")
		lines += "[b]%s[/b] - %s\n%s\n\n" % [s["name"], state, s["objective"]]
	if int(campaign["traffic_load"]) > int(campaign["traffic_capacity"]):
		lines += "[color=orange]Network Congested[/color]\nTraffic load exceeds capacity. Future maps begin under extra pressure.\n"
	side_text.text = lines

func _refresh_local_side_text() -> void:
	if side_text == null or screen != Screen.LOCAL:
		return
	var scenario: Dictionary = local.get("scenario", {})
	var text := "[b]%s[/b]\n%s\n\n" % [local.get("name", ""), local.get("objective", "")]
	if scenario.get("briefing", "") != "":
		text += "[b]Build Plan[/b]\n%s\n\n" % scenario["briefing"]
	text += "[b]Signal Guide[/b]\nBlock signal: lets a train enter the next block only when that block is empty. Use after stations, passing loops, and junction exits.\nChain signal: checks ahead through the junction and holds the train until the exit path is clear. Use before junctions and yards.\n\n"
	text += "[b]Message[/b]\n%s\n\n" % local_message
	text += "[b]Controls[/b]\nLeft click/drag builds. Right click erases. Click trains or signals for details.\n\n"
	if selected_train_id != "":
		for t in trains:
			if t["id"] == selected_train_id:
				text += "[b]%s[/b]\nState: %s\nCargo: %s %d/%d\nReason: %s\nSuggestion: %s\n\n" % [
					t["name"],
					t["state"],
					t.get("cargo", "none") if t.get("cargo", "") != "" else "none",
					t.get("cargo_amount", 0),
					t.get("capacity", 0),
					t.get("wait_reason", "Moving normally."),
					_suggestion_for_train(t)
				]
	if selected_signal_pos.x > -900:
		var bid := int(block_for_tile.get(selected_signal_pos, -1))
		text += "[b]Signal[/b]\nType: %s\nBlock: %s\nStatus: %s\n\n" % [signals.get(selected_signal_pos, "none"), bid, _signal_summary(selected_signal_pos)]
	text += "[b]Scenario Stats[/b]\nDeadlocks: %d\nMax Queue: %d\nInfrastructure Cost: $%d\n" % [local.get("deadlocks", 0), local.get("max_queue", 0), local.get("infra_cost", 0)]
	if local.get("kind", "") == "steel":
		text += "Steelworks buffer: %d steel\n" % int(local.get("steel_buffer", 0))
	side_text.text = text

func _suggestion_for_train(t: Dictionary) -> String:
	var reason := String(t.get("wait_reason", ""))
	if reason.contains("No valid route"):
		return "Connect every stop on the route with orthogonal track."
	if reason.contains("Chain"):
		return "Place chain signals before junctions and block signals at clear exits."
	if reason.contains("occupied"):
		return "Split the line into smaller blocks or add a passing loop."
	if reason.contains("tile"):
		return "Add siding space or reduce the number of trains."
	return "Keep cargo flowing and watch for red signals."

func _signal_summary(pos: Vector2i) -> String:
	var b := int(block_for_tile.get(pos, -1))
	var blocker := _block_occupied_by_other(b, "")
	if blocker == "":
		return "Green: adjacent block appears clear."
	return "Red: block occupied by %s." % blocker

func _draw() -> void:
	var bg := Color.html("#eaf6ec")
	if screen == Screen.LOCAL:
		bg = Color.html("#eef7e7")
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	if screen == Screen.REGIONAL:
		_draw_regional()
	elif screen == Screen.LOCAL:
		_draw_local()
	else:
		_draw_results_background()

func _draw_regional() -> void:
	if art_texture:
		draw_texture_rect(art_texture, Rect2(Vector2(size.x - 520, size.y - 500), Vector2(450, 450)), false, Color(1, 1, 1, 0.32))
	var ids := ["coal_valley", "central_yard", "steelworks"]
	for i in range(ids.size() - 1):
		_draw_piece(game_track_texture, (_regional_node_position(ids[i]) + _regional_node_position(ids[i + 1])) * 0.5, Vector2(330, 74), 0.0, Color(1, 1, 1, 0.72))
	for s in scenarios:
		var p := _regional_node_position(s["id"])
		var completed: bool = campaign["completed"].has(s["id"])
		var available: bool = _scenario_is_available(s["id"])
		var col: Color = Color.html("#78d891") if completed else (Color.html("#ffe06d") if available else Color.html("#a5afb4"))
		if not _draw_piece(game_regional_node_texture, p, Vector2(122, 122), 0.0, col):
			draw_circle(p, 54, col)
			draw_circle(p, 46, Color(1, 1, 1, 0.38))
		draw_string(font, p + Vector2(-64, 84), s["name"], HORIZONTAL_ALIGNMENT_CENTER, 128, 17, Color.html("#172028"))
		draw_string(font, p + Vector2(-48, 106), "Click" if available else ("Done" if completed else "Locked"), HORIZONTAL_ALIGNMENT_CENTER, 96, 14, Color.html("#172028"))

func _draw_results_background() -> void:
	if art_texture:
		draw_texture_rect(art_texture, Rect2(Vector2(size.x * 0.5 - 280, size.y * 0.5 - 290), Vector2(560, 560)), false, Color(1, 1, 1, 0.18))

func _draw_local() -> void:
	if local.is_empty():
		return
	_update_board_layout()
	var grid: Vector2i = local["scenario"]["grid"]
	var grid_rect := Rect2(grid_origin, Vector2(float(grid.x) * cell_size, float(grid.y) * cell_size))
	if ui_panel_texture:
		draw_texture_rect(ui_panel_texture, grid_rect.grow(36), false, Color(1, 1, 1, 0.92))
	else:
		draw_rect(grid_rect.grow(8), Color.html("#c9e7bd"))
	draw_rect(grid_rect, Color(0.97, 0.94, 0.78, 0.72))
	for x in range(grid.x + 1):
		var gx := grid_origin.x + float(x) * cell_size
		draw_line(Vector2(gx, grid_origin.y), Vector2(gx, grid_origin.y + float(grid.y) * cell_size), Color(0.28, 0.45, 0.32, 0.16), 1.0)
	for y in range(grid.y + 1):
		var gy := grid_origin.y + float(y) * cell_size
		draw_line(Vector2(grid_origin.x, gy), Vector2(grid_origin.x + float(grid.x) * cell_size, gy), Color(0.28, 0.45, 0.32, 0.16), 1.0)
	_draw_ghost_route()
	_draw_blocks()
	_draw_tracks()
	_draw_stations()
	_draw_signals()
	_draw_trains()
	_draw_contract_card()

func _draw_ghost_route() -> void:
	var ghost: Array = local["scenario"].get("ghost", [])
	for i in range(ghost.size() - 1):
		var a: Vector2i = ghost[i]
		var b: Vector2i = ghost[i + 1]
		if abs(a.x - b.x) + abs(a.y - b.y) == 1 and not (tracks.has(a) and tracks.has(b)):
			var ac := _grid_to_screen(a)
			var bc := _grid_to_screen(b)
			var horizontal: bool = abs(a.x - b.x) > 0
			if not _draw_piece(game_track_texture, (ac + bc) * 0.5, Vector2(cell_size * 1.16, cell_size * 0.48), 0.0 if horizontal else PI * 0.5, Color(1, 1, 1, 0.24)):
				draw_line(ac, bc, Color(0.4, 0.5, 0.45, 0.24), max(8.0, cell_size * 0.16), true)
	for p in ghost:
		if not tracks.has(p):
			var c := _grid_to_screen(p)
			draw_circle(c, max(5.0, cell_size * 0.1), Color(0.4, 0.5, 0.45, 0.34))

func _draw_blocks() -> void:
	var colors := [Color(0.3, 0.7, 1, 0.11), Color(1, 0.7, 0.2, 0.13), Color(0.7, 0.4, 1, 0.12), Color(0.2, 0.8, 0.5, 0.12)]
	for bid in blocks.keys():
		for p in blocks[bid]:
			var top_left := grid_origin + Vector2(float(p.x) * cell_size, float(p.y) * cell_size)
			draw_rect(Rect2(top_left + Vector2(5, 5), Vector2(cell_size - 10.0, cell_size - 10.0)), colors[int(bid) % colors.size()])

func _draw_tracks() -> void:
	for p in tracks.keys():
		var c := _grid_to_screen(p)
		var neigh := _track_neighbors(p)
		for n in neigh:
			if n < p:
				continue
			var nc := _grid_to_screen(n)
			var horizontal: bool = abs(n.x - p.x) > 0
			if not _draw_piece(game_track_texture, (c + nc) * 0.5, Vector2(cell_size * 1.2, cell_size * 0.54), 0.0 if horizontal else PI * 0.5):
				draw_line(c, nc, Color.html("#4b4037"), cell_size * 0.32, true)
				draw_line(c, nc, Color.html("#e7d6a1"), cell_size * 0.18, true)
				draw_line(c, nc, Color.html("#393536"), cell_size * 0.06, true)
		if game_track_texture == null:
			draw_circle(c, cell_size * 0.16, Color.html("#4b4037"))
			draw_circle(c, cell_size * 0.08, Color.html("#e7d6a1"))

func _draw_stations() -> void:
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		var c := _grid_to_screen(st["pos"])
		var col := Color.html("#f4d35e")
		if st.get("role", "") == "source":
			col = Color.html("#b4e18b")
		elif st.get("role", "") in ["sink", "yard"]:
			col = Color.html("#9fd9ff")
		elif st.get("role", "") == "processor":
			col = Color.html("#ff9b83")
		var texture := game_steelworks_texture if st.get("role", "") == "processor" else game_station_texture
		if selected_tool == "train" and st.get("role", "") == "source":
			draw_circle(c, cell_size * 0.82, Color(1.0, 0.86, 0.22, 0.32))
			draw_circle(c, cell_size * 0.82, Color.html("#172028"), false, 3.0)
		if not _draw_piece(texture, c, Vector2(cell_size * 1.34, cell_size * 1.34), 0.0, col):
			draw_rect(Rect2(c - Vector2(cell_size * 0.58, cell_size * 0.42), Vector2(cell_size * 1.16, cell_size * 0.84)), col)
			draw_rect(Rect2(c - Vector2(cell_size * 0.58, cell_size * 0.42), Vector2(cell_size * 1.16, cell_size * 0.84)), Color.html("#2f3840"), false, 2)
		var label_size := int(max(14.0, cell_size * 0.24))
		draw_string(font, c + Vector2(-cell_size * 1.04, cell_size * 0.7), st["name"], HORIZONTAL_ALIGNMENT_CENTER, cell_size * 2.08, label_size, Color.html("#19242b"))
		if selected_tool == "train" and st.get("role", "") == "source":
			draw_string(font, c + Vector2(-cell_size * 0.9, -cell_size * 1.04), "BUY HERE", HORIZONTAL_ALIGNMENT_CENTER, cell_size * 1.8, int(max(13.0, cell_size * 0.22)), Color.html("#172028"))
		if int(st.get("platforms", 1)) > 1:
			draw_string(font, c + Vector2(-cell_size * 0.45, -cell_size * 0.7), "P%d" % int(st["platforms"]), HORIZONTAL_ALIGNMENT_CENTER, cell_size * 0.9, label_size, Color.html("#19242b"))

func _draw_signals() -> void:
	for p in signals.keys():
		var c := _grid_to_screen(p)
		var sig_type: String = signals[p]
		var is_chain := sig_type == "chain"
		var occupied := _block_occupied_by_other(int(block_for_tile.get(p, -1)), "") != ""
		var light := Color.html("#e84242") if occupied else Color.html("#42d46b")
		var signal_offset := Vector2(cell_size * 0.28, -cell_size * 0.18)
		if not _draw_piece(game_signal_texture, c + signal_offset, Vector2(cell_size * 0.48, cell_size * 1.08)):
			var stem_col := Color.html("#27333b")
			draw_line(c + Vector2(cell_size * 0.27, cell_size * 0.32), c + Vector2(cell_size * 0.27, -cell_size * 0.36), stem_col, 4.0, true)
			if is_chain:
				draw_rect(Rect2(c + Vector2(cell_size * 0.06, -cell_size * 0.58), Vector2(cell_size * 0.46, cell_size * 0.36)), Color.html("#f4f7fb"))
				draw_rect(Rect2(c + Vector2(cell_size * 0.06, -cell_size * 0.58), Vector2(cell_size * 0.46, cell_size * 0.36)), stem_col, false, 2)
			else:
				draw_circle(c + Vector2(cell_size * 0.28, -cell_size * 0.36), cell_size * 0.22, Color.html("#f4f7fb"))
				draw_circle(c + Vector2(cell_size * 0.28, -cell_size * 0.36), cell_size * 0.22, stem_col)
		draw_circle(c + Vector2(cell_size * 0.28, -cell_size * 0.36), cell_size * 0.12, light)
		if is_chain:
			draw_circle(c + Vector2(cell_size * 0.28, -cell_size * 0.1), cell_size * 0.08, light.lightened(0.18))

func _draw_trains() -> void:
	for t in trains:
		var p: Vector2 = t["pos"]
		var waiting: bool = String(t.get("state", "")).begins_with("Waiting") or t.get("state", "") == "Blocked" or t.get("state", "") == "NoRoute"
		var body: Color = Color(1, 1, 1, 1)
		if waiting:
			body = Color(1.25, 0.82, 0.82, 1)
		elif t.get("cargo", "") == "coal":
			body = Color(0.78, 0.78, 0.74, 1)
		elif t.get("cargo", "") == "steel":
			body = Color(0.78, 0.9, 1.0, 1)
		var dir: Vector2 = t.get("dir", Vector2.RIGHT)
		var rot := dir.angle()
		if not _draw_piece(game_train_texture, p, Vector2(cell_size * 0.96, cell_size * 0.5), rot, body):
			draw_rect(Rect2(p - Vector2(cell_size * 0.42, cell_size * 0.25), Vector2(cell_size * 0.84, cell_size * 0.5)), Color.html("#e84f4f") if waiting else Color.html("#2d7dd2"))
			draw_rect(Rect2(p - Vector2(cell_size * 0.42, cell_size * 0.25), Vector2(cell_size * 0.84, cell_size * 0.5)), Color.html("#172028"), false, 2)
			draw_circle(p + Vector2(-cell_size * 0.23, cell_size * 0.29), cell_size * 0.08, Color.html("#172028"))
			draw_circle(p + Vector2(cell_size * 0.23, cell_size * 0.29), cell_size * 0.08, Color.html("#172028"))
		if waiting:
			draw_circle(p + Vector2(cell_size * 0.46, -cell_size * 0.34), cell_size * 0.14, Color.html("#e84242"))
		draw_string(font, p + Vector2(-cell_size * 0.42, -cell_size * 0.5), t["id"], HORIZONTAL_ALIGNMENT_CENTER, cell_size * 0.84, int(max(12.0, cell_size * 0.2)), Color.html("#172028"))

func _draw_contract_card() -> void:
	var grid: Vector2i = local["scenario"].get("grid", Vector2i(14, 9))
	var card_size := Vector2(328, 330)
	var board_right := grid_origin.x + float(grid.x) * cell_size
	var card_pos := Vector2(board_right + 18.0, grid_origin.y)
	if card_pos.x + card_size.x > size.x - 18.0:
		card_size = Vector2(300, 96)
		card_pos = Vector2(size.x - card_size.x - 18.0, 56.0)
	if ui_panel_texture:
		draw_texture_rect(ui_panel_texture, Rect2(card_pos, card_size), false, Color(1, 1, 1, 0.97))
	else:
		draw_rect(Rect2(card_pos, card_size), Color(1.0, 0.94, 0.72, 0.94))
		draw_rect(Rect2(card_pos, card_size), Color.html("#172028"), false, 3)
	var x := card_pos.x + 46.0
	var y := card_pos.y + 40.0
	var text_color := Color.html("#172028")
	draw_string(font, Vector2(x, y), local.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, card_size.x - 82.0, 20, text_color)
	y += 30.0
	var lines := _contract_card_lines()
	for line in lines:
		if y > card_pos.y + card_size.y - 28.0:
			break
		draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, card_size.x - 82.0, 15, text_color)
		y += 20.0

func _contract_card_lines() -> Array[String]:
	if local.get("id", "") == "central_yard":
		return [
			"Demand: 20 freight trains.",
			"West -> Yard -> East.",
			"South -> Yard -> East.",
			"Buy: click West, then South.",
			"Block = next section empty.",
			"Chain = junction exit clear.",
			"Use chain before the yard."
		]
	if local.get("id", "") == "steelworks":
		return [
			"Demand: export 40 steel.",
			"Coal Input feeds Steelworks.",
			"Steelworks sends to Export.",
			"Buy: click Coal Input.",
			"Block = split long track.",
			"Chain = protect junctions."
		]
	return [
		"Demand: deliver 80 coal.",
		"Coal Mine -> Interchange.",
		"Buy: click Coal Mine.",
		"Block = split the line.",
		"Passing loop fixes meetups.",
		"Click stopped trains."
	]

func _draw_piece(texture: Texture2D, center: Vector2, draw_size: Vector2, rotation: float = 0.0, modulate_color: Color = Color.WHITE) -> bool:
	if texture == null:
		return false
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, modulate_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _load_campaign() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in campaign.keys():
			if parsed.has(key):
				campaign[key] = parsed[key]

func _save_campaign() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(campaign))
