extends Control

@onready var player_hp_label = $Panel/VBox/PlayerHP
@onready var player_mp_label = $Panel/VBox/PlayerMP
@onready var enemy_hp_label = $Panel/VBox/EnemyHP
@onready var menu = $Panel/Menu
var log_lines: Array[String] = []

# References to characters for UI updates
var player_char: CharacterData
var enemy_team: Array = []

func setup_battle(player_team_ref: Array[CharacterData], enemy_team_ref: Array[CharacterData]):
    # Store references for UI updates
    player_char = player_team_ref[0]
    enemy_team = enemy_team_ref
    update_stats()
    menu.visible = false

func update_stats():
    if player_char:
        player_hp_label.text = "HP: %d/%d" % [player_char.hp, player_char.max_hp]
        player_mp_label.text = "MP: %d/%d" % [player_char.mp, player_char.max_mp]
    else:
        player_hp_label.text = "HP: 0/0"
        player_mp_label.text = "MP: 0/0"

    if enemy_team.size() > 0 and enemy_team[0]:
        var e = enemy_team[0]
        enemy_hp_label.text = "Enemy HP: %d/%d" % [e.hp, e.max_hp]
    else:
        enemy_hp_label.text = "Enemy HP: 0/0"

func show_player_menu():
    menu.visible = true

func add_log(text: String):
    log_lines.append(text)
    if log_lines.size() > 4:
        log_lines.pop_front()
    print(text)
