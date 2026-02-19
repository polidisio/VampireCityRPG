extends Node
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

var skills: Array[SkillData] = []
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
		SkillData.create("Golpe Sombrío", "Daño moderado", 10, 15, 5),
		SkillData.create("Presencia Amenazante", "Reduce defensa enemy", 15, 0, 10)
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
		SkillData.create("Golpe Brutal", "Daño alto", 15, 20, 0),
		SkillData.create("Piel de Acero", "Aumenta defensa", 20, 0, 15)
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
		SkillData.create("Tiro Preciso", "Daño a distancia", 12, 18, 0),
		SkillData.create("Disparo Sangriento", "Drena vida", 18, 25, 8)
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
		SkillData.create("Proyectil de Sangre", "Daño mágico", 15, 20, 10),
		SkillData.create("Curación-blood", "Restaura HP", 20, -30, 15)
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
	print("%s subió a nivel %d" % [character_name, level])

func take_damage(amount: int) -> int:
	var actual_damage = max(1, amount - defense)
	hp = max(0, hp - actual_damage)
	return actual_damage

func heal(amount: int):
	hp = min(max_hp, hp + amount)

func use_mp(cost: int) -> bool:
	if mp >= cost:
		mp -= cost
		return true
	return false
