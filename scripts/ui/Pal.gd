class_name Pal
extends RefCounted
## The "Mimic Panel" identity: colours, fonts and the small drawing helpers every screen
## shares. See docs/DESIGN.md.

const ENAMEL := Color("#E4E7E1")
const WELL := Color("#F4F5F0")
const DOT := Color("#C3C9BE")
const INK := Color("#1D2622")
const INK_SOFT := Color("#56615B")
const INK_FAINT := Color("#8D978F")
const BEZEL := Color("#26332E")
const BEZEL_TEXT := Color("#F4F5F0")
const BEZEL_SOFT := Color("#B9C3BD")
const BLUE := Color("#1F4F8F")
const BLUE_DARK := Color("#163B6B")
const TICKET := Color("#F1E2B6")
const TICKET_INK := Color("#4E4222")
const TICKET_SOFT := Color("#6B5A2E")
const TICKET_RULE := Color("#C9B67F")
const LIT := Color("#FFF4CF")
const LAMP_GREEN := Color("#2F9A4C")
const LAMP_AMBER := Color("#E9A21C")
const LAMP_RED := Color("#D8432E")
const WOODS := Color("#A7B697")
const WOODS_DARK := Color("#7F9170")
const WATER := Color("#A9C7D0")
const WATER_DARK := Color("#7FA8B5")
const TOWN := Color("#C9BFB0")
const TOWN_DARK := Color("#A89C8A")
const WHITE := Color("#FFFFFF")

const LIVERIES := [Color("#D94F70"), Color("#178A83"), Color("#7552C4"), Color("#E07426")]
const LIVERY_NAMES := ["Rose", "Teal", "Violet", "Tangerine"]

const FONT_FILES := {
	"body": "res://assets/fonts/Barlow-Medium.ttf",
	"semi": "res://assets/fonts/Barlow-SemiBold.ttf",
	"bold": "res://assets/fonts/Barlow-Bold.ttf",
	"display": "res://assets/fonts/BarlowCondensed-Bold.ttf",
}

static var _fonts := {}
static var _boxes := {}


static func font(kind: String = "body") -> Font:
	if not _fonts.has(kind):
		_fonts[kind] = load(FONT_FILES[kind])
	return _fonts[kind]


static func livery(color: int) -> Color:
	return LIVERIES[color % LIVERIES.size()]


static func box(bg: Color, radius: float, border: Color = Color.TRANSPARENT, border_w: int = 0, pad := Vector4.ZERO) -> StyleBoxFlat:
	var key := "%s|%s|%s|%d|%s" % [bg.to_html(), radius, border.to_html(), border_w, pad]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	_boxes[key] = sb
	return sb


static func label(text: String, size: int, kind := "body", color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size: int, kind := "body", color := INK) -> Label:
	var l := label(text, size, kind, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10
	return l


## Button looks: "primary" (enamel blue), "dark" (bezel), "ticket" (ink on ticket),
## "tool" (light, toggles dark when selected), "ghost" (text only), "bar" (inside a bezel bar).
static func button(text: String, look := "primary", size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, look, size)
	return b


static func style_button(b: Button, look: String, size := 40) -> void:
	var bg := BLUE
	var bg_hover := BLUE_DARK
	var fg := WHITE
	var kind := "display"
	var radius := 26.0
	match look:
		"dark":
			bg = BEZEL
			bg_hover = INK
			fg = LIT
		"ticket":
			bg = INK
			bg_hover = BEZEL
			fg = TICKET
		"tool":
			bg = WELL
			bg_hover = Color("#E9ECE5")
			fg = INK
			kind = "semi"
			radius = 22.0
		"tool_on":
			bg = BEZEL
			bg_hover = BEZEL
			fg = LIT
			kind = "semi"
			radius = 22.0
		"ghost":
			bg = Color(0, 0, 0, 0)
			bg_hover = Color(0, 0, 0, 0.06)
			fg = INK
			kind = "semi"
			radius = 14.0
		"bar":
			bg = Color(0, 0, 0, 0)
			bg_hover = Color(1, 1, 1, 0.08)
			fg = BEZEL_TEXT
			kind = "semi"
			radius = 16.0
	var pad := Vector4(24, 10, 24, 10)
	b.add_theme_stylebox_override("normal", box(bg, radius, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("hover", box(bg_hover, radius, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("pressed", box(bg_hover.darkened(0.08), radius, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("disabled", box(bg.lerp(ENAMEL, 0.6), radius, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", fg.lerp(ENAMEL, 0.5))
	b.add_theme_font_override("font", font(kind))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("h_separation", 12)


static func card(bg: Color, radius := 34.0, pad := 36.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, Color.TRANSPARENT, 0, Vector4(pad, pad, pad, pad)))
	return p


static func vbox(sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func rounded_rect(ci: CanvasItem, rect: Rect2, color: Color, radius: float, border := Color.TRANSPARENT, border_w := 0) -> void:
	ci.draw_style_box(box(color, radius, border, border_w), rect)


## White shape that pairs with each livery, so colours are never the only cue.
static func draw_glyph(ci: CanvasItem, color: int, c: Vector2, r: float, col: Color) -> void:
	match color % 4:
		0:
			ci.draw_circle(c, r, col, true, -1.0, true)
		1:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 1.05, r * 0.8), c + Vector2(-r * 1.05, r * 0.8)]), col)
		2:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), col)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.2), c + Vector2(r * 1.2, 0), c + Vector2(0, r * 1.2), c + Vector2(-r * 1.2, 0)]), col)


## A train seen from above: a rounded capsule in its livery, a window at the front and
## its shape on the side.
static func draw_train(ci: CanvasItem, center: Vector2, angle: float, length: float, color: int, alpha := 1.0) -> void:
	var thick := length * 0.5
	var col := livery(color)
	col.a = alpha
	var white := Color(1, 1, 1, alpha)
	ci.draw_set_transform(center, angle, Vector2.ONE)
	rounded_rect(ci, Rect2(Vector2(-length / 2, -thick / 2), Vector2(length, thick)), col, thick / 2)
	rounded_rect(ci, Rect2(Vector2(length / 2 - thick * 0.72, -thick * 0.28), Vector2(thick * 0.4, thick * 0.56)), white, thick * 0.14)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var glyph_at := center + Vector2(-length * 0.14, 0).rotated(angle)
	draw_glyph(ci, color, glyph_at, thick * 0.2, white)


static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


static func outcome_color(result: String) -> Color:
	match result:
		"arrived":
			return LAMP_GREEN
		"wrong":
			return LAMP_AMBER
	return LAMP_RED


## The dark bar across the top of a screen: a left slot, a centred title and a right slot.
static func top_bar(title: String, eyebrow := "") -> Dictionary:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", box(BEZEL, 0, Color.TRANSPARENT, 0, Vector4(12, 0, 12, 0)))
	bar.custom_minimum_size.y = 116
	var row := HBoxContainer.new()
	bar.add_child(row)
	var left := HBoxContainer.new()
	left.custom_minimum_size.x = 150
	row.add_child(left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", -4)
	row.add_child(mid)
	if eyebrow != "":
		var e := label(eyebrow, 24, "display", BEZEL_SOFT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(e)
	var t := label(title, 44, "display", BEZEL_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(t)
	var right := HBoxContainer.new()
	right.custom_minimum_size.x = 150
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	return {"root": bar, "left": left, "right": right, "title": t}


## A dimmed layer with a card in the middle, for results and help.
static func overlay(parent: Control, bg := WELL) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var c: PanelContainer
	if bg == TICKET:
		c = Drawn.Ticket.new()
		c.notch_color = ENAMEL.lerp(INK, 0.45)
	else:
		c = card(bg, 36, 44)
	c.custom_minimum_size.x = minf(parent.size.x - 48, 660)
	center.add_child(c)
	var v := vbox(24)
	c.add_child(v)
	return {"root": dim, "card": c, "body": v}
