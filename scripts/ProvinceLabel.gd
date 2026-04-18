# ==================================================================================================
# â–â–â–â•—   â–â–â–â•— â–â–â–â–â–â•— â–â–â–â–â–â–â•— â–â–â–â–â–â–â–â•—    â–â–â–â–â–â–â•— â–â–â•—   â–â–â•—    â–â–â–â–â–â•— â–â–â–â–â–â–â–â•—â–â–â–â–â–â–â•—  â–â–â–â–â–â–â•— â–â–â•—  â–â–â•—
# â–â–â–â–â•— â–â–â–â–â•‘â–â–â•”â•â•â–â–â•—â–â–â•”â•â•â–â–â•—â–â–â•”â•â•â•â•â•ť    â–â–â•”â•â•â–â–â•—â•šâ–â–â•— â–â–â•”â•ť   â–â–â•”â•â•â–â–â•—â–â–â•”â•â•â•â•â•ťâ–â–â•”â•â•â–â–â•—â–â–â•”â•â•â•â–â–â•—â•šâ–â–â•—â–â–â•”â•ť
# â–â–â•”â–â–â–â–â•”â–â–â•‘â–â–â–â–â–â–â–â•‘â–â–â•‘  â–â–â•‘â–â–â–â–â–â•—      â–â–â–â–â–â–â•”â•ť â•šâ–â–â–â–â•”â•ť    â–â–â–â–â–â–â–â•‘â–â–â–â–â–â•—  â–â–â–â–â–â–â•”â•ťâ–â–â•‘   â–â–â•‘ â•šâ–â–â–â•”â•ť
# â–â–â•‘â•šâ–â–â•”â•ťâ–â–â•‘â–â–â•”â•â•â–â–â•‘â–â–â•‘  â–â–â•‘â–â–â•”â•â•â•ť      â–â–â•”â•â•â–â–â•—  â•šâ–â–â•”â•ť     â–â–â•”â•â•â–â–â•‘â–â–â•”â•â•â•ť  â–â–â•”â•â•â–â–â•—â–â–â•‘   â–â–â•‘ â–â–â•”â–â–â•—
# â–â–â•‘ â•šâ•â•ť â–â–â•‘â–â–â•‘  â–â–â•‘â–â–â–â–â–â–â•”â•ťâ–â–â–â–â–â–â–â•—    â–â–â–â–â–â–â•”â•ť   â–â–â•‘      â–â–â•‘  â–â–â•‘â–â–â•‘     â–â–â•‘  â–â–â•‘â•šâ–â–â–â–â–â–â•”â•ťâ–â–â•”â•ť â–â–â•—
# â•šâ•â•ť     â•šâ•â•ťâ•šâ•â•ť  â•šâ•â•ťâ•šâ•â•â•â•â•â•ť â•šâ•â•â•â•â•â•â•ť    â•šâ•â•â•â•â•â•ť    â•šâ•â•ť      â•šâ•â•ť  â•šâ•â•ťâ•šâ•â•ť     â•šâ•â•ť  â•šâ•â•ť â•šâ•â•â•â•â•â•ť â•šâ•â•ť  â•šâ•â•ť
#
#                                         Made By: Afrox26TP
# ==================================================================================================
extends Node2D
# this script drives a specific gameplay/UI area and keeps related logic together.

@onready var hbox = $HBoxContainer # Reference to the container holding text/flag
@onready var label = $HBoxContainer/Label
@onready var flag = $HBoxContainer/Flag
@onready var army_icon = $ArmyIcon # Army icon is now OUTSIDE the HBoxContainer

var province_id: int = -1
var je_hlavni: bool = true 
var is_capital: bool = false 
var is_zoomed_out: bool = false
var aktualni_zoom: float = 1.0 

var plny_nazev: String = ""

# Initializes references, connects signals, and prepares default runtime state.
func _ready():
	if label and plny_nazev == "":
		plny_nazev = label.text
	reset_stav()

# Fetches data for callers.
func get_spravny_scale() -> Vector2:
	if is_zoomed_out and is_capital:
		var zvetseni = clamp(1.0 / aktualni_zoom, 1.0, 4.0) 
		return Vector2(zvetseni, zvetseni)
	else:
		return Vector2(1.0, 1.0)

# Checks if troops are present and toggles the army icon independently
# Core flow for this feature.
func _zkontroluj_armadu() -> bool:
	if army_icon and province_id != -1 and GameManager.map_data.has(province_id):
		var troop_count = int(GameManager.map_data[province_id].get("soldiers", 0))
		if troop_count > 0:
			army_icon.show()
			return true
			
	if army_icon:
		army_icon.hide()
	return false

# Writes new values and refreshes related state.
func nastav_stav_souseda(je_cil: bool, je_soused: bool):
	var ma_armadu = _zkontroluj_armadu()
	
	if is_zoomed_out and not is_capital:
		hbox.visible = false # Hide city text
		visible = ma_armadu # Root node stays visible ONLY if there is an army
		return

	var cilovy_scale = get_spravny_scale()

	if je_cil:
		hbox.visible = true
		label.visible = not is_zoomed_out
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = cilovy_scale
		z_index = 10
		label.text = plny_nazev
	elif je_soused:
		hbox.visible = true
		label.visible = not is_zoomed_out
		label.modulate = Color(0.8, 0.8, 0.8, 1.0)
		scale = cilovy_scale * 0.8 
		z_index = 5
		label.text = plny_nazev
	else:
		reset_stav()
		return
		
	visible = true 

# Core flow for this feature.
func reset_stav():
	z_index = 0              
	scale = get_spravny_scale() 
	
	var ma_armadu = _zkontroluj_armadu()
	var ukaz_ui = false
	
	if is_zoomed_out:
		if is_capital:
			ukaz_ui = true
			label.visible = false 
	else:
		if je_hlavni:
			ukaz_ui = true
			label.visible = true
			label.modulate = Color(1.0, 0.9, 0.5, 1.0) if is_capital else Color(0.6, 0.6, 0.6, 1.0)
	
	# Hide or show the text/flag based on zoom and proximity
	hbox.visible = ukaz_ui
	
	# THE CRUCIAL FIX: The entire province label object remains active 
	# if either the UI is supposed to be shown OR an army is stationed here.
	visible = (ukaz_ui or ma_armadu)



