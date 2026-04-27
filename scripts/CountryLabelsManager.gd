# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Node2D
# this script drives a specific gameplay/UI area and keeps related logic together.

# Builds one strategic label per state from province label positions.
# Hard part: center is computed from all owned province points so labels stay readable
# even for fragmented countries.

@export var label_scene: PackedScene = preload("res://scenes/CountryLabel.tscn")
@export var min_velikost_pro_text: float = 85.0 

var aktivni_labely: Dictionary = {}
var potato_mode_enabled: bool = false

# Applies updates and syncs dependent state.
func nastav_potato_mode(enabled: bool) -> void:
	potato_mode_enabled = enabled
	visible = not enabled
	if enabled:
		for key in aktivni_labely.keys():
			var lbl = aktivni_labely[key]
			if lbl:
				lbl.queue_free()
		aktivni_labely.clear()

# Updates derived state and UI.
func aktualizuj_labely_statu(all_provinces: Dictionary, prov_labels_node: Node2D):
	# Rebuild visible state labels each refresh and remove dead entries.
	if potato_mode_enabled:
		return

	var staty_data = {} 
	
	for child in prov_labels_node.get_children():
		var p_id = int(child.get("province_id"))
		if all_provinces.has(p_id):
			var owner_tag = str(all_provinces[p_id].get("owner", ""))
			if owner_tag == "SEA" or owner_tag == "": continue
			
			if not staty_data.has(owner_tag):
				staty_data[owner_tag] = {
					"body": [], 
					"jmeno": all_provinces[p_id].get("country_name", owner_tag),
					# Extract ideology from the first valid province
					"ideologie": str(all_provinces[p_id].get("ideology", "")) 
				}
			staty_data[owner_tag]["body"].append(child.global_position)
			
	var existujici_vlastnici = []
	for owner_tag in staty_data.keys():
		existujici_vlastnici.append(owner_tag)
		var body = staty_data[owner_tag]["body"]
		
		var min_p = body[0]
		var max_p = body[0]
		var sum_pos = Vector2.ZERO # Sum of all province positions
		
		for pt in body:
			min_p.x = min(min_p.x, pt.x)
			min_p.y = min(min_p.y, pt.y)
			max_p.x = max(max_p.x, pt.x)
			max_p.y = max(max_p.y, pt.y)
			
			sum_pos += pt
			
		# Center of mass (average position). Pulls the label towards the largest landmass.
		var stred = sum_pos / float(body.size())
		
		# Country size based on bounding box extremes (used for visibility checks)
		var velikost_statu = min_p.distance_to(max_p) 
		
		_vykresli_label(owner_tag, staty_data[owner_tag]["jmeno"], stred, velikost_statu, staty_data[owner_tag]["ideologie"])
		
	var znicene_staty = []
	# Remove labels for states that no longer own any province this refresh.
	for owner_tag in aktivni_labely.keys():
		if not owner_tag in existujici_vlastnici:
			aktivni_labely[owner_tag].queue_free()
			znicene_staty.append(owner_tag)
			
	for zniceny in znicene_staty:
		aktivni_labely.erase(zniceny)

# Navrh teto funkce vznikl s podporou AI, nasledne byl upraven a integrovan mnou.  # [_vykresli_label]
# Ai generated or editted start (priloha_a.txt)
func _vykresli_label(tag: String, jmeno: String, pozice: Vector2, velikost: float, _ideologie: String):
	var inst
	if not aktivni_labely.has(tag):
		# Reuse existing label nodes when possible to avoid allocation churn.
		inst = label_scene.instantiate()
		add_child(inst)
		aktivni_labely[tag] = inst
	else:
		inst = aktivni_labely[tag]

	inst.global_position = pozice
	
	var lbl = inst.get_node("Label")
	var flag = inst.get_node_or_null("Flag")
	if lbl and lbl is Control:
		(lbl as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flag and flag is Control:
		(flag as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	lbl.text = jmeno
	
	if velikost < min_velikost_pro_text:
		# Micro-state: Hide the big country name and flag. 
		# The capital city label will represent it instead to prevent visual clutter.
		lbl.hide()
		if flag:
			flag.hide()
	else:
		# Large state: Show country name, hide the flag.
		lbl.show()
		if flag: 
			flag.hide()



# Ai generated or editted end (priloha_a.txt)

