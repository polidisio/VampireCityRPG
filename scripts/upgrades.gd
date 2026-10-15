class_name Upgrades
# Mejoras de la build del run: 1 de 3 al subir de nivel y 1 de 3 reliquias tras cada jefe.
const MAX_SKILLS = 4
const STATS = [
	{"id": "hp", "name": "+20 Vida", "desc": "Vida máxima +20", "stats": {"max_hp": 20}},
	{"id": "atk", "name": "+4 Ataque", "desc": "Ataque +4", "stats": {"attack": 4}},
	{"id": "def", "name": "+3 Defensa", "desc": "Defensa +3", "stats": {"defense": 3}},
	{"id": "spd", "name": "+3 Velocidad", "desc": "Velocidad +3: actúas antes", "stats": {"speed": 3}},
	{"id": "mp", "name": "+12 Maná", "desc": "Maná máximo +12", "stats": {"max_mp": 12}},
]
# Las de "stats" se aplican al elegirlas; el resto las leen los ganchos de battle_system.
const RELICS = [
	{"id": "colmillo", "name": "Colmillo Voraz", "desc": "Curas 10 HP al matar un enemigo"},
	{"id": "sed", "name": "Sed de Sangre", "desc": "+50% de daño con menos del 40% de vida"},
	{"id": "calice", "name": "Cáliz Venenoso", "desc": "El sangrado dura 2 turnos más"},
	{"id": "rosario", "name": "Rosario de Ajo", "desc": "Recuperas 3 MP más por turno"},
	{"id": "bolsa", "name": "Bolsa sin Fondo", "desc": "+50% de oro por combate"},
	{"id": "furia", "name": "Anillo de Furia", "desc": "Empiezas cada combate con Furia (2 turnos)"},
	{"id": "coraza", "name": "Coraza de Hueso", "desc": "Defensa +5 y vida máxima +20", "stats": {"defense": 5, "max_hp": 20}},
	{"id": "reloj", "name": "Reloj de Ceniza", "desc": "Velocidad +5 y ataque +3", "stats": {"speed": 5, "attack": 3}},
]

# 3 mejoras al azar: estadísticas y habilidades de la clase aún no aprendidas (hasta MAX_SKILLS).
static func level_offers(c: CharacterData, n := 3) -> Array:
	var pool: Array = STATS.duplicate()
	if c.skills.size() < MAX_SKILLS:
		var known = c.skills.map(func(s): return s.name)
		for sk in CharacterData.class_skills(c.class_type):
			if not known.has(sk.name) and sk.unlock_level <= c.level + 2:
				pool.append({"id": "skill", "name": sk.name, "desc": "%s (%d MP)" % [sk.description, sk.mp_cost], "skill": sk})
	pool.shuffle()
	return pool.slice(0, n)

static func relic_offers(c: CharacterData, n := 3) -> Array:
	var pool = RELICS.filter(func(r): return not c.has_relic(r.id))
	pool.shuffle()
	return pool.slice(0, n)

# Aplica una mejora de nivel y repone HP/MP, como hacía subir de nivel.
static func apply(c: CharacterData, o: Dictionary) -> void:
	if o.id == "skill":
		c.skills.append(o.skill)
	else:
		add_stats(c, o.stats)
	c.hp = c.max_hp
	c.mp = c.max_mp

static func apply_relic(c: CharacterData, r: Dictionary) -> void:
	c.relics.append(r.id)
	add_stats(c, r.get("stats", {}))

static func add_stats(c: CharacterData, stats: Dictionary, times := 1) -> void:
	for k in stats:
		c.set(k, c.get(k) + stats[k] * times)
		if k == "max_hp":
			c.hp += stats[k] * times
		elif k == "max_mp":
			c.mp += stats[k] * times
