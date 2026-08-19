extends "res://scripts/GameEconomy.gd"

## Relationships, alliances, access treaties, and diplomatic requests.

func uprav_vztah_statu(tag_a: String, tag_b: String, delta: float) -> float:
	# Inputs: two state tags and relation delta.
	# Outputs: updated relation value.
	# Execution timing: Called by player-triggered relation actions.
	# Steps: enforce cooldown/rules, apply delta, sync dependent diplomacy.
	var result = _get_relationship_store().adjust(tag_a, tag_b, delta, RELATION_MIN, RELATION_MAX, aktualni_kolo, RELATION_ACTION_COOLDOWN_TURNS)
	return _finalize_relation_adjustment(result, delta, true)

func _uprav_vztah_statu_bez_cooldown(tag_a: String, tag_b: String, delta: float) -> float:
	# Inputs: two tags and relation delta.
	# Outputs: updated relation value.
	# Execution timing: Internal helper when cooldown should be bypassed.
	# Steps: apply clamped delta then run synchronization hooks.
	var result = _get_relationship_store().adjust(tag_a, tag_b, delta, RELATION_MIN, RELATION_MAX)
	return _finalize_relation_adjustment(result, delta, true)

# Ai generated or editted start (priloha_a.txt)
func _uprav_vztah_statu_bez_cooldown_rychle(tag_a: String, tag_b: String, delta: float) -> float:
	# Inputs: two tags and delta.
	# Outputs: updated relation value.
	# Execution timing: Hot-path relation adjuster for AI batch updates.
	# Steps: apply minimal-overhead relation update and return new value.
	var result = _get_relationship_store().adjust(tag_a, tag_b, delta, RELATION_MIN, RELATION_MAX)
	return _finalize_relation_adjustment(result, delta, false)

func _finalize_relation_adjustment(result: Dictionary, delta: float, write_log: bool) -> float:
	if not bool(result.get("valid", false)):
		return 0.0
	var updated = float(result.get("new", 0.0))
	if not bool(result.get("changed", false)):
		return updated
	var a = str(result.get("a", ""))
	var b = str(result.get("b", ""))
	var pair_key = str(result.get("pair_key", ""))
	var current = float(result.get("old", updated))
	_ai_relation_cache[pair_key] = updated
	_ai_can_adjust_relation_cache.erase(pair_key)
	_mark_ai_war_pair_eval_dirty_pair(a, b)
	if write_log and not is_zero_approx(delta) and not _suppress_relation_global_logs:
		var action_txt = "improved" if delta > 0.0 else "worsened"
		_zaloguj_globalni_zpravu("Relations", "%s %s relation with %s to %.1f." % [a, action_txt, b, updated], "relations")
	if _vyzaduje_vztahova_synchronizace(current, updated):
		_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return updated

# Ai generated or editted end (priloha_a.txt)
func _vyzaduje_vztahova_synchronizace(old_rel: float, new_rel: float) -> bool:
	# Inputs: old and new relation values.
	# Outputs: true when alliance/access sync should run.
	# Execution timing: Called after relation updates.
	# Steps: compare threshold crossings that affect diplomacy contracts.
	if new_rel >= old_rel:
		return false
	for threshold in [15.0, ALLIANCE_MIN_REL_DEFENSE, ALLIANCE_MIN_REL_OFFENSE, ALLIANCE_MIN_REL_FULL]:
		if old_rel >= threshold and new_rel < threshold:
			return true
	return false

# Ai generated or editted start (priloha_a.txt)
func zlepsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	# Inputs: two tags and optional amount.
	# Outputs: updated relation value.
	# Execution timing: Called by improve-relation action.
	# Steps: call relation update with positive delta.
	return uprav_vztah_statu(tag_a, tag_b, absf(amount))

# Ai generated or editted end (priloha_a.txt)
func zhorsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	# Inputs: two tags and optional amount.
	# Outputs: updated relation value.
	# Execution timing: Called by worsen-relation action.
	# Steps: call relation update with negative delta.
	return uprav_vztah_statu(tag_a, tag_b, -absf(amount))

# Core flow for this feature.
func nazev_urovne_aliance(level: int) -> String:
	# Inputs: alliance level id.
	# Outputs: localized/display name for level.
	# Execution timing: Called by UI and logs.
	# Steps: map level constant to human-readable label.
	match level:
		ALLIANCE_DEFENSE:
			return "Defensive Alliance"
		ALLIANCE_OFFENSE:
			return "Offensive Alliance"
		ALLIANCE_FULL:
			return "Full Alliance"
		_:
			return "No Alliance"

# Returns true when conditions are met.
func _ma_stat_prijmout_alianci(tag_a: String, tag_b: String, target_level: int) -> bool:
	# Inputs: two tags and proposed alliance level.
	# Outputs: AI acceptance boolean.
	# Execution timing: Called for AI response to alliance requests.
	# Steps: evaluate relation/war/contract constraints and return decision.
	if _vazal_musi_prijmout_zadost(tag_a, tag_b):
		return true
	var rel = ziskej_vztah_statu(tag_a, tag_b)
	if rel < ALLIANCE_HARD_REJECT_REL:
		return false
	return rel >= _minimalni_vztah_pro_alianci(target_level)

# Pulls current state data.
func ziskej_uroven_aliance(tag_a: String, tag_b: String) -> int:
	# Inputs: two tags.
	# Outputs: current alliance level between states.
	# Execution timing: Called by diplomacy UI and war logic.
	# Steps: read normalized pair key from alliance state map.
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return ALLIANCE_NONE
	return int(aliance_statu.get(key, ALLIANCE_NONE))

# Applies updates and syncs dependent state.
func _nastav_uroven_aliance_bez_kontroly(tag_a: String, tag_b: String, level: int) -> void:
	# Inputs: two tags and level.
	# Outputs: none.
	# Execution timing: Internal setter after validation is already done.
	# Steps: write or clear alliance level entry for pair.
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return
	if level <= ALLIANCE_NONE:
		aliance_statu.erase(key)
		if _ai_phase_cache_active:
			_ai_alliance_level_cache.erase(key)
			_ai_allies_cache.clear()
			_mark_ai_war_pair_eval_dirty_pair(tag_a, tag_b)
		return
	aliance_statu[key] = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if _ai_phase_cache_active:
		_ai_alliance_level_cache[key] = int(aliance_statu[key])
		_ai_allies_cache.clear()
		_mark_ai_war_pair_eval_dirty_pair(tag_a, tag_b)

# If relation drops under thresholds, alliance gets downgraded automaticky.
# Applies incoming data to runtime state.
func nastav_uroven_aliance(tag_a: String, tag_b: String, level: int, ignoruj_vztahove_podminky: bool = false) -> bool:
	# Inputs: two tags, target level, ignore-relation flag.
	# Outputs: true when alliance level changed.
	# Execution timing: Called by alliance actions and treaty effects.
	# Steps: validate constraints, set level, sync groups/related diplomacy.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var target_level = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if a == "" or b == "" or a == b:
		return false

	if jsou_ve_valce(a, b):
		if target_level > ALLIANCE_NONE:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Alliance cannot be formed during an active war.")
			return false

	var old_level = ziskej_uroven_aliance(a, b)
	if target_level > ALLIANCE_NONE:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if (not ignoruj_vztahove_podminky) and target_level > old_level and not _ma_stat_prijmout_alianci(a, b, target_level):
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				if rel < ALLIANCE_HARD_REJECT_REL:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s and %s do not get along (relation %.1f), alliance rejected." % [a, b, rel])
				else:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s rejects %s: %s requires relation at least %.1f." % [b, a, nazev_urovne_aliance(target_level), needed_rel])
			return false
		if (not ignoruj_vztahove_podminky) and rel < needed_rel:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Relation %.1f is too low for %s (needs %.1f)." % [rel, nazev_urovne_aliance(target_level), needed_rel])
			return false

	_nastav_uroven_aliance_bez_kontroly(a, b, target_level)

	if old_level != target_level:
		_zaloguj_globalni_zpravu("Alliance", "Alliance between %s and %s: %s." % [a, b, nazev_urovne_aliance(target_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var title = "Diplomacy"
			var text = "Alliance between %s and %s: %s" % [a, b, nazev_urovne_aliance(target_level)]
			_pridej_popup_zucastnenym_hracum(a, b, title, text)
	return true

# Handles this gameplay/UI path.
func _synchronizuj_aliance_po_zmene_vztahu(tag_a: String, tag_b: String) -> void:
	# Inputs: two tags with changed relation.
	# Outputs: none.
	# Execution timing: Called after relation updates.
	# Steps: downgrade/remove alliance levels that no longer satisfy thresholds.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return

	var current_level = ziskej_uroven_aliance(a, b)
	if current_level <= ALLIANCE_NONE:
		return

	if jsou_ve_valce(a, b):
		_nastav_uroven_aliance_bez_kontroly(a, b, ALLIANCE_NONE)
		return

	var rel = ziskej_vztah_statu(a, b)
	var new_level = current_level
	if rel < ALLIANCE_MIN_REL_DEFENSE:
		new_level = ALLIANCE_NONE
	elif rel < ALLIANCE_MIN_REL_OFFENSE:
		new_level = min(new_level, ALLIANCE_DEFENSE)
	elif rel < ALLIANCE_MIN_REL_FULL:
		new_level = min(new_level, ALLIANCE_OFFENSE)

	if new_level != current_level:
		_nastav_uroven_aliance_bez_kontroly(a, b, new_level)
		_zaloguj_globalni_zpravu("Alliance", "Relations weakened the alliance %s-%s: %s." % [a, b, nazev_urovne_aliance(new_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var text = "Relations weakened the alliance %s-%s: %s" % [a, b, nazev_urovne_aliance(new_level)]
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", text)
		if new_level == ALLIANCE_NONE:
			_expeluj_jednotky_bez_pristupu(a)
			_expeluj_jednotky_bez_pristupu(b)

	_synchronizuj_vojensky_pristup_po_zmene_vztahu(a, b)

func _synchronizuj_vojensky_pristup_po_zmene_vztahu(tag_a: String, tag_b: String) -> void:
	# Inputs: two tags with changed relation.
	# Outputs: none.
	# Execution timing: Called after relation updates.
	# Steps: remove/adjust military access agreements when relation is too low.
	var rel = ziskej_vztah_statu(tag_a, tag_b)
	if rel >= 15.0:
		return
	# Revoke A->B grant if A gave B access
	for pair in [[tag_a, tag_b], [tag_b, tag_a]]:
		var host = pair[0]
		var guest = pair[1]
		var key = "%s|%s" % [host, guest]
		if vojensky_pristup.has(key):
			vojensky_pristup.erase(key)
			_zaloguj_globalni_zpravu("Diplomacy", "Military access %s->%s revoked (relations dropped below 15)." % [host, guest], "diplomacy")
			if je_lidsky_stat(guest):
				_pridej_popup_hraci(guest, "Diplomacy", "Military access in %s revoked - relations dropped too low." % host)
			if je_lidsky_stat(host):
				_pridej_popup_hraci(host, "Diplomacy", "You revoked military access for %s (relations too low)." % guest)
			_expeluj_jednotky_bez_pristupu(guest)

# ---- Alliance Groups ----

# Handles this gameplay/UI path.
func _generuj_id_aliance() -> String:
	# Inputs: none.
	# Outputs: unique alliance-group id string.
	# Execution timing: Called when creating new alliance groups.
	# Steps: increment sequence counter and format deterministic id.
	_aliance_skupiny_seq += 1
	return "alliance_%d" % _aliance_skupiny_seq

# Creates required nodes and connects signals.
func vytvor_alianci_skupinu(nazev: String, level: int, zakladatel: String, clenove: Array = [], barva: String = "#4488ff") -> Dictionary:
	# Inputs: name, level, founder tag, members array, color.
	# Outputs: creation result dictionary (with alliance id on success).
	# Execution timing: Called by diplomacy UI/group actions.
	# Steps: validate founder/members/level, create group record, sync pair levels.
	var founder = _normalizuj_tag(zakladatel)
	if founder == "":
		return {"ok": false, "reason": "Invalid founder tag."}
	var clean_name = nazev.strip_edges()
	if clean_name == "":
		clean_name = "Alliance %d" % (_aliance_skupiny_seq + 1)
	var target_level = clampi(level, ALLIANCE_DEFENSE, ALLIANCE_FULL)

	var alliance_id = _generuj_id_aliance()
	var member_list: Array = [founder]
	for c in clenove:
		var tag = _normalizuj_tag(str(c))
		if tag == "" or tag == "SEA" or tag == founder:
			continue
		if not member_list.has(tag):
			member_list.append(tag)

	var skupina: Dictionary = {
		"id": alliance_id,
		"name": clean_name,
		"level": target_level,
		"founder": founder,
		"members": member_list,
		"created_turn": aktualni_kolo,
		"color": barva
	}
	aliance_skupiny[alliance_id] = skupina

	_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	_zaloguj_globalni_zpravu("Alliance", "%s founded alliance '%s' (%s)." % [founder, clean_name, nazev_urovne_aliance(target_level)], "alliance")
	return {"ok": true, "id": alliance_id}

# Ai generated or editted start (priloha_a.txt)
func upravit_alianci_skupinu(alliance_id: String, novy_nazev: String = "", novy_level: int = -1) -> bool:
	# Inputs: alliance group id, optional new name, optional new level.
	# Outputs: true when edit applied.
	# Execution timing: Called when editing existing alliance groups.
	# Steps: validate group and edits, update metadata, propagate level changes.
	if not aliance_skupiny.has(alliance_id):
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var changed = false
	if novy_nazev.strip_edges() != "":
		skupina["name"] = novy_nazev.strip_edges()
		changed = true
	if novy_level >= ALLIANCE_DEFENSE and novy_level <= ALLIANCE_FULL and novy_level != int(skupina.get("level", 0)):
		skupina["level"] = novy_level
		changed = true
	if changed:
		aliance_skupiny[alliance_id] = skupina
		_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	return changed

# Ai generated or editted start (priloha_a.txt)
func pridej_clena_do_aliance(alliance_id: String, tag: String, ignoruj_vztahove_podminky: bool = false) -> Dictionary:
	# Inputs:
	# - `alliance_id`: Input argument used by `pridej_clena_do_aliance` during execution.
	# - `tag`: State tag handled by this function.
	# - `ignoruj_vztahove_podminky`: Behavior flag that toggles a conditional path.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `pridej_clena_do_aliance` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `pridej clena do aliance` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not aliance_skupiny.has(alliance_id):
		return {"ok": false, "reason": "Alliance does not exist."}
	var clean = _normalizuj_tag(tag)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid country tag."}
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	if members.has(clean):
		return {"ok": false, "reason": "%s is already a member." % clean}

	var candidate_overlord = ziskej_overlorda_statu(clean)
	var forced_by_member_overlord = (candidate_overlord != "" and members.has(candidate_overlord))
	var ignore_requirements = ignoruj_vztahove_podminky or forced_by_member_overlord

	var level = int(skupina.get("level", ALLIANCE_DEFENSE))

	if not ignore_requirements:
		for m in members:
			var member_tag = _normalizuj_tag(str(m))
			if member_tag == "" or member_tag == clean:
				continue
			if jsou_ve_valce(clean, member_tag):
				return {"ok": false, "reason": "%s is at war with member %s." % [clean, member_tag]}
			var rel = ziskej_vztah_statu(clean, member_tag)
			var needed = _minimalni_vztah_pro_alianci(level)
			if rel < needed:
				return {"ok": false, "reason": "Relation with %s is %.1f (needs %.1f for %s)." % [member_tag, rel, needed, nazev_urovne_aliance(level)]}

	members.append(clean)
	skupina["members"] = members
	aliance_skupiny[alliance_id] = skupina

	_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	_zaloguj_globalni_zpravu("Alliance", "%s joined alliance '%s'." % [clean, str(skupina.get("name", ""))], "alliance")
	if je_lidsky_stat(clean):
		_pridej_popup_hraci(clean, "Alliance", "You joined alliance '%s'." % str(skupina.get("name", "")))
	if forced_by_member_overlord and je_lidsky_stat(candidate_overlord):
		_pridej_popup_hraci(candidate_overlord, "Alliance", "%s joined '%s' automatically as your vassal." % [clean, str(skupina.get("name", ""))])
	return {"ok": true}

# Ai generated or editted end (priloha_a.txt)
func odeber_clena_z_aliance(alliance_id: String, tag: String) -> bool:
	# Inputs:
	# - `alliance_id`: Input argument used by `odeber_clena_z_aliance` during execution.
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `odeber_clena_z_aliance` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `odeber clena z aliance` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not aliance_skupiny.has(alliance_id):
		return false
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	if not members.has(clean):
		return false

	members.erase(clean)
	skupina["members"] = members

	_zaloguj_globalni_zpravu("Alliance", "%s left alliance '%s'." % [clean, str(skupina.get("name", ""))], "alliance")
	if je_lidsky_stat(clean):
		_pridej_popup_hraci(clean, "Alliance", "You left alliance '%s'." % str(skupina.get("name", "")))

	if members.size() < 2:
		var old_name = str(skupina.get("name", ""))
		aliance_skupiny.erase(alliance_id)
		_zaloguj_globalni_zpravu("Alliance", "Alliance '%s' disbanded (too few members)." % old_name, "alliance")
	else:
		aliance_skupiny[alliance_id] = skupina

	_resynchronizuj_bilateralni_aliance_vsech_skupin()
	return true

# Handles this gameplay/UI path.
func rozpust_alianci(alliance_id: String) -> bool:
	# Inputs:
	# - `alliance_id`: Input argument used by `rozpust_alianci` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `rozpust_alianci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `rozpust alianci` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not aliance_skupiny.has(alliance_id):
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var old_name = str(skupina.get("name", ""))
	var members = (skupina.get("members", []) as Array).duplicate()
	aliance_skupiny.erase(alliance_id)

	_zaloguj_globalni_zpravu("Alliance", "Alliance '%s' has been disbanded." % old_name, "alliance")
	for m in members:
		if je_lidsky_stat(str(m)):
			_pridej_popup_hraci(str(m), "Alliance", "Alliance '%s' has been disbanded." % old_name)

	_resynchronizuj_bilateralni_aliance_vsech_skupin()
	return true

# Fetches data for callers.
func ziskej_aliance_statu(tag: String) -> Array:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_aliance_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej aliance statu` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		if members.has(clean):
			result.append(skupina.duplicate(true))
	return result

# Returns current runtime data.
func ziskej_alianci_podle_id(alliance_id: String) -> Dictionary:
	# Inputs:
	# - `alliance_id`: Input argument used by `ziskej_alianci_podle_id` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_alianci_podle_id` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej alianci podle id` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not aliance_skupiny.has(alliance_id):
		return {}
	return (aliance_skupiny[alliance_id] as Dictionary).duplicate(true)

# Pulls current state data.
func ziskej_spolecne_aliance(tag_a: String, tag_b: String) -> Array:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_spolecne_aliance` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej spolecne aliance` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		if members.has(a) and members.has(b):
			result.append(skupina.duplicate(true))
	return result

# Reads values from active state.
func ziskej_podminky_clenstvi_aliance(alliance_id: String, candidate_tag: String) -> Array:
	# Inputs:
	# - `alliance_id`: Input argument used by `ziskej_podminky_clenstvi_aliance` during execution.
	# - `candidate_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_podminky_clenstvi_aliance` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej podminky clenstvi aliance` logic.
	# 3. Persist side effects and return the computed `Array` result.
	if not aliance_skupiny.has(alliance_id):
		return []
	var clean = _normalizuj_tag(candidate_tag)
	if clean == "":
		return []
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	var candidate_overlord = ziskej_overlorda_statu(clean)
	var forced_by_member_overlord = (candidate_overlord != "" and members.has(candidate_overlord))
	var level = int(skupina.get("level", ALLIANCE_DEFENSE))
	var needed_rel = _minimalni_vztah_pro_alianci(level)
	var conditions: Array = []

	for m in members:
		var member_tag = _normalizuj_tag(str(m))
		if member_tag == "" or member_tag == clean:
			continue
		var rel = ziskej_vztah_statu(clean, member_tag)
		var at_war = jsou_ve_valce(clean, member_tag)
		var oba_lidske = je_lidsky_stat(clean) and je_lidsky_stat(member_tag)
		var forced_pair = forced_by_member_overlord
		var splneno = forced_pair or oba_lidske or (rel >= needed_rel and not at_war)
		conditions.append({
			"member": member_tag,
			"relation": rel,
			"needed": needed_rel,
			"at_war": at_war,
			"both_human": oba_lidske,
			"forced_by_overlord": forced_pair,
			"overlord": candidate_overlord,
			"met": splneno
		})
	return conditions

# Core flow for this feature.
func _synchronizuj_bilateralni_aliance_skupiny(alliance_id: String) -> void:
	# Inputs:
	# - `alliance_id`: Input argument used by `_synchronizuj_bilateralni_aliance_skupiny` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_synchronizuj_bilateralni_aliance_skupiny` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` synchronizuj bilateralni aliance skupiny` logic.
	# 3. Persist side effects and finish without a return value.
	if not aliance_skupiny.has(alliance_id):
		return
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	var level = int(skupina.get("level", ALLIANCE_DEFENSE))

	for i in range(members.size()):
		for j in range(i + 1, members.size()):
			var a = _normalizuj_tag(str(members[i]))
			var b = _normalizuj_tag(str(members[j]))
			if a == "" or b == "":
				continue
			var current = ziskej_uroven_aliance(a, b)
			if level > current:
				_nastav_uroven_aliance_bez_kontroly(a, b, level)

# Runs the local feature logic.
func _resynchronizuj_bilateralni_aliance_vsech_skupin() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_resynchronizuj_bilateralni_aliance_vsech_skupin` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` resynchronizuj bilateralni aliance vsech skupin` logic.
	# 3. Persist side effects and finish without a return value.
	var max_levels: Dictionary = {}
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		var level = int(skupina.get("level", ALLIANCE_DEFENSE))
		for i in range(members.size()):
			for j in range(i + 1, members.size()):
				var a = _normalizuj_tag(str(members[i]))
				var b = _normalizuj_tag(str(members[j]))
				if a == "" or b == "":
					continue
				var key = _klic_pair(a, b)
				if key == "":
					continue
				var existing = int(max_levels.get(key, ALLIANCE_NONE))
				if level > existing:
					max_levels[key] = level

	for key in aliance_statu.keys().duplicate():
		if not max_levels.has(key):
			aliance_statu.erase(key)
			if _ai_phase_cache_active:
				_ai_alliance_level_cache.erase(key)
				var parts_remove = str(key).split("|")
				if parts_remove.size() == 2:
					_mark_ai_war_pair_eval_dirty_pair(parts_remove[0], parts_remove[1])

	for key in max_levels:
		var level = int(max_levels[key])
		var parts = key.split("|")
		if parts.size() == 2:
			_nastav_uroven_aliance_bez_kontroly(parts[0], parts[1], level)

	if _ai_phase_cache_active:
		_ai_allies_cache.clear()

# Resets transient runtime/UI data.
func _vycisti_aliance_skupiny_mrtve_staty() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_vycisti_aliance_skupiny_mrtve_staty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vycisti aliance skupiny mrtve staty` logic.
	# 3. Persist side effects and finish without a return value.
	var active = _ziskej_aktivni_staty()
	var changed = false
	for aid in aliance_skupiny.keys().duplicate():
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = (skupina.get("members", []) as Array).duplicate()
		var new_members: Array = []
		for m in members:
			if active.has(str(m)):
				new_members.append(str(m))
		if new_members.size() != members.size():
			changed = true
			if new_members.size() < 2:
				aliance_skupiny.erase(aid)
			else:
				skupina["members"] = new_members
				aliance_skupiny[aid] = skupina
	if changed:
		_resynchronizuj_bilateralni_aliance_vsech_skupin()

# Returns current runtime data.
func _ziskej_vsechny_aliance_skupiny() -> Array:
	# Inputs:
	# - none.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_vsechny_aliance_skupiny` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej vsechny aliance skupiny` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var result: Array = []
	for aid in aliance_skupiny:
		result.append((aliance_skupiny[aid] as Dictionary).duplicate(true))
	return result

# Returns current runtime data.
func _ziskej_aliance_kde_je_zakladatel(tag: String) -> Array:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_aliance_kde_je_zakladatel` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej aliance kde je zakladatel` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		if _normalizuj_tag(str(skupina.get("founder", ""))) == clean:
			result.append(skupina.duplicate(true))
	return result

# Fetches data for callers.
func _ziskej_spojence_s_min_alianci(state_tag: String, min_level: int) -> Array:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `min_level`: Input argument used by `_ziskej_spojence_s_min_alianci` during execution.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_spojence_s_min_alianci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej spojence s min alianci` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var out: Array = []
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "":
		return out
	if _ai_phase_cache_active:
		var cache_key = "%s|%d" % [cisty, min_level]
		if _ai_allies_cache.has(cache_key):
			return (_ai_allies_cache[cache_key] as Array).duplicate()

	var active_states: Array = _turn_active_states if _turn_cache_valid else _ziskej_aktivni_staty()
	for other in active_states:
		var tag = _normalizuj_tag(str(other))
		if tag == "" or tag == cisty:
			continue
		if ziskej_uroven_aliance(cisty, tag) >= min_level:
			out.append(tag)

	if _ai_phase_cache_active:
		_ai_allies_cache["%s|%d" % [cisty, min_level]] = out.duplicate()
	return out

# Resets transient runtime/UI data.
func _vycisti_expirovane_neagresivni_smlouvy() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_vycisti_expirovane_neagresivni_smlouvy` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vycisti expirovane neagresivni smlouvy` logic.
	# 3. Persist side effects and finish without a return value.
	var keys = neagresivni_smlouvy.keys().duplicate()
	for k in keys:
		var expiry_turn = int(neagresivni_smlouvy.get(k, -1))
		if expiry_turn < aktualni_kolo:
			neagresivni_smlouvy.erase(k)

# Returns true when conditions are met.
func ma_neagresivni_smlouvu(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `ma_neagresivni_smlouvu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ma neagresivni smlouvu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	_vycisti_expirovane_neagresivni_smlouvy()
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	return neagresivni_smlouvy.has(key)

# Handles this gameplay/UI path.
func zbyva_kol_neagresivni_smlouvy(tag_a: String, tag_b: String) -> int:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `zbyva_kol_neagresivni_smlouvy` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `zbyva kol neagresivni smlouvy` logic.
	# 3. Persist side effects and return the computed `int` result.
	_vycisti_expirovane_neagresivni_smlouvy()
	var key = _klic_pair(tag_a, tag_b)
	if key == "" or not neagresivni_smlouvy.has(key):
		return 0
	var expiry_turn = int(neagresivni_smlouvy[key])
	return max(0, expiry_turn - aktualni_kolo + 1)

# Validates required conditions.
func je_aliancni_zadost_cekajici(odesilatel: String, prijemce: String) -> bool:
	# Inputs:
	# - `odesilatel`: Input argument used by `je_aliancni_zadost_cekajici` during execution.
	# - `prijemce`: Input argument used by `je_aliancni_zadost_cekajici` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `je_aliancni_zadost_cekajici` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `je aliancni zadost cekajici` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var from_clean = _normalizuj_tag(odesilatel)
	var to_clean = _normalizuj_tag(prijemce)
	if from_clean == "" or to_clean == "" or from_clean == to_clean:
		return false

	for req in cekajici_aliancni_zadosti:
		if _normalizuj_tag(str(req.get("from", ""))) != from_clean:
			continue
		if _normalizuj_tag(str(req.get("to", ""))) != to_clean:
			continue
		return true
	return false

# Core flow for this feature.
func odeslat_aliancni_zadost(tag_a: String, tag_b: String, level: int, ignoruj_vztahove_podminky: bool = false) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# - `level`: Input argument used by `odeslat_aliancni_zadost` during execution.
	# - `ignoruj_vztahove_podminky`: Behavior flag that toggles a conditional path.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `odeslat_aliancni_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `odeslat aliancni zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var target_level = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if a == "" or b == "" or a == b:
		return false
	if target_level <= ALLIANCE_NONE:
		return false
	if jsou_ve_valce(a, b):
		return false
	if je_aliancni_zadost_cekajici(a, b):
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "Alliance request already sent. Waiting for response.")
		return false

	if not ignoruj_vztahove_podminky:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if rel < needed_rel:
			if je_lidsky_stat(a):
				_pridej_popup_hraci(a, "Diplomacy", "%s requires relation at least %.1f." % [nazev_urovne_aliance(target_level), needed_rel])
			return false

	cekajici_aliancni_zadosti.append({
		"from": a,
		"to": b,
		"level": target_level,
		"turn": aktualni_kolo
	})
	_zaloguj_globalni_zpravu("Alliance", "%s sent %s alliance request to %s." % [a, nazev_urovne_aliance(target_level), b], "alliance")
	if je_lidsky_stat(a):
		_pridej_popup_hraci(a, "Diplomacy", "Request for %s was sent to %s." % [nazev_urovne_aliance(target_level), b])
	return true

# Ai generated or editted start (priloha_a.txt)
func _vyhodnot_aliancni_zadosti_pred_ai() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_vyhodnot_aliancni_zadosti_pred_ai` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyhodnot aliancni zadosti pred ai` logic.
	# 3. Persist side effects and finish without a return value.
	if cekajici_aliancni_zadosti.is_empty():
		return

	var pending = cekajici_aliancni_zadosti.duplicate(true)
	cekajici_aliancni_zadosti.clear()

	for req in pending:
		var from_tag = _normalizuj_tag(str(req.get("from", "")))
		var to_tag = _normalizuj_tag(str(req.get("to", "")))
		var level = int(req.get("level", ALLIANCE_NONE))
		if from_tag == "" or to_tag == "" or from_tag == to_tag:
			continue
		if level <= ALLIANCE_NONE:
			continue
		if jsou_ve_valce(from_tag, to_tag):
			continue
		if je_lidsky_stat(to_tag):
			# Human recipient decides manually via diplomacy popup queue.
			_pridej_diplomatickou_zadost(from_tag, to_tag, "alliance", level)
			continue

		if _ma_stat_prijmout_alianci(to_tag, from_tag, level):
			nastav_uroven_aliance(from_tag, to_tag, level)
		else:
			_zaloguj_globalni_zpravu("Alliance", "%s declined %s request for %s." % [to_tag, from_tag, nazev_urovne_aliance(level)], "alliance")
			if je_lidsky_stat(from_tag):
				_zaloguj_zpravu_hraci(from_tag, "Alliance", "Country %s rejected your request for %s." % [to_tag, nazev_urovne_aliance(level)], "alliance")
				_pridej_popup_hraci(from_tag, "Diplomacy", "Country %s rejected your request for %s." % [to_tag, nazev_urovne_aliance(level)])

# Ai generated or editted end (priloha_a.txt)
func uzavrit_neagresivni_smlouvu(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `uzavrit_neagresivni_smlouvu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `uzavrit neagresivni smlouvu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b or a == "SEA" or b == "SEA":
		return false
	var forced_vassal_accept = _vazal_musi_prijmout_zadost(a, b)
	if jsou_ve_valce(a, b):
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Non-aggression pact cannot be signed during war.")
		return false

	var rel = ziskej_vztah_statu(a, b)
	if rel < NON_AGGRESSION_MIN_REL and not forced_vassal_accept:
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Non-aggression pact requires relation at least %.1f." % NON_AGGRESSION_MIN_REL)
		return false

	var key = _klic_pair(a, b)
	if key == "":
		return false

	neagresivni_smlouvy[key] = aktualni_kolo + NON_AGGRESSION_DURATION_TURNS - 1
	_zaloguj_globalni_zpravu("Diplomacy", "%s and %s signed a non-aggression pact for %d turns." % [a, b, NON_AGGRESSION_DURATION_TURNS], "diplomacy")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s and %s signed a non-aggression pact for %d turns." % [a, b, NON_AGGRESSION_DURATION_TURNS])
	return true

# ---- Military access ----
# vojensky_pristup["HOST|GUEST"] = true -> HOST has granted GUEST right to move troops through HOST's territory.
# Alliance automatically grants mutual access (checked in ma_vojensky_pristup, not stored).

# Eligibility/guard check.
func ma_vojensky_pristup(guest: String, host: String) -> bool:
	# Inputs:
	# - `guest`: Input argument used by `ma_vojensky_pristup` during execution.
	# - `host`: Input argument used by `ma_vojensky_pristup` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `ma_vojensky_pristup` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ma vojensky pristup` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "" or g == h:
		return false
	# Any alliance level grants automatic mutual military access.
	if ziskej_uroven_aliance(g, h) > ALLIANCE_NONE:
		return true
	# Manual grant: HOST|GUEST
	return vojensky_pristup.has("%s|%s" % [h, g])

func udelit_vojensky_pristup(host: String, guest: String) -> void:
	# Inputs:
	# - `host`: Input argument used by `udelit_vojensky_pristup` during execution.
	# - `guest`: Input argument used by `udelit_vojensky_pristup` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `udelit_vojensky_pristup` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `udelit vojensky pristup` logic.
	# 3. Persist side effects and finish without a return value.
	var h = _normalizuj_tag(host)
	var g = _normalizuj_tag(guest)
	if h == "" or g == "" or h == g:
		return
	vojensky_pristup["%s|%s" % [h, g]] = true

func odvolej_vojensky_pristup(host: String, guest: String) -> void:
	# Inputs:
	# - `host`: Input argument used by `odvolej_vojensky_pristup` during execution.
	# - `guest`: Input argument used by `odvolej_vojensky_pristup` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `odvolej_vojensky_pristup` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `odvolej vojensky pristup` logic.
	# 3. Persist side effects and finish without a return value.
	var h = _normalizuj_tag(host)
	var g = _normalizuj_tag(guest)
	if h == "" or g == "":
		return
	vojensky_pristup.erase("%s|%s" % [h, g])
	_expeluj_jednotky_bez_pristupu(g)

# Data lookup with best-match logic.
func _najdi_nejblizsi_vlastni_provincii_pro_presun(tag: String, from_prov_id: int) -> int:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# - `from_prov_id`: Input argument used by `_najdi_nejblizsi_vlastni_provincii_pro_presun` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_najdi_nejblizsi_vlastni_provincii_pro_presun` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` najdi nejblizsi vlastni provincii pro presun` logic.
	# 3. Persist side effects and return the computed `int` result.
	var source = map_data.get(from_prov_id, {})
	var sx = float(source.get("x", 0.0))
	var sy = float(source.get("y", 0.0))
	var best_id = -1
	var best_dist = INF
	for p_id in map_data:
		if p_id == from_prov_id:
			continue
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if owner_tag != tag:
			continue
		var existing_army = _normalizuj_tag(str(d.get("army_owner", "")))
		if existing_army != "" and existing_army != tag:
			continue
		var dx = float(d.get("x", 0.0)) - sx
		var dy = float(d.get("y", 0.0)) - sy
		var dist = dx * dx + dy * dy
		if dist < best_dist:
			best_dist = dist
			best_id = p_id
	return best_id

# Core flow for this feature.
func _expeluj_jednotky_bez_pristupu(filter_tag: String = "") -> void:
	# Inputs:
	# - `filter_tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_expeluj_jednotky_bez_pristupu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` expeluj jednotky bez pristupu` logic.
	# 3. Persist side effects and finish without a return value.
	if map_data.is_empty():
		return
	var ft = _normalizuj_tag(filter_tag)
	var active_states: Dictionary = {}
	for p_id_any in map_data:
		var owner_now = _normalizuj_tag(str(map_data[p_id_any].get("owner", "")))
		if owner_now == "" or owner_now == "SEA":
			continue
		active_states[owner_now] = true

	var to_expel: Array = []
	for prov_id in map_data:
		var d = map_data[prov_id]
		var army_tag = _normalizuj_tag(str(d.get("army_owner", "")))
		if army_tag == "":
			continue
		var army_state_exists = active_states.has(army_tag)
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if army_tag == owner_tag:
			continue
		if ft != "" and army_tag != ft:
			continue
		var vojaci = int(d.get("soldiers", 0))
		if vojaci <= 0:
			continue
		if (not army_state_exists) or (not muze_vstoupit_na_uzemi(army_tag, owner_tag)):
			to_expel.append({"prov_id": prov_id, "army_tag": army_tag, "soldiers": vojaci, "owner_tag": owner_tag})

	if to_expel.is_empty():
		return

	var notified_tags: Array = []
	for entry in to_expel:
		var prov_id = entry["prov_id"]
		var army_tag = entry["army_tag"]
		var vojaci = entry["soldiers"]

		map_data[prov_id]["army_owner"] = ""
		map_data[prov_id]["soldiers"] = 0

		var target_id = _najdi_nejblizsi_vlastni_provincii_pro_presun(army_tag, prov_id)
		if target_id >= 0:
			map_data[target_id]["army_owner"] = army_tag
			map_data[target_id]["soldiers"] = int(map_data[target_id].get("soldiers", 0)) + vojaci

		if je_lidsky_stat(army_tag) and not notified_tags.has(army_tag):
			notified_tags.append(army_tag)

	for ptag in notified_tags:
		_pridej_popup_hraci(ptag, "Military", "Your units have been expelled from unauthorized territory and have returned home.")

	var ml = _get_map_loader()
	if ml and ml.has_method("aktualizuj_ikony_armad"):
		ml.aktualizuj_ikony_armad()

# Ai generated or editted start (priloha_a.txt)
func _oprav_neplatne_vlastniky_armad() -> bool:
	# Inputs:
	# - none.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_oprav_neplatne_vlastniky_armad` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` oprav neplatne vlastniky armad` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if map_data.is_empty():
		return false
	var active_states: Dictionary = {}
	for p_id_any in map_data:
		var owner_now = _normalizuj_tag(str(map_data[p_id_any].get("owner", "")))
		if owner_now == "" or owner_now == "SEA":
			continue
		active_states[owner_now] = true

	var changed := false
	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		var army_tag = _normalizuj_tag(str(d.get("army_owner", "")))
		var soldiers = int(d.get("soldiers", 0))

		if soldiers <= 0:
			if army_tag != "":
				d["army_owner"] = ""
				changed = true
			continue

		if owner_tag == "SEA":
			if army_tag != "" and not active_states.has(army_tag):
				d["army_owner"] = ""
				changed = true
			continue

		if army_tag == "" or not active_states.has(army_tag):
			d["army_owner"] = owner_tag
			changed = true
			continue

		# Heal corrupted land stacks: foreign army owner on land without legal access.
		# Legit foreign presence (military access/alliance/vassal) is preserved.
		if army_tag != owner_tag and not muze_vstoupit_na_uzemi(army_tag, owner_tag):
			d["army_owner"] = owner_tag
			changed = true

	return changed

# Ai generated or editted end (priloha_a.txt)
func pozadej_vojensky_pristup(guest: String, host: String) -> bool:
	# Inputs:
	# - `guest`: Input argument used by `pozadej_vojensky_pristup` during execution.
	# - `host`: Input argument used by `pozadej_vojensky_pristup` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `pozadej_vojensky_pristup` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `pozadej vojensky pristup` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "" or g == h:
		return false
	if jsou_ve_valce(g, h):
		if je_lidsky_stat(g):
			_pridej_popup_hraci(g, "Diplomacy", "Cannot request military access during war.")
		return false
	if ma_vojensky_pristup(g, h):
		return false
	# If target is AI, grant immediately when relations >= 15, otherwise deny.
	if not je_lidsky_stat(h):
		if _vazal_musi_prijmout_zadost(h, g):
			udelit_vojensky_pristup(h, g)
			_zaloguj_globalni_zpravu("Diplomacy", "%s automatically granted military access to overlord %s." % [h, g], "diplomacy")
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "%s (your vassal) granted you military access automatically." % h)
			return true
		var rel = ziskej_vztah_statu(g, h)
		if rel >= 15.0:
			udelit_vojensky_pristup(h, g)
			_zaloguj_globalni_zpravu("Diplomacy", "%s granted military access to %s." % [h, g], "diplomacy")
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "%s granted you military access to their territory." % h)
			return true
		else:
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "Military access denied by %s (relations too low: %.0f, need 15)." % [h, rel])
			return false
	# Target is human - send a diplomatic request.
	return _pridej_diplomatickou_zadost(g, h, "military_access")

# Boolean check for required state.
func _ma_cekajici_zadost_vojenskeho_pristupu(guest: String, host: String) -> bool:
	# Inputs:
	# - `guest`: Input argument used by `_ma_cekajici_zadost_vojenskeho_pristupu` during execution.
	# - `host`: Input argument used by `_ma_cekajici_zadost_vojenskeho_pristupu` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_cekajici_zadost_vojenskeho_pristupu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma cekajici zadost vojenskeho pristupu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "":
		return false
	if not cekajici_diplomaticke_zadosti.has(h):
		return false
	for req in (cekajici_diplomaticke_zadosti[h] as Array):
		if _normalizuj_tag(str(req.get("from", ""))) == g and str(req.get("type", "")) == "military_access":
			return true
	return false

# Runs the local feature logic.
func _pridej_diplomatickou_zadost(from_tag: String, to_tag: String, req_type: String, alliance_level: int = ALLIANCE_NONE, payload: Dictionary = {}) -> bool:
	# Inputs:
	# - `from_tag`: State tag handled by this function.
	# - `to_tag`: State tag handled by this function.
	# - `req_type`: Category/type selector used to branch logic.
	# - `alliance_level`: Input argument used by `_pridej_diplomatickou_zadost` during execution.
	# - `payload`: Structured data container consumed by this helper.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_pridej_diplomatickou_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` pridej diplomatickou zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	if from_clean == "" or to_clean == "" or from_clean == to_clean:
		return false

	if req_type != "alliance" and req_type != "non_aggression" and req_type != "peace" and req_type != "military_access" and req_type != "trade" and req_type != "loan":
		return false

	if not _je_essential_diplomaticka_zadost(from_clean, to_clean, req_type, alliance_level):
		return false

	# Vassals cannot reject overlord diplomacy; apply immediately.
	if _vazal_musi_prijmout_zadost(to_clean, from_clean):
		var forced_req = {
			"from": from_clean,
			"to": to_clean,
			"type": req_type,
			"level": alliance_level,
			"turn": aktualni_kolo
		}
		if not payload.is_empty():
			forced_req["payload"] = payload.duplicate(true)
		var forced_ok = _vykonej_prijeti_diplomaticke_zadosti(to_clean, forced_req, true)
		if forced_ok:
			_zaloguj_globalni_zpravu("Diplomacy", "%s automatically accepted %s from overlord %s." % [to_clean, req_type, from_clean], "diplomacy")
		return forced_ok

	if not cekajici_diplomaticke_zadosti.has(to_clean):
		cekajici_diplomaticke_zadosti[to_clean] = []

	var queue = cekajici_diplomaticke_zadosti[to_clean] as Array
	var new_req = {
		"from": from_clean,
		"to": to_clean,
		"type": req_type,
		"level": alliance_level,
		"turn": aktualni_kolo
	}
	if not payload.is_empty():
		new_req["payload"] = payload.duplicate(true)

	# Keep max one visible request per sender to avoid spam; replace only when the
	# new request is more important than the currently queued one.
	for i in range(queue.size()):
		var existing = queue[i] as Dictionary
		if _normalizuj_tag(str(existing.get("from", ""))) != from_clean:
			continue
		if _diplomaticka_zadost_priorita(new_req) < _diplomaticka_zadost_priorita(existing):
			queue[i] = new_req
			_zaloguj_globalni_zpravu("Diplomacy", "%s updated diplomatic request for %s (%s)." % [from_clean, to_clean, req_type], "diplomacy")
			return true
		return false

	queue.append(new_req)
	if req_type == "alliance":
		_zaloguj_globalni_zpravu("Alliance", "%s sent %s alliance proposal (%s)." % [from_clean, to_clean, nazev_urovne_aliance(alliance_level)], "alliance")
	elif req_type == "peace":
		_zaloguj_globalni_zpravu("Diplomacy", "%s sent peace proposal to %s." % [from_clean, to_clean], "diplomacy")
	elif req_type == "non_aggression":
		_zaloguj_globalni_zpravu("Diplomacy", "%s proposed non-aggression pact to %s." % [from_clean, to_clean], "diplomacy")
	elif req_type == "military_access":
		_zaloguj_globalni_zpravu("Diplomacy", "%s requested military access from %s." % [from_clean, to_clean], "diplomacy")
	elif req_type == "trade":
		_zaloguj_globalni_zpravu("Trade", "%s sent trade offer to %s." % [from_clean, to_clean], "trade")
	elif req_type == "loan":
		_zaloguj_globalni_zpravu("Loans", "%s sent loan proposal to %s." % [from_clean, to_clean], "trade")
	return true

# Validates required conditions.
func _je_essential_diplomaticka_zadost(from_tag: String, to_tag: String, req_type: String, alliance_level: int) -> bool:
	# Inputs:
	# - `from_tag`: State tag handled by this function.
	# - `to_tag`: State tag handled by this function.
	# - `req_type`: Category/type selector used to branch logic.
	# - `alliance_level`: Input argument used by `_je_essential_diplomaticka_zadost` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_essential_diplomaticka_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je essential diplomaticka zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	if from_clean == "" or to_clean == "":
		return false

	# Human initiated diplomacy is always actionable and should never be filtered out.
	if je_lidsky_stat(from_clean):
		return true

	# AI-generated requests are filtered to only critical/important offers.
	match req_type:
		"peace":
			return true
		"alliance":
			# Defensive alliance offers are still strategically important.
			return alliance_level >= ALLIANCE_DEFENSE
		"non_aggression":
			# Show only meaningful NAPs from AI to avoid low-value spam.
			var rel = ziskej_vztah_statu(from_clean, to_clean)
			return rel >= maxf(35.0, NON_AGGRESSION_MIN_REL)
		"military_access":
			return true
		"trade":
			return true
		"loan":
			return true
		_:
			return false

func _diplomaticka_zadost_priorita(req: Dictionary) -> int:
	# Inputs:
	# - `req`: Structured data container consumed by this helper.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_diplomaticka_zadost_priorita` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` diplomaticka zadost priorita` logic.
	# 3. Persist side effects and return the computed `int` result.
	var from_tag = _normalizuj_tag(str(req.get("from", "")))
	if je_lidsky_stat(from_tag):
		return DIP_REQUEST_PRIORITY_PLAYER

	match str(req.get("type", "")):
		"peace":
			return DIP_REQUEST_PRIORITY_PEACE
		"alliance":
			return DIP_REQUEST_PRIORITY_ALLIANCE
		"non_aggression":
			return DIP_REQUEST_PRIORITY_NON_AGGRESSION
		"military_access":
			return DIP_REQUEST_PRIORITY_MILITARY_ACCESS
		"trade":
			return DIP_REQUEST_PRIORITY_TRADE
		"loan":
			return DIP_REQUEST_PRIORITY_LOAN
		_:
			return 100

# Reads values from active state.
func _ziskej_index_nejvyssi_priority_zadosti(queue: Array) -> int:
	# Inputs:
	# - `queue`: Structured data container consumed by this helper.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ziskej_index_nejvyssi_priority_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej index nejvyssi priority zadosti` logic.
	# 3. Persist side effects and return the computed `int` result.
	if queue.is_empty():
		return -1

	var best_idx := 0
	var best_priority := _diplomaticka_zadost_priorita(queue[0] as Dictionary)
	var best_turn := int((queue[0] as Dictionary).get("turn", 0))

	for i in range(1, queue.size()):
		var req = queue[i] as Dictionary
		var p = _diplomaticka_zadost_priorita(req)
		var t = int(req.get("turn", 0))
		if p < best_priority or (p == best_priority and t < best_turn):
			best_idx = i
			best_priority = p
			best_turn = t

	return best_idx

func _odeber_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> Dictionary:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# - `from_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_odeber_diplomatickou_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` odeber diplomatickou zadost` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if player_clean == "" or from_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	for i in range(queue.size() - 1, -1, -1):
		var req = queue[i]
		if _normalizuj_tag(str(req.get("from", ""))) != from_clean:
			continue
		queue.remove_at(i)
		return req
	return {}

# Reads values from active state.
func ziskej_cekajici_zadost_od_statu(hrac_tag: String, from_tag: String) -> Dictionary:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# - `from_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_cekajici_zadost_od_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej cekajici zadost od statu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if player_clean == "" or from_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	for req in (cekajici_diplomaticke_zadosti[player_clean] as Array):
		if _normalizuj_tag(str(req.get("from", ""))) == from_clean:
			return req.duplicate(true)
	return {}

# Read-only data accessor.
func ziskej_prvni_cekajici_diplomatickou_zadost(hrac_tag: String) -> Dictionary:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_prvni_cekajici_diplomatickou_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej prvni cekajici diplomatickou zadost` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	if queue.is_empty():
		return {}

	var idx = _ziskej_index_nejvyssi_priority_zadosti(queue)
	if idx < 0:
		return {}
	return (queue[idx] as Dictionary).duplicate(true)

# Fetches data for callers.
func ziskej_pocet_cekajicich_diplomatickych_zadosti(hrac_tag: String) -> int:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `ziskej_pocet_cekajicich_diplomatickych_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej pocet cekajicich diplomatickych zadosti` logic.
	# 3. Persist side effects and return the computed `int` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0
	return (cekajici_diplomaticke_zadosti[player_clean] as Array).size()

# Fetches data for callers.
func ziskej_cekajici_diplomaticke_zadosti(hrac_tag: String) -> Array:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_cekajici_diplomaticke_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej cekajici diplomaticke zadosti` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return []
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return []

	var queue = (cekajici_diplomaticke_zadosti[player_clean] as Array).duplicate(true)
	queue.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		var pa = _diplomaticka_zadost_priorita(da)
		var pb = _diplomaticka_zadost_priorita(db)
		if pa != pb:
			return pa < pb
		return int(da.get("turn", 0)) < int(db.get("turn", 0))
	)
	return queue

func _vazal_musi_prijmout_zadost(receiver_tag: String, sender_tag: String) -> bool:
	# Inputs:
	# - `receiver_tag`: State tag handled by this function.
	# - `sender_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_vazal_musi_prijmout_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vazal musi prijmout zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var receiver = _normalizuj_tag(receiver_tag)
	var sender = _normalizuj_tag(sender_tag)
	if receiver == "" or sender == "" or receiver == sender:
		return false
	return ziskej_overlorda_statu(receiver) == sender

func _vykonej_prijeti_diplomaticke_zadosti(player_clean: String, req: Dictionary, forced_vassal_accept: bool = false) -> bool:
	# Inputs:
	# - `player_clean`: Input argument used by `_vykonej_prijeti_diplomaticke_zadosti` during execution.
	# - `req`: Structured data container consumed by this helper.
	# - `forced_vassal_accept`: Input argument used by `_vykonej_prijeti_diplomaticke_zadosti` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_vykonej_prijeti_diplomaticke_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vykonej prijeti diplomaticke zadosti` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatic offer"
	if req_type == "alliance":
		req_name = "alliance offer"
	elif req_type == "peace":
		req_name = "peace offer"
	elif req_type == "non_aggression":
		req_name = "non-aggression pact offer"
	elif req_type == "military_access":
		req_name = "military access request"
	elif req_type == "trade":
		req_name = "trade offer"
	elif req_type == "loan":
		req_name = "loan proposal"

	if req_type == "alliance":
		var level = int(req.get("level", ALLIANCE_NONE))
		var obe_strany_lide = je_lidsky_stat(player_clean) and je_lidsky_stat(sender)
		var alliance_ok = false
		if obe_strany_lide:
			# Human-vs-human diplomacy is decided purely by acceptance/rejection.
			alliance_ok = nastav_uroven_aliance(player_clean, sender, level, true)
		else:
			alliance_ok = nastav_uroven_aliance(player_clean, sender, level)
		if alliance_ok:
			# Try to place both into an alliance group
			var placed = false
			var sender_groups = ziskej_aliance_statu(sender)
			for grp in sender_groups:
				if int(grp.get("level", 0)) == level:
					var members = grp.get("members", []) as Array
					if not members.has(player_clean):
						var ignoruj = obe_strany_lide
						var res = pridej_clena_do_aliance(str(grp.get("id", "")), player_clean, ignoruj)
						if res.get("ok", false):
							placed = true
							break
			if not placed:
				var group_name = "%s-%s Pact" % [sender, player_clean]
				vytvor_alianci_skupinu(group_name, level, sender, [player_clean])
			_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return alliance_ok
	if req_type == "non_aggression":
		var nap_ok = uzavrit_neagresivni_smlouvu(player_clean, sender)
		if nap_ok:
			_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return nap_ok
	if req_type == "peace":
		if not jsou_ve_valce(player_clean, sender):
			return false
		uzavri_mir_a_zahaj_konferenci(player_clean, sender, "peace_offer")
		if je_lidsky_stat(player_clean) or je_lidsky_stat(sender):
			_pridej_popup_zucastnenym_hracum(player_clean, sender, "Diplomacy", "Peace offer accepted: %s and %s made peace." % [player_clean, sender])
		_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return true
	if req_type == "military_access":
		udelit_vojensky_pristup(player_clean, sender)
		_zaloguj_globalni_zpravu("Diplomacy", "%s granted military access to %s." % [player_clean, sender], "diplomacy")
		if je_lidsky_stat(sender):
			_pridej_popup_hraci(sender, "Diplomacy", "%s granted you military access to their territory." % player_clean)
		return true
	if req_type == "trade":
		var payload = req.get("payload", {}) as Dictionary
		var trade_ok = _proved_trade_dohodu(sender, player_clean, payload)
		if bool(trade_ok.get("ok", false)):
			_zaloguj_globalni_zpravu("Trade", "%s accepted trade offer from %s." % [player_clean, sender], "trade")
			if je_lidsky_stat(sender):
				_pridej_popup_hraci(sender, "Trade", "%s accepted your trade offer." % player_clean, false, [sender, player_clean])
		return bool(trade_ok.get("ok", false))
	if req_type == "loan":
		var payload = req.get("payload", {}) as Dictionary
		var lender = _normalizuj_tag(str(payload.get("lender", "")))
		var borrower = _normalizuj_tag(str(payload.get("borrower", "")))
		var principal = float(payload.get("principal", 0.0))
		var interest_pct = float(payload.get("interest_pct", 0.0))
		var turns = int(payload.get("turns", 0))
		var loan_ok = _vytvor_statni_pujcku(lender, borrower, principal, interest_pct, turns)
		if bool(loan_ok.get("ok", false)):
			_zaloguj_globalni_zpravu("Loans", "%s accepted loan proposal from %s." % [player_clean, sender], "trade")
			if je_lidsky_stat(sender):
				_pridej_popup_hraci(sender, "Loans", "%s accepted your loan proposal." % player_clean, true)
			if je_lidsky_stat(player_clean):
				_pridej_popup_hraci(player_clean, "Loans", "You accepted loan proposal from %s." % sender, true)
			return true
		if je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Loans", str(loan_ok.get("reason", "Loan proposal failed.")), true)
		if je_lidsky_stat(sender):
			_pridej_popup_hraci(sender, "Loans", "%s could not finalize the loan proposal." % player_clean, true)
		return false

	# Keep generic fallback for future diplomatic request types.
	_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
	if forced_vassal_accept and je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, you automatically accepted a diplomatic request from your overlord (%s)." % sender)
	return false

func hrac_prijmi_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# - `from_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `hrac_prijmi_diplomatickou_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac prijmi diplomatickou zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false
	return _vykonej_prijeti_diplomaticke_zadosti(player_clean, req)

# Ai generated or editted start (priloha_a.txt)
func hrac_odmitni_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# - `from_tag`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `hrac_odmitni_diplomatickou_zadost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac odmitni diplomatickou zadost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if _vazal_musi_prijmout_zadost(player_clean, from_clean):
		return hrac_prijmi_diplomatickou_zadost(player_clean, from_clean)

	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false

	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatic offer"
	if req_type == "alliance":
		req_name = "alliance offer"
	elif req_type == "peace":
		req_name = "peace offer"
	elif req_type == "non_aggression":
		req_name = "non-aggression pact offer"
	elif req_type == "military_access":
		req_name = "military access request"
	elif req_type == "trade":
		req_name = "trade offer"
	elif req_type == "loan":
		req_name = "loan proposal"
	if je_lidsky_stat(player_clean):
		_zaloguj_zpravu_hraci(player_clean, "Diplomacy", "You declined %s from %s." % [req_name, sender], "diplomacy")
		_pridej_popup_hraci(player_clean, "Diplomacy", "You declined a diplomatic request from %s." % sender)
	if je_lidsky_stat(sender):
		_zaloguj_zpravu_hraci(sender, "Diplomacy", "%s declined your %s." % [player_clean, req_name], "diplomacy")
	if req_type == "loan" and je_lidsky_stat(sender):
		_pridej_popup_hraci(sender, "Loans", "%s rejected your loan proposal." % player_clean, true)
	_zaloguj_globalni_zpravu("Diplomacy", "%s declined %s from %s." % [player_clean, req_name, sender], "diplomacy")
	return true

# Ai generated or editted end (priloha_a.txt)
func hrac_odmitni_vsechny_diplomaticke_zadosti(hrac_tag: String) -> int:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `hrac_odmitni_vsechny_diplomaticke_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac odmitni vsechny diplomaticke zadosti` logic.
	# 3. Persist side effects and return the computed `int` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	var queue_copy = queue.duplicate(true)
	var count = queue_copy.size()
	if count <= 0:
		return 0

	var auto_accepted := 0
	for req_any in queue_copy:
		var req = req_any as Dictionary
		var sender = _normalizuj_tag(str(req.get("from", "")))
		if _vazal_musi_prijmout_zadost(player_clean, sender):
			if hrac_prijmi_diplomatickou_zadost(player_clean, sender):
				auto_accepted += 1

	# Re-fetch queue after automatic acceptances and decline only the rest.
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		if auto_accepted > 0 and je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, %d offer(s) from your overlord were accepted automatically." % auto_accepted)
		return 0
	queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	count = queue.size()
	if count <= 0:
		if auto_accepted > 0 and je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, %d offer(s) from your overlord were accepted automatically." % auto_accepted)
		return 0

	var remaining_copy = queue.duplicate(true)
	var declined_count := 0
	for req_any in remaining_copy:
		var req_dict = req_any as Dictionary
		var sender = _normalizuj_tag(str(req_dict.get("from", "")))
		if sender == "":
			continue
		if hrac_odmitni_diplomatickou_zadost(player_clean, sender):
			declined_count += 1

	count = declined_count
	if count <= 0:
		if auto_accepted > 0 and je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, %d offer(s) from your overlord were accepted automatically." % auto_accepted)
		return 0

	if je_lidsky_stat(player_clean):
		if auto_accepted > 0:
			_zaloguj_zpravu_hraci(player_clean, "Diplomacy", "You declined %d request(s); %d overlord request(s) were accepted automatically." % [count, auto_accepted], "diplomacy")
			_pridej_popup_hraci(player_clean, "Diplomacy", "You declined %d request(s); %d overlord request(s) were accepted automatically." % [count, auto_accepted])
		else:
			_zaloguj_zpravu_hraci(player_clean, "Diplomacy", "You declined all pending diplomatic requests (%d)." % count, "diplomacy")
			_pridej_popup_hraci(player_clean, "Diplomacy", "You declined all pending diplomatic requests (%d)." % count)
	return count

# Core flow for this feature.
func hrac_prijmi_vsechny_diplomaticke_zadosti(hrac_tag: String) -> int:
	# Inputs:
	# - `hrac_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `hrac_prijmi_vsechny_diplomaticke_zadosti` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac prijmi vsechny diplomaticke zadosti` logic.
	# 3. Persist side effects and return the computed `int` result.
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0

	var queue_copy = (cekajici_diplomaticke_zadosti[player_clean] as Array).duplicate(true)
	if queue_copy.is_empty():
		return 0

	var accepted := 0
	for req in queue_copy:
		var from_tag = _normalizuj_tag(str((req as Dictionary).get("from", "")))
		if from_tag == "":
			continue
		if hrac_prijmi_diplomatickou_zadost(player_clean, from_tag):
			accepted += 1

	if accepted > 0 and je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacy", "You accepted pending diplomatic requests (%d)." % accepted)
	return accepted

# Ai generated or editted start (priloha_a.txt)
