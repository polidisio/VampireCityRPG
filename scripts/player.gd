extends CharacterBody2D

const SPEED = 60.0
var character_data: CharacterData

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var animation_player = $AnimationPlayer

var direction: Vector2 = Vector2.DOWN
var _frame_counter: int = 0
var _move_debug_logged: bool = false

func _ready():
	character_data = CharacterData.create_noble()
	position = Vector2(160, 100)
	update_sprite_color()

func update_sprite_color():
	var color = Color(0.8, 0.2, 0.2)
	sprite.modulate = color

func _physics_process(_delta):
	# Debug: show first few physics ticks to ensure processing runs
	if _frame_counter < 10:
		print("PHYSICS_TICK delta=", _delta)
		_frame_counter += 1
	# Compute movement from both on-screen controls (arrow keys) and WASD
	var input_direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	
	# Fallback for WASD keys if input map is not configured
	if input_direction == Vector2.ZERO:
		var w_down = false
		var a_left = false
		var s_down = false
		var d_right = false
		if InputMap.has_action("move_up"):
			w_down = Input.is_action_pressed("move_up")
		else:
			w_down = Input.is_key_pressed(KEY_W)
		if InputMap.has_action("move_left"):
			a_left = Input.is_action_pressed("move_left")
		else:
			a_left = Input.is_key_pressed(KEY_A)
		if InputMap.has_action("move_down"):
			s_down = Input.is_action_pressed("move_down")
		else:
			s_down = Input.is_key_pressed(KEY_S)
		if InputMap.has_action("move_right"):
			d_right = Input.is_action_pressed("move_right")
		else:
			d_right = Input.is_key_pressed(KEY_D)
		input_direction = Vector2(int(d_right) - int(a_left), int(s_down) - int(w_down))
	
	if input_direction != Vector2.ZERO:
		if not _move_debug_logged:
			print("DEBUG: movement input detected:", input_direction)
			_move_debug_logged = true
		direction = input_direction.normalized()
		velocity = direction * SPEED
		animation_player.play("walk")
	else:
		velocity = Vector2.ZERO
		animation_player.play("idle")
	
	move_and_slide()

func get_input_direction() -> Vector2:
	return direction
