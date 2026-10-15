extends SceneTree
# Uso: Godot --headless --path . --script tests/test_floor_features.gd
# Piso: sello con puerta, élite con llave, eventos y presencia del jefe.
func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	SaveGame.save(CharacterData.create_for_class(1), Inventory.new(), 1, 1)
	var lvl = load("res://scenes/level.tscn").instantiate()
	root.add_child(lvl)
	await process_frame
	var ok = await run(lvl)
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
	assert(ok)
	print("OK")
	quit()

func objs(lvl) -> Array:
	return lvl.get_tree().get_nodes_in_group("floor_obj").filter(func(n): return n is Area2D and not n.is_queued_for_deletion())

func run(lvl) -> bool:
	lvl._go_floor(1)
	await process_frame
	var all = objs(lvl)
	var elite = all.filter(func(n): return n.has_meta("elite"))
	var boss = all.filter(func(n): return n.has_meta("boss"))
	assert(elite.size() == 1 and boss.size() == 1, "un élite y un jefe")
	assert(is_instance_valid(lvl.door) and not lvl.has_key, "el sello empieza cerrado")
	var door_x = lvl.door.position.x
	assert(all.filter(func(n): return not n.has_meta("boss")).all(func(n): return n.position.x < door_x), "todo salvo el jefe está antes de la puerta")
	assert(boss[0].position.x > door_x, "el jefe está tras la puerta")
	assert(all.filter(func(n): return n.has_meta("solid")).size() >= 3, "al menos ataúdes y pozo")
	assert(lvl.floor_label.text.contains("Sello: busca"), "el HUD avisa del sello")
	# el jefe se distingue: nombre y tamaño
	var names = boss[0].get_children().filter(func(n): return n is Label)
	assert(names.size() == 1 and names[0].text == boss[0].get_meta("enemies")[0].character_name.to_upper(), "nombre sobre el jefe")
	assert(boss[0].get_child(0).scale.x > 1.4, "el jefe es más grande")
	assert(elite[0].get_meta("enemies")[0].character_name.begins_with("Élite "), "el élite se llama Élite")
	# llave: romper el sello
	var ess = lvl.meta.essence
	lvl._break_seal()
	await process_frame
	assert(lvl.has_key and not is_instance_valid(lvl.door) and lvl.meta.essence == ess + lvl.ELITE_ESSENCE, "la llave rompe el sello y da Esencia")
	assert(lvl.floor_label.text.contains("Sello roto"))
	# ataúd: botín
	var c = lvl.player.character_data
	var coffin = Area2D.new()
	lvl.add_child(coffin)
	var gold = lvl.player_inventory.gold
	lvl._open_coffin(coffin, 0.9)
	assert(lvl.player_inventory.gold > gold and coffin.is_queued_for_deletion(), "ataúd da oro y desaparece")
	# ataúd: emboscada
	var trap = Area2D.new()
	lvl.add_child(trap)
	lvl._open_coffin(trap, 0.1)
	assert(trap.has_meta("enemies") and lvl.battle_system.is_battle_active, "emboscada empieza un combate")
	lvl.battle_system.is_battle_active = false
	lvl.battle_system.ui.visible = false
	lvl.busy = false
	lvl.player.process_mode = Node.PROCESS_MODE_INHERIT
	# pozo de sangre
	var well = Area2D.new()
	lvl.add_child(well)
	c.hp = c.max_hp
	lvl._drink_well(well)
	assert(not well.is_queued_for_deletion(), "con vida llena no se gasta")
	c.hp = 1
	lvl._drink_well(well)
	assert(c.hp == 1 + c.max_hp / 2 and well.is_queued_for_deletion(), "el pozo cura la mitad y se agota")
	# sarcófago: cuesta vida y ofrece reliquias
	var sar = Area2D.new()
	lvl.add_child(sar)
	c.hp = c.max_hp
	var hp0 = c.hp
	lvl._open_sarcophagus.call(sar) # corrutina: espera la elección
	assert(c.hp == hp0 - hp0 / 4 and lvl.get_children().any(func(n): return n is DialogBox), "el pacto cuesta un 25% y abre la elección")
	# tarjeta del jefe
	var done = [false]
	(func():
		await lvl._boss_intro(boss[0].get_meta("enemies")[0])
		done[0] = true).call()
	await process_frame
	assert(lvl.get_children().any(func(n): return n is CanvasLayer and n.layer == 8), "tarjeta de entrada visible")
	while not done[0]:
		await process_frame
	await process_frame
	assert(not lvl.get_children().any(func(n): return n is CanvasLayer and n.layer == 8), "la tarjeta se retira sola")
	return true
