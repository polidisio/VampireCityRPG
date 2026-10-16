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
var gold_mult: float = 1.0 # Codicia (altar); lo fija el nivel
var theme := "battle" # pista de este combate (la fija el nivel por enemigo)
var new_level: int = 0 # nivel alcanzado en el último combate ganado (0 = no subió)
var enemy_delay: float = 1.0 # los tests de equilibrio lo ponen a 0

func _ready():
	layer = 10 # por encima del HUD del nivel
	ui = $BattleUI
	if ui:
		ui.visible = false
		ui.skill_selected.connect(_on_skill_selected)
		ui.item_selected.connect(_on_item_selected)
		ui.item_pressed.connect(_on_item_pressed)
	else:
		push_error("BattleSystem: UI no encontrada")

func start_battle(player: CharacterData, enemies: Array[CharacterData], inventory: Inventory = null):
	Music.play(self, theme)
	player_inventory = inventory
	player_team = [player]
	player.statuses.clear()
	if player.has_relic("furia"):
		player.add_status("furia", 2)
	new_level = 0
	enemy_team = enemies
	for e in enemy_team:
		plan_intent(e)
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
		actor.mp = mini(actor.max_mp, actor.mp + MP_REGEN + (3 if actor.has_relic("rosario") else 0))
	var stunned = actor.has_status("aturdido")
	var hp_before = actor.hp
	actor.tick_statuses()
	if actor.hp < hp_before:
		ui.float_text(actor, "-%d" % (hp_before - actor.hp), Color(0.9, 0.2, 0.25))
	ui.update_stats()
	check_battle_end()
	if not is_battle_active:
		return
	if actor.hp <= 0:
		next_turn()
		return
	if stunned:
		ui.float_text(actor, "¡Aturdido!", Color(1, 0.9, 0.35))
		if current_actor.is_enemy:
			plan_intent(actor)
		ui.update_stats()
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
	Sfx.play(self, "sword")
	ui.animate_attack(attacker, target)
	ui.float_text(target, "-%d" % actual_damage, Color(1, 0.45, 0.45))
	_on_player_hit(attacker, target)
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
	_on_player_hit(attacker, enemy_team[target_index])
	
	# Update UI stats after skill usage
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

func enemy_turn():
	var enemy = turn_order[current_turn_index].character
	var target = player_team[0]
	
	var skill = enemy.intent_skill # lo que se mostró en pantalla es lo que ocurre
	if skill and enemy.use_mp(skill.mp_cost):
		_use_skill(enemy, skill, target)
	else:
		var actual_damage = target.take_damage(_power(enemy, enemy.attack))
		Sfx.play(self, "grunt")
		ui.animate_attack(enemy, target)
		ui.float_text(target, "-%d" % actual_damage, Color(1, 0.45, 0.45))
	plan_intent(enemy)
	# Update UI stats after enemy turn
	if ui:
		ui.update_stats()
	
	check_battle_end()
	if is_battle_active:
		next_turn()

# Decide la próxima acción del enemigo (se muestra como intención hasta que le toque).
func plan_intent(e: CharacterData) -> void:
	var usable = e.skills.filter(func(sk): return sk.mp_cost <= e.mp)
	e.intent_skill = usable.pick_random() if not usable.is_empty() and randf() < (0.5 if e.is_boss else 0.4) else null

# Qué mostrar de la intención de `e`: {icons: [nombre...], value: daño previsto o 0}.
func intent_info(e: CharacterData) -> Dictionary:
	if e.has_status("aturdido"):
		return {"icons": ["stun"], "value": 0}
	var p = player_team[0]
	var sk = e.intent_skill
	if sk == null:
		return {"icons": ["sword"], "value": p.preview_damage(_power(e, e.attack))}
	return {"icons": Icons.skill_icons(sk), "value": sk.heal if sk.is_heal else (p.preview_damage(_power(e, sk.damage)) if sk.damage > 0 and not sk.on_self else 0)}

# Cuántos enemigos vivos atacarán con daño (si es 1, el total sería idéntico a su propia intención).
func incoming_count() -> int:
	return enemy_team.filter(func(e): return e.hp > 0 and not e.has_status("aturdido") and "sword" in intent_info(e).icons).size()

# Daño total previsto sobre el jugador si todos los enemigos vivos ejecutan su intención.
func incoming_damage() -> int:
	var total = 0
	for e in enemy_team:
		if e.hp > 0 and not e.has_status("aturdido"):
			var info = intent_info(e)
			if "sword" in info.icons:
				total += info.value
	return total

func _power(user: CharacterData, base: int) -> int:
	var m = 1.5 if user.has_status("furia") else 1.0
	if user.has_relic("sed") and user.hp * 100 < user.max_hp * 40:
		m *= 1.5
	return int(base * m)

# Reliquia Colmillo Voraz: cura al matar.
func _on_player_hit(attacker: CharacterData, target: CharacterData) -> void:
	if target.hp <= 0 and attacker.has_relic("colmillo"):
		attacker.heal(10)
		ui.float_text(attacker, "+10", Color(0.5, 1, 0.6))

func _use_skill(user: CharacterData, skill: SkillData, target: CharacterData):
	ui.float_text(user, skill.name, Color.WHITE)
	Sfx.play(self, "heal" if skill.is_heal or skill.on_self else "skill")
	if skill.is_heal or skill.on_self:
		ui.flash(user, Color(0.4, 1, 0.5))
	elif skill.damage > 0:
		ui.animate_attack(user, target)
	else:
		ui.flash(target, Color(0.7, 0.4, 1))
	if skill.is_heal:
		user.heal(skill.heal)
		ui.float_text(user, "+%d" % skill.heal, Color(0.5, 1, 0.6))
		return
	if skill.on_self:
		user.add_status(skill.status, skill.status_turns)
		return
	if skill.damage > 0:
		var dmg = target.take_damage(_power(user, skill.damage))
		ui.float_text(target, "-%d" % dmg, Color(1, 0.45, 0.45))
	if skill.status != "":
		target.add_status(skill.status, skill.status_turns + (2 if skill.status == "sangrado" and user.has_relic("calice") else 0))

func check_battle_end():
	if not is_battle_active:
		return # ya terminó: no emitir battle_ended dos veces
	var all_dead = true
	for p in player_team:
		if p.hp <= 0 and p.revive_ready: # mejora meta Retorno
			p.revive_ready = false
			p.hp = maxi(1, p.max_hp / 2)
			ui.float_text(p, "¡Revives!", Color(0.5, 1, 0.6))
			ui.add_log("¡Retorno! Vuelves a levantarte")
			ui.update_stats()
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
		var pc = player_team[0]
		var level_before = pc.level
		pc.add_exp(exp_gained)
		ui.add_log("¡Victoria! +%d EXP" % exp_gained)
		var leveled = pc.level > level_before
		if leveled:
			new_level = pc.level
			ui.add_log("¡Nivel %d!" % pc.level)
		Sfx.play(self, "levelup" if leveled else "victory")
		
		if player_inventory != null:
			var drops = generate_drops()
			for drop in drops:
				player_inventory.add_item(drop)
				ui.add_log("¡Obtuviste: %s!" % drop.name)
			var gold_drop = int(randi_range(5, 20) * (1.5 if pc.has_relic("bolsa") else 1.0) * gold_mult)
			player_inventory.add_gold(gold_drop)
			ui.add_log("¡Obtuviste: %d oro!" % gold_drop)
		
		battle_ended.emit(true)

func _on_attack_pressed():
	if is_player_turn and is_battle_active:
		ui.menu.visible = false
		_pick_target(player_attack, player_team[0].attack)

# Daño que haría el jugador con una acción de poder `base` sobre `target` (defensa y estados incluidos).
func damage_vs(target: CharacterData, base: int) -> int:
	return target.preview_damage(_power(player_team[0], base))

# El único enemigo vivo, o null si hay varios (entonces el daño se ve al elegir objetivo).
func single_target() -> CharacterData:
	var alive = enemy_team.filter(func(e): return e.hp > 0)
	return alive[0] if alive.size() == 1 else null

# Con varios enemigos vivos el jugador elige a quién golpear (viendo el daño sobre cada uno); con uno solo no pregunta.
func _pick_target(on_pick: Callable, base: int):
	var alive: Array[int] = []
	for i in enemy_team.size():
		if enemy_team[i].hp > 0:
			alive.append(i)
	if alive.size() <= 1:
		on_pick.call(first_alive_enemy())
		return
	ui.show_target_menu(alive.map(func(i): return enemy_team[i]), func(k): on_pick.call(alive[k]), base)

func _on_skill_pressed():
	if is_player_turn and is_battle_active:
		ui.show_skill_menu(player_team[0].skills)

func _on_item_pressed():
	if not (is_player_turn and is_battle_active):
		return
	if player_team[0].pacts.has("ayuno"):
		ui.add_log("Ayuno: no puedes usar objetos")
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
	if item.hp_restore > 0 or item.mp_restore > 0:
		Sfx.play(self, "potion")
	if item.hp_restore > 0:
		ui.float_text(player_team[0], "+%d" % item.hp_restore, Color(0.5, 1, 0.6))
	if item.mp_restore > 0:
		ui.float_text(player_team[0], "+%d" % item.mp_restore, Color(0.5, 0.7, 1))
	player_inventory.remove_item(item)
	ui.float_text(player_team[0], item.name, Color.WHITE)
	ui.update_stats()
	next_turn()

func _on_skill_selected(index: int):
	var skill = player_team[0].skills[index]
	if skill.is_heal or skill.on_self: # no apuntan a un enemigo
		player_use_skill(index, first_alive_enemy())
	else:
		_pick_target(func(t): player_use_skill(index, t), skill.damage)

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
