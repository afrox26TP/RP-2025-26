extends Camera2D

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

func _ready() -> void:
	_nacti_ovladani_ze_settings()

func _process(delta):
	# Handle keyboard movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if input_dir == Vector2.ZERO:
		return

	if input_dir.x != 0.0 and input_dir.y != 0.0:
		input_dir = input_dir.normalized()

	position += input_dir * speed * delta * (1.0 / zoom.x)

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
func _is_hovering_any_ui_blocking_camera() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		# Block camera only for HUD/menus in CanvasLayer, not map labels placed in world.
		if hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and _is_canvas_layer_ui_control(hovered):
			return true
		hovered = hovered.get_parent() as Control
	return false

func _is_canvas_layer_ui_control(ctrl: Control) -> bool:
	var node: Node = ctrl
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false

func _zoom_camera(factor):
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	# Broadcast the new zoom level to other game systems
	zoom_zmenen.emit(zoom.x)

func _nacti_ovladani_ze_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) != OK:
		return

	speed = float(cfg.get_value("controls", "camera_speed", speed))
	zoom_speed = clamp(float(cfg.get_value("controls", "zoom_speed", zoom_speed)), 0.01, 0.6)
	invert_zoom_wheel = bool(cfg.get_value("controls", "invert_zoom", invert_zoom_wheel))
