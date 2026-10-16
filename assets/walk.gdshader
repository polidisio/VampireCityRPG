shader_type canvas_item;
// Pasos sin frames de arte: la mitad inferior del sprite alterna 1 px arriba/abajo por lado (piernas que se cruzan).
uniform float walk = 0.0;      // 0 = quieto, 1 = andando
uniform float phase = 0.0;     // reloj de pasos
uniform float legs_from = 0.66; // desde esta fracción de altura hacia abajo se mueven las piernas

void fragment() {
	vec2 uv = UV;
	if (walk > 0.5 && UV.y > legs_from) {
		float s = sin(phase) >= 0.0 ? 1.0 : -1.0;
		float side = UV.x < 0.5 ? 1.0 : -1.0;
		uv.y += s * side * TEXTURE_PIXEL_SIZE.y;
		uv.x += s * TEXTURE_PIXEL_SIZE.x * 0.5;
	}
	COLOR = texture(TEXTURE, uv);
}
