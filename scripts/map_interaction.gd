extends Sprite2D

@export var logic_map: Texture2D # SEM V INSPECTORU HOĎ PŮVODNÍ ProvinceMap.png
var map_image: Image

# --- NOVÉ PROMĚNNÉ PRO DYNAMICKOU MAPU ---
var data_image: Image
var data_texture: ImageTexture
var total_provinces: int = 5000 # POZOR: Uprav podle reálného počtu provincií v tvém txt!

# --- SLOVNÍK BAREV PRO STÁTY (POLITICKÁ MAPA) ---
var country_colors = {
	"ALB": Color("#D13A3A"), # Albánie (Červená)
	"AND": Color("#1A409A"), # Andorra (Tmavě modrá)
	"AUT": Color("#FFFFFF"), # Rakousko (Bílá)
	"BLR": Color("#8CA35E"), # Bělorusko (Zelenkavá)
	"BEL": Color("#D4B04C"), # Belgie (Tmavě žlutá/Zlatá)
	"BIH": Color("#456285"), # Bosna a Hercegovina (Tlumená modrá)
	"BGR": Color("#426145"), # Bulharsko (Olivová)
	"HRV": Color("#5C7691"), # Chorvatsko (Šedomodrá)
	"CYP": Color("#E3A336"), # Kypr (Měděná)
	"CZE": Color("#D49035"), # Česko (Zlatavá/Oranžová)
	"DNK": Color("#9E333D"), # Dánsko (Tmavě červená)
	"EST": Color("#266E73"), # Estonsko (Tyrkysová)
	"FIN": Color("#96B6D1"), # Finsko (Světle modrá)
	"FRA": Color("#2944A6"), # Francie (Královská modrá)
	"DEU": Color("#666666"), # Německo (Šedá)
	"GRC": Color("#5CA1D6"), # Řecko (Modrá)
	"HUN": Color("#A35A47"), # Maďarsko (Cihlová)
	"ISL": Color("#88ADC9"), # Island (Ledová modrá)
	"IRL": Color("#388F4F"), # Irsko (Smaragdová)
	"ITA": Color("#408F45"), # Itálie (Zelená)
	"KOS": Color("#454B87"), # Kosovo (Tmavě fialová/Modrá)
	"GEO": Color("#D48035"), # Gruzie (Oranžovo-hnědá)
	"LVA": Color("#85616D"), # Lotyšsko (Fialovo-šedá)
	"LIE": Color("#314C7D"), # Lichtenštejnsko (Modrá)
	"LTU": Color("#A6A34E"), # Litva (Žlutozelená)
	"LUX": Color("#8FA9D4"), # Lucembursko (Světle fialovomodrá)
	"MLT": Color("#D95959"), # Malta (Jemná červená)
	"MDA": Color("#D4A94C"), # Moldavsko (Žlutooranžová)
	"MCO": Color("#D63636"), # Monako (Červená)
	"MNE": Color("#3D7873"), # Černá Hora (Tyrkysovo-šedá)
	"NLD": Color("#D97529"), # Nizozemsko (Oranžová)
	"MKD": Color("#D14532"), # Severní Makedonie (Červeno-oranžová)
	"NOR": Color("#6E88A1"), # Norsko (Šedomodrá)
	"POL": Color("#C44D64"), # Polsko (Karmínová)
	"PRT": Color("#2A7A38"), # Portugalsko (Zelená)
	"ROU": Color("#C9A936"), # Rumunsko (Žlutá)
	"RUS": Color("#316E40"), # Rusko (Tmavě zelená)
	"SMR": Color("#7BA1C7"), # San Marino (Světle modrá)
	"SRB": Color("#B8939D"), # Srbsko (Růžovo-šedá)
	"SVK": Color("#3A5B8C"), # Slovensko (Tmavá modrá)
	"SVN": Color("#4E8272"), # Slovinsko (Mátová zelená)
	"ESP": Color("#D4BC2C"), # Španělsko (Žlutá)
	"SWE": Color("#286C9E"), # Švédsko (Azurová)
	"CHE": Color("#AD2A2A"), # Švýcarsko (Sytá červená)
	"TUR": Color("#3A8C67"), # Turecko (Osmanská zelená)
	"UKR": Color("#DEC243"), # Ukrajina (Žlutá)
	"GBR": Color("#9E2633"),  # Velká Británie (Tmavě červená)
	"SEA": Color("5b556fff")  # Velká Británie (Tmavě červená)
}

func _ready():
	if logic_map:
		map_image = logic_map.get_image()
	else:
		push_error("Nezapomeň přiřadit Logic Map v Inspectoru!")
	
	# Inicializace prázdné datové textury pro mapové módy
	data_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	
	# --- TADY JE TA OPRAVA ---
	# Místo Color.GRAY tam dáme Color.TRANSPARENT
	data_image.fill(Color.TRANSPARENT) 
	
	data_texture = ImageTexture.create_from_image(data_image)
	
	# Předání základních dat do shaderu
	material.set_shader_parameter("data_texture", data_texture)
	material.set_shader_parameter("total_provinces", float(total_provinces))
	
	# Reset stavů
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("hovered_id", -1.0)
	material.set_shader_parameter("selected_id", -1.0)

func _unhandled_input(event):
	# Tvoje stávající logika pro myš
	if event is InputEventMouseMotion:
		_zpracuj_interakci(event.position, false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_zpracuj_interakci(event.position, true)
		
	# --- TESTOVACÍ PŘEPÍNÁNÍ MÓDŮ ---
	if event is InputEventKey and event.pressed:
		var map_root = get_parent()
		# Ujistíme se, že má přístup k načteným provinciím
		if "provinces" in map_root:
			if event.keycode == KEY_1:
				print("Přepínám na Politický mód")
				aktualizuj_mapovy_mod("political", map_root.provinces)
			elif event.keycode == KEY_2:
				print("Přepínám na Populační mód")
				aktualizuj_mapovy_mod("population", map_root.provinces)
			elif event.keycode == KEY_3:
				print("Přepínám na GDP mód")
				aktualizuj_mapovy_mod("gdp", map_root.provinces)

func _zpracuj_interakci(mouse_pos: Vector2, je_kliknuti: bool):
	if map_image == null:
		return 
	
	# Přepočet na lokální souřadnice (bere v potaz kameru i zoom)
	var local_pos = to_local(get_global_mouse_position())
	
	# Korekce, pokud je zapnutý "Centered" u Sprite2D
	if centered:
		local_pos += texture.get_size() / 2.0
	
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	
	if rect.has_point(local_pos):
		var pixel_pos = Vector2i(local_pos)
		var pixel_color = map_image.get_pixelv(pixel_pos)
		
		if pixel_color.a > 0.0:
			# Potřebujeme data hned, abychom znali ID pro shader
			var map_root = get_parent()
			if map_root.has_method("get_province_data_by_color"):
				var data = map_root.get_province_data_by_color(pixel_color)
				
				if data:
					var prov_id = float(data["id"])
					
					if je_kliknuti:
						# 1. Změna přes ID v shaderu (výběr)
						material.set_shader_parameter("selected_id", prov_id)
						material.set_shader_parameter("has_selected", true)
						
						print("--- Provincie Nalezena ---")
						print("ID: ", data["id"], " | Vlastník: ", data["owner"])
						
						# 2. Update InfoUI
						var ui = get_tree().current_scene.find_child("InfoUI", true, false)
						if ui and ui.has_method("zobraz_data"):
							ui.zobraz_data(data)
					else:
						# Hover efekt přes ID
						material.set_shader_parameter("hovered_id", prov_id)
						material.set_shader_parameter("has_hover", true)
				else:
					if je_kliknuti:
						print("Nenalezeno v TXT. Myš vidí RGB: ", 
							int(pixel_color.r*255), ",", 
							int(pixel_color.g*255), ",", 
							int(pixel_color.b*255))
					material.set_shader_parameter("has_hover", false)
		else:
			material.set_shader_parameter("has_hover", false)
	else:
		material.set_shader_parameter("has_hover", false)

func aktualizuj_mapovy_mod(mod: String, province_db: Dictionary):
	var more_nalezeno = false # Flag pro jednorázový debug výpis
	
	for prov_id in province_db.keys():
		var prov_data = province_db[prov_id]
		var barva = Color.GRAY
		
		# Vyčištění textu od mezer a převod na stejnou velikost písmen, ať eliminujeme chyby!
		var owner = str(prov_data.get("owner", "")).strip_edges().to_upper()
		var type = str(prov_data.get("type", "")).strip_edges().to_lower()
		
		# --- ROBUSTNÍ KONTROLA PRO MOŘE ---
		if owner == "SEA" or type == "sea":
			barva = Color(0.0, 0.0, 0.0, 0.0) # Průhledná barva!
			
			if not more_nalezeno:
				print("DEBUG: Moře ('", owner, "') nalezeno na ID ", prov_id, ", posílám průhlednou barvu!")
				more_nalezeno = true # Abychom nespamovali konzoli
		else:
			if mod == "political":
				if country_colors.has(owner):
					barva = country_colors[owner]
					barva.a = 1.0 # Ujistíme se, že pevnina není průhledná
				else:
					var hash_val = owner.hash()
					barva = Color(
						float((hash_val & 0xFF0000) >> 16) / 255.0,
						float((hash_val & 0x00FF00) >> 8) / 255.0,
						float(hash_val & 0x0000FF) / 255.0,
						1.0
					)
			elif mod == "population":
				var pop = float(prov_data.get("population", 0))
				var sytost = clamp(pop / 1000000.0, 0.0, 1.0)
				barva = Color(sytost, 0.2, 0.2, 1.0)
			elif mod == "gdp":
				var gdp = float(prov_data.get("gdp", 0.0))
				var sytost = clamp(gdp / 5.0, 0.0, 1.0)
				barva = Color(0.2, 0.8 * sytost, sytost, 1.0)
				
		# Zápis nové barvy na index provincie
		data_image.set_pixel(prov_id, 0, barva)
		
	# Bleskový update celé mapy v grafice
	data_texture.update(data_image)
