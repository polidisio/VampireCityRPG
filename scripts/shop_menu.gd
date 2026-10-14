extends CanvasLayer
class_name ShopMenu

signal closed

var inventory: Inventory
var gold_label: Label
var buy_list: VBoxContainer
var sell_list: VBoxContainer

func _init(inv: Inventory):
	inventory = inv

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gold_label = Label.new()
	gold_label.position = Vector2(8, 4)
	panel.add_child(gold_label)
	buy_list = _column(panel, 8, "COMPRAR")
	sell_list = _column(panel, 164, "VENDER (50%)")
	var stock: Array[ItemData] = []
	stock.append_array(ItemData.get_all_consumables())
	stock.append_array(ItemData.get_all_weapons())
	stock.append_array(ItemData.get_all_armors())
	stock.append_array(ItemData.get_all_accessories())
	for item in stock:
		var b = Button.new()
		b.text = "%s %d" % [item.name, item.value]
		b.tooltip_text = item.description
		b.pressed.connect(_buy.bind(item))
		buy_list.add_child(b)
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
	gold_label.text = "Oro %d   [Esc] salir" % inventory.gold
	for n in sell_list.get_children():
		n.queue_free()
	for item in inventory.items:
		var b = Button.new()
		b.text = "%s %d" % [item.name, int(item.value * 0.5)]
		b.pressed.connect(_sell.bind(item))
		sell_list.add_child(b)
