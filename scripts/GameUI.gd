extends CanvasLayer

class ArmyOfferCard:
	extends PanelContainer
	var owner_ui = null
	var offer_index: int = -1

	func _get_drag_data(_at_position: Vector2):
		if owner_ui == null:
			return null
		return owner_ui._army_offer_get_drag_data(offer_index, self)

class ArmyGridCell:
	extends PanelContainer
	var owner_ui = null
	var cell_index: int = -1

	func _get_drag_data(_at_position: Vector2):
		if owner_ui == null:
			return null
		return owner_ui._army_grid_cell_get_drag_data(cell_index, self)

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if owner_ui == null:
			return false
		return owner_ui._army_grid_cell_can_drop(cell_index, data)

	func _drop_data(_at_position: Vector2, data) -> void:
		if owner_ui == null:
			return
		owner_ui._army_grid_cell_drop(cell_index, data)

class ArmyTrashBin:
	extends PanelContainer
	var owner_ui = null

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if owner_ui == null:
			return false
		return owner_ui._army_trash_can_drop(data)

	func _drop_data(_at_position: Vector2, data) -> void:
		if owner_ui == null:
			return
		owner_ui._army_trash_drop(data)

@onready var panel = $OverviewPanel

# Updated paths for the new UI tree structure
@onready var country_flag = $OverviewPanel/VBoxContainer/TitleBoxOffset/TitleBox/CountryFlag
@onready var name_label = $OverviewPanel/VBoxContainer/TitleBoxOffset/TitleBox/CountryNameLabel

@onready var ideo_label = $OverviewPanel/VBoxContainer/IdeologyLabel 
@onready var pop_label = $OverviewPanel/VBoxContainer/TotalPopLabel
@onready var recruit_label = $OverviewPanel/VBoxContainer/TotalRecruitsLabel 
@onready var gdp_label = $OverviewPanel/VBoxContainer/TotalGdpLabel
@onready var gdp_pc_label = $OverviewPanel/VBoxContainer/GdpPerCapitaLabel 
@onready var relationship_label = $OverviewPanel/VBoxContainer/RelationshipLabel
var _vassals_btn: Button
var _vassals_dialog: PopupPanel
var _vassals_list: VBoxContainer
var army_power_label: Label
var vassals_label: Label
var war_reparations_label: Label

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
@onready var popup_decline_all_btn = $DiplomacyRequestPopup/HBoxContainer/DeclineAllButton
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
var _pause_confirm_accepted: bool = false
var _overview_metric_rows: Dictionary = {}
var _overview_metric_deltas: Dictionary = {}
var _overview_preview_deltas: Dictionary = {}
var _save_dialog: PopupPanel
var _save_name_input: LineEdit
var _load_dialog: PopupPanel
var _load_slot_scroll: ScrollContainer
var _load_slots_vbox: VBoxContainer
var _load_confirm_btn: Button
var _load_slot_names: Array = []
var _load_selected_slot_name: String = ""
var _load_slot_row_buttons: Dictionary = {}
var _settings_dialog: PopupPanel
var _settings_fullscreen_check: CheckBox
var _settings_vsync_check: CheckBox
var _settings_volume_slider: HSlider
var _settings_volume_value: Label
var _settings_camera_slider: HSlider
var _settings_camera_value: Label
var _settings_zoom_slider: HSlider
var _settings_zoom_value: Label
var _settings_invert_zoom_check: CheckBox
var _settings_tab_controls_btn: Button
var _settings_tab_settings_btn: Button
var _settings_controls_panel: PanelContainer
var _settings_options_panel: PanelContainer
var _gift_dialog: PopupPanel
var _gift_amount_input: LineEdit
var gift_money_btn: Button
var _peace_dialog: PopupPanel
var _peace_title_label: Label
var _peace_points_label: Label
var _peace_participants_label: Label
var _peace_pick_btn: Button
var _peace_selected_label: Label
var _peace_take_label: Label
var _peace_annex_check: CheckBox
var _peace_vassal_check: CheckBox
var _peace_reparations_slider: HSlider
var _peace_reparations_label: Label
var _peace_cost_label: Label
var _peace_confirm_btn: Button
var _active_peace_conference: Dictionary = {}
var _peace_selected_provinces: Array = []
var _ceka_na_vyber_miru: bool = false
var _peace_notice_panel: Panel
var _peace_notice_label: Label
var _peace_notice_flag: TextureRect
var _peace_notice_btn: Button
var _peace_notice_deferred_conf_id: int = -1
var ideology_separator: HSeparator
var ideology_effects_label: RichTextLabel
var ideology_option: OptionButton
var ideology_apply_btn: Button
var ideology_relocate_capital_btn: Button
var research_btn: Button
var _research_dialog: PanelContainer
var _research_money_label: Label
var _research_list: VBoxContainer
var _army_research_grid: GridContainer
var _army_research_offers: VBoxContainer
var _army_research_trash: ArmyTrashBin
var _army_research_reroll_btn: Button
var _army_research_quality_btn: Button
var _army_research_summary_label: Label
var _army_research_grid_cells: Array = []
var _army_research_grid_w: int = 3
var _army_research_grid_h: int = 3
var _army_research_view_w: int = 3
var _army_research_view_h: int = 3
var _army_research_last_info: Dictionary = {}
var _research_dialog_user_open: bool = false
var _research_dialog_layout_warmed: bool = false
var _army_cell_drag_uid: Dictionary = {}
var _ideology_option_values: Array = []
var _current_viewed_province_id: int = -1
var _relocate_capital_action_lock: bool = false
var _ceka_na_vyber_cile_hlavniho_mesta: bool = false
var _popup_country_link_btn: LinkButton
var _camera_focus_tween: Tween
var _ideology_flag_path_index: Dictionary = {}
var _ideology_flag_index_ready: bool = false
var _updating_ideology_ui: bool = false
var _ideology_dropdown_open: bool = false
var _ideology_hover_idx: int = -1
var _ideology_effects_base_text: String = ""
var _diplomacy_queue_preview_cards: Array = []
var _queue_preview_toggle_btn: Button
var _queue_preview_panel: Panel
var _queue_preview_scroll: ScrollContainer
var _queue_preview_list: VBoxContainer
var _queue_preview_expanded: bool = false
var _queue_preview_rows: int = 0
var _zpravy_toggle_btn: Button
var _zpravy_panel: Panel
var _zpravy_anchor_control: Control
var _zpravy_mode_local_btn: Button
var _zpravy_mode_global_btn: Button
var _zpravy_mode: int = 0 # 0 = moje zeme, 1 = globalni
var _zpravy_title_label: Label
var _zpravy_historie_checkbox: CheckBox
var _zpravy_scroll: ScrollContainer
var _zpravy_groups_list: VBoxContainer
var _zpravy_category_expanded: Dictionary = {}
var _zpravy_expanded: bool = false
var _zpravy_historie_expanded: bool = false
var _turn_loading_overlay: ColorRect
var _turn_loading_label: Label
var _turn_loading_anim_time: float = 0.0
var _turn_loading_anim_step: int = 0
var _turn_loading_active: bool = false

const POPUP_TOP_MARGIN := 6
const POPUP_GAP := 6
const QUEUE_PREVIEW_MAX_ITEMS := 8
const ZPRAVY_MAX_ITEMS := 180
const ZPRAVY_HISTORY_MAX_ITEMS := 500
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const SETTINGS_FILE_PATH := "user://settings.cfg"
const IDEOLOGY_UI_ORDER := ["demokracie", "kralovstvi", "autokracie", "komunismus", "nacismus", "fasismus"]
const TURN_LOADING_FRAMES := ["Zpracovavam tah", "Zpracovavam tah.", "Zpracovavam tah..", "Zpracovavam tah..."]
const SYSTEM_MESSAGE_TURN_AUTO_ACK_MS := 7000

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
		"res://map_data/Flags/%s.svg" % cisty_tag,
		"res://map_data/Flags/%s.png" % cisty_tag
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
			var country_name = str(d.get("country_name", cisty)).strip_edges()
			return country_name if country_name != "" else cisty
	return cisty

func _ready():
	panel.hide()
	_setup_overview_inline_deltas()
	_zajisti_label_sily_armady()
	_zajisti_mirove_overview_labely()
	_zajisti_tlacitko_vazalu()
	_zajisti_tlacitko_daru()
	_zajisti_ideology_controls()
	_zajisti_vyzkum_controls()
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
	if popup_accept_btn and not popup_accept_btn.pressed.is_connected(_on_popup_accept_all_requests_pressed):
		popup_accept_btn.pressed.connect(_on_popup_accept_all_requests_pressed)
	if popup_decline_btn and not popup_decline_btn.pressed.is_connected(_on_popup_decline_all_requests_pressed):
		popup_decline_btn.pressed.connect(_on_popup_decline_all_requests_pressed)
	if popup_decline_all_btn and not popup_decline_all_btn.pressed.is_connected(_on_popup_decline_all_requests_pressed):
		popup_decline_all_btn.pressed.connect(_on_popup_decline_all_requests_pressed)
	if system_message_ok_btn and not system_message_ok_btn.pressed.is_connected(_on_system_message_ok_pressed):
		system_message_ok_btn.pressed.connect(_on_system_message_ok_pressed)
	if improve_rel_btn and not improve_rel_btn.pressed.is_connected(_on_improve_relationship_pressed):
		improve_rel_btn.pressed.connect(_on_improve_relationship_pressed)
	if worsen_rel_btn and not worsen_rel_btn.pressed.is_connected(_on_worsen_relationship_pressed):
		worsen_rel_btn.pressed.connect(_on_worsen_relationship_pressed)
	if gift_money_btn and not gift_money_btn.pressed.is_connected(_on_gift_money_pressed):
		gift_money_btn.pressed.connect(_on_gift_money_pressed)
	if _vassals_btn and not _vassals_btn.pressed.is_connected(_on_vassals_button_pressed):
		_vassals_btn.pressed.connect(_on_vassals_button_pressed)
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
	if ideology_relocate_capital_btn and not ideology_relocate_capital_btn.pressed.is_connected(_on_relocate_capital_pressed):
		ideology_relocate_capital_btn.pressed.connect(_on_relocate_capital_pressed)
	if research_btn and not research_btn.pressed.is_connected(_on_research_button_pressed):
		research_btn.pressed.connect(_on_research_button_pressed)
	if alliance_level_option and not alliance_level_option.item_selected.is_connected(_on_alliance_level_selected):
		alliance_level_option.item_selected.connect(_on_alliance_level_selected)
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)
	if GameManager.has_signal("zpracovani_tahu_zmeneno") and not GameManager.zpracovani_tahu_zmeneno.is_connected(_on_zpracovani_tahu_zmeneno):
		GameManager.zpracovani_tahu_zmeneno.connect(_on_zpracovani_tahu_zmeneno)
	if diplomacy_request_popup:
		diplomacy_request_popup.hide()
		if popup_decline_all_btn:
			popup_decline_all_btn.hide()
		if popup_request_flag:
			popup_request_flag.hide()
	_zajisti_vizual_fronty_diplomacii()
	_zajisti_rozbaleni_fronty_popupu()
	_zajisti_panel_zprav()
	_aktualizuj_vizual_fronty_diplomacii(0)
	_aktualizuj_text_rozbaleni_fronty(0)
	_aktualizuj_tlacitko_zprav()
	_aktualizuj_panel_zprav()
	if system_message_popup:
		system_message_popup.hide()
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_vytvor_pause_menu()
	_vytvor_turn_loading_overlay()
	_on_zpracovani_tahu_zmeneno(bool(GameManager.zpracovava_se_tah))
	_aktualizuj_pozice_popupu()
	_aktualizuj_popup_diplomatickych_zadosti()
	_vytvor_darovaci_dialog()
	_vytvor_mirovou_konferenci_dialog()
	_vytvor_hlaseni_mirove_konference()
	_vytvor_panel_vazalu()
	_vytvor_vyzkum_dialog()
	# Pre-layout research dialog once in hidden mode; fixes broken first open in turn 0.
	call_deferred("_predhrej_vyzkum_dialog_layout")
	_nastav_tooltipy_ui()
	_aktualizuj_hlaseni_mirove_konference()

func _process(_delta: float) -> void:
	if _research_dialog and _research_dialog.visible:
		if panel == null or not panel.visible or research_btn == null or not research_btn.visible:
			_zavri_vyzkum_dialog()

	if _turn_loading_active:
		_turn_loading_anim_time += _delta
		if _turn_loading_anim_time >= 0.2 and _turn_loading_label:
			_turn_loading_anim_time = 0.0
			_turn_loading_anim_step = (_turn_loading_anim_step + 1) % TURN_LOADING_FRAMES.size()
			_turn_loading_label.text = TURN_LOADING_FRAMES[_turn_loading_anim_step]

	if not _ideology_dropdown_open or ideology_option == null:
		if not _turn_loading_active:
			set_process(false)
		return
	var popup = ideology_option.get_popup()
	if popup == null or not popup.visible:
		if not _turn_loading_active:
			set_process(false)
		return
	if popup.has_method("get_focused_item"):
		var idx = int(popup.get_focused_item())
		if idx != _ideology_hover_idx:
			_on_ideology_dropdown_item_focused(idx)

func _vytvor_turn_loading_overlay() -> void:
	if _turn_loading_overlay != null:
		return
	_turn_loading_overlay = ColorRect.new()
	_turn_loading_overlay.name = "TurnLoadingOverlay"
	_turn_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_loading_overlay.color = Color(0.03, 0.05, 0.08, 0.18)
	_turn_loading_overlay.visible = false
	_turn_loading_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_loading_overlay)

	_turn_loading_label = Label.new()
	_turn_loading_label.name = "TurnLoadingLabel"
	_turn_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_turn_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_loading_label.text = TURN_LOADING_FRAMES[0]
	_turn_loading_label.add_theme_font_size_override("font_size", 24)
	_turn_loading_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.95))
	_turn_loading_overlay.add_child(_turn_loading_label)

func _on_zpracovani_tahu_zmeneno(aktivni: bool) -> void:
	_turn_loading_active = aktivni
	_turn_loading_anim_time = 0.0
	_turn_loading_anim_step = 0
	if _turn_loading_overlay:
		_turn_loading_overlay.visible = aktivni
	if _turn_loading_label:
		_turn_loading_label.text = TURN_LOADING_FRAMES[0]
	if aktivni:
		set_process(true)

func _setup_popup_country_link() -> void:
	# Sender name text in the popup was intentionally removed to keep the card compact.
	if _popup_country_link_btn:
		_popup_country_link_btn.hide()
		_popup_country_link_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if popup_request_flag and not popup_request_flag.gui_input.is_connected(_on_popup_flag_gui_input):
		popup_request_flag.gui_input.connect(_on_popup_flag_gui_input)
		popup_request_flag.mouse_filter = Control.MOUSE_FILTER_STOP
		popup_request_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _nastav_tooltipy_ui() -> void:
	name_label.tooltip_text = "Name of the selected country."
	country_flag.tooltip_text = "Flag of the selected country."
	ideo_label.tooltip_text = "Current political system of the country."
	pop_label.tooltip_text = "Total population of the country."
	recruit_label.tooltip_text = "Available recruits in the whole country."
	if army_power_label:
		army_power_label.tooltip_text = "Final army strength after equipment bonuses."
	gdp_label.tooltip_text = "Total GDP of the country."
	gdp_pc_label.tooltip_text = "GDP per capita."
	if vassals_label:
		vassals_label.tooltip_text = "List of countries that are your vassals."
	if war_reparations_label:
		war_reparations_label.tooltip_text = "Number of active war reparations (incoming/outgoing)."
	if _vassals_btn:
		_vassals_btn.tooltip_text = "Open your vassal list and available interactions."
	relationship_label.tooltip_text = "Diplomatic relation between your country and the target."
	if ideology_option:
		ideology_option.tooltip_text = "Choose a new ideology for your country."
	if ideology_effects_label:
		ideology_effects_label.tooltip_text = "Overview of pros and cons of the selected ideology."
	if ideology_apply_btn:
		ideology_apply_btn.tooltip_text = "Confirm switching your country to the selected ideology."
	if ideology_relocate_capital_btn:
		ideology_relocate_capital_btn.tooltip_text = "Start target selection on map. Cost is dynamic and shown directly at the target province."
	if research_btn:
		research_btn.tooltip_text = "Open Army Lab: expandable grid, items, and rerolls."
	improve_rel_btn.tooltip_text = "Improve relations by 10 points."
	worsen_rel_btn.tooltip_text = "Worsen relations by 10 points."
	if gift_money_btn:
		gift_money_btn.tooltip_text = "Send a financial gift to the target country."
	declare_war_btn.tooltip_text = "Declare war on the selected country."
	propose_peace_btn.tooltip_text = "Send a peace proposal."
	non_aggression_btn.tooltip_text = "Sign a non-aggression pact for 10 turns."
	incoming_request_label.tooltip_text = "Shows incoming diplomatic request."
	accept_request_btn.tooltip_text = "Accept displayed diplomatic request."
	decline_request_btn.tooltip_text = "Decline displayed diplomatic request."
	popup_request_flag.tooltip_text = "Click to open this country overview."
	if _popup_country_link_btn:
		_popup_country_link_btn.tooltip_text = "Click to open this country overview."
	popup_request_text.tooltip_text = "Short description of diplomatic offer."
	popup_accept_btn.tooltip_text = "Accept all pending offers."
	popup_decline_btn.tooltip_text = "Decline all pending offers."
	if popup_decline_all_btn:
		popup_decline_all_btn.tooltip_text = "Decline all pending diplomatic offers."
	system_message_title.tooltip_text = "System message title."
	system_message_text.tooltip_text = "Detailed system message text."
	system_message_ok_btn.tooltip_text = "Confirm and close message."
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
	gift_money_btn.text = "Send gift"
	vbox.add_child(gift_money_btn)
	if insert_after and insert_after.get_parent() == vbox:
		vbox.move_child(gift_money_btn, insert_after.get_index() + 1)

func _zajisti_tlacitko_vazalu() -> void:
	_vassals_btn = get_node_or_null("OverviewPanel/VBoxContainer/VassalsButton") as Button
	if _vassals_btn:
		return
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	_vassals_btn = Button.new()
	_vassals_btn.name = "VassalsButton"
	_vassals_btn.text = "Vassals"
	_vassals_btn.hide()
	vbox.add_child(_vassals_btn)
	if action_separator and action_separator.get_parent() == vbox:
		vbox.move_child(_vassals_btn, action_separator.get_index() + 1)

func _vytvor_panel_vazalu() -> void:
	if _vassals_dialog != null:
		return

	_vassals_dialog = PopupPanel.new()
	_vassals_dialog.name = "VassalsDialog"
	_vassals_dialog.size = Vector2(372, 252)
	_vassals_dialog.exclusive = false
	_vassals_dialog.popup_window = false
	add_child(_vassals_dialog)
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	dialog_style.border_color = Color(0.60, 0.74, 0.92, 0.65)
	dialog_style.border_width_left = 1
	dialog_style.border_width_top = 1
	dialog_style.border_width_right = 1
	dialog_style.border_width_bottom = 1
	dialog_style.corner_radius_top_left = 8
	dialog_style.corner_radius_top_right = 8
	dialog_style.corner_radius_bottom_left = 8
	dialog_style.corner_radius_bottom_right = 8
	_vassals_dialog.add_theme_stylebox_override("panel", dialog_style)

	var margin = MarginContainer.new()
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vassals_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title = Label.new()
	title.text = "My vassals"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_top_btn = Button.new()
	close_top_btn.text = "Close"
	close_top_btn.custom_minimum_size = Vector2(72, 0)
	close_top_btn.pressed.connect(func(): _vassals_dialog.hide())
	header.add_child(close_top_btn)

	var hint = Label.new()
	hint.text = "Set tribute and click Apply %."
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(0, 18)
	root.add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_vassals_list = VBoxContainer.new()
	_vassals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vassals_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_vassals_list)

	_vassals_dialog.hide()

func _pozicuj_a_zmen_velikost_panelu_vazalu(vassal_count: int = -1) -> void:
	if _vassals_dialog == null:
		return

	var viewport = get_viewport()
	if viewport == null:
		return
	var vp = viewport.get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var count: int = maxi(0, vassal_count)
	if vassal_count < 0 and GameManager.has_method("ziskej_vazaly_statu"):
		count = (GameManager.ziskej_vazaly_statu(GameManager.hrac_stat) as Array).size()

	var base_w: float = 372.0
	var base_h: float = 252.0
	var extra_w: float = minf(90.0, float(count) * 6.0)
	var extra_h: float = minf(320.0, float(maxi(0, count - 1)) * 32.0)

	var max_w: float = maxf(280.0, vp.x - 24.0)
	var max_h: float = maxf(180.0, vp.y - 24.0)
	var w: float = clampf(base_w + extra_w, 320.0, max_w)
	var h: float = clampf(base_h + extra_h, 220.0, max_h)
	_vassals_dialog.size = Vector2(w, h)

	var gap: float = 10.0
	var x: float = 16.0
	var min_y: float = _topbar_bottom_y() + 8.0
	var y: float = min_y
	if panel:
		var ov = panel.get_global_rect()
		x = ov.position.x + ov.size.x + gap
		y = maxf(ov.position.y + 14.0, min_y)
		if x + w > vp.x - 8.0:
			x = ov.position.x - w - gap

	x = clampf(x, 8.0, maxf(8.0, vp.x - w - 8.0))
	y = clampf(y, min_y, maxf(min_y, vp.y - h - 8.0))
	_vassals_dialog.position = Vector2(x, y)

func _on_vassals_button_pressed() -> void:
	if _vassals_dialog == null:
		return
	_obnov_panel_vazalu()
	_pozicuj_a_zmen_velikost_panelu_vazalu()
	_vassals_dialog.show()

func _obnov_panel_vazalu() -> void:
	if _vassals_list == null:
		return
	for ch in _vassals_list.get_children():
		ch.queue_free()

	var player = str(GameManager.hrac_stat).strip_edges().to_upper()
	var vassals: Array = []
	if GameManager.has_method("ziskej_vazaly_statu"):
		vassals = GameManager.ziskej_vazaly_statu(player) as Array

	if vassals.is_empty():
		var empty_label = Label.new()
		empty_label.text = "You currently have no active vassals."
		_vassals_list.add_child(empty_label)
		_pozicuj_a_zmen_velikost_panelu_vazalu(0)
		return

	for subject_any in vassals:
		var subject = str(subject_any).strip_edges().to_upper()
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.10, 0.14, 0.20, 0.88)
		card_style.border_color = Color(0.45, 0.62, 0.85, 0.45)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card.add_theme_stylebox_override("panel", card_style)
		_vassals_list.add_child(card)

		var card_margin = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 6)
		card_margin.add_theme_constant_override("margin_top", 4)
		card_margin.add_theme_constant_override("margin_right", 6)
		card_margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(card_margin)

		var card_v = VBoxContainer.new()
		card_v.add_theme_constant_override("separation", 4)
		card_margin.add_child(card_v)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card_v.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = _ziskej_jmeno_statu_podle_tagu(subject)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.tooltip_text = subject
		row.add_child(name_lbl)

		var focus_btn = Button.new()
		focus_btn.text = "Open"
		focus_btn.pressed.connect(_on_vassal_focus_pressed.bind(subject))
		row.add_child(focus_btn)

		var release_btn = Button.new()
		release_btn.text = "Release"
		release_btn.pressed.connect(_on_vassal_release_pressed.bind(subject))
		row.add_child(release_btn)

		var tribute_row = HBoxContainer.new()
		tribute_row.add_theme_constant_override("separation", 8)
		card_v.add_child(tribute_row)

		var tribute_lbl = Label.new()
		tribute_lbl.text = "Tribute"
		tribute_lbl.custom_minimum_size = Vector2(88, 0)
		tribute_row.add_child(tribute_lbl)

		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 60
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var current_rate = 15.0
		if GameManager.has_method("ziskej_vazalsky_odvod"):
			current_rate = float(GameManager.ziskej_vazalsky_odvod(GameManager.hrac_stat, subject)) * 100.0
		slider.value = current_rate
		tribute_row.add_child(slider)

		var pct_label = Label.new()
		pct_label.text = "%d%%" % int(round(current_rate))
		pct_label.custom_minimum_size = Vector2(44, 0)
		slider.value_changed.connect(func(v): pct_label.text = "%d%%" % int(round(v)))
		tribute_row.add_child(pct_label)

		var apply_btn = Button.new()
		apply_btn.text = "Apply %"
		apply_btn.pressed.connect(_on_vassal_tribute_apply_pressed.bind(subject, slider))
		tribute_row.add_child(apply_btn)

		if GameManager.has_method("ziskej_cisty_prijem_statu"):
			var inc = float(GameManager.ziskej_cisty_prijem_statu(subject))
			var est = max(0.0, inc) * (float(slider.value) / 100.0)
			var est_lbl = Label.new()
			est_lbl.text = "Estimated tribute/turn: $%.2f" % est
			est_lbl.modulate = Color(0.86, 0.94, 1.0, 0.92)
			slider.value_changed.connect(func(v):
				var est_now = max(0.0, float(GameManager.ziskej_cisty_prijem_statu(subject))) * (float(v) / 100.0)
				est_lbl.text = "Estimated tribute/turn: $%.2f" % est_now
			)
			card_v.add_child(est_lbl)

	_pozicuj_a_zmen_velikost_panelu_vazalu(vassals.size())

func _on_vassal_tribute_apply_pressed(subject_tag: String, slider: HSlider) -> void:
	if slider == null or not GameManager.has_method("nastav_vazalsky_odvod"):
		return
	var ok = bool(GameManager.nastav_vazalsky_odvod(GameManager.hrac_stat, subject_tag, float(slider.value)))
	if ok:
		_aktualizuj_mirove_overview_statistiky(str(GameManager.hrac_stat).strip_edges().to_upper(), true)

func _on_vassal_focus_pressed(subject_tag: String) -> void:
	_otevri_prehled_statu_podle_tagu(subject_tag)

func _on_vassal_release_pressed(subject_tag: String) -> void:
	if not GameManager.has_method("propustit_vazala"):
		return
	var ok = bool(GameManager.propustit_vazala(GameManager.hrac_stat, subject_tag))
	if ok:
		_obnov_panel_vazalu()
		if current_viewed_tag == str(subject_tag).strip_edges().to_upper():
			_aktualizuj_vztah_ui(current_viewed_tag)
		_aktualizuj_mirove_overview_statistiky(str(GameManager.hrac_stat).strip_edges().to_upper(), true)

func _aktualizuj_tlacitko_vazalu(je_hracuv_stat: bool) -> void:
	if _vassals_btn == null:
		return
	if je_hracuv_stat:
		_vassals_btn.show()
		var count := 0
		if GameManager.has_method("ziskej_vazaly_statu"):
			count = (GameManager.ziskej_vazaly_statu(GameManager.hrac_stat) as Array).size()
		_vassals_btn.text = "Vassals (%d)" % count
	else:
		_vassals_btn.hide()
		if _vassals_dialog and _vassals_dialog.visible:
			_vassals_dialog.hide()

func _zajisti_label_sily_armady() -> void:
	army_power_label = get_node_or_null("OverviewPanel/VBoxContainer/ArmyPowerLabel") as Label
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	if army_power_label == null:
		army_power_label = Label.new()
		army_power_label.name = "ArmyPowerLabel"
		army_power_label.text = "Army strength: 1.00x (+0 | +0.00%)"
		vbox.add_child(army_power_label)

	# Keep army power in the main stats block, directly above action separator.
	if action_separator and action_separator.get_parent() == vbox:
		vbox.move_child(army_power_label, action_separator.get_index())

func _zajisti_mirove_overview_labely() -> void:
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer") as VBoxContainer
	if vbox == null:
		return

	vassals_label = get_node_or_null("OverviewPanel/VBoxContainer/VassalsLabel") as Label
	if vassals_label == null:
		vassals_label = Label.new()
		vassals_label.name = "VassalsLabel"
		vassals_label.text = "Vassals: -"
		vbox.add_child(vassals_label)

	war_reparations_label = get_node_or_null("OverviewPanel/VBoxContainer/WarReparationsLabel") as Label
	if war_reparations_label == null:
		war_reparations_label = Label.new()
		war_reparations_label.name = "WarReparationsLabel"
		war_reparations_label.text = "War reparations: -"
		vbox.add_child(war_reparations_label)

	if action_separator and action_separator.get_parent() == vbox:
		vbox.move_child(vassals_label, action_separator.get_index())
		vbox.move_child(war_reparations_label, action_separator.get_index())

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
		ideology_apply_btn.text = "Change ideology"
		vbox.add_child(ideology_apply_btn)

	ideology_relocate_capital_btn = get_node_or_null("OverviewPanel/VBoxContainer/RelocateCapitalButton") as Button
	if ideology_relocate_capital_btn == null:
		ideology_relocate_capital_btn = Button.new()
		ideology_relocate_capital_btn.name = "RelocateCapitalButton"
		ideology_relocate_capital_btn.text = "Relocate capital"
		vbox.add_child(ideology_relocate_capital_btn)

	if action_separator and action_separator.get_parent() == vbox:
		var base_idx = action_separator.get_index()
		vbox.move_child(ideology_separator, base_idx)
		vbox.move_child(ideology_effects_label, ideology_separator.get_index() + 1)
		vbox.move_child(ideology_option, ideology_effects_label.get_index() + 1)
		vbox.move_child(ideology_apply_btn, ideology_option.get_index() + 1)
		vbox.move_child(ideology_relocate_capital_btn, ideology_apply_btn.get_index() + 1)

func _zajisti_vyzkum_controls() -> void:
	research_btn = get_node_or_null("OverviewPanel/VBoxContainer/ResearchButton") as Button
	if research_btn:
		return
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer")
	if vbox == null:
		return

	research_btn = Button.new()
	research_btn.name = "ResearchButton"
	research_btn.text = "Army"
	vbox.add_child(research_btn)

	# Keep research action close to ideology controls for player's own state.
	if ideology_relocate_capital_btn and ideology_relocate_capital_btn.get_parent() == vbox:
		vbox.move_child(research_btn, ideology_relocate_capital_btn.get_index() + 1)

func _vytvor_vyzkum_dialog() -> void:
	if _research_dialog != null:
		return

	_research_dialog = PanelContainer.new()
	_research_dialog.name = "ResearchDialog"
	_research_dialog.size = Vector2(640, 620)
	_research_dialog.top_level = true
	add_child(_research_dialog)
	_aplikuj_ingame_popup_styl(_research_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_research_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title = Label.new()
	title.text = "Army research"
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	_research_money_label = Label.new()
	_research_money_label.text = "Funds: -"
	root.add_child(_research_money_label)

	_army_research_summary_label = Label.new()
	_army_research_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_army_research_summary_label.text = "Army bonus: +0"
	root.add_child(_army_research_summary_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_research_list = VBoxContainer.new()
	_research_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_research_list)

	var grid_title = Label.new()
	grid_title.text = "Equipment grid"
	grid_title.add_theme_font_size_override("font_size", 18)
	_research_list.add_child(grid_title)

	_army_research_grid = GridContainer.new()
	_army_research_grid.columns = 3
	_army_research_grid.tooltip_text = "Each turn, 3 items drop. Buying works via drag and drop into the grid. Dragging onto the same item at the same level merges them."
	_army_research_grid.add_theme_constant_override("h_separation", 6)
	_army_research_grid.add_theme_constant_override("v_separation", 6)
	_research_list.add_child(_army_research_grid)

	_army_research_grid_cells.clear()

	var controls_row = HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 8)
	_research_list.add_child(controls_row)

	_army_research_reroll_btn = Button.new()
	_army_research_reroll_btn.text = "Reroll"
	_army_research_reroll_btn.pressed.connect(_on_army_research_reroll_pressed)
	controls_row.add_child(_army_research_reroll_btn)

	_army_research_quality_btn = Button.new()
	_army_research_quality_btn.text = "Upgrade quality"
	_army_research_quality_btn.pressed.connect(_on_army_research_quality_upgrade_pressed)
	controls_row.add_child(_army_research_quality_btn)

	_army_research_trash = ArmyTrashBin.new()
	_army_research_trash.owner_ui = self
	_army_research_trash.custom_minimum_size = Vector2(170, 40)
	_army_research_trash.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	controls_row.add_child(_army_research_trash)

	var trash_label = Label.new()
	trash_label.name = "TrashLabel"
	trash_label.text = "Trash (sell 75%)"
	trash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_army_research_trash.add_child(trash_label)

	var offers_title = Label.new()
	offers_title.text = "This turn's offers"
	offers_title.add_theme_font_size_override("font_size", 18)
	_research_list.add_child(offers_title)

	_army_research_offers = VBoxContainer.new()
	_army_research_offers.add_theme_constant_override("separation", 8)
	_research_list.add_child(_army_research_offers)

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _zavri_vyzkum_dialog())
	footer.add_child(close_btn)

	_research_dialog.hide()

func _zavri_vyzkum_dialog() -> void:
	_research_dialog_user_open = false
	if _research_dialog:
		_research_dialog.hide()

func _predhrej_vyzkum_dialog_layout() -> void:
	if _research_dialog == null or _research_dialog_layout_warmed:
		return
	if GameManager == null:
		return

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return

	_pozicuj_vyzkum_dialog()
	_research_dialog.modulate.a = 0.0
	_research_dialog.show()
	_aktualizuj_vyzkum_dialog(player_tag)
	await get_tree().process_frame
	if _research_dialog:
		_research_dialog.hide()
		_research_dialog.modulate.a = 1.0
	_research_dialog_user_open = false
	_research_dialog_layout_warmed = true

func _pozicuj_vyzkum_dialog() -> void:
	if _research_dialog == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return
	var vp = viewport.get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var left_x := 0.0
	if panel:
		left_x = max(0.0, panel.offset_right)
	var margin := 10.0
	var top_offset := 62.0
	var avail_w = max(280.0, vp.x - left_x - margin * 2.0)
	var avail_h = max(300.0, vp.y - top_offset - margin)

	var w = min(640.0, avail_w)
	var h = min(720.0, avail_h)
	_research_dialog.size = Vector2(w, h)
	_research_dialog.position = Vector2(clamp(left_x + margin, 0.0, max(0.0, vp.x - w)), clamp(top_offset, 0.0, max(0.0, vp.y - h)))

func _on_research_button_pressed() -> void:
	if current_viewed_tag == "":
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag != player_tag:
		return
	if _research_dialog and _research_dialog.visible:
		_zavri_vyzkum_dialog()
		return
	if not _research_dialog_layout_warmed:
		await _predhrej_vyzkum_dialog_layout()
	_research_dialog_user_open = true
	if _research_dialog:
		_pozicuj_vyzkum_dialog()
		_research_dialog.show()
	# Update after popup layout is ready to avoid first-open visual glitches.
	call_deferred("_aktualizuj_vyzkum_dialog", player_tag)

func _item_short_name(item_name: String) -> String:
	var words = item_name.strip_edges().split(" ")
	if words.size() >= 2:
		return (str(words[0]).substr(0, 1) + str(words[1]).substr(0, 1)).to_upper()
	if item_name.length() <= 3:
		return item_name.to_upper()
	return item_name.substr(0, 3).to_upper()

func _display_army_item_name(item_name: String) -> String:
	var raw = item_name.strip_edges().to_lower()
	match raw:
		"zbran":
			return "Weapon"
		"granat":
			return "Grenade"
		"auto":
			return "Truck"
		"raketomet":
			return "Rocket Launcher"
		"tezky tank":
			return "Heavy Tank"
		_:
			return item_name

func _aktualizuj_vyzkum_dialog(state_tag: String) -> void:
	if _research_dialog == null or _research_list == null:
		return
	if not GameManager.has_method("ziskej_armadni_lab_statu"):
		if _army_research_summary_label:
			_army_research_summary_label.text = "Army Lab is not available yet."
		return

	var info = GameManager.ziskej_armadni_lab_statu(state_tag) as Dictionary
	if not bool(info.get("ok", false)):
		if _army_research_summary_label:
			_army_research_summary_label.text = str(info.get("reason", "Failed to load Army Lab."))
		return
	_army_research_last_info = info.duplicate(true)
	_army_cell_drag_uid.clear()

	var treasury = float(info.get("treasury", 0.0))
	if _research_money_label:
		_research_money_label.text = "State funds: $%.2f bn" % treasury

	var power_flat = int(info.get("power_flat", 0))
	var power_pct = float(info.get("power_pct", 0.0)) * 100.0
	var expand_cost = float(info.get("expand_cost", 0.0))
	var grid_w = max(1, int(info.get("grid_w", 3)))
	var grid_h = max(1, int(info.get("grid_h", 3)))
	var grid_max_w = max(grid_w, int(info.get("grid_max_w", grid_w)))
	var grid_max_h = max(grid_h, int(info.get("grid_max_h", grid_h)))
	_army_research_grid_w = grid_w
	_army_research_grid_h = grid_h
	_army_research_view_w = min(grid_max_w, grid_w + 1)
	_army_research_view_h = min(grid_max_h, grid_h + 1)
	var unlocked = _army_unlocked_dict()
	var plus_candidates = _army_plus_candidates(unlocked, grid_max_w, grid_max_h)
	if _army_research_summary_label:
		_army_research_summary_label.text = "Army bonus: +%d and +%.2f%% from base power" % [power_flat, power_pct]

	var cell_texts: Array = []
	cell_texts.resize(_army_research_view_w * _army_research_view_h)
	for i in range(cell_texts.size()):
		cell_texts[i] = "-"

	var grid_items = info.get("grid_items", []) as Array
	for item_any in grid_items:
		var item = item_any as Dictionary
		var x = int(item.get("x", 0))
		var y = int(item.get("y", 0))
		var w = int(item.get("w", 1))
		var h = int(item.get("h", 1))
		var short = _item_short_name(_display_army_item_name(str(item.get("name", "?"))))
		var uid = str(item.get("offer_uid", ""))
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				if xx < 0 or yy < 0 or xx >= _army_research_view_w or yy >= _army_research_view_h:
					continue
				if not unlocked.has("%d_%d" % [xx, yy]):
					continue
				var cell_key = "%d" % (yy * _army_research_view_w + xx)
				if uid != "":
					_army_cell_drag_uid[cell_key] = uid
				cell_texts[yy * _army_research_view_w + xx] = short

	if _army_research_grid:
		var target_count = _army_research_view_w * _army_research_view_h
		for child in _army_research_grid.get_children():
			child.queue_free()
		_army_research_grid_cells.clear()
		_army_research_grid.columns = _army_research_view_w
		for yy in range(_army_research_view_h):
			for xx in range(_army_research_view_w):
				var idx = yy * _army_research_view_w + xx
				var key = "%d_%d" % [xx, yy]
				if unlocked.has(key):
					var cell = ArmyGridCell.new()
					cell.owner_ui = self
					cell.cell_index = idx
					cell.custom_minimum_size = Vector2(120, 52)
					var lbl = Label.new()
					lbl.name = "CellLabel"
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					lbl.text = "-"
					cell.add_child(lbl)
					_army_research_grid.add_child(cell)
					_army_research_grid_cells.append(cell)
				elif plus_candidates.has(key):
					var plus_btn = Button.new()
					plus_btn.text = "+ $%.0f" % expand_cost
					plus_btn.custom_minimum_size = Vector2(120, 52)
					plus_btn.pressed.connect(_on_army_research_buy_cell_pressed.bind(xx, yy))
					plus_btn.disabled = treasury < expand_cost
					_army_research_grid.add_child(plus_btn)
					_army_research_grid_cells.append(plus_btn)
				else:
					var filler = PanelContainer.new()
					filler.custom_minimum_size = Vector2(120, 52)
					filler.modulate = Color(1, 1, 1, 0.18)
					_army_research_grid.add_child(filler)
					_army_research_grid_cells.append(filler)

		for i in range(min(cell_texts.size(), _army_research_grid_cells.size())):
			var cell_any = _army_research_grid_cells[i]
			if not (cell_any is ArmyGridCell):
				continue
			var cell = cell_any as PanelContainer
			var lbl = cell.get_node_or_null("CellLabel") as Label
			if lbl:
				lbl.text = str(cell_texts[i])

	if _army_research_reroll_btn:
		var reroll_cost = float(info.get("reroll_cost", 0.0))
		_army_research_reroll_btn.text = "Reroll ($%.2f)" % reroll_cost
		_army_research_reroll_btn.disabled = treasury < reroll_cost

	if _army_research_quality_btn:
		var quality_level = int(info.get("quality_level", 0))
		var quality_cost = float(info.get("quality_upgrade_cost", 0.0))
		_army_research_quality_btn.text = "Upgrade drop quality Q%d -> Q%d ($%.2f)" % [quality_level, quality_level + 1, quality_cost]
		_army_research_quality_btn.tooltip_text = "Higher Q increases chance for higher-level items and raises the minimum offer quality."
		_army_research_quality_btn.disabled = quality_level >= 8 or treasury < quality_cost

	if _army_research_offers:
		for child in _army_research_offers.get_children():
			child.queue_free()

	var offers = info.get("offers", []) as Array
	for i in range(offers.size()):
		var offer = offers[i] as Dictionary
		if _army_research_offers == null:
			break
		var card = ArmyOfferCard.new()
		card.owner_ui = self
		card.offer_index = i
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		_army_research_offers.add_child(card)

		var card_margin = MarginContainer.new()
		card_margin.offset_left = 8
		card_margin.offset_top = 8
		card_margin.offset_right = -8
		card_margin.offset_bottom = -8
		card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(card_margin)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card_margin.add_child(row)

		var left = VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)

		var w = int(offer.get("w", 1))
		var h = int(offer.get("h", 1))
		var cost = float(offer.get("cost", 0.0))
		var power_item_flat = int(offer.get("power_flat", 0))
		var power_item_pct = float(offer.get("power_pct", 0.0)) * 100.0

		var title = Label.new()
		title.text = "%d) %s | %dx%d | $%.2f" % [i + 1, _display_army_item_name(str(offer.get("name", "Item"))), w, h, cost]
		left.add_child(title)

		var desc = Label.new()
		desc.text = "Effect: +%d power, +%.2f%% from base" % [power_item_flat, power_item_pct]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(desc)

		if treasury < cost:
			card.modulate = Color(1, 1, 1, 0.65)
		card.tooltip_text = "Buying works only via drag and drop into the grid."

func _vytvor_army_drag_preview(w: int, h: int, level: int = 1) -> Control:
	var iw = max(1, w)
	var ih = max(1, h)
	var cell_w := 44.0
	var cell_h := 30.0
	var sep := 4.0
	var inner_w = float(iw) * cell_w + float(max(0, iw - 1)) * sep
	var inner_h = float(ih) * cell_h + float(max(0, ih - 1)) * sep

	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(inner_w + 10.0, inner_h + 10.0)
	preview.size = preview.custom_minimum_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 5
	margin.offset_top = 5
	margin.offset_right = -5
	margin.offset_bottom = -5
	preview.add_child(margin)

	var grid = GridContainer.new()
	grid.columns = iw
	grid.add_theme_constant_override("h_separation", int(sep))
	grid.add_theme_constant_override("v_separation", int(sep))
	margin.add_child(grid)

	for _i in range(iw * ih):
		var block = ColorRect.new()
		block.custom_minimum_size = Vector2(cell_w, cell_h)
		block.color = Color(0.78, 0.89, 1.0, 0.70)
		grid.add_child(block)

	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2.ZERO
	root.size = Vector2.ZERO
	root.add_child(preview)
	preview.position = -preview.size * 0.5
	return root

func _army_offer_get_drag_data(offer_index: int, source: Control):
	if not _army_research_last_info.has("offers"):
		return null
	var offers = _army_research_last_info.get("offers", []) as Array
	if offer_index < 0 or offer_index >= offers.size():
		return null
	var offer = offers[offer_index] as Dictionary

	var preview = _vytvor_army_drag_preview(int(offer.get("w", 1)), int(offer.get("h", 1)), int(offer.get("level", 1)))
	source.set_drag_preview(preview)

	return {
		"type": "army_offer",
		"offer_index": offer_index
	}

func _army_unlocked_dict() -> Dictionary:
	var out: Dictionary = {}
	var arr = _army_research_last_info.get("unlocked_cells", []) as Array
	for c_any in arr:
		out[str(c_any)] = true
	return out

func _army_plus_candidates(unlocked: Dictionary, max_w: int, max_h: int) -> Dictionary:
	var out: Dictionary = {}
	for y in range(max_h):
		var row_right := -1
		for x in range(max_w):
			if unlocked.has("%d_%d" % [x, y]):
				row_right = x
		if row_right >= 0 and row_right + 1 < max_w:
			var key_r = "%d_%d" % [row_right + 1, y]
			if not unlocked.has(key_r):
				out[key_r] = true

	for x in range(max_w):
		var col_bottom := -1
		for y in range(max_h):
			if unlocked.has("%d_%d" % [x, y]):
				col_bottom = y
		if col_bottom >= 0 and col_bottom + 1 < max_h:
			var key_b = "%d_%d" % [x, col_bottom + 1]
			if not unlocked.has(key_b):
				out[key_b] = true
	return out

func _army_cell_index_to_xy(cell_index: int) -> Vector2i:
	var gw = max(1, _army_research_view_w)
	return Vector2i(cell_index % gw, int(cell_index / gw))

func _army_grid_item_at_cell(cell_index: int) -> Dictionary:
	var pos = _army_cell_index_to_xy(cell_index)
	var x = pos.x
	var y = pos.y
	var grid_items = _army_research_last_info.get("grid_items", []) as Array
	for item_any in grid_items:
		var item = item_any as Dictionary
		var ix = int(item.get("x", 0))
		var iy = int(item.get("y", 0))
		var iw = int(item.get("w", 1))
		var ih = int(item.get("h", 1))
		if x >= ix and x < (ix + iw) and y >= iy and y < (iy + ih):
			return item
	return {}

func _army_items_mozno_sloucit(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("id", "")) != str(b.get("id", "")):
		return false
	return int(a.get("level", 1)) == int(b.get("level", 1))

func _army_offer_mozno_sloucit_s_itemem(offer: Dictionary, item: Dictionary) -> bool:
	if offer.is_empty() or item.is_empty():
		return false
	if str(offer.get("id", "")) != str(item.get("id", "")):
		return false
	return int(offer.get("level", 1)) == int(item.get("level", 1))

func _army_grid_can_place_offer_at(cell_index: int, offer: Dictionary) -> bool:
	var pos = _army_cell_index_to_xy(cell_index)
	var x = pos.x
	var y = pos.y
	var w = int(offer.get("w", 1))
	var h = int(offer.get("h", 1))
	var grid_w = max(1, int(_army_research_last_info.get("grid_w", _army_research_grid_w)))
	var grid_h = max(1, int(_army_research_last_info.get("grid_h", _army_research_grid_h)))
	if x < 0 or y < 0:
		return false
	if x + w > grid_w or y + h > grid_h:
		return false

	var grid_items = _army_research_last_info.get("grid_items", []) as Array
	var unlocked = _army_unlocked_dict()
	var occupied: Dictionary = {}
	for item_any in grid_items:
		var item = item_any as Dictionary
		var ix = int(item.get("x", 0))
		var iy = int(item.get("y", 0))
		var iw = int(item.get("w", 1))
		var ih = int(item.get("h", 1))
		for yy in range(iy, iy + ih):
			for xx in range(ix, ix + iw):
				occupied["%d_%d" % [xx, yy]] = true

	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if not unlocked.has("%d_%d" % [xx, yy]):
				return false
			if occupied.has("%d_%d" % [xx, yy]):
				return false
	return true

func _army_grid_cell_can_drop(cell_index: int, data) -> bool:
	if not (data is Dictionary):
		return false
	var d = data as Dictionary
	var dtype = str(d.get("type", ""))
	if dtype != "army_offer" and dtype != "army_item":
		return false
	if dtype == "army_item":
		var item_uid = str(d.get("item_uid", ""))
		if item_uid == "":
			return false
		var grid_items = _army_research_last_info.get("grid_items", []) as Array
		var moving: Dictionary = {}
		for item_any in grid_items:
			var item = item_any as Dictionary
			if str(item.get("offer_uid", "")) == item_uid:
				moving = item
				break
		if moving.is_empty():
			return false
		var pos = _army_cell_index_to_xy(cell_index)
		var x = pos.x
		var y = pos.y
		var w = int(moving.get("w", 1))
		var h = int(moving.get("h", 1))
		var grid_w = max(1, int(_army_research_last_info.get("grid_w", _army_research_grid_w)))
		var grid_h = max(1, int(_army_research_last_info.get("grid_h", _army_research_grid_h)))
		if x < 0 or y < 0 or x + w > grid_w or y + h > grid_h:
			return false
		var target_item = _army_grid_item_at_cell(cell_index)
		if not target_item.is_empty() and str(target_item.get("offer_uid", "")) != item_uid:
			return _army_items_mozno_sloucit(moving, target_item)
		var unlocked = _army_unlocked_dict()
		var occupied: Dictionary = {}
		for item_any in grid_items:
			var item2 = item_any as Dictionary
			if str(item2.get("offer_uid", "")) == item_uid:
				continue
			var ix = int(item2.get("x", 0))
			var iy = int(item2.get("y", 0))
			var iw = int(item2.get("w", 1))
			var ih = int(item2.get("h", 1))
			for yy in range(iy, iy + ih):
				for xx in range(ix, ix + iw):
					occupied["%d_%d" % [xx, yy]] = true
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				if not unlocked.has("%d_%d" % [xx, yy]):
					return false
				if occupied.has("%d_%d" % [xx, yy]):
					return false
		return true

	if not _army_research_last_info.has("offers"):
		return false
	var offer_index = int(d.get("offer_index", -1))
	var offers = _army_research_last_info.get("offers", []) as Array
	if offer_index < 0 or offer_index >= offers.size():
		return false
	var offer = offers[offer_index] as Dictionary
	var treasury = float(_army_research_last_info.get("treasury", 0.0))
	var cost = float(offer.get("cost", 0.0))
	if treasury < cost:
		return false
	var target_item = _army_grid_item_at_cell(cell_index)
	if not target_item.is_empty():
		return _army_offer_mozno_sloucit_s_itemem(offer, target_item)
	return _army_grid_can_place_offer_at(cell_index, offer)

func _army_grid_cell_drop(cell_index: int, data) -> void:
	if not _army_grid_cell_can_drop(cell_index, data):
		return
	var d = data as Dictionary
	var dtype = str(d.get("type", ""))
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	var pos = _army_cell_index_to_xy(cell_index)
	var result: Dictionary = {}
	if dtype == "army_offer":
		var offer_index = int(d.get("offer_index", -1))
		var offers = _army_research_last_info.get("offers", []) as Array
		var offer: Dictionary = {}
		if offer_index >= 0 and offer_index < offers.size():
			offer = offers[offer_index] as Dictionary
		var target_item = _army_grid_item_at_cell(cell_index)
		if not target_item.is_empty() and _army_offer_mozno_sloucit_s_itemem(offer, target_item):
			if not GameManager.has_method("kup_a_slouc_armadni_nabidku"):
				return
			result = GameManager.kup_a_slouc_armadni_nabidku(player_tag, offer_index, str(target_item.get("offer_uid", ""))) as Dictionary
		else:
			if not GameManager.has_method("kup_armadni_nabidku_na_pozici"):
				return
			result = GameManager.kup_armadni_nabidku_na_pozici(player_tag, offer_index, pos.x, pos.y) as Dictionary
	elif dtype == "army_item":
		var item_uid = str(d.get("item_uid", ""))
		var target_item = _army_grid_item_at_cell(cell_index)
		var source_item: Dictionary = {}
		for it_any in (_army_research_last_info.get("grid_items", []) as Array):
			var it = it_any as Dictionary
			if str(it.get("offer_uid", "")) == item_uid:
				source_item = it
				break
		if not target_item.is_empty() and str(target_item.get("offer_uid", "")) != item_uid and _army_items_mozno_sloucit(source_item, target_item):
			if not GameManager.has_method("sloucit_armadni_itemy"):
				return
			result = GameManager.sloucit_armadni_itemy(player_tag, item_uid, str(target_item.get("offer_uid", ""))) as Dictionary
		else:
			if not GameManager.has_method("presun_armadni_item"):
				return
			result = GameManager.presun_armadni_item(player_tag, item_uid, pos.x, pos.y) as Dictionary
	else:
		return
	if not bool(result.get("ok", false)):
		zobraz_systemove_hlaseni("Army", str(result.get("reason", "Item cannot be placed here.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

func _army_grid_cell_get_drag_data(cell_index: int, source: Control):
	var key = "%d" % cell_index
	if not _army_cell_drag_uid.has(key):
		return null
	var item_uid = str(_army_cell_drag_uid[key])
	if item_uid == "":
		return null
	var moving: Dictionary = {}
	for item_any in (_army_research_last_info.get("grid_items", []) as Array):
		var item = item_any as Dictionary
		if str(item.get("offer_uid", "")) == item_uid:
			moving = item
			break
	if moving.is_empty():
		return null

	var preview = _vytvor_army_drag_preview(int(moving.get("w", 1)), int(moving.get("h", 1)), int(moving.get("level", 1)))
	source.set_drag_preview(preview)

	return {
		"type": "army_item",
		"item_uid": item_uid
	}

func _army_trash_can_drop(data) -> bool:
	if not (data is Dictionary):
		return false
	var d = data as Dictionary
	if str(d.get("type", "")) != "army_item":
		return false
	var item_uid = str(d.get("item_uid", ""))
	if item_uid == "":
		return false
	for it_any in (_army_research_last_info.get("grid_items", []) as Array):
		var it = it_any as Dictionary
		if str(it.get("offer_uid", "")) == item_uid:
			return true
	return false

func _army_trash_drop(data) -> void:
	if not _army_trash_can_drop(data):
		return
	var d = data as Dictionary
	var item_uid = str(d.get("item_uid", ""))
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	if not GameManager.has_method("prodej_armadni_item"):
		return
	var result = GameManager.prodej_armadni_item(player_tag, item_uid) as Dictionary
	if not bool(result.get("ok", false)):
		zobraz_systemove_hlaseni("Army", str(result.get("reason", "Sale failed.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

func _on_army_research_buy_offer_pressed(offer_index: int) -> void:
	# Legacy fallback. Main flow is drag & drop only.
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	if not GameManager.has_method("kup_armadni_nabidku"):
		return
	var result = GameManager.kup_armadni_nabidku(player_tag, offer_index) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Army", str(result.get("reason", "Purchase failed.")))
		_aktualizuj_vyzkum_dialog(player_tag)
		return
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

func _on_army_research_buy_cell_pressed(x: int, y: int) -> void:
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	if not GameManager.has_method("koupit_armadni_bunku"):
		return
	var result = GameManager.koupit_armadni_bunku(player_tag, x, y) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Army", str(result.get("reason", "Cell purchase failed.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

func _on_army_research_reroll_pressed() -> void:
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	if not GameManager.has_method("reroll_armadni_nabidky"):
		return
	var result = GameManager.reroll_armadni_nabidky(player_tag) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Army", str(result.get("reason", "Reroll failed.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

func _on_army_research_quality_upgrade_pressed() -> void:
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		return
	if not GameManager.has_method("vylepsi_kvalitu_dropu_armady"):
		return
	var result = GameManager.vylepsi_kvalitu_dropu_armady(player_tag) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Army", str(result.get("reason", "Quality upgrade failed.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

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
		return "Unknown"
	match raw:
		"demokracie":
			return "Democracy"
		"kralovstvi":
			return "Kingdom"
		"autokracie":
			return "Autocracy"
		"komunismus":
			return "Communism"
		"nacismus":
			return "Nazism"
		"fasismus":
			return "Fascism"
		_:
			return raw.capitalize()

func _ziskej_vyhody_nevyhody_ideologie(ideology: String) -> Dictionary:
	var ideo = _normalizuj_ideologii(ideology)
	match ideo:
		"demokracie":
			return {
				"plus": ["stable economy", "better relations with similar regimes"],
				"minus": ["slower decision-making", "lower tolerance for aggression"]
			}
		"kralovstvi":
			return {
				"plus": ["strong legitimacy of power", "easier diplomatic ties with traditional states"],
				"minus": ["risk of conservative stagnation", "worse relations with revolutionary regimes"]
			}
		"autokracie":
			return {
				"plus": ["fast centralized decision-making", "strong internal control"],
				"minus": ["lower international trust", "tension with democratic states"]
			}
		"komunismus":
			return {
				"plus": ["strong national mobilization", "focus on heavy industry"],
				"minus": ["weaker relations with monarchies and democracies", "higher geopolitical tension"]
			}
		"nacismus", "fasismus":
			return {
				"plus": ["aggressive military mobilization", "high power control"],
				"minus": ["heavy diplomatic sanctions", "rapid deterioration of relations with opponents"]
			}
		_:
			return {
				"plus": ["flag and diplomatic profile change"],
				"minus": ["uncertain foreign reaction"]
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
		return "Ideology data is unavailable."

	var base_profile = GameManager.ziskej_ideologicky_ekonomicky_profil(base_ideology) as Dictionary
	if base_profile.is_empty():
		return "Ideology data is unavailable."

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

	return "Cost/soldier: %s%s\nUpkeep/soldier / turn: %s%s\nIncome rate from GDP: %.2f%%%s\nGDP growth: %.3f%s\nPopulation growth / turn: %.3f%%%s\nRecruit regen (core): %.2f%%%s\nRecruit regen (occupied): %.2f%%%s" % [
		_format_money_auto(recruit_cost, 4),
		_format_delta_text_color(d_recruit_cost, 4, " M") if show_delta else "",
		_format_money_auto(upkeep_cost, 4),
		_format_delta_text_color(d_upkeep_cost, 4, " M") if show_delta else "",
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
		return "%.*fk" % [max(1, mil_decimals - 1), value * 1000.0]
	return "%.*fM" % [mil_decimals, value]

func _format_delta_text_color(value: float, decimals: int, suffix: String = "") -> String:
	var txt := ""
	if suffix == " M" and absf(value) < 0.01:
		# Tiny money changes are easier to read in thousands.
		txt = "%+.1fk" % (value * 1000.0)
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
	ideo_label.text = "Regime: " + _display_ideologie(current_ideo)

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
	ideo_label.text = "Regime: " + _display_ideologie(selected)

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
	ideo_label.text = "Regime: " + _display_ideologie(selected)

func _ziskej_vsechny_provincie_pro_prehled() -> Dictionary:
	var map_loader = _ziskej_map_loader_node()
	if map_loader:
		var maybe_provinces = map_loader.get("provinces")
		if maybe_provinces is Dictionary:
			return maybe_provinces
	if GameManager and not GameManager.map_data.is_empty():
		return GameManager.map_data
	return {}

func _ziskej_hlavni_mesto_statu_z_mapy(state_tag: String) -> int:
	var wanted = state_tag.strip_edges().to_upper()
	if wanted == "" or wanted == "SEA":
		return -1
	var provinces = _ziskej_vsechny_provincie_pro_prehled()
	if provinces.is_empty():
		return -1

	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		if bool(d.get("is_capital", false)):
			return p_id

	# Fallback: if capital is occupied, it can still be marked by core owner.
	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		var d = provinces[p_id] as Dictionary
		if str(d.get("core_owner", "")).strip_edges().to_upper() != wanted:
			continue
		if bool(d.get("is_capital", false)):
			return p_id

	return -1

func _zamer_kameru_na_mirovou_konferenci() -> void:
	if _active_peace_conference.is_empty():
		return
	var loser = str(_active_peace_conference.get("loser", "")).strip_edges().to_upper()
	if loser == "" or loser == "SEA":
		return

	var capital_pid = _ziskej_hlavni_mesto_statu_z_mapy(loser)
	if capital_pid > 0:
		_posun_kameru_na_stat(loser, true, capital_pid)
		return

	# If no explicit capital is found, keep existing state-focus fallback behavior.
	_posun_kameru_na_stat(loser, true)

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
	if ideology_separator == null or ideology_option == null or ideology_apply_btn == null or ideology_effects_label == null or ideology_relocate_capital_btn == null:
		return

	var is_player = owner_tag == str(GameManager.hrac_stat).strip_edges().to_upper()
	if not is_player:
		ideology_separator.hide()
		ideology_effects_label.hide()
		ideology_option.hide()
		ideology_apply_btn.hide()
		ideology_relocate_capital_btn.hide()
		_vycisti_nahled_ideologie_v_ui()
		return

	ideology_separator.show()
	ideology_effects_label.show()
	ideology_option.show()
	ideology_apply_btn.show()
	ideology_relocate_capital_btn.show()

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
	_aktualizuj_tlacitko_presunu_hlavniho_mesta(owner_tag)

func _aktualizuj_tlacitko_presunu_hlavniho_mesta(owner_tag: String) -> void:
	if ideology_relocate_capital_btn == null:
		return

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var viewed = owner_tag.strip_edges().to_upper()
	if viewed == "" or viewed != player_tag:
		ideology_relocate_capital_btn.hide()
		return

	ideology_relocate_capital_btn.show()
	if _ceka_na_vyber_cile_hlavniho_mesta:
		ideology_relocate_capital_btn.disabled = false
		ideology_relocate_capital_btn.text = "Cancel capital target selection"
		return
	if _relocate_capital_action_lock:
		ideology_relocate_capital_btn.disabled = true
		return
	if not GameManager.has_method("muze_presunout_hlavni_mesto"):
		ideology_relocate_capital_btn.disabled = true
		ideology_relocate_capital_btn.text = "Relocate capital"
		return

	var can_start_targeting = true
	if GameManager.has_method("ma_dostupny_cil_presunu_hlavniho_mesta"):
		can_start_targeting = bool(GameManager.ma_dostupny_cil_presunu_hlavniho_mesta(viewed))
	ideology_relocate_capital_btn.text = "Relocate capital"
	ideology_relocate_capital_btn.disabled = not can_start_targeting

func _on_relocate_capital_pressed() -> void:
	if _relocate_capital_action_lock:
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag == "" or current_viewed_tag != player_tag:
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader == null and get_tree().current_scene and get_tree().current_scene.has_method("aktivuj_rezim_vyberu_hlavniho_mesta"):
		map_loader = get_tree().current_scene
	if map_loader == null:
		await zobraz_systemove_hlaseni("Capital", "Map module not found, cannot start target selection.")
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	if _ceka_na_vyber_cile_hlavniho_mesta:
		if map_loader.has_method("zrus_rezim_vyberu_hlavniho_mesta"):
			map_loader.zrus_rezim_vyberu_hlavniho_mesta()
		_ceka_na_vyber_cile_hlavniho_mesta = false
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	if not map_loader.has_method("aktivuj_rezim_vyberu_hlavniho_mesta"):
		await zobraz_systemove_hlaseni("Capital", "Map module does not support target selection for capital relocation.")
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	var activation = map_loader.aktivuj_rezim_vyberu_hlavniho_mesta(player_tag)
	if not bool((activation as Dictionary).get("ok", false)):
		await zobraz_systemove_hlaseni("Capital", str((activation as Dictionary).get("reason", "No valid target is available for capital relocation.")))
		_ceka_na_vyber_cile_hlavniho_mesta = false
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	_ceka_na_vyber_cile_hlavniho_mesta = true
	_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)

func zrus_vyber_cile_hlavniho_mesta_ui() -> void:
	_ceka_na_vyber_cile_hlavniho_mesta = false
	_relocate_capital_action_lock = false
	if current_viewed_tag != "":
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(current_viewed_tag)

func obsluha_presunu_hlavniho_mesta_z_mapy(result: Dictionary, _target_province_id: int) -> void:
	_ceka_na_vyber_cile_hlavniho_mesta = false
	_relocate_capital_action_lock = false
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()

	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Capital", str(result.get("reason", "Capital relocation failed.")))
		_aktualizuj_tlacitko_presunu_hlavniho_mesta(player_tag)
		return

	await zobraz_systemove_hlaseni(
		"Capital",
		"Moved: %s -> %s\nCost: %s" % [
			str(result.get("old_capital_name", "Old capital")),
			str(result.get("new_capital_name", "New capital")),
			_format_money_auto(float(result.get("cost", 0.0)), 2)
		]
	)
	_obnov_otevreny_prehled_statu()

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
	_pozicuj_settings_dialog()
	_pozicuj_gift_dialog()
	_pozicuj_mirovou_konferenci_dialog()
	_pozicuj_hlaseni_mirove_konference()
	if _vassals_dialog and _vassals_dialog.visible:
		_pozicuj_a_zmen_velikost_panelu_vazalu()
	if _research_dialog and _research_dialog.visible:
		_pozicuj_vyzkum_dialog()

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if _peace_dialog and _peace_dialog.visible:
				_on_peace_close_pressed()
				get_viewport().set_input_as_handled()
				return
			if _research_dialog and _research_dialog.visible:
				_zavri_vyzkum_dialog()
				get_viewport().set_input_as_handled()
				return
			if _gift_dialog and _gift_dialog.visible:
				_gift_dialog.hide()
				get_viewport().set_input_as_handled()
				return
			if _save_dialog and _save_dialog.visible:
				_save_dialog.hide()
				get_viewport().set_input_as_handled()
				return
			if _settings_dialog and _settings_dialog.visible:
				_settings_dialog.hide()
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
	_pause_menu_panel.wrap_controls = false
	_pause_menu_panel.unresizable = true
	_pause_menu_panel.min_size = Vector2i(340, 358)
	_pause_menu_panel.size = Vector2(340, 358)
	add_child(_pause_menu_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.18, 0.97)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.45, 0.6, 0.79, 0.7)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_pause_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var root_margin = MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu_panel.add_child(root_margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(vbox)

	var title = Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var _btn_defs = [
		["Resume", Callable(self, "_on_pause_resume_pressed")],
		["Settings", Callable(self, "_on_pause_options_pressed")],
		["Surrender", Callable(self, "_on_pause_surrender_pressed")],
		["Save / Load", Callable(self, "_on_pause_save_pressed")],
		["Quit", Callable(self, "_on_pause_quit_pressed")],
	]
	for _bd in _btn_defs:
		var _b = Button.new()
		_b.text = _bd[0]
		_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_b.custom_minimum_size = Vector2(0, 44)
		_b.pressed.connect(_bd[1])
		vbox.add_child(_b)

	_pause_confirm_dialog = ConfirmationDialog.new()
	_pause_confirm_dialog.wrap_controls = false
	_pause_confirm_dialog.unresizable = true
	_pause_confirm_dialog.min_size = Vector2i(480, 200)
	_pause_confirm_dialog.ok_button_text = "Yes"
	_pause_confirm_dialog.cancel_button_text = "No"
	_pause_confirm_dialog.confirmed.connect(_on_pause_confirmed)
	_pause_confirm_dialog.visibility_changed.connect(_on_pause_confirm_visibility_changed)
	add_child(_pause_confirm_dialog)
	_aplikuj_ingame_popup_styl(_pause_confirm_dialog)
	var _conf_lbl = _pause_confirm_dialog.get_label()
	if _conf_lbl:
		_conf_lbl.add_theme_font_size_override("font_size", 18)
		_conf_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_conf_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_conf_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_vytvor_save_load_dialogy()
	_vytvor_settings_dialog()

	_pause_menu_panel.hide()
	_pozicuj_pause_menu()
	_pozicuj_save_load_popupy()
	_pozicuj_settings_dialog()

func _aplikuj_ingame_popup_styl(node) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.10, 0.18, 0.97)
	s.border_color = Color(0.45, 0.60, 0.79, 0.70)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	node.add_theme_stylebox_override("panel", s)

func _vytvor_darovaci_dialog() -> void:
	_gift_dialog = PopupPanel.new()
	_gift_dialog.name = "GiftDialog"
	_gift_dialog.size = Vector2(420, 190)
	add_child(_gift_dialog)
	_aplikuj_ingame_popup_styl(_gift_dialog)

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
	title.text = "Send financial gift"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Amount in M USD"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_gift_amount_input = LineEdit.new()
	_gift_amount_input.placeholder_text = "e.g. 50"
	_gift_amount_input.text_submitted.connect(func(_t): _on_confirm_gift_money())
	vbox.add_child(_gift_amount_input)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Send"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(_on_confirm_gift_money)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
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

func _vytvor_mirovou_konferenci_dialog() -> void:
	if _peace_dialog != null:
		return

	_peace_dialog = PopupPanel.new()
	_peace_dialog.name = "PeaceConferenceDialog"
	_peace_dialog.size = Vector2(520, 430)
	_peace_dialog.exclusive = false
	_peace_dialog.popup_window = false
	add_child(_peace_dialog)
	_aplikuj_ingame_popup_styl(_peace_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peace_dialog.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_peace_title_label = Label.new()
	_peace_title_label.text = "Peace conference"
	_peace_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peace_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_peace_title_label)

	_peace_points_label = Label.new()
	_peace_points_label.text = "Points: 0"
	vbox.add_child(_peace_points_label)

	_peace_participants_label = Label.new()
	_peace_participants_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_peace_participants_label)

	_peace_annex_check = CheckBox.new()
	_peace_annex_check.text = "Annex whole country"
	_peace_annex_check.toggled.connect(func(_v): _aktualizuj_mirovou_konferenci_preview())
	vbox.add_child(_peace_annex_check)

	_peace_pick_btn = Button.new()
	_peace_pick_btn.text = "Select provinces on map"
	_peace_pick_btn.pressed.connect(_on_peace_pick_provinces_pressed)
	vbox.add_child(_peace_pick_btn)

	_peace_selected_label = Label.new()
	_peace_selected_label.text = "Selected on map: 0"
	vbox.add_child(_peace_selected_label)

	_peace_take_label = Label.new()
	_peace_take_label.text = "Take provinces: 0"
	vbox.add_child(_peace_take_label)

	_peace_vassal_check = CheckBox.new()
	_peace_vassal_check.text = "Create vassal state"
	_peace_vassal_check.toggled.connect(func(_v): _aktualizuj_mirovou_konferenci_preview())
	vbox.add_child(_peace_vassal_check)

	_peace_reparations_label = Label.new()
	_peace_reparations_label.text = "War reparations (turns): 0"
	vbox.add_child(_peace_reparations_label)

	_peace_reparations_slider = HSlider.new()
	_peace_reparations_slider.min_value = 0
	_peace_reparations_slider.max_value = 0
	_peace_reparations_slider.step = 1
	_peace_reparations_slider.value_changed.connect(func(_v): _aktualizuj_mirovou_konferenci_preview())
	vbox.add_child(_peace_reparations_slider)

	_peace_cost_label = Label.new()
	_peace_cost_label.text = "Cost: 0 / 0"
	vbox.add_child(_peace_cost_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_peace_confirm_btn = Button.new()
	_peace_confirm_btn.text = "Confirm terms"
	_peace_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_peace_confirm_btn.pressed.connect(_on_potvrdit_mirovou_konferenci)
	btn_row.add_child(_peace_confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Later"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_on_peace_close_pressed)
	btn_row.add_child(cancel_btn)

	_peace_dialog.hide()
	_pozicuj_mirovou_konferenci_dialog()

func _pozicuj_mirovou_konferenci_dialog() -> void:
	if not _peace_dialog:
		return
	var vp = get_viewport().get_visible_rect().size
	var margin := 12.0
	var w = min(520.0, max(320.0, vp.x - margin * 2.0))
	var h = min(430.0, max(260.0, vp.y - margin * 2.0))
	_peace_dialog.size = Vector2(w, h)
	_peace_dialog.position = Vector2(max(0.0, vp.x - w - margin), max(0.0, vp.y - h - margin))

func _vytvor_hlaseni_mirove_konference() -> void:
	if _peace_notice_panel != null:
		return

	_peace_notice_panel = Panel.new()
	_peace_notice_panel.name = "PeaceConferenceNotice"
	_peace_notice_panel.size = Vector2(500, 48)
	_peace_notice_panel.visible = false
	_peace_notice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_peace_notice_panel.z_index = 120
	add_child(_peace_notice_panel)

	var margin = MarginContainer.new()
	margin.offset_left = 8
	margin.offset_top = 7
	margin.offset_right = -8
	margin.offset_bottom = -7
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peace_notice_panel.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	_peace_notice_flag = TextureRect.new()
	_peace_notice_flag.custom_minimum_size = Vector2(28, 20)
	_peace_notice_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_peace_notice_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_peace_notice_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_peace_notice_flag)

	_peace_notice_label = Label.new()
	_peace_notice_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_peace_notice_label.clip_text = true
	_peace_notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_peace_notice_label.text = "Peace negotiation available."
	if popup_request_text:
		_peace_notice_label.add_theme_font_size_override("font_size", popup_request_text.get_theme_font_size("font_size"))
	row.add_child(_peace_notice_label)

	var btn_wrap = MarginContainer.new()
	btn_wrap.add_theme_constant_override("margin_top", 2)
	btn_wrap.add_theme_constant_override("margin_bottom", 2)
	btn_wrap.add_theme_constant_override("margin_right", 6)
	row.add_child(btn_wrap)

	_peace_notice_btn = Button.new()
	_peace_notice_btn.text = "Peace negotiation"
	_peace_notice_btn.custom_minimum_size = Vector2(104, 30)
	_peace_notice_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_peace_notice_btn.pressed.connect(_on_peace_notice_open_pressed)
	if popup_accept_btn:
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb = popup_accept_btn.get_theme_stylebox(style_name)
			if sb:
				_peace_notice_btn.add_theme_stylebox_override(style_name, sb)
		_peace_notice_btn.add_theme_font_size_override("font_size", popup_accept_btn.get_theme_font_size("font_size"))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			_peace_notice_btn.add_theme_color_override(color_name, popup_accept_btn.get_theme_color(color_name))
		for const_name in ["h_separation", "outline_size"]:
			_peace_notice_btn.add_theme_constant_override(const_name, popup_accept_btn.get_theme_constant(const_name))
	btn_wrap.add_child(_peace_notice_btn)

	_pozicuj_hlaseni_mirove_konference()

func _pozicuj_hlaseni_mirove_konference() -> void:
	if _peace_notice_panel == null:
		return
	var vp = get_viewport().get_visible_rect().size
	var req_w = clamp(vp.x * 0.50, 500.0, 820.0)
	var req_h = 48.0
	if diplomacy_request_popup and diplomacy_request_popup.visible:
		req_h = float(diplomacy_request_popup.size.y)
	_peace_notice_panel.size = Vector2(req_w, req_h)
	var p_size = _peace_notice_panel.size
	var x = (vp.x - p_size.x) * 0.5
	var y = _topbar_bottom_y() + POPUP_TOP_MARGIN
	if diplomacy_request_popup and diplomacy_request_popup.visible:
		y = diplomacy_request_popup.position.y + diplomacy_request_popup.size.y + POPUP_GAP
	if _queue_preview_panel and _queue_preview_panel.visible:
		y = _queue_preview_panel.position.y + _queue_preview_panel.size.y + POPUP_GAP
	x = clampf(x, 8.0, maxf(8.0, vp.x - p_size.x - 8.0))
	y = clampf(y, 8.0, maxf(8.0, vp.y - p_size.y - 8.0))
	_peace_notice_panel.position = Vector2(x, y)

func _aktualizuj_hlaseni_mirove_konference() -> void:
	if _peace_notice_panel == null:
		return
	if _peace_dialog and _peace_dialog.visible:
		_peace_notice_panel.hide()
		return
	if not GameManager or not GameManager.has_method("ziskej_prvni_mirovou_konferenci_pro_hrace"):
		_peace_notice_panel.hide()
		return

	var conf = GameManager.ziskej_prvni_mirovou_konferenci_pro_hrace(GameManager.hrac_stat) as Dictionary
	if conf.is_empty():
		_peace_notice_deferred_conf_id = -1
		_peace_notice_panel.hide()
		return
	var queue_count := 1
	if GameManager.has_method("ziskej_pocet_mirovych_konferenci_pro_hrace"):
		queue_count = maxi(1, int(GameManager.ziskej_pocet_mirovych_konferenci_pro_hrace(GameManager.hrac_stat)))

	var conf_id = int(conf.get("id", -1))
	var waiting_decision = (conf_id != -1 and conf_id != _peace_notice_deferred_conf_id)
	var reason = str(conf.get("reason", "peace"))
	var loser = str(conf.get("loser", "?"))
	var loser_name = _ziskej_jmeno_statu_podle_tagu(loser)
	var loser_ideology = _ziskej_aktualni_ideologii_statu(loser)
	if _peace_notice_flag:
		_peace_notice_flag.texture = _resolve_flag_texture(loser, loser_ideology)
	if reason == "capitulation" and waiting_decision:
		_peace_notice_label.text = "%s capitulated. Peace negotiations are ready." % loser_name
	elif reason == "capitulation":
		_peace_notice_label.text = "%s capitulated. Peace negotiations are available in the menu." % loser_name
	elif waiting_decision:
		_peace_notice_label.text = "Peace negotiations with %s are available." % loser_name
	else:
		_peace_notice_label.text = "Peace negotiations with %s are available in the menu." % loser_name
	if queue_count > 1:
		_peace_notice_label.text += " | Queue: %d" % queue_count

	if _peace_notice_btn:
		_peace_notice_btn.visible = true
		_peace_notice_btn.text = "Peace negotiation (%d)" % queue_count if queue_count > 1 else "Peace negotiation"

	_peace_notice_panel.show()
	_pozicuj_hlaseni_mirove_konference()

func _on_peace_notice_open_pressed() -> void:
	_otevri_mirovou_konferenci_z_fronty()

func ma_otevrene_mirove_jednani() -> bool:
	return _peace_dialog != null and _peace_dialog.visible

func _spust_vyber_miru_na_mape(show_error_popup: bool) -> bool:
	if _active_peace_conference.is_empty():
		return false
	var map_node = _ziskej_map_node_pro_mir()
	if map_node == null:
		if show_error_popup:
			zobraz_systemove_hlaseni("Peace conference", "Map module was not found.")
		return false
	if not map_node.has_method("aktivuj_rezim_vyberu_miru"):
		if show_error_popup:
			zobraz_systemove_hlaseni("Peace conference", "Map does not support province selection for peace.")
		return false

	var winner = str(_active_peace_conference.get("winner", ""))
	var loser = str(_active_peace_conference.get("loser", ""))
	var activation = map_node.aktivuj_rezim_vyberu_miru(winner, loser, _peace_selected_provinces)
	if not bool((activation as Dictionary).get("ok", false)):
		if show_error_popup:
			zobraz_systemove_hlaseni("Peace conference", str((activation as Dictionary).get("reason", "Failed to start map selection.")))
		return false

	_ceka_na_vyber_miru = true
	if activation.has("selected"):
		_peace_selected_provinces = ((activation as Dictionary).get("selected", []) as Array).duplicate()
	_aktualizuj_mirovou_konferenci_preview()
	return true

func _aktualizuj_mirovou_konferenci_preview() -> void:
	if _active_peace_conference.is_empty():
		return
	if _peace_reparations_slider == null:
		return

	var annex_all = bool(_peace_annex_check.button_pressed)
	var take_count = 0 if annex_all else _peace_selected_provinces.size()
	var vassal = bool(_peace_vassal_check.button_pressed)
	var repar_turns = int(_peace_reparations_slider.value)

	var loser = str(_active_peace_conference.get("loser", ""))
	var points = int(_active_peace_conference.get("points", 0))
	var cost = 0
	if GameManager.has_method("spocitej_cenu_mirovych_pozadavku"):
		cost = int(GameManager.spocitej_cenu_mirovych_pozadavku(loser, take_count, annex_all, vassal, repar_turns))
	else:
		cost = take_count * 8

	_peace_take_label.text = "Take provinces: %d" % take_count
	if _peace_selected_label:
		_peace_selected_label.text = "Selected on map: %d" % _peace_selected_provinces.size()
	if _peace_pick_btn:
		_peace_pick_btn.disabled = annex_all
		_peace_pick_btn.text = "Finish map selection" if _ceka_na_vyber_miru else "Select provinces on map"
	_peace_reparations_label.text = "War reparations (turns): %d" % repar_turns
	_peace_cost_label.text = "Cost: %d / %d points" % [cost, points]
	_peace_confirm_btn.disabled = cost > points

func _ziskej_map_node_pro_mir() -> Node:
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader != null:
		return map_loader
	if get_tree().current_scene and get_tree().current_scene.has_method("aktivuj_rezim_vyberu_miru"):
		return get_tree().current_scene
	return null

func _on_peace_pick_provinces_pressed() -> void:
	if _active_peace_conference.is_empty():
		return
	var map_node = _ziskej_map_node_pro_mir()
	if map_node == null:
		zobraz_systemove_hlaseni("Peace conference", "Map module was not found.")
		return

	if _ceka_na_vyber_miru:
		if map_node.has_method("zrus_rezim_vyberu_miru"):
			map_node.zrus_rezim_vyberu_miru()
		_ceka_na_vyber_miru = false
		_aktualizuj_mirovou_konferenci_preview()
		return
	_spust_vyber_miru_na_mape(true)

func zrus_vyber_miru_ui() -> void:
	_ceka_na_vyber_miru = false
	_aktualizuj_mirovou_konferenci_preview()

func obsluha_vyberu_miru_z_mapy(result: Dictionary, _province_id: int) -> void:
	if _active_peace_conference.is_empty():
		return
	if not bool(result.get("ok", false)):
		return
	_peace_selected_provinces = (result.get("selected", []) as Array).duplicate()
	_aktualizuj_mirovou_konferenci_preview()

func _on_peace_close_pressed() -> void:
	if not _active_peace_conference.is_empty():
		_peace_notice_deferred_conf_id = int(_active_peace_conference.get("id", -1))
	var map_node = _ziskej_map_node_pro_mir()
	if map_node and map_node.has_method("zrus_rezim_vyberu_miru"):
		map_node.zrus_rezim_vyberu_miru()
	_ceka_na_vyber_miru = false
	if _peace_dialog:
		_peace_dialog.hide()
	_aktualizuj_hlaseni_mirove_konference()

func _otevri_mirovou_konferenci_z_fronty() -> void:
	if not GameManager or not GameManager.has_method("ziskej_prvni_mirovou_konferenci_pro_hrace"):
		return
	if _peace_dialog and _peace_dialog.visible:
		return

	var conf = GameManager.ziskej_prvni_mirovou_konferenci_pro_hrace(GameManager.hrac_stat) as Dictionary
	if conf.is_empty():
		_aktualizuj_hlaseni_mirove_konference()
		return

	_active_peace_conference = conf.duplicate(true)
	var winner = str(conf.get("winner", ""))
	var loser = str(conf.get("loser", ""))
	var points = int(conf.get("points", 0))
	var max_rep = int(conf.get("max_reparations_turns", 0))

	_peace_points_label.text = "Points: %d" % points
	_peace_participants_label.text = "War participants: %s vs %s" % [winner, loser]
	_peace_selected_provinces = []
	_ceka_na_vyber_miru = false
	_peace_annex_check.button_pressed = false
	_peace_vassal_check.button_pressed = false
	_peace_reparations_slider.min_value = 0
	_peace_reparations_slider.max_value = max(0, max_rep)
	_peace_reparations_slider.value = 0

	_aktualizuj_mirovou_konferenci_preview()
	_pozicuj_mirovou_konferenci_dialog()
	_peace_dialog.show()
	if _peace_notice_panel:
		_peace_notice_panel.hide()
	_zamer_kameru_na_mirovou_konferenci()
	# Start map focus/selection immediately, just like capital relocation targeting mode.
	_spust_vyber_miru_na_mape(false)

func _on_potvrdit_mirovou_konferenci() -> void:
	if _active_peace_conference.is_empty():
		return
	if not GameManager.has_method("hrac_uzavri_mirovou_konferenci"):
		return

	var demands = {
		"take_provinces": _peace_selected_provinces.size(),
		"selected_provinces": _peace_selected_provinces.duplicate(),
		"annex_all": bool(_peace_annex_check.button_pressed),
		"make_vassal": bool(_peace_vassal_check.button_pressed),
		"reparations_turns": int(_peace_reparations_slider.value)
	}
	var conf_id = int(_active_peace_conference.get("id", -1))
	var result = GameManager.hrac_uzavri_mirovou_konferenci(GameManager.hrac_stat, conf_id, demands) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Peace conference", str(result.get("reason", "Failed to confirm terms.")))
		return

	if _peace_dialog:
		_peace_dialog.hide()
	_peace_notice_deferred_conf_id = -1
	_aktualizuj_hlaseni_mirove_konference()
	var map_node = _ziskej_map_node_pro_mir()
	if map_node and map_node.has_method("zrus_rezim_vyberu_miru"):
		map_node.zrus_rezim_vyberu_miru()
	_ceka_na_vyber_miru = false
	_active_peace_conference = {}
	_peace_selected_provinces = []
	_aktualizuj_hlaseni_mirove_konference()
	await zobraz_systemove_hlaseni(
		"Peace conference",
		"Terms confirmed: transferred provinces %d, vassal: %s, reparations: %d turns." % [
			int(result.get("transferred", 0)),
			"yes" if bool(result.get("make_vassal", false)) else "no",
			int(result.get("reparations_turns", 0))
		]
	)
	_obnov_otevreny_prehled_statu()
	_aktualizuj_hlaseni_mirove_konference()

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
			"Diplomacy",
			"Gift of %s USD sent to %s.\nRelation: %+0.1f" % [
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

	await zobraz_systemove_hlaseni("Diplomacy", str(result.get("reason", "Failed to send gift.")))

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
		_pause_menu_panel.show()

func _zavri_pause_menu() -> void:
	if _pause_menu_panel:
		_pause_menu_panel.hide()

func _zobraz_pause_confirm(action: String, title: String, text: String) -> void:
	if not _pause_confirm_dialog:
		return
	_pause_pending_action = action
	_pause_confirm_accepted = false
	_pause_confirm_dialog.title = title
	_pause_confirm_dialog.dialog_text = text
	_pause_confirm_dialog.popup_centered()

func _vytvor_save_load_dialogy() -> void:
	_save_dialog = PopupPanel.new()
	_save_dialog.name = "SaveLoadDialog"
	_save_dialog.size = Vector2(560, 470)
	add_child(_save_dialog)
	_aplikuj_ingame_popup_styl(_save_dialog)

	# Keep compatibility for existing helpers that still reference _load_dialog.
	_load_dialog = _save_dialog

	var root_margin = MarginContainer.new()
	root_margin.offset_left = 12
	root_margin.offset_top = 12
	root_margin.offset_right = -12
	root_margin.offset_bottom = -12
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_dialog.add_child(root_margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(root_vbox)

	var title = Label.new()
	title.text = "Save / Load"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root_vbox.add_child(title)

	_load_slot_scroll = ScrollContainer.new()
	_load_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_load_slot_scroll)

	_load_slots_vbox = VBoxContainer.new()
	_load_slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_slots_vbox.add_theme_constant_override("separation", 4)
	_load_slot_scroll.add_child(_load_slots_vbox)

	var load_btns = HBoxContainer.new()
	load_btns.add_theme_constant_override("separation", 8)
	root_vbox.add_child(load_btns)

	_load_confirm_btn = Button.new()
	_load_confirm_btn.text = "Load"
	_load_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_confirm_btn.custom_minimum_size = Vector2(0, 44)
	_load_confirm_btn.pressed.connect(_on_load_dialog_confirm_pressed)
	load_btns.add_child(_load_confirm_btn)

	var load_refresh_btn = Button.new()
	load_refresh_btn.text = "Refresh"
	load_refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_refresh_btn.custom_minimum_size = Vector2(0, 44)
	load_refresh_btn.pressed.connect(_obnov_load_sloty)
	load_btns.add_child(load_refresh_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(func(): _save_dialog.hide())
	load_btns.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(save_row)

	_save_name_input = LineEdit.new()
	_save_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_name_input.placeholder_text = "e.g. france_turn12"
	_save_name_input.text_submitted.connect(func(_t): _on_save_dialog_confirm_pressed())
	save_row.add_child(_save_name_input)

	var save_confirm_btn = Button.new()
	save_confirm_btn.text = "Save"
	save_confirm_btn.custom_minimum_size = Vector2(0, 44)
	save_confirm_btn.pressed.connect(_on_save_dialog_confirm_pressed)
	save_row.add_child(save_confirm_btn)

	_save_dialog.hide()

func _vytvor_settings_dialog() -> void:
	_settings_dialog = PopupPanel.new()
	_settings_dialog.name = "SettingsDialog"
	_settings_dialog.wrap_controls = false
	_settings_dialog.unresizable = true
	_settings_dialog.min_size = Vector2i(620, 560)
	_settings_dialog.size = Vector2i(620, 560)
	add_child(_settings_dialog)
	_aplikuj_ingame_popup_styl(_settings_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	var tab_switcher = HBoxContainer.new()
	tab_switcher.add_theme_constant_override("separation", 6)
	root.add_child(tab_switcher)

	_settings_tab_controls_btn = Button.new()
	_settings_tab_controls_btn.text = "Controls"
	_settings_tab_controls_btn.custom_minimum_size = Vector2(130, 34)
	tab_switcher.add_child(_settings_tab_controls_btn)

	_settings_tab_settings_btn = Button.new()
	_settings_tab_settings_btn.text = "Settings"
	_settings_tab_settings_btn.custom_minimum_size = Vector2(130, 34)
	tab_switcher.add_child(_settings_tab_settings_btn)

	var tab_spacer = Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_switcher.add_child(tab_spacer)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.2, 0.88)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.45, 0.6, 0.79, 0.68)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6

	_settings_controls_panel = PanelContainer.new()
	_settings_controls_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_controls_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_settings_controls_panel)

	_settings_options_panel = PanelContainer.new()
	_settings_options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_options_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_settings_options_panel)

	var controls_margin = MarginContainer.new()
	controls_margin.offset_left = 12
	controls_margin.offset_top = 10
	controls_margin.offset_right = -12
	controls_margin.offset_bottom = -10
	controls_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_controls_panel.add_child(controls_margin)

	var controls_content = VBoxContainer.new()
	controls_content.add_theme_constant_override("separation", 8)
	controls_margin.add_child(controls_content)

	var controls_title = Label.new()
	controls_title.text = "Control Scheme"
	controls_title.add_theme_font_size_override("font_size", 17)
	controls_content.add_child(controls_title)

	var controls_info = RichTextLabel.new()
	controls_info.fit_content = false
	controls_info.scroll_active = false
	controls_info.bbcode_enabled = true
	controls_info.custom_minimum_size = Vector2(0, 130)
	controls_info.text = "- WASD / Arrows: move camera\n- Mouse wheel: zoom\n- Right mouse hold + drag: pan map\n- Space: end turn\n- Right click: cancel action / close dialogs\n- C: developer quick conquer tool"
	controls_content.add_child(controls_info)

	controls_content.add_child(HSeparator.new())

	var map_modes_title = Label.new()
	map_modes_title.text = "Map Modes"
	map_modes_title.add_theme_font_size_override("font_size", 16)
	controls_content.add_child(map_modes_title)

	var hotkeys_grid = GridContainer.new()
	hotkeys_grid.columns = 2
	hotkeys_grid.add_theme_constant_override("h_separation", 16)
	hotkeys_grid.add_theme_constant_override("v_separation", 4)
	controls_content.add_child(hotkeys_grid)

	var mode_rows := [
		"1 - Political", "2 - Population",
		"3 - GDP", "4 - Ideology",
		"5 - Recruitable Pop.", "6 - Relationships",
		"7 - Terrain", "8 - Resources"
	]
	for row_text in mode_rows:
		var row_label = Label.new()
		row_label.text = row_text
		hotkeys_grid.add_child(row_label)

	var settings_margin = MarginContainer.new()
	settings_margin.offset_left = 12
	settings_margin.offset_top = 10
	settings_margin.offset_right = -12
	settings_margin.offset_bottom = -10
	settings_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_options_panel.add_child(settings_margin)

	var settings_content = VBoxContainer.new()
	settings_content.add_theme_constant_override("separation", 7)
	settings_margin.add_child(settings_content)

	var display_title = Label.new()
	display_title.text = "Display"
	display_title.add_theme_font_size_override("font_size", 16)
	settings_content.add_child(display_title)

	_settings_fullscreen_check = CheckBox.new()
	_settings_fullscreen_check.text = "Fullscreen"
	settings_content.add_child(_settings_fullscreen_check)

	_settings_vsync_check = CheckBox.new()
	_settings_vsync_check.text = "VSync"
	settings_content.add_child(_settings_vsync_check)

	settings_content.add_child(HSeparator.new())

	var audio_title = Label.new()
	audio_title.text = "Audio"
	audio_title.add_theme_font_size_override("font_size", 16)
	settings_content.add_child(audio_title)

	var volume_label = Label.new()
	volume_label.text = "Master volume"
	settings_content.add_child(volume_label)

	var volume_row = HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 8)
	settings_content.add_child(volume_row)

	_settings_volume_slider = HSlider.new()
	_settings_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_volume_slider.min_value = 0.0
	_settings_volume_slider.max_value = 1.0
	_settings_volume_slider.step = 0.01
	_settings_volume_slider.value_changed.connect(_on_ingame_volume_changed)
	volume_row.add_child(_settings_volume_slider)

	_settings_volume_value = Label.new()
	_settings_volume_value.custom_minimum_size = Vector2(64, 0)
	_settings_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(_settings_volume_value)

	settings_content.add_child(HSeparator.new())

	var controls_settings_title = Label.new()
	controls_settings_title.text = "Controls"
	controls_settings_title.add_theme_font_size_override("font_size", 16)
	settings_content.add_child(controls_settings_title)

	var camera_label = Label.new()
	camera_label.text = "Camera move speed"
	settings_content.add_child(camera_label)

	var camera_row = HBoxContainer.new()
	camera_row.add_theme_constant_override("separation", 8)
	settings_content.add_child(camera_row)

	_settings_camera_slider = HSlider.new()
	_settings_camera_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_camera_slider.min_value = 400.0
	_settings_camera_slider.max_value = 2600.0
	_settings_camera_slider.step = 25.0
	_settings_camera_slider.value_changed.connect(_on_ingame_camera_speed_changed)
	camera_row.add_child(_settings_camera_slider)

	_settings_camera_value = Label.new()
	_settings_camera_value.custom_minimum_size = Vector2(64, 0)
	_settings_camera_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	camera_row.add_child(_settings_camera_value)

	var zoom_label = Label.new()
	zoom_label.text = "Zoom speed"
	settings_content.add_child(zoom_label)

	var zoom_row = HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	settings_content.add_child(zoom_row)

	_settings_zoom_slider = HSlider.new()
	_settings_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_zoom_slider.min_value = 0.03
	_settings_zoom_slider.max_value = 0.35
	_settings_zoom_slider.step = 0.01
	_settings_zoom_slider.value_changed.connect(_on_ingame_zoom_speed_changed)
	zoom_row.add_child(_settings_zoom_slider)

	_settings_zoom_value = Label.new()
	_settings_zoom_value.custom_minimum_size = Vector2(64, 0)
	_settings_zoom_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_row.add_child(_settings_zoom_value)

	_settings_invert_zoom_check = CheckBox.new()
	_settings_invert_zoom_check.text = "Invert mouse wheel zoom"
	settings_content.add_child(_settings_invert_zoom_check)

	_settings_tab_controls_btn.pressed.connect(func(): _show_ingame_settings_tab(0))
	_settings_tab_settings_btn.pressed.connect(func(): _show_ingame_settings_tab(1))
	_show_ingame_settings_tab(1)

	root.add_child(HSeparator.new())

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.pressed.connect(_on_ingame_settings_apply_pressed)
	buttons.add_child(apply_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): _settings_dialog.hide())
	buttons.add_child(close_btn)

	_settings_dialog.hide()

func _show_ingame_settings_tab(tab_index: int) -> void:
	if _settings_controls_panel == null or _settings_options_panel == null:
		return

	if tab_index == 0:
		_settings_controls_panel.show()
		_settings_options_panel.hide()
		if _settings_tab_controls_btn:
			_settings_tab_controls_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if _settings_tab_settings_btn:
			_settings_tab_settings_btn.modulate = Color(0.72, 0.8, 0.9, 1.0)
	else:
		_settings_controls_panel.hide()
		_settings_options_panel.show()
		if _settings_tab_controls_btn:
			_settings_tab_controls_btn.modulate = Color(0.72, 0.8, 0.9, 1.0)
		if _settings_tab_settings_btn:
			_settings_tab_settings_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _pozicuj_settings_dialog() -> void:
	if _settings_dialog:
		var vp = get_viewport().get_visible_rect().size
		_settings_dialog.position = Vector2((vp.x - _settings_dialog.size.x) * 0.5, (vp.y - _settings_dialog.size.y) * 0.5)

func _pozicuj_save_load_popupy() -> void:
	if _save_dialog:
		var vp = get_viewport().get_visible_rect().size
		_save_dialog.position = Vector2((vp.x - _save_dialog.size.x) * 0.5, (vp.y - _save_dialog.size.y) * 0.5)

func _ziskej_map_kameru() -> Node:
	var map_cam = get_tree().current_scene.find_child("Camera2D", true, false)
	if map_cam != null and map_cam.has_method("_nacti_ovladani_ze_settings"):
		return map_cam
	return null

func _nacti_settings_do_ingame_ui() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		_settings_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_settings_vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		_settings_volume_slider.value = 1.0
		_settings_camera_slider.value = 1000.0
		_settings_zoom_slider.value = 0.1
		_settings_invert_zoom_check.button_pressed = false
	else:
		_settings_fullscreen_check.button_pressed = bool(cfg.get_value("display", "fullscreen", false))
		_settings_vsync_check.button_pressed = bool(cfg.get_value("display", "vsync", true))
		_settings_volume_slider.value = clamp(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
		_settings_camera_slider.value = float(cfg.get_value("controls", "camera_speed", 1000.0))
		_settings_zoom_slider.value = clamp(float(cfg.get_value("controls", "zoom_speed", 0.1)), 0.03, 0.35)
		_settings_invert_zoom_check.button_pressed = bool(cfg.get_value("controls", "invert_zoom", false))

	_on_ingame_volume_changed(_settings_volume_slider.value)
	_on_ingame_camera_speed_changed(_settings_camera_slider.value)
	_on_ingame_zoom_speed_changed(_settings_zoom_slider.value)

func _uloz_a_aplikuj_ingame_settings() -> void:
	var fullscreen = _settings_fullscreen_check.button_pressed
	var vsync_enabled = _settings_vsync_check.button_pressed
	var master_volume = float(_settings_volume_slider.value)
	var camera_speed = float(_settings_camera_slider.value)
	var zoom_speed = float(_settings_zoom_slider.value)
	var invert_zoom = _settings_invert_zoom_check.button_pressed

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx == -1:
		master_bus_idx = 0
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(clamp(master_volume, 0.0001, 1.0)))

	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_FILE_PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "camera_speed", camera_speed)
	cfg.set_value("controls", "zoom_speed", zoom_speed)
	cfg.set_value("controls", "invert_zoom", invert_zoom)
	var save_err = cfg.save(SETTINGS_FILE_PATH)
	if save_err != OK:
		push_warning("Failed to save in-game settings. Error: %s" % str(save_err))

	var map_cam = _ziskej_map_kameru()
	if map_cam:
		map_cam.speed = camera_speed
		map_cam.zoom_speed = zoom_speed
		map_cam.invert_zoom_wheel = invert_zoom

func _on_ingame_volume_changed(value: float) -> void:
	if _settings_volume_value:
		_settings_volume_value.text = "%d%%" % int(round(value * 100.0))

func _on_ingame_camera_speed_changed(value: float) -> void:
	if _settings_camera_value:
		_settings_camera_value.text = "%d" % int(round(value))

func _on_ingame_zoom_speed_changed(value: float) -> void:
	if _settings_zoom_value:
		_settings_zoom_value.text = "%.2f" % value

func _on_ingame_settings_apply_pressed() -> void:
	_uloz_a_aplikuj_ingame_settings()
	_settings_dialog.hide()

func _vygeneruj_default_jmeno_save() -> String:
	return "save_%s" % Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")

func _obnov_load_sloty() -> void:
	if _load_slots_vbox == null:
		return

	for ch in _load_slots_vbox.get_children():
		ch.queue_free()
	_load_slot_row_buttons.clear()
	_load_slot_names.clear()
	_load_selected_slot_name = ""
	var sloty: Array = []
	if GameManager and GameManager.has_method("ziskej_save_sloty"):
		sloty = GameManager.ziskej_save_sloty()

	for s in sloty:
		var d = s as Dictionary
		var slot_name = str(d.get("name", ""))
		if slot_name == "":
			continue
		_load_slot_names.append(slot_name)
		_pridej_radek_load_slotu(slot_name, slot_name)

	if _load_slot_names.is_empty() and FileAccess.file_exists("user://savegame.dat"):
		_load_slot_names.append("__legacy__")
		_pridej_radek_load_slotu("__legacy__", "quicksave (legacy)")

	if not _load_slot_names.is_empty():
		_nastav_vybrany_load_slot(str(_load_slot_names[0]))
	if _load_confirm_btn:
		_load_confirm_btn.disabled = _load_slot_names.is_empty()

func _pridej_radek_load_slotu(slot_name: String, display_name: String) -> void:
	if _load_slots_vbox == null:
		return

	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	_load_slots_vbox.add_child(row)

	var select_btn = Button.new()
	select_btn.text = display_name
	select_btn.toggle_mode = true
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_btn.focus_mode = Control.FOCUS_NONE
	select_btn.pressed.connect(_on_load_slot_row_pressed.bind(slot_name))
	row.add_child(select_btn)
	_load_slot_row_buttons[slot_name] = select_btn

	var delete_btn = Button.new()
	delete_btn.text = "🗑"
	delete_btn.custom_minimum_size = Vector2(34, 0)
	delete_btn.focus_mode = Control.FOCUS_NONE
	delete_btn.tooltip_text = "Delete save slot"
	delete_btn.add_theme_font_size_override("font_size", 18)
	delete_btn.pressed.connect(_on_load_slot_row_delete_pressed.bind(slot_name))
	row.add_child(delete_btn)

func _nastav_vybrany_load_slot(slot_name: String) -> void:
	_load_selected_slot_name = slot_name
	for key_any in _load_slot_row_buttons.keys():
		var key = str(key_any)
		var btn = _load_slot_row_buttons[key_any] as Button
		if btn:
			btn.button_pressed = (key == _load_selected_slot_name)
	if _load_confirm_btn:
		_load_confirm_btn.disabled = _load_selected_slot_name == ""

func _on_load_slot_row_pressed(slot_name: String) -> void:
	_nastav_vybrany_load_slot(slot_name)

func _on_load_slot_row_delete_pressed(slot_name: String) -> void:
	await _smaz_load_slot(slot_name)

func _on_load_slot_selected(_index: int) -> void:
	# Deprecated path (ItemList was replaced by custom row list).
	pass

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
		await zobraz_systemove_hlaseni("Save", "Game was saved to slot: %s" % slot_name)
	else:
		await zobraz_systemove_hlaseni("Save", "Save failed.")

func _on_load_dialog_confirm_pressed() -> void:
	if _load_selected_slot_name == "":
		return
	var slot_name = _load_selected_slot_name
	var ok = false
	if slot_name == "__legacy__" and GameManager and GameManager.has_method("nacti_hru"):
		ok = bool(GameManager.nacti_hru())
	elif GameManager and GameManager.has_method("nacti_hru_ze_slotu"):
		ok = bool(GameManager.nacti_hru_ze_slotu(slot_name))
	elif GameManager and GameManager.has_method("nacti_hru"):
		ok = bool(GameManager.nacti_hru())

	if ok:
		_zavri_vyzkum_dialog()
		_load_dialog.hide()
		await zobraz_systemove_hlaseni("Load", "Game was loaded from slot: %s" % slot_name)
	else:
		await zobraz_systemove_hlaseni("Load", "Load failed.")

func _smaz_load_slot(slot_name: String) -> void:
	var ok = false
	if slot_name == "__legacy__" and GameManager and GameManager.has_method("smaz_legacy_save"):
		ok = bool(GameManager.smaz_legacy_save())
	elif GameManager and GameManager.has_method("smaz_save_slot"):
		ok = bool(GameManager.smaz_save_slot(slot_name))

	if ok:
		_obnov_load_sloty()
		await zobraz_systemove_hlaseni("Load", "Save slot deleted: %s" % slot_name)
	else:
		await zobraz_systemove_hlaseni("Load", "Failed to delete save slot.")

func _on_pause_resume_pressed() -> void:
	_zavri_pause_menu()

func _on_pause_options_pressed() -> void:
	_zavri_pause_menu()
	_nacti_settings_do_ingame_ui()
	_show_ingame_settings_tab(1)
	if _settings_dialog:
		_settings_dialog.size = _settings_dialog.min_size
		_settings_dialog.popup_centered(_settings_dialog.min_size)

func _on_pause_surrender_pressed() -> void:
	_zobraz_pause_confirm("surrender", "Surrender", "Do you really want to surrender as the current country?")

func _on_pause_save_pressed() -> void:
	_zavri_pause_menu()
	_obnov_load_sloty()
	if _save_name_input:
		_save_name_input.text = _vygeneruj_default_jmeno_save()
	if _save_dialog:
		_pozicuj_save_load_popupy()
		_save_dialog.popup()
		if _save_name_input:
			_save_name_input.grab_focus()
			_save_name_input.select_all()

func _on_pause_load_pressed() -> void:
	_on_pause_save_pressed()

func _on_pause_quit_pressed() -> void:
	_zobraz_pause_confirm("quit", "Quit", "Do you really want to return to the main menu?")

func _on_pause_confirm_visibility_changed() -> void:
	if not _pause_confirm_dialog or _pause_confirm_dialog.visible:
		return
	var should_restore_pause := not _pause_confirm_accepted and (_pause_pending_action == "quit" or _pause_pending_action == "surrender")
	_pause_pending_action = ""
	_pause_confirm_accepted = false
	if should_restore_pause and _pause_menu_panel:
		_pozicuj_pause_menu()
		_pause_menu_panel.call_deferred("show")

func _on_pause_confirmed() -> void:
	_pause_confirm_accepted = true
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
				await zobraz_systemove_hlaseni("Surrender", "You surrendered. Returning to main menu.")
				get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
				return
			await zobraz_systemove_hlaseni("Surrender", "Country %s capitulated." % current_tag)
		else:
			await zobraz_systemove_hlaseni("Surrender", "Surrender failed.")
		return

	if action == "quit":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _topbar_bottom_y() -> float:
	var topbar = get_tree().current_scene.find_child("TopBar", true, false)
	if topbar and topbar is CanvasLayer:
		var top_panel = topbar.find_child("Panel", true, false)
		if top_panel and top_panel is Control:
			return (top_panel as Control).global_position.y + (top_panel as Control).size.y
	return 35.0

func _aktualizuj_pozice_popupu():
	var viewport_size = get_viewport().get_visible_rect().size
	var top_y = _topbar_bottom_y() + POPUP_TOP_MARGIN
	_pozicuj_tlacitko_zprav()

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
		_rozmistit_vizual_fronty_diplomacii()
		if _queue_preview_panel:
			var rows = max(1, _queue_preview_rows)
			var panel_h = clamp(56.0 + float(rows) * 36.0, 160.0, 520.0)
			var panel_w = req_w
			_queue_preview_panel.position = Vector2((viewport_size.x - panel_w) * 0.5, top_y + req_h + 6.0)
			_queue_preview_panel.size = Vector2(panel_w, panel_h)
	if _zpravy_panel:
		var zpravy_anchor = _ziskej_rect_anchoru_zprav()
		if zpravy_anchor.size == Vector2.ZERO:
			return
		var zpravy_w = clamp(viewport_size.x * 0.30, 360.0, 540.0)
		var zpravy_h = clamp(viewport_size.y * 0.34, 180.0, 380.0)
		var x = clampf(zpravy_anchor.position.x + zpravy_anchor.size.x - zpravy_w, 10.0, viewport_size.x - zpravy_w - 10.0)
		var y = zpravy_anchor.position.y + zpravy_anchor.size.y + 6.0
		if diplomacy_request_popup and diplomacy_request_popup.visible:
			var zpravy_rect = Rect2(Vector2(x, y), Vector2(zpravy_w, zpravy_h))
			var dip_rect = Rect2(diplomacy_request_popup.position, diplomacy_request_popup.size)
			if zpravy_rect.intersects(dip_rect):
				y = dip_rect.position.y + dip_rect.size.y + POPUP_GAP
				if _queue_preview_panel and _queue_preview_panel.visible:
					y = _queue_preview_panel.position.y + _queue_preview_panel.size.y + POPUP_GAP
		_zpravy_panel.position = Vector2(x, y)
		_zpravy_panel.size = Vector2(zpravy_w, zpravy_h)

	if _peace_notice_panel and _peace_notice_panel.visible:
		_pozicuj_hlaseni_mirove_konference()
		if _zpravy_panel and _zpravy_panel.visible:
			var zpravy_rect2 = Rect2(_zpravy_panel.position, _zpravy_panel.size)
			var peace_rect = Rect2(_peace_notice_panel.position, _peace_notice_panel.size)
			if zpravy_rect2.intersects(peace_rect):
				var new_y = peace_rect.position.y + peace_rect.size.y + POPUP_GAP
				new_y = clampf(new_y, 8.0, maxf(8.0, viewport_size.y - _zpravy_panel.size.y - 8.0))
				_zpravy_panel.position = Vector2(_zpravy_panel.position.x, new_y)

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
		if _queue_preview_panel and _queue_preview_panel.visible:
			msg_y += _queue_preview_panel.size.y + POPUP_GAP
		if _peace_notice_panel and _peace_notice_panel.visible:
			msg_y += _peace_notice_panel.size.y + POPUP_GAP
		if _zpravy_panel and _zpravy_panel.visible:
			msg_y += _zpravy_panel.size.y + POPUP_GAP
		var max_msg_h = max(110.0, viewport_size.y - msg_y - 12.0)
		var msg_h = clamp(96.0 + float(approx_lines) * 18.0, 110.0, max_msg_h)
		msg_y = clamp(msg_y, top_y, max(top_y, viewport_size.y - msg_h - 8.0))
		system_message_popup.position = Vector2((viewport_size.x - msg_w) * 0.5, msg_y)
		system_message_popup.size = Vector2(msg_w, msg_h)
		if system_message_text:
			var text_area_h = max(42.0, msg_h - 68.0)
			system_message_text.custom_minimum_size = Vector2(0.0, text_area_h)

func zobraz_systemove_hlaseni(titulek: String, text: String) -> void:
	if not system_message_popup:
		return
	if system_message_title:
		system_message_title.text = titulek if titulek.strip_edges() != "" else "Report"
	if system_message_text:
		system_message_text.text = text

	_system_message_ack = false
	_aktualizuj_pozice_popupu()
	system_message_popup.show()
	if bool(GameManager.zpracovava_se_tah):
		# Never block turn resolution on message acknowledgement.
		_on_system_message_ok_pressed()
		return
	var wait_start_ms = Time.get_ticks_msec()

	while is_instance_valid(system_message_popup) and system_message_popup.visible and not _system_message_ack:
		if bool(GameManager.zpracovava_se_tah):
			var elapsed_ms = Time.get_ticks_msec() - wait_start_ms
			if elapsed_ms >= SYSTEM_MESSAGE_TURN_AUTO_ACK_MS:
				print("[UI] Auto-closing system message during turn processing timeout.")
				_on_system_message_ok_pressed()
				break
		await get_tree().process_frame

func _napln_aliance_option():
	if not alliance_level_option:
		return
	alliance_level_option.clear()
	alliance_level_option.add_item("[ ] No alliance", 0)
	alliance_level_option.add_item("[D] Defensive (ally defense)", 1)
	alliance_level_option.add_item("[O] Offensive (joint attack)", 2)
	alliance_level_option.add_item("[F] Full (defense + attack)", 3)

func _aktualizuj_zadost_ui(_target_tag: String):
	_current_incoming_request = {}
	if incoming_request_label:
		incoming_request_label.hide()
	if respond_request_buttons:
		respond_request_buttons.hide()

func _aktualizuj_popup_diplomatickych_zadosti():
	_popup_request_from_tag = ""
	if not diplomacy_request_popup:
		return
	if not GameManager.has_method("ziskej_cekajici_diplomaticke_zadosti"):
		diplomacy_request_popup.hide()
		_aktualizuj_vizual_fronty_diplomacii(0)
		_aktualizuj_text_rozbaleni_fronty(0)
		_aktualizuj_panel_rozbalene_fronty([])
		return

	var queue = GameManager.ziskej_cekajici_diplomaticke_zadosti(GameManager.hrac_stat)
	if queue.is_empty():
		diplomacy_request_popup.hide()
		_aktualizuj_vizual_fronty_diplomacii(0)
		_aktualizuj_text_rozbaleni_fronty(0)
		_aktualizuj_panel_rozbalene_fronty([])
		return

	var first_req = queue[0] as Dictionary
	var from_tag = str(first_req.get("from", "")).strip_edges().to_upper()
	if from_tag == "":
		diplomacy_request_popup.hide()
		_aktualizuj_vizual_fronty_diplomacii(0)
		_aktualizuj_text_rozbaleni_fronty(0)
		_aktualizuj_panel_rozbalene_fronty([])
		return
	_popup_request_from_tag = from_tag
	var pending_count := queue.size()
	_aktualizuj_text_rozbaleni_fronty(pending_count)

	if popup_request_flag:
		popup_request_flag.texture = _resolve_flag_texture(from_tag, "")
	if popup_request_text:
		popup_request_text.text = "Diplomacy (%d)" % pending_count

	if popup_accept_btn:
		popup_accept_btn.text = "Accept all"
	if popup_decline_btn:
		popup_decline_btn.text = "Decline all"

	diplomacy_request_popup.show()
	_aktualizuj_vizual_fronty_diplomacii(pending_count)
	_aktualizuj_panel_rozbalene_fronty(queue)
	_aktualizuj_panel_zprav()
	_aktualizuj_pozice_popupu()

func _zajisti_rozbaleni_fronty_popupu() -> void:
	if diplomacy_request_popup == null:
		return
	var hbox = get_node_or_null("DiplomacyRequestPopup/HBoxContainer") as HBoxContainer
	if hbox:
		if popup_request_text:
			popup_request_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if popup_accept_btn:
			popup_accept_btn.custom_minimum_size = Vector2(104, 0)
		if popup_decline_btn:
			popup_decline_btn.custom_minimum_size = Vector2(110, 0)
		if _queue_preview_toggle_btn == null:
			_queue_preview_toggle_btn = Button.new()
			_queue_preview_toggle_btn.name = "QueuePreviewToggleButton"
			_queue_preview_toggle_btn.text = "Queue"
			_queue_preview_toggle_btn.toggle_mode = true
			_queue_preview_toggle_btn.focus_mode = Control.FOCUS_NONE
			_queue_preview_toggle_btn.custom_minimum_size = Vector2(88, 0)
			_queue_preview_toggle_btn.tooltip_text = "Expand/hide preview of pending offers."
			_queue_preview_toggle_btn.pressed.connect(_on_queue_preview_toggle_pressed)
			hbox.add_child(_queue_preview_toggle_btn)
			hbox.move_child(_queue_preview_toggle_btn, max(0, hbox.get_child_count() - 1))

	if _queue_preview_panel == null:
		_queue_preview_panel = Panel.new()
		_queue_preview_panel.name = "DiplomacyQueueExpandedPanel"
		_queue_preview_panel.visible = false
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.13, 0.96)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.45, 0.65, 0.9, 0.60)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		_queue_preview_panel.add_theme_stylebox_override("panel", style)
		add_child(_queue_preview_panel)

		_queue_preview_scroll = ScrollContainer.new()
		_queue_preview_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_queue_preview_scroll.offset_left = 6.0
		_queue_preview_scroll.offset_top = 4.0
		_queue_preview_scroll.offset_right = -6.0
		_queue_preview_scroll.offset_bottom = -4.0
		_queue_preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_queue_preview_panel.add_child(_queue_preview_scroll)

		_queue_preview_list = VBoxContainer.new()
		_queue_preview_list.name = "QueueRows"
		_queue_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_queue_preview_list.add_theme_constant_override("separation", 8)
		_queue_preview_scroll.add_child(_queue_preview_list)

func _zajisti_panel_zprav() -> void:
	if diplomacy_request_popup == null:
		return

	if _zpravy_toggle_btn == null:
		_zpravy_toggle_btn = Button.new()
		_zpravy_toggle_btn.name = "ZpravyToggleButton"
		_zpravy_toggle_btn.toggle_mode = true
		_zpravy_toggle_btn.focus_mode = Control.FOCUS_NONE
		_zpravy_toggle_btn.custom_minimum_size = Vector2(120, 30)
		_zpravy_toggle_btn.text = "Messages"
		_zpravy_toggle_btn.tooltip_text = "Expand messages center (my country / global)."
		_zpravy_toggle_btn.pressed.connect(_on_zpravy_toggle_pressed)
		add_child(_zpravy_toggle_btn)

	if _zpravy_panel == null:
		_zpravy_panel = Panel.new()
		_zpravy_panel.name = "ZpravyPanel"
		_zpravy_panel.visible = false
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.42, 0.64, 0.9, 0.58)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		_zpravy_panel.add_theme_stylebox_override("panel", style)
		add_child(_zpravy_panel)

		var content_box = VBoxContainer.new()
		content_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_box.offset_left = 8
		content_box.offset_top = 6
		content_box.offset_right = -8
		content_box.offset_bottom = -6
		content_box.add_theme_constant_override("separation", 6)
		_zpravy_panel.add_child(content_box)

		var top = HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		content_box.add_child(top)

		_zpravy_title_label = Label.new()
		_zpravy_title_label.text = "Messages"
		_zpravy_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_zpravy_title_label)

		var mode_tabs = HBoxContainer.new()
		mode_tabs.add_theme_constant_override("separation", 4)
		top.add_child(mode_tabs)

		_zpravy_mode_local_btn = Button.new()
		_zpravy_mode_local_btn.text = "My country"
		_zpravy_mode_local_btn.toggle_mode = true
		_zpravy_mode_local_btn.button_pressed = true
		_zpravy_mode_local_btn.focus_mode = Control.FOCUS_NONE
		_zpravy_mode_local_btn.pressed.connect(_on_zpravy_mode_local_pressed)
		mode_tabs.add_child(_zpravy_mode_local_btn)

		_zpravy_mode_global_btn = Button.new()
		_zpravy_mode_global_btn.text = "Global"
		_zpravy_mode_global_btn.toggle_mode = true
		_zpravy_mode_global_btn.focus_mode = Control.FOCUS_NONE
		_zpravy_mode_global_btn.pressed.connect(_on_zpravy_mode_global_pressed)
		mode_tabs.add_child(_zpravy_mode_global_btn)

		_zpravy_historie_checkbox = CheckBox.new()
		_zpravy_historie_checkbox.focus_mode = Control.FOCUS_NONE
		_zpravy_historie_checkbox.text = "History"
		_zpravy_historie_checkbox.tooltip_text = "Show messages from previous turns."
		_zpravy_historie_checkbox.toggled.connect(_on_zpravy_historie_toggled)
		top.add_child(_zpravy_historie_checkbox)

		_zpravy_scroll = ScrollContainer.new()
		_zpravy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_zpravy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content_box.add_child(_zpravy_scroll)

		_zpravy_groups_list = VBoxContainer.new()
		_zpravy_groups_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_zpravy_groups_list.add_theme_constant_override("separation", 6)
		_zpravy_scroll.add_child(_zpravy_groups_list)

func _ziskej_aktivni_zpravy() -> Array:
	if not GameManager:
		return []
	var out: Array = []
	if _zpravy_mode == 1:
		if GameManager.has_method("ziskej_globalni_zpravy"):
			out = GameManager.ziskej_globalni_zpravy(ZPRAVY_MAX_ITEMS)
			out = _odfiltruj_popup_kategorie(out)
		return out
	if GameManager.has_method("ziskej_relevantni_zpravy_statu"):
		out = GameManager.ziskej_relevantni_zpravy_statu(GameManager.hrac_stat, ZPRAVY_MAX_ITEMS, true)
		return _odfiltruj_popup_kategorie(out)
	if GameManager.has_method("ziskej_zpravy_hrace"):
		out = GameManager.ziskej_zpravy_hrace(GameManager.hrac_stat, ZPRAVY_MAX_ITEMS)
		var current_turn = int(GameManager.aktualni_kolo)
		var filtered: Array = []
		for entry in out:
			if int((entry as Dictionary).get("turn", -1)) == current_turn:
				filtered.append(entry)
		return filtered
	return out

func _ziskej_historicke_zpravy() -> Array:
	if not GameManager:
		return []
	var out: Array = []
	var current_turn = int(GameManager.aktualni_kolo)
	if _zpravy_mode == 1:
		if GameManager.has_method("ziskej_globalni_zpravy"):
			out = _odfiltruj_popup_kategorie(GameManager.ziskej_globalni_zpravy(ZPRAVY_HISTORY_MAX_ITEMS))
	else:
		if GameManager.has_method("ziskej_relevantni_zpravy_statu"):
			out = _odfiltruj_popup_kategorie(GameManager.ziskej_relevantni_zpravy_statu(GameManager.hrac_stat, ZPRAVY_HISTORY_MAX_ITEMS, false))
		elif GameManager.has_method("ziskej_zpravy_hrace"):
			out = _odfiltruj_popup_kategorie(GameManager.ziskej_zpravy_hrace(GameManager.hrac_stat, ZPRAVY_HISTORY_MAX_ITEMS))

	var hist: Array = []
	for entry in out:
		if int((entry as Dictionary).get("turn", -1)) < current_turn:
			hist.append(entry)
	return hist

func _odfiltruj_popup_kategorie(entries: Array) -> Array:
	var filtered: Array = []
	for entry in entries:
		var cat = str((entry as Dictionary).get("category", "")).to_lower()
		if cat == "popup":
			continue
		filtered.append(entry)
	return filtered

func _je_redundantni_titulek_zpravy(category_label: String, title: String) -> bool:
	var t = title.strip_edges().to_lower()
	if t == "":
		return true
	match category_label:
		"War":
			return t.findn("valk") != -1 or t.findn("war") != -1
		"Alliance":
			return t.findn("alianc") != -1 or t.findn("alliance") != -1
		"Treaties":
			return t.findn("smlouv") != -1 or t.findn("treaty") != -1 or t.findn("pakt") != -1
		"Relations":
			return t.findn("vztah") != -1 or t.findn("relation") != -1
		"Negotiations":
			return t.findn("diplom") != -1 or t.findn("negoti") != -1
		"Gifts":
			return t.findn("dar") != -1 or t.findn("gift") != -1
		_:
			return false

func _format_zprava(entry: Dictionary) -> String:
	var category = str(entry.get("category", "")).strip_edges().to_lower()
	var title = str(entry.get("title", "Info")).strip_edges()
	var text = str(entry.get("text", "")).strip_edges()
	if text == "":
		text = "(bez detailu)"
	var category_label = _normalizuj_kategorii_zpravy(category, title, text)
	var cat_tag = ""
	if category_label != "":
		cat_tag = "[%s] " % category_label

	if _je_redundantni_titulek_zpravy(category_label, title):
		return "%s%s" % [cat_tag, text]
	return "%s%s: %s" % [cat_tag, title, text]

func _normalizuj_kategorii_zpravy(category: String, title: String = "", text: String = "") -> String:
	var c = category.strip_edges().to_lower()
	match c:
		"war":
			return "War"
		"relations":
			return "Relations"
		"alliance":
			return "Alliance"
		"treaty", "treaties", "non_aggression":
			return "Treaties"
		"gift", "gifts":
			return "Gifts"
		"diplomacy":
			pass

	var body = (title + " " + text).to_lower()
	var war_tokens = ["valk", "war", "mir", "peace", "kapitul", "okup", "anex", "surrender"]
	for t in war_tokens:
		if body.findn(t) != -1:
			return "War"

	var alliance_tokens = ["alianc", "alliance", "spojenec"]
	for t in alliance_tokens:
		if body.findn(t) != -1:
			return "Alliance"

	var treaty_tokens = ["neagres", "smlouv", "pakt", "treaty", "truce"]
	for t in treaty_tokens:
		if body.findn(t) != -1:
			return "Treaties"

	var gift_tokens = ["dar", "gift", "usd", "finance", "financni"]
	for t in gift_tokens:
		if body.findn(t) != -1:
			return "Gifts"

	var relation_tokens = ["vztah", "relations"]
	for t in relation_tokens:
		if body.findn(t) != -1:
			return "Relations"

	if c == "diplomacy":
		return "Negotiations"
	return "Other"

func _sestav_skupiny_zprav(entries: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for item in entries:
		var entry = item as Dictionary
		var cat = _normalizuj_kategorii_zpravy(
			str(entry.get("category", "")),
			str(entry.get("title", "")),
			str(entry.get("text", ""))
		)
		if not grouped.has(cat):
			grouped[cat] = []
		(grouped[cat] as Array).append(entry)
	return grouped

func _format_zprava_radek(entry: Dictionary, historical: bool) -> String:
	var base = _format_zprava(entry)
	if historical:
		return "[Turn %d] %s" % [int(entry.get("turn", 0)), base]
	return base

func _vykresli_skupiny_zprav(current_entries: Array, history_entries: Array) -> void:
	if _zpravy_groups_list == null:
		return

	for child in _zpravy_groups_list.get_children():
		child.queue_free()

	if current_entries.is_empty() and history_entries.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(no messages)"
		_zpravy_groups_list.add_child(empty_lbl)
		return

	var grouped_current = _sestav_skupiny_zprav(current_entries)
	var grouped_history = _sestav_skupiny_zprav(history_entries)
	var order = ["War", "Alliance", "Treaties", "Negotiations", "Gifts", "Relations", "Other"]
	var rendered_any := false
	for cat in order:
		var current_cat_entries = grouped_current.get(cat, []) as Array
		var history_cat_entries = grouped_history.get(cat, []) as Array
		if current_cat_entries.is_empty() and history_cat_entries.is_empty():
			continue
		rendered_any = true

		if not _zpravy_category_expanded.has(cat):
			_zpravy_category_expanded[cat] = true

		var cat_entries: Array = []
		for e in current_cat_entries:
			var d = (e as Dictionary).duplicate(true)
			d["_historical"] = false
			cat_entries.append(d)
		for e in history_cat_entries:
			var d2 = (e as Dictionary).duplicate(true)
			d2["_historical"] = true
			cat_entries.append(d2)

		var section = VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		_zpravy_groups_list.add_child(section)

		var header_btn = Button.new()
		header_btn.toggle_mode = true
		header_btn.button_pressed = bool(_zpravy_category_expanded[cat])
		header_btn.focus_mode = Control.FOCUS_NONE
		header_btn.text = "%s (%d)" % [cat, cat_entries.size()]
		header_btn.pressed.connect(_on_zpravy_category_toggle_pressed.bind(cat))
		section.add_child(header_btn)

		if not bool(_zpravy_category_expanded[cat]):
			continue

		var body = VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 3)
		for i in range(cat_entries.size() - 1, -1, -1):
			var entry = cat_entries[i] as Dictionary
			var historical = bool(entry.get("_historical", false))
			var line = _format_zprava_radek(entry, historical)
			if line.strip_edges() == "":
				continue

			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 6)

			var flow = HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flow.add_theme_constant_override("h_separation", 3)
			flow.add_theme_constant_override("v_separation", 2)
			row.add_child(flow)

			var mentions = _najdi_zminky_statu_v_textu(line)
			if mentions.is_empty():
				var fallback_line = line
				if fallback_line == "":
					fallback_line = "-"
				flow.add_child(_vytvor_zprava_text_chunk(fallback_line))
			else:
				var cursor := 0
				for m_any in mentions:
					var m = m_any as Dictionary
					var start_idx = int(m.get("start", 0))
					var end_idx = int(m.get("end", start_idx))
					var tag = str(m.get("tag", "")).strip_edges().to_upper()
					if start_idx > cursor:
						var chunk = line.substr(cursor, start_idx - cursor)
						if chunk.strip_edges() != "":
							flow.add_child(_vytvor_zprava_text_chunk(chunk))
					var flag_btn = _vytvor_zprava_flag_btn(tag)
					if flag_btn:
						flow.add_child(flag_btn)
					else:
						var fallback = line.substr(start_idx, max(0, end_idx - start_idx))
						flow.add_child(_vytvor_zprava_text_chunk(fallback))
					cursor = max(cursor, end_idx)
				if cursor < line.length():
					var tail = line.substr(cursor, line.length() - cursor)
					if tail.strip_edges() != "":
						flow.add_child(_vytvor_zprava_text_chunk(tail))

			body.add_child(row)

		section.add_child(body)

	if not rendered_any:
		var empty_lbl2 = Label.new()
		empty_lbl2.text = "(no messages for current filter)"
		_zpravy_groups_list.add_child(empty_lbl2)

func _aktualizuj_tlacitko_zprav() -> void:
	if _zpravy_toggle_btn == null:
		return
	var count = _ziskej_aktivni_zpravy().size()
	_zpravy_toggle_btn.text = "Messages (%d)" % count
	_zpravy_toggle_btn.disabled = false
	if _zpravy_anchor_control and is_instance_valid(_zpravy_anchor_control) and _zpravy_anchor_control is Button:
		(_zpravy_anchor_control as Button).text = "Messages (%d)" % count

func _pozicuj_tlacitko_zprav() -> void:
	if _zpravy_toggle_btn == null:
		return
	if _zpravy_anchor_control and is_instance_valid(_zpravy_anchor_control):
		_zpravy_toggle_btn.hide()
		return
	_zpravy_toggle_btn.show()
	var viewport_size = get_viewport().get_visible_rect().size
	var y = _topbar_bottom_y() + 4.0
	var next_btn = get_tree().current_scene.find_child("NextTurnButton", true, false) as Control
	if next_btn:
		y = next_btn.global_position.y + next_btn.size.y + 4.0
	_zpravy_toggle_btn.position = Vector2(viewport_size.x - _zpravy_toggle_btn.size.x - 12.0, y)

func _ziskej_rect_anchoru_zprav() -> Rect2:
	if _zpravy_anchor_control and is_instance_valid(_zpravy_anchor_control) and _zpravy_anchor_control.is_visible_in_tree():
		return Rect2(_zpravy_anchor_control.global_position, _zpravy_anchor_control.size)
	if _zpravy_toggle_btn and is_instance_valid(_zpravy_toggle_btn) and _zpravy_toggle_btn.visible:
		return Rect2(_zpravy_toggle_btn.global_position, _zpravy_toggle_btn.size)
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func nastav_zpravy_anchor_control(control: Control) -> void:
	_zpravy_anchor_control = control
	_pozicuj_tlacitko_zprav()
	_aktualizuj_tlacitko_zprav()
	_aktualizuj_pozice_popupu()

func prepni_zpravy_panel() -> void:
	_on_zpravy_toggle_pressed()

func _vyhledat_tagy_statu_v_textu(text: String) -> Array:
	var tags: Array = []
	var seen: Dictionary = {}
	var rx = RegEx.new()
	if rx.compile("\\b[A-Z]{3}\\b") != OK:
		return tags
	for m in rx.search_all(text.to_upper()):
		var tag = str(m.get_string()).strip_edges().to_upper()
		if tag == "" or tag == "SEA" or seen.has(tag):
			continue
		var has_state = false
		if not GameManager.map_data.is_empty():
			for p_id in GameManager.map_data:
				var d = GameManager.map_data[p_id]
				if str(d.get("owner", "")).strip_edges().to_upper() == tag:
					has_state = true
					break
		if not has_state:
			continue
		seen[tag] = true
		tags.append(tag)
	return tags

func _vyhledat_tagy_statu_podle_nazvu(text: String) -> Array:
	var tags: Array = []
	var seen: Dictionary = {}
	if GameManager.map_data.is_empty():
		return tags

	var lower_text = text.to_lower()
	var states: Dictionary = {}
	for p_id in GameManager.map_data:
		var d = GameManager.map_data[p_id]
		var tag = str(d.get("owner", "")).strip_edges().to_upper()
		if tag == "" or states.has(tag):
			continue
		states[tag] = str(d.get("country_name", tag)).strip_edges()

	for tag_any in states.keys():
		var tag = str(tag_any)
		var country_name = str(states[tag]).strip_edges()
		if country_name == "":
			continue
		if lower_text.find(country_name.to_lower()) != -1 and not seen.has(tag):
			seen[tag] = true
			tags.append(tag)
	return tags

func _je_hranice_slova(text: String, idx: int) -> bool:
	if idx < 0 or idx >= text.length():
		return true
	var ch = text.substr(idx, 1)
	var word_chars = "abcdefghijklmnopqrstuvwxyz0123456789_"
	return word_chars.find(ch.to_lower()) == -1

func _najdi_zminky_statu_v_textu(text: String) -> Array:
	var mentions: Array = []
	var rx = RegEx.new()
	if rx.compile("\\b[A-Z]{3}\\b") == OK:
		for m in rx.search_all(text.to_upper()):
			var tag = str(m.get_string()).strip_edges().to_upper()
			if tag == "" or tag == "SEA":
				continue
			if _ziskej_jmeno_statu_podle_tagu(tag) == tag and GameManager.map_data.is_empty():
				continue
			mentions.append({
				"start": int(m.get_start()),
				"end": int(m.get_end()),
				"tag": tag
			})

	if not GameManager.map_data.is_empty():
		var lower_text = text.to_lower()
		var states: Dictionary = {}
		for p_id in GameManager.map_data:
			var d = GameManager.map_data[p_id]
			var tag = str(d.get("owner", "")).strip_edges().to_upper()
			if tag == "" or states.has(tag):
				continue
			states[tag] = str(d.get("country_name", tag)).strip_edges()

		for tag_any in states.keys():
			var tag = str(tag_any)
			var country_name = str(states[tag]).strip_edges()
			if country_name == "":
				continue
			var needle = country_name.to_lower()
			var from_idx = 0
			while true:
				var idx = lower_text.find(needle, from_idx)
				if idx == -1:
					break
				var end_idx = idx + needle.length()
				if _je_hranice_slova(lower_text, idx - 1) and _je_hranice_slova(lower_text, end_idx):
					mentions.append({"start": idx, "end": end_idx, "tag": tag})
				from_idx = idx + max(1, needle.length())

	mentions.sort_custom(func(a: Dictionary, b: Dictionary):
		var sa = int(a.get("start", 0))
		var sb = int(b.get("start", 0))
		if sa == sb:
			var la = int(a.get("end", 0)) - sa
			var lb = int(b.get("end", 0)) - sb
			return la > lb
		return sa < sb
	)

	var filtered: Array = []
	var cursor = -1
	for m_any in mentions:
		var m = m_any as Dictionary
		var s = int(m.get("start", 0))
		var e = int(m.get("end", s))
		if s < cursor:
			continue
		filtered.append(m)
		cursor = e

	return filtered

func _vytvor_zprava_text_chunk(text: String) -> Label:
	var lbl = Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	lbl.text = text
	return lbl

func _vytvor_zprava_flag_btn(tag: String):
	var clean_tag = tag.strip_edges().to_upper()
	if clean_tag == "":
		return null
	var flag_tex = _resolve_flag_texture(clean_tag, "")
	if flag_tex == null:
		return null
	var flag_btn = TextureButton.new()
	flag_btn.custom_minimum_size = Vector2(16, 11)
	flag_btn.size = Vector2(16, 11)
	flag_btn.ignore_texture_size = true
	flag_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	flag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flag_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	flag_btn.texture_normal = flag_tex
	flag_btn.texture_hover = flag_tex
	flag_btn.texture_pressed = flag_tex
	flag_btn.tooltip_text = "%s (%s)" % [_ziskej_jmeno_statu_podle_tagu(clean_tag), clean_tag]
	flag_btn.focus_mode = Control.FOCUS_NONE
	flag_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flag_btn.pressed.connect(_on_zprava_flag_pressed.bind(clean_tag))
	return flag_btn

func _ziskej_tagy_pro_zpravu(entry: Dictionary, fallback_line: String) -> Array:
	var tags: Array = []
	var seen: Dictionary = {}
	var raw = "%s %s" % [str(entry.get("title", "")), str(entry.get("text", ""))]
	for tag_any in _vyhledat_tagy_statu_v_textu(raw):
		var tag = str(tag_any)
		if not seen.has(tag):
			seen[tag] = true
			tags.append(tag)
	if tags.is_empty():
		for tag_any in _vyhledat_tagy_statu_v_textu(fallback_line):
			var tag2 = str(tag_any)
			if not seen.has(tag2):
				seen[tag2] = true
				tags.append(tag2)

	for tag_any in _vyhledat_tagy_statu_podle_nazvu(raw):
		var tag3 = str(tag_any)
		if not seen.has(tag3):
			seen[tag3] = true
			tags.append(tag3)

	if tags.is_empty():
		for tag_any in _vyhledat_tagy_statu_podle_nazvu(fallback_line):
			var tag4 = str(tag_any)
			if not seen.has(tag4):
				seen[tag4] = true
				tags.append(tag4)
	return tags

func _odeber_nazvy_statu_z_textu(text: String, tags: Array) -> String:
	var out = text
	for tag_any in tags:
		var tag = str(tag_any).strip_edges().to_upper()
		if tag == "":
			continue
		out = out.replace(tag, "")
		var country_name = _ziskej_jmeno_statu_podle_tagu(tag).strip_edges()
		if country_name != "":
			out = out.replace(country_name, "")
			out = out.replace(country_name.to_lower(), "")
			out = out.replace(country_name.to_upper(), "")
	out = out.replace("  ", " ")
	out = out.replace(" ,", ",")
	out = out.replace(" :", ":")
	out = out.replace(" ;", ";")
	return out

func _on_zprava_flag_pressed(state_tag: String) -> void:
	_otevri_prehled_statu_podle_tagu(state_tag)

func _aktualizuj_panel_zprav() -> void:
	_aktualizuj_tlacitko_zprav()
	if _zpravy_panel == null or _zpravy_groups_list == null:
		return
	if not _zpravy_expanded:
		_zpravy_panel.hide()
		return

	var arr = _ziskej_aktivni_zpravy()
	var hist_arr = _ziskej_historicke_zpravy()
	if _zpravy_title_label:
		if _zpravy_mode == 0 and GameManager:
			_zpravy_title_label.text = "Messages - turn %d" % int(GameManager.aktualni_kolo)
		else:
			_zpravy_title_label.text = "Messages - global"
	if _zpravy_historie_checkbox:
		_zpravy_historie_checkbox.disabled = hist_arr.is_empty()
		_zpravy_historie_checkbox.text = "History (%d)" % hist_arr.size()
		if hist_arr.is_empty():
			_zpravy_historie_expanded = false
			_zpravy_historie_checkbox.button_pressed = false

	var history_to_show: Array = hist_arr if _zpravy_historie_expanded else []
	_vykresli_skupiny_zprav(arr, history_to_show)
	_zpravy_panel.show()
	_aktualizuj_pozice_popupu()

func _on_zpravy_toggle_pressed() -> void:
	_zpravy_expanded = not _zpravy_expanded
	if _zpravy_toggle_btn:
		_zpravy_toggle_btn.button_pressed = _zpravy_expanded
	_aktualizuj_panel_zprav()

func _on_zpravy_mode_local_pressed() -> void:
	_zpravy_mode = 0
	if _zpravy_mode_local_btn:
		_zpravy_mode_local_btn.button_pressed = true
	if _zpravy_mode_global_btn:
		_zpravy_mode_global_btn.button_pressed = false
	_aktualizuj_panel_zprav()

func _on_zpravy_mode_global_pressed() -> void:
	_zpravy_mode = 1
	if _zpravy_mode_local_btn:
		_zpravy_mode_local_btn.button_pressed = false
	if _zpravy_mode_global_btn:
		_zpravy_mode_global_btn.button_pressed = true
	_aktualizuj_panel_zprav()

func _on_zpravy_category_toggle_pressed(category_name: String) -> void:
	var current = bool(_zpravy_category_expanded.get(category_name, true))
	_zpravy_category_expanded[category_name] = not current
	_aktualizuj_panel_zprav()

func _on_zpravy_historie_toggled(pressed: bool) -> void:
	_zpravy_historie_expanded = pressed
	if _zpravy_historie_checkbox:
		_zpravy_historie_checkbox.button_pressed = _zpravy_historie_expanded
	_aktualizuj_panel_zprav()

func _aktualizuj_text_rozbaleni_fronty(pending_count: int) -> void:
	if _queue_preview_toggle_btn == null:
		return
	if pending_count <= 0:
		_queue_preview_toggle_btn.text = "Queue"
		_queue_preview_toggle_btn.disabled = true
		_queue_preview_expanded = false
		_queue_preview_toggle_btn.button_pressed = false
		return
	_queue_preview_toggle_btn.text = "Queue (%d)" % pending_count
	_queue_preview_toggle_btn.disabled = false

func _formatuj_text_zadosti(req: Dictionary) -> String:
	var req_type = str(req.get("type", ""))
	if req_type == "alliance":
		match int(req.get("level", 0)):
			1:
				return "Defensive alliance"
			2:
				return "Offensive alliance"
			3:
				return "Full alliance"
		return "Alliance"
	if req_type == "peace":
		return "Peace proposal"
	if req_type == "non_aggression":
		return "Non-aggression pact (10 turns)"
	return "Diplomatic offer"

func _aktualizuj_panel_rozbalene_fronty(queue: Array) -> void:
	if _queue_preview_panel == null or _queue_preview_list == null:
		return
	if not diplomacy_request_popup or not diplomacy_request_popup.visible:
		_queue_preview_panel.hide()
		return

	if not _queue_preview_expanded:
		_queue_preview_panel.hide()
		return

	if queue.is_empty():
		_queue_preview_panel.hide()
		return

	for child in _queue_preview_list.get_children():
		child.queue_free()

	var limit = min(queue.size(), QUEUE_PREVIEW_MAX_ITEMS)
	for i in range(limit):
		var req = queue[i] as Dictionary
		var from_tag = str(req.get("from", "")).strip_edges().to_upper()
		var row = Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(_on_queue_row_focus_country_pressed.bind(from_tag))
		row.custom_minimum_size = Vector2(0, 40)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var row_content = HBoxContainer.new()
		row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_content.add_theme_constant_override("separation", 10)
		row.add_child(row_content)

		var flag_btn = TextureButton.new()
		flag_btn.custom_minimum_size = Vector2(30, 20)
		flag_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		flag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flag_btn.ignore_texture_size = true
		flag_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var flag_tex = _resolve_flag_texture(from_tag, "")
		if flag_tex:
			flag_btn.texture_normal = flag_tex
			flag_btn.texture_hover = flag_tex
			flag_btn.texture_pressed = flag_tex
		flag_btn.focus_mode = Control.FOCUS_NONE
		flag_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flag_btn.tooltip_text = "%s (%s)" % [_ziskej_jmeno_statu_podle_tagu(from_tag), from_tag]
		flag_btn.pressed.connect(_on_queue_row_focus_country_pressed.bind(from_tag))
		row_content.add_child(flag_btn)

		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(220, 0)
		label.clip_text = true
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text = "%d. %s | Offer: %s" % [i + 1, _ziskej_jmeno_statu_podle_tagu(from_tag), _formatuj_text_zadosti(req)]
		label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
		label.tooltip_text = "Click the flag to move camera to country %s." % from_tag
		row_content.add_child(label)

		var btn_accept = Button.new()
		btn_accept.text = "Accept"
		btn_accept.custom_minimum_size = Vector2(82, 0)
		btn_accept.focus_mode = Control.FOCUS_NONE
		btn_accept.pressed.connect(_on_queue_row_accept_pressed.bind(from_tag))
		row_content.add_child(btn_accept)

		var btn_decline = Button.new()
		btn_decline.text = "Decline"
		btn_decline.custom_minimum_size = Vector2(86, 0)
		btn_decline.focus_mode = Control.FOCUS_NONE
		btn_decline.pressed.connect(_on_queue_row_decline_pressed.bind(from_tag))
		row_content.add_child(btn_decline)

		_queue_preview_list.add_child(row)

	var remaining = queue.size() - limit
	if remaining > 0:
		var more_label = Label.new()
		more_label.text = "+%d more offers..." % remaining
		_queue_preview_list.add_child(more_label)

	_queue_preview_rows = max(1, min(queue.size(), QUEUE_PREVIEW_MAX_ITEMS) + (1 if remaining > 0 else 0))
	_queue_preview_panel.show()
	_aktualizuj_pozice_popupu()

func _on_queue_preview_toggle_pressed() -> void:
	_queue_preview_expanded = not _queue_preview_expanded
	if _queue_preview_toggle_btn:
		_queue_preview_toggle_btn.button_pressed = _queue_preview_expanded
	if not _queue_preview_expanded:
		if _queue_preview_panel:
			_queue_preview_panel.hide()
		_aktualizuj_pozice_popupu()
		return

	if GameManager.has_method("ziskej_cekajici_diplomaticke_zadosti"):
		_aktualizuj_panel_rozbalene_fronty(GameManager.ziskej_cekajici_diplomaticke_zadosti(GameManager.hrac_stat))

func _on_queue_row_accept_pressed(from_tag: String) -> void:
	if not GameManager.has_method("hrac_prijmi_diplomatickou_zadost"):
		return
	GameManager.hrac_prijmi_diplomatickou_zadost(GameManager.hrac_stat, from_tag)
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag == from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_queue_row_decline_pressed(from_tag: String) -> void:
	if not GameManager.has_method("hrac_odmitni_diplomatickou_zadost"):
		return
	GameManager.hrac_odmitni_diplomatickou_zadost(GameManager.hrac_stat, from_tag)
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag == from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_queue_row_focus_country_pressed(from_tag: String) -> void:
	_otevri_prehled_statu_podle_tagu(from_tag)

func _zajisti_vizual_fronty_diplomacii() -> void:
	if diplomacy_request_popup == null:
		return
	if not _diplomacy_queue_preview_cards.is_empty():
		return

	for i in range(3):
		var card = Panel.new()
		card.name = "DiplomacyQueuePreview_%d" % i
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.z_index = -10 + i
		card.show_behind_parent = true
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.18, 0.30)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.48, 0.72, 0.98, 0.32)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", style)
		diplomacy_request_popup.add_child(card)
		diplomacy_request_popup.move_child(card, 0)
		_diplomacy_queue_preview_cards.append(card)

func _rozmistit_vizual_fronty_diplomacii() -> void:
	if diplomacy_request_popup == null:
		return
	if _diplomacy_queue_preview_cards.is_empty():
		return

	var base_size = diplomacy_request_popup.size
	for i in range(_diplomacy_queue_preview_cards.size()):
		var card = _diplomacy_queue_preview_cards[i] as Panel
		if card == null:
			continue
		var depth = i + 1
		var inset_x = 8.0 * depth
		var offset_y = 7.0 * depth
		card.position = Vector2(inset_x, offset_y)
		card.size = Vector2(max(220.0, base_size.x - inset_x * 2.0), base_size.y)

func _aktualizuj_vizual_fronty_diplomacii(pending_count: int) -> void:
	if _diplomacy_queue_preview_cards.is_empty():
		return

	# Preview cards emulate queued offers: deeper card => more transparent.
	for i in range(_diplomacy_queue_preview_cards.size()):
		var card = _diplomacy_queue_preview_cards[i] as Panel
		if card == null:
			continue
		var depth = i + 2 # card #2, #3, #4 relative to active card
		card.visible = pending_count >= depth
		if not card.visible:
			continue
		var alpha = clamp(0.28 - float(i) * 0.09, 0.06, 0.35)
		card.self_modulate = Color(1, 1, 1, alpha / 0.30)
	_rozmistit_vizual_fronty_diplomacii()

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
		alliance_level_option.tooltip_text = "Alliance cannot be changed during war."
	elif alliance_request_pending:
		alliance_level_option.tooltip_text = "Alliance request already sent. Waiting for response."
	elif rel < 60.0:
		alliance_level_option.tooltip_text = "Defensive alliance requires relation at least 60."
	elif rel < 75.0:
		alliance_level_option.tooltip_text = "Offensive alliance requires relation at least 75."
	elif rel < 90.0:
		alliance_level_option.tooltip_text = "Full alliance requires relation at least 90."
	else:
		alliance_level_option.tooltip_text = "Higher alliance level unlocks broader call-to-war support."
	_updating_alliance_ui = false

func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
	if data.is_empty():
		schovej_se()
		return
		
	var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	current_viewed_tag = owner_tag # Save the tag for button actions
	_current_viewed_province_id = int(data.get("id", -1))
	
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
	var total_soldiers = 0
	
	# Calculate total country stats
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == owner_tag:
			total_pop += int(p.get("population", 0))
			total_gdp += float(p.get("gdp", 0.0))
			total_recruits += int(p.get("recruitable_population", 0))
			total_soldiers += int(p.get("soldiers", 0))
			
	name_label.text = plne_jmeno
	ideo_label.text = "Regime: " + ideologie.capitalize()
	pop_label.text = "Total population: " + _formatuj_cislo(total_pop)
	
	# Calculate recruitable population percentage
	var procento = 0.0
	if total_pop > 0:
		procento = (float(total_recruits) / float(total_pop)) * 100.0
		
	recruit_label.text = "Total recruits: " + _formatuj_cislo(total_recruits) + " (%.2f %%)" % procento
	if army_power_label:
		var army_total = total_soldiers
		var bonus_flat = 0
		var bonus_pct = 0.0
		if GameManager.has_method("ziskej_silu_armady_statu"):
			var power_info = GameManager.ziskej_silu_armady_statu(owner_tag, total_soldiers) as Dictionary
			army_total = int(power_info.get("total", total_soldiers))
			bonus_flat = int(power_info.get("bonus_flat", 0))
			bonus_pct = float(power_info.get("bonus_pct", 0.0)) * 100.0
		var mult = 1.0
		if total_soldiers > 0:
			mult = float(army_total) / float(total_soldiers)
		else:
			mult = 1.0 + (bonus_pct / 100.0)
		army_power_label.text = "Army strength: %.3fx (+%d | +%.2f%%)" % [mult, bonus_flat, bonus_pct]
	gdp_label.text = "Total GDP: %.2f bn USD" % total_gdp
	
	# Calculate GDP per capita
	if total_pop > 0:
		var gdp_per_capita = (total_gdp * 1000000000.0) / float(total_pop)
		gdp_pc_label.text = "GDP per capita: $%.0f" % gdp_per_capita
	else:
		gdp_pc_label.text = "GDP per capita: N/A"
	_aktualizuj_mirove_overview_statistiky(owner_tag, owner_tag == player_tag)
	_aktualizuj_tlacitko_vazalu(owner_tag == player_tag)

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
			if research_btn: research_btn.show()
		else:
			_aktualizuj_ideology_ui(owner_tag, ideologie)
			_aktualizuj_vztah_ui(owner_tag)
			if _research_dialog and _research_dialog.visible:
				_zavri_vyzkum_dialog()
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
			if research_btn: research_btn.hide()
	
	panel.show()

func _aktualizuj_mirove_overview_statistiky(owner_tag: String, je_hracuv_stat: bool) -> void:
	if vassals_label == null or war_reparations_label == null:
		return
	if not je_hracuv_stat:
		vassals_label.hide()
		war_reparations_label.hide()
		return

	vassals_label.show()
	war_reparations_label.show()

	var tag = owner_tag.strip_edges().to_upper()
	if tag == "":
		vassals_label.text = "Vassals: -"
		war_reparations_label.text = "War reparations: -"
		return

	var vassals_text = "-"
	if GameManager.has_method("ziskej_vazaly_statu"):
		var vassals = GameManager.ziskej_vazaly_statu(tag) as Array
		vassals_text = ", ".join(vassals) if not vassals.is_empty() else "none"
	vassals_label.text = "Vassals: %s" % vassals_text

	var repar_text = "none"
	if GameManager.has_method("ziskej_aktivni_reparace_statu"):
		var rep = GameManager.ziskej_aktivni_reparace_statu(tag) as Dictionary
		var incoming = (rep.get("incoming", []) as Array).size()
		var outgoing = (rep.get("outgoing", []) as Array).size()
		repar_text = "+%d / -%d" % [incoming, outgoing]
	war_reparations_label.text = "War reparations: %s" % repar_text

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
		await zobraz_systemove_hlaseni("Ideology", str(result.get("reason", "Ideology change failed.")))
		return

	var changed = bool(result.get("changed", true))
	if not changed:
		await zobraz_systemove_hlaseni("Ideology", "This ideology is already active.")
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
		"Ideology",
		"Country %s switched to ideology %s.\nImproved relations: %d\nWorsened relations: %d" % [
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
	# Keep peace conference open until player exits manually.
	if _research_dialog and _research_dialog.visible:
		_zavri_vyzkum_dialog()
	if research_btn:
		research_btn.hide()
	_current_viewed_province_id = -1
	_ceka_na_vyber_cile_hlavniho_mesta = false
	_relocate_capital_action_lock = false
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
	_aktualizuj_panel_zprav()

func _on_propose_peace_button_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return

	GameManager.nabidnout_mir(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

func _on_non_aggression_button_pressed():
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("uzavrit_neagresivni_smlouvu"):
		return

	var success = bool(GameManager.uzavrit_neagresivni_smlouvu(GameManager.hrac_stat, current_viewed_tag))
	if success:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

func _on_popup_accept_request_pressed():
	# Legacy wrapper: accept currently highlighted request.
	if _popup_request_from_tag == "":
		return
	_on_queue_row_accept_pressed(_popup_request_from_tag)

func _on_popup_decline_request_pressed():
	# Legacy wrapper: decline currently highlighted request.
	if _popup_request_from_tag == "":
		return
	_on_queue_row_decline_pressed(_popup_request_from_tag)

func _on_popup_accept_all_requests_pressed():
	if not GameManager.has_method("hrac_prijmi_vsechny_diplomaticke_zadosti"):
		return
	var accepted = int(GameManager.hrac_prijmi_vsechny_diplomaticke_zadosti(GameManager.hrac_stat))
	if accepted <= 0:
		return
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag != "":
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

func _on_popup_decline_all_requests_pressed():
	if not GameManager.has_method("hrac_odmitni_vsechny_diplomaticke_zadosti"):
		return
	var declined = int(GameManager.hrac_odmitni_vsechny_diplomaticke_zadosti(GameManager.hrac_stat))
	if declined <= 0:
		return
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag != "":
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
			_aktualizuj_panel_zprav()
		return

	var success = bool(GameManager.nastav_uroven_aliance(GameManager.hrac_stat, current_viewed_tag, index))
	if not success:
		_aktualizuj_aliance_ui(current_viewed_tag)
		return

	_aktualizuj_aliance_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

func _on_kolo_zmeneno():
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	_aktualizuj_hlaseni_mirove_konference()
	# Keep research window open; player closes it manually.
	if _research_dialog and _research_dialog.visible and GameManager:
		_aktualizuj_vyzkum_dialog(str(GameManager.hrac_stat).strip_edges().to_upper())
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
	var relation_suffix = ""
	if GameManager.has_method("je_vazal_statu"):
		if bool(GameManager.je_vazal_statu(target_tag, GameManager.hrac_stat)):
			relation_suffix = " | Your vassal"
		elif bool(GameManager.je_vazal_statu(GameManager.hrac_stat, target_tag)):
			relation_suffix = " | Your overlord"
	relationship_label.text = "Our relation: %.1f%s" % [vztah, relation_suffix]
	relationship_label.show()
	var zbyle_kola := 0
	if GameManager.has_method("zbyva_kol_do_upravy_vztahu"):
		zbyle_kola = int(GameManager.zbyva_kol_do_upravy_vztahu(GameManager.hrac_stat, target_tag))
	var je_cooldown = zbyle_kola > 0

	if improve_rel_btn:
		improve_rel_btn.text = "Improve relation (%d turns)" % zbyle_kola if je_cooldown else "Improve relation (+10)"
		improve_rel_btn.disabled = je_cooldown or vztah >= 100.0
	if worsen_rel_btn:
		worsen_rel_btn.text = "Worsen relation (%d turns)" % zbyle_kola if je_cooldown else "Worsen relation (-10)"
		worsen_rel_btn.disabled = je_cooldown or vztah <= -100.0
	if gift_money_btn:
		gift_money_btn.text = "Send gift"
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
		declare_war_btn.text = "AT WAR"
		declare_war_btn.disabled = true
		declare_war_btn.modulate = Color(1, 0.5, 0.5)
		declare_war_btn.show()

		var ceka_na_odpoved = GameManager.je_mirova_nabidka_cekajici(GameManager.hrac_stat, target)
		propose_peace_btn.text = "Proposal sent" if ceka_na_odpoved else "Offer peace"
		propose_peace_btn.disabled = ceka_na_odpoved
		propose_peace_btn.modulate = Color(1, 1, 1)
		propose_peace_btn.show()

		if alliance_level_option:
			alliance_level_option.disabled = true
		if non_aggression_btn:
			non_aggression_btn.text = "Non-aggression pact (war locked)"
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
			declare_war_btn.text = "War cooldown (%dT)" % peace_cooldown_turns_left
		else:
			declare_war_btn.text = "Declare war"
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
				non_aggression_btn.text = "Non-aggression pact (%dT)" % non_aggression_turns_left
				non_aggression_btn.disabled = true
				non_aggression_btn.modulate = Color(1, 1, 1)
			else:
				non_aggression_btn.text = "Non-aggression pact (10T)"
				non_aggression_btn.disabled = rel < 10.0
				non_aggression_btn.modulate = Color(1, 1, 1)
