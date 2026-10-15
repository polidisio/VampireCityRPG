class_name Inventory

signal inventory_updated

const BASE_CONSUMABLES = 4 # lo que se puede comprar y llevar al run (los botines no cuentan); el altar lo amplía

var max_consumables := BASE_CONSUMABLES
var items: Array[ItemData] = []
var gold: int = 0

func add_item(item: ItemData) -> void:
	items.append(item)
	inventory_updated.emit()

func remove_item(item: ItemData) -> bool:
	var idx = items.find(item)
	if idx >= 0:
		items.remove_at(idx)
		inventory_updated.emit()
		return true
	return false

func has_item(item: ItemData) -> bool:
	return items.has(item)

func get_consumables() -> Array[ItemData]:
	return items.filter(func(i): return i.type == ItemData.ItemType.CONSUMABLE)

func get_weapons() -> Array[ItemData]:
	return items.filter(func(i): return i.type == ItemData.ItemType.WEAPON)

func get_armors() -> Array[ItemData]:
	return items.filter(func(i): return i.type == ItemData.ItemType.ARMOR)

func get_accessories() -> Array[ItemData]:
	return items.filter(func(i): return i.type == ItemData.ItemType.ACCESSORY)

func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false
