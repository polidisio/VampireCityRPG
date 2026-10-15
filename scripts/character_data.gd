extends RefCounted
class_name CharacterData

enum ClassType { NOBLE, SALVAJE, DHAMPIR, HEMOMANTE }

var character_name: String = ""
var class_type: ClassType = ClassType.NOBLE
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 100

var hp: int = 100
var max_hp: int = 100
var mp: int = 50
var max_mp: int = 50
var attack: int = 10
var defense: int = 5
var speed: int = 10

var skills: Array = []
var sprite_tile: int = 100 # tile de assets/sprites
var art: String = "" # arte propio, ruta bajo assets/sprites/ sin extensión (classes/noble, enemies/bat): <art>.png combate, <art>_map.png mapa
var is_boss: bool = false
var intent_skill: SkillData = null # solo enemigos: habilidad que usará en su próximo turno (null = ataque básico)
var statuses: Dictionary = {} # nombre -> turnos restantes
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory": null
}

# Textura de combate (64 px) o, con map=true, de mapa; sin arte propio usa el tile Kenney.
func texture(map: bool = false) -> Texture2D:
	if art != "":
		return load("res://assets/sprites/%s%s.png" % [art, "_map" if map else ""])
	return load("res://assets/sprites/tile_%04d.png" % sprite_tile)

static func create_noble() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Vampiro Noble"
	new_char.class_type = ClassType.NOBLE
	new_char.sprite_tile = 100
	new_char.art = "classes/noble"
	new_char.max_hp = 90
	new_char.hp = 90
	new_char.max_mp = 60
	new_char.mp = 60
	new_char.attack = 15
	new_char.defense = 8
	new_char.speed = 12
	new_char.sync_skills()
	return new_char

static func create_salvaje() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Vampiro Salvaje"
	new_char.class_type = ClassType.SALVAJE
	new_char.sprite_tile = 87
	new_char.art = "classes/salvaje"
	new_char.max_hp = 130
	new_char.hp = 130
	new_char.max_mp = 30
	new_char.mp = 30
	new_char.attack = 12
	new_char.defense = 15
	new_char.speed = 8
	new_char.sync_skills()
	return new_char

static func create_dhamphir() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Dhampir"
	new_char.class_type = ClassType.DHAMPIR
	new_char.sprite_tile = 88
	new_char.art = "classes/dhampir"
	new_char.max_hp = 90
	new_char.hp = 90
	new_char.max_mp = 45
	new_char.mp = 45
	new_char.attack = 18
	new_char.defense = 5
	new_char.speed = 15
	new_char.sync_skills()
	return new_char

static func create_hemomante() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Hemomante"
	new_char.class_type = ClassType.HEMOMANTE
	new_char.sprite_tile = 84
	new_char.art = "classes/hemomante"
	new_char.max_hp = 70
	new_char.hp = 70
	new_char.max_mp = 80
	new_char.mp = 80
	new_char.attack = 10
	new_char.defense = 5
	new_char.speed = 10
	new_char.sync_skills()
	return new_char

static func class_skills(c: ClassType) -> Array:
	match c:
		ClassType.SALVAJE: return [
			SkillData.create("Golpe Brutal", "Daño alto", 20, 0, 5),
			SkillData.create("Piel de Acero", "Golpe con armadura", 20, 0, 15),
			SkillData.create("Desgarro", "Hiere y causa sangrado", 18, 0, 10).with_status("sangrado", 3).at_level(3),
			SkillData.create("Rugido Aterrador", "Reduce la defensa enemiga", 8, 0, 12).with_status("debil", 3).at_level(5),
			SkillData.create("Frenesí", "Aumenta tu ataque", 0, 0, 15).with_status("furia", 4, true).at_level(7)]
		ClassType.DHAMPIR: return [
			SkillData.create("Tiro Preciso", "Daño a distancia", 18, 0, 3),
			SkillData.create("Disparo Sangriento", "Daño fuerte y sangrado", 25, 0, 8).with_status("sangrado", 2),
			SkillData.create("Estaca de Plata", "Daño muy alto", 30, 0, 12).at_level(3),
			SkillData.create("Red de Ajo", "Aturde al enemigo", 5, 0, 14).with_status("aturdido", 2).at_level(5),
			SkillData.create("Instinto Cazador", "Aumenta tu ataque", 0, 0, 10).with_status("furia", 3, true).at_level(7)]
		ClassType.HEMOMANTE: return [
			SkillData.create("Proyectil de Sangre", "Daño mágico", 20, 0, 8),
			SkillData.create("Curación-blood", "Restaura HP", 0, 30, 12),
			SkillData.create("Hemorragia", "Sangrado prolongado", 12, 0, 14).with_status("sangrado", 4).at_level(3),
			SkillData.create("Transfusión", "Restaura mucho HP", 0, 70, 28).at_level(5),
			SkillData.create("Lluvia Carmesí", "Daño mágico devastador", 35, 0, 22).at_level(7)]
		_: return [
			SkillData.create("Golpe Sombrío", "Daño moderado", 15, 0, 5),
			SkillData.create("Presencia Amenazante", "Reduce la defensa enemiga", 15, 0, 10).with_status("debil", 3),
			SkillData.create("Mordisco Carmesí", "Daño y sangrado", 20, 0, 12).with_status("sangrado", 3).at_level(3),
			SkillData.create("Mirada Hipnótica", "Aturde al enemigo", 0, 0, 15).with_status("aturdido", 2).at_level(5),
			SkillData.create("Orgullo Ancestral", "Aumenta tu ataque", 0, 0, 14).with_status("furia", 3, true).at_level(7)]

func sync_skills():
	skills = CharacterData.class_skills(class_type).filter(func(sk): return sk.unlock_level <= level)

func has_status(s: String) -> bool:
	return statuses.has(s)

func add_status(s: String, turns: int):
	statuses[s] = maxi(turns, statuses.get(s, 0))

# Inicio de turno: aplica sangrado y descuenta turnos. Devuelve líneas de log.
func tick_statuses() -> Array[String]:
	var lines: Array[String] = []
	if has_status("sangrado"):
		var d = maxi(1, int(max_hp * 0.1))
		hp = maxi(0, hp - d)
		lines.append("%s sangra (-%d HP)" % [character_name, d])
	for s in statuses.keys():
		statuses[s] -= 1
		if statuses[s] <= 0:
			statuses.erase(s)
	return lines

func status_text() -> String:
	return "" if statuses.is_empty() else " [" + ",".join(statuses.keys()) + "]"

func add_exp(amount: int):
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level_up()

func level_up():
	level += 1
	experience_to_next_level = int(experience_to_next_level * 1.35)
	max_hp += 10
	hp = max_hp
	max_mp += 5
	mp = max_mp
	attack += 2
	defense += 1
	speed += 1
	sync_skills()

# Daño que causaría un golpe de `amount` (lo usan take_damage y las intenciones de los enemigos).
func preview_damage(amount: int) -> int:
	var def = int(defense * 0.5) if has_status("debil") else defense
	return max(1, amount - def)

func take_damage(amount: int) -> int:
	var actual_damage = preview_damage(amount)
	hp = max(0, hp - actual_damage)
	return actual_damage

func equip(item: ItemData) -> ItemData:
	var slot = {ItemData.ItemType.WEAPON: "weapon", ItemData.ItemType.ARMOR: "armor", ItemData.ItemType.ACCESSORY: "accessory"}[item.type]
	var old: ItemData = equipment[slot]
	if old:
		attack -= old.attack_bonus
		defense -= old.defense_bonus
	equipment[slot] = item
	attack += item.attack_bonus
	defense += item.defense_bonus
	return old

func use_item(item: ItemData):
	heal(item.hp_restore)
	mp = min(max_mp, mp + item.mp_restore)

static func create_for_class(c: ClassType) -> CharacterData:
	match c:
		ClassType.SALVAJE: return create_salvaje()
		ClassType.DHAMPIR: return create_dhamphir()
		ClassType.HEMOMANTE: return create_hemomante()
		_: return create_noble()

func heal(amount: int):
	hp = min(max_hp, hp + amount)

func use_mp(cost: int) -> bool:
	if mp >= cost:
		mp -= cost
		return true
	return false

static func create_hunter() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Cazador Ángel"
	enemy.sprite_tile = 97
	enemy.art = "enemies/cazador_angel"
	enemy.level = 1
	enemy.max_hp = 50
	enemy.hp = 50
	enemy.attack = 8
	enemy.defense = 3
	enemy.speed = 7
	return enemy

static func create_slayer() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Slayer"
	enemy.sprite_tile = 98
	enemy.art = "enemies/slayer"
	enemy.level = 2
	enemy.max_hp = 70
	enemy.hp = 70
	enemy.attack = 12
	enemy.defense = 5
	enemy.speed = 9
	return enemy

static func create_vampire_hunter() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Cazador de Vampiros"
	enemy.sprite_tile = 96
	enemy.art = "enemies/cazador_vampiros"
	enemy.level = 3
	enemy.max_hp = 90
	enemy.hp = 90
	enemy.attack = 15
	enemy.defense = 8
	enemy.speed = 11
	return enemy

static func create_wild_vampire() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Vampiro Salvaje"
	enemy.sprite_tile = 110
	enemy.art = "enemies/vampiro_salvaje"
	enemy.level = 2
	enemy.max_hp = 80
	enemy.hp = 80
	enemy.attack = 10
	enemy.defense = 6
	enemy.speed = 8
	enemy.skills = [
		SkillData.create("Golpe Descontrolado", "Daño medio y sangrado", 12, 0, 0).with_status("sangrado", 2)
	]
	return enemy

static func create_noble_vampire() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Vampiro Noble"
	enemy.sprite_tile = 111
	enemy.art = "enemies/vampiro_noble"
	enemy.level = 4
	enemy.max_hp = 120
	enemy.hp = 120
	enemy.attack = 18
	enemy.defense = 10
	enemy.speed = 14
	enemy.skills = [
		SkillData.create("Golpe Sombrío", "Daño moderado", 15, 0, 5),
		SkillData.create("Presencia Amenazante", "Reduce defensa", 0, 0, 10).with_status("debil", 3)
	]
	return enemy

const ENEMY_ART = {"Murciélago Sanguijuela": "murcielago", "Cieno Carmesí": "cieno", "Espectro": "espectro", "Araña de Cripta": "arana",
	"Cíclope Ghoul": "ciclope_ghoul", "Cazador Capitán": "capitan", "Reina Araña": "reina_arana", "Ogro de la Cripta": "ogro",
	"Espectro Real": "espectro_real", "Lord Vampiro": "lord_vampiro"}

static func _enemy(n: String, tile: int, lvl: int, health: int, power: int, armor: int, agility: int, sk: Array = []) -> CharacterData:
	var e = CharacterData.new()
	e.character_name = n
	e.sprite_tile = tile
	e.art = "enemies/" + ENEMY_ART[n]
	e.level = lvl
	e.max_hp = health
	e.hp = health
	e.attack = power
	e.defense = armor
	e.speed = agility
	e.skills = sk
	return e

static func create_bat() -> CharacterData:
	return _enemy("Murciélago Sanguijuela", 120, 1, 35, 7, 1, 14,
		[SkillData.create("Chupasangre", "Mordisco que sangra", 6, 0, 0).with_status("sangrado", 2)])

static func create_slime() -> CharacterData:
	return _enemy("Cieno Carmesí", 108, 2, 90, 8, 8, 4)

static func create_ghost() -> CharacterData:
	return _enemy("Espectro", 121, 3, 60, 16, 3, 13,
		[SkillData.create("Gemido", "Aturde", 0, 0, 0).with_status("aturdido", 1)])

static func create_spider() -> CharacterData:
	return _enemy("Araña de Cripta", 122, 3, 70, 13, 5, 12,
		[SkillData.create("Mordisco Venenoso", "Veneno", 10, 0, 0).with_status("sangrado", 3)])

static func create_ghoul() -> CharacterData:
	return _enemy("Cíclope Ghoul", 109, 4, 140, 17, 9, 6,
		[SkillData.create("Golpe Demoledor", "Daño alto", 26, 0, 0)])

# Rampa de dificultad de los pisos 1-5: multiplicador de vida y ataque de enemigos y jefe (el piso 1 lo juega un personaje sin mejoras).
const FLOOR_EASE = {1: 0.7, 2: 0.75, 3: 0.8, 4: 0.85, 5: 0.9}

# a partir del piso 5 la dificultad base se estanca: escalan los stats (+12% por piso)
static func _scale_for_floor(e: CharacterData, floor_num: int) -> void:
	var m = 1.0
	if FLOOR_EASE.has(floor_num):
		m = FLOOR_EASE[floor_num]
	elif floor_num > 5:
		m = 1.0 + 0.12 * (floor_num - 5)
	if m != 1.0:
		e.max_hp = int(e.max_hp * m)
		e.hp = e.max_hp
		e.attack = int(e.attack * m)
		e.defense = int(e.defense * m)

static func get_random_enemy(difficulty: int = 1, floor_num: int = 0) -> CharacterData:
	var enemies: Array[Callable] = []
	match difficulty:
		1:
			enemies = [create_hunter, create_bat]
		2:
			enemies = [create_hunter, create_slayer, create_wild_vampire, create_slime]
		3:
			enemies = [create_slayer, create_vampire_hunter, create_wild_vampire, create_ghost, create_spider]
		4, 5:
			enemies = [create_vampire_hunter, create_noble_vampire, create_ghost, create_spider, create_ghoul]
		_:
			enemies = [create_hunter]
	var e: CharacterData = enemies.pick_random().call()
	_scale_for_floor(e, floor_num)
	return e

# Un jefe distinto por piso (cicla cada 5 pisos y escala a partir del 6).
static func create_boss(floor_num: int) -> CharacterData:
	var b: CharacterData
	match (maxi(floor_num, 1) - 1) % 5:
		0: b = _enemy("Cazador Capitán", 96, 3, 110, 10, 4, 8,
			[SkillData.create("Golpe Aplastante", "Aturde", 14, 0, 0).with_status("aturdido", 1)])
		1: b = _enemy("Reina Araña", 122, 4, 170, 13, 6, 11,
			[SkillData.create("Telaraña", "Reduce defensa", 0, 0, 0).with_status("debil", 3),
			SkillData.create("Mordisco Venenoso", "Veneno", 12, 0, 0).with_status("sangrado", 3)])
		2: b = _enemy("Ogro de la Cripta", 109, 5, 250, 18, 9, 7,
			[SkillData.create("Rugido", "Reduce defensa", 0, 0, 0).with_status("debil", 3),
			SkillData.create("Golpe Demoledor", "Daño muy alto", 32, 0, 0)])
		3: b = _enemy("Espectro Real", 121, 6, 200, 20, 7, 14,
			[SkillData.create("Lamento", "Aturde", 0, 0, 0).with_status("aturdido", 2),
			SkillData.create("Toque Gélido", "Daño y debilita", 24, 0, 0).with_status("debil", 2)])
		_: b = _enemy("Lord Vampiro", 111, 7, 290, 24, 11, 13,
			[SkillData.create("Sed Eterna", "Daño y sangrado", 28, 0, 0).with_status("sangrado", 4),
			SkillData.create("Orgullo Ancestral", "Aumenta su ataque", 0, 0, 0).with_status("furia", 3, true)])
	b.is_boss = true
	_scale_for_floor(b, floor_num)
	return b

static func get_enemy_count_for_difficulty(difficulty: int) -> int:
	match difficulty:
		1: return 1
		2: return randi_range(1, 2)
		3: return randi_range(1, 3)
		4: return randi_range(2, 3)
		5: return randi_range(2, 4)
		_: return 1
