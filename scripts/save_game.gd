class_name SaveGame

const PATH = "user://save.json"
const STATS = ["level", "experience", "experience_to_next_level", "hp", "max_hp", "mp", "max_mp", "attack", "defense", "speed"]

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func save(c: CharacterData, inv: Inventory, floor_num: int = 1, max_floor: int = 1) -> void:
	var d = {"class": c.class_type, "gold": inv.gold, "floor": floor_num, "max_floor": max_floor,
		"items": inv.items.map(func(i): return i.id), "equipment": {}}
	for s in STATS:
		d[s] = c.get(s)
	for slot in c.equipment:
		d.equipment[slot] = c.equipment[slot].id if c.equipment[slot] else ""
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))

# Returns [CharacterData, Inventory, floor, max_floor] or [] if missing/corrupt.
static func load_game() -> Array:
	if not exists():
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY or not d.has("class"):
		return []
	var c = CharacterData.create_for_class(int(d["class"]))
	for s in STATS:
		if d.has(s):
			c.set(s, int(d[s]))
	for slot in d.get("equipment", {}):
		c.equipment[slot] = ItemData.find_by_id(d.equipment[slot])
	var inv = Inventory.new()
	inv.gold = int(d.get("gold", 0))
	for id in d.get("items", []):
		var it = ItemData.find_by_id(id)
		if it:
			inv.items.append(it)
	var fl = maxi(0, int(d.get("floor", 1)))
	return [c, inv, fl, maxi(fl, int(d.get("max_floor", 1)))]
