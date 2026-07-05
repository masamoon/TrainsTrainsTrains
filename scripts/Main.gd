extends Control

enum Screen { REGIONAL, LOCAL, RESULTS }

const SAVE_PATH := "user://trains_campaign.json"
const CELL := 48.0
const GRID_ORIGIN := Vector2(64, 132)
const RUN_LENGTH := 30
const RUN_POOL_SIZE := 30
const RUN_CHOICES := 3
const RUN_SCENARIO_PREFIX := "run_"
const DAILY_PUZZLE_SEED := 20260703
const REGIONAL_GRID := Vector2i(9, 7)
const REGIONAL_START_KEY := "0,3"
const REGIONAL_TILE_SIZE := 64.0
const REGIONAL_TILE_MIN := 48.0
const REGIONAL_TILE_MAX := 256.0
const LOCAL_CELL_MIN := 46.0
const LOCAL_CELL_MAX := 256.0
const OPERATING_COST_PER_TILE := 0.45
const EMPTY_OPERATING_SURCHARGE_PER_TILE := 0.25
const CONTRACT_DETOUR_DWELL := 1.1
const DISPATCH_OVERLOAD_PER_EXTRA_TRAIN := 0.07
const DISPATCH_OVERLOAD_MIN_SPEED := 0.65
const TEST_BATTERY_STEP := 0.1
const TEST_BATTERY_START_STEPS := 8
const TEST_BATTERY_MAX_STEPS := 520
const TEST_BATTERY_RAMP_INTERVAL := 0.35
const PASSENGER_CARGO := "passengers"
const FREIGHT_CARGOS := ["coal", "freight", "timber", "iron", "steel"]
const PASSENGER_SERVICE_CLASSES := ["passenger_local", "passenger_express"]
const FREIGHT_SERVICE_CLASSES := ["light_freight", "heavy_freight"]
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
	"mastery_records": {},
	"run_won": false,
	"regional_map_seed": 32027,
	"regional_map": [],
	"regional_position": REGIONAL_START_KEY,
	"regional_completed_tiles": [],
	"regional_tile_records": {},
	"regional_visible_tiles": [],
	"active_regional_tile": "",
	"daily_puzzle_seed": DAILY_PUZZLE_SEED,
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
		"burstiness": 0.0,
		"inspection_debt": 0
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
var line_picker_scroll: ScrollContainer
var line_picker_row: HBoxContainer
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
var last_layout_size := Vector2.ZERO

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
	resized.connect(_on_resized)
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
	style.content_margin_left = _scaled(14.0)
	style.content_margin_top = _scaled(8.0)
	style.content_margin_right = _scaled(14.0)
	style.content_margin_bottom = _scaled(8.0)
	return style

func _style_panel(panel: PanelContainer) -> void:
	var style := _flat_style(Color(1.0, 0.97, 0.82, 0.99), Color.html("#172028"), 3, 8)
	style.content_margin_left = _scaled(18.0)
	style.content_margin_top = _scaled(14.0)
	style.content_margin_right = _scaled(18.0)
	style.content_margin_bottom = _scaled(14.0)
	panel.add_theme_stylebox_override("panel", style)

func _ui_scale() -> float:
	var viewport := Vector2(max(size.x, 640.0), max(size.y, 480.0))
	return clamp(min(viewport.x / 1280.0, viewport.y / 720.0), 1.0, 2.35)

func _scaled(value: float) -> float:
	return round(value * _ui_scale())

func _scaled_font(value: int) -> int:
	return int(round(float(value) * _ui_scale()))

func _local_side_panel_width() -> float:
	var viewport_width: float = max(size.x, 640.0)
	if viewport_width >= 1800.0:
		return _scaled(560.0)
	if viewport_width >= 1500.0:
		return _scaled(520.0)
	return min(_scaled(520.0), viewport_width - _scaled(32.0))

func _local_tray_height() -> float:
	var viewport_height: float = max(size.y, 480.0)
	if viewport_height <= 640.0:
		return _scaled(104.0)
	if viewport_height <= 900.0:
		return _scaled(118.0)
	return _scaled(132.0)

func _local_side_panel_inner_width() -> float:
	return _local_side_panel_width() - 12.0 - 36.0

func _regional_side_panel_width() -> float:
	var viewport_width: float = max(size.x, 640.0)
	if viewport_width >= 1800.0:
		return clamp(viewport_width * 0.24, _scaled(360.0), _scaled(440.0))
	if viewport_width >= 1400.0:
		return clamp(viewport_width * 0.25, _scaled(340.0), _scaled(410.0))
	return min(_scaled(340.0), viewport_width * 0.29)

func _regional_tutorial_rail_width() -> float:
	if size.x < 900.0:
		return 0.0
	return _scaled(128.0)

func _regional_map_top_margin() -> float:
	var viewport_height: float = max(size.y, 480.0)
	if size.x >= 1600.0 and viewport_height >= 900.0:
		return clamp(viewport_height * 0.14, _scaled(116.0), _scaled(152.0))
	return clamp(viewport_height * 0.14, _scaled(116.0), _scaled(146.0))

func _local_hud_width() -> float:
	var viewport_width: float = max(size.x, 640.0)
	if viewport_width >= 1800.0:
		return _scaled(720.0)
	if viewport_width >= 1200.0:
		return _scaled(560.0)
	return _scaled(360.0)

func _on_resized() -> void:
	if last_layout_size.distance_to(size) < 1.0:
		return
	last_layout_size = size
	if screen == Screen.LOCAL:
		_update_board_layout()
	rebuild_ui()
	queue_redraw()

func _apply_local_side_panel_layout() -> void:
	if screen != Screen.LOCAL or side_panel == null:
		return
	side_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	side_panel.offset_left = _scaled(14.0)
	side_panel.offset_top = -_local_tray_height()
	side_panel.offset_right = -_scaled(14.0)
	side_panel.offset_bottom = -_scaled(8.0)
	if tool_bar != null:
		tool_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tool_bar.offset_left = _scaled(18.0)
		tool_bar.offset_top = -(_local_tray_height() + _scaled(72.0))
		tool_bar.offset_right = -_scaled(18.0)
		tool_bar.offset_bottom = -(_local_tray_height() + _scaled(18.0))
	if service_edit_bar != null:
		service_edit_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		service_edit_bar.offset_left = _scaled(18.0)
		service_edit_bar.offset_top = -_local_tray_height() + _scaled(8.0)
		service_edit_bar.offset_right = -_scaled(18.0)
		service_edit_bar.offset_bottom = -_scaled(12.0)

func _style_button(button: Button, selected: bool = false) -> void:
	var base := Color.html("#20414c") if not selected else Color.html("#ffd96b")
	var hover := Color.html("#2e5964") if not selected else Color.html("#ffe58f")
	var pressed := Color.html("#ffeec0")
	var border := Color.html("#10242d")
	button.add_theme_stylebox_override("normal", _flat_style(base, border, 2, 6))
	button.add_theme_stylebox_override("hover", _flat_style(hover, border, 2, 6))
	button.add_theme_stylebox_override("pressed", _flat_style(pressed, border, 2, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", _scaled_font(17))
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
	if bool(local.get("test_battery_running", false)):
		_update_test_battery(delta)
		queue_redraw()
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
	for i in range(scenarios.size()):
		scenarios[i] = _normalize_scenario_contracts(scenarios[i])

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
	terrain = _terrain_without_blocking_path_tiles(terrain, ghost, _station_positions(stations))
	var clause := _contract_clause_for(index, pattern, difficulty)
	var template := _puzzle_template_for(pattern, kind)
	var resource_profile := _resource_puzzle_profile_for(index, difficulty, pattern, fleet_goal, grid, stations, terrain, route, ghost)
	var scenario := {
		"id": "%s%02d" % [RUN_SCENARIO_PREFIX, index + 1],
		"name": name,
		"purpose": "Rail Sudoku contract %d of %d: %s" % [index + 1, RUN_POOL_SIZE, _difficulty_label(difficulty)],
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
		"template_id": String(template.get("id", "branch_delivery")),
		"template_name": String(template.get("name", "Branch Delivery")),
		"contract_clause": clause,
		"resource_mode": "limited",
		"resource_budget": resource_profile.get("budget", {}),
		"star_thresholds": resource_profile.get("star_thresholds", {}),
		"solution_variants": resource_profile.get("solution_variants", []),
		"train_car_count": int(resource_profile.get("train_car_count", 1)),
		"multi_solution_note": String(resource_profile.get("multi_solution_note", "")),
		"bonus_money": 110 + difficulty * 45 + pattern * 10,
		"reward_money": 220 + difficulty * 120 + pattern * 20,
		"reward_load": 5 + difficulty * 3 + pattern,
		"reward_capacity": 2 + difficulty * 2 + int(pattern == 4) * 6,
		"wait_target": wait_target
	}
	if difficulty >= 2:
		_add_mixed_crossing_to_scenario(scenario, index, difficulty, pattern)
	_normalize_scenario_contracts(scenario)
	_apply_contract_clause_modifiers(scenario)
	scenario["contract_puzzle"] = _contract_puzzle_schema_for(scenario, template)
	scenario["requirements"] = _requirements_for_contract(kind, difficulty, pattern, fleet_goal, clause, scenario["contract_puzzle"])
	return scenario

func _normalize_scenario_contracts(sc: Dictionary) -> Dictionary:
	_normalize_station_metadata(sc)
	if bool(sc.get("order_mode", false)):
		var seeded_primary := _primary_order_for_scenario(sc)
		if not seeded_primary.is_empty() and not _orders_include_origin_destination(sc.get("orders", []), String(seeded_primary.get("origin", "")), String(seeded_primary.get("destination", ""))):
			var seeded_orders: Array = sc.get("orders", [])
			seeded_orders.push_front(seeded_primary)
			sc["orders"] = seeded_orders
	if not sc.has("orders") or not (sc.get("orders", []) is Array) or (sc.get("orders", []) as Array).is_empty():
		var primary_order := _primary_order_for_scenario(sc)
		sc["orders"] = [primary_order] if not primary_order.is_empty() else []
	else:
		var normalized_orders: Array = []
		var ordinal := 1
		for raw_order in sc.get("orders", []):
			var order: Dictionary = (raw_order as Dictionary).duplicate(true)
			order["id"] = String(order.get("id", "order_%02d" % ordinal))
			order["cargo"] = String(order.get("cargo", sc.get("cargo", "freight")))
			order["origin"] = String(order.get("origin", ""))
			order["destination"] = String(order.get("destination", ""))
			if not order.has("via"):
				order["via"] = []
			order["amount"] = max(1, int(order.get("amount", sc.get("target", 1))))
			order["due_time"] = float(order.get("due_time", _reward_time_par(sc)))
			order["service_class"] = String(order.get("service_class", _service_class_for_cargo(String(order.get("cargo", "")))))
			order["priority"] = int(order.get("priority", 1))
			if String(order.get("origin", "")) != "" and String(order.get("destination", "")) != "":
				normalized_orders.append(order)
			ordinal += 1
		sc["orders"] = normalized_orders
	if bool(sc.get("order_mode", false)):
		sc["target"] = _scenario_order_target(sc)
	sc["service_routes"] = _normalized_service_routes(sc)
	sc["service_mix"] = _service_mix_from_orders(sc.get("orders", []))
	if not sc.has("resource_budget"):
		var grid: Vector2i = sc.get("grid", Vector2i(18, 11))
		var ghost: Array = sc.get("ghost", [])
		sc["resource_mode"] = "limited"
		sc["resource_budget"] = {
			"track": max(ghost.size() + 24, int(grid.x * grid.y * 0.55)),
			"signals": 64,
			"block": 48,
			"chain": 24,
			"trains": max(int(sc.get("fleet_goal", 1)) + 6, 12)
		}
	return sc

func _orders_include_origin_destination(orders: Array, origin: String, destination: String) -> bool:
	for order in orders:
		var data: Dictionary = order
		if String(data.get("origin", "")) == origin and String(data.get("destination", "")) == destination:
			return true
	return false

func _normalize_station_metadata(sc: Dictionary) -> void:
	var stations: Array = sc.get("stations", [])
	for st in stations:
		var station: Dictionary = st
		if not station.has("station_type"):
			var role := String(station.get("role", ""))
			if String(station.get("produces", "")) == PASSENGER_CARGO or (station.get("accepts", []) as Array).has(PASSENGER_CARGO):
				station["station_type"] = "passenger"
			else:
				station["station_type"] = role if role != "" else "freight"
		if not station.has("service_classes"):
			var classes: Array[String] = []
			var cargoes: Array[String] = []
			var produced := String(station.get("produces", ""))
			if produced != "":
				cargoes.append(produced)
			for cargo in station.get("accepts", []):
				var cargo_name := String(cargo)
				if cargo_name != "" and not cargoes.has(cargo_name):
					cargoes.append(cargo_name)
			for cargo in cargoes:
				var service_class := _service_class_for_cargo(String(cargo))
				if service_class != "" and not classes.has(service_class):
					classes.append(service_class)
			station["service_classes"] = classes

func _normalized_service_routes(sc: Dictionary) -> Dictionary:
	var service_routes: Dictionary = {}
	if typeof(sc.get("service_routes", {})) == TYPE_DICTIONARY:
		for raw_source in (sc.get("service_routes", {}) as Dictionary).keys():
			service_routes[String(raw_source)] = (sc["service_routes"][raw_source] as Array).duplicate()
	if sc.has("route") and (sc["route"] as Array).size() >= 2:
		service_routes[String(sc["route"][0])] = (sc["route"] as Array).duplicate()
	if sc.has("alt_route") and (sc["alt_route"] as Array).size() >= 2:
		service_routes[String(sc["alt_route"][0])] = (sc["alt_route"] as Array).duplicate()
	for order in sc.get("orders", []):
		var route: Array = [String(order.get("origin", ""))]
		for via_id in order.get("via", []):
			route.append(String(via_id))
		route.append(String(order.get("destination", "")))
		if route.size() >= 2 and String(route[0]) != "" and not service_routes.has(String(route[0])):
			service_routes[String(route[0])] = route
	return service_routes

func _primary_order_for_scenario(sc: Dictionary) -> Dictionary:
	var route: Array = sc.get("route", [])
	if route.size() < 2:
		return {}
	var origin := String(route[0])
	var destination := String(route[route.size() - 1])
	for station_id in route:
		var id := String(station_id)
		for station in sc.get("stations", []):
			var st: Dictionary = station
			if String(st.get("id", "")) == id and String(st.get("role", "")) == "sink":
				destination = id
				break
	var via: Array[String] = []
	for station_id in route:
		var id := String(station_id)
		if id == destination:
			break
		if id != origin and id != destination and not via.has(id):
			via.append(id)
	return {
		"id": "primary",
		"cargo": _primary_cargo_for_scenario(sc),
		"origin": origin,
		"destination": destination,
		"via": via,
		"amount": max(1, int(sc.get("target", 1))),
		"due_time": _reward_time_par(sc),
		"service_class": _service_class_for_cargo(_primary_cargo_for_scenario(sc)),
		"priority": 1
	}

func _primary_cargo_for_scenario(sc: Dictionary) -> String:
	var cargo := String(sc.get("cargo", ""))
	if cargo == "mixed freight":
		return "freight"
	if cargo != "":
		return cargo
	var kind := String(sc.get("kind", ""))
	if kind == "steel":
		return "steel"
	if kind == "coal":
		return "coal"
	return "freight"

func _scenario_order_target(sc: Dictionary) -> int:
	var total := 0
	for order in sc.get("orders", []):
		total += int((order as Dictionary).get("amount", 0))
	return max(1, total)

func _service_mix_from_orders(orders: Array) -> Array[String]:
	var mix: Array[String] = []
	for order in orders:
		var cargo := String((order as Dictionary).get("cargo", ""))
		if cargo != "" and not mix.has(cargo):
			mix.append(cargo)
	return mix

func _service_class_for_cargo(cargo: String) -> String:
	if cargo == PASSENGER_CARGO:
		return "passenger_local"
	if cargo in ["iron", "steel"]:
		return "heavy_freight"
	return "light_freight"

func _service_class_domain(service_class: String) -> String:
	if PASSENGER_SERVICE_CLASSES.has(service_class):
		return "passenger"
	return "freight"

func _cargo_domain(cargo: String) -> String:
	return "passenger" if cargo == PASSENGER_CARGO else "freight"

func _service_class_compatible_with_cargo(service_class: String, cargo: String) -> bool:
	return _service_class_domain(service_class) == _cargo_domain(cargo)

func _add_mixed_crossing_to_scenario(sc: Dictionary, index: int, difficulty: int, pattern: int) -> void:
	var grid: Vector2i = sc.get("grid", Vector2i(18, 11))
	var stations: Array = sc.get("stations", [])
	var used := {}
	for station in stations:
		var st: Dictionary = station
		used[st.get("pos", Vector2i(-999, -999))] = true
	var center_x: int = int(clamp(floor(float(grid.x) * 0.5) + float((pattern % 3) - 1), 2.0, float(grid.x - 3)))
	var pass_origin := _free_station_pos(grid, Vector2i(center_x, 1), used)
	var pass_dest := _free_station_pos(grid, Vector2i(center_x, grid.y - 2), used)
	var passenger_a := {
		"id": "passenger_north",
		"name": "North Halt",
		"pos": pass_origin,
		"role": "source",
		"station_type": "passenger",
		"produces": PASSENGER_CARGO,
		"accepts": [PASSENGER_CARGO],
		"platforms": 1,
		"service_classes": ["passenger_local", "passenger_express"]
	}
	var passenger_b := {
		"id": "passenger_south",
		"name": "South Halt",
		"pos": pass_dest,
		"role": "sink",
		"station_type": "passenger",
		"produces": "",
		"accepts": [PASSENGER_CARGO],
		"platforms": 1,
		"service_classes": ["passenger_local", "passenger_express"]
	}
	stations.append(passenger_a)
	stations.append(passenger_b)
	used[pass_origin] = true
	used[pass_dest] = true
	var orders: Array = sc.get("orders", [])
	orders.append({
		"id": "passenger_crossing",
		"cargo": PASSENGER_CARGO,
		"origin": "passenger_north",
		"destination": "passenger_south",
		"via": [],
		"amount": 18 + difficulty * 8 + (index % 4) * 2,
		"due_time": max(60.0, float(sc.get("wait_target", 45.0)) * 2.8),
		"service_class": "passenger_local",
		"priority": 2
	})
	if difficulty >= 3:
		var industry_cargo := "iron" if pattern % 2 == 0 else "timber"
		var industry_source := _free_station_pos(grid, Vector2i(grid.x - 3, 2 + (pattern % max(1, grid.y - 4))), used)
		var industry_sink := _free_station_pos(grid, Vector2i(2, grid.y - 3 - (pattern % 2)), used)
		stations.append({
			"id": "%s_source" % industry_cargo,
			"name": "%s Loader" % industry_cargo.capitalize(),
			"pos": industry_source,
			"role": "source",
			"station_type": "freight",
			"produces": industry_cargo,
			"accepts": [],
			"platforms": 1,
			"service_classes": [_service_class_for_cargo(industry_cargo)]
		})
		stations.append({
			"id": "%s_receiver" % industry_cargo,
			"name": "%s Mill" % industry_cargo.capitalize(),
			"pos": industry_sink,
			"role": "sink",
			"station_type": "freight",
			"produces": "",
			"accepts": [industry_cargo],
			"platforms": 1,
			"service_classes": [_service_class_for_cargo(industry_cargo)]
		})
		orders.append({
			"id": "%s_crossing" % industry_cargo,
			"cargo": industry_cargo,
			"origin": "%s_source" % industry_cargo,
			"destination": "%s_receiver" % industry_cargo,
			"via": [],
			"amount": 28 + difficulty * 12,
			"due_time": max(90.0, float(sc.get("wait_target", 45.0)) * 3.4),
			"service_class": _service_class_for_cargo(industry_cargo),
			"priority": 1
		})
	sc["stations"] = stations
	sc["orders"] = orders
	sc["order_mode"] = true
	sc["mixed_template_id"] = "processor_with_commuters" if String(sc.get("kind", "")) == "steel" else ("dual_industry_split" if difficulty >= 3 else "passenger_freight_crossing")
	sc["service_mix"] = _service_mix_from_orders(orders)
	var service_routes: Dictionary = sc.get("service_routes", {})
	service_routes["passenger_north"] = ["passenger_north", "passenger_south", "passenger_north"]
	if difficulty >= 3:
		var extra_cargo := "iron" if pattern % 2 == 0 else "timber"
		service_routes["%s_source" % extra_cargo] = ["%s_source" % extra_cargo, "%s_receiver" % extra_cargo, "%s_source" % extra_cargo]
	sc["service_routes"] = service_routes
	var ghost: Array = sc.get("ghost", [])
	_append_path_to_ghost(ghost, _simple_path_points(pass_origin, pass_dest))
	if difficulty >= 3:
		var extra_order: Dictionary = orders[orders.size() - 1]
		var from_pos: Vector2i = _station_pos_in_list(stations, String(extra_order.get("origin", "")))
		var to_pos: Vector2i = _station_pos_in_list(stations, String(extra_order.get("destination", "")))
		_append_path_to_ghost(ghost, _simple_path_points(from_pos, to_pos))
	sc["ghost"] = ghost
	sc["terrain"] = _terrain_without_blocking_path_tiles(sc.get("terrain", []), ghost, _station_positions(stations))
	if typeof(sc.get("resource_budget", {})) == TYPE_DICTIONARY:
		var budget: Dictionary = sc.get("resource_budget", {})
		budget["track"] = max(int(budget.get("track", 0)), ghost.size() + 14 + difficulty * 6, int(grid.x * grid.y * 0.72))
		budget["signals"] = max(int(budget.get("signals", 0)), 8 + difficulty * 4)
		budget["block"] = max(int(budget.get("block", 0)), 6 + difficulty * 3)
		budget["chain"] = max(int(budget.get("chain", 0)), 3 + difficulty * 2)
		budget["trains"] = max(int(budget.get("trains", 0)), int(sc.get("fleet_goal", 1)) + 2)
		sc["resource_budget"] = budget

func _free_station_pos(grid: Vector2i, preferred: Vector2i, used: Dictionary) -> Vector2i:
	var candidates: Array[Vector2i] = [preferred]
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				candidates.append(preferred + Vector2i(dx, dy))
	for raw in candidates:
		var p: Vector2i = raw
		p.x = int(clamp(p.x, 1, max(1, grid.x - 2)))
		p.y = int(clamp(p.y, 1, max(1, grid.y - 2)))
		if not used.has(p):
			used[p] = true
			return p
	return preferred

func _append_path_to_ghost(ghost: Array, path: Array) -> void:
	for raw_cell in path:
		var cell: Vector2i = raw_cell
		if not ghost.has(cell):
			ghost.append(cell)

func _station_pos_in_list(stations: Array, station_id: String) -> Vector2i:
	for station in stations:
		var st: Dictionary = station
		if String(st.get("id", "")) == station_id:
			return st.get("pos", Vector2i.ZERO)
	return Vector2i.ZERO

func _resource_puzzle_profile_for(index: int, difficulty: int, pattern: int, fleet_goal: int, grid: Vector2i, stations: Array, terrain: Array, route: Array, ghost: Array[Vector2i]) -> Dictionary:
	var variants: Array = []
	_add_solution_variant(variants, "spine", "Follow the contract spine with compact passing pockets.", ghost)
	var alt_a: Array[Vector2i] = _detoured_solution_path(ghost, grid, terrain, stations, 2 + difficulty + (pattern % 2))
	_add_solution_variant(variants, "upper_bypass", "Spend extra rail on a higher bypass to avoid a shared throat.", alt_a)
	var alt_b: Array[Vector2i] = _detoured_solution_path(ghost, grid, terrain, stations, -(2 + difficulty + ((pattern + 1) % 2)))
	_add_solution_variant(variants, "lower_bypass", "Spend extra rail on a lower return lane and simplify signal pressure.", alt_b)
	var longest_solution: int = max(1, _longest_solution_track_count(variants))
	var perimeter_budget: int = (grid.x + grid.y) * 2
	var track_budget: int = max(longest_solution + 10 + difficulty * 6, perimeter_budget + 4 + difficulty * 4)
	var block_budget: int = 6 + difficulty * 2 + int(pattern in [2, 4]) * 2
	var chain_budget: int = 2 + difficulty + int(pattern in [1, 5]) * 2
	var train_budget: int = fleet_goal + 1 + int(difficulty >= 3)
	var car_count: int = 1
	if difficulty >= 2 and pattern in [1, 4, 5]:
		car_count = 2
	if difficulty >= 3 and pattern in [1, 3, 5]:
		car_count = 3
	var total_signal_budget: int = block_budget + chain_budget
	var two_star_spare: int = max(3, int(ceil(float(track_budget) * 0.08)) + int(total_signal_budget > 8))
	var three_star_spare: int = max(7, int(ceil(float(track_budget) * 0.16)) + 2)
	return {
		"budget": {
			"track": track_budget,
			"block": block_budget,
			"chain": chain_budget,
			"signals": total_signal_budget,
			"trains": train_budget
		},
		"star_thresholds": {
			"two_star_spare": two_star_spare,
			"three_star_spare": three_star_spare
		},
		"solution_variants": variants.slice(0, min(2, variants.size())),
		"train_car_count": car_count,
		"multi_solution_note": "At least two authored route families fit the budget; unused track and signal pieces decide the star multiplier."
	}

func _add_solution_variant(variants: Array, id: String, note: String, path: Array) -> void:
	if path.size() < 2:
		return
	var key := _solution_path_key(path)
	for variant in variants:
		if String(variant.get("key", "")) == key:
			return
	variants.append({
		"id": id,
		"note": note,
		"track_pieces": max(0, path.size() - 1),
		"path": path.duplicate(),
		"key": key
	})

func _solution_path_key(path: Array) -> String:
	var parts: Array[String] = []
	for p in path:
		var cell: Vector2i = p
		parts.append(_track_key(cell))
	return "|".join(parts)

func _longest_solution_track_count(variants: Array) -> int:
	var longest := 0
	for variant in variants:
		longest = max(longest, int(variant.get("track_pieces", 0)))
	return longest

func _detoured_solution_path(base_path: Array[Vector2i], grid: Vector2i, terrain: Array, stations: Array, offset: int) -> Array[Vector2i]:
	if base_path.size() < 4:
		return base_path.duplicate()
	var pivot_index: int = clamp(int(floor(float(base_path.size()) * 0.5)), 1, base_path.size() - 2)
	var pivot: Vector2i = base_path[pivot_index]
	var reconnect: Vector2i = base_path[pivot_index + 1]
	var allowed := _station_positions(stations)
	var detour := _detour_cell_near(pivot, grid, terrain, allowed, offset)
	if detour == pivot:
		return base_path.duplicate()
	var first_leg := _terrain_aware_path(pivot, detour, grid, terrain, allowed, abs(offset) + 3)
	if first_leg.is_empty():
		first_leg = _simple_path_points(pivot, detour)
	var second_leg := _terrain_aware_path(detour, reconnect, grid, terrain, allowed, abs(offset) + 5)
	if second_leg.is_empty():
		second_leg = _simple_path_points(detour, reconnect)
	var result: Array[Vector2i] = []
	for i in range(0, pivot_index + 1):
		_append_unique_path_cell(result, base_path[i])
	for p in first_leg:
		_append_unique_path_cell(result, p)
	for p in second_leg:
		_append_unique_path_cell(result, p)
	for i in range(pivot_index + 1, base_path.size()):
		_append_unique_path_cell(result, base_path[i])
	return result

func _detour_cell_near(pivot: Vector2i, grid: Vector2i, terrain: Array, allowed: Array[Vector2i], offset: int) -> Vector2i:
	var sign: int = 1 if offset >= 0 else -1
	var distance: int = max(2, abs(offset))
	for extra in range(0, grid.y):
		for x_shift in [0, 1, -1, 2, -2, 3, -3]:
			var candidate: Vector2i = Vector2i(
				clamp(pivot.x + x_shift, 1, max(1, grid.x - 2)),
				clamp(pivot.y + sign * (distance + extra), 1, max(1, grid.y - 2))
			)
			if candidate != pivot and not _generation_terrain_blocks(candidate, terrain, allowed):
				return candidate
	return pivot

func _append_unique_path_cell(path: Array[Vector2i], cell: Vector2i) -> void:
	if path.is_empty() or path[path.size() - 1] != cell:
		path.append(cell)

func _puzzle_template_defs() -> Dictionary:
	return {
		"branch_delivery": {
			"id": "branch_delivery",
			"name": "Branch Delivery",
			"summary": "One source feeds multiple required stops; a direct corridor is incomplete.",
			"route_clause": "Visit the off-axis branch before the final receiver.",
			"service_clause": "Use a service route with the required branch order."
		},
		"processor_chain": {
			"id": "processor_chain",
			"name": "Processor Chain",
			"summary": "Raw input must be transformed before export counts.",
			"route_clause": "Coal must reach the processor before steel can be exported.",
			"service_clause": "Keep input and export flow connected without skipping the processor."
		},
		"passing_siding": {
			"id": "passing_siding",
			"name": "Passing Siding",
			"summary": "A constrained corridor rewards signals, passing space, and steady dispatch.",
			"route_clause": "Terrain narrows the corridor; avoid deadlocking the shared throat.",
			"service_clause": "Run the contract route with enough passing capacity for the target fleet."
		},
		"junction_sort": {
			"id": "junction_sort",
			"name": "Junction Sort",
			"summary": "A shared junction must sort traffic through required intermediate stops.",
			"route_clause": "Use the listed yard stops; outside-contract cargo does not count.",
			"service_clause": "Keep the junction route disciplined instead of a circular catch-all."
		},
		"efficiency_run": {
			"id": "efficiency_run",
			"name": "Efficiency Run",
			"summary": "The puzzle is simple, but Gold and Perfect require lean material and timing.",
			"route_clause": "Complete the required route with no extra scheduled stops.",
			"service_clause": "Hit the target with a right-sized fleet and compact infrastructure."
		}
	}

func _puzzle_template_for(pattern: int, kind: String) -> Dictionary:
	var defs := _puzzle_template_defs()
	if kind == "steel":
		return (defs["processor_chain"] as Dictionary).duplicate(true)
	var order := ["branch_delivery", "junction_sort", "passing_siding", "efficiency_run", "branch_delivery", "processor_chain"]
	return (defs[String(order[pattern % order.size()])] as Dictionary).duplicate(true)

func _contract_puzzle_schema_for(sc: Dictionary, template: Dictionary) -> Dictionary:
	var route: Array = sc.get("route", [])
	var clause: Dictionary = sc.get("contract_clause", {})
	var terrain_tags: Array[String] = []
	for item in sc.get("terrain", []):
		var tag := String(item.get("type", ""))
		if tag != "" and not terrain_tags.has(tag):
			terrain_tags.append(tag)
	var required_deliveries: Array[String] = []
	if not (sc.get("orders", []) as Array).is_empty():
		for order in sc.get("orders", []):
			var order_data: Dictionary = order
			required_deliveries.append("%d %s %s -> %s" % [
				int(order_data.get("amount", 0)),
				_resource_name(String(order_data.get("cargo", "cargo"))),
				_station_name_for_scenario(sc, String(order_data.get("origin", ""))),
				_station_name_for_scenario(sc, String(order_data.get("destination", "")))
			])
	else:
		required_deliveries.append("%d %s contract output" % [int(sc.get("target", 0)), String(sc.get("cargo", "cargo")).capitalize()])
	if String(sc.get("kind", "")) == "steel":
		required_deliveries.append("Coal input must feed processor before Steel export.")
	var route_clauses: Array[String] = []
	if not route.is_empty():
		route_clauses.append(_scenario_route_preview(sc))
	route_clauses.append(String(template.get("route_clause", "Follow the required route order.")))
	route_clauses.append("A simple supplier-to-receiver double track does not satisfy this puzzle.")
	var service_clauses: Array[String] = []
	service_clauses.append("Minimum fleet: %d trains" % int(sc.get("fleet_goal", 1)))
	service_clauses.append(String(template.get("service_clause", "Keep the service route compact and reliable.")))
	if String(template.get("id", "")) == "passing_siding":
		service_clauses.append("Signal proof: build at least %d signal gates for passing capacity." % _passing_capacity_target(sc))
	if String(template.get("id", "")) == "junction_sort":
		service_clauses.append("Junction proof: build at least %d chain-signal gates before shared conflict points." % _junction_chain_target(sc))
	if String(template.get("id", "")) == "efficiency_run":
		service_clauses.append("Lean proof: no extra scheduled stops, fleet within +1, and material within par.")
	if String(template.get("id", "")) == "processor_chain":
		service_clauses.append("Processor proof: feed coal into the processor, then export steel made by that processor.")
	if not clause.is_empty():
		service_clauses.append("%s: %s" % [String(clause.get("name", "Clause")), String(clause.get("desc", ""))])
	return {
		"template_id": String(template.get("id", "branch_delivery")),
		"template_name": String(template.get("name", "Branch Delivery")),
		"summary": String(template.get("summary", "")),
		"service_mix": sc.get("service_mix", []),
		"mixed_template_id": String(sc.get("mixed_template_id", "")),
		"tier": int(sc.get("difficulty", 1)),
		"terrain_tags": terrain_tags,
		"required_deliveries": required_deliveries,
		"route_clauses": route_clauses,
		"service_clauses": service_clauses,
		"bonus_clause": _contract_bonus_challenge_text(sc),
		"resource_budget": sc.get("resource_budget", {}),
		"star_thresholds": sc.get("star_thresholds", {}),
		"solution_variants": sc.get("solution_variants", []),
		"train_car_count": int(sc.get("train_car_count", 1)),
		"grade_thresholds": {
			"bronze": "Complete all required deliveries.",
			"silver": "Complete reliably near material, time, and wait targets.",
			"gold": "Meet the contract clauses with clean routing.",
			"perfect": "Gold clear plus the optional bonus clause."
		},
		"reward_profile": {
			"base_money": int(sc.get("reward_money", 0)),
			"bonus_money": int(sc.get("bonus_money", 0)),
			"traffic_load": int(sc.get("reward_load", 0)),
			"traffic_capacity": int(sc.get("reward_capacity", 0))
		}
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

func _contract_clause_for(index: int, pattern: int, difficulty: int) -> Dictionary:
	var clauses := [
		{
			"type": "express_flow",
			"name": "Express Flow",
			"desc": "Keep useful deliveries frequent; long circular gaps are graded harder."
		},
		{
			"type": "lean_build",
			"name": "Lean Build",
			"desc": "Material par is tighter; compact infrastructure matters more."
		},
		{
			"type": "clean_returns",
			"name": "Clean Returns",
			"desc": "Empty running is scrutinized; avoid wasteful return loops."
		},
		{
			"type": "compact_network",
			"name": "Compact Network",
			"desc": "Keep the rail network close to the proof path; map-wide comfort loops miss the bonus."
		}
	]
	var old_rotation := (index + pattern + difficulty) % 3
	var clause_index := 3 if (index + pattern + difficulty) % 5 == 4 else old_rotation
	var clause: Dictionary = (clauses[clause_index] as Dictionary).duplicate(true)
	clause["tier"] = difficulty
	return clause

func _apply_contract_clause_modifiers(sc: Dictionary) -> void:
	var clause: Dictionary = sc.get("contract_clause", {})
	var clause_type := String(clause.get("type", ""))
	if clause_type == "express_flow":
		sc["flow_gap_multiplier"] = 0.82 if int(clause.get("tier", 1)) <= 1 else 0.72
	elif clause_type == "lean_build":
		sc["material_par_multiplier"] = 0.92 if int(clause.get("tier", 1)) <= 1 else 0.84
	elif clause_type == "clean_returns":
		sc["empty_share_limit"] = 0.36 if int(clause.get("tier", 1)) <= 1 else 0.30
	elif clause_type == "compact_network":
		sc["sprawl_allowance_bonus"] = 0 if int(clause.get("tier", 1)) <= 1 else -2

func _contract_clause_text(sc: Dictionary) -> String:
	var clause: Dictionary = sc.get("contract_clause", {})
	if clause.is_empty():
		return ""
	return "%s: %s" % [String(clause.get("name", "Clause")), String(clause.get("desc", ""))]

func _contract_bonus_challenge_text(sc: Dictionary) -> String:
	var bonus_money := int(sc.get("bonus_money", 0))
	var clause: Dictionary = sc.get("contract_clause", {})
	var clause_type := String(clause.get("type", ""))
	if bonus_money <= 0 or clause_type == "":
		return ""
	if clause_type == "express_flow":
		return "Bonus Challenge: Priority flow - keep useful delivery gaps inside the flow target for +$%d." % bonus_money
	if clause_type == "lean_build":
		return "Bonus Challenge: Master builder - finish within material par for +$%d." % bonus_money
	if clause_type == "clean_returns":
		return "Bonus Challenge: Clean returns - keep empty running inside the clause limit for +$%d." % bonus_money
	if clause_type == "compact_network":
		return "Bonus Challenge: Compact network - finish without rail sprawl beyond the proof budget for +$%d." % bonus_money
	return ""

func _contract_bonus_challenge_met(sc: Dictionary, _avg_wait: float, productive: bool) -> bool:
	if int(sc.get("bonus_money", 0)) <= 0 or not productive:
		return false
	var clause: Dictionary = sc.get("contract_clause", {})
	var clause_type := String(clause.get("type", ""))
	if clause_type == "express_flow":
		return _completion_progress() > 0 and _max_output_gap() <= _flow_gap_target()
	if clause_type == "lean_build":
		return int(local.get("infra_cost", 0)) <= _reward_material_par(sc)
	if clause_type == "clean_returns":
		return _completion_progress() > 0 and _empty_mileage_share() <= _empty_running_grade_limit(sc)
	if clause_type == "compact_network":
		return _completion_progress() > 0 and _network_sprawl_score(sc) <= 0
	return false

func _contract_bonus_reward_money(sc: Dictionary, avg_wait: float, productive: bool) -> int:
	if _contract_bonus_challenge_met(sc, avg_wait, productive):
		return int(sc.get("bonus_money", 0))
	return 0

func _contract_bonus_result_text(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	var challenge := _contract_bonus_challenge_text(sc)
	if challenge == "":
		return "none"
	var bonus_money := int(sc.get("bonus_money", 0))
	if _contract_bonus_challenge_met(sc, avg_wait, productive):
		return "met (+$%d)" % bonus_money
	return "missed (+$%d available)" % bonus_money

func _contract_bonus_coach_text(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	if _contract_bonus_challenge_text(sc) == "":
		return ""
	var clause: Dictionary = sc.get("contract_clause", {})
	var clause_type := String(clause.get("type", ""))
	if _contract_bonus_challenge_met(sc, avg_wait, productive):
		return "Bonus ready: claim it with a reliable clear."
	if not productive:
		return "Bonus coach: first clear fleet, wait, and deadlock reliability."
	if clause_type == "express_flow":
		if _completion_progress() <= 0:
			return "Bonus coach: start contract output, then keep gaps under %.0fs." % _flow_gap_target()
		return "Bonus coach: flow gap %.0fs / %.0fs; shorten the cycle or add passing capacity." % [_max_output_gap(), _flow_gap_target()]
	if clause_type == "lean_build":
		return "Bonus coach: material %d / %d; trim low-value track, signals, or extra trains." % [int(local.get("infra_cost", 0)), _reward_material_par(sc)]
	if clause_type == "clean_returns":
		if _completion_progress() <= 0:
			return "Bonus coach: start contract output, then keep empty running under %.0f%%." % (_empty_running_grade_limit(sc) * 100.0)
		return "Bonus coach: empty running %.0f%% / %.0f%%; shorten return loops or stage trains smarter." % [_empty_mileage_share() * 100.0, _empty_running_grade_limit(sc) * 100.0]
	if clause_type == "compact_network":
		if _completion_progress() <= 0:
			return "Bonus coach: start contract output, then keep the rail map inside the proof budget."
		return "Bonus coach: rail sprawl %d tiles over budget; erase low-value comfort loops." % _network_sprawl_score(sc)
	return ""

func _result_replay_label(grade: String, has_bonus: bool, bonus_met: bool) -> String:
	if has_bonus and not bonus_met:
		return "Replay for Bonus"
	if grade == "perfect":
		return "Replay Perfect"
	if grade not in ["gold", "perfect"]:
		return "Replay for Gold"
	return "Replay Mastery"

func _result_next_try_text(sc: Dictionary, avg_wait: float, productive: bool, grade: String) -> String:
	var bonus_text := _contract_bonus_challenge_text(sc)
	var bonus_met := _contract_bonus_challenge_met(sc, avg_wait, productive)
	if bonus_text != "" and not bonus_met:
		return "Chase the bonus: %s" % _contract_bonus_coach_text(sc, avg_wait, productive).replace("Bonus coach: ", "")
	if grade not in ["gold", "perfect"]:
		return "Push for Gold: %s" % _grade_coach_text(sc, avg_wait, productive)
	if grade == "gold" and bonus_text != "":
		return "Push for Perfect: meet the bonus while preserving Gold efficiency."
	return "Mastery run: try a cleaner, faster layout or a new regional contract."

func _completion_quality_rank(grade: String) -> int:
	if grade == "perfect":
		return 5
	if grade == "gold":
		return 4
	if grade == "silver":
		return 3
	if grade == "bronze":
		return 2
	return 1

func _mastery_record_summary(record: Dictionary) -> String:
	if record.is_empty():
		return "none yet"
	var grade := _completion_quality_short_label(String(record.get("grade", "rough")))
	var bonus := " + bonus" if bool(record.get("bonus_met", false)) else ""
	return "%s%s, $%d reward, %.1fs wait" % [
		grade,
		bonus,
		int(record.get("reward_money", 0)),
		float(record.get("avg_wait", 0.0))
	]

func _mastery_record_overview_text() -> String:
	var records: Dictionary = campaign.get("mastery_records", {})
	if records.is_empty():
		return "Mastery records: none yet."
	var bonus_count := 0
	var gold_count := 0
	for id in records.keys():
		var record: Dictionary = records[id]
		if bool(record.get("bonus_met", false)):
			bonus_count += 1
		if String(record.get("grade", "")) in ["gold", "perfect"]:
			gold_count += 1
	return "Mastery records: %d bests, %d Gold+, %d bonus clears." % [records.size(), gold_count, bonus_count]

func _mastery_badge_for_scenario(id: String) -> String:
	if id == "":
		return ""
	var records: Dictionary = campaign.get("mastery_records", {})
	if not records.has(id):
		return ""
	var record: Dictionary = records[id]
	return "Best: %s" % _mastery_record_summary(record)

func _mastery_record_is_improvement(previous: Dictionary, grade: String, bonus_met: bool, reward_money: int, avg_wait: float) -> bool:
	if previous.is_empty():
		return true
	var rank: int = _completion_quality_rank(grade)
	var previous_rank: int = int(previous.get("grade_rank", 0))
	if rank != previous_rank:
		return rank > previous_rank
	var previous_bonus := bool(previous.get("bonus_met", false))
	if bonus_met != previous_bonus:
		return bonus_met
	var previous_reward := int(previous.get("reward_money", 0))
	if reward_money != previous_reward:
		return reward_money > previous_reward
	return avg_wait < float(previous.get("avg_wait", 999999.0))

func _update_mastery_record(sc: Dictionary, grade: String, avg_wait: float, productive: bool, reward_money: int) -> Dictionary:
	var id := String(sc.get("id", local.get("id", "")))
	if id == "":
		return {"changed": false, "text": "Best: none yet"}
	var records: Dictionary = campaign.get("mastery_records", {})
	var previous: Dictionary = records.get(id, {})
	var bonus_met := _contract_bonus_challenge_met(sc, avg_wait, productive)
	var improved := _mastery_record_is_improvement(previous, grade, bonus_met, reward_money, avg_wait)
	if improved:
		var record := {
			"id": id,
			"name": String(sc.get("name", id)),
			"grade": grade,
			"grade_rank": _completion_quality_rank(grade),
			"bonus_met": bonus_met,
			"reward_money": reward_money,
			"avg_wait": avg_wait,
			"completed_at_step": int(campaign.get("run_step", 0))
		}
		records[id] = record
		campaign["mastery_records"] = records
		return {"changed": true, "text": "New best: %s" % _mastery_record_summary(record)}
	return {"changed": false, "text": "Best: %s" % _mastery_record_summary(previous)}

func _scenario_route_preview(sc: Dictionary) -> String:
	var route: Array = sc.get("route", [])
	if route.is_empty():
		return ""
	var names: Array[String] = []
	var by_id := {}
	for raw_station in sc.get("stations", []):
		var station: Dictionary = raw_station
		by_id[String(station.get("id", ""))] = String(station.get("name", station.get("id", "")))
	for raw_id in route:
		var station_id := String(raw_id)
		var name := String(by_id.get(station_id, station_id))
		if names.is_empty() or names[names.size() - 1] != name:
			names.append(name)
	return "Stops: %s" % " -> ".join(names)

func _station_name_for_scenario(sc: Dictionary, station_id: String) -> String:
	for raw_station in sc.get("stations", []):
		var station: Dictionary = raw_station
		if String(station.get("id", "")) == station_id:
			return String(station.get("name", station_id))
	return station_id

func _service_mix_text(sc: Dictionary) -> String:
	var mix: Array = sc.get("service_mix", [])
	if mix.is_empty():
		return ""
	var labels: Array[String] = []
	for cargo in mix:
		labels.append(_resource_name(String(cargo)).capitalize())
	return " + ".join(labels)

func _regional_contract_preview_text(sc: Dictionary) -> String:
	var lines: Array[String] = []
	var puzzle: Dictionary = sc.get("contract_puzzle", {})
	if not puzzle.is_empty():
		lines.append("%s: %s" % [String(puzzle.get("template_name", "Rail Sudoku")), String(puzzle.get("summary", ""))])
		lines.append(_contract_puzzle_checklist_text(sc, false))
	var route_preview := _scenario_route_preview(sc)
	if route_preview != "":
		lines.append(route_preview)
	var service_mix := _service_mix_text(sc)
	if service_mix != "":
		lines.append("Service Mix: %s" % service_mix)
	var clause := _contract_clause_text(sc)
	if clause != "":
		lines.append(clause)
	var bonus := _contract_bonus_challenge_text(sc)
	if bonus != "":
		lines.append(bonus)
	var pressure_text := _regional_contract_pressure_text(sc)
	if pressure_text != "":
		lines.append(pressure_text)
	var streak_text := _regional_mastery_streak_preview_text(sc)
	if streak_text != "":
		lines.append(streak_text)
	var recovery_text := _regional_inspection_recovery_preview_text(sc)
	if recovery_text != "":
		lines.append(recovery_text)
	var mastery_badge := _mastery_badge_for_scenario(String(sc.get("id", "")))
	if mastery_badge != "":
		lines.append(mastery_badge)
	lines.append("Fleet %d  Wait %.0fs  Target %d" % [
		int(sc.get("fleet_goal", 1)),
		float(sc.get("wait_target", 0.0)),
		int(sc.get("target", 0))
	])
	return "\n".join(lines)

func _regional_inspection_recovery_preview_text(sc: Dictionary) -> String:
	if not _is_run_scenario_id(String(sc.get("id", ""))):
		return ""
	var traits: Dictionary = campaign.get("regional_traits", {})
	var debt: int = int(traits.get("inspection_debt", 0))
	if debt <= 0:
		return ""
	return "Recovery: Gold/Perfect clears reduce inspection debt; rough loop clears add more."

func _regional_mastery_streak_preview_text(sc: Dictionary) -> String:
	if not _is_run_scenario_id(String(sc.get("id", ""))):
		return ""
	var next_bonus := _completion_mastery_streak_bonus(sc, "gold")
	if next_bonus <= 0:
		return ""
	var current_streak := _current_mastery_streak_length()
	return "Mastery streak: %d Gold+ in a row; Gold/Perfect here earns +$%d." % [current_streak, next_bonus]

func _contract_puzzle_checklist_text(sc: Dictionary, live: bool = false) -> String:
	var puzzle: Dictionary = sc.get("contract_puzzle", {})
	if puzzle.is_empty():
		return ""
	var items: Array[String] = []
	for text in puzzle.get("required_deliveries", []):
		items.append("%s %s" % [_check_mark(live and _completion_progress() >= int(local.get("target", 0))), String(text)])
	var route_ready := false
	if live:
		for id in lines.keys():
			if _line_contract_ready(String(id)):
				route_ready = true
				break
	for text in puzzle.get("route_clauses", []):
		items.append("%s %s" % [_check_mark(live and route_ready), String(text)])
	var trip_proof := _contract_trip_proof_text(sc)
	if trip_proof != "":
		var trip_ready := live and _completion_progress() > 0 and int(local.get("unqualified_output", 0)) <= 0
		if String(sc.get("template_id", "")) == "processor_chain":
			trip_ready = live and _processor_proof_missing(sc) <= 0
		items.append("%s %s" % [_check_mark(trip_ready), trip_proof])
	var fleet_ready := live and _active_train_count() >= _fleet_goal()
	for text in puzzle.get("service_clauses", []):
		var clause_text := String(text)
		var clause_ready := fleet_ready
		if clause_text.begins_with("Signal proof:"):
			clause_ready = live and _passing_capacity_missing(sc) <= 0
		elif clause_text.begins_with("Junction proof:"):
			clause_ready = live and _junction_chain_missing(sc) <= 0
		elif clause_text.begins_with("Lean proof:"):
			clause_ready = live and _efficiency_proof_missing(sc) <= 0
		elif clause_text.begins_with("Processor proof:"):
			clause_ready = live and _processor_proof_missing(sc) <= 0
		items.append("%s %s" % [_check_mark(clause_ready), clause_text])
	var bonus := String(puzzle.get("bonus_clause", ""))
	if bonus != "":
		items.append("%s %s" % [_check_mark(live and _contract_bonus_challenge_met(sc, _average_wait(), _current_productive_for_grade(_average_wait()))), bonus])
	return "\n".join(items)

func _contract_trip_proof_text(sc: Dictionary) -> String:
	if sc.is_empty():
		return ""
	if String(sc.get("template_id", "")) == "processor_chain" or String(sc.get("kind", "")) == "steel":
		return "Trip proof: processor output needs coal feed into the processor and processor-made export; split shuttles count only through those handoffs."
	if (sc.get("route", []) as Array).is_empty() and String(sc.get("template_id", "")) == "":
		return ""
	return "Trip proof: each loaded trip must visit the required stops in order; shortcut or handoff shuttles stay sandbox output."

func _check_mark(done: bool) -> String:
	return "[x]" if done else "[ ]"

func _regional_pressure_forecast_text(traits: Dictionary) -> String:
	var through: int = int(traits.get("through_traffic", 0))
	var capacity: int = int(traits.get("capacity_rating", 0))
	var pressure: int = max(0, through - capacity)
	var reliability: float = float(traits.get("reliability", 1.0))
	var burst: float = float(traits.get("burstiness", 0.0))
	var inspection_level := _regional_inspection_level(traits)
	if pressure <= 0 and reliability >= 0.92 and burst < 0.12 and inspection_level <= 0:
		return "Regional pressure: calm. Clean clears are keeping future contracts forgiving."
	var parts: Array[String] = []
	if pressure > 0:
		parts.append("+%d traffic over capacity" % pressure)
	if reliability < 0.92:
		parts.append("%.0f%% reliability" % (reliability * 100.0))
	if burst >= 0.12:
		parts.append("%.0f%% operating surge" % (burst * 100.0))
	if inspection_level > 0:
		parts.append("inspection L%d" % inspection_level)
	return "Regional pressure: %s. Gold dispatch and bonus clears keep later maps calmer." % ", ".join(parts)

func _regional_operating_surge_level(traits: Dictionary) -> int:
	var burst: float = float(traits.get("burstiness", 0.0))
	if burst < 0.12:
		return 0
	return int(clamp(ceil(burst * 4.0), 1.0, 5.0))

func _regional_inspection_level(traits: Dictionary) -> int:
	var debt: int = int(traits.get("inspection_debt", 0))
	if debt < 3:
		return 0
	return int(clamp(ceil(float(debt) / 3.0), 1.0, 5.0))

func _regional_contract_pressure_text(sc: Dictionary) -> String:
	var pressure: int = int(sc.get("regional_pressure", 0))
	var surge: int = int(sc.get("regional_surge_level", 0))
	var inspection: int = int(sc.get("regional_inspection_level", 0))
	if pressure <= 0 and surge <= 0 and inspection <= 0:
		return ""
	var parts: Array[String] = []
	if pressure > 0:
		parts.append("traffic +%d" % pressure)
	if surge > 0:
		parts.append("surge L%d" % surge)
	if inspection > 0:
		parts.append("inspection L%d" % inspection)
	return "Regional pressure applied: %s." % ", ".join(parts)

func _requirements_for_contract(kind: String, difficulty: int, pattern: int, fleet_goal: int, clause: Dictionary = {}, puzzle: Dictionary = {}) -> Array[String]:
	var req: Array[String] = []
	if not puzzle.is_empty():
		req.append("Puzzle template - %s: %s" % [String(puzzle.get("template_name", "Rail Sudoku")), String(puzzle.get("summary", ""))])
		var mix: Array = puzzle.get("service_mix", [])
		if mix.size() >= 2:
			var labels: Array[String] = []
			for cargo in mix:
				labels.append(_resource_name(String(cargo)).capitalize())
			req.append("Mixed service crossing: %s must share compact infrastructure without becoming one catch-all loop." % " + ".join(labels))
	req.append("Minimum fleet: %d trains" % fleet_goal)
	req.append("Route includes an off-axis branch stop; a simple A-to-B double track is not enough.")
	req.append("Terrain forces at least one detour or bridge decision.")
	if not clause.is_empty():
		req.append("Contract clause - %s: %s" % [String(clause.get("name", "Clause")), String(clause.get("desc", ""))])
		req.append("Optional bonus challenge rewards clean, clause-specific play.")
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

func _terrain_without_blocking_path_tiles(terrain: Array, path: Array[Vector2i], allowed_blocked: Array[Vector2i]) -> Array:
	var path_keys := {}
	for cell in path:
		var path_cell: Vector2i = cell
		path_keys[_track_key(path_cell)] = true
	var allowed_keys := {}
	for cell in allowed_blocked:
		var allowed_cell: Vector2i = cell
		allowed_keys[_track_key(allowed_cell)] = true
	var result: Array = []
	for item in terrain:
		var pos: Vector2i = item.get("pos", Vector2i(-999, -999))
		var terrain_type := String(item.get("type", ""))
		var pos_key := _track_key(pos)
		if path_keys.has(pos_key) and not allowed_keys.has(pos_key) and terrain_type in ["mountain", "rock", "ocean"]:
			continue
		result.append(item)
	return result

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
	if not campaign.has("mastery_records") or typeof(campaign["mastery_records"]) != TYPE_DICTIONARY:
		campaign["mastery_records"] = {}
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
	if not campaign.has("regional_tile_records") or typeof(campaign["regional_tile_records"]) != TYPE_DICTIONARY:
		campaign["regional_tile_records"] = {}
	if not campaign.has("regional_visible_tiles") or typeof(campaign["regional_visible_tiles"]) != TYPE_ARRAY or (campaign["regional_visible_tiles"] as Array).is_empty():
		campaign["regional_visible_tiles"] = _regional_neighbors(REGIONAL_START_KEY)
	if not campaign.has("active_regional_tile"):
		campaign["active_regional_tile"] = ""
	if not campaign.has("daily_puzzle_seed"):
		campaign["daily_puzzle_seed"] = DAILY_PUZZLE_SEED
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
	if not traits.has("inspection_debt"):
		traits["inspection_debt"] = 0
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
		"burstiness": 0.0,
		"inspection_debt": 0
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
	campaign["regional_tile_records"] = {}
	campaign["regional_visible_tiles"] = []
	campaign["active_regional_tile"] = ""
	campaign["daily_puzzle_seed"] = DAILY_PUZZLE_SEED
	campaign["permanent_upgrades"] = {}
	campaign["run_upgrades"] = {}
	campaign["upgrade_shop"] = []
	campaign["run_step"] = 0
	campaign["run_completed"] = []
	campaign["run_available"] = []
	campaign["run_history"] = []
	campaign["mastery_records"] = {}
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
			var template_id := ""
			if key != REGIONAL_START_KEY and x <= 4 and scenario_index <= RUN_POOL_SIZE:
				scenario_id = "%s%02d" % [RUN_SCENARIO_PREFIX, scenario_index]
				template_id = String(_puzzle_template_for((scenario_index - 1) % 6, "steel" if ((scenario_index - 1) % 6) == 5 else "coal").get("id", "branch_delivery"))
				scenario_index += 1
			tiles.append({
				"key": key,
				"x": x,
				"y": y,
				"terrain": terrain,
				"tier": tier,
				"scenario_id": scenario_id,
				"template_id": template_id,
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

func _complete_regional_tile_for_scenario(id: String, grade: String = "", reward_money: int = 0, pressure_delta: int = 0) -> void:
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
	var scenario := _get_scenario(id)
	var records: Dictionary = campaign.get("regional_tile_records", {})
	records[active_key] = {
		"scenario_id": id,
		"template_id": String(scenario.get("template_id", "")),
		"template_name": String(scenario.get("template_name", "")),
		"grade": grade,
		"reward": reward_money,
		"pressure_delta": pressure_delta,
		"terrain": String(tile.get("terrain", "plains")),
		"tier": int(tile.get("tier", 1))
	}
	campaign["regional_tile_records"] = records
	_reveal_regional_neighbors(active_key)
	campaign["active_regional_tile"] = ""
	_generate_upgrade_shop()

func _upgrade_defs() -> Dictionary:
	return {
		"reward_multiplier": {"name": "Prize Ledger", "scope": "permanent", "cost": 260, "desc": "+10% campaign money from graded clears."},
		"station_planning": {"name": "Platform Permit", "scope": "permanent", "cost": 340, "desc": "+1 starting platform on generated puzzles."},
		"wider_offers": {"name": "Shop Network", "scope": "permanent", "cost": 420, "desc": "Adds one more upgrade offer after each puzzle."},
		"train_voucher": {"name": "Train Voucher", "scope": "run", "cost": 180, "desc": "Next train has no material score."},
		"dispatch_reliability": {"name": "Signal Assist", "scope": "run", "cost": 220, "desc": "More forgiving wait targets this run."},
		"material_efficiency": {"name": "Material Rebate", "scope": "run", "cost": 240, "desc": "Material score counts 10% lighter."},
		"throughput_boost": {"name": "Throughput Crew", "scope": "run", "cost": 210, "desc": "Station work tolerates tighter layouts."}
	}

func _generate_upgrade_shop() -> void:
	var defs := _upgrade_defs()
	var ids: Array = defs.keys()
	var offers: Array = []
	var seed: int = int(campaign.get("regional_map_seed", 32027)) + int(campaign.get("run_step", 0)) * 17
	var offset := 0
	var offer_count: int = clamp(3 + _upgrade_level("wider_offers"), 3, 5)
	while offers.size() < offer_count and offset < ids.size() * 3:
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
	var surge_level := _regional_operating_surge_level(traits)
	var inspection_level := _regional_inspection_level(traits)
	var pressure: int = int(max(0, through - capacity))
	var tile_tier := int(tile.get("tier", 1))
	sc["target"] = int(sc.get("target", 60)) + pressure * 2 + surge_level * 7 + inspection_level * 5 + int((1.0 - reliability) * 20.0) + tile_tier * 8 + int(campaign.get("run_step", 0)) * 2
	sc["fleet_goal"] = min(8, int(sc.get("fleet_goal", 1)) + int(pressure >= 8) + int(surge_level >= 3) + int(inspection_level >= 4) + int(tile_tier >= 4))
	sc["start_budget"] = int(sc.get("start_budget", 1500)) + capacity * 10
	sc["wait_target"] = max(28.0, float(sc.get("wait_target", 45.0)) - min(14.0, float(pressure)) - min(10.0, float(surge_level) * 2.5) - min(8.0, float(inspection_level) * 1.8) + float(_upgrade_level("dispatch_reliability")) * 4.0)
	sc["regional_pressure"] = pressure
	sc["regional_surge_level"] = surge_level
	sc["regional_inspection_level"] = inspection_level
	sc["regional_tile"] = tile.duplicate(true)
	_apply_regional_tile_modifier(sc, tile)
	_apply_upgrade_scenario_modifiers(sc)
	if bool(sc.get("order_mode", false)):
		_apply_order_pressure_to_target(sc)
		_normalize_scenario_contracts(sc)
	sc["terrain"] = _terrain_without_blocking_path_tiles(sc.get("terrain", []), sc.get("ghost", []), _station_positions(sc.get("stations", [])))
	var template_defs := _puzzle_template_defs()
	var template_id := String(sc.get("template_id", "branch_delivery"))
	var template: Dictionary = (template_defs.get(template_id, template_defs["branch_delivery"]) as Dictionary).duplicate(true)
	sc["contract_puzzle"] = _contract_puzzle_schema_for(sc, template)
	sc["requirements"] = _requirements_for_contract(String(sc.get("kind", "coal")), int(sc.get("difficulty", 1)), 0, int(sc.get("fleet_goal", 1)), sc.get("contract_clause", {}), sc["contract_puzzle"])
	var briefing := String(sc.get("briefing", ""))
	briefing += "\nRegional tile: %s tier %d. Inherited region: Through traffic %d, capacity rating %d, reliability %.0f%%, surge L%d, inspection L%d. These values come from previous completed nodes." % [
		String(tile.get("terrain", "plains")).capitalize(),
		tile_tier,
		through,
		capacity,
		reliability * 100.0,
		surge_level,
		inspection_level
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

func _apply_order_pressure_to_target(sc: Dictionary) -> void:
	var orders: Array = sc.get("orders", [])
	if orders.is_empty():
		return
	var desired_total: int = max(1, int(sc.get("target", _scenario_order_target(sc))))
	var current_total: int = _scenario_order_target(sc)
	var extra: int = max(0, desired_total - current_total)
	if extra <= 0:
		sc["target"] = current_total
		return
	var priority_index := 0
	var priority := -999
	for i in range(orders.size()):
		var order: Dictionary = orders[i]
		if int(order.get("priority", 0)) > priority:
			priority = int(order.get("priority", 0))
			priority_index = i
	var chosen: Dictionary = orders[priority_index]
	chosen["amount"] = int(chosen.get("amount", 0)) + extra
	orders[priority_index] = chosen
	sc["orders"] = orders
	sc["target"] = _scenario_order_target(sc)

func _record_run_completion(sc: Dictionary, avg_wait: float, productive: bool, quality_grade: String = "") -> void:
	var id := String(sc.get("id", ""))
	if not _is_run_scenario_id(id) or _run_completed_has(id):
		return
	var run_completed: Array = campaign.get("run_completed", [])
	run_completed.append(id)
	campaign["run_completed"] = run_completed
	campaign["run_step"] = min(RUN_LENGTH, run_completed.size())
	var reliability_score := 1.0
	if float(local.get("wait_target", 1.0)) > 0.0:
		reliability_score = clamp(1.0 - (avg_wait / max(1.0, float(local.get("wait_target", 1.0)))) * 0.35, 0.35, 1.0)
	if int(local.get("deadlocks", 0)) > 0:
		reliability_score *= 0.75
	if productive:
		reliability_score = min(1.0, reliability_score + 0.08)
	if quality_grade == "":
		quality_grade = _completion_quality_grade(sc, avg_wait, productive)
	reliability_score = clamp(reliability_score * _completion_quality_reliability_multiplier(quality_grade), 0.2, 1.15)
	var effects := _completion_quality_regional_effects(sc, quality_grade)
	var reward_money := _completion_reward_money(sc, avg_wait, productive)
	var pressure_delta := int(effects.get("traffic", 0)) - int(effects.get("capacity", 0))
	_complete_regional_tile_for_scenario(id, quality_grade, reward_money, pressure_delta)
	var traits: Dictionary = campaign.get("regional_traits", {})
	var inspection_delta := _completion_inspection_delta(sc, quality_grade)
	traits["through_traffic"] = int(traits.get("through_traffic", 0)) + int(effects.get("traffic", int(sc.get("reward_load", 0))))
	traits["capacity_rating"] = int(traits.get("capacity_rating", 0)) + int(effects.get("capacity", int(sc.get("reward_capacity", 0))))
	traits["reliability"] = clamp((float(traits.get("reliability", 1.0)) * 0.75) + reliability_score * 0.25, 0.2, 1.15)
	traits["burstiness"] = clamp(float(traits.get("burstiness", 0.0)) + (1.0 - reliability_score) * 0.3 + float(effects.get("burst", 0.0)), 0.0, 2.0)
	traits["inspection_debt"] = int(clamp(int(traits.get("inspection_debt", 0)) + inspection_delta, 0, 15))
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
		"quality_grade": quality_grade,
		"reward_money": reward_money,
		"template_id": String(sc.get("template_id", "")),
		"pressure_delta": pressure_delta,
		"inspection_delta": inspection_delta,
		"inspection_debt": int(traits.get("inspection_debt", 0)),
		"regional_traffic": int(effects.get("traffic", int(sc.get("reward_load", 0)))),
		"regional_capacity": int(effects.get("capacity", int(sc.get("reward_capacity", 0)))),
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
	_add_backplate(ui_hud_texture, Control.PRESET_TOP_WIDE, Vector4(_scaled(6.0), _scaled(2.0), -_scaled(6.0), _scaled(48.0)), Vector4(220, 110, 220, 100), Color(1, 1, 1, 0.94))
	top_status = Label.new()
	top_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_status.offset_left = _scaled(80.0)
	top_status.offset_top = _scaled(13.0)
	top_status.offset_right = -_scaled(64.0)
	top_status.offset_bottom = _scaled(42.0)
	top_status.clip_text = true
	top_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_status.add_theme_font_size_override("font_size", _scaled_font(18))
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
	var header_right: float = min(max(_scaled(760.0), size.x - _regional_side_panel_width() - _scaled(56.0)), _scaled(1080.0))
	var reset_left: float = header_right - _scaled(148.0)
	_add_backplate(ui_panel_texture, Control.PRESET_TOP_LEFT, Vector4(_scaled(32.0), _scaled(24.0), header_right, _scaled(112.0)), Vector4(160, 120, 160, 120), Color(1, 1, 1, 0.96))
	var title := Label.new()
	title.text = "TrainsTrainsTrains: Rail Sudoku Run"
	title.add_theme_font_size_override("font_size", _scaled_font(36))
	title.add_theme_color_override("font_color", Color.html("#172028"))
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = _scaled(84.0)
	title.offset_top = _scaled(34.0)
	title.offset_right = reset_left - _scaled(18.0)
	title.offset_bottom = _scaled(78.0)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title)

	var hint := Label.new()
	hint.text = "Choose an adjacent tile, solve its train logic puzzle, then let the simulation prove it."
	hint.add_theme_font_size_override("font_size", _scaled_font(17))
	hint.add_theme_color_override("font_color", Color.html("#28363f"))
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.offset_left = _scaled(86.0)
	hint.offset_top = _scaled(78.0)
	hint.offset_right = reset_left - _scaled(18.0)
	hint.offset_bottom = _scaled(106.0)
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(hint)

	var reset_button := _add_button(self, "Reset\nProgress", func(): _reset_progress())
	reset_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_button.offset_left = reset_left
	reset_button.offset_top = _scaled(38.0)
	reset_button.offset_right = header_right - _scaled(12.0)
	reset_button.offset_bottom = _scaled(104.0)

	side_panel = PanelContainer.new()
	_style_panel(side_panel)
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -_regional_side_panel_width()
	side_panel.offset_top = _scaled(64.0)
	side_panel.offset_right = -_scaled(10.0)
	side_panel.offset_bottom = -_scaled(16.0)
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
	side_text.custom_minimum_size = Vector2(0, _scaled(360.0))
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", _scaled_font(16))
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
	var hud_width := _local_hud_width()
	var hud_top := _scaled(8.0)
	var hud_height := _scaled(58.0 if size.x >= 1800.0 else (48.0 if size.x >= 1200.0 else 40.0))
	var status_plate := _add_backplate(
		ui_panel_texture,
		Control.PRESET_TOP_LEFT,
		Vector4(_scaled(8.0), _scaled(5.0), max(_scaled(460.0), size.x - hud_width - _scaled(26.0)), _scaled(46.0)),
		Vector4(120, 90, 120, 90),
		Color(1.0, 0.97, 0.82, 0.96)
	)
	status_plate.z_index = 29
	hud_bar = HBoxContainer.new()
	hud_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_bar.offset_left = -hud_width
	hud_bar.offset_top = hud_top
	hud_bar.offset_right = -_scaled(8.0)
	hud_bar.offset_bottom = hud_top + hud_height
	hud_bar.add_theme_constant_override("separation", int(_scaled(6.0)))
	hud_bar.z_index = 30
	hud_bar.z_as_relative = false
	add_child(hud_bar)
	if top_status != null:
		top_status.offset_left = _scaled(26.0)
		top_status.offset_top = _scaled(11.0)
		top_status.offset_right = -(hud_width + _scaled(36.0))
		top_status.offset_bottom = _scaled(48.0 if size.x >= 1800.0 else 43.0)
		top_status.z_index = 31
		top_status.add_theme_font_size_override("font_size", _scaled_font(21 if size.x >= 1800.0 else (18 if size.x >= 1200.0 else 17)))

	_add_button(hud_bar, "Pause", func(): _toggle_pause())
	_add_button(hud_bar, "1x/2x", func(): _toggle_speed())
	_add_button(hud_bar, "Test", func(): _toggle_test_battery())
	_add_button(hud_bar, "Reset", func(): _restart_trains_only())
	_add_button(hud_bar, "Region", func(): _return_to_region())

	side_panel = PanelContainer.new()
	_style_panel(side_panel)
	side_panel.clip_contents = true
	side_panel.z_index = 28
	side_panel.z_as_relative = false
	add_child(side_panel)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", int(_scaled(4.0)))
	side_panel.add_child(side_box)
	line_picker_scroll = ScrollContainer.new()
	line_picker_scroll.custom_minimum_size = Vector2(0, _scaled(30.0))
	line_picker_scroll.visible = false
	side_box.add_child(line_picker_scroll)
	line_picker_row = HBoxContainer.new()
	line_picker_row.add_theme_constant_override("separation", int(_scaled(6.0)))
	line_picker_scroll.add_child(line_picker_row)
	side_text = RichTextLabel.new()
	side_text.bbcode_enabled = true
	side_text.fit_content = false
	side_text.scroll_active = true
	side_text.custom_minimum_size = Vector2(0, _scaled(54.0))
	side_text.add_theme_color_override("default_color", Color.html("#172028"))
	side_text.add_theme_font_size_override("normal_font_size", _scaled_font(13))
	side_text.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.78, 0.55))
	side_text.add_theme_constant_override("outline_size", 1)
	side_box.add_child(side_text)
	_apply_local_side_panel_layout()

	_build_mobile_overlay_ui()
	_refresh_local_side_text()

func _build_upgrade_shop_buttons(parent: VBoxContainer) -> void:
	_ensure_run_state()
	var defs := _upgrade_defs()
	var header := Label.new()
	header.text = "Upgrade Shop"
	header.add_theme_color_override("font_color", Color.html("#172028"))
	header.add_theme_font_size_override("font_size", _scaled_font(18))
	parent.add_child(header)
	for offer_id in campaign.get("upgrade_shop", []):
		var id := String(offer_id)
		if not defs.has(id):
			continue
		var def: Dictionary = defs[id]
		var b := _add_button(parent, "%s\n$%d" % [def.get("name", id), int(def.get("cost", 0))], func(upgrade_id := id): _purchase_upgrade(upgrade_id))
		b.custom_minimum_size = Vector2(0, _scaled(48.0))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = int(campaign.get("money", 0)) < int(def.get("cost", 0))
		b.add_theme_font_size_override("font_size", _scaled_font(13))

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
	var replay_button := _add_button(actions, String(result_data.get("replay_label", "Replay Scenario")), func(): start_scenario(result_data.get("id", "coal_valley")))
	replay_button.custom_minimum_size = Vector2(190, 54)

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(_scaled(124.0), _scaled(66.0))
	if parent == tool_bar:
		b.custom_minimum_size = Vector2(0, _scaled(52.0))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(b)
	if parent == hud_bar:
		if size.x >= 1800.0:
			b.custom_minimum_size = Vector2(_scaled(160.0), _scaled(58.0))
			b.add_theme_font_size_override("font_size", _scaled_font(19))
		elif size.x >= 1200.0:
			b.custom_minimum_size = Vector2(_scaled(132.0), _scaled(48.0))
			b.add_theme_font_size_override("font_size", _scaled_font(16))
		else:
			b.custom_minimum_size = Vector2(_scaled(82.0), _scaled(38.0))
			b.add_theme_font_size_override("font_size", _scaled_font(13))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _fit_sidebar_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, _scaled(52.0))
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
	toast_label.offset_left = _scaled(18.0)
	toast_label.offset_top = -_scaled(64.0)
	toast_label.offset_right = -_scaled(18.0)
	toast_label.offset_bottom = -_scaled(18.0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_font_size_override("font_size", _scaled_font(15))
	toast_label.add_theme_color_override("font_color", Color.html("#172028"))
	toast_label.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.92), Color.html("#172028"), 2, 8))
	toast_label.z_index = 35
	toast_label.z_as_relative = false
	add_child(toast_label)

	inspect_chip = RichTextLabel.new()
	inspect_chip.bbcode_enabled = true
	inspect_chip.scroll_active = false
	inspect_chip.fit_content = false
	inspect_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inspect_chip.offset_left = _scaled(18.0)
	inspect_chip.offset_top = _scaled(70.0)
	inspect_chip.offset_right = _scaled(430.0 if size.x >= 1200.0 else 360.0)
	inspect_chip.offset_bottom = _scaled(202.0)
	inspect_chip.add_theme_color_override("default_color", Color.html("#172028"))
	inspect_chip.add_theme_font_size_override("normal_font_size", _scaled_font(13))
	inspect_chip.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.92), Color.html("#172028"), 2, 8))
	inspect_chip.z_index = 35
	inspect_chip.z_as_relative = false
	inspect_chip.visible = false
	add_child(inspect_chip)

	service_edit_bar = HBoxContainer.new()
	service_edit_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	service_edit_bar.offset_left = _scaled(18.0)
	service_edit_bar.offset_top = -_local_tray_height() + _scaled(8.0)
	service_edit_bar.offset_right = -_scaled(18.0)
	service_edit_bar.offset_bottom = -_scaled(12.0)
	service_edit_bar.add_theme_constant_override("separation", int(_scaled(8.0)))
	service_edit_bar.z_index = 36
	service_edit_bar.z_as_relative = false
	add_child(service_edit_bar)

	service_edit_label = Label.new()
	service_edit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_edit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_edit_label.add_theme_font_size_override("font_size", _scaled_font(14))
	service_edit_label.add_theme_color_override("font_color", Color.html("#172028"))
	service_edit_label.add_theme_stylebox_override("normal", _flat_style(Color(1.0, 0.97, 0.82, 0.94), Color.html("#172028"), 2, 8))
	service_edit_bar.add_child(service_edit_label)
	var complete_button := _add_button(service_edit_bar, "Done", func(): _complete_service_edit())
	complete_button.custom_minimum_size = Vector2(_scaled(88.0), _scaled(44.0))
	var cancel_button := _add_button(service_edit_bar, "Cancel", func(): _cancel_service_edit())
	cancel_button.custom_minimum_size = Vector2(_scaled(96.0), _scaled(44.0))

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
	if bool(local.get("test_battery_running", false)):
		_stop_test_battery("Test battery paused by player.", true)
		return
	local["paused"] = !local.get("paused", true)
	local_message = "Simulation paused." if local["paused"] else "Trains are running."
	_refresh_local_side_text()

func _toggle_speed() -> void:
	if bool(local.get("test_battery_running", false)):
		_stop_test_battery("Test battery stopped. Normal speed restored.", true)
	local["speed"] = 2.0 if float(local.get("speed", 1.0)) < 2.0 else 1.0
	local_message = "Simulation speed: %sx" % int(local["speed"])
	_refresh_local_side_text()

func _toggle_test_battery() -> void:
	if bool(local.get("test_battery_running", false)):
		_stop_test_battery("Test battery stopped.", true)
		return
	local["test_battery_running"] = true
	local["test_battery_steps"] = TEST_BATTERY_START_STEPS
	local["test_battery_ramp_elapsed"] = 0.0
	local["test_battery_ticks"] = 0
	local["test_battery_last_deadlocks"] = int(local.get("deadlocks", 0))
	local["paused"] = false
	local_message = "Test battery running: accelerating until the solution wins or fails."
	_refresh_local_side_text()
	_update_status_labels()

func _stop_test_battery(message: String, pause_after: bool) -> void:
	local["test_battery_running"] = false
	local["test_battery_steps"] = TEST_BATTERY_START_STEPS
	local["test_battery_ramp_elapsed"] = 0.0
	if pause_after:
		local["paused"] = true
	local_message = message
	_refresh_local_side_text()
	_update_status_labels()

func _update_test_battery(delta: float) -> void:
	if screen != Screen.LOCAL or not bool(local.get("test_battery_running", false)):
		return
	local["test_battery_ramp_elapsed"] = float(local.get("test_battery_ramp_elapsed", 0.0)) + delta
	if float(local["test_battery_ramp_elapsed"]) >= TEST_BATTERY_RAMP_INTERVAL:
		local["test_battery_ramp_elapsed"] = 0.0
		var steps: int = int(local.get("test_battery_steps", TEST_BATTERY_START_STEPS))
		local["test_battery_steps"] = min(TEST_BATTERY_MAX_STEPS, int(ceil(float(steps) * 1.45)) + 2)
	var ticks_this_frame: int = int(local.get("test_battery_steps", TEST_BATTERY_START_STEPS))
	for i in range(ticks_this_frame):
		if screen != Screen.LOCAL or not bool(local.get("test_battery_running", false)):
			break
		var deadlocks_before: int = int(local.get("deadlocks", 0))
		_update_local(TEST_BATTERY_STEP, false)
		local["test_battery_ticks"] = int(local.get("test_battery_ticks", 0)) + 1
		if screen != Screen.LOCAL:
			break
		if int(local.get("deadlocks", 0)) > deadlocks_before:
			_stop_test_battery("Test battery stopped on deadlock after %d ticks." % int(local.get("test_battery_ticks", 0)), true)
			break
		var no_route_reason := _first_test_failure_reason()
		if no_route_reason != "":
			_stop_test_battery("Test battery stopped: %s" % no_route_reason, true)
			break
	if screen == Screen.LOCAL:
		if bool(local.get("test_battery_running", false)):
			local_message = "Test battery running: %d ticks, %d steps/frame." % [int(local.get("test_battery_ticks", 0)), int(local.get("test_battery_steps", 0))]
		_update_status_labels()
		_refresh_local_side_text()

func _first_test_failure_reason() -> String:
	for t in trains:
		if String(t.get("state", "")) == "NoRoute":
			var reason := String(t.get("wait_reason", "No legal route."))
			if reason == "":
				reason = "No legal route."
			return "%s has no route. %s" % [String(t.get("id", "Train")), reason]
	return ""

func _return_to_region() -> void:
	if screen == Screen.LOCAL and not local.is_empty():
		local["test_battery_running"] = false
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
		"first_output_time": -1.0,
		"last_output_time": 0.0,
		"max_output_gap": 0.0,
		"unqualified_output": 0,
		"detour_output": 0,
		"detour_stops": 0,
		"detour_dwell": 0.0,
		"excess_mileage": 0,
		"excess_mileage_output": 0,
		"service_mileage": 0.0,
		"empty_mileage": 0.0,
		"steel_buffer": 0,
		"coal_buffer": 0,
		"processor_feed": 0,
		"processor_export": 0,
		"production_remainder": 0.0,
		"storage": {},
		"infra_cost": 0,
		"elapsed_time": 0.0,
		"train_vouchers": _upgrade_level("train_voucher"),
		"deadlocks": 0,
		"max_queue": 0,
		"paused": true,
		"speed": 1.0,
		"test_battery_running": false,
		"test_battery_steps": TEST_BATTERY_START_STEPS,
		"test_battery_ramp_elapsed": 0.0,
		"test_battery_ticks": 0,
		"test_battery_last_deadlocks": 0,
		"route_toggle": false,
		"order_mode": bool(scenario.get("order_mode", false)),
		"orders": (scenario.get("orders", []) as Array).duplicate(true),
		"order_progress": {},
		"order_in_transit": {},
		"late_orders": 0,
		"late_order_amount": 0,
		"incompatible_stops": 0,
		"wrong_service_loads": 0,
		"flow_scores": {},
		"debug_details_open": false,
		"scenario": scenario
	}
	for st in scenario["stations"]:
		var copy: Dictionary = st.duplicate(true)
		copy["stored"] = 240 if copy.get("role", "") == "source" else 0
		copy["base_platforms"] = int(copy.get("platforms", 1))
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
	if size.x >= 900.0:
		var tutorial_ids := ["coal_valley", "central_yard", "steelworks", "overtake_pass"]
		var tutorial_index := tutorial_ids.find(id)
		if tutorial_index >= 0:
			var rail_width := _regional_tutorial_rail_width()
			return Vector2(max(_scaled(58.0), rail_width * 0.52), _regional_map_top_margin() + _scaled(58.0) + float(tutorial_index) * _scaled(104.0))
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
	var right_limit: float = size.x - _regional_side_panel_width() - _scaled(24.0)
	var left_limit: float = max(_scaled(24.0), _regional_tutorial_rail_width() + _scaled(8.0))
	var available_width: float = max(_scaled(420.0), right_limit - left_limit - _scaled(16.0))
	return Vector2(left_limit + max(0.0, (available_width - map_size.x) * 0.5), _regional_map_top_margin())

func _regional_draw_tile_size() -> float:
	var left_reserve := _regional_tutorial_rail_width()
	var right_limit: float = max(_scaled(420.0), size.x - _regional_side_panel_width() - left_reserve - _scaled(48.0))
	var available_height: float = max(_scaled(320.0), size.y - _regional_map_top_margin() - _scaled(18.0))
	var max_tile_from_width: float = right_limit / float(REGIONAL_GRID.x)
	var max_tile_from_height: float = available_height / float(REGIONAL_GRID.y)
	return clamp(floor(min(max_tile_from_width, max_tile_from_height)), REGIONAL_TILE_MIN, REGIONAL_TILE_MAX * _ui_scale())

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
	var top_reserved: float = _scaled(36.0 if size.x >= 1600.0 and size.y >= 900.0 else 52.0)
	var bottom_reserved: float = _local_tray_height() + _scaled(8.0)
	var horizontal_margin: float = clamp(size.x * 0.025, _scaled(16.0), _scaled(48.0))
	var max_cell_from_width: float = (size.x - horizontal_margin * 2.0) / float(grid.x)
	var max_cell_from_height: float = (size.y - top_reserved - bottom_reserved) / float(grid.y)
	var fit_cell: float = floor(max(12.0, min(max_cell_from_width, max_cell_from_height)))
	cell_size = clamp(fit_cell, 12.0, LOCAL_CELL_MAX * _ui_scale())
	var board_width: float = float(grid.x) * cell_size
	var origin_x: float = max(horizontal_margin, (size.x - board_width) * 0.5)
	grid_origin = Vector2(origin_x, top_reserved)

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
	if not signals.has(pos):
		return {}
	return _signal_dir_map_from_value(signals.get(pos, {}))

func _signal_dir_map_from_value(signal_value: Variant) -> Dictionary:
	var dir_map: Dictionary = {}
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
		if not _signal_budget_allows_change(pos, signal_type, [dir]):
			return
		_replace_signal_set(pos, signal_type, [dir])
		local_message = "%s signal set to single. Use Rotate Sig to change facing." % signal_type.capitalize()
	else:
		var paired_dirs := _paired_signal_dirs(pos)
		if not _signal_budget_allows_change(pos, signal_type, paired_dirs):
			return
		_replace_signal_set(pos, signal_type, paired_dirs)
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
		var rotated_pair: Array[Vector2i] = [next_dir, _opposite_dir(next_dir)]
		if not _signal_budget_allows_change(pos, _signal_type(pos), rotated_pair):
			return
		_replace_signal_set(pos, _signal_type(pos), rotated_pair)
	else:
		if not _signal_budget_allows_change(pos, _signal_type(pos), [next_dir]):
			return
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
	var new_segments := _new_track_segments_for_path(from_cell, to_cell)
	if not _track_budget_allows_added_segments(new_segments):
		return
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
		if not _signal_budget_allows_change(gp, signal_type, _signal_dirs(gp)):
			return
		_replace_signal_set(gp, signal_type, _signal_dirs(gp))
		selected_signal_pos = gp
		local_message = "Signal changed to %s. Click again to toggle single or double." % signal_type
		_compute_blocks()
		return
	if not _signal_budget_allows_change(gp, signal_type, [_default_signal_dir(gp)]):
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
		var existing_pair_dirs := _paired_signal_dirs(gp)
		if not _signal_budget_allows_change(gp, signal_type, existing_pair_dirs):
			return
		_replace_signal_set(gp, signal_type, existing_pair_dirs)
		selected_signal_pos = gp
		local_message = "Paired %s signal set. Rotate Sig changes the protected axis." % signal_type
		_compute_blocks()
		return
	var pair_dirs := _paired_signal_dirs(gp)
	if not _signal_budget_allows_change(gp, signal_type, pair_dirs):
		return
	if _spend(money_cost):
		_clear_erased_signal_target(gp)
		_set_signal(gp, signal_type, _default_signal_dir(gp))
		_replace_signal_set(gp, signal_type, pair_dirs)
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

func _line_ids_for_station_context(station_id: String) -> Array[String]:
	var matches: Array[String] = []
	for raw_line_id in lines.keys():
		var line_id := String(raw_line_id)
		var line: Dictionary = lines[line_id]
		var route: Array = line.get("route", [])
		if route.has(station_id) or _source_id_for_line(line) == station_id:
			matches.append(line_id)
	matches.sort()
	return matches

func _line_id_for_station_context(station_id: String) -> String:
	var matches := _line_ids_for_station_context(station_id)
	if matches.is_empty():
		return ""
	if selected_line_id != "" and matches.has(selected_line_id):
		return selected_line_id
	return matches[0]

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

func _edit_line_from_picker(line_id: String) -> void:
	if not lines.has(line_id):
		return
	_start_service_edit(line_id)

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
		"service_class": _service_class_for_route(route),
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

func _service_class_for_route(route: Array) -> String:
	if route.is_empty():
		return "light_freight"
	var source_id := String(route[0])
	for order in local.get("scenario", {}).get("orders", []):
		var order_data: Dictionary = order
		if String(order_data.get("origin", "")) == source_id:
			return String(order_data.get("service_class", _service_class_for_cargo(String(order_data.get("cargo", "")))))
	if station_by_id.has(source_id):
		var st: Dictionary = station_by_id[source_id]
		var produced := String(st.get("produces", ""))
		if produced != "":
			return _service_class_for_cargo(produced)
	return "light_freight"

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
	var car_count := _scenario_train_car_count()
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
		"train_class": "light_freight",
		"current_order_id": "",
		"loaded_order_id": "",
		"capacity": 40 * car_count,
		"car_count": car_count,
		"speed": 150.0 / (1.0 + float(car_count - 1) * 0.12),
		"dir": Vector2.RIGHT,
		"state": "Available" if line_id == "" else "Idle",
		"wait_reason": "",
		"wait_time": 0.0,
		"total_wait": 0.0,
		"dwell": 0.0,
		"handled_yard": false,
		"contract_trip_visited": [],
		"contract_trip_distance": 0,
		"productive_output": 0
	}

func _apply_train_class_stats(t: Dictionary, train_class: String) -> void:
	t["train_class"] = train_class
	var car_count: int = max(1, int(t.get("car_count", 1)))
	if train_class == "passenger_express":
		t["capacity"] = 54
		t["speed"] = 188.0
		t["class_dwell"] = 0.55
	elif train_class == "passenger_local":
		t["capacity"] = 72
		t["speed"] = 164.0
		t["class_dwell"] = 0.72
	elif train_class == "heavy_freight":
		t["capacity"] = 64 * car_count
		t["speed"] = 126.0 / (1.0 + float(car_count - 1) * 0.18)
		t["class_dwell"] = 1.25
	else:
		t["capacity"] = 40 * car_count
		t["speed"] = 150.0 / (1.0 + float(car_count - 1) * 0.12)
		t["class_dwell"] = 0.82

func _buy_available_train() -> void:
	if not _train_budget_allows_add():
		_refresh_local_side_text()
		return
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
			t["contract_trip_visited"] = []
			t["contract_trip_distance"] = 0
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
		local_message = "%s complete. %s" % [lines[selected_line_id]["name"], _line_service_plan_verdict(selected_line_id, false)]
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
	lines[selected_line_id]["service_class"] = _service_class_for_route(route)
	_reapply_line_to_assigned_trains(selected_line_id)
	local_message = "Added %s to %s." % [station_by_id[station_id]["name"], lines[selected_line_id]["name"]]

func _line_has_valid_orders(line_id: String) -> bool:
	return lines.has(line_id) and (lines[line_id].get("route", []) as Array).size() >= 2

func _line_contract_ready(line_id: String) -> bool:
	if not lines.has(line_id):
		return false
	return _route_contract_ready(lines[line_id].get("route", []))

func _train_route_contract_ready(t: Dictionary) -> bool:
	return _route_contract_ready(t.get("route", []))

func _route_contract_ready(route: Array) -> bool:
	var required := _contract_required_stops_for_route(route)
	if required.size() < 2:
		return route.size() >= 2
	return _route_contains_required_stops_in_order(route, required)

func _contract_required_stops_for_route(route: Array) -> Array[String]:
	var required: Array[String] = []
	if route.is_empty() or local.is_empty() or not local.has("scenario"):
		return required
	var source_id := String(route[0])
	var contract_route: Array = _route_for_source(source_id)
	if contract_route.is_empty():
		return required
	for raw_id in contract_route:
		var station_id := String(raw_id)
		if not required.has(station_id):
			required.append(station_id)
	return required

func _contract_required_stops_for_delivery(route: Array, delivery_station_id: String) -> Array[String]:
	var required: Array[String] = []
	if route.is_empty() or delivery_station_id == "":
		return _contract_required_stops_for_route(route)
	var source_id := String(route[0])
	var contract_route: Array = _route_for_source(source_id)
	if contract_route.is_empty():
		return required
	for raw_id in contract_route:
		var station_id := String(raw_id)
		if not required.has(station_id):
			required.append(station_id)
		if station_id == delivery_station_id:
			return required
	return _contract_required_stops_for_route(route)

func _route_contains_required_stops_in_order(route: Array, required: Array[String]) -> bool:
	var required_index := 0
	for raw_id in route:
		if required_index >= required.size():
			return true
		if String(raw_id) == required[required_index]:
			required_index += 1
	return required_index >= required.size()

func _contract_missing_stop_names_for_route(route: Array) -> Array[String]:
	var missing: Array[String] = []
	var required := _contract_required_stops_for_route(route)
	if required.is_empty():
		return missing
	for station_id in required:
		if not route.has(station_id):
			missing.append(_station_name(String(station_id)))
	if missing.is_empty() and not _route_contains_required_stops_in_order(route, required):
		missing.append("contract order: %s" % _route_station_names(required))
	return missing

func _line_service_plan_verdict(line_id: String, bbcode: bool = true) -> String:
	if line_id == "" or not lines.has(line_id):
		return ""
	var route: Array = lines[line_id].get("route", [])
	if route.size() < 2:
		return "Service plan: add at least two stops before trains can run."
	if _uses_order_mode():
		var incompatible := _line_incompatible_stop_count(line_id)
		if incompatible > 0:
			return _verdict_text("orange", "Service plan: %s has %d incompatible stop%s. Split passenger and freight flows for Gold." % [
				String(lines[line_id].get("service_class", "service")).replace("_", " "),
				incompatible,
				"" if incompatible == 1 else "s"
			], bbcode)
	if not _route_contract_ready(route):
		var missing := ", ".join(_contract_missing_stop_names_for_route(route))
		return _verdict_text("orange", "Service plan: sandbox only - trains can move cargo, but contract output stays inactive until you add %s." % missing, bbcode)
	var detour_count: int = _contract_route_detour_stop_names(route).size()
	var extra_orders: int = _route_extra_order_stop_count(route)
	var repeat_orders: int = _route_repeated_stop_count(route)
	if detour_count > 0 or extra_orders > 0 or repeat_orders > 0:
		var pressure: Array[String] = []
		if detour_count > 0:
			pressure.append("%d detour stop%s" % [detour_count, "" if detour_count == 1 else "s"])
		if extra_orders > 0:
			pressure.append("%d extra scheduled stop%s" % [extra_orders, "" if extra_orders == 1 else "s"])
		if repeat_orders > 0:
			pressure.append("%d repeated stop%s" % [repeat_orders, "" if repeat_orders == 1 else "s"])
		return _verdict_text("orange", "Service plan: contract-valid, but %s will pressure grade and bonus. Keep the loop if it solves congestion; trim it for mastery." % ", ".join(pressure), bbcode)
	return _verdict_text("green", "Service plan: contract-ready clean loop. This line can score output and chase Gold/bonus.", bbcode)

func _verdict_text(color: String, text: String, bbcode: bool) -> String:
	if not bbcode:
		return text
	return "[color=%s]%s[/color]" % [color, text]

func _station_name(station_id: String) -> String:
	if station_by_id.has(station_id):
		return String(station_by_id[station_id].get("name", station_id))
	return station_id

func _start_contract_trip(t: Dictionary, st: Dictionary) -> void:
	t["contract_trip_visited"] = []
	t["contract_trip_distance"] = 0
	_mark_contract_trip_visit(t, st)

func _mark_contract_trip_visit(t: Dictionary, st: Dictionary) -> void:
	var station_id := String(st.get("id", ""))
	if station_id == "":
		return
	var visited: Array = t.get("contract_trip_visited", [])
	if visited.is_empty() or String(visited[visited.size() - 1]) != station_id:
		visited.append(station_id)
	t["contract_trip_visited"] = visited

func _clear_contract_trip(t: Dictionary) -> void:
	t["contract_trip_visited"] = []
	t["contract_trip_distance"] = 0

func _train_contract_output_ready(t: Dictionary, delivery_station_id: String) -> bool:
	if not _train_route_contract_ready(t):
		return false
	var route: Array = t.get("route", [])
	var required := _contract_required_stops_for_delivery(route, delivery_station_id)
	if required.size() < 2:
		return true
	var visited: Array = t.get("contract_trip_visited", [])
	return _route_contains_required_stops_in_order(visited, required)

func _contract_missing_trip_stop_names(t: Dictionary, delivery_station_id: String) -> Array[String]:
	var missing: Array[String] = _contract_missing_stop_names_for_route(t.get("route", []))
	if not missing.is_empty():
		return missing
	var required := _contract_required_stops_for_delivery(t.get("route", []), delivery_station_id)
	var visited: Array = t.get("contract_trip_visited", [])
	for station_id in required:
		if not visited.has(station_id):
			missing.append(_station_name(String(station_id)))
	if missing.is_empty() and not _route_contains_required_stops_in_order(visited, required):
		missing.append("trip order: %s" % _route_station_names(required))
	return missing

func _contract_delivery_station_id_for_route(route: Array) -> String:
	if route.is_empty():
		return ""
	var contract_route: Array = _route_for_source(String(route[0]))
	for raw_id in contract_route:
		var station_id := String(raw_id)
		if station_by_id.has(station_id) and String((station_by_id[station_id] as Dictionary).get("role", "")) == "sink":
			return station_id
	var required := _contract_required_stops_for_route(route)
	if required.size() >= 2:
		return required[required.size() - 1]
	return ""

func _contract_trip_detour_stop_count(t: Dictionary, delivery_station_id: String) -> int:
	var route: Array = t.get("route", [])
	var required := _contract_required_stops_for_delivery(route, delivery_station_id)
	if required.size() < 2:
		return 0
	var visited: Array = t.get("contract_trip_visited", [])
	return _detour_stop_count_for_visit_sequence(visited, required, delivery_station_id)

func _loaded_contract_visit_would_detour(t: Dictionary, st: Dictionary) -> bool:
	if int(t.get("cargo_amount", 0)) <= 0:
		return false
	var station_id := String(st.get("id", ""))
	if station_id == "":
		return false
	var route: Array = t.get("route", [])
	var delivery_station_id := _contract_delivery_station_id_for_route(route)
	if station_id == delivery_station_id:
		return false
	var required := _contract_required_stops_for_delivery(route, delivery_station_id)
	if required.size() < 2:
		return false
	var required_index := 0
	var visited: Array = t.get("contract_trip_visited", [])
	for raw_id in visited:
		var visited_id := String(raw_id)
		if required_index < required.size() and visited_id == required[required_index]:
			required_index += 1
	return required_index >= required.size() or station_id != required[required_index]

func _apply_contract_detour_dwell(t: Dictionary, st: Dictionary) -> void:
	if not _loaded_contract_visit_would_detour(t, st):
		return
	t["dwell"] = max(float(t.get("dwell", 0.0)), CONTRACT_DETOUR_DWELL)
	t["dwell_state"] = "DetourStop"
	local["detour_dwell"] = float(local.get("detour_dwell", 0.0)) + CONTRACT_DETOUR_DWELL
	local_message = "%s is spending extra time at an unnecessary loaded stop." % String(t.get("name", t.get("id", "Train")))

func _contract_trip_excess_mileage(t: Dictionary, delivery_station_id: String) -> int:
	var route: Array = t.get("route", [])
	var required := _contract_required_stops_for_delivery(route, delivery_station_id)
	if required.size() < 2:
		return 0
	var expected_distance := _contract_required_trip_distance(required)
	if expected_distance <= 0.0:
		return 0
	var generous_allowance: float = expected_distance * 1.45 + 3.0
	var actual_distance: float = float(t.get("contract_trip_distance", 0.0))
	return max(0, int(floor(actual_distance - generous_allowance)))

func _contract_required_trip_distance(required: Array[String]) -> float:
	var total := 0.0
	for i in range(required.size() - 1):
		var from_id := String(required[i])
		var to_id := String(required[i + 1])
		if not station_by_id.has(from_id) or not station_by_id.has(to_id):
			continue
		var from_pos: Vector2i = station_by_id[from_id].get("pos", Vector2i.ZERO)
		var to_pos: Vector2i = station_by_id[to_id].get("pos", Vector2i.ZERO)
		var delta := to_pos - from_pos
		total += abs(delta.x) + abs(delta.y)
	return total

func _detour_stop_count_for_visit_sequence(visited: Array, required: Array[String], delivery_station_id: String = "") -> int:
	if required.is_empty():
		return 0
	var required_index := 0
	var detours := 0
	for raw_id in visited:
		var station_id := String(raw_id)
		if required_index < required.size() and station_id == required[required_index]:
			required_index += 1
		else:
			detours += 1
		if delivery_station_id != "" and station_id == delivery_station_id:
			break
	return detours

func _contract_route_detour_stop_names(route: Array) -> Array[String]:
	var names: Array[String] = []
	var delivery_station_id := _contract_delivery_station_id_for_route(route)
	var required := _contract_required_stops_for_delivery(route, delivery_station_id)
	if delivery_station_id == "" or required.size() < 2 or not _route_contains_required_stops_in_order(route, required):
		return names
	var required_index := 0
	for raw_id in route:
		var station_id := String(raw_id)
		var is_required_next := required_index < required.size() and station_id == required[required_index]
		if is_required_next:
			required_index += 1
		elif not names.has(_station_name(station_id)):
			names.append(_station_name(station_id))
		if station_id == delivery_station_id:
			break
	return names

func _route_extra_order_stop_count(route: Array) -> int:
	if route.is_empty():
		return 0
	var contract_route: Array = _route_for_source(String(route[0]))
	if contract_route.is_empty():
		return 0
	return max(0, route.size() - contract_route.size())

func _route_repeated_stop_count(route: Array) -> int:
	if route.size() < 2:
		return 0
	var source_id := String(route[0])
	var contract_route: Array = _route_for_source(source_id)
	var allowed: Dictionary = {}
	for raw_contract_id in contract_route:
		var contract_id := String(raw_contract_id)
		allowed[contract_id] = int(allowed.get(contract_id, 0)) + 1
	var seen: Dictionary = {}
	var repeats := 0
	for raw_id in route:
		var station_id := String(raw_id)
		if station_id == source_id:
			seen[station_id] = int(seen.get(station_id, 0)) + 1
			continue
		var used := int(seen.get(station_id, 0)) + 1
		seen[station_id] = used
		var allowed_uses := int(allowed.get(station_id, 1))
		if used > allowed_uses:
			repeats += 1
	return repeats

func _active_route_bloat_score() -> int:
	var extra := 0
	for line_id in lines.keys():
		if _line_train_count(String(line_id)) <= 0:
			continue
		extra += _route_extra_order_stop_count(lines[line_id].get("route", []))
	return extra

func _active_route_repeat_score() -> int:
	var repeats := 0
	for line_id in lines.keys():
		if _line_train_count(String(line_id)) <= 0:
			continue
		repeats += _route_repeated_stop_count(lines[line_id].get("route", []))
	return repeats

func _active_incompatible_stop_score() -> int:
	var score := int(local.get("incompatible_stops", 0)) + int(local.get("wrong_service_loads", 0))
	for line_id in lines.keys():
		if _line_train_count(String(line_id)) <= 0:
			continue
		score += _line_incompatible_stop_count(String(line_id))
	return score

func _line_incompatible_stop_count(line_id: String) -> int:
	if line_id == "" or not lines.has(line_id):
		return 0
	var line: Dictionary = lines[line_id]
	var service_class := String(line.get("service_class", "light_freight"))
	var route: Array = line.get("route", [])
	var count := 0
	for raw_station_id in route:
		var station_id := String(raw_station_id)
		if not station_by_id.has(station_id):
			continue
		var station: Dictionary = station_by_id[station_id]
		var station_classes: Array = station.get("service_classes", [])
		if not station_classes.is_empty() and not station_classes.has(service_class):
			var compatible_domain := false
			for station_class in station_classes:
				if _service_class_domain(String(station_class)) == _service_class_domain(service_class):
					compatible_domain = true
					break
			if not compatible_domain:
				count += 1
	return count

func _platform_padding_score() -> int:
	var added := 0
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		added += max(0, int(st.get("platforms", 1)) - int(st.get("base_platforms", st.get("platforms", 1))))
	var allowance: int = max(1, int(ceil(float(_fleet_goal()) * 0.5)))
	if String(local.get("kind", "")) == "yard":
		allowance += 1
	return max(0, added - allowance)

func _contributing_train_count() -> int:
	var count := 0
	for t in trains:
		if int(t.get("productive_output", 0)) > 0:
			count += 1
	return count

func _fleet_contribution_shortfall() -> int:
	if _completion_progress() <= 0:
		return 0
	return max(0, _fleet_goal() - _contributing_train_count())

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
	text += "%s\n" % _line_service_plan_verdict(line_id)
	var sc: Dictionary = local.get("scenario", {})
	var passing_status := _passing_capacity_status_text(sc)
	if passing_status != "":
		text += "%s\n" % passing_status
	var junction_status := _junction_chain_status_text(sc)
	if junction_status != "":
		text += "%s\n" % junction_status
	var efficiency_status := _efficiency_proof_status_text(sc)
	if efficiency_status != "":
		text += "%s\n" % efficiency_status
	var processor_status := _processor_proof_status_text(sc)
	if processor_status != "":
		text += "%s\n" % processor_status
	if not _route_contract_ready(route):
		text += "[color=orange]Contract output inactive[/color]: add %s.\n" % ", ".join(_contract_missing_stop_names_for_route(route))
	else:
		var detour_names := _contract_route_detour_stop_names(route)
		if not detour_names.is_empty():
			text += "[color=orange]Detour pressure[/color]: %s before delivery will lower grade.\n" % ", ".join(detour_names)
		var extra_orders := _route_extra_order_stop_count(route)
		if extra_orders > 0:
			text += "[color=orange]Route discipline[/color]: %d extra scheduled stops beyond the contract loop will lower grade.\n" % extra_orders
		var repeat_orders := _route_repeated_stop_count(route)
		if repeat_orders > 0:
			text += "[color=orange]Catch-all pressure[/color]: %d repeated stops create backtracking; split focused services for mastery.\n" % repeat_orders
		text += "%s\n" % _line_pressure_preview_text(line_id)
	var kind: String = local.get("kind", "")
	if _uses_order_mode():
		text += "Service class: %s. Compatible orders: %s.\n" % [
			String(line.get("service_class", "light_freight")).replace("_", " ").capitalize(),
			_line_order_summary(line_id)
		]
	elif kind == "coal":
		text += "Expected cargo: coal from %s to %s.\n" % [station_by_id[route[0]]["name"], station_by_id[route[1]]["name"]]
	elif kind == "yard":
		text += "Expected cargo: freight loads at source stops and unloads at sink stops. Yard stops add dwell time if the line includes them.\n"
	elif kind == "steel":
		text += "Expected cargo: coal to Steelworks, then steel to Export Platform.\n"
	else:
		text += "Expected cargo follows station production and acceptance.\n"
	var clause_text := _contract_clause_text(local.get("scenario", {}))
	if clause_text != "":
		text += "%s\n" % clause_text
	text += "%s\n" % _completion_grade_target_text(local.get("scenario", {}))
	text += "%s\n" % _fleet_preview_text()
	text += "Assigned trains: %d\nAvailable trains: %d" % [_line_train_count(line_id), _available_train_count()]
	return text

func _line_pressure_preview_text(line_id: String) -> String:
	if line_id == "" or not lines.has(line_id):
		return ""
	var route: Array = lines[line_id].get("route", [])
	if route.size() < 2 or not _route_contract_ready(route):
		return ""
	var sc: Dictionary = local.get("scenario", {})
	var detour_count: int = _contract_route_detour_stop_names(route).size()
	var route_extra: int = _route_extra_order_stop_count(route)
	var route_repeats: int = _route_repeated_stop_count(route)
	var fleet_extra: int = max(0, _active_train_count() - _fleet_goal())
	var passing_status := _passing_capacity_status_text(sc)
	var passing_missing := _passing_capacity_missing(sc)
	var junction_status := _junction_chain_status_text(sc)
	var junction_missing := _junction_chain_missing(sc)
	var efficiency_status := _efficiency_proof_status_text(sc)
	var efficiency_missing := _efficiency_proof_missing(sc)
	var processor_status := _processor_proof_status_text(sc)
	var processor_missing := _processor_proof_missing(sc)
	var sprawl_score := _network_sprawl_score(sc)
	var incompatible := _line_incompatible_stop_count(line_id)
	if detour_count == 0 and route_extra == 0 and route_repeats == 0 and fleet_extra <= 1 and passing_missing <= 0 and junction_missing <= 0 and efficiency_missing <= 0 and processor_missing <= 0 and sprawl_score <= 0 and incompatible <= 0:
		return "Preview pressure: clean route shape; keep fleet near target."
	var parts: Array[String] = []
	if detour_count > 0:
		parts.append("Detours %d" % detour_count)
	if route_extra > 0:
		parts.append("Route +%d" % route_extra)
	if route_repeats > 0:
		parts.append("Repeat +%d" % route_repeats)
	if fleet_extra > 1:
		parts.append("Fleet +%d" % fleet_extra)
	if passing_missing > 0:
		parts.append("Signals %d/%d" % [_signal_gate_count(), _passing_capacity_target(sc)])
	if junction_missing > 0:
		parts.append("Chain %d/%d" % [_chain_signal_gate_count(), _junction_chain_target(sc)])
	if efficiency_missing > 0:
		parts.append("Lean proof")
	if processor_missing > 0:
		parts.append("Processor %d/2" % max(0, 2 - processor_missing))
	if sprawl_score > 0:
		parts.append("Rail +%d" % sprawl_score)
	if incompatible > 0:
		parts.append("Mixed stops +%d" % incompatible)
	var inspection_note := ""
	if not parts.is_empty() and _is_run_scenario_id(String(sc.get("id", ""))):
		inspection_note = " Future inspection risk if this clears rough."
	if passing_status != "" and passing_missing <= 0:
		return "Preview pressure: clean route shape; %s" % passing_status
	if junction_status != "" and junction_missing <= 0:
		return "Preview pressure: clean route shape; %s" % junction_status
	if efficiency_status != "" and efficiency_missing <= 0:
		return "Preview pressure: clean route shape; %s" % efficiency_status
	if processor_status != "" and processor_missing <= 0:
		return "Preview pressure: clean route shape; %s" % processor_status
	return "Preview pressure: %s will lower grade.%s" % [", ".join(parts), inspection_note]

func _line_order_summary(line_id: String) -> String:
	if line_id == "" or not lines.has(line_id):
		return "none"
	var labels: Array[String] = []
	for order in local.get("orders", []):
		var data: Dictionary = order
		if _line_can_serve_order(line_id, data):
			labels.append("%s %d" % [_resource_name(String(data.get("cargo", ""))), _order_remaining_amount(data)])
	if labels.is_empty():
		return "none"
	return ", ".join(labels)

func _fleet_preview_text() -> String:
	var active: int = _active_train_count()
	var goal: int = _fleet_goal()
	var extra: int = max(0, active - goal)
	if active < goal:
		return "Fleet preview: add %d train%s to meet contract target; output counts, but the contract clear waits for full service." % [goal - active, "" if goal - active == 1 else "s"]
	if extra <= 0:
		return "Fleet preview: right-sized fleet for this contract."
	if extra == 1:
		return "Fleet preview: one comfort train is fine; more will slow dispatch."
	return "Fleet preview: dispatch overload at %.0f%% speed. Return extra trains to protect grade." % (_dispatch_speed_factor() * 100.0)

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
			var status := "%s | %d stops | %d trains" % [_train_class_label(String(line.get("service_class", ""))), route.size(), _line_train_count(line_id)]
			if route.size() < 2:
				status = "needs stops"
			elif not _route_contract_ready(route):
				status = "missing contract stop"
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
			var label := "%s  %s  %s\n%s  %s%s" % [train_id, _train_class_label(String(t.get("train_class", ""))), cargo_text, state_label, _short_ui_text(line_label, 22), next_label]
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
		t["cargo"] = ""
		t["cargo_amount"] = 0
		t["current_order_id"] = ""
		t["loaded_order_id"] = ""
		t["contract_trip_visited"] = []
		t["contract_trip_distance"] = 0
		t["productive_output"] = 0
		t["state"] = "WaitingForOrders"
		t["wait_reason"] = "Line needs at least two stops."
		t["tile"] = _off_map_tile()
		t["pos"] = Vector2(-1000, -1000)
		return
	var route: Array = (lines[line_id]["route"] as Array).duplicate()
	t["line_id"] = line_id
	t["route"] = route
	_apply_train_class_stats(t, String(lines[line_id].get("service_class", _service_class_for_route(route))))
	t["stop_index"] = 1
	t["tile"] = _off_map_tile()
	t["pos"] = Vector2(-1000, -1000)
	t["path"] = []
	t["path_index"] = 0
	t["cargo"] = ""
	t["cargo_amount"] = 0
	t["current_order_id"] = ""
	t["loaded_order_id"] = ""
	t["contract_trip_visited"] = []
	t["contract_trip_distance"] = 0
	t["productive_output"] = 0
	t["state"] = "WaitingForPlatform"
	t["wait_reason"] = "Queued in depot until the line's first platform and exit path are clear."
	t["wait_time"] = 0.0
	t["dwell"] = 0.0
	t["handled_yard"] = false
	_try_dispatch_train_from_depot(t)
	queue_redraw()

func _restart_trains_only() -> void:
	if bool(local.get("test_battery_running", false)):
		_stop_test_battery("Test battery stopped for train reset.", true)
	var selected_exists := false
	selected_signal_pos = Vector2i(-999, -999)
	local["delivered"] = 0
	local["processed"] = 0
	local["productive_progress"] = 0
	local["unqualified_output"] = 0
	local["order_progress"] = {}
	local["order_in_transit"] = {}
	local["late_orders"] = 0
	local["late_order_amount"] = 0
	local["incompatible_stops"] = 0
	local["wrong_service_loads"] = 0
	local["flow_scores"] = {}
	local["steel_buffer"] = 0
	local["coal_buffer"] = 0
	local["processor_feed"] = 0
	local["processor_export"] = 0
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
	t["current_order_id"] = ""
	t["loaded_order_id"] = ""
	t["contract_trip_visited"] = []
	t["contract_trip_distance"] = 0
	t["productive_output"] = 0
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
		_apply_train_class_stats(t, String(lines[line_id].get("service_class", _service_class_for_route(t["route"]))))
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
	if typeof(sc.get("service_routes", {})) == TYPE_DICTIONARY:
		var service_routes: Dictionary = sc.get("service_routes", {})
		if service_routes.has(source_id):
			return (service_routes[source_id] as Array).duplicate()
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
	if spend_money and not _train_budget_allows_add():
		return
	if spend_money and not _spend(300, 0):
		return
	var start_station: Dictionary = station_by_id[route[0]]
	var t := _new_train_record(start_station["pos"])
	t["line_id"] = line_id
	t["route"] = route
	_apply_train_class_stats(t, String(lines[line_id].get("service_class", _service_class_for_route(route))))
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
	t["current_order_id"] = ""
	t["loaded_order_id"] = ""
	t["contract_trip_visited"] = []
	t["contract_trip_distance"] = 0
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

func _is_resource_puzzle(sc: Dictionary = {}) -> bool:
	var source := sc
	if source.is_empty() and not local.is_empty():
		source = local.get("scenario", {})
	return String(source.get("resource_mode", "")) == "limited" and typeof(source.get("resource_budget", {})) == TYPE_DICTIONARY

func _resource_budget(sc: Dictionary = {}) -> Dictionary:
	var source := sc
	if source.is_empty() and not local.is_empty():
		source = local.get("scenario", {})
	if typeof(source.get("resource_budget", {})) == TYPE_DICTIONARY:
		return source.get("resource_budget", {})
	return {}

func _track_piece_count() -> int:
	return track_segments.size()

func _new_track_segments_for_path(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var additions: Dictionary = {}
	var last_valid := Vector2i(-999, -999)
	for p in _grid_drag_path(from_cell, to_cell):
		if not _is_in_grid(p):
			continue
		if not tracks.has(p) and _terrain_blocks_track(p):
			break
		if _is_in_grid(last_valid):
			var key := _segment_key(last_valid, p)
			if not track_segments.has(key):
				additions[key] = true
		last_valid = p
	return additions.size()

func _track_budget_allows_added_segments(new_segments: int) -> bool:
	if new_segments <= 0 or not _is_resource_puzzle():
		return true
	var budget := _resource_budget()
	var track_budget: int = int(budget.get("track", 0))
	if track_budget <= 0:
		return true
	var used := _track_piece_count()
	if used + new_segments <= track_budget:
		return true
	local_message = "Track inventory full: %d/%d pieces used. Erase unused rail or choose a shorter route." % [used, track_budget]
	return false

func _signal_piece_counts_for(signal_map: Dictionary) -> Dictionary:
	var counts := {"signals": 0, "block": 0, "chain": 0}
	for pos in signal_map.keys():
		var dir_map := _signal_dir_map_from_value(signal_map[pos])
		for key in dir_map.keys():
			var signal_type := String(dir_map[key])
			counts["signals"] = int(counts.get("signals", 0)) + 1
			counts[signal_type] = int(counts.get(signal_type, 0)) + 1
	return counts

func _current_signal_piece_counts() -> Dictionary:
	return _signal_piece_counts_for(signals)

func _signal_budget_allows_map(signal_map: Dictionary) -> bool:
	if not _is_resource_puzzle():
		return true
	var budget := _resource_budget()
	var counts := _signal_piece_counts_for(signal_map)
	for key in ["signals", "block", "chain"]:
		var limit: int = int(budget.get(key, 0))
		if limit > 0 and int(counts.get(key, 0)) > limit:
			local_message = "%s signal inventory full: %d/%d used. Remove or convert signals to fit the puzzle budget." % [key.capitalize(), int(counts.get(key, 0)), limit]
			return false
	return true

func _signal_budget_allows_change(pos: Vector2i, signal_type: String, dirs: Array[Vector2i]) -> bool:
	if not _is_resource_puzzle():
		return true
	var dir_map := {}
	for dir in dirs:
		dir_map[_dir_key(dir)] = signal_type
	var proposed := signals.duplicate(true)
	proposed[pos] = {
		"type": signal_type,
		"dir": dirs[0] if not dirs.is_empty() else Vector2i.RIGHT,
		"dirs": dir_map
	}
	return _signal_budget_allows_map(proposed)

func _train_budget_allows_add() -> bool:
	if not _is_resource_puzzle():
		return true
	var train_budget: int = int(_resource_budget().get("trains", 0))
	if train_budget <= 0:
		return true
	if trains.size() < train_budget:
		return true
	local_message = "Train inventory full: %d/%d trains. Use longer trains or a leaner service." % [trains.size(), train_budget]
	return false

func _puzzle_resource_usage() -> Dictionary:
	var signal_counts := _current_signal_piece_counts()
	return {
		"track": _track_piece_count(),
		"signals": int(signal_counts.get("signals", 0)),
		"block": int(signal_counts.get("block", 0)),
		"chain": int(signal_counts.get("chain", 0)),
		"trains": trains.size()
	}

func _puzzle_resource_spare(sc: Dictionary = {}) -> Dictionary:
	var budget := _resource_budget(sc)
	var used := _puzzle_resource_usage()
	var spare := {}
	for key in ["track", "signals", "block", "chain", "trains"]:
		if budget.has(key):
			spare[key] = int(budget.get(key, 0)) - int(used.get(key, 0))
	return spare

func _puzzle_star_rank(sc: Dictionary, productive: bool) -> int:
	if not _is_resource_puzzle(sc) or _completion_progress() < int(local.get("target", 0)):
		return 0
	if not productive:
		return 1
	var spare := _puzzle_resource_spare(sc)
	var total_spare: int = max(0, int(spare.get("track", 0))) + max(0, int(spare.get("signals", 0)))
	var thresholds: Dictionary = sc.get("star_thresholds", {})
	if total_spare >= int(thresholds.get("three_star_spare", 9999)):
		return 3
	if total_spare >= int(thresholds.get("two_star_spare", 9999)):
		return 2
	return 1

func _puzzle_star_reward_multiplier(stars: int) -> float:
	if stars >= 3:
		return 1.35
	if stars == 2:
		return 1.15
	return 1.0

func _puzzle_star_label(stars: int) -> String:
	if stars <= 0:
		return "Unranked"
	return "%d Star%s" % [stars, "" if stars == 1 else "s"]

func _puzzle_resource_summary_text(sc: Dictionary = {}) -> String:
	if not _is_resource_puzzle(sc):
		return ""
	var budget := _resource_budget(sc)
	var used := _puzzle_resource_usage()
	return "Track %d/%d  Block %d/%d  Chain %d/%d  Total %d/%d  Trains %d/%d" % [
		int(used.get("track", 0)),
		int(budget.get("track", 0)),
		int(used.get("block", 0)),
		int(budget.get("block", 0)),
		int(used.get("chain", 0)),
		int(budget.get("chain", 0)),
		int(used.get("signals", 0)),
		int(budget.get("signals", 0)),
		int(used.get("trains", 0)),
		int(budget.get("trains", 0))
	]

func _puzzle_resource_result_text(sc: Dictionary, stars: int, multiplier: float) -> String:
	var spare := _puzzle_resource_spare(sc)
	return "Puzzle Rank: %s (x%.2f resource multiplier)\nUnused: Track %d  Signals %d  Block %d  Chain %d\n%s" % [
		_puzzle_star_label(stars),
		multiplier,
		int(spare.get("track", 0)),
		int(spare.get("signals", 0)),
		int(spare.get("block", 0)),
		int(spare.get("chain", 0)),
		String(sc.get("multi_solution_note", ""))
	]

func _scenario_train_car_count() -> int:
	if local.is_empty():
		return 1
	var sc: Dictionary = local.get("scenario", {})
	return max(1, int(sc.get("train_car_count", 1)))

func _update_local(delta: float, refresh_ui: bool = true) -> void:
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
	if refresh_ui:
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
	var step := float(t["speed"]) * _dispatch_speed_factor() * delta
	if step >= dist:
		var tile_step: float = Vector2(next_tile - (t["tile"] as Vector2i)).length()
		local["service_mileage"] = float(local.get("service_mileage", 0.0)) + tile_step
		if int(t.get("cargo_amount", 0)) > 0:
			t["contract_trip_distance"] = float(t.get("contract_trip_distance", 0.0)) + tile_step
		else:
			local["empty_mileage"] = float(local.get("empty_mileage", 0.0)) + tile_step
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
		t["dwell"] = max(float(t.get("dwell", 0.0)), 0.8)
		if String(t.get("dwell_state", "")) != "DetourStop":
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

func _uses_order_mode() -> bool:
	return bool(local.get("order_mode", false))

func _order_by_id(order_id: String) -> Dictionary:
	for order in local.get("orders", []):
		var data: Dictionary = order
		if String(data.get("id", "")) == order_id:
			return data
	return {}

func _order_progress_amount(order_id: String) -> int:
	return int((local.get("order_progress", {}) as Dictionary).get(order_id, 0))

func _order_in_transit_amount(order_id: String) -> int:
	return int((local.get("order_in_transit", {}) as Dictionary).get(order_id, 0))

func _set_order_counter(counter_key: String, order_id: String, amount: int) -> void:
	var counters: Dictionary = local.get(counter_key, {})
	counters[order_id] = max(0, amount)
	local[counter_key] = counters

func _order_remaining_amount(order: Dictionary) -> int:
	var id := String(order.get("id", ""))
	return max(0, int(order.get("amount", 0)) - _order_progress_amount(id) - _order_in_transit_amount(id))

func _route_contains_order_stops(route: Array, order: Dictionary) -> bool:
	var required: Array[String] = [String(order.get("origin", ""))]
	for via_id in order.get("via", []):
		required.append(String(via_id))
	required.append(String(order.get("destination", "")))
	return _route_contains_required_stops_in_order(route, required)

func _train_can_serve_order(t: Dictionary, order: Dictionary) -> bool:
	return _service_class_compatible_with_cargo(String(t.get("train_class", "light_freight")), String(order.get("cargo", "")))

func _line_can_serve_order(line_id: String, order: Dictionary) -> bool:
	if line_id == "" or not lines.has(line_id):
		return false
	var line: Dictionary = lines[line_id]
	if not _service_class_compatible_with_cargo(String(line.get("service_class", "light_freight")), String(order.get("cargo", ""))):
		return false
	return _route_contains_order_stops(line.get("route", []), order)

func _next_order_for_train_at_station(t: Dictionary, station_id: String) -> Dictionary:
	var line_id := String(t.get("line_id", ""))
	var best: Dictionary = {}
	for order in local.get("orders", []):
		var data: Dictionary = order
		if String(data.get("origin", "")) != station_id:
			continue
		if _order_remaining_amount(data) <= 0:
			continue
		if not _train_can_serve_order(t, data) or not _line_can_serve_order(line_id, data):
			continue
		if best.is_empty() or int(data.get("priority", 0)) > int(best.get("priority", 0)):
			best = data
	return best

func _station_has_order_origin(station_id: String) -> bool:
	for order in local.get("orders", []):
		if String((order as Dictionary).get("origin", "")) == station_id:
			return true
	return false

func _process_order_at_station(t: Dictionary, st: Dictionary) -> void:
	var station_id := String(st.get("id", ""))
	if int(t.get("cargo_amount", 0)) > 0:
		_mark_contract_trip_visit(t, st)
		var order := _order_by_id(String(t.get("loaded_order_id", "")))
		if order.is_empty():
			return
		if station_id == String(order.get("destination", "")):
			_deliver_order_from_train(t, order)
		elif (order.get("via", []) as Array).has(station_id):
			t["dwell"] = max(float(t.get("dwell", 0.0)), float(t.get("class_dwell", 0.8)))
		elif not _station_accepts_cargo(st, String(t.get("cargo", ""))):
			_record_incompatible_stop(t, st)
		return
	if station_id == "":
		return
	var next_order := _next_order_for_train_at_station(t, station_id)
	if next_order.is_empty():
		if _station_has_order_origin(station_id):
			local["wrong_service_loads"] = int(local.get("wrong_service_loads", 0)) + 1
			t["wait_reason"] = "Wrong service class for this station."
			local_message = "Wrong service: %s needs a compatible train class." % String(st.get("name", station_id))
		return
	_load_order_on_train(t, st, next_order)

func _station_accepts_cargo(st: Dictionary, cargo: String) -> bool:
	if cargo == "":
		return true
	return (st.get("accepts", []) as Array).has(cargo) or String(st.get("produces", "")) == cargo

func _load_order_on_train(t: Dictionary, st: Dictionary, order: Dictionary) -> void:
	var order_id := String(order.get("id", ""))
	var amount: int = min(int(t.get("capacity", 0)), _order_remaining_amount(order))
	if String(order.get("cargo", "")) != PASSENGER_CARGO and st.has("stored"):
		amount = min(amount, int(st.get("stored", 0)))
	if amount <= 0:
		return
	if String(order.get("cargo", "")) != PASSENGER_CARGO and st.has("stored"):
		st["stored"] = int(st.get("stored", 0)) - amount
	t["cargo"] = String(order.get("cargo", ""))
	t["cargo_amount"] = amount
	t["current_order_id"] = order_id
	t["loaded_order_id"] = order_id
	_set_order_counter("order_in_transit", order_id, _order_in_transit_amount(order_id) + amount)
	_start_contract_trip(t, st)
	t["dwell"] = max(float(t.get("dwell", 0.0)), float(t.get("class_dwell", 0.8)))
	t["dwell_state"] = "Loading"

func _deliver_order_from_train(t: Dictionary, order: Dictionary) -> void:
	var amount := int(t.get("cargo_amount", 0))
	if amount <= 0:
		return
	var order_id := String(order.get("id", ""))
	var remaining_to_score: int = max(0, int(order.get("amount", 0)) - _order_progress_amount(order_id))
	var scored: int = min(amount, remaining_to_score)
	_set_order_counter("order_in_transit", order_id, _order_in_transit_amount(order_id) - amount)
	if scored > 0:
		_record_order_output(scored, order, t)
	t["cargo_amount"] = 0
	t["cargo"] = ""
	t["current_order_id"] = ""
	t["loaded_order_id"] = ""
	_clear_contract_trip(t)
	t["dwell"] = max(float(t.get("dwell", 0.0)), float(t.get("class_dwell", 0.8)))
	t["dwell_state"] = "Unloading"

func _record_order_output(amount: int, order: Dictionary, t: Dictionary) -> void:
	var order_id := String(order.get("id", ""))
	local["productive_progress"] = int(local.get("productive_progress", 0)) + amount
	local["delivered"] = int(local.get("delivered", 0)) + amount
	local["processed"] = int(local.get("processed", 0)) + amount
	_set_order_counter("order_progress", order_id, _order_progress_amount(order_id) + amount)
	_record_output_flow_gap()
	t["productive_output"] = int(t.get("productive_output", 0)) + amount
	var cargo := String(order.get("cargo", ""))
	var flow_scores: Dictionary = local.get("flow_scores", {})
	var flow: Dictionary = flow_scores.get(cargo, {"delivered": 0, "late": 0})
	flow["delivered"] = int(flow.get("delivered", 0)) + amount
	if float(local.get("elapsed_time", 0.0)) > float(order.get("due_time", 999999.0)):
		flow["late"] = int(flow.get("late", 0)) + amount
		local["late_orders"] = int(local.get("late_orders", 0)) + 1
		local["late_order_amount"] = int(local.get("late_order_amount", 0)) + amount
		local_message = "Late %s delivery: focused routes and passing capacity improve passenger/freight timing." % _resource_name(cargo)
	flow_scores[cargo] = flow
	local["flow_scores"] = flow_scores
	var detour_stops := _order_trip_detour_stop_count(t, order)
	if detour_stops > 0:
		local["detour_output"] = int(local.get("detour_output", 0)) + amount
		local["detour_stops"] = int(local.get("detour_stops", 0)) + detour_stops
	var excess_mileage := _order_trip_excess_mileage(t, order)
	if excess_mileage > 0:
		local["excess_mileage"] = int(local.get("excess_mileage", 0)) + excess_mileage
		local["excess_mileage_output"] = int(local.get("excess_mileage_output", 0)) + amount

func _record_incompatible_stop(t: Dictionary, st: Dictionary) -> void:
	local["incompatible_stops"] = int(local.get("incompatible_stops", 0)) + 1
	t["dwell"] = max(float(t.get("dwell", 0.0)), float(t.get("class_dwell", 0.8)) + 0.45)
	t["dwell_state"] = "DetourStop"
	local_message = "%s stopped at incompatible %s station." % [String(t.get("id", "Train")), String(st.get("name", "station"))]

func _order_trip_required_stops(order: Dictionary) -> Array[String]:
	var required: Array[String] = [String(order.get("origin", ""))]
	for via_id in order.get("via", []):
		required.append(String(via_id))
	required.append(String(order.get("destination", "")))
	return required

func _order_trip_detour_stop_count(t: Dictionary, order: Dictionary) -> int:
	return _detour_stop_count_for_visit_sequence(t.get("contract_trip_visited", []), _order_trip_required_stops(order), String(order.get("destination", "")))

func _order_trip_excess_mileage(t: Dictionary, order: Dictionary) -> int:
	var expected_distance := _contract_required_trip_distance(_order_trip_required_stops(order))
	var allowance := expected_distance * 1.45 + 3.0
	return max(0, int(floor(float(t.get("contract_trip_distance", 0.0)) - allowance)))

func _process_cargo_at_station(t: Dictionary, st: Dictionary) -> void:
	if _uses_order_mode():
		_process_order_at_station(t, st)
		return
	var kind: String = local.get("kind", "")
	if int(t.get("cargo_amount", 0)) > 0:
		_apply_contract_detour_dwell(t, st)
		_mark_contract_trip_visit(t, st)
	if kind == "coal":
		if st.get("role", "") == "source" and int(t["cargo_amount"]) == 0:
			var amount: int = min(int(t["capacity"]), int(st.get("stored", 0)))
			st["stored"] = int(st.get("stored", 0)) - amount
			t["cargo"] = "coal"
			t["cargo_amount"] = amount
			if amount > 0:
				_start_contract_trip(t, st)
		elif st.get("role", "") == "sink" and t.get("cargo", "") == "coal":
			_mark_contract_trip_visit(t, st)
			local["delivered"] = int(local["delivered"]) + int(t["cargo_amount"])
			_record_productive_output(int(t["cargo_amount"]), t, String(st.get("id", "")))
			t["cargo_amount"] = 0
			t["cargo"] = ""
			_clear_contract_trip(t)
	elif kind == "yard":
		if st.get("role", "") == "source" and int(t["cargo_amount"]) == 0:
			t["cargo"] = "freight"
			t["cargo_amount"] = min(int(t["capacity"]), 10 * max(1, int(t.get("car_count", 1))))
			if int(t["cargo_amount"]) > 0:
				_start_contract_trip(t, st)
		elif st.get("role", "") == "yard":
			if int(t.get("cargo_amount", 0)) > 0:
				_mark_contract_trip_visit(t, st)
			t["dwell"] = max(float(t.get("dwell", 0.0)), 1.2 / max(1, int(st.get("platforms", 1))))
		elif st.get("role", "") == "sink" and t.get("cargo", "") == "freight":
			_mark_contract_trip_visit(t, st)
			var processed: int = max(1, int(floor(float(t.get("cargo_amount", 0)) / 10.0)))
			local["processed"] = int(local["processed"]) + processed
			_record_productive_output(processed, t, String(st.get("id", "")))
			t["cargo_amount"] = 0
			t["cargo"] = ""
			_clear_contract_trip(t)
	elif kind == "steel":
		if st["id"] == "coal_input" and int(t["cargo_amount"]) == 0:
			var coal: int = min(int(t["capacity"]), int(st.get("stored", 0)))
			st["stored"] = int(st.get("stored", 0)) - coal
			t["cargo"] = "coal"
			t["cargo_amount"] = coal
			if coal > 0:
				_start_contract_trip(t, st)
		elif st["id"] == "steelworks":
			if t.get("cargo", "") == "coal":
				_mark_contract_trip_visit(t, st)
				local["coal_buffer"] = int(local["coal_buffer"]) + int(t["cargo_amount"])
				local["steel_buffer"] = int(local["steel_buffer"]) + int(int(t["cargo_amount"]) / 2)
				local["processor_feed"] = int(local.get("processor_feed", 0)) + int(t["cargo_amount"])
				t["cargo"] = ""
				t["cargo_amount"] = 0
			if int(t["cargo_amount"]) == 0 and int(local.get("steel_buffer", 0)) > 0:
				var steel: int = min(int(t["capacity"]), int(local["steel_buffer"]))
				local["steel_buffer"] = int(local["steel_buffer"]) - steel
				t["cargo"] = "steel"
				t["cargo_amount"] = steel
				if not (t.get("contract_trip_visited", []) as Array).has(String(st.get("id", ""))):
					_start_contract_trip(t, st)
		elif st["id"] == "export_platform" and t.get("cargo", "") == "steel":
			_mark_contract_trip_visit(t, st)
			local["delivered"] = int(local["delivered"]) + int(t["cargo_amount"])
			local["processor_export"] = int(local.get("processor_export", 0)) + int(t["cargo_amount"])
			_record_productive_output(int(t["cargo_amount"]), t, String(st.get("id", "")))
			t["cargo"] = ""
			t["cargo_amount"] = 0
			_clear_contract_trip(t)

func _record_productive_output(amount: int, t: Dictionary = {}, delivery_station_id: String = "") -> void:
	if amount <= 0:
		return
	if t.is_empty() or _train_contract_output_ready(t, delivery_station_id):
		local["productive_progress"] = int(local.get("productive_progress", 0)) + amount
		_record_output_flow_gap()
		if not t.is_empty():
			t["productive_output"] = int(t.get("productive_output", 0)) + amount
			var detour_stops := _contract_trip_detour_stop_count(t, delivery_station_id)
			if detour_stops > 0:
				local["detour_output"] = int(local.get("detour_output", 0)) + amount
				local["detour_stops"] = int(local.get("detour_stops", 0)) + detour_stops
				local_message = "Contract output counted, but detours before delivery are lowering the grade."
			var excess_mileage := _contract_trip_excess_mileage(t, delivery_station_id)
			if excess_mileage > 0:
				local["excess_mileage"] = int(local.get("excess_mileage", 0)) + excess_mileage
				local["excess_mileage_output"] = int(local.get("excess_mileage_output", 0)) + amount
				local_message = "Contract output counted, but long loaded mileage is lowering the grade."
	else:
		local["unqualified_output"] = int(local.get("unqualified_output", 0)) + amount
		var missing := _contract_missing_trip_stop_names(t, delivery_station_id)
		if not missing.is_empty():
			local_message = "Cargo moved, but contract output needs this trip to visit: %s." % ", ".join(missing)

func _record_output_flow_gap() -> void:
	var now: float = float(local.get("elapsed_time", 0.0))
	var first_time: float = float(local.get("first_output_time", -1.0))
	var previous_time: float = float(local.get("last_output_time", 0.0))
	var gap: float = max(0.0, now if first_time < 0.0 else now - previous_time)
	local["max_output_gap"] = max(float(local.get("max_output_gap", 0.0)), gap)
	if first_time < 0.0:
		local["first_output_time"] = now
	local["last_output_time"] = now

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
	var avg_wait: float = _average_wait()
	var fleet_goal: int = _fleet_goal()
	var fleet_met: bool = _active_train_count() >= fleet_goal
	var productive: bool = fleet_met and _fleet_contribution_shortfall() <= 0 and avg_wait <= float(local["wait_target"]) and int(local.get("deadlocks", 0)) == 0
	var quality_grade: String = _completion_quality_grade(sc, avg_wait, productive)
	var quality: String = _completion_quality_label(quality_grade)
	var reward_money: int = _completion_reward_money(sc, avg_wait, productive)
	var material_par: int = _reward_material_par(sc)
	var time_par: float = _reward_time_par(sc)
	var elapsed: float = float(local.get("elapsed_time", 0.0))
	var has_bonus := _contract_bonus_challenge_text(sc) != ""
	var bonus_met := _contract_bonus_challenge_met(sc, avg_wait, productive)
	var puzzle_stars := _puzzle_star_rank(sc, productive)
	var puzzle_multiplier := _puzzle_star_reward_multiplier(puzzle_stars)
	var mastery_record: Dictionary = _update_mastery_record(sc, quality_grade, avg_wait, productive, reward_money)
	result_data = {
		"id": local["id"],
		"name": local["name"],
		"quality_grade": quality_grade,
		"replay_label": _result_replay_label(quality_grade, has_bonus, bonus_met),
		"text": "[b]%s[/b]\n%s\nNext Try: %s\nMastery Record: %s\nGrade Coach: %s\n%s\n\n%s: %d / %d\nTotal Output: %d\nFleet: %d / %d trains\nFleet Overage: %d\nContributing Trains: %d / %d\nDispatch Speed: %.0f%%\nAverage Train Wait: %.1fs / %.0fs target\nFlow Gap: %.0fs / %.0fs target\nTime: %.0fs / %.0fs par\nMaterial Used: %d / %d par\nDeadlocks: %d\nMaximum Queue: %d\nOutside Contract: %d\nDetoured Contract: %d\nDetour Dwell: %.1fs\nLong Mileage: %d\nRoute Discipline: %d extra stops\nRepeated Stops: %d\nPlatform Padding: %d\nService Mileage: %.1f/output\nEmpty Running: %.0f%%\nBonus Challenge: %s\n%s\nOperating Cost: -$%d\nInspection Fine: -$%d\nInspection Rebate: +$%d\nMastery Streak: +$%d\n\nRegional Reward:\n+$%d\n+%d Traffic Load\n+%d Traffic Capacity" % [
			quality,
			_completion_quality_summary(sc, avg_wait, productive),
			_result_next_try_text(sc, avg_wait, productive, quality_grade),
			String(mastery_record.get("text", "Best: none yet")),
			_grade_coach_text(sc, avg_wait, productive),
			_completion_regional_effect_text(sc, quality_grade),
			_progress_label(),
			_completion_progress(),
			int(local["target"]),
			_objective_progress(),
			_active_train_count(),
			fleet_goal,
			_fleet_overage(),
			_contributing_train_count(),
			fleet_goal,
			_dispatch_speed_factor() * 100.0,
			avg_wait,
			float(local["wait_target"]),
			_max_output_gap(),
			_flow_gap_target(),
			elapsed,
			time_par,
			int(local.get("infra_cost", 0)),
			material_par,
			int(local.get("deadlocks", 0)),
			int(local.get("max_queue", 0)),
			int(local.get("unqualified_output", 0)),
			int(local.get("detour_output", 0)),
			float(local.get("detour_dwell", 0.0)),
			int(local.get("excess_mileage", 0)),
			_active_route_bloat_score(),
			_active_route_repeat_score(),
			_platform_padding_score(),
			_service_mileage_per_output(),
			_empty_mileage_share() * 100.0,
			_contract_bonus_result_text(sc, avg_wait, productive),
			_contract_bonus_coach_text(sc, avg_wait, productive),
			_operating_cost(),
			_completion_inspection_fine(sc, quality_grade),
			_completion_inspection_rebate(sc, quality_grade),
			_completion_mastery_streak_bonus(sc, quality_grade),
			reward_money,
			int(sc.get("reward_load", 0)),
			int(sc.get("reward_capacity", 0))
		]
	}
	if _is_resource_puzzle(sc):
		result_data["text"] = String(result_data["text"]).replace("\n\nRegional Reward:", "\n\n%s\n\nRegional Reward:" % _puzzle_resource_result_text(sc, puzzle_stars, puzzle_multiplier))
	if not campaign["completed"].has(local["id"]):
		campaign["completed"].append(local["id"])
		campaign["money"] = int(campaign["money"]) + reward_money
		campaign["traffic_load"] = int(campaign["traffic_load"]) + int(sc.get("reward_load", 0))
		campaign["traffic_capacity"] = int(campaign["traffic_capacity"]) + int(sc.get("reward_capacity", 0))
		_record_run_completion(sc, avg_wait, productive, quality_grade)
		_save_campaign()
	elif bool(mastery_record.get("changed", false)):
		_save_campaign()
	screen = Screen.RESULTS
	rebuild_ui()
	queue_redraw()

func _completion_reward_money(sc: Dictionary, avg_wait: float, productive: bool) -> int:
	var base: int = int(sc.get("reward_money", 0))
	var effective_material: int = int(float(local.get("infra_cost", 0)) * max(0.55, 1.0 - float(_upgrade_level("material_efficiency")) * 0.10))
	var material_bonus: int = int(max(0.0, float(_reward_material_par(sc) - effective_material) * 0.22))
	var time_bonus: int = int(max(0.0, _reward_time_par(sc) - float(local.get("elapsed_time", 0.0))) * 1.4)
	var wait_bonus: int = int(max(0.0, float(local.get("wait_target", 0.0)) - avg_wait) * 2.0)
	var reliability_bonus: int = 120 if productive else 0
	var over_target_bonus: int = int(max(0, _completion_progress() - int(local.get("target", 0))) * 0.4)
	var total: int = max(0, base + material_bonus + time_bonus + wait_bonus + reliability_bonus + over_target_bonus)
	var grade: String = _completion_quality_grade(sc, avg_wait, productive)
	var grade_multiplier: float = _completion_quality_reward_multiplier(grade)
	var resource_multiplier: float = _puzzle_star_reward_multiplier(_puzzle_star_rank(sc, productive))
	var gross_reward: int = int(round(float(total) * grade_multiplier * resource_multiplier * (1.0 + float(_upgrade_level("reward_multiplier")) * 0.10)))
	return max(0, gross_reward - _operating_cost() - _completion_inspection_fine(sc, grade) + _completion_inspection_rebate(sc, grade) + _completion_mastery_streak_bonus(sc, grade) + _contract_bonus_reward_money(sc, avg_wait, productive))

func _completion_mastery_streak_bonus(sc: Dictionary, grade: String) -> int:
	if not _is_run_scenario_id(String(sc.get("id", ""))) or grade not in ["gold", "perfect"]:
		return 0
	var streak := _current_mastery_streak_length() + 1
	return min(4, streak) * 25

func _current_mastery_streak_length() -> int:
	var history: Array = campaign.get("run_history", [])
	var streak := 0
	for i in range(history.size() - 1, -1, -1):
		var record: Dictionary = history[i]
		if String(record.get("quality_grade", "")) in ["gold", "perfect"]:
			streak += 1
		else:
			break
	return streak

func _operating_cost() -> int:
	var service: float = max(0.0, float(local.get("service_mileage", 0.0)))
	var empty: float = max(0.0, float(local.get("empty_mileage", 0.0)))
	return int(round(service * OPERATING_COST_PER_TILE + empty * EMPTY_OPERATING_SURCHARGE_PER_TILE))

func _flow_gap_target() -> float:
	var sc: Dictionary = local.get("scenario", {})
	var multiplier: float = float(sc.get("flow_gap_multiplier", 1.0))
	return max(14.0, float(local.get("wait_target", 0.0)) * 0.75 * multiplier)

func _max_output_gap() -> float:
	return max(0.0, float(local.get("max_output_gap", 0.0)))

func _passing_capacity_target(sc: Dictionary) -> int:
	if String(sc.get("template_id", "")) != "passing_siding":
		return 0
	return max(2, min(6, int(sc.get("fleet_goal", _fleet_goal()))))

func _signal_gate_count() -> int:
	var count := 0
	for raw_pos in signals.keys():
		var pos: Vector2i = raw_pos
		count += max(1, _signal_dirs(pos).size())
	return count

func _passing_capacity_missing(sc: Dictionary) -> int:
	var target := _passing_capacity_target(sc)
	if target <= 0:
		return 0
	return max(0, target - _signal_gate_count())

func _passing_capacity_status_text(sc: Dictionary) -> String:
	var target := _passing_capacity_target(sc)
	if target <= 0:
		return ""
	var gates := _signal_gate_count()
	if gates >= target:
		return "Passing proof: %d/%d signal gates ready." % [gates, target]
	return "Passing proof: %d/%d signal gates; add signals or paired signals for Gold/Perfect capacity." % [gates, target]

func _junction_chain_target(sc: Dictionary) -> int:
	if String(sc.get("template_id", "")) != "junction_sort":
		return 0
	return max(2, min(6, int(sc.get("fleet_goal", _fleet_goal()))))

func _chain_signal_gate_count() -> int:
	var count := 0
	for raw_pos in signals.keys():
		var pos: Vector2i = raw_pos
		for dir in _signal_dirs(pos):
			if _signal_type_for_dir(pos, dir) == "chain":
				count += 1
	return count

func _junction_chain_missing(sc: Dictionary) -> int:
	var target := _junction_chain_target(sc)
	if target <= 0:
		return 0
	return max(0, target - _chain_signal_gate_count())

func _junction_chain_status_text(sc: Dictionary) -> String:
	var target := _junction_chain_target(sc)
	if target <= 0:
		return ""
	var gates := _chain_signal_gate_count()
	if gates >= target:
		return "Junction proof: %d/%d chain-signal gates ready." % [gates, target]
	return "Junction proof: %d/%d chain-signal gates; protect shared entries for Gold/Perfect sorting." % [gates, target]

func _efficiency_proof_applies(sc: Dictionary) -> bool:
	return String(sc.get("template_id", "")) == "efficiency_run"

func _efficiency_proof_missing(sc: Dictionary) -> int:
	if not _efficiency_proof_applies(sc):
		return 0
	var missing := 0
	if _active_route_bloat_score() > 0:
		missing += 1
	if _fleet_overage() > 1:
		missing += 1
	if int(local.get("infra_cost", 0)) > _reward_material_par(sc):
		missing += 1
	return missing

func _efficiency_proof_status_text(sc: Dictionary) -> String:
	if not _efficiency_proof_applies(sc):
		return ""
	var misses: Array[String] = []
	if _active_route_bloat_score() > 0:
		misses.append("Route +%d" % _active_route_bloat_score())
	if _fleet_overage() > 1:
		misses.append("Fleet +%d" % _fleet_overage())
	if int(local.get("infra_cost", 0)) > _reward_material_par(sc):
		misses.append("Used %d/%d" % [int(local.get("infra_cost", 0)), _reward_material_par(sc)])
	if misses.is_empty():
		return "Lean proof: clean route, right-sized fleet, material within par."
	return "Lean proof: %s; trim loops, extra trains, or low-value build for Gold/Perfect." % ", ".join(misses)

func _processor_proof_applies(sc: Dictionary) -> bool:
	return String(sc.get("template_id", "")) == "processor_chain"

func _processor_proof_satisfied_count(sc: Dictionary) -> int:
	if not _processor_proof_applies(sc):
		return 2
	var count := 0
	var fed_processor := int(local.get("processor_feed", 0)) > 0 or int(local.get("coal_buffer", 0)) > 0 or int(local.get("processor_export", 0)) > 0
	var exported_processor_output := int(local.get("processor_export", 0)) > 0
	if fed_processor:
		count += 1
	if exported_processor_output:
		count += 1
	return count

func _processor_proof_missing(sc: Dictionary) -> int:
	if not _processor_proof_applies(sc):
		return 0
	return max(0, 2 - _processor_proof_satisfied_count(sc))

func _processor_proof_status_text(sc: Dictionary) -> String:
	if not _processor_proof_applies(sc):
		return ""
	var count := _processor_proof_satisfied_count(sc)
	if count >= 2:
		return "Processor proof: 2/2 handoffs ready - coal feed and steel export both proven."
	var missing: Array[String] = []
	if int(local.get("processor_feed", 0)) <= 0 and int(local.get("coal_buffer", 0)) <= 0 and int(local.get("processor_export", 0)) <= 0:
		missing.append("feed coal into processor")
	if int(local.get("processor_export", 0)) <= 0:
		missing.append("export processor-made steel")
	return "Processor proof: %d/2 handoffs; %s for Gold/Perfect flow." % [count, ", then ".join(missing)]

func _completion_quality_grade(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	var material_par: float = float(max(1, _reward_material_par(sc)))
	var time_par: float = max(1.0, _reward_time_par(sc))
	var material_ratio: float = float(local.get("infra_cost", 0)) / material_par
	var time_ratio: float = float(local.get("elapsed_time", 0.0)) / time_par
	var wait_target: float = max(1.0, float(local.get("wait_target", 1.0)))
	var wait_ratio: float = avg_wait / wait_target
	var score: int = 0
	if productive:
		score += 2
	if material_ratio <= 1.0:
		score += 2
	elif material_ratio <= 1.25:
		score += 1
	elif material_ratio > 1.65:
		score -= 1
	if time_ratio <= 1.0:
		score += 1
	elif time_ratio > 1.5:
		score -= 1
	if wait_ratio <= 1.0:
		score += 1
	elif wait_ratio > 1.5:
		score -= 1
	var flow_ratio: float = _max_output_gap() / max(1.0, _flow_gap_target())
	if flow_ratio > 1.4:
		score -= 1
	if flow_ratio > 2.0:
		score -= 1
	var fleet_overage := _fleet_overage()
	if fleet_overage > 1:
		score -= 1
	if fleet_overage > 3:
		score -= 1
	if int(local.get("deadlocks", 0)) == 0:
		score += 1
	else:
		score -= min(2, int(local.get("deadlocks", 0)))
	if int(local.get("unqualified_output", 0)) > 0:
		score -= 1
	if int(local.get("late_order_amount", 0)) > 0:
		score -= 1
	if int(local.get("late_orders", 0)) >= 2:
		score -= 1
	var incompatible_score := _active_incompatible_stop_score()
	if incompatible_score > 0:
		score -= 1
	if incompatible_score >= 3:
		score -= 1
	var detour_ratio: float = float(local.get("detour_output", 0)) / float(max(1, _completion_progress()))
	if detour_ratio > 0.0:
		score -= 1
	if detour_ratio >= 0.25 or int(local.get("detour_stops", 0)) >= 4:
		score -= 1
	var excess_mileage_ratio: float = float(local.get("excess_mileage_output", 0)) / float(max(1, _completion_progress()))
	if excess_mileage_ratio > 0.0:
		score -= 1
	if excess_mileage_ratio >= 0.25 or int(local.get("excess_mileage", 0)) >= 10:
		score -= 1
	var mileage_per_output := _service_mileage_per_output()
	var empty_share := _empty_mileage_share()
	var empty_limit: float = _empty_running_grade_limit(sc)
	if _completion_progress() > 0 and sc.has("empty_share_limit") and empty_share > empty_limit and mileage_per_output > 2.2:
		score -= 1
	var route_bloat := _active_route_bloat_score()
	if route_bloat > 0:
		score -= 1
	if route_bloat >= 3:
		score -= 1
	var route_repeats := _active_route_repeat_score()
	if route_repeats > 0:
		score -= 1
	if route_repeats >= 2:
		score -= 1
	var platform_padding := _platform_padding_score()
	if platform_padding > 0:
		score -= 1
	if platform_padding >= 3:
		score -= 1
	if _completion_progress() > 0 and mileage_per_output > 2.8:
		score -= 1
	if _completion_progress() > 0 and mileage_per_output > 4.2 and empty_share > 0.42:
		score -= 1
	var passing_missing := _passing_capacity_missing(sc)
	if passing_missing > 0:
		score -= 1
	if passing_missing >= max(2, int(ceil(float(_passing_capacity_target(sc)) * 0.5))):
		score -= 1
	var junction_missing := _junction_chain_missing(sc)
	if junction_missing > 0:
		score -= 1
	if junction_missing >= max(2, int(ceil(float(_junction_chain_target(sc)) * 0.5))):
		score -= 1
	var efficiency_missing := _efficiency_proof_missing(sc)
	if efficiency_missing > 0:
		score -= efficiency_missing
	var processor_missing := _processor_proof_missing(sc)
	if processor_missing > 0:
		score -= processor_missing
	var sprawl_score := _network_sprawl_score(sc)
	if sprawl_score > 0:
		score -= 1
	if sprawl_score >= _network_sprawl_major_threshold(sc):
		score -= 1
	if score >= 7 and _contract_bonus_challenge_met(sc, avg_wait, productive):
		return "perfect"
	if score >= 6:
		return "gold"
	if score >= 4:
		return "silver"
	if score >= 2:
		return "bronze"
	return "rough"

func _completion_quality_label(grade: String) -> String:
	if grade == "perfect":
		return "Perfect proof"
	if grade == "gold":
		return "Gold dispatch"
	if grade == "silver":
		return "Silver dispatch"
	if grade == "bronze":
		return "Bronze clear"
	return "Rough clear"

func _completion_quality_reward_multiplier(grade: String) -> float:
	if grade == "perfect":
		return 1.45
	if grade == "gold":
		return 1.25
	if grade == "silver":
		return 1.0
	if grade == "bronze":
		return 0.72
	return 0.45

func _completion_quality_reliability_multiplier(grade: String) -> float:
	if grade == "perfect":
		return 1.15
	if grade == "gold":
		return 1.08
	if grade == "silver":
		return 1.0
	if grade == "bronze":
		return 0.88
	return 0.72

func _completion_quality_regional_effects(sc: Dictionary, grade: String) -> Dictionary:
	var traffic: int = int(sc.get("reward_load", 0))
	var capacity: int = int(sc.get("reward_capacity", 0))
	var burst := 0.0
	if grade == "perfect":
		capacity += 3
		traffic = max(0, traffic - 2)
		burst = -0.08
	elif grade == "gold":
		capacity += 2
		traffic = max(0, traffic - 1)
		burst = -0.04
	elif grade == "silver":
		capacity += 1
	elif grade == "bronze":
		traffic += 1
		burst = 0.05
	else:
		traffic += 3
		capacity = max(0, capacity - 1)
		burst = 0.12
	return {"traffic": traffic, "capacity": capacity, "burst": burst}

func _completion_inspection_delta(sc: Dictionary, grade: String) -> int:
	if not _is_run_scenario_id(String(sc.get("id", ""))):
		return 0
	if grade == "perfect":
		return -3
	if grade == "gold":
		return -2
	var delta := 0
	if grade == "bronze":
		delta = 1
	elif grade == "rough":
		delta = 3
	if _active_route_bloat_score() > 0:
		delta += 1
	if _active_route_repeat_score() > 0:
		delta += 1
	if _platform_padding_score() > 0:
		delta += 1
	if _network_sprawl_score(sc) > 0:
		delta += 1
	if int(local.get("detour_output", 0)) > 0:
		delta += 1
	if _completion_progress() > 0 and _empty_mileage_share() > _empty_running_grade_limit(sc):
		delta += 1
	if int(local.get("deadlocks", 0)) > 0:
		delta += 1
	if grade == "silver" and delta > 0:
		delta = max(0, delta - 1)
	return delta

func _completion_inspection_effect_text(sc: Dictionary, grade: String) -> String:
	var delta := _completion_inspection_delta(sc, grade)
	if delta < 0:
		return "inspection -%d" % abs(delta)
	if delta > 0:
		return "inspection +%d" % delta
	return "inspection steady"

func _completion_inspection_fine(sc: Dictionary, grade: String) -> int:
	var delta := _completion_inspection_delta(sc, grade)
	if delta <= 0:
		return 0
	var debt: int = int((campaign.get("regional_traits", {}) as Dictionary).get("inspection_debt", 0))
	return delta * 35 + max(0, debt) * 10

func _completion_inspection_rebate(sc: Dictionary, grade: String) -> int:
	var delta := _completion_inspection_delta(sc, grade)
	if delta >= 0:
		return 0
	var debt: int = int((campaign.get("regional_traits", {}) as Dictionary).get("inspection_debt", 0))
	return min(abs(delta), max(0, debt)) * 45

func _completion_inspection_preview_text(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	if not _is_run_scenario_id(String(sc.get("id", ""))) or _completion_progress() <= 0:
		return ""
	var grade := _completion_quality_grade(sc, avg_wait, productive)
	var delta := _completion_inspection_delta(sc, grade)
	if delta > 0:
		return "Inspection risk: this %s would add inspection +%d and a -$%d fine. Clean up loops now or accept a harder region." % [_completion_quality_label(grade), delta, _completion_inspection_fine(sc, grade)]
	if delta < 0:
		var debt: int = int((campaign.get("regional_traits", {}) as Dictionary).get("inspection_debt", 0))
		if debt > 0:
			return "Inspection relief: this %s would reduce regional inspection pressure by %d and earn a +$%d rebate." % [_completion_quality_label(grade), min(abs(delta), debt), _completion_inspection_rebate(sc, grade)]
		return "Inspection outlook: this %s keeps the region forgiving." % _completion_quality_label(grade)
	return "Inspection outlook: steady."

func _completion_regional_effect_text(sc: Dictionary, grade: String) -> String:
	if not _is_run_scenario_id(String(sc.get("id", ""))):
		return ""
	var effects := _completion_quality_regional_effects(sc, grade)
	var reliability_text := "steady"
	if grade == "perfect":
		reliability_text = "proven"
	elif grade == "gold":
		reliability_text = "improves"
	elif grade == "bronze":
		reliability_text = "strained"
	elif grade == "rough":
		reliability_text = "damaged"
	return "Regional effect: +%d traffic, +%d capacity, reliability %s, %s." % [
		int(effects.get("traffic", 0)),
		int(effects.get("capacity", 0)),
		reliability_text,
		_completion_inspection_effect_text(sc, grade)
	]

func _service_mileage_per_output() -> float:
	return float(local.get("service_mileage", 0.0)) / float(max(1, _completion_progress()))

func _empty_mileage_share() -> float:
	var service_mileage: float = float(local.get("service_mileage", 0.0))
	if service_mileage <= 0.0:
		return 0.0
	return float(local.get("empty_mileage", 0.0)) / service_mileage

func _empty_running_grade_limit(sc: Dictionary) -> float:
	return float(sc.get("empty_share_limit", 0.42))

func _ghost_unique_track_tiles(sc: Dictionary) -> int:
	var seen := {}
	for raw_pos in sc.get("ghost", []):
		var p: Vector2i = raw_pos
		seen[p] = true
	return seen.size()

func _network_sprawl_allowance(sc: Dictionary) -> int:
	var allowance: int = max(4, _fleet_goal() * 2)
	if String(sc.get("template_id", "")) == "passing_siding":
		allowance += max(4, _passing_capacity_target(sc) * 2)
	elif String(sc.get("template_id", "")) == "junction_sort":
		allowance += max(3, _junction_chain_target(sc))
	allowance += int(sc.get("sprawl_allowance_bonus", 0))
	return allowance

func _network_sprawl_track_budget(sc: Dictionary) -> int:
	var ghost_tiles := _ghost_unique_track_tiles(sc)
	if ghost_tiles <= 0:
		ghost_tiles = max(6, int(sc.get("route", []).size()) * 5)
	return ghost_tiles + _network_sprawl_allowance(sc)

func _network_sprawl_score(sc: Dictionary) -> int:
	if local.is_empty() or sc.is_empty():
		return 0
	return max(0, tracks.size() - _network_sprawl_track_budget(sc))

func _network_sprawl_major_threshold(sc: Dictionary) -> int:
	return max(6, int(ceil(float(_network_sprawl_allowance(sc)) * 1.5)))

func _completion_quality_short_label(grade: String) -> String:
	if grade == "perfect":
		return "Perfect"
	if grade == "gold":
		return "Gold"
	if grade == "silver":
		return "Silver"
	if grade == "bronze":
		return "Bronze"
	return "Rough"

func _current_completion_quality_grade() -> String:
	if local.is_empty() or not local.has("scenario"):
		return "rough"
	var avg_wait: float = _average_wait()
	return _completion_quality_grade(local["scenario"], avg_wait, _current_productive_for_grade(avg_wait))

func _current_productive_for_grade(avg_wait: float) -> bool:
	return _active_train_count() >= _fleet_goal() and _fleet_contribution_shortfall() <= 0 and avg_wait <= float(local.get("wait_target", 0.0)) and int(local.get("deadlocks", 0)) == 0

func _fleet_shortfall() -> int:
	return max(0, _fleet_goal() - _active_train_count())

func _completion_quality_summary(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	var grade: String = _completion_quality_grade(sc, avg_wait, productive)
	var multiplier: float = _completion_quality_reward_multiplier(grade)
	var signal_target := _passing_capacity_target(sc)
	var signal_summary := "" if signal_target <= 0 else ", Signals %d/%d" % [_signal_gate_count(), signal_target]
	var chain_target := _junction_chain_target(sc)
	var chain_summary := "" if chain_target <= 0 else ", Chain %d/%d" % [_chain_signal_gate_count(), chain_target]
	var lean_summary := "" if not _efficiency_proof_applies(sc) else ", Lean %d/3" % max(0, 3 - _efficiency_proof_missing(sc))
	var processor_summary := "" if not _processor_proof_applies(sc) else ", Processor %d/2" % _processor_proof_satisfied_count(sc)
	return "Grade payout %.0f%% - Material %d/%d, Time %.0f/%.0f, Wait %.0f/%.0f, Flow %.0f/%.0f, Fleet -%d/+%d, Contrib -%d, Dispatch %.0f%%%s%s%s%s, Bonus %s, Streak +$%d, Detour %d, Miles +%d, Route +%d, Repeat +%d, Platform +%d, Rail +%d, Ops -$%d, Inspect -$%d/+$%d, Service %.1f/output" % [
		multiplier * 100.0,
		int(local.get("infra_cost", 0)),
		_reward_material_par(sc),
		float(local.get("elapsed_time", 0.0)),
		_reward_time_par(sc),
		avg_wait,
		float(local.get("wait_target", 0.0)),
		_max_output_gap(),
		_flow_gap_target(),
		_fleet_shortfall(),
		_fleet_overage(),
		_fleet_contribution_shortfall(),
		_dispatch_speed_factor() * 100.0,
		signal_summary,
		chain_summary,
		lean_summary,
		processor_summary,
		_contract_bonus_result_text(sc, avg_wait, productive),
		_completion_mastery_streak_bonus(sc, grade),
		int(local.get("detour_output", 0)),
		int(local.get("excess_mileage", 0)),
		_active_route_bloat_score(),
		_active_route_repeat_score(),
		_platform_padding_score(),
		_network_sprawl_score(sc),
		_operating_cost(),
		_completion_inspection_fine(sc, grade),
		_completion_inspection_rebate(sc, grade),
		_service_mileage_per_output()
	]

func _grade_coach_text(sc: Dictionary, avg_wait: float, productive: bool) -> String:
	var tips: Array[String] = []
	if int(local.get("deadlocks", 0)) > 0:
		tips.append("clear deadlocks with chain signals or escape paths")
	if int(local.get("unqualified_output", 0)) > 0:
		tips.append("add every required contract stop in order")
	if int(local.get("late_order_amount", 0)) > 0:
		tips.append("shorten late order routes")
	if _active_incompatible_stop_score() > 0:
		tips.append("split passenger and freight services")
	if _fleet_shortfall() > 0:
		tips.append("add %d contract train%s" % [_fleet_shortfall(), "" if _fleet_shortfall() == 1 else "s"])
	if _fleet_contribution_shortfall() > 0:
		tips.append("get %d more contract train%s delivering output" % [_fleet_contribution_shortfall(), "" if _fleet_contribution_shortfall() == 1 else "s"])
	if _fleet_overage() > 1:
		tips.append("return extra trains to stock")
	if _active_route_bloat_score() > 0:
		tips.append("trim extra scheduled stops")
	if _active_route_repeat_score() > 0:
		tips.append("split repeated stops into focused services")
	if _platform_padding_score() > 0:
		tips.append("remove low-value platform padding")
	if _network_sprawl_score(sc) > 0:
		tips.append("trim unused rail sprawl")
	if int(local.get("detour_output", 0)) > 0:
		tips.append("move contract stops before detours")
	if _max_output_gap() > _flow_gap_target():
		tips.append("shorten gaps between useful deliveries")
	if _passing_capacity_missing(sc) > 0:
		tips.append("add signal gates for passing capacity")
	if _junction_chain_missing(sc) > 0:
		tips.append("add chain signals before junction entries")
	if _efficiency_proof_missing(sc) > 0:
		tips.append("complete the lean proof")
	if _processor_proof_missing(sc) > 0:
		tips.append("prove processor feed and steel export")
	if avg_wait > float(local.get("wait_target", 0.0)):
		tips.append("add passing capacity where trains wait")
	if int(local.get("excess_mileage", 0)) > 0 or _service_mileage_per_output() > 2.8:
		tips.append("shorten loaded and return mileage")
	if _completion_progress() > 0 and _empty_mileage_share() > _empty_running_grade_limit(sc):
		tips.append("reduce empty running")
	if int(local.get("infra_cost", 0)) > _reward_material_par(sc):
		tips.append("remove low-value track or signals")
	if float(local.get("elapsed_time", 0.0)) > _reward_time_par(sc):
		tips.append("speed up the contract cycle")
	if tips.is_empty():
		return "Gold-ready: keep this service compact and steady."
	var shown: Array[String] = []
	for i in range(min(2, tips.size())):
		shown.append(tips[i])
	return "; ".join(shown)

func _completion_grade_target_text(sc: Dictionary) -> String:
	var signal_target := _passing_capacity_target(sc)
	var signal_text := "" if signal_target <= 0 else ", Signals >= %d" % signal_target
	var chain_target := _junction_chain_target(sc)
	var chain_text := "" if chain_target <= 0 else ", Chain >= %d" % chain_target
	var lean_text := "" if not _efficiency_proof_applies(sc) else ", Lean proof"
	var processor_text := "" if not _processor_proof_applies(sc) else ", Processor proof"
	return "Gold target: Used <= %d, Fleet <= %d, Time <= %.0fs, Wait <= %.0fs, Flow <= %.0fs%s%s%s%s, clean routing. Perfect also needs the bonus." % [
		_reward_material_par(sc),
		_fleet_goal() + 1,
		_reward_time_par(sc),
		float(local.get("wait_target", 0.0)),
		_flow_gap_target(),
		signal_text,
		chain_text,
		lean_text,
		processor_text
	]

func _reward_material_par(sc: Dictionary) -> int:
	var ghost: Array = sc.get("ghost", [])
	var route: Array = sc.get("route", [])
	var track_steps: int = max(0, ghost.size() - 1)
	if track_steps <= 0:
		track_steps = max(6, route.size() * 5)
	var signal_allowance: int = max(2, int(ceil(float(track_steps) / 5.0)))
	var station_allowance: int = max(0, route.size() - 2)
	var par := track_steps * 25 + signal_allowance * 80 + _fleet_goal() * 300 + station_allowance * 200
	return int(round(float(par) * float(sc.get("material_par_multiplier", 1.0))))

func _reward_time_par(sc: Dictionary) -> float:
	var target_amount := float(sc.get("target", local.get("target", 80)))
	var route: Array = sc.get("route", [])
	var route_pressure := float(max(2, route.size())) * 18.0
	var fleet_pressure := float(_fleet_goal()) * 20.0
	return max(75.0, target_amount * 1.45 + route_pressure + fleet_pressure)

func _objective_progress() -> int:
	if _uses_order_mode():
		return int(local.get("productive_progress", 0))
	if local.get("kind", "") == "yard":
		return int(local.get("processed", 0))
	return int(local.get("delivered", 0))

func _completion_progress() -> int:
	return int(local.get("productive_progress", 0))

func _progress_label() -> String:
	return "Contract output"

func _fleet_goal() -> int:
	return max(1, int(local.get("fleet_goal", 1)))

func _fleet_overage() -> int:
	return max(0, _active_train_count() - _fleet_goal())

func _dispatch_speed_factor() -> float:
	var pressure: int = max(0, _fleet_overage() - 1)
	if pressure <= 0:
		return 1.0
	return max(DISPATCH_OVERLOAD_MIN_SPEED, 1.0 - float(pressure) * DISPATCH_OVERLOAD_PER_EXTRA_TRAIN)

func _objective_complete() -> bool:
	if _uses_order_mode():
		return _orders_complete() and _active_train_count() >= _fleet_goal()
	return _completion_progress() >= int(local["target"]) and _active_train_count() >= _fleet_goal()

func _orders_complete() -> bool:
	for order in local.get("orders", []):
		var data: Dictionary = order
		if _order_progress_amount(String(data.get("id", ""))) < int(data.get("amount", 0)):
			return false
	return not (local.get("orders", []) as Array).is_empty()

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
		var clause_summary := _local_contract_hud_clause_text()
		var clause_suffix := "" if clause_summary == "" else " | %s" % clause_summary
		var test_suffix := ""
		if bool(local.get("test_battery_running", false)):
			test_suffix = " | TEST x%d" % int(local.get("test_battery_steps", TEST_BATTERY_START_STEPS))
		top_status.text = "%s | Out %d/%d | Ops $%d | Fleet %d/%d | Grade %s%s%s" % [
			local.get("name", ""),
			_completion_progress(),
			local.get("target", 0),
			_operating_cost(),
			_active_train_count(),
			_fleet_goal(),
			_completion_quality_short_label(_current_completion_quality_grade()),
			clause_suffix,
			test_suffix
		]
	else:
		top_status.text = "Scenario results"

func _refresh_regional_side_text() -> void:
	if side_text == null:
		return
	_ensure_run_state()
	var traits: Dictionary = campaign.get("regional_traits", {})
	var text: String = "[b]Rail Sudoku Roguelike[/b]\n\n"
	text += "A 30-puzzle catalog is split into 10 local feeder, 10 regional pressure, and 10 late-run stress maps. Build the proof locally; unused track and signals set the star multiplier.\n\n"
	text += "Run Progress: %d / %d\n" % [int(campaign.get("run_step", 0)), RUN_LENGTH]
	text += "Adjacent Choices: %d\n" % [(campaign.get("run_available", []) as Array).size()]
	text += "Position: %s\nMoney: $%d\n" % [String(campaign.get("regional_position", REGIONAL_START_KEY)), int(campaign.get("money", 0))]
	text += "Through Traffic: %d\nCapacity Rating: %d\nReliability: %.0f%%\nOperating Surge: %.0f%%\nInspection Debt: %d (L%d)\nCoal: %d  Freight: %d  Steel: %d\n\n" % [
		int(traits.get("through_traffic", 0)),
		int(traits.get("capacity_rating", 0)),
		float(traits.get("reliability", 1.0)) * 100.0,
		float(traits.get("burstiness", 0.0)) * 100.0,
		int(traits.get("inspection_debt", 0)),
		_regional_inspection_level(traits),
		int(traits.get("coal_output", 0)),
		int(traits.get("freight_output", 0)),
		int(traits.get("steel_output", 0))
	]
	text += "%s\n\n" % _regional_pressure_forecast_text(traits)
	text += "%s\n\n" % _regional_grade_overview_text()
	text += "%s\n\n" % _regional_run_momentum_text()
	text += "%s\n\n" % _mastery_record_overview_text()
	text += "[b]Upgrades[/b]\nPermanent: %s\nRun: %s\n\n" % [_upgrade_summary("permanent_upgrades"), _upgrade_summary("run_upgrades")]
	if bool(campaign.get("run_won", false)):
		text += "[color=green][b]Run Complete[/b][/color]\nThe region survived the full %d-map expansion.\n\n" % RUN_LENGTH
	text += "[b]Adjacent Contracts[/b]\n"
	for id in campaign.get("run_available", []):
		var tile := _regional_tile_for_scenario(String(id))
		var s := _get_scenario(String(id))
		if not tile.is_empty() and not s.is_empty():
			var preview_scenario := _apply_run_pressure_to_scenario(s)
			text += "[b]%s[/b] T%d %s\n%s\n%s\n\n" % [
				preview_scenario["name"],
				int(tile.get("tier", 1)),
				String(tile.get("terrain", "plains")).capitalize(),
				preview_scenario["objective"],
				_regional_contract_preview_text(preview_scenario)
			]
	text += "[b]Tutorial Contracts[/b]\n"
	for s in scenarios:
		var id := String(s.get("id", ""))
		if _is_run_scenario_id(id):
			continue
		var state := "Completed" if campaign["completed"].has(id) else ("Available" if _scenario_is_available(id) else "Locked")
		var mastery_badge := _mastery_badge_for_scenario(id)
		if mastery_badge != "":
			state += " (%s)" % mastery_badge
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

func _regional_grade_overview_text() -> String:
	var records: Dictionary = campaign.get("regional_tile_records", {})
	if records.is_empty():
		return "Tile proofs: none yet."
	var counts := {"perfect": 0, "gold": 0, "silver": 0, "bronze": 0, "rough": 0}
	var reward_total := 0
	var pressure_total := 0
	for key in records.keys():
		var record: Dictionary = records[key]
		var grade := String(record.get("grade", "rough"))
		counts[grade] = int(counts.get(grade, 0)) + 1
		reward_total += int(record.get("reward", 0))
		pressure_total += int(record.get("pressure_delta", 0))
	var pressure_text := "+%d" % pressure_total if pressure_total >= 0 else "%d" % pressure_total
	return "Tile proofs: Perfect %d  Gold %d  Silver %d  Bronze %d  Rough %d\nRun rewards: $%d  Pressure delta: %s" % [
		int(counts.get("perfect", 0)),
		int(counts.get("gold", 0)),
		int(counts.get("silver", 0)),
		int(counts.get("bronze", 0)),
		int(counts.get("rough", 0)),
		reward_total,
		pressure_text
	]

func _regional_run_momentum_text() -> String:
	var history: Array = campaign.get("run_history", [])
	if history.is_empty():
		return "Run momentum: no regional clears yet."
	var start_index: int = max(0, history.size() - 3)
	var recent_count := 0
	var gold_plus := 0
	var rough_count := 0
	var inspection_delta := 0
	var pressure_delta := 0
	for i in range(start_index, history.size()):
		var record: Dictionary = history[i]
		recent_count += 1
		var grade := String(record.get("quality_grade", "rough"))
		if grade in ["gold", "perfect"]:
			gold_plus += 1
		if grade == "rough":
			rough_count += 1
		inspection_delta += int(record.get("inspection_delta", 0))
		pressure_delta += int(record.get("pressure_delta", 0))
	var pressure_text := "+%d" % pressure_delta if pressure_delta >= 0 else "%d" % pressure_delta
	var inspection_text := "+%d" % inspection_delta if inspection_delta >= 0 else "%d" % inspection_delta
	if rough_count > 0 or inspection_delta > 0:
		return "Run momentum: risky over last %d - pressure %s, inspection %s. Gold/Perfect clears reduce debt and can earn rebates." % [recent_count, pressure_text, inspection_text]
	if gold_plus == recent_count:
		return "Run momentum: clean over last %d - pressure %s, inspection %s. Keep chasing bonuses while the region is forgiving." % [recent_count, pressure_text, inspection_text]
	return "Run momentum: mixed over last %d - pressure %s, inspection %s. Push the next map toward Gold to avoid a rough spiral." % [recent_count, pressure_text, inspection_text]

func _local_compact_side_text() -> String:
	var lines_out: Array[String] = []
	lines_out.append("[b]%s[/b]  %s %d/%d  Fleet %d/%d  Wait %.0fs  Used %d" % [
		local.get("name", ""),
		_progress_label(),
		_completion_progress(),
		int(local.get("target", 0)),
		_active_train_count(),
		_fleet_goal(),
		_average_wait(),
		int(local.get("infra_cost", 0))
	])
	var mix_text := _service_mix_text(local.get("scenario", {}))
	var orders_text := _compact_order_progress_text()
	var flow_parts: Array[String] = []
	if mix_text != "":
		flow_parts.append("Service Mix: %s" % _short_ui_text(mix_text, 34))
	if orders_text != "":
		flow_parts.append("Orders: %s" % orders_text)
	if not flow_parts.is_empty():
		lines_out.append(_short_ui_text("  |  ".join(flow_parts), 104))
	var contract_title := String((local.get("scenario", {}).get("contract_puzzle", {}) as Dictionary).get("template_name", local.get("name", "Contract")))
	lines_out.append("Contract Clauses: %s  |  Gold target: Used <= %d Fleet <= %d Flow <= %.0fs" % [
		_short_ui_text(contract_title, 24),
		_reward_material_par(local.get("scenario", {})),
		_fleet_goal() + 1,
		_flow_gap_target()
	])
	var issues: Array[String] = []
	if int(local.get("unqualified_output", 0)) > 0:
		issues.append("outside contract")
	if int(local.get("late_order_amount", 0)) > 0:
		issues.append("late orders %d" % int(local.get("late_order_amount", 0)))
	if _active_incompatible_stop_score() > 0:
		issues.append("mixed incompatible stops %d" % _active_incompatible_stop_score())
	if _active_route_bloat_score() > 0:
		issues.append("route +%d" % _active_route_bloat_score())
	if _active_route_repeat_score() > 0:
		issues.append("repeat +%d" % _active_route_repeat_score())
	if _platform_padding_score() > 0:
		issues.append("Platform padding +%d" % _platform_padding_score())
	if _network_sprawl_score(local.get("scenario", {})) > 0:
		issues.append("Rail sprawl +%d" % _network_sprawl_score(local.get("scenario", {})))
	if _fleet_shortfall() > 0:
		issues.append("Fleet shortfall %d" % _fleet_shortfall())
	if _fleet_contribution_shortfall() > 0:
		issues.append("Fleet contribution %d/%d" % [_contributing_train_count(), _fleet_goal()])
	if _dispatch_speed_factor() < 1.0:
		issues.append("Dispatch overload %.0f%%" % (_dispatch_speed_factor() * 100.0))
	if _operating_cost() >= 35:
		issues.append("Ops $%d" % _operating_cost())
	var inspection_preview := _completion_inspection_preview_text(local.get("scenario", {}), _average_wait(), _current_productive_for_grade(_average_wait()))
	if inspection_preview != "":
		issues.append("Inspection risk" if inspection_preview.contains("risk") else "Inspection steady")
	if issues.is_empty():
		lines_out.append("Issues: none blocking")
	else:
		lines_out.append("Issues: %s" % _short_ui_text(", ".join(issues), 86))
	var context_parts: Array[String] = []
	var coach := _grade_coach_text(local.get("scenario", {}), _average_wait(), _current_productive_for_grade(_average_wait()))
	if coach != "":
		context_parts.append("Grade Coach: %s" % _short_ui_text(coach, 58))
	if selected_train_id != "":
		for t in trains:
			if t["id"] == selected_train_id:
				context_parts.append("[b]%s[/b] %s %s -> %s" % [t["id"], _train_class_label(String(t.get("train_class", ""))), _cargo_label(t), _next_stop_name_for_train(t)])
				break
	if selected_signal_pos.x > -900:
		context_parts.append("[b]Signal[/b] %s %s" % [_signal_type(selected_signal_pos), _dir_name(_signal_dir(selected_signal_pos))])
	if local_message != "":
		context_parts.append(_short_ui_text(local_message, 44))
	if not context_parts.is_empty():
		lines_out.append(_short_ui_text("  |  ".join(context_parts), 104))
	return "\n".join(lines_out)

func _compact_order_progress_text() -> String:
	if not _uses_order_mode():
		return ""
	var parts: Array[String] = []
	for order in local.get("orders", []):
		var data: Dictionary = order
		parts.append("%s %d/%d" % [
			_resource_name(String(data.get("cargo", ""))),
			_order_progress_amount(String(data.get("id", ""))),
			int(data.get("amount", 0))
		])
	return _short_ui_text("  ".join(parts), 62)

func _train_class_label(train_class: String) -> String:
	if train_class == "":
		return ""
	return train_class.replace("_", " ").capitalize()

func _refresh_local_side_text() -> void:
	if screen != Screen.LOCAL:
		return
	_update_board_layout()
	if not bool(local.get("debug_details_open", false)):
		if side_text != null:
			side_text.text = _local_compact_side_text()
		_show_toast(local_message)
		_refresh_inspect_chip()
		_refresh_line_picker_bar()
		_refresh_service_edit_bar()
		_update_status_labels()
		_refresh_dispatch_panel()
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
	var contract_detail := _local_contract_detail_text()
	if contract_detail != "":
		text += "%s\n" % contract_detail
	if int(local.get("unqualified_output", 0)) > 0:
		text += "Moved %d cargo outside contract orders. Add the missing stops to count it.\n" % int(local.get("unqualified_output", 0))
	if int(local.get("detour_output", 0)) > 0:
		text += "Detoured %d contract cargo before delivery. Shorter service keeps grade high.\n" % int(local.get("detour_output", 0))
	if float(local.get("detour_dwell", 0.0)) > 0.0:
		text += "Loaded detour stops added %.1fs dwell. Keep contract stops ahead of loopback stops.\n" % float(local.get("detour_dwell", 0.0))
	if int(local.get("excess_mileage", 0)) > 0:
		text += "Loaded trains ran %d extra tiles. Compact routing keeps grade high.\n" % int(local.get("excess_mileage", 0))
	if _active_route_bloat_score() > 0:
		text += "Route has %d extra scheduled stops beyond contract loops. Trim unused circular stops for a better grade.\n" % _active_route_bloat_score()
	if _active_route_repeat_score() > 0:
		text += "Repeated stops add %d catch-all backtracks. Split focused services to keep mastery routes clean.\n" % _active_route_repeat_score()
	var sprawl_score := _network_sprawl_score(local.get("scenario", {}))
	if sprawl_score > 0:
		text += "Rail sprawl is %d tiles over the proof budget. Keep useful sidings; trim map-wide comfort loops for mastery.\n" % sprawl_score
	if _platform_padding_score() > 0:
		text += "Platform padding is %d over the useful capacity allowance. Keep queue-solving platforms; trim comfort padding for mastery.\n" % _platform_padding_score()
	if _operating_cost() >= 35:
		text += "Operating cost $%d comes from train mileage; empty loops add a surcharge.\n" % _operating_cost()
	if _max_output_gap() > _flow_gap_target():
		text += "Flow gap %.0fs exceeds %.0fs target. More frequent useful deliveries improve grade.\n" % [_max_output_gap(), _flow_gap_target()]
	if _fleet_shortfall() > 0:
		text += "Fleet shortfall: add %d train%s to convert progress into a contract clear.\n" % [_fleet_shortfall(), "" if _fleet_shortfall() == 1 else "s"]
	if _fleet_contribution_shortfall() > 0:
		text += "Fleet contribution: %d/%d contract trains have delivered output. Parked trains count for a rough clear, but Gold needs them working.\n" % [_contributing_train_count(), _fleet_goal()]
	if _fleet_overage() > 1:
		text += "Fleet is %d trains above contract target. Extra dispatch can help, but over-fleeting lowers grade.\n" % _fleet_overage()
	if _dispatch_speed_factor() < 1.0:
		text += "Dispatch overload: trains run at %.0f%% speed until extra trains return to stock.\n" % (_dispatch_speed_factor() * 100.0)
	if bool(local.get("test_battery_running", false)):
		text += "Test battery: %d ticks, %d steps/frame. It will stop on win, deadlock, or no-route failure.\n" % [
			int(local.get("test_battery_ticks", 0)),
			int(local.get("test_battery_steps", TEST_BATTERY_START_STEPS))
		]
	if _completion_progress() > 0 and _service_mileage_per_output() > 2.8:
		text += "Service mileage %.1f/output with %.0f%% empty running. Trim return loops for a better grade.\n" % [_service_mileage_per_output(), _empty_mileage_share() * 100.0]
	var inspection_preview := _completion_inspection_preview_text(local.get("scenario", {}), _average_wait(), _current_productive_for_grade(_average_wait()))
	if inspection_preview != "":
		text += "%s\n" % inspection_preview
	var coach := _grade_coach_text(local.get("scenario", {}), _average_wait(), _current_productive_for_grade(_average_wait()))
	if coach != "":
		text += "Grade Coach: %s\n" % coach
	text += "Used %d  Ops $%d  Time %.0fs  Depot %d  Tool %s" % [int(local.get("infra_cost", 0)), _operating_cost(), float(local.get("elapsed_time", 0.0)), _available_train_count(), selected_tool.capitalize()]
	if _is_resource_puzzle(local.get("scenario", {})):
		text += "\nInventory: %s" % _puzzle_resource_summary_text(local.get("scenario", {}))
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
	_refresh_line_picker_bar()
	_refresh_service_edit_bar()
	_update_status_labels()
	_refresh_dispatch_panel()

func _show_toast(message: String) -> void:
	if toast_label == null:
		return
	if side_text != null:
		toast_label.visible = false
		toast_label.text = ""
		return
	toast_label.visible = message != ""
	toast_label.text = _short_ui_text(message, 96)

func _refresh_inspect_chip() -> void:
	if inspect_chip == null:
		return
	inspect_chip.text = ""
	inspect_chip.visible = false

func _local_contract_clause_text() -> String:
	return _local_contract_detail_text()

func _local_contract_hud_clause_text() -> String:
	if screen != Screen.LOCAL or local.is_empty() or not local.has("scenario"):
		return ""
	var sc: Dictionary = local.get("scenario", {})
	var puzzle: Dictionary = sc.get("contract_puzzle", {})
	var parts: Array[String] = []
	if not puzzle.is_empty():
		parts.append(_short_ui_text(String(puzzle.get("template_name", "Rail Sudoku")), 18))
	var mix := _service_mix_text(sc)
	if mix != "":
		parts.append(_short_ui_text(mix, 22))
	if _is_resource_puzzle(sc):
		parts.append(_short_ui_text(_puzzle_resource_summary_text(sc), 30))
	var contract_clause: Dictionary = sc.get("contract_clause", {})
	if not contract_clause.is_empty():
		parts.append(String(contract_clause.get("name", "Clause")))
	if int(sc.get("bonus_money", 0)) > 0:
		parts.append("Bonus +$%d" % int(sc.get("bonus_money", 0)))
	return " | ".join(parts)

func _local_contract_detail_text() -> String:
	if screen != Screen.LOCAL or local.is_empty() or not local.has("scenario"):
		return ""
	var sc: Dictionary = local.get("scenario", {})
	var clauses: Array[String] = []
	var puzzle: Dictionary = sc.get("contract_puzzle", {})
	var title := String(puzzle.get("template_name", "Rail Sudoku")) if not puzzle.is_empty() else String(sc.get("name", "Contract"))
	clauses.append("[b]Contract Clauses[/b]  %s" % _short_ui_text(title, 28))
	clauses.append("Goal: %d/%d %s | Fleet %d | Wait %.0fs" % [
		_completion_progress(),
		int(local.get("target", 0)),
		_progress_label(),
		_fleet_goal(),
		float(local.get("wait_target", 0.0))
	])
	var mix_text := _service_mix_text(sc)
	if mix_text != "":
		clauses.append("Service Mix: %s" % mix_text)
	var route: Array = sc.get("route", [])
	if not route.is_empty():
		clauses.append("Stops: %s" % _short_ui_text(_route_station_names(_unique_route_stops(route)), 56))
	if _is_resource_puzzle(sc):
		clauses.append("Resources: %s | Live rank %s" % [
			_puzzle_resource_summary_text(sc),
			_puzzle_star_label(_puzzle_star_rank(sc, _current_productive_for_grade(_average_wait())))
		])
		var variants: Array = sc.get("solution_variants", [])
		if variants.size() >= 2:
			clauses.append("Multiple solutions: %d authored route families fit this map." % variants.size())
	var contract_clause: Dictionary = sc.get("contract_clause", {})
	if not contract_clause.is_empty():
		var clause_type := String(contract_clause.get("type", ""))
		var clause_hint := _short_ui_text(String(contract_clause.get("desc", "")), 42)
		if clause_type == "express_flow":
			clause_hint = "keep delivery gaps tight"
		elif clause_type == "lean_build":
			clause_hint = "material par is tight"
		elif clause_type == "clean_returns":
			clause_hint = "limit empty running"
		elif clause_type == "compact_network":
			clause_hint = "avoid rail sprawl"
		clauses.append("%s: %s" % [
			String(contract_clause.get("name", "Clause")),
			clause_hint
		])
	var bonus_challenge := _contract_bonus_challenge_text(sc)
	if bonus_challenge != "":
		clauses.append("Bonus Challenge: +$%d | Perfect needs bonus." % int(sc.get("bonus_money", 0)))
	clauses.append("Gold target: Used <= %d, Fleet <= %d, Flow <= %.0fs; clean routing. Perfect bonus." % [
		_reward_material_par(sc),
		_fleet_goal() + 1,
		_flow_gap_target()
	])
	if not puzzle.is_empty():
		clauses.append(_compact_contract_proof_text(sc))
	elif _contract_trip_proof_text(sc) != "":
		clauses.append("Trip proof: required stops in order; handoff shuttles stay sandbox")
	var bonus_coach := _contract_bonus_coach_text(sc, _average_wait(), _current_productive_for_grade(_average_wait()))
	if bonus_coach != "":
		clauses.append(_short_ui_text(bonus_coach, 72))
	var pressure_text := _regional_contract_pressure_text(sc)
	if pressure_text != "":
		clauses.append(_short_ui_text(pressure_text, 84))
	var streak_text := _regional_mastery_streak_preview_text(sc)
	if streak_text != "":
		clauses.append(_short_ui_text(streak_text, 84))
	var inspection_preview := _completion_inspection_preview_text(sc, _average_wait(), _current_productive_for_grade(_average_wait()))
	if inspection_preview != "":
		clauses.append(_short_ui_text(inspection_preview, 84))
	clauses.append("Grade Coach: %s" % _grade_coach_text(sc, _average_wait(), _current_productive_for_grade(_average_wait())))
	clauses.append("Compact service: detours, extra stops, and empty loops lower payout.")
	return "\n".join(clauses)

func _compact_contract_proof_text(sc: Dictionary) -> String:
	var proof: Array[String] = []
	var passing_target := _passing_capacity_target(sc)
	if passing_target > 0:
		proof.append("Signal proof: %d/%d" % [_signal_gate_count(), passing_target])
	var junction_target := _junction_chain_target(sc)
	if junction_target > 0:
		proof.append("Junction proof: %d/%d" % [_chain_signal_gate_count(), junction_target])
	if _efficiency_proof_applies(sc):
		proof.append("Lean proof: %d issue%s" % [_efficiency_proof_missing(sc), "" if _efficiency_proof_missing(sc) == 1 else "s"])
	if _processor_proof_applies(sc):
		proof.append("Processor proof: %d/2" % _processor_proof_satisfied_count(sc))
		proof.append("Trip proof: handoff shuttles stay sandbox; split shuttles count only through those handoffs")
	elif _contract_trip_proof_text(sc) != "":
		proof.append("Trip proof: required stops in order; handoff shuttles stay sandbox")
	if proof.is_empty():
		return "Proof: required stops in order"
	return " | ".join(proof)

func _unique_route_stops(route: Array) -> Array[String]:
	var unique: Array[String] = []
	for raw_id in route:
		var station_id := String(raw_id)
		if not unique.has(station_id):
			unique.append(station_id)
	return unique

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
	inspect_chip.text = ""
	inspect_chip.visible = false
	if text != "":
		_show_toast(_short_ui_text(_strip_bbcode(text).replace("\n", "  "), 96))

func _strip_bbcode(text: String) -> String:
	return text.replace("[b]", "").replace("[/b]", "").replace("[color=green]", "").replace("[color=orange]", "").replace("[/color]", "")

func _refresh_line_picker_bar() -> void:
	if line_picker_scroll == null or line_picker_row == null:
		return
	_clear_control_children(line_picker_row)
	var line_ids: Array[String] = _visible_service_line_ids()
	line_picker_scroll.visible = not line_ids.is_empty()
	if side_text != null:
		var picker_height: float = _scaled(30.0) if line_picker_scroll.visible else 0.0
		side_text.custom_minimum_size = Vector2(0, max(_scaled(32.0), _local_tray_height() - _scaled(40.0) - picker_height))
	if line_ids.is_empty():
		return
	for line_id in line_ids:
		var button := Button.new()
		button.text = _line_picker_chip_text(line_id)
		button.tooltip_text = _line_picker_tooltip_text(line_id)
		button.custom_minimum_size = Vector2(_scaled(84.0), _scaled(28.0))
		button.pressed.connect(func(id := line_id): _edit_line_from_picker(id))
		_style_line_chip_button(button, _line_color(line_id), line_id == selected_line_id)
		line_picker_row.add_child(button)

func _line_picker_chip_text(line_id: String) -> String:
	if not lines.has(line_id):
		return "Line"
	var line: Dictionary = lines[line_id]
	var ordinal: int = int(line.get("ordinal", 1))
	var route: Array = line.get("route", [])
	return "L%d %s %d" % [ordinal, _service_class_chip(String(line.get("service_class", ""))), route.size()]

func _service_class_chip(service_class: String) -> String:
	if service_class == "passenger_express":
		return "PX"
	if service_class == "passenger_local":
		return "P"
	if service_class == "heavy_freight":
		return "HF"
	return "F"

func _line_picker_tooltip_text(line_id: String) -> String:
	if not lines.has(line_id):
		return ""
	var line: Dictionary = lines[line_id]
	var route: Array = line.get("route", [])
	return "%s: %s" % [String(line.get("name", "Service")), _route_station_names(route, true) if not route.is_empty() else "tap station +"]

func _style_line_chip_button(button: Button, color: Color, selected: bool) -> void:
	var fill := Color(color.r, color.g, color.b, 0.98 if selected else 0.78)
	var border := Color.html("#172028")
	button.add_theme_stylebox_override("normal", _flat_style(fill, border, 2 if selected else 1, 6))
	button.add_theme_stylebox_override("hover", _flat_style(fill.lightened(0.12), border, 2, 6))
	button.add_theme_stylebox_override("pressed", _flat_style(fill.lightened(0.22), border, 2, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", _scaled_font(12))
	button.add_theme_color_override("font_color", Color.html("#172028"))
	button.add_theme_color_override("font_hover_color", Color.html("#172028"))
	button.add_theme_color_override("font_pressed_color", Color.html("#172028"))
	button.add_theme_color_override("font_focus_color", Color.html("#172028"))

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
		if state == "DetourStop":
			return "Extra dwell at an unnecessary loaded stop."
		if state in ["Loading", "Unloading", "Processing", "StationStop"]:
			return "Station dwell in progress."
		var next_issue := _next_move_issue_for_train(t)
		if next_issue != "":
			return next_issue
		return "Moving normally."
	if state == "YardStop":
		return "Working through the yard stop. Next move: %s" % reason
	if state == "DetourStop":
		return "Extra dwell at an unnecessary loaded stop. Next move: %s" % reason
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
	if art_texture and size.x >= 1500.0:
		var art_size := Vector2(_scaled(300.0), _scaled(300.0))
		var art_x: float = size.x - _regional_side_panel_width() - art_size.x - _scaled(30.0)
		draw_texture_rect(art_texture, Rect2(Vector2(max(_regional_tutorial_rail_width(), art_x), size.y - art_size.y - _scaled(28.0)), art_size), false, Color(1, 1, 1, 0.22))
	_draw_regional_tile_map()
	for s in _tutorial_regional_scenarios():
		var id := String(s["id"])
		var p := _regional_node_position(id)
		var completed: bool = campaign["completed"].has(id)
		var available: bool = _scenario_is_available(id)
		var col: Color = Color.html("#78d891") if completed else (Color.html("#ffe06d") if available else Color.html("#a5afb4"))
		var draw_size := Vector2(_scaled(76.0), _scaled(76.0))
		if not _draw_piece(game_regional_node_texture, p, draw_size, 0.0, col):
			draw_circle(p, _scaled(38.0), col)
			draw_circle(p, _scaled(32.0), Color(1, 1, 1, 0.38))
		_draw_map_label(p + Vector2(-_scaled(58.0), _scaled(48.0)), String(s["name"]), _scaled(116.0), _scaled_font(13))
		var status := "Click" if available else ("Done" if completed else "Locked")
		_draw_map_label(p + Vector2(-_scaled(42.0), _scaled(66.0)), status, _scaled(84.0), _scaled_font(12), Color(1.0, 0.98, 0.84, 1.0))

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
			_draw_map_label(rect.position + Vector2(_scaled(3.0), rect.size.y - _scaled(24.0)), "T%d" % int(tile.get("tier", 1)), rect.size.x - _scaled(6.0), max(_scaled_font(12), int(rect.size.x * 0.12)), Color.html("#ffe06d"))
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
	if cargo == PASSENGER_CARGO:
		return Color.html("#f7a8d8")
	if cargo == "coal":
		return Color.html("#d8d2bd")
	if cargo == "freight":
		return Color.html("#f2c36b")
	if cargo == "timber":
		return Color.html("#c99b62")
	if cargo == "iron":
		return Color.html("#aeb6bf")
	if cargo == "steel":
		return Color.html("#bfe3f6")
	return Color.html("#eef3e8")

func _resource_name(cargo: String) -> String:
	if cargo == PASSENGER_CARGO:
		return "PAX"
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
	_draw_service_line_overlays()
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

func _draw_service_line_overlays() -> void:
	var line_ids: Array[String] = _visible_service_line_ids()
	var total: int = line_ids.size()
	for i in range(total):
		var line_id: String = line_ids[i]
		var selected := line_id == selected_line_id
		var color := _line_color_for_index(i)
		var lane_offset := _service_line_lane_offset(i, total)
		_draw_service_line_overlay(line_id, color, lane_offset, selected)

func _visible_service_line_ids() -> Array[String]:
	var line_ids: Array[String] = []
	for raw_line_id in lines.keys():
		var line_id := String(raw_line_id)
		var line: Dictionary = lines[line_id]
		var route: Array = line.get("route", [])
		if route.size() >= 2:
			line_ids.append(line_id)
	line_ids.sort()
	return line_ids

func _line_color(line_id: String) -> Color:
	var line_ids: Array[String] = _visible_service_line_ids()
	var index: int = line_ids.find(line_id)
	if index < 0:
		index = 0
	return _line_color_for_index(index)

func _line_color_for_index(index: int) -> Color:
	var palette: Array[Color] = [
		Color.html("#14b8a6"),
		Color.html("#f59e0b"),
		Color.html("#ec4899"),
		Color.html("#3b82f6"),
		Color.html("#84cc16"),
		Color.html("#ef4444"),
		Color.html("#8b5cf6"),
		Color.html("#06b6d4")
	]
	return palette[index % palette.size()]

func _service_line_lane_offset(index: int, total: int) -> float:
	if total <= 1:
		return 0.0
	var centered: float = float(index) - (float(total) - 1.0) * 0.5
	return clamp(centered, -3.0, 3.0) * max(4.0, cell_size * 0.075)

func _draw_service_line_overlay(line_id: String, color: Color, lane_offset: float, selected: bool) -> void:
	if not lines.has(line_id):
		return
	var line: Dictionary = lines[line_id]
	var route: Array = line.get("route", [])
	for i in range(route.size() - 1):
		var from_station_id := String(route[i])
		var to_station_id := String(route[i + 1])
		if not station_by_id.has(from_station_id) or not station_by_id.has(to_station_id):
			continue
		var from_pos: Vector2i = station_by_id[from_station_id]["pos"]
		var to_pos: Vector2i = station_by_id[to_station_id]["pos"]
		if from_pos == to_pos:
			continue
		var path: Array[Vector2i] = _find_track_path_ignore_signals(from_pos, to_pos)
		if path.is_empty():
			_draw_service_line_direct_hint(from_pos, to_pos, color, lane_offset, selected)
		else:
			_draw_service_line_path(from_pos, path, color, lane_offset, selected)
	_draw_service_line_stop_markers(route, color, lane_offset, selected)

func _draw_service_line_path(start_tile: Vector2i, path: Array[Vector2i], color: Color, lane_offset: float, selected: bool) -> void:
	var previous := start_tile
	for next in path:
		_draw_service_line_segment(previous, next, color, lane_offset, selected, true)
		previous = next

func _draw_service_line_segment(a_tile: Vector2i, b_tile: Vector2i, color: Color, lane_offset: float, selected: bool, connected: bool) -> void:
	var a := _grid_to_screen(a_tile)
	var b := _grid_to_screen(b_tile)
	var delta := b - a
	if delta.length_squared() <= 0.1:
		return
	var dir := delta.normalized()
	var side := Vector2(-dir.y, dir.x)
	var offset := side * lane_offset
	var width: float = max(4.0, cell_size * (0.088 if selected else 0.064))
	var alpha: float = 0.9 if selected else 0.72
	if not connected:
		alpha *= 0.42
	var line_color := Color(color.r, color.g, color.b, alpha)
	draw_line(a + offset, b + offset, Color(0.04, 0.07, 0.09, alpha * 0.82), width + max(3.0, cell_size * 0.045), true)
	draw_line(a + offset, b + offset, line_color, width, true)

func _draw_service_line_direct_hint(a_tile: Vector2i, b_tile: Vector2i, color: Color, lane_offset: float, selected: bool) -> void:
	var a := _grid_to_screen(a_tile)
	var b := _grid_to_screen(b_tile)
	var delta := b - a
	if delta.length_squared() <= 0.1:
		return
	var dir := delta.normalized()
	var side := Vector2(-dir.y, dir.x)
	var offset := side * lane_offset
	var start := a + offset
	var end := b + offset
	var length: float = start.distance_to(end)
	var dash_len: float = max(12.0, cell_size * 0.2)
	var gap_len: float = max(7.0, cell_size * 0.11)
	var cursor := 0.0
	while cursor < length:
		var segment_end: float = min(length, cursor + dash_len)
		var p0 := start.lerp(end, cursor / length)
		var p1 := start.lerp(end, segment_end / length)
		draw_line(p0, p1, Color(0.04, 0.07, 0.09, 0.35), max(5.0, cell_size * 0.07), true)
		draw_line(p0, p1, Color(color.r, color.g, color.b, 0.42 if selected else 0.28), max(3.0, cell_size * 0.045), true)
		cursor += dash_len + gap_len

func _draw_service_line_stop_markers(route: Array, color: Color, lane_offset: float, selected: bool) -> void:
	var seen: Dictionary = {}
	var radius: float = max(9.0, cell_size * (0.19 if selected else 0.15))
	for raw_station_id in route:
		var station_id := String(raw_station_id)
		if seen.has(station_id) or not station_by_id.has(station_id):
			continue
		seen[station_id] = true
		var center: Vector2 = _grid_to_screen(station_by_id[station_id]["pos"]) + Vector2(lane_offset * 0.35, -lane_offset * 0.35)
		draw_circle(center, radius + 2.0, Color(0.04, 0.07, 0.09, 0.5 if selected else 0.36), false, max(2.0, cell_size * 0.04))
		draw_circle(center, radius, Color(color.r, color.g, color.b, 0.86 if selected else 0.62), false, max(2.0, cell_size * 0.035))

func _draw_stations() -> void:
	var badge_layout := _station_resource_badge_layout()
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
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		var c := _grid_to_screen(st["pos"])
		var label_size := int(max(14.0, cell_size * 0.24))
		_draw_map_label(c + Vector2(-cell_size * 1.04, cell_size * 0.7), String(st["name"]), cell_size * 2.08, label_size)
		if selected_tool == "train" and st.get("role", "") == "source":
			_draw_map_label(c + Vector2(-cell_size * 0.9, -cell_size * 1.04), "BUY HERE", cell_size * 1.8, int(max(13.0, cell_size * 0.22)), Color.html("#ffe06d"))
		if int(st.get("platforms", 1)) > 1:
			_draw_map_label(c + Vector2(-cell_size * 0.45, -cell_size * 0.94), "P%d" % int(st["platforms"]), cell_size * 0.9, label_size)
		_draw_station_resource_badges(st, badge_layout.get(String(id), {}))
		if editing_line_stops and selected_line_id != "" and lines.has(selected_line_id):
			_draw_station_add_handle(st["pos"])

func _draw_station_resource_badges(st: Dictionary, placed_badges: Dictionary) -> void:
	var out_text := _station_output_badge_text(st)
	var need_text := _station_need_badge_text(st)
	if out_text != "" and placed_badges.has("out"):
		var cargo := String(st.get("produces", ""))
		var rect: Rect2 = placed_badges["out"]
		_draw_station_resource_badge(rect.position, out_text, _resource_color(cargo), false)
	if need_text != "" and placed_badges.has("need"):
		var accepts: Array = st.get("accepts", [])
		var cargo := String(accepts[0]) if not accepts.is_empty() else ""
		var rect: Rect2 = placed_badges["need"]
		_draw_station_resource_badge(rect.position, need_text, _resource_color(cargo), true)

func _station_resource_badge_layout() -> Dictionary:
	var reserved := _station_label_base_reservations()
	_append_station_fixed_label_reservations(reserved)
	var layout := {}
	var pad := _station_label_gap()
	for id in station_by_id.keys():
		var station_id := String(id)
		var st: Dictionary = station_by_id[id]
		var center := _grid_to_screen(st["pos"])
		var station_badges := {}
		if _station_output_badge_text(st) != "":
			var out_rect := _place_station_resource_badge(center, "out", reserved)
			station_badges["out"] = out_rect
			reserved.append(out_rect.grow(pad))
		if _station_need_badge_text(st) != "":
			var need_rect := _place_station_resource_badge(center, "need", reserved)
			station_badges["need"] = need_rect
			reserved.append(need_rect.grow(pad))
		if not station_badges.is_empty():
			layout[station_id] = station_badges
	return layout

func _station_label_base_reservations() -> Array:
	var reserved: Array = []
	var core_size := Vector2(cell_size * 1.5, cell_size * 1.5)
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		var center := _grid_to_screen(st["pos"])
		reserved.append(Rect2(center - core_size * 0.5, core_size))
	return reserved

func _append_station_fixed_label_reservations(reserved: Array) -> void:
	for id in station_by_id.keys():
		var st: Dictionary = station_by_id[id]
		var center := _grid_to_screen(st["pos"])
		var label_size := int(max(14.0, cell_size * 0.24))
		reserved.append(_map_label_rect(center + Vector2(-cell_size * 1.04, cell_size * 0.7), cell_size * 2.08, label_size).grow(_station_label_gap()))
		if selected_tool == "train" and st.get("role", "") == "source":
			reserved.append(_map_label_rect(center + Vector2(-cell_size * 0.9, -cell_size * 1.04), cell_size * 1.8, int(max(13.0, cell_size * 0.22))).grow(_station_label_gap()))
		if int(st.get("platforms", 1)) > 1:
			reserved.append(_map_label_rect(center + Vector2(-cell_size * 0.45, -cell_size * 0.94), cell_size * 0.9, label_size).grow(_station_label_gap()))

func _map_label_rect(draw_pos: Vector2, width: float, label_font_size: int) -> Rect2:
	var height: float = float(label_font_size) + max(6.0, cell_size * 0.08)
	return Rect2(draw_pos + Vector2(0.0, -float(label_font_size)), Vector2(width, height))

func _station_label_gap() -> float:
	return max(4.0, cell_size * 0.06)

func _place_station_resource_badge(center: Vector2, kind: String, reserved: Array) -> Rect2:
	var badge_size: Vector2 = _station_resource_badge_size()
	var candidates: Array = _station_resource_badge_offsets(kind, badge_size)
	var bounds: Rect2 = _station_label_view_bounds()
	var first_offset: Vector2 = candidates[0]
	var best_rect: Rect2 = _clamped_label_rect(Rect2(center + first_offset, badge_size), bounds)
	var best_score: float = 1.0e20
	for i in range(candidates.size()):
		var offset: Vector2 = candidates[i]
		var raw_rect: Rect2 = Rect2(center + offset, badge_size)
		var rect: Rect2 = _clamped_label_rect(raw_rect, bounds)
		var score: float = _label_overlap_score(rect, reserved) * 1000.0
		score += rect.position.distance_to(raw_rect.position) * 0.5
		score += float(i)
		if score < best_score:
			best_score = score
			best_rect = rect
		if _label_overlap_score(rect, reserved) <= 0.0:
			return rect
	return best_rect

func _station_resource_badge_offsets(kind: String, badge_size: Vector2) -> Array:
	var gap: float = _station_label_gap()
	var side_gap: float = max(8.0, cell_size * 0.14)
	var core_y: float = cell_size * 0.75
	var top_y: float = -core_y - badge_size.y - gap
	var bottom_y: float = core_y + gap
	var mid_y: float = -badge_size.y * 0.5
	var left_x: float = -badge_size.x - side_gap
	var right_x: float = side_gap
	var center_x: float = -badge_size.x * 0.5
	var far_left_x: float = -badge_size.x - cell_size * 0.72
	var far_right_x: float = cell_size * 0.72
	var offsets: Array = []
	if kind == "need":
		offsets = [
			Vector2(right_x, top_y),
			Vector2(left_x, top_y),
			Vector2(center_x, top_y),
			Vector2(right_x, bottom_y),
			Vector2(left_x, bottom_y),
			Vector2(center_x, bottom_y),
			Vector2(far_right_x, mid_y),
			Vector2(far_left_x, mid_y)
		]
	else:
		offsets = [
			Vector2(left_x, top_y),
			Vector2(right_x, top_y),
			Vector2(center_x, top_y),
			Vector2(left_x, bottom_y),
			Vector2(right_x, bottom_y),
			Vector2(center_x, bottom_y),
			Vector2(far_left_x, mid_y),
			Vector2(far_right_x, mid_y)
		]
	var row_step: float = badge_size.y + gap
	for row in range(1, 4):
		offsets.append(Vector2(left_x, top_y - row_step * float(row)))
		offsets.append(Vector2(right_x, top_y - row_step * float(row)))
		offsets.append(Vector2(center_x, top_y - row_step * float(row)))
		offsets.append(Vector2(left_x, bottom_y + row_step * float(row)))
		offsets.append(Vector2(right_x, bottom_y + row_step * float(row)))
		offsets.append(Vector2(center_x, bottom_y + row_step * float(row)))
	return offsets

func _station_label_view_bounds() -> Rect2:
	var margin: float = max(4.0, _scaled(4.0))
	var bottom: float = size.y - margin
	if screen == Screen.LOCAL and side_panel != null:
		bottom = min(bottom, size.y + side_panel.offset_top - margin)
	var top: float = margin
	var width: float = max(1.0, size.x - margin * 2.0)
	var height: float = max(1.0, bottom - top)
	return Rect2(Vector2(margin, top), Vector2(width, height))

func _clamped_label_rect(rect: Rect2, bounds: Rect2) -> Rect2:
	var max_x: float = max(bounds.position.x, bounds.position.x + bounds.size.x - rect.size.x)
	var max_y: float = max(bounds.position.y, bounds.position.y + bounds.size.y - rect.size.y)
	var x: float = clamp(rect.position.x, bounds.position.x, max_x)
	var y: float = clamp(rect.position.y, bounds.position.y, max_y)
	return Rect2(Vector2(x, y), rect.size)

func _label_overlap_score(rect: Rect2, reserved: Array) -> float:
	var total := 0.0
	for raw_other in reserved:
		var other: Rect2 = raw_other
		total += _rect_overlap_area(rect, other)
	return total

func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = max(a.position.x, b.position.x)
	var top: float = max(a.position.y, b.position.y)
	var right: float = min(a.position.x + a.size.x, b.position.x + b.size.x)
	var bottom: float = min(a.position.y + a.size.y, b.position.y + b.size.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)

func _draw_station_resource_badge(pos: Vector2, text: String, fill: Color, outlined: bool) -> void:
	var badge_size := _station_resource_badge_size()
	var rect := Rect2(pos, badge_size)
	draw_rect(rect.grow(2.0), Color(0.04, 0.08, 0.1, 0.78))
	draw_rect(rect, fill)
	if outlined:
		draw_rect(rect.grow(-3.0), Color(1, 1, 1, 0.0), false, 2.0)
	draw_rect(rect, Color.html("#172028"), false, 1.5)
	draw_string(font, rect.position + Vector2(0, badge_size.y - 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, badge_size.x, int(max(10.0, cell_size * 0.18)), Color.html("#172028"))

func _station_resource_badge_size() -> Vector2:
	return Vector2(max(88.0, cell_size * 1.72), max(22.0, cell_size * 0.36))

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

func _draw_train_unit(center: Vector2, rotation: float, body: Color, waiting: bool, is_car: bool = false) -> void:
	var draw_size := Vector2(cell_size * (0.82 if is_car else 0.96), cell_size * (0.44 if is_car else 0.5))
	if not _draw_piece(game_train_texture, center, draw_size, rotation, body):
		draw_rect(Rect2(center - draw_size * 0.5, draw_size), Color.html("#b86945") if is_car else (Color.html("#e84f4f") if waiting else Color.html("#2d7dd2")))
		draw_rect(Rect2(center - draw_size * 0.5, draw_size), Color.html("#172028"), false, 2)
		draw_circle(center + Vector2(-draw_size.x * 0.28, draw_size.y * 0.58), cell_size * 0.07, Color.html("#172028"))
		draw_circle(center + Vector2(draw_size.x * 0.28, draw_size.y * 0.58), cell_size * 0.07, Color.html("#172028"))

func _draw_trains() -> void:
	for t in trains:
		if not _is_train_on_map(t):
			continue
		var p: Vector2 = t["pos"]
		var waiting: bool = String(t.get("state", "")).begins_with("Waiting") or t.get("state", "") == "Blocked" or t.get("state", "") == "NoRoute"
		var body: Color = Color(1, 1, 1, 1)
		if waiting:
			body = Color(1.25, 0.82, 0.82, 1)
		elif t.get("cargo", "") == PASSENGER_CARGO:
			body = Color.html("#f7a8d8")
		elif t.get("cargo", "") == "coal":
			body = Color(0.78, 0.78, 0.74, 1)
		elif t.get("cargo", "") == "timber":
			body = Color.html("#c99b62")
		elif t.get("cargo", "") == "iron":
			body = Color.html("#aeb6bf")
		elif t.get("cargo", "") == "steel":
			body = Color(0.78, 0.9, 1.0, 1)
		var dir: Vector2 = t.get("dir", Vector2.RIGHT)
		if dir.length_squared() <= 0.0:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var rot := dir.angle()
		var car_count: int = max(1, int(t.get("car_count", 1)))
		for car_index in range(car_count - 1, 0, -1):
			var car_pos := p - dir * cell_size * 0.58 * float(car_index)
			_draw_train_unit(car_pos, rot, body.darkened(0.08), waiting, true)
		_draw_train_unit(p, rot, body, waiting, false)
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
