# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Sprite2D
# this script drives a specific gameplay/UI area and keeps related logic together.

const ControlsConfig = preload("res://scripts/ControlsConfig.gd")

# Processes map clicking, hover, and selection overlays on top of the shader map sprite.
# Simple part: convert click to province id and notify UI.
# Hard part: keeps multiple overlay textures in sync (selection, occupation, capital focus)
# and caches label/map lookups to avoid heavy per-frame work.

@export var logic_map: Texture2D
var map_image: Image

var data_image: Image
var data_texture: ImageTexture
var occupation_image: Image
var occupation_texture: ImageTexture
var selected_multi_image: Image
var selected_multi_texture: ImageTexture
var capital_focus_owned_image: Image
var capital_focus_owned_texture: ImageTexture
var capital_focus_valid_image: Image
var capital_focus_valid_texture: ImageTexture
var total_provinces: int = 5000

var _drag_select_active: bool = false
var _drag_select_started: bool = false
var _drag_start_local: Vector2 = Vector2.ZERO
var _drag_end_local: Vector2 = Vector2.ZERO
const DRAG_SELECT_THRESHOLD := 6.0
const RIGHT_CLICK_CANCEL_THRESHOLD := 8.0

var _right_press_active: bool = false
var _right_press_pos: Vector2 = Vector2.ZERO
var _right_dragging: bool = false
var _drag_select_anchor_cache: Dictionary = {}
var _mode_hover_layer: CanvasLayer
var _mode_hover_panel: PanelContainer
var _mode_hover_label: Label
var _mode_hover_debug_label: Label
var _aktualni_mapovy_mod_local: String = "political"
var _last_mode_hover_debug_text: String = ""
var _root_cache: Node
var _info_ui_cache: Node
var _game_ui_cache: Node
var _map_loader_cache: Node
var _labels_node_cache: Node2D
var _labels_by_province_id: Dictionary = {}
var _labels_cache_dirty: bool = true
var _selection_label_states: Dictionary = {}
var _last_cursor_shape: int = -1
var _potato_mode_enabled: bool = false
var _peace_use_core_ownership_preview: bool = false
var _trade_pick_saved_has_selected: bool = false
var _trade_pick_saved_selected_id: float = -1.0
var _trade_pick_selection_suspended: bool = false
const MODE_HOVER_OFFSET := Vector2(16, 18)
const MODE_HOVER_DEBUG_LOG := false

# Variable to track the last hovered province ID for label popping
var _posledni_hover_id: int = -1

var country_colors = {
	"ALB": Color("#D13A3A"), "AND": Color("#1A409A"), "AUT": Color("#FFFFFF"),
	"BLR": Color("#8CA35E"), "BEL": Color("#D4B04C"), "BIH": Color("#456285"),
	"BGR": Color("#426145"), "HRV": Color("#5C7691"), "CYP": Color("#E3A336"),
	"CZE": Color("#D49035"), "DNK": Color("#9E333D"), "EST": Color("#266E73"),
	"FIN": Color("#96B6D1"), "FRA": Color("#2944A6"), "DEU": Color("#666666"),
	"GRC": Color("#5CA1D6"), "HUN": Color("#A35A47"), "ISL": Color("#88ADC9"),
	"IRL": Color("#388F4F"), "ITA": Color("#408F45"), "KOS": Color("#454B87"),
	"GEO": Color("#D48035"), "LVA": Color("#85616D"), "LIE": Color("#314C7D"),
	"LTU": Color("#A6A34E"), "LUX": Color("#8FA9D4"), "MLT": Color("#D95959"),
	"MDA": Color("#D4A94C"), "MCO": Color("#D63636"), "MNE": Color("#3D7873"),
	"NLD": Color("#D97529"), "MKD": Color("#D14532"), "NOR": Color("#6E88A1"),
	"POL": Color("#C44D64"), "PRT": Color("#2A7A38"), "ROU": Color("#C9A936"),
	"RUS": Color("#316E40"), "SMR": Color("#7BA1C7"), "SRB": Color("#B8939D"),
	"SVK": Color("#3A5B8C"), "SVN": Color("#4E8272"), "ESP": Color("#D4BC2C"),
	"SWE": Color("#286C9E"), "CHE": Color("#AD2A2A"), "TUR": Color("#3A8C67"),
	"UKR": Color("#DEC243"), "GBR": Color("#9E2633"), "SEA": Color("5b556fff")
}

# Occupied provinces are tinted a bit, so the player sees non-core land faster.
# Core flow for this feature.
func _barva_politickeho_vlastnictvi(d: Dictionary) -> Color:
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var base = country_colors.get(owner_tag, Color.from_hsv(owner_tag.hash() / float(0x7FFFFFFF), 0.7, 0.8))
	base.a = 1.0

	# Occupied (non-core) territory is visually muted to separate it from core land.
	var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
	if core_owner != "" and owner_tag != core_owner:
		base = base.lerp(Color(0.92, 0.92, 0.92, 1.0), 0.08)

	return base

# Read-only data accessor.
func _ziskej_barvu_hrace_pro_vyber() -> Color:
	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var base = country_colors.get(player_tag, Color(0.95, 0.85, 0.25, 1.0))
	if base is Color:
		var col = base as Color
		col.a = 1.0
		return col
	return Color(0.95, 0.85, 0.25, 1.0)

# Pulls current state data.
func _ziskej_barvu_statu(tag: String) -> Color:
	var clean = str(tag).strip_edges().to_upper()
	var base = country_colors.get(clean, Color(0.72, 0.34, 0.34, 1.0))
	if base is Color:
		var col = base as Color
		col.a = 1.0
		return col
	return Color(0.72, 0.34, 0.34, 1.0)

# Initializes references, connects signals, and prepares default runtime state.
func _ready():
	if logic_map:
		map_image = logic_map.get_image()
	else:
		push_error("Chybi Logic Map!")
	
	data_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	data_image.fill(Color.TRANSPARENT)
	data_texture = ImageTexture.create_from_image(data_image)

	occupation_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	occupation_image.fill(Color(0, 0, 0, 0))
	occupation_texture = ImageTexture.create_from_image(occupation_image)

	selected_multi_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	selected_multi_image.fill(Color(0, 0, 0, 0))
	selected_multi_texture = ImageTexture.create_from_image(selected_multi_image)

	capital_focus_owned_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	capital_focus_owned_image.fill(Color(0, 0, 0, 0))
	capital_focus_owned_texture = ImageTexture.create_from_image(capital_focus_owned_image)

	capital_focus_valid_image = Image.create_empty(total_provinces, 1, false, Image.FORMAT_RGBA8)
	capital_focus_valid_image.fill(Color(0, 0, 0, 0))
	capital_focus_valid_texture = ImageTexture.create_from_image(capital_focus_valid_image)
	
	material.set_shader_parameter("data_texture", data_texture)
	material.set_shader_parameter("occupation_texture", occupation_texture)
	material.set_shader_parameter("selected_multi_texture", selected_multi_texture)
	material.set_shader_parameter("capital_focus_owned_texture", capital_focus_owned_texture)
	material.set_shader_parameter("capital_focus_valid_texture", capital_focus_valid_texture)
	material.set_shader_parameter("capital_focus_mode", false)
	material.set_shader_parameter("selected_multi_color", _ziskej_barvu_hrace_pro_vyber())
	material.set_shader_parameter("peace_selection_player_color_mode", false)
	material.set_shader_parameter("peace_target_visual_mode", false)
	material.set_shader_parameter("peace_target_owner_color", Color(0.72, 0.34, 0.34, 1.0))
	material.set_shader_parameter("low_detail_mode", false)
	material.set_shader_parameter("total_provinces", float(total_provinces))
	
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("hovered_id", -1.0)
	material.set_shader_parameter("selected_id", -1.0)
	_aktualizuj_hromadny_selection_texture([])
	_ensure_mode_hover_tooltip()
	_connect_labels_cache_signals()

# These small caches matter a lot, jinak hover/select spam would do too much lookup work.
# Applies incoming data to runtime state.
func nastav_potato_mode(enabled: bool) -> void:
	_potato_mode_enabled = enabled
	if material:
		material.set_shader_parameter("low_detail_mode", enabled)

# Reads values from active state.
func _get_root() -> Node:
	var parent_node = get_parent()
	if _root_cache == null or not is_instance_valid(_root_cache) or _root_cache != parent_node:
		_root_cache = parent_node
	return _root_cache

# Fetches data for callers.
func _get_info_ui() -> Node:
	if _info_ui_cache == null or not is_instance_valid(_info_ui_cache):
		var current_scene = get_tree().current_scene
		_info_ui_cache = current_scene.find_child("InfoUI", true, false) if current_scene else null
	return _info_ui_cache

# Pulls current state data.
func _get_game_ui() -> Node:
	if _game_ui_cache == null or not is_instance_valid(_game_ui_cache):
		var current_scene = get_tree().current_scene
		_game_ui_cache = current_scene.find_child("GameUI", true, false) if current_scene else null
	return _game_ui_cache

# Reads values from active state.
func _get_map_loader() -> Node:
	if _map_loader_cache == null or not is_instance_valid(_map_loader_cache):
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.has_method("zpracuj_tah_armad"):
			_map_loader_cache = current_scene
		elif current_scene:
			_map_loader_cache = current_scene.find_child("Map", true, false)
	return _map_loader_cache

# Reads values from active state.
func _get_labels_node() -> Node2D:
	var root = _get_root()
	var next_labels = root.get_node_or_null("ProvinceLabels") as Node2D if root else null
	if _labels_node_cache != next_labels:
		_disconnect_labels_cache_signals()
		_labels_node_cache = next_labels
		_labels_cache_dirty = true
		_connect_labels_cache_signals()
	return _labels_node_cache

# Feature logic entry point.
func _connect_labels_cache_signals() -> void:
	var labels = _labels_node_cache
	if labels == null:
		labels = _get_labels_node()
	if labels == null:
		return
	if not labels.child_entered_tree.is_connected(_on_labels_child_changed):
		labels.child_entered_tree.connect(_on_labels_child_changed)
	if not labels.child_exiting_tree.is_connected(_on_labels_child_changed):
		labels.child_exiting_tree.connect(_on_labels_child_changed)

# Runs the local feature logic.
func _disconnect_labels_cache_signals() -> void:
	if _labels_node_cache == null:
		return
	if _labels_node_cache.child_entered_tree.is_connected(_on_labels_child_changed):
		_labels_node_cache.child_entered_tree.disconnect(_on_labels_child_changed)
	if _labels_node_cache.child_exiting_tree.is_connected(_on_labels_child_changed):
		_labels_node_cache.child_exiting_tree.disconnect(_on_labels_child_changed)

# Triggered by a UI/game signal.
func _on_labels_child_changed(_node: Node) -> void:
	_labels_cache_dirty = true

# Feature logic entry point.
func _ensure_labels_cache() -> void:
	var labels = _get_labels_node()
	if labels == null:
		_labels_by_province_id.clear()
		_labels_cache_dirty = false
		return
	if not _labels_cache_dirty and _labels_by_province_id.size() == labels.get_child_count():
		# Fast path: skip rebuild when structure did not change.
		# Pro male dite: kdyz se nic nezmenilo, nic zbytecne nepocitame.
		return
	_labels_by_province_id.clear()
	for lbl in labels.get_children():
		_labels_by_province_id[int(lbl.get("province_id"))] = lbl
	_labels_cache_dirty = false

# Read-only data accessor.
func _get_label_for_province(province_id: int) -> Node:
	_ensure_labels_cache()
	return _labels_by_province_id.get(province_id, null)

# Sync update for linked values.
func _set_cursor_shape(shape: int) -> void:
	if _last_cursor_shape == shape:
		return
	_last_cursor_shape = shape
	Input.set_default_cursor_shape(shape)

# Clears temporary state.
func _clear_selection_label_states() -> void:
	if _selection_label_states.is_empty():
		return
	for province_id in _selection_label_states.keys():
		var lbl = _get_label_for_province(int(province_id))
		if lbl and lbl.has_method("reset_stav"):
			lbl.reset_stav()
	_selection_label_states.clear()

# Applies prepared settings/effects to runtime systems.
func _apply_selection_label_states(target_id: int, neighbor_ids: Array) -> void:
	var next_states: Dictionary = {}
	next_states[target_id] = 2
	# State map: 2 = selected province, 1 = neighboring province highlight.
	# Pro male dite: vybrana provincie sviti vic, sousedi sviti min.
	for raw_neighbor_id in neighbor_ids:
		var neighbor_id = int(raw_neighbor_id)
		if neighbor_id == target_id:
			continue
		next_states[neighbor_id] = 1

	for province_id in _selection_label_states.keys():
		if next_states.has(province_id):
			continue
		var old_lbl = _get_label_for_province(int(province_id))
		if old_lbl and old_lbl.has_method("reset_stav"):
			old_lbl.reset_stav()

	for province_id in next_states.keys():
		var lbl = _get_label_for_province(int(province_id))
		if lbl == null or not lbl.has_method("nastav_stav_souseda"):
			continue
		var state = int(next_states[province_id])
		lbl.nastav_stav_souseda(state == 2, state == 1)

	_selection_label_states = next_states

# Applies updates and syncs dependent state.
func nastav_nahled_hlavniho_mesta(owned_ids: Array, valid_ids: Array) -> void:
	if capital_focus_owned_image == null or capital_focus_valid_image == null:
		return

	capital_focus_owned_image.fill(Color(0, 0, 0, 0))
	capital_focus_valid_image.fill(Color(0, 0, 0, 0))

	for raw_id in owned_ids:
		# Owned = can be shown; valid = actually selectable as new capital target.
		var pid = int(raw_id)
		if pid < 0 or pid >= total_provinces:
			continue
		capital_focus_owned_image.set_pixel(pid, 0, Color(1, 1, 1, 1))

	for raw_id in valid_ids:
		var pid2 = int(raw_id)
		if pid2 < 0 or pid2 >= total_provinces:
			continue
		capital_focus_valid_image.set_pixel(pid2, 0, Color(1, 1, 1, 1))

	capital_focus_owned_texture.update(capital_focus_owned_image)
	capital_focus_valid_texture.update(capital_focus_valid_image)
	material.set_shader_parameter("capital_focus_mode", true)

# Wipes short-lived state.
func vycisti_nahled_hlavniho_mesta() -> void:
	if capital_focus_owned_image == null or capital_focus_valid_image == null:
		return
	capital_focus_owned_image.fill(Color(0, 0, 0, 0))
	capital_focus_valid_image.fill(Color(0, 0, 0, 0))
	capital_focus_owned_texture.update(capital_focus_owned_image)
	capital_focus_valid_texture.update(capital_focus_valid_image)
	material.set_shader_parameter("capital_focus_mode", false)

func pozastav_trade_single_selection_highlight() -> void:
	if material == null or _trade_pick_selection_suspended:
		return
	_trade_pick_saved_has_selected = bool(material.get_shader_parameter("has_selected"))
	_trade_pick_saved_selected_id = float(material.get_shader_parameter("selected_id"))
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("selected_id", -1.0)
	_trade_pick_selection_suspended = true

func obnov_trade_single_selection_highlight() -> void:
	if material == null or not _trade_pick_selection_suspended:
		return
	material.set_shader_parameter("has_selected", _trade_pick_saved_has_selected)
	material.set_shader_parameter("selected_id", _trade_pick_saved_selected_id)
	_trade_pick_saved_has_selected = false
	_trade_pick_saved_selected_id = -1.0
	_trade_pick_selection_suspended = false

# Feature logic entry point.
func _ensure_mode_hover_tooltip() -> void:
	if _mode_hover_layer != null:
		return

	_mode_hover_layer = CanvasLayer.new()
	_mode_hover_layer.layer = 2048
	_mode_hover_layer.follow_viewport_enabled = false
	var root_viewport = get_tree().root
	if root_viewport:
		root_viewport.add_child(_mode_hover_layer)
	else:
		add_child(_mode_hover_layer)

	_mode_hover_panel = PanelContainer.new()
	_mode_hover_panel.visible = false
	_mode_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_hover_panel.top_level = true
	_mode_hover_panel.modulate = Color(1, 1, 1, 0.96)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.72, 0.80, 0.92, 0.50)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	_mode_hover_panel.add_theme_stylebox_override("panel", style)
	_mode_hover_layer.add_child(_mode_hover_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	_mode_hover_panel.add_child(margin)

	_mode_hover_label = Label.new()
	_mode_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_hover_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_mode_hover_label.add_theme_font_size_override("font_size", 15)
	_mode_hover_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	_mode_hover_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_mode_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	_mode_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(_mode_hover_label)

	# Hard fallback label (kept hidden unless explicitly enabled).
	_mode_hover_debug_label = Label.new()
	_mode_hover_debug_label.visible = false
	_mode_hover_debug_label.position = Vector2(12, 12)
	_mode_hover_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_hover_debug_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_mode_hover_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.90))
	_mode_hover_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	_mode_hover_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	_mode_hover_layer.add_child(_mode_hover_debug_label)

# Hides UI/output and resets related temporary state.
func _hide_mode_hover_tooltip() -> void:
	if _mode_hover_panel:
		_mode_hover_panel.visible = false
	if _mode_hover_debug_label:
		_mode_hover_debug_label.visible = false

# Refreshes cached/UI state.
func _update_mode_hover_tooltip_position(_global_pos: Vector2) -> void:
	if _mode_hover_panel == null or not _mode_hover_panel.visible:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var target = mouse_pos + MODE_HOVER_OFFSET
	var vp_size = get_viewport().get_visible_rect().size
	_mode_hover_panel.reset_size()
	var panel_size = _mode_hover_panel.size
	target.x = clamp(target.x, 4.0, max(4.0, vp_size.x - panel_size.x - 4.0))
	target.y = clamp(target.y, 4.0, max(4.0, vp_size.y - panel_size.y - 4.0))
	_mode_hover_panel.position = target

# Returns current runtime data.
func _ziskej_aktualni_mapovy_mod(root: Node) -> String:
	if _aktualni_mapovy_mod_local != "":
		return _aktualni_mapovy_mod_local
	if root:
		var maybe_mod = str(root.get("aktualni_mapovy_mod"))
		if maybe_mod != "":
			return maybe_mod
	return "political"

# Display formatting helper.
func _format_int_compact(value: int) -> String:
	var s = str(abs(value))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	if value < 0:
		return "-" + out
	return out

# Display formatting helper.
func _format_money_compact(value: float) -> String:
	var rounded = snapped(max(0.0, value), 0.01)
	var whole = int(floor(rounded))
	var decimals = int(round((rounded - float(whole)) * 100.0))
	if decimals >= 100:
		whole += 1
		decimals = 0
	return "%s.%02d" % [_format_int_compact(whole), decimals]

# Updates what the player sees.
func _show_capital_target_tooltip(province_id: int, _data: Dictionary, root: Node) -> void:
	if _mode_hover_panel == null or _mode_hover_label == null:
		return

	var state_tag = ""
	if "stat_presunu_hlavniho_mesta" in root:
		state_tag = str(root.stat_presunu_hlavniho_mesta).strip_edges().to_upper()
	if state_tag == "":
		state_tag = str(GameManager.hrac_stat).strip_edges().to_upper()

	var txt = ""
	if GameManager.has_method("muze_presunout_hlavni_mesto"):
		# Tooltip shows relocation price only for valid target provinces.
		# Pro male dite: kdyz sem muzes presunout hlavni mesto, ukazeme cenu.
		var check = GameManager.muze_presunout_hlavni_mesto(state_tag, province_id)
		if bool(check.get("ok", false)):
			var price = float(check.get("cost", 0.0))
			txt = _format_money_compact(price)
	if txt == "":
		_hide_mode_hover_tooltip()
		return

	_mode_hover_label.text = txt
	_mode_hover_panel.size = _mode_hover_panel.get_combined_minimum_size()
	_mode_hover_panel.visible = true
	if _mode_hover_debug_label:
		_mode_hover_debug_label.text = txt
		_mode_hover_debug_label.visible = false
	_update_mode_hover_tooltip_position(get_global_mouse_position())

# Presents refreshed UI output.
func _show_peace_target_tooltip(province_id: int, data: Dictionary, root: Node) -> void:
	if _mode_hover_panel == null or _mode_hover_label == null:
		return

	var province_name = str(data.get("province_name", "Province %d" % province_id)).strip_edges()
	if province_name == "":
		province_name = "Province %d" % province_id

	var selected = false
	if root.has_method("je_provincie_vybrana_v_miru"):
		selected = bool(root.je_provincie_vybrana_v_miru(province_id))

	_mode_hover_label.text = "%s | %s" % [province_name, "SELECTED" if selected else "click to select"]
	_mode_hover_panel.size = _mode_hover_panel.get_combined_minimum_size()
	_mode_hover_panel.visible = true
	if _mode_hover_debug_label:
		_mode_hover_debug_label.text = _mode_hover_label.text
		_mode_hover_debug_label.visible = false
	_update_mode_hover_tooltip_position(get_global_mouse_position())

# Display formatting helper.
func _format_pct_signed(value: float) -> String:
	var pct = int(round(value * 100.0))
	if pct >= 0:
		return "+%d%%" % pct
	return "%d%%" % pct

# Draws/updates visible UI output.
func _show_attack_target_tooltip(from_id: int, province_id: int, data: Dictionary, root: Node) -> bool:
	if _mode_hover_panel == null or _mode_hover_label == null:
		return false
	if root == null or not root.has_method("ziskej_nahled_bojovych_modifikatoru"):
		return false

	var preview = root.ziskej_nahled_bojovych_modifikatoru(from_id, province_id) as Dictionary
	if not bool(preview.get("ok", false)):
		return false
	if not bool(preview.get("is_attack", false)):
		return false

	var prov_name = str(data.get("province_name", "Province %d" % province_id)).strip_edges()
	if prov_name == "":
		prov_name = "Province %d" % province_id

	var atk_bonus_txt = _format_pct_signed(float(preview.get("attacker_bonus_pct", 0.0)))
	var def_bonus_txt = _format_pct_signed(float(preview.get("defender_bonus_pct", 0.0)))
	var terrain_name = str(preview.get("terrain", "unknown")).strip_edges()
	if terrain_name == "":
		terrain_name = "unknown"

	var atk_total = float(preview.get("attacker_total_mult", 1.0))
	var def_total = float(preview.get("defender_total_mult", 1.0))

	_mode_hover_label.text = "Attack: %s\nA/D Bonus: %s / %s\nA/D Power: x%.2f / x%.2f (%s)" % [
		prov_name,
		atk_bonus_txt,
		def_bonus_txt,
		atk_total,
		def_total,
		terrain_name
	]
	_mode_hover_panel.size = _mode_hover_panel.get_combined_minimum_size()
	_mode_hover_panel.visible = true
	if _mode_hover_debug_label:
		_mode_hover_debug_label.text = _mode_hover_label.text
		_mode_hover_debug_label.visible = false
	_update_mode_hover_tooltip_position(get_global_mouse_position())
	return true

# Main runtime logic lives here.
func _sestav_text_hover_modu(data: Dictionary, mod: String) -> String:
	match mod:
		"population":
			return "Population: %s" % _format_int_compact(int(data.get("population", 0)))
		"gdp":
			return "GDP: %.2f" % float(data.get("gdp", 0.0))
		"ideology":
			return "Ideology: %s" % str(data.get("ideology", "unknown"))
		"recruitable_population":
			return "Recruitable: %s" % _format_int_compact(int(data.get("recruitable_population", 0)))
		"relationships":
			var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
			var rel = 0.0
			if GameManager.has_method("ziskej_vztah_statu") and owner_tag != "" and owner_tag != "SEA":
				rel = float(GameManager.ziskej_vztah_statu(GameManager.hrac_stat, owner_tag))
			return "Relation: %+.1f" % rel
		"terrain":
			return "Terrain: %s" % str(data.get("terrain", "unknown"))
		"resources":
			var r_type = str(data.get("resource_type", "none"))
			var r_amount = int(data.get("resource_amount", 0))
			if r_type == "" or r_type == "none":
				return "Resource: none"
			return "Resource: %s (%d)" % [r_type, r_amount]
		_:
			return ""

# Applies visual/UI updates.
func _show_mode_hover_tooltip(data: Dictionary, root: Node) -> void:
	if _mode_hover_panel == null or _mode_hover_label == null:
		return
	var mod = _ziskej_aktualni_mapovy_mod(root)
	if mod == "political":
		_hide_mode_hover_tooltip()
		return

	var txt = _sestav_text_hover_modu(data, mod)
	if txt == "":
		_hide_mode_hover_tooltip()
		return

	_mode_hover_label.text = txt
	_mode_hover_panel.size = _mode_hover_panel.get_combined_minimum_size()
	_mode_hover_panel.visible = true
	if _mode_hover_debug_label:
		_mode_hover_debug_label.text = txt
		_mode_hover_debug_label.visible = false
	if MODE_HOVER_DEBUG_LOG and txt != _last_mode_hover_debug_text:
		print("[MODE_HOVER] ", txt)
		_last_mode_hover_debug_text = txt
	_update_mode_hover_tooltip_position(get_global_mouse_position())

# Render pass for custom visuals.
func _draw():
	if not _drag_select_active or not _drag_select_started:
		return

	var rect = Rect2(_drag_start_local, _drag_end_local - _drag_start_local).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return

	var rect_draw = rect
	# Drag selection is tracked in texture-space (0..size), but Sprite2D drawing
	# uses local coordinates centered around (0,0) when centered=true.
	if centered and texture:
		rect_draw.position -= texture.get_size() / 2.0

	draw_rect(rect_draw, Color(0.1, 1.0, 1.0, 1.0), false, 3.0)

# Fetches data for callers.
func _ziskej_localni_pozici_mysi(global_mouse_pos: Vector2) -> Vector2:
	var local_pos = to_local(global_mouse_pos)
	if centered:
		local_pos += texture.get_size() / 2.0
	return local_pos

# Updates derived state and UI.
func _aktualizuj_hromadny_selection_texture(ids: Array):
	if selected_multi_image == null or selected_multi_texture == null:
		return
	if material:
		var root = get_parent()
		var is_peace_targeting = root != null and ("ceka_na_cil_miru" in root) and bool(root.ceka_na_cil_miru)
		var is_trade_targeting = root != null and ("ceka_na_cil_trade_provincie" in root) and bool(root.ceka_na_cil_trade_provincie)
		var is_clean_selection_mode = is_peace_targeting or is_trade_targeting
		material.set_shader_parameter("selected_multi_color", _ziskej_barvu_hrace_pro_vyber())
		# In peace/trade picking modes, tint only explicitly selected provinces.
		material.set_shader_parameter("peace_selection_player_color_mode", is_clean_selection_mode)
		# Prevent stale peace-target owner coloring from affecting trade mode.
		material.set_shader_parameter("peace_target_visual_mode", false)

	selected_multi_image.fill(Color(0, 0, 0, 0))
	for raw_id in ids:
		var pid = int(raw_id)
		if pid < 0 or pid >= total_provinces:
			continue
		selected_multi_image.set_pixel(pid, 0, Color(1, 1, 1, 1))
	selected_multi_texture.update(selected_multi_image)

# Applies incoming data to runtime state.
func nastav_nahled_mirovych_cilu(porazeny_tag: String) -> void:
	if material == null:
		return
	material.set_shader_parameter("peace_target_visual_mode", true)
	material.set_shader_parameter("peace_target_owner_color", _ziskej_barvu_statu(porazeny_tag))

# Wipes short-lived state.
func vycisti_nahled_mirovych_cilu() -> void:
	if material == null:
		return
	material.set_shader_parameter("peace_target_visual_mode", false)

func nastav_peace_ownership_preview(enabled: bool) -> void:
	_peace_use_core_ownership_preview = enabled
	var root = _get_root()
	if root and ("provinces" in root):
		aktualizuj_mapovy_mod(_aktualni_mapovy_mod_local, root.provinces)

# Fallback input handler.
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if _drag_select_active:
			# behem drag-selectu nevolame normal hover flow, at se to navzajem nebije.
			_drag_end_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
			if not _drag_select_started and _drag_start_local.distance_to(_drag_end_local) >= DRAG_SELECT_THRESHOLD:
				_drag_select_started = true
			queue_redraw()
			return
		_zpracuj_interakci(event.position, false, false)
		_update_mode_hover_tooltip_position(get_global_mouse_position())
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# drag start povolime jen mimo special target rezimy (presun/mir/trade).
			var root = get_parent()
			var is_targeting = "ceka_na_cil_presunu" in root and root.ceka_na_cil_presunu
			var is_capital_targeting = "ceka_na_cil_hlavniho_mesta" in root and root.ceka_na_cil_hlavniho_mesta
			var is_peace_targeting = "ceka_na_cil_miru" in root and root.ceka_na_cil_miru
			var is_trade_targeting = "ceka_na_cil_trade_provincie" in root and root.ceka_na_cil_trade_provincie
			var is_bulk_targeting = "ceka_na_hromadny_cil_presunu" in root and root.ceka_na_hromadny_cil_presunu
			var game_ui = _get_game_ui()
			var is_trade_war_targeting = game_ui and game_ui.has_method("je_aktivni_vyber_trade_valky_na_mape") and bool(game_ui.je_aktivni_vyber_trade_valky_na_mape())
			if not is_targeting and not is_bulk_targeting and not is_capital_targeting and not is_peace_targeting and not is_trade_targeting and not is_trade_war_targeting:
				_drag_select_active = true
				_drag_select_started = false
				_drag_start_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
				_drag_end_local = _drag_start_local
				queue_redraw()
				return
			_zpracuj_interakci(event.position, true, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _drag_select_active:
				# kratky klik -> normal selection; real drag -> box apply branch.
				_drag_end_local = _ziskej_localni_pozici_mysi(get_global_mouse_position())
				var had_drag = _drag_select_started
				_drag_select_active = false
				_drag_select_started = false
				queue_redraw()
				if had_drag:
					_aplikuj_drag_hromadny_vyber()
				else:
					_zpracuj_interakci(event.position, true, event.shift_pressed)
				return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_press_active = true
				_right_dragging = false
				_right_press_pos = event.position
			else:
				if _right_press_active and not _right_dragging:
					_odzanc_vse()
				_right_press_active = false
				_right_dragging = false

	if event is InputEventMouseMotion and _right_press_active and not _right_dragging:
		if event.position.distance_to(_right_press_pos) >= RIGHT_CLICK_CANCEL_THRESHOLD:
			_right_dragging = true
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		var root = get_parent()
		if event.keycode == KEY_ESCAPE:
			_odzanc_vse()
			return
		if "provinces" in root:
			if event.keycode == KEY_1:
				aktualizuj_mapovy_mod("political", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("political")
			elif event.keycode == KEY_2:
				aktualizuj_mapovy_mod("population", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("population")
			elif event.keycode == KEY_3:
				aktualizuj_mapovy_mod("gdp", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("gdp")
			elif event.keycode == KEY_4:
				aktualizuj_mapovy_mod("ideology", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("ideology")
			elif event.keycode == KEY_5:
				aktualizuj_mapovy_mod("recruitable_population", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("recruitable_population")
			elif event.keycode == KEY_6:
				aktualizuj_mapovy_mod("relationships", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("relationships")
			elif event.keycode == KEY_7:
				aktualizuj_mapovy_mod("terrain", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("terrain")
			elif event.keycode == KEY_8:
				aktualizuj_mapovy_mod("resources", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("resources")
			elif event.keycode == KEY_9:
				aktualizuj_mapovy_mod("alliances", root.provinces)
				if root.has_method("nastav_mapovy_mod"):
					root.nastav_mapovy_mod("alliances")
			
			elif ControlsConfig.matches_action(event, ControlsConfig.ACTION_DEV_CONQUER):
				var vybrana_provincie = material.get_shader_parameter("selected_id")
				if vybrana_provincie != null and float(vybrana_provincie) >= 0.0:
					dobyt_provincii(int(vybrana_provincie), GameManager.hrac_stat, true)
					
			elif ControlsConfig.matches_action(event, ControlsConfig.ACTION_END_TURN):
				var game_ui_for_turn = _get_game_ui()
				if game_ui_for_turn and game_ui_for_turn.has_method("blokuje_hotkey_ukonceni_tahu") and bool(game_ui_for_turn.blokuje_hotkey_ukonceni_tahu()):
					return
				if GameManager.has_method("pozaduj_ukonceni_kola"):
					GameManager.pozaduj_ukonceni_kola()
				else:
					GameManager.ukonci_kolo()

# Applies prepared settings/effects to runtime systems.
func _aplikuj_drag_hromadny_vyber():
	if map_image == null:
		return

	var root = _get_root()
	if not root:
		return
	if not root.has_method("pridej_hromadny_vyber_provincie") or not root.has_method("ziskej_hromadne_vybrane_provincie"):
		return

	var texture_rect = Rect2(Vector2.ZERO, texture.get_size())
	var drag_rect = Rect2(_drag_start_local, _drag_end_local - _drag_start_local).abs()
	var clipped_rect = drag_rect.intersection(texture_rect)
	# clipping na texture bounds zabranuje selekci mimo mapu pri rychlym tahu mysi.
	if clipped_rect.size.x < 1.0 or clipped_rect.size.y < 1.0:
		return

	# Add only provinces whose center/anchor lies inside rectangle.
	if "provinces" in root:
		for p_id in root.provinces.keys():
			var pid = int(p_id)
			var p = root.provinces[pid]
			var pos = _ziskej_drag_select_anchor(root, pid, p)
			if pos == Vector2.ZERO:
				continue
			if clipped_rect.has_point(pos):
				root.pridej_hromadny_vyber_provincie(pid)

	var hromadny_ids = root.ziskej_hromadne_vybrane_provincie()
	_aktualizuj_hromadny_selection_texture(hromadny_ids)

	if hromadny_ids.is_empty():
		# prazdnej vysledek = vratime UI do neutralniho stavu.
		_odzanc_vse()
		return

	material.set_shader_parameter("selected_id", int(hromadny_ids[hromadny_ids.size() - 1]))
	material.set_shader_parameter("has_selected", true)
	if root.has_method("nastav_vybranou_armadu_provincie"):
		root.nastav_vybranou_armadu_provincie(int(hromadny_ids[hromadny_ids.size() - 1]))

	if hromadny_ids.size() > 1:
		var info_ui_multi = _get_info_ui()
		if info_ui_multi and info_ui_multi.has_method("zobraz_hromadna_data"):
			info_ui_multi.zobraz_hromadna_data(hromadny_ids, root.provinces)
	else:
		var pid = int(hromadny_ids[0])
		if root.provinces.has(pid):
			var info_ui_single = _get_info_ui()
			if info_ui_single and info_ui_single.has_method("zobraz_data"):
				info_ui_single.zobraz_data(root.provinces[pid])

# Pulls current state data.
func _ziskej_drag_select_anchor(root: Node, prov_id: int, prov_data: Dictionary) -> Vector2:
	if _drag_select_anchor_cache.has(prov_id):
		return _drag_select_anchor_cache[prov_id]

	# Sea provinces are never valid for box-select of owned land armies and can trigger expensive fallbacks.
	if root.has_method("_je_more_provincie") and root._je_more_provincie(prov_id):
		_drag_select_anchor_cache[prov_id] = Vector2.ZERO
		return Vector2.ZERO

	var pos = Vector2(float(prov_data.get("x", 0.0)), float(prov_data.get("y", 0.0)))
	if pos != Vector2.ZERO:
		_drag_select_anchor_cache[prov_id] = pos
		return pos

	# Fallback only for rare provinces with missing coordinates.
	if root.has_method("_ziskej_lokalni_pozici_provincie"):
		pos = root._ziskej_lokalni_pozici_provincie(prov_id)
		_drag_select_anchor_cache[prov_id] = pos
		return pos

	_drag_select_anchor_cache[prov_id] = Vector2.ZERO
	return Vector2.ZERO

# Completely clears the active selection and hides all contextual UI panels
# Runs the local feature logic.
func _odzanc_vse():
	material.set_shader_parameter("has_selected", false)
	material.set_shader_parameter("selected_id", -1.0)
	_hide_mode_hover_tooltip()
	
	var root = _get_root()
	if root and root.has_method("nastav_vybranou_armadu_provincie"):
		root.nastav_vybranou_armadu_provincie(-1)
	if "ceka_na_cil_presunu" in root:
		root.ceka_na_cil_presunu = false
	if root.has_method("zrus_rezim_vyberu_hlavniho_mesta"):
		root.zrus_rezim_vyberu_hlavniho_mesta()
	if root.has_method("zrus_rezim_vyberu_miru"):
		root.zrus_rezim_vyberu_miru()
	if root.has_method("zrus_rezim_vyberu_trade_provincie"):
		root.zrus_rezim_vyberu_trade_provincie()
	if "ceka_na_hromadny_cil_presunu" in root:
		root.ceka_na_hromadny_cil_presunu = false
	if root.has_method("vycisti_nahled_presunu"):
		root.vycisti_nahled_presunu()
	if root.has_method("vycisti_hromadny_vyber_provincii"):
		root.vycisti_hromadny_vyber_provincii()
	_aktualizuj_hromadny_selection_texture([])
	
	_set_cursor_shape(Input.CURSOR_ARROW)
	
	var info_ui = _get_info_ui()
	if info_ui and info_ui.has_method("schovej_se"):
		info_ui.schovej_se()
		
	var game_ui = _get_game_ui()
	if game_ui and game_ui.has_method("zrus_vyber_cile_hlavniho_mesta_ui"):
		game_ui.zrus_vyber_cile_hlavniho_mesta_ui()
	if game_ui and game_ui.has_method("zrus_vyber_miru_ui"):
		game_ui.zrus_vyber_miru_ui()
	if game_ui and game_ui.has_method("zrus_vyber_trade_provincie_ui"):
		game_ui.zrus_vyber_trade_provincie_ui()
	if game_ui and game_ui.has_method("zrus_vyber_trade_valecneho_cile_ui"):
		game_ui.zrus_vyber_trade_valecneho_cile_ui()
	var ma_otevrene_mirove_jednani = false
	if game_ui and game_ui.has_method("ma_otevrene_mirove_jednani"):
		ma_otevrene_mirove_jednani = bool(game_ui.ma_otevrene_mirove_jednani())
	if game_ui and game_ui.has_method("schovej_se") and not ma_otevrene_mirove_jednani:
		game_ui.schovej_se()
	_clear_selection_label_states()

# Main runtime logic lives here.
func _zpracuj_interakci(_mouse_pos: Vector2, je_kliknuti: bool, shift_held: bool = false):
	if map_image == null: return

	var root = _get_root()
	if je_kliknuti and root and root.has_method("ziskej_prov_id_podle_ikony_armady"):
		# priorita kliknuti na army ikonu, i kdyz pod ni je jina provincie/barva mapy.
		var hit_prov_id = int(root.ziskej_prov_id_podle_ikony_armady(get_global_mouse_position()))
		if hit_prov_id >= 0 and "provinces" in root and root.provinces.has(hit_prov_id):
			_aktualizuj_vizual(float(hit_prov_id), true, root.provinces[hit_prov_id], shift_held)
			return
	
	var local_pos = to_local(get_global_mouse_position())
	if centered: local_pos += texture.get_size() / 2.0
	
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	if rect.has_point(local_pos):
		var pixel_color = map_image.get_pixelv(Vector2i(local_pos))
		
		if pixel_color.a > 0.0:
			# color hit-test bezi az po icon-hit; tohle je fallback pro samotnou mapu.
			if root.has_method("get_province_data_by_color"):
				var data = root.get_province_data_by_color(pixel_color)
				if data:
					_aktualizuj_vizual(float(data["id"]), je_kliknuti, data, shift_held)
					return

	_vymaz_hover()

# Updates selection and hover states
# Updates derived state and UI.
func _aktualizuj_vizual(prov_id: float, je_kliknuti: bool, data: Dictionary, shift_held: bool = false):
	var root = _get_root()
	var is_targeting = "ceka_na_cil_presunu" in root and root.ceka_na_cil_presunu
	var is_capital_targeting = "ceka_na_cil_hlavniho_mesta" in root and root.ceka_na_cil_hlavniho_mesta
	var is_peace_targeting = "ceka_na_cil_miru" in root and root.ceka_na_cil_miru
	var is_trade_targeting = "ceka_na_cil_trade_provincie" in root and root.ceka_na_cil_trade_provincie
	var is_bulk_targeting = "ceka_na_hromadny_cil_presunu" in root and root.ceka_na_hromadny_cil_presunu
	var game_ui_trade_war = _get_game_ui()
	var is_trade_war_targeting = game_ui_trade_war and game_ui_trade_war.has_method("je_aktivni_vyber_trade_valky_na_mape") and bool(game_ui_trade_war.je_aktivni_vyber_trade_valky_na_mape())
	if material:
		material.set_shader_parameter("peace_selection_player_color_mode", is_peace_targeting or is_trade_targeting)
	var multi_ids: Array = []
	# multi selection je sdilena mezi shader highlightem a InfoUI panelem.
	if root.has_method("ziskej_hromadne_vybrane_provincie"):
		multi_ids = root.ziskej_hromadne_vybrane_provincie()
	var has_multi_selection = multi_ids.size() > 1
	
	if je_kliknuti:
		# --- TARGET SELECTION MODE FOR ARMY MOVEMENT ---
		if is_peace_targeting:
			# peace mode pouziva toggle vyber, ne jednorazovy confirm na prvni klik.
			var target_peace_id = int(prov_id)
			if not root.has_method("je_platna_provincie_pro_mir") or not root.je_platna_provincie_pro_mir(target_peace_id):
				return

			var result_peace: Dictionary = {"ok": false, "reason": "Failed to select province for peace terms."}
			if root.has_method("prepni_vyber_mirove_provincie"):
				result_peace = root.prepni_vyber_mirove_provincie(target_peace_id)

			if bool(result_peace.get("ok", false)):
				_aktualizuj_hromadny_selection_texture(result_peace.get("selected", []) as Array)

			var game_ui_peace = _get_game_ui()
			if game_ui_peace and game_ui_peace.has_method("obsluha_vyberu_miru_z_mapy"):
				game_ui_peace.obsluha_vyberu_miru_z_mapy(result_peace, target_peace_id)
			return

		if is_trade_targeting:
			# trade province pick ma vlastni validacni guardy v map_loader.
			var target_trade_id = int(prov_id)
			if not root.has_method("je_platna_provincie_pro_trade") or not root.je_platna_provincie_pro_trade(target_trade_id):
				return

			var result_trade: Dictionary = {"ok": false, "reason": "Failed to select province for trade transfer."}
			if root.has_method("prepni_vyber_trade_provincie"):
				result_trade = root.prepni_vyber_trade_provincie(target_trade_id)

			if bool(result_trade.get("ok", false)):
				_aktualizuj_hromadny_selection_texture(result_trade.get("selected", []) as Array)

			var game_ui_trade = _get_game_ui()
			if game_ui_trade and game_ui_trade.has_method("obsluha_vyberu_trade_provincie_z_mapy"):
				game_ui_trade.obsluha_vyberu_trade_provincie_z_mapy(result_trade, target_trade_id)
			return

		if is_trade_war_targeting:
			if game_ui_trade_war and game_ui_trade_war.has_method("obsluha_vyberu_trade_valky_z_mapy"):
				if bool(game_ui_trade_war.obsluha_vyberu_trade_valky_z_mapy(data)):
					return

		if is_capital_targeting:
			var target_cap_id = int(prov_id)
			if not root.has_method("je_platny_cil_hlavniho_mesta") or not root.je_platny_cil_hlavniho_mesta(target_cap_id):
				return

			var result: Dictionary = {"ok": false, "reason": "Presun hlavniho mesta selhal."}
			if root.has_method("potvrd_cil_hlavniho_mesta"):
				result = root.potvrd_cil_hlavniho_mesta(target_cap_id)

			_set_cursor_shape(Input.CURSOR_ARROW)
			material.set_shader_parameter("is_target_hover", false)

			var game_ui_cap = _get_game_ui()
			if game_ui_cap and game_ui_cap.has_method("obsluha_presunu_hlavniho_mesta_z_mapy"):
				game_ui_cap.obsluha_presunu_hlavniho_mesta_z_mapy(result, target_cap_id)
			return

		if is_bulk_targeting:
			var bulk_to_id = int(prov_id)
			var planned_count = 0
			if root.has_method("zaregistruj_hromadny_presun_armad"):
				planned_count = int(root.zaregistruj_hromadny_presun_armad(bulk_to_id))

			if planned_count > 0:
				var map_loader = _get_map_loader()
				if not map_loader and root.has_method("_ukaz_bitevni_popup"):
					map_loader = root
				if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
					map_loader._ukaz_bitevni_popup("BULK MOVE", "Planned moves: %d" % planned_count)
				_set_cursor_shape(Input.CURSOR_ARROW)
				material.set_shader_parameter("is_target_hover", false)
			return

		if is_targeting:
			var from_id = root.vybrana_armada_od
			var to_id = int(prov_id)
			var cil_vybran = false
			var path: Array = []
			
			if from_id != to_id and root.has_method("najdi_nejrychlejsi_cestu_presunu"):
				path = root.najdi_nejrychlejsi_cestu_presunu(from_id, to_id)
				if path.size() >= 2:
					var target_info_ui = _get_info_ui()
					if target_info_ui and target_info_ui.has_method("zobraz_presun_slider"):
						target_info_ui.zobraz_presun_slider(from_id, to_id, root.vybrana_armada_max, path)
						cil_vybran = true
			
			# Reset state only when a valid target is chosen.
			if cil_vybran:
				root.ceka_na_cil_presunu = false
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				_set_cursor_shape(Input.CURSOR_ARROW)
				material.set_shader_parameter("is_target_hover", false)
			return
		# -----------------------------------------------

		var shift_multi = shift_held or Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
		if shift_multi and root.has_method("prepni_hromadny_vyber_provincie") and root.has_method("ziskej_hromadne_vybrane_provincie"):
			# Preserve the previously selected province as initial bulk member when Shift-selection starts.
			if root.has_method("pridej_hromadny_vyber_provincie"):
				var existing_multi = root.ziskej_hromadne_vybrane_provincie()
				if existing_multi.is_empty():
					var initial_selected = int(material.get_shader_parameter("selected_id"))
					if initial_selected >= 0 and initial_selected != int(prov_id):
						root.pridej_hromadny_vyber_provincie(initial_selected)

			root.prepni_hromadny_vyber_provincie(int(prov_id))
			var hromadny_ids = root.ziskej_hromadne_vybrane_provincie()
			_aktualizuj_hromadny_selection_texture(hromadny_ids)
			material.set_shader_parameter("selected_id", prov_id)
			material.set_shader_parameter("has_selected", true)
			if root.has_method("nastav_vybranou_armadu_provincie"):
				root.nastav_vybranou_armadu_provincie(int(prov_id))
			if hromadny_ids.size() > 1:
				var info_ui_multi = _get_info_ui()
				if info_ui_multi and info_ui_multi.has_method("zobraz_hromadna_data"):
					info_ui_multi.zobraz_hromadna_data(hromadny_ids, root.provinces)
				return
			elif hromadny_ids.size() == 1:
				return
			elif hromadny_ids.is_empty():
				_odzanc_vse()
				return

		if root.has_method("vycisti_hromadny_vyber_provincii"):
			root.vycisti_hromadny_vyber_provincii()
		_aktualizuj_hromadny_selection_texture([])
		
		material.set_shader_parameter("selected_id", prov_id)
		material.set_shader_parameter("has_selected", true)
		if root.has_method("nastav_vybranou_armadu_provincie"):
			root.nastav_vybranou_armadu_provincie(int(prov_id))
		
		var vsechny_provincie = root.provinces if "provinces" in root else {}
		
		var info_ui = _get_info_ui()
		if info_ui and info_ui.has_method("zobraz_data"):
			info_ui.zobraz_data(data)
			
		var game_ui = _get_game_ui()
		if game_ui and game_ui.has_method("zobraz_prehled_statu"):
			game_ui.zobraz_prehled_statu(data, vsechny_provincie)
		_apply_selection_label_states(int(prov_id), data.get("neighbors", []))
					
	else:
		# --- HOVER LOGIC ---

		if has_multi_selection and not is_targeting and not is_bulk_targeting and not is_peace_targeting:
			var valid_multi_hover = false
			if root.has_method("je_platna_provincie_pro_hromadny_vyber"):
				valid_multi_hover = root.je_platna_provincie_pro_hromadny_vyber(int(prov_id))

			material.set_shader_parameter("is_target_hover", false)
			_set_cursor_shape(Input.CURSOR_POINTING_HAND if valid_multi_hover else Input.CURSOR_ARROW)

			if _posledni_hover_id == int(prov_id):
				_show_mode_hover_tooltip(data, root)
				return

			_vymaz_hover_labely()
			material.set_shader_parameter("hovered_id", prov_id)
			material.set_shader_parameter("has_hover", true)
			_posledni_hover_id = int(prov_id)
			_show_mode_hover_tooltip(data, root)
			return
		
		# Limit hovering strictly to neighbors if we are in target mode
		if is_peace_targeting:
			var valid_peace_target = false
			if root.has_method("je_platna_provincie_pro_mir"):
				valid_peace_target = root.je_platna_provincie_pro_mir(int(prov_id))
			if not valid_peace_target:
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return
			_set_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_trade_targeting:
			var valid_trade_target = false
			if root.has_method("je_platna_provincie_pro_trade"):
				valid_trade_target = root.je_platna_provincie_pro_trade(int(prov_id))
			if not valid_trade_target:
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return
			_set_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_trade_war_targeting:
			var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
			var valid_country_target = owner_tag != "" and owner_tag != "SEA"
			if game_ui_trade_war and game_ui_trade_war.has_method("je_platny_trade_cil_statu_na_mape"):
				valid_country_target = bool(game_ui_trade_war.je_platny_trade_cil_statu_na_mape(owner_tag))
			if not valid_country_target:
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return
			_set_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_capital_targeting:
			var valid_cap_target = false
			if root.has_method("je_platny_cil_hlavniho_mesta"):
				valid_cap_target = root.je_platny_cil_hlavniho_mesta(int(prov_id))
			if not valid_cap_target:
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return
			_set_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_bulk_targeting:
			var bulk_valid = false
			var bulk_hover_path: Array = []
			if root.has_method("ma_hromadny_platny_cil_presunu"):
				bulk_valid = root.ma_hromadny_platny_cil_presunu(int(prov_id))
			if bulk_valid and root.has_method("najdi_hromadny_nahled_presunu_k_cili"):
				bulk_hover_path = root.najdi_hromadny_nahled_presunu_k_cili(int(prov_id))
			if not bulk_valid:
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return
			if bulk_hover_path.size() >= 2 and root.has_method("zobraz_nahled_presunu"):
				root.zobraz_nahled_presunu(bulk_hover_path)
			_set_cursor_shape(Input.CURSOR_POINTING_HAND)
			material.set_shader_parameter("is_target_hover", true)
		elif is_targeting:
			var from_id = root.vybrana_armada_od
			var is_valid_target = false
			var hover_path: Array = []
			if root.has_method("najdi_nejrychlejsi_cestu_presunu"):
				hover_path = root.najdi_nejrychlejsi_cestu_presunu(from_id, int(prov_id))
				is_valid_target = hover_path.size() >= 2
			
			if not is_valid_target or int(prov_id) == from_id:
				if root.has_method("vycisti_nahled_presunu"):
					root.vycisti_nahled_presunu()
				_vymaz_hover()
				_set_cursor_shape(Input.CURSOR_ARROW)
				return 
			else:
				if root.has_method("zobraz_nahled_presunu"):
					root.zobraz_nahled_presunu(hover_path)
				_set_cursor_shape(Input.CURSOR_POINTING_HAND)
				material.set_shader_parameter("is_target_hover", true)
		else:
			if root.has_method("vycisti_nahled_presunu"):
				root.vycisti_nahled_presunu()
			_set_cursor_shape(Input.CURSOR_ARROW)
			material.set_shader_parameter("is_target_hover", false)
			
		if _posledni_hover_id == int(prov_id):
			if is_peace_targeting:
				_show_peace_target_tooltip(int(prov_id), data, root)
			elif is_capital_targeting:
				_show_capital_target_tooltip(int(prov_id), data, root)
			elif is_targeting:
				if not _show_attack_target_tooltip(int(root.vybrana_armada_od), int(prov_id), data, root):
					_show_mode_hover_tooltip(data, root)
			else:
				_show_mode_hover_tooltip(data, root)
			return # Already hovering this province, do nothing
			
		_vymaz_hover_labely() # Clean up the previously hovered label
		
		material.set_shader_parameter("hovered_id", prov_id)
		material.set_shader_parameter("has_hover", true)
		
		# Make the currently hovered label pop up
		var hovered_lbl = _get_label_for_province(int(prov_id))
		if hovered_lbl and hovered_lbl.has_method("nastav_stav_souseda"):
			hovered_lbl.nastav_stav_souseda(true, false) # Treat hover as 'target' to show it
					
		_posledni_hover_id = int(prov_id)
		if is_peace_targeting:
			_show_peace_target_tooltip(int(prov_id), data, root)
		elif is_capital_targeting:
			_show_capital_target_tooltip(int(prov_id), data, root)
		elif is_targeting:
			if not _show_attack_target_tooltip(int(root.vybrana_armada_od), int(prov_id), data, root):
				_show_mode_hover_tooltip(data, root)
		else:
			_show_mode_hover_tooltip(data, root)

# Feature logic entry point.
func _vymaz_hover():
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("is_target_hover", false)
	_hide_mode_hover_tooltip()
	var root = _get_root()
	if root and root.has_method("vycisti_nahled_presunu"):
		root.vycisti_nahled_presunu()
	_set_cursor_shape(Input.CURSOR_ARROW)
	_vymaz_hover_labely()

# Safely resets the previously hovered label to its correct persistent state
# Handles this gameplay/UI path.
func _vymaz_hover_labely():
	if _posledni_hover_id != -1:
		var sel_id = int(material.get_shader_parameter("selected_id"))
		
		# If the hovered province is also the clicked one, leave it alone
		if _posledni_hover_id == sel_id:
			_posledni_hover_id = -1
			return
			
		var state = int(_selection_label_states.get(_posledni_hover_id, 0))
		var lbl = _get_label_for_province(_posledni_hover_id)
		if lbl and lbl.has_method("nastav_stav_souseda"):
			if state == 2:
				lbl.nastav_stav_souseda(true, false)
			elif state == 1:
				# Restore neighbor state if it belongs to the active selection.
				lbl.nastav_stav_souseda(false, true)
			elif lbl.has_method("reset_stav"):
				# Otherwise, completely hide/reset it.
				lbl.reset_stav()
		_posledni_hover_id = -1

# Recomputes values from current data.
func aktualizuj_mapovy_mod(mod: String, province_db: Dictionary):
	_aktualni_mapovy_mod_local = str(mod)
	for prov_id in province_db.keys():
		var d = province_db[prov_id]
		var barva = Color.TRANSPARENT
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
		var display_owner_tag = owner_tag
		if _peace_use_core_ownership_preview and core_owner != "" and core_owner != "SEA":
			display_owner_tag = core_owner
		var je_okupace = (core_owner != "" and owner_tag != core_owner and not _peace_use_core_ownership_preview)
		occupation_image.set_pixel(prov_id, 0, Color(1, 1, 1, 1) if je_okupace else Color(0, 0, 0, 0))
		
		if display_owner_tag != "SEA" and str(d.get("type", "")) != "sea":
			match mod:
				"political":
					if _peace_use_core_ownership_preview:
						barva = _ziskej_barvu_statu(display_owner_tag)
					else:
						barva = _barva_politickeho_vlastnictvi(d)
				"population":
					var s = clamp(float(d.get("population", 0)) / 3000000.0, 0.0, 1.0)
					barva = Color(s, 0.2, 0.2, 1.0)
				"gdp":
					var s = clamp(float(d.get("gdp", 0.0)) / 500.0, 0.0, 1.0)
					barva = Color(0.2, 0.8 * s, s, 1.0)
				"ideology": 
					var ideo = str(d.get("ideology", ""))
					if ideo == "demokracie": barva = Color("#2944A6")
					elif ideo == "komunismus": barva = Color("#D13A3A")
					elif ideo == "fasismus": barva = Color("#664229")
					elif ideo == "nacismus": barva = Color("4b4b4fff")
					elif ideo == "kralovstvi": barva = Color("#D4B04C")
					elif ideo == "autokracie": barva = Color("275b34ff")
					else: barva = Color("#666666") 
					barva.a = 1.0
				"recruitable_population": 
					var s = clamp(float(d.get("recruitable_population", 0)) / 500000.0, 0.0, 1.0)
					barva = Color(s, 0.8 * s, 0.1, 1.0)
				"relationships":
					var rel = 0.0
					if GameManager.has_method("ziskej_vztah_statu"):
						rel = GameManager.ziskej_vztah_statu(GameManager.hrac_stat, owner_tag)
					if rel >= 0.0:
						var s_pos = clamp(rel / 100.0, 0.0, 1.0)
						barva = Color(1.0 - (0.9 * s_pos), 1.0, 0.15, 1.0)
					else:
						var s_neg = clamp(absf(rel) / 100.0, 0.0, 1.0)
						barva = Color(1.0, 1.0 - (0.9 * s_neg), 0.15, 1.0)
				"terrain":
					var terrain = str(d.get("terrain", "")).strip_edges().to_lower()
					match terrain:
						"city":
							barva = Color(0.72, 0.16, 0.22, 1.0)
						"plains":
							barva = Color(0.79, 0.72, 0.36, 1.0)
						"forest":
							barva = Color(0.18, 0.52, 0.25, 1.0)
						"hills":
							barva = Color(0.56, 0.42, 0.29, 1.0)
						"mountains":
							barva = Color(0.46, 0.49, 0.53, 1.0)
						"desert":
							barva = Color(0.86, 0.74, 0.44, 1.0)
						"swamp":
							barva = Color(0.29, 0.42, 0.30, 1.0)
						_:
							barva = Color(0.52, 0.52, 0.52, 1.0)
				"resources":
					var resource = str(d.get("resource_type", "")).strip_edges().to_lower()
					match resource:
						"grain":
							barva = Color(0.92, 0.78, 0.30, 1.0)
						"timber":
							barva = Color(0.30, 0.58, 0.22, 1.0)
						"iron":
							barva = Color(0.56, 0.58, 0.62, 1.0)
						"coal":
							barva = Color(0.16, 0.18, 0.22, 1.0)
						"oil":
							barva = Color(0.10, 0.10, 0.10, 1.0)
						"gas":
							barva = Color(0.18, 0.72, 0.84, 1.0)
						"gold":
							barva = Color(0.98, 0.83, 0.24, 1.0)
						"uranium":
							barva = Color(0.50, 0.90, 0.40, 1.0)
						_:
							barva = Color(0.55, 0.55, 0.58, 1.0)
				"alliances":
					barva = _barva_aliance(owner_tag)
				
		data_image.set_pixel(prov_id, 0, barva)
	data_texture.update(data_image)
	occupation_texture.update(occupation_image)

# Main runtime logic lives here.
func _barva_aliance(owner_tag: String) -> Color:
	var alliances = GameManager.ziskej_aliance_statu(owner_tag)
	if alliances.size() == 0:
		return Color(0.18, 0.18, 0.18, 1.0)
	var skupina = alliances[0] as Dictionary
	var barva_str = str(skupina.get("color", "#4488ff"))
	return Color.html(barva_str)

# Core flow for this feature.
func dobyt_provincii(prov_id: int, novy_vlastnik: String, z_dev_nastroje: bool = false):
	var root = get_parent()
	if not root or not "provinces" in root: return
	
	if root.provinces.has(prov_id):
		var puvodni_vlastnik = str(root.provinces[prov_id].get("owner", "")).strip_edges().to_upper()
		var novy = novy_vlastnik.strip_edges().to_upper()
		var was_capital = bool(root.provinces[prov_id].get("is_capital", false))
		if novy == "" or puvodni_vlastnik == novy:
			return

		root.provinces[prov_id]["owner"] = novy
		if z_dev_nastroje and str(root.provinces[prov_id].get("type", "")).strip_edges().to_lower() != "sea":
			# Dev capture has no battle resolution, so remove stale garrison ownership.
			root.provinces[prov_id]["soldiers"] = 0
			root.provinces[prov_id]["army_owner"] = ""

		if root.has_method("_ziskej_profil_statu"):
			var profil = root._ziskej_profil_statu(novy)
			root.provinces[prov_id]["country_name"] = str(profil.get("country_name", novy))
			root.provinces[prov_id]["ideology"] = str(profil.get("ideology", ""))

		if z_dev_nastroje and was_capital and puvodni_vlastnik != "" and puvodni_vlastnik != "SEA" and novy != "SEA":
			GameManager.zaregistruj_obsazeni_hlavniho_mesta(puvodni_vlastnik, novy, prov_id)

		var mod = "political"
		if "aktualni_mapovy_mod" in root:
			mod = str(root.aktualni_mapovy_mod)
		aktualizuj_mapovy_mod(mod, root.provinces)
		print("Province ", prov_id, " was captured by ", novy_vlastnik)
		
		var labels_manager = root.get_node_or_null("CountryLabelsManager")
		var prov_labels = root.get_node_or_null("ProvinceLabels")
		if labels_manager and prov_labels:
			labels_manager.aktualizuj_labely_statu(root.provinces, prov_labels)



