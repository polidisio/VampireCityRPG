extends Control

signal skill_selected(index: int)
signal item_selected(item: ItemData)
signal item_pressed

@onready var player_hp_label = $Panel/VBox/PlayerHP
@onready var player_mp_label = $Panel/VBox/PlayerMP
@onready var enemy_hp_label = $Panel/VBox/EnemyHP
@onready var menu = $Panel/Menu
var skill_menu: GridContainer
var log_label: Label
var log_lines: Array[String] = []

var player_char: CharacterData
var stage: Node2D
var sprites: Dictionary = {} # CharacterData -> Sprite2D
var hp_labels: Dictionary = {} # CharacterData -> Label
var enemy_team: Array = []

func _ready():
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(bg, 0) # detrás del Panel
	stage = Node2D.new()
	add_child(stage)
	move_child(stage, 1)
	var scroll = ScrollContainer.new()
	scroll.visible = false
	$Panel.add_child(scroll)
	scroll.position = Vector2(4, 4)
	scroll.size = Vector2(292, 62)
	skill_menu = GridContainer.new() # 2 columnas: caben 6 botones en el panel
	skill_menu.columns = 2
	skill_menu.custom_minimum_size.x = 286
	scroll.add_child(skill_menu)
	var ib = Button.new()
	ib.text = "Objeto"
	menu.add_child(ib)
	menu.move_child(ib, 2)
	ib.pressed.connect(func(): item_pressed.emit())
	log_label = Label.new()
	log_label.position = Vector2(10, 6)
	add_child(log_label)

func setup_battle(player_team_ref: Array[CharacterData], enemy_team_ref: Array[CharacterData]):
	player_char = player_team_ref[0]
	enemy_team = enemy_team_ref
	log_lines.clear()
	log_label.text = ""
	_build_stage()
	update_stats()
	menu.visible = false
	skill_menu.get_parent().visible = false

func _make_sprite(c: CharacterData, pos: Vector2, scale_f: float, flip: bool = false) -> void:
	var spr = Sprite2D.new()
	spr.texture = c.texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2.ONE * scale_f
	spr.flip_h = flip
	Shadow.attach(spr)
	stage.add_child(spr)
	sprites[c] = spr
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(130, 10)
	lbl.position = pos + Vector2(-65, spr.texture.get_height() / 2.0 * scale_f)
	stage.add_child(lbl)
	hp_labels[c] = lbl

func _build_stage():
	for n in stage.get_children():
		n.queue_free()
	sprites.clear()
	hp_labels.clear()
	enemy_hp_label.visible = false
	_make_sprite(player_char, Vector2(60, 58), 1.0 if player_char.art != "" else 3.0)
	var n = enemy_team.size()
	for i in n:
		var e = enemy_team[i]
		if e.art == "": # tile Kenney: 16 px ampliado
			_make_sprite(e, Vector2(255 - (i >> 1) * 70, 55 if n == 1 else 28 + (i % 2) * 44), 4.0 if e.is_boss else 2.0, true)
		elif n == 1: # arte propio de 64 px; menos enemigos = más grande
			_make_sprite(e, Vector2(250, 50), 1.2 if e.is_boss else 1.0)
		elif n == 2:
			_make_sprite(e, Vector2(210 + i * 65, 52), 0.75)
		else:
			_make_sprite(e, Vector2(255 - (i >> 1) * 70, 28 + (i % 2) * 44), 0.5)

# El atacante embiste hacia el objetivo y el objetivo parpadea en rojo.
func animate_attack(attacker: CharacterData, target: CharacterData):
	var a = sprites.get(attacker)
	var t = sprites.get(target)
	if a and t:
		var home = a.position
		var tw = a.create_tween()
		tw.tween_property(a, "position", home + (t.position - home).normalized() * 24, 0.1)
		tw.tween_property(a, "position", home, 0.15)
	flash(target, Color(1, 0.3, 0.3))

func flash(c: CharacterData, color: Color):
	var spr = sprites.get(c)
	if spr:
		_burst(spr.position, color)
		var tw = spr.create_tween()
		tw.tween_property(spr, "modulate", color, 0.08)
		tw.tween_property(spr, "modulate", Color.WHITE, 0.2)

# Chispas pixel que saltan del objetivo (rojo = daño, verde = cura, violeta = estado).
func _burst(pos: Vector2, color: Color):
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color.lightened(0.2)
	p.z_index = 5
	p.finished.connect(p.queue_free)
	stage.add_child(p)

func update_stats():
	if player_char:
		player_hp_label.text = "HP: %d/%d" % [player_char.hp, player_char.max_hp]
		player_mp_label.text = "MP: %d/%d%s" % [player_char.mp, player_char.max_mp, player_char.status_text()]
	for c in hp_labels:
		# con 2+ enemigos no hay sitio para los nombres: solo HP y estados
		var show_name = c != player_char and enemy_team.size() == 1
		hp_labels[c].text = "%s%d/%d%s" % [c.character_name + " " if show_name else "", c.hp, c.max_hp, c.status_text()]
	for c in sprites:
		if c.hp <= 0 and sprites[c].modulate.a > 0.0 and not sprites[c].has_meta("fading"):
			sprites[c].set_meta("fading", true)
			sprites[c].create_tween().tween_property(sprites[c], "modulate:a", 0.0, 0.4)

func show_player_menu():
	skill_menu.get_parent().visible = false
	$Panel/VBox.visible = true
	menu.visible = true

func show_skill_menu(skills: Array):
	_show_list(skills.map(func(sk): return "%s (%d MP)" % [sk.name, sk.mp_cost]), func(i): skill_selected.emit(i))

func show_item_menu(items: Array):
	_show_list(items.map(func(it): return it.name), func(i): item_selected.emit(items[i]))

func _show_list(labels: Array, on_pick: Callable):
	for c in skill_menu.get_children():
		c.queue_free()
	for i in labels.size():
		var b = Button.new()
		b.text = labels[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			skill_menu.get_parent().visible = false
			$Panel/VBox.visible = true
			on_pick.call(i))
		skill_menu.add_child(b)
	var back = Button.new()
	back.text = "Volver"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(show_player_menu)
	skill_menu.add_child(back)
	menu.visible = false
	$Panel/VBox.visible = false
	skill_menu.get_parent().visible = true

func add_log(text: String):
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
