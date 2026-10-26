extends Control

const SaveManager = preload("res://scripts/save_manager.gd")

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b2a49")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "DEFENDER"
	title.add_theme_font_size_override("font_size", 90)
	title.position = Vector2(0, 220)
	title.size = Vector2(720, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var data := SaveManager.load_data()
	var info := Label.new()
	info.text = "Missions terminées : %d" % data["missions_done"].size()
	info.add_theme_font_size_override("font_size", 32)
	info.position = Vector2(0, 380)
	info.size = Vector2(720, 50)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)

	_make_button("JOUER", Vector2(160, 560), func(): get_tree().change_scene_to_file("res://scenes/Battle3D.tscn"))
	_make_button("QUITTER", Vector2(160, 720), func(): get_tree().quit())

func _make_button(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(400, 110)
	b.add_theme_font_size_override("font_size", 44)
	b.pressed.connect(cb)
	add_child(b)
