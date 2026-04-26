# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Control
# this script drives a specific gameplay/UI area and keeps related logic together.

# Main menu flow controller: new game, load, settings and country selection.
# Hard part: this scene also prepares per-player setup and persistent settings,
# so it acts as bridge before map scene boot.

const ControlsConfig = preload("res://scripts/ControlsConfig.gd")
const CountryCustomization = preload("res://scripts/CountryCustomization.gd")
const TooltipUtilsScript = preload("res://scripts/TooltipUtils.gd")

@onready var selected_country_label: Label = $CenterPanel/MarginContainer/VBoxContainer/SelectedCountryLabel
@onready var menu_hint_label: Label = $CenterPanel/MarginContainer/VBoxContainer/MenuHint
@onready var title_label: Label = $CenterPanel/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterPanel/MarginContainer/VBoxContainer/Subtitle

@onready var btn_new_game: Button = $CenterPanel/MarginContainer/VBoxContainer/MainButtons/NewGameButton
@onready var btn_continue: Button = $CenterPanel/MarginContainer/VBoxContainer/MainButtons/ContinueButton
@onready var btn_settings: Button = $CenterPanel/MarginContainer/VBoxContainer/SecondaryButtons/SettingsButton
@onready var btn_credits: Button = $CenterPanel/MarginContainer/VBoxContainer/SecondaryButtons/CreditsButton
@onready var btn_exit: Button = $CenterPanel/MarginContainer/VBoxContainer/ExitButton

@onready var country_browser_panel: PanelContainer = $CountryBrowserPanel
@onready var country_browser_margin: MarginContainer = $CountryBrowserPanel/MarginContainer
@onready var country_browser_root_vbox: VBoxContainer = $CountryBrowserPanel/MarginContainer/RootVBox
@onready var btn_close_corner: Button = $CountryBrowserPanel/MarginContainer/RootVBox/HeaderRow/CloseHeaderButton
@onready var browser_title: Label = $CountryBrowserPanel/MarginContainer/RootVBox/HeaderRow/BrowserTitle
@onready var browser_subtitle: Label = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserSubtitle
@onready var browser_flow_hint: Label = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserFlowHint
@onready var selected_players_panel: PanelContainer = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel
@onready var selected_players_margin: MarginContainer = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel/SelectedPlayersMargin
@onready var selected_players_title: Label = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel/SelectedPlayersMargin/SelectedPlayersVBox/SelectedPlayersTitle
@onready var selected_players_list: Label = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel/SelectedPlayersMargin/SelectedPlayersVBox/SelectedPlayersList
@onready var list_hint: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/ListPanel/ListMargin/ListVBox/ListHint
@onready var country_list_scroll: ScrollContainer = $CountryBrowserPanel/MarginContainer/RootVBox/Content/ListPanel/ListMargin/ListVBox/CountryListScroll
@onready var country_list: VBoxContainer = $CountryBrowserPanel/MarginContainer/RootVBox/Content/ListPanel/ListMargin/ListVBox/CountryListScroll/CountryList
@onready var detail_flag: TextureRect = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailFlag
@onready var detail_name: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailName
@onready var detail_tag: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailTag
@onready var detail_ideology: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailIdeology
@onready var detail_population: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailPopulation
@onready var detail_gdp: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailGdp
@onready var detail_recruits: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailRecruits
@onready var detail_soldiers: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailSoldiers
@onready var detail_provinces: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailProvinceCount
@onready var detail_info: RichTextLabel = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailInfo
@onready var btn_confirm_country: Button = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserButtons/ConfirmCountryButton
@onready var btn_close_browser: Button = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserButtons/CloseBrowserButton
@onready var browser_buttons_row: HBoxContainer = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserButtons

@onready var settings_dialog: AcceptDialog = $Dialogs/SettingsDialog
@onready var credits_dialog: AcceptDialog = $Dialogs/CreditsDialog
@onready var exit_dialog: ConfirmationDialog = $Dialogs/ExitDialog
@onready var settings_header_title: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsHeader/SettingsHeaderTitle
@onready var settings_header_subtitle: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsHeader/SettingsHeaderSubtitle

@onready var controls_btn: Button = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/TabSwitcher/ControlsTabBtn
@onready var settings_btn: Button = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/TabSwitcher/SettingsTabBtn
@onready var controls_panel: PanelContainer = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel
@onready var settings_panel: PanelContainer = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel
@onready var controls_content: VBoxContainer = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent
@onready var settings_content: VBoxContainer = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent
@onready var controls_info: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ControlsInfo
@onready var camera_speed_label: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/CameraSpeedLabel
@onready var camera_speed_slider: HSlider = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/CameraSpeedRow/CameraSpeedSlider
@onready var camera_speed_value: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/CameraSpeedRow/CameraSpeedValue
@onready var zoom_speed_label: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ZoomSpeedLabel
@onready var zoom_speed_slider: HSlider = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ZoomSpeedRow/ZoomSpeedSlider
@onready var zoom_speed_value: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ZoomSpeedRow/ZoomSpeedValue
@onready var invert_zoom_check: CheckBox = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/InvertZoomCheck
@onready var controls_scheme_title: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ControlsSchemeTitle
@onready var controls_scheme_text: RichTextLabel = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/ControlsPanel/ControlsPad/ControlsContent/ControlsSchemeText

@onready var language_label: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/LanguageLabel
@onready var language_option: OptionButton = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/LanguageRow/LanguageOption
@onready var language_hint: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/LanguageHint
@onready var fullscreen_check: CheckBox = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/FullscreenCheck
@onready var vsync_check: CheckBox = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/VsyncCheck
var potato_mode_check: CheckBox = null
var ai_debug_mode_check: CheckBox = null
var skip_battle_reports_check: CheckBox = null
@onready var master_volume_label: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/MasterVolumeLabel
@onready var master_volume_slider: HSlider = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/MasterVolumeRow/MasterVolumeSlider
@onready var master_volume_value: Label = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsPanel/SettingsPad/SettingsContent/MasterVolumeRow/MasterVolumeValue
@onready var btn_settings_reset: Button = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsButtons/ResetButton
@onready var btn_settings_apply: Button = $Dialogs/SettingsDialog/SettingsRoot/SettingsVBox/SettingsButtons/ApplyButton

var _btn_apply_cache: Button = null
var _btn_reset_cache: Button = null
var _keybind_buttons: Dictionary = {}
var _keybind_capture_action: String = ""
var _keybind_state: Dictionary = {}
var _keybind_grid: GridContainer = null
var _center_panel_cache: PanelContainer = null

# List of playable countries (Display Name : Tag)
var hratelne_staty = {
	"Albania": "ALB",
	"Austria": "AUT",
	"Belgium": "BEL",
	"Bulgaria": "BGR",
	"Bosnia and Herzegovina": "BIH",
	"Belarus": "BLR",
	"Switzerland": "CHE",
	"Cyprus": "CYP",
	"Czech Republic": "CZE",
	"Germany": "DEU",
	"Denmark": "DNK",
	"Spain": "ESP",
	"Estonia": "EST",
	"Finland": "FIN",
	"France": "FRA",
	"United Kingdom": "GBR",
	"Georgia": "GEO",
	"Greece": "GRC",
	"Croatia": "HRV",
	"Hungary": "HUN",
	"Ireland": "IRL",
	"Island": "ISL",
	"Italy": "ITA",
	"Kosovo": "KOS",
	"Lithuania": "LTU",
	"Luxembourg": "LUX",
	"Latvia": "LVA",
	"Moldova": "MDA",
	"North Macedonia": "MKD",
	"Montenegro": "MNE",
	"Netherlands": "NLD",
	"Norway": "NOR",
	"Poland": "POL",
	"Portugal": "PRT",
	"Romania": "ROU",
	"Russia": "RUS",
	"Serbia": "SRB",
	"Slovakia": "SVK",
	"Slovenia": "SVN",
	"Sweden": "SWE",
	"Turkey": "TUR",
	"Ukraine": "UKR"
}

const MAP_SCENE_PATH := "res://scenes/map.tscn"
const SAVE_FILE_PATH := "user://savegame.dat"
const SETTINGS_FILE_PATH := "user://settings.cfg"
const PROVINCES_DATA_PATHS := [
	"res://map_data/province.txt",
	"res://map_data/Province.txt",
	"res://map_data/Provinces.txt"
]
const SETTINGS_DIALOG_TITLE := "Settings"
const CREDITS_DIALOG_TITLE := "Credits"
const CREDITS_DIALOG_TEXT := "RP-2025-26\n\nDesign and gameplay: ME (Afrox26TP)\nMap and data: internal dataset (mine)\nTester: Andhyy (outsourced)"
const EXIT_DIALOG_TITLE := "Confirmation"
const EXIT_DIALOG_TEXT := "Do you really want to quit the game?"
const SETTINGS_DEFAULT_LANGUAGE := "en"

const UI_TEXTS := {
	"en": {
		"title": "EUROPEAN MAP PROJECT",
		"subtitle": "Turn-based grand strategy game | School project 2025-26",
		"new_game": "New Game",
		"continue": "Load",
		"continue_empty": "Load (no save)",
		"settings": "Settings",
		"credits": "Credits",
		"quit": "Quit game",
		"settings_title": "Settings",
		"settings_header_title": "Game Settings",
		"settings_header_subtitle": "Customize controls, language, and gameplay preferences",
		"settings_header_subtitle_clean": "All changes saved",
		"settings_header_subtitle_dirty": "Unsaved changes - press Apply",
		"tab_settings": "Settings",
		"tab_controls": "Controls",
		"tab_language": "Language",
		"tab_other": "Other",
		"controls_info": "Map controls",
		"camera_speed": "Camera move speed",
		"zoom_speed": "Zoom speed",
		"invert_zoom": "Invert mouse wheel zoom",
		"controls_static_title": "Current keybinds",
		"controls_static_text": "Core controls\n- WASD / Arrows: move camera\n- Mouse wheel: zoom\n- Right mouse hold + drag: pan map\n- Space: end turn\n- Right click: cancel action or close open dialogs\n- C: developer quick conquer tool\n\nMap mode hotkeys\n- 1: Political\n- 2: Population\n- 3: GDP\n- 4: Ideology\n- 5: Recruitable Population\n- 6: Relations\n- 7: Terrain\n- 8: Resources",
		"language_info": "Language",
		"language_label": "UI language",
		"language_hint": "Switches main menu and settings labels immediately.",
		"other_info": "Other",
		"fullscreen": "Fullscreen",
		"vsync": "VSync",
		"potato_mode": "Potato mode (low-end PC)",
		"ai_debug_mode": "Debug mode",
		"skip_battle_reports": "Skip battle reports on end turn",
		"spectate_mode": "Spectate mode (AI only)",
		"master_volume": "Master volume",
		"reset": "Reset defaults",
		"apply": "Apply",
		"close": "Close"
	},
	"cs": {
		"title": "EUROPEAN MAP PROJECT",
		"subtitle": "Tahova grand strategy hra | Skolni projekt 2025-26",
		"new_game": "New Game",
		"continue": "Load",
		"continue_empty": "Load (bez ulozeni)",
		"settings": "Nastaveni",
		"credits": "Autori",
		"quit": "Ukoncit hru",
		"settings_title": "Nastaveni",
		"settings_header_title": "Nastaveni hry",
		"settings_header_subtitle": "Uprav ovladani, jazyk a herni preference",
		"settings_header_subtitle_clean": "Vsechny zmeny jsou ulozene",
		"settings_header_subtitle_dirty": "Mas neulozene zmeny - stiskni Pouzit",
		"tab_settings": "Nastaveni",
		"tab_controls": "Ovladani",
		"tab_language": "Jazyk",
		"tab_other": "Ostatni",
		"controls_info": "Ovladani mapy",
		"camera_speed": "Rychlost posunu kamery",
		"zoom_speed": "Rychlost zoomu",
		"invert_zoom": "Obratit zoom koleckem",
		"controls_static_title": "Aktualni ovladani",
		"controls_static_text": "Zakladni ovladani\n- WASD / Sipky: posun kamery\n- Kolecko mysi: zoom\n- Drzeni praveho tlacitka + tah: posun mapy\n- Mezernik: ukoncit kolo\n- Prave tlacitko: zrusit akci nebo zavrit dialog\n- C: vyvojarsky rychly conquer tool\n\nHotkeys pro map mody\n- 1: Politicky\n- 2: Populace\n- 3: HDP\n- 4: Ideologie\n- 5: Rekrutovatelna populace\n- 6: Vztahy\n- 7: Teren\n- 8: Suroviny",
		"language_info": "Jazyk",
		"language_label": "Jazyk rozhrani",
		"language_hint": "Zmeni texty v hlavnim menu a nastaveni ihned.",
		"other_info": "Ostatni",
		"fullscreen": "Cela obrazovka",
		"vsync": "VSync",
		"potato_mode": "Potato mode (slabe PC)",
		"ai_debug_mode": "Debug mode",
		"skip_battle_reports": "Preskocit battle reporty na konci kola",
		"spectate_mode": "Spectate mode (pouze AI)",
		"master_volume": "Hlavni hlasitost",
		"reset": "Obnovit vychozi",
		"apply": "Pouzit",
		"close": "Zavrit"
	}
}

var country_stats: Dictionary = {}
var flag_texture_cache: Dictionary = {}
var normalized_flag_texture_cache: Dictionary = {}
var country_rows: Dictionary = {}
var selected_country_tag_in_browser: String = ""
var selected_country_tag: String = "ALB"
var new_game_browser_flow: bool = false
var local_player_tags: Array = []
var setup_active_player_index: int = 0
var nastaveni_data: Dictionary = {}
var _settings_original_ui_state: Dictionary = {}
var _load_dialog: AcceptDialog = null
var _load_scroll_vbox: VBoxContainer = null
var _load_status_label: Label = null
var _load_open_button: Button = null
var _load_slot_btns: Dictionary = {}
var _selected_load_slot_key: String = ""
var _browser_helper_btn: Button = null
var _language_hint_helper_btn: Button = null
var _global_ai_aggression: float = 0.5
var _ai_aggression_row: HBoxContainer = null
var _ai_aggression_label: Label = null
var _ai_aggression_slider: HSlider = null
var _ai_aggression_value: Label = null
var _browser_current_settings_panel: PanelContainer = null
var _browser_current_settings_vbox: VBoxContainer = null
var _browser_potato_mode_check: CheckBox = null
var _browser_ai_debug_mode_check: CheckBox = null
var _browser_spectate_mode_check: CheckBox = null
var _browser_settings_country_separator: HSeparator = null
var _selected_players_flag_list: HFlowContainer = null
var _selected_players_scroll: ScrollContainer = null
var _settings_controls_scroll: ScrollContainer = null
var _settings_options_scroll: ScrollContainer = null
var _browser_root_scroll: ScrollContainer = null
var _browser_compact_mode: bool = false
var _browser_tiny_mode: bool = false
const _PLAYER_ROW_H := 26
const _PLAYER_ROW_MAX_H := 420
const _PLAYER_CHIP_MIN_W := 210
const _PLAYER_ACTIVE_EXTRA_W := 24
const _PLAYER_ACTIVE_EXTRA_H := 8
const BROWSER_CONFIRM_DEFAULT_TEXT := "Confirm selection"
const BROWSER_CONFIRM_ADD_PLAYER_TEXT := "Add player"
const BROWSER_CLOSE_DEFAULT_TEXT := "Close"
const BROWSER_CLOSE_START_TEXT := "Start game"
const COUNTRY_BROWSER_MIN_WIDTH := 640.0
const COUNTRY_BROWSER_MAX_WIDTH := 1500.0
const COUNTRY_BROWSER_MIN_HEIGHT := 360.0
const COUNTRY_BROWSER_MAX_HEIGHT := 900.0
const COUNTRY_BROWSER_LIST_MIN_W := 280.0
const COUNTRY_BROWSER_DETAIL_MIN_W := 360.0
const COUNTRY_BROWSER_VIEWPORT_MARGIN := 16.0
const COUNTRY_BROWSER_SAFE_MIN_W := 280.0
const COUNTRY_BROWSER_SAFE_MIN_H := 180.0
const COUNTRY_BROWSER_BUTTON_H_DEFAULT := 52.0
const COUNTRY_BROWSER_BUTTON_H_COMPACT := 44.0
const COUNTRY_BROWSER_BUTTON_H_TINY := 38.0
const COUNTRY_BROWSER_ROW_H_DEFAULT := 74.0
const COUNTRY_BROWSER_ROW_H_COMPACT := 44.0
const COUNTRY_BROWSER_ROW_H_TINY := 38.0
const SETTINGS_DIALOG_BASE_SIZE := Vector2i(960, 840)
const SETTINGS_DIALOG_MIN_SIZE := Vector2i(560, 440)
const COUNTRY_BROWSER_COMPACT_H := 1078.0
const COUNTRY_BROWSER_TINY_H := 1078.0
const COUNTRY_BROWSER_COMPACT_W := 1997.0
const COUNTRY_BROWSER_TINY_W := 1997.0
const COUNTRY_BROWSER_VIEWPORT_FIT_H := 930.0
const COUNTRY_BROWSER_VIEWPORT_FIT_W := 1320.0

# Resource loading with validation.
func _load_texture_cached(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not flag_texture_cache.has(path):
		flag_texture_cache[path] = load(path)
	return flag_texture_cache[path]

# Pulls data and verifies parse output.
func _load_normalized_flag_texture(path: String, width: int, height: int):
	var cache_key = "%s|%d|%d" % [path, width, height]
	if normalized_flag_texture_cache.has(cache_key):
		return normalized_flag_texture_cache[cache_key]

	var base_tex = _load_texture_cached(path)
	if base_tex == null:
		return null

	var base_img = base_tex.get_image()
	if base_img == null:
		return base_tex

	var src_w = base_img.get_width()
	var src_h = base_img.get_height()
	if src_w <= 0 or src_h <= 0:
		return base_tex

	var scale_factor = min(float(width) / float(src_w), float(height) / float(src_h))
	var out_w = max(1, int(round(src_w * scale_factor)))
	var out_h = max(1, int(round(src_h * scale_factor)))

	var resized_img = base_img.duplicate()
	resized_img.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	var canvas = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dst_pos = Vector2i((width - out_w) / 2, (height - out_h) / 2)
	canvas.blit_rect(resized_img, Rect2i(Vector2i.ZERO, Vector2i(out_w, out_h)), dst_pos)

	var normalized_tex = ImageTexture.create_from_image(canvas)
	normalized_flag_texture_cache[cache_key] = normalized_tex
	return normalized_tex

# Runs the local feature logic.
func _vloz_centered_helper_pred_label(label: Label) -> Button:
	if label == null or label.get_parent() == null:
		return null
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_spacer)
	var help_btn := TooltipUtilsScript.create_help_button(label.text)
	row.add_child(help_btn)
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_spacer)
	var parent := label.get_parent()
	parent.add_child(row)
	parent.move_child(row, label.get_index())
	label.hide()
	return help_btn

# Builds UI objects and default wiring.
func _vytvor_clean_helpery() -> void:
	if _browser_helper_btn == null and btn_close_corner and btn_close_corner.get_parent() != null:
		_browser_helper_btn = TooltipUtilsScript.create_help_button("")
		_browser_helper_btn.pressed.connect(func(): TooltipUtilsScript.show_help_dropdown(self, _browser_helper_btn, _browser_helper_btn.tooltip_text))
		var browser_header := btn_close_corner.get_parent()
		browser_header.add_child(_browser_helper_btn)
		browser_header.move_child(_browser_helper_btn, btn_close_corner.get_index())
		browser_subtitle.hide()
		browser_flow_hint.hide()
		list_hint.hide()
	if _language_hint_helper_btn == null and language_option and language_option.get_parent() != null:
		_language_hint_helper_btn = TooltipUtilsScript.create_help_button(language_hint.text)
		_language_hint_helper_btn.pressed.connect(func(): TooltipUtilsScript.show_help_dropdown(self, _language_hint_helper_btn, _language_hint_helper_btn.tooltip_text))
		language_option.get_parent().add_child(_language_hint_helper_btn)
		language_hint.hide()
	_aktualizuj_clean_helpery()

# Rebuilds state from latest data.
func _aktualizuj_clean_helpery() -> void:
	if _browser_helper_btn:
		var browser_parts: Array[String] = []
		for part in [browser_subtitle.text, browser_flow_hint.text, list_hint.text]:
			var clean_part := str(part).strip_edges()
			if clean_part != "":
				browser_parts.append(clean_part)
		_browser_helper_btn.tooltip_text = "\n".join(browser_parts)
		_browser_helper_btn.visible = not browser_parts.is_empty()
	if _language_hint_helper_btn:
		_language_hint_helper_btn.tooltip_text = language_hint.text
		_language_hint_helper_btn.visible = language_hint.text.strip_edges() != ""

# Initializes references, connects signals, and prepares default runtime state.
func _ready():
	# Startup order matters: load settings/data first, then build UI from that state.
	# Pro male dite: tady se pri zapnuti hry pripravi uplne vse, aby tlacitka fungovala hned.
	ControlsConfig.ensure_default_actions()
	_nacti_nastaveni()
	_nastav_texty_dialogu()
	_nacti_data_statu_pro_browser()
	_log_export_data_diagnostics()
	_show_export_diagnostics_if_missing_data()
	_restore_country_browser_root_layout()
	_naplni_browser_seznam()
	_apply_country_browser_window_size()
	_ensure_ai_aggression_control()
	_ensure_selected_players_flag_list()
	_nastav_vychozi_vyber_statu()
	_obnov_text_vyberu()
	_nastav_stav_pokracovani()
	_aktualizuj_browser_napovedu()
	_apply_main_menu_window_size()
	country_browser_panel.hide()
	_ensure_potato_mode_checkbox()
	_ensure_ai_debug_mode_checkbox()
	_ensure_skip_battle_reports_checkbox()

	# Connect UI signals
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_confirm_country.pressed.connect(_on_confirm_country_pressed)
	btn_close_browser.pressed.connect(_on_close_browser_pressed)
	btn_close_corner.pressed.connect(_on_close_browser_corner_pressed)
	controls_btn.pressed.connect(_on_controls_tab_clicked)
	settings_btn.pressed.connect(_on_settings_tab_clicked)
	
	# Connect settings button signals with safe handling
	_ensure_settings_buttons_connected()
	
	language_option.item_selected.connect(_on_language_option_selected)
	camera_speed_slider.value_changed.connect(_on_settings_value_changed)
	zoom_speed_slider.value_changed.connect(_on_settings_value_changed)
	master_volume_slider.value_changed.connect(_on_settings_value_changed)
	invert_zoom_check.toggled.connect(_on_settings_toggle_changed)
	fullscreen_check.toggled.connect(_on_settings_toggle_changed)
	vsync_check.toggled.connect(_on_settings_toggle_changed)
	if potato_mode_check:
		potato_mode_check.toggled.connect(_on_settings_toggle_changed)
	if ai_debug_mode_check:
		ai_debug_mode_check.toggled.connect(_on_settings_toggle_changed)
	if skip_battle_reports_check:
		skip_battle_reports_check.toggled.connect(_on_settings_toggle_changed)
	exit_dialog.confirmed.connect(_on_exit_confirmed)

	_napln_language_option()
	_nastav_settings_ui_z_dat()
	_aplikuj_nastaveni_globalne()
	_aktualizuj_settings_hodnoty()
	_aktualizuj_texty_dle_jazyka()
	_ensure_keybind_controls()
	_refresh_keybind_buttons()
	_vytvor_clean_helpery()
	_nastav_tooltipy_ui()
	_vytvor_load_dialog()
	_styluj_mainmenu_popup_dialogy()
	_show_settings_tab(0)  # Start with Controls tab
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

# Runs the local feature logic.
func _log_export_data_diagnostics() -> void:
	# Export diagnostics for missing data/assets in standalone builds.
	var checks: Array[String] = [
		"res://map_data/Provinces.txt",
		"res://map_data/Relationships.csv",
		"res://map_data/Alliances.csv",
		"res://map_data/Flags/ALB.svg",
		"res://map_data/ArmyIcons/ALB.svg",
		"res://map_data/PoliticalMap.png",
		"res://map_data/ProvinceIDMask.png"
	]
	print("[ExportCheck] resolved_provinces_path=", _resolve_provinces_data_path())
	for p in checks:
		print("[ExportCheck] ", p, " file_exists=", FileAccess.file_exists(p), " resource_exists=", ResourceLoader.exists(p))
	if country_stats.is_empty():
		push_warning("[ExportCheck] country_stats is empty after data load. Export likely misses map_data raw files.")

# Updates what the player sees.
func _show_export_diagnostics_if_missing_data() -> void:
	if not country_stats.is_empty():
		return

	var checks: Array[String] = [
		"res://map_data/Provinces.txt",
		"res://map_data/Relationships.csv",
		"res://map_data/Alliances.csv",
		"res://map_data/Flags/ALB.svg",
		"res://map_data/ArmyIcons/ALB.svg",
		"res://map_data/PoliticalMap.png",
		"res://map_data/ProvinceIDMask.png"
	]

	var lines: Array[String] = []
	lines.append("Country data could not be loaded in this build.")
	lines.append("resolved_provinces_path: %s" % _resolve_provinces_data_path())
	lines.append("exe: %s" % OS.get_executable_path())
	lines.append("")
	lines.append("File checks:")
	for p in checks:
		lines.append("- %s | file=%s | resource=%s" % [
			p,
			str(FileAccess.file_exists(p)),
			str(ResourceLoader.exists(p))
		])

	var dlg := AcceptDialog.new()
	dlg.title = "Export Data Diagnostics"
	dlg.dialog_text = "\n".join(lines)
	dlg.exclusive = false
	add_child(dlg)
	dlg.popup_centered_ratio(0.72)

# Applies prepared settings/effects to runtime systems.
func _apply_country_browser_window_size() -> void:
	if country_browser_panel == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size = vp.get_visible_rect().size
	var viewport_fit = vp_size.y < COUNTRY_BROWSER_VIEWPORT_FIT_H or vp_size.x < COUNTRY_BROWSER_VIEWPORT_FIT_W
	var browser_width = clampf(vp_size.x * 0.92, COUNTRY_BROWSER_MIN_WIDTH, COUNTRY_BROWSER_MAX_WIDTH)
	var tiny_layout = vp_size.y < COUNTRY_BROWSER_TINY_H or vp_size.x < COUNTRY_BROWSER_TINY_W
	var compact_height = tiny_layout or vp_size.y < COUNTRY_BROWSER_COMPACT_H or vp_size.x < COUNTRY_BROWSER_COMPACT_W
	var height_ratio = 0.58 if tiny_layout else (0.66 if compact_height else 0.84)
	var browser_height = clampf(vp_size.y * height_ratio, COUNTRY_BROWSER_MIN_HEIGHT, COUNTRY_BROWSER_MAX_HEIGHT)
	var edge = 8.0 if tiny_layout else (12.0 if compact_height else COUNTRY_BROWSER_VIEWPORT_MARGIN)
	browser_width = minf(browser_width, maxf(COUNTRY_BROWSER_SAFE_MIN_W, vp_size.x - edge * 2.0))
	browser_height = minf(browser_height, maxf(COUNTRY_BROWSER_SAFE_MIN_H, vp_size.y - edge * 2.0))
	_apply_country_browser_compact_mode(vp_size)

	if viewport_fit:
		country_browser_panel.anchor_left = 0.0
		country_browser_panel.anchor_top = 0.0
		country_browser_panel.anchor_right = 1.0
		country_browser_panel.anchor_bottom = 1.0
		country_browser_panel.custom_minimum_size = Vector2(0, 0)
		country_browser_panel.offset_left = edge
		country_browser_panel.offset_top = edge
		country_browser_panel.offset_right = -edge
		country_browser_panel.offset_bottom = -edge
		browser_width = maxf(COUNTRY_BROWSER_SAFE_MIN_W, vp_size.x - edge * 2.0)
		browser_height = maxf(COUNTRY_BROWSER_SAFE_MIN_H, vp_size.y - edge * 2.0)
	else:
		country_browser_panel.anchor_left = 0.5
		country_browser_panel.anchor_top = 0.5
		country_browser_panel.anchor_right = 0.5
		country_browser_panel.anchor_bottom = 0.5
		country_browser_panel.custom_minimum_size = Vector2(browser_width, browser_height)
		country_browser_panel.offset_left = -browser_width * 0.5
		country_browser_panel.offset_top = -browser_height * 0.5
		country_browser_panel.offset_right = browser_width * 0.5
		country_browser_panel.offset_bottom = browser_height * 0.5

	var split = _get_country_browser_content_split()
	if split:
		split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var list_panel = split.get_node_or_null("ListPanel") as PanelContainer
		if list_panel:
			list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			list_panel.custom_minimum_size.x = COUNTRY_BROWSER_LIST_MIN_W
		var detail_panel = split.get_node_or_null("DetailPanel") as PanelContainer
		if detail_panel:
			detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			detail_panel.custom_minimum_size.x = COUNTRY_BROWSER_DETAIL_MIN_W
		var available_w = maxf(0.0, browser_width - float(split.get_theme_constant("separation")))
		var list_min = 170.0 if tiny_layout else (220.0 if compact_height else COUNTRY_BROWSER_LIST_MIN_W)
		var detail_min = 220.0 if tiny_layout else (280.0 if compact_height else COUNTRY_BROWSER_DETAIL_MIN_W)
		if available_w < (list_min + detail_min):
			var half = maxf(120.0, available_w * 0.5)
			list_min = minf(list_min, half)
			detail_min = minf(detail_min, available_w - list_min)
		var ratio = 0.36 if tiny_layout else (0.41 if compact_height else 0.40)
		var target_left_w = clampf(available_w * ratio, list_min, maxf(list_min, available_w - detail_min))
		# SplitContainer offset is relative to center, not absolute left width.
		split.split_offset = int(round(target_left_w - (available_w * 0.5)))

	if detail_name:
		detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_name.custom_minimum_size = Vector2(0, 32 if tiny_layout else (44 if compact_height else 56))
	if detail_info:
		detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_info.fit_content = false
		detail_info.scroll_active = true

func _restore_country_browser_root_layout() -> void:
	if country_browser_panel == null:
		return
	var margin = country_browser_panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	var root = margin.get_node_or_null("RootVBox") as VBoxContainer
	if root == null:
		var wrapped = margin.get_node_or_null("BrowserRootScroll") as ScrollContainer
		if wrapped:
			root = wrapped.get_node_or_null("RootVBox") as VBoxContainer
			if root:
				wrapped.remove_child(root)
				margin.add_child(root)
				margin.move_child(root, 0)
			wrapped.queue_free()
			_browser_root_scroll = null
	if root:
		root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _get_country_browser_root_vbox() -> VBoxContainer:
	if country_browser_panel == null:
		return null
	var root = country_browser_panel.get_node_or_null("MarginContainer/RootVBox") as VBoxContainer
	if root:
		return root
	return country_browser_panel.get_node_or_null("MarginContainer/BrowserRootScroll/RootVBox") as VBoxContainer

func _get_country_browser_content_split() -> HSplitContainer:
	var root = _get_country_browser_root_vbox()
	if root == null:
		return null
	return root.get_node_or_null("Content") as HSplitContainer

func _apply_country_browser_compact_mode(vp_size: Vector2) -> void:
	var tiny = vp_size.y < COUNTRY_BROWSER_TINY_H or vp_size.x < COUNTRY_BROWSER_TINY_W
	var compact = tiny or vp_size.y < COUNTRY_BROWSER_COMPACT_H or vp_size.x < COUNTRY_BROWSER_COMPACT_W
	_browser_compact_mode = compact
	_browser_tiny_mode = tiny
	if country_browser_margin:
		var edge = 8 if tiny else (12 if compact else 18)
		country_browser_margin.add_theme_constant_override("margin_left", edge)
		country_browser_margin.add_theme_constant_override("margin_top", edge)
		country_browser_margin.add_theme_constant_override("margin_right", edge)
		country_browser_margin.add_theme_constant_override("margin_bottom", edge)
	if country_browser_root_vbox:
		country_browser_root_vbox.add_theme_constant_override("separation", 6 if tiny else (8 if compact else 10))
	if _browser_current_settings_panel:
		_browser_current_settings_panel.visible = true
	if _browser_settings_country_separator:
		_browser_settings_country_separator.visible = true
	if browser_subtitle:
		browser_subtitle.visible = not compact
	if browser_flow_hint:
		browser_flow_hint.visible = not compact
	if list_hint:
		list_hint.visible = not compact
	if selected_players_panel:
		selected_players_panel.visible = true
	if selected_players_margin:
		var selected_margin = 4 if tiny else (6 if compact else 8)
		selected_players_margin.add_theme_constant_override("margin_top", selected_margin)
		selected_players_margin.add_theme_constant_override("margin_bottom", selected_margin)
		selected_players_margin.add_theme_constant_override("margin_left", 8 if compact else 10)
		selected_players_margin.add_theme_constant_override("margin_right", 8 if compact else 10)
	if browser_title:
		browser_title.add_theme_font_size_override("font_size", 20 if tiny else (24 if compact else 30))
	if detail_flag:
		detail_flag.custom_minimum_size = Vector2(130, 56) if tiny else (Vector2(160, 72) if compact else Vector2(220, 100))
	if detail_info:
		detail_info.custom_minimum_size = Vector2(0, 16) if tiny else (Vector2(0, 30) if compact else Vector2(0, 70))
		detail_info.fit_content = false
		detail_info.scroll_active = true
		detail_info.visible = not compact
	if selected_players_title:
		selected_players_title.add_theme_font_size_override("font_size", 13 if tiny else (14 if compact else 16))
	if _browser_potato_mode_check:
		_browser_potato_mode_check.add_theme_font_size_override("font_size", 12 if tiny else (13 if compact else 14))
	if _browser_ai_debug_mode_check:
		_browser_ai_debug_mode_check.add_theme_font_size_override("font_size", 12 if tiny else (13 if compact else 14))
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.add_theme_font_size_override("font_size", 12 if tiny else (13 if compact else 14))
	if country_list_scroll:
		country_list_scroll.custom_minimum_size.y = 84 if tiny else (120 if compact else 260)
	if browser_buttons_row:
		browser_buttons_row.add_theme_constant_override("separation", 6 if tiny else (8 if compact else 10))
		browser_buttons_row.vertical = tiny
	if btn_confirm_country:
		btn_confirm_country.custom_minimum_size.y = COUNTRY_BROWSER_BUTTON_H_TINY if tiny else (COUNTRY_BROWSER_BUTTON_H_COMPACT if compact else COUNTRY_BROWSER_BUTTON_H_DEFAULT)
		btn_confirm_country.add_theme_font_size_override("font_size", 14 if tiny else (16 if compact else 18))
		btn_confirm_country.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if btn_close_browser:
		btn_close_browser.custom_minimum_size.y = COUNTRY_BROWSER_BUTTON_H_TINY if tiny else (COUNTRY_BROWSER_BUTTON_H_COMPACT if compact else COUNTRY_BROWSER_BUTTON_H_DEFAULT)
		btn_close_browser.add_theme_font_size_override("font_size", 14 if tiny else (16 if compact else 18))
		btn_close_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_h = COUNTRY_BROWSER_ROW_H_TINY if tiny else (COUNTRY_BROWSER_ROW_H_COMPACT if compact else COUNTRY_BROWSER_ROW_H_DEFAULT)
	for row_key in country_rows.keys():
		var row_btn = country_rows[row_key] as Button
		if row_btn:
			row_btn.custom_minimum_size.y = row_h
			row_btn.autowrap_mode = TextServer.AUTOWRAP_OFF if tiny else TextServer.AUTOWRAP_WORD_SMART
	_obnov_texty_radku_statu()

# Applies prepared settings/effects to runtime systems.
func _apply_main_menu_window_size() -> void:
	if _center_panel_cache == null:
		_center_panel_cache = get_node_or_null("CenterPanel") as PanelContainer
	if _center_panel_cache == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size = vp.get_visible_rect().size
	var panel_width = clampf(vp_size.x * 0.74, 360.0, 820.0)
	var panel_height = clampf(vp_size.y * 0.78, 360.0, 620.0)
	_center_panel_cache.custom_minimum_size = Vector2(panel_width, panel_height)
	_center_panel_cache.offset_left = -panel_width * 0.5
	_center_panel_cache.offset_top = -panel_height * 0.5
	_center_panel_cache.offset_right = panel_width * 0.5
	_center_panel_cache.offset_bottom = panel_height * 0.5
	if selected_country_label:
		selected_country_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		selected_country_label.max_lines_visible = 2
		selected_country_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# Callback for UI/game events.
func _on_viewport_size_changed() -> void:
	_apply_main_menu_window_size()
	_apply_country_browser_window_size()
	_styluj_mainmenu_popup_dialogy()

# Handles this gameplay/UI path.
func _default_ai_aggression_from_ideology(ideology_raw: String) -> float:
	var ideol = ideology_raw.strip_edges().to_lower()
	match ideol:
		"democracy", "democratic", "demokracie":
			return 0.34
		"autocracy", "autocratic", "autokracie", "dictatorship":
			return 0.56
		"communism", "communist", "komunismus", "socialism":
			return 0.46
		"monarchy", "monarchie":
			return 0.42
		"fascism", "fascist", "fascismus", "nazism", "nacismus":
			return 0.72
		_:
			return 0.50

# Reads values from active state.
func _get_ai_aggression_for_tag(tag: String) -> float:
	if tag != "" and country_stats.has(tag):
		var ideol = str((country_stats[tag] as Dictionary).get("ideology", ""))
		var ideology_default = _default_ai_aggression_from_ideology(ideol)
		# Keep slight ideology flavor while using one global setting in UI.
		return clamp((ideology_default * 0.20) + (_global_ai_aggression * 0.80), 0.0, 1.0)
	return clamp(_global_ai_aggression, 0.0, 1.0)

# Handles this gameplay/UI path.
func _ensure_ai_aggression_control() -> void:
	if _browser_current_settings_panel != null:
		return
	if country_browser_panel == null:
		return
	var root_vbox = _get_country_browser_root_vbox()
	if root_vbox == null:
		return

	_browser_current_settings_panel = PanelContainer.new()
	_browser_current_settings_panel.name = "CurrentGameSettingsPanel"
	_browser_current_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 12)
	panel_margin.add_theme_constant_override("margin_right", 12)
	panel_margin.add_theme_constant_override("margin_top", 10)
	panel_margin.add_theme_constant_override("margin_bottom", 10)
	_browser_current_settings_panel.add_child(panel_margin)

	_browser_current_settings_vbox = VBoxContainer.new()
	_browser_current_settings_vbox.name = "CurrentGameSettingsVBox"
	_browser_current_settings_vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(_browser_current_settings_vbox)

	var title := Label.new()
	title.name = "CurrentGameSettingsTitle"
	title.text = "Current Game Settings"
	_browser_current_settings_vbox.add_child(title)

	_ai_aggression_row = HBoxContainer.new()
	_ai_aggression_row.name = "AIAggressionRow"
	_ai_aggression_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_current_settings_vbox.add_child(_ai_aggression_row)

	_ai_aggression_label = Label.new()
	_ai_aggression_label.name = "AIAggressionLabel"
	_ai_aggression_label.text = "AI Aggression"
	_ai_aggression_label.custom_minimum_size = Vector2(120, 0)
	_ai_aggression_row.add_child(_ai_aggression_label)

	_ai_aggression_slider = HSlider.new()
	_ai_aggression_slider.name = "AIAggressionSlider"
	_ai_aggression_slider.min_value = 0.0
	_ai_aggression_slider.max_value = 100.0
	_ai_aggression_slider.step = 1.0
	_ai_aggression_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_aggression_slider.value_changed.connect(_on_ai_aggression_changed)
	_ai_aggression_row.add_child(_ai_aggression_slider)

	_ai_aggression_value = Label.new()
	_ai_aggression_value.name = "AIAggressionValue"
	_ai_aggression_value.text = "50%"
	_ai_aggression_value.custom_minimum_size = Vector2(54, 0)
	_ai_aggression_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai_aggression_row.add_child(_ai_aggression_value)

	_browser_potato_mode_check = CheckBox.new()
	_browser_potato_mode_check.name = "BrowserPotatoModeCheck"
	_browser_potato_mode_check.text = "Potato mode"
	_browser_potato_mode_check.button_pressed = bool(nastaveni_data.get("other", {}).get("potato_mode", false))
	_browser_potato_mode_check.toggled.connect(_on_browser_potato_mode_toggled)
	_browser_current_settings_vbox.add_child(_browser_potato_mode_check)

	_browser_ai_debug_mode_check = CheckBox.new()
	_browser_ai_debug_mode_check.name = "BrowserAIDebugModeCheck"
	_browser_ai_debug_mode_check.text = "Debug mode"
	_browser_ai_debug_mode_check.button_pressed = bool(nastaveni_data.get("other", {}).get("ai_debug_mode", false))
	_browser_ai_debug_mode_check.toggled.connect(_on_browser_ai_debug_mode_toggled)
	_browser_current_settings_vbox.add_child(_browser_ai_debug_mode_check)

	_browser_spectate_mode_check = CheckBox.new()
	_browser_spectate_mode_check.name = "BrowserSpectateModeCheck"
	_browser_spectate_mode_check.text = "Spectate mode (AI only)"
	_browser_spectate_mode_check.button_pressed = false
	_browser_spectate_mode_check.disabled = true
	_browser_spectate_mode_check.visible = false
	_browser_spectate_mode_check.toggled.connect(_on_browser_spectate_mode_toggled)
	_browser_current_settings_vbox.add_child(_browser_spectate_mode_check)

	var insert_index := root_vbox.get_child_count()
	if selected_players_title and selected_players_title.get_parent() and selected_players_title.get_parent().get_parent() and selected_players_title.get_parent().get_parent().get_parent():
		var selected_players_panel = selected_players_title.get_parent().get_parent().get_parent()
		insert_index = selected_players_panel.get_index()

	root_vbox.add_child(_browser_current_settings_panel)
	root_vbox.move_child(_browser_current_settings_panel, insert_index)

	if _browser_settings_country_separator == null:
		_browser_settings_country_separator = HSeparator.new()
		_browser_settings_country_separator.name = "SettingsCountrySeparator"
		_browser_settings_country_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(_browser_settings_country_separator)
	root_vbox.move_child(_browser_settings_country_separator, insert_index + 1)

	# Initialize the global aggression slider from current stored value.
	_set_ai_aggression_ui_for_tag("")  # tag ignored Ă˘â‚¬â€ť always shows global value

# Handles this gameplay/UI path.
func _ensure_selected_players_flag_list() -> void:
	if _selected_players_flag_list != null:
		return
	if selected_players_list == null or selected_players_list.get_parent() == null:
		return

	selected_players_list.visible = false
	var parent_vbox = selected_players_list.get_parent() as VBoxContainer
	if parent_vbox == null:
		return

	_selected_players_scroll = ScrollContainer.new()
	_selected_players_scroll.name = "SelectedPlayersScroll"
	_selected_players_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_players_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_players_scroll.custom_minimum_size = Vector2(0, 0)
	_selected_players_scroll.clip_contents = true
	parent_vbox.add_child(_selected_players_scroll)
	parent_vbox.move_child(_selected_players_scroll, selected_players_list.get_index() + 1)

	_selected_players_flag_list = HFlowContainer.new()
	_selected_players_flag_list.name = "SelectedPlayersFlagList"
	_selected_players_flag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_players_flag_list.alignment = FlowContainer.ALIGNMENT_BEGIN
	_selected_players_flag_list.add_theme_constant_override("h_separation", 8)
	_selected_players_flag_list.add_theme_constant_override("v_separation", 6)
	_selected_players_scroll.add_child(_selected_players_flag_list)

# Wipes short-lived state.
func _clear_selected_players_flag_rows() -> void:
	if _selected_players_flag_list == null:
		return
	for child in _selected_players_flag_list.get_children():
		child.queue_free()

# Feature logic entry point.
func _add_selected_player_row(row_text: String, tag: String, is_active: bool, player_index: int = -1) -> void:
	if _selected_players_flag_list == null:
		return

	var row = PanelContainer.new()
	var row_w = _PLAYER_CHIP_MIN_W + (_PLAYER_ACTIVE_EXTRA_W if is_active else 0)
	var row_h = _PLAYER_ROW_H + (_PLAYER_ACTIVE_EXTRA_H if is_active else 0)
	row.custom_minimum_size = Vector2(row_w, row_h)
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.26, 0.40, 0.94) if is_active else Color(0.08, 0.12, 0.20, 0.82)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	if is_active:
		row_style.border_width_left = 2
		row_style.border_width_top = 2
		row_style.border_width_right = 2
		row_style.border_width_bottom = 2
	row_style.border_color = Color(0.82, 0.95, 1.0, 0.98) if is_active else Color(0.34, 0.48, 0.66, 0.72)
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_right = 6
	row_style.corner_radius_bottom_left = 6
	row.add_theme_stylebox_override("panel", row_style)

	var row_inner = HBoxContainer.new()
	row_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_inner.add_theme_constant_override("separation", 8)

	var row_margin = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 8)
	row_margin.add_theme_constant_override("margin_right", 8)
	row_margin.add_theme_constant_override("margin_top", 4)
	row_margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(row_margin)
	row_margin.add_child(row_inner)

	var flag = TextureRect.new()
	flag.custom_minimum_size = Vector2(28, 18)
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tag.strip_edges() != "":
		var flag_path = "res://map_data/Flags/%s.svg" % tag
		flag.texture = _load_normalized_flag_texture(flag_path, 56, 36)
	row_inner.add_child(flag)

	var text_lbl = Label.new()
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_lbl.clip_text = true
	text_lbl.text = row_text
	if is_active:
		text_lbl.add_theme_font_size_override("font_size", 15)
		text_lbl.modulate = Color(0.95, 1.0, 0.85, 1.0)
	row_inner.add_child(text_lbl)

	if new_game_browser_flow and player_index >= 0 and tag.strip_edges() != "":
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(_on_selected_player_chip_gui_input.bind(player_index, tag))

	_selected_players_flag_list.add_child(row)

# Reacts to incoming events.
func _on_selected_player_chip_gui_input(event: InputEvent, player_index: int, tag: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not new_game_browser_flow:
		return
	if player_index < 0 or player_index >= local_player_tags.size():
		return
	call_deferred("_select_setup_player_from_chip", player_index, tag)

# Applies incoming data to runtime state.
func _select_setup_player_from_chip(player_index: int, tag: String) -> void:
	if not new_game_browser_flow:
		return
	if player_index < 0 or player_index >= local_player_tags.size():
		return

	setup_active_player_index = player_index
	selected_country_tag_in_browser = tag
	_nastav_detail_statu(tag, true)
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()

# Sync update for linked values.
func _set_ai_aggression_ui_for_tag(_tag: String) -> void:
	if _ai_aggression_slider == null or _ai_aggression_value == null:
		return
	var percent = int(round(_global_ai_aggression * 100.0))
	_ai_aggression_slider.set_block_signals(true)
	_ai_aggression_slider.value = percent
	_ai_aggression_slider.set_block_signals(false)
	_ai_aggression_value.text = "%d%%" % percent

# Triggered by a UI/game signal.
func _on_ai_aggression_changed(value: float) -> void:
	var percent = int(round(value))
	if _ai_aggression_value:
		_ai_aggression_value.text = "%d%%" % percent
	_global_ai_aggression = clamp(value / 100.0, 0.0, 1.0)

# Callback for UI/game events.
func _on_browser_potato_mode_toggled(enabled: bool) -> void:
	nastaveni_data["other"]["potato_mode"] = enabled
	_aplikuj_potato_mode_globalne(enabled)
	if potato_mode_check:
		potato_mode_check.set_block_signals(true)
		potato_mode_check.button_pressed = enabled
		potato_mode_check.set_block_signals(false)

# Event handler for user or game actions.
func _on_browser_ai_debug_mode_toggled(enabled: bool) -> void:
	nastaveni_data["other"]["ai_debug_mode"] = enabled
	_aplikuj_ai_debug_mode_globalne(enabled)
	if ai_debug_mode_check:
		ai_debug_mode_check.set_block_signals(true)
		ai_debug_mode_check.button_pressed = enabled
		ai_debug_mode_check.set_block_signals(false)

func _on_browser_spectate_mode_toggled(enabled: bool) -> void:
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.set_block_signals(true)
		_browser_spectate_mode_check.button_pressed = false
		_browser_spectate_mode_check.set_block_signals(false)
	_aktualizuj_spectate_stav_v_new_game(false)

func _aktualizuj_spectate_stav_v_new_game(enabled: bool) -> void:
	if enabled:
		local_player_tags.clear()
		setup_active_player_index = 0
	_aktualizuj_stav_blokace_vyberu_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	_obnov_texty_radku_statu()

func _je_spectate_new_game_aktivni() -> bool:
	return false

func _aktualizuj_stav_blokace_vyberu_statu() -> void:
	var lock_selection = _je_spectate_new_game_aktivni()
	if country_list_scroll:
		country_list_scroll.modulate = Color(0.58, 0.58, 0.62, 0.9) if lock_selection else Color(1, 1, 1, 1)
	if detail_flag:
		detail_flag.modulate = Color(0.6, 0.6, 0.62, 0.92) if lock_selection else Color(1, 1, 1, 1)
	if detail_name:
		detail_name.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_tag:
		detail_tag.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_ideology:
		detail_ideology.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_population:
		detail_population.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_gdp:
		detail_gdp.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_recruits:
		detail_recruits.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_soldiers:
		detail_soldiers.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_provinces:
		detail_provinces.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if detail_info:
		detail_info.modulate = Color(0.72, 0.72, 0.78, 1.0) if lock_selection else Color(1, 1, 1, 1)
	if btn_confirm_country:
		btn_confirm_country.disabled = lock_selection

# Applies prepared settings/effects to runtime systems.
func _apply_ai_aggression_overrides(_local_tags: Array) -> void:
	if not GameManager or not GameManager.has_method("nastav_globalni_ai_agresi"):
		return
	GameManager.nastav_globalni_ai_agresi(_global_ai_aggression)


# Updates state and keeps things in sync.
func _nastav_tooltipy_ui() -> void:
	btn_new_game.tooltip_text = "Start a new game and open country selection."
	btn_continue.tooltip_text = "Load the latest saved game."
	btn_settings.tooltip_text = "Open game settings."
	btn_credits.tooltip_text = "Show authors and project info."
	btn_exit.tooltip_text = "Quit the game."
	btn_confirm_country.tooltip_text = "Confirm the current country selection."
	btn_close_browser.tooltip_text = "Close country selection, or start the game in multiplayer flow."
	btn_close_corner.tooltip_text = "Quickly close the country selection panel."
	selected_country_label.tooltip_text = "Currently selected country or local player list."
	menu_hint_label.tooltip_text = "Short hint for the next step."
	browser_subtitle.tooltip_text = "Explains country selection behavior."
	browser_flow_hint.tooltip_text = "Shows what to do in the current step."
	selected_players_title.tooltip_text = "Panel with local player list."
	selected_players_list.tooltip_text = "Currently selected countries for players."
	list_hint.tooltip_text = "Hint for controlling the country list."
	detail_flag.tooltip_text = "Flag of the selected country."
	detail_name.tooltip_text = "Name of the selected country."
	detail_info.tooltip_text = "Short summary of country strengths and risks."
	if _ai_aggression_slider:
		_ai_aggression_slider.tooltip_text = "Sets global AI aggression for the whole new game."
	if _ai_aggression_label:
		_ai_aggression_label.tooltip_text = "Global AI aggression for all AI countries."
	if _ai_aggression_value:
		_ai_aggression_value.tooltip_text = "Current aggression override value."
	if _browser_potato_mode_check:
		_browser_potato_mode_check.tooltip_text = "Quick toggle for potato mode in current game setup."
	if _browser_ai_debug_mode_check:
		_browser_ai_debug_mode_check.tooltip_text = "Shows debug panel and detailed diagnostics in output."
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.tooltip_text = "Temporarily disabled."
	if _browser_settings_country_separator:
		_browser_settings_country_separator.tooltip_text = "Visual separator between setup settings and country selection."
	if potato_mode_check:
		potato_mode_check.tooltip_text = "Turns on low-detail rendering and power-saving updates for weak PCs."
	if ai_debug_mode_check:
		ai_debug_mode_check.tooltip_text = "Shows debug panel and detailed diagnostics in output."
	if skip_battle_reports_check:
		skip_battle_reports_check.tooltip_text = "When enabled, battle/frontline popups are skipped and turn processing continues immediately."
	TooltipUtilsScript.apply_default_tooltips(self)

# Feature logic entry point.
func _ensure_potato_mode_checkbox() -> void:
	if potato_mode_check != null or settings_content == null:
		return

	potato_mode_check = CheckBox.new()
	potato_mode_check.name = "PotatoModeCheck"
	potato_mode_check.text = "Potato mode (low-end PC)"

	var insert_index := settings_content.get_child_count()
	if master_volume_label and master_volume_label.get_parent() == settings_content:
		insert_index = master_volume_label.get_index()

	settings_content.add_child(potato_mode_check)
	settings_content.move_child(potato_mode_check, insert_index)

# Runs the local feature logic.
func _ensure_ai_debug_mode_checkbox() -> void:
	if ai_debug_mode_check != null or settings_content == null:
		return

	ai_debug_mode_check = CheckBox.new()
	ai_debug_mode_check.name = "AIDebugModeCheck"
	ai_debug_mode_check.text = "Debug mode"

	var insert_index := settings_content.get_child_count()
	if master_volume_label and master_volume_label.get_parent() == settings_content:
		insert_index = master_volume_label.get_index()

	settings_content.add_child(ai_debug_mode_check)
	settings_content.move_child(ai_debug_mode_check, insert_index)

func _ensure_skip_battle_reports_checkbox() -> void:
	if skip_battle_reports_check != null or settings_content == null:
		return

	skip_battle_reports_check = CheckBox.new()
	skip_battle_reports_check.name = "SkipBattleReportsCheck"
	skip_battle_reports_check.text = "Skip battle reports on end turn"

	var insert_index := settings_content.get_child_count()
	if master_volume_label and master_volume_label.get_parent() == settings_content:
		insert_index = master_volume_label.get_index()

	settings_content.add_child(skip_battle_reports_check)
	settings_content.move_child(skip_battle_reports_check, insert_index)

# Writes new values and refreshes related state.
func _nastav_texty_dialogu():
	settings_dialog.title = SETTINGS_DIALOG_TITLE
	settings_dialog.ok_button_text = "Close"
	credits_dialog.title = CREDITS_DIALOG_TITLE
	credits_dialog.dialog_text = CREDITS_DIALOG_TEXT
	credits_dialog.ok_button_text = "Close"
	exit_dialog.title = EXIT_DIALOG_TITLE
	exit_dialog.dialog_text = EXIT_DIALOG_TEXT
	exit_dialog.ok_button_text = "Yes"
	exit_dialog.cancel_button_text = "No"
	var _exit_lbl = exit_dialog.get_label()
	if _exit_lbl:
		_exit_lbl.add_theme_font_size_override("font_size", 20)
		_exit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_exit_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_exit_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

# Returns current runtime data.
func _get_settings_button_apply() -> Button:
	if _btn_apply_cache and is_instance_valid(_btn_apply_cache):
		return _btn_apply_cache
	
	# Try @onready reference first
	if btn_settings_apply and is_instance_valid(btn_settings_apply):
		_btn_apply_cache = btn_settings_apply
		return _btn_apply_cache
	
	# Fallback: find it using find_child
	var apply_btn = settings_dialog.find_child("ApplyButton", true, false) as Button
	if apply_btn:
		_btn_apply_cache = apply_btn
		return apply_btn
	
	return null

# Returns current runtime data.
func _get_settings_button_reset() -> Button:
	if _btn_reset_cache and is_instance_valid(_btn_reset_cache):
		return _btn_reset_cache
	
	# Try @onready reference first
	if btn_settings_reset and is_instance_valid(btn_settings_reset):
		_btn_reset_cache = btn_settings_reset
		return _btn_reset_cache
	
	# Fallback: find it using find_child
	var reset_btn = settings_dialog.find_child("ResetButton", true, false) as Button
	if reset_btn:
		_btn_reset_cache = reset_btn
		return reset_btn
	
	return null

# Handles this gameplay/UI path.
func _ensure_settings_buttons_connected() -> void:
	var apply_btn = _get_settings_button_apply()
	var reset_btn = _get_settings_button_reset()
	
	print("Ensure buttons connected - apply: ", apply_btn != null, " reset: ", reset_btn != null)
	
	if apply_btn and not apply_btn.pressed.is_connected(_on_apply_settings_pressed):
		apply_btn.pressed.connect(_on_apply_settings_pressed)
		print("Connected apply button")
	
	if reset_btn and not reset_btn.pressed.is_connected(_on_reset_settings_pressed):
		reset_btn.pressed.connect(_on_reset_settings_pressed)
		print("Connected reset button")
	settings_dialog.title = SETTINGS_DIALOG_TITLE
	settings_dialog.ok_button_text = "Close"
	credits_dialog.title = CREDITS_DIALOG_TITLE
	credits_dialog.dialog_text = CREDITS_DIALOG_TEXT
	credits_dialog.ok_button_text = "Close"
	exit_dialog.title = EXIT_DIALOG_TITLE
	exit_dialog.dialog_text = EXIT_DIALOG_TEXT
	exit_dialog.ok_button_text = "Yes"
	exit_dialog.cancel_button_text = "No"
	var _exit_lbl = exit_dialog.get_label()
	if _exit_lbl:
		_exit_lbl.add_theme_font_size_override("font_size", 20)
		_exit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_exit_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_exit_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

# Applies prepared settings/effects to runtime systems.
func _aplikuj_spolecny_popup_styl(dialog: Window, target_size: Vector2i) -> void:
	if dialog == null:
		return

	dialog.wrap_controls = false
	dialog.unresizable = true
	dialog.min_size = target_size
	dialog.size = target_size

	var base_panel = settings_dialog.get_theme_stylebox("panel")
	if base_panel != null:
		dialog.add_theme_stylebox_override("panel", base_panel.duplicate())

# Core flow for this feature.
func _styluj_mainmenu_popup_dialogy() -> void:
	_apply_settings_dialog_window_size()
	_aplikuj_spolecny_popup_styl(credits_dialog, _calc_dialog_target_size(Vector2i(680, 360), Vector2i(420, 260), 0.72))
	_aplikuj_spolecny_popup_styl(exit_dialog, _calc_dialog_target_size(Vector2i(560, 240), Vector2i(380, 210), 0.62))
	if _load_dialog != null:
		_aplikuj_spolecny_popup_styl(_load_dialog, _calc_dialog_target_size(Vector2i(720, 560), Vector2i(500, 360), 0.78))
	if settings_dialog and settings_dialog.visible:
		settings_dialog.popup_centered(settings_dialog.size)
	if credits_dialog and credits_dialog.visible:
		credits_dialog.popup_centered(credits_dialog.size)
	if exit_dialog and exit_dialog.visible:
		exit_dialog.popup_centered(exit_dialog.size)
	if _load_dialog and _load_dialog.visible:
		_load_dialog.popup_centered(_load_dialog.size)

func _calc_dialog_target_size(base_size: Vector2i, min_size: Vector2i, viewport_ratio: float) -> Vector2i:
	var vp := get_viewport()
	if vp == null:
		return base_size
	var vp_size = vp.get_visible_rect().size
	var w = int(round(clampf(vp_size.x * viewport_ratio, float(min_size.x), float(base_size.x))))
	var h = int(round(clampf(vp_size.y * viewport_ratio, float(min_size.y), float(base_size.y))))
	return Vector2i(w, h)

func _ensure_settings_panel_scroll(panel: PanelContainer, pad_node_name: String) -> ScrollContainer:
	if panel == null:
		return null
	var existing = panel.get_node_or_null("ResponsiveScroll") as ScrollContainer
	if existing:
		return existing
	var pad = panel.get_node_or_null(pad_node_name) as MarginContainer
	if pad == null:
		return null
	panel.remove_child(pad)
	var scroll := ScrollContainer.new()
	scroll.name = "ResponsiveScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	scroll.add_child(pad)
	return scroll

func _apply_settings_dialog_window_size() -> void:
	if settings_dialog == null:
		return
	var target = _calc_dialog_target_size(SETTINGS_DIALOG_BASE_SIZE, SETTINGS_DIALOG_MIN_SIZE, 0.90)
	_aplikuj_spolecny_popup_styl(settings_dialog, target)
	settings_dialog.wrap_controls = true
	settings_dialog.unresizable = false
	settings_dialog.min_size = SETTINGS_DIALOG_MIN_SIZE

	_settings_controls_scroll = _ensure_settings_panel_scroll(controls_panel, "ControlsPad")
	_settings_options_scroll = _ensure_settings_panel_scroll(settings_panel, "SettingsPad")

	var slider_w = clampf(float(target.x) * 0.50, 260.0, 500.0)
	if camera_speed_slider:
		camera_speed_slider.custom_minimum_size.x = slider_w
	if zoom_speed_slider:
		zoom_speed_slider.custom_minimum_size.x = slider_w
	if master_volume_slider:
		master_volume_slider.custom_minimum_size.x = slider_w

# Creates required nodes and connects signals.
func _vytvor_vychozi_nastaveni() -> Dictionary:
	return {
		"controls": {
			"camera_speed": 1000.0,
			"zoom_speed": 0.10,
			"invert_zoom": false
		},
		"keybinds": ControlsConfig.get_default_bindings(),
		"language": {
			"code": SETTINGS_DEFAULT_LANGUAGE
		},
		"other": {
			"fullscreen": false,
			"vsync": true,
			"potato_mode": false,
			"ai_debug_mode": false,
			"skip_battle_reports": false,
			"master_volume": 0.85
		}
	}

# Pulls data and verifies parse output.
func _nacti_nastaveni() -> void:
	nastaveni_data = _vytvor_vychozi_nastaveni()
	# Keybinds are currently fixed to defaults (custom rebinding is temporarily disabled).
	var default_keybinds = ControlsConfig.get_default_bindings()
	nastaveni_data["keybinds"] = default_keybinds.duplicate(true)
	_keybind_state = default_keybinds.duplicate(true)
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		ControlsConfig.apply_bindings(_keybind_state)
		return

	nastaveni_data["controls"]["camera_speed"] = float(cfg.get_value("controls", "camera_speed", nastaveni_data["controls"]["camera_speed"]))
	nastaveni_data["controls"]["zoom_speed"] = float(cfg.get_value("controls", "zoom_speed", nastaveni_data["controls"]["zoom_speed"]))
	nastaveni_data["controls"]["invert_zoom"] = bool(cfg.get_value("controls", "invert_zoom", nastaveni_data["controls"]["invert_zoom"]))

	var loaded_language = str(cfg.get_value("language", "code", nastaveni_data["language"]["code"]))
	nastaveni_data["language"]["code"] = _normalizuj_jazyk(loaded_language)

	nastaveni_data["other"]["fullscreen"] = bool(cfg.get_value("other", "fullscreen", nastaveni_data["other"]["fullscreen"]))
	nastaveni_data["other"]["vsync"] = bool(cfg.get_value("other", "vsync", nastaveni_data["other"]["vsync"]))
	nastaveni_data["other"]["potato_mode"] = bool(cfg.get_value("other", "potato_mode", nastaveni_data["other"]["potato_mode"]))
	# Always start with AI debug disabled, regardless of previously saved value.
	nastaveni_data["other"]["ai_debug_mode"] = false
	nastaveni_data["other"]["skip_battle_reports"] = bool(cfg.get_value("other", "skip_battle_reports", nastaveni_data["other"]["skip_battle_reports"]))
	nastaveni_data["other"]["master_volume"] = float(cfg.get_value("other", "master_volume", nastaveni_data["other"]["master_volume"]))
	ControlsConfig.apply_bindings(_keybind_state)

# Persistence write helper.
func _uloz_nastaveni() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("controls", "camera_speed", float(nastaveni_data["controls"]["camera_speed"]))
	cfg.set_value("controls", "zoom_speed", float(nastaveni_data["controls"]["zoom_speed"]))
	cfg.set_value("controls", "invert_zoom", bool(nastaveni_data["controls"]["invert_zoom"]))

	cfg.set_value("language", "code", str(nastaveni_data["language"]["code"]))

	cfg.set_value("other", "fullscreen", bool(nastaveni_data["other"]["fullscreen"]))
	cfg.set_value("other", "vsync", bool(nastaveni_data["other"]["vsync"]))
	cfg.set_value("other", "potato_mode", bool(nastaveni_data["other"]["potato_mode"]))
	cfg.set_value("other", "ai_debug_mode", bool(nastaveni_data["other"]["ai_debug_mode"]))
	cfg.set_value("other", "skip_battle_reports", bool(nastaveni_data["other"]["skip_battle_reports"]))
	cfg.set_value("other", "master_volume", float(nastaveni_data["other"]["master_volume"]))

	var save_err = cfg.save(SETTINGS_FILE_PATH)
	if save_err != OK:
		push_warning("Failed to save settings. Error: %s" % str(save_err))

# Handles this gameplay/UI path.
func _normalizuj_jazyk(raw_code: String) -> String:
	var code = raw_code.strip_edges().to_lower()
	if code != "en":
		return SETTINGS_DEFAULT_LANGUAGE
	if not UI_TEXTS.has(code):
		return SETTINGS_DEFAULT_LANGUAGE
	return code

# Feature logic entry point.
func _aktualni_jazyk() -> String:
	var code = str(nastaveni_data.get("language", {}).get("code", SETTINGS_DEFAULT_LANGUAGE))
	return _normalizuj_jazyk(code)

# Feature logic entry point.
func _texty_ui() -> Dictionary:
	return UI_TEXTS[_aktualni_jazyk()]

# Populates UI/data structures from available runtime data.
func _napln_language_option() -> void:
	language_option.clear()
	language_option.add_item("English")
	language_option.set_item_metadata(0, "en")
	language_option.select(0)
	language_option.disabled = true

# Main runtime logic lives here.
func _jazyk_z_option() -> String:
	var idx = language_option.selected
	if idx < 0:
		return SETTINGS_DEFAULT_LANGUAGE
	var metadata = language_option.get_item_metadata(idx)
	if metadata == null:
		return SETTINGS_DEFAULT_LANGUAGE
	return _normalizuj_jazyk(str(metadata))

# Writes new values and refreshes related state.
func _nastav_settings_ui_z_dat() -> void:
	camera_speed_slider.value = float(nastaveni_data["controls"]["camera_speed"])
	zoom_speed_slider.value = float(nastaveni_data["controls"]["zoom_speed"])
	invert_zoom_check.button_pressed = bool(nastaveni_data["controls"]["invert_zoom"])
	_keybind_state = (nastaveni_data.get("keybinds", ControlsConfig.get_default_bindings()) as Dictionary).duplicate(true)
	_refresh_keybind_buttons()

	var jazyk = _aktualni_jazyk()
	for i in range(language_option.item_count):
		if str(language_option.get_item_metadata(i)) == jazyk:
			language_option.select(i)
			break

	fullscreen_check.button_pressed = bool(nastaveni_data["other"]["fullscreen"])
	vsync_check.button_pressed = bool(nastaveni_data["other"]["vsync"])
	if potato_mode_check:
		potato_mode_check.button_pressed = bool(nastaveni_data["other"].get("potato_mode", false))
	if ai_debug_mode_check:
		ai_debug_mode_check.button_pressed = bool(nastaveni_data["other"].get("ai_debug_mode", false))
	if skip_battle_reports_check:
		skip_battle_reports_check.button_pressed = bool(nastaveni_data["other"].get("skip_battle_reports", false))
	master_volume_slider.value = clamp(float(nastaveni_data["other"]["master_volume"]), 0.0, 1.0)

# Stores current data to disk.
func _uloz_settings_ui_do_dat() -> void:
	nastaveni_data["controls"]["camera_speed"] = clamp(camera_speed_slider.value, 400.0, 2600.0)
	nastaveni_data["controls"]["zoom_speed"] = clamp(zoom_speed_slider.value, 0.03, 0.35)
	nastaveni_data["controls"]["invert_zoom"] = invert_zoom_check.button_pressed
	nastaveni_data["keybinds"] = _keybind_state.duplicate(true)
	nastaveni_data["language"]["code"] = _jazyk_z_option()
	nastaveni_data["other"]["fullscreen"] = fullscreen_check.button_pressed
	nastaveni_data["other"]["vsync"] = vsync_check.button_pressed
	nastaveni_data["other"]["potato_mode"] = potato_mode_check.button_pressed if potato_mode_check else false
	nastaveni_data["other"]["ai_debug_mode"] = ai_debug_mode_check.button_pressed if ai_debug_mode_check else false
	nastaveni_data["other"]["skip_battle_reports"] = skip_battle_reports_check.button_pressed if skip_battle_reports_check else false
	nastaveni_data["other"]["master_volume"] = clamp(master_volume_slider.value, 0.0, 1.0)

# Recomputes values from current data.
func _aktualizuj_settings_hodnoty(_v: float = 0.0) -> void:
	camera_speed_value.text = "%d" % int(round(camera_speed_slider.value))
	zoom_speed_value.text = "%.2f" % zoom_speed_slider.value
	master_volume_value.text = "%d%%" % int(round(master_volume_slider.value * 100.0))

# Construct/setup block for required nodes.
func _ensure_keybind_controls() -> void:
	# Rebinding UI intentionally disabled for now.
	return

# Refreshes existing content to reflect current runtime values.
func _refresh_keybind_buttons() -> void:
	for action_any in _keybind_buttons.keys():
		var action = str(action_any)
		var btn = _keybind_buttons[action_any] as Button
		if btn == null:
			continue
		btn.text = "Press key..." if action == _keybind_capture_action else ControlsConfig.get_binding_text(action, _keybind_state)

# Event handler for user or game actions.
func _on_keybind_button_pressed(action: String) -> void:
	_keybind_capture_action = action
	_refresh_keybind_buttons()

# Callback for UI/game events.
func _capture_menu_keybind(event: InputEventKey) -> bool:
	if _keybind_capture_action == "":
		return false
	if not event.pressed or event.echo:
		return true
	if event.keycode == KEY_ESCAPE:
		_keybind_capture_action = ""
		_refresh_keybind_buttons()
		return true
	_keybind_state[_keybind_capture_action] = [int(event.keycode)]
	_keybind_capture_action = ""
	_refresh_keybind_buttons()
	_refresh_apply_button_state()
	return true

# Applies prepared settings/effects to runtime systems.
func _aplikuj_nastaveni_globalne() -> void:
	ControlsConfig.apply_bindings(nastaveni_data.get("keybinds", ControlsConfig.get_default_bindings()))
	var fullscreen = bool(nastaveni_data["other"]["fullscreen"])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync_mode = DisplayServer.VSYNC_ENABLED if bool(nastaveni_data["other"]["vsync"]) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	_aplikuj_potato_mode_globalne(bool(nastaveni_data["other"].get("potato_mode", false)))
	_aplikuj_ai_debug_mode_globalne(bool(nastaveni_data["other"].get("ai_debug_mode", false)))

	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus != -1:
		var linear_volume = clamp(float(nastaveni_data["other"]["master_volume"]), 0.0, 1.0)
		var db_volume = -80.0 if linear_volume <= 0.0001 else linear_to_db(linear_volume)
		AudioServer.set_bus_volume_db(master_bus, db_volume)

# Applies prepared settings/effects to runtime systems.
func _aplikuj_potato_mode_globalne(enabled: bool) -> void:
	Engine.max_fps = 45 if enabled else 0
	OS.low_processor_usage_mode = enabled
	OS.low_processor_usage_mode_sleep_usec = 12000 if enabled else 6900

# Applies prepared settings/effects to runtime systems.
func _aplikuj_ai_debug_mode_globalne(enabled: bool) -> void:
	if GameManager and GameManager.has_method("nastav_ai_debug_mode"):
		GameManager.nastav_ai_debug_mode(enabled)

# Refresh pass for current state.
func _aktualizuj_texty_dle_jazyka() -> void:
	var t = _texty_ui()
	title_label.text = str(t["title"])
	subtitle_label.text = str(t["subtitle"])
	btn_new_game.text = str(t["new_game"])
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.text = str(t["spectate_mode"])
	btn_settings.text = str(t["settings"])
	btn_credits.text = str(t["credits"])
	btn_exit.text = str(t["quit"])
	settings_dialog.title = str(t["settings_title"])
	settings_dialog.ok_button_text = str(t["close"])
	settings_header_title.text = str(t["settings_header_title"])
	settings_header_subtitle.text = str(t["settings_header_subtitle"])

	controls_btn.text = str(t["tab_controls"])
	settings_btn.text = str(t["tab_settings"])
	controls_info.text = str(t["controls_info"])
	camera_speed_label.text = str(t["camera_speed"])
	zoom_speed_label.text = str(t["zoom_speed"])
	invert_zoom_check.text = str(t["invert_zoom"])
	controls_scheme_title.text = str(t["controls_static_title"])
	controls_scheme_text.text = "Camera up: %s\nCamera down: %s\nCamera left: %s\nCamera right: %s\nEnd turn: %s\nDeveloper conquer: %s\n\nMap modes\n1 Political\n2 Population\n3 GDP\n4 Ideology\n5 Recruitable Population\n6 Relations\n7 Terrain\n8 Resources\n9 Alliances" % [
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_CAMERA_UP, _keybind_state),
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_CAMERA_DOWN, _keybind_state),
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_CAMERA_LEFT, _keybind_state),
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_CAMERA_RIGHT, _keybind_state),
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_END_TURN, _keybind_state),
		ControlsConfig.get_binding_text(ControlsConfig.ACTION_DEV_CONQUER, _keybind_state)
	]
	language_label.text = str(t["language_label"])
	language_hint.text = str(t["language_hint"])
	fullscreen_check.text = str(t["fullscreen"])
	vsync_check.text = str(t["vsync"])
	if potato_mode_check:
		potato_mode_check.text = str(t["potato_mode"])
	if ai_debug_mode_check:
		ai_debug_mode_check.text = str(t["ai_debug_mode"])
	if skip_battle_reports_check:
		skip_battle_reports_check.text = str(t["skip_battle_reports"])
	master_volume_label.text = str(t["master_volume"])
	btn_settings_reset.text = str(t["reset"])
	btn_settings_apply.text = str(t["apply"])
	_refresh_keybind_buttons()
	_aktualizuj_clean_helpery()

# Updates derived state and UI.
func _aktualizuj_settings_header_stav(dirty: bool) -> void:
	var t = _texty_ui()
	if dirty:
		settings_header_subtitle.text = str(t["settings_header_subtitle_dirty"])
		settings_header_subtitle.modulate = Color(1.0, 0.91, 0.70, 1.0)
	else:
		settings_header_subtitle.text = str(t["settings_header_subtitle_clean"])
		settings_header_subtitle.modulate = Color(0.72, 0.88, 1.0, 1.0)

# Main runtime logic lives here.
func _read_settings_from_ui() -> Dictionary:
	return {
		"camera_speed": int(round(camera_speed_slider.value)),
		"zoom_speed": snapped(zoom_speed_slider.value, 0.01),
		"invert_zoom": invert_zoom_check.button_pressed,
		"keybinds": _keybind_state.duplicate(true),
		"language": _jazyk_z_option(),
		"fullscreen": fullscreen_check.button_pressed,
		"vsync": vsync_check.button_pressed,
		"potato_mode": potato_mode_check.button_pressed if potato_mode_check else false,
		"ai_debug_mode": ai_debug_mode_check.button_pressed if ai_debug_mode_check else false,
		"skip_battle_reports": skip_battle_reports_check.button_pressed if skip_battle_reports_check else false,
		"master_volume": snapped(master_volume_slider.value, 0.01)
	}

# Runs the local feature logic.
func _settings_state_equals(a: Dictionary, b: Dictionary) -> bool:
	for key in ["camera_speed", "zoom_speed", "invert_zoom", "language", "fullscreen", "vsync", "potato_mode", "ai_debug_mode", "skip_battle_reports", "master_volume"]:
		if not a.has(key) or not b.has(key):
			return false
		if a[key] != b[key]:
			return false
	if not ControlsConfig.bindings_equal(a.get("keybinds", {}), b.get("keybinds", {})):
		return false
	return true

# Refreshes existing content to reflect current runtime values.
func _refresh_apply_button_state() -> void:
	var apply_btn = _get_settings_button_apply()
	var reset_btn = _get_settings_button_reset()
	
	if not apply_btn or not reset_btn:
		print("ERROR: Settings buttons not found!")
		return
	
	# Force visibility and size on button container
	var btn_container = apply_btn.get_parent()
	if btn_container:
		btn_container.visible = true
		if btn_container is HBoxContainer or btn_container is Control:
			btn_container.size_flags_vertical = Control.SIZE_SHRINK_END
	
	# Force visibility on all parent nodes up to dialog
	var current = apply_btn
	while current and current != settings_dialog:
		current.visible = true
		current = current.get_parent()
	
	current = reset_btn
	while current and current != settings_dialog:
		current.visible = true
		current = current.get_parent()
	
	var current_state = _read_settings_from_ui()
	var dirty = not _settings_state_equals(current_state, _settings_original_ui_state)
	apply_btn.disabled = not dirty
	apply_btn.modulate = Color(1, 1, 1, 1) if dirty else Color(0.78, 0.82, 0.9, 1)
	_aktualizuj_settings_header_stav(dirty)
	
	print("Settings buttons refreshed - apply visible: ", apply_btn.visible, " reset visible: ", reset_btn.visible)

# Applies incoming data to runtime state.
func _nastav_vychozi_vyber_statu():
	if country_stats.has(selected_country_tag):
		return

	if country_stats.is_empty():
		selected_country_tag = ""
		return

	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort()
	selected_country_tag = str(vsechny_tagy[0])

# Handles this gameplay/UI path.
func _raw_data_path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)

# Handles this gameplay/UI path.
func _resolve_provinces_data_path() -> String:
	for path in PROVINCES_DATA_PATHS:
		if _raw_data_path_exists(path):
			return path
	return str(PROVINCES_DATA_PATHS[PROVINCES_DATA_PATHS.size() - 1])

# Main runtime logic lives here.
func _build_column_index(header_line: String) -> Dictionary:
	var out: Dictionary = {}
	var cols = header_line.split(";")
	for i in range(cols.size()):
		out[str(cols[i]).strip_edges().to_lower()] = i
	return out

# Search helper over available data.
func _find_column_idx(col_index: Dictionary, names: Array, fallback_idx: int = -1) -> int:
	for raw_name in names:
		var key = str(raw_name).strip_edges().to_lower()
		if col_index.has(key):
			return int(col_index[key])
	return fallback_idx

# Runs the local feature logic.
func _read_int(parts: Array, idx: int, default_val: int = 0) -> int:
	if idx < 0 or idx >= parts.size():
		return default_val
	var raw = str(parts[idx]).strip_edges()
	if raw == "":
		return default_val
	return int(raw)

# Runs the local feature logic.
func _read_float(parts: Array, idx: int, default_val: float = 0.0) -> float:
	if idx < 0 or idx >= parts.size():
		return default_val
	var raw = str(parts[idx]).strip_edges()
	if raw == "":
		return default_val
	return float(raw)

# Main runtime logic lives here.
func _read_text(parts: Array, idx: int, default_val: String = "") -> String:
	if idx < 0 or idx >= parts.size():
		return default_val
	return str(parts[idx]).strip_edges()

# Data/resource load and sanity checks.
func _nacti_data_statu_pro_browser():
	country_stats.clear()
	var data_path = _resolve_provinces_data_path()
	var file = FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to load province dataset for country browser.")
		return

	if file.eof_reached():
		return

	var header_line = file.get_line().strip_edges()
	var col_index = _build_column_index(header_line)

	var idx_type = _find_column_idx(col_index, ["type"], 4)
	var idx_owner = _find_column_idx(col_index, ["controller", "owner"], 6)
	var idx_country_name = _find_column_idx(col_index, ["country_name"], 11)
	var idx_population = _find_column_idx(col_index, ["population"], 12)
	var idx_gdp = _find_column_idx(col_index, ["gdp"], 13)
	var idx_ideology = _find_column_idx(col_index, ["ideology"], 18)
	var idx_recruitable = _find_column_idx(col_index, ["recruitable_population"], 19)
	var idx_soldiers = _find_column_idx(col_index, ["soldiers", "army", "army_size"], -1)

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		var parts = line.split(";")
		if parts.size() < 7:
			continue

		var typ = _read_text(parts, idx_type).to_lower()
		var tag = _read_text(parts, idx_owner).to_upper()
		if typ == "sea" or tag == "" or tag == "SEA":
			continue

		if not country_stats.has(tag):
			country_stats[tag] = {
				"tag": tag,
				"country_name_en": _read_text(parts, idx_country_name, tag),
				"ideology": _read_text(parts, idx_ideology),
				"population": 0,
				"gdp": 0.0,
				"recruitable_population": 0,
				"soldiers": 0,
				"province_count": 0
			}

		country_stats[tag]["population"] += _read_int(parts, idx_population)
		country_stats[tag]["gdp"] += _read_float(parts, idx_gdp)
		country_stats[tag]["recruitable_population"] += _read_int(parts, idx_recruitable)
		country_stats[tag]["province_count"] += 1
		country_stats[tag]["soldiers"] += _read_int(parts, idx_soldiers)

# Core flow for this feature.
func _naplni_browser_seznam():
	for child in country_list.get_children():
		child.queue_free()

	country_rows.clear()

	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort_custom(func(a, b):
		return _zobrazene_jmeno_statu(str(a)) < _zobrazene_jmeno_statu(str(b))
	)

	for tag in vsechny_tagy:
		var row_btn = _vytvor_radek_statu(str(tag))
		country_list.add_child(row_btn)
		country_rows[str(tag)] = row_btn

	if not vsechny_tagy.is_empty():
		_nastav_detail_statu(str(vsechny_tagy[0]))

	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()

# Initialization for UI objects and hooks.
func _vytvor_radek_statu(tag: String) -> Button:
	var stats = country_stats[tag]
	var row_btn = Button.new()
	row_btn.custom_minimum_size = Vector2(0, COUNTRY_BROWSER_ROW_H_COMPACT if _browser_compact_mode else COUNTRY_BROWSER_ROW_H_DEFAULT)
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.flat = false
	row_btn.clip_text = true
	row_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var icon_path = "res://map_data/Flags/%s.svg" % tag
	var icon_tex = _load_normalized_flag_texture(icon_path, 56, 36)
	if icon_tex:
		row_btn.icon = icon_tex
		row_btn.expand_icon = false
	row_btn.text = _sestav_text_radku_statu(tag)
	row_btn.tooltip_text = "%s (%s) | Population: %s | GDP: %.1f" % [
		_zobrazene_jmeno_statu(tag), tag, _formatuj_cislo(int(stats["population"])), float(stats["gdp"])
	]
	row_btn.pressed.connect(func(): _on_country_row_pressed(tag))
	return row_btn

# Runs the local feature logic.
func _sestav_text_radku_statu(tag: String) -> String:
	if not country_stats.has(tag):
		return tag

	var stats = country_stats[tag]
	var badges: Array = []

	if selected_country_tag_in_browser == tag:
		badges.append("SELECTED")

	var idx = local_player_tags.find(tag)
	if idx != -1:
		badges.append("TAKEN")
		badges.append("PLAYER %d" % (idx + 1))
		if new_game_browser_flow and idx == setup_active_player_index:
			badges.append("ACTIVE")

	var prefix = ""
	if not badges.is_empty():
		prefix = "[%s] " % " | ".join(badges)
	if _browser_tiny_mode:
		var status = ""
		if selected_country_tag_in_browser == tag:
			status = " [S]"
		elif local_player_tags.find(tag) != -1:
			status = " [T]"
		return "%s (%s)%s | Pop: %s | GDP: %.1f" % [
			_zobrazene_jmeno_statu(tag),
			tag,
			status,
			_formatuj_cislo(int(stats["population"])),
			float(stats["gdp"])
		]

	return "%s%s (%s)\nPop: %s  |  GDP: %.1f" % [
		prefix,
		_zobrazene_jmeno_statu(tag),
		tag,
		_formatuj_cislo(int(stats["population"])),
		float(stats["gdp"])
	]

# Refreshes existing content to reflect current runtime values.
func _obnov_texty_radku_statu() -> void:
	var spectate_lock = _je_spectate_new_game_aktivni()
	# Pro male dite: projdeme vsechny radky statu a nastavime jim spravny vzhled.
	for tag in country_rows.keys():
		var row_btn = country_rows[tag]
		if row_btn:
			var tag_txt = str(tag)
			row_btn.text = _sestav_text_radku_statu(tag_txt)
			var je_obsazeno = new_game_browser_flow and local_player_tags.has(tag_txt)
			var je_aktivne_vybrany = selected_country_tag_in_browser == tag_txt

			if spectate_lock:
				# Spectate setup intentionally disables state picking for all rows.
				row_btn.disabled = true
				row_btn.modulate = Color(0.56, 0.56, 0.62, 0.92)
				continue

			if je_obsazeno:
				row_btn.disabled = false
				row_btn.modulate = Color(0.72, 0.72, 0.78, 1.0)
			elif je_aktivne_vybrany:
				row_btn.disabled = false
				row_btn.modulate = Color(0.88, 0.95, 1.0, 1.0)
			else:
				row_btn.disabled = false
				row_btn.modulate = Color(1, 1, 1, 1)

# Refreshes cached/UI state.
func _aktualizuj_panel_vyberu_hracu() -> void:
	if not selected_players_title or not selected_players_list:
		return
	_ensure_selected_players_flag_list()
	_clear_selected_players_flag_rows()
	if _je_spectate_new_game_aktivni():
		selected_players_title.text = "Spectate mode"
		selected_players_list.text = "No human players. AI observer start."
		_add_selected_player_row("Observer only (AI vs AI)", "", true)
		if _selected_players_scroll:
			_selected_players_scroll.custom_minimum_size = Vector2(0, 92)
		call_deferred("_apply_country_browser_window_size")
		return

	var row_count := 0
	if new_game_browser_flow:
		selected_players_title.text = "Selected Countries"
		if local_player_tags.is_empty():
			selected_players_list.text = "Nobody yet"
			_add_selected_player_row("Nobody yet", "", false)
			row_count = 1
		else:
			var lines: Array = []
			for i in range(local_player_tags.size()):
				var tag = str(local_player_tags[i])
				var prefix = "%d." % (i + 1)
				var row_text = "%s %s (%s)" % [prefix, _zobrazene_jmeno_statu(tag), tag]
				lines.append(row_text)
				_add_selected_player_row(row_text, tag, i == setup_active_player_index, i)
			selected_players_list.text = "\n".join(lines)
			row_count = local_player_tags.size()
	else:
		selected_players_title.text = "Current selection"
		if selected_country_tag == "":
			selected_players_list.text = "Nobody yet"
			_add_selected_player_row("Nobody yet", "", false)
			row_count = 1
		else:
			selected_players_list.text = "%s (%s)" % [_zobrazene_jmeno_statu(selected_country_tag), selected_country_tag]
			_add_selected_player_row(selected_players_list.text, selected_country_tag, false)
			row_count = 1

	if _selected_players_scroll:
		var flow_rows := row_count
		var width_for_layout = maxf(200.0, _selected_players_scroll.size.x)
		if width_for_layout <= 200.0 and _selected_players_scroll.custom_minimum_size.x > 0:
			width_for_layout = _selected_players_scroll.custom_minimum_size.x
		var chips_per_row = max(1, int(floor(width_for_layout / float(_PLAYER_CHIP_MIN_W + 8))))
		flow_rows = int(ceil(float(max(1, row_count)) / float(chips_per_row)))
		var needed_h = flow_rows * _PLAYER_ROW_H + max(0, flow_rows - 1) * 6 + 10
		var vp := get_viewport()
		var viewport_h = vp.get_visible_rect().size.y if vp != null else 720.0
		var compact_rows = viewport_h < COUNTRY_BROWSER_COMPACT_H
		var max_h = min(_PLAYER_ROW_MAX_H, int(maxf(92.0, viewport_h * (0.19 if compact_rows else 0.27))))
		var target_h = clamp(needed_h, 82 if compact_rows else 128, max_h)
		_selected_players_scroll.custom_minimum_size = Vector2(0, target_h)

	# Deferred reset to prevent the panel from jumping when layout recalculates
	call_deferred("_apply_country_browser_window_size")

# Runs the local feature logic.
func _zobrazene_jmeno_statu(tag: String) -> String:
	for nazev in hratelne_staty.keys():
		if hratelne_staty[nazev] == tag:
			return nazev
	if country_stats.has(tag):
		return str(country_stats[tag].get("country_name_en", tag))
	return tag

# Applies updates and syncs dependent state.
func _nastav_detail_statu(tag: String, update_aggression_ui: bool = true):
	if not country_stats.has(tag):
		return

	selected_country_tag_in_browser = tag
	for row_tag in country_rows.keys():
		var row_btn = country_rows[row_tag]
		row_btn.disabled = (row_tag == tag)

	var s = country_stats[tag]
	var jmeno = _zobrazene_jmeno_statu(tag)

	detail_name.text = jmeno
	detail_tag.text = "Tag: %s" % tag
	detail_ideology.text = "Ideology: %s" % str(s["ideology"]).capitalize()
	detail_population.text = "Population: %s" % _formatuj_cislo(int(s["population"]))
	detail_gdp.text = "GDP: %.2f bn USD" % float(s["gdp"])
	detail_recruits.text = "Recruits: %s" % _formatuj_cislo(int(s["recruitable_population"]))
	detail_soldiers.text = "Soldiers: %s" % _formatuj_cislo(int(s["soldiers"]))
	detail_provinces.text = "Provinces: %d" % int(s["province_count"])
	detail_info.text = _vytvor_souhrn_statu(jmeno, s, _browser_tiny_mode or _browser_compact_mode)
	if update_aggression_ui:
		_set_ai_aggression_ui_for_tag(tag)

	var flag_tex = _load_normalized_flag_texture("res://map_data/Flags/%s.svg" % tag, 240, 150)
	detail_flag.texture = flag_tex

# Creates required nodes and connects signals.
func _vytvor_souhrn_statu(jmeno: String, s: Dictionary, compact_summary: bool = false) -> String:
	var populace = max(1, int(s.get("population", 0)))
	var hdp = float(s.get("gdp", 0.0))
	var provincie = int(s.get("province_count", 0))
	var rekruti = int(s.get("recruitable_population", 0))
	var vojaci = int(s.get("soldiers", 0))

	var hdp_na_osobu = (hdp * 1000000000.0) / float(populace)
	var mobilizace = float(vojaci) / float(populace)
	var rekrut_podil = float(rekruti) / float(populace)

	var vyspelost = "lower"
	if hdp_na_osobu >= 45000.0:
		vyspelost = "high"
	elif hdp_na_osobu >= 25000.0:
		vyspelost = "medium"

	var velikost = "smaller"
	if provincie >= 35:
		velikost = "very large"
	elif provincie >= 18:
		velikost = "mid-sized"

	var vojenska_sila = "limited"
	if mobilizace >= 0.015:
		vojenska_sila = "high"
	elif mobilizace >= 0.007:
		vojenska_sila = "solid"

	var silne = []
	var slabiny = []

	if vyspelost == "high":
		silne.append("strong economy and stable foundation for long-term expansion")
	elif vyspelost == "medium":
		silne.append("balanced economy suitable for flexible strategy")
	else:
		slabiny.append("lower economic output and slower modernization pace")

	if provincie >= 25:
		silne.append("wide territory with more maneuver and defense options")
	elif provincie <= 8:
		slabiny.append("small territory, vulnerable to early pressure")

	if rekrut_podil >= 0.09:
		silne.append("above-average recruit pool for army reinforcement")
	elif rekrut_podil <= 0.04:
		slabiny.append("limited army growth due to low recruit share")

	if vojenska_sila == "high":
		silne.append("strong immediate combat readiness")
	elif vojenska_sila == "limited":
		slabiny.append("weaker starting army, safer to play a cautious opening")

	var silne_text = ", ".join(silne) if not silne.is_empty() else "flexible start without major extremes"
	var slabiny_text = ", ".join(slabiny) if not slabiny.is_empty() else "no critical weakness at game start"
	if compact_summary:
		return "%s: %s economy, %s military. + %s. - %s." % [jmeno, vyspelost, vojenska_sila, silne_text, slabiny_text]

	return "%s is a %s country with a %s base and %s military readiness. Strengths: %s. Risks: %s." % [jmeno, velikost, vyspelost, vojenska_sila, silne_text, slabiny_text]

# Callback for UI/game events.
func _on_country_row_pressed(tag: String):
	if _je_spectate_new_game_aktivni():
		return
	if new_game_browser_flow:
		var owner_idx = local_player_tags.find(tag)
		if owner_idx != -1 and owner_idx != setup_active_player_index:
			# Clicking an already selected country switches editing focus to that player.
			setup_active_player_index = owner_idx
			selected_country_tag_in_browser = tag
			_nastav_detail_statu(tag, true)
			_obnov_texty_radku_statu()
			_aktualizuj_panel_vyberu_hracu()
			_aktualizuj_browser_napovedu()
			return
		_prirad_stat_aktivnimu_hraci(tag)
		return
	_nastav_detail_statu(tag)
	_obnov_texty_radku_statu()

# Fetches data for callers.
func _ziskej_setup_tag_aktivniho_hrace() -> String:
	if local_player_tags.is_empty():
		return ""
	if setup_active_player_index < 0 or setup_active_player_index >= local_player_tags.size():
		return ""
	return str(local_player_tags[setup_active_player_index])

# Finds the best matching result.
func _najdi_prvni_volny_tag() -> String:
	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort_custom(func(a, b):
		return _zobrazene_jmeno_statu(str(a)) < _zobrazene_jmeno_statu(str(b))
	)

	for raw_tag in vsechny_tagy:
		var tag = str(raw_tag)
		if not local_player_tags.has(tag):
			return tag

	return ""

# Feature logic entry point.
func _prirad_stat_aktivnimu_hraci(tag: String) -> void:
	if _je_spectate_new_game_aktivni():
		return
	if local_player_tags.is_empty():
		return

	if setup_active_player_index < 0 or setup_active_player_index >= local_player_tags.size():
		return

	var idx_obsazeni = local_player_tags.find(tag)
	if idx_obsazeni != -1 and idx_obsazeni != setup_active_player_index:
		if browser_flow_hint:
			browser_flow_hint.text = "Country %s is already taken by another player." % tag
		return

	local_player_tags[setup_active_player_index] = tag
	selected_country_tag_in_browser = tag
	selected_country_tag = str(local_player_tags[0])
	_nastav_detail_statu(tag, true)
	_obnov_text_vyberu()
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()

# Runs the local feature logic.
func _pridej_dalsiho_hrace_do_setupu() -> void:
	if _je_spectate_new_game_aktivni():
		return
	var novy_tag = _najdi_prvni_volny_tag()
	if novy_tag == "":
		if browser_flow_hint:
			browser_flow_hint.text = "No additional free country is available for a new player."
		return

	local_player_tags.append(novy_tag)
	setup_active_player_index = local_player_tags.size() - 1
	selected_country_tag_in_browser = novy_tag
	_nastav_detail_statu(novy_tag, false)
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()

# Opens a UI flow/panel and prepares its data and position.
func _otevri_browser_statu():
	_apply_country_browser_window_size()
	if selected_country_tag != "" and country_stats.has(selected_country_tag):
		_nastav_detail_statu(selected_country_tag, false)
	_aktualizuj_stav_blokace_vyberu_statu()
	_aktualizuj_browser_napovedu()
	country_browser_panel.show()

# Triggered by a UI/game signal.
func _on_confirm_country_pressed():
	if _je_spectate_new_game_aktivni():
		return
	if new_game_browser_flow:
		_pridej_dalsiho_hrace_do_setupu()
		return

	if selected_country_tag_in_browser != "":
		selected_country_tag = selected_country_tag_in_browser
		_obnov_text_vyberu()
		_aktualizuj_panel_vyberu_hracu()

	country_browser_panel.hide()

# Callback for UI/game events.
func _on_close_browser_pressed():
	if new_game_browser_flow:
		# In spectate flow, closing browser means immediate AI-vs-AI start.
		# Pro male dite: kdyz je spectate, zavreni okna = hned spustit hru bez hrace.
		if _je_spectate_new_game_aktivni():
			setup_active_player_index = 0
			new_game_browser_flow = false
			btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
			btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
			if _browser_spectate_mode_check:
				_browser_spectate_mode_check.set_block_signals(true)
				_browser_spectate_mode_check.button_pressed = false
				_browser_spectate_mode_check.set_block_signals(false)
			_aktualizuj_stav_blokace_vyberu_statu()
			_obnov_texty_radku_statu()
			_aktualizuj_panel_vyberu_hracu()
			_aktualizuj_browser_napovedu()
			country_browser_panel.hide()
			_spust_hru_vyberem([], true)
			return
		if local_player_tags.is_empty() and selected_country_tag != "":
			local_player_tags.append(selected_country_tag)
		selected_country_tag = str(local_player_tags[0]) if not local_player_tags.is_empty() else selected_country_tag
		setup_active_player_index = 0
		new_game_browser_flow = false
		btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
		btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
		_obnov_texty_radku_statu()
		_aktualizuj_panel_vyberu_hracu()
		_aktualizuj_browser_napovedu()
		country_browser_panel.hide()
		_spust_hru_vyberem(local_player_tags)
		return

	new_game_browser_flow = false
	btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
	btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	country_browser_panel.hide()

# Handles this signal callback.
func _on_close_browser_corner_pressed():
	new_game_browser_flow = false
	setup_active_player_index = 0
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.set_block_signals(true)
		_browser_spectate_mode_check.button_pressed = false
		_browser_spectate_mode_check.set_block_signals(false)
	_aktualizuj_stav_blokace_vyberu_statu()
	btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
	btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
	local_player_tags.clear()
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	country_browser_panel.hide()

# Refreshes existing content to reflect current runtime values.
func _obnov_text_vyberu():
	if local_player_tags.size() > 1:
		selected_country_label.text = "Local players: %s" % ", ".join(local_player_tags)
		if menu_hint_label:
			menu_hint_label.text = "Ready: %d players. Click New Game to edit selection or Load for a quick start." % local_player_tags.size()
		_aktualizuj_panel_vyberu_hracu()
		return

	if selected_country_tag == "":
		selected_country_label.text = "Selected country: none"
		return

	var nazev_statu = _zobrazene_jmeno_statu(selected_country_tag)
	selected_country_label.text = "Selected country: %s (%s)" % [nazev_statu, selected_country_tag]
	if menu_hint_label:
		menu_hint_label.text = "For multiplayer, add more countries in New Game."
	if country_stats.has(selected_country_tag):
		_nastav_detail_statu(selected_country_tag)
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_clean_helpery()

# Rebuilds state from latest data.
func _aktualizuj_browser_napovedu():
	if not browser_flow_hint or not browser_subtitle or not list_hint:
		return

	if new_game_browser_flow:
		if _je_spectate_new_game_aktivni():
			browser_subtitle.text = "Observer setup. Human country selection is disabled."
			list_hint.text = "Spectate mode is ON: country offer and selection are disabled."
			browser_flow_hint.text = "Press Start game to launch AI vs AI observer session."
			_aktualizuj_clean_helpery()
			return
		browser_subtitle.text = "Player 1 is added automatically. Click to assign a country to the active player."
		list_hint.text = "Click a country chip in Selected Countries to pick player, then click a free country to change it."
		if local_player_tags.is_empty():
			browser_flow_hint.text = "Preparing player selection..."
		else:
			var cislo_hrace = setup_active_player_index + 1
			var aktivni_tag = _ziskej_setup_tag_aktivniho_hrace()
			browser_flow_hint.text = "Selecting country for PLAYER %d. Current: %s" % [cislo_hrace, aktivni_tag]
	else:
		browser_subtitle.text = "Pick one country for solo or add more for local multiplayer"
		list_hint.text = "Click a country for details, then confirm selection"
		browser_flow_hint.text = "Solo mode: choose a country and confirm."
	_aktualizuj_clean_helpery()

# Writes new values and refreshes related state.
func _nastav_stav_pokracovani():
	var ma_save = FileAccess.file_exists(SAVE_FILE_PATH)
	if GameManager and GameManager.has_method("ma_ulozene_hry"):
		ma_save = bool(GameManager.ma_ulozene_hry())
	var t = _texty_ui()
	btn_continue.disabled = not ma_save
	if ma_save:
		btn_continue.text = str(t["continue"])
	else:
		btn_continue.text = str(t["continue_empty"])

# Construct/setup block for required nodes.
func _vytvor_load_dialog() -> void:
	if _load_dialog != null:
		return

	_load_dialog = AcceptDialog.new()
	_load_dialog.name = "LoadDialog"
	_load_dialog.title = "Load Game"
	_load_dialog.min_size = Vector2i(720, 560)
	_load_dialog.size = Vector2i(720, 560)
	_load_dialog.wrap_controls = false
	_load_dialog.unresizable = true
	_load_dialog.ok_button_text = "Close"
	add_child(_load_dialog)

	# Hide the native OK button Ă˘â‚¬â€ś our footer provides its own Close
	_load_dialog.get_ok_button().hide()

	var root = MarginContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	_load_dialog.add_child(root)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	# Title Ă˘â‚¬â€ś matches BrowserTitle font size
	var title_lbl = Label.new()
	title_lbl.text = "Load Game"
	title_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title_lbl)

	# List panel Ă˘â‚¬â€ś matches ListPanel structure from Country Browser
	var list_panel = PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_panel)

	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 10)
	list_margin.add_theme_constant_override("margin_top", 10)
	list_margin.add_theme_constant_override("margin_right", 10)
	list_margin.add_theme_constant_override("margin_bottom", 10)
	list_panel.add_child(list_margin)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_vbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_child(scroll)

	_load_scroll_vbox = VBoxContainer.new()
	_load_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_scroll_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_load_scroll_vbox)

	# Status label Ă˘â‚¬â€ś BrowserFlowHint color
	_load_status_label = Label.new()
	_load_status_label.text = ""
	_load_status_label.add_theme_color_override("font_color", Color(0.8, 0.870588, 0.964706, 1.0))
	vbox.add_child(_load_status_label)

	# Footer buttons Ă˘â‚¬â€ś matches BrowserButtons style exactly
	var browser_btns = HBoxContainer.new()
	browser_btns.add_theme_constant_override("separation", 10)
	vbox.add_child(browser_btns)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(0, 44)
	refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_btn.pressed.connect(_obnov_load_sloty_v_menu)
	browser_btns.add_child(refresh_btn)

	_load_open_button = Button.new()
	_load_open_button.text = "Load"
	_load_open_button.custom_minimum_size = Vector2(0, 44)
	_load_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_open_button.disabled = true
	_load_open_button.pressed.connect(_on_load_selected_pressed)
	browser_btns.add_child(_load_open_button)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): _load_dialog.hide())
	browser_btns.add_child(close_btn)

	_styluj_mainmenu_popup_dialogy()
	_obnov_load_sloty_v_menu()

# Builds UI objects and default wiring.
func _vytvor_load_row_style(selected: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(0.14, 0.22, 0.38, 0.95)
		s.border_color = Color(0.45, 0.6, 0.82, 0.95)
		s.border_width_top = 2
		s.border_width_left = 2
		s.border_width_right = 1
		s.border_width_bottom = 1
	else:
		s.bg_color = Color(0.065, 0.102, 0.168, 0.0)
		s.border_color = Color(0.28, 0.38, 0.53, 0.0)
		s.border_width_top = 0
		s.border_width_left = 0
		s.border_width_right = 0
		s.border_width_bottom = 0
	s.content_margin_left = 14.0
	s.content_margin_top = 6.0
	s.content_margin_right = 14.0
	s.content_margin_bottom = 6.0
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	return s

# Refreshes existing content to reflect current runtime values.
func _obnov_load_sloty_v_menu() -> void:
	if _load_scroll_vbox == null:
		return

	for ch in _load_scroll_vbox.get_children():
		ch.queue_free()
	_load_slot_btns.clear()
	_selected_load_slot_key = ""

	var all_slots: Array = []

	if GameManager and GameManager.has_method("ziskej_save_sloty"):
		var slots = GameManager.ziskej_save_sloty() as Array
		for slot_any in slots:
			var slot = slot_any as Dictionary
			var slot_name = str(slot.get("name", "")).strip_edges()
			if slot_name == "":
				continue
			var modified = int(slot.get("modified", 0))
			var stamp = "date unknown"
			if modified > 0:
				stamp = Time.get_datetime_string_from_unix_time(modified, true)
			all_slots.append({"key": slot_name, "name": slot_name, "stamp": stamp})

	if FileAccess.file_exists(SAVE_FILE_PATH):
		all_slots.append({"key": "__legacy__", "name": "Legacy quicksave", "stamp": "savegame.dat"})

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.11, 0.18, 0.30, 0.92)
	hover_style.border_color = Color(0.45, 0.62, 0.86, 0.75)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.corner_radius_bottom_left = 6

	for slot_info_any in all_slots:
		var slot_info = slot_info_any as Dictionary
		var slot_key = str(slot_info.get("key", ""))
		var slot_name = str(slot_info.get("name", ""))
		var stamp = str(slot_info.get("stamp", ""))

		var row_btn = Button.new()
		row_btn.custom_minimum_size = Vector2(0, 74)
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.flat = false
		row_btn.focus_mode = Control.FOCUS_CLICK
		row_btn.add_theme_stylebox_override("normal", _vytvor_load_row_style(false))
		row_btn.add_theme_stylebox_override("hover", hover_style.duplicate())
		row_btn.add_theme_stylebox_override("pressed", _vytvor_load_row_style(true))
		row_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var inner = VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_theme_constant_override("separation", 3)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(inner)

		var name_lbl = Label.new()
		name_lbl.text = slot_name
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.clip_text = true
		inner.add_child(name_lbl)

		var date_lbl = Label.new()
		date_lbl.text = stamp
		date_lbl.add_theme_font_size_override("font_size", 12)
		date_lbl.add_theme_color_override("font_color", Color(0.694118, 0.831373, 1.0, 1.0))
		date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(date_lbl)

		row_btn.pressed.connect(_on_load_row_pressed.bind(slot_key))
		_load_slot_btns[slot_key] = row_btn
		_load_scroll_vbox.add_child(row_btn)

	var count := all_slots.size()
	if _load_open_button:
		_load_open_button.disabled = count == 0
	if _load_status_label:
		_load_status_label.text = "%d save%s found" % [count, "s" if count != 1 else ""] if count > 0 else "No saves found."

	if count > 0:
		var first_key = str((all_slots[0] as Dictionary).get("key", ""))
		_on_load_row_highlight(first_key)

# Opens a UI flow/panel and prepares its data and position.
func _otevri_load_okno() -> void:
	if _load_dialog == null:
		_vytvor_load_dialog()
	_obnov_load_sloty_v_menu()
	_load_dialog.popup_centered(_load_dialog.min_size)

# Reacts to incoming events.
func _on_load_row_pressed(slot_key: String) -> void:
	_on_load_row_highlight(slot_key)

# Handles this signal callback.
func _on_load_row_highlight(slot_key: String) -> void:
	_selected_load_slot_key = slot_key
	for key in _load_slot_btns.keys():
		var btn = _load_slot_btns[key] as Button
		if btn:
			var is_sel = key == slot_key
			btn.add_theme_stylebox_override("normal", _vytvor_load_row_style(is_sel))
			btn.add_theme_stylebox_override("focus", _vytvor_load_row_style(is_sel))
	if _load_open_button:
		_load_open_button.disabled = slot_key == ""

# Pulls current state data.
func _ziskej_vybrany_load_slot() -> String:
	return _selected_load_slot_key

# Reacts to incoming events.
func _on_load_selected_pressed() -> void:
	var slot_key = _ziskej_vybrany_load_slot()
	if slot_key == "":
		if _load_status_label:
			_load_status_label.text = "Select a save first."
		return
	if _load_dialog:
		_load_dialog.hide()
	_spust_load_ze_slotu(slot_key)

# Feature logic entry point.
func _pockej_na_map_scenu(tree: SceneTree, max_frames: int = 180) -> bool:
	if tree == null:
		return false
	for _i in range(max_frames):
		if GameManager and GameManager.has_method("_get_map_loader"):
			var loader = GameManager._get_map_loader()
			if loader != null:
				if loader.has_method("je_pripraveno_pro_load"):
					if bool(loader.je_pripraveno_pro_load()):
						return true
				else:
					# Backward-compatible fallback for older loader implementations.
					return true
		await tree.process_frame
	return false

# Handles this gameplay/UI path.
func _spust_load_ze_slotu(slot_key: String) -> void:
	if GameManager and GameManager.has_method("spust_load_ze_slotu_pres_scenu"):
		GameManager.spust_load_ze_slotu_pres_scenu(slot_key, MAP_SCENE_PATH)
		return

	var tree := get_tree()
	if tree == null:
		push_warning("Load canceled: SceneTree is unavailable.")
		return

	var err = tree.change_scene_to_file(MAP_SCENE_PATH)
	if err != OK:
		push_warning("Failed to open map for Load. Error: %s" % str(err))
		return

	await tree.process_frame
	if not await _pockej_na_map_scenu(tree):
		push_warning("Load canceled: map scene did not initialize in time.")
		return

	var loaded_ok := false
	if slot_key == "__legacy__":
		if GameManager and GameManager.has_method("nacti_hru"):
			loaded_ok = bool(GameManager.nacti_hru())
	elif GameManager and GameManager.has_method("nacti_hru_ze_slotu"):
		loaded_ok = bool(GameManager.nacti_hru_ze_slotu(slot_key))

	if not loaded_ok:
		# Fallback to newest available save if selected slot cannot be loaded.
		if GameManager and GameManager.has_method("nacti_posledni_hru"):
			loaded_ok = bool(GameManager.nacti_posledni_hru())

	if not loaded_ok:
		push_warning("Load failed: save could not be loaded.")
		return

	# Defensive sync: ensure map loader and visuals use loaded state even if something
	# reinitialized province data during scene transition.
	await tree.process_frame
	if GameManager and GameManager.has_method("_get_map_loader"):
		var loader = GameManager._get_map_loader()
		if loader != null and not GameManager.map_data.is_empty():
			if "provinces" in loader:
				loader.provinces = (GameManager.map_data as Dictionary).duplicate(true)
				GameManager.map_data = loader.provinces
			if loader.has_method("_rebuild_movement_topology_cache"):
				loader._rebuild_movement_topology_cache()
			if loader.has_method("_invalidate_naval_reachability_cache"):
				loader._invalidate_naval_reachability_cache()
			if loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
				loader._aktualizuj_aktivni_mapovy_mod()
			if loader.has_method("aktualizuj_ikony_armad"):
				loader.aktualizuj_ikony_armad()
			if loader.has_method("aktualizuj_vlajky_hlavnich_mest"):
				loader.aktualizuj_vlajky_hlavnich_mest()

# Main runtime logic lives here.
func _spust_hru_vyberem(player_tags: Array = [], spectate_mode: bool = false):
	# One entry point for both normal player start and observer/spectate start.
	# Pro male dite: tohle je hlavni cudlik v kodu, co opravdu pusti mapu.
	spectate_mode = false
	var final_tags = player_tags.duplicate()
	if not spectate_mode and final_tags.is_empty() and selected_country_tag != "":
		final_tags = [selected_country_tag]
	if not spectate_mode and final_tags.is_empty():
		return
	if not spectate_mode:
		selected_country_tag = str(final_tags[0])

	# Start a truly fresh session for New Game and avoid carrying previous run state.
	if GameManager and GameManager.has_method("reset_pro_novou_hru"):
		GameManager.reset_pro_novou_hru()

	# Reset uploaded custom flags so each New Game starts with default flag assets.
	CountryCustomization.clear_all_custom_flags()
	if GameManager.has_method("nastav_spectate_mode"):
		GameManager.nastav_spectate_mode(spectate_mode)

	# Save selected local players to GameManager.
	if GameManager.has_method("nastav_lokalni_hrace"):
		GameManager.nastav_lokalni_hrace(final_tags)
	elif not spectate_mode:
		GameManager.hrac_stat = selected_country_tag

	_apply_ai_aggression_overrides(final_tags)

	print("Local players: ", final_tags)
	
	# Load the main map scene
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

# Reacts to incoming events.
func _on_new_game_pressed():
	# Reset setup state so previous browser/session choices cannot leak into new game.
	# Pro male dite: zmacknu New Game -> vse stare se vycisti a zacina se od nuly.
	local_player_tags.clear()
	new_game_browser_flow = true
	setup_active_player_index = 0
	if _browser_spectate_mode_check:
		_browser_spectate_mode_check.set_block_signals(true)
		_browser_spectate_mode_check.button_pressed = false
		_browser_spectate_mode_check.set_block_signals(false)

	var vychozi_tag = selected_country_tag.strip_edges().to_upper()
	if vychozi_tag == "" or not country_stats.has(vychozi_tag):
		vychozi_tag = _najdi_prvni_volny_tag()
	if vychozi_tag == "":
		vychozi_tag = selected_country_tag

	if vychozi_tag != "":
		local_player_tags = [vychozi_tag]
		selected_country_tag = vychozi_tag
		selected_country_tag_in_browser = vychozi_tag
		_nastav_detail_statu(vychozi_tag)

	btn_confirm_country.text = BROWSER_CONFIRM_ADD_PLAYER_TEXT
	btn_close_browser.text = BROWSER_CLOSE_START_TEXT
	_obnov_text_vyberu()
	_obnov_texty_radku_statu()
	_aktualizuj_stav_blokace_vyberu_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	_otevri_browser_statu()

# Handles this signal callback.
func _on_continue_pressed():
	_otevri_load_okno()

# Callback for UI/game events.
func _on_settings_pressed():
	_ensure_keybind_controls()
	_nastav_settings_ui_z_dat()
	_aktualizuj_settings_hodnoty()
	_settings_original_ui_state = _read_settings_from_ui()
	_show_settings_tab(0)  # Show Controls tab
	_styluj_mainmenu_popup_dialogy()
	_ensure_settings_buttons_connected()
	_apply_settings_dialog_window_size()

	var apply_btn = _get_settings_button_apply()
	var reset_btn = _get_settings_button_reset()
	
	if apply_btn:
		apply_btn.visible = true
		if apply_btn.get_parent():
			apply_btn.get_parent().visible = true
	
	if reset_btn:
		reset_btn.visible = true
		if reset_btn.get_parent():
			reset_btn.get_parent().visible = true
	
	settings_dialog.popup_centered(settings_dialog.size)
	call_deferred("_refresh_apply_button_state")

# Display update for visible data.
func _show_settings_tab(tab_index: int) -> void:
	if tab_index == 0:
		controls_panel.show()
		settings_panel.hide()
		controls_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		controls_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		settings_btn.modulate = Color(0.65, 0.72, 0.82, 1.0)
		settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		controls_panel.hide()
		settings_panel.show()
		controls_btn.modulate = Color(0.65, 0.72, 0.82, 1.0)
		controls_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		settings_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		settings_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

# Event handler for user or game actions.
func _on_controls_tab_clicked() -> void:
	_show_settings_tab(0)

# Callback for UI/game events.
func _on_settings_tab_clicked() -> void:
	_show_settings_tab(1)

# Triggered by a UI/game signal.
func _on_apply_settings_pressed() -> void:
	_uloz_settings_ui_do_dat()
	_aplikuj_nastaveni_globalne()
	_aktualizuj_texty_dle_jazyka()
	_nastav_stav_pokracovani()
	_uloz_nastaveni()
	_settings_original_ui_state = _read_settings_from_ui()
	_refresh_apply_button_state()

# Callback for UI/game events.
func _on_reset_settings_pressed() -> void:
	nastaveni_data = _vytvor_vychozi_nastaveni()
	_nastav_settings_ui_z_dat()
	_aktualizuj_settings_hodnoty()
	_aplikuj_nastaveni_globalne()
	_aktualizuj_texty_dle_jazyka()
	_nastav_stav_pokracovani()
	_uloz_nastaveni()
	_settings_original_ui_state = _read_settings_from_ui()
	_refresh_apply_button_state()

# Handles this signal callback.
func _on_language_option_selected(_idx: int) -> void:
	# Language switch is applied immediately to avoid UI/data desync.
	nastaveni_data["language"]["code"] = _jazyk_z_option()
	_aktualizuj_texty_dle_jazyka()
	_nastav_stav_pokracovani()
	_uloz_nastaveni()
	_settings_original_ui_state = _read_settings_from_ui()
	_refresh_apply_button_state()

# Reacts to incoming events.
func _on_settings_value_changed(_value: float) -> void:
	_aktualizuj_settings_hodnoty()
	_refresh_apply_button_state()

# Triggered by a UI/game signal.
func _on_settings_toggle_changed(_pressed: bool) -> void:
	_refresh_apply_button_state()

# Handles immediate input callbacks.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and settings_dialog and settings_dialog.visible and _keybind_capture_action != "":
		if _capture_menu_keybind(event as InputEventKey):
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()

# Handles this signal callback.
func _on_credits_pressed():
	_styluj_mainmenu_popup_dialogy()
	credits_dialog.popup_centered(credits_dialog.min_size)

# Reacts to incoming events.
func _on_exit_pressed():
	_styluj_mainmenu_popup_dialogy()
	exit_dialog.popup_centered(exit_dialog.min_size)

# Triggered by a UI/game signal.
func _on_exit_confirmed():
	get_tree().quit()

# User-facing value formatter.
func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek


