extends SceneTree
# Uso: Godot --headless --path . --script tests/test_content.gd
func _init():
	for d in range(1, 6):
		for i in 30:
			var e = CharacterData.get_random_enemy(d, d)
			assert(e.hp > 0 and e.sprite_tile > 0 and e.hp == e.max_hp, e.character_name)
	var names = {}
	for f in range(1, 11):
		var b = CharacterData.create_boss(f)
		assert(b.is_boss and b.hp == b.max_hp and not b.skills.is_empty(), "boss %d" % f)
		names[b.character_name] = true
	assert(names.size() == 5)
	assert(CharacterData.create_boss(10).max_hp > CharacterData.create_boss(5).max_hp * 1.4) # 5 -> mismo jefe, escalado
	for l in [ItemData.get_all_weapons(), ItemData.get_all_armors(), ItemData.get_all_accessories(), ItemData.get_all_consumables()]:
		for it in l:
			assert(ItemData.find_by_id(it.id) != null and it.value > 0, it.name)
	for q in QuestLog.QUESTS:
		assert(ItemData.find_by_id(q.item) != null, q.item)
		assert(QuestLog.KIND_TEXT.has(q.kind))
	# drops por piso: nada caro en el piso 1; el jefe siempre suelta equipo
	var bs = load("res://scenes/battle.tscn").instantiate()
	root.add_child(bs)
	await process_frame
	bs.floor_num = 1
	bs.enemy_team.assign([CharacterData.get_random_enemy(1, 1)])
	for i in 200:
		for it in bs.generate_drops():
			assert(it.value <= 80, "drop caro en piso 1: " + it.name)
	bs.enemy_team.assign([CharacterData.create_boss(1)])
	for i in 50:
		var gear = bs.generate_drops().filter(func(it): return it.type != ItemData.ItemType.CONSUMABLE)
		assert(not gear.is_empty() and gear[0].value <= 120)
	print("OK")
	quit()
