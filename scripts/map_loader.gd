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
		
	file.get_line()
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
			
		var parts = line.split(";")
		if parts.size() < 11: continue 
			
		var prov_id = int(parts[0])
		
		var pop = 0
		var gdp_val = 0.0
		if parts.size() > 12: pop = int(parts[12])
		if parts.size() > 13: gdp_val = float(parts[13])
		
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
			"gdp": gdp_val
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

	# 1. Seřadíme provincie podle populace, aby ty největší dostaly přednost
	var serazene_provinci = provinces.values()
	serazene_provinci.sort_custom(func(a, b): return a.get("population", 0) > b.get("population", 0))

	var umistene_pozice = []
	var MIN_VZDALENOST = 60.0 # <-- TADY NASTAVUJEŠ, JAK MOC OD SEBE MUSÍ TEXTY BÝT (v pixelech)

	for d in serazene_provinci:
		if str(d.get("owner", "")) == "SEA" or str(d.get("province_name", "")) == "":
			continue
			
		var pozice = Vector2(d.get("x", 0), d.get("y", 0)) + offset
		
		# 2. Zkontrolujeme, jestli už není v okolí jiný text
		var moc_blizko = false
		for p in umistene_pozice:
			if pozice.distance_to(p) < MIN_VZDALENOST:
				moc_blizko = true
				break
				
		# Pokud je moc blízko jiné (lidnatější) provincie, text vůbec nevytvoříme
		if moc_blizko:
			continue
			
		var lbl_inst = label_scene.instantiate()
		
		# 1. NEJDŘÍV nastavujeme proměnné!
		lbl_inst.set("province_id", d.id)
		lbl_inst.set("je_hlavni", not moc_blizko) 
		
		# 2. AŽ PAK ho přidáváme do scény!
		label_container.add_child(lbl_inst)
		
		var l = lbl_inst.get_node("Label")
		if l:
			var cisty_nazev = str(d.province_name).replace(" Voivodeship", "").replace(" County", "")
			l.text = cisty_nazev
		
		lbl_inst.position = pozice
		
		# Uložíme si pozici tohoto textu, aby se mu ostatní vyhýbaly
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
	
	# texty se ukazi, pokud je zoom vetsi nez 0.8
	var zobrazit_texty = aktualni_zoom > 0.8
	
	for lbl in labels.get_children():
		lbl.visible = zobrazit_texty
