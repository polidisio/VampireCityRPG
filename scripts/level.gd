extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var busy: bool = false
var player_inventory: Inventory
var floor_num: int = 0 # 0 = hub
var max_floor: int = 1
var run_floor: int = 0 # piso más profundo del run en curso (0 = sin run); las escaleras del hub vuelven a él
var has_key := false # el élite del piso soltó la llave: el sello del jefe está roto
var door: StaticBody2D
var event_spots: Array[Vector2] = [] # eventos ya colocados en el piso (para no apilarlos)
var meta := Meta.new()
var run_essence: int = 0 # Esencia ganada en el run en curso (solo para el resumen)
const ESSENCE_RECORD = 10 # por alcanzar un piso nuevo
const BOSS_ESSENCE = 5 # por jefe, más 2 por piso; cada enemigo normal da 1
signal chosen(option: Dictionary)
var quests := QuestLog.new()
var nearby: Callable
var msg: Label
var current_enemy: Area2D
var floor_size := Vector2(320, 180)
var start_pos := Vector2(160, 160)
var hub_bg: TextureRect
var blocked: Array[Rect2] = [] # paredes/pilares del piso actual (para no spawnear encima)
var chase_grace_until := 0 # ms: tras un combate los enemigos no te persiguen un momento
var ground: TextureRect
var cam: Camera2D
var floor_label: Label
var ambient: CanvasModulate
# Suelo por tramo de 5 pisos: [tile, tinte]; se repite al acabar la lista.
const DOOR_FRAC = 0.72 # la puerta del sello está en este x (fracción del ancho); detrás, la sala del jefe
const ELITE_ESSENCE = 3
const BOSS_COLORS = [Color(1, 0.7, 0.2), Color(0.5, 1, 0.4), Color(1, 0.4, 0.2), Color(0.6, 0.5, 1), Color(1, 0.2, 0.4)] # aura por jefe
const RUN_END_GOLD = 10 # oro por piso alcanzado al morir
const CRYPT_ART = "res://assets/sprites/floor1/"
const CRYPT_PROPS = 13
const CRYPT_DECALS = 4
const FLOORS = [[0, Color.WHITE], [48, Color(0.5, 0.55, 0.75)], [53, Color(0.55, 0.8, 0.65)], [49, Color(0.75, 0.65, 1.0)], [13, Color(1.0, 0.8, 0.8)]]
const HUB_ROOM = Rect2(0, 0, 320, 213) # fondo del hub (3:2; la cámara baja unos px con el jugador)
# paredes, muebles y hueco de la escalera (abajo, x 150-171) según el fondo
const HUB_SOLIDS = [Rect2(0, 0, 320, 104), Rect2(0, 0, 22, 213), Rect2(298, 0, 22, 213), Rect2(0, 185, 150, 28), Rect2(171, 185, 149, 28), Rect2(30, 100, 38, 12), Rect2(18, 104, 20, 24), Rect2(288, 118, 12, 30)]
static var _glow_tex: GradientTexture2D

func _ready():
	Controls.setup()
	battle_system.battle_ended.connect(_on_battle_ended)
	battle_system.battle_fled.connect(_on_battle_fled)
	var saved = SaveGame.load_game()
	player_inventory = Inventory.new()
	if not saved.is_empty():
		player_inventory = saved[1]
		floor_num = saved[2]
		max_floor = saved[3]
		quests = saved[4]
		run_floor = saved[5]
		meta = saved[6]
	if saved.is_empty() or saved[0] == null: # sin run: elegir clase empieza uno nuevo
		_show_class_select()
	else:
		player.character_data = saved[0]
	_refresh_modifiers()
	ground = TextureRect.new()
	ground.texture = load("res://assets/sprites/tile_0000.png")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_TILE
	add_child(ground)
	move_child(ground, 1) # sobre Background, bajo todo lo demás
	hub_bg = TextureRect.new()
	hub_bg.texture = load("res://assets/sprites/hub.png")
	hub_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hub_bg.position = HUB_ROOM.position
	hub_bg.size = HUB_ROOM.size
	add_child(hub_bg)
	move_child(hub_bg, 2)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	player.add_child(cam)
	# HUD fijo en pantalla (la cámara se mueve en los pisos grandes)
	var hud = CanvasLayer.new()
	add_child(hud)
	var help: Label = $Label
	floor_label = $FloorLabel
	msg = Label.new()
	floor_label.position = Vector2(20, 150)
	help.position = Vector2(20, 140)
	msg.position = Vector2(20, 130)
	for l in [help, floor_label, msg]:
		if l.get_parent():
			l.reparent(hud, false)
		else:
			hud.add_child(l)
	ambient = CanvasModulate.new()
	add_child(ambient)
	player.add_child(_glow(Color(1, 0.92, 0.8), 110, 0.9))
	y_sort_enabled = true # el jugador se dibuja delante/detrás de NPCs y enemigos según su y
	_spawn_floor()

func _show_class_select():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var layer = CanvasLayer.new()
	layer.layer = 5 # por encima del HUD
	var bg = Panel.new()
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = Label.new()
	title.text = "Elige tu clase"
	title.position = Vector2(112, 12)
	layer.add_child(title)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.position = Vector2(8, 40)
	layer.add_child(row)
	for c in [CharacterData.ClassType.NOBLE, CharacterData.ClassType.SALVAJE, CharacterData.ClassType.DHAMPIR, CharacterData.ClassType.HEMOMANTE]:
		var data = CharacterData.create_for_class(c)
		var card = VBoxContainer.new()
		card.custom_minimum_size.x = 74
		var pic = TextureRect.new()
		pic.texture = data.texture()
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = Vector2(74, 64)
		card.add_child(pic)
		var b = Button.new()
		b.text = data.character_name.replace(" ", "\n")
		b.pressed.connect(func():
			meta.apply_to_run(data)
			layer.queue_free()
			var menu = PactMenu.new(meta.last_pacts)
			add_child(menu)
			data.pacts = await menu.confirmed
			meta.last_pacts = data.pacts
			Pacts.apply_start(data)
			player.character_data = data
			run_essence = 0
			_refresh_modifiers()
			busy = false
			player.process_mode = Node.PROCESS_MODE_INHERIT
			await _spend_picks("Mejora inicial (Iniciado). Elige una:") # solo si el altar la da
			_save())
		card.add_child(b)
		row.add_child(card)
		if row.get_child_count() == 1:
			b.grab_focus.call_deferred()
	add_child(layer)

func _save():
	SaveGame.save(player.character_data, player_inventory, floor_num, max_floor, quests, run_floor, meta)

func _unhandled_input(event):
	if event.is_action_pressed("fullscreen"):
		Controls.toggle_fullscreen()
	if busy:
		return
	if event.is_action_pressed("inventory"):
		_open_inventory()
	elif event.is_action_pressed("interact"):
		if nearby.is_valid():
			nearby.call()
	elif event.is_action_pressed("hub"):
		if floor_num > 0:
			_go_floor(0)
	elif event.is_action_pressed("pause"):
		_open_pause()

func _open_pause():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = PauseMenu.new()
	menu.resumed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT)
	menu.to_title.connect(func():
		_save()
		get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(menu)

func _open_inventory():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = InventoryMenu.new(player.character_data, player_inventory)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

# Luz redonda con borde suave (radio en px); textura compartida.
func _glow(color: Color, radius: float, energy: float) -> PointLight2D:
	if _glow_tex == null:
		var g = Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color.BLACK])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	var l = PointLight2D.new()
	l.texture = _glow_tex
	l.texture_scale = radius * 2.0 / 128.0
	l.color = color
	l.energy = energy
	return l

# Antorcha: luz cálida que titila.
func _torch(parent: Node, radius: float) -> void:
	var l = _glow(Color(1, 0.75, 0.45), radius, 0.6)
	parent.add_child(l)
	l.tree_entered.connect(func():
		var tw = l.create_tween().set_loops()
		tw.tween_property(l, "energy", 0.4, 0.35 + randf() * 0.2)
		tw.tween_property(l, "energy", 0.7, 0.35 + randf() * 0.2))

func _make_area(tile: int, size: float, pos: Vector2, on_enter: Callable, hint: String = "", tex: Texture2D = null) -> Area2D:
	var a = Area2D.new()
	var spr = Sprite2D.new()
	if tile == 45 and not tex:
		tex = load("res://assets/sprites/npcs/escaleras_map.png")
	if tex: # arte propio (ya a escala de mapa): los pies quedan como los de un tile de 16
		spr.texture = tex
		spr.offset.y = -(tex.get_height() - 16) / 2.0
	else:
		spr.texture = load("res://assets/sprites/tile_%04d.png" % tile)
		spr.scale = Vector2.ONE * size / 16.0
	if tile != 45 and not (tex and hint != ""): # las escaleras no llevan sombra ni respiran; el arte de los PNJ ya trae la suya
		Shadow.attach(spr)
		spr.tree_entered.connect(func():
			var base = spr.offset.y
			var tw = spr.create_tween().set_loops()
			tw.tween_property(spr, "offset:y", base - 1.0, 0.5 + randf() * 0.4)
			tw.tween_property(spr, "offset:y", base, 0.5 + randf() * 0.4))
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2.ONE * (size + 22 if hint != "" else size * 0.7)
	a.add_child(spr)
	a.add_child(cs)
	a.position = pos
	a.add_to_group("floor_obj")
	if hint != "" or tile == 45: # NPCs y escaleras iluminan su zona
		_torch(a, 60)
	if hint != "": # NPC: sólido, y se activa con E mientras estés cerca
		a.set_meta("solid", _add_solid(Rect2(pos + Vector2(-6, -8), Vector2(12, 16))))
		var lbl = Label.new()
		lbl.text = hint
		lbl.visible = false
		lbl.z_index = 10
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(160, 10)
		lbl.position = Vector2(-80, -size / 2 - 13)
		a.add_child(lbl)
		a.body_entered.connect(func(_b):
			nearby = on_enter
			lbl.visible = true)
		a.body_exited.connect(func(_b):
			if nearby == on_enter:
				nearby = Callable()
			lbl.visible = false)
	else:
		a.body_entered.connect(func(_b): if not busy: on_enter.call(a))
	add_child(a)
	return a

# Colisión invisible (NPCs).
func _add_solid(r: Rect2) -> StaticBody2D:
	var b = StaticBody2D.new()
	b.collision_layer = 2 # capa propia: las zonas de interacción (máscara 1) no lo detectan
	b.position = r.position
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = r.size
	cs.position = r.size / 2
	b.add_child(cs)
	b.add_to_group("floor_obj")
	add_child(b)
	return b

func _clear_floor():
	nearby = Callable()
	msg.text = ""
	for n in get_tree().get_nodes_in_group("floor_obj"):
		n.queue_free()

func _go_floor(n: int):
	Sfx.play(self, "door")
	_clear_floor()
	floor_num = n
	var record = n > max_floor
	max_floor = maxi(max_floor, n)
	run_floor = maxi(run_floor, n)
	var gained = 0
	if record:
		gained = _gain_essence(ESSENCE_RECORD)
		meta.streak = 0
	busy = true # la física aún tiene al jugador en su sitio antiguo: sin esto, un enemigo nuevo que solape ahí inicia combate al llegar
	_spawn_floor()
	if record:
		_note("Piso récord: +%d Esencia" % gained)
	_save()
	await get_tree().physics_frame
	await get_tree().physics_frame
	busy = false

func _add_block(r: Rect2, tex: Texture2D, tiled := true):
	var b = StaticBody2D.new()
	b.position = r.position
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = r.size
	cs.position = r.size / 2
	var t = TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tiled:
		t.stretch_mode = TextureRect.STRETCH_TILE
		t.size = r.size
	else: # prop: sprite a su tamaño, apoyado en la base del bloque de colisión y centrado
		t.size = tex.get_size()
		t.position = Vector2((r.size.x - t.size.x) / 2, r.size.y - t.size.y)
	b.add_child(t)
	b.add_child(cs)
	b.add_to_group("floor_obj")
	add_child(b)
	blocked.append(r)

# Un bloque cabe si está dentro del margen, lejos del inicio y con >=24px de paso respecto a los demás.
func _placeable(r: Rect2) -> bool:
	return Rect2(48, 48, floor_size.x - 96, floor_size.y - 96).encloses(r) \
		and not r.grow(64).has_point(start_pos) \
		and not blocked.any(func(o): return o.intersects(r.grow(24)))

func _build_walls():
	var w = floor_size.x
	var h = floor_size.y
	for r in [Rect2(0, 0, w, 16), Rect2(0, h - 16, w, 16), Rect2(0, 16, 16, h - 32), Rect2(w - 16, 16, 16, h - 32)]:
		_add_block(r, _wall_tex(r))
	# ponytail: obstáculos aleatorios con separación mínima, así nunca bloquean el paso
	for i in 3:
		var seg = randi_range(5, 8) * 16
		var size = Vector2(seg, 16) if randf() < 0.5 else Vector2(16, seg)
		var r = Rect2(Vector2(randi_range(3, int(w / 16) - 4), randi_range(3, int(h / 16) - 4)) * 16, size)
		if _placeable(r):
			_add_block(r, _wall_tex(r))
	for i in 40:
		var r = Rect2(Vector2(randi_range(3, int(w / 16) - 4), randi_range(3, int(h / 16) - 4)) * 16, Vector2(16, 16))
		if _placeable(r):
			if _crypt():
				_add_block(r, load(CRYPT_ART + "prop_%d.png" % randi_range(0, CRYPT_PROPS - 1)), false)
			else:
				_add_block(r, load("res://assets/sprites/tile_%04d.png" % [64, 65, 82].pick_random()))
	if _crypt():
		_scatter_decals()

# Pisos 1-5: arte de cripta (tools/make_floor1.py). El resto sigue con los tiles Kenney.
func _crypt() -> bool:
	return floor_num > 0 and ((floor_num - 1) / 5) % FLOORS.size() == 0

func _wall_tex(r: Rect2) -> Texture2D:
	if _crypt():
		return load(CRYPT_ART + ("wall_cap.png" if r.size.x > r.size.y else "wall_brick.png"))
	return load("res://assets/sprites/tile_0057.png")

# Manchas y huesos sobre el suelo (sin colisión, bajo jugador y enemigos).
func _scatter_decals():
	for i in 10:
		var d = TextureRect.new()
		d.texture = load(CRYPT_ART + "decal_%d.png" % randi_range(1, CRYPT_DECALS - 1)) # el 0 (salpicadura grande) queda para el pozo de sangre
		d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		d.position = Vector2(randf_range(24, floor_size.x - 24 - d.texture.get_width()), randf_range(24, floor_size.y - 24 - d.texture.get_height()))
		d.add_to_group("floor_obj")
		add_child(d)
		move_child(d, 3)

func _free_pos(area: Rect2, avoid: Vector2 = start_pos, min_dist: float = 100.0) -> Vector2:
	var p = area.get_center()
	for i in 60:
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(avoid) >= min_dist and not blocked.any(func(r): return r.grow(14).has_point(p)) and not event_spots.any(func(e): return e.distance_to(p) < 40):
			break
	return p

# Un fondo al azar del tema del piso (un tema por bloque de 5 pisos, igual que FLOORS). El hub usa cualquiera.
const BACKDROPS = [5, 6, 6, 5, 6] # fondos por tema en assets/backgrounds/<tema>_<n>.png
func _battle_backdrop() -> Texture2D:
	var theme = ((floor_num - 1) / 5) % BACKDROPS.size() if floor_num > 0 else randi() % BACKDROPS.size()
	return load("res://assets/backgrounds/%d_%d.png" % [theme, randi() % BACKDROPS[theme]])

# Hub y pisos 1-5: tema de exploración; del piso 6 en adelante, el tema profundo.
func _explore_music() -> void:
	Music.play(self, "deep" if floor_num >= 6 else "explore")

func _spawn_floor():
	_explore_music()
	blocked.clear()
	event_spots.clear()
	has_key = false
	var tower = floor_num > 0
	floor_size = Vector2(640, 360) if tower else Vector2(320, 213)
	start_pos = Vector2(48, 180) if tower else Vector2(160, 160)
	ground.visible = tower
	hub_bg.visible = not tower
	ground.size = floor_size
	$Background.size = floor_size
	cam.limit_right = int(floor_size.x)
	cam.limit_bottom = int(floor_size.y)
	player.position = start_pos
	# más oscuro cuanto más alto el piso (mínimo para que se vea a los enemigos)
	ambient.color = Color(0.62, 0.58, 0.78).lerp(Color(0.28, 0.25, 0.42), minf(floor_num, 10) / 10.0) if tower else Color(0.9, 0.86, 1.0)
	var fl = FLOORS[((floor_num - 1) / 5) % FLOORS.size()] if tower else FLOORS[0]
	if _crypt():
		ground.texture = load(CRYPT_ART + ["ground_a.png", "ground_b.png"].pick_random())
		ground.modulate = Color.WHITE
	else:
		ground.texture = load("res://assets/sprites/tile_%04d.png" % fl[0])
		ground.modulate = fl[1]
	if tower:
		_build_walls()
	if not tower:
		for r in HUB_SOLIDS:
			_add_solid(r)
		floor_label.text = "HUB - PISO MAX %d" % max_floor
		_make_area(112, 28, Vector2(90, 135), _say.bind("mercader"), "E: Tienda", load("res://assets/sprites/npcs/mercader_map.png"))
		_make_area(99, 28, Vector2(230, 135), _say.bind("posadera"), "E: Descansar (10 oro)", load("res://assets/sprites/npcs/posadera_map.png"))
		_make_area(86, 28, Vector2(160, 124), _say.bind("anciano"), "E: Hablar con el Anciano", load("res://assets/sprites/npcs/anciano_map.png"))
		_make_area(60, 24, Vector2(48, 160), _open_altar, "E: Altar", load(CRYPT_ART + "prop_5.png")) # sarcófago de la cripta: ponytail, sin arte propio de altar
		_make_area(45, 16, Vector2(160, 198), func(_a): _go_floor(maxi(1, run_floor))).get_child(0).visible = false # las escaleras ya están en el fondo
		return
	var w = floor_size.x
	var h = floor_size.y
	_build_seal()
	_spawn_events()
	_spawn_elite()
	for n in randi_range(4, 7):
		var group = _enemy_group()
		var ga = _make_area(group[0].sprite_tile, 20, _free_pos(_roam_rect()), try_start_battle, "", group[0].texture(true))
		ga.set_meta("enemies", group)
		EnemyAI.new().setup(ga, self, _chase_speed())
	var boss = CharacterData.create_boss(floor_num)
	_scale_enemy(boss, true)
	var ba = _make_area(boss.sprite_tile, 32, _free_pos(Rect2(w * DOOR_FRAC + 8, 32, w * (1.0 - DOOR_FRAC) - 40, h - 64)), try_start_battle, "", boss.texture(true))
	ba.set_meta("boss", true)
	ba.set_meta("enemies", [boss])
	_boss_presence(ba, boss)

# Velocidad de persecución: lenta en el piso 1 (20 px/s, el jugador va a 60) y sube con la profundidad hasta un tope de 42.
func _chase_speed() -> float:
	return minf(20.0 + 1.5 * floor_num, 42.0)

# Zona por la que se mueven los enemigos: antes del sello, lejos de los bordes.
func enemy_bounds() -> Rect2:
	return Rect2(24, 24, floor_size.x * DOOR_FRAC - 16 - 24 - 14, floor_size.y - 48)

# Dónde viven los enemigos, el élite y los eventos: antes de la puerta del sello.
func _roam_rect() -> Rect2:
	return Rect2(120, 32, floor_size.x * DOOR_FRAC - 24 - 120 - 16, floor_size.y - 64)

func _update_floor_label() -> void:
	floor_label.text = "PISO %d  (H: hub)  %s" % [floor_num, "Sello roto" if has_key else "Sello: busca al élite"]

# Puerta que separa la sala del jefe hasta que cae el élite (que lleva la llave).
func _build_seal() -> void:
	var r = Rect2(floor_size.x * DOOR_FRAC - 16, 16, 16, floor_size.y - 32)
	door = StaticBody2D.new()
	door.position = r.position
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = r.size
	cs.position = r.size / 2
	var t = TextureRect.new()
	t.texture = _wall_tex(r)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.size = r.size
	var glow = ColorRect.new() # velo rojo que late
	glow.color = Color(0.9, 0.1, 0.2, 0.55)
	glow.size = r.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.tree_entered.connect(func():
		var tw = glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.4, 0.8)
		tw.tween_property(glow, "modulate:a", 1.0, 0.8))
	var lock = TextureRect.new()
	lock.texture = Icons.tex("skull")
	lock.position = Vector2(3.5, r.size.y / 2 - 4.5)
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var zone = Area2D.new() # avisa al tocarla
	var zs = CollisionShape2D.new()
	zs.shape = RectangleShape2D.new()
	zs.shape.size = Vector2(r.size.x + 12, r.size.y)
	zs.position = r.size / 2
	zone.add_child(zs)
	zone.body_entered.connect(func(_b):
		if not has_key:
			_note("El sello resiste. Busca al élite del piso."))
	for n in [t, glow, lock, cs, zone]:
		door.add_child(n)
	door.add_to_group("floor_obj")
	add_child(door)
	_update_floor_label()

# Un élite por piso, lejos de la entrada: más fuerte, con brillo dorado y la llave flotando sobre él.
func _spawn_elite() -> void:
	var e = CharacterData.create_elite(floor_num)
	_scale_enemy(e)
	var a = _make_area(e.sprite_tile, 24, _free_pos(_roam_rect(), start_pos, 160.0), try_start_battle, "", e.texture(true))
	a.set_meta("enemies", [e])
	a.set_meta("elite", true)
	EnemyAI.new().setup(a, self, _chase_speed() * 0.75) # el élite es más lento
	a.get_child(0).scale = Vector2.ONE * 1.25
	a.add_child(_glow(Color(1, 0.8, 0.3), 46, 0.9))
	var k = TextureRect.new()
	k.texture = Icons.tex("key")
	k.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	k.position = Vector2(-4.5, -34)
	a.add_child(k)
	k.tree_entered.connect(func():
		var tw = k.create_tween().set_loops()
		tw.tween_property(k, "position:y", -37.0, 0.5)
		tw.tween_property(k, "position:y", -34.0, 0.5))

func _break_seal() -> void:
	Sfx.play(self, "key")
	has_key = true
	if is_instance_valid(door):
		door.queue_free()
	var g = _gain_essence(ELITE_ESSENCE)
	_note("¡Llave! El sello del jefe se rompe (+%d Esencia)" % g)
	_update_floor_label()

# Jefe: más grande, aura de color propio por jefe, nombre encima y sala teñida de rojo.
func _boss_presence(ba: Area2D, boss: CharacterData) -> void:
	var color = BOSS_COLORS[(floor_num - 1) % BOSS_COLORS.size()]
	var th = boss.texture(true).get_height()
	ba.get_child(0).scale = Vector2.ONE * 1.5
	ba.add_child(_glow(color, 90, 1.0))
	var l = Label.new()
	l.text = boss.character_name.to_upper()
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(140, 12)
	l.position = Vector2(-70, -(th - 8) * 1.5 - 14)
	ba.add_child(l)
	var room = ColorRect.new()
	room.color = Color(0.55, 0.05, 0.1, 0.22)
	room.position = Vector2(floor_size.x * DOOR_FRAC, 16)
	room.size = Vector2(floor_size.x * (1.0 - DOOR_FRAC) - 16, floor_size.y - 32)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_to_group("floor_obj")
	add_child(room)
	move_child(room, 3) # sobre el suelo, bajo jugador y enemigos

# Tarjeta de entrada del jefe: "PISO N / NOMBRE".
func _boss_intro(boss: CharacterData) -> void:
	Sfx.play(self, "door")
	Sfx.play(self, "roar")
	var layer = CanvasLayer.new()
	layer.layer = 8
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0, 0.05, 0.0)
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var color = BOSS_COLORS[(floor_num - 1) % BOSS_COLORS.size()]
	var box = VBoxContainer.new()
	box.modulate.a = 0.0
	layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for line in [["PISO %d" % floor_num, 8, Color(0.8, 0.8, 0.9)], [boss.character_name.to_upper(), 16, color]]:
		var l = Label.new()
		l.text = line[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
		l.add_theme_constant_override("outline_size", 3)
		box.add_child(l)
	add_child(layer)
	var tw = layer.create_tween().set_parallel()
	tw.tween_property(bg, "color:a", 0.9, 0.4)
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(1.6).timeout
	layer.queue_free()

# Eventos del piso: ataúdes (botín o emboscada), pozo de sangre (cura), sarcófago (pacto) y mercader errante.
func _spawn_events() -> void:
	var coffin = load(CRYPT_ART + "prop_0.png")
	for i in 2:
		_make_event(coffin, "E: Abrir ataúd", _open_coffin)
	_make_event(load(CRYPT_ART + "decal_0.png"), "E: Pozo de sangre", _drink_well)
	if randf() < 0.4:
		_make_event(load(CRYPT_ART + "prop_5.png"), "E: Pacto de sangre", _open_sarcophagus)
	if randf() < 0.25:
		_make_event(load("res://assets/sprites/npcs/mercader_map.png"), "E: Mercader errante", func(_n): _open_shop())

func _make_event(tex: Texture2D, hint: String, handler: Callable) -> Area2D:
	var holder = []
	var pos = _free_pos(_roam_rect(), start_pos, 90.0)
	var a = _make_area(0, 24, pos, func(): handler.call(holder[0]), hint, tex)
	holder.append(a)
	event_spots.append(pos)
	return a

# Quita un objeto del piso con su colisión (los de interacción llevan un sólido aparte).
func _remove_obj(n: Node) -> void:
	if n.has_meta("solid") and is_instance_valid(n.get_meta("solid")):
		n.get_meta("solid").queue_free()
	n.queue_free()
	nearby = Callable()

func _open_coffin(node: Area2D, roll := randf()) -> void:
	if roll < 0.3: # emboscada
		node.set_meta("enemies", _enemy_group())
		nearby = Callable()
		_note("¡Emboscada!")
		try_start_battle(node)
		return
	var gold = int((randi_range(15, 40) + 5 * floor_num) * battle_system.gold_mult)
	player_inventory.add_gold(gold)
	var text = "Ataúd: +%d oro" % gold
	var ess = _gain_essence(2)
	text += ", +%d Esencia" % ess
	var pool = ItemData.get_all_consumables().filter(func(i): return i.value <= 40 + 40 * floor_num)
	if randf() < 0.4 and not pool.is_empty():
		var item = pool.pick_random()
		player_inventory.add_item(item)
		text += ", " + item.name
	Sfx.play(self, "coins")
	_note(text)
	_remove_obj(node)

func _drink_well(node: Area2D) -> void:
	var c = player.character_data
	if c.hp >= c.max_hp:
		_note("No necesitas beber ahora.")
		return
	var amount = c.max_hp / 2
	c.heal(amount)
	Sfx.play(self, "heal")
	_note("Pozo de sangre: +%d vida" % amount)
	_remove_obj(node)

func _open_sarcophagus(node: Area2D) -> void:
	var c = player.character_data
	var cost = c.max_hp / 4
	var offers = Upgrades.relic_offers(c)
	if offers.is_empty():
		_note("El sarcófago está vacío.")
		return
	if c.hp <= cost:
		_note("Estás demasiado débil para el pacto.")
		return
	c.hp -= cost
	_remove_obj(node)
	Upgrades.apply_relic(c, await _choose("Pacto de sangre (-%d vida). Elige una reliquia:" % cost, offers))
	_save()

func _enemy_group() -> Array[CharacterData]:
	var difficulty = clampi(floor_num, 1, 5)
	var group: Array[CharacterData] = []
	for i in Pacts.enemy_count(CharacterData.get_enemy_count_for_difficulty(difficulty), player.character_data.pacts):
		var e = CharacterData.get_random_enemy(difficulty, floor_num)
		_scale_enemy(e)
		group.append(e)
	return group

func _open_shop():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = ShopMenu.new(player_inventory, _face("mercader"))
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

func _face(npc: String) -> Texture2D:
	return load("res://assets/sprites/npcs/%s_face.png" % npc)

func _open_dialog(text: String, actions: Array = [], face: Texture2D = null, closable := true) -> DialogBox:
	Sfx.play(self, "dialog")
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var box = DialogBox.new(text, actions, face, closable)
	box.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT)
	add_child(box)
	return box

# Elección obligatoria entre mejoras (Upgrades); devuelve la elegida.
func _choose(title: String, offers: Array) -> Dictionary:
	var lines = [title]
	var actions = []
	for o in offers:
		lines.append("- %s: %s" % [o.name, o.desc])
		actions.append([o.name, func(): chosen.emit(o)])
	_open_dialog("\n".join(lines), actions, null, false)
	return await chosen

func _pick_relic() -> void:
	var offers = Upgrades.relic_offers(player.character_data)
	if not offers.is_empty():
		Upgrades.apply_relic(player.character_data, await _choose("Reliquia del jefe. Elige una:", offers))

func _spend_picks(title := "") -> void:
	var c = player.character_data
	while c.pending_picks > 0:
		c.pending_picks -= 1
		Upgrades.apply(c, await _choose(title if title != "" else "¡Nivel %d! Elige una mejora:" % (c.level - c.pending_picks), Upgrades.level_offers(c)))

# Aviso breve en el HUD (se borra solo si nada lo ha sustituido).
func _note(text: String) -> void:
	msg.text = text
	get_tree().create_timer(3.0).timeout.connect(func():
		if msg.text == text:
			msg.text = "")

# Esencia con la recompensa de los pactos; devuelve lo ganado.
func _gain_essence(n: int) -> int:
	var c = player.character_data
	var g = int(round(n * Pacts.reward_mult(c.pacts if c else [])))
	meta.essence += g
	run_essence += g
	return g

# Oro y mochila según altar y pactos del run.
func _refresh_modifiers() -> void:
	var pacts: Array = player.character_data.pacts if player.character_data else []
	battle_system.gold_mult = meta.gold_mult() * Pacts.gold_mult(pacts)
	player_inventory.max_consumables = 0 if pacts.has("ayuno") else meta.max_consumables()

func _scale_enemy(e: CharacterData, boss := false) -> void:
	Pacts.scale_enemy(e, player.character_data.pacts if player.character_data else [], boss, meta.assist())

func _open_altar():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = AltarMenu.new(meta)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_refresh_modifiers()
		_save())
	add_child(menu)

func _say(npc: String, node: String = "start"):
	var c = player.character_data
	var v = Dialogues.pick(npc, node, {"max_floor": max_floor, "level": c.level, "claimed": quests.claimed,
		"hp": c.hp, "max_hp": c.max_hp, "gold": player_inventory.gold})
	if v.is_empty():
		return
	var acts = {"quest": _talk, "rest": _rest, "shop": _open_shop}
	var actions = []
	for o in v.get("options", []):
		actions.append([o.label, acts[o.do] if o.has("do") else _say.bind(npc, o.go)])
	_open_dialog(v.text, actions, _face(npc))

func _talk():
	var q = quests.current()
	if q.is_empty():
		_open_dialog("Anciano: Has cumplido todos mis encargos, cazador. La torre es tuya.", [], _face("anciano"))
		return
	quests.counters["floor"] = max_floor
	var item = ItemData.find_by_id(q.item)
	var text = "Anciano: %s\nProgreso: %d/%d (%s)\nRecompensa: %d oro + %s" % [
		q.title, mini(quests.counters[q.kind], q.goal), q.goal,
		QuestLog.KIND_TEXT[q.kind], q.gold, item.name]
	_open_dialog(text, [["Cobrar", _claim.bind(q)]] if quests.is_ready(q) else [], _face("anciano"))

func _claim(q: Dictionary):
	Sfx.play(self, "coins")
	quests.claimed.append(q.id)
	player_inventory.add_gold(q.gold)
	player_inventory.add_item(ItemData.find_by_id(q.item))
	_save()
	_talk()

func _rest():
	var c = player.character_data
	if player_inventory.spend_gold(10):
		c.hp = c.max_hp
		c.mp = c.max_mp
		Sfx.play(self, "heal")
		_save()
		_open_dialog("Posadera: Descansa, cazador. Tienes HP y MP al máximo. (-10 oro)", [], _face("posadera"))
	else:
		_open_dialog("Posadera: Sin 10 monedas no hay cama, cazador.", [], _face("posadera"))

func try_start_battle(enemy_node: Area2D):
	if busy:
		return
	current_enemy = enemy_node
	var enemies: Array[CharacterData] = []
	enemies.assign(enemy_node.get_meta("enemies"))
	battle_system.floor_num = floor_num
	if not enemy_node.has_meta("theme"): # el mismo enemigo siempre suena igual, aunque huyas y vuelvas
		enemy_node.set_meta("theme", Music.pick("boss" if enemy_node.has_meta("boss") else "battle"))
	battle_system.theme = enemy_node.get_meta("theme")
	battle_system.ui.set_backdrop(_battle_backdrop())
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if enemy_node.has_node("EnemyAI"): # embestida antes del combate
		var spr = enemy_node.get_child(0)
		var base = spr.position
		var lunge = create_tween()
		lunge.tween_property(spr, "position", base + (player.position - enemy_node.position).normalized() * 8.0, 0.09)
		lunge.tween_property(spr, "position", base, 0.09)
		await lunge.finished
	if enemy_node.has_meta("boss"):
		await _boss_intro(enemies[0])
	battle_system.start_battle(player.character_data, enemies, player_inventory)

func _end_battle():
	chase_grace_until = Time.get_ticks_msec() + 1500
	_explore_music()
	battle_system.ui.visible = false
	busy = false
	player.process_mode = Node.PROCESS_MODE_INHERIT

func _on_battle_ended(victory: bool):
	await get_tree().create_timer(1.3).timeout # deja leer el log final antes de cerrar el combate
	_end_battle()
	if victory:
		quests.add("kill", battle_system.enemy_team.size())
		var gain = _gain_essence(battle_system.enemy_team.size() + (BOSS_ESSENCE + 2 * floor_num if current_enemy.has_meta("boss") else 0))
		_note("+%d Esencia" % gain)
		if current_enemy.has_meta("boss"):
			meta.streak = 0
		if current_enemy.has_meta("boss"):
			quests.add("boss")
			msg.text = "¡Jefe derrotado! Baja por las escaleras (+%d Esencia)" % gain
		var boss = current_enemy.has_meta("boss")
		var boss_pos = current_enemy.position
		if current_enemy.has_meta("elite"):
			_break_seal()
		_remove_obj(current_enemy)
		if boss:
			await _pick_relic()
		await _spend_picks()
		if boss: # las escaleras salen cuando ya no hay menús abiertos
			_open_stairs(boss_pos)
		_save()
	else:
		await _end_run()

# La muerte cierra el run: se pierde la build (nivel, habilidades, reliquias, equipo y objetos); se conservan el oro y la meta.
func _end_run() -> void:
	var c = player.character_data
	var bonus = RUN_END_GOLD * floor_num # consuelo: la muerte no deja con las manos vacías
	player_inventory.add_gold(bonus)
	meta.streak += 1
	var help = "\nAyuda: enemigos -%d%% hasta que superes un jefe o un récord." % int(meta.assist() * 100) if meta.assist() > 0 else ""
	var box = _open_dialog("Has caído en el piso %d.\nNivel %d, %d reliquias.\nBotín del superviviente: +%d oro.\nEsencia del run: +%d (tienes %d). Gástala en el altar.%s" % [floor_num, c.level, c.relics.size(), bonus, run_essence, meta.essence, help])
	await box.closed
	player_inventory.items.clear()
	SaveGame.save(null, player_inventory, 0, max_floor, quests, 0, meta)
	get_tree().reload_current_scene()

# Escaleras al piso siguiente: cerca del jefe caído pero a >=32px del jugador, para no activarlas al instante.
func _open_stairs(boss_pos: Vector2) -> void:
	var near = Rect2(boss_pos - Vector2(48, 48), Vector2(96, 96)).intersection(Rect2(32, 32, floor_size.x - 64, floor_size.y - 64))
	var stairs = _make_area(45, 16, _free_pos(near, player.position, 32.0), func(_a): _go_floor(floor_num + 1))
	stairs.modulate.a = 0.0 # el hueco se abre en el suelo
	stairs.create_tween().tween_property(stairs, "modulate:a", 1.0, 0.8)

func _on_battle_fled():
	_end_battle()
	chase_grace_until = Time.get_ticks_msec() + 3000 # huir da más ventaja
	# ponytail: empuja al jugador fuera del enemigo para no re-disparar
	player.move_and_collide((player.position - current_enemy.position).normalized() * 24)
	_save()
