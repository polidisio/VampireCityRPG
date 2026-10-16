extends Control
class_name Bar
# Barra de vida/maná con el número dentro.

var color := Color(0.8, 0.15, 0.2)
var cur := 1
var maxv := 1
var prefix := ""
var ghost := -1.0 # rastro blanco que baja hacia el valor real tras recibir daño

func _init(c: Color, w: float, h: float = 9.0):
	color = c
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(c: int, m: int) -> void:
	cur = c
	maxv = maxi(1, m)
	var f = clampf(float(cur) / maxv, 0.0, 1.0)
	if ghost < 0.0 or f > ghost:
		ghost = f
	set_process(ghost > f)
	queue_redraw()

func _process(delta: float) -> void:
	var f = clampf(float(cur) / maxv, 0.0, 1.0)
	ghost = maxf(f, ghost - delta * 0.5)
	set_process(ghost > f)
	queue_redraw()

func _draw() -> void:
	var inner = Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(Rect2(Vector2.ZERO, size), color.darkened(0.8)) # borde
	draw_rect(inner, color.darkened(0.7).lerp(Color.BLACK, 0.5)) # hueco
	var f = clampf(float(cur) / maxv, 0.0, 1.0)
	if ghost > f:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ghost, inner.size.y)), Color(1, 1, 1, 0.75))
	var fill = Rect2(inner.position, Vector2(roundf(inner.size.x * f), inner.size.y))
	if fill.size.x > 0.0:
		draw_rect(fill, color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), color.lightened(0.45)) # brillo
		draw_rect(Rect2(fill.position + Vector2(0, fill.size.y - 2), Vector2(fill.size.x, 2)), color.darkened(0.35)) # sombra
	for i in range(1, 4): # marcas al 25/50/75 %
		draw_rect(Rect2(inner.position.x + roundf(inner.size.x * i / 4.0), inner.position.y, 1, 2), Color(0, 0, 0, 0.5))
	var font = get_theme_default_font()
	var fs = 9
	var text = "%s%d/%d" % [prefix, cur, maxv]
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos = Vector2((size.x - w) / 2.0, (size.y + fs) / 2.0 - 1.5)
	draw_string(font, pos + Vector2.ONE * 0.6, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
