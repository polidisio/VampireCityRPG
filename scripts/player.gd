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

var _step_t := 0.3

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
		_step_t += delta
		if _step_t >= 0.3:
			_step_t = 0.0
			Sfx.play(self, "step%d" % randi_range(1, 3), -4.0)
			_dust()
		if absf(direction.x) > 0.3:
			var faces_right = character_data != null and character_data.art_faces_right
			sprite.flip_h = (direction.x > 0) != faces_right # el arte suele mirar a la izquierda (se voltea al ir a la derecha); el de la Dhampir, al revés
	else:
		velocity = Vector2.ZERO
		_step_t = 0.3 # el primer paso suena al instante
	_animate(delta)
	move_and_slide()

# Animación por código (sin hojas de sprites): saltito al andar, respiración en reposo.
# El sprite sube y la sombra se queda en el suelo. ponytail: sin frames de andar; si hay arte animado, usar AnimationPlayer.
var _t := 0.0
var _was_moving := false
var _squash: Tween
func _animate(delta: float) -> void:
	_t += delta
	var moving = velocity != Vector2.ZERO
	if moving != _was_moving: # arrancar estira, frenar aplasta; rebota a su forma
		_was_moving = moving
		if _squash:
			_squash.kill()
		sprite.scale = Vector2(0.86, 1.14) if moving else Vector2(1.12, 0.9)
		_squash = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_squash.tween_property(sprite, "scale", Vector2.ONE, 0.16)
	sprite.rotation = lerpf(sprite.rotation, direction.x * 0.09 if moving else 0.0, minf(1.0, 14.0 * delta)) # se inclina hacia donde va
	var hop = absf(sin(_t * 14.0)) * 2.0 if velocity != Vector2.ZERO else (1.0 if fmod(_t, 1.4) < 0.7 else 0.0)
	sprite.position.y = -3.0 - roundf(hop)
	if sprite.has_node("Shadow"):
		sprite.get_node("Shadow").position.y = sprite.texture.get_height() / 2.0 + sprite.offset.y - 1.0 + roundf(hop)

# Dos motas de polvo a los pies en cada paso.
func _dust() -> void:
	for i in 2:
		var d = ColorRect.new()
		d.size = Vector2(2, 2)
		d.color = Color(0.78, 0.75, 0.9, 0.55)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.position = position + Vector2(randf_range(-4, 4), 7)
		d.z_index = -1
		get_parent().add_child(d)
		var tw = d.create_tween().set_parallel()
		tw.tween_property(d, "position", d.position + Vector2(randf_range(-3, 3), -4), 0.35)
		tw.tween_property(d, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(d.queue_free)

func get_input_direction() -> Vector2:
	return direction
