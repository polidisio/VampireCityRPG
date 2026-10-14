extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var busy: bool = false
var player_inventory: Inventory
var floor_num: int = 0 # 0 = hub
var max_floor: int = 1
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
	SaveGame.save(player.character_data, player_inventory, floor_num, max_floor)

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

func _make_area(color: Color, size: Vector2, pos: Vector2, on_enter: Callable, hint: String = "") -> Area2D:
	var a = Area2D.new()
	var r = ColorRect.new()
	r.size = size
	r.position = -size / 2
	r.color = color
	var cs = CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	a.add_child(r)
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
		_make_area(Color(0.2, 0.4, 0.9), Vector2(12, 12), Vector2(80, 70), _open_shop, "E: Tienda")
		_make_area(Color(0.2, 0.8, 0.3), Vector2(12, 12), Vector2(240, 70), _rest, "E: Descansar (10 oro)")
		_make_area(Color(0.9, 0.8, 0.2), Vector2(14, 14), Vector2(160, 150), func(_a): _go_floor(max_floor))
		return
	$FloorLabel.text = "PISO %d  (H: hub)" % floor_num
	for n in randi_range(2, 4):
		_make_area(Color(0.5, 0.1, 0.6), Vector2(10, 10), _free_pos(), try_start_battle)
	_make_area(Color(0.9, 0.4, 0.1), Vector2(18, 18), _free_pos(), try_start_battle).set_meta("boss", true)

func _open_shop():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = ShopMenu.new(player_inventory)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

func _rest():
	var c = player.character_data
	if player_inventory.spend_gold(10):
		c.hp = c.max_hp
		c.mp = c.max_mp
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
		if current_enemy.has_meta("boss"):
			# lejos del jugador (está pegado al jefe) para no activar las escaleras al instante
			var pos = (current_enemy.position + (current_enemy.position - player.position).normalized() * 40).clamp(Vector2(15, 25), Vector2(305, 145))
			_make_area(Color(0.9, 0.8, 0.2), Vector2(14, 14), pos, func(_a): _go_floor(floor_num + 1))
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
