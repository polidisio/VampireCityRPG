class_name Sfx

const FILES = {
	"hit": "impactMetal_medium_000", "hurt": "impactMetal_heavy_000", "skill": "knifeSlice",
	"heal": "handleSmallLeather", "coins": "handleCoins", "door": "doorOpen_1", "dialog": "bookOpen",
	"victory": "jingles_NES12", "defeat": "jingles_NES16",
	"sword": "sword_hit.mp3", "grunt": "hurt_grunt.mp3", "roar": "monster_roar.mp3",
	"levelup": "level_up.mp3", "key": "key.mp3", "potion": "potion.mp3",
	"step1": "step1.mp3", "step2": "step2.mp3", "step3": "step3.mp3", "click": "click.mp3"}

static func play(node: Node, key: String, db := 0.0) -> void:
	var p = AudioStreamPlayer.new()
	p.volume_db = db
	p.stream = load("res://assets/audio/" + FILES[key] + ("" if "." in FILES[key] else ".ogg"))
	p.finished.connect(p.queue_free)
	node.add_child(p)
	p.play()
