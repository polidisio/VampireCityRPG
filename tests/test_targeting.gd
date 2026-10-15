extends SceneTree
# Uso: Godot --headless --path . --script tests/test_targeting.gd
# Con varios enemigos, Atacar abre la lista de objetivos y golpea al elegido; con uno solo no pregunta.
func _init():
	var bs: BattleSystem = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	await process_frame
	var p = CharacterData.create_for_class(2)
	p.hp = 999
	p.max_hp = 999
	var a = CharacterData.create_ghoul()
	var b = CharacterData.create_ghoul()
	var team: Array[CharacterData] = [a, b]
	bs.start_battle(p, team)
	bs.is_player_turn = true
	bs._on_attack_pressed()
	var list = bs.ui.skill_menu
	assert(bs.ui.skill_menu.get_parent().visible, "lista de objetivos visible")
	var buttons = list.get_children().filter(func(n): return n is Button and n.text != "Volver")
	assert(buttons.size() == 2, "un botón por enemigo vivo")
	assert(bs.ui.sprites[a].modulate.r > 1.0 and bs.ui.sprites[b].modulate.r == 1.0, "el enemigo enfocado se resalta")
	var hpa = a.hp
	var hpb = b.hp
	buttons[1].pressed.emit() # elige al segundo
	assert(a.hp == hpa and b.hp < hpb, "el golpe cae en el enemigo elegido")
	assert(bs.ui.sprites[b].modulate.r == 1.0, "el resaltado se quita al elegir")
	# con un solo enemigo vivo no se pregunta
	b.hp = 0
	bs.is_player_turn = true
	bs.is_battle_active = true
	bs._on_attack_pressed()
	assert(a.hp < hpa, "un solo enemigo: golpe directo")
	print("OK")
	quit()
