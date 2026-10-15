class_name ItemData

enum ItemType { WEAPON, ARMOR, ACCESSORY, CONSUMABLE }

var id: String = ""
var name: String = ""
var description: String = ""
var type: ItemType = ItemType.CONSUMABLE
var value: int = 10
var attack_bonus: int = 0
var defense_bonus: int = 0
var hp_restore: int = 0
var mp_restore: int = 0

# Iconos: tiles Kenney de assets/sprites; TINTS recolorea (multiplica) para distinguir niveles.
const ICONS = {
	"daga_de_plata": 103, "espada_corta": 104, "espada_longa": 106, "hacha_de_guerra": 118, "látigo_encantado": 129,
	"estaca_sagrada": 107, "guadaña_carmesí": 105,
	"armadura_de_cuero": 66, "cota_de_mallas": 56, "pechera_de_acero": 54, "armadura_de_placas": 74, "manto_de_sombras": 55, "armadura_sangrienta": 74,
	"anillo_de_sangre": 101, "amuleto_de_ajo": 102, "colmillo_de_plata": 124, "capa_nocturna": 64,
	"poción_pequeña": 127, "poción_mediana": 115, "poción_grande": 115, "éter_pequeño": 128, "éter_mediano": 116, "poción_mixta": 114,
	"éter_grande": 116, "elixir": 113}
const TINTS = {"guadaña_carmesí": Color(1.5, 0.5, 0.5), "armadura_sangrienta": Color(1.6, 0.5, 0.5), "anillo_de_sangre": Color(1.6, 0.5, 0.5),
	"poción_grande": Color(1.5, 1.3, 0.5), "éter_grande": Color(1.3, 0.7, 1.5), "elixir": Color(1.5, 1.3, 0.6)}
static var _icons: Dictionary = {}

func icon() -> Texture2D:
	if not ICONS.has(id):
		return null
	if not _icons.has(id):
		var img: Image = load("res://assets/sprites/tile_%04d.png" % ICONS[id]).get_image()
		if TINTS.has(id):
			for y in img.get_height():
				for x in img.get_width():
					img.set_pixel(x, y, img.get_pixel(x, y) * TINTS[id])
		_icons[id] = ImageTexture.create_from_image(img)
	return _icons[id]

static func create_weapon(n: String, d: String, atk: int, val: int = 50) -> ItemData:
	var item = ItemData.new()
	item.id = n.to_lower().replace(" ", "_")
	item.name = n
	item.description = d
	item.type = ItemType.WEAPON
	item.attack_bonus = atk
	item.value = val
	return item

static func create_armor(n: String, d: String, def: int, val: int = 50) -> ItemData:
	var item = ItemData.new()
	item.id = n.to_lower().replace(" ", "_")
	item.name = n
	item.description = d
	item.type = ItemType.ARMOR
	item.defense_bonus = def
	item.value = val
	return item

static func create_accessory(n: String, d: String, atk: int, def: int, val: int = 30) -> ItemData:
	var item = ItemData.new()
	item.id = n.to_lower().replace(" ", "_")
	item.name = n
	item.description = d
	item.type = ItemType.ACCESSORY
	item.attack_bonus = atk
	item.defense_bonus = def
	item.value = val
	return item

static func create_consumable(n: String, d: String, hp: int = 0, mp: int = 0, val: int = 10) -> ItemData:
	var item = ItemData.new()
	item.id = n.to_lower().replace(" ", "_")
	item.name = n
	item.description = d
	item.type = ItemType.CONSUMABLE
	item.hp_restore = hp
	item.mp_restore = mp
	item.value = val
	return item

static func get_all_weapons() -> Array[ItemData]:
	return [
		create_weapon("Daga de Plata", "Daga forjada en plata, efectiva contra vampiros", 5, 30),
		create_weapon("Espada Corta", "Espada ligero de acero", 8, 50),
		create_weapon("Espada Longa", "Espada de una mano con buen equilibrio", 12, 80),
		create_weapon("Hacha de Guerra", "Hacha pesada que causa gran daño", 15, 100),
		create_weapon("Látigo Encantado", "Látigo místico del caos", 10, 75),
		create_weapon("Estaca Sagrada", "Madera bendita, letal para vampiros", 18, 130),
		create_weapon("Guadaña Carmesí", "Hoja forjada con sangre", 23, 190)
	]

static func get_all_armors() -> Array[ItemData]:
	return [
		create_armor("Armadura de Cuero", "Protección básica de cuero", 3, 25),
		create_armor("Cota de Mallas", "Cota de metal flexible", 6, 50),
		create_armor("Pechera de Acero", "Armadura sólida de placas", 10, 80),
		create_armor("Armadura de Placas", "Armadura pesada de máxima protección", 15, 120),
		create_armor("Manto de Sombras", "Tela encantada y ligera", 12, 110),
		create_armor("Armadura Sangrienta", "Placas teñidas de rojo", 21, 190)
	]

static func get_all_accessories() -> Array[ItemData]:
	return [
		create_accessory("Anillo de Sangre", "Aumenta el ataque", 3, 0, 60),
		create_accessory("Amuleto de Ajo", "Aumenta la defensa", 0, 3, 60),
		create_accessory("Colmillo de Plata", "Ataque y defensa", 2, 2, 90),
		create_accessory("Capa Nocturna", "Gran protección", 1, 5, 120)
	]

static func get_all_consumables() -> Array[ItemData]:
	return [
		create_consumable("Poción Pequeña", "Restaura 30 HP", 30, 0, 10),
		create_consumable("Poción Mediana", "Restaura 60 HP", 60, 0, 20),
		create_consumable("Poción Grande", "Restaura 100 HP", 100, 0, 35),
		create_consumable("Éter Pequeño", "Restaura 20 MP", 0, 20, 15),
		create_consumable("Éter Mediano", "Restaura 40 MP", 0, 40, 30),
		create_consumable("Poción Mixta", "Restaura 40 HP y 20 MP", 40, 20, 25),
		create_consumable("Éter Grande", "Restaura 80 MP", 0, 80, 50),
		create_consumable("Elixir", "Restaura 150 HP y 60 MP", 150, 60, 90)
	]

static func find_by_id(item_id: String) -> ItemData:
	for list in [get_all_weapons(), get_all_armors(), get_all_accessories(), get_all_consumables()]:
		for i in list:
			if i.id == item_id:
				return i
	return null
