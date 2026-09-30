class_name Save
extends RefCounted
## Local progress: campaign stars and builds, Daily Line attempts and streaks.

const PATH := "user://trainstrains_save.json"

var data := {"version": 1, "levels": {}, "daily": {}}
var path := PATH


func load_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		data.merge(parsed, true)


func save_file() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


# Campaign

func _level(id: String) -> Dictionary:
	if not data.levels.has(id):
		data.levels[id] = {"stars": 0, "layout": {}}
	return data.levels[id]


func stars(id: String) -> int:
	return int(data.levels.get(id, {}).get("stars", 0))


func set_stars(id: String, s: int) -> void:
	var lv := _level(id)
	lv.stars = maxi(int(lv.stars), s)
	save_file()


func total_stars() -> int:
	var n := 0
	for i in Levels.count():
		n += stars(Levels.DATA[i].id)
	return n


## Index of the first stop not yet cleared; every stop up to it is open.
func next_level_index() -> int:
	for i in Levels.count():
		if stars(Levels.DATA[i].id) == 0:
			return i
	return Levels.count()


func level_layout(id: String) -> Dictionary:
	return data.levels.get(id, {}).get("layout", {})


func set_level_layout(id: String, layout: Dictionary) -> void:
	_level(id).layout = layout
	save_file()


# Daily Line

func daily(day: int) -> Dictionary:
	return data.daily.get(str(day), {"rows": [], "solved": false, "layout": {}, "track": 0})


func set_daily_layout(day: int, layout: Dictionary) -> void:
	var d := daily(day)
	d.layout = layout
	data.daily[str(day)] = d
	save_file()


## Records one departure: a row of per-train results ("arrived", "wrong", "crashed").
func record_daily(day: int, row: Array, solved: bool, track: int, layout: Dictionary) -> void:
	var d := daily(day)
	if d.solved or d.rows.size() >= DailyGen.DEPARTURES:
		return
	d.rows.append(row)
	d.layout = layout
	if solved:
		d.solved = true
		d.track = track
	data.daily[str(day)] = d
	save_file()


func daily_finished(day: int) -> bool:
	var d := daily(day)
	return d.solved or d.rows.size() >= DailyGen.DEPARTURES


func daily_stats(today: int) -> Dictionary:
	var played := 0
	var solved := 0
	var best := 0
	var run := 0
	var days: Array = []
	for key in data.daily:
		days.append(int(key))
	days.sort()
	var last := -10
	for day in days:
		var d: Dictionary = data.daily[str(day)]
		if d.rows.is_empty():
			continue
		played += 1
		if d.solved:
			solved += 1
			run = run + 1 if day == last + 1 else 1
			last = day
			best = maxi(best, run)
	var streak := 0
	var day := today if daily(today).solved else today - 1
	while daily(day).solved:
		streak += 1
		day -= 1
	return {"played": played, "solved": solved, "streak": streak, "best": best}


static func share_text(day: int, d: Dictionary, par: int) -> String:
	var squares := {"arrived": "🟩", "wrong": "🟨"}
	var lines: PackedStringArray = []
	var score := "%d/%d" % [d.rows.size(), DailyGen.DEPARTURES] if d.solved else "X/%d" % DailyGen.DEPARTURES
	lines.append("TrainsTrainsTrains %s · %s" % [DailyGen.number_label(day), score])
	for row in d.rows:
		var s := ""
		for r in row:
			s += squares.get(r, "🟥")
		lines.append(s)
	if d.solved:
		lines.append("track %d · par %d" % [d.track, par])
	return "\n".join(lines)
