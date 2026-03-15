extends Node2D

@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")

var provinces = {}
var color_cache = {}

func _ready():
	load_provinces()
	print("Nacteno provincii z TXT: ", provinces.size())
	
	# oprava cesty ke kamere (je to primy potomek, takze staci $)
	var kamera = $Camera2D 
	if kamera:
		kamera.zoom_zmenen.connect(_na_zmenu_zoomu)
	else:
		print("Chyba: Kamera nenalezena!")

	var sprite = $Sprite2D
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod("political", provinces)
	
	# spustime generovani popisku
	generuj_nazvy_provincii()
	
func load_provinces():
	var file = FileAccess.open("res://map_data/Provinces.txt", FileAccess.READ)
	if file == null:
		push_error("Chybi soubor Provinces.txt!")
		return
		
	file.get_line() # Přeskočení hlavičky
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
			
		var parts = line.split(";")
		if parts.size() < 18: continue # Teď vyžadujeme 18 sloupců z tvého nového exportu
			
		var prov_id = int(parts[0])
		
		# Bezpečné načtení populace a HDP
		var pop = 0
		var gdp_val = 0.0
		if parts[12].strip_edges() != "": pop = int(parts[12])
		if parts[13].strip_edges() != "": gdp_val = float(parts[13])
		
		# Parsování hlavního města (sloupce 15 a 16)
		var je_to_hlavni = false
		var nazev_mesta = ""
		if parts[15].strip_edges() == "1":
			je_to_hlavni = true
			nazev_mesta = parts[16].strip_edges()
			
		# Parsování sousedů (sloupec 17) z "1,2,3" na pole [1, 2, 3]
		var neighbors_array = []
		var n_str = parts[17].strip_edges()
		if n_str != "":
			for n in n_str.split(","):
				if n.strip_edges() != "":
					neighbors_array.append(int(n))
		
		provinces[prov_id] = {
			"id": prov_id,
			"color": Color8(int(parts[1]), int(parts[2]), int(parts[3])),
			"type": parts[4],
			"state": parts[5],
			"owner": parts[6],
			"x": float(parts[8]), 
			"y": float(parts[9]), 
			"province_name": parts[10], 
			"population": pop,
			"gdp": gdp_val,
			"is_capital": je_to_hlavni,
			"capital_name": nazev_mesta, # TADY PŘIDÁVÁME NÁZEV MĚSTA
			"neighbors": neighbors_array
		}

func generuj_nazvy_provincii():
	var label_container = Node2D.new()
	label_container.name = "ProvinceLabels"
	add_child(label_container)
	
	var sprite = $Sprite2D
	var offset = Vector2.ZERO
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position

	# 1. VIP ŘAZENÍ: Hlavní města jdou nekompromisně první, pak až zbytek podle populace
	var serazene_provinci = provinces.values()
	serazene_provinci.sort_custom(func(a, b): 
		if a.get("is_capital", false) != b.get("is_capital", false):
			return a.get("is_capital", false)
		return a.get("population", 0) > b.get("population", 0)
	)

	var umistene_pozice = []
	var MIN_VZDALENOST = 60.0 

	for d in serazene_provinci:
		if str(d.get("owner", "")) == "SEA" or str(d.get("province_name", "")) == "":
			continue
			
		var pozice = Vector2(d.get("x", 0), d.get("y", 0)) + offset
		
		var je_to_capital = d.get("is_capital", false)
		var moc_blizko = false
		
		# 2. OCHRANA: Pokud je to hlavní město, kašle na okolí a NIKDY se neschová
		if not je_to_capital:
			for p in umistene_pozice:
				if pozice.distance_to(p) < MIN_VZDALENOST:
					moc_blizko = true
					break
				
		var lbl_inst = label_scene.instantiate()
		
		lbl_inst.set("province_id", d.id)
		lbl_inst.set("je_hlavni", not moc_blizko) 
		lbl_inst.set("is_capital", je_to_capital)
		
		label_container.add_child(lbl_inst)
		
		var l = lbl_inst.get_node("Label")
		if l:
			var zobrazeny_nazev = str(d.province_name).replace(" Voivodeship", "").replace(" County", "")
			
			# 3. SPRÁVNÉ JMÉNO: Pokud je to capital, vezme název z indexu 16
			if je_to_capital:
				var jmeno_mesta = d.get("capital_name", "")
				if jmeno_mesta != "":
					zobrazeny_nazev = "★ " + jmeno_mesta
				else:
					zobrazeny_nazev = "★ " + zobrazeny_nazev # Záloha, kdyby město v TXT chybělo
				
			l.text = zobrazeny_nazev
		
		lbl_inst.position = pozice
		
		if not moc_blizko:
			umistene_pozice.append(pozice)
func get_province_data_by_color(clicked_color: Color):
	var hex = clicked_color.to_html(false)
	
	if color_cache.has(hex):
		return provinces[color_cache[hex]]
		
	var v_clicked = Vector3(clicked_color.r, clicked_color.g, clicked_color.b)
	
	for id in provinces:
		var c = provinces[id]["color"]
		var v_prov = Vector3(c.r, c.g, c.b)
		
		if v_prov.distance_to(v_clicked) < 0.02:
			color_cache[hex] = id
			return provinces[id]
			
	return null

func _na_zmenu_zoomu(aktualni_zoom):
	var labels = get_node_or_null("ProvinceLabels")
	if not labels: return
	
	var odzoomovano = aktualni_zoom <= 0.8
	
	for lbl in labels.get_children():
		if "is_zoomed_out" in lbl:
			lbl.is_zoomed_out = odzoomovano
			lbl.aktualni_zoom = aktualni_zoom # TADY předáváme číslo zoomu
			lbl.reset_stav()
