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
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory": null
}

static func create_noble() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Vampiro Noble"
	new_char.class_type = ClassType.NOBLE
	new_char.max_hp = 90
	new_char.hp = 90
	new_char.max_mp = 60
	new_char.mp = 60
	new_char.attack = 15
	new_char.defense = 8
	new_char.speed = 12
	new_char.skills = [
		SkillData.create("Golpe Sombrío", "Daño moderado", 15, 0, 5),
		SkillData.create("Presencia Amenazante", "Daño intimidante", 15, 0, 10)
	]
	return new_char

static func create_salvaje() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Vampiro Salvaje"
	new_char.class_type = ClassType.SALVAJE
	new_char.max_hp = 130
	new_char.hp = 130
	new_char.max_mp = 30
	new_char.mp = 30
	new_char.attack = 12
	new_char.defense = 15
	new_char.speed = 8
	new_char.skills = [
		SkillData.create("Golpe Brutal", "Daño alto", 20, 0, 5),
		SkillData.create("Piel de Acero", "Golpe con armadura", 20, 0, 15)
	]
	return new_char

static func create_dhamphir() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Dhampir"
	new_char.class_type = ClassType.DHAMPIR
	new_char.max_hp = 80
	new_char.hp = 80
	new_char.max_mp = 45
	new_char.mp = 45
	new_char.attack = 18
	new_char.defense = 5
	new_char.speed = 15
	new_char.skills = [
		SkillData.create("Tiro Preciso", "Daño a distancia", 18, 0, 3),
		SkillData.create("Disparo Sangriento", "Daño fuerte", 25, 0, 8)
	]
	return new_char

static func create_hemomante() -> CharacterData:
	var new_char = CharacterData.new()
	new_char.character_name = "Hemomante"
	new_char.class_type = ClassType.HEMOMANTE
	new_char.max_hp = 70
	new_char.hp = 70
	new_char.max_mp = 80
	new_char.mp = 80
	new_char.attack = 8
	new_char.defense = 5
	new_char.speed = 10
	new_char.skills = [
		SkillData.create("Proyectil de Sangre", "Daño mágico", 20, 0, 10),
		SkillData.create("Curación-blood", "Restaura HP", 0, 30, 15)
	]
	return new_char

func add_exp(amount: int):
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level_up()

func level_up():
	level += 1
	experience_to_next_level = int(experience_to_next_level * 1.5)
	max_hp += 10
	hp = max_hp
	max_mp += 5
	mp = max_mp
	attack += 2
	defense += 1
	speed += 1

func take_damage(amount: int) -> int:
	var actual_damage = max(1, amount - defense)
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
	enemy.level = 2
	enemy.max_hp = 80
	enemy.hp = 80
	enemy.attack = 10
	enemy.defense = 6
	enemy.speed = 8
	enemy.skills = [
		SkillData.create("Golpe Descontrolado", "Daño medio", 12, 0, 0)
	]
	return enemy

static func create_noble_vampire() -> CharacterData:
	var enemy = CharacterData.new()
	enemy.character_name = "Vampiro Noble"
	enemy.level = 4
	enemy.max_hp = 120
	enemy.hp = 120
	enemy.attack = 18
	enemy.defense = 10
	enemy.speed = 14
	enemy.skills = [
		SkillData.create("Golpe Sombrío", "Daño moderado", 15, 0, 5),
		SkillData.create("Presencia Amenazante", "Reduce defensa", 0, 0, 10)
	]
	return enemy

static func get_random_enemy(difficulty: int = 1) -> CharacterData:
	var enemies: Array[Callable] = []
	match difficulty:
		1:
			enemies = [create_hunter]
		2:
			enemies = [create_hunter, create_slayer, create_wild_vampire]
		3:
			enemies = [create_slayer, create_vampire_hunter, create_wild_vampire]
		4, 5:
			enemies = [create_vampire_hunter, create_noble_vampire]
		_:
			enemies = [create_hunter]
	
	var idx = randi() % enemies.size()
	return enemies[idx].call()

static func get_enemy_count_for_difficulty(difficulty: int) -> int:
	match difficulty:
		1: return 1
		2: return randi_range(1, 2)
		3: return randi_range(2, 3)
		4: return randi_range(2, 4)
		5: return randi_range(3, 5)
		_: return 1
