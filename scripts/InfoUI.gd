extends CanvasLayer

@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel
@onready var pop_label = $PanelContainer/VBoxContainer/PopLabel
@onready var gdp_label = $PanelContainer/VBoxContainer/GdpLabel
@onready var gdp_pc_label = $PanelContainer/VBoxContainer/GdpPerCapitaLabel

@onready var action_menu = $ActionMenu
@onready var btn_stavet = $ActionMenu/HBoxContainer/StavetButton
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

func _ready():
	action_menu.hide()

func zobraz_data(data: Dictionary):
	if data.is_empty():
		action_menu.hide()
		return
	
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var je_more = (owner == "SEA")
	
	# Zásadní proměnná: Je tohle moje území?
	var je_moje = (owner == GameManager.hrac_stat)
	
	id_label.text = "Provincie: " + str(data.get("province_name", "Neznamo"))
	owner_label.text = "Vlastnik: " + owner
	
	if je_more:
		# Schovame ekonomicke udaje pro more
		pop_label.hide()
		gdp_label.hide()
		gdp_pc_label.hide()
	else:
		# Ukazeme data pro pevninu
		pop_label.show()
		gdp_label.show()
		
		
		var pop = int(data.get("population", 0))
		pop_label.text = "Populace: " + _formatuj_cislo(pop)
		
		var gdp = float(data.get("gdp", 0.0))
		gdp_label.text = "HDP: %.2f mld. USD" % gdp
		
		
			

	# TADY JE TA LOGIKA: Zobraz akce jenom, když to vlastníš
	if je_moje and not je_more:
		btn_stavet.disabled = false
		btn_verbovat.disabled = false
		btn_likvidovat.disabled = false
		action_menu.show()
	else:
		# Cizí stát nebo moře -> žádné akce
		action_menu.hide()

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
