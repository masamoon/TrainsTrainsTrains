extends Control

enum Screen { REGIONAL, LOCAL, RESULTS }

const SAVE_PATH := "user://trains_campaign.json"
const CELL := 48.0
const GRID_ORIGIN := Vector2(64, 132)
const DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i(1, -1),
	Vector2i.RIGHT,
	Vector2i(1, 1),
	Vector2i.DOWN,
	Vector2i(-1, 1),
	Vector2i.LEFT,
	Vector2i(-1, -1),
]

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
var dispatch_line_box: VBoxContainer
var dispatch_train_box: VBoxContainer
var dispatch_preview: RichTextLabel
var top_status: Label
var tool_buttons: Dictionary = {}
var selected_tool := "track"
var selected_train_id := ""
var selected_signal_pos := Vector2i(-999, -999)
var dragging := false
var last_drag_cell := Vector2i(-999, -999)
var drag_start_cell := Vector2i(-999, -999)
var drag_hover_cell := Vector2i(-999, -999)
var erased_signal_targets: Array[Dictionary] = []
var cell_size := CELL
var grid_origin := GRID_ORIGIN

var local := {}
var tracks: Dictionary = {}
var track_segments: Dictionary = {}
var signals: Dictionary = {}
var station_by_id: Dictionary = {}
var station_by_pos: Dictionary = {}
var blocks: Dictionary = {}
var block_for_tile: Dictionary = {}
var tile_reservations: Dictionary = {}
var lines: Dictionary = {}
var selected_line_id := ""
var editing_line_stops := false
var trains: Array = []
var train_seq := 1
var local_message := ""
var result_data := {}
var elapsed_since_progress := 0.0
var last_progress_count := 0
var deadlock_cooldown := 0.0
var signal_help_open := false
var planning_guide_open := false

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
	var style := _flat_style(Color(1.0, 0.97, 0.82, 0.99), Color.html("#172028"), 3, 8)
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

func _local_side_panel_width() -> float:
	var viewport_width: float = max(size.x, 640.0)
	if viewport_width >= 1800.0:
		return 520.0
	if viewport_width >= 1500.0:
		return 480.0
	return 390.0

func _local_side_panel_inner_width() -> float:
	return _local_side_panel_width() - 12.0 - 36.0

func _apply_local_side_panel_layout() -> void:
	if screen != Screen.LOCAL or side_panel == null:
		return
	side_panel.offset_left = -_local_side_panel_width()
	side_panel.offset_right = -12

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
	rect.z_index = 0
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
	var step: float = delta * float(local.get("speed", 1.0))
	_update_local(step)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if screen == Screen.REGIONAL and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_regional_click(mb.position)
		elif screen == Screen.LOCAL:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					dragging = true
					last_drag_cell = Vector2i(-999, -999)
					drag_start_cell = _screen_to_grid(mb.position)
					drag_hover_cell = drag_start_cell
					_handle_local_click(mb.position)
				else:
					if dragging and selected_tool in ["track", "erase"]:
						_finish_track_drag(mb.position)
					dragging = false
					last_drag_cell = Vector2i(-999, -999)
					drag_start_cell = Vector2i(-999, -999)
					drag_hover_cell = Vector2i(-999, -999)
					queue_redraw()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				if selected_tool in ["train", "line"]:
					_select_tool("track")
					local_message = "Tool canceled. Track tool selected."
					_refresh_local_side_text()
					return
				var old_tool := selected_tool
				selected_tool = "erase"
				_handle_local_click(mb.position)
				selected_tool = old_tool
	if event is InputEventKey and screen == Screen.LOCAL:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and selected_tool in ["train", "line"]:
			_select_tool("track")
			local_message = "Tool canceled. Track tool selected."
			_refresh_local_side_text()
	if event is InputEventMouseMotion and screen == Screen.LOCAL and dragging:
		if selected_tool in ["track", "erase"]:
			var motion := event as InputEventMouseMotion
			drag_hover_cell = _screen_to_grid(motion.position)
			queue_redraw()

func _define_scenarios() -> void:
	scenarios = [
		{
			"id": "coal_valley",
			"name": "Coal Valley",
			"purpose": "Teach basic track placement, cargo loading, cargo delivery, and train status.",
			"objective": "Deliver 80 coal to Interchange. Keep average train wait below 40s.",
			"briefing": "Contract: connect Coal Mine to Interchange and establish a coal service.\nSuccess is measured by delivered cargo and average train wait, not by matching a prescribed layout. A direct starter line is cheap, but leave room for later signals, passing space, or extra platforms if the service starts to queue.\nCreate a line from Coal Mine, assign at least one train, then watch the cargo badge and train status to decide what needs attention.",
			"start_message": "Connect Coal Mine to Interchange, create a coal line, assign a train, then improve the service if waits appear.",
			"guide_label": "One cheap starter option is a direct Coal Mine to Interchange connection.",
			"target": 80,
			"fleet_goal": 1,
			"cargo": "coal",
			"kind": "coal",
			"start_budget": 1500,
			"grid": Vector2i(18, 11),
			"route": ["coal_mine", "interchange"],
			"stations": [
				{"id": "coal_mine", "name": "Coal Mine", "pos": Vector2i(1, 5), "role": "source", "produces": "coal", "accepts": [], "platforms": 1},
				{"id": "interchange", "name": "Interchange", "pos": Vector2i(16, 5), "role": "sink", "produces": "", "accepts": ["coal"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5), Vector2i(16, 5)],
			"reward_money": 500,
			"reward_materials": 0,
			"reward_load": 8,
			"reward_capacity": 0,
			"wait_target": 40.0
		},
		{
			"id": "central_yard",
			"name": "Signal Siding",
			"purpose": "Teach block signals, paired signals, and a simple passing loop before introducing junctions.",
			"objective": "Move 20 freight loads with a 2-train line.",
			"briefing": "Contract: run a two-train freight service between West Line and East Line.\nThe constraint is shared track, not a hidden answer. Opposing trains need either room to pass, one-way separation, or enough signal blocks that the dispatcher can keep them apart.\nUse block or paired signals where they explain and improve flow, then compare total output, queues, and average wait.",
			"start_message": "Build a West Line to East Line service for two trains. Add capacity where the trains actually get in each other's way.",
			"guide_label": "A passing siding is one reliable option for two-way traffic, but parallel one-way track can work too.",
			"target": 20,
			"fleet_goal": 2,
			"cargo": "freight",
			"kind": "yard",
			"start_budget": 2300,
			"grid": Vector2i(18, 11),
			"route": ["west_line", "east_line", "west_line"],
			"stations": [
				{"id": "west_line", "name": "West Line", "pos": Vector2i(1, 5), "role": "source", "produces": "freight", "accepts": [], "platforms": 1},
				{"id": "east_line", "name": "East Line", "pos": Vector2i(16, 5), "role": "sink", "produces": "", "accepts": ["freight"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5), Vector2i(16, 5), Vector2i(5, 5), Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(12, 6), Vector2i(12, 5)],
			"reward_money": 250,
			"reward_materials": 0,
			"reward_load": 6,
			"reward_capacity": 8,
			"wait_target": 30.0
		},
		{
			"id": "steelworks",
			"name": "Central Yard",
			"purpose": "Teach a compact right-hand yard loop with block spacing, a yard throat, and a return path.",
			"objective": "Process 60 freight loads while running a 4-train yard fleet.",
			"briefing": "Contract: keep a four-train yard fleet processing freight through Central Yard without letting the throat lock up.\nThis map is about managing a stressed production district. Build any readable circulation pattern that gives trains an entrance, a yard stop, an exit, and a way back to the source.\nUse chain signals before conflict points, block signals after clear exits, and extra platforms or holding track when queues tell you the yard is saturated.",
			"start_message": "Design a yard circulation pattern for four trains. Watch the throat, queues, and wait time, then add infrastructure where the system strains.",
			"guide_label": "A loop through the yard with a protected return path is one robust pattern, not the only acceptable answer.",
			"target": 60,
			"fleet_goal": 4,
			"cargo": "mixed freight",
			"kind": "yard",
			"start_budget": 3100,
			"grid": Vector2i(18, 11),
			"route": ["west_line", "central_yard", "east_line", "central_yard", "west_line"],
			"stations": [
				{"id": "west_line", "name": "West Line", "pos": Vector2i(1, 4), "role": "source", "produces": "freight", "accepts": [], "platforms": 1},
				{"id": "central_yard", "name": "Central Yard", "pos": Vector2i(9, 5), "role": "yard", "produces": "", "accepts": ["freight"], "platforms": 1},
				{"id": "east_line", "name": "East Line", "pos": Vector2i(16, 5), "role": "sink", "produces": "", "accepts": ["freight"], "platforms": 1}
			],
			"ghost": [Vector2i(1, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5), Vector2i(16, 5), Vector2i(15, 6), Vector2i(14, 7), Vector2i(13, 7), Vector2i(12, 7), Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 5), Vector2i(8, 4), Vector2i(7, 3), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 4)],
			"reward_money": 0,
			"reward_materials": 0,
			"reward_load": 0,
			"reward_capacity": 20,
			"wait_target": 45.0
		},
		{
			"id": "overtake_pass",
			"name": "Overtake Pass",
			"purpose": "Stress-test single-track dispatch with short overtaking pockets and four-train meets.",
			"objective": "Move 40 freight loads with at least four trains on a mostly single-track route.",
			"briefing": "Contract: keep four freight trains moving over one shared corridor with only small passing pockets. This is not a double-track build: the main line is single track, and each pocket is just long enough to hold a meet or overtake.\nUse right-hand running through pockets: eastbound trains prefer the lower/south rail, westbound trains use the upper/north rail. Signal each pocket mouth so trains reserve one clear pocket segment at a time.",
			"start_message": "Build West Line to East Line over a single-track corridor with short overtaking pockets. Run four trains without letting the pockets lock up.",
			"guide_label": "A reliable pattern is one single main with three short upper passing pockets and chain-protected throats.",
			"target": 40,
			"fleet_goal": 4,
			"cargo": "freight",
			"kind": "yard",
			"start_budget": 3900,
			"grid": Vector2i(18, 11),
			"route": ["west_line", "east_line", "west_line"],
			"stations": [
				{"id": "west_line", "name": "West Line", "pos": Vector2i(1, 5), "role": "source", "produces": "freight", "accepts": [], "platforms": 3},
				{"id": "east_line", "name": "East Line", "pos": Vector2i(16, 5), "role": "sink", "produces": "", "accepts": ["freight"], "platforms": 3}
			],
			"ghost": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5), Vector2i(16, 5), Vector2i(3, 5), Vector2i(4, 4), Vector2i(6, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 4), Vector2i(11, 4), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 4), Vector2i(15, 4), Vector2i(16, 5)],
			"reward_money": 0,
			"reward_materials": 0,
			"reward_load": 0,
			"reward_capacity": 24,
			"wait_target": 120.0
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
	hud_bar.offset_top = 50
	hud_bar.offset_right = -18
	hud_bar.offset_bottom = 100
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
	tool_bar.offset_top = 108
	tool_bar.offset_right = -20
	tool_bar.offset_bottom = 166
	tool_bar.add_theme_constant_override("separation", 6)
	tool_bar.z_index = 30
	tool_bar.z_as_relative = false
	add_child(tool_bar)

	_add_tool_button("Track\n$25", "track")
	_add_tool_button("Erase", "erase")
	_add_tool_button("Block\n$80", "block")
	_add_tool_button("Chain\n$120", "chain")
	_add_tool_button("Line\nPick", "line")
	_add_button(tool_bar, "New\nTrain", func(): _buy_available_train())
	_add_button(tool_bar, "Assign\nTrain", func(): _assign_selected_train_to_selected_line())
	_add_button(tool_bar, "Signal\nHelp", func(): _toggle_signal_help())
	_add_button(tool_bar, "Plan\nGuide", func(): _toggle_planning_guide())
	_add_button(tool_bar, "Platform\n$200", func(): _add_platform())
	_add_button(tool_bar, "Rotate\nSig", func(): _rotate_selected_signal())
	_add_button(tool_bar, "Restart\nTrains", func(): _restart_trains_only())
	_add_tool_button("Buy\nTrain", "train")
	_add_button(tool_bar, "Reset\nMap", func(): start_scenario(local.get("id", "coal_valley")))

	side_panel = PanelContainer.new()
	_style_panel(side_panel)
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -_local_side_panel_width()
	side_panel.offset_top = 100
	side_panel.offset_right = -12
	side_panel.offset_bottom = -16
	side_panel.z_index = 30
	side_panel.z_as_relative = false
	add_child(side_panel)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.add_child(side_box)

	side_text = RichTextLabel.new()
	side_text.bbcode_enabled = true
	side_text.scroll_active = true
	side_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_text.custom_minimum_size = Vector2(0, 240)
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", 16)
	side_text.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.86, 0.8))
	side_text.add_theme_constant_override("outline_size", 2)
	side_box.add_child(side_text)

	var dispatch_title := Label.new()
	dispatch_title.text = "Dispatcher"
	dispatch_title.add_theme_font_size_override("font_size", 18)
	dispatch_title.add_theme_color_override("font_color", Color.html("#172028"))
	side_box.add_child(dispatch_title)

	var dispatch_lists := HBoxContainer.new()
	dispatch_lists.add_theme_constant_override("separation", 8)
	dispatch_lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(dispatch_lists)

	dispatch_line_box = VBoxContainer.new()
	dispatch_line_box.custom_minimum_size = Vector2(150, 0)
	dispatch_line_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_line_box.size_flags_stretch_ratio = 0.44
	dispatch_line_box.add_theme_constant_override("separation", 5)
	dispatch_lists.add_child(dispatch_line_box)

	dispatch_train_box = VBoxContainer.new()
	dispatch_train_box.custom_minimum_size = Vector2(180, 0)
	dispatch_train_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_train_box.size_flags_stretch_ratio = 0.56
	dispatch_train_box.add_theme_constant_override("separation", 5)
	dispatch_lists.add_child(dispatch_train_box)

	var dispatch_actions := HBoxContainer.new()
	dispatch_actions.add_theme_constant_override("separation", 8)
	dispatch_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(dispatch_actions)
	var buy_stock_button := _add_button(dispatch_actions, "Buy Train $300", func(): _buy_available_train())
	_fit_sidebar_action_button(buy_stock_button)
	var assign_train_button := _add_button(dispatch_actions, "Assign Train", func(): _assign_selected_train_to_selected_line())
	_fit_sidebar_action_button(assign_train_button)
	var clear_train_button := _add_button(dispatch_actions, "Clear Line", func(): _clear_selected_train_line())
	_fit_sidebar_action_button(clear_train_button)
	var line_actions := HBoxContainer.new()
	line_actions.add_theme_constant_override("separation", 8)
	line_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(line_actions)
	var edit_stops_button := _add_button(line_actions, "Edit Stops", func(): _toggle_line_stop_edit())
	_fit_sidebar_action_button(edit_stops_button)
	var complete_line_button := _add_button(line_actions, "Complete Line", func(): _complete_line_stop_edit())
	_fit_sidebar_action_button(complete_line_button)
	var clear_stops_button := _add_button(line_actions, "Clear Stops", func(): _clear_selected_line_stops())
	_fit_sidebar_action_button(clear_stops_button)
	var debug_actions := HBoxContainer.new()
	debug_actions.add_theme_constant_override("separation", 8)
	debug_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(debug_actions)
	var debug_money_button := _add_button(debug_actions, "Debug Money +$5000", func(): _debug_replenish_money())
	_fit_sidebar_action_button(debug_money_button)

	dispatch_preview = RichTextLabel.new()
	dispatch_preview.bbcode_enabled = true
	dispatch_preview.scroll_active = false
	dispatch_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_preview.custom_minimum_size = Vector2(0, 100)
	dispatch_preview.add_theme_color_override("default_color", Color.html("#172028"))
	dispatch_preview.add_theme_font_size_override("normal_font_size", 15)
	dispatch_preview.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.86, 0.7))
	dispatch_preview.add_theme_constant_override("outline_size", 1)
	side_box.add_child(dispatch_preview)
	_refresh_local_side_text()

func _build_results_ui() -> void:
	_add_backplate(ui_panel_texture, Control.PRESET_CENTER, Vector4(-345, -235, 345, 245), Vector4(180, 130, 180, 130), Color(1, 1, 1, 0.96))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -245
	box.offset_top = -154
	box.offset_right = 245
	box.offset_bottom = 182
	box.z_index = 30
	box.z_as_relative = false
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "%s Complete" % result_data.get("name", "Scenario")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.html("#172028"))
	box.add_child(title)

	var details := RichTextLabel.new()
	details.custom_minimum_size = Vector2(490, 210)
	details.bbcode_enabled = true
	details.scroll_active = false
	details.add_theme_color_override("default_color", Color.html("#172028"))
	details.text = result_data.get("text", "")
	box.add_child(details)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var continue_button := _add_button(actions, "Continue to Regional Map", func(): _return_to_region())
	continue_button.custom_minimum_size = Vector2(220, 54)
	var replay_button := _add_button(actions, "Replay Scenario", func(): start_scenario(result_data.get("id", "coal_valley")))
	replay_button.custom_minimum_size = Vector2(160, 54)

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

func _fit_sidebar_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _add_tool_button(text: String, tool: String) -> void:
	var button := _add_button(tool_bar, text, func(): _select_tool(tool))
	tool_buttons[tool] = button
	_refresh_tool_button_styles()

func _select_tool(tool: String) -> void:
	selected_tool = tool
	if selected_tool == "train":
		local_message = "Buy Train selected. Click a green source station to choose where the train starts."
	elif selected_tool == "block":
		local_message = "Block signal selected. Click track to place; click the signal again to toggle single or double."
	elif selected_tool == "chain":
		local_message = "Chain signal selected. Click track to place; click the signal again to toggle single or double."
	elif selected_tool == "pair":
		local_message = "Pair selected. Existing signal tools now toggle single and double signals directly."
	elif selected_tool == "line":
		local_message = "Line tool selected. Click a source station to create or select its route line."
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
	erased_signal_targets.clear()
	planning_guide_open = false
	tracks.clear()
	track_segments.clear()
	signals.clear()
	lines.clear()
	selected_line_id = ""
	editing_line_stops = false
	station_by_id.clear()
	station_by_pos.clear()
	blocks.clear()
	block_for_tile.clear()
	tile_reservations.clear()
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
		"fleet_goal": int(scenario.get("fleet_goal", 1)),
		"wait_target": scenario["wait_target"],
		"money": int(scenario["start_budget"]) + int(campaign["materials"]) * 25,
		"materials": int(campaign["materials"]),
		"delivered": 0,
		"processed": 0,
		"productive_progress": 0,
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
	if id == "overtake_pass":
		return campaign["completed"].has("steelworks")
	return false

func _regional_node_position(id: String) -> Vector2:
	var y := size.y * 0.52
	if id == "coal_valley":
		return Vector2(size.x * 0.16, y)
	if id == "central_yard":
		return Vector2(size.x * 0.38, y)
	if id == "steelworks":
		return Vector2(size.x * 0.60, y)
	return Vector2(size.x * 0.82, y)

func _update_board_layout() -> void:
	if local.is_empty() or not local.has("scenario"):
		cell_size = CELL
		grid_origin = GRID_ORIGIN
		return
	_apply_local_side_panel_layout()
	var grid: Vector2i = local["scenario"].get("grid", Vector2i(14, 9))
	var top_reserved := 174.0
	var bottom_reserved := 20.0
	var horizontal_margin := 28.0
	var briefing_width := _local_side_panel_width() if max(size.x, 640.0) >= 1024.0 else 0.0
	var briefing_gap := 14.0 if briefing_width > 0.0 else 0.0
	var max_cell_from_width: float = (max(size.x, 640.0) - horizontal_margin * 2.0 - briefing_width - briefing_gap) / float(grid.x)
	var max_cell_from_height: float = (max(size.y, 480.0) - top_reserved - bottom_reserved) / float(grid.y)
	cell_size = clamp(floor(min(max_cell_from_width, max_cell_from_height)), 46.0, 78.0)
	grid_origin = Vector2(horizontal_margin, top_reserved)

func _handle_local_click(pos: Vector2) -> void:
	if selected_tool != "line":
		var hit_train := _hit_train_id(pos)
		if hit_train != "":
			selected_train_id = hit_train
			selected_signal_pos = Vector2i(-999, -999)
			dragging = false
			_refresh_local_side_text()
			queue_redraw()
			return
		if selected_tool == "erase":
			var erase_signal := _hit_signal_pos(pos)
			if erase_signal.x > -900:
				_erase_signal_or_track(erase_signal)
				_refresh_local_side_text()
				queue_redraw()
				return
		var hit_signal := _hit_signal_pos(pos)
		if hit_signal.x > -900 and selected_tool in ["block", "chain", "pair"]:
			if selected_tool == "block":
				_place_signal(hit_signal, "block")
			elif selected_tool == "chain":
				_place_signal(hit_signal, "chain")
			else:
				_place_signal_pair(hit_signal, _pair_signal_type_for(hit_signal))
			selected_train_id = ""
			dragging = false
			_refresh_local_side_text()
			queue_redraw()
			return
		if hit_signal.x > -900 and not (selected_tool in ["block", "chain", "pair", "erase"]):
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
	if editing_line_stops:
		var add_station := _hit_line_stop_add_station(pos)
		if add_station != "":
			var station: Dictionary = station_by_id[add_station]
			_append_station_to_selected_line_at(station["pos"])
		else:
			local_message = "Tap a station plus sign to add it to the line, or use Complete Line when finished."
		_refresh_local_side_text()
		queue_redraw()
		return
	if gp == last_drag_cell and selected_tool in ["track", "erase"]:
		return
	var previous_cell := last_drag_cell
	last_drag_cell = gp
	if selected_tool == "track":
		if _is_in_grid(previous_cell):
			_place_track_path(previous_cell, gp)
		else:
			_place_track(gp)
	elif selected_tool == "erase":
		if _is_in_grid(previous_cell):
			_erase_path(previous_cell, gp)
		else:
			_erase_signal_or_track(gp)
	elif selected_tool == "block":
		_place_signal(_signal_placement_cell(pos, gp), "block")
	elif selected_tool == "chain":
		_place_signal(_signal_placement_cell(pos, gp), "chain")
	elif selected_tool == "pair":
		var signal_gp := _signal_placement_cell(pos, gp)
		_place_signal_pair(signal_gp, _pair_signal_type_for(signal_gp))
	elif selected_tool == "line":
		_select_or_create_line_at(gp)
	elif selected_tool == "train":
		_buy_train_at(gp)
	_refresh_local_side_text()
	queue_redraw()

func _finish_track_drag(pos: Vector2) -> void:
	if selected_tool not in ["track", "erase"]:
		return
	var end_cell := _screen_to_grid(pos)
	if not _is_in_grid(drag_start_cell) or not _is_in_grid(end_cell):
		return
	if end_cell == drag_start_cell:
		return
	if selected_tool == "track":
		_place_track_path(drag_start_cell, end_cell)
	elif selected_tool == "erase":
		_erase_path(drag_start_cell, end_cell)
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
		if not _is_train_on_map(t):
			continue
		if (t["pos"] as Vector2).distance_to(pos) < max(24.0, cell_size * 0.42):
			return t["id"]
	return ""

func _hit_signal_pos(pos: Vector2) -> Vector2i:
	_update_board_layout()
	for sig_pos in signals.keys():
		for dir in _signal_dirs(sig_pos):
			if _signal_gate_center(sig_pos, dir).distance_to(pos) < max(22.0, cell_size * 0.34):
				return sig_pos
	for sig_pos in signals.keys():
		if _grid_to_screen(sig_pos).distance_to(pos) < max(18.0, cell_size * 0.28):
			return sig_pos
	return Vector2i(-999, -999)

func _signal_placement_cell(click_pos: Vector2, fallback: Vector2i) -> Vector2i:
	var radius: float = max(22.0, cell_size * 0.34)
	for target in erased_signal_targets:
		var target_pos: Vector2i = target.get("pos", Vector2i(-999, -999))
		var center: Vector2 = target.get("center", Vector2.INF)
		if target_pos.x > -900 and tracks.has(target_pos) and center.distance_to(click_pos) <= radius:
			return target_pos
	return fallback

func _remember_erased_signal_targets(pos: Vector2i) -> void:
	if not signals.has(pos):
		return
	for dir in _signal_dirs(pos):
		erased_signal_targets.append({
			"pos": pos,
			"center": _signal_gate_center(pos, dir)
		})
	erased_signal_targets.append({
		"pos": pos,
		"center": _grid_to_screen(pos)
	})
	while erased_signal_targets.size() > 24:
		erased_signal_targets.pop_front()

func _clear_erased_signal_target(pos: Vector2i) -> void:
	for i in range(erased_signal_targets.size() - 1, -1, -1):
		if erased_signal_targets[i].get("pos", Vector2i(-999, -999)) == pos:
			erased_signal_targets.remove_at(i)

func _station_add_handle_center(station_pos: Vector2i) -> Vector2:
	return _grid_to_screen(station_pos) + Vector2(cell_size * 0.48, -cell_size * 0.48)

func _hit_line_stop_add_station(pos: Vector2) -> String:
	if not editing_line_stops:
		return ""
	var radius: float = max(14.0, cell_size * 0.24)
	for station_id in station_by_id.keys():
		var st: Dictionary = station_by_id[station_id]
		if _station_add_handle_center(st["pos"]).distance_to(pos) <= radius:
			return String(station_id)
	return ""

func _signal_type(pos: Vector2i) -> String:
	var signal_value: Variant = signals.get(pos, "")
	if typeof(signal_value) == TYPE_DICTIONARY:
		var data: Dictionary = signal_value
		return String(data.get("type", "block"))
	return String(signal_value)

func _signal_dir(pos: Vector2i) -> Vector2i:
	var signal_value: Variant = signals.get(pos, {})
	if typeof(signal_value) == TYPE_DICTIONARY:
		var data: Dictionary = signal_value
		var dir: Vector2i = data.get("dir", Vector2i.RIGHT)
		return dir
	return Vector2i.RIGHT

func _dir_key(dir: Vector2i) -> String:
	return "%d,%d" % [dir.x, dir.y]

func _key_dir(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.RIGHT
	return Vector2i(int(parts[0]), int(parts[1]))

func _opposite_dir(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.x, -dir.y)

func _signal_dir_map(pos: Vector2i) -> Dictionary:
	var dir_map: Dictionary = {}
	if not signals.has(pos):
		return dir_map
	var signal_value: Variant = signals.get(pos, {})
	if typeof(signal_value) == TYPE_DICTIONARY:
		var data: Dictionary = signal_value
		if data.has("dirs"):
			var stored: Dictionary = data["dirs"]
			for key in stored.keys():
				dir_map[String(key)] = String(stored[key])
		else:
			dir_map[_dir_key(data.get("dir", Vector2i.RIGHT))] = String(data.get("type", "block"))
	elif signal_value != "":
		dir_map[_dir_key(Vector2i.RIGHT)] = String(signal_value)
	return dir_map

func _signal_dirs(pos: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	for key in _signal_dir_map(pos).keys():
		dirs.append(_key_dir(String(key)))
	return dirs

func _signal_type_for_dir(pos: Vector2i, dir: Vector2i) -> String:
	var dir_map := _signal_dir_map(pos)
	return String(dir_map.get(_dir_key(dir), _signal_type(pos)))

func _set_signal(pos: Vector2i, signal_type: String, dir: Vector2i = Vector2i.RIGHT) -> void:
	var dir_map := _signal_dir_map(pos)
	dir_map[_dir_key(dir)] = signal_type
	signals[pos] = {
		"type": signal_type,
		"dir": dir,
		"dirs": dir_map
	}

func _replace_signal_set(pos: Vector2i, signal_type: String, dirs: Array[Vector2i]) -> void:
	var dir_map := {}
	for dir in dirs:
		dir_map[_dir_key(dir)] = signal_type
	signals[pos] = {
		"type": signal_type,
		"dir": dirs[0] if not dirs.is_empty() else Vector2i.RIGHT,
		"dirs": dir_map
	}

func _pair_signal_type_for(pos: Vector2i) -> String:
	if signals.has(pos):
		return _signal_type(pos)
	return "block"

func _signal_direction_options(pos: Vector2i) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for n in _track_neighbors(pos):
		var d: Vector2i = n - pos
		if d != Vector2i.ZERO:
			options.append(d)
	if options.is_empty():
		options = DIRS.duplicate()
	return options

func _paired_signal_dirs(pos: Vector2i) -> Array[Vector2i]:
	var options := _signal_direction_options(pos)
	var current: Vector2i = _signal_dir(pos)
	var dirs: Array[Vector2i] = []
	if options.has(current):
		dirs.append(current)
	for dir in options:
		if not dirs.has(dir):
			dirs.append(dir)
	return dirs

func _toggle_signal_pair_state(pos: Vector2i, signal_type: String) -> void:
	var dir := _signal_dir(pos)
	if _signal_dirs(pos).size() > 1:
		_replace_signal_set(pos, signal_type, [dir])
		local_message = "%s signal set to single. Use Rotate Sig to change facing." % signal_type.capitalize()
	else:
		_replace_signal_set(pos, signal_type, _paired_signal_dirs(pos))
		local_message = "%s signal set to paired. It now protects each connected rail direction." % signal_type.capitalize()
	selected_signal_pos = pos
	_compute_blocks()

func _default_signal_dir(pos: Vector2i) -> Vector2i:
	return _signal_direction_options(pos)[0]

func _rotate_signal_at(pos: Vector2i) -> void:
	if not signals.has(pos):
		return
	var options := _signal_direction_options(pos)
	var current: Vector2i = _signal_dir(pos)
	var idx: int = options.find(current)
	var next_dir: Vector2i = options[(idx + 1) % options.size()] if idx >= 0 else options[0]
	if _signal_dirs(pos).size() > 1:
		_replace_signal_set(pos, _signal_type(pos), [next_dir, _opposite_dir(next_dir)])
	else:
		_replace_signal_set(pos, _signal_type(pos), [next_dir])
	local_message = "%s signal rotated to face %s." % [_signal_type(pos).capitalize(), _dir_name(next_dir)]
	_compute_blocks()
	_refresh_local_side_text()
	queue_redraw()

func _rotate_selected_signal() -> void:
	if selected_signal_pos.x <= -900:
		local_message = "Select a signal first, then rotate it."
		_refresh_local_side_text()
		return
	_rotate_signal_at(selected_signal_pos)

func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP:
		return "north"
	if dir == Vector2i(1, -1):
		return "northeast"
	if dir == Vector2i.DOWN:
		return "south"
	if dir == Vector2i(1, 1):
		return "southeast"
	if dir == Vector2i.LEFT:
		return "west"
	if dir == Vector2i(-1, 1):
		return "southwest"
	if dir == Vector2i(-1, -1):
		return "northwest"
	return "east"

func _dir_screen_name(dir: Vector2i) -> String:
	var cardinal := _dir_name(dir)
	if dir.x > 0:
		cardinal += " / right"
	elif dir.x < 0:
		cardinal += " / left"
	if dir.y > 0:
		cardinal += " / down"
	elif dir.y < 0:
		cardinal += " / up"
	return cardinal

func _track_key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

func _key_to_track(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-999, -999)
	return Vector2i(int(parts[0]), int(parts[1]))

func _segment_key(a: Vector2i, b: Vector2i) -> String:
	var ak := _track_key(a)
	var bk := _track_key(b)
	if ak < bk:
		return "%s|%s" % [ak, bk]
	return "%s|%s" % [bk, ak]

func _segment_points(key: String) -> Array[Vector2i]:
	var parts := key.split("|")
	if parts.size() != 2:
		return []
	return [_key_to_track(parts[0]), _key_to_track(parts[1])]

func _has_track_segment(a: Vector2i, b: Vector2i) -> bool:
	return track_segments.has(_segment_key(a, b))

func _is_adjacent_track_step(a: Vector2i, b: Vector2i) -> bool:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return max(dx, dy) == 1 and (dx != 0 or dy != 0)

func _add_track_segment(a: Vector2i, b: Vector2i) -> bool:
	if not _is_adjacent_track_step(a, b):
		return false
	if not tracks.has(a) or not tracks.has(b):
		return false
	var key := _segment_key(a, b)
	if track_segments.has(key):
		return false
	track_segments[key] = true
	return true

func _remove_track_segment(a: Vector2i, b: Vector2i) -> bool:
	return track_segments.erase(_segment_key(a, b))

func _remove_track_segments_at(p: Vector2i) -> int:
	var removed := 0
	for d in DIRS:
		if _remove_track_segment(p, p + d):
			removed += 1
	return removed

func _track_tile_has_segments(p: Vector2i) -> bool:
	for d in DIRS:
		if _has_track_segment(p, p + d):
			return true
	return false

func _force_track_path(points: Array[Vector2i]) -> void:
	var last := Vector2i(-999, -999)
	for p in points:
		if not _is_in_grid(p):
			continue
		tracks[p] = true
		if _is_in_grid(last):
			_add_track_segment(last, p)
		last = p

func _place_track(gp: Vector2i) -> void:
	if not tracks.has(gp):
		if _spend(25, 0):
			tracks[gp] = true
			local["infra_cost"] += 25
		else:
			return
		local_message = "Track placed. Drag from one rail tile to another to create exact connections."
		_compute_blocks()
		_dispatch_waiting_trains()

func _grid_drag_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := from_cell
	if not _is_in_grid(cur):
		cur = to_cell
	path.append(cur)
	while cur != to_cell:
		var step_x := 0
		if to_cell.x > cur.x:
			step_x = 1
		elif to_cell.x < cur.x:
			step_x = -1
		var step_y := 0
		if to_cell.y > cur.y:
			step_y = 1
		elif to_cell.y < cur.y:
			step_y = -1
		cur += Vector2i(step_x, step_y)
		path.append(cur)
	return path

func _place_track_path(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var changed := 0
	var last_valid := Vector2i(-999, -999)
	for p in _grid_drag_path(from_cell, to_cell):
		if not _is_in_grid(p):
			continue
		if not tracks.has(p):
			if not _spend(25, 0):
				break
			tracks[p] = true
			local["infra_cost"] += 25
			changed += 1
		if _is_in_grid(last_valid) and _add_track_segment(last_valid, p):
			changed += 1
		last_valid = p
	if changed > 0:
		local_message = "Track run placed. Only the drawn rail segments are connected."
		_compute_blocks()
		_dispatch_waiting_trains()

func _erase_path(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var erased := 0
	var path := _grid_drag_path(from_cell, to_cell)
	for i in range(path.size() - 1):
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		if _remove_track_segment(a, b):
			erased += 1
	for p in path:
		if signals.has(p):
			_remember_erased_signal_targets(p)
			signals.erase(p)
			erased += 1
		if not station_by_pos.has(p) and _tile_has_train(p, "") == "" and not _track_tile_has_segments(p):
			if tracks.erase(p):
				erased += 1
	if erased > 0:
		selected_signal_pos = Vector2i(-999, -999)
		local_message = "Track run erased."
		_compute_blocks()

func _erase_signal_or_track(gp: Vector2i) -> void:
	if signals.has(gp):
		_remember_erased_signal_targets(gp)
		signals.erase(gp)
		selected_signal_pos = Vector2i(-999, -999)
		local_message = "Signal removed. Track remains."
		_compute_blocks()
		return
	_erase_track(gp)

func _erase_track(gp: Vector2i) -> void:
	if _tile_has_train(gp, ""):
		local_message = "Cannot erase track occupied by a train."
		return
	var removed_segments := _remove_track_segments_at(gp)
	if station_by_pos.has(gp):
		if removed_segments > 0:
			local_message = "Station rail connections removed. Stations remain fixed."
			_compute_blocks()
		else:
			local_message = "Stations are fixed contract points."
		return
	if tracks.erase(gp):
		if signals.has(gp):
			_remember_erased_signal_targets(gp)
		signals.erase(gp)
		local_message = "Track removed."
		_compute_blocks()
	elif removed_segments > 0:
		local_message = "Track connections removed."
		_compute_blocks()

func _place_signal(gp: Vector2i, signal_type: String) -> void:
	if not tracks.has(gp):
		local_message = "Signals need track."
		return
	var material_cost := 1 if signal_type == "chain" else 0
	var money_cost := 120 if signal_type == "chain" else 80
	if signals.has(gp):
		if _signal_type(gp) == signal_type:
			_toggle_signal_pair_state(gp, signal_type)
			return
		_replace_signal_set(gp, signal_type, _signal_dirs(gp))
		selected_signal_pos = gp
		local_message = "Signal changed to %s. Click again to toggle single or double." % signal_type
		_compute_blocks()
		return
	if _spend(money_cost, material_cost):
		_clear_erased_signal_target(gp)
		_set_signal(gp, signal_type, _default_signal_dir(gp))
		selected_signal_pos = gp
		local["infra_cost"] += money_cost
		local_message = "%s signal placed facing %s. Click it again to make it double." % [signal_type.capitalize(), _dir_name(_signal_dir(gp))]
		_compute_blocks()

func _place_signal_pair(gp: Vector2i, signal_type: String) -> void:
	if not tracks.has(gp):
		local_message = "Paired signals need track."
		return
	var material_cost := 1 if signal_type == "chain" else 0
	var money_cost := 210 if signal_type == "chain" else 140
	if signals.has(gp):
		if _signal_type(gp) == signal_type and _signal_dirs(gp).size() > 1:
			selected_signal_pos = gp
			local_message = "Paired %s signal selected. Rotate Sig changes the protected axis." % signal_type
			return
		_replace_signal_set(gp, signal_type, _paired_signal_dirs(gp))
		selected_signal_pos = gp
		local_message = "Paired %s signal set. Rotate Sig changes the protected axis." % signal_type
		_compute_blocks()
		return
	if _spend(money_cost, material_cost):
		_clear_erased_signal_target(gp)
		_set_signal(gp, signal_type, _default_signal_dir(gp))
		_replace_signal_set(gp, signal_type, _paired_signal_dirs(gp))
		selected_signal_pos = gp
		local["infra_cost"] += money_cost
		local_message = "Paired %s signal placed. It protects both directions on this rail." % signal_type
		_compute_blocks()

func _add_platform() -> void:
	var target_id: String = "central_yard" if local.get("kind", "") == "yard" and station_by_id.has("central_yard") else ""
	if target_id == "":
		for id in station_by_id.keys():
			if station_by_id[id].get("role", "") in ["yard", "sink", "processor"]:
				target_id = id
				break
	if target_id == "" or not _spend(200, 1):
		return
	station_by_id[target_id]["platforms"] = int(station_by_id[target_id].get("platforms", 1)) + 1
	local["infra_cost"] += 200
	local_message = "%s now has %d platforms." % [station_by_id[target_id]["name"], station_by_id[target_id]["platforms"]]
	_refresh_local_side_text()

func _line_id_for_source(source_id: String) -> String:
	return "line_%s" % source_id

func _line_name_for_route(route: Array) -> String:
	if route.is_empty():
		return "Line"
	var first: Dictionary = station_by_id[route[0]]
	var last: Dictionary = station_by_id[route[max(0, route.size() - 1)]]
	return "%s Line" % first.get("name", last.get("name", "Route"))

func _create_or_get_line_for_source(source_id: String) -> String:
	var route: Array = _route_for_source(source_id)
	if route.is_empty():
		return ""
	var line_id: String = _line_id_for_source(source_id)
	if not lines.has(line_id):
		lines[line_id] = {
			"id": line_id,
			"name": _line_name_for_route(route),
			"route": route
		}
	return line_id

func _select_or_create_line_at(gp: Vector2i) -> void:
	if not station_by_pos.has(gp):
		local_message = "Click a source station to create or select a line."
		return
	var station_id: String = station_by_pos[gp]
	var st: Dictionary = station_by_id[station_id]
	if st.get("role", "") != "source":
		local_message = "Lines start at source stations. Click a green station."
		return
	var line_id: String = _create_or_get_line_for_source(station_id)
	if line_id == "":
		local_message = "No route template starts at %s." % st.get("name", "that station")
		return
	selected_line_id = line_id
	local_message = "%s selected. Select an available train, then assign it to this line." % lines[line_id]["name"]

func _selected_line_route() -> Array:
	if selected_line_id == "" or not lines.has(selected_line_id):
		return []
	return (lines[selected_line_id]["route"] as Array).duplicate()

func _first_source_station_id() -> String:
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		if st.get("role", "") == "source":
			return id
	return ""

func _available_train_spawn_pos() -> Vector2i:
	var source_id := _first_source_station_id()
	if source_id != "":
		return station_by_id[source_id]["pos"]
	return Vector2i.ZERO

func _off_map_tile() -> Vector2i:
	return Vector2i(-999, -999)

func _is_train_on_map(t: Dictionary) -> bool:
	return tracks.has(t.get("tile", _off_map_tile()))

func _new_train_record(spawn_pos: Vector2i, line_id: String = "", route: Array = []) -> Dictionary:
	var starts_on_map := line_id != "" and tracks.has(spawn_pos)
	return {
		"id": "T%02d" % train_seq,
		"name": "Train %02d" % train_seq,
		"line_id": line_id,
		"route": route,
		"stop_index": 1 if not route.is_empty() else 0,
		"tile": spawn_pos if starts_on_map else _off_map_tile(),
		"pos": _grid_to_screen(spawn_pos) if starts_on_map else Vector2(-1000, -1000),
		"path": [],
		"path_index": 0,
		"cargo": "",
		"cargo_amount": 0,
		"capacity": 40,
		"speed": 150.0,
		"dir": Vector2.RIGHT,
		"state": "Available" if line_id == "" else "Idle",
		"wait_reason": "",
		"wait_time": 0.0,
		"total_wait": 0.0,
		"dwell": 0.0,
		"handled_yard": false
	}

func _buy_available_train() -> void:
	if not _spend(300, 0):
		_refresh_local_side_text()
		return
	_add_available_train(false)

func _add_available_train(free: bool = true) -> void:
	var t := _new_train_record(_off_map_tile())
	train_seq += 1
	trains.append(t)
	selected_train_id = t["id"]
	if not free:
		local["infra_cost"] += 300
	local_message = "%s bought as available stock. Select a line and assign it." % t["name"]
	_update_status_labels()
	_refresh_local_side_text()
	queue_redraw()

func _buy_train_on_selected_line() -> void:
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select a line first with the Line tool."
		_refresh_local_side_text()
		return
	_buy_train_for_line(selected_line_id)

func _toggle_signal_help() -> void:
	signal_help_open = not signal_help_open
	if signal_help_open:
		selected_tool = "block"
		local_message = "Signal help on. Colored rail sections show blocks; click any signal to inspect what it protects."
	else:
		selected_tool = "track"
		local_message = "Signal help off."
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _toggle_planning_guide() -> void:
	planning_guide_open = not planning_guide_open
	if planning_guide_open:
		local_message = "Planning guide shown. Treat it as one proven pattern, then adapt it to your own network."
	else:
		local_message = "Planning guide hidden. Use train status, queues, and block colors to tune your design."
	_refresh_local_side_text()
	queue_redraw()

func _line_train_count(line_id: String) -> int:
	var count := 0
	for t in trains:
		if String(t.get("line_id", "")) == line_id:
			count += 1
	return count

func _active_train_count() -> int:
	var count := 0
	for t in trains:
		var line_id := String(t.get("line_id", ""))
		if line_id != "" and _line_has_valid_orders(line_id):
			count += 1
	return count

func _available_train_count() -> int:
	return trains.size() - _active_train_count()

func _assign_selected_train_to_line(line_id: String) -> void:
	for t in trains:
		if t["id"] == selected_train_id:
			_assign_train_to_line(t, line_id)
			local_message = "%s assigned to %s." % [t["name"], lines[line_id]["name"]]
			_refresh_local_side_text()
			return

func _assign_selected_train_to_selected_line() -> void:
	if selected_train_id == "":
		local_message = "Select a train from the dispatcher first."
		_refresh_local_side_text()
		return
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select or create a line before assigning a train."
		_refresh_local_side_text()
		return
	if not _line_has_valid_orders(selected_line_id):
		local_message = "Line needs at least two stops before trains can run."
		_refresh_local_side_text()
		return
	_assign_selected_train_to_line(selected_line_id)

func _clear_selected_train_line() -> void:
	if selected_train_id == "":
		local_message = "Select a train first."
		_refresh_local_side_text()
		return
	for t in trains:
		if t["id"] == selected_train_id:
			t["line_id"] = ""
			t["route"] = []
			t["stop_index"] = 0
			t["path"] = []
			t["path_index"] = 0
			t["cargo"] = ""
			t["cargo_amount"] = 0
			t["state"] = "Available"
			t["wait_reason"] = ""
			t["wait_time"] = 0.0
			t["dwell"] = 0.0
			t["tile"] = _off_map_tile()
			t["pos"] = Vector2(-1000, -1000)
			local_message = "%s returned to depot stock." % t["name"]
			_refresh_local_side_text()
			queue_redraw()
			return

func _debug_replenish_money() -> void:
	if screen != Screen.LOCAL or local.is_empty():
		return
	local["money"] = int(local.get("money", 0)) + 5000
	local_message = "Debug: added $5000."
	_update_status_labels()
	_refresh_local_side_text()
	queue_redraw()

func _clear_control_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _add_dispatch_button(parent: Control, text: String, selected: bool, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	_style_button(b, selected)
	parent.add_child(b)
	return b

func _select_line_from_dispatch(line_id: String) -> void:
	selected_line_id = line_id
	local_message = "%s selected. Pick a train and assign it." % lines[line_id]["name"]
	_refresh_local_side_text()
	queue_redraw()

func _create_line_from_dispatch(source_id: String) -> void:
	var line_id := _create_or_get_line_for_source(source_id)
	if line_id == "":
		local_message = "No service template starts at %s." % source_id
		_refresh_local_side_text()
		return
	_select_line_from_dispatch(line_id)

func _toggle_line_stop_edit() -> void:
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select or create a line before editing stops."
		_refresh_local_side_text()
		return
	editing_line_stops = not editing_line_stops
	if editing_line_stops:
		selected_tool = "line"
		local_message = "Editing %s stops. Tap station plus signs in the order trains should visit them." % lines[selected_line_id]["name"]
	else:
		selected_tool = "track"
		local_message = "Stop editing finished for %s." % lines[selected_line_id]["name"]
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _complete_line_stop_edit() -> void:
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select or create a line before completing it."
		_refresh_local_side_text()
		return
	editing_line_stops = false
	selected_tool = "track"
	if _line_has_valid_orders(selected_line_id):
		local_message = "%s complete. Assign trains when ready." % lines[selected_line_id]["name"]
	else:
		local_message = "%s needs at least two stops before trains can run." % lines[selected_line_id]["name"]
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _clear_selected_line_stops() -> void:
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select a line before clearing stops."
		_refresh_local_side_text()
		return
	lines[selected_line_id]["route"] = []
	_reapply_line_to_assigned_trains(selected_line_id)
	editing_line_stops = true
	selected_tool = "line"
	local_message = "%s stops cleared. Tap station plus signs to add stops in order." % lines[selected_line_id]["name"]
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _append_station_to_selected_line_at(gp: Vector2i) -> void:
	if selected_line_id == "" or not lines.has(selected_line_id):
		local_message = "Select a line before adding stops."
		return
	if not station_by_pos.has(gp):
		local_message = "Tap station plus signs to add line stops."
		return
	var station_id: String = station_by_pos[gp]
	var route: Array = lines[selected_line_id].get("route", [])
	if not route.is_empty() and String(route[route.size() - 1]) == station_id:
		local_message = "That station is already the last stop."
		return
	route.append(station_id)
	lines[selected_line_id]["route"] = route
	lines[selected_line_id]["name"] = _line_name_for_route(route)
	_reapply_line_to_assigned_trains(selected_line_id)
	local_message = "Added %s to %s." % [station_by_id[station_id]["name"], lines[selected_line_id]["name"]]

func _line_has_valid_orders(line_id: String) -> bool:
	return lines.has(line_id) and (lines[line_id].get("route", []) as Array).size() >= 2

func _reapply_line_to_assigned_trains(line_id: String) -> void:
	for t in trains:
		if String(t.get("line_id", "")) == line_id:
			if _line_has_valid_orders(line_id):
				_assign_train_to_line(t, line_id)
			else:
				t["route"] = []
				t["path"] = []
				t["path_index"] = 0
				t["state"] = "WaitingForOrders"
				t["wait_reason"] = "Line needs at least two stops."

func _select_train_from_dispatch(train_id: String) -> void:
	selected_train_id = train_id
	selected_signal_pos = Vector2i(-999, -999)
	local_message = "%s selected." % train_id
	_refresh_local_side_text()
	queue_redraw()

func _route_station_names(route: Array, show_repeat: bool = false) -> String:
	var names: Array[String] = []
	for station_id in route:
		if station_by_id.has(station_id):
			names.append(String(station_by_id[station_id].get("name", station_id)))
	if show_repeat and route.size() > 1:
		var first_id: String = String(route[0])
		if station_by_id.has(first_id) and String(route[route.size() - 1]) != first_id:
			names.append(String(station_by_id[first_id].get("name", first_id)))
		return "%s (repeat)" % " -> ".join(names)
	return " -> ".join(names)

func _line_cargo_preview(line_id: String) -> String:
	if line_id == "" or not lines.has(line_id):
		return "Select a line to preview its orders and cargo."
	var route: Array = lines[line_id]["route"]
	var line: Dictionary = lines[line_id]
	var text := "[b]%s[/b]\nOrders: %s\n" % [line["name"], _route_station_names(route, true) if not route.is_empty() else "No stops yet"]
	if editing_line_stops and line_id == selected_line_id:
		text += "Editing: tap station plus signs on the map, then use Complete Line.\n"
	if route.size() < 2:
		text += "Needs at least two stops before trains can run.\n"
		text += "Assigned trains: %d\nAvailable trains: %d" % [_line_train_count(line_id), _available_train_count()]
		return text
	var kind: String = local.get("kind", "")
	if kind == "coal":
		text += "Expected cargo: coal from %s to %s.\n" % [station_by_id[route[0]]["name"], station_by_id[route[1]]["name"]]
	elif kind == "yard":
		text += "Expected cargo: freight loads at source stops and unloads at sink stops. Yard stops add dwell time if the line includes them.\n"
	elif kind == "steel":
		text += "Expected cargo: coal to Steelworks, then steel to Export Platform.\n"
	else:
		text += "Expected cargo follows station production and acceptance.\n"
	text += "Assigned trains: %d\nAvailable trains: %d" % [_line_train_count(line_id), _available_train_count()]
	return text

func _refresh_dispatch_panel() -> void:
	if dispatch_line_box == null or dispatch_train_box == null or dispatch_preview == null:
		return
	_clear_control_children(dispatch_line_box)
	_clear_control_children(dispatch_train_box)

	var line_header := Label.new()
	line_header.text = "Lines"
	line_header.add_theme_color_override("font_color", Color.html("#172028"))
	dispatch_line_box.add_child(line_header)
	if lines.is_empty():
		var empty_line := Label.new()
		empty_line.text = "Create a service below."
		empty_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_line.add_theme_color_override("font_color", Color.html("#33424a"))
		dispatch_line_box.add_child(empty_line)
	else:
		for line_id in lines.keys():
			var line: Dictionary = lines[line_id]
			var route: Array = line.get("route", [])
			var status := "%d stops, %d trains" % [route.size(), _line_train_count(line_id)]
			if route.size() < 2:
				status = "needs stops"
			var label := "%s\n%s" % [line["name"], status]
			_add_dispatch_button(dispatch_line_box, label, line_id == selected_line_id, func(id := String(line_id)): _select_line_from_dispatch(id))
	for station_id in station_by_id.keys():
		var st: Dictionary = station_by_id[station_id]
		if st.get("role", "") == "source":
			var line_id := _line_id_for_source(station_id)
			if not lines.has(line_id) and not _route_for_source(station_id).is_empty():
				_add_dispatch_button(dispatch_line_box, "Create\n%s Line" % st["name"], false, func(id := String(station_id)): _create_line_from_dispatch(id))

	var train_header := Label.new()
	train_header.text = "Trains"
	train_header.add_theme_color_override("font_color", Color.html("#172028"))
	dispatch_train_box.add_child(train_header)
	if trains.is_empty():
		var empty_train := Label.new()
		empty_train.text = "Buy depot stock."
		empty_train.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_train.add_theme_color_override("font_color", Color.html("#33424a"))
		dispatch_train_box.add_child(empty_train)
	else:
		for t in trains:
			var train_id := String(t["id"])
			var line_label := "Available"
			if String(t.get("line_id", "")) != "" and lines.has(t["line_id"]):
				line_label = String(lines[t["line_id"]]["name"])
			var cargo_text := _cargo_label(t)
			var state_label := String(t.get("state", ""))
			if not _is_train_on_map(t) and String(t.get("line_id", "")) != "":
				state_label = "Queued in depot"
			var next_label := ""
			if String(t.get("line_id", "")) != "" and not (t.get("route", []) as Array).is_empty():
				next_label = "\nNext: %s" % _next_stop_name_for_train(t)
			var label := "%s  %s\n%s\n%s%s" % [train_id, cargo_text, line_label, state_label, next_label]
			_add_dispatch_button(dispatch_train_box, label, train_id == selected_train_id, func(id := train_id): _select_train_from_dispatch(id))

	dispatch_preview.text = _line_cargo_preview(selected_line_id)

func _assign_train_to_line(t: Dictionary, line_id: String) -> void:
	if not _line_has_valid_orders(line_id):
		t["line_id"] = line_id
		t["route"] = []
		t["path"] = []
		t["path_index"] = 0
		t["state"] = "WaitingForOrders"
		t["wait_reason"] = "Line needs at least two stops."
		t["tile"] = _off_map_tile()
		t["pos"] = Vector2(-1000, -1000)
		return
	var route: Array = (lines[line_id]["route"] as Array).duplicate()
	t["line_id"] = line_id
	t["route"] = route
	t["stop_index"] = 1
	t["tile"] = _off_map_tile()
	t["pos"] = Vector2(-1000, -1000)
	t["path"] = []
	t["path_index"] = 0
	t["cargo"] = ""
	t["cargo_amount"] = 0
	t["state"] = "WaitingForPlatform"
	t["wait_reason"] = "Queued in depot until the line's first platform and exit path are clear."
	t["wait_time"] = 0.0
	t["dwell"] = 0.0
	t["handled_yard"] = false
	_try_dispatch_train_from_depot(t)
	queue_redraw()

func _restart_trains_only() -> void:
	var selected_exists := false
	selected_signal_pos = Vector2i(-999, -999)
	local["delivered"] = 0
	local["processed"] = 0
	local["productive_progress"] = 0
	local["steel_buffer"] = 0
	local["coal_buffer"] = 0
	local["production_remainder"] = 0.0
	local["deadlocks"] = 0
	local["max_queue"] = 0
	tile_reservations.clear()
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		if st.get("role", "") == "source":
			st["stored"] = 240
	for t in trains:
		if String(t.get("id", "")) == selected_train_id:
			selected_exists = true
		_reset_train_for_restart(t)
	_dispatch_waiting_trains()
	if not selected_exists:
		selected_train_id = ""
	local_message = "Trains reset to depot/start positions. Track, signals, platforms, and lines are unchanged."
	_update_status_labels()
	_refresh_local_side_text()
	queue_redraw()

func _reset_train_for_restart(t: Dictionary) -> void:
	var line_id := String(t.get("line_id", ""))
	t["path"] = []
	t["path_index"] = 0
	t["cargo"] = ""
	t["cargo_amount"] = 0
	t["wait_time"] = 0.0
	t["total_wait"] = 0.0
	t["dwell"] = 0.0
	t["handled_yard"] = false
	t["reset_to_source"] = false
	t["tile"] = _off_map_tile()
	t["pos"] = Vector2(-1000, -1000)
	if line_id == "":
		t["route"] = []
		t["stop_index"] = 0
		t["state"] = "Available"
		t["wait_reason"] = ""
		return
	if _line_has_valid_orders(line_id):
		t["route"] = (lines[line_id]["route"] as Array).duplicate()
		t["stop_index"] = 1
		t["state"] = "WaitingForPlatform"
		t["wait_reason"] = "Queued in depot until the line's first platform and exit path are clear."
	else:
		t["route"] = []
		t["stop_index"] = 0
		t["state"] = "WaitingForOrders"
		t["wait_reason"] = "Line needs at least two stops."

func _buy_train_at(gp: Vector2i) -> void:
	if not station_by_pos.has(gp):
		local_message = "Click a green source station to buy a train there."
		return
	var station_id: String = station_by_pos[gp]
	var st: Dictionary = station_by_id[station_id]
	if st.get("role", "") != "source":
		local_message = "Trains must be bought at a source station, not at %s." % st.get("name", "that station")
		return
	var line_id: String = _create_or_get_line_for_source(station_id)
	if line_id == "":
		local_message = "No line can start at %s." % st.get("name", "that station")
		return
	selected_line_id = line_id
	_buy_train_for_line(line_id)

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
	if local.get("route_toggle", false) and sc.has("alt_route"):
		source_id = sc["alt_route"][0]
	local["route_toggle"] = !local.get("route_toggle", false)
	var line_id: String = _create_or_get_line_for_source(source_id)
	if line_id == "":
		local_message = "No line can start at %s." % source_id
		return
	selected_line_id = line_id
	_buy_train_for_line(line_id)

func _buy_train_for_source(source_id: String) -> void:
	var line_id: String = _create_or_get_line_for_source(source_id)
	if line_id == "":
		local_message = "No line can start at %s." % source_id
		return
	_buy_train_for_line(line_id)

func _buy_train_for_line(line_id: String, spend_money: bool = true) -> void:
	if not lines.has(line_id):
		local_message = "Select or create a line first."
		return
	var route: Array = (lines[line_id]["route"] as Array).duplicate()
	if route.size() < 2:
		local_message = "Line needs at least two stops before trains can run."
		return
	if spend_money and not _spend(300, 0):
		return
	var start_station: Dictionary = station_by_id[route[0]]
	var t := _new_train_record(start_station["pos"])
	t["line_id"] = line_id
	t["route"] = route
	t["stop_index"] = 1
	t["state"] = "WaitingForPlatform"
	t["wait_reason"] = "Queued in depot until the line's first platform and exit path are clear."
	train_seq += 1
	trains.append(t)
	if spend_money:
		local["infra_cost"] += 300
	_try_dispatch_train_from_depot(t)
	local_message = "%s bought on %s. Route: %s." % [t["name"], lines[line_id]["name"], " -> ".join(route)]
	selected_tool = "track"
	_refresh_tool_button_styles()
	_update_status_labels()
	_refresh_local_side_text()

func _dispatch_waiting_trains() -> void:
	for t in trains:
		if not _is_train_on_map(t) and String(t.get("line_id", "")) != "" and _line_has_valid_orders(String(t.get("line_id", ""))):
			_try_dispatch_train_from_depot(t)

func _try_dispatch_train_from_depot(t: Dictionary) -> bool:
	if _is_train_on_map(t):
		return true
	var route: Array = t.get("route", [])
	if route.size() < 2:
		t["state"] = "WaitingForOrders"
		t["wait_reason"] = "Line needs at least two stops."
		return false
	var start_station: Dictionary = station_by_id[route[0]]
	var start_pos: Vector2i = start_station["pos"]
	if _tile_train_count(start_pos, String(t["id"])) >= _station_capacity_at(start_pos):
		t["state"] = "WaitingForPlatform"
		t["wait_reason"] = "%s platforms are full. Train remains in depot." % start_station.get("name", "Source")
		return false
	t["tile"] = start_pos
	t["pos"] = _grid_to_screen(start_pos)
	t["path"] = []
	t["path_index"] = 0
	t["cargo"] = ""
	t["cargo_amount"] = 0
	t["state"] = "Idle"
	t["wait_reason"] = ""
	t["wait_time"] = 0.0
	t["dwell"] = 0.0
	t["handled_yard"] = false
	_process_cargo_at_station(t, start_station)
	_plan_next_path(t)
	return true

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
	_dispatch_waiting_trains()
	_refresh_reservations()
	var progress_before := _objective_progress()
	for t in trains:
		_update_train(t, delta)
		_refresh_reservations()
	var progress_after := _objective_progress()
	if progress_after > progress_before:
		elapsed_since_progress = 0.0
	else:
		elapsed_since_progress += delta
	_detect_congestion(delta)
	_update_status_labels()
	_refresh_local_side_text()
	if _objective_complete():
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
	if (t.get("route", []) as Array).is_empty():
		if String(t.get("line_id", "")) == "":
			t["state"] = "Available"
			t["wait_reason"] = ""
		else:
			t["state"] = "WaitingForOrders"
			t["wait_reason"] = "Line needs at least two stops."
		return
	if not _is_train_on_map(t):
		t["state"] = "WaitingForPlatform"
		if String(t.get("wait_reason", "")) == "":
			t["wait_reason"] = "Queued in depot until the first platform is clear."
		t["wait_time"] = float(t["wait_time"]) + delta
		t["total_wait"] = float(t["total_wait"]) + delta
		return
	if float(t.get("dwell", 0.0)) > 0.0:
		t["dwell"] = max(0.0, float(t["dwell"]) - delta)
		t["state"] = String(t.get("dwell_state", "Loading" if t.get("cargo_amount", 0) == 0 else "Unloading"))
		return
	if (t["path"] as Array).is_empty() or int(t["path_index"]) >= (t["path"] as Array).size():
		if t.get("state", "") == "NoRoute":
			t["wait_time"] = float(t["wait_time"]) + delta
			t["total_wait"] = float(t["total_wait"]) + delta
			if float(t["wait_time"]) > 1.5:
				t["wait_time"] = 0.0
				_plan_next_path(t)
			return
		_handle_station_arrival(t)
		return
	var next_tile: Vector2i = t["path"][int(t["path_index"])]
	var allowed := _can_enter_next_tile(t, next_tile)
	if not allowed:
		t["wait_time"] = float(t["wait_time"]) + delta
		t["total_wait"] = float(t["total_wait"]) + delta
		if float(t["wait_time"]) > 1.5:
			_plan_next_path(t)
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
		var cargo_before: int = int(t.get("cargo_amount", 0))
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
			t["dwell_state"] = "Loading"
			_plan_next_path(t)
			return
		t["dwell"] = 0.8
		t["dwell_state"] = _station_dwell_state(t, st, cargo_before)
		t["state"] = String(t["dwell_state"])
		t["handled_yard"] = false
		t["stop_index"] = (int(t["stop_index"]) + 1) % (t["route"] as Array).size()
		_skip_current_station_target(t, tile)
	_plan_next_path(t)

func _station_dwell_state(t: Dictionary, st: Dictionary, cargo_before: int) -> String:
	var role := String(st.get("role", ""))
	if role == "yard":
		return "YardStop"
	if role == "source" and int(t.get("cargo_amount", 0)) > cargo_before:
		return "Loading"
	if role == "sink" and cargo_before > int(t.get("cargo_amount", 0)):
		return "Unloading"
	if role == "processor":
		return "Processing"
	return "StationStop"

func _skip_current_station_target(t: Dictionary, tile: Vector2i) -> void:
	var route: Array = t["route"]
	if route.is_empty():
		return
	var guard := 0
	while guard < route.size():
		var target_station: Dictionary = station_by_id[route[int(t["stop_index"])]]
		if target_station["pos"] != tile:
			return
		t["stop_index"] = (int(t["stop_index"]) + 1) % route.size()
		guard += 1

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
			_record_productive_output(int(t["cargo_amount"]))
			t["cargo_amount"] = 0
			t["cargo"] = ""
	elif kind == "yard":
		if st.get("role", "") == "source" and int(t["cargo_amount"]) == 0:
			t["cargo"] = "freight"
			t["cargo_amount"] = min(int(t["capacity"]), 10)
		elif st.get("role", "") == "yard":
			t["dwell"] = max(float(t.get("dwell", 0.0)), 1.2 / max(1, int(st.get("platforms", 1))))
		elif st.get("role", "") == "sink" and t.get("cargo", "") == "freight":
			var processed: int = max(1, int(floor(float(t.get("cargo_amount", 0)) / 10.0)))
			local["processed"] = int(local["processed"]) + processed
			_record_productive_output(processed)
			t["cargo_amount"] = 0
			t["cargo"] = ""
	elif kind == "steel":
		if st["id"] == "coal_input" and int(t["cargo_amount"]) == 0:
			var coal: int = min(int(t["capacity"]), int(st.get("stored", 0)))
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
				var steel: int = min(int(t["capacity"]), int(local["steel_buffer"]))
				local["steel_buffer"] = int(local["steel_buffer"]) - steel
				t["cargo"] = "steel"
				t["cargo_amount"] = steel
		elif st["id"] == "export_platform" and t.get("cargo", "") == "steel":
			local["delivered"] = int(local["delivered"]) + int(t["cargo_amount"])
			_record_productive_output(int(t["cargo_amount"]))
			t["cargo"] = ""
			t["cargo_amount"] = 0

func _record_productive_output(amount: int) -> void:
	if _active_train_count() >= _fleet_goal():
		local["productive_progress"] = int(local.get("productive_progress", 0)) + amount

func _plan_next_path(t: Dictionary) -> void:
	var route: Array = t["route"]
	if route.is_empty():
		return
	var target_station: Dictionary = station_by_id[route[int(t["stop_index"])]]
	var path := _find_path(t["tile"], target_station["pos"], t["id"])
	if path.is_empty():
		path = _find_path(t["tile"], target_station["pos"])
	if path.is_empty():
		t["state"] = "NoRoute"
		t["wait_reason"] = _route_failure_reason(t["tile"], target_station["pos"])
	else:
		t["path"] = path
		t["path_index"] = 0
		t["state"] = "Idle"
		t["wait_reason"] = ""

func _route_failure_reason(start: Vector2i, goal: Vector2i) -> String:
	var physical_path := _find_track_path_ignore_signals(start, goal)
	if physical_path.is_empty():
		return "No connected rail reaches %s. Draw explicit track segments between the line stops." % _tile_label(goal)
	var current := start
	for next in physical_path:
		if _signal_controls_departure(current) and not _signal_faces_movement(current, next):
			var needed_dir: Vector2i = next - current
			return "Signal at %s only opens %s, but this train needs %s. Follow the bright arrow on the gate: rotate it, or click it with the signal tool again to make it double." % [
				_tile_label(current),
				_dir_screen_name(_signal_dir(current)),
				_dir_screen_name(needed_dir)
			]
		current = next
	return "No legal route reaches %s. Check one-way signal directions or missing explicit track segments." % _tile_label(goal)

func _find_track_path_ignore_signals(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not tracks.has(start) or not tracks.has(goal):
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for n in _track_neighbors_toward(current, goal):
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

func _tile_label(tile: Vector2i) -> String:
	if station_by_pos.has(tile):
		var station_id: String = station_by_pos[tile]
		return String(station_by_id[station_id].get("name", station_id))
	return "(%d,%d)" % [tile.x, tile.y]

func _find_path(start: Vector2i, goal: Vector2i, own_id: String = "") -> Array:
	if not tracks.has(start) or not tracks.has(goal):
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0.0}
	while not frontier.is_empty():
		var current: Vector2i = _pop_lowest_cost(frontier, cost_so_far)
		if current == goal:
			break
		for n in _track_neighbors_toward(current, goal):
			if _signal_controls_departure(current) and not _signal_faces_movement(current, n):
				continue
			var new_cost: float = float(cost_so_far[current]) + _path_step_cost(n, current, goal, own_id)
			if not cost_so_far.has(n) or new_cost < float(cost_so_far[n]):
				cost_so_far[n] = new_cost
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

func _pop_lowest_cost(frontier: Array[Vector2i], cost_so_far: Dictionary) -> Vector2i:
	var best_index := 0
	var best_cost := float(cost_so_far.get(frontier[0], 0.0))
	for i in range(1, frontier.size()):
		var candidate_cost := float(cost_so_far.get(frontier[i], 0.0))
		if candidate_cost < best_cost:
			best_index = i
			best_cost = candidate_cost
	return frontier.pop_at(best_index)

func _path_step_cost(next_tile: Vector2i, current: Vector2i, goal: Vector2i, own_id: String) -> float:
	var cost := 1.0 + _path_step_score(next_tile, current, goal) * 0.01
	if own_id != "":
		if next_tile != goal and _tile_has_train(next_tile, own_id) != "":
			cost += 30.0
		var reserved_by := _tile_reserved_by_other(next_tile, own_id)
		if reserved_by != "":
			cost += 18.0
		var block_id := int(block_for_tile.get(next_tile, -1))
		if block_id >= 0 and _block_occupied_by_other(block_id, own_id) != "":
			cost += 8.0
	return cost

func _signal_controls_departure(pos: Vector2i) -> bool:
	return signals.has(pos)

func _refresh_reservations() -> void:
	tile_reservations.clear()
	for t in trains:
		if not _is_train_on_map(t):
			continue
		var train_id := String(t.get("id", ""))
		var path: Array = t.get("path", [])
		var start_index := int(t.get("path_index", 0))
		if _signal_departure_has_actual_blocker(t, path, start_index):
			continue
		var lookahead: int = _reservation_lookahead(t, path, start_index)
		var claim: Array[Vector2i] = []
		var claim_conflicts := false
		for i in range(start_index, lookahead):
			var p: Vector2i = path[i]
			if _tile_has_train(p, train_id) != "":
				claim_conflicts = true
				break
			var reserved_by := String(tile_reservations.get(p, ""))
			if reserved_by != "" and reserved_by != train_id:
				claim_conflicts = true
				break
			claim.append(p)
			if i > start_index and (signals.has(p) or station_by_pos.has(p)):
				break
		if claim_conflicts:
			continue
		for p in claim:
			tile_reservations[p] = train_id

func _reservation_lookahead(t: Dictionary, path: Array, start_index: int) -> int:
	if path.is_empty() or start_index >= path.size():
		return start_index
	var default_lookahead: int = min(path.size(), start_index + 5)
	var cur: Vector2i = t["tile"]
	if not _signal_controls_departure(cur):
		return default_lookahead
	var next_tile: Vector2i = path[start_index]
	if not _signal_faces_movement(cur, next_tile):
		return default_lookahead
	var sig_type: String = _signal_type_for_dir(cur, next_tile - cur)
	var signal_lookahead: int = default_lookahead
	for i in range(start_index, min(path.size(), start_index + 10)):
		signal_lookahead = i + 1
		var p: Vector2i = path[i]
		if i > start_index and (station_by_pos.has(p) or (sig_type != "chain" and signals.has(p))):
			break
	return signal_lookahead

func _signal_departure_has_actual_blocker(t: Dictionary, path: Array, start_index: int) -> bool:
	if path.is_empty() or start_index >= path.size():
		return false
	var cur: Vector2i = t["tile"]
	if not _signal_controls_departure(cur):
		return false
	var next_tile: Vector2i = path[start_index]
	if not _signal_faces_movement(cur, next_tile):
		return true
	var sig_type: String = _signal_type_for_dir(cur, next_tile - cur)
	var scan_limit: int = path.size() if sig_type == "block" else min(path.size(), start_index + 7)
	for i in range(start_index, scan_limit):
		var p: Vector2i = path[i]
		var blocker := _tile_entry_blocker(p, String(t["id"]))
		if blocker != "":
			return true
		var reserved_by := _tile_reserved_by_other(p, String(t["id"]))
		if reserved_by != "":
			return true
		if i > start_index and (station_by_pos.has(p) or (sig_type != "chain" and signals.has(p))):
			break
	return false

func _tile_reserved_by_other(tile: Vector2i, own_id: String) -> String:
	var reserved_by := String(tile_reservations.get(tile, ""))
	if reserved_by != "" and reserved_by != own_id:
		return reserved_by
	return ""

func _can_enter_next_tile(t: Dictionary, next_tile: Vector2i) -> bool:
	var other := _tile_entry_blocker(next_tile, t["id"])
	if other != "":
		t["state"] = "Blocked"
		t["wait_reason"] = "Next tile is occupied by %s." % other
		return false
	var reserved_by := _tile_reserved_by_other(next_tile, t["id"])
	if reserved_by != "":
		t["state"] = "WaitingAtSignal"
		t["wait_reason"] = "Next tile is reserved by %s." % reserved_by
		return false
	var cur: Vector2i = t["tile"]
	var direction := Vector2(next_tile - cur)
	if direction.length_squared() > 0.0:
		t["dir"] = direction.normalized()
	if _signal_controls_departure(cur) and not _signal_faces_movement(cur, next_tile):
		t["state"] = "WaitingAtSignal"
		t["wait_reason"] = "Signal only opens %s, but this train needs %s. Follow the bright arrow on the gate: rotate it or click it with the signal tool again to make it double." % [
			_dir_screen_name(_signal_dir(cur)),
			_dir_screen_name(next_tile - cur)
		]
		return false
	if _signal_controls_departure(cur) and _signal_faces_movement(cur, next_tile):
		var sig_type: String = _signal_type_for_dir(cur, next_tile - cur)
		if sig_type == "block":
			var blocker := _block_signal_blocker(t)
			if blocker != "":
				t["state"] = "WaitingAtSignal"
				t["wait_reason"] = "Next signal section is occupied by %s. Add a passing loop or split long blocks with signals." % blocker
				return false
		else:
			var chain_reason := _chain_signal_blocker(t)
			if chain_reason != "":
				t["state"] = "WaitingAtSignal"
				t["wait_reason"] = chain_reason
				return false
	return true

func _signal_faces_movement(signal_pos: Vector2i, next_tile: Vector2i) -> bool:
	return _signal_dirs(signal_pos).has(next_tile - signal_pos)

func _block_signal_blocker(t: Dictionary) -> String:
	var path: Array = t["path"]
	for i in range(int(t["path_index"]), path.size()):
		var p: Vector2i = path[i]
		var blocker := _tile_entry_blocker(p, t["id"])
		if blocker != "":
			return blocker
		var reserved_by := _tile_reserved_by_other(p, t["id"])
		if reserved_by != "":
			return reserved_by
		if i > int(t["path_index"]) and (signals.has(p) or station_by_pos.has(p)):
			break
	return ""

func _chain_signal_blocker(t: Dictionary) -> String:
	var path: Array = t["path"]
	for i in range(int(t["path_index"]), min(path.size(), int(t["path_index"]) + 7)):
		var p: Vector2i = path[i]
		var blocker := _tile_entry_blocker(p, t["id"])
		if blocker != "":
			return "Chain signal is red: exit path is blocked by %s. Keep junction entries protected by chain signals." % blocker
		var reserved_by := _tile_reserved_by_other(p, t["id"])
		if reserved_by != "":
			return "Chain signal is red: exit path is reserved by %s." % reserved_by
		if i > int(t["path_index"]) and station_by_pos.has(p):
			break
	return ""

func _tile_has_train(tile: Vector2i, own_id: String) -> String:
	for t in trains:
		if not _is_train_on_map(t):
			continue
		if t["id"] != own_id and t["tile"] == tile:
			return t["id"]
	return ""

func _tile_train_count(tile: Vector2i, own_id: String = "") -> int:
	var count := 0
	for t in trains:
		if not _is_train_on_map(t):
			continue
		if String(t.get("id", "")) != own_id and t.get("tile", Vector2i(-999, -999)) == tile:
			count += 1
	return count

func _station_capacity_at(tile: Vector2i) -> int:
	if not station_by_pos.has(tile):
		return 1
	var station_id: String = station_by_pos[tile]
	var st: Dictionary = station_by_id[station_id]
	return max(1, int(st.get("platforms", 1)))

func _tile_entry_blocker(tile: Vector2i, own_id: String) -> String:
	var blocker := _tile_has_train(tile, own_id)
	if blocker == "":
		return ""
	if station_by_pos.has(tile) and _tile_train_count(tile, own_id) < _station_capacity_at(tile):
		return ""
	return blocker

func _block_occupied_by_other(block_id: int, own_id: String) -> String:
	var occupants := _block_occupants(block_id, own_id)
	return occupants[0] if not occupants.is_empty() else ""

func _block_occupants(block_id: int, own_id: String = "") -> Array[String]:
	var occupants: Array[String] = []
	if block_id < 0:
		return occupants
	for t in trains:
		if not _is_train_on_map(t):
			continue
		if t["id"] != own_id and int(block_for_tile.get(t["tile"], -2)) == block_id:
			occupants.append(String(t["id"]))
	return occupants

func _deadlock_progress_grace() -> float:
	var grid: Vector2i = local.get("scenario", {}).get("grid", Vector2i(14, 9))
	return max(8.0, float(grid.x) * 0.9)

func _detect_congestion(delta: float) -> void:
	var queue := 0
	for t in trains:
		if String(t.get("state", "")).begins_with("Waiting") or t.get("state", "") == "Blocked":
			queue += 1
	local["max_queue"] = max(int(local.get("max_queue", 0)), queue)
	deadlock_cooldown = max(0.0, deadlock_cooldown - delta)
	if queue >= 2 and elapsed_since_progress > _deadlock_progress_grace() and deadlock_cooldown <= 0.0:
		local["deadlocks"] = int(local.get("deadlocks", 0)) + 1
		deadlock_cooldown = 10.0
		local_message = "Deadlock detected. Replace junction entry block signals with chain signals or add an exit path."

func _complete_scenario() -> void:
	var sc: Dictionary = local["scenario"]
	var avg_wait := _average_wait()
	var fleet_goal := _fleet_goal()
	var fleet_met := _active_train_count() >= fleet_goal
	var productive: bool = fleet_met and avg_wait <= float(local["wait_target"]) and int(local.get("deadlocks", 0)) == 0
	var quality := "Productive network" if productive else "Completed with reliability warnings"
	result_data = {
		"id": local["id"],
		"name": local["name"],
		"text": "[b]%s[/b]\n\n%s: %d / %d\nTotal Output: %d\nFleet: %d / %d trains\nAverage Train Wait: %.1fs / %.0fs target\nDeadlocks: %d\nMaximum Queue: %d\nInfrastructure Cost: $%d\n\nRegional Effect:\n+$%d per cycle\n+%d Materials per cycle\n+%d Traffic Load\n+%d Traffic Capacity" % [
			quality,
			_progress_label(),
			_completion_progress(),
			int(local["target"]),
			_objective_progress(),
			_active_train_count(),
			fleet_goal,
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

func _completion_progress() -> int:
	if _fleet_goal() > 1:
		return int(local.get("productive_progress", 0))
	return _objective_progress()

func _progress_label() -> String:
	if _fleet_goal() > 1:
		return "Productive output"
	return "Output"

func _fleet_goal() -> int:
	return max(1, int(local.get("fleet_goal", 1)))

func _objective_complete() -> bool:
	return _completion_progress() >= int(local["target"]) and _active_train_count() >= _fleet_goal()

func _average_wait() -> float:
	var total := 0.0
	var count := 0
	for t in trains:
		if String(t.get("line_id", "")) == "":
			continue
		total += float(t.get("total_wait", 0.0))
		count += 1
	if count == 0:
		return 0.0
	return total / float(count)

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
		if tracks.has(n) and _has_track_segment(p, n):
			out.append(n)
	return out

func _track_neighbors_toward(p: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out := _track_neighbors(p)
	var sorted: Array[Vector2i] = []
	for n in out:
		var inserted := false
		for i in range(sorted.size()):
			if _path_step_score(n, p, goal) < _path_step_score(sorted[i], p, goal):
				sorted.insert(i, n)
				inserted = true
				break
		if not inserted:
			sorted.append(n)
	return sorted

func _path_step_score(next_tile: Vector2i, current: Vector2i, goal: Vector2i) -> float:
	var to_goal := Vector2(goal - next_tile)
	var step := Vector2(next_tile - current)
	var direct := Vector2(goal - current)
	var score := to_goal.length_squared()
	if direct.length_squared() > 0.0 and step.length_squared() > 0.0:
		score -= step.normalized().dot(direct.normalized()) * 0.25
	return score

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
		top_status.text = "%s   Money: $%d   Materials: %d   %s: %d / %d   Avg Wait: %.1fs   Fleet: %d / %d   Tool: %s" % [
			local.get("name", ""),
			local.get("money", 0),
			local.get("materials", 0),
			_progress_label(),
			_completion_progress(),
			local.get("target", 0),
			_average_wait(),
			_active_train_count(),
			_fleet_goal(),
			selected_tool.capitalize()
		]
	else:
		top_status.text = "Scenario results"

func _refresh_regional_side_text() -> void:
	if side_text == null:
		return
	var text: String = "[b]Regional Network[/b]\n\n"
	text += "Completed local maps permanently add outputs to this small region.\n\n"
	for s in scenarios:
		var state := "Completed" if campaign["completed"].has(s["id"]) else ("Available" if _scenario_is_available(s["id"]) else "Locked")
		text += "[b]%s[/b] - %s\n%s\n\n" % [s["name"], state, s["objective"]]
	if int(campaign["traffic_load"]) > int(campaign["traffic_capacity"]):
		text += "[color=orange]Network Congested[/color]\nTraffic load exceeds capacity. Future maps begin under extra pressure.\n"
	side_text.text = text

func _refresh_local_side_text() -> void:
	if side_text == null or screen != Screen.LOCAL:
		return
	var scenario: Dictionary = local.get("scenario", {})
	var text: String = "[font_size=21][b]%s[/b][/font_size]\n" % local.get("name", "")
	text += "[b]Objectives[/b]\n"
	text += "%s: %d / %d\n" % [_progress_label(), _completion_progress(), int(local.get("target", 0))]
	if _fleet_goal() > 1:
		text += "Total output: %d\n" % _objective_progress()
	text += "Running fleet: %d / %d trains\n" % [_active_train_count(), _fleet_goal()]
	text += "Depot stock: %d available\n" % _available_train_count()
	text += "Average wait target: %.0fs\n\n" % float(local.get("wait_target", 0.0))
	if scenario.get("briefing", "") != "":
		text += "[b]Contract Brief[/b]\n%s\n\n" % scenario["briefing"]
	if scenario.get("guide_label", "") != "":
		var guide_state := "shown" if planning_guide_open else "hidden"
		text += "[b]Planning Guide[/b]\n%s It is currently %s.\n\n" % [scenario["guide_label"], guide_state]
	text += "[b]Signals[/b]\n"
	text += "Block: use on straight track after stations or junction exits. Green means the next section is clear.\n"
	text += "Chain: use before a junction. Green means the train can enter and also leave the junction.\n"
	text += "Double: click an existing block or chain signal again to protect both directions on that rail tile.\n"
	text += "Right-hand running: on double track, route eastbound trains on the lower/south rail and westbound trains on the upper/north rail.\n"
	if signal_help_open:
		text += "Signal Help: colored rail sections are blocks. Red sections contain a train or a reserved path. Click a signal to see exactly what it faces.\n"
	text += "\n"
	text += "[b]Message[/b]\n%s\n\n" % local_message
	text += "[b]Controls[/b]\nDrag Track to draw rail. Create/select a line, Edit Stops, tap station plus signs, then Complete Line. Assign depot trains to finished lines. Plan Guide shows one possible layout. Signal Help shows blocks. Restart Trains keeps infrastructure; Reset Map clears it.\n\n"
	if selected_train_id != "":
		for t in trains:
			if t["id"] == selected_train_id:
				text += "[b]%s[/b]\nState: %s\nCargo: %s %d/%d\nNext stop: %s\nNext rail leg: %s\nReason: %s\nSuggestion: %s\n\n" % [
					t["name"],
					t["state"],
					t.get("cargo", "none") if t.get("cargo", "") != "" else "none",
					t.get("cargo_amount", 0),
					t.get("capacity", 0),
					_next_stop_name_for_train(t),
					_next_leg_name_for_train(t),
					_display_reason_for_train(t),
					_suggestion_for_train(t)
				]
				if String(t.get("line_id", "")) != "" and lines.has(t["line_id"]):
					text += "Line: %s\n\n" % lines[t["line_id"]]["name"]
	if selected_signal_pos.x > -900:
		var bid := int(block_for_tile.get(selected_signal_pos, -1))
		text += "[b]Selected Signal[/b]\nType: %s\nFacing: %s\nBlock: %s\nStatus: %s\nUse: %s\n\n" % [_signal_type(selected_signal_pos), _dir_name(_signal_dir(selected_signal_pos)), bid, _signal_summary(selected_signal_pos), _signal_use_text(selected_signal_pos)]
	text += "[b]Stats[/b]\nDeadlocks: %d\nMax Queue: %d\nInfrastructure Cost: $%d\n" % [local.get("deadlocks", 0), local.get("max_queue", 0), local.get("infra_cost", 0)]
	if local.get("kind", "") == "steel":
		text += "Steelworks buffer: %d steel\n" % int(local.get("steel_buffer", 0))
	side_text.text = text
	_refresh_dispatch_panel()

func _suggestion_for_train(t: Dictionary) -> String:
	var reason := _display_reason_for_train(t)
	if (reason.contains("faces") or reason.contains("only opens")) and reason.contains("needs"):
		return "Rotate that signal to the needed direction, or click it with the signal tool again if trains must run both ways."
	if reason.contains("No valid route"):
		return "Connect every stop on the route with orthogonal track."
	if reason.contains("No connected rail"):
		return "Draw explicit track segments between the line stops."
	if reason.contains("Chain"):
		return "Place chain signals before junctions and block signals at clear exits."
	if reason.contains("occupied"):
		return "Split the line into smaller blocks or add a passing loop."
	if reason.contains("tile"):
		return "Add siding space or reduce the number of trains."
	return "Keep cargo flowing and watch for red signals."

func _next_stop_name_for_train(t: Dictionary) -> String:
	var route: Array = t.get("route", [])
	if route.is_empty():
		return "none"
	var stop_index := int(t.get("stop_index", 0))
	if stop_index < 0 or stop_index >= route.size():
		return "none"
	var station_id := String(route[stop_index])
	if not station_by_id.has(station_id):
		return station_id
	return String(station_by_id[station_id].get("name", station_id))

func _next_leg_name_for_train(t: Dictionary) -> String:
	if not _is_train_on_map(t):
		return "waiting for platform"
	var cur: Vector2i = t.get("tile", _off_map_tile())
	var path: Array = t.get("path", [])
	var path_index := int(t.get("path_index", 0))
	if path_index >= 0 and path_index < path.size():
		var next_tile: Vector2i = path[path_index]
		return _dir_screen_name(next_tile - cur)
	var route: Array = t.get("route", [])
	if route.is_empty():
		return "none"
	var stop_index := int(t.get("stop_index", 0))
	if stop_index < 0 or stop_index >= route.size():
		return "none"
	var station_id := String(route[stop_index])
	if not station_by_id.has(station_id):
		return "none"
	var target_station: Dictionary = station_by_id[station_id]
	var physical_path := _find_track_path_ignore_signals(cur, target_station["pos"])
	if physical_path.is_empty():
		return "no connected rail"
	return _dir_screen_name(physical_path[0] - cur)

func _display_reason_for_train(t: Dictionary) -> String:
	var state := String(t.get("state", ""))
	var reason := String(t.get("wait_reason", ""))
	if reason == "":
		if state == "YardStop":
			return "Working through the yard stop."
		if state in ["Loading", "Unloading", "Processing", "StationStop"]:
			return "Station dwell in progress."
		var next_issue := _next_move_issue_for_train(t)
		if next_issue != "":
			return next_issue
		return "Moving normally."
	if state == "YardStop":
		return "Working through the yard stop. Next move: %s" % reason
	if state in ["Loading", "Unloading", "Processing", "StationStop"]:
		return "Station dwell in progress. Next move: %s" % reason
	return reason

func _next_move_issue_for_train(t: Dictionary) -> String:
	if not _is_train_on_map(t):
		return ""
	var path: Array = t.get("path", [])
	var path_index := int(t.get("path_index", 0))
	if path.is_empty() or path_index < 0 or path_index >= path.size():
		return ""
	var next_tile: Vector2i = path[path_index]
	var other := _tile_entry_blocker(next_tile, String(t.get("id", "")))
	if other != "":
		return "Next tile is occupied by %s." % other
	var reserved_by := _tile_reserved_by_other(next_tile, String(t.get("id", "")))
	if reserved_by != "":
		return "Next tile is reserved by %s." % reserved_by
	var cur: Vector2i = t.get("tile", _off_map_tile())
	if _signal_controls_departure(cur) and not _signal_faces_movement(cur, next_tile):
		return "Signal only opens %s, but this train needs %s." % [
			_dir_screen_name(_signal_dir(cur)),
			_dir_screen_name(next_tile - cur)
		]
	if _signal_controls_departure(cur) and _signal_faces_movement(cur, next_tile):
		var sig_type: String = _signal_type_for_dir(cur, next_tile - cur)
		if sig_type == "block":
			var blocker := _block_signal_blocker(t)
			if blocker != "":
				return "Next signal section is occupied by %s." % blocker
		else:
			var chain_reason := _chain_signal_blocker(t)
			if chain_reason != "":
				return chain_reason
	return ""

func _signal_summary(pos: Vector2i) -> String:
	var summaries: Array[String] = []
	for dir in _signal_dirs(pos):
		var parts: Array[String] = []
		var blocker := ""
		for bid in _signal_target_blocks(pos, dir):
			parts.append("B%d" % bid)
			if _block_has_occupant(bid):
				blocker = _block_occupied_by_other(bid, "")
		var protected := "/".join(parts) if not parts.is_empty() else "none"
		if blocker == "":
			summaries.append("opens %s, green: %s clear" % [_dir_screen_name(dir), protected])
		else:
			summaries.append("opens %s, red: %s blocked by %s" % [_dir_screen_name(dir), protected, blocker])
	return "; ".join(summaries)

func _signal_use_text(pos: Vector2i) -> String:
	var sig_type := _signal_type(pos)
	var directions := _signal_dirs(pos).size()
	if sig_type == "chain":
		return "Place before junctions so trains wait outside the crossing until an exit is open."
	if directions > 1:
		return "Use on two-way track. It behaves like a block signal for both directions."
	return "Use after stations, after junction exits, and along long straight track to split following traffic."

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
	var ids := ["coal_valley", "central_yard", "steelworks", "overtake_pass"]
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
		_draw_map_label(p + Vector2(-64, 84), String(s["name"]), 128, 17)
		_draw_map_label(p + Vector2(-48, 106), "Click" if available else ("Done" if completed else "Locked"), 96, 14, Color(1.0, 0.98, 0.84, 1.0))

func _draw_results_background() -> void:
	if art_texture:
		draw_texture_rect(art_texture, Rect2(Vector2(size.x * 0.5 - 280, size.y * 0.5 - 290), Vector2(560, 560)), false, Color(1, 1, 1, 0.18))

func _draw_map_label(pos: Vector2, text: String, width: float, label_font_size: int, fill: Color = Color(1.0, 0.94, 0.72, 1.0)) -> void:
	var outline := Color(0.05, 0.09, 0.11, 0.92)
	var shadow := Color(0.0, 0.0, 0.0, 0.42)
	var offsets: Array[Vector2] = [
		Vector2(-2, 0),
		Vector2(2, 0),
		Vector2(0, -2),
		Vector2(0, 2),
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1),
	]
	draw_string(font, pos + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_CENTER, width, label_font_size, shadow)
	for offset in offsets:
		draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_CENTER, width, label_font_size, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, label_font_size, fill)

func _cargo_label(t: Dictionary) -> String:
	var cargo := String(t.get("cargo", ""))
	var amount := int(t.get("cargo_amount", 0))
	if cargo == "" or amount <= 0:
		return "EMPTY"
	return "%s %d" % [cargo.to_upper(), amount]

func _cargo_badge_color(t: Dictionary) -> Color:
	var cargo := String(t.get("cargo", ""))
	if cargo == "coal":
		return Color.html("#d8d2bd")
	if cargo == "freight":
		return Color.html("#f2c36b")
	if cargo == "steel":
		return Color.html("#bfe3f6")
	return Color.html("#eef3e8")

func _draw_train_cargo_badge(t: Dictionary, center: Vector2) -> void:
	var badge_text := _cargo_label(t)
	var badge_size := Vector2(max(76.0, cell_size * 1.55), max(22.0, cell_size * 0.34))
	var badge_pos := center + Vector2(-badge_size.x * 0.5, cell_size * 0.42)
	var rect := Rect2(badge_pos, badge_size)
	draw_rect(rect.grow(2.0), Color(0.04, 0.08, 0.1, 0.68))
	draw_rect(rect, _cargo_badge_color(t))
	draw_rect(rect, Color.html("#172028"), false, 2.0)
	draw_string(font, badge_pos + Vector2(0, badge_size.y - 6.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, int(max(12.0, cell_size * 0.22)), Color.html("#172028"))

func _show_signal_debug_overlay() -> bool:
	return signal_help_open or selected_tool in ["block", "chain", "pair"] or selected_signal_pos.x > -900 or _selected_train_waiting_on_signal() or not _selected_train_signal_issue().is_empty()

func _selected_train_waiting_on_signal() -> bool:
	if selected_train_id == "":
		return false
	for t in trains:
		if t["id"] == selected_train_id:
			return String(t.get("state", "")) == "WaitingAtSignal"
	return false

func _selected_train_signal_issue() -> Dictionary:
	if selected_train_id == "":
		return {}
	for t in trains:
		if t["id"] != selected_train_id:
			continue
		var cur: Vector2i = t["tile"]
		var path: Array = t.get("path", [])
		var path_index := int(t.get("path_index", 0))
		if _signal_controls_departure(cur) and path_index < path.size():
			var next_tile: Vector2i = path[path_index]
			if not _signal_faces_movement(cur, next_tile):
				return {"pos": cur, "needed": next_tile - cur}
		var route: Array = t.get("route", [])
		if route.is_empty():
			return {}
		var stop_index := int(t.get("stop_index", 0))
		if stop_index < 0 or stop_index >= route.size():
			return {}
		var station_id := String(route[stop_index])
		if not station_by_id.has(station_id):
			return {}
		var target_station: Dictionary = station_by_id[station_id]
		var physical_path := _find_track_path_ignore_signals(cur, target_station["pos"])
		var current := cur
		for next in physical_path:
			if _signal_controls_departure(current) and not _signal_faces_movement(current, next):
				return {"pos": current, "needed": next - current}
			current = next
	return {}

func _block_has_occupant(block_id: int) -> bool:
	return not _block_occupants(block_id).is_empty()

func _signal_target_blocks(pos: Vector2i, dir: Vector2i = Vector2i.ZERO) -> Array[int]:
	var targets: Array[int] = []
	var own_block := int(block_for_tile.get(pos, -1))
	var signal_dir := _signal_dir(pos) if dir == Vector2i.ZERO else dir
	var facing_tile := pos + signal_dir
	if tracks.has(facing_tile) and _has_track_segment(pos, facing_tile):
		var bid := int(block_for_tile.get(facing_tile, -1))
		if bid >= 0 and bid != own_block:
			targets.append(bid)
	if targets.is_empty() and own_block >= 0:
		targets.append(own_block)
	return targets

func _signal_has_blocker_for_dir(pos: Vector2i, dir: Vector2i) -> bool:
	for bid in _signal_target_blocks(pos, dir):
		if _block_has_occupant(bid):
			return true
	return false

func _signal_has_blocker(pos: Vector2i) -> bool:
	for dir in _signal_dirs(pos):
		if _signal_has_blocker_for_dir(pos, dir):
			return true
	return false

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
	_draw_track_drag_preview()
	_draw_tracks()
	_draw_blocks()
	_draw_stations()
	_draw_signals()
	_draw_train_route_hints()
	_draw_trains()

func _draw_ghost_route() -> void:
	if not planning_guide_open:
		return
	var ghost: Array = local["scenario"].get("ghost", [])
	for i in range(ghost.size() - 1):
		var a: Vector2i = ghost[i]
		var b: Vector2i = ghost[i + 1]
		if _is_adjacent_track_step(a, b) and not _has_track_segment(a, b):
			var ac := _grid_to_screen(a)
			var bc := _grid_to_screen(b)
			var delta := bc - ac
			if not _draw_piece(game_track_texture, (ac + bc) * 0.5, Vector2(delta.length() * 1.18, cell_size * 0.48), delta.angle(), Color(1, 1, 1, 0.24)):
				draw_line(ac, bc, Color(0.4, 0.5, 0.45, 0.24), max(8.0, cell_size * 0.16), true)
	for p in ghost:
		if not tracks.has(p):
			var c := _grid_to_screen(p)
			draw_circle(c, max(5.0, cell_size * 0.1), Color(0.4, 0.5, 0.45, 0.34))

func _draw_track_drag_preview() -> void:
	if not dragging or selected_tool not in ["track", "erase"]:
		return
	if not _is_in_grid(drag_start_cell) or not _is_in_grid(drag_hover_cell):
		return
	if drag_start_cell == drag_hover_cell:
		return
	var path := _grid_drag_path(drag_start_cell, drag_hover_cell)
	var col := Color(0.22, 0.72, 1.0, 0.58)
	var dot_col := Color(0.12, 0.52, 0.9, 0.78)
	if selected_tool == "erase":
		col = Color(1.0, 0.22, 0.16, 0.58)
		dot_col = Color(0.9, 0.12, 0.08, 0.78)
	for i in range(path.size() - 1):
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		if not _is_in_grid(a) or not _is_in_grid(b):
			continue
		var ac := _grid_to_screen(a)
		var bc := _grid_to_screen(b)
		draw_line(ac, bc, col, max(6.0, cell_size * 0.11), true)
	for p in path:
		if _is_in_grid(p):
			draw_circle(_grid_to_screen(p), max(4.0, cell_size * 0.08), dot_col)

func _draw_blocks() -> void:
	var debug := _show_signal_debug_overlay()
	if not debug:
		return
	var label_centers: Dictionary = {}
	for key in track_segments.keys():
		var points := _segment_points(String(key))
		if points.size() != 2:
			continue
		var a: Vector2i = points[0]
		var b: Vector2i = points[1]
		var bid_a := int(block_for_tile.get(a, -1))
		var bid_b := int(block_for_tile.get(b, -1))
		if bid_a < 0 and bid_b < 0:
			continue
		var ac := _grid_to_screen(a)
		var bc := _grid_to_screen(b)
		if bid_a == bid_b:
			_draw_block_segment(ac, bc, bid_a)
			if not label_centers.has(bid_a):
				label_centers[bid_a] = (ac + bc) * 0.5
		else:
			var mid := (ac + bc) * 0.5
			if bid_a >= 0:
				_draw_block_segment(ac, mid, bid_a)
				if not label_centers.has(bid_a):
					label_centers[bid_a] = (ac + mid) * 0.5
			if bid_b >= 0:
				_draw_block_segment(mid, bc, bid_b)
				if not label_centers.has(bid_b):
					label_centers[bid_b] = (mid + bc) * 0.5
			_draw_block_boundary(mid)
	for bid in blocks.keys():
		if label_centers.has(int(bid)):
			_draw_block_label(label_centers[int(bid)], int(bid))
	for t in trains:
		if not _is_train_on_map(t):
			continue
		var bid := int(block_for_tile.get(t["tile"], -1))
		if bid >= 0 and not _block_occupants(bid).is_empty():
			_draw_block_occupant_badge(t["tile"], String(t["id"]))

func _draw_block_segment(a: Vector2, b: Vector2, block_id: int) -> void:
	if a.distance_squared_to(b) <= 0.1:
		return
	var color := _block_debug_color(block_id)
	var occupied := _block_has_occupant(block_id)
	var reserved := _block_has_reservation(block_id)
	if occupied:
		color = Color.html("#ff4d3d")
	elif reserved:
		color = Color.html("#51a7ff")
	var rail_width: float = max(8.0, cell_size * 0.13)
	draw_line(a, b, Color(0.02, 0.04, 0.05, 0.72), rail_width + 5.0, true)
	draw_line(a, b, Color(color.r, color.g, color.b, 0.82 if occupied else 0.68), rail_width, true)
	if occupied or reserved:
		var dash_dir := (b - a).normalized()
		var side: Vector2 = Vector2(-dash_dir.y, dash_dir.x) * max(2.0, cell_size * 0.035)
		draw_line(a + side, b + side, Color(1.0, 1.0, 1.0, 0.5), max(2.0, cell_size * 0.035), true)

func _draw_block_boundary(center: Vector2) -> void:
	var radius: float = max(5.0, cell_size * 0.08)
	draw_circle(center, radius + 2.0, Color(0.02, 0.04, 0.05, 0.82))
	draw_circle(center, radius, Color.html("#f7fbff"))

func _draw_block_label(center: Vector2, block_id: int) -> void:
	var label := "B%d" % block_id
	var label_size := Vector2(max(28.0, cell_size * 0.43), max(17.0, cell_size * 0.25))
	var rect := Rect2(center + Vector2(-label_size.x * 0.5, -cell_size * 0.36), label_size)
	var fill := Color(0.96, 0.98, 1.0, 0.9)
	if _block_has_occupant(block_id):
		fill = Color.html("#ffbd4a")
	elif _block_has_reservation(block_id):
		fill = Color.html("#bfe0ff")
	draw_rect(rect.grow(2.0), Color(0.02, 0.04, 0.05, 0.76))
	draw_rect(rect, fill)
	draw_rect(rect, Color(0.02, 0.04, 0.05, 0.82), false, 1.5)
	draw_string(font, rect.position + Vector2(0, label_size.y - 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, label_size.x, int(max(10.0, cell_size * 0.16)), Color.html("#172028"))

func _block_debug_color(block_id: int) -> Color:
	var colors := [
		Color.html("#47b5ff"),
		Color.html("#ffca4d"),
		Color.html("#b784ff"),
		Color.html("#47d18c"),
		Color.html("#ff7b6e"),
		Color.html("#48d7d0"),
	]
	return colors[block_id % colors.size()]

func _block_has_reservation(block_id: int) -> bool:
	if block_id < 0:
		return false
	for tile in tile_reservations.keys():
		if int(block_for_tile.get(tile, -2)) == block_id:
			return true
	return false

func _draw_block_occupant_badge(tile: Vector2i, train_id: String) -> void:
	var c := _grid_to_screen(tile) + Vector2(-cell_size * 0.26, -cell_size * 0.29)
	var badge_size := Vector2(max(32.0, cell_size * 0.5), max(16.0, cell_size * 0.24))
	var rect := Rect2(c - badge_size * 0.5, badge_size)
	draw_rect(rect.grow(2.0), Color.html("#172028"))
	draw_rect(rect, Color.html("#ffbd4a"))
	draw_rect(rect, Color.html("#172028"), false, 1.5)
	draw_string(font, rect.position + Vector2(0, badge_size.y - 4.0), train_id, HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, int(max(10.0, cell_size * 0.16)), Color.html("#172028"))

func _draw_tracks() -> void:
	for key in track_segments.keys():
		var points := _segment_points(String(key))
		if points.size() != 2:
			continue
		var p: Vector2i = points[0]
		var n: Vector2i = points[1]
		if not tracks.has(p) or not tracks.has(n):
			continue
		var c := _grid_to_screen(p)
		var nc := _grid_to_screen(n)
		var delta := nc - c
		if not _draw_piece(game_track_texture, (c + nc) * 0.5, Vector2(delta.length() * 1.2, cell_size * 0.54), delta.angle()):
			draw_line(c, nc, Color.html("#4b4037"), cell_size * 0.32, true)
			draw_line(c, nc, Color.html("#e7d6a1"), cell_size * 0.18, true)
			draw_line(c, nc, Color.html("#393536"), cell_size * 0.06, true)
	for p in tracks.keys():
		var c := _grid_to_screen(p)
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
		var texture: Texture2D = game_steelworks_texture if st.get("role", "") == "processor" else game_station_texture
		if selected_tool == "train" and st.get("role", "") == "source":
			draw_circle(c, cell_size * 0.82, Color(1.0, 0.86, 0.22, 0.32))
			draw_circle(c, cell_size * 0.82, Color.html("#172028"), false, 3.0)
		if not _draw_piece(texture, c, Vector2(cell_size * 1.34, cell_size * 1.34), 0.0, col):
			draw_rect(Rect2(c - Vector2(cell_size * 0.58, cell_size * 0.42), Vector2(cell_size * 1.16, cell_size * 0.84)), col)
			draw_rect(Rect2(c - Vector2(cell_size * 0.58, cell_size * 0.42), Vector2(cell_size * 1.16, cell_size * 0.84)), Color.html("#2f3840"), false, 2)
		var label_size := int(max(14.0, cell_size * 0.24))
		_draw_map_label(c + Vector2(-cell_size * 1.04, cell_size * 0.7), String(st["name"]), cell_size * 2.08, label_size)
		if selected_tool == "train" and st.get("role", "") == "source":
			_draw_map_label(c + Vector2(-cell_size * 0.9, -cell_size * 1.04), "BUY HERE", cell_size * 1.8, int(max(13.0, cell_size * 0.22)), Color.html("#ffe06d"))
		if int(st.get("platforms", 1)) > 1:
			_draw_map_label(c + Vector2(-cell_size * 0.45, -cell_size * 0.7), "P%d" % int(st["platforms"]), cell_size * 0.9, label_size)
		if editing_line_stops and selected_line_id != "" and lines.has(selected_line_id):
			_draw_station_add_handle(st["pos"])

func _draw_station_add_handle(station_pos: Vector2i) -> void:
	var center: Vector2 = _station_add_handle_center(station_pos)
	var radius: float = max(13.0, cell_size * 0.22)
	draw_circle(center, radius + 3.0, Color.html("#172028"))
	draw_circle(center, radius, Color.html("#ffd96b"))
	draw_line(center + Vector2(-radius * 0.48, 0), center + Vector2(radius * 0.48, 0), Color.html("#172028"), 3.0, true)
	draw_line(center + Vector2(0, -radius * 0.48), center + Vector2(0, radius * 0.48), Color.html("#172028"), 3.0, true)

func _signal_gate_center(pos: Vector2i, dir: Vector2i) -> Vector2:
	return _grid_to_screen(pos)

func _draw_signals() -> void:
	var signal_issue := _selected_train_signal_issue()
	var issue_pos: Vector2i = signal_issue.get("pos", Vector2i(-999, -999))
	var issue_needed: Vector2i = signal_issue.get("needed", Vector2i.ZERO)
	for raw_pos in signals.keys():
		var p: Vector2i = raw_pos
		var dirs := _signal_dirs(p)
		if dirs.is_empty():
			continue
		var primary_dir: Vector2i = _signal_dir(p)
		var primary_facing: Vector2 = Vector2(primary_dir).normalized()
		if primary_facing.length_squared() == 0.0:
			primary_facing = Vector2.RIGHT
		var side: Vector2 = Vector2(-primary_facing.y, primary_facing.x)
		var gate_center: Vector2 = _signal_gate_center(p, primary_dir)
		var is_issue_signal := p == issue_pos
		var any_occupied := false
		for dir in dirs:
			if _signal_has_blocker_for_dir(p, dir):
				any_occupied = true
				break
		var badge_light := Color.html("#ff8a2a") if is_issue_signal else Color.html("#e84242") if any_occupied else Color.html("#42d46b")
		var gate_len: float = max(24.0, cell_size * 0.54)
		var gate_width: float = max(6.0, cell_size * 0.1)
		var gate_col: Color = Color.html("#ff9d4a") if is_issue_signal else Color.html("#ffd96b") if selected_signal_pos == p else Color.html("#f7fbff")
		if is_issue_signal:
			draw_circle(gate_center, max(17.0, cell_size * 0.32), Color(1.0, 0.36, 0.08, 0.22))
		draw_line(gate_center - side * gate_len * 0.5, gate_center + side * gate_len * 0.5, Color.html("#172028"), gate_width + 4.0, true)
		draw_line(gate_center - side * gate_len * 0.46, gate_center + side * gate_len * 0.46, gate_col, gate_width, true)
		_draw_signal_gate_badge(gate_center - side * cell_size * 0.18, _signal_type(p) == "chain", badge_light)
		for dir in dirs:
			var light := Color.html("#ff8a2a") if is_issue_signal and dir == issue_needed else Color.html("#e84242") if _signal_has_blocker_for_dir(p, dir) else Color.html("#42d46b")
			_draw_signal_flow_marker(gate_center, Vector2(dir), light, dirs.size() > 1)
		if selected_signal_pos == p:
			draw_circle(gate_center, max(14.0, cell_size * 0.24), Color(1.0, 0.86, 0.22, 0.22))
	if issue_pos.x > -900 and issue_needed != Vector2i.ZERO:
		_draw_needed_signal_direction(issue_pos, issue_needed)

func _draw_signal_gate_badge(center: Vector2, is_chain: bool, light: Color) -> void:
	var radius: float = max(8.0, cell_size * 0.14)
	var outline: Color = Color.html("#172028")
	if is_chain:
		var points := PackedVector2Array([
			center + Vector2(0, -radius * 1.12),
			center + Vector2(radius * 1.12, 0),
			center + Vector2(0, radius * 1.12),
			center + Vector2(-radius * 1.12, 0),
		])
		draw_polygon(points, PackedColorArray([outline, outline, outline, outline]))
		var inner := PackedVector2Array([
			center + Vector2(0, -radius * 0.78),
			center + Vector2(radius * 0.78, 0),
			center + Vector2(0, radius * 0.78),
			center + Vector2(-radius * 0.78, 0),
		])
		draw_polygon(inner, PackedColorArray([light, light, light, light]))
	else:
		draw_circle(center, radius * 1.12, outline)
		draw_circle(center, radius * 0.78, light)

func _draw_signal_flow_marker(gate_center: Vector2, dir: Vector2, light: Color, compact: bool = false) -> void:
	var facing := dir.normalized()
	if facing.length_squared() == 0.0:
		return
	var flow_col := light.lightened(0.18)
	var offset: float = cell_size * (0.11 if compact else 0.18)
	var size: float = max(11.0, cell_size * (0.2 if compact else 0.28))
	_draw_direction_chevron(gate_center + facing * offset, facing, size, flow_col)

func _draw_needed_signal_direction(pos: Vector2i, dir: Vector2i) -> void:
	var facing := Vector2(dir).normalized()
	if facing.length_squared() == 0.0:
		return
	var center := _signal_gate_center(pos, dir)
	var side := Vector2(-facing.y, facing.x)
	var width: float = max(7.0, cell_size * 0.12)
	var length: float = max(26.0, cell_size * 0.66)
	var marker_col := Color.html("#ff8a2a")
	draw_line(center - side * length * 0.5, center + side * length * 0.5, Color.html("#172028"), width + 6.0, true)
	draw_line(center - side * length * 0.46, center + side * length * 0.46, marker_col, width, true)
	_draw_direction_chevron(center + facing * cell_size * 0.28, facing, max(17.0, cell_size * 0.36), marker_col)
	var slash_a := center - side * length * 0.28 - facing * cell_size * 0.08
	var slash_b := center + side * length * 0.28 + facing * cell_size * 0.08
	draw_line(slash_a, slash_b, Color.html("#172028"), max(5.0, cell_size * 0.085), true)
	draw_line(slash_a, slash_b, Color.html("#fff4cf"), max(2.5, cell_size * 0.045), true)

func _draw_direction_chevron(center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var facing := dir.normalized()
	if facing.length_squared() == 0.0:
		return
	var side := Vector2(-facing.y, facing.x)
	var outline := Color(0.05, 0.08, 0.1, min(1.0, color.a + 0.2))
	var tip := center + facing * size
	var left := center - facing * size * 0.72 + side * size * 0.58
	var right := center - facing * size * 0.72 - side * size * 0.58
	draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([outline, outline, outline]))
	var inner_tip := center + facing * size * 0.72
	var inner_left := center - facing * size * 0.46 + side * size * 0.38
	var inner_right := center - facing * size * 0.46 - side * size * 0.38
	draw_polygon(PackedVector2Array([inner_tip, inner_left, inner_right]), PackedColorArray([color, color, color]))

func _draw_train_route_hints() -> void:
	for t in trains:
		if not _is_train_on_map(t):
			continue
		var path: Array = t.get("path", [])
		if path.is_empty():
			continue
		var train_id := String(t.get("id", ""))
		var selected := selected_train_id == train_id
		if not selected and not signal_help_open:
			continue
		var start_tile: Vector2i = t["tile"]
		var start_index := int(t.get("path_index", 0))
		var previous := start_tile
		var max_hint: int = min(path.size(), start_index + (8 if selected else 5))
		var route_col := Color(0.1, 0.38, 0.95, 0.72 if selected else 0.42)
		for i in range(start_index, max_hint):
			var next: Vector2i = path[i]
			var a := _grid_to_screen(previous)
			var b := _grid_to_screen(next)
			var delta := b - a
			if delta.length_squared() > 0.0:
				var dir := delta.normalized()
				var side := Vector2(-dir.y, dir.x)
				var lane_offset := side * cell_size * 0.16
				draw_line(a + lane_offset, b + lane_offset, Color(route_col.r, route_col.g, route_col.b, route_col.a * 0.38), 3.0, true)
				_draw_direction_chevron((a + b) * 0.5 + lane_offset, dir, cell_size * (0.2 if selected else 0.16), route_col)
			previous = next

func _draw_trains() -> void:
	for t in trains:
		if not _is_train_on_map(t):
			continue
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
		_draw_map_label(p + Vector2(-cell_size * 0.42, -cell_size * 0.5), String(t["id"]), cell_size * 0.84, int(max(12.0, cell_size * 0.2)), Color(1.0, 0.98, 0.84, 1.0))
		_draw_train_cargo_badge(t, p)

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
