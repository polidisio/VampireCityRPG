extends CharacterBody2D

const SPEED = 60.0
var character_data: CharacterData:
	set(v):
		character_data = v
		if is_node_ready():
			update_sprite()

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

var direction: Vector2 = Vector2.DOWN

func _ready():
	collision_mask = 3 # capa 1: muros; capa 2: NPCs
	Shadow.attach(sprite)
	position = Vector2(160, 100)
	update_sprite()

func update_sprite():
	sprite.texture = character_data.texture(true) if character_data else load("res://assets/sprites/tile_0100.png")
	sprite.offset.y = -(sprite.texture.get_height() - 16) / 2.0 # los pies quedan donde los de un tile de 16
	Shadow.fit(sprite)

func _physics_process(delta):
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# WASD fallback
	if input_direction == Vector2.ZERO:
		input_direction = Vector2(
			int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	
	if input_direction != Vector2.ZERO:
		direction = input_direction.normalized()
		velocity = direction * SPEED
		if absf(direction.x) > 0.3:
			var faces_right = character_data != null and character_data.art_faces_right
			sprite.flip_h = (direction.x > 0) != faces_right # el arte suele mirar a la izquierda (se voltea al ir a la derecha); el de la Dhampir, al revés
	else:
		velocity = Vector2.ZERO
	_animate(delta)
	move_and_slide()

# Animación por código (sin hojas de sprites): saltito al andar, respiración en reposo.
# El sprite sube y la sombra se queda en el suelo. ponytail: sin frames de andar; si hay arte animado, usar AnimationPlayer.
var _t := 0.0
func _animate(delta: float) -> void:
	_t += delta
	var hop = absf(sin(_t * 14.0)) * 2.0 if velocity != Vector2.ZERO else (1.0 if fmod(_t, 1.4) < 0.7 else 0.0)
	sprite.position.y = -3.0 - roundf(hop)
	if sprite.has_node("Shadow"):
		sprite.get_node("Shadow").position.y = sprite.texture.get_height() / 2.0 + sprite.offset.y - 1.0 + roundf(hop)

func get_input_direction() -> Vector2:
	return direction
