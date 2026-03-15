extends Control

@onready var dropdown = $VBoxContainer/OptionButton
@onready var play_btn = $VBoxContainer/PlayButton

# Slovník států, které si hráč může vybrat (Název pro lidi : Tag pro kód)
var hratelne_staty = {
	"Česká republika": "CZE",
	"Německo": "DEU",
	"Francie": "FRA",
	"Polsko": "POL",
	"Velká Británie": "GBR",
	"Itálie": "ITA"
}

func _ready():
	# Naplníme rozbalovací menu názvy států
	for stat in hratelne_staty.keys():
		dropdown.add_item(stat)
		
	# Propojíme tlačítko Hrát s funkcí
	play_btn.pressed.connect(_on_play_pressed)

func _on_play_pressed():
	# Zjistíme, co hráč vybral
	var vybrany_index = dropdown.selected
	var nazev_statu = dropdown.get_item_text(vybrany_index)
	var tag_statu = hratelne_staty[nazev_statu]
	
	# Uložíme to do našeho globálního manažera
	GameManager.hrac_stat = tag_statu
	print("Hráč si vybral: ", tag_statu)
	
	# PŘEPNEME DO HRY! (Tady změň cestu na tvou skutečnou scénu s mapou)
	get_tree().change_scene_to_file("res://scenes/map.tscn")
