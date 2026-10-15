class_name SaveGame

const PATH = "user://save.json"
const STATS = ["level", "experience", "experience_to_next_level", "hp", "max_hp", "mp", "max_mp", "attack", "defense", "speed"]

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

# Meta (oro, piso máximo, misiones) siempre; el run (personaje, objetos, piso del run) solo si `c` no es null.
static func save(c: CharacterData, inv: Inventory, floor_num: int = 1, max_floor: int = 1, quests: QuestLog = null, run_floor: int = 1, meta: Meta = null) -> void:
	var d = {"gold": inv.gold, "floor": floor_num, "max_floor": max_floor, "run_floor": run_floor, "meta": (meta if meta else Meta.new()).to_dict(), "quests": (quests if quests else QuestLog.new()).to_dict()}
	if c:
		d.merge({"class": c.class_type, "items": inv.items.map(func(i): return i.id), "equipment": {},
			"skills": c.skills.map(func(s): return s.name), "relics": c.relics, "pending_picks": c.pending_picks, "revive": c.revive_ready, "pacts": c.pacts})
		for s in STATS:
			d[s] = c.get(s)
		for slot in c.equipment:
			d.equipment[slot] = c.equipment[slot].id if c.equipment[slot] else ""
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))

# Devuelve [CharacterData (null si no hay run), Inventory, floor, max_floor, QuestLog, run_floor, Meta] o [] si falta/está corrupto.
static func load_game() -> Array:
	if not exists():
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY or not d.has("gold"):
		return []
	var inv = Inventory.new()
	inv.gold = int(d.get("gold", 0))
	var quests = QuestLog.from_dict(d.get("quests", {}))
	var meta = Meta.from_dict(d.get("meta", {}))
	inv.max_consumables = meta.max_consumables()
	var fl = maxi(0, int(d.get("floor", 1)))
	var max_floor = maxi(fl, int(d.get("max_floor", 1)))
	if not d.has("class"):
		return [null, inv, 0, max_floor, quests, 0, meta]
	var c = CharacterData.create_for_class(int(d["class"]))
	for s in STATS:
		if d.has(s):
			c.set(s, int(d[s]))
	if d.has("skills"):
		c.skills = CharacterData.class_skills(c.class_type).filter(func(sk): return sk.name in d.skills)
	else: # guardado anterior a las builds: las habilidades que tocaban por nivel
		c.skills = CharacterData.class_skills(c.class_type).filter(func(sk): return sk.unlock_level <= c.level)
	c.relics = d.get("relics", [])
	c.pending_picks = int(d.get("pending_picks", 0))
	c.revive_ready = bool(d.get("revive", false))
	c.pacts = d.get("pacts", [])
	for slot in d.get("equipment", {}):
		c.equipment[slot] = ItemData.find_by_id(d.equipment[slot])
	for id in d.get("items", []):
		var it = ItemData.find_by_id(id)
		if it:
			inv.items.append(it)
	return [c, inv, fl, max_floor, quests, int(d.get("run_floor", max_floor)), meta]
