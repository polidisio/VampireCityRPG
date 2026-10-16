extends Control

func _ready():
	Controls.setup()
	Music.play(self, "title")
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.1)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = Label.new()
	title.text = "VAMPIRE CITY RPG"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(320, 20)
	title.position = Vector2(0, 14)
	add_child(title)
	var x = 40
	for art in ["classes/salvaje", "classes/noble", "classes/hemomante", "classes/dhampir"]:
		var spr = Sprite2D.new()
		spr.texture = load("res://assets/sprites/%s.png" % art)
		spr.position = Vector2(x, 78)
		add_child(spr)
		var tw = spr.create_tween().set_loops()
		tw.tween_property(spr, "offset:y", -2.0, 0.6 + randf() * 0.3)
		tw.tween_property(spr, "offset:y", 0.0, 0.6 + randf() * 0.3)
		x += 80
	var box = VBoxContainer.new()
	box.position = Vector2(110, 118)
	box.custom_minimum_size.x = 100
	add_child(box)
	var first: Button
	if SaveGame.exists():
		first = _button(box, "Continuar", _start)
	var new_btn = _button(box, "Nueva partida", Callable())
	first = first if first else new_btn
	new_btn.pressed.connect(func():
		if SaveGame.exists() and new_btn.text == "Nueva partida":
			new_btn.text = "¿Seguro? Se borra todo" # segundo pulso confirma
			return
		DirAccess.remove_absolute(SaveGame.PATH)
		_start())
	_button(box, "Salir", func(): get_tree().quit())
	first.grab_focus.call_deferred()

func _unhandled_input(event):
	if event.is_action_pressed("fullscreen"):
		Controls.toggle_fullscreen()

func _button(box: Control, label: String, on_press: Callable) -> Button:
	var b = Button.new()
	b.text = label
	if on_press.is_valid():
		b.pressed.connect(on_press)
	box.add_child(b)
	return b

func _start():
	get_tree().change_scene_to_file("res://scenes/level.tscn")
