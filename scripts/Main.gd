extends Control

enum Screen { REGIONAL, LOCAL, RESULTS }

const SAVE_PATH := "user://trains_campaign.json"
const CELL := 48.0
const GRID_ORIGIN := Vector2(64, 132)
const RUN_LENGTH := 20
const RUN_POOL_SIZE := 30
const RUN_CHOICES := 3
const RUN_SCENARIO_PREFIX := "run_"
const REGIONAL_GRID := Vector2i(9, 7)
const REGIONAL_START_KEY := "0,3"
const REGIONAL_TILE_SIZE := 64.0
const REGIONAL_TILE_TERRAINS := ["plains", "forest", "hills", "mountains", "river", "coast", "city", "industry"]
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
	"completed": [],
	"run_seed": 32027,
	"run_step": 0,
	"run_completed": [],
	"run_available": [],
	"run_history": [],
	"run_won": false,
	"regional_map_seed": 32027,
	"regional_map": [],
	"regional_position": REGIONAL_START_KEY,
	"regional_completed_tiles": [],
	"regional_visible_tiles": [],
	"active_regional_tile": "",
	"permanent_upgrades": {},
	"run_upgrades": {},
	"upgrade_shop": [],
	"regional_traits": {
		"coal_output": 0,
		"freight_output": 0,
		"steel_output": 0,
		"reliability": 1.0,
		"capacity_rating": 0,
		"through_traffic": 0,
		"burstiness": 0.0
	}
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
var regional_tileset_texture: Texture2D
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
var context_menu_open := false
var context_target_type := ""
var context_target_pos := Vector2i(-999, -999)
var context_target_id := ""
var context_screen_pos := Vector2.ZERO
var context_menu_layer: Control
var toast_label: Label
var inspect_chip: RichTextLabel
var service_edit_bar: HBoxContainer
var service_edit_label: Label
var service_edit_line_id := ""
var press_active := false
var press_start_pos := Vector2.ZERO
var press_start_cell := Vector2i(-999, -999)
var press_elapsed := 0.0
var press_context_consumed := false
var press_moved := false
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
	_ensure_run_state()
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
	regional_tileset_texture = _load_texture("res://assets/generated/regional/tileset.png")

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		if texture:
			return texture
	if FileAccess.file_exists(path):
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
		return 560.0
	if viewport_width >= 1500.0:
		return 520.0
	return min(520.0, viewport_width - 32.0)

func _local_tray_height() -> float:
	var viewport_height: float = max(size.y, 480.0)
	if viewport_height <= 640.0:
		return 176.0
	return 214.0

func _local_side_panel_inner_width() -> float:
	return _local_side_panel_width() - 12.0 - 36.0

func _apply_local_side_panel_layout() -> void:
	if screen != Screen.LOCAL or side_panel == null:
		return
	side_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	side_panel.offset_left = 14
	side_panel.offset_top = -_local_tray_height()
	side_panel.offset_right = -14
	side_panel.offset_bottom = -12
	if tool_bar != null:
		tool_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tool_bar.offset_left = 18
		tool_bar.offset_top = -(_local_tray_height() + 72.0)
		tool_bar.offset_right = -18
		tool_bar.offset_bottom = -(_local_tray_height() + 18.0)

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
	if press_active:
		press_elapsed += delta
		if not press_moved and not press_context_consumed and press_elapsed >= 0.42:
			var target := _context_target_at(press_start_pos)
			_open_context_menu_at(press_start_pos, String(target.get("type", "tile")), String(target.get("id", "")), target.get("pos", press_start_cell))
			press_context_consumed = true
			press_active = false
			dragging = false
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
					_close_context_menu()
					press_active = true
					press_elapsed = 0.0
					press_context_consumed = false
					press_moved = false
					press_start_pos = mb.position
					dragging = true
					last_drag_cell = Vector2i(-999, -999)
					drag_start_cell = _screen_to_grid(mb.position)
					drag_hover_cell = drag_start_cell
				else:
					if not press_context_consumed:
						if dragging and selected_tool in ["track", "erase"] and mb.position.distance_to(press_start_pos) > 10.0:
							_finish_track_drag(mb.position)
						else:
							_handle_local_click(mb.position)
					press_active = false
					press_elapsed = 0.0
					press_context_consumed = false
					press_moved = false
					dragging = false
					last_drag_cell = Vector2i(-999, -999)
					drag_start_cell = Vector2i(-999, -999)
					drag_hover_cell = Vector2i(-999, -999)
					queue_redraw()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				var target := _context_target_at(mb.position)
				_open_context_menu_at(mb.position, String(target.get("type", "tile")), String(target.get("id", "")), target.get("pos", _screen_to_grid(mb.position)))
	if event is InputEventKey and screen == Screen.LOCAL:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and context_menu_open:
			_close_context_menu()
			queue_redraw()
		elif key.pressed and key.keycode == KEY_ESCAPE and selected_tool in ["train", "line"]:
			_select_tool("track")
			local_message = "Tool canceled. Track tool selected."
			_refresh_local_side_text()
	if event is InputEventMouseMotion and screen == Screen.LOCAL and dragging:
		if selected_tool in ["track", "erase"]:
			var motion := event as InputEventMouseMotion
			drag_hover_cell = _screen_to_grid(motion.position)
			if motion.position.distance_to(press_start_pos) > 10.0:
				press_moved = true
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
	scenarios.append_array(_generate_run_scenarios())

func _generate_run_scenarios() -> Array:
	var generated: Array = []
	for i in range(RUN_POOL_SIZE):
		generated.append(_make_run_scenario(i))
	return generated

func _make_run_scenario(index: int) -> Dictionary:
	var difficulty: int = 1 + int(floor(float(index) / 10.0))
	var pattern: int = index % 6
	var grid := Vector2i(16 + difficulty * 2 + (index % 2) * 2, 10 + min(2, difficulty))
	var west := Vector2i(1, int(grid.y / 2))
	var east := Vector2i(grid.x - 2, int(grid.y / 2))
	var mid := Vector2i(int(grid.x / 2), int(grid.y / 2))
	var north := Vector2i(mid.x, 1 + (index % 2))
	var south := Vector2i(mid.x, grid.y - 2 - (index % 2))
	var branch := north if pattern in [0, 2, 5] else south
	var return_branch := south if branch == north else north
	var terrain: Array = _run_terrain_for(index, grid, pattern, difficulty)
	var base_budget: int = 1550 + difficulty * 650 + pattern * 90
	var target: int = 70 + difficulty * 35 + index * 3
	var fleet_goal: int = int(clamp(1 + difficulty + int(pattern / 2), 1, 6))
	var wait_target: float = 48.0 + difficulty * 16.0
	var cargo_name := "coal"
	var kind := "coal"
	var route: Array = ["source", "branch_yard", "sink", "source"]
	var stations: Array = [
		{"id": "source", "name": _run_source_name(index, pattern), "pos": west, "role": "source", "produces": "coal", "accepts": [], "platforms": 1 + int(difficulty > 2)},
		{"id": "branch_yard", "name": _run_branch_name(index, pattern), "pos": branch, "role": "yard", "produces": "", "accepts": ["coal"], "platforms": 1 + int(difficulty > 1)},
		{"id": "sink", "name": _run_sink_name(index, pattern), "pos": east, "role": "sink", "produces": "", "accepts": ["coal"], "platforms": 1 + int(difficulty > 1)}
	]
	var name := _run_contract_name(index, pattern, difficulty)
	var objective := "Deliver %d cargo through a branch contract, not a straight corridor." % target
	var briefing := "Contract: expand the regional railway through %s.\nPhysical constraints on this map change your cheapest path. Previous districts add traffic pressure, so optimize for reliable flow rather than just connection.\nTerrain colors show mountains, rocks, rivers, and ocean tiles that force detours or bridges." % name

	if pattern in [1, 4]:
		kind = "yard"
		cargo_name = "freight"
		target = 24 + difficulty * 18 + index
		fleet_goal = clamp(2 + difficulty, 2, 6)
		stations = [
			{"id": "source", "name": _run_source_name(index, pattern), "pos": west, "role": "source", "produces": "freight", "accepts": [], "platforms": 1 + int(difficulty > 1)},
			{"id": "north_yard", "name": _run_yard_name(index), "pos": north, "role": "yard", "produces": "", "accepts": ["freight"], "platforms": 1 + int(difficulty > 2)},
			{"id": "sink", "name": _run_sink_name(index, pattern), "pos": east, "role": "sink", "produces": "", "accepts": ["freight"], "platforms": 1 + int(difficulty > 1)},
			{"id": "south_yard", "name": _run_branch_name(index, pattern), "pos": south, "role": "yard", "produces": "", "accepts": ["freight"], "platforms": 1 + int(difficulty > 1)}
		]
		route = ["source", "north_yard", "sink", "south_yard", "source"]
		objective = "Process %d freight loads with at least %d trains." % [target, fleet_goal]
	elif pattern == 5:
		kind = "steel"
		cargo_name = "steel"
		target = 95 + difficulty * 40 + index * 2
		fleet_goal = clamp(2 + difficulty, 3, 6)
		stations = [
			{"id": "coal_input", "name": "Coal Input", "pos": west, "role": "source", "produces": "coal", "accepts": [], "platforms": 1 + int(difficulty > 1)},
			{"id": "steelworks", "name": _run_yard_name(index), "pos": branch, "role": "processor", "produces": "steel", "accepts": ["coal"], "platforms": 1 + int(difficulty > 2)},
			{"id": "export_platform", "name": "Export Platform", "pos": east, "role": "sink", "produces": "", "accepts": ["steel"], "platforms": 1 + int(difficulty > 1)},
			{"id": "staging", "name": _run_branch_name(index, pattern), "pos": return_branch, "role": "yard", "produces": "", "accepts": ["steel"], "platforms": 1 + int(difficulty > 1)}
		]
		route = ["coal_input", "steelworks", "export_platform", "staging", "coal_input"]
		objective = "Convert coal into %d steel output with a %d-train service." % [target, fleet_goal]

	var ghost := _run_solution_path_for(stations, grid, pattern, terrain, route)
	return {
		"id": "%s%02d" % [RUN_SCENARIO_PREFIX, index + 1],
		"name": name,
		"purpose": "Roguelike contract %d of %d: %s" % [index + 1, RUN_POOL_SIZE, _difficulty_label(difficulty)],
		"objective": objective,
		"briefing": briefing,
		"start_message": "Build any reliable service that satisfies this contract. Terrain and inherited traffic pressure are the real constraints.",
		"target": target,
		"fleet_goal": fleet_goal,
		"cargo": cargo_name,
		"kind": kind,
		"difficulty": difficulty,
		"start_budget": base_budget,
		"grid": grid,
		"route": route,
		"stations": stations,
		"terrain": terrain,
		"ghost": ghost,
		"requirements": _requirements_for_contract(kind, difficulty, pattern, fleet_goal),
		"reward_money": 220 + difficulty * 120 + pattern * 20,
		"reward_load": 5 + difficulty * 3 + pattern,
		"reward_capacity": 2 + difficulty * 2 + int(pattern == 4) * 6,
		"wait_target": wait_target
	}

func _difficulty_label(difficulty: int) -> String:
	if difficulty <= 1:
		return "local feeder"
	if difficulty == 2:
		return "regional pressure"
	return "late-run stress"

func _run_contract_name(index: int, pattern: int, difficulty: int) -> String:
	var names := [
		"Coal Cut",
		"River Exchange",
		"Granite Pass",
		"Harbor Approach",
		"Yard Throat",
		"Steel Relay"
	]
	return "%s %02d" % [names[pattern], index + 1]

func _run_source_name(index: int, pattern: int) -> String:
	var names := ["North Mine", "Timber Spur", "Quarry", "Harbor Mine", "Freight Intake", "Coal Field"]
	return "%s %d" % [names[pattern], index + 1]

func _run_sink_name(index: int, pattern: int) -> String:
	var names := ["Interchange", "Market Town", "Cement Works", "Port Yard", "Sorting Exit", "Export Rail"]
	return "%s %d" % [names[pattern], index + 1]

func _run_yard_name(index: int) -> String:
	var names := ["Central Yard", "Ridge Yard", "Bay Junction", "Foundry Yard", "Summit Works"]
	return "%s %d" % [names[index % names.size()], index + 1]

func _run_branch_name(index: int, pattern: int) -> String:
	var names := ["Relief Spur", "North Fork", "Market Branch", "Harbor Staging", "Return Yard", "Hill Exchange"]
	return "%s %d" % [names[pattern], index + 1]

func _requirements_for_contract(kind: String, difficulty: int, pattern: int, fleet_goal: int) -> Array[String]:
	var req: Array[String] = []
	req.append("Minimum fleet: %d trains" % fleet_goal)
	req.append("Route includes an off-axis branch stop; a simple A-to-B double track is not enough.")
	req.append("Terrain forces at least one detour or bridge decision.")
	if kind == "yard":
		req.append("Yard stations add dwell time and reward platform capacity.")
	elif kind == "steel":
		req.append("Coal must reach the processor before steel can be exported.")
	else:
		req.append("Source and sink throughput reward short waits over cheap track.")
	return req

func _run_terrain_for(index: int, grid: Vector2i, pattern: int, difficulty: int) -> Array:
	var terrain: Array = []
	var river_x: int = 4 + (index * 3) % int(max(5, grid.x - 7))
	if pattern in [1, 5]:
		for y in range(1, grid.y - 1):
			if y != int(grid.y / 2) and y != int(grid.y / 2) + 1:
				terrain.append({"pos": Vector2i(river_x, y), "type": "river"})
	if pattern in [2, 4]:
		var ridge_y: int = 2 + (index % int(max(2, grid.y - 5)))
		for x in range(3, grid.x - 3):
			if x % 4 != index % 4:
				terrain.append({"pos": Vector2i(x, ridge_y), "type": "mountain"})
		for x in range(5, grid.x - 5, 4):
			terrain.append({"pos": Vector2i(x, ridge_y + 1), "type": "rock"})
	if pattern == 3:
		for y in range(0, grid.y):
			terrain.append({"pos": Vector2i(grid.x - 1, y), "type": "ocean"})
			if y > 1 and y < grid.y - 2 and y % 3 != 0:
				terrain.append({"pos": Vector2i(grid.x - 2, y), "type": "ocean"})
	if pattern == 0:
		for x in range(4, grid.x - 4, 3):
			terrain.append({"pos": Vector2i(x, 2 + ((x + index) % max(2, grid.y - 4))), "type": "rock"})
	if difficulty >= 3:
		for x in range(2, grid.x - 2, 5):
			terrain.append({"pos": Vector2i(x, grid.y - 2), "type": "river"})
	return terrain

func _run_solution_path_for(stations: Array, grid: Vector2i, pattern: int, terrain: Array, route: Array = []) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if stations.is_empty():
		return path
	var ordered_stations: Array = stations.duplicate()
	if not route.is_empty():
		var by_id := {}
		for st in stations:
			by_id[String(st["id"])] = st
		ordered_stations = []
		for station_id in route:
			if by_id.has(String(station_id)):
				ordered_stations.append(by_id[String(station_id)])
	if ordered_stations.is_empty():
		return path
	var last: Vector2i = ordered_stations[0]["pos"]
	path.append(last)
	for i in range(1, ordered_stations.size()):
		var target: Vector2i = ordered_stations[i]["pos"]
		var leg := _terrain_aware_path(last, target, grid, terrain, _station_positions(stations), pattern)
		if leg.is_empty():
			leg = _simple_path_points(last, target)
		for p in leg:
			if path.is_empty() or path[path.size() - 1] != p:
				path.append(p)
		last = target
	return path

func _station_positions(stations: Array) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for st in stations:
		positions.append(st["pos"])
	return positions

func _terrain_aware_path(start: Vector2i, goal: Vector2i, grid: Vector2i, terrain: Array, allowed_blocked: Array[Vector2i], pattern: int) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for n in _generation_neighbors_toward(current, goal, pattern):
			if n.x < 0 or n.y < 0 or n.x >= grid.x or n.y >= grid.y:
				continue
			if _generation_terrain_blocks(n, terrain, allowed_blocked):
				continue
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
	path.push_front(start)
	return path

func _generation_neighbors_toward(current: Vector2i, goal: Vector2i, pattern: int) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for d in DIRS:
		options.append(current + d)
	var sorted: Array[Vector2i] = []
	for n in options:
		var score := Vector2(goal - n).length_squared()
		score += abs(n.y - (goal.y + ((pattern % 3) - 1))) * 0.08
		var inserted := false
		for i in range(sorted.size()):
			var other_score := Vector2(goal - sorted[i]).length_squared()
			other_score += abs(sorted[i].y - (goal.y + ((pattern % 3) - 1))) * 0.08
			if score < other_score:
				sorted.insert(i, n)
				inserted = true
				break
		if not inserted:
			sorted.append(n)
	return sorted

func _generation_terrain_blocks(p: Vector2i, terrain: Array, allowed_blocked: Array[Vector2i]) -> bool:
	if allowed_blocked.has(p):
		return false
	for item in terrain:
		if item.get("pos", Vector2i(-999, -999)) == p:
			return String(item.get("type", "")) in ["mountain", "rock", "ocean"]
	return false

func _simple_path_points(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := from_cell
	path.append(cur)
	while cur != to_cell:
		var step_x := signi(to_cell.x - cur.x)
		var step_y := signi(to_cell.y - cur.y)
		if abs(to_cell.x - cur.x) >= abs(to_cell.y - cur.y):
			cur.x += step_x
		else:
			cur.y += step_y
		path.append(cur)
	return path

func signi(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

func _ensure_run_state() -> void:
	for key in ["completed", "run_completed", "run_available", "run_history"]:
		if not campaign.has(key) or typeof(campaign[key]) != TYPE_ARRAY:
			campaign[key] = []
	if not campaign.has("run_seed"):
		campaign["run_seed"] = 32027
	if not campaign.has("run_step"):
		campaign["run_step"] = (campaign["run_completed"] as Array).size()
	if not campaign.has("run_won"):
		campaign["run_won"] = false
	if not campaign.has("regional_map_seed"):
		campaign["regional_map_seed"] = int(campaign.get("run_seed", 32027))
	if not campaign.has("regional_map") or typeof(campaign["regional_map"]) != TYPE_ARRAY or (campaign["regional_map"] as Array).is_empty():
		campaign["regional_map"] = _generate_regional_map(int(campaign.get("regional_map_seed", 32027)))
	if not campaign.has("regional_position") or String(campaign["regional_position"]) == "":
		campaign["regional_position"] = REGIONAL_START_KEY
	if not campaign.has("regional_completed_tiles") or typeof(campaign["regional_completed_tiles"]) != TYPE_ARRAY:
		campaign["regional_completed_tiles"] = []
	if not (campaign["regional_completed_tiles"] as Array).has(REGIONAL_START_KEY):
		(campaign["regional_completed_tiles"] as Array).append(REGIONAL_START_KEY)
	if not campaign.has("regional_visible_tiles") or typeof(campaign["regional_visible_tiles"]) != TYPE_ARRAY or (campaign["regional_visible_tiles"] as Array).is_empty():
		campaign["regional_visible_tiles"] = _regional_neighbors(REGIONAL_START_KEY)
	if not campaign.has("active_regional_tile"):
		campaign["active_regional_tile"] = ""
	if not campaign.has("permanent_upgrades") or typeof(campaign["permanent_upgrades"]) != TYPE_DICTIONARY:
		campaign["permanent_upgrades"] = {}
	if not campaign.has("run_upgrades") or typeof(campaign["run_upgrades"]) != TYPE_DICTIONARY:
		campaign["run_upgrades"] = {}
	if not campaign.has("upgrade_shop") or typeof(campaign["upgrade_shop"]) != TYPE_ARRAY:
		campaign["upgrade_shop"] = []
	if not campaign.has("regional_traits") or typeof(campaign["regional_traits"]) != TYPE_DICTIONARY:
		campaign["regional_traits"] = {}
	var traits: Dictionary = campaign["regional_traits"]
	for key in ["coal_output", "freight_output", "steel_output", "capacity_rating", "through_traffic"]:
		if not traits.has(key):
			traits[key] = 0
	if not traits.has("reliability"):
		traits["reliability"] = 1.0
	if not traits.has("burstiness"):
		traits["burstiness"] = 0.0
	campaign["run_step"] = min(RUN_LENGTH, (campaign["run_completed"] as Array).size())
	campaign["run_won"] = int(campaign["run_step"]) >= RUN_LENGTH
	if (campaign["upgrade_shop"] as Array).is_empty():
		_generate_upgrade_shop()
	_ensure_run_choices()

func _default_regional_traits() -> Dictionary:
	return {
		"coal_output": 0,
		"freight_output": 0,
		"steel_output": 0,
		"reliability": 1.0,
		"capacity_rating": 0,
		"through_traffic": 0,
		"burstiness": 0.0
	}

func _reset_progress(save_to_disk: bool = true) -> void:
	campaign["money"] = 1500
	campaign["materials"] = 4
	campaign["traffic_load"] = 18
	campaign["traffic_capacity"] = 40
	campaign["completed"] = []
	campaign["run_seed"] = 32027
	campaign["regional_map_seed"] = 32027
	campaign["regional_map"] = []
	campaign["regional_position"] = REGIONAL_START_KEY
	campaign["regional_completed_tiles"] = []
	campaign["regional_visible_tiles"] = []
	campaign["active_regional_tile"] = ""
	campaign["permanent_upgrades"] = {}
	campaign["run_upgrades"] = {}
	campaign["upgrade_shop"] = []
	campaign["run_step"] = 0
	campaign["run_completed"] = []
	campaign["run_available"] = []
	campaign["run_history"] = []
	campaign["run_won"] = false
	campaign["regional_traits"] = _default_regional_traits()
	_ensure_run_state()
	if save_to_disk:
		_save_campaign()
	screen = Screen.REGIONAL
	rebuild_ui()
	queue_redraw()

func _ensure_run_choices() -> void:
	if bool(campaign.get("run_won", false)):
		campaign["run_available"] = []
		return
	if not campaign.has("regional_map") or (campaign.get("regional_map", []) as Array).is_empty():
		campaign["regional_map"] = _generate_regional_map(int(campaign.get("regional_map_seed", 32027)))
	var choices: Array = []
	for key in _regional_available_tile_keys():
		var tile := _regional_tile_for_key(String(key))
		var id := String(tile.get("scenario_id", ""))
		if id != "" and not choices.has(id):
			choices.append(id)
	if choices.is_empty() and int(campaign.get("run_step", 0)) < RUN_LENGTH:
		var fallback_key := _nearest_uncompleted_regional_contract()
		if fallback_key != "":
			var visible: Array = campaign.get("regional_visible_tiles", [])
			if not visible.has(fallback_key):
				visible.append(fallback_key)
			campaign["regional_visible_tiles"] = visible
			var fallback_tile := _regional_tile_for_key(fallback_key)
			var fallback_id := String(fallback_tile.get("scenario_id", ""))
			if fallback_id != "":
				choices.append(fallback_id)
	campaign["run_available"] = choices

func _generate_regional_map(seed: int) -> Array:
	var tiles: Array = []
	var scenario_index := 1
	for y in range(REGIONAL_GRID.y):
		for x in range(REGIONAL_GRID.x):
			var key := _regional_key(x, y)
			var terrain := _regional_terrain_for(seed, x, y)
			var tier: int = clamp(1 + int(floor(float(x) / 2.0)), 1, 5)
			var scenario_id := ""
			if key != REGIONAL_START_KEY and x <= 4 and scenario_index <= RUN_POOL_SIZE:
				scenario_id = "%s%02d" % [RUN_SCENARIO_PREFIX, scenario_index]
				scenario_index += 1
			tiles.append({
				"key": key,
				"x": x,
				"y": y,
				"terrain": terrain,
				"tier": tier,
				"scenario_id": scenario_id,
				"marker": "start" if key == REGIONAL_START_KEY else ("contract" if scenario_id != "" else "scenic")
			})
	return tiles

func _regional_terrain_for(seed: int, x: int, y: int) -> String:
	if x == 0 or x == REGIONAL_GRID.x - 1 or y == 0 or y == REGIONAL_GRID.y - 1:
		return "coast" if _regional_hash(seed, x, y, 7) % 3 == 0 else "plains"
	var h := _regional_hash(seed, x, y, 11) % 100
	if h < 14:
		return "forest"
	if h < 28:
		return "hills"
	if h < 39:
		return "mountains"
	if h < 51:
		return "river"
	if h < 64:
		return "city"
	if h < 76:
		return "industry"
	return "plains"

func _regional_hash(seed: int, x: int, y: int, salt: int) -> int:
	return abs(seed * 1103515245 + x * 374761393 + y * 668265263 + salt * 2246822519)

func _regional_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _regional_key_to_pos(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _regional_tile_for_key(key: String) -> Dictionary:
	for tile in campaign.get("regional_map", []):
		if String(tile.get("key", "")) == key:
			return tile
	return {}

func _regional_tile_for_scenario(id: String) -> Dictionary:
	for tile in campaign.get("regional_map", []):
		if String(tile.get("scenario_id", "")) == id:
			return tile
	return {}

func _regional_neighbors(key: String) -> Array:
	var pos := _regional_key_to_pos(key)
	var result: Array = []
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var p: Vector2i = pos + d
		if p.x >= 0 and p.y >= 0 and p.x < REGIONAL_GRID.x and p.y < REGIONAL_GRID.y:
			result.append(_regional_key(p.x, p.y))
	return result

func _regional_available_tile_keys() -> Array:
	var position := String(campaign.get("regional_position", REGIONAL_START_KEY))
	var completed: Array = campaign.get("regional_completed_tiles", [])
	var visible: Array = campaign.get("regional_visible_tiles", [])
	var adjacent := _regional_neighbors(position)
	var result: Array = []
	for key in visible:
		var key_str := String(key)
		if completed.has(key_str) or not adjacent.has(key_str):
			continue
		var tile := _regional_tile_for_key(key_str)
		var scenario_id := String(tile.get("scenario_id", ""))
		if scenario_id != "" and not _run_completed_has(scenario_id):
			result.append(key_str)
	return result

func _nearest_uncompleted_regional_contract() -> String:
	var current := _regional_key_to_pos(String(campaign.get("regional_position", REGIONAL_START_KEY)))
	var best_key := ""
	var best_dist := 99999
	for tile in campaign.get("regional_map", []):
		var id := String(tile.get("scenario_id", ""))
		var key := String(tile.get("key", ""))
		if id == "" or _run_completed_has(id):
			continue
		var p := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		var dist: int = abs(p.x - current.x) + abs(p.y - current.y)
		if dist < best_dist:
			best_dist = dist
			best_key = key
	return best_key

func _reveal_regional_neighbors(key: String) -> void:
	var visible: Array = campaign.get("regional_visible_tiles", [])
	for n in _regional_neighbors(key):
		if not visible.has(n):
			visible.append(n)
	campaign["regional_visible_tiles"] = visible

func _complete_regional_tile_for_scenario(id: String) -> void:
	var active_key := String(campaign.get("active_regional_tile", ""))
	var tile := _regional_tile_for_key(active_key)
	if tile.is_empty() or String(tile.get("scenario_id", "")) != id:
		tile = _regional_tile_for_scenario(id)
		active_key = String(tile.get("key", ""))
	if active_key == "":
		return
	campaign["regional_position"] = active_key
	var completed_tiles: Array = campaign.get("regional_completed_tiles", [])
	if not completed_tiles.has(active_key):
		completed_tiles.append(active_key)
	campaign["regional_completed_tiles"] = completed_tiles
	_reveal_regional_neighbors(active_key)
	campaign["active_regional_tile"] = ""
	_generate_upgrade_shop()

func _upgrade_defs() -> Dictionary:
	return {
		"reward_multiplier": {"name": "Regional Yield", "scope": "permanent", "cost": 260, "desc": "+10% money rewards."},
		"station_planning": {"name": "Station Planning", "scope": "permanent", "cost": 340, "desc": "+1 platform on generated contracts."},
		"train_voucher": {"name": "Train Voucher", "scope": "run", "cost": 180, "desc": "Next train has no material score."},
		"dispatch_reliability": {"name": "Dispatch Relay", "scope": "run", "cost": 220, "desc": "More forgiving wait targets this run."},
		"material_efficiency": {"name": "Lean Build", "scope": "run", "cost": 240, "desc": "Material score counts 10% lighter."},
		"throughput_boost": {"name": "Flow Crew", "scope": "run", "cost": 210, "desc": "Station work tolerates tighter layouts."}
	}

func _generate_upgrade_shop() -> void:
	var defs := _upgrade_defs()
	var ids: Array = defs.keys()
	var offers: Array = []
	var seed: int = int(campaign.get("regional_map_seed", 32027)) + int(campaign.get("run_step", 0)) * 17
	var offset := 0
	while offers.size() < 3 and offset < ids.size() * 3:
		var id := String(ids[abs(seed + offset * 5) % ids.size()])
		if not offers.has(id):
			offers.append(id)
		offset += 1
	campaign["upgrade_shop"] = offers

func _purchase_upgrade(id: String) -> void:
	var defs := _upgrade_defs()
	if not defs.has(id):
		return
	var def: Dictionary = defs[id]
	var cost := int(def.get("cost", 0))
	if int(campaign.get("money", 0)) < cost:
		return
	campaign["money"] = int(campaign.get("money", 0)) - cost
	var scope := String(def.get("scope", "run"))
	var bucket_key := "permanent_upgrades" if scope == "permanent" else "run_upgrades"
	var bucket: Dictionary = campaign.get(bucket_key, {})
	bucket[id] = int(bucket.get(id, 0)) + 1
	campaign[bucket_key] = bucket
	_generate_upgrade_shop()
	_save_campaign()
	rebuild_ui()
	queue_redraw()

func _upgrade_level(id: String) -> int:
	var permanent: Dictionary = campaign.get("permanent_upgrades", {})
	var run: Dictionary = campaign.get("run_upgrades", {})
	return int(permanent.get(id, 0)) + int(run.get(id, 0))

func _remaining_run_scenario_count() -> int:
	return max(0, RUN_POOL_SIZE - (campaign.get("run_completed", []) as Array).size())

func _run_completed_has(id: String) -> bool:
	return (campaign.get("run_completed", []) as Array).has(id)

func _is_run_scenario_id(id: String) -> bool:
	return id.begins_with(RUN_SCENARIO_PREFIX)

func _regional_visible_scenarios() -> Array:
	var visible: Array = []
	for s in scenarios:
		var id := String(s.get("id", ""))
		if _is_run_scenario_id(id):
			if _run_completed_has(id) or (campaign.get("run_available", []) as Array).has(id):
				visible.append(s)
		elif id in ["coal_valley", "central_yard", "steelworks", "overtake_pass"]:
			visible.append(s)
	return visible

func _tutorial_regional_scenarios() -> Array:
	var visible: Array = []
	for s in scenarios:
		var id := String(s.get("id", ""))
		if id in ["coal_valley", "central_yard", "steelworks", "overtake_pass"]:
			visible.append(s)
	return visible

func _apply_run_pressure_to_scenario(scenario: Dictionary) -> Dictionary:
	var sc := scenario.duplicate(true)
	if not _is_run_scenario_id(String(sc.get("id", ""))):
		return sc
	var tile := _regional_tile_for_scenario(String(sc.get("id", "")))
	var traits: Dictionary = campaign.get("regional_traits", {})
	var through := int(traits.get("through_traffic", 0))
	var capacity := int(traits.get("capacity_rating", 0))
	var reliability := float(traits.get("reliability", 1.0))
	var pressure: int = int(max(0, through - capacity))
	var tile_tier := int(tile.get("tier", 1))
	sc["target"] = int(sc.get("target", 60)) + pressure * 2 + int((1.0 - reliability) * 20.0) + tile_tier * 8 + int(campaign.get("run_step", 0)) * 2
	sc["fleet_goal"] = min(8, int(sc.get("fleet_goal", 1)) + int(pressure >= 8) + int(tile_tier >= 4))
	sc["start_budget"] = int(sc.get("start_budget", 1500)) + capacity * 10
	sc["wait_target"] = max(28.0, float(sc.get("wait_target", 45.0)) - min(14.0, float(pressure)) + float(_upgrade_level("dispatch_reliability")) * 4.0)
	sc["regional_tile"] = tile.duplicate(true)
	_apply_regional_tile_modifier(sc, tile)
	_apply_upgrade_scenario_modifiers(sc)
	var briefing := String(sc.get("briefing", ""))
	briefing += "\nRegional tile: %s tier %d. Inherited region: Through traffic %d, capacity rating %d, reliability %.0f%%. These values come from previous completed nodes." % [
		String(tile.get("terrain", "plains")).capitalize(),
		tile_tier,
		through,
		capacity,
		reliability * 100.0
	]
	sc["briefing"] = briefing
	return sc

func _apply_regional_tile_modifier(sc: Dictionary, tile: Dictionary) -> void:
	if tile.is_empty():
		return
	var terrain := String(tile.get("terrain", "plains"))
	var tier := int(tile.get("tier", 1))
	sc["reward_money"] = int(sc.get("reward_money", 0)) + tier * 45
	sc["reward_load"] = int(sc.get("reward_load", 0)) + tier
	if terrain == "city":
		sc["target"] = int(sc.get("target", 0)) + 20
		sc["reward_load"] = int(sc.get("reward_load", 0)) + 4
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 110
	elif terrain == "industry":
		sc["target"] = int(sc.get("target", 0)) + 28
		sc["reward_capacity"] = int(sc.get("reward_capacity", 0)) + 4
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 130
	elif terrain == "river":
		_add_regional_obstacle_line(sc, "river")
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 90
	elif terrain == "mountains":
		_add_regional_obstacle_line(sc, "mountain")
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 140
	elif terrain == "hills":
		_add_regional_obstacle_line(sc, "rock")
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 80
	elif terrain == "coast":
		_add_regional_obstacle_line(sc, "ocean")
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 100
	elif terrain == "forest":
		sc["wait_target"] = float(sc.get("wait_target", 45.0)) - 3.0
		sc["reward_money"] = int(sc.get("reward_money", 0)) + 45

func _add_regional_obstacle_line(sc: Dictionary, terrain_type: String) -> void:
	var terrain: Array = sc.get("terrain", []).duplicate(true)
	var grid: Vector2i = sc.get("grid", Vector2i(18, 11))
	var blocked: Array[Vector2i] = _station_positions(sc.get("stations", []))
	var x: int = int(clamp(floor(float(grid.x) * 0.5), 3.0, float(grid.x - 4)))
	if terrain_type in ["river", "ocean"]:
		for y in range(1, grid.y - 1):
			var p := Vector2i(x, y)
			if not blocked.has(p):
				terrain.append({"pos": p, "type": terrain_type})
	else:
		var y: int = int(clamp(floor(float(grid.y) * 0.33), 2.0, float(grid.y - 3)))
		for tx in range(3, grid.x - 3, 2):
			var p := Vector2i(tx, y + ((tx + x) % 2))
			if not blocked.has(p):
				terrain.append({"pos": p, "type": terrain_type})
	sc["terrain"] = terrain

func _apply_upgrade_scenario_modifiers(sc: Dictionary) -> void:
	var platform_bonus := _upgrade_level("station_planning")
	if platform_bonus > 0:
		for st in sc.get("stations", []):
			st["platforms"] = int(st.get("platforms", 1)) + platform_bonus
	if _upgrade_level("throughput_boost") > 0:
		sc["wait_target"] = float(sc.get("wait_target", 45.0)) + float(_upgrade_level("throughput_boost")) * 3.0

func _record_run_completion(sc: Dictionary, avg_wait: float, productive: bool) -> void:
	var id := String(sc.get("id", ""))
	if not _is_run_scenario_id(id) or _run_completed_has(id):
		return
	var run_completed: Array = campaign.get("run_completed", [])
	run_completed.append(id)
	campaign["run_completed"] = run_completed
	campaign["run_step"] = min(RUN_LENGTH, run_completed.size())
	_complete_regional_tile_for_scenario(id)
	var reliability_score := 1.0
	if float(local.get("wait_target", 1.0)) > 0.0:
		reliability_score = clamp(1.0 - (avg_wait / max(1.0, float(local.get("wait_target", 1.0)))) * 0.35, 0.35, 1.0)
	if int(local.get("deadlocks", 0)) > 0:
		reliability_score *= 0.75
	if productive:
		reliability_score = min(1.0, reliability_score + 0.08)
	var traits: Dictionary = campaign.get("regional_traits", {})
	traits["through_traffic"] = int(traits.get("through_traffic", 0)) + int(sc.get("reward_load", 0))
	traits["capacity_rating"] = int(traits.get("capacity_rating", 0)) + int(sc.get("reward_capacity", 0))
	traits["reliability"] = clamp((float(traits.get("reliability", 1.0)) * 0.75) + reliability_score * 0.25, 0.2, 1.15)
	traits["burstiness"] = clamp(float(traits.get("burstiness", 0.0)) + (1.0 - reliability_score) * 0.3, 0.0, 2.0)
	var kind := String(sc.get("kind", "coal"))
	if kind == "coal":
		traits["coal_output"] = int(traits.get("coal_output", 0)) + _completion_progress()
	elif kind == "yard":
		traits["freight_output"] = int(traits.get("freight_output", 0)) + _completion_progress()
	elif kind == "steel":
		traits["steel_output"] = int(traits.get("steel_output", 0)) + _completion_progress()
	campaign["regional_traits"] = traits
	var history: Array = campaign.get("run_history", [])
	history.append({
		"id": id,
		"name": sc.get("name", id),
		"step": campaign["run_step"],
		"output": _completion_progress(),
		"avg_wait": avg_wait,
		"deadlocks": int(local.get("deadlocks", 0)),
		"reliability": reliability_score,
		"productive": productive
	})
	campaign["run_history"] = history
	if int(campaign["run_step"]) >= RUN_LENGTH:
		campaign["run_won"] = true
		campaign["run_available"] = []
	else:
		campaign["run_available"] = []
		_ensure_run_choices()

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
	top_status.clip_text = true
	top_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	title.text = "TrainsTrainsTrains: Regional Run"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.html("#172028"))
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 84
	title.offset_top = 64
	title.offset_right = 520
	title.offset_bottom = 112
	add_child(title)

	var hint := Label.new()
	hint.text = "Choose an adjacent regional tile. Complete 20 contracts; each tile and upgrade changes the next map."
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color.html("#28363f"))
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.offset_left = 86
	hint.offset_top = 112
	hint.offset_right = 740
	hint.offset_bottom = 146
	add_child(hint)

	var reset_button := _add_button(self, "Reset\nProgress", func(): _reset_progress())
	reset_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_button.offset_left = 612
	reset_button.offset_top = 72
	reset_button.offset_right = 748
	reset_button.offset_bottom = 138

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
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	side_panel.add_child(side_box)
	side_text = RichTextLabel.new()
	side_text.fit_content = true
	side_text.scroll_active = false
	side_text.bbcode_enabled = true
	side_text.custom_minimum_size = Vector2(0, 360)
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", 16)
	side_text.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.78, 0.55))
	side_text.add_theme_constant_override("outline_size", 1)
	side_box.add_child(side_text)
	_build_upgrade_shop_buttons(side_box)
	_refresh_regional_side_text()

func _build_local_ui() -> void:
	tool_bar = null
	side_panel = null
	side_text = null
	dispatch_line_box = null
	dispatch_train_box = null
	dispatch_preview = null
	hud_bar = HBoxContainer.new()
	hud_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_bar.offset_left = -360
	hud_bar.offset_top = 8
	hud_bar.offset_right = -8
	hud_bar.offset_bottom = 48
	hud_bar.add_theme_constant_override("separation", 6)
	hud_bar.z_index = 30
	hud_bar.z_as_relative = false
	add_child(hud_bar)
	if top_status != null:
		top_status.offset_left = 14
		top_status.offset_top = 12
		top_status.offset_right = -380
		top_status.offset_bottom = 42
		top_status.add_theme_font_size_override("font_size", 16)

	_add_button(hud_bar, "Pause", func(): _toggle_pause())
	_add_button(hud_bar, "1x/2x", func(): _toggle_speed())
	_add_button(hud_bar, "Reset", func(): _restart_trains_only())
	_add_button(hud_bar, "Region", func(): _return_to_region())

	_build_mobile_overlay_ui()
	_refresh_local_side_text()

func _build_upgrade_shop_buttons(parent: VBoxContainer) -> void:
	_ensure_run_state()
	var defs := _upgrade_defs()
	var header := Label.new()
	header.text = "Upgrade Shop"
	header.add_theme_color_override("font_color", Color.html("#172028"))
	header.add_theme_font_size_override("font_size", 18)
	parent.add_child(header)
	for offer_id in campaign.get("upgrade_shop", []):
		var id := String(offer_id)
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		var b := _add_button(parent, "%s\n$%d" % [def.get("name", id), int(def.get("cost", 0))], func(upgrade_id := id): _purchase_upgrade(upgrade_id))
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = int(campaign.get("money", 0)) < int(def.get("cost", 0))
		b.add_theme_font_size_override("font_size", 13)

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
	if parent == tool_bar:
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(b)
	if parent == hud_bar:
		b.custom_minimum_size = Vector2(82, 38)
		b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _fit_sidebar_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_mobile_overlay_ui() -> void:
	context_menu_layer = Control.new()
	context_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	context_menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_menu_layer.z_index = 45
	context_menu_layer.z_as_relative = false
	add_child(context_menu_layer)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 18
	toast_label.offset_top = -64
	toast_label.offset_right = -18
	toast_label.offset_bottom = -18
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("font_color", Color.html("#172028"))
	toast_label.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.92), Color.html("#172028"), 2, 8))
	toast_label.z_index = 35
	toast_label.z_as_relative = false
	add_child(toast_label)

	inspect_chip = RichTextLabel.new()
	inspect_chip.bbcode_enabled = true
	inspect_chip.scroll_active = false
	inspect_chip.fit_content = true
	inspect_chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inspect_chip.offset_left = 18
	inspect_chip.offset_top = 62
	inspect_chip.offset_right = 420
	inspect_chip.offset_bottom = 126
	inspect_chip.add_theme_color_override("default_color", Color.html("#172028"))
	inspect_chip.add_theme_font_size_override("normal_font_size", 14)
	inspect_chip.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.92), Color.html("#172028"), 2, 8))
	inspect_chip.z_index = 35
	inspect_chip.z_as_relative = false
	add_child(inspect_chip)

	service_edit_bar = HBoxContainer.new()
	service_edit_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	service_edit_bar.offset_left = 18
	service_edit_bar.offset_top = -116
	service_edit_bar.offset_right = -18
	service_edit_bar.offset_bottom = -70
	service_edit_bar.add_theme_constant_override("separation", 8)
	service_edit_bar.z_index = 36
	service_edit_bar.z_as_relative = false
	add_child(service_edit_bar)

	service_edit_label = Label.new()
	service_edit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_edit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_edit_label.add_theme_font_size_override("font_size", 14)
	service_edit_label.add_theme_color_override("font_color", Color.html("#172028"))
	service_edit_label.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.94), Color.html("#172028"), 2, 8))
	service_edit_bar.add_child(service_edit_label)
	var complete_button := _add_button(service_edit_bar, "Done", func(): _complete_service_edit())
	complete_button.custom_minimum_size = Vector2(88, 44)
	var cancel_button := _add_button(service_edit_bar, "Cancel", func(): _cancel_service_edit())
	cancel_button.custom_minimum_size = Vector2(96, 44)

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
		local_message = "Line tool selected. Click a source station to select its first line, or use the dispatch panel to create additional lines."
	else:
		local_message = "Tool selected: %s" % tool.capitalize()
	_refresh_tool_button_styles()
	_update_status_labels()
	_refresh_local_side_text()
	queue_redraw()

func _open_context_menu_at(screen_pos: Vector2, target_type: String, target_id: String, grid_pos: Vector2i) -> void:
	if context_menu_layer == null:
		return
	_close_context_menu()
	context_menu_open = true
	context_target_type = target_type
	context_target_id = target_id
	context_target_pos = grid_pos
	context_screen_pos = screen_pos
	_build_radial_menu(_context_actions_for_target(target_type, target_id, grid_pos))
	_show_inspect_chip_for_target(target_type, target_id, grid_pos)
	queue_redraw()

func _close_context_menu() -> void:
	context_menu_open = false
	context_target_type = ""
	context_target_id = ""
	context_target_pos = Vector2i(-999, -999)
	if context_menu_layer != null:
		_clear_control_children(context_menu_layer)

func _context_actions_for_target(target_type: String, target_id: String, grid_pos: Vector2i) -> Array:
	var actions: Array = []
	if target_type == "station" and station_by_id.has(target_id):
		_append_station_context_actions(actions, target_id)
	elif target_type == "station_train":
		var station_id := _station_id_from_combo_target(target_id)
		var train_id := _train_id_from_combo_target(target_id)
		if station_by_id.has(station_id):
			_append_station_context_actions(actions, station_id)
		if train_id != "":
			_append_train_context_actions(actions, train_id)
	elif target_type == "train":
		_append_train_context_actions(actions, target_id)
	elif target_type == "signal":
		actions.append({"label": "Rotate", "callback": func(p := grid_pos): _rotate_signal_at(p)})
		actions.append({"label": "Pair", "callback": func(p := grid_pos): _place_signal_pair(p, _pair_signal_type_for(p))})
		actions.append({"label": "Erase", "callback": func(p := grid_pos): _erase_signal_or_track(p)})
	elif target_type in ["track", "tile"]:
		if target_type == "tile":
			actions.append({"label": "Track", "callback": func(p := grid_pos): _place_track(p)})
		actions.append({"label": "Block", "callback": func(p := grid_pos): _place_signal(p, "block")})
		actions.append({"label": "Chain", "callback": func(p := grid_pos): _place_signal(p, "chain")})
		actions.append({"label": "Erase", "callback": func(p := grid_pos): _erase_signal_or_track(p)})
	if actions.is_empty():
		actions.append({"label": "Track", "callback": func(p := grid_pos): _place_track(p)})
	return actions

func _append_station_context_actions(actions: Array, station_id: String) -> void:
	var st: Dictionary = station_by_id[station_id]
	if st.get("role", "") == "source":
		actions.append({"label": "Service", "callback": func(id := station_id): _context_create_service(id)})
		actions.append({"label": "Train", "callback": func(id := station_id): _context_buy_train_for_station(id)})
	if _source_has_lines(station_id) or String(st.get("role", "")) != "source":
		actions.append({"label": "Edit", "callback": func(id := station_id): _context_edit_service_for_station(id)})
	actions.append({"label": "Platform", "callback": func(id := station_id): _add_platform_at(id)})

func _append_train_context_actions(actions: Array, train_id: String) -> void:
	actions.append({"label": "Assign", "callback": func(id := train_id): _context_assign_train(id)})
	actions.append({"label": "Clear", "callback": func(id := train_id): _context_clear_train_line(id)})
	actions.append({"label": "Inspect", "callback": func(id := train_id): _show_inspect_chip_for_target("train", id, Vector2i(-999, -999))})

func _build_radial_menu(actions: Array) -> void:
	if context_menu_layer == null:
		return
	var count: int = max(1, actions.size())
	var radius: float = 72.0 + float(max(0, count - 4)) * 10.0
	var center := _clamped_context_center(context_screen_pos, radius)
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var angle := -PI * 0.5 + (TAU * float(i) / float(count))
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		var button := Button.new()
		button.text = String(action.get("label", "Action"))
		button.custom_minimum_size = Vector2(82, 44)
		button.position = pos - Vector2(41, 22)
		button.z_index = 46
		button.z_as_relative = false
		_style_button(button)
		var callback: Callable = action.get("callback", Callable())
		button.pressed.connect(func(cb := callback): _run_context_action(cb))
		context_menu_layer.add_child(button)

func _run_context_action(callback: Callable) -> void:
	_close_context_menu()
	if callback.is_valid():
		callback.call()
	_refresh_local_side_text()
	queue_redraw()

func _clamped_context_center(screen_pos: Vector2, radius: float = 72.0) -> Vector2:
	var margin: float = radius + 48.0
	return Vector2(clamp(screen_pos.x, margin, max(margin, size.x - margin)), clamp(screen_pos.y, margin, max(margin, size.y - margin)))

func _context_target_at(screen_pos: Vector2) -> Dictionary:
	var station_id := _hit_station_id(screen_pos)
	if station_id != "":
		var train_id_at_station := _hit_train_id(screen_pos)
		if train_id_at_station != "":
			return {"type": "station_train", "id": _combo_target_id(station_id, train_id_at_station), "pos": station_by_id[station_id]["pos"]}
		return {"type": "station", "id": station_id, "pos": station_by_id[station_id]["pos"]}
	var train_id := _hit_train_id(screen_pos)
	if train_id != "":
		return {"type": "train", "id": train_id, "pos": Vector2i(-999, -999)}
	var signal_pos := _hit_signal_pos(screen_pos)
	if signal_pos.x > -900:
		return {"type": "signal", "id": "", "pos": signal_pos}
	var gp := _screen_to_grid(screen_pos)
	if _is_in_grid(gp) and tracks.has(gp):
		return {"type": "track", "id": "", "pos": gp}
	return {"type": "tile", "id": "", "pos": gp}

func _combo_target_id(station_id: String, train_id: String) -> String:
	return "%s|%s" % [station_id, train_id]

func _station_id_from_combo_target(target_id: String) -> String:
	var parts := target_id.split("|", false, 1)
	return String(parts[0]) if not parts.is_empty() else ""

func _train_id_from_combo_target(target_id: String) -> String:
	var parts := target_id.split("|", false, 1)
	return String(parts[1]) if parts.size() > 1 else ""

func _hit_station_id(pos: Vector2) -> String:
	_update_board_layout()
	for station_id in station_by_id.keys():
		var st: Dictionary = station_by_id[station_id]
		if _grid_to_screen(st["pos"]).distance_to(pos) < max(28.0, cell_size * 0.52):
			return String(station_id)
	return ""

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
	var tile := _regional_tile_at_screen(pos)
	if not tile.is_empty():
		var key := String(tile.get("key", ""))
		var scenario_id := String(tile.get("scenario_id", ""))
		if scenario_id != "" and _regional_available_tile_keys().has(key):
			campaign["active_regional_tile"] = key
			start_scenario(scenario_id)
		return
	for s in _tutorial_regional_scenarios():
		var node_pos: Vector2 = _regional_node_position(s["id"])
		if pos.distance_to(node_pos) <= 54.0:
			if _scenario_is_available(s["id"]):
				start_scenario(s["id"])
			return

func start_scenario(id: String) -> void:
	if _is_run_scenario_id(id):
		var active_tile := _regional_tile_for_key(String(campaign.get("active_regional_tile", "")))
		if active_tile.is_empty() or String(active_tile.get("scenario_id", "")) != id:
			var tile := _regional_tile_for_scenario(id)
			campaign["active_regional_tile"] = String(tile.get("key", ""))
	var scenario := _apply_run_pressure_to_scenario(_get_scenario(id))
	if scenario.is_empty():
		return
	screen = Screen.LOCAL
	selected_tool = "track"
	selected_train_id = ""
	selected_signal_pos = Vector2i(-999, -999)
	context_menu_open = false
	context_target_type = ""
	context_target_id = ""
	context_target_pos = Vector2i(-999, -999)
	service_edit_line_id = ""
	press_active = false
	press_context_consumed = false
	press_moved = false
	erased_signal_targets.clear()
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
		"money": int(scenario["start_budget"]),
		"materials": int(campaign["materials"]),
		"delivered": 0,
		"processed": 0,
		"productive_progress": 0,
		"steel_buffer": 0,
		"coal_buffer": 0,
		"production_remainder": 0.0,
		"storage": {},
		"infra_cost": 0,
		"elapsed_time": 0.0,
		"train_vouchers": _upgrade_level("train_voucher"),
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
	if _is_run_scenario_id(id):
		return not bool(campaign.get("run_won", false)) and (campaign.get("run_available", []) as Array).has(id)
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
	var y := size.y * 0.86
	if _is_run_scenario_id(id):
		var completed: Array = campaign.get("run_completed", [])
		var visible_order: Array = []
		for done_id in completed:
			visible_order.append(String(done_id))
		for available_id in campaign.get("run_available", []):
			if not visible_order.has(String(available_id)):
				visible_order.append(String(available_id))
		var idx: int = int(max(0, visible_order.find(id)))
		var columns: int = 5
		var row: int = int(floor(float(idx) / float(columns)))
		var col: int = idx % columns
		var left: float = size.x * 0.12
		var usable_width: float = max(460.0, size.x * 0.58)
		var x: float = left + float(col) * (usable_width / float(columns - 1))
		var start_y: float = size.y * 0.29
		return Vector2(x, start_y + float(row) * 92.0)
	if id == "coal_valley":
		return Vector2(size.x * 0.18, y)
	if id == "central_yard":
		return Vector2(size.x * 0.36, y)
	if id == "steelworks":
		return Vector2(size.x * 0.54, y)
	return Vector2(size.x * 0.72, y)

func _regional_map_origin() -> Vector2:
	var tile_size := _regional_draw_tile_size()
	var map_size := Vector2(float(REGIONAL_GRID.x), float(REGIONAL_GRID.y)) * tile_size
	var right_limit := size.x - 390.0
	return Vector2(max(24.0, (right_limit - map_size.x) * 0.5), 190.0)

func _regional_draw_tile_size() -> float:
	return clamp(floor(min((max(size.x - 430.0, 420.0)) / float(REGIONAL_GRID.x), (max(size.y - 300.0, 320.0)) / float(REGIONAL_GRID.y))), 42.0, 72.0)

func _regional_tile_rect(tile: Dictionary) -> Rect2:
	var tile_size := _regional_draw_tile_size()
	var origin := _regional_map_origin()
	return Rect2(origin + Vector2(float(tile.get("x", 0)) * tile_size, float(tile.get("y", 0)) * tile_size), Vector2(tile_size, tile_size))

func _regional_tile_at_screen(pos: Vector2) -> Dictionary:
	for tile in campaign.get("regional_map", []):
		if _regional_tile_rect(tile).has_point(pos):
			return tile
	return {}

func _update_board_layout() -> void:
	if local.is_empty() or not local.has("scenario"):
		cell_size = CELL
		grid_origin = GRID_ORIGIN
		return
	_apply_local_side_panel_layout()
	var grid: Vector2i = local["scenario"].get("grid", Vector2i(14, 9))
	var top_reserved := 64.0
	var bottom_reserved := 72.0
	var horizontal_margin := 16.0
	var max_cell_from_width: float = (max(size.x, 640.0) - horizontal_margin * 2.0) / float(grid.x)
	var max_cell_from_height: float = (max(size.y, 480.0) - top_reserved - bottom_reserved) / float(grid.y)
	cell_size = clamp(floor(min(max_cell_from_width, max_cell_from_height)), 46.0, 78.0)
	grid_origin = Vector2(horizontal_margin, top_reserved)

func _handle_local_click(pos: Vector2) -> void:
	var gp := _screen_to_grid(pos)
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
	if selected_tool != "line":
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
			_toggle_signal_pair_state(hit_signal, _signal_type(hit_signal))
			selected_train_id = ""
			dragging = false
			_refresh_local_side_text()
			queue_redraw()
			return
	var station_id := _hit_station_id(pos)
	if station_id != "":
		selected_train_id = ""
		selected_signal_pos = Vector2i(-999, -999)
		_show_inspect_chip_for_target("station", station_id, station_by_id[station_id]["pos"])
		_show_toast("Hold %s for actions." % station_by_id[station_id].get("name", station_id))
		queue_redraw()
		return
	if selected_tool != "line":
		var hit_train := _hit_train_id(pos)
		if hit_train != "":
			selected_train_id = hit_train
			selected_signal_pos = Vector2i(-999, -999)
			dragging = false
			_refresh_local_side_text()
			queue_redraw()
			return
	if not _is_in_grid(gp):
		_select_train_or_signal(pos)
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
		if _terrain_blocks_track(gp):
			local_message = "%s blocks new track here. Route around it." % _terrain_label(_terrain_type_at(gp))
			return
		var build_cost := _track_build_cost(gp)
		if _spend(build_cost, 0):
			tracks[gp] = true
			local["infra_cost"] += build_cost
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
			if _terrain_blocks_track(p):
				local_message = "%s blocks the track run at %s. Route around it." % [_terrain_label(_terrain_type_at(p)), _tile_label(p)]
				break
			var build_cost := _track_build_cost(p)
			if not _spend(build_cost, 0):
				break
			tracks[p] = true
			local["infra_cost"] += build_cost
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
	if _spend(money_cost):
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
	if _spend(money_cost):
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
	if target_id == "":
		return
	_add_platform_at(target_id)

func _add_platform_at(station_id: String) -> void:
	if not station_by_id.has(station_id) or not _spend(200):
		return
	station_by_id[station_id]["platforms"] = int(station_by_id[station_id].get("platforms", 1)) + 1
	local["infra_cost"] += 200
	local_message = "%s now has %d platforms." % [station_by_id[station_id]["name"], station_by_id[station_id]["platforms"]]
	_refresh_local_side_text()

func _context_create_service(source_id: String) -> void:
	if not station_by_id.has(source_id):
		return
	var line_id := _create_new_line_for_source(source_id) if _source_has_lines(source_id) else _create_or_get_line_for_source(source_id)
	if line_id == "":
		local_message = "No service can start at %s." % station_by_id[source_id].get("name", source_id)
		return
	lines[line_id]["route"] = []
	lines[line_id]["name"] = _line_name_for_route([source_id], int(lines[line_id].get("ordinal", 1)))
	_reapply_line_to_assigned_trains(line_id)
	_start_service_edit(line_id)

func _context_edit_service_for_station(station_id: String) -> void:
	var line_id := _line_id_for_station_context(station_id)
	if line_id == "":
		local_message = "Create a service from a source station first."
		return
	_start_service_edit(line_id)

func _line_id_for_station_context(station_id: String) -> String:
	if selected_line_id != "" and lines.has(selected_line_id):
		return selected_line_id
	for line_id in lines.keys():
		var route: Array = lines[line_id].get("route", [])
		if route.has(station_id):
			return String(line_id)
	for line_id in lines.keys():
		if _source_id_for_line(lines[line_id]) == station_id:
			return String(line_id)
	return ""

func _start_service_edit(line_id: String) -> void:
	if not lines.has(line_id):
		return
	selected_line_id = line_id
	service_edit_line_id = line_id
	editing_line_stops = true
	selected_tool = "line"
	local_message = "Editing %s. Tap station plus signs, then Done." % lines[line_id]["name"]
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _complete_service_edit() -> void:
	_complete_line_stop_edit()
	service_edit_line_id = ""

func _cancel_service_edit() -> void:
	editing_line_stops = false
	service_edit_line_id = ""
	selected_tool = "track"
	local_message = "Service editing canceled."
	_refresh_tool_button_styles()
	_refresh_local_side_text()
	queue_redraw()

func _context_buy_train_for_station(source_id: String) -> void:
	if not station_by_id.has(source_id):
		return
	_buy_train_at(station_by_id[source_id]["pos"])

func _context_assign_train(train_id: String) -> void:
	selected_train_id = train_id
	if selected_line_id == "" or not lines.has(selected_line_id):
		selected_line_id = _first_valid_line_id()
	if selected_line_id == "":
		local_message = "Create a service before assigning trains."
		return
	_assign_selected_train_to_selected_line()

func _context_clear_train_line(train_id: String) -> void:
	selected_train_id = train_id
	_clear_selected_train_line()

func _first_valid_line_id() -> String:
	for line_id in lines.keys():
		if _line_has_valid_orders(String(line_id)):
			return String(line_id)
	return ""

func _line_id_for_source(source_id: String, ordinal: int = 1) -> String:
	if ordinal <= 1:
		return "line_%s" % source_id
	return "line_%s_%d" % [source_id, ordinal]

func _line_name_for_route(route: Array, ordinal: int = 1) -> String:
	if route.is_empty():
		return "Line"
	var first: Dictionary = station_by_id[route[0]]
	var last: Dictionary = station_by_id[route[max(0, route.size() - 1)]]
	var base := "%s Line" % first.get("name", last.get("name", "Route"))
	if ordinal > 1:
		return "%s %d" % [base, ordinal]
	return base

func _create_or_get_line_for_source(source_id: String) -> String:
	return _create_line_for_source(source_id, false)

func _create_new_line_for_source(source_id: String) -> String:
	return _create_line_for_source(source_id, true)

func _create_line_for_source(source_id: String, force_new: bool) -> String:
	var route: Array = _route_for_source(source_id)
	if route.is_empty():
		return ""
	var ordinal := _next_line_ordinal_for_source(source_id) if force_new else 1
	var line_id: String = _line_id_for_source(source_id, ordinal)
	if lines.has(line_id):
		return line_id
	lines[line_id] = {
		"id": line_id,
		"name": _line_name_for_route(route, ordinal),
		"route": route,
		"source_id": source_id,
		"ordinal": ordinal
	}
	return line_id

func _next_line_ordinal_for_source(source_id: String) -> int:
	var highest := 0
	for line_id in lines.keys():
		var line: Dictionary = lines[line_id]
		if _source_id_for_line(line) == source_id:
			highest = max(highest, int(line.get("ordinal", 1)))
	return highest + 1

func _source_has_lines(source_id: String) -> bool:
	for line_id in lines.keys():
		if _source_id_for_line(lines[line_id]) == source_id:
			return true
	return false

func _source_id_for_line(line: Dictionary) -> String:
	if line.has("source_id"):
		return String(line["source_id"])
	var route: Array = line.get("route", [])
	if not route.is_empty():
		return String(route[0])
	return ""

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
	local_message = "%s selected. Select an available train, assign it, or create another line from this source in the dispatch panel." % lines[line_id]["name"]

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
		if int(local.get("train_vouchers", 0)) > 0:
			local["train_vouchers"] = int(local.get("train_vouchers", 0)) - 1
		else:
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
	b.custom_minimum_size = Vector2(0, 38)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	_style_button(b, selected)
	b.add_theme_font_size_override("font_size", 13)
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

func _create_new_line_from_dispatch(source_id: String) -> void:
	var line_id := _create_new_line_for_source(source_id)
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
	lines[selected_line_id]["name"] = _line_name_for_route(route, int(lines[selected_line_id].get("ordinal", 1)))
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
			var status := "%d stops | %d trains" % [route.size(), _line_train_count(line_id)]
			if route.size() < 2:
				status = "needs stops"
			var label := "%s\n%s" % [line["name"], status]
			_add_dispatch_button(dispatch_line_box, label, line_id == selected_line_id, func(id := String(line_id)): _select_line_from_dispatch(id))
	for station_id in station_by_id.keys():
		var st: Dictionary = station_by_id[station_id]
		if st.get("role", "") == "source":
			if not _route_for_source(station_id).is_empty():
				var label := "New\n%s Line" % st["name"] if _source_has_lines(station_id) else "Create\n%s Line" % st["name"]
				_add_dispatch_button(dispatch_line_box, label, false, func(id := String(station_id)): _create_new_line_from_dispatch(id))

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
			var next_label := " -"
			if String(t.get("line_id", "")) != "" and not (t.get("route", []) as Array).is_empty():
				next_label = " -> %s" % _next_stop_name_for_train(t)
			var label := "%s  %s  %s\n%s%s" % [train_id, cargo_text, state_label, _short_ui_text(line_label, 28), next_label]
			_add_dispatch_button(dispatch_train_box, label, train_id == selected_train_id, func(id := train_id): _select_train_from_dispatch(id))

	dispatch_preview.text = _line_cargo_preview(selected_line_id)

func _train_card_issue_label(t: Dictionary) -> String:
	var state := String(t.get("state", ""))
	if not (state in ["NoRoute", "WaitingAtSignal", "Blocked", "WaitingForOrders", "WaitingForPlatform"]):
		return ""
	var reason := _display_reason_for_train(t)
	if reason == "" or reason == "Moving normally.":
		return ""
	if reason.length() > 72:
		reason = reason.substr(0, 69) + "..."
	return "\nWhy: %s" % reason

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
		if int(local.get("train_vouchers", 0)) > 0:
			local["train_vouchers"] = int(local.get("train_vouchers", 0)) - 1
		else:
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

func _spend(money: int, _materials: int = 0) -> bool:
	# Local maps are permissive: construction records material footprint for rewards
	# instead of blocking player experimentation with a cash budget.
	return true

func _update_local(delta: float) -> void:
	local["elapsed_time"] = float(local.get("elapsed_time", 0.0)) + delta
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
	if amount > 0:
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
	var reward_money := _completion_reward_money(sc, avg_wait, productive)
	var material_par := _reward_material_par(sc)
	var time_par := _reward_time_par(sc)
	var elapsed := float(local.get("elapsed_time", 0.0))
	result_data = {
		"id": local["id"],
		"name": local["name"],
		"text": "[b]%s[/b]\n\n%s: %d / %d\nTotal Output: %d\nFleet: %d / %d trains\nAverage Train Wait: %.1fs / %.0fs target\nTime: %.0fs / %.0fs par\nMaterial Used: %d / %d par\nDeadlocks: %d\nMaximum Queue: %d\n\nRegional Reward:\n+$%d\n+%d Traffic Load\n+%d Traffic Capacity" % [
			quality,
			_progress_label(),
			_completion_progress(),
			int(local["target"]),
			_objective_progress(),
			_active_train_count(),
			fleet_goal,
			avg_wait,
			float(local["wait_target"]),
			elapsed,
			time_par,
			int(local.get("infra_cost", 0)),
			material_par,
			int(local.get("deadlocks", 0)),
			int(local.get("max_queue", 0)),
			reward_money,
			int(sc.get("reward_load", 0)),
			int(sc.get("reward_capacity", 0))
		]
	}
	if not campaign["completed"].has(local["id"]):
		campaign["completed"].append(local["id"])
		campaign["money"] = int(campaign["money"]) + reward_money
		campaign["traffic_load"] = int(campaign["traffic_load"]) + int(sc.get("reward_load", 0))
		campaign["traffic_capacity"] = int(campaign["traffic_capacity"]) + int(sc.get("reward_capacity", 0))
		_record_run_completion(sc, avg_wait, productive)
		_save_campaign()
	screen = Screen.RESULTS
	rebuild_ui()
	queue_redraw()

func _completion_reward_money(sc: Dictionary, avg_wait: float, productive: bool) -> int:
	var base := int(sc.get("reward_money", 0))
	var effective_material: int = int(float(local.get("infra_cost", 0)) * max(0.55, 1.0 - float(_upgrade_level("material_efficiency")) * 0.10))
	var material_bonus: int = int(max(0.0, float(_reward_material_par(sc) - effective_material) * 0.22))
	var time_bonus: int = int(max(0.0, _reward_time_par(sc) - float(local.get("elapsed_time", 0.0))) * 1.4)
	var wait_bonus: int = int(max(0.0, float(local.get("wait_target", 0.0)) - avg_wait) * 2.0)
	var reliability_bonus := 120 if productive else 0
	var over_target_bonus: int = int(max(0, _completion_progress() - int(local.get("target", 0))) * 0.4)
	var total: int = max(0, base + material_bonus + time_bonus + wait_bonus + reliability_bonus + over_target_bonus)
	return int(round(float(total) * (1.0 + float(_upgrade_level("reward_multiplier")) * 0.10)))

func _reward_material_par(sc: Dictionary) -> int:
	var ghost: Array = sc.get("ghost", [])
	var route: Array = sc.get("route", [])
	var track_steps: int = max(0, ghost.size() - 1)
	if track_steps <= 0:
		track_steps = max(6, route.size() * 5)
	var signal_allowance: int = max(2, int(ceil(float(track_steps) / 5.0)))
	var station_allowance: int = max(0, route.size() - 2)
	return track_steps * 25 + signal_allowance * 80 + _fleet_goal() * 300 + station_allowance * 200

func _reward_time_par(sc: Dictionary) -> float:
	var target_amount := float(sc.get("target", local.get("target", 80)))
	var route: Array = sc.get("route", [])
	var route_pressure := float(max(2, route.size())) * 18.0
	var fleet_pressure := float(_fleet_goal()) * 20.0
	return max(75.0, target_amount * 1.45 + route_pressure + fleet_pressure)

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

func _terrain_type_at(p: Vector2i) -> String:
	var scenario: Dictionary = local.get("scenario", {})
	for item in scenario.get("terrain", []):
		if item.get("pos", Vector2i(-999, -999)) == p:
			return String(item.get("type", ""))
	return ""

func _terrain_blocks_track(p: Vector2i) -> bool:
	if station_by_pos.has(p):
		return false
	var terrain_type := _terrain_type_at(p)
	return terrain_type in ["mountain", "rock", "ocean"]

func _track_build_cost(p: Vector2i) -> int:
	var terrain_type := _terrain_type_at(p)
	if terrain_type == "river":
		return 85
	return 25

func _terrain_label(terrain_type: String) -> String:
	if terrain_type == "mountain":
		return "Mountain"
	if terrain_type == "rock":
		return "Rock"
	if terrain_type == "river":
		return "River"
	if terrain_type == "ocean":
		return "Ocean"
	return "Terrain"

func _update_status_labels() -> void:
	if top_status == null:
		return
	if screen == Screen.REGIONAL:
		var warning := "  Network Congested: income reduced" if int(campaign["traffic_load"]) > int(campaign["traffic_capacity"]) else ""
		top_status.text = "Money: $%d   Traffic: %d / %d%s" % [campaign["money"], campaign["traffic_load"], campaign["traffic_capacity"], warning]
	elif screen == Screen.LOCAL:
		top_status.text = "%s | %d/%d %s | Used %d | Time %.0fs | Fleet %d/%d | Wait %.0fs" % [
			local.get("name", ""),
			_completion_progress(),
			local.get("target", 0),
			_progress_label(),
			int(local.get("infra_cost", 0)),
			float(local.get("elapsed_time", 0.0)),
			_active_train_count(),
			_fleet_goal(),
			_average_wait()
		]
	else:
		top_status.text = "Scenario results"

func _refresh_regional_side_text() -> void:
	if side_text == null:
		return
	_ensure_run_state()
	var traits: Dictionary = campaign.get("regional_traits", {})
	var text: String = "[b]Roguelike Regional Run[/b]\n\n"
	text += "Complete %d adjacent regional tiles. Terrain, upgrades, and previous results shape every local contract.\n\n" % RUN_LENGTH
	text += "Run Progress: %d / %d\n" % [int(campaign.get("run_step", 0)), RUN_LENGTH]
	text += "Adjacent Choices: %d\n" % [(campaign.get("run_available", []) as Array).size()]
	text += "Position: %s\nMoney: $%d\n" % [String(campaign.get("regional_position", REGIONAL_START_KEY)), int(campaign.get("money", 0))]
	text += "Through Traffic: %d\nCapacity Rating: %d\nReliability: %.0f%%\nCoal: %d  Freight: %d  Steel: %d\n\n" % [
		int(traits.get("through_traffic", 0)),
		int(traits.get("capacity_rating", 0)),
		float(traits.get("reliability", 1.0)) * 100.0,
		int(traits.get("coal_output", 0)),
		int(traits.get("freight_output", 0)),
		int(traits.get("steel_output", 0))
	]
	text += "[b]Upgrades[/b]\nPermanent: %s\nRun: %s\n\n" % [_upgrade_summary("permanent_upgrades"), _upgrade_summary("run_upgrades")]
	if bool(campaign.get("run_won", false)):
		text += "[color=green][b]Run Complete[/b][/color]\nThe region survived the full 20-map expansion.\n\n"
	text += "[b]Adjacent Contracts[/b]\n"
	for id in campaign.get("run_available", []):
		var tile := _regional_tile_for_scenario(String(id))
		var s := _get_scenario(String(id))
		if not tile.is_empty() and not s.is_empty():
			text += "[b]%s[/b] T%d %s\n%s\n\n" % [s["name"], int(tile.get("tier", 1)), String(tile.get("terrain", "plains")).capitalize(), s["objective"]]
	text += "[b]Tutorial Contracts[/b]\n"
	for s in scenarios:
		var id := String(s.get("id", ""))
		if _is_run_scenario_id(id):
			continue
		var state := "Completed" if campaign["completed"].has(id) else ("Available" if _scenario_is_available(id) else "Locked")
		text += "%s - %s\n" % [s["name"], state]
	if int(campaign["traffic_load"]) > int(campaign["traffic_capacity"]):
		text += "[color=orange]Network Congested[/color]\nTraffic load exceeds capacity. Future maps begin under extra pressure.\n"
	side_text.text = text

func _upgrade_summary(bucket_key: String) -> String:
	var bucket: Dictionary = campaign.get(bucket_key, {})
	if bucket.is_empty():
		return "none"
	var defs := _upgrade_defs()
	var parts: Array[String] = []
	for id in bucket.keys():
		var def: Dictionary = defs.get(id, {"name": id})
		parts.append("%s x%d" % [def.get("name", id), int(bucket.get(id, 0))])
	return ", ".join(parts)

func _refresh_local_side_text() -> void:
	if screen != Screen.LOCAL:
		return
	var text: String = "[b]%s[/b]  %s %d/%d  Fleet %d/%d  Wait %.0fs\n" % [
		local.get("name", ""),
		_progress_label(),
		_completion_progress(),
		int(local.get("target", 0)),
		_active_train_count(),
		_fleet_goal(),
		_average_wait()
	]
	text += "Used %d  Time %.0fs  Depot %d  Tool %s" % [int(local.get("infra_cost", 0)), float(local.get("elapsed_time", 0.0)), _available_train_count(), selected_tool.capitalize()]
	if selected_train_id != "":
		for t in trains:
			if t["id"] == selected_train_id:
				text += "\n[b]%s[/b] %s -> %s. %s" % [t["id"], String(t.get("state", "")), _next_stop_name_for_train(t), _short_train_hint(t)]
				break
	if selected_signal_pos.x > -900:
		var bid := int(block_for_tile.get(selected_signal_pos, -1))
		text += "\n[b]Signal[/b] %s %s, block %s, %s" % [_signal_type(selected_signal_pos), _dir_name(_signal_dir(selected_signal_pos)), bid, _signal_summary(selected_signal_pos)]
	if local_message != "":
		text += "\n%s" % _short_ui_text(local_message, 96)
	text += "\nDeadlocks %d  Queue %d  Material %d" % [local.get("deadlocks", 0), local.get("max_queue", 0), local.get("infra_cost", 0)]
	if local.get("kind", "") == "steel":
		text += "  Steel %d" % int(local.get("steel_buffer", 0))
	if side_text != null:
		side_text.text = text
	_show_toast(local_message)
	_refresh_inspect_chip()
	_refresh_service_edit_bar()
	_update_status_labels()
	_refresh_dispatch_panel()

func _show_toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = _short_ui_text(message, 96) if message != "" else "Drag to build track. Hold anything for actions."

func _refresh_inspect_chip() -> void:
	if inspect_chip == null:
		return
	if selected_train_id != "":
		_show_inspect_chip_for_target("train", selected_train_id, Vector2i(-999, -999))
		return
	if selected_signal_pos.x > -900:
		_show_inspect_chip_for_target("signal", "", selected_signal_pos)
		return
	inspect_chip.text = ""
	inspect_chip.visible = false

func _show_inspect_chip_for_target(target_type: String, target_id: String, grid_pos: Vector2i) -> void:
	if inspect_chip == null:
		return
	var text := ""
	if target_type == "train":
		for t in trains:
			if String(t.get("id", "")) == target_id:
				text = "[b]%s[/b] %s  %s\nNext: %s  %s" % [
					t.get("id", target_id),
					String(t.get("state", "")),
					_cargo_label(t),
					_next_stop_name_for_train(t),
					_short_train_hint(t)
				]
				break
	elif target_type == "signal" and grid_pos.x > -900:
		var bid := int(block_for_tile.get(grid_pos, -1))
		text = "[b]Signal[/b] %s %s\nBlock %s  %s" % [_signal_type(grid_pos), _dir_name(_signal_dir(grid_pos)), bid, _signal_summary(grid_pos)]
	elif target_type == "station" and station_by_id.has(target_id):
		var st: Dictionary = station_by_id[target_id]
		text = "[b]%s[/b]\n%s %s  P%d" % [st.get("name", target_id), _station_output_badge_text(st), _station_need_badge_text(st), int(st.get("platforms", 1))]
	elif target_type == "station_train":
		var station_id := _station_id_from_combo_target(target_id)
		var train_id := _train_id_from_combo_target(target_id)
		if station_by_id.has(station_id):
			var st: Dictionary = station_by_id[station_id]
			text = "[b]%s[/b] + [b]%s[/b]\n%s %s  P%d" % [
				st.get("name", station_id),
				train_id,
				_station_output_badge_text(st),
				_station_need_badge_text(st),
				int(st.get("platforms", 1))
			]
	elif grid_pos.x > -900:
		text = "[b]%s[/b] %s" % [target_type.capitalize(), _tile_label(grid_pos)]
	inspect_chip.text = text
	inspect_chip.visible = text != ""

func _refresh_service_edit_bar() -> void:
	if service_edit_bar == null or service_edit_label == null:
		return
	service_edit_bar.visible = editing_line_stops and selected_line_id != "" and lines.has(selected_line_id)
	if not service_edit_bar.visible:
		return
	var route: Array = lines[selected_line_id].get("route", [])
	service_edit_label.text = "%s: %s" % [lines[selected_line_id].get("name", "Service"), _route_station_names(route, true) if not route.is_empty() else "tap station +"]

func _short_train_hint(t: Dictionary) -> String:
	var reason := _display_reason_for_train(t)
	if reason == "" or reason == "Moving normally.":
		return "Next rail: %s" % _next_leg_name_for_train(t)
	return _short_ui_text(reason, 74)

func _short_ui_text(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, max(0, limit - 3)) + "..."

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
	_draw_regional_tile_map()
	for s in _tutorial_regional_scenarios():
		var id := String(s["id"])
		var p := _regional_node_position(id)
		var completed: bool = campaign["completed"].has(id)
		var available: bool = _scenario_is_available(id)
		var col: Color = Color.html("#78d891") if completed else (Color.html("#ffe06d") if available else Color.html("#a5afb4"))
		var draw_size := Vector2(76, 76)
		if not _draw_piece(game_regional_node_texture, p, draw_size, 0.0, col):
			draw_circle(p, 38, col)
			draw_circle(p, 32, Color(1, 1, 1, 0.38))
		_draw_map_label(p + Vector2(-58, 48), String(s["name"]), 116, 13)
		var status := "Click" if available else ("Done" if completed else "Locked")
		_draw_map_label(p + Vector2(-42, 66), status, 84, 12, Color(1.0, 0.98, 0.84, 1.0))

func _draw_regional_tile_map() -> void:
	_ensure_run_state()
	var completed_tiles: Array = campaign.get("regional_completed_tiles", [])
	var visible_tiles: Array = campaign.get("regional_visible_tiles", [])
	var available_tiles := _regional_available_tile_keys()
	var current_key := String(campaign.get("regional_position", REGIONAL_START_KEY))
	for tile in campaign.get("regional_map", []):
		var rect := _regional_tile_rect(tile)
		var key := String(tile.get("key", ""))
		var visible := visible_tiles.has(key) or completed_tiles.has(key) or key == REGIONAL_START_KEY
		var col := Color(1, 1, 1, 1) if visible else Color(0.36, 0.39, 0.38, 0.58)
		_draw_regional_atlas_tile(_terrain_tile_index(String(tile.get("terrain", "plains"))), rect, col)
		draw_rect(rect, Color(0.05, 0.09, 0.11, 0.42), false, 1.0)
	for key in completed_tiles:
		var tile := _regional_tile_for_key(String(key))
		if not tile.is_empty():
			_draw_regional_atlas_tile(13, _regional_tile_rect(tile).grow(-8), Color(1, 1, 1, 0.92))
	for key in available_tiles:
		var tile := _regional_tile_for_key(String(key))
		if not tile.is_empty():
			_draw_regional_atlas_tile(12, _regional_tile_rect(tile).grow(-7), Color(1, 1, 1, 0.96))
	for tile in campaign.get("regional_map", []):
		var key := String(tile.get("key", ""))
		var scenario_id := String(tile.get("scenario_id", ""))
		if scenario_id == "" or not (visible_tiles.has(key) or completed_tiles.has(key) or key == current_key):
			continue
		var rect := _regional_tile_rect(tile)
		_draw_regional_atlas_tile(10, rect.grow(-14), Color(1, 1, 1, 0.9))
		if available_tiles.has(key):
			_draw_map_label(rect.position + Vector2(3, rect.size.y - 22), "T%d" % int(tile.get("tier", 1)), rect.size.x - 6, 12, Color.html("#ffe06d"))
	if _regional_tile_for_key(current_key).is_empty():
		return
	_draw_regional_atlas_tile(14, _regional_tile_rect(_regional_tile_for_key(current_key)).grow(-5), Color(1, 1, 1, 1))

func _draw_regional_atlas_tile(index: int, rect: Rect2, modulate_color: Color = Color.WHITE) -> void:
	if regional_tileset_texture != null:
		var src := Rect2(Vector2(float(index % 8) * REGIONAL_TILE_SIZE, float(int(index / 8)) * REGIONAL_TILE_SIZE), Vector2(REGIONAL_TILE_SIZE, REGIONAL_TILE_SIZE))
		draw_texture_rect_region(regional_tileset_texture, rect, src, modulate_color)
		return
	draw_rect(rect, _fallback_regional_tile_color(index) * modulate_color)

func _terrain_tile_index(terrain: String) -> int:
	var idx := REGIONAL_TILE_TERRAINS.find(terrain)
	return max(0, idx)

func _fallback_regional_tile_color(index: int) -> Color:
	var colors := [
		Color.html("#a9d77a"),
		Color.html("#5ea86c"),
		Color.html("#b5b86f"),
		Color.html("#8d8b83"),
		Color.html("#76b5d6"),
		Color.html("#d4c782"),
		Color.html("#d6aa64"),
		Color.html("#b98f6a"),
		Color.html("#d8c38b"),
		Color.html("#f0e18a"),
		Color.html("#dde6f0"),
		Color.html("#d7b56d"),
		Color.html("#ffe06d"),
		Color.html("#78d891"),
		Color.html("#ffefb0"),
		Color.html("#5a6064")
	]
	return colors[index % colors.size()]

func _run_completion_index(id: String) -> int:
	var completed: Array = campaign.get("run_completed", [])
	var idx := completed.find(id)
	return idx + 1 if idx >= 0 else 0

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
	return _resource_color(cargo)

func _resource_color(cargo: String) -> Color:
	if cargo == "coal":
		return Color.html("#d8d2bd")
	if cargo == "freight":
		return Color.html("#f2c36b")
	if cargo == "steel":
		return Color.html("#bfe3f6")
	return Color.html("#eef3e8")

func _resource_name(cargo: String) -> String:
	if cargo == "":
		return ""
	return cargo.to_upper()

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
	_draw_terrain()
	for x in range(grid.x + 1):
		var gx := grid_origin.x + float(x) * cell_size
		draw_line(Vector2(gx, grid_origin.y), Vector2(gx, grid_origin.y + float(grid.y) * cell_size), Color(0.28, 0.45, 0.32, 0.16), 1.0)
	for y in range(grid.y + 1):
		var gy := grid_origin.y + float(y) * cell_size
		draw_line(Vector2(grid_origin.x, gy), Vector2(grid_origin.x + float(grid.x) * cell_size, gy), Color(0.28, 0.45, 0.32, 0.16), 1.0)
	_draw_track_drag_preview()
	_draw_tracks()
	_draw_blocks()
	_draw_stations()
	_draw_signals()
	_draw_train_route_hints()
	_draw_trains()

func _draw_terrain() -> void:
	var scenario: Dictionary = local.get("scenario", {})
	for item in scenario.get("terrain", []):
		var p: Vector2i = item.get("pos", Vector2i(-999, -999))
		if not _is_in_grid(p):
			continue
		var terrain_type := String(item.get("type", ""))
		var center := _grid_to_screen(p)
		var rect := Rect2(center - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size)).grow(-2.0)
		var fill := Color(0.44, 0.53, 0.48, 0.56)
		if terrain_type == "mountain":
			fill = Color(0.52, 0.55, 0.58, 0.72)
		elif terrain_type == "rock":
			fill = Color(0.43, 0.38, 0.34, 0.68)
		elif terrain_type == "river":
			fill = Color(0.30, 0.61, 0.86, 0.62)
		elif terrain_type == "ocean":
			fill = Color(0.14, 0.42, 0.68, 0.72)
		draw_rect(rect, fill)
		if terrain_type == "mountain":
			draw_polygon([
				center + Vector2(-cell_size * 0.36, cell_size * 0.24),
				center + Vector2(0.0, -cell_size * 0.32),
				center + Vector2(cell_size * 0.36, cell_size * 0.24)
			], [Color(0.88, 0.9, 0.86, 0.84)])
		elif terrain_type == "river":
			draw_line(center + Vector2(-cell_size * 0.36, 0.0), center + Vector2(cell_size * 0.36, 0.0), Color(0.9, 0.98, 1.0, 0.82), max(3.0, cell_size * 0.06), true)
		elif terrain_type == "rock":
			draw_circle(center, cell_size * 0.19, Color(0.21, 0.18, 0.16, 0.72))
		elif terrain_type == "ocean":
			draw_line(center + Vector2(-cell_size * 0.3, -cell_size * 0.08), center + Vector2(cell_size * 0.3, -cell_size * 0.08), Color(0.86, 0.95, 1.0, 0.68), max(2.0, cell_size * 0.04), true)

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
		_draw_station_resource_badges(st, c)
		if selected_tool == "train" and st.get("role", "") == "source":
			_draw_map_label(c + Vector2(-cell_size * 0.9, -cell_size * 1.04), "BUY HERE", cell_size * 1.8, int(max(13.0, cell_size * 0.22)), Color.html("#ffe06d"))
		if int(st.get("platforms", 1)) > 1:
			_draw_map_label(c + Vector2(-cell_size * 0.45, -cell_size * 0.94), "P%d" % int(st["platforms"]), cell_size * 0.9, label_size)
		if editing_line_stops and selected_line_id != "" and lines.has(selected_line_id):
			_draw_station_add_handle(st["pos"])

func _draw_station_resource_badges(st: Dictionary, center: Vector2) -> void:
	var out_text := _station_output_badge_text(st)
	var need_text := _station_need_badge_text(st)
	if out_text != "":
		var cargo := String(st.get("produces", ""))
		_draw_station_resource_badge(center + Vector2(-cell_size * 1.42, -cell_size * 0.58), out_text, _resource_color(cargo), false)
	if need_text != "":
		var accepts: Array = st.get("accepts", [])
		var cargo := String(accepts[0]) if not accepts.is_empty() else ""
		_draw_station_resource_badge(center + Vector2(cell_size * 0.52, -cell_size * 0.58), need_text, _resource_color(cargo), true)

func _draw_station_resource_badge(pos: Vector2, text: String, fill: Color, outlined: bool) -> void:
	var badge_size := Vector2(max(88.0, cell_size * 1.72), max(22.0, cell_size * 0.36))
	var rect := Rect2(pos, badge_size)
	draw_rect(rect.grow(2.0), Color(0.04, 0.08, 0.1, 0.78))
	draw_rect(rect, fill)
	if outlined:
		draw_rect(rect.grow(-3.0), Color(1, 1, 1, 0.0), false, 2.0)
	draw_rect(rect, Color.html("#172028"), false, 1.5)
	draw_string(font, rect.position + Vector2(0, badge_size.y - 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, int(max(10.0, cell_size * 0.18)), Color.html("#172028"))

func _station_output_badge_text(st: Dictionary) -> String:
	var produced := String(st.get("produces", ""))
	if produced == "":
		return ""
	var amount := _station_available_amount(st, produced)
	if amount >= 0:
		return "OUT %s %d" % [_resource_name(produced), amount]
	return "OUT %s" % _resource_name(produced)

func _station_need_badge_text(st: Dictionary) -> String:
	var accepts: Array = st.get("accepts", [])
	if accepts.is_empty():
		return ""
	var names: Array[String] = []
	for cargo in accepts:
		names.append(_resource_name(String(cargo)))
	return "NEEDS %s" % "/".join(names)

func _station_available_amount(st: Dictionary, cargo: String) -> int:
	if st.get("role", "") == "source" and st.has("stored"):
		return int(st.get("stored", 0))
	if String(st.get("id", "")) == "steelworks" and cargo == "steel":
		return int(local.get("steel_buffer", 0))
	return -1

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
