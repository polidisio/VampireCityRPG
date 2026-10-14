extends SceneTree
# Simula torres completas con el BattleSystem real y un jugador "razonable".
# Uso: Godot --headless --path . --script tests/sim_balance.gd
# REST=1: además vuelve a la posada (10 oro) si HP < 50% entre combates.
# Supuestos: posada (HP/MP full) al empezar cada piso; no compra en tienda; equipa lo que dropea.
const RUNS = 20
const MAX_FLOOR = 15

var bs: BattleSystem
var inv: Inventory
var won := false
var done := false

func _init():
	randomize()
	bs = load("res://scenes/battle.tscn").instantiate()
	bs.enemy_delay = 0.0
	root.add_child(bs)
	bs.turn_changed.connect(func(_n): if bs.is_player_turn: _act.call_deferred())
	bs.battle_ended.connect(func(v):
		won = v
		done = true)
	await process_frame
	for cls in 4:
		var deaths := {}
		var lvl_sum := 0
		var floor_sum := 0
		for r in RUNS:
			var res = await _run(cls)
			deaths[res[0]] = deaths.get(res[0], 0) + 1
			floor_sum += res[0]
			lvl_sum += res[1]
		var keys = deaths.keys()
		keys.sort()
		print("%-10s piso medio %.1f  nivel medio %.1f  muertes por piso %s" % [
			CharacterData.create_for_class(cls).character_name, float(floor_sum) / RUNS, float(lvl_sum) / RUNS,
			", ".join(keys.map(func(k): return "%d:%d" % [k, deaths[k]]))])
	quit()

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
		if not pots.is_empty():
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

func _fight(p: CharacterData, enemies: Array[CharacterData]) -> bool:
	done = false
	bs.start_battle(p, enemies, inv)
	var frames := 0
	while not done and frames < 3000:
		await process_frame
		frames += 1
	if won:
		for it in inv.items.duplicate():
			var cur = p.equipment["weapon" if it.type == ItemData.ItemType.WEAPON else "armor"] if it.type in [ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR] else null
			if it.type == ItemData.ItemType.WEAPON and it.attack_bonus > (cur.attack_bonus if cur else 0):
				p.equip(it)
			elif it.type == ItemData.ItemType.ARMOR and it.defense_bonus > (cur.defense_bonus if cur else 0):
				p.equip(it)
	return won

# Devuelve [piso en el que muere (MAX_FLOOR+1 si completa), nivel final]
func _run(cls: int) -> Array:
	var p = CharacterData.create_for_class(cls)
	inv = Inventory.new()
	for f in range(1, MAX_FLOOR + 1):
		p.hp = p.max_hp
		p.mp = p.max_mp
		var diff = clampi(f, 1, 5)
		var fights = randi_range(2, 4)
		for i in fights + 1:
			var enemies: Array[CharacterData] = []
			if i == fights:
				enemies.append(CharacterData.create_boss(f))
			else:
				for k in CharacterData.get_enemy_count_for_difficulty(diff):
					enemies.append(CharacterData.get_random_enemy(diff, f))
			if OS.get_environment("REST") == "1" and p.hp < p.max_hp * 0.5 and inv.spend_gold(10):
				p.hp = p.max_hp
				p.mp = p.max_mp
			if not await _fight(p, enemies):
				return [f, p.level]
	return [MAX_FLOOR + 1, p.level]
