extends CanvasLayer
class_name DialogBox

signal closed

var text: String
var actions: Array # [[etiqueta, Callable], ...]
var portrait: Texture2D

func _init(t: String, acts: Array = [], face: Texture2D = null):
	text = t
	actions = acts
	portrait = face

func _ready():
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label = Label.new()
	label.text = text
	label.position = Vector2(12, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	label.size = Vector2(296 if not portrait else 216, 110) # tras add_child: antes, el Label crece al ancho del texto y pasa bajo el retrato
	if portrait:
		var pic = TextureRect.new()
		pic.texture = portrait
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(236, 10)
		pic.size = Vector2(72, 72)
		panel.add_child(pic)
	var row = HBoxContainer.new()
	row.position = Vector2(12, 140)
	panel.add_child(row)
	for a in actions:
		row.add_child(_button(a[0], a[1]))
	row.add_child(_button("Cerrar [Esc]", Callable()))
	row.get_child(0).grab_focus.call_deferred()

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
