extends RefCounted
# Sauvegarde locale (user://save.json). Utilisation : const SaveManager = preload("res://scripts/save_manager.gd")

const SAVE_PATH := "user://save.json"

static func load_data() -> Dictionary:
	var data := {"missions_done": [], "stars": {}}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("missions_done") and parsed.has("stars"):
			return parsed
	return data

static func save_data(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func complete_mission(mission_id: int, stars: int) -> void:
	var data := load_data()
	if not data["missions_done"].has(mission_id):
		data["missions_done"].append(mission_id)
	var key := str(mission_id)
	data["stars"][key] = max(int(data["stars"].get(key, 0)), stars)
	save_data(data)
