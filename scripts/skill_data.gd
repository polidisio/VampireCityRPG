class_name SkillData

var name: String = ""
var description: String = ""
var damage: int = 0
var heal: int = 0
var mp_cost: int = 0
var is_heal: bool = false
var status: String = "" # sangrado | aturdido | debil | furia
var status_turns: int = 0
var on_self: bool = false # el estado se aplica al usuario (buff)
var unlock_level: int = 1

static func create(n: String, d: String, dmg: int = 0, h: int = 0, mp: int = 0) -> SkillData:
	var skill = SkillData.new()
	skill.name = n
	skill.description = d
	skill.damage = dmg
	skill.heal = h
	skill.mp_cost = mp
	skill.is_heal = h > 0
	return skill

func with_status(s: String, turns: int, self_target: bool = false) -> SkillData:
	status = s
	status_turns = turns
	on_self = self_target
	return self

func at_level(l: int) -> SkillData:
	unlock_level = l
	return self
