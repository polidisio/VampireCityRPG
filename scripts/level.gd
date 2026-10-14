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
	var ground = TextureRect.new()
	ground.texture = load("res://assets/sprites/tile_0000.png")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.size = Vector2(320, 180)
	add_child(ground)
	move_child(ground, 1) # sobre Background, bajo todo lo demás
	msg = Label.new()
	msg.position = Vector2(10, 134)
	add_child(msg)
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
	player.position = Vector2(160, 100)
	_spawn_floor()
	_save()

func _free_pos() -> Vector2:
	# ponytail: posición aleatoria lejos del jugador (160,100)
	var p = Vector2(160, 100)
	while p.distance_to(Vector2(160, 100)) < 50:
		p = Vector2(randf_range(20, 300), randf_range(30, 140))
	return p

func _spawn_floor():
	if floor_num == 0:
		$FloorLabel.text = "HUB - PISO MAX %d" % max_floor
		_make_area(112, 16, Vector2(80, 70), _open_shop, "E: Tienda")
		_make_area(99, 16, Vector2(240, 70), _rest, "E: Descansar (10 oro)")
		_make_area(86, 16, Vector2(160, 40), _talk, "E: Hablar con el Anciano")
		_make_area(45, 16, Vector2(160, 150), func(_a): _go_floor(max_floor))
		return
	$FloorLabel.text = "PISO %d  (H: hub)" % floor_num
	for n in randi_range(2, 4):
		_make_area([108, 120, 121, 122].pick_random(), 14, _free_pos(), try_start_battle)
	_make_area(109, 24, _free_pos(), try_start_battle).set_meta("boss", true)

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
			enemies.append(CharacterData.get_random_enemy(difficulty))
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
			# lejos del jugador (está pegado al jefe) para no activar las escaleras al instante
			var pos = (current_enemy.position + (current_enemy.position - player.position).normalized() * 40).clamp(Vector2(15, 25), Vector2(305, 145))
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
	player.position += (player.position - current_enemy.position).normalized() * 24
	_save()
