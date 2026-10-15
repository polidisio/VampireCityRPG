extends CanvasLayer
class_name AltarMenu
# Altar del hub: gasta Esencia en mejoras permanentes (Meta.UPGRADES).

signal closed

var meta: Meta
var essence_label: Label
var desc_label: Label
var list: VBoxContainer
var portrait: Texture2D

func _init(m: Meta):
	meta = m

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	essence_label = Label.new()
	essence_label.position = Vector2(8, 4)
	panel.add_child(essence_label)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 22)
	scroll.size = Vector2(304, 118)
	panel.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size.x = 296
	scroll.add_child(list)
	desc_label = Label.new() # la descripción de la mejora enfocada (también con mando)
	desc_label.position = Vector2(8, 146)
	desc_label.size = Vector2(304, 30)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_label)
	for u in Meta.UPGRADES:
		var b = Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(func(): desc_label.text = u.desc)
		b.pressed.connect(func():
			if meta.buy(u):
				Sfx.play(self, "coins")
				refresh())
		list.add_child(b)
	list.get_child(0).grab_focus.call_deferred()
	refresh()

func refresh():
	essence_label.text = "ESENCIA %d   [Esc] salir" % meta.essence
	for i in Meta.UPGRADES.size():
		var u = Meta.UPGRADES[i]
		var lv = meta.level(u.id)
		list.get_child(i).text = "%s %d/%d  -  %s" % [u.name, lv, u.max, "máx." if lv >= u.max else str(meta.cost(u))]
		list.get_child(i).disabled = false # sin deshabilitar: el foco no se pierde al comprar
	if list.get_child_count() > 0 and desc_label.text == "":
		desc_label.text = Meta.UPGRADES[0].desc

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
