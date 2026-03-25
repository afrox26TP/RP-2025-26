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
@onready var btn_presunout = $ActionMenu/HBoxContainer/PresunoutButton
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

# Paths to the recruitment popup panel elements
@onready var recruit_popup = $ActionMenu/RecruitPopup
@onready var recruit_info = $ActionMenu/RecruitPopup/VBoxContainer/RecruitInfo
@onready var recruit_slider = $ActionMenu/RecruitPopup/VBoxContainer/RecruitSlider
@onready var btn_potvrdit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/PotvrditBtn
@onready var btn_zrusit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/ZrusitBtn

# --- NEW: Paths to the Move popup panel elements ---
@onready var move_popup = $ActionMenu/MovePopup
@onready var move_count_label = $ActionMenu/MovePopup/VBoxContainer/CountLabel
@onready var move_slider = $ActionMenu/MovePopup/VBoxContainer/HSlider
@onready var btn_move_potvrdit = $ActionMenu/MovePopup/VBoxContainer/HBoxContainer/PotvrditButton
@onready var btn_move_zrusit = $ActionMenu/MovePopup/VBoxContainer/HBoxContainer/ZrusitButton

var presun_od_id: int = -1
var presun_do_id: int = -1
# ---------------------------------------------------

var aktualni_provincie_id: int = -1
var cena_za_vojaka: float = 0.05 # Cost: 50 mil. per 1000 men

func _ready():
	action_menu.hide()
	if move_popup: move_popup.hide()
	
	var popup_stavba = btn_stavet.get_popup()
	popup_stavba.clear()
	popup_stavba.add_item("Civilní továrna (150 mil.)", 0)
	popup_stavba.add_item("Zbrojovka (200 mil.)", 1)
	popup_stavba.add_item("Přístav (250 mil.)", 2)
	popup_stavba.id_pressed.connect(_on_stavba_vybrana)
	popup_stavba.about_to_popup.connect(_posun_stavba_menu)

	if btn_presunout: btn_presunout.pressed.connect(_on_presunout_pressed)
	btn_verbovat.pressed.connect(_on_verbovat_pressed)
	recruit_slider.value_changed.connect(_on_slider_zmenen)
	btn_potvrdit.pressed.connect(_on_potvrdit_verbovani)
	btn_zrusit.pressed.connect(func(): recruit_popup.hide())
	
	# --- NEW: Připojení tlačítek pro přesun ---
	if move_slider: move_slider.value_changed.connect(_on_move_slider_zmenen)
	if btn_move_potvrdit: btn_move_potvrdit.pressed.connect(_on_potvrdit_presun)
	if btn_move_zrusit: btn_move_zrusit.pressed.connect(func(): move_popup.hide())

func _posun_stavba_menu():
	var p = btn_stavet.get_popup()
	p.position.y = btn_stavet.global_position.y - p.size.y - 5

func schovej_se():
	$PanelContainer.hide()
	action_menu.hide()
	recruit_popup.hide()
	if move_popup: move_popup.hide()
	aktualni_provincie_id = -1

func zobraz_data(data: Dictionary):
	if data.is_empty():
		schovej_se()
		return
	
	$PanelContainer.show()
	recruit_popup.hide() 
	if move_popup: move_popup.hide()
	aktualni_provincie_id = data.get("id", -1)
	
	var owner = str(data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(data.get("army_owner", "")).strip_edges().to_upper()
	var core_owner = str(data.get("core_owner", owner)).strip_edges().to_upper()
	var je_more = (owner == "SEA")
	var je_moje = (owner == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat and int(data.get("soldiers", 0)) > 0)
	var vojaci = int(data.get("soldiers", 0))
	
	id_label.text = "Provincie: " + str(data.get("province_name", "Neznamo"))
	if je_more and armada_owner != "":
		owner_label.text = "Vlastnik: SEA (námořní armáda: %s)" % armada_owner
	elif core_owner != "" and core_owner != owner:
		owner_label.text = "Vlastnik: %s (okupace, core: %s)" % [owner, core_owner]
	else:
		owner_label.text = "Vlastnik: " + owner
	
	if je_more:
		pop_label.hide()
		recruit_label.hide()
		gdp_label.hide()
		income_label.hide()
		if vojaci > 0:
			soldiers_label.show()
			if armada_owner != "":
				soldiers_label.text = "Flotila (%s): %s mužů" % [armada_owner, _formatuj_cislo(vojaci)]
			else:
				soldiers_label.text = "Flotila: " + _formatuj_cislo(vojaci) + " mužů"
		else:
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
		
		soldiers_label.text = "Posádka: " + _formatuj_cislo(vojaci) + " mužů"
		
		if je_moje:
			income_label.show()
			income_label.text = "Příjem: +%.2f mil. USD" % (gdp * 0.05)
		else:
			income_label.hide()

	if (je_moje and not je_more) or je_moje_armada_na_mori:
		var muze_stavet = (je_moje and not je_more)
		btn_stavet.visible = muze_stavet
		btn_verbovat.visible = muze_stavet
		btn_likvidovat.visible = muze_stavet

		if not muze_stavet:
			btn_stavet.disabled = true
			btn_stavet.text = "Stavět"
			btn_verbovat.disabled = true
			btn_likvidovat.disabled = true

		if muze_stavet:
			if GameManager.provincie_cooldowny.has(aktualni_provincie_id):
				var zbyva_kol = GameManager.provincie_cooldowny[aktualni_provincie_id]["zbyva"]
				btn_stavet.disabled = true
				btn_stavet.text = "Staví se (%d kol)" % zbyva_kol
			elif GameManager.provincie_ma_pristav(aktualni_provincie_id):
				btn_stavet.disabled = false
				btn_stavet.text = "Stavět (Přístav postaven)"
			else:
				btn_stavet.disabled = false
				btn_stavet.text = "Stavět"
			
		if btn_presunout:
			btn_presunout.visible = (vojaci > 0)
			
		if muze_stavet:
			btn_verbovat.disabled = false
			btn_likvidovat.disabled = false
		action_menu.show()
	else:
		action_menu.hide()

func _on_presunout_pressed():
	if aktualni_provincie_id == -1: return
	
	var prov_data = GameManager.map_data.get(aktualni_provincie_id, {})
	var dostupni_vojaci = int(prov_data.get("soldiers", 0))
	if dostupni_vojaci <= 0: return
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("aktivuj_rezim_vyberu_cile"):
		map_loader = get_parent()
			
	if map_loader and map_loader.has_method("aktivuj_rezim_vyberu_cile"):
		map_loader.aktivuj_rezim_vyberu_cile(aktualni_provincie_id, dostupni_vojaci)
		
	schovej_se()

# --- NEW: Zobrazí slider po úspěšném kliknutí na souseda v mapě ---
func zobraz_presun_slider(from_id: int, to_id: int, max_troops: int):
	presun_od_id = from_id
	presun_do_id = to_id
	
	move_slider.min_value = 1
	move_slider.max_value = max_troops
	move_slider.value = max_troops # Základně navolí všechny vojáky
	
	_on_move_slider_zmenen(max_troops)
	
	# Zobrazíme popup (pokud je to PopupPanel, použije popup_centered)
	if move_popup is Popup:
		move_popup.popup_centered()
	else:
		move_popup.show()

func _on_move_slider_zmenen(hodnota: float):
	if move_count_label:
		move_count_label.text = _formatuj_cislo(int(hodnota)) + " vojáků"

func _on_potvrdit_presun():
	var amount = int(move_slider.value)
	move_popup.hide()
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("zaregistruj_presun_armady"):
		map_loader = get_parent()
		
	if map_loader and map_loader.has_method("zaregistruj_presun_armady"):
		map_loader.zaregistruj_presun_armady(presun_od_id, presun_do_id, amount)
# ------------------------------------------------------------------

func _on_stavba_vybrana(id: int):
	if aktualni_provincie_id == -1: return
	var cena = 150.0
	if id == 1:
		cena = 200.0
	elif id == 2:
		cena = 250.0

	if id == 2:
		if not GameManager.muze_postavit_pristav(aktualni_provincie_id):
			_ukaz_stavbu_info("PŘÍSTAV", "Přístav lze stavět pouze ve vlastní pobřežní provincii sousedící s mořem a jen jednou.")
			return
	
	if GameManager.statni_kasa >= cena:
		GameManager.statni_kasa -= cena
		GameManager.provincie_cooldowny[aktualni_provincie_id] = {"zbyva": 3, "budova": id}
		btn_stavet.disabled = true
		btn_stavet.text = "Staví se (3 kola)"
		GameManager.kolo_zmeneno.emit()
	else:
		_ukaz_stavbu_info("NEDOSTATEK PENĚZ", "Na tuto stavbu nemáš dost peněz.")

func _ukaz_stavbu_info(title: String, text: String):
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("_ukaz_bitevni_popup"):
		map_loader = get_parent()

	if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
		map_loader._ukaz_bitevni_popup(title, text)

func _on_verbovat_pressed():
	if aktualni_provincie_id == -1: return
	
	var prov_data = GameManager.map_data[aktualni_provincie_id]
	var dostupni_rekruti = int(prov_data.get("recruitable_population", 0))
	var max_za_penize = int(GameManager.statni_kasa / cena_za_vojaka)
	var max_mozno = min(dostupni_rekruti, max_za_penize)
	
	if max_mozno <= 0: return
		
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = 0
	_on_slider_zmenen(0) 
	
	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	recruit_popup.popup(rect)

func _on_slider_zmenen(hodnota: float):
	var cena = hodnota * cena_za_vojaka
	recruit_info.text = "Mužů: %d\nCena: %.2f mil." % [int(hodnota), cena]
	btn_potvrdit.disabled = (hodnota == 0)

func _on_potvrdit_verbovani():
	var pocet_vojaku = int(recruit_slider.value)
	var celkova_cena = pocet_vojaku * cena_za_vojaka
	var prov_data = GameManager.map_data[aktualni_provincie_id]
	
	GameManager.statni_kasa -= celkova_cena
	prov_data["recruitable_population"] -= pocet_vojaku
	
	if not prov_data.has("soldiers"): prov_data["soldiers"] = 0
	prov_data["soldiers"] += pocet_vojaku
	
	recruit_popup.hide()
	zobraz_data(prov_data) 
	GameManager.kolo_zmeneno.emit()

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0: vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
