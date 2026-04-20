# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends CanvasLayer
# this script drives a specific gameplay/UI area and keeps related logic together.

class StatsLineChart:
	extends Control
	signal chart_point_selected(info: Dictionary)
	signal chart_point_hovered(info: Dictionary)
	var series: Array = []
	var turn_values: Array = []
	var y_tick_count: int = 4
	var value_suffix: String = ""
	var value_decimals: int = 2
	var title: String = ""
	var _hover_info: Dictionary = {}

	# Initializes references, connects signals, and prepares default runtime state.
	func _ready() -> void:
		# Keep explicit chart sizes set by the stats popup; only apply defaults when unset.
		if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
			custom_minimum_size = Vector2(780, 170)
		mouse_filter = Control.MOUSE_FILTER_STOP

	# Paints custom control visuals.
	func _draw() -> void:
		var r = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.05, 0.08, 0.12, 0.75), true)
		draw_rect(r, Color(0.35, 0.47, 0.62, 0.9), false, 1.0)

		var plot_data = _build_plot_data()
		var valid_series = plot_data.get("valid_series", []) as Array
		if valid_series.is_empty():
			return
		var plot = plot_data.get("plot_rect", Rect2()) as Rect2

		for i in range(y_tick_count + 1):
			var t = float(i) / float(max(1, y_tick_count))
			var y = lerpf(plot.position.y + plot.size.y, plot.position.y, t)
			draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), Color(0.22, 0.30, 0.40, 0.55), 1.0)

		draw_line(Vector2(plot.position.x, plot.position.y), Vector2(plot.position.x, plot.position.y + plot.size.y), Color(0.55, 0.65, 0.78, 0.8), 1.0)
		draw_line(Vector2(plot.position.x, plot.position.y + plot.size.y), Vector2(plot.position.x + plot.size.x, plot.position.y + plot.size.y), Color(0.55, 0.65, 0.78, 0.8), 1.0)

		for s_any in valid_series:
			var s = s_any as Dictionary
			var c = s.get("color", Color(0.95, 0.95, 0.95, 1.0)) as Color
			var points = s.get("points", PackedVector2Array()) as PackedVector2Array
			if points.size() >= 2:
				draw_polyline(points, c, 2.0, true)
				draw_circle(points[points.size() - 1], 3.0, c)

		if not _hover_info.is_empty():
			var hp = _hover_info.get("point", Vector2(-1000, -1000)) as Vector2
			if hp.x > -999.0:
				draw_line(Vector2(hp.x, plot.position.y), Vector2(hp.x, plot.position.y + plot.size.y), Color(1, 1, 1, 0.25), 1.0)
				draw_line(Vector2(plot.position.x, hp.y), Vector2(plot.position.x + plot.size.x, hp.y), Color(1, 1, 1, 0.15), 1.0)
				draw_circle(hp, 4.0, Color(1, 1, 1, 0.95))
				var txt = str(_hover_info.get("text", ""))
				if txt != "":
					var f = get_theme_font("font")
					var fs = get_theme_font_size("font_size")
					if f:
						var text_size = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
						var pad = Vector2(8, 5)
						var box_pos = hp + Vector2(10, -text_size.y - 14)
						box_pos.x = clampf(box_pos.x, 4.0, maxf(4.0, size.x - text_size.x - pad.x * 2.0 - 4.0))
						box_pos.y = clampf(box_pos.y, 4.0, maxf(4.0, size.y - text_size.y - pad.y * 2.0 - 4.0))
						var box = Rect2(box_pos, text_size + pad * 2.0)
						draw_rect(box, Color(0.04, 0.06, 0.10, 0.95), true)
						draw_rect(box, Color(0.58, 0.70, 0.86, 0.95), false, 1.0)
						draw_string(f, box.position + Vector2(pad.x, pad.y + text_size.y - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.98, 1.0, 1.0))

	# Runs the local feature logic.
	func _gui_input(event: InputEvent) -> void:
		if series.is_empty():
			return
		if event is InputEventMouseMotion:
			_aktualizuj_hover(event.position)
		elif event is InputEventMouseButton:
			var mb = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_aktualizuj_hover(mb.position)
				if not _hover_info.is_empty():
					chart_point_selected.emit(_hover_info.duplicate(true))

	# Main runtime logic lives here.
	func _exit_tree() -> void:
		_hover_info.clear()

	# Feature logic entry point.
	func _build_plot_data() -> Dictionary:
		var valid_series: Array = []
		for s_any in series:
			var s0 = s_any as Dictionary
			var vals = s0.get("values", []) as Array
			if vals.size() >= 2:
				valid_series.append({
					"name": str(s0.get("name", "series")),
					"color": s0.get("color", Color(0.95, 0.95, 0.95, 1.0)),
					"values": vals
				})

		if valid_series.is_empty():
			return {"valid_series": []}

		var left_pad = 44.0
		var right_pad = 12.0
		var top_pad = 12.0
		var bottom_pad = 26.0
		var plot = Rect2(
			Vector2(left_pad, top_pad),
			Vector2(max(1.0, size.x - left_pad - right_pad), max(1.0, size.y - top_pad - bottom_pad))
		)

		var min_v = INF
		var max_v = -INF
		for s_any in valid_series:
			var vals = (s_any as Dictionary).get("values", []) as Array
			for v_any in vals:
				var v = float(v_any)
				min_v = minf(min_v, v)
				max_v = maxf(max_v, v)

		if not is_finite(min_v) or not is_finite(max_v):
			return {"valid_series": []}
		if absf(max_v - min_v) <= 0.000001:
			var pad = maxf(1.0, absf(max_v) * 0.08)
			min_v -= pad
			max_v += pad

		for i in range(valid_series.size()):
			var s = valid_series[i] as Dictionary
			var vals = s.get("values", []) as Array
			var pts: PackedVector2Array = []
			var count = vals.size()
			for j in range(count):
				var x_t = float(j) / float(max(1, count - 1))
				var x = plot.position.x + (plot.size.x * x_t)
				var v = float(vals[j])
				var y_t = (v - min_v) / (max_v - min_v)
				var y = plot.position.y + plot.size.y - (plot.size.y * y_t)
				pts.append(Vector2(x, y))
			s["points"] = pts
			valid_series[i] = s

		return {
			"valid_series": valid_series,
			"plot_rect": plot,
			"min": min_v,
			"max": max_v
		}

	# Display formatting helper.
	func _format_value(v: float) -> String:
		return "%.*f%s" % [max(0, value_decimals), v, value_suffix]

	# Refreshes cached/UI state.
	func _aktualizuj_hover(local_pos: Vector2) -> void:
		var plot_data = _build_plot_data()
		var valid_series = plot_data.get("valid_series", []) as Array
		if valid_series.is_empty():
			if not _hover_info.is_empty():
				_hover_info.clear()
				chart_point_hovered.emit({})
				queue_redraw()
			return

		var plot = plot_data.get("plot_rect", Rect2()) as Rect2
		if not plot.has_point(local_pos):
			if not _hover_info.is_empty():
				_hover_info.clear()
				chart_point_hovered.emit({})
				queue_redraw()
			return

		var best_dist = INF
		var best: Dictionary = {}
		for s_any in valid_series:
			var s = s_any as Dictionary
			var vals = s.get("values", []) as Array
			var pts = s.get("points", PackedVector2Array()) as PackedVector2Array
			for idx in range(pts.size()):
				var p = pts[idx]
				var d = p.distance_to(local_pos)
				if d < best_dist:
					best_dist = d
					var turn_val = idx + 1
					if idx < turn_values.size():
						turn_val = int(turn_values[idx])
					best = {
						"series": str(s.get("name", "series")),
						"series_index": idx,
						"turn": turn_val,
						"value": float(vals[idx]),
						"point": p,
						"color": s.get("color", Color.WHITE)
					}

		if best.is_empty():
			return
		var text = "%s | T%d | %s" % [
			str(best.get("series", "series")),
			int(best.get("turn", 0)),
			_format_value(float(best.get("value", 0.0)))
		]
		best["text"] = text
		_hover_info = best
		chart_point_hovered.emit(best.duplicate(true))
		queue_redraw()

@onready var money_label = $Panel/HBoxContainer/MoneyLabel
@onready var date_label = $Panel/HBoxContainer/DateLabel
@onready var player_turn_panel = $PlayerTurnPanel
@onready var next_btn = $PlayerTurnPanel/VBoxContainer/TurnRow/NextTurnButton
@onready var turn_row = $PlayerTurnPanel/VBoxContainer/TurnRow
@onready var turn_queue_flags = $PlayerTurnPanel/VBoxContainer/TurnQueueFlags
@onready var zpravy_btn = $Panel/HBoxContainer/ZpravyButton
@onready var top_panel = $Panel
@onready var map_modes_box = $Panel/HBoxContainer/MapModes
@onready var mode_btn_political = $Panel/HBoxContainer/MapModes/ModePolitical
@onready var mode_btn_population = $Panel/HBoxContainer/MapModes/ModePopulation
@onready var mode_btn_gdp = $Panel/HBoxContainer/MapModes/ModeGDP
@onready var mode_btn_ideology = $Panel/HBoxContainer/MapModes/ModeIdeology
@onready var mode_btn_recruits = $Panel/HBoxContainer/MapModes/ModeRecruits
@onready var mode_btn_relations = $Panel/HBoxContainer/MapModes/ModeRelations
@onready var mode_btn_terrain = $Panel/HBoxContainer/MapModes/ModeTerrain
@onready var mode_btn_resources = $Panel/HBoxContainer/MapModes/ModeResources
@onready var mode_btn_alliances = $Panel/HBoxContainer/MapModes/ModeAlliances
var _map_modes_dropdown: OptionButton

# Panel rows: 1) flag + next turn, 2) state name, 3) queue flags.
@onready var player_flag = $PlayerTurnPanel/VBoxContainer/TurnRow/PlayerFlag
@onready var player_name = $PlayerTurnPanel/VBoxContainer/PlayerName

var flag_texture_cache: Dictionary = {}
var ideology_flag_path_index: Dictionary = {}
var ideology_flag_index_ready: bool = false
var _last_seen_player_tag: String = ""
var _player_focus_tween: Tween
var _turn_busy_indicator: Label
var _is_turn_processing: bool = false
var _turn_busy_suppressed: bool = false
var _turn_busy_anim_time: float = 0.0
var _turn_busy_anim_step: int = 0
var _map_mode_white_icon_cache: Dictionary = {}
var _finance_tooltip_panel: PanelContainer
var _finance_tooltip_text: RichTextLabel
var _finance_tooltip_visible: bool = false
var _stats_button: Button
var _stats_popup: PopupPanel
var _stats_state_option: OptionButton
var _stats_last_update_label: Label
var _stats_report: RichTextLabel
var _stats_scroll: ScrollContainer
var _stats_content: VBoxContainer
var _stats_tabs: TabContainer
var _stats_overview_tab: VBoxContainer
var _stats_charts_tab: VBoxContainer
var _stats_finance_tab: VBoxContainer
var _stats_kpi_grid: GridContainer
var _stats_kpi_labels: Dictionary = {}
var _stats_time_window_option: OptionButton
var _stats_compare_metric_option: OptionButton
var _stats_compare_state_list: ItemList
var _stats_compare_chart: StatsLineChart
var _stats_compare_hint: Label
var _stats_chart_growth: StatsLineChart
var _stats_chart_gdp: StatsLineChart
var _stats_chart_population: StatsLineChart
var _stats_chart_recruits_army: StatsLineChart
var _stats_chart_finance: StatsLineChart
var _stats_income_breakdown: VBoxContainer
var _stats_expense_breakdown: VBoxContainer
var _stats_country_options: Array = []
var _stats_history_by_state: Dictionary = {}
var _stats_last_recorded_turn_by_state: Dictionary = {}
var _calendar_start_day: int = 1
var _calendar_start_month: int = 1
var _calendar_start_year: int = 2026

const TURN_BUSY_FRAMES := ["[turn... ]", "[turn.. .]", "[turn. ..]", "[turn ...]"]
const STATS_HISTORY_LIMIT := 84
const STATS_COLOR_GDP := Color(0.95, 0.77, 0.25, 1.0)
const STATS_COLOR_POP := Color(0.38, 0.82, 0.92, 1.0)
const STATS_COLOR_RECRUITS := Color(0.30, 0.90, 0.57, 1.0)
const STATS_COLOR_ARMY := Color(0.96, 0.38, 0.34, 1.0)
const STATS_COLOR_INCOME := Color(0.41, 0.94, 0.48, 1.0)
const STATS_COLOR_EXPENSE := Color(0.98, 0.52, 0.33, 1.0)
const STATS_COLOR_PROFIT := Color(0.80, 0.82, 0.92, 1.0)
const STATS_COLOR_GROWTH_GDP := Color(1.00, 0.89, 0.44, 1.0)
const STATS_COLOR_GROWTH_POP := Color(0.62, 0.90, 1.00, 1.0)
const STATS_PANEL_BG := Color(0.06, 0.10, 0.15, 0.96)
const STATS_PANEL_BORDER := Color(0.27, 0.42, 0.60, 0.95)
const MAP_MODE_BUTTON_HEIGHT := 38
const MAP_MODE_BUTTON_SELECTED_HEIGHT := 45
const MAP_MODE_BUTTON_WIDTH := 50
const MAP_MODE_TO_BUTTON_PATHS := {
	"political": "ModePolitical",
	"population": "ModePopulation",
	"gdp": "ModeGDP",
	"ideology": "ModeIdeology",
	"recruitable_population": "ModeRecruits",
	"relationships": "ModeRelations",
	"terrain": "ModeTerrain",
	"resources": "ModeResources",
	"alliances": "ModeAlliances"
}
const MAP_MODE_DISPLAY_NAMES := {
	"political": "Political Mode",
	"population": "Population Mode",
	"gdp": "GDP Mode",
	"ideology": "Ideology Mode",
	"recruitable_population": "Recruitable Population Mode",
	"relationships": "Diplomatic Relations Mode",
	"terrain": "Terrain Mode",
	"resources": "Resources Mode",
	"alliances": "Alliances Mode"
}
const MAP_MODE_HOTKEYS := {
	"political": "1",
	"population": "2",
	"gdp": "3",
	"ideology": "4",
	"recruitable_population": "5",
	"relationships": "6",
	"terrain": "7",
	"resources": "8",
	"alliances": "9"
}
const MAP_MODE_ICON_PATHS := {
	"political": "res://map_data/map.svg",
	"population": "res://map_data/users.svg",
	"gdp": "res://map_data/dollar-sign.svg",
	"ideology": "res://map_data/flag.svg",
	"recruitable_population": "res://map_data/user-round-plus.svg",
	"relationships": "res://map_data/annoyed.svg",
	"terrain": "res://map_data/mountain.svg",
	"resources": "res://map_data/pickaxe.svg",
	"alliances": "res://map_data/port_icon.svg"
}
const MAP_MODE_ORDER := [
	"political",
	"population",
	"gdp",
	"ideology",
	"recruitable_population",
	"relationships",
	"terrain",
	"resources",
	"alliances"
]
const MAP_MODE_DROPDOWN_BREAKPOINT := 1817.0

# Feature logic entry point.
func _cached_texture(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not flag_texture_cache.has(path):
		flag_texture_cache[path] = load(path)
	return flag_texture_cache[path]

# Main runtime logic lives here.
func _normalizuj_ideologii(ideologie: String) -> String:
	var raw = ideologie.strip_edges().to_lower()
	match raw:
		"democracy", "democratic":
			return "demokracie"
		"autocracy", "autocratic", "dictatorship":
			return "autokracie"
		"communism", "communist", "socialism":
			return "komunismus"
		"fascism", "fascist":
			return "fasismus"
		"nazism", "nazismus", "nazi", "national_socialism", "nacismum":
			return "nacismus"
		"kingdom", "monarchy", "royal", "kralostvi":
			return "kralovstvi"
		_:
			return raw

# Handles this gameplay/UI path.
func _ensure_ideology_flag_index() -> void:
	if ideology_flag_index_ready:
		return
	ideology_flag_index_ready = true
	ideology_flag_path_index.clear()

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
		if ideo == "":
			continue

		var key = "%s|%s" % [tag, ideo]
		var path = "res://map_data/FlagsIdeology/%s" % file_name
		if not ideology_flag_path_index.has(key):
			ideology_flag_path_index[key] = path
			continue
		var current = str(ideology_flag_path_index[key]).to_lower()
		if current.ends_with(".png") and lower.ends_with(".svg"):
			ideology_flag_path_index[key] = path
	dir.list_dir_end()

# Initializes references, connects signals, and prepares default runtime state.
func _ready():
	# Connect button clicks and GameManager signals
	_inicializuj_startovni_datum_hry()
	if next_btn and not next_btn.pressed.is_connected(_on_next_turn_pressed):
		next_btn.pressed.connect(_on_next_turn_pressed)
	if zpravy_btn and not zpravy_btn.pressed.is_connected(_on_zpravy_pressed):
		zpravy_btn.pressed.connect(_on_zpravy_pressed)
	if zpravy_btn:
		# Prevent accidental Space/Enter activation while ending turns.
		zpravy_btn.focus_mode = Control.FOCUS_NONE
		zpravy_btn.toggle_mode = false
	_zapoj_tlacitka_mapovych_modu()
	_vytvor_dropdown_mapovych_modu()
	_napoj_signal_mapoveho_modu()
	_vytvor_financni_tooltip_panel()
	_napoj_financni_hover()
	_vytvor_statistics_tlacitko()
	_vytvor_statistics_popup()
	GameManager.kolo_zmeneno.connect(aktualizuj_ui)
	if GameManager.has_signal("zpracovani_tahu_zmeneno") and not GameManager.zpracovani_tahu_zmeneno.is_connected(_on_zpracovani_tahu_zmeneno):
		GameManager.zpracovani_tahu_zmeneno.connect(_on_zpracovani_tahu_zmeneno)
	_vytvor_turn_busy_indicator()
	_on_zpracovani_tahu_zmeneno(bool(GameManager.zpracovava_se_tah))
	_nastav_tooltipy_ui()
	var viewport = get_viewport()
	if viewport and viewport.has_signal("size_changed") and not viewport.size_changed.is_connected(_aktualizuj_sirku_panelu_hrace):
		viewport.size_changed.connect(_aktualizuj_sirku_panelu_hrace)
	_aktualizuj_sirku_panelu_hrace()
	aktualizuj_ui()
	call_deferred("_registruj_anchor_zprav")
	call_deferred("_aktualizuj_stav_tlacitek_modu")

# Applies incoming data to runtime state.
func _nastav_tooltipy_ui() -> void:
	if money_label:
		money_label.tooltip_text = ""
	if _stats_button:
		_stats_button.tooltip_text = "Open country statistics and trends."
	if date_label:
		date_label.tooltip_text = "In-game date. Every turn advances one month."
	if next_btn:
		next_btn.tooltip_text = "End your turn and process the next one."
	if turn_queue_flags:
		turn_queue_flags.tooltip_text = "Turn order for local multiplayer players."
	if zpravy_btn:
		zpravy_btn.tooltip_text = "Open the messages center (my country / global)."
	if player_flag:
		player_flag.tooltip_text = "Flag of the country you currently control."
	if player_name:
		player_name.tooltip_text = "Name of the country you currently play as."
	_nastav_tooltipy_mapovych_modu()
	TooltipUtils.apply_default_tooltips(self)
	# Money label uses only custom hover panel, never default Godot tooltip.
	if money_label:
		money_label.tooltip_text = ""

# Handles this gameplay/UI path.
func _inicializuj_startovni_datum_hry() -> void:
	var datum: Dictionary = Time.get_datetime_dict_from_system()
	_calendar_start_day = clampi(int(datum.get("day", 1)), 1, 31)
	_calendar_start_month = clampi(int(datum.get("month", 1)), 1, 12)
	_calendar_start_year = int(datum.get("year", 2026))

# Read-only data accessor.
func _ziskej_text_data_pro_kolo(kolo: int) -> String:
	var offset_mesicu = maxi(0, kolo - 1)
	var month_index = (_calendar_start_month - 1) + offset_mesicu
	var month = int(month_index % 12) + 1
	var year = _calendar_start_year + int(floor(float(month_index) / 12.0))
	return "Date: %02d.%02d.%04d (Turn %d)" % [_calendar_start_day, month, year, maxi(1, kolo)]

# Pulls current state data.
func _ziskej_jmeno_statu_pro_frontu(tag: String) -> String:
	var wanted = tag.strip_edges().to_upper()
	if wanted == "":
		return ""
	if wanted == str(GameManager.hrac_stat).strip_edges().to_upper() and str(GameManager.hrac_jmeno).strip_edges() != "":
		return str(GameManager.hrac_jmeno).strip_edges()

	var data = GameManager.map_data
	if data is Dictionary:
		for prov_id in data:
			var d = data[prov_id] as Dictionary
			if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
				continue
			var state_name = str(d.get("country_name", wanted)).strip_edges()
			if state_name != "":
				return state_name
	return wanted

# Runs the local feature logic.
func _sestav_text_fronty_tahu() -> String:
	var hraci = GameManager.lokalni_hraci_staty
	if not (hraci is Array) or hraci.size() <= 1:
		return "Queue: Singleplayer"

	var aktivni_idx = clampi(int(GameManager.aktivni_hrac_index), 0, hraci.size() - 1)
	var casti: Array[String] = []
	for i in range(hraci.size()):
		var idx = (aktivni_idx + i) % hraci.size()
		var tag = str(hraci[idx]).strip_edges().to_upper()
		var state_name = _ziskej_jmeno_statu_pro_frontu(tag)
		if i == 0:
			casti.append("[NOW] %s" % state_name)
		else:
			casti.append(state_name)
	return "Queue: %s" % " -> ".join(casti)

# Pulls current state data.
func _ziskej_texturu_vlajky_fronty(tag: String):
	var cisty_tag = tag.strip_edges().to_upper()
	for path in ["res://map_data/Flags/%s.svg" % cisty_tag, "res://map_data/Flags/%s.png" % cisty_tag]:
		var tex = _cached_texture(path)
		if tex:
			return tex
	return null

# Resets transient runtime/UI data.
func _vycisti_frontu_tahu_vlajek() -> void:
	if turn_queue_flags == null:
		return
	for child in turn_queue_flags.get_children():
		child.queue_free()

# Runs the local feature logic.
func _pridej_vlajku_do_fronty(tag: String, aktivni: bool) -> void:
	if turn_queue_flags == null:
		return
	var tex = _ziskej_texturu_vlajky_fronty(tag)
	if tex == null:
		return

	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(40, 26)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = tex
	rect.tooltip_text = _ziskej_jmeno_statu_pro_frontu(tag)
	if aktivni:
		rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		rect.modulate = Color(0.62, 0.62, 0.62, 0.52)
	turn_queue_flags.add_child(rect)

# Refreshes cached/UI state.
func _aktualizuj_frontu_tahu_vlajky() -> void:
	if turn_queue_flags == null:
		return
	_vycisti_frontu_tahu_vlajek()

	var hraci = GameManager.lokalni_hraci_staty
	if not (hraci is Array) or hraci.size() <= 1:
		turn_queue_flags.visible = false
		return

	turn_queue_flags.visible = true
	var aktivni_idx = clampi(int(GameManager.aktivni_hrac_index), 0, hraci.size() - 1)
	# Show only upcoming players in the queue, not the player currently taking the turn.
	for i in range(1, hraci.size()):
		var idx = (aktivni_idx + i) % hraci.size()
		var tag = str(hraci[idx]).strip_edges().to_upper()
		_pridej_vlajku_do_fronty(tag, false)

# Recomputes values from current data.
func _aktualizuj_sirku_panelu_hrace() -> void:
	if player_turn_panel == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return
	var vp_width = viewport.get_visible_rect().size.x
	_aktualizuj_responzivni_topbar(vp_width)

	var row_separation = 8.0
	if turn_row:
		row_separation = float(turn_row.get_theme_constant("separation"))
	var flag_width = 68.0
	if player_flag:
		flag_width = maxf(flag_width, player_flag.custom_minimum_size.x)
	var button_width = 180.0
	if next_btn:
		button_width = maxf(button_width, next_btn.custom_minimum_size.x)
	var busy_width = 0.0
	if _turn_busy_indicator and _turn_busy_indicator.visible and not _turn_busy_suppressed:
		busy_width = _ziskej_sirku_turn_busy_indicatoru()
		_turn_busy_indicator.custom_minimum_size.x = busy_width
	var name_width = 90.0
	if player_name:
		var font = player_name.get_theme_font("font")
		var font_size = player_name.get_theme_font_size("font_size")
		var text_width = 0.0
		if font:
			text_width = font.get_string_size(player_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		else:
			text_width = player_name.get_minimum_size().x
		# Keep room for short names but prevent very long names from exploding width.
		name_width = clampf(text_width + 8.0, 90.0, 360.0)

	var queue_estimated = 0.0
	if turn_queue_flags and turn_queue_flags.visible:
		# Queue wraps in HFlowContainer, so it should not force extra panel width.
		queue_estimated = 120.0

	# First row: flag + next button.
	var turn_row_estimated = flag_width + button_width + (busy_width if busy_width > 0.0 else 0.0) + row_separation * (2.0 if busy_width > 0.0 else 1.0) + 18.0
	# Second row is full-width state name; third row is queue.
	var second_row_estimated = name_width + 18.0

	var desired_width = maxf(320.0, maxf(turn_row_estimated, maxf(second_row_estimated, queue_estimated)))
	var max_width = minf(560.0, maxf(320.0, vp_width - 24.0))
	desired_width = clampf(desired_width, 320.0, max_width)

	player_turn_panel.custom_minimum_size.x = desired_width
	player_turn_panel.offset_left = player_turn_panel.offset_right - desired_width

# Updates derived state and UI.
func _aktualizuj_responzivni_topbar(vp_width: float) -> void:
	var compact = vp_width < 1360.0
	var narrow = vp_width < MAP_MODE_DROPDOWN_BREAKPOINT
	var tiny = vp_width < 980.0

	if map_modes_box:
		map_modes_box.visible = not narrow
	if _map_modes_dropdown:
		_map_modes_dropdown.visible = narrow
		_map_modes_dropdown.custom_minimum_size.x = 170.0 if tiny else (190.0 if compact else 210.0)
		_map_modes_dropdown.add_theme_font_size_override("font_size", 14 if tiny else (15 if compact else 16))

	if money_label:
		money_label.custom_minimum_size.x = 300.0 if compact else 425.0
		money_label.add_theme_font_size_override("font_size", 24 if compact else 31)

	if date_label:
		date_label.visible = not tiny
		date_label.custom_minimum_size.x = 240.0 if compact else 350.0
		date_label.add_theme_font_size_override("font_size", 20 if compact else 24)

	if zpravy_btn:
		zpravy_btn.visible = vp_width >= 860.0
		zpravy_btn.custom_minimum_size.x = 130.0 if compact else 175.0
		zpravy_btn.add_theme_font_size_override("font_size", 20 if compact else 26)

# Recomputes values from current data.
func _aktualizuj_zarovnani_nazvu_statu() -> void:
	if player_name == null:
		return

	var text_width = 0.0
	var font = player_name.get_theme_font("font")
	var font_size = player_name.get_theme_font_size("font_size")
	if font:
		text_width = font.get_string_size(player_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	else:
		text_width = player_name.get_minimum_size().x

	var flag_width = 68.0
	if player_flag:
		flag_width = maxf(flag_width, player_flag.custom_minimum_size.x)

	# If the name fits in (or near) flag width, center it under the flag.
	if text_width <= (flag_width + 10.0):
		player_name.size_flags_horizontal = 0
		player_name.custom_minimum_size.x = flag_width
		player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_name.custom_minimum_size.x = 0.0
		player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

# Read-only data accessor.
func _ziskej_game_ui_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.find_child("GameUI", true, false)

# Main runtime logic lives here.
func _registruj_anchor_zprav() -> void:
	var game_ui = _ziskej_game_ui_node()
	if game_ui and game_ui.has_method("nastav_zpravy_anchor_control"):
		game_ui.nastav_zpravy_anchor_control(zpravy_btn)

# Reacts to incoming events.
func _on_zpravy_pressed() -> void:
	var game_ui = _ziskej_game_ui_node()
	if game_ui and game_ui.has_method("prepni_zpravy_panel"):
		game_ui.prepni_zpravy_panel()

# Writes new values and refreshes related state.
func _nastav_tooltipy_mapovych_modu() -> void:
	if map_modes_box == null:
		return
	for mod in MAP_MODE_TO_BUTTON_PATHS.keys():
		var btn_name = str(MAP_MODE_TO_BUTTON_PATHS[mod])
		var btn = map_modes_box.get_node_or_null(btn_name)
		if btn and btn is Button:
			(btn as Button).tooltip_text = "%s | Hotkey: %s" % [
				str(MAP_MODE_DISPLAY_NAMES.get(mod, mod)),
				str(MAP_MODE_HOTKEYS.get(mod, "-"))
			]
	if _map_modes_dropdown:
		_map_modes_dropdown.tooltip_text = "Map mode menu (auto-shown on small screens)."

# Creates required nodes and connects signals.
func _vytvor_dropdown_mapovych_modu() -> void:
	if _map_modes_dropdown != null:
		return
	if top_panel == null:
		return
	var box = top_panel.get_node_or_null("HBoxContainer") as HBoxContainer
	if box == null:
		return

	_map_modes_dropdown = OptionButton.new()
	_map_modes_dropdown.name = "MapModesDropdown"
	_map_modes_dropdown.visible = false
	_map_modes_dropdown.focus_mode = Control.FOCUS_NONE
	_map_modes_dropdown.custom_minimum_size = Vector2(210, 38)
	_map_modes_dropdown.add_theme_font_size_override("font_size", 16)
	if not _map_modes_dropdown.item_selected.is_connected(_on_map_mode_dropdown_selected):
		_map_modes_dropdown.item_selected.connect(_on_map_mode_dropdown_selected)

	for mod in MAP_MODE_ORDER:
		var label = str(MAP_MODE_DISPLAY_NAMES.get(mod, mod))
		_map_modes_dropdown.add_item(label)
		var idx = _map_modes_dropdown.item_count - 1
		_map_modes_dropdown.set_item_metadata(idx, mod)

	box.add_child(_map_modes_dropdown)
	if map_modes_box and map_modes_box.get_parent() == box:
		box.move_child(_map_modes_dropdown, map_modes_box.get_index() + 1)

# Callback for UI/game events.
func _on_map_mode_dropdown_selected(index: int) -> void:
	if _map_modes_dropdown == null:
		return
	if index < 0 or index >= _map_modes_dropdown.item_count:
		return
	var mod = str(_map_modes_dropdown.get_item_metadata(index))
	if mod == "":
		return
	_prepni_mapovy_mod(mod)

# Read-only data accessor.
func _ziskej_cesty_ikony_map_modu(mod: String) -> Array:
	# Relationships icon can be replaced later by adding one of these files.
	if mod == "relationships":
		return [
			"res://map_data/annoyed.svg",
			"res://map_data/thumbs-up-down.svg",
			"res://map_data/thumbs-up.svg",
			"res://map_data/thumbs-down.svg",
			"res://map_data/users.svg"
		]
	if MAP_MODE_ICON_PATHS.has(mod):
		return [str(MAP_MODE_ICON_PATHS[mod])]
	return []

# Load pass with basic validation.
func _nacti_bilou_ikonu(path: String):
	if path == "":
		return null
	if _map_mode_white_icon_cache.has(path):
		return _map_mode_white_icon_cache[path]

	var tex = _cached_texture(path)
	if tex == null:
		return null

	var src_image = tex.get_image()
	if src_image == null:
		_map_mode_white_icon_cache[path] = tex
		return tex

	var out_img = src_image.duplicate()
	for y in range(out_img.get_height()):
		for x in range(out_img.get_width()):
			var px = out_img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			out_img.set_pixel(x, y, Color(1, 1, 1, px.a))

	var out_tex = ImageTexture.create_from_image(out_img)
	_map_mode_white_icon_cache[path] = out_tex
	return out_tex

# Data/resource load and sanity checks.
func _nacti_ikonu_map_modu(mod: String):
	for path in _ziskej_cesty_ikony_map_modu(mod):
		var tex = _nacti_bilou_ikonu(str(path))
		if tex:
			return tex
	return null

# Writes new values and refreshes related state.
func _nastav_hotkey_badge(btn: Button, hotkey: String) -> void:
	if btn == null:
		return

	var badge = btn.get_node_or_null("HotkeyBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "HotkeyBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.z_index = 20
		btn.add_child(badge)

	badge.text = str(hotkey)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.95))
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)

	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -15.0
	badge.offset_right = -2.0
	badge.offset_top = -13.0
	badge.offset_bottom = -1.0

# Applies updates and syncs dependent state.
func _nastav_ikony_mapovych_modu() -> void:
	if map_modes_box == null:
		return
	for mod in MAP_MODE_TO_BUTTON_PATHS.keys():
		var btn_name = str(MAP_MODE_TO_BUTTON_PATHS[mod])
		var btn = map_modes_box.get_node_or_null(btn_name)
		if btn and btn is Button:
			var b = btn as Button
			b.text = ""
			b.icon = _nacti_ikonu_map_modu(mod)
			b.expand_icon = false
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 1))
			b.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 1))
			b.add_theme_color_override("icon_pressed_color", Color(1, 1, 1, 1))
			b.add_theme_color_override("icon_focus_color", Color(1, 1, 1, 1))
			b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
			b.custom_minimum_size = Vector2(MAP_MODE_BUTTON_WIDTH, MAP_MODE_BUTTON_HEIGHT)
			_nastav_hotkey_badge(b, str(MAP_MODE_HOTKEYS.get(mod, "")))

# Core flow for this feature.
func _napoj_signal_mapoveho_modu() -> void:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return
	if map_loader.has_signal("mapovy_mod_zmenen") and not map_loader.mapovy_mod_zmenen.is_connected(_on_mapovy_mod_zmenen):
		map_loader.mapovy_mod_zmenen.connect(_on_mapovy_mod_zmenen)

# Reacts to incoming events.
func _on_mapovy_mod_zmenen(mod: String) -> void:
	_aktualizuj_stav_tlacitek_modu(mod)

# Read-only data accessor.
func _ziskej_map_loader() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("nastav_mapovy_mod"):
		return scene_root
	if scene_root:
		var map_node = scene_root.find_child("map2D", true, false)
		if map_node and map_node.has_method("nastav_mapovy_mod"):
			return map_node
	return null

# Applies mode change side effects.
func _prepni_mapovy_mod(mod: String) -> void:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return
	if map_loader.has_method("nastav_mapovy_mod"):
		map_loader.nastav_mapovy_mod(mod)
	_aktualizuj_stav_tlacitek_modu(mod)

# Returns current runtime data.
func _ziskej_aktualni_mapovy_mod() -> String:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return "political"
	return str(map_loader.get("aktualni_mapovy_mod"))

# Recomputes values from current data.
func _aktualizuj_stav_tlacitek_modu(active_mode: String = "") -> void:
	var mode = active_mode if active_mode != "" else _ziskej_aktualni_mapovy_mod()
	if map_modes_box:
		for child in map_modes_box.get_children():
			if child is Button:
				var b = child as Button
				b.button_pressed = false
				b.custom_minimum_size = Vector2(MAP_MODE_BUTTON_WIDTH, MAP_MODE_BUTTON_HEIGHT)
		for mod in MAP_MODE_TO_BUTTON_PATHS.keys():
			if mod != mode:
				continue
			var btn_name = str(MAP_MODE_TO_BUTTON_PATHS[mod])
			var btn = map_modes_box.get_node_or_null(btn_name)
			if btn and btn is Button:
				var active_btn = btn as Button
				active_btn.button_pressed = true
				active_btn.custom_minimum_size = Vector2(MAP_MODE_BUTTON_WIDTH, MAP_MODE_BUTTON_SELECTED_HEIGHT)
			break

	if _map_modes_dropdown:
		for i in range(_map_modes_dropdown.item_count):
			if str(_map_modes_dropdown.get_item_metadata(i)) == mode:
				_map_modes_dropdown.select(i)
				break

# Feature logic entry point.
func _zapoj_tlacitka_mapovych_modu() -> void:
	if map_modes_box == null:
		return
	_nastav_ikony_mapovych_modu()
	_nastav_tooltipy_mapovych_modu()
	for child in map_modes_box.get_children():
		if child is Button:
			var btn = child as Button
			btn.toggle_mode = true

	if mode_btn_political and not mode_btn_political.pressed.is_connected(_on_mode_political_pressed):
		mode_btn_political.pressed.connect(_on_mode_political_pressed)
	if mode_btn_population and not mode_btn_population.pressed.is_connected(_on_mode_population_pressed):
		mode_btn_population.pressed.connect(_on_mode_population_pressed)
	if mode_btn_gdp and not mode_btn_gdp.pressed.is_connected(_on_mode_gdp_pressed):
		mode_btn_gdp.pressed.connect(_on_mode_gdp_pressed)
	if mode_btn_ideology and not mode_btn_ideology.pressed.is_connected(_on_mode_ideology_pressed):
		mode_btn_ideology.pressed.connect(_on_mode_ideology_pressed)
	if mode_btn_recruits and not mode_btn_recruits.pressed.is_connected(_on_mode_recruits_pressed):
		mode_btn_recruits.pressed.connect(_on_mode_recruits_pressed)
	if mode_btn_relations and not mode_btn_relations.pressed.is_connected(_on_mode_relations_pressed):
		mode_btn_relations.pressed.connect(_on_mode_relations_pressed)
	if mode_btn_terrain and not mode_btn_terrain.pressed.is_connected(_on_mode_terrain_pressed):
		mode_btn_terrain.pressed.connect(_on_mode_terrain_pressed)
	if mode_btn_resources and not mode_btn_resources.pressed.is_connected(_on_mode_resources_pressed):
		mode_btn_resources.pressed.connect(_on_mode_resources_pressed)
	if mode_btn_alliances and not mode_btn_alliances.pressed.is_connected(_on_mode_alliances_pressed):
		mode_btn_alliances.pressed.connect(_on_mode_alliances_pressed)

	_aktualizuj_stav_tlacitek_modu()

# Reacts to incoming events.
func _on_mode_political_pressed() -> void:
	_prepni_mapovy_mod("political")

# Event handler for user or game actions.
func _on_mode_population_pressed() -> void:
	_prepni_mapovy_mod("population")

# Event handler for user or game actions.
func _on_mode_gdp_pressed() -> void:
	_prepni_mapovy_mod("gdp")

# Handles this signal callback.
func _on_mode_ideology_pressed() -> void:
	_prepni_mapovy_mod("ideology")

# Triggered by a UI/game signal.
func _on_mode_recruits_pressed() -> void:
	_prepni_mapovy_mod("recruitable_population")

# Callback for UI/game events.
func _on_mode_relations_pressed() -> void:
	_prepni_mapovy_mod("relationships")

# Handles this signal callback.
func _on_mode_terrain_pressed() -> void:
	_prepni_mapovy_mod("terrain")

# Triggered by a UI/game signal.
func _on_mode_resources_pressed() -> void:
	_prepni_mapovy_mod("resources")

# Handles this signal callback.
func _on_mode_alliances_pressed() -> void:
	_prepni_mapovy_mod("alliances")

# Refreshes cached/UI state.
func aktualizuj_ui():
	# Update money and date counters
	# topbar balance bereme z cashflow projekce, ne z cistyho profitu, at sedi s kasou.
	var topbar_balance = float(GameManager.celkovy_prijem)
	if GameManager.has_method("ziskej_financni_rozpad_statu"):
		var finance = GameManager.ziskej_financni_rozpad_statu(str(GameManager.hrac_stat)) as Dictionary
		if bool(finance.get("ok", false)):
			topbar_balance = float(finance.get("cashflow", finance.get("profit", topbar_balance)))
	money_label.text = "Funds: %.2f M USD (+%.2f)" % [GameManager.statni_kasa, topbar_balance]
	if date_label:
		date_label.text = _ziskej_text_data_pro_kolo(int(GameManager.aktualni_kolo))
	
	# Update player info with dynamic data from GameManager
	var aktivni_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	nastav_hrace(aktivni_tag, GameManager.hrac_jmeno, GameManager.hrac_ideologie)
	_aktualizuj_zarovnani_nazvu_statu()
	_aktualizuj_frontu_tahu_vlajky()
	_aktualizuj_sirku_panelu_hrace()
	if _finance_tooltip_visible:
		_aktualizuj_financni_tooltip_text()
		_aktualizuj_financni_tooltip_pozici()

	# In local multiplayer, center camera when control switches to another human player.
	if GameManager.lokalni_hraci_staty.size() > 1 and _last_seen_player_tag != "" and aktivni_tag != _last_seen_player_tag:
		_vycentruj_kameru_na_stat(aktivni_tag, true)

	_last_seen_player_tag = aktivni_tag
	_aktualizuj_statistiky_kola()
	if _stats_popup and _stats_popup.visible:
		# report obnovujem jen kdyz je popup otevreny, jinak by to zbytecne zralo vykon.
		_aktualizuj_statistics_report()

# Callback for UI/game events.
func _on_next_turn_pressed():
	if GameManager.has_method("pozaduj_ukonceni_kola"):
		GameManager.pozaduj_ukonceni_kola()
	else:
		GameManager.ukonci_kolo()

# Construct/setup block for required nodes.
func _vytvor_statistics_tlacitko() -> void:
	if _stats_button != null:
		return
	if not is_instance_valid(top_panel):
		return
	var box = top_panel.get_node_or_null("HBoxContainer") as HBoxContainer
	if box == null:
		return

	_stats_button = Button.new()
	_stats_button.name = "StatisticsButton"
	_stats_button.text = "Statistics"
	_stats_button.custom_minimum_size = Vector2(170, 0)
	_stats_button.add_theme_font_size_override("font_size", 22)
	_stats_button.focus_mode = Control.FOCUS_NONE
	if not _stats_button.pressed.is_connected(_on_statistics_pressed):
		_stats_button.pressed.connect(_on_statistics_pressed)

	box.add_child(_stats_button)
	if is_instance_valid(zpravy_btn) and zpravy_btn.get_parent() == box:
		# Keep statistics directly adjacent to the messages button in the right section.
		var msg_idx = zpravy_btn.get_index()
		box.move_child(_stats_button, msg_idx + 1)

# Builds UI objects and default wiring.
func _vytvor_statistics_popup() -> void:
	if _stats_popup != null:
		return

	_stats_popup = PopupPanel.new()
	_stats_popup.name = "StatisticsPopup"
	_stats_popup.size = Vector2i(1620, 1140)
	_stats_popup.unresizable = false
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = STATS_PANEL_BG
	popup_style.border_color = STATS_PANEL_BORDER
	popup_style.border_width_left = 1
	popup_style.border_width_top = 1
	popup_style.border_width_right = 1
	popup_style.border_width_bottom = 1
	popup_style.corner_radius_top_left = 10
	popup_style.corner_radius_top_right = 10
	popup_style.corner_radius_bottom_left = 10
	popup_style.corner_radius_bottom_right = 10
	popup_style.content_margin_left = 10
	popup_style.content_margin_right = 10
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	_stats_popup.add_theme_stylebox_override("panel", popup_style)
	# popup je vetsi schvalne; grafy jinak nejsou citelny na 1080p pri vice seriich.

	var frame := VBoxContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_constant_override("separation", 10)
	_stats_popup.add_child(frame)

	var header_wrap := PanelContainer.new()
	header_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(header_wrap)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.09, 0.15, 0.24, 0.96)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_style.content_margin_left = 12
	header_style.content_margin_right = 12
	header_style.content_margin_top = 8
	header_style.content_margin_bottom = 8
	header_wrap.add_theme_stylebox_override("panel", header_style)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	header_wrap.add_child(header_box)
	var title_lbl := Label.new()
	title_lbl.text = "Country Statistics Dashboard"
	title_lbl.add_theme_font_size_override("font_size", 24)
	header_box.add_child(title_lbl)
	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Turn-by-turn overview with trends, finance structure, and cross-state ranking"
	subtitle_lbl.add_theme_font_size_override("font_size", 14)
	subtitle_lbl.modulate = Color(0.82, 0.88, 0.96, 0.92)
	header_box.add_child(subtitle_lbl)

	var controls_row := HBoxContainer.new()
	controls_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_theme_constant_override("separation", 10)
	frame.add_child(controls_row)

	var state_caption := Label.new()
	state_caption.text = "Country:"
	state_caption.add_theme_font_size_override("font_size", 16)
	controls_row.add_child(state_caption)

	_stats_state_option = OptionButton.new()
	_stats_state_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_state_option.custom_minimum_size = Vector2(280, 38)
	_stats_state_option.add_theme_font_size_override("font_size", 16)
	if not _stats_state_option.item_selected.is_connected(_on_statistics_state_selected):
		_stats_state_option.item_selected.connect(_on_statistics_state_selected)
	controls_row.add_child(_stats_state_option)

	var history_caption := Label.new()
	history_caption.text = "History:"
	history_caption.add_theme_font_size_override("font_size", 15)
	controls_row.add_child(history_caption)

	_stats_time_window_option = OptionButton.new()
	_stats_time_window_option.custom_minimum_size = Vector2(150, 38)
	_stats_time_window_option.add_theme_font_size_override("font_size", 15)
	_stats_time_window_option.add_item("Last 12")
	_stats_time_window_option.add_item("Last 24")
	_stats_time_window_option.add_item("Last 48")
	_stats_time_window_option.add_item("All")
	_stats_time_window_option.select(1)
	if not _stats_time_window_option.item_selected.is_connected(_on_statistics_time_window_selected):
		_stats_time_window_option.item_selected.connect(_on_statistics_time_window_selected)
	controls_row.add_child(_stats_time_window_option)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(120, 38)
	refresh_btn.add_theme_font_size_override("font_size", 15)
	refresh_btn.focus_mode = Control.FOCUS_NONE
	if not refresh_btn.pressed.is_connected(_on_statistics_refresh_pressed):
		refresh_btn.pressed.connect(_on_statistics_refresh_pressed)
	controls_row.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 38)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.focus_mode = Control.FOCUS_NONE
	if not close_btn.pressed.is_connected(_on_statistics_close_pressed):
		close_btn.pressed.connect(_on_statistics_close_pressed)
	controls_row.add_child(close_btn)

	_stats_last_update_label = Label.new()
	_stats_last_update_label.text = "Turn update: -"
	_stats_last_update_label.modulate = Color(0.84, 0.90, 0.98, 0.92)
	frame.add_child(_stats_last_update_label)

	_stats_scroll = ScrollContainer.new()
	_stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_stats_scroll)

	_stats_content = VBoxContainer.new()
	_stats_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_content.add_theme_constant_override("separation", 12)
	_stats_scroll.add_child(_stats_content)

	var kpi_wrap := PanelContainer.new()
	kpi_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_content.add_child(kpi_wrap)
	var kpi_style := StyleBoxFlat.new()
	kpi_style.bg_color = Color(0.10, 0.16, 0.24, 0.85)
	kpi_style.corner_radius_top_left = 8
	kpi_style.corner_radius_top_right = 8
	kpi_style.corner_radius_bottom_left = 8
	kpi_style.corner_radius_bottom_right = 8
	kpi_style.content_margin_left = 10
	kpi_style.content_margin_right = 10
	kpi_style.content_margin_top = 10
	kpi_style.content_margin_bottom = 10
	kpi_wrap.add_theme_stylebox_override("panel", kpi_style)

	_stats_kpi_grid = GridContainer.new()
	_stats_kpi_grid.columns = 3
	_stats_kpi_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_kpi_grid.add_theme_constant_override("h_separation", 10)
	_stats_kpi_grid.add_theme_constant_override("v_separation", 10)
	kpi_wrap.add_child(_stats_kpi_grid)
	_vytvor_stats_kpi_card("gdp", "GDP", STATS_COLOR_GDP)
	_vytvor_stats_kpi_card("population", "Population", STATS_COLOR_POP)
	_vytvor_stats_kpi_card("army", "Army", STATS_COLOR_ARMY)
	_vytvor_stats_kpi_card("profit", "Net Profit", STATS_COLOR_PROFIT)
	_vytvor_stats_kpi_card("growth", "GDP Growth", STATS_COLOR_GROWTH_GDP)
	_vytvor_stats_kpi_card("relation", "Avg Relations", Color(0.84, 0.70, 0.95, 1.0))

	_stats_tabs = TabContainer.new()
	_stats_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_content.add_child(_stats_tabs)

	_stats_overview_tab = VBoxContainer.new()
	_stats_overview_tab.name = "Overview"
	_stats_overview_tab.add_theme_constant_override("separation", 8)
	_stats_tabs.add_child(_stats_overview_tab)

	_stats_report = RichTextLabel.new()
	_stats_report.bbcode_enabled = true
	_stats_report.fit_content = true
	_stats_report.scroll_active = false
	_stats_report.selection_enabled = false
	_stats_report.custom_minimum_size = Vector2(980, 220)
	_stats_overview_tab.add_child(_stats_report)

	_stats_charts_tab = VBoxContainer.new()
	_stats_charts_tab.name = "My Country"
	_stats_charts_tab.add_theme_constant_override("separation", 10)
	_stats_tabs.add_child(_stats_charts_tab)

	_stats_finance_tab = VBoxContainer.new()
	_stats_finance_tab.name = "All Countries"
	_stats_finance_tab.add_theme_constant_override("separation", 10)
	_stats_tabs.add_child(_stats_finance_tab)

	_stats_chart_growth = _vytvor_statistics_chart_blok(_stats_charts_tab, "Growth rates")
	_stats_chart_gdp = _vytvor_statistics_chart_blok(_stats_charts_tab, "GDP and GDP per capita")
	_stats_chart_population = _vytvor_statistics_chart_blok(_stats_charts_tab, "Population and provinces")
	_stats_chart_recruits_army = _vytvor_statistics_chart_blok(_stats_charts_tab, "Recruit pool and army")

	var compare_wrap := PanelContainer.new()
	compare_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_finance_tab.add_child(compare_wrap)
	var compare_box := VBoxContainer.new()
	compare_box.add_theme_constant_override("separation", 8)
	compare_wrap.add_child(compare_box)

	var compare_title := Label.new()
	compare_title.text = "Cross-state comparison"
	compare_title.add_theme_font_size_override("font_size", 18)
	compare_box.add_child(compare_title)

	_stats_compare_chart = StatsLineChart.new()
	_stats_compare_chart.custom_minimum_size = Vector2(780, 684)
	_stats_compare_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_compare_chart.value_suffix = ""
	_stats_compare_chart.value_decimals = 2
	if not _stats_compare_chart.chart_point_hovered.is_connected(_on_statistics_chart_point_hovered):
		_stats_compare_chart.chart_point_hovered.connect(_on_statistics_chart_point_hovered)
	compare_box.add_child(_stats_compare_chart)

	_stats_compare_hint = Label.new()
	_stats_compare_hint.modulate = Color(0.83, 0.89, 0.98, 0.9)
	compare_box.add_child(_stats_compare_hint)

	var compare_controls := HBoxContainer.new()
	compare_controls.add_theme_constant_override("separation", 8)
	compare_box.add_child(compare_controls)

	var metric_label := Label.new()
	metric_label.text = "Metric:"
	compare_controls.add_child(metric_label)

	_stats_compare_metric_option = OptionButton.new()
	_stats_compare_metric_option.custom_minimum_size = Vector2(230, 34)
	_stats_compare_metric_option.add_item("GDP total")
	_stats_compare_metric_option.add_item("Population")
	_stats_compare_metric_option.add_item("Province count")
	_stats_compare_metric_option.add_item("Army")
	_stats_compare_metric_option.add_item("Recruit pool")
	_stats_compare_metric_option.add_item("Income")
	_stats_compare_metric_option.add_item("Expenses")
	_stats_compare_metric_option.add_item("Net profit")
	_stats_compare_metric_option.add_item("GDP growth %")
	_stats_compare_metric_option.add_item("Population growth %")
	if not _stats_compare_metric_option.item_selected.is_connected(_on_statistics_compare_controls_changed):
		_stats_compare_metric_option.item_selected.connect(_on_statistics_compare_controls_changed)
	compare_controls.add_child(_stats_compare_metric_option)

	var all_btn := Button.new()
	all_btn.text = "Select all"
	all_btn.focus_mode = Control.FOCUS_NONE
	if not all_btn.pressed.is_connected(_on_stats_compare_select_all_pressed):
		all_btn.pressed.connect(_on_stats_compare_select_all_pressed)
	compare_controls.add_child(all_btn)

	var none_btn := Button.new()
	none_btn.text = "Clear"
	none_btn.focus_mode = Control.FOCUS_NONE
	if not none_btn.pressed.is_connected(_on_stats_compare_clear_pressed):
		none_btn.pressed.connect(_on_stats_compare_clear_pressed)
	compare_controls.add_child(none_btn)

	_stats_compare_state_list = ItemList.new()
	_stats_compare_state_list.allow_reselect = true
	_stats_compare_state_list.select_mode = ItemList.SELECT_MULTI
	_stats_compare_state_list.custom_minimum_size = Vector2(0, 120)
	_stats_compare_state_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _stats_compare_state_list.multi_selected.is_connected(_on_statistics_compare_multi_selected):
		_stats_compare_state_list.multi_selected.connect(_on_statistics_compare_multi_selected)
	compare_box.add_child(_stats_compare_state_list)

	_stats_chart_finance = _vytvor_statistics_chart_blok(_stats_charts_tab, "Income, expenses, profit")

	var breakdown_wrap := PanelContainer.new()
	breakdown_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_charts_tab.add_child(breakdown_wrap)

	var breakdown_box := VBoxContainer.new()
	breakdown_box.add_theme_constant_override("separation", 6)
	breakdown_wrap.add_child(breakdown_box)

	var breakdown_title := Label.new()
	breakdown_title.text = "Finance composition (current turn)"
	breakdown_title.add_theme_font_size_override("font_size", 18)
	breakdown_box.add_child(breakdown_title)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	breakdown_box.add_child(split)

	_stats_income_breakdown = VBoxContainer.new()
	_stats_income_breakdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_stats_income_breakdown)

	_stats_expense_breakdown = VBoxContainer.new()
	_stats_expense_breakdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_stats_expense_breakdown)

	add_child(_stats_popup)

# Creates required nodes and connects signals.
func _vytvor_statistics_chart_blok(parent: Node, title: String) -> StatsLineChart:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrap)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	wrap.add_child(box)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 17)
	box.add_child(lbl)

	var chart := StatsLineChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not chart.chart_point_hovered.is_connected(_on_statistics_chart_point_hovered):
		chart.chart_point_hovered.connect(_on_statistics_chart_point_hovered)
	box.add_child(chart)
	return chart

# Construct/setup block for required nodes.
func _vytvor_stats_kpi_card(key: String, title: String, accent: Color) -> void:
	if _stats_kpi_grid == null:
		return
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.19, 0.28, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent * Color(1, 1, 1, 0.65)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	_stats_kpi_grid.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 13)
	t.modulate = Color(0.82, 0.88, 0.96, 0.9)
	box.add_child(t)

	var v := Label.new()
	v.text = "-"
	v.add_theme_font_size_override("font_size", 24)
	v.modulate = accent
	box.add_child(v)
	_stats_kpi_labels[key] = v

# Core flow for this feature.
func _stats_set_kpi(key: String, value_text: String) -> void:
	if not _stats_kpi_labels.has(key):
		return
	var lbl = _stats_kpi_labels[key] as Label
	if lbl:
		lbl.text = value_text

# Triggered by a UI/game signal.
func _on_statistics_pressed() -> void:
	_aktualizuj_statistiky_kola(true)
	_obnov_statistics_state_options()
	_aktualizuj_statistics_report()
	if _stats_popup:
		_stats_popup.popup_centered(Vector2i(1620, 1140))

# Handles this signal callback.
func _on_statistics_close_pressed() -> void:
	if _stats_popup:
		_stats_popup.hide()

# Callback for UI/game events.
func _on_statistics_refresh_pressed() -> void:
	_aktualizuj_statistiky_kola(true)
	_obnov_statistics_state_options()
	_aktualizuj_statistics_report()

# Reacts to incoming events.
func _on_statistics_state_selected(_index: int) -> void:
	_aktualizuj_statistics_report()

# Handles this signal callback.
func _on_statistics_time_window_selected(_index: int) -> void:
	_aktualizuj_statistics_report()

# Handles this signal callback.
func _on_statistics_compare_controls_changed(_index: int) -> void:
	_aktualizuj_statistics_report()

# Callback for UI/game events.
func _on_statistics_compare_multi_selected(_index: int, _selected: bool) -> void:
	_aktualizuj_statistics_report()

# Reacts to incoming events.
func _on_stats_compare_select_all_pressed() -> void:
	if _stats_compare_state_list == null:
		return
	for i in range(_stats_compare_state_list.item_count):
		_stats_compare_state_list.select(i, false)
	_aktualizuj_statistics_report()

# Handles this signal callback.
func _on_stats_compare_clear_pressed() -> void:
	if _stats_compare_state_list == null:
		return
	for i in range(_stats_compare_state_list.item_count):
		_stats_compare_state_list.deselect(i)
	_aktualizuj_statistics_report()

# Handles this signal callback.
func _on_statistics_chart_point_hovered(info: Dictionary) -> void:
	if _stats_compare_hint == null:
		return
	if info.is_empty():
		_stats_compare_hint.text = ""
		return
	_stats_compare_hint.text = str(info.get("text", ""))

# Reads values from active state.
func _ziskej_stats_window_size() -> int:
	if _stats_time_window_option == null:
		return 24
	match _stats_time_window_option.selected:
		0:
			return 12
		1:
			return 24
		2:
			return 48
		_:
			return 0

# Runs the local feature logic.
func _orez_series_na_okno(values: Array, turns: Array, window_size: int) -> Dictionary:
	if values.is_empty() or turns.is_empty():
		return {"values": [], "turns": []}
	if window_size <= 0 or values.size() <= window_size:
		return {"values": values.duplicate(), "turns": turns.duplicate()}
	var from_idx = max(0, values.size() - window_size)
	return {
		"values": values.slice(from_idx, values.size()),
		"turns": turns.slice(from_idx, turns.size())
	}

# Feature logic entry point.
func _stats_metric_def() -> Dictionary:
	var idx = 0
	if _stats_compare_metric_option:
		idx = _stats_compare_metric_option.selected
	match idx:
		0:
			return {"key": "gdp", "name": "GDP total", "suffix": " M", "decimals": 2, "growth": false}
		1:
			return {"key": "population", "name": "Population", "suffix": "", "decimals": 0, "growth": false}
		2:
			return {"key": "provinces", "name": "Province count", "suffix": "", "decimals": 0, "growth": false}
		3:
			return {"key": "army", "name": "Army", "suffix": "", "decimals": 0, "growth": false}
		4:
			return {"key": "recruits", "name": "Recruit pool", "suffix": "", "decimals": 0, "growth": false}
		5:
			return {"key": "income", "name": "Income", "suffix": " M", "decimals": 2, "growth": false}
		6:
			return {"key": "expenses", "name": "Expenses", "suffix": " M", "decimals": 2, "growth": false}
		7:
			return {"key": "profit", "name": "Net profit", "suffix": " M", "decimals": 2, "growth": false}
		8:
			return {"key": "gdp", "name": "GDP growth", "suffix": "%", "decimals": 2, "growth": true}
		9:
			return {"key": "population", "name": "Population growth", "suffix": "%", "decimals": 2, "growth": true}
		_:
			return {"key": "gdp", "name": "GDP total", "suffix": " M", "decimals": 2, "growth": false}

# Feature logic entry point.
func _vybrane_staty_pro_compare() -> Array:
	var out: Array = []
	if _stats_compare_state_list == null:
		return out
	for i in range(_stats_compare_state_list.item_count):
		if not _stats_compare_state_list.is_selected(i):
			continue
		var tag = str(_stats_compare_state_list.get_item_metadata(i))
		if tag == "":
			continue
		out.append(tag)
	return out

# Runs the local feature logic.
func _barva_pro_stat_index(i: int, total: int) -> Color:
	var count = max(1, total)
	var h = fposmod(float(i) / float(count), 1.0)
	return Color.from_hsv(h, 0.68, 0.98, 1.0)

# Rebuilds state from latest data.
func _aktualizuj_compare_chart(window_size: int) -> void:
	if _stats_compare_chart == null:
		return
	var selected_states = _vybrane_staty_pro_compare()
	var metric = _stats_metric_def()
	var key = str(metric.get("key", "gdp"))
	var is_growth = bool(metric.get("growth", false))

	if selected_states.is_empty():
		_nastav_chart_data(_stats_compare_chart, [])
		_stats_compare_chart.turn_values = []
		_stats_compare_chart.value_suffix = str(metric.get("suffix", ""))
		_stats_compare_chart.value_decimals = int(metric.get("decimals", 2))
		if _stats_compare_hint:
			_stats_compare_hint.text = "Select at least one state to draw comparison."
		return

	var series_out: Array = []
	var turns_ref: Array = []
	for i in range(selected_states.size()):
		var state = str(selected_states[i])
		if not _stats_history_by_state.has(state):
			continue
		var h = _stats_history_by_state[state] as Dictionary
		var turns = h.get("turns", []) as Array
		var vals = h.get(key, []) as Array
		var data_vals = vals
		if is_growth:
			data_vals = _calc_growth_series(vals)
			if turns.size() > 1:
				turns = turns.slice(1, turns.size())
			else:
				turns = []
		var clipped = _orez_series_na_okno(data_vals, turns, window_size)
		var cvals = clipped.get("values", []) as Array
		var cturns = clipped.get("turns", []) as Array
		if cvals.size() < 2:
			continue
		if turns_ref.is_empty() or cturns.size() < turns_ref.size():
			turns_ref = cturns.duplicate()
		series_out.append({
			"name": str(h.get("name", state)),
			"values": _as_float_series(cvals),
			"color": _barva_pro_stat_index(i, selected_states.size())
		})

	_nastav_chart_data(_stats_compare_chart, series_out)
	_stats_compare_chart.turn_values = turns_ref.duplicate()
	_stats_compare_chart.value_suffix = str(metric.get("suffix", ""))
	_stats_compare_chart.value_decimals = int(metric.get("decimals", 2))
	if _stats_compare_hint:
		_stats_compare_hint.text = "Metric: %s | Selected states: %d | Hover any point for exact turn/value." % [
			str(metric.get("name", "Metric")),
			selected_states.size()
		]

# Returns current runtime data.
func _ziskej_vsechny_staty_z_mapy() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var data = GameManager.map_data
	if not (data is Dictionary):
		return out
	for p_id in data:
		var d = data[p_id] as Dictionary
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue
		if seen.has(owner):
			continue
		seen[owner] = true
		out.append(owner)
	out.sort()
	return out

# Fetches data for callers.
func _ziskej_jmeno_statu_z_mapy(tag: String) -> String:
	var wanted = str(tag).strip_edges().to_upper()
	if wanted == "":
		return ""
	var data = GameManager.map_data
	if data is Dictionary:
		for p_id in data:
			var d = data[p_id] as Dictionary
			if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
				continue
			var n = str(d.get("country_name", wanted)).strip_edges()
			if n != "":
				return n
	return wanted

# Computes derived values from current inputs and game state.
func _spocitej_snapshot_statu(tag: String) -> Dictionary:
	var state = str(tag).strip_edges().to_upper()
	if state == "" or state == "SEA":
		return {}

	var total_gdp := 0.0
	var total_population := 0
	var total_recruits := 0
	var total_army := 0
	var provinces := 0
	var port_count := 0
	var ideology := ""
	var data = GameManager.map_data
	if data is Dictionary:
		for p_id in data:
			var d = data[p_id] as Dictionary
			if str(d.get("owner", "")).strip_edges().to_upper() != state:
				continue
			provinces += 1
			total_gdp += float(d.get("gdp", 0.0))
			total_population += int(d.get("population", 0))
			total_recruits += int(d.get("recruitable_population", 0))
			total_army += int(d.get("soldiers", 0))
			if bool(d.get("has_port", false)):
				port_count += 1
			if ideology == "":
				ideology = str(d.get("ideology", "")).strip_edges()

	var income_total := 0.0
	var expenses_total := 0.0
	var profit := 0.0
	var income_gdp := 0.0
	var income_vassals := 0.0
	var income_reparations := 0.0
	var income_loan_interest := 0.0
	var income_other := 0.0
	var expense_army_upkeep := 0.0
	var expense_investments := 0.0
	var expense_loan_interest := 0.0
	var expense_other := 0.0
	if GameManager.has_method("ziskej_financni_rozpad_statu"):
		var fin = GameManager.ziskej_financni_rozpad_statu(state) as Dictionary
		if bool(fin.get("ok", false)):
			var income = fin.get("income", {}) as Dictionary
			var expenses = fin.get("expenses", {}) as Dictionary
			income_total = float(income.get("total", 0.0))
			expenses_total = float(expenses.get("total", 0.0))
			income_gdp = float(income.get("gdp", 0.0))
			income_vassals = float(income.get("vassals", 0.0))
			income_reparations = float(income.get("reparations", 0.0))
			income_loan_interest = float(income.get("loan_interest", 0.0))
			income_other = float(income.get("other", 0.0))
			expense_army_upkeep = float(expenses.get("army_upkeep", 0.0))
			expense_investments = float(expenses.get("investments", 0.0))
			expense_loan_interest = float(expenses.get("loan_interest", 0.0))
			expense_other = float(expenses.get("other", 0.0))
			profit = float(fin.get("profit", 0.0))
		else:
			profit = float(GameManager.ziskej_cisty_prijem_statu(state)) if GameManager.has_method("ziskej_cisty_prijem_statu") else 0.0
	else:
		profit = float(GameManager.ziskej_cisty_prijem_statu(state)) if GameManager.has_method("ziskej_cisty_prijem_statu") else 0.0

	var gdp_pc := 0.0
	if total_population > 0:
		gdp_pc = total_gdp / float(total_population)

	var avg_relation := 0.0
	var rel_count := 0
	if GameManager.has_method("ziskej_vztah_statu"):
		for other_any in _ziskej_vsechny_staty_z_mapy():
			var other = str(other_any)
			if other == state:
				continue
			avg_relation += float(GameManager.ziskej_vztah_statu(state, other))
			rel_count += 1
	if rel_count > 0:
		avg_relation /= float(rel_count)

	return {
		"state": state,
		"name": _ziskej_jmeno_statu_z_mapy(state),
		"ideology": ideology,
		"gdp": total_gdp,
		"gdp_pc": gdp_pc,
		"population": total_population,
		"recruits": total_recruits,
		"army": total_army,
		"provinces": provinces,
		"ports": port_count,
		"avg_relation": avg_relation,
		"income": income_total,
		"expenses": expenses_total,
		"profit": profit,
		"income_gdp": income_gdp,
		"income_vassals": income_vassals,
		"income_reparations": income_reparations,
		"income_loan_interest": income_loan_interest,
		"income_other": income_other,
		"expense_army_upkeep": expense_army_upkeep,
		"expense_investments": expense_investments,
		"expense_loan_interest": expense_loan_interest,
		"expense_other": expense_other
	}

# Handles this gameplay/UI path.
func _sanitize_stats_metric_value(key: String, value: Variant, previous_value: Variant) -> Variant:
	match key:
		"population", "recruits", "army", "provinces", "ports":
			return clampi(maxi(0, int(value)), 0, 2000000000)
		_:
			var f = float(value)
			if not is_finite(f):
				if previous_value == null:
					return 0.0
				return float(previous_value)
			var limit = 1000000000.0
			if key == "gdp_pc":
				limit = 1000000.0
			return clampf(f, -limit, limit)

# Applies incoming data to runtime state.
func _set_or_append_metric_for_turn(history: Dictionary, key: String, value, max_items: int) -> void:
	var turns = history.get("turns", []) as Array
	var values = history.get(key, []) as Array
	var previous_value: Variant = value
	if not values.is_empty():
		previous_value = values[values.size() - 1]
	var safe_value = _sanitize_stats_metric_value(key, value, previous_value)

	# Keep metric series aligned with turn count. This prevents invalid -1 indexing
	# when a turn exists but the metric has no value yet.
	while values.size() < turns.size():
		if values.is_empty():
			values.append(safe_value)
		else:
			values.append(values[values.size() - 1])

	if turns.is_empty():
		values.clear()
	else:
		values[turns.size() - 1] = safe_value

	while values.size() > max_items:
		values.remove_at(0)

	history[key] = values

# Handles this gameplay/UI path.
func _zapis_snapshot_statu_do_historie(snapshot: Dictionary, turn: int) -> void:
	if snapshot.is_empty():
		return
	var state = str(snapshot.get("state", "")).strip_edges().to_upper()
	if state == "":
		return

	var history = _stats_history_by_state.get(state, {
		"state": state,
		"name": str(snapshot.get("name", state)),
		"turns": [],
		"gdp": [],
		"gdp_pc": [],
		"population": [],
		"recruits": [],
		"army": [],
		"provinces": [],
		"ports": [],
		"avg_relation": [],
		"income": [],
		"expenses": [],
		"profit": [],
		"income_gdp": [],
		"income_vassals": [],
		"income_reparations": [],
		"income_loan_interest": [],
		"income_other": [],
		"expense_army_upkeep": [],
		"expense_investments": [],
		"expense_loan_interest": [],
		"expense_other": []
	}) as Dictionary
	history["name"] = str(snapshot.get("name", state))
	history["ideology"] = str(snapshot.get("ideology", ""))

	var turns = history.get("turns", []) as Array
	if turns.is_empty() or int(turns[turns.size() - 1]) < turn:
		turns.append(turn)
	elif int(turns[turns.size() - 1]) > turn:
		turns[turns.size() - 1] = turn
	while turns.size() > STATS_HISTORY_LIMIT:
		turns.remove_at(0)
	history["turns"] = turns

	_set_or_append_metric_for_turn(history, "gdp", float(snapshot.get("gdp", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "gdp_pc", float(snapshot.get("gdp_pc", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "population", int(snapshot.get("population", 0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "recruits", int(snapshot.get("recruits", 0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "army", int(snapshot.get("army", 0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "provinces", int(snapshot.get("provinces", 0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "ports", int(snapshot.get("ports", 0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "avg_relation", float(snapshot.get("avg_relation", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income", float(snapshot.get("income", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "expenses", float(snapshot.get("expenses", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "profit", float(snapshot.get("profit", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income_gdp", float(snapshot.get("income_gdp", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income_vassals", float(snapshot.get("income_vassals", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income_reparations", float(snapshot.get("income_reparations", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income_loan_interest", float(snapshot.get("income_loan_interest", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "income_other", float(snapshot.get("income_other", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "expense_army_upkeep", float(snapshot.get("expense_army_upkeep", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "expense_investments", float(snapshot.get("expense_investments", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "expense_loan_interest", float(snapshot.get("expense_loan_interest", 0.0)), STATS_HISTORY_LIMIT)
	_set_or_append_metric_for_turn(history, "expense_other", float(snapshot.get("expense_other", 0.0)), STATS_HISTORY_LIMIT)

	_stats_history_by_state[state] = history

	_stats_last_recorded_turn_by_state[state] = turn

# Rebuilds state from latest data.
func _aktualizuj_statistiky_kola(force_refresh: bool = false) -> void:
	var turn = max(1, int(GameManager.aktualni_kolo))
	for state_any in _ziskej_vsechny_staty_z_mapy():
		var state = str(state_any)
		if not force_refresh and int(_stats_last_recorded_turn_by_state.get(state, -1)) == turn:
			continue
		var snapshot = _spocitej_snapshot_statu(state)
		_zapis_snapshot_statu_do_historie(snapshot, turn)

# Refreshes existing content to reflect current runtime values.
func _obnov_statistics_state_options() -> void:
	if _stats_state_option == null:
		return

	var previous_state = _ziskej_selected_statistics_state()
	_stats_state_option.clear()
	_stats_country_options.clear()
	if _stats_compare_state_list:
		_stats_compare_state_list.clear()

	var states = _ziskej_vsechny_staty_z_mapy()
	var preferred = str(GameManager.hrac_stat).strip_edges().to_upper()
	var selected_idx = -1

	for state_any in states:
		var state = str(state_any)
		var name = _ziskej_jmeno_statu_z_mapy(state)
		var label = "%s (%s)" % [name, state]
		_stats_state_option.add_item(label)
		_stats_country_options.append(state)
		if _stats_compare_state_list:
			_stats_compare_state_list.add_item(label)
			var list_idx = _stats_compare_state_list.item_count - 1
			_stats_compare_state_list.set_item_metadata(list_idx, state)
			_stats_compare_state_list.select(list_idx, false)
		var idx = _stats_country_options.size() - 1
		if previous_state != "" and state == previous_state:
			selected_idx = idx
		elif previous_state == "" and state == preferred:
			selected_idx = idx

	if selected_idx < 0 and _stats_country_options.size() > 0:
		selected_idx = 0
	if selected_idx >= 0:
		_stats_state_option.select(selected_idx)

# Returns current runtime data.
func _ziskej_selected_statistics_state() -> String:
	if _stats_state_option == null:
		return ""
	var idx = _stats_state_option.selected
	if idx < 0 or idx >= _stats_country_options.size():
		return ""
	return str(_stats_country_options[idx])

# User-facing value formatter.
func _format_signed_percent(value: float) -> String:
	return "%+.2f%%" % value

# Computes derived values from current inputs and game state.
func _calc_growth_series(values: Array) -> Array:
	var out: Array = []
	if values.size() <= 1:
		return out
	for i in range(1, values.size()):
		var prev = float(values[i - 1])
		var current = float(values[i])
		if absf(prev) <= 0.0000001:
			out.append(0.0)
		else:
			var growth = ((current - prev) / prev) * 100.0
			out.append(clampf(growth, -500.0, 500.0))
	return out

# Handles this gameplay/UI path.
func _value_last(values: Array, default_value) -> Variant:
	if values.is_empty():
		return default_value
	return values[values.size() - 1]

# Runs the local feature logic.
func _as_float_series(values: Array) -> Array:
	var out: Array = []
	var previous := 0.0
	for v_any in values:
		var f = float(v_any)
		if not is_finite(f):
			f = previous
		f = clampf(f, -1000000000.0, 1000000000.0)
		out.append(f)
		previous = f
	return out

# Wipes short-lived state.
func _vycisti_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

# Writes new values and refreshes related state.
func _nastav_chart_data(chart: StatsLineChart, chart_series: Array) -> void:
	if chart == null:
		return
	chart.series = chart_series
	chart.queue_redraw()

# Builds UI objects and default wiring.
func _vytvor_breakdown_sloupce(container: VBoxContainer, title: String, rows: Array, total: float) -> void:
	if container == null:
		return
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	container.add_child(heading)

	for row_any in rows:
		var row = row_any as Dictionary
		var name = str(row.get("name", "-"))
		var value = float(row.get("value", 0.0))
		var color = row.get("color", Color(0.85, 0.85, 0.85, 1.0)) as Color

		var h = HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 8)
		container.add_child(h)

		var name_lbl = Label.new()
		name_lbl.custom_minimum_size.x = 120
		name_lbl.text = name
		h.add_child(name_lbl)

		var bar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.max_value = maxf(0.0001, total)
		bar.value = clampf(value, 0.0, bar.max_value)
		bar.modulate = color
		h.add_child(bar)

		var val_lbl = Label.new()
		val_lbl.custom_minimum_size.x = 120
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var pct = 0.0
		if total > 0.0001:
			pct = (value / total) * 100.0
		val_lbl.text = "%.2f M (%.0f%%)" % [value, pct]
		h.add_child(val_lbl)

# Feature logic entry point.
func _top_states_by_metric(metric_key: String, limit: int = 8) -> Array:
	var rows: Array = []
	for state_any in _stats_history_by_state.keys():
		var state = str(state_any)
		var h = _stats_history_by_state[state] as Dictionary
		var series = h.get(metric_key, []) as Array
		if series.is_empty():
			continue
		rows.append({
			"state": state,
			"name": str(h.get("name", state)),
			"value": float(_value_last(series, 0.0))
		})
	rows.sort_custom(func(a, b): return float(a.get("value", 0.0)) > float(b.get("value", 0.0)))
	if rows.size() > limit:
		rows.resize(limit)
	return rows

# Recomputes values from current data.
func _aktualizuj_statistics_report() -> void:
	if _stats_report == null:
		return
	# tohle je centralni refresh vsech statistik: text, KPI, grafy i breakdown sloupce.

	var selected = _ziskej_selected_statistics_state()
	if selected == "":
		_stats_report.text = "[color=#FFFFFF]No country selected.[/color]"
		_stats_set_kpi("gdp", "-")
		_stats_set_kpi("population", "-")
		_stats_set_kpi("army", "-")
		_stats_set_kpi("profit", "-")
		_stats_set_kpi("growth", "-")
		_stats_set_kpi("relation", "-")
		_nastav_chart_data(_stats_chart_growth, [])
		_nastav_chart_data(_stats_chart_gdp, [])
		_nastav_chart_data(_stats_chart_population, [])
		_nastav_chart_data(_stats_chart_recruits_army, [])
		_nastav_chart_data(_stats_chart_finance, [])
		_nastav_chart_data(_stats_compare_chart, [])
		_vycisti_children(_stats_income_breakdown)
		_vycisti_children(_stats_expense_breakdown)
		if _stats_last_update_label:
			_stats_last_update_label.text = "Turn update: %d" % max(1, int(GameManager.aktualni_kolo))
		return

	if not _stats_history_by_state.has(selected):
		var snapshot = _spocitej_snapshot_statu(selected)
		_zapis_snapshot_statu_do_historie(snapshot, max(1, int(GameManager.aktualni_kolo)))

	var h = _stats_history_by_state.get(selected, {}) as Dictionary
	# bereme serii explicitne po klĂ­ÄŤĂ­ch, at je jasne co feeduje kterej graf.
	var turns = h.get("turns", []) as Array
	var gdp_series = h.get("gdp", []) as Array
	var gdp_pc_series = h.get("gdp_pc", []) as Array
	var pop_series = h.get("population", []) as Array
	var recruits_series = h.get("recruits", []) as Array
	var army_series = h.get("army", []) as Array
	var prov_series = h.get("provinces", []) as Array
	var ports_series = h.get("ports", []) as Array
	var avg_rel_series = h.get("avg_relation", []) as Array
	var income_series = h.get("income", []) as Array
	var expenses_series = h.get("expenses", []) as Array
	var profit_series = h.get("profit", []) as Array
	var income_gdp_series = h.get("income_gdp", []) as Array
	var income_vassals_series = h.get("income_vassals", []) as Array
	var income_reparations_series = h.get("income_reparations", []) as Array
	var income_loan_series = h.get("income_loan_interest", []) as Array
	var income_other_series = h.get("income_other", []) as Array
	var expense_army_series = h.get("expense_army_upkeep", []) as Array
	var expense_invest_series = h.get("expense_investments", []) as Array
	var expense_loan_series = h.get("expense_loan_interest", []) as Array
	var expense_other_series = h.get("expense_other", []) as Array

	var gdp_growth = _calc_growth_series(gdp_series)
	var pop_growth = _calc_growth_series(pop_series)
	var window_size = _ziskej_stats_window_size()
	# orez na okno drzi graf rychlej i kdyz historie naroste na stovky tahu.

	var gdp_clip = _orez_series_na_okno(gdp_series, turns, window_size)
	var gdp_chart = gdp_clip.get("values", []) as Array
	var chart_turns = gdp_clip.get("turns", []) as Array
	var gdp_pc_chart = (_orez_series_na_okno(gdp_pc_series, turns, window_size).get("values", []) as Array)
	var pop_chart = (_orez_series_na_okno(pop_series, turns, window_size).get("values", []) as Array)
	var recruits_chart = (_orez_series_na_okno(recruits_series, turns, window_size).get("values", []) as Array)
	var army_chart = (_orez_series_na_okno(army_series, turns, window_size).get("values", []) as Array)
	var prov_chart = (_orez_series_na_okno(prov_series, turns, window_size).get("values", []) as Array)
	var ports_chart = (_orez_series_na_okno(ports_series, turns, window_size).get("values", []) as Array)
	var rel_chart = (_orez_series_na_okno(avg_rel_series, turns, window_size).get("values", []) as Array)
	var income_chart = (_orez_series_na_okno(income_series, turns, window_size).get("values", []) as Array)
	var expenses_chart = (_orez_series_na_okno(expenses_series, turns, window_size).get("values", []) as Array)
	var profit_chart = (_orez_series_na_okno(profit_series, turns, window_size).get("values", []) as Array)

	var growth_turns = turns.slice(1, turns.size()) if turns.size() > 1 else []
	var gdp_growth_chart = (_orez_series_na_okno(gdp_growth, growth_turns, window_size).get("values", []) as Array)
	var growth_chart_turns = (_orez_series_na_okno(gdp_growth, growth_turns, window_size).get("turns", []) as Array)
	var pop_growth_chart = (_orez_series_na_okno(pop_growth, growth_turns, window_size).get("values", []) as Array)

	var name = str(h.get("name", selected))
	var latest_turn = int(_value_last(turns, int(GameManager.aktualni_kolo)))
	var latest_gdp = float(_value_last(gdp_series, 0.0))
	var latest_gdp_pc = float(_value_last(gdp_pc_series, 0.0))
	var latest_pop = int(_value_last(pop_series, 0))
	var latest_recruits = int(_value_last(recruits_series, 0))
	var latest_army = int(_value_last(army_series, 0))
	var latest_prov = int(_value_last(prov_series, 0))
	var latest_ports = int(_value_last(ports_series, 0))
	var latest_avg_rel = float(_value_last(avg_rel_series, 0.0))
	var latest_income = float(_value_last(income_series, 0.0))
	var latest_expenses = float(_value_last(expenses_series, 0.0))
	var latest_profit = float(_value_last(profit_series, 0.0))
	var latest_gdp_growth = float(_value_last(gdp_growth, 0.0))
	var latest_pop_growth = float(_value_last(pop_growth, 0.0))
	var ideology = str(h.get("ideology", "")).strip_edges()

	_stats_set_kpi("gdp", "%.1f M" % latest_gdp)
	_stats_set_kpi("population", "%d" % latest_pop)
	_stats_set_kpi("army", "%d" % latest_army)
	_stats_set_kpi("profit", "%+.2f M" % latest_profit)
	_stats_set_kpi("growth", _format_signed_percent(latest_gdp_growth))
	_stats_set_kpi("relation", "%.1f" % latest_avg_rel)

	var text := ""
	text += "[b][color=#FFFFFF]State Overview[/color][/b]\n"
	text += "[color=#A6D3FF]%s (%s)[/color] | Turn [b]%d[/b]" % [name, selected, latest_turn]
	if ideology != "":
		text += " | Ideology: [color=#D5E8FF]%s[/color]" % ideology
	text += "\n\n"

	text += "[b]Economy[/b]\n"
	text += "GDP: [color=#F2D14C]%.2f M USD[/color] | GDP per capita: [color=#E7E1A9]%.6f M USD[/color]\n" % [latest_gdp, latest_gdp_pc]
	text += "Income: [color=#76E878]%.2f M USD[/color] | Expenses: [color=#FF9A63]%.2f M USD[/color] | Net: [color=#CCD0EA]%+.2f M USD[/color]\n\n" % [latest_income, latest_expenses, latest_profit]

	text += "[b]Demography & Military[/b]\n"
	text += "Population: [color=#73D3E7]%d[/color] | Recruit pool: [color=#72E39E]%d[/color] | Army: [color=#F66A61]%d[/color]\n" % [latest_pop, latest_recruits, latest_army]
	text += "Provinces: [color=#BAC4EC]%d[/color] | Ports: [color=#9BC8FF]%d[/color] | Avg relation: [color=#D6B4F2]%.1f[/color]\n\n" % [latest_prov, latest_ports, latest_avg_rel]

	text += "[b]Latest Turn Changes[/b]\n"
	text += "GDP growth: [color=#FEDD65]%s[/color] | Population growth: [color=#98DCFF]%s[/color]\n\n" % [_format_signed_percent(latest_gdp_growth), _format_signed_percent(latest_pop_growth)]

	text += "[b]How To Read Tabs[/b]\n"
	text += "- [b]Overview[/b]: compact summary + ranking\n"
	text += "- [b]Charts[/b]: long-term state trends\n"
	text += "- [b]Finance[/b]: income/expense lines + composition bars\n\n"

	var top_gdp = _top_states_by_metric("gdp", 8)
	text += "[b]Top GDP States[/b]\n"
	if top_gdp.is_empty():
		text += "No data yet.\n"
	else:
		for i in range(top_gdp.size()):
			var row = top_gdp[i] as Dictionary
			text += "%d. [color=#E7EDF8]%s[/color] (%s): %.2f M USD\n" % [
				i + 1,
				str(row.get("name", "-")),
				str(row.get("state", "-")),
				float(row.get("value", 0.0))
			]

	_stats_report.text = text
	# po textu jedeme grafy; poradi je dulezity kvuli sdilenym turn-axis hodnotam.

	_nastav_chart_data(_stats_chart_growth, [
		{"name": "GDP growth %", "values": _as_float_series(gdp_growth_chart), "color": STATS_COLOR_GROWTH_GDP},
		{"name": "Population growth %", "values": _as_float_series(pop_growth_chart), "color": STATS_COLOR_GROWTH_POP}
	])
	_stats_chart_growth.turn_values = growth_chart_turns.duplicate()
	_stats_chart_growth.value_suffix = "%"
	_stats_chart_growth.value_decimals = 2
	_nastav_chart_data(_stats_chart_gdp, [
		{"name": "GDP total", "values": _as_float_series(gdp_chart), "color": STATS_COLOR_GDP},
		{"name": "GDP per capita", "values": _as_float_series(gdp_pc_chart), "color": Color(0.89, 0.87, 0.64, 1.0)}
	])
	_stats_chart_gdp.turn_values = chart_turns.duplicate()
	_stats_chart_gdp.value_suffix = " M"
	_stats_chart_gdp.value_decimals = 2
	_nastav_chart_data(_stats_chart_population, [
		{"name": "Population", "values": _as_float_series(pop_chart), "color": STATS_COLOR_POP},
		{"name": "Provinces", "values": _as_float_series(prov_chart), "color": Color(0.73, 0.78, 0.93, 1.0)},
		{"name": "Ports", "values": _as_float_series(ports_chart), "color": Color(0.61, 0.77, 1.0, 1.0)}
	])
	_stats_chart_population.turn_values = chart_turns.duplicate()
	_stats_chart_population.value_suffix = ""
	_stats_chart_population.value_decimals = 0
	_nastav_chart_data(_stats_chart_recruits_army, [
		{"name": "Recruitable population", "values": _as_float_series(recruits_chart), "color": STATS_COLOR_RECRUITS},
		{"name": "Army", "values": _as_float_series(army_chart), "color": STATS_COLOR_ARMY},
		{"name": "Avg relation", "values": _as_float_series(rel_chart), "color": Color(0.86, 0.73, 0.95, 1.0)}
	])
	_stats_chart_recruits_army.turn_values = chart_turns.duplicate()
	_stats_chart_recruits_army.value_suffix = ""
	_stats_chart_recruits_army.value_decimals = 0
	_nastav_chart_data(_stats_chart_finance, [
		{"name": "Income", "values": _as_float_series(income_chart), "color": STATS_COLOR_INCOME},
		{"name": "Expenses", "values": _as_float_series(expenses_chart), "color": STATS_COLOR_EXPENSE},
		{"name": "Profit", "values": _as_float_series(profit_chart), "color": STATS_COLOR_PROFIT}
	])
	_stats_chart_finance.turn_values = chart_turns.duplicate()
	_stats_chart_finance.value_suffix = " M"
	_stats_chart_finance.value_decimals = 2
	_aktualizuj_compare_chart(window_size)

	_vycisti_children(_stats_income_breakdown)
	_vycisti_children(_stats_expense_breakdown)
	_vytvor_breakdown_sloupce(_stats_income_breakdown, "Income", [
		{"name": "GDP", "value": float(_value_last(income_gdp_series, 0.0)), "color": Color(0.96, 0.79, 0.33, 1.0)},
		{"name": "Vassals", "value": float(_value_last(income_vassals_series, 0.0)), "color": Color(0.45, 0.91, 0.55, 1.0)},
		{"name": "Reparations", "value": float(_value_last(income_reparations_series, 0.0)), "color": Color(0.43, 0.82, 0.96, 1.0)},
		{"name": "Loan interest", "value": float(_value_last(income_loan_series, 0.0)), "color": Color(0.80, 0.74, 0.96, 1.0)},
		{"name": "Other", "value": float(_value_last(income_other_series, 0.0)), "color": Color(0.72, 0.84, 0.86, 1.0)}
	], maxf(0.0001, latest_income))
	_vytvor_breakdown_sloupce(_stats_expense_breakdown, "Expenses", [
		{"name": "Army upkeep", "value": float(_value_last(expense_army_series, 0.0)), "color": Color(0.97, 0.42, 0.39, 1.0)},
		{"name": "Investments", "value": float(_value_last(expense_invest_series, 0.0)), "color": Color(0.98, 0.67, 0.35, 1.0)},
		{"name": "Loan interest", "value": float(_value_last(expense_loan_series, 0.0)), "color": Color(0.93, 0.56, 0.71, 1.0)},
		{"name": "Other", "value": float(_value_last(expense_other_series, 0.0)), "color": Color(0.83, 0.84, 0.92, 1.0)}
	], maxf(0.0001, latest_expenses))

	if _stats_last_update_label:
		var first_turn = 1
		if turns.size() > 0:
			first_turn = int(turns[0])
		_stats_last_update_label.text = "State: %s | Turn update: %d | History: %d points (T%d-T%d)" % [
			selected,
			max(1, int(GameManager.aktualni_kolo)),
			turns.size(),
			first_turn,
			latest_turn
		]

# Initialization for UI objects and hooks.
func _vytvor_turn_busy_indicator() -> void:
	if _turn_busy_indicator != null:
		return
	if next_btn == null:
		return
	var parent = next_btn.get_parent()
	if parent == null:
		return
	_turn_busy_indicator = Label.new()
	_turn_busy_indicator.text = TURN_BUSY_FRAMES[0]
	_turn_busy_indicator.visible = false
	_turn_busy_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_busy_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_busy_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_turn_busy_indicator.clip_text = true
	_turn_busy_indicator.custom_minimum_size = Vector2(92, 0)
	parent.add_child(_turn_busy_indicator)
	parent.move_child(_turn_busy_indicator, next_btn.get_index() + 1)

# Returns current runtime data.
func _ziskej_sirku_turn_busy_indicatoru() -> float:
	if _turn_busy_indicator == null:
		return 92.0
	var font = _turn_busy_indicator.get_theme_font("font")
	var font_size = _turn_busy_indicator.get_theme_font_size("font_size")
	var longest = TURN_BUSY_FRAMES[0]
	for frame in TURN_BUSY_FRAMES:
		if str(frame).length() > longest.length():
			longest = str(frame)
	if font:
		return clampf(font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10.0, 70.0, 180.0)
	return 92.0

# Event handler for user or game actions.
func _on_zpracovani_tahu_zmeneno(aktivni: bool) -> void:
	_is_turn_processing = aktivni
	# indicator + next_btn drzi hrace informovanyho, ze tah fakt stale bezi.
	if next_btn:
		next_btn.disabled = aktivni
	if _turn_busy_indicator:
		_turn_busy_indicator.visible = aktivni and not _turn_busy_suppressed
		_turn_busy_anim_step = 0
		_turn_busy_indicator.text = TURN_BUSY_FRAMES[0]
	_turn_busy_anim_time = 0.0
	_aktualizuj_sirku_panelu_hrace()
	set_process(aktivni)

# Writes new values and refreshes related state.
func nastav_pozastaveni_turn_busy_indicator(pozastavit: bool) -> void:
	_turn_busy_suppressed = pozastavit
	if _turn_busy_indicator:
		_turn_busy_indicator.visible = _is_turn_processing and not _turn_busy_suppressed
	_aktualizuj_sirku_panelu_hrace()

# Runs each frame when active.
func _process(delta: float) -> void:
	if _finance_tooltip_visible:
		_aktualizuj_financni_tooltip_pozici()

	if not _is_turn_processing or _turn_busy_indicator == null or _turn_busy_suppressed:
		return
	_turn_busy_anim_time += delta
	if _turn_busy_anim_time < 0.16:
		return
	_turn_busy_anim_time = 0.0
	_turn_busy_anim_step = (_turn_busy_anim_step + 1) % TURN_BUSY_FRAMES.size()
	_turn_busy_indicator.text = TURN_BUSY_FRAMES[_turn_busy_anim_step]

# Construct/setup block for required nodes.
func _vytvor_financni_tooltip_panel() -> void:
	if _finance_tooltip_panel != null:
		return
	_finance_tooltip_panel = PanelContainer.new()
	_finance_tooltip_panel.name = "FinanceTooltipPanel"
	_finance_tooltip_panel.visible = false
	_finance_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finance_tooltip_panel.z_index = 200

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.12, 0.96)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.65, 0.70, 0.76, 0.92)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 8
	_finance_tooltip_panel.add_theme_stylebox_override("panel", panel_style)

	_finance_tooltip_text = RichTextLabel.new()
	_finance_tooltip_text.bbcode_enabled = true
	_finance_tooltip_text.fit_content = true
	_finance_tooltip_text.scroll_active = false
	_finance_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finance_tooltip_text.custom_minimum_size = Vector2(340, 0)
	_finance_tooltip_panel.add_child(_finance_tooltip_text)
	add_child(_finance_tooltip_panel)

# Feature logic entry point.
func _napoj_financni_hover() -> void:
	if money_label == null:
		return
	money_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if not money_label.mouse_entered.is_connected(_on_money_label_mouse_entered):
		money_label.mouse_entered.connect(_on_money_label_mouse_entered)
	if not money_label.mouse_exited.is_connected(_on_money_label_mouse_exited):
		money_label.mouse_exited.connect(_on_money_label_mouse_exited)

# Reacts to incoming events.
func _on_money_label_mouse_entered() -> void:
	_finance_tooltip_visible = true
	_aktualizuj_financni_tooltip_text()
	_aktualizuj_financni_tooltip_pozici()
	if _finance_tooltip_panel:
		_finance_tooltip_panel.show()

# Callback for UI/game events.
func _on_money_label_mouse_exited() -> void:
	_finance_tooltip_visible = false
	if _finance_tooltip_panel:
		_finance_tooltip_panel.hide()

# Display formatting helper.
func _format_finance_value(value: float) -> String:
	return "%.2f M USD" % value

# Display formatting helper.
func _format_finance_signed(value: float) -> String:
	return "%+.2f M USD" % value

# Refreshes cached/UI state.
func _aktualizuj_financni_tooltip_text() -> void:
	if _finance_tooltip_text == null:
		return
	# tooltip zamerne ukazuje profit i cashflow zvlast, aby nevznikal zmatek.

	var finance: Dictionary = {}
	if GameManager.has_method("ziskej_financni_rozpad_statu"):
		# bereme to primo z GM breakdownu, ne z lokalne skladanych cisel.
		finance = GameManager.ziskej_financni_rozpad_statu(str(GameManager.hrac_stat))

	if not bool(finance.get("ok", false)):
		_finance_tooltip_text.text = "[color=#FFFFFF]Finance: data unavailable.[/color]"
		return

	var income = finance.get("income", {}) as Dictionary
	var expenses = finance.get("expenses", {}) as Dictionary
	var profit = float(finance.get("profit", 0.0))
	var cashflow = float(finance.get("cashflow", profit))

	var t := ""
	# bbcode text je levnejsi udrzovat jako jeden string, nez sklĂˇdat desitky labelu.
	t += "[b][color=#FFFFFF]INCOME[/color][/b]\n"
	t += "[color=#65D96E]GDP: %s[/color]\n" % _format_finance_value(float(income.get("gdp", 0.0)))
	t += "[color=#65D96E]Vassals: %s[/color]\n" % _format_finance_value(float(income.get("vassals", 0.0)))
	t += "[color=#65D96E]Reparations: %s[/color]\n" % _format_finance_value(float(income.get("reparations", 0.0)))
	t += "[color=#65D96E]Loan interest: %s[/color]\n" % _format_finance_value(float(income.get("loan_interest", 0.0)))
	t += "[color=#65D96E]Loan principal: %s[/color]\n" % _format_finance_value(float(income.get("loan_principal", 0.0)))
	t += "[color=#65D96E]Other: %s[/color]\n\n" % _format_finance_value(float(income.get("other", 0.0)))

	t += "[b][color=#FFFFFF]EXPENSES[/color][/b]\n"
	t += "[color=#FF6666]Army upkeep: %s[/color]\n" % _format_finance_value(float(expenses.get("army_upkeep", 0.0)))
	t += "[color=#FF6666]Investments: %s[/color]\n" % _format_finance_value(float(expenses.get("investments", 0.0)))
	t += "[color=#FF6666]Loan interest: %s[/color]\n" % _format_finance_value(float(expenses.get("loan_interest", 0.0)))
	t += "[color=#FF6666]Loan principal: %s[/color]\n" % _format_finance_value(float(expenses.get("loan_principal", 0.0)))
	t += "[color=#FF6666]Other: %s[/color]\n\n" % _format_finance_value(float(expenses.get("other", 0.0)))

	t += "[b][color=#FFFFFF]BALANCE (PROFIT): %s[/color][/b]\n" % _format_finance_signed(profit)
	t += "[b][color=#FFFFFF]TREASURY CHANGE (CASHFLOW): %s[/color][/b]" % _format_finance_signed(cashflow)
	_finance_tooltip_text.text = t

# Recomputes values from current data.
func _aktualizuj_financni_tooltip_pozici() -> void:
	if _finance_tooltip_panel == null:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var margin = Vector2(14, 14)
	var desired = mouse_pos + margin
	var viewport = get_viewport()
	if viewport == null:
		return
	var viewport_size = viewport.get_visible_rect().size
	var tooltip_size = _finance_tooltip_panel.get_combined_minimum_size()
	var topbar_bottom = 0.0
	if top_panel:
		topbar_bottom = top_panel.global_position.y + top_panel.size.y
	if desired.x + tooltip_size.x > viewport_size.x - 6:
		desired.x = mouse_pos.x - tooltip_size.x - 10
	if desired.y + tooltip_size.y > viewport_size.y - 6:
		desired.y = viewport_size.y - tooltip_size.y - 6
	desired.x = clampf(desired.x, 4.0, max(4.0, viewport_size.x - tooltip_size.x - 4.0))
	desired.y = clampf(desired.y, topbar_bottom + 8.0, max(topbar_bottom + 8.0, viewport_size.y - tooltip_size.y - 4.0))
	_finance_tooltip_panel.position = desired

# Applies updates and syncs dependent state.
func nastav_hrace(tag: String, jmeno_statu: String, ideologie: String = ""):
	if player_name:
		player_name.text = jmeno_statu
		
	if player_flag:
		var ideo = _normalizuj_ideologii(ideologie)
		var cisty_tag = tag.strip_edges().to_upper()
		if cisty_tag == "DEU":
			if ideo == "fasismus":
				ideo = "nacismus"
			elif ideo == "nacismus":
				ideo = "fasismus"
		if ideo != "":
			_ensure_ideology_flag_index()
			var key = "%s|%s" % [cisty_tag, ideo]
			if ideology_flag_path_index.has(key):
				var ideol_path = str(ideology_flag_path_index[key])
				var ideol_tex = _cached_texture(ideol_path)
				if ideol_tex:
					player_flag.texture = ideol_tex
					return

		for path in ["res://map_data/Flags/%s.svg" % tag, "res://map_data/Flags/%s.png" % tag]:
			var tex = _cached_texture(path)
			if tex:
				player_flag.texture = tex
				return
		player_flag.texture = null

# Reads values from active state.
func _ziskej_map_loader_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("_ziskej_map_pozici_provincie") and scene_root.has_method("_ziskej_map_offset"):
		return scene_root
	if scene_root:
		var by_name = scene_root.find_child("Map", true, false)
		if by_name and by_name.has_method("_ziskej_map_pozici_provincie") and by_name.has_method("_ziskej_map_offset"):
			return by_name
	return null

# Returns current runtime data.
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

# Fetches data for callers.
func _ziskej_fokus_statu_na_mape(tag: String) -> Dictionary:
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

	# 1) Capital province first.
	for p_id in provinces:
		var d = provinces[p_id] as Dictionary
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		if bool(d.get("is_capital", false)):
			var cap_pos = _ziskej_map_pozici_provincie_bezpecne(map_loader, int(p_id), d)
			if cap_pos != Vector2.ZERO:
				return {"ok": true, "pos": cap_pos}

	# 2) Most populated owned province.
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

	return {"ok": false}

# Core flow for this feature.
func _vycentruj_kameru_na_stat(tag: String, smooth: bool = true) -> void:
	var center = _ziskej_fokus_statu_na_mape(tag)
	if not bool(center.get("ok", false)):
		return

	var camera = get_tree().current_scene.find_child("Camera2D", true, false) as Camera2D
	if camera == null:
		return

	var target_pos: Vector2 = center.get("pos", camera.position)
	if not is_finite(target_pos.x) or not is_finite(target_pos.y):
		return

	if smooth:
		if _player_focus_tween and _player_focus_tween.is_running():
			_player_focus_tween.kill()
		_player_focus_tween = camera.create_tween()
		_player_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_player_focus_tween.tween_property(camera, "position", target_pos, 0.70)
	else:
		camera.position = target_pos



