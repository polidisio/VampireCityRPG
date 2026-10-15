extends CharacterBody2D

const SPEED = 60.0
var character_data: CharacterData:
	set(v):
		character_data = v
		if is_node_ready():
			update_sprite()

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var animation_player = $AnimationPlayer

var direction: Vector2 = Vector2.DOWN

func _ready():
	collision_mask = 3 # capa 1: muros; capa 2: NPCs
	Shadow.attach(sprite)
	position = Vector2(160, 100)
	update_sprite()

func update_sprite():
	sprite.texture = character_data.texture(true) if character_data else load("res://assets/sprites/tile_0100.png")
	sprite.offset.y = -(sprite.texture.get_height() - 16) / 2.0 # los pies quedan donde los de un tile de 16

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
