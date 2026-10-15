class_name Dialogues
# Diálogos ramificados. NPCS[npc][nodo] = lista de variantes; gana la primera cuyo `when` cumple.
# Variante: {when?, text, options?: [{label, go?: nodo, do?: acción}]}. Entrada: "start".
# `when` (todas las claves deben cumplirse): min_floor, min_level, claimed (id misión), hp_below_pct, no_gold.
# ponytail: sin flags persistentes; usa el estado existente. Si crece, mover a data/dialogues.json.
const NPCS = {
	"anciano": {
		"start": [
			{"when": {"min_floor": 10}, "text": "Anciano: Has llegado lejos, cazador. Pocos vuelven de allí arriba.",
				"options": [{"label": "Encargos", "do": "quest"}, {"label": "Rumores", "go": "rumores"}]},
			{"text": "Anciano: Ah, cazador. La torre no perdona a los impacientes.",
				"options": [{"label": "Encargos", "do": "quest"}, {"label": "Rumores", "go": "rumores"}]},
		],
		"rumores": [
			{"when": {"min_floor": 10}, "text": "Anciano: Dicen que cada jefe guarda una llave. Nadie sabe de qué puerta.",
				"options": [{"label": "Más", "go": "origen"}, {"label": "Volver", "go": "start"}]},
			{"text": "Anciano: Los vampiros de los pisos bajos son solo el principio. Sube con cuidado.",
				"options": [{"label": "¿Quién eres?", "go": "origen"}, {"label": "Volver", "go": "start"}]},
		],
		"origen": [
			{"text": "Anciano: Fui cazador, como tú. Ahora solo guardo la memoria de quienes cayeron.",
				"options": [{"label": "Volver", "go": "start"}]},
		],
	},
	"mercader": {
		"start": [
			{"when": {"min_floor": 10}, "text": "Mercader: Vienes con la ropa chamuscada, cazador. Buena señal: mira lo que tengo para ti.",
				"options": [{"label": "Comprar / vender", "do": "shop"}]},
			{"text": "Mercader: Pasa, pasa. Acero, pociones... y sin preguntas.",
				"options": [{"label": "Comprar / vender", "do": "shop"}]},
		],
	},
	"posadera": {
		"start": [
			{"when": {"no_gold": true}, "text": "Posadera: Sin monedas no hay cama, cazador. Vuelve con oro.",
				"options": [{"label": "Descansar (10 oro)", "do": "rest"}]},
			{"when": {"hp_below_pct": 50}, "text": "Posadera: Dios mío, estás hecho un asco. Siéntate.",
				"options": [{"label": "Descansar (10 oro)", "do": "rest"}]},
			{"text": "Posadera: Bienvenido. ¿Una cama para el cazador?",
				"options": [{"label": "Descansar (10 oro)", "do": "rest"}]},
		],
	},
}

static func matches(when: Dictionary, s: Dictionary) -> bool:
	for k in when:
		var ok = false
		match k:
			"min_floor": ok = s.max_floor >= when[k]
			"min_level": ok = s.level >= when[k]
			"claimed": ok = when[k] in s.claimed
			"hp_below_pct": ok = s.hp * 100 < s.max_hp * when[k]
			"no_gold": ok = (s.gold < 10) == when[k]
		if not ok:
			return false
	return true

# Devuelve la variante a mostrar, o {} si el nodo no existe / ninguna cumple.
static func pick(npc: String, node: String, s: Dictionary) -> Dictionary:
	for v in NPCS.get(npc, {}).get(node, []):
		if matches(v.get("when", {}), s):
			return v
	return {}
