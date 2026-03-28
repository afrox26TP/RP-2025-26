extends CanvasLayer

@onready var money_label = $Panel/HBoxContainer/MoneyLabel
@onready var turn_label = $Panel/HBoxContainer/TurnLabel
@onready var next_btn = $Panel/HBoxContainer/NextTurnButton

# Paths to the central flag and player name based on the UI tree
@onready var player_flag = $Panel/HBoxContainer/PlayerInfo/PlayerFlag
@onready var player_name = $Panel/HBoxContainer/PlayerInfo/PlayerName

var flag_texture_cache: Dictionary = {}
var ideology_flag_path_index: Dictionary = {}
var ideology_flag_index_ready: bool = false
var _last_seen_player_tag: String = ""
var _player_focus_tween: Tween

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
	next_btn.pressed.connect(_on_next_turn_pressed)
	GameManager.kolo_zmeneno.connect(aktualizuj_ui)
	_nastav_tooltipy_ui()

func _nastav_tooltipy_ui() -> void:
	money_label.tooltip_text = "Stav statni kasy a cisty prijem za kolo."
	turn_label.tooltip_text = "Aktualni cislo kola."
	next_btn.tooltip_text = "Ukonci tve kolo a spusti dalsi tah."
	player_flag.tooltip_text = "Vlajka prave ovladaneho statu."
	player_name.tooltip_text = "Nazev statu, za ktery prave hrajes."
	TooltipUtils.apply_default_tooltips(self)

func aktualizuj_ui():
	# Update money and turn counters
	money_label.text = "Kasa: %.2f mil. USD (+%.2f)" % [GameManager.statni_kasa, GameManager.celkovy_prijem]
	turn_label.text = "Kolo: %d" % GameManager.aktualni_kolo
	
	# Update player info with dynamic data from GameManager
	var aktivni_tag = str(GameManager.hrac_stat).strip_edges().to_upper()
	nastav_hrace(aktivni_tag, GameManager.hrac_jmeno, GameManager.hrac_ideologie)

	# In local multiplayer, center camera when control switches to another human player.
	if GameManager.lokalni_hraci_staty.size() > 1 and _last_seen_player_tag != "" and aktivni_tag != _last_seen_player_tag:
		_vycentruj_kameru_na_stat(aktivni_tag, true)

	_last_seen_player_tag = aktivni_tag

func _on_next_turn_pressed():
	GameManager.ukonci_kolo()

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
