extends Node2D

func _ready():
	print("=== VAMPIRE CITY RPG ===")
	print("Proyecto iniciado correctamente")
	
	# Crear UI básica de título
	var label = Label.new()
	label.text = "VAMPIRE CITY RPG"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(160 - label.size.x / 2, 60)
	add_child(label)
	
	var sublabel = Label.new()
	sublabel.text = "Presiona ENTER para comenzar"
	sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sublabel.add_theme_font_size_override("font_size", 12)
	sublabel.position = Vector2(160 - sublabel.size.x / 2, 100)
	add_child(sublabel)

func _process(_delta):
	if Input.is_action_pressed("ui_accept"):
		print("Iniciando juego...")
		# Aquí ira la transición al juego
