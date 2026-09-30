extends Control
## Home: the wordmark, the campaign card and today's Daily Line ticket.

signal open_map
signal open_daily

var save: Save


func _init(s: Save) -> void:
	save = s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.ENAMEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := Drawn.Column.new(700)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	var v := Pal.vbox(40)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var top := Control.new()
	top.custom_minimum_size.y = 40
	v.add_child(top)
	v.add_child(Drawn.Wordmark.new(92))
	v.add_child(_campaign_card())
	v.add_child(_daily_ticket())
	var help := Pal.button("How to play", "ghost", 30)
	help.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help.pressed.connect(_show_help)
	v.add_child(help)


func _campaign_card() -> Control:
	var c := Pal.card(Pal.WELL)
	var v := Pal.vbox(20)
	c.add_child(v)
	var head := Pal.hbox()
	var eyebrow := Pal.label("CAMPAIGN", 26, "display", Pal.INK_SOFT)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(eyebrow)
	head.add_child(Pal.label("%d of %d stars" % [save.total_stars(), Levels.count() * 3], 28, "semi"))
	v.add_child(head)
	v.add_child(Pal.label("LINE 1 · " + Levels.LINE_NAME.to_upper(), 58, "display"))
	v.add_child(Progress.new(save.next_level_index()))
	var next := save.next_level_index()
	var line: String = "Every stop cleared. Replay any stop for more stars." if next >= Levels.count() else "Next stop: " + Levels.DATA[next].name
	v.add_child(Pal.wrap_label(line, 30, "body", Pal.INK_SOFT))
	var go := Pal.button("CONTINUE" if next > 0 else "START", "primary", 42)
	go.custom_minimum_size.y = 100
	go.pressed.connect(func(): open_map.emit())
	v.add_child(go)
	return c


func _daily_ticket() -> Control:
	var day := DailyGen.today()
	var d := save.daily(day)
	var t := Drawn.Ticket.new()
	var v := Pal.vbox(18)
	t.add_child(v)
	var head := Pal.hbox()
	var eyebrow := Pal.label("DAILY LINE", 26, "display", Pal.TICKET_SOFT)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(eyebrow)
	head.add_child(Pal.label(DailyGen.number_label(day), 34, "display"))
	v.add_child(head)
	v.add_child(Pal.label(DailyGen.date_label(day), 58, "display"))
	var blurb := "One puzzle for everyone today. Six departures to get every train home."
	if d.solved:
		blurb = "Solved on departure %d of %d. A new line opens at midnight." % [d.rows.size(), DailyGen.DEPARTURES]
	elif d.rows.size() >= DailyGen.DEPARTURES:
		blurb = "Out of departures today. A new line opens at midnight."
	elif not d.rows.is_empty():
		blurb = "%d of %d departures used. Keep going." % [d.rows.size(), DailyGen.DEPARTURES]
	v.add_child(Pal.wrap_label(blurb, 30, "body", Pal.TICKET_INK))
	var rule := ColorRect.new()
	rule.color = Pal.TICKET_RULE
	rule.custom_minimum_size.y = 3
	v.add_child(rule)
	var row := Pal.hbox()
	var sv := Pal.vbox(0)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(Pal.label("Streak", 26, "body", Pal.TICKET_SOFT))
	var streak: int = save.daily_stats(day).streak
	sv.add_child(Pal.label("%d DAY%s" % [streak, "" if streak == 1 else "S"], 48, "display"))
	row.add_child(sv)
	var board := Pal.button("SEE RESULT" if save.daily_finished(day) else "BOARD", "ticket", 38)
	board.custom_minimum_size = Vector2(220, 92)
	board.pressed.connect(func(): open_daily.emit())
	row.add_child(board)
	v.add_child(row)
	return t


func _show_help() -> void:
	var o := Pal.overlay(self)
	var body: VBoxContainer = o.body
	body.add_child(Pal.label("HOW TO PLAY", 52, "display"))
	var lines := [
		"Drag across squares to lay track from each depot to the platform of the same colour and shape.",
		"Join three sides of a square to make a switch. Tap it to flip the lever.",
		"Signal adds a stop signal to a straight or curve (a train holds two beats), or a colour lamp to a switch (that colour follows the lever, others take the other branch).",
		"Press Depart. Trains move one square per beat. Two trains in one square crash.",
		"Use no more track than par for three stars.",
	]
	for line in lines:
		body.add_child(Pal.wrap_label(line, 30))
	var ok := Pal.button("GOT IT", "primary", 38)
	ok.custom_minimum_size.y = 92
	ok.pressed.connect(func(): o.root.queue_free())
	body.add_child(ok)


## Campaign progress as a short line of stops.
class Progress extends Control:
	var reached := 0

	func _init(r: int) -> void:
		reached = r
		custom_minimum_size.y = 44

	func _draw() -> void:
		var n := Levels.count()
		var step := (size.x - 40) / float(n - 1)
		var y := size.y / 2
		var cut := 20 + step * mini(reached, n - 1)
		draw_line(Vector2(20, y), Vector2(cut, y), Pal.livery(0), 12, true)
		var x := cut
		while x < size.x - 20:
			draw_line(Vector2(x, y), Vector2(minf(x + 6, size.x - 20), y), Pal.DOT, 10, true)
			x += 20
		for i in n:
			var c := Vector2(20 + step * i, y)
			if i < reached:
				draw_circle(c, 14, Pal.livery(0), true, -1.0, true)
			elif i == reached:
				draw_circle(c, 17, Pal.WHITE, true, -1.0, true)
				draw_arc(c, 17, 0, TAU, 32, Pal.INK, 7, true)
			else:
				draw_circle(c, 10, Pal.ENAMEL, true, -1.0, true)
				draw_arc(c, 10, 0, TAU, 24, Pal.DOT, 4, true)
