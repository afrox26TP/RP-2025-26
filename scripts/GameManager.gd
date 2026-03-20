extends Node

signal kolo_zmeneno 

# Set the player's country tag here (e.g., CZE, ALB, GER). The rest is auto-detected.
var hrac_stat = "ALB" 
var hrac_jmeno = "" 
var hrac_ideologie = "" 

var statni_kasa: float = 1000.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

# Store map data for read/write operations
var map_data: Dictionary = {}

# Active construction queue (key: province ID, value: {zbyva, budova})
var provincie_cooldowny: Dictionary = {}

func spocitej_prijem(all_provinces: Dictionary):
	map_data = all_provinces 
	var celkove_hdp = 0.0
	var celkem_vojaku = 0
	
	for p_id in map_data:
		var p = map_data[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			
			# Extract country name and ideology from the first valid province
			if hrac_jmeno == "":
				hrac_jmeno = str(p.get("country_name", ""))
				hrac_ideologie = str(p.get("ideology", ""))
			
			celkove_hdp += float(p.get("gdp", 0.0))
			celkem_vojaku += int(p.get("soldiers", 0))
			
	# Calculate income and expenses
	var prijem_z_hdp = celkove_hdp * 0.05
	var naklady_na_vojaky = celkem_vojaku * 0.005
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	
	print("HDP Příjem: %.2f | Výdaje Armáda: %.2f | Čistý zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	
	# Trigger UI update (TopBar now has the detected name and flag)
	kolo_zmeneno.emit()

func ukonci_kolo():
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

	# Recalculate income (GDP might have changed due to completed buildings)
	if not map_data.is_empty():
		spocitej_prijem(map_data)

	print("--- KOLO %d ---" % aktualni_kolo)

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	
	if typ == 0: 
		map_data[prov_id]["gdp"] += 10.0 
		print("Dostavěna Civilní továrna (Provincie %d)" % prov_id)
	elif typ == 1: 
		map_data[prov_id]["recruitable_population"] += 1000 
		print("Dostavěna Zbrojovka (Provincie %d)" % prov_id)
