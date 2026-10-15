extends SceneTree
# Uso: Godot --headless --path . --script tests/test_pacts.gd
# Pactos (más dificultad, más recompensa), ayuda tras muertes seguidas y su guardado.
func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	assert(Pacts.reward_mult([]) == 1.0, "sin pactos, recompensa base")
	assert(is_equal_approx(Pacts.reward_mult(["espesa", "horda"]), 1.0 + Pacts.PACTS[0].bonus + Pacts.PACTS[2].bonus), "los bonus se suman")
	assert(is_equal_approx(Pacts.gold_mult(["pobreza"]), (1.0 + Pacts.PACTS[6].bonus) * 0.5), "Pobreza: la mitad del oro con su recompensa")
	# enemigos
	var e = CharacterData.create_ghoul()
	var hp = e.max_hp
	var atk = e.attack
	Pacts.scale_enemy(e, ["espesa", "garras"], false, 0.0)
	assert(e.max_hp == int(hp * 1.25) and e.hp == e.max_hp and e.attack == int(atk * 1.2), "Sangre Espesa y Garras")
	var b = CharacterData.create_boss(1)
	var bhp = b.max_hp
	Pacts.scale_enemy(b, ["jefes"], true, 0.0)
	assert(b.max_hp == int(bhp * 1.3), "Jefes Furiosos")
	var n = CharacterData.create_ghoul()
	Pacts.scale_enemy(n, ["jefes"], false, 0.0)
	assert(n.max_hp == hp, "Jefes Furiosos no afecta a enemigos normales")
	var a = CharacterData.create_ghoul()
	Pacts.scale_enemy(a, [], false, 0.1)
	assert(a.max_hp == int(hp * 0.9), "la ayuda reduce a los enemigos")
	assert(Pacts.enemy_count(2, ["horda"]) == 3 and Pacts.enemy_count(5, ["horda"]) == 5 and Pacts.enemy_count(2, []) == 2, "Horda sube el grupo hasta 5")
	var c = CharacterData.create_for_class(0)
	c.pacts = ["fragil"]
	Pacts.apply_start(c)
	assert(c.hp == int(c.max_hp * 0.7), "Fragilidad")
	# ayuda tras muertes seguidas
	var m = Meta.new()
	assert(m.assist() == 0.0, "sin muertes, sin ayuda")
	m.streak = 1
	assert(m.assist() == 0.0, "una muerte no activa la ayuda")
	m.streak = 3
	assert(is_equal_approx(m.assist(), 0.1), "2 muertes de racha: -10%")
	m.streak = 99
	assert(is_equal_approx(m.assist(), Pacts.MAX_ASSIST), "la ayuda tiene techo")
	# Ayuno bloquea objetos
	var bs: BattleSystem = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	await process_frame
	var p = CharacterData.create_for_class(1)
	p.pacts = ["ayuno"]
	var inv = Inventory.new()
	inv.add_item(ItemData.find_by_id("poción_pequeña"))
	var team: Array[CharacterData] = [CharacterData.create_bat()]
	bs.start_battle(p, team, inv)
	bs.is_player_turn = true
	p.hp = 10
	bs._on_item_pressed()
	assert(not bs.ui.skill_menu.get_parent().visible and p.hp == 10, "Ayuno: no abre la lista de objetos")
	# guardado
	m.last_pacts = ["espesa"]
	p.pacts = ["horda", "ayuno"]
	SaveGame.save(p, inv, 1, 1, null, 1, m)
	var l = SaveGame.load_game()
	assert(l[0].pacts == ["horda", "ayuno"] and l[6].streak == 99 and l[6].last_pacts == ["espesa"], "pactos y racha se guardan")
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
	print("OK")
	quit()
