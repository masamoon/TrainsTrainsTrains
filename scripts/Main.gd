extends Control
## Screen router: home, campaign line map, and the play screen for levels and the Daily Line.

var save := Save.new()
var current: Control


func _ready() -> void:
	RenderingServer.set_default_clear_color(Pal.ENAMEL)
	save.load_file()
	show_home()


func _swap(screen: Control) -> void:
	if current:
		current.queue_free()
	current = screen
	add_child(screen)


func show_home() -> void:
	var s := preload("res://scripts/ui/HomeScreen.gd").new(save)
	s.open_map.connect(show_map)
	s.open_daily.connect(play_daily)
	_swap(s)


func show_map() -> void:
	var s := preload("res://scripts/ui/MapScreen.gd").new(save)
	s.back.connect(show_home)
	s.play_level.connect(play_level)
	s.open_daily.connect(play_daily)
	_swap(s)


func play_level(index: int) -> void:
	var s := preload("res://scripts/ui/PlayScreen.gd").new(save, "level", index)
	s.back.connect(show_map)
	s.next_level.connect(play_level)
	_swap(s)


func play_daily() -> void:
	var s := preload("res://scripts/ui/PlayScreen.gd").new(save, "daily", DailyGen.today())
	s.back.connect(show_home)
	_swap(s)
