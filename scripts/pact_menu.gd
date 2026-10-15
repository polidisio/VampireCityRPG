extends CanvasLayer
class_name PactMenu
# Al empezar un run: elegir pactos (alternar con Aceptar) y empezar.

signal confirmed(ids: Array)

var selected: Array
var list: VBoxContainer
var desc_label: Label
var start_btn: Button

func _init(preselected: Array = []):
	selected = preselected.duplicate()

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = Label.new()
	title.text = "PACTOS: más dificultad, más recompensa"
	title.position = Vector2(8, 4)
	panel.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 22)
	scroll.size = Vector2(304, 118)
	panel.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size.x = 296
	scroll.add_child(list)
	desc_label = Label.new()
	desc_label.position = Vector2(8, 146)
	desc_label.size = Vector2(304, 30)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_label)
	start_btn = Button.new() # primero: con los pactos de siempre se empieza con un solo pulso
	start_btn.focus_entered.connect(func(): desc_label.text = "Esc también empieza el run")
	start_btn.pressed.connect(_confirm)
	list.add_child(start_btn)
	for p in Pacts.PACTS:
		var b = Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(func(): desc_label.text = p.desc)
		b.pressed.connect(func():
			if selected.has(p.id):
				selected.erase(p.id)
			else:
				selected.append(p.id)
			refresh())
		list.add_child(b)
	start_btn.grab_focus.call_deferred()
	refresh()

func _confirm():
	confirmed.emit(selected)
	queue_free()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm()

func refresh():
	for i in Pacts.PACTS.size():
		var p = Pacts.PACTS[i]
		list.get_child(i + 1).text = "[%s] %s  +%d%%" % ["x" if selected.has(p.id) else " ", p.name, int(p.bonus * 100)]
	start_btn.text = "EMPEZAR  (recompensa +%d%%)" % roundi((Pacts.reward_mult(selected) - 1.0) * 100)
	if desc_label.text == "":
		desc_label.text = "Esc también empieza el run"
