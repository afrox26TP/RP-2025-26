extends Sprite2D

@export var logic_map: Texture2D
var map_image: Image

var data_image: Image
var data_texture: ImageTexture
var total_provinces: int = 5000

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

func _ready():
	if logic_map:
		map_image = logic_map.get_image()
	else:
		push_error("Chybi Logic Map!")
	
	data_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	data_image.fill(Color.TRANSPARENT)
	data_texture = ImageTexture.create_from_image(data_image)
	
	material.set_shader_parameter("data_texture", data_texture)
	material.set_shader_parameter("total_provinces", float(total_provinces))
	
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("hovered_id", -1.0)
	material.set_shader_parameter("selected_id", -1.0)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_zpracuj_interakci(event.position, false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_zpracuj_interakci(event.position, true)
		
	if event is InputEventKey and event.pressed:
		var root = get_parent()
		if "provinces" in root:
			if event.keycode == KEY_1: aktualizuj_mapovy_mod("political", root.provinces)
			elif event.keycode == KEY_2: aktualizuj_mapovy_mod("population", root.provinces)
			elif event.keycode == KEY_3: aktualizuj_mapovy_mod("gdp", root.provinces)

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

func _aktualizuj_vizual(prov_id: float, je_kliknuti: bool, data: Dictionary):
	# --- 1. Shader a UI ---
	if je_kliknuti:
		material.set_shader_parameter("selected_id", prov_id)
		material.set_shader_parameter("has_selected", true)
		var ui = get_tree().current_scene.find_child("InfoUI", true, false)
		if ui and ui.has_method("zobraz_data"): ui.zobraz_data(data)
	else:
		material.set_shader_parameter("hovered_id", prov_id)
		material.set_shader_parameter("has_hover", true)

	# --- 2. Dynamické labely (čisté a bez skákání) ---
	var labels = get_parent().get_node_or_null("ProvinceLabels")
	if labels:
		for lbl in labels.get_children():
			# Převedeme oboje na int, abychom měli 100% jistotu, že se najdou
			var is_target = (int(lbl.get("province_id")) == int(prov_id))
			
			if lbl.has_method("nastav_stav"):
				lbl.nastav_stav(is_target)

func _vymaz_hover():
	material.set_shader_parameter("has_hover", false)
	var labels = get_parent().get_node_or_null("ProvinceLabels")
	if labels:
		for lbl in labels.get_children():
			if lbl.has_method("reset_stav"):
				lbl.reset_stav()

func aktualizuj_mapovy_mod(mod: String, province_db: Dictionary):
	for prov_id in province_db.keys():
		var d = province_db[prov_id]
		var barva = Color.TRANSPARENT
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		
		if owner != "SEA" and str(d.get("type", "")) != "sea":
			match mod:
				"political":
					barva = country_colors.get(owner, Color.from_hsv(owner.hash() / float(0x7FFFFFFF), 0.7, 0.8))
					barva.a = 1.0
				"population":
					var s = clamp(float(d.get("population", 0)) / 3000000.0, 0.0, 1.0)
					barva = Color(s, 0.2, 0.2, 1.0)
				"gdp":
					var s = clamp(float(d.get("gdp", 0.0)) / 500.0, 0.0, 1.0)
					barva = Color(0.2, 0.8 * s, s, 1.0)
				
		data_image.set_pixel(prov_id, 0, barva)
	data_texture.update(data_image)
