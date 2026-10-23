extends Node2D
# Prototype : 1 mission, 3 emplacements, 3 tours, 3 ennemis, 5 vagues.

const SaveManager = preload("res://scripts/save_manager.gd")

var PATH := PackedVector2Array([
	Vector2(0, 300), Vector2(600, 300), Vector2(600, 560),
	Vector2(120, 560), Vector2(120, 820), Vector2(720, 820)])
var SLOTS := [Vector2(300, 210), Vector2(470, 430), Vector2(380, 690)]

var enemy_defs = {}
var tower_defs = {}
var level = {}
var gold := 100
var base_hp := 20
var wave_i := -1
var wave_active := false
var queue := []
var spawn_timer := 0.0
var spawn_interval := 1.0
var enemies := []
var towers := {}
var shots := []
var selected := "archer"
var speed := 1.0
var paused := false
var state := "play"
var hud: Label
var wave_btn: Button
var layer: CanvasLayer

func _load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _ready() -> void:
	enemy_defs = _load_json("res://data/enemies.json")
	tower_defs = _load_json("res://data/towers.json")
	level = _load_json("res://data/levels.json")["levels"][0]
	gold = int(level["start_gold"])
	base_hp = int(level["base_health"])
	_build_ui()

func _btn(text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	layer.add_child(b)
	return b

func _build_ui() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(10, 10)
	hud.add_theme_font_size_override("font_size", 32)
	layer.add_child(hud)
	var ids := ["archer", "fire", "ice"]
	for i in range(ids.size()):
		var id: String = ids[i]
		var d = tower_defs[id]
		_btn("%s\n%d or" % [d["name"], int(d["cost"])], Vector2(10 + i * 240, 1150), Vector2(220, 100), func(): selected = id)
	wave_btn = _btn("Lancer la vague", Vector2(10, 1030), Vector2(220, 100), _start_wave)
	_btn("Pause", Vector2(250, 1030), Vector2(220, 100), func(): paused = not paused)
	_btn("Vitesse x2", Vector2(490, 1030), Vector2(220, 100), func(): speed = 2.0 if speed == 1.0 else 1.0)

func _start_wave() -> void:
	if wave_active or state != "play":
		return
	wave_i += 1
	var wave = level["waves"][wave_i]
	queue = []
	for e in wave["enemies"]:
		for n in range(int(e["count"])):
			queue.append(e["type"])
	spawn_interval = float(wave["spawn_interval"])
	spawn_timer = 0.0
	wave_active = true
	wave_btn.disabled = true

func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(get_global_mouse_position())

func _tap(p: Vector2) -> void:
	for i in range(SLOTS.size()):
		if p.distance_to(SLOTS[i]) < 50:
			if towers.has(i):
				var t = towers[i]
				var up_cost := int(int(tower_defs[t["type"]]["cost"]) * 0.8 * t["lvl"])
				if t["lvl"] < 3 and gold >= up_cost:
					gold -= up_cost
					t["lvl"] += 1
			else:
				var cost := int(tower_defs[selected]["cost"])
				if gold >= cost:
					gold -= cost
					towers[i] = {"type": selected, "cd": 0.0, "lvl": 1}
			return

func _process(delta: float) -> void:
	if paused or state != "play":
		return
	var dt := delta * speed
	_spawn(dt)
	_move(dt)
	_towers(dt)
	for s in shots:
		s["ttl"] -= dt
	shots = shots.filter(func(s): return s["ttl"] > 0.0)
	if base_hp <= 0:
		_end(false)
	elif wave_active and queue.is_empty() and enemies.is_empty():
		wave_active = false
		if wave_i >= level["waves"].size() - 1:
			_end(true)
		else:
			wave_btn.disabled = false
	hud.text = "Or : %d   Base : %d   Vague : %d/%d" % [gold, base_hp, max(wave_i + 1, 0), level["waves"].size()]
	queue_redraw()

func _spawn(dt: float) -> void:
	if queue.is_empty():
		return
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		var type: String = queue.pop_front()
		var d = enemy_defs[type]
		enemies.append({"d": d, "hp": float(d["hp"]), "max": float(d["hp"]), "pos": PATH[0], "idx": 1, "slow": 0.0})
		spawn_timer = spawn_interval

func _move(dt: float) -> void:
	var alive := []
	for e in enemies:
		e["slow"] = max(0.0, e["slow"] - dt)
		var sp: float = float(e["d"]["speed"]) * (0.5 if e["slow"] > 0.0 else 1.0)
		var step := sp * dt
		var target: Vector2 = PATH[e["idx"]]
		if e["pos"].distance_to(target) <= step:
			e["pos"] = target
			e["idx"] += 1
		else:
			e["pos"] = e["pos"].move_toward(target, step)
		if e["idx"] >= PATH.size():
			base_hp -= 1
			continue
		if e["hp"] <= 0.0:
			gold += int(e["d"]["reward"])
			continue
		alive.append(e)
	enemies = alive

func _towers(dt: float) -> void:
	for i in towers:
		var t = towers[i]
		t["cd"] -= dt
		if t["cd"] > 0.0:
			continue
		var d = tower_defs[t["type"]]
		var pos: Vector2 = SLOTS[i]
		var best = null
		var best_prog := -1.0
		for e in enemies:
			if e["hp"] <= 0.0:
				continue
			if pos.distance_to(e["pos"]) <= float(d["range"]):
				var prog: float = e["idx"] * 10000.0 - e["pos"].distance_to(PATH[e["idx"]])
				if prog > best_prog:
					best_prog = prog
					best = e
		if best == null:
			continue
		t["cd"] = float(d["cooldown"])
		var dmg: float = float(d["damage"]) * (1.0 + 0.4 * (t["lvl"] - 1))
		var splash: float = float(d.get("splash", 0))
		if splash > 0.0:
			for e2 in enemies:
				if e2["pos"].distance_to(best["pos"]) <= splash:
					e2["hp"] -= dmg
		else:
			best["hp"] -= dmg
		if d.has("slow_time"):
			best["slow"] = float(d["slow_time"])
		shots.append({"from": pos, "to": best["pos"], "ttl": 0.12, "color": Color(d["color"])})

func _end(victory: bool) -> void:
	state = "victory" if victory else "defeat"
	if victory:
		var stars := 3 if base_hp >= 15 else (2 if base_hp >= 8 else 1)
		SaveManager.complete_mission(int(level["level_id"]), stars)
	var l := Label.new()
	l.text = "VICTOIRE !" if victory else "DÉFAITE"
	l.add_theme_font_size_override("font_size", 80)
	l.position = Vector2(0, 380)
	l.size = Vector2(720, 120)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(l)
	_btn("Menu principal", Vector2(160, 540), Vector2(400, 110), func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color("3a6b35"))
	draw_polyline(PATH, Color("b08a5a"), 60.0)
	draw_rect(Rect2(650, 790, 70, 60), Color("1b2a49"))
	for i in range(SLOTS.size()):
		draw_circle(SLOTS[i], 42, Color(0, 0, 0, 0.35))
		if towers.has(i):
			var t = towers[i]
			var d = tower_defs[t["type"]]
			draw_circle(SLOTS[i], 36, Color(d["color"]))
			draw_string(ThemeDB.fallback_font, SLOTS[i] + Vector2(-8, 10), str(t["lvl"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	for s in shots:
		draw_line(s["from"], s["to"], s["color"], 4.0)
	for e in enemies:
		draw_circle(e["pos"], 20, Color(e["d"]["color"]))
		var ratio: float = clamp(e["hp"] / e["max"], 0.0, 1.0)
		draw_rect(Rect2(e["pos"] + Vector2(-20, -32), Vector2(40, 6)), Color.RED)
		draw_rect(Rect2(e["pos"] + Vector2(-20, -32), Vector2(40 * ratio, 6)), Color.GREEN)
