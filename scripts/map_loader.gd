extends Node2D

var provinces = {}

func _ready():
	load_provinces()
	print("Načteno provincií z TXT: ", provinces.size())

func load_provinces():
	var file = FileAccess.open("res://map_data/Provinces.txt", FileAccess.READ)
	if file == null:
		push_error("Chybí soubor Provinces.txt!")
		return
		
	file.get_line() # Přeskočit hlavičku
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
			
		var parts = line.split(";")
		if parts.size() < 4: continue # Základní kontrola délky
			
		var id = int(parts[0])
		# Ukládáme barvu přes Color8 pro maximální shodu s Pythonem
		provinces[id] = {
			"color": Color8(int(parts[1]), int(parts[2]), int(parts[3])),
			"type": parts[4],
			"state": parts[5],
			"owner": parts[6]
		}

# Funkce pro vyhledání provincie
func get_province_data_by_color(clicked_color: Color):
	# 1. úroveň (1 tabulátor)
	var v_clicked = Vector3(clicked_color.r, clicked_color.g, clicked_color.b)
	
	for id in provinces:
		# 2. úroveň (2 tabulátory)
		var c = provinces[id]["color"]
		var v_prov = Vector3(c.r, c.g, c.b)
		
		if v_prov.distance_to(v_clicked) < 0.02:
			# 3. úroveň (3 tabulátory)
			var data = provinces[id]
			data["id"] = id
			return data
			
	# Zpět na 1. úroveň
	return null
