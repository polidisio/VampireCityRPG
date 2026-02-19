extends Node2D
class_name BattleSystem

signal battle_ended(victory: bool)
signal turn_changed(actor_name: String)

var player_team: Array[CharacterData] = []
var enemy_team: Array[CharacterData] = []
var turn_order: Array[Dictionary] = []
var current_turn_index: int = 0
var is_battle_active: bool = false
var is_player_turn: bool = true

var ui: Control

func _ready():
	ui = $BattleUI
	if ui:
		ui.visible = false
		print("UI encontrada correctamente")
	else:
		print("ERROR: UI no encontrada")

func start_battle(player: CharacterData, enemies: Array[CharacterData]):
	print("start_battle llamado")
	player_team = [player]
	enemy_team = enemies
	calculate_turn_order()
	is_battle_active = true
	is_player_turn = true
	
	if ui:
		ui.visible = true
		ui.setup_battle(player_team, enemy_team)
		# Refresh UI statistics after wiring up
		ui.update_stats()
		print("UI debería ser visible ahora")
	else:
		print("ERROR: UI es null")
	
	print("¡Combate iniciado!")
	print("Orden de turnos: ", turn_order)
	next_turn()

func calculate_turn_order():
	turn_order.clear()
	for c in player_team:
		turn_order.append({"character": c, "is_enemy": false})
	for e in enemy_team:
		turn_order.append({"character": e, "is_enemy": true})
	turn_order.sort_custom(func(a, b): return a.character.speed > b.character.speed)

func next_turn():
	if not is_battle_active:
		return
	
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	var current_actor = turn_order[current_turn_index]
	
	if current_actor.character.hp <= 0:
		next_turn()
		return
	
	is_player_turn = not current_actor.is_enemy
	turn_changed.emit(current_actor.character.character_name)
	
	if is_player_turn:
		ui.show_player_menu()
	else:
		await get_tree().create_timer(1.0).timeout
		enemy_turn()

func player_attack(target_index: int):
	if not is_player_turn or not is_battle_active:
		return
	
	var attacker = player_team[0]
	var target = enemy_team[target_index]
	
	var damage = attacker.attack
	var actual_damage = target.take_damage(damage)
	
	ui.add_log("%s ataca a %s por %d daños!" % [attacker.character_name, target.character_name, actual_damage])
	# Update UI stats after attack
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func player_use_skill(skill_index: int, target_index: int):
	if not is_player_turn or not is_battle_active:
		return
	
	var attacker = player_team[0]
	var skill = attacker.skills[skill_index]
	
	if not attacker.use_mp(skill.mp_cost):
		ui.add_log("¡No tienes suficiente MP!")
		return
	
	if skill.is_heal:
		attacker.heal(skill.heal)
		ui.add_log("%s usa %s y recupera %d HP!" % [attacker.character_name, skill.character_name, skill.heal])
	else:
		var target = enemy_team[target_index]
		target.take_damage(skill.damage)
		ui.add_log("%s usa %s en %s por %d daños!" % [attacker.character_name, skill.character_name, target.character_name, skill.damage])
	
	# Update UI stats after skill usage
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func enemy_turn():
	var enemy = enemy_team[0]
	var target = player_team[0]
	
	var damage = enemy.attack
	var actual_damage = target.take_damage(damage)
	
	ui.add_log("%s ataca a %s por %d daños!" % [enemy.character_name, target.character_name, actual_damage])
	# Update UI stats after enemy turn
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func check_battle_end():
	var all_dead = true
	for p in player_team:
		if p.hp > 0:
			all_dead = false
			break
	
	if all_dead:
		is_battle_active = false
		ui.add_log("¡Has perdido!")
		battle_ended.emit(false)
		return
	
	all_dead = true
	for e in enemy_team:
		if e.hp > 0:
			all_dead = false
			break
	
	if all_dead:
		is_battle_active = false
		var exp_gained = 0
		for e in enemy_team:
			exp_gained += 25
		player_team[0].add_exp(exp_gained)
		ui.add_log("¡Victoria! +%d EXP" % exp_gained)
		battle_ended.emit(true)

func _on_attack_pressed():
	if is_player_turn and is_battle_active:
		player_attack(0)

func _on_skill_pressed():
	if is_player_turn and is_battle_active:
		var player = player_team[0]
		if player.skills.size() > 0:
			player_use_skill(0, 0)

func _on_run_pressed():
	if is_player_turn and is_battle_active:
		ui.add_log("¡Escapaste del combate!")
		is_battle_active = false
		battle_ended.emit(false)
