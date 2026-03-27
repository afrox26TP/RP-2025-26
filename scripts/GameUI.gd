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
var _pause_menu_panel: PopupPanel
var _pause_confirm_dialog: ConfirmationDialog
var _pause_pending_action: String = ""
var _save_dialog: PopupPanel
var _save_name_input: LineEdit
var _load_dialog: PopupPanel
var _load_slot_list: ItemList
var _load_confirm_btn: Button
var _load_slot_names: Array = []

const POPUP_TOP_MARGIN := 6
const POPUP_GAP := 6
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

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
	_vytvor_pause_menu()
	_aktualizuj_pozice_popupu()
	_aktualizuj_popup_diplomatickych_zadosti()

func _on_system_message_ok_pressed():
	_system_message_ack = true
	if system_message_popup:
		system_message_popup.hide()
	_aktualizuj_pozice_popupu()

func _on_viewport_resized():
	_aktualizuj_pozice_popupu()
	_pozicuj_pause_menu()
	_pozicuj_save_load_popupy()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if _save_dialog and _save_dialog.visible:
				_save_dialog.hide()
				get_viewport().set_input_as_handled()
				return
			if _load_dialog and _load_dialog.visible:
				_load_dialog.hide()
				get_viewport().set_input_as_handled()
				return
			if system_message_popup and system_message_popup.visible:
				_on_system_message_ok_pressed()
			else:
				_prepni_pause_menu()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE and system_message_popup and system_message_popup.visible:
			_on_system_message_ok_pressed()
			get_viewport().set_input_as_handled()

func _vytvor_pause_menu() -> void:
	_pause_menu_panel = PopupPanel.new()
	_pause_menu_panel.name = "PauseMenu"
	_pause_menu_panel.size = Vector2(320, 352)
	add_child(_pause_menu_panel)

	var root_margin = MarginContainer.new()
	root_margin.offset_left = 12
	root_margin.offset_top = 12
	root_margin.offset_right = -12
	root_margin.offset_bottom = -12
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu_panel.add_child(root_margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	root_margin.add_child(vbox)

	var title = Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "ESC"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.pressed.connect(_on_pause_resume_pressed)
	vbox.add_child(btn_resume)

	var btn_options = Button.new()
	btn_options.text = "Options"
	btn_options.pressed.connect(_on_pause_options_pressed)
	vbox.add_child(btn_options)

	var btn_surrender = Button.new()
	btn_surrender.text = "Surrender"
	btn_surrender.pressed.connect(_on_pause_surrender_pressed)
	vbox.add_child(btn_surrender)

	var btn_save = Button.new()
	btn_save.text = "Save"
	btn_save.pressed.connect(_on_pause_save_pressed)
	vbox.add_child(btn_save)

	var btn_load = Button.new()
	btn_load.text = "Load"
	btn_load.pressed.connect(_on_pause_load_pressed)
	vbox.add_child(btn_load)

	var btn_quit = Button.new()
	btn_quit.text = "Quit"
	btn_quit.pressed.connect(_on_pause_quit_pressed)
	vbox.add_child(btn_quit)

	_pause_confirm_dialog = ConfirmationDialog.new()
	_pause_confirm_dialog.min_size = Vector2i(430, 160)
	_pause_confirm_dialog.confirmed.connect(_on_pause_confirmed)
	add_child(_pause_confirm_dialog)

	_vytvor_save_load_dialogy()

	_pause_menu_panel.hide()
	_pozicuj_pause_menu()
	_pozicuj_save_load_popupy()

func _pozicuj_pause_menu() -> void:
	if not _pause_menu_panel:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	_pause_menu_panel.position = Vector2((viewport_size.x - _pause_menu_panel.size.x) * 0.5, (viewport_size.y - _pause_menu_panel.size.y) * 0.5)

func _prepni_pause_menu() -> void:
	if not _pause_menu_panel:
		return
	if _pause_menu_panel.visible:
		_pause_menu_panel.hide()
	else:
		_pozicuj_pause_menu()
		_pause_menu_panel.popup()

func _zavri_pause_menu() -> void:
	if _pause_menu_panel:
		_pause_menu_panel.hide()

func _zobraz_pause_confirm(action: String, title: String, text: String) -> void:
	if not _pause_confirm_dialog:
		return
	_pause_pending_action = action
	_pause_confirm_dialog.title = title
	_pause_confirm_dialog.dialog_text = text
	_pause_confirm_dialog.popup_centered()

func _vytvor_save_load_dialogy() -> void:
	_save_dialog = PopupPanel.new()
	_save_dialog.name = "SaveDialog"
	_save_dialog.size = Vector2(430, 190)
	add_child(_save_dialog)

	var save_margin = MarginContainer.new()
	save_margin.offset_left = 12
	save_margin.offset_top = 12
	save_margin.offset_right = -12
	save_margin.offset_bottom = -12
	save_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_dialog.add_child(save_margin)

	var save_vbox = VBoxContainer.new()
	save_vbox.add_theme_constant_override("separation", 10)
	save_margin.add_child(save_vbox)

	var save_title = Label.new()
	save_title.text = "Save game"
	save_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_title.add_theme_font_size_override("font_size", 20)
	save_vbox.add_child(save_title)

	var save_hint = Label.new()
	save_hint.text = "Zadej jmeno save slotu"
	save_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_vbox.add_child(save_hint)

	_save_name_input = LineEdit.new()
	_save_name_input.placeholder_text = "napr. france_turn12"
	_save_name_input.text_submitted.connect(func(_t): _on_save_dialog_confirm_pressed())
	save_vbox.add_child(_save_name_input)

	var save_btns = HBoxContainer.new()
	save_btns.add_theme_constant_override("separation", 8)
	save_vbox.add_child(save_btns)

	var save_confirm_btn = Button.new()
	save_confirm_btn.text = "Ulozit"
	save_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_confirm_btn.pressed.connect(_on_save_dialog_confirm_pressed)
	save_btns.add_child(save_confirm_btn)

	var save_cancel_btn = Button.new()
	save_cancel_btn.text = "Zrusit"
	save_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_cancel_btn.pressed.connect(func(): _save_dialog.hide())
	save_btns.add_child(save_cancel_btn)

	_load_dialog = PopupPanel.new()
	_load_dialog.name = "LoadDialog"
	_load_dialog.size = Vector2(460, 320)
	add_child(_load_dialog)

	var load_margin = MarginContainer.new()
	load_margin.offset_left = 12
	load_margin.offset_top = 12
	load_margin.offset_right = -12
	load_margin.offset_bottom = -12
	load_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_dialog.add_child(load_margin)

	var load_vbox = VBoxContainer.new()
	load_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_vbox.add_theme_constant_override("separation", 8)
	load_margin.add_child(load_vbox)

	var load_title = Label.new()
	load_title.text = "Load game"
	load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_title.add_theme_font_size_override("font_size", 20)
	load_vbox.add_child(load_title)

	_load_slot_list = ItemList.new()
	_load_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_slot_list.allow_reselect = true
	load_vbox.add_child(_load_slot_list)

	var load_btns = HBoxContainer.new()
	load_btns.add_theme_constant_override("separation", 8)
	load_vbox.add_child(load_btns)

	_load_confirm_btn = Button.new()
	_load_confirm_btn.text = "Nacist"
	_load_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_confirm_btn.pressed.connect(_on_load_dialog_confirm_pressed)
	load_btns.add_child(_load_confirm_btn)

	var load_refresh_btn = Button.new()
	load_refresh_btn.text = "Obnovit"
	load_refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_refresh_btn.pressed.connect(_obnov_load_sloty)
	load_btns.add_child(load_refresh_btn)

	var load_cancel_btn = Button.new()
	load_cancel_btn.text = "Zrusit"
	load_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_cancel_btn.pressed.connect(func(): _load_dialog.hide())
	load_btns.add_child(load_cancel_btn)

	_save_dialog.hide()
	_load_dialog.hide()

func _pozicuj_save_load_popupy() -> void:
	if _save_dialog:
		var vp = get_viewport().get_visible_rect().size
		_save_dialog.position = Vector2((vp.x - _save_dialog.size.x) * 0.5, (vp.y - _save_dialog.size.y) * 0.5)
	if _load_dialog:
		var vp2 = get_viewport().get_visible_rect().size
		_load_dialog.position = Vector2((vp2.x - _load_dialog.size.x) * 0.5, (vp2.y - _load_dialog.size.y) * 0.5)

func _vygeneruj_default_jmeno_save() -> String:
	return "save_%s" % Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")

func _obnov_load_sloty() -> void:
	if not _load_slot_list:
		return

	_load_slot_list.clear()
	_load_slot_names.clear()
	var sloty: Array = []
	if GameManager and GameManager.has_method("ziskej_save_sloty"):
		sloty = GameManager.ziskej_save_sloty()

	for s in sloty:
		var d = s as Dictionary
		var slot_name = str(d.get("name", ""))
		if slot_name == "":
			continue
		_load_slot_list.add_item(slot_name)
		_load_slot_names.append(slot_name)

	if _load_slot_list.get_item_count() == 0 and FileAccess.file_exists("user://savegame.dat"):
		_load_slot_list.add_item("quicksave (legacy)")
		_load_slot_names.append("__legacy__")

	if _load_slot_list.get_item_count() > 0:
		_load_slot_list.select(0)
	if _load_confirm_btn:
		_load_confirm_btn.disabled = _load_slot_list.get_item_count() == 0

func _on_save_dialog_confirm_pressed() -> void:
	if not _save_name_input:
		return

	var slot_name = _save_name_input.text.strip_edges()
	if slot_name == "":
		slot_name = _vygeneruj_default_jmeno_save()

	var ok = false
	if GameManager and GameManager.has_method("uloz_hru_do_slotu"):
		ok = bool(GameManager.uloz_hru_do_slotu(slot_name))
	elif GameManager and GameManager.has_method("uloz_hru"):
		ok = bool(GameManager.uloz_hru())

	if ok:
		_save_dialog.hide()
		await zobraz_systemove_hlaseni("Save", "Hra byla ulozena do slotu: %s" % slot_name)
	else:
		await zobraz_systemove_hlaseni("Save", "Ulozeni se nepodarilo.")

func _on_load_dialog_confirm_pressed() -> void:
	if not _load_slot_list:
		return
	var selected = _load_slot_list.get_selected_items()
	if selected.is_empty():
		return

	var idx = int(selected[0])
	if idx < 0 or idx >= _load_slot_names.size():
		return

	var slot_name = str(_load_slot_names[idx])
	var ok = false
	if slot_name == "__legacy__" and GameManager and GameManager.has_method("nacti_hru"):
		ok = bool(GameManager.nacti_hru())
	elif GameManager and GameManager.has_method("nacti_hru_ze_slotu"):
		ok = bool(GameManager.nacti_hru_ze_slotu(slot_name))
	elif GameManager and GameManager.has_method("nacti_hru"):
		ok = bool(GameManager.nacti_hru())

	if ok:
		_load_dialog.hide()
		await zobraz_systemove_hlaseni("Load", "Hra byla nactena ze slotu: %s" % slot_name)
	else:
		await zobraz_systemove_hlaseni("Load", "Nacteni se nepodarilo.")

func _on_pause_resume_pressed() -> void:
	_zavri_pause_menu()

func _on_pause_options_pressed() -> void:
	_zavri_pause_menu()
	await zobraz_systemove_hlaseni("Options", "Nastaveni bude doplneno v dalsi iteraci.")

func _on_pause_surrender_pressed() -> void:
	_zobraz_pause_confirm("surrender", "Surrender", "Opravdu se chces vzdat za aktualni stat?")

func _on_pause_save_pressed() -> void:
	_zavri_pause_menu()
	if _save_name_input:
		_save_name_input.text = _vygeneruj_default_jmeno_save()
	if _save_dialog:
		_pozicuj_save_load_popupy()
		_save_dialog.popup()
		if _save_name_input:
			_save_name_input.grab_focus()
			_save_name_input.select_all()

func _on_pause_load_pressed() -> void:
	_zavri_pause_menu()
	_obnov_load_sloty()
	if _load_dialog:
		_pozicuj_save_load_popupy()
		_load_dialog.popup()

func _on_pause_quit_pressed() -> void:
	_zobraz_pause_confirm("quit", "Quit", "Opravdu se chces vratit do hlavniho menu?")

func _on_pause_confirmed() -> void:
	var action = _pause_pending_action
	_pause_pending_action = ""
	_zavri_pause_menu()

	if action == "surrender":
		var current_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
		var map_loader = get_tree().current_scene.find_child("Map", true, false)
		if map_loader and map_loader.has_method("hrac_se_vzdal") and bool(map_loader.hrac_se_vzdal(current_tag)):
			if GameManager.has_method("odeber_lidsky_stat"):
				GameManager.odeber_lidsky_stat(current_tag)
			if GameManager.lokalni_hraci_staty.is_empty():
				await zobraz_systemove_hlaseni("Surrender", "Vzdal ses. Vracim se do hlavniho menu.")
				get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
				return
			await zobraz_systemove_hlaseni("Surrender", "Stat %s kapituloval." % current_tag)
		else:
			await zobraz_systemove_hlaseni("Surrender", "Vzdat se se nepodarilo.")
		return

	if action == "quit":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

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
