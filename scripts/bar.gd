extends Control
class_name Bar
# Barra de vida/maná con el número dentro.

var color := Color(0.8, 0.15, 0.2)
var cur := 1
var maxv := 1
var prefix := ""

func _init(c: Color, w: float, h: float = 9.0):
	color = c
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(c: int, m: int) -> void:
	cur = c
	maxv = maxi(1, m)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.02, 0.08))
	draw_rect(Rect2(Vector2.ONE, (size - Vector2(2, 2)) * Vector2(clampf(float(cur) / maxv, 0.0, 1.0), 1.0)), color)
	var font = get_theme_default_font()
	var fs = 9
	var text = "%s%d/%d" % [prefix, cur, maxv]
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos = Vector2((size.x - w) / 2.0, (size.y + fs) / 2.0 - 1.5)
	draw_string(font, pos + Vector2.ONE * 0.6, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
