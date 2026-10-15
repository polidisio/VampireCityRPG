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
	assert(buttons[1].text.ends_with("-%d" % bs.damage_vs(b, p.attack)), "el botón muestra el daño que harás: " + buttons[1].text)
	assert(bs.ui.incoming_row.get_child_count() > 0, "con 2 atacantes se ve el daño total sobre el jugador")
	var hpa = a.hp
	var hpb = b.hp
	var predicted = bs.damage_vs(b, p.attack)
	buttons[1].pressed.emit() # elige al segundo
	assert(a.hp == hpa and b.hp < hpb, "el golpe cae en el enemigo elegido")
	assert(hpb - b.hp == predicted, "el daño previsto es el real")
	assert(bs.ui.sprites[b].modulate.r == 1.0, "el resaltado se quita al elegir")
	# con un solo enemigo vivo no se pregunta
	b.hp = 0
	bs.is_player_turn = true
	bs.is_battle_active = true
	bs.ui.update_stats()
	await process_frame # las filas se vacían con queue_free
	assert(bs.ui.incoming_row.get_child_count() == 0, "con un atacante no se repite su daño sobre el jugador")
	bs.ui.show_player_menu()
	var pred1 = bs.damage_vs(a, p.attack)
	assert(bs.ui.menu.get_child(0).text == "Atacar -%d" % pred1, "Atacar muestra el daño con un solo enemigo: " + bs.ui.menu.get_child(0).text)
	bs._on_attack_pressed()
	assert(hpa - a.hp == pred1, "un solo enemigo: golpe directo con el daño previsto")
	print("OK")
	quit()
