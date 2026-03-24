extends CanvasLayer

@onready var money_label = $Panel/HBoxContainer/MoneyLabel
@onready var turn_label = $Panel/HBoxContainer/TurnLabel
@onready var next_btn = $Panel/HBoxContainer/NextTurnButton

# Paths to the central flag and player name based on the UI tree
@onready var player_flag = $Panel/HBoxContainer/PlayerInfo/PlayerFlag
@onready var player_name = $Panel/HBoxContainer/PlayerInfo/PlayerName

var flag_texture_cache: Dictionary = {}

func _cached_texture(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not flag_texture_cache.has(path):
		flag_texture_cache[path] = load(path)
	return flag_texture_cache[path]

func _ready():
	# Connect button clicks and GameManager signals
	next_btn.pressed.connect(_on_next_turn_pressed)
	GameManager.kolo_zmeneno.connect(aktualizuj_ui)

func aktualizuj_ui():
	# Update money and turn counters
	money_label.text = "Kasa: %.2f mil. USD (+%.2f)" % [GameManager.statni_kasa, GameManager.celkovy_prijem]
	turn_label.text = "Kolo: %d" % GameManager.aktualni_kolo
	
	# Update player info with dynamic data from GameManager
	nastav_hrace(GameManager.hrac_stat, GameManager.hrac_jmeno, GameManager.hrac_ideologie)

func _on_next_turn_pressed():
	GameManager.ukonci_kolo()

func nastav_hrace(tag: String, jmeno_statu: String, ideologie: String = ""):
	if player_name:
		player_name.text = jmeno_statu
		
	if player_flag:
		# Generate file paths for flags
		var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [tag, ideologie]
		var zaklad_cesta = "res://map_data/Flags/%s.svg" % tag
		
		# Try loading the ideology-specific flag first, fallback to the base flag
		if ideologie != "":
			var ideo_tex = _cached_texture(ideo_cesta)
			if ideo_tex:
				player_flag.texture = ideo_tex
				return

		var base_tex = _cached_texture(zaklad_cesta)
		if base_tex:
			player_flag.texture = base_tex
		else:
			player_flag.texture = null
