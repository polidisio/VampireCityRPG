extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var busy: bool = false
var player_inventory: Inventory

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
	SaveGame.save(player.character_data, player_inventory)

func _unhandled_input(event):
	if busy:
		return
	if event.is_action_pressed("ui_accept"):
		try_start_battle()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_I:
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

func try_start_battle():
	var difficulty = 1
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
	_save()
