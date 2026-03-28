extends CanvasLayer

const TooltipUtils = preload("res://scripts/TooltipUtils.gd")

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
var _overview_metric_rows: Dictionary = {}
var _overview_metric_deltas: Dictionary = {}
var _overview_preview_deltas: Dictionary = {}
var _save_dialog: PopupPanel
var _save_name_input: LineEdit
var _load_dialog: PopupPanel
var _load_slot_list: ItemList
var _load_confirm_btn: Button
var _load_slot_names: Array = []
var _gift_dialog: PopupPanel
var _gift_amount_input: LineEdit
var gift_money_btn: Button
var ideology_separator: HSeparator
var ideology_effects_label: RichTextLabel
var ideology_option: OptionButton
var ideology_apply_btn: Button
var _ideology_option_values: Array = []
var _popup_country_link_btn: LinkButton
var _camera_focus_tween: Tween
var _ideology_flag_path_index: Dictionary = {}
var _ideology_flag_index_ready: bool = false
var _updating_ideology_ui: bool = false
var _ideology_dropdown_open: bool = false
var _ideology_hover_idx: int = -1
var _ideology_effects_base_text: String = ""

const POPUP_TOP_MARGIN := 6
const POPUP_GAP := 6
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const IDEOLOGY_UI_ORDER := ["demokracie", "kralovstvi", "autokracie", "komunismus", "nacismus", "fasismus"]

func _resolve_flag_texture(owner_tag: String, ideologie: String):
	var cisty_tag = owner_tag.strip_edges().to_upper()
	var ideo = _normalizuj_ideologii(ideologie)
	if cisty_tag == "DEU":
		if ideo == "fasismus":
			ideo = "nacismus"
		elif ideo == "nacismus":
			ideo = "fasismus"
	if ideo != "" and ideo != "neznamo":
		_ensure_ideology_flag_index()
		var key = "%s|%s" % [cisty_tag, ideo]
		if _ideology_flag_path_index.has(key):
			var ideol_path = str(_ideology_flag_path_index[key])
			if ResourceLoader.exists(ideol_path):
				if not flag_texture_cache.has(ideol_path):
					flag_texture_cache[ideol_path] = load(ideol_path)
				return flag_texture_cache[ideol_path]

	var base_candidates = [
		"res://map_data/Flags/%s.svg" % owner_tag,
		"res://map_data/Flags/%s.png" % owner_tag
	]
	for path in base_candidates:
		if ResourceLoader.exists(path):
			if not flag_texture_cache.has(path):
				flag_texture_cache[path] = load(path)
			return flag_texture_cache[path]

	return null

func _ensure_ideology_flag_index() -> void:
	if _ideology_flag_index_ready:
		return
	_ideology_flag_index_ready = true
	_ideology_flag_path_index.clear()

	var dir = DirAccess.open("res://map_data/FlagsIdeology")
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue

		var lower = file_name.to_lower()
		if not (lower.ends_with(".svg") or lower.ends_with(".png")):
			continue
		if lower.ends_with(".import"):
			continue

		var tag := ""
		var ideo_raw := ""
		var sep_idx = lower.find("__")
		if sep_idx > 0:
			tag = lower.substr(0, sep_idx).to_upper()
			var ext_idx = lower.rfind(".")
			if ext_idx > sep_idx + 2:
				ideo_raw = lower.substr(sep_idx + 2, ext_idx - (sep_idx + 2))
		else:
			var one_idx = lower.find("_")
			var ext_idx2 = lower.rfind(".")
			if one_idx > 0 and ext_idx2 > one_idx + 1:
				tag = lower.substr(0, one_idx).to_upper()
				ideo_raw = lower.substr(one_idx + 1, ext_idx2 - (one_idx + 1))

		if tag == "" or ideo_raw == "":
			continue
		var ideo = _normalizuj_ideologii(ideo_raw)
		if ideo == "" or IDEOLOGY_UI_ORDER.find(ideo) == -1:
			continue

		var key = "%s|%s" % [tag, ideo]
		var path = "res://map_data/FlagsIdeology/%s" % file_name
		if not _ideology_flag_path_index.has(key):
			_ideology_flag_path_index[key] = path
			continue
		var current = str(_ideology_flag_path_index[key]).to_lower()
		if current.ends_with(".png") and lower.ends_with(".svg"):
			_ideology_flag_path_index[key] = path
	dir.list_dir_end()

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
	_setup_overview_inline_deltas()
	_zajisti_tlacitko_daru()
	_zajisti_ideology_controls()
	_setup_popup_country_link()
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
	if gift_money_btn and not gift_money_btn.pressed.is_connected(_on_gift_money_pressed):
		gift_money_btn.pressed.connect(_on_gift_money_pressed)
	if ideology_option and not ideology_option.item_selected.is_connected(_on_ideology_option_selected):
		ideology_option.item_selected.connect(_on_ideology_option_selected)
	if ideology_option and ideology_option.get_popup():
		var popup = ideology_option.get_popup()
		if popup.has_signal("about_to_popup") and not popup.about_to_popup.is_connected(_on_ideology_dropdown_opened):
			popup.about_to_popup.connect(_on_ideology_dropdown_opened)
		if popup.has_signal("id_focused") and not popup.id_focused.is_connected(_on_ideology_dropdown_item_focused):
			popup.id_focused.connect(_on_ideology_dropdown_item_focused)
		if popup.has_signal("popup_hide") and not popup.popup_hide.is_connected(_on_ideology_dropdown_closed):
			popup.popup_hide.connect(_on_ideology_dropdown_closed)
	if ideology_apply_btn and not ideology_apply_btn.pressed.is_connected(_on_apply_ideology_pressed):
		ideology_apply_btn.pressed.connect(_on_apply_ideology_pressed)
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
	_vytvor_darovaci_dialog()
	_nastav_tooltipy_ui()

func _process(_delta: float) -> void:
	if not _ideology_dropdown_open or ideology_option == null:
		set_process(false)
		return
	var popup = ideology_option.get_popup()
	if popup == null or not popup.visible:
		set_process(false)
		return
	if popup.has_method("get_focused_item"):
		var idx = int(popup.get_focused_item())
		if idx != _ideology_hover_idx:
			_on_ideology_dropdown_item_focused(idx)

func _setup_popup_country_link() -> void:
	var hbox = get_node_or_null("DiplomacyRequestPopup/HBoxContainer") as HBoxContainer
	if hbox and _popup_country_link_btn == null:
		_popup_country_link_btn = LinkButton.new()
		_popup_country_link_btn.name = "RequestCountryLink"
		_popup_country_link_btn.text = ""
		_popup_country_link_btn.focus_mode = Control.FOCUS_NONE
		_popup_country_link_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hbox.add_child(_popup_country_link_btn)
		hbox.move_child(_popup_country_link_btn, 1)
		_popup_country_link_btn.pressed.connect(_on_popup_country_reference_pressed)

	if popup_request_flag and not popup_request_flag.gui_input.is_connected(_on_popup_flag_gui_input):
		popup_request_flag.gui_input.connect(_on_popup_flag_gui_input)
		popup_request_flag.mouse_filter = Control.MOUSE_FILTER_STOP
		popup_request_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _nastav_tooltipy_ui() -> void:
	name_label.tooltip_text = "Nazev vybraneho statu."
	country_flag.tooltip_text = "Vlajka vybraneho statu."
	ideo_label.tooltip_text = "Aktualni politicke zrizeni statu."
	pop_label.tooltip_text = "Celkova populace statu."
	recruit_label.tooltip_text = "Dostupni rekruti celeho statu."
	gdp_label.tooltip_text = "Celkove HDP statu."
	gdp_pc_label.tooltip_text = "HDP prepocitane na jednoho obyvatele."
	relationship_label.tooltip_text = "Diplomaticky vztah mezi tvym statem a cilem."
	if ideology_option:
		ideology_option.tooltip_text = "Vyber nove ideologie pro tvuj stat."
	if ideology_effects_label:
		ideology_effects_label.tooltip_text = "Prehled vyhod a nevyhod zvolene ideologie."
	if ideology_apply_btn:
		ideology_apply_btn.tooltip_text = "Potvrdi prechod tvého statu na zvolenou ideologii."
	improve_rel_btn.tooltip_text = "Zlepsi vztah o 10 bodu."
	worsen_rel_btn.tooltip_text = "Zhorsi vztah o 10 bodu."
	if gift_money_btn:
		gift_money_btn.tooltip_text = "Posle cilovemu statu financni dar."
	declare_war_btn.tooltip_text = "Vyhlasi valku vybranemu statu."
	propose_peace_btn.tooltip_text = "Posle navrh na uzavreni miru."
	non_aggression_btn.tooltip_text = "Uzavre neagresivni smlouvu na 10 kol."
	incoming_request_label.tooltip_text = "Zobrazuje prichozi diplomatickou zadost."
	accept_request_btn.tooltip_text = "Prijme zobrazenou diplomatickou zadost."
	decline_request_btn.tooltip_text = "Odmita zobrazenou diplomatickou zadost."
	popup_request_flag.tooltip_text = "Klikni pro otevreni prehledu tohoto statu."
	if _popup_country_link_btn:
		_popup_country_link_btn.tooltip_text = "Klikni pro otevreni prehledu tohoto statu."
	popup_request_text.tooltip_text = "Strucny popis diplomaticke nabidky."
	popup_accept_btn.tooltip_text = "Prijme diplomatickou nabidku."
	popup_decline_btn.tooltip_text = "Odmita diplomatickou nabidku."
	system_message_title.tooltip_text = "Titulek systemoveho hlaseni."
	system_message_text.tooltip_text = "Detailni text systemoveho hlaseni."
	system_message_ok_btn.tooltip_text = "Potvrdi a zavre hlaseni."
	TooltipUtils.apply_default_tooltips(self)

func _on_popup_flag_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_popup_country_reference_pressed()

func _on_popup_country_reference_pressed() -> void:
	_otevri_prehled_statu_podle_tagu(_popup_request_from_tag)

func _ziskej_map_loader_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("_ziskej_map_pozici_provincie") and scene_root.has_method("_ziskej_map_offset"):
		return scene_root
	if scene_root:
		var by_name = scene_root.find_child("Map", true, false)
		if by_name and by_name.has_method("_ziskej_map_pozici_provincie") and by_name.has_method("_ziskej_map_offset"):
			return by_name
	return null

func _otevri_prehled_statu_podle_tagu(tag: String) -> void:
	var wanted = tag.strip_edges().to_upper()
	if wanted == "" or wanted == "SEA":
		return

	var provinces: Dictionary = {}
	var map_loader = _ziskej_map_loader_node()
	if map_loader:
		var maybe_provinces = map_loader.get("provinces")
		if maybe_provinces is Dictionary:
			provinces = maybe_provinces
	elif GameManager and not GameManager.map_data.is_empty():
		provinces = GameManager.map_data

	if provinces.is_empty():
		return

	var preview_data: Dictionary = {}
	var preview_pid := -1
	for prov_id in provinces:
		var prov = provinces[prov_id] as Dictionary
		var owner_tag = str(prov.get("owner", "")).strip_edges().to_upper()
		if owner_tag == wanted:
			preview_data = prov
			preview_pid = int(prov_id)
			break

	if preview_data.is_empty():
		return

	_posun_kameru_na_stat(wanted, true, preview_pid)
	zobraz_prehled_statu(preview_data, provinces)
	var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
	if info_ui and info_ui.has_method("zobraz_data"):
		info_ui.zobraz_data(preview_data)

func _ziskej_map_pozici_provincie_bezpecne(map_loader: Node, prov_id: int, prov_data: Dictionary) -> Vector2:
	var pos := Vector2.ZERO
	var map_offset := Vector2.ZERO
	if map_loader.has_method("_ziskej_map_offset"):
		map_offset = map_loader._ziskej_map_offset()

	if map_loader.has_method("_ziskej_map_pozici_provincie"):
		pos = map_loader._ziskej_map_pozici_provincie(prov_id, map_offset)
	elif map_loader.has_method("_ziskej_lokalni_pozici_provincie"):
		pos = map_loader._ziskej_lokalni_pozici_provincie(prov_id) + map_offset
	else:
		pos = Vector2(float(prov_data.get("x", 0.0)), float(prov_data.get("y", 0.0))) + map_offset

	if not is_finite(pos.x) or not is_finite(pos.y):
		return Vector2.ZERO
	if pos == Vector2.ZERO:
		return Vector2.ZERO
	if absf(pos.x) > 200000.0 or absf(pos.y) > 200000.0:
		return Vector2.ZERO
	return pos

func _ziskej_fokus_statu_na_mape(tag: String, preferred_province_id: int = -1) -> Dictionary:
	var wanted = tag.strip_edges().to_upper()
	if wanted == "" or wanted == "SEA":
		return {"ok": false}

	var map_loader = _ziskej_map_loader_node()
	if map_loader == null:
		return {"ok": false}

	var maybe_provinces = map_loader.get("provinces")
	if not (maybe_provinces is Dictionary):
		return {"ok": false}
	var provinces: Dictionary = maybe_provinces
	if provinces.is_empty():
		return {"ok": false}

	# 1) Prefer explicit capital province of the state.
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		if bool(d.get("is_capital", false)):
			var cap_pos = _ziskej_map_pozici_provincie_bezpecne(map_loader, int(p_id), d)
			if cap_pos != Vector2.ZERO:
				return {"ok": true, "pos": cap_pos}

	# 2) Fallback to the most populated owned province.
	var best_pop := -1
	var best_pos := Vector2.ZERO
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		var pos = _ziskej_map_pozici_provincie_bezpecne(map_loader, int(p_id), d)
		if pos == Vector2.ZERO:
			continue
		var pop = int(d.get("population", 0))
		if pop > best_pop:
			best_pop = pop
			best_pos = pos
	if best_pos != Vector2.ZERO:
		return {"ok": true, "pos": best_pos}

	# 3) Fallback to the province we used for preview, if available.
	if preferred_province_id >= 0 and provinces.has(preferred_province_id):
		var preferred_data = provinces[preferred_province_id] as Dictionary
		if str(preferred_data.get("owner", "")).strip_edges().to_upper() == wanted:
			var preferred_pos = _ziskej_map_pozici_provincie_bezpecne(map_loader, preferred_province_id, preferred_data)
			if preferred_pos != Vector2.ZERO:
				return {"ok": true, "pos": preferred_pos}

	# 4) Last-resort centroid of owned provinces.
	var sum := Vector2.ZERO
	var cnt := 0
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		var pos = _ziskej_map_pozici_provincie_bezpecne(map_loader, int(p_id), d)
		if pos == Vector2.ZERO:
			continue
		sum += pos
		cnt += 1
	if cnt > 0:
		return {"ok": true, "pos": sum / float(cnt)}

	return {"ok": false}

func _posun_kameru_na_stat(tag: String, smooth: bool = true, preferred_province_id: int = -1) -> void:
	var center = _ziskej_fokus_statu_na_mape(tag, preferred_province_id)
	if not bool(center.get("ok", false)):
		return

	var camera = get_tree().current_scene.find_child("Camera2D", true, false) as Camera2D
	if camera == null:
		return

	var target_pos: Vector2 = center.get("pos", camera.position)
	if not is_finite(target_pos.x) or not is_finite(target_pos.y):
		return
	if smooth:
		if _camera_focus_tween and _camera_focus_tween.is_running():
			_camera_focus_tween.kill()
		_camera_focus_tween = camera.create_tween()
		_camera_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_camera_focus_tween.tween_property(camera, "position", target_pos, 0.65)
	else:
		camera.position = target_pos

func _zajisti_tlacitko_daru() -> void:
	gift_money_btn = get_node_or_null("OverviewPanel/VBoxContainer/GiftMoneyButton") as Button
	if gift_money_btn:
		return
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer")
	if vbox == null:
		return
	var insert_after = worsen_rel_btn
	gift_money_btn = Button.new()
	gift_money_btn.name = "GiftMoneyButton"
	gift_money_btn.text = "Poslat dar"
	vbox.add_child(gift_money_btn)
	if insert_after and insert_after.get_parent() == vbox:
		vbox.move_child(gift_money_btn, insert_after.get_index() + 1)

func _zajisti_ideology_controls() -> void:
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer")
	if vbox == null:
		return

	ideology_separator = get_node_or_null("OverviewPanel/VBoxContainer/IdeologySeparator") as HSeparator
	if ideology_separator == null:
		ideology_separator = HSeparator.new()
		ideology_separator.name = "IdeologySeparator"
		vbox.add_child(ideology_separator)

	var effects_node = get_node_or_null("OverviewPanel/VBoxContainer/IdeologyEffectsLabel")
	ideology_effects_label = effects_node as RichTextLabel
	if ideology_effects_label == null:
		ideology_effects_label = RichTextLabel.new()
		ideology_effects_label.name = "IdeologyEffectsLabel"
		if effects_node and effects_node.get_parent() == vbox:
			var idx = effects_node.get_index()
			vbox.remove_child(effects_node)
			effects_node.queue_free()
			vbox.add_child(ideology_effects_label)
			vbox.move_child(ideology_effects_label, idx)
		else:
			vbox.add_child(ideology_effects_label)

	# Keep ideology description inside overview panel bounds on all resolutions.
	ideology_effects_label.bbcode_enabled = true
	ideology_effects_label.scroll_active = false
	ideology_effects_label.fit_content = true
	ideology_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ideology_effects_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ideology_effects_label.custom_minimum_size = Vector2(0, 180)
	ideology_effects_label.add_theme_font_size_override("font_size", 12)

	ideology_option = get_node_or_null("OverviewPanel/VBoxContainer/IdeologyOption") as OptionButton
	if ideology_option == null:
		ideology_option = OptionButton.new()
		ideology_option.name = "IdeologyOption"
		vbox.add_child(ideology_option)

	ideology_apply_btn = get_node_or_null("OverviewPanel/VBoxContainer/ChangeIdeologyButton") as Button
	if ideology_apply_btn == null:
		ideology_apply_btn = Button.new()
		ideology_apply_btn.name = "ChangeIdeologyButton"
		ideology_apply_btn.text = "Zmenit ideologii"
		vbox.add_child(ideology_apply_btn)

	if action_separator and action_separator.get_parent() == vbox:
		var base_idx = action_separator.get_index()
		vbox.move_child(ideology_separator, base_idx)
		vbox.move_child(ideology_effects_label, ideology_separator.get_index() + 1)
		vbox.move_child(ideology_option, ideology_effects_label.get_index() + 1)
		vbox.move_child(ideology_apply_btn, ideology_option.get_index() + 1)

func _normalizuj_ideologii(ideology: String) -> String:
	var raw = ideology.strip_edges().to_lower()
	match raw:
		"democracy", "democratic":
			return "demokracie"
		"autocracy", "autocratic", "dictatorship":
			return "autokracie"
		"communism", "communist", "socialism":
			return "komunismus"
		"fascism", "fascist":
			return "fasismus"
		"nazism", "nazismus", "nazi", "national_socialism":
			return "nacismus"
		"kingdom", "monarchy":
			return "kralovstvi"
		"royal":
			return "kralovstvi"
		"nacismum":
			return "nacismus"
		"kralostvi":
			return "kralovstvi"
		_:
			return raw

func _display_ideologie(ideology: String) -> String:
	var raw = _normalizuj_ideologii(ideology)
	if raw == "":
		return "Neznamo"
	return raw.capitalize()

func _ziskej_vyhody_nevyhody_ideologie(ideology: String) -> Dictionary:
	var ideo = _normalizuj_ideologii(ideology)
	match ideo:
		"demokracie":
			return {
				"plus": ["stabilni ekonomika", "lepsi vztahy s podobnymi rezimy"],
				"minus": ["pomalejsi rozhodovani", "mensi tolerance k agresi"]
			}
		"kralovstvi":
			return {
				"plus": ["silna legitimita moci", "snazsi diplomaticke vazby s tradicnimi staty"],
				"minus": ["riziko konzervativni stagnace", "horsi vztahy s revolucnimi rezimy"]
			}
		"autokracie":
			return {
				"plus": ["rychle centralni rozhodovani", "pevna vnitrni kontrola"],
				"minus": ["slabsi mezinarodni duvera", "napeti s demokratickymi staty"]
			}
		"komunismus":
			return {
				"plus": ["silna mobilizace statu", "duraz na tezky prumysl"],
				"minus": ["slabsi vztahy s monarchiemi a demokraciemi", "vyssi geopoliticke napeti"]
			}
		"nacismus", "fasismus":
			return {
				"plus": ["agresivni militarni mobilizace", "vysoka kontrola moci"],
				"minus": ["silne diplomaticke sankce", "rychle zhorsovani vztahu s oponenty"]
			}
		_:
			return {
				"plus": ["zmena vlajky a diplomatickeho profilu"],
				"minus": ["nejista reakce zahranici"]
			}

func _set_ideology_effects_label(ideology: String) -> void:
	if ideology_effects_label == null:
		return
	_ideology_effects_base_text = _sestav_ideology_effects_text(ideology)
	_set_ideology_effects_text(_ideology_effects_base_text)

func _set_ideology_effects_text(content: String) -> void:
	if ideology_effects_label == null:
		return
	ideology_effects_label.clear()
	ideology_effects_label.append_text(content)

func _sestav_ideology_effects_text(base_ideology: String, preview_ideology: String = "") -> String:
	if not GameManager.has_method("ziskej_ideologicky_ekonomicky_profil"):
		return "Data ideologie nejsou dostupna."

	var base_profile = GameManager.ziskej_ideologicky_ekonomicky_profil(base_ideology) as Dictionary
	if base_profile.is_empty():
		return "Data ideologie nejsou dostupna."

	var show_delta = preview_ideology.strip_edges() != "" and _normalizuj_ideologii(preview_ideology) != _normalizuj_ideologii(base_ideology)
	var preview_profile: Dictionary = {}
	if show_delta:
		preview_profile = GameManager.ziskej_ideologicky_ekonomicky_profil(preview_ideology) as Dictionary
		if preview_profile.is_empty():
			show_delta = false

	var recruit_cost = float(base_profile.get("recruit_cost_per_soldier", 0.05))
	var upkeep_cost = float(base_profile.get("upkeep_per_soldier", 0.001))
	var income_rate_pct = float(base_profile.get("income_rate_from_gdp", 0.1)) * 100.0
	var gdp_growth = float(base_profile.get("gdp_growth_per_turn", 0.5))
	var pop_growth_pct = float(base_profile.get("population_growth_ratio", 0.0015)) * 100.0
	var recruit_regen_core_pct = float(base_profile.get("recruit_regen_ratio_core", 0.10)) * 100.0
	var recruit_regen_occ_pct = float(base_profile.get("recruit_regen_ratio_occupied", 0.025)) * 100.0

	var d_recruit_cost = 0.0
	var d_upkeep_cost = 0.0
	var d_income_rate_pct = 0.0
	var d_gdp_growth = 0.0
	var d_pop_growth_pct = 0.0
	var d_recruit_regen_core_pct = 0.0
	var d_recruit_regen_occ_pct = 0.0
	if show_delta:
		d_recruit_cost = float(preview_profile.get("recruit_cost_per_soldier", recruit_cost)) - recruit_cost
		d_upkeep_cost = float(preview_profile.get("upkeep_per_soldier", upkeep_cost)) - upkeep_cost
		d_income_rate_pct = (float(preview_profile.get("income_rate_from_gdp", income_rate_pct / 100.0)) * 100.0) - income_rate_pct
		d_gdp_growth = float(preview_profile.get("gdp_growth_per_turn", gdp_growth)) - gdp_growth
		d_pop_growth_pct = (float(preview_profile.get("population_growth_ratio", pop_growth_pct / 100.0)) * 100.0) - pop_growth_pct
		d_recruit_regen_core_pct = (float(preview_profile.get("recruit_regen_ratio_core", recruit_regen_core_pct / 100.0)) * 100.0) - recruit_regen_core_pct
		d_recruit_regen_occ_pct = (float(preview_profile.get("recruit_regen_ratio_occupied", recruit_regen_occ_pct / 100.0)) * 100.0) - recruit_regen_occ_pct

	return "Cena / 1 vojak: %s%s\nUdrzba/vojak / kolo: %s%s\nSazba prijmu z HDP: %.2f%%%s\nHDP/rust: %.3f%s\nRust populace / kolo: %.3f%%%s\nObnova rekrutu(core): %.2f%%%s\nObnova rekrutu(occ): %.2f%%%s" % [
		_format_money_auto(recruit_cost, 4),
		_format_delta_text_color(d_recruit_cost, 4, " mil") if show_delta else "",
		_format_money_auto(upkeep_cost, 4),
		_format_delta_text_color(d_upkeep_cost, 4, " mil") if show_delta else "",
		income_rate_pct,
		_format_delta_text_color(d_income_rate_pct, 2, "%") if show_delta else "",
		gdp_growth,
		_format_delta_text_color(d_gdp_growth, 3, "") if show_delta else "",
		pop_growth_pct,
		_format_delta_text_color(d_pop_growth_pct, 3, "%") if show_delta else "",
		recruit_regen_core_pct,
		_format_delta_text_color(d_recruit_regen_core_pct, 2, "%") if show_delta else "",
		recruit_regen_occ_pct,
		_format_delta_text_color(d_recruit_regen_occ_pct, 2, "%") if show_delta else ""
	]

func _format_money_auto(value: float, mil_decimals: int = 2) -> String:
	if absf(value) < 0.01:
		return "%.*f tis." % [max(1, mil_decimals - 1), value * 1000.0]
	return "%.*f mil" % [mil_decimals, value]

func _format_delta_text_color(value: float, decimals: int, suffix: String = "") -> String:
	var txt := ""
	if suffix == " mil" and absf(value) < 0.01:
		# Tiny money changes are easier to read in thousands.
		txt = "%+.1ftis." % (value * 1000.0)
	else:
		var fmt = "%+." + str(decimals) + "f"
		txt = fmt % value
		if suffix != "":
			txt += suffix.strip_edges()
	var color = "#34c759"
	if value < 0.0:
		color = "#ff4d4f"
	elif is_zero_approx(value):
		color = "#c0c0c0"
	return " [color=%s](%s)[/color]" % [color, txt]

func _vycisti_nahled_ideologie_v_ui() -> void:
	nastav_akce_nahled_delta({})
	if ideology_effects_label and current_viewed_tag != "":
		var current_ideo = _ziskej_aktualni_ideologii_statu(current_viewed_tag)
		if current_ideo != "":
			_set_ideology_effects_label(current_ideo)
	var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
	if info_ui and info_ui.has_method("vycisti_nahled_ideologie"):
		info_ui.vycisti_nahled_ideologie()

func _ziskej_aktualni_ideologii_statu(owner_tag: String) -> String:
	var clean = owner_tag.strip_edges().to_upper()
	if clean == "":
		return ""
	var provinces = _ziskej_vsechny_provincie_pro_prehled()
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() == clean:
			return _normalizuj_ideologii(str(d.get("ideology", "")))
	return ""

func _obnov_ideology_vizual_z_mapy() -> void:
	if current_viewed_tag == "":
		return
	var current_ideo = _ziskej_aktualni_ideologii_statu(current_viewed_tag)
	if current_ideo == "":
		return
	if country_flag:
		country_flag.texture = _resolve_flag_texture(current_viewed_tag, current_ideo)
	ideo_label.text = "Zřízení: " + _display_ideologie(current_ideo)

func _on_ideology_dropdown_opened() -> void:
	_ideology_dropdown_open = true
	_ideology_hover_idx = -1
	_vycisti_nahled_ideologie_v_ui()
	_obnov_ideology_vizual_z_mapy()
	set_process(true)

func _on_ideology_dropdown_item_focused(index: int) -> void:
	if not _ideology_dropdown_open:
		return
	if index < 0 or index >= _ideology_option_values.size():
		return
	_ideology_hover_idx = index
	var selected = str(_ideology_option_values[index])
	# Preview ideology changes directly in ideology stats block under separator.
	_aplikuj_nahled_ideologie_do_ui(current_viewed_tag, selected)
	if country_flag and current_viewed_tag != "":
		country_flag.texture = _resolve_flag_texture(current_viewed_tag, selected)
	ideo_label.text = "Zřízení: " + _display_ideologie(selected)

func _on_ideology_dropdown_closed() -> void:
	_ideology_dropdown_open = false
	_ideology_hover_idx = -1
	set_process(false)
	_obnov_nahled_ideologie_podle_volby()

func _aplikuj_nahled_ideologie_do_ui(owner_tag: String, selected_ideology: String) -> void:
	if owner_tag != str(GameManager.hrac_stat).strip_edges().to_upper():
		_vycisti_nahled_ideologie_v_ui()
		return
	if not GameManager.has_method("nahled_zmeny_ideologie_statu"):
		_vycisti_nahled_ideologie_v_ui()
		return

	var preview = GameManager.nahled_zmeny_ideologie_statu(owner_tag, selected_ideology)
	if not bool(preview.get("ok", false)):
		_vycisti_nahled_ideologie_v_ui()
		return

	var stat_changes = preview.get("stat_changes", {}) as Dictionary
	var delta = stat_changes.get("delta", {}) as Dictionary
	var dgdp = float(delta.get("gdp", 0.0))
	var drecruit = int(delta.get("recruitable_population", 0))
	var old_totals = stat_changes.get("old_totals", {}) as Dictionary
	var new_totals = stat_changes.get("new_totals", {}) as Dictionary
	var old_pop = int(old_totals.get("population", 0))
	var new_pop = int(new_totals.get("population", 0))
	var old_gdp = float(old_totals.get("gdp", 0.0))
	var new_gdp = float(new_totals.get("gdp", 0.0))
	var old_gdp_pc = ((old_gdp * 1000000000.0) / float(old_pop)) if old_pop > 0 else 0.0
	var new_gdp_pc = ((new_gdp * 1000000000.0) / float(new_pop)) if new_pop > 0 else 0.0
	var dgdp_pc = new_gdp_pc - old_gdp_pc

	var overview_deltas: Dictionary = {
		"gdp": {
			"text": "%+.2f" % dgdp,
			"color": Color(0.20, 0.85, 0.25) if dgdp >= 0.0 else Color(0.95, 0.35, 0.35)
		},
		"gdp_pc": {
			"text": "%+.0f" % dgdp_pc,
			"color": Color(0.20, 0.85, 0.25) if dgdp_pc >= 0.0 else Color(0.95, 0.35, 0.35)
		},
		"recruit": {
			"text": "%+d" % drecruit,
			"color": Color(0.20, 0.85, 0.25) if drecruit >= 0 else Color(0.95, 0.35, 0.35)
		}
	}
	nastav_akce_nahled_delta(overview_deltas)

	if ideology_effects_label:
		var current_ideo = _ziskej_aktualni_ideologii_statu(owner_tag)
		if current_ideo == "":
			current_ideo = selected_ideology
		_set_ideology_effects_text(_sestav_ideology_effects_text(current_ideo, selected_ideology))

	var info_ui = get_tree().current_scene.find_child("InfoUI", true, false)
	if info_ui and info_ui.has_method("nastav_nahled_ideologie"):
		info_ui.nastav_nahled_ideologie(preview)

func _obnov_nahled_ideologie_podle_volby() -> void:
	if current_viewed_tag == "":
		_vycisti_nahled_ideologie_v_ui()
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag != player_tag:
		_vycisti_nahled_ideologie_v_ui()
		_obnov_ideology_vizual_z_mapy()
		return
	if ideology_option == null or _ideology_option_values.is_empty():
		_vycisti_nahled_ideologie_v_ui()
		_obnov_ideology_vizual_z_mapy()
		return
	var idx = ideology_option.selected
	if idx < 0 or idx >= _ideology_option_values.size():
		_vycisti_nahled_ideologie_v_ui()
		_obnov_ideology_vizual_z_mapy()
		return
	var selected = str(_ideology_option_values[idx])
	var current_ideo = _ziskej_aktualni_ideologii_statu(current_viewed_tag)
	if _normalizuj_ideologii(selected) == _normalizuj_ideologii(current_ideo):
		_vycisti_nahled_ideologie_v_ui()
		_obnov_ideology_vizual_z_mapy()
		return
	_aplikuj_nahled_ideologie_do_ui(current_viewed_tag, selected)
	if country_flag and current_viewed_tag != "":
		country_flag.texture = _resolve_flag_texture(current_viewed_tag, selected)
	ideo_label.text = "Zřízení: " + _display_ideologie(selected)

func _ziskej_vsechny_provincie_pro_prehled() -> Dictionary:
	var map_loader = _ziskej_map_loader_node()
	if map_loader:
		var maybe_provinces = map_loader.get("provinces")
		if maybe_provinces is Dictionary:
			return maybe_provinces
	if GameManager and not GameManager.map_data.is_empty():
		return GameManager.map_data
	return {}

func _obnov_otevreny_prehled_statu() -> void:
	if current_viewed_tag == "":
		return
	var provinces = _ziskej_vsechny_provincie_pro_prehled()
	if provinces.is_empty():
		return
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() == current_viewed_tag:
			zobraz_prehled_statu(d, provinces)
			return

func _ziskej_dostupne_ideologie_pro_stat(tag: String) -> Array:
	var out: Array = []
	var clean_tag = tag.strip_edges().to_upper()
	if clean_tag == "":
		return out

	var dir = DirAccess.open("res://map_data/FlagsIdeology")
	if dir == null:
		return out

	var seen: Dictionary = {}
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		var lower = file_name.to_lower()
		if not (lower.ends_with(".svg") or lower.ends_with(".png")):
			continue
		if lower.ends_with(".import"):
			continue
		var prefix := ""
		var prefix_double = (clean_tag + "__").to_lower()
		var prefix_single = (clean_tag + "_").to_lower()
		if lower.begins_with(prefix_double):
			prefix = prefix_double
		elif lower.begins_with(prefix_single):
			prefix = prefix_single
		else:
			continue

		var ext_idx = lower.rfind(".")
		if ext_idx <= prefix.length():
			continue
		var raw_ideo = lower.substr(prefix.length(), ext_idx - prefix.length())
		var ideo = _normalizuj_ideologii(raw_ideo)
		if IDEOLOGY_UI_ORDER.find(ideo) == -1:
			continue
		if ideo == "" or seen.has(ideo):
			continue
		seen[ideo] = true
		out.append(ideo)

	dir.list_dir_end()
	out.sort_custom(func(a, b):
		var ai = IDEOLOGY_UI_ORDER.find(a)
		var bi = IDEOLOGY_UI_ORDER.find(b)
		if ai == -1 and bi == -1:
			return str(a) < str(b)
		if ai == -1:
			return false
		if bi == -1:
			return true
		return ai < bi
	)
	return out

func _aktualizuj_ideology_ui(owner_tag: String, current_ideology: String) -> void:
	if ideology_separator == null or ideology_option == null or ideology_apply_btn == null or ideology_effects_label == null:
		return

	var is_player = owner_tag == str(GameManager.hrac_stat).strip_edges().to_upper()
	if not is_player:
		ideology_separator.hide()
		ideology_effects_label.hide()
		ideology_option.hide()
		ideology_apply_btn.hide()
		_vycisti_nahled_ideologie_v_ui()
		return

	ideology_separator.show()
	ideology_effects_label.show()
	ideology_option.show()
	ideology_apply_btn.show()

	var current = _normalizuj_ideologii(current_ideology)
	var options = _ziskej_dostupne_ideologie_pro_stat(owner_tag)
	if current != "" and not options.has(current):
		options.append(current)

	if options.is_empty():
		options = [current if current != "" else "demokracie"]

	_ideology_option_values = options.duplicate()
	_updating_ideology_ui = true
	ideology_option.clear()

	var selected_idx := 0
	for i in range(options.size()):
		var ideo = str(options[i])
		ideology_option.add_item(_display_ideologie(ideo), i)
		if ideo == current:
			selected_idx = i

	ideology_option.select(selected_idx)
	ideology_apply_btn.disabled = options.size() <= 1
	_set_ideology_effects_label(str(options[selected_idx]))
	_ideology_dropdown_open = false
	_vycisti_nahled_ideologie_v_ui()
	_updating_ideology_ui = false

func _wrap_overview_metric_label(key: String, base_label: Label) -> void:
	if base_label == null:
		return
	if _overview_metric_rows.has(key):
		return
	var parent = base_label.get_parent()
	if parent == null:
		return

	var idx = base_label.get_index()
	parent.remove_child(base_label)

	var row = HBoxContainer.new()
	row.name = "OverviewMetricRow_%s" % key
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	parent.move_child(row, idx)

	base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(base_label)

	var delta = Label.new()
	delta.name = "OverviewDelta_%s" % key
	delta.visible = false
	row.add_child(delta)

	_overview_metric_rows[key] = row
	_overview_metric_deltas[key] = delta

func _setup_overview_inline_deltas() -> void:
	_wrap_overview_metric_label("pop", pop_label)
	_wrap_overview_metric_label("recruit", recruit_label)
	_wrap_overview_metric_label("gdp", gdp_label)
	_wrap_overview_metric_label("gdp_pc", gdp_pc_label)

func _set_overview_metric_delta(key: String, text: String, color: Color) -> void:
	if not _overview_metric_deltas.has(key):
		return
	var lbl = _overview_metric_deltas[key] as Label
	var clean = text.strip_edges()
	if clean == "":
		lbl.text = ""
		lbl.visible = false
		return
	lbl.text = "(%s)" % clean
	lbl.add_theme_color_override("font_color", color)
	lbl.visible = true

func _clear_overview_metric_deltas() -> void:
	for k in _overview_metric_deltas.keys():
		_set_overview_metric_delta(str(k), "", Color.WHITE)

func _apply_overview_preview_deltas() -> void:
	_clear_overview_metric_deltas()
	if _overview_preview_deltas.is_empty():
		return

	for key in _overview_preview_deltas.keys():
		var entry = _overview_preview_deltas[key] as Dictionary
		var txt = str(entry.get("text", ""))
		var clr = entry.get("color", Color.WHITE)
		_set_overview_metric_delta(str(key), txt, clr)

func nastav_akce_nahled_delta(deltas: Dictionary) -> void:
	_overview_preview_deltas = deltas.duplicate(true)
	_apply_overview_preview_deltas()

func nastav_akce_nahled(_text: String) -> void:
	# Backward-compatible no-op; preview now uses inline deltas next to existing rows.
	if _text.strip_edges() == "":
		nastav_akce_nahled_delta({})

func _on_system_message_ok_pressed():
	_system_message_ack = true
	if system_message_popup:
		system_message_popup.hide()
	_aktualizuj_pozice_popupu()

func _on_viewport_resized():
	_aktualizuj_pozice_popupu()
	_pozicuj_pause_menu()
	_pozicuj_save_load_popupy()
	_pozicuj_gift_dialog()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if _gift_dialog and _gift_dialog.visible:
				_gift_dialog.hide()
				get_viewport().set_input_as_handled()
				return
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

func _vytvor_darovaci_dialog() -> void:
	_gift_dialog = PopupPanel.new()
	_gift_dialog.name = "GiftDialog"
	_gift_dialog.size = Vector2(420, 190)
	add_child(_gift_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gift_dialog.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Poslat finanční dar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Částka v mil. USD"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_gift_amount_input = LineEdit.new()
	_gift_amount_input.placeholder_text = "např. 50"
	_gift_amount_input.text_submitted.connect(func(_t): _on_confirm_gift_money())
	vbox.add_child(_gift_amount_input)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Poslat"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(_on_confirm_gift_money)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Zrušit"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): _gift_dialog.hide())
	btn_row.add_child(cancel_btn)

	_gift_dialog.hide()
	_pozicuj_gift_dialog()

func _pozicuj_gift_dialog() -> void:
	if not _gift_dialog:
		return
	var vp = get_viewport().get_visible_rect().size
	_gift_dialog.position = Vector2((vp.x - _gift_dialog.size.x) * 0.5, (vp.y - _gift_dialog.size.y) * 0.5)

func _parse_gift_amount(text: String) -> float:
	var sanitized = text.strip_edges().replace(",", ".")
	if sanitized == "":
		return 0.0
	if not sanitized.is_valid_float():
		return 0.0
	return maxf(0.0, float(sanitized))

func _on_gift_money_pressed() -> void:
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not _gift_dialog:
		return
	_gift_amount_input.text = "10"
	_pozicuj_gift_dialog()
	_gift_dialog.popup()
	_gift_amount_input.grab_focus()
	_gift_amount_input.select_all()

func _on_confirm_gift_money() -> void:
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("daruj_penize_statu"):
		return

	var amount = _parse_gift_amount(_gift_amount_input.text if _gift_amount_input else "")
	var result = GameManager.daruj_penize_statu(GameManager.hrac_stat, current_viewed_tag, amount)
	var ok = bool(result.get("ok", false))
	if ok:
		if _gift_dialog:
			_gift_dialog.hide()
		await zobraz_systemove_hlaseni(
			"Diplomacie",
			"Odeslán dar %s USD státu %s.\nVztah: %+0.1f" % [
				_format_money_auto(float(result.get("amount", amount)), 2),
				current_viewed_tag,
				float(result.get("relation_delta", 0.0))
			]
		)
		if GameManager.has_signal("kolo_zmeneno"):
			GameManager.kolo_zmeneno.emit()
		_aktualizuj_vztah_ui(current_viewed_tag)
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
		return

	await zobraz_systemove_hlaseni("Diplomacie", str(result.get("reason", "Dar se nepodařilo odeslat.")))

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
		if _popup_country_link_btn:
			_popup_country_link_btn.text = display_name
			_popup_country_link_btn.tooltip_text = "Klikni pro otevreni prehledu statu %s." % display_name
		if popup_request_flag:
			popup_request_flag.tooltip_text = "Klikni pro otevreni prehledu statu %s." % display_name
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
			popup_request_text.text = "navrhuje %s" % level_text
		elif req_type == "peace":
			popup_request_text.text = "navrhuje uzavrit mir"
		else:
			popup_request_text.text = "navrhuje neagresivni smlouvu (10 kol)"

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
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
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

	# Keep action preview inline with current metrics (no extra rows).
	if owner_tag != player_tag:
		_clear_overview_metric_deltas()
	else:
		_apply_overview_preview_deltas()
		
	# --- NEW: DIPLOMACY UI LOGIC ---
	if action_separator and declare_war_btn and propose_peace_btn:
		if owner_tag == player_tag:
			_aktualizuj_ideology_ui(owner_tag, ideologie)
			# Hide actions if looking at our own country
			if relationship_label:
				relationship_label.hide()
			action_separator.hide()
			if improve_rel_btn: improve_rel_btn.hide()
			if worsen_rel_btn: worsen_rel_btn.hide()
			if gift_money_btn: gift_money_btn.hide()
			if alliance_level_option: alliance_level_option.hide()
			declare_war_btn.hide()
			propose_peace_btn.hide()
			if non_aggression_btn: non_aggression_btn.hide()
			if incoming_request_label: incoming_request_label.hide()
			if respond_request_buttons: respond_request_buttons.hide()
		else:
			_aktualizuj_ideology_ui(owner_tag, ideologie)
			_aktualizuj_vztah_ui(owner_tag)
			# Show actions for other countries
			action_separator.show()
			if improve_rel_btn: improve_rel_btn.show()
			if worsen_rel_btn: worsen_rel_btn.show()
			if gift_money_btn: gift_money_btn.show()
			if alliance_level_option: alliance_level_option.show()
			_aktualizuj_aliance_ui(owner_tag)
			_aktualizuj_diplomacii_tlacitka(owner_tag)
			if non_aggression_btn: non_aggression_btn.show()
			_aktualizuj_zadost_ui(owner_tag)
	
	panel.show()

func _on_apply_ideology_pressed() -> void:
	if current_viewed_tag == "" or current_viewed_tag != str(GameManager.hrac_stat).strip_edges().to_upper():
		return
	if ideology_option == null or _ideology_option_values.is_empty():
		return
	if not GameManager.has_method("zmen_ideologii_statu"):
		return

	var idx = ideology_option.selected
	if idx < 0 or idx >= _ideology_option_values.size():
		return

	var selected_ideology = str(_ideology_option_values[idx])
	var result = GameManager.zmen_ideologii_statu(GameManager.hrac_stat, selected_ideology)
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Ideologie", str(result.get("reason", "Zmena ideologie selhala.")))
		return

	var changed = bool(result.get("changed", true))
	if not changed:
		await zobraz_systemove_hlaseni("Ideologie", "Tato ideologie uz je aktivni.")
		return

	_ideology_dropdown_open = false
	_vycisti_nahled_ideologie_v_ui()

	var relation_changes = result.get("relation_changes", []) as Array
	var plus_count := 0
	var minus_count := 0
	for c in relation_changes:
		var delta = float((c as Dictionary).get("delta", 0.0))
		if delta > 0.0:
			plus_count += 1
		elif delta < 0.0:
			minus_count += 1

	await zobraz_systemove_hlaseni(
		"Ideologie",
		"Stat %s presel na ideologii %s.\nZlepsene vztahy: %d\nZhorske vztahy: %d" % [
			str(result.get("state", current_viewed_tag)),
			_display_ideologie(str(result.get("new_ideology", selected_ideology))),
			plus_count,
			minus_count
		]
	)
	_obnov_otevreny_prehled_statu()

func _on_ideology_option_selected(index: int) -> void:
	if _updating_ideology_ui:
		return
	if index < 0 or index >= _ideology_option_values.size():
		return
	_obnov_nahled_ideologie_podle_volby()

# Triggered by right-clicking on the map
func schovej_se():
	panel.hide()
	_vycisti_nahled_ideologie_v_ui()

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
	_obnov_otevreny_prehled_statu()
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
	if gift_money_btn:
		gift_money_btn.text = "Poslat dar"
		gift_money_btn.disabled = current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat

	_aktualizuj_aliance_ui(target_tag)
	_aktualizuj_diplomacii_tlacitka(target_tag)
	_aktualizuj_zadost_ui(target_tag)

func _aktualizuj_diplomacii_tlacitka(target_tag: String):
	if not declare_war_btn or not propose_peace_btn:
		return

	var target = target_tag.strip_edges().to_upper()
	var me = str(GameManager.hrac_stat).strip_edges().to_upper()
	if target == "" or target == me:
		declare_war_btn.hide()
		propose_peace_btn.hide()
		if non_aggression_btn:
			non_aggression_btn.hide()
		return

	if GameManager.jsou_ve_valce(GameManager.hrac_stat, target):
		declare_war_btn.text = "VE VALCE"
		declare_war_btn.disabled = true
		declare_war_btn.modulate = Color(1, 0.5, 0.5)
		declare_war_btn.show()

		var ceka_na_odpoved = GameManager.je_mirova_nabidka_cekajici(GameManager.hrac_stat, target)
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
			alliance_level = int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, target))
		var war_blocked_by_alliance = alliance_level > 0
		var has_non_aggression = false
		var non_aggression_turns_left = 0
		if GameManager.has_method("ma_neagresivni_smlouvu"):
			has_non_aggression = bool(GameManager.ma_neagresivni_smlouvu(GameManager.hrac_stat, target))
		if has_non_aggression and GameManager.has_method("zbyva_kol_neagresivni_smlouvy"):
			non_aggression_turns_left = int(GameManager.zbyva_kol_neagresivni_smlouvy(GameManager.hrac_stat, target))
		var war_blocked_by_non_aggression = has_non_aggression
		var war_blocked_by_peace_cooldown = false
		var peace_cooldown_turns_left = 0
		if GameManager.has_method("zbyva_kol_do_dalsi_valky"):
			peace_cooldown_turns_left = int(GameManager.zbyva_kol_do_dalsi_valky(GameManager.hrac_stat, target))
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
				rel = float(GameManager.ziskej_vztah_statu(GameManager.hrac_stat, target))
			if has_non_aggression:
				non_aggression_btn.text = "Neagresivni smlouva (%d kol)" % non_aggression_turns_left
				non_aggression_btn.disabled = true
				non_aggression_btn.modulate = Color(1, 1, 1)
			else:
				non_aggression_btn.text = "Neagresivni smlouva (10 kol)"
				non_aggression_btn.disabled = rel < 10.0
				non_aggression_btn.modulate = Color(1, 1, 1)
