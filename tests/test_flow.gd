extends SceneTree
# Uso: Godot --headless --path . --script tests/test_flow.gd
# Cubre: acciones de entrada, título, pausa, subida de nivel, cierre del combate, suelos y números flotantes.
func fail(msg: String):
	print("FAIL: ", msg)
	quit(1)
	return false

func _init():
	var backup = FileAccess.get_file_as_string(SaveGame.PATH) if SaveGame.exists() else ""
	DirAccess.remove_absolute(SaveGame.PATH)
	var done = await run()
	if not done: # un error de script aborta run() antes de devolver true
		print("FAIL: run() no terminó")
		quit(1)
		return
	DirAccess.remove_absolute(SaveGame.PATH)
	if backup != "":
		var f = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("OK")
	quit()

func run():
	Controls.setup()
	for a in ["interact", "inventory", "hub", "pause"]:
		if not InputMap.has_action(a) or InputMap.action_get_events(a).size() != 2:
			return fail("acción " + a)
	if not InputMap.has_action("fullscreen") or InputMap.action_get_events("fullscreen").size() != 1:
		return fail("acción fullscreen")
	# título: sin guardado solo Nueva partida; con guardado, el primer pulso solo pide confirmación
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var texts = title.find_children("*", "Button", true, false).map(func(b): return b.text)
	if texts != ["Nueva partida", "Salir"]:
		return fail("título sin guardado: " + str(texts))
	title.queue_free()
	SaveGame.save(CharacterData.create_for_class(1), Inventory.new())
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var btns = title.find_children("*", "Button", true, false)
	if btns[0].text != "Continuar":
		return fail("falta Continuar")
	btns[1].pressed.emit()
	if not SaveGame.exists() or btns[1].text == "Nueva partida":
		return fail("nueva partida no pidió confirmación")
	title.queue_free()
	DirAccess.remove_absolute(SaveGame.PATH)

	var lvl = load("res://scenes/level.tscn").instantiate()
	root.add_child(lvl)
	for i in 4: await process_frame
	lvl.get_children().filter(func(n): return n is CanvasLayer and n != lvl.battle_system and n.layer == 5).map(func(n): n.queue_free())
	lvl.busy = false
	var p = CharacterData.create_for_class(1) # Salvaje: Desgarro al nivel 3
	p.level = 2
	p.sync_skills()
	p.experience = p.experience_to_next_level - 1
	lvl.player.character_data = p
	# pausa
	lvl._open_pause()
	if not lvl.busy:
		return fail("la pausa no bloquea")
	var pm = lvl.get_children().filter(func(n): return n is PauseMenu)[0]
	pm._resume()
	await process_frame
	if lvl.busy:
		return fail("la pausa no libera")
	# suelos por tramo
	var tex = {}
	for f in [0, 1, 6, 11, 16, 21, 26]:
		lvl._go_floor(f)
		tex[f] = [lvl.ground.texture.resource_path, lvl.ground.modulate]
	if tex[1] == tex[6] or tex[6] == tex[11] or tex[1] != tex[26] or tex[0] == tex[1]:
		return fail("suelos por tramo: " + str(tex))
	# combate: sube de nivel, avisa y se oculta
	lvl._go_floor(1)
	var e = CharacterData.create_bat()
	var en: Array[CharacterData] = [e]
	lvl.current_enemy = Area2D.new()
	lvl.add_child(lvl.current_enemy)
	lvl.current_enemy.set_meta("enemies", en)
	lvl.busy = true
	lvl.battle_system.start_battle(p, en, lvl.player_inventory)
	lvl.battle_system.ui.float_text(e, "-5", Color.RED)
	var labels = lvl.battle_system.ui.stage.get_children().filter(func(n): return n is Label and n.text == "-5")
	if labels.size() != 1:
		return fail("número flotante")
	e.hp = 0
	lvl.battle_system.check_battle_end()
	if lvl.battle_system.new_level != 3 or lvl.battle_system.new_skills.map(func(s): return s.name) != ["Desgarro"]:
		return fail("aviso de nivel: %d %s" % [lvl.battle_system.new_level, lvl.battle_system.new_skills])
	if not lvl.battle_system.ui.visible:
		return fail("la UI no debería ocultarse todavía (se lee el log)")
	await create_timer(1.6).timeout
	if lvl.battle_system.ui.visible:
		return fail("la UI de combate sigue visible")
	if not lvl.get_children().any(func(n): return n is DialogBox):
		return fail("falta el diálogo de nivel")
	return true
