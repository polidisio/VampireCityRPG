extends CanvasLayer
class_name BattleSystem

signal battle_ended(victory: bool)
signal battle_fled
signal turn_changed(actor_name: String)

var player_team: Array[CharacterData] = []
var enemy_team: Array[CharacterData] = []
var turn_order: Array[Dictionary] = []
var current_turn_index: int = 0
var is_battle_active: bool = false
var is_player_turn: bool = true

var ui: Control
var player_inventory: Inventory
var floor_num: int = 1 # lo fija el nivel; condiciona los drops
const MP_REGEN = 3 # MP que recupera el jugador al inicio de cada uno de sus turnos
var enemy_delay: float = 1.0 # los tests de equilibrio lo ponen a 0

func _ready():
	ui = $BattleUI
	if ui:
		ui.visible = false
		ui.skill_selected.connect(_on_skill_selected)
		ui.item_selected.connect(_on_item_selected)
		ui.item_pressed.connect(_on_item_pressed)
	else:
		push_error("BattleSystem: UI no encontrada")

func start_battle(player: CharacterData, enemies: Array[CharacterData], inventory: Inventory = null):
	player_inventory = inventory
	player_team = [player]
	player.statuses.clear()
	enemy_team = enemies
	current_turn_index = -1
	calculate_turn_order()
	is_battle_active = true
	is_player_turn = true
	
	if ui:
		ui.visible = true
		ui.setup_battle(player_team, enemy_team)
		ui.update_stats()
	else:
		push_error("BattleSystem: UI es null")
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
	
	var actor: CharacterData = current_actor.character
	if not current_actor.is_enemy:
		actor.mp = mini(actor.max_mp, actor.mp + MP_REGEN)
	var stunned = actor.has_status("aturdido")
	for line in actor.tick_statuses():
		ui.add_log(line)
	ui.update_stats()
	check_battle_end()
	if not is_battle_active:
		return
	if actor.hp <= 0:
		next_turn()
		return
	if stunned:
		ui.add_log("%s está aturdido y pierde el turno" % actor.character_name)
		next_turn()
		return

	is_player_turn = not current_actor.is_enemy
	turn_changed.emit(current_actor.character.character_name)
	
	if is_player_turn:
		ui.show_player_menu()
	else:
		await get_tree().create_timer(enemy_delay).timeout
		enemy_turn()

func first_alive_enemy() -> int:
	for i in enemy_team.size():
		if enemy_team[i].hp > 0:
			return i
	return -1

func player_attack(target_index: int):
	if not is_player_turn or not is_battle_active:
		return
	
	var attacker = player_team[0]
	var target = enemy_team[target_index]
	
	var actual_damage = target.take_damage(_power(attacker, attacker.attack))
	Sfx.play(self, "hit")
	ui.animate_attack(attacker, target)
	
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
		ui.show_player_menu()
		return
	
	_use_skill(attacker, skill, enemy_team[target_index])
	
	# Update UI stats after skill usage
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func enemy_turn():
	var enemy = turn_order[current_turn_index].character
	var target = player_team[0]
	
	var usable = enemy.skills.filter(func(sk): return sk.mp_cost <= enemy.mp)
	if not usable.is_empty() and randf() < (0.5 if enemy.is_boss else 0.4):
		var skill = usable.pick_random()
		enemy.use_mp(skill.mp_cost)
		_use_skill(enemy, skill, target)
	else:
		var actual_damage = target.take_damage(_power(enemy, enemy.attack))
		Sfx.play(self, "hurt")
		ui.animate_attack(enemy, target)
		ui.add_log("%s ataca a %s por %d daños!" % [enemy.character_name, target.character_name, actual_damage])
	# Update UI stats after enemy turn
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func _power(user: CharacterData, base: int) -> int:
	return int(base * 1.5) if user.has_status("furia") else base

func _use_skill(user: CharacterData, skill: SkillData, target: CharacterData):
	Sfx.play(self, "heal" if skill.is_heal or skill.on_self else "skill")
	if skill.is_heal or skill.on_self:
		ui.flash(user, Color(0.4, 1, 0.5))
	elif skill.damage > 0:
		ui.animate_attack(user, target)
	else:
		ui.flash(target, Color(0.7, 0.4, 1))
	if skill.is_heal:
		user.heal(skill.heal)
		ui.add_log("%s usa %s y recupera %d HP!" % [user.character_name, skill.name, skill.heal])
		return
	if skill.on_self:
		user.add_status(skill.status, skill.status_turns)
		ui.add_log("%s usa %s (%s)" % [user.character_name, skill.name, skill.status])
		return
	if skill.damage > 0:
		var dmg = target.take_damage(_power(user, skill.damage))
		ui.add_log("%s usa %s en %s por %d daños!" % [user.character_name, skill.name, target.character_name, dmg])
	else:
		ui.add_log("%s usa %s en %s" % [user.character_name, skill.name, target.character_name])
	if skill.status != "":
		target.add_status(skill.status, skill.status_turns)
		ui.add_log("%s sufre %s" % [target.character_name, skill.status])

func check_battle_end():
	var all_dead = true
	for p in player_team:
		if p.hp > 0:
			all_dead = false
			break
	
	if all_dead:
		is_battle_active = false
		ui.add_log("¡Has perdido!")
		Sfx.play(self, "defeat")
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
			exp_gained += (10 + 15 * e.level) * (2 if e.is_boss else 1)
		player_team[0].add_exp(exp_gained)
		ui.add_log("¡Victoria! +%d EXP" % exp_gained)
		Sfx.play(self, "victory")
		
		if player_inventory != null:
			var drops = generate_drops()
			for drop in drops:
				player_inventory.add_item(drop)
				ui.add_log("¡Obtuviste: %s!" % drop.name)
			var gold_drop = randi_range(5, 20)
			player_inventory.add_gold(gold_drop)
			ui.add_log("¡Obtuviste: %d oro!" % gold_drop)
		
		battle_ended.emit(true)

func _on_attack_pressed():
	if is_player_turn and is_battle_active:
		ui.menu.visible = false
		player_attack(first_alive_enemy())

func _on_skill_pressed():
	if is_player_turn and is_battle_active:
		ui.show_skill_menu(player_team[0].skills)

func _on_item_pressed():
	if not (is_player_turn and is_battle_active):
		return
	var usable = player_inventory.get_consumables() if player_inventory else []
	if usable.is_empty():
		ui.add_log("¡No tienes objetos!")
		return
	ui.show_item_menu(usable)

func _on_item_selected(item: ItemData):
	if not (is_player_turn and is_battle_active):
		return
	player_team[0].use_item(item)
	player_inventory.remove_item(item)
	ui.add_log("%s usa %s" % [player_team[0].character_name, item.name])
	ui.update_stats()
	next_turn()

func _on_skill_selected(index: int):
	player_use_skill(index, first_alive_enemy())

func _on_run_pressed():
	if is_player_turn and is_battle_active:
		ui.add_log("¡Escapaste del combate!")
		is_battle_active = false
		battle_fled.emit()

# Solo cae lo que "toca" por piso: valor <= 40 + 40*piso (los jefes: +40 y siempre sueltan equipo).
func generate_drops() -> Array[ItemData]:
	var drops: Array[ItemData] = []
	var max_val = 40 + 40 * floor_num
	var consumables = ItemData.get_all_consumables().filter(func(i): return i.value <= max_val)
	var gear = (ItemData.get_all_weapons() + ItemData.get_all_armors() + ItemData.get_all_accessories())
	var roll = randf()
	if roll < 0.3 and not consumables.is_empty():
		drops.append(consumables.pick_random())
	elif roll < 0.7 and randf() < 0.3:
		var pool = gear.filter(func(i): return i.value <= max_val)
		if not pool.is_empty():
			drops.append(pool.pick_random())
	if randf() < 0.2 and not consumables.is_empty():
		drops.append(consumables.pick_random())
	if enemy_team[0].is_boss:
		var pool = gear.filter(func(i): return i.value <= max_val + 40)
		if not pool.is_empty():
			drops.append(pool.pick_random())
	return drops
