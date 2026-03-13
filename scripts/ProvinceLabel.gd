extends Node2D

@onready var label = $Label

var province_id = -1
var je_vybrano = false

func _ready():
	# Zakladni stav - seda
	label.modulate = Color(0.6, 0.6, 0.6, 1.0)

func nastav_hover(stav: bool):
	if je_vybrano: return
	if stav:
		label.modulate = Color(0.9, 0.9, 0.9, 1.0) # Svetlejsi pri najeti
	else:
		label.modulate = Color(0.6, 0.6, 0.6, 1.0) # Navrat k sede

func nastav_vyber(stav: bool):
	je_vybrano = stav
	if je_vybrano:
		label.modulate = Color(1.0, 1.0, 1.0, 1.0) # Zvyraznena (bila)
		label.z_index = 10 # Aby byl vybrany text navrchu
	else:
		label.modulate = Color(0.6, 0.6, 0.6, 1.0)
		label.z_index = 0
