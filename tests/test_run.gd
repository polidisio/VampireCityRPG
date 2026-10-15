extends SceneTree
# Uso: Godot --headless --path . --script tests/test_run.gd
# Builds por run: elegir mejora al subir de nivel, reliquias con efecto y la muerte como fin de run (oro y meta se conservan).
func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	# nivel: sin stats automáticos, mejora pendiente
	var p = CharacterData.create_for_class(1) # Salvaje: 2 habilidades de partida
	assert(p.skills.size() == 2, "habilidades de partida")
	var atk = p.attack
	p.add_exp(p.experience_to_next_level)
	assert(p.level == 2 and p.pending_picks == 1 and p.attack == atk, "subir de nivel da una mejora a elegir, no stats")
	var offers = Upgrades.level_offers(p)
	assert(offers.size() == 3, "3 ofertas")
	var skill_offer = Upgrades.level_offers(p, 99).filter(func(o): return o.id == "skill")
	assert(skill_offer.all(func(o): return o.skill.unlock_level <= p.level + 2), "no se ofrece una habilidad demasiado avanzada")
	Upgrades.apply(p, Upgrades.STATS[1]) # +4 ataque
	assert(p.attack == atk + 4 and p.hp == p.max_hp)
	for i in 5: # llenar habilidades: nunca más de MAX_SKILLS
		var s = Upgrades.level_offers(p, 99).filter(func(o): return o.id == "skill")
		if s.is_empty():
			break
		Upgrades.apply(p, s[0])
	assert(p.skills.size() <= Upgrades.MAX_SKILLS)
	assert(Upgrades.level_offers(p, 99).all(func(o): return o.id != "skill") or p.skills.size() < Upgrades.MAX_SKILLS, "con 4 habilidades no se ofrecen más")
	# reliquias: no se repiten y sus ganchos funcionan
	var bs: BattleSystem = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	await process_frame
	var c = CharacterData.create_for_class(2)
	c.hp = 100
	c.max_hp = 200
	var e = CharacterData.create_ghoul()
	var team: Array[CharacterData] = [e, CharacterData.create_bat()]
	bs.start_battle(c, team)
	var base = bs._power(c, 100)
	Upgrades.apply_relic(c, Upgrades.RELICS.filter(func(r): return r.id == "sed")[0])
	assert(bs._power(c, 100) == base, "Sed de Sangre: sin efecto con vida alta (50%)")
	c.hp = 50
	assert(bs._power(c, 100) == int(base * 1.5), "Sed de Sangre: +50% con poca vida")
	Upgrades.apply_relic(c, Upgrades.RELICS.filter(func(r): return r.id == "colmillo")[0])
	e.hp = 1
	var hp0 = c.hp
	bs.is_player_turn = true
	bs.player_attack(0)
	assert(e.hp <= 0 and c.hp == hp0 + 10, "Colmillo Voraz: cura al matar")
	assert(Upgrades.relic_offers(c, 99).all(func(r): return not c.has_relic(r.id)), "no se repiten reliquias")
	Upgrades.apply_relic(c, Upgrades.RELICS.filter(func(r): return r.id == "coraza")[0])
	assert(c.defense > CharacterData.create_for_class(2).defense and c.max_hp == 220, "Coraza: suma estadísticas")
	# guardado: build y reliquias sobreviven; sin run solo queda la meta
	var inv = Inventory.new()
	inv.gold = 77
	SaveGame.save(c, inv, 3, 4, null, 3)
	var l = SaveGame.load_game()
	assert(l[0].relics == c.relics and l[0].skills.size() == c.skills.size() and l[5] == 3, "guardado con build")
	SaveGame.save(null, inv, 0, 4, null, 0)
	l = SaveGame.load_game()
	assert(l[0] == null and l[1].gold == 77 and l[3] == 4, "guardado solo con meta")
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
	print("OK")
	quit()
