# ==================================================================================================
# ███╗   ███╗ █████╗ ██████╗ ███████╗    ██████╗ ██╗   ██╗    █████╗ ███████╗██████╗  ██████╗ ██╗  ██╗
# ████╗ ████║██╔══██╗██╔══██╗██╔════╝    ██╔══██╗╚██╗ ██╔╝   ██╔══██╗██╔════╝██╔══██╗██╔═══██╗╚██╗██╔╝
# ██╔████╔██║███████║██║  ██║█████╗      ██████╔╝ ╚████╔╝    ███████║█████╗  ██████╔╝██║   ██║ ╚███╔╝
# ██║╚██╔╝██║██╔══██║██║  ██║██╔══╝      ██╔══██╗  ╚██╔╝     ██╔══██║██╔══╝  ██╔══██╗██║   ██║ ██╔██╗
# ██║ ╚═╝ ██║██║  ██║██████╔╝███████╗    ██████╔╝   ██║      ██║  ██║██║     ██║  ██║╚██████╔╝██╔╝ ██╗
# ╚═╝     ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝    ╚═════╝    ╚═╝      ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝
#
#                                         Made By: Afrox26TP
# ==================================================================================================
extends Node2D
# this script drives a specific gameplay/UI area and keeps related logic together.

const CountryCustomization = preload("res://scripts/CountryCustomization.gd")

# Loads province data, switches map modes and resolves army movement on the actual map.
signal mapovy_mod_zmenen(mod: String)

@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")

var provinces = {}
var color_cache = {}
var ideology_flag_path_index: Dictionary = {}
var ideology_flag_index_ready: bool = false
var army_icon_texture_cache: Dictionary = {}
var flag_texture_cache: Dictionary = {}

var aktivni_armady = {} 
var aktivni_porty: Dictionary = {}
var _sea_position_cache: Dictionary = {}
var _province_pixel_center_cache: Dictionary = {}

# --- State variables for army movement targeting ---
var vybrana_armada_od: int = -1
var vybrana_armada_max: int = 0
var ceka_na_cil_presunu: bool = false
var ceka_na_cil_hlavniho_mesta: bool = false
var dostupne_cile_hlavniho_mesta: Array = []
var stat_presunu_hlavniho_mesta: String = ""
var ceka_na_cil_miru: bool = false
var stat_mirove_konference_vitez: String = ""
var stat_mirove_konference_porazeny: String = ""
var dostupne_cile_miru: Array = []
var vybrane_cile_miru: Array = []
var ceka_na_cil_trade_provincie: bool = false
var stat_trade_province_source: String = ""
var dostupne_cile_trade_provincie: Array = []
var vybrane_cile_trade_provincie: Array = []
var ceka_na_hromadny_cil_presunu: bool = false
var hromadny_presun_zdroje: Array = []
var hromadne_vybrane_provincie: Array = []
var cekajici_presuny = []
var obsazene_pozice_presunu: Array = []
var trasy_lane_counter: Dictionary = {}
var _pozastavit_aktualizaci_ikon: bool = false
var _minimalni_ai_tahy: Dictionary = {}
var _ai_anim_markery: Array = []
var _cekajici_anim_markery: Array = []
var _preview_anim_markery: Array = []
const MAX_MINIMALNI_AI_CAR := 90
const AI_MARKER_ATTACK_SPEED := 170.0
const AI_MARKER_MOVE_SPEED := 130.0
const FAST_TURN_RESOLUTION := true
const FAST_BATTLE_SUMMARY_MAX_LINES := 8
const FAST_TURN_SHOW_BATTLE_SUMMARY := true
const TURN_ARMY_SLICE_ENABLED := false
const TURN_ARMY_SLICE_BATCH := 90
var _bitevni_kamera_aktivni: bool = false
var _bitevni_puvodni_pozice: Vector2 = Vector2.ZERO
var aktualni_mapovy_mod: String = "political"
var _port_icons_dirty: bool = true
var _naval_reachable_cache_from: int = -1
var _naval_reachable_cache: Dictionary = {}
var _sea_province_cache: Dictionary = {}
var _coastal_province_cache: Dictionary = {}
var _sea_step_neighbors_cache: Dictionary = {}
var _land_step_neighbors_cache: Dictionary = {}
var _land_plus_sea_step_neighbors_cache: Dictionary = {}
var _land_step_distance_cap_cache: Dictionary = {}
var _last_army_state_signature: int = -1
var _preview_path_key: String = ""
var _hromadny_vyber_overlay_key: String = ""
var _loading_layer: CanvasLayer = null
var _loading_label: Label = null
var _loading_bar: ProgressBar = null
var _inicializace_hotova: bool = false
var _potato_mode_enabled: bool = false
var _turn_indicator_suppress_locks: int = 0
const PORT_ICON_PATH := "res://map_data/port_icon.svg"
const PORT_ICON_FALLBACK_PATH := "res://map_data/ArmyIcons/ArmyIconTemplate.svg"
const SETTINGS_FILE_PATH := "user://settings.cfg"
const PROVINCES_DATA_PATHS := [
	"res://map_data/province.txt",
	"res://map_data/Province.txt",
	"res://map_data/Provinces.txt"
]
const LAND_STEP_HARD_CAP_MIN := 220.0
const LAND_STEP_HARD_CAP_MAX := 900.0
const LAND_STEP_HARD_CAP_FACTOR := 2.4
const LAND_STEP_HARD_CAP_FALLBACK := 420.0
const TERRAIN_DEFENDER_BONUS_PCT := {
	"plains": -0.20,
	"plain": -0.20,
	"forest": 0.0,
	"hills": 0.20,
	"hill": 0.20,
	"mountains": 0.40,
	"mountain": 0.40,
	"city": 0.80
}
const ATTACKER_LIBERATION_BONUS_PCT := 0.10
# --------------------------------------------------------

# Tries a few filename variants because raw data names changed during dev a bit.
func _raw_data_path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)

# Executes module-specific gameplay/UI logic for the current context.
func _resolve_provinces_data_path() -> String:
	for path in PROVINCES_DATA_PATHS:
		if _raw_data_path_exists(path):
			return path
	return str(PROVINCES_DATA_PATHS[PROVINCES_DATA_PATHS.size() - 1])

func _build_column_index(header_line: String) -> Dictionary:
	var out: Dictionary = {}
	var cols = header_line.split(";")
	for i in range(cols.size()):
		out[str(cols[i]).strip_edges().to_lower()] = i
	return out

# Searches available data and returns the best matching result.
func _find_column_idx(col_index: Dictionary, names: Array, fallback_idx: int = -1) -> int:
	for raw_name in names:
		var key = str(raw_name).strip_edges().to_lower()
		if col_index.has(key):
			return int(col_index[key])
	return fallback_idx

func _read_int(parts: Array, idx: int, default_val: int = 0) -> int:
	if idx < 0 or idx >= parts.size():
		return default_val
	var raw = str(parts[idx]).strip_edges()
	if raw == "":
		return default_val
	return int(raw)

func _read_float(parts: Array, idx: int, default_val: float = 0.0) -> float:
	if idx < 0 or idx >= parts.size():
		return default_val
	var raw = str(parts[idx]).strip_edges()
	if raw == "":
		return default_val
	return float(raw)

func _read_text(parts: Array, idx: int, default_val: String = "") -> String:
	if idx < 0 or idx >= parts.size():
		return default_val
	return str(parts[idx]).strip_edges()

func _army_turn_slice_wait(counter: int, chunk: int = TURN_ARMY_SLICE_BATCH) -> int:
	if not TURN_ARMY_SLICE_ENABLED:
		return counter
	var next_counter = counter + 1
	if next_counter >= max(1, chunk):
		await get_tree().process_frame
		return 0
	return next_counter

# Returns whether required conditions are currently satisfied.
func _je_potato_mode_ze_settings() -> bool:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return false

	var display_mode = bool(cfg.get_value("display", "potato_mode", false))
	var other_mode = bool(cfg.get_value("other", "potato_mode", display_mode))
	return display_mode or other_mode

# Potato mode turns off some heavier visuals for weaker notebooks/PCs.
func nastav_potato_mode(enabled: bool) -> void:
	_potato_mode_enabled = enabled
	Engine.max_fps = 45 if enabled else 0
	OS.low_processor_usage_mode = enabled
	OS.low_processor_usage_mode_sleep_usec = 12000 if enabled else 6900

	var sprite = $Sprite2D
	if sprite and sprite.has_method("nastav_potato_mode"):
		sprite.nastav_potato_mode(enabled)

	var labels = get_node_or_null("ProvinceLabels")
	if labels:
		labels.visible = not enabled

	var labels_manager = get_node_or_null("CountryLabelsManager")
	if labels_manager and labels_manager.has_method("nastav_potato_mode"):
		labels_manager.nastav_potato_mode(enabled)
	elif labels_manager:
		labels_manager.visible = not enabled

# Builds required objects/UI nodes and wires essential defaults/signals.
func _vytvor_loading_overlay() -> void:
	if _loading_layer != null:
		return

	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 200
	add_child(_loading_layer)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.92)
	_loading_layer.add_child(bg)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 130)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_top = -65.0
	panel.offset_right = 210.0
	panel.offset_bottom = 65.0
	_loading_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.text = "Nacitani mapy..."
	vbox.add_child(_loading_label)

	_loading_bar = ProgressBar.new()
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = 100.0
	_loading_bar.value = 0.0
	_loading_bar.show_percentage = true
	vbox.add_child(_loading_bar)

func _nastav_loading_stav(text: String, progress_0_1: float) -> void:
	if _loading_label:
		_loading_label.text = text
	if _loading_bar:
		_loading_bar.value = clamp(progress_0_1 * 100.0, 0.0, 100.0)

func _skryj_loading_overlay() -> void:
	if _loading_layer:
		_loading_layer.queue_free()
	_loading_layer = null
	_loading_label = null
	_loading_bar = null

# Map mode switch updates shader colors and visibility of army/port markers.
func nastav_mapovy_mod(mod: String):
	aktualni_mapovy_mod = mod
	_aktualizuj_aktivni_mapovy_mod()
	_aplikuj_viditelnost_ukazatelu_jednotek()
	emit_signal("mapovy_mod_zmenen", aktualni_mapovy_mod)

func _aktualizuj_aktivni_mapovy_mod() -> void:
	var sprite = $Sprite2D
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod(aktualni_mapovy_mod, provinces)

func _jsou_ukazatele_jednotek_povolene() -> bool:
	return aktualni_mapovy_mod == "political"

# Applies prepared settings/effects to runtime systems.
func _aplikuj_viditelnost_ukazatelu_jednotek():
	var ukazovat = _jsou_ukazatele_jednotek_povolene()
	var army_container = get_node_or_null("ArmyContainer")
	var port_container = get_node_or_null("PortContainer")
	if army_container:
		army_container.visible = ukazovat
	if port_container:
		port_container.visible = ukazovat

	if not ukazovat:
		for prov_id in aktivni_armady.keys():
			var army_node = aktivni_armady[prov_id]
			if army_node:
				army_node.hide()

func _ziskej_map_offset() -> Vector2:
	var sprite = $Sprite2D
	if sprite and sprite.centered:
		return sprite.position - (sprite.texture.get_size() / 2.0)
	if sprite:
		return sprite.position
	return Vector2.ZERO

func _je_validni_lokalni_pozice(pos: Vector2) -> bool:
	if pos == Vector2.ZERO:
		return false
	var sprite = $Sprite2D
	if not sprite or not sprite.texture:
		return true
	var size = sprite.texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return true
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= size.x and pos.y <= size.y

func _ziskej_lokalni_pozici_provincie(prov_id: int) -> Vector2:
	if not provinces.has(prov_id):
		return Vector2.ZERO

	var d = provinces[prov_id]
	var x = float(d.get("x", 0.0))
	var y = float(d.get("y", 0.0))
	var data_pos = Vector2(x, y)
	if _je_validni_lokalni_pozice(data_pos):
		return data_pos

	# Fallback to mask centroid if province coordinates are missing/invalid in source data.
	var mask_pos = _ziskej_lokalni_pozici_z_masky_provincie(prov_id)
	if mask_pos != Vector2.ZERO:
		if _je_more_provincie(prov_id):
			_sea_position_cache[prov_id] = mask_pos
		return mask_pos

	if not _je_more_provincie(prov_id):
		return data_pos

	# Sea provinces usually do not have explicit x/y in data, so use mask centroid first.
	var sea_mask_pos = _ziskej_lokalni_pozici_z_masky_provincie(prov_id)
	if sea_mask_pos != Vector2.ZERO:
		_sea_position_cache[prov_id] = sea_mask_pos
		return sea_mask_pos

	if _sea_position_cache.has(prov_id):
		return _sea_position_cache[prov_id]

	var queue: Array = [prov_id]
	var visited: Dictionary = {}
	var samples: Array = []
	var head = 0

	while head < queue.size() and samples.size() < 10 and visited.size() < 220:
		var curr_id = int(queue[head])
		head += 1
		if visited.has(curr_id):
			continue
		visited[curr_id] = true
		if not provinces.has(curr_id):
			continue

		var curr = provinces[curr_id]
		var cx = float(curr.get("x", 0.0))
		var cy = float(curr.get("y", 0.0))
		if (cx != 0.0 or cy != 0.0) and not _je_more_provincie(curr_id):
			samples.append(Vector2(cx, cy))
			continue

		for n_id in curr.get("neighbors", []):
			var neighbor_id = int(n_id)
			if not visited.has(neighbor_id):
				queue.append(neighbor_id)

	if samples.is_empty():
		_sea_position_cache[prov_id] = Vector2.ZERO
		return Vector2.ZERO

	var avg = Vector2.ZERO
	for p in samples:
		avg += p
	avg /= float(samples.size())

	# Add tiny deterministic spread so neighboring sea provinces do not stack exactly.
	var angle = deg_to_rad(float((prov_id * 97) % 360))
	avg += Vector2(cos(angle), sin(angle)) * 7.0

	_sea_position_cache[prov_id] = avg
	return avg

# Reads current runtime data and returns it to callers.
func _ziskej_lokalni_pozici_z_masky_provincie(prov_id: int) -> Vector2:
	if _province_pixel_center_cache.has(prov_id):
		return _province_pixel_center_cache[prov_id]

	if not provinces.has(prov_id):
		return Vector2.ZERO

	var sprite = $Sprite2D
	if not sprite:
		return Vector2.ZERO

	var map_image = sprite.get("map_image")
	if map_image == null:
		return Vector2.ZERO

	var target_color: Color = provinces[prov_id].get("color", Color.BLACK)
	var width = map_image.get_width()
	var height = map_image.get_height()
	if width <= 0 or height <= 0:
		return Vector2.ZERO

	# Hard performance cap: sample up to ~220k pixels instead of scanning the full texture.
	var pixel_count = width * height
	var sample_budget = 220000
	var step = 1
	if pixel_count > sample_budget:
		step = int(ceil(sqrt(float(pixel_count) / float(sample_budget))))
		step = max(1, step)

	var sum = Vector2.ZERO
	var cnt := 0
	for yy in range(0, height, step):
		for xx in range(0, width, step):
			var px = map_image.get_pixel(xx, yy)
			if px.a <= 0.0:
				continue
			if absf(px.r - target_color.r) <= 0.006 and absf(px.g - target_color.g) <= 0.006 and absf(px.b - target_color.b) <= 0.006:
				sum += Vector2(float(xx), float(yy))
				cnt += 1

	if cnt <= 0:
		return Vector2.ZERO

	var center = sum / float(cnt)
	_province_pixel_center_cache[prov_id] = center
	return center

# Reads current runtime data and returns it to callers.
func _ziskej_map_pozici_provincie(prov_id: int, offset: Vector2) -> Vector2:
	return _ziskej_lokalni_pozici_provincie(prov_id) + offset

func ziskej_prov_id_podle_ikony_armady(global_mouse_pos: Vector2, tolerance: float = 16.0) -> int:
	if aktivni_armady.is_empty():
		return -1

	var best_prov_id := -1
	var best_dist_sq := INF

	for raw_id in aktivni_armady.keys():
		var prov_id = int(raw_id)
		var army_node = aktivni_armady[prov_id]
		if not army_node or not army_node.visible:
			continue

		var icon = army_node.get_node_or_null("Icon") as Sprite2D
		var icon_pos = army_node.global_position
		var radius = tolerance

		if icon:
			icon_pos = icon.global_position
			if icon.texture:
				var tex_size = icon.texture.get_size()
				var scale_factor = max(absf(icon.global_scale.x), absf(icon.global_scale.y))
				var tex_radius = (max(tex_size.x, tex_size.y) * 0.5) * scale_factor
				radius = max(radius, tex_radius + 6.0)

		var dist_sq = icon_pos.distance_squared_to(global_mouse_pos)
		if dist_sq <= (radius * radius) and dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_prov_id = prov_id

	return best_prov_id

func nastav_vybranou_armadu_provincie(selected_prov_id: int):
	var vybrane_armady: Dictionary = {}
	if selected_prov_id >= 0:
		vybrane_armady[selected_prov_id] = true
	for raw_multi in hromadne_vybrane_provincie:
		var multi_id = int(raw_multi)
		if multi_id >= 0:
			vybrane_armady[multi_id] = true

	for raw_id in aktivni_armady.keys():
		var prov_id = int(raw_id)
		var army_node = aktivni_armady[prov_id]
		if not army_node:
			continue
		var ring = army_node.get_node_or_null("SelectionRing")
		if ring:
			var owner_tag = _ziskej_vlastnika_armady_v_provincii(prov_id)
			var je_moje_armada = owner_tag == GameManager.hrac_stat
			ring.visible = vybrane_armady.has(prov_id) and je_moje_armada

func _aktualizuj_selection_ring_geometrii(army_node: Node2D):
	if not army_node:
		return

	var ring = army_node.get_node_or_null("SelectionRing") as Line2D
	var icon = army_node.get_node_or_null("Icon") as Sprite2D
	if ring == null or icon == null:
		return
	if icon.texture == null:
		return

	var tex_size = icon.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var half_w = (tex_size.x * absf(icon.scale.x)) * 0.5
	var half_h = (tex_size.y * absf(icon.scale.y)) * 0.5
	var pad = 2.2
	var ring_half_w = half_w + pad
	var ring_half_h = half_h + pad
	var ring_width = clamp(max(ring_half_w, ring_half_h) * 0.14, 1.6, 3.2)

	ring.width = ring_width
	ring.clear_points()
	ring.add_point(Vector2(-ring_half_w, -ring_half_h))
	ring.add_point(Vector2(ring_half_w, -ring_half_h))
	ring.add_point(Vector2(ring_half_w, ring_half_h))
	ring.add_point(Vector2(-ring_half_w, ring_half_h))
	ring.add_point(Vector2(-ring_half_w, -ring_half_h))

func _ziskej_pozici_armady_v_provincii(prov_id: int, offset: Vector2) -> Vector2:
	var base_pos = _ziskej_map_pozici_provincie(prov_id, offset)
	# Keep sea fleets centered on sea tile, but move land armies below province names.
	if _je_more_provincie(prov_id):
		return base_pos

	# Keep army marker close to province name first; overlap solver can move it if needed.
	var y_offset = 14.0
	if provinces.has(prov_id) and bool(provinces[prov_id].get("is_capital", false)):
		y_offset = 17.0
	return base_pos + Vector2(0, y_offset)

# Reads current runtime data and returns it to callers.
func _ziskej_lane_index(slot: int) -> int:
	if slot <= 0:
		return 0
	var magnitude = int((float(slot) + 1.0) / 2.0)
	if slot % 2 == 1:
		return magnitude
	return -magnitude

# Executes module-specific gameplay/UI logic for the current context.
func _vypocitej_ofset_trasy(from_id: int, to_id: int, start_pos: Vector2, end_pos: Vector2) -> Vector2:
	var a = min(from_id, to_id)
	var b = max(from_id, to_id)
	var key = "%d_%d" % [a, b]
	var slot = int(trasy_lane_counter.get(key, 0))
	trasy_lane_counter[key] = slot + 1

	if slot == 0:
		return Vector2.ZERO

	var dir = end_pos - start_pos
	if dir.length() < 0.001:
		return Vector2.ZERO

	var lane_index = _ziskej_lane_index(slot)
	return dir.normalized().orthogonal() * (12.0 * float(lane_index))

func _najdi_volnou_pozici(base_pos: Vector2, occupied_positions: Array, min_distance: float) -> Vector2:
	if occupied_positions.is_empty():
		return base_pos

	var blocked = false
	for p in occupied_positions:
		if base_pos.distance_to(p) < min_distance:
			blocked = true
			break
	if not blocked:
		return base_pos

	# If the preferred spot is occupied, search around province center in expanding circles.
	var radii = [12.0, 18.0, 24.0, 30.0, 38.0]
	var angles_deg = [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]
	for r in radii:
		for deg in angles_deg:
			var a = deg_to_rad(deg)
			var candidate = base_pos + Vector2(cos(a), sin(a)) * r
			var local_blocked = false
			for p in occupied_positions:
				if candidate.distance_to(p) < min_distance:
					local_blocked = true
					break
			if not local_blocked:
				return candidate

	return base_pos + Vector2(42, 0)

# Reads current runtime data and returns it to callers.
func _ziskej_obsazene_pozice_armad() -> Array:
	var occupied: Array = []
	for prov_id in aktivni_armady.keys():
		var army_node = aktivni_armady[prov_id]
		if army_node and army_node.visible:
			occupied.append(army_node.position)
	return occupied

func _rozmisti_armady_bez_overlapu():
	if aktivni_armady.is_empty():
		return

	var occupied: Array = []
	var sorted_ids: Array = aktivni_armady.keys()
	sorted_ids.sort_custom(func(a, b):
		return int(provinces[a].get("soldiers", 0)) > int(provinces[b].get("soldiers", 0))
	)

	for prov_id in sorted_ids:
		var army_node = aktivni_armady[prov_id]
		if not army_node or not army_node.visible:
			continue

		if not army_node.has_meta("base_pos"):
			continue

		var base_pos = army_node.get_meta("base_pos") as Vector2
		# Keep fleets anchored to their sea tile center so they never drift onto land.
		var final_pos = base_pos if _je_more_provincie(int(prov_id)) else _najdi_volnou_pozici(base_pos, occupied, 24.0)
		army_node.position = final_pos
		occupied.append(final_pos)

# Reads current runtime data and returns it to callers.
func _get_cached_texture(path: String, cache: Dictionary):
	if path == "":
		return null
	if cache.has(path):
		return cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	cache[path] = tex
	return tex

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

func _get_flag_texture(tag: String, ideology: String):
	var custom_tex = CountryCustomization.load_custom_flag_texture(tag, flag_texture_cache)
	if custom_tex:
		return custom_tex
	var ideologie = _normalizuj_ideologii(ideology)
	var cisty_tag = tag.strip_edges().to_upper()
	if cisty_tag == "DEU":
		if ideologie == "fasismus":
			ideologie = "nacismus"
		elif ideologie == "nacismus":
			ideologie = "fasismus"
	if ideologie != "":
		_ensure_ideology_flag_index()
		var key = "%s|%s" % [cisty_tag, ideologie]
		if ideology_flag_path_index.has(key):
			var ideol_path = str(ideology_flag_path_index[key])
			var ideol_tex = _get_cached_texture(ideol_path, flag_texture_cache)
			if ideol_tex:
				return ideol_tex

	for path in ["res://map_data/Flags/%s.svg" % tag, "res://map_data/Flags/%s.png" % tag]:
		var tex = _get_cached_texture(path, flag_texture_cache)
		if tex:
			return tex
	return null

func _get_army_icon_texture(owner_tag: String):
	var icon_path = "res://map_data/ArmyIcons/%s.svg" % owner_tag
	var fallback_path = "res://map_data/ArmyIcons/ArmyIconTemplate.svg"
	var icon_tex = _get_cached_texture(icon_path, army_icon_texture_cache)
	if icon_tex:
		return icon_tex
	return _get_cached_texture(fallback_path, army_icon_texture_cache)

# Reads current runtime data and returns it to callers.
func _get_port_icon_texture():
	var icon_tex = _get_cached_texture(PORT_ICON_PATH, army_icon_texture_cache)
	if icon_tex:
		return icon_tex
	return _get_cached_texture(PORT_ICON_FALLBACK_PATH, army_icon_texture_cache)

# Reads current runtime data and returns it to callers.
func _ziskej_zakladni_barvu_statu(tag: String) -> Color:
	if tag == "":
		return Color(0.62, 0.62, 0.66, 1.0)

	var sprite = $Sprite2D
	if sprite and ("country_colors" in sprite):
		var country_cols = sprite.country_colors
		if country_cols is Dictionary and country_cols.has(tag):
			var c = country_cols[tag]
			return Color(c.r, c.g, c.b, 1.0)

	var hue = float(abs(tag.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 0.86, 1.0)

func _ziskej_barvu_overlay_statu(tag: String, is_attack: bool) -> Color:
	var base = _ziskej_zakladni_barvu_statu(tag)
	var out_col: Color
	if is_attack:
		# Attack overlay is always a lighter variant of the country's color.
		out_col = base.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.42)
		out_col.a = 0.94
	else:
		# Regular moves stay close to country color but brighter than base.
		out_col = base.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.24)
		out_col.a = 0.86
	return out_col

# Reads current runtime data and returns it to callers.
func _ziskej_nasobic_sily_statu(state_tag: String) -> float:
	var cisty = state_tag.strip_edges().to_upper()
	if cisty == "" or cisty == "SEA":
		return 1.0
	if GameManager == null or not GameManager.has_method("ziskej_silu_armady_statu"):
		return 1.0

	var info = GameManager.ziskej_silu_armady_statu(cisty) as Dictionary
	if not bool(info.get("ok", false)):
		return 1.0

	var base = int(info.get("base", 0))
	var total = int(info.get("total", base))
	if base > 0:
		return max(0.05, float(total) / float(base))

	# If state currently has no soldiers, fall back to percentage component.
	var bonus_pct = max(0.0, float(info.get("bonus_pct", 0.0)))
	return max(1.0, 1.0 + bonus_pct)

func _ziskej_terenni_obranny_bonus_pct(prov_id: int) -> float:
	if not provinces.has(prov_id):
		return 0.0

	var terrain_raw = str(provinces[prov_id].get("terrain", "")).strip_edges().to_lower()
	if terrain_raw == "":
		return 0.0

	if TERRAIN_DEFENDER_BONUS_PCT.has(terrain_raw):
		return float(TERRAIN_DEFENDER_BONUS_PCT[terrain_raw])
	return 0.0

func _ziskej_bonus_utocnika_pri_osvobozovani(prov_id: int, attacker_tag: String) -> float:
	if not provinces.has(prov_id):
		return 0.0

	var atk = attacker_tag.strip_edges().to_upper()
	if atk == "" or atk == "SEA":
		return 0.0

	var owner_tag = str(provinces[prov_id].get("owner", "")).strip_edges().to_upper()
	var core_owner = str(provinces[prov_id].get("core_owner", owner_tag)).strip_edges().to_upper()
	if core_owner == "" or core_owner == "SEA":
		return 0.0

	# Liberation bonus applies only when attacker fights for their own occupied core land.
	if core_owner == atk and owner_tag != atk:
		return ATTACKER_LIBERATION_BONUS_PCT
	return 0.0

func ziskej_terenni_obranny_bonus_pct(prov_id: int) -> float:
	return _ziskej_terenni_obranny_bonus_pct(prov_id)

func ziskej_bonus_utocnika_pri_osvobozovani(prov_id: int, attacker_tag: String) -> float:
	return _ziskej_bonus_utocnika_pri_osvobozovani(prov_id, attacker_tag)

func ziskej_nahled_bojovych_modifikatoru(from_id: int, to_id: int) -> Dictionary:
	if not provinces.has(from_id) or not provinces.has(to_id):
		return {"ok": false, "reason": "invalid_province"}

	var attacker_tag = _ziskej_vlastnika_armady_v_provincii(from_id)
	if attacker_tag == "":
		return {"ok": false, "reason": "no_attacker"}

	var defender_tag = _ziskej_braniciho_vlastnika_v_provincii(to_id)
	var is_attack = (defender_tag != "" and defender_tag != attacker_tag and defender_tag != "SEA")

	var terrain_bonus = 0.0
	var liberation_bonus = 0.0
	if is_attack:
		terrain_bonus = _ziskej_terenni_obranny_bonus_pct(to_id)
		liberation_bonus = _ziskej_bonus_utocnika_pri_osvobozovani(to_id, attacker_tag)

	var attacker_state_mult = _ziskej_nasobic_sily_statu(attacker_tag)
	var defender_state_mult = _ziskej_nasobic_sily_statu(defender_tag) if defender_tag != "" else 1.0

	return {
		"ok": true,
		"is_attack": is_attack,
		"attacker_tag": attacker_tag,
		"defender_tag": defender_tag,
		"terrain": str(provinces[to_id].get("terrain", "")).strip_edges().to_lower(),
		"attacker_bonus_pct": liberation_bonus,
		"defender_bonus_pct": terrain_bonus,
		"attacker_state_mult": attacker_state_mult,
		"defender_state_mult": defender_state_mult,
		"attacker_total_mult": attacker_state_mult * max(0.05, 1.0 + liberation_bonus),
		"defender_total_mult": defender_state_mult * max(0.05, 1.0 + terrain_bonus)
	}

# Build a readable battle text block for system popup (numbers + quick context).
func _format_battle_popup_text(attacker_tag: String, defender_tag: String, attacker_before: int, defender_before: int, attacker_after: int, defender_after: int, summary: String, province_name: String = "") -> String:
	var winner = "No winner"
	if attacker_after > 0 and defender_after <= 0:
		winner = attacker_tag
	elif defender_after > 0 and attacker_after <= 0:
		winner = defender_tag

	var location_label = province_name.strip_edges()
	if location_label == "":
		location_label = "unknown"

	var att_losses = max(0, attacker_before - attacker_after)
	var def_losses = max(0, defender_before - defender_after)

	return "BATTLE REPORT\nLocation: %s\nSummary: %s\nWinner: %s\n\nAttacker %s\n- Before: %s\n- Survivors: %s\n- Casualties: %s\n\nDefender %s\n- Before: %s\n- Survivors: %s\n- Casualties: %s" % [
		location_label,
		summary.strip_edges(),
		winner,
		attacker_tag,
		_formatuj_cislo(attacker_before),
		_formatuj_cislo(attacker_after),
		_formatuj_cislo(att_losses),
		defender_tag,
		_formatuj_cislo(defender_before),
		_formatuj_cislo(defender_after),
		_formatuj_cislo(def_losses)
	]

# Prepare compact payload for UI battle panel (flags, winner, strength split).
func _vytvor_bitevni_payload(attacker_tag: String, defender_tag: String, attacker_before: int, defender_before: int, attacker_after: int, defender_after: int, province_name: String = "") -> Dictionary:
	var winner_tag = ""
	if attacker_after > 0 and defender_after <= 0:
		winner_tag = attacker_tag
	elif defender_after > 0 and attacker_after <= 0:
		winner_tag = defender_tag

	var player_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	var left_tag = attacker_tag
	var right_tag = defender_tag
	var left_before = attacker_before
	var right_before = defender_before
	var left_after = attacker_after
	var right_after = defender_after

	# Keep the human player on the left whenever possible; feels more natural in UI.
	if player_tag != "" and player_tag == defender_tag and player_tag != attacker_tag:
		left_tag = defender_tag
		right_tag = attacker_tag
		left_before = defender_before
		right_before = attacker_before
		left_after = defender_after
		right_after = attacker_after

	return {
		"left_tag": left_tag,
		"right_tag": right_tag,
		"winner_tag": winner_tag,
		"left_before": left_before,
		"right_before": right_before,
		"left_after": left_after,
		"right_after": right_after,
		"province_name": province_name.strip_edges()
	}

# Executes module-specific gameplay/UI logic for the current context.
func _vyres_souboj_podle_sily(attacker_tag: String, attacker_soldiers: int, defender_tag: String, defender_soldiers: int, defender_bonus_pct: float = 0.0, attacker_bonus_pct: float = 0.0) -> Dictionary:
	var att_count = max(0, attacker_soldiers)
	var def_count = max(0, defender_soldiers)
	if att_count <= 0 and def_count <= 0:
		return {"attacker_won": false, "defender_won": false, "attacker_survivors": 0, "defender_survivors": 0}
	if def_count <= 0:
		return {"attacker_won": true, "defender_won": false, "attacker_survivors": att_count, "defender_survivors": 0}
	if att_count <= 0:
		return {"attacker_won": false, "defender_won": true, "attacker_survivors": 0, "defender_survivors": def_count}

	var att_mult = _ziskej_nasobic_sily_statu(attacker_tag)
	att_mult *= max(0.05, 1.0 + attacker_bonus_pct)
	var def_mult = _ziskej_nasobic_sily_statu(defender_tag)
	def_mult *= max(0.05, 1.0 + defender_bonus_pct)
	var att_power = float(att_count) * att_mult
	var def_power = float(def_count) * def_mult
	var eps = 0.0001

	if abs(att_power - def_power) <= eps:
		return {
			"attacker_won": false,
			"defender_won": false,
			"attacker_survivors": 0,
			"defender_survivors": 0,
			"attacker_power": att_power,
			"defender_power": def_power
		}

	if att_power > def_power:
		var left_power = att_power - def_power
		var survivors = int(ceil(left_power / max(0.0001, att_mult)))
		survivors = clampi(survivors, 1, att_count)
		return {
			"attacker_won": true,
			"defender_won": false,
			"attacker_survivors": survivors,
			"defender_survivors": 0,
			"attacker_power": att_power,
			"defender_power": def_power
		}

	var left_power_def = def_power - att_power
	var def_survivors = int(ceil(left_power_def / max(0.0001, def_mult)))
	def_survivors = clampi(def_survivors, 1, def_count)
	return {
		"attacker_won": false,
		"defender_won": true,
		"attacker_survivors": 0,
		"defender_survivors": def_survivors,
		"attacker_power": att_power,
		"defender_power": def_power
	}

func _ready():
	_inicializace_hotova = false
	_vytvor_loading_overlay()
	_nastav_loading_stav("Nacitani mapy...", 0.03)
	await get_tree().process_frame

	_nastav_loading_stav("Nacitani provincii...", 0.16)
	print("[MapInit] 1/6 load_provinces")
	load_provinces()
	print("Nacteno provincii z TXT: ", provinces.size())
	await get_tree().process_frame
	
	_nastav_loading_stav("Inicializace kamery a map modu...", 0.30)
	print("[MapInit] 2/6 camera+map mode")
	var kamera = $Camera2D 
	if kamera:
		kamera.zoom_zmenen.connect(_na_zmenu_zoomu)
	else:
		print("Chyba: Kamera nenalezena!")

	nastav_potato_mode(_je_potato_mode_ze_settings())

	var sprite = $Sprite2D
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod("political", provinces)
	nastav_mapovy_mod("political")
	await get_tree().process_frame
	
	_nastav_loading_stav("Generating province names...", 0.48)
	print("[MapInit] 3/6 province labels")
	generuj_nazvy_provincii()
	await get_tree().process_frame
	
	_nastav_loading_stav("Generating country names...", 0.63)
	print("[MapInit] 4/6 country labels")
	var labels_manager = get_node_or_null("CountryLabelsManager")
	var prov_labels = get_node_or_null("ProvinceLabels")
	if not _potato_mode_enabled and labels_manager and prov_labels:
		labels_manager.aktualizuj_labely_statu(provinces, prov_labels)
	await get_tree().process_frame
	
	_nastav_loading_stav("Preparing economy and ports...", 0.80)
	print("[MapInit] 5/6 economy+ports")
	if GameManager.has_method("spocitej_prijem"):
		if GameManager.has_method("pridej_startovni_pristavy"):
			GameManager.pridej_startovni_pristavy(provinces)
		GameManager.spocitej_prijem(provinces)
	await get_tree().process_frame
		
	_nastav_loading_stav("Nacitani armadnich ikon...", 0.93)
	print("[MapInit] 6/6 army icons")
	aktualizuj_ikony_armad()
	if GameManager.has_signal("kolo_zmeneno"):
		GameManager.kolo_zmeneno.connect(aktualizuj_ikony_armad)
	set_process(false)
	_nastav_loading_stav("Hotovo", 1.0)
	await get_tree().process_frame
	_skryj_loading_overlay()
	_inicializace_hotova = true
	print("[MapInit] done")

func je_pripraveno_pro_load() -> bool:
	return _inicializace_hotova

# Runs frame-by-frame updates while this node is active.
func _process(delta: float):
	if _ai_anim_markery.is_empty() and _cekajici_anim_markery.is_empty() and _preview_anim_markery.is_empty():
		set_process(false)
		return

	_ai_anim_markery = _aktualizuj_anim_markery(_ai_anim_markery, delta)
	_cekajici_anim_markery = _aktualizuj_anim_markery(_cekajici_anim_markery, delta)
	_preview_anim_markery = _aktualizuj_anim_markery(_preview_anim_markery, delta)

	if _ai_anim_markery.is_empty() and _cekajici_anim_markery.is_empty() and _preview_anim_markery.is_empty():
		set_process(false)

# Recomputes and refreshes state from the latest game/UI data.
func _aktualizuj_anim_markery(markery: Array, delta: float) -> Array:
	var out = markery
	for i in range(out.size() - 1, -1, -1):
		var m = out[i]
		var node = m.get("node", null)
		if not is_instance_valid(node):
			out.remove_at(i)
			continue

		var length = max(1.0, float(m.get("length", 1.0)))
		var speed = float(m.get("speed", AI_MARKER_MOVE_SPEED))
		var speed_scale = float(m.get("speed_scale", 1.0))
		var progress = float(m.get("progress", 0.0)) + (((speed * speed_scale) * delta) / length)
		progress = fposmod(progress, 1.0)
		m["progress"] = progress

		if m.has("poly_points"):
			var poly_points: PackedVector2Array = m.get("poly_points", PackedVector2Array())
			var poly_lengths: PackedFloat32Array = m.get("poly_lengths", PackedFloat32Array())
			if poly_points.size() < 2 or poly_lengths.size() < 2:
				out.remove_at(i)
				node.queue_free()
				continue

			var total_len = max(1.0, float(poly_lengths[poly_lengths.size() - 1]))
			var distance = progress * total_len
			var sample = _sample_polyline_position(poly_points, poly_lengths, distance)
			node.position = sample["position"]
			node.rotation = float(sample["angle"])
		else:
			var start_pos = m.get("start", Vector2.ZERO) as Vector2
			var dir = m.get("dir", Vector2.RIGHT) as Vector2
			node.position = start_pos + (dir * progress)
		out[i] = m

	return out

# Executes module-specific gameplay/UI logic for the current context.
func _sample_polyline_position(points: PackedVector2Array, cumulative_lengths: PackedFloat32Array, distance: float) -> Dictionary:
	if points.size() < 2 or cumulative_lengths.size() < 2:
		return {"position": Vector2.ZERO, "angle": 0.0}

	var total_len = float(cumulative_lengths[cumulative_lengths.size() - 1])
	if total_len <= 0.001:
		var fallback_dir = points[1] - points[0]
		return {
			"position": points[0],
			"angle": fallback_dir.angle()
		}

	var d = clamp(distance, 0.0, total_len)
	var seg_idx = 1
	while seg_idx < cumulative_lengths.size() and d > float(cumulative_lengths[seg_idx]):
		seg_idx += 1

	seg_idx = clampi(seg_idx, 1, points.size() - 1)
	var seg_start = points[seg_idx - 1]
	var seg_end = points[seg_idx]
	var seg_from = float(cumulative_lengths[seg_idx - 1])
	var seg_to = float(cumulative_lengths[seg_idx])
	var seg_len = max(0.001, seg_to - seg_from)
	var t = clamp((d - seg_from) / seg_len, 0.0, 1.0)
	var seg_dir = seg_end - seg_start

	return {
		"position": seg_start.lerp(seg_end, t),
		"angle": seg_dir.angle()
	}

func _pridej_animovany_marker(container: Node2D, marker_store: Array, start_pos: Vector2, end_pos: Vector2, color: Color, speed: float, phase: float, width: float):
	var dir = end_pos - start_pos
	var length = dir.length()
	if length < 0.001:
		return

	var marker = Polygon2D.new()
	var s = clamp(width * 0.40, 0.75, 1.65)
	marker.polygon = PackedVector2Array([
		Vector2(-5.2, -2.2) * s,
		Vector2(1.4, -2.2) * s,
		Vector2(1.4, -4.3) * s,
		Vector2(7.2, 0.0) * s,
		Vector2(1.4, 4.3) * s,
		Vector2(1.4, 2.2) * s,
		Vector2(-5.2, 2.2) * s
	])
	marker.color = color
	marker.rotation = dir.angle()
	container.add_child(marker)

	# Slow down markers on short paths so they do not look too frantic.
	var speed_scale = clamp(length / 220.0, 0.35, 1.0)

	marker_store.append({
		"node": marker,
		"start": start_pos,
		"dir": dir,
		"length": length,
		"speed": speed,
		"speed_scale": speed_scale,
		"progress": fposmod(phase, 1.0)
	})

# Executes module-specific gameplay/UI logic for the current context.
func _pridej_animovany_marker_po_linii(container: Node2D, marker_store: Array, poly_points: PackedVector2Array, color: Color, speed: float, phase: float, width: float):
	if poly_points.size() < 2:
		return

	var cumulative = PackedFloat32Array()
	cumulative.append(0.0)
	var total_len := 0.0
	for i in range(1, poly_points.size()):
		total_len += poly_points[i - 1].distance_to(poly_points[i])
		cumulative.append(total_len)

	if total_len < 0.001:
		return

	var marker = Polygon2D.new()
	var s = clamp(width * 0.40, 0.75, 1.65)
	marker.polygon = PackedVector2Array([
		Vector2(-5.2, -2.2) * s,
		Vector2(1.4, -2.2) * s,
		Vector2(1.4, -4.3) * s,
		Vector2(7.2, 0.0) * s,
		Vector2(1.4, 4.3) * s,
		Vector2(1.4, 2.2) * s,
		Vector2(-5.2, 2.2) * s
	])
	marker.color = color
	container.add_child(marker)

	var speed_scale = clamp(total_len / 220.0, 0.35, 1.0)
	var sample = _sample_polyline_position(poly_points, cumulative, fposmod(phase, 1.0) * total_len)
	marker.position = sample["position"]
	marker.rotation = float(sample["angle"])

	marker_store.append({
		"node": marker,
		"poly_points": poly_points,
		"poly_lengths": cumulative,
		"length": total_len,
		"speed": speed,
		"speed_scale": speed_scale,
		"progress": fposmod(phase, 1.0)
	})

# Loads data/resources and validates parsed results.
func load_provinces():
	var data_path = _resolve_provinces_data_path()
	var file = FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_error("Chybi dataset provincii!")
		return

	if file.eof_reached():
		return

	var header_line = file.get_line().strip_edges()
	var col_index = _build_column_index(header_line)

	var idx_id = _find_column_idx(col_index, ["id"], 0)
	var idx_r = _find_column_idx(col_index, ["r"], 1)
	var idx_g = _find_column_idx(col_index, ["g"], 2)
	var idx_b = _find_column_idx(col_index, ["b"], 3)
	var idx_type = _find_column_idx(col_index, ["type"], 4)
	var idx_state = _find_column_idx(col_index, ["state"], 5)
	var idx_core_owner = _find_column_idx(col_index, ["owner", "core_owner"], 6)
	var idx_controller = _find_column_idx(col_index, ["controller", "owner"], 6)
	var idx_x = _find_column_idx(col_index, ["x"], 8)
	var idx_y = _find_column_idx(col_index, ["y"], 9)
	var idx_province_name = _find_column_idx(col_index, ["province_name"], 10)
	var idx_country_name = _find_column_idx(col_index, ["country_name"], 11)
	var idx_population = _find_column_idx(col_index, ["population"], 12)
	var idx_gdp = _find_column_idx(col_index, ["gdp"], 13)
	var idx_is_capital = _find_column_idx(col_index, ["is_capital"], 15)
	var idx_capital_city = _find_column_idx(col_index, ["capital_city", "capital_name"], 16)
	var idx_neighbors = _find_column_idx(col_index, ["neighbors"], 17)
	var idx_ideology = _find_column_idx(col_index, ["ideology"], 18)
	var idx_recruitable = _find_column_idx(col_index, ["recruitable_population"], 19)
	var idx_soldiers = _find_column_idx(col_index, ["soldiers", "army", "army_size"], -1)
	var idx_happiness = _find_column_idx(col_index, ["happiness"], -1)
	var idx_terrain = _find_column_idx(col_index, ["terrain"], -1)
	var idx_terrain_index = _find_column_idx(col_index, ["terrain_index"], -1)
	var idx_resource_type = _find_column_idx(col_index, ["resource_type"], -1)
	var idx_resource_index = _find_column_idx(col_index, ["resource_index"], -1)
	var idx_resource_amount = _find_column_idx(col_index, ["resource_amount"], -1)
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
			
		var parts = line.split(";")
		if parts.size() < 7: continue 
			
		var prov_id = _read_int(parts, idx_id, -1)
		if prov_id < 0:
			continue

		var pop = _read_int(parts, idx_population)
		var gdp_val = _read_float(parts, idx_gdp)

		var je_to_hlavni = _read_int(parts, idx_is_capital) == 1
		var nazev_mesta = _read_text(parts, idx_capital_city)
			
		var neighbors_array = []
		var n_str = _read_text(parts, idx_neighbors)
		if n_str != "":
			for n in n_str.split(","):
				if n.strip_edges() != "":
					neighbors_array.append(int(n))

		var ideologie_statu = _read_text(parts, idx_ideology).to_lower()
		var core_owner_tag = _read_text(parts, idx_core_owner).to_upper()
		var controller_tag = _read_text(parts, idx_controller, core_owner_tag).to_upper()
		if controller_tag == "":
			controller_tag = core_owner_tag

		var r = _read_int(parts, idx_r)
		var g = _read_int(parts, idx_g)
		var b = _read_int(parts, idx_b)
		var recruitable_population = _read_int(parts, idx_recruitable)
		var soldiers = _read_int(parts, idx_soldiers)
		
		provinces[prov_id] = {
			"id": prov_id,
			"color": Color8(r, g, b),
			"type": _read_text(parts, idx_type),
			"state": _read_text(parts, idx_state),
			"owner": controller_tag,
			"core_owner": core_owner_tag,
			"x": _read_float(parts, idx_x),
			"y": _read_float(parts, idx_y),
			"province_name": _read_text(parts, idx_province_name),
			"country_name": _read_text(parts, idx_country_name),
			"population": pop,
			"gdp": gdp_val,
			"is_capital": je_to_hlavni,
			"capital_name": nazev_mesta,
			"neighbors": neighbors_array,
			"ideology": ideologie_statu,
			"recruitable_population": recruitable_population,
			"base_recruitable_population": recruitable_population,
			"soldiers": soldiers,
			"army_owner": "" if controller_tag == "SEA" else controller_tag,
			"controller": controller_tag,
			"happiness": _read_int(parts, idx_happiness),
			"terrain": _read_text(parts, idx_terrain),
			"terrain_index": _read_int(parts, idx_terrain_index),
			"resource_type": _read_text(parts, idx_resource_type),
			"resource_index": _read_int(parts, idx_resource_index),
			"resource_amount": _read_int(parts, idx_resource_amount),
			"has_port": false
		}

	_sea_position_cache.clear()
	_province_pixel_center_cache.clear()
	_invalidate_movement_topology_cache()
	_rebuild_movement_topology_cache()
	_invalidate_naval_reachability_cache()

# Executes module-specific gameplay/UI logic for the current context.
func generuj_nazvy_provincii():
	var label_container = Node2D.new()
	label_container.name = "ProvinceLabels"
	add_child(label_container)
	
	var sprite = $Sprite2D
	var offset = Vector2.ZERO
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position

	var serazene_provinci = provinces.values()
	serazene_provinci.sort_custom(func(a, b): 
		if a.get("is_capital", false) != b.get("is_capital", false):
			return a.get("is_capital", false)
		return a.get("population", 0) > b.get("population", 0)
	)

	var umistene_pozice = []
	var MIN_VZDALENOST = 60.0 

	for d in serazene_provinci:
		if str(d.get("owner", "")) == "SEA" or str(d.get("province_name", "")) == "":
			continue
			
		var pozice = Vector2(d.get("x", 0), d.get("y", 0)) + offset
		
		var je_to_capital = d.get("is_capital", false)
		var moc_blizko = false
		
		if not je_to_capital:
			for p in umistene_pozice:
				if pozice.distance_to(p) < MIN_VZDALENOST:
					moc_blizko = true
					break
				
		var lbl_inst = label_scene.instantiate()
		lbl_inst.set("province_id", d.id)
		lbl_inst.set("je_hlavni", not moc_blizko) 
		lbl_inst.set("is_capital", je_to_capital)
		label_container.add_child(lbl_inst)
		
		var l = lbl_inst.find_child("Label", true, false)
		var f = lbl_inst.find_child("Flag", true, false)
		
		if l:
			var zobrazeny_nazev = str(d.province_name).replace(" Voivodeship", "").replace(" County", "")
			
			if je_to_capital:
				var jmeno_mesta = d.get("capital_name", "")
				if jmeno_mesta != "":
					zobrazeny_nazev = jmeno_mesta
				
				if f:
					f.show()
					var tag = str(d.get("owner", ""))
					var ideologie = str(d.get("ideology", ""))
					f.texture = _get_flag_texture(tag, ideologie)
			else:
				if f:
					f.hide()
				
			l.text = zobrazeny_nazev
			lbl_inst.plny_nazev = zobrazeny_nazev
		
		lbl_inst.position = pozice
		if not moc_blizko:
			umistene_pozice.append(pozice)

func aktualizuj_vlajky_hlavnich_mest() -> void:
	var labels = get_node_or_null("ProvinceLabels")
	if labels == null:
		return

	for lbl in labels.get_children():
		var prov_id = int(lbl.get("province_id"))
		if not provinces.has(prov_id):
			continue
		var d = provinces[prov_id]
		var je_to_capital = bool(d.get("is_capital", false))
		var f = lbl.find_child("Flag", true, false)
		if f == null:
			continue

		if not je_to_capital:
			f.hide()
			continue

		var tag = str(d.get("owner", "")).strip_edges().to_upper()
		if tag == "" or tag == "SEA":
			f.hide()
			continue

		var ideologie = str(d.get("ideology", ""))
		f.texture = _get_flag_texture(tag, ideologie)
		f.show()

func get_province_data_by_color(clicked_color: Color):
	var hex = clicked_color.to_html(false)
	
	if color_cache.has(hex):
		return provinces[color_cache[hex]]
		
	var v_clicked = Vector3(clicked_color.r, clicked_color.g, clicked_color.b)
	
	for id in provinces:
		var c = provinces[id]["color"]
		var v_prov = Vector3(c.r, c.g, c.b)
		
		if v_prov.distance_to(v_clicked) < 0.02:
			color_cache[hex] = id
			return provinces[id]
			
	return null

func ziskej_hromadne_vybrane_provincie() -> Array:
	return hromadne_vybrane_provincie.duplicate()

func pridej_hromadny_vyber_provincie(prov_id: int) -> bool:
	if not je_platna_provincie_pro_hromadny_vyber(prov_id):
		return false
	if hromadne_vybrane_provincie.has(prov_id):
		return false
	hromadne_vybrane_provincie.append(prov_id)
	return true

# Clears temporary data and resets transient runtime/UI state.
func vycisti_hromadny_vyber_provincii():
	hromadne_vybrane_provincie.clear()
	vycisti_hromadny_vyber_overlay()

func vycisti_hromadny_vyber_overlay():
	_hromadny_vyber_overlay_key = ""
	var overlay = get_node_or_null("MultiSelectOverlay")
	if not overlay:
		return
	for child in overlay.get_children():
		child.queue_free()

# Executes module-specific gameplay/UI logic for the current context.
func vykresli_hromadny_vyber_overlay(ids: Array):
	if ids.is_empty():
		vycisti_hromadny_vyber_overlay()
		return

	var normalized: Array = []
	for raw_id in ids:
		var pid = int(raw_id)
		if provinces.has(pid):
			normalized.append(pid)
	if normalized.is_empty():
		vycisti_hromadny_vyber_overlay()
		return

	normalized.sort()
	var key = ""
	for pid in normalized:
		key += "%d|" % pid
	if key == _hromadny_vyber_overlay_key:
		return
	_hromadny_vyber_overlay_key = key

	var overlay = get_node_or_null("MultiSelectOverlay")
	if not overlay:
		overlay = Node2D.new()
		overlay.name = "MultiSelectOverlay"
		overlay.z_index = 27
		add_child(overlay)
	else:
		for child in overlay.get_children():
			child.queue_free()

	var offset = _ziskej_map_offset()
	for pid in normalized:
		var center = _ziskej_map_pozici_provincie(pid, offset)

		var glow = ColorRect.new()
		glow.size = Vector2(14, 14)
		glow.pivot_offset = Vector2(7, 7)
		glow.position = center - Vector2(7, 7)
		glow.color = Color(1.0, 0.95, 0.55, 0.34)
		overlay.add_child(glow)

		var ring = Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(1.0, 0.98, 0.70, 0.90)
		ring.antialiased = true
		var segments = 14
		var radius = 8.0
		for i in range(segments + 1):
			var a = (TAU * float(i)) / float(segments)
			ring.add_point(center + Vector2(cos(a), sin(a)) * radius)
		overlay.add_child(ring)

func prepni_hromadny_vyber_provincie(prov_id: int) -> bool:
	if not je_platna_provincie_pro_hromadny_vyber(prov_id):
		return false

	if hromadne_vybrane_provincie.has(prov_id):
		hromadne_vybrane_provincie.erase(prov_id)
		return false

	hromadne_vybrane_provincie.append(prov_id)
	return true

func je_platna_provincie_pro_hromadny_vyber(prov_id: int) -> bool:
	if not provinces.has(prov_id):
		return false

	var d = provinces[prov_id]
	var owner_tag = _ziskej_vlastnika_armady_v_provincii(prov_id)
	if owner_tag != GameManager.hrac_stat:
		return false
	return int(d.get("soldiers", 0)) > 0

func aktivuj_rezim_hromadneho_presunu(from_ids: Array) -> bool:
	hromadny_presun_zdroje.clear()
	for raw_id in from_ids:
		var prov_id = int(raw_id)
		if not provinces.has(prov_id):
			continue
		var owner_tag = _ziskej_vlastnika_armady_v_provincii(prov_id)
		if owner_tag != GameManager.hrac_stat:
			continue
		var soldiers = int(provinces[prov_id].get("soldiers", 0))
		if soldiers <= 0:
			continue
		if not hromadny_presun_zdroje.has(prov_id):
			hromadny_presun_zdroje.append(prov_id)

	if hromadny_presun_zdroje.is_empty():
		return false

	ceka_na_cil_presunu = false
	ceka_na_hromadny_cil_presunu = true
	vycisti_nahled_presunu()
	return true

func ma_hromadny_platny_cil_presunu(to_id: int) -> bool:
	if hromadny_presun_zdroje.is_empty():
		return false
	for from_id in hromadny_presun_zdroje:
		var fid = int(from_id)
		if fid == to_id:
			continue
		var path = najdi_nejrychlejsi_cestu_presunu(fid, to_id)
		if path.size() >= 2:
			return true
	return false

# Searches available data and returns the best matching result.
func najdi_hromadny_nahled_presunu_k_cili(to_id: int) -> Array:
	if hromadny_presun_zdroje.is_empty():
		return []

	var best_path: Array = []
	var best_len := 1 << 30
	for from_id in hromadny_presun_zdroje:
		var fid = int(from_id)
		if fid == to_id:
			continue
		var path = najdi_nejrychlejsi_cestu_presunu(fid, to_id)
		if path.size() < 2:
			continue
		if path.size() < best_len:
			best_len = path.size()
			best_path = path

	return best_path

func zaregistruj_hromadny_presun_armad(to_id: int) -> int:
	if hromadny_presun_zdroje.is_empty():
		ceka_na_hromadny_cil_presunu = false
		return 0

	var planned := 0
	for from_id in hromadny_presun_zdroje:
		var fid = int(from_id)
		if fid == to_id:
			continue
		if not provinces.has(fid):
			continue
		var amount = int(provinces[fid].get("soldiers", 0))
		if amount <= 0:
			continue
		var path = najdi_nejrychlejsi_cestu_presunu(fid, to_id)
		if path.size() < 2:
			continue
		zaregistruj_presun_armady(fid, to_id, amount, true, path)
		planned += 1

	ceka_na_hromadny_cil_presunu = false
	hromadny_presun_zdroje.clear()
	vycisti_nahled_presunu()
	return planned

func _na_zmenu_zoomu(aktualni_zoom):
	if _potato_mode_enabled:
		var low_labels = get_node_or_null("ProvinceLabels")
		if low_labels:
			low_labels.visible = false
		var low_labels_manager = get_node_or_null("CountryLabelsManager")
		if low_labels_manager:
			low_labels_manager.visible = false
		_aktualizuj_zoom_armad(aktualni_zoom)
		_aktualizuj_zoom_pristavu(aktualni_zoom)
		_aktualizuj_indikatory_kapitulace()
		return

	var labels = get_node_or_null("ProvinceLabels")
	if labels:
		var odzoomovano = aktualni_zoom <= 0.8
		for lbl in labels.get_children():
			if "is_zoomed_out" in lbl:
				lbl.is_zoomed_out = odzoomovano
				lbl.aktualni_zoom = aktualni_zoom
				lbl.reset_stav()
				
	var labels_manager = get_node_or_null("CountryLabelsManager")
	if labels_manager:
		var odzoomovano = aktualni_zoom <= 0.8
		labels_manager.visible = odzoomovano
		
		if odzoomovano:
			var zvetseni = clamp(1.0 / aktualni_zoom, 1.0, 4.0)
			for c_lbl in labels_manager.get_children():
				c_lbl.scale = Vector2(zvetseni, zvetseni)

	_aktualizuj_zoom_armad(aktualni_zoom)
	_aktualizuj_zoom_pristavu(aktualni_zoom)
	_aktualizuj_indikatory_kapitulace()

func _formatuj_cislo(cislo: int) -> String:
	if cislo >= 1000000:
		return str(snapped(cislo / 1000000.0, 0.1)) + "M"
	elif cislo >= 1000:
		return str(snapped(cislo / 1000.0, 0.1)) + "k"
	return str(cislo)

func _aktualizuj_zoom_armad(aktualni_zoom: float):
	if aktivni_armady.is_empty(): return
	if not _jsou_ukazatele_jednotek_povolene():
		for prov_id in aktivni_armady.keys():
			var hidden_node = aktivni_armady[prov_id]
			if hidden_node:
				hidden_node.hide()
		return
	
	var ZOOM_THRESHOLD_MERGE = 0.6 
	var zvetseni = clamp(1.0 / aktualni_zoom, 0.4, 2.5) 
	var is_merged_mode = aktualni_zoom <= ZOOM_THRESHOLD_MERGE

	if not is_merged_mode:
		for prov_id in aktivni_armady:
			var army_node = aktivni_armady[prov_id]
			army_node.show()
			army_node.scale = Vector2(zvetseni, zvetseni)
			
			var lbl = army_node.get_node_or_null("TroopCount")
			if lbl:
				lbl.text = _formatuj_cislo(int(provinces[prov_id].get("soldiers", 0)))
		_rozmisti_armady_bez_overlapu()
	else:
		var zkontrolovane = {}
		var clustery = []
		
		for prov_id in aktivni_armady.keys():
			if zkontrolovane.has(prov_id): continue
			if _je_more_provincie(prov_id):
				zkontrolovane[prov_id] = true
				clustery.append([prov_id])
				continue
			
			var cluster = []
			var fronta = [prov_id]
			var cluster_owner = _ziskej_vlastnika_armady_v_provincii(prov_id)
			
			while fronta.size() > 0:
				var curr_id = fronta.pop_front()
				if zkontrolovane.has(curr_id): continue
				
				zkontrolovane[curr_id] = true
				cluster.append(curr_id)
				
				var sousedi = provinces[curr_id].get("neighbors", [])
				for n_id in sousedi:
					if aktivni_armady.has(n_id) and not zkontrolovane.has(n_id):
						if _je_more_provincie(n_id):
							continue
						var n_owner = _ziskej_vlastnika_armady_v_provincii(n_id)
						if n_owner == cluster_owner:
							fronta.append(n_id)
							
			clustery.append(cluster)
			
		for cluster in clustery:
			var leader_id = cluster[0]
			var max_troops = -1
			var total_troops = 0
			
			for c_id in cluster:
				var troops = int(provinces[c_id].get("soldiers", 0))
				total_troops += troops
				if troops > max_troops:
					max_troops = troops
					leader_id = c_id
					
			for c_id in cluster:
				var army_node = aktivni_armady[c_id]
				if c_id == leader_id:
					army_node.show()
					var merge_bonus = 1.0 + (min(cluster.size(), 4) * 0.15) 
					army_node.scale = Vector2(zvetseni, zvetseni) * merge_bonus
					
					var lbl = army_node.get_node_or_null("TroopCount")
					if lbl:
						lbl.text = _formatuj_cislo(total_troops)
				else:
					army_node.hide()

func _aktualizuj_zoom_pristavu(aktualni_zoom: float):
	if aktivni_porty.is_empty():
		return

	var zvetseni = clamp(1.0 / aktualni_zoom, 0.70, 1.95)
	for prov_id in aktivni_porty.keys():
		var port_node = aktivni_porty[prov_id]
		if not port_node:
			continue
		port_node.scale = Vector2(zvetseni, zvetseni)

func aktualizuj_ikony_armad():
	var arm_signature = _spocitej_army_state_signature()
	if arm_signature == _last_army_state_signature:
		_aplikuj_viditelnost_ukazatelu_jednotek()
		if _port_icons_dirty:
			aktualizuj_ikony_pristavu()
		var selected_cached = -1
		var sprite_interaction_cached = $Sprite2D
		if sprite_interaction_cached and sprite_interaction_cached.material:
			selected_cached = int(sprite_interaction_cached.material.get_shader_parameter("selected_id"))
		nastav_vybranou_armadu_provincie(selected_cached)
		return

	_last_army_state_signature = arm_signature

	var container = get_node_or_null("ArmyContainer")
	if not container:
		container = Node2D.new()
		container.name = "ArmyContainer"
		container.z_index = 20
		add_child(container)
		
	var offset = _ziskej_map_offset()

	for prov_id in provinces.keys():
		var prov_data = provinces[prov_id]
		var vojaci = int(prov_data.get("soldiers", 0))
		var owner_tag = _ziskej_vlastnika_armady_v_provincii(prov_id)
		if owner_tag == "":
			owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
		
		if vojaci > 0:
			var base_pos = _ziskej_pozici_armady_v_provincii(prov_id, offset)
			var target_texture = _get_army_icon_texture(owner_tag)
			
			if not aktivni_armady.has(prov_id):
				var army_node = Node2D.new()
				army_node.position = base_pos
				army_node.set_meta("base_pos", base_pos)

				var ring = Line2D.new()
				ring.name = "SelectionRing"
				ring.width = 2.0
				ring.default_color = Color(1.0, 0.96, 0.62, 0.95)
				ring.antialiased = true
				ring.visible = false
				ring.z_index = -1
				
				var icon = Sprite2D.new()
				icon.name = "Icon"
				icon.texture = target_texture
				
				var tex_size = icon.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					icon.scale = Vector2(24.0 / tex_size.x, 24.0 / tex_size.y)
				
				var lbl = Label.new()
				lbl.name = "TroopCount"
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.position = Vector2(-50, 10) 
				lbl.custom_minimum_size = Vector2(100, 20)
				lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				lbl.add_theme_constant_override("outline_size", 4)
				lbl.add_theme_font_size_override("font_size", 14)
				lbl.text = _formatuj_cislo(vojaci)
				
				army_node.add_child(ring)
				army_node.add_child(icon)
				army_node.add_child(lbl)
				_aktualizuj_selection_ring_geometrii(army_node)
				container.add_child(army_node)
				
				aktivni_armady[prov_id] = army_node
			else:
				var army_node = aktivni_armady[prov_id]
				army_node.set_meta("base_pos", base_pos)
				army_node.position = base_pos
				var icon = army_node.get_node_or_null("Icon")
				if icon and icon.texture != target_texture:
					icon.texture = target_texture
				if icon and icon.texture:
					var tex_size = icon.texture.get_size()
					if tex_size.x > 0 and tex_size.y > 0:
						icon.scale = Vector2(24.0 / tex_size.x, 24.0 / tex_size.y)
				_aktualizuj_selection_ring_geometrii(army_node)
					
				var lbl = army_node.get_node_or_null("TroopCount")
				if lbl:
					lbl.text = _formatuj_cislo(vojaci)
		else:
			if aktivni_armady.has(prov_id):
				aktivni_armady[prov_id].queue_free()
				aktivni_armady.erase(prov_id)
				
	var kamera = $Camera2D
	if kamera:
		_aktualizuj_zoom_armad(kamera.zoom.x)
	_aplikuj_viditelnost_ukazatelu_jednotek()
	if _port_icons_dirty:
		aktualizuj_ikony_pristavu()
	aktualizuj_vlajky_hlavnich_mest()
	_aktualizuj_indikatory_kapitulace()

	var selected_prov_id = -1
	var sprite_interaction = $Sprite2D
	if sprite_interaction and sprite_interaction.material:
		selected_prov_id = int(sprite_interaction.material.get_shader_parameter("selected_id"))
	nastav_vybranou_armadu_provincie(selected_prov_id)

# --- CORE MOVEMENT LOGIC ---

func _je_more_provincie(prov_id: int) -> bool:
	if _sea_province_cache.has(prov_id):
		return bool(_sea_province_cache[prov_id])
	if not provinces.has(prov_id):
		return false
	var d = provinces[prov_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	var is_sea = (owner_tag == "SEA" or typ == "sea")
	_sea_province_cache[prov_id] = is_sea
	return is_sea

func _je_pobrezni_provincie(prov_id: int) -> bool:
	if _coastal_province_cache.has(prov_id):
		return bool(_coastal_province_cache[prov_id])
	var result = _spocitej_je_pobrezni_provincie(prov_id)
	_coastal_province_cache[prov_id] = result
	return result

func _spocitej_je_pobrezni_provincie(prov_id: int) -> bool:
	if not provinces.has(prov_id):
		return false
	if _je_more_provincie(prov_id):
		return false
	for n_id in provinces[prov_id].get("neighbors", []):
		if _je_more_provincie(int(n_id)):
			return true
	return false

func _ziskej_delku_pozemniho_kroku(from_id: int, to_id: int) -> float:
	var from_pos = _ziskej_lokalni_pozici_provincie(from_id)
	var to_pos = _ziskej_lokalni_pozici_provincie(to_id)
	if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
		return -1.0
	return from_pos.distance_to(to_pos)

func _spocitej_lokalni_land_cap(prov_id: int) -> float:
	if _land_step_distance_cap_cache.has(prov_id):
		return float(_land_step_distance_cap_cache[prov_id])
	if not provinces.has(prov_id) or _je_more_provincie(prov_id):
		return LAND_STEP_HARD_CAP_FALLBACK

	var dists: Array = []
	for n_id_any in provinces[prov_id].get("neighbors", []):
		var n_id = int(n_id_any)
		if not provinces.has(n_id) or _je_more_provincie(n_id):
			continue
		var step_dist = _ziskej_delku_pozemniho_kroku(prov_id, n_id)
		if step_dist > 0.0:
			dists.append(step_dist)

	if dists.is_empty():
		_land_step_distance_cap_cache[prov_id] = LAND_STEP_HARD_CAP_FALLBACK
		return LAND_STEP_HARD_CAP_FALLBACK

	dists.sort()
	var samples = mini(6, dists.size())
	var avg_short := 0.0
	for i in range(samples):
		avg_short += float(dists[i])
	avg_short /= float(samples)

	var cap_val = clamp(avg_short * LAND_STEP_HARD_CAP_FACTOR, LAND_STEP_HARD_CAP_MIN, LAND_STEP_HARD_CAP_MAX)
	_land_step_distance_cap_cache[prov_id] = cap_val
	return cap_val

func _splnuje_hard_cap_pozemniho_kroku(from_id: int, to_id: int) -> bool:
	var step_dist = _ziskej_delku_pozemniho_kroku(from_id, to_id)
	if step_dist < 0.0:
		# If position data is missing, do not block movement blindly.
		return true
	var from_cap = _spocitej_lokalni_land_cap(from_id)
	var to_cap = _spocitej_lokalni_land_cap(to_id)
	var allowed_cap = max(from_cap, to_cap)
	return step_dist <= allowed_cap

func _invalidate_movement_topology_cache() -> void:
	_sea_province_cache.clear()
	_coastal_province_cache.clear()
	_sea_step_neighbors_cache.clear()
	_land_step_neighbors_cache.clear()
	_land_plus_sea_step_neighbors_cache.clear()
	_land_step_distance_cap_cache.clear()
	_last_army_state_signature = -1

# Executes module-specific gameplay/UI logic for the current context.
func _rebuild_movement_topology_cache() -> void:
	_invalidate_movement_topology_cache()

	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		if not provinces.has(p_id):
			continue
		var p_data = provinces[p_id]
		var p_owner = str(p_data.get("owner", "")).strip_edges().to_upper()
		var p_type = str(p_data.get("type", "")).strip_edges().to_lower()
		var p_is_sea = (p_owner == "SEA" or p_type == "sea")
		_sea_province_cache[p_id] = p_is_sea

		var neighbors = provinces[p_id].get("neighbors", [])
		if p_is_sea:
			var sea_steps: Array = []
			for n_id_any in neighbors:
				var n_id = int(n_id_any)
				if not provinces.has(n_id):
					continue
				if _je_more_provincie(n_id) or _je_pobrezni_provincie(n_id):
					sea_steps.append(n_id)
			_sea_step_neighbors_cache[p_id] = sea_steps
			continue

		var land_steps: Array = []
		var land_plus_sea_steps: Array = []
		for n_id_any in neighbors:
			var n_id = int(n_id_any)
			if not provinces.has(n_id):
				continue
			if _je_more_provincie(n_id):
				land_plus_sea_steps.append(n_id)
			else:
				if not _splnuje_hard_cap_pozemniho_kroku(p_id, n_id):
					continue
				land_steps.append(n_id)
				land_plus_sea_steps.append(n_id)

		_land_step_neighbors_cache[p_id] = land_steps
		_land_plus_sea_step_neighbors_cache[p_id] = land_plus_sea_steps

func _invalidate_naval_reachability_cache() -> void:
	_naval_reachable_cache_from = -1
	_naval_reachable_cache.clear()

# Reads current runtime data and returns it to callers.
func _ziskej_dostupna_moreni_pole(from_id: int) -> Dictionary:
	if _naval_reachable_cache_from == from_id and not _naval_reachable_cache.is_empty():
		return _naval_reachable_cache

	var start_seas: Array = []
	if _je_more_provincie(from_id):
		start_seas.append(from_id)
	else:
		# Embark is possible only from a coastal province with a built port.
		if not _je_pobrezni_provincie(from_id) or not GameManager.provincie_ma_pristav(from_id):
			_naval_reachable_cache_from = from_id
			_naval_reachable_cache = {}
			return _naval_reachable_cache
		for n_id in provinces[from_id].get("neighbors", []):
			var nid = int(n_id)
			if _je_more_provincie(nid):
				start_seas.append(nid)

	var reachable: Dictionary = {}
	var q: Array = []
	for sid in start_seas:
		var sea_id = int(sid)
		if not reachable.has(sea_id):
			reachable[sea_id] = true
			q.append(sea_id)

	var head := 0
	while head < q.size():
		var curr = int(q[head])
		head += 1
		if not provinces.has(curr):
			continue
		for n_id in provinces[curr].get("neighbors", []):
			var nid = int(n_id)
			if not _je_more_provincie(nid):
				continue
			if reachable.has(nid):
				continue
			reachable[nid] = true
			q.append(nid)

	_naval_reachable_cache_from = from_id
	_naval_reachable_cache = reachable
	return _naval_reachable_cache

# Returns whether required conditions are currently satisfied.
func _ma_pobrezni_pristup_k_dostupnemu_mori(land_id: int, reachable_sea: Dictionary) -> bool:
	if not provinces.has(land_id):
		return false
	if _je_more_provincie(land_id):
		return false
	for n_id in provinces[land_id].get("neighbors", []):
		var nid = int(n_id)
		if _je_more_provincie(nid) and reachable_sea.has(nid):
			return true
	return false

func _ziskej_vlastnika_armady_v_provincii(prov_id: int) -> String:
	if not provinces.has(prov_id):
		return ""
	var army_owner = str(provinces[prov_id].get("army_owner", "")).strip_edges().to_upper()
	if army_owner != "":
		return army_owner
	if _je_more_provincie(prov_id):
		return ""
	return str(provinces[prov_id].get("owner", "")).strip_edges().to_upper()

func _ziskej_braniciho_vlastnika_v_provincii(prov_id: int) -> String:
	if not provinces.has(prov_id):
		return ""
	var p = provinces[prov_id]
	if _je_more_provincie(prov_id):
		return str(p.get("army_owner", "")).strip_edges().to_upper()
	var owner_tag = str(p.get("owner", "")).strip_edges().to_upper()
	var army_owner = str(p.get("army_owner", "")).strip_edges().to_upper()
	var soldiers = int(p.get("soldiers", 0))
	if soldiers > 0 and army_owner != "":
		return army_owner
	return owner_tag

# Executes module-specific gameplay/UI logic for the current context.
func _zvol_vlastnika_pri_pratelskem_slouceni(existing_owner_tag: String, incoming_owner_tag: String) -> String:
	var existing_owner = str(existing_owner_tag).strip_edges().to_upper()
	var incoming_owner = str(incoming_owner_tag).strip_edges().to_upper()
	if existing_owner == "":
		return incoming_owner
	if incoming_owner == "" or incoming_owner == existing_owner:
		return existing_owner

	# Preserve direct player control when their stack enters allied/vassal land.
	if incoming_owner == str(GameManager.hrac_stat).strip_edges().to_upper():
		return incoming_owner
	if existing_owner == str(GameManager.hrac_stat).strip_edges().to_upper():
		return existing_owner

	if GameManager.has_method("ziskej_overlorda_statu"):
		var existing_overlord = str(GameManager.ziskej_overlorda_statu(existing_owner)).strip_edges().to_upper()
		var incoming_overlord = str(GameManager.ziskej_overlorda_statu(incoming_owner)).strip_edges().to_upper()
		if existing_overlord == incoming_owner:
			return incoming_owner
		if incoming_overlord == existing_owner:
			return existing_owner

	# Keep current controller for allied merges to avoid last-move ownership flips.
	return existing_owner

# Reads current runtime data and returns it to callers.
func _ziskej_pozici_pristavu_v_provincii(prov_id: int) -> Vector2:
	var center = _ziskej_lokalni_pozici_provincie(prov_id)
	if not provinces.has(prov_id):
		return center

	var sea_neighbors: Array = []
	for n_id in provinces[prov_id].get("neighbors", []):
		var nid = int(n_id)
		if _je_more_provincie(nid):
			sea_neighbors.append(nid)

	if sea_neighbors.is_empty():
		return center + Vector2(18, 0)

	# Push the icon towards neighboring sea provinces so it visually sits on the coast.
	var sea_focus = Vector2.ZERO
	var valid_points := 0
	for sea_id in sea_neighbors:
		var sea_pos = _ziskej_lokalni_pozici_provincie(int(sea_id))
		if sea_pos == Vector2.ZERO:
			continue
		sea_focus += sea_pos
		valid_points += 1

	if valid_points <= 0:
		return center + Vector2(16, 0)

	sea_focus /= float(valid_points)
	var dir = sea_focus - center
	if dir.length() <= 0.001:
		return center + Vector2(16, 0)

	return center + dir.normalized() * 16.0

# Returns whether required conditions are currently satisfied.
func _ma_nepratelskou_posadku_na_mori(prov_id: int, owner_tag: String) -> bool:
	if not _je_more_provincie(prov_id):
		return false
	var sea_army_owner = str(provinces[prov_id].get("army_owner", "")).strip_edges().to_upper()
	return sea_army_owner != "" and sea_army_owner != owner_tag

func _je_pruchozi_mezikrok_presunu(prov_id: int, owner_tag: String) -> bool:
	if not provinces.has(prov_id):
		return false
	if _je_more_provincie(prov_id):
		if not _ma_nepratelskou_posadku_na_mori(prov_id, owner_tag):
			return true
		var sea_owner = str(provinces[prov_id].get("army_owner", "")).strip_edges().to_upper()
		if sea_owner == "" or sea_owner == owner_tag:
			return true
		return bool(GameManager.has_method("jsou_ve_valce") and GameManager.jsou_ve_valce(owner_tag, sea_owner))
	var land_owner = str(provinces[prov_id].get("owner", "")).strip_edges().to_upper()
	if land_owner == "":
		return false
	if GameManager.has_method("muze_vstoupit_na_uzemi"):
		if bool(GameManager.muze_vstoupit_na_uzemi(owner_tag, land_owner)):
			return true
	if GameManager.has_method("jsou_ve_valce") and GameManager.jsou_ve_valce(owner_tag, land_owner):
		return true
	return land_owner == owner_tag

# Reads current runtime data and returns it to callers.
func _ziskej_krokove_sousedy_presunu(from_id: int) -> Array:
	if not provinces.has(from_id):
		return []

	var from_is_sea = _je_more_provincie(from_id)
	if from_is_sea:
		return _sea_step_neighbors_cache.get(from_id, [])

	var can_embark = _je_pobrezni_provincie(from_id) and GameManager.provincie_ma_pristav(from_id)
	if can_embark:
		return _land_plus_sea_step_neighbors_cache.get(from_id, [])
	return _land_step_neighbors_cache.get(from_id, [])

func _spocitej_army_state_signature() -> int:
	var signature := 216613626
	for p_id_any in provinces:
		var p_id = int(p_id_any)
		var d = provinces[p_id]
		var soldiers = int(d.get("soldiers", 0))
		if soldiers <= 0:
			continue
		var owner_tag = str(d.get("army_owner", "")).strip_edges().to_upper()
		if owner_tag == "":
			owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		signature = int(((signature * 16777619) ^ (p_id * 1315423911) ^ soldiers ^ owner_tag.hash()) & 0x7fffffff)
	if _port_icons_dirty:
		signature = int((signature ^ 0x1A2B3C4D) & 0x7fffffff)
	return signature

func najdi_nejrychlejsi_cestu_presunu(from_id: int, to_id: int) -> Array:
	if from_id == to_id:
		return []
	if not provinces.has(from_id) or not provinces.has(to_id):
		return []

	var owner_tag = _ziskej_vlastnika_armady_v_provincii(from_id)
	if owner_tag == "":
		return []

	var queue: Array = [from_id]
	var visited: Dictionary = {from_id: true}
	var prev: Dictionary = {}
	var head := 0

	while head < queue.size():
		var curr = int(queue[head])
		head += 1

		for next_id in _ziskej_krokove_sousedy_presunu(curr):
			var nid = int(next_id)
			if visited.has(nid):
				continue

			var je_cil = (nid == to_id)
			if not je_cil and not _je_pruchozi_mezikrok_presunu(nid, owner_tag):
				continue

			visited[nid] = true
			prev[nid] = curr

			if je_cil:
				var path: Array = [to_id]
				var step = to_id
				while prev.has(step):
					step = int(prev[step])
					path.push_front(step)
				if path.size() >= 2 and int(path[0]) == from_id:
					return path
				return []

			queue.append(nid)

	return []

# Clears temporary data and resets transient runtime/UI state.
func vycisti_nahled_presunu():
	_preview_path_key = ""
	_preview_anim_markery.clear()
	if _ai_anim_markery.is_empty() and _cekajici_anim_markery.is_empty():
		set_process(false)
	var overlay = get_node_or_null("MovePathPreviewOverlay")
	if not overlay:
		return
	for child in overlay.get_children():
		child.queue_free()

# Displays UI/output and updates visible presentation data.
func zobraz_nahled_presunu(path: Array):
	if path.size() < 2:
		vycisti_nahled_presunu()
		return

	var key = ""
	for pid in path:
		key += "%d>" % int(pid)
	if key == _preview_path_key:
		return
	_preview_path_key = key

	var overlay = get_node_or_null("MovePathPreviewOverlay")
	if not overlay:
		overlay = Node2D.new()
		overlay.name = "MovePathPreviewOverlay"
		overlay.z_index = 26
		add_child(overlay)
	else:
		for child in overlay.get_children():
			child.queue_free()
		_preview_anim_markery.clear()

	var offset = _ziskej_map_offset()
	var poly_points = PackedVector2Array()
	for pid in path:
		var prov_id = int(pid)
		if not provinces.has(prov_id):
			continue
		poly_points.append(_ziskej_map_pozici_provincie(prov_id, offset))

	if poly_points.size() < 2:
		vycisti_nahled_presunu()
		return

	var from_id = int(path[0])
	var to_id = int(path[path.size() - 1])
	var owner_tag = _ziskej_vlastnika_armady_v_provincii(from_id)
	var target_owner_tag = ""
	if provinces.has(to_id):
		target_owner_tag = _ziskej_braniciho_vlastnika_v_provincii(to_id)
	var is_attack_preview = (target_owner_tag != "" and owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA")
	var col = _ziskej_barvu_overlay_statu(owner_tag, is_attack_preview)
	var width = 2.2

	var line = Line2D.new()
	line.width = max(1.8, width - 0.2)
	line.default_color = Color(col.r, col.g, col.b, 0.34)
	line.antialiased = false
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

	for p in poly_points:
		line.add_point(p)
	overlay.add_child(line)

	_pridej_animovany_marker_po_linii(overlay, _preview_anim_markery, poly_points, col, AI_MARKER_MOVE_SPEED, 0.08, width)

	var start_dot = ColorRect.new()
	start_dot.size = Vector2(6, 6)
	start_dot.pivot_offset = Vector2(3, 3)
	start_dot.color = Color(1.0, 1.0, 1.0, 0.95)
	start_dot.position = poly_points[0] - Vector2(3, 3)
	overlay.add_child(start_dot)

	if not _preview_anim_markery.is_empty():
		set_process(true)

func _ziskej_profil_statu(owner_tag: String) -> Dictionary:
	for p_id in provinces.keys():
		if _je_more_provincie(p_id):
			continue
		var d = provinces[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == owner_tag and str(d.get("core_owner", "")).strip_edges().to_upper() == owner_tag:
			return {
				"country_name": str(d.get("country_name", owner_tag)),
				"ideology": str(d.get("ideology", ""))
			}

	for p_id in provinces.keys():
		if _je_more_provincie(p_id):
			continue
		var d = provinces[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == owner_tag:
			return {
				"country_name": str(d.get("country_name", owner_tag)),
				"ideology": str(d.get("ideology", ""))
			}
	return {
		"country_name": owner_tag,
		"ideology": ""
	}

func je_platny_cil_presunu(from_id: int, to_id: int) -> bool:
	return najdi_nejrychlejsi_cestu_presunu(from_id, to_id).size() >= 2

func aktualizuj_ikony_pristavu():
	var container = get_node_or_null("PortContainer")
	if not container:
		container = Node2D.new()
		container.name = "PortContainer"
		container.z_index = 19
		add_child(container)

	var offset = _ziskej_map_offset()
	for prov_id in provinces.keys():
		var d = provinces[prov_id]
		var has_port = bool(d.get("has_port", false))
		if has_port and not _je_more_provincie(prov_id):
			var base_pos = _ziskej_pozici_pristavu_v_provincii(prov_id) + offset
			if not aktivni_porty.has(prov_id):
				var port_node = Node2D.new()
				port_node.position = base_pos

				var marker = Sprite2D.new()
				marker.name = "PortMarker"
				marker.texture = _get_port_icon_texture()
				marker.centered = true
				if marker.texture:
					var tex_size = marker.texture.get_size()
					if tex_size.x > 0.0 and tex_size.y > 0.0:
						marker.scale = Vector2(22.0 / tex_size.x, 22.0 / tex_size.y)
				port_node.add_child(marker)
				container.add_child(port_node)
				aktivni_porty[prov_id] = port_node
			else:
				aktivni_porty[prov_id].position = base_pos
		else:
			if aktivni_porty.has(prov_id):
				aktivni_porty[prov_id].queue_free()
				aktivni_porty.erase(prov_id)

	_port_icons_dirty = false

	var kamera = $Camera2D
	if kamera:
		_aktualizuj_zoom_pristavu(kamera.zoom.x)

# Executes module-specific gameplay/UI logic for the current context.
func oznac_pristavy_k_aktualizaci():
	_port_icons_dirty = true

# Activates target selection mode
# Executes module-specific gameplay/UI logic for the current context.
func aktivuj_rezim_vyberu_cile(from_id: int, max_troops: int):
	vybrana_armada_od = from_id
	vybrana_armada_max = max_troops
	ceka_na_cil_presunu = true
	_invalidate_naval_reachability_cache()
	vycisti_nahled_presunu()
	print("Click on the map to select a move target.")

func _ziskej_provincie_statu_v_mape(state_tag: String) -> Array:
	var out: Array = []
	var wanted = state_tag.strip_edges().to_upper()
	if wanted == "" or wanted == "SEA":
		return out
	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		if not provinces.has(p_id):
			continue
		var d = provinces[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		if _je_more_provincie(p_id):
			continue
		out.append(p_id)
	return out

# Reads current runtime data and returns it to callers.
func _ziskej_dostupne_cile_miru(vitez: String, porazeny: String) -> Array:
	var win = vitez.strip_edges().to_upper()
	var lose = porazeny.strip_edges().to_upper()
	var out: Array = []
	if win == "" or lose == "" or win == lose:
		return out

	for p_id_any in provinces.keys():
		var p_id = int(p_id_any)
		if not provinces.has(p_id):
			continue
		if _je_more_provincie(p_id):
			continue
		var d = provinces[p_id]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
		var je_primy_loser = owner_tag == lose
		var je_okupovana_vitezem = owner_tag == win and core_owner == lose
		if not je_primy_loser and not je_okupovana_vitezem:
			continue
		out.append(p_id)

	return out

func zrus_rezim_vyberu_miru() -> void:
	ceka_na_cil_miru = false
	stat_mirove_konference_vitez = ""
	stat_mirove_konference_porazeny = ""
	dostupne_cile_miru.clear()
	vybrane_cile_miru.clear()
	var sprite = $Sprite2D
	if sprite and sprite.has_method("vycisti_nahled_hlavniho_mesta"):
		sprite.vycisti_nahled_hlavniho_mesta()
	if sprite and sprite.has_method("vycisti_nahled_mirovych_cilu"):
		sprite.vycisti_nahled_mirovych_cilu()
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture([])

func aktivuj_rezim_vyberu_miru(vitez_tag: String, porazeny_tag: String, preselected_ids: Array = []) -> Dictionary:
	var vitez = vitez_tag.strip_edges().to_upper()
	var porazeny = porazeny_tag.strip_edges().to_upper()
	zrus_rezim_vyberu_miru()

	if vitez == "" or porazeny == "" or vitez == porazeny:
		return {"ok": false, "reason": "Invalid peace conference participants."}

	var targets = _ziskej_dostupne_cile_miru(vitez, porazeny)
	if targets.is_empty():
		return {"ok": false, "reason": "Defeated state has no provinces available for selection."}

	ceka_na_cil_miru = true
	stat_mirove_konference_vitez = vitez
	stat_mirove_konference_porazeny = porazeny
	dostupne_cile_miru = targets.duplicate()

	for raw_id in preselected_ids:
		var pid = int(raw_id)
		if dostupne_cile_miru.has(pid) and not vybrane_cile_miru.has(pid):
			vybrane_cile_miru.append(pid)

	var participants: Array = _ziskej_provincie_statu_v_mape(vitez)
	for pid_any in _ziskej_provincie_statu_v_mape(porazeny):
		var pid = int(pid_any)
		if not participants.has(pid):
			participants.append(pid)

	var sprite = $Sprite2D
	if sprite and sprite.has_method("nastav_nahled_hlavniho_mesta"):
		sprite.nastav_nahled_hlavniho_mesta(participants, dostupne_cile_miru)
	if sprite and sprite.has_method("vycisti_nahled_mirovych_cilu"):
		sprite.vycisti_nahled_mirovych_cilu()
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture(vybrane_cile_miru)

	return {
		"ok": true,
		"count": dostupne_cile_miru.size(),
		"selected": vybrane_cile_miru.duplicate()
	}

# Returns whether required conditions are currently satisfied.
func je_platna_provincie_pro_mir(prov_id: int) -> bool:
	if not ceka_na_cil_miru:
		return false
	return dostupne_cile_miru.has(int(prov_id))

# Returns whether required conditions are currently satisfied.
func je_provincie_vybrana_v_miru(prov_id: int) -> bool:
	return vybrane_cile_miru.has(int(prov_id))

func prepni_vyber_mirove_provincie(prov_id: int) -> Dictionary:
	var pid = int(prov_id)
	if not je_platna_provincie_pro_mir(pid):
		return {"ok": false, "reason": "This province cannot be selected in peace terms."}
	if vybrane_cile_miru.has(pid):
		vybrane_cile_miru.erase(pid)
	else:
		vybrane_cile_miru.append(pid)

	var sprite = $Sprite2D
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture(vybrane_cile_miru)

	return {
		"ok": true,
		"province_id": pid,
		"selected": vybrane_cile_miru.duplicate(),
		"selected_count": vybrane_cile_miru.size()
	}

func ziskej_vybrane_mirove_provincie() -> Array:
	return vybrane_cile_miru.duplicate()

# Cancels the active flow and restores a safe default state.
func zrus_rezim_vyberu_trade_provincie() -> void:
	ceka_na_cil_trade_provincie = false
	stat_trade_province_source = ""
	dostupne_cile_trade_provincie.clear()
	vybrane_cile_trade_provincie.clear()
	var sprite = $Sprite2D
	if sprite and sprite.has_method("vycisti_nahled_hlavniho_mesta"):
		sprite.vycisti_nahled_hlavniho_mesta()
	if sprite and sprite.has_method("vycisti_nahled_mirovych_cilu"):
		sprite.vycisti_nahled_mirovych_cilu()
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture([])

# Executes module-specific gameplay/UI logic for the current context.
func aktivuj_rezim_vyberu_trade_provincie(source_tag: String, preselected_ids: Array = []) -> Dictionary:
	var source = source_tag.strip_edges().to_upper()
	zrus_rezim_vyberu_trade_provincie()
	if source == "" or source == "SEA":
		return {"ok": false, "reason": "Invalid source country for trade province transfer."}

	var valid_ids: Array = []
	for pid_any in _ziskej_provincie_statu_v_mape(source):
		var pid = int(pid_any)
		if not provinces.has(pid):
			continue
		var d = provinces[pid]
		if _je_more_provincie(pid):
			continue
		if bool(d.get("is_capital", false)):
			continue
		valid_ids.append(pid)

	if valid_ids.is_empty():
		return {"ok": false, "reason": "No tradable provinces available (capital is excluded)."}

	ceka_na_cil_trade_provincie = true
	stat_trade_province_source = source
	dostupne_cile_trade_provincie = valid_ids.duplicate()
	vybrane_cile_trade_provincie.clear()
	for raw_id in preselected_ids:
		var pid_pre = int(raw_id)
		if not dostupne_cile_trade_provincie.has(pid_pre):
			continue
		if not vybrane_cile_trade_provincie.has(pid_pre):
			vybrane_cile_trade_provincie.append(pid_pre)

	var sprite = $Sprite2D
	if sprite and sprite.has_method("nastav_nahled_hlavniho_mesta"):
		sprite.nastav_nahled_hlavniho_mesta(_ziskej_provincie_statu_v_mape(source), dostupne_cile_trade_provincie)
	if sprite and sprite.has_method("vycisti_nahled_mirovych_cilu"):
		sprite.vycisti_nahled_mirovych_cilu()
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture(vybrane_cile_trade_provincie)

	return {
		"ok": true,
		"count": dostupne_cile_trade_provincie.size(),
		"selected": vybrane_cile_trade_provincie.duplicate(),
		"selected_count": vybrane_cile_trade_provincie.size(),
		"source": stat_trade_province_source
	}

# Returns whether required conditions are currently satisfied.
func je_platna_provincie_pro_trade(prov_id: int) -> bool:
	if not ceka_na_cil_trade_provincie:
		return false
	return dostupne_cile_trade_provincie.has(int(prov_id))

# Switches mode/state and updates related behavior and visuals.
func prepni_vyber_trade_provincie(prov_id: int) -> Dictionary:
	var pid = int(prov_id)
	if not je_platna_provincie_pro_trade(pid):
		return {"ok": false, "reason": "This province cannot be selected for trade transfer."}
	if vybrane_cile_trade_provincie.has(pid):
		vybrane_cile_trade_provincie.erase(pid)
	else:
		vybrane_cile_trade_provincie.append(pid)

	var sprite = $Sprite2D
	if sprite and sprite.has_method("_aktualizuj_hromadny_selection_texture"):
		sprite._aktualizuj_hromadny_selection_texture(vybrane_cile_trade_provincie)

	return {
		"ok": true,
		"province_id": pid,
		"selected": vybrane_cile_trade_provincie.duplicate(),
		"selected_count": vybrane_cile_trade_provincie.size(),
		"source": stat_trade_province_source
	}

func ziskej_vybrane_trade_provincie() -> Array:
	return vybrane_cile_trade_provincie.duplicate()

func potvrd_vyber_trade_provincii() -> Dictionary:
	if not ceka_na_cil_trade_provincie:
		return {"ok": false, "reason": "Trade province selection mode is not active."}
	if vybrane_cile_trade_provincie.is_empty():
		return {"ok": false, "reason": "Select at least one province."}

	var selected_ids = vybrane_cile_trade_provincie.duplicate()
	selected_ids.sort()
	var selected_names: Array = []
	for pid_any in selected_ids:
		var pid = int(pid_any)
		var name = "Province %d" % pid
		if provinces.has(pid):
			name = str((provinces[pid] as Dictionary).get("province_name", name))
		selected_names.append(name)
	var source = stat_trade_province_source

	zrus_rezim_vyberu_trade_provincie()
	return {
		"ok": true,
		"selected": selected_ids,
		"selected_names": selected_names,
		"selected_count": selected_ids.size(),
		"source": source
	}

func _ziskej_dostupne_cile_hlavniho_mesta(state_tag: String) -> Array:
	var state = state_tag.strip_edges().to_upper()
	if state == "" or state == "SEA":
		return []

	var out: Array = []
	if not GameManager.has_method("muze_presunout_hlavni_mesto"):
		return out

	for p_id in provinces.keys():
		var pid = int(p_id)
		var d = provinces[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var core_owner = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
		if owner_tag != state:
			continue
		if core_owner != state:
			continue
		if _je_more_provincie(pid):
			continue

		var check = GameManager.muze_presunout_hlavni_mesto(state, pid)
		if bool(check.get("ok", false)):
			out.append(pid)

	return out

# Cancels the active flow and restores a safe default state.
func zrus_rezim_vyberu_hlavniho_mesta() -> void:
	ceka_na_cil_hlavniho_mesta = false
	dostupne_cile_hlavniho_mesta.clear()
	stat_presunu_hlavniho_mesta = ""
	var sprite = $Sprite2D
	if sprite and sprite.has_method("vycisti_nahled_hlavniho_mesta"):
		sprite.vycisti_nahled_hlavniho_mesta()

# Executes module-specific gameplay/UI logic for the current context.
func aktivuj_rezim_vyberu_hlavniho_mesta(state_tag: String) -> Dictionary:
	var state = state_tag.strip_edges().to_upper()
	zrus_rezim_vyberu_hlavniho_mesta()

	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not GameManager.has_method("muze_presunout_hlavni_mesto"):
		return {"ok": false, "reason": "Capital relocation is not available."}

	var targets = _ziskej_dostupne_cile_hlavniho_mesta(state)
	if targets.is_empty():
		return {"ok": false, "reason": "No available province for capital relocation."}

	ceka_na_cil_hlavniho_mesta = true
	stat_presunu_hlavniho_mesta = state
	dostupne_cile_hlavniho_mesta = targets.duplicate()

	var owned_ids: Array = []
	for p_id in provinces.keys():
		var pid = int(p_id)
		var d = provinces[pid]
		if _je_more_provincie(pid):
			continue
		if str(d.get("owner", "")).strip_edges().to_upper() == state:
			owned_ids.append(pid)

	var sprite = $Sprite2D
	if sprite and sprite.has_method("nastav_nahled_hlavniho_mesta"):
		sprite.nastav_nahled_hlavniho_mesta(owned_ids, targets)

	print("Click on the map to choose a new capital. The cost is shown dynamically when hovering a target.")
	return {"ok": true, "count": targets.size()}

# Returns whether required conditions are currently satisfied.
func je_platny_cil_hlavniho_mesta(prov_id: int) -> bool:
	if not ceka_na_cil_hlavniho_mesta:
		return false
	return dostupne_cile_hlavniho_mesta.has(int(prov_id))

# Validates and confirms an action, then commits the result.
func potvrd_cil_hlavniho_mesta(prov_id: int) -> Dictionary:
	var pid = int(prov_id)
	if not je_platny_cil_hlavniho_mesta(pid):
		return {"ok": false, "reason": "Invalid target for capital relocation."}
	if not GameManager.has_method("presun_hlavni_mesto"):
		zrus_rezim_vyberu_hlavniho_mesta()
		return {"ok": false, "reason": "Capital relocation is not available."}

	var result = GameManager.presun_hlavni_mesto(stat_presunu_hlavniho_mesta, pid, true, true)
	zrus_rezim_vyberu_hlavniho_mesta()
	return result

# Executes module-specific gameplay/UI logic for the current context.
func zacni_davkovy_presun():
	_pozastavit_aktualizaci_ikon = true
	_minimalni_ai_tahy.clear()

# Executes module-specific gameplay/UI logic for the current context.
func ukonci_davkovy_presun():
	_pozastavit_aktualizaci_ikon = false
	_vykresli_minimalni_ai_presuny()
	aktualizuj_ikony_armad()

# Executes module-specific gameplay/UI logic for the current context.
func _vymaz_minimalni_ai_presuny():
	_ai_anim_markery.clear()
	if _cekajici_anim_markery.is_empty():
		set_process(false)
	var container = get_node_or_null("AIMoveOverlay")
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

# Executes module-specific gameplay/UI logic for the current context.
func _vymaz_indikaci_cekajicich_presunu():
	_cekajici_anim_markery.clear()
	if _ai_anim_markery.is_empty():
		set_process(false)
	var container = get_node_or_null("QueuedMoveOverlay")
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

# Executes module-specific gameplay/UI logic for the current context.
func _zaregistruj_minimalni_ai_tah_s_mnozstvim(from_id: int, to_id: int, owner_tag: String, is_attack: bool, amount: int):
	var key = "%d_%d_%s_%d" % [from_id, to_id, owner_tag, 1 if is_attack else 0]
	if not _minimalni_ai_tahy.has(key):
		_minimalni_ai_tahy[key] = {
			"from": from_id,
			"to": to_id,
			"owner": owner_tag,
			"is_attack": is_attack,
			"count": 0,
			"total_amount": 0
		}
	_minimalni_ai_tahy[key]["count"] = int(_minimalni_ai_tahy[key].get("count", 0)) + 1
	_minimalni_ai_tahy[key]["total_amount"] = int(_minimalni_ai_tahy[key].get("total_amount", 0)) + max(0, amount)

# Displays UI/output and updates visible presentation data.
func _zobraz_minimalni_presun(from_id: int, to_id: int, owner_tag: String, is_attack: bool, total_amount: int, count: int = 1):
	if not provinces.has(from_id) or not provinces.has(to_id):
		return

	var container = get_node_or_null("AIMoveOverlay")
	if not container:
		container = Node2D.new()
		container.name = "AIMoveOverlay"
		container.z_index = 24
		add_child(container)

	var offset = _ziskej_map_offset()
	var start_pos = _ziskej_map_pozici_provincie(from_id, offset)
	var end_pos = _ziskej_map_pozici_provincie(to_id, offset)
	var dir = end_pos - start_pos
	if dir.length() < 0.001:
		return

	var col = _ziskej_barvu_overlay_statu(owner_tag, is_attack)
	var width = (2.9 if is_attack else 2.2) + min(1.8, float(max(1, count) - 1) * 0.20)
	var speed = AI_MARKER_ATTACK_SPEED if is_attack else AI_MARKER_MOVE_SPEED
	var marker_count = 2 if is_attack else 1
	if count >= 3:
		marker_count += 1
	marker_count = min(marker_count, 3)

	var trail = Line2D.new()
	trail.width = max(1.8, width - 0.2)
	trail.default_color = Color(col.r, col.g, col.b, 0.38 if is_attack else 0.30)
	trail.antialiased = false
	trail.add_point(start_pos)
	trail.add_point(end_pos)
	container.add_child(trail)

	for m in range(marker_count):
		var phase = (float(m) / float(marker_count)) + 0.12
		_pridej_animovany_marker(container, _ai_anim_markery, start_pos, end_pos, col, speed, phase, width)

	if is_attack and count > 1:
		var cnt = Label.new()
		cnt.text = "x%d" % count
		var cnt_pos = start_pos.lerp(end_pos, 0.55) + Vector2(3, -10)
		cnt.position = Vector2(round(cnt_pos.x), round(cnt_pos.y))
		cnt.add_theme_font_size_override("font_size", 11)
		cnt.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.98))
		cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		cnt.add_theme_constant_override("outline_size", 3)
		container.add_child(cnt)

	if total_amount > 0:
		var amount_lbl = Label.new()
		amount_lbl.text = _formatuj_cislo(total_amount)
		var amount_pos = start_pos.lerp(end_pos, 0.45) + Vector2(5, 6)
		amount_lbl.position = Vector2(round(amount_pos.x), round(amount_pos.y))
		amount_lbl.add_theme_font_size_override("font_size", 12)
		amount_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.98))
		amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		amount_lbl.add_theme_constant_override("outline_size", 3)
		container.add_child(amount_lbl)

	if not _ai_anim_markery.is_empty():
		set_process(true)

func _zobraz_minimalni_presun_po_ceste(path: Array, owner_tag: String, is_attack: bool, total_amount: int, count: int = 1):
	if path.size() < 2:
		return

	var container = get_node_or_null("AIMoveOverlay")
	if not container:
		container = Node2D.new()
		container.name = "AIMoveOverlay"
		container.z_index = 24
		add_child(container)

	var offset = _ziskej_map_offset()
	var poly_points = PackedVector2Array()
	for pid in path:
		var prov_id = int(pid)
		if not provinces.has(prov_id):
			continue
		poly_points.append(_ziskej_map_pozici_provincie(prov_id, offset))

	if poly_points.size() < 2:
		return

	var start_pos = poly_points[0]
	var end_pos = poly_points[poly_points.size() - 1]
	var col = _ziskej_barvu_overlay_statu(owner_tag, is_attack)
	var width = (2.9 if is_attack else 2.2) + min(1.8, float(max(1, count) - 1) * 0.20)
	var speed = AI_MARKER_ATTACK_SPEED if is_attack else AI_MARKER_MOVE_SPEED
	var marker_count = 2 if is_attack else 1
	if count >= 3:
		marker_count += 1
	marker_count = min(marker_count, 3)

	var trail = Line2D.new()
	trail.width = max(1.8, width - 0.2)
	trail.default_color = Color(col.r, col.g, col.b, 0.38 if is_attack else 0.30)
	trail.antialiased = false
	for p in poly_points:
		trail.add_point(p)
	container.add_child(trail)

	for m in range(marker_count):
		var phase = (float(m) / float(marker_count)) + 0.12
		_pridej_animovany_marker_po_linii(container, _ai_anim_markery, poly_points, col, speed, phase, width)

	if is_attack and count > 1:
		var cnt = Label.new()
		cnt.text = "x%d" % count
		var cnt_pos = start_pos.lerp(end_pos, 0.55) + Vector2(3, -10)
		cnt.position = Vector2(round(cnt_pos.x), round(cnt_pos.y))
		cnt.add_theme_font_size_override("font_size", 11)
		cnt.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.98))
		cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		cnt.add_theme_constant_override("outline_size", 3)
		container.add_child(cnt)

	if total_amount > 0:
		var amount_lbl = Label.new()
		amount_lbl.text = _formatuj_cislo(total_amount)
		var amount_pos = start_pos.lerp(end_pos, 0.45) + Vector2(5, 6)
		amount_lbl.position = Vector2(round(amount_pos.x), round(amount_pos.y))
		amount_lbl.add_theme_font_size_override("font_size", 12)
		amount_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.98))
		amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		amount_lbl.add_theme_constant_override("outline_size", 3)
		container.add_child(amount_lbl)

	if not _ai_anim_markery.is_empty():
		set_process(true)

func _vykresli_minimalni_ai_presuny():
	_vymaz_minimalni_ai_presuny()
	if _minimalni_ai_tahy.is_empty():
		return

	var container = get_node_or_null("AIMoveOverlay")
	if not container:
		container = Node2D.new()
		container.name = "AIMoveOverlay"
		container.z_index = 24
		add_child(container)

	var entries: Array = _minimalni_ai_tahy.values()
	entries.sort_custom(func(a, b):
		var a_attack = bool(a.get("is_attack", false))
		var b_attack = bool(b.get("is_attack", false))
		if a_attack != b_attack:
			return a_attack
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)

	var limit = min(entries.size(), MAX_MINIMALNI_AI_CAR)
	for i in range(limit):
		var e = entries[i]
		var from_id = int(e.get("from", -1))
		var to_id = int(e.get("to", -1))
		var owner_tag = str(e.get("owner", "")).strip_edges().to_upper()
		if not provinces.has(from_id) or not provinces.has(to_id):
			continue

		var is_attack = bool(e.get("is_attack", false))
		var count = int(e.get("count", 1))
		var total_amount = int(e.get("total_amount", 0))
		_zobraz_minimalni_presun(from_id, to_id, owner_tag, is_attack, total_amount, count)

	if not _ai_anim_markery.is_empty():
		set_process(true)

func _ziskej_zbyvajici_cestu_presunu(move: Dictionary) -> Array:
	var path: Array = move.get("path", [])
	var path_index = int(move.get("path_index", 0))
	if path.size() < 2:
		return []
	if path_index < 0:
		path_index = 0
	if path_index >= (path.size() - 1):
		return []

	var out: Array = []
	for i in range(path_index, path.size()):
		out.append(int(path[i]))
	return out

func _vykresli_indikaci_cekajicich_presunu():
	_vymaz_indikaci_cekajicich_presunu()
	if cekajici_presuny.is_empty():
		return

	var container = get_node_or_null("QueuedMoveOverlay")
	if not container:
		container = Node2D.new()
		container.name = "QueuedMoveOverlay"
		container.z_index = 25
		add_child(container)

	for raw_move in cekajici_presuny:
		var move = raw_move as Dictionary
		var owner_tag = str(move.get("owner", "")).strip_edges().to_upper()
		if owner_tag == "":
			continue
		if not GameManager.je_lidsky_stat(owner_tag):
			continue

		var from_id = int(move.get("from", -1))
		var to_id = int(move.get("to", -1))
		if not provinces.has(from_id) or not provinces.has(to_id):
			continue

		var amount = max(0, int(move.get("amount", 0)))
		var target_owner_tag = _ziskej_braniciho_vlastnika_v_provincii(to_id)
		var is_attack = (target_owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA")

		var zbyvajici_path = _ziskej_zbyvajici_cestu_presunu(move)
		if zbyvajici_path.size() >= 3:
			_zobraz_cekajici_presun_po_ceste(container, zbyvajici_path, owner_tag, is_attack, amount)
		else:
			_zobraz_cekajici_presun(container, from_id, to_id, owner_tag, is_attack, amount)

	if not _cekajici_anim_markery.is_empty():
		set_process(true)

func _zobraz_cekajici_presun(container: Node2D, from_id: int, to_id: int, owner_tag: String, is_attack: bool, amount: int):
	if not provinces.has(from_id) or not provinces.has(to_id):
		return

	var offset = _ziskej_map_offset()
	var start_pos = _ziskej_map_pozici_provincie(from_id, offset)
	var end_pos = _ziskej_map_pozici_provincie(to_id, offset)
	if start_pos.distance_to(end_pos) < 0.001:
		return

	var col = _ziskej_barvu_overlay_statu(owner_tag, is_attack)
	var width = 2.2
	var speed = AI_MARKER_ATTACK_SPEED if is_attack else AI_MARKER_MOVE_SPEED

	var trail = Line2D.new()
	trail.width = max(1.6, width - 0.2)
	trail.default_color = Color(col.r, col.g, col.b, 0.28)
	trail.antialiased = false
	trail.add_point(start_pos)
	trail.add_point(end_pos)
	container.add_child(trail)

	_pridej_animovany_marker(container, _cekajici_anim_markery, start_pos, end_pos, col, speed, 0.12, width)

	if amount > 0:
		var amount_lbl = Label.new()
		amount_lbl.text = _formatuj_cislo(amount)
		var amount_pos = start_pos.lerp(end_pos, 0.45) + Vector2(5, 6)
		amount_lbl.position = Vector2(round(amount_pos.x), round(amount_pos.y))
		amount_lbl.add_theme_font_size_override("font_size", 11)
		amount_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.95))
		amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		amount_lbl.add_theme_constant_override("outline_size", 3)
		container.add_child(amount_lbl)

# Displays UI/output and updates visible presentation data.
func _zobraz_cekajici_presun_po_ceste(container: Node2D, path: Array, owner_tag: String, is_attack: bool, amount: int):
	if path.size() < 2:
		return

	var offset = _ziskej_map_offset()
	var poly_points = PackedVector2Array()
	for pid in path:
		var prov_id = int(pid)
		if not provinces.has(prov_id):
			continue
		poly_points.append(_ziskej_map_pozici_provincie(prov_id, offset))

	if poly_points.size() < 2:
		return

	var start_pos = poly_points[0]
	var end_pos = poly_points[poly_points.size() - 1]
	var col = _ziskej_barvu_overlay_statu(owner_tag, is_attack)
	var width = 2.2
	var speed = AI_MARKER_ATTACK_SPEED if is_attack else AI_MARKER_MOVE_SPEED

	var trail = Line2D.new()
	trail.width = max(1.6, width - 0.2)
	trail.default_color = Color(col.r, col.g, col.b, 0.28)
	trail.antialiased = false
	for p in poly_points:
		trail.add_point(p)
	container.add_child(trail)

	_pridej_animovany_marker_po_linii(container, _cekajici_anim_markery, poly_points, col, speed, 0.12, width)

	if amount > 0:
		var amount_lbl = Label.new()
		amount_lbl.text = _formatuj_cislo(amount)
		var amount_pos = start_pos.lerp(end_pos, 0.45) + Vector2(5, 6)
		amount_lbl.position = Vector2(round(amount_pos.x), round(amount_pos.y))
		amount_lbl.add_theme_font_size_override("font_size", 11)
		amount_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.95))
		amount_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		amount_lbl.add_theme_constant_override("outline_size", 3)
		container.add_child(amount_lbl)

# Registers the move, deducts troops from source, and shows visual midway "ghost"
func zaregistruj_presun_armady(from_id: int, to_id: int, amount: int, vykreslit_trajektorii: bool = true, planned_path: Array = []):
	if amount <= 0: return
	var move_path: Array = planned_path.duplicate()
	if move_path.size() < 2:
		move_path = najdi_nejrychlejsi_cestu_presunu(from_id, to_id)
	if move_path.size() < 2:
		if _ziskej_vlastnika_armady_v_provincii(from_id) == GameManager.hrac_stat:
			_ukaz_bitevni_popup("INVALID MOVE", "No valid traversable route was found for this destination.")
		ceka_na_cil_presunu = false
		vycisti_nahled_presunu()
		var invalid_root = get_parent()
		if "ceka_na_cil_presunu" in invalid_root:
			invalid_root.ceka_na_cil_presunu = false
		return
	
	var owner_tag = _ziskej_vlastnika_armady_v_provincii(from_id)
	if owner_tag == "":
		return
	var is_human_owner = GameManager.je_lidsky_stat(owner_tag)

	# Human players can intentionally split one province army into multiple queued moves.
	# Keep replacement behavior only for non-human owners.
	# AI batch planning guarantees one outgoing move per source in the same phase,
	# so we can skip the expensive full scan when batching is active.
	if not is_human_owner and not _pozastavit_aktualizaci_ikon:
		for i in range(cekajici_presuny.size() - 1, -1, -1):
			var q = cekajici_presuny[i]
			if int(q.get("from", -1)) != from_id:
				continue
			if str(q.get("owner", "")).strip_edges().to_upper() != owner_tag:
				continue
			cekajici_presuny.remove_at(i)

	var target_owner_tag = _ziskej_braniciho_vlastnika_v_provincii(to_id)
	var target_land_owner_tag = str(provinces[to_id].get("owner", "")).strip_edges().to_upper() if not _je_more_provincie(to_id) else ""
	var ma_pristup = false
	if target_owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA" and GameManager.has_method("muze_vstoupit_na_uzemi"):
		ma_pristup = bool(GameManager.muze_vstoupit_na_uzemi(owner_tag, target_owner_tag))
	if target_land_owner_tag != "" and owner_tag != target_land_owner_tag and GameManager.has_method("muze_vstoupit_na_uzemi"):
		ma_pristup = ma_pristup or bool(GameManager.muze_vstoupit_na_uzemi(owner_tag, target_land_owner_tag))
	
	# Block illegal attacks
	if target_owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA":
		if not ma_pristup and not GameManager.jsou_ve_valce(owner_tag, target_owner_tag):
			if owner_tag == GameManager.hrac_stat:
				_ukaz_bitevni_popup("ATTACK NOT ALLOWED", "You cannot attack yet. First declare war on %s via State Overview." % target_owner_tag)
			
			ceka_na_cil_presunu = false
			vycisti_nahled_presunu()
			var root_state = get_parent()
			if "ceka_na_cil_presunu" in root_state:
				root_state.ceka_na_cil_presunu = false
				
			return 
	
	provinces[from_id]["soldiers"] -= amount
	if provinces[from_id]["soldiers"] <= 0:
		provinces[from_id]["soldiers"] = 0
		if _je_more_provincie(from_id):
			provinces[from_id]["army_owner"] = ""
		else:
			provinces[from_id]["army_owner"] = str(provinces[from_id].get("owner", "")).strip_edges().to_upper()
	if not _pozastavit_aktualizaci_ikon:
		aktualizuj_ikony_armad()
	
	if not vykreslit_trajektorii:
		if _pozastavit_aktualizaci_ikon:
			var is_attack = (target_owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA" and not ma_pristup)
			_zaregistruj_minimalni_ai_tah_s_mnozstvim(from_id, to_id, owner_tag, is_attack, amount)

		cekajici_presuny.append({
			"from": from_id,
			"to": to_id,
			"path": move_path,
			"path_index": 0,
			"deduct_on_resolve": false,
			"amount": amount,
			"owner": owner_tag
		})
		
		ceka_na_cil_presunu = false
		vycisti_nahled_presunu()
		# Redraw queued-move overlay only for human owners; for AI batches this
		# avoids O(n^2) redraw churn while preserving gameplay/state.
		if is_human_owner:
			_vykresli_indikaci_cekajicich_presunu()
		var root2 = get_parent()
		if "ceka_na_cil_presunu" in root2:
			root2.ceka_na_cil_presunu = false
		return

	var is_attack_player = (target_owner_tag != "" and owner_tag != target_owner_tag and target_owner_tag != "SEA" and not ma_pristup)
	# Human moves are rendered only through queued overlay; this prevents duplicated amount labels.
	if not is_human_owner:
		if move_path.size() >= 3:
			_zobraz_minimalni_presun_po_ceste(move_path, owner_tag, is_attack_player, amount, 1)
		else:
			_zobraz_minimalni_presun(from_id, to_id, owner_tag, is_attack_player, amount, 1)
	else:
		_vymaz_minimalni_ai_presuny()
	
	cekajici_presuny.append({
		"from": from_id,
		"to": to_id,
		"path": move_path,
		"path_index": 0,
		"deduct_on_resolve": false,
		"amount": amount,
		"owner": owner_tag
	})
	
	ceka_na_cil_presunu = false
	vycisti_nahled_presunu()
	_vykresli_indikaci_cekajicich_presunu()
	var root = get_parent()
	if "ceka_na_cil_presunu" in root:
		root.ceka_na_cil_presunu = false

# Process all movements and await player confirmation for their battles
# Executes module-specific gameplay/UI logic for the current context.
func zpracuj_tah_armad():
	if cekajici_presuny.is_empty():
		_vymaz_indikaci_cekajicich_presunu()
		_minimalni_ai_tahy.clear()
		obsazene_pozice_presunu.clear()
		trasy_lane_counter.clear()
		return

	var puvodni_tahy = cekajici_presuny
	cekajici_presuny = []
	var tahy_k_zpracovani: Array = []
	var pokracujici_presuny: Array = []
	var profil_statu_cache: Dictionary = {}
	var army_slice_counter := 0

	for raw_move in puvodni_tahy:
		var move_any = raw_move as Dictionary
		if move_any == null:
			continue

		var path: Array = (move_any.get("path", []) as Array).duplicate()
		var from_id = int(move_any.get("from", -1))
		var to_id = int(move_any.get("to", -1))
		var path_index = int(move_any.get("path_index", 0))

		if path.size() >= 2:
			if path_index < 0:
				path_index = 0
			if path_index >= (path.size() - 1):
				path_index = path.size() - 2
			from_id = int(path[path_index])
			to_id = int(path[path_index + 1])

		var move := {
			"from": from_id,
			"to": to_id,
			"path": path,
			"path_index": path_index,
			"deduct_on_resolve": bool(move_any.get("deduct_on_resolve", false)),
			"amount": int(move_any.get("amount", 0)),
			"owner": str(move_any.get("owner", "")).strip_edges().to_upper()
		}
		tahy_k_zpracovani.append(move)
		army_slice_counter = await _army_turn_slice_wait(army_slice_counter)

	# Multi-step movement: deduct soldiers only when that specific step is really resolved.
	for i in range(tahy_k_zpracovani.size()):
		var move = tahy_k_zpracovani[i]
		if not bool(move.get("deduct_on_resolve", false)):
			continue

		var from_id = int(move.get("from", -1))
		if not provinces.has(from_id):
			move["amount"] = 0
			tahy_k_zpracovani[i] = move
			continue

		var requested = max(0, int(move.get("amount", 0)))
		var available = max(0, int(provinces[from_id].get("soldiers", 0)))
		var moved_amount = min(requested, available)
		if moved_amount <= 0:
			move["amount"] = 0
			tahy_k_zpracovani[i] = move
			continue

		provinces[from_id]["soldiers"] = available - moved_amount
		if int(provinces[from_id]["soldiers"]) <= 0:
			provinces[from_id]["soldiers"] = 0
			if _je_more_provincie(from_id):
				provinces[from_id]["army_owner"] = ""
			else:
				provinces[from_id]["army_owner"] = str(provinces[from_id].get("owner", "")).strip_edges().to_upper()

		move["amount"] = moved_amount
		tahy_k_zpracovani[i] = move
		army_slice_counter = await _army_turn_slice_wait(army_slice_counter)
	
	var celkovy_report = "" 
	var bitevni_udalosti: Array = []
	var ownership_changed := false
	var protivne_smery: Dictionary = {}
	for idx in range(tahy_k_zpracovani.size()):
		var base_move = tahy_k_zpracovani[idx]
		if int(base_move.get("amount", 0)) <= 0:
			continue
		var pair_key = "%d>%d" % [int(base_move.get("from", -1)), int(base_move.get("to", -1))]
		if not protivne_smery.has(pair_key):
			protivne_smery[pair_key] = []
		(protivne_smery[pair_key] as Array).append(idx)
		army_slice_counter = await _army_turn_slice_wait(army_slice_counter)

	# Head-on movement clash: armies marching into each other fight before province resolution.
	for i in range(tahy_k_zpracovani.size()):
		var utok1 = tahy_k_zpracovani[i]
		if int(utok1.get("amount", 0)) <= 0:
			continue

		var reverse_key = "%d>%d" % [int(utok1.get("to", -1)), int(utok1.get("from", -1))]
		if not protivne_smery.has(reverse_key):
			continue

		var reverse_indices: Array = protivne_smery[reverse_key]
		for j_raw in reverse_indices:
			var j = int(j_raw)
			if j <= i:
				continue

			var utok2 = tahy_k_zpracovani[j]
			if int(utok2.get("amount", 0)) <= 0:
				continue
			if str(utok1.get("owner", "")) == str(utok2.get("owner", "")):
				continue

			var hrac_zapojen = GameManager.je_lidsky_stat(str(utok1["owner"])) or GameManager.je_lidsky_stat(str(utok2["owner"]))
			var utok1_puvodni = int(utok1.get("amount", 0))
			var utok2_puvodni = int(utok2.get("amount", 0))
			var souboj_pole = _vyres_souboj_podle_sily(str(utok1["owner"]), int(utok1["amount"]), str(utok2["owner"]), int(utok2["amount"]))

			if bool(souboj_pole.get("attacker_won", false)):
				utok1["amount"] = int(souboj_pole.get("attacker_survivors", 0))
				utok2["amount"] = 0 # Wiped in this clash.
				if hrac_zapojen:
					bitevni_udalosti.append({
						"title": "Field battle",
						"text": _format_battle_popup_text(
							str(utok1["owner"]),
							str(utok2["owner"]),
							utok1_puvodni,
							utok2_puvodni,
							int(souboj_pole.get("attacker_survivors", 0)),
							0,
							"Moving armies clashed in the field.",
							str(provinces.get(int(utok1["to"]), {}).get("province_name", ""))
						),
						"province_id": int(utok1["to"]),
						"battle_data": _vytvor_bitevni_payload(
							str(utok1["owner"]),
							str(utok2["owner"]),
							utok1_puvodni,
							utok2_puvodni,
							int(souboj_pole.get("attacker_survivors", 0)),
							0,
							str(provinces.get(int(utok1["to"]), {}).get("province_name", ""))
						)
					})
			elif bool(souboj_pole.get("defender_won", false)):
				utok2["amount"] = int(souboj_pole.get("defender_survivors", 0))
				utok1["amount"] = 0 # Wiped in this clash.
				if hrac_zapojen:
					bitevni_udalosti.append({
						"title": "Field battle",
						"text": _format_battle_popup_text(
							str(utok2["owner"]),
							str(utok1["owner"]),
							utok2_puvodni,
							utok1_puvodni,
							int(souboj_pole.get("defender_survivors", 0)),
							0,
							"Moving armies clashed in the field.",
							str(provinces.get(int(utok2["to"]), {}).get("province_name", ""))
						),
						"province_id": int(utok2["to"]),
						"battle_data": _vytvor_bitevni_payload(
							str(utok2["owner"]),
							str(utok1["owner"]),
							utok2_puvodni,
							utok1_puvodni,
							int(souboj_pole.get("defender_survivors", 0)),
							0,
							str(provinces.get(int(utok2["to"]), {}).get("province_name", ""))
						)
					})
			else:
				# Peak chaos: both stacks delete each other.
				utok1["amount"] = 0
				utok2["amount"] = 0
				if hrac_zapojen:
					bitevni_udalosti.append({
						"title": "Field battle",
						"text": _format_battle_popup_text(
							str(utok1["owner"]),
							str(utok2["owner"]),
							utok1_puvodni,
							utok2_puvodni,
							0,
							0,
							"Both moving armies annihilated each other.",
							str(provinces.get(int(utok1["to"]), {}).get("province_name", ""))
						),
						"province_id": int(utok1["to"]),
						"battle_data": _vytvor_bitevni_payload(
							str(utok1["owner"]),
							str(utok2["owner"]),
							utok1_puvodni,
							utok2_puvodni,
							0,
							0,
							str(provinces.get(int(utok1["to"]), {}).get("province_name", ""))
						)
					})

			tahy_k_zpracovani[i] = utok1
			tahy_k_zpracovani[j] = utok2
			if int(utok1.get("amount", 0)) <= 0:
				break
			army_slice_counter = await _army_turn_slice_wait(army_slice_counter)

		tahy_k_zpracovani[i] = utok1
		army_slice_counter = await _army_turn_slice_wait(army_slice_counter)
	# ----------------------------------------------------
	
	# Anything that survives the head-on phase can still hit provinces.
	for move in tahy_k_zpracovani:
		if int(move.get("amount", 0)) <= 0:
			continue # No soldiers left, no action.
		
		var _from_id = int(move.get("from", -1))
		var to_id = int(move.get("to", -1))
		var utocnici = int(move.get("amount", 0))
		var attacker_tag = str(move.get("owner", "")).strip_edges().to_upper()
		var path: Array = move.get("path", [])
		var path_index = int(move.get("path_index", 0))
		var ma_dalsi_krok = (path.size() >= 2 and (path_index + 1) < (path.size() - 1))
		var moved_survivors := 0
		
		var target_is_sea = _je_more_provincie(to_id)
		var target_owner = _ziskej_braniciho_vlastnika_v_provincii(to_id)
		var target_land_owner = str(provinces[to_id].get("owner", "")).strip_edges().to_upper() if not target_is_sea else ""
		var ma_pristup_do_cile = false
		if not target_is_sea and attacker_tag != "":
			if target_land_owner != "" and target_land_owner != attacker_tag and GameManager.has_method("muze_vstoupit_na_uzemi"):
				ma_pristup_do_cile = bool(GameManager.muze_vstoupit_na_uzemi(attacker_tag, target_land_owner))
		if not target_is_sea and target_owner != "" and target_owner != attacker_tag:
			var stale_attack_order = (not ma_pristup_do_cile) and (not GameManager.jsou_ve_valce(attacker_tag, target_owner))
			if stale_attack_order:
				# Diplomacy changed since order creation (peace/capitulation), so cancel this attack.
				if not bool(move.get("deduct_on_resolve", false)) and _from_id >= 0 and provinces.has(_from_id):
					provinces[_from_id]["soldiers"] = int(provinces[_from_id].get("soldiers", 0)) + utocnici
					var from_owner_now = str(provinces[_from_id].get("army_owner", "")).strip_edges().to_upper()
					provinces[_from_id]["army_owner"] = _zvol_vlastnika_pri_pratelskem_slouceni(from_owner_now, attacker_tag)
				continue
		var je_mirovy_vstup = (not target_is_sea and ma_pristup_do_cile and (target_owner == "" or not GameManager.jsou_ve_valce(attacker_tag, target_owner)))
		var jmeno_provincie = str(provinces[to_id].get("province_name", "Unknown province"))
		
		var hrac_zapojen = GameManager.je_lidsky_stat(attacker_tag) or GameManager.je_lidsky_stat(target_owner)

		if target_is_sea:
			var obranci_more = int(provinces[to_id].get("soldiers", 0))
			if target_owner == "" or obranci_more <= 0:
				provinces[to_id]["soldiers"] = max(0, obranci_more) + utocnici
				provinces[to_id]["army_owner"] = attacker_tag
				moved_survivors = utocnici
			elif target_owner == attacker_tag:
				provinces[to_id]["soldiers"] += utocnici
				moved_survivors = utocnici
			else:
				var souboj_more = _vyres_souboj_podle_sily(attacker_tag, utocnici, target_owner, obranci_more)
				if bool(souboj_more.get("attacker_won", false)):
					var prezivsi_more_att = int(souboj_more.get("attacker_survivors", 0))
					provinces[to_id]["soldiers"] = prezivsi_more_att
					provinces[to_id]["army_owner"] = attacker_tag
					moved_survivors = prezivsi_more_att
				elif bool(souboj_more.get("defender_won", false)):
					provinces[to_id]["soldiers"] = int(souboj_more.get("defender_survivors", 0))
					provinces[to_id]["army_owner"] = target_owner
					moved_survivors = 0
				else:
					provinces[to_id]["soldiers"] = 0
					provinces[to_id]["army_owner"] = ""
					moved_survivors = 0

			if ma_dalsi_krok and moved_survivors > 0:
				pokracujici_presuny.append({
					"from": to_id,
					"to": int(path[path_index + 2]),
					"path": path,
					"path_index": path_index + 1,
					"deduct_on_resolve": true,
					"amount": moved_survivors,
					"owner": attacker_tag
				})
			continue

		if je_mirovy_vstup:
			var cilovi_vojaci = int(provinces[to_id].get("soldiers", 0))
			var puvodni_vlastnik_armady = _ziskej_braniciho_vlastnika_v_provincii(to_id)
			provinces[to_id]["soldiers"] = max(0, cilovi_vojaci) + utocnici
			provinces[to_id]["army_owner"] = _zvol_vlastnika_pri_pratelskem_slouceni(puvodni_vlastnik_armady, attacker_tag)
			moved_survivors = utocnici
			if ma_dalsi_krok and moved_survivors > 0:
				pokracujici_presuny.append({
					"from": to_id,
					"to": int(path[path_index + 2]),
					"path": path,
					"path_index": path_index + 1,
					"deduct_on_resolve": true,
					"amount": moved_survivors,
					"owner": attacker_tag
				})
			continue
		
		if target_owner == attacker_tag or target_owner == "SEA":
			provinces[to_id]["soldiers"] += utocnici
			provinces[to_id]["army_owner"] = attacker_tag
			moved_survivors = utocnici
			if ma_dalsi_krok and moved_survivors > 0:
				pokracujici_presuny.append({
					"from": to_id,
					"to": int(path[path_index + 2]),
					"path": path,
					"path_index": path_index + 1,
					"deduct_on_resolve": true,
					"amount": moved_survivors,
					"owner": attacker_tag
				})
			continue
			
		var obranci = int(provinces[to_id].get("soldiers", 0))
		var terenni_bonus_obrany = _ziskej_terenni_obranny_bonus_pct(to_id)
		var bonus_utocnika_osvobozeni = _ziskej_bonus_utocnika_pri_osvobozovani(to_id, attacker_tag)
		var souboj_provincie = _vyres_souboj_podle_sily(attacker_tag, utocnici, target_owner, obranci, terenni_bonus_obrany, bonus_utocnika_osvobozeni)
		
		if bool(souboj_provincie.get("attacker_won", false)):
			var prezivsi = int(souboj_provincie.get("attacker_survivors", 0))
			provinces[to_id]["soldiers"] = prezivsi
			moved_survivors = prezivsi
			
			var was_capital = provinces[to_id].get("is_capital", false)
			var capital_core_owner = str(provinces[to_id].get("core_owner", "")).strip_edges().to_upper()
			if capital_core_owner == "" or capital_core_owner == "SEA":
				capital_core_owner = target_owner
			
			# Province ownership flip + profile data sync.
			provinces[to_id]["owner"] = attacker_tag
			ownership_changed = true
			# Keep core_owner intact so occupied land stays distinguishable from core land.
			var profil_utocnika = profil_statu_cache.get(attacker_tag, null)
			if profil_utocnika == null:
				profil_utocnika = _ziskej_profil_statu(attacker_tag)
				profil_statu_cache[attacker_tag] = profil_utocnika
			provinces[to_id]["country_name"] = str(profil_utocnika.get("country_name", attacker_tag))
			provinces[to_id]["ideology"] = str(profil_utocnika.get("ideology", ""))
			provinces[to_id]["army_owner"] = attacker_tag
			
			var sprite = $Sprite2D
			if sprite and sprite.has_method("dobyt_provincii"):
				sprite.dobyt_provincii(to_id, attacker_tag)
				
			# Capitulation is intentionally delayed: hold capital for a full turn first.
			if was_capital:
				# Track only foreign-capital occupations; own-capital recapture should not trigger this.
				if attacker_tag != capital_core_owner and capital_core_owner != "" and capital_core_owner != "SEA":
					GameManager.zaregistruj_obsazeni_hlavniho_mesta(capital_core_owner, attacker_tag, to_id)
				if hrac_zapojen:
					if attacker_tag == capital_core_owner:
						bitevni_udalosti.append({
							"title": "Capital recaptured",
							"text": "%s recaptured its capital." % attacker_tag,
							"province_id": to_id
						})
					else:
						bitevni_udalosti.append({
							"title": "Capital occupied",
							"text": "%s captured the capital of %s. Capitulation triggers only if it is held for a full turn." % [attacker_tag, capital_core_owner],
							"province_id": to_id
						})
			
			if hrac_zapojen and not was_capital:
				bitevni_udalosti.append({
					"title": "Frontline changed",
					"text": _format_battle_popup_text(
						attacker_tag,
						target_owner,
						utocnici,
						obranci,
						prezivsi,
						0,
						"The attacking force captured the province.",
						jmeno_provincie
					),
					"province_id": to_id,
					"battle_data": _vytvor_bitevni_payload(attacker_tag, target_owner, utocnici, obranci, prezivsi, 0, jmeno_provincie)
				})
					
		else:
			var prezivsi = int(souboj_provincie.get("defender_survivors", 0))
			provinces[to_id]["soldiers"] = prezivsi
			provinces[to_id]["army_owner"] = target_owner if prezivsi > 0 else ""
			moved_survivors = 0
			
			if hrac_zapojen:
				bitevni_udalosti.append({
					"title": "Defense",
					"text": _format_battle_popup_text(
						attacker_tag,
						target_owner,
						utocnici,
						obranci,
						0,
						prezivsi,
						"The defenders held the line.",
						jmeno_provincie
					),
					"province_id": to_id,
					"battle_data": _vytvor_bitevni_payload(attacker_tag, target_owner, utocnici, obranci, 0, prezivsi, jmeno_provincie)
				})

		if ma_dalsi_krok and moved_survivors > 0:
			pokracujici_presuny.append({
				"from": to_id,
				"to": int(path[path_index + 2]),
				"path": path,
				"path_index": path_index + 1,
				"deduct_on_resolve": true,
				"amount": moved_survivors,
				"owner": attacker_tag
			})
		army_slice_counter = await _army_turn_slice_wait(army_slice_counter)
					
	if ownership_changed:
		celkovy_report = _zpracuj_automaticke_kapitulace(celkovy_report)
	if "cekajici_kapitulace" in GameManager and (GameManager.cekajici_kapitulace as Array).size() > 0:
		celkovy_report = _zpracuj_odlozene_kapitulace(celkovy_report)
	aktualizuj_ikony_armad()
	if ownership_changed:
		var sprite = $Sprite2D
		if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
			sprite.aktualizuj_mapovy_mod(str(aktualni_mapovy_mod), provinces)

	var je_rychle_tahove_zpracovani = _ma_rychle_zpracovani_tahu() and _potato_mode_enabled
	var bude_zobrazen_bitevni_popup = false
	if not bitevni_udalosti.is_empty():
		if not je_rychle_tahove_zpracovani or FAST_TURN_SHOW_BATTLE_SUMMARY:
			bude_zobrazen_bitevni_popup = true
	if celkovy_report != "" and not je_rychle_tahove_zpracovani:
		bude_zobrazen_bitevni_popup = true
	if bude_zobrazen_bitevni_popup:
		_ziskej_turn_indicator_suppression_lock()

	if not bitevni_udalosti.is_empty():
		if je_rychle_tahove_zpracovani:
			if FAST_TURN_SHOW_BATTLE_SUMMARY:
				await _ukaz_souhrn_bitevnich_udalosti(bitevni_udalosti)
		else:
			_zacni_bitevni_kameru()
			for udalost in bitevni_udalosti:
				await _ukaz_bitevni_popup_na_provincii(
					str(udalost.get("title", "Bitva")),
					str(udalost.get("text", "")),
					int(udalost.get("province_id", -1)),
					udalost.get("battle_data", {}) as Dictionary
				)
			await _obnov_bitevni_kameru()
	
	if celkovy_report != "":
		if je_rychle_tahove_zpracovani:
			if GameManager.has_method("_zaloguj_globalni_zpravu"):
				GameManager._zaloguj_globalni_zpravu("War", celkovy_report.strip_edges(), "war")
		else:
			await _ukaz_bitevni_popup("Frontline report", celkovy_report)

	if bude_zobrazen_bitevni_popup:
		_uvolni_turn_indicator_suppression_lock()

	if not pokracujici_presuny.is_empty():
		for p_move in pokracujici_presuny:
			cekajici_presuny.append(p_move)
			army_slice_counter = await _army_turn_slice_wait(army_slice_counter)
		
	get_tree().call_group("duchove_armad", "queue_free")
	_vykresli_indikaci_cekajicich_presunu()
	_minimalni_ai_tahy.clear()
	obsazene_pozice_presunu.clear()
	trasy_lane_counter.clear()

func _ma_rychle_zpracovani_tahu() -> bool:
	if not FAST_TURN_RESOLUTION:
		return false
	if GameManager == null:
		return false
	return bool(GameManager.zpracovava_se_tah)

func _ukaz_souhrn_bitevnich_udalosti(udalosti: Array) -> void:
	if udalosti.is_empty():
		return
	var lines: Array = []
	var max_lines = min(FAST_BATTLE_SUMMARY_MAX_LINES, udalosti.size())
	for i in range(max_lines):
		var e = udalosti[i] as Dictionary
		var title = str(e.get("title", "Battle")).strip_edges()
		if title == "":
			title = "Battle"

		var location = ""
		var winner_line = ""
		var text_lines = str(e.get("text", "")).split("\n")
		for raw_line in text_lines:
			var clean_line = str(raw_line).strip_edges()
			if clean_line == "":
				continue
			if clean_line.begins_with("Location:"):
				location = clean_line.replace("Location:", "").strip_edges()
			elif clean_line.begins_with("Winner:"):
				winner_line = clean_line

		var compact = title
		if location != "":
			compact += " | %s" % location
		if winner_line != "":
			compact += " | %s" % winner_line
		lines.append("- %s" % compact)

	var remaining = udalosti.size() - max_lines
	if remaining > 0:
		lines.append("- ... and %d more battle events" % remaining)

	await _ukaz_bitevni_popup("Frontline Report", "\n".join(lines))

func _ukaz_bitevni_popup(titulek: String, text: String, battle_payload: Dictionary = {}):
	_ziskej_turn_indicator_suppression_lock()
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("zobraz_systemove_hlaseni"):
		await game_ui.zobraz_systemove_hlaseni(titulek, text, false, battle_payload)
		_uvolni_turn_indicator_suppression_lock()
		return

	var dialog = AcceptDialog.new()
	dialog.title = titulek
	dialog.dialog_text = text
	dialog.min_size = Vector2i(360, 170)
	dialog.size = Vector2i(360, 170)
	dialog.unresizable = true
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup()

	# Place compact battle popups at top-center, just below TopBar.
	var viewport_size = get_viewport_rect().size
	var top_margin = 10
	var topbar = get_tree().current_scene.find_child("TopBar", true, false)
	if topbar and topbar is Control:
		top_margin = int((topbar as Control).size.y) + 8

	var popup_pos = Vector2i(
		int((viewport_size.x - dialog.size.x) * 0.5),
		top_margin
	)
	dialog.position = popup_pos
	
	dialog.confirmed.connect(func(): pass)
	dialog.canceled.connect(func(): pass)
	
	while is_instance_valid(dialog) and dialog.visible:
		await get_tree().process_frame
		
	if is_instance_valid(dialog):
		dialog.queue_free()
	_uvolni_turn_indicator_suppression_lock()

# Reads current runtime data and returns it to callers.
func _ziskej_turn_indicator_suppression_lock() -> void:
	_turn_indicator_suppress_locks += 1
	if _turn_indicator_suppress_locks == 1:
		_nastav_pozastaveni_turn_indikatoru(true)

func _uvolni_turn_indicator_suppression_lock() -> void:
	_turn_indicator_suppress_locks = max(0, _turn_indicator_suppress_locks - 1)
	if _turn_indicator_suppress_locks == 0:
		_nastav_pozastaveni_turn_indikatoru(false)

# Applies incoming values and synchronizes dependent state.
func _nastav_pozastaveni_turn_indikatoru(pozastavit: bool) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var game_ui = scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("nastav_pozastaveni_turn_overlay"):
		game_ui.nastav_pozastaveni_turn_overlay(pozastavit)
	var top_bar = scene.find_child("TopBar", true, false)
	if top_bar and top_bar.has_method("nastav_pozastaveni_turn_busy_indicator"):
		top_bar.nastav_pozastaveni_turn_busy_indicator(pozastavit)

func _zacni_bitevni_kameru():
	var kamera = $Camera2D
	if not kamera:
		return
	if _bitevni_kamera_aktivni:
		return
	_bitevni_puvodni_pozice = kamera.position
	_bitevni_kamera_aktivni = true

func _obnov_bitevni_kameru():
	if not _bitevni_kamera_aktivni:
		return
	var kamera = $Camera2D
	if not kamera:
		_bitevni_kamera_aktivni = false
		return

	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(kamera, "position", _bitevni_puvodni_pozice, 0.38)
	await t.finished
	_bitevni_kamera_aktivni = false

func _ukaz_bitevni_popup_na_provincii(titulek: String, text: String, province_id: int, battle_payload: Dictionary = {}):
	var kamera = $Camera2D
	if not kamera or not provinces.has(province_id):
		await _ukaz_bitevni_popup(titulek, text, battle_payload)
		return

	var cilova_pozice = _ziskej_map_pozici_provincie(province_id, _ziskej_map_offset())
	var vzdalenost = kamera.position.distance_to(cilova_pozice)
	var delka_preletu = clamp(vzdalenost / 1600.0, 0.18, 0.55)

	var t1 = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(kamera, "position", cilova_pozice, delka_preletu)
	await t1.finished

	await _ukaz_bitevni_popup(titulek, text, battle_payload)

# Cancels the active flow and restores a safe default state.
func zrus_cekajici_utoky_na_stat(target_tag: String) -> int:
	var target = str(target_tag).strip_edges().to_upper()
	if target == "":
		return 0
	var removed := 0
	for i in range(cekajici_presuny.size() - 1, -1, -1):
		var move = cekajici_presuny[i] as Dictionary
		if move == null:
			continue
		var attacker = str(move.get("owner", "")).strip_edges().to_upper()
		if attacker == "" or attacker == target:
			continue
		var to_id = int(move.get("to", -1))
		if to_id < 0 or not provinces.has(to_id) or _je_more_provincie(to_id):
			continue
		var to_owner = str(provinces[to_id].get("owner", "")).strip_edges().to_upper()
		if to_owner != target:
			continue

		var has_access = bool(GameManager.has_method("muze_vstoupit_na_uzemi") and GameManager.muze_vstoupit_na_uzemi(attacker, target))
		var at_war = bool(GameManager.has_method("jsou_ve_valce") and GameManager.jsou_ve_valce(attacker, target))
		if has_access and not at_war:
			continue

		if not bool(move.get("deduct_on_resolve", false)):
			var from_id = int(move.get("from", -1))
			var amount = max(0, int(move.get("amount", 0)))
			if amount > 0 and from_id >= 0 and provinces.has(from_id):
				provinces[from_id]["soldiers"] = int(provinces[from_id].get("soldiers", 0)) + amount
				var existing_owner = str(provinces[from_id].get("army_owner", "")).strip_edges().to_upper()
				provinces[from_id]["army_owner"] = _zvol_vlastnika_pri_pratelskem_slouceni(existing_owner, attacker)

		cekajici_presuny.remove_at(i)
		removed += 1

	if removed > 0:
		aktualizuj_ikony_armad()
		_vykresli_indikaci_cekajicich_presunu()
	return removed

# Reads current runtime data and returns it to callers.
func _ziskej_reprezentaci_statu(tag: String) -> Dictionary:
	var hledany = tag.strip_edges().to_upper()
	for p_id in provinces.keys():
		if str(provinces[p_id].get("owner", "")).strip_edges().to_upper() == hledany and str(provinces[p_id].get("core_owner", "")).strip_edges().to_upper() == hledany:
			return {
				"country_name": str(provinces[p_id].get("country_name", hledany)),
				"ideology": str(provinces[p_id].get("ideology", ""))
			}

	for p_id in provinces.keys():
		if str(provinces[p_id].get("owner", "")).strip_edges().to_upper() == hledany:
			return {
				"country_name": str(provinces[p_id].get("country_name", hledany)),
				"ideology": str(provinces[p_id].get("ideology", ""))
			}
	return {
		"country_name": hledany,
		"ideology": ""
	}

# Executes module-specific gameplay/UI logic for the current context.
func _kapituluj_stat_rozdelenim(cilovy_stat: String, fallback_vitez: String = "") -> Dictionary:
	var target_owner = cilovy_stat.strip_edges().to_upper()
	var winner = fallback_vitez.strip_edges().to_upper()
	if target_owner == "":
		return {"provedeno": false, "okupanti": {}}

	var sprite = $Sprite2D
	var labels = get_node_or_null("ProvinceLabels")
	var prevedeno := 0
	var okupanti: Dictionary = {}
	var ma_core = false
	var profile_cache: Dictionary = {}

	if winner != "":
		profile_cache[winner] = _ziskej_reprezentaci_statu(winner)

	for p_id in provinces.keys():
		var p = provinces[p_id]
		var core_owner = str(p.get("core_owner", "")).strip_edges().to_upper()
		if core_owner != target_owner:
			continue
		ma_core = true

		var current_owner = str(p.get("owner", "")).strip_edges().to_upper()
		if current_owner == target_owner:
			if winner == "":
				return {"provedeno": false, "okupanti": {}}
			current_owner = winner
			p["owner"] = winner
			prevedeno += 1

		if current_owner == "" or current_owner == "SEA":
			if winner != "":
				current_owner = winner
				p["owner"] = winner
				prevedeno += 1

		if current_owner != "" and current_owner != "SEA":
			if not profile_cache.has(current_owner):
				profile_cache[current_owner] = _ziskej_reprezentaci_statu(current_owner)
			var profile = profile_cache[current_owner]
			p["country_name"] = str(profile.get("country_name", current_owner))
			p["ideology"] = str(profile.get("ideology", ""))
			p["core_owner"] = current_owner
			p["army_owner"] = current_owner if int(p.get("soldiers", 0)) > 0 else ""
			okupanti[current_owner] = int(okupanti.get(current_owner, 0)) + 1
		else:
			p["soldiers"] = 0
			p["army_owner"] = ""

		if bool(p.get("is_capital", false)):
			p["is_capital"] = false
			if labels:
				for lbl in labels.get_children():
					if lbl.get("province_id") == p_id:
						lbl.set("is_capital", false)
						var f = lbl.find_child("Flag", true, false)
						if f:
							f.hide()

	# If defeated state controls foreign cores, immediately return those provinces.
	for p_id in provinces.keys():
		var p = provinces[p_id]
		var owner_now = str(p.get("owner", "")).strip_edges().to_upper()
		if owner_now != target_owner:
			continue

		var core_owner = str(p.get("core_owner", "")).strip_edges().to_upper()
		var reclaim_owner = ""
		if core_owner != "" and core_owner != "SEA" and core_owner != target_owner:
			reclaim_owner = core_owner
		elif winner != "":
			reclaim_owner = winner

		if reclaim_owner == "":
			if _je_more_provincie(p_id):
				p["owner"] = "SEA"
			p["soldiers"] = 0
			p["army_owner"] = ""
			continue

		p["owner"] = reclaim_owner
		if not profile_cache.has(reclaim_owner):
			profile_cache[reclaim_owner] = _ziskej_reprezentaci_statu(reclaim_owner)
		var reclaim_profile = profile_cache[reclaim_owner]
		p["country_name"] = str(reclaim_profile.get("country_name", reclaim_owner))
		p["ideology"] = str(reclaim_profile.get("ideology", ""))
		p["army_owner"] = reclaim_owner if int(p.get("soldiers", 0)) > 0 else ""
		okupanti[reclaim_owner] = int(okupanti.get(reclaim_owner, 0)) + 1
		prevedeno += 1

	# Final safety cleanup so defeated state cannot keep ghost armies.
	for p_id in provinces.keys():
		var p = provinces[p_id]
		if _je_more_provincie(p_id):
			if str(p.get("army_owner", "")).strip_edges().to_upper() == target_owner:
				p["soldiers"] = 0
				p["army_owner"] = ""
			continue

		var owner_land = str(p.get("owner", "")).strip_edges().to_upper()
		var army_owner_land = str(p.get("army_owner", "")).strip_edges().to_upper()
		if army_owner_land == target_owner:
			p["army_owner"] = owner_land if int(p.get("soldiers", 0)) > 0 else ""
		if owner_land == target_owner:
			p["soldiers"] = 0
			p["army_owner"] = ""

	if not ma_core:
		return {"provedeno": false, "okupanti": {}}

	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod(aktualni_mapovy_mod, provinces)

	return {
		"provedeno": true,
		"prevedeno": prevedeno,
		"okupanti": okupanti
	}

# Executes module-specific gameplay/UI logic for the current context.
func _zpracuj_automaticke_kapitulace(celkovy_report: String) -> String:
	var state_flags: Dictionary = {}
	for p_id in provinces.keys():
		var p = provinces[p_id]
		var core_owner = str(p.get("core_owner", "")).strip_edges().to_upper()
		if core_owner == "" or core_owner == "SEA":
			continue
		if not state_flags.has(core_owner):
			state_flags[core_owner] = {"has_self": false, "has_occupied": false}
		var owner_tag = str(p.get("owner", "")).strip_edges().to_upper()
		var flags = state_flags[core_owner] as Dictionary
		if owner_tag == core_owner:
			flags["has_self"] = true
		else:
			flags["has_occupied"] = true
		state_flags[core_owner] = flags

	for target_owner in state_flags.keys():
		if GameManager.has_method("ma_cekajici_mirovou_konferenci_pro_stat") and GameManager.ma_cekajici_mirovou_konferenci_pro_stat(target_owner):
			continue
		var flags = state_flags[target_owner] as Dictionary
		if bool(flags.get("has_self", false)) or not bool(flags.get("has_occupied", false)):
			continue

		# If exactly one state occupies all remaining cores, use peace conference flow
		# (same as delayed capitulation) instead of instant split/annex.
		var okupanti_set: Dictionary = {}
		for p_id_any in provinces.keys():
			var pid = int(p_id_any)
			var pd = provinces[pid]
			var core_owner = str(pd.get("core_owner", "")).strip_edges().to_upper()
			if core_owner != str(target_owner):
				continue
			var owner_tag = str(pd.get("owner", "")).strip_edges().to_upper()
			if owner_tag == "" or owner_tag == "SEA" or owner_tag == str(target_owner):
				continue
			okupanti_set[owner_tag] = true

		if okupanti_set.size() == 1 and GameManager.has_method("uzavri_mir_a_zahaj_konferenci"):
			var winner_tag = str(okupanti_set.keys()[0]).strip_edges().to_upper()
			if winner_tag != "" and winner_tag != str(target_owner):
				GameManager.map_data = provinces
				var conf_result = GameManager.uzavri_mir_a_zahaj_konferenci(winner_tag, target_owner, "automatic_capitulation")
				if bool(conf_result.get("ok", false)):
					provinces = GameManager.map_data
					_rebuild_movement_topology_cache()
					if GameManager.je_lidsky_stat(winner_tag) or GameManager.je_lidsky_stat(target_owner):
						celkovy_report += "Automatic capitulation: %s lost all non-occupied territory. Peace conference will determine war terms.\n\n" % target_owner
					continue

		var vysledek = _kapituluj_stat_rozdelenim(target_owner, "")
		if not bool(vysledek.get("provedeno", false)):
			continue

		if GameManager.has_method("vycisti_stat_po_kapitulaci"):
			GameManager.vycisti_stat_po_kapitulaci(target_owner)

		var okupanti: Dictionary = vysledek.get("okupanti", {})
		var casti: Array = []
		for okupant in okupanti.keys():
			casti.append("%s: %d" % [okupant, int(okupanti[okupant])])
		var hrac_zapojen = GameManager.je_lidsky_stat(target_owner)
		if not hrac_zapojen:
			for okupant in okupanti.keys():
				if GameManager.je_lidsky_stat(str(okupant)):
					hrac_zapojen = true
					break
		if hrac_zapojen:
			celkovy_report += "Automatic capitulation: %s lost all non-occupied territory. Occupation split: %s.\n\n" % [target_owner, ", ".join(casti)]
		if GameManager.has_method("_zaloguj_globalni_zpravu"):
			GameManager._zaloguj_globalni_zpravu(
				"War",
				"Automatic capitulation of %s. Occupation split: %s." % [target_owner, ", ".join(casti)],
				"war"
			)

	return celkovy_report

# Executes module-specific gameplay/UI logic for the current context.
func _zpracuj_odlozene_kapitulace(celkovy_report: String) -> String:
	var hotove_kapitulace = GameManager.vyhodnot_odlozene_kapitulace()
	if hotove_kapitulace.is_empty():
		return celkovy_report

	for zaznam in hotove_kapitulace:
		var target_owner = str(zaznam.get("obrance", "")).strip_edges().to_upper()
		var winner_tag = str(zaznam.get("utocnik", "")).strip_edges().to_upper()
		if target_owner == "" or winner_tag == "" or target_owner == winner_tag:
			continue

		if GameManager.has_method("uzavri_mir_a_zahaj_konferenci"):
			GameManager.map_data = provinces
			var conf_result = GameManager.uzavri_mir_a_zahaj_konferenci(winner_tag, target_owner, "capitulation")
			if bool(conf_result.get("ok", false)):
				provinces = GameManager.map_data
				_rebuild_movement_topology_cache()
				if GameManager.je_lidsky_stat(winner_tag) or GameManager.je_lidsky_stat(target_owner):
					celkovy_report += "Capitulation: %s held the capital of %s. Peace conference will determine war terms.\n\n" % [winner_tag, target_owner]
				continue

		# Fallback to legacy split when conference API is unavailable.
		var vysledek = _kapituluj_stat_rozdelenim(target_owner, winner_tag)
		if not bool(vysledek.get("provedeno", false)):
			continue

		if GameManager.has_method("vycisti_stat_po_kapitulaci"):
			GameManager.vycisti_stat_po_kapitulaci(target_owner)

		if GameManager.je_lidsky_stat(winner_tag) or GameManager.je_lidsky_stat(target_owner):
			var okupanti: Dictionary = vysledek.get("okupanti", {})
			var casti: Array = []
			for okupant in okupanti.keys():
				casti.append("%s: %d" % [okupant, int(okupanti[okupant])])
			celkovy_report += "Capitulation: %s held the capital of %s for one full turn. Occupation split: %s.\n\n" % [winner_tag, target_owner, ", ".join(casti)]
			if GameManager.has_method("_zaloguj_globalni_zpravu"):
				GameManager._zaloguj_globalni_zpravu(
					"War",
					"Capitulation of %s after capital hold. Occupation split: %s." % [target_owner, ", ".join(casti)],
					"war"
				)

	return celkovy_report

# Executes module-specific gameplay/UI logic for the current context.
func hrac_se_vzdal(state_tag: String) -> bool:
	var target_owner = state_tag.strip_edges().to_upper()
	if target_owner == "" or target_owner == "SEA":
		return false

	var vysledek = _kapituluj_stat_rozdelenim(target_owner, "")
	if not bool(vysledek.get("provedeno", false)):
		return false

	if GameManager.has_method("vycisti_stat_po_kapitulaci"):
		GameManager.vycisti_stat_po_kapitulaci(target_owner)

	GameManager.map_data = provinces
	aktualizuj_ikony_armad()
	_aktualizuj_indikatory_kapitulace()
	GameManager.kolo_zmeneno.emit()
	return true

func _aktualizuj_indikatory_kapitulace():
	var container = get_node_or_null("CapitulationIndicators")
	if not container:
		container = Node2D.new()
		container.name = "CapitulationIndicators"
		container.z_index = 30
		add_child(container)

	for child in container.get_children():
		child.queue_free()

	if not GameManager.has_method("vyhodnot_odlozene_kapitulace"):
		return
	if not ("cekajici_kapitulace" in GameManager):
		return

	var offset = _ziskej_map_offset()
	for zaznam in GameManager.cekajici_kapitulace:
		var capital_id = int(zaznam.get("capital_id", -1))
		if not provinces.has(capital_id):
			continue

		var utocnik = str(zaznam.get("utocnik", "")).strip_edges().to_upper()
		var obrance = str(zaznam.get("obrance", "")).strip_edges().to_upper()
		if utocnik == "" or obrance == "":
			continue

		var owner_now = str(provinces[capital_id].get("owner", "")).strip_edges().to_upper()
		if owner_now != utocnik:
			continue

		var capture_turn = int(zaznam.get("capture_turn", GameManager.aktualni_kolo))
		var remain = max(0, (capture_turn + 1) - int(GameManager.aktualni_kolo))

		var node = Node2D.new()
		node.position = Vector2(provinces[capital_id]["x"], provinces[capital_id]["y"]) + offset + Vector2(0, -44)

		var bg = ColorRect.new()
		bg.size = Vector2(170, 30)
		bg.position = Vector2(-85, -15)
		bg.color = Color(0.38, 0.08, 0.08, 0.72)
		node.add_child(bg)

		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(170, 26)
		lbl.position = Vector2(-85, -13)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = "%s holds capital (%s): %d turn" % [utocnik, obrance, max(1, remain)]
		node.add_child(lbl)

		container.add_child(node)



