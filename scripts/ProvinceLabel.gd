extends Node2D

@onready var label = $Label

var province_id: int = -1
var je_hlavni: bool = true 
var is_capital: bool = false 
var is_zoomed_out: bool = false
var aktualni_zoom: float = 1.0 

var plny_nazev: String = "" # Sem si uložíme celý název i s hvězdičkou

func _ready():
	if label and plny_nazev == "":
		plny_nazev = label.text
	reset_stav()

func get_spravny_scale() -> Vector2:
	if is_zoomed_out and is_capital:
		var zvetseni = clamp(1.0 / aktualni_zoom, 1.0, 4.0) 
		return Vector2(zvetseni, zvetseni)
	else:
		return Vector2(1.0, 1.0)

func nastav_stav_souseda(je_cil: bool, je_soused: bool):
	if is_zoomed_out and not is_capital:
		visible = false
		return

	var cilovy_scale = get_spravny_scale()

	if je_cil:
		visible = true
		label.visible = true
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = cilovy_scale
		z_index = 10
		# I při najetí myší necháme jen hvězdičku, pokud je odzoomováno
		label.text = "★" if (is_zoomed_out and is_capital) else plny_nazev
	elif je_soused:
		visible = true
		label.visible = true
		label.modulate = Color(0.8, 0.8, 0.8, 1.0)
		scale = cilovy_scale * 0.8 
		z_index = 5
		label.text = "★" if (is_zoomed_out and is_capital) else plny_nazev
	else:
		reset_stav()

func reset_stav():
	z_index = 0             
	scale = get_spravny_scale() 
	
	if is_zoomed_out:
		if is_capital:
			visible = true
			label.visible = true
			label.text = "★" # ZMĚNA: Skryje text, nechá jen ikonu hvězdy
			label.modulate = Color(1.0, 0.9, 0.5, 1.0)
		else:
			visible = false
	else:
		if je_hlavni:
			visible = true
			label.visible = true
			label.text = plny_nazev # ZMĚNA: Vrátí zpět plný název města
			label.modulate = Color(1.0, 0.9, 0.5, 1.0) if is_capital else Color(0.6, 0.6, 0.6, 1.0)
		else:
			visible = false
