extends Control
## The campaign line map. Stops unlock in order.

signal back
signal play_level(index: int)
signal open_daily

var save: Save
var _scroll: ScrollContainer
var _map: Drawn.LineMap


func _init(s: Save) -> void:
	save = s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.ENAMEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := Pal.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	var bar := Pal.top_bar("LINE 1 · " + Levels.LINE_NAME.to_upper())
	v.add_child(bar.root)
	var back_btn := Pal.button("‹ Home", "bar", 30)
	back_btn.pressed.connect(func(): back.emit())
	bar.left.add_child(back_btn)
	var stars := Pal.hbox(8)
	stars.alignment = BoxContainer.ALIGNMENT_END
	var star := Drawn.Stars.new(1, 30, 1)
	star.custom_minimum_size = Vector2(30, 30)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.add_child(star)
	stars.add_child(Pal.label("%d" % save.total_stars(), 32, "bold", Pal.BEZEL_TEXT))
	bar.right.add_child(stars)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(_scroll)
	var col := Drawn.Column.new(640)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size.y = Levels.count() * Drawn.LineMap.STEP + 160
	_scroll.add_child(col)
	_map = Drawn.LineMap.new(save)
	_map.stop_pressed.connect(func(i): play_level.emit(i))
	col.add_child(_map)

	var strip_wrap := MarginContainer.new()
	for side in ["left", "right", "bottom", "top"]:
		strip_wrap.add_theme_constant_override("margin_" + side, 24)
	v.add_child(strip_wrap)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Pal.box(Pal.TICKET, 26, Color.TRANSPARENT, 0, Vector4(32, 18, 18, 18)))
	strip_wrap.add_child(strip)
	var row := Pal.hbox()
	strip.add_child(row)
	var info := Pal.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var day := DailyGen.today()
	info.add_child(Pal.label("DAILY LINE " + DailyGen.number_label(day), 24, "display", Pal.TICKET_SOFT))
	var status := "Not played yet today"
	if save.daily(day).solved:
		status = "Solved today"
	elif save.daily_finished(day):
		status = "Out of departures"
	elif not save.daily(day).rows.is_empty():
		status = "In progress"
	info.add_child(Pal.label(status, 28, "semi"))
	row.add_child(info)
	var board := Pal.button("BOARD", "ticket", 32)
	board.custom_minimum_size = Vector2(170, 80)
	board.pressed.connect(func(): open_daily.emit())
	row.add_child(board)

	_scroll_to_current.call_deferred()


func _scroll_to_current() -> void:
	await get_tree().process_frame
	var i := mini(save.next_level_index(), Levels.count() - 1)
	var y := _map.stop_pos(i).y - _scroll.size.y * 0.55
	_scroll.scroll_vertical = int(maxf(0, y))
