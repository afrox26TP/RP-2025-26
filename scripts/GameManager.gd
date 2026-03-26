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
var lokalni_hraci_staty: Array = []
var aktivni_hrac_index: int = 0
var hrac_kasy: Dictionary = {}
var hrac_prijmy: Dictionary = {}
var hrac_kasa_inicializovana: Dictionary = {}
var cekajici_popupy_hracu: Dictionary = {}

const AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE := 1.25
const AI_DECLARE_WAR_MIN_ATTACK_FORCE := 1800
const AI_DECLARE_WAR_MAX_RELATION := -10.0
const RELATION_MIN := -100.0
const RELATION_MAX := 100.0
const RELATION_STEP_PLAYER := 10.0
const RELATION_ACTION_COOLDOWN_TURNS := 3
const AI_FRIEND_RELATION_THRESHOLD := 35.0
const AI_RELATION_STEP := 5.0
const AI_REL_WORSEN_TRIGGER := -25.0
const AI_REL_IMPROVE_TRIGGER := 20.0

# Diplomacy
var valky: Dictionary = {}
var cekajici_kapitulace: Array = []
var cekajici_mirove_nabidky: Array = []

var zpracovava_se_tah: bool = false
var _core_state_cache: Dictionary = {}
var _vztahy_statu: Dictionary = {}
var _vztahy_nactene: bool = false
var _vztah_akce_posledni_kolo: Dictionary = {}
var _turn_cache_valid: bool = false
var _turn_state_soldier_power: Dictionary = {}
var _turn_state_hdp: Dictionary = {}
var _turn_border_pairs: Dictionary = {}
var _turn_active_states: Array = []

const RELATIONSHIPS_CSV_PATH := "res://map_data/Relationships.csv"

func _normalizuj_lidske_staty(staty: Array) -> Array:
	var out: Array = []
	for s in staty:
		var tag = _normalizuj_tag(str(s))
		if tag == "" or tag == "SEA":
			continue
		if out.has(tag):
			continue
		out.append(tag)
	return out

func nastav_lokalni_hrace(staty: Array) -> void:
	var normalizovane = _normalizuj_lidske_staty(staty)
	if normalizovane.is_empty():
		normalizovane = [_normalizuj_tag(hrac_stat)]

	lokalni_hraci_staty = normalizovane
	aktivni_hrac_index = 0
	hrac_stat = str(lokalni_hraci_staty[0])
	hrac_jmeno = ""
	hrac_ideologie = ""
	_hrac_kasa_inicializovana = false
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	ai_kasy.clear()

	if not hrac_kasy.has(hrac_stat):
		hrac_kasy[hrac_stat] = statni_kasa
	if not hrac_prijmy.has(hrac_stat):
		hrac_prijmy[hrac_stat] = celkovy_prijem

	_synchronizuj_jmeno_a_ideologii_hrace()

func _pridej_popup_hraci(tag: String, titulek: String, text: String) -> void:
	var cisty_tag = _normalizuj_tag(tag)
	if cisty_tag == "" or not je_lidsky_stat(cisty_tag):
		return
	if titulek.strip_edges() == "" or text.strip_edges() == "":
		return
	if not cekajici_popupy_hracu.has(cisty_tag):
		cekajici_popupy_hracu[cisty_tag] = []
	(cekajici_popupy_hracu[cisty_tag] as Array).append({
		"title": titulek,
		"text": text
	})

func _pridej_popup_zucastnenym_hracum(tag_a: String, tag_b: String, titulek: String, text: String) -> void:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var pridane: Dictionary = {}
	for t in [a, b]:
		if t == "" or pridane.has(t):
			continue
		if je_lidsky_stat(t):
			_pridej_popup_hraci(t, titulek, text)
			pridane[t] = true

func _zobraz_cekajici_popupy_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	if not cekajici_popupy_hracu.has(aktivni):
		return

	var fronta = (cekajici_popupy_hracu[aktivni] as Array)
	if fronta.is_empty():
		return

	var map_loader = _get_map_loader()
	if map_loader == null or not map_loader.has_method("_ukaz_bitevni_popup"):
		return

	var kopie_fronty = fronta.duplicate(true)
	fronta.clear()
	for item in kopie_fronty:
		var t = str(item.get("title", "Hlaseni"))
		var msg = str(item.get("text", ""))
		if msg.strip_edges() == "":
			continue
		await map_loader._ukaz_bitevni_popup(t, msg)

func je_lidsky_stat(tag: String) -> bool:
	var cisty = _normalizuj_tag(tag)
	if cisty == "":
		return false
	if lokalni_hraci_staty.is_empty():
		return cisty == _normalizuj_tag(hrac_stat)
	return lokalni_hraci_staty.has(cisty)

func _uloz_finance_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	hrac_kasy[aktivni] = statni_kasa
	hrac_prijmy[aktivni] = celkovy_prijem

func _nacti_finance_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	statni_kasa = float(hrac_kasy.get(aktivni, statni_kasa))
	celkovy_prijem = float(hrac_prijmy.get(aktivni, celkovy_prijem))

func _synchronizuj_jmeno_a_ideologii_hrace() -> void:
	hrac_jmeno = ""
	hrac_ideologie = ""
	if map_data.is_empty():
		return
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			hrac_jmeno = str(d.get("country_name", hrac_stat))
			hrac_ideologie = str(d.get("ideology", ""))
			return

func _prepni_na_hrace(index: int) -> void:
	if lokalni_hraci_staty.is_empty():
		return
	aktivni_hrac_index = clamp(index, 0, lokalni_hraci_staty.size() - 1)
	hrac_stat = str(lokalni_hraci_staty[aktivni_hrac_index])
	_nacti_finance_aktivniho_hrace()
	_synchronizuj_jmeno_a_ideologii_hrace()

func _prepni_na_dalsiho_hrace() -> void:
	if lokalni_hraci_staty.size() <= 1:
		return
	var dalsi_index = (aktivni_hrac_index + 1) % lokalni_hraci_staty.size()
	_prepni_na_hrace(dalsi_index)

func _je_posledni_hrac_v_poradi() -> bool:
	return lokalni_hraci_staty.size() <= 1 or aktivni_hrac_index >= (lokalni_hraci_staty.size() - 1)

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

func _normalizuj_tag(tag: String) -> String:
	return tag.strip_edges().to_upper()

func _je_more_provincie(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	var d = map_data[prov_id]
	var owner = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner == "SEA" or typ == "sea"

func je_pobrezni_provincie(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	if _je_more_provincie(prov_id):
		return false
	for n_id in map_data[prov_id].get("neighbors", []):
		if _je_more_provincie(int(n_id)):
			return true
	return false

func provincie_ma_pristav(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	return bool(map_data[prov_id].get("has_port", false))

func muze_postavit_pristav(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	var owner = str(map_data[prov_id].get("owner", "")).strip_edges().to_upper()
	if owner != hrac_stat:
		return false
	if provincie_cooldowny.has(prov_id):
		return false
	if provincie_ma_pristav(prov_id):
		return false
	return je_pobrezni_provincie(prov_id)

func _klic_vztahu(tag_a: String, tag_b: String) -> String:
	return "%s|%s" % [_normalizuj_tag(tag_a), _normalizuj_tag(tag_b)]

func _klic_vztah_pair(tag_a: String, tag_b: String) -> String:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _nacti_vztahy_statu() -> void:
	if _vztahy_nactene:
		return

	_vztahy_statu.clear()
	var file = FileAccess.open(RELATIONSHIPS_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("Nepodarilo se nacist %s" % RELATIONSHIPS_CSV_PATH)
		_vztahy_nactene = true
		return

	if not file.eof_reached():
		file.get_line() # Skip header

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		var parts = line.split(";")
		if parts.size() < 3:
			continue

		var a = _normalizuj_tag(parts[0])
		var b = _normalizuj_tag(parts[1])
		if a == "" or b == "":
			continue

		var score := 0.0
		var score_txt = str(parts[2]).strip_edges()
		if score_txt != "":
			score = float(score_txt)

		_vztahy_statu[_klic_vztahu(a, b)] = score
		_vztahy_statu[_klic_vztahu(b, a)] = score

	_vztahy_nactene = true

func ziskej_vztah_statu(tag_a: String, tag_b: String) -> float:
	_nacti_vztahy_statu()
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0

	var klic = _klic_vztahu(a, b)
	if _vztahy_statu.has(klic):
		return float(_vztahy_statu[klic])
	return 0.0

func uprav_vztah_statu(tag_a: String, tag_b: String, delta: float) -> float:
	_nacti_vztahy_statu()
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0
	if not muze_upravit_vztah_statu(a, b):
		return ziskej_vztah_statu(a, b)

	var current = ziskej_vztah_statu(a, b)
	var updated = clamp(current + delta, RELATION_MIN, RELATION_MAX)
	_vztahy_statu[_klic_vztahu(a, b)] = updated
	_vztahy_statu[_klic_vztahu(b, a)] = updated
	_vztah_akce_posledni_kolo[_klic_vztah_pair(a, b)] = aktualni_kolo
	return updated

func zlepsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	return uprav_vztah_statu(tag_a, tag_b, absf(amount))

func zhorsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	return uprav_vztah_statu(tag_a, tag_b, -absf(amount))

func _je_pratelsky_vztah(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	return ziskej_vztah_statu(tag_a, tag_b) >= AI_FRIEND_RELATION_THRESHOLD

func muze_upravit_vztah_statu(tag_a: String, tag_b: String) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return false
	return zbyva_kol_do_upravy_vztahu(a, b) <= 0

func zbyva_kol_do_upravy_vztahu(tag_a: String, tag_b: String) -> int:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0

	var key = _klic_vztah_pair(a, b)
	if not _vztah_akce_posledni_kolo.has(key):
		return 0

	var last_turn = int(_vztah_akce_posledni_kolo[key])
	var elapsed = aktualni_kolo - last_turn
	return max(0, RELATION_ACTION_COOLDOWN_TURNS - elapsed)

# Diplomacy helpers
func jsou_ve_valce(tag1: String, tag2: String) -> bool:
	var klic1 = tag1 + "_" + tag2
	var klic2 = tag2 + "_" + tag1
	return valky.has(klic1) or valky.has(klic2)

func vycisti_stat_po_kapitulaci(tag: String):
	var target = tag.strip_edges().to_upper()
	if target == "":
		return

	var valky_klice = valky.keys().duplicate()
	for klic in valky_klice:
		var txt = str(klic)
		if txt.begins_with(target + "_") or txt.ends_with("_" + target):
			valky.erase(klic)

	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		var obr = str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper()
		var uto = str(cekajici_kapitulace[i].get("utocnik", "")).strip_edges().to_upper()
		if obr == target or uto == target:
			cekajici_kapitulace.remove_at(i)

	for i in range(cekajici_mirove_nabidky.size() - 1, -1, -1):
		var from_tag = str(cekajici_mirove_nabidky[i].get("from", "")).strip_edges().to_upper()
		var to_tag = str(cekajici_mirove_nabidky[i].get("to", "")).strip_edges().to_upper()
		if from_tag == target or to_tag == target:
			cekajici_mirove_nabidky.remove_at(i)

	ai_kasy.erase(target)
	_core_state_cache.erase(target)

func vyhlasit_valku(utocnik: String, obrance: String):
	if jsou_ve_valce(utocnik, obrance): return
	
	var klic = utocnik + "_" + obrance
	valky[klic] = true
	
	var msg = "⚠️ VÁLKA!\n\nStát %s právě vyhlásil válku státu %s!" % [utocnik, obrance]
	print(msg.replace("\n\n", " "))
	
	# Pause and show popup if the player is involved
	if je_lidsky_stat(utocnik) or je_lidsky_stat(obrance):
		_pridej_popup_zucastnenym_hracum(utocnik, obrance, "DIPLOMACIE", msg)

func nabidnout_mir(tag1: String, tag2: String):
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()

	if cisty_tag1 == "" or cisty_tag2 == "" or cisty_tag1 == cisty_tag2:
		return
	if not jsou_ve_valce(cisty_tag1, cisty_tag2):
		return
	if je_mirova_nabidka_cekajici(cisty_tag1, cisty_tag2):
		return

	cekajici_mirove_nabidky.append({
		"from": cisty_tag1,
		"to": cisty_tag2,
		"turn": aktualni_kolo
	})

	print("Mirova nabidka odeslana: %s -> %s" % [cisty_tag1, cisty_tag2])

func je_mirova_nabidka_cekajici(odesilatel: String, prijemce: String) -> bool:
	var from_tag = odesilatel.strip_edges().to_upper()
	var to_tag = prijemce.strip_edges().to_upper()
	for nabidka in cekajici_mirove_nabidky:
		if str(nabidka.get("from", "")).strip_edges().to_upper() == from_tag and str(nabidka.get("to", "")).strip_edges().to_upper() == to_tag:
			return true
	return false

func _uzavri_mir_mezi(tag1: String, tag2: String):
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()
	var klic1 = cisty_tag1 + "_" + cisty_tag2
	var klic2 = cisty_tag2 + "_" + cisty_tag1

	valky.erase(klic1)
	valky.erase(klic2)

	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		var obr = str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper()
		var uto = str(cekajici_kapitulace[i].get("utocnik", "")).strip_edges().to_upper()
		var stejna_dvojice = (obr == cisty_tag1 and uto == cisty_tag2) or (obr == cisty_tag2 and uto == cisty_tag1)
		if stejna_dvojice:
			cekajici_kapitulace.remove_at(i)

func _ma_aktivni_tlak_na_kapitulaci(obrance: String, utocnik: String) -> bool:
	var obr_tag = obrance.strip_edges().to_upper()
	var uto_tag = utocnik.strip_edges().to_upper()
	for zaznam in cekajici_kapitulace:
		if str(zaznam.get("obrance", "")).strip_edges().to_upper() == obr_tag and str(zaznam.get("utocnik", "")).strip_edges().to_upper() == uto_tag:
			return true
	return false

func _spocitej_silu_statu(tag: String) -> int:
	var hledany = tag.strip_edges().to_upper()
	if hledany == "":
		return 0
	if _turn_cache_valid and _turn_state_soldier_power.has(hledany):
		return int(_turn_state_soldier_power[hledany])
	var sila := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hledany:
			sila += int(d.get("soldiers", 0))
	return sila

func _ma_ai_prijmout_mir(prijemce: String, odesilatel: String) -> bool:
	var prij = prijemce.strip_edges().to_upper()
	var ode = odesilatel.strip_edges().to_upper()

	var sila_prijemce = float(max(1, _spocitej_silu_statu(prij)))
	var sila_odesilatele = float(max(1, _spocitej_silu_statu(ode)))
	var pomer = sila_prijemce / sila_odesilatele

	var chance := 0.45
	if pomer < 0.8:
		chance += 0.35
	elif pomer < 1.0:
		chance += 0.15
	elif pomer > 1.4:
		chance -= 0.20

	if _ma_aktivni_tlak_na_kapitulaci(prij, ode):
		chance += 0.30
	if _ma_aktivni_tlak_na_kapitulaci(ode, prij):
		chance -= 0.20

	# War fatigue diplomacy: better relations increase peace acceptance.
	var rel = ziskej_vztah_statu(prij, ode)
	chance += clamp(rel / 120.0, -0.20, 0.25)

	chance = clamp(chance, 0.05, 0.95)
	return randf() < chance

func _ziskej_ai_staty() -> Array:
	var ai_staty: Dictionary = {}
	for owner in _ziskej_aktivni_staty():
		var tag = str(owner)
		if tag == "" or je_lidsky_stat(tag):
			continue
		ai_staty[tag] = true
	return ai_staty.keys()

func _klic_pair(tag_a: String, tag_b: String) -> String:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return ""
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _invalidate_turn_cache() -> void:
	_turn_cache_valid = false
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()

func _rebuild_turn_cache() -> void:
	_invalidate_turn_cache()

	var active: Dictionary = {}
	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue

		active[owner] = true
		_turn_state_soldier_power[owner] = int(_turn_state_soldier_power.get(owner, 0)) + int(d.get("soldiers", 0))
		_turn_state_hdp[owner] = float(_turn_state_hdp.get(owner, 0.0)) + float(d.get("gdp", 0.0))

		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if n_owner == "" or n_owner == "SEA" or n_owner == owner:
				continue
			var pair_key = _klic_pair(owner, n_owner)
			if pair_key != "":
				_turn_border_pairs[pair_key] = true

	_turn_active_states = active.keys()
	_turn_cache_valid = true

func _ziskej_aktivni_staty() -> Array:
	if _turn_cache_valid:
		return _turn_active_states.duplicate()

	var ai_staty: Dictionary = {}
	for p_id in map_data:
		var owner = str(map_data[p_id].get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue
		ai_staty[owner] = true
	return ai_staty.keys()

func _ma_spolecnou_hranici(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	if _turn_cache_valid:
		var cache_key = _klic_pair(tag_a, tag_b)
		return cache_key != "" and _turn_border_pairs.has(cache_key)

	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != tag_a:
			continue
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if n_owner == tag_b:
				return true
	return false

func _zpracuj_ai_diplomacii(ai_staty: Array) -> Array:
	var aktivni_staty = _ziskej_aktivni_staty()
	var zmeny_vztahu_k_hraci: Array = []
	for owner in ai_staty:
		var owner_tag = str(owner)
		if owner_tag == "":
			continue

		var our_power = float(max(1, _spocitej_silu_statu(owner_tag)))
		var best_improve_target := ""
		var best_improve_score := -INF
		var best_worsen_target := ""
		var best_worsen_score := -INF

		for other in aktivni_staty:
			var other_tag = str(other)
			if other_tag == owner_tag:
				continue
			if jsou_ve_valce(owner_tag, other_tag):
				continue
			if not muze_upravit_vztah_statu(owner_tag, other_tag):
				continue

			var rel = ziskej_vztah_statu(owner_tag, other_tag)
			var their_power = float(max(1, _spocitej_silu_statu(other_tag)))
			var ratio = our_power / their_power
			var border = _ma_spolecnou_hranici(owner_tag, other_tag)

			# Build allies when weak or when the relation is already positive but not stable.
			var improve_score := -INF
			if rel < AI_REL_IMPROVE_TRIGGER and (ratio < 0.95 or border):
				improve_score = (AI_REL_IMPROVE_TRIGGER - rel)
				if ratio < 0.95:
					improve_score += (0.95 - ratio) * 35.0
				if border:
					improve_score += 8.0

			if improve_score > best_improve_score:
				best_improve_score = improve_score
				best_improve_target = other_tag

			# Escalate hostility against weakly defended rivals.
			var worsen_score := -INF
			if rel <= AI_REL_WORSEN_TRIGGER and ratio > 1.05:
				worsen_score = (-rel)
				worsen_score += (ratio - 1.05) * 30.0
				if border:
					worsen_score += 12.0

			if worsen_score > best_worsen_score:
				best_worsen_score = worsen_score
				best_worsen_target = other_tag

		if best_worsen_target != "" and best_worsen_score >= 22.0:
			var novy_vztah_minus = uprav_vztah_statu(owner_tag, best_worsen_target, -AI_RELATION_STEP)
			if je_lidsky_stat(best_worsen_target):
				zmeny_vztahu_k_hraci.append({
					"from": owner_tag,
					"to": best_worsen_target,
					"delta": -AI_RELATION_STEP,
					"new_rel": novy_vztah_minus
				})
			continue

		if best_improve_target != "" and best_improve_score >= 12.0:
			var novy_vztah_plus = uprav_vztah_statu(owner_tag, best_improve_target, AI_RELATION_STEP)
			if je_lidsky_stat(best_improve_target):
				zmeny_vztahu_k_hraci.append({
					"from": owner_tag,
					"to": best_improve_target,
					"delta": AI_RELATION_STEP,
					"new_rel": novy_vztah_plus
				})

	return zmeny_vztahu_k_hraci

func _zobraz_hlaseni_vztahu_hrace(zmeny: Array):
	if zmeny.is_empty():
		return

	var lines_by_target: Dictionary = {}
	for z in zmeny:
		var stat = str(z.get("from", ""))
		var target = _normalizuj_tag(str(z.get("to", "")))
		var delta = float(z.get("delta", 0.0))
		var rel = float(z.get("new_rel", 0.0))
		if stat == "" or target == "" or not je_lidsky_stat(target):
			continue
		if not lines_by_target.has(target):
			lines_by_target[target] = []
		if delta > 0.0:
			(lines_by_target[target] as Array).append("%s zlepsil vztah k tobe. Novy vztah: %.1f" % [stat, rel])
		else:
			(lines_by_target[target] as Array).append("%s zhorsil vztah k tobe. Novy vztah: %.1f" % [stat, rel])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacie", "\n".join(lines))

func _vyhodnot_mirove_nabidky_pred_ai():
	if cekajici_mirove_nabidky.is_empty():
		return

	var nabidky = cekajici_mirove_nabidky.duplicate()
	cekajici_mirove_nabidky.clear()

	for nabidka in nabidky:
		var odesilatel = str(nabidka.get("from", "")).strip_edges().to_upper()
		var prijemce = str(nabidka.get("to", "")).strip_edges().to_upper()
		if odesilatel == "" or prijemce == "":
			continue
		if not jsou_ve_valce(odesilatel, prijemce):
			continue

		# This evaluation runs in AI phase, so only AI recipients are resolved now.
		if je_lidsky_stat(prijemce) or prijemce == "SEA":
			continue

		if _ma_ai_prijmout_mir(prijemce, odesilatel):
			_uzavri_mir_mezi(odesilatel, prijemce)
			var ok_msg = "Mirova nabidka prijata: %s a %s uzavrely mir." % [odesilatel, prijemce]
			print(ok_msg)
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACIE", ok_msg)
		else:
			var no_msg = "Mirova nabidka odmitnuta: %s odmitlo mir se statem %s." % [prijemce, odesilatel]
			print(no_msg)
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACIE", no_msg)

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

func _je_more_provincie_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	if not all_provinces.has(prov_id):
		return false
	var d = all_provinces[prov_id]
	var owner = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner == "SEA" or typ == "sea"

func _je_pobrezni_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	if not all_provinces.has(prov_id):
		return false
	if _je_more_provincie_v_datech(all_provinces, prov_id):
		return false
	for n_id in all_provinces[prov_id].get("neighbors", []):
		if _je_more_provincie_v_datech(all_provinces, int(n_id)):
			return true
	return false

func _vyber_startovni_port_kandidata(all_provinces: Dictionary, kandidati: Array) -> int:
	var vybrany := -1
	var best_pop := -1

	for p_id in kandidati:
		var pid = int(p_id)
		if not all_provinces.has(pid):
			continue
		var d = all_provinces[pid]
		if bool(d.get("is_capital", false)):
			return pid
		var pop = int(d.get("population", 0))
		if pop > best_pop:
			best_pop = pop
			vybrany = pid

	return vybrany

func pridej_startovni_pristavy(all_provinces: Dictionary):
	if all_provinces.is_empty():
		return

	var vsechny_staty: Dictionary = {}
	var stat_ma_pristav: Dictionary = {}
	var kandidati: Dictionary = {}

	for p_id in all_provinces.keys():
		var pid = int(p_id)
		var d = all_provinces[pid]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if owner == "" or owner == "SEA":
			continue

		vsechny_staty[owner] = true

		if bool(d.get("has_port", false)):
			stat_ma_pristav[owner] = true

		if _je_pobrezni_v_datech(all_provinces, pid):
			if not kandidati.has(owner):
				kandidati[owner] = []
			(kandidati[owner] as Array).append(pid)

	for owner in vsechny_staty.keys():
		if stat_ma_pristav.has(owner):
			continue
		if not kandidati.has(owner):
			continue

		var vybrany = _vyber_startovni_port_kandidata(all_provinces, kandidati[owner])
		if vybrany != -1 and all_provinces.has(vybrany):
			all_provinces[vybrany]["has_port"] = true

func spocitej_prijem(all_provinces: Dictionary, emit_ui_signal: bool = true):
	map_data = all_provinces 
	_synchronizuj_jmeno_a_ideologii_hrace()
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

	if lokalni_hraci_staty.size() > 1:
		if not hrac_kasa_inicializovana.has(hrac_stat) and celkove_hdp > 0.0:
			hrac_kasy[hrac_stat] = celkove_hdp * 0.05
			hrac_kasa_inicializovana[hrac_stat] = true
		statni_kasa = float(hrac_kasy.get(hrac_stat, statni_kasa))
	else:
		if not _hrac_kasa_inicializovana and celkove_hdp > 0.0:
			statni_kasa = celkove_hdp * 0.05
			_hrac_kasa_inicializovana = true
			
	# Balanced income: 10% GDP minus army upkeep
	var prijem_z_hdp = celkove_hdp * 0.1
	var naklady_na_vojaky = celkem_vojaku * 0.001
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	if lokalni_hraci_staty.size() > 1:
		hrac_prijmy[hrac_stat] = celkovy_prijem
		hrac_kasy[hrac_stat] = statni_kasa
	
	print("HDP Prijem: %.2f | Vydaje Armada: %.2f | Cisty zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	if emit_ui_signal:
		kolo_zmeneno.emit()

func _spocitej_hdp_statu(tag: String) -> float:
	var hledany = tag.strip_edges().to_upper()
	if hledany == "":
		return 0.0
	if _turn_cache_valid and _turn_state_hdp.has(hledany):
		return float(_turn_state_hdp[hledany])
	var hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hledany:
			hdp += float(d.get("gdp", 0.0))
	return hdp

func ukonci_kolo():
	if zpracovava_se_tah: return 
	zpracovava_se_tah = true

	if lokalni_hraci_staty.size() > 1 and not _je_posledni_hrac_v_poradi():
		_uloz_finance_aktivniho_hrace()
		_prepni_na_dalsiho_hrace()
		if not map_data.is_empty():
			spocitej_prijem(map_data, false)
		await _zobraz_cekajici_popupy_aktivniho_hrace()
		kolo_zmeneno.emit()
		zpracovava_se_tah = false
		return

	var map_loader = _get_map_loader()
	
	if map_loader:
		# Resolve battles and remove stale moves
		await map_loader.zpracuj_tah_armad()

	if lokalni_hraci_staty.size() > 1:
		_uloz_finance_aktivniho_hrace()
		for tag in lokalni_hraci_staty:
			var cisty_tag = _normalizuj_tag(str(tag))
			var kasa = float(hrac_kasy.get(cisty_tag, 0.0)) + float(hrac_prijmy.get(cisty_tag, 0.0))
			hrac_kasy[cisty_tag] = kasa
			if kasa < -100.0:
				await _vyres_bankrot(cisty_tag)
	else:
		statni_kasa += celkovy_prijem
		
		# Bankruptcy at debt below -100
		if statni_kasa < -100.0:
			await _vyres_bankrot(hrac_stat)

	aktualni_kolo += 1
	
	var hotove_stavby = []
	var hlaseni_dokoncene_stavby: Dictionary = {}
	for prov_id in provincie_cooldowny.keys():
		provincie_cooldowny[prov_id]["zbyva"] -= 1 
		if provincie_cooldowny[prov_id]["zbyva"] <= 0:
			hotove_stavby.append(prov_id)
			
	for prov_id in hotove_stavby:
		var typ_budovy = provincie_cooldowny[prov_id]["budova"]
		provincie_cooldowny.erase(prov_id)
		_aplikuj_bonus(prov_id, typ_budovy)
		if typ_budovy == 2 and map_data.has(prov_id):
			var nazev = str(map_data[prov_id].get("province_name", "Provincie %d" % int(prov_id)))
			var owner = _normalizuj_tag(str(map_data[prov_id].get("owner", "")))
			if je_lidsky_stat(owner):
				if not hlaseni_dokoncene_stavby.has(owner):
					hlaseni_dokoncene_stavby[owner] = []
				(hlaseni_dokoncene_stavby[owner] as Array).append("Pristav dokoncen: %s" % nazev)

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
		
		# Regenerate population and grow economy
		for p_id in map_data:
			var d = map_data[p_id]
			d["recruitable_population"] += 150
			if d["recruitable_population"] > 15000:
				d["recruitable_population"] = 15000
			d["gdp"] += 0.5 # Passive wealth growth

	# AI plans attacks and may declare wars (await for popups)
	await zpracuj_tah_ai()

	if not hlaseni_dokoncene_stavby.is_empty():
		for owner_tag in hlaseni_dokoncene_stavby.keys():
			var lines = hlaseni_dokoncene_stavby[owner_tag] as Array
			if lines.is_empty():
				continue
			_pridej_popup_hraci(str(owner_tag), "Hlaseni", "\n".join(lines))

	print("--- KOLO %d ---" % aktualni_kolo)
	
	if map_loader and map_loader.has_method("aktualizuj_ikony_armad"):
		map_loader.aktualizuj_ikony_armad()

	if lokalni_hraci_staty.size() > 1:
		_prepni_na_hrace(0)
		if not map_data.is_empty():
			spocitej_prijem(map_data, false)
	await _zobraz_cekajici_popupy_aktivniho_hrace()
	kolo_zmeneno.emit()
		
	zpracovava_se_tah = false

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	if typ == 0: 
		map_data[prov_id]["gdp"] += 10.0 
	elif typ == 1: 
		map_data[prov_id]["recruitable_population"] += 2000 
	elif typ == 2:
		map_data[prov_id]["has_port"] = true
		var map_loader = _get_map_loader()
		if map_loader and map_loader.has_method("oznac_pristavy_k_aktualizaci"):
			map_loader.oznac_pristavy_k_aktualizaci()

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
		if je_lidsky_stat(tag):
			_pridej_popup_hraci(tag, "STÁTNÍ BANKROT", "Dosly penize! %d vojaku dezertovalo." % celkem_dezertovalo)
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
	_rebuild_turn_cache()
	var ai_staty = _ziskej_ai_staty()

	# Evaluate pending peace offers before AI plans any attacks.
	await _vyhodnot_mirove_nabidky_pred_ai()
	var zmeny_vztahu_k_hraci = _zpracuj_ai_diplomacii(ai_staty)
	await _zobraz_hlaseni_vztahu_hrace(zmeny_vztahu_k_hraci)
		
	var cena_za_vojaka = 0.01

	for p_id in map_data:
		var d = map_data[p_id]
		var owner = str(d.get("owner", "")).strip_edges().to_upper()
		if je_lidsky_stat(owner) or owner == "SEA": continue
		
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
	_invalidate_turn_cache()
				
	print("--- AI THINKING END ---")

func _naplanuj_ai_presuny(map_loader):
	var ai_staty = _ziskej_ai_staty()

	if map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()

	for owner in ai_staty:
		var moved_from: Dictionary = {}
		var owner_tag = str(owner)
		var serazene: Array = _seradene_ai_provincie(owner_tag)
		var core_state: String = _ziskej_core_state_cached(owner_tag)

		# 1) Internal non-attacking relocation (rear to frontline by adjacent friendly move).
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_neutocny_presun(owner_tag, p_id)
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
			var move = _navrhni_core_obranu(owner_tag, p_id, core_state)
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
			var move = _navrhni_utok(owner_tag, p_id)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue

			var target_owner = str(map_data[move["to"]].get("owner", "")).strip_edges().to_upper()
			if jsou_ve_valce(owner_tag, target_owner):
				map_loader.zaregistruj_presun_armady(move["from"], move["to"], amount, false)
				moved_from[move["from"]] = true
			else:
				if _ma_smyls_vyhlasit_valku(owner_tag, target_owner, int(move["from"]), int(move["to"]), amount):
					await vyhlasit_valku(owner_tag, target_owner)
					if jsou_ve_valce(owner_tag, target_owner):
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
		if n_owner == owner or n_owner == "SEA":
			continue
		if jsou_ve_valce(owner, n_owner):
			return true
		if not _je_pratelsky_vztah(owner, n_owner):
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
		if not jsou_ve_valce(owner, n_owner) and _je_pratelsky_vztah(owner, n_owner):
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
	if _je_pratelsky_vztah(owner, target_owner):
		return false
	var rel = ziskej_vztah_statu(owner, target_owner)
	if rel > AI_DECLARE_WAR_MAX_RELATION:
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

	var relation_factor = clamp((-rel) / 80.0, 0.0, 1.0)
	var required_local_ratio = 1.25 - (relation_factor * 0.20)
	return ratio >= AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE and local_ratio >= required_local_ratio

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
		if not jsou_ve_valce(owner, n_owner) and _je_pratelsky_vztah(owner, n_owner):
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
		var rel = ziskej_vztah_statu(owner, n_owner)
		score += clamp(-rel, 0.0, 100.0) * 12.0
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
