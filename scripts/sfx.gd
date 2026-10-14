class_name Sfx

const FILES = {
	"hit": "impactMetal_medium_000", "hurt": "impactMetal_heavy_000", "skill": "knifeSlice",
	"heal": "handleSmallLeather", "coins": "handleCoins", "door": "doorOpen_1", "dialog": "bookOpen",
	"victory": "jingles_NES12", "defeat": "jingles_NES16"}

static func play(node: Node, key: String) -> void:
	var p = AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.ogg" % FILES[key])
	p.finished.connect(p.queue_free)
	node.add_child(p)
	p.play()
