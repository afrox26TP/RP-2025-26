extends CanvasLayer

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
var _calendar_start_day: int = 1
var _calendar_start_month: int = 1
var _calendar_start_year: int = 2026

const TURN_BUSY_FRAMES := ["[zpracovavam  ]", "[zpracovavam .]", "[zpracovavam ..]", "[zpracovavam ...]"]
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

func _cached_texture(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not flag_texture_cache.has(path):
		flag_texture_cache[path] = load(path)
	return flag_texture_cache[path]

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
	_napoj_signal_mapoveho_modu()
	_vytvor_financni_tooltip_panel()
	_napoj_financni_hover()
	GameManager.kolo_zmeneno.connect(aktualizuj_ui)
	if GameManager.has_signal("zpracovani_tahu_zmeneno") and not GameManager.zpracovani_tahu_zmeneno.is_connected(_on_zpracovani_tahu_zmeneno):
		GameManager.zpracovani_tahu_zmeneno.connect(_on_zpracovani_tahu_zmeneno)
	_vytvor_turn_busy_indicator()
	_on_zpracovani_tahu_zmeneno(bool(GameManager.zpracovava_se_tah))
	_nastav_tooltipy_ui()
	var viewport = get_viewport()
	if viewport and viewport.has_signal("size_changed") and not viewport.size_changed.is_connected(_aktualizuj_sirku_panelu_hrace):
		viewport.size_changed.connect(_aktualizuj_sirku_panelu_hrace)
	aktualizuj_ui()
	call_deferred("_registruj_anchor_zprav")

func _nastav_tooltipy_ui() -> void:
	if money_label:
		money_label.tooltip_text = ""
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

func _inicializuj_startovni_datum_hry() -> void:
	var datum: Dictionary = Time.get_datetime_dict_from_system()
	_calendar_start_day = clampi(int(datum.get("day", 1)), 1, 31)
	_calendar_start_month = clampi(int(datum.get("month", 1)), 1, 12)
	_calendar_start_year = int(datum.get("year", 2026))

func _ziskej_text_data_pro_kolo(kolo: int) -> String:
	var offset_mesicu = maxi(0, kolo - 1)
	var month_index = (_calendar_start_month - 1) + offset_mesicu
	var month = int(month_index % 12) + 1
	var year = _calendar_start_year + int(floor(float(month_index) / 12.0))
	return "Date: %02d.%02d.%04d (Turn %d)" % [_calendar_start_day, month, year, maxi(1, kolo)]

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

func _ziskej_texturu_vlajky_fronty(tag: String):
	var cisty_tag = tag.strip_edges().to_upper()
	for path in ["res://map_data/Flags/%s.svg" % cisty_tag, "res://map_data/Flags/%s.png" % cisty_tag]:
		var tex = _cached_texture(path)
		if tex:
			return tex
	return null

func _vycisti_frontu_tahu_vlajek() -> void:
	if turn_queue_flags == null:
		return
	for child in turn_queue_flags.get_children():
		child.queue_free()

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

func _aktualizuj_sirku_panelu_hrace() -> void:
	if player_turn_panel == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return
	var vp_width = viewport.get_visible_rect().size.x

	var row_separation = 8.0
	if turn_row:
		row_separation = float(turn_row.get_theme_constant("separation"))
	var flag_width = 68.0
	if player_flag:
		flag_width = maxf(flag_width, player_flag.custom_minimum_size.x)
	var button_width = 180.0
	if next_btn:
		button_width = maxf(button_width, next_btn.custom_minimum_size.x)
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
	var turn_row_estimated = flag_width + button_width + row_separation + 18.0
	# Second row is full-width state name; third row is queue.
	var second_row_estimated = name_width + 18.0

	var desired_width = maxf(320.0, maxf(turn_row_estimated, maxf(second_row_estimated, queue_estimated)))
	var max_width = minf(560.0, maxf(320.0, vp_width - 24.0))
	desired_width = clampf(desired_width, 320.0, max_width)

	player_turn_panel.custom_minimum_size.x = desired_width
	player_turn_panel.offset_left = player_turn_panel.offset_right - desired_width

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

func _ziskej_game_ui_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.find_child("GameUI", true, false)

func _registruj_anchor_zprav() -> void:
	var game_ui = _ziskej_game_ui_node()
	if game_ui and game_ui.has_method("nastav_zpravy_anchor_control"):
		game_ui.nastav_zpravy_anchor_control(zpravy_btn)

func _on_zpravy_pressed() -> void:
	var game_ui = _ziskej_game_ui_node()
	if game_ui and game_ui.has_method("prepni_zpravy_panel"):
		game_ui.prepni_zpravy_panel()

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

func _nacti_ikonu_map_modu(mod: String):
	for path in _ziskej_cesty_ikony_map_modu(mod):
		var tex = _nacti_bilou_ikonu(str(path))
		if tex:
			return tex
	return null

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

func _napoj_signal_mapoveho_modu() -> void:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return
	if map_loader.has_signal("mapovy_mod_zmenen") and not map_loader.mapovy_mod_zmenen.is_connected(_on_mapovy_mod_zmenen):
		map_loader.mapovy_mod_zmenen.connect(_on_mapovy_mod_zmenen)

func _on_mapovy_mod_zmenen(mod: String) -> void:
	_aktualizuj_stav_tlacitek_modu(mod)

func _ziskej_map_loader() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("nastav_mapovy_mod"):
		return scene_root
	if scene_root:
		var map_node = scene_root.find_child("map2D", true, false)
		if map_node and map_node.has_method("nastav_mapovy_mod"):
			return map_node
	return null

func _prepni_mapovy_mod(mod: String) -> void:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return
	if map_loader.has_method("nastav_mapovy_mod"):
		map_loader.nastav_mapovy_mod(mod)
	_aktualizuj_stav_tlacitek_modu(mod)

func _ziskej_aktualni_mapovy_mod() -> String:
	var map_loader = _ziskej_map_loader()
	if map_loader == null:
		return "political"
	return str(map_loader.get("aktualni_mapovy_mod"))

func _aktualizuj_stav_tlacitek_modu(active_mode: String = "") -> void:
	if map_modes_box == null:
		return
	var mode = active_mode if active_mode != "" else _ziskej_aktualni_mapovy_mod()
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

func _on_mode_political_pressed() -> void:
	_prepni_mapovy_mod("political")

func _on_mode_population_pressed() -> void:
	_prepni_mapovy_mod("population")

func _on_mode_gdp_pressed() -> void:
	_prepni_mapovy_mod("gdp")

func _on_mode_ideology_pressed() -> void:
	_prepni_mapovy_mod("ideology")

func _on_mode_recruits_pressed() -> void:
	_prepni_mapovy_mod("recruitable_population")

func _on_mode_relations_pressed() -> void:
	_prepni_mapovy_mod("relationships")

func _on_mode_terrain_pressed() -> void:
	_prepni_mapovy_mod("terrain")

func _on_mode_resources_pressed() -> void:
	_prepni_mapovy_mod("resources")

func _on_mode_alliances_pressed() -> void:
	_prepni_mapovy_mod("alliances")

func aktualizuj_ui():
	# Update money and date counters
	money_label.text = "Funds: %.2f M USD (+%.2f)" % [GameManager.statni_kasa, GameManager.celkovy_prijem]
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

func _on_next_turn_pressed():
	if GameManager.has_method("pozaduj_ukonceni_kola"):
		GameManager.pozaduj_ukonceni_kola()
	else:
		GameManager.ukonci_kolo()

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
	parent.add_child(_turn_busy_indicator)
	parent.move_child(_turn_busy_indicator, next_btn.get_index() + 1)

func _on_zpracovani_tahu_zmeneno(aktivni: bool) -> void:
	_is_turn_processing = aktivni
	if next_btn:
		next_btn.disabled = aktivni
	if _turn_busy_indicator:
		_turn_busy_indicator.visible = aktivni and not _turn_busy_suppressed
		_turn_busy_anim_step = 0
		_turn_busy_indicator.text = TURN_BUSY_FRAMES[0]
	_turn_busy_anim_time = 0.0
	set_process(aktivni)

func nastav_pozastaveni_turn_busy_indicator(pozastavit: bool) -> void:
	_turn_busy_suppressed = pozastavit
	if _turn_busy_indicator:
		_turn_busy_indicator.visible = _is_turn_processing and not _turn_busy_suppressed

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

func _napoj_financni_hover() -> void:
	if money_label == null:
		return
	money_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if not money_label.mouse_entered.is_connected(_on_money_label_mouse_entered):
		money_label.mouse_entered.connect(_on_money_label_mouse_entered)
	if not money_label.mouse_exited.is_connected(_on_money_label_mouse_exited):
		money_label.mouse_exited.connect(_on_money_label_mouse_exited)

func _on_money_label_mouse_entered() -> void:
	_finance_tooltip_visible = true
	_aktualizuj_financni_tooltip_text()
	_aktualizuj_financni_tooltip_pozici()
	if _finance_tooltip_panel:
		_finance_tooltip_panel.show()

func _on_money_label_mouse_exited() -> void:
	_finance_tooltip_visible = false
	if _finance_tooltip_panel:
		_finance_tooltip_panel.hide()

func _format_finance_value(value: float) -> String:
	return "%.2f M USD" % value

func _format_finance_signed(value: float) -> String:
	return "%+.2f M USD" % value

func _aktualizuj_financni_tooltip_text() -> void:
	if _finance_tooltip_text == null:
		return

	var finance: Dictionary = {}
	if GameManager.has_method("ziskej_financni_rozpad_statu"):
		finance = GameManager.ziskej_financni_rozpad_statu(str(GameManager.hrac_stat))

	if not bool(finance.get("ok", false)):
		_finance_tooltip_text.text = "[color=#FFFFFF]Finance: data unavailable.[/color]"
		return

	var income = finance.get("income", {}) as Dictionary
	var expenses = finance.get("expenses", {}) as Dictionary
	var profit = float(finance.get("profit", 0.0))

	var t := ""
	t += "[b][color=#FFFFFF]INCOME[/color][/b]\n"
	t += "[color=#65D96E]GDP: %s[/color]\n" % _format_finance_value(float(income.get("gdp", 0.0)))
	t += "[color=#65D96E]Vassals: %s[/color]\n" % _format_finance_value(float(income.get("vassals", 0.0)))
	t += "[color=#65D96E]Reparations: %s[/color]\n" % _format_finance_value(float(income.get("reparations", 0.0)))
	t += "[color=#65D96E]Other: %s[/color]\n\n" % _format_finance_value(float(income.get("other", 0.0)))

	t += "[b][color=#FFFFFF]EXPENSES[/color][/b]\n"
	t += "[color=#FF6666]Army upkeep: %s[/color]\n" % _format_finance_value(float(expenses.get("army_upkeep", 0.0)))
	t += "[color=#FF6666]Investments: %s[/color]\n" % _format_finance_value(float(expenses.get("investments", 0.0)))
	t += "[color=#FF6666]Other: %s[/color]\n\n" % _format_finance_value(float(expenses.get("other", 0.0)))

	t += "[b][color=#FFFFFF]BALANCE (PROFIT): %s[/color][/b]" % _format_finance_signed(profit)
	_finance_tooltip_text.text = t

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

func _ziskej_map_loader_node() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("_ziskej_map_pozici_provincie") and scene_root.has_method("_ziskej_map_offset"):
		return scene_root
	if scene_root:
		var by_name = scene_root.find_child("Map", true, false)
		if by_name and by_name.has_method("_ziskej_map_pozici_provincie") and by_name.has_method("_ziskej_map_offset"):
			return by_name
	return null

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
