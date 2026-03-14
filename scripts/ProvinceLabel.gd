extends Node2D

@onready var label = $Label

var province_id: int = -1
var je_hlavni: bool = true 

func _ready():
	reset_stav()

func nastav_stav(je_cil: bool):
	if je_cil:
		# Jsem přesně pod myší -> zaručeně se ukážu a rozsvítím!
		visible = true
		label.visible = true
		label.z_index = 10
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Nejsem cíl -> vracím se do normálu
		reset_stav()

func reset_stav():
	label.z_index = 0
	if je_hlavni:
		# Hlavní texty normálně šedě svítí
		visible = true
		label.visible = true
		label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		# Skryté texty zalezou zpět do tmy
		visible = false
