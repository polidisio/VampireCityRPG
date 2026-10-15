extends CanvasLayer
class_name ShopMenu

signal closed

var inventory: Inventory
var gold_label: Label
var buy_list: VBoxContainer
var sell_list: VBoxContainer

var portrait: Texture2D

const GEAR_MAX_VALUE = 60 # el mercader solo vende equipo básico: lo mejor se encuentra en la torre

# Lo que vende: consumibles y equipo de partida.
static func stock() -> Array[ItemData]:
	var items: Array[ItemData] = []
	items.append_array(ItemData.get_all_consumables())
	for gear in ItemData.get_all_weapons() + ItemData.get_all_armors() + ItemData.get_all_accessories():
		if gear.value <= GEAR_MAX_VALUE:
			items.append(gear)
	return items

func _init(inv: Inventory, face: Texture2D = null):
	inventory = inv
	portrait = face

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gold_label = Label.new()
	gold_label.position = Vector2(8, 4)
	panel.add_child(gold_label)
	if portrait:
		var pic = TextureRect.new() # el mercader mira desde la esquina, sobre la lista de venta
		pic.texture = portrait
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(276, 0)
		pic.size = Vector2(36, 36)
		panel.add_child(pic)
	buy_list = _column(panel, 8, "COMPRAR")
	sell_list = _column(panel, 164, "VENDER (50%)")
	for item in stock():
		var b = Button.new()
		b.text = "%s %d" % [item.name, item.value]
		b.icon = item.icon()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = item.description
		b.pressed.connect(_buy.bind(item))
		buy_list.add_child(b)
	buy_list.get_child(0).grab_focus.call_deferred()
	refresh()

func _column(panel: Panel, x: int, title: String) -> VBoxContainer:
	var t = Label.new()
	t.text = title
	t.position = Vector2(x, 20)
	panel.add_child(t)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(x, 36)
	scroll.size = Vector2(148, 136)
	panel.add_child(scroll)
	var box = VBoxContainer.new()
	box.custom_minimum_size.x = 140
	scroll.add_child(box)
	return box

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()

func _buy(item: ItemData):
	if item.type == ItemData.ItemType.CONSUMABLE and inventory.get_consumables().size() >= Inventory.MAX_CONSUMABLES:
		return # mochila llena (se ve en la cabecera)
	if inventory.spend_gold(item.value):
		Sfx.play(self, "coins")
		inventory.add_item(ItemData.find_by_id(item.id))
		refresh()

func _sell(item: ItemData):
	Sfx.play(self, "coins")
	inventory.add_gold(int(item.value * 0.5))
	inventory.remove_item(item)
	refresh()

func refresh():
	gold_label.text = "Oro %d  Mochila %d/%d  [Esc] salir" % [inventory.gold, inventory.get_consumables().size(), Inventory.MAX_CONSUMABLES]
	for n in sell_list.get_children():
		n.queue_free()
	for item in inventory.items:
		var b = Button.new()
		b.text = "%s %d" % [item.name, int(item.value * 0.5)]
		b.icon = item.icon()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_sell.bind(item))
		sell_list.add_child(b)
