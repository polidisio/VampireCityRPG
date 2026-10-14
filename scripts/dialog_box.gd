extends CanvasLayer
class_name DialogBox

signal closed

var text: String
var actions: Array # [[etiqueta, Callable], ...]

func _init(t: String, acts: Array = []):
	text = t
	actions = acts

func _ready():
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var label = Label.new()
	label.text = text
	label.position = Vector2(12, 12)
	label.size = Vector2(296, 110)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	var row = HBoxContainer.new()
	row.position = Vector2(12, 140)
	panel.add_child(row)
	for a in actions:
		row.add_child(_button(a[0], a[1]))
	row.add_child(_button("Cerrar [Esc]", Callable()))

func _button(label: String, on_press: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.pressed.connect(func(): _finish(on_press))
	return b

func _finish(on_press: Callable):
	closed.emit()
	queue_free()
	if on_press.is_valid():
		on_press.call()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(Callable())
