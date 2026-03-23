extends Node2D

@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")

var provinces = {}
var color_cache = {}

var aktivni_armady = {} 

# --- State variables for army movement targeting ---
var vybrana_armada_od: int = -1
var vybrana_armada_max: int = 0
var ceka_na_cil_presunu: bool = false
var cekajici_presuny = []
# --------------------------------------------------------

func _ready():
	load_provinces()
	print("Nacteno provincii z TXT: ", provinces.size())
	
	var kamera = $Camera2D 
	if kamera:
		kamera.zoom_zmenen.connect(_na_zmenu_zoomu)
	else:
		print("Chyba: Kamera nenalezena!")

	var sprite = $Sprite2D
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod("political", provinces)
	
	generuj_nazvy_provincii()
	
	var labels_manager = get_node_or_null("CountryLabelsManager")
	var prov_labels = get_node_or_null("ProvinceLabels")
	if labels_manager and prov_labels:
		labels_manager.aktualizuj_labely_statu(provinces, prov_labels)
	
	if GameManager.has_method("spocitej_prijem"):
		GameManager.spocitej_prijem(provinces)
		
	aktualizuj_ikony_armad()
	if GameManager.has_signal("kolo_zmeneno"):
		GameManager.kolo_zmeneno.connect(aktualizuj_ikony_armad)

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
		if parts.size() < 19: continue 
			
		var prov_id = int(parts[0])
		
		var pop = 0
		var gdp_val = 0.0
		if parts[12].strip_edges() != "": pop = int(parts[12])
		if parts[13].strip_edges() != "": gdp_val = float(parts[13])
		
		var je_to_hlavni = false
		var nazev_mesta = ""
		if parts[15].strip_edges() == "1":
			je_to_hlavni = true
			nazev_mesta = parts[16].strip_edges()
			
		var neighbors_array = []
		var n_str = parts[17].strip_edges()
		if n_str != "":
			for n in n_str.split(","):
				if n.strip_edges() != "":
					neighbors_array.append(int(n))

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
			"ideology": ideologie_statu,
			"recruitable_population": int(parts[19]),
			"soldiers": int(parts[20]) if parts.size() > 20 else 0
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
		
		var l = lbl_inst.find_child("Label", true, false)
		var f = lbl_inst.find_child("Flag", true, false)
		
		if l:
			var zobrazeny_nazev = str(d.province_name).replace(" Voivodeship", "").replace(" County", "")
			
			if je_to_capital:
				var jmeno_mesta = d.get("capital_name", "")
				if jmeno_mesta != "":
					zobrazeny_nazev = jmeno_mesta
				
				if f:
					f.show()
					var tag = str(d.get("owner", ""))
					var ideologie = str(d.get("ideology", ""))
					
					var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [tag, ideologie]
					var zaklad_cesta = "res://map_data/Flags/%s.svg" % tag
					
					if ideologie != "" and ResourceLoader.exists(ideo_cesta):
						f.texture = load(ideo_cesta)
					elif ResourceLoader.exists(zaklad_cesta):
						f.texture = load(zaklad_cesta)
			else:
				if f:
					f.hide()
				
			l.text = zobrazeny_nazev
			lbl_inst.plny_nazev = zobrazeny_nazev
		
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
	if labels:
		var odzoomovano = aktualni_zoom <= 0.8
		for lbl in labels.get_children():
			if "is_zoomed_out" in lbl:
				lbl.is_zoomed_out = odzoomovano
				lbl.aktualni_zoom = aktualni_zoom
				lbl.reset_stav()
				
	var labels_manager = get_node_or_null("CountryLabelsManager")
	if labels_manager:
		var odzoomovano = aktualni_zoom <= 0.8
		labels_manager.visible = odzoomovano
		
		if odzoomovano:
			var zvetseni = clamp(1.0 / aktualni_zoom, 1.0, 4.0)
			for c_lbl in labels_manager.get_children():
				c_lbl.scale = Vector2(zvetseni, zvetseni)

	_aktualizuj_zoom_armad(aktualni_zoom)

func _formatuj_cislo(cislo: int) -> String:
	if cislo >= 1000000:
		return str(snapped(cislo / 1000000.0, 0.1)) + "M"
	elif cislo >= 1000:
		return str(snapped(cislo / 1000.0, 0.1)) + "k"
	return str(cislo)

func _aktualizuj_zoom_armad(aktualni_zoom: float):
	if aktivni_armady.is_empty(): return
	
	var ZOOM_THRESHOLD_MERGE = 0.6 
	var BASE_ARMY_SCALE = 12.0
	var zvetseni = clamp(1.0 / aktualni_zoom, 0.4, 2.5) 
	var is_merged_mode = aktualni_zoom <= ZOOM_THRESHOLD_MERGE

	if not is_merged_mode:
		for prov_id in aktivni_armady:
			var army_node = aktivni_armady[prov_id]
			army_node.show()
			army_node.scale = Vector2(zvetseni, zvetseni)
			
			var lbl = army_node.get_node_or_null("TroopCount")
			if lbl:
				lbl.text = _formatuj_cislo(int(provinces[prov_id].get("soldiers", 0)))
	else:
		var zkontrolovane = {}
		var clustery = []
		
		for prov_id in aktivni_armady.keys():
			if zkontrolovane.has(prov_id): continue
			
			var cluster = []
			var fronta = [prov_id]
			var owner = str(provinces[prov_id].get("owner", ""))
			
			while fronta.size() > 0:
				var curr_id = fronta.pop_front()
				if zkontrolovane.has(curr_id): continue
				
				zkontrolovane[curr_id] = true
				cluster.append(curr_id)
				
				var sousedi = provinces[curr_id].get("neighbors", [])
				for n_id in sousedi:
					if aktivni_armady.has(n_id) and not zkontrolovane.has(n_id):
						var n_owner = str(provinces[n_id].get("owner", ""))
						if n_owner == owner:
							fronta.append(n_id)
							
			clustery.append(cluster)
			
		for cluster in clustery:
			var leader_id = cluster[0]
			var max_troops = -1
			var total_troops = 0
			
			for c_id in cluster:
				var troops = int(provinces[c_id].get("soldiers", 0))
				total_troops += troops
				if troops > max_troops:
					max_troops = troops
					leader_id = c_id
					
			for c_id in cluster:
				var army_node = aktivni_armady[c_id]
				if c_id == leader_id:
					army_node.show()
					var merge_bonus = 1.0 + (min(cluster.size(), 4) * 0.15) 
					army_node.scale = Vector2(zvetseni, zvetseni) * merge_bonus
					
					var lbl = army_node.get_node_or_null("TroopCount")
					if lbl:
						lbl.text = _formatuj_cislo(total_troops)
				else:
					army_node.hide()

func aktualizuj_ikony_armad():
	var container = get_node_or_null("ArmyContainer")
	if not container:
		container = Node2D.new()
		container.name = "ArmyContainer"
		container.z_index = 20
		add_child(container)
		
	var offset = Vector2.ZERO
	var sprite = $Sprite2D
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position

	for prov_id in provinces.keys():
		var prov_data = provinces[prov_id]
		var vojaci = int(prov_data.get("soldiers", 0))
		var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
		
		if vojaci > 0:
			var icon_path = "res://map_data/ArmyIcons/%s.svg" % owner_tag
			var fallback_path = "res://map_data/ArmyIcons/ArmyIconTemplate.svg"
			var target_texture = load(icon_path) if ResourceLoader.exists(icon_path) else load(fallback_path)
			
			if not aktivni_armady.has(prov_id):
				var army_node = Node2D.new()
				army_node.position = Vector2(prov_data["x"], prov_data["y"]) + offset
				
				var icon = Sprite2D.new()
				icon.name = "Icon"
				icon.texture = target_texture
				
				var tex_size = icon.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					icon.scale = Vector2(24.0 / tex_size.x, 24.0 / tex_size.y)
				
				var lbl = Label.new()
				lbl.name = "TroopCount"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.position = Vector2(-50, 10) 
				lbl.custom_minimum_size = Vector2(100, 20)
				lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				lbl.add_theme_constant_override("outline_size", 4)
				lbl.add_theme_font_size_override("font_size", 14)
				lbl.text = _formatuj_cislo(vojaci)
				
				army_node.add_child(icon)
				army_node.add_child(lbl)
				container.add_child(army_node)
				
				aktivni_armady[prov_id] = army_node
			else:
				var army_node = aktivni_armady[prov_id]
				var icon = army_node.get_node_or_null("Icon")
				if icon and icon.texture != target_texture:
					icon.texture = target_texture
					
				var lbl = army_node.get_node_or_null("TroopCount")
				if lbl:
					lbl.text = _formatuj_cislo(vojaci)
		else:
			if aktivni_armady.has(prov_id):
				aktivni_armady[prov_id].queue_free()
				aktivni_armady.erase(prov_id)
				
	var kamera = $Camera2D
	if kamera:
		_aktualizuj_zoom_armad(kamera.zoom.x)

# --- CORE MOVEMENT LOGIC ---

# Activates target selection mode
func aktivuj_rezim_vyberu_cile(from_id: int, max_troops: int):
	vybrana_armada_od = from_id
	vybrana_armada_max = max_troops
	ceka_na_cil_presunu = true
	print("Klikni na mapu pro vyber cile presunu.")

# Registers the move, deducts troops from source, and shows visual midway "ghost"
func zaregistruj_presun_armady(from_id: int, to_id: int, amount: int):
	if amount <= 0: return
	
	var owner_tag = str(provinces[from_id]["owner"]).strip_edges().to_upper()
	var target_owner_tag = str(provinces[to_id]["owner"]).strip_edges().to_upper()
	
	# Block illegal attacks
	if owner_tag != target_owner_tag and target_owner_tag != "SEA":
		if not GameManager.jsou_ve_valce(owner_tag, target_owner_tag):
			if owner_tag == GameManager.hrac_stat:
				_ukaz_bitevni_popup("NEPOVOLENÝ ÚTOK", "Nemůžeš zaútočit! Nejdřív musíš státu %s vyhlásit válku přes State Overview." % target_owner_tag)
			
			ceka_na_cil_presunu = false
			var root = get_parent()
			if "ceka_na_cil_presunu" in root:
				root.ceka_na_cil_presunu = false
				
			return 
	
	provinces[from_id]["soldiers"] -= amount
	aktualizuj_ikony_armad()
	
	var offset = Vector2.ZERO
	var sprite = $Sprite2D
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position
		
	var start_pos = Vector2(provinces[from_id]["x"], provinces[from_id]["y"]) + offset
	var end_pos = Vector2(provinces[to_id]["x"], provinces[to_id]["y"]) + offset
	var midway_pos = start_pos.lerp(end_pos, 0.5)
	
	var container = get_node_or_null("ArmyContainer")
	var icon_path = "res://map_data/ArmyIcons/%s.svg" % owner_tag
	var fallback_path = "res://map_data/ArmyIcons/ArmyIconTemplate.svg"
	var target_texture = load(icon_path) if ResourceLoader.exists(icon_path) else load(fallback_path)
	
	# --- VISUAL ARROW LOGIC (HOI4 STYLE RED/BLUE) ---
	var moving_node = Node2D.new()
	moving_node.add_to_group("duchove_armad")
	moving_node.z_index = 25 
	
	var is_attack = (owner_tag != target_owner_tag)
	
	# Red for enemy territory, Blue for friendly territory
	var arrow_color = Color(0.85, 0.15, 0.15, 0.7) if is_attack else Color(0.2, 0.6, 0.8, 0.7)
	var head_color = Color(0.9, 0.1, 0.1, 0.9) if is_attack else Color(0.15, 0.5, 0.9, 0.9)
	
	# 1. Draw the Line
	var line = Line2D.new()
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.width = 6.0
	line.default_color = arrow_color
	moving_node.add_child(line)
	
	# 2. Draw the Arrowhead
	var dir = (end_pos - start_pos).normalized()
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-12, -8), Vector2(8, 0), Vector2(-12, 8)])
	arrow.color = head_color
	arrow.position = end_pos - (dir * 15.0)
	arrow.rotation = dir.angle()
	moving_node.add_child(arrow)
	
	# 3. Add the Army Icon and Label in the middle
	var icon_node = Node2D.new()
	icon_node.position = midway_pos
	
	var icon = Sprite2D.new()
	icon.texture = target_texture
	var tex_size = icon.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		icon.scale = Vector2(16.0 / tex_size.x, 16.0 / tex_size.y) 
	icon.modulate.a = 0.95 
	
	var lbl = Label.new()
	lbl.text = _formatuj_cislo(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50, 12) 
	lbl.custom_minimum_size = Vector2(100, 20)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 14)
	
	icon_node.add_child(icon)
	icon_node.add_child(lbl)
	moving_node.add_child(icon_node)
	
	if container:
		container.add_child(moving_node)
	# -------------------------------
	
	cekajici_presuny.append({
		"from": from_id,
		"to": to_id,
		"amount": amount,
		"owner": owner_tag
	})
	
	ceka_na_cil_presunu = false
	var root = get_parent()
	if "ceka_na_cil_presunu" in root:
		root.ceka_na_cil_presunu = false

# Process all movements and await player confirmation for their battles
func zpracuj_tah_armad():
	var hrac = GameManager.hrac_stat
	var tahy_k_zpracovani = cekajici_presuny.duplicate()
	cekajici_presuny.clear()
	
	var celkovy_report = "" 

	# --- NEW: FIELD BATTLES (CROSS-MOVEMENT RESOLUTION) ---
	# Pokud dvě armády táhnou proti sobě, setkají se na půli cesty
	for i in range(tahy_k_zpracovani.size()):
		var utok1 = tahy_k_zpracovani[i]
		if utok1["amount"] <= 0: continue
		
		for j in range(i + 1, tahy_k_zpracovani.size()):
			var utok2 = tahy_k_zpracovani[j]
			if utok2["amount"] <= 0: continue
			
			# Check if they cross paths (A -> B and B -> A)
			if utok1["from"] == utok2["to"] and utok1["to"] == utok2["from"]:
				# Make sure they are enemies
				if utok1["owner"] != utok2["owner"]:
					var hrac_zapojen = (utok1["owner"] == hrac or utok2["owner"] == hrac)
					
					if utok1["amount"] > utok2["amount"]:
						utok1["amount"] -= utok2["amount"]
						utok2["amount"] = 0 # Destroyed
						if hrac_zapojen:
							if utok1["owner"] == hrac:
								celkovy_report += "⚔️ POLNÍ BITVA: Naše armáda smetla nepřátelské síly (%s), které se nás pokusily napadnout během přesunu!\n\n" % utok2["owner"]
							else:
								celkovy_report += "💀 POLNÍ BITVA: Naše útočící armáda byla zničena silnějšími jednotkami nepřítele (%s) na půli cesty!\n\n" % utok1["owner"]
					elif utok2["amount"] > utok1["amount"]:
						utok2["amount"] -= utok1["amount"]
						utok1["amount"] = 0 # Destroyed
						if hrac_zapojen:
							if utok2["owner"] == hrac:
								celkovy_report += "⚔️ POLNÍ BITVA: Naše armáda smetla nepřátelské síly (%s), které se nás pokusily napadnout během přesunu!\n\n" % utok1["owner"]
							else:
								celkovy_report += "💀 POLNÍ BITVA: Naše útočící armáda byla zničena silnějšími jednotkami nepřítele (%s) na půli cesty!\n\n" % utok2["owner"]
						break # utok1 is dead, stop checking it
					else:
						# Mutual annihilation
						utok1["amount"] = 0
						utok2["amount"] = 0
						if hrac_zapojen:
							celkovy_report += "⚔️ POLNÍ BITVA: Krvavý masakr! Naše i nepřátelská armáda se při přesunu navzájem kompletně vyhladily.\n\n"
						break
	# ----------------------------------------------------
	
	# Only process surviving attacks against provinces
	for move in tahy_k_zpracovani:
		if move["amount"] <= 0: continue # Skip destroyed armies
		
		var from_id = move["from"]
		var to_id = move["to"]
		var utocnici = move["amount"]
		var owner = move["owner"]
		
		var target_owner = str(provinces[to_id]["owner"]).strip_edges().to_upper()
		var jmeno_provincie = str(provinces[to_id].get("province_name", "Neznámá provincie"))
		
		var hrac_zapojen = (owner == hrac or target_owner == hrac)
		
		if target_owner == owner or target_owner == "SEA":
			provinces[to_id]["soldiers"] += utocnici
			continue
			
		var obranci = int(provinces[to_id].get("soldiers", 0))
		
		if utocnici > obranci:
			var prezivsi = utocnici - obranci
			provinces[to_id]["soldiers"] = prezivsi
			
			var was_capital = provinces[to_id].get("is_capital", false)
			
			# Update properties for the conquered province
			provinces[to_id]["owner"] = owner
			provinces[to_id]["country_name"] = provinces[from_id]["country_name"]
			provinces[to_id]["ideology"] = provinces[from_id]["ideology"]
			provinces[to_id]["is_capital"] = false 
			
			# Remove flag from map
			var labels = get_node_or_null("ProvinceLabels")
			if labels:
				for lbl in labels.get_children():
					if lbl.get("province_id") == to_id:
						lbl.set("is_capital", false)
						var f = lbl.find_child("Flag", true, false)
						if f: f.hide()
			
			var sprite = $Sprite2D
			if sprite and sprite.has_method("dobyt_provincii"):
				sprite.dobyt_provincii(to_id, owner)
				
			# CAPITULATION MECHANIC (Blitzkrieg)
			if was_capital:
				for p_id in provinces.keys():
					if str(provinces[p_id].get("owner", "")).strip_edges().to_upper() == target_owner:
						provinces[p_id]["owner"] = owner
						provinces[p_id]["country_name"] = provinces[from_id]["country_name"]
						provinces[p_id]["ideology"] = provinces[from_id]["ideology"]
						provinces[p_id]["is_capital"] = false
						if sprite and sprite.has_method("dobyt_provincii"):
							sprite.dobyt_provincii(p_id, owner)
							
				if hrac_zapojen:
					celkovy_report += "💥 KAPITULACE: Padlo hlavní město! Stát %s se kompletně vzdal a jeho území připadlo státu %s!\n\n" % [target_owner, owner]
			
			if hrac_zapojen and not was_capital:
				if owner == hrac:
					celkovy_report += "✅ VÍTĚZSTVÍ: Dobyli jsme %s! Přežilo %d našich vojáků.\n\n" % [jmeno_provincie, prezivsi]
				else:
					celkovy_report += "💀 ZTRÁTA ÚZEMÍ: Nepřítel (%s) dobyl provincii %s! Padli všichni obránci.\n\n" % [owner, jmeno_provincie]
					
		else:
			var prezivsi = obranci - utocnici
			provinces[to_id]["soldiers"] = prezivsi
			
			if hrac_zapojen:
				if target_owner == hrac:
					celkovy_report += "🛡️ OBRANA: Ubránili jsme %s! Zbylo nám %d vojáků.\n\n" % [jmeno_provincie, prezivsi]
				else:
					celkovy_report += "❌ ÚTOK SELHAL: Naše invaze do %s byla odražena.\n\n" % [jmeno_provincie]
					
	aktualizuj_ikony_armad()
	
	if celkovy_report != "":
		await _ukaz_bitevni_popup("Hlášení z fronty", celkovy_report)
		
	get_tree().call_group("duchove_armad", "queue_free")

func _ukaz_bitevni_popup(titulek: String, text: String):
	var dialog = AcceptDialog.new()
	dialog.title = titulek
	dialog.dialog_text = text
	dialog.min_size = Vector2i(450, 250) 
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	
	var zavreno = false
	var on_close = func(): zavreno = true
	
	dialog.confirmed.connect(on_close)
	dialog.canceled.connect(on_close)
	
	while is_instance_valid(dialog) and dialog.visible:
		await get_tree().process_frame
		
	if is_instance_valid(dialog):
		dialog.queue_free()
