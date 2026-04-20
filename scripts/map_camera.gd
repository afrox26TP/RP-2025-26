# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Camera2D
# this script drives a specific gameplay/UI area and keeps related logic together.

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

# Initializes references, connects signals, and prepares default runtime state.
func _ready() -> void:
	ControlsConfig.ensure_default_actions()
	_nacti_ovladani_ze_settings()

# Per-frame runtime logic.
func _process(delta):
	# Handle keyboard movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_RIGHT): input_dir.x += 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_LEFT): input_dir.x -= 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_DOWN): input_dir.y += 1
	if Input.is_action_pressed(ControlsConfig.ACTION_CAMERA_UP): input_dir.y -= 1
	if input_dir == Vector2.ZERO:
		return

	if input_dir.x != 0.0 and input_dir.y != 0.0:
		input_dir = input_dir.normalized()

	position += input_dir * speed * delta * (1.0 / zoom.x)

# Input event handler for this node.
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
		var diff = (drag_start - drag_current) * (1.0 / zoom.x)
		position += diff
		drag_start = drag_current

# Prevent camera stealing input when mouse is above menus/HUD.
# Boolean check for required state.
func _is_hovering_any_ui_blocking_camera() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		# Block camera only for HUD/menus in CanvasLayer, not map labels placed in world.
		if hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and _is_canvas_layer_ui_control(hovered):
			return true
		hovered = hovered.get_parent() as Control
	return false

# Returns true when conditions are met.
func _is_canvas_layer_ui_control(ctrl: Control) -> bool:
	var node: Node = ctrl
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false

# Runs the local feature logic.
func _zoom_camera(factor):
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	# Broadcast the new zoom level to other game systems
	zoom_zmenen.emit(zoom.x)

# Pulls data and verifies parse output.
func _nacti_ovladani_ze_settings() -> void:
	ControlsConfig.apply_bindings(ControlsConfig.load_bindings_from_config())
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return

	speed = float(cfg.get_value("controls", "camera_speed", speed))
	zoom_speed = clamp(float(cfg.get_value("controls", "zoom_speed", zoom_speed)), 0.01, 0.6)
	invert_zoom_wheel = bool(cfg.get_value("controls", "invert_zoom", invert_zoom_wheel))



