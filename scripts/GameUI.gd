extends CanvasLayer

@onready var panel = $OverviewPanel

# Updated paths for the new UI tree structure
@onready var country_flag = $OverviewPanel/VBoxContainer/TitleBox/CountryFlag
@onready var name_label = $OverviewPanel/VBoxContainer/TitleBox/CountryNameLabel

@onready var ideo_label = $OverviewPanel/VBoxContainer/IdeologyLabel 
@onready var pop_label = $OverviewPanel/VBoxContainer/TotalPopLabel
@onready var recruit_label = $OverviewPanel/VBoxContainer/TotalRecruitsLabel 
@onready var gdp_label = $OverviewPanel/VBoxContainer/TotalGdpLabel
@onready var gdp_pc_label = $OverviewPanel/VBoxContainer/GdpPerCapitaLabel 

# --- NEW: Action nodes ---
@onready var action_separator = $OverviewPanel/VBoxContainer/ActionSeparator
@onready var declare_war_btn = $OverviewPanel/VBoxContainer/DeclareWarButton

# Store the currently viewed country tag
var current_viewed_tag: String = ""
var flag_texture_cache: Dictionary = {}

func _resolve_flag_texture(owner: String, ideologie: String):
	var ideo = ideologie.strip_edges().to_lower()
	var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [owner, ideo]
	var zaklad_cesta = "res://map_data/Flags/%s.svg" % owner

	if ideo != "" and ideo != "neznámo" and ResourceLoader.exists(ideo_cesta):
		if not flag_texture_cache.has(ideo_cesta):
			flag_texture_cache[ideo_cesta] = load(ideo_cesta)
		return flag_texture_cache[ideo_cesta]

	if ResourceLoader.exists(zaklad_cesta):
		if not flag_texture_cache.has(zaklad_cesta):
			flag_texture_cache[zaklad_cesta] = load(zaklad_cesta)
		return flag_texture_cache[zaklad_cesta]

	return null

func _ready():
	panel.hide()
	
	# Automatically connect the button signal if it exists
	if declare_war_btn and not declare_war_btn.pressed.is_connected(_on_declare_war_button_pressed):
		declare_war_btn.pressed.connect(_on_declare_war_button_pressed)

func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
	if data.is_empty():
		schovej_se()
		return
		
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	current_viewed_tag = owner # Save the tag for button actions
	
	var plne_jmeno = str(data.get("country_name", owner))
	
	# Force lowercase to prevent file path issues
	var ideologie = str(data.get("ideology", "")).to_lower() 
	
	if owner == "SEA" or owner == "":
		schovej_se()
		return
		
	# --- FLAG LOADING ---
	if country_flag:
		country_flag.texture = _resolve_flag_texture(owner, ideologie)
	# --------------------
		
	var total_pop = 0
	var total_gdp = 0.0
	var total_recruits = 0
	
	# Calculate total country stats
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == owner:
			total_pop += int(p.get("population", 0))
			total_gdp += float(p.get("gdp", 0.0))
			total_recruits += int(p.get("recruitable_population", 0))
			
	name_label.text = plne_jmeno
	ideo_label.text = "Zřízení: " + ideologie.capitalize()
	pop_label.text = "Celková populace: " + _formatuj_cislo(total_pop)
	
	# Calculate recruitable population percentage
	var procento = 0.0
	if total_pop > 0:
		procento = (float(total_recruits) / float(total_pop)) * 100.0
		
	recruit_label.text = "Celkoví rekruti: " + _formatuj_cislo(total_recruits) + " (%.2f %%)" % procento
	gdp_label.text = "Celkové HDP: %.2f mld. USD" % total_gdp
	
	# Calculate GDP per capita
	if total_pop > 0:
		var gdp_per_capita = (total_gdp * 1000000000.0) / float(total_pop)
		gdp_pc_label.text = "HDP na osobu: $%.0f" % gdp_per_capita
	else:
		gdp_pc_label.text = "HDP na osobu: N/A"
		
	# --- NEW: DIPLOMACY UI LOGIC ---
	if action_separator and declare_war_btn:
		if owner == GameManager.hrac_stat:
			# Hide actions if looking at our own country
			action_separator.hide()
			declare_war_btn.hide()
		else:
			# Show actions for other countries
			action_separator.show()
			declare_war_btn.show()
			
			# Check war status from GameManager
			if GameManager.jsou_ve_valce(GameManager.hrac_stat, owner):
				declare_war_btn.text = "VE VÁLCE"
				declare_war_btn.disabled = true
				declare_war_btn.modulate = Color(1, 0.5, 0.5) # Red tint
			else:
				declare_war_btn.text = "Vyhlásit válku"
				declare_war_btn.disabled = false
				declare_war_btn.modulate = Color(1, 1, 1) # Normal color
	
	panel.show()

# Triggered by right-clicking on the map
func schovej_se():
	panel.hide()

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek

# --- DIPLOMACY ACTION ---
func _on_declare_war_button_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
		
	# Declare war via GameManager
	GameManager.vyhlasit_valku(GameManager.hrac_stat, current_viewed_tag)
	
	# Update button visually immediately
	if declare_war_btn:
		declare_war_btn.text = "VE VÁLCE"
		declare_war_btn.disabled = true
		declare_war_btn.modulate = Color(1, 0.5, 0.5)
