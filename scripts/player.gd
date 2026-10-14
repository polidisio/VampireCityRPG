extends CharacterBody2D

const SPEED = 60.0
var character_data: CharacterData

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var animation_player = $AnimationPlayer

var direction: Vector2 = Vector2.DOWN

func _ready():
	position = Vector2(160, 100)
	update_sprite_color()

func update_sprite_color():
	var color = Color(0.8, 0.2, 0.2)
	sprite.modulate = color

func _physics_process(_delta):
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# WASD fallback
	if input_direction == Vector2.ZERO:
		input_direction = Vector2(
			int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	
	if input_direction != Vector2.ZERO:
		direction = input_direction.normalized()
		velocity = direction * SPEED
		animation_player.play("walk")
	else:
		velocity = Vector2.ZERO
		animation_player.play("idle")
	
	move_and_slide()

func get_input_direction() -> Vector2:
	return direction
