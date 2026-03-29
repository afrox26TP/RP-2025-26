extends Camera2D

signal zoom_zmenen(aktualni_zoom)

@export var speed = 1000.0
@export var zoom_speed = 0.1
@export var min_zoom = 0.05
@export var max_zoom = 4.0

var drag_start = Vector2.ZERO
var dragging = false

func _process(delta):
	# Handle keyboard movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input_dir.y -= 1
	
	position += input_dir.normalized() * speed * delta * (1.0 / zoom.x)

func _unhandled_input(event):
	# Handle mouse input for zooming and panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _is_hovering_scrollable_ui():
				_zoom_camera(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not _is_hovering_scrollable_ui():
				_zoom_camera(1.0 - zoom_speed)
			
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging = true
				drag_start = get_viewport().get_mouse_position()
			else:
				dragging = false

	if event is InputEventMouseMotion and dragging:
		var drag_current = get_viewport().get_mouse_position()
		var diff = (drag_start - drag_current) * (1.0 / zoom.x)
		position += diff
		drag_start = drag_current

func _is_hovering_scrollable_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		# Scroll containers should keep mouse wheel for their own content.
		if hovered is ScrollContainer:
			return true
		hovered = hovered.get_parent() as Control
	return false

func _zoom_camera(factor):
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	# Broadcast the new zoom level to other game systems
	zoom_zmenen.emit(zoom.x)
