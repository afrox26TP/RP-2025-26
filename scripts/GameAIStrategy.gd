extends "res://scripts/GameTurnFlow.gd"

## AI strategy, economy, recruitment, movement, war evaluation, and runtime caches.

func _ai_randomizuj_ideologie_a_profily(ai_staty: Array) -> void:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_randomizuj_ideologie_a_profily` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai randomizuj ideologie a profily` logic.
	# 3. Persist side effects and finish without a return value.
	if _ai_randomized_ideologies_applied:
		return
	if aktualni_kolo > 1:
		return

	var ideology_pool = IDEOLOGY_ECONOMIC_MODIFIERS.keys()
	if ideology_pool.is_empty():
		_ai_randomized_ideologies_applied = true
		return

	for tag_any in ai_staty:
		var tag = _normalizuj_tag(str(tag_any))
		if tag == "" or tag == "SEA":
			continue
		var original = _ziskej_ideologii_statu(tag)
		var picked = _normalizuj_ideologii(str(ideology_pool[randi_range(0, ideology_pool.size() - 1)]))
		if picked == "":
			picked = original

		# Keep a little continuity so every game is not fully chaotic.
		if randf() < 0.28:
			picked = original

		for p_id in map_data:
			if _normalizuj_tag(str(map_data[p_id].get("owner", ""))) != tag:
				continue
			map_data[p_id]["ideology"] = picked

		_ai_profily[tag] = _ai_vytvor_profil_pro_ideologii(picked)
		var prof = _ai_profily[tag] as Dictionary
		_ai_debug("profile seed %s ideology=%s aggr=%.2f def=%.2f rnd=%.2f" % [
			tag,
			picked,
			float(prof.get("aggression", 0.5)),
			float(prof.get("defense", 0.55)),
			float(prof.get("unpredictability", 0.3))
		])

	_ai_randomized_ideologies_applied = true

# Core flow for this feature.
func _ai_ziskej_nepratele_statu(state_tag: String) -> Array:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ai_ziskej_nepratele_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej nepratele statu` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "":
		return []
	if _ai_phase_cache_active and _ai_state_enemies_cache.has(clean):
		return (_ai_state_enemies_cache[clean] as Array).duplicate()
	var enemies: Dictionary = {}
	for key_any in valky.keys():
		var parts = str(key_any).split("_")
		if parts.size() != 2:
			continue
		var a = _normalizuj_tag(parts[0])
		var b = _normalizuj_tag(parts[1])
		if a == clean and b != "":
			enemies[b] = true
		elif b == clean and a != "":
			enemies[a] = true
	var out = enemies.keys()
	if _ai_phase_cache_active:
		_ai_state_enemies_cache[clean] = out.duplicate()
	return out

func _ai_sdili_nepritele_s(state_a: String, state_b: String) -> bool:
	# Inputs:
	# - `state_a`: Input argument used by `_ai_sdili_nepritele_s` during execution.
	# - `state_b`: Input argument used by `_ai_sdili_nepritele_s` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_sdili_nepritele_s` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai sdili nepritele s` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var enemies_a = _ai_ziskej_nepratele_statu(state_a)
	if enemies_a.is_empty():
		return false
	var enemies_b_dict: Dictionary = {}
	for e in _ai_ziskej_nepratele_statu(state_b):
		enemies_b_dict[_normalizuj_tag(str(e))] = true
	for e in enemies_a:
		if enemies_b_dict.has(_normalizuj_tag(str(e))):
			return true
	return false

func _ai_ziskej_mindset(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_ziskej_mindset` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej mindset` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {
			"attack_bias": 0.5,
			"defense_bias": 0.5,
			"risk": 0.5,
			"war_rel_bonus": 0.0,
			"local_ratio_shift": 0.0,
			"strategic_shift": 0.0
		}

	if _ai_mindset_cache.has(clean):
		return _ai_mindset_cache[clean] as Dictionary

	var profile = _ai_ziskej_profil(clean)
	var aggression = float(profile.get("aggression", 0.5))
	var defense = float(profile.get("defense", 0.55))
	var unpredictability = float(profile.get("unpredictability", 0.30))
	var personality = str(profile.get("personality", "balanced"))
	var attack_mod := 0.0
	var defense_mod := 0.0
	var risk_mod := 0.0
	match personality:
		"warlord":
			attack_mod = 0.14
			defense_mod = -0.10
			risk_mod = 0.12
		"expansionist":
			attack_mod = 0.10
			defense_mod = -0.05
			risk_mod = 0.08
		"fortress":
			attack_mod = -0.12
			defense_mod = 0.16
			risk_mod = -0.10
		"tactician":
			attack_mod = -0.02
			defense_mod = 0.10
			risk_mod = -0.02
		"planner":
			attack_mod = -0.04
			defense_mod = 0.08
			risk_mod = -0.05
		"opportunist":
			attack_mod = 0.06
			defense_mod = -0.02
			risk_mod = 0.14

	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	var frontline := 0
	var border_rivals: Dictionary = {}
	var total_threat := 0.0
	for p_any in owned:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		var is_frontline = _ma_nepratelskeho_souseda(clean, p_id)
		if is_frontline:
			frontline += 1
		total_threat += float(_spocitej_hrozbu_nepratel_u_provincie(p_id, clean))
		for n_raw in (_turn_neighbors_by_province.get(p_id, map_data[p_id].get("neighbors", [])) as Array):
			var n_id = int(n_raw)
			if not map_data.has(n_id):
				continue
			var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
			if n_owner == "" or n_owner == "SEA" or n_owner == clean:
				continue
			border_rivals[n_owner] = true

	var enemies = _ai_ziskej_nepratele_statu(clean)
	var own_power = float(max(1, _spocitej_silu_statu(clean)))
	var enemy_power := 0.0
	for e in enemies:
		enemy_power += float(max(1, _spocitej_silu_statu(_normalizuj_tag(str(e)))))
	var war_pressure = enemy_power / own_power if enemy_power > 0.0 else 0.0

	var avg_threat = total_threat / float(max(1, owned.size()))
	var pressure = clamp(avg_threat / 2400.0, 0.0, 1.0)
	var frontline_ratio = float(frontline) / float(max(1, owned.size()))
	var treasury = _ziskej_kasu_statu(clean)
	var gdp = max(1.0, _spocitej_hdp_statu(clean))
	var economy_health = clamp(treasury / (gdp * 0.10), -0.6, 1.8)

	var attack_bias = clamp(
		aggression * 0.58 +
		(1.0 - defense) * 0.16 +
		(1.0 - pressure) * 0.24 +
		(1.0 - frontline_ratio) * 0.12 +
		clamp(economy_health, 0.0, 1.0) * 0.16 -
		clamp(war_pressure - 1.0, 0.0, 1.0) * 0.26 +
		attack_mod,
		0.05,
		0.98
	)

	var defense_bias = clamp(
		defense * 0.62 +
		pressure * 0.34 +
		frontline_ratio * 0.24 +
		clamp(war_pressure - 1.0, 0.0, 1.2) * 0.25 +
		defense_mod,
		0.05,
		0.98
	)

	# Fast crisis reaction around capital.
	var cap_id = _ziskej_hlavni_mesto_statu(clean)
	if cap_id > 0 and _ma_nepratelskeho_souseda(clean, cap_id):
		defense_bias = clamp(defense_bias + 0.18, 0.05, 0.98)
		attack_bias = clamp(attack_bias - 0.10, 0.05, 0.98)

	var risk = clamp(
		aggression * 0.44 + unpredictability * 0.36 + attack_bias * 0.26 - defense_bias * 0.18 + risk_mod,
		0.05,
		0.98
	)

	var mindset := {
		"attack_bias": attack_bias,
		"defense_bias": defense_bias,
		"risk": risk,
		"war_rel_bonus": (attack_bias - 0.50) * 52.0,
		"local_ratio_shift": (attack_bias - defense_bias) * -0.36,
		"strategic_shift": (attack_bias - defense_bias) * -0.26
	}

	_ai_mindset_cache[clean] = mindset
	return mindset

func _ai_ziskej_strategicky_cil(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_ziskej_strategicky_cil` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej strategicky cil` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"type": "none", "target": "", "expires_turn": aktualni_kolo}

	if _ai_goal_cache.has(clean):
		var cached = _ai_goal_cache[clean] as Dictionary
		var expires_turn = int(cached.get("expires_turn", -1))
		var target_cached = _normalizuj_tag(str(cached.get("target", "")))
		if expires_turn >= aktualni_kolo and (target_cached == "" or _turn_state_owned_provinces.has(target_cached)):
			return cached

	var mindset = _ai_ziskej_mindset(clean)
	var attack_bias = float(mindset.get("attack_bias", 0.5))
	var defense_bias = float(mindset.get("defense_bias", 0.5))

	var neighbors: Dictionary = {}
	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	for p_any in owned:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		for n_raw in (_turn_neighbors_by_province.get(p_id, map_data[p_id].get("neighbors", [])) as Array):
			var n_id = int(n_raw)
			if not map_data.has(n_id):
				continue
			var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
			if n_owner == "" or n_owner == "SEA" or n_owner == clean:
				continue
			neighbors[n_owner] = true

	var best_goal := {"type": "none", "target": "", "score": -INF}
	var own_power = float(max(1, _spocitej_silu_statu(clean)))

	for target_any in neighbors.keys():
		var target = _normalizuj_tag(str(target_any))
		if target == "":
			continue

		var rel = _ziskej_ai_vztah_cached(clean, target)
		var target_power = float(max(1, _spocitej_silu_statu(target)))
		var power_ratio = own_power / target_power
		var border = _spocitej_silu_na_hranici(clean, target)
		var border_ratio = float(int(border.get("our", 0))) / float(max(1, int(border.get("enemy", 0))))

		var reclaim_bonus := 0.0
		for p_id in map_data:
			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("core_owner", ""))) != clean:
				continue
			if _normalizuj_tag(str(d.get("owner", ""))) != target:
				continue
			reclaim_bonus += 1.0

		var war_now = _jsou_ve_valce_ai_cached(clean, target)
		var score = attack_bias * 120.0 + clamp(-rel, 0.0, 100.0) * 1.7 + border_ratio * 80.0 + power_ratio * 90.0
		score += reclaim_bonus * 320.0
		if war_now:
			score += 240.0
		if _ziskej_uroven_aliance_ai_cached(clean, target) > ALLIANCE_NONE:
			score -= 220.0
		if _ma_neagresivni_smlouvu_ai_cached(clean, target):
			score -= 180.0
		score -= defense_bias * 90.0

		var goal_type = "expand_border"
		if reclaim_bonus >= 1.0:
			goal_type = "reclaim_core"
		elif war_now and power_ratio >= 0.95:
			goal_type = "break_rival"

		if score > float(best_goal.get("score", -INF)):
			best_goal = {"type": goal_type, "target": target, "score": score}

	var out = {
		"type": str(best_goal.get("type", "none")),
		"target": _normalizuj_tag(str(best_goal.get("target", ""))),
		"expires_turn": aktualni_kolo + AI_GOAL_RETARGET_TURNS,
		"retarget_lock_until": aktualni_kolo + AI_GOAL_RETARGET_TURNS + (abs(hash(clean)) % (AI_GOAL_RETARGET_JITTER_MAX + 1)),
		"created_turn": aktualni_kolo,
		"stagnation": 0,
		"last_signature": {}
	}
	_ai_goal_cache[clean] = out
	return out

# Runs the local feature logic.
func _ai_goal_signature(owner_tag: String, target_tag: String) -> Dictionary:
	# Inputs:
	# - `owner_tag`: State tag handled by this function.
	# - `target_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_goal_signature` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai goal signature` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var goal_owner = _normalizuj_tag(owner_tag)
	var target = _normalizuj_tag(target_tag)
	var owner_owned := 0
	var owner_cores_held_by_target := 0
	var target_cores_held_by_owner := 0

	if goal_owner == "" or target == "" or goal_owner == target:
		return {
			"owner_owned": owner_owned,
			"owner_cores_held_by_target": owner_cores_held_by_target,
			"target_cores_held_by_owner": target_cores_held_by_owner,
			"border_ratio": 0.0,
			"power_ratio": 0.0
		}

	for p_id in map_data:
		var d = map_data[p_id]
		var owner_now = _normalizuj_tag(str(d.get("goal_owner", "")))
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_now)))
		if owner_now == goal_owner:
			owner_owned += 1
		if owner_now == target and core_owner == goal_owner:
			owner_cores_held_by_target += 1
		if owner_now == goal_owner and core_owner == target:
			target_cores_held_by_owner += 1

	var border = _spocitej_silu_na_hranici(goal_owner, target)
	var border_ratio = float(int(border.get("our", 0))) / float(max(1, int(border.get("enemy", 0))))
	var power_ratio = float(max(1, _spocitej_silu_statu(goal_owner))) / float(max(1, _spocitej_silu_statu(target)))
	return {
		"owner_owned": owner_owned,
		"owner_cores_held_by_target": owner_cores_held_by_target,
		"target_cores_held_by_owner": target_cores_held_by_owner,
		"border_ratio": border_ratio,
		"power_ratio": power_ratio
	}

# Runs the local feature logic.
func _ai_aktualizuj_goal_progres(state_tag: String) -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_aktualizuj_goal_progres` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai aktualizuj goal progres` logic.
	# 3. Persist side effects and finish without a return value.
	var state_owner = _normalizuj_tag(state_tag)
	if state_owner == "" or not _ai_goal_cache.has(state_owner):
		return

	var goal = (_ai_goal_cache[state_owner] as Dictionary).duplicate(true)
	var target = _normalizuj_tag(str(goal.get("target", "")))
	if target == "":
		return

	var sig = _ai_goal_signature(state_owner, target)
	var prev = goal.get("last_signature", {}) as Dictionary
	var stagnation = int(goal.get("stagnation", 0))
	var retarget_lock_until = int(goal.get("retarget_lock_until", -1))
	var goal_age = aktualni_kolo - int(goal.get("created_turn", aktualni_kolo))

	if prev.is_empty():
		goal["last_signature"] = sig
		goal["stagnation"] = 0
		_ai_goal_cache[state_owner] = goal
		return

	var progress := false
	if int(sig.get("owner_owned", 0)) > int(prev.get("owner_owned", 0)):
		progress = true
	if int(sig.get("target_cores_held_by_owner", 0)) > int(prev.get("target_cores_held_by_owner", 0)):
		progress = true
	if int(sig.get("owner_cores_held_by_target", 0)) < int(prev.get("owner_cores_held_by_target", 0)):
		progress = true
	if float(sig.get("border_ratio", 0.0)) > float(prev.get("border_ratio", 0.0)) + 0.08:
		progress = true

	if progress:
		stagnation = 0
	else:
		stagnation += 1

	goal["stagnation"] = stagnation
	goal["last_signature"] = sig

	if stagnation >= AI_GOAL_STAGNATION_RETARGET and aktualni_kolo >= retarget_lock_until and goal_age >= AI_GOAL_MIN_AGE_FOR_STAGNATION_RETARGET:
		goal["expires_turn"] = aktualni_kolo - 1
		goal["retarget_lock_until"] = aktualni_kolo + AI_GOAL_RETARGET_TURNS
		_ai_debug("goal retarget %s reason=stagnation target=%s" % [state_owner, target])

	_ai_goal_cache[state_owner] = goal

# Core flow for this feature.
func _ai_spocitej_war_exhaustion(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_spocitej_war_exhaustion`.
	# Execution timing: Called when game flow invokes `_ai_spocitej_war_exhaustion` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai spocitej war exhaustion` logic.
	# 3. Persist side effects and return the computed `float` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return 0.0

	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	if owned.is_empty():
		# Fallback scan: turn cache can be transiently stale during movement slices.
		for p_id in map_data:
			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("owner", ""))) == clean:
				owned.append(int(p_id))
	if owned.is_empty():
		# Do not force a global panic if ownership data is temporarily unavailable.
		return float(_ai_war_exhaustion_cache.get(clean, 0.25))

	var own_power = float(max(1, _spocitej_silu_statu(clean)))
	var enemies = _ai_ziskej_nepratele_statu(clean)
	var enemy_power := 0.0
	for e in enemies:
		enemy_power += float(max(1, _spocitej_silu_statu(_normalizuj_tag(str(e)))))
	var war_pressure = enemy_power / own_power if enemy_power > 0.0 else 0.0
	var war_count_stress = clamp(float(max(0, enemies.size() - 1)) / 6.0, 0.0, 1.0)

	var frontline := 0
	for p_any in owned:
		if _ma_nepratelskeho_souseda(clean, int(p_any)):
			frontline += 1
	var frontline_ratio = float(frontline) / float(max(1, owned.size()))

	var treasury = _ziskej_kasu_statu(clean)
	var gdp = max(1.0, _spocitej_hdp_statu(clean))
	var eco_stress = clamp((0.04 - (treasury / gdp)) / 0.08, 0.0, 1.0)

	var goal = _ai_ziskej_strategicky_cil(clean)
	var stagnation = int(goal.get("stagnation", 0))
	var stagnation_stress = clamp(float(stagnation) / float(max(1, AI_GOAL_STAGNATION_RETARGET + 1)), 0.0, 1.0)

	var exhaustion = clamp(
		clamp((war_pressure - 1.10) / 3.0, 0.0, 1.0) * 0.32 +
		frontline_ratio * 0.24 +
		eco_stress * 0.20 +
		stagnation_stress * 0.11 +
		war_count_stress * 0.15,
		0.0,
		0.92
	)
	if enemies.is_empty():
		exhaustion = min(exhaustion, 0.35)
	_ai_war_exhaustion_cache[clean] = exhaustion
	return exhaustion

func _ai_ziskej_operacni_plan(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_ziskej_operacni_plan` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej operacni plan` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"target": "", "phase": "staging", "updated_turn": aktualni_kolo}

	if _ai_operation_plan_cache.has(clean):
		var cached = _ai_operation_plan_cache[clean] as Dictionary
		if int(cached.get("updated_turn", -1)) == aktualni_kolo:
			return cached

	var goal = _ai_ziskej_strategicky_cil(clean)
	var target = _normalizuj_tag(str(goal.get("target", "")))
	if target == "":
		var fallback_front = _ai_ziskej_primarni_front(clean)
		target = _normalizuj_tag(str(fallback_front.get("target", "")))
	if target == "" and _ai_operation_plan_cache.has(clean):
		# Keep last known target for continuity if this turn cannot resolve one.
		var prev_plan = _ai_operation_plan_cache[clean] as Dictionary
		target = _normalizuj_tag(str(prev_plan.get("target", "")))
	var exhaustion = _ai_spocitej_war_exhaustion(clean)
	var phase := "staging"

	if _ai_operation_plan_cache.has(clean):
		var prev = _ai_operation_plan_cache[clean] as Dictionary
		var prev_target = _normalizuj_tag(str(prev.get("target", "")))
		var prev_phase = str(prev.get("phase", "staging"))
		var prev_turn = int(prev.get("updated_turn", -1))
		if prev_target == target and target != "" and prev_turn == aktualni_kolo - 1 and exhaustion < 0.80:
			phase = "strike" if prev_phase == "staging" else "staging"
		elif prev_target == target and prev_turn >= aktualni_kolo - 1 and exhaustion < 0.72:
			phase = prev_phase

	if exhaustion >= 0.80:
		phase = "staging"

	var out = {
		"target": target,
		"phase": phase,
		"updated_turn": aktualni_kolo
	}
	_ai_operation_plan_cache[clean] = out
	_ai_debug("op plan %s phase=%s target=%s exhaustion=%.2f" % [
		clean,
		phase,
		target if target != "" else "-",
		exhaustion
	])
	return out

# Handles this gameplay/UI path.
func _ai_je_blizko_fronty(state_tag: String, province_id: int, frontline_cache: Dictionary) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_ai_je_blizko_fronty` during execution.
	# - `frontline_cache`: Input argument used by `_ai_je_blizko_fronty` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_je_blizko_fronty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai je blizko fronty` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not map_data.has(province_id):
		return false
	for n_raw in (_turn_neighbors_by_province.get(province_id, map_data[province_id].get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
		if n_owner != _normalizuj_tag(state_tag):
			continue
		if _je_frontline_cached(state_tag, n_id, frontline_cache):
			return true
	return false

# Ai generated or editted start (priloha_a.txt)
func _ai_urci_roli_jednotky(state_tag: String, province_id: int, own_capital_id: int, frontline_cache: Dictionary) -> String:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_ai_urci_roli_jednotky` during execution.
	# - `own_capital_id`: Input argument used by `_ai_urci_roli_jednotky` during execution.
	# - `frontline_cache`: Input argument used by `_ai_urci_roli_jednotky` during execution.
	# Outputs:
	# - `String`: Normalized text value returned by this helper.
	# Execution timing: Called when game flow invokes `_ai_urci_roli_jednotky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai urci roli jednotky` logic.
	# 3. Persist side effects and return the computed `String` result.
	if not map_data.has(province_id):
		return "reserve"
	if province_id == own_capital_id:
		return "anchor"

	var soldiers = int(_turn_soldiers_by_province.get(province_id, int(map_data[province_id].get("soldiers", 0))))
	var frontline = _je_frontline_cached(state_tag, province_id, frontline_cache)
	var is_sea = _je_more_provincie(province_id)
	if frontline:
		# Naval stacks must not idle in staging forever; allow earlier breakout.
		if is_sea and soldiers >= 900:
			return "breaker"
		if soldiers >= 1700:
			return "breaker"
		return "holder"

	if _ai_je_blizko_fronty(state_tag, province_id, frontline_cache):
		if soldiers >= 1400:
			return "holder"
		return "reserve"

	return "reserve"

# Ai generated or editted end (priloha_a.txt)
func _ai_provincie_hranicni_k_targetu(state_tag: String, province_id: int, target_owner: String) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_ai_provincie_hranicni_k_targetu` during execution.
	# - `target_owner`: Input argument used by `_ai_provincie_hranicni_k_targetu` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_provincie_hranicni_k_targetu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai provincie hranicni k targetu` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var state_owner = _normalizuj_tag(state_tag)
	var target = _normalizuj_tag(target_owner)
	if state_owner == "" or target == "" or state_owner == target or not map_data.has(province_id):
		return false
	if _normalizuj_tag(str(_turn_owner_by_province.get(province_id, str(map_data[province_id].get("state_owner", ""))))) != state_owner:
		return false
	for n_raw in (_turn_neighbors_by_province.get(province_id, map_data[province_id].get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("state_owner", "")))))
		if n_owner == target:
			return true
	return false

# Ai generated or editted start (priloha_a.txt)
func _ai_provincie_hranicni_k_neprateli(state_tag: String, province_id: int, enemies_set: Dictionary) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_ai_provincie_hranicni_k_neprateli` during execution.
	# - `enemies_set`: Input argument used by `_ai_provincie_hranicni_k_neprateli` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_provincie_hranicni_k_neprateli` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai provincie hranicni k neprateli` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if enemies_set.is_empty() or not map_data.has(province_id):
		return false
	for enemy_any in enemies_set.keys():
		var enemy_tag = _normalizuj_tag(str(enemy_any))
		if enemy_tag == "":
			continue
		if _ai_provincie_hranicni_k_targetu(state_tag, province_id, enemy_tag):
			return true
	return false

# Ai generated or editted end (priloha_a.txt)
func _ai_stat_ma_hranici_s_neprateli(state_tag: String, owned: Array, enemies_set: Dictionary) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_stat_ma_hranici_s_neprateli` during execution.
	# - `enemies_set`: Input argument used by `_ai_stat_ma_hranici_s_neprateli` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_stat_ma_hranici_s_neprateli` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai stat ma hranici s neprateli` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if enemies_set.is_empty():
		return false
	for p_any in owned:
		var p_id = int(p_any)
		if p_id < 0:
			continue
		if _ai_provincie_hranicni_k_neprateli(state_tag, p_id, enemies_set):
			return true
	return false

# Handles this gameplay/UI path.
func _ai_ziskej_primarni_front(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_ziskej_primarni_front` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej primarni front` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"target": "", "score": -INF}

	var goal = _ai_ziskej_strategicky_cil(clean)
	var goal_target = _normalizuj_tag(str(goal.get("target", "")))
	if goal_target != "":
		return {"target": goal_target, "score": 9999.0}

	var profile = _ai_ziskej_profil(clean)
	var aggression = float(profile.get("aggression", 0.5))
	var candidates: Dictionary = {}
	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	if owned.is_empty():
		for p_id in map_data:
			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("owner", ""))) == clean:
				owned.append(int(p_id))
	for p_any in owned:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		for n_raw in (_turn_neighbors_by_province.get(p_id, map_data[p_id].get("neighbors", [])) as Array):
			var n_id = int(n_raw)
			if not map_data.has(n_id):
				continue
			var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
			if n_owner == "" or n_owner == "SEA" or n_owner == clean:
				continue
			candidates[n_owner] = true

	var best_target := ""
	var best_score := -INF
	for t_any in candidates.keys():
		var t = _normalizuj_tag(str(t_any))
		if t == "":
			continue
		var border = _spocitej_silu_na_hranici(clean, t)
		var border_ratio = float(int(border.get("our", 0))) / float(max(1, int(border.get("enemy", 0))))
		var rel = _ziskej_ai_vztah_cached(clean, t)
		var in_war = _jsou_ve_valce_ai_cached(clean, t)
		var score = border_ratio * 70.0 + clamp(-rel, 0.0, 100.0) * 1.5 + aggression * 60.0
		if in_war:
			score += 180.0
		if score > best_score:
			best_score = score
			best_target = t

	return {"target": best_target, "score": best_score}

# Handles this gameplay/UI path.
func _ai_ziskej_recruit_kandidaty(state_tag: String, owned: Array, pressure: float) -> Array:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_ziskej_recruit_kandidaty` during execution.
	# - `pressure`: Input argument used by `_ai_ziskej_recruit_kandidaty` during execution.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_ai_ziskej_recruit_kandidaty` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej recruit kandidaty` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var scored: Array = []
	var cap_id = _ziskej_hlavni_mesto_statu(state_tag)
	var profile = _ai_ziskej_profil(state_tag)
	var mindset = _ai_ziskej_mindset(state_tag)
	var goal = _ai_ziskej_strategicky_cil(state_tag)
	var primary_front = _ai_ziskej_primarni_front(state_tag)
	var defense = float(profile.get("defense", 0.55))
	var aggression = float(profile.get("aggression", 0.50))
	var attack_bias = float(mindset.get("attack_bias", 0.5))
	var exhaustion = _ai_spocitej_war_exhaustion(state_tag)
	var goal_target = _normalizuj_tag(str(goal.get("target", "")))
	var front_target = _normalizuj_tag(str(primary_front.get("target", "")))
	var enemies = _ai_ziskej_nepratele_statu(state_tag)
	var at_war = not enemies.is_empty()
	var enemy_set: Dictionary = {}
	for e_any in enemies:
		var e_tag = _normalizuj_tag(str(e_any))
		if e_tag != "":
			enemy_set[e_tag] = true
	var has_enemy_border = _ai_stat_ma_hranici_s_neprateli(state_tag, owned, enemy_set)
	var base_threat_gate = 170 if at_war else 420
	var min_local_recruits = 30 if at_war else 120
	var front_anchor_candidates := 0

	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		var recruits = int(d.get("recruitable_population", 0))
		if recruits <= min_local_recruits:
			continue
		var is_capital = bool(d.get("is_capital", false)) or p_id == cap_id
		var is_frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
		var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
		var focused_front = false
		var enemy_front_contact = false
		if goal_target != "" or front_target != "":
			for n_raw in (_turn_neighbors_by_province.get(p_id, d.get("neighbors", [])) as Array):
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if n_owner == "" or n_owner == "SEA" or n_owner == state_tag:
					continue
				if enemy_set.has(n_owner):
					enemy_front_contact = true
				if n_owner == goal_target or n_owner == front_target:
					focused_front = true
					break
		else:
			for n_raw in (_turn_neighbors_by_province.get(p_id, d.get("neighbors", [])) as Array):
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if enemy_set.has(n_owner):
					enemy_front_contact = true
					break

		# Strict wartime mode: if enemy border exists, recruit only there.
		# If there is no direct enemy border (overseas war / distant enemy), use staging fronts.
		if at_war:
			if has_enemy_border and not enemy_front_contact:
				continue
			if not has_enemy_border and not focused_front and not is_frontline and threat < 200:
				continue
		# Avoid recruiting everywhere: in peacetime low-threat areas recruit only if strategic anchor exists.
		if (not at_war) and not is_capital and not is_frontline and not focused_front and not enemy_front_contact and threat < base_threat_gate:
			continue
		var score = 0.0
		if is_capital and not at_war:
			score += 3000.0
		if is_frontline:
			score += 1800.0
		if focused_front:
			score += 1300.0
		if enemy_front_contact:
			score += 1600.0
		if focused_front and enemy_front_contact:
			score += 700.0
		score += min(2100.0, float(threat) * (0.24 + attack_bias * 0.10))
		score += float(recruits) * 0.12
		score += float(d.get("gdp", 0.0)) * 14.0 * aggression
		score += (320.0 * defense) if is_capital else 0.0
		score -= exhaustion * 220.0
		if is_frontline or focused_front or enemy_front_contact:
			front_anchor_candidates += 1
		scored.append({
			"id": p_id,
			"score": score,
			"anchor": (is_capital or is_frontline or focused_front or enemy_front_contact)
		})

	if scored.is_empty():
		if at_war:
			# Emergency fallback for war states: take strategic anchors even with low local recruitment pools.
			for p_id_any in owned:
				var p_id = int(p_id_any)
				if not map_data.has(p_id):
					continue
				var d = map_data[p_id]
				var recruits = int(d.get("recruitable_population", 0))
				if recruits <= 20:
					continue
				var is_frontline_fallback = _ma_nepratelskeho_souseda(state_tag, p_id)
				var enemy_front_fallback = _ai_provincie_hranicni_k_neprateli(state_tag, p_id, enemy_set)
				if enemy_front_fallback or is_frontline_fallback:
					return [p_id]
		return []

	scored.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	var war_pressure = 1.0 if not at_war else 1.30
	var pressure_factor = clamp(pressure / 1800.0, 0.0, 1.0)
	var fraction = clamp(0.18 + (pressure_factor * 0.20) + (defense * 0.10) + (attack_bias * 0.10), 0.16, 0.62)
	fraction *= war_pressure
	fraction = clamp(fraction, 0.16, 0.70)
	var max_targets = 3
	if at_war:
		max_targets = 6
	if pressure_factor >= 0.55:
		max_targets += 1
	if attack_bias >= 0.70:
		max_targets += 1
	if exhaustion >= 0.70:
		max_targets = max(2, max_targets - 1)
	var keep_n = clampi(int(ceil(float(scored.size()) * fraction)), 1, min(max_targets, scored.size()))
	if at_war and scored.size() >= 2:
		keep_n = max(2, keep_n)
	if at_war and pressure_factor >= 0.45 and scored.size() >= 3:
		keep_n = max(3, keep_n)
	if at_war and scored.size() >= 4 and pressure_factor >= 0.20:
		keep_n = max(4, keep_n)
	if at_war and scored.size() >= 5 and pressure_factor < 0.20:
		keep_n = max(5, keep_n)
	var top_score = float((scored[0] as Dictionary).get("score", 0.0))

	var out: Array = []
	for i in range(min(keep_n, scored.size())):
		var row = scored[i] as Dictionary
		var s = float(row.get("score", 0.0))
		if i > 0 and s < max(top_score * 0.10, top_score - 5200.0):
			continue
		if at_war and front_anchor_candidates > 0 and not bool(row.get("anchor", false)):
			continue
		out.append(int(row.get("id", -1)))

	# Fallback: keep at least a few strategic anchors so recruitment can spread across orders.
	if at_war and out.size() < min(3, keep_n):
		for row_any in scored:
			if out.size() >= min(3, keep_n):
				break
			var row = row_any as Dictionary
			var pid = int(row.get("id", -1))
			if pid < 0 or out.has(pid):
				continue
			if not map_data.has(pid):
				continue
			var d = map_data[pid]
			var is_capital_fallback = bool(d.get("is_capital", false)) or pid == cap_id
			var is_frontline_fallback = _ma_nepratelskeho_souseda(state_tag, pid)
			var threat_fallback = _spocitej_hrozbu_nepratel_u_provincie(pid, state_tag)
			if is_capital_fallback or is_frontline_fallback or threat_fallback >= 180:
				out.append(pid)

	# Rear fallback: when war has low local frontier pressure, allow high-recruit interior provinces
	# so large states do not stall at targets=1 and end up with 0 spend despite large budgets.
	if at_war and front_anchor_candidates <= 0 and out.size() < min(max_targets, max(3, keep_n)):
		var rear_pool: Array = []
		for p_id_any in owned:
			var p_id = int(p_id_any)
			if p_id < 0 or out.has(p_id) or not map_data.has(p_id):
				continue
			var d = map_data[p_id]
			var recruits = int(d.get("recruitable_population", 0))
			if recruits < 80:
				continue
			var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
			var gdp = float(d.get("gdp", 0.0))
			rear_pool.append({"id": p_id, "recruits": recruits, "threat": threat, "gdp": gdp})
		rear_pool.sort_custom(func(a, b):
			var ra = a as Dictionary
			var rb = b as Dictionary
			var score_a = float(ra.get("recruits", 0)) * 1.0 + float(ra.get("threat", 0)) * 0.45 + float(ra.get("gdp", 0.0)) * 120.0
			var score_b = float(rb.get("recruits", 0)) * 1.0 + float(rb.get("threat", 0)) * 0.45 + float(rb.get("gdp", 0.0)) * 120.0
			return score_a > score_b
		)
		for row_any in rear_pool:
			if out.size() >= min(max_targets, max(3, keep_n) + 2):
				break
			out.append(int((row_any as Dictionary).get("id", -1)))
	if at_war and front_anchor_candidates > 0:
		var filtered: Array = []
		var filtered_front: Array = []
		var filtered_other: Array = []
		for pid_any in out:
			var pid = int(pid_any)
			if not map_data.has(pid):
				continue
			if _ai_provincie_hranicni_k_neprateli(state_tag, pid, enemy_set):
				filtered_front.append(pid)
			elif (front_target != "" and _ai_provincie_hranicni_k_targetu(state_tag, pid, front_target)) or (goal_target != "" and _ai_provincie_hranicni_k_targetu(state_tag, pid, goal_target)):
				filtered_front.append(pid)
			else:
				filtered_other.append(pid)
		filtered.append_array(filtered_front)
		# In wartime strict mode, do not pull interior provinces unless no frontline exists.
		if filtered.is_empty():
			for pid_any in filtered_other:
				var pid = int(pid_any)
				if not map_data.has(pid):
					continue
				var p_threat = _spocitej_hrozbu_nepratel_u_provincie(pid, state_tag)
				if p_threat >= 220:
					filtered.append(pid)
			if filtered.is_empty():
				filtered.append_array(filtered_other)
		if filtered.size() >= 2:
			var front_pressure_factor = clamp(pressure / 1800.0, 0.0, 1.0)
			var max_front_targets = 4
			if front_pressure_factor >= 0.35:
				max_front_targets += 1
			if front_pressure_factor >= 0.65:
				max_front_targets += 1
			max_front_targets = min(max_front_targets, filtered.size())
			return filtered.slice(0, max_front_targets)
	return out

# Runs the local feature logic.
func _ai_spocitej_tlak_statu(state_tag: String, owned: Array) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_spocitej_tlak_statu` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_spocitej_tlak_statu`.
	# Execution timing: Called when game flow invokes `_ai_spocitej_tlak_statu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai spocitej tlak statu` logic.
	# 3. Persist side effects and return the computed `float` result.
	var clean = _normalizuj_tag(state_tag)
	if _ai_phase_cache_active and _ai_state_pressure_cache.has(clean):
		return float(_ai_state_pressure_cache[clean])
	var total_threat := 0
	for p_id_any in owned:
		var p_id = int(p_id_any)
		total_threat += _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
	if owned.is_empty():
		return 0.0
	var value = float(total_threat) / float(max(1, owned.size()))
	if _ai_phase_cache_active and clean != "":
		_ai_state_pressure_cache[clean] = value
	return value

# Core flow for this feature.
func _ai_spocitej_recruit_pass_skore(state_tag: String, p_id: int, cap_id: int, war_focus_target: String, enemies_set: Dictionary, recruit_orders_in_province: int, at_war_state: bool) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `p_id`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# - `cap_id`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# - `war_focus_target`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# - `enemies_set`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# - `recruit_orders_in_province`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# - `at_war_state`: Input argument used by `_ai_spocitej_recruit_pass_skore` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_spocitej_recruit_pass_skore`.
	# Execution timing: Called when game flow invokes `_ai_spocitej_recruit_pass_skore` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai spocitej recruit pass skore` logic.
	# 3. Persist side effects and return the computed `float` result.
	if not map_data.has(p_id):
		return -INF
	var d = map_data[p_id]
	# score je schvalne slozenej z vic casti, at AI nespamuje jen jednu provincii dokola.
	var recruits = int(d.get("recruitable_population", 0))
	var local_soldiers = int(d.get("soldiers", 0))
	var core_owner = str(d.get("core_owner", state_tag)).strip_edges().to_upper()
	var occupied = core_owner != "" and core_owner != state_tag
	if occupied:
		recruits = int(floor(float(recruits) * 0.2))
	if recruits <= 0:
		return -INF

	var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
	var is_frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
	var is_capital = bool(d.get("is_capital", false)) or p_id == cap_id
	var enemy_front_contact = false
	var focused_front_contact = false
	for n_raw in (_turn_neighbors_by_province.get(p_id, d.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
		if n_owner == "" or n_owner == "SEA" or n_owner == state_tag:
			continue
		if enemies_set.has(n_owner):
			enemy_front_contact = true
		if war_focus_target != "" and n_owner == war_focus_target:
			focused_front_contact = true
	if war_focus_target == "" and enemy_front_contact:
		focused_front_contact = true
	if at_war_state and not enemy_front_contact:
		return -INF

	# cilovej garnizon je orientacni strop/spodek obrany; neni to hard limit.
	var desired_garrison = 950
	if is_frontline:
		desired_garrison = 1300
	if is_capital:
		desired_garrison = 2200
	desired_garrison += min(1400, int(float(threat) * 0.40))
	var deficit = max(0, desired_garrison - local_soldiers)

	var score = float(recruits) * 0.20
	score += float(threat) * 1.70
	score += float(deficit) * 2.60
	if focused_front_contact:
		score += 3200.0
	elif enemy_front_contact:
		score += 2300.0
	elif is_frontline:
		score += 1200.0
	if is_capital:
		score += 700.0 + min(800.0, float(threat) * 0.50)
	if at_war_state and (not is_frontline) and (not enemy_front_contact):
		score -= 1400.0
	if recruit_orders_in_province > 0:
		# jemnej anti-stack postih, aby se nabory rozlozily po fronte.
		score -= float(recruit_orders_in_province) * 1800.0
	return score

# Runs the local feature logic.
func _ai_ziskej_recruit_emergency_level(state_tag: String, owned: Array, at_war_state: bool, state_pressure: float, state_exhaustion: float) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_ziskej_recruit_emergency_level` during execution.
	# - `at_war_state`: Input argument used by `_ai_ziskej_recruit_emergency_level` during execution.
	# - `state_pressure`: Input argument used by `_ai_ziskej_recruit_emergency_level` during execution.
	# - `state_exhaustion`: Input argument used by `_ai_ziskej_recruit_emergency_level` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_ziskej_recruit_emergency_level`.
	# Execution timing: Called when game flow invokes `_ai_ziskej_recruit_emergency_level` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ziskej recruit emergency level` logic.
	# 3. Persist side effects and return the computed `float` result.
	if not at_war_state:
		return 0.0

	var enemies = _ai_ziskej_nepratele_statu(state_tag)
	if enemies.is_empty():
		return 0.0

	var own_power = float(max(1, _spocitej_silu_statu(state_tag)))
	var enemy_power := 0.0
	for e in enemies:
		enemy_power += float(max(1, _spocitej_silu_statu(_normalizuj_tag(str(e)))))
	var war_ratio = enemy_power / own_power if enemy_power > 0.0 else 0.0

	var frontline := 0
	for p_any in owned:
		if _ma_nepratelskeho_souseda(state_tag, int(p_any)):
			frontline += 1
	var frontline_ratio = float(frontline) / float(max(1, owned.size()))

	# mix vah drzi emergency stabilni i kdyz jeden vstup kratce vystreli.
	var level := 0.0
	level += clamp((war_ratio - 1.10) / 1.25, 0.0, 1.0) * 0.46
	level += clamp((state_pressure - AI_RECRUIT_EMERGENCY_PRESSURE) / 900.0, 0.0, 1.0) * 0.24
	level += clamp((state_exhaustion - AI_RECRUIT_EMERGENCY_EXHAUSTION) / 0.30, 0.0, 1.0) * 0.20
	level += clamp((frontline_ratio - 0.28) / 0.42, 0.0, 1.0) * 0.10
	return clamp(level, 0.0, 1.0)

# Ai generated or editted start (priloha_a.txt)
func _ai_odhad_dostupnych_rekrutu(state_tag: String, owned: Array, recruit_targets: Array, at_war_state: bool) -> int:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_odhad_dostupnych_rekrutu` during execution.
	# - `recruit_targets`: Input argument used by `_ai_odhad_dostupnych_rekrutu` during execution.
	# - `at_war_state`: Input argument used by `_ai_odhad_dostupnych_rekrutu` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ai_odhad_dostupnych_rekrutu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai odhad dostupnych rekrutu` logic.
	# 3. Persist side effects and return the computed `int` result.
	var used: Dictionary = {}
	var pool: Array = []
	for p_any in recruit_targets:
		var pid = int(p_any)
		if pid < 0 or used.has(pid):
			continue
		used[pid] = true
		pool.append(pid)
	if pool.is_empty():
		for p_any in owned:
			var pid = int(p_any)
			if pid < 0 or used.has(pid):
				continue
			used[pid] = true
			pool.append(pid)

	var soft_floor = 20 if at_war_state else 120
	var available := 0
	# soft floor chrani zakladni pool provincie, at ji AI nevyzere na nulu hned.
	for p_any in pool:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		var recruits = int(d.get("recruitable_population", 0))
		var core_owner = str(d.get("core_owner", state_tag)).strip_edges().to_upper()
		var occupied = core_owner != "" and core_owner != state_tag
		if occupied:
			recruits = int(floor(float(recruits) * 0.2))
		if recruits <= 0:
			continue
		var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
		var is_front = _ma_nepratelskeho_souseda(state_tag, p_id)
		var is_cap = bool(d.get("is_capital", false)) or p_id == _ziskej_hlavni_mesto_statu(state_tag)
		var local_floor = soft_floor
		if at_war_state and (is_front or is_cap or threat >= 180):
			local_floor = int(floor(float(soft_floor) * 0.5))
		available += max(0, recruits - local_floor)

	if available > 0:
		return available

	# Last-resort estimate: if strict floor leaves nothing, allow minimal draw from raw pools.
	# nouzovka: radsi male naborove cislo nez total freeze celeho statu.
	var raw_available := 0
	for p_any in pool:
		var p_id = int(p_any)
		if not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		var recruits = int(d.get("recruitable_population", 0))
		var core_owner = str(d.get("core_owner", state_tag)).strip_edges().to_upper()
		if core_owner != "" and core_owner != state_tag:
			recruits = int(floor(float(recruits) * 0.2))
		raw_available += max(0, recruits)
	return raw_available

# Ai generated or editted start (priloha_a.txt)
func _ai_odhad_max_rekrutu_na_tah(state_tag: String, recruit_targets: Array, recruit_order_cap: int, at_war_state: bool, state_pressure: float, recruit_spend_cap: float, emergency_level: float = 0.0) -> int:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `recruit_targets`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# - `recruit_order_cap`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# - `at_war_state`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# - `state_pressure`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# - `recruit_spend_cap`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# - `emergency_level`: Input argument used by `_ai_odhad_max_rekrutu_na_tah` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ai_odhad_max_rekrutu_na_tah` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai odhad max rekrutu na tah` logic.
	# 3. Persist side effects and return the computed `int` result.
	if recruit_targets.is_empty() or recruit_order_cap <= 0:
		return 0

	var cap_id = _ziskej_hlavni_mesto_statu(state_tag)
	var threshold = 220
	if at_war_state:
		threshold = 40
	if state_pressure >= 900.0:
		threshold = min(threshold, 30)
	if at_war_state and recruit_spend_cap >= 220.0:
		threshold = min(threshold, 25)
	if emergency_level > 0.0:
		threshold = min(threshold, int(round(lerp(12.0, 0.0, clamp(emergency_level, 0.0, 1.0)))))

	# remaining/per_order_caps je dvoufazovy model: kolik jde vzit a kolik najednou poslat.
	var remaining: Dictionary = {}
	var per_order_caps: Dictionary = {}
	for p_any in recruit_targets:
		var p_id = int(p_any)
		if p_id < 0 or not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		var recruits = int(d.get("recruitable_population", 0))
		var local_soldiers = int(d.get("soldiers", 0))
		var core_owner = str(d.get("core_owner", state_tag)).strip_edges().to_upper()
		var occupied = core_owner != "" and core_owner != state_tag
		if occupied:
			recruits = int(floor(float(recruits) * 0.2))

		var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
		var frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
		var is_capital = bool(d.get("is_capital", false)) or p_id == cap_id
		var desired_garrison = 950
		if frontline:
			desired_garrison = 1300
		if is_capital:
			desired_garrison = 2200
		desired_garrison += min(1400, int(float(threat) * 0.40))
		if not frontline and threat < 260 and local_soldiers >= desired_garrison:
			var skip_safe = true
			if at_war_state:
				var war_overgarrison_limit = int(float(desired_garrison) * 2.0)
				skip_safe = state_pressure < 220.0 and local_soldiers >= war_overgarrison_limit
			if skip_safe:
				continue

		var available = max(0, recruits - threshold)
		if available <= 0:
			continue
		var per_order_cap = 850
		if frontline:
			per_order_cap += 550
		if is_capital:
			per_order_cap += 650
		per_order_cap += min(950, int(float(threat) * 0.22))
		if occupied:
			per_order_cap = int(max(120, floor(float(per_order_cap) * 0.30)))
		if recruit_targets.size() <= 2 and recruit_order_cap >= 4:
			per_order_cap = int(float(per_order_cap) * 1.75)
		elif recruit_targets.size() == 3 and recruit_order_cap >= 5:
			per_order_cap = int(float(per_order_cap) * 1.35)
		if emergency_level > 0.0:
			per_order_cap = int(float(per_order_cap) * (1.0 + emergency_level * 0.90))
		var per_order_hard_cap = int(round(3600.0 + (2200.0 * clamp(emergency_level, 0.0, 1.0))))
		per_order_cap = min(per_order_hard_cap, per_order_cap)

		remaining[p_id] = available
		per_order_caps[p_id] = per_order_cap

	if remaining.is_empty():
		return 0

	# greedy pass: bere zatim nejlepsi moznej take, je to rychly a v praxi staci.
	var recruited_units := 0
	for _slot in range(recruit_order_cap):
		var best_pid := -1
		var best_take := 0
		for pid_any in remaining.keys():
			var pid = int(pid_any)
			var left = int(remaining.get(pid, 0))
			if left <= 0:
				continue
			var take = min(left, int(per_order_caps.get(pid, 0)))
			if take > best_take:
				best_take = take
				best_pid = pid
		if best_pid < 0 or best_take <= 0:
			break
		recruited_units += best_take
		remaining[best_pid] = int(remaining.get(best_pid, 0)) - best_take

	return recruited_units

# Ai generated or editted end (priloha_a.txt)
func _ai_vypocitej_hotovostni_rezervu(state_tag: String, owned: Array) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_vypocitej_hotovostni_rezervu` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_vypocitej_hotovostni_rezervu`.
	# Execution timing: Called when game flow invokes `_ai_vypocitej_hotovostni_rezervu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai vypocitej hotovostni rezervu` logic.
	# 3. Persist side effects and return the computed `float` result.
	var upkeep_total = _spocitej_naklady_udrzby_statu(state_tag)
	var pressure = _ai_spocitej_tlak_statu(state_tag, owned)
	var profile = _ai_ziskej_profil(state_tag)
	var defense_bias = float(profile.get("defense", 0.55))
	var reserve = AI_MIN_TREASURY_RESERVE * (0.9 + defense_bias * 0.6)
	reserve += upkeep_total * 2.5
	reserve += min(120.0, pressure * 0.008)
	return reserve

# Core flow for this feature.
func _ai_uprav_hotovostni_rezervu_pro_spending(_state_tag: String, reserve: float, treasury: float, at_war_state: bool, pressure: float) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `reserve`: Input argument used by `_ai_uprav_hotovostni_rezervu_pro_spending` during execution.
	# - `treasury`: Input argument used by `_ai_uprav_hotovostni_rezervu_pro_spending` during execution.
	# - `at_war_state`: Input argument used by `_ai_uprav_hotovostni_rezervu_pro_spending` during execution.
	# - `pressure`: Input argument used by `_ai_uprav_hotovostni_rezervu_pro_spending` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_uprav_hotovostni_rezervu_pro_spending`.
	# Execution timing: Called when game flow invokes `_ai_uprav_hotovostni_rezervu_pro_spending` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai uprav hotovostni rezervu pro spending` logic.
	# 3. Persist side effects and return the computed `float` result.
	if treasury <= 0.0:
		return 0.0

	var adjusted = max(0.0, reserve)
	var pressure_factor = clamp(pressure / 1800.0, 0.0, 1.0)
	var reserve_ratio_cap = 0.82
	if at_war_state:
		reserve_ratio_cap = 0.72 + (pressure_factor * 0.16)
	else:
		reserve_ratio_cap = 0.82 + (pressure_factor * 0.08)
	reserve_ratio_cap = clamp(reserve_ratio_cap, 0.60, 0.92)

	# Prevent reserve from scaling above a reasonable share of treasury.
	adjusted = min(adjusted, treasury * reserve_ratio_cap)

	# Wealthy states should always keep deployable cash so they do not stall.
	if treasury >= 800.0:
		# bohate staty musi mit vzdy kus volny kasy, jinak AI pusobi "zasekle".
		var spend_floor = max(180.0, treasury * (0.22 if at_war_state else 0.15))
		adjusted = min(adjusted, max(0.0, treasury - spend_floor))

	var min_guard = AI_MIN_TREASURY_RESERVE * (1.20 if at_war_state else 1.00)
	adjusted = max(min_guard, adjusted)
	return clamp(adjusted, 0.0, treasury)

# Ai generated or editted start (priloha_a.txt)
func _ai_skore_vyzkumu(state_tag: String, project: Dictionary, pressure: float, treasury: float) -> float:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `project`: Input argument used by `_ai_skore_vyzkumu` during execution.
	# - `pressure`: Input argument used by `_ai_skore_vyzkumu` during execution.
	# - `treasury`: Input argument used by `_ai_skore_vyzkumu` during execution.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ai_skore_vyzkumu`.
	# Execution timing: Called when game flow invokes `_ai_skore_vyzkumu` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai skore vyzkumu` logic.
	# 3. Persist side effects and return the computed `float` result.
	var mods = project.get("modifiers", {}) as Dictionary
	var cost = max(1.0, float(project.get("cost", 1.0)))
	var score := 0.0

	var profile = _ai_ziskej_profil(state_tag)
	var aggression = float(profile.get("aggression", 0.50))
	var defense = float(profile.get("defense", 0.55))
	var economy_bias = 1.30 if treasury < 120.0 else 1.0
	var military_bias = 1.25 if pressure >= 1200.0 else 1.0
	economy_bias *= (0.95 + (1.0 - aggression) * 0.25)
	military_bias *= (0.90 + defense * 0.30)

	if mods.has("income_rate_mult"):
		score += (float(mods.get("income_rate_mult", 1.0)) - 1.0) * 220.0 * economy_bias
	if mods.has("gdp_growth_mult"):
		score += (float(mods.get("gdp_growth_mult", 1.0)) - 1.0) * 230.0 * economy_bias
	if mods.has("upkeep_mult"):
		score += (1.0 - float(mods.get("upkeep_mult", 1.0))) * 260.0 * military_bias
	if mods.has("recruit_cost_mult"):
		score += (1.0 - float(mods.get("recruit_cost_mult", 1.0))) * 170.0 * military_bias
	if mods.has("recruit_regen_mult"):
		score += (float(mods.get("recruit_regen_mult", 1.0)) - 1.0) * 190.0 * military_bias
	if mods.has("population_growth_mult"):
		score += (float(mods.get("population_growth_mult", 1.0)) - 1.0) * 95.0

	# deleni cenou brzdi drahy projekty, co vypadaji hezky jen na papire.
	return score / cost

# Ai generated or editted end (priloha_a.txt)
func _ai_zvaz_vyzkum(state_tag: String, reserve: float, pressure: float) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `reserve`: Input argument used by `_ai_zvaz_vyzkum` during execution.
	# - `pressure`: Input argument used by `_ai_zvaz_vyzkum` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_zvaz_vyzkum` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai zvaz vyzkum` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not RESEARCH_PROJECTS_ENABLED:
		return false
	var treasury = _ziskej_kasu_statu(state_tag)
	if treasury <= reserve + 15.0:
		return false

	var research_state = ziskej_vyzkum_statu(state_tag)
	if not bool(research_state.get("ok", false)):
		return false

	var projects = research_state.get("projects", []) as Array
	var best_id := ""
	var best_score := -INF
	for p_any in projects:
		var p = p_any as Dictionary
		if bool(p.get("done", false)):
			continue
		var pid = str(p.get("id", "")).strip_edges()
		if pid == "":
			continue
		var cost = float(p.get("cost", 0.0))
		if treasury - cost < reserve * 0.90:
			continue
		var score = _ai_skore_vyzkumu(state_tag, p, pressure, treasury)
		if score > best_score:
			best_score = score
			best_id = pid

	if best_id == "":
		_ai_debug("research skip %s treasury=%.2f reserve=%.2f pressure=%.1f" % [state_tag, treasury, reserve, pressure])
		return false

	var result = proved_vyzkum_projektu(state_tag, best_id)
	if bool(result.get("ok", false)):
		_ai_debug("research buy %s project=%s treasury_after=%.2f" % [
			state_tag,
			best_id,
			float(result.get("treasury_after", _ziskej_kasu_statu(state_tag)))
		])
	return bool(result.get("ok", false))

# Handles this gameplay/UI path.
func _ai_stat_ma_pristav(owned: Array) -> bool:
	# Inputs:
	# - `owned`: Input argument used by `_ai_stat_ma_pristav` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_stat_ma_pristav` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai stat ma pristav` logic.
	# 3. Persist side effects and return the computed `bool` result.
	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		if bool(map_data[p_id].get("has_port", false)):
			return true
	return false

# Core flow for this feature.
func _ai_spocitej_core_defense_ohrozeni(state_tag: String, owned: Array) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_spocitej_core_defense_ohrozeni` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ai_spocitej_core_defense_ohrozeni` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai spocitej core defense ohrozeni` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var clean = _normalizuj_tag(state_tag)
	if _ai_phase_cache_active and _ai_state_core_defense_cache.has(clean):
		return (_ai_state_core_defense_cache[clean] as Dictionary).duplicate(true)
	var capital_id = _ziskej_hlavni_mesto_statu(state_tag)
	var threatened_core_count := 0
	var max_core_threat := 0
	var capital_threat := 0
	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("core_owner", state_tag))) != state_tag:
			continue
		var local_threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
		var frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
		var is_capital = bool(d.get("is_capital", false)) or p_id == capital_id
		var local_threshold = 220 if is_capital else 340
		if local_threat >= local_threshold or (frontline and local_threat >= 140):
			threatened_core_count += 1
		if local_threat > max_core_threat:
			max_core_threat = local_threat
		if is_capital:
			capital_threat = local_threat
	var out = {
		"threatened_core_count": threatened_core_count,
		"max_core_threat": max_core_threat,
		"capital_threat": capital_threat
	}
	if _ai_phase_cache_active and clean != "":
		_ai_state_core_defense_cache[clean] = out.duplicate(true)
	return out

func _ai_zvaz_stavby(state_tag: String, owned: Array, reserve: float, pressure: float) -> int:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `owned`: Input argument used by `_ai_zvaz_stavby` during execution.
	# - `reserve`: Input argument used by `_ai_zvaz_stavby` during execution.
	# - `pressure`: Input argument used by `_ai_zvaz_stavby` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ai_zvaz_stavby` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai zvaz stavby` logic.
	# 3. Persist side effects and return the computed `int` result.
	var built := 0
	if owned.is_empty():
		return built
	var at_war = not _ai_ziskej_nepratele_statu(state_tag).is_empty()
	var core_threat = _ai_spocitej_core_defense_ohrozeni(state_tag, owned)
	var threatened_core_count = int(core_threat.get("threatened_core_count", 0))
	var max_core_threat = int(core_threat.get("max_core_threat", 0))
	var capital_threat = int(core_threat.get("capital_threat", 0))
	var severe_defense_mode = at_war and (capital_threat >= 340 or pressure >= 1400.0 or (threatened_core_count >= 3 and max_core_threat >= 450))
	# severe mode je schvalne prisny: preziti statu ma prednost pred ekonomikou.
	if severe_defense_mode:
		_ai_debug("build hold %s reason=core_defense threatened=%d max_threat=%d pressure=%.1f" % [
			state_tag,
			threatened_core_count,
			max_core_threat,
			pressure
		])

	var has_port = _ai_stat_ma_pristav(owned)
	var profile = _ai_ziskej_profil(state_tag)
	var defense = float(profile.get("defense", 0.55))
	var aggression = float(profile.get("aggression", 0.50))
	var initial_budget = max(0.0, _ziskej_kasu_statu(state_tag) - reserve)
	var max_builds_this_turn = AI_BUILD_MAX_PER_TURN + int(floor(initial_budget / 220.0))
	if at_war:
		max_builds_this_turn = min(max_builds_this_turn, 2)
	else:
		max_builds_this_turn = min(max_builds_this_turn, 6)
	max_builds_this_turn = max(1, max_builds_this_turn)
	var used: Dictionary = {}
	for _i in range(max_builds_this_turn):
		var treasury = _ziskej_kasu_statu(state_tag)
		var budget = treasury - reserve
		if budget < AI_BUILDING_COST_ECON:
			break

		var best_pid := -1
		var best_building := ""
		var best_cost := 0.0
		var best_score := -INF

		for p_id_any in owned:
			var p_id = int(p_id_any)
			if not map_data.has(p_id):
				continue
			if used.has(p_id):
				continue
			if provincie_cooldowny.has(p_id):
				continue

			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("owner", ""))) != state_tag:
				continue
			var buildings = _ziskej_buildings_provincie(p_id)
			var gdp = float(d.get("gdp", 0.0))
			var pop = int(d.get("population", 0))
			var recruits = int(d.get("recruitable_population", 0))
			var is_frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
			var local_threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
			var is_capital = bool(d.get("is_capital", false))

			if budget >= AI_BUILDING_COST_ECON and int(buildings.get(BUILDING_ID_ECON_HUB, 0)) < int((BUILDING_DEFS[BUILDING_ID_ECON_HUB] as Dictionary).get("max_level", 1)):
				if at_war and is_frontline:
					continue
				if severe_defense_mode:
					continue
				var score_econ = gdp * 14.0 * (1.05 - defense * 0.2)
				score_econ *= (1.05 + (1.0 - aggression) * 0.20)
				if at_war:
					score_econ *= 0.82
				if not is_frontline:
					score_econ += 120.0
				if score_econ > best_score:
					best_score = score_econ
					best_pid = p_id
					best_building = BUILDING_ID_ECON_HUB
					best_cost = AI_BUILDING_COST_ECON

			if budget >= AI_BUILDING_COST_RECRUIT and int(buildings.get(BUILDING_ID_RECRUIT_CENTER, 0)) < int((BUILDING_DEFS[BUILDING_ID_RECRUIT_CENTER] as Dictionary).get("max_level", 1)):
				var score_recruit = float(recruits) * 0.09 + pressure * (0.014 + defense * 0.010)
				if is_frontline:
					score_recruit += 180.0
				if at_war:
					score_recruit += 120.0
				if score_recruit > best_score:
					best_score = score_recruit
					best_pid = p_id
					best_building = BUILDING_ID_RECRUIT_CENTER
					best_cost = AI_BUILDING_COST_RECRUIT

			if budget >= AI_BUILDING_COST_FARM and int(buildings.get(BUILDING_ID_FARM, 0)) < int((BUILDING_DEFS[BUILDING_ID_FARM] as Dictionary).get("max_level", 1)):
				if severe_defense_mode and is_frontline:
					continue
				var score_farm = gdp * 9.0 + float(recruits) * 0.04 + float(pop) * 0.0008
				score_farm *= (1.04 + (1.0 - aggression) * 0.22)
				if at_war:
					score_farm *= 0.75
				if not is_frontline:
					score_farm += 100.0
				if score_farm > best_score:
					best_score = score_farm
					best_pid = p_id
					best_building = BUILDING_ID_FARM
					best_cost = AI_BUILDING_COST_FARM

			if budget >= AI_BUILDING_COST_ARMY_BASE and int(buildings.get(BUILDING_ID_ARMY_BASE, 0)) < int((BUILDING_DEFS[BUILDING_ID_ARMY_BASE] as Dictionary).get("max_level", 1)):
				var score_base = float(recruits) * 0.08 + pressure * (0.013 + aggression * 0.012) + local_threat * 0.25
				score_base *= (1.0 + aggression * 0.16)
				if is_frontline:
					score_base += 170.0
				if at_war:
					score_base += 120.0
				if not at_war and not is_frontline:
					score_base -= 60.0
				if score_base > best_score:
					best_score = score_base
					best_pid = p_id
					best_building = BUILDING_ID_ARMY_BASE
					best_cost = AI_BUILDING_COST_ARMY_BASE

			if budget >= AI_BUILDING_COST_FORTRESS and int(buildings.get(BUILDING_ID_FORTRESS, 0)) < int((BUILDING_DEFS[BUILDING_ID_FORTRESS] as Dictionary).get("max_level", 1)):
				var score_fort = local_threat * 0.85 + pressure * 0.06
				if is_frontline:
					score_fort += 180.0
				if is_capital:
					score_fort += 190.0
				if severe_defense_mode:
					score_fort += 220.0
				if not at_war and not is_capital and local_threat < 150:
					score_fort -= 120.0
				if score_fort > best_score:
					best_score = score_fort
					best_pid = p_id
					best_building = BUILDING_ID_FORTRESS
					best_cost = AI_BUILDING_COST_FORTRESS

			if not has_port and budget >= AI_BUILDING_COST_PORT and muze_postavit_pristav(p_id):
				if severe_defense_mode:
					continue
				var score_port = 260.0 + (gdp * (6.0 + aggression * 4.0))
				if at_war:
					score_port -= 140.0
				if score_port > best_score:
					best_score = score_port
					best_pid = p_id
					best_building = BUILDING_ID_PORT
					best_cost = AI_BUILDING_COST_PORT

		if best_pid == -1 or best_building == "":
			break

		_nastav_kasu_statu(state_tag, treasury - best_cost)
		var bdef = _ziskej_building_def(best_building)
		var build_time = max(1, int(bdef.get("build_time", 3)))
		provincie_cooldowny[best_pid] = {"zbyva": build_time, "budova": best_building}
		_ai_debug("build start %s prov=%d type=%s cost=%.2f treasury_after=%.2f" % [
			state_tag,
			best_pid,
			best_building,
			best_cost,
			_ziskej_kasu_statu(state_tag)
		])
		used[best_pid] = true
		if best_building == BUILDING_ID_PORT:
			has_port = true
		built += 1

	return built

# Runs the local feature logic.
func _ai_zvaz_armadni_lab(state_tag: String, reserve: float) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `reserve`: Input argument used by `_ai_zvaz_armadni_lab` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_zvaz_armadni_lab` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai zvaz armadni lab` logic.
	# 3. Persist side effects and return the computed `bool` result.
	var profile = _ai_ziskej_profil(state_tag)
	var aggression = float(profile.get("aggression", 0.50))
	var treasury = _ziskej_kasu_statu(state_tag)
	if treasury < reserve + AI_ARM_LAB_MIN_SURPLUS * (0.9 + aggression * 0.4):
		return false

	var any_action := false
	var at_war = not _ai_ziskej_nepratele_statu(state_tag).is_empty()
	var surplus = max(0.0, treasury - reserve)
	var max_actions = 1 + int(floor(surplus / 140.0))
	if at_war:
		max_actions = min(max_actions, 2)
	else:
		max_actions = min(max_actions, 5)
	max_actions = max(1, max_actions)

	for _step in range(max_actions):
		treasury = _ziskej_kasu_statu(state_tag)
		if treasury <= reserve + 5.0:
			break
		var lab_state = ziskej_armadni_lab_statu(state_tag)
		if not bool(lab_state.get("ok", false)):
			break

		var did_action := false
		var base_army_power = float(max(1, _spocitej_silu_statu(state_tag)))
		var offers = lab_state.get("offers", []) as Array
		var best_idx := -1
		var best_score := -INF
		for i in range(offers.size()):
			var offer = offers[i] as Dictionary
			var cost = max(1.0, float(offer.get("cost", 1.0)))
			if treasury - cost < reserve:
				continue
			var projected = float(int(offer.get("power_flat", 0))) + float(offer.get("power_pct", 0.0)) * base_army_power
			var roi = projected / cost
			var score = projected * 0.55 + roi * 28.0
			if score > best_score:
				best_score = score
				best_idx = i

		if best_idx != -1:
			var buy_result = kup_armadni_nabidku(state_tag, best_idx)
			if bool(buy_result.get("ok", false)):
				_ai_debug("arm_lab buy %s offer=%d cost=%.2f treasury_after=%.2f" % [
					state_tag,
					best_idx,
					float(buy_result.get("cost", 0.0)),
					float(buy_result.get("treasury_after", _ziskej_kasu_statu(state_tag)))
				])
				did_action = true

		if not did_action:
			var quality_level = int(lab_state.get("quality_level", 0))
			var quality_cost = float(lab_state.get("quality_upgrade_cost", 0.0))
			if quality_level < 5 and treasury - quality_cost >= reserve + 20.0:
				var quality_result = vylepsi_kvalitu_dropu_armady(state_tag)
				if bool(quality_result.get("ok", false)):
					_ai_debug("arm_lab quality %s lvl=%d cost=%.2f treasury_after=%.2f" % [
						state_tag,
						int(quality_result.get("new_quality_level", quality_level + 1)),
						float(quality_result.get("cost", quality_cost)),
						float(quality_result.get("treasury_after", _ziskej_kasu_statu(state_tag)))
					])
					did_action = true

		if not did_action and bool(lab_state.get("can_expand", false)):
			var expand_cost = float(lab_state.get("expand_cost", 0.0))
			if treasury - expand_cost >= reserve + 20.0:
				var expand_result = rozsirit_armadni_mrizku(state_tag)
				if bool(expand_result.get("ok", false)):
					_ai_debug("arm_lab expand %s cost=%.2f treasury_after=%.2f" % [
						state_tag,
						expand_cost,
						_ziskej_kasu_statu(state_tag)
					])
					did_action = true

		if not did_action:
			break
		any_action = true

	return any_action

# AI logic

# Handles this gameplay/UI path.
func zpracuj_tah_ai():
	# Inputs:
	# - none.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `zpracuj_tah_ai`.
	# Execution timing: Called when game flow invokes `zpracuj_tah_ai` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core `zpracuj tah ai` logic.
	# 3. Persist side effects and return the computed `value` result.
	if TURN_LOG_ENABLED:
		print("--- AI THINKING START ---")
	var ai_start_ms = Time.get_ticks_msec()
	var ai_phase_ms = ai_start_ms
	var ai_phases := {
		"setup": 0,
		"diplomacy": 0,
		"economy_recruit": 0,
		"movement": 0,
		"cleanup": 0
	}
	var ai_detail_profile := {
		"turn": aktualni_kolo,
		"states_total": 0,
		"states_processed": 0,
		"states_passive": 0,
		"total_ms": 0,
		"phases": {},
		"diplomacy": {
			"peace_eval_ms": 0,
			"non_aggression_ms": 0,
			"relation_ms": 0,
			"leave_alliance_ms": 0,
			"alliance_ms": 0,
			"skipped_potato": false
		},
		"economy": {
			"income_ms": 0,
			"prep_ms": 0,
			"recruit_ms": 0,
			"post_ms": 0,
			"top_states": []
		},
		"movement": {}
	}
	var ai_econ_income_ms := 0
	var ai_econ_prep_ms := 0
	var ai_econ_recruit_ms := 0
	var ai_econ_post_ms := 0
	var ai_econ_state_rows: Array = []
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return
	# AI phase starts from clean caches and a rebuilt turn cache snapshot.
	_core_state_cache.clear()
	_ai_phase_cache_active = false
	_ai_vycisti_runtime_cache()
	_rebuild_turn_cache()
	var ai_staty_all = _ziskej_ai_staty()
	_ai_randomizuj_ideologie_a_profily(ai_staty_all)
	var ai_staty = _vyber_ai_staty_pro_tah(ai_staty_all)
	# `war_states_processed` is used to enable light-war pass when too many wars run at once.
	var war_states_processed := 0
	for ai_tag_any in ai_staty:
		if not (_ai_ziskej_nepratele_statu(_normalizuj_tag(str(ai_tag_any))) as Array).is_empty():
			war_states_processed += 1
	ai_detail_profile["states_total"] = ai_staty_all.size()
	ai_detail_profile["states_processed"] = ai_staty.size()
	ai_detail_profile["states_passive"] = max(0, ai_staty_all.size() - ai_staty.size())
	if _ai_debug_mode_enabled and ai_staty.size() < ai_staty_all.size():
		_append_debug_turn_event("ai fastmode subset=%d/%d" % [ai_staty.size(), ai_staty_all.size()])
	var occupied_core_by_state: Dictionary = {}
	for p_id_any in map_data:
		var d_core = map_data[p_id_any]
		var owner_core = _normalizuj_tag(str(d_core.get("owner", "")))
		var core_owner = _normalizuj_tag(str(d_core.get("core_owner", owner_core)))
		if core_owner == "" or core_owner == "SEA":
			continue
		if owner_core == "" or owner_core == "SEA" or owner_core == core_owner:
			continue
		occupied_core_by_state[core_owner] = int(occupied_core_by_state.get(core_owner, 0)) + 1
	await get_tree().process_frame
	ai_phases["setup"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()
	_ai_phase_cache_active = true
	_set_defer_log_maintenance(true)

	# Evaluate pending peace offers before AI plans any attacks.
	var dip_stage_ms = Time.get_ticks_msec()
	_vyhodnot_mirove_nabidky_pred_ai()
	(ai_detail_profile["diplomacy"] as Dictionary)["peace_eval_ms"] = Time.get_ticks_msec() - dip_stage_ms
	dip_stage_ms = Time.get_ticks_msec()
	_vyhodnot_aliancni_zadosti_pred_ai()
	(ai_detail_profile["diplomacy"] as Dictionary)["alliance_ms"] = Time.get_ticks_msec() - dip_stage_ms
	await get_tree().process_frame
	
	# Skip diplomacy in potato mode for performance
	if not _potato_mode_enabled:
		dip_stage_ms = Time.get_ticks_msec()
		var zmeny_neagrese_k_hraci = _zpracuj_ai_neagresivni_smlouvy(ai_staty)
		(ai_detail_profile["diplomacy"] as Dictionary)["non_aggression_ms"] = Time.get_ticks_msec() - dip_stage_ms
		_zobraz_hlaseni_neagresivnich_smluv_hrace(zmeny_neagrese_k_hraci)
		await get_tree().process_frame
		dip_stage_ms = Time.get_ticks_msec()
		var zmeny_vztahu_k_hraci = _zpracuj_ai_diplomacii(ai_staty)
		(ai_detail_profile["diplomacy"] as Dictionary)["relation_ms"] = Time.get_ticks_msec() - dip_stage_ms
		_zobraz_hlaseni_vztahu_hrace(zmeny_vztahu_k_hraci)
		await get_tree().process_frame
		dip_stage_ms = Time.get_ticks_msec()
		var zmeny_opusteni_alianci = _zpracuj_ai_opusteni_alianci(ai_staty)
		(ai_detail_profile["diplomacy"] as Dictionary)["leave_alliance_ms"] = Time.get_ticks_msec() - dip_stage_ms
		_zobraz_hlaseni_opusteni_alianci_hrace(zmeny_opusteni_alianci)
		await get_tree().process_frame
		dip_stage_ms = Time.get_ticks_msec()
		var zmeny_alianci_k_hraci = _zpracuj_ai_aliance(ai_staty)
		(ai_detail_profile["diplomacy"] as Dictionary)["alliance_ms"] = int((ai_detail_profile["diplomacy"] as Dictionary).get("alliance_ms", 0)) + (Time.get_ticks_msec() - dip_stage_ms)
		_zobraz_hlaseni_alianci_hrace(zmeny_alianci_k_hraci)
		await get_tree().process_frame
	else:
		(ai_detail_profile["diplomacy"] as Dictionary)["skipped_potato"] = true
	
	_set_defer_log_maintenance(false)
	ai_phases["diplomacy"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()

	# Runtime cache mode remains enabled for economy and movement.
	_ai_vycisti_runtime_cache()
	# Precompute net income once per turn and reuse it in per-state loops.
	var ai_net_income_by_state = _ai_spocitej_ekonomicky_tok_statu_pro_tah(ai_staty_all)
	# States skipped by fast-mode still get passive economic tick, so they do not freeze.
	_ai_pripis_pasivni_ekonomiku_mimo_subset(ai_staty_all, ai_staty, ai_net_income_by_state)
		
	var ai_state_slice_counter := 0
	var war_light_states := 0

	for owner_tag_raw in ai_staty:
		var state_total_start_ms = Time.get_ticks_msec()
		var owner_tag = _normalizuj_tag(str(owner_tag_raw))
		if owner_tag == "":
			continue
		var owned = _turn_state_owned_provinces.get(owner_tag, []) as Array
		if owned.is_empty():
			continue

		if not ai_kasy.has(owner_tag):
			var ai_hdp = _spocitej_hdp_statu(owner_tag)
			ai_kasy[owner_tag] = ai_hdp * 0.05
		var treasury_before = _ziskej_kasu_statu(owner_tag)
		var enemies_state = _ai_ziskej_nepratele_statu(owner_tag)
		var at_war_state = not enemies_state.is_empty()

		_ai_zvaz_presun_hlavniho_mesta(owner_tag)
		var treasury_reserve_raw = _ai_vypocitej_hotovostni_rezervu(owner_tag, owned)
		var treasury_reserve = treasury_reserve_raw

		var income_gained_this_turn := 0.0
		var state_income_start_ms = Time.get_ticks_msec()
		if ai_net_income_by_state.has(owner_tag):
			income_gained_this_turn = float((ai_net_income_by_state[owner_tag] as Dictionary).get("net", 0.0))
		else:
			income_gained_this_turn = _spocitej_cisty_prijem_statu(owner_tag)
		ai_kasy[owner_tag] += income_gained_this_turn
		var ai_income_slice_counter := 0
		ai_income_slice_counter = await _turn_slice_wait(ai_income_slice_counter, TURN_FRAME_SLICE_AI_STATES)
		var state_income_ms = Time.get_ticks_msec() - state_income_start_ms
		ai_econ_income_ms += state_income_ms

		if ai_kasy[owner_tag] < -100.0:
			_vyres_bankrot(owner_tag)

		var state_pressure = _ai_spocitej_tlak_statu(owner_tag, owned)
		var core_defense_threat = _ai_spocitej_core_defense_ohrozeni(owner_tag, owned)
		var threatened_core_count = int(core_defense_threat.get("threatened_core_count", 0))
		var max_core_threat = int(core_defense_threat.get("max_core_threat", 0))
		var occupied_core_count = int(occupied_core_by_state.get(owner_tag, 0))
		var core_defense_lockdown = at_war_state and occupied_core_count > 0
		treasury_reserve = _ai_uprav_hotovostni_rezervu_pro_spending(owner_tag, treasury_reserve_raw, _ziskej_kasu_statu(owner_tag), at_war_state, state_pressure)
		if core_defense_lockdown:
			treasury_reserve = 0.0
		_ai_debug("reserve tune %s raw=%.2f adjusted=%.2f treasury=%.2f war=%s pressure=%.1f" % [
			owner_tag,
			treasury_reserve_raw,
			treasury_reserve,
			_ziskej_kasu_statu(owner_tag),
			str(at_war_state),
			state_pressure
		])
		var spend_build_this_turn := 0.0
		var spend_lab_this_turn := 0.0
		var war_light_pass = false
		# Light pass alternates war states by parity to reduce spikes in huge wars.
		if at_war_state and war_states_processed > AI_WAR_LIGHT_PASS_THRESHOLD:
			var parity_key = (aktualni_kolo + owner_tag.hash()) & 1
			war_light_pass = parity_key == 1
		if core_defense_lockdown:
			_ai_debug("core defense lockdown %s occupied_core=%d threatened_core=%d max_threat=%d" % [
				owner_tag,
				occupied_core_count,
				threatened_core_count,
				max_core_threat
			])
		elif war_light_pass:
			war_light_states += 1
			_ai_debug("war light-pass %s (full-econ skipped this turn)" % owner_tag)
		else:
			var research_actions = 1 + int(floor(max(0.0, _ziskej_kasu_statu(owner_tag) - treasury_reserve) / 260.0))
			if at_war_state:
				research_actions = min(research_actions, 1)
			else:
				research_actions = min(research_actions, 3)
			for _r in range(max(1, research_actions)):
				if not _ai_zvaz_vyzkum(owner_tag, treasury_reserve, state_pressure):
					break
			var treasury_before_build = _ziskej_kasu_statu(owner_tag)
			_ai_zvaz_stavby(owner_tag, owned, treasury_reserve, state_pressure)
			spend_build_this_turn = max(0.0, treasury_before_build - _ziskej_kasu_statu(owner_tag))
			var treasury_before_lab = _ziskej_kasu_statu(owner_tag)
			_ai_zvaz_armadni_lab(owner_tag, treasury_reserve)
			spend_lab_this_turn = max(0.0, treasury_before_lab - _ziskej_kasu_statu(owner_tag))

		var cena_za_vojaka = max(0.001, ziskej_cenu_za_vojaka(owner_tag))
		var state_prep_ms = Time.get_ticks_msec() - (state_income_start_ms + state_income_ms)
		ai_econ_prep_ms += state_prep_ms

		var recruit_targets = _ai_ziskej_recruit_kandidaty(owner_tag, owned, state_pressure)
		var state_exhaustion = _ai_spocitej_war_exhaustion(owner_tag)
		var state_mindset = _ai_ziskej_mindset(owner_tag)
		var state_attack_bias = float(state_mindset.get("attack_bias", 0.5))
		var strategic_goal = _ai_ziskej_strategicky_cil(owner_tag)
		var primary_front = _ai_ziskej_primarni_front(owner_tag)
		var goal_target = _normalizuj_tag(str(strategic_goal.get("target", "")))
		var front_target = _normalizuj_tag(str(primary_front.get("target", "")))
		var war_focus_target = front_target if front_target != "" else goal_target
		var enemies_set: Dictionary = {}
		for e_any in enemies_state:
			var e_tag = _normalizuj_tag(str(e_any))
			if e_tag != "":
				enemies_set[e_tag] = true
		var recruit_emergency_level = _ai_ziskej_recruit_emergency_level(owner_tag, owned, at_war_state, state_pressure, state_exhaustion)
		var frontline_crisis = at_war_state and (
			recruit_emergency_level >= 0.45
			or threatened_core_count > 0
			or occupied_core_count > 0
			or state_pressure >= 850.0
		)
		var recruit_spend_factor = 1.0
		var recruit_spend_cap = max(0.0, ai_kasy[owner_tag] - treasury_reserve)
		var recruit_order_cap = 2
		if at_war_state:
			recruit_order_cap = 4
		if state_pressure >= 950.0:
			recruit_order_cap += 1
		if state_attack_bias >= 0.70:
			recruit_order_cap += 1
		if at_war_state and threatened_core_count > 0:
			recruit_order_cap += 2
		if frontline_crisis:
			recruit_order_cap += 3
		# Large war economies can still under-spend with low order caps even at full order usage.
		# Scale the cap by budget and target breadth so majors can distribute recruitment better.
		if at_war_state:
			if recruit_spend_cap >= 120.0 and recruit_targets.size() >= 4:
				recruit_order_cap = max(recruit_order_cap, 5)
			if recruit_spend_cap >= 220.0 and recruit_targets.size() >= 5:
				recruit_order_cap = max(recruit_order_cap, 6)
			if recruit_spend_cap >= 320.0 and recruit_targets.size() >= 6:
				recruit_order_cap = max(recruit_order_cap, 7)
			if recruit_spend_cap >= 450.0 and recruit_targets.size() >= 7:
				recruit_order_cap = max(recruit_order_cap, 8)
		if state_exhaustion >= 0.72:
			recruit_order_cap = max(2, recruit_order_cap - 1)
		if at_war_state and recruit_emergency_level > 0.01:
			recruit_order_cap += int(round(recruit_emergency_level * float(AI_RECRUIT_EMERGENCY_ORDER_BONUS)))
		if at_war_state and recruit_spend_cap > 0.0:
			recruit_order_cap += int(floor(recruit_spend_cap / 120.0))
		# Keep a very high safety ceiling only to protect performance.
		recruit_order_cap = clampi(recruit_order_cap, 1, 40)
		var manpower_estimate_units = _ai_odhad_dostupnych_rekrutu(owner_tag, owned, recruit_targets, at_war_state)
		var throughput_estimate_units = _ai_odhad_max_rekrutu_na_tah(owner_tag, recruit_targets, recruit_order_cap, at_war_state, state_pressure, recruit_spend_cap, recruit_emergency_level)
		var est_units = min(max(0, manpower_estimate_units), max(0, throughput_estimate_units))
		if est_units <= 0:
			est_units = max(0, throughput_estimate_units)
		# No hard spend cap: allow using entire available recruit budget.
		if frontline_crisis:
			_ai_debug("recruit crisis %s lvl=%.2f cap=%.2f orders=%d" % [
				owner_tag,
				recruit_emergency_level,
				recruit_spend_cap,
				recruit_order_cap
			])
		_ai_debug("recruit budget %s spend_factor=%.0f%% spend_cap=%.2f order_cap=%d war=%s pressure=%.1f exhaustion=%.2f" % [
			owner_tag,
			recruit_spend_factor * 100.0,
			recruit_spend_cap,
			recruit_order_cap,
			str(at_war_state),
			state_pressure,
			state_exhaustion
		])
		if recruit_emergency_level >= 0.01:
			_ai_debug("recruit emergency level %s lvl=%.2f" % [owner_tag, recruit_emergency_level])
		_ai_debug("recruit plan %s targets=%d pressure=%.1f reserve=%.2f treasury=%.2f" % [
			owner_tag,
			recruit_targets.size(),
			state_pressure,
			treasury_reserve,
			_ziskej_kasu_statu(owner_tag)
		])
		if at_war_state:
			_ai_debug("recruit focus %s target=%s enemies=%d" % [
				owner_tag,
				war_focus_target if war_focus_target != "" else "any_enemy_front",
				enemies_state.size()
			])
		var ai_recruit_slice_counter := 0
		var state_recruit_start_ms = Time.get_ticks_msec()
		var recruited_total := 0
		var recruit_orders_done := 0
		var recruit_spent_this_turn := 0.0
		var recruit_orders_by_province: Dictionary = {}
		var recruit_capital_id = _ziskej_hlavni_mesto_statu(owner_tag)
		var enemy_front_threat: Dictionary = {}
		var enemy_front_orders: Dictionary = {}
		var has_enemy_border_recruit = _ai_stat_ma_hranici_s_neprateli(owner_tag, owned, enemies_set)
		if at_war_state:
			for e_key_any in enemies_set.keys():
				var e_key = _normalizuj_tag(str(e_key_any))
				if e_key == "":
					continue
				enemy_front_threat[e_key] = 0.0
				enemy_front_orders[e_key] = 0
			for p_any in owned:
				var p_id_scan = int(p_any)
				if p_id_scan < 0 or not map_data.has(p_id_scan):
					continue
				var local_scan_threat = float(_spocitej_hrozbu_nepratel_u_provincie(p_id_scan, owner_tag))
				for e_key_any in enemy_front_threat.keys():
					var e_key = str(e_key_any)
					if _ai_provincie_hranicni_k_targetu(owner_tag, p_id_scan, e_key):
						enemy_front_threat[e_key] = float(enemy_front_threat.get(e_key, 0.0)) + max(1.0, local_scan_threat)
		var max_recruit_passes = max(1, recruit_order_cap)
		for pass_idx in range(max_recruit_passes):
			if recruit_orders_done >= recruit_order_cap:
				break
			if recruit_spent_this_turn >= recruit_spend_cap:
				break
			var war_phase = 0
			if at_war_state:
				if pass_idx >= 2:
					war_phase = 1
				if pass_idx >= 4:
					war_phase = 2
			var preferred_enemy_front = ""
			if at_war_state and war_phase <= 1 and not enemy_front_threat.is_empty():
				var total_front_threat := 0.0
				for t_any in enemy_front_threat.values():
					total_front_threat += float(t_any)
				var best_deficit := -INF
				for e_key_any in enemy_front_threat.keys():
					var e_key = str(e_key_any)
					var e_threat = float(enemy_front_threat.get(e_key, 0.0))
					if e_threat <= 0.0:
						continue
					var threat_share = e_threat / max(1.0, total_front_threat)
					var desired_orders = threat_share * float(max(1, recruit_orders_done + 1))
					var current_orders = float(int(enemy_front_orders.get(e_key, 0)))
					var deficit = desired_orders - current_orders
					if deficit > best_deficit:
						best_deficit = deficit
						preferred_enemy_front = e_key
			var ordered_targets = recruit_targets.duplicate()
			ordered_targets.sort_custom(func(a, b):
				var p_a = int(a)
				var p_b = int(b)
				var s_a = _ai_spocitej_recruit_pass_skore(owner_tag, p_a, recruit_capital_id, war_focus_target, enemies_set, int(recruit_orders_by_province.get(p_a, 0)), at_war_state)
				var s_b = _ai_spocitej_recruit_pass_skore(owner_tag, p_b, recruit_capital_id, war_focus_target, enemies_set, int(recruit_orders_by_province.get(p_b, 0)), at_war_state)
				return s_a > s_b
			)
			var pass_had_order = false
			for p_id in ordered_targets:
				if recruit_orders_done >= recruit_order_cap:
					break
				if recruit_spent_this_turn >= recruit_spend_cap:
					break
				if not map_data.has(p_id):
					continue
				var d = map_data[p_id]
				var rekruti = int(d.get("recruitable_population", 0))
				var local_soldiers = int(d.get("soldiers", 0))
				var local_threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, owner_tag)
				var local_frontline = _ma_nepratelskeho_souseda(owner_tag, p_id)
				var is_capital = bool(d.get("is_capital", false)) or p_id == _ziskej_hlavni_mesto_statu(owner_tag)
				var existing_orders_here = int(recruit_orders_by_province.get(p_id, 0))
				if at_war_state and preferred_enemy_front != "" and war_phase <= 1:
					if not _ai_provincie_hranicni_k_targetu(owner_tag, p_id, preferred_enemy_front):
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
				if at_war_state and ordered_targets.size() >= 3 and pass_idx <= 2 and existing_orders_here >= 1:
					ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
					continue
				if at_war_state and existing_orders_here >= 2:
					ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
					continue
				var enemy_front_contact = false
				var focused_front_contact = false
				if at_war_state:
					for n_raw in (_turn_neighbors_by_province.get(p_id, d.get("neighbors", [])) as Array):
						var n_id = int(n_raw)
						if not map_data.has(n_id):
							continue
						var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
						if n_owner == "" or n_owner == "SEA" or n_owner == owner_tag:
							continue
						if enemies_set.has(n_owner):
							enemy_front_contact = true
						if war_focus_target != "" and n_owner == war_focus_target:
							focused_front_contact = true
					if war_focus_target == "" and enemy_front_contact:
						focused_front_contact = true
					if has_enemy_border_recruit and not enemy_front_contact:
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
					if war_phase == 0 and has_enemy_border_recruit and not enemy_front_contact:
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
					if war_phase == 1 and not focused_front_contact and not enemy_front_contact and not local_frontline and not is_capital:
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
				if at_war_state and (not local_frontline) and (not is_capital) and local_threat < 260 and pass_idx <= 2 and recruit_targets.size() >= 3:
					ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
					continue
				var desired_garrison = 950
				if local_frontline:
					desired_garrison = 1300
				if is_capital:
					desired_garrison = 2200
				desired_garrison += min(1400, int(float(local_threat) * 0.40))
				# Do not overstack safe provinces, but in wartime allow moderate reserve growth
				# so large economies do not fully stall at orders=0 with high spend caps.
				if not local_frontline and local_threat < 260 and local_soldiers >= desired_garrison:
					var skip_safe = true
					if at_war_state:
						var war_overgarrison_limit = int(float(desired_garrison) * 2.0)
						skip_safe = state_pressure < 220.0 and local_soldiers >= war_overgarrison_limit
					if skip_safe:
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
				var core_owner_tag = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
				var je_okupace = core_owner_tag != "" and core_owner_tag != owner_tag
				if je_okupace:
					rekruti = int(floor(float(rekruti) * 0.2))
				var min_recruits_threshold = 220
				if at_war_state:
					min_recruits_threshold = 40
				if state_pressure >= 900.0:
					min_recruits_threshold = min(min_recruits_threshold, 30)
				if pass_idx >= 1 and at_war_state:
					min_recruits_threshold = min(min_recruits_threshold, 20)
				if at_war_state and recruit_spend_cap >= 220.0:
					min_recruits_threshold = min(min_recruits_threshold, 25)
				if at_war_state and recruit_orders_done == 0 and recruit_spent_this_turn <= 0.001:
					min_recruits_threshold = min(min_recruits_threshold, 20)
				if recruit_emergency_level > 0.0:
					min_recruits_threshold = min(min_recruits_threshold, int(round(lerp(18.0, 0.0, clamp(recruit_emergency_level, 0.0, 1.0)))))
				if rekruti > min_recruits_threshold and ai_kasy[owner_tag] > treasury_reserve + 5.0:
					var dostupny_rozpocet = max(0.0, ai_kasy[owner_tag] - treasury_reserve)
					var zbyvajici_recruit_budget = max(0.0, recruit_spend_cap - recruit_spent_this_turn)
					dostupny_rozpocet = min(dostupny_rozpocet, zbyvajici_recruit_budget)
					var pocet_k_verbovani = min(rekruti, int(dostupny_rozpocet / cena_za_vojaka))
					if pocet_k_verbovani <= 0:
						ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
						continue
					var frontline_bonus = 0
					if _ma_nepratelskeho_souseda(owner_tag, p_id):
						frontline_bonus += 900
					if bool(d.get("is_capital", false)):
						frontline_bonus += 900
					if p_id == _ziskej_hlavni_mesto_statu(owner_tag):
						frontline_bonus += 1200
					var hrozba = _spocitej_hrozbu_nepratel_u_provincie(p_id, owner_tag)
					frontline_bonus += min(1600, int(float(hrozba) * 0.24))
					var limit_verbovani = min(4200, 900 + frontline_bonus)
					if je_okupace:
						limit_verbovani = int(max(120, floor(float(limit_verbovani) * 0.25)))
					if recruit_emergency_level > 0.0:
						limit_verbovani = int(float(limit_verbovani) * (1.0 + recruit_emergency_level * 0.60))
					var per_order_cap = 850
					if local_frontline:
						per_order_cap += 550
					if is_capital:
						per_order_cap += 650
					per_order_cap += min(950, int(float(local_threat) * 0.22))
					if je_okupace:
						per_order_cap = int(max(120, floor(float(per_order_cap) * 0.30)))
					if recruit_order_cap >= 3 and recruit_spend_cap > 0.0 and recruit_emergency_level < 0.45:
						var effective_slots = max(1, min(recruit_order_cap, max(2, recruit_targets.size())))
						var fair_share_units = int((recruit_spend_cap / float(effective_slots)) / cena_za_vojaka)
						if fair_share_units > 0:
							per_order_cap = min(per_order_cap, max(220, int(float(fair_share_units) * 1.45)))
					if recruit_targets.size() <= 2 and recruit_order_cap >= 4:
						per_order_cap = int(float(per_order_cap) * 1.75)
					elif recruit_targets.size() == 3 and recruit_order_cap >= 5:
						per_order_cap = int(float(per_order_cap) * 1.35)
					if pass_idx >= 1 and at_war_state:
						per_order_cap = int(float(per_order_cap) * 1.15)
					if recruit_emergency_level > 0.0:
						per_order_cap = int(float(per_order_cap) * (1.0 + recruit_emergency_level * 0.90))
					var per_order_hard_cap = int(round(3600.0 + (2200.0 * clamp(recruit_emergency_level, 0.0, 1.0))))
					per_order_cap = min(per_order_hard_cap, per_order_cap)
					pocet_k_verbovani = min(pocet_k_verbovani, limit_verbovani, per_order_cap)
					d["recruitable_population"] -= pocet_k_verbovani
					d["soldiers"] += pocet_k_verbovani
					d["army_owner"] = owner_tag
					_ai_vycisti_runtime_cache_pro_stat(owner_tag)
					var recruit_cost = pocet_k_verbovani * cena_za_vojaka
					ai_kasy[owner_tag] -= recruit_cost
					recruit_spent_this_turn += recruit_cost
					recruited_total += pocet_k_verbovani
					recruit_orders_done += 1
					recruit_orders_by_province[p_id] = existing_orders_here + 1
					if at_war_state and not enemy_front_orders.is_empty():
						var touched_front = false
						for e_key_any in enemy_front_orders.keys():
							var e_key = str(e_key_any)
							if _ai_provincie_hranicni_k_targetu(owner_tag, p_id, e_key):
								enemy_front_orders[e_key] = int(enemy_front_orders.get(e_key, 0)) + 1
								touched_front = true
						if (not touched_front) and preferred_enemy_front != "":
							enemy_front_orders[preferred_enemy_front] = int(enemy_front_orders.get(preferred_enemy_front, 0)) + 1
					pass_had_order = true
				ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
			if not pass_had_order:
				break

		# Emergency fallback: in a defensive crisis, allow extra recruitment
		# even if normal pass logic under-spent due to local hard caps.
		var emergency_need = recruit_orders_done == 0
		if not emergency_need and recruit_emergency_level >= 0.60 and recruit_spend_cap > 0.0:
			emergency_need = recruit_spent_this_turn < recruit_spend_cap * 0.60
		if at_war_state and emergency_need and recruit_spend_cap > 0.0 and ai_kasy[owner_tag] > treasury_reserve + 5.0:
			var emergency_pool: Array = []
			for p_id_any in owned:
				var p_id = int(p_id_any)
				if not map_data.has(p_id):
					continue
				if not _ai_provincie_hranicni_k_neprateli(owner_tag, p_id, enemies_set):
					continue
				var d_em = map_data[p_id]
				var em_recruits = int(d_em.get("recruitable_population", 0))
				var core_owner_em = str(d_em.get("core_owner", owner_tag)).strip_edges().to_upper()
				var em_okupace = core_owner_em != "" and core_owner_em != owner_tag
				if em_okupace:
					em_recruits = int(floor(float(em_recruits) * 0.2))
				if em_recruits <= 15:
					continue
				var em_threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, owner_tag)
				var em_front = _ma_nepratelskeho_souseda(owner_tag, p_id)
				var em_capital = bool(d_em.get("is_capital", false)) or p_id == _ziskej_hlavni_mesto_statu(owner_tag)
				var em_soldiers = int(d_em.get("soldiers", 0))
				var em_score = float(em_recruits) + float(em_threat) * 0.65
				em_score += 850.0 if em_front else 0.0
				em_score += 650.0 if em_capital else 0.0
				em_score -= float(em_soldiers) * 0.015
				emergency_pool.append({"id": p_id, "score": em_score, "okupace": em_okupace, "threat": em_threat})
			emergency_pool.sort_custom(func(a, b):
				return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
			)
			var emergency_orders_target = min(2, recruit_order_cap)
			if recruit_orders_done > 0:
				emergency_orders_target = min(max(1, int(round(2.0 * recruit_emergency_level))), max(0, recruit_order_cap - recruit_orders_done))
			if recruit_orders_done == 0:
				emergency_orders_target = min(max(2, int(round(2.0 + recruit_emergency_level * 2.0))), recruit_order_cap)
			var emergency_placed = 0
			for row_any in emergency_pool:
				if emergency_placed >= emergency_orders_target:
					break
				var row = row_any as Dictionary
				var p_id = int(row.get("id", -1))
				if p_id < 0 or not map_data.has(p_id):
					continue
				var d = map_data[p_id]
				var rekruti = int(d.get("recruitable_population", 0))
				var je_okupace = bool(row.get("okupace", false))
				if je_okupace:
					rekruti = int(floor(float(rekruti) * 0.2))
				if rekruti <= 0:
					continue
				var dostupny_rozpocet = max(0.0, ai_kasy[owner_tag] - treasury_reserve)
				var zbyvajici_recruit_budget = max(0.0, recruit_spend_cap - recruit_spent_this_turn)
				dostupny_rozpocet = min(dostupny_rozpocet, zbyvajici_recruit_budget)
				var pocet_k_verbovani = min(rekruti, int(dostupny_rozpocet / cena_za_vojaka))
				if pocet_k_verbovani <= 0:
					continue
				var emergency_cap = 1400 + min(1200, int(float(row.get("threat", 0)) * 0.30))
				emergency_cap = int(float(emergency_cap) * (1.0 + recruit_emergency_level * 0.70))
				if je_okupace:
					emergency_cap = int(max(120, floor(float(emergency_cap) * 0.25)))
				pocet_k_verbovani = min(pocet_k_verbovani, emergency_cap)
				if pocet_k_verbovani <= 0:
					continue
				d["recruitable_population"] -= pocet_k_verbovani
				d["soldiers"] += pocet_k_verbovani
				d["army_owner"] = owner_tag
				_ai_vycisti_runtime_cache_pro_stat(owner_tag)
				var recruit_cost = pocet_k_verbovani * cena_za_vojaka
				ai_kasy[owner_tag] -= recruit_cost
				recruit_spent_this_turn += recruit_cost
				recruited_total += pocet_k_verbovani
				recruit_orders_done += 1
				emergency_placed += 1
			if emergency_placed > 0:
				_ai_debug("recruit emergency %s orders=%d spent=%.2f" % [
					owner_tag,
					emergency_placed,
					recruit_spent_this_turn
				])
		var state_recruit_ms = Time.get_ticks_msec() - state_recruit_start_ms
		ai_econ_recruit_ms += state_recruit_ms
		var state_post_start_ms = Time.get_ticks_msec()
		# Overflow spending burns extra treasury after recruiting so AI cash does not hoard forever.
		_ai_debug("state summary %s recruited=%d treasury_before=%.2f treasury_after=%.2f" % [
			owner_tag,
			recruited_total,
			treasury_before,
			_ziskej_kasu_statu(owner_tag)
		])
		var spent_pct = 0.0
		if recruit_spend_cap > 0.001:
			spent_pct = clamp((recruit_spent_this_turn / recruit_spend_cap) * 100.0, 0.0, 200.0)
		if recruit_orders_done == 0 and recruit_spend_cap >= 50.0:
			_ai_debug("recruit stall %s spend_cap=%.2f targets=%d pressure=%.1f" % [
				owner_tag,
				recruit_spend_cap,
				recruit_targets.size(),
				state_pressure
			])
		_ai_debug("recruit result %s spent=%.2f/%.2f (%.0f%%) orders=%d/%d" % [
			owner_tag,
			recruit_spent_this_turn,
			recruit_spend_cap,
			spent_pct,
			recruit_orders_done,
			recruit_order_cap
		])
		if at_war_state and not recruit_orders_by_province.is_empty():
			var peak_orders = 0
			for v_any in recruit_orders_by_province.values():
				peak_orders = max(peak_orders, int(v_any))
			_ai_debug("recruit distribution %s provinces_used=%d peak_orders_in_one=%d" % [
				owner_tag,
				recruit_orders_by_province.size(),
				peak_orders
			])
			if not enemy_front_orders.is_empty():
				var front_parts: Array[String] = []
				for e_key_any in enemy_front_orders.keys():
					var e_key = str(e_key_any)
					front_parts.append("%s:%d" % [e_key, int(enemy_front_orders.get(e_key, 0))])
				_ai_debug("recruit front split %s %s" % [owner_tag, ", ".join(front_parts)])

		var post_recruit_surplus = max(0.0, _ziskej_kasu_statu(owner_tag) - treasury_reserve)
		var under_spent_ratio = 0.0
		if recruit_spend_cap > 0.001:
			under_spent_ratio = recruit_spent_this_turn / recruit_spend_cap
		if (not war_light_pass) and post_recruit_surplus >= 220.0 and under_spent_ratio < 0.55:
			var relaxed_reserve = max(0.0, treasury_reserve * 0.55)
			var overflow_actions = min(6, 1 + int(floor(post_recruit_surplus / 220.0)))
			var action_order: Array[String] = ["lab", "build"]
			if not at_war_state:
				action_order.append("research")
			var action_cursor = posmod(aktualni_kolo, max(1, action_order.size()))
			var overflow_done := 0
			for _ov in range(overflow_actions):
				var did = false
				for step in range(action_order.size()):
					var idx = (action_cursor + step) % action_order.size()
					var action = action_order[idx]
					match action:
						"lab":
							did = _ai_zvaz_armadni_lab(owner_tag, relaxed_reserve)
						"build":
							did = _ai_zvaz_stavby(owner_tag, owned, relaxed_reserve, state_pressure) > 0
						"research":
							did = _ai_zvaz_vyzkum(owner_tag, relaxed_reserve, state_pressure)
						_:
							did = false
					if did:
						overflow_done += 1
						action_cursor = (idx + 1) % action_order.size()
						break
				if not did:
					break
			_ai_debug("overflow spend %s surplus=%.2f ratio=%.2f actions=%d reserve_relaxed=%.2f" % [
				owner_tag,
				post_recruit_surplus,
				under_spent_ratio,
				overflow_done,
				relaxed_reserve
			])

		var treasury_after = _ziskej_kasu_statu(owner_tag)
		var treasury_after_income = treasury_before + income_gained_this_turn
		var total_spent_this_turn = max(0.0, treasury_after_income - treasury_after)
		var spend_other_this_turn = max(0.0, total_spent_this_turn - (spend_build_this_turn + spend_lab_this_turn + recruit_spent_this_turn))
		_ai_debug_last_spending_by_state[owner_tag] = {
			"recruit": recruit_spent_this_turn,
			"lab": spend_lab_this_turn,
			"build": spend_build_this_turn,
			"other": spend_other_this_turn,
			"total": total_spent_this_turn,
			"income": income_gained_this_turn,
			"treasury_before": treasury_before,
			"treasury_after": treasury_after
		}
		var state_post_ms = Time.get_ticks_msec() - state_post_start_ms
		ai_econ_post_ms += state_post_ms
		var state_total_ms = Time.get_ticks_msec() - state_total_start_ms
		ai_econ_state_rows.append({
			"state": owner_tag,
			"total_ms": state_total_ms,
			"income_ms": state_income_ms,
			"prep_ms": state_prep_ms,
			"recruit_ms": state_recruit_ms,
			"post_ms": state_post_ms,
			"owned": owned.size(),
			"at_war": at_war_state
		})

		ai_state_slice_counter = await _turn_slice_wait(ai_state_slice_counter, TURN_FRAME_SLICE_AI_STATES)
	ai_phases["economy_recruit"] = Time.get_ticks_msec() - ai_phase_ms
	ai_econ_state_rows.sort_custom(func(a, b):
		return int((a as Dictionary).get("total_ms", 0)) > int((b as Dictionary).get("total_ms", 0))
	)
	if ai_econ_state_rows.size() > 8:
		ai_econ_state_rows.resize(8)
	(ai_detail_profile["economy"] as Dictionary)["war_light_states"] = war_light_states
	(ai_detail_profile["economy"] as Dictionary)["income_ms"] = ai_econ_income_ms
	(ai_detail_profile["economy"] as Dictionary)["prep_ms"] = ai_econ_prep_ms
	(ai_detail_profile["economy"] as Dictionary)["recruit_ms"] = ai_econ_recruit_ms
	(ai_detail_profile["economy"] as Dictionary)["post_ms"] = ai_econ_post_ms
	(ai_detail_profile["economy"] as Dictionary)["top_states"] = ai_econ_state_rows
	ai_phase_ms = Time.get_ticks_msec()
	_refresh_turn_runtime_owner_soldier_cache()
	var opened_wars = _ai_otevri_valky(ai_staty)
	if opened_wars > 0:
		_ai_debug("war opener created %d wars" % opened_wars)
	for ai_tag in ai_staty:
		_ai_aktualizuj_goal_progres(str(ai_tag))

	# AI movement phases:
	# 1) Non-attacking moves inside own provinces.
	# 2) Reinforce core provinces (capital + capital state).
	# 3) Offensive attacks.
	var movement_profile = await _naplanuj_ai_presuny(map_loader, ai_staty)
	ai_detail_profile["movement"] = movement_profile
	ai_phases["movement"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()
	# Disable runtime caches after movement and clean up temp maps.
	_ai_phase_cache_active = false
	_ai_vycisti_runtime_cache()
	_invalidate_turn_cache()
	ai_phases["cleanup"] = Time.get_ticks_msec() - ai_phase_ms
	var ai_total_ms = Time.get_ticks_msec() - ai_start_ms
	ai_detail_profile["total_ms"] = ai_total_ms
	ai_detail_profile["phases"] = ai_phases.duplicate(true)
	_debug_last_ai_profile = ai_detail_profile.duplicate(true)
	_log_ai_profile(ai_total_ms, ai_phases)
				
	if TURN_LOG_ENABLED:
		print("--- AI THINKING END ---")

# Core flow for this feature.
func _vyber_ai_kandidata_pro_presun_hlavniho_mesta(state_tag: String, current_capital_id: int) -> int:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `current_capital_id`: Input argument used by `_vyber_ai_kandidata_pro_presun_hlavniho_mesta` during execution.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_vyber_ai_kandidata_pro_presun_hlavniho_mesta` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyber ai kandidata pro presun hlavniho mesta` logic.
	# 3. Persist side effects and return the computed `int` result.
	var best_id := -1
	var best_score := -2147483648

	for p_id in map_data:
		var pid = int(p_id)
		if pid == current_capital_id:
			continue
		var d = map_data[pid]
		if _normalizuj_tag(str(d.get("owner", ""))) != state_tag:
			continue
		if _normalizuj_tag(str(d.get("core_owner", state_tag))) != state_tag:
			continue
		if _normalizuj_tag(str(d.get("owner", ""))) == "SEA":
			continue

		var pop = int(d.get("population", 0))
		var soldiers = int(d.get("soldiers", 0))
		var gdp = float(d.get("gdp", 0.0))
		var enemy_border = _ma_nepratelskeho_souseda(state_tag, pid)

		var score = int(round(gdp * 35.0)) + int(round(float(pop) * 0.003)) + int(round(float(soldiers) * 0.45))
		if enemy_border:
			score -= 350
		else:
			score += 450

		if score > best_score:
			best_score = score
			best_id = pid

	return best_id

func _ai_zvaz_presun_hlavniho_mesta(state_tag: String) -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_zvaz_presun_hlavniho_mesta` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai zvaz presun hlavniho mesta` logic.
	# 3. Persist side effects and finish without a return value.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return

	var current_capital_id = _ziskej_hlavni_mesto_statu(state)
	if current_capital_id == -1 or not map_data.has(current_capital_id):
		return

	var cap_data = map_data[current_capital_id]
	var capital_owner = _normalizuj_tag(str(cap_data.get("owner", "")))
	var surrender_pressure = _ma_stat_cekajici_kapitulaci(state)

	# Performance guard: evaluate relocation only during direct capitulation pressure
	# or when the state has already lost ownership of its capital province.
	if not (surrender_pressure or capital_owner != state):
		return

	var candidate_id = _vyber_ai_kandidata_pro_presun_hlavniho_mesta(state, current_capital_id)
	if candidate_id == -1:
		return

	var relocation_check = muze_presunout_hlavni_mesto(state, candidate_id)
	if not bool(relocation_check.get("ok", false)):
		return

	var cost = float(relocation_check.get("cost", 0.0))
	if _ziskej_kasu_statu(state) + 0.0001 < cost:
		return

	var result = presun_hlavni_mesto(state, candidate_id, true, false)
	if bool(result.get("ok", false)):
		if TURN_LOG_ENABLED:
			print("[AI] %s moved the capital to province %d for %.2f bn USD." % [state, candidate_id, cost])

# Runs the local feature logic.
func _naplanuj_ai_presuny(map_loader, ai_staty_override: Array = []):
	# Inputs:
	# - `map_loader`: Input argument used by `_naplanuj_ai_presuny` during execution.
	# - `ai_staty_override`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Variant`: Computed `Variant` result produced by `_naplanuj_ai_presuny`.
	# Execution timing: Called when game flow invokes `_naplanuj_ai_presuny` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` naplanuj ai presuny` logic.
	# 3. Persist side effects and return the computed `value` result.
	var ai_staty = ai_staty_override if not ai_staty_override.is_empty() else _ziskej_ai_staty()
	var movement_profile = AI_MOVEMENT_PROFILE_ENABLED or _ai_debug_mode_enabled
	var movement_start_ms = 0
	var movement_non_attack_ms = 0
	var movement_core_defense_ms = 0
	var movement_offense_ms = 0
	var movement_war_eval_ms = 0
	var movement_war_declare_ms = 0
	var movement_war_eval_count = 0
	var movement_war_declare_count = 0
	var movement_registered = 0
	var movement_state_rows: Array = []
	if movement_profile:
		movement_start_ms = Time.get_ticks_msec()

	if map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()

	var plan_slice_counter := 0

	for owner_tag in ai_staty:
		# Each state runs the same movement pipeline in deterministic order:
		# crisis -> relocation -> core defense -> naval staging -> offense.
		var state_movement_start_ms = Time.get_ticks_msec()
		var moved_from: Dictionary = {}
		var orders_for_state := 0  # Hard limit on movement orders per state (potato mode only)
		var ai_limit_enabled := _potato_mode_enabled
		owner_tag = str(owner_tag)
		var serazene: Array = _seradene_ai_provincie(owner_tag)
		var own_capital_id = _ziskej_hlavni_mesto_statu(owner_tag)
		var core_state: String = _ziskej_core_state_cached(owner_tag)
		var operation_plan = _ai_ziskej_operacni_plan(owner_tag)
		var operation_phase = str(operation_plan.get("phase", "staging"))
		var operation_target = _normalizuj_tag(str(operation_plan.get("target", "")))
		var front_info = _ai_ziskej_primarni_front(owner_tag)
		var preferred_front_owner = _normalizuj_tag(str(front_info.get("target", "")))
		if operation_target != "":
			preferred_front_owner = operation_target
		var war_exhaustion = _ai_spocitej_war_exhaustion(owner_tag)
		var is_consolidating = war_exhaustion >= 0.68
		var coordinated_commitment: Dictionary = {}
		if preferred_front_owner != "":
			coordinated_commitment["owner:" + preferred_front_owner] = 1
		var frontline_cache: Dictionary = {}
		for p_any in serazene:
			var p_id_int = int(p_any)
			_je_frontline_cached(owner_tag, p_id_int, frontline_cache)
			for n_raw in (_turn_neighbors_by_province.get(p_id_int, []) as Array):
				var n_id = int(n_raw)
				if _normalizuj_tag(str(_turn_owner_by_province.get(n_id, ""))) != owner_tag:
					continue
				_je_frontline_cached(owner_tag, n_id, frontline_cache)
				plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)

		# 0) Immediate crisis reaction (capital recapture / punishing direct incursion).
		var phase_start_ms = 0
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break
			if moved_from.has(p_id):
				continue
			var urgent_move = _navrhni_krizovy_protiutok(owner_tag, p_id, own_capital_id, frontline_cache)
			if urgent_move.is_empty():
				continue
			var urgent_amount = int(urgent_move.get("amount", 0))
			if urgent_amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(
				int(urgent_move["from"]),
				int(urgent_move["to"]),
				urgent_amount,
				false,
				[int(urgent_move["from"]), int(urgent_move["to"])]
			)
			movement_registered += 1
			moved_from[urgent_move["from"]] = true
			orders_for_state += 1
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
		if movement_profile:
			movement_core_defense_ms += Time.get_ticks_msec() - phase_start_ms

		# 1) Internal non-attacking relocation (rear to frontline by adjacent friendly move).
		phase_start_ms = 0
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break  # Hard limit reached for this state
			if moved_from.has(p_id):
				continue
			# Keep coastal assault stacks in place when any sea invasion route is viable.
			if _ai_ma_namorni_prilezitost(owner_tag, int(p_id), ""):
				continue
			var unit_role = _ai_urci_roli_jednotky(owner_tag, int(p_id), own_capital_id, frontline_cache)
			if unit_role == "anchor":
				continue
			var move = _navrhni_neutocny_presun(owner_tag, p_id, frontline_cache, preferred_front_owner, operation_phase == "staging")
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(
				int(move["from"]),
				int(move["to"]),
				amount,
				false,
				[int(move["from"]), int(move["to"])]
			)
			movement_registered += 1
			moved_from[move["from"]] = true
			orders_for_state += 1
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
		if movement_profile:
			movement_non_attack_ms += Time.get_ticks_msec() - phase_start_ms

		# 2) Defense of core provinces (capital and provinces in the capital's state).
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break  # Hard limit reached for this state
			if moved_from.has(p_id):
				continue
			var move = _navrhni_core_obranu(owner_tag, p_id, core_state, frontline_cache)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(
				int(move["from"]),
				int(move["to"]),
				amount,
				false,
				[int(move["from"]), int(move["to"])]
			)
			movement_registered += 1
			moved_from[move["from"]] = true
			orders_for_state += 1
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
		if movement_profile:
			movement_core_defense_ms += Time.get_ticks_msec() - phase_start_ms

		# 2.5) Naval staging: embark from coastal ports toward overseas enemy coasts.
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break
			if moved_from.has(p_id):
				continue
			var naval_move = _navrhni_namorni_presun(owner_tag, int(p_id), "")
			if naval_move.is_empty():
				continue
			var naval_amount = int(naval_move.get("amount", 0))
			if naval_amount <= 0:
				continue
			map_loader.zaregistruj_presun_armady(
				int(naval_move["from"]),
				int(naval_move["to"]),
				naval_amount,
				false,
				[int(naval_move["from"]), int(naval_move["to"])]
			)
			movement_registered += 1
			moved_from[naval_move["from"]] = true
			orders_for_state += 1
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
		if movement_profile:
			movement_non_attack_ms += Time.get_ticks_msec() - phase_start_ms

		# 3) Offensive attacks.
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		var offense_orders := 0
		var offense_order_cap := 999999
		if is_consolidating:
			offense_order_cap = 1
		if operation_phase == "staging" and not is_consolidating:
			offense_order_cap = min(offense_order_cap, 2)
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break  # Hard limit reached for this state
			if offense_orders >= offense_order_cap:
				break
			if moved_from.has(p_id):
				continue
			var unit_role = _ai_urci_roli_jednotky(owner_tag, int(p_id), own_capital_id, frontline_cache)
			var sea_frontline_attack = _je_more_provincie(int(p_id)) and _je_frontline_cached(owner_tag, int(p_id), frontline_cache)
			if unit_role != "breaker" and not (unit_role == "holder" and (operation_phase == "strike" or sea_frontline_attack)):
				continue
			var move = _navrhni_utok(owner_tag, p_id, frontline_cache, preferred_front_owner, coordinated_commitment, operation_phase == "strike")
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue

			var target_id = int(move["to"])
			var target_owner = _normalizuj_tag(str(_turn_owner_by_province.get(target_id, str(map_data[target_id].get("owner", "")))))
			if target_owner == "" or target_owner == owner_tag or target_owner == "SEA":
				plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
				continue
			var from_country_name = _normalizuj_nazev_statu(str(map_data[int(move["from"])].get("country_name", "")))
			var target_country_name = _normalizuj_nazev_statu(str(map_data[target_id].get("country_name", "")))
			if from_country_name != "" and from_country_name == target_country_name:
				plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
				continue
			if jsou_ve_valce(owner_tag, target_owner):
				# In staging/consolidation phases, attacks require stronger local advantage.
				var from_is_sea_attack = _je_more_provincie(int(move["from"]))
				var target_is_capital_attack = bool(map_data[target_id].get("is_capital", false))
				var island_capital_override = from_is_sea_attack and target_is_capital_attack
				if operation_phase == "staging":
					var local_enemy_staging = int(_turn_soldiers_by_province.get(target_id, int(map_data[target_id].get("soldiers", 0))))
					if (not island_capital_override) and float(amount) / float(max(1, local_enemy_staging)) < 1.55:
						plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
						continue
				if is_consolidating:
					var local_enemy = int(_turn_soldiers_by_province.get(target_id, int(map_data[target_id].get("soldiers", 0))))
					if (not island_capital_override) and float(amount) / float(max(1, local_enemy)) < 1.20:
						plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
						continue
				map_loader.zaregistruj_presun_armady(
					int(move["from"]),
					int(move["to"]),
					amount,
					false,
					[int(move["from"]), int(move["to"])]
				)
				movement_registered += 1
				moved_from[move["from"]] = true
				orders_for_state += 1
				offense_orders += 1
				coordinated_commitment["owner:" + _normalizuj_tag(target_owner)] = int(coordinated_commitment.get("owner:" + _normalizuj_tag(target_owner), 0)) + 1
				coordinated_commitment["prov:" + str(target_id)] = int(coordinated_commitment.get("prov:" + str(target_id), 0)) + 1
			else:
				# If not at war yet, evaluate declaration before scheduling attack order.
				if is_consolidating:
					plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
					continue
				var war_eval_start_ms = 0
				if movement_profile:
					war_eval_start_ms = Time.get_ticks_msec()
				var should_declare = _ma_smyls_vyhlasit_valku(owner_tag, target_owner, int(move["from"]), int(move["to"]), amount)
				if movement_profile:
					movement_war_eval_ms += Time.get_ticks_msec() - war_eval_start_ms
					movement_war_eval_count += 1
				if should_declare:
					var aggr_profile = _ai_ziskej_profil(owner_tag)
					var aggr_level = float(aggr_profile.get("aggression", 0.5))
					if aggr_level >= 0.82:
						var pair_key = _klic_pair(owner_tag, target_owner)
						if pair_key != "":
							neagresivni_smlouvy.erase(pair_key)
						if _ziskej_uroven_aliance_ai_cached(owner_tag, target_owner) > ALLIANCE_NONE:
							_nastav_uroven_aliance_bez_kontroly(owner_tag, target_owner, ALLIANCE_NONE)
					var war_declare_start_ms = 0
					if movement_profile:
						war_declare_start_ms = Time.get_ticks_msec()
					vyhlasit_valku(owner_tag, target_owner)
					if movement_profile:
						movement_war_declare_ms += Time.get_ticks_msec() - war_declare_start_ms
						movement_war_declare_count += 1
					if jsou_ve_valce(owner_tag, target_owner):
						map_loader.zaregistruj_presun_armady(
							int(move["from"]),
							int(move["to"]),
							amount,
							false,
							[int(move["from"]), int(move["to"])]
						)
						movement_registered += 1
						moved_from[move["from"]] = true
						orders_for_state += 1
						offense_orders += 1
						coordinated_commitment["owner:" + _normalizuj_tag(target_owner)] = int(coordinated_commitment.get("owner:" + _normalizuj_tag(target_owner), 0)) + 1
						coordinated_commitment["prov:" + str(target_id)] = int(coordinated_commitment.get("prov:" + str(target_id), 0)) + 1
			plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI)
		if movement_profile:
			movement_offense_ms += Time.get_ticks_msec() - phase_start_ms

		plan_slice_counter = await _turn_slice_wait(plan_slice_counter, TURN_FRAME_SLICE_AI_STATES)
		movement_state_rows.append({
			"state": _normalizuj_tag(owner_tag),
			"total_ms": Time.get_ticks_msec() - state_movement_start_ms,
			"orders": orders_for_state,
			"offense_orders": offense_orders,
			"phase": operation_phase,
			"target": preferred_front_owner
		})

	if map_loader.has_method("ukonci_davkovy_presun"):
		map_loader.ukonci_davkovy_presun()

	var movement_total_ms = Time.get_ticks_msec() - movement_start_ms if movement_profile else 0
	movement_state_rows.sort_custom(func(a, b):
		return int((a as Dictionary).get("total_ms", 0)) > int((b as Dictionary).get("total_ms", 0))
	)
	if movement_state_rows.size() > 8:
		movement_state_rows.resize(8)
	if AI_MOVEMENT_PROFILE_ENABLED:
		print("[AI-MOVE-PROFILE] total=%dms non_attack=%dms core_defense=%dms offense=%dms war_eval=%dms war_eval_n=%d war_declare=%dms war_declare_n=%d states=%d moves=%d" % [
			movement_total_ms,
			movement_non_attack_ms,
			movement_core_defense_ms,
			movement_offense_ms,
			movement_war_eval_ms,
			movement_war_eval_count,
			movement_war_declare_ms,
			movement_war_declare_count,
			ai_staty.size(),
			movement_registered
		])

	return {
		"total_ms": movement_total_ms,
		"non_attack_ms": movement_non_attack_ms,
		"core_defense_ms": movement_core_defense_ms,
		"offense_ms": movement_offense_ms,
		"war_eval_ms": movement_war_eval_ms,
		"war_eval_count": movement_war_eval_count,
		"war_declare_ms": movement_war_declare_ms,
		"war_declare_count": movement_war_declare_count,
		"moves_registered": movement_registered,
		"states": ai_staty.size(),
		"state_rows": movement_state_rows
	}

# Computes derived values from current inputs and game state.
func _vyber_ai_staty_pro_tah(ai_staty_all: Array) -> Array:
	# Inputs:
	# - `ai_staty_all`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_vyber_ai_staty_pro_tah` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` vyber ai staty pro tah` logic.
	# 3. Persist side effects and return the computed `Array` result.
	if not AI_FASTMODE_ENABLED:
		return ai_staty_all
	var total = ai_staty_all.size()
	if total <= 1:
		return ai_staty_all
	var cap = AI_STATES_PER_TURN_CAP_POTATO if _potato_mode_enabled else AI_STATES_PER_TURN_CAP
	cap = clampi(cap, 1, total)
	if total <= cap:
		_ai_turn_state_cursor = 0
		_ai_fastmode_cached_subset = ai_staty_all.duplicate(true)
		_ai_fastmode_cached_turn_marker = aktualni_kolo
		return ai_staty_all

	var forced_include: Array = []
	# States currently at war are always forced in, even in fast-mode rotation.
	for raw_tag in ai_staty_all:
		var clean = _normalizuj_tag(str(raw_tag))
		if clean == "":
			continue
		if not (_ai_ziskej_nepratele_statu(clean) as Array).is_empty():
			forced_include.append(clean)

	# Hard cap applies only to peace-time rotation.
	# States currently at war are always processed this turn.
	var rotation_cap = max(0, cap - forced_include.size())

	# Always recompute subset each turn. This keeps round-robin visibly rotating
	# and avoids sticky AI subsets over long peace-time stretches.
	var use_cached = false
	var dynamic_subset: Array = []
	if use_cached:
		for cached_any in _ai_fastmode_cached_subset:
			var cached_tag = _normalizuj_tag(str(cached_any))
			if cached_tag == "" or not ai_staty_all.has(cached_tag):
				continue
			if not dynamic_subset.has(cached_tag):
				dynamic_subset.append(cached_tag)
	else:
		# Peace-time states rotate through a cursor window so all AI states get turns over time.
		var rotation_pool: Array = []
		for raw_tag in ai_staty_all:
			var clean = _normalizuj_tag(str(raw_tag))
			if clean == "" or forced_include.has(clean):
				continue
			rotation_pool.append(clean)
		var pool_total = rotation_pool.size()
		if pool_total > 0 and rotation_cap > 0:
			var take = min(rotation_cap, pool_total)
			var start = posmod(_ai_turn_state_cursor, pool_total)
			for i in range(take):
				var idx = (start + i) % pool_total
				dynamic_subset.append(rotation_pool[idx])
			_ai_turn_state_cursor = (start + take) % pool_total

	var out: Array = []
	for tag_any in forced_include:
		if not out.has(tag_any):
			out.append(tag_any)
	for tag_any in dynamic_subset:
		if out.size() >= forced_include.size() + rotation_cap:
			break
		if not out.has(tag_any):
			out.append(tag_any)
	if out.is_empty():
		out.append(ai_staty_all[0])

	_ai_fastmode_cached_subset = out.duplicate(true)
	_ai_fastmode_cached_turn_marker = aktualni_kolo
	return out

# Computes derived values from current inputs and game state.
func _ai_spocitej_ekonomicky_tok_statu_pro_tah(state_tags: Array) -> Dictionary:
	# One-pass aggregation over provinces is cheaper than per-state rescans.
	if state_tags.is_empty() or map_data.is_empty():
		return {}
	var state_set: Dictionary = {}
	for tag_any in state_tags:
		var clean = _normalizuj_tag(str(tag_any))
		if clean != "" and clean != "SEA":
			state_set[clean] = true
	if state_set.is_empty():
		return {}
	var per_state_rates: Dictionary = {}
	var out: Dictionary = {}
	for p_id_any in map_data:
		var p_id = int(p_id_any)
		var d = map_data[p_id] as Dictionary
		var owner_tag = _normalizuj_tag(str(_turn_owner_by_province.get(p_id, str(d.get("owner", "")))))
		if owner_tag == "" or owner_tag == "SEA" or not state_set.has(owner_tag):
			continue
		if not per_state_rates.has(owner_tag):
			per_state_rates[owner_tag] = {
				"income_rate": ziskej_prijmovou_sazbu_hdp(owner_tag),
				"upkeep": ziskej_udrzbu_za_vojaka(owner_tag)
			}
		var rates = per_state_rates[owner_tag] as Dictionary
		var income_rate = float(rates.get("income_rate", BASE_INCOME_RATE))
		var upkeep_state = float(rates.get("upkeep", BASE_UPKEEP_PER_SOLDIER))
		var prov_mods = _ziskej_modifikatory_budov_provincie(p_id)
		# Province upkeep modifiers are applied on top of state-level upkeep.
		var local_upkeep_mult = max(0.01, float(prov_mods.get("upkeep_mult", 1.0)))
		var gdp_income = float(d.get("gdp", 0.0)) * income_rate
		var upkeep_cost = float(max(0, int(d.get("soldiers", 0)))) * upkeep_state * local_upkeep_mult
		if not out.has(owner_tag):
			out[owner_tag] = {"income": 0.0, "upkeep": 0.0, "net": 0.0}
		var row = out[owner_tag] as Dictionary
		row["income"] = float(row.get("income", 0.0)) + gdp_income
		row["upkeep"] = float(row.get("upkeep", 0.0)) + upkeep_cost
		row["net"] = float(row.get("income", 0.0)) - float(row.get("upkeep", 0.0))
		out[owner_tag] = row
	return out

# Runs the local feature logic.
func _ai_pripis_pasivni_ekonomiku_mimo_subset(ai_staty_all: Array, ai_staty_subset: Array, net_income_by_state: Dictionary = {}) -> void:
	# Fast-mode can skip active logic for some AI states, but economy still advances here.
	if ai_staty_all.is_empty():
		return
	var subset_set: Dictionary = {}
	for tag_any in ai_staty_subset:
		var clean_subset = _normalizuj_tag(str(tag_any))
		if clean_subset != "":
			subset_set[clean_subset] = true
	for raw_tag in ai_staty_all:
		var owner_tag = _normalizuj_tag(str(raw_tag))
		if owner_tag == "" or subset_set.has(owner_tag):
			continue
		if (_turn_state_owned_provinces.get(owner_tag, []) as Array).is_empty():
			continue
		if not ai_kasy.has(owner_tag):
			var ai_hdp = _spocitej_hdp_statu(owner_tag)
			ai_kasy[owner_tag] = ai_hdp * 0.05
		var income_gained_this_turn = 0.0
		if net_income_by_state.has(owner_tag):
			income_gained_this_turn = float((net_income_by_state[owner_tag] as Dictionary).get("net", 0.0))
		else:
			# Fast passive tick fallback when aggregation map is unavailable.
			income_gained_this_turn = _spocitej_cisty_prijem_statu(owner_tag)
		ai_kasy[owner_tag] += income_gained_this_turn
		if ai_kasy[owner_tag] < -100.0:
			_vyres_bankrot(owner_tag)
		if not _ai_debug_last_spending_by_state.has(owner_tag):
			_ai_debug_last_spending_by_state[owner_tag] = {}
		(_ai_debug_last_spending_by_state[owner_tag] as Dictionary)["income"] = income_gained_this_turn

# Ai generated or editted start (priloha_a.txt)
func _seradene_ai_provincie(state_tag: String) -> Array:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `Array`: Collected results returned to the caller.
	# Execution timing: Called when game flow invokes `_seradene_ai_provincie` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` seradene ai provincie` logic.
	# 3. Persist side effects and return the computed `Array` result.
	var ids: Array = []
	if _turn_cache_valid and _turn_state_owned_provinces.has(state_tag):
		for p_id in (_turn_state_owned_provinces[state_tag] as Array):
			if not map_data.has(p_id):
				continue
			var d_cached = map_data[p_id]
			var army_owner_cached = str(d_cached.get("army_owner", "")).strip_edges().to_upper()
			# AI can only command stacks it actually controls.
			if army_owner_cached != "" and army_owner_cached != state_tag:
				continue
			if int(_turn_soldiers_by_province.get(int(p_id), int(map_data[p_id].get("soldiers", 0)))) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
				ids.append(p_id)
		# Include navies stationed on sea tiles (owner is SEA, controller is army_owner).
		for p_id_any in map_data:
			var p_id = int(p_id_any)
			if ids.has(p_id):
				continue
			if not _je_more_provincie(p_id):
				continue
			var d_sea = map_data[p_id]
			var army_owner_sea = _normalizuj_tag(str(d_sea.get("army_owner", "")))
			if army_owner_sea != state_tag:
				continue
			if int(_turn_soldiers_by_province.get(p_id, int(d_sea.get("soldiers", 0)))) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
				ids.append(p_id)
	else:
		for p_id in map_data:
			var d = map_data[p_id]
			if str(d.get("owner", "")).strip_edges().to_upper() == state_tag:
				var army_owner = str(d.get("army_owner", "")).strip_edges().to_upper()
				# Skip mixed-control provinces (e.g., foreign troops with military access).
				if army_owner != "" and army_owner != state_tag:
					continue
				if int(d.get("soldiers", 0)) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
					ids.append(p_id)
		# Fallback branch: sea tiles controlled by this state's navy.
		for p_id_any in map_data:
			var p_id = int(p_id_any)
			if ids.has(p_id):
				continue
			if not _je_more_provincie(p_id):
				continue
			var d_sea_fb = map_data[p_id]
			if _normalizuj_tag(str(d_sea_fb.get("army_owner", ""))) != state_tag:
				continue
			if int(d_sea_fb.get("soldiers", 0)) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
				ids.append(p_id)

	ids.sort_custom(func(a, b):
		return int(_turn_soldiers_by_province.get(int(a), int(map_data[a].get("soldiers", 0)))) > int(_turn_soldiers_by_province.get(int(b), int(map_data[b].get("soldiers", 0))))
	)
	return ids

# Ai generated or editted end (priloha_a.txt)
func _ai_ma_namorni_prilezitost(state_tag: String, from_id: int, _preferred_front_owner: String = "") -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_ai_ma_namorni_prilezitost` during execution.
	# - `preferred_front_owner`: Input argument used by `_ai_ma_namorni_prilezitost` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ai_ma_namorni_prilezitost` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai ma namorni prilezitost` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if state_tag == "" or state_tag == "SEA":
		return false
	if not map_data.has(from_id):
		return false

	var from_is_sea = _je_more_provincie(from_id)
	if not from_is_sea:
		if not je_pobrezni_provincie(from_id):
			return false
		if not provincie_ma_pristav(from_id):
			return false

	for n_raw in (map_data[from_id].get("neighbors", []) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		if not _je_more_provincie(n_id):
			continue
		for coast_raw in (map_data[n_id].get("neighbors", []) as Array):
			var coast_id = int(coast_raw)
			if not map_data.has(coast_id) or _je_more_provincie(coast_id):
				continue
			var coast_owner = _normalizuj_tag(str(_turn_owner_by_province.get(coast_id, str(map_data[coast_id].get("owner", "")))))
			if coast_owner == "" or coast_owner == "SEA" or coast_owner == state_tag:
				continue
			if _jsou_ve_valce_ai_cached(state_tag, coast_owner):
				return true
			if not _je_pratelsky_vztah_ai_cached(state_tag, coast_owner):
				# i bez otevreny valky je to signal, ze more muze otevrit novej front.
				return true
	return false

# Condition check helper.
func _ma_nepratelskeho_souseda(state_tag: String, province_id: int) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_ma_nepratelskeho_souseda` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_nepratelskeho_souseda` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma nepratelskeho souseda` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if _ai_phase_cache_active:
		var ck = "%s|%d" % [state_tag, province_id]
		if _ai_enemy_neighbor_cache.has(ck):
			return bool(_ai_enemy_neighbor_cache[ck])

	if not map_data.has(province_id):
		if _ai_phase_cache_active:
			_ai_enemy_neighbor_cache["%s|%d" % [state_tag, province_id]] = false
		return false
	var found_enemy := false
	var neighbors = (_turn_neighbors_by_province.get(province_id, map_data[province_id].get("neighbors", [])) as Array)
	for n_raw in neighbors:
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if _jsou_ve_valce_ai_cached(state_tag, n_owner):
			found_enemy = true
			break
		if not _je_pratelsky_vztah_ai_cached(state_tag, n_owner):
			found_enemy = true
			break
	if _ai_phase_cache_active:
		_ai_enemy_neighbor_cache["%s|%d" % [state_tag, province_id]] = found_enemy
	return found_enemy

# Computes derived values from current inputs and game state.
func _spocitej_hrozbu_nepratel_u_provincie(province_id: int, state_tag: String) -> int:
	# Inputs:
	# - `province_id`: Input argument used by `_spocitej_hrozbu_nepratel_u_provincie` during execution.
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_spocitej_hrozbu_nepratel_u_provincie` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej hrozbu nepratel u provincie` logic.
	# 3. Persist side effects and return the computed `int` result.
	if _ai_phase_cache_active:
		var ck = "%s|%d" % [state_tag, province_id]
		if _ai_threat_cache.has(ck):
			return int(_ai_threat_cache[ck])

	if not map_data.has(province_id):
		if _ai_phase_cache_active:
			_ai_threat_cache["%s|%d" % [state_tag, province_id]] = 0
		return 0
	var threat := 0
	# hrozba = suma sousednich ne-pratelskych armad v jednom kroku od provincie.
	var neighbors = (_turn_neighbors_by_province.get(province_id, map_data[province_id].get("neighbors", [])) as Array)
	for n_raw in neighbors:
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner):
			continue
		threat += int(_turn_soldiers_by_province.get(n_id, int(map_data[n_id].get("soldiers", 0))))
	if _ai_phase_cache_active:
		_ai_threat_cache["%s|%d" % [state_tag, province_id]] = threat
	return threat

# Computes derived values from current inputs and game state.
func _spocitej_silu_na_hranici(state_tag: String, enemy: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `enemy`: Input argument used by `_spocitej_silu_na_hranici` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_spocitej_silu_na_hranici` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` spocitej silu na hranici` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	var our_border := 0
	var enemy_border := 0

	if _turn_cache_valid and _turn_state_owned_provinces.has(state_tag) and _turn_state_owned_provinces.has(enemy):
		for p_id in (_turn_state_owned_provinces[state_tag] as Array):
			if not map_data.has(p_id):
				continue
			var soldiers_our = int(_turn_soldiers_by_province.get(int(p_id), int(map_data[p_id].get("soldiers", 0))))
			for n_raw in (_turn_neighbors_by_province.get(int(p_id), map_data[p_id].get("neighbors", [])) as Array):
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner_our = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if n_owner_our == enemy:
					our_border += soldiers_our
					break

		for p_id in (_turn_state_owned_provinces[enemy] as Array):
			if not map_data.has(p_id):
				continue
			var soldiers_enemy = int(_turn_soldiers_by_province.get(int(p_id), int(map_data[p_id].get("soldiers", 0))))
			for n_raw in (_turn_neighbors_by_province.get(int(p_id), map_data[p_id].get("neighbors", [])) as Array):
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner_enemy = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if n_owner_enemy == state_tag:
					enemy_border += soldiers_enemy
					break
		return {"our": our_border, "enemy": enemy_border}

	for p_id in map_data:
		var d = map_data[p_id]
		var p_owner = _normalizuj_tag(str(d.get("owner", "")))
		if p_owner != state_tag and p_owner != enemy:
			continue
		var soldiers = int(d.get("soldiers", 0))
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = _normalizuj_tag(str(map_data[n_id].get("owner", "")))
			if p_owner == state_tag and n_owner == enemy:
				our_border += soldiers
				break
			if p_owner == enemy and n_owner == state_tag:
				enemy_border += soldiers
				break
	return {"our": our_border, "enemy": enemy_border}

# Reads values from active state.
func _ziskej_ai_border_strength_cached(state_tag: String, target_owner: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `target_owner`: Input argument used by `_ziskej_ai_border_strength_cached` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ziskej_ai_border_strength_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej ai border strength cached` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not _ai_phase_cache_active:
		return _spocitej_silu_na_hranici(state_tag, target_owner)
	var key = "%s>%s" % [state_tag, target_owner]
	if _ai_border_strength_cache.has(key):
		return (_ai_border_strength_cache[key] as Dictionary)
	var computed = _spocitej_silu_na_hranici(state_tag, target_owner)
	_ai_border_strength_cache[key] = computed
	return computed

# Read-only data accessor.
func _ziskej_ai_war_pair_eval_cached(state_tag: String, target_owner: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `target_owner`: Input argument used by `_ziskej_ai_war_pair_eval_cached` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_ziskej_ai_war_pair_eval_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej ai war pair eval cached` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	state_tag = _normalizuj_tag(state_tag)
	target_owner = _normalizuj_tag(target_owner)
	if state_tag == "" or target_owner == "" or state_tag == target_owner:
		return {
			"blocked": true,
			"required_local_ratio": 999.0,
			"border_ratio": 0.0,
			"strategic_ratio": 0.0
		}
	if not _ai_phase_cache_active:
		return {}
	var key = "%s>%s" % [state_tag, target_owner]
	if _ai_war_pair_eval_cache.has(key):
		return (_ai_war_pair_eval_cache[key] as Dictionary)

	var out := {
		"blocked": false,
		"required_local_ratio": 999.0,
		"border_ratio": 0.0,
		"strategic_ratio": 0.0
	}

	if _ziskej_uroven_aliance_ai_cached(state_tag, target_owner) > ALLIANCE_NONE:
		out["blocked"] = true
		_ai_war_pair_eval_cache[key] = out
		return out

	var profile = _ai_ziskej_profil(state_tag)
	var aggression = float(profile.get("aggression", 0.5))
	var rel = _ziskej_ai_vztah_cached(state_tag, target_owner)
	var war_rel_cap = AI_DECLARE_WAR_MAX_RELATION + (aggression * 45.0)

	if rel >= AI_FRIEND_RELATION_THRESHOLD and aggression < 0.90:
		out["blocked"] = true
		_ai_war_pair_eval_cache[key] = out
		return out

	if rel > war_rel_cap:
		out["blocked"] = true
		_ai_war_pair_eval_cache[key] = out
		return out

	var border_strength = _ziskej_ai_border_strength_cached(state_tag, target_owner)
	var our_border = float(int(border_strength.get("our", 0)))
	var enemy_border = float(max(1, int(border_strength.get("enemy", 0))))
	out["border_ratio"] = our_border / enemy_border

	var relation_factor = clamp((-rel) / 80.0, 0.0, 1.0)
	out["required_local_ratio"] = 1.25 - (relation_factor * 0.20)

	var defensive_allies_power := 0
	for ally in _ziskej_spojence_s_min_alianci(target_owner, ALLIANCE_DEFENSE):
		var ally_tag = _normalizuj_tag(str(ally))
		if ally_tag == "" or ally_tag == state_tag:
			continue
		if _ziskej_ai_vztah_cached(ally_tag, state_tag) >= AI_FRIEND_RELATION_THRESHOLD:
			continue
		defensive_allies_power += _spocitej_silu_statu(ally_tag)

	var own_total = float(max(1, _spocitej_silu_statu(state_tag)))
	var target_total = float(max(1, _spocitej_silu_statu(target_owner) + defensive_allies_power))
	out["strategic_ratio"] = own_total / target_total

	_ai_war_pair_eval_cache[key] = out
	return out

# Boolean check for required state.
func _ma_smyls_vyhlasit_valku(state_tag: String, target_owner: String, from_id: int, to_id: int, amount: int) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `target_owner`: Input argument used by `_ma_smyls_vyhlasit_valku` during execution.
	# - `from_id`: Input argument used by `_ma_smyls_vyhlasit_valku` during execution.
	# - `to_id`: Input argument used by `_ma_smyls_vyhlasit_valku` during execution.
	# - `amount`: Input argument used by `_ma_smyls_vyhlasit_valku` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_smyls_vyhlasit_valku` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma smyls vyhlasit valku` logic.
	# 3. Persist side effects and return the computed `bool` result.
	state_tag = _normalizuj_tag(state_tag)
	target_owner = _normalizuj_tag(target_owner)
	if state_tag == target_owner:
		return false
	if state_tag == "" or target_owner == "" or target_owner == "SEA":
		return false
	var own_name = _ziskej_nazev_statu_podle_owner(state_tag)
	var target_name = _ziskej_nazev_statu_podle_owner(target_owner)
	if own_name != "" and own_name == target_name:
		_ai_debug("war block %s->%s reason=same_country_name name=%s" % [state_tag, target_owner, own_name])
		return false
	if not map_data.has(from_id) or not map_data.has(to_id):
		return false

	var pair_eval: Dictionary = _ziskej_ai_war_pair_eval_cached(state_tag, target_owner)
	if not pair_eval.is_empty() and bool(pair_eval.get("blocked", false)):
		return false

	var ratio = float(pair_eval.get("border_ratio", 0.0))
	var required_local_ratio = float(pair_eval.get("required_local_ratio", 1.25))
	var strategic_ratio = float(pair_eval.get("strategic_ratio", 0.0))
	var profile = _ai_ziskej_profil(state_tag)
	var mindset = _ai_ziskej_mindset(state_tag)
	var goal = _ai_ziskej_strategicky_cil(state_tag)
	var aggression = float(profile.get("aggression", 0.5))
	var attack_bias = float(mindset.get("attack_bias", 0.5))
	var defense_bias = float(mindset.get("defense_bias", 0.5))
	var risk = float(mindset.get("risk", 0.5))
	var goal_target = _normalizuj_tag(str(goal.get("target", "")))
	var goal_type = str(goal.get("type", "none"))
	var goal_focus = goal_target != "" and goal_target == target_owner
	var war_rel_bonus = float(mindset.get("war_rel_bonus", 0.0))
	if goal_focus:
		war_rel_bonus += 12.0
	var war_rel_cap = AI_DECLARE_WAR_MAX_RELATION + (aggression * 45.0) + war_rel_bonus
	var min_attack_force = maxf(550.0, AI_DECLARE_WAR_MIN_ATTACK_FORCE - (aggression * 1000.0) - (attack_bias * 520.0) + (defense_bias * 260.0))
	if goal_focus:
		min_attack_force = maxf(450.0, min_attack_force - 180.0)
	if float(amount) < min_attack_force:
		return false

	if pair_eval.is_empty():
		# Fallback path when AI phase cache is not active.
		if _ziskej_uroven_aliance_ai_cached(state_tag, target_owner) > ALLIANCE_NONE:
			return false
		var rel = _ziskej_ai_vztah_cached(state_tag, target_owner)
		if rel >= AI_FRIEND_RELATION_THRESHOLD and aggression < 0.90:
			return false
		if rel > war_rel_cap:
			return false
		var border_strength = _spocitej_silu_na_hranici(state_tag, target_owner)
		var our_border = float(int(border_strength.get("our", 0)))
		var enemy_border = float(max(1, int(border_strength.get("enemy", 0))))
		ratio = our_border / enemy_border
		var relation_factor = clamp((-rel) / 80.0, 0.0, 1.0)
		required_local_ratio = 1.25 - (relation_factor * 0.20)
		var defensive_allies_power := 0
		for ally in _ziskej_spojence_s_min_alianci(target_owner, ALLIANCE_DEFENSE):
			var ally_tag = _normalizuj_tag(str(ally))
			if ally_tag == "" or ally_tag == state_tag:
				continue
			if _ziskej_ai_vztah_cached(ally_tag, state_tag) >= AI_FRIEND_RELATION_THRESHOLD:
				continue
			defensive_allies_power += _spocitej_silu_statu(ally_tag)
		var own_total = float(max(1, _spocitej_silu_statu(state_tag)))
		var target_total = float(max(1, _spocitej_silu_statu(target_owner) + defensive_allies_power))
		strategic_ratio = own_total / target_total

	var target_soldiers = int(map_data[to_id].get("soldiers", 0))
	var local_ratio = float(amount) / float(max(1, target_soldiers))
	var rel_now = _ziskej_ai_vztah_cached(state_tag, target_owner)
	var target_core_owner = _normalizuj_tag(str(map_data[to_id].get("core_owner", "")))

	var border_need = AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE - aggression * 0.45 - attack_bias * 0.20 + defense_bias * 0.12
	required_local_ratio = maxf(0.72, required_local_ratio - aggression * 0.35 + float(mindset.get("local_ratio_shift", 0.0)))
	var strategic_need = maxf(0.58, 0.90 - aggression * 0.30 + float(mindset.get("strategic_shift", 0.0)))
	if goal_focus:
		border_need -= 0.10
		required_local_ratio = maxf(0.68, required_local_ratio - 0.08)
		if goal_type == "reclaim_core":
			strategic_need = maxf(0.54, strategic_need - 0.08)

	# High aggression: allow opportunistic wars instead of waiting for ideal ratios.
	if (aggression >= 0.78 or risk >= 0.72) and rel_now <= (35.0 + attack_bias * 18.0) and local_ratio >= 0.82 and strategic_ratio >= 0.75:
		_ai_debug("war decide %s->%s reason=aggr_shortcut rel=%.1f local=%.2f strategic=%.2f" % [state_tag, target_owner, rel_now, local_ratio, strategic_ratio])
		return true

	# If rival blocks our core province while relations are hostile, escalate faster.
	if target_core_owner == state_tag and rel_now <= -15.0:
		_ai_debug("war decide %s->%s reason=core_block rel=%.1f local=%.2f strategic=%.2f" % [state_tag, target_owner, rel_now, local_ratio, strategic_ratio])
		return local_ratio >= 1.08 and strategic_ratio >= 0.82

	# If both fight same enemies and relations are bad, AI may open a rivalry war.
	if _ai_sdili_nepritele_s(state_tag, target_owner) and rel_now <= -30.0 and local_ratio >= 1.18 and strategic_ratio >= 0.95:
		_ai_debug("war decide %s->%s reason=rivalry rel=%.1f local=%.2f strategic=%.2f" % [state_tag, target_owner, rel_now, local_ratio, strategic_ratio])
		return true

	# Overwhelming local superiority should trigger immediate action.
	if local_ratio >= 3.5 and strategic_ratio >= 1.20 and rel_now <= 20.0:
		_ai_debug("war decide %s->%s reason=overwhelming rel=%.1f local=%.2f strategic=%.2f" % [state_tag, target_owner, rel_now, local_ratio, strategic_ratio])
		return true

	var final_ok = ratio >= border_need and local_ratio >= required_local_ratio and strategic_ratio >= strategic_need
	if final_ok:
		_ai_debug("war decide %s->%s reason=standard border=%.2f local=%.2f strategic=%.2f" % [state_tag, target_owner, ratio, local_ratio, strategic_ratio])
	return final_ok

# Ai generated or editted start (priloha_a.txt)
func _ai_otevri_valky(ai_staty: Array) -> int:
	# Inputs:
	# - `ai_staty`: State-tag input used for filtering or normalization.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ai_otevri_valky` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai otevri valky` logic.
	# 3. Persist side effects and return the computed `int` result.
	var opened := 0
	for owner_any in ai_staty:
		var state_owner = _normalizuj_tag(str(owner_any))
		if state_owner == "" or state_owner == "SEA":
			continue

		var owned = _turn_state_owned_provinces.get(state_owner, []) as Array
		if owned.is_empty():
			continue

		var profile = _ai_ziskej_profil(state_owner)
		var goal = _ai_ziskej_strategicky_cil(state_owner)
		var primary_front = _ai_ziskej_primarni_front(state_owner)
		var front_target = _normalizuj_tag(str(primary_front.get("target", "")))
		var exhaustion = _ai_spocitej_war_exhaustion(state_owner)
		var aggression = float(profile.get("aggression", 0.5))
		var personality = str(profile.get("personality", "balanced"))
		if aggression < 0.45 or exhaustion >= 0.86:
			continue
		var goal_target = _normalizuj_tag(str(goal.get("target", "")))
		var goal_type = str(goal.get("type", "none"))

		var candidates: Dictionary = {}
		for p_raw in owned:
			var p_id = int(p_raw)
			var neighbors = (_turn_neighbors_by_province.get(p_id, map_data.get(p_id, {}).get("neighbors", [])) as Array)
			for n_raw in neighbors:
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("state_owner", "")))))
				if n_owner == "" or n_owner == "SEA" or n_owner == state_owner:
					continue
				candidates[n_owner] = true

		var best_target := ""
		var best_score := -INF
		for target in candidates.keys():
			var target_owner = _normalizuj_tag(str(target))
			if target_owner == "":
				continue
			if _jsou_ve_valce_ai_cached(state_owner, target_owner):
				continue

			var alliance_level = _ziskej_uroven_aliance_ai_cached(state_owner, target_owner)
			if alliance_level > ALLIANCE_NONE and aggression < 0.82:
				continue
			if _ma_neagresivni_smlouvu_ai_cached(state_owner, target_owner) and aggression < 0.82:
				continue

			var rel = _ziskej_ai_vztah_cached(state_owner, target_owner)
			var war_rel_cap = AI_DECLARE_WAR_MAX_RELATION + (aggression * 55.0)
			if rel > war_rel_cap and aggression < 0.92:
				continue

			var own_power = float(max(1, _spocitej_silu_statu(state_owner)))
			var target_power = float(max(1, _spocitej_silu_statu(target_owner)))
			var strategic_ratio = own_power / target_power
			var ratio_need = lerpf(1.18, 0.72, aggression) + exhaustion * 0.22
			if personality == "fortress" or personality == "planner":
				ratio_need += 0.08
			elif personality == "warlord" or personality == "opportunist":
				ratio_need -= 0.08
			if goal_target == target_owner:
				ratio_need -= 0.12
				if goal_type == "reclaim_core":
					ratio_need -= 0.08
			if strategic_ratio < ratio_need:
				continue

			var border = _spocitej_silu_na_hranici(state_owner, target_owner)
			var border_ratio = float(int(border.get("our", 0))) / float(max(1, int(border.get("enemy", 0))))
			var score = strategic_ratio * 110.0 + border_ratio * 95.0 + clamp(-rel, 0.0, 120.0) * 1.4 + aggression * 140.0
			score -= exhaustion * 180.0
			if front_target != "" and target_owner == front_target:
				score += 200.0
			if goal_target == target_owner:
				score += 280.0
				if goal_type == "reclaim_core":
					score += 200.0
			if score > best_score:
				best_score = score
				best_target = target_owner

		if best_target == "":
			continue

		if aggression >= 0.82:
			var pair_key = _klic_pair(state_owner, best_target)
			if pair_key != "":
				neagresivni_smlouvy.erase(pair_key)
			if _ziskej_uroven_aliance_ai_cached(state_owner, best_target) > ALLIANCE_NONE:
				_nastav_uroven_aliance_bez_kontroly(state_owner, best_target, ALLIANCE_NONE)

		if vyhlasit_valku(state_owner, best_target):
			opened += 1
			_ai_debug("war opener %s -> %s aggr=%.2f score=%.1f" % [state_owner, best_target, aggression, best_score])
			_ai_war_cache.clear()
			_ai_war_pair_eval_cache.clear()
			_ai_border_strength_cache.clear()

	return opened

# Ai generated or editted start (priloha_a.txt)
func _navrhni_krizovy_protiutok(state_tag: String, from_id: int, own_capital_id: int, _frontline_cache: Dictionary = {}) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `from_id`: Input argument used by `_navrhni_krizovy_protiutok` during execution.
	# - `own_capital_id`: Input argument used by `_navrhni_krizovy_protiutok` during execution.
	# - `frontline_cache`: Input argument used by `_navrhni_krizovy_protiutok` during execution.
	# Outputs:
	# - `Dictionary`: Structured result payload for downstream processing.
	# Execution timing: Called when game flow invokes `_navrhni_krizovy_protiutok` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` navrhni krizovy protiutok` logic.
	# 3. Persist side effects and return the computed `Dictionary` result.
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var soldiers = int(from_data.get("soldiers", 0))
	if soldiers < 1200:
		return {}

	var best_target := -1
	var best_score := -INF
	var best_amount := 0

	for n_raw in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_data = map_data[n_id]
		var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(n_data.get("owner", "")))))
		if n_owner == "" or n_owner == "SEA" or n_owner == state_tag:
			continue

		var rel = _ziskej_ai_vztah_cached(state_tag, n_owner)
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and rel >= AI_FRIEND_RELATION_THRESHOLD:
			continue

		var enemy_soldiers = int(_turn_soldiers_by_province.get(n_id, int(n_data.get("soldiers", 0))))
		var local_ratio = float(soldiers) / float(max(1, enemy_soldiers))
		var score = 0.0
		score += float(soldiers - enemy_soldiers) * 1.35

		if n_id == own_capital_id and n_owner != state_tag:
			score += 15000.0
		if _normalizuj_tag(str(n_data.get("core_owner", ""))) == state_tag:
			score += 3800.0
		if bool(n_data.get("is_capital", false)):
			score += 1800.0

		# If we are massively stronger, react immediately.
		if local_ratio >= 8.0:
			score += 5000.0

		if score > best_score:
			best_score = score
			best_target = n_id
			best_amount = min(soldiers - 500, int(float(soldiers) * 0.84))

	if best_target == -1:
		return {}
	if best_amount < 550:
		return {}
	if best_score < 2000.0:
		return {}
	_ai_debug("crisis move %s from=%d to=%d amount=%d score=%.1f" % [state_tag, from_id, best_target, best_amount, best_score])

	return {"from": from_id, "to": best_target, "amount": best_amount}

# Ai generated or editted end (priloha_a.txt)
func _ziskej_ai_vztah_cached(tag_a: String, tag_b: String) -> float:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `float`: Computed `float` result produced by `_ziskej_ai_vztah_cached`.
	# Execution timing: Called when game flow invokes `_ziskej_ai_vztah_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej ai vztah cached` logic.
	# 3. Persist side effects and return the computed `float` result.
	if not _ai_phase_cache_active:
		return ziskej_vztah_statu(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return 0.0
	if _ai_relation_cache.has(key):
		return float(_ai_relation_cache[key])
	var rel = ziskej_vztah_statu(tag_a, tag_b)
	_ai_relation_cache[key] = rel
	return rel

# Boolean check for required state.
func _je_pratelsky_vztah_ai_cached(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_pratelsky_vztah_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je pratelsky vztah ai cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	return _ziskej_ai_vztah_cached(tag_a, tag_b) >= AI_FRIEND_RELATION_THRESHOLD

# Core flow for this feature.
func _jsou_ve_valce_ai_cached(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_jsou_ve_valce_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` jsou ve valce ai cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not _ai_phase_cache_active:
		return jsou_ve_valce(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_war_cache.has(key):
		return bool(_ai_war_cache[key])
	var is_war = jsou_ve_valce(tag_a, tag_b)
	_ai_war_cache[key] = is_war
	return is_war

# Reads values from active state.
func _ziskej_uroven_aliance_ai_cached(tag_a: String, tag_b: String) -> int:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `int`: Computed numeric result for game/UI logic.
	# Execution timing: Called when game flow invokes `_ziskej_uroven_aliance_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ziskej uroven aliance ai cached` logic.
	# 3. Persist side effects and return the computed `int` result.
	if not _ai_phase_cache_active:
		return ziskej_uroven_aliance(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return ALLIANCE_NONE
	if _ai_alliance_level_cache.has(key):
		return int(_ai_alliance_level_cache[key])
	var level = int(aliance_statu.get(key, ALLIANCE_NONE))
	_ai_alliance_level_cache[key] = level
	return level

# Returns true when conditions are met.
func _ma_neagresivni_smlouvu_ai_cached(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_neagresivni_smlouvu_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma neagresivni smlouvu ai cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not _ai_phase_cache_active:
		return ma_neagresivni_smlouvu(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_non_aggr_cache.has(key):
		return bool(_ai_non_aggr_cache[key])
	var has_pact = neagresivni_smlouvy.has(key)
	_ai_non_aggr_cache[key] = has_pact
	return has_pact

# Runs the local feature logic.
func _muze_upravit_vztah_ai_cached(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_muze_upravit_vztah_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` muze upravit vztah ai cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not _ai_phase_cache_active:
		return muze_upravit_vztah_statu(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_can_adjust_relation_cache.has(key):
		return bool(_ai_can_adjust_relation_cache[key])
	var last_turn = _get_relationship_store().last_action_turn(tag_a, tag_b)
	var ok = (aktualni_kolo - last_turn) >= RELATION_ACTION_COOLDOWN_TURNS
	_ai_can_adjust_relation_cache[key] = ok
	return ok

# Condition check helper.
func _ma_spolecnou_hranici_ai_cached(tag_a: String, tag_b: String) -> bool:
	# Inputs:
	# - `tag_a`: State tag handled by this function.
	# - `tag_b`: State tag handled by this function.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_ma_spolecnou_hranici_ai_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ma spolecnou hranici ai cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if not _ai_phase_cache_active:
		return _ma_spolecnou_hranici(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_border_cache.has(key):
		return bool(_ai_border_cache[key])
	var has_border = _ma_spolecnou_hranici(tag_a, tag_b)
	_ai_border_cache[key] = has_border
	return has_border

# Eligibility/guard check.
func _je_frontline_cached(state_tag: String, province_id: int, frontline_cache: Dictionary) -> bool:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# - `province_id`: Input argument used by `_je_frontline_cached` during execution.
	# - `frontline_cache`: Input argument used by `_je_frontline_cached` during execution.
	# Outputs:
	# - `bool`: True when the requested condition is met.
	# Execution timing: Called when game flow invokes `_je_frontline_cached` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` je frontline cached` logic.
	# 3. Persist side effects and return the computed `bool` result.
	if frontline_cache.has(province_id):
		return bool(frontline_cache[province_id])
	var is_frontline = _ma_nepratelskeho_souseda(state_tag, province_id)
	frontline_cache[province_id] = is_frontline
	return is_frontline

# Wipes short-lived state.
func _ai_vycisti_runtime_cache_pro_stat(state_tag: String) -> void:
	# Inputs:
	# - `state_tag`: State tag handled by this function.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_vycisti_runtime_cache_pro_stat` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai vycisti runtime cache pro stat` logic.
	# 3. Persist side effects and finish without a return value.
	var clean = _normalizuj_tag(state_tag)
	if clean == "":
		return
	_ai_state_pressure_cache.erase(clean)
	_ai_state_core_defense_cache.erase(clean)
	_ai_state_enemies_cache.erase(clean)
	_ai_capital_cache.erase(clean)
	_ai_econ_mods_cache.erase(clean)

# Wipes AI-only runtime memoization between AI phases or after major world-state changes.
func _ai_vycisti_runtime_cache() -> void:
	# Inputs:
	# - none.
	# Outputs:
	# - none.
	# Execution timing: Called when game flow invokes `_ai_vycisti_runtime_cache` for this subsystem.
	# Steps:
	# 1. Validate inputs and collect runtime state required by this function.
	# 2. Execute the core ` ai vycisti runtime cache` logic.
	# 3. Persist side effects and finish without a return value.
	_ai_enemy_neighbor_cache.clear()
	_ai_threat_cache.clear()
	_ai_border_strength_cache.clear()
	_ai_war_pair_eval_cache.clear()
	_ai_relation_cache.clear()
	_ai_allies_cache.clear()
	_ai_war_cache.clear()
	_ai_alliance_level_cache.clear()
	_ai_non_aggr_cache.clear()
	_ai_can_adjust_relation_cache.clear()
	_ai_border_cache.clear()
	_ai_mindset_cache.clear()
	_ai_state_enemies_cache.clear()
	_ai_capital_cache.clear()
	_ai_econ_mods_cache.clear()
	_ai_state_pressure_cache.clear()
	_ai_state_core_defense_cache.clear()

