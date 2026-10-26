extends Node3D

const SAVE_MANAGER = preload("res://scripts/save_manager.gd")

var tower_defs = {}
var enemy_defs = {}
var level = {}
var gold = 100
var base_hp = 20
var wave_index = -1
var wave_active = false
var paused = false
var game_over = false
var speed = 1.0
var selected_tower = "archer"
var spawn_timer = 0.0
var spawn_interval = 1.0
var queue = []
var enemies = []
var towers = []
var slots = []
var hud
var wave_button
var ui_layer

var path_points = [
    Vector3(-6, 0.15, -9),
    Vector3(5, 0.15, -9),
    Vector3(5, 0.15, -3),
    Vector3(-4, 0.15, -3),
    Vector3(-4, 0.15, 3),
    Vector3(6, 0.15, 3),
    Vector3(6, 0.15, 9)
]

func _ready():
    tower_defs = _read_json("res://data/towers.json")
    enemy_defs = _read_json("res://data/enemies.json")
    var level_data = _read_json("res://data/levels.json")
    level = level_data["levels"][0]
    gold = int(level["start_gold"])
    base_hp = int(level["base_health"])
    _build_world()
    _build_ui()
    _refresh_hud()

func _read_json(path):
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Fichier introuvable : " + path)
        return {}
    var result = JSON.parse_string(file.get_as_text())
    return result if result != null else {}

func _material(color):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    return material

func _box(parent, size, pos, color):
    var body = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    body.mesh = mesh
    body.position = pos
    body.material_override = _material(color)
    parent.add_child(body)
    return body

func _sphere(parent, radius, pos, color):
    var body = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    body.mesh = mesh
    body.position = pos
    body.material_override = _material(color)
    parent.add_child(body)
    return body

func _build_world():
    var env = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.58, 0.66)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.5
    add_child(sun)

    var camera = Camera3D.new()
    camera.position = Vector3(0, 20, 20)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)
    camera.current = true
    camera.fov = 48
    add_child(camera)

    _box(self, Vector3(17, 0.5, 25), Vector3(0, -0.3, 0), Color("#344b35"))

    for x in range(-7, 8, 2):
        for z in range(-11, 12, 2):
            _box(self, Vector3(0.04, 0.01, 0.04), Vector3(x, -0.02, z), Color("#60734a"))

    for i in range(path_points.size() - 1):
        var a = path_points[i]
        var b = path_points[i + 1]
        var middle = (a + b) / 2.0
        var length = a.distance_to(b)
        var road = _box(self, Vector3(1.5, 0.12, length + 0.2), middle, Color("#8b7657"))
        road.look_at(Vector3(b.x, middle.y, b.z), Vector3.UP)
        road.rotation.x = 0
        road.rotation.z = 0
        if abs(b.x - a.x) > abs(b.z - a.z):
            road.rotation.y = PI / 2.0

    var base = _box(self, Vector3(1.5, 1.5, 1.5), Vector3(6, 0.65, 10), Color("#26344c"))
    _sphere(self, 0.55, Vector3(6, 1.8, 10), Color("#d5b56a"))

    slots = [
        Vector3(-3, 0.2, -7),
        Vector3(3, 0.2, -5),
        Vector3(2, 0.2, 1),
        Vector3(-2, 0.2, 5),
        Vector3(3, 0.2, 7)
    ]
    for p in slots:
        _box(self, Vector3(1.1, 0.12, 1.1), p, Color("#6c765b"))

    for i in range(12):
        var tree_x = -7.0 + float(i % 6) * 2.5
        var tree_z = -11.0 + float(i / 6) * 21.0
        _box(self, Vector3(0.3, 1.1, 0.3), Vector3(tree_x, 0.5, tree_z), Color("#59442c"))
        _sphere(self, 0.9, Vector3(tree_x, 1.5, tree_z), Color("#203f2c"))

func _build_ui():
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    var panel = ColorRect.new()
    panel.color = Color(0.04, 0.06, 0.08, 0.88)
    panel.position = Vector2(0, 0)
    panel.size = Vector2(720, 145)
    ui_layer.add_child(panel)

    hud = Label.new()
    hud.position = Vector2(12, 12)
    hud.size = Vector2(690, 110)
    hud.add_theme_font_size_override("font_size", 27)
    hud.add_theme_color_override("font_color", Color.WHITE)
    ui_layer.add_child(hud)

    wave_button = _button("LANCER VAGUE", Vector2(10, 970), Vector2(230, 90), _start_wave)
    _button("PAUSE", Vector2(245, 970), Vector2(140, 90), func(): paused = not paused)
    _button("VITESSE x2", Vector2(390, 970), Vector2(180, 90), func(): speed = 2.0 if speed == 1.0 else 1.0)

    var names = ["archer", "fire", "ice"]
    for i in range(names.size()):
        var id = names[i]
        var data = tower_defs.get(id, {})
        var label = str(data.get("name", id)) + "\n" + str(data.get("cost", 0)) + " or"
        _button(label, Vector2(10 + i * 235, 1080), Vector2(220, 110), func(): selected_tower = id)

func _button(text, pos, size, callback):
    var button = Button.new()
    button.text = text
    button.position = pos
    button.size = size
    button.add_theme_font_size_override("font_size", 23)
    button.pressed.connect(callback)
    ui_layer.add_child(button)
    return button

func _start_wave():
    if wave_active or game_over:
        return
    if wave_index + 1 >= level["waves"].size():
        return
    wave_index += 1
    queue.clear()
    var wave = level["waves"][wave_index]
    for entry in wave["enemies"]:
        for i in range(int(entry["count"])):
            queue.append(entry["type"])
    spawn_interval = float(wave["spawn_interval"])
    spawn_timer = 0.0
    wave_active = true
    wave_button.disabled = true
    _refresh_hud()

func _unhandled_input(event):
    if game_over:
        return
    var screen_position = Vector2.ZERO
    var pressed = false
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        screen_position = event.position
        pressed = true
    elif event is InputEventScreenTouch and event.pressed:
        screen_position = event.position
        pressed = true
    if not pressed:
        return
    if screen_position.y > 940:
        return
    var camera = get_viewport().get_camera_3d()
    if camera == null:
        return
    var origin = camera.project_ray_origin(screen_position)
    var direction = camera.project_ray_normal(screen_position)
    if abs(direction.y) < 0.001:
        return
    var distance = -origin.y / direction.y
    if distance < 0:
        return
    var hit = origin + direction * distance
    _place_tower(hit)

func _place_tower(hit):
    for i in range(slots.size()):
        if Vector2(hit.x, hit.z).distance_to(Vector2(slots[i].x, slots[i].z)) > 0.9:
            continue
        for tower in towers:
            if tower["slot"] == i:
                var cost = int(tower_defs[tower["type"]]["cost"] * 0.8 * tower["level"])
                if tower["level"] < 3 and gold >= cost:
                    gold -= cost
                    tower["level"] += 1
                    tower["damage"] *= 1.4
                    _refresh_hud()
                return
        var definition = tower_defs.get(selected_tower, {})
        var tower_cost = int(definition.get("cost", 999999))
        if gold < tower_cost:
            return
        gold -= tower_cost
        var root = Node3D.new()
        root.position = slots[i]
        add_child(root)
        _box(root, Vector3(0.9, 0.7, 0.9), Vector3(0, 0.35, 0), Color("#6d6a61"))
        var color = Color(definition.get("color", "#d9d9d9"))
        _box(root, Vector3(0.5, 1.5, 0.5), Vector3(0, 1.35, 0), color)
        _sphere(root, 0.4, Vector3(0, 2.2, 0), color)
        towers.append({
            "slot": i,
            "type": selected_tower,
            "root": root,
            "level": 1,
            "cooldown": 0.0,
            "damage": float(definition.get("damage", 10)),
            "range": float(definition.get("range", 4))
        })
        _refresh_hud()
        return

func _spawn_enemy(type):
    var definition = enemy_defs.get(type, {})
    var root = Node3D.new()
    root.position = path_points[0]
    add_child(root)
    var color = Color(definition.get("color", "#9e3333"))
    _box(root, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.55, 0), color)
    _sphere(root, 0.35, Vector3(0, 1.25, 0), Color("#302c2a"))
    enemies.append({
        "root": root,
        "data": definition,
        "hp": float(definition.get("hp", 30)),
        "max_hp": float(definition.get("hp", 30)),
        "point": 1,
        "slow": 0.0
    })

func _process(delta):
    if paused or game_over:
        return
    var dt = delta * speed
    if not queue.is_empty():
        spawn_timer -= dt
        if spawn_timer <= 0:
            _spawn_enemy(queue.pop_front())
            spawn_timer = spawn_interval

    for enemy in enemies:
        enemy["slow"] = max(0.0, enemy["slow"] - dt)
        if enemy["point"] >= path_points.size():
            continue
        var target = path_points[enemy["point"]]
        var factor = 0.5 if enemy["slow"] > 0 else 1.0
        enemy["root"].position = enemy["root"].position.move_toward(
            target, float(enemy["data"].get("speed", 1.5)) * factor * dt
        )
        if enemy["root"].position.distance_to(target) < 0.15:
            enemy["point"] += 1

    var survivors = []
    for enemy in enemies:
        if enemy["hp"] <= 0:
            gold += int(enemy["data"].get("reward", 5))
            enemy["root"].queue_free()
        elif enemy["point"] >= path_points.size():
            base_hp -= 1
            enemy["root"].queue_free()
        else:
            survivors.append(enemy)
    enemies = survivors

    for tower in towers:
        tower["cooldown"] -= dt
        if tower["cooldown"] > 0:
            continue
        var target_enemy = null
        var best_progress = -1.0
        for enemy in enemies:
            var distance = tower["root"].position.distance_to(enemy["root"].position)
            if distance <= tower["range"]:
                var progress = float(enemy["point"]) * 100.0
                if progress > best_progress:
                    best_progress = progress
                    target_enemy = enemy
        if target_enemy != null:
            tower["cooldown"] = 0.8
            target_enemy["hp"] -= tower["damage"]
            var tower_type = tower["type"]
            if tower_type == "ice":
                target_enemy["slow"] = 1.5
            if tower_type == "fire":
                for other in enemies:
                    if other["root"].position.distance_to(target_enemy["root"].position) < 1.6:
                        other["hp"] -= tower["damage"] * 0.35

    if base_hp <= 0:
        _finish(false)
    elif wave_active and queue.is_empty() and enemies.is_empty():
        wave_active = false
        wave_button.disabled = false
        if wave_index >= level["waves"].size() - 1:
            _finish(true)
    _refresh_hud()

func _refresh_hud():
    if hud:
        hud.text = "DEFENDER 3D   |   OR : %d   |   BASE : %d\nVAGUE : %d / %d   |   Tour sélectionnée : %s" % [
            gold, base_hp, max(wave_index + 1, 0), level.get("waves", []).size(), selected_tower
        ]

func _finish(victory):
    if game_over:
        return
    game_over = true
    if victory:
        var stars = 3 if base_hp >= 15 else (2 if base_hp >= 8 else 1)
        SAVE_MANAGER.complete_mission(int(level["level_id"]), stars)
    var result = Label.new()
    result.text = "VICTOIRE !" if victory else "DÉFAITE"
    result.position = Vector2(80, 400)
    result.size = Vector2(560, 130)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 64)
    ui_layer.add_child(result)
    var menu = _button("MENU PRINCIPAL", Vector2(150, 600), Vector2(420, 100), func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
    menu.z_index = 10
