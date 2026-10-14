extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var busy: bool = false
var player_inventory: Inventory
var floor_num: int = 1
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
	_spawn_enemies()

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
	SaveGame.save(player.character_data, player_inventory, floor_num)

func _unhandled_input(event):
	if busy:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_open_inventory()

func _open_inventory():
	busy = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = InventoryMenu.new(player.character_data, player_inventory)
	menu.closed.connect(func():
		busy = false
		player.process_mode = Node.PROCESS_MODE_INHERIT
		_save())
	add_child(menu)

func _spawn_enemies():
	$FloorLabel.text = "PISO %d" % floor_num
	for n in randi_range(2, 4):
		var a = Area2D.new()
		var r = ColorRect.new()
		r.size = Vector2(10, 10)
		r.position = Vector2(-5, -5)
		r.color = Color(0.5, 0.1, 0.6)
		var cs = CollisionShape2D.new()
		cs.shape = RectangleShape2D.new()
		cs.shape.size = Vector2(10, 10)
		a.add_child(r)
		a.add_child(cs)
		# ponytail: posición aleatoria, lejos del jugador (160,100)
		while true:
			a.position = Vector2(randf_range(20, 300), randf_range(30, 140))
			if a.position.distance_to(Vector2(160, 100)) > 50:
				break
		a.body_entered.connect(func(_b): try_start_battle(a))
		add_child(a)

func try_start_battle(enemy_node: Area2D):
	if busy:
		return
	current_enemy = enemy_node
	var difficulty = clampi(floor_num, 1, 5) # ponytail: dificultad máx 5 hasta tener más enemigos
	var enemy_count = CharacterData.get_enemy_count_for_difficulty(difficulty)
	var enemies: Array[CharacterData] = []
	for i in range(enemy_count):
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
		current_enemy.queue_free()
		_save()
	else:
		# ponytail: sin penalización, revive con HP/MP completos
		var c = player.character_data
		c.hp = c.max_hp
		c.mp = c.max_mp
		_save()
		get_tree().reload_current_scene()

func _on_battle_fled():
	_end_battle()
	# ponytail: empuja al jugador fuera del enemigo para no re-disparar
	player.position += (player.position - current_enemy.position).normalized() * 24
	_save()
