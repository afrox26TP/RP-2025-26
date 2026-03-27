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
@onready var alliance_level_option = $OverviewPanel/VBoxContainer/AllianceLevelOption
@onready var declare_war_btn = $OverviewPanel/VBoxContainer/DeclareWarButton
@onready var propose_peace_btn = $OverviewPanel/VBoxContainer/ProposePeaceButton
@onready var non_aggression_btn = $OverviewPanel/VBoxContainer/NonAggressionButton
@onready var incoming_request_label = $OverviewPanel/VBoxContainer/IncomingRequestLabel
@onready var respond_request_buttons = $OverviewPanel/VBoxContainer/RespondRequestButtons
@onready var accept_request_btn = $OverviewPanel/VBoxContainer/RespondRequestButtons/AcceptRequestButton
@onready var decline_request_btn = $OverviewPanel/VBoxContainer/RespondRequestButtons/DeclineRequestButton
@onready var diplomacy_request_popup = $DiplomacyRequestPopup
@onready var popup_request_flag = $DiplomacyRequestPopup/HBoxContainer/RequestFlag
@onready var popup_request_text = $DiplomacyRequestPopup/HBoxContainer/RequestText
@onready var popup_accept_btn = $DiplomacyRequestPopup/HBoxContainer/AcceptButton
@onready var popup_decline_btn = $DiplomacyRequestPopup/HBoxContainer/DeclineButton
@onready var system_message_popup = $SystemMessagePopup
@onready var system_message_title = $SystemMessagePopup/VBoxContainer/MessageTitle
@onready var system_message_text = $SystemMessagePopup/VBoxContainer/MessageText
@onready var system_message_ok_btn = $SystemMessagePopup/VBoxContainer/MessageOkButton

# Store the currently viewed country tag
var current_viewed_tag: String = ""
var flag_texture_cache: Dictionary = {}
var _updating_alliance_ui: bool = false
var _current_incoming_request: Dictionary = {}
var _popup_request_from_tag: String = ""
var _system_message_ack: bool = false

const POPUP_TOP_MARGIN := 6
const POPUP_GAP := 6

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

func _ziskej_jmeno_statu_podle_tagu(tag: String) -> String:
	var cisty = tag.strip_edges().to_upper()
	if cisty == "":
		return ""
	if GameManager.map_data.is_empty():
		return cisty
	for p_id in GameManager.map_data:
		var d = GameManager.map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == cisty:
			var name = str(d.get("country_name", cisty)).strip_edges()
			return name if name != "" else cisty
	return cisty

func _ready():
	panel.hide()
	_napln_aliance_option()
	
	# Automatically connect the button signal if it exists
	if declare_war_btn and not declare_war_btn.pressed.is_connected(_on_declare_war_button_pressed):
		declare_war_btn.pressed.connect(_on_declare_war_button_pressed)
	if propose_peace_btn and not propose_peace_btn.pressed.is_connected(_on_propose_peace_button_pressed):
		propose_peace_btn.pressed.connect(_on_propose_peace_button_pressed)
	if non_aggression_btn and not non_aggression_btn.pressed.is_connected(_on_non_aggression_button_pressed):
		non_aggression_btn.pressed.connect(_on_non_aggression_button_pressed)
	if accept_request_btn and not accept_request_btn.pressed.is_connected(_on_accept_request_pressed):
		accept_request_btn.pressed.connect(_on_accept_request_pressed)
	if decline_request_btn and not decline_request_btn.pressed.is_connected(_on_decline_request_pressed):
		decline_request_btn.pressed.connect(_on_decline_request_pressed)
	if popup_accept_btn and not popup_accept_btn.pressed.is_connected(_on_popup_accept_request_pressed):
		popup_accept_btn.pressed.connect(_on_popup_accept_request_pressed)
	if popup_decline_btn and not popup_decline_btn.pressed.is_connected(_on_popup_decline_request_pressed):
		popup_decline_btn.pressed.connect(_on_popup_decline_request_pressed)
	if system_message_ok_btn and not system_message_ok_btn.pressed.is_connected(_on_system_message_ok_pressed):
		system_message_ok_btn.pressed.connect(_on_system_message_ok_pressed)
	if improve_rel_btn and not improve_rel_btn.pressed.is_connected(_on_improve_relationship_pressed):
		improve_rel_btn.pressed.connect(_on_improve_relationship_pressed)
	if worsen_rel_btn and not worsen_rel_btn.pressed.is_connected(_on_worsen_relationship_pressed):
		worsen_rel_btn.pressed.connect(_on_worsen_relationship_pressed)
	if alliance_level_option and not alliance_level_option.item_selected.is_connected(_on_alliance_level_selected):
		alliance_level_option.item_selected.connect(_on_alliance_level_selected)
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)
	if diplomacy_request_popup:
		diplomacy_request_popup.hide()
	if system_message_popup:
		system_message_popup.hide()
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_aktualizuj_pozice_popupu()
	_aktualizuj_popup_diplomatickych_zadosti()

func _on_system_message_ok_pressed():
	_system_message_ack = true
	if system_message_popup:
		system_message_popup.hide()
	_aktualizuj_pozice_popupu()

func _on_viewport_resized():
	_aktualizuj_pozice_popupu()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE and system_message_popup and system_message_popup.visible:
			_on_system_message_ok_pressed()
			get_viewport().set_input_as_handled()

func _topbar_bottom_y() -> float:
	var topbar = get_tree().current_scene.find_child("TopBar", true, false)
	if topbar and topbar is CanvasLayer:
		var panel = topbar.find_child("Panel", true, false)
		if panel and panel is Control:
			return (panel as Control).global_position.y + (panel as Control).size.y
	return 35.0

func _aktualizuj_pozice_popupu():
	var viewport_size = get_viewport().get_visible_rect().size
	var top_y = _topbar_bottom_y() + POPUP_TOP_MARGIN

	if diplomacy_request_popup:
		var req_w = clamp(viewport_size.x * 0.50, 500.0, 820.0)
		var req_text_len = 0
		if popup_request_text:
			req_text_len = popup_request_text.text.length()
			popup_request_text.clip_text = false
		var req_lines = max(1, int(ceil(float(req_text_len) / max(24.0, req_w / 10.0))))
		var req_h = clamp(34.0 + float(req_lines) * 14.0, 48.0, 78.0)
		diplomacy_request_popup.position = Vector2((viewport_size.x - req_w) * 0.5, top_y)
		diplomacy_request_popup.size = Vector2(req_w, req_h)

	if system_message_popup:
		var msg_w = clamp(viewport_size.x * 0.42, 440.0, 760.0)
		var text_len = 0
		var explicit_lines = 1
		if system_message_text:
			text_len = system_message_text.text.length()
			explicit_lines = max(1, system_message_text.text.split("\n").size())
			system_message_text.clip_text = false
		var wrap_lines = max(1, int(ceil(float(text_len) / max(28.0, msg_w / 9.0))))
		var approx_lines = max(explicit_lines, wrap_lines)
		var msg_y = top_y
		if diplomacy_request_popup and diplomacy_request_popup.visible:
			msg_y += diplomacy_request_popup.size.y + POPUP_GAP
		var max_msg_h = max(110.0, viewport_size.y - msg_y - 12.0)
		var msg_h = clamp(96.0 + float(approx_lines) * 18.0, 110.0, max_msg_h)
		system_message_popup.position = Vector2((viewport_size.x - msg_w) * 0.5, msg_y)
		system_message_popup.size = Vector2(msg_w, msg_h)
		if system_message_text:
			var text_area_h = max(42.0, msg_h - 68.0)
			system_message_text.custom_minimum_size = Vector2(0.0, text_area_h)

func zobraz_systemove_hlaseni(titulek: String, text: String) -> void:
	if not system_message_popup:
		return
	if system_message_title:
		system_message_title.text = titulek if titulek.strip_edges() != "" else "Hlaseni"
	if system_message_text:
		system_message_text.text = text

	_system_message_ack = false
	_aktualizuj_pozice_popupu()
	system_message_popup.show()

	while is_instance_valid(system_message_popup) and system_message_popup.visible and not _system_message_ack:
		await get_tree().process_frame

func _napln_aliance_option():
	if not alliance_level_option:
		return
	alliance_level_option.clear()
	alliance_level_option.add_item("[ ] Bez aliance", 0)
	alliance_level_option.add_item("[D] Obranna (obrana spojence)", 1)
	alliance_level_option.add_item("[O] Utocna (spolecny utok)", 2)
	alliance_level_option.add_item("[F] Plna (obrana + utok)", 3)

func _aktualizuj_zadost_ui(target_tag: String):
	_current_incoming_request = {}
	if incoming_request_label:
		incoming_request_label.hide()
	if respond_request_buttons:
		respond_request_buttons.hide()

func _aktualizuj_popup_diplomatickych_zadosti():
	_popup_request_from_tag = ""
	if not diplomacy_request_popup:
		return
	if not GameManager.has_method("ziskej_prvni_cekajici_diplomatickou_zadost"):
		diplomacy_request_popup.hide()
		return

	var req = GameManager.ziskej_prvni_cekajici_diplomatickou_zadost(GameManager.hrac_stat)
	if req.is_empty():
		diplomacy_request_popup.hide()
		return

	var from_tag = str(req.get("from", "")).strip_edges().to_upper()
	if from_tag == "":
		diplomacy_request_popup.hide()
		return
	_popup_request_from_tag = from_tag

	if popup_request_flag:
		popup_request_flag.texture = _resolve_flag_texture(from_tag, "")
	if popup_request_text:
		var req_type = str(req.get("type", ""))
		var country_name = _ziskej_jmeno_statu_podle_tagu(from_tag)
		var display_name = "%s (%s)" % [country_name, from_tag]
		if req_type == "alliance":
			var level = int(req.get("level", 0))
			var level_text = "alianci"
			match level:
				1:
					level_text = "obrannou alianci"
				2:
					level_text = "utocnou alianci"
				3:
					level_text = "plnou alianci"
			popup_request_text.text = "%s navrhuje %s" % [display_name, level_text]
		elif req_type == "peace":
			popup_request_text.text = "%s navrhuje uzavrit mir" % display_name
		else:
			popup_request_text.text = "%s navrhuje neagresivni smlouvu (10 kol)" % display_name

	diplomacy_request_popup.show()
	_aktualizuj_pozice_popupu()

func _aktualizuj_aliance_ui(target_tag: String):
	if not alliance_level_option:
		return

	if not GameManager.has_method("ziskej_uroven_aliance"):
		alliance_level_option.hide()
		return

	var level = int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, target_tag))
	var rel = 0.0
	if GameManager.has_method("ziskej_vztah_statu"):
		rel = float(GameManager.ziskej_vztah_statu(GameManager.hrac_stat, target_tag))

	var at_war = GameManager.jsou_ve_valce(GameManager.hrac_stat, target_tag)
	var alliance_request_pending = false
	if GameManager.has_method("je_aliancni_zadost_cekajici"):
		alliance_request_pending = bool(GameManager.je_aliancni_zadost_cekajici(GameManager.hrac_stat, target_tag))

	_updating_alliance_ui = true
	alliance_level_option.select(clamp(level, 0, 3))
	alliance_level_option.disabled = at_war or alliance_request_pending
	if at_war:
		alliance_level_option.tooltip_text = "Během války nelze měnit alianci."
	elif alliance_request_pending:
		alliance_level_option.tooltip_text = "Žádost o alianci už byla odeslána. Čeká se na odpověď."
	elif rel < 60.0:
		alliance_level_option.tooltip_text = "Pro obrannou alianci je potřeba vztah alespoň 60."
	elif rel < 75.0:
		alliance_level_option.tooltip_text = "Pro útočnou alianci je potřeba vztah alespoň 75."
	elif rel < 90.0:
		alliance_level_option.tooltip_text = "Pro plnou alianci je potřeba vztah alespoň 90."
	else:
		alliance_level_option.tooltip_text = "Vyšší úroveň aliance odemyká širší call-to-war podporu."
	_updating_alliance_ui = false

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
			if alliance_level_option: alliance_level_option.hide()
			declare_war_btn.hide()
			propose_peace_btn.hide()
			if non_aggression_btn: non_aggression_btn.hide()
			if incoming_request_label: incoming_request_label.hide()
			if respond_request_buttons: respond_request_buttons.hide()
		else:
			_aktualizuj_vztah_ui(owner_tag)
			# Show actions for other countries
			action_separator.show()
			if improve_rel_btn: improve_rel_btn.show()
			if worsen_rel_btn: worsen_rel_btn.show()
			if alliance_level_option: alliance_level_option.show()
			_aktualizuj_aliance_ui(owner_tag)
			_aktualizuj_diplomacii_tlacitka(owner_tag)
			if non_aggression_btn: non_aggression_btn.show()
			_aktualizuj_zadost_ui(owner_tag)
	
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

func _on_non_aggression_button_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("uzavrit_neagresivni_smlouvu"):
		return

	var success = bool(GameManager.uzavrit_neagresivni_smlouvu(GameManager.hrac_stat, current_viewed_tag))
	if success:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_popup_accept_request_pressed():
	if _popup_request_from_tag == "":
		return
	if not GameManager.has_method("hrac_prijmi_diplomatickou_zadost"):
		return
	GameManager.hrac_prijmi_diplomatickou_zadost(GameManager.hrac_stat, _popup_request_from_tag)
	_aktualizuj_popup_diplomatickych_zadosti()
	if current_viewed_tag == _popup_request_from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_popup_decline_request_pressed():
	if _popup_request_from_tag == "":
		return
	if not GameManager.has_method("hrac_odmitni_diplomatickou_zadost"):
		return
	GameManager.hrac_odmitni_diplomatickou_zadost(GameManager.hrac_stat, _popup_request_from_tag)
	_aktualizuj_popup_diplomatickych_zadosti()
	if current_viewed_tag == _popup_request_from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_accept_request_pressed():
	if current_viewed_tag == "" or _current_incoming_request.is_empty():
		return
	if not GameManager.has_method("hrac_prijmi_diplomatickou_zadost"):
		return
	GameManager.hrac_prijmi_diplomatickou_zadost(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_zadost_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_popup_diplomatickych_zadosti()

func _on_decline_request_pressed():
	if current_viewed_tag == "" or _current_incoming_request.is_empty():
		return
	if not GameManager.has_method("hrac_odmitni_diplomatickou_zadost"):
		return
	GameManager.hrac_odmitni_diplomatickou_zadost(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_zadost_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_popup_diplomatickych_zadosti()

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
	_aktualizuj_aliance_ui(current_viewed_tag)

func _on_alliance_level_selected(index: int):
	if _updating_alliance_ui:
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("nastav_uroven_aliance"):
		return

	var current_level = 0
	if GameManager.has_method("ziskej_uroven_aliance"):
		current_level = int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, current_viewed_tag))

	var target_is_ai = true
	if GameManager.has_method("je_lidsky_stat"):
		target_is_ai = not bool(GameManager.je_lidsky_stat(current_viewed_tag))

	if index > current_level and GameManager.has_method("odeslat_aliancni_zadost"):
		var ignorovat_vztah = not target_is_ai
		var sent = bool(GameManager.odeslat_aliancni_zadost(GameManager.hrac_stat, current_viewed_tag, index, ignorovat_vztah))
		if sent:
			_aktualizuj_aliance_ui(current_viewed_tag)
			_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
		return

	var success = bool(GameManager.nastav_uroven_aliance(GameManager.hrac_stat, current_viewed_tag, index))
	if not success:
		_aktualizuj_aliance_ui(current_viewed_tag)
		return

	_aktualizuj_aliance_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_kolo_zmeneno():
	_aktualizuj_popup_diplomatickych_zadosti()
	if current_viewed_tag == "" or not panel.visible:
		return
	_aktualizuj_vztah_ui(current_viewed_tag)
	_aktualizuj_aliance_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_zadost_ui(current_viewed_tag)

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

	_aktualizuj_aliance_ui(target_tag)
	_aktualizuj_diplomacii_tlacitka(target_tag)
	_aktualizuj_zadost_ui(target_tag)

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

		if alliance_level_option:
			alliance_level_option.disabled = true
		if non_aggression_btn:
			non_aggression_btn.text = "Neagresivni smlouva (nelze ve valce)"
			non_aggression_btn.disabled = true
			non_aggression_btn.modulate = Color(1, 1, 1)
	else:
		var alliance_level = 0
		if GameManager.has_method("ziskej_uroven_aliance"):
			alliance_level = int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, target_tag))
		var war_blocked_by_alliance = alliance_level > 0
		var has_non_aggression = false
		var non_aggression_turns_left = 0
		if GameManager.has_method("ma_neagresivni_smlouvu"):
			has_non_aggression = bool(GameManager.ma_neagresivni_smlouvu(GameManager.hrac_stat, target_tag))
		if has_non_aggression and GameManager.has_method("zbyva_kol_neagresivni_smlouvy"):
			non_aggression_turns_left = int(GameManager.zbyva_kol_neagresivni_smlouvy(GameManager.hrac_stat, target_tag))
		var war_blocked_by_non_aggression = has_non_aggression
		var war_blocked_by_peace_cooldown = false
		var peace_cooldown_turns_left = 0
		if GameManager.has_method("zbyva_kol_do_dalsi_valky"):
			peace_cooldown_turns_left = int(GameManager.zbyva_kol_do_dalsi_valky(GameManager.hrac_stat, target_tag))
			war_blocked_by_peace_cooldown = peace_cooldown_turns_left > 0

		if war_blocked_by_peace_cooldown:
			declare_war_btn.text = "Povalecny cooldown (%d kol)" % peace_cooldown_turns_left
		else:
			declare_war_btn.text = "Vyhlasit valku"
		declare_war_btn.disabled = war_blocked_by_alliance or war_blocked_by_non_aggression or war_blocked_by_peace_cooldown
		declare_war_btn.modulate = Color(1, 1, 1)
		declare_war_btn.show()

		propose_peace_btn.hide()

		if alliance_level_option:
			alliance_level_option.disabled = false

		if non_aggression_btn:
			var rel = 0.0
			if GameManager.has_method("ziskej_vztah_statu"):
				rel = float(GameManager.ziskej_vztah_statu(GameManager.hrac_stat, target_tag))
			if has_non_aggression:
				non_aggression_btn.text = "Neagresivni smlouva (%d kol)" % non_aggression_turns_left
				non_aggression_btn.disabled = true
				non_aggression_btn.modulate = Color(1, 1, 1)
			else:
				non_aggression_btn.text = "Neagresivni smlouva (10 kol)"
				non_aggression_btn.disabled = rel < 10.0
				non_aggression_btn.modulate = Color(1, 1, 1)
