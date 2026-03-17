extends CanvasLayer

@onready var panel = $OverviewPanel
@onready var name_label = $OverviewPanel/VBoxContainer/CountryNameLabel
@onready var ideo_label = $OverviewPanel/VBoxContainer/IdeologyLabel 
@onready var pop_label = $OverviewPanel/VBoxContainer/TotalPopLabel
@onready var gdp_label = $OverviewPanel/VBoxContainer/TotalGdpLabel
# Napojení nového Labelu pro HDP na hlavu
@onready var gdp_pc_label = $OverviewPanel/VBoxContainer/GdpPerCapitaLabel 

func _ready():
	panel.hide()

func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
	if data.is_empty():
		panel.hide()
		return
		
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var plne_jmeno = str(data.get("country_name", owner))
	var ideologie = str(data.get("ideology", "Neznámo"))
	
	if owner == "SEA" or owner == "":
		panel.hide()
		return
		
	var total_pop = 0
	var total_gdp = 0.0
	
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == owner:
			total_pop += int(p.get("population", 0))
			total_gdp += float(p.get("gdp", 0.0))
			
	name_label.text = "Stát: " + plne_jmeno
	ideo_label.text = "Zřízení: " + ideologie.capitalize()
	pop_label.text = "Celková populace: " + _formatuj_cislo(total_pop)
	gdp_label.text = "Celkové HDP: %.2f mld. USD" % total_gdp
	
	# Výpočet průměrného HDP na osobu pro celý stát
	if total_pop > 0:
		var gdp_per_capita = (total_gdp * 1000000000.0) / float(total_pop)
		gdp_pc_label.text = "HDP na osobu: $%.0f" % gdp_per_capita
	else:
		gdp_pc_label.text = "HDP na osobu: N/A"
	
	panel.show()

func zavri_prehled():
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
