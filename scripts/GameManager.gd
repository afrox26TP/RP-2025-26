extends Node

signal kolo_zmeneno 

var hrac_stat = "CZE"
var statni_kasa: float = 1000.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

# Uložím si celou mapu pro zápis dat
var map_data: Dictionary = {}

# Probíhající stavby (klíč: ID provincie, hodnota: zbyva, budova)
var provincie_cooldowny: Dictionary = {}

func spocitej_prijem(all_provinces: Dictionary):
	map_data = all_provinces # Hodím si sem referenci
	var celkove_hdp = 0.0
	for p_id in map_data:
		var p = map_data[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			celkove_hdp += float(p.get("gdp", 0.0))
	celkovy_prijem = celkove_hdp * 0.05

func ukonci_kolo():
	statni_kasa += celkovy_prijem
	aktualni_kolo += 1
	
	var hotove_stavby = []
	for prov_id in provincie_cooldowny.keys():
		# Odečtu 1 tah
		provincie_cooldowny[prov_id]["zbyva"] -= 1 
		
		if provincie_cooldowny[prov_id]["zbyva"] <= 0:
			hotove_stavby.append(prov_id)
			
	for prov_id in hotove_stavby:
		var typ_budovy = provincie_cooldowny[prov_id]["budova"]
		provincie_cooldowny.erase(prov_id)
		
		# Aplikuju bonusy z dostavěné budovy
		_aplikuj_bonus(prov_id, typ_budovy)

	# Přepočítám příjem (HDP mohlo stoupnout)
	if not map_data.is_empty():
		spocitej_prijem(map_data)

	print("--- KOLO %d ---" % aktualni_kolo)
	kolo_zmeneno.emit()

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	
	if typ == 0: # Civilní továrna
		map_data[prov_id]["gdp"] += 10.0 # Zvednu HDP
		print("Dostavěna Civilní továrna (Provincie %d)" % prov_id)
	elif typ == 1: # Zbrojovka
		map_data[prov_id]["recruitable_population"] += 1000 # Přidám rekruty
		print("Dostavěna Zbrojovka (Provincie %d)" % prov_id)
