class_name Pacts
# Pactos: modificadores voluntarios de un run. Más dificultad = más recompensa (Esencia y oro de combate).
# `bonus` se suma: recompensa = 1 + suma de los bonus de los pactos activos.
const PACTS = [
	{"id": "espesa", "name": "Sangre Espesa", "desc": "Enemigos con +25% de vida", "bonus": 0.4},
	{"id": "garras", "name": "Garras Afiladas", "desc": "Enemigos con +20% de ataque", "bonus": 0.15},
	{"id": "horda", "name": "Horda", "desc": "+1 enemigo por grupo (máx. 5)", "bonus": 0.8},
	{"id": "jefes", "name": "Jefes Furiosos", "desc": "Jefes con +30% de vida y ataque", "bonus": 0.2},
	{"id": "fragil", "name": "Fragilidad", "desc": "Empiezas con el 70% de la vida", "bonus": 0.15},
	{"id": "ayuno", "name": "Ayuno", "desc": "Sin objetos: ni usarlos ni llevarlos", "bonus": 0.15},
	{"id": "pobreza", "name": "Pobreza", "desc": "El oro de combate se reduce a la mitad", "bonus": 0.2},
]
const MAX_ASSIST = 0.2 # ayuda tras muertes seguidas: enemigos hasta -20%

static func reward_mult(ids: Array) -> float:
	var m = 1.0
	for p in PACTS:
		if ids.has(p.id):
			m += p.bonus
	return m

static func gold_mult(ids: Array) -> float:
	return reward_mult(ids) * (0.5 if ids.has("pobreza") else 1.0)

# Estadísticas de un enemigo recién creado según los pactos y la ayuda (0..MAX_ASSIST).
static func scale_enemy(e: CharacterData, ids: Array, boss: bool, assist: float) -> void:
	var hp_m = 1.0 - assist
	var atk_m = 1.0 - assist
	if ids.has("espesa"):
		hp_m *= 1.25
	if ids.has("garras"):
		atk_m *= 1.2
	if boss and ids.has("jefes"):
		hp_m *= 1.3
		atk_m *= 1.3
	e.max_hp = maxi(1, int(e.max_hp * hp_m))
	e.hp = e.max_hp
	e.attack = maxi(1, int(e.attack * atk_m))

static func enemy_count(base: int, ids: Array) -> int:
	return mini(5, base + (1 if ids.has("horda") else 0))

# Efectos que se fijan al empezar el run.
static func apply_start(c: CharacterData) -> void:
	if c.pacts.has("fragil"):
		c.hp = int(c.max_hp * 0.7)
