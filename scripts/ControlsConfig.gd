extends RefCounted

const SETTINGS_FILE_PATH := "user://settings.cfg"
const KEYBINDS_SECTION := "keybinds"

const ACTION_CAMERA_UP := "camera_move_up"
const ACTION_CAMERA_DOWN := "camera_move_down"
const ACTION_CAMERA_LEFT := "camera_move_left"
const ACTION_CAMERA_RIGHT := "camera_move_right"
const ACTION_END_TURN := "end_turn"
const ACTION_DEV_CONQUER := "dev_conquer"

const ACTIONS := [
	ACTION_CAMERA_UP,
	ACTION_CAMERA_DOWN,
	ACTION_CAMERA_LEFT,
	ACTION_CAMERA_RIGHT,
	ACTION_END_TURN,
	ACTION_DEV_CONQUER
]

const ACTION_LABELS := {
	ACTION_CAMERA_UP: "Move camera up",
	ACTION_CAMERA_DOWN: "Move camera down",
	ACTION_CAMERA_LEFT: "Move camera left",
	ACTION_CAMERA_RIGHT: "Move camera right",
	ACTION_END_TURN: "End turn",
	ACTION_DEV_CONQUER: "Developer conquer"
}

const DEFAULT_BINDINGS := {
	ACTION_CAMERA_UP: [KEY_W, KEY_UP],
	ACTION_CAMERA_DOWN: [KEY_S, KEY_DOWN],
	ACTION_CAMERA_LEFT: [KEY_A, KEY_LEFT],
	ACTION_CAMERA_RIGHT: [KEY_D, KEY_RIGHT],
	ACTION_END_TURN: [KEY_SPACE],
	ACTION_DEV_CONQUER: [KEY_C]
}

static func ensure_default_actions() -> void:
	for action_any in ACTIONS:
		var action = StringName(str(action_any))
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			set_action_keycodes(str(action), DEFAULT_BINDINGS.get(str(action), []))

static func get_default_bindings() -> Dictionary:
	var out: Dictionary = {}
	for action_any in ACTIONS:
		var action = str(action_any)
		out[action] = normalize_codes(DEFAULT_BINDINGS.get(action, []))
	return out

static func normalize_codes(raw_value) -> Array:
	var out: Array = []
	if raw_value is Array:
		for code_any in raw_value:
			var code = int(code_any)
			if code > 0 and not out.has(code):
				out.append(code)
	elif raw_value != null:
		var single_code = int(raw_value)
		if single_code > 0:
			out.append(single_code)
	return out

static func load_bindings_from_config(cfg: ConfigFile = null) -> Dictionary:
	var local_cfg := cfg
	if local_cfg == null:
		local_cfg = ConfigFile.new()
		local_cfg.load(SETTINGS_FILE_PATH)

	var out = get_default_bindings()
	for action_any in ACTIONS:
		var action = str(action_any)
		var fallback = out.get(action, [])
		var stored = local_cfg.get_value(KEYBINDS_SECTION, action, fallback)
		var codes = normalize_codes(stored)
		if codes.is_empty():
			codes = normalize_codes(fallback)
		out[action] = codes
	return out

static func save_bindings_to_config(cfg: ConfigFile, bindings: Dictionary) -> void:
	if cfg == null:
		return
	for action_any in ACTIONS:
		var action = str(action_any)
		cfg.set_value(KEYBINDS_SECTION, action, normalize_codes(bindings.get(action, DEFAULT_BINDINGS.get(action, []))))

static func apply_bindings(bindings: Dictionary) -> void:
	ensure_default_actions()
	for action_any in ACTIONS:
		var action = str(action_any)
		var codes = normalize_codes(bindings.get(action, DEFAULT_BINDINGS.get(action, [])))
		if codes.is_empty():
			codes = normalize_codes(DEFAULT_BINDINGS.get(action, []))
		set_action_keycodes(action, codes)

static func set_action_keycodes(action: String, codes: Array) -> void:
	var action_name = StringName(action)
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for code_any in normalize_codes(codes):
		var event := InputEventKey.new()
		event.keycode = int(code_any)
		InputMap.action_add_event(action_name, event)

static func get_action_keycodes(action: String) -> Array:
	ensure_default_actions()
	var out: Array = []
	for event_any in InputMap.action_get_events(StringName(action)):
		if event_any is InputEventKey:
			var key_event := event_any as InputEventKey
			var code = int(key_event.keycode)
			if code > 0 and not out.has(code):
				out.append(code)
	return out

static func get_binding_text(action: String, bindings: Dictionary = {}) -> String:
	var codes: Array = []
	if not bindings.is_empty() and bindings.has(action):
		codes = normalize_codes(bindings[action])
	else:
		codes = get_action_keycodes(action)
	if codes.is_empty():
		return "Unbound"
	var names: Array[String] = []
	for code_any in codes:
		var key_name = OS.get_keycode_string(int(code_any)).strip_edges()
		if key_name == "":
			key_name = str(code_any)
		names.append(key_name)
	return " / ".join(names)

static func matches_action(event: InputEvent, action: String) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	for code_any in get_action_keycodes(action):
		if int(code_any) == int(key_event.keycode):
			return true
	return false

static func bindings_equal(a: Dictionary, b: Dictionary) -> bool:
	for action_any in ACTIONS:
		var action = str(action_any)
		if normalize_codes(a.get(action, [])) != normalize_codes(b.get(action, [])):
			return false
	return true

