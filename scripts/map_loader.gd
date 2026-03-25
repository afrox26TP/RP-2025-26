extends Node2D

@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")

var provinces = {}
var color_cache = {}
var army_icon_texture_cache: Dictionary = {}
var flag_texture_cache: Dictionary = {}

var aktivni_armady = {} 

# --- State variables for army movement targeting ---
var vybrana_armada_od: int = -1
var vybrana_armada_max: int = 0
var ceka_na_cil_presunu: bool = false
var cekajici_presuny = []
var obsazene_pozice_presunu: Array = []
var trasy_lane_counter: Dictionary = {}
var _bitevni_kamera_aktivni: bool = false
var _bitevni_puvodni_pozice: Vector2 = Vector2.ZERO
var _bitevni_puvodni_zoom: Vector2 = Vector2.ONE
# --------------------------------------------------------

func _ziskej_map_offset() -> Vector2:
	var sprite = $Sprite2D
	if sprite and sprite.centered:
		return sprite.position - (sprite.texture.get_size() / 2.0)
	if sprite:
		return sprite.position
	return Vector2.ZERO

func _ziskej_lane_index(slot: int) -> int:
	if slot <= 0:
		return 0
	var magnitude = int((slot + 1) / 2)
	return magnitude if slot % 2 == 1 else -magnitude

func _vypocitej_ofset_trasy(from_id: int, to_id: int, start_pos: Vector2, end_pos: Vector2) -> Vector2:
	var a = min(from_id, to_id)
	var b = max(from_id, to_id)
	var key = "%d_%d" % [a, b]
	var slot = int(trasy_lane_counter.get(key, 0))
	trasy_lane_counter[key] = slot + 1

	if slot == 0:
		return Vector2.ZERO

	var dir = end_pos - start_pos
	if dir.length() < 0.001:
		return Vector2.ZERO

	var lane_index = _ziskej_lane_index(slot)
	return dir.normalized().orthogonal() * (12.0 * float(lane_index))

func _najdi_volnou_pozici(base_pos: Vector2, occupied_positions: Array, min_distance: float) -> Vector2:
	if occupied_positions.is_empty():
		return base_pos

	var offsets = [
		Vector2.ZERO,
		Vector2(18, 0), Vector2(-18, 0), Vector2(0, 18), Vector2(0, -18),
		Vector2(14, 14), Vector2(-14, 14), Vector2(14, -14), Vector2(-14, -14),
		Vector2(28, 0), Vector2(-28, 0), Vector2(0, 28), Vector2(0, -28),
		Vector2(24, 16), Vector2(-24, 16), Vector2(24, -16), Vector2(-24, -16),
		Vector2(36, 0), Vector2(-36, 0), Vector2(0, 36), Vector2(0, -36)
	]

	for off in offsets:
		var candidate = base_pos + off
		var blocked = false
		for p in occupied_positions:
			if candidate.distance_to(p) < min_distance:
				blocked = true
				break
		if not blocked:
			return candidate

	return base_pos + Vector2(42, 0)

func _ziskej_obsazene_pozice_armad() -> Array:
	var occupied: Array = []
	for prov_id in aktivni_armady.keys():
		var army_node = aktivni_armady[prov_id]
		if army_node and army_node.visible:
			occupied.append(army_node.position)
	return occupied

func _rozmisti_armady_bez_overlapu():
	if aktivni_armady.is_empty():
		return

	var occupied: Array = []
	var sorted_ids: Array = aktivni_armady.keys()
	sorted_ids.sort_custom(func(a, b):
		return int(provinces[a].get("soldiers", 0)) > int(provinces[b].get("soldiers", 0))
	)

	for prov_id in sorted_ids:
		var army_node = aktivni_armady[prov_id]
		if not army_node or not army_node.visible:
			continue

		if not army_node.has_meta("base_pos"):
			continue

		var base_pos = army_node.get_meta("base_pos") as Vector2
		var final_pos = _najdi_volnou_pozici(base_pos, occupied, 24.0)
		army_node.position = final_pos
		occupied.append(final_pos)

func _get_cached_texture(path: String, cache: Dictionary):
	if path == "":
		return null
	if cache.has(path):
		return cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	cache[path] = tex
	return tex

func _get_flag_texture(tag: String, ideology: String):
	var ideologie = ideology.strip_edges().to_lower()
	var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [tag, ideologie]
	var zaklad_cesta = "res://map_data/Flags/%s.svg" % tag

	if ideologie != "":
		var ideo_tex = _get_cached_texture(ideo_cesta, flag_texture_cache)
		if ideo_tex:
			return ideo_tex

	return _get_cached_texture(zaklad_cesta, flag_texture_cache)

func _get_army_icon_texture(owner_tag: String):
	var icon_path = "res://map_data/ArmyIcons/%s.svg" % owner_tag
	var fallback_path = "res://map_data/ArmyIcons/ArmyIconTemplate.svg"
	var icon_tex = _get_cached_texture(icon_path, army_icon_texture_cache)
	if icon_tex:
		return icon_tex
	return _get_cached_texture(fallback_path, army_icon_texture_cache)

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
		if parts.size() < 20: continue 
			
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
			"core_owner": parts[6],
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
					f.texture = _get_flag_texture(tag, ideologie)
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
	_aktualizuj_indikatory_kapitulace()

func _formatuj_cislo(cislo: int) -> String:
	if cislo >= 1000000:
		return str(snapped(cislo / 1000000.0, 0.1)) + "M"
	elif cislo >= 1000:
		return str(snapped(cislo / 1000.0, 0.1)) + "k"
	return str(cislo)

func _aktualizuj_zoom_armad(aktualni_zoom: float):
	if aktivni_armady.is_empty(): return
	
	var ZOOM_THRESHOLD_MERGE = 0.6 
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
		_rozmisti_armady_bez_overlapu()
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
		
	var offset = _ziskej_map_offset()

	for prov_id in provinces.keys():
		var prov_data = provinces[prov_id]
		var vojaci = int(prov_data.get("soldiers", 0))
		var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
		var base_pos = Vector2(prov_data["x"], prov_data["y"]) + offset
		
		if vojaci > 0:
			var target_texture = _get_army_icon_texture(owner_tag)
			
			if not aktivni_armady.has(prov_id):
				var army_node = Node2D.new()
				army_node.position = base_pos
				army_node.set_meta("base_pos", base_pos)
				
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
				army_node.set_meta("base_pos", base_pos)
				army_node.position = base_pos
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
	_aktualizuj_indikatory_kapitulace()

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
	
	var offset = _ziskej_map_offset()
		
	var start_pos = Vector2(provinces[from_id]["x"], provinces[from_id]["y"]) + offset
	var end_pos = Vector2(provinces[to_id]["x"], provinces[to_id]["y"]) + offset
	var lane_offset = _vypocitej_ofset_trasy(from_id, to_id, start_pos, end_pos)
	start_pos += lane_offset
	end_pos += lane_offset
	var midway_pos = start_pos.lerp(end_pos, 0.5)
	
	var container = get_node_or_null("ArmyContainer")
	var target_texture = _get_army_icon_texture(owner_tag)
	
	# --- VISUAL ARROW LOGIC (enhanced readability) ---
	var moving_node = Node2D.new()
	moving_node.add_to_group("duchove_armad")
	moving_node.z_index = 25 
	
	var is_attack = (owner_tag != target_owner_tag)
	
	# Clean contrast: warm red for attacks, cool blue for non-attack moves.
	var arrow_color = Color(0.88, 0.25, 0.22, 0.9) if is_attack else Color(0.16, 0.68, 0.92, 0.9)
	var glow_color = Color(0.96, 0.38, 0.32, 0.22) if is_attack else Color(0.35, 0.85, 0.98, 0.22)
	var head_color = Color(0.95, 0.15, 0.12, 0.98) if is_attack else Color(0.07, 0.56, 0.95, 0.98)
	
	# 1) Thin glow underlay.
	var glow_line = Line2D.new()
	glow_line.add_point(start_pos)
	glow_line.add_point(end_pos)
	glow_line.width = 4.0
	glow_line.default_color = glow_color
	glow_line.antialiased = true
	moving_node.add_child(glow_line)

	# 2) Main line.
	var line = Line2D.new()
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.width = 2.1
	line.default_color = arrow_color
	line.antialiased = true
	moving_node.add_child(line)

	# 3) Subtle center accent only for attacks.
	if is_attack:
		var accent = Line2D.new()
		accent.add_point(start_pos)
		accent.add_point(end_pos)
		accent.width = 0.8
		accent.default_color = Color(1.0, 0.78, 0.7, 0.82)
		accent.antialiased = true
		moving_node.add_child(accent)
	
	# 4) Arrowhead.
	var dir = (end_pos - start_pos).normalized()
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-8, -5), Vector2(7, 0), Vector2(-8, 5)])
	arrow.color = head_color
	arrow.position = end_pos - (dir * 10.0)
	arrow.rotation = dir.angle()
	moving_node.add_child(arrow)
	
	# 5) Army icon + amount at midpoint.
	var icon_node = Node2D.new()
	var occupied_positions = _ziskej_obsazene_pozice_armad()
	for p in obsazene_pozice_presunu:
		occupied_positions.append(p)
	icon_node.position = _najdi_volnou_pozici(midway_pos, occupied_positions, 30.0)
	obsazene_pozice_presunu.append(icon_node.position)

	var icon = Sprite2D.new()
	icon.texture = target_texture
	var tex_size = icon.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		icon.scale = Vector2(15.0 / tex_size.x, 15.0 / tex_size.y)
	icon.position = Vector2(0, -6)
	icon.modulate.a = 0.95
	
	var lbl = Label.new()
	lbl.text = _formatuj_cislo(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-36, 4)
	lbl.custom_minimum_size = Vector2(72, 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 12)
	
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
	var bitevni_udalosti: Array = []

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
								bitevni_udalosti.append({
									"title": "Polní bitva",
									"text": "⚔️ Naše armáda smetla nepřátelské síly (%s) během přesunu." % utok2["owner"],
									"province_id": int(utok1["to"])
								})
							else:
								bitevni_udalosti.append({
									"title": "Polní bitva",
									"text": "💀 Naše útočící armáda byla zničena silnějšími jednotkami nepřítele (%s)." % utok1["owner"],
									"province_id": int(utok2["to"])
								})
					elif utok2["amount"] > utok1["amount"]:
						utok2["amount"] -= utok1["amount"]
						utok1["amount"] = 0 # Destroyed
						if hrac_zapojen:
							if utok2["owner"] == hrac:
								bitevni_udalosti.append({
									"title": "Polní bitva",
									"text": "⚔️ Naše armáda smetla nepřátelské síly (%s) během přesunu." % utok1["owner"],
									"province_id": int(utok2["to"])
								})
							else:
								bitevni_udalosti.append({
									"title": "Polní bitva",
									"text": "💀 Naše útočící armáda byla zničena silnějšími jednotkami nepřítele (%s)." % utok2["owner"],
									"province_id": int(utok1["to"])
								})
						break # utok1 is dead, stop checking it
					else:
						# Mutual annihilation
						utok1["amount"] = 0
						utok2["amount"] = 0
						if hrac_zapojen:
							bitevni_udalosti.append({
								"title": "Polní bitva",
								"text": "⚔️ Krvavý masakr: naše i nepřátelská armáda se při přesunu navzájem vyhladily.",
								"province_id": int(utok1["to"])
							})
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
			# core_owner remains unchanged so occupied territory can be distinguished from core territory.
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
				
			# Delayed capitulation: state capitulates only if attacker keeps capital for a full turn.
			if was_capital:
				GameManager.zaregistruj_obsazeni_hlavniho_mesta(target_owner, owner, to_id)
				if hrac_zapojen:
					bitevni_udalosti.append({
						"title": "Hlavní město obsazeno",
						"text": "🏛️ %s dobylo hlavní město státu %s. Kapitulace nastane jen pokud město udrží celé jedno kolo." % [owner, target_owner],
						"province_id": to_id
					})
			
			if hrac_zapojen and not was_capital:
				if owner == hrac:
					bitevni_udalosti.append({
						"title": "Vítězství",
						"text": "✅ Dobyli jsme %s. Přežilo %d našich vojáků." % [jmeno_provincie, prezivsi],
						"province_id": to_id
					})
				else:
					bitevni_udalosti.append({
						"title": "Ztráta území",
						"text": "💀 Nepřítel (%s) dobyl provincii %s. Padli všichni obránci." % [owner, jmeno_provincie],
						"province_id": to_id
					})
					
		else:
			var prezivsi = obranci - utocnici
			provinces[to_id]["soldiers"] = prezivsi
			
			if hrac_zapojen:
				if target_owner == hrac:
					bitevni_udalosti.append({
						"title": "Obrana",
						"text": "🛡️ Ubránili jsme %s. Zbylo nám %d vojáků." % [jmeno_provincie, prezivsi],
						"province_id": to_id
					})
				else:
					bitevni_udalosti.append({
						"title": "Útok selhal",
						"text": "❌ Naše invaze do %s byla odražena." % [jmeno_provincie],
						"province_id": to_id
					})
					
	celkovy_report = _zpracuj_odlozene_kapitulace(celkovy_report)
	aktualizuj_ikony_armad()

	if not bitevni_udalosti.is_empty():
		_zacni_bitevni_kameru()
	for udalost in bitevni_udalosti:
		await _ukaz_bitevni_popup_na_provincii(
			str(udalost.get("title", "Bitva")),
			str(udalost.get("text", "")),
			int(udalost.get("province_id", -1))
		)
	if not bitevni_udalosti.is_empty():
		await _obnov_bitevni_kameru()
	
	if celkovy_report != "":
		await _ukaz_bitevni_popup("Hlášení z fronty", celkovy_report)
		
	get_tree().call_group("duchove_armad", "queue_free")
	obsazene_pozice_presunu.clear()
	trasy_lane_counter.clear()

func _ukaz_bitevni_popup(titulek: String, text: String):
	var dialog = AcceptDialog.new()
	dialog.title = titulek
	dialog.dialog_text = text
	dialog.min_size = Vector2i(360, 170)
	dialog.size = Vector2i(360, 170)
	dialog.unresizable = true
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup()

	# Place compact battle popups at top-center, just below TopBar.
	var viewport_size = get_viewport_rect().size
	var top_margin = 10
	var topbar = get_tree().current_scene.find_child("TopBar", true, false)
	if topbar and topbar is Control:
		top_margin = int((topbar as Control).size.y) + 8

	var popup_pos = Vector2i(
		int((viewport_size.x - dialog.size.x) * 0.5),
		top_margin
	)
	dialog.position = popup_pos
	
	var zavreno = false
	var on_close = func(): zavreno = true
	
	dialog.confirmed.connect(on_close)
	dialog.canceled.connect(on_close)
	
	while is_instance_valid(dialog) and dialog.visible:
		await get_tree().process_frame
		
	if is_instance_valid(dialog):
		dialog.queue_free()

func _zacni_bitevni_kameru():
	var kamera = $Camera2D
	if not kamera:
		return
	if _bitevni_kamera_aktivni:
		return
	_bitevni_puvodni_pozice = kamera.position
	_bitevni_puvodni_zoom = kamera.zoom
	_bitevni_kamera_aktivni = true

func _obnov_bitevni_kameru():
	if not _bitevni_kamera_aktivni:
		return
	var kamera = $Camera2D
	if not kamera:
		_bitevni_kamera_aktivni = false
		return

	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(kamera, "position", _bitevni_puvodni_pozice, 0.38)
	t.parallel().tween_property(kamera, "zoom", _bitevni_puvodni_zoom, 0.38)
	await t.finished
	if kamera.has_signal("zoom_zmenen"):
		kamera.emit_signal("zoom_zmenen", kamera.zoom.x)
	_bitevni_kamera_aktivni = false

func _ukaz_bitevni_popup_na_provincii(titulek: String, text: String, province_id: int):
	var kamera = $Camera2D
	if not kamera or not provinces.has(province_id):
		await _ukaz_bitevni_popup(titulek, text)
		return

	var cilova_pozice = Vector2(provinces[province_id]["x"], provinces[province_id]["y"]) + _ziskej_map_offset()
	var current_zoom_hod = kamera.zoom.x
	var cilovy_zoom_hod = clamp(lerpf(current_zoom_hod, 0.72, 0.45), 0.62, current_zoom_hod)
	var cilovy_zoom = Vector2(cilovy_zoom_hod, cilovy_zoom_hod)
	var vzdalenost = kamera.position.distance_to(cilova_pozice)
	var delka_preletu = clamp(vzdalenost / 1600.0, 0.18, 0.55)

	var t1 = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(kamera, "position", cilova_pozice, delka_preletu)
	t1.parallel().tween_property(kamera, "zoom", cilovy_zoom, delka_preletu)
	await t1.finished
	if kamera.has_signal("zoom_zmenen"):
		kamera.emit_signal("zoom_zmenen", kamera.zoom.x)

	await _ukaz_bitevni_popup(titulek, text)

func _zpracuj_odlozene_kapitulace(celkovy_report: String) -> String:
	var hotove_kapitulace = GameManager.vyhodnot_odlozene_kapitulace()
	if hotove_kapitulace.is_empty():
		return celkovy_report

	var hrac = GameManager.hrac_stat
	var sprite = $Sprite2D

	for zaznam in hotove_kapitulace:
		var target_owner = str(zaznam.get("obrance", "")).strip_edges().to_upper()
		var owner = str(zaznam.get("utocnik", "")).strip_edges().to_upper()
		if target_owner == "" or owner == "" or target_owner == owner:
			continue

		var source_country_name = owner
		var source_ideology = ""
		for p_id in provinces.keys():
			if str(provinces[p_id].get("owner", "")).strip_edges().to_upper() == owner:
				source_country_name = str(provinces[p_id].get("country_name", owner))
				source_ideology = str(provinces[p_id].get("ideology", ""))
				break

		var prevedeno = 0
		for p_id in provinces.keys():
			if str(provinces[p_id].get("owner", "")).strip_edges().to_upper() == target_owner:
				provinces[p_id]["owner"] = owner
				provinces[p_id]["core_owner"] = owner
				provinces[p_id]["country_name"] = source_country_name
				provinces[p_id]["ideology"] = source_ideology
				provinces[p_id]["is_capital"] = false
				if sprite and sprite.has_method("dobyt_provincii"):
					sprite.dobyt_provincii(p_id, owner)
				prevedeno += 1

		# Remove occupation hatching only on the capitulated country's former core,
		# and only for the winner that forced capitulation.
		for p_id in provinces.keys():
			var p_core_owner = str(provinces[p_id].get("core_owner", "")).strip_edges().to_upper()
			var p_owner = str(provinces[p_id].get("owner", "")).strip_edges().to_upper()
			if p_core_owner == target_owner and p_owner == owner:
				provinces[p_id]["core_owner"] = owner

		if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
			sprite.aktualizuj_mapovy_mod("political", provinces)

		if prevedeno > 0 and (owner == hrac or target_owner == hrac):
			celkovy_report += "💥 KAPITULACE: %s udrželo hlavní město státu %s celé jedno kolo. Stát %s kapituloval.\n\n" % [owner, target_owner, target_owner]

	return celkovy_report

func _aktualizuj_indikatory_kapitulace():
	var container = get_node_or_null("CapitulationIndicators")
	if not container:
		container = Node2D.new()
		container.name = "CapitulationIndicators"
		container.z_index = 30
		add_child(container)

	for child in container.get_children():
		child.queue_free()

	if not GameManager.has_method("vyhodnot_odlozene_kapitulace"):
		return
	if not ("cekajici_kapitulace" in GameManager):
		return

	var offset = _ziskej_map_offset()
	for zaznam in GameManager.cekajici_kapitulace:
		var capital_id = int(zaznam.get("capital_id", -1))
		if not provinces.has(capital_id):
			continue

		var utocnik = str(zaznam.get("utocnik", "")).strip_edges().to_upper()
		var obrance = str(zaznam.get("obrance", "")).strip_edges().to_upper()
		if utocnik == "" or obrance == "":
			continue

		var owner_now = str(provinces[capital_id].get("owner", "")).strip_edges().to_upper()
		if owner_now != utocnik:
			continue

		var capture_turn = int(zaznam.get("capture_turn", GameManager.aktualni_kolo))
		var remain = max(0, (capture_turn + 1) - int(GameManager.aktualni_kolo))

		var node = Node2D.new()
		node.position = Vector2(provinces[capital_id]["x"], provinces[capital_id]["y"]) + offset + Vector2(0, -44)

		var bg = ColorRect.new()
		bg.size = Vector2(170, 30)
		bg.position = Vector2(-85, -15)
		bg.color = Color(0.38, 0.08, 0.08, 0.72)
		node.add_child(bg)

		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(170, 26)
		lbl.position = Vector2(-85, -13)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = "%s drzi cap (%s): %d kolo" % [utocnik, obrance, max(1, remain)]
		node.add_child(lbl)

		container.add_child(node)
