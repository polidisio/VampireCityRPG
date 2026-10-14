extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var busy: bool = false
var player_inventory: Inventory
var floor_num: int = 0 # 0 = hub
var max_floor: int = 1
var quests := QuestLog.new()
var nearby: Callable
var msg: Label
var current_enemy: Area2D
var floor_size := Vector2(320, 180)
var start_pos := Vector2(160, 100)
var blocked: Array[Rect2] = [] # paredes/pilares del piso actual (para no spawnear encima)
var ground: TextureRect
var cam: Camera2D
var floor_label: Label

func _ready():
	battle_system.battle_ended.connect(_on_battle_ended)
	battle_system.battle_fled.connect(_on_battle_fled)
	var saved = SaveGame.load_game()
	if saved.is_empty():
		player_inventory = Inventory.new()
		_show_class_select()
	else:
		player.character_data = saved[0]
		player_inventory = saved[1]
		floor_num = saved[2]
		max_floor = saved[3]
		quests = saved[4]
	ground = TextureRect.new()
	ground.texture = load("res://assets/sprites/tile_0000.png")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_TILE
	add_child(ground)
	move_child(ground, 1) # sobre Background, bajo todo lo demás
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
	msg.position = Vector2(10, 150)
	for l in [help, floor_label, msg]:
		if l.get_parent():
			l.reparent(hud, false)
		else:
			hud.add_child(l)
		l.add_theme_font_size_override("font_size", 8)
	_spawn_floor()

func _show_class_select():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var layer = CanvasLayer.new()
	var box = VBoxContainer.new()
	box.position = Vector2(100, 20)
	layer.add_child(box)
	var title = Label.new()
	title.text = "Elige tu clase"
	box.add_child(title)
	for c in [CharacterData.ClassType.NOBLE, CharacterData.ClassType.SALVAJE, CharacterData.ClassType.DHAMPIR, CharacterData.ClassType.HEMOMANTE]:
		var data = CharacterData.create_for_class(c)
		var b = Button.new()
		b.text = data.character_name
		b.pressed.connect(func():
			player.character_data = data
			layer.queue_free()
			busy = false
			player.process_mode = Node.PROCESS_MODE_INHERIT
			_save())
		box.add_child(b)
	add_child(layer)

func _save():
	SaveGame.save(player.character_data, player_inventory, floor_num, max_floor, quests)

func _unhandled_input(event):
	if busy:
		return
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_I: _open_inventory()
		KEY_E:
			if nearby.is_valid():
				nearby.call()
		KEY_H:
			if floor_num > 0:
				_go_floor(0)

func _open_inventory():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = InventoryMenu.new(player.character_data, player_inventory)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

func _make_area(tile: int, size: float, pos: Vector2, on_enter: Callable, hint: String = "") -> Area2D:
	var a = Area2D.new()
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/tile_%04d.png" % tile)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * size / 16.0
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2.ONE * size * 0.7
	a.add_child(spr)
	a.add_child(cs)
	a.position = pos
	a.add_to_group("floor_obj")
	if hint != "": # NPC: se activa con E mientras estés cerca
		a.body_entered.connect(func(_b):
			nearby = on_enter
			msg.text = hint)
		a.body_exited.connect(func(_b):
			if nearby == on_enter:
				nearby = Callable()
				msg.text = "")
	else:
		a.body_entered.connect(func(_b): if not busy: on_enter.call(a))
	add_child(a)
	return a

func _clear_floor():
	nearby = Callable()
	msg.text = ""
	for n in get_tree().get_nodes_in_group("floor_obj"):
		n.queue_free()

func _go_floor(n: int):
	Sfx.play(self, "door")
	_clear_floor()
	floor_num = n
	max_floor = maxi(max_floor, n)
	_spawn_floor()
	_save()

func _add_block(r: Rect2, tile: int):
	var b = StaticBody2D.new()
	b.position = r.position
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = r.size
	cs.position = r.size / 2
	var t = TextureRect.new()
	t.texture = load("res://assets/sprites/tile_%04d.png" % tile)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.size = r.size
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
		_add_block(r, 57)
	if floor_num == 0:
		return
	# ponytail: obstáculos aleatorios con separación mínima, así nunca bloquean el paso
	for i in 3:
		var seg = randi_range(5, 8) * 16
		var size = Vector2(seg, 16) if randf() < 0.5 else Vector2(16, seg)
		var r = Rect2(Vector2(randi_range(3, int(w / 16) - 4), randi_range(3, int(h / 16) - 4)) * 16, size)
		if _placeable(r):
			_add_block(r, 57)
	for i in 40:
		var r = Rect2(Vector2(randi_range(3, int(w / 16) - 4), randi_range(3, int(h / 16) - 4)) * 16, Vector2(16, 16))
		if _placeable(r):
			_add_block(r, [64, 65, 82].pick_random())

func _free_pos(area: Rect2, avoid: Vector2 = start_pos, min_dist: float = 100.0) -> Vector2:
	var p = area.get_center()
	for i in 60:
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(avoid) >= min_dist and not blocked.any(func(r): return r.grow(14).has_point(p)):
			break
	return p

func _spawn_floor():
	blocked.clear()
	var tower = floor_num > 0
	floor_size = Vector2(640, 360) if tower else Vector2(320, 180)
	start_pos = Vector2(48, 180) if tower else Vector2(160, 100)
	ground.size = floor_size
	$Background.size = floor_size
	cam.limit_right = int(floor_size.x)
	cam.limit_bottom = int(floor_size.y)
	player.position = start_pos
	_build_walls()
	if not tower:
		floor_label.text = "HUB - PISO MAX %d" % max_floor
		_make_area(112, 16, Vector2(80, 70), _open_shop, "E: Tienda")
		_make_area(99, 16, Vector2(240, 70), _rest, "E: Descansar (10 oro)")
		_make_area(86, 16, Vector2(160, 40), _talk, "E: Hablar con el Anciano")
		_make_area(45, 16, Vector2(160, 150), func(_a): _go_floor(max_floor))
		return
	floor_label.text = "PISO %d  (H: hub)" % floor_num
	var w = floor_size.x
	var h = floor_size.y
	for n in randi_range(4, 7):
		_make_area([108, 120, 121, 122].pick_random(), 14, _free_pos(Rect2(120, 32, w - 152, h - 64)), try_start_battle)
	_make_area(109, 24, _free_pos(Rect2(w * 0.72, 32, w * 0.28 - 32, h - 64)), try_start_battle).set_meta("boss", true)

func _open_shop():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = ShopMenu.new(player_inventory)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

func _open_dialog(text: String, actions: Array = []):
	Sfx.play(self, "dialog")
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var box = DialogBox.new(text, actions)
	box.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT)
	add_child(box)

func _talk():
	var q = quests.current()
	if q.is_empty():
		_open_dialog("Anciano: Has cumplido todos mis encargos, cazador. La torre es tuya.")
		return
	var item = ItemData.find_by_id(q.item)
	var text = "Anciano: %s\nProgreso: %d/%d (%s)\nRecompensa: %d oro + %s" % [
		q.title, mini(quests.counters[q.kind], q.goal), q.goal,
		"enemigos derrotados" if q.kind == "kill" else "jefes derrotados", q.gold, item.name]
	_open_dialog(text, [["Cobrar", _claim.bind(q)]] if quests.is_ready(q) else [])

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
		msg.text = "Descansas. HP/MP al maximo (-10 oro)"
		_save()
	else:
		msg.text = "No tienes oro suficiente"

func try_start_battle(enemy_node: Area2D):
	if busy:
		return
	current_enemy = enemy_node
	var difficulty = clampi(floor_num, 1, 5) # ponytail: dificultad máx 5 hasta tener más enemigos
	var enemies: Array[CharacterData] = []
	if enemy_node.has_meta("boss"):
		enemies.append(CharacterData.create_boss(floor_num))
	else:
		for i in range(CharacterData.get_enemy_count_for_difficulty(difficulty)):
			enemies.append(CharacterData.get_random_enemy(difficulty, floor_num))
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	battle_system.start_battle(player.character_data, enemies, player_inventory)

func _end_battle():
	busy = false
	player.process_mode = Node.PROCESS_MODE_INHERIT

func _on_battle_ended(victory: bool):
	_end_battle()
	if victory:
		quests.add("kill", battle_system.enemy_team.size())
		if current_enemy.has_meta("boss"):
			quests.add("boss")
			# cerca del jefe pero a >=32px del jugador (está pegado al jefe) para no activar las escaleras al instante
			var near = Rect2(current_enemy.position - Vector2(48, 48), Vector2(96, 96)).intersection(Rect2(32, 32, floor_size.x - 64, floor_size.y - 64))
			var pos = _free_pos(near, player.position, 32.0)
			_make_area(45, 16, pos, func(_a): _go_floor(floor_num + 1))
			msg.text = "¡Jefe derrotado! Baja por las escaleras"
		current_enemy.queue_free()
		_save()
	else:
		# ponytail: sin penalización, revive con HP/MP completos
		var c = player.character_data
		c.hp = c.max_hp
		c.mp = c.max_mp
		floor_num = 0 # ponytail: al morir vuelves al hub
		_save()
		get_tree().reload_current_scene()

func _on_battle_fled():
	_end_battle()
	# ponytail: empuja al jugador fuera del enemigo para no re-disparar
	player.move_and_collide((player.position - current_enemy.position).normalized() * 24)
	_save()
