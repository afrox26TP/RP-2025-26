extends Sprite2D

@export var logic_map: Texture2D # SEM V INSPECTORU HOĎ ProvinceMap.png
var map_image: Image

func _ready():
	if logic_map:
		map_image = logic_map.get_image()
	else:
		push_error("Nezapomeň přiřadit Logic Map v Inspectoru!")
	
	material.set_shader_parameter("has_hover", false)
	material.set_shader_parameter("has_selected", false)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		_zpracuj_interakci(event.position, false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_zpracuj_interakci(event.position, true)

func _zpracuj_interakci(mouse_pos: Vector2, je_kliknuti: bool):
	if map_image == null:
		return 
	
	# Přepočet na lokální souřadnice (bere v potaz kameru i zoom)
	var local_pos = to_local(get_global_mouse_position())
	
	# Korekce, pokud je zapnutý "Centered" u Sprite2D
	if centered:
		local_pos += texture.get_size() / 2.0
	
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	
	if rect.has_point(local_pos):
		var pixel_pos = Vector2i(local_pos)
		var pixel_color = map_image.get_pixelv(pixel_pos)
		
		if pixel_color.a > 0.0:
			var shader_color = Vector3(pixel_color.r, pixel_color.g, pixel_color.b)
			
			if je_kliknuti:
				# 1. Změna barvy v shaderu (výběr)
				material.set_shader_parameter("selected_color", shader_color)
				material.set_shader_parameter("has_selected", true)
				
				# 2. Získání dat z loaderu
				var map_root = get_parent()
				if map_root.has_method("get_province_data_by_color"):
					var data = map_root.get_province_data_by_color(pixel_color)
					
					if data:
						print("--- Provincie Nalezena ---")
						print("ID: ", data["id"], " | Vlastník: ", data["owner"])
						
						# --- NOVÁ ČÁST PRO UI ---
						# Najdeme InfoUI uzel kdekoli v aktuální scéně
						var ui = get_tree().current_scene.find_child("InfoUI", true, false)
						if ui and ui.has_method("zobraz_data"):
							ui.zobraz_data(data)
						# ------------------------
					else:
						print("Nenalezeno v TXT. Myš vidí RGB: ", 
							int(pixel_color.r*255), ",", 
							int(pixel_color.g*255), ",", 
							int(pixel_color.b*255))
			else:
				# Hover efekt (žlutá)
				material.set_shader_parameter("hover_color", shader_color)
				material.set_shader_parameter("has_hover", true)
		else:
			material.set_shader_parameter("has_hover", false)
	else:
		material.set_shader_parameter("has_hover", false)
