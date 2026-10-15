extends Control

signal skill_selected(index: int)
signal item_selected(item: ItemData)
signal item_pressed

@onready var menu = $Panel/Menu
var skill_menu: GridContainer
var log_label: Label
var log_lines: Array[String] = []

var player_char: CharacterData
var stage: Node2D
var sprites: Dictionary = {} # CharacterData -> Sprite2D
var hp_bars: Dictionary = {} # CharacterData -> Bar
var status_rows: Dictionary = {} # CharacterData -> HBoxContainer (iconos de estado con turnos)
var intent_rows: Dictionary = {} # CharacterData -> HBoxContainer (qué hará el enemigo)
var incoming_row: HBoxContainer # daño total que recibirá el jugador
var player_hp_bar: Bar
var player_mp_bar: Bar
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
	scroll.size = Vector2(292, 56)
	skill_menu = GridContainer.new() # 2 columnas: caben 6 botones en el panel
	skill_menu.columns = 2
	skill_menu.custom_minimum_size.x = 286
	scroll.add_child(skill_menu)
	var ib = Button.new()
	ib.text = "Objeto"
	menu.add_child(ib)
	menu.move_child(ib, 2)
	ib.pressed.connect(func(): item_pressed.emit())
	$Panel/VBox.add_theme_constant_override("separation", 2)
	player_hp_bar = Bar.new(Color(0.8, 0.15, 0.2), 130, 11)
	player_mp_bar = Bar.new(Color(0.2, 0.4, 0.9), 130, 11)
	player_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	player_mp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	$Panel/VBox.add_child(player_hp_bar)
	$Panel/VBox.add_child(player_mp_bar)
	log_label = Label.new() # solo lo que los símbolos no cuentan: victoria, botín, avisos
	log_label.position = Vector2(150, 6)
	log_label.size = Vector2(140, 36)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel.add_child(log_label)

func setup_battle(player_team_ref: Array[CharacterData], enemy_team_ref: Array[CharacterData]):
	player_char = player_team_ref[0]
	enemy_team = enemy_team_ref
	log_lines.clear()
	log_label.text = ""
	_build_stage()
	update_stats()
	menu.visible = false
	skill_menu.get_parent().visible = false

func _make_sprite(c: CharacterData, pos: Vector2, scale_f: float, bar_w: float, flip: bool = false) -> void:
	var spr = Sprite2D.new()
	spr.texture = c.texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2.ONE * scale_f
	spr.flip_h = flip
	Shadow.attach(spr)
	stage.add_child(spr)
	sprites[c] = spr
	var top = pos.y - spr.texture.get_height() / 2.0 * scale_f
	var bottom = pos.y + spr.texture.get_height() / 2.0 * scale_f
	var bw = bar_w
	var bob = spr.create_tween().set_loops() # respiración: offset (no position) para no chocar con la embestida
	bob.tween_property(spr, "offset:y", -1.0, 0.5 + randf() * 0.3)
	bob.tween_property(spr, "offset:y", 0.0, 0.5 + randf() * 0.3)
	var bar = Bar.new(Color(0.8, 0.15, 0.2), bw)
	bar.position = Vector2(pos.x - bw / 2.0, bottom + 1)
	if c != player_char and enemy_team.size() == 1:
		bar.prefix = c.character_name + " " # con 1 enemigo hay sitio para el nombre
	stage.add_child(bar)
	hp_bars[c] = bar
	var st = _row(Vector2(pos.x - bw / 2.0, bottom + 11), bw)
	status_rows[c] = st
	if c != player_char:
		intent_rows[c] = _row(Vector2(pos.x - 40, maxf(1.0, top - 9)), 80)

# Fila centrada de iconos (+ texto) de ancho fijo.
func _row(pos: Vector2, w: float) -> HBoxContainer:
	var r = HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 1)
	r.position = pos
	r.custom_minimum_size = Vector2(w, 9)
	r.size = r.custom_minimum_size
	r.z_index = 4
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(r)
	return r

func _clear_row(r: HBoxContainer) -> void:
	for n in r.get_children():
		n.queue_free()

func _add_icon(r: HBoxContainer, name: String) -> void:
	var t = TextureRect.new()
	t.texture = Icons.tex(name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(9, 9)
	r.add_child(t)

func _add_text(r: HBoxContainer, text: String) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	r.add_child(l)

func _build_stage():
	for n in stage.get_children():
		n.queue_free()
	sprites.clear()
	hp_bars.clear()
	status_rows.clear()
	intent_rows.clear()
	_make_sprite(player_char, Vector2(60, 50), 1.0 if player_char.art != "" else 3.0, 64)
	incoming_row = _row(Vector2(20, 1), 80)
	var n = enemy_team.size()
	for i in n:
		var e = enemy_team[i]
		if e.art == "": # tile Kenney: 16 px ampliado
			_make_sprite(e, Vector2(255 - (i >> 1) * 70, 48 if n == 1 else 28 + (i % 2) * 44), 4.0 if e.is_boss else 2.0, 120 if n == 1 else 48, true)
		elif n == 1: # arte propio de 64 px; menos enemigos = más grande
			_make_sprite(e, Vector2(250, 46), 1.1 if e.is_boss else 1.0, 130)
		elif n == 2:
			_make_sprite(e, Vector2(210 + i * 65, 50), 0.75, 56)
		else:
			_make_sprite(e, Vector2(255 - (i >> 1) * 70, 24 + (i % 2) * 50), 0.45, 48)

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

# Número que sube y se desvanece sobre el sprite (varios a la vez se apilan un poco).
func float_text(c: CharacterData, text: String, color: Color):
	var spr = sprites.get(c)
	if not spr:
		return
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(60, 10)
	var top = spr.position.y - spr.texture.get_height() / 2.0 * spr.scale.y
	var stack = spr.get_meta("floats", 0) # varios textos a la vez sobre el mismo sprite se apilan
	spr.set_meta("floats", stack + 1)
	l.position = Vector2(spr.position.x - 30, top - 4 - stack * 10)
	l.z_index = 6
	stage.add_child(l)
	var tw = l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(func():
		spr.set_meta("floats", maxi(0, spr.get_meta("floats", 1) - 1))
		l.queue_free())

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
	var system: BattleSystem = get_parent()
	if player_char:
		player_hp_bar.set_value(player_char.hp, player_char.max_hp)
		player_mp_bar.set_value(player_char.mp, player_char.max_mp)
		var dmg = system.incoming_damage() if system.is_battle_active and system.incoming_count() > 1 else 0 # con 1 atacante repetiría su intención
		_clear_row(incoming_row)
		if dmg > 0:
			_add_icon(incoming_row, "sword")
			_add_text(incoming_row, str(dmg))
	for c in hp_bars:
		hp_bars[c].set_value(c.hp, c.max_hp)
		var alive = c.hp > 0
		hp_bars[c].visible = alive
		status_rows[c].visible = alive
		_clear_row(status_rows[c])
		for k in c.statuses:
			_add_icon(status_rows[c], Icons.STATUS.get(k, "skull"))
			_add_text(status_rows[c], str(c.statuses[k])) # turnos restantes
		if c in intent_rows:
			intent_rows[c].visible = alive and system.is_battle_active
			if alive:
				var info = system.intent_info(c)
				_clear_row(intent_rows[c])
				for ic in info.icons:
					_add_icon(intent_rows[c], ic)
				if info.value > 0:
					_add_text(intent_rows[c], str(info.value))
	for c in sprites:
		if c.hp <= 0 and sprites[c].modulate.a > 0.0 and not sprites[c].has_meta("fading"):
			sprites[c].set_meta("fading", true)
			sprites[c].create_tween().tween_property(sprites[c], "modulate:a", 0.0, 0.4)

func _show_info(v: bool) -> void:
	$Panel/VBox.visible = v
	log_label.visible = v

func show_target_menu(targets: Array, on_pick: Callable, base: int = 0):
	var system: BattleSystem = get_parent()
	_show_list(targets.map(func(t): return "%s %d/%d%s" % [t.character_name, t.hp, t.max_hp, "  -%d" % system.damage_vs(t, base) if base > 0 else ""]), on_pick, [], func(i): _highlight(targets[i]))
	_highlight(targets[0]) # el primer botón ya tiene el foco

# Aclara el sprite del enemigo elegido (null: ninguno). Solo toca el color, no el alfa del desvanecido.
func _highlight(target) -> void:
	for c in enemy_team:
		var spr = sprites.get(c)
		if spr:
			var v = 1.7 if c == target else 1.0
			spr.modulate = Color(v, v, v, spr.modulate.a)

func show_player_menu():
	var system: BattleSystem = get_parent()
	var t = system.single_target()
	$Panel/Menu/AttackBtn.text = "Atacar -%d" % system.damage_vs(t, player_char.attack) if t else "Atacar" # el daño que harás
	_highlight(null)
	skill_menu.get_parent().visible = false
	_show_info(true)
	menu.visible = true
	menu.get_child(0).grab_focus.call_deferred()

func show_skill_menu(skills: Array):
	var system: BattleSystem = get_parent()
	var t = system.single_target()
	_show_list(skills.map(func(sk): return "%s (%d MP)%s" % [sk.name, sk.mp_cost, "  -%d" % system.damage_vs(t, sk.damage) if t and sk.damage > 0 and not sk.on_self and not sk.is_heal else ""]), func(i): skill_selected.emit(i), skills.map(func(sk): return Icons.tex(Icons.skill_icons(sk)[0])))

func show_item_menu(items: Array):
	_show_list(items.map(func(it): return it.name), func(i): item_selected.emit(items[i]))

func _show_list(labels: Array, on_pick: Callable, icons: Array = [], on_focus := Callable()):
	for c in skill_menu.get_children():
		c.queue_free()
	var first: Button
	for i in labels.size():
		var b = Button.new()
		first = first if first else b
		b.text = labels[i]
		if i < icons.size():
			b.icon = icons[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if on_focus.is_valid():
			b.focus_entered.connect(on_focus.bind(i))
		b.pressed.connect(func():
			_highlight(null)
			skill_menu.get_parent().visible = false
			_show_info(true)
			on_pick.call(i))
		skill_menu.add_child(b)
	var back = Button.new()
	back.text = "Volver"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(show_player_menu)
	skill_menu.add_child(back)
	menu.visible = false
	_show_info(false)
	skill_menu.get_parent().visible = true
	(first if first else back).grab_focus.call_deferred()

func add_log(text: String):
	log_lines.append(text)
	if log_lines.size() > 3:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
