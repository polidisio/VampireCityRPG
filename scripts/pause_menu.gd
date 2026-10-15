extends CanvasLayer
class_name PauseMenu

signal resumed
signal to_title

func _ready():
	layer = 6
	var panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = Label.new()
	title.text = "PAUSA"
	title.position = Vector2(140, 14)
	panel.add_child(title)
	var help = Label.new()
	help.text = Controls.HELP
	help.position = Vector2(40, 92)
	help.add_theme_constant_override("line_spacing", -3)
	help.visible = false
	panel.add_child(help)
	var box = VBoxContainer.new()
	box.position = Vector2(110, 34)
	box.custom_minimum_size.x = 100
	panel.add_child(box)
	var first = _button(box, "Continuar", _resume)
	_button(box, "Controles", func(): help.visible = not help.visible)
	_button(box, "Menú principal", func():
		to_title.emit()
		queue_free())
	first.grab_focus.call_deferred()

func _button(box: Control, label: String, on_press: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.pressed.connect(on_press)
	box.add_child(b)
	return b

func _resume():
	resumed.emit()
	queue_free()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()
