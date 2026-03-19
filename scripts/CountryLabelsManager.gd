extends Node2D

# Načteme tvou připravenou scénu
@export var label_scene: PackedScene = preload("res://scenes/CountryLabel.tscn")

# Limit pro zobrazení vlajky místo textu
@export var min_velikost_pro_text: float = 250.0 

var aktivni_labely: Dictionary = {}

func aktualizuj_labely_statu(all_provinces: Dictionary, prov_labels_node: Node2D):
	var staty_data = {} 
	
	# 1. Posbírám pozice všech provincií podle vlastníka
	for child in prov_labels_node.get_children():
		var p_id = int(child.get("province_id"))
		if all_provinces.has(p_id):
			var owner = str(all_provinces[p_id].get("owner", ""))
			if owner == "SEA" or owner == "": continue
			
			if not staty_data.has(owner):
				staty_data[owner] = {
					"body": [], 
					"jmeno": all_provinces[p_id].get("country_name", owner)
				}
			staty_data[owner]["body"].append(child.global_position)
			
	# 2. Najdu střed a velikost (Bounding Box)
	var existujici_vlastnici = []
	for owner in staty_data.keys():
		existujici_vlastnici.append(owner)
		var body = staty_data[owner]["body"]
		
		var min_p = body[0]
		var max_p = body[0]
		
		for pt in body:
			min_p.x = min(min_p.x, pt.x)
			min_p.y = min(min_p.y, pt.y)
			max_p.x = max(max_p.x, pt.x)
			max_p.y = max(max_p.y, pt.y)
			
		var stred = (min_p + max_p) / 2.0
		var velikost_statu = min_p.distance_to(max_p) 
		
		_vykresli_label(owner, staty_data[owner]["jmeno"], stred, velikost_statu)
		
	# 3. Úklid dobytých států
	var znicene_staty = []
	for owner in aktivni_labely.keys():
		if not owner in existujici_vlastnici:
			aktivni_labely[owner].queue_free()
			znicene_staty.append(owner)
			
	for zniceny in znicene_staty:
		aktivni_labely.erase(zniceny)

func _vykresli_label(tag: String, jmeno: String, pozice: Vector2, velikost: float):
	var inst
	# Pokud štítek ještě neexistuje, vytvořím instanci tvé scény
	if not aktivni_labely.has(tag):
		inst = label_scene.instantiate()
		add_child(inst)
		aktivni_labely[tag] = inst
	else:
		inst = aktivni_labely[tag]

	inst.global_position = pozice
	
	# Sáhnu si pro tvoje uzly uvnitř tvé scény
	var lbl = inst.get_node("Label")
	var flag = inst.get_node_or_null("Flag")
	
	lbl.text = jmeno
	
	# Přepínání Text vs. Vlajka podle velikosti státu
	if velikost < min_velikost_pro_text:
		lbl.hide()
		if flag:
			flag.show()
			# Zkusím načíst vlajku (uprav si cestu podle toho, kde máš obrázky vlajek)
			var cesta = "res://external assets/Flags/%s.svg" % tag
			if ResourceLoader.exists(cesta):
				flag.texture = load(cesta)
	else:
		lbl.show()
		if flag: 
			flag.hide()
