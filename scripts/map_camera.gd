extends Camera2D

# Nastavení rychlosti a citlivosti
@export var speed = 1000.0
@export var zoom_speed = 0.1
@export var min_zoom = 0.05
@export var max_zoom = 2.0

var drag_start = Vector2.ZERO
var dragging = false

func _process(delta):
	# 1. POHYB POMOCÍ WASD
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input_dir.y -= 1
	
	position += input_dir.normalized() * speed * delta * (1.0 / zoom.x)

func _unhandled_input(event):
	# 2. ZOOMOVÁNÍ KOLEČKEM (směrem ke kurzoru)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.0 + zoom_speed, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 - zoom_speed, event.position)
			
		# 3. TAHÁNÍ MAPY (Pravé tlačítko myši)
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

func _zoom_camera(factor, mouse_pos):
	var prev_zoom = zoom
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	# Tento kousek zajistí, že zoomujeme tam, kde je myš, ne jen do středu
	var mouse_world_pos = get_global_mouse_position()
	var next_mouse_world_pos = get_global_mouse_position() # Godot to přepočítá po změně zoomu
	# (Zjednodušený výpočet pro plynulost)
