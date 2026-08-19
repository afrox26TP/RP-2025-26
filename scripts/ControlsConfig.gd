# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends RefCounted

# Central keybind helper shared by menu and gameplay scripts.
# It normalizes key codes, loads/saves config values, and applies them to InputMap.

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
	# Inputs: none
	# Outputs: none
	# Execution timing: Called during startup and before keybind reads/writes.
	# Steps:
	# 1. Iterate all known actions.
	# 2. Add missing actions to `InputMap`.
	# 3. If an action has no events, apply default keycodes.
	# Guarantees actions exist even on a fresh install with empty settings.
	for action_any in ACTIONS:
		var action = StringName(str(action_any))
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			set_action_keycodes(str(action), DEFAULT_BINDINGS.get(str(action), []))

static func get_default_bindings() -> Dictionary:
	# Inputs: none
	# Outputs:
	# - `Dictionary`: Action -> normalized default keycode array.
	# Execution timing: Called when creating fallback data for loading or reset.
	# Steps:
	# 1. Build an output dictionary.
	# 2. For each action, normalize configured default codes.
	# 3. Return the completed map.
	var out: Dictionary = {}
	for action_any in ACTIONS:
		var action = str(action_any)
		out[action] = normalize_codes(DEFAULT_BINDINGS.get(action, []))
	return out

static func normalize_codes(raw_value) -> Array:
	# Inputs:
	# - `raw_value`: Single value, array, or null containing keycode candidates.
	# Outputs:
	# - `Array`: Deduplicated positive integer keycodes.
	# Execution timing: Called by all load/save/apply helpers that touch keycodes.
	# Steps:
	# 1. If input is an array, iterate all items.
	# 2. Convert each item to int and keep only `> 0` unique values.
	# 3. If input is a single non-null value, normalize it the same way.
	# 4. Return normalized result.
	# Accepts single value or array, removes invalid/duplicate key codes.
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
	# Inputs:
	# - `cfg`: Optional `ConfigFile`; when null, a new config is loaded from disk.
	# Outputs:
	# - `Dictionary`: Action -> normalized keycode array with default fallback.
	# Execution timing: Called when loading user settings into runtime state.
	# Steps:
	# 1. Resolve config source (`cfg` or file from `SETTINGS_FILE_PATH`).
	# 2. Start from normalized defaults.
	# 3. For each action, read stored value with default fallback.
	# 4. Normalize stored value and replace empty results with fallback.
	# 5. Return merged bindings.
	var local_cfg := cfg
	if local_cfg == null:
		local_cfg = ConfigFile.new()
		local_cfg.load(SETTINGS_FILE_PATH)

	var out = get_default_bindings()
	for action_any in ACTIONS:
		var action = str(action_any)
		var fallback = out.get(action, [])
		# Missing key or legacy format both fall back to sane defaults.
		var stored = local_cfg.get_value(KEYBINDS_SECTION, action, fallback)
		var codes = normalize_codes(stored)
		if codes.is_empty():
			codes = normalize_codes(fallback)
		out[action] = codes
	return out

static func save_bindings_to_config(cfg: ConfigFile, bindings: Dictionary) -> void:
	# Inputs:
	# - `cfg`: Target `ConfigFile` to write into.
	# - `bindings`: Action -> keycode list map to persist.
	# Outputs: none
	# Execution timing: Called when user confirms/apply keybind changes.
	# Steps:
	# 1. Exit early if config object is missing.
	# 2. Iterate all known actions.
	# 3. Normalize incoming values with defaults fallback.
	# 4. Write each action to `KEYBINDS_SECTION`.
	if cfg == null:
		return
	for action_any in ACTIONS:
		var action = str(action_any)
		cfg.set_value(KEYBINDS_SECTION, action, normalize_codes(bindings.get(action, DEFAULT_BINDINGS.get(action, []))))

static func apply_bindings(bindings: Dictionary) -> void:
	# Inputs:
	# - `bindings`: Action -> keycode list map to apply to `InputMap`.
	# Outputs: none
	# Execution timing: Called after loading settings or rebinding controls in UI.
	# Steps:
	# 1. Ensure all actions exist.
	# 2. For each action, normalize provided keycodes.
	# 3. If empty, replace with normalized defaults.
	# 4. Replace action events via `set_action_keycodes()`.
	# Hard reset + rebuild prevents stale events from old bindings.
	ensure_default_actions()
	for action_any in ACTIONS:
		var action = str(action_any)
		var codes = normalize_codes(bindings.get(action, DEFAULT_BINDINGS.get(action, [])))
		if codes.is_empty():
			codes = normalize_codes(DEFAULT_BINDINGS.get(action, []))
		set_action_keycodes(action, codes)

static func set_action_keycodes(action: String, codes: Array) -> void:
	# Inputs:
	# - `action`: Input action name.
	# - `codes`: Raw or normalized keycode values.
	# Outputs: none
	# Execution timing: Called by defaults setup and keybind apply operations.
	# Steps:
	# 1. Ensure action exists in `InputMap`.
	# 2. Remove all old events for the action.
	# 3. Normalize incoming codes.
	# 4. Create `InputEventKey` for each code and add it to the action.
	var action_name = StringName(action)
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	# Full erase avoids mixed old/new keybind states after rebinding.
	InputMap.action_erase_events(action_name)
	for code_any in normalize_codes(codes):
		var event := InputEventKey.new()
		event.keycode = int(code_any) as Key
		InputMap.action_add_event(action_name, event)

static func get_action_keycodes(action: String) -> Array:
	# Inputs:
	# - `action`: Input action name.
	# Outputs:
	# - `Array`: Unique positive keycodes currently assigned to the action.
	# Execution timing: Called by UI display and input matching helpers.
	# Steps:
	# 1. Ensure default actions exist before reading.
	# 2. Iterate all events assigned to the action.
	# 3. Keep only `InputEventKey` entries.
	# 4. Extract keycodes and return deduplicated list.
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
	# Inputs:
	# - `action`: Input action name.
	# - `bindings`: Optional action -> keycode map override.
	# Outputs:
	# - `String`: Human-readable key text (e.g. `W / Up`) or `Unbound`.
	# Execution timing: Called when rendering controls UI labels.
	# Steps:
	# 1. Resolve source codes from provided `bindings` or live `InputMap`.
	# 2. Return `Unbound` if no codes are available.
	# 3. Convert each keycode to display name via `OS.get_keycode_string()`.
	# 4. Join names with ` / ` separator and return the label.
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
	# Inputs:
	# - `event`: Incoming input event.
	# - `action`: Action name to test against.
	# Outputs:
	# - `bool`: `true` when event is a pressed non-echo key bound to action.
	# Execution timing: Called from gameplay/menu input handlers.
	# Steps:
	# 1. Reject non-key events.
	# 2. Reject key release and key-repeat events.
	# 3. Compare event keycode to action keycodes.
	# 4. Return `true` on first match, else `false`.
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	# Ignore key release and autorepeat so gameplay reacts only once per press.
	if not key_event.pressed or key_event.echo:
		return false
	for code_any in get_action_keycodes(action):
		if int(code_any) == int(key_event.keycode):
			return true
	return false

static func bindings_equal(a: Dictionary, b: Dictionary) -> bool:
	# Inputs:
	# - `a`: First bindings dictionary.
	# - `b`: Second bindings dictionary.
	# Outputs:
	# - `bool`: `true` when all known actions have equal normalized keycodes.
	# Execution timing: Called to detect unsaved changes or avoid unnecessary writes.
	# Steps:
	# 1. Iterate all known actions.
	# 2. Normalize codes from both dictionaries for each action.
	# 3. Return `false` immediately on first mismatch.
	# 4. Return `true` only if every action matches.
	for action_any in ACTIONS:
		var action = str(action_any)
		if normalize_codes(a.get(action, [])) != normalize_codes(b.get(action, [])):
			return false
	return true

