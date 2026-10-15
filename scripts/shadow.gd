class_name Shadow

static var _tex: ImageTexture

# Añade una sombra elíptica bajo un sprite (detrás de él, hereda escala y transparencia); se ajusta a su ancho/alto.
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
	s.name = "Shadow"
	spr.add_child(s)
	fit(spr)

# Coloca/ajusta la sombra a los pies y al ancho del sprite (se llama de nuevo si cambia la textura).
static func fit(spr: Sprite2D) -> void:
	var s = spr.get_node("Shadow")
	var size = spr.texture.get_size() if spr.texture else Vector2(16, 16)
	s.position = Vector2(0, size.y / 2.0 + spr.offset.y - 1.0)
	s.scale = Vector2(maxf(1.0, size.x / 16.0 * 0.8), 1.0)
