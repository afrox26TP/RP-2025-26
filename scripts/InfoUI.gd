extends CanvasLayer

@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel
@onready var pop_label = $PanelContainer/VBoxContainer/PopLabel
@onready var recruit_label = $PanelContainer/VBoxContainer/RecruitLabel
@onready var gdp_label = $PanelContainer/VBoxContainer/GdpLabel
@onready var income_label = $PanelContainer/VBoxContainer/IncomeLabel 
@onready var soldiers_label = $PanelContainer/VBoxContainer/SoldiersLabel 

@onready var action_menu = $ActionMenu
@onready var btn_stavet = $ActionMenu/HBoxContainer/StavetMenuButton 
# Tady nechávám tvůj původní název, jen to v editoru musí být MenuButton
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

var aktualni_provincie_id: int = -1

func _ready():
	action_menu.hide()
	
	# Menu pro stavění
	var popup_stavba = btn_stavet.get_popup()
	popup_stavba.clear()
	popup_stavba.add_item("Civilní továrna (150 mil.)", 0)
	popup_stavba.add_item("Zbrojovka (200 mil.)", 1)
	popup_stavba.id_pressed.connect(_on_stavba_vybrana)
	popup_stavba.about_to_popup.connect(_posun_stavba_menu)

	# Menu pro verbování
	var popup_verbovani = btn_verbovat.get_popup()
	popup_verbovani.clear()
	popup_verbovani.add_item("Pěchota (50 mil. | 1000 rekrutů)", 0)
	popup_verbovani.id_pressed.connect(_on_verbovat_vybrano)
	popup_verbovani.about_to_popup.connect(_posun_verbovat_menu)

func _posun_stavba_menu():
	var p = btn_stavet.get_popup()
	p.position.y = btn_stavet.global_position.y - p.size.y - 5

func _posun_verbovat_menu():
	var p = btn_verbovat.get_popup()
	p.position.y = btn_verbovat.global_position.y - p.size.y - 5

func schovej_se():
	$PanelContainer.hide()
	action_menu.hide()
	aktualni_provincie_id = -1

func zobraz_data(data: Dictionary):
	if data.is_empty():
		schovej_se()
		return
	
	$PanelContainer.show()
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
		soldiers_label.hide()
	else:
		pop_label.show()
		recruit_label.show()
		gdp_label.show()
		soldiers_label.show()
		
		var pop = int(data.get("population", 0))
		pop_label.text = "Populace: " + _formatuj_cislo(pop)
		
		var rekruti = int(data.get("recruitable_population", 0))
		recruit_label.text = "Rekruti: " + _formatuj_cislo(rekruti)
		
		var gdp = float(data.get("gdp", 0.0))
		gdp_label.text = "HDP: %.2f mld. USD" % gdp
		
		# Kolik tam mám vojáků?
		var vojaci = int(data.get("soldiers", 0))
		soldiers_label.text = "Posádka: " + _formatuj_cislo(vojaci) + " mužů"
		
		if je_moje:
			income_label.show()
			income_label.text = "Příjem: +%.2f mil. USD" % (gdp * 0.05)
		else:
			income_label.hide()

	if je_moje and not je_more:
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
	
	var cena = 150.0 if id == 0 else 200.0
	var typ_budovy = "Civilní továrna" if id == 0 else "Zbrojovka"
		
	if GameManager.statni_kasa >= cena:
		GameManager.statni_kasa -= cena
		GameManager.provincie_cooldowny[aktualni_provincie_id] = {"zbyva": 3, "budova": id}
		btn_stavet.disabled = true
		btn_stavet.text = "Staví se (3 kola)"
		GameManager.kolo_zmeneno.emit()
	else:
		print("Nemáš peníze na stavbu!")

func _on_verbovat_vybrano(id: int):
	if aktualni_provincie_id == -1: return
	
	if id == 0: # Pěchota
		var cena = 50.0
		var potreba_rekrutu = 1000
		
		var prov_data = GameManager.map_data[aktualni_provincie_id]
		var dostupni_rekruti = int(prov_data.get("recruitable_population", 0))
		
		# Mám prachy i rekruty?
		if GameManager.statni_kasa >= cena and dostupni_rekruti >= potreba_rekrutu:
			GameManager.statni_kasa -= cena
			
			# Přesunu rekruty do posádky
			prov_data["recruitable_population"] -= potreba_rekrutu
			if not prov_data.has("soldiers"):
				prov_data["soldiers"] = 0
			prov_data["soldiers"] += potreba_rekrutu
			
			print("Naverbována pěchota! (Provincie %d)" % aktualni_provincie_id)
			
			zobraz_data(prov_data)
			GameManager.kolo_zmeneno.emit()
		else:
			print("Nedostatek financí nebo rekrutů!")

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
