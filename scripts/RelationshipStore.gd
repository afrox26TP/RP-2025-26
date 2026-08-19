extends RefCounted

## Owns bilateral relationship values and player-action cooldowns.
## GameManager remains responsible for diplomacy side effects such as alliance sync and logging.

var _normalize_tag: Callable
var _csv_path: String = ""
var _relationships: Dictionary = {}
var _last_action_turn: Dictionary = {}
var _loaded: bool = false


func configure(normalize_tag: Callable, csv_path: String) -> void:
	_normalize_tag = normalize_tag
	_csv_path = csv_path


func ensure_loaded() -> void:
	if _loaded:
		return

	_relationships.clear()
	var file = FileAccess.open(_csv_path, FileAccess.READ)
	if file == null:
		push_warning("Nepodarilo se nacist %s" % _csv_path)
		_loaded = true
		return

	if not file.eof_reached():
		file.get_line()

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var parts = line.split(";")
		if parts.size() < 3:
			continue

		var a = _normalize(str(parts[0]))
		var b = _normalize(str(parts[1]))
		if a == "" or b == "" or a == b:
			continue

		var score := 0.0
		var score_text = str(parts[2]).strip_edges()
		if score_text != "":
			score = float(score_text)
		_relationships[directional_key(a, b)] = score
		_relationships[directional_key(b, a)] = score

	_loaded = true


func get_relation(tag_a: String, tag_b: String) -> float:
	ensure_loaded()
	var a = _normalize(tag_a)
	var b = _normalize(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0
	return float(_relationships.get(directional_key(a, b), 0.0))


func adjust(tag_a: String, tag_b: String, delta: float, minimum: float, maximum: float, current_turn: int = -1, cooldown_turns: int = 0) -> Dictionary:
	ensure_loaded()
	var a = _normalize(tag_a)
	var b = _normalize(tag_b)
	if a == "" or b == "" or a == b:
		return {"valid": false, "changed": false, "old": 0.0, "new": 0.0}

	var pair = pair_key(a, b)
	var old_value = float(_relationships.get(directional_key(a, b), 0.0))
	if current_turn >= 0 and remaining_turns(a, b, current_turn, cooldown_turns) > 0:
		return _result(a, b, pair, old_value, old_value, false)

	var new_value = clampf(old_value + delta, minimum, maximum)
	if is_equal_approx(new_value, old_value):
		return _result(a, b, pair, old_value, old_value, false)

	_relationships[directional_key(a, b)] = new_value
	_relationships[directional_key(b, a)] = new_value
	if current_turn >= 0:
		_last_action_turn[pair] = current_turn
	return _result(a, b, pair, old_value, new_value, true)


func can_adjust(tag_a: String, tag_b: String, current_turn: int, cooldown_turns: int) -> bool:
	var a = _normalize(tag_a)
	var b = _normalize(tag_b)
	if a == "" or b == "" or a == b:
		return false
	return remaining_turns(a, b, current_turn, cooldown_turns) <= 0


func remaining_turns(tag_a: String, tag_b: String, current_turn: int, cooldown_turns: int) -> int:
	var key = pair_key(tag_a, tag_b)
	if key == "" or not _last_action_turn.has(key):
		return 0
	var elapsed = current_turn - int(_last_action_turn[key])
	return maxi(0, cooldown_turns - elapsed)


func last_action_turn(tag_a: String, tag_b: String, fallback: int = -9999999) -> int:
	var key = pair_key(tag_a, tag_b)
	return int(_last_action_turn.get(key, fallback))


func directional_key(tag_a: String, tag_b: String) -> String:
	return "%s|%s" % [_normalize(tag_a), _normalize(tag_b)]


func pair_key(tag_a: String, tag_b: String) -> String:
	var a = _normalize(tag_a)
	var b = _normalize(tag_b)
	if a == "" or b == "" or a == b:
		return ""
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


func export_state() -> Dictionary:
	return {
		"relationships": _relationships.duplicate(true),
		"last_action_turn": _last_action_turn.duplicate(true),
		"loaded": _loaded
	}


func import_state(relationships: Dictionary, action_turns: Dictionary, loaded: bool) -> void:
	_relationships = relationships.duplicate(true)
	_last_action_turn = action_turns.duplicate(true)
	_loaded = loaded


func reset() -> void:
	_relationships.clear()
	_last_action_turn.clear()
	_loaded = false


func _normalize(tag: String) -> String:
	if _normalize_tag.is_valid():
		return str(_normalize_tag.call(tag))
	return tag.strip_edges().to_upper()


func _result(a: String, b: String, pair: String, old_value: float, new_value: float, changed: bool) -> Dictionary:
	return {
		"valid": true,
		"changed": changed,
		"a": a,
		"b": b,
		"pair_key": pair,
		"old": old_value,
		"new": new_value
	}
