extends Node

signal kolo_zmeneno 

var hrac_stat = "ALB" 
var hrac_jmeno = "" 
var hrac_ideologie = "" 

# Startujes na 1000.00 (zobrazuje se jako mil. USD)
var statni_kasa: float = 1000.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

var map_data: Dictionary = {}
var provincie_cooldowny: Dictionary = {}
var ai_kasy: Dictionary = {} 

# --- NEW: DIPLOMACIE ---
var valky: Dictionary = {}

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

# --- DIPLOMATICKÉ FUNKCE ---
func jsou_ve_valce(tag1: String, tag2: String) -> bool:
	var klic1 = tag1 + "_" + tag2
	var klic2 = tag2 + "_" + tag1
	return valky.has(klic1) or valky.has(klic2)

func vyhlasit_valku(utocnik: String, obrance: String):
	if jsou_ve_valce(utocnik, obrance): return
	
	var klic = utocnik + "_" + obrance
	valky[klic] = true
	
	var msg = "⚠️ VÁLKA!\n\nStát %s právě vyhlásil válku státu %s!" % [utocnik, obrance]
	print(msg.replace("\n\n", " "))
	
	# Pokud se válka týká hráče, hra se zastaví a ukáže se Popup okno
	if utocnik == hrac_stat or obrance == hrac_stat:
		var map_loader = _get_map_loader()
		if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
			await map_loader._ukaz_bitevni_popup("DIPLOMACIE", msg)

func spocitej_prijem(all_provinces: Dictionary):
	map_data = all_provinces 
	var celkove_hdp = 0.0
	var celkem_vojaku = 0
	
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			if hrac_jmeno == "":
				hrac_jmeno = str(d.get("country_name", ""))
				hrac_ideologie = str(d.get("ideology", ""))
			
			celkove_hdp += float(d.get("gdp", 0.0))
			celkem_vojaku += int(d.get("soldiers", 0))
			
	# Vybalancovany prijem: 10% z HDP minus udrzba armady
	var prijem_z_hdp = celkove_hdp * 0.1
	var naklady_na_vojaky = celkem_vojaku * 0.001
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	
	print("HDP Prijem: %.2f | Vydaje Armada: %.2f | Cisty zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	kolo_zmeneno.emit()

func ukonci_kolo():
	if zpracovava_se_tah: return 
	zpracovava_se_tah = true

	var map_loader = _get_map_loader()
	
	if map_loader:
		# Vyhodnotime bitvy a smazeme duchy
		await map_loader.zpracuj_tah_armad()

	statni_kasa += celkovy_prijem
	
	# BANKROT nastane pri dluhu -100
	if statni_kasa < -100.0:
		await _vyres_bankrot(hrac_stat)

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
		
		# Regenerace populace a rust ekonomiky
		for p_id in map_data:
			var d = map_data[p_id]
			d["recruitable_population"] += 150
			if d["recruitable_population"] > 15000:
				d["recruitable_population"] = 15000
			d["gdp"] += 0.5 # Pasivni rust bohatstvi

	# AI naplanuje nove utoky a vyhlašuje války (přidán await kvůli vyskakovacím oknům)
	await zpracuj_tah_ai()

	print("--- KOLO %d ---" % aktualni_kolo)
	
	if map_loader and map_loader.has_method("aktualizuj_ikony_armad"):
		map_loader.aktualizuj_ikony_armad()
		
	zpracovava_se_tah = false

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	if typ == 0: 
		map_data[prov_id]["gdp"] += 10.0 
	elif typ == 1: 
		map_data[prov_id]["recruitable_population"] += 2000 

# --- BANKRUPTCY LOGIC (Vzpoura pri dluhu) ---
func _vyres_bankrot(tag: String):
	var celkem_dezertovalo = 0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == tag:
			var vojaci = int(d.get("soldiers", 0))
			if vojaci > 0:
				var dezertovalo = int(vojaci * 0.25)
				d["soldiers"] -= dezertovalo
				d["recruitable_population"] += dezertovalo
				celkem_dezertovalo += dezertovalo
				
	if celkem_dezertovalo > 0:
		if tag == hrac_stat:
			var map_loader = _get_map_loader()
			if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
				await map_loader._ukaz_bitevni_popup("STÁTNÍ BANKROT", "Dosly penize! %d vojaku dezertovalo." % celkem_dezertovalo)
		else:
			print("📉 BANKROT AI (%s): %d vojaku dezertovalo." % [tag, celkem_dezertovalo])

# --- PLAYER ACTIONS ---

func hrac_verbuje(provincie_id: int, pocet: int) -> bool:
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return false
	
	var d = map_data[provincie_id]
	if str(d.get("owner", "")).strip_edges().to_upper() != hrac_stat: return false
		
	var cena_za_vojaka = 0.01 # 1000 vojaku stoji 10.00 mil. USD
	var celkova_cena = pocet * cena_za_vojaka
	
	if statni_kasa >= celkova_cena:
		var dostupni_rekruti = int(d.get("recruitable_population", 0))
		if dostupni_rekruti >= pocet:
			statni_kasa -= celkova_cena
			d["recruitable_population"] -= pocet
			d["soldiers"] += pocet
			map_loader.aktualizuj_ikony_armad()
			kolo_zmeneno.emit() 
			return true
	return false

# --- AI BRAIN ---

func zpracuj_tah_ai():
	print("--- AI THINKING START ---")
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return
		
	var cena_za_vojaka = 0.01
	
	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == hrac_stat or owner == "SEA": continue
		
		if not ai_kasy.has(owner): ai_kasy[owner] = 1000.0 
		
		var gdp = float(d.get("gdp", 0.0))
		var vojaci = int(d.get("soldiers", 0))
		var prijem = (gdp * 0.1) - (vojaci * 0.001)
		ai_kasy[owner] += prijem

		if ai_kasy[owner] < -100.0:
			_vyres_bankrot(owner)

		# AI Recruitment
		var rekruti = int(d.get("recruitable_population", 0))
		if rekruti > 300 and ai_kasy[owner] > 50.0:
			var pocet_k_verbovani = min(rekruti, int(ai_kasy[owner] / cena_za_vojaka))
			pocet_k_verbovani = min(pocet_k_verbovani, 1200) 
			d["recruitable_population"] -= pocet_k_verbovani
			d["soldiers"] += pocet_k_verbovani
			ai_kasy[owner] -= (pocet_k_verbovani * cena_za_vojaka)

		# AI Attack & Diplomacy
		if vojaci > 1000: 
			var sousedi = d.get("neighbors", [])
			var best_target = -1
			var weakest_defense = 9999999
			
			for n_id in sousedi:
				if map_data.has(n_id):
					var n_prov = map_data[n_id]
					var n_owner = str(n_prov.get("owner", "")).strip_edges().to_upper()
					if n_owner != owner and n_owner != "SEA":
						var n_vojaci = int(n_prov.get("soldiers", 0))
						if (vojaci >= int(n_vojaci * 1.2) or vojaci > 3000) and n_vojaci < weakest_defense:
							weakest_defense = n_vojaci
							best_target = n_id
							
			if best_target != -1:
				var n_owner = str(map_data[best_target].get("owner", "")).strip_edges().to_upper()
				
				# Zkontroluje, jestli už mají válku
				if jsou_ve_valce(owner, n_owner):
					map_loader.zaregistruj_presun_armady(p_id, best_target, int(vojaci * 0.8))
				else:
					# Pokud nemají válku, je 25% šance, že ji teď vyhlásí
					if randf() < 0.25:
						await vyhlasit_valku(owner, n_owner)
				
	print("--- AI THINKING END ---")
