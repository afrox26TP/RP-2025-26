extends Node2D

@export var label_scene: PackedScene = preload("res://scenes/CountryLabel.tscn")
@export var min_velikost_pro_text: float = 85.0 

var aktivni_labely: Dictionary = {}

func aktualizuj_labely_statu(all_provinces: Dictionary, prov_labels_node: Node2D):
	var staty_data = {} 
	
	for child in prov_labels_node.get_children():
		var p_id = int(child.get("province_id"))
		if all_provinces.has(p_id):
			var owner = str(all_provinces[p_id].get("owner", ""))
			if owner == "SEA" or owner == "": continue
			
			if not staty_data.has(owner):
				staty_data[owner] = {
					"body": [], 
					"jmeno": all_provinces[p_id].get("country_name", owner),
					# NOVÉ: Vytáhnu si rovnou i ideologii státu z první provincie
					"ideologie": str(all_provinces[p_id].get("ideology", "")) 
				}
			staty_data[owner]["body"].append(child.global_position)
			
	var existujici_vlastnici = []
	for owner in staty_data.keys():
		existujici_vlastnici.append(owner)
		var body = staty_data[owner]["body"]
		
		var min_p = body[0]
		var max_p = body[0]
		var sum_pos = Vector2.ZERO # NOVÉ: sem budeme sčítat všechny pozice
		
		for pt in body:
			min_p.x = min(min_p.x, pt.x)
			min_p.y = min(min_p.y, pt.y)
			max_p.x = max(max_p.x, pt.x)
			max_p.y = max(max_p.y, pt.y)
			
			sum_pos += pt # NOVÉ: přičtu pozici každé jednotlivé provincie
			
		# NOVÉ: Těžiště (průměr). Většina bodů je na pevnině, takže to text stáhne tam!
		var stred = sum_pos / float(body.size())
		
		# Velikost státu (pro schování textu) necháme počítat z extrémů
		var velikost_statu = min_p.distance_to(max_p) 
		
		_vykresli_label(owner, staty_data[owner]["jmeno"], stred, velikost_statu, staty_data[owner]["ideologie"])
		
	var znicene_staty = []
	for owner in aktivni_labely.keys():
		if not owner in existujici_vlastnici:
			aktivni_labely[owner].queue_free()
			znicene_staty.append(owner)
			
	for zniceny in znicene_staty:
		aktivni_labely.erase(zniceny)

# Přidal jsem parametr ideologie
func _vykresli_label(tag: String, jmeno: String, pozice: Vector2, velikost: float, ideologie: String):
	var inst
	if not aktivni_labely.has(tag):
		inst = label_scene.instantiate()
		add_child(inst)
		aktivni_labely[tag] = inst
	else:
		inst = aktivni_labely[tag]

	inst.global_position = pozice
	
	var lbl = inst.get_node("Label")
	var flag = inst.get_node_or_null("Flag")
	
	lbl.text = jmeno
	
	# ZMĚNA: Tady to teď celé zjednodušíme
	if velikost < min_velikost_pro_text:
		# Je to prcek -> schováme text státu i velkou vlajku.
		# Zastoupí to hlavní město, které má vlastní malou vlaječku a název.
		lbl.hide()
		if flag:
			flag.hide()
	else:
		# Je to velký stát -> ukážeme jen obří nápis, vlajku schováme
		lbl.show()
		if flag: 
			flag.hide()
