extends SceneTree
# Uso: Godot --headless --path . --script tests/test_intents.gd
# La intención que se muestra (icono + daño) es lo que el enemigo hace luego.
func _init():
	var bs: BattleSystem = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	await process_frame
	var p = CharacterData.create_for_class(2)
	p.hp = 999
	p.max_hp = 999
	var e = CharacterData.create_ghoul()
	var team: Array[CharacterData] = [e]
	bs.start_battle(p, team)
	bs.is_player_turn = false
	bs.current_turn_index = _idx(bs, e)
	# 1) ataque básico
	e.intent_skill = null
	var info = bs.intent_info(e)
	assert(info.icons == ["sword"] and info.value > 0, "ataque básico: espada con daño")
	assert(bs.incoming_damage() == info.value, "el total recibido suma la intención")
	var hp0 = p.hp
	bs.enemy_turn()
	assert(hp0 - p.hp == info.value, "daño real %d == previsto %d" % [hp0 - p.hp, info.value])
	# 2) habilidad con daño
	e.intent_skill = e.skills[0]
	e.mp = 99
	info = bs.intent_info(e)
	assert("sword" in info.icons and info.value > 0, "habilidad con daño: espada")
	bs.is_player_turn = false
	bs.current_turn_index = _idx(bs, e)
	hp0 = p.hp
	bs.enemy_turn()
	assert(hp0 - p.hp == info.value, "daño de habilidad %d == previsto %d" % [hp0 - p.hp, info.value])
	# 3) aturdido: se muestra y no suma daño
	e.add_status("aturdido", 2)
	assert(bs.intent_info(e).icons == ["stun"] and bs.incoming_damage() == 0, "aturdido: icono y sin daño")
	# 4) cada habilidad tiene icono
	for c in [CharacterData.create_for_class(0), CharacterData.create_for_class(3), CharacterData.create_boss(5)]:
		for sk in c.skills:
			assert(not Icons.skill_icons(sk).is_empty(), "icono para %s" % sk.name)
	print("OK")
	quit()

func _idx(bs: BattleSystem, c: CharacterData) -> int:
	for i in bs.turn_order.size():
		if bs.turn_order[i].character == c:
			return i
	return -1
