extends Control
## Plays one puzzle: a campaign stop or today's Daily Line.

signal back
signal next_level(index: int)

var save: Save
var mode := "level"
var index := 0
var day := 0

var pz: Puzzle
var lay := Layout.new()
var undo: Array = []
var board: BoardView
var tool_buttons := {}
var track_label: Label
var stars: Drawn.Stars
var depart_btn: Button
var info_box: VBoxContainer
var rows_view: Drawn.ResultRows
var toast: PanelContainer
var toast_label: Label
var _toast_tween: Tween
var _overlay := {}
var _countdown: Label
var _run := {}


func _init(s: Save, play_mode: String, which: int) -> void:
	save = s
	mode = play_mode
	if mode == "daily":
		day = which
	else:
		index = which


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == "daily":
		pz = DailyGen.generate(day)
		var saved: Dictionary = save.daily(day).layout
		if not saved.is_empty():
			lay = Layout.from_dict(saved)
	else:
		pz = Levels.load_level(index)
		var saved := save.level_layout(pz.id)
		if not saved.is_empty():
			lay = Layout.from_dict(saved)
	_build()
	_refresh()
	if mode == "daily" and save.daily_finished(day):
		board.editable = false
		_show_daily_result.call_deferred()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Pal.ENAMEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := Pal.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var eyebrow := "STOP %d" % (index + 1) if mode == "level" else "DAILY LINE " + DailyGen.number_label(day)
	var title := pz.name.to_upper() if mode == "level" else DailyGen.date_label(day)
	var bar := Pal.top_bar(title, eyebrow)
	root.add_child(bar.root)
	var back_btn := Pal.button("‹ Map" if mode == "level" else "‹ Home", "bar", 30)
	back_btn.pressed.connect(func(): back.emit())
	bar.left.add_child(back_btn)
	var clear_btn := Pal.button("Clear", "bar", 30)
	clear_btn.pressed.connect(_clear)
	bar.right.add_child(clear_btn)

	var col := Drawn.Column.new(760)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(col)
	var v := Pal.vbox(18)
	col.add_child(v)
	v.add_child(_spacer(6))

	var deps := Pal.hbox(14)
	var dl := Pal.label("DEPARTURES", 24, "display", Pal.INK_SOFT)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deps.add_child(dl)
	for dp in pz.depots:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Pal.box(Pal.WELL, 14, Color.TRANSPARENT, 0, Vector4(12, 8, 12, 8)))
		chip.add_child(Drawn.TrainRow.new(dp.trains, 40))
		deps.add_child(chip)
	v.add_child(deps)

	board = BoardView.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size.y = 360
	board.edited.connect(_on_edited)
	board.hint.connect(show_toast)
	board.playback_finished.connect(_on_playback_finished)
	v.add_child(board)
	board.setup(pz, lay)

	var status := Pal.hbox()
	track_label = Pal.label("", 30, "semi")
	track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(track_label)
	stars = Drawn.Stars.new(3, 32)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(stars)
	v.add_child(status)

	var info := Pal.card(Pal.WELL, 24, 22)
	info_box = Pal.vbox(8)
	info.add_child(info_box)
	if mode == "daily":
		var row := Pal.hbox(20)
		rows_view = Drawn.ResultRows.new(save.daily(day).rows, 26, 0)
		rows_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rows_view)
		var txt := Pal.wrap_label("Six departures to get every train to its platform. Each one adds a row to your result.", 26, "body", Pal.INK_SOFT)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		info_box.add_child(row)
		v.add_child(info)
	elif pz.intro_title != "":
		info_box.add_child(Pal.label(pz.intro_title, 30, "bold"))
		info_box.add_child(Pal.wrap_label(pz.intro_text, 26, "body", Pal.INK_SOFT))
		v.add_child(info)

	var tools := GridContainer.new()
	tools.columns = 4
	tools.add_theme_constant_override("h_separation", 14)
	for spec in [["track", "Track"], ["signal", "Signal"], ["erase", "Erase"], ["undo", "Undo"]]:
		var b := Pal.button(spec[1], "tool", 30)
		b.custom_minimum_size.y = 92
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = spec[0]
		if key == "undo":
			b.pressed.connect(_undo)
		else:
			b.pressed.connect(func(): _set_tool(key))
			tool_buttons[key] = b
		tools.add_child(b)
	if not pz.allow_stop and not pz.allow_lamp:
		tool_buttons.signal.disabled = true
	v.add_child(tools)

	depart_btn = Pal.button("DEPART", "primary", 46)
	depart_btn.custom_minimum_size.y = 108
	depart_btn.pressed.connect(_depart)
	v.add_child(depart_btn)
	v.add_child(_spacer(14))

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", Pal.box(Pal.BEZEL, 20, Color.TRANSPARENT, 0, Vector4(26, 16, 26, 16)))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Pal.label("", 28, "semi", Pal.LIT)
	toast.add_child(toast_label)
	toast.modulate.a = 0
	layer.add_child(toast)
	_set_tool("track")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _set_tool(key: String) -> void:
	board.tool = key
	for k in tool_buttons:
		Pal.style_button(tool_buttons[k], "tool_on" if k == key else "tool", 30)


func _refresh() -> void:
	var n := lay.track_count(pz)
	track_label.text = "Track %d  ·  par %d" % [n, pz.par]
	stars.set_filled(pz.stars_for(n) if n > 0 else 0)
	var running := board.is_playing()
	for k in tool_buttons:
		tool_buttons[k].disabled = running or (k == "signal" and not pz.allow_stop and not pz.allow_lamp)
	if running:
		depart_btn.text = "STOP"
		Pal.style_button(depart_btn, "dark", 46)
	else:
		Pal.style_button(depart_btn, "primary", 46)
		depart_btn.text = "DEPART"
		if mode == "daily":
			var d := save.daily(day)
			var left: int = DailyGen.DEPARTURES - d.rows.size()
			depart_btn.text = "DEPART  ·  %d LEFT" % left
			if d.solved:
				depart_btn.text = "SOLVED TODAY"
			elif left <= 0:
				depart_btn.text = "NO DEPARTURES LEFT"
			depart_btn.disabled = save.daily_finished(day)
	if rows_view:
		rows_view.set_rows(save.daily(day).rows)
		rows_view.visible = not save.daily(day).rows.is_empty()


func _persist() -> void:
	if mode == "daily":
		if not save.daily_finished(day):
			save.set_daily_layout(day, lay.to_dict())
	else:
		save.set_level_layout(pz.id, lay.to_dict())


func _on_edited(before: Dictionary) -> void:
	undo.append(before)
	if undo.size() > 100:
		undo.pop_front()
	_persist()
	_refresh()


func _set_layout(l: Layout) -> void:
	lay = l
	board.lay = l
	board.queue_redraw()
	_persist()
	_refresh()


func _undo() -> void:
	if board.is_playing() or undo.is_empty():
		return
	_set_layout(Layout.from_dict(undo.pop_back()))


func _clear() -> void:
	if board.is_playing() or (mode == "daily" and save.daily_finished(day)):
		return
	if lay.edges.is_empty():
		return
	undo.append(lay.to_dict())
	_set_layout(Layout.new())


func _depart() -> void:
	if board.is_playing():
		board.stop_playback()
		_refresh()
		return
	if lay.edges.is_empty():
		show_toast("Lay some track first: drag from a depot.")
		return
	_close_overlay()
	_run = Sim.run(pz, lay)
	if mode == "daily":
		var row: Array = []
		for o in _run.outcomes:
			row.append(o.result)
		save.record_daily(day, row, _run.success, lay.track_count(pz), lay.to_dict())
	board.play(_run)
	_refresh()


func _on_playback_finished() -> void:
	_refresh()
	if mode == "daily":
		if save.daily_finished(day):
			_show_daily_result()
		else:
			_show_failure(true)
		return
	if _run.success:
		_show_level_success()
	else:
		_show_failure(false)


func _first_problem() -> Dictionary:
	for ev in _run.events:
		if ev.kind != "arrived":
			return ev
	return {}


func _show_failure(daily: bool) -> void:
	var ev := _first_problem()
	var who: String = Pal.LIVERY_NAMES[ev.get("color", 0) % 4]
	var title := "CRASH"
	var text := "The %s train ran into another train. Try a stop signal or a different route." % who
	match ev.get("kind", ""):
		"derail":
			title = "DERAILED"
			text = "The %s train ran off the end of its track." % who
		"wrong":
			title = "WRONG PLATFORM"
			text = "The %s train reached a platform of another colour." % who
		"lost":
			title = "STILL RUNNING"
			text = "The %s train never reached a platform. Look for loops and trains stuck in a queue." % who
	var o := Pal.overlay(self)
	_overlay = o
	var body: VBoxContainer = o.body
	body.add_child(Pal.label(title, 56, "display", Pal.LAMP_RED if title != "WRONG PLATFORM" else Pal.TICKET_SOFT))
	body.add_child(Pal.wrap_label(text, 30))
	if daily:
		var used: int = save.daily(day).rows.size()
		body.add_child(Pal.label("Departure %d of %d" % [used, DailyGen.DEPARTURES], 28, "semi", Pal.INK_SOFT))
		body.add_child(Drawn.ResultRows.new(save.daily(day).rows, 40, 0))
	var ok := Pal.button("KEEP BUILDING", "primary", 38)
	ok.custom_minimum_size.y = 96
	ok.pressed.connect(_back_to_building)
	body.add_child(ok)


func _back_to_building() -> void:
	_close_overlay()
	board.stop_playback()
	_refresh()


func _show_level_success() -> void:
	var n := lay.track_count(pz)
	var s := pz.stars_for(n)
	save.set_stars(pz.id, s)
	var o := Pal.overlay(self)
	_overlay = o
	var body: VBoxContainer = o.body
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := Pal.label("ALL TRAINS HOME", 60, "display")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	var big := Drawn.Stars.new(s, 76)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(big)
	var msg := "Track %d, par %d." % [n, pz.par]
	if s < 3:
		msg += " Use %d or fewer pieces for three stars." % pz.par
	var m := Pal.wrap_label(msg, 30, "body", Pal.INK_SOFT)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(m)
	if index + 1 < Levels.count():
		var nxt := Pal.button("NEXT STOP", "primary", 40)
		nxt.custom_minimum_size.y = 100
		nxt.pressed.connect(func(): next_level.emit(index + 1))
		body.add_child(nxt)
	else:
		body.add_child(Pal.wrap_label("That's the whole Branch Line. Try today's Daily Line next.", 28))
		var home := Pal.button("BACK TO THE MAP", "primary", 40)
		home.custom_minimum_size.y = 100
		home.pressed.connect(func(): back.emit())
		body.add_child(home)
	var again := Pal.button("Improve this stop", "ghost", 30)
	again.pressed.connect(_back_to_building)
	body.add_child(again)


func _show_daily_result() -> void:
	_close_overlay()
	var d := save.daily(day)
	var o := Pal.overlay(self, Pal.TICKET)
	_overlay = o
	var body: VBoxContainer = o.body
	var head := Pal.hbox()
	var date := Pal.label(DailyGen.date_label(day), 26, "display", Pal.TICKET_SOFT)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(date)
	head.add_child(Pal.label(DailyGen.number_label(day), 32, "display"))
	body.add_child(head)
	if d.solved:
		body.add_child(Pal.label("ALL TRAINS HOME", 62, "display"))
		body.add_child(Pal.wrap_label("Solved on departure %d of %d · track %d, par %d" % [d.rows.size(), DailyGen.DEPARTURES, d.track, pz.par], 28, "body", Pal.TICKET_INK))
	else:
		body.add_child(Pal.label("OUT OF DEPARTURES", 58, "display"))
		body.add_child(Pal.wrap_label("Six departures used. Par for today was %d pieces of track." % pz.par, 28, "body", Pal.TICKET_INK))
	var rule := ColorRect.new()
	rule.color = Pal.TICKET_RULE
	rule.custom_minimum_size.y = 3
	body.add_child(rule)
	body.add_child(Drawn.ResultRows.new(d.rows, 54, 0))

	var stats := save.daily_stats(DailyGen.today())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	var solved_pct := 0 if stats.played == 0 else int(round(100.0 * stats.solved / stats.played))
	for pair in [[str(stats.played), "Played"], ["%d%%" % solved_pct, "Solved"], [str(stats.streak), "Streak"], [str(stats.best), "Best"]]:
		var cell := Pal.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var num := Pal.label(pair[0], 52, "display")
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(num)
		var cap := Pal.label(pair[1], 24, "body", Pal.TICKET_SOFT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cap)
		grid.add_child(cell)
	body.add_child(grid)

	var share := Pal.button("COPY RESULT", "primary", 40)
	share.custom_minimum_size.y = 100
	share.pressed.connect(_copy_result)
	body.add_child(share)
	if not d.solved:
		var sol := Pal.button("Show a solution", "ghost", 30)
		sol.pressed.connect(func():
			_close_overlay()
			board.stop_playback()
			lay = pz.solution_layout()
			board.lay = lay
			board.editable = false
			board.queue_redraw()
			_refresh())
		body.add_child(sol)
	var close := Pal.button("Look at the board", "ghost", 30)
	close.pressed.connect(func():
		_close_overlay()
		board.stop_playback()
		board.editable = false)
	body.add_child(close)
	_countdown = Pal.label("", 28, "body", Pal.TICKET_SOFT)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_countdown)
	_tick_countdown()


func _process(_delta: float) -> void:
	if _countdown and is_instance_valid(_countdown):
		_tick_countdown()


func _tick_countdown() -> void:
	var s := DailyGen.seconds_until_tomorrow()
	_countdown.text = "Next Daily Line in %02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _copy_result() -> void:
	var text := Save.share_text(day, save.daily(day), pz.par)
	DisplayServer.clipboard_set(text)
	show_toast("Result copied. Paste it anywhere.")


func _close_overlay() -> void:
	if not _overlay.is_empty() and is_instance_valid(_overlay.root):
		_overlay.root.queue_free()
	_overlay = {}
	_countdown = null


func show_toast(text: String) -> void:
	toast_label.text = text
	toast.reset_size()
	toast.position = Vector2((size.x - toast.size.x) / 2, size.y - toast.size.y - 290)
	toast.move_to_front()
	toast.get_parent().move_to_front()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	toast.modulate.a = 1.0
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
