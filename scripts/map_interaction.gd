extends Sprite2D

@export var logic_map: Texture2D
var map_image: Image

var data_image: Image
var data_texture: ImageTexture
var occupation_image: Image
var occupation_texture: ImageTexture
var selected_multi_image: Image
var selected_multi_texture: ImageTexture
var total_provinces: int = 5000

var _drag_select_active: bool = false
var _drag_select_started: bool = false
var _drag_start_local: Vector2 = Vector2.ZERO
var _drag_end_local: Vector2 = Vector2.ZERO
const DRAG_SELECT_THRESHOLD := 6.0
const RIGHT_CLICK_CANCEL_THRESHOLD := 8.0

var _right_press_active: bool = false
var _right_press_pos: Vector2 = Vector2.ZERO
var _right_dragging: bool = false

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
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var base = country_colors.get(owner_tag, Color.from_hsv(owner_tag.hash() / float(0x7FFFFFFF), 0.7, 0.8))
	base.a = 1.0

	# Occupied (non-core) territory is visually muted to separate it from core land.
	var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
	if core_owner != "" and owner_tag != core_owner:
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

	selected_multi_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	selected_multi_image.fill(Color(0, 0, 0, 0))
	selected_multi_texture = ImageTexture.create_from_image(selected_multi_image)
	
	material.set_shader_parameter("data_texture", data_texture)
	material.set_shader_parameter("occupation_texture", occupation_texture)
	material.set_shader_parameter("selected_multi_texture", selected_multi_texture)
	material.set_shader_parameter("total_provinces", float(total_provinces))
	
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("hovered_id", -1.0)
	material.set_shader_parameter("selected_id", -1.0)
	_aktualizuj_hromadny_selection_texture([])

func _draw():
	if not _drag_select_active or not _drag_select_started:
		return

	var rect = Rect2(_drag_start_local, _drag_end_local - _drag_start_local).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return

	var rect_draw = rect
	# Drag selection is tracked in texture-space (0..size), but Sprite2D drawing
	# uses local coordinates centered around (0,0) when centered=true.
	if centered and texture:
		rect_draw.position -= texture.get_size() / 2.0

	draw_rect(rect_draw, Color(0.1, 1.0, 1.0, 1.0), false, 3.0)

func _ziskej_localni_pozici_mysi(global_mouse_pos: Vector2) -> Vector2:
	var local_pos = to_local(global_mouse_pos)
	if centered:
		local_pos += texture.get_size() / 2.0
	return local_pos

func _aktualizuj_hromadny_selection_texture(ids: Array):
	if selected_multi_image == null or selected_multi_texture == null:
		return

	selected_multi_image.fill(Color(0, 0, 0, 0))
	for raw_id in ids:
		var pid = int(raw_id)
		if pid < 0 or pid >= total_provinces:
			continue
		selected_multi_image.set_pixel(pid, 0, Color(1, 1, 1, 1))
	selected_multi_texture.update(selected_multi_image)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if _drag_select_active:
			_drag_end_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
			if not _drag_select_started and _drag_start_local.distance_to(_drag_end_local) >= DRAG_SELECT_THRESHOLD:
				_drag_select_started = true
			queue_redraw()
			return
		_zpracuj_interakci(event.position, false, false)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var root = get_parent()
			var is_targeting = "ceka_na_cil_presunu" in root and root.ceka_na_cil_presunu
			var is_bulk_targeting = "ceka_na_hromadny_cil_presunu" in root and root.ceka_na_hromadny_cil_presunu
			if not is_targeting and not is_bulk_targeting:
				_drag_select_active = true
				_drag_select_started = false
				_drag_start_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
				_drag_end_local = _drag_start_local
				queue_redraw()
				return
			_zpracuj_interakci(event.position, true, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _drag_select_active:
				_drag_end_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
				var had_drag = _drag_select_started
				_drag_select_active = false
				_drag_select_started = false
				queue_redraw()
				if had_drag:
					_aplikuj_drag_hromadny_vyber()
				else:
					_zpracuj_interakci(event.position, true, event.shift_pressed)
				return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_press_active = true
				_right_dragging = false
				_right_press_pos = event.position
			else:
				if _right_press_active and not _right_dragging:
					_odzanc_vse()
				_right_press_active = false
				_right_dragging = false

	if event is InputEventMouseMotion and _right_press_active and not _right_dragging:
		if event.position.distance_to(_right_press_pos) >= RIGHT_CLICK_CANCEL_THRESHOLD:
			_right_dragging = true
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		var root = get_parent()
		if event.keycode == KEY_ESCAPE:
			_odzanc_vse()
			return
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
					dobyt_provincii(int(vybrana_provincie), GameManager.hrac_stat, true)
					
			elif event.keycode == KEY_SPACE:
				GameManager.ukonci_kolo()

func _aplikuj_drag_hromadny_vyber():
	if map_image == null:
		return

	var root = get_parent()
	if not root:
		return
	if not root.has_method("pridej_hromadny_vyber_provincie") or not root.has_method("ziskej_hromadne_vybrane_provincie"):
		return

	var texture_rect = Rect2(Vector2.ZERO, texture.get_size())
	var drag_rect = Rect2(_drag_start_local, _drag_end_local - _drag_start_local).abs()
	var clipped_rect = drag_rect.intersection(texture_rect)
	if clipped_rect.size.x < 1.0 or clipped_rect.size.y < 1.0:
		return

	# Add only provinces whose center/anchor lies inside rectangle.
	if "provinces" in root:
		for p_id in root.provinces.keys():
			var pid = int(p_id)
			var p = root.provinces[pid]
			var pos = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
			if root.has_method("_ziskej_lokalni_pozici_provincie"):
				pos = root._ziskej_lokalni_pozici_provincie(pid)
			if clipped_rect.has_point(pos):
				root.pridej_hromadny_vyber_provincie(pid)

	var hromadny_ids = root.ziskej_hromadne_vybrane_provincie()
	_aktualizuj_hromadny_selection_texture(hromadny_ids)

	if hromadny_ids.is_empty():
		_odzanc_vse()
		return

	material.set_shader_parameter("selected_id", int(hromadny_ids[hromadny_ids.size() - 1]))
	material.set_shader_parameter("has_selected", true)
	if root.has_method("nastav_vybranou_armadu_provincie"):
		root.nastav_vybranou_armadu_provincie(int(hromadny_ids[hromadny_ids.size() - 1]))

	if hromadny_ids.size() > 1:
		var info_ui_multi = get_tree().current_scene.find_child("InfoUI", true, false)
		if info_ui_multi and info_ui_multi.has_method("zobraz_hromadna_data"):
			info_ui_multi.zobraz_hromadna_data(hromadny_ids, root.provinces)
	else:
		var pid = int(hromadny_ids[0])
		if root.provinces.has(pid):
			var info_ui_single = get_tree().current_scene.find_child("InfoUI", true, false)
			if info_ui_single and info_ui_single.has_method("zobraz_data"):
				info_ui_single.zobraz_data(root.provinces[pid])

# Completely clears the active selection and hides all contextual UI panels
func _odzanc_vse():
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("selected_id", -1.0)
	
	var root = get_parent()
	if root and root.has_method("nastav_vybranou_armadu_provincie"):
		root.nastav_vybranou_armadu_provincie(-1)
	if "ceka_na_cil_presunu" in root:
		root.ceka_na_cil_presunu = false
	if "ceka_na_hromadny_cil_presunu" in root:
		root.ceka_na_hromadny_cil_presunu = false
	if root.has_method("vycisti_nahled_presunu"):
		root.vycisti_nahled_presunu()
	if root.has_method("vycisti_hromadny_vyber_provincii"):
		root.vycisti_hromadny_vyber_provincii()
	_aktualizuj_hromadny_selection_texture([])
	
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

func _zpracuj_interakci(_mouse_pos: Vector2, je_kliknuti: bool, shift_held: bool = false):
	if map_image == null: return

	var root = get_parent()
	if je_kliknuti and root and root.has_method("ziskej_prov_id_podle_ikony_armady"):
		var hit_prov_id = int(root.ziskej_prov_id_podle_ikony_armady(get_global_mouse_position()))
		if hit_prov_id >= 0 and "provinces" in root and root.provinces.has(hit_prov_id):
			_aktualizuj_vizual(float(hit_prov_id), true, root.provinces[hit_prov_id], shift_held)
			return
	
	var local_pos = to_local(get_global_mouse_position())
	if centered: local_pos += texture.get_size() / 2.0
	
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	if rect.has_point(local_pos):
		var pixel_color = map_image.get_pixelv(Vector2i(local_pos))
		
		if pixel_color.a > 0.0:
			if root.has_method("get_province_data_by_color"):
				var data = root.get_province_data_by_color(pixel_color)
				if data:
					_aktualizuj_vizual(float(data["id"]), je_kliknuti, data, shift_held)
					return

	_vymaz_hover()

# Updates selection and hover states
func _aktualizuj_vizual(prov_id: float, je_kliknuti: bool, data: Dictionary, shift_held: bool = false):
	var root = get_parent()
	var is_targeting = "ceka_na_cil_presunu" in root and root.ceka_na_cil_presunu
	var is_bulk_targeting = "ceka_na_hromadny_cil_presunu" in root and root.ceka_na_hromadny_cil_presunu
	var multi_ids: Array = []
	if root.has_method("ziskej_hromadne_vybrane_provincie"):
		multi_ids = root.ziskej_hromadne_vybrane_provincie()
	var has_multi_selection = multi_ids.size() > 1
	
	if je_kliknuti:
		# --- TARGET SELECTION MODE FOR ARMY MOVEMENT ---
		if is_bulk_targeting:
			var bulk_to_id = int(prov_id)
			var planned_count = 0
			if root.has_method("zaregistruj_hromadny_presun_armad"):
				planned_count = int(root.zaregistruj_hromadny_presun_armad(bulk_to_id))

			if planned_count > 0:
				var map_loader = get_tree().current_scene.find_child("Map", true, false)
				if not map_loader and get_parent().has_method("_ukaz_bitevni_popup"):
					map_loader = get_parent()
				if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
					map_loader._ukaz_bitevni_popup("HROMADNÝ PŘESUN", "Naplánováno přesunů: %d" % planned_count)
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				material.set_shader_parameter("is_target_hover", false)
			return

		if is_targeting:
			var from_id = root.vybrana_armada_od
			var to_id = int(prov_id)
			var cil_vybran = false
			var path: Array = []
			
			if from_id != to_id and root.has_method("najdi_nejrychlejsi_cestu_presunu"):
				path = root.najdi_nejrychlejsi_cestu_presunu(from_id, to_id)
				if path.size() >= 2:
					var target_info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
					if target_info_ui and target_info_ui.has_method("zobraz_presun_slider"):
						target_info_ui.zobraz_presun_slider(from_id, to_id, root.vybrana_armada_max, path)
						cil_vybran = true
			
			# Reset state only when a valid target is chosen.
			if cil_vybran:
				root.ceka_na_cil_presunu = false
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				material.set_shader_parameter("is_target_hover", false)
			return
		# -----------------------------------------------

		var shift_multi = shift_held or Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
		if shift_multi and root.has_method("prepni_hromadny_vyber_provincie") and root.has_method("ziskej_hromadne_vybrane_provincie"):
			# Preserve the previously selected province as initial bulk member when Shift-selection starts.
			if root.has_method("pridej_hromadny_vyber_provincie"):
				var existing_multi = root.ziskej_hromadne_vybrane_provincie()
				if existing_multi.is_empty():
					var initial_selected = int(material.get_shader_parameter("selected_id"))
					if initial_selected >= 0 and initial_selected != int(prov_id):
						root.pridej_hromadny_vyber_provincie(initial_selected)

			root.prepni_hromadny_vyber_provincie(int(prov_id))
			var hromadny_ids = root.ziskej_hromadne_vybrane_provincie()
			_aktualizuj_hromadny_selection_texture(hromadny_ids)
			material.set_shader_parameter("selected_id", prov_id)
			material.set_shader_parameter("has_selected", true)
			if hromadny_ids.size() > 1:
				var info_ui_multi = get_tree().current_scene.find_child("InfoUI", true, false)
				if info_ui_multi and info_ui_multi.has_method("zobraz_hromadna_data"):
					info_ui_multi.zobraz_hromadna_data(hromadny_ids, root.provinces)
				return
			elif hromadny_ids.size() == 1:
				return
			elif hromadny_ids.is_empty():
				_odzanc_vse()
				return

		if root.has_method("vycisti_hromadny_vyber_provincii"):
			root.vycisti_hromadny_vyber_provincii()
		_aktualizuj_hromadny_selection_texture([])
		
		material.set_shader_parameter("selected_id", prov_id)
		material.set_shader_parameter("has_selected", true)
		if root.has_method("nastav_vybranou_armadu_provincie"):
			root.nastav_vybranou_armadu_provincie(int(prov_id))
		
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

		if has_multi_selection and not is_targeting and not is_bulk_targeting:
			var valid_multi_hover = false
			if root.has_method("je_platna_provincie_pro_hromadny_vyber"):
				valid_multi_hover = root.je_platna_provincie_pro_hromadny_vyber(int(prov_id))

			material.set_shader_parameter("is_target_hover", false)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if valid_multi_hover else Input.CURSOR_ARROW)

			if _posledni_hover_id == int(prov_id):
				return

			_vymaz_hover_labely()
			material.set_shader_parameter("hovered_id", prov_id)
			material.set_shader_parameter("has_hover", true)
			_posledni_hover_id = int(prov_id)
			return
		
		# Limit hovering strictly to neighbors if we are in target mode
		if is_bulk_targeting:
			var bulk_valid = false
			var bulk_hover_path: Array = []
			if root.has_method("ma_hromadny_platny_cil_presunu"):
				bulk_valid = root.ma_hromadny_platny_cil_presunu(int(prov_id))
			if bulk_valid and root.has_method("najdi_hromadny_nahled_presunu_k_cili"):
				bulk_hover_path = root.najdi_hromadny_nahled_presunu_k_cili(int(prov_id))
			if not bulk_valid:
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				_vymaz_hover()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return
			if bulk_hover_path.size() >= 2 and root.has_method("zobraz_nahled_presunu"):
				root.zobraz_nahled_presunu(bulk_hover_path)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_targeting:
			var from_id = root.vybrana_armada_od
			var is_valid_target = false
			var hover_path: Array = []
			if root.has_method("najdi_nejrychlejsi_cestu_presunu"):
				hover_path = root.najdi_nejrychlejsi_cestu_presunu(from_id, int(prov_id))
				is_valid_target = hover_path.size() >= 2
			
			if not is_valid_target or int(prov_id) == from_id:
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				_vymaz_hover()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return 
			else:
				if root.has_method("zobraz_nahled_presunu"):
					root.zobraz_nahled_presunu(hover_path)
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
				material.set_shader_parameter("is_target_hover", true)
		else:
			if root.has_method("vycisti_nahled_presunu"):
				root.vycisti_nahled_presunu()
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
	var root = get_parent()
	if root and root.has_method("vycisti_nahled_presunu"):
		root.vycisti_nahled_presunu()
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
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
		var je_okupace = (core_owner != "" and owner_tag != core_owner)
		occupation_image.set_pixel(prov_id, 0, Color(1, 1, 1, 1) if je_okupace else Color(0, 0, 0, 0))
		
		if owner_tag != "SEA" and str(d.get("type", "")) != "sea":
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
						rel = GameManager.ziskej_vztah_statu(GameManager.hrac_stat, owner_tag)
					if rel >= 0.0:
						var s_pos = clamp(rel / 100.0, 0.0, 1.0)
						barva = Color(1.0 - (0.9 * s_pos), 1.0, 0.15, 1.0)
					else:
						var s_neg = clamp(absf(rel) / 100.0, 0.0, 1.0)
						barva = Color(1.0, 1.0 - (0.9 * s_neg), 0.15, 1.0)
				
		data_image.set_pixel(prov_id, 0, barva)
	data_texture.update(data_image)
	occupation_texture.update(occupation_image)

func dobyt_provincii(prov_id: int, novy_vlastnik: String, z_dev_nastroje: bool = false):
	var root = get_parent()
	if not root or not "provinces" in root: return
	
	if root.provinces.has(prov_id):
		var puvodni_vlastnik = str(root.provinces[prov_id].get("owner", "")).strip_edges().to_upper()
		var novy = novy_vlastnik.strip_edges().to_upper()
		var was_capital = bool(root.provinces[prov_id].get("is_capital", false))
		if novy == "" or puvodni_vlastnik == novy:
			return

		root.provinces[prov_id]["owner"] = novy
		if z_dev_nastroje and str(root.provinces[prov_id].get("type", "")).strip_edges().to_lower() != "sea":
			# Dev capture has no battle resolution, so remove stale garrison ownership.
			root.provinces[prov_id]["soldiers"] = 0
			root.provinces[prov_id]["army_owner"] = ""

		if root.has_method("_ziskej_profil_statu"):
			var profil = root._ziskej_profil_statu(novy)
			root.provinces[prov_id]["country_name"] = str(profil.get("country_name", novy))
			root.provinces[prov_id]["ideology"] = str(profil.get("ideology", ""))

		if z_dev_nastroje and was_capital and puvodni_vlastnik != "" and puvodni_vlastnik != "SEA" and novy != "SEA":
			GameManager.zaregistruj_obsazeni_hlavniho_mesta(puvodni_vlastnik, novy, prov_id)

		var mod = "political"
		if "aktualni_mapovy_mod" in root:
			mod = str(root.aktualni_mapovy_mod)
		aktualizuj_mapovy_mod(mod, root.provinces)
		print("Provincie ", prov_id, " byla dobyta státem ", novy_vlastnik)
		
		var labels_manager = root.get_node_or_null("CountryLabelsManager")
		var prov_labels = root.get_node_or_null("ProvinceLabels")
		if labels_manager and prov_labels:
			labels_manager.aktualizuj_labely_statu(root.provinces, prov_labels)
