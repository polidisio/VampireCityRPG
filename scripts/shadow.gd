class_name Shadow

static var _tex: ImageTexture

# Añade una sombra elíptica bajo un sprite de 16x16 (detrás de él, hereda escala y transparencia).
static func attach(spr: Sprite2D) -> void:
	if _tex == null:
		var img = Image.create(16, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 16:
				var dx = (x + 0.5 - 8.0) / 8.0
				var dy = (y + 0.5 - 3.0) / 3.0
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.4))
		_tex = ImageTexture.create_from_image(img)
	var s = Sprite2D.new()
	s.texture = _tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.show_behind_parent = true
	s.position = Vector2(0, 7)
	spr.add_child(s)
