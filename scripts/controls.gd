class_name Controls

# Acciones propias (teclado + mando). Los menús usan ui_* (flechas/D-pad, A = aceptar, B = cancelar).
static var _click_hooked := false

static func setup() -> void:
	if not _click_hooked:
		_click_hooked = true
		var tree := Engine.get_main_loop() as SceneTree
		tree.node_added.connect(func(n: Node):
			if n is BaseButton:
				n.pressed.connect(func(): Sfx.play(tree.root, "click", -6.0)))
	_add("interact", KEY_E, JOY_BUTTON_A)
	_add("inventory", KEY_I, JOY_BUTTON_Y)
	_add("hub", KEY_H, JOY_BUTTON_X)
	_add("pause", KEY_ESCAPE, JOY_BUTTON_START)
	_add("fullscreen", KEY_F11)

static func _add(action: String, key: Key, button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var k = InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)
	if button >= 0:
		var j = InputEventJoypadButton.new()
		j.button_index = button as JoyButton
		InputMap.action_add_event(action, j)

static func toggle_fullscreen() -> void:
	var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

const HELP = "Mover: WASD / flechas / stick\nInteractuar: E / A\nInventario: I / Y\nVolver al hub: H / X\nPausa: Esc / Start\nPantalla completa: F11\nMenús: ratón, flechas o D-pad; A acepta, B cancela"
