# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Camera2D
# this script drives a specific gameplay/UI area and keeps related logic together.

# Camera input layer (keyboard move, wheel zoom, RMB drag).
# Hard part: camera must ignore input when cursor is over HUD controls,
# otherwise map movement fights with UI interactions.

const ControlsConfig = preload("res://scripts/ControlsConfig.gd")

# Camera script is intentionally simple: keyboard move, wheel zoom, RMB drag.
signal zoom_zmenen(aktualni_zoom)

@export var speed = 1000.0
@export var zoom_speed = 0.1
@export var min_zoom = 0.05
@export var max_zoom = 4.0
const SETTINGS_FILE_PATH := "user://settings.cfg"

var drag_start = Vector2.ZERO
var dragging = false
var invert_zoom_wheel: bool = false
var _game_ui_cache: Node = null

# Inputs:
# - none
# Outputs:
# - none; initializes camera input action bindings and loads camera control settings
# Execution timing:
# - Called once when camera node enters scene tree.
# Steps:
# - Ensure default input actions exist.
# - Load camera speed/zoom settings from config.
func _ready() -> void:
	ControlsConfig.ensure_default_actions()
	_nacti_ovladani_ze_settings()

# Inputs:
# - delta: frame time in seconds
# Outputs:
# - none; updates camera position from keyboard input when movement is allowed
# Execution timing:
# - Called every frame.
# Steps:
# - Skip when UI currently blocks keyboard camera movement.
# - Build movement vector from configured camera actions.
# - Normalize diagonal input and move camera with zoom-compensated speed.
func _process(delta):
	if _blokuje_kamerovy_pohyb_klavesami():
		return

	# Handle keyboard movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_RIGHT): input_dir.x += 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_LEFT): input_dir.x -= 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_DOWN): input_dir.y += 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_UP): input_dir.y -= 1
	if input_dir == Vector2.ZERO:
		return

	if input_dir.x != 0.0 and input_dir.y != 0.0:
		# Normalize diagonal movement so it is not faster than straight movement.
		input_dir = input_dir.normalized()

	position += input_dir * speed * delta * (1.0 / zoom.x)


# Inputs:
# - none
# Outputs:
# - bool: true when camera keyboard movement should be blocked by focused UI state
# Execution timing:
# - Called each frame before processing keyboard camera movement.
# Steps:
# - Block movement when focused control belongs to CanvasLayer UI.
# - Ask GameUI whether hotkeys/movement should be blocked by modal UI.
func _blokuje_kamerovy_pohyb_klavesami() -> bool:
	# If keyboard focus is inside CanvasLayer UI, do not move camera.
	var focused = get_viewport().gui_get_focus_owner()
	if focused and _is_canvas_layer_ui_control(focused):
		return true

	var game_ui = _ziskej_game_ui_node()
	if game_ui and game_ui.has_method("blokuje_hotkey_ukonceni_tahu"):
		return bool(game_ui.blokuje_hotkey_ukonceni_tahu())
	return false


# Inputs:
# - none
# Outputs:
# - Node|null: cached GameUI node if present in current scene
# Execution timing:
# - Utility used by camera movement block checks.
# Steps:
# - Return cached valid node when available.
# - Resolve GameUI from parent once and cache it.
func _ziskej_game_ui_node() -> Node:
	if _game_ui_cache != null and is_instance_valid(_game_ui_cache):
		return _game_ui_cache
	var root = get_parent()
	if root:
		_game_ui_cache = root.get_node_or_null("GameUI")
	return _game_ui_cache

# Inputs:
# - event: input event delivered to camera node
# Outputs:
# - none; handles wheel zoom and right-mouse drag panning when not over blocking UI
# Execution timing:
# - Called on input events for this node.
# Steps:
# - Process wheel-up/down zoom with optional inverted behavior.
# - Start/stop RMB dragging.
# - Apply drag delta scaled by current zoom.
func _input(event):
	# Handle mouse input for zooming and panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _is_hovering_any_ui_blocking_camera():
				var factor_up = 1.0 - zoom_speed if invert_zoom_wheel else 1.0 + zoom_speed
				_zoom_camera(factor_up)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not _is_hovering_any_ui_blocking_camera():
				var factor_down = 1.0 + zoom_speed if invert_zoom_wheel else 1.0 - zoom_speed
				_zoom_camera(factor_down)
			
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _is_hovering_any_ui_blocking_camera():
					return
				dragging = true
				drag_start = get_viewport().get_mouse_position()
			else:
				dragging = false

	if event is InputEventMouseMotion and dragging:
		var drag_current = get_viewport().get_mouse_position()
		# Scale by zoom so drag feels consistent regardless of current zoom level.
		var diff = (drag_start - drag_current) * (1.0 / zoom.x)
		position += diff
		drag_start = drag_current

# Inputs:
# - none
# Outputs:
# - bool: true when hovered control chain belongs to blocking CanvasLayer UI
# Execution timing:
# - Called before zoom/drag handling.
# Steps:
# - Walk hovered control parents.
# - Return true for non-ignored CanvasLayer UI controls.
func _is_hovering_any_ui_blocking_camera() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		# Block camera only for HUD/menus in CanvasLayer, not map labels placed in world.
		if hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and _is_canvas_layer_ui_control(hovered):
			return true
		hovered = hovered.get_parent() as Control
	return false

# Inputs:
# - ctrl: control node to inspect
# Outputs:
# - bool: true when control is inside any CanvasLayer hierarchy
# Execution timing:
# - Utility for camera input blocking checks.
# Steps:
# - Traverse parent chain from control to root.
# - Detect presence of CanvasLayer ancestor.
func _is_canvas_layer_ui_control(ctrl: Control) -> bool:
	var node: Node = ctrl
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false

# Inputs:
# - factor: multiplicative zoom factor
# Outputs:
# - none; updates camera zoom within limits and emits zoom signal
# Execution timing:
# - Called from mouse-wheel handling.
# Steps:
# - Multiply current zoom by factor.
# - Clamp zoom into min/max bounds.
# - Emit zoom_zmenen signal with resulting scalar zoom.
func _zoom_camera(factor):
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	# Broadcast the new zoom level to other game systems
	zoom_zmenen.emit(zoom.x)

# Inputs:
# - none
# Outputs:
# - none; loads camera controls and keybind settings from configuration file
# Execution timing:
# - Called during _ready and can be called by external refreshers.
# Steps:
# - Apply default keybind set first.
# - Load settings config file when available.
# - Apply camera speed, zoom speed, and invert wheel flag.
func _nacti_ovladani_ze_settings() -> void:
	ControlsConfig.apply_bindings(ControlsConfig.get_default_bindings())
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return

	speed = float(cfg.get_value("controls", "camera_speed", speed))
	zoom_speed = clamp(float(cfg.get_value("controls", "zoom_speed", zoom_speed)), 0.01, 0.6)
	invert_zoom_wheel = bool(cfg.get_value("controls", "invert_zoom", invert_zoom_wheel))



