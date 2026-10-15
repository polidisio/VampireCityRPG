extends SceneTree
# Uso: Godot --headless --path . --script tests/test_shop.gd
# El mercader prepara el run: solo equipo básico y un máximo de consumibles.
func _init():
	var stock = ShopMenu.stock()
	assert(stock.any(func(i): return i.type == ItemData.ItemType.CONSUMABLE), "vende consumibles")
	assert(stock.any(func(i): return i.type == ItemData.ItemType.WEAPON), "vende un arma de partida")
	assert(stock.all(func(i): return i.type == ItemData.ItemType.CONSUMABLE or i.value <= ShopMenu.GEAR_MAX_VALUE), "no vende equipo avanzado")
	assert(not stock.any(func(i): return i.name == "Guadaña Carmesí"), "lo mejor solo cae en la torre")
	var inv = Inventory.new()
	inv.gold = 1000
	var shop = ShopMenu.new(inv)
	root.add_child(shop)
	await process_frame
	var potion = ItemData.find_by_id("poción_pequeña")
	for i in inv.max_consumables + 3:
		shop._buy(potion)
	assert(inv.get_consumables().size() == inv.max_consumables, "mochila limitada a %d" % inv.max_consumables)
	assert(inv.gold == 1000 - inv.max_consumables * potion.value, "no cobra lo que no entra")
	var sword = ItemData.find_by_id("espada_corta")
	shop._buy(sword)
	assert(inv.items.has(sword) or inv.items.any(func(i): return i.id == "espada_corta"), "el equipo no cuenta para la mochila")
	print("OK")
	quit()
