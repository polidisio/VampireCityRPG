extends SceneTree
# El menú de inventario lista las reliquias del run.
func _init():
	var c = CharacterData.create_for_class(0)
	Upgrades.apply_relic(c, Upgrades.RELICS[0])
	var m = InventoryMenu.new(c, Inventory.new())
	root.add_child(m)
	await process_frame
	var found := false
	for n in m.list.get_children():
		if n is Label and n.text.contains(Upgrades.RELICS[0].name):
			found = true
	print("OK" if found else "FAIL: reliquia no listada")
	quit(0 if found else 1)
