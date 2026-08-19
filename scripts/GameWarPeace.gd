extends "res://scripts/GameDiplomacy.gd"

## War declarations, peace conferences, vassals, reparations, and financial flows.

func jsou_ve_valce(tag1: String, tag2: String) -> bool:
	# Inputs:
	# - `tag1`: Input argument used by `jsou_ve_valce` during execution.
	# - `tag2`: Input argument used by `jsou_ve_valce` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `jsou_ve_valce` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `jsou ve valce` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var klic = _klic_valky(tag1, tag2)
	if klic == "":
		return false
	return valky.has(klic)

# Ai generated or editted end (priloha_a.txt)
func vycisti_stat_po_kapitulaci(tag: String):
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `vycisti_stat_po_kapitulaci`.
	# Execution timing: Called when game flow invokes `vycisti_stat_po_kapitulaci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `vycisti stat po kapitulaci` logic.
	# 3. Persist side effects and return the computed `value` result.
	var target = tag.strip_edges().to_upper()
	if target == "":
		return
	_presun_hlavniho_mesta_posledni_kolo.erase(target)

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

	var aliance_klice = aliance_statu.keys().duplicate()
	for klic in aliance_klice:
		var parts = str(klic).split("|")
		if parts.size() != 2:
			continue
		if parts[0] == target or parts[1] == target:
			aliance_statu.erase(klic)

	# Remove defeated state from alliance groups
	for aid in aliance_skupiny.keys().duplicate():
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = (skupina.get("members", []) as Array)
		if members.has(target):
			members.erase(target)
			if members.size() < 2:
				aliance_skupiny.erase(aid)
			else:
				skupina["members"] = members
				aliance_skupiny[aid] = skupina

	var smlouvy_klice = neagresivni_smlouvy.keys().duplicate()
	for klic in smlouvy_klice:
		var parts2 = str(klic).split("|")
		if parts2.size() != 2:
			continue
		if parts2[0] == target or parts2[1] == target:
			neagresivni_smlouvy.erase(klic)

	var cooldown_klice = povalecne_cooldowny.keys().duplicate()
	for klic in cooldown_klice:
		var parts_c = str(klic).split("|")
		if parts_c.size() != 2:
			continue
		if parts_c[0] == target or parts_c[1] == target:
			povalecne_cooldowny.erase(klic)

	var zadosti_klice = cekajici_diplomaticke_zadosti.keys().duplicate()
	for receiver in zadosti_klice:
		var receiver_tag = _normalizuj_tag(str(receiver))
		if receiver_tag == target:
			cekajici_diplomaticke_zadosti.erase(receiver)
			continue
		var queue = cekajici_diplomaticke_zadosti[receiver] as Array
		for i in range(queue.size() - 1, -1, -1):
			var from_tag3 = _normalizuj_tag(str(queue[i].get("from", "")))
			if from_tag3 == target:
				queue.remove_at(i)

	for i in range(cekajici_aliancni_zadosti.size() - 1, -1, -1):
		var req = cekajici_aliancni_zadosti[i]
		var from_tag4 = _normalizuj_tag(str(req.get("from", "")))
		var to_tag4 = _normalizuj_tag(str(req.get("to", "")))
		if from_tag4 == target or to_tag4 == target:
			cekajici_aliancni_zadosti.remove_at(i)

	for subject_any in vazalske_vztahy.keys().duplicate():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == target or overlord == target:
			vazalske_vztahy.erase(subject_any)
			vazalske_odvody.erase(subject)

	for i in range(valecne_reparace.size() - 1, -1, -1):
		var rep = valecne_reparace[i] as Dictionary
		var from_tag_rep = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag_rep = _normalizuj_tag(str(rep.get("to", "")))
		if from_tag_rep == target or to_tag_rep == target:
			valecne_reparace.remove_at(i)

	# Remove stale military access entries for defeated state (host or guest).
	for key_any in vojensky_pristup.keys().duplicate():
		var parts_va = str(key_any).split("|")
		if parts_va.size() != 2:
			continue
		if _normalizuj_tag(parts_va[0]) == target or _normalizuj_tag(parts_va[1]) == target:
			vojensky_pristup.erase(key_any)

	for key_any in cekajici_mirove_konference.keys().duplicate():
		var queue = cekajici_mirove_konference[key_any] as Array
		for i in range(queue.size() - 1, -1, -1):
			var conf = queue[i] as Dictionary
			var winner = _normalizuj_tag(str(conf.get("winner", "")))
			var loser = _normalizuj_tag(str(conf.get("loser", "")))
			if winner == target or loser == target:
				queue.remove_at(i)
		if queue.is_empty():
			cekajici_mirove_konference.erase(key_any)

	ai_kasy.erase(target)
	_core_state_cache.erase(target)
	_expeluj_jednotky_bez_pristupu(target)

# Core flow for this feature.
func _vyhlasit_valku_par(utocnik: String, obrance: String, headline: String, details: String) -> bool:
	# Inputs:
	# - `utocnik`: Input argument used by `_vyhlasit_valku_par` during execution.
	# - `obrance`: Input argument used by `_vyhlasit_valku_par` during execution.
	# - `headline`: Input argument used by `_vyhlasit_valku_par` during execution.
	# - `details`: Input argument used by `_vyhlasit_valku_par` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_vyhlasit_valku_par` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyhlasit valku par` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var a = _normalizuj_tag(utocnik)
	var b = _normalizuj_tag(obrance)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	if jsou_ve_valce(a, b):
		return false
	var a_name = _ziskej_jmeno_statu_podle_tagu(a)
	var b_name = _ziskej_jmeno_statu_podle_tagu(b)

	var klic = _klic_valky(a, b)
	if klic == "":
		return false
	valky[klic] = true
	var pair_key = _klic_pair(a, b)
	if pair_key != "":
		_ai_war_cache.erase(pair_key)
		_ai_non_aggr_cache.erase(pair_key)
		_ai_alliance_level_cache.erase(pair_key)
		_ai_relation_cache.erase(pair_key)
		_ai_can_adjust_relation_cache.erase(pair_key)
		_ai_border_cache.erase(pair_key)
	_ai_war_pair_eval_cache.erase("%s>%s" % [a, b])
	_ai_war_pair_eval_cache.erase("%s>%s" % [b, a])
	_ai_state_enemies_cache.erase(a)
	_ai_state_enemies_cache.erase(b)
	_ai_war_exhaustion_cache.erase(a)
	_ai_war_exhaustion_cache.erase(b)

	var popup_title = "WAR"
	var popup_text = details
	var head_clean = headline.strip_edges().to_upper()
	if head_clean == "WAR":
		popup_title = "WAR"
		popup_text = "%s -> %s | DECLARED WAR" % [a_name, b_name]
	elif head_clean.find("ALLIANCE") != -1:
		popup_title = "ALLIANCE WAR"
		popup_text = details
	var msg = "%s | %s" % [popup_title, popup_text]
	if TURN_LOG_ENABLED:
		print(msg)
	_zaloguj_globalni_zpravu("War", "%s declared war on %s." % [a_name, b_name], "war")
	if je_lidsky_stat(a):
		_zaloguj_zpravu_hraci(a, "War", "You declared war on %s." % b_name, "war")
	if je_lidsky_stat(b):
		_zaloguj_zpravu_hraci(b, "War", "%s declared war on you." % a_name, "war")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, popup_title, popup_text)
	var old_suppress_logs = _suppress_relation_global_logs
	_suppress_relation_global_logs = _suppress_relation_global_logs or _ai_phase_cache_active
	_aplikuj_diplomatickou_reakci_na_agresi(a, b)
	_suppress_relation_global_logs = old_suppress_logs

	var alliance_level = _ziskej_uroven_aliance_ai_cached(a, b) if _ai_phase_cache_active else ziskej_uroven_aliance(a, b)
	if alliance_level > ALLIANCE_NONE:
		_nastav_uroven_aliance_bez_kontroly(a, b, ALLIANCE_NONE)
	return true

# Applies prepared settings/effects to runtime systems.
func _aplikuj_diplomatickou_reakci_na_agresi(utocnik: String, obrance: String) -> void:
	# Inputs:
	# - `utocnik`: Input argument used by `_aplikuj_diplomatickou_reakci_na_agresi` during execution.
	# - `obrance`: Input argument used by `_aplikuj_diplomatickou_reakci_na_agresi` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_aplikuj_diplomatickou_reakci_na_agresi` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` aplikuj diplomatickou reakci na agresi` logic.
	# 3. Persist side effects and finish without a return value.
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "" or attacker == defender:
		return
	_nacti_vztahy_statu()

	var reakce_na_hrace: Dictionary = {}
	var reakce_na_utocnika: Array = []
	var use_ai_cache = _ai_phase_cache_active
	var active_states = _turn_active_states if _turn_cache_valid else _ziskej_aktivni_staty()

	for stat in active_states:
		var observer = _normalizuj_tag(str(stat))
		if observer == "" or observer == "SEA":
			continue
		if observer == attacker or observer == defender:
			continue
		var observer_vs_defender_war = _jsou_ve_valce_ai_cached(observer, defender) if use_ai_cache else jsou_ve_valce(observer, defender)
		if observer_vs_defender_war:
			continue

		var rel_to_defender = _ziskej_ai_vztah_cached(observer, defender) if use_ai_cache else ziskej_vztah_statu(observer, defender)
		if rel_to_defender < AI_FRIEND_RELATION_THRESHOLD:
			continue

		var old_rel_to_attacker = _ziskej_ai_vztah_cached(observer, attacker) if use_ai_cache else ziskej_vztah_statu(observer, attacker)
		if old_rel_to_attacker <= RELATION_MIN + 0.001:
			continue
		var new_rel_to_attacker = _uprav_vztah_statu_bez_cooldown_rychle(observer, attacker, -AGGRESSION_RELATION_PENALTY) if use_ai_cache else _uprav_vztah_statu_bez_cooldown(observer, attacker, -AGGRESSION_RELATION_PENALTY)
		if new_rel_to_attacker >= old_rel_to_attacker:
			continue

		if je_lidsky_stat(observer):
			if not reakce_na_hrace.has(observer):
				reakce_na_hrace[observer] = []
			(reakce_na_hrace[observer] as Array).append("Because of %s aggression against %s, your relation with %s dropped to %.1f." % [attacker, defender, attacker, new_rel_to_attacker])

		if je_lidsky_stat(attacker):
			reakce_na_utocnika.append("%s worsened its relation to you (now %.1f) because you attacked %s." % [observer, new_rel_to_attacker, defender])

	for target_tag in reakce_na_hrace.keys():
		var lines = reakce_na_hrace[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacy", "\n".join(lines))

	if je_lidsky_stat(attacker) and not reakce_na_utocnika.is_empty():
		_pridej_popup_hraci(attacker, "Diplomacy", "\n".join(reakce_na_utocnika))

# Returns true when conditions are met.
func _ma_byt_spojenec_povolan(state_tag: String, ally_tag: String, enemy_tag: String, min_alliance_level: int) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `ally_tag`: State tag handled by this function.
	# - `enemy_tag`: State tag handled by this function.
	# - `min_alliance_level`: Input argument used by `_ma_byt_spojenec_povolan` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_byt_spojenec_povolan` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma byt spojenec povolan` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if state_tag == "" or ally_tag == "" or enemy_tag == "":
		return false
	if state_tag == ally_tag or state_tag == enemy_tag or ally_tag == enemy_tag:
		return false
	if ally_tag == "SEA":
		return false
	var alliance_state_ally = _ziskej_uroven_aliance_ai_cached(state_tag, ally_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(state_tag, ally_tag)
	if alliance_state_ally < min_alliance_level:
		return false
	var ally_vs_state_war = _jsou_ve_valce_ai_cached(ally_tag, state_tag) if _ai_phase_cache_active else jsou_ve_valce(ally_tag, state_tag)
	if ally_vs_state_war:
		return false
	var ally_vs_enemy_war = _jsou_ve_valce_ai_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else jsou_ve_valce(ally_tag, enemy_tag)
	if ally_vs_enemy_war:
		return false

	var alliance_vs_enemy = _ziskej_uroven_aliance_ai_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(ally_tag, enemy_tag)
	var alliance_vs_state = _ziskej_uroven_aliance_ai_cached(ally_tag, state_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(ally_tag, state_tag)
	if alliance_vs_enemy > alliance_vs_state:
		return false

	var rel_ally_enemy = _ziskej_ai_vztah_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else ziskej_vztah_statu(ally_tag, enemy_tag)
	if rel_ally_enemy >= AI_FRIEND_RELATION_THRESHOLD:
		return false

	return true

# Ai generated or editted start (priloha_a.txt)
func _aktivuj_aliance_po_vyhlaseni_valky(utocnik: String, obrance: String) -> void:
	# Inputs:
	# - `utocnik`: Input argument used by `_aktivuj_aliance_po_vyhlaseni_valky` during execution.
	# - `obrance`: Input argument used by `_aktivuj_aliance_po_vyhlaseni_valky` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_aktivuj_aliance_po_vyhlaseni_valky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` aktivuj aliance po vyhlaseni valky` logic.
	# 3. Persist side effects and finish without a return value.
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "":
		return
	var use_ai_cache = _ai_phase_cache_active

	# Defensive call: defender's defense/full allies join against attacker.
	for ally in _ziskej_spojence_s_min_alianci(defender, ALLIANCE_DEFENSE):
		var ally_tag = _normalizuj_tag(str(ally))
		if _turn_cache_valid and not _turn_state_owned_provinces.has(ally_tag):
			continue
		if use_ai_cache and _jsou_ve_valce_ai_cached(ally_tag, attacker):
			continue
		if not _ma_byt_spojenec_povolan(defender, ally_tag, attacker, ALLIANCE_DEFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag,
			attacker,
			"DEFENSIVE ALLIANCE",
			"%s entered the war to defend ally %s against %s." % [ally_tag, defender, attacker]
		)

	# Offensive call: attacker's offense/full allies join against defender.
	for ally in _ziskej_spojence_s_min_alianci(attacker, ALLIANCE_OFFENSE):
		var ally_tag2 = _normalizuj_tag(str(ally))
		if _turn_cache_valid and not _turn_state_owned_provinces.has(ally_tag2):
			continue
		if use_ai_cache and _jsou_ve_valce_ai_cached(ally_tag2, defender):
			continue
		if not _ma_byt_spojenec_povolan(attacker, ally_tag2, defender, ALLIANCE_OFFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag2,
			defender,
			"OFFENSIVE ALLIANCE",
			"%s entered the war alongside ally %s against %s." % [ally_tag2, attacker, defender]
		)

# Ai generated or editted end (priloha_a.txt)
func vyhlasit_valku(utocnik: String, obrance: String):
	# Inputs:
	# - `utocnik`: Input argument used by `vyhlasit_valku` during execution.
	# - `obrance`: Input argument used by `vyhlasit_valku` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `vyhlasit_valku`.
	# Execution timing: Called when game flow invokes `vyhlasit_valku` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `vyhlasit valku` logic.
	# 3. Persist side effects and return the computed `value` result.
	var a = _normalizuj_tag(utocnik)
	var b = _normalizuj_tag(obrance)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	_begin_ai_cache_batch()
	if jsou_ve_valce(a, b):
		_end_ai_cache_batch()
		return false
	var zbyva_povalecny_cooldown = zbyva_kol_do_dalsi_valky(a, b)
	if zbyva_povalecny_cooldown > 0:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "After peace, you must wait %d more turns before declaring war on %s again." % [zbyva_povalecny_cooldown, _ziskej_jmeno_statu_podle_tagu(b)])
		_end_ai_cache_batch()
		return false
	if ma_neagresivni_smlouvu(a, b):
		if je_lidsky_stat(a):
			var zbyva = zbyva_kol_neagresivni_smlouvy(a, b)
			_pridej_popup_hraci(a, "Diplomacy", "Cannot declare war while non-aggression pact with %s is active (%d turns)." % [_ziskej_jmeno_statu_podle_tagu(b), zbyva])
		_end_ai_cache_batch()
		return false

	if ziskej_uroven_aliance(a, b) > ALLIANCE_NONE:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "Cannot declare war on ally (%s). Cancel the alliance first." % _ziskej_jmeno_statu_podle_tagu(b))
		_end_ai_cache_batch()
		return false

	var created = _vyhlasit_valku_par(
		a,
		b,
		"WAR",
		"%s has declared war on %s!" % [_ziskej_jmeno_statu_podle_tagu(a), _ziskej_jmeno_statu_podle_tagu(b)]
	)
	if not created:
		_end_ai_cache_batch()
		return false

	# Revoke any military access between the warring parties.
	odvolej_vojensky_pristup(a, b)
	odvolej_vojensky_pristup(b, a)

	_aktivuj_aliance_po_vyhlaseni_valky(a, b)
	_end_ai_cache_batch()
	
	# Trigger immediate AI response if defender is AI-controlled
	if not je_lidsky_stat(b):
		_ai_zagent_valka_okamzita_reakce(a, b)
	
	return true

# Handles immediate AI response when this state is declared war on.
# Triggers recruitment and attack planning for the defending AI state.
func _ai_zagent_valka_okamzita_reakce(attacker: String, defender: String) -> void:
	# Inputs:
	# - `attacker`: Input argument used by `_ai_zagent_valka_okamzita_reakce` during execution.
	# - `defender`: Input argument used by `_ai_zagent_valka_okamzita_reakce` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_zagent_valka_okamzita_reakce` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai zagent valka okamzita reakce` logic.
	# 3. Persist side effects and finish without a return value.
	var attacker_tag = _normalizuj_tag(attacker)
	var defender_tag = _normalizuj_tag(defender)
	if attacker_tag == "" or defender_tag == "" or attacker_tag == defender_tag or defender_tag == "SEA":
		return
	if je_lidsky_stat(defender_tag):
		return
	
	# Quick sanity check: are they actually at war?
	if not jsou_ve_valce(attacker_tag, defender_tag):
		return
	
	var map_loader = _get_map_loader()
	if not map_loader:
		return
	
	# Prepare caches for this brief AI planning phase
	_core_state_cache.clear()
	_ai_phase_cache_active = true
	_ai_vycisti_runtime_cache()
	_rebuild_turn_cache()
	_set_defer_log_maintenance(true)
	
	# Get defender's owned provinces
	var owned_by_defender: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == defender_tag:
			owned_by_defender.append(p_id)
	
	if owned_by_defender.is_empty():
		_ai_phase_cache_active = false
		_ai_vycisti_runtime_cache()
		_set_defer_log_maintenance(false)
		return
	
	# Quick recruitment response: find threatened border provinces and recruit defenders
	var budget = _ziskej_kasu_statu(defender_tag)
	var cena_za_vojaka = max(0.001, ziskej_cenu_za_vojaka(defender_tag))
	var recruit_reserve = budget * 0.15  # Keep 15% in reserve
	var spend_cap = max(0.0, budget - recruit_reserve)
	
	var cil_provinces: Array = []
	for p_id in owned_by_defender:
		if not map_data.has(p_id):
			continue
		# Find provinces bordering the attacker
		var border_to_enemy = false
		for n_id in (_turn_neighbors_by_province.get(p_id, []) as Array):
			if _normalizuj_tag(str(_turn_owner_by_province.get(n_id, ""))) == attacker_tag:
				border_to_enemy = true
				break
		if border_to_enemy:
			cil_provinces.append(p_id)
	
	# Recruit emergency troops at border
	if not cil_provinces.is_empty() and spend_cap > cena_za_vojaka:
		cil_provinces.sort_custom(func(a, b):
			# Prioritize capital and high-population areas
			var pop_a = int(map_data[a].get("population", 0))
			var pop_b = int(map_data[b].get("population", 0))
			return pop_a > pop_b
		)
		
		var recruited = 0
		for p_id in cil_provinces:
			if recruited >= min(3, int(spend_cap / (cena_za_vojaka * 200))):  # Max 3 provinces
				break
			var d = map_data[p_id]
			var dostupni = int(d.get("recruitable_population", 0))
			if dostupni <= 0:
				continue
			
			# Recruit up to 400 soldiers per border province
			var cast = min(dostupni, 400)
			cast = min(cast, int((spend_cap - (recruited * cena_za_vojaka * 100)) / cena_za_vojaka))
			
			if cast <= 0:
				continue
			
			d["recruitable_population"] -= cast
			d["soldiers"] += cast
			d["army_owner"] = defender_tag
			spend_cap -= cast * cena_za_vojaka
			ai_kasy[defender_tag] = ai_kasy.get(defender_tag, 0.0) - cast * cena_za_vojaka
			recruited += 1
			_ai_vycisti_runtime_cache_pro_stat(defender_tag)
	
	# Quick movement planning: trigger defensive movements against the attacker.
	# If we are already inside an outer batch (e.g. _naplanuj_ai_presuny), do NOT start a
	# nested batch: zacni_davkovy_presun() would clear _minimalni_ai_tahy and
	# ukonci_davkovy_presun() would flip _pozastavit_aktualizaci_ikon to false, which causes
	# any attack moves registered *after* this reaction to skip the attack-arrow recording.
	var _reaction_was_batching: bool = "_pozastavit_aktualizaci_ikon" in map_loader and bool(map_loader._pozastavit_aktualizaci_ikon)
	if not _reaction_was_batching and map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()
	
	var core_defense_moves = 0
	var serazene = _seradene_ai_provincie(defender_tag)
	var own_capital_id = _ziskej_hlavni_mesto_statu(defender_tag)
	var frontline_cache: Dictionary = {}
	
	# Phase: Crisis reaction + core defense
	for p_id in serazene:
		if core_defense_moves >= 5:  # Limit moves for immediate response
			break
		
		var soldiers = int(map_data[p_id].get("soldiers", 0))
		if soldiers <= 0:
			continue
		
		# Try crisis reaction (capital recapture)
		var crisis_move = _navrhni_krizovy_protiutok(defender_tag, p_id, own_capital_id, frontline_cache)
		if not crisis_move.is_empty():
			var move_amount = int(crisis_move.get("amount", 0))
			if move_amount > 0:
				map_loader.zaregistruj_presun_armady(
					int(crisis_move["from"]),
					int(crisis_move["to"]),
					move_amount,
					false,
					[int(crisis_move["from"]), int(crisis_move["to"])]
				)
				core_defense_moves += 1
				continue
		
		# Try core defense
		var core_state = _ziskej_core_state_cached(defender_tag)
		var core_move = _navrhni_core_obranu(defender_tag, p_id, core_state, frontline_cache)
		if not core_move.is_empty():
			var move_amount = int(core_move.get("amount", 0))
			if move_amount > 0:
				map_loader.zaregistruj_presun_armady(
					int(core_move["from"]),
					int(core_move["to"]),
					move_amount,
					false,
					[int(core_move["from"]), int(core_move["to"])]
				)
				core_defense_moves += 1
				continue
	
	if not _reaction_was_batching and map_loader.has_method("ukonci_davkovy_presun"):
		map_loader.ukonci_davkovy_presun()
	
	# Cleanup
	_ai_phase_cache_active = false
	_ai_vycisti_runtime_cache()
	_invalidate_turn_cache()
	_set_defer_log_maintenance(false)
	
	if core_defense_moves > 0:
		_ai_debug("immediate_response %s moves=%d against %s" % [defender_tag, core_defense_moves, attacker_tag])

# Runs the local feature logic.
func nabidnout_mir(tag1: String, tag2: String):
	# Inputs:
	# - `tag1`: Input argument used by `nabidnout_mir` during execution.
	# - `tag2`: Input argument used by `nabidnout_mir` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `nabidnout_mir`.
	# Execution timing: Called when game flow invokes `nabidnout_mir` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nabidnout mir` logic.
	# 3. Persist side effects and return the computed `value` result.
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()

	if cisty_tag1 == "" or cisty_tag2 == "" or cisty_tag1 == cisty_tag2:
		return
	if not jsou_ve_valce(cisty_tag1, cisty_tag2):
		return
	if je_mirova_nabidka_cekajici(cisty_tag1, cisty_tag2):
		return

	if je_lidsky_stat(cisty_tag2):
		if _pridej_diplomatickou_zadost(cisty_tag1, cisty_tag2, "peace"):
			print("Peace request sent to player: %s -> %s" % [cisty_tag1, cisty_tag2])
		return

	cekajici_mirove_nabidky.append({
		"from": cisty_tag1,
		"to": cisty_tag2,
		"turn": aktualni_kolo
	})

	print("Peace offer sent: %s -> %s" % [cisty_tag1, cisty_tag2])

# Validates required conditions.
func je_mirova_nabidka_cekajici(odesilatel: String, prijemce: String) -> bool:
	# Inputs:
	# - `odesilatel`: Input argument used by `je_mirova_nabidka_cekajici` during execution.
	# - `prijemce`: Input argument used by `je_mirova_nabidka_cekajici` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `je_mirova_nabidka_cekajici` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `je mirova nabidka cekajici` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var from_tag = odesilatel.strip_edges().to_upper()
	var to_tag = prijemce.strip_edges().to_upper()
	for nabidka in cekajici_mirove_nabidky:
		if str(nabidka.get("from", "")).strip_edges().to_upper() == from_tag and str(nabidka.get("to", "")).strip_edges().to_upper() == to_tag:
			return true
	if cekajici_diplomaticke_zadosti.has(to_tag):
		for req in (cekajici_diplomaticke_zadosti[to_tag] as Array):
			if _normalizuj_tag(str(req.get("from", ""))) != from_tag:
				continue
			if str(req.get("type", "")) != "peace":
				continue
			return true
	return false

# Runs the local feature logic.
func _uzavri_mir_mezi(tag1: String, tag2: String, prepis_okupace: bool = true):
	# Inputs:
	# - `tag1`: Input argument used by `_uzavri_mir_mezi` during execution.
	# - `tag2`: Input argument used by `_uzavri_mir_mezi` during execution.
	# - `prepis_okupace`: Input argument used by `_uzavri_mir_mezi` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `_uzavri_mir_mezi`.
	# Execution timing: Called when game flow invokes `_uzavri_mir_mezi` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` uzavri mir mezi` logic.
	# 3. Persist side effects and return the computed `value` result.
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()
	var klic = _klic_valky(cisty_tag1, cisty_tag2)
	if klic == "":
		return
	_zaloguj_globalni_zpravu("War", "%s and %s made peace." % [cisty_tag1, cisty_tag2], "war")

	valky.erase(klic)
	var pair_key = _klic_pair(cisty_tag1, cisty_tag2)
	_ai_war_cache.erase(pair_key)
	_ai_non_aggr_cache.erase(pair_key)
	_ai_alliance_level_cache.erase(pair_key)
	_ai_relation_cache.erase(pair_key)
	_ai_can_adjust_relation_cache.erase(pair_key)
	_ai_border_cache.erase(pair_key)
	_ai_war_pair_eval_cache.erase("%s>%s" % [cisty_tag1, cisty_tag2])
	_ai_war_pair_eval_cache.erase("%s>%s" % [cisty_tag2, cisty_tag1])
	mirove_body_peak_dle_smeru.erase(_klic_mirovych_bodu(cisty_tag1, cisty_tag2))
	mirove_body_peak_dle_smeru.erase(_klic_mirovych_bodu(cisty_tag2, cisty_tag1))
	_ai_state_enemies_cache.erase(cisty_tag1)
	_ai_state_enemies_cache.erase(cisty_tag2)
	_ai_war_exhaustion_cache.erase(cisty_tag1)
	_ai_war_exhaustion_cache.erase(cisty_tag2)
	_nastav_povalecny_cooldown(cisty_tag1, cisty_tag2)
	if prepis_okupace:
		_prepis_okupace_po_miru(cisty_tag1, cisty_tag2)
	_expeluj_jednotky_bez_pristupu()

	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		var obr = str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper()
		var uto = str(cekajici_kapitulace[i].get("utocnik", "")).strip_edges().to_upper()
		var stejna_dvojice = (obr == cisty_tag1 and uto == cisty_tag2) or (obr == cisty_tag2 and uto == cisty_tag1)
		if stejna_dvojice:
			cekajici_kapitulace.remove_at(i)

	for i in range(cekajici_mirove_nabidky.size() - 1, -1, -1):
		var from_tag = str(cekajici_mirove_nabidky[i].get("from", "")).strip_edges().to_upper()
		var to_tag = str(cekajici_mirove_nabidky[i].get("to", "")).strip_edges().to_upper()
		var stejna_dvojice_mir = (from_tag == cisty_tag1 and to_tag == cisty_tag2) or (from_tag == cisty_tag2 and to_tag == cisty_tag1)
		if stejna_dvojice_mir:
			cekajici_mirove_nabidky.remove_at(i)

# Wipes short-lived state.
func _vycisti_expirovane_povalecne_cooldowny() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_vycisti_expirovane_povalecne_cooldowny` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vycisti expirovane povalecne cooldowny` logic.
	# 3. Persist side effects and finish without a return value.
	var keys = povalecne_cooldowny.keys().duplicate()
	for k in keys:
		var expiry_turn = int(povalecne_cooldowny.get(k, -1))
		if expiry_turn < aktualni_kolo:
			povalecne_cooldowny.erase(k)

# Applies updates and syncs dependent state.
func _nastav_povalecny_cooldown(tag_a: String, tag_b: String) -> void:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_nastav_povalecny_cooldown` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` nastav povalecny cooldown` logic.
	# 3. Persist side effects and finish without a return value.
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return
	povalecne_cooldowny[key] = aktualni_kolo + PEACE_WAR_COOLDOWN_TURNS - 1

# Runs the local feature logic.
func zbyva_kol_do_dalsi_valky(tag_a: String, tag_b: String) -> int:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `zbyva_kol_do_dalsi_valky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `zbyva kol do dalsi valky` logic.
	# 3. Persist side effects and return the computed `int` result.
	_vycisti_expirovane_povalecne_cooldowny()
	var key = _klic_pair(tag_a, tag_b)
	if key == "" or not povalecne_cooldowny.has(key):
		return 0
	var expiry_turn = int(povalecne_cooldowny[key])
	return max(0, expiry_turn - aktualni_kolo + 1)

# Handles this gameplay/UI path.
func _prepis_okupace_po_miru(tag_a: String, tag_b: String) -> void:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_prepis_okupace_po_miru` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` prepis okupace po miru` logic.
	# 3. Persist side effects and finish without a return value.
	if map_data.is_empty():
		return

	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return

	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
		if owner_tag == a and core_owner == b:
			d["core_owner"] = a
		elif owner_tag == b and core_owner == a:
			d["core_owner"] = b

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()

# Boolean check for required state.
func _ma_aktivni_tlak_na_kapitulaci(obrance: String, utocnik: String) -> bool:
	# Inputs:
	# - `obrance`: Input argument used by `_ma_aktivni_tlak_na_kapitulaci` during execution.
	# - `utocnik`: Input argument used by `_ma_aktivni_tlak_na_kapitulaci` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_aktivni_tlak_na_kapitulaci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma aktivni tlak na kapitulaci` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var obr_tag = obrance.strip_edges().to_upper()
	var uto_tag = utocnik.strip_edges().to_upper()
	for zaznam in cekajici_kapitulace:
		if str(zaznam.get("obrance", "")).strip_edges().to_upper() == obr_tag and str(zaznam.get("utocnik", "")).strip_edges().to_upper() == uto_tag:
			return true
	return false

# Validates required conditions.
func _ma_stat_cekajici_kapitulaci(state_tag: String) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_stat_cekajici_kapitulaci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma stat cekajici kapitulaci` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return false
	for zaznam in cekajici_kapitulace:
		if _normalizuj_tag(str(zaznam.get("obrance", ""))) == wanted:
			return true
	return false

# Fetches data for callers.
func _ziskej_statove_provincie(owner_tag: String) -> Array:
	# Inputs:
	# - `owner_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_statove_provincie` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej statove provincie` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var owner_clean = _normalizuj_tag(owner_tag)
	var out: Array = []
	if owner_clean == "" or owner_clean == "SEA":
		return out
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == owner_clean:
			out.append(int(p_id))
	return out

# Eligibility/guard check.
func _je_mirova_provincie_porazeneho(vitez_tag: String, porazeny_tag: String, d: Dictionary) -> bool:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `d`: Input argument used by `_je_mirova_provincie_porazeneho` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_mirova_provincie_porazeneho` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je mirova provincie porazeneho` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "":
		return false
	var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
	if owner_tag == "SEA":
		return false
	var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
	if owner_tag == loser:
		return true
	if owner_tag == winner and core_owner == loser:
		return true
	return false

# Fetches data for callers.
func _ziskej_mirove_provincie_porazeneho(vitez_tag: String, porazeny_tag: String) -> Array:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_mirove_provincie_porazeneho` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej mirove provincie porazeneho` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var out: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if _je_mirova_provincie_porazeneho(vitez_tag, porazeny_tag, d):
			out.append(int(p_id))
	return out

# Fetches data for callers.
func _ziskej_potencialni_mirove_provincie_dle_losera(porazeny_tag: String) -> Array:
	# Inputs:
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_potencialni_mirove_provincie_dle_losera` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej potencialni mirove provincie dle losera` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var loser = _normalizuj_tag(porazeny_tag)
	var out: Array = []
	if loser == "":
		return out
	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if owner_tag == "SEA":
			continue
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
		if owner_tag == loser or core_owner == loser:
			out.append(int(p_id))
	return out

# Computes derived values from current inputs and game state.
func _klic_mirovych_bodu(vitez_tag: String, porazeny_tag: String) -> String:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_klic_mirovych_bodu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` klic mirovych bodu` logic.
	# 3. Persist side effects and return the computed `String` result.
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	if vitez == "" or porazeny == "" or vitez == porazeny:
		return ""
	return "%s>%s" % [vitez, porazeny]

# Computes derived values from current inputs and game state.
func _spocitej_aktualni_body_mirove_konference(vitez_tag: String, porazeny_tag: String, reason: String = "") -> int:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `reason`: Input argument used by `_spocitej_aktualni_body_mirove_konference` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_spocitej_aktualni_body_mirove_konference` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej aktualni body mirove konference` logic.
	# 3. Persist side effects and return the computed `int` result.
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	if vitez == "" or porazeny == "" or vitez == porazeny:
		return 0

	var occupied_cores := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != vitez:
			continue
		if _normalizuj_tag(str(d.get("core_owner", ""))) == porazeny:
			occupied_cores += 1

	var body = PEACE_POINTS_BASE + (occupied_cores * PEACE_POINTS_PER_OCCUPIED_CORE)
	var porazeny_capital = _ziskej_hlavni_mesto_statu(porazeny)
	if porazeny_capital > 0 and map_data.has(porazeny_capital):
		if _normalizuj_tag(str(map_data[porazeny_capital].get("owner", ""))) == vitez:
			body += PEACE_POINTS_CAPITAL_BONUS

	if reason == "capitulation":
		body += 10

	var sila_vitez = ziskej_silu_armady_statu(vitez) as Dictionary
	var sila_porazeny = ziskej_silu_armady_statu(porazeny) as Dictionary
	var v_total = int(sila_vitez.get("total", 0))
	var p_total = int(sila_porazeny.get("total", 0))
	if v_total > p_total:
		body += min(25, int(round(float(v_total - p_total) / 1200.0)))

	return max(12, body)

# Read-only data accessor.
func _ziskej_peak_mirovych_bodu(vitez_tag: String, porazeny_tag: String) -> int:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ziskej_peak_mirovych_bodu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej peak mirovych bodu` logic.
	# 3. Persist side effects and return the computed `int` result.
	var key = _klic_mirovych_bodu(vitez_tag, porazeny_tag)
	if key == "":
		return 0
	return int(mirove_body_peak_dle_smeru.get(key, 0))

# Updates state and keeps things in sync.
func _uloz_peak_mirovych_bodu(vitez_tag: String, porazeny_tag: String, body: int) -> void:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `body`: Input argument used by `_uloz_peak_mirovych_bodu` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_uloz_peak_mirovych_bodu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` uloz peak mirovych bodu` logic.
	# 3. Persist side effects and finish without a return value.
	var key = _klic_mirovych_bodu(vitez_tag, porazeny_tag)
	if key == "":
		return
	var safe_body = max(0, int(body))
	if safe_body <= int(mirove_body_peak_dle_smeru.get(key, 0)):
		return
	mirove_body_peak_dle_smeru[key] = safe_body

# Sync update for linked values.
func _aktualizuj_peak_mirovych_bodu_pro_dvojici(tag_a: String, tag_b: String) -> void:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_aktualizuj_peak_mirovych_bodu_pro_dvojici` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` aktualizuj peak mirovych bodu pro dvojici` logic.
	# 3. Persist side effects and finish without a return value.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return
	if not jsou_ve_valce(a, b):
		return
	_uloz_peak_mirovych_bodu(a, b, _spocitej_aktualni_body_mirove_konference(a, b))
	_uloz_peak_mirovych_bodu(b, a, _spocitej_aktualni_body_mirove_konference(b, a))

func zaznamenej_okupacni_zmenu_pro_mir(tag_a: String, tag_b: String) -> void:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `zaznamenej_okupacni_zmenu_pro_mir` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `zaznamenej okupacni zmenu pro mir` logic.
	# 3. Persist side effects and finish without a return value.
	_aktualizuj_peak_mirovych_bodu_pro_dvojici(tag_a, tag_b)

# Computes derived values from current inputs and game state.
func _spocitej_body_mirove_konference(vitez_tag: String, porazeny_tag: String, reason: String = "") -> int:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `reason`: Input argument used by `_spocitej_body_mirove_konference` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_spocitej_body_mirove_konference` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej body mirove konference` logic.
	# 3. Persist side effects and return the computed `int` result.
	var aktualni = _spocitej_aktualni_body_mirove_konference(vitez_tag, porazeny_tag, reason)
	var peak = _ziskej_peak_mirovych_bodu(vitez_tag, porazeny_tag)
	return max(aktualni, peak)

# Computes derived values from current inputs and game state.
func _spocitej_cenu_mirovych_pozadavku(porazeny_tag: String, provinces_to_take: int, annex_all: bool, make_vassal: bool, reparations_turns: int) -> int:
	# Inputs:
	# - `porazeny_tag`: State tag handled by this function.
	# - `provinces_to_take`: Input argument used by `_spocitej_cenu_mirovych_pozadavku` during execution.
	# - `annex_all`: Input argument used by `_spocitej_cenu_mirovych_pozadavku` during execution.
	# - `make_vassal`: Input argument used by `_spocitej_cenu_mirovych_pozadavku` during execution.
	# - `reparations_turns`: Input argument used by `_spocitej_cenu_mirovych_pozadavku` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_spocitej_cenu_mirovych_pozadavku` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej cenu mirovych pozadavku` logic.
	# 3. Persist side effects and return the computed `int` result.
	var loser = _normalizuj_tag(porazeny_tag)
	var loser_provinces = _ziskej_potencialni_mirove_provincie_dle_losera(loser)
	var max_take = min(provinces_to_take, loser_provinces.size())
	var cost := 0
	if annex_all:
		cost += PEACE_COST_ANNEX_BASE + (loser_provinces.size() * PEACE_COST_PROVINCE)
	else:
		cost += max_take * PEACE_COST_PROVINCE
	if make_vassal:
		cost += PEACE_COST_VASSAL
	var clamped_turns = clampi(reparations_turns, 0, PEACE_MAX_REPARATIONS_TURNS)
	cost += clamped_turns * PEACE_COST_REPARATIONS_PER_TURN
	return max(0, cost)

# Computes derived values from current inputs and game state.
func spocitej_cenu_mirovych_pozadavku(porazeny_tag: String, provinces_to_take: int, annex_all: bool, make_vassal: bool, reparations_turns: int) -> int:
	# Inputs:
	# - `porazeny_tag`: State tag handled by this function.
	# - `provinces_to_take`: Input argument used by `spocitej_cenu_mirovych_pozadavku` during execution.
	# - `annex_all`: Input argument used by `spocitej_cenu_mirovych_pozadavku` during execution.
	# - `make_vassal`: Input argument used by `spocitej_cenu_mirovych_pozadavku` during execution.
	# - `reparations_turns`: Input argument used by `spocitej_cenu_mirovych_pozadavku` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `spocitej_cenu_mirovych_pozadavku` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `spocitej cenu mirovych pozadavku` logic.
	# 3. Persist side effects and return the computed `int` result.
	return _spocitej_cenu_mirovych_pozadavku(porazeny_tag, provinces_to_take, annex_all, make_vassal, reparations_turns)

# Reads values from active state.
func _ziskej_profile_statu_pro_mir(tag: String) -> Dictionary:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ziskej_profile_statu_pro_mir` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej profile statu pro mir` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var wanted = _normalizuj_tag(tag)
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != wanted:
			continue
		return {
			"country_name": str(d.get("country_name", wanted)),
			"ideology": str(d.get("ideology", ""))
		}
	# Fallback when the state has no currently owned land (fully occupied),
	# but still has core provinces on map.
	for p_id2 in map_data:
		var d2 = map_data[p_id2]
		if _normalizuj_tag(str(d2.get("core_owner", ""))) != wanted:
			continue
		return {
			"country_name": str(d2.get("country_name", wanted)),
			"ideology": str(d2.get("ideology", ""))
		}
	return {
		"country_name": wanted,
		"ideology": ""
	}

# Refreshes existing content to reflect current runtime values.
func _obnov_okupovana_uzemi_porazeneho(vitez_tag: String, porazeny_tag: String) -> int:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_obnov_okupovana_uzemi_porazeneho` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` obnov okupovana uzemi porazeneho` logic.
	# 3. Persist side effects and return the computed `int` result.
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "" or winner == loser:
		return 0

	var loser_profile = _ziskej_profile_statu_pro_mir(loser)
	var restored := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(winner, loser, d):
			continue
		if _normalizuj_tag(str(d.get("owner", ""))) == loser:
			continue
		d["owner"] = loser
		d["core_owner"] = loser
		d["country_name"] = str(loser_profile.get("country_name", loser))
		d["ideology"] = str(loser_profile.get("ideology", ""))
		d["army_owner"] = loser if int(d.get("soldiers", 0)) > 0 else ""
		restored += 1

	return restored

# Handles this gameplay/UI path.
func _anektuj_cely_stat(vitez_tag: String, porazeny_tag: String) -> Dictionary:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_anektuj_cely_stat` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` anektuj cely stat` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	var prevedeno := 0
	var profile = _ziskej_profile_statu_pro_mir(vitez)
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		prevedeno += 1

	# Ensure the winner has exactly one capital.
	var winner_capital = _ziskej_hlavni_mesto_statu(vitez)
	if winner_capital <= 0:
		var provinces = _ziskej_statove_provincie(vitez)
		if not provinces.is_empty() and map_data.has(int(provinces[0])):
			map_data[int(provinces[0])]["is_capital"] = true

	return {"transferred": prevedeno}

# Ai generated or editted start (priloha_a.txt)
func _vezmi_cast_provincii(vitez_tag: String, porazeny_tag: String, count: int) -> Dictionary:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `count`: Numeric cap controlling how many items are processed.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_vezmi_cast_provincii` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vezmi cast provincii` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	var wanted = max(0, count)
	if wanted <= 0:
		return {"transferred": 0}

	var candidates: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		var score = float(d.get("gdp", 0.0)) * 1000.0 + float(d.get("population", 0))
		if bool(d.get("is_capital", false)):
			score += 5000000.0
		candidates.append({"id": int(p_id), "score": score})

	candidates.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	var profile = _ziskej_profile_statu_pro_mir(vitez)
	var transferred := 0
	for row_any in candidates:
		if transferred >= wanted:
			break
		var row = row_any as Dictionary
		var pid = int(row.get("id", -1))
		if pid < 0 or not map_data.has(pid):
			continue
		var d = map_data[pid]
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		transferred += 1

	return {"transferred": transferred}

# Ai generated or editted start (priloha_a.txt)
func _vezmi_konkretni_provincie(vitez_tag: String, porazeny_tag: String, selected_ids: Array) -> Dictionary:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `selected_ids`: Input argument used by `_vezmi_konkretni_provincie` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_vezmi_konkretni_provincie` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vezmi konkretni provincie` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	if selected_ids.is_empty():
		return {"transferred": 0}

	var profile = _ziskej_profile_statu_pro_mir(vitez)
	var transferred := 0
	for raw_id in selected_ids:
		var pid = int(raw_id)
		if not map_data.has(pid):
			continue
		var d = map_data[pid]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		transferred += 1

	return {"transferred": transferred}

# Ai generated or editted end (priloha_a.txt)
func _nastav_vazala(overlord_tag: String, subject_tag: String) -> void:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_nastav_vazala` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` nastav vazala` logic.
	# 3. Persist side effects and finish without a return value.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "" or overlord == subject:
		return
	vazalske_vztahy[subject] = overlord
	vazalske_odvody[subject] = float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE))
	_uprav_vztah_statu_bez_cooldown(overlord, subject, 35.0)
	nastav_uroven_aliance(overlord, subject, ALLIANCE_FULL, true)
	if not ma_neagresivni_smlouvu(overlord, subject):
		uzavrit_neagresivni_smlouvu(overlord, subject)

# Runs the local feature logic.
func _uzavri_valky_statu_krome(state_tag: String, except_tags: Array = []) -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `except_tags`: Input argument used by `_uzavri_valky_statu_krome` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_uzavri_valky_statu_krome` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` uzavri valky statu krome` logic.
	# 3. Persist side effects and finish without a return value.
	var state = _normalizuj_tag(state_tag)
	if state == "":
		return

	var ignore: Dictionary = {}
	for raw in except_tags:
		var tag = _normalizuj_tag(str(raw))
		if tag != "":
			ignore[tag] = true

	var enemies: Array = []
	for key_any in valky.keys():
		var key = str(key_any)
		var sep = key.find("_")
		if sep <= 0 or sep >= key.length() - 1:
			continue
		var a = _normalizuj_tag(key.substr(0, sep))
		var b = _normalizuj_tag(key.substr(sep + 1))
		if a == state and b != "" and not enemies.has(b):
			enemies.append(b)
		elif b == state and a != "" and not enemies.has(a):
			enemies.append(a)

	for enemy_any in enemies:
		var enemy = _normalizuj_tag(str(enemy_any))
		if enemy == "" or ignore.has(enemy):
			continue
		_uzavri_mir_mezi(state, enemy, true)

# Handles this gameplay/UI path.
func _pridej_valecne_reparace(from_tag: String, to_tag: String, turns: int) -> void:
	# Inputs:
	# - `from_tag`: State tag handled by this function.
	# - `to_tag`: State tag handled by this function.
	# - `turns`: Input argument used by `_pridej_valecne_reparace` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_pridej_valecne_reparace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` pridej valecne reparace` logic.
	# 3. Persist side effects and finish without a return value.
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	var t = clampi(turns, 0, PEACE_MAX_REPARATIONS_TURNS)
	if from_clean == "" or to_clean == "" or from_clean == to_clean or t <= 0:
		return
	valecne_reparace.append({
		"from": from_clean,
		"to": to_clean,
		"remaining_turns": t,
		"rate": WAR_REPARATIONS_RATE
	})

# Computes derived values from current inputs and game state.
func _spocitej_cisty_prijem_statu(tag: String) -> float:
	# This is the "base net" economy used by AI and projections.
	# Cross-state money flows (vassals, loans, reparations) are applied later.
	var state = _normalizuj_tag(tag)
	if state == "" or state == "SEA":
		return 0.0
	var hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		hdp += float(d.get("gdp", 0.0))
	var income_rate = ziskej_prijmovou_sazbu_hdp(state)
	return (hdp * income_rate) - _spocitej_naklady_udrzby_statu(state)

# Computes the tribute base from profit before vassal payments are deducted.
func _spocitej_profit_income_pro_vazalsky_odvod(state_tag: String, projected_row: Dictionary = {}) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `projected_row`: Input argument used by `_spocitej_profit_income_pro_vazalsky_odvod` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_spocitej_profit_income_pro_vazalsky_odvod`.
	# Execution timing: Called when game flow invokes `_spocitej_profit_income_pro_vazalsky_odvod` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej profit income pro vazalsky odvod` logic.
	# 3. Persist side effects and return the computed `float` result.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return 0.0
	var row = projected_row
	if row.is_empty():
		var projection = _simuluj_financni_toky_aktualniho_tahu()
		var projected_states = projection.get("states", {}) as Dictionary
		row = projected_states.get(state, {}) as Dictionary
	var base_income = _spocitej_cisty_prijem_statu(state)
	var reparations_delta = float(row.get("reparations_in", 0.0)) - float(row.get("reparations_out", 0.0))
	return max(0.0, base_income + reparations_delta)

# Pulls current state data.
func _ziskej_staty_pro_financni_projekci() -> Array:
	# Inputs:
	# - none.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_staty_pro_financni_projekci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej staty pro financni projekci` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var states: Dictionary = {}
	for raw_tag in _ziskej_aktivni_staty():
		var clean = _normalizuj_tag(str(raw_tag))
		if clean != "" and clean != "SEA":
			states[clean] = true
	for raw_tag in lokalni_hraci_staty:
		var local_clean = _normalizuj_tag(str(raw_tag))
		if local_clean != "" and local_clean != "SEA":
			states[local_clean] = true
	var active_player = _normalizuj_tag(hrac_stat)
	if active_player != "" and active_player != "SEA":
		states[active_player] = true
	for subject_any in vazalske_vztahy.keys():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject != "" and subject != "SEA":
			states[subject] = true
		if overlord != "" and overlord != "SEA":
			states[overlord] = true
	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		if from_tag != "" and from_tag != "SEA":
			states[from_tag] = true
		if to_tag != "" and to_tag != "SEA":
			states[to_tag] = true
	for loan_any in aktivni_pujcky:
		var loan = loan_any as Dictionary
		var lender = _normalizuj_tag(str(loan.get("lender", "")))
		var borrower = _normalizuj_tag(str(loan.get("borrower", "")))
		if lender != "" and lender != "SEA":
			states[lender] = true
		if borrower != "" and borrower != "SEA":
			states[borrower] = true
	return states.keys()

# Returns true when conditions are met.
func _ma_prijem_pred_toky_v_aktualnim_tahu(state_tag: String) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_prijem_pred_toky_v_aktualnim_tahu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma prijem pred toky v aktualnim tahu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return false
	if lokalni_hraci_staty.size() > 1:
		for raw_tag in lokalni_hraci_staty:
			if _normalizuj_tag(str(raw_tag)) == state:
				return true
		return false
	return state == _normalizuj_tag(hrac_stat)

# Fetches data for callers.
func _ziskej_urokovou_cast_splatky_pujcky(loan: Dictionary, paid_this_turn: float) -> float:
	# Inputs:
	# - `loan`: Input argument used by `_ziskej_urokovou_cast_splatky_pujcky` during execution.
	# - `paid_this_turn`: Input argument used by `_ziskej_urokovou_cast_splatky_pujcky` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ziskej_urokovou_cast_splatky_pujcky`.
	# Execution timing: Called when game flow invokes `_ziskej_urokovou_cast_splatky_pujcky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej urokovou cast splatky pujcky` logic.
	# 3. Persist side effects and return the computed `float` result.
	return economy_loan_calculator.interest_part(loan, paid_this_turn)

# Read-only data accessor.
func _ziskej_vychozi_kasu_pro_financni_projekci(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ziskej_vychozi_kasu_pro_financni_projekci`.
	# Execution timing: Called when game flow invokes `_ziskej_vychozi_kasu_pro_financni_projekci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej vychozi kasu pro financni projekci` logic.
	# 3. Persist side effects and return the computed `float` result.
	var state = _normalizuj_tag(state_tag)
	if state == "":
		return 0.0
	if _finance_projection_cash_overrides.has(state):
		return float(_finance_projection_cash_overrides[state])
	return _ziskej_kasu_statu(state)

# Core flow for this feature.
func _simuluj_financni_toky_aktualniho_tahu() -> Dictionary:
	# Inputs:
	# - none.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_simuluj_financni_toky_aktualniho_tahu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` simuluj financni toky aktualniho tahu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if _finance_projection_cash_overrides.is_empty() and _sim_cache_validni:
		return _sim_cache
	var state_rows: Dictionary = {}
	for state_any in _ziskej_staty_pro_financni_projekci():
		var state = _normalizuj_tag(str(state_any))
		if state == "" or state == "SEA":
			continue
		var cash_before = _ziskej_vychozi_kasu_pro_financni_projekci(state)
		var base_income = _spocitej_cisty_prijem_statu(state)
		var applied_base_income = base_income if _ma_prijem_pred_toky_v_aktualnim_tahu(state) else 0.0
		state_rows[state] = {
			"cash_before": cash_before,
			"base_income": base_income,
			"base_income_applied": applied_base_income,
			"cash_work": cash_before + applied_base_income,
			"cash_after_base": cash_before + applied_base_income,
			"vassal_in": 0.0,
			"vassal_out": 0.0,
			"reparations_in": 0.0,
			"reparations_out": 0.0,
			"loan_interest_in": 0.0,
			"loan_interest_out": 0.0,
			"loan_principal_in": 0.0,
			"loan_principal_out": 0.0,
			"loan_payment_in": 0.0,
			"loan_payment_out": 0.0,
			"vassal_in_details": {},
			"vassal_out_details": {}
		}

	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if remaining <= 0 or from_tag == "" or to_tag == "" or from_tag == to_tag:
			continue
		if not state_rows.has(from_tag) or not state_rows.has(to_tag):
			continue
		var rate = clamp(float(rep.get("rate", WAR_REPARATIONS_RATE)), 0.01, 0.50)
		var base_income = max(0.0, _spocitej_cisty_prijem_statu(from_tag))
		var planned = max(WAR_REPARATIONS_MIN_PAYMENT, base_income * rate)
		var from_row = state_rows[from_tag] as Dictionary
		var to_row = state_rows[to_tag] as Dictionary
		var from_cash = float(from_row.get("cash_work", 0.0))
		var paid = clamp(planned, 0.0, max(0.0, from_cash + 100.0))
		if paid <= 0.0:
			continue
		from_row["cash_work"] = from_cash - paid
		to_row["cash_work"] = float(to_row.get("cash_work", 0.0)) + paid
		from_row["reparations_out"] = float(from_row.get("reparations_out", 0.0)) + paid
		to_row["reparations_in"] = float(to_row.get("reparations_in", 0.0)) + paid
		state_rows[from_tag] = from_row
		state_rows[to_tag] = to_row

	for subject_any in vazalske_vztahy.keys().duplicate():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or overlord == "" or subject == overlord:
			continue
		if not state_rows.has(subject) or not state_rows.has(overlord):
			continue
		var rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
		var subject_row = state_rows[subject] as Dictionary
		var overlord_row = state_rows[overlord] as Dictionary
		var subject_profit_income = _spocitej_profit_income_pro_vazalsky_odvod(subject, subject_row)
		var planned = subject_profit_income * rate
		if planned <= 0.0:
			continue
		var subject_cash = float(subject_row.get("cash_work", 0.0))
		var paid = clamp(planned, 0.0, max(0.0, subject_cash))
		if paid <= 0.0:
			continue
		subject_row["cash_work"] = subject_cash - paid
		overlord_row["cash_work"] = float(overlord_row.get("cash_work", 0.0)) + paid
		subject_row["vassal_out"] = float(subject_row.get("vassal_out", 0.0)) + paid
		overlord_row["vassal_in"] = float(overlord_row.get("vassal_in", 0.0)) + paid
		var subject_out_details = (subject_row.get("vassal_out_details", {}) as Dictionary).duplicate(true)
		subject_out_details[overlord] = paid
		subject_row["vassal_out_details"] = subject_out_details
		var overlord_in_details = (overlord_row.get("vassal_in_details", {}) as Dictionary).duplicate(true)
		overlord_in_details[subject] = paid
		overlord_row["vassal_in_details"] = overlord_in_details
		state_rows[subject] = subject_row
		state_rows[overlord] = overlord_row

	for loan_any in aktivni_pujcky:
		var loan = _normalizuj_loan_na_celkovy_urok_model(loan_any as Dictionary)
		var lender = _normalizuj_tag(str(loan.get("lender", "")))
		var borrower = _normalizuj_tag(str(loan.get("borrower", "")))
		var created_turn = int(loan.get("created_turn", -1))
		var remaining_turns = int(loan.get("remaining_turns", 0))
		var remaining_due = max(0.0, float(loan.get("remaining_due", 0.0)))
		var installment = max(0.0, float(loan.get("installment", 0.0)))
		if lender == "" or borrower == "" or lender == borrower:
			continue
		# New loan should grant principal first; first installment starts next turn.
		if created_turn == aktualni_kolo:
			continue
		if remaining_turns <= 0 or remaining_due <= 0.0001:
			continue
		if not state_rows.has(lender) or not state_rows.has(borrower):
			continue
		var due_this_turn = min(remaining_due, installment)
		var borrower_row = state_rows[borrower] as Dictionary
		var lender_row = state_rows[lender] as Dictionary
		var borrower_cash = float(borrower_row.get("cash_work", 0.0))
		var paid = clamp(due_this_turn, 0.0, max(0.0, borrower_cash + 100.0))
		if paid <= 0.0:
			continue
		var interest_paid = _ziskej_urokovou_cast_splatky_pujcky(loan, paid)
		var principal_paid = max(0.0, paid - interest_paid)
		borrower_row["cash_work"] = borrower_cash - paid
		lender_row["cash_work"] = float(lender_row.get("cash_work", 0.0)) + paid
		borrower_row["loan_payment_out"] = float(borrower_row.get("loan_payment_out", 0.0)) + paid
		lender_row["loan_payment_in"] = float(lender_row.get("loan_payment_in", 0.0)) + paid
		borrower_row["loan_interest_out"] = float(borrower_row.get("loan_interest_out", 0.0)) + interest_paid
		lender_row["loan_interest_in"] = float(lender_row.get("loan_interest_in", 0.0)) + interest_paid
		borrower_row["loan_principal_out"] = float(borrower_row.get("loan_principal_out", 0.0)) + principal_paid
		lender_row["loan_principal_in"] = float(lender_row.get("loan_principal_in", 0.0)) + principal_paid
		state_rows[borrower] = borrower_row
		state_rows[lender] = lender_row

	for state in state_rows.keys():
		var row = state_rows[state] as Dictionary
		var cash_before = float(row.get("cash_before", 0.0))
		var cash_after = float(row.get("cash_work", cash_before))
		row["cash_after"] = cash_after
		row["cashflow"] = cash_after - cash_before
		state_rows[state] = row

	var vysledek = {"states": state_rows}
	if _finance_projection_cash_overrides.is_empty():
		_sim_cache = vysledek
		_sim_cache_validni = true
	return vysledek

# Pulls current state data.
func ziskej_cisty_prijem_statu(tag: String) -> float:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `ziskej_cisty_prijem_statu`.
	# Execution timing: Called when game flow invokes `ziskej_cisty_prijem_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej cisty prijem statu` logic.
	# 3. Persist side effects and return the computed `float` result.
	return _spocitej_cisty_prijem_statu(tag)

# Pulls current state data.
func ziskej_financni_rozpad_statu(state_tag: String = "") -> Dictionary:
	# Financial breakdown combines base economy with projected flow simulation.
	# `profit` is structural balance, while `cashflow` includes transfer timing.
	var state = _normalizuj_tag(state_tag)
	if state == "":
		state = _normalizuj_tag(hrac_stat)
	if state == "" or state == "SEA":
		return {
			"ok": false,
			"reason": "Invalid state."
		}
	var projection = _simuluj_financni_toky_aktualniho_tahu()
	var projected_states = projection.get("states", {}) as Dictionary
	var projected = projected_states.get(state, {}) as Dictionary

	var celkove_hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		celkove_hdp += float(d.get("gdp", 0.0))

	var prijmova_sazba = ziskej_prijmovou_sazbu_hdp(state)
	var prijem_hdp = celkove_hdp * prijmova_sazba
	var vydaj_armada = _spocitej_naklady_udrzby_statu(state)

	var prijem_vazalove := float(projected.get("vassal_in", 0.0))
	var vydaj_vazalsky_odvod := float(projected.get("vassal_out", 0.0))
	var prijem_reparace := float(projected.get("reparations_in", 0.0))
	var vydaj_reparace := float(projected.get("reparations_out", 0.0))
	var prijem_ostatni := 0.0
	var vydaj_investice := 0.0
	var prijem_uroky_pujcky := float(projected.get("loan_interest_in", 0.0))
	var vydaj_uroky_pujcky := float(projected.get("loan_interest_out", 0.0))
	var prijem_jistina_pujcky := float(projected.get("loan_principal_in", 0.0))
	var vydaj_jistina_pujcky := float(projected.get("loan_principal_out", 0.0))

	var vydaj_ostatni := vydaj_vazalsky_odvod + vydaj_reparace

	var celkove_prijmy = prijem_hdp + prijem_vazalove + prijem_reparace + prijem_ostatni + prijem_uroky_pujcky
	var celkove_vydaje = vydaj_armada + vydaj_investice + vydaj_ostatni + vydaj_uroky_pujcky
	var profit = celkove_prijmy - celkove_vydaje
	var cashflow = float(projected.get("cashflow", profit))

	return {
		"ok": true,
		"state": state,
		"income": {
			"gdp": prijem_hdp,
			"vassals": prijem_vazalove,
			"reparations": prijem_reparace,
			"loan_interest": prijem_uroky_pujcky,
			"loan_principal": prijem_jistina_pujcky,
			"other": prijem_ostatni,
			"total": celkove_prijmy
		},
		"expenses": {
			"army_upkeep": vydaj_armada,
			"investments": vydaj_investice,
			"loan_interest": vydaj_uroky_pujcky,
			"loan_principal": vydaj_jistina_pujcky,
			"other": vydaj_ostatni,
			"total": celkove_vydaje
		},
		"profit": profit,
		"cashflow": cashflow,
		"cash": _ziskej_kasu_statu(state),
		"base_net_income": (prijem_hdp - vydaj_armada),
		"projected_net_income": cashflow
	}

# Reads values from active state.
func ziskej_projektovany_vazalsky_odvod(overlord_tag: String, subject_tag: String) -> Dictionary:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_projektovany_vazalsky_odvod` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej projektovany vazalsky odvod` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return {"ok": false, "reason": "Invalid state."}
	if ziskej_overlorda_statu(subject) != overlord:
		return {"ok": false, "reason": "Not a valid vassal relation."}
	var rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
	var projection = _simuluj_financni_toky_aktualniho_tahu()
	var states = projection.get("states", {}) as Dictionary
	var subject_row = states.get(subject, {}) as Dictionary
	var profit_income = _spocitej_profit_income_pro_vazalsky_odvod(subject, subject_row)
	var planned = profit_income * rate
	var paid = float((subject_row.get("vassal_out_details", {}) as Dictionary).get(overlord, 0.0))
	return {
		"ok": true,
		"rate": rate,
		"profit_income": profit_income,
		"planned": planned,
		"paid": paid
	}

# Public accessor for UI preview parity.
func ziskej_profit_income_pro_vazalsky_odvod(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `ziskej_profit_income_pro_vazalsky_odvod`.
	# Execution timing: Called when game flow invokes `ziskej_profit_income_pro_vazalsky_odvod` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej profit income pro vazalsky odvod` logic.
	# 3. Persist side effects and return the computed `float` result.
	return _spocitej_profit_income_pro_vazalsky_odvod(state_tag)

# Pulls current state data.
func ziskej_vazalsky_odvod(overlord_tag: String, subject_tag: String) -> float:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `ziskej_vazalsky_odvod`.
	# Execution timing: Called when game flow invokes `ziskej_vazalsky_odvod` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej vazalsky odvod` logic.
	# 3. Persist side effects and return the computed `float` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return 0.0
	if ziskej_overlorda_statu(subject) != overlord:
		return 0.0
	var rate = float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE))
	return clamp(rate, VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)

# Sync update for linked values.
func nastav_vazalsky_odvod(overlord_tag: String, subject_tag: String, procenta: float) -> bool:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# - `procenta`: Input argument used by `nastav_vazalsky_odvod` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `nastav_vazalsky_odvod` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav vazalsky odvod` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return false
	if ziskej_overlorda_statu(subject) != overlord:
		return false
	var rate = clamp(float(procenta) / 100.0, VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
	var current_rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
	if is_equal_approx(current_rate, rate):
		return true
	if ziskej_zbyvajici_cooldown_vazalskeho_odvodu(overlord, subject) > 0:
		return false
	vazalske_odvody[subject] = rate
	vazalske_odvody_posledni_zmena_kolo[subject] = aktualni_kolo
	return true

# Pulls current state data.
func ziskej_zbyvajici_cooldown_vazalskeho_odvodu(overlord_tag: String, subject_tag: String) -> int:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `ziskej_zbyvajici_cooldown_vazalskeho_odvodu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej zbyvajici cooldown vazalskeho odvodu` logic.
	# 3. Persist side effects and return the computed `int` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return 0
	if ziskej_overlorda_statu(subject) != overlord:
		return 0
	var last_turn = int(vazalske_odvody_posledni_zmena_kolo.get(subject, -1000000))
	if last_turn < 0:
		return 0
	var turns_passed = max(0, aktualni_kolo - last_turn)
	return maxi(0, VASSAL_TRIBUTE_CHANGE_COOLDOWN_TURNS - turns_passed)

# Runs the local feature logic.
func _zpracuj_vazalske_odvody_za_kolo() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zpracuj_vazalske_odvody_za_kolo` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj vazalske odvody za kolo` logic.
	# 3. Persist side effects and finish without a return value.
	if vazalske_vztahy.is_empty():
		return
	for subject_any in vazalske_vztahy.keys().duplicate():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or overlord == "" or subject == overlord:
			continue
		if not _stat_existuje(subject) or not _stat_existuje(overlord):
			continue

		var rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
		var subject_profit_income = _spocitej_profit_income_pro_vazalsky_odvod(subject)
		var planned = subject_profit_income * rate
		if planned <= 0.0:
			continue
		var subject_cash = _ziskej_kasu_statu(subject)
		var paid = clamp(planned, 0.0, max(0.0, subject_cash))
		if paid <= 0.0:
			continue
		_nastav_kasu_statu(subject, subject_cash - paid)
		_nastav_kasu_statu(overlord, _ziskej_kasu_statu(overlord) + paid)

# Core flow for this feature.
func _zpracuj_valecne_reparace_za_kolo() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zpracuj_valecne_reparace_za_kolo` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj valecne reparace za kolo` logic.
	# 3. Persist side effects and finish without a return value.
	if valecne_reparace.is_empty():
		return

	var active: Array = []
	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if from_tag == "" or to_tag == "" or from_tag == to_tag or remaining <= 0:
			continue
		if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
			continue

		var rate = clamp(float(rep.get("rate", WAR_REPARATIONS_RATE)), 0.01, 0.50)
		var base_income = max(0.0, _spocitej_cisty_prijem_statu(from_tag))
		var planned = max(WAR_REPARATIONS_MIN_PAYMENT, base_income * rate)
		var from_cash = _ziskej_kasu_statu(from_tag)
		var paid = clamp(planned, 0.0, max(0.0, from_cash + 100.0))
		if paid > 0.0:
			_nastav_kasu_statu(from_tag, from_cash - paid)
			_nastav_kasu_statu(to_tag, _ziskej_kasu_statu(to_tag) + paid)

		rep["remaining_turns"] = remaining - 1
		if int(rep.get("remaining_turns", 0)) > 0:
			active.append(rep)

	valecne_reparace = active

func _zpracuj_aktivni_pujcky_za_kolo() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zpracuj_aktivni_pujcky_za_kolo` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj aktivni pujcky za kolo` logic.
	# 3. Persist side effects and finish without a return value.
	if aktivni_pujcky.is_empty():
		return

	var active: Array = []
	for loan_any in aktivni_pujcky:
		var loan = _normalizuj_loan_na_celkovy_urok_model(loan_any as Dictionary)
		var lender = _normalizuj_tag(str(loan.get("lender", "")))
		var borrower = _normalizuj_tag(str(loan.get("borrower", "")))
		var created_turn = int(loan.get("created_turn", -1))
		var remaining_turns = int(loan.get("remaining_turns", 0))
		var remaining_due = max(0.0, float(loan.get("remaining_due", 0.0)))
		var installment = max(0.0, float(loan.get("installment", 0.0)))
		if lender == "" or borrower == "" or lender == borrower:
			continue
		# Do not collect installments on the same turn the loan is created.
		if created_turn == aktualni_kolo:
			active.append(loan)
			continue
		if remaining_turns <= 0 or remaining_due <= 0.0001:
			continue
		if not _stat_existuje(lender) or not _stat_existuje(borrower):
			continue

		var due_this_turn = min(remaining_due, installment)
		var borrower_cash = _ziskej_kasu_statu(borrower)
		var paid = clamp(due_this_turn, 0.0, max(0.0, borrower_cash + 100.0))

		if paid > 0.0:
			_nastav_kasu_statu(borrower, borrower_cash - paid)
			_nastav_kasu_statu(lender, _ziskej_kasu_statu(lender) + paid)

		if paid + 0.0001 < due_this_turn:
			var default_msg = "%s defaulted on loan payment to %s (paid %.2f / %.2f mil. USD)." % [borrower, lender, paid, due_this_turn]
			_zaloguj_globalni_zpravu("Loans", default_msg, "trade")
			if je_lidsky_stat(lender) or je_lidsky_stat(borrower):
				_pridej_popup_zucastnenym_hracum(lender, borrower, "Loans", default_msg)
			_uprav_vztah_statu_bez_cooldown(borrower, lender, -clamp((due_this_turn - paid) / 20.0, 2.0, 18.0))
			continue

		remaining_due = max(0.0, remaining_due - paid)
		remaining_turns -= 1

		if remaining_due <= 0.0001 or remaining_turns <= 0:
			var paid_off_msg = "%s fully repaid loan to %s." % [borrower, lender]
			_zaloguj_globalni_zpravu("Loans", paid_off_msg, "trade")
			if je_lidsky_stat(lender) or je_lidsky_stat(borrower):
				_pridej_popup_zucastnenym_hracum(lender, borrower, "Loans", paid_off_msg)
			_uprav_vztah_statu_bez_cooldown(borrower, lender, 2.0)
			continue

		loan["remaining_due"] = remaining_due
		loan["remaining_turns"] = remaining_turns
		active.append(loan)

	aktivni_pujcky = active

# Handles this gameplay/UI path.
func _odstran_neplatne_mirove_konference() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_odstran_neplatne_mirove_konference` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` odstran neplatne mirove konference` logic.
	# 3. Persist side effects and finish without a return value.
	var keys = cekajici_mirove_konference.keys().duplicate()
	for k in keys:
		var player_tag = _normalizuj_tag(str(k))
		if player_tag == "" or not cekajici_mirove_konference.has(k):
			cekajici_mirove_konference.erase(k)
			continue
		var queue = cekajici_mirove_konference[k] as Array
		for i in range(queue.size() - 1, -1, -1):
			var item = queue[i] as Dictionary
			var winner = _normalizuj_tag(str(item.get("winner", "")))
			var loser = _normalizuj_tag(str(item.get("loser", "")))
			if winner == "" or loser == "" or winner == loser:
				queue.remove_at(i)
				continue
			if not _stat_existuje(winner) and not _stat_existuje(loser):
				queue.remove_at(i)
		if queue.is_empty():
			cekajici_mirove_konference.erase(k)

# Construct/setup block for required nodes.
func _vytvor_mirovou_konferenci(vitez_tag: String, porazeny_tag: String, reason: String = "peace") -> Dictionary:
	# Inputs:
	# - `vitez_tag`: State tag handled by this function.
	# - `porazeny_tag`: State tag handled by this function.
	# - `reason`: Input argument used by `_vytvor_mirovou_konferenci` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_vytvor_mirovou_konferenci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vytvor mirovou konferenci` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "" or winner == loser:
		return {}

	mirove_konference_seq += 1
	_aktualizuj_peak_mirovych_bodu_pro_dvojici(winner, loser)
	var points = _spocitej_body_mirove_konference(winner, loser, reason)
	var loser_provinces = _ziskej_mirove_provincie_porazeneho(winner, loser)
	return {
		"id": mirove_konference_seq,
		"winner": winner,
		"loser": loser,
		"reason": reason,
		"points": points,
		"loser_province_count": loser_provinces.size(),
		"max_reparations_turns": PEACE_MAX_REPARATIONS_TURNS
	}

# Handles this gameplay/UI path.
func _auto_navrh_mirovych_podminek(conf: Dictionary) -> Dictionary:
	# Inputs:
	# - `conf`: Input argument used by `_auto_navrh_mirovych_podminek` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_auto_navrh_mirovych_podminek` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` auto navrh mirovych podminek` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var points = int(conf.get("points", 0))
	var loser_count = int(conf.get("loser_province_count", 0))
	var take_count = min(loser_count, int(points / max(1, PEACE_COST_PROVINCE)))
	var annex_cost = _spocitej_cenu_mirovych_pozadavku(str(conf.get("loser", "")), 0, true, false, 0)
	var annex_all = points >= annex_cost and loser_count <= 7
	var vassal = (not annex_all) and points >= (PEACE_COST_VASSAL + PEACE_COST_PROVINCE)
	var remaining = max(0, points - _spocitej_cenu_mirovych_pozadavku(str(conf.get("loser", "")), take_count if not annex_all else 0, annex_all, vassal, 0))
	var repar_turns = min(PEACE_MAX_REPARATIONS_TURNS, int(remaining / max(1, PEACE_COST_REPARATIONS_PER_TURN)))
	return {
		"take_provinces": 0 if annex_all else take_count,
		"annex_all": annex_all,
		"make_vassal": vassal,
		"reparations_turns": repar_turns
	}

func _proved_mirovou_konferenci(conf: Dictionary, demands: Dictionary) -> Dictionary:
	# Inputs:
	# - `conf`: Input argument used by `_proved_mirovou_konferenci` during execution.
	# - `demands`: Input argument used by `_proved_mirovou_konferenci` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_proved_mirovou_konferenci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` proved mirovou konferenci` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var winner = _normalizuj_tag(str(conf.get("winner", "")))
	var loser = _normalizuj_tag(str(conf.get("loser", "")))
	if winner == "" or loser == "" or winner == loser:
		return {"ok": false, "reason": "Invalid peace conference."}

	var points = int(conf.get("points", 0))
	var annex_all = bool(demands.get("annex_all", false))
	var take_count = int(demands.get("take_provinces", 0))
	var selected_raw = (demands.get("selected_provinces", []) as Array).duplicate()
	var selected_provinces: Array = []
	for raw_id in selected_raw:
		var pid = int(raw_id)
		if not map_data.has(pid):
			continue
		if selected_provinces.has(pid):
			continue
		var pd = map_data[pid]
		if not _je_mirova_provincie_porazeneho(winner, loser, pd):
			continue
		selected_provinces.append(pid)
	var make_vassal = bool(demands.get("make_vassal", false))
	var repar_turns = int(demands.get("reparations_turns", 0))
	if not annex_all and not selected_provinces.is_empty():
		take_count = selected_provinces.size()

	var cost = _spocitej_cenu_mirovych_pozadavku(loser, take_count, annex_all, make_vassal, repar_turns)
	if cost > points:
		return {"ok": false, "reason": "Not enough conference points.", "cost": cost, "points": points}

	var transferred := 0
	if annex_all:
		var annex_result = _anektuj_cely_stat(winner, loser)
		transferred = int(annex_result.get("transferred", 0))
	else:
		# Return occupied provinces to the loser first, then apply exact player demands.
		# This allows shaping peace terms (including giving back occupied capital).
		_obnov_okupovana_uzemi_porazeneho(winner, loser)
		var partial_result: Dictionary
		if not selected_provinces.is_empty():
			partial_result = _vezmi_konkretni_provincie(winner, loser, selected_provinces)
		else:
			partial_result = _vezmi_cast_provincii(winner, loser, take_count)
		transferred = int(partial_result.get("transferred", 0))

	if make_vassal and _stat_existuje(loser):
		_nastav_vazala(winner, loser)
		# Protectorate outcome: third-party wars against the new vassal must stop.
		_uzavri_valky_statu_krome(loser, [winner])
		var map_loader_after_vassal = _get_map_loader()
		if map_loader_after_vassal and map_loader_after_vassal.has_method("zrus_cekajici_utoky_na_stat"):
			map_loader_after_vassal.zrus_cekajici_utoky_na_stat(loser)
	if repar_turns > 0 and _stat_existuje(loser):
		_pridej_valecne_reparace(loser, winner, repar_turns)

	if not _stat_existuje(loser):
		vycisti_stat_po_kapitulaci(loser)

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()

	_invalidate_turn_cache()
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	var msg = "%s used peace points against %s (cost %d/%d)." % [winner, loser, cost, points]
	_zaloguj_globalni_zpravu("War", msg, "war")
	return {
		"ok": true,
		"winner": winner,
		"loser": loser,
		"points": points,
		"cost": cost,
		"transferred": transferred,
		"annex_all": annex_all,
		"make_vassal": make_vassal,
		"reparations_turns": repar_turns
	}

# Core flow for this feature.
func uzavri_mir_a_zahaj_konferenci(tag1: String, tag2: String, reason: String = "peace") -> Dictionary:
	# Inputs:
	# - `tag1`: Input argument used by `uzavri_mir_a_zahaj_konferenci` during execution.
	# - `tag2`: Input argument used by `uzavri_mir_a_zahaj_konferenci` during execution.
	# - `reason`: Input argument used by `uzavri_mir_a_zahaj_konferenci` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `uzavri_mir_a_zahaj_konferenci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `uzavri mir a zahaj konferenci` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var a = _normalizuj_tag(tag1)
	var b = _normalizuj_tag(tag2)
	if a == "" or b == "" or a == b:
		return {"ok": false, "reason": "Invalid states."}

	var conf_a = _vytvor_mirovou_konferenci(a, b, reason)
	var conf_b = _vytvor_mirovou_konferenci(b, a, reason)
	# Keep occupation/core state intact until conference demands are finalized,
	# so the winner can return occupied land (including captured capitals).
	_uzavri_mir_mezi(a, b, false)
	var winner_conf = conf_a if int(conf_a.get("points", 0)) >= int(conf_b.get("points", 0)) else conf_b
	if winner_conf.is_empty():
		return {"ok": false, "reason": "Failed to prepare peace conference."}

	var winner = _normalizuj_tag(str(winner_conf.get("winner", "")))
	if je_lidsky_stat(winner):
		if not cekajici_mirove_konference.has(winner):
			cekajici_mirove_konference[winner] = []
		(cekajici_mirove_konference[winner] as Array).append(winner_conf)
		_pridej_popup_hraci(winner, "Peace Conference", "After the war with %s, you can set demands (points: %d)." % [str(winner_conf.get("loser", "?")), int(winner_conf.get("points", 0))])
		return {"ok": true, "queued_for_player": true, "conference": winner_conf}

	var auto_demands = _auto_navrh_mirovych_podminek(winner_conf)
	var result = _proved_mirovou_konferenci(winner_conf, auto_demands)
	result["queued_for_player"] = false
	return result

# Reads values from active state.
func ziskej_prvni_mirovou_konferenci_pro_hrace(hrac_tag: String) -> Dictionary:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_prvni_mirovou_konferenci_pro_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej prvni mirovou konferenci pro hrace` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	_odstran_neplatne_mirove_konference()
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return {}
	var queue = cekajici_mirove_konference[player] as Array
	if queue.is_empty():
		return {}
	return (queue[0] as Dictionary).duplicate(true)

# Returns current runtime data.
func ziskej_pocet_mirovych_konferenci_pro_hrace(hrac_tag: String) -> int:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `ziskej_pocet_mirovych_konferenci_pro_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej pocet mirovych konferenci pro hrace` logic.
	# 3. Persist side effects and return the computed `int` result.
	_odstran_neplatne_mirove_konference()
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return 0
	var queue = cekajici_mirove_konference[player] as Array
	return queue.size()

# Returns true when conditions are met.
func ma_cekajici_mirovou_konferenci_pro_stat(stat_tag: String) -> bool:
	# Inputs:
	# - `stat_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `ma_cekajici_mirovou_konferenci_pro_stat` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ma cekajici mirovou konferenci pro stat` logic.
	# 3. Persist side effects and return the computed `bool` result.
	_odstran_neplatne_mirove_konference()
	var wanted = _normalizuj_tag(stat_tag)
	if wanted == "":
		return false
	for key_any in cekajici_mirove_konference.keys():
		var queue = cekajici_mirove_konference[key_any] as Array
		for item_any in queue:
			var item = item_any as Dictionary
			var winner = _normalizuj_tag(str(item.get("winner", "")))
			var loser = _normalizuj_tag(str(item.get("loser", "")))
			if winner == wanted or loser == wanted:
				return true
	return false

# Ai generated or editted start (priloha_a.txt)
func hrac_uzavri_mirovou_konferenci(hrac_tag: String, conference_id: int, demands: Dictionary) -> Dictionary:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# - `conference_id`: Input argument used by `hrac_uzavri_mirovou_konferenci` during execution.
	# - `demands`: Input argument used by `hrac_uzavri_mirovou_konferenci` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `hrac_uzavri_mirovou_konferenci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac uzavri mirovou konferenci` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return {"ok": false, "reason": "No pending peace conference found."}
	var queue = cekajici_mirove_konference[player] as Array
	var idx := -1
	for i in range(queue.size()):
		if int((queue[i] as Dictionary).get("id", -1)) == conference_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "Conference is no longer available."}

	var conf = queue[idx] as Dictionary
	if _normalizuj_tag(str(conf.get("winner", ""))) != player:
		return {"ok": false, "reason": "Only the conference winner can confirm terms."}

	var result = _proved_mirovou_konferenci(conf, demands)
	if bool(result.get("ok", false)):
		queue.remove_at(idx)
		if queue.is_empty():
			cekajici_mirove_konference.erase(player)
	return result

# Ai generated or editted end (priloha_a.txt)
func ziskej_vazaly_statu(overlord_tag: String) -> Array:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_vazaly_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej vazaly statu` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var out: Array = []
	if overlord == "":
		return out
	for subject_any in vazalske_vztahy.keys():
		var subject = _normalizuj_tag(str(subject_any))
		var lord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or lord == "":
			continue
		if lord == overlord:
			out.append(subject)
	out.sort()
	return out

# Returns current runtime data.
func ziskej_overlorda_statu(subject_tag: String) -> String:
	# Inputs:
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `ziskej_overlorda_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej overlorda statu` logic.
	# 3. Persist side effects and return the computed `String` result.
	var subject = _normalizuj_tag(subject_tag)
	if subject == "":
		return ""
	return _normalizuj_tag(str(vazalske_vztahy.get(subject, "")))

# Boolean check for required state.
func je_vazal_statu(subject_tag: String, overlord_tag: String = "") -> bool:
	# Inputs:
	# - `subject_tag`: State tag handled by this function.
	# - `overlord_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `je_vazal_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `je vazal statu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var subject = _normalizuj_tag(subject_tag)
	if subject == "":
		return false
	var current_lord = ziskej_overlorda_statu(subject)
	if current_lord == "":
		return false
	if _normalizuj_tag(overlord_tag) == "":
		return true
	return current_lord == _normalizuj_tag(overlord_tag)

# Core flow for this feature.
func jsou_vazalsky_spojeni(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `jsou_vazalsky_spojeni` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `jsou vazalsky spojeni` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return false
	return je_vazal_statu(a, b) or je_vazal_statu(b, a)

# Ai generated or editted start (priloha_a.txt)
func muze_vstoupit_na_uzemi(actor_tag: String, owner_tag: String) -> bool:
	# Inputs:
	# - `actor_tag`: State tag handled by this function.
	# - `owner_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `muze_vstoupit_na_uzemi` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `muze vstoupit na uzemi` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var actor = _normalizuj_tag(actor_tag)
	var owner_state = _normalizuj_tag(owner_tag)
	if actor == "" or owner_state == "":
		return false
	if owner_state == "SEA":
		return true
	if actor == owner_state:
		return true
	if jsou_vazalsky_spojeni(actor, owner_state):
		return true
	if ziskej_uroven_aliance(actor, owner_state) >= ALLIANCE_DEFENSE:
		return true
	if ma_vojensky_pristup(actor, owner_state):
		return true
	return false

# Ai generated or editted end (priloha_a.txt)
func propustit_vazala(overlord_tag: String, subject_tag: String) -> bool:
	# Inputs:
	# - `overlord_tag`: State tag handled by this function.
	# - `subject_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `propustit_vazala` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `propustit vazala` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "" or overlord == subject:
		return false
	if ziskej_overlorda_statu(subject) != overlord:
		return false
	vazalske_vztahy.erase(subject)
	vazalske_odvody.erase(subject)
	vazalske_odvody_posledni_zmena_kolo.erase(subject)
	_uprav_vztah_statu_bez_cooldown(overlord, subject, -20.0)
	if ziskej_uroven_aliance(overlord, subject) > ALLIANCE_NONE:
		nastav_uroven_aliance(overlord, subject, ALLIANCE_NONE, true)
	return true

# Fetches data for callers.
func ziskej_aktivni_reparace_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_aktivni_reparace_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej aktivni reparace statu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var state = _normalizuj_tag(state_tag)
	var incoming: Array = []
	var outgoing: Array = []
	if state == "":
		return {"incoming": incoming, "outgoing": outgoing}

	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if remaining <= 0:
			continue
		if to_tag == state:
			incoming.append(rep.duplicate(true))
		elif from_tag == state:
			outgoing.append(rep.duplicate(true))

	return {"incoming": incoming, "outgoing": outgoing}

# Computes derived values from current inputs and game state.
