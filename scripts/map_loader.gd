extends Node2D
# Pridej k ostatnim promennym nahoře
@onready var camera = get_node("../Camera2D") # Uprav cestu ke kamere
@onready var label_container = $ProvinceLabels

func _process(_delta):
	_aktualizuj_viditelnost_labelu()

func _aktualizuj_viditelnost_labelu():
	if not camera or not label_container: return
	
	var zoom_level = camera.zoom.x
	
	# PRAVIDLA PRO VIDITELNOST:
	# Zoom > 0.8: Vidim provincie
	# Zoom < 0.8: Vidim jen staty (zatim schovame vse krom hlavnich mest)
	
	for lbl in label_container.get_children():
		var data = provinces.get(lbl.province_id)
		if not data: continue
		
		# Logika pro zoom
		if zoom_level > 0.8:
			lbl.visible = true
			# Zde muzes pridat podminku: if not d.is_capital: lbl.visible = true
		else:
			# Schovame vse, co neni hlavni mesto (pokud mas v TXT info o hlavnim meste)
			lbl.visible = false
@export var label_scene = preload("res://scenes/ProvinceLabel.tscn")

var provinces = {}
var color_cache = {}

func _ready():
	load_provinces()
	print("Nacteno provincii z TXT: ", provinces.size())
	
	var sprite = $Sprite2D
	if sprite and sprite.has_method("aktualizuj_mapovy_mod"):
		sprite.aktualizuj_mapovy_mod("political", provinces)
	
	# spustime generovani popisku
	generuj_nazvy_provincii()

func load_provinces():
	var file = FileAccess.open("res://map_data/Provinces.txt", FileAccess.READ)
	if file == null:
		push_error("Chybi soubor Provinces.txt!")
		return
		
	file.get_line()
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
			
		var parts = line.split(";")
		if parts.size() < 11: continue 
			
		var prov_id = int(parts[0])
		
		var pop = 0
		var gdp_val = 0.0
		if parts.size() > 12: pop = int(parts[12])
		if parts.size() > 13: gdp_val = float(parts[13])
		
		provinces[prov_id] = {
			"id": prov_id,
			"color": Color8(int(parts[1]), int(parts[2]), int(parts[3])),
			"type": parts[4],
			"state": parts[5],
			"owner": parts[6],
			"x": float(parts[8]), # pridano
			"y": float(parts[9]), # pridano
			"province_name": parts[10], # pridano
			"population": pop,
			"gdp": gdp_val
		}

func generuj_nazvy_provincii():
	var label_container = Node2D.new()
	label_container.name = "ProvinceLabels"
	add_child(label_container)
	
	var sprite = $Sprite2D
	# vypocet offsetu, pokud je mapa centrovana (sprite.centered)
	var offset = Vector2.ZERO
	if sprite and sprite.centered:
		offset = sprite.position - (sprite.texture.get_size() / 2.0)
	elif sprite:
		offset = sprite.position

	for id in provinces:
		var d = provinces[id]
		
		if d.owner == "SEA" or d.province_name == "":
			continue
			
		var lbl_inst = label_scene.instantiate()
		label_container.add_child(lbl_inst)
		
		# v ProvinceLabel.tscn musi byt uzel Label
		var l = lbl_inst.get_node("Label")
		if l:
			l.text = d.province_name
		
		# nastaveni pozice s ohledem na souradnice v txt a pozici mapy
		lbl_inst.position = Vector2(d.x, d.y) + offset

func get_province_data_by_color(clicked_color: Color):
	var hex = clicked_color.to_html(false)
	
	if color_cache.has(hex):
		return provinces[color_cache[hex]]
		
	var v_clicked = Vector3(clicked_color.r, clicked_color.g, clicked_color.b)
	
	for id in provinces:
		var c = provinces[id]["color"]
		var v_prov = Vector3(c.r, c.g, c.b)
		
		if v_prov.distance_to(v_clicked) < 0.02:
			color_cache[hex] = id
			return provinces[id]
			
	return null
