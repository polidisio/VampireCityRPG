extends SceneTree
# Uso: Godot --headless --path . --script tests/test_dialogues.gd
func _init():
	var s = {"max_floor": 1, "level": 1, "claimed": [], "hp": 10, "max_hp": 10, "gold": 50}
	assert(Dialogues.pick("anciano", "start", s).text.contains("impacientes"), "variante por defecto")
	s.max_floor = 12
	assert(Dialogues.pick("anciano", "start", s).text.contains("lejos"), "variante por piso")
	assert(Dialogues.pick("posadera", "start", s).text.contains("Bienvenido"))
	s.hp = 3
	assert(Dialogues.pick("posadera", "start", s).text.contains("asco"), "hp bajo")
	s.gold = 5
	assert(Dialogues.pick("posadera", "start", s).text.contains("Sin monedas"), "sin oro gana")
	assert(Dialogues.pick("nadie", "start", s).is_empty(), "npc desconocido")
	# toda rama apunta a un nodo existente
	for npc in Dialogues.NPCS:
		for node in Dialogues.NPCS[npc]:
			for v in Dialogues.NPCS[npc][node]:
				for o in v.get("options", []):
					assert(o.has("do") or Dialogues.NPCS[npc].has(o.go), "rama rota %s/%s" % [npc, o.get("go")])
	print("OK")
	quit()
