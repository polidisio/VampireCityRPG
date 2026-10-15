extends SceneTree
# Simula campañas de runs con el BattleSystem real y un jugador "razonable": pisos con 4-7 grupos, élite,
# emboscadas, pozo, sarcófago y jefe; mejoras de nivel y reliquias; Esencia que se gasta en el altar entre runs.
# Uso: Godot --headless --path . --script tests/sim_balance.gd
# Variables de entorno: CLASS=0..3 (solo esa clase), REPS (campañas por clase, 6), RUNS (runs por campaña, 8),
# PACTS=espesa,garras (pactos activos en todos los runs), META=0 (sin altar: cada run empieza de cero).
# Supuestos: posada (HP/MP completos) al empezar cada piso; no compra en tienda; equipa lo que dropea.
const MAX_FLOOR = 15
const ALTAR_ORDER = ["vida", "fuerza", "guardia", "iniciado", "mente", "celeridad", "retorno", "herencia", "codicia", "mochila"]

var bs: BattleSystem
var inv: Inventory
var won := false
var done := false
var cur_floor := 1
var meta: Meta
var max_floor := 1
var pacts: Array = []
var essence_run := 0

func _init():
	randomize()
	var reps = int(OS.get_environment("REPS")) if OS.get_environment("REPS") != "" else 6
	var runs = int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 8
	if OS.get_environment("PACTS") != "":
		pacts = Array(OS.get_environment("PACTS").split(","))
	bs = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	bs.turn_changed.connect(func(_n): if bs.is_player_turn: _act.call_deferred())
	bs.battle_ended.connect(func(v):
		won = v
		done = true)
	await process_frame
	var classes = [int(OS.get_environment("CLASS"))] if OS.get_environment("CLASS") != "" else [0, 1, 2, 3]
	for cls in classes:
		var floors = []
		var levels = []
		var gains = []
		for r in runs:
			floors.append(0.0)
			levels.append(0.0)
			gains.append(0.0)
		var deaths := {}
		for rep in reps:
			meta = Meta.new()
			max_floor = 1
			for r in runs:
				var res = await _run(cls)
				floors[r] += res[0]
				levels[r] += res[1]
				gains[r] += res[2]
				if r == 0:
					deaths[res[0]] = deaths.get(res[0], 0) + 1
				_spend_essence()
		var keys = deaths.keys()
		keys.sort()
		print("%-10s piso medio por run: %s" % [CharacterData.create_for_class(cls).character_name, " ".join(floors.map(func(f): return "%.1f" % (f / reps)))])
		print("%-10s Esencia ganada por run: %s" % ["", " ".join(gains.map(func(g): return "%d" % (g / reps)))])
		print("%-10s nivel medio por run: %s   |  1.er run, muertes por piso: %s" % ["", " ".join(levels.map(func(l): return "%.1f" % (l / reps))), ", ".join(keys.map(func(k): return "%d:%d" % [k, deaths[k]]))])
	quit()

# Altar: compra lo más barato que se pueda pagar, hasta gastarlo todo.
func _spend_essence() -> void:
	if OS.get_environment("META") == "0":
		meta.essence = 0
		return
	while true:
		var opts = Meta.UPGRADES.filter(func(u): return meta.can_buy(u))
		if opts.is_empty():
			return
		opts.sort_custom(func(a, b): return meta.cost(a) < meta.cost(b))
		meta.buy(opts[0])

func _act():
	var p: CharacterData = bs.player_team[0]
	var t = bs.first_alive_enemy()
	if t < 0:
		return
	if p.hp < p.max_hp * 0.4:
		for i in p.skills.size():
			if p.skills[i].is_heal and p.mp >= p.skills[i].mp_cost:
				bs.player_use_skill(i, t)
				return
		var pots = inv.get_consumables().filter(func(it): return it.hp_restore > 0)
		if not pots.is_empty() and not pacts.has("ayuno"):
			bs._on_item_selected(pots[0])
			return
	var best := -1
	var best_dmg: int = p.attack
	for i in p.skills.size():
		var sk = p.skills[i]
		if not sk.is_heal and not sk.on_self and p.mp >= sk.mp_cost and sk.damage > best_dmg:
			best = i
			best_dmg = sk.damage
	if best >= 0:
		bs.player_use_skill(best, t)
	else:
		bs.player_attack(t)

# Elecciones del bot: reliquia al azar tras el jefe o el sarcófago; en cada nivel, una habilidad si la ofrecen y si no, lo primero que salga.
func _build(p: CharacterData, boss: bool) -> void:
	if boss:
		_relic(p)
	while p.pending_picks > 0:
		p.pending_picks -= 1
		var offers = Upgrades.level_offers(p)
		var pick = offers[0]
		for o in offers:
			if o.id == "skill":
				pick = o
				break
		Upgrades.apply(p, pick)

func _relic(p: CharacterData) -> void:
	var r = Upgrades.relic_offers(p)
	if not r.is_empty():
		Upgrades.apply_relic(p, r[0])

func _group(f: int, p: CharacterData) -> Array[CharacterData]:
	var diff = clampi(f, 1, 5)
	var g: Array[CharacterData] = []
	for k in Pacts.enemy_count(CharacterData.get_enemy_count_for_difficulty(diff), pacts):
		var e = CharacterData.get_random_enemy(diff, f)
		Pacts.scale_enemy(e, pacts, false, meta.assist())
		g.append(e)
	return g

# Combate; si gana, nivel/reliquia, Esencia (con la recompensa de los pactos) y equipo nuevo.
func _fight(p: CharacterData, enemies: Array[CharacterData], bonus_essence := 0) -> bool:
	done = false
	bs.floor_num = cur_floor
	bs.start_battle(p, enemies, inv)
	var frames := 0
	while not done and frames < 3000:
		await process_frame
		frames += 1
	if won:
		var boss = enemies[0].is_boss
		essence_run += int(round((enemies.size() + (5 + 2 * cur_floor if boss else 0) + bonus_essence) * Pacts.reward_mult(pacts)))
		_build(p, boss)
		for it in inv.items.duplicate():
			var cur = p.equipment["weapon" if it.type == ItemData.ItemType.WEAPON else "armor"] if it.type in [ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR] else null
			if it.type == ItemData.ItemType.WEAPON and it.attack_bonus > (cur.attack_bonus if cur else 0):
				p.equip(it)
			elif it.type == ItemData.ItemType.ARMOR and it.defense_bonus > (cur.defense_bonus if cur else 0):
				p.equip(it)
	return won

# Un run completo. Devuelve [piso en el que muere (MAX_FLOOR+1 si completa), nivel final, Esencia ganada]; suma la Esencia a la meta.
func _run(cls: int) -> Array:
	var p = CharacterData.create_for_class(cls)
	meta.apply_to_run(p)
	p.pacts = pacts
	Pacts.apply_start(p)
	_spend_picks_initial(p)
	inv = Inventory.new()
	essence_run = 0
	var died = MAX_FLOOR + 1
	for f in range(1, MAX_FLOOR + 1):
		cur_floor = f
		if f > max_floor:
			max_floor = f
			essence_run += int(round(10 * Pacts.reward_mult(pacts)))
			meta.streak = 0
		p.hp = p.max_hp
		p.mp = p.max_mp
		var ok = await _floor(p, f)
		if not ok:
			died = f
			meta.streak += 1
			break
		meta.streak = 0 if ok else meta.streak
	meta.essence += essence_run
	return [died, p.level, essence_run]

func _spend_picks_initial(p: CharacterData) -> void:
	_build(p, false)

# Un piso: 4-7 grupos, 2 ataúdes (30% emboscada), pozo, sarcófago (40%), élite y jefe. Devuelve false si muere.
func _floor(p: CharacterData, f: int) -> bool:
	var groups = randi_range(4, 7)
	for i in groups:
		if not await _fight(p, _group(f, p)):
			return false
		if i == groups / 2 and p.hp < p.max_hp * 0.6: # pozo de sangre a mitad del piso
			p.heal(p.max_hp / 2)
	for c in 2:
		if randf() < 0.3 and not await _fight(p, _group(f, p)): # emboscada
			return false
		elif randf() < 0.4:
			var pots = ItemData.get_all_consumables().filter(func(i): return i.value <= 40 + 40 * f)
			if not pots.is_empty():
				inv.add_item(pots.pick_random())
		essence_run += int(round(2 * Pacts.reward_mult(pacts)))
	if randf() < 0.4 and p.hp > p.max_hp / 4: # sarcófago: -25% vida por una reliquia
		p.hp -= p.max_hp / 4
		_relic(p)
	var elite = CharacterData.create_elite(f)
	Pacts.scale_enemy(elite, pacts, false, meta.assist())
	var team: Array[CharacterData] = [elite]
	if not await _fight(p, team, 3):
		return false
	var boss = CharacterData.create_boss(f)
	Pacts.scale_enemy(boss, pacts, true, meta.assist())
	var bteam: Array[CharacterData] = [boss]
	return await _fight(p, bteam)
