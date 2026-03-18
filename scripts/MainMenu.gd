extends Control

@onready var dropdown = $VBoxContainer/OptionButton
@onready var play_btn = $VBoxContainer/PlayButton

# Seznam států (Zobrazený text : Tag)
var hratelne_staty = {
	"Albánie": "ALB",
	"Rakousko": "AUT",
	"Belgie": "BEL",
	"Bulharsko": "BGR",
	"Bosna a Hercegovina": "BIH",
	"Bělorusko": "BLR",
	"Švýcarsko": "CHE",
	"Kypr": "CYP",
	"Česká republika": "CZE",
	"Německo": "DEU",
	"Dánsko": "DNK",
	"Španělsko": "ESP",
	"Estonsko": "EST",
	"Finsko": "FIN",
	"Francie": "FRA",
	"Velká Británie": "GBR",
	"Gruzie": "GEO",
	"Řecko": "GRC",
	"Chorvatsko": "HRV",
	"Maďarsko": "HUN",
	"Irsko": "IRL",
	"Island": "ISL",
	"Itálie": "ITA",
	"Kosovo": "KOS",
	"Litva": "LTU",
	"Lucembursko": "LUX",
	"Lotyšsko": "LVA",
	"Moldavsko": "MDA",
	"Severní Makedonie": "MKD",
	"Černá Hora": "MNE",
	"Nizozemsko": "NLD",
	"Norsko": "NOR",
	"Polsko": "POL",
	"Portugalsko": "PRT",
	"Rumunsko": "ROU",
	"Rusko": "RUS",
	"Srbsko": "SRB",
	"Slovensko": "SVK",
	"Slovinsko": "SVN",
	"Švédsko": "SWE",
	"Turecko": "TUR",
	"Ukrajina": "UKR"
}

func _ready():
	# Nacpu státy do dropdownu
	for stat in hratelne_staty.keys():
		dropdown.add_item(stat)
		
	# Napojím tlačítko
	play_btn.pressed.connect(_on_play_pressed)

func _on_play_pressed():
	# Zjistím, co je vybráno
	var vybrany_index = dropdown.selected
	var nazev_statu = dropdown.get_item_text(vybrany_index)
	var tag_statu = hratelne_staty[nazev_statu]
	
	# Uložím tag do GameManageru
	GameManager.hrac_stat = tag_statu
	print("Hráč si vybral: ", tag_statu)
	
	# Spustím hru 
	get_tree().change_scene_to_file("res://scenes/map.tscn")
