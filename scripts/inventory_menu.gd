extends CanvasLayer
class_name InventoryMenu

signal closed

var character: CharacterData
var inventory: Inventory
var info: Label
var list: VBoxContainer

func _init(c: CharacterData, inv: Inventory):
	character = c
	inventory = inv

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info = Label.new()
	info.position = Vector2(8, 8)
	panel.add_child(info)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(150, 8)
	scroll.size = Vector2(162, 164)
	panel.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size.x = 150
	scroll.add_child(list)
	refresh()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

func refresh():
	var c = character
	var eq = func(slot): return c.equipment[slot].name if c.equipment[slot] else "-"
	info.text = "%s Nv%d\nHP %d/%d\nMP %d/%d\nATK %d DEF %d VEL %d\nEXP %d/%d\nOro %d\n\nArma: %s\nArmadura: %s\nAccesorio: %s\n\n[I/Esc] cerrar" % [
		c.character_name, c.level, c.hp, c.max_hp, c.mp, c.max_mp, c.attack, c.defense, c.speed,
		c.experience, c.experience_to_next_level, inventory.gold,
		eq.call("weapon"), eq.call("armor"), eq.call("accessory")]
	for n in list.get_children():
		n.queue_free()
	for r in Upgrades.RELICS.filter(func(r): return c.has_relic(r.id)):
		var l = Label.new() # reliquias del run: nombre y efecto
		l.text = "* %s: %s" % [r.name, r.desc]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 150
		l.modulate = Color(1, 0.85, 0.4)
		list.add_child(l)
	var first: Button
	for item in inventory.items:
		var b = Button.new()
		b.text = item.name
		b.icon = item.icon()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = item.description
		b.pressed.connect(_on_item.bind(item))
		list.add_child(b)
		first = first if first else b
	if first:
		first.grab_focus.call_deferred()

func _on_item(item: ItemData):
	if item.type == ItemData.ItemType.CONSUMABLE:
		character.use_item(item)
	else:
		var old = character.equip(item)
		if old:
			inventory.items.append(old)
	inventory.remove_item(item)
	refresh()
