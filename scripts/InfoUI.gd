extends CanvasLayer

@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel

func _ready():
	# Na začátku panel schováme, dokud hráč na nic neklikne
	hide()

func zobraz_data(data):
	show()
	id_label.text = "ID provincie: " + str(data["id"])
	owner_label.text = "Vlastník: " + str(data["owner"])
