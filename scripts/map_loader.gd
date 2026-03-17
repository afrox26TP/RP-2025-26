extends Node2D

@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")
# ZMĚNA: Smazáno slovo @export, aby se cesta k souboru napevno vynutila
var country_label_scene = preload("res://scenes/CountryLabel.tscn") 

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
	
	# ZMĚNA: TADY TO CHYBĚLO! Musíme Godotu říct, ať ty státy opravdu vygeneruje
	generuj_nazvy_statu() 
	
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
		# ZMĚNA: Teď vyžadujeme 19 sloupců kvůli ideologii
		if parts.size() < 19: continue 
			
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

		# NOVÉ: Načtení ideologie (sloupec 18)
		var ideologie_statu = parts[18].strip_edges().to_lower()
		
		provinces[prov_id] = {
			"id": prov_id,
			"color": Color8(int(parts[1]), int(parts[2]), int(parts[3])),
			"type": parts[4],
			"state": parts[5],
			"owner": parts[6],
			"x": float(parts[8]), 
			"y": float(parts[9]), 
			"province_name": parts[10],
			"country_name": parts[11].strip_edges(), 
			"population": pop,
			"gdp": gdp_val,
			"is_capital": je_to_hlavni,
			"capital_name": nazev_mesta,
			"neighbors": neighbors_array,
			"ideology": ideologie_statu, # Tady nezapomeň na čárku!
			"recruitable_population": int(parts[19]) # PŘIDÁNO TADY
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
			
			if je_to_capital:
				var jmeno_mesta = d.get("capital_name", "")
				if jmeno_mesta != "":
					zobrazeny_nazev = "★ " + jmeno_mesta
				else:
					zobrazeny_nazev = "★ " + zobrazeny_nazev
				
			l.text = zobrazeny_nazev
			lbl_inst.plny_nazev = zobrazeny_nazev # <--- PŘIDEJ TENTO ŘÁDEK
		
		lbl_inst.position = pozice
		
		if not moc_blizko:
			umistene_pozice.append(pozice)

func generuj_nazvy_statu():
	var country_container = Node2D.new()
	country_container.name = "CountryLabels"
	add_child(country_container)
	country_container.visible = false # Skryté při startu

	var sprite = $Sprite2D
	var offset = Vector2.ZERO
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position

	var staty_kandidati = {}
	var pozice_hlavnich_mest = {} 
	var staty_hranice = {} 
	
	# Státy natvrdo přilepené na hlavní město nebo střed
	var na_hlavni_mesto = ["ESP", "NOR", "RUS", "TUR"]
	var na_geometricky_stred = ["DEU"] 
	
	# Ruční posuny
	var rucni_posun = {
		"HRV": Vector2(30, 20),
		"MNE": Vector2(-25, 15),
		"KOS": Vector2(15, 0),
		"BIH": Vector2(-25, -10),
		"SRB": Vector2(25, 15),
		"NOR": Vector2(-40, -40) # TADY JE ZMĚNA: -40 = doleva, druhé -40 = nahoru
	}

	for p in provinces.values():
		var majitel = str(p.get("owner", ""))
		var px = float(p.get("x", 0))
		var py = float(p.get("y", 0))

		if majitel == "SEA" or majitel == "" or (px == 0.0 and py == 0.0): 
			continue

		if p.get("is_capital", false):
			pozice_hlavnich_mest[majitel] = Vector2(px, py)

		var stejni_sousede = 0
		var sousede_pole = p.get("neighbors", [])
		for s_id in sousede_pole:
			if provinces.has(s_id) and str(provinces[s_id].get("owner", "")) == majitel:
				stejni_sousede += 1

		if not staty_kandidati.has(majitel):
			staty_kandidati[majitel] = []
			staty_hranice[majitel] = {"min_x": px, "max_x": px, "min_y": py, "max_y": py}
		else:
			var h = staty_hranice[majitel]
			if px < h["min_x"]: h["min_x"] = px
			if px > h["max_x"]: h["max_x"] = px
			if py < h["min_y"]: h["min_y"] = py
			if py > h["max_y"]: h["max_y"] = py

		staty_kandidati[majitel].append({
			"pos": Vector2(px, py),
			"score": stejni_sousede,
			"name": p.get("country_name", majitel)
		})

	for majitel in staty_kandidati:
		var provincie_statu = staty_kandidati[majitel]
		var stred_statu = Vector2.ZERO
		var nazev_statu = majitel
		
		# Vyhodnocení pozice
		if majitel in na_hlavni_mesto:
			if pozice_hlavnich_mest.has(majitel):
				stred_statu = pozice_hlavnich_mest[majitel] 
				nazev_statu = provincie_statu[0]["name"]
			else:
				stred_statu = provincie_statu[0]["pos"]
		elif majitel in na_geometricky_stred:
			var h = staty_hranice[majitel]
			stred_statu = Vector2((h["min_x"] + h["max_x"]) / 2.0, (h["min_y"] + h["max_y"]) / 2.0)
			nazev_statu = provincie_statu[0]["name"]
		else:
			var max_score = -1
			for prov in provincie_statu:
				if prov["score"] > max_score:
					max_score = prov["score"]
					
			var sum_pos = Vector2.ZERO
			var count = 0
			
			for prov in provincie_statu:
				if prov["score"] == max_score:
					sum_pos += prov["pos"]
					count += 1
					nazev_statu = prov["name"]
					
			stred_statu = sum_pos / float(count)
			
		# Aplikování ručního posunu
		if rucni_posun.has(majitel):
			stred_statu += rucni_posun[majitel]
			
		var lbl_inst = country_label_scene.instantiate()
		country_container.add_child(lbl_inst)
		
		var l = lbl_inst.get_node_or_null("Label")
		if l:
			var zobrazeny_nazev = str(nazev_statu).to_upper()
			
			if zobrazeny_nazev == "BOSNIA AND HERZEGOVINA": zobrazeny_nazev = "BOSNIA & HERZ."
			if zobrazeny_nazev == "CZECH REPUBLIC": zobrazeny_nazev = "CZECHIA"
			if zobrazeny_nazev == "REPUBLIC OF SERBIA": zobrazeny_nazev = "SERBIA"
			
			l.text = zobrazeny_nazev 
			
		lbl_inst.position = stred_statu + offset
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
	if labels:
		var odzoomovano = aktualni_zoom <= 0.8
		for lbl in labels.get_children():
			if "is_zoomed_out" in lbl:
				lbl.is_zoomed_out = odzoomovano
				lbl.aktualni_zoom = aktualni_zoom
				lbl.reset_stav()
				
	# --- NOVÁ ČÁST PRO STÁTY ---
	var country_labels = get_node_or_null("CountryLabels")
	if country_labels:
		var odzoomovano = aktualni_zoom <= 0.8
		country_labels.visible = odzoomovano # Ukážou se jen z dálky
		
		if odzoomovano:
			# Zvětšování států, aby z dálky nekřičely, ale rostly s oddalováním
			var zvetseni = clamp(1.0 / aktualni_zoom, 1.0, 4.0)
			for c_lbl in country_labels.get_children():
				c_lbl.scale = Vector2(zvetseni, zvetseni)
