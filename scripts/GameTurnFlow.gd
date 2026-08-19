extends "res://scripts/GameWarPeace.gd"

## Turn orchestration, runtime caches, world setup, recruitment, and shared AI support.

func _spocitej_silu_statu(tag: String) -> int:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_spocitej_silu_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej silu statu` logic.
	# 3. Persist side effects and return the computed `int` result.
	var hledany = tag.strip_edges().to_upper()
	if hledany == "":
		return 0
	if _turn_cache_valid and _turn_state_soldier_power.has(hledany):
		return int(_turn_state_soldier_power[hledany])
	var base_sila := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hledany:
			base_sila += int(d.get("soldiers", 0))
	var army_power = ziskej_silu_armady_statu(hledany, base_sila)
	if bool(army_power.get("ok", false)):
		return int(army_power.get("total", base_sila))
	return base_sila

# Validates required conditions.
func _ma_ai_prijmout_mir(prijemce: String, odesilatel: String) -> bool:
	# Inputs:
	# - `prijemce`: Input argument used by `_ma_ai_prijmout_mir` during execution.
	# - `odesilatel`: Input argument used by `_ma_ai_prijmout_mir` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_ai_prijmout_mir` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma ai prijmout mir` logic.
	# 3. Persist side effects and return the computed `bool` result.
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
	var exhaustion = _ai_spocitej_war_exhaustion(prij)
	chance += exhaustion * 0.30
	if pomer < 0.92:
		chance += exhaustion * 0.18

	# Strategic-goal aware peace behavior.
	var goal = _ai_ziskej_strategicky_cil(prij)
	var goal_target = _normalizuj_tag(str(goal.get("target", "")))
	if goal_target == ode:
		var goal_type = str(goal.get("type", "none"))
		var stagnation = int(goal.get("stagnation", 0))
		var sig = _ai_goal_signature(prij, ode)
		var enemy_holds_our_cores = int(sig.get("owner_cores_held_by_target", 0))
		var we_hold_enemy_cores = int(sig.get("target_cores_held_by_owner", 0))

		if goal_type == "reclaim_core" and enemy_holds_our_cores > 0:
			chance -= 0.30
		elif goal_type == "break_rival" and pomer >= 1.08:
			chance -= 0.18
		elif goal_type == "expand_border" and we_hold_enemy_cores > 0 and pomer >= 0.95:
			chance -= 0.14

		# If the strategic plan is stalled, AI becomes more willing to cut losses.
		if stagnation >= AI_GOAL_STAGNATION_RETARGET:
			chance += 0.24
		elif stagnation >= 1:
			chance += 0.10
		# Even goal-focused AI should de-escalate when heavily exhausted.
		if exhaustion >= 0.76:
			chance += 0.18

	chance = clamp(chance, 0.05, 0.95)
	return randf() < chance

# Returns current runtime data.
func _ziskej_ai_staty() -> Array:
	# Inputs:
	# - none.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_ai_staty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej ai staty` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var ai_staty: Dictionary = {}
	for state_tag in _ziskej_aktivni_staty():
		var tag = str(state_tag)
		if tag == "" or je_lidsky_stat(tag):
			continue
		ai_staty[tag] = true
	return ai_staty.keys()

# Core flow for this feature.
func _klic_pair(tag_a: String, tag_b: String) -> String:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_klic_pair` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` klic pair` logic.
	# 3. Persist side effects and return the computed `String` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return ""
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

# Ai generated or editted start (priloha_a.txt)
func _klic_valky(tag_a: String, tag_b: String) -> String:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_klic_valky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` klic valky` logic.
	# 3. Persist side effects and return the computed `String` result.
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return ""
	if a < b:
		return "%s_%s" % [a, b]
	return "%s_%s" % [b, a]

# Ai generated or editted end (priloha_a.txt)
func _normalizuj_valecne_klice() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_normalizuj_valecne_klice` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` normalizuj valecne klice` logic.
	# 3. Persist side effects and finish without a return value.
	if valky.is_empty():
		return
	var normalized: Dictionary = {}
	for key_any in valky.keys():
		var raw = str(key_any).strip_edges().to_upper()
		if raw == "":
			continue
		var parts: Array = []
		if raw.contains("|"):
			parts = raw.split("|")
		else:
			parts = raw.split("_")
		if parts.size() != 2:
			continue
		var war_key = _klic_valky(str(parts[0]), str(parts[1]))
		if war_key == "":
			continue
		normalized[war_key] = true
	valky = normalized
	_ai_war_cache.clear()

# Runs the local feature logic.
func _begin_ai_cache_batch() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_begin_ai_cache_batch` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` begin ai cache batch` logic.
	# 3. Persist side effects and finish without a return value.
	_ai_cache_batch_depth += 1

# Handles this gameplay/UI path.
func _end_ai_cache_batch() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_end_ai_cache_batch` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` end ai cache batch` logic.
	# 3. Persist side effects and finish without a return value.
	if _ai_cache_batch_depth <= 0:
		_ai_cache_batch_depth = 0
		_flush_ai_war_pair_eval_dirty_states()
		return
	_ai_cache_batch_depth -= 1
	if _ai_cache_batch_depth == 0:
		_flush_ai_war_pair_eval_dirty_states()

# Runs the local feature logic.
func _mark_ai_war_pair_eval_dirty_state(tag: String) -> void:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_mark_ai_war_pair_eval_dirty_state` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` mark ai war pair eval dirty state` logic.
	# 3. Persist side effects and finish without a return value.
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return
	_ai_war_pair_eval_dirty_states[clean] = true

func _mark_ai_war_pair_eval_dirty_pair(tag_a: String, tag_b: String) -> void:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_mark_ai_war_pair_eval_dirty_pair` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` mark ai war pair eval dirty pair` logic.
	# 3. Persist side effects and finish without a return value.
	_mark_ai_war_pair_eval_dirty_state(tag_a)
	_mark_ai_war_pair_eval_dirty_state(tag_b)
	if _ai_cache_batch_depth == 0:
		_flush_ai_war_pair_eval_dirty_states()

# Handles this gameplay/UI path.
func _flush_ai_war_pair_eval_dirty_states() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_flush_ai_war_pair_eval_dirty_states` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` flush ai war pair eval dirty states` logic.
	# 3. Persist side effects and finish without a return value.
	if _ai_war_pair_eval_dirty_states.is_empty():
		return
	# Full clear is faster than per-key parsing/erase in war-declare bursts.
	# This cache is performance-only and safe to rebuild lazily.
	_ai_war_pair_eval_cache.clear()
	_ai_war_pair_eval_dirty_states.clear()

func _invalidate_turn_cache() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_invalidate_turn_cache` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` invalidate turn cache` logic.
	# 3. Persist side effects and finish without a return value.
	_turn_cache_valid = false
	_invalidate_tag_alias_cache()
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()
	_turn_state_owned_provinces.clear()
	_turn_owner_by_province.clear()
	_turn_soldiers_by_province.clear()
	_turn_neighbors_by_province.clear()

# Runs the local feature logic.
func _rebuild_turn_cache() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_rebuild_turn_cache` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` rebuild turn cache` logic.
	# 3. Persist side effects and finish without a return value.
	_invalidate_turn_cache()

	for p_id in map_data:
		var d0 = map_data[p_id]
		var pid0 = int(p_id)
		var n_arr: Array = []
		for n_raw in d0.get("neighbors", []):
			n_arr.append(int(n_raw))
		_turn_neighbors_by_province[pid0] = n_arr
		_turn_owner_by_province[pid0] = _normalizuj_tag(str(d0.get("owner", "")))
		_turn_soldiers_by_province[pid0] = int(d0.get("soldiers", 0))

	var active: Dictionary = {}
	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if owner_tag == "" or owner_tag == "SEA":
			continue

		active[owner_tag] = true
		_turn_state_soldier_power[owner_tag] = int(_turn_state_soldier_power.get(owner_tag, 0)) + int(d.get("soldiers", 0))
		_turn_state_hdp[owner_tag] = float(_turn_state_hdp.get(owner_tag, 0.0)) + float(d.get("gdp", 0.0))
		if not _turn_state_owned_provinces.has(owner_tag):
			_turn_state_owned_provinces[owner_tag] = []
		(_turn_state_owned_provinces[owner_tag] as Array).append(int(p_id))

		for n_id in (_turn_neighbors_by_province.get(int(p_id), []) as Array):
			if not _turn_owner_by_province.has(int(n_id)):
				continue
			var n_owner = str(_turn_owner_by_province[int(n_id)])
			if n_owner == "" or n_owner == "SEA" or n_owner == owner_tag:
				continue
			var pair_key = _klic_pair(owner_tag, n_owner)
			if pair_key != "":
				_turn_border_pairs[pair_key] = true

	_turn_active_states = active.keys()
	_turn_cache_valid = true

# Refreshes existing content to reflect current runtime values.
func _refresh_turn_runtime_owner_soldier_cache() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_refresh_turn_runtime_owner_soldier_cache` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` refresh turn runtime owner soldier cache` logic.
	# 3. Persist side effects and finish without a return value.
	if not _turn_cache_valid:
		return
	for p_id in map_data:
		var pid = int(p_id)
		var d = map_data[p_id]
		_turn_owner_by_province[pid] = _normalizuj_tag(str(d.get("owner", "")))
		_turn_soldiers_by_province[pid] = int(d.get("soldiers", 0))

# Fetches data for callers.
func _ziskej_aktivni_staty() -> Array:
	# Inputs:
	# - none.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ziskej_aktivni_staty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej aktivni staty` logic.
	# 3. Persist side effects and return the computed `Array` result.
	if _turn_cache_valid:
		return _turn_active_states.duplicate()

	var ai_staty: Dictionary = {}
	for p_id in map_data:
		var owner_tag = _normalizuj_tag(str(map_data[p_id].get("owner", "")))
		if owner_tag == "" or owner_tag == "SEA":
			continue
		ai_staty[owner_tag] = true
	return ai_staty.keys()

# Boolean check for required state.
func _ma_spolecnou_hranici(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_spolecnou_hranici` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma spolecnou hranici` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	if _turn_cache_valid:
		var cache_key = _klic_pair(tag_a, tag_b)
		return cache_key != "" and _turn_border_pairs.has(cache_key)

	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != tag_a:
			continue
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = _normalizuj_tag(str(map_data[n_id].get("owner", "")))
			if n_owner == tag_b:
				return true
	return false

# Runs the local feature logic.
func _zpracuj_ai_diplomacii(ai_staty: Array) -> Array:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_zpracuj_ai_diplomacii` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj ai diplomacii` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var aktivni_staty = _ziskej_aktivni_staty()
	var aktivni_staty_norm: Array = []
	for s in aktivni_staty:
		var t = _normalizuj_tag(str(s))
		if t != "":
			aktivni_staty_norm.append(t)

	var state_power: Dictionary = {}
	for state_tag in aktivni_staty_norm:
		state_power[state_tag] = float(max(1, _spocitej_silu_statu(state_tag)))

	var zmeny_vztahu_k_hraci: Array = []
	for ai_tag in ai_staty:
		var owner_tag = _normalizuj_tag(str(ai_tag))
		if owner_tag == "":
			continue

		var our_power = float(state_power.get(owner_tag, 1.0))
		var best_improve_target := ""
		var best_improve_score := -INF
		var best_worsen_target := ""
		var best_worsen_score := -INF

		for other_tag in aktivni_staty_norm:
			if other_tag == owner_tag:
				continue
			if _jsou_ve_valce_ai_cached(owner_tag, other_tag):
				continue
			if not _muze_upravit_vztah_ai_cached(owner_tag, other_tag):
				continue

			var rel = ziskej_vztah_statu(owner_tag, other_tag)
			var their_power = float(state_power.get(other_tag, 1.0))
			var ratio = our_power / their_power
			var border = _ma_spolecnou_hranici_ai_cached(owner_tag, other_tag)

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

# Handles this gameplay/UI path.
func _zpracuj_ai_aliance(ai_staty: Array) -> Array:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_zpracuj_ai_aliance` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj ai aliance` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var zmeny_alianci: Array = []
	var aktivni_staty = _ziskej_aktivni_staty()
	var aktivni_staty_norm: Array = []
	for s in aktivni_staty:
		var t = _normalizuj_tag(str(s))
		if t != "":
			aktivni_staty_norm.append(t)
	var state_power: Dictionary = {}
	var hostility_by_state: Dictionary = {}

	for state_tag in aktivni_staty_norm:
		state_power[state_tag] = float(max(1, _spocitej_silu_statu(state_tag)))
		var hostile_set: Dictionary = {}
		for enemy_tag in aktivni_staty_norm:
			if enemy_tag == state_tag:
				continue
			if ziskej_vztah_statu(state_tag, enemy_tag) <= -35.0:
				hostile_set[enemy_tag] = true
		hostility_by_state[state_tag] = hostile_set

	for ai_tag in ai_staty:
		var owner_tag = _normalizuj_tag(str(ai_tag))
		if owner_tag == "":
			continue
		var owner_mindset = _ai_ziskej_mindset(owner_tag)
		var owner_attack_bias = float(owner_mindset.get("attack_bias", 0.5))
		# Highly aggressive states should not keep creating new alliance nets.
		if owner_attack_bias >= 0.62:
			continue
		var our_power = float(state_power.get(owner_tag, 1.0))
		var owner_enemies = hostility_by_state.get(owner_tag, {}) as Dictionary

		for other_tag in aktivni_staty_norm:
			if other_tag == owner_tag:
				continue
			if _jsou_ve_valce_ai_cached(owner_tag, other_tag):
				continue

			var current_level = _ziskej_uroven_aliance_ai_cached(owner_tag, other_tag)
			var rel = ziskej_vztah_statu(owner_tag, other_tag)
			var border = _ma_spolecnou_hranici_ai_cached(owner_tag, other_tag)
			var their_power = float(state_power.get(other_tag, 1.0))
			var ratio = our_power / their_power

			var common_enemy := false
			var other_enemies = hostility_by_state.get(other_tag, {}) as Dictionary
			if not owner_enemies.is_empty() and not other_enemies.is_empty():
				var iterate_keys = owner_enemies.keys()
				var probe = other_enemies
				if other_enemies.size() < owner_enemies.size():
					iterate_keys = other_enemies.keys()
					probe = owner_enemies
				for enemy_tag in iterate_keys:
					if probe.has(enemy_tag):
						common_enemy = true
						break

			var desired_level = current_level
			if rel >= ALLIANCE_MIN_REL_FULL and (common_enemy or border):
				desired_level = max(desired_level, ALLIANCE_FULL)
			elif rel >= ALLIANCE_MIN_REL_OFFENSE and common_enemy:
				desired_level = max(desired_level, ALLIANCE_OFFENSE)
			elif rel >= ALLIANCE_MIN_REL_DEFENSE and (border or ratio < 0.95):
				desired_level = max(desired_level, ALLIANCE_DEFENSE)

			if desired_level != current_level:
				if je_lidsky_stat(other_tag):
					if _pridej_diplomatickou_zadost(owner_tag, other_tag, "alliance", desired_level):
						zmeny_alianci.append({
							"a": owner_tag,
							"b": other_tag,
							"new_level": desired_level,
							"request": true
						})
				else:
					# AI-to-AI: use alliance groups instead of raw bilateral
					var handled = false
					if desired_level > current_level:
						# Try to find an existing group where owner is a member at desired level
						var owner_groups = ziskej_aliance_statu(owner_tag)
						for grp in owner_groups:
							if int(grp.get("level", 0)) == desired_level:
								var members = grp.get("members", []) as Array
								if not members.has(other_tag):
									var res = pridej_clena_do_aliance(str(grp.get("id", "")), other_tag, false)
									if res.get("ok", false):
										handled = true
										if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
											zmeny_alianci.append({
												"a": owner_tag,
												"b": other_tag,
												"new_level": desired_level
											})
										break
						if not handled:
							# Also check if other_tag has a suitable group to join
							var other_groups = ziskej_aliance_statu(other_tag)
							for grp in other_groups:
								if int(grp.get("level", 0)) == desired_level:
									var members = grp.get("members", []) as Array
									if not members.has(owner_tag):
										var res = pridej_clena_do_aliance(str(grp.get("id", "")), owner_tag, false)
										if res.get("ok", false):
											handled = true
											if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
												zmeny_alianci.append({
													"a": owner_tag,
													"b": other_tag,
													"new_level": desired_level
												})
											break
						if not handled:
							# Create a new alliance group
							var group_name = "%s-%s Pact" % [owner_tag, other_tag]
							var res = vytvor_alianci_skupinu(group_name, desired_level, owner_tag, [other_tag])
							if res.get("ok", false):
								handled = true
								if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
									zmeny_alianci.append({
										"a": owner_tag,
										"b": other_tag,
										"new_level": desired_level
									})
					if not handled:
						# Fallback: use bilateral directly
						if nastav_uroven_aliance(owner_tag, other_tag, desired_level):
							if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
								zmeny_alianci.append({
									"a": owner_tag,
									"b": other_tag,
									"new_level": desired_level
								})

	return zmeny_alianci

# Handles this gameplay/UI path.
func _zpracuj_ai_neagresivni_smlouvy(ai_staty: Array) -> Array:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_zpracuj_ai_neagresivni_smlouvy` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj ai neagresivni smlouvy` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var zmeny: Array = []
	var aktivni_staty = _ziskej_aktivni_staty()
	var aktivni_staty_norm: Array = []
	for s in aktivni_staty:
		var t = _normalizuj_tag(str(s))
		if t != "":
			aktivni_staty_norm.append(t)
	_vycisti_expirovane_neagresivni_smlouvy()

	for ai_tag in ai_staty:
		var owner_tag = _normalizuj_tag(str(ai_tag))
		if owner_tag == "":
			continue
		var owner_mindset = _ai_ziskej_mindset(owner_tag)
		var owner_attack_bias = float(owner_mindset.get("attack_bias", 0.5))
		# Aggressive states prefer open conflict options over non-aggression pacts.
		if owner_attack_bias >= 0.52:
			continue

		var best_target := ""
		var best_rel := -INF
		for other_tag in aktivni_staty_norm:
			if other_tag == owner_tag:
				continue
			if _jsou_ve_valce_ai_cached(owner_tag, other_tag):
				continue
			if _ma_neagresivni_smlouvu_ai_cached(owner_tag, other_tag):
				continue
			if _ziskej_uroven_aliance_ai_cached(owner_tag, other_tag) > ALLIANCE_NONE:
				continue

			var rel = ziskej_vztah_statu(owner_tag, other_tag)
			if rel < NON_AGGRESSION_MIN_REL:
				continue

			if rel > best_rel:
				best_rel = rel
				best_target = other_tag

		if best_target != "":
			if je_lidsky_stat(best_target):
				if _pridej_diplomatickou_zadost(owner_tag, best_target, "non_aggression", ALLIANCE_NONE):
					zmeny.append({
						"a": owner_tag,
						"b": best_target,
						"request": true
					})
			else:
				if uzavrit_neagresivni_smlouvu(owner_tag, best_target):
					_ai_non_aggr_cache.clear()
					if je_lidsky_stat(owner_tag) or je_lidsky_stat(best_target):
						zmeny.append({
							"a": owner_tag,
							"b": best_target
						})

	return zmeny

# Display update for visible data.
func _zobraz_hlaseni_neagresivnich_smluv_hrace(zmeny: Array) -> void:
	# Inputs:
	# - `zmeny`: Input argument used by `_zobraz_hlaseni_neagresivnich_smluv_hrace` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zobraz_hlaseni_neagresivnich_smluv_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zobraz hlaseni neagresivnich smluv hrace` logic.
	# 3. Persist side effects and finish without a return value.
	if zmeny.is_empty():
		return

	var lines_by_target: Dictionary = {}
	for z in zmeny:
		var a = _normalizuj_tag(str(z.get("a", "")))
		var b = _normalizuj_tag(str(z.get("b", "")))
		var is_request = bool(z.get("request", false))
		if a == "" or b == "":
			continue

		# Incoming requests already have dedicated accept/decline UI, so do not
		# duplicate them as system popups.
		if is_request:
			continue

		if je_lidsky_stat(a):
			if not lines_by_target.has(a):
				lines_by_target[a] = []
			(lines_by_target[a] as Array).append("Non-aggression pact with %s (%d turns)." % [_ziskej_jmeno_statu_podle_tagu(b), NON_AGGRESSION_DURATION_TURNS])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Non-aggression pact with %s (%d turns)." % [_ziskej_jmeno_statu_podle_tagu(a), NON_AGGRESSION_DURATION_TURNS])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacy", "\n".join(lines))

# Ai generated or editted start (priloha_a.txt)
func _zpracuj_ai_opusteni_alianci(ai_staty: Array) -> Array:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_zpracuj_ai_opusteni_alianci` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zpracuj ai opusteni alianci` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var zmeny_opusteni: Array = []
	var processed_pairs: Dictionary = {}
	var aktivni_staty = _ziskej_aktivni_staty()
	var aktivni_staty_norm: Array = []
	for s in aktivni_staty:
		var t = _normalizuj_tag(str(s))
		if t != "":
			aktivni_staty_norm.append(t)

	# Track which AI states want to leave which alliance groups
	var ai_group_leaves: Dictionary = {}  # tag -> Array of alliance_ids to leave

	for ai_tag in ai_staty:
		var owner_tag = _normalizuj_tag(str(ai_tag))
		if owner_tag == "":
			continue

		for other_tag in aktivni_staty_norm:
			if other_tag == owner_tag:
				continue

			var pair_key = _klic_pair(owner_tag, other_tag)
			if pair_key == "" or processed_pairs.has(pair_key):
				continue
			processed_pairs[pair_key] = true

			var level = _ziskej_uroven_aliance_ai_cached(owner_tag, other_tag)
			if level <= ALLIANCE_NONE:
				continue

			var rel = ziskej_vztah_statu(owner_tag, other_tag)
			var should_leave = rel < 0.0

			if not should_leave:
				continue

			# Find shared alliance groups and mark for leaving
			var shared = ziskej_spolecne_aliance(owner_tag, other_tag)
			if shared.size() > 0:
				# The AI with the worse relationship leaves the group
				var leaver = owner_tag
				for grp in shared:
					var aid = str(grp.get("id", ""))
					if aid == "":
						continue
					if not ai_group_leaves.has(leaver):
						ai_group_leaves[leaver] = []
					if not (ai_group_leaves[leaver] as Array).has(aid):
						(ai_group_leaves[leaver] as Array).append(aid)
			else:
				# No shared group, clear bilateral directly (legacy cleanup)
				_nastav_uroven_aliance_bez_kontroly(owner_tag, other_tag, ALLIANCE_NONE)

			if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
				zmeny_opusteni.append({
					"a": owner_tag,
					"b": other_tag,
					"rel": rel
				})

	# Process group leaves
	for leaver_tag in ai_group_leaves:
		var aids = ai_group_leaves[leaver_tag] as Array
		for aid in aids:
			odeber_clena_z_aliance(str(aid), str(leaver_tag))

	return zmeny_opusteni

# Ai generated or editted end (priloha_a.txt)
func _zobraz_hlaseni_opusteni_alianci_hrace(zmeny: Array) -> void:
	# Inputs:
	# - `zmeny`: Input argument used by `_zobraz_hlaseni_opusteni_alianci_hrace` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zobraz_hlaseni_opusteni_alianci_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zobraz hlaseni opusteni alianci hrace` logic.
	# 3. Persist side effects and finish without a return value.
	if zmeny.is_empty():
		return

	var lines_by_target: Dictionary = {}
	for z in zmeny:
		var a = _normalizuj_tag(str(z.get("a", "")))
		var b = _normalizuj_tag(str(z.get("b", "")))
		var rel = float(z.get("rel", 0.0))
		if a == "" or b == "":
			continue

		if je_lidsky_stat(a):
			if not lines_by_target.has(a):
				lines_by_target[a] = []
			(lines_by_target[a] as Array).append("%s left the alliance (relation %.1f)." % [b, rel])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("%s left the alliance (relation %.1f)." % [a, rel])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Alliance", "\n".join(lines))

# Draws/updates visible UI output.
func _zobraz_hlaseni_alianci_hrace(zmeny: Array) -> void:
	# Inputs:
	# - `zmeny`: Input argument used by `_zobraz_hlaseni_alianci_hrace` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zobraz_hlaseni_alianci_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zobraz hlaseni alianci hrace` logic.
	# 3. Persist side effects and finish without a return value.
	if zmeny.is_empty():
		return

	var lines_by_target: Dictionary = {}
	for z in zmeny:
		var a = _normalizuj_tag(str(z.get("a", "")))
		var b = _normalizuj_tag(str(z.get("b", "")))
		var level = int(z.get("new_level", ALLIANCE_NONE))
		var is_request = bool(z.get("request", false))
		if a == "" or b == "":
			continue

		# Incoming requests already have dedicated accept/decline UI, so do not
		# duplicate them as system popups.
		if is_request:
			continue

		if je_lidsky_stat(a):
			if not lines_by_target.has(a):
				lines_by_target[a] = []
			(lines_by_target[a] as Array).append("Alliance with %s: %s" % [b, nazev_urovne_aliance(level)])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Alliance with %s: %s" % [a, nazev_urovne_aliance(level)])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Alliance", "\n".join(lines))

# Updates what the player sees.
func _zobraz_hlaseni_vztahu_hrace(zmeny: Array):
	# Inputs:
	# - `zmeny`: Input argument used by `_zobraz_hlaseni_vztahu_hrace` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `_zobraz_hlaseni_vztahu_hrace`.
	# Execution timing: Called when game flow invokes `_zobraz_hlaseni_vztahu_hrace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zobraz hlaseni vztahu hrace` logic.
	# 3. Persist side effects and return the computed `value` result.
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
			(lines_by_target[target] as Array).append("%s improved relation with you. New relation: %.1f" % [stat, rel])
		else:
			(lines_by_target[target] as Array).append("%s worsened relation with you. New relation: %.1f" % [stat, rel])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacy", "\n".join(lines))

# Ai generated or editted start (priloha_a.txt)
func _vyhodnot_mirove_nabidky_pred_ai():
	# Inputs:
	# - none.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `_vyhodnot_mirove_nabidky_pred_ai`.
	# Execution timing: Called when game flow invokes `_vyhodnot_mirove_nabidky_pred_ai` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyhodnot mirove nabidky pred ai` logic.
	# 3. Persist side effects and return the computed `value` result.
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
			if je_lidsky_stat(prijemce):
				_pridej_diplomatickou_zadost(odesilatel, prijemce, "peace")
			continue

		if _ma_ai_prijmout_mir(prijemce, odesilatel):
			uzavri_mir_a_zahaj_konferenci(odesilatel, prijemce, "peace_offer")
			var ok_msg = "Peace offer accepted: %s and %s made peace." % [odesilatel, prijemce]
			print(ok_msg)
			_zaloguj_globalni_zpravu("Diplomacy", ok_msg, "diplomacy")
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACY", ok_msg)
		else:
			var no_msg = "Peace offer declined: %s declined peace with %s." % [prijemce, odesilatel]
			print(no_msg)
			_zaloguj_globalni_zpravu("Diplomacy", no_msg, "diplomacy")
			if je_lidsky_stat(odesilatel):
				_zaloguj_zpravu_hraci(odesilatel, "Diplomacy", "%s declined your peace offer." % prijemce, "diplomacy")
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACY", no_msg)

# Ai generated or editted end (priloha_a.txt)
func zaregistruj_obsazeni_hlavniho_mesta(obrance: String, utocnik: String, capital_province_id: int):
	# Inputs:
	# - `obrance`: Input argument used by `zaregistruj_obsazeni_hlavniho_mesta` during execution.
	# - `utocnik`: Input argument used by `zaregistruj_obsazeni_hlavniho_mesta` during execution.
	# - `capital_province_id`: Input argument used by `zaregistruj_obsazeni_hlavniho_mesta` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `zaregistruj_obsazeni_hlavniho_mesta`.
	# Execution timing: Called when game flow invokes `zaregistruj_obsazeni_hlavniho_mesta` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `zaregistruj obsazeni hlavniho mesta` logic.
	# 3. Persist side effects and return the computed `value` result.
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
	_zaloguj_globalni_zpravu(
		"War",
		"%s occupied the capital of %s. If held until next turn, capitulation follows." % [uto, obr],
		"war"
	)

# Ai generated or editted start (priloha_a.txt)
func vyhodnot_odlozene_kapitulace() -> Array:
	# Inputs:
	# - none.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `vyhodnot_odlozene_kapitulace` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `vyhodnot odlozene kapitulace` logic.
	# 3. Persist side effects and return the computed `Array` result.
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

# Ai generated or editted end (priloha_a.txt)
func _je_more_provincie_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	# Inputs:
	# - `all_provinces`: Input argument used by `_je_more_provincie_v_datech` during execution.
	# - `prov_id`: Input argument used by `_je_more_provincie_v_datech` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_more_provincie_v_datech` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je more provincie v datech` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not all_provinces.has(prov_id):
		return false
	var d = all_provinces[prov_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner_tag == "SEA" or typ == "sea"

# Eligibility/guard check.
func _je_pobrezni_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	# Inputs:
	# - `all_provinces`: Input argument used by `_je_pobrezni_v_datech` during execution.
	# - `prov_id`: Input argument used by `_je_pobrezni_v_datech` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_pobrezni_v_datech` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je pobrezni v datech` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not all_provinces.has(prov_id):
		return false
	if _je_more_provincie_v_datech(all_provinces, prov_id):
		return false
	for n_id in all_provinces[prov_id].get("neighbors", []):
		if _je_more_provincie_v_datech(all_provinces, int(n_id)):
			return true
	return false

# Core flow for this feature.
func _vyber_startovni_port_kandidata(all_provinces: Dictionary, kandidati: Array) -> int:
	# Inputs:
	# - `all_provinces`: Input argument used by `_vyber_startovni_port_kandidata` during execution.
	# - `kandidati`: Input argument used by `_vyber_startovni_port_kandidata` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_vyber_startovni_port_kandidata` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyber startovni port kandidata` logic.
	# 3. Persist side effects and return the computed `int` result.
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

# Runs the local feature logic.
func pridej_startovni_pristavy(all_provinces: Dictionary):
	# Inputs:
	# - `all_provinces`: Input argument used by `pridej_startovni_pristavy` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `pridej_startovni_pristavy`.
	# Execution timing: Called when game flow invokes `pridej_startovni_pristavy` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `pridej startovni pristavy` logic.
	# 3. Persist side effects and return the computed `value` result.
	if all_provinces.is_empty():
		return

	var vsechny_staty: Dictionary = {}
	var stat_ma_pristav: Dictionary = {}
	var kandidati: Dictionary = {}

	for p_id in all_provinces.keys():
		var pid = int(p_id)
		var d = all_provinces[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		if owner_tag == "" or owner_tag == "SEA":
			continue

		vsechny_staty[owner_tag] = true

		if bool(d.get("has_port", false)):
			stat_ma_pristav[owner_tag] = true

		if _je_pobrezni_v_datech(all_provinces, pid):
			if not kandidati.has(owner_tag):
				kandidati[owner_tag] = []
			(kandidati[owner_tag] as Array).append(pid)

	for state_tag in vsechny_staty.keys():
		if stat_ma_pristav.has(state_tag):
			continue
		if not kandidati.has(state_tag):
			continue

		var vybrany = _vyber_startovni_port_kandidata(all_provinces, kandidati[state_tag])
		if vybrany != -1 and all_provinces.has(vybrany):
			all_provinces[vybrany]["has_port"] = true

# Computes derived values from current inputs and game state.
func spocitej_prijem(all_provinces: Dictionary, emit_ui_signal: bool = true):
	# Inputs:
	# - `all_provinces`: Input argument used by `spocitej_prijem` during execution.
	# - `emit_ui_signal`: Input argument used by `spocitej_prijem` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `spocitej_prijem` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `spocitej prijem` logic.
	# 3. Persist side effects and return the computed `value` result.
	map_data = all_provinces
	_prewarm_runtime_cache_if_needed()
	_synchronizuj_jmeno_a_ideologii_hrace()
	var celkove_hdp = 0.0
	var hrac_clean = _normalizuj_tag(hrac_stat)
	
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == hrac_clean:
			if hrac_jmeno == "":
				hrac_jmeno = str(d.get("country_name", ""))
				hrac_ideologie = str(d.get("ideology", ""))
			
			celkove_hdp += float(d.get("gdp", 0.0))

	if lokalni_hraci_staty.size() > 1:
		if not hrac_kasa_inicializovana.has(hrac_clean) and celkove_hdp > 0.0:
			hrac_kasy[hrac_clean] = celkove_hdp * 0.05
			hrac_kasa_inicializovana[hrac_clean] = true
		hrac_kasy[hrac_clean] = statni_kasa
		statni_kasa = float(hrac_kasy.get(hrac_clean, statni_kasa))
	else:
		if not _hrac_kasa_inicializovana and celkove_hdp > 0.0:
			statni_kasa = celkove_hdp * 0.05
			hrac_kasy[hrac_clean] = statni_kasa
			_hrac_kasa_inicializovana = true
			hrac_kasa_inicializovana[hrac_clean] = true
			
	# Balanced income: 10% GDP minus army upkeep
	var prijmova_sazba = ziskej_prijmovou_sazbu_hdp(hrac_clean)
	var prijem_z_hdp = celkove_hdp * prijmova_sazba
	var naklady_na_vojaky = _spocitej_naklady_udrzby_statu(hrac_clean)
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	var finance_breakdown = ziskej_financni_rozpad_statu(hrac_clean)
	if bool(finance_breakdown.get("ok", false)):
		celkovy_prijem = float(finance_breakdown.get("cashflow", finance_breakdown.get("profit", celkovy_prijem)))
	if lokalni_hraci_staty.size() > 1:
		hrac_prijmy[hrac_clean] = celkovy_prijem
		hrac_kasy[hrac_clean] = statni_kasa
	
	if TURN_LOG_ENABLED:
		print("HDP Prijem: %.2f | Vydaje Armada: %.2f | Cashflow: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	if emit_ui_signal:
		kolo_zmeneno.emit()

# Computes derived values from current inputs and game state.
func _spocitej_hdp_statu(tag: String) -> float:
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `_spocitej_hdp_statu`.
	# Execution timing: Called when game flow invokes `_spocitej_hdp_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej hdp statu` logic.
	# 3. Persist side effects and return the computed `float` result.
	var hledany = _normalizuj_tag(tag)
	if hledany == "":
		return 0.0
	if _turn_cache_valid and _turn_state_hdp.has(hledany):
		return float(_turn_state_hdp[hledany])
	var hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == hledany:
			hdp += float(d.get("gdp", 0.0))
	return hdp

# Sync update for linked values.
func _nastav_stav_zpracovani_tahu(aktivni: bool) -> void:
	# Inputs:
	# - `aktivni`: Input argument used by `_nastav_stav_zpracovani_tahu` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_nastav_stav_zpracovani_tahu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` nastav stav zpracovani tahu` logic.
	# 3. Persist side effects and finish without a return value.
	if zpracovava_se_tah == aktivni:
		return
	zpracovava_se_tah = aktivni
	zpracovani_tahu_zmeneno.emit(aktivni)

# Handles this gameplay/UI path.
func _spust_turn_watchdog(token: int) -> void:
	# Inputs:
	# - `token`: Input argument used by `_spust_turn_watchdog` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_spust_turn_watchdog` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spust turn watchdog` logic.
	# 3. Persist side effects and finish without a return value.
	await get_tree().create_timer(float(TURN_STUCK_WATCHDOG_MS) / 1000.0).timeout
	if token != _turn_watchdog_token:
		return
	if not zpracovava_se_tah:
		return
	print("[TURN_WATCHDOG] Turn processing timeout reached, forcing UI unlock.")
	_nastav_stav_zpracovani_tahu(false)
	kolo_zmeneno.emit()

# Cancels the active flow and restores a safe default state.
func _zrus_turn_watchdog() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_zrus_turn_watchdog` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` zrus turn watchdog` logic.
	# 3. Persist side effects and finish without a return value.
	_turn_watchdog_token += 1

# Handles this gameplay/UI path.
func muze_ukoncit_kolo() -> bool:
	# Inputs:
	# - none.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `muze_ukoncit_kolo` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `muze ukoncit kolo` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if zpracovava_se_tah:
		return false
	var elapsed = Time.get_ticks_msec() - _last_end_turn_request_ms
	return elapsed >= NEXT_TURN_INPUT_COOLDOWN_MS

# Core flow for this feature.
func pozaduj_ukonceni_kola() -> bool:
	# Inputs:
	# - none.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `pozaduj_ukonceni_kola` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `pozaduj ukonceni kola` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if zpracovava_se_tah:
		# Ignore repeated input while a turn is already processing.
		# Queueing here caused "runaway" extra turns after key spam or UI interactions.
		_queued_end_turn_requests = 0
		return false
	if not muze_ukoncit_kolo():
		return false
	_queued_end_turn_requests = 0
	_last_end_turn_request_ms = Time.get_ticks_msec()
	ukonci_kolo()
	return true

# Handles this gameplay/UI path.
func _spust_dalsi_pozadovane_kolo() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_spust_dalsi_pozadovane_kolo` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spust dalsi pozadovane kolo` logic.
	# 3. Persist side effects and finish without a return value.
	if zpracovava_se_tah:
		return
	if _queued_end_turn_requests <= 0:
		return
	_queued_end_turn_requests -= 1
	_last_end_turn_request_ms = Time.get_ticks_msec()
	ukonci_kolo()

# Runs the local feature logic.
func _dokoncit_ukonceni_kola(turn_start_ms: int, turn_phases: Dictionary) -> void:
	# Inputs:
	# - `turn_start_ms`: Input argument used by `_dokoncit_ukonceni_kola` during execution.
	# - `turn_phases`: Input argument used by `_dokoncit_ukonceni_kola` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_dokoncit_ukonceni_kola` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` dokoncit ukonceni kola` logic.
	# 3. Persist side effects and finish without a return value.
	_uloz_debug_turn_profile(Time.get_ticks_msec() - turn_start_ms, turn_phases)
	_zrus_turn_watchdog()
	_nastav_stav_zpracovani_tahu(false)
	_log_turn_profile(Time.get_ticks_msec() - turn_start_ms, turn_phases)
	_queued_end_turn_requests = 0

func _append_debug_turn_event(message: String) -> void:
	# Inputs:
	# - `message`: Input argument used by `_append_debug_turn_event` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_append_debug_turn_event` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` append debug turn event` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	var trimmed = message.strip_edges()
	if trimmed == "":
		return
	_debug_turn_live_events.append(trimmed)

# Stores current data to disk.
func _uloz_debug_turn_profile(total_ms: int, phases: Dictionary) -> void:
	# Inputs:
	# - `total_ms`: Input argument used by `_uloz_debug_turn_profile` during execution.
	# - `phases`: Input argument used by `_uloz_debug_turn_profile` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_uloz_debug_turn_profile` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` uloz debug turn profile` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	var entry = {
		"turn": aktualni_kolo,
		"total_ms": total_ms,
		"phases": phases.duplicate(true),
		"events": _debug_turn_live_events.duplicate(true)
	}
	_debug_last_turn_profile = entry
	_debug_turn_history.append(entry)
	while _debug_turn_history.size() > DEBUG_TURN_HISTORY_MAX:
		_debug_turn_history.remove_at(0)
	_debug_turn_live_events.clear()

# Ai generated or editted start (priloha_a.txt)
func _log_turn_profile(total_ms: int, phases: Dictionary) -> void:
	# Inputs:
	# - `total_ms`: Input argument used by `_log_turn_profile` during execution.
	# - `phases`: Input argument used by `_log_turn_profile` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_log_turn_profile` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` log turn profile` logic.
	# 3. Persist side effects and finish without a return value.
	if not TURN_PROFILE_ENABLED:
		return
	var p_switch = int(phases.get("switch_player", 0))
	var p_armies = int(phases.get("armies", 0))
	var p_finance = int(phases.get("finance", 0))
	var p_growth = int(phases.get("growth", 0))
	var p_ai = int(phases.get("ai", 0))
	var p_popups = int(phases.get("popups", 0))
	var p_ui = int(phases.get("ui", 0))
	var level = "WARN" if total_ms >= TURN_PROFILE_WARN_MS else "INFO"
	print("[TURN_PROFILE][%s] turn=%d total=%dms | switch=%dms armies=%dms finance=%dms growth=%dms ai=%dms popups=%dms ui=%dms" % [
		level,
		aktualni_kolo,
		total_ms,
		p_switch,
		p_armies,
		p_finance,
		p_growth,
		p_ai,
		p_popups,
		p_ui
	])

# Ai generated or editted end (priloha_a.txt)
func _log_ai_profile(total_ms: int, phases: Dictionary) -> void:
	# Inputs:
	# - `total_ms`: Input argument used by `_log_ai_profile` during execution.
	# - `phases`: Input argument used by `_log_ai_profile` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_log_ai_profile` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` log ai profile` logic.
	# 3. Persist side effects and finish without a return value.
	if not AI_PROFILE_ENABLED:
		return
	var p_setup = int(phases.get("setup", 0))
	var p_dip = int(phases.get("diplomacy", 0))
	var p_econ = int(phases.get("economy_recruit", 0))
	var p_move = int(phases.get("movement", 0))
	var p_clean = int(phases.get("cleanup", 0))
	var level = "WARN" if total_ms >= AI_PROFILE_WARN_MS else "INFO"
	print("[AI_PROFILE][%s] turn=%d total=%dms | setup=%dms dip=%dms econ=%dms move=%dms clean=%dms" % [
		level,
		aktualni_kolo,
		total_ms,
		p_setup,
		p_dip,
		p_econ,
		p_move,
		p_clean
	])

# Core flow for this feature.
func _ai_debug(msg: String) -> void:
	# Inputs:
	# - `msg`: Input argument used by `_ai_debug` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_debug` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai debug` logic.
	# 3. Persist side effects and finish without a return value.
	if not AI_DECISION_DEBUG_ENABLED:
		return
	if not _ai_debug_mode_enabled:
		return
	if _ai_debug_turn_marker != aktualni_kolo:
		_ai_debug_turn_marker = aktualni_kolo
		_ai_debug_lines_this_turn = 0
		_ai_debug_suppressed_notice_printed = false
	if _ai_debug_lines_this_turn >= AI_DEBUG_MAX_LINES_PER_TURN:
		if not _ai_debug_suppressed_notice_printed:
			print("[AI_DEBUG][turn=%d] ... output capped at %d lines ..." % [aktualni_kolo, AI_DEBUG_MAX_LINES_PER_TURN])
			_ai_debug_suppressed_notice_printed = true
		return
	_ai_debug_lines_this_turn += 1
	print("[AI_DEBUG][turn=%d] %s" % [aktualni_kolo, msg])

func _money_debug(msg: String) -> void:
	# Inputs:
	# - `msg`: Input argument used by `_money_debug` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_money_debug` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` money debug` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	_append_debug_turn_event(msg)
	print("[MONEY_DEBUG][turn=%d] %s" % [aktualni_kolo, msg])

# Runs the local feature logic.
func _money_debug_expense(state_tag: String, category: String, amount: float, treasury_before: float, treasury_after: float, detail: String = "") -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `category`: Category/type selector used to branch logic.
	# - `amount`: Input argument used by `_money_debug_expense` during execution.
	# - `treasury_before`: Input argument used by `_money_debug_expense` during execution.
	# - `treasury_after`: Input argument used by `_money_debug_expense` during execution.
	# - `detail`: Input argument used by `_money_debug_expense` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_money_debug_expense` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` money debug expense` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	var state = _normalizuj_tag(state_tag)
	var suffix = ""
	var clean_detail = detail.strip_edges()
	if clean_detail != "":
		suffix = " | %s" % clean_detail
	_money_debug("expense %s %s amount=%.2f cash_before=%.2f cash_after=%.2f%s" % [state, category, amount, treasury_before, treasury_after, suffix])

func _money_debug_income_event(state_tag: String, category: String, amount: float, treasury_before: float, treasury_after: float, detail: String = "") -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `category`: Category/type selector used to branch logic.
	# - `amount`: Input argument used by `_money_debug_income_event` during execution.
	# - `treasury_before`: Input argument used by `_money_debug_income_event` during execution.
	# - `treasury_after`: Input argument used by `_money_debug_income_event` during execution.
	# - `detail`: Input argument used by `_money_debug_income_event` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_money_debug_income_event` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` money debug income event` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	var state = _normalizuj_tag(state_tag)
	var suffix = ""
	var clean_detail = detail.strip_edges()
	if clean_detail != "":
		suffix = " | %s" % clean_detail
	_money_debug("income_event %s %s amount=%.2f cash_before=%.2f cash_after=%.2f%s" % [state, category, amount, treasury_before, treasury_after, suffix])

# Core flow for this feature.
func _snapshot_lidske_kasy() -> Dictionary:
	# Inputs:
	# - none.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_snapshot_lidske_kasy` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` snapshot lidske kasy` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var snapshot: Dictionary = {}
	for raw_tag in lokalni_hraci_staty:
		var t = _normalizuj_tag(str(raw_tag))
		if t == "":
			continue
		snapshot[t] = _ziskej_kasu_statu(t)
	return snapshot

# Ai generated or editted start (priloha_a.txt)
func _with_finance_projection_cash_overrides(overrides: Dictionary, callback: Callable):
	# mala helper vrstva: docasne prehodi cash snapshot jen pro vypocet projekce.
	var previous = _finance_projection_cash_overrides.duplicate(true)
	_finance_projection_cash_overrides = overrides.duplicate(true)
	var result = callback.call()
	_finance_projection_cash_overrides = previous
	return result

# Ai generated or editted end (priloha_a.txt)
func _money_debug_log_delta(stage: String, before: Dictionary) -> void:
	# Inputs:
	# - `stage`: Input argument used by `_money_debug_log_delta` during execution.
	# - `before`: Input argument used by `_money_debug_log_delta` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_money_debug_log_delta` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` money debug log delta` logic.
	# 3. Persist side effects and finish without a return value.
	if not _ai_debug_mode_enabled:
		return
	# debug je schvalne po statech, aby se rychle nasel kdo rozhoupal kasu.
	for raw_tag in lokalni_hraci_staty:
		var t = _normalizuj_tag(str(raw_tag))
		if t == "":
			continue
		var old_cash = float(before.get(t, _ziskej_kasu_statu(t)))
		var new_cash = _ziskej_kasu_statu(t)
		var delta = new_cash - old_cash
		if absf(delta) < 0.0001:
			continue
		_money_debug("%s %s delta=%.2f cash_before=%.2f cash_after=%.2f" % [stage, t, delta, old_cash, new_cash])

# Ai generated or editted start (priloha_a.txt)
func _turn_slice_wait(counter: int, chunk: int) -> int:
	# Keep slicing only for low-end potato mode to maximize turn throughput on normal PCs.
	if not TURN_FRAME_SLICE_ENABLED or not _potato_mode_enabled:
		return counter
	# mikro-yield drzi frame plynulejsi pri dlouhych turn fazich.
	var next_counter = counter + 1
	if next_counter >= max(1, chunk):
		await get_tree().process_frame
		return 0
	return next_counter

# Ai generated or editted end (priloha_a.txt)
func ukonci_kolo():
	# End-turn pipeline runs in deterministic phases so profiling output stays readable
	# and multiplayer turn-switch logic can short-circuit before global AI processing.
	if zpracovava_se_tah:
		return
	_nastav_stav_zpracovani_tahu(true)
	# Start processing immediately to avoid a guaranteed extra frame delay each turn.
	_sim_cache_validni = false
	_sjednot_financni_toky_cache()
	if _ai_debug_mode_enabled:
		_debug_turn_live_events.clear()
		_append_debug_turn_event("turn start active=%s local_index=%d players=%d" % [_normalizuj_tag(hrac_stat), aktivni_hrac_index, lokalni_hraci_staty.size()])
	var turn_start_ms = Time.get_ticks_msec()
	var phase_start_ms = turn_start_ms
	var turn_phases := {
		"switch_player": 0,
		"armies": 0,
		"finance": 0,
		"growth": 0,
		"ai": 0,
		"popups": 0,
		"ui": 0
	}
	_last_end_turn_request_ms = Time.get_ticks_msec()
	_turn_watchdog_token += 1
	_spust_turn_watchdog(_turn_watchdog_token)
	if lokalni_hraci_staty.size() > 1:
		_sjednot_multiplayer_finance_cache()

	if lokalni_hraci_staty.size() > 1 and not _je_posledni_hrac_v_poradi():
		# In local multiplayer, non-last players only rotate control and refresh UI.
		# Heavy world simulation runs after the last local player confirms end turn.
		_uloz_finance_aktivniho_hrace()
		_prepni_na_dalsiho_hrace()
		if not map_data.is_empty():
			spocitej_prijem(map_data, false)
		turn_phases["switch_player"] = Time.get_ticks_msec() - phase_start_ms
		phase_start_ms = Time.get_ticks_msec()
		await _zobraz_cekajici_popupy_aktivniho_hrace()
		turn_phases["popups"] = int(turn_phases["popups"]) + (Time.get_ticks_msec() - phase_start_ms)
		phase_start_ms = Time.get_ticks_msec()
		kolo_zmeneno.emit()
		turn_phases["ui"] = Time.get_ticks_msec() - phase_start_ms
		_dokoncit_ukonceni_kola(turn_start_ms, turn_phases)
		return

	var map_loader = _get_map_loader()
	
	if map_loader:
		# Resolve battles and remove stale moves
		await map_loader.zpracuj_tah_armad()
		if _oprav_neplatne_vlastniky_armad():
			if map_loader.has_method("aktualizuj_ikony_armad"):
				map_loader.aktualizuj_ikony_armad()
	turn_phases["armies"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	if lokalni_hraci_staty.size() > 1:
		# Multi-local mode computes each human state's base income first,
		# then keeps projected cashflow separately for UI and finance tooltips.
		# dulezity detail: base income se pripise do kasy, cashflow je jen projekce pro UI.
		_uloz_finance_aktivniho_hrace()
		var treasury_before_income = _snapshot_lidske_kasy()
		for tag in lokalni_hraci_staty:
			var cisty_tag = _normalizuj_tag(str(tag))
			if cisty_tag == "" or cisty_tag == "SEA":
				continue
			var cash_before_income = float(treasury_before_income.get(cisty_tag, hrac_kasy.get(cisty_tag, _ziskej_kasu_statu(cisty_tag))))
			if not hrac_kasa_inicializovana.has(cisty_tag):
				if not hrac_kasy.has(cisty_tag):
					var start_hdp = max(0.0, _spocitej_hdp_statu(cisty_tag))
					if start_hdp > 0.0:
						hrac_kasy[cisty_tag] = start_hdp * 0.05
						treasury_before_income[cisty_tag] = float(hrac_kasy[cisty_tag])
						cash_before_income = float(hrac_kasy[cisty_tag])
				hrac_kasa_inicializovana[cisty_tag] = true
			var base_income = _spocitej_cisty_prijem_statu(cisty_tag)
			var finance_breakdown = _with_finance_projection_cash_overrides(treasury_before_income, func():
				return ziskej_financni_rozpad_statu(cisty_tag)
			)
			var projected_cashflow = float(finance_breakdown.get("cashflow", finance_breakdown.get("profit", base_income)))
			hrac_prijmy[cisty_tag] = projected_cashflow
			var kasa = float(hrac_kasy.get(cisty_tag, 0.0)) + base_income
			hrac_kasy[cisty_tag] = kasa
			_money_debug("income %s base_income=%.2f projected_cashflow=%.2f cash_before=%.2f cash_after=%.2f" % [cisty_tag, base_income, projected_cashflow, cash_before_income, kasa])
			if cisty_tag == _normalizuj_tag(hrac_stat):
				statni_kasa = kasa
				celkovy_prijem = projected_cashflow
			if kasa < -100.0:
				await _vyres_bankrot(cisty_tag)
	else:
		var single_before_income = statni_kasa
		var current_tag = _normalizuj_tag(hrac_stat)
		var base_income = _spocitej_cisty_prijem_statu(current_tag)
		var finance_breakdown = _with_finance_projection_cash_overrides({current_tag: single_before_income}, func():
			return ziskej_financni_rozpad_statu(current_tag)
		)
		celkovy_prijem = float(finance_breakdown.get("cashflow", finance_breakdown.get("profit", base_income)))
		statni_kasa += base_income
		_money_debug("income %s base_income=%.2f projected_cashflow=%.2f cash_before=%.2f cash_after=%.2f" % [current_tag, base_income, celkovy_prijem, single_before_income, statni_kasa])
		
		# Bankruptcy at debt below -100
		if statni_kasa < -100.0:
			await _vyres_bankrot(hrac_stat)
	turn_phases["finance"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	aktualni_kolo += 1
	# tohle je snapshot pred "flow" efekty (reparace/odvody/pujcky), at jde ladit delta.
	var _money_before_flow_effects: Dictionary = _snapshot_lidske_kasy() if lokalni_hraci_staty.size() > 1 else {}
	var _single_before_flow_effects = statni_kasa
	_zpracuj_valecne_reparace_za_kolo()
	_zpracuj_vazalske_odvody_za_kolo()
	_zpracuj_cekajici_pujcky_za_kolo()
	_zpracuj_aktivni_pujcky_za_kolo()
	if lokalni_hraci_staty.size() > 1:
		_money_debug_log_delta("flows", _money_before_flow_effects)
	else:
		var flow_delta = statni_kasa - _single_before_flow_effects
		if absf(flow_delta) >= 0.0001:
			_money_debug("flows %s delta=%.2f cash_before=%.2f cash_after=%.2f" % [_normalizuj_tag(hrac_stat), flow_delta, _single_before_flow_effects, statni_kasa])
	
	var hotove_stavby = []
	var hlaseni_dokoncene_stavby: Dictionary = {}
	var cooldown_slice_counter := 0
	for prov_id in provincie_cooldowny.keys():
		provincie_cooldowny[prov_id]["zbyva"] -= 1 
		if provincie_cooldowny[prov_id]["zbyva"] <= 0:
			hotove_stavby.append(prov_id)
		cooldown_slice_counter = await _turn_slice_wait(cooldown_slice_counter, TURN_FRAME_SLICE_PROVINCES)
			
	var finish_slice_counter := 0
	for prov_id in hotove_stavby:
		var typ_budovy = provincie_cooldowny[prov_id]["budova"]
		provincie_cooldowny.erase(prov_id)
		_aplikuj_bonus(prov_id, typ_budovy)
		if map_data.has(prov_id):
			var nazev = str(map_data[prov_id].get("province_name", "Province %d" % int(prov_id)))
			var owner_tag = _normalizuj_tag(str(map_data[prov_id].get("owner", "")))
			if je_lidsky_stat(owner_tag):
				if not hlaseni_dokoncene_stavby.has(owner_tag):
					hlaseni_dokoncene_stavby[owner_tag] = []
				var build_name = _ziskej_nazev_budovy(typ_budovy)
				(hlaseni_dokoncene_stavby[owner_tag] as Array).append("%s completed: %s" % [build_name, nazev])
		finish_slice_counter = await _turn_slice_wait(finish_slice_counter, TURN_FRAME_SLICE_PROVINCES)

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
		var econ_mods_by_owner: Dictionary = {}
		var growth_slice_counter := 0
		
		# Occupied territory recovers recruits much slower than core land.
		for p_id in map_data:
			var d = map_data[p_id]
			var base_recruits = int(d.get("base_recruitable_population", d.get("recruitable_population", 0)))
			if base_recruits < 0:
				base_recruits = 0
			var cap = base_recruits
			var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
			var core_owner_tag = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
			var je_okupace = owner_tag != "" and owner_tag != "SEA" and core_owner_tag != "" and core_owner_tag != owner_tag
			if not econ_mods_by_owner.has(owner_tag):
				econ_mods_by_owner[owner_tag] = ziskej_ekonomicke_modifikatory_statu(owner_tag)
			var econ_mods = econ_mods_by_owner[owner_tag] as Dictionary
			var build_mods = _ziskej_modifikatory_budov_provincie(int(p_id))
			var recruit_regen_mult = max(0.01, float(econ_mods.get("recruit_regen_mult", 1.0))) * max(0.01, float(build_mods.get("recruit_regen_mult", 1.0)))
			var gdp_growth_mult = max(0.01, float(econ_mods.get("gdp_growth_mult", 1.0))) * max(0.01, float(build_mods.get("gdp_growth_mult", 1.0)))
			var pop_growth_mult = max(0.01, float(econ_mods.get("population_growth_mult", 1.0))) * max(0.01, float(build_mods.get("population_growth_mult", 1.0)))
			var regen_ratio = 0.025 if je_okupace else 0.10
			regen_ratio *= recruit_regen_mult
			var regen_per_turn = max(1, int(round(float(base_recruits) * regen_ratio)))
			d["recruitable_population"] = min(int(d.get("recruitable_population", 0)) + regen_per_turn, cap)
			d["gdp"] += BASE_GDP_GROWTH_PER_TURN * gdp_growth_mult

			if owner_tag != "" and owner_tag != "SEA":
				var pop = int(d.get("population", 0))
				if pop > 0:
					var growth_ratio = BASE_POP_GROWTH_RATIO * pop_growth_mult
					if je_okupace:
						growth_ratio *= 0.40
					var pop_growth = max(1, int(round(float(pop) * growth_ratio)))
					d["population"] = pop + pop_growth
			growth_slice_counter = await _turn_slice_wait(growth_slice_counter, TURN_FRAME_SLICE_PROVINCES)
	turn_phases["growth"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	# AI plans attacks and may declare wars (await for popups)
	await zpracuj_tah_ai()
	turn_phases["ai"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	if not hlaseni_dokoncene_stavby.is_empty():
		for owner_tag in hlaseni_dokoncene_stavby.keys():
			var lines = hlaseni_dokoncene_stavby[owner_tag] as Array
			if lines.is_empty():
				continue
			_pridej_popup_hraci(str(owner_tag), "Report", "\n".join(lines))

	if TURN_LOG_ENABLED:
		print("--- TURN %d ---" % aktualni_kolo)

	if lokalni_hraci_staty.size() > 1:
		_prepni_na_hrace(0)
		if not map_data.is_empty():
			spocitej_prijem(map_data, false)
	await _zobraz_cekajici_popupy_aktivniho_hrace()
	turn_phases["popups"] = int(turn_phases["popups"]) + (Time.get_ticks_msec() - phase_start_ms)
	phase_start_ms = Time.get_ticks_msec()
	kolo_zmeneno.emit()
	turn_phases["ui"] = int(turn_phases["ui"]) + (Time.get_ticks_msec() - phase_start_ms)
	_dokoncit_ukonceni_kola(turn_start_ms, turn_phases)

# Applies prepared settings/effects to runtime systems.
func _aplikuj_bonus(prov_id: int, typ):
	# Inputs:
	# - `prov_id`: Input argument used by `_aplikuj_bonus` during execution.
	# - `typ`: Input argument used by `_aplikuj_bonus` during execution.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `_aplikuj_bonus`.
	# Execution timing: Called when game flow invokes `_aplikuj_bonus` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` aplikuj bonus` logic.
	# 3. Persist side effects and return the computed `value` result.
	if not map_data.has(prov_id):
		return

	var building_id = _legacy_building_id(typ)
	if building_id == "":
		return
	var bdef = _ziskej_building_def(building_id)
	if bdef.is_empty():
		return

	if not _pridej_budovu_provincie(prov_id, building_id):
		return

	var d = map_data[prov_id] as Dictionary
	d["gdp"] = float(d.get("gdp", 0.0)) + float(bdef.get("gdp_flat", 0.0))

	var recruit_flat = int(bdef.get("recruitable_flat", 0))
	if recruit_flat != 0:
		var current_recruit = int(d.get("recruitable_population", 0)) + recruit_flat
		d["recruitable_population"] = max(0, current_recruit)
		var base_cap = int(d.get("base_recruitable_population", d.get("recruitable_population", 0))) + recruit_flat
		d["base_recruitable_population"] = max(0, base_cap)
		var raw_cap = int(d.get("base_recruitable_population_raw", d.get("base_recruitable_population", 0))) + recruit_flat
		d["base_recruitable_population_raw"] = max(0, raw_cap)

	if bool(bdef.get("grant_port", false)):
		d["has_port"] = true
		var map_loader = _get_map_loader()
		if map_loader and map_loader.has_method("oznac_pristavy_k_aktualizaci"):
			map_loader.oznac_pristavy_k_aktualizaci()

# Bankruptcy logic
# Handles this gameplay/UI path.
func _vyres_bankrot(tag: String):
	# Inputs:
	# - `tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_vyres_bankrot` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyres bankrot` logic.
	# 3. Persist side effects and return the computed `value` result.
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
			_pridej_popup_hraci(tag, "STATE BANKRUPTCY", "Out of money. %d soldiers deserted." % celkem_dezertovalo)
		elif TURN_LOG_ENABLED:
			print("AI BANKRUPTCY (%s): %d soldiers deserted." % [tag, celkem_dezertovalo])

# Player actions

# Runs the local feature logic.
func hrac_verbuje(provincie_id: int, pocet: int) -> bool:
	# Inputs:
	# - `provincie_id`: Input argument used by `hrac_verbuje` during execution.
	# - `pocet`: Input argument used by `hrac_verbuje` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `hrac_verbuje` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `hrac verbuje` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return false
	
	var d = map_data[provincie_id]
	if str(d.get("owner", "")).strip_edges().to_upper() != hrac_stat: return false
		
	var cena_za_vojaka = ziskej_cenu_za_vojaka(hrac_stat)
	var celkova_cena = pocet * cena_za_vojaka
	
	if statni_kasa >= celkova_cena:
		var dostupni_rekruti = int(d.get("recruitable_population", 0))
		if dostupni_rekruti >= pocet:
			var cash_before_recruit = statni_kasa
			_nastav_kasu_statu(hrac_stat, statni_kasa - celkova_cena)
			d["recruitable_population"] -= pocet
			d["soldiers"] += pocet
			d["army_owner"] = hrac_stat
			_money_debug_expense(hrac_stat, "recruit", celkova_cena, cash_before_recruit, statni_kasa, "province=%d soldiers=%d" % [provincie_id, pocet])
			map_loader.aktualizuj_ikony_armad()
			kolo_zmeneno.emit() 
			return true
	return false

# Runs the local feature logic.
func _ai_vytvor_profil_pro_ideologii(ideology: String) -> Dictionary:
	# Inputs:
	# - `ideology`: Input argument used by `_ai_vytvor_profil_pro_ideologii` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_vytvor_profil_pro_ideologii` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai vytvor profil pro ideologii` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var ideol = _normalizuj_ideologii(ideology)
	var aggression := 0.50
	var defense := 0.55
	var unpredictability := 0.30
	var personality := "balanced"

	match ideol:
		"demokracie":
			aggression = 0.34
			defense = 0.58
			unpredictability = 0.22
			personality = "tactician"
		"autokracie":
			aggression = 0.56
			defense = 0.50
			unpredictability = 0.32
			personality = "expansionist"
		"komunismus":
			aggression = 0.46
			defense = 0.60
			unpredictability = 0.28
			personality = "planner"
		"monarchie":
			aggression = 0.42
			defense = 0.66
			unpredictability = 0.20
			personality = "fortress"
		"fascismus", "nacismus":
			aggression = 0.72
			defense = 0.42
			unpredictability = 0.40
			personality = "warlord"

	# Add mild random drift so same ideology still plays differently each game.
	aggression = clamp(aggression + randf_range(-0.12, 0.12), 0.20, 0.95)
	defense = clamp(defense + randf_range(-0.12, 0.12), 0.20, 0.95)
	unpredictability = clamp(unpredictability + randf_range(-0.10, 0.14), 0.05, 0.95)

	# Blend with global aggression level (70% weight) so the slider has a strong effect.
	aggression = clampf(lerpf(aggression, _global_ai_aggression_level, 0.70), 0.0, 1.0)

	# Final personality pass: profile can drift based on generated traits.
	if defense >= 0.70:
		personality = "fortress"
	elif aggression >= 0.76 and unpredictability >= 0.36:
		personality = "warlord"
	elif aggression >= 0.63:
		personality = "expansionist"
	elif unpredictability >= 0.46:
		personality = "opportunist"
	elif defense >= 0.60:
		personality = "tactician"

	return {
		"ideology": ideol,
		"aggression": aggression,
		"defense": defense,
		"unpredictability": unpredictability,
		"personality": personality
	}

# Core flow for this feature.
func _ai_ziskej_profil(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_ziskej_profil` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej profil` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"aggression": 0.5, "defense": 0.55, "unpredictability": 0.30, "ideology": "", "personality": "balanced"}
	if _ai_profily.has(clean):
		return (_ai_profily[clean] as Dictionary)
	var created = _ai_vytvor_profil_pro_ideologii(_ziskej_ideologii_statu(clean))
	_ai_profily[clean] = created
	return created

# Fetches data for callers.
func ziskej_ai_profil_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `ziskej_ai_profil_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej ai profil statu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid state.", "profile": {}}
	return {
		"ok": true,
		"state": clean,
		"profile": (_ai_ziskej_profil(clean) as Dictionary).duplicate(true)
	}

# Updates state and keeps things in sync.
func nastav_ai_agresivitu_statu(state_tag: String, aggression_0_to_1: float) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `aggression_0_to_1`: Input argument used by `nastav_ai_agresivitu_statu` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `nastav_ai_agresivitu_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav ai agresivitu statu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid state."}

	var profile = _ai_ziskej_profil(clean)
	var old_aggression = float(profile.get("aggression", 0.5))
	var old_defense = float(profile.get("defense", 0.55))
	var new_aggression = clamp(aggression_0_to_1, 0.0, 1.0)

	# Keep behavior coherent: higher aggression generally means lower defensive bias.
	var target_defense = clamp(0.90 - new_aggression * 0.72, 0.20, 0.95)
	var blended_defense = clamp((old_defense * 0.30) + (target_defense * 0.70), 0.20, 0.95)

	profile["aggression"] = new_aggression
	profile["defense"] = blended_defense
	_ai_profily[clean] = profile

	_ai_debug("manual profile %s aggression %.2f->%.2f defense %.2f->%.2f" % [
		clean,
		old_aggression,
		new_aggression,
		old_defense,
		blended_defense
	])

	return {
		"ok": true,
		"state": clean,
		"profile": (profile as Dictionary).duplicate(true)
	}

# Sync update for linked values.
func nastav_globalni_ai_agresi(level: float) -> void:
	# Inputs:
	# - `level`: Input argument used by `nastav_globalni_ai_agresi` during execution.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `nastav_globalni_ai_agresi` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav globalni ai agresi` logic.
	# 3. Persist side effects and finish without a return value.
	_global_ai_aggression_level = clamp(level, 0.0, 1.0)
	# Re-bake all existing profiles so the new setting takes effect immediately.
	for tag in _ai_profily.keys():
		if je_lidsky_stat(str(tag)):
			continue
		var profile = _ai_profily[str(tag)] as Dictionary
		var base = float(profile.get("aggression", 0.5))
		profile["aggression"] = clampf(lerpf(base, _global_ai_aggression_level, 0.70), 0.0, 1.0)
		_ai_profily[str(tag)] = profile

# Core flow for this feature.
func _navrhni_neutocny_presun(state_tag: String, from_id: int, frontline_cache: Dictionary = {}, preferred_front_owner: String = "", staging_mode: bool = false) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_navrhni_neutocny_presun` during execution.
	# - `frontline_cache`: Input argument used by `_navrhni_neutocny_presun` during execution.
	# - `preferred_front_owner`: Input argument used by `_navrhni_neutocny_presun` during execution.
	# - `staging_mode`: Input argument used by `_navrhni_neutocny_presun` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_navrhni_neutocny_presun` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` navrhni neutocny presun` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 1400:
		return {}

	# Keep frontline stacks in place for attacks/defense phases.
	if _je_frontline_cached(state_tag, from_id, frontline_cache):
		return {}

	var best_target = -1
	var best_score = -INF
	for n_raw in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
		if n_owner != state_tag:
			continue

		var target_soldiers = int(_turn_soldiers_by_province.get(n_id, int(map_data[n_id].get("soldiers", 0))))
		var threatened = _je_frontline_cached(state_tag, n_id, frontline_cache)
		var front_link = false
		if preferred_front_owner != "":
			front_link = _ai_provincie_hranicni_k_targetu(state_tag, n_id, preferred_front_owner)
		var score = 0.0
		if threatened:
			score += 10000.0
		if front_link:
			score += 3200.0
		if staging_mode and not threatened and not front_link:
			score -= 1800.0
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

# Returns current runtime data.
func _ziskej_core_state(state_tag: String) -> String:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_ziskej_core_state` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej core state` logic.
	# 3. Persist side effects and return the computed `String` result.
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state_tag:
			continue
		if bool(d.get("is_capital", false)):
			return str(d.get("state", ""))
	return ""

# Reads values from active state.
func _ziskej_core_state_cached(state_tag: String) -> String:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_ziskej_core_state_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej core state cached` logic.
	# 3. Persist side effects and return the computed `String` result.
	if state_tag == "":
		return ""
	if _core_state_cache.has(state_tag):
		return str(_core_state_cache[state_tag])
	var core_state = _ziskej_core_state(state_tag)
	_core_state_cache[state_tag] = core_state
	return core_state

# Boolean check for required state.
func _je_core_provincie(state_tag: String, province_id: int, core_state: String) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_je_core_provincie` during execution.
	# - `core_state`: Input argument used by `_je_core_provincie` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_core_provincie` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je core provincie` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not map_data.has(province_id):
		return false
	var d = map_data[province_id]
	if _normalizuj_tag(str(_turn_owner_by_province.get(province_id, str(d.get("owner", ""))))) != state_tag:
		return false
	if bool(d.get("is_capital", false)):
		return true
	if core_state != "" and str(d.get("state", "")) == core_state:
		return true
	return false

# Handles this gameplay/UI path.
func _navrhni_core_obranu(state_tag: String, from_id: int, core_state: String = "", frontline_cache: Dictionary = {}) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_navrhni_core_obranu` during execution.
	# - `core_state`: Input argument used by `_navrhni_core_obranu` during execution.
	# - `frontline_cache`: Input argument used by `_navrhni_core_obranu` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_navrhni_core_obranu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` navrhni core obranu` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 1100:
		return {}

	if core_state == "":
		core_state = _ziskej_core_state_cached(state_tag)
	var best_target = -1
	var best_score = -INF
	for n_raw in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not _je_core_provincie(state_tag, n_id, core_state):
			continue
		var n_soldiers = int(_turn_soldiers_by_province.get(n_id, int(map_data[n_id].get("soldiers", 0))))
		var score = (2600.0 - float(n_soldiers))
		if bool(map_data[n_id].get("is_capital", false)):
			score += 2200.0
		if _je_frontline_cached(state_tag, n_id, frontline_cache):
			score += 1600.0
		score += min(1800.0, float(_spocitej_hrozbu_nepratel_u_provincie(n_id, state_tag)) * 0.25)
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

# Handles this gameplay/UI path.
func _navrhni_utok(state_tag: String, from_id: int, frontline_cache: Dictionary = {}, preferred_front_owner: String = "", coordinated_commitment: Dictionary = {}, strike_mode: bool = true) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_navrhni_utok` during execution.
	# - `frontline_cache`: Input argument used by `_navrhni_utok` during execution.
	# - `preferred_front_owner`: Input argument used by `_navrhni_utok` during execution.
	# - `coordinated_commitment`: Input argument used by `_navrhni_utok` during execution.
	# - `strike_mode`: Input argument used by `_navrhni_utok` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_navrhni_utok` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` navrhni utok` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci <= 700:
		return {}
	if not _je_frontline_cached(state_tag, from_id, frontline_cache) and not _ai_ma_namorni_prilezitost(state_tag, from_id, ""):
		return {}

	var best_target = -1
	var best_score = -INF
	var best_amount = 0
	var own_capital_id = _ziskej_hlavni_mesto_statu(state_tag)
	var profile = _ai_ziskej_profil(state_tag)
	var mindset = _ai_ziskej_mindset(state_tag)
	var goal = _ai_ziskej_strategicky_cil(state_tag)
	var aggression = float(profile.get("aggression", 0.5))
	var unpredictability = float(profile.get("unpredictability", 0.3))
	var attack_bias = float(mindset.get("attack_bias", 0.5))
	var defense_bias = float(mindset.get("defense_bias", 0.5))
	var goal_target = _normalizuj_tag(str(goal.get("target", "")))
	var goal_type = str(goal.get("type", "none"))
	var from_is_sea = _je_more_provincie(from_id)
	var reserve = max(360, int(float(vojaci) * (0.40 - aggression * 0.15 + defense_bias * 0.10 - attack_bias * 0.08)))
	if from_is_sea:
		reserve = max(220, int(float(reserve) * 0.65))
	var max_attack = vojaci - reserve
	if max_attack < 280:
		return {}

	# Hard override: fleets adjacent to enemy capitals should not idle.
	if from_is_sea:
		var forced_capital_target := -1
		var forced_capital_defenders := 0
		for n_raw_forced in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
			var n_id_forced = int(n_raw_forced)
			if not map_data.has(n_id_forced):
				continue
			if _je_more_provincie(n_id_forced):
				continue
			var n_prov_forced = map_data[n_id_forced]
			var n_owner_forced = _normalizuj_tag(str(_turn_owner_by_province.get(n_id_forced, str(n_prov_forced.get("owner", "")))))
			if n_owner_forced == "" or n_owner_forced == "SEA" or n_owner_forced == state_tag:
				continue
			if not bool(n_prov_forced.get("is_capital", false)):
				continue
			if not _jsou_ve_valce_ai_cached(state_tag, n_owner_forced):
				continue
			var defenders = int(_turn_soldiers_by_province.get(n_id_forced, int(n_prov_forced.get("soldiers", 0))))
			if forced_capital_target == -1 or defenders < forced_capital_defenders:
				forced_capital_target = n_id_forced
				forced_capital_defenders = defenders

		if forced_capital_target != -1:
			var forced_amount = min(max_attack, int(float(vojaci) * 0.94))
			forced_amount = max(420, forced_amount)
			forced_amount = min(forced_amount, vojaci - 120)
			if forced_amount > 0:
				# Keep only a tiny sea garrison; capital strike has absolute priority.
				return {
					"from": from_id,
					"to": forced_capital_target,
					"amount": forced_amount
				}

	for n_raw in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_prov = map_data[n_id]
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(n_prov.get("owner", "")))))
		if n_owner == "SEA":
			# Consider embarking when sea tile offers access to valuable enemy coast.
			if not _je_more_provincie(n_id):
				continue
			if not _je_more_provincie(from_id):
				if not je_pobrezni_provincie(from_id) or not provincie_ma_pristav(from_id):
					continue
			var landing_best := -INF
			for coast_raw in (n_prov.get("neighbors", []) as Array):
				var coast_id = int(coast_raw)
				if not map_data.has(coast_id) or _je_more_provincie(coast_id):
					continue
				var coast_owner = _normalizuj_tag(str(_turn_owner_by_province.get(coast_id, str(map_data[coast_id].get("owner", "")))))
				if coast_owner == "" or coast_owner == "SEA" or coast_owner == state_tag:
					continue
				var preferred_match = preferred_front_owner != "" and coast_owner == _normalizuj_tag(preferred_front_owner)
				if not _jsou_ve_valce_ai_cached(state_tag, coast_owner) and _je_pratelsky_vztah_ai_cached(state_tag, coast_owner) and attack_bias < 0.72:
					continue
				var coast_data = map_data[coast_id]
				var coast_score = float(coast_data.get("gdp", 0.0)) * 18.0 + float(int(coast_data.get("recruitable_population", 0))) * 0.03
				if bool(coast_data.get("is_capital", false)):
					coast_score += 3200.0
				if _normalizuj_tag(str(coast_data.get("core_owner", ""))) == state_tag:
					coast_score += 1800.0
				if preferred_match:
					coast_score += 900.0
				var rel_sea = _ziskej_ai_vztah_cached(state_tag, coast_owner)
				coast_score += clamp(-rel_sea, 0.0, 100.0) * 8.0
				landing_best = max(landing_best, coast_score)

			if landing_best == -INF:
				continue

			var embark_amount = min(max_attack, int(float(vojaci) * (0.70 if strike_mode else 0.56)))
			if embark_amount < 260:
				continue
			var sea_score = 420.0 + (landing_best * 0.60) + (220.0 * attack_bias) - (110.0 * defense_bias)
			if sea_score > best_score:
				best_score = sea_score
				best_target = n_id
				best_amount = embark_amount
			continue
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner) and attack_bias < 0.72:
			continue

		var n_vojaci = int(_turn_soldiers_by_province.get(n_id, int(n_prov.get("soldiers", 0))))
		var target_is_capital = bool(n_prov.get("is_capital", false))
		var island_capital_assault = from_is_sea and target_is_capital
		var threat_after_capture = _spocitej_hrozbu_nepratel_u_provincie(n_id, state_tag)
		var needed_for_push = int(float(n_vojaci) * lerpf(1.14, 0.78, attack_bias)) + int(float(threat_after_capture) * lerpf(0.14, 0.04, attack_bias))
		if island_capital_assault:
			needed_for_push = int(float(n_vojaci) * 0.92)
		var attack_amount = min(max_attack, int(float(vojaci) * 0.78))
		if not strike_mode:
			attack_amount = min(attack_amount, int(float(vojaci) * 0.62))
		if island_capital_assault:
			attack_amount = min(max_attack, int(float(vojaci) * 0.90))
		var source_threat = _spocitej_hrozbu_nepratel_u_provincie(from_id, state_tag)
		var remaining_after = vojaci - attack_amount
		# Do not overextend from threatened source provinces.
		if (not island_capital_assault) and source_threat > int(float(max(1, remaining_after)) * 1.45):
			if not (goal_type == "reclaim_core" and goal_target != "" and n_owner == goal_target):
				continue
		# Protect capital garrison unless this is a direct reclaim objective.
		if from_id == own_capital_id and remaining_after < max(700, int(float(source_threat) * 0.85)):
			if not (goal_type == "reclaim_core" and goal_target != "" and n_owner == goal_target):
				continue
		var overwhelming = float(vojaci) / float(max(1, n_vojaci)) >= lerpf(4.8, 1.7, attack_bias)
		if attack_amount < max(320, needed_for_push) and not overwhelming:
			if not island_capital_assault:
				continue
		if island_capital_assault and attack_amount < max(380, int(float(n_vojaci) * 0.95)):
			continue

		# Attrition awareness: avoid captures that cannot be held after combat.
		var hold_after_capture = max(0.0, float(attack_amount) - float(n_vojaci) * 0.65)
		var hold_need = float(threat_after_capture) * 0.55
		if bool(n_prov.get("is_capital", false)):
			hold_need += 550.0
		if hold_after_capture < hold_need and not overwhelming:
			if island_capital_assault:
				pass
			else:
				if not (goal_type == "reclaim_core" and goal_target != "" and n_owner == goal_target):
					continue

		var score = 0.0
		score += float(attack_amount - n_vojaci) * 1.2
		score -= float(threat_after_capture) * 0.30
		var rel = _ziskej_ai_vztah_cached(state_tag, n_owner)
		score += clamp(-rel, 0.0, 100.0) * 12.0
		score += float(n_prov.get("gdp", 0.0)) * 16.0
		score += float(int(n_prov.get("recruitable_population", 0))) * 0.02
		if target_is_capital:
			score += 3600.0
		if island_capital_assault:
			score += 5200.0
			score += clamp(float(attack_amount - n_vojaci), -4000.0, 4000.0) * 0.35
		if n_id == own_capital_id and n_owner != state_tag:
			score += 16000.0
		if _normalizuj_tag(str(n_prov.get("core_owner", ""))) == state_tag:
			score += 2600.0
		var enemy_core = _ziskej_core_state_cached(n_owner)
		if enemy_core != "" and str(n_prov.get("state", "")) == enemy_core:
			score += 900.0
		score += randf_range(-220.0, 220.0) * unpredictability
		score += 240.0 * attack_bias
		score -= 140.0 * defense_bias
		if preferred_front_owner != "" and _normalizuj_tag(n_owner) == _normalizuj_tag(preferred_front_owner):
			score += 900.0
		var owner_focus_key = "owner:" + _normalizuj_tag(n_owner)
		var prov_focus_key = "prov:" + str(n_id)
		score += float(int(coordinated_commitment.get(owner_focus_key, 0))) * 180.0
		score += float(int(coordinated_commitment.get(prov_focus_key, 0))) * 140.0
		if goal_target != "" and n_owner == goal_target:
			score += 1800.0
			if goal_type == "reclaim_core" and _normalizuj_tag(str(n_prov.get("core_owner", ""))) == state_tag:
				score += 2200.0

		if score > best_score:
			best_score = score
			best_target = n_id
			best_amount = attack_amount

	if best_target == -1:
		return {}
	if best_score < lerpf(260.0, -160.0, attack_bias):
		return {}

	return {
		"from": from_id,
		"to": best_target,
		"amount": best_amount
	}

# Ai generated or editted start (priloha_a.txt)
func _navrhni_namorni_presun(state_tag: String, from_id: int, preferred_front_owner: String = "") -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_navrhni_namorni_presun` during execution.
	# - `preferred_front_owner`: Input argument used by `_navrhni_namorni_presun` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_navrhni_namorni_presun` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` navrhni namorni presun` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not map_data.has(from_id):
		return {}
	if _je_more_provincie(from_id):
		return {}
	if not je_pobrezni_provincie(from_id):
		return {}
	if not provincie_ma_pristav(from_id):
		return {}

	var from_data = map_data[from_id]
	var army_owner = _normalizuj_tag(str(from_data.get("army_owner", "")))
	if army_owner != "" and army_owner != state_tag:
		return {}

	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 700:
		return {}

	var best_sea = -1
	var best_score = -INF
	for n_raw in (from_data.get("neighbors", []) as Array):
		var sea_id = int(n_raw)
		if not map_data.has(sea_id):
			continue
		if not _je_more_provincie(sea_id):
			continue

		var sea_army_owner = _normalizuj_tag(str(map_data[sea_id].get("army_owner", "")))
		if sea_army_owner != "" and sea_army_owner != state_tag and not _jsou_ve_valce_ai_cached(state_tag, sea_army_owner):
			continue

		var landing_best := -INF
		for coast_raw in (map_data[sea_id].get("neighbors", []) as Array):
			var coast_id = int(coast_raw)
			if not map_data.has(coast_id) or _je_more_provincie(coast_id):
				continue
			var coast_owner = _normalizuj_tag(str(_turn_owner_by_province.get(coast_id, str(map_data[coast_id].get("owner", "")))))
			if coast_owner == "" or coast_owner == "SEA" or coast_owner == state_tag:
				continue
			var preferred_match = preferred_front_owner != "" and coast_owner == _normalizuj_tag(preferred_front_owner)
			if not _jsou_ve_valce_ai_cached(state_tag, coast_owner) and _je_pratelsky_vztah_ai_cached(state_tag, coast_owner):
				continue

			var coast_data = map_data[coast_id]
			var local_score = float(coast_data.get("gdp", 0.0)) * 14.0 + float(int(coast_data.get("recruitable_population", 0))) * 0.02
			if bool(coast_data.get("is_capital", false)):
				local_score += 2600.0
			if _normalizuj_tag(str(coast_data.get("core_owner", ""))) == state_tag:
				local_score += 1400.0
			if preferred_match:
				local_score += 850.0
			landing_best = max(landing_best, local_score)

		if landing_best == -INF:
			continue

		var sea_score = 320.0 + landing_best
		if sea_army_owner == state_tag:
			sea_score += 180.0
		if sea_score > best_score:
			best_score = sea_score
			best_sea = sea_id

	if best_sea == -1:
		return {}

	var amount = min(int(float(vojaci) * 0.64), vojaci - 380)
	if amount < 240:
		return {}

	return {
		"from": from_id,
		"to": best_sea,
		"amount": amount
	}

# Ai generated or editted end (priloha_a.txt)
func nastav_potato_mode(enabled: bool) -> void:
	# Inputs:
	# - `enabled`: Behavior flag that toggles a conditional path.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `nastav_potato_mode` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav potato mode` logic.
	# 3. Persist side effects and finish without a return value.
	_potato_mode_enabled = enabled

# Sync update for linked values.
func nastav_spectate_mode(_enabled: bool) -> void:
	# Inputs:
	# - `enabled`: Behavior flag that toggles a conditional path.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `nastav_spectate_mode` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav spectate mode` logic.
	# 3. Persist side effects and finish without a return value.
	_spectate_mode_active = false
	if _normalizuj_tag(hrac_stat) == "" or _normalizuj_tag(hrac_stat) == "SPECTATE":
		hrac_stat = "ALB"
	if lokalni_hraci_staty.is_empty():
		lokalni_hraci_staty = [_normalizuj_tag(hrac_stat)]
	aktivni_hrac_index = clampi(aktivni_hrac_index, 0, max(0, lokalni_hraci_staty.size() - 1))

# Returns current runtime data.
func je_spectate_mode_aktivni() -> bool:
	# Inputs:
	# - none.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `je_spectate_mode_aktivni` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `je spectate mode aktivni` logic.
	# 3. Persist side effects and return the computed `bool` result.
	return false

# Sync update for linked values.
func nastav_ai_debug_mode(enabled: bool) -> void:
	# Inputs:
	# - `enabled`: Behavior flag that toggles a conditional path.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `nastav_ai_debug_mode` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `nastav ai debug mode` logic.
	# 3. Persist side effects and finish without a return value.
	_ai_debug_mode_enabled = enabled
	if not enabled:
		_debug_turn_live_events.clear()

# Eligibility/guard check.
func je_ai_debug_mode_zapnuty() -> bool:
	# Inputs:
	# - none.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `je_ai_debug_mode_zapnuty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `je ai debug mode zapnuty` logic.
	# 3. Persist side effects and return the computed `bool` result.
	return _ai_debug_mode_enabled

# Reads values from active state.
func ziskej_debug_historii_tahu(limit: int = 6) -> Array:
	# Inputs:
	# - `limit`: Numeric cap controlling how many items are processed.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `ziskej_debug_historii_tahu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `ziskej debug historii tahu` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var capped = clampi(limit, 1, DEBUG_TURN_HISTORY_MAX)
	if _debug_turn_history.is_empty():
		return []
	var from_idx = max(0, _debug_turn_history.size() - capped)
	return _debug_turn_history.slice(from_idx, _debug_turn_history.size())

# Read-only data accessor.
func ziskej_ai_debug_snapshot(state_tag: String = "") -> Dictionary:
	var clean = _normalizuj_tag(state_tag)
	if clean == "":
		clean = _normalizuj_tag(hrac_stat)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid state."}

	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	if owned.is_empty():
		for p_id in map_data:
			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("owner", ""))) == clean:
				owned.append(int(p_id))

	var enemies: Array = []
	for other_any in _ziskej_aktivni_staty():
		var other = _normalizuj_tag(str(other_any))
		if other == "" or other == clean or other == "SEA":
			continue
		if jsou_ve_valce(clean, other):
			enemies.append(other)
	var at_war = not enemies.is_empty()
	var pressure = _ai_spocitej_tlak_statu(clean, owned)
	var exhaustion = _ai_spocitej_war_exhaustion(clean)
	var treasury = _ziskej_kasu_statu(clean)
	var finance_breakdown = ziskej_financni_rozpad_statu(clean)
	var net_income = float(finance_breakdown.get("cashflow", finance_breakdown.get("profit", _spocitej_cisty_prijem_statu(clean))))
	var profit_income = float(finance_breakdown.get("profit", net_income))
	var goal = _ai_ziskej_strategicky_cil(clean)
	var op_plan = _ai_ziskej_operacni_plan(clean)
	var profile = _ai_ziskej_profil(clean)
	var recruit_targets = _ai_ziskej_recruit_kandidaty(clean, owned, pressure)
	var spend = _ai_debug_last_spending_by_state.get(clean, {}) as Dictionary
	var naval_ready := 0
	var naval_ports := 0
	for p_any in owned:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		if _je_more_provincie(p_id):
			continue
		if not je_pobrezni_provincie(p_id):
			continue
		if not provincie_ma_pristav(p_id):
			continue
		naval_ports += 1
		if _ai_ma_namorni_prilezitost(clean, p_id, _normalizuj_tag(str(op_plan.get("target", "")))):
			naval_ready += 1

	return {
		"ok": true,
		"state": clean,
		"is_player": je_lidsky_stat(clean),
		"turn": aktualni_kolo,
		"treasury": treasury,
		"net_income": net_income,
		"profit_income": profit_income,
		"at_war": at_war,
		"enemies": enemies,
		"pressure": pressure,
		"exhaustion": exhaustion,
		"goal_type": str(goal.get("type", "none")),
		"goal_target": _normalizuj_tag(str(goal.get("target", ""))),
		"plan_phase": str(op_plan.get("phase", "staging")),
		"plan_target": _normalizuj_tag(str(op_plan.get("target", ""))),
		"attack_bias": float(profile.get("attack_bias", 0.5)),
		"defense_bias": float(profile.get("defense_bias", 0.5)),
		"aggression": float(profile.get("aggression", 0.5)),
		"spend_recruit": float(spend.get("recruit", 0.0)),
		"spend_lab": float(spend.get("lab", 0.0)),
		"spend_build": float(spend.get("build", 0.0)),
		"spend_other": float(spend.get("other", 0.0)),
		"spend_total": float(spend.get("total", 0.0)),
		"naval_ports": naval_ports,
		"naval_ready": naval_ready,
		"recruit_targets": recruit_targets,
		"owned_provinces": owned.size(),
		"turn_profile": _debug_last_turn_profile.duplicate(true),
		"ai_profile": _debug_last_ai_profile.duplicate(true),
		"turn_history": ziskej_debug_historii_tahu(6)
	}
