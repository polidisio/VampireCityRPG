extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var in_combat: bool = false
var player_inventory: Inventory

func _ready():
	battle_system.battle_ended.connect(_on_battle_ended)
	battle_system.battle_fled.connect(_on_battle_fled)
	player_inventory = Inventory.new()

func _unhandled_input(event):
	if not in_combat and event.is_action_pressed("ui_accept"):
		try_start_battle()

func try_start_battle():
	var difficulty = 1
	var enemy_count = CharacterData.get_enemy_count_for_difficulty(difficulty)
	var enemies: Array[CharacterData] = []
	
	for i in range(enemy_count):
		enemies.append(CharacterData.get_random_enemy(difficulty))
	
	in_combat = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	battle_system.start_battle(player.character_data, enemies, player_inventory)

func _on_battle_ended(victory: bool):
	in_combat = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if not victory:
		get_tree().reload_current_scene()

func _on_battle_fled():
	in_combat = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
