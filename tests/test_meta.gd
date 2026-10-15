extends SceneTree
# Uso: Godot --headless --path . --script tests/test_meta.gd
# Altar: Esencia, costes, bonos de partida, Retorno (revivir) y guardado de la meta.
func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	var m = Meta.new()
	var vida = Meta.UPGRADES.filter(func(u): return u.id == "vida")[0]
	assert(not m.buy(vida), "sin Esencia no compra")
	m.essence = 100
	assert(m.buy(vida) and m.essence == 100 - vida.cost and m.level("vida") == 1, "compra nivel 1")
	assert(m.cost(vida) == 2 * vida.cost and m.buy(vida) and m.essence == 100 - 3 * vida.cost, "el coste sube con el nivel")
	m.essence = 1000
	for i in 10:
		m.buy(vida)
	assert(m.level("vida") == vida.max, "no pasa del máximo")
	m.essence = 5000
	for u in Meta.UPGRADES:
		while m.buy(u):
			pass
		assert(m.level(u.id) == u.max, "máximo de " + u.id)
	var c = CharacterData.create_for_class(1)
	var base = CharacterData.create_for_class(1)
	m.levels.erase("herencia") # la reliquia es aleatoria y puede sumar estadísticas: se prueba aparte
	m.apply_to_run(c)
	assert(c.max_hp == base.max_hp + 50 and c.attack == base.attack + 10 and c.defense == base.defense + 5, "bonos de estadísticas")
	assert(c.hp == c.max_hp and c.pending_picks == 2 and c.relics.is_empty() and c.revive_ready, "iniciado y retorno")
	m.levels["herencia"] = 1
	var c2 = CharacterData.create_for_class(0)
	m.apply_to_run(c2)
	assert(c2.relics.size() == 1, "herencia da una reliquia")
	assert(is_equal_approx(m.gold_mult(), 1.5) and m.max_consumables() == Inventory.BASE_CONSUMABLES + 3, "oro y mochila")
	# Retorno: revive una vez con la mitad de vida y la batalla sigue
	var bs: BattleSystem = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	await process_frame
	var team: Array[CharacterData] = [CharacterData.create_ghoul()]
	bs.start_battle(c, team)
	var lost_flag = [false]
	bs.battle_ended.connect(func(v): lost_flag[0] = not v)
	c.hp = 0
	bs.check_battle_end()
	assert(c.hp == c.max_hp / 2 and not c.revive_ready and bs.is_battle_active and not lost_flag[0], "Retorno revive y sigue el combate")
	c.hp = 0
	bs.check_battle_end()
	assert(lost_flag[0] and not bs.is_battle_active, "la segunda muerte sí termina el run")
	# guardado: Esencia y mejoras sobreviven a la muerte (guardado sin run)
	var inv = Inventory.new()
	SaveGame.save(null, inv, 0, 3, null, 0, m)
	var l = SaveGame.load_game()
	assert(l[6].essence == m.essence and l[6].level("vida") == vida.max and l[1].max_consumables == m.max_consumables(), "meta guardada")
	c.revive_ready = true
	SaveGame.save(c, inv, 1, 3, null, 1, m)
	assert(SaveGame.load_game()[0].revive_ready, "Retorno pendiente se guarda")
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
	print("OK")
	quit()
