extends CanvasLayer

@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel
@onready var pop_label = $PanelContainer/VBoxContainer/PopLabel
@onready var recruit_label = $PanelContainer/VBoxContainer/RecruitLabel
@onready var gdp_label = $PanelContainer/VBoxContainer/GdpLabel
@onready var income_label = $PanelContainer/VBoxContainer/IncomeLabel 

@onready var action_menu = $ActionMenu
@onready var btn_stavet = $ActionMenu/HBoxContainer/StavetMenuButton 
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

var aktualni_provincie_id: int = -1

func _ready():
	action_menu.hide()
	
	var popup = btn_stavet.get_popup()
	popup.clear()
	popup.add_item("Civilní továrna (150 mil.)", 0)
	popup.add_item("Zbrojovka (200 mil.)", 1)
	
	popup.id_pressed.connect(_on_stavba_vybrana)
	popup.about_to_popup.connect(_posun_menu_nahoru)

func _posun_menu_nahoru():
	var popup = btn_stavet.get_popup()
	# Posunu roletku těsně nad tlačítko
	popup.position.y = btn_stavet.global_position.y - popup.size.y - 5

func zobraz_data(data: Dictionary):
	if data.is_empty():
		action_menu.hide()
		aktualni_provincie_id = -1
		return
	
	# Zapamatuju si vybranou provincii
	aktualni_provincie_id = data.get("id", -1)
	
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var je_more = (owner == "SEA")
	var je_moje = (owner == GameManager.hrac_stat)
	
	id_label.text = "Provincie: " + str(data.get("province_name", "Neznamo"))
	owner_label.text = "Vlastnik: " + owner
	
	if je_more:
		pop_label.hide()
		recruit_label.hide()
		gdp_label.hide()
		income_label.hide()
	else:
		pop_label.show()
		recruit_label.show()
		gdp_label.show()
		
		var pop = int(data.get("population", 0))
		pop_label.text = "Populace: " + _formatuj_cislo(pop)
		
		var rekruti = int(data.get("recruitable_population", 0))
		recruit_label.text = "Rekruti: " + _formatuj_cislo(rekruti)
		
		var gdp = float(data.get("gdp", 0.0))
		gdp_label.text = "HDP: %.2f mld. USD" % gdp
		
		if je_moje:
			income_label.show()
			var prijem_provincie = gdp * 0.05
			income_label.text = "Příjem: +%.2f mil. USD" % prijem_provincie
		else:
			income_label.hide()

	if je_moje and not je_more:
		# Zkontroluju, jestli už tu nestavím
		if GameManager.provincie_cooldowny.has(aktualni_provincie_id):
			var zbyva_kol = GameManager.provincie_cooldowny[aktualni_provincie_id]["zbyva"]
			btn_stavet.disabled = true
			btn_stavet.text = "Staví se (%d kol)" % zbyva_kol
		else:
			btn_stavet.disabled = false
			btn_stavet.text = "Stavět"
			
		btn_verbovat.disabled = false
		btn_likvidovat.disabled = false
		action_menu.show()
	else:
		action_menu.hide()

func _on_stavba_vybrana(id: int):
	if aktualni_provincie_id == -1: return
	
	var cena = 0.0
	var typ_budovy = ""
	
	if id == 0:
		cena = 150.0
		typ_budovy = "Civilní továrna"
	elif id == 1:
		cena = 200.0
		typ_budovy = "Zbrojovka"
		
	if GameManager.statni_kasa >= cena:
		# Strhnu prachy
		GameManager.statni_kasa -= cena
		print("Začala stavba: %s (Provincie %d)" % [typ_budovy, aktualni_provincie_id])
		
		# Zapíšu stavbu do paměti (3 kola, typ budovy)
		GameManager.provincie_cooldowny[aktualni_provincie_id] = {"zbyva": 3, "budova": id}
		
		# Vizuálně zamknu tlačítko
		btn_stavet.disabled = true
		btn_stavet.text = "Staví se (3 kola)"
		
		GameManager.kolo_zmeneno.emit()
	else:
		print("Nemáš peníze!")

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
