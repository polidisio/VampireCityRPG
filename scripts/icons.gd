class_name Icons
# Símbolos de 7x7 dibujados en código (con contorno oscuro de 1 px => 9x9). Sin hojas de sprites.

const GLYPHS = {
	"sword": [".....##", "....###", "...###.", "#.###..", ".###...", ".##....", "#.#...."],
	"heart": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
	"drop": ["...#...", "...#...", "..###..", ".#####.", "#######", "#######", ".#####."],
	"skull": [".#####.", "#######", "#.###.#", "#######", ".#####.", "..#.#..", "..###.."],
	"up": ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."],
	"down": ["..###..", "..###..", "..###..", "#######", ".#####.", "..###..", "...#..."],
	"stun": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"key": ["..###..", ".#...#.", ".#...#.", "..###..", "...#...", "..##...", "...##.."],
	"flame": ["...#...", "..##...", "..###.#", ".######", ".######", ".######", "..####."],
}
const COLORS = {
	"sword": Color(1, 0.45, 0.35), "heart": Color(0.45, 0.95, 0.55), "drop": Color(0.9, 0.2, 0.25),
	"skull": Color(0.75, 0.5, 1), "up": Color(1, 0.85, 0.3), "down": Color(0.75, 0.5, 1),
	"stun": Color(1, 0.9, 0.35), "flame": Color(1, 0.6, 0.2), "key": Color(1, 0.85, 0.3),
}
const STATUS = {"sangrado": "drop", "aturdido": "stun", "debil": "down", "furia": "flame"}
static var _cache := {}

static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var img = Image.create(9, 9, false, Image.FORMAT_RGBA8)
		var rows: Array = GLYPHS[name]
		for y in 7:
			for x in 7:
				if rows[y][x] != "#":
					continue
				for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
					img.set_pixel(x + 1 + d.x, y + 1 + d.y, Color(0.04, 0.02, 0.08))
		for y in 7:
			for x in 7:
				if rows[y][x] == "#":
					img.set_pixel(x + 1, y + 1, COLORS[name])
		_cache[name] = ImageTexture.create_from_image(img)
	return _cache[name]

# Iconos de lo que hace una habilidad (la usa el menú del jugador y las intenciones del enemigo).
static func skill_icons(sk: SkillData) -> Array[String]:
	var r: Array[String] = []
	if sk.is_heal:
		r.append("heart")
	elif sk.on_self:
		r.append(STATUS.get(sk.status, "up"))
	else:
		if sk.damage > 0:
			r.append("sword")
		if sk.status != "":
			r.append(STATUS.get(sk.status, "skull"))
		elif sk.damage == 0:
			r.append("skull")
	return r
