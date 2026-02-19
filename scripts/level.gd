extends Node2D

@onready var player = $Player
@onready var battle_system = $BattleSystem

var in_combat: bool = false
var player_inventory: Inventory
var _enter_debug_logged: bool = false
var _process_logged: bool = false

func _ready():
	battle_system.battle_ended.connect(_on_battle_ended)
	player_inventory = Inventory.new()
	print("Inventario creado")

func _process(_delta):
	# Do not process input while in combat
	if in_combat:
		return
	
	# Start battle on Enter/Accept key
	if not _process_logged:
		print("LEVEL: _process running, input map ok? ui_accept exists?")
		_process_logged = true
	if Input.is_action_just_pressed("ui_accept"):
		if not _enter_debug_logged:
			print("DEBUG: Enter/ui_accept detected (start batlle path)")
			_enter_debug_logged = true
		print("Tecla presionada, iniciando combate...")
		try_start_battle()

func _unhandled_input(_event):
	# Fallback: catch Enter key even if Input Map is misconfigured
	if Input.is_key_pressed(KEY_ENTER):
		if not in_combat:
			print("DEBUG: Enter key detected via unhandled_input; starting battle")
			try_start_battle()

func try_start_battle():
	var difficulty = 1
	var enemy_count = CharacterData.get_enemy_count_for_difficulty(difficulty)
	var enemies: Array[CharacterData] = []
	
	for i in range(enemy_count):
		enemies.append(CharacterData.get_random_enemy(difficulty))
	
	print("Iniciando combate con %d enemigo(s)" % enemies.size())
	for e in enemies:
		print("  - %s (HP: %d, ATK: %d)" % [e.character_name, e.hp, e.attack])
	
	in_combat = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	battle_system.start_battle(player.character_data, enemies, player_inventory)

func _on_battle_ended(victory: bool):
	in_combat = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if victory:
		print("¡Batalla ganada!")
	else:
		print("¡Game Over!")
		get_tree().reload_current_scene()
