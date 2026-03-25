extends Sprite2D

@export var logic_map: Texture2D
var map_image: Image

var data_image: Image
var data_texture: ImageTexture
var occupation_image: Image
var occupation_texture: ImageTexture
var total_provinces: int = 5000

# Variable to track the last hovered province ID for label popping
var _posledni_hover_id: int = -1

var country_colors = {
	"ALB": Color("#D13A3A"), "AND": Color("#1A409A"), "AUT": Color("#FFFFFF"),
	"BLR": Color("#8CA35E"), "BEL": Color("#D4B04C"), "BIH": Color("#456285"),
	"BGR": Color("#426145"), "HRV": Color("#5C7691"), "CYP": Color("#E3A336"),
	"CZE": Color("#D49035"), "DNK": Color("#9E333D"), "EST": Color("#266E73"),
	"FIN": Color("#96B6D1"), "FRA": Color("#2944A6"), "DEU": Color("#666666"),
	"GRC": Color("#5CA1D6"), "HUN": Color("#A35A47"), "ISL": Color("#88ADC9"),
	"IRL": Color("#388F4F"), "ITA": Color("#408F45"), "KOS": Color("#454B87"),
	"GEO": Color("#D48035"), "LVA": Color("#85616D"), "LIE": Color("#314C7D"),
	"LTU": Color("#A6A34E"), "LUX": Color("#8FA9D4"), "MLT": Color("#D95959"),
	"MDA": Color("#D4A94C"), "MCO": Color("#D63636"), "MNE": Color("#3D7873"),
	"NLD": Color("#D97529"), "MKD": Color("#D14532"), "NOR": Color("#6E88A1"),
	"POL": Color("#C44D64"), "PRT": Color("#2A7A38"), "ROU": Color("#C9A936"),
	"RUS": Color("#316E40"), "SMR": Color("#7BA1C7"), "SRB": Color("#B8939D"),
	"SVK": Color("#3A5B8C"), "SVN": Color("#4E8272"), "ESP": Color("#D4BC2C"),
	"SWE": Color("#286C9E"), "CHE": Color("#AD2A2A"), "TUR": Color("#3A8C67"),
	"UKR": Color("#DEC243"), "GBR": Color("#9E2633"), "SEA": Color("5b556fff")
}

func _barva_politickeho_vlastnictvi(d: Dictionary) -> Color:
	var owner = str(d.get("owner", "")).strip_edges().to_upper()
	var base = country_colors.get(owner, Color.from_hsv(owner.hash() / float(0x7FFFFFFF), 0.7, 0.8))
	base.a = 1.0

	# Occupied (non-core) territory is visually muted to separate it from core land.
	var core_owner = str(d.get("core_owner", owner)).strip_edges().to_upper()
	if core_owner != "" and owner != core_owner:
		base = base.lerp(Color(0.92, 0.92, 0.92, 1.0), 0.08)

	return base

func _ready():
	if logic_map:
		map_image = logic_map.get_image()
	else:
		push_error("Chybi Logic Map!")
	
	data_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	data_image.fill(Color.TRANSPARENT)
	data_texture = ImageTexture.create_from_image(data_image)

	occupation_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	occupation_image.fill(Color(0, 0, 0, 0))
	occupation_texture = ImageTexture.create_from_image(occupation_image)
	
	material.set_shader_parameter("data_texture", data_texture)
	material.set_shader_parameter("occupation_texture", occupation_texture)
	material.set_shader_parameter("total_provinces", float(total_provinces))
	
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("hovered_id", -1.0)
	material.set_shader_parameter("selected_id", -1.0)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_zpracuj_interakci(event.position, false)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_zpracuj_interakci(event.position, true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_odzanc_vse()
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		var root = get_parent()
		if "provinces" in root:
			if event.keycode == KEY_1:
				aktualizuj_mapovy_mod("political", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("political")
			elif event.keycode == KEY_2:
				aktualizuj_mapovy_mod("population", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("population")
			elif event.keycode == KEY_3:
				aktualizuj_mapovy_mod("gdp", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("gdp")
			elif event.keycode == KEY_4:
				aktualizuj_mapovy_mod("ideology", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("ideology")
			elif event.keycode == KEY_5:
				aktualizuj_mapovy_mod("recruitable_population", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("recruitable_population")
			elif event.keycode == KEY_6:
				aktualizuj_mapovy_mod("relationships", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("relationships")
			
			elif event.keycode == KEY_C:
				var vybrana_provincie = material.get_shader_parameter("selected_id")
				if vybrana_provincie != null and float(vybrana_provincie) >= 0.0:
					dobyt_provincii(int(vybrana_provincie), GameManager.hrac_stat)
					
			elif event.keycode == KEY_SPACE:
				GameManager.ukonci_kolo()

# Completely clears the active selection and hides all contextual UI panels
func _odzanc_vse():
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("selected_id", -1.0)
	
	var root = get_parent()
	if "ceka_na_cil_presunu" in root:
		root.ceka_na_cil_presunu = false
	
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
	if info_ui and info_ui.has_method("schovej_se"):
		info_ui.schovej_se()
		
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("schovej_se"):
		game_ui.schovej_se()

	var labels = get_parent().get_node_or_null("ProvinceLabels")
	if labels:
		for lbl in labels.get_children():
			if lbl.has_method("reset_stav"):
				lbl.reset_stav()

func _zpracuj_interakci(mouse_pos: Vector2, je_kliknuti: bool):
	if map_image == null: return
	
	var local_pos = to_local(get_global_mouse_position())
	if centered: local_pos += texture.get_size() / 2.0
	
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	if rect.has_point(local_pos):
		var pixel_color = map_image.get_pixelv(Vector2i(local_pos))
		
		if pixel_color.a > 0.0:
			var root = get_parent()
			if root.has_method("get_province_data_by_color"):
				var data = root.get_province_data_by_color(pixel_color)
				if data:
					_aktualizuj_vizual(float(data["id"]), je_kliknuti, data)
					return

	_vymaz_hover()

# Updates selection and hover states
func _aktualizuj_vizual(prov_id: float, je_kliknuti: bool, data: Dictionary):
	var root = get_parent()
	var is_targeting = "ceka_na_cil_presunu" in root and root.ceka_na_cil_presunu
	
	if je_kliknuti:
		# --- TARGET SELECTION MODE FOR ARMY MOVEMENT ---
		if is_targeting:
			var from_id = root.vybrana_armada_od
			var to_id = int(prov_id)
			
			if from_id != to_id and "provinces" in root:
				var is_neighbor = to_id in root.provinces[from_id].get("neighbors", [])
				
				if is_neighbor:
					var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
					if info_ui and info_ui.has_method("zobraz_presun_slider"):
						info_ui.zobraz_presun_slider(from_id, to_id, root.vybrana_armada_max)
			
			# Reset state and stop normal click processing
			root.ceka_na_cil_presunu = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			material.set_shader_parameter("is_target_hover", false)
			return
		# -----------------------------------------------
		
		material.set_shader_parameter("selected_id", prov_id)
		material.set_shader_parameter("has_selected", true)
		
		var vsechny_provincie = root.provinces if "provinces" in root else {}
		
		var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
		if info_ui and info_ui.has_method("zobraz_data"):
			info_ui.zobraz_data(data)
			
		var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
		if game_ui and game_ui.has_method("zobraz_prehled_statu"):
			game_ui.zobraz_prehled_statu(data, vsechny_provincie)
			
		var labels = get_parent().get_node_or_null("ProvinceLabels")
		if labels:
			var aktualni_sousede = data.get("neighbors", [])
			for lbl in labels.get_children():
				var l_id = int(lbl.get("province_id"))
				var je_cil = (l_id == int(prov_id))
				var je_soused = l_id in aktualni_sousede
				
				if lbl.has_method("nastav_stav_souseda"):
					lbl.nastav_stav_souseda(je_cil, je_soused)
					
	else:
		# --- HOVER LOGIC ---
		
		# Limit hovering strictly to neighbors if we are in target mode
		if is_targeting:
			var from_id = root.vybrana_armada_od
			var is_neighbor = int(prov_id) in root.provinces[from_id].get("neighbors", [])
			
			if not is_neighbor or int(prov_id) == from_id:
				_vymaz_hover()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return 
			else:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
				material.set_shader_parameter("is_target_hover", true)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			material.set_shader_parameter("is_target_hover", false)
			
		if _posledni_hover_id == int(prov_id):
			return # Already hovering this province, do nothing
			
		_vymaz_hover_labely() # Clean up the previously hovered label
		
		material.set_shader_parameter("hovered_id", prov_id)
		material.set_shader_parameter("has_hover", true)
		
		# Make the currently hovered label pop up
		var labels = get_parent().get_node_or_null("ProvinceLabels")
		if labels:
			for lbl in labels.get_children():
				if int(lbl.get("province_id")) == int(prov_id):
					if lbl.has_method("nastav_stav_souseda"):
						lbl.nastav_stav_souseda(true, false) # Treat hover as 'target' to show it
					break # Stop searching once found
					
		_posledni_hover_id = int(prov_id)

func _vymaz_hover():
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("is_target_hover", false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_vymaz_hover_labely()

# Safely resets the previously hovered label to its correct persistent state
func _vymaz_hover_labely():
	if _posledni_hover_id != -1:
		var sel_id = int(material.get_shader_parameter("selected_id"))
		
		# If the hovered province is also the clicked one, leave it alone
		if _posledni_hover_id == sel_id:
			_posledni_hover_id = -1
			return
			
		var je_soused = false
		var root = get_parent()
		if sel_id != -1 and "provinces" in root and root.provinces.has(sel_id):
			je_soused = _posledni_hover_id in root.provinces[sel_id].get("neighbors", [])
			
		var labels = root.get_node_or_null("ProvinceLabels")
		if labels:
			for lbl in labels.get_children():
				if int(lbl.get("province_id")) == _posledni_hover_id:
					if lbl.has_method("nastav_stav_souseda"):
						if je_soused:
							# Restore neighbor state if it belongs to the active selection
							lbl.nastav_stav_souseda(false, true)
						else:
							# Otherwise, completely hide/reset it
							lbl.reset_stav()
					break
		_posledni_hover_id = -1

func aktualizuj_mapovy_mod(mod: String, province_db: Dictionary):
	for prov_id in province_db.keys():
		var d = province_db[prov_id]
		var barva = Color.TRANSPARENT
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		var core_owner = str(d.get("core_owner", owner)).strip_edges().to_upper()
		var je_okupace = (core_owner != "" and owner != core_owner)
		occupation_image.set_pixel(prov_id, 0, Color(1, 1, 1, 1) if je_okupace else Color(0, 0, 0, 0))
		
		if owner != "SEA" and str(d.get("type", "")) != "sea":
			match mod:
				"political":
					barva = _barva_politickeho_vlastnictvi(d)
				"population":
					var s = clamp(float(d.get("population", 0)) / 3000000.0, 0.0, 1.0)
					barva = Color(s, 0.2, 0.2, 1.0)
				"gdp":
					var s = clamp(float(d.get("gdp", 0.0)) / 500.0, 0.0, 1.0)
					barva = Color(0.2, 0.8 * s, s, 1.0)
				"ideology": 
					var ideo = str(d.get("ideology", ""))
					if ideo == "demokracie": barva = Color("#2944A6")
					elif ideo == "komunismus": barva = Color("#D13A3A")
					elif ideo == "fasismus": barva = Color("#664229")
					elif ideo == "nacismus": barva = Color("4b4b4fff")
					elif ideo == "kralovstvi": barva = Color("#D4B04C")
					elif ideo == "autokracie": barva = Color("275b34ff")
					else: barva = Color("#666666") 
					barva.a = 1.0
				"recruitable_population": 
					var s = clamp(float(d.get("recruitable_population", 0)) / 500000.0, 0.0, 1.0)
					barva = Color(s, 0.8 * s, 0.1, 1.0)
				"relationships":
					var rel = 0.0
					if GameManager.has_method("ziskej_vztah_statu"):
						rel = GameManager.ziskej_vztah_statu(GameManager.hrac_stat, owner)
					if rel >= 0.0:
						var s_pos = clamp(rel / 100.0, 0.0, 1.0)
						barva = Color(1.0 - (0.9 * s_pos), 1.0, 0.15, 1.0)
					else:
						var s_neg = clamp(absf(rel) / 100.0, 0.0, 1.0)
						barva = Color(1.0, 1.0 - (0.9 * s_neg), 0.15, 1.0)
				
		data_image.set_pixel(prov_id, 0, barva)
	data_texture.update(data_image)
	occupation_texture.update(occupation_image)

func dobyt_provincii(prov_id: int, novy_vlastnik: String):
	var root = get_parent()
	if not root or not "provinces" in root: return
	
	if root.provinces.has(prov_id):
		root.provinces[prov_id]["owner"] = novy_vlastnik
		aktualizuj_mapovy_mod("political", root.provinces)
		print("Provincie ", prov_id, " byla dobyta státem ", novy_vlastnik)
		
		var labels_manager = root.get_node_or_null("CountryLabelsManager")
		var prov_labels = root.get_node_or_null("ProvinceLabels")
		if labels_manager and prov_labels:
			labels_manager.aktualizuj_labely_statu(root.provinces, prov_labels)
