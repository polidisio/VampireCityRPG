class_name Controls

# Acciones propias (teclado + mando). Los menús usan ui_* (flechas/D-pad, A = aceptar, B = cancelar).
static func setup() -> void:
	_add("interact", KEY_E, JOY_BUTTON_A)
	_add("inventory", KEY_I, JOY_BUTTON_Y)
	_add("hub", KEY_H, JOY_BUTTON_X)
	_add("pause", KEY_ESCAPE, JOY_BUTTON_START)

static func _add(action: String, key: Key, button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var k = InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)
	var j = InputEventJoypadButton.new()
	j.button_index = button
	InputMap.action_add_event(action, j)

const HELP = "Mover: WASD / flechas / stick\nInteractuar: E / A\nInventario: I / Y\nVolver al hub: H / X\nPausa: Esc / Start\nMenús: ratón, flechas o D-pad; A acepta, B cancela"
