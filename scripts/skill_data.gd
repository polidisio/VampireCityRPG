class_name SkillData

var name: String = ""
var description: String = ""
var damage: int = 0
var heal: int = 0
var mp_cost: int = 0
var is_heal: bool = false

static func create(n: String, d: String, dmg: int = 0, h: int = 0, mp: int = 0) -> SkillData:
	var skill = SkillData.new()
	skill.name = n
	skill.description = d
	skill.damage = dmg
	skill.heal = h
	skill.mp_cost = mp
	skill.is_heal = h > 0
	return skill
