class_name Drawn
extends RefCounted
## Small custom-drawn pieces of UI.


## The stacked "TRAINS TRAINS TRAINS" wordmark, each line led by a train.
class Wordmark extends Control:
	var text_size := 88

	func _init(s := 88) -> void:
		text_size = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		var line := text_size * 0.92
		return Vector2(text_size * 4.6, line * 3)

	func _draw() -> void:
		var f := Pal.font("display")
		var line := text_size * 0.92
		var token := text_size * 0.82
		for i in 3:
			var x := i * token * 0.62
			var y := i * line
			var mid := y + line * 0.52
			Pal.draw_train(self, Vector2(x + token / 2, mid), 0.0, token, i)
			draw_string(f, Vector2(x + token + text_size * 0.2, y + line * 0.86), "TRAINS", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Pal.INK)


class Stars extends Control:
	var filled := 0
	var count := 3
	var star_size := 34.0
	var empty_color := Pal.DOT

	func _init(n := 0, s := 34.0, total := 3) -> void:
		filled = n
		star_size = s
		count = total
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled(n: int) -> void:
		filled = n
		queue_redraw()

	func _get_minimum_size() -> Vector2:
		return Vector2(star_size * count + star_size * 0.3 * (count - 1), star_size)

	func _draw() -> void:
		for i in count:
			var c := Vector2(star_size / 2 + i * star_size * 1.3, size.y / 2)
			Pal.draw_star(self, c, star_size / 2, Pal.LAMP_AMBER if i < filled else empty_color)


## A row of train tokens, e.g. the trains waiting in a depot.
class TrainRow extends Control:
	var colors: Array = []
	var token := 44.0

	func _init(c: Array = [], t := 44.0) -> void:
		colors = c
		token = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2(maxf(colors.size(), 1) * token * 1.12, token * 0.6)

	func _draw() -> void:
		for i in colors.size():
			Pal.draw_train(self, Vector2(token / 2 + i * token * 1.12, size.y / 2), 0.0, token, colors[i])


## Daily Line departure results: one row per departure, one square per train.
class ResultRows extends Control:
	var rows: Array = []
	var square := 54.0
	var slots := 0

	func _init(r: Array = [], s := 54.0, total_slots := 0) -> void:
		rows = r
		square = s
		slots = total_slots
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_rows(r: Array) -> void:
		rows = r
		update_minimum_size()
		queue_redraw()

	func _get_minimum_size() -> Vector2:
		var cols := 1
		for row in rows:
			cols = maxi(cols, row.size())
		var n := maxi(rows.size(), slots)
		return Vector2(cols * square * 1.2, n * square * 1.2)

	func _draw() -> void:
		var cols := 1
		for row in rows:
			cols = maxi(cols, row.size())
		for y in maxi(rows.size(), slots):
			for x in cols:
				var r := Rect2(Vector2(x, y) * square * 1.2, Vector2(square, square))
				if y < rows.size() and x < rows[y].size():
					Pal.rounded_rect(self, r, Pal.outcome_color(rows[y][x]), square * 0.2)
				else:
					Pal.rounded_rect(self, r, Color(0, 0, 0, 0), square * 0.2, Color(Pal.TICKET_RULE, 0.9), 3)


## The campaign as a metro line: each level is a stop.
class LineMap extends Control:
	signal stop_pressed(index: int)

	const STEP := 190.0
	var save: Save

	func _init(s: Save) -> void:
		save = s

	func _get_minimum_size() -> Vector2:
		return Vector2(400, Levels.count() * STEP + 160)

	func stop_pos(i: int) -> Vector2:
		var x := size.x * (0.26 if i % 2 == 0 else 0.74)
		return Vector2(x, size.y - 110 - i * STEP)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in Levels.count():
				if event.position.distance_to(stop_pos(i)) < 64 and i <= save.next_level_index():
					stop_pressed.emit(i)
					accept_event()
					return

	func _segment(i: int) -> PackedVector2Array:
		var a := stop_pos(i)
		var b := stop_pos(i + 1)
		var pts := PackedVector2Array()
		for k in 25:
			var t := k / 24.0
			var c1 := Vector2(a.x, a.y - STEP * 0.5)
			var c2 := Vector2(b.x, b.y + STEP * 0.5)
			var u := 1.0 - t
			pts.append(u * u * u * a + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * b)
		return pts

	func _draw() -> void:
		var reached := save.next_level_index()
		var line_col := Pal.livery(0)
		var w := 18.0
		draw_line(stop_pos(0) + Vector2(0, 90), stop_pos(0), line_col, w, true)
		for i in Levels.count() - 1:
			var pts := _segment(i)
			if i < reached:
				draw_polyline(pts, line_col, w, true)
			else:
				for k in range(0, pts.size() - 1, 2):
					draw_line(pts[k], pts[k + 1], Pal.DOT, w * 0.7, true)
		var body := Pal.font("semi")
		var disp := Pal.font("display")
		for i in Levels.count():
			var lv: Dictionary = Levels.DATA[i]
			var c := stop_pos(i)
			var left_side := i % 2 == 1
			var tx := c.x - 62 if left_side else c.x + 62
			var align := HORIZONTAL_ALIGNMENT_RIGHT if left_side else HORIZONTAL_ALIGNMENT_LEFT
			var label_x := tx - 400 if left_side else tx
			var stars := save.stars(lv.id)
			if i < reached:
				draw_circle(c, 34, line_col, true, -1.0, true)
				draw_string(disp, c + Vector2(-40, 12), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Pal.WHITE)
				draw_string(body, Vector2(label_x, c.y - 4), lv.name, align, 400, 30, Pal.INK)
				for s in 3:
					var sx := (tx - 3 * 30 + 15 + s * 30) if left_side else (tx + 15 + s * 30)
					Pal.draw_star(self, Vector2(sx, c.y + 28), 13, Pal.LAMP_AMBER if s < stars else Pal.DOT)
			elif i == reached:
				draw_circle(c, 56, Color(line_col, 0.18), true, -1.0, true)
				draw_circle(c, 40, Pal.WHITE, true, -1.0, true)
				draw_arc(c, 40, 0, TAU, 48, Pal.INK, 9, true)
				draw_string(disp, c + Vector2(-40, 13), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 80, 38, Pal.INK)
				draw_string(Pal.font("bold"), Vector2(label_x, c.y - 4), lv.name, align, 400, 32, Pal.INK)
				var intro: String = lv.get("intro_title", "")
				if intro.begins_with("New: "):
					var badge := "NEW · " + intro.substr(5).to_upper()
					var bw := disp.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28
					var bx := tx - bw if left_side else tx
					Pal.rounded_rect(self, Rect2(bx, c.y + 10, bw, 38), Pal.BEZEL, 10)
					draw_string(disp, Vector2(bx + 14, c.y + 38), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.LIT)
			else:
				draw_circle(c, 26, Pal.ENAMEL, true, -1.0, true)
				draw_arc(c, 26, 0, TAU, 40, Pal.DOT, 5, true)
				draw_string(disp, c + Vector2(-40, 10), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 80, 28, Pal.INK_FAINT)
				draw_string(body, Vector2(label_x, c.y + 10), lv.name, align, 400, 28, Pal.INK_FAINT)


## A panel that keeps its children in a centred column no wider than `max_width`.
class Column extends Container:
	var max_width := 760.0
	var gutter := 24.0

	func _init(mw := 760.0) -> void:
		max_width = mw

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var w := minf(size.x - gutter * 2, max_width)
			for child in get_children():
				if child is Control:
					fit_child_in_rect(child, Rect2((size.x - w) / 2, 0, w, size.y))


## The Daily Line card: ticket stock with punched notches on both sides.
class Ticket extends PanelContainer:
	var notch_color := Pal.ENAMEL

	func _init() -> void:
		add_theme_stylebox_override("panel", Pal.box(Pal.TICKET, 34, Color.TRANSPARENT, 0, Vector4(40, 36, 40, 36)))

	func _draw() -> void:
		var y := size.y * 0.5
		draw_circle(Vector2(0, y), 22, notch_color, true, -1.0, true)
		draw_circle(Vector2(size.x, y), 22, notch_color, true, -1.0, true)
