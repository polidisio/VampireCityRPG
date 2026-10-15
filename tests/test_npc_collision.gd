extends SceneTree
# Uso: Godot --headless --path . --script tests/test_npc_collision.gd
# Un NPC es sólido (no se pisa) y su cartel "E:" solo aparece al acercarse.
func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	SaveGame.save(CharacterData.create_for_class(0), Inventory.new(), 0, 1)
	var lvl = load("res://scenes/level.tscn").instantiate()
	root.add_child(lvl)
	await process_frame
	var npcs = lvl.get_tree().get_nodes_in_group("floor_obj").filter(func(n): return n is Area2D and n.get_children().any(func(c): return c is Label))
	assert(npcs.size() == 4, "4 NPCs con cartel")
	for n in npcs:
		assert(not n.get_children().filter(func(c): return c is Label)[0].visible, "cartel oculto al inicio")
	assert(not lvl.nearby.is_valid())
	var elder = npcs.filter(func(n): return n.position == Vector2(160, 124))[0]
	lvl.player.position = Vector2(160, 154)
	for i in 80: # empuja al jugador contra el anciano
		lvl.player.move_and_collide(Vector2(0, -1))
		await process_frame
	assert(lvl.player.position.y >= elder.position.y + 12, "no se solapa: y=%f" % lvl.player.position.y)
	assert(lvl.nearby.is_valid(), "zona de interacción activa junto al NPC")
	assert(elder.get_children().filter(func(c): return c is Label)[0].visible)
	# el hub tiene paredes: el jugador no sale de la sala ni por los lados ni por abajo (salvo escaleras)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
		lvl.player.position = Vector2(110, 160)
		for i in 220:
			lvl.player.move_and_collide(d)
			await process_frame
		var p = lvl.player.position
		assert(Rect2(22, 104, 276, 82).grow(2).has_point(p), "dentro del hub: %s al ir %s" % [p, d])
	# la escalera del fondo lleva a la torre
	lvl.player.position = Vector2(160, 160)
	for i in 80:
		lvl.player.move_and_collide(Vector2(0, 1))
		await process_frame
	assert(lvl.floor_num == 1, "escaleras del hub llevan al piso max: floor=%d" % lvl.floor_num)
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
	print("OK")
	quit()
