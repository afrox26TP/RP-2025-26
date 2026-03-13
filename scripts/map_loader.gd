extends Node2D

var provinces = {}

func _ready():
	load_provinces()
	print("Načteno provincií z TXT: ", provinces.size())
	
	# --- NOVÉ: Po načtení řekneme Spritu, ať vykreslí defaultní mapu ---
	var sprite = $Sprite2D # Ujisti se, že cesta ke Spritu sedí s tvým stromem uzlů
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod("political", provinces)
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
			
		var prov_id = int(parts[0])
		
		# Ošetření, aby to nespadlo, kdyby nějaký řádek neměl vyplněnou populaci/GDP
		var pop = 0
		var gdp_val = 0.0
		if parts.size() > 12:
			pop = int(parts[12])
		if parts.size() > 13:
			gdp_val = float(parts[13])
		
		provinces[prov_id] = {
			"id": prov_id, # Uložíme rovnou sem
			"color": Color8(int(parts[1]), int(parts[2]), int(parts[3])),
			"type": parts[4],
			"state": parts[5],
			"owner": parts[6],
			"population": pop,
			"gdp": gdp_val
		}

# Funkce pro vyhledání provincie
func get_province_data_by_color(clicked_color: Color):
	var v_clicked = Vector3(clicked_color.r, clicked_color.g, clicked_color.b)
	
	for id in provinces:
		var c = provinces[id]["color"]
		var v_prov = Vector3(c.r, c.g, c.b)
		
		if v_prov.distance_to(v_clicked) < 0.02:
			return provinces[id]
			
	return null
