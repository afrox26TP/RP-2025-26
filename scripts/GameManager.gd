extends Node

signal kolo_zmeneno 

var hrac_stat = "ALB" 
var hrac_jmeno = "" 
var hrac_ideologie = "" 

# Initial treasury is set dynamically from 5% of total state GDP.
var statni_kasa: float = 0.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

var map_data: Dictionary = {}
var provincie_cooldowny: Dictionary = {}
var ai_kasy: Dictionary = {} 
var _hrac_kasa_inicializovana: bool = false

const AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE := 1.25
const AI_DECLARE_WAR_MIN_ATTACK_FORCE := 1800

# Diplomacy
var valky: Dictionary = {}
var cekajici_kapitulace: Array = []

var zpracovava_se_tah: bool = false
var _core_state_cache: Dictionary = {}

# Safely get the map node
func _get_map_loader():
	var map_loader = get_tree().current_scene
	if map_loader and map_loader.has_method("zpracuj_tah_armad"):
		return map_loader
	if map_loader:
		var child_map = map_loader.find_child("Map", true, false)
		if child_map and child_map.has_method("zpracuj_tah_armad"):
			return child_map
	return null

# Diplomacy helpers
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
	
	# Pause and show popup if the player is involved
	if utocnik == hrac_stat or obrance == hrac_stat:
		var map_loader = _get_map_loader()
		if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
			await map_loader._ukaz_bitevni_popup("DIPLOMACIE", msg)

func zaregistruj_obsazeni_hlavniho_mesta(obrance: String, utocnik: String, capital_province_id: int):
	if obrance == "" or utocnik == "" or obrance == utocnik:
		return

	var obr = obrance.strip_edges().to_upper()
	var uto = utocnik.strip_edges().to_upper()

	# Keep only one active surrender timer per defender
	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		if str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper() == obr:
			cekajici_kapitulace.remove_at(i)

	cekajici_kapitulace.append({
		"obrance": obr,
		"utocnik": uto,
		"capital_id": capital_province_id,
		"capture_turn": aktualni_kolo
	})

func vyhodnot_odlozene_kapitulace() -> Array:
	var hotove: Array = []
	var stale_cekaji: Array = []

	for zaznam in cekajici_kapitulace:
		var capital_id = int(zaznam.get("capital_id", -1))
		if not map_data.has(capital_id):
			continue

		var utocnik = str(zaznam.get("utocnik", "")).strip_edges().to_upper()
		var aktualni_vlastnik = str(map_data[capital_id].get("owner", "")).strip_edges().to_upper()

		# Cancel surrender if attacker no longer holds the capital
		if aktualni_vlastnik != utocnik:
			continue

		var capture_turn = int(zaznam.get("capture_turn", aktualni_kolo))
		if aktualni_kolo > capture_turn:
			hotove.append(zaznam)
		else:
			stale_cekaji.append(zaznam)

	cekajici_kapitulace = stale_cekaji
	return hotove

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

	if not _hrac_kasa_inicializovana and celkove_hdp > 0.0:
		statni_kasa = celkove_hdp * 0.05
		_hrac_kasa_inicializovana = true
			
	# Balanced income: 10% GDP minus army upkeep
	var prijem_z_hdp = celkove_hdp * 0.1
	var naklady_na_vojaky = celkem_vojaku * 0.001
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	
	print("HDP Prijem: %.2f | Vydaje Armada: %.2f | Cisty zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	kolo_zmeneno.emit()

func _spocitej_hdp_statu(tag: String) -> float:
	if tag == "":
		return 0.0
	var hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == tag:
			hdp += float(d.get("gdp", 0.0))
	return hdp

func ukonci_kolo():
	if zpracovava_se_tah: return 
	zpracovava_se_tah = true

	var map_loader = _get_map_loader()
	
	if map_loader:
		# Resolve battles and remove stale moves
		await map_loader.zpracuj_tah_armad()

	statni_kasa += celkovy_prijem
	
	# Bankruptcy at debt below -100
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
		
		# Regenerate population and grow economy
		for p_id in map_data:
			var d = map_data[p_id]
			d["recruitable_population"] += 150
			if d["recruitable_population"] > 15000:
				d["recruitable_population"] = 15000
			d["gdp"] += 0.5 # Passive wealth growth

	# AI plans attacks and may declare wars (await for popups)
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

# Bankruptcy logic
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

# Player actions

func hrac_verbuje(provincie_id: int, pocet: int) -> bool:
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return false
	
	var d = map_data[provincie_id]
	if str(d.get("owner", "")).strip_edges().to_upper() != hrac_stat: return false
		
	var cena_za_vojaka = 0.01 # 1000 soldiers cost 10.00 mil. USD
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

# AI logic

func zpracuj_tah_ai():
	print("--- AI THINKING START ---")
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return
	_core_state_cache.clear()
		
	var cena_za_vojaka = 0.01

	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == hrac_stat or owner == "SEA": continue
		
		if not ai_kasy.has(owner):
			var ai_hdp = _spocitej_hdp_statu(owner)
			ai_kasy[owner] = ai_hdp * 0.05
		
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
			var frontline_bonus = 0
			if _ma_nepratelskeho_souseda(owner, p_id):
				frontline_bonus += 700
			if bool(d.get("is_capital", false)):
				frontline_bonus += 500
			var hrozba = _spocitej_hrozbu_nepratel_u_provincie(p_id, owner)
			frontline_bonus += min(900, int(float(hrozba) * 0.15))
			var limit_verbovani = min(2500, 900 + frontline_bonus)
			pocet_k_verbovani = min(pocet_k_verbovani, limit_verbovani)
			d["recruitable_population"] -= pocet_k_verbovani
			d["soldiers"] += pocet_k_verbovani
			ai_kasy[owner] -= (pocet_k_verbovani * cena_za_vojaka)

	# AI movement phases:
	# 1) Non-attacking moves inside own provinces.
	# 2) Reinforce core provinces (capital + capital state).
	# 3) Offensive attacks.
	await _naplanuj_ai_presuny(map_loader)
				
	print("--- AI THINKING END ---")

func _naplanuj_ai_presuny(map_loader):
	var ai_staty: Dictionary = {}
	for p_id in map_data:
		var owner = str(map_data[p_id].get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA" or owner == hrac_stat:
			continue
		if not ai_staty.has(owner):
			ai_staty[owner] = true

	if map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()

	for owner in ai_staty.keys():
		var moved_from: Dictionary = {}
		var serazene: Array = _seradene_ai_provincie(owner)
		var core_state: String = _ziskej_core_state_cached(owner)

		# 1) Internal non-attacking relocation (rear to frontline by adjacent friendly move).
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_neutocny_presun(owner, p_id)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(move["from"], move["to"], amount, false)
			moved_from[move["from"]] = true

		# 2) Defense of core provinces (capital and provinces in the capital's state).
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_core_obranu(owner, p_id, core_state)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(move["from"], move["to"], amount, false)
			moved_from[move["from"]] = true

		# 3) Offensive attacks.
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_utok(owner, p_id)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue

			var target_owner = str(map_data[move["to"]].get("owner", "")).strip_edges().to_upper()
			if jsou_ve_valce(owner, target_owner):
				map_loader.zaregistruj_presun_armady(move["from"], move["to"], amount, false)
				moved_from[move["from"]] = true
			else:
				if _ma_smyls_vyhlasit_valku(owner, target_owner, int(move["from"]), int(move["to"]), amount):
					await vyhlasit_valku(owner, target_owner)
					if jsou_ve_valce(owner, target_owner):
						map_loader.zaregistruj_presun_armady(move["from"], move["to"], amount, false)
						moved_from[move["from"]] = true

	if map_loader.has_method("ukonci_davkovy_presun"):
		map_loader.ukonci_davkovy_presun()

func _seradene_ai_provincie(owner: String) -> Array:
	var ids: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == owner:
			if int(d.get("soldiers", 0)) > 0:
				ids.append(p_id)

	ids.sort_custom(func(a, b):
		return int(map_data[a].get("soldiers", 0)) > int(map_data[b].get("soldiers", 0))
	)
	return ids

func _ma_nepratelskeho_souseda(owner: String, province_id: int) -> bool:
	if not map_data.has(province_id):
		return false
	for n_id in map_data[province_id].get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
		if n_owner != owner and n_owner != "SEA":
			return true
	return false

func _spocitej_hrozbu_nepratel_u_provincie(province_id: int, owner: String) -> int:
	if not map_data.has(province_id):
		return 0
	var threat := 0
	for n_id in map_data[province_id].get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
		if n_owner == owner or n_owner == "SEA":
			continue
		threat += int(map_data[n_id].get("soldiers", 0))
	return threat

func _spocitej_silu_na_hranici(owner: String, enemy: String) -> Dictionary:
	var our_border := 0
	var enemy_border := 0
	for p_id in map_data:
		var d = map_data[p_id]
		var p_owner = str(d.get("owner", "")).strip_edges().to_upper()
		if p_owner != owner and p_owner != enemy:
			continue
		var soldiers = int(d.get("soldiers", 0))
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if p_owner == owner and n_owner == enemy:
				our_border += soldiers
				break
			if p_owner == enemy and n_owner == owner:
				enemy_border += soldiers
				break
	return {"our": our_border, "enemy": enemy_border}

func _ma_smyls_vyhlasit_valku(owner: String, target_owner: String, from_id: int, to_id: int, amount: int) -> bool:
	if owner == "" or target_owner == "" or target_owner == "SEA":
		return false
	if amount < AI_DECLARE_WAR_MIN_ATTACK_FORCE:
		return false
	if not map_data.has(from_id) or not map_data.has(to_id):
		return false

	var border_strength = _spocitej_silu_na_hranici(owner, target_owner)
	var our_border = float(int(border_strength.get("our", 0)))
	var enemy_border = float(max(1, int(border_strength.get("enemy", 0))))
	var ratio = our_border / enemy_border

	var target_soldiers = int(map_data[to_id].get("soldiers", 0))
	var local_ratio = float(amount) / float(max(1, target_soldiers))

	return ratio >= AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE and local_ratio >= 1.2

func _navrhni_neutocny_presun(owner: String, from_id: int) -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 1400:
		return {}

	# Keep frontline stacks in place for attacks/defense phases.
	if _ma_nepratelskeho_souseda(owner, from_id):
		return {}

	var best_target = -1
	var best_score = -INF
	for n_id in from_data.get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_data = map_data[n_id]
		var n_owner = str(n_data.get("owner", "")).strip_edges().to_upper()
		if n_owner != owner:
			continue

		var target_soldiers = int(n_data.get("soldiers", 0))
		var threatened = _ma_nepratelskeho_souseda(owner, n_id)
		var score = 0.0
		if threatened:
			score += 10000.0
		score += (2000.0 - float(target_soldiers))

		if score > best_score:
			best_score = score
			best_target = n_id

	if best_target == -1:
		return {}

	var amount = int(vojaci * 0.45)
	amount = max(250, amount)
	amount = min(amount, vojaci - 700)
	if amount <= 0:
		return {}

	return {"from": from_id, "to": best_target, "amount": amount}

func _ziskej_core_state(owner: String) -> String:
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != owner:
			continue
		if bool(d.get("is_capital", false)):
			return str(d.get("state", ""))
	return ""

func _ziskej_core_state_cached(owner: String) -> String:
	if owner == "":
		return ""
	if _core_state_cache.has(owner):
		return str(_core_state_cache[owner])
	var core_state = _ziskej_core_state(owner)
	_core_state_cache[owner] = core_state
	return core_state

func _je_core_provincie(owner: String, province_id: int, core_state: String) -> bool:
	if not map_data.has(province_id):
		return false
	var d = map_data[province_id]
	if str(d.get("owner", "")).strip_edges().to_upper() != owner:
		return false
	if bool(d.get("is_capital", false)):
		return true
	if core_state != "" and str(d.get("state", "")) == core_state:
		return true
	return false

func _navrhni_core_obranu(owner: String, from_id: int, core_state: String = "") -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 1100:
		return {}

	if core_state == "":
		core_state = _ziskej_core_state_cached(owner)
	var best_target = -1
	var best_score = -INF
	for n_id in from_data.get("neighbors", []):
		if not _je_core_provincie(owner, n_id, core_state):
			continue
		var n_soldiers = int(map_data[n_id].get("soldiers", 0))
		var score = (2600.0 - float(n_soldiers))
		if bool(map_data[n_id].get("is_capital", false)):
			score += 2200.0
		if _ma_nepratelskeho_souseda(owner, n_id):
			score += 1600.0
		score += min(1800.0, float(_spocitej_hrozbu_nepratel_u_provincie(n_id, owner)) * 0.25)
		if score > best_score:
			best_score = score
			best_target = n_id

	if best_target == -1:
		return {}

	if best_score < 400.0:
		return {}

	var amount = int(vojaci * 0.35)
	amount = max(200, amount)
	amount = min(amount, vojaci - 650)
	if amount <= 0:
		return {}

	return {"from": from_id, "to": best_target, "amount": amount}

func _navrhni_utok(owner: String, from_id: int) -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci <= 1000:
		return {}
	if not _ma_nepratelskeho_souseda(owner, from_id):
		return {}

	var best_target = -1
	var best_score = -INF
	var best_amount = 0
	var reserve = max(650, int(float(vojaci) * 0.25))
	var max_attack = vojaci - reserve
	if max_attack < 450:
		return {}

	for n_id in from_data.get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_prov = map_data[n_id]
		var n_owner = str(n_prov.get("owner", "")).strip_edges().to_upper()
		if n_owner == owner or n_owner == "SEA":
			continue

		var n_vojaci = int(n_prov.get("soldiers", 0))
		var threat_after_capture = _spocitej_hrozbu_nepratel_u_provincie(n_id, owner)
		var needed_for_push = int(float(n_vojaci) * 1.15) + int(float(threat_after_capture) * 0.15)
		var attack_amount = min(max_attack, int(float(vojaci) * 0.78))
		if attack_amount < max(550, needed_for_push):
			continue

		var score = 0.0
		score += float(attack_amount - n_vojaci) * 1.2
		score -= float(threat_after_capture) * 0.30
		score += float(n_prov.get("gdp", 0.0)) * 16.0
		score += float(int(n_prov.get("recruitable_population", 0))) * 0.02
		if bool(n_prov.get("is_capital", false)):
			score += 3600.0
		var enemy_core = _ziskej_core_state_cached(n_owner)
		if enemy_core != "" and str(n_prov.get("state", "")) == enemy_core:
			score += 900.0

		if score > best_score:
			best_score = score
			best_target = n_id
			best_amount = attack_amount

	if best_target == -1:
		return {}
	if best_score < 350.0:
		return {}

	return {
		"from": from_id,
		"to": best_target,
		"amount": best_amount
	}
