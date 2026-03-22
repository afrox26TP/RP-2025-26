extends Node

signal kolo_zmeneno 

var hrac_stat = "ALB" 
var hrac_jmeno = "" 
var hrac_ideologie = "" 

var statni_kasa: float = 1000.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

var map_data: Dictionary = {}
var provincie_cooldowny: Dictionary = {}
var ai_kasy: Dictionary = {} 

var zpracovava_se_tah: bool = false

# --- HELPER FUNCTION: Safely find the map node ---
func _get_map_loader():
	var map_loader = get_tree().current_scene
	if map_loader and map_loader.has_method("zpracuj_tah_armad"):
		return map_loader
	if map_loader:
		var child_map = map_loader.find_child("Map", true, false)
		if child_map and child_map.has_method("zpracuj_tah_armad"):
			return child_map
	return null

func spocitej_prijem(all_provinces: Dictionary):
	map_data = all_provinces 
	var celkove_hdp = 0.0
	var celkem_vojaku = 0
	
	for p_id in map_data:
		var p = map_data[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			if hrac_jmeno == "":
				hrac_jmeno = str(p.get("country_name", ""))
				hrac_ideologie = str(p.get("ideology", ""))
			
			celkove_hdp += float(p.get("gdp", 0.0))
			celkem_vojaku += int(p.get("soldiers", 0))
			
	var prijem_z_hdp = celkove_hdp * 0.05
	var naklady_na_vojaky = celkem_vojaku * 0.005
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	
	print("HDP Příjem: %.2f | Výdaje Armáda: %.2f | Čistý zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	kolo_zmeneno.emit()

func ukonci_kolo():
	if zpracovava_se_tah: return 
	zpracovava_se_tah = true

	# --- FIX: Use the bulletproof map finder ---
	var map_loader = _get_map_loader()
	
	if map_loader:
		# Process battles from the LAST turn and delete old ghosts
		await map_loader.zpracuj_tah_armad()
	else:
		print("CRITICAL ERROR: GameManager cannot find the Map to process battles!")

	statni_kasa += celkovy_prijem
	aktualni_kolo += 1
	
	var hotove_stavby = []
	for prov_id in provincie_cooldowny.keys():
		provincie_cooldowny[prov_id]["zbyva"] -= 1 
		
		if provincie_cooldowny[prov_id]["zbyva"] <= 0:
			hotove_stavby.append(prov_id)
			
	for prov_id in hotove_stavby:
		var typ_budovy = provincie_cooldowny[prov_id]["budova"]
		provincie_cooldowny.erase(prov_id)
		_aplikuj_bonus(prov_id, typ_budovy)

	if not map_data.is_empty():
		spocitej_prijem(map_data)

	# AI plans NEW moves and spawns NEW ghosts
	zpracuj_tah_ai()

	print("--- KOLO %d ---" % aktualni_kolo)
	
	zpracovava_se_tah = false

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	if typ == 0: 
		map_data[prov_id]["gdp"] += 10.0 
	elif typ == 1: 
		map_data[prov_id]["recruitable_population"] += 1000 

# --- PLAYER ACTIONS ---

func hrac_verbuje(provincie_id: int, pocet: int) -> bool:
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): 
		return false
	
	var d = map_data[provincie_id]
	
	if str(d.get("owner", "")).strip_edges().to_upper() != hrac_stat:
		print("VERBOVÁNÍ CHYBA: Tohle není tvoje provincie!")
		return false
		
	var cena_za_vojaka = 0.05
	var celkova_cena = pocet * cena_za_vojaka
	
	if statni_kasa >= celkova_cena:
		var dostupni_rekruti = int(d.get("recruitable_population", 0))
		if dostupni_rekruti >= pocet:
			statni_kasa -= celkova_cena
			d["recruitable_population"] -= pocet
			d["soldiers"] += pocet
			
			map_loader.aktualizuj_ikony_armad()
			print("VERBOVÁNÍ: Naverbováno %d vojáků za %.2f. Zbývá ti %.2f peněz." % [pocet, celkova_cena, statni_kasa])
			kolo_zmeneno.emit() 
			return true
		else:
			print("VERBOVÁNÍ CHYBA: V provincii není dost lidí k naverbování!")
			return false
	else:
		print("VERBOVÁNÍ CHYBA: Nemáš prachy! Potřebuješ %.2f, máš %.2f." % [celkova_cena, statni_kasa])
		return false

# --- THE BRAIN OF THE AI (ROBUST VERSION) ---

func zpracuj_tah_ai():
	print("--- AI THINKING START ---")
	
	var map_loader = _get_map_loader()
		
	if not map_loader:
		print("AI ERROR: Map node not found!")
		return
		
	if map_data.is_empty():
		print("AI ERROR: map_data is empty! The AI has no map to read.")
		return
		
	var cena_za_vojaka = 0.05
	var ai_prijmy = {}
	var pocet_akci = 0 
	
	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		
		if owner == hrac_stat or owner == "SEA": continue
		
		if not ai_kasy.has(owner): ai_kasy[owner] = 1000.0 
		if not ai_prijmy.has(owner): ai_prijmy[owner] = 0.0
		
		var gdp = float(d.get("gdp", 0.0))
		var vojaci = int(d.get("soldiers", 0))
		ai_prijmy[owner] += (gdp * 0.05) - (vojaci * 0.005)

	for ai_tag in ai_prijmy:
		ai_kasy[ai_tag] += max(0, ai_prijmy[ai_tag]) 

	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == hrac_stat or owner == "SEA": continue
		
		var kasa = ai_kasy[owner]
		
		# A) RECRUITMENT LOGIC
		var rekruti = int(d.get("recruitable_population", 0))
		if rekruti > 500 and kasa > 50.0:
			var pocet_k_verbovani = min(rekruti, int(kasa / cena_za_vojaka))
			pocet_k_verbovani = min(pocet_k_verbovani, 1500) 
			
			if pocet_k_verbovani > 0:
				d["recruitable_population"] -= pocet_k_verbovani
				d["soldiers"] += pocet_k_verbovani
				ai_kasy[owner] -= (pocet_k_verbovani * cena_za_vojaka)
				print("AI VERBUJE: %s naverboval %d vojáků v provincii %d" % [owner, pocet_k_verbovani, p_id])
				pocet_akci += 1

		# B) ATTACK LOGIC
		var vojaci = int(d.get("soldiers", 0))
		if vojaci > 1500: 
			var sousedi = d.get("neighbors", [])
			var best_target = -1
			var weakest_defense = 9999999
			
			for n_id in sousedi:
				if map_data.has(n_id):
					var n_prov = map_data[n_id]
					var n_owner = str(n_prov.get("owner", "")).strip_edges().to_upper()
					
					if n_owner != owner and n_owner != "SEA":
						var n_vojaci = int(n_prov.get("soldiers", 0))
						
						if vojaci >= (n_vojaci * 1.5) and n_vojaci < weakest_defense:
							weakest_defense = n_vojaci
							best_target = n_id
							
			if best_target != -1:
				var utocnici = int(vojaci * 0.8) 
				print(" AI ÚTOK: %s posílá %d vojáků z provincie %d na provincii %d!" % [owner, utocnici, p_id, best_target])
				map_loader.zaregistruj_presun_armady(p_id, best_target, utocnici)
				pocet_akci += 1
				
	print("--- AI THINKING END (Provedeno akcí: %d) ---" % pocet_akci)
