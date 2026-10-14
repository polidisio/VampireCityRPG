extends Control

signal skill_selected(index: int)
signal item_selected(item: ItemData)
signal item_pressed

@onready var player_hp_label = $Panel/VBox/PlayerHP
@onready var player_mp_label = $Panel/VBox/PlayerMP
@onready var enemy_hp_label = $Panel/VBox/EnemyHP
@onready var menu = $Panel/Menu
var skill_menu: VBoxContainer
var log_label: Label
var log_lines: Array[String] = []

var player_char: CharacterData
var enemy_team: Array = []

func _ready():
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, 54)
	scroll.visible = false
	$Panel.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	skill_menu = VBoxContainer.new()
	scroll.add_child(skill_menu)
	var ib = Button.new()
	ib.text = "Objeto"
	menu.add_child(ib)
	menu.move_child(ib, 2)
	ib.pressed.connect(func(): item_pressed.emit())
	log_label = Label.new()
	log_label.position = Vector2(10, 10)
	add_child(log_label)

func setup_battle(player_team_ref: Array[CharacterData], enemy_team_ref: Array[CharacterData]):
	player_char = player_team_ref[0]
	enemy_team = enemy_team_ref
	log_lines.clear()
	log_label.text = ""
	update_stats()
	menu.visible = false
	skill_menu.get_parent().visible = false

func update_stats():
	if player_char:
		player_hp_label.text = "HP: %d/%d" % [player_char.hp, player_char.max_hp]
		player_mp_label.text = "MP: %d/%d" % [player_char.mp, player_char.max_mp]
	var parts: Array[String] = []
	for e in enemy_team:
		parts.append("%s %d/%d" % [e.character_name, e.hp, e.max_hp])
	enemy_hp_label.text = " | ".join(parts)

func show_player_menu():
	skill_menu.get_parent().visible = false
	menu.visible = true

func show_skill_menu(skills: Array):
	_show_list(skills.map(func(sk): return "%s (%d MP)" % [sk.name, sk.mp_cost]), func(i): skill_selected.emit(i))

func show_item_menu(items: Array):
	_show_list(items.map(func(it): return it.name), func(i): item_selected.emit(items[i]))

func _show_list(labels: Array, on_pick: Callable):
	for c in skill_menu.get_children():
		c.queue_free()
	for i in labels.size():
		var b = Button.new()
		b.text = labels[i]
		b.pressed.connect(func():
			skill_menu.get_parent().visible = false
			on_pick.call(i))
		skill_menu.add_child(b)
	var back = Button.new()
	back.text = "Volver"
	back.pressed.connect(show_player_menu)
	skill_menu.add_child(back)
	menu.visible = false
	skill_menu.get_parent().visible = true

func add_log(text: String):
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
