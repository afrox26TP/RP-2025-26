extends "res://scripts/GameMilitaryDevelopment.gd"

## Treasury access, capital relocation, trade, loans, and province buildings.

const EconomyLoanCalculatorScript = preload("res://scripts/LoanCalculator.gd")
const EconomyCapitalRelocationCalculatorScript = preload("res://scripts/CapitalRelocationCalculator.gd")
const ECONOMY_CAPITAL_RELOCATION_BASE_COST := 25.0
const ECONOMY_CAPITAL_RELOCATION_HDP_RATIO := 0.12
const ECONOMY_CAPITAL_RELOCATION_DISTANCE_STEP := 250.0
const ECONOMY_CAPITAL_RELOCATION_DISTANCE_RATIO_PER_STEP := 0.06
const ECONOMY_CAPITAL_RELOCATION_DISTANCE_MULTIPLIER_MAX := 2.25

var economy_loan_calculator = EconomyLoanCalculatorScript.new()
var _economy_capital_relocation_calculator = EconomyCapitalRelocationCalculatorScript.new(
	ECONOMY_CAPITAL_RELOCATION_BASE_COST,
	ECONOMY_CAPITAL_RELOCATION_HDP_RATIO,
	ECONOMY_CAPITAL_RELOCATION_DISTANCE_STEP,
	ECONOMY_CAPITAL_RELOCATION_DISTANCE_RATIO_PER_STEP,
	ECONOMY_CAPITAL_RELOCATION_DISTANCE_MULTIPLIER_MAX
)

func _stat_existuje(tag: String) -> bool:
	# Outputs: `bool` whether state exists on current map.
	# Execution timing: Called by most state-mutating actions as guard.
	# Steps: normalize tag, scan ownership, return existence.
	var wanted = _normalizuj_tag(tag)
	if wanted == "" or wanted == "SEA":
		return false
	for p_id in map_data:
		var owner_tag = _normalizuj_tag(str(map_data[p_id].get("owner", "")))
		if owner_tag == wanted:
			return true
	return false

# Reads values from active state.
func _ziskej_kasu_statu(tag: String) -> float:
	# Outputs: current state treasury as float.
	# Execution timing: Called by economy, purchase, and diplomacy flows.
	# Steps: resolve whether tag is active player or cached player/AI treasury.
	var t = _normalizuj_tag(tag)
	if t == "":
		return 0.0
	if je_lidsky_stat(t):
		if t == _normalizuj_tag(hrac_stat):
			return statni_kasa
		return float(hrac_kasy.get(t, 0.0))
	return float(ai_kasy.get(t, 0.0))

# Updates state and keeps things in sync.
func _nastav_kasu_statu(tag: String, value: float) -> void:
	# Outputs: none.
	# Execution timing: Called after spending/income events.
	# Steps: clamp/normalize value and write into correct treasury store.
	var t = _normalizuj_tag(tag)
	if t == "":
		return
	var safe_value = value
	if je_lidsky_stat(t):
		hrac_kasy[t] = safe_value
		if t == _normalizuj_tag(hrac_stat):
			statni_kasa = safe_value
	else:
		ai_kasy[t] = safe_value

# Fetches data for callers.
func _ziskej_pozici_provincie(province_id: int) -> Vector2:
	# Outputs: province world position or zero vector fallback.
	# Execution timing: Called by capital relocation distance calculations.
	# Steps: read province coordinates from map data and return fallback on miss.
	return _economy_capital_relocation_calculator.province_position(map_data, province_id)

# Pulls current state data.
func _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(source_province_id: int, target_province_id: int) -> float:
	# Inputs: source and target capital province ids.
	# Outputs: relocation distance multiplier.
	# Execution timing: Called by capital-relocation cost preview and apply.
	# Steps: compute distance, convert into stepped multiplier, clamp max.
	return _economy_capital_relocation_calculator.distance_multiplier(map_data, source_province_id, target_province_id)

# Fetches data for callers.
func ziskej_cenu_presunu_hlavniho_mesta(state_tag: String, target_province_id: int = -1) -> float:
	# Outputs: relocation cost for capital move.
	# Execution timing: Called by UI preview and relocation validation.
	# Steps: resolve current/target capitals, compute GDP+distance based cost.
	var tag = _normalizuj_tag(state_tag)
	if tag == "" or tag == "SEA":
		return 999999.0
	var hdp = _spocitej_hdp_statu(tag)
	var base_cost = _economy_capital_relocation_calculator.relocation_cost(hdp)
	if target_province_id <= 0:
		return base_cost

	var current_capital_id = _ziskej_hlavni_mesto_statu(tag)
	if current_capital_id <= 0:
		return base_cost

	var distance_multiplier = _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(current_capital_id, target_province_id)
	return _economy_capital_relocation_calculator.relocation_cost(hdp, distance_multiplier)

# Pulls current state data.
func _ziskej_hlavni_mesto_statu(state_tag: String) -> int:
	# Outputs: province id of current capital or `-1`.
	# Execution timing: Called by capital-move and peace systems.
	# Steps: locate owner provinces and select marked capital fallback.
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "" or wanted == "SEA":
		return -1
	if _ai_phase_cache_active and _ai_capital_cache.has(wanted):
		return int(_ai_capital_cache[wanted])

	# Prefer currently owned capital if it exists.
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != wanted:
			continue
		if bool(d.get("is_capital", false)):
			var found_owned = int(p_id)
			if _ai_phase_cache_active:
				_ai_capital_cache[wanted] = found_owned
			return found_owned

	# Fallback: occupied capital still marked by core owner.
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("core_owner", ""))) != wanted:
			continue
		if bool(d.get("is_capital", false)):
			var found_core = int(p_id)
			if _ai_phase_cache_active:
				_ai_capital_cache[wanted] = found_core
			return found_core

	if _ai_phase_cache_active:
		_ai_capital_cache[wanted] = -1
	return -1

# Cancels the active flow and restores a safe default state.
func _zrus_cekajici_kapitulace_pro_obrance(obrance_tag: String) -> int:
	# Inputs: defender tag.
	# Outputs: number of removed pending capitulations.
	# Execution timing: Called when state conditions invalidate capitulation queue.
	# Steps: iterate queue backwards, remove entries matching defender.
	var obr = _normalizuj_tag(obrance_tag)
	if obr == "":
		return 0
	var removed := 0
	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		if _normalizuj_tag(str(cekajici_kapitulace[i].get("obrance", ""))) == obr:
			cekajici_kapitulace.remove_at(i)
			removed += 1
	return removed

# Recomputes values from current data.
func _aktualizuj_label_hlavniho_mesta(map_loader: Node, prov_id: int, is_capital: bool, state_tag: String) -> void:
	# Inputs: map loader, province id, capital flag, state tag.
	# Outputs: none.
	# Execution timing: Called during capital relocation map refresh.
	# Steps: find province label node and update capital indicator visuals.
	var labels = map_loader.get_node_or_null("ProvinceLabels")
	if labels == null:
		return

	for lbl in labels.get_children():
		if int(lbl.get("province_id")) != prov_id:
			continue

		lbl.set("is_capital", is_capital)

		var d = map_data.get(prov_id, {}) as Dictionary
		var shown_name = str(d.get("province_name", "Province %d" % prov_id)).replace(" Voivodeship", "").replace(" County", "")
		if is_capital:
			var city_name = str(d.get("capital_name", "")).strip_edges()
			if city_name != "":
				shown_name = city_name

		var label_node = lbl.find_child("Label", true, false)
		if label_node:
			label_node.text = shown_name
		if "plny_nazev" in lbl:
			lbl.set("plny_nazev", shown_name)

		var flag_node = lbl.find_child("Flag", true, false)
		if flag_node:
			if is_capital:
				flag_node.show()
				if map_loader.has_method("_get_flag_texture"):
					var ideology = str(d.get("ideology", ""))
					var tex = map_loader._get_flag_texture(state_tag, ideology)
					if tex:
						flag_node.texture = tex
			else:
				flag_node.hide()

		if lbl.has_method("reset_stav"):
			lbl.reset_stav()
		break

# Refresh pass for current state.
func _aktualizuj_mapu_po_presunu_hlavniho_mesta(old_capital_id: int, new_capital_id: int, state_tag: String) -> void:
	# Inputs: old/new capital ids and state tag.
	# Outputs: none.
	# Execution timing: Called after successful capital relocation.
	# Steps: update map data flags and refresh map-label/visual helpers.
	var map_loader = _get_map_loader()
	if map_loader == null:
		return

	if "provinces" in map_loader:
		map_loader.provinces = map_data

	_aktualizuj_label_hlavniho_mesta(map_loader, old_capital_id, false, state_tag)
	_aktualizuj_label_hlavniho_mesta(map_loader, new_capital_id, true, state_tag)

	var labels_manager = map_loader.get_node_or_null("CountryLabelsManager")
	var province_labels = map_loader.get_node_or_null("ProvinceLabels")
	if labels_manager and province_labels and labels_manager.has_method("aktualizuj_labely_statu"):
		labels_manager.aktualizuj_labely_statu(map_data, province_labels)

	if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
		map_loader._aktualizuj_aktivni_mapovy_mod()
	if map_loader.has_method("_aktualizuj_indikatory_kapitulace"):
		map_loader._aktualizuj_indikatory_kapitulace()

# Handles this gameplay/UI path.
func muze_presunout_hlavni_mesto(state_tag: String, target_province_id: int) -> Dictionary:
	# Inputs: state tag and target province id.
	# Outputs: eligibility dictionary with reason/cost details.
	# Execution timing: Called before enabling capital-move action.
	# Steps: validate ownership/rules/cooldowns/treasury and return structured result.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid state."}

	var last_turn = int(_presun_hlavniho_mesta_posledni_kolo.get(state, -1))
	if last_turn == aktualni_kolo:
		return {"ok": false, "reason": "Capital can be moved only once per turn."}

	if not _stat_existuje(state):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if not map_data.has(target_province_id):
		return {"ok": false, "reason": "Target province does not exist."}

	var target = map_data[target_province_id]
	var target_owner = _normalizuj_tag(str(target.get("owner", "")))
	if target_owner != state:
		return {"ok": false, "reason": "Capital can be moved only to your own province."}
	if _normalizuj_tag(str(target.get("core_owner", target_owner))) != state:
		return {"ok": false, "reason": "Target must be a core province of this state."}
	if target_owner == "SEA":
		return {"ok": false, "reason": "Capital cannot be moved to sea."}

	var current_capital_id = _ziskej_hlavni_mesto_statu(state)
	if current_capital_id == -1:
		return {"ok": false, "reason": "State has no available capital to move."}
	if current_capital_id == target_province_id:
		return {"ok": false, "reason": "This province is already the capital."}

	var current_name = "Province %d" % current_capital_id
	if map_data.has(current_capital_id):
		current_name = str(map_data[current_capital_id].get("province_name", current_name))
	var target_name = str(target.get("province_name", "Province %d" % target_province_id))
	var cost = ziskej_cenu_presunu_hlavniho_mesta(state, target_province_id)
	var distance_multiplier = _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(current_capital_id, target_province_id)
	return {
		"ok": true,
		"state": state,
		"cost": cost,
		"distance_multiplier": distance_multiplier,
		"current_capital_id": current_capital_id,
		"current_capital_name": current_name,
		"target_capital_id": target_province_id,
		"target_capital_name": target_name
	}

# Eligibility/guard check.
func ma_dostupny_cil_presunu_hlavniho_mesta(state_tag: String) -> bool:
	# Inputs: state tag.
	# Outputs: `bool` whether any legal capital target exists.
	# Execution timing: Called by UI to show/hide relocate action.
	# Steps: scan owned provinces and test each with eligibility helper.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return false
	if not _stat_existuje(state):
		return false

	for p_id in map_data.keys():
		var pid = int(p_id)
		var check = muze_presunout_hlavni_mesto(state, pid)
		if bool(check.get("ok", false)):
			return true
	return false

# Ai generated or editted start (priloha_a.txt)
func presun_hlavni_mesto(state_tag: String, target_province_id: int, pay_cost: bool = true, emit_ui_signal: bool = true) -> Dictionary:
	# Inputs: state tag, target province id, payment flag, ui-signal flag.
	# Outputs: relocation result payload.
	# Execution timing: Called when relocation is confirmed or scripted.
	# Steps: validate move, optionally deduct cost, update capital data/map, emit updates.
	var check = muze_presunout_hlavni_mesto(state_tag, target_province_id)
	if not bool(check.get("ok", false)):
		return check

	var state = _normalizuj_tag(str(check.get("state", state_tag)))
	var cost = float(check.get("cost", 0.0))
	if pay_cost:
		var cash_now = _ziskej_kasu_statu(state)
		if cash_now + 0.0001 < cost:
			return {"ok": false, "reason": "Insufficient funds.", "required": cost, "cash": cash_now}
		_nastav_kasu_statu(state, cash_now - cost)
		_money_debug_expense(state, "capital_move", cost, cash_now, _ziskej_kasu_statu(state), "target_province=%d" % target_province_id)

	var old_capital_id = int(check.get("current_capital_id", -1))
	if map_data.has(old_capital_id):
		map_data[old_capital_id]["is_capital"] = false
	map_data[target_province_id]["is_capital"] = true
	_ai_capital_cache.erase(state)
	_presun_hlavniho_mesta_posledni_kolo[state] = aktualni_kolo

	var canceled_pressure = _zrus_cekajici_kapitulace_pro_obrance(state)
	_aktualizuj_mapu_po_presunu_hlavniho_mesta(old_capital_id, target_province_id, state)
	_invalidate_turn_cache()

	var old_name = str(check.get("current_capital_name", "Province %d" % old_capital_id))
	var new_name = str(check.get("target_capital_name", "Province %d" % target_province_id))
	var log_msg = "%s moved the capital from %s to %s." % [state, old_name, new_name]
	if canceled_pressure > 0:
		log_msg += " This removed the pressure for immediate surrender."
	_zaloguj_globalni_zpravu("War", log_msg, "war")

	if emit_ui_signal:
		kolo_zmeneno.emit()

	return {
		"ok": true,
		"state": state,
		"cost": cost,
		"old_capital_id": old_capital_id,
		"new_capital_id": target_province_id,
		"old_capital_name": old_name,
		"new_capital_name": new_name,
		"canceled_surrender_pressure": canceled_pressure,
		"cash_after": _ziskej_kasu_statu(state)
	}

# Ai generated or editted end (priloha_a.txt)
func daruj_penize_statu(odesilatel: String, prijemce: String, amount: float) -> Dictionary:
	# Inputs: sender tag, receiver tag, amount.
	# Outputs: transfer result dictionary.
	# Execution timing: Called by diplomacy gift actions.
	# Steps: validate parties/amount/funds, transfer treasury, log notifications.
	var from_tag = _normalizuj_tag(odesilatel)
	var to_tag = _normalizuj_tag(prijemce)
	var castka = maxf(0.0, amount)

	if from_tag == "" or to_tag == "" or from_tag == to_tag:
		return {"ok": false, "reason": "Invalid countries for gift."}
	if from_tag == "SEA" or to_tag == "SEA":
		return {"ok": false, "reason": "Cannot send gifts to sea provinces."}
	if castka <= 0.0:
		return {"ok": false, "reason": "Gift amount must be greater than 0."}
	if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
		return {"ok": false, "reason": "One of the countries does not exist on the current map."}

	var kasa_odesilatel = _ziskej_kasu_statu(from_tag)
	if kasa_odesilatel + 0.0001 < castka:
		return {"ok": false, "reason": "Insufficient funds."}

	var kasa_prijemce = _ziskej_kasu_statu(to_tag)
	_nastav_kasu_statu(from_tag, kasa_odesilatel - castka)
	_nastav_kasu_statu(to_tag, kasa_prijemce + castka)
	_money_debug_expense(from_tag, "gift_sent", castka, kasa_odesilatel, _ziskej_kasu_statu(from_tag), "to=%s" % to_tag)
	_money_debug_income_event(to_tag, "gift_received", castka, kasa_prijemce, _ziskej_kasu_statu(to_tag), "from=%s" % from_tag)

	var rel_delta = clamp(castka / 20.0, 1.0, 15.0)
	var new_rel = _uprav_vztah_statu_bez_cooldown(from_tag, to_tag, rel_delta)

	if je_lidsky_stat(from_tag) or je_lidsky_stat(to_tag):
		_pridej_popup_zucastnenym_hracum(
			from_tag,
			to_tag,
			"DIPLOMACY",
			"%s sent a financial gift of %.2f mil. USD to %s (relation %+0.1f)." % [from_tag, castka, to_tag, rel_delta]
		)
	_zaloguj_globalni_zpravu(
		"Gifts",
		"%s sent a financial gift of %.2f mil. USD to %s (relation %+0.1f)." % [from_tag, castka, to_tag, rel_delta],
		"gifts"
	)

	return {
		"ok": true,
		"amount": castka,
		"relation_delta": rel_delta,
		"new_relation": new_rel,
		"from_cash": _ziskej_kasu_statu(from_tag),
		"to_cash": _ziskej_kasu_statu(to_tag)
	}

# Handles this gameplay/UI path.
func prejmenuj_stat(state_tag: String, new_name: String) -> Dictionary:
	# Inputs: state tag and new name.
	# Outputs: rename result dictionary.
	# Execution timing: Called by customization and scripted rename flows.
	# Steps: validate name/tag, update map country_name fields, emit refresh signal.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(state):
		return {"ok": false, "reason": "State does not exist on the current map."}

	var clean_name = new_name.strip_edges()
	clean_name = clean_name.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while clean_name.find("  ") != -1:
		clean_name = clean_name.replace("  ", " ")
	if clean_name == "":
		return {"ok": false, "reason": "Country name cannot be empty."}
	if clean_name.length() > 40:
		return {"ok": false, "reason": "Country name is too long (max 40 characters)."}

	var changed := 0
	for p_id in map_data:
		var d = map_data[p_id] as Dictionary
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		d["country_name"] = clean_name
		changed += 1

	if changed <= 0:
		return {"ok": false, "reason": "No provinces found for this state."}

	_invalidate_tag_alias_cache()
	_synchronizuj_jmeno_a_ideologii_hrace()
	_invalidate_turn_cache()

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_invalidate_naval_reachability_cache"):
			map_loader._invalidate_naval_reachability_cache()
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()
		var labels_manager = map_loader.get_node_or_null("CountryLabelsManager")
		var province_labels = map_loader.get_node_or_null("ProvinceLabels")
		if labels_manager and labels_manager.has_method("aktualizuj_labely_statu"):
			labels_manager.aktualizuj_labely_statu(map_data, province_labels)

	kolo_zmeneno.emit()
	return {
		"ok": true,
		"state": state,
		"new_name": clean_name,
		"changed_provinces": changed
	}

# Trade flow is: normalize -> validate -> queue/AI decide -> execute.
# Handles this gameplay/UI path.
func odeslat_obchodni_nabidku(odesilatel: String, prijemce: String, terms_from_sender_raw: Dictionary, terms_from_receiver_raw: Dictionary) -> Dictionary:
	# Inputs: sender/receiver tags and raw terms dictionaries.
	# Outputs: trade-offer result payload.
	# Execution timing: Called when creating a new trade proposal.
	# Steps: normalize terms, validate legality/value, route to AI or queue request.
	var from_tag = _normalizuj_tag(odesilatel)
	var to_tag = _normalizuj_tag(prijemce)
	if from_tag == "" or to_tag == "" or from_tag == to_tag:
		return {"ok": false, "reason": "Invalid countries for trade."}
	if from_tag == "SEA" or to_tag == "SEA":
		return {"ok": false, "reason": "Trade cannot involve sea provinces."}
	if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
		return {"ok": false, "reason": "One of the countries does not exist on the current map."}

	var terms_from_sender = _normalizuj_trade_terms(terms_from_sender_raw)
	var terms_from_receiver = _normalizuj_trade_terms(terms_from_receiver_raw)
	if terms_from_sender.is_empty() and terms_from_receiver.is_empty():
		return {"ok": false, "reason": "Trade offer must contain at least one term."}

	var check_sender = _trade_validate_terms(from_tag, to_tag, terms_from_sender)
	if not bool(check_sender.get("ok", false)):
		return check_sender
	var check_receiver = _trade_validate_terms(to_tag, from_tag, terms_from_receiver)
	if not bool(check_receiver.get("ok", false)):
		return check_receiver

	var payload = {
		"from_terms": terms_from_sender,
		"to_terms": terms_from_receiver
	}

	if je_lidsky_stat(to_tag):
		var queued = _pridej_diplomatickou_zadost(from_tag, to_tag, "trade", ALLIANCE_NONE, payload)
		if not queued:
			return {"ok": false, "reason": "Trade offer could not be queued."}
		if je_lidsky_stat(from_tag):
			_pridej_popup_hraci(from_tag, "Trade", "Trade offer was sent to %s." % to_tag)
		return {
			"ok": true,
			"queued": true,
			"accepted": false,
			"from_terms": terms_from_sender,
			"to_terms": terms_from_receiver
		}

	var ai_accepts = _vyhodnot_trade_nabidku_ai(from_tag, to_tag, terms_from_sender, terms_from_receiver)
	if not ai_accepts:
		_zaloguj_globalni_zpravu("Trade", "%s rejected trade offer from %s." % [to_tag, from_tag], "trade")
		if je_lidsky_stat(from_tag):
			_zaloguj_zpravu_hraci(from_tag, "Trade", "%s rejected your trade offer." % to_tag, "trade")
		if je_lidsky_stat(from_tag):
			_pridej_popup_hraci(from_tag, "Trade", "%s rejected your trade offer." % to_tag)
		return {"ok": true, "queued": false, "accepted": false, "reason": "AI rejected the offer."}

	var apply_result = _proved_trade_dohodu(from_tag, to_tag, payload)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	apply_result["queued"] = false
	apply_result["accepted"] = true
	return apply_result

# Handles this gameplay/UI path.
func _normalizuj_trade_terms(raw_terms: Dictionary) -> Dictionary:
	# Inputs: raw trade terms dictionary.
	# Outputs: normalized trade terms schema.
	# Execution timing: Called before trade validation and valuation.
	# Steps: parse known slots/values, sanitize invalid entries, return normalized map.
	var out: Dictionary = {}
	for slot_any in raw_terms.keys():
		var slot = str(slot_any).strip_edges().to_lower()
		if not TRADE_SUPPORTED_SLOTS.has(slot):
			continue
		var entry_any = raw_terms.get(slot_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry = entry_any as Dictionary
		var value_a = str(entry.get("a", "")).strip_edges()
		var value_b = str(entry.get("b", "")).strip_edges()
		if value_a == "" and value_b == "":
			continue
		out[slot] = {"a": value_a, "b": value_b}
	return out

# Runs the local feature logic.
func _trade_parse_amount(raw: String) -> float:
	# Inputs: raw numeric text.
	# Outputs: parsed non-negative amount.
	# Execution timing: Called by trade terms parser.
	# Steps: normalize separators/tokens, parse float, clamp invalid values.
	var sanitized = raw.strip_edges().replace(",", ".").to_lower()
	if sanitized == "":
		return -1.0
	if sanitized.is_valid_float():
		return float(sanitized)

	var re := RegEx.new()
	var err = re.compile("[-+]?[0-9]*\\.?[0-9]+")
	if err != OK:
		return -1.0
	var m = re.search(sanitized)
	if m == null:
		return -1.0
	var parsed = m.get_string(0)
	if parsed == "" or not parsed.is_valid_float():
		return -1.0
	return float(parsed)

func _trade_parse_province_id(raw: String) -> int:
	# Inputs: raw province token.
	# Outputs: parsed province id or `-1`.
	# Execution timing: Called by trade parsing helpers.
	# Steps: extract numeric token and convert to valid int.
	var sanitized = raw.strip_edges()
	if sanitized == "":
		return -1
	if not sanitized.is_valid_int():
		return -1
	return int(sanitized)

func _trade_parse_province_ids(raw: String) -> Array:
	# Inputs: raw province list text.
	# Outputs: deduplicated parsed province id array.
	# Execution timing: Called when terms include multiple provinces.
	# Steps: tokenize input, parse ids, remove invalid/duplicate ids.
	var text = raw.strip_edges().replace(";", ",").replace(" ", "")
	if text == "":
		return []
	var out: Array = []
	for part in text.split(",", false):
		var token = part.strip_edges()
		if token == "" or not token.is_valid_int():
			continue
		var pid = int(token)
		if not out.has(pid):
			out.append(pid)
	return out

func _trade_parse_target_tag(raw: String) -> String:
	# Inputs: raw target tag text.
	# Outputs: normalized state tag.
	# Execution timing: Called by trade parser for target-state slots.
	# Steps: normalize via tag resolver and return.
	return _normalizuj_tag(raw)

# Runs the local feature logic.
func _trade_extract_numeric_tokens(raw: String) -> Array:
	# Inputs: raw text.
	# Outputs: array of numeric token strings.
	# Execution timing: Shared helper for amount/province parsing.
	# Steps: split text by separators and keep numeric-looking tokens.
	return economy_loan_calculator.extract_numeric_tokens(raw)

# Ai generated or editted start (priloha_a.txt)
func _trade_parse_loan_terms(value_a: String, value_b: String) -> Dictionary:
	# Inputs: two raw values for loan terms.
	# Outputs: normalized loan-term dictionary.
	# Execution timing: Called when trade contains loan slot.
	# Steps: parse principal/interest/turns and clamp to configured limits.
	return economy_loan_calculator.parse_terms(value_a, value_b, LOAN_MIN_INTEREST_PCT, LOAN_MAX_INTEREST_PCT, LOAN_MIN_TURNS, LOAN_MAX_TURNS)

# Ai generated or editted end (priloha_a.txt)
func _spocitej_celkovou_dluznou_castku_pujcky(principal: float, interest_pct: float) -> float:
	# Inputs: principal and interest percent.
	# Outputs: total owed amount.
	# Execution timing: Called by loan creation and UI projections.
	# Steps: compute principal plus total interest.
	return economy_loan_calculator.total_due(principal, interest_pct)

# Computes derived values from current inputs and game state.
func _spocitej_splatku_pujcky(principal: float, interest_pct: float, turns: int) -> float:
	# Inputs: principal, interest pct, repayment turns.
	# Outputs: per-turn repayment amount.
	# Execution timing: Called in loan setup and turn processing.
	# Steps: compute total debt and divide by turn count safely.
	return economy_loan_calculator.installment(principal, interest_pct, turns)

# Applies incoming data to runtime state.
func _normalizuj_loan_na_celkovy_urok_model(loan: Dictionary) -> Dictionary:
	# Inputs: raw/legacy loan dictionary.
	# Outputs: normalized loan dictionary in total-interest model.
	# Execution timing: Called when loading or processing old loan records.
	# Steps: map legacy fields, recompute totals/payment fields, return normalized loan.
	return economy_loan_calculator.normalize_schedule(loan)

# Builds UI objects and default wiring.
func _vytvor_statni_pujcku(lender_tag: String, borrower_tag: String, principal: float, interest_pct: float, turns: int) -> Dictionary:
	# Inputs: lender, borrower, principal, interest, turns.
	# Outputs: structured loan creation result.
	# Execution timing: Called after loan offer acceptance.
	# Steps: validate parties/limits/funds, transfer principal, create active-loan record.
	var lender = _normalizuj_tag(lender_tag)
	var borrower = _normalizuj_tag(borrower_tag)
	if lender == "" or borrower == "" or lender == borrower:
		return {"ok": false, "reason": "Invalid lender/borrower for loan."}
	if principal <= 0.0:
		return {"ok": false, "reason": "Loan principal must be positive."}
	if turns < LOAN_MIN_TURNS or turns > LOAN_MAX_TURNS:
		return {"ok": false, "reason": "Invalid loan duration."}
	if interest_pct < LOAN_MIN_INTEREST_PCT or interest_pct > LOAN_MAX_INTEREST_PCT:
		return {"ok": false, "reason": "Invalid loan interest."}

	var lender_cash = _ziskej_kasu_statu(lender)
	if lender_cash + 0.0001 < principal:
		return {
			"ok": false,
			"reason": "%s does not have enough treasury to fund loan (required %.2f mil. USD, available %.2f mil. USD)." % [lender, principal, lender_cash],
			"required": principal,
			"available": lender_cash
		}

	var total_due = _spocitej_celkovou_dluznou_castku_pujcky(principal, interest_pct)
	var installment = _spocitej_splatku_pujcky(principal, interest_pct, turns)
	_nastav_kasu_statu(lender, lender_cash - principal)
	var borrower_cash_before = _ziskej_kasu_statu(borrower)
	_nastav_kasu_statu(borrower, borrower_cash_before + principal)
	_money_debug_expense(lender, "loan_funded", principal, lender_cash, _ziskej_kasu_statu(lender), "to=%s interest=%.2f%% turns=%d" % [borrower, interest_pct, turns])
	_money_debug_income_event(borrower, "loan_received", principal, borrower_cash_before, _ziskej_kasu_statu(borrower), "from=%s interest=%.2f%% turns=%d" % [lender, interest_pct, turns])

	var loan = {
		"lender": lender,
		"borrower": borrower,
		"principal": principal,
		"interest_pct": interest_pct,
		"interest_model": "term_total",
		"turns_total": turns,
		"remaining_turns": turns,
		"installment": installment,
		"remaining_due": total_due,
		"created_turn": aktualni_kolo
	}
	aktivni_pujcky.append(loan)

	var relation_delta = clamp(principal / 120.0, 0.4, 5.0)
	_uprav_vztah_statu_bez_cooldown(lender, borrower, relation_delta)

	var msg = "%s gave %.2f mil. USD loan to %s (interest %.2f%%, %d turns)." % [lender, principal, borrower, interest_pct, turns]
	_zaloguj_globalni_zpravu("Loans", msg, "trade")
	if je_lidsky_stat(lender) or je_lidsky_stat(borrower):
		_pridej_popup_zucastnenym_hracum(lender, borrower, "Loans", msg)

	return {
		"ok": true,
		"loan": loan,
		"total_due": total_due,
		"installment": installment
	}

# Core flow for this feature.
func navrhni_statni_pujcku(lender_tag: String, borrower_tag: String, principal: float, interest_pct: float, turns: int, requester_tag: String = "") -> Dictionary:
	# Inputs: lender, borrower, principal, interest, turns, requester.
	# Outputs: loan proposal result payload.
	# Execution timing: Called when creating inter-state loan request.
	# Steps: validate parameters, decide immediate AI response or queue pending request.
	var lender = _normalizuj_tag(lender_tag)
	var borrower = _normalizuj_tag(borrower_tag)
	var requester = _normalizuj_tag(requester_tag)
	if lender == "" or borrower == "" or lender == borrower:
		return {"ok": false, "reason": "Invalid lender/borrower for loan offer."}
	if not _stat_existuje(lender) or not _stat_existuje(borrower):
		return {"ok": false, "reason": "State does not exist on current map."}
	if principal <= 0.0:
		return {"ok": false, "reason": "Loan principal must be positive."}
	if turns < LOAN_MIN_TURNS or turns > LOAN_MAX_TURNS:
		return {"ok": false, "reason": "Invalid loan duration."}
	if interest_pct < LOAN_MIN_INTEREST_PCT or interest_pct > LOAN_MAX_INTEREST_PCT:
		return {"ok": false, "reason": "Invalid loan interest."}
	var lender_is_human = je_lidsky_stat(lender)
	var borrower_is_human = je_lidsky_stat(borrower)
	if lender_is_human and borrower_is_human:
		var receiver = borrower
		if requester == borrower:
			receiver = lender
		var payload = {
			"lender": lender,
			"borrower": borrower,
			"principal": principal,
			"interest_pct": interest_pct,
			"turns": turns
		}
		var queued = _pridej_diplomatickou_zadost(requester if requester != "" else lender, receiver, "loan", ALLIANCE_NONE, payload)
		if not queued:
			return {"ok": false, "reason": "Loan proposal could not be queued."}
		return {"ok": true, "queued": true, "receiver": receiver, "payload": payload}

	var lender_cash = _ziskej_kasu_statu(lender)
	if lender_cash + 0.0001 < principal:
		return {
			"ok": false,
			"reason": "%s does not have enough treasury to fund loan (required %.2f mil. USD, available %.2f mil. USD)." % [lender, principal, lender_cash],
			"required": principal,
			"available": lender_cash
		}

	var decision_maker = borrower if not borrower_is_human else lender
	var request_kind = "give" if requester != borrower else "take"

	# For human-vs-AI interactions, evaluate AI response immediately to avoid
	# an extra waiting turn before the player sees the funded loan flow.
	if requester != "" and je_lidsky_stat(requester) and ((not lender_is_human) or (not borrower_is_human)):
		var accepted = false
		if decision_maker == lender:
			accepted = _ai_ma_poskytnout_pujcku(lender, borrower, principal, interest_pct, turns)
		else:
			accepted = _ai_ma_prijmout_pujcku_nabidku(lender, borrower, principal, interest_pct, turns)

		if accepted:
			var result_now = _vytvor_statni_pujcku(lender, borrower, principal, interest_pct, turns)
			if bool(result_now.get("ok", false)):
				if request_kind == "take" and je_lidsky_stat(borrower):
					var granted_now_text = "%s granted your loan request." % lender
					_pridej_popup_hraci(borrower, "Loans", granted_now_text, true)
					_pridej_notifikaci_pujcky_hraci(borrower, granted_now_text)
				elif je_lidsky_stat(lender):
					var accept_now_text = "%s accepted your loan offer." % borrower
					_pridej_popup_hraci(lender, "Loans", accept_now_text, true)
					_pridej_notifikaci_pujcky_hraci(lender, accept_now_text)
				result_now["immediate_resolve"] = true
				return result_now

			if request_kind == "take" and je_lidsky_stat(borrower):
				var fail_take_now_text = "%s could not grant your loan request: %s" % [lender, str(result_now.get("reason", "failed"))]
				_pridej_popup_hraci(borrower, "Loans", fail_take_now_text, true)
				_pridej_notifikaci_pujcky_hraci(borrower, fail_take_now_text)
				return {"ok": false, "reason": fail_take_now_text}
			if je_lidsky_stat(lender):
				var fail_now_text = "%s could not accept your loan offer: %s" % [borrower, str(result_now.get("reason", "failed"))]
				_pridej_popup_hraci(lender, "Loans", fail_now_text, true)
				_pridej_notifikaci_pujcky_hraci(lender, fail_now_text)
				return {"ok": false, "reason": fail_now_text}
			return result_now

		var reject_now_msg = "%s rejected loan offer from %s (%.2f mil. USD, %.2f%%, %d turns)." % [borrower, lender, principal, interest_pct, turns]
		if request_kind == "take":
			reject_now_msg = "%s rejected loan request from %s (%.2f mil. USD, %.2f%%, %d turns)." % [lender, borrower, principal, interest_pct, turns]
		_zaloguj_globalni_zpravu("Loans", reject_now_msg, "trade")
		if request_kind == "take" and je_lidsky_stat(borrower):
			var reject_take_now_text = "%s rejected your loan request." % lender
			_pridej_popup_hraci(borrower, "Loans", reject_take_now_text, true)
			_pridej_notifikaci_pujcky_hraci(borrower, reject_take_now_text)
			return {"ok": false, "reason": reject_take_now_text}
		if je_lidsky_stat(lender):
			var reject_now_text = "%s rejected your loan offer." % borrower
			_pridej_popup_hraci(lender, "Loans", reject_now_text, true)
			_pridej_notifikaci_pujcky_hraci(lender, reject_now_text)
			return {"ok": false, "reason": reject_now_text}
		return {"ok": false, "reason": "Loan proposal rejected."}

	var offer = {
		"lender": lender,
		"borrower": borrower,
		"principal": principal,
		"interest_pct": interest_pct,
		"turns": turns,
		"decision_maker": decision_maker,
		"request_kind": request_kind,
		"created_turn": aktualni_kolo,
		"resolve_turn": aktualni_kolo + 1
	}
	cekajici_pujcky.append(offer)

	var msg = "%s offered %.2f mil. USD loan to %s (interest %.2f%%, %d turns). Awaiting response next turn." % [lender, principal, borrower, interest_pct, turns]
	if requester == borrower:
		msg = "%s requested %.2f mil. USD loan from %s (interest %.2f%%, %d turns). Awaiting response next turn." % [borrower, principal, lender, interest_pct, turns]
	_zaloguj_globalni_zpravu("Loans", msg, "trade")
	if je_lidsky_stat(lender):
		_pridej_popup_hraci(lender, "Loans", msg)
	if je_lidsky_stat(borrower):
		_pridej_popup_hraci(borrower, "Loans", msg)

	return {"ok": true, "pending": true, "offer": offer}

# Handles this gameplay/UI path.
func _ai_ma_prijmout_pujcku_nabidku(lender: String, borrower: String, principal: float, interest_pct: float, turns: int) -> bool:
	# Inputs: lender/borrower tags and loan terms.
	# Outputs: `bool` AI accept decision.
	# Execution timing: Called during AI response to incoming loan offers.
	# Steps: evaluate affordability, relation/risk heuristics, return decision.
	var borrower_cash = _ziskej_kasu_statu(borrower)
	var income = max(0.0, _spocitej_cisty_prijem_statu(borrower))
	var installment = _spocitej_splatku_pujcky(principal, interest_pct, turns)
	var rel = ziskej_vztah_statu(borrower, lender)

	var score = 0.0
	if borrower_cash < 25.0:
		score += 0.55
	elif borrower_cash < 90.0:
		score += 0.30

	if interest_pct <= 4.0:
		score += 0.35
	elif interest_pct <= 8.0:
		score += 0.15
	elif interest_pct >= 16.0:
		score -= 0.55

	if installment > max(6.0, income * 0.55):
		score -= 1.0

	score += clamp((rel - 10.0) / 100.0, -0.6, 0.6)
	if ziskej_uroven_aliance(lender, borrower) > ALLIANCE_NONE:
		score += 0.15
	if ma_neagresivni_smlouvu(lender, borrower):
		score += 0.10

	var accept_chance = clamp(0.5 + score, 0.05, 0.95)
	return randf() < accept_chance

# Runs the local feature logic.
func _ai_ma_poskytnout_pujcku(lender: String, borrower: String, principal: float, interest_pct: float, turns: int) -> bool:
	# Inputs: lender/borrower and loan terms.
	# Outputs: `bool` AI willingness to lend.
	# Execution timing: Called when AI receives borrow request.
	# Steps: evaluate reserves/relations/profitability and return decision.
	var lender_cash = _ziskej_kasu_statu(lender)
	var lender_income = max(0.0, _spocitej_cisty_prijem_statu(lender))
	var borrower_cash = _ziskej_kasu_statu(borrower)
	var rel = ziskej_vztah_statu(lender, borrower)
	var total_due = _spocitej_celkovou_dluznou_castku_pujcky(principal, interest_pct)
	var total_profit = max(0.0, total_due - principal)

	var score = 0.0
	if lender_cash >= principal * 3.5:
		score += 0.45
	elif lender_cash >= principal * 2.0:
		score += 0.25
	elif lender_cash + lender_income * 2.0 < principal:
		score -= 1.1
	elif lender_cash < principal:
		score -= 0.45

	if borrower_cash < 30.0:
		score += 0.18
	elif borrower_cash > 180.0:
		score -= 0.18

	if interest_pct >= 10.0:
		score += 0.25
	elif interest_pct >= 6.0:
		score += 0.12
	elif interest_pct <= 2.0:
		score -= 0.20

	if turns >= 20:
		score -= 0.18
	elif turns <= 10:
		score += 0.08

	if total_profit >= max(8.0, principal * 0.20):
		score += 0.15

	score += clamp((rel - 10.0) / 100.0, -0.55, 0.55)
	if ziskej_uroven_aliance(lender, borrower) > ALLIANCE_NONE:
		score += 0.15
	if ma_neagresivni_smlouvu(lender, borrower):
		score += 0.08

	var accept_chance = clamp(0.45 + score, 0.05, 0.95)
	return randf() < accept_chance

# Handles this gameplay/UI path.
func _zpracuj_cekajici_pujcky_za_kolo() -> void:
	# Inputs: none.
	# Outputs: none.
	# Execution timing: Called during end-turn pipeline.
	# Steps: process pending loan requests, resolve accept/reject, update notifications/logs.
	if cekajici_pujcky.is_empty():
		return

	var stale: Array = []
	for offer_any in cekajici_pujcky:
		var offer = offer_any as Dictionary
		var lender = _normalizuj_tag(str(offer.get("lender", "")))
		var borrower = _normalizuj_tag(str(offer.get("borrower", "")))
		var resolve_turn = int(offer.get("resolve_turn", int(offer.get("created_turn", aktualni_kolo)) + 1))
		if lender == "" or borrower == "" or lender == borrower:
			continue
		if aktualni_kolo < resolve_turn:
			stale.append(offer)
			continue
		if not _stat_existuje(lender) or not _stat_existuje(borrower):
			continue

		var principal = float(offer.get("principal", 0.0))
		var interest_pct = float(offer.get("interest_pct", 0.0))
		var turns = int(offer.get("turns", 0))
		var decision_maker = _normalizuj_tag(str(offer.get("decision_maker", borrower)))
		var request_kind = str(offer.get("request_kind", "give"))
		if principal <= 0.0 or turns <= 0:
			continue

		var accepted = false
		if decision_maker == lender:
			accepted = _ai_ma_poskytnout_pujcku(lender, borrower, principal, interest_pct, turns)
		else:
			accepted = _ai_ma_prijmout_pujcku_nabidku(lender, borrower, principal, interest_pct, turns)
		if accepted:
			var result = _vytvor_statni_pujcku(lender, borrower, principal, interest_pct, turns)
			if not bool(result.get("ok", false)):
				if request_kind == "take" and je_lidsky_stat(borrower):
					var fail_take_text = "%s could not grant your loan request: %s" % [lender, str(result.get("reason", "failed"))]
					_pridej_popup_hraci(borrower, "Loans", fail_take_text, true)
					_pridej_notifikaci_pujcky_hraci(borrower, fail_take_text)
				elif je_lidsky_stat(lender):
					var fail_text = "%s could not accept your loan offer: %s" % [borrower, str(result.get("reason", "failed"))]
					_pridej_popup_hraci(lender, "Loans", fail_text, true)
					_pridej_notifikaci_pujcky_hraci(lender, fail_text)
			elif request_kind == "take" and je_lidsky_stat(borrower):
				var granted_text = "%s granted your loan request." % lender
				_pridej_popup_hraci(borrower, "Loans", granted_text, true)
				_pridej_notifikaci_pujcky_hraci(borrower, granted_text)
			elif je_lidsky_stat(lender):
				var accept_text = "%s accepted your loan offer." % borrower
				_pridej_popup_hraci(lender, "Loans", accept_text, true)
				_pridej_notifikaci_pujcky_hraci(lender, accept_text)
		else:
			var reject_msg = "%s rejected loan offer from %s (%.2f mil. USD, %.2f%%, %d turns)." % [borrower, lender, principal, interest_pct, turns]
			if request_kind == "take":
				reject_msg = "%s rejected loan request from %s (%.2f mil. USD, %.2f%%, %d turns)." % [lender, borrower, principal, interest_pct, turns]
			_zaloguj_globalni_zpravu("Loans", reject_msg, "trade")
			if request_kind == "take" and je_lidsky_stat(borrower):
				var reject_take_text = "%s rejected your loan request." % lender
				_zaloguj_zpravu_hraci(borrower, "Loans", reject_take_text, "trade")
				_pridej_popup_hraci(borrower, "Loans", reject_take_text, true)
				_pridej_notifikaci_pujcky_hraci(borrower, reject_take_text)
			elif je_lidsky_stat(lender):
				var reject_text = "%s rejected your loan offer." % borrower
				_zaloguj_zpravu_hraci(lender, "Loans", reject_text, "trade")
				_pridej_popup_hraci(lender, "Loans", reject_text, true)
				_pridej_notifikaci_pujcky_hraci(lender, reject_text)

	cekajici_pujcky = stale

# Handles this gameplay/UI path.
func _trade_can_declare_war(attacker_tag: String, defender_tag: String) -> bool:
	# Inputs: attacker and defender tags.
	# Outputs: `bool` whether war declaration is legal.
	# Execution timing: Called while validating trade terms involving war action.
	# Steps: run standard war-eligibility checks and return result.
	var a = _normalizuj_tag(attacker_tag)
	var b = _normalizuj_tag(defender_tag)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	if not _stat_existuje(a) or not _stat_existuje(b):
		return false
	if jsou_ve_valce(a, b):
		return false
	if zbyva_kol_do_dalsi_valky(a, b) > 0:
		return false
	if ma_neagresivni_smlouvu(a, b):
		return false
	if ziskej_uroven_aliance(a, b) > ALLIANCE_NONE:
		return false
	return true

# Ai generated or editted start (priloha_a.txt)
func _trade_validate_terms(provider_tag: String, receiver_tag: String, terms: Dictionary) -> Dictionary:
	# Inputs: provider/receiver tags and normalized terms.
	# Outputs: validation dictionary with ok flag and details.
	# Execution timing: Called before trade execution or AI valuation.
	# Steps: validate every slot type against ownership/rules/resources.
	var provider = _normalizuj_tag(provider_tag)
	var receiver = _normalizuj_tag(receiver_tag)
	if provider == "" or receiver == "" or provider == receiver:
		return {"ok": false, "reason": "Invalid trade term parties."}

	for slot_any in terms.keys():
		var slot = str(slot_any)
		var entry = terms.get(slot_any, {}) as Dictionary
		var value_a = str(entry.get("a", "")).strip_edges()
		match slot:
			TRADE_SLOT_GOLD:
				var amount = _trade_parse_amount(value_a)
				if amount <= 0.0:
					return {"ok": false, "reason": "Trade term 'Money' must be a positive number (mil. USD)."}
				var provider_cash = _ziskej_kasu_statu(provider)
				if provider_cash + 0.0001 < amount:
					return {
						"ok": false,
						"reason": "%s does not have enough treasury for this money transfer (required %.2f mil. USD, available %.2f mil. USD)." % [provider, amount, provider_cash],
						"required": amount,
						"available": provider_cash
					}
			TRADE_SLOT_PROVINCE:
				var province_ids = _trade_parse_province_ids(value_a)
				if province_ids.is_empty():
					return {"ok": false, "reason": "Trade term 'Province' requires at least one valid numeric province ID."}
				for province_id_any in province_ids:
					var province_id = int(province_id_any)
					if province_id < 0 or not map_data.has(province_id):
						return {"ok": false, "reason": "Province %d does not exist." % province_id}
					var province = map_data[province_id] as Dictionary
					var province_owner = _normalizuj_tag(str(province.get("province_owner", "")))
					if province_owner != provider:
						return {"ok": false, "reason": "Province %d is not owned by %s." % [province_id, provider]}
					if bool(province.get("is_capital", false)):
						return {"ok": false, "reason": "Capital province cannot be traded (province %d)." % province_id}
			TRADE_SLOT_DECLARE_WAR:
				var war_target = _trade_parse_target_tag(value_a)
				if war_target == "" or war_target == provider or war_target == receiver:
					return {"ok": false, "reason": "Trade term 'Declare War' needs a valid third-party tag."}
				if not _trade_can_declare_war(provider, war_target):
					return {"ok": false, "reason": "%s cannot declare war on %s under current diplomacy constraints." % [provider, war_target]}
			TRADE_SLOT_JOIN_ALLIANCE:
				var alliance_id = value_a
				if alliance_id == "":
					return {"ok": false, "reason": "Trade term 'Join Alliance' requires an alliance selection."}
				var alliance = ziskej_alianci_podle_id(alliance_id)
				if alliance.is_empty():
					return {"ok": false, "reason": "Selected alliance does not exist anymore."}
				var members = alliance.get("members", []) as Array
				if members.has(provider):
					return {"ok": false, "reason": "%s is already in selected alliance." % provider}
				var conditions = ziskej_podminky_clenstvi_aliance(alliance_id, provider)
				for cond_any in conditions:
					var cond = cond_any as Dictionary
					if not bool(cond.get("met", false)):
						return {
							"ok": false,
							"reason": "%s does not meet conditions to join alliance '%s'." % [provider, str(alliance.get("name", alliance_id))]
						}
			TRADE_SLOT_IMPROVE_RELATIONSHIP_WITH:
				var improve_target = _trade_parse_target_tag(value_a)
				if improve_target == "" or improve_target == "SEA" or improve_target == provider:
					return {"ok": false, "reason": "Trade term 'Improve Relationship With' needs a valid target country."}
				if not _stat_existuje(improve_target):
					return {"ok": false, "reason": "Target country for relation change does not exist on current map."}
			TRADE_SLOT_WORSEN_RELATIONSHIP_WITH:
				var worsen_target = _trade_parse_target_tag(value_a)
				if worsen_target == "" or worsen_target == "SEA" or worsen_target == provider:
					return {"ok": false, "reason": "Trade term 'Worsen Relationship With' needs a valid target country."}
				if not _stat_existuje(worsen_target):
					return {"ok": false, "reason": "Target country for relation change does not exist on current map."}
			TRADE_SLOT_NON_AGGRESSION:
				if jsou_ve_valce(provider, receiver):
					return {"ok": false, "reason": "Non-aggression pact cannot be signed during war."}
			_:
				return {"ok": false, "reason": "Unsupported trade term: %s" % slot}

	return {"ok": true}

# Ai generated or editted end (priloha_a.txt)
func _trade_transfer_province(provider_tag: String, receiver_tag: String, province_id: int) -> Dictionary:
	# Inputs: provider/receiver tags and province id.
	# Outputs: transfer result dictionary.
	# Execution timing: Called while executing accepted trades.
	# Steps: validate ownership/constraints, transfer province owner and related state fields.
	var provider = _normalizuj_tag(provider_tag)
	var receiver = _normalizuj_tag(receiver_tag)
	if not map_data.has(province_id):
		return {"ok": false, "reason": "Province not found."}
	var d = map_data[province_id] as Dictionary
	if _normalizuj_tag(str(d.get("owner", ""))) != provider:
		return {"ok": false, "reason": "Province is no longer owned by trade provider."}
	if bool(d.get("is_capital", false)):
		return {"ok": false, "reason": "Capital province cannot be traded."}

	var profile = _ziskej_profile_statu_pro_mir(receiver)
	d["owner"] = receiver
	d["core_owner"] = receiver
	d["country_name"] = str(profile.get("country_name", receiver))
	d["ideology"] = str(profile.get("ideology", ""))
	d["army_owner"] = receiver if int(d.get("soldiers", 0)) > 0 else ""
	return {"ok": true}

# Runs the local feature logic.
func _trade_execute_terms(provider_tag: String, receiver_tag: String, terms: Dictionary) -> Dictionary:
	# Inputs: provider tag, receiver tag, term payload.
	# Outputs: execution result dictionary.
	# Execution timing: Called when applying one side of a finalized trade.
	# Steps: execute each slot atomically-ish, collect results/errors.
	var provider = _normalizuj_tag(provider_tag)
	var receiver = _normalizuj_tag(receiver_tag)
	var map_changed := false

	for slot_any in terms.keys():
		var slot = str(slot_any)
		var entry = terms.get(slot_any, {}) as Dictionary
		var value_a = str(entry.get("a", "")).strip_edges()
		match slot:
			TRADE_SLOT_GOLD:
				var amount = _trade_parse_amount(value_a)
				if amount <= 0.0:
					return {"ok": false, "reason": "Invalid money amount in trade execution."}
				var provider_cash = _ziskej_kasu_statu(provider)
				if provider_cash + 0.0001 < amount:
					return {
						"ok": false,
						"reason": "%s does not have enough treasury to complete trade (required %.2f mil. USD, available %.2f mil. USD)." % [provider, amount, provider_cash],
						"required": amount,
						"available": provider_cash
					}
				var receiver_cash = _ziskej_kasu_statu(receiver)
				_nastav_kasu_statu(provider, provider_cash - amount)
				_nastav_kasu_statu(receiver, receiver_cash + amount)
				_uprav_vztah_statu_bez_cooldown(provider, receiver, clamp(amount / 40.0, 0.5, 12.0))
			TRADE_SLOT_PROVINCE:
				var province_ids = _trade_parse_province_ids(value_a)
				if province_ids.is_empty():
					return {"ok": false, "reason": "No provinces were provided for transfer."}
				for province_id_any in province_ids:
					var province_id = int(province_id_any)
					var transfer_res = _trade_transfer_province(provider, receiver, province_id)
					if not bool(transfer_res.get("ok", false)):
						return transfer_res
				map_changed = true
			TRADE_SLOT_DECLARE_WAR:
				var war_target = _trade_parse_target_tag(value_a)
				if not vyhlasit_valku(provider, war_target):
					return {"ok": false, "reason": "%s failed to declare war on %s." % [provider, war_target]}
			TRADE_SLOT_JOIN_ALLIANCE:
				var alliance_id = value_a
				var join_result = pridej_clena_do_aliance(alliance_id, provider, false)
				if not bool(join_result.get("ok", false)):
					return {"ok": false, "reason": str(join_result.get("reason", "Failed to join selected alliance."))}
			TRADE_SLOT_IMPROVE_RELATIONSHIP_WITH:
				var improve_target = _trade_parse_target_tag(value_a)
				_uprav_vztah_statu_bez_cooldown(provider, improve_target, absf(RELATION_STEP_PLAYER))
			TRADE_SLOT_WORSEN_RELATIONSHIP_WITH:
				var worsen_target = _trade_parse_target_tag(value_a)
				_uprav_vztah_statu_bez_cooldown(provider, worsen_target, -absf(RELATION_STEP_PLAYER))
			TRADE_SLOT_NON_AGGRESSION:
				if not ma_neagresivni_smlouvu(provider, receiver):
					if not uzavrit_neagresivni_smlouvu(provider, receiver):
						return {"ok": false, "reason": "Non-aggression pact term could not be executed."}
			_:
				return {"ok": false, "reason": "Unsupported trade term during execution: %s" % slot}

	return {"ok": true, "map_changed": map_changed}

# Ai generated or editted start (priloha_a.txt)
func _trade_update_map_after_changes() -> void:
	# Inputs: none.
	# Outputs: none.
	# Execution timing: Called after province/ownership changes from trade.
	# Steps: refresh map visuals, labels, and affected runtime caches.
	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()

# Ai generated or editted end (priloha_a.txt)
func _trade_spocitej_hodnotu_terms(receiver_tag: String, provider_tag: String, terms: Dictionary) -> float:
	# Inputs: receiver/provider tags and terms.
	# Outputs: numeric value estimate of term package.
	# Execution timing: Called by AI trade decision heuristics.
	# Steps: score each slot type by configured value rules and sum.
	var receiver = _normalizuj_tag(receiver_tag)
	var provider = _normalizuj_tag(provider_tag)
	var score := 0.0
	for slot_any in terms.keys():
		var slot = str(slot_any)
		var entry = terms.get(slot_any, {}) as Dictionary
		var value_a = str(entry.get("a", "")).strip_edges()
		match slot:
			TRADE_SLOT_GOLD:
				var amount = max(0.0, _trade_parse_amount(value_a))
				score += clamp(amount / 20.0, 0.5, 35.0)
			TRADE_SLOT_PROVINCE:
				var province_ids = _trade_parse_province_ids(value_a)
				for province_id_any in province_ids:
					var province_id = int(province_id_any)
					if province_id >= 0 and map_data.has(province_id):
						var d = map_data[province_id] as Dictionary
						var gdp = max(0.0, float(d.get("gdp", 0.0)))
						score += 8.0 + clamp(gdp / 60.0, 0.0, 28.0)
			TRADE_SLOT_DECLARE_WAR:
				var target = _trade_parse_target_tag(value_a)
				if target != "":
					var rel = ziskej_vztah_statu(provider, target)
					score += 4.0 if rel < -10.0 else -8.0
			TRADE_SLOT_JOIN_ALLIANCE:
				var alliance = ziskej_alianci_podle_id(value_a)
				if not alliance.is_empty():
					var members = alliance.get("members", []) as Array
					if members.has(receiver):
						score += 12.0
					else:
						score += 5.0
			TRADE_SLOT_IMPROVE_RELATIONSHIP_WITH:
				var improve_target = _trade_parse_target_tag(value_a)
				if improve_target != "":
					var rel_improve = ziskej_vztah_statu(receiver, improve_target)
					score += 6.0 if rel_improve >= 0.0 else -4.0
			TRADE_SLOT_WORSEN_RELATIONSHIP_WITH:
				var worsen_target = _trade_parse_target_tag(value_a)
				if worsen_target != "":
					var rel_worsen = ziskej_vztah_statu(receiver, worsen_target)
					score += 6.0 if rel_worsen < 0.0 else -5.0
			TRADE_SLOT_NON_AGGRESSION:
				score += 7.0
	return score

# Ai generated or editted start (priloha_a.txt)
func _vyhodnot_trade_nabidku_ai(from_tag: String, to_tag: String, from_terms: Dictionary, to_terms: Dictionary) -> bool:
	# Inputs: sender/receiver tags and both term sets.
	# Outputs: `bool` AI accept/reject decision.
	# Execution timing: Called immediately for AI trade responses.
	# Steps: compare offered vs requested value and apply AI thresholds.
	var ai_gain = _trade_spocitej_hodnotu_terms(to_tag, from_tag, from_terms)
	var ai_cost = _trade_spocitej_hodnotu_terms(to_tag, from_tag, to_terms)
	var relation = ziskej_vztah_statu(from_tag, to_tag)
	var threshold = 1.0 - clamp(relation / 25.0, -2.0, 2.0)
	return (ai_gain - ai_cost) >= threshold

# Ai generated or editted end (priloha_a.txt)
func _proved_trade_dohodu(from_tag: String, to_tag: String, payload: Dictionary) -> Dictionary:
	# Inputs: two state tags and full trade payload.
	# Outputs: trade execution result dictionary.
	# Execution timing: Called once both parties accept deal.
	# Steps: validate both directions, execute terms, refresh map, log notifications.
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	var from_terms = _normalizuj_trade_terms(payload.get("from_terms", {}) as Dictionary)
	var to_terms = _normalizuj_trade_terms(payload.get("to_terms", {}) as Dictionary)

	var check_sender = _trade_validate_terms(from_clean, to_clean, from_terms)
	if not bool(check_sender.get("ok", false)):
		return check_sender
	var check_receiver = _trade_validate_terms(to_clean, from_clean, to_terms)
	if not bool(check_receiver.get("ok", false)):
		return check_receiver

	var sender_exec = _trade_execute_terms(from_clean, to_clean, from_terms)
	if not bool(sender_exec.get("ok", false)):
		return sender_exec
	var receiver_exec = _trade_execute_terms(to_clean, from_clean, to_terms)
	if not bool(receiver_exec.get("ok", false)):
		return receiver_exec

	var map_changed = bool(sender_exec.get("map_changed", false)) or bool(receiver_exec.get("map_changed", false))
	if map_changed:
		_trade_update_map_after_changes()

	_invalidate_turn_cache()
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	_zaloguj_globalni_zpravu("Trade", "%s and %s completed a trade agreement." % [from_clean, to_clean], "trade")
	if je_lidsky_stat(from_clean) or je_lidsky_stat(to_clean):
		_pridej_popup_zucastnenym_hracum(from_clean, to_clean, "Trade", "%s and %s completed a trade agreement." % [from_clean, to_clean])

	return {
		"ok": true,
		"from": from_clean,
		"to": to_clean,
		"map_changed": map_changed,
		"from_terms": from_terms,
		"to_terms": to_terms
	}

# Eligibility/guard check.
func _je_more_provincie(prov_id: int) -> bool:
	# Inputs: province id.
	# Outputs: true when province is sea-type.
	# Execution timing: Called by naval/coastal/build checks.
	# Steps: read province terrain/type flags and return sea status.
	if not map_data.has(prov_id):
		return false
	var d = map_data[prov_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner_tag == "SEA" or typ == "sea"

# Validates required conditions.
func je_pobrezni_provincie(prov_id: int) -> bool:
	# Inputs: province id.
	# Outputs: true when province borders sea.
	# Execution timing: Called by port eligibility and naval logic.
	# Steps: inspect neighbors and detect adjacency to sea province.
	if not map_data.has(prov_id):
		return false
	if _je_more_provincie(prov_id):
		return false
	for n_id in map_data[prov_id].get("neighbors", []):
		if _je_more_provincie(int(n_id)):
			return true
	return false

func provincie_ma_pristav(prov_id: int) -> bool:
	# Inputs: province id.
	# Outputs: true when province has port building/flag.
	# Execution timing: Called by movement/building availability checks.
	# Steps: inspect province building data for port presence.
	if not map_data.has(prov_id):
		return false
	return bool(map_data[prov_id].get("has_port", false))

# Runs the local feature logic.
func muze_postavit_pristav(prov_id: int) -> bool:
	# Inputs: province id.
	# Outputs: true when port can be built.
	# Execution timing: Called by UI before showing build action.
	# Steps: enforce coastal/ownership/existing-port restrictions.
	if not map_data.has(prov_id):
		return false
	var owner_tag = str(map_data[prov_id].get("owner", "")).strip_edges().to_upper()
	if owner_tag == "" or owner_tag == "SEA":
		return false
	if provincie_cooldowny.has(prov_id):
		return false
	if provincie_ma_pristav(prov_id):
		return false
	return je_pobrezni_provincie(prov_id)

# Fetches data for callers.
func _legacy_building_id(building_any) -> String:
	# Inputs: mixed legacy/new building identifier value.
	# Outputs: normalized building id string.
	# Execution timing: Called when loading old saves and build APIs.
	# Steps: map aliases/legacy keys to canonical ids.
	if building_any is String:
		return str(building_any).strip_edges().to_lower()
	var typ = int(building_any)
	if typ == 0:
		return BUILDING_ID_ECON_HUB
	if typ == 1:
		return BUILDING_ID_RECRUIT_CENTER
	if typ == 2:
		return BUILDING_ID_PORT
	return ""

# Applies incoming data to runtime state.
func _normalizuj_provincie_cooldowny(raw_any) -> Dictionary:
	# Inputs: raw cooldown payload.
	# Outputs: normalized province cooldown dictionary.
	# Execution timing: Called during save-load normalization.
	# Steps: coerce keys/values into expected int->int map.
	if not (raw_any is Dictionary):
		return {}
	var raw = raw_any as Dictionary
	var out: Dictionary = {}
	for prov_key in raw.keys():
		var prov_id = int(prov_key)
		if prov_id <= 0:
			continue

		var entry = raw[prov_key]
		var build_id := ""
		var zbyva := 1

		if entry is Dictionary:
			var e = entry as Dictionary
			var build_any = e.get("budova", e.get("building", e.get("building_id", e.get("typ", e.get("type", e.get("building_type", ""))))))
			build_id = _legacy_building_id(build_any)
			zbyva = int(e.get("zbyva", e.get("remaining", e.get("remaining_turns", e.get("turns", 1)))))
		elif entry is Array:
			var arr = entry as Array
			if arr.size() >= 2:
				zbyva = int(arr[0])
				build_id = _legacy_building_id(arr[1])
		elif entry is String:
			build_id = _legacy_building_id(entry)
		elif entry is int or entry is float:
			var as_int = int(entry)
			if as_int >= 0 and as_int <= 2:
				build_id = _legacy_building_id(as_int)

		if build_id == "" or _ziskej_building_def(build_id).is_empty():
			continue
		out[prov_id] = {"zbyva": max(1, zbyva), "budova": build_id}
	return out

# Read-only data accessor.
func _ziskej_building_def(building_id: String) -> Dictionary:
	# Inputs: building id.
	# Outputs: building definition dictionary or empty.
	# Execution timing: Called by build validation and UI rendering.
	# Steps: normalize id and return matching definition.
	if BUILDING_DEFS.has(building_id):
		return BUILDING_DEFS[building_id] as Dictionary
	return {}

# Fetches data for callers.
func _ziskej_nazev_budovy(building_any) -> String:
	# Inputs: building id/legacy value.
	# Outputs: display name for building.
	# Execution timing: Called by UI and logs.
	# Steps: normalize id, fetch definition name, fallback to id text.
	var build_id = _legacy_building_id(building_any)
	var bdef = _ziskej_building_def(build_id)
	if bdef.is_empty():
		return "Building"
	return str(bdef.get("name", "Building"))

# Returns current runtime data.
func ziskej_dostupne_building_ids() -> Array:
	# Inputs: none.
	# Outputs: available canonical building id list.
	# Execution timing: Called when building UI initializes.
	# Steps: iterate definitions and return sorted/stable id list.
	return [
		BUILDING_ID_ECON_HUB,
		BUILDING_ID_RECRUIT_CENTER,
		BUILDING_ID_PORT,
		BUILDING_ID_FARM,
		BUILDING_ID_ARMY_BASE,
		BUILDING_ID_FORTRESS
	]

# Fetches data for callers.
func ziskej_building_def_pro_ui(building_any) -> Dictionary:
	# Inputs: building id/legacy token.
	# Outputs: UI-ready building definition payload.
	# Execution timing: Called while rendering build options.
	# Steps: normalize id and expose relevant fields for interface.
	var build_id = _legacy_building_id(building_any)
	if build_id == "":
		return {}
	return _ziskej_building_def(build_id).duplicate(true)

# Validates required conditions.
func muze_postavit_budovu(prov_id: int, building_any) -> Dictionary:
	# Inputs: province id and building identifier.
	# Outputs: eligibility result dictionary with reason/cost.
	# Execution timing: Called before constructing buildings.
	# Steps: validate owner/state/rules/cooldowns/funds and return result.
	# Validation order matters here: fast reject invalid ownership/cooldown first,
	# then expensive checks (definition lookup and cost validation).
	if not map_data.has(prov_id):
		return {"ok": false, "reason": "Invalid province."}

	var owner_tag = _normalizuj_tag(str((map_data[prov_id] as Dictionary).get("owner", "")))
	if owner_tag == "" or owner_tag == "SEA":
		return {"ok": false, "reason": "Construction is only possible on land provinces."}
	if owner_tag != _normalizuj_tag(hrac_stat):
		return {"ok": false, "reason": "You can only build in your own provinces."}
	if provincie_cooldowny.has(prov_id):
		return {"ok": false, "reason": "Another construction is already in progress here."}

	var building_id = _legacy_building_id(building_any)
	if building_id == "":
		return {"ok": false, "reason": "Unknown building type."}
	var bdef = _ziskej_building_def(building_id)
	if bdef.is_empty():
		return {"ok": false, "reason": "Unknown building type."}

	var level = _ziskej_level_budovy_provincie(prov_id, building_id)
	var max_level = max(1, int(bdef.get("max_level", 1)))
	if level >= max_level:
		return {"ok": false, "reason": "Maximum level already reached."}

	if building_id == BUILDING_ID_PORT and not muze_postavit_pristav(prov_id):
		return {"ok": false, "reason": "A port can only be built in your coastal province adjacent to sea."}

	var cost = max(0.0, float(bdef.get("cost", 0.0)))
	if _ziskej_kasu_statu(owner_tag) < cost:
		return {"ok": false, "reason": "Not enough money.", "cost": cost}

	return {
		"ok": true,
		"building_id": building_id,
		"cost": cost,
		"build_time": max(1, int(bdef.get("build_time", 3))),
		"name": str(bdef.get("name", "Building")),
		"current_level": level,
		"next_level": level + 1,
		"max_level": max_level
	}

# Handles this gameplay/UI path.
func rozpocni_stavbu_pro_hrace(prov_id: int, building_any) -> Dictionary:
	# Inputs: province id and building identifier.
	# Outputs: build-start result dictionary.
	# Execution timing: Called when player confirms construction.
	# Steps: validate build, deduct funds, set cooldown/queue, emit update.
	# One-way transaction: verify -> charge treasury -> create cooldown record.
	# If validation fails, this function returns early and does not mutate state.
	var can_build = muze_postavit_budovu(prov_id, building_any)
	if not bool(can_build.get("ok", false)):
		return can_build

	var owner_tag = _normalizuj_tag(str((map_data[prov_id] as Dictionary).get("owner", "")))
	var cost = float(can_build.get("cost", 0.0))
	_nastav_kasu_statu(owner_tag, _ziskej_kasu_statu(owner_tag) - cost)

	var build_time = max(1, int(can_build.get("build_time", 3)))
	var building_id = str(can_build.get("building_id", ""))
	provincie_cooldowny[prov_id] = {"zbyva": build_time, "budova": building_id}

	var out = can_build.duplicate(true)
	out["cash_after"] = _ziskej_kasu_statu(owner_tag)
	return out

# Reads values from active state.
func _ziskej_buildings_provincie(prov_id: int) -> Dictionary:
	# Inputs: province id.
	# Outputs: province building-level dictionary.
	# Execution timing: Called by building modifier/read helpers.
	# Steps: ensure province building map exists and return it.
	if not map_data.has(prov_id):
		return {}
	var d = map_data[prov_id] as Dictionary
	if not d.has("buildings") or not (d.get("buildings") is Dictionary):
		d["buildings"] = {}
	return d["buildings"] as Dictionary

# Reads values from active state.
func _ziskej_level_budovy_provincie(prov_id: int, building_id: String) -> int:
	# Inputs: province id and building id.
	# Outputs: current building level in province.
	# Execution timing: Called by validation/modifier logic.
	# Steps: read province building map and return level fallback 0.
	if not map_data.has(prov_id):
		return 0
	var buildings = _ziskej_buildings_provincie(prov_id)
	return max(0, int(buildings.get(building_id, 0)))

# Applies updates and syncs dependent state.
func _pridej_budovu_provincie(prov_id: int, building_id: String) -> bool:
	# Inputs: province id and building id.
	# Outputs: true when level increment applied.
	# Execution timing: Called when construction completes.
	# Steps: validate building def/max level and increment province level.
	if not map_data.has(prov_id):
		return false
	var bdef = _ziskej_building_def(building_id)
	if bdef.is_empty():
		return false
	var buildings = _ziskej_buildings_provincie(prov_id)
	var level = int(buildings.get(building_id, 0))
	var max_level = max(1, int(bdef.get("max_level", 1)))
	if level >= max_level:
		return false
	buildings[building_id] = level + 1
	return true

# Computes derived values from current inputs and game state.
func _ziskej_modifikatory_budov_provincie(prov_id: int) -> Dictionary:
	# Inputs: province id.
	# Outputs: aggregated province-level building modifiers.
	# Execution timing: Called in economy/upkeep/growth calculations.
	# Steps: accumulate modifiers from all buildings/levels in province.
	var out := {
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0,
		"upkeep_mult": 1.0
	}
	if not map_data.has(prov_id):
		return out
	var buildings = _ziskej_buildings_provincie(prov_id)
	for building_id in buildings.keys():
		var level = max(0, int(buildings[building_id]))
		if level <= 0:
			continue
		var bdef = _ziskej_building_def(str(building_id))
		if bdef.is_empty():
			continue
		var province_mods = bdef.get("province_modifiers", {}) as Dictionary
		for k in province_mods.keys():
			if not out.has(k):
				continue
			out[k] = float(out[k]) * pow(max(0.01, float(province_mods[k])), level)
	return out

# Computes derived values from current inputs and game state.
func _ziskej_modifikatory_budov_statu(state_tag: String) -> Dictionary:
	# Inputs: state tag.
	# Outputs: aggregated state-wide building modifiers.
	# Execution timing: Called by state economic projection functions.
	# Steps: sum province modifiers across owned provinces.
	var out := {
		"recruit_cost_mult": 1.0,
		"upkeep_mult": 1.0,
		"income_rate_mult": 1.0,
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0
	}
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return out
	for p_id in map_data.keys():
		var d = map_data[p_id] as Dictionary
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		var buildings = _ziskej_buildings_provincie(int(p_id))
		for building_id in buildings.keys():
			var level = max(0, int(buildings[building_id]))
			if level <= 0:
				continue
			var bdef = _ziskej_building_def(str(building_id))
			if bdef.is_empty():
				continue
			var state_mods = bdef.get("state_modifiers", {}) as Dictionary
			for k in state_mods.keys():
				if not out.has(k):
					continue
				out[k] = float(out[k]) * pow(max(0.01, float(state_mods[k])), level)
	return out

# Fetches data for callers.
func ziskej_bonus_obrany_stavby_provincie(prov_id: int) -> float:
	# Inputs: province id.
	# Outputs: defense bonus percentage from buildings.
	# Execution timing: Called by combat resolution.
	# Steps: read building defs in province and sum defense bonuses.
	if not map_data.has(prov_id):
		return 0.0
	var bonus := 0.0
	var buildings = _ziskej_buildings_provincie(prov_id)
	for building_id in buildings.keys():
		var level = max(0, int(buildings[building_id]))
		if level <= 0:
			continue
		var bdef = _ziskej_building_def(str(building_id))
		if bdef.is_empty():
			continue
		bonus += float(bdef.get("defense_bonus_pct", 0.0)) * float(level)
	return bonus

