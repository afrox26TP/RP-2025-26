extends Node

# Signál, který později využijeme, aby se po odkliknutí kola automaticky aktualizovalo UI
signal kolo_zmeneno 

var hrac_stat = "CZE"

# --- EKONOMIKA A TAHY ---
var statni_kasa: float = 1000.0 # Miliarda do začátku
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

# Tuhle funkci zavoláš po načtení mapy a pak po každém dobytí/ztrátě provincie
func spocitej_prijem(all_provinces: Dictionary):
	var celkove_hdp = 0.0
	
	for p_id in all_provinces:
		var p = all_provinces[p_id]
		if str(p.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			celkove_hdp += float(p.get("gdp", 0.0))
			
	# Příjem je třeba 5 % z celkového HDP (můžeš si to pak vybalancovat)
	celkovy_prijem = celkove_hdp * 0.05

# Tuhle funkci zavoláme, když hráč klikne na tlačítko "Další kolo"
func ukonci_kolo():
	statni_kasa += celkovy_prijem
	aktualni_kolo += 1
	
	print("--- KOLO %d ---" % aktualni_kolo)
	print("Do kasy přibylo: %.2f | Celkový stav: %.2f" % [celkovy_prijem, statni_kasa])
	
	# Vystřelíme signál do světa, ať o tom ví UI (že má přepsat texty v horní liště)
	kolo_zmeneno.emit()
