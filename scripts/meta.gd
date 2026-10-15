class_name Meta
# Metaprogresión: Esencia (se conserva al morir) y mejoras permanentes del altar del hub.
# Cada mejora cuesta `cost` * (nivel actual + 1). Se aplican al empezar un run (apply_to_run) o las leen otros sistemas.
const UPGRADES = [
	{"id": "vida", "name": "Vitalidad", "desc": "+10 de vida máxima al empezar", "max": 5, "cost": 10, "stats": {"max_hp": 10}},
	{"id": "fuerza", "name": "Fuerza", "desc": "+2 de ataque al empezar", "max": 5, "cost": 12, "stats": {"attack": 2}},
	{"id": "guardia", "name": "Guardia", "desc": "+1 de defensa al empezar", "max": 5, "cost": 12, "stats": {"defense": 1}},
	{"id": "celeridad", "name": "Celeridad", "desc": "+1 de velocidad al empezar", "max": 3, "cost": 15, "stats": {"speed": 1}},
	{"id": "mente", "name": "Mente", "desc": "+8 de maná máximo al empezar", "max": 3, "cost": 10, "stats": {"max_mp": 8}},
	{"id": "codicia", "name": "Codicia", "desc": "+10% de oro por combate", "max": 5, "cost": 10},
	{"id": "mochila", "name": "Mochila", "desc": "+1 consumible en la mochila", "max": 3, "cost": 20},
	{"id": "iniciado", "name": "Iniciado", "desc": "Empiezas con 1 mejora de nivel extra", "max": 2, "cost": 40},
	{"id": "herencia", "name": "Herencia", "desc": "Empiezas el run con una reliquia", "max": 1, "cost": 60},
	{"id": "retorno", "name": "Retorno", "desc": "Revives una vez por run con la mitad de vida", "max": 1, "cost": 80},
]

var essence: int = 0
var levels: Dictionary = {}
var streak: int = 0 # muertes seguidas sin superar un jefe ni un piso récord
var last_pacts: Array = [] # pactos del último run, preseleccionados en el siguiente

# Ayuda suave: tras la 2.ª muerte seguida los enemigos pierden un 5% por muerte (hasta Pacts.MAX_ASSIST).
func assist() -> float:
	return minf(0.05 * maxi(streak - 1, 0), Pacts.MAX_ASSIST)

func level(id: String) -> int:
	return int(levels.get(id, 0))

func cost(u: Dictionary) -> int:
	return u.cost * (level(u.id) + 1)

func can_buy(u: Dictionary) -> bool:
	return level(u.id) < u.max and essence >= cost(u)

func buy(u: Dictionary) -> bool:
	if not can_buy(u):
		return false
	essence -= cost(u)
	levels[u.id] = level(u.id) + 1
	return true

func gold_mult() -> float:
	return 1.0 + 0.1 * level("codicia")

func max_consumables() -> int:
	return Inventory.BASE_CONSUMABLES + level("mochila")

# Bonos de partida sobre un personaje recién creado.
func apply_to_run(c: CharacterData) -> void:
	for u in UPGRADES:
		if u.has("stats"):
			Upgrades.add_stats(c, u.stats, level(u.id))
	c.hp = c.max_hp
	c.mp = c.max_mp
	c.pending_picks += level("iniciado")
	if level("herencia") > 0:
		var r = Upgrades.relic_offers(c, 1)
		if not r.is_empty():
			Upgrades.apply_relic(c, r[0])
	c.revive_ready = level("retorno") > 0

func to_dict() -> Dictionary:
	return {"essence": essence, "levels": levels, "streak": streak, "last_pacts": last_pacts}

static func from_dict(d: Dictionary) -> Meta:
	var m = Meta.new()
	m.essence = int(d.get("essence", 0))
	m.streak = int(d.get("streak", 0))
	m.last_pacts = d.get("last_pacts", [])
	for k in d.get("levels", {}):
		m.levels[k] = int(d.levels[k])
	return m
