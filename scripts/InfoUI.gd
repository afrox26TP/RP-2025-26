# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends CanvasLayer
# this script drives a specific gameplay/UI area and keeps related logic together.

# Province detail + local action panel.
# Simple part: shows current province numbers.
# Hard part: movement/recruit/liquidation popups must stay synced with selected province
# and with GameManager economy modifiers.


@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel
@onready var terrain_label = $PanelContainer/VBoxContainer/TerrainLabel
@onready var pop_label = $PanelContainer/VBoxContainer/PopLabel
@onready var recruit_label = $PanelContainer/VBoxContainer/RecruitLabel
@onready var gdp_label = $PanelContainer/VBoxContainer/GdpLabel
@onready var income_label = $PanelContainer/VBoxContainer/IncomeLabel 
@onready var soldiers_label = $PanelContainer/VBoxContainer/SoldiersLabel 

@onready var action_menu = $ActionMenu
@onready var info_panel = $PanelContainer
@onready var action_row = $ActionMenu/HBoxContainer
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

# Paths to the liquidation popup panel elements
@onready var likvidace_popup = $ActionMenu/LikvidacePopup
@onready var likvidace_info = $ActionMenu/LikvidacePopup/VBoxContainer/LikvidaceInfo
@onready var likvidace_slider = $ActionMenu/LikvidacePopup/VBoxContainer/LikvidaceSlider
@onready var btn_likvidace_potvrdit = $ActionMenu/LikvidacePopup/VBoxContainer/HBoxContainer/PotvrditButton
@onready var btn_likvidace_zrusit = $ActionMenu/LikvidacePopup/VBoxContainer/HBoxContainer/ZrusitButton

var presun_od_id: int = -1
var presun_do_id: int = -1
var presun_path: Array = []
var hromadny_vyber_ids: Array = []
var je_hromadny_rezim: bool = false
var je_hromadne_verbovani: bool = false
var je_hromadne_likvidovani: bool = false
# ---------------------------------------------------

var aktualni_provincie_id: int = -1
var cena_za_vojaka: float = 0.05 # Cost: 50 mil. per 1000 men
var likvidace_vynos_za_vojaka: float = 0.01 # Small refund per removed soldier
var _preview_label: Label
var _metric_rows: Dictionary = {}
var _metric_deltas: Dictionary = {}
var _ideology_preview_active: bool = false
var _stavba_popup: PopupMenu
var _stavba_last_focus_idx: int = -2
var _stavba_menu_build_ids: Array = []

const INFO_UI_MARGIN := 0.0
const INFO_UI_GAP := 0.0
const INFO_PANEL_MIN_W := 210.0
const INFO_PANEL_MAX_W := 360.0
const ACTION_MENU_MIN_W := 300.0
const ACTION_MENU_MAX_W := 560.0

# Fetches data for callers.
func _ziskej_provincie_data() -> Dictionary:
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader and "provinces" in map_loader:
		return map_loader.provinces
	return GameManager.map_data

# Returns current runtime data.
func _ziskej_map_loader():
	return get_tree().current_scene.find_child("Map", true, false)

# Turns raw data into readable text.
func _format_pct_signed(value: float) -> String:
	var pct = int(round(value * 100.0))
	if pct >= 0:
		return "+%d%%" % pct
	return "%d%%" % pct

# Main runtime logic lives here.
func _terenni_obranny_bonus_fallback(terrain_raw: String) -> float:
	var key = terrain_raw.strip_edges().to_lower()
	match key:
		"plains", "plain":
			return -0.20
		"forest":
			return 0.0
		"hills", "hill":
			return 0.20
		"mountains", "mountain":
			return 0.40
		"city":
			return 0.80
		_:
			return 0.0

# Returns current runtime data.
func _ziskej_terenni_obranny_bonus_pro_data(data: Dictionary, terrain_raw: String) -> float:
	var prov_id = int(data.get("id", -1))
	var map_loader = _ziskej_map_loader()
	if map_loader and prov_id >= 0 and map_loader.has_method("ziskej_terenni_obranny_bonus_pct"):
		return float(map_loader.ziskej_terenni_obranny_bonus_pct(prov_id))
	return _terenni_obranny_bonus_fallback(terrain_raw)

# Read-only data accessor.
func _ziskej_cenu_za_vojaka() -> float:
	if GameManager.has_method("ziskej_cenu_za_vojaka"):
		return float(GameManager.ziskej_cenu_za_vojaka(GameManager.hrac_stat))
	return cena_za_vojaka

# Read-only data accessor.
func _ziskej_udrzbu_za_vojaka() -> float:
	if GameManager.has_method("ziskej_udrzbu_za_vojaka"):
		return float(GameManager.ziskej_udrzbu_za_vojaka(GameManager.hrac_stat))
	return 0.001

# Read-only data accessor.
func _ziskej_prijmovou_sazbu_hdp() -> float:
	if GameManager.has_method("ziskej_prijmovou_sazbu_hdp"):
		return float(GameManager.ziskej_prijmovou_sazbu_hdp(GameManager.hrac_stat))
	return 0.1

func _ziskej_stavba_menu_building_id(menu_id: int) -> String:
	if menu_id < 0 or menu_id >= _stavba_menu_build_ids.size():
		return ""
	return str(_stavba_menu_build_ids[menu_id])

func _ziskej_stavba_def(building_id: String) -> Dictionary:
	if building_id == "":
		return {}
	if GameManager.has_method("ziskej_building_def_pro_ui"):
		return GameManager.ziskej_building_def_pro_ui(building_id) as Dictionary
	return {}

func _sestav_building_tooltip(building_id: String, bdef: Dictionary) -> String:
	var lines: Array = []
	lines.append(str(bdef.get("name", building_id)))
	lines.append("Cost: %s" % _format_money_auto(max(0.0, float(bdef.get("cost", 0.0))), 2))
	lines.append("Build time: %d turns" % max(1, int(bdef.get("build_time", 3))))

	var gdp_flat = float(bdef.get("gdp_flat", 0.0))
	if absf(gdp_flat) > 0.0001:
		lines.append("Effect: %+0.2f GDP" % gdp_flat)

	var recruit_flat = int(bdef.get("recruitable_flat", 0))
	if recruit_flat != 0:
		lines.append("Effect: %+d recruits" % recruit_flat)

	if bool(bdef.get("grant_port", false)):
		lines.append("Effect: unlocks naval port")

	var def_pct = float(bdef.get("defense_bonus_pct", 0.0))
	if absf(def_pct) > 0.0001:
		lines.append("Effect: +%d%% local defense" % int(round(def_pct * 100.0)))

	var state_mods = bdef.get("state_modifiers", {}) as Dictionary
	for key in state_mods.keys():
		var v = float(state_mods[key])
		if key == "recruit_cost_mult":
			lines.append("State: recruit cost %+.1f%%" % ((v - 1.0) * 100.0))
		elif key == "upkeep_mult":
			lines.append("State: upkeep %+.1f%%" % ((v - 1.0) * 100.0))
		elif key == "income_rate_mult":
			lines.append("State: income rate %+.1f%%" % ((v - 1.0) * 100.0))

	var prov_mods = bdef.get("province_modifiers", {}) as Dictionary
	for key in prov_mods.keys():
		var v = float(prov_mods[key])
		if key == "gdp_growth_mult":
			lines.append("Province: GDP growth %+.1f%%" % ((v - 1.0) * 100.0))
		elif key == "population_growth_mult":
			lines.append("Province: population growth %+.1f%%" % ((v - 1.0) * 100.0))
		elif key == "recruit_regen_mult":
			lines.append("Province: recruit regen %+.1f%%" % ((v - 1.0) * 100.0))
		elif key == "upkeep_mult":
			lines.append("Province: army upkeep %+.1f%%" % ((v - 1.0) * 100.0))

	lines.append("Max level: %d" % max(1, int(bdef.get("max_level", 1))))
	return "\n".join(lines)

func _obnov_stavba_popup_polozky() -> void:
	# Rebuild menu from live building defs so costs/effects always match current rules.
	# Pro male dite: znovu naplnime seznam budov, aby ukazoval spravne ceny.
	var popup_stavba = btn_stavet.get_popup()
	_stavba_popup = popup_stavba
	_stavba_menu_build_ids.clear()
	popup_stavba.clear()

	var ids: Array = []
	if GameManager.has_method("ziskej_dostupne_building_ids"):
		ids = GameManager.ziskej_dostupne_building_ids() as Array
	for building_any in ids:
		var building_id = str(building_any)
		var bdef = _ziskej_stavba_def(building_id)
		if bdef.is_empty():
			continue
		var name = str(bdef.get("name", building_id))
		var cost = max(0.0, float(bdef.get("cost", 0.0)))
		var item_id = _stavba_menu_build_ids.size()
		popup_stavba.add_item("%s (%dM)" % [name, int(round(cost))], item_id)
		popup_stavba.set_item_tooltip(item_id, _sestav_building_tooltip(building_id, bdef))
		_stavba_menu_build_ids.append(building_id)

# Runs the local feature logic.
func _limit_verbovani_v_okupaci(requested: int, prov_data: Dictionary) -> int:
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var core_owner = str(prov_data.get("core_owner", owner_tag)).strip_edges().to_upper()
	var je_okupace = owner_tag != "" and owner_tag != "SEA" and core_owner != "" and core_owner != owner_tag
	if not je_okupace:
		return max(0, requested)
	# Occupation allows only limited local recruitment each action.
	# This prevents unrealistic instant manpower from freshly occupied territory.
	return int(max(0, floor(float(requested) * 0.2)))

# Initializes references, connects signals, and prepares default runtime state.
func _ready():
	action_menu.hide()
	if info_panel:
		info_panel.clip_contents = true
	if action_menu:
		action_menu.clip_contents = true
	_setup_inline_delta_rows()
	_vytvor_preview_label()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)
	
	var popup_stavba = btn_stavet.get_popup()
	_obnov_stavba_popup_polozky()
	popup_stavba.id_pressed.connect(_on_stavba_vybrana)
	popup_stavba.about_to_popup.connect(_posun_stavba_menu)
	if popup_stavba.has_signal("popup_hide"):
		popup_stavba.popup_hide.connect(_on_stavba_menu_zavreno)
	if popup_stavba.has_signal("id_focused"):
		popup_stavba.id_focused.connect(_on_stavba_zvyraznena)

	if btn_presunout: btn_presunout.pressed.connect(_on_presunout_pressed)
	btn_verbovat.pressed.connect(_on_verbovat_pressed)
	if btn_likvidovat: btn_likvidovat.pressed.connect(_on_likvidovat_pressed)
	recruit_slider.value_changed.connect(_on_slider_zmenen)
	btn_potvrdit.pressed.connect(_on_potvrdit_verbovani)
	btn_zrusit.pressed.connect(func(): recruit_popup.hide(); _clear_preview_text())
	
	# --- NEW: PĹ™ipojenĂ­ tlaÄŤĂ­tek pro pĹ™esun ---
	if move_slider: move_slider.value_changed.connect(_on_move_slider_zmenen)
	if btn_move_potvrdit: btn_move_potvrdit.pressed.connect(_on_potvrdit_presun)
	if btn_move_zrusit: btn_move_zrusit.pressed.connect(func(): move_popup.hide())

	if likvidace_slider: likvidace_slider.value_changed.connect(_on_likvidace_slider_zmenen)
	if btn_likvidace_potvrdit: btn_likvidace_potvrdit.pressed.connect(_on_potvrdit_likvidaci)
	if btn_likvidace_zrusit: btn_likvidace_zrusit.pressed.connect(func(): likvidace_popup.hide())
	_nastav_tooltipy_ui()
	var viewport = get_viewport()
	if viewport and viewport.has_signal("size_changed") and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)
	call_deferred("_on_viewport_resized")

# Handles this signal callback.
func _on_viewport_resized() -> void:
	_aktualizuj_responzivni_layout()
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("obnov_layout_ui"):
		game_ui.obnov_layout_ui()

# Refreshes existing content to reflect current runtime values.
func obnov_layout_ui() -> void:
	_aktualizuj_responzivni_layout()
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("obnov_layout_ui"):
		game_ui.call_deferred("obnov_layout_ui")

# Pulls current state data.
func _ziskej_safe_bottom_inset() -> float:
	# Compensate taskbar overlap when window covers desktop working area.
	var viewport = get_viewport()
	if viewport == null:
		return 0.0
	var vp_h = maxf(1.0, viewport.get_visible_rect().size.y)
	var screen_idx = DisplayServer.window_get_current_screen()
	var usable = DisplayServer.screen_get_usable_rect(screen_idx)
	var win_pos = DisplayServer.window_get_position()
	var win_size = DisplayServer.window_get_size()
	var win_h = maxf(1.0, float(win_size.y))
	var window_bottom = int(win_pos.y + win_size.y)
	var usable_bottom = int(usable.position.y + usable.size.y)
	var overlap_px = max(0, window_bottom - usable_bottom)
	if overlap_px <= 0:
		return 0.0
	return float(overlap_px) * (vp_h / win_h)

# Refreshes cached/UI state.
func _aktualizuj_responzivni_layout() -> void:
	# Keep province panel and action panel pinned to bottom edge across resolutions.
	# Pro male dite: i kdyz zmenis velikost okna, panely zustanou pekne dole.
	if info_panel == null or action_menu == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return
	var vp_size = viewport.get_visible_rect().size
	var vp_w = maxf(320.0, vp_size.x)
	var vp_h = maxf(240.0, vp_size.y)
	var safe_bottom = _ziskej_safe_bottom_inset()
	var bottom_margin = INFO_UI_MARGIN + safe_bottom

	var panel_w = clampf(vp_w * 0.24, INFO_PANEL_MIN_W, INFO_PANEL_MAX_W)
	panel_w = minf(panel_w, vp_w - (INFO_UI_MARGIN * 2.0))

	info_panel.anchor_left = 0.0
	info_panel.anchor_right = 0.0
	info_panel.anchor_top = 1.0
	info_panel.anchor_bottom = 1.0
	info_panel.offset_left = INFO_UI_MARGIN
	info_panel.offset_right = INFO_UI_MARGIN + panel_w

	# Province info must stay glued to bottom edge.
	var panel_hard_max = minf(maxf(220.0, vp_h * 0.46), maxf(140.0, vp_h - 72.0 - bottom_margin))
	var panel_h = clampf(info_panel.size.y, 140.0, panel_hard_max)
	info_panel.offset_top = -panel_h - bottom_margin
	info_panel.offset_bottom = -bottom_margin

	var side_space = vp_w - (panel_w + INFO_UI_GAP + INFO_UI_MARGIN)
	var action_w = clampf(side_space, ACTION_MENU_MIN_W, ACTION_MENU_MAX_W)

	action_menu.anchor_left = 0.0
	action_menu.anchor_right = 0.0
	action_menu.anchor_top = 1.0
	action_menu.anchor_bottom = 1.0
	# Action panel must stay glued to bottom edge too.
	action_menu.offset_left = panel_w + INFO_UI_GAP
	action_menu.offset_right = action_menu.offset_left + action_w
	action_menu.offset_top = -bottom_margin - action_menu.size.y
	action_menu.offset_bottom = -bottom_margin

	# If there is not enough side space, keep panel glued to the right+bottom edge.
	if action_menu.offset_right > vp_w:
		action_w = clampf(vp_w * 0.48, 220.0, ACTION_MENU_MAX_W)
		action_menu.anchor_left = 1.0
		action_menu.anchor_right = 1.0
		action_menu.offset_right = -INFO_UI_MARGIN
		action_menu.offset_left = -INFO_UI_MARGIN - action_w
		action_menu.offset_top = -bottom_margin - action_menu.size.y
		action_menu.offset_bottom = -bottom_margin

	# Clamp action menu vertically only; horizontal edge anchoring is intentional.
	var min_bottom = -bottom_margin
	var max_top = -vp_h + 72.0
	if action_menu.offset_top < max_top:
		var delta_y = max_top - action_menu.offset_top
		action_menu.offset_top += delta_y
		action_menu.offset_bottom += delta_y
	if action_menu.offset_bottom > min_bottom:
		var delta_y2 = action_menu.offset_bottom - min_bottom
		action_menu.offset_top -= delta_y2
		action_menu.offset_bottom -= delta_y2

	# Compact button sizing on narrow layouts to avoid internal overlap.
	var compact = action_w < 430.0
	var tiny = action_w < 360.0
	var btn_w = 100.0
	var btn_h = 38.0
	var font_size = 15
	if compact:
		btn_w = 88.0
		btn_h = 36.0
		font_size = 14
	if tiny:
		btn_w = 74.0
		btn_h = 34.0
		font_size = 12
	for b in [btn_presunout, btn_verbovat, btn_stavet, btn_likvidovat]:
		if b == null:
			continue
		b.custom_minimum_size = Vector2(btn_w, btn_h)
		b.add_theme_font_size_override("font_size", font_size)

	if action_row:
		action_row.add_theme_constant_override("separation", 3 if tiny else 4)

# Main runtime logic lives here.
func _clamp_popup_rect_to_viewport(rect: Rect2i) -> Rect2i:
	var viewport = get_viewport()
	if viewport == null:
		return rect
	var vp = viewport.get_visible_rect().size
	var out = rect
	out.position.x = int(clampi(out.position.x, 4, int(maxf(4.0, vp.x - out.size.x - 4.0))))
	out.position.y = int(clampi(out.position.y, 4, int(maxf(4.0, vp.y - out.size.y - 4.0))))
	return out

# Applies updates and syncs dependent state.
func _nastav_tooltipy_ui() -> void:
	id_label.tooltip_text = "Name of the selected province."
	owner_label.tooltip_text = "Current owner of the province."
	terrain_label.tooltip_text = "Terrain type in this province."
	pop_label.tooltip_text = "Province population."
	recruit_label.tooltip_text = "Available recruits in this province."
	gdp_label.tooltip_text = "Economic strength of this province."
	income_label.tooltip_text = "Province income for the owner."
	soldiers_label.tooltip_text = "Number of soldiers or fleet units."
	btn_stavet.tooltip_text = "Build a structure in this province."
	btn_presunout.tooltip_text = "Plan troop movement to another province."
	btn_verbovat.tooltip_text = "Recruit new soldiers for money."
	btn_likvidovat.tooltip_text = "Disband troops in this province and refund part of the cost."
	recruit_info.tooltip_text = "How many soldiers can be recruited."
	recruit_slider.tooltip_text = "Set number of recruits."
	btn_potvrdit.tooltip_text = "Confirm recruitment."
	btn_zrusit.tooltip_text = "Close recruitment window without changes."
	move_count_label.tooltip_text = "How many soldiers will be moved."
	move_slider.tooltip_text = "Set soldier amount for movement."
	btn_move_potvrdit.tooltip_text = "Confirm army movement."
	btn_move_zrusit.tooltip_text = "Cancel army movement."
	likvidace_info.tooltip_text = "How many soldiers will be removed."
	likvidace_slider.tooltip_text = "Set number of soldiers to remove."
	btn_likvidace_potvrdit.tooltip_text = "Confirm partial army disband."
	btn_likvidace_zrusit.tooltip_text = "Close disband window without changes."
	TooltipUtils.apply_default_tooltips(self)

# Builds UI objects and default wiring.
func _vytvor_preview_label() -> void:
	if _preview_label and is_instance_valid(_preview_label):
		return
	var vbox = $PanelContainer/VBoxContainer
	vbox.clip_contents = true
	_preview_label = Label.new()
	_preview_label.name = "ActionPreviewLabel"
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.clip_text = true
	_preview_label.max_lines_visible = 4
	_preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_preview_label.visible = false
	vbox.add_child(_preview_label)

# Main runtime logic lives here.
func _wrap_metric_label(key: String, base_label: Label) -> void:
	if base_label == null:
		return
	var parent = base_label.get_parent()
	if parent == null:
		return
	if _metric_rows.has(key):
		return

	var idx = base_label.get_index()
	parent.remove_child(base_label)

	var row = HBoxContainer.new()
	row.name = "MetricRow_%s" % key
	row.size_flags_horizontal = Control.SIZE_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	parent.move_child(row, idx)

	# Keep the value label compact so delta text stays attached to the number.
	base_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(base_label)

	var delta = Label.new()
	delta.name = "Delta_%s" % key
	delta.visible = false
	row.add_child(delta)

	_metric_rows[key] = row
	_metric_deltas[key] = delta

# Runs the local feature logic.
func _setup_inline_delta_rows() -> void:
	_wrap_metric_label("pop", pop_label)
	_wrap_metric_label("recruit", recruit_label)
	_wrap_metric_label("gdp", gdp_label)
	_wrap_metric_label("income", income_label)
	_wrap_metric_label("soldiers", soldiers_label)

# Writes new values and refreshes related state.
func _set_metric_visible(key: String, metric_visible: bool) -> void:
	if _metric_rows.has(key):
		(_metric_rows[key] as Control).visible = metric_visible
	if not metric_visible:
		_set_metric_delta(key, "", Color.WHITE)

# Applies updates and syncs dependent state.
func _set_metric_delta(key: String, text: String, color: Color) -> void:
	if not _metric_deltas.has(key):
		return
	var lbl = _metric_deltas[key] as Label
	var clean = text.strip_edges()
	if clean == "":
		# Empty delta means hide preview suffix and keep row visually clean.
		# Pro male dite: kdyz neni zmena, schovame barevne +/-, at to neplete.
		lbl.visible = false
		lbl.text = ""
		return
	lbl.text = "(%s)" % clean
	lbl.add_theme_color_override("font_color", color)
	lbl.visible = true

# Wipes short-lived state.
func _clear_inline_deltas() -> void:
	for key in _metric_deltas.keys():
		_set_metric_delta(str(key), "", Color.WHITE)

# Writes new values and refreshes related state.
func _set_preview_text(text: String) -> void:
	if not _preview_label:
		return
	var clean = text.strip_edges()
	if clean == "":
		_preview_label.visible = false
		_preview_label.text = ""
		return
	_preview_label.text = "Preview: " + clean
	_preview_label.visible = true

# Runs the local feature logic.
func _push_overview_deltas(deltas: Dictionary) -> void:
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("nastav_akce_nahled_delta"):
		game_ui.nastav_akce_nahled_delta(deltas)

func _push_overview_ekonomicky_nahled(preview: Dictionary) -> void:
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("nastav_akce_nahled_ekonomiky"):
		game_ui.nastav_akce_nahled_ekonomiky(preview)

# Wipes short-lived state.
func _clear_preview_text() -> void:
	_set_preview_text("")
	_clear_inline_deltas()
	_push_overview_deltas({})
	_push_overview_ekonomicky_nahled({})
	_ideology_preview_active = false

# Writes new values and refreshes related state.
func nastav_nahled_ideologie(preview: Dictionary) -> void:
	if aktualni_provincie_id == -1:
		return
	if preview.is_empty() or not bool(preview.get("ok", false)):
		return

	var state_tag = str(preview.get("state", "")).strip_edges().to_upper()
	if state_tag == "":
		return

	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var d = province_data[aktualni_provincie_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	if owner_tag != state_tag:
		vycisti_nahled_ideologie()
		return

	var stat_changes = preview.get("stat_changes", {}) as Dictionary
	var modifiers = stat_changes.get("modifiers", {}) as Dictionary
	var gdp_ratio = float(modifiers.get("gdp_ratio", 1.0))
	var new_recruit_mult = float(modifiers.get("new_recruit_mult", 1.0))

	var old_gdp = float(d.get("gdp", 0.0))
	var new_gdp = max(0.0, old_gdp * gdp_ratio)
	var delta_gdp = new_gdp - old_gdp

	var old_cap = int(d.get("base_recruitable_population", d.get("recruitable_population", 0)))
	var old_recruit = int(d.get("recruitable_population", old_cap))
	old_recruit = clampi(old_recruit, 0, max(0, old_cap))
	var raw_base = int(d.get("base_recruitable_population_raw", old_cap))
	if raw_base < 0:
		raw_base = 0

	var fill_ratio = 0.0
	if old_cap > 0:
		fill_ratio = float(old_recruit) / float(old_cap)

	var new_cap = max(0, int(round(float(raw_base) * max(0.01, new_recruit_mult))))
	var new_recruit = clampi(int(round(float(new_cap) * fill_ratio)), 0, new_cap)
	var delta_recruit = new_recruit - old_recruit
	var recruit_delta_text = "+" + _formatuj_cislo(delta_recruit) if delta_recruit >= 0 else _formatuj_cislo(delta_recruit)

	_set_metric_delta("gdp", "%+.2f" % delta_gdp, Color(0.20, 0.85, 0.25) if delta_gdp >= 0.0 else Color(0.95, 0.35, 0.35))
	_set_metric_delta("recruit", recruit_delta_text, Color(0.20, 0.85, 0.25) if delta_recruit >= 0 else Color(0.95, 0.35, 0.35))
	_set_metric_delta("pop", "0", Color(0.75, 0.75, 0.75))
	_ideology_preview_active = true

# Cleanup for temporary values.
func vycisti_nahled_ideologie() -> void:
	if not _ideology_preview_active:
		return
	_set_metric_delta("gdp", "", Color.WHITE)
	_set_metric_delta("recruit", "", Color.WHITE)
	_set_metric_delta("pop", "", Color.WHITE)
	_ideology_preview_active = false

# Computes derived values from current inputs and game state.
func _spocitej_stat_hdp_a_vojaky(owner_tag: String, province_data: Dictionary) -> Dictionary:
	var hdp := 0.0
	var vojaci := 0
	var wanted = owner_tag.strip_edges().to_upper()
	for p_id in province_data:
		var d = province_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		hdp += float(d.get("gdp", 0.0))
		vojaci += int(d.get("soldiers", 0))
	return {"hdp": hdp, "vojaci": vojaci}

# Runs the local feature logic.
func _nahled_stavby_text(building_id: String, prov_data: Dictionary) -> String:
	_clear_inline_deltas()
	_push_overview_ekonomicky_nahled({})
	# preview se sklada z lokalnich i statnich metrik, at hrac vidi dopad pred klikem.
	var bdef = _ziskej_stavba_def(building_id)
	if bdef.is_empty():
		return "Unknown building."
	var cena = max(0.0, float(bdef.get("cost", 0.0)))
	var build_time = max(1, int(bdef.get("build_time", 3)))
	var bname = str(bdef.get("name", "Building"))
	var overview_deltas: Dictionary = {}
	# tenhle baseline je "pred stavbou", vsechny dalsi delty se pocitaji proti nemu.
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var province_data = _ziskej_provincie_data()
	var totals = _spocitej_stat_hdp_a_vojaky(owner_tag, province_data)
	var base_hdp = float(totals.get("hdp", 0.0))
	var base_vojaci = int(totals.get("vojaci", 0))
	var prijmova_sazba = _ziskej_prijmovou_sazbu_hdp()
	var upkeep_za_vojaka = _ziskej_udrzbu_za_vojaka()
	var base_income = (base_hdp * prijmova_sazba) - (float(base_vojaci) * upkeep_za_vojaka)
	var delta_income = 0.0
	var bonus_text = "%s" % bname

	if building_id == "econ_hub":
		delta_income = float(bdef.get("gdp_flat", 0.0)) * prijmova_sazba
		bonus_text = "%s: +%.2f GDP" % [bname, float(bdef.get("gdp_flat", 0.0))]
	elif building_id == "recruit_center":
		var recruit_cost_mult = float((bdef.get("state_modifiers", {}) as Dictionary).get("recruit_cost_mult", 1.0))
		var cost_now = _ziskej_cenu_za_vojaka()
		var cost_after = cost_now * max(0.01, recruit_cost_mult)
		bonus_text = "%s: recruit cost/soldier %s -> %s" % [bname, _format_money_auto(cost_now, 4), _format_money_auto(cost_after, 4)]
	elif building_id == "port":
		bonus_text = "%s: unlocks naval options" % bname
	elif building_id == "farm":
		bonus_text = "%s: growth boosts (GDP / population / recruit regen)" % bname
	elif building_id == "army_base":
		var upkeep_mult = float((bdef.get("province_modifiers", {}) as Dictionary).get("upkeep_mult", 1.0))
		var upkeep_now = _ziskej_udrzbu_za_vojaka()
		if GameManager.has_method("ziskej_udrzbu_za_vojaka_v_provincii") and aktualni_provincie_id != -1:
			upkeep_now = float(GameManager.ziskej_udrzbu_za_vojaka_v_provincii(GameManager.hrac_stat, aktualni_provincie_id))
		var upkeep_after = upkeep_now * max(0.01, upkeep_mult)
		bonus_text = "%s: local upkeep/soldier %s -> %s" % [bname, _format_money_auto(upkeep_now, 4), _format_money_auto(upkeep_after, 4)]
	elif building_id == "fortress":
		var def_pct = int(round(100.0 * float(bdef.get("defense_bonus_pct", 0.0))))
		bonus_text = "%s: +%d%% local defense" % [bname, def_pct]

	var income_after = base_income + delta_income
	var cash_after = GameManager.statni_kasa - cena
	if building_id == "econ_hub":
		var gdp_flat = float(bdef.get("gdp_flat", 0.0))
		_set_metric_delta("gdp", "%+.2f" % gdp_flat, Color(0.20, 0.85, 0.25))
		_set_metric_delta("income", "%+.2f / turn" % delta_income, Color(0.20, 0.85, 0.25))
		overview_deltas["gdp"] = {"text": "%+.2f" % gdp_flat, "color": Color(0.20, 0.85, 0.25)}
		_push_overview_deltas(overview_deltas)
		return "%s | Cost: %s | Funds after purchase: %s | Income after completion (%d turns): %s (Delta %s)" % [bonus_text, _format_money_auto(cena, 2), _format_money_auto(cash_after, 2), build_time, _format_money_auto(income_after, 2, false, true), _format_money_auto(delta_income, 2, true, true)]
	if building_id == "recruit_center":
		var recruit_cost_mult = float((bdef.get("state_modifiers", {}) as Dictionary).get("recruit_cost_mult", 1.0))
		var old_cost = _ziskej_cenu_za_vojaka()
		var new_cost = old_cost * max(0.01, recruit_cost_mult)
		var cost_delta = new_cost - old_cost
		var cost_delta_color = Color(0.20, 0.85, 0.25) if cost_delta <= 0.0 else Color(0.95, 0.35, 0.35)
		_set_metric_delta("income", "cost/soldier: %s -> %s" % [_format_money_auto(old_cost, 4), _format_money_auto(new_cost, 4)], cost_delta_color)
		_push_overview_ekonomicky_nahled({
			"recruit_cost_after": new_cost
		})
		overview_deltas["recruit"] = {
			"text": "cost/soldier %s" % _format_money_auto(cost_delta, 4, true, false),
			"color": cost_delta_color
		}
	if building_id == "port":
		_set_metric_delta("income", "0.00", Color(0.75, 0.75, 0.75))
		overview_deltas["gdp"] = {"text": "0.00", "color": Color(0.75, 0.75, 0.75)}
	if building_id == "farm":
		_set_metric_delta("income", "growth +", Color(0.20, 0.85, 0.25))
		# farm preview tahame z ideology profilu, jinak by to ukazovalo random cisla.
		if GameManager.has_method("ziskej_ideologicky_ekonomicky_profil"):
			var ideol = str(prov_data.get("ideology", ""))
			var econ_profile = GameManager.ziskej_ideologicky_ekonomicky_profil(ideol) as Dictionary
			if not econ_profile.is_empty():
				var prov_mods = bdef.get("province_modifiers", {}) as Dictionary
				var gdp_mult = max(0.01, float(prov_mods.get("gdp_growth_mult", 1.0)))
				var pop_mult = max(0.01, float(prov_mods.get("population_growth_mult", 1.0)))
				var reg_mult = max(0.01, float(prov_mods.get("recruit_regen_mult", 1.0)))
				var gdp_growth_base = float(econ_profile.get("gdp_growth_per_turn", 0.0))
				var pop_growth_base_pct = float(econ_profile.get("population_growth_ratio", 0.0)) * 100.0
				var reg_core_base_pct = float(econ_profile.get("recruit_regen_ratio_core", 0.0)) * 100.0
				var reg_occ_base_pct = float(econ_profile.get("recruit_regen_ratio_occupied", 0.0)) * 100.0
				_push_overview_ekonomicky_nahled({
					"gdp_growth_after": gdp_growth_base * gdp_mult,
					"population_growth_pct_after": pop_growth_base_pct * pop_mult,
					"recruit_regen_core_pct_after": reg_core_base_pct * reg_mult,
					"recruit_regen_occ_pct_after": reg_occ_base_pct * reg_mult
				})
	if building_id == "army_base":
		# upkeep je lokalni vec, proto berem provincial variantu kdyz je dostupna.
		var upkeep_mult = float((bdef.get("province_modifiers", {}) as Dictionary).get("upkeep_mult", 1.0))
		var old_upkeep = _ziskej_udrzbu_za_vojaka()
		if GameManager.has_method("ziskej_udrzbu_za_vojaka_v_provincii") and aktualni_provincie_id != -1:
			old_upkeep = float(GameManager.ziskej_udrzbu_za_vojaka_v_provincii(GameManager.hrac_stat, aktualni_provincie_id))
		var new_upkeep = old_upkeep * max(0.01, upkeep_mult)
		var upkeep_delta = new_upkeep - old_upkeep
		var upkeep_delta_color = Color(0.20, 0.85, 0.25) if upkeep_delta <= 0.0 else Color(0.95, 0.35, 0.35)
		_set_metric_delta("income", "upkeep/soldier: %s -> %s" % [_format_money_auto(old_upkeep, 4), _format_money_auto(new_upkeep, 4)], upkeep_delta_color)
		_push_overview_ekonomicky_nahled({
			"upkeep_per_soldier_after": new_upkeep
		})
		overview_deltas["army"] = {
			"text": "upkeep/soldier %s" % _format_money_auto(upkeep_delta, 4, true, false),
			"color": upkeep_delta_color
		}
	if building_id == "fortress":
		_set_metric_delta("soldiers", "defense +", Color(0.20, 0.85, 0.25))
	_push_overview_deltas(overview_deltas)
	return "%s | Cost: %s | Funds after purchase: %s | Completion time: %d turns" % [bonus_text, _format_money_auto(cena, 2), _format_money_auto(cash_after, 2), build_time]

# Feature logic entry point.
func _nahled_verbovani_text(pocet: int) -> String:
	_clear_inline_deltas()
	_push_overview_ekonomicky_nahled({})
	# recruit preview je schvalne konzervativni: ukazuje okamzite naklady + upkeep dopad.
	var upkeep_per_soldier = _ziskej_udrzbu_za_vojaka()
	if GameManager.has_method("ziskej_udrzbu_za_vojaka_v_provincii") and aktualni_provincie_id != -1:
		upkeep_per_soldier = float(GameManager.ziskej_udrzbu_za_vojaka_v_provincii(GameManager.hrac_stat, aktualni_provincie_id))
	var upkeep_delta = -float(pocet) * upkeep_per_soldier
	var projected_income = float(GameManager.celkovy_prijem) + upkeep_delta
	var cena = float(pocet) * _ziskej_cenu_za_vojaka()
	var cash_after = GameManager.statni_kasa - cena
	_set_metric_delta("soldiers", "+%s" % _formatuj_cislo(pocet), Color(0.20, 0.85, 0.25))
	_set_metric_delta("recruit", "-%s" % _formatuj_cislo(pocet), Color(0.95, 0.35, 0.35))
	_set_metric_delta("income", "%+.2f / turn" % upkeep_delta, Color(0.95, 0.35, 0.35))
	_push_overview_deltas({
		"recruit": {"text": "-%s" % _formatuj_cislo(pocet), "color": Color(0.95, 0.35, 0.35)},
		"gdp": {"text": "%+.2f / turn" % upkeep_delta, "color": Color(0.95, 0.35, 0.35)}
	})
	return "Recruitment: %s soldiers | Cost: %s | Funds after purchase: %s | Upkeep: %s | New net income: %s" % [_formatuj_cislo(pocet), _format_money_auto(cena, 2), _format_money_auto(cash_after, 2), _format_money_auto(upkeep_delta, 2, true, true), _format_money_auto(projected_income, 2, false, true)]

# Runs the local feature logic.
func _posun_stavba_menu():
	var p = btn_stavet.get_popup()
	# pred otevrenim menu znovu prepocitame disabled stavy i tooltipy (muze se to menit po tahu).
	for idx in range(p.item_count):
		var build_id = _ziskej_stavba_menu_building_id(int(p.get_item_id(idx)))
		var bdef = _ziskej_stavba_def(build_id)
		var base_tip = _sestav_building_tooltip(build_id, bdef)
		var can_build = GameManager.muze_postavit_budovu(aktualni_provincie_id, build_id) if GameManager.has_method("muze_postavit_budovu") else {"ok": true}
		p.set_item_disabled(idx, not bool(can_build.get("ok", false)))
		if not bool(can_build.get("ok", false)):
			var reason = str(can_build.get("reason", "Unavailable right now."))
			p.set_item_tooltip(idx, "%s\n\nStatus: %s" % [base_tip, reason])
		else:
			p.set_item_tooltip(idx, base_tip)
	var viewport = get_viewport()
	if viewport:
		var vp = viewport.get_visible_rect().size
		p.position.x = int(clampi(int(btn_stavet.global_position.x), 4, int(maxf(4.0, vp.x - p.size.x - 4.0))))
		p.position.y = int(clampi(int(btn_stavet.global_position.y - p.size.y - 5), 4, int(maxf(4.0, vp.y - p.size.y - 4.0))))
	else:
		p.position.y = btn_stavet.global_position.y - p.size.y - 5
	_stavba_last_focus_idx = -2
	set_process(true)

# Handles this signal callback.
func _on_stavba_zvyraznena(id: int) -> void:
	_nastav_nahled_stavby_podle_id(id)

# Writes new values and refreshes related state.
func _nastav_nahled_stavby_podle_id(id: int) -> void:
	if aktualni_provincie_id == -1:
		return
	var building_id = _ziskej_stavba_menu_building_id(id)
	if building_id == "":
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	_nahled_stavby_text(building_id, province_data[aktualni_provincie_id])

# Triggered by a UI/game signal.
func _on_stavba_menu_zavreno() -> void:
	_stavba_last_focus_idx = -2
	set_process(false)
	_clear_preview_text()

# Continuous update loop.
func _process(_delta: float) -> void:
	# Fallback hover tracking for PopupMenu (works even when id_focused is unreliable).
	if _stavba_popup == null or not is_instance_valid(_stavba_popup):
		set_process(false)
		return
	if not _stavba_popup.visible:
		set_process(false)
		return
	if not _stavba_popup.has_method("get_focused_item"):
		return

	var idx = int(_stavba_popup.get_focused_item())
	if idx == _stavba_last_focus_idx:
		return
	_stavba_last_focus_idx = idx
	if idx < 0:
		return
	if idx >= _stavba_popup.item_count:
		return

	_nastav_nahled_stavby_podle_id(int(_stavba_popup.get_item_id(idx)))

# Hides UI/output and resets related temporary state.
func schovej_se():
	$PanelContainer.hide()
	action_menu.hide()
	recruit_popup.hide()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	aktualni_provincie_id = -1
	hromadny_vyber_ids.clear()
	je_hromadny_rezim = false
	je_hromadne_verbovani = false
	je_hromadne_likvidovani = false
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader and map_loader.has_method("vycisti_hromadny_vyber_provincii"):
		map_loader.vycisti_hromadny_vyber_provincii()
	_clear_preview_text()
	call_deferred("obnov_layout_ui")

# Updates what the player sees.
func zobraz_data(data: Dictionary):
	if data.is_empty():
		schovej_se()
		return
	
	$PanelContainer.show()
	je_hromadny_rezim = false
	je_hromadne_verbovani = false
	je_hromadne_likvidovani = false
	hromadny_vyber_ids.clear()
	recruit_popup.hide() 
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	aktualni_provincie_id = data.get("id", -1)
	
	var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(data.get("army_owner", "")).strip_edges().to_upper()
	var core_owner = str(data.get("core_owner", owner_tag)).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_sousi = (not je_more and armada_owner == GameManager.hrac_stat and int(data.get("soldiers", 0)) > 0)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat and int(data.get("soldiers", 0)) > 0)
	var vojaci = int(data.get("soldiers", 0))
	var ma_pristav = bool(data.get("has_port", false))
	
	var province_name = str(data.get("province_name", "Neznamo"))
	id_label.text = "Province: %s - PORT" % province_name if (not je_more and ma_pristav) else "Province: " + province_name
	if je_more and armada_owner != "":
		owner_label.text = "Owner: SEA (naval army: %s)" % armada_owner
	elif core_owner != "" and core_owner != owner_tag:
		owner_label.text = "Owner: %s (occupation, core: %s)" % [owner_tag, core_owner]
	else:
		owner_label.text = "Owner: " + owner_tag

	terrain_label.visible = true
	var terrain_raw = str(data.get("terrain", "")).strip_edges()
	if terrain_raw == "":
		terrain_raw = "unknown"
	var terrain_def_bonus = _ziskej_terenni_obranny_bonus_pro_data(data, terrain_raw)
	terrain_label.text = "Terrain: %s (defense %s)" % [terrain_raw, _format_pct_signed(terrain_def_bonus)]
	
	if je_more:
		_set_metric_visible("pop", false)
		_set_metric_visible("recruit", false)
		_set_metric_visible("gdp", false)
		_set_metric_visible("income", false)
		if vojaci > 0:
			_set_metric_visible("soldiers", true)
			if armada_owner != "":
				soldiers_label.text = "Fleet (%s): %s men" % [armada_owner, _formatuj_cislo(vojaci)]
			else:
				soldiers_label.text = "Fleet: " + _formatuj_cislo(vojaci) + " men"
		else:
			_set_metric_visible("soldiers", false)
	else:
		_set_metric_visible("pop", true)
		_set_metric_visible("recruit", true)
		_set_metric_visible("gdp", true)
		_set_metric_visible("soldiers", true)
		
		var pop = int(data.get("population", 0))
		pop_label.text = "Population: " + _formatuj_cislo(pop)
		
		var rekruti = int(data.get("recruitable_population", 0))
		recruit_label.text = "Recruits: " + _formatuj_cislo(rekruti)
		
		var gdp = float(data.get("gdp", 0.0))
		gdp_label.text = "GDP: %.2f bn USD" % gdp
		
		soldiers_label.text = "Army: " + _formatuj_cislo(vojaci) + " men"
		
		if je_moje:
			_set_metric_visible("income", true)
			income_label.text = "Income: +%s USD" % _format_money_auto(gdp * 0.05, 2)
		else:
			_set_metric_visible("income", false)

	if (je_moje and not je_more) or je_moje_armada_na_sousi or je_moje_armada_na_mori:
		var muze_stavet = (je_moje and not je_more)
		var ma_armadu = (vojaci > 0 and (je_moje or je_moje_armada_na_sousi or je_moje_armada_na_mori))
		btn_stavet.visible = muze_stavet
		btn_verbovat.visible = muze_stavet
		btn_likvidovat.visible = ma_armadu

		if not muze_stavet:
			btn_stavet.disabled = true
			btn_stavet.text = "Build"
			btn_verbovat.disabled = true
			btn_likvidovat.disabled = not ma_armadu

		if muze_stavet:
			if GameManager.provincie_cooldowny.has(aktualni_provincie_id):
				var zbyva_kol = GameManager.provincie_cooldowny[aktualni_provincie_id]["zbyva"]
				btn_stavet.disabled = true
				btn_stavet.text = "Building (%d turns)" % zbyva_kol
			else:
				btn_stavet.disabled = false
				btn_stavet.text = "Build"
			
		if btn_presunout:
			btn_presunout.visible = (vojaci > 0)
			btn_presunout.disabled = not ma_armadu
			
		if muze_stavet:
			btn_verbovat.disabled = false
		btn_likvidovat.disabled = not ma_armadu
		action_menu.show()
	else:
		action_menu.hide()
		_clear_preview_text()
	call_deferred("obnov_layout_ui")

# Callback for UI/game events.
func _on_likvidovat_pressed():
	if je_hromadny_rezim:
		_otevri_hromadne_likvidovani()
		return
	if aktualni_provincie_id == -1:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var prov_data = province_data[aktualni_provincie_id]
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(prov_data.get("army_owner", "")).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_sousi = (not je_more and armada_owner == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat)

	if not je_moje and not je_moje_armada_na_sousi and not je_moje_armada_na_mori:
		return

	var pocet_vojaku = int(prov_data.get("soldiers", 0))
	if pocet_vojaku <= 0:
		return

	likvidace_slider.min_value = 1
	likvidace_slider.max_value = pocet_vojaku
	likvidace_slider.value = pocet_vojaku
	_on_likvidace_slider_zmenen(float(pocet_vojaku))

	var rect = Rect2i()
	rect.position = Vector2i(btn_likvidovat.global_position.x, btn_likvidovat.global_position.y - likvidace_popup.size.y - 5)
	rect.size = likvidace_popup.size
	rect = _clamp_popup_rect_to_viewport(rect)
	likvidace_popup.popup(rect)

# Triggered by a UI/game signal.
func _on_likvidace_slider_zmenen(hodnota: float):
	if not likvidace_info:
		return
	var pocet = int(hodnota)
	var refundace = float(pocet) * likvidace_vynos_za_vojaka
	if je_hromadne_likvidovani:
		likvidace_info.text = "Disband all: %s soldiers\nRefund: +%s" % [_formatuj_cislo(pocet), _format_money_auto(refundace, 2)]
	else:
		likvidace_info.text = "Disband: %s soldiers\nRefund: +%s" % [_formatuj_cislo(pocet), _format_money_auto(refundace, 2)]
	if btn_likvidace_potvrdit:
		btn_likvidace_potvrdit.disabled = (pocet <= 0)

# Triggered by a UI/game signal.
func _on_potvrdit_likvidaci():
	if je_hromadne_likvidovani:
		_potvrd_hromadne_likvidovani()
		return
	if aktualni_provincie_id == -1:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var prov_data = province_data[aktualni_provincie_id]
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(prov_data.get("army_owner", "")).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_sousi = (not je_more and armada_owner == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat)

	if not je_moje and not je_moje_armada_na_sousi and not je_moje_armada_na_mori:
		likvidace_popup.hide()
		return

	var dostupni_vojaci = int(prov_data.get("soldiers", 0))
	var pocet_vojaku = clampi(int(likvidace_slider.value), 1, dostupni_vojaci)
	if dostupni_vojaci <= 0 or pocet_vojaku <= 0:
		likvidace_popup.hide()
		return

	var refundace = float(pocet_vojaku) * likvidace_vynos_za_vojaka
	GameManager.statni_kasa += refundace
	prov_data["soldiers"] = max(0, dostupni_vojaci - pocet_vojaku)

	if je_more and int(prov_data.get("soldiers", 0)) <= 0:
		prov_data["army_owner"] = ""
	elif not je_more:
		prov_data["army_owner"] = GameManager.hrac_stat
		prov_data["recruitable_population"] = int(prov_data.get("recruitable_population", 0)) + pocet_vojaku

	likvidace_popup.hide()
	_ukaz_stavbu_info("ARMY DISBAND", "Disbanded %s soldiers. %s USD was returned to state funds." % [_formatuj_cislo(pocet_vojaku), _format_money_auto(refundace, 2)])
	zobraz_data(prov_data)
	GameManager.kolo_zmeneno.emit()

# Event handler for user or game actions.
func _on_presunout_pressed():
	if je_hromadny_rezim:
		if hromadny_vyber_ids.is_empty():
			return
		var map_loader_bulk = get_tree().current_scene.find_child("Map", true, false)
		if not map_loader_bulk and get_parent().has_method("aktivuj_rezim_hromadneho_presunu"):
			map_loader_bulk = get_parent()
		if map_loader_bulk and map_loader_bulk.has_method("aktivuj_rezim_hromadneho_presunu"):
			if map_loader_bulk.aktivuj_rezim_hromadneho_presunu(hromadny_vyber_ids):
				schovej_se()
		return

	if aktualni_provincie_id == -1: return
	
	var province_data = _ziskej_provincie_data()
	var prov_data = province_data.get(aktualni_provincie_id, {})
	var dostupni_vojaci = int(prov_data.get("soldiers", 0))
	if dostupni_vojaci <= 0: return
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("aktivuj_rezim_vyberu_cile"):
		map_loader = get_parent()
			
	if map_loader and map_loader.has_method("aktivuj_rezim_vyberu_cile"):
		map_loader.aktivuj_rezim_vyberu_cile(aktualni_provincie_id, dostupni_vojaci)
		
	schovej_se()

# --- NEW: ZobrazĂ­ slider po ĂşspÄ›ĹˇnĂ©m kliknutĂ­ na souseda v mapÄ› ---
# Updates what the player sees.
func zobraz_presun_slider(from_id: int, to_id: int, max_troops: int, path: Array = []):
	presun_od_id = from_id
	presun_do_id = to_id
	presun_path = path.duplicate()
	
	move_slider.min_value = 1
	move_slider.max_value = max_troops
	move_slider.value = max_troops
	
	_on_move_slider_zmenen(max_troops)
	
	# ZobrazĂ­me popup (pokud je to PopupPanel, pouĹľije popup_centered)
	if move_popup is Popup:
		move_popup.popup_centered()
	else:
		move_popup.show()

# Reacts to incoming events.
func _on_move_slider_zmenen(hodnota: float):
	if move_count_label:
		move_count_label.text = _formatuj_cislo(int(hodnota)) + " soldiers"

# Triggered by a UI/game signal.
func _on_potvrdit_presun():
	var amount = int(move_slider.value)
	move_popup.hide()
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("zaregistruj_presun_armady"):
		map_loader = get_parent()
		
	if map_loader and map_loader.has_method("zaregistruj_presun_armady"):
		map_loader.zaregistruj_presun_armady(presun_od_id, presun_do_id, amount, true, presun_path)
# ------------------------------------------------------------------

# Handles this signal callback.
func _on_stavba_vybrana(id: int):
	var building_id = _ziskej_stavba_menu_building_id(id)
	if building_id == "":
		return

	if je_hromadny_rezim:
		_postav_hromadne(building_id)
		return

	if aktualni_provincie_id == -1: return

	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	var preview_text = _nahled_stavby_text(building_id, province_data[aktualni_provincie_id])
	# nejdriv ukazeme preview, az pak teprve sahame na backend akci.
	_set_preview_text(preview_text)

	if not GameManager.has_method("rozpocni_stavbu_pro_hrace"):
		_ukaz_stavbu_info("CONSTRUCTION", "Construction backend is unavailable.")
		_clear_preview_text()
		return

	var result = GameManager.rozpocni_stavbu_pro_hrace(aktualni_provincie_id, building_id) as Dictionary
	if bool(result.get("ok", false)):
		# UI lock tlacitka je dulezitej, jinak by slo spamnout vic staveb v jedny provincii.
		var turns = max(1, int(result.get("build_time", 3)))
		btn_stavet.disabled = true
		btn_stavet.text = "Building (%d turns)" % turns
		_ukaz_stavbu_info("CONSTRUCTION STARTED", preview_text)
		_clear_preview_text()
		GameManager.kolo_zmeneno.emit()
		return

	var reason = str(result.get("reason", "Construction failed."))
	_ukaz_stavbu_info("CONSTRUCTION", reason)
	_clear_preview_text()

# Main runtime logic lives here.
func _ukaz_stavbu_info(title: String, text: String):
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("_ukaz_bitevni_popup"):
		map_loader = get_parent()

	if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
		map_loader._ukaz_bitevni_popup(title, text)

# Triggered by a UI/game signal.
func _on_verbovat_pressed():
	if je_hromadny_rezim:
		_otevri_hromadne_verbovani()
		return

	if aktualni_provincie_id == -1: return
	
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	var prov_data = province_data[aktualni_provincie_id]
	var dostupni_rekruti = int(prov_data.get("recruitable_population", 0))
	dostupni_rekruti = _limit_verbovani_v_okupaci(dostupni_rekruti, prov_data)
	var max_za_penize = int(GameManager.statni_kasa / _ziskej_cenu_za_vojaka())
	var max_mozno = min(dostupni_rekruti, max_za_penize)
	
	if max_mozno <= 0: return
		
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = 0
	_on_slider_zmenen(0) 
	
	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	rect = _clamp_popup_rect_to_viewport(rect)
	recruit_popup.popup(rect)

# Reacts to incoming events.
func _on_slider_zmenen(hodnota: float):
	var cena = hodnota * _ziskej_cenu_za_vojaka()
	# slider callback drzi info text + mini preview stale v syncu.
	if je_hromadne_verbovani:
		recruit_info.text = "Bulk: %d men\nCost: %s" % [int(hodnota), _format_money_auto(cena, 2)]
	else:
		recruit_info.text = "Men: %d\nCost: %s" % [int(hodnota), _format_money_auto(cena, 2)]
	if hodnota > 0:
		_nahled_verbovani_text(int(hodnota))
	else:
		_clear_inline_deltas()
		_push_overview_deltas({})
	btn_potvrdit.disabled = (hodnota == 0)

# Event handler for user or game actions.
func _on_potvrdit_verbovani():
	if je_hromadne_verbovani:
		_potvrd_hromadne_verbovani()
		return

	var pocet_vojaku = int(recruit_slider.value)
	var celkova_cena = pocet_vojaku * _ziskej_cenu_za_vojaka()
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		recruit_popup.hide()
		return
	var prov_data = province_data[aktualni_provincie_id]
	# okupace ma vlastni cap; tady to znovu kontrolujem kvuli bezpecnosti.
	var max_okupace = _limit_verbovani_v_okupaci(int(prov_data.get("recruitable_population", 0)), prov_data)
	if max_okupace <= 0:
		recruit_popup.hide()
		_clear_preview_text()
		_ukaz_stavbu_info("RECRUITMENT", "Recruitment in occupied territory is currently heavily limited.")
		return
	pocet_vojaku = min(pocet_vojaku, max_okupace)
	celkova_cena = pocet_vojaku * _ziskej_cenu_za_vojaka()
	
	GameManager.statni_kasa -= celkova_cena
	prov_data["recruitable_population"] -= pocet_vojaku
	
	if not prov_data.has("soldiers"): prov_data["soldiers"] = 0
	prov_data["soldiers"] += pocet_vojaku
	
	recruit_popup.hide()
	_clear_preview_text()
	zobraz_data(prov_data) 
	GameManager.kolo_zmeneno.emit()

# Triggered by a UI/game signal.
func _on_kolo_zmeneno():
	if je_hromadny_rezim:
		var map_loader = get_tree().current_scene.find_child("Map", true, false)
		if map_loader and map_loader.has_method("ziskej_hromadne_vybrane_provincie"):
			var ids = map_loader.ziskej_hromadne_vybrane_provincie()
			if ids.size() > 1:
				zobraz_hromadna_data(ids, GameManager.map_data)
				return
		return

	if aktualni_provincie_id == -1:
		return
	if not $PanelContainer.visible:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	zobraz_data(province_data[aktualni_provincie_id])

# Formats values for display.
func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0: vysledek += " "
		vysledek += text_cisla[i]
	return vysledek

# Formats values for display.
func _format_money_auto(value: float, mil_decimals: int = 2, signed: bool = false, per_turn: bool = false) -> String:
	if absf(value) < 0.01:
		var tis_decimals = max(1, mil_decimals - 1)
		var fmt_tis = "%" + ("+" if signed else "") + "." + str(tis_decimals) + "f"
		var txt_tis = fmt_tis % (value * 1000.0)
		return txt_tis + "k" + ("/turn" if per_turn else "")
	var fmt_mil = "%" + ("+" if signed else "") + "." + str(mil_decimals) + "f"
	var txt_mil = fmt_mil % value
	return txt_mil + "M" + ("/turn" if per_turn else "")

# Applies visual/UI updates.
func zobraz_hromadna_data(ids: Array, all_provinces: Dictionary):
	if ids.size() <= 1:
		if ids.size() == 1 and all_provinces.has(int(ids[0])):
			zobraz_data(all_provinces[int(ids[0])])
		else:
			schovej_se()
		return

	je_hromadny_rezim = true
	je_hromadne_verbovani = false
	je_hromadne_likvidovani = false
	hromadny_vyber_ids = ids.duplicate()
	$PanelContainer.show()
	action_menu.show()
	recruit_popup.hide()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()

	var vlastni_pozemni: Array = []
	var vlastni_s_armadou: Array = []
	var total_pop := 0
	var total_recruits := 0
	var total_gdp := 0.0
	var total_soldiers := 0
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not all_provinces.has(pid):
			continue
		var d = all_provinces[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var je_more = (owner_tag == "SEA")
		if owner_tag == GameManager.hrac_stat and not je_more:
			vlastni_pozemni.append(pid)
			total_pop += int(d.get("population", 0))
			total_recruits += int(d.get("recruitable_population", 0))
			total_gdp += float(d.get("gdp", 0.0))
		var army_owner = str(d.get("army_owner", "")).strip_edges().to_upper()
		var moje_more_armada = (je_more and army_owner == GameManager.hrac_stat)
		var moje_pozemni_armada = (not je_more and army_owner == GameManager.hrac_stat and int(d.get("soldiers", 0)) > 0)
		if (owner_tag == GameManager.hrac_stat and int(d.get("soldiers", 0)) > 0) or moje_more_armada or moje_pozemni_armada:
			vlastni_s_armadou.append(pid)
			total_soldiers += int(d.get("soldiers", 0))

	id_label.text = "Bulk selection: %d provinces" % hromadny_vyber_ids.size()
	owner_label.text = "Actions for country: %s" % GameManager.hrac_stat
	terrain_label.visible = false
	_set_metric_visible("pop", true)
	_set_metric_visible("recruit", true)
	_set_metric_visible("gdp", true)
	_set_metric_visible("income", false)
	_set_metric_visible("soldiers", true)
	pop_label.text = "Total population: %s" % _formatuj_cislo(total_pop)
	recruit_label.text = "Total recruits: %s" % _formatuj_cislo(total_recruits)
	gdp_label.text = "Total GDP: %.2f bn USD" % total_gdp
	soldiers_label.text = "Total soldiers: %s" % _formatuj_cislo(total_soldiers)

	btn_likvidovat.show()
	btn_likvidovat.disabled = vlastni_s_armadou.is_empty()
	btn_stavet.show()
	btn_verbovat.show()
	btn_presunout.show()
	btn_stavet.disabled = vlastni_pozemni.is_empty()
	btn_verbovat.disabled = vlastni_pozemni.is_empty()
	btn_presunout.disabled = vlastni_s_armadou.is_empty()
	btn_stavet.text = "Build"
	call_deferred("obnov_layout_ui")

# Reads values from active state.
func _ziskej_hromadne_vlastni_pozemni() -> Array:
	var out: Array = []
	var province_data = _ziskej_provincie_data()
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		if owner_tag == GameManager.hrac_stat and owner_tag != "SEA":
			out.append(pid)
	return out

# Pulls current state data.
func _ziskej_hromadne_zdroje_s_armadou() -> Array:
	var out: Array = []
	var province_data = _ziskej_provincie_data()
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var army_owner = str(d.get("army_owner", "")).strip_edges().to_upper()
		if int(d.get("soldiers", 0)) <= 0:
			continue
		if owner_tag == GameManager.hrac_stat or army_owner == GameManager.hrac_stat:
			out.append(pid)
	return out

# Opens a UI flow/panel and prepares its data and position.
func _otevri_hromadne_verbovani():
	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	if pozemni.is_empty():
		_ukaz_stavbu_info("BULK RECRUITMENT", "No owned land province is selected.")
		return

	var total_recruits := 0
	var province_data = _ziskej_provincie_data()
	for pid in pozemni:
		if not province_data.has(pid):
			continue
		total_recruits += _limit_verbovani_v_okupaci(int(province_data[pid].get("recruitable_population", 0)), province_data[pid])
	var max_za_penize = int(GameManager.statni_kasa / _ziskej_cenu_za_vojaka())
	var max_mozno = min(total_recruits, max_za_penize)
	if max_mozno <= 0:
		if total_recruits <= 0:
			_ukaz_stavbu_info("BULK RECRUITMENT", "Selected provinces have no available recruits.")
		else:
			_ukaz_stavbu_info("BULK RECRUITMENT", "Not enough money for bulk recruitment.")
		return

	je_hromadne_verbovani = true
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = max_mozno
	_on_slider_zmenen(max_mozno)

	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	rect = _clamp_popup_rect_to_viewport(rect)
	recruit_popup.popup(rect)

# Validates and confirms an action, then commits the result.
func _potvrd_hromadne_verbovani():
	var total_to_recruit = int(recruit_slider.value)
	if total_to_recruit <= 0:
		recruit_popup.hide()
		return

	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	var province_data = _ziskej_provincie_data()

	# First pass: collect valid provinces and their per-cap.
	var valid_pids: Array = []
	var caps: Array = []
	var total_cap := 0
	for pid in pozemni:
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var cap = _limit_verbovani_v_okupaci(int(d.get("recruitable_population", 0)), d)
		if cap > 0:
			valid_pids.append(pid)
			caps.append(cap)
			total_cap += cap

	if total_cap <= 0:
		_ukaz_stavbu_info("BULK RECRUITMENT", "Selected provinces have no available recruits.")
		recruit_popup.hide()
		return

	# Second pass: strict equal split (floor) across all valid provinces.
	# Example: 1000 over 3 provinces => 333, 333, 333 (remainder 1 is intentionally not used).
	var total_recruited := 0
	var per_province = int(floor(float(total_to_recruit) / float(valid_pids.size())))
	for i in range(valid_pids.size()):
		var pid = valid_pids[i]
		var d = province_data[pid]
		var share = clampi(per_province, 0, caps[i])
		if share <= 0:
			continue
		d["recruitable_population"] = int(d.get("recruitable_population", 0)) - share
		d["soldiers"] = int(d.get("soldiers", 0)) + share
		total_recruited += share

	if total_recruited > 0:
		GameManager.statni_kasa -= float(total_recruited) * _ziskej_cenu_za_vojaka()
	else:
		_ukaz_stavbu_info("BULK RECRUITMENT", "Recruitment was not performed (0 soldiers recruited).")

	je_hromadne_verbovani = false
	recruit_popup.hide()
	_clear_preview_text()
	GameManager.kolo_zmeneno.emit()

# Opens bulk-disband popup for all selected provinces with armies.
func _otevri_hromadne_likvidovani():
	var s_armadou = _ziskej_hromadne_zdroje_s_armadou()
	if s_armadou.is_empty():
		_ukaz_stavbu_info("BULK DISBAND", "No selected province has troops to disband.")
		return

	var total_soldiers := 0
	var province_data = _ziskej_provincie_data()
	for pid in s_armadou:
		if province_data.has(pid):
			total_soldiers += int(province_data[pid].get("soldiers", 0))

	if total_soldiers <= 0:
		_ukaz_stavbu_info("BULK DISBAND", "No troops available in selected provinces.")
		return

	je_hromadne_likvidovani = true
	likvidace_slider.visible = false
	likvidace_slider.min_value = total_soldiers
	likvidace_slider.max_value = total_soldiers
	likvidace_slider.value = total_soldiers
	_on_likvidace_slider_zmenen(float(total_soldiers))

	var rect = Rect2i()
	rect.position = Vector2i(btn_likvidovat.global_position.x, btn_likvidovat.global_position.y - likvidace_popup.size.y - 5)
	rect.size = likvidace_popup.size
	rect = _clamp_popup_rect_to_viewport(rect)
	likvidace_popup.popup(rect)

# Confirms bulk disband and removes all armies in selected provinces.
func _potvrd_hromadne_likvidovani():
	var s_armadou = _ziskej_hromadne_zdroje_s_armadou()
	var province_data = _ziskej_provincie_data()
	var total_disbanded := 0
	var total_refund := 0.0
	for pid in s_armadou:
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var pocet = int(d.get("soldiers", 0))
		if pocet <= 0:
			continue
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var je_more = (owner_tag == "SEA")
		var refund = float(pocet) * likvidace_vynos_za_vojaka
		total_refund += refund
		total_disbanded += pocet
		d["soldiers"] = 0
		if je_more:
			d["army_owner"] = ""
		else:
			d["recruitable_population"] = int(d.get("recruitable_population", 0)) + pocet

	if total_disbanded > 0:
		GameManager.statni_kasa += total_refund

	je_hromadne_likvidovani = false
	likvidace_slider.visible = true
	likvidace_popup.hide()
	if total_disbanded > 0:
		_ukaz_stavbu_info("BULK DISBAND", "Disbanded %s soldiers across %d provinces. Refund: +%s" % [_formatuj_cislo(total_disbanded), s_armadou.size(), _format_money_auto(total_refund, 2)])
		GameManager.kolo_zmeneno.emit()
	else:
		_ukaz_stavbu_info("BULK DISBAND", "No troops were disbanded.")

# Handles this gameplay/UI path.
func _postav_hromadne(building_id: String):
	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	if pozemni.is_empty():
		return

	var postaveno := 0
	var preskoceno := 0
	for pid in pozemni:
		if not GameManager.has_method("rozpocni_stavbu_pro_hrace"):
			preskoceno += 1
			continue
		var result = GameManager.rozpocni_stavbu_pro_hrace(int(pid), building_id) as Dictionary
		if bool(result.get("ok", false)):
			postaveno += 1
		else:
			preskoceno += 1

	if postaveno > 0:
		GameManager.kolo_zmeneno.emit()

	_ukaz_stavbu_info("BULK CONSTRUCTION", "Built: %d | Skipped: %d" % [postaveno, preskoceno])



