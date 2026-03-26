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
@onready var relationship_label = $OverviewPanel/VBoxContainer/RelationshipLabel

# --- NEW: Action nodes ---
@onready var action_separator = $OverviewPanel/VBoxContainer/ActionSeparator
@onready var improve_rel_btn = $OverviewPanel/VBoxContainer/ImproveRelationButton
@onready var worsen_rel_btn = $OverviewPanel/VBoxContainer/WorsenRelationButton
@onready var declare_war_btn = $OverviewPanel/VBoxContainer/DeclareWarButton
@onready var propose_peace_btn = $OverviewPanel/VBoxContainer/ProposePeaceButton

# Store the currently viewed country tag
var current_viewed_tag: String = ""
var flag_texture_cache: Dictionary = {}

func _resolve_flag_texture(owner_tag: String, ideologie: String):
	var ideo = ideologie.strip_edges().to_lower()
	var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [owner_tag, ideo]
	var zaklad_cesta = "res://map_data/Flags/%s.svg" % owner_tag

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
	if propose_peace_btn and not propose_peace_btn.pressed.is_connected(_on_propose_peace_button_pressed):
		propose_peace_btn.pressed.connect(_on_propose_peace_button_pressed)
	if improve_rel_btn and not improve_rel_btn.pressed.is_connected(_on_improve_relationship_pressed):
		improve_rel_btn.pressed.connect(_on_improve_relationship_pressed)
	if worsen_rel_btn and not worsen_rel_btn.pressed.is_connected(_on_worsen_relationship_pressed):
		worsen_rel_btn.pressed.connect(_on_worsen_relationship_pressed)
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)

func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
	if data.is_empty():
		schovej_se()
		return
		
	var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
	current_viewed_tag = owner_tag # Save the tag for button actions
	
	var plne_jmeno = str(data.get("country_name", owner_tag))
	
	# Force lowercase to prevent file path issues
	var ideologie = str(data.get("ideology", "")).to_lower() 
	
	if owner_tag == "SEA" or owner_tag == "":
		schovej_se()
		return

	if relationship_label:
		relationship_label.hide()
		
	# --- FLAG LOADING ---
	if country_flag:
		country_flag.texture = _resolve_flag_texture(owner_tag, ideologie)
	# --------------------
		
	var total_pop = 0
	var total_gdp = 0.0
	var total_recruits = 0
	
	# Calculate total country stats
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == owner_tag:
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
	if action_separator and declare_war_btn and propose_peace_btn:
		if owner_tag == GameManager.hrac_stat:
			# Hide actions if looking at our own country
			if relationship_label:
				relationship_label.hide()
			action_separator.hide()
			if improve_rel_btn: improve_rel_btn.hide()
			if worsen_rel_btn: worsen_rel_btn.hide()
			declare_war_btn.hide()
			propose_peace_btn.hide()
		else:
			_aktualizuj_vztah_ui(owner_tag)
			# Show actions for other countries
			action_separator.show()
			if improve_rel_btn: improve_rel_btn.show()
			if worsen_rel_btn: worsen_rel_btn.show()
			_aktualizuj_diplomacii_tlacitka(owner_tag)
	
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
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_propose_peace_button_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return

	GameManager.nabidnout_mir(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_improve_relationship_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if GameManager.has_method("zlepsi_vztah_statu"):
		GameManager.zlepsi_vztah_statu(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_vztah_ui(current_viewed_tag)

func _on_worsen_relationship_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if GameManager.has_method("zhorsi_vztah_statu"):
		GameManager.zhorsi_vztah_statu(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_vztah_ui(current_viewed_tag)

func _on_kolo_zmeneno():
	if current_viewed_tag == "" or not panel.visible:
		return
	_aktualizuj_vztah_ui(current_viewed_tag)

func _aktualizuj_vztah_ui(target_tag: String):
	if not relationship_label or not GameManager.has_method("ziskej_vztah_statu"):
		return
	var vztah = GameManager.ziskej_vztah_statu(GameManager.hrac_stat, target_tag)
	relationship_label.text = "Nas vztah: %.1f" % vztah
	relationship_label.show()
	var zbyle_kola := 0
	if GameManager.has_method("zbyva_kol_do_upravy_vztahu"):
		zbyle_kola = int(GameManager.zbyva_kol_do_upravy_vztahu(GameManager.hrac_stat, target_tag))
	var je_cooldown = zbyle_kola > 0

	if improve_rel_btn:
		improve_rel_btn.text = "Zlepsit vztah (%d kol)" % zbyle_kola if je_cooldown else "Zlepsit vztah (+10)"
		improve_rel_btn.disabled = je_cooldown or vztah >= 100.0
	if worsen_rel_btn:
		worsen_rel_btn.text = "Zhorsit vztah (%d kol)" % zbyle_kola if je_cooldown else "Zhorsit vztah (-10)"
		worsen_rel_btn.disabled = je_cooldown or vztah <= -100.0

func _aktualizuj_diplomacii_tlacitka(target_tag: String):
	if not declare_war_btn or not propose_peace_btn:
		return

	if GameManager.jsou_ve_valce(GameManager.hrac_stat, target_tag):
		declare_war_btn.text = "VE VALCE"
		declare_war_btn.disabled = true
		declare_war_btn.modulate = Color(1, 0.5, 0.5)
		declare_war_btn.show()

		var ceka_na_odpoved = GameManager.je_mirova_nabidka_cekajici(GameManager.hrac_stat, target_tag)
		propose_peace_btn.text = "Nabidka odeslana" if ceka_na_odpoved else "Nabidnout mir"
		propose_peace_btn.disabled = ceka_na_odpoved
		propose_peace_btn.modulate = Color(1, 1, 1)
		propose_peace_btn.show()
	else:
		declare_war_btn.text = "Vyhlasit valku"
		declare_war_btn.disabled = false
		declare_war_btn.modulate = Color(1, 1, 1)
		declare_war_btn.show()

		propose_peace_btn.hide()
