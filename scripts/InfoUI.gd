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
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

# Paths to the recruitment popup panel elements
@onready var recruit_popup = $ActionMenu/RecruitPopup
@onready var recruit_info = $ActionMenu/RecruitPopup/VBoxContainer/RecruitInfo
@onready var recruit_slider = $ActionMenu/RecruitPopup/VBoxContainer/RecruitSlider
@onready var btn_potvrdit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/PotvrditBtn
@onready var btn_zrusit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/ZrusitBtn

var aktualni_provincie_id: int = -1
var cena_za_vojaka: float = 0.05 # Cost: 50 mil. per 1000 men

func _ready():
	action_menu.hide()
	
	# Initialize the construction popup menu
	var popup_stavba = btn_stavet.get_popup()
	popup_stavba.clear()
	popup_stavba.add_item("Civilní továrna (150 mil.)", 0)
	popup_stavba.add_item("Zbrojovka (200 mil.)", 1)
	popup_stavba.id_pressed.connect(_on_stavba_vybrana)
	popup_stavba.about_to_popup.connect(_posun_stavba_menu)

	# Connect buttons and slider signals
	btn_verbovat.pressed.connect(_on_verbovat_pressed)
	recruit_slider.value_changed.connect(_on_slider_zmenen)
	btn_potvrdit.pressed.connect(_on_potvrdit_verbovani)
	btn_zrusit.pressed.connect(func(): recruit_popup.hide())

# Repositions the construction menu slightly above the build button
func _posun_stavba_menu():
	var p = btn_stavet.get_popup()
	p.position.y = btn_stavet.global_position.y - p.size.y - 5

# Hides all UI panels and resets the selected province ID
func schovej_se():
	$PanelContainer.hide()
	action_menu.hide()
	recruit_popup.hide()
	aktualni_provincie_id = -1

# Populates the UI with data from the selected province
func zobraz_data(data: Dictionary):
	if data.is_empty():
		schovej_se()
		return
	
	$PanelContainer.show()
	recruit_popup.hide() # Close recruitment popup when clicking elsewhere
	aktualni_provincie_id = data.get("id", -1)
	
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var je_more = (owner == "SEA")
	var je_moje = (owner == GameManager.hrac_stat)
	
	id_label.text = "Provincie: " + str(data.get("province_name", "Neznamo"))
	owner_label.text = "Vlastnik: " + owner
	
	if je_more:
		# Hide irrelevant stats for sea tiles
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
		
		var vojaci = int(data.get("soldiers", 0))
		soldiers_label.text = "Posádka: " + _formatuj_cislo(vojaci) + " mužů"
		
		if je_moje:
			income_label.show()
			income_label.text = "Příjem: +%.2f mil. USD" % (gdp * 0.05)
		else:
			income_label.hide()

	# Handle action menu visibility for player-owned land provinces
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

# Handles building construction logic (deducts money, starts cooldown)
func _on_stavba_vybrana(id: int):
	if aktualni_provincie_id == -1: return
	var cena = 150.0 if id == 0 else 200.0
	
	if GameManager.statni_kasa >= cena:
		GameManager.statni_kasa -= cena
		GameManager.provincie_cooldowny[aktualni_provincie_id] = {"zbyva": 3, "budova": id}
		btn_stavet.disabled = true
		btn_stavet.text = "Staví se (3 kola)"
		GameManager.kolo_zmeneno.emit()

# Prepares and shows the recruitment slider popup
func _on_verbovat_pressed():
	if aktualni_provincie_id == -1: return
	
	var prov_data = GameManager.map_data[aktualni_provincie_id]
	var dostupni_rekruti = int(prov_data.get("recruitable_population", 0))
	
	var max_za_penize = int(GameManager.statni_kasa / cena_za_vojaka)
	var max_mozno = min(dostupni_rekruti, max_za_penize)
	
	if max_mozno <= 0:
		print("Nemáš lidi nebo peníze na vojáky!")
		return
		
	# Setup slider limits based on available resources
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = 0
	_on_slider_zmenen(0) 
	
	# Calculate popup position to appear directly above the recruit button
	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	
	recruit_popup.popup(rect)

# Updates the cost and amount text dynamically as the slider moves
func _on_slider_zmenen(hodnota: float):
	var cena = hodnota * cena_za_vojaka
	recruit_info.text = "Mužů: %d\nCena: %.2f mil." % [int(hodnota), cena]
	btn_potvrdit.disabled = (hodnota == 0)

# Finalizes the recruitment process
func _on_potvrdit_verbovani():
	var pocet_vojaku = int(recruit_slider.value)
	var celkova_cena = pocet_vojaku * cena_za_vojaka
	var prov_data = GameManager.map_data[aktualni_provincie_id]
	
	# Deduct cost and transfer recruits into active soldiers
	GameManager.statni_kasa -= celkova_cena
	prov_data["recruitable_population"] -= pocet_vojaku
	
	if not prov_data.has("soldiers"):
		prov_data["soldiers"] = 0
	prov_data["soldiers"] += pocet_vojaku
	
	recruit_popup.hide()
	zobraz_data(prov_data) # Redraw panel with updated numbers
	GameManager.kolo_zmeneno.emit()

# Utility function to format numbers with spaces (e.g., 1000000 -> 1 000 000)
func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
