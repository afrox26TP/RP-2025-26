extends CanvasLayer

@onready var panel = $OverviewPanel

# ZMĚNA: Tady jsou aktualizované cesty podle nového stromu
@onready var country_flag = $OverviewPanel/VBoxContainer/TitleBox/CountryFlag
@onready var name_label = $OverviewPanel/VBoxContainer/TitleBox/CountryNameLabel

@onready var ideo_label = $OverviewPanel/VBoxContainer/IdeologyLabel 
@onready var pop_label = $OverviewPanel/VBoxContainer/TotalPopLabel
@onready var recruit_label = $OverviewPanel/VBoxContainer/TotalRecruitsLabel 
@onready var gdp_label = $OverviewPanel/VBoxContainer/TotalGdpLabel
@onready var gdp_pc_label = $OverviewPanel/VBoxContainer/GdpPerCapitaLabel 

func _ready():
	panel.hide()

func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
	if data.is_empty():
		schovej_se()
		return
		
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var plne_jmeno = str(data.get("country_name", owner))
	
	# To lower case, abychom se vyhli problémům s názvy souborů (Neznámo -> neznamo atd.)
	var ideologie = str(data.get("ideology", "")).to_lower() 
	
	if owner == "SEA" or owner == "":
		schovej_se()
		return
		
	# --- NAČTENÍ VLAJKY ---
	if country_flag:
		var ideo_cesta = "res://map_data/FlagsIdeology/%s_%s.svg" % [owner, ideologie]
		var zaklad_cesta = "res://map_data/Flags/%s.svg" % owner
		
		if ideologie != "" and ideologie != "neznámo" and ResourceLoader.exists(ideo_cesta):
			country_flag.texture = load(ideo_cesta)
		elif ResourceLoader.exists(zaklad_cesta):
			country_flag.texture = load(zaklad_cesta)
		else:
			country_flag.texture = null
	# ----------------------
		
	var total_pop = 0
	var total_gdp = 0.0
	var total_recruits = 0
	
	# Sečtu si data za celý stát
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == owner:
			total_pop += int(p.get("population", 0))
			total_gdp += float(p.get("gdp", 0.0))
			total_recruits += int(p.get("recruitable_population", 0))
			
	name_label.text = plne_jmeno
	ideo_label.text = "Zřízení: " + ideologie.capitalize()
	pop_label.text = "Celková populace: " + _formatuj_cislo(total_pop)
	
	# Spočítám podíl rekrutů
	var procento = 0.0
	if total_pop > 0:
		procento = (float(total_recruits) / float(total_pop)) * 100.0
		
	recruit_label.text = "Celkoví rekruti: " + _formatuj_cislo(total_recruits) + " (%.2f %%)" % procento
	gdp_label.text = "Celkové HDP: %.2f mld. USD" % total_gdp
	
	# Spočítám HDP na hlavu
	if total_pop > 0:
		var gdp_per_capita = (total_gdp * 1000000000.0) / float(total_pop)
		gdp_pc_label.text = "HDP na osobu: $%.0f" % gdp_per_capita
	else:
		gdp_pc_label.text = "HDP na osobu: N/A"
	
	panel.show()

# Zavolá se při kliknutí pravým tlačítkem do mapy
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
