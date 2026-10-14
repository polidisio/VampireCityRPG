class_name QuestLog

# ponytail: contadores acumulados (no empiezan al aceptar); las misiones van en orden.
const QUESTS = [
	{"id": "kill5", "title": "Plaga de cazadores", "kind": "kill", "goal": 5, "gold": 50, "item": "poción_pequeña"},
	{"id": "boss1", "title": "Cabeza de la torre", "kind": "boss", "goal": 1, "gold": 80, "item": "espada_corta"},
	{"id": "kill20", "title": "Noche de caza", "kind": "kill", "goal": 20, "gold": 150, "item": "poción_grande"},
	{"id": "boss3", "title": "Verdugo de jefes", "kind": "boss", "goal": 3, "gold": 300, "item": "armadura_de_placas"},
]

var counters: Dictionary = {"kill": 0, "boss": 0}
var claimed: Array = []

func add(kind: String, n: int = 1) -> void:
	counters[kind] += n

# Primera misión sin cobrar, o {} si no quedan.
func current() -> Dictionary:
	for q in QUESTS:
		if not claimed.has(q.id):
			return q
	return {}

func is_ready(q: Dictionary) -> bool:
	return counters[q.kind] >= q.goal

func to_dict() -> Dictionary:
	return {"counters": counters, "claimed": claimed}

static func from_dict(d: Dictionary) -> QuestLog:
	var ql = QuestLog.new()
	for k in ql.counters:
		ql.counters[k] = int(d.get("counters", {}).get(k, 0))
	ql.claimed = d.get("claimed", [])
	return ql
