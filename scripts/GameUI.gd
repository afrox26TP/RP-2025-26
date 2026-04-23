# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends CanvasLayer
# this script drives a specific gameplay/UI area and keeps related logic together.

# Main in-game UI controller.
# Handles diplomacy panels, economy actions, research widgets, and popups.
# Hard part: this file coordinates many modal states (trade/peace/loan/pause),
# so flags below track which interaction currently owns user input.

const ControlsConfig = preload("res://scripts/ControlsConfig.gd")
const CountryCustomization = preload("res://scripts/CountryCustomization.gd")
const TooltipUtilsScript = preload("res://scripts/TooltipUtils.gd")
const OVERVIEW_TARGET_WIDTH := 324.0
const OVERVIEW_MIN_WIDTH := 324.0
const OVERVIEW_MAX_WIDTH := 324.0
const OVERVIEW_TARGET_HEIGHT := 900.0
const OVERVIEW_MIN_HEIGHT := 560.0
const OVERVIEW_SCREEN_MARGIN := 10.0
const OVERVIEW_INLINE_DELTA_WIDTH := 124.0
const RENAME_DIALOG_SIZE := Vector2i(500, 230)
const SETTINGS_DIALOG_DEFAULT_SIZE := Vector2i(620, 560)
const SETTINGS_DIALOG_MIN_SIZE := Vector2i(320, 300)
const SETTINGS_DIALOG_SCREEN_MARGIN := 28.0

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
var _military_access_btn: Button
var army_power_label: Label
var vassals_label: Label
var war_reparations_label: Label
var ai_debug_panel: PanelContainer
var ai_debug_label: RichTextLabel
var _ai_debug_header: HBoxContainer
var _ai_debug_title_label: Label
var _ai_debug_min_btn: Button
var _ai_debug_max_btn: Button
var _ai_debug_filter_row: HBoxContainer
var _ai_debug_filter_all_btn: Button
var _ai_debug_filter_mine_btn: Button
var _ai_debug_filter_other_btn: Button
var _ai_debug_mode_option: OptionButton
var _ai_debug_collapsed: bool = false
var _ai_debug_expanded: bool = false
var _ai_debug_filter_mode: int = 0
var _ai_debug_section_mode: int = 0

# --- NEW: Action nodes ---
@onready var action_separator = $OverviewPanel/VBoxContainer/ActionSeparator
@onready var improve_rel_btn = $OverviewPanel/VBoxContainer/ImproveRelationButton
@onready var worsen_rel_btn = $OverviewPanel/VBoxContainer/WorsenRelationButton
@onready var alliance_btn = $OverviewPanel/VBoxContainer/AllianceLevelOption
@onready var declare_war_btn = $OverviewPanel/VBoxContainer/DeclareWarButton
@onready var propose_peace_btn = $OverviewPanel/VBoxContainer/ProposePeaceButton
@onready var non_aggression_btn = $OverviewPanel/VBoxContainer/NonAggressionButton
@onready var give_loan_btn = $OverviewPanel/VBoxContainer/LoansHBox/GiveLoanButton
@onready var take_loan_btn = $OverviewPanel/VBoxContainer/LoansHBox/TakeLoanButton
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

# Alliance popup variables
var _alliance_dialog: PanelContainer
var _alliance_dialog_scroll: ScrollContainer
var _alliance_dialog_list: VBoxContainer
var _alliance_dialog_close_btn: Button
var _alliance_dialog_create_btn: Button
var _alliance_dialog_title: Label
var _alliance_create_popup: PanelContainer
var _alliance_create_name_input: LineEdit
var _alliance_create_level_option: OptionButton
var _alliance_create_color_picker: ColorPickerButton
var _alliance_create_confirm_btn: Button
var _alliance_create_cancel_btn: Button
var _alliance_dialog_target_tag: String = ""
var _system_message_ack: bool = false
var _loans_dialog: PopupPanel
var _loans_list: VBoxContainer
var _loans_mode: String = ""  # "give" or "take"
var _loan_principal_slider: HSlider
var _loan_principal_input: LineEdit
var _loan_interest_slider: HSlider
var _loan_interest_input: LineEdit
var _loan_duration_slider: HSlider
var _loan_duration_input: LineEdit
var _pending_loan_notes: Array = []
var _showing_loan_notes: bool = false
var _pause_menu_panel: PopupPanel
var _pause_confirm_dialog: ConfirmationDialog
var _pause_pending_action: String = ""
var _pause_spectate_btn: Button = null
var _pause_spectate_pick_row: HBoxContainer = null
var _pause_spectate_pick_label: Label = null
var _pause_spectate_pick_option: OptionButton = null
var _spectate_mode_enabled: bool = false
var _spectate_auto_turn_cooldown: float = 0.0
var _spectate_focus_index: int = 0
var _spectate_hud_panel: PanelContainer = null
var _spectate_hud_label: Label = null
var _overview_metric_rows: Dictionary = {}
var _overview_metric_deltas: Dictionary = {}
var _overview_metric_delta_holders: Dictionary = {}
var _overview_preview_deltas: Dictionary = {}
var _overview_action_econ_preview: Dictionary = {}
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
var _settings_potato_mode_check: CheckBox
var _settings_ai_debug_mode_check: CheckBox
var _settings_skip_battle_reports_check: CheckBox
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
var _settings_keybind_grid: GridContainer
var _settings_keybind_buttons: Dictionary = {}
var _settings_keybind_state: Dictionary = {}
var _settings_capture_action: String = ""
var _gift_dialog: PopupPanel
var _gift_amount_input: LineEdit
var _rename_country_dialog: PopupPanel
var _rename_country_input: LineEdit
var _rename_country_confirm_btn: Button
var _rename_country_upload_flag_btn: Button
var _custom_flag_dialog: FileDialog
var _pending_custom_flag_tag: String = ""
var gift_money_btn: Button
var trade_btn: Button
var _trade_dialog: PopupPanel
var _trade_title_label: Label
var _trade_success_label: Label
var _trade_left_title_label: Label
var _trade_right_title_label: Label
var _trade_left_buttons: Dictionary = {}
var _trade_right_buttons: Dictionary = {}
var _trade_left_editor: Dictionary = {}
var _trade_right_editor: Dictionary = {}
var _trade_left_values: Dictionary = {}
var _trade_right_values: Dictionary = {}
var _trade_left_selected_slot: String = ""
var _trade_right_selected_slot: String = ""
var _trade_target_tag: String = ""
var _trade_province_picker_popup: PopupPanel
var _trade_province_picker_title: Label
var _trade_province_picker_info: Label
var _trade_province_picker_count: Label
var _trade_province_picker_confirm_btn: Button
var _trade_province_picker_cancel_btn: Button
var _ceka_na_vyber_trade_provincie: bool = false
var _trade_map_pick_side: int = -1
var _trade_map_pick_source_tag: String = ""
var _trade_map_selected_ids: Array = []
var _trade_dialog_hidden_for_map_pick: bool = false
var _ceka_na_vyber_trade_war_cile: bool = false
var _trade_war_pick_side: int = -1
var _trade_war_provider_tag: String = ""
var _trade_war_receiver_tag: String = ""
var _trade_war_pick_slot: String = ""
var _trade_dialog_hidden_for_war_pick: bool = false
var _ceka_na_vyber_trade_aliance: bool = false
var _trade_alliance_pick_side: int = -1
var _trade_alliance_pick_provider_tag: String = ""
var _trade_dialog_hidden_for_alliance_pick: bool = false
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
var ideology_menu_btn: Button
var ideology_menu_popup: PopupMenu
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
var _diplomacy_popup_dismissed_signature: String = ""
var _turn_loading_overlay: ColorRect
var _turn_loading_label: Label
var _turn_loading_tip_label: Label
var _turn_loading_anim_time: float = 0.0
var _turn_loading_anim_step: int = 0
var _turn_loading_active: bool = false
var _turn_loading_suppressed: bool = false
var _turn_loading_tip_anim_time: float = 0.0
var _turn_loading_tip_step: int = 0
var _debug_turn_start_ms: int = -1
var _debug_last_turn_ms: int = -1
var _debug_turn_total_ms: int = 0
var _debug_turn_samples: int = 0
var _debug_turn_recent_ms: Array = []
var _country_overview_stats_cache: Dictionary = {}
var _system_battle_panel: PanelContainer = null
var _system_battle_left_flag: TextureRect = null
var _system_battle_right_flag: TextureRect = null
var _system_battle_left_name: Label = null
var _system_battle_right_name: Label = null
var _system_battle_left_losses_label: Label = null
var _system_battle_right_losses_label: Label = null
var _system_battle_left_strength_label: Label = null
var _system_battle_right_strength_label: Label = null
var _system_battle_winner_label: Label = null
var _system_battle_adv_bar: ProgressBar = null
var _system_battle_margin_label: Label = null
var _system_message_compact_battle: bool = false
var _system_message_meta_row: HBoxContainer = null
var _system_message_meta_left_flag: TextureButton = null
var _system_message_meta_right_flag: TextureButton = null
var _system_message_meta_center_label: Label = null
var _system_batch_panel: ScrollContainer = null
var _system_batch_list: VBoxContainer = null

const POPUP_TOP_MARGIN := 6
const POPUP_GAP := 6
const QUEUE_PREVIEW_MAX_ITEMS := 8
const ZPRAVY_MAX_ITEMS := 180
const ZPRAVY_HISTORY_MAX_ITEMS := 500
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const SETTINGS_FILE_PATH := "user://settings.cfg"
const IDEOLOGY_UI_ORDER := ["demokracie", "kralovstvi", "autokracie", "komunismus", "nacismus", "fasismus"]
const TURN_LOADING_FRAMES := ["Zpracovavam tah", "Zpracovavam tah.", "Zpracovavam tah..", "Zpracovavam tah..."]
const TURN_LOADING_TIPS := [
	"Pripravuji ekonomicky prehled statu...",
	"Synchronizuji diplomacii a valecne vztahy...",
	"Aktualizuji armady, laboratore a produkci...",
	"Cistim fronty udalosti a zpravy pro dalsi tah..."
]
const TURN_LOADING_TIP_STEP_SEC := 1.8
const SYSTEM_MESSAGE_TURN_AUTO_ACK_MS := 7000
const TURN_DEBUG_RECENT_LIMIT := 24
const TURN_DEBUG_SLOW_THRESHOLD_MS := 900
const SPECTATE_AUTO_NEXT_TURN_SEC := 0.45
const SYSTEM_BATTLE_PANEL_HEIGHT := 118.0
const SYSTEM_BATTLE_FLAG_SIZE := Vector2(46.0, 30.0)
const SYSTEM_MESSAGE_META_ROW_HEIGHT := 24.0
const SYSTEM_BATCH_FLAG_SIZE := Vector2(36.0, 22.0)
const SYSTEM_BATCH_MAX_VISIBLE_HEIGHT := 280.0
const AI_DEBUG_SECTION_ALL := 0
const AI_DEBUG_SECTION_AI := 1
const AI_DEBUG_SECTION_LATENCY := 2
const AI_DEBUG_SECTION_ECONOMY := 3
const AI_DEBUG_SECTION_DIPLOMACY := 4
const AI_DEBUG_SECTION_TURN_PIPELINE := 5

func _resolve_flag_texture(owner_tag: String, ideologie: String):
	var cisty_tag = owner_tag.strip_edges().to_upper()
	var custom_tex = CountryCustomization.load_custom_flag_texture(cisty_tag, flag_texture_cache)
	if custom_tex:
		return custom_tex
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

# Read-only data accessor.
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
	# Build/prepare all major UI subsystems before any popup can open.
	# Pro male dite: tady se sklada cele herni menu, aby se nic nerozbilo po prvnim kliknuti.
	ControlsConfig.ensure_default_actions()
	panel.hide()
	_setup_overview_inline_deltas()
	_zajisti_label_sily_armady()
	_zajisti_mirove_overview_labely()
	_zajisti_ai_debug_overview_labely()
	_nastav_overview_text_properties()
	_zajisti_tlacitko_vazalu()
	_zajisti_tlacitko_daru()
	_zajisti_tlacitko_obchodu()
	_zajisti_tlacitko_vojenskeho_pristupu()
	_zajisti_ideology_controls()
	_zajisti_vyzkum_controls()
	_setup_popup_country_link()
	_setup_country_name_rename_link()
	_setup_country_flag_upload_link()
	_vytvor_custom_flag_dialog()
	_vytvor_alliance_dialog()
	_vytvor_alliance_create_popup()
	_vytvor_trade_dialog()
	if GameManager and GameManager.has_method("je_spectate_mode_aktivni"):
		# Restore spectate state after load so pause/HUD stay in sync with GameManager.
		_spectate_mode_enabled = bool(GameManager.je_spectate_mode_aktivni())
		if _spectate_mode_enabled:
			_spectate_auto_turn_cooldown = 0.05
			_spectate_focus_index = 0
	_ensure_spectate_hud_indicator()
	_obnov_spectate_hud_indicator()
	
	# Automatically connect the button signal if it exists
	if declare_war_btn and not declare_war_btn.pressed.is_connected(_on_declare_war_button_pressed):
		declare_war_btn.pressed.connect(_on_declare_war_button_pressed)
	if propose_peace_btn and not propose_peace_btn.pressed.is_connected(_on_propose_peace_button_pressed):
		propose_peace_btn.pressed.connect(_on_propose_peace_button_pressed)
	if non_aggression_btn and not non_aggression_btn.pressed.is_connected(_on_non_aggression_button_pressed):
		non_aggression_btn.pressed.connect(_on_non_aggression_button_pressed)
	if give_loan_btn and not give_loan_btn.pressed.is_connected(func(): _on_loan_button_pressed("give")):
		give_loan_btn.pressed.connect(func(): _on_loan_button_pressed("give"))
		give_loan_btn.focus_mode = Control.FOCUS_NONE
	if take_loan_btn and not take_loan_btn.pressed.is_connected(func(): _on_loan_button_pressed("take")):
		take_loan_btn.pressed.connect(func(): _on_loan_button_pressed("take"))
		take_loan_btn.focus_mode = Control.FOCUS_NONE
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
	if system_message_ok_btn:
		system_message_ok_btn.text = "OK [Space]"
		_aplikuj_ingame_tlacitko_styl(system_message_ok_btn)
		system_message_ok_btn.custom_minimum_size = Vector2(220, maxf(36.0, system_message_ok_btn.custom_minimum_size.y))
		# Keep the button centered, avoids the old stretched/basic look.
		system_message_ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if system_message_popup:
		# Make core report popup consistent with dark-blue UI language.
		system_message_popup.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.03, 0.07, 0.16, 0.97), Color(0.36, 0.57, 0.87, 0.82)))
	if system_message_title:
		system_message_title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
		system_message_title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
		system_message_title.add_theme_constant_override("outline_size", 2)
	if system_message_text:
		system_message_text.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.98))
		system_message_text.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.85))
		system_message_text.add_theme_constant_override("outline_size", 1)
	if improve_rel_btn and not improve_rel_btn.pressed.is_connected(_on_improve_relationship_pressed):
		improve_rel_btn.pressed.connect(_on_improve_relationship_pressed)
	if worsen_rel_btn and not worsen_rel_btn.pressed.is_connected(_on_worsen_relationship_pressed):
		worsen_rel_btn.pressed.connect(_on_worsen_relationship_pressed)
	if gift_money_btn and not gift_money_btn.pressed.is_connected(_on_gift_money_pressed):
		gift_money_btn.pressed.connect(_on_gift_money_pressed)
	if trade_btn and not trade_btn.pressed.is_connected(_on_trade_button_pressed):
		trade_btn.pressed.connect(_on_trade_button_pressed)
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
	if ideology_menu_btn and not ideology_menu_btn.pressed.is_connected(_on_ideology_menu_button_pressed):
		ideology_menu_btn.pressed.connect(_on_ideology_menu_button_pressed)
	if ideology_menu_popup:
		if not ideology_menu_popup.id_pressed.is_connected(_on_ideology_menu_id_pressed):
			ideology_menu_popup.id_pressed.connect(_on_ideology_menu_id_pressed)
		if ideology_menu_popup.has_signal("about_to_popup") and not ideology_menu_popup.about_to_popup.is_connected(_on_ideology_dropdown_opened):
			ideology_menu_popup.about_to_popup.connect(_on_ideology_dropdown_opened)
		if ideology_menu_popup.has_signal("id_focused") and not ideology_menu_popup.id_focused.is_connected(_on_ideology_dropdown_item_focused):
			ideology_menu_popup.id_focused.connect(_on_ideology_dropdown_item_focused)
		if ideology_menu_popup.has_signal("popup_hide") and not ideology_menu_popup.popup_hide.is_connected(_on_ideology_dropdown_closed):
			ideology_menu_popup.popup_hide.connect(_on_ideology_dropdown_closed)
	if ideology_relocate_capital_btn and not ideology_relocate_capital_btn.pressed.is_connected(_on_relocate_capital_pressed):
		ideology_relocate_capital_btn.pressed.connect(_on_relocate_capital_pressed)
	if research_btn and not research_btn.pressed.is_connected(_on_research_button_pressed):
		research_btn.pressed.connect(_on_research_button_pressed)
	if alliance_btn and not alliance_btn.pressed.is_connected(_on_alliance_button_pressed):
		alliance_btn.pressed.connect(_on_alliance_button_pressed)
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)
	if GameManager.has_signal("zpracovani_tahu_zmeneno") and not GameManager.zpracovani_tahu_zmeneno.is_connected(_on_zpracovani_tahu_zmeneno):
		GameManager.zpracovani_tahu_zmeneno.connect(_on_zpracovani_tahu_zmeneno)
	if diplomacy_request_popup:
		_aplikuj_ingame_popup_styl(diplomacy_request_popup)
		if popup_accept_btn:
			_aplikuj_ingame_tlacitko_styl(popup_accept_btn)
		if popup_decline_btn:
			_aplikuj_ingame_tlacitko_styl(popup_decline_btn, true)
		if popup_decline_all_btn:
			_aplikuj_ingame_tlacitko_styl(popup_decline_all_btn, true)
		if popup_request_text:
			popup_request_text.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
			popup_request_text.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.90))
			popup_request_text.add_theme_constant_override("outline_size", 1)
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
	_nastav_tooltipy_ui()
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_aktualizuj_overview_panel_layout()
	_vytvor_pause_menu()
	_vytvor_turn_loading_overlay()
	_on_zpracovani_tahu_zmeneno(bool(GameManager.zpracovava_se_tah))
	_aktualizuj_pozice_popupu()
	_aktualizuj_popup_diplomatickych_zadosti()
	_vytvor_darovaci_dialog()
	_vytvor_prejmenovani_statu_dialog()
	_vytvor_mirovou_konferenci_dialog()
	_vytvor_hlaseni_mirove_konference()
	_vytvor_panel_vazalu()
	_vytvor_vyzkum_dialog()
	_vytvor_loans_dialog()
	# Pre-layout research dialog once in hidden mode; fixes broken first open in turn 0.
	call_deferred("_predhrej_vyzkum_dialog_layout")
	_nastav_tooltipy_ui()
	_aktualizuj_hlaseni_mirove_konference()

# Per-frame runtime logic.
func _process(_delta: float) -> void:
	if _spectate_mode_enabled and not _turn_loading_active and GameManager and not bool(GameManager.zpracovava_se_tah):
		_spectate_auto_turn_cooldown -= _delta
		if _spectate_auto_turn_cooldown <= 0.0 and _lze_automaticky_ukoncit_tah_ve_spectate():
			_spectate_auto_turn_cooldown = SPECTATE_AUTO_NEXT_TURN_SEC
			if GameManager.has_method("pozaduj_ukonceni_kola"):
				GameManager.pozaduj_ukonceni_kola()
			elif GameManager.has_method("ukonci_kolo"):
				GameManager.ukonci_kolo()

	if _research_dialog and _research_dialog.visible:
		if panel == null or not panel.visible or research_btn == null or not research_btn.visible:
			_zavri_vyzkum_dialog()

	if _turn_loading_active:
		_turn_loading_anim_time += _delta
		_turn_loading_tip_anim_time += _delta
		if _turn_loading_anim_time >= 0.2 and _turn_loading_label:
			_turn_loading_anim_time = 0.0
			_turn_loading_anim_step = (_turn_loading_anim_step + 1) % TURN_LOADING_FRAMES.size()
			_turn_loading_label.text = TURN_LOADING_FRAMES[_turn_loading_anim_step]
		if _turn_loading_tip_anim_time >= TURN_LOADING_TIP_STEP_SEC and _turn_loading_tip_label:
			_turn_loading_tip_anim_time = 0.0
			_turn_loading_tip_step = (_turn_loading_tip_step + 1) % TURN_LOADING_TIPS.size()
			_turn_loading_tip_label.text = TURN_LOADING_TIPS[_turn_loading_tip_step]

	if not _ideology_dropdown_open:
		if not _turn_loading_active:
			set_process(false)
		return
	var popup: PopupMenu = null
	if ideology_menu_popup and ideology_menu_popup.visible:
		popup = ideology_menu_popup
	elif ideology_option and ideology_option.get_popup() and ideology_option.get_popup().visible:
		popup = ideology_option.get_popup()
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

	_turn_loading_tip_label = Label.new()
	_turn_loading_tip_label.name = "TurnLoadingTipLabel"
	_turn_loading_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_loading_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_loading_tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_turn_loading_tip_label.offset_top = 28.0
	_turn_loading_tip_label.offset_bottom = 58.0
	_turn_loading_tip_label.custom_minimum_size = Vector2(720.0, 24.0)
	_turn_loading_tip_label.text = TURN_LOADING_TIPS[0]
	_turn_loading_tip_label.add_theme_font_size_override("font_size", 15)
	_turn_loading_tip_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96, 0.95))
	_turn_loading_overlay.add_child(_turn_loading_tip_label)

# Triggered by a UI/game signal.
func _on_zpracovani_tahu_zmeneno(aktivni: bool) -> void:
	var now_ms := Time.get_ticks_msec()
	if aktivni:
		_debug_turn_start_ms = now_ms
	elif _debug_turn_start_ms >= 0:
		_debug_last_turn_ms = max(0, now_ms - _debug_turn_start_ms)
		_debug_turn_total_ms += _debug_last_turn_ms
		_debug_turn_samples += 1
		_debug_turn_recent_ms.append(_debug_last_turn_ms)
		if _debug_turn_recent_ms.size() > TURN_DEBUG_RECENT_LIMIT:
			_debug_turn_recent_ms.pop_front()
		if _debug_last_turn_ms >= TURN_DEBUG_SLOW_THRESHOLD_MS:
			print("[TurnDebug] Slow turn detected: ", _debug_last_turn_ms, " ms (threshold ", TURN_DEBUG_SLOW_THRESHOLD_MS, " ms)")
		_debug_turn_start_ms = -1

	_turn_loading_active = aktivni
	_turn_loading_anim_time = 0.0
	_turn_loading_anim_step = 0
	_turn_loading_tip_anim_time = 0.0
	_turn_loading_tip_step = 0
	if _turn_loading_overlay:
		_turn_loading_overlay.visible = aktivni and not _turn_loading_suppressed
	if _turn_loading_label:
		_turn_loading_label.text = TURN_LOADING_FRAMES[0]
	if _turn_loading_tip_label:
		_turn_loading_tip_label.text = TURN_LOADING_TIPS[0]
	if not aktivni and not _pending_loan_notes.is_empty():
		call_deferred("_zobraz_pending_loan_notes")
	if not aktivni and _je_spectate_observer_mode():
		call_deferred("_spectate_focus_next_ai_state")
	if aktivni:
		set_process(true)

func _lze_automaticky_ukoncit_tah_ve_spectate() -> bool:
	if _settings_dialog and _settings_dialog.visible:
		return false
	if _save_dialog and _save_dialog.visible:
		return false
	if _load_dialog and _load_dialog.visible:
		return false
	if _trade_dialog and _trade_dialog.visible:
		return false
	if _peace_dialog and _peace_dialog.visible:
		return false
	if diplomacy_request_popup and diplomacy_request_popup.visible:
		return false
	if system_message_popup and system_message_popup.visible:
		return false
	if _pause_menu_panel and _pause_menu_panel.visible:
		return false
	return true

# Prevent Space end-turn from leaking through while any major popup/dialog is open.
func blokuje_hotkey_ukonceni_tahu() -> bool:
	if _settings_dialog and _settings_dialog.visible:
		return true
	if _save_dialog and _save_dialog.visible:
		return true
	if _load_dialog and _load_dialog.visible:
		return true
	if _trade_dialog and _trade_dialog.visible:
		return true
	if _trade_province_picker_popup and _trade_province_picker_popup.visible:
		return true
	if _peace_dialog and _peace_dialog.visible:
		return true
	if diplomacy_request_popup and diplomacy_request_popup.visible:
		return true
	if system_message_popup and system_message_popup.visible:
		return true
	if _pause_menu_panel and _pause_menu_panel.visible:
		return true
	if _gift_dialog and _gift_dialog.visible:
		return true
	if _research_dialog and _research_dialog.visible:
		return true
	if _vassals_dialog and _vassals_dialog.visible:
		return true
	if _loans_dialog and _loans_dialog.visible:
		return true
	if _alliance_dialog and _alliance_dialog.visible:
		return true
	if _alliance_create_popup and _alliance_create_popup.visible:
		return true
	return false

func _je_spectate_observer_mode() -> bool:
	return _spectate_mode_enabled

func _ziskej_spectate_ai_staty() -> Array:
	var out: Array = []
	if not GameManager:
		return out
	var human_set: Dictionary = {}
	for tag_any in (GameManager.lokalni_hraci_staty as Array):
		var ht = str(tag_any).strip_edges().to_upper()
		if ht != "":
			human_set[ht] = true
	if human_set.is_empty():
		var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
		if player_tag != "":
			human_set[player_tag] = true
	for p_id in GameManager.map_data:
		var d = GameManager.map_data[p_id] as Dictionary
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue
		if human_set.has(owner):
			continue
		if not out.has(owner):
			out.append(owner)
	out.sort()
	return out

func _spectate_focus_next_ai_state() -> void:
	if not _je_spectate_observer_mode():
		return
	var ai_states = _ziskej_spectate_ai_staty()
	if ai_states.is_empty():
		return
	_spectate_focus_index = _spectate_focus_index % ai_states.size()
	var target_tag = str(ai_states[_spectate_focus_index])
	_spectate_focus_index = (_spectate_focus_index + 1) % ai_states.size()
	_otevri_prehled_statu_podle_tagu(target_tag)

func _spocitej_turn_debug_statistiky(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"avg": 0, "min": 0, "max": 0, "p95": 0}
	var sorted: Array = []
	var total := 0.0
	for val_any in samples:
		var ms = int(val_any)
		sorted.append(ms)
		total += float(ms)
	sorted.sort()
	var idx95 = int(ceil(float(sorted.size()) * 0.95)) - 1
	idx95 = clampi(idx95, 0, sorted.size() - 1)
	return {
		"avg": int(round(total / float(sorted.size()))),
		"min": int(sorted[0]),
		"max": int(sorted[sorted.size() - 1]),
		"p95": int(sorted[idx95])
	}

# Updates what the player sees.
func _zobraz_pending_loan_notes() -> void:
	if _showing_loan_notes:
		return
	if _pending_loan_notes.is_empty():
		return
	if GameManager and bool(GameManager.zpracovava_se_tah):
		return

	_showing_loan_notes = true
	while not _pending_loan_notes.is_empty():
		var note = str(_pending_loan_notes.pop_front()).strip_edges()
		if note == "":
			continue
		await zobraz_systemove_hlaseni("Loans", note)
	_showing_loan_notes = false

# Applies updates and syncs dependent state.
func nastav_pozastaveni_turn_overlay(pozastavit: bool) -> void:
	_turn_loading_suppressed = pozastavit
	if _turn_loading_overlay:
		_turn_loading_overlay.visible = _turn_loading_active and not _turn_loading_suppressed
	if not _turn_loading_active and not _ideology_dropdown_open:
		set_process(false)

func _setup_popup_country_link() -> void:
	# Sender name text in the popup was intentionally removed to keep the card compact.
	if _popup_country_link_btn:
		_popup_country_link_btn.hide()
		_popup_country_link_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if popup_request_flag and not popup_request_flag.gui_input.is_connected(_on_popup_flag_gui_input):
		popup_request_flag.gui_input.connect(_on_popup_flag_gui_input)
		popup_request_flag.mouse_filter = Control.MOUSE_FILTER_STOP
		popup_request_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _setup_country_name_rename_link() -> void:
	if name_label and not name_label.gui_input.is_connected(_on_country_name_gui_input):
		name_label.gui_input.connect(_on_country_name_gui_input)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _setup_country_flag_upload_link() -> void:
	if country_flag and not country_flag.gui_input.is_connected(_on_country_flag_gui_input):
		country_flag.gui_input.connect(_on_country_flag_gui_input)
		country_flag.mouse_filter = Control.MOUSE_FILTER_STOP
		country_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Builds UI objects and default wiring.
func _vytvor_custom_flag_dialog() -> void:
	if _custom_flag_dialog:
		return
	_custom_flag_dialog = FileDialog.new()
	_custom_flag_dialog.name = "CustomFlagDialog"
	_custom_flag_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_custom_flag_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_custom_flag_dialog.title = "Select custom flag"
	_custom_flag_dialog.use_native_dialog = false
	_custom_flag_dialog.min_size = Vector2i(680, 420)
	_custom_flag_dialog.size = Vector2i(780, 500)
	_custom_flag_dialog.ok_button_text = "Use flag"
	_custom_flag_dialog.unresizable = false
	_aplikuj_ingame_popup_styl(_custom_flag_dialog)
	_custom_flag_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp", "Image files")
	if not _custom_flag_dialog.file_selected.is_connected(_on_custom_flag_file_selected):
		_custom_flag_dialog.file_selected.connect(_on_custom_flag_file_selected)
	add_child(_custom_flag_dialog)

# Applies updates and syncs dependent state.
func _nastav_overview_text_properties() -> void:
	if ideo_label:
		ideo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ideo_label.custom_minimum_size = Vector2(0, 0)
		ideo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pop_label:
		pop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pop_label.custom_minimum_size = Vector2(0, 0)
		pop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if recruit_label:
		recruit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recruit_label.custom_minimum_size = Vector2(0, 0)
		recruit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if army_power_label:
		army_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		army_power_label.custom_minimum_size = Vector2(0, 0)
		army_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if gdp_label:
		gdp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gdp_label.custom_minimum_size = Vector2(0, 0)
		gdp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if gdp_pc_label:
		gdp_pc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gdp_pc_label.custom_minimum_size = Vector2(0, 0)
		gdp_pc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vassals_label:
		vassals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vassals_label.custom_minimum_size = Vector2(0, 0)
		vassals_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if war_reparations_label:
		war_reparations_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		war_reparations_label.custom_minimum_size = Vector2(0, 0)
		war_reparations_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

# Sync update for linked values.
func _nastav_tooltipy_ui() -> void:
	name_label.tooltip_text = "Name of the selected country. Double-click your own country name to rename it."
	country_flag.tooltip_text = "Flag of the selected country. Double-click your own flag to upload a custom image."
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
	if trade_btn:
		trade_btn.tooltip_text = "Open trade negotiation preview with the target country."
	declare_war_btn.tooltip_text = "Declare war on the selected country."
	propose_peace_btn.tooltip_text = "Send a peace proposal."
	non_aggression_btn.tooltip_text = "Sign a non-aggression pact for 10 turns."
	if _military_access_btn:
		_military_access_btn.tooltip_text = "Request permission to move your troops through this country's territory. Alliances grant access automatically."
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
	TooltipUtilsScript.apply_default_tooltips(self)

func _on_popup_flag_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_popup_country_reference_pressed()

# Event handler for user or game actions.
func _on_country_name_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or not mouse_event.double_click:
		return
	if current_viewed_tag == "":
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag != player_tag:
		return
	_otevri_prejmenovani_statu_dialog(player_tag)

# Triggered by a UI/game signal.
func _on_country_flag_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or not mouse_event.double_click:
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag == "" or current_viewed_tag != player_tag:
		return
	_otevri_upload_vlajky_dialog(player_tag)

func _on_popup_country_reference_pressed() -> void:
	_otevri_prehled_statu_podle_tagu(_popup_request_from_tag)

func _vytvor_prejmenovani_statu_dialog() -> void:
	if _rename_country_dialog:
		return
	_rename_country_dialog = PopupPanel.new()
	_rename_country_dialog.name = "RenameCountryDialog"
	_rename_country_dialog.wrap_controls = false
	_rename_country_dialog.unresizable = true
	_rename_country_dialog.size = RENAME_DIALOG_SIZE
	_rename_country_dialog.min_size = RENAME_DIALOG_SIZE
	_rename_country_dialog.max_size = RENAME_DIALOG_SIZE
	_aplikuj_ingame_popup_styl(_rename_country_dialog)
	add_child(_rename_country_dialog)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 16
	root.offset_right = -16
	root.offset_bottom = -16
	_rename_country_dialog.add_child(root)

	var title = Label.new()
	title.text = "Rename Country"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	root.add_child(title)

	_rename_country_input = LineEdit.new()
	_rename_country_input.placeholder_text = "Enter new country name"
	_rename_country_input.max_length = 40
	_rename_country_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_rename_country_input)
	if not _rename_country_input.text_submitted.is_connected(_on_confirm_rename_country):
		_rename_country_input.text_submitted.connect(_on_confirm_rename_country)

	var hint = Label.new()
	hint.text = "Only your country can be renamed. You can also upload a custom flag."
	hint.modulate = Color(0.82, 0.90, 0.98, 0.92)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	_aplikuj_ingame_tlacitko_styl(cancel_btn)
	row.add_child(cancel_btn)
	cancel_btn.pressed.connect(func():
		if _rename_country_dialog:
			_rename_country_dialog.hide()
	)

	_rename_country_upload_flag_btn = Button.new()
	_rename_country_upload_flag_btn.text = "Upload Flag"
	_aplikuj_ingame_tlacitko_styl(_rename_country_upload_flag_btn)
	row.add_child(_rename_country_upload_flag_btn)
	if not _rename_country_upload_flag_btn.pressed.is_connected(_on_rename_country_upload_flag_pressed):
		_rename_country_upload_flag_btn.pressed.connect(_on_rename_country_upload_flag_pressed)

	_rename_country_confirm_btn = Button.new()
	_rename_country_confirm_btn.text = "Save"
	_aplikuj_ingame_tlacitko_styl(_rename_country_confirm_btn)
	row.add_child(_rename_country_confirm_btn)
	if not _rename_country_confirm_btn.pressed.is_connected(_on_confirm_rename_country):
		_rename_country_confirm_btn.pressed.connect(_on_confirm_rename_country)

func _otevri_prejmenovani_statu_dialog(state_tag: String) -> void:
	if _rename_country_dialog == null:
		_vytvor_prejmenovani_statu_dialog()
	if _rename_country_dialog == null or _rename_country_input == null:
		return
	var current_name = _ziskej_jmeno_statu_podle_tagu(state_tag)
	_rename_country_input.text = current_name
	_vynutit_velikost_prejmenovani_dialogu(true)
	_rename_country_input.grab_focus()
	_rename_country_input.select_all()
	if _rename_country_upload_flag_btn:
		_rename_country_upload_flag_btn.disabled = state_tag.strip_edges().to_upper() != str(GameManager.hrac_stat).strip_edges().to_upper()

# Applies prepared settings/effects to runtime systems.
func _vynutit_velikost_prejmenovani_dialogu(center: bool = false) -> void:
	if _rename_country_dialog == null:
		return
	_rename_country_dialog.size = RENAME_DIALOG_SIZE
	_rename_country_dialog.min_size = RENAME_DIALOG_SIZE
	_rename_country_dialog.max_size = RENAME_DIALOG_SIZE
	if center:
		_rename_country_dialog.popup_centered(RENAME_DIALOG_SIZE)

func _on_rename_country_upload_flag_pressed() -> void:
	var state_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if state_tag == "":
		return
	_otevri_upload_vlajky_dialog(state_tag)

# Callback for UI/game events.
func _on_confirm_rename_country(_submitted_text: String = "") -> void:
	if _rename_country_input == null:
		return
	var state_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if state_tag == "":
		return
	var new_name = _rename_country_input.text.strip_edges()
	if new_name == "":
		await zobraz_systemove_hlaseni("Rename", "Country name cannot be empty.")
		return
	if not GameManager.has_method("prejmenuj_stat"):
		await zobraz_systemove_hlaseni("Rename", "Rename action is unavailable.")
		return
	var result = GameManager.prejmenuj_stat(state_tag, new_name) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Rename", str(result.get("reason", "Rename failed.")))
		return
	if _rename_country_dialog:
		_rename_country_dialog.hide()
	_obnov_otevreny_prehled_statu()
	await zobraz_systemove_hlaseni("Rename", "Country renamed to %s." % str(result.get("new_name", new_name)))

# Opens a UI flow/panel and prepares its data and position.
func _otevri_upload_vlajky_dialog(state_tag: String) -> void:
	if _custom_flag_dialog == null:
		_vytvor_custom_flag_dialog()
	if _custom_flag_dialog == null:
		return
	_pending_custom_flag_tag = str(state_tag).strip_edges().to_upper()
	var vp := get_viewport()
	if vp != null:
		var vp_size = vp.get_visible_rect().size
		var popup_w = clampi(int(vp_size.x * 0.68), 680, 980)
		var popup_h = clampi(int(vp_size.y * 0.62), 420, 620)
		_custom_flag_dialog.popup_centered(Vector2i(popup_w, popup_h))
	else:
		_custom_flag_dialog.popup_centered(Vector2i(780, 500))

func _on_custom_flag_file_selected(path: String) -> void:
	var target_tag = _pending_custom_flag_tag.strip_edges().to_upper()
	_pending_custom_flag_tag = ""
	if target_tag == "":
		return
	var result = CountryCustomization.save_custom_flag_from_source(target_tag, path) as Dictionary
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Flag", str(result.get("reason", "Flag upload failed.")))
		return
	flag_texture_cache.clear()
	_obnov_otevreny_prehled_statu()
	var map_loader = _ziskej_map_loader_node()
	if map_loader:
		if "flag_texture_cache" in map_loader:
			map_loader.flag_texture_cache.clear()
		if map_loader.has_method("aktualizuj_vlajky_hlavnich_mest"):
			map_loader.aktualizuj_vlajky_hlavnich_mest()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()
	await zobraz_systemove_hlaseni("Flag", "Custom flag was updated for %s." % _ziskej_jmeno_statu_podle_tagu(target_tag))

func _ziskej_map_loader_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("_ziskej_map_pozici_provincie") and scene_root.has_method("_ziskej_map_offset"):
		return scene_root
	if scene_root:
		var by_name = scene_root.find_child("Map", true, false)
		if by_name and by_name.has_method("_ziskej_map_pozici_provincie") and by_name.has_method("_ziskej_map_offset"):
			return by_name
	return null

func _ziskej_barvu_statu_pro_battle(tag: String) -> Color:
	var clean = tag.strip_edges().to_upper()
	if clean == "" or clean == "SEA":
		return Color(0.62, 0.62, 0.66, 1.0)
	var map_loader = _ziskej_map_loader_node()
	if map_loader and map_loader.has_method("_ziskej_zakladni_barvu_statu"):
		var base = map_loader._ziskej_zakladni_barvu_statu(clean)
		if base is Color:
			return (base as Color)
	# Fallback: deterministic color from tag hash.
	var hue = float(abs(clean.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 0.86, 1.0)

func _aplikuj_system_battle_barvy(left_tag: String, right_tag: String) -> void:
	if _system_battle_adv_bar == null:
		return
	var left_col = _ziskej_barvu_statu_pro_battle(left_tag)
	var right_col = _ziskej_barvu_statu_pro_battle(right_tag)
	# Slightly brighten both colors for UI readability.
	left_col = left_col.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.15)
	right_col = right_col.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.10)

	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = Color(left_col.r, left_col.g, left_col.b, 0.98)
	fill_sb.corner_radius_top_left = 2
	fill_sb.corner_radius_bottom_left = 2
	fill_sb.corner_radius_top_right = 2
	fill_sb.corner_radius_bottom_right = 2

	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(right_col.r, right_col.g, right_col.b, 0.92)
	bg_sb.border_width_left = 1
	bg_sb.border_width_top = 1
	bg_sb.border_width_right = 1
	bg_sb.border_width_bottom = 1
	bg_sb.border_color = Color(0.02, 0.03, 0.05, 0.75)
	bg_sb.corner_radius_top_left = 2
	bg_sb.corner_radius_bottom_left = 2
	bg_sb.corner_radius_top_right = 2
	bg_sb.corner_radius_bottom_right = 2

	_system_battle_adv_bar.add_theme_stylebox_override("fill", fill_sb)
	_system_battle_adv_bar.add_theme_stylebox_override("background", bg_sb)

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

# Figure out how much bottom space on the left side is already occupied (InfoUI blocks etc.).
func _ziskej_overview_left_bottom_reserved(target_w: float) -> Dictionary:
	var viewport = get_viewport()
	if viewport == null:
		return {"bottom_height": 0.0}
	var vp_size = viewport.get_visible_rect().size
	var vp_h = maxf(1.0, vp_size.y)

	var top_y: float = vp_h
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return {"bottom_height": 0.0}

	var info_ui = scene_root.find_child("InfoUI", true, false)
	if info_ui == null:
		return {"bottom_height": 0.0}

	var left_edge = 0.0
	var right_edge = left_edge + target_w
	for node_name in ["PanelContainer", "ActionMenu"]:
		var c = info_ui.get_node_or_null(node_name) as Control
		if c == null or not c.visible:
			continue
		var r = c.get_global_rect()
		var overlap_x = r.position.x < right_edge and (r.position.x + r.size.x) > left_edge
		if overlap_x:
			top_y = minf(top_y, r.position.y)

	if top_y >= vp_h:
		return {"bottom_height": 0.0}

	var reserved = maxf(0.0, vp_h - top_y)
	return {"bottom_height": reserved}

# Build battle summary widgets lazily; we only create this once when first needed.
func _ensure_system_battle_panel() -> void:
	if _system_battle_panel != null:
		return
	if system_message_text == null or system_message_text.get_parent() == null:
		return

	var vbox = system_message_text.get_parent() as VBoxContainer
	if vbox == null:
		return

	_system_battle_panel = PanelContainer.new()
	_system_battle_panel.name = "BattleSummaryPanel"
	_system_battle_panel.visible = false
	_system_battle_panel.custom_minimum_size = Vector2(0, SYSTEM_BATTLE_PANEL_HEIGHT)
	_system_battle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_battle_panel.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.05, 0.08, 0.16, 0.96), Color(0.71, 0.60, 0.22, 0.68)))
	vbox.add_child(_system_battle_panel)
	vbox.move_child(_system_battle_panel, system_message_text.get_index())

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_system_battle_panel.add_child(margin)

	var root_col = VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 6)
	margin.add_child(root_col)

	var losses_row = HBoxContainer.new()
	losses_row.add_theme_constant_override("separation", 6)
	root_col.add_child(losses_row)

	_system_battle_left_losses_label = Label.new()
	_system_battle_left_losses_label.add_theme_font_size_override("font_size", 24)
	_system_battle_left_losses_label.add_theme_color_override("font_color", Color(0.95, 0.22, 0.16, 1.0))
	_system_battle_left_losses_label.text = "-0"
	losses_row.add_child(_system_battle_left_losses_label)

	var losses_spacer = Control.new()
	losses_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	losses_row.add_child(losses_spacer)

	_system_battle_right_losses_label = Label.new()
	_system_battle_right_losses_label.add_theme_font_size_override("font_size", 24)
	_system_battle_right_losses_label.add_theme_color_override("font_color", Color(0.95, 0.22, 0.16, 1.0))
	_system_battle_right_losses_label.text = "-0"
	_system_battle_right_losses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	losses_row.add_child(_system_battle_right_losses_label)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root_col.add_child(row)

	var left_box = VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(112, 0)
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left_box)

	_system_battle_left_flag = TextureRect.new()
	_system_battle_left_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_system_battle_left_flag.custom_minimum_size = SYSTEM_BATTLE_FLAG_SIZE
	_system_battle_left_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_box.add_child(_system_battle_left_flag)

	_system_battle_left_name = Label.new()
	_system_battle_left_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_left_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_system_battle_left_name.add_theme_font_size_override("font_size", 14)
	left_box.add_child(_system_battle_left_name)

	_system_battle_left_strength_label = Label.new()
	_system_battle_left_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_left_strength_label.add_theme_font_size_override("font_size", 22)
	_system_battle_left_strength_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25, 1.0))
	left_box.add_child(_system_battle_left_strength_label)

	var center_box = VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 6)
	row.add_child(center_box)

	_system_battle_winner_label = Label.new()
	_system_battle_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_winner_label.add_theme_font_size_override("font_size", 30)
	_system_battle_winner_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.98))
	center_box.add_child(_system_battle_winner_label)

	_system_battle_adv_bar = ProgressBar.new()
	_system_battle_adv_bar.show_percentage = false
	_system_battle_adv_bar.min_value = 0
	_system_battle_adv_bar.max_value = 100
	_system_battle_adv_bar.value = 50
	_system_battle_adv_bar.custom_minimum_size = Vector2(190, 16)
	_system_battle_adv_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.add_child(_system_battle_adv_bar)

	_system_battle_margin_label = Label.new()
	_system_battle_margin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_margin_label.modulate = Color(0.84, 0.90, 1.0, 0.95)
	_system_battle_margin_label.add_theme_font_size_override("font_size", 12)
	center_box.add_child(_system_battle_margin_label)

	var right_box = VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(112, 0)
	right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right_box)

	_system_battle_right_flag = TextureRect.new()
	_system_battle_right_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_system_battle_right_flag.custom_minimum_size = SYSTEM_BATTLE_FLAG_SIZE
	_system_battle_right_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_box.add_child(_system_battle_right_flag)

	_system_battle_right_name = Label.new()
	_system_battle_right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_right_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_system_battle_right_name.add_theme_font_size_override("font_size", 14)
	right_box.add_child(_system_battle_right_name)

	_system_battle_right_strength_label = Label.new()
	_system_battle_right_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_battle_right_strength_label.add_theme_font_size_override("font_size", 22)
	_system_battle_right_strength_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25, 1.0))
	right_box.add_child(_system_battle_right_strength_label)

func _ensure_system_message_meta_row() -> void:
	if _system_message_meta_row != null:
		return
	if system_message_text == null or system_message_text.get_parent() == null:
		return

	var vbox = system_message_text.get_parent() as VBoxContainer
	if vbox == null:
		return

	_system_message_meta_row = HBoxContainer.new()
	_system_message_meta_row.name = "MessageMetaRow"
	_system_message_meta_row.visible = false
	_system_message_meta_row.custom_minimum_size = Vector2(0.0, SYSTEM_MESSAGE_META_ROW_HEIGHT)
	_system_message_meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_system_message_meta_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_system_message_meta_row)
	if system_message_title:
		vbox.move_child(_system_message_meta_row, system_message_title.get_index() + 1)

	_system_message_meta_left_flag = TextureButton.new()
	_system_message_meta_left_flag.custom_minimum_size = Vector2(30, 20)
	_system_message_meta_left_flag.ignore_texture_size = true
	_system_message_meta_left_flag.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_system_message_meta_left_flag.focus_mode = Control.FOCUS_NONE
	_system_message_meta_left_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_system_message_meta_left_flag.pressed.connect(_on_system_message_meta_flag_pressed.bind(true))
	_system_message_meta_row.add_child(_system_message_meta_left_flag)

	_system_message_meta_center_label = Label.new()
	_system_message_meta_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_system_message_meta_center_label.add_theme_font_size_override("font_size", 13)
	_system_message_meta_center_label.add_theme_color_override("font_color", Color(0.84, 0.91, 1.0, 0.97))
	_system_message_meta_center_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.10, 0.85))
	_system_message_meta_center_label.add_theme_constant_override("outline_size", 1)
	_system_message_meta_center_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_message_meta_row.add_child(_system_message_meta_center_label)

	_system_message_meta_right_flag = TextureButton.new()
	_system_message_meta_right_flag.custom_minimum_size = Vector2(30, 20)
	_system_message_meta_right_flag.ignore_texture_size = true
	_system_message_meta_right_flag.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_system_message_meta_right_flag.focus_mode = Control.FOCUS_NONE
	_system_message_meta_right_flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_system_message_meta_right_flag.pressed.connect(_on_system_message_meta_flag_pressed.bind(false))
	_system_message_meta_row.add_child(_system_message_meta_right_flag)

func _ensure_system_batch_panel() -> void:
	if _system_batch_panel != null:
		return
	if system_message_text == null or system_message_text.get_parent() == null:
		return
	var vbox = system_message_text.get_parent() as VBoxContainer
	if vbox == null:
		return
	_system_batch_panel = ScrollContainer.new()
	_system_batch_panel.name = "BatchReportPanel"
	_system_batch_panel.visible = false
	_system_batch_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_system_batch_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_system_batch_panel)
	vbox.move_child(_system_batch_panel, system_message_text.get_index())
	_system_batch_list = VBoxContainer.new()
	_system_batch_list.name = "BatchReportList"
	_system_batch_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_batch_list.add_theme_constant_override("separation", 0)
	_system_batch_panel.add_child(_system_batch_list)

func _nastav_system_batch_items(items: Array) -> void:
	_ensure_system_batch_panel()
	if _system_batch_panel == null or _system_batch_list == null:
		return
	for ch in _system_batch_list.get_children():
		ch.queue_free()
	if items.is_empty():
		_system_batch_panel.hide()
		return
	var row_count := 0
	for item_any in items:
		var item = item_any as Dictionary
		var t = str(item.get("title", "Report")).strip_edges()
		var msg = str(item.get("text", "")).strip_edges()
		var item_tags = item.get("state_tags", []) as Array
		var tags = _ziskej_tagy_systemove_zpravy(t, msg, {}, item_tags)
		var left_tag = str(tags[0]).strip_edges().to_upper() if tags.size() >= 1 else ""
		var right_tag = str(tags[1]).strip_edges().to_upper() if tags.size() >= 2 else ""
		if right_tag == left_tag:
			right_tag = ""
		var polished_text = _zpolish_system_message_text(_nahrad_tagy_nazvy_ve_zprave(msg))
		var polished_title = _zpolish_system_message_title(_nahrad_tagy_nazvy_ve_zprave(t))
		var display_text = polished_text if polished_text.strip_edges() != "" else polished_title
		if row_count > 0:
			var sep = HSeparator.new()
			sep.modulate = Color(1.0, 1.0, 1.0, 0.10)
			_system_batch_list.add_child(sep)
		row_count += 1
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_system_batch_list.add_child(row)
		var lf_btn = TextureButton.new()
		lf_btn.custom_minimum_size = SYSTEM_BATCH_FLAG_SIZE
		lf_btn.ignore_texture_size = true
		lf_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		lf_btn.focus_mode = Control.FOCUS_NONE
		if left_tag != "":
			lf_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var ltex = _resolve_flag_texture(left_tag, _ziskej_aktualni_ideologii_statu(left_tag))
			lf_btn.texture_normal = ltex
			lf_btn.texture_hover = ltex
			lf_btn.texture_pressed = ltex
			lf_btn.tooltip_text = _ziskej_jmeno_statu_podle_tagu(left_tag)
			lf_btn.pressed.connect(_posun_kameru_na_stat.bind(left_tag, true))
		else:
			lf_btn.modulate.a = 0.0
		row.add_child(lf_btn)
		var center_lbl = Label.new()
		center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		center_lbl.add_theme_font_size_override("font_size", 13)
		center_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.98))
		center_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.85))
		center_lbl.add_theme_constant_override("outline_size", 1)
		center_lbl.text = display_text
		row.add_child(center_lbl)
		var rf_btn = TextureButton.new()
		rf_btn.custom_minimum_size = SYSTEM_BATCH_FLAG_SIZE
		rf_btn.ignore_texture_size = true
		rf_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		rf_btn.focus_mode = Control.FOCUS_NONE
		if right_tag != "":
			rf_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var rtex = _resolve_flag_texture(right_tag, _ziskej_aktualni_ideologii_statu(right_tag))
			rf_btn.texture_normal = rtex
			rf_btn.texture_hover = rtex
			rf_btn.texture_pressed = rtex
			rf_btn.tooltip_text = _ziskej_jmeno_statu_podle_tagu(right_tag)
			rf_btn.pressed.connect(_posun_kameru_na_stat.bind(right_tag, true))
		else:
			rf_btn.modulate.a = 0.0
		row.add_child(rf_btn)
	var panel_h = clampf(float(items.size()) * 34.0 + 4.0, 34.0, SYSTEM_BATCH_MAX_VISIBLE_HEIGHT)
	_system_batch_panel.custom_minimum_size = Vector2(0.0, panel_h)
	_system_batch_panel.show()

func _ziskej_tagy_systemove_zpravy(title_raw: String, text_raw: String, battle_payload: Dictionary, explicit_tags: Array = []) -> Array:
	var tags: Array = []
	var seen: Dictionary = {}

	for raw_tag in explicit_tags:
		var explicit_tag = str(raw_tag).strip_edges().to_upper()
		if explicit_tag == "" or explicit_tag == "SEA" or seen.has(explicit_tag):
			continue
		seen[explicit_tag] = true
		tags.append(explicit_tag)

	if not battle_payload.is_empty():
		var bt_left = str(battle_payload.get("left_tag", "")).strip_edges().to_upper()
		if bt_left != "" and bt_left != "SEA" and not seen.has(bt_left):
			seen[bt_left] = true
			tags.append(bt_left)
		var bt_right = str(battle_payload.get("right_tag", "")).strip_edges().to_upper()
		if bt_right != "" and bt_right != "SEA" and not seen.has(bt_right):
			seen[bt_right] = true
			tags.append(bt_right)

	var merged_raw = (title_raw + " " + text_raw).strip_edges()
	for t_any in _vyhledat_tagy_statu_v_textu(merged_raw):
		var tag = str(t_any).strip_edges().to_upper()
		if tag == "" or tag == "SEA" or seen.has(tag):
			continue
		seen[tag] = true
		tags.append(tag)
	if tags.size() < 2:
		for t_any in _vyhledat_tagy_statu_podle_nazvu(merged_raw):
			var tag2 = str(t_any).strip_edges().to_upper()
			if tag2 == "" or tag2 == "SEA" or seen.has(tag2):
				continue
			seen[tag2] = true
			tags.append(tag2)

	if tags.size() > 2:
		return [str(tags[0]), str(tags[1])]
	return tags

func _nastav_system_message_meta_row(tags: Array) -> void:
	_ensure_system_message_meta_row()
	if _system_message_meta_row == null:
		return

	if tags.is_empty() or _system_message_compact_battle:
		_system_message_meta_row.hide()
		return

	var left_tag = str(tags[0]).strip_edges().to_upper()
	var right_tag = str(tags[1]).strip_edges().to_upper() if tags.size() >= 2 else ""
	var left_name = _ziskej_jmeno_statu_podle_tagu(left_tag)
	var right_name = _ziskej_jmeno_statu_podle_tagu(right_tag)

	var left_tex = _resolve_flag_texture(left_tag, _ziskej_aktualni_ideologii_statu(left_tag)) if left_tag != "" else null
	var right_tex = _resolve_flag_texture(right_tag, _ziskej_aktualni_ideologii_statu(right_tag)) if right_tag != "" else null

	if _system_message_meta_left_flag:
		_system_message_meta_left_flag.texture_normal = left_tex
		_system_message_meta_left_flag.texture_hover = left_tex
		_system_message_meta_left_flag.texture_pressed = left_tex
		_system_message_meta_left_flag.visible = left_tex != null
		_system_message_meta_left_flag.set_meta("state_tag", left_tag)
		_system_message_meta_left_flag.tooltip_text = left_name

	if _system_message_meta_right_flag:
		_system_message_meta_right_flag.texture_normal = right_tex
		_system_message_meta_right_flag.texture_hover = right_tex
		_system_message_meta_right_flag.texture_pressed = right_tex
		_system_message_meta_right_flag.visible = right_tex != null
		_system_message_meta_right_flag.set_meta("state_tag", right_tag)
		_system_message_meta_right_flag.tooltip_text = right_name

	if _system_message_meta_center_label:
		if right_tag != "":
			_system_message_meta_center_label.text = "%s  vs  %s" % [left_name, right_name]
		else:
			_system_message_meta_center_label.text = left_name

	var has_any_flag = (left_tex != null) or (right_tex != null)
	_system_message_meta_row.visible = has_any_flag

func _on_system_message_meta_flag_pressed(is_left: bool) -> void:
	var target: TextureButton = _system_message_meta_left_flag if is_left else _system_message_meta_right_flag
	if target == null:
		return
	var state_tag = str(target.get_meta("state_tag", "")).strip_edges().to_upper()
	if state_tag == "":
		return
	_posun_kameru_na_stat(state_tag, true)

func _zpolish_system_message_title(title: String) -> String:
	var t = title.strip_edges()
	if t == "":
		return t
	if t == "WAR":
		return "War"
	if t == "ALLIANCE WAR":
		return "Alliance War"
	if t == "LOANS":
		return "Loans"
	return t

func _zpolish_system_message_text(text: String) -> String:
	var t = text.strip_edges()
	if t == "":
		return t

	if t.find(" | ") != -1 and t.find("\n") == -1:
		var parts = t.split(" | ", false, 1)
		if parts.size() == 2:
			var sides = parts[0].strip_edges()
			var event = parts[1].strip_edges()
			if event == "DECLARED WAR":
				var ab = sides.split(" -> ")
				if ab.size() == 2:
					return "%s declared war on %s." % [ab[0].strip_edges(), ab[1].strip_edges()]
			if event == "PEACE PROPOSAL":
				var ab2 = sides.split(" -> ")
				if ab2.size() == 2:
					return "%s sent a peace proposal to %s." % [ab2[0].strip_edges(), ab2[1].strip_edges()]
			if event == "NON-AGGRESSION PACT":
				var ab3 = sides.split(" <-> ")
				if ab3.size() == 2:
					return "%s and %s signed a non-aggression pact." % [ab3[0].strip_edges(), ab3[1].strip_edges()]
			if event.begins_with("CAPITAL OCCUPIED"):
				var ab4 = sides.split(" -> ")
				if ab4.size() == 2:
					return "%s occupied %s's capital. Hold it for one turn to trigger capitulation." % [ab4[0].strip_edges(), ab4[1].strip_edges()]
			if event == "CAPITAL RECAPTURED":
				return "%s recaptured the capital." % sides
			if event == "CAPITULATION TRIGGERED -> PEACE CONFERENCE":
				var ab5 = sides.split(" -> ")
				if ab5.size() == 2:
					return "%s capitulated to %s. The peace conference has started." % [ab5[1].strip_edges(), ab5[0].strip_edges()]
			return "%s\n%s" % [sides, event]

	return t

# Fill battle summary panel from payload and keep it hidden when payload is empty.
func _nastav_system_battle_panel(payload: Dictionary) -> void:
	_ensure_system_battle_panel()
	if _system_battle_panel == null:
		return
	if payload.is_empty():
		_system_battle_panel.hide()
		return

	var left_tag = str(payload.get("left_tag", "")).strip_edges().to_upper()
	var right_tag = str(payload.get("right_tag", "")).strip_edges().to_upper()
	var winner_tag = str(payload.get("winner_tag", "")).strip_edges().to_upper()
	var left_before = int(payload.get("left_before", 0))
	var left_after = int(payload.get("left_after", 0))
	var right_before = int(payload.get("right_before", 0))
	var right_after = int(payload.get("right_after", 0))
	var left_power = float(payload.get("left_power", -1.0))
	var right_power = float(payload.get("right_power", -1.0))
	var left_total_mult = float(payload.get("left_total_mult", -1.0))
	var right_total_mult = float(payload.get("right_total_mult", -1.0))
	var left_lab_mult = float(payload.get("left_lab_mult", -1.0))
	var right_lab_mult = float(payload.get("right_lab_mult", -1.0))

	var left_name = _ziskej_jmeno_statu_podle_tagu(left_tag)
	var right_name = _ziskej_jmeno_statu_podle_tagu(right_tag)
	var left_ideology = _ziskej_aktualni_ideologii_statu(left_tag)
	var right_ideology = _ziskej_aktualni_ideologii_statu(right_tag)
	_aplikuj_system_battle_barvy(left_tag, right_tag)

	if _system_battle_left_name:
		_system_battle_left_name.text = left_name
	if _system_battle_right_name:
		_system_battle_right_name.text = right_name
	if _system_battle_left_flag:
		_system_battle_left_flag.texture = _resolve_flag_texture(left_tag, left_ideology)
	if _system_battle_right_flag:
		_system_battle_right_flag.texture = _resolve_flag_texture(right_tag, right_ideology)

	var winner_name = "Draw"
	if winner_tag != "":
		winner_name = _ziskej_jmeno_statu_podle_tagu(winner_tag)
	if _system_battle_winner_label:
		if winner_tag == "":
			_system_battle_winner_label.text = "Battle ended in a draw"
		else:
			_system_battle_winner_label.text = "%s is Victorious!" % winner_name
		_system_battle_winner_label.modulate = Color(0.95, 0.97, 1.0, 1.0)

	# Advantage bar should show force ratio at battle start, not only survivors.
	var bar_left_strength = max(0, left_before)
	var bar_right_strength = max(0, right_before)
	if bar_left_strength <= 0 and bar_right_strength <= 0:
		bar_left_strength = max(0, left_after)
		bar_right_strength = max(0, right_after)
	var total = max(1, bar_left_strength + bar_right_strength)
	var left_share = float(bar_left_strength) / float(total)
	var bar_value = int(round(left_share * 100.0))
	if bar_left_strength > 0 and bar_right_strength > 0:
		# Keep a visible segment for both sides when both entered the battle.
		bar_value = clampi(bar_value, 5, 95)
	if _system_battle_adv_bar:
		_system_battle_adv_bar.value = bar_value

	var left_losses = max(0, left_before - left_after)
	var right_losses = max(0, right_before - right_after)
	if _system_battle_left_losses_label:
		_system_battle_left_losses_label.text = "-%s" % _formatuj_cislo(left_losses)
	if _system_battle_right_losses_label:
		_system_battle_right_losses_label.text = "-%s" % _formatuj_cislo(right_losses)
	if _system_battle_left_strength_label:
		_system_battle_left_strength_label.text = _formatuj_cislo(left_after)
	if _system_battle_right_strength_label:
		_system_battle_right_strength_label.text = _formatuj_cislo(right_after)

	var margin = abs(left_losses - right_losses)
	if _system_battle_margin_label:
		var ratio_suffix = ""
		if left_power > 0.0 and right_power > 0.0:
			var min_power = max(0.0001, min(left_power, right_power))
			var left_ratio = left_power / min_power
			var right_ratio = right_power / min_power
			var mult_text = ""
			if left_lab_mult > 0.0 and right_lab_mult > 0.0:
				mult_text = " | lab x%.2f vs x%.2f" % [left_lab_mult, right_lab_mult]
				if left_total_mult > 0.0 and right_total_mult > 0.0:
					mult_text += " (eff x%.2f vs x%.2f)" % [left_total_mult, right_total_mult]
			elif left_total_mult > 0.0 and right_total_mult > 0.0:
				mult_text = " | eff x%.2f vs x%.2f" % [left_total_mult, right_total_mult]
			ratio_suffix = " | power %.2f:%.2f%s" % [left_ratio, right_ratio, mult_text]
		if winner_tag == "":
			_system_battle_margin_label.text = "Losses were equal%s" % ratio_suffix
		elif winner_tag == left_tag:
			_system_battle_margin_label.text = "%s inflicted +%s more losses%s" % [left_name, _formatuj_cislo(margin), ratio_suffix]
		else:
			_system_battle_margin_label.text = "%s inflicted +%s more losses%s" % [right_name, _formatuj_cislo(margin), ratio_suffix]

	_system_battle_panel.show()

func obnov_layout_ui() -> void:
	_aktualizuj_overview_panel_layout()
	_pozicuj_ai_debug_panel()
	_aktualizuj_pozice_popupu()

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

# Returns current runtime data.
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

func _zajisti_tlacitko_obchodu() -> void:
	trade_btn = get_node_or_null("OverviewPanel/VBoxContainer/TradeButton") as Button
	if trade_btn:
		return
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	trade_btn = Button.new()
	trade_btn.name = "TradeButton"
	trade_btn.text = "Trade"
	trade_btn.focus_mode = Control.FOCUS_NONE
	trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_btn.hide()
	_aplikuj_overview_tlacitko_vzhled(trade_btn)
	vbox.add_child(trade_btn)
	if gift_money_btn and gift_money_btn.get_parent() == vbox:
		vbox.move_child(trade_btn, gift_money_btn.get_index() + 1)

# Runs the local feature logic.
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
	_vassals_btn.focus_mode = Control.FOCUS_NONE
	_vassals_btn.hide()
	vbox.add_child(_vassals_btn)
	if action_separator and action_separator.get_parent() == vbox:
		vbox.move_child(_vassals_btn, action_separator.get_index() + 1)

# Runs the local feature logic.
func _zajisti_tlacitko_vojenskeho_pristupu() -> void:
	_military_access_btn = get_node_or_null("OverviewPanel/VBoxContainer/MilitaryAccessButton") as Button
	if _military_access_btn:
		return
	var vbox = get_node_or_null("OverviewPanel/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	_military_access_btn = Button.new()
	_military_access_btn.name = "MilitaryAccessButton"
	_military_access_btn.text = "Request military access"
	_military_access_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_military_access_btn.hide()
	_aplikuj_overview_tlacitko_vzhled(_military_access_btn)
	vbox.add_child(_military_access_btn)
	# Place it after non_aggression_btn if present, else at end
	if non_aggression_btn and non_aggression_btn.get_parent() == vbox:
		vbox.move_child(_military_access_btn, non_aggression_btn.get_index() + 1)
	_military_access_btn.pressed.connect(_on_military_access_btn_pressed)

# Construct/setup block for required nodes.
func _vytvor_panel_vazalu() -> void:
	if _vassals_dialog != null:
		return

	_vassals_dialog = PopupPanel.new()
	_vassals_dialog.name = "VassalsDialog"
	_vassals_dialog.wrap_controls = false
	_vassals_dialog.unresizable = true
	_vassals_dialog.min_size = Vector2i(360, 280)
	_vassals_dialog.size = Vector2(438, 320)
	_vassals_dialog.exclusive = false
	_vassals_dialog.popup_window = false
	add_child(_vassals_dialog)
	_aplikuj_ingame_popup_styl(_vassals_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vassals_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title = Label.new()
	title.text = "My vassals"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var help_btn = TooltipUtilsScript.create_help_button("Set tribute and click Apply %.")
	help_btn.pressed.connect(func(): TooltipUtilsScript.show_help_dropdown(self, help_btn, "Set tribute and click Apply %."))
	header.add_child(help_btn)

	var close_top_btn = Button.new()
	close_top_btn.text = "Close"
	close_top_btn.custom_minimum_size = Vector2(72, 0)
	_aplikuj_ingame_tlacitko_styl(close_top_btn)
	close_top_btn.pressed.connect(func(): _vassals_dialog.hide())
	header.add_child(close_top_btn)

	var subtitle = Label.new()
	subtitle.text = "Manage tribute, open subject overview, or release vassals."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.81, 0.93, 0.95))
	root.add_child(subtitle)

	var separator = HSeparator.new()
	root.add_child(separator)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_vassals_list = VBoxContainer.new()
	_vassals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vassals_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_vassals_list)

	_vassals_dialog.hide()

# Runs the local feature logic.
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

	var base_w: float = 438.0
	var base_h: float = 320.0
	var extra_w: float = minf(120.0, float(count) * 8.0)
	var extra_h: float = minf(360.0, float(maxi(0, count - 1)) * 48.0)

	var max_w: float = maxf(280.0, vp.x - 24.0)
	var max_h: float = maxf(180.0, vp.y - 24.0)
	var w: float = clampf(base_w + extra_w, 360.0, max_w)
	var h: float = clampf(base_h + extra_h, 280.0, max_h)
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

# Triggered by a UI/game signal.
func _on_vassals_button_pressed() -> void:
	if _vassals_dialog == null:
		return
	if _vassals_dialog.visible:
		_vassals_dialog.hide()
		return
	_zavri_vyzkum_dialog()
	_obnov_panel_vazalu()
	_pozicuj_a_zmen_velikost_panelu_vazalu()
	_vassals_dialog.show()
	call_deferred("_pozicuj_a_zmen_velikost_panelu_vazalu")

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
		var empty_card = PanelContainer.new()
		empty_card.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.10, 0.14, 0.22, 0.90), Color(0.35, 0.47, 0.62, 0.55)))
		_vassals_list.add_child(empty_card)

		var empty_margin = MarginContainer.new()
		empty_margin.add_theme_constant_override("margin_left", 10)
		empty_margin.add_theme_constant_override("margin_top", 10)
		empty_margin.add_theme_constant_override("margin_right", 10)
		empty_margin.add_theme_constant_override("margin_bottom", 10)
		empty_card.add_child(empty_margin)

		var empty_label = Label.new()
		empty_label.text = "You currently have no active vassals."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.97, 0.9))
		empty_margin.add_child(empty_label)
		_pozicuj_a_zmen_velikost_panelu_vazalu(0)
		return

	for subject_any in vassals:
		var subject = str(subject_any).strip_edges().to_upper()
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.11, 0.16, 0.24, 0.94), Color(0.53, 0.70, 0.92, 0.58)))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vassals_list.add_child(card)

		var card_margin = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(card_margin)

		var card_v = VBoxContainer.new()
		card_v.add_theme_constant_override("separation", 7)
		card_margin.add_child(card_v)

		var top_row = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		card_v.add_child(top_row)

		var ideology = _ziskej_aktualni_ideologii_statu(subject)
		var flag = TextureRect.new()
		flag.custom_minimum_size = Vector2(26, 18)
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.texture = _resolve_flag_texture(subject, ideology)
		top_row.add_child(flag)

		var identity_col = VBoxContainer.new()
		identity_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity_col.add_theme_constant_override("separation", 1)
		top_row.add_child(identity_col)

		var name_lbl = Label.new()
		name_lbl.text = _ziskej_jmeno_statu_podle_tagu(subject)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
		name_lbl.tooltip_text = subject
		identity_col.add_child(name_lbl)

		var tag_lbl = Label.new()
		tag_lbl.text = subject
		tag_lbl.add_theme_font_size_override("font_size", 11)
		tag_lbl.add_theme_color_override("font_color", Color(0.67, 0.78, 0.92, 0.92))
		identity_col.add_child(tag_lbl)

		var action_row = HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 8)
		card_v.add_child(action_row)

		var focus_btn = Button.new()
		focus_btn.text = "Open"
		focus_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_aplikuj_ingame_tlacitko_styl(focus_btn)
		focus_btn.pressed.connect(_on_vassal_focus_pressed.bind(subject))
		action_row.add_child(focus_btn)

		var release_btn = Button.new()
		release_btn.text = "Release"
		release_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_aplikuj_ingame_tlacitko_styl(release_btn, true)
		release_btn.pressed.connect(_on_vassal_release_pressed.bind(subject))
		action_row.add_child(release_btn)

		var split = HSeparator.new()
		card_v.add_child(split)

		var tribute_row = HBoxContainer.new()
		tribute_row.add_theme_constant_override("separation", 8)
		card_v.add_child(tribute_row)

		var tribute_lbl = Label.new()
		tribute_lbl.text = "Tribute"
		tribute_lbl.add_theme_color_override("font_color", Color(0.87, 0.92, 0.98, 1.0))
		tribute_lbl.custom_minimum_size = Vector2(64, 0)
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
		pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct_label.add_theme_color_override("font_color", Color(0.83, 0.90, 0.98, 1.0))
		pct_label.custom_minimum_size = Vector2(44, 0)
		slider.value_changed.connect(func(v): pct_label.text = "%d%%" % int(round(v)))
		tribute_row.add_child(pct_label)

		var apply_btn = Button.new()
		apply_btn.text = "Apply %"
		_aplikuj_ingame_tlacitko_styl(apply_btn)
		apply_btn.pressed.connect(_on_vassal_tribute_apply_pressed.bind(subject, slider))
		tribute_row.add_child(apply_btn)

		var cooldown_left := 0
		if GameManager.has_method("ziskej_zbyvajici_cooldown_vazalskeho_odvodu"):
			cooldown_left = int(GameManager.ziskej_zbyvajici_cooldown_vazalskeho_odvodu(GameManager.hrac_stat, subject))
		if cooldown_left > 0:
			slider.editable = false
			apply_btn.disabled = true
			apply_btn.tooltip_text = "Tribute can be changed again in %d turn(s)." % cooldown_left
			var lock_lbl = Label.new()
			lock_lbl.text = "Tribute lock: %d turn(s) remaining" % cooldown_left
			lock_lbl.add_theme_font_size_override("font_size", 11)
			lock_lbl.add_theme_color_override("font_color", Color(0.96, 0.75, 0.52, 0.95))
			card_v.add_child(lock_lbl)

		if GameManager.has_method("ziskej_cisty_prijem_statu"):
			var est = 0.0
			if GameManager.has_method("ziskej_projektovany_vazalsky_odvod"):
				var tribute_info = GameManager.ziskej_projektovany_vazalsky_odvod(GameManager.hrac_stat, subject) as Dictionary
				est = float(tribute_info.get("paid", 0.0))
			else:
				var inc = float(GameManager.ziskej_cisty_prijem_statu(subject))
				est = max(0.0, inc) * (float(slider.value) / 100.0)
			var est_lbl = Label.new()
			est_lbl.text = "Projected tribute/turn: $%.2f" % est
			est_lbl.add_theme_font_size_override("font_size", 12)
			est_lbl.add_theme_color_override("font_color", Color(0.73, 0.96, 0.82, 0.95))
			slider.value_changed.connect(func(v):
				var est_now = 0.0
				if GameManager.has_method("ziskej_projektovany_vazalsky_odvod"):
					var preview_ok = false
					var preview_rate = 0.0
					if GameManager.has_method("ziskej_vazalsky_odvod"):
						preview_rate = float(GameManager.ziskej_vazalsky_odvod(GameManager.hrac_stat, subject)) * 100.0
					preview_ok = absf(float(v) - preview_rate) < 0.001
					if preview_ok:
						var tribute_info_now = GameManager.ziskej_projektovany_vazalsky_odvod(GameManager.hrac_stat, subject) as Dictionary
						est_now = float(tribute_info_now.get("paid", 0.0))
				if est_now <= 0.0:
					var inc_now = max(0.0, float(GameManager.ziskej_cisty_prijem_statu(subject)))
					est_now = inc_now * (float(v) / 100.0)
				est_lbl.text = "Projected tribute/turn: $%.2f" % est_now
			)
			card_v.add_child(est_lbl)

	_pozicuj_a_zmen_velikost_panelu_vazalu(vassals.size())

func _on_vassal_tribute_apply_pressed(subject_tag: String, slider: HSlider) -> void:
	if slider == null or not GameManager.has_method("nastav_vazalsky_odvod"):
		return
	if GameManager.has_method("ziskej_zbyvajici_cooldown_vazalskeho_odvodu"):
		var cooldown_left = int(GameManager.ziskej_zbyvajici_cooldown_vazalskeho_odvodu(GameManager.hrac_stat, subject_tag))
		if cooldown_left > 0:
			zobraz_systemove_hlaseni("Vassal Tribute", "You can change tribute for %s again in %d turn(s)." % [subject_tag, cooldown_left])
			return
	var ok = bool(GameManager.nastav_vazalsky_odvod(GameManager.hrac_stat, subject_tag, float(slider.value)))
	if ok:
		_aktualizuj_mirove_overview_statistiky(str(GameManager.hrac_stat).strip_edges().to_upper(), true)
		_obnov_panel_vazalu()
	else:
		zobraz_systemove_hlaseni("Vassal Tribute", "Tribute change failed.")

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

# Refresh pass for current state.
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

# Core flow for this feature.
func _zajisti_ai_debug_overview_labely() -> void:
	ai_debug_panel = get_node_or_null("AIDebugPanel") as PanelContainer
	if ai_debug_panel == null:
		ai_debug_panel = PanelContainer.new()
		ai_debug_panel.name = "AIDebugPanel"
		ai_debug_panel.anchor_left = 1.0
		ai_debug_panel.anchor_top = 0.0
		ai_debug_panel.anchor_right = 1.0
		ai_debug_panel.anchor_bottom = 0.0
		ai_debug_panel.custom_minimum_size = Vector2(420.0, 420.0)

		if panel:
			var source_style = panel.get_theme_stylebox("panel")
			if source_style:
				ai_debug_panel.add_theme_stylebox_override("panel", source_style.duplicate())

		var root := VBoxContainer.new()
		root.name = "RootVBox"
		root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ai_debug_panel.add_child(root)

		_ai_debug_header = HBoxContainer.new()
		_ai_debug_header.name = "Header"
		root.add_child(_ai_debug_header)

		_ai_debug_title_label = Label.new()
		_ai_debug_title_label.name = "Title"
		_ai_debug_title_label.text = "Debug"
		_ai_debug_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ai_debug_header.add_child(_ai_debug_title_label)

		_ai_debug_min_btn = Button.new()
		_ai_debug_min_btn.name = "MinButton"
		_ai_debug_min_btn.text = "-"
		_ai_debug_min_btn.custom_minimum_size = Vector2(32, 28)
		if not _ai_debug_min_btn.pressed.is_connected(_on_ai_debug_min_pressed):
			_ai_debug_min_btn.pressed.connect(_on_ai_debug_min_pressed)
		_ai_debug_header.add_child(_ai_debug_min_btn)

		_ai_debug_max_btn = Button.new()
		_ai_debug_max_btn.name = "MaxButton"
		_ai_debug_max_btn.text = "+"
		_ai_debug_max_btn.custom_minimum_size = Vector2(32, 28)
		if not _ai_debug_max_btn.pressed.is_connected(_on_ai_debug_max_pressed):
			_ai_debug_max_btn.pressed.connect(_on_ai_debug_max_pressed)
		_ai_debug_header.add_child(_ai_debug_max_btn)

		_ai_debug_filter_row = HBoxContainer.new()
		_ai_debug_filter_row.name = "FilterRow"
		root.add_child(_ai_debug_filter_row)

		_ai_debug_filter_all_btn = Button.new()
		_ai_debug_filter_all_btn.name = "FilterAllButton"
		_ai_debug_filter_all_btn.text = "Vse"
		if not _ai_debug_filter_all_btn.pressed.is_connected(_on_ai_debug_filter_all_pressed):
			_ai_debug_filter_all_btn.pressed.connect(_on_ai_debug_filter_all_pressed)
		_ai_debug_filter_row.add_child(_ai_debug_filter_all_btn)

		_ai_debug_filter_mine_btn = Button.new()
		_ai_debug_filter_mine_btn.name = "FilterMineButton"
		_ai_debug_filter_mine_btn.text = "Moje"
		if not _ai_debug_filter_mine_btn.pressed.is_connected(_on_ai_debug_filter_mine_pressed):
			_ai_debug_filter_mine_btn.pressed.connect(_on_ai_debug_filter_mine_pressed)
		_ai_debug_filter_row.add_child(_ai_debug_filter_mine_btn)

		_ai_debug_filter_other_btn = Button.new()
		_ai_debug_filter_other_btn.name = "FilterOtherButton"
		_ai_debug_filter_other_btn.text = "Ostatni"
		if not _ai_debug_filter_other_btn.pressed.is_connected(_on_ai_debug_filter_other_pressed):
			_ai_debug_filter_other_btn.pressed.connect(_on_ai_debug_filter_other_pressed)
		_ai_debug_filter_row.add_child(_ai_debug_filter_other_btn)

		_ai_debug_mode_option = OptionButton.new()
		_ai_debug_mode_option.name = "ModeOption"
		_ai_debug_mode_option.custom_minimum_size = Vector2(170, 0)
		_ai_debug_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ai_debug_filter_row.add_child(_ai_debug_mode_option)
		_zajisti_ai_debug_mode_dropdown()

		var margin := MarginContainer.new()
		margin.name = "BodyMargin"
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(margin)

		ai_debug_label = RichTextLabel.new()
		ai_debug_label.name = "AIDebugLabel"
		ai_debug_label.bbcode_enabled = true
		ai_debug_label.scroll_active = true
		ai_debug_label.fit_content = false
		ai_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ai_debug_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ai_debug_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ai_debug_label.custom_minimum_size = Vector2(0, 392)
		margin.add_child(ai_debug_label)

		add_child(ai_debug_panel)
	else:
		ai_debug_label = ai_debug_panel.get_node_or_null("RootVBox/BodyMargin/AIDebugLabel") as RichTextLabel
		_ai_debug_header = ai_debug_panel.get_node_or_null("RootVBox/Header") as HBoxContainer
		_ai_debug_title_label = ai_debug_panel.get_node_or_null("RootVBox/Header/Title") as Label
		_ai_debug_min_btn = ai_debug_panel.get_node_or_null("RootVBox/Header/MinButton") as Button
		_ai_debug_max_btn = ai_debug_panel.get_node_or_null("RootVBox/Header/MaxButton") as Button
		_ai_debug_filter_row = ai_debug_panel.get_node_or_null("RootVBox/FilterRow") as HBoxContainer
		_ai_debug_filter_all_btn = ai_debug_panel.get_node_or_null("RootVBox/FilterRow/FilterAllButton") as Button
		_ai_debug_filter_mine_btn = ai_debug_panel.get_node_or_null("RootVBox/FilterRow/FilterMineButton") as Button
		_ai_debug_filter_other_btn = ai_debug_panel.get_node_or_null("RootVBox/FilterRow/FilterOtherButton") as Button
		_ai_debug_mode_option = ai_debug_panel.get_node_or_null("RootVBox/FilterRow/ModeOption") as OptionButton
		_zajisti_ai_debug_mode_dropdown()

	_pozicuj_ai_debug_panel()
	_aktualizuj_ai_debug_filter_tlacitka()
	ai_debug_panel.hide()

func _pozicuj_ai_debug_panel() -> void:
	if ai_debug_panel == null or not is_instance_valid(ai_debug_panel):
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var side_margin := 8.0
	var top_margin := 8.0
	var y_pos := top_margin

	var topbar_panel = get_tree().current_scene.get_node_or_null("TopBar/Panel") as Control
	if topbar_panel:
		y_pos = topbar_panel.global_position.y + topbar_panel.size.y + top_margin

	var available_height = max(260.0, viewport_size.y - y_pos - top_margin)
	var max_width = max(300.0, min(900.0, viewport_size.x - side_margin * 2.0))
	var width_ratio = 0.50 if _ai_debug_expanded else 0.34
	var height_ratio = 0.88 if _ai_debug_expanded else 0.72
	var width = clamp(viewport_size.x * width_ratio, 300.0, max_width)
	var height = 46.0 if _ai_debug_collapsed else clamp(viewport_size.y * height_ratio, 260.0, available_height)
	ai_debug_panel.custom_minimum_size = Vector2(width, height)
	if _ai_debug_title_label:
		_ai_debug_title_label.text = "Debug Panel"
	if _ai_debug_min_btn:
		_ai_debug_min_btn.text = "+" if _ai_debug_collapsed else "-"
	if _ai_debug_max_btn:
		_ai_debug_max_btn.text = "[]" if not _ai_debug_expanded else "<>"
	if ai_debug_label:
		ai_debug_label.visible = not _ai_debug_collapsed
		ai_debug_label.custom_minimum_size = Vector2(0, max(220.0, height - 92.0))
	ai_debug_panel.offset_left = -width - side_margin
	ai_debug_panel.offset_top = y_pos
	ai_debug_panel.offset_right = -side_margin
	ai_debug_panel.offset_bottom = y_pos + height

# Handles this signal callback.
func _on_ai_debug_min_pressed() -> void:
	_ai_debug_collapsed = not _ai_debug_collapsed
	_pozicuj_ai_debug_panel()

func _on_ai_debug_max_pressed() -> void:
	_ai_debug_expanded = not _ai_debug_expanded
	if _ai_debug_expanded:
		_ai_debug_collapsed = false
	_pozicuj_ai_debug_panel()

func _nastav_ai_debug_filter_mode(mode: int) -> void:
	_ai_debug_filter_mode = clampi(mode, 0, 2)
	_aktualizuj_ai_debug_filter_tlacitka()
	var target_tag = _vyres_debug_panel_tag(current_viewed_tag)
	if target_tag != "":
		_aktualizuj_ai_debug_overview(target_tag, _je_hracuv_tag(target_tag))
	else:
		ai_debug_panel.hide()

func _zajisti_ai_debug_mode_dropdown() -> void:
	if _ai_debug_filter_row == null:
		return
	if _ai_debug_mode_option == null:
		_ai_debug_mode_option = _ai_debug_filter_row.get_node_or_null("ModeOption") as OptionButton
	if _ai_debug_mode_option == null:
		_ai_debug_mode_option = OptionButton.new()
		_ai_debug_mode_option.name = "ModeOption"
		_ai_debug_mode_option.custom_minimum_size = Vector2(170, 0)
		_ai_debug_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ai_debug_filter_row.add_child(_ai_debug_mode_option)
	_ai_debug_mode_option.clear()
	_ai_debug_mode_option.add_item("All", AI_DEBUG_SECTION_ALL)
	_ai_debug_mode_option.add_item("AI", AI_DEBUG_SECTION_AI)
	_ai_debug_mode_option.add_item("Latency", AI_DEBUG_SECTION_LATENCY)
	_ai_debug_mode_option.add_item("Economy", AI_DEBUG_SECTION_ECONOMY)
	_ai_debug_mode_option.add_item("Diplomacy", AI_DEBUG_SECTION_DIPLOMACY)
	_ai_debug_mode_option.add_item("Turn pipeline", AI_DEBUG_SECTION_TURN_PIPELINE)
	var selected_idx := 0
	for i in range(_ai_debug_mode_option.item_count):
		if _ai_debug_mode_option.get_item_id(i) == _ai_debug_section_mode:
			selected_idx = i
			break
	_ai_debug_mode_option.select(selected_idx)
	if not _ai_debug_mode_option.item_selected.is_connected(_on_ai_debug_mode_selected):
		_ai_debug_mode_option.item_selected.connect(_on_ai_debug_mode_selected)

func _on_ai_debug_mode_selected(index: int) -> void:
	if _ai_debug_mode_option == null:
		return
	_nastav_ai_debug_sekci_mode(_ai_debug_mode_option.get_item_id(index))

func _nastav_ai_debug_sekci_mode(mode: int) -> void:
	_ai_debug_section_mode = clampi(mode, AI_DEBUG_SECTION_ALL, AI_DEBUG_SECTION_TURN_PIPELINE)
	if _ai_debug_mode_option:
		for i in range(_ai_debug_mode_option.item_count):
			if _ai_debug_mode_option.get_item_id(i) == _ai_debug_section_mode:
				_ai_debug_mode_option.select(i)
				break
	var target_tag = _vyres_debug_panel_tag(current_viewed_tag)
	if target_tag != "":
		_aktualizuj_ai_debug_overview(target_tag, _je_hracuv_tag(target_tag))

func _ziskej_ai_debug_nazev_sekce(mode: int) -> String:
	match mode:
		AI_DEBUG_SECTION_AI:
			return "AI"
		AI_DEBUG_SECTION_LATENCY:
			return "Latency"
		AI_DEBUG_SECTION_ECONOMY:
			return "Economy"
		AI_DEBUG_SECTION_DIPLOMACY:
			return "Diplomacy"
		AI_DEBUG_SECTION_TURN_PIPELINE:
			return "Turn pipeline"
		_:
			return "All"

func _ziskej_ai_debug_nazev_filtru() -> String:
	match _ai_debug_filter_mode:
		1:
			return "Moje"
		2:
			return "Ostatni"
		_:
			return "Vse"

func _debug_append_ai_lines(lines: Array[String], snap: Dictionary, enemies_text: String, goal_target_text: String, plan_target_text: String, recruit_targets: Array) -> void:
	var enemies = snap.get("enemies", []) as Array
	lines.append("[b]AI diagnostics[/b]")
	lines.append("Treasury: %s | Net income: %s/turn" % [
		_format_money_auto(float(snap.get("treasury", 0.0)), 2),
		_format_money_auto(float(snap.get("net_income", 0.0)), 2)
	])
	lines.append("Pressure: %.1f | Exhaustion: %.0f%% | Provinces: %d" % [
		float(snap.get("pressure", 0.0)),
		float(snap.get("exhaustion", 0.0)) * 100.0,
		int(snap.get("owned_provinces", 0))
	])
	lines.append("At war: %s | Enemies (%d): %s" % [
		"yes" if bool(snap.get("at_war", false)) else "no",
		enemies.size(),
		enemies_text
	])
	lines.append("Goal: %s -> %s" % [str(snap.get("goal_type", "none")), goal_target_text])
	lines.append("Plan: %s -> %s" % [str(snap.get("plan_phase", "staging")), plan_target_text])
	lines.append("Profile: aggr %.2f | atk %.2f | def %.2f | recruit targets %d" % [
		float(snap.get("aggression", 0.5)),
		float(snap.get("attack_bias", 0.5)),
		float(snap.get("defense_bias", 0.5)),
		recruit_targets.size()
	])

func _debug_append_latency_lines(lines: Array[String], turn_last_text: String, turn_avg_text: String, turn_recent_text: String, turn_history: Array, snap: Dictionary) -> void:
	lines.append("[b]Latency diagnostics[/b]")
	lines.append("Turn state: %s | loading overlay: %s" % [
		"processing" if _turn_loading_active else "idle",
		"visible" if (_turn_loading_overlay and _turn_loading_overlay.visible) else "hidden"
	])
	lines.append("Turn response: last %s | avg %s | samples %d" % [turn_last_text, turn_avg_text, _debug_turn_samples])
	lines.append("Turn response (recent %d): %s" % [_debug_turn_recent_ms.size(), turn_recent_text])
	if turn_history.is_empty():
		lines.append("No completed turn profiles yet.")
		return
	var totals: Array = []
	for entry_any in turn_history:
		var entry = entry_any as Dictionary
		totals.append(int(entry.get("total_ms", 0)))
	var totals_stats = _spocitej_turn_debug_statistiky(totals)
	lines.append("History totals (%d): avg %d | min %d | max %d | p95 %d ms" % [
		totals.size(),
		int(totals_stats.get("avg", 0)),
		int(totals_stats.get("min", 0)),
		int(totals_stats.get("max", 0)),
		int(totals_stats.get("p95", 0))
	])
	var ai_profile = snap.get("ai_profile", {}) as Dictionary
	if ai_profile.is_empty():
		lines.append("AI latency profile: no AI turn data yet.")
		return
	var ai_phases = ai_profile.get("phases", {}) as Dictionary
	lines.append("AI total: %d ms | setup %d | dip %d | econ %d | move %d | clean %d" % [
		int(ai_profile.get("total_ms", 0)),
		int(ai_phases.get("setup", 0)),
		int(ai_phases.get("diplomacy", 0)),
		int(ai_phases.get("economy_recruit", 0)),
		int(ai_phases.get("movement", 0)),
		int(ai_phases.get("cleanup", 0))
	])
	lines.append("AI states: processed %d/%d | passive tick %d" % [
		int(ai_profile.get("states_processed", 0)),
		int(ai_profile.get("states_total", 0)),
		int(ai_profile.get("states_passive", 0))
	])
	var dip = ai_profile.get("diplomacy", {}) as Dictionary
	if not dip.is_empty():
		lines.append("AI diplomacy ms: peace %d | non-agg %d | relation %d | leave alliance %d | alliance %d | potato_skip=%s" % [
			int(dip.get("peace_eval_ms", 0)),
			int(dip.get("non_aggression_ms", 0)),
			int(dip.get("relation_ms", 0)),
			int(dip.get("leave_alliance_ms", 0)),
			int(dip.get("alliance_ms", 0)),
			"yes" if bool(dip.get("skipped_potato", false)) else "no"
		])
	var econ = ai_profile.get("economy", {}) as Dictionary
	if not econ.is_empty():
		lines.append("AI economy ms: income %d | prep %d | recruit %d | post %d | war-light %d" % [
			int(econ.get("income_ms", 0)),
			int(econ.get("prep_ms", 0)),
			int(econ.get("recruit_ms", 0)),
			int(econ.get("post_ms", 0)),
			int(econ.get("war_light_states", 0))
		])
		var econ_states = econ.get("top_states", []) as Array
		if not econ_states.is_empty():
			lines.append("Slowest AI states in economy:")
			var econ_cap = min(5, econ_states.size())
			for i in range(econ_cap):
				var row = econ_states[i] as Dictionary
				lines.append("  - %s total %d ms (income %d | prep %d | recruit %d | post %d)" % [
					str(row.get("state", "?")),
					int(row.get("total_ms", 0)),
					int(row.get("income_ms", 0)),
					int(row.get("prep_ms", 0)),
					int(row.get("recruit_ms", 0)),
					int(row.get("post_ms", 0))
				])
	var move = ai_profile.get("movement", {}) as Dictionary
	if not move.is_empty():
		lines.append("AI movement ms: total %d | non-attack %d | core defense %d | offense %d | war-eval %d (%d) | declare %d (%d) | moves %d" % [
			int(move.get("total_ms", 0)),
			int(move.get("non_attack_ms", 0)),
			int(move.get("core_defense_ms", 0)),
			int(move.get("offense_ms", 0)),
			int(move.get("war_eval_ms", 0)),
			int(move.get("war_eval_count", 0)),
			int(move.get("war_declare_ms", 0)),
			int(move.get("war_declare_count", 0)),
			int(move.get("moves_registered", 0))
		])
		var move_states = move.get("state_rows", []) as Array
		if not move_states.is_empty():
			lines.append("Slowest AI states in movement:")
			var move_cap = min(5, move_states.size())
			for i in range(move_cap):
				var row = move_states[i] as Dictionary
				lines.append("  - %s total %d ms (orders %d | offense %d | phase %s | target %s)" % [
					str(row.get("state", "?")),
					int(row.get("total_ms", 0)),
					int(row.get("orders", 0)),
					int(row.get("offense_orders", 0)),
					str(row.get("phase", "-")),
					str(row.get("target", "-"))
				])

func _debug_append_economy_lines(lines: Array[String], snap: Dictionary, turn_history: Array) -> void:
	lines.append("[b]Economy diagnostics[/b]")
	lines.append("Treasury: %s | Profit income: %s/turn" % [
		_format_money_auto(float(snap.get("treasury", 0.0)), 2),
		_format_money_auto(float(snap.get("profit_income", 0.0)), 2)
	])
	lines.append("Spend: recruit %s | lab %s | build %s | other %s | total %s" % [
		_format_money_auto(float(snap.get("spend_recruit", 0.0)), 2),
		_format_money_auto(float(snap.get("spend_lab", 0.0)), 2),
		_format_money_auto(float(snap.get("spend_build", 0.0)), 2),
		_format_money_auto(float(snap.get("spend_other", 0.0)), 2),
		_format_money_auto(float(snap.get("spend_total", 0.0)), 2)
	])
	if turn_history.is_empty():
		lines.append("No turn history available for economy events.")
		return
	var last_entry = turn_history[turn_history.size() - 1] as Dictionary
	var last_events = last_entry.get("events", []) as Array
	var shown := 0
	for event_any in last_events:
		var event_text = str(event_any).strip_edges()
		if event_text == "":
			continue
		if not (event_text.contains("income_event") or event_text.contains("expense ") or event_text.contains("delta=")):
			continue
		if shown == 0:
			lines.append("Recent money events (last turn):")
		lines.append("  - %s" % event_text)
		shown += 1
		if shown >= 10:
			break
	if shown == 0:
		lines.append("Recent money events (last turn): none")

func _debug_append_diplomacy_lines(lines: Array[String], resolved_tag: String, pair_war_text: String) -> void:
	lines.append("[b]Diplomacy diagnostics[/b]")
	lines.append("Player vs viewed country at war: %s" % pair_war_text)
	var active_wars := 0
	if GameManager and GameManager.has_method("jsou_ve_valce"):
		var seen_war: Dictionary = {}
		for p_id in GameManager.map_data:
			var d = GameManager.map_data[p_id] as Dictionary
			var other = str(d.get("owner", "")).strip_edges().to_upper()
			if other == "" or other == "SEA" or other == resolved_tag:
				continue
			if seen_war.has(other):
				continue
			seen_war[other] = true
			if bool(GameManager.jsou_ve_valce(resolved_tag, other)):
				active_wars += 1
	lines.append("Viewed country active wars: %d" % active_wars)
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper() if GameManager else ""
	var queued_count := 0
	var queued_requests: Array = []
	if GameManager and player_tag != "" and GameManager.has_method("ziskej_pocet_cekajicich_diplomatickych_zadosti"):
		queued_count = int(GameManager.ziskej_pocet_cekajicich_diplomatickych_zadosti(player_tag))
	if GameManager and player_tag != "" and GameManager.has_method("ziskej_cekajici_diplomaticke_zadosti"):
		queued_requests = GameManager.ziskej_cekajici_diplomaticke_zadosti(player_tag) as Array
	lines.append("Pending diplomatic requests (player): %d" % queued_count)
	lines.append("Popup queue cards: %d | queue panel rows: %d" % [_diplomacy_queue_preview_cards.size(), _queue_preview_rows])
	lines.append("Request popup visible: %s" % ("yes" if (diplomacy_request_popup and diplomacy_request_popup.visible) else "no"))
	if not queued_requests.is_empty():
		lines.append("Top queued requests:")
		var to_show = min(5, queued_requests.size())
		for i in range(to_show):
			var req = queued_requests[i] as Dictionary
			var from_tag = str(req.get("from", "")).strip_edges().to_upper()
			var req_type = str(req.get("type", "unknown"))
			lines.append("  - %s -> %s" % [_ziskej_jmeno_statu_podle_tagu(from_tag), req_type])

func _debug_append_turn_pipeline_lines(lines: Array[String], turn_history: Array, snap: Dictionary) -> void:
	lines.append("[b]Turn pipeline[/b]")
	lines.append("Processing now: %s" % ("yes" if (GameManager and bool(GameManager.zpracovava_se_tah)) else "no"))
	if GameManager and "_queued_end_turn_requests" in GameManager:
		lines.append("Queued end-turn requests: %d" % int(GameManager._queued_end_turn_requests))
	if turn_history.is_empty():
		lines.append("No turn history yet.")
		return
	var latest = turn_history[turn_history.size() - 1] as Dictionary
	var phases = latest.get("phases", {}) as Dictionary
	lines.append("Latest turn %d total %d ms" % [int(latest.get("turn", -1)), int(latest.get("total_ms", 0))])
	lines.append("switch %d | armies %d | finance %d | growth %d | ai %d | popups %d | ui %d" % [
		int(phases.get("switch_player", 0)),
		int(phases.get("armies", 0)),
		int(phases.get("finance", 0)),
		int(phases.get("growth", 0)),
		int(phases.get("ai", 0)),
		int(phases.get("popups", 0)),
		int(phases.get("ui", 0))
	])
	var slow_phase := "none"
	var slow_ms := -1
	for key_any in phases.keys():
		var phase_key = str(key_any)
		var phase_ms = int(phases.get(phase_key, 0))
		if phase_ms > slow_ms:
			slow_ms = phase_ms
			slow_phase = phase_key
	lines.append("Slowest phase: %s (%d ms)" % [slow_phase, max(0, slow_ms)])
	var latest_events = latest.get("events", []) as Array
	if latest_events.is_empty():
		lines.append("Turn events: none")
	else:
		lines.append("Turn events (%d):" % latest_events.size())
		var cap = min(12, latest_events.size())
		for i in range(cap):
			lines.append("  - %s" % str(latest_events[i]))
	var profile = snap.get("turn_profile", {}) as Dictionary
	if not profile.is_empty():
		lines.append("Profile snapshot turn %d total %d ms" % [
			int(profile.get("turn", -1)),
			int(profile.get("total_ms", 0))
		])

# Refreshes cached/UI state.
func _aktualizuj_ai_debug_filter_tlacitka() -> void:
	if _ai_debug_filter_all_btn:
		_ai_debug_filter_all_btn.disabled = _ai_debug_filter_mode == 0
	if _ai_debug_filter_mine_btn:
		_ai_debug_filter_mine_btn.disabled = _ai_debug_filter_mode == 1
	if _ai_debug_filter_other_btn:
		_ai_debug_filter_other_btn.disabled = _ai_debug_filter_mode == 2

func _je_hracuv_tag(owner_tag: String) -> bool:
	var clean = owner_tag.strip_edges().to_upper()
	if clean == "":
		return false
	if GameManager == null:
		return false
	var local_states = GameManager.lokalni_hraci_staty if "lokalni_hraci_staty" in GameManager else []
	for raw_tag in local_states:
		if str(raw_tag).strip_edges().to_upper() == clean:
			return true
	return clean == str(GameManager.hrac_stat).strip_edges().to_upper()

# Validates required conditions.
func _je_debug_panel_povoleny_pro_stat(owner_tag: String) -> bool:
	match _ai_debug_filter_mode:
		1:
			return _je_hracuv_tag(owner_tag)
		2:
			return not _je_hracuv_tag(owner_tag)
		_:
			return true

# Search helper over available data.
func _najdi_debug_panel_fallback_tag() -> String:
	if GameManager == null:
		return ""

	if _ai_debug_filter_mode == 1:
		var local_states = GameManager.lokalni_hraci_staty if "lokalni_hraci_staty" in GameManager else []
		for raw_tag in local_states:
			var t = str(raw_tag).strip_edges().to_upper()
			if t != "":
				return t
		return str(GameManager.hrac_stat).strip_edges().to_upper()

	if _ai_debug_filter_mode == 2:
		var seen: Dictionary = {}
		var map_data = GameManager.map_data if "map_data" in GameManager else {}
		for p_id in map_data:
			var d = map_data[p_id] as Dictionary
			var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
			if owner_tag == "" or owner_tag == "SEA" or seen.has(owner_tag):
				continue
			seen[owner_tag] = true
			if not _je_hracuv_tag(owner_tag):
				return owner_tag

	return ""

func _vyres_debug_panel_tag(owner_tag: String) -> String:
	var clean = owner_tag.strip_edges().to_upper()
	if clean != "" and _je_debug_panel_povoleny_pro_stat(clean):
		return clean
	return _najdi_debug_panel_fallback_tag()

func _on_ai_debug_filter_all_pressed() -> void:
	_nastav_ai_debug_filter_mode(0)

func _on_ai_debug_filter_mine_pressed() -> void:
	_nastav_ai_debug_filter_mode(1)

# Triggered by a UI/game signal.
func _on_ai_debug_filter_other_pressed() -> void:
	_nastav_ai_debug_filter_mode(2)

# Refresh pass for current state.
func _aktualizuj_ai_debug_overview(owner_tag: String, je_hracuv_stat: bool) -> void:
	# Collects a snapshot and formats one combined debug report for the right panel.
	# Pro male dite: tady se seberou cisla o AI a napisi se do debug okna.
	if ai_debug_label == null or ai_debug_panel == null:
		return
	if not GameManager or not GameManager.has_method("je_ai_debug_mode_zapnuty"):
		ai_debug_panel.hide()
		return
	if not bool(GameManager.je_ai_debug_mode_zapnuty()):
		ai_debug_panel.hide()
		return
	var resolved_tag = _vyres_debug_panel_tag(owner_tag)
	if resolved_tag == "":
		ai_debug_panel.hide()
		return
	if not GameManager.has_method("ziskej_ai_debug_snapshot"):
		ai_debug_panel.hide()
		return

	var snap = GameManager.ziskej_ai_debug_snapshot(resolved_tag) as Dictionary
	if not bool(snap.get("ok", false)):
		ai_debug_panel.hide()
		return

	var enemies = snap.get("enemies", []) as Array
	var enemy_names: Array[String] = []
	for e_any in enemies:
		var e_tag = str(e_any).strip_edges().to_upper()
		if e_tag == "":
			continue
		enemy_names.append(_ziskej_jmeno_statu_podle_tagu(e_tag))
	var enemies_text = "none" if enemy_names.is_empty() else ", ".join(enemy_names)

	var goal_target = str(snap.get("goal_target", "")).strip_edges().to_upper()
	var plan_target = str(snap.get("plan_target", "")).strip_edges().to_upper()
	var goal_target_text = "-"
	if goal_target != "":
		goal_target_text = "%s (%s)" % [_ziskej_jmeno_statu_podle_tagu(goal_target), goal_target]
	var plan_target_text = "-"
	if plan_target != "":
		plan_target_text = "%s (%s)" % [_ziskej_jmeno_statu_podle_tagu(plan_target), plan_target]

	var recruit_targets = snap.get("recruit_targets", []) as Array
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var viewed_tag = resolved_tag
	var pair_war_text = "n/a"
	if player_tag != "" and viewed_tag != "" and player_tag != viewed_tag and GameManager.has_method("jsou_ve_valce"):
		pair_war_text = "yes" if bool(GameManager.jsou_ve_valce(player_tag, viewed_tag)) else "no"

	var lines: Array[String] = []
	var fps_now = Engine.get_frames_per_second()
	var turn_state = "processing" if _turn_loading_active else "idle"
	var turn_last_text = "n/a" if _debug_last_turn_ms < 0 else "%d ms" % _debug_last_turn_ms
	var turn_avg_text = "n/a"
	var turn_recent_text = "n/a"
	var turn_history = snap.get("turn_history", []) as Array
	var viewed_name = _ziskej_jmeno_statu_podle_tagu(str(snap.get("state", owner_tag)))
	if _ai_debug_title_label:
		_ai_debug_title_label.text = "Debug: %s [%s]" % [viewed_name, _ziskej_ai_debug_nazev_sekce(_ai_debug_section_mode)]
	if _debug_turn_samples > 0:
		turn_avg_text = "%d ms" % int(round(float(_debug_turn_total_ms) / float(_debug_turn_samples)))
	if not _debug_turn_recent_ms.is_empty():
		var t_stats = _spocitej_turn_debug_statistiky(_debug_turn_recent_ms)
		turn_recent_text = "avg %d | min %d | max %d | p95 %d ms" % [
			int(t_stats.get("avg", 0)),
			int(t_stats.get("min", 0)),
			int(t_stats.get("max", 0)),
			int(t_stats.get("p95", 0))
		]

	lines.append("[b]Debug mode[/b]  %s (%s)" % [viewed_name, str(snap.get("state", owner_tag))])
	lines.append("Section: %s | Filter: %s" % [_ziskej_ai_debug_nazev_sekce(_ai_debug_section_mode), _ziskej_ai_debug_nazev_filtru()])
	lines.append("FPS: %d | Turn state: %s" % [fps_now, turn_state])
	lines.append("------------------------------")

	match _ai_debug_section_mode:
		AI_DEBUG_SECTION_AI:
			_debug_append_ai_lines(lines, snap, enemies_text, goal_target_text, plan_target_text, recruit_targets)
		AI_DEBUG_SECTION_LATENCY:
			_debug_append_latency_lines(lines, turn_last_text, turn_avg_text, turn_recent_text, turn_history, snap)
		AI_DEBUG_SECTION_ECONOMY:
			_debug_append_economy_lines(lines, snap, turn_history)
		AI_DEBUG_SECTION_DIPLOMACY:
			_debug_append_diplomacy_lines(lines, resolved_tag, pair_war_text)
		AI_DEBUG_SECTION_TURN_PIPELINE:
			_debug_append_turn_pipeline_lines(lines, turn_history, snap)
		_:
			_debug_append_ai_lines(lines, snap, enemies_text, goal_target_text, plan_target_text, recruit_targets)
			lines.append("------------------------------")
			_debug_append_latency_lines(lines, turn_last_text, turn_avg_text, turn_recent_text, turn_history, snap)
			lines.append("------------------------------")
			_debug_append_economy_lines(lines, snap, turn_history)
			lines.append("------------------------------")
			_debug_append_diplomacy_lines(lines, resolved_tag, pair_war_text)
			lines.append("------------------------------")
			_debug_append_turn_pipeline_lines(lines, turn_history, snap)

	ai_debug_label.text = "\n".join(lines)
	ai_debug_label.scroll_to_line(0)
	_pozicuj_ai_debug_panel()
	ai_debug_panel.show()

# Feature logic entry point.
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

	ideology_menu_btn = get_node_or_null("OverviewPanel/VBoxContainer/ChangeIdeologyMenuButton") as Button
	if ideology_menu_btn == null:
		ideology_menu_btn = Button.new()
		ideology_menu_btn.name = "ChangeIdeologyMenuButton"
		ideology_menu_btn.text = "Change ideology v"
		ideology_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(ideology_menu_btn)
	if ideology_menu_btn.text.strip_edges() == "":
		ideology_menu_btn.text = "Change ideology v"
	_aplikuj_overview_tlacitko_vzhled(ideology_menu_btn)

	ideology_menu_popup = get_node_or_null("IdeologyMenuPopup") as PopupMenu
	if ideology_menu_popup == null:
		ideology_menu_popup = PopupMenu.new()
		ideology_menu_popup.name = "IdeologyMenuPopup"
		ideology_menu_popup.popup_window = false
		add_child(ideology_menu_popup)
		var popup_style = StyleBoxFlat.new()
		popup_style.bg_color = Color(0.07, 0.10, 0.18, 0.97)
		popup_style.border_color = Color(0.45, 0.60, 0.79, 0.70)
		popup_style.border_width_left = 1
		popup_style.border_width_top = 1
		popup_style.border_width_right = 1
		popup_style.border_width_bottom = 1
		popup_style.corner_radius_top_left = 8
		popup_style.corner_radius_top_right = 8
		popup_style.corner_radius_bottom_left = 8
		popup_style.corner_radius_bottom_right = 8
		ideology_menu_popup.add_theme_stylebox_override("panel", popup_style)
		ideology_menu_popup.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
		ideology_menu_popup.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	if not ideology_menu_btn.pressed.is_connected(_on_ideology_menu_button_pressed):
		ideology_menu_btn.pressed.connect(_on_ideology_menu_button_pressed)
	if not ideology_menu_popup.id_pressed.is_connected(_on_ideology_menu_id_pressed):
		ideology_menu_popup.id_pressed.connect(_on_ideology_menu_id_pressed)
	if ideology_menu_popup.has_signal("about_to_popup") and not ideology_menu_popup.about_to_popup.is_connected(_on_ideology_dropdown_opened):
		ideology_menu_popup.about_to_popup.connect(_on_ideology_dropdown_opened)
	if ideology_menu_popup.has_signal("id_focused") and not ideology_menu_popup.id_focused.is_connected(_on_ideology_dropdown_item_focused):
		ideology_menu_popup.id_focused.connect(_on_ideology_dropdown_item_focused)
	if ideology_menu_popup.has_signal("popup_hide") and not ideology_menu_popup.popup_hide.is_connected(_on_ideology_dropdown_closed):
		ideology_menu_popup.popup_hide.connect(_on_ideology_dropdown_closed)

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
		if _vassals_btn and _vassals_btn.get_parent() == vbox:
			vbox.move_child(ideology_menu_btn, _vassals_btn.get_index() + 1)
		else:
			vbox.move_child(ideology_menu_btn, ideology_relocate_capital_btn.get_index() + 1)

	# Keep only the new menu flow visible; old dropdown/apply are internal state holders.
	ideology_option.hide()
	ideology_apply_btn.hide()

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
	_research_dialog.size = Vector2(820, 780)
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
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	root.add_child(title)

	_research_money_label = Label.new()
	_research_money_label.text = "Funds: -"
	_research_money_label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.99, 1.0))
	root.add_child(_research_money_label)

	_army_research_summary_label = Label.new()
	_army_research_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_army_research_summary_label.text = "Army bonus: +0"
	_army_research_summary_label.add_theme_color_override("font_color", Color(0.83, 0.90, 0.98, 1.0))
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
	grid_title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
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
	_aplikuj_ingame_tlacitko_styl(_army_research_reroll_btn)
	_army_research_reroll_btn.pressed.connect(_on_army_research_reroll_pressed)
	controls_row.add_child(_army_research_reroll_btn)

	_army_research_quality_btn = Button.new()
	_army_research_quality_btn.text = "Upgrade quality"
	_aplikuj_ingame_tlacitko_styl(_army_research_quality_btn)
	_army_research_quality_btn.pressed.connect(_on_army_research_quality_upgrade_pressed)
	controls_row.add_child(_army_research_quality_btn)

	_army_research_trash = ArmyTrashBin.new()
	_army_research_trash.owner_ui = self
	_army_research_trash.custom_minimum_size = Vector2(170, 40)
	_army_research_trash.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	_army_research_trash.tooltip_text = "Trash (sell 75%)"
	_army_research_trash.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.17, 0.10, 0.12, 0.94), Color(0.84, 0.49, 0.49, 0.70)))
	controls_row.add_child(_army_research_trash)

	var trash_icon = Label.new()
	trash_icon.name = "TrashIcon"
	trash_icon.text = "BIN"
	trash_icon.add_theme_color_override("font_color", Color(1.0, 0.89, 0.89, 1.0))
	trash_icon.add_theme_font_size_override("font_size", 16)
	trash_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_army_research_trash.add_child(trash_icon)

	var offers_title = Label.new()
	offers_title.text = "This turn's offers"
	offers_title.add_theme_font_size_override("font_size", 18)
	offers_title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
	_research_list.add_child(offers_title)

	_army_research_offers = VBoxContainer.new()
	_army_research_offers.add_theme_constant_override("separation", 8)
	_research_list.add_child(_army_research_offers)

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)

	var close_btn = Button.new()
	close_btn.text = "Close"
	_aplikuj_ingame_tlacitko_styl(close_btn)
	close_btn.pressed.connect(func(): _zavri_vyzkum_dialog())
	footer.add_child(close_btn)

	_research_dialog.hide()

# Closes the active UI flow and clears temporary interaction context.
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
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if _research_dialog:
		_research_dialog.hide()
		_research_dialog.modulate.a = 1.0
	_research_dialog_user_open = false
	_research_dialog_layout_warmed = true

# Handles this gameplay/UI path.
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
	var margin := 8.0
	var top_offset := 18.0
	var avail_w = max(280.0, vp.x - left_x - margin * 2.0)
	var avail_h = max(300.0, vp.y - top_offset - margin)
	var grid_columns = max(3, _army_research_view_w)
	var grid_rows = max(3, _army_research_view_h)
	var desired_grid_w = float(grid_columns * 120) + float(max(0, grid_columns - 1) * 6)
	var desired_grid_h = float(grid_rows * 52) + float(max(0, grid_rows - 1) * 6)
	var desired_w = max(760.0, desired_grid_w + 120.0)
	var desired_h = max(860.0, desired_grid_h + 500.0)

	var w = min(desired_w, avail_w)
	var h = min(desired_h, avail_h)
	_research_dialog.size = Vector2(w, h)
	_research_dialog.position = Vector2(clamp(left_x + margin, 0.0, max(0.0, vp.x - w)), clamp(top_offset, 0.0, max(0.0, vp.y - h)))

# Reacts to incoming events.
func _on_research_button_pressed() -> void:
	if current_viewed_tag == "":
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if current_viewed_tag != player_tag:
		return
	if _research_dialog and _research_dialog.visible:
		_zavri_vyzkum_dialog()
		return
	if _vassals_dialog and _vassals_dialog.visible:
		_vassals_dialog.hide()
	if not _research_dialog_layout_warmed:
		await _predhrej_vyzkum_dialog_layout()
	_research_dialog_user_open = true
	if _research_dialog:
		_pozicuj_vyzkum_dialog()
		_research_dialog.show()
	# Update after popup layout is ready to avoid first-open visual glitches.
	call_deferred("_aktualizuj_vyzkum_dialog", player_tag)

# Runs the local feature logic.
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

func _format_army_item_title(item_name: String, level: int) -> String:
	var safe_level = max(1, level)
	return "%s L%d" % [_display_army_item_name(item_name), safe_level]

# Updates derived state and UI.
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
	# +1 viewport okno drzi UX plynule: hrac vidi i dalsi expand krok bez prepinani.
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
		var lvl = max(1, int(item.get("level", 1)))
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
				cell_texts[yy * _army_research_view_w + xx] = "%s%d" % [short, lvl]

	if _army_research_grid:
		# grid se pri refreshi stavi znovu, at drag/drop stav nevisi na starych nodech.
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
					cell.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl())
					var lbl = Label.new()
					lbl.name = "CellLabel"
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					lbl.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
					lbl.text = "-"
					cell.add_child(lbl)
					_army_research_grid.add_child(cell)
					_army_research_grid_cells.append(cell)
				elif plus_candidates.has(key):
					var plus_btn = Button.new()
					plus_btn.text = "+ $%.0f" % expand_cost
					plus_btn.custom_minimum_size = Vector2(120, 52)
					_aplikuj_ingame_tlacitko_styl(plus_btn)
					plus_btn.pressed.connect(_on_army_research_buy_cell_pressed.bind(xx, yy))
					plus_btn.disabled = treasury < expand_cost
					_army_research_grid.add_child(plus_btn)
					_army_research_grid_cells.append(plus_btn)
				else:
					var filler = PanelContainer.new()
					filler.custom_minimum_size = Vector2(120, 52)
					filler.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.09, 0.12, 0.18, 0.45), Color(0.35, 0.44, 0.60, 0.30)))
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
		# nabidky cistime pred renderem, protoze jejich poradi/cena se muze menit rerollem.
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
		card.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl())
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
		var level = max(1, int(offer.get("level", 1)))
		var power_item_flat = int(offer.get("power_flat", 0))
		var power_item_pct = float(offer.get("power_pct", 0.0)) * 100.0

		var title = Label.new()
		title.text = "%d) %s | %dx%d | $%.2f" % [i + 1, _format_army_item_title(str(offer.get("name", "Item")), level), w, h, cost]
		left.add_child(title)

		var desc = Label.new()
		desc.text = "Effect: +%d power, +%.2f%% from base" % [power_item_flat, power_item_pct]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(desc)

		if treasury < cost:
			card.modulate = Color(1, 1, 1, 0.65)
		card.tooltip_text = "Buying works only via drag and drop into the grid."

	if _research_dialog and _research_dialog.visible:
		_pozicuj_vyzkum_dialog()

func _vytvor_army_drag_preview(w: int, h: int, _level: int = 1) -> Control:
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

# Core flow for this feature.
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

# Core flow for this feature.
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

# Runs the local feature logic.
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

# Handles this gameplay/UI path.
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

# Handles this gameplay/UI path.
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
		var move_target_item = _army_grid_item_at_cell(cell_index)
		if not move_target_item.is_empty() and str(move_target_item.get("offer_uid", "")) != item_uid:
			return _army_items_mozno_sloucit(moving, move_target_item)
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

# Core flow for this feature.
func _army_grid_cell_drop(cell_index: int, data) -> void:
	if not _army_grid_cell_can_drop(cell_index, data):
		return
	# drop je centralni commit bod pro buy/move/merge armadnich itemu.
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
		# chybu ukazeme, ale stejne refreshem srovname lokalni UI stav s backendem.
		zobraz_systemove_hlaseni("Army", str(result.get("reason", "Item cannot be placed here.")))
	_aktualizuj_vyzkum_dialog(player_tag)
	_obnov_otevreny_prehled_statu()

# Runs the local feature logic.
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

# Callback for UI/game events.
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

# Reacts to incoming events.
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

# Feature logic entry point.
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

# Sync update for linked values.
func _set_ideology_effects_text(content: String) -> void:
	if ideology_effects_label == null:
		return
	ideology_effects_label.clear()
	ideology_effects_label.append_text(content)

# Feature logic entry point.
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

	var action_recruit_after = float(_overview_action_econ_preview.get("recruit_cost_after", recruit_cost))
	var action_upkeep_after = float(_overview_action_econ_preview.get("upkeep_per_soldier_after", upkeep_cost))
	var action_gdp_growth_after = float(_overview_action_econ_preview.get("gdp_growth_after", gdp_growth))
	var action_pop_growth_after = float(_overview_action_econ_preview.get("population_growth_pct_after", pop_growth_pct))
	var action_regen_core_after = float(_overview_action_econ_preview.get("recruit_regen_core_pct_after", recruit_regen_core_pct))
	var action_regen_occ_after = float(_overview_action_econ_preview.get("recruit_regen_occ_pct_after", recruit_regen_occ_pct))

	var action_recruit_text := ""
	if _overview_action_econ_preview.has("recruit_cost_after"):
		action_recruit_text = " [color=#5ec8ff](-> %s)[/color]" % _format_money_auto(action_recruit_after, 4)
	var action_upkeep_text := ""
	if _overview_action_econ_preview.has("upkeep_per_soldier_after"):
		action_upkeep_text = " [color=#5ec8ff](-> %s)[/color]" % _format_money_auto(action_upkeep_after, 4)
	var action_gdp_growth_text := ""
	if _overview_action_econ_preview.has("gdp_growth_after"):
		action_gdp_growth_text = " [color=#5ec8ff](-> %.3f)[/color]" % action_gdp_growth_after
	var action_pop_growth_text := ""
	if _overview_action_econ_preview.has("population_growth_pct_after"):
		action_pop_growth_text = " [color=#5ec8ff](-> %.3f%%)[/color]" % action_pop_growth_after
	var action_regen_core_text := ""
	if _overview_action_econ_preview.has("recruit_regen_core_pct_after"):
		action_regen_core_text = " [color=#5ec8ff](-> %.2f%%)[/color]" % action_regen_core_after
	var action_regen_occ_text := ""
	if _overview_action_econ_preview.has("recruit_regen_occ_pct_after"):
		action_regen_occ_text = " [color=#5ec8ff](-> %.2f%%)[/color]" % action_regen_occ_after

	return "Cost/soldier: %s%s\nUpkeep/soldier / turn: %s%s\nIncome rate from GDP: %.2f%%%s\nGDP growth: %.3f%s\nPopulation growth / turn: %.3f%%%s\nRecruit regen (core): %.2f%%%s\nRecruit regen (occupied): %.2f%%%s" % [
		_format_money_auto(recruit_cost, 4),
		(_format_delta_text_color(d_recruit_cost, 4, " M") if show_delta else "") + action_recruit_text,
		_format_money_auto(upkeep_cost, 4),
		(_format_delta_text_color(d_upkeep_cost, 4, " M") if show_delta else "") + action_upkeep_text,
		income_rate_pct,
		_format_delta_text_color(d_income_rate_pct, 2, "%") if show_delta else "",
		gdp_growth,
		(_format_delta_text_color(d_gdp_growth, 3, "") if show_delta else "") + action_gdp_growth_text,
		pop_growth_pct,
		(_format_delta_text_color(d_pop_growth_pct, 3, "%") if show_delta else "") + action_pop_growth_text,
		recruit_regen_core_pct,
		(_format_delta_text_color(d_recruit_regen_core_pct, 2, "%") if show_delta else "") + action_regen_core_text,
		recruit_regen_occ_pct,
		(_format_delta_text_color(d_recruit_regen_occ_pct, 2, "%") if show_delta else "") + action_regen_occ_text
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

# Resets transient runtime/UI data.
func _vycisti_nahled_ideologie_v_ui() -> void:
	nastav_akce_nahled_delta({})
	nastav_akce_nahled_ekonomiky({})
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

# Event handler for user or game actions.
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

# Reacts to incoming events.
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

# Refreshes existing content to reflect current runtime values.
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
	if _current_viewed_province_id >= 0 and provinces.has(_current_viewed_province_id):
		var current_data = provinces[_current_viewed_province_id] as Dictionary
		if str(current_data.get("owner", "")).strip_edges().to_upper() == current_viewed_tag:
			zobraz_prehled_statu(current_data, provinces)
			return

	var stats = _ziskej_souhrn_statu(current_viewed_tag, provinces)
	var representative_province_id = int(stats.get("representative_province_id", -1))
	if representative_province_id >= 0 and provinces.has(representative_province_id):
		zobraz_prehled_statu(provinces[representative_province_id], provinces)

# Read-only data accessor.
func _ziskej_souhrn_statu(owner_tag: String, all_provinces: Dictionary) -> Dictionary:
	var clean_tag = owner_tag.strip_edges().to_upper()
	if clean_tag == "":
		return {}

	var stats := {
		"population": 0,
		"gdp": 0.0,
		"recruits": 0,
		"soldiers": 0,
		"representative_province_id": -1
	}
	
	# If we have fresh provinces data, always recalculate instead of trusting stale cache
	if all_provinces.size() > 0:
		for p_id in all_provinces:
			var province = all_provinces[p_id] as Dictionary
			if str(province.get("owner", "")).strip_edges().to_upper() != clean_tag:
				continue
			stats["population"] = int(stats.get("population", 0)) + int(province.get("population", 0))
			stats["gdp"] = float(stats.get("gdp", 0.0)) + float(province.get("gdp", 0.0))
			stats["recruits"] = int(stats.get("recruits", 0)) + int(province.get("recruitable_population", 0))
			stats["soldiers"] = int(stats.get("soldiers", 0)) + int(province.get("soldiers", 0))
			if int(stats.get("representative_province_id", -1)) == -1:
				stats["representative_province_id"] = int(p_id)
		_country_overview_stats_cache[clean_tag] = stats
		return stats
	
	# Only use cache if no fresh data is available
	if _country_overview_stats_cache.has(clean_tag):
		return _country_overview_stats_cache[clean_tag]
	
	return stats

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

# Refresh pass for current state.
func _aktualizuj_ideology_ui(owner_tag: String, current_ideology: String) -> void:
	if ideology_separator == null or ideology_option == null or ideology_apply_btn == null or ideology_effects_label == null or ideology_relocate_capital_btn == null:
		return

	var is_player = owner_tag == str(GameManager.hrac_stat).strip_edges().to_upper()
	if not is_player:
		ideology_separator.hide()
		ideology_effects_label.hide()
		ideology_option.hide()
		ideology_apply_btn.hide()
		if ideology_menu_btn:
			ideology_menu_btn.hide()
		ideology_relocate_capital_btn.hide()
		_vycisti_nahled_ideologie_v_ui()
		return

	ideology_separator.show()
	ideology_effects_label.show()
	ideology_option.hide()
	ideology_apply_btn.hide()
	if ideology_menu_btn:
		ideology_menu_btn.show()
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
	if ideology_menu_btn:
		ideology_menu_btn.disabled = options.size() <= 1
		_napln_ideology_menu(options, current)
	_set_ideology_effects_label(str(options[selected_idx]))
	_ideology_dropdown_open = false
	_vycisti_nahled_ideologie_v_ui()
	_updating_ideology_ui = false
	_aktualizuj_tlacitko_presunu_hlavniho_mesta(owner_tag)

func _napln_ideology_menu(options: Array, current_ideology: String) -> void:
	if ideology_menu_popup == null:
		return
	ideology_menu_popup.clear()
	for i in range(options.size()):
		var ideo = str(options[i])
		ideology_menu_popup.add_item(_display_ideologie(ideo), i)
		if _normalizuj_ideologii(ideo) == _normalizuj_ideologii(current_ideology):
			ideology_menu_popup.set_item_disabled(ideology_menu_popup.get_item_count() - 1, true)
	ideology_menu_popup.reset_size()

func _on_ideology_menu_button_pressed() -> void:
	if ideology_menu_btn == null or ideology_menu_popup == null or ideology_menu_btn.disabled:
		return
	if ideology_menu_popup.visible:
		ideology_menu_popup.hide()
		return
	var viewport = get_viewport()
	if viewport == null:
		ideology_menu_popup.popup()
		return
	var vp_size = viewport.get_visible_rect().size
	var popup_size = ideology_menu_popup.get_contents_minimum_size()
	var approx_w = maxf(220.0, popup_size.x + 20.0)
	var approx_h = maxf(120.0, popup_size.y + 10.0)
	var btn_pos = ideology_menu_btn.get_global_position()
	var pos = btn_pos + Vector2(ideology_menu_btn.size.x + 6.0, 0.0)
	if pos.x + approx_w > vp_size.x - 8.0:
		pos.x = btn_pos.x - approx_w - 6.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp_size.x - approx_w - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp_size.y - approx_h - 8.0))
	ideology_menu_popup.position = pos
	ideology_menu_popup.popup()

func _aplikuj_overview_tlacitko_vzhled(btn: Button) -> void:
	if btn == null:
		return
	var source: Button = null
	if _vassals_btn:
		source = _vassals_btn
	elif improve_rel_btn:
		source = improve_rel_btn
	elif research_btn:
		source = research_btn
	if source == null:
		return
	btn.custom_minimum_size = source.custom_minimum_size
	btn.theme_type_variation = source.theme_type_variation
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb = source.get_theme_stylebox(key)
		if sb:
			btn.add_theme_stylebox_override(key, sb)

func _on_ideology_menu_id_pressed(id: int) -> void:
	if ideology_option == null:
		return
	if id < 0 or id >= _ideology_option_values.size():
		return
	ideology_option.select(id)
	_on_ideology_option_selected(id)
	_on_apply_ideology_pressed()

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

# Feature logic entry point.
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

# Core flow for this feature.
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
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	parent.move_child(row, idx)

	base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_label.custom_minimum_size.x = 0.0
	row.add_child(base_label)

	var delta_holder = Control.new()
	delta_holder.name = "OverviewDeltaHolder_%s" % key
	delta_holder.custom_minimum_size = Vector2(OVERVIEW_INLINE_DELTA_WIDTH, 0)
	delta_holder.clip_contents = true
	delta_holder.visible = false
	row.add_child(delta_holder)

	var delta = Label.new()
	delta.name = "OverviewDelta_%s" % key
	delta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delta.visible = false
	delta_holder.add_child(delta)

	_overview_metric_rows[key] = row
	_overview_metric_deltas[key] = delta
	_overview_metric_delta_holders[key] = delta_holder

func _setup_overview_inline_deltas() -> void:
	_wrap_overview_metric_label("pop", pop_label)
	_wrap_overview_metric_label("recruit", recruit_label)
	_wrap_overview_metric_label("gdp", gdp_label)
	_wrap_overview_metric_label("gdp_pc", gdp_pc_label)
	_wrap_overview_metric_label("army", army_power_label)

# Updates state and keeps things in sync.
func _set_overview_metric_delta(key: String, text: String, color: Color) -> void:
	if not _overview_metric_deltas.has(key):
		return
	var lbl = _overview_metric_deltas[key] as Label
	var holder: Control = _overview_metric_delta_holders.get(key, null)
	var clean = text.strip_edges()
	if clean == "":
		lbl.text = ""
		lbl.visible = false
		if holder:
			holder.visible = false
		return
	lbl.text = "(%s)" % clean
	lbl.add_theme_color_override("font_color", color)
	lbl.visible = true
	if holder:
		holder.visible = true

# Wipes short-lived state.
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

# Updates state and keeps things in sync.
func nastav_akce_nahled_delta(deltas: Dictionary) -> void:
	_overview_preview_deltas = deltas.duplicate(true)
	_apply_overview_preview_deltas()

func nastav_akce_nahled_ekonomiky(preview: Dictionary) -> void:
	_overview_action_econ_preview = preview.duplicate(true)
	_obnov_overview_ekonomicky_blok()

func _obnov_overview_ekonomicky_blok() -> void:
	if current_viewed_tag == "":
		return
	var current_ideo = _ziskej_aktualni_ideologii_statu(current_viewed_tag)
	if current_ideo == "":
		return
	if _ideology_dropdown_open and _ideology_hover_idx >= 0 and _ideology_hover_idx < _ideology_option_values.size():
		var hovered = str(_ideology_option_values[_ideology_hover_idx])
		_set_ideology_effects_text(_sestav_ideology_effects_text(current_ideo, hovered))
		return
	_set_ideology_effects_label(current_ideo)

# Updates state and keeps things in sync.
func nastav_akce_nahled(_text: String) -> void:
	# Backward-compatible no-op; preview now uses inline deltas next to existing rows.
	if _text.strip_edges() == "":
		nastav_akce_nahled_delta({})

# Triggered by a UI/game signal.
func _on_system_message_ok_pressed():
	_system_message_ack = true
	if system_message_popup:
		system_message_popup.hide()
	_aktualizuj_pozice_popupu()

# Event handler for user or game actions.
func _on_viewport_resized():
	_aktualizuj_overview_panel_layout()
	_pozicuj_ai_debug_panel()
	_aktualizuj_pozice_popupu()
	_pozicuj_spectate_hud_indicator()
	if _rename_country_dialog and _rename_country_dialog.visible:
		_vynutit_velikost_prejmenovani_dialogu(false)
	_pozicuj_pause_menu()
	_pozicuj_save_load_popupy()
	_pozicuj_settings_dialog()
	_pozicuj_gift_dialog()
	_pozicuj_mirovou_konferenci_dialog()
	_pozicuj_hlaseni_mirove_konference()
	if _trade_dialog and _trade_dialog.visible:
		_pozicuj_trade_dialog()
	if _trade_province_picker_popup and _trade_province_picker_popup.visible:
		_trade_pozicuj_province_picker_popup()
	if _vassals_dialog and _vassals_dialog.visible:
		_pozicuj_a_zmen_velikost_panelu_vazalu()
	if _research_dialog and _research_dialog.visible:
		_pozicuj_vyzkum_dialog()

func _aktualizuj_overview_panel_layout() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var target_w = minf(OVERVIEW_TARGET_WIDTH, maxf(260.0, viewport_size.x))
	var left_bottom_reserved = _ziskej_overview_left_bottom_reserved(target_w)
	var bottom_reserved = float(left_bottom_reserved.get("bottom_height", 0.0))
	var available_h = maxf(96.0, viewport_size.y - bottom_reserved)
	var target_h = minf(OVERVIEW_TARGET_HEIGHT, available_h)

	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = target_w
	panel.offset_bottom = target_h

	var compact = target_h < 780.0 or target_w < OVERVIEW_TARGET_WIDTH
	var vbox = panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", 7 if compact else 10)

	if ideology_effects_label:
		ideology_effects_label.custom_minimum_size = Vector2(0, 120 if compact else 180)

	# Prevent random vertical stretching when other UI popups trigger relayout.
	var overview_btn_h = 34.0 if compact else 38.0
	for b in [
		improve_rel_btn,
		worsen_rel_btn,
		gift_money_btn,
		trade_btn,
		alliance_btn,
		declare_war_btn,
		propose_peace_btn,
		non_aggression_btn,
		_military_access_btn,
		give_loan_btn,
		take_loan_btn,
		research_btn,
		_vassals_btn,
		ideology_apply_btn,
		ideology_relocate_capital_btn,
	]:
		if b and b is Button:
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.custom_minimum_size = Vector2(0, overview_btn_h)

func _input(event):
	if event is InputEventKey and _settings_dialog and _settings_dialog.visible and _settings_capture_action != "":
		if _capture_ingame_keybind(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if diplomacy_request_popup and diplomacy_request_popup.visible:
				_potlac_diplomatickou_frontu_do_zmeny()
				get_viewport().set_input_as_handled()
				return
			if _peace_notice_panel and _peace_notice_panel.visible:
				_potlac_hlaseni_miru_do_dalsi_konference()
				get_viewport().set_input_as_handled()
				return
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

# Builds UI objects and default wiring.
func _vytvor_pause_menu() -> void:
	_pause_menu_panel = PopupPanel.new()
	_pause_menu_panel.name = "PauseMenu"
	_pause_menu_panel.wrap_controls = false
	_pause_menu_panel.unresizable = true
	_pause_menu_panel.min_size = Vector2i(380, 470)
	_pause_menu_panel.size = Vector2(380, 470)
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

	_pause_spectate_btn = Button.new()
	_pause_spectate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_spectate_btn.custom_minimum_size = Vector2(0, 40)
	_pause_spectate_btn.pressed.connect(_on_pause_toggle_spectate_pressed)
	vbox.add_child(_pause_spectate_btn)

	_pause_spectate_pick_row = HBoxContainer.new()
	_pause_spectate_pick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_spectate_pick_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_pause_spectate_pick_row)

	_pause_spectate_pick_label = Label.new()
	_pause_spectate_pick_label.text = "Take control as:"
	_pause_spectate_pick_label.custom_minimum_size = Vector2(108, 0)
	_pause_spectate_pick_row.add_child(_pause_spectate_pick_label)

	_pause_spectate_pick_option = OptionButton.new()
	_pause_spectate_pick_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_spectate_pick_option.custom_minimum_size = Vector2(0, 34)
	_pause_spectate_pick_row.add_child(_pause_spectate_pick_option)

	_obnov_pause_spectate_vyber_hrace()
	_obnov_text_spectate_tlacitka()

	_pause_confirm_dialog = ConfirmationDialog.new()
	_pause_confirm_dialog.wrap_controls = false
	_pause_confirm_dialog.unresizable = true
	_pause_confirm_dialog.min_size = Vector2i(480, 200)
	_pause_confirm_dialog.ok_button_text = "Yes"
	_pause_confirm_dialog.cancel_button_text = "No"
	_pause_confirm_dialog.confirmed.connect(_on_pause_confirmed)
	_pause_confirm_dialog.canceled.connect(_on_pause_confirm_canceled)
	_pause_confirm_dialog.close_requested.connect(_on_pause_confirm_canceled)
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

# Applies prepared settings/effects to runtime systems.
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

func _vytvor_ingame_kartu_styl(bg: Color = Color(0.11, 0.16, 0.24, 0.94), border: Color = Color(0.53, 0.70, 0.92, 0.58)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	return s

# Applies prepared settings/effects to runtime systems.
func _aplikuj_ingame_tlacitko_styl(btn: Button, danger: bool = false) -> void:
	if btn == null:
		return
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 34.0)
	btn.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	var base = StyleBoxFlat.new()
	base.bg_color = Color(0.16, 0.24, 0.38, 0.96)
	base.border_color = Color(0.60, 0.75, 0.95, 0.86)
	if danger:
		base.bg_color = Color(0.28, 0.15, 0.19, 0.97)
		base.border_color = Color(0.85, 0.49, 0.57, 0.88)
	base.border_width_left = 1
	base.border_width_top = 1
	base.border_width_right = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 6
	base.corner_radius_top_right = 6
	base.corner_radius_bottom_left = 6
	base.corner_radius_bottom_right = 6

	var hover = base.duplicate() as StyleBoxFlat
	hover.bg_color = base.bg_color.lightened(0.12)
	hover.border_color = base.border_color.lightened(0.15)

	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

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

	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_row)

	var title_left_spacer = Control.new()
	title_left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_left_spacer)

	var title = Label.new()
	title.text = "Send financial gift"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title_row.add_child(title)

	var gift_help_btn = TooltipUtilsScript.create_help_button("Amount in M USD")
	gift_help_btn.pressed.connect(func(): TooltipUtilsScript.show_help_dropdown(self, gift_help_btn, "Amount in M USD"))
	title_row.add_child(gift_help_btn)

	var title_right_spacer = Control.new()
	title_right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_right_spacer)

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

# ---- Loans Dialog ----

func _vytvor_loans_dialog() -> void:
	if _loans_dialog != null:
		return

	_loans_dialog = PopupPanel.new()
	_loans_dialog.name = "LoansDialog"
	_loans_dialog.wrap_controls = false
	_loans_dialog.unresizable = true
	_loans_dialog.min_size = Vector2i(380, 280)
	_loans_dialog.size = Vector2(480, 350)
	_loans_dialog.exclusive = false
	_loans_dialog.popup_window = false
	add_child(_loans_dialog)
	_aplikuj_ingame_popup_styl(_loans_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loans_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title = Label.new()
	title.text = "Loan Request"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 0)
	_aplikuj_ingame_tlacitko_styl(close_btn)
	close_btn.pressed.connect(func(): _loans_dialog.hide())
	header.add_child(close_btn)

	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	root.add_child(form)

	# === Principal Slider + Input Row ===
	var principal_title = Label.new()
	principal_title.text = "Principal (M USD):"
	principal_title.add_theme_font_size_override("font_size", 12)
	form.add_child(principal_title)

	var principal_slider_row = HBoxContainer.new()
	principal_slider_row.add_theme_constant_override("separation", 6)
	form.add_child(principal_slider_row)

	var principal_slider = HSlider.new()
	_loan_principal_slider = principal_slider
	principal_slider.min_value = 0.0
	principal_slider.max_value = 1000.0
	principal_slider.value = 500.0
	principal_slider.step = 1.0
	principal_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	principal_slider_row.add_child(principal_slider)

	var principal_input = LineEdit.new()
	_loan_principal_input = principal_input
	principal_input.text = "500"
	principal_input.custom_minimum_size = Vector2(60, 24)
	principal_slider_row.add_child(principal_input)

	principal_slider.value_changed.connect(func(val): principal_input.text = str(int(val)))
	principal_input.text_changed.connect(func(txt):
		if txt.strip_edges() != "":
			var val = float(txt) if txt.is_valid_float() else 0.0
			var clamped = clampf(val, principal_slider.min_value, principal_slider.max_value)
			principal_slider.set_value_no_signal(clamped)
			if val != clamped:
				principal_input.text = str(int(clamped))
	)

	# === Interest Slider + Input Row ===
	var interest_title = Label.new()
	interest_title.text = "Interest (%):"
	interest_title.add_theme_font_size_override("font_size", 12)
	form.add_child(interest_title)

	var interest_slider_row = HBoxContainer.new()
	interest_slider_row.add_theme_constant_override("separation", 6)
	form.add_child(interest_slider_row)

	var interest_slider = HSlider.new()
	_loan_interest_slider = interest_slider
	interest_slider.min_value = 0.0
	interest_slider.max_value = 100.0
	interest_slider.value = 6.0
	interest_slider.step = 0.5
	interest_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interest_slider_row.add_child(interest_slider)

	var interest_input = LineEdit.new()
	_loan_interest_input = interest_input
	interest_input.text = "6.0"
	interest_input.custom_minimum_size = Vector2(60, 24)
	interest_slider_row.add_child(interest_input)

	interest_slider.value_changed.connect(func(val): interest_input.text = "%.1f" % val)
	interest_input.text_changed.connect(func(txt):
		if txt.strip_edges() != "":
			var val = float(txt) if txt.is_valid_float() else 0.0
			val = clampf(val, interest_slider.min_value, interest_slider.max_value)
			interest_input.text = "%.1f" % val
			interest_slider.set_value_no_signal(val)
	)

	# === Duration Slider + Input Row ===
	var duration_title = Label.new()
	duration_title.text = "Duration (turns):"
	duration_title.add_theme_font_size_override("font_size", 12)
	form.add_child(duration_title)

	var duration_slider_row = HBoxContainer.new()
	duration_slider_row.add_theme_constant_override("separation", 6)
	form.add_child(duration_slider_row)

	var duration_slider = HSlider.new()
	_loan_duration_slider = duration_slider
	duration_slider.min_value = 5.0
	duration_slider.max_value = 36.0
	duration_slider.value = 10.0
	duration_slider.step = 1.0
	duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_slider_row.add_child(duration_slider)

	var duration_input = LineEdit.new()
	_loan_duration_input = duration_input
	duration_input.text = "10"
	duration_input.custom_minimum_size = Vector2(60, 24)
	duration_slider_row.add_child(duration_input)

	duration_slider.value_changed.connect(func(val): duration_input.text = str(int(val)))
	duration_input.text_changed.connect(func(txt):
		if txt.strip_edges() != "":
			var val = float(txt) if txt.is_valid_float() else 5.0
			val = clampf(val, duration_slider.min_value, duration_slider.max_value)
			duration_input.text = str(int(val))
			duration_slider.set_value_no_signal(val)
	)

	# Buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	form.add_child(button_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(confirm_btn)
	confirm_btn.pressed.connect(func(): _on_loan_confirmed(principal_input.text, interest_input.text, duration_input.text))

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(cancel_btn)
	cancel_btn.pressed.connect(func(): _loans_dialog.hide())

	_loans_dialog.hide()

func _ziskej_dostupne_funds_statu(tag: String) -> float:
	if GameManager == null:
		return 0.0
	var normalized = str(tag).strip_edges().to_upper()
	if normalized == "":
		return 0.0
	if GameManager.has_method("_ziskej_kasu_statu"):
		return maxf(0.0, float(GameManager._ziskej_kasu_statu(normalized)))
	if normalized == str(GameManager.hrac_stat).strip_edges().to_upper():
		return maxf(0.0, float(GameManager.statni_kasa))
	return 0.0

func _ziskej_max_principal_pro_rezim(player_tag: String, target_tag: String) -> float:
	if _loans_mode == "take":
		return _ziskej_dostupne_funds_statu(target_tag)
	return _ziskej_dostupne_funds_statu(player_tag)

func _aktualizuj_loans_dialog_cap(player_tag: String, target_tag: String) -> void:
	if _loan_principal_slider == null or _loan_principal_input == null:
		return

	var max_principal = _ziskej_max_principal_pro_rezim(player_tag, target_tag)
	max_principal = maxf(0.0, floor(max_principal))
	_loan_principal_slider.max_value = max_principal
	_loan_principal_slider.step = 1.0
	_loan_principal_slider.editable = max_principal > 0.0
	if _loan_principal_input:
		_loan_principal_input.editable = max_principal > 0.0
	_loan_principal_input.placeholder_text = "max %.0f" % max_principal

	var clamped = clampf(_loan_principal_slider.value, _loan_principal_slider.min_value, _loan_principal_slider.max_value)
	_loan_principal_slider.set_value_no_signal(clamped)
	_loan_principal_input.text = str(int(clamped))

func _pozicuj_loans_dialog() -> void:
	if _loans_dialog == null:
		return

	var vp = get_viewport().get_visible_rect().size
	var gap = 10.0
	var x = 16.0
	var y = _topbar_bottom_y() + 8.0

	if panel:
		var ov = panel.get_global_rect()
		x = ov.position.x + ov.size.x + gap
		y = maxf(ov.position.y + 14.0, _topbar_bottom_y() + 8.0)
		if x + _loans_dialog.size.x > vp.x - 8.0:
			x = ov.position.x - _loans_dialog.size.x - gap

	x = clampf(x, 8.0, maxf(8.0, vp.x - _loans_dialog.size.x - 8.0))
	y = clampf(y, _topbar_bottom_y() + 8.0, maxf(_topbar_bottom_y() + 8.0, vp.y - _loans_dialog.size.y - 8.0))
	_loans_dialog.position = Vector2(x, y)

func _on_loan_button_pressed(mode: String) -> void:
	if current_viewed_tag == "" or GameManager == null:
		zobraz_systemove_hlaseni("Chyba", "NejdĂ„Ä…Ă˘â€žËĂ„â€šĂ‚Â­v si vyber stĂ„â€šĂ‹â€ˇt.")
		return
	if current_viewed_tag == str(GameManager.hrac_stat).strip_edges().to_upper():
		zobraz_systemove_hlaseni("Chyba", "SĂ„â€šĂ‹â€ˇm sobÄ‚â€žĂ˘â‚¬Ĺź pĂ„Ä…ÄąÂ»jÄ‚â€žÄąÂ¤ku dĂ„â€šĂ‹â€ˇt nelze.")
		return
	
	# Store mode for later use in confirmation
	_loans_mode = mode
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	_aktualizuj_loans_dialog_cap(player_tag, current_viewed_tag)
	
	# Close other dialogs
	_zavri_vyzkum_dialog()
	
	# Show the loans dialog
	_pozicuj_loans_dialog()
	_loans_dialog.show()

# Reacts to incoming events.
func _on_loan_confirmed(principal_str: String, interest_str: String, turns_str: String) -> void:
	# Validate state
	var target = current_viewed_tag.strip_edges().to_upper()
	if target == "":
		zobraz_systemove_hlaseni("Chyba", "NejdĂ„Ä…Ă˘â€žËĂ„â€šĂ‚Â­v si vyber stĂ„â€šĂ‹â€ˇt.")
		return
	
	# Get player country
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	if player_tag == "":
		zobraz_systemove_hlaseni("Chyba", "HrĂ„â€šĂ‹â€ˇÄ‚â€žÄąÂ¤Ă„Ä…ÄąÂ»v stĂ„â€šĂ‹â€ˇt nebyl stanoven.")
		return
	if target == player_tag:
		zobraz_systemove_hlaseni("Chyba", "SĂ„â€šĂ‹â€ˇm sobÄ‚â€žĂ˘â‚¬Ĺź pĂ„Ä…ÄąÂ»jÄ‚â€žÄąÂ¤ku dĂ„â€šĂ‹â€ˇt nelze.")
		return
	
	# Parse and validate principal
	var principal = 0.0
	if principal_str.strip_edges() != "":
		principal = float(principal_str)
	if principal <= 0.0:
		zobraz_systemove_hlaseni("Chyba", "Ä‚â€žÄąĹˇĂ„â€šĂ‹â€ˇstka musĂ„â€šĂ‚Â­ bĂ„â€šĂ‹ĹĄt kladnĂ„â€šĂ‹â€ˇ.")
		return
	
	# Parse and validate interest
	var interest = 6.0
	if interest_str.strip_edges() != "":
		interest = float(interest_str)
		if interest < 0.0 or interest > 100.0:
			zobraz_systemove_hlaseni("Chyba", "Ă„â€šÄąË‡rok musĂ„â€šĂ‚Â­ bĂ„â€šĂ‹ĹĄt 0-100%.")
			return
	
	# Parse and validate turns
	var turns = 5
	if turns_str.strip_edges() != "":
		turns = int(turns_str)
	if turns < 5 or turns > 36:
		zobraz_systemove_hlaseni("Chyba", "Doba trvĂ„â€šĂ‹â€ˇnĂ„â€šĂ‚Â­ musĂ„â€šĂ‚Â­ bĂ„â€šĂ‹ĹĄt 5-36 kol.")
		return

	var max_principal = _ziskej_max_principal_pro_rezim(player_tag, target)
	if max_principal <= 0.0:
		zobraz_systemove_hlaseni("Chyba", "DostupnĂ„â€šĂ‚Â© funds pro tuto pĂ„Ä…ÄąÂ»jÄ‚â€žÄąÂ¤ku jsou 0.")
		return
	if principal > max_principal:
		principal = max_principal
		if _loan_principal_slider:
			_loan_principal_slider.set_value_no_signal(principal)
		if _loan_principal_input:
			_loan_principal_input.text = str(int(principal))
	
	# Create the loan
	if GameManager.has_method("_vytvor_statni_pujcku"):
		if _loans_mode == "give":
			# Player is lender, target is borrower.
			var result: Dictionary = {}
			if GameManager.has_method("navrhni_statni_pujcku"):
				result = GameManager.navrhni_statni_pujcku(player_tag, target, principal, interest, turns, player_tag)
			else:
				result = GameManager._vytvor_statni_pujcku(player_tag, target, principal, interest, turns)
			if bool(result.get("ok", false)):
				zobraz_systemove_hlaseni("PĂ„Ä…ÄąÂ»jÄ‚â€žÄąÂ¤ka nabĂ„â€šĂ‚Â­dnuta", "NabĂ„â€šĂ‚Â­dnuto %.0f M za %.1f%% na %d kol stĂ„â€šĂ‹â€ˇtu %s." % [principal, interest, turns, _ziskej_jmeno_statu_podle_tagu(target)])
				_loans_dialog.hide()
			else:
				zobraz_systemove_hlaseni("Chyba", str(result.get("reason", "Selhalo.")))
		else:  # "take"
			# Player is borrower, target is lender.
			var result: Dictionary = {}
			if GameManager.has_method("navrhni_statni_pujcku"):
				result = GameManager.navrhni_statni_pujcku(target, player_tag, principal, interest, turns, player_tag)
			else:
				result = GameManager._vytvor_statni_pujcku(target, player_tag, principal, interest, turns)
			if bool(result.get("ok", false)):
				zobraz_systemove_hlaseni("PĂ„Ä…ÄąÂ»jÄ‚â€žÄąÂ¤ka poĂ„Ä…Ă„ÄľadovĂ„â€šĂ‹â€ˇna", "PoĂ„Ä…Ă„ÄľadovĂ„â€šĂ‹â€ˇno %.0f M za %.1f%% na %d kol od stĂ„â€šĂ‹â€ˇtu %s." % [principal, interest, turns, _ziskej_jmeno_statu_podle_tagu(target)])
				_loans_dialog.hide()
			else:
				zobraz_systemove_hlaseni("Chyba", str(result.get("reason", "Selhalo.")))

# ---- Alliance Dialog ----

func _vytvor_alliance_dialog() -> void:
	_alliance_dialog = PanelContainer.new()
	_alliance_dialog.name = "AllianceDialog"
	_alliance_dialog.custom_minimum_size = Vector2(520, 400)
	_alliance_dialog.visible = false
	add_child(_alliance_dialog)

	var style = _vytvor_ingame_kartu_styl(Color(0.07, 0.10, 0.16, 0.96), Color(0.40, 0.60, 0.90, 0.55))
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	_alliance_dialog.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_alliance_dialog.add_child(main_vbox)

	# Title row
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	_alliance_dialog_title = Label.new()
	_alliance_dialog_title.text = "Alliance Management"
	_alliance_dialog_title.add_theme_font_size_override("font_size", 18)
	_alliance_dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_alliance_dialog_title)

	_alliance_dialog_close_btn = Button.new()
	_alliance_dialog_close_btn.text = "X"
	_alliance_dialog_close_btn.custom_minimum_size = Vector2(32, 0)
	_alliance_dialog_close_btn.pressed.connect(_zavri_alliance_dialog)
	title_row.add_child(_alliance_dialog_close_btn)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Scroll area for alliance list
	_alliance_dialog_scroll = ScrollContainer.new()
	_alliance_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alliance_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_alliance_dialog_scroll)

	_alliance_dialog_list = VBoxContainer.new()
	_alliance_dialog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alliance_dialog_list.add_theme_constant_override("separation", 6)
	_alliance_dialog_scroll.add_child(_alliance_dialog_list)

	# Bottom buttons
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(bottom_row)

	_alliance_dialog_create_btn = Button.new()
	_alliance_dialog_create_btn.text = "Create new alliance"
	_alliance_dialog_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alliance_dialog_create_btn.pressed.connect(_on_alliance_create_pressed)
	_aplikuj_ingame_tlacitko_styl(_alliance_dialog_create_btn, false)
	bottom_row.add_child(_alliance_dialog_create_btn)

	var close_btn2 = Button.new()
	close_btn2.text = "Close"
	close_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn2.pressed.connect(_zavri_alliance_dialog)
	_aplikuj_ingame_tlacitko_styl(close_btn2, false)
	bottom_row.add_child(close_btn2)

# Builds UI objects and default wiring.
func _vytvor_alliance_create_popup() -> void:
	_alliance_create_popup = PanelContainer.new()
	_alliance_create_popup.name = "AllianceCreatePopup"
	_alliance_create_popup.custom_minimum_size = Vector2(400, 240)
	_alliance_create_popup.visible = false
	add_child(_alliance_create_popup)

	var style = _vytvor_ingame_kartu_styl(Color(0.08, 0.12, 0.18, 0.98), Color(0.50, 0.72, 0.95, 0.65))
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	_alliance_create_popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_alliance_create_popup.add_child(vbox)

	var title = Label.new()
	title.text = "Create New Alliance"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	vbox.add_child(name_row)

	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_lbl)

	_alliance_create_name_input = LineEdit.new()
	_alliance_create_name_input.placeholder_text = "Alliance name..."
	_alliance_create_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_alliance_create_name_input)

	var level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	vbox.add_child(level_row)

	var level_lbl = Label.new()
	level_lbl.text = "Type:"
	level_lbl.custom_minimum_size = Vector2(60, 0)
	level_row.add_child(level_lbl)

	_alliance_create_level_option = OptionButton.new()
	_alliance_create_level_option.add_item("Defensive Alliance", 1)
	_alliance_create_level_option.add_item("Offensive Alliance", 2)
	_alliance_create_level_option.add_item("Full Alliance", 3)
	_alliance_create_level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(_alliance_create_level_option)

	var color_row = HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	vbox.add_child(color_row)

	var color_lbl = Label.new()
	color_lbl.text = "Color:"
	color_lbl.custom_minimum_size = Vector2(60, 0)
	color_row.add_child(color_lbl)

	_alliance_create_color_picker = ColorPickerButton.new()
	_alliance_create_color_picker.color = Color(0.27, 0.53, 1.0)
	_alliance_create_color_picker.custom_minimum_size = Vector2(120, 0)
	_alliance_create_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(_alliance_create_color_picker)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_alliance_create_confirm_btn = Button.new()
	_alliance_create_confirm_btn.text = "Create"
	_alliance_create_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alliance_create_confirm_btn.pressed.connect(_on_alliance_create_confirm)
	_aplikuj_ingame_tlacitko_styl(_alliance_create_confirm_btn, false)
	btn_row.add_child(_alliance_create_confirm_btn)

	_alliance_create_cancel_btn = Button.new()
	_alliance_create_cancel_btn.text = "Cancel"
	_alliance_create_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alliance_create_cancel_btn.pressed.connect(_zavri_alliance_create_popup)
	_aplikuj_ingame_tlacitko_styl(_alliance_create_cancel_btn, false)
	btn_row.add_child(_alliance_create_cancel_btn)

func _pozicuj_alliance_dialog() -> void:
	if not _alliance_dialog:
		return
	var vp = get_viewport().get_visible_rect().size
	_alliance_dialog.position = Vector2((vp.x - _alliance_dialog.custom_minimum_size.x) * 0.5, (vp.y - _alliance_dialog.custom_minimum_size.y) * 0.5)

# Feature logic entry point.
func _pozicuj_alliance_create_popup() -> void:
	if not _alliance_create_popup:
		return
	var vp = get_viewport().get_visible_rect().size
	_alliance_create_popup.position = Vector2((vp.x - _alliance_create_popup.custom_minimum_size.x) * 0.5, (vp.y - _alliance_create_popup.custom_minimum_size.y) * 0.35)

# Closes the active UI flow and clears temporary interaction context.
func _zavri_alliance_dialog() -> void:
	if _ceka_na_vyber_trade_aliance:
		_trade_zrus_vyber_aliance_z_menu(true)
	if _alliance_dialog:
		_alliance_dialog.visible = false
	_zavri_alliance_create_popup()

func _zavri_alliance_create_popup() -> void:
	if _alliance_create_popup:
		_alliance_create_popup.visible = false

# Opens a UI flow/panel and prepares its data and position.
func _otevri_alliance_dialog(target_tag: String) -> void:
	_alliance_dialog_target_tag = target_tag
	_obnov_alliance_dialog_obsah(target_tag)
	_pozicuj_alliance_dialog()
	if _alliance_dialog:
		_alliance_dialog.visible = true

func _obnov_alliance_dialog_obsah(target_tag: String) -> void:
	if not _alliance_dialog_list:
		return

	# Clear old content
	for c in _alliance_dialog_list.get_children():
		c.queue_free()

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var target = target_tag.strip_edges().to_upper()
	var target_name = _ziskej_jmeno_statu_podle_tagu(target)
	if _ceka_na_vyber_trade_aliance:
		if _alliance_dialog_title:
			_alliance_dialog_title.text = "Select Alliance for %s" % _ziskej_jmeno_statu_podle_tagu(_trade_alliance_pick_provider_tag)
		if _alliance_dialog_create_btn:
			_alliance_dialog_create_btn.visible = false

		var all_alliances: Array = []
		if GameManager.has_method("_ziskej_vsechny_aliance_skupiny"):
			all_alliances = GameManager._ziskej_vsechny_aliance_skupiny() as Array
		if all_alliances.is_empty():
			var empty_trade_label = Label.new()
			empty_trade_label.text = "No alliance exists yet."
			empty_trade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_trade_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			_alliance_dialog_list.add_child(empty_trade_label)
		else:
			for alliance in all_alliances:
				_pridej_alliance_kartu(alliance, _trade_alliance_pick_provider_tag, "trade_select")
		return

	var player_alliances: Array = []
	if GameManager.has_method("ziskej_aliance_statu"):
		player_alliances = GameManager.ziskej_aliance_statu(player_tag) as Array

	var is_own = (target == player_tag)

	if is_own:
		# --- OWN COUNTRY VIEW: manage my alliances ---
		if _alliance_dialog_title:
			_alliance_dialog_title.text = "My Alliances"
		if _alliance_dialog_create_btn:
			_alliance_dialog_create_btn.text = "Create Alliance"
			_alliance_dialog_create_btn.visible = true

		if player_alliances.is_empty():
			var empty_label = Label.new()
			empty_label.text = "You have no alliances yet.\nClick 'Create Alliance' to found one."
			empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			_alliance_dialog_list.add_child(empty_label)
		else:
			for alliance in player_alliances:
				_pridej_alliance_kartu(alliance, "", "own")
	else:
		# --- OTHER COUNTRY VIEW: invite into alliance ---
		if _alliance_dialog_title:
			_alliance_dialog_title.text = "Invite %s into Alliance" % target_name
		if _alliance_dialog_create_btn:
			_alliance_dialog_create_btn.visible = false

		if player_alliances.is_empty():
			var empty_label = Label.new()
			empty_label.text = "You have no alliances.\nClick your own country to create one first."
			empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			_alliance_dialog_list.add_child(empty_label)
		else:
			for alliance in player_alliances:
				_pridej_alliance_kartu(alliance, target, "invite")

			# Bilateral relationship status
			var sep2 = HSeparator.new()
			_alliance_dialog_list.add_child(sep2)

			var bilateral_level = 0
			if GameManager.has_method("ziskej_uroven_aliance"):
				bilateral_level = int(GameManager.ziskej_uroven_aliance(player_tag, target))
			var rel = 0.0
			if GameManager.has_method("ziskej_vztah_statu"):
				rel = float(GameManager.ziskej_vztah_statu(player_tag, target))
			var level_name = "No Alliance"
			if GameManager.has_method("nazev_urovne_aliance"):
				level_name = str(GameManager.nazev_urovne_aliance(bilateral_level))
			var bilateral_label = Label.new()
			bilateral_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bilateral_label.text = "Bilateral status with %s: %s (relation: %.1f)" % [target_name, level_name, rel]
			_alliance_dialog_list.add_child(bilateral_label)

# Main runtime logic lives here.
func _pridej_alliance_kartu(alliance: Dictionary, target_tag: String, view_mode: String = "own") -> void:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.14, 0.22, 0.85)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.35, 0.55, 0.85, 0.50)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 10
	card_style.content_margin_top = 8
	card_style.content_margin_right = 10
	card_style.content_margin_bottom = 8
	# Tint border with alliance color if available
	var alliance_color_hex = str(alliance.get("color", "#4488ff"))
	var parsed_color = Color.html(alliance_color_hex) if alliance_color_hex.begins_with("#") else Color(0.27, 0.53, 1.0)
	card_style.border_color = Color(parsed_color.r, parsed_color.g, parsed_color.b, 0.75)
	card.add_theme_stylebox_override("panel", card_style)
	_alliance_dialog_list.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var alliance_id = str(alliance.get("id", ""))
	var alliance_name = str(alliance.get("name", "Alliance"))
	var level = int(alliance.get("level", 0))
	var members = alliance.get("members", []) as Array
	var founder = str(alliance.get("founder", ""))
	var created_turn = int(alliance.get("created_turn", 0))

	var level_name = "Unknown"
	if GameManager.has_method("nazev_urovne_aliance"):
		level_name = str(GameManager.nazev_urovne_aliance(level))

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl = Label.new()
	title_lbl.text = "%s (%s)" % [alliance_name, level_name]
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title_lbl)

	# Color swatch
	var color_swatch = ColorRect.new()
	color_swatch.color = parsed_color
	color_swatch.custom_minimum_size = Vector2(18, 18)
	title_row.add_child(color_swatch)

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var target = target_tag.strip_edges().to_upper()
	var is_founder = (founder == player_tag)

	# Members label
	var members_text = "Members: "
	var member_names: Array = []
	for m in members:
		member_names.append(_ziskej_jmeno_statu_podle_tagu(str(m)))
	members_text += ", ".join(member_names)
	var members_lbl = Label.new()
	members_lbl.text = members_text
	members_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	members_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	members_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(members_lbl)

	# Created info
	var info_lbl = Label.new()
	info_lbl.text = "Founded by %s, turn %d" % [_ziskej_jmeno_statu_podle_tagu(founder), created_turn]
	info_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	info_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_lbl)

	# Conditions for target to join (only in invite mode, and if not already member)
	var target_is_member = members.has(target)
	if (view_mode == "invite" or view_mode == "trade_select") and not target_is_member and target != "" and GameManager.has_method("ziskej_podminky_clenstvi_aliance"):
		var conditions = GameManager.ziskej_podminky_clenstvi_aliance(alliance_id, target) as Array
		if not conditions.is_empty():
			var cond_title = Label.new()
			cond_title.text = "Conditions for %s to join:" % _ziskej_jmeno_statu_podle_tagu(target)
			cond_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
			cond_title.add_theme_font_size_override("font_size", 13)
			vbox.add_child(cond_title)

			for cond in conditions:
				var cond_label = Label.new()
				var member_name = _ziskej_jmeno_statu_podle_tagu(str(cond.get("member", "")))
				var cond_rel = float(cond.get("relation", 0))
				var needed = float(cond.get("needed", 0))
				var met = bool(cond.get("met", false))
				var both_human = bool(cond.get("both_human", false))
				var forced_by_overlord = bool(cond.get("forced_by_overlord", false))
				var overlord_name = _ziskej_jmeno_statu_podle_tagu(str(cond.get("overlord", "")))
				var at_war = bool(cond.get("at_war", false))

				if forced_by_overlord:
					cond_label.text = "  %s: Forced (vassal of %s)" % [member_name, overlord_name]
					cond_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
				elif both_human:
					cond_label.text = "  %s: Auto (both players)" % member_name
					cond_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
				elif at_war:
					cond_label.text = "  %s: AT WAR" % member_name
					cond_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
				elif met:
					cond_label.text = "  %s: %.1f / %.1f [OK]" % [member_name, cond_rel, needed]
					cond_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
				else:
					cond_label.text = "  %s: %.1f / %.1f [MISSING]" % [member_name, cond_rel, needed]
					cond_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
				cond_label.add_theme_font_size_override("font_size", 12)
				cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(cond_label)

	# Action buttons differ by view mode.
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	if view_mode == "invite":
		# Invite mode: only show invite button (+ conditions are shown above)
		if not target_is_member and target != "":
			var invite_btn = Button.new()
			invite_btn.text = "Invite %s" % _ziskej_jmeno_statu_podle_tagu(target)
			invite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var aid_copy = alliance_id
			var target_copy = target
			invite_btn.pressed.connect(func(): _on_alliance_invite_pressed(aid_copy, target_copy))
			_aplikuj_ingame_tlacitko_styl(invite_btn, false)
			btn_row.add_child(invite_btn)
		else:
			var already_lbl = Label.new()
			already_lbl.text = "%s is already a member." % _ziskej_jmeno_statu_podle_tagu(target)
			already_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
			already_lbl.add_theme_font_size_override("font_size", 12)
			btn_row.add_child(already_lbl)
	elif view_mode == "trade_select":
		if target_is_member:
			var already_in_lbl = Label.new()
			already_in_lbl.text = "%s is already a member." % _ziskej_jmeno_statu_podle_tagu(target)
			already_in_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
			already_in_lbl.add_theme_font_size_override("font_size", 12)
			btn_row.add_child(already_in_lbl)
		else:
			var select_btn = Button.new()
			select_btn.text = "Select for Trade"
			select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var can_select = true
			if GameManager.has_method("ziskej_podminky_clenstvi_aliance"):
				var trade_conditions = GameManager.ziskej_podminky_clenstvi_aliance(alliance_id, target) as Array
				for cond_any in trade_conditions:
					var cond = cond_any as Dictionary
					if not bool(cond.get("met", false)):
						can_select = false
						break
			select_btn.disabled = not can_select
			var aid_trade = alliance_id
			var aname_trade = alliance_name
			select_btn.pressed.connect(func(): _trade_vyber_aliance_z_menu(aid_trade, aname_trade))
			_aplikuj_ingame_tlacitko_styl(select_btn, false)
			btn_row.add_child(select_btn)
	else:
		# Own mode: leave / kick / disband
		var leave_btn = Button.new()
		leave_btn.text = "Leave"
		leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var aid_copy3 = alliance_id
		leave_btn.pressed.connect(func(): _on_alliance_leave_pressed(aid_copy3))
		_aplikuj_ingame_tlacitko_styl(leave_btn, true)
		btn_row.add_child(leave_btn)

		if is_founder:
			var disband_btn = Button.new()
			disband_btn.text = "Disband"
			disband_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var aid_copy4 = alliance_id
			disband_btn.pressed.connect(func(): _on_alliance_disband_pressed(aid_copy4))
			_aplikuj_ingame_tlacitko_styl(disband_btn, true)
			btn_row.add_child(disband_btn)

func _on_alliance_create_pressed() -> void:
	if _alliance_create_popup:
		if _alliance_create_name_input:
			_alliance_create_name_input.text = ""
		if _alliance_create_level_option:
			_alliance_create_level_option.select(0)
		if _alliance_create_color_picker:
			_alliance_create_color_picker.color = Color(0.27, 0.53, 1.0)
		# Update popup title (own view: "Create New Alliance")
		var popup_title_lbl = _alliance_create_popup.get_node_or_null("VBoxContainer/Label")
		if popup_title_lbl:
			popup_title_lbl.text = "Create New Alliance"
		_pozicuj_alliance_create_popup()
		_alliance_create_popup.visible = true

func _on_alliance_create_confirm() -> void:
	if not GameManager.has_method("vytvor_alianci_skupinu"):
		return
	var name_text = ""
	if _alliance_create_name_input:
		name_text = _alliance_create_name_input.text.strip_edges()
	if name_text == "":
		name_text = "Alliance"
	var level_idx = 0
	if _alliance_create_level_option:
		level_idx = _alliance_create_level_option.selected
	var level = _alliance_create_level_option.get_item_id(level_idx) if _alliance_create_level_option else 1
	var color_hex = "#4488ff"
	if _alliance_create_color_picker:
		color_hex = "#" + _alliance_create_color_picker.color.to_html(false)

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()

	var result = GameManager.vytvor_alianci_skupinu(name_text, level, player_tag, [], color_hex)
	if not bool(result.get("ok", false)):
		zobraz_systemove_hlaseni("Alliance", str(result.get("reason", "Failed to create alliance.")))
		return

	_zavri_alliance_create_popup()
	_obnov_alliance_dialog_obsah(_alliance_dialog_target_tag)
	_aktualizuj_aliance_ui(_alliance_dialog_target_tag)
	_aktualizuj_diplomacii_tlacitka(_alliance_dialog_target_tag)
	_aktualizuj_panel_zprav()

func _on_alliance_invite_pressed(alliance_id: String, target_tag: String) -> void:
	if not GameManager.has_method("pridej_clena_do_aliance"):
		return
	var target_clean = str(target_tag).strip_edges().to_upper()
	var target_is_human = GameManager.has_method("je_lidsky_stat") and bool(GameManager.je_lidsky_stat(target_clean))

	var forced_by_overlord_member = false
	if GameManager.has_method("ziskej_alianci_podle_id") and GameManager.has_method("ziskej_overlorda_statu"):
		var grp = GameManager.ziskej_alianci_podle_id(alliance_id) as Dictionary
		var members = grp.get("members", []) as Array
		var target_overlord = str(GameManager.ziskej_overlorda_statu(target_clean)).strip_edges().to_upper()
		forced_by_overlord_member = (target_overlord != "" and members.has(target_overlord))

	if target_is_human and not forced_by_overlord_member:
		if not GameManager.has_method("odeslat_aliancni_zadost") or not GameManager.has_method("ziskej_alianci_podle_id"):
			zobraz_systemove_hlaseni("Alliance", "Cannot send alliance request in current game state.")
			return
		var grp_info = GameManager.ziskej_alianci_podle_id(alliance_id) as Dictionary
		var lvl = int(grp_info.get("level", 1))
		var sent = bool(GameManager.odeslat_aliancni_zadost(GameManager.hrac_stat, target_clean, lvl, true))
		if not sent:
			zobraz_systemove_hlaseni("Alliance", "Alliance request could not be sent.")
		else:
			var sender_name = _ziskej_jmeno_statu_podle_tagu(str(GameManager.hrac_stat).strip_edges().to_upper())
			var target_name = _ziskej_jmeno_statu_podle_tagu(target_clean)
			zobraz_systemove_hlaseni("Alliance", "Alliance request sent: %s -> %s. %s can accept or decline it." % [sender_name, target_name, target_name])
	else:
		var ignoruj = target_is_human
		var result = GameManager.pridej_clena_do_aliance(alliance_id, target_clean, ignoruj)
		if not bool(result.get("ok", false)):
			zobraz_systemove_hlaseni("Alliance", str(result.get("reason", "Failed to add member.")))
	_obnov_alliance_dialog_obsah(_alliance_dialog_target_tag)
	_aktualizuj_aliance_ui(_alliance_dialog_target_tag)
	_aktualizuj_diplomacii_tlacitka(_alliance_dialog_target_tag)
	_aktualizuj_panel_zprav()

func _on_alliance_kick_pressed(alliance_id: String, target_tag: String) -> void:
	if not GameManager.has_method("odeber_clena_z_aliance"):
		return
	GameManager.odeber_clena_z_aliance(alliance_id, target_tag)
	_obnov_alliance_dialog_obsah(_alliance_dialog_target_tag)
	_aktualizuj_aliance_ui(_alliance_dialog_target_tag)
	_aktualizuj_diplomacii_tlacitka(_alliance_dialog_target_tag)
	_aktualizuj_panel_zprav()

func _on_alliance_leave_pressed(alliance_id: String) -> void:
	if not GameManager.has_method("odeber_clena_z_aliance"):
		return
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	GameManager.odeber_clena_z_aliance(alliance_id, player_tag)
	_obnov_alliance_dialog_obsah(_alliance_dialog_target_tag)
	_aktualizuj_aliance_ui(_alliance_dialog_target_tag)
	_aktualizuj_diplomacii_tlacitka(_alliance_dialog_target_tag)
	_aktualizuj_panel_zprav()

func _on_alliance_disband_pressed(alliance_id: String) -> void:
	if not GameManager.has_method("rozpust_alianci"):
		return
	GameManager.rozpust_alianci(alliance_id)
	_obnov_alliance_dialog_obsah(_alliance_dialog_target_tag)
	_aktualizuj_aliance_ui(_alliance_dialog_target_tag)
	_aktualizuj_diplomacii_tlacitka(_alliance_dialog_target_tag)
	_aktualizuj_panel_zprav()

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
	if conf_id != -1 and conf_id == _peace_notice_deferred_conf_id:
		_peace_notice_panel.hide()
		return
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

# Core flow for this feature.
func _potlac_hlaseni_miru_do_dalsi_konference() -> void:
	if _peace_notice_panel == null:
		return
	if GameManager and GameManager.has_method("ziskej_prvni_mirovou_konferenci_pro_hrace"):
		var conf = GameManager.ziskej_prvni_mirovou_konferenci_pro_hrace(GameManager.hrac_stat) as Dictionary
		if not conf.is_empty():
			_peace_notice_deferred_conf_id = int(conf.get("id", -1))
	_peace_notice_panel.hide()
	_aktualizuj_pozice_popupu()

func _on_peace_notice_open_pressed() -> void:
	_otevri_mirovou_konferenci_z_fronty()

func ma_otevrene_mirove_jednani() -> bool:
	return _peace_dialog != null and _peace_dialog.visible

# Feature logic entry point.
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

# Refresh pass for current state.
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

# Callback for UI/game events.
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

# Cancels the active flow and restores a safe default state.
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

# Opens a UI flow/panel and prepares its data and position.
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

func _on_trade_button_pressed() -> void:
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	_otevri_trade_dialog(current_viewed_tag)

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

func _trade_option_specs() -> Array:
	return [
		{"slot": "gold", "label": "Money", "placeholder_a": "Amount (mil. USD)", "placeholder_b": "Currency / note"},
		{"slot": "province", "label": "Provinces", "placeholder_a": "Province ID / name", "placeholder_b": "Count / note"},
		{"slot": "declare_war", "label": "Declare War", "placeholder_a": "Target TAG", "placeholder_b": "Reason / note"},
		{"slot": "join_alliance", "label": "Join Alliance", "placeholder_a": "Alliance ID", "placeholder_b": "Alliance name"},
		{"slot": "improve_relationship_with", "label": "Improve Relations With", "placeholder_a": "Target TAG", "placeholder_b": "Optional note"},
		{"slot": "worsen_relationship_with", "label": "Worsen Relations With", "placeholder_a": "Target TAG", "placeholder_b": "Optional note"},
		{"slot": "non_aggression", "label": "Non-Aggression Pact", "placeholder_a": "Duration", "placeholder_b": "Note"}
	]

func _trade_option_spec(slot: String) -> Dictionary:
	for spec_any in _trade_option_specs():
		var spec = spec_any as Dictionary
		if str(spec.get("slot", "")) == slot:
			return spec
	return {}

func _vytvor_trade_dialog() -> void:
	if _trade_dialog != null:
		return
	_trade_dialog = PopupPanel.new()
	_trade_dialog.name = "TradeDialog"
	_trade_dialog.wrap_controls = false
	_trade_dialog.unresizable = true
	_trade_dialog.min_size = Vector2i(760, 500)
	_trade_dialog.size = Vector2(960, 620)
	_trade_dialog.exclusive = false
	_trade_dialog.popup_window = false
	add_child(_trade_dialog)
	_aplikuj_ingame_popup_styl(_trade_dialog)

	var margin = MarginContainer.new()
	margin.offset_left = 10
	margin.offset_top = 10
	margin.offset_right = -10
	margin.offset_bottom = -10
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_dialog.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_trade_title_label = Label.new()
	_trade_title_label.text = "Trade Request"
	_trade_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_title_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_trade_title_label)

	_trade_success_label = Label.new()
	_trade_success_label.text = "Configure terms and send"
	_trade_success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_success_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.44, 1.0))
	root.add_child(_trade_success_label)

	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# Left panel is foreign state, right panel is player state.
	split.add_child(_trade_vytvor_stranu(1))
	split.add_child(_trade_vytvor_stranu(0))

	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.custom_minimum_size = Vector2(0, 46)
	root.add_child(bottom)

	var send_btn = Button.new()
	send_btn.text = "Send offer"
	send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_btn.custom_minimum_size = Vector2(0, 38)
	_aplikuj_ingame_tlacitko_styl(send_btn)
	send_btn.pressed.connect(_on_trade_send_pressed)
	bottom.add_child(send_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.custom_minimum_size = Vector2(0, 38)
	_aplikuj_ingame_tlacitko_styl(close_btn)
	close_btn.pressed.connect(_trade_close_dialog)
	bottom.add_child(close_btn)
	_trade_vytvor_province_picker_popup()

# Main runtime logic lives here.
func _trade_close_dialog() -> void:
	_trade_zrus_vyber_provincii_z_mapy(false)
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	_trade_zrus_vyber_aliance_z_menu(false)
	if _trade_dialog:
		_trade_dialog.hide()

# Condition check helper.
func je_aktivni_vyber_trade_valky_na_mape() -> bool:
	return _ceka_na_vyber_trade_war_cile

# Returns true when conditions are met.
func je_platny_trade_cil_statu_na_mape(owner_tag: String) -> bool:
	if not _ceka_na_vyber_trade_war_cile:
		return false
	var target_tag = owner_tag.strip_edges().to_upper()
	if target_tag == "" or target_tag == "SEA":
		return false
	if target_tag == _trade_war_provider_tag:
		return false
	if _trade_war_pick_slot == "declare_war" and target_tag == _trade_war_receiver_tag:
		return false
	return true

func zrus_vyber_trade_valecneho_cile_ui() -> void:
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)

# Handles this gameplay/UI path.
func _trade_otevri_join_alliance_picker(side: int) -> void:
	_trade_zrus_vyber_provincii_z_mapy(false)
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	var provider_tag = str(GameManager.hrac_stat).strip_edges().to_upper() if side == 0 else _trade_target_tag
	if provider_tag == "" or provider_tag == "SEA":
		zobraz_systemove_hlaseni("Trade", "Invalid state for alliance selection.")
		return
	if _ceka_na_vyber_trade_aliance and _trade_alliance_pick_side == side:
		_trade_zrus_vyber_aliance_z_menu()
		return

	_ceka_na_vyber_trade_aliance = true
	_trade_alliance_pick_side = side
	_trade_alliance_pick_provider_tag = provider_tag
	_trade_dialog_hidden_for_alliance_pick = _trade_dialog != null and _trade_dialog.visible
	if _trade_dialog_hidden_for_alliance_pick and _trade_dialog:
		_trade_dialog.hide()
	_otevri_alliance_dialog(provider_tag)

# Runs the local feature logic.
func _trade_zrus_vyber_aliance_z_menu(obnovit_hlavni_dialog: bool = true) -> void:
	_ceka_na_vyber_trade_aliance = false
	_trade_alliance_pick_side = -1
	_trade_alliance_pick_provider_tag = ""
	if obnovit_hlavni_dialog and _trade_dialog and _trade_dialog_hidden_for_alliance_pick:
		_pozicuj_trade_dialog()
		_trade_dialog.popup()
		_pozicuj_trade_dialog()
	_trade_dialog_hidden_for_alliance_pick = false

func _trade_vyber_aliance_z_menu(alliance_id: String, alliance_name: String) -> void:
	if not _ceka_na_vyber_trade_aliance:
		return
	if alliance_id.strip_edges() == "":
		return
	var side = _trade_alliance_pick_side
	if side < 0:
		return
	_trade_side_values(side)["join_alliance"] = {
		"a": alliance_id.strip_edges(),
		"b": alliance_name.strip_edges()
	}
	_trade_set_selected_slot(side, "join_alliance")
	_trade_zrus_vyber_aliance_z_menu(true)
	if _alliance_dialog:
		_alliance_dialog.visible = false
	_trade_refresh_dialog_ui()

func obsluha_vyberu_trade_valky_z_mapy(data: Dictionary) -> bool:
	if not _ceka_na_vyber_trade_war_cile:
		return false
	var target_tag = str(data.get("owner", "")).strip_edges().to_upper()
	if not je_platny_trade_cil_statu_na_mape(target_tag):
		return true
	var side = _trade_war_pick_side
	var slot = _trade_war_pick_slot if _trade_war_pick_slot != "" else "declare_war"
	var note = "Map target"
	if slot == "improve_relationship_with":
		note = "Improve via map"
	elif slot == "worsen_relationship_with":
		note = "Worsen via map"
	_trade_side_values(side)[slot] = {
		"a": target_tag,
		"b": note
	}
	_trade_zrus_vyber_valecneho_cile_z_mapy(true)
	_trade_set_selected_slot(side, slot)
	_trade_refresh_dialog_ui()
	return true

# Main runtime logic lives here.
func _trade_vytvor_province_picker_popup() -> void:
	if _trade_province_picker_popup != null:
		return
	_trade_province_picker_popup = PopupPanel.new()
	_trade_province_picker_popup.name = "TradeProvincePicker"
	_trade_province_picker_popup.size = Vector2(360, 156)
	_trade_province_picker_popup.min_size = Vector2i(300, 130)
	_trade_province_picker_popup.exclusive = false
	_trade_province_picker_popup.popup_window = false
	add_child(_trade_province_picker_popup)
	_aplikuj_ingame_popup_styl(_trade_province_picker_popup)

	var margin = MarginContainer.new()
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_province_picker_popup.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_trade_province_picker_title = Label.new()
	_trade_province_picker_title.text = "Province Transfer Selection"
	_trade_province_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_province_picker_title.add_theme_font_size_override("font_size", 18)
	root.add_child(_trade_province_picker_title)

	_trade_province_picker_info = Label.new()
	_trade_province_picker_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_province_picker_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_province_picker_info.text = "Source: -"
	root.add_child(_trade_province_picker_info)

	_trade_province_picker_count = Label.new()
	_trade_province_picker_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_province_picker_count.text = "Selected provinces: 0"
	root.add_child(_trade_province_picker_count)

	var close_row = HBoxContainer.new()
	close_row.add_theme_constant_override("separation", 8)
	close_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(close_row)
	_trade_province_picker_confirm_btn = Button.new()
	_trade_province_picker_confirm_btn.text = "Confirm selection"
	_trade_province_picker_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aplikuj_ingame_tlacitko_styl(_trade_province_picker_confirm_btn)
	_trade_province_picker_confirm_btn.pressed.connect(_trade_potvrd_vyber_provincii_z_mapy)
	close_row.add_child(_trade_province_picker_confirm_btn)

	_trade_province_picker_cancel_btn = Button.new()
	_trade_province_picker_cancel_btn.text = "Cancel"
	_trade_province_picker_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aplikuj_ingame_tlacitko_styl(_trade_province_picker_cancel_btn, true)
	_trade_province_picker_cancel_btn.pressed.connect(_trade_zrus_vyber_provincii_z_mapy)
	close_row.add_child(_trade_province_picker_cancel_btn)

func _trade_seznam_provincii_statu(state_tag: String) -> Array:
	var tag = state_tag.strip_edges().to_upper()
	var out: Array = []
	if tag == "" or tag == "SEA":
		return out

	var provinces = _ziskej_vsechny_provincie_pro_prehled()
	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		if not provinces.has(p_id):
			continue
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != tag:
			continue
		if bool(d.get("is_capital", false)):
			continue
		out.append({
			"id": p_id,
			"name": str(d.get("province_name", "Province %d" % p_id)),
			"gdp": float(d.get("gdp", 0.0))
		})

	out.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		return float(da.get("gdp", 0.0)) > float(db.get("gdp", 0.0))
	)
	return out

# Core flow for this feature.
func _trade_otevri_province_picker(side: int) -> void:
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	_trade_zrus_vyber_aliance_z_menu(false)
	var source_tag = str(GameManager.hrac_stat).strip_edges().to_upper() if side == 0 else _trade_target_tag
	if source_tag == "":
		zobraz_systemove_hlaseni("Trade", "No source state selected for province transfer.")
		return
	var map_node = _ziskej_map_node_pro_mir()
	if map_node == null:
		zobraz_systemove_hlaseni("Trade", "Map module was not found.")
		return
	if not map_node.has_method("aktivuj_rezim_vyberu_trade_provincie"):
		zobraz_systemove_hlaseni("Trade", "Map does not support trade province selection.")
		return

	if _ceka_na_vyber_trade_provincie and _trade_map_pick_side == side:
		# druhy klik na stejny picker funguje jako rychly cancel/toggle.
		_trade_zrus_vyber_provincii_z_mapy()
		return

	var editor = _trade_side_editor(side)
	var preselected: Array = []
	var values = _trade_side_values(side)
	if values.has("province"):
		var province_entry = values["province"] as Dictionary
		preselected = _trade_parse_selected_province_ids(str(province_entry.get("a", "")))
	elif not editor.is_empty():
		preselected = _trade_parse_selected_province_ids((editor["input_a"] as LineEdit).text)

	var activation = map_node.aktivuj_rezim_vyberu_trade_provincie(source_tag, preselected)
	# map node vraci validacni result; UI nic nepredpoklada naslepo.
	if not bool((activation as Dictionary).get("ok", false)):
		zobraz_systemove_hlaseni("Trade", str((activation as Dictionary).get("reason", "Failed to start map selection.")))
		return

	_trade_map_pick_side = side
	_trade_map_pick_source_tag = source_tag
	_ceka_na_vyber_trade_provincie = true
	_trade_map_selected_ids = ((activation as Dictionary).get("selected", []) as Array).duplicate()
	_trade_dialog_hidden_for_map_pick = _trade_dialog != null and _trade_dialog.visible
	if _trade_dialog_hidden_for_map_pick:
		_trade_dialog.hide()
	_trade_obnov_popup_vyberu_provincii_info()
	if _trade_province_picker_popup:
		_trade_pozicuj_province_picker_popup()
		_trade_province_picker_popup.popup()
		_trade_pozicuj_province_picker_popup()
	_trade_refresh_dialog_ui()
	zobraz_systemove_hlaseni("Trade", "Click state territory on map for %s and confirm in small panel." % source_tag)

func _trade_otevri_declare_war_picker(side: int) -> void:
	_trade_otevri_country_relation_picker(side, "declare_war")

func _trade_otevri_country_relation_picker(side: int, slot: String) -> void:
	_trade_zrus_vyber_provincii_z_mapy(false)
	_trade_zrus_vyber_aliance_z_menu(false)
	var provider_tag = str(GameManager.hrac_stat).strip_edges().to_upper() if side == 0 else _trade_target_tag
	var receiver_tag = _trade_target_tag if side == 0 else str(GameManager.hrac_stat).strip_edges().to_upper()
	if provider_tag == "" or provider_tag == "SEA" or receiver_tag == "":
		zobraz_systemove_hlaseni("Trade", "Invalid states for country target selection.")
		return
	if _ceka_na_vyber_trade_war_cile and _trade_war_pick_side == side and _trade_war_pick_slot == slot:
		_trade_zrus_vyber_valecneho_cile_z_mapy()
		return

	_trade_war_pick_side = side
	_trade_war_provider_tag = provider_tag
	_trade_war_receiver_tag = receiver_tag
	_trade_war_pick_slot = slot
	_ceka_na_vyber_trade_war_cile = true
	_trade_dialog_hidden_for_war_pick = _trade_dialog != null and _trade_dialog.visible
	if _trade_dialog_hidden_for_war_pick:
		_trade_dialog.hide()
	_trade_refresh_dialog_ui()
	var action_name = "Declare War target"
	if slot == "improve_relationship_with":
		action_name = "Improve Relations target"
	elif slot == "worsen_relationship_with":
		action_name = "Worsen Relations target"
	zobraz_systemove_hlaseni("Trade", "Click target state territory for %s by %s." % [action_name, provider_tag])

func _trade_zrus_vyber_valecneho_cile_z_mapy(obnovit_hlavni_dialog: bool = true) -> void:
	_ceka_na_vyber_trade_war_cile = false
	_trade_war_pick_side = -1
	_trade_war_provider_tag = ""
	_trade_war_receiver_tag = ""
	_trade_war_pick_slot = ""
	if obnovit_hlavni_dialog and _trade_dialog and _trade_dialog_hidden_for_war_pick:
		_pozicuj_trade_dialog()
		_trade_dialog.popup()
		_pozicuj_trade_dialog()
	_trade_dialog_hidden_for_war_pick = false

# Runs the local feature logic.
func obsluha_vyberu_trade_provincie_z_mapy(result: Dictionary, _province_id: int) -> void:
	if not _ceka_na_vyber_trade_provincie:
		return
	if not bool(result.get("ok", false)):
		return
	_trade_map_selected_ids = (result.get("selected", []) as Array).duplicate()
	_trade_obnov_popup_vyberu_provincii_info()

# Main runtime logic lives here.
func _trade_obnov_popup_vyberu_provincii_info() -> void:
	if _trade_province_picker_info:
		_trade_province_picker_info.text = "Source state: %s" % (_trade_map_pick_source_tag if _trade_map_pick_source_tag != "" else "-")
	if _trade_province_picker_count:
		_trade_province_picker_count.text = "Selected provinces: %d" % _trade_map_selected_ids.size()
	if _trade_province_picker_confirm_btn:
		_trade_province_picker_confirm_btn.disabled = _trade_map_selected_ids.is_empty()
	if _trade_province_picker_popup and _trade_province_picker_popup.visible:
		_trade_pozicuj_province_picker_popup()

func _trade_pozicuj_province_picker_popup() -> void:
	if _trade_province_picker_popup == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = _trade_province_picker_popup.size
	if panel_size.x < float(_trade_province_picker_popup.min_size.x):
		panel_size.x = float(_trade_province_picker_popup.min_size.x)
	if panel_size.y < float(_trade_province_picker_popup.min_size.y):
		panel_size.y = float(_trade_province_picker_popup.min_size.y)
	_trade_province_picker_popup.size = panel_size

	var margin = 12.0
	var x = viewport_size.x - panel_size.x - margin
	var y = viewport_size.y - panel_size.y - margin
	var next_btn = get_tree().current_scene.find_child("NextTurnButton", true, false) as Control
	if next_btn and next_btn.is_visible_in_tree():
		x = minf(x, next_btn.global_position.x + next_btn.size.x - panel_size.x)
		y = next_btn.global_position.y + next_btn.size.y + 8.0
	var min_y = _topbar_bottom_y() + 6.0
	x = clampf(x, margin, viewport_size.x - panel_size.x - margin)
	y = clampf(y, min_y, viewport_size.y - panel_size.y - margin)
	_trade_province_picker_popup.position = Vector2(x, y)

# Main runtime logic lives here.
func _trade_parse_selected_province_ids(raw_text: String) -> Array:
	var text = raw_text.strip_edges().replace(";", ",").replace(" ", "")
	if text == "":
		return []
	var out: Array = []
	for part in text.split(",", false):
		var token = part.strip_edges()
		if token == "" or not token.is_valid_int():
			continue
		var pid = int(token)
		if not out.has(pid):
			out.append(pid)
	return out

# Handles this gameplay/UI path.
func _trade_potvrd_vyber_provincii_z_mapy() -> void:
	if not _ceka_na_vyber_trade_provincie:
		return
	var side = _trade_map_pick_side
	if side < 0:
		return
	var map_node = _ziskej_map_node_pro_mir()
	if map_node == null or not map_node.has_method("potvrd_vyber_trade_provincii"):
		zobraz_systemove_hlaseni("Trade", "Map cannot confirm trade province selection.")
		return
	var result = map_node.potvrd_vyber_trade_provincii() as Dictionary
	if not bool(result.get("ok", false)):
		zobraz_systemove_hlaseni("Trade", str(result.get("reason", "Failed to confirm trade province selection.")))
		return

	var ids = (result.get("selected", []) as Array).duplicate()
	# sort zajisti stabilni serializaci textu i pozdejsi porovnani terms.
	ids.sort()
	var id_parts: Array = []
	for raw_id in ids:
		id_parts.append(str(int(raw_id)))
	var source = str(result.get("source", _trade_map_pick_source_tag)).strip_edges().to_upper()
	_trade_side_values(side)["province"] = {
		"a": ",".join(id_parts),
		"b": "%d provinces from %s" % [ids.size(), source]
	}

	_ceka_na_vyber_trade_provincie = false
	_trade_map_pick_side = -1
	_trade_map_pick_source_tag = ""
	_trade_map_selected_ids.clear()
	if _trade_province_picker_popup:
		_trade_province_picker_popup.hide()
	if _trade_dialog and _trade_dialog_hidden_for_map_pick:
		_pozicuj_trade_dialog()
		_trade_dialog.popup()
		_pozicuj_trade_dialog()
	_trade_dialog_hidden_for_map_pick = false
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	_trade_set_selected_slot(side, "province")
	_trade_refresh_dialog_ui()

# Main runtime logic lives here.
func _trade_zrus_vyber_provincii_z_mapy(obnovit_hlavni_dialog: bool = true) -> void:
	var map_node = _ziskej_map_node_pro_mir()
	if map_node and map_node.has_method("zrus_rezim_vyberu_trade_provincie"):
		map_node.zrus_rezim_vyberu_trade_provincie()
	_ceka_na_vyber_trade_provincie = false
	_trade_map_pick_side = -1
	_trade_map_pick_source_tag = ""
	_trade_map_selected_ids.clear()
	if _trade_province_picker_popup:
		_trade_province_picker_popup.hide()
	if obnovit_hlavni_dialog and _trade_dialog and _trade_dialog_hidden_for_map_pick:
		_pozicuj_trade_dialog()
		_trade_dialog.popup()
		_pozicuj_trade_dialog()
	_trade_dialog_hidden_for_map_pick = false
	_trade_refresh_dialog_ui()

# Runs the local feature logic.
func _trade_vytvor_stranu(side: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style = _vytvor_ingame_kartu_styl(
		Color(0.09, 0.14, 0.22, 0.96) if side == 0 else Color(0.15, 0.11, 0.09, 0.96),
		Color(0.42, 0.63, 0.90, 0.70) if side == 0 else Color(0.88, 0.62, 0.36, 0.70)
	)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.text = "Player state" if side == 0 else "Target state"
	root.add_child(title)
	if side == 0:
		_trade_left_title_label = title
	else:
		_trade_right_title_label = title

	var buttons_box = VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 6)
	buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(buttons_box)

	for spec_any in _trade_option_specs():
		var spec = spec_any as Dictionary
		var slot = str(spec.get("slot", ""))
		var btn = Button.new()
		btn.text = str(spec.get("label", slot))
		btn.custom_minimum_size = Vector2(0, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_aplikuj_overview_tlacitko_vzhled(btn)
		btn.pressed.connect(_trade_on_slot_pressed.bind(side, slot))
		buttons_box.add_child(btn)
		if side == 0:
			_trade_left_buttons[slot] = btn
		else:
			_trade_right_buttons[slot] = btn

	var editor_panel = PanelContainer.new()
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_panel.add_theme_stylebox_override("panel", _vytvor_ingame_kartu_styl(Color(0.05, 0.08, 0.14, 0.96), Color(0.32, 0.49, 0.74, 0.55)))
	root.add_child(editor_panel)

	var editor_margin = MarginContainer.new()
	editor_margin.offset_left = 8
	editor_margin.offset_top = 8
	editor_margin.offset_right = -8
	editor_margin.offset_bottom = -8
	editor_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor_panel.add_child(editor_margin)

	var editor_scroll = ScrollContainer.new()
	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_margin.add_child(editor_scroll)

	var editor_box = VBoxContainer.new()
	editor_box.add_theme_constant_override("separation", 8)
	editor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.add_child(editor_box)

	var info = Label.new()
	info.text = "Select an option above"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_box.add_child(info)

	var input_a = LineEdit.new()
	input_a.placeholder_text = "Value"
	input_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_box.add_child(input_a)

	var input_b = LineEdit.new()
	input_b.placeholder_text = "Optional note"
	input_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_box.add_child(input_b)

	var pick_province_btn = Button.new()
	pick_province_btn.text = "Select territory on map"
	pick_province_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_province_btn.custom_minimum_size = Vector2(0, 34)
	pick_province_btn.visible = false
	_aplikuj_ingame_tlacitko_styl(pick_province_btn)
	pick_province_btn.pressed.connect(_trade_otevri_province_picker.bind(side))
	editor_box.add_child(pick_province_btn)

	var pick_war_target_btn = Button.new()
	pick_war_target_btn.text = "Select war target on map"
	pick_war_target_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_war_target_btn.custom_minimum_size = Vector2(0, 34)
	pick_war_target_btn.visible = false
	_aplikuj_ingame_tlacitko_styl(pick_war_target_btn)
	pick_war_target_btn.pressed.connect(_trade_on_country_target_pick_pressed.bind(side))
	editor_box.add_child(pick_war_target_btn)

	var pick_alliance_btn = Button.new()
	pick_alliance_btn.text = "Select alliance"
	pick_alliance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_alliance_btn.custom_minimum_size = Vector2(0, 34)
	pick_alliance_btn.visible = false
	_aplikuj_ingame_tlacitko_styl(pick_alliance_btn)
	pick_alliance_btn.pressed.connect(_trade_otevri_join_alliance_picker.bind(side))
	editor_box.add_child(pick_alliance_btn)

	var preview = Label.new()
	preview.text = "No configured item"
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size = Vector2(0, 46)
	editor_box.add_child(preview)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.custom_minimum_size = Vector2(0, 40)
	editor_box.add_child(action_row)

	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.custom_minimum_size = Vector2(0, 36)
	_aplikuj_ingame_tlacitko_styl(apply_btn)
	apply_btn.pressed.connect(_trade_apply_side.bind(side))
	action_row.add_child(apply_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.custom_minimum_size = Vector2(0, 36)
	_aplikuj_ingame_tlacitko_styl(clear_btn, true)
	clear_btn.pressed.connect(_trade_clear_side.bind(side))
	action_row.add_child(clear_btn)

	var editor_ref = {
		"info": info,
		"input_a": input_a,
		"input_b": input_b,
		"preview": preview,
		"pick_province": pick_province_btn,
		"pick_war_target": pick_war_target_btn,
		"pick_alliance": pick_alliance_btn,
		"slot": ""
	}
	if side == 0:
		_trade_left_editor = editor_ref
	else:
		_trade_right_editor = editor_ref

	return panel

# Core flow for this feature.
func _trade_side_values(side: int) -> Dictionary:
	return _trade_left_values if side == 0 else _trade_right_values

# Feature logic entry point.
func _trade_side_editor(side: int) -> Dictionary:
	return _trade_left_editor if side == 0 else _trade_right_editor

func _trade_side_buttons(side: int) -> Dictionary:
	return _trade_left_buttons if side == 0 else _trade_right_buttons

func _trade_selected_slot(side: int) -> String:
	return _trade_left_selected_slot if side == 0 else _trade_right_selected_slot

func _trade_set_selected_slot(side: int, slot: String) -> void:
	if side == 0:
		_trade_left_selected_slot = slot
	else:
		_trade_right_selected_slot = slot

func _trade_on_country_target_pick_pressed(side: int) -> void:
	var slot = _trade_selected_slot(side)
	if slot == "declare_war" or slot == "improve_relationship_with" or slot == "worsen_relationship_with":
		_trade_otevri_country_relation_picker(side, slot)

func _trade_on_slot_pressed(side: int, slot: String) -> void:
	_trade_set_selected_slot(side, slot)
	var spec = _trade_option_spec(slot)
	var editor = _trade_side_editor(side)
	if editor.is_empty():
		return
	editor["slot"] = slot
	var values = _trade_side_values(side)
	var stored = values.get(slot, {"a": "", "b": ""}) as Dictionary
	editor["info"].text = str(spec.get("label", slot))
	(editor["input_a"] as LineEdit).placeholder_text = str(spec.get("placeholder_a", "Value"))
	(editor["input_b"] as LineEdit).placeholder_text = str(spec.get("placeholder_b", "Optional note"))
	(editor["input_a"] as LineEdit).text = str(stored.get("a", ""))
	(editor["input_b"] as LineEdit).text = str(stored.get("b", ""))
	var is_province_slot = slot == "province"
	var is_declare_war_slot = slot == "declare_war"
	var is_improve_rel_slot = slot == "improve_relationship_with"
	var is_worsen_rel_slot = slot == "worsen_relationship_with"
	var is_country_target_slot = is_declare_war_slot or is_improve_rel_slot or is_worsen_rel_slot
	var is_join_alliance_slot = slot == "join_alliance"
	var hide_inputs = is_province_slot or is_country_target_slot or is_join_alliance_slot
	(editor["input_a"] as LineEdit).visible = not hide_inputs
	(editor["input_b"] as LineEdit).visible = not hide_inputs
	if editor.has("pick_province"):
		var pick_btn = editor["pick_province"] as Button
		pick_btn.visible = is_province_slot
		if is_province_slot:
			pick_btn.text = "Finish map selection" if (_ceka_na_vyber_trade_provincie and _trade_map_pick_side == side) else "Click state territory on map"
	if editor.has("pick_war_target"):
		var war_btn = editor["pick_war_target"] as Button
		war_btn.visible = is_country_target_slot
		if is_country_target_slot:
			var is_current_picker = _ceka_na_vyber_trade_war_cile and _trade_war_pick_side == side and _trade_war_pick_slot == slot
			war_btn.text = "Finish target selection" if is_current_picker else "Click country on map"
	if editor.has("pick_alliance"):
		var alliance_btn = editor["pick_alliance"] as Button
		alliance_btn.visible = is_join_alliance_slot
		if is_join_alliance_slot:
			alliance_btn.text = "Finish alliance selection" if (_ceka_na_vyber_trade_aliance and _trade_alliance_pick_side == side) else "Select alliance"
	_trade_refresh_dialog_ui()

# Feature logic entry point.
func _trade_apply_side(side: int) -> void:
	var slot = _trade_selected_slot(side)
	if slot == "":
		await zobraz_systemove_hlaseni("Trade", "Select an option first.")
		return
	if slot == "province":
		# province/decalre-war/join-alliance sloty jsou map/menu driven, ne text input.
		if not _trade_side_values(side).has("province"):
			await zobraz_systemove_hlaseni("Trade", "Use map selection for provinces.")
			return
		_trade_refresh_dialog_ui()
		return
	if slot == "declare_war":
		if not _trade_side_values(side).has("declare_war"):
			await zobraz_systemove_hlaseni("Trade", "Use map selection for Declare War target.")
			return
		_trade_refresh_dialog_ui()
		return
	if slot == "improve_relationship_with":
		if not _trade_side_values(side).has("improve_relationship_with"):
			await zobraz_systemove_hlaseni("Trade", "Use map selection for Improve Relations target.")
			return
		_trade_refresh_dialog_ui()
		return
	if slot == "worsen_relationship_with":
		if not _trade_side_values(side).has("worsen_relationship_with"):
			await zobraz_systemove_hlaseni("Trade", "Use map selection for Worsen Relations target.")
			return
		_trade_refresh_dialog_ui()
		return
	if slot == "join_alliance":
		if not _trade_side_values(side).has("join_alliance"):
			await zobraz_systemove_hlaseni("Trade", "Select alliance from alliance menu.")
			return
		_trade_refresh_dialog_ui()
		return
	var editor = _trade_side_editor(side)
	if editor.is_empty():
		return
	var value_a = (editor["input_a"] as LineEdit).text.strip_edges()
	var value_b = (editor["input_b"] as LineEdit).text.strip_edges()
	if value_a == "" and slot != "non_aggression":
		await zobraz_systemove_hlaseni("Trade", "Fill in the main value for the selected option.")
		return
	_trade_side_values(side)[slot] = {"a": value_a if value_a != "" else "ON", "b": value_b}
	_trade_refresh_dialog_ui()

func _trade_clear_side(side: int) -> void:
	var slot = _trade_selected_slot(side)
	if slot == "":
		return
	_trade_side_values(side).erase(slot)
	var editor = _trade_side_editor(side)
	if not editor.is_empty():
		(editor["input_a"] as LineEdit).text = ""
		(editor["input_b"] as LineEdit).text = ""
	_trade_refresh_dialog_ui()

# Feature logic entry point.
func _trade_compact_value(entry: Dictionary) -> String:
	var value_a = str(entry.get("a", "")).strip_edges()
	var value_b = str(entry.get("b", "")).strip_edges()
	if value_a == "" and value_b == "":
		return ""
	if value_b == "":
		return value_a
	return "%s | %s" % [value_a, value_b]

func _trade_refresh_side_ui(side: int) -> void:
	var values = _trade_side_values(side)
	var buttons = _trade_side_buttons(side)
	var editor = _trade_side_editor(side)
	var selected_slot = _trade_selected_slot(side)
	for spec_any in _trade_option_specs():
		var spec = spec_any as Dictionary
		var slot = str(spec.get("slot", ""))
		var btn = buttons.get(slot, null) as Button
		if btn == null:
			continue
		var text = str(spec.get("label", slot))
		if values.has(slot):
			var compact = _trade_compact_value(values[slot] as Dictionary)
			if compact != "":
				text += " [%s]" % compact
		btn.text = text
		btn.modulate = Color(1.0, 0.92, 0.45, 1.0) if slot == selected_slot else Color(1, 1, 1, 1)
	if editor.is_empty():
		return
	if selected_slot == "":
		editor["preview"].text = "No configured item"
		return
	var spec = _trade_option_spec(selected_slot)
	if values.has(selected_slot):
		editor["preview"].text = "Current value: %s" % _trade_compact_value(values[selected_slot] as Dictionary)
	else:
		editor["preview"].text = "No value set for %s" % str(spec.get("label", selected_slot))

func _trade_refresh_dialog_ui() -> void:
	if _trade_title_label:
		_trade_title_label.text = "Trade Request"
	if _trade_success_label:
		var configured = _trade_left_values.size() + _trade_right_values.size()
		_trade_success_label.text = "Configured items: %d" % configured
	if _trade_left_title_label:
		_trade_left_title_label.text = str(GameManager.hrac_stat)
	if _trade_right_title_label:
		_trade_right_title_label.text = _trade_target_tag if _trade_target_tag != "" else "Target state"
	# obe strany refresheme vzdy spolu, at preview zustane konzistentni.
	_trade_refresh_side_ui(0)
	_trade_refresh_side_ui(1)

func _otevri_trade_dialog(target_tag: String) -> void:
	_vytvor_trade_dialog()
	_trade_target_tag = target_tag.strip_edges().to_upper()
	_trade_left_selected_slot = ""
	_trade_right_selected_slot = ""
	_ceka_na_vyber_trade_provincie = false
	_trade_map_pick_side = -1
	_trade_dialog_hidden_for_map_pick = false
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	_trade_zrus_vyber_aliance_z_menu(false)
	if _trade_province_picker_popup:
		_trade_province_picker_popup.hide()
	_trade_refresh_dialog_ui()
	call_deferred("_trade_open_popup_deferred")

func _trade_open_popup_deferred() -> void:
	if _trade_dialog == null:
		return
	var map_node = _ziskej_map_node_pro_mir()
	if map_node and map_node.has_method("zrus_rezim_vyberu_trade_provincie"):
		map_node.zrus_rezim_vyberu_trade_provincie()
	_ceka_na_vyber_trade_provincie = false
	_trade_map_pick_side = -1
	_trade_dialog_hidden_for_map_pick = false
	_trade_zrus_vyber_valecneho_cile_z_mapy(false)
	_trade_zrus_vyber_aliance_z_menu(false)
	if _trade_province_picker_popup:
		_trade_province_picker_popup.hide()
	_pozicuj_trade_dialog()
	_trade_dialog.popup()
	_pozicuj_trade_dialog()

func _pozicuj_trade_dialog() -> void:
	if _trade_dialog == null:
		return
	var vp = get_viewport().get_visible_rect().size
	var w = clamp(vp.x - 40.0, 760.0, 1180.0)
	var h = clamp(vp.y - 40.0, 500.0, 760.0)
	_trade_dialog.size = Vector2(w, h)
	_trade_dialog.position = Vector2((vp.x - _trade_dialog.size.x) * 0.5, (vp.y - _trade_dialog.size.y) * 0.5)

func _on_trade_send_pressed() -> void:
	if _trade_target_tag == "" or _trade_target_tag == GameManager.hrac_stat:
		await zobraz_systemove_hlaseni("Trade", "Select a valid target country first.")
		return
	if not GameManager.has_method("odeslat_obchodni_nabidku"):
		await zobraz_systemove_hlaseni("Trade", "Trade backend is not available in current game build.")
		return

	var sender_terms = _trade_left_values.duplicate(true)
	var receiver_terms = _trade_right_values.duplicate(true)
	var result = GameManager.odeslat_obchodni_nabidku(GameManager.hrac_stat, _trade_target_tag, sender_terms, receiver_terms)
	if not bool(result.get("ok", false)):
		await zobraz_systemove_hlaseni("Trade", str(result.get("reason", "Failed to send trade offer.")))
		return

	var queued = bool(result.get("queued", false))
	var accepted = bool(result.get("accepted", false))
	if queued:
		await zobraz_systemove_hlaseni("Trade", "Trade offer was sent to %s." % _trade_target_tag)
	elif accepted:
		await zobraz_systemove_hlaseni("Trade", "%s accepted your trade offer and terms were applied." % _trade_target_tag)
	else:
		await zobraz_systemove_hlaseni("Trade", "%s declined your trade offer." % _trade_target_tag)

	if queued or accepted:
		var map_node = _ziskej_map_node_pro_mir()
		if map_node and map_node.has_method("zrus_rezim_vyberu_trade_provincie"):
			map_node.zrus_rezim_vyberu_trade_provincie()
		_ceka_na_vyber_trade_provincie = false
		_trade_map_pick_side = -1
		_trade_dialog_hidden_for_map_pick = false
		_trade_zrus_vyber_valecneho_cile_z_mapy(false)
		_trade_zrus_vyber_aliance_z_menu(false)
		if _trade_province_picker_popup:
			_trade_province_picker_popup.hide()
		_trade_left_values.clear()
		_trade_right_values.clear()
		_trade_left_selected_slot = ""
		_trade_right_selected_slot = ""
		_trade_refresh_dialog_ui()
		if _trade_dialog:
			_trade_dialog.hide()

	_aktualizuj_popup_diplomatickych_zadosti()
	if current_viewed_tag != "":
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

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
		_obnov_pause_spectate_vyber_hrace()
		_obnov_text_spectate_tlacitka()
		_pozicuj_pause_menu()
		_pause_menu_panel.show()

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

# Sets up nodes, defaults, and signals.
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

# Initialization for UI objects and hooks.
func _vytvor_settings_dialog() -> void:
	_settings_dialog = PopupPanel.new()
	_settings_dialog.name = "SettingsDialog"
	_settings_dialog.wrap_controls = false
	_settings_dialog.unresizable = true
	_settings_dialog.min_size = SETTINGS_DIALOG_MIN_SIZE
	_settings_dialog.size = SETTINGS_DIALOG_DEFAULT_SIZE
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

	var controls_scroll = ScrollContainer.new()
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_settings_controls_panel.add_child(controls_scroll)

	var controls_margin = MarginContainer.new()
	controls_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_margin.add_theme_constant_override("margin_left", 12)
	controls_margin.add_theme_constant_override("margin_top", 10)
	controls_margin.add_theme_constant_override("margin_right", 12)
	controls_margin.add_theme_constant_override("margin_bottom", 10)
	controls_scroll.add_child(controls_margin)

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
	controls_info.text = "- Mouse wheel: zoom\n- Right mouse hold + drag: pan map\n- Escape: cancel action / close dialogs\n- Space confirms battle/system popups"
	controls_content.add_child(controls_info)

	var keybind_hint = Label.new()
	keybind_hint.text = "Keybinds are currently fixed to default values."
	keybind_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_content.add_child(keybind_hint)

	_settings_keybind_grid = GridContainer.new()
	_settings_keybind_grid.columns = 2
	_settings_keybind_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_keybind_grid.add_theme_constant_override("h_separation", 12)
	_settings_keybind_grid.add_theme_constant_override("v_separation", 6)
	controls_content.add_child(_settings_keybind_grid)
	_settings_keybind_state = ControlsConfig.get_default_bindings()
	_build_ingame_keybind_rows()

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

	var settings_scroll = ScrollContainer.new()
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_settings_options_panel.add_child(settings_scroll)

	var settings_margin = MarginContainer.new()
	settings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_margin.add_theme_constant_override("margin_left", 12)
	settings_margin.add_theme_constant_override("margin_top", 10)
	settings_margin.add_theme_constant_override("margin_right", 12)
	settings_margin.add_theme_constant_override("margin_bottom", 10)
	settings_scroll.add_child(settings_margin)

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

	_settings_potato_mode_check = CheckBox.new()
	_settings_potato_mode_check.text = "Potato mode (low-end PC)"
	_settings_potato_mode_check.tooltip_text = "Low-detail rendering and power-saving updates for weak PCs."
	settings_content.add_child(_settings_potato_mode_check)

	_settings_ai_debug_mode_check = CheckBox.new()
	_settings_ai_debug_mode_check.text = "Debug mode"
	_settings_ai_debug_mode_check.tooltip_text = "Shows debug panel and detailed diagnostics in output."
	settings_content.add_child(_settings_ai_debug_mode_check)

	_settings_skip_battle_reports_check = CheckBox.new()
	_settings_skip_battle_reports_check.text = "Skip battle reports on end turn"
	_settings_skip_battle_reports_check.tooltip_text = "When enabled, battle/frontline popups are skipped and turn processing continues immediately."
	settings_content.add_child(_settings_skip_battle_reports_check)

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

func _build_ingame_keybind_rows() -> void:
	if _settings_keybind_grid == null:
		return
	for child in _settings_keybind_grid.get_children():
		child.queue_free()
	_settings_keybind_buttons.clear()
	for action_any in ControlsConfig.ACTIONS:
		var action = str(action_any)
		var label = Label.new()
		label.text = str(ControlsConfig.ACTION_LABELS.get(action, action))
		_settings_keybind_grid.add_child(label)

		var value = Label.new()
		value.text = ControlsConfig.get_binding_text(action, _settings_keybind_state)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_settings_keybind_grid.add_child(value)

# Refreshes existing content to reflect current runtime values.
func _refresh_ingame_keybind_buttons() -> void:
	return

# Reacts to incoming events.
func _on_ingame_keybind_button_pressed(action: String) -> void:
	return

func _capture_ingame_keybind(event: InputEventKey) -> bool:
	return false

# Runs the local feature logic.
func _pozicuj_settings_dialog() -> void:
	if _settings_dialog:
		var vp = get_viewport().get_visible_rect().size
		var target_size = _vypocitej_settings_dialog_size(vp)
		_settings_dialog.size = target_size
		_settings_dialog.position = Vector2(
			maxf(0.0, (vp.x - target_size.x) * 0.5),
			maxf(0.0, (vp.y - target_size.y) * 0.5)
		)

func _vypocitej_settings_dialog_size(viewport_size: Vector2) -> Vector2i:
	var available_w = int(maxf(float(SETTINGS_DIALOG_MIN_SIZE.x), viewport_size.x - SETTINGS_DIALOG_SCREEN_MARGIN))
	var available_h = int(maxf(float(SETTINGS_DIALOG_MIN_SIZE.y), viewport_size.y - SETTINGS_DIALOG_SCREEN_MARGIN))
	return Vector2i(
		min(SETTINGS_DIALOG_DEFAULT_SIZE.x, available_w),
		min(SETTINGS_DIALOG_DEFAULT_SIZE.y, available_h)
	)

# Main runtime logic lives here.
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
	ControlsConfig.ensure_default_actions()
	_settings_keybind_state = ControlsConfig.get_default_bindings()
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		_settings_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_settings_vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		_settings_potato_mode_check.button_pressed = false
		if _settings_ai_debug_mode_check:
			_settings_ai_debug_mode_check.button_pressed = false
		if _settings_skip_battle_reports_check:
			_settings_skip_battle_reports_check.button_pressed = false
		_settings_volume_slider.value = 1.0
		_settings_camera_slider.value = 1000.0
		_settings_zoom_slider.value = 0.1
		_settings_invert_zoom_check.button_pressed = false
	else:
		_settings_fullscreen_check.button_pressed = bool(cfg.get_value("display", "fullscreen", false))
		_settings_vsync_check.button_pressed = bool(cfg.get_value("display", "vsync", true))
		var potato_display = bool(cfg.get_value("display", "potato_mode", false))
		var potato_other = bool(cfg.get_value("other", "potato_mode", potato_display))
		_settings_potato_mode_check.button_pressed = potato_display or potato_other
		if _settings_ai_debug_mode_check:
			# Always initialize debug mode as disabled at startup.
			_settings_ai_debug_mode_check.button_pressed = false
		if _settings_skip_battle_reports_check:
			_settings_skip_battle_reports_check.button_pressed = bool(cfg.get_value("other", "skip_battle_reports", false))
		_settings_volume_slider.value = clamp(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
		_settings_camera_slider.value = float(cfg.get_value("controls", "camera_speed", 1000.0))
		_settings_zoom_slider.value = clamp(float(cfg.get_value("controls", "zoom_speed", 0.1)), 0.03, 0.35)
		_settings_invert_zoom_check.button_pressed = bool(cfg.get_value("controls", "invert_zoom", false))

	_refresh_ingame_keybind_buttons()

	_aplikuj_ai_debug_mode_runtime(_settings_ai_debug_mode_check.button_pressed if _settings_ai_debug_mode_check else false)
	_aplikuj_skip_battle_reports_runtime(_settings_skip_battle_reports_check.button_pressed if _settings_skip_battle_reports_check else false)

	_on_ingame_volume_changed(_settings_volume_slider.value)
	_on_ingame_camera_speed_changed(_settings_camera_slider.value)
	_on_ingame_zoom_speed_changed(_settings_zoom_slider.value)

# Persistence write helper.
func _uloz_a_aplikuj_ingame_settings() -> void:
	var fullscreen = _settings_fullscreen_check.button_pressed
	var vsync_enabled = _settings_vsync_check.button_pressed
	var potato_mode = _settings_potato_mode_check.button_pressed if _settings_potato_mode_check else false
	var ai_debug_mode = _settings_ai_debug_mode_check.button_pressed if _settings_ai_debug_mode_check else false
	var skip_battle_reports = _settings_skip_battle_reports_check.button_pressed if _settings_skip_battle_reports_check else false
	var master_volume = float(_settings_volume_slider.value)
	var camera_speed = float(_settings_camera_slider.value)
	var zoom_speed = float(_settings_zoom_slider.value)
	var invert_zoom = _settings_invert_zoom_check.button_pressed
	var keybinds = ControlsConfig.get_default_bindings()

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	_aplikuj_potato_mode_runtime(potato_mode)
	_aplikuj_ai_debug_mode_runtime(ai_debug_mode)
	_aplikuj_skip_battle_reports_runtime(skip_battle_reports)

	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx == -1:
		master_bus_idx = 0
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(clamp(master_volume, 0.0001, 1.0)))

	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_FILE_PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("display", "potato_mode", potato_mode)
	cfg.set_value("other", "potato_mode", potato_mode)
	cfg.set_value("other", "ai_debug_mode", ai_debug_mode)
	cfg.set_value("other", "skip_battle_reports", skip_battle_reports)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "camera_speed", camera_speed)
	cfg.set_value("controls", "zoom_speed", zoom_speed)
	cfg.set_value("controls", "invert_zoom", invert_zoom)
	var save_err = cfg.save(SETTINGS_FILE_PATH)
	if save_err != OK:
		push_warning("Failed to save in-game settings. Error: %s" % str(save_err))
	ControlsConfig.apply_bindings(keybinds)

	var map_cam = _ziskej_map_kameru()
	if map_cam:
		map_cam.speed = camera_speed
		map_cam.zoom_speed = zoom_speed
		map_cam.invert_zoom_wheel = invert_zoom

# Applies prepared settings/effects to runtime systems.
func _aplikuj_potato_mode_runtime(enabled: bool) -> void:
	Engine.max_fps = 45 if enabled else 0
	OS.low_processor_usage_mode = enabled
	OS.low_processor_usage_mode_sleep_usec = 12000 if enabled else 6900

	var map_loader = _ziskej_map_loader_node()
	if map_loader and map_loader.has_method("nastav_potato_mode"):
		map_loader.nastav_potato_mode(enabled)
	
	var game_manager = get_tree().root.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("nastav_potato_mode"):
		game_manager.nastav_potato_mode(enabled)

func _aplikuj_ai_debug_mode_runtime(enabled: bool) -> void:
	var game_manager = get_tree().root.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("nastav_ai_debug_mode"):
		game_manager.nastav_ai_debug_mode(enabled)

func _aplikuj_skip_battle_reports_runtime(enabled: bool) -> void:
	var map_loader = _ziskej_map_loader_node()
	if map_loader and map_loader.has_method("nastav_skip_battle_reportu"):
		map_loader.nastav_skip_battle_reportu(enabled)

func _on_ingame_volume_changed(value: float) -> void:
	if _settings_volume_value:
		_settings_volume_value.text = "%d%%" % int(round(value * 100.0))

# Reacts to incoming events.
func _on_ingame_camera_speed_changed(value: float) -> void:
	if _settings_camera_value:
		_settings_camera_value.text = "%d" % int(round(value))

func _on_ingame_zoom_speed_changed(value: float) -> void:
	if _settings_zoom_value:
		_settings_zoom_value.text = "%.2f" % value

func _on_ingame_settings_apply_pressed() -> void:
	_uloz_a_aplikuj_ingame_settings()
	_settings_dialog.hide()

# Handles this gameplay/UI path.
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
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(34, 0)
	delete_btn.focus_mode = Control.FOCUS_NONE
	delete_btn.tooltip_text = "Delete save slot"
	delete_btn.add_theme_font_size_override("font_size", 18)
	delete_btn.pressed.connect(_on_load_slot_row_delete_pressed.bind(slot_name))
	row.add_child(delete_btn)

# Updates state and keeps things in sync.
func _nastav_vybrany_load_slot(slot_name: String) -> void:
	_load_selected_slot_name = slot_name
	for key_any in _load_slot_row_buttons.keys():
		var key = str(key_any)
		var btn = _load_slot_row_buttons[key_any] as Button
		if btn:
			btn.button_pressed = (key == _load_selected_slot_name)
	if _load_confirm_btn:
		_load_confirm_btn.disabled = _load_selected_slot_name == ""

# Triggered by a UI/game signal.
func _on_load_slot_row_pressed(slot_name: String) -> void:
	_nastav_vybrany_load_slot(slot_name)

# Handles this signal callback.
func _on_load_slot_row_delete_pressed(slot_name: String) -> void:
	await _smaz_load_slot(slot_name)

func _on_load_slot_selected(_index: int) -> void:
	# Deprecated path (ItemList was replaced by custom row list).
	pass

# Reacts to incoming events.
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

# Main runtime logic lives here.
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

# Callback for UI/game events.
func _on_pause_resume_pressed() -> void:
	_zavri_pause_menu()

func _obnov_text_spectate_tlacitka() -> void:
	if _pause_spectate_btn == null:
		return
	_spectate_mode_enabled = false
	_pause_spectate_btn.text = "Spectate mode: Disabled"
	_pause_spectate_btn.tooltip_text = "Temporarily disabled."
	_pause_spectate_btn.disabled = true
	_pause_spectate_btn.visible = false
	if _pause_spectate_pick_row:
		_pause_spectate_pick_row.visible = false
	_obnov_spectate_hud_indicator()

func _on_pause_toggle_spectate_pressed() -> void:
	_spectate_mode_enabled = false
	_spectate_auto_turn_cooldown = 0.0
	if GameManager and GameManager.has_method("nastav_spectate_mode"):
		GameManager.nastav_spectate_mode(false)
	await zobraz_systemove_hlaseni("Spectate", "Spectate mode is temporarily disabled.")

func _ziskej_pause_volitelne_hrace() -> Array:
	var out: Array = []
	if not GameManager:
		return out
	var seen: Dictionary = {}
	for p_id in GameManager.map_data:
		var d = GameManager.map_data[p_id] as Dictionary
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue
		if seen.has(owner):
			continue
		seen[owner] = true
		out.append(owner)
	out.sort_custom(func(a, b): return _ziskej_jmeno_statu_podle_tagu(str(a)) < _ziskej_jmeno_statu_podle_tagu(str(b)))
	return out

func _ziskej_pause_selected_hrac_tag() -> String:
	if _pause_spectate_pick_option == null:
		return ""
	if _pause_spectate_pick_option.item_count <= 0:
		return ""
	var idx = _pause_spectate_pick_option.selected
	if idx < 0:
		idx = 0
	var meta = _pause_spectate_pick_option.get_item_metadata(idx)
	if meta == null:
		return ""
	return str(meta).strip_edges().to_upper()

func _obnov_pause_spectate_vyber_hrace() -> void:
	if _pause_spectate_pick_option == null:
		return
	var previous = _ziskej_pause_selected_hrac_tag()
	_pause_spectate_pick_option.clear()
	var states = _ziskej_pause_volitelne_hrace()
	for tag_any in states:
		var tag = str(tag_any)
		var name = _ziskej_jmeno_statu_podle_tagu(tag)
		var item = "%s (%s)" % [name, tag]
		_pause_spectate_pick_option.add_item(item)
		_pause_spectate_pick_option.set_item_metadata(_pause_spectate_pick_option.item_count - 1, tag)
	if _pause_spectate_pick_option.item_count <= 0:
		_pause_spectate_pick_option.add_item("No playable state")
		_pause_spectate_pick_option.set_item_disabled(0, true)
		return
	var select_idx = 0
	if previous != "":
		for i in range(_pause_spectate_pick_option.item_count):
			if str(_pause_spectate_pick_option.get_item_metadata(i)).strip_edges().to_upper() == previous:
				select_idx = i
				break
	_pause_spectate_pick_option.select(select_idx)

func _ensure_spectate_hud_indicator() -> void:
	# Lightweight always-visible indicator to avoid confusion during auto-turn spectate.
	# Pro male dite: mala cedulka na obrazovce rika, ze jen koukas a nehrajes.
	if _spectate_hud_panel != null:
		return
	_spectate_hud_panel = PanelContainer.new()
	_spectate_hud_panel.name = "SpectateHudIndicator"
	_spectate_hud_panel.visible = false
	_spectate_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spectate_hud_panel.size = Vector2(252.0, 34.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.14, 0.24, 0.93)
	panel_style.border_color = Color(0.58, 0.74, 0.94, 0.86)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	_spectate_hud_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_spectate_hud_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spectate_hud_panel.add_child(margin)

	_spectate_hud_label = Label.new()
	_spectate_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectate_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spectate_hud_label.text = "SPECTATE MODE ACTIVE"
	_spectate_hud_label.add_theme_font_size_override("font_size", 13)
	_spectate_hud_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	margin.add_child(_spectate_hud_label)

	_pozicuj_spectate_hud_indicator()

func _pozicuj_spectate_hud_indicator() -> void:
	if _spectate_hud_panel == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_w = clamp(viewport_size.x * 0.24, 220.0, 320.0)
	var panel_h = 34.0
	var top_y = _topbar_bottom_y() + 8.0
	var x = maxf(10.0, viewport_size.x - panel_w - 12.0)
	_spectate_hud_panel.size = Vector2(panel_w, panel_h)
	_spectate_hud_panel.position = Vector2(x, top_y)

func _obnov_spectate_hud_indicator() -> void:
	_ensure_spectate_hud_indicator()
	if _spectate_hud_panel == null:
		return
	if _spectate_hud_label:
		_spectate_hud_label.text = "SPECTATE MODE ACTIVE" if _spectate_mode_enabled else ""
	_spectate_hud_panel.visible = _spectate_mode_enabled
	_pozicuj_spectate_hud_indicator()

# Event handler for user or game actions.
func _on_pause_options_pressed() -> void:
	_zavri_pause_menu()
	_nacti_settings_do_ingame_ui()
	_show_ingame_settings_tab(1)
	if _settings_dialog:
		_pozicuj_settings_dialog()
		_settings_dialog.popup()

# Event handler for user or game actions.
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

func _on_pause_confirm_canceled() -> void:
	var should_restore_pause := _pause_pending_action == "quit" or _pause_pending_action == "surrender"
	_pause_pending_action = ""
	if should_restore_pause and _pause_menu_panel:
		_pozicuj_pause_menu()
		_pause_menu_panel.call_deferred("show")

# Triggered by a UI/game signal.
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
	_pozicuj_spectate_hud_indicator()
	_pozicuj_tlacitko_zprav()

	if diplomacy_request_popup:
		var req_w = clamp(viewport_size.x * 0.50, 420.0, 820.0)
		var req_text_len = 0
		if popup_request_text:
			req_text_len = popup_request_text.text.length()
			popup_request_text.clip_text = true
			popup_request_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		var req_lines = max(1, int(ceil(float(req_text_len) / max(24.0, req_w / 10.0))))
		var req_h = clamp(34.0 + float(req_lines) * 14.0, 48.0, 72.0)
		req_h = min(req_h, max(48.0, viewport_size.y * 0.18))
		diplomacy_request_popup.position = Vector2((viewport_size.x - req_w) * 0.5, top_y)
		diplomacy_request_popup.size = Vector2(req_w, req_h)
		_rozmistit_vizual_fronty_diplomacii()
		if _queue_preview_panel:
			var rows = max(1, _queue_preview_rows)
			var panel_h = clamp(56.0 + float(rows) * 36.0, 120.0, 520.0)
			panel_h = min(panel_h, max(120.0, viewport_size.y - top_y - req_h - 28.0))
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
		var msg_w = clamp(viewport_size.x * 0.38, 420.0, 680.0)
		var text_len = 0
		var explicit_lines = 1
		if system_message_text and not _system_message_compact_battle:
			text_len = system_message_text.text.length()
			explicit_lines = max(1, system_message_text.text.split("\n").size())
			system_message_text.clip_text = false
		var wrap_lines = max(1, int(ceil(float(text_len) / max(28.0, msg_w / 9.0))))
		var approx_lines = max(explicit_lines, wrap_lines)
		var extra_battle_h = 0.0
		if _system_battle_panel and _system_battle_panel.visible:
			extra_battle_h = SYSTEM_BATTLE_PANEL_HEIGHT + 6.0
		var extra_meta_h = 0.0
		if _system_message_meta_row and _system_message_meta_row.visible:
			extra_meta_h = SYSTEM_MESSAGE_META_ROW_HEIGHT
		var extra_batch_h = 0.0
		if _system_batch_panel and _system_batch_panel.visible:
			extra_batch_h = _system_batch_panel.custom_minimum_size.y + 6.0
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
		var msg_h = 0.0
		if _system_message_compact_battle:
			msg_h = clamp(90.0 + extra_battle_h + extra_meta_h + extra_batch_h, 108.0, max_msg_h)
		else:
			msg_h = clamp(90.0 + float(approx_lines) * 17.0 + extra_battle_h + extra_meta_h + extra_batch_h, 108.0, max_msg_h)
		msg_y = clamp(msg_y, top_y, max(top_y, viewport_size.y - msg_h - 8.0))
		system_message_popup.position = Vector2((viewport_size.x - msg_w) * 0.5, msg_y)
		system_message_popup.size = Vector2(msg_w, msg_h)
		if system_message_text:
			if _system_message_compact_battle:
				system_message_text.custom_minimum_size = Vector2(0.0, 0.0)
			else:
				var text_area_h = max(34.0, msg_h - 62.0 - extra_battle_h - extra_meta_h - extra_batch_h)
				system_message_text.custom_minimum_size = Vector2(0.0, text_area_h)

	if _alliance_dialog and _alliance_dialog.visible:
		_pozicuj_alliance_dialog()
	if _alliance_create_popup and _alliance_create_popup.visible:
		_pozicuj_alliance_create_popup()

func zobraz_systemove_hlaseni(titulek: String, text: String, allow_auto_ack_during_turn: bool = true, battle_payload: Dictionary = {}, state_tags: Array = []) -> void:
	if not system_message_popup:
		return
	if _system_batch_panel:
		_system_batch_panel.hide()
	_system_message_compact_battle = not battle_payload.is_empty()
	var final_title = _zpolish_system_message_title(_nahrad_tagy_nazvy_ve_zprave(titulek))
	var final_text = _zpolish_system_message_text(_nahrad_tagy_nazvy_ve_zprave(text))
	_nastav_system_message_meta_row(_ziskej_tagy_systemove_zpravy(titulek, text, battle_payload, state_tags))
	var puvodni_pozastaveni_overlay = _turn_loading_suppressed
	nastav_pozastaveni_turn_overlay(true)
	if system_message_title:
		system_message_title.text = final_title if final_title.strip_edges() != "" else "Report"
	_nastav_system_battle_panel(battle_payload)
	if system_message_text:
		if _system_message_compact_battle:
			system_message_text.text = ""
			system_message_text.hide()
		else:
			system_message_text.show()
			system_message_text.text = final_text

	_system_message_ack = false
	_aktualizuj_pozice_popupu()
	system_message_popup.show()
	if bool(GameManager.zpracovava_se_tah) and allow_auto_ack_during_turn:
		# Never block turn resolution on message acknowledgement.
		_on_system_message_ok_pressed()
		nastav_pozastaveni_turn_overlay(puvodni_pozastaveni_overlay)
		return
	var wait_start_ms = Time.get_ticks_msec()

	while is_instance_valid(system_message_popup) and system_message_popup.visible and not _system_message_ack:
		if bool(GameManager.zpracovava_se_tah) and allow_auto_ack_during_turn:
			var elapsed_ms = Time.get_ticks_msec() - wait_start_ms
			if elapsed_ms >= SYSTEM_MESSAGE_TURN_AUTO_ACK_MS:
				print("[UI] Auto-closing system message during turn processing timeout.")
				_on_system_message_ok_pressed()
				break
		var tree := get_tree()
		if tree == null:
			break
		await tree.process_frame

	nastav_pozastaveni_turn_overlay(puvodni_pozastaveni_overlay)
	_system_message_compact_battle = false

func zobraz_batched_hlaseni(items: Array) -> void:
	if not system_message_popup:
		return
	_system_message_compact_battle = false
	var puvodni_pozastaveni_overlay = _turn_loading_suppressed
	nastav_pozastaveni_turn_overlay(true)
	if system_message_title:
		system_message_title.text = "Reports (%d)" % items.size()
	_nastav_system_message_meta_row([])
	_nastav_system_battle_panel({})
	_nastav_system_batch_items(items)
	if system_message_text:
		system_message_text.hide()
	_system_message_ack = false
	_aktualizuj_pozice_popupu()
	system_message_popup.show()
	while is_instance_valid(system_message_popup) and system_message_popup.visible and not _system_message_ack:
		var tree := get_tree()
		if tree == null:
			break
		await tree.process_frame
	nastav_pozastaveni_turn_overlay(puvodni_pozastaveni_overlay)
	_system_message_compact_battle = false
	if system_message_text:
		system_message_text.show()

func _napln_aliance_option():
	# Legacy stub - alliance is now managed via popup dialog
	pass

# Refreshes cached/UI state.
func _aktualizuj_zadost_ui(_target_tag: String):
	_current_incoming_request = {}
	if incoming_request_label:
		incoming_request_label.hide()
	if respond_request_buttons:
		respond_request_buttons.hide()

# Sets up nodes, defaults, and signals.
func _vytvor_otisk_diplomaticke_fronty(queue: Array) -> String:
	if queue.is_empty():
		return ""
	var parts: Array = []
	for req_any in queue:
		var req = req_any as Dictionary
		parts.append("%s|%s|%d" % [
			str(req.get("from", "")).strip_edges().to_upper(),
			str(req.get("type", "")).strip_edges(),
			int(req.get("level", 0))
		])
	parts.sort()
	return "||".join(parts)

# Main runtime logic lives here.
func _potlac_diplomatickou_frontu_do_zmeny() -> void:
	if diplomacy_request_popup == null:
		return
	if not GameManager or not GameManager.has_method("ziskej_cekajici_diplomaticke_zadosti"):
		diplomacy_request_popup.hide()
		_aktualizuj_panel_rozbalene_fronty([])
		_aktualizuj_pozice_popupu()
		return
	var queue = GameManager.ziskej_cekajici_diplomaticke_zadosti(GameManager.hrac_stat)
	_diplomacy_popup_dismissed_signature = _vytvor_otisk_diplomaticke_fronty(queue)
	diplomacy_request_popup.hide()
	_queue_preview_expanded = false
	if _queue_preview_toggle_btn:
		_queue_preview_toggle_btn.button_pressed = false
	_aktualizuj_panel_rozbalene_fronty([])
	_aktualizuj_pozice_popupu()

# Updates derived state and UI.
func _aktualizuj_popup_diplomatickych_zadosti():
	_popup_request_from_tag = ""
	if not diplomacy_request_popup:
		return
	if not GameManager.has_method("ziskej_cekajici_diplomaticke_zadosti"):
		_diplomacy_popup_dismissed_signature = ""
		diplomacy_request_popup.hide()
		_aktualizuj_vizual_fronty_diplomacii(0)
		_aktualizuj_text_rozbaleni_fronty(0)
		_aktualizuj_panel_rozbalene_fronty([])
		return

	var queue = GameManager.ziskej_cekajici_diplomaticke_zadosti(GameManager.hrac_stat)
	if queue.is_empty():
		_diplomacy_popup_dismissed_signature = ""
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
	var queue_signature = _vytvor_otisk_diplomaticke_fronty(queue)
	_aktualizuj_text_rozbaleni_fronty(pending_count)

	if popup_request_flag:
		popup_request_flag.texture = _resolve_flag_texture(from_tag, "")
	if popup_request_text:
		var first_summary = _formatuj_text_zadosti(first_req)
		if first_summary.length() > 92:
			first_summary = first_summary.substr(0, 89) + "..."
		var war_count := 0
		for req_any in queue:
			var req_d = req_any as Dictionary
			var req_t = str(req_d.get("type", "")).to_lower()
			if req_t.find("war") != -1:
				war_count += 1
		var suffix = ""
		if war_count > 0:
			suffix = " | war: %d" % war_count
		popup_request_text.text = "%d offers%s | %s: %s" % [pending_count, suffix, _ziskej_jmeno_statu_podle_tagu(from_tag), first_summary]

	if popup_accept_btn:
		popup_accept_btn.text = "Accept all"
	if popup_decline_btn:
		popup_decline_btn.text = "Decline all"

	if _diplomacy_popup_dismissed_signature != "" and queue_signature == _diplomacy_popup_dismissed_signature:
		diplomacy_request_popup.hide()
		_queue_preview_expanded = false
		if _queue_preview_toggle_btn:
			_queue_preview_toggle_btn.button_pressed = false
		_aktualizuj_vizual_fronty_diplomacii(pending_count)
		_aktualizuj_panel_rozbalene_fronty([])
		_aktualizuj_panel_zprav()
		_aktualizuj_pozice_popupu()
		return

	_diplomacy_popup_dismissed_signature = ""

	diplomacy_request_popup.show()
	_aktualizuj_vizual_fronty_diplomacii(pending_count)
	_aktualizuj_panel_rozbalene_fronty(queue)
	_aktualizuj_panel_zprav()
	_aktualizuj_pozice_popupu()

# Core flow for this feature.
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

# Reads values from active state.
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
		return _odfiltruj_popup_kategorie(filtered)
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

# Feature logic entry point.
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

func _ziskej_prvni_dva_tagy_zpravy(title: String, text: String) -> Array:
	var merged = (title + " " + text).strip_edges()
	if merged == "":
		return []
	var tags = _vyhledat_tagy_statu_v_textu(merged)
	if tags.size() < 2:
		for tag_any in _vyhledat_tagy_statu_podle_nazvu(merged):
			var tag = str(tag_any).strip_edges().to_upper()
			if tag == "" or tags.has(tag):
				continue
			tags.append(tag)
			if tags.size() >= 2:
				break
	if tags.size() >= 2:
		return [str(tags[0]), str(tags[1])]
	if tags.size() == 1:
		return [str(tags[0])]
	return []

func _nahrad_tagy_nazvy_ve_zprave(text: String) -> String:
	var out = text
	if out.strip_edges() == "":
		return out
	for raw_tag in _vyhledat_tagy_statu_v_textu(out):
		var tag = str(raw_tag).strip_edges().to_upper()
		if tag == "":
			continue
		var state_name = _ziskej_jmeno_statu_podle_tagu(tag)
		if state_name == "" or state_name == tag:
			continue
		var rx = RegEx.new()
		if rx.compile("\\b" + tag + "\\b") != OK:
			continue
		out = rx.sub(out, state_name, true)
	return out

func _zformatuj_diplomatickou_zpravu(category_label: String, title: String, text: String) -> String:
	var lower = (title + " " + text).to_lower()
	var tags = _ziskej_prvni_dva_tagy_zpravy(title, text)
	var a = str(tags[0]) if tags.size() >= 1 else ""
	var b = str(tags[1]) if tags.size() >= 2 else ""
	var a_name = _ziskej_jmeno_statu_podle_tagu(a) if a != "" else ""
	var b_name = _ziskej_jmeno_statu_podle_tagu(b) if b != "" else ""

	if lower.findn("declared war") != -1 or lower.findn("vyhlasil valku") != -1:
		if a != "" and b != "":
			return "%s -> %s | DECLARED WAR" % [a_name, b_name]

	if lower.findn("sent peace proposal") != -1 or lower.findn("peace proposal") != -1:
		if a != "" and b != "":
			return "%s -> %s | PEACE PROPOSAL" % [a_name, b_name]

	if lower.findn("non-aggression pact") != -1 or lower.findn("neagres") != -1:
		if a != "" and b != "":
			return "%s <-> %s | NON-AGGRESSION PACT" % [a_name, b_name]

	if lower.findn("alliance between") != -1:
		if a != "" and b != "":
			var level = ""
			var colon_idx = text.find(":")
			if colon_idx != -1 and colon_idx + 1 < text.length():
				level = text.substr(colon_idx + 1, text.length() - colon_idx - 1).strip_edges().trim_suffix(".")
			if level != "":
				return "%s <-> %s | ALLIANCE: %s" % [a_name, b_name, level]
			return "%s <-> %s | ALLIANCE UPDATE" % [a_name, b_name]

	if lower.findn("founded alliance") != -1:
		if a != "":
			return "%s | FOUNDED ALLIANCE" % a_name

	if lower.findn("joined alliance") != -1:
		if a != "":
			return "%s | JOINED ALLIANCE" % a_name

	if lower.findn("left alliance") != -1:
		if a != "":
			return "%s | LEFT ALLIANCE" % a_name

	if lower.findn("alliance '") != -1 and lower.findn("disband") != -1:
		return "ALLIANCE | DISBANDED"

	if lower.findn("military access") != -1 and lower.findn("requested") != -1:
		if a != "" and b != "":
			return "%s -> %s | MILITARY ACCESS REQUEST" % [a_name, b_name]

	if lower.findn("military access") != -1 and lower.findn("granted") != -1:
		if a != "" and b != "":
			return "%s -> %s | MILITARY ACCESS GRANTED" % [a_name, b_name]

	if lower.findn("military access") != -1 and lower.findn("revoked") != -1:
		if a != "" and b != "":
			return "%s -> %s | MILITARY ACCESS REVOKED" % [a_name, b_name]
		return "MILITARY ACCESS | REVOKED"

	if category_label == "War" and a != "" and b != "":
		return "%s vs %s | WAR EVENT" % [a_name, b_name]

	return ""

# Formats values for display.
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

	var styled_diplomacy = _zformatuj_diplomatickou_zpravu(category_label, title, text)
	if styled_diplomacy != "":
		return "%s%s" % [cat_tag, styled_diplomacy]

	if _je_redundantni_titulek_zpravy(category_label, title):
		# redukce duplicit: kdyz title opakuje body, ukazeme jen jednu verzi textu.
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

# Core flow for this feature.
func _sestav_skupiny_zprav(entries: Array) -> Dictionary:
	var grouped: Dictionary = {}
	# seskupeni podle normalizovane kategorie drzi filtr stabilni i u ruznych zdroju logu.
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

# Updates derived state and UI.
func _aktualizuj_tlacitko_zprav() -> void:
	if _zpravy_toggle_btn == null:
		return
	var count = _ziskej_aktivni_zpravy().size()
	_zpravy_toggle_btn.text = "Messages (%d)" % count
	_zpravy_toggle_btn.disabled = false
	if _zpravy_anchor_control and is_instance_valid(_zpravy_anchor_control) and _zpravy_anchor_control is Button:
		(_zpravy_anchor_control as Button).text = "Messages (%d)" % count

# Core flow for this feature.
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

# Read-only data accessor.
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
	_nastav_zpravy_panel_otevreny(not _zpravy_expanded)

func _nastav_zpravy_panel_otevreny(otevreno: bool) -> void:
	_zpravy_expanded = otevreno
	if _zpravy_toggle_btn:
		_zpravy_toggle_btn.button_pressed = _zpravy_expanded
	_aktualizuj_panel_zprav()

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
	var matches: Array = []
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
		var at = lower_text.find(country_name.to_lower())
		if at == -1:
			continue
		matches.append({
			"tag": tag,
			"at": at
		})

	# Keep state picks stable and aligned with message wording.
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_at = int(a.get("at", 0))
		var b_at = int(b.get("at", 0))
		if a_at == b_at:
			return str(a.get("tag", "")) < str(b.get("tag", ""))
		return a_at < b_at
	)

	for m_any in matches:
		var m = m_any as Dictionary
		var tag = str(m.get("tag", "")).strip_edges().to_upper()
		if tag == "" or seen.has(tag):
			continue
		seen[tag] = true
		tags.append(tag)
	return tags

# Eligibility/guard check.
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

# Builds UI objects and default wiring.
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

# Reads values from active state.
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

# Refresh pass for current state.
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
	# render backend bere current + optional history, UI prepina jen jednim flagem.
	_vykresli_skupiny_zprav(arr, history_to_show)
	_zpravy_panel.show()
	_aktualizuj_pozice_popupu()

# Callback for UI/game events.
func _on_zpravy_toggle_pressed() -> void:
	_nastav_zpravy_panel_otevreny(not _zpravy_expanded)

# Callback for UI/game events.
func _on_zpravy_mode_local_pressed() -> void:
	_zpravy_mode = 0
	if _zpravy_mode_local_btn:
		_zpravy_mode_local_btn.button_pressed = true
	if _zpravy_mode_global_btn:
		_zpravy_mode_global_btn.button_pressed = false
	_aktualizuj_panel_zprav()

# Reacts to incoming events.
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

# Reacts to incoming events.
func _on_zpravy_historie_toggled(pressed: bool) -> void:
	_zpravy_historie_expanded = pressed
	if _zpravy_historie_checkbox:
		_zpravy_historie_checkbox.button_pressed = _zpravy_historie_expanded
	_aktualizuj_panel_zprav()

# Refreshes cached/UI state.
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

# Converts raw values to UI text.
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
	if req_type == "military_access":
		return "Military access request"
	if req_type == "trade":
		var payload = req.get("payload", {}) as Dictionary
		var from_terms = payload.get("from_terms", {}) as Dictionary
		var to_terms = payload.get("to_terms", {}) as Dictionary
		var receive_parts = _trade_formatuj_terms_pro_zadost(from_terms)
		var provide_parts = _trade_formatuj_terms_pro_zadost(to_terms)
		var receive_text = ", ".join(receive_parts) if not receive_parts.is_empty() else "nothing"
		var provide_text = ", ".join(provide_parts) if not provide_parts.is_empty() else "nothing"
		return "Trade: You receive [%s] | You provide [%s]" % [receive_text, provide_text]
	if req_type == "loan":
		var payload = req.get("payload", {}) as Dictionary
		var lender = str(payload.get("lender", "")).strip_edges().to_upper()
		var borrower = str(payload.get("borrower", "")).strip_edges().to_upper()
		var principal = float(payload.get("principal", 0.0))
		var interest_pct = float(payload.get("interest_pct", 0.0))
		var turns = int(payload.get("turns", 0))
		if str(GameManager.hrac_stat).strip_edges().to_upper() == lender:
			return "Loan request: %s wants %.0f M at %.1f%% for %d turns" % [_ziskej_jmeno_statu_podle_tagu(borrower), principal, interest_pct, turns]
		return "Loan offer: %.0f M at %.1f%% for %d turns" % [principal, interest_pct, turns]
	return "Diplomatic offer"

func _trade_formatuj_terms_pro_zadost(terms: Dictionary) -> Array:
	var out: Array = []
	if terms.is_empty():
		return out
	var order = [
		"gold",
		"province",
		"declare_war",
		"join_alliance",
		"improve_relationship_with",
		"worsen_relationship_with",
		"non_aggression"
	]
	for slot_any in order:
		var slot = str(slot_any)
		if not terms.has(slot):
			continue
		var entry = terms.get(slot, {}) as Dictionary
		var value_a = str(entry.get("a", "")).strip_edges()
		var value_b = str(entry.get("b", "")).strip_edges()
		var value = value_a
		if value == "":
			value = value_b
		if value == "":
			value = "ON"
		out.append("%s: %s" % [_trade_label_slotu_pro_zadost(slot), value])
	for slot_any in terms.keys():
		var slot_extra = str(slot_any)
		if order.has(slot_extra):
			continue
		var entry_extra = terms.get(slot_any, {}) as Dictionary
		var value_extra = str(entry_extra.get("a", "")).strip_edges()
		if value_extra == "":
			value_extra = str(entry_extra.get("b", "")).strip_edges()
		if value_extra == "":
			value_extra = "ON"
		out.append("%s: %s" % [slot_extra, value_extra])
	return out

# Core flow for this feature.
func _trade_label_slotu_pro_zadost(slot: String) -> String:
	match slot:
		"gold":
			return "Money"
		"province":
			return "Provinces"
		"declare_war":
			return "Declare War"
		"join_alliance":
			return "Join Alliance"
		"improve_relationship_with":
			return "Improve Relations"
		"worsen_relationship_with":
			return "Worsen Relations"
		"non_aggression":
			return "Non-Aggression"
		_:
			return slot

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
		var offer_text = _formatuj_text_zadosti(req)
		label.text = "%d. %s | Offer: %s" % [i + 1, _ziskej_jmeno_statu_podle_tagu(from_tag), offer_text]
		label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
		label.tooltip_text = "Offer detail: %s" % offer_text
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

# Triggered by a UI/game signal.
func _on_queue_row_accept_pressed(from_tag: String) -> void:
	if not GameManager.has_method("hrac_prijmi_diplomatickou_zadost"):
		return
	var req: Dictionary = {}
	if GameManager.has_method("ziskej_cekajici_zadost_od_statu"):
		req = GameManager.ziskej_cekajici_zadost_od_statu(GameManager.hrac_stat, from_tag)
	var accepted = GameManager.hrac_prijmi_diplomatickou_zadost(GameManager.hrac_stat, from_tag)
	# u loan requestu po acceptu hned synchronizujeme topbar finance hodnoty.
	if accepted and str(req.get("type", "")) == "loan":
		var topbar = get_tree().current_scene.find_child("TopBar", true, false)
		if topbar and topbar.has_method("aktualizuj_ui"):
			topbar.aktualizuj_ui()
		var payload = req.get("payload", {}) as Dictionary
		var principal = float(payload.get("principal", 0.0))
		zobraz_systemove_hlaseni("Loans", "Loan accepted: %.0f M USD transferred." % principal)
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag == from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

# Handles this signal callback.
func _on_queue_row_decline_pressed(from_tag: String) -> void:
	if not GameManager.has_method("hrac_odmitni_diplomatickou_zadost"):
		return
	GameManager.hrac_odmitni_diplomatickou_zadost(GameManager.hrac_stat, from_tag)
	_aktualizuj_popup_diplomatickych_zadosti()
	_aktualizuj_panel_zprav()
	if current_viewed_tag == from_tag:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)

# Triggered by a UI/game signal.
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

# Handles this gameplay/UI path.
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

# Refreshes cached/UI state.
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
	if not alliance_btn:
		return

	if not GameManager.has_method("ziskej_uroven_aliance"):
		alliance_btn.hide()
		return

	var level = int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, target_tag))
	var at_war = GameManager.jsou_ve_valce(GameManager.hrac_stat, target_tag)

	var alliance_count = 0
	if GameManager.has_method("ziskej_spolecne_aliance"):
		alliance_count = (GameManager.ziskej_spolecne_aliance(GameManager.hrac_stat, target_tag) as Array).size()

	_updating_alliance_ui = true
	if at_war:
		alliance_btn.text = "Alliances (at war)"
		alliance_btn.disabled = true
		alliance_btn.tooltip_text = "Alliance cannot be managed during war."
	elif level > 0:
		var level_name = ""
		if GameManager.has_method("nazev_urovne_aliance"):
			level_name = str(GameManager.nazev_urovne_aliance(level))
		else:
			level_name = "Level %d" % level
		if alliance_count > 0:
			alliance_btn.text = "Alliances (%d) -> %s" % [alliance_count, level_name]
		else:
			alliance_btn.text = "Alliances -> %s" % level_name
		alliance_btn.disabled = false
		alliance_btn.tooltip_text = "Open alliance management menu."
	else:
		alliance_btn.text = "Alliances"
		alliance_btn.disabled = false
		alliance_btn.tooltip_text = "Open alliance management menu."
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

	var stats = _ziskej_souhrn_statu(owner_tag, all_provinces)
	var total_pop = int(stats.get("population", 0))
	var total_gdp = float(stats.get("gdp", 0.0))
	var total_recruits = int(stats.get("recruits", 0))
	var total_soldiers = int(stats.get("soldiers", 0))
	
	# Fallback: if soldiers are 0 and all_provinces is empty or corrupted, try GameManager.map_data
	if total_soldiers <= 0 and (all_provinces.is_empty() or total_pop <= 0):
		if GameManager and not GameManager.map_data.is_empty():
			var fallback_stats = _ziskej_souhrn_statu(owner_tag, GameManager.map_data)
			if int(fallback_stats.get("soldiers", 0)) > 0 or int(fallback_stats.get("population", 0)) > 0:
				stats = fallback_stats
				total_pop = int(stats.get("population", 0))
				total_gdp = float(stats.get("gdp", 0.0))
				total_recruits = int(stats.get("recruits", 0))
				total_soldiers = int(stats.get("soldiers", 0))
			
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
		var stable_multiplier = 1.0
		if GameManager.has_method("ziskej_silu_armady_statu"):
			var power_info = GameManager.ziskej_silu_armady_statu(owner_tag, total_soldiers) as Dictionary
			army_total = int(power_info.get("total", total_soldiers))
			bonus_flat = int(power_info.get("bonus_flat", 0))
			bonus_pct = float(power_info.get("bonus_pct", 0.0)) * 100.0
		stable_multiplier = 1.0 + (bonus_pct / 100.0)
		army_power_label.text = "Army strength: %s total | lab mult %.3fx | +%d flat" % [_formatuj_cislo(army_total), stable_multiplier, bonus_flat]
	gdp_label.text = "Total GDP: %.2f bn USD" % total_gdp
	
	# Calculate GDP per capita
	if total_pop > 0:
		var gdp_per_capita = (total_gdp * 1000000000.0) / float(total_pop)
		gdp_pc_label.text = "GDP per capita: $%.0f" % gdp_per_capita
	else:
		gdp_pc_label.text = "GDP per capita: N/A"
	_aktualizuj_mirove_overview_statistiky(owner_tag, owner_tag == player_tag)
	_aktualizuj_tlacitko_vazalu(owner_tag == player_tag)
	_aktualizuj_ai_debug_overview(owner_tag, owner_tag == player_tag)

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
			if trade_btn: trade_btn.hide()
			if alliance_btn:
				alliance_btn.show()
				_aktualizuj_aliance_ui(owner_tag)
			declare_war_btn.hide()
			propose_peace_btn.hide()
			if non_aggression_btn: non_aggression_btn.hide()
			if give_loan_btn: give_loan_btn.hide()
			if take_loan_btn: take_loan_btn.hide()
			if _military_access_btn: _military_access_btn.hide()
			if incoming_request_label: incoming_request_label.hide()
			if respond_request_buttons: respond_request_buttons.hide()
			if research_btn: research_btn.show()
			if _loans_dialog and _loans_dialog.visible:
				_loans_dialog.hide()
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
			if alliance_btn: alliance_btn.show()
			_aktualizuj_aliance_ui(owner_tag)
			_aktualizuj_diplomacii_tlacitka(owner_tag)
			if non_aggression_btn: non_aggression_btn.show()
			if give_loan_btn: give_loan_btn.show()
			if take_loan_btn: take_loan_btn.show()
			_aktualizuj_zadost_ui(owner_tag)
			if research_btn: research_btn.hide()
	
	panel.show()
	call_deferred("obnov_layout_ui")

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

# Handles this signal callback.
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
	# backend vraci relation_changes; z nich stavime lidsky summary popup.
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

# Triggered by a UI/game signal.
func _on_ideology_option_selected(index: int) -> void:
	if _updating_ideology_ui:
		return
	if index < 0 or index >= _ideology_option_values.size():
		return
	_obnov_nahled_ideologie_podle_volby()

# Triggered by right-clicking on the map
# Hides UI/output and resets related temporary state.
func schovej_se():
	panel.hide()
	# Keep peace conference open until player exits manually.
	if _research_dialog and _research_dialog.visible:
		_zavri_vyzkum_dialog()
	_zavri_alliance_dialog()
	if research_btn:
		research_btn.hide()
	_current_viewed_province_id = -1
	_ceka_na_vyber_cile_hlavniho_mesta = false
	_relocate_capital_action_lock = false
	_vycisti_nahled_ideologie_v_ui()
	call_deferred("obnov_layout_ui")

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
# Event handler for user or game actions.
func _on_declare_war_button_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
		
	# Declare war via GameManager
	GameManager.vyhlasit_valku(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

func _on_propose_peace_button_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return

	GameManager.nabidnout_mir(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

func _on_non_aggression_button_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("uzavrit_neagresivni_smlouvu"):
		return

	var success = bool(GameManager.uzavrit_neagresivni_smlouvu(GameManager.hrac_stat, current_viewed_tag))
	if success:
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()

# Handles this signal callback.
func _on_military_access_btn_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if not GameManager.has_method("pozadej_vojensky_pristup"):
		return
	# If player already has manual access, revoke it.
	var has_access = GameManager.has_method("ma_vojensky_pristup") and bool(GameManager.ma_vojensky_pristup(GameManager.hrac_stat, current_viewed_tag))
	var is_alliance = GameManager.has_method("ziskej_uroven_aliance") and int(GameManager.ziskej_uroven_aliance(GameManager.hrac_stat, current_viewed_tag)) > 0
	if has_access and not is_alliance:
		if GameManager.has_method("odvolej_vojensky_pristup"):
			GameManager.odvolej_vojensky_pristup(current_viewed_tag, GameManager.hrac_stat)
		_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
		_aktualizuj_panel_zprav()
		zobraz_systemove_hlaseni("Military Access", "You revoked military access from %s." % current_viewed_tag)
		return
	# Request access
	var granted = bool(GameManager.pozadej_vojensky_pristup(GameManager.hrac_stat, current_viewed_tag))
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_panel_zprav()
	if GameManager.je_lidsky_stat(current_viewed_tag):
		zobraz_systemove_hlaseni("Military Access", "Request for military access sent to %s." % current_viewed_tag)
	elif granted:
		zobraz_systemove_hlaseni("Military Access", "%s granted you military access to their territory." % current_viewed_tag)
	else:
		var rel = 0.0
		if GameManager.has_method("ziskej_vztah_statu"):
			rel = float(GameManager.ziskej_vztah_statu(GameManager.hrac_stat, current_viewed_tag))
		zobraz_systemove_hlaseni("Military Access Denied", "%s refused military access.\nRelations: %.0f (minimum required: 15)." % [current_viewed_tag, rel])

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

# Reacts to incoming events.
func _on_accept_request_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or _current_incoming_request.is_empty():
		return
	if not GameManager.has_method("hrac_prijmi_diplomatickou_zadost"):
		return
	var req = _current_incoming_request.duplicate(true)
	var accepted = GameManager.hrac_prijmi_diplomatickou_zadost(GameManager.hrac_stat, current_viewed_tag)
	if accepted and str(req.get("type", "")) == "loan":
		var topbar = get_tree().current_scene.find_child("TopBar", true, false)
		if topbar and topbar.has_method("aktualizuj_ui"):
			topbar.aktualizuj_ui()
		var payload = req.get("payload", {}) as Dictionary
		var principal = float(payload.get("principal", 0.0))
		zobraz_systemove_hlaseni("Loans", "Loan accepted: %.0f M USD transferred." % principal)
	_aktualizuj_zadost_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_popup_diplomatickych_zadosti()

# Event handler for user or game actions.
func _on_decline_request_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or _current_incoming_request.is_empty():
		return
	if not GameManager.has_method("hrac_odmitni_diplomatickou_zadost"):
		return
	GameManager.hrac_odmitni_diplomatickou_zadost(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_zadost_ui(current_viewed_tag)
	_aktualizuj_diplomacii_tlacitka(current_viewed_tag)
	_aktualizuj_popup_diplomatickych_zadosti()

func _on_improve_relationship_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if GameManager.has_method("zlepsi_vztah_statu"):
		GameManager.zlepsi_vztah_statu(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_vztah_ui(current_viewed_tag)

func _on_worsen_relationship_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat:
		return
	if GameManager.has_method("zhorsi_vztah_statu"):
		GameManager.zhorsi_vztah_statu(GameManager.hrac_stat, current_viewed_tag)
	_aktualizuj_vztah_ui(current_viewed_tag)
	_aktualizuj_aliance_ui(current_viewed_tag)

func _on_alliance_level_selected(_index: int):
	# Legacy stub - alliance management moved to popup dialog
	pass

func _on_alliance_button_pressed():
	if _je_spectate_observer_mode():
		return
	if current_viewed_tag == "":
		return
	_alliance_dialog_target_tag = current_viewed_tag
	_otevri_alliance_dialog(current_viewed_tag)

func _on_kolo_zmeneno():
	_country_overview_stats_cache.clear()
	_diplomacy_popup_dismissed_signature = ""
	if _loans_dialog:
		_loans_dialog.hide()
	if GameManager and GameManager.has_method("vyzvedni_notifikace_pujcek_hrace"):
		var loan_notes = GameManager.vyzvedni_notifikace_pujcek_hrace(GameManager.hrac_stat) as Array
		for note_any in loan_notes:
			var note = str(note_any).strip_edges()
			if note != "":
				_pending_loan_notes.append(note)
	if not _pending_loan_notes.is_empty() and not (GameManager and bool(GameManager.zpracovava_se_tah)):
		call_deferred("_zobraz_pending_loan_notes")
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
	if trade_btn:
		trade_btn.text = "Trade"
		trade_btn.disabled = current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat
		trade_btn.visible = not (current_viewed_tag == "" or current_viewed_tag == GameManager.hrac_stat)

	_aktualizuj_aliance_ui(target_tag)
	_aktualizuj_diplomacii_tlacitka(target_tag)
	_aktualizuj_zadost_ui(target_tag)

# Recomputes values from current data.
func _aktualizuj_diplomacii_tlacitka(target_tag: String):
	if not declare_war_btn or not propose_peace_btn:
		return
	if _je_spectate_observer_mode():
		declare_war_btn.text = "Spectate mode"
		declare_war_btn.disabled = true
		declare_war_btn.show()
		propose_peace_btn.hide()
		if improve_rel_btn:
			improve_rel_btn.disabled = true
		if worsen_rel_btn:
			worsen_rel_btn.disabled = true
		if gift_money_btn:
			gift_money_btn.hide()
		if trade_btn:
			trade_btn.hide()
		if non_aggression_btn:
			non_aggression_btn.hide()
		if give_loan_btn:
			give_loan_btn.hide()
		if take_loan_btn:
			take_loan_btn.hide()
		if alliance_btn:
			alliance_btn.disabled = true
		if _military_access_btn:
			_military_access_btn.hide()
		return

	var target = target_tag.strip_edges().to_upper()
	var me = str(GameManager.hrac_stat).strip_edges().to_upper()
	if target == "" or target == me:
		declare_war_btn.hide()
		propose_peace_btn.hide()
		if non_aggression_btn:
			non_aggression_btn.hide()
		if gift_money_btn:
			gift_money_btn.hide()
		if trade_btn:
			trade_btn.hide()
		if _military_access_btn:
			_military_access_btn.hide()
		return

	if gift_money_btn:
		gift_money_btn.show()
	if trade_btn:
		trade_btn.show()

	if GameManager.jsou_ve_valce(GameManager.hrac_stat, target):
		# war branch: peace button muze byt pending, war button je tvrdy lock.
		declare_war_btn.text = "AT WAR"
		declare_war_btn.disabled = true
		declare_war_btn.modulate = Color(1, 0.5, 0.5)
		declare_war_btn.show()

		var ceka_na_odpoved = GameManager.je_mirova_nabidka_cekajici(GameManager.hrac_stat, target)
		propose_peace_btn.text = "Proposal sent" if ceka_na_odpoved else "Offer peace"
		propose_peace_btn.disabled = ceka_na_odpoved
		propose_peace_btn.modulate = Color(1, 1, 1)
		propose_peace_btn.show()

		if alliance_btn:
			alliance_btn.disabled = true
		if non_aggression_btn:
			non_aggression_btn.text = "Non-aggression pact (war locked)"
			non_aggression_btn.disabled = true
			non_aggression_btn.modulate = Color(1, 1, 1)
		if trade_btn:
			trade_btn.disabled = false
		if _military_access_btn:
			_military_access_btn.hide()
	else:
		# peace branch: declare war je blokovan alianci, NAP nebo peace cooldownem.
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

		if alliance_btn:
			alliance_btn.disabled = false

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

		if _military_access_btn:
			var has_access = false
			var pending = false
			if GameManager.has_method("ma_vojensky_pristup"):
				has_access = bool(GameManager.ma_vojensky_pristup(GameManager.hrac_stat, target))
			if not has_access and GameManager.has_method("_ma_cekajici_zadost_vojenskeho_pristupu"):
				pending = bool(GameManager._ma_cekajici_zadost_vojenskeho_pristupu(GameManager.hrac_stat, target))
			if alliance_level > 0:
				_military_access_btn.text = "Military access -> (alliance)"
				_military_access_btn.disabled = true
			elif has_access:
				_military_access_btn.text = "Military access -> (Revoke)"
				_military_access_btn.disabled = false
			elif pending:
				_military_access_btn.text = "Military access (pending...)"
				_military_access_btn.disabled = true
			else:
				_military_access_btn.text = "Request military access"
				_military_access_btn.disabled = false
			_military_access_btn.show()

