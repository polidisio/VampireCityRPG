class_name Music

const VOLUME_DB := -12.0 # bajo los SFX
static var _player: AudioStreamPlayer
static var _key := ""

# Reproduce en bucle; no reinicia si ya suena la misma pista. El reproductor vive en root para sobrevivir a change_scene.
static func play(node: Node, key: String) -> void:
	if key == _key and is_instance_valid(_player):
		return
	_key = key
	if not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.volume_db = VOLUME_DB
		node.get_tree().root.add_child.call_deferred(_player) # root está ocupado durante _ready
	var s: AudioStreamMP3 = load("res://assets/audio/music/%s.mp3" % key)
	s.loop = true
	_player.stream = s
	_player.play.call_deferred()
