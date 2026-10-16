class_name EnemyAI
extends Node
# Patrulla -> alerta ("!") -> persecución. Mueve el Area2D del enemigo a mano (sin cuerpo físico):
# choca con los muros de level.blocked y se queda antes del sello. El contacto con el jugador lo resuelve el body_entered del área.

enum { PATROL, ALERT, CHASE }
const SIGHT := 90.0
const LOSE := 150.0

var area: Area2D
var level: Node
var speed := 34.0
var state := PATROL
var _spr: Sprite2D
var _shadow: Sprite2D
var _shadow_y := 0.0
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _alert := 0.0
var _t := 0.0
var _hop_rate := 12.0
var _hop_h := 2.0

func setup(a: Area2D, lvl: Node, spd: float) -> void:
	name = "EnemyAI"
	area = a
	level = lvl
	speed = spd * randf_range(0.85, 1.15)
	_spr = a.get_child(0)
	_shadow = _spr.get_node_or_null("Shadow")
	_spr.material = ShaderMaterial.new()
	_spr.material.shader = load("res://assets/walk.gdshader")
	if _shadow:
		_shadow_y = _shadow.position.y
	_home = a.position
	_target = a.position
	_t = randf() * 10.0
	_hop_rate = randf_range(9.0, 15.0) # cada enemigo con su ritmo
	_hop_h = randf_range(1.5, 3.0)
	_wait = randf_range(0.2, 2.0)
	a.add_child(self)

func _physics_process(delta: float) -> void:
	if level.busy or level.player.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	_t += delta
	var to_p: Vector2 = level.player.position - area.position
	var grace: bool = Time.get_ticks_msec() < level.chase_grace_until
	var moving := false
	match state:
		PATROL:
			if not grace and to_p.length() < SIGHT:
				_start_alert()
			else:
				moving = _wander(delta)
		ALERT:
			_alert -= delta
			if _alert <= 0.0:
				state = CHASE
		CHASE:
			if grace or to_p.length() > LOSE:
				state = PATROL
				_home = area.position
				_wait = 1.0
			else:
				moving = _step(to_p.normalized() * speed * delta)
	_animate(moving)

func _start_alert() -> void:
	state = ALERT
	_alert = 0.45
	var l := Label.new()
	l.text = "!"
	l.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	l.position = Vector2(-3, -36)
	l.z_index = 10
	area.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", -42.0, 0.2)
	tw.tween_interval(0.3)
	tw.tween_callback(l.queue_free)

func _wander(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	if area.position.distance_to(_target) < 3.0:
		_wait = randf_range(1.0, 2.5)
		_target = _clamp(_home + Vector2(randf_range(-40, 40), randf_range(-30, 30)))
		return false
	if not _step((_target - area.position).normalized() * speed * 0.4 * delta):
		_target = area.position # bloqueado: elige otro destino
	return true

# Mueve por ejes (se desliza por las paredes). Devuelve si avanzó.
func _step(d: Vector2) -> bool:
	var moved := false
	for v in [Vector2(d.x, 0), Vector2(0, d.y)]:
		var p: Vector2 = area.position + v
		if _free(p):
			area.position = p
			moved = true
	return moved

func _free(p: Vector2) -> bool:
	return level.enemy_bounds().has_point(p) and not level.blocked.any(func(r): return r.grow(8).has_point(p))

func _clamp(p: Vector2) -> Vector2:
	var b: Rect2 = level.enemy_bounds()
	return Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))

func _animate(moving: bool) -> void:
	var hop := absf(sin(_t * _hop_rate)) * _hop_h if moving else 0.0
	_spr.position.y = -roundf(hop)
	_spr.material.set_shader_parameter("walk", 1.0 if moving else 0.0)
	_spr.material.set_shader_parameter("phase", _t * _hop_rate)
	if _shadow:
		_shadow.position.y = _shadow_y + roundf(hop)
