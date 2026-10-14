extends SceneTree
# Uso: Godot --headless --path . --script tests/test_floor_reachability.gd
# Genera muchos pisos y comprueba por flood-fill (celdas de 8px, margen del jugador) que inicio, enemigos y jefe son alcanzables.
func _init():
	# guardado temporal para saltarse la selección de clase; se restaura el guardado real al terminar
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	SaveGame.save(CharacterData.create_for_class(0), Inventory.new(), 1, 1)
	var lvl = load("res://scenes/level.tscn").instantiate()
	root.add_child(lvl)
	await process_frame
	var bad = 0
	var total_obs = 0
	for k in 60:
		lvl._go_floor(1 + k % 8)
		await process_frame
		var objs = lvl.get_tree().get_nodes_in_group("floor_obj").filter(func(n): return n is Area2D and not n.is_queued_for_deletion())
		var boss = objs.filter(func(n): return n.has_meta("boss"))
		assert(boss.size() == 1 and objs.size() >= 5 and objs.size() <= 8, "objs %d" % objs.size())
		total_obs += lvl.blocked.size()
		# flood fill
		var step = 8.0
		var w = int(lvl.floor_size.x / step)
		var h = int(lvl.floor_size.y / step)
		var free = func(c: Vector2i) -> bool:
			var pt = Vector2(c) * step + Vector2(step, step) / 2
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h: return false
			return not lvl.blocked.any(func(r): return r.grow(6).has_point(pt))
		var seen = {}
		var q = [Vector2i(lvl.start_pos / step)]
		seen[q[0]] = true
		while not q.is_empty():
			var c = q.pop_back()
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var n = c + d
				if not seen.has(n) and free.call(n):
					seen[n] = true
					q.append(n)
		for o in objs:
			if not seen.has(Vector2i(o.position / step)):
				bad += 1
	_restore(backup)
	print("pisos 60, inalcanzables: ", bad, " bloques medios: ", total_obs / 60.0)
	assert(bad == 0)
	print("OK")
	quit()

func _restore(backup: String):
	if backup == "":
		DirAccess.remove_absolute(SaveGame.PATH)
	else:
		FileAccess.open(SaveGame.PATH, FileAccess.WRITE).store_string(backup)
