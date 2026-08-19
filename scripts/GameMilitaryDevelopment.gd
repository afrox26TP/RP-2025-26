extends "res://scripts/GameCore.gd"

## Army development, research, ideology, and military economy rules.

func _zajisti_armadni_lab_statu(tag: String) -> Dictionary:
	# Inputs:
	# - `tag`: State tag.
	# Outputs:
	# - `Dictionary`: Guaranteed-valid army-lab state dictionary.
	# Execution timing: Called before any army-lab read/write operation.
	# Steps:
	# 1. Normalize/validate state tag.
	# 2. Create lab entry when missing or invalid.
	# 3. Ensure required fields and defaults exist.
	# 4. Normalize quality/grid dimensions and item levels.
	# 5. Persist and return normalized lab dictionary.
	var cisty = _normalizuj_tag(tag)
	if cisty == "" or cisty == "SEA":
		return {}
	if not armadni_lab_statu.has(cisty):
		armadni_lab_statu[cisty] = {
			"grid_items": [],
			"offers": [],
			"offers_turn": -1,
			"rerolls_this_turn": 0,
			"quality_level": 0,
			"grid_w": ARM_LAB_GRID_W,
			"grid_h": ARM_LAB_GRID_H
		}
	var lab_any = armadni_lab_statu[cisty]
	if not (lab_any is Dictionary):
		armadni_lab_statu[cisty] = {
			"grid_items": [],
			"offers": [],
			"offers_turn": -1,
			"rerolls_this_turn": 0,
			"quality_level": 0,
			"grid_w": ARM_LAB_GRID_W,
			"grid_h": ARM_LAB_GRID_H
		}
	var lab = armadni_lab_statu[cisty] as Dictionary
	if not lab.has("grid_items") or not (lab.get("grid_items", []) is Array):
		lab["grid_items"] = []
	if not lab.has("offers") or not (lab.get("offers", []) is Array):
		lab["offers"] = []
	if not lab.has("offers_turn"):
		lab["offers_turn"] = -1
	if not lab.has("rerolls_this_turn"):
		lab["rerolls_this_turn"] = 0
	if not lab.has("quality_level"):
		lab["quality_level"] = 0
	if not lab.has("grid_w"):
		lab["grid_w"] = ARM_LAB_GRID_W
	if not lab.has("grid_h"):
		lab["grid_h"] = ARM_LAB_GRID_H
	if not lab.has("unlocked_cells") or not (lab.get("unlocked_cells", []) is Array):
		var base_cells: Array = []
		for y in range(ARM_LAB_GRID_H):
			for x in range(ARM_LAB_GRID_W):
				base_cells.append("%d_%d" % [x, y])
		lab["unlocked_cells"] = base_cells
	lab["quality_level"] = _clamp_arm_lab_quality(int(lab.get("quality_level", 0)))
	lab["grid_w"] = clampi(int(lab.get("grid_w", ARM_LAB_GRID_W)), ARM_LAB_GRID_W, ARM_LAB_GRID_MAX_W)
	lab["grid_h"] = clampi(int(lab.get("grid_h", ARM_LAB_GRID_H)), ARM_LAB_GRID_H, ARM_LAB_GRID_MAX_H)
	var grid_items = lab.get("grid_items", []) as Array
	for i in range(grid_items.size()):
		var item = grid_items[i] as Dictionary
		if not item.has("level"):
			item["level"] = 1
		grid_items[i] = item
	lab["grid_items"] = grid_items
	armadni_lab_statu[cisty] = lab
	return lab

# Inputs:
# - `quality_level`: Current lab quality level.
# Outputs:
# - `int`: Random rolled tier (1-3).
# Execution timing: Called when generating new lab offers.
# Steps:
# 1. Clamp quality level.
# 2. Compute tier probabilities.
# 3. Roll random value and map to tier.
func _arm_lab_zajisti_nabidky(state_tag: String) -> void:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs: none
	# Execution timing: Called before serving lab state or purchase operations.
	# Steps:
	# 1. Normalize and validate state.
	# 2. Ensure lab dictionary exists.
	# 3. Skip refresh when offers for current turn are already complete.
	# 4. Generate new offers and reset reroll counter for current turn.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return
	var lab = _zajisti_armadni_lab_statu(cisty)
	if lab.is_empty():
		return

	if int(lab.get("offers_turn", -1)) == aktualni_kolo and (lab.get("offers", []) as Array).size() == ARM_LAB_OFFER_COUNT:
		return

	var quality = int(lab.get("quality_level", 0))
	var offers: Array = []
	for _i in range(ARM_LAB_OFFER_COUNT):
		offers.append(_arm_lab_vytvor_random_offer(quality))

	lab["offers"] = offers
	lab["offers_turn"] = aktualni_kolo
	lab["rerolls_this_turn"] = 0
	armadni_lab_statu[cisty] = lab

func ziskej_armadni_lab_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Complete UI-ready army-lab snapshot or error payload.
	# Execution timing: Called when opening/refreshing army-lab UI.
	# Steps:
	# 1. Validate state existence.
	# 2. Ensure offers and lab data are current.
	# 3. Compute unlocked cells, dimensions, offers, and bonus totals.
	# 4. Return normalized response payload with costs and treasury.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	_arm_lab_zajisti_nabidky(cisty)
	var lab = _zajisti_armadni_lab_statu(cisty)
	var grid_items = (lab.get("grid_items", []) as Array).duplicate(true)
	var unlocked = _arm_lab_odemcene_dict(lab)
	var dims = _arm_lab_obsah_mrizky_odemykani(unlocked)
	var offers = (lab.get("offers", []) as Array).duplicate(true)
	var bonus = _arm_lab_spocitej_bonus(grid_items)
	var rerolls_this_turn = int(lab.get("rerolls_this_turn", 0))
	var quality_level = int(lab.get("quality_level", 0))
	var grid_w = int(dims.get("w", ARM_LAB_GRID_W))
	var grid_h = int(dims.get("h", ARM_LAB_GRID_H))
	var expanded_cells = max(0, unlocked.size() - (ARM_LAB_GRID_W * ARM_LAB_GRID_H))
	var expand_cost = snapped(ARM_LAB_EXPAND_BASE_COST + float(expanded_cells) * ARM_LAB_EXPAND_STEP_COST, 0.01)
	var can_expand = unlocked.size() < (ARM_LAB_GRID_MAX_W * ARM_LAB_GRID_MAX_H)

	return {
		"ok": true,
		"state": cisty,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"grid_max_w": ARM_LAB_GRID_MAX_W,
		"grid_max_h": ARM_LAB_GRID_MAX_H,
		"can_expand": can_expand,
		"expand_cost": expand_cost,
		"unlocked_cells": _arm_lab_odemcene_array(unlocked),
		"grid_items": grid_items,
		"offers": offers,
		"offers_turn": int(lab.get("offers_turn", -1)),
		"reroll_cost": snapped(ARM_LAB_REROLL_BASE_COST + float(rerolls_this_turn) * 4.0, 0.01),
		"quality_level": quality_level,
		"quality_upgrade_cost": snapped(ARM_LAB_QUALITY_UPGRADE_BASE_COST + float(quality_level) * 16.0, 0.01),
		"power_flat": int(bonus.get("flat", 0)),
		"power_pct": float(bonus.get("pct", 0.0)),
		"treasury": _ziskej_kasu_statu(cisty)
	}

# Inputs:
# - `state_tag`: State tag.
# - `base_soldiers`: Optional precomputed base soldiers (`-1` auto-computes from map).
# Outputs:
# - `Dictionary`: Base strength, lab bonuses, and total army strength.
# Execution timing: Called for combat evaluation and UI strength display.
# Steps:
# 1. Validate state and resolve base soldier count.
# 2. Read current lab grid items.
# 3. Compute flat/percent bonuses.
# 4. Return detailed strength breakdown.
func ziskej_silu_armady_statu(state_tag: String, base_soldiers: int = -1) -> Dictionary:
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "base": 0, "total": 0}

	var base_value = base_soldiers
	if base_value < 0:
		base_value = 0
		for p_id in map_data:
			var d = map_data[p_id]
			if _normalizuj_tag(str(d.get("owner", ""))) == cisty:
				base_value += int(d.get("soldiers", 0))

	var lab = _zajisti_armadni_lab_statu(cisty)
	var grid_items = lab.get("grid_items", []) as Array
	var bonus = _arm_lab_spocitej_bonus(grid_items)
	var bonus_flat = int(bonus.get("flat", 0))
	var bonus_pct = max(0.0, float(bonus.get("pct", 0.0)))
	var bonus_from_pct = int(round(float(base_value) * bonus_pct))
	var total = max(0, base_value + bonus_flat + bonus_from_pct)
	return {
		"ok": true,
		"base": max(0, base_value),
		"bonus_flat": bonus_flat,
		"bonus_pct": bonus_pct,
		"bonus_from_pct": bonus_from_pct,
		"total": total
	}

# Inputs:
# - `state_tag`: Buyer state tag.
# - `offer_index`: Index in current offers list.
# - `target_x`: Optional target x (`-1` for auto place).
# - `target_y`: Optional target y (`-1` for auto place).
# Outputs:
# - `Dictionary`: Success payload with placed item/cost or error reason.
# Execution timing: Called when player buys an army-lab offer.
# Steps:
# 1. Validate state, offer selection, and treasury.
# 2. Resolve placement (manual or first free slot).
# 3. Append purchased item to grid.
# 4. Refill offers list and persist lab state.
# 5. Deduct treasury, emit turn-change signal, and return result.
func kup_armadni_nabidku_na_pozici(state_tag: String, offer_index: int, target_x: int, target_y: int) -> Dictionary:
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	_arm_lab_zajisti_nabidky(cisty)
	var lab = _zajisti_armadni_lab_statu(cisty)
	var offers = lab.get("offers", []) as Array
	if offer_index < 0 or offer_index >= offers.size():
		return {"ok": false, "reason": "Invalid offer selection."}

	var offer = offers[offer_index] as Dictionary
	var cost = float(offer.get("cost", 0.0))
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {"ok": false, "reason": "Not enough money.", "cost": cost, "treasury": treasury}

	var grid_items = lab.get("grid_items", []) as Array
	var unlocked = _arm_lab_odemcene_dict(lab)
	var dims = _arm_lab_obsah_mrizky_odemykani(unlocked)
	var grid_w = int(dims.get("w", ARM_LAB_GRID_W))
	var grid_h = int(dims.get("h", ARM_LAB_GRID_H))
	var ow = int(offer.get("w", 1))
	var oh = int(offer.get("h", 1))
	var pos: Vector2i
	if target_x >= 0 and target_y >= 0:
		if not _arm_lab_muze_umistit_na(grid_items, ow, oh, target_x, target_y, grid_w, grid_h, unlocked):
			return {"ok": false, "reason": "Item cannot be placed here."}
		pos = Vector2i(target_x, target_y)
	else:
		pos = _arm_lab_najdi_prvni_volne_misto(grid_items, ow, oh, grid_w, grid_h, unlocked)
	if pos.x < 0:
		return {"ok": false, "reason": "There is no space left in the grid for this item."}

	var item = offer.duplicate(true)
	item["x"] = pos.x
	item["y"] = pos.y
	grid_items.append(item)
	lab["grid_items"] = grid_items

	offers.remove_at(offer_index)
	while offers.size() < ARM_LAB_OFFER_COUNT:
		offers.append(_arm_lab_vytvor_random_offer(int(lab.get("quality_level", 0))))
	lab["offers"] = offers
	armadni_lab_statu[cisty] = lab

	_nastav_kasu_statu(cisty, treasury - cost)
	_money_debug_expense(cisty, "army_lab_buy", cost, treasury, _ziskej_kasu_statu(cisty), "offer=%d item=%s" % [offer_index, str(item.get("id", ""))])
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"item": item,
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

# Inputs:
# - `state_tag`: Buyer state tag.
# - `offer_index`: Index in offers list.
# Outputs:
# - `Dictionary`: Purchase result from auto-placement flow.
# Execution timing: Convenience wrapper for basic buy action.
# Steps:
# 1. Delegate to `kup_armadni_nabidku_na_pozici()` with auto-placement.
func kup_armadni_nabidku(state_tag: String, offer_index: int) -> Dictionary:
	return kup_armadni_nabidku_na_pozici(state_tag, offer_index, -1, -1)

# Inputs:
# - `state_tag`: Buyer state tag.
# - `offer_index`: Index in offers list.
# - `target_uid`: Existing item uid to merge into.
# Outputs:
# - `Dictionary`: Merge purchase result or error payload.
# Execution timing: Called when buying an offer directly into merge upgrade flow.
# Steps:
# 1. Validate state, offer, target item, and treasury.
# 2. Validate merge compatibility (id and level).
# 3. Compute merged stats and upgrade destination item.
# 4. Remove purchased offer, refill offers, persist state, deduct money.
# 5. Emit turn update and return merge result.
func kup_a_slouc_armadni_nabidku(state_tag: String, offer_index: int, target_uid: String) -> Dictionary:
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if target_uid.strip_edges() == "":
		return {"ok": false, "reason": "Invalid merge target."}

	_arm_lab_zajisti_nabidky(cisty)
	var lab = _zajisti_armadni_lab_statu(cisty)
	var offers = lab.get("offers", []) as Array
	if offer_index < 0 or offer_index >= offers.size():
		return {"ok": false, "reason": "Invalid offer selection."}

	var offer = offers[offer_index] as Dictionary
	var cost = float(offer.get("cost", 0.0))
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {"ok": false, "reason": "Not enough money.", "cost": cost, "treasury": treasury}

	var grid_items = lab.get("grid_items", []) as Array
	var dst_idx := -1
	for i in range(grid_items.size()):
		var it = grid_items[i] as Dictionary
		if str(it.get("offer_uid", "")) == target_uid:
			dst_idx = i
			break
	if dst_idx < 0:
		return {"ok": false, "reason": "Target item for merge was not found."}

	var dst = grid_items[dst_idx] as Dictionary
	if str(offer.get("id", "")) != str(dst.get("id", "")):
		return {"ok": false, "reason": "Only the same item types can be merged."}
	if int(offer.get("level", 1)) != int(dst.get("level", 1)):
		return {"ok": false, "reason": "Items must have the same level."}

	var combined_flat = int(round((int(offer.get("power_flat", 0)) + int(dst.get("power_flat", 0))) * ARM_LAB_MERGE_POWER_MULT))
	var combined_pct = (float(offer.get("power_pct", 0.0)) + float(dst.get("power_pct", 0.0))) * ARM_LAB_MERGE_POWER_MULT
	dst["level"] = int(dst.get("level", 1)) + 1
	dst["tier"] = max(int(dst.get("tier", 1)), int(offer.get("tier", 1)))
	dst["power_flat"] = max(1, combined_flat)
	dst["power_pct"] = max(0.0, combined_pct)
	dst["cost"] = max(float(dst.get("cost", 0.0)), float(offer.get("cost", 0.0)))
	grid_items[dst_idx] = dst
	lab["grid_items"] = grid_items

	offers.remove_at(offer_index)
	while offers.size() < ARM_LAB_OFFER_COUNT:
		offers.append(_arm_lab_vytvor_random_offer(int(lab.get("quality_level", 0))))
	lab["offers"] = offers
	armadni_lab_statu[cisty] = lab

	_nastav_kasu_statu(cisty, treasury - cost)
	_money_debug_expense(cisty, "army_lab_merge_buy", cost, treasury, _ziskej_kasu_statu(cisty), "offer=%d target=%s" % [offer_index, target_uid])
	kolo_zmeneno.emit()
	return {
		"ok": true,
		"target_uid": target_uid,
		"new_level": int(dst.get("level", 1)),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

# Runs the local feature logic.
# Inputs: `state_tag` owner state tag, `item_uid` moved item id, `target_x` and `target_y` destination grid coordinates.
# Outputs: Dictionary with move result (`ok`) and resulting item position, or failure reason.
# Execution timing: Triggered by army-lab item drag/drop or manual reposition actions.
# Steps: Validates state and item, checks placement collision rules, updates stored grid coordinates, and emits refresh signal.
func presun_armadni_item(state_tag: String, item_uid: String, target_x: int, target_y: int) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `item_uid`: Item to move.
	# - `target_x`: Target grid x.
	# - `target_y`: Target grid y.
	# Outputs:
	# - `Dictionary`: Move result or error payload.
	# Execution timing: Called by army-lab drag/drop operations.
	# Steps:
	# 1. Validate state/item and locate source item.
	# 2. Validate placement with ignore-self collision logic.
	# 3. Update item coordinates and persist lab state.
	# 4. Emit turn-change signal and return result.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if item_uid.strip_edges() == "":
		return {"ok": false, "reason": "Invalid item."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	var grid_items = lab.get("grid_items", []) as Array
	var found_idx := -1
	for i in range(grid_items.size()):
		var item = grid_items[i] as Dictionary
		if str(item.get("offer_uid", "")) == item_uid:
			found_idx = i
			break
	if found_idx < 0:
		return {"ok": false, "reason": "Item was not found in the grid."}

	var moving = grid_items[found_idx] as Dictionary
	var w = int(moving.get("w", 1))
	var h = int(moving.get("h", 1))
	var unlocked = _arm_lab_odemcene_dict(lab)
	var dims = _arm_lab_obsah_mrizky_odemykani(unlocked)
	var grid_w = int(dims.get("w", ARM_LAB_GRID_W))
	var grid_h = int(dims.get("h", ARM_LAB_GRID_H))
	if not _arm_lab_muze_umistit_na_ignorovat(grid_items, w, h, target_x, target_y, item_uid, grid_w, grid_h, unlocked):
		return {"ok": false, "reason": "Item cannot be moved here."}

	moving["x"] = target_x
	moving["y"] = target_y
	grid_items[found_idx] = moving
	lab["grid_items"] = grid_items
	armadni_lab_statu[cisty] = lab

	kolo_zmeneno.emit()
	return {
		"ok": true,
		"item_uid": item_uid,
		"x": target_x,
		"y": target_y
	}

# Inputs: `state_tag` state tag buying expansion.
# Outputs: Dictionary describing expansion attempt result.
# Execution timing: Called by quick-expand action in army-lab UI.
# Steps: Finds first currently purchasable grid cell and delegates purchase to `koupit_armadni_bunku`.
func rozsirit_armadni_mrizku(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Expansion purchase result or failure payload.
	# Execution timing: Called by quick-expand UI action.
	# Steps:
	# 1. Validate state.
	# 2. Scan for first valid expansion candidate cell.
	# 3. Delegate actual purchase to `koupit_armadni_bunku()`.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}
	var lab = _zajisti_armadni_lab_statu(cisty)
	var unlocked = _arm_lab_odemcene_dict(lab)
	for y in range(ARM_LAB_GRID_MAX_H):
		for x in range(ARM_LAB_GRID_MAX_W):
			if _arm_lab_je_kandidat_expanze(unlocked, x, y):
				return koupit_armadni_bunku(cisty, x, y)
	return {"ok": false, "reason": "Grid is already at maximum size."}

# Handles this gameplay/UI path.
# Inputs: `state_tag` buyer state tag, `x` and `y` target cell coordinates.
# Outputs: Dictionary with unlocked cell, new grid size, and treasury-after value.
# Execution timing: Called when player chooses a concrete expansion cell.
# Steps: Validates candidate cell and budget, unlocks cell, recalculates visible grid bounds, deducts cost, emits update.
func koupit_armadni_bunku(state_tag: String, x: int, y: int) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `x`: Cell x.
	# - `y`: Cell y.
	# Outputs:
	# - `Dictionary`: Cell purchase result with updated grid and treasury.
	# Execution timing: Called when buying a specific grid expansion cell.
	# Steps:
	# 1. Validate state and candidate cell.
	# 2. Compute expansion cost and verify treasury.
	# 3. Unlock cell and recompute grid dimensions.
	# 4. Deduct money, emit update, and return payload.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	var unlocked = _arm_lab_odemcene_dict(lab)
	if unlocked.size() >= (ARM_LAB_GRID_MAX_W * ARM_LAB_GRID_MAX_H):
		return {"ok": false, "reason": "Grid is already at maximum size."}
	if not _arm_lab_je_kandidat_expanze(unlocked, x, y):
		return {"ok": false, "reason": "This cell cannot be bought right now."}

	var expanded_cells = max(0, unlocked.size() - (ARM_LAB_GRID_W * ARM_LAB_GRID_H))
	var cost = snapped(ARM_LAB_EXPAND_BASE_COST + float(expanded_cells) * ARM_LAB_EXPAND_STEP_COST, 0.01)
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {"ok": false, "reason": "Not enough money for expansion.", "cost": cost, "treasury": treasury}

	unlocked["%d_%d" % [x, y]] = true
	lab["unlocked_cells"] = _arm_lab_odemcene_array(unlocked)
	var dims = _arm_lab_obsah_mrizky_odemykani(unlocked)
	lab["grid_w"] = int(dims.get("w", ARM_LAB_GRID_W))
	lab["grid_h"] = int(dims.get("h", ARM_LAB_GRID_H))
	armadni_lab_statu[cisty] = lab
	_nastav_kasu_statu(cisty, treasury - cost)
	_money_debug_expense(cisty, "army_lab_expand", cost, treasury, _ziskej_kasu_statu(cisty), "cell=%d,%d" % [x, y])
	kolo_zmeneno.emit()
	return {
		"ok": true,
		"x": x,
		"y": y,
		"grid_w": int(lab.get("grid_w", ARM_LAB_GRID_W)),
		"grid_h": int(lab.get("grid_h", ARM_LAB_GRID_H)),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

# Ai generated or editted start (priloha_a.txt)
# Inputs: `state_tag` owner state tag, `item_uid` item identifier to sell.
# Outputs: Dictionary with sold value and treasury-after snapshot.
# Execution timing: Called by army-lab item sell action.
# Steps: Locates selected item, computes sell return ratio, removes item from grid, credits treasury, emits update.
func prodej_armadni_item(state_tag: String, item_uid: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `item_uid`: Item to sell.
	# Outputs:
	# - `Dictionary`: Sale result with payout and treasury.
	# Execution timing: Called by army-lab sell actions.
	# Steps:
	# 1. Validate state/item and locate item.
	# 2. Compute sell value from stored item cost.
	# 3. Remove item from grid and persist.
	# 4. Add money, emit update, and return result.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if item_uid.strip_edges() == "":
		return {"ok": false, "reason": "Invalid item."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	var grid_items = lab.get("grid_items", []) as Array
	var found_idx := -1
	var found_item: Dictionary = {}
	for i in range(grid_items.size()):
		var it = grid_items[i] as Dictionary
		if str(it.get("offer_uid", "")) == item_uid:
			found_idx = i
			found_item = it
			break
	if found_idx < 0:
		return {"ok": false, "reason": "Item was not found in the grid."}

	var base_cost = max(0.0, float(found_item.get("cost", 0.0)))
	var sell_value = snapped(base_cost * ARM_LAB_SELL_RETURN_RATIO, 0.01)
	grid_items.remove_at(found_idx)
	lab["grid_items"] = grid_items
	armadni_lab_statu[cisty] = lab

	var treasury = _ziskej_kasu_statu(cisty)
	_nastav_kasu_statu(cisty, treasury + sell_value)
	_money_debug_income_event(cisty, "army_lab_sell", sell_value, treasury, _ziskej_kasu_statu(cisty), "item=%s" % item_uid)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"item_uid": item_uid,
		"sold_for": sell_value,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

# Ai generated or editted end (priloha_a.txt)
# Inputs: `state_tag` owner state, `source_uid` source item id, `target_uid` target item id.
# Outputs: Dictionary with merge result and resulting target level.
# Execution timing: Called when player merges two placed army-lab items.
# Steps: Validates pair compatibility, combines stats with merge multiplier, removes source item, persists target changes.
func sloucit_armadni_itemy(state_tag: String, source_uid: String, target_uid: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `source_uid`: Source item uid.
	# - `target_uid`: Target item uid.
	# Outputs:
	# - `Dictionary`: Merge result or error payload.
	# Execution timing: Called when merging two placed lab items.
	# Steps:
	# 1. Validate state and both item ids.
	# 2. Locate source/target items and verify compatibility.
	# 3. Compute merged stats and update target item.
	# 4. Remove source item, persist state, emit update.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if source_uid.strip_edges() == "" or target_uid.strip_edges() == "" or source_uid == target_uid:
		return {"ok": false, "reason": "Invalid item combination."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	var grid_items = lab.get("grid_items", []) as Array
	var src_idx := -1
	var dst_idx := -1
	for i in range(grid_items.size()):
		var it = grid_items[i] as Dictionary
		var uid = str(it.get("offer_uid", ""))
		if uid == source_uid:
			src_idx = i
		elif uid == target_uid:
			dst_idx = i
	if src_idx < 0 or dst_idx < 0:
		return {"ok": false, "reason": "Item was not found."}

	var src = grid_items[src_idx] as Dictionary
	var dst = grid_items[dst_idx] as Dictionary
	if str(src.get("id", "")) != str(dst.get("id", "")):
		return {"ok": false, "reason": "Only the same item types can be merged."}
	var src_lvl = int(src.get("level", 1))
	var dst_lvl = int(dst.get("level", 1))
	if src_lvl != dst_lvl:
		return {"ok": false, "reason": "Items must have the same level."}

	var combined_flat = int(round((int(src.get("power_flat", 0)) + int(dst.get("power_flat", 0))) * ARM_LAB_MERGE_POWER_MULT))
	var combined_pct = (float(src.get("power_pct", 0.0)) + float(dst.get("power_pct", 0.0))) * ARM_LAB_MERGE_POWER_MULT
	dst["level"] = dst_lvl + 1
	dst["tier"] = max(int(dst.get("tier", 1)), int(src.get("tier", 1)))
	dst["power_flat"] = max(1, combined_flat)
	dst["power_pct"] = max(0.0, combined_pct)
	dst["cost"] = max(float(dst.get("cost", 0.0)), float(src.get("cost", 0.0)))

	grid_items[dst_idx] = dst
	grid_items.remove_at(src_idx)
	lab["grid_items"] = grid_items
	armadni_lab_statu[cisty] = lab
	kolo_zmeneno.emit()
	return {
		"ok": true,
		"target_uid": target_uid,
		"new_level": int(dst.get("level", 1))
	}

# Handles this gameplay/UI path.
# Inputs: `state_tag` state tag.
# Outputs: Dictionary with reroll cost and refreshed treasury state.
# Execution timing: Called from army-lab offer reroll button.
# Steps: Computes dynamic reroll price for current turn, regenerates offer list, increments reroll counter, deducts funds.
func reroll_armadni_nabidky(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Reroll result with new offers and treasury.
	# Execution timing: Called by army-lab reroll button.
	# Steps:
	# 1. Validate state and ensure current offers.
	# 2. Compute reroll cost from per-turn reroll count.
	# 3. Validate treasury and generate new offers.
	# 4. Increment reroll counter, deduct money, emit update.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	if int(lab.get("offers_turn", -1)) != aktualni_kolo:
		_arm_lab_zajisti_nabidky(cisty)
		lab = _zajisti_armadni_lab_statu(cisty)

	var rerolls = int(lab.get("rerolls_this_turn", 0))
	var cost = snapped(ARM_LAB_REROLL_BASE_COST + float(rerolls) * 4.0, 0.01)
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {"ok": false, "reason": "Not enough money for reroll.", "cost": cost, "treasury": treasury}

	var offers: Array = []
	for _i in range(ARM_LAB_OFFER_COUNT):
		offers.append(_arm_lab_vytvor_random_offer(int(lab.get("quality_level", 0))))

	lab["offers"] = offers
	lab["offers_turn"] = aktualni_kolo
	lab["rerolls_this_turn"] = rerolls + 1
	armadni_lab_statu[cisty] = lab

	_nastav_kasu_statu(cisty, treasury - cost)
	_money_debug_expense(cisty, "army_lab_reroll", cost, treasury, _ziskej_kasu_statu(cisty), "rerolls=%d" % (rerolls + 1))
	kolo_zmeneno.emit()

	return {"ok": true, "cost": cost, "treasury_after": _ziskej_kasu_statu(cisty)}

# Handles this gameplay/UI path.
func vylepsi_kvalitu_dropu_armady(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Upgrade result with new quality level and treasury.
	# Execution timing: Called by quality-upgrade UI action.
	# Steps:
	# 1. Validate state and current quality level.
	# 2. Compute upgrade cost and verify treasury.
	# 3. Increase quality level and refresh offers.
	# 4. Deduct money, emit update, and return result.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	var lab = _zajisti_armadni_lab_statu(cisty)
	var current_level = _clamp_arm_lab_quality(int(lab.get("quality_level", 0)))
	if current_level >= 8:
		return {"ok": false, "reason": "Drop quality is already at maximum."}

	var cost = snapped(ARM_LAB_QUALITY_UPGRADE_BASE_COST + float(current_level) * 16.0, 0.01)
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {"ok": false, "reason": "Not enough money for quality upgrade.", "cost": cost, "treasury": treasury}

	lab["quality_level"] = current_level + 1
	lab["offers_turn"] = -1
	lab["offers"] = []
	lab["rerolls_this_turn"] = 0
	armadni_lab_statu[cisty] = lab
	_nastav_kasu_statu(cisty, treasury - cost)
	_money_debug_expense(cisty, "army_lab_quality", cost, treasury, _ziskej_kasu_statu(cisty), "new_level=%d" % int(lab.get("quality_level", 0)))

	# New quality applies immediately with a free offer refresh.
	_arm_lab_zajisti_nabidky(cisty)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"new_quality_level": int(lab.get("quality_level", 0)),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

func _zajisti_vyzkum_statu(tag: String) -> Array:
	# Inputs:
	# - `tag`: State tag.
	# Outputs:
	# - `Array`: Guaranteed array of completed research ids.
	# Execution timing: Called before any research read/write.
	# Steps:
	# 1. Normalize and validate state tag.
	# 2. Initialize missing/invalid research entry as array.
	# 3. Return stored research array.
	var cisty = _normalizuj_tag(tag)
	if cisty == "" or cisty == "SEA":
		return []
	if not vyzkum_statu.has(cisty):
		vyzkum_statu[cisty] = []
	var research_any = vyzkum_statu.get(cisty, [])
	if not (research_any is Array):
		vyzkum_statu[cisty] = []
		return vyzkum_statu[cisty] as Array
	return research_any as Array

# Returns true when conditions are met.
func je_vyzkum_hotovy(state_tag: String, project_id: String) -> bool:
	# Inputs:
	# - `state_tag`: State tag.
	# - `project_id`: Research project id.
	# Outputs:
	# - `bool`: True when project is already completed.
	# Execution timing: Called by research UI and modifiers pipeline.
	# Steps:
	# 1. Validate project id.
	# 2. Read state's completed-research array.
	# 3. Check membership.
	if not RESEARCH_PROJECTS_ENABLED:
		return false
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or project_id.strip_edges() == "":
		return false
	var completed = _zajisti_vyzkum_statu(cisty)
	return completed.has(project_id)

# Read-only data accessor.
func ziskej_vyzkum_projekty() -> Array:
	# Inputs: none
	# Outputs:
	# - `Array`: UI-ready list of research project definitions.
	# Execution timing: Called when building research menus.
	# Steps:
	# 1. Iterate project definition dictionary.
	# 2. Build normalized dictionaries with required fields.
	# 3. Sort/return project list.
	if not RESEARCH_PROJECTS_ENABLED:
		return []
	var out: Array = []
	for key in VYZKUM_PROJEKTY.keys():
		var p = (VYZKUM_PROJEKTY[key] as Dictionary).duplicate(true)
		out.append(p)
	out.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		var cat_a = str(da.get("category", ""))
		var cat_b = str(db.get("category", ""))
		if cat_a == cat_b:
			return str(da.get("name", "")) < str(db.get("name", ""))
		return cat_a < cat_b
	)
	return out

# Read-only data accessor.
func ziskej_vyzkum_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: State research status, treasury, and project data.
	# Execution timing: Called by research panel refresh.
	# Steps:
	# 1. Validate state existence.
	# 2. Load completed project ids.
	# 3. Build project list with completion flags and affordability.
	# 4. Return aggregate payload.
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {
			"ok": false,
			"reason": "Invalid state.",
			"projects": [],
			"completed": [],
			"treasury": 0.0
		}
	if not RESEARCH_PROJECTS_ENABLED:
		return {
			"ok": true,
			"state": cisty,
			"projects": [],
			"completed": [],
			"treasury": _ziskej_kasu_statu(cisty)
		}

	var completed = _zajisti_vyzkum_statu(cisty)
	var out_projects: Array = []
	for key in VYZKUM_PROJEKTY.keys():
		var base = VYZKUM_PROJEKTY[key] as Dictionary
		var project = base.duplicate(true)
		project["done"] = completed.has(str(project.get("id", key)))
		out_projects.append(project)

	out_projects.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		var cat_a = str(da.get("category", ""))
		var cat_b = str(db.get("category", ""))
		if cat_a == cat_b:
			return str(da.get("name", "")) < str(db.get("name", ""))
		return cat_a < cat_b
	)

	return {
		"ok": true,
		"state": cisty,
		"projects": out_projects,
		"completed": completed.duplicate(),
		"treasury": _ziskej_kasu_statu(cisty)
	}

func muze_vyzkoumat_projekt(state_tag: String, project_id: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `project_id`: Project id.
	# Outputs:
	# - `Dictionary`: Eligibility result and reason/cost details.
	# Execution timing: Called before enabling research purchase actions.
	# Steps:
	# 1. Validate state and project.
	# 2. Check if already completed.
	# 3. Validate treasury against project cost.
	# 4. Return structured eligibility result.
	if not RESEARCH_PROJECTS_ENABLED:
		return {"ok": false, "reason": "Research projects are temporarily disabled."}
	var cisty = _normalizuj_tag(state_tag)
	var pid = project_id.strip_edges()
	if cisty == "" or cisty == "SEA":
		return {"ok": false, "reason": "Invalid state."}
	if pid == "" or not VYZKUM_PROJEKTY.has(pid):
		return {"ok": false, "reason": "Unknown research."}
	if not _stat_existuje(cisty):
		return {"ok": false, "reason": "State does not exist on the current map."}

	var completed = _zajisti_vyzkum_statu(cisty)
	if completed.has(pid):
		return {"ok": false, "reason": "Research is already completed."}

	var project = VYZKUM_PROJEKTY[pid] as Dictionary
	var cost = float(project.get("cost", 0.0))
	var treasury = _ziskej_kasu_statu(cisty)
	if treasury < cost:
		return {
			"ok": false,
			"reason": "Not enough money for research.",
			"cost": cost,
			"treasury": treasury
		}

	return {
		"ok": true,
		"state": cisty,
		"project": project.duplicate(true),
		"cost": cost,
		"treasury": treasury
	}

# Handles this gameplay/UI path.
func proved_vyzkum_projektu(state_tag: String, project_id: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `project_id`: Project id to complete.
	# Outputs:
	# - `Dictionary`: Completion result with updated treasury/status.
	# Execution timing: Called when player confirms research purchase.
	# Steps:
	# 1. Validate eligibility via guard checks.
	# 2. Deduct project cost from state treasury.
	# 3. Append project id to completed list.
	# 4. Emit update and return success payload.
	var check = muze_vyzkoumat_projekt(state_tag, project_id)
	if not bool(check.get("ok", false)):
		return check

	var cisty = _normalizuj_tag(state_tag)
	var pid = project_id.strip_edges()
	var project = VYZKUM_PROJEKTY[pid] as Dictionary
	var cost = float(project.get("cost", 0.0))

	var current_treasury = _ziskej_kasu_statu(cisty)
	_nastav_kasu_statu(cisty, current_treasury - cost)
	_money_debug_expense(cisty, "research", cost, current_treasury, _ziskej_kasu_statu(cisty), "project=%s" % pid)

	var completed = _zajisti_vyzkum_statu(cisty)
	completed.append(pid)
	vyzkum_statu[cisty] = completed

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"state": cisty,
		"project_id": pid,
		"project": project.duplicate(true),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

# Pulls current state data.
func _ziskej_modifikatory_vyzkumu_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Aggregated research modifiers for completed projects.
	# Execution timing: Called by economy/recruitment calculations.
	# Steps:
	# 1. Get completed projects for state.
	# 2. Iterate project modifier dictionaries.
	# 3. Combine modifier values into aggregate result.
	var out := {
		"recruit_cost_mult": 1.0,
		"upkeep_mult": 1.0,
		"income_rate_mult": 1.0,
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0
	}
	if not RESEARCH_PROJECTS_ENABLED:
		return out

	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return out

	var completed = _zajisti_vyzkum_statu(cisty)
	for pid_any in completed:
		var pid = str(pid_any)
		if not VYZKUM_PROJEKTY.has(pid):
			continue
		var project = VYZKUM_PROJEKTY[pid] as Dictionary
		var modifiers = project.get("modifiers", {}) as Dictionary
		for k in modifiers.keys():
			if not out.has(k):
				continue
			out[k] = float(out[k]) * float(modifiers[k])

	return out

# Returns current runtime data.
func _ziskej_ideologii_statu(tag: String) -> String:
	# Inputs:
	# - `tag`: State tag.
	# Outputs:
	# - `String`: State ideology key.
	# Execution timing: Called by economy/diplomacy/AI heuristics.
	# Steps:
	# 1. Normalize state tag.
	# 2. Locate state's ideology from map data.
	# 3. Normalize and return ideology value.
	var wanted = _normalizuj_tag(tag)
	if wanted == "" or wanted == "SEA":
		return ""
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == wanted:
			return _normalizuj_ideologii(str(d.get("ideology", "")))
	return ""

# Pulls current state data.
func ziskej_ekonomicke_modifikatory_statu(state_tag: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `Dictionary`: Combined ideology + research + state modifiers.
	# Execution timing: Called by economy/recruit/upkeep calculations.
	# Steps:
	# 1. Resolve state's ideology.
	# 2. Fetch ideology modifiers.
	# 3. Merge in research/state modifiers and return.
	var clean = _normalizuj_tag(state_tag)
	if _ai_phase_cache_active and clean != "" and clean != "SEA" and _ai_econ_mods_cache.has(clean):
		return (_ai_econ_mods_cache[clean] as Dictionary).duplicate(true)
	var base = _ziskej_ekonomicke_modifikatory_ideologie(_ziskej_ideologii_statu(state_tag))
	var research = _ziskej_modifikatory_vyzkumu_statu(state_tag)
	for k in research.keys():
		if not base.has(k):
			continue
		base[k] = float(base[k]) * float(research[k])
	var building_mods = _ziskej_modifikatory_budov_statu(state_tag)
	for k in building_mods.keys():
		if not base.has(k):
			continue
		base[k] = float(base[k]) * float(building_mods[k])
	if _ai_phase_cache_active and clean != "" and clean != "SEA":
		_ai_econ_mods_cache[clean] = base.duplicate(true)
	return base

# Returns current runtime data.
func ziskej_cenu_za_vojaka(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `float`: Recruit cost per soldier for the state.
	# Execution timing: Called by recruitment cost calculations.
	# Steps:
	# 1. Resolve state economic modifiers.
	# 2. Multiply base recruit cost by modifier.
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_RECRUIT_COST_PER_SOLDIER * max(0.01, float(mods.get("recruit_cost_mult", 1.0)))

# Returns current runtime data.
func ziskej_udrzbu_za_vojaka(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `float`: Upkeep cost per soldier.
	# Execution timing: Called by finance tick calculations.
	# Steps:
	# 1. Resolve state modifiers.
	# 2. Multiply base upkeep by modifier.
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_UPKEEP_PER_SOLDIER * max(0.01, float(mods.get("upkeep_mult", 1.0)))

# Computes derived values from current inputs and game state.
func ziskej_udrzbu_za_vojaka_v_provincii(state_tag: String, prov_id: int) -> float:
	# Inputs:
	# - `state_tag`: State tag.
	# - `prov_id`: Province id.
	# Outputs:
	# - `float`: Province-adjusted upkeep cost per soldier.
	# Execution timing: Called when computing local upkeep impact.
	# Steps:
	# 1. Get base state upkeep.
	# 2. Apply province building modifiers.
	# 3. Return adjusted upkeep value.
	# Province upkeep is state upkeep multiplied by province-only building modifiers.
	# When province lookup fails, we gracefully fall back to pure state upkeep.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return 0.0
	if not map_data.has(prov_id):
		return ziskej_udrzbu_za_vojaka(state)
	var d = map_data[prov_id] as Dictionary
	if _normalizuj_tag(str(d.get("owner", ""))) != state:
		return ziskej_udrzbu_za_vojaka(state)
	var base_upkeep = ziskej_udrzbu_za_vojaka(state)
	var prov_mods = _ziskej_modifikatory_budov_provincie(prov_id)
	var local_mult = max(0.01, float(prov_mods.get("upkeep_mult", 1.0)))
	return base_upkeep * local_mult

# Computes derived values from current inputs and game state.
func _spocitej_naklady_udrzby_statu(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `float`: Total upkeep costs for all soldiers in state provinces.
	# Execution timing: Called during end-turn financial processing.
	# Steps:
	# 1. Iterate state-owned provinces.
	# 2. Compute per-province upkeep for local soldier counts.
	# 3. Sum and return total cost.
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return 0.0
	var total_upkeep := 0.0
	for p_id_any in map_data.keys():
		var p_id = int(p_id_any)
		var d = map_data[p_id] as Dictionary
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		var soldiers = max(0, int(d.get("soldiers", 0)))
		if soldiers <= 0:
			continue
		total_upkeep += float(soldiers) * ziskej_udrzbu_za_vojaka_v_provincii(state, p_id)
	return total_upkeep

# Returns current runtime data.
func ziskej_prijmovou_sazbu_hdp(state_tag: String) -> float:
	# Inputs:
	# - `state_tag`: State tag.
	# Outputs:
	# - `float`: Effective GDP income rate.
	# Execution timing: Called by income projection and end-turn income flow.
	# Steps:
	# 1. Resolve economic modifiers.
	# 2. Multiply base income rate by modifier.
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_INCOME_RATE * max(0.01, float(mods.get("income_rate_mult", 1.0)))

func _spocitej_zmeny_vztahu_po_ideologii(state: String, target_ideology: String) -> Array:
	# Inputs:
	# - `state`: State tag changing ideology.
	# - `target_ideology`: Target ideology key.
	# Outputs:
	# - `Array`: Planned relation deltas against other states.
	# Execution timing: Called by ideology preview/apply flows.
	# Steps:
	# 1. Compare target ideology against other-state ideologies.
	# 2. Compute similarity/opposition relation deltas.
	# 3. Return change list.
	var relation_changes: Array = []
	for other_state in _ziskej_aktivni_staty():
		var other = _normalizuj_tag(str(other_state))
		if other == "" or other == state:
			continue

		var other_ideology = _ziskej_ideologii_statu(other)
		var delta := 0.0
		if _jsou_ideologie_podobne(target_ideology, other_ideology):
			delta = IDEOLOGY_RELATION_SIMILAR_BONUS
		elif _jsou_ideologie_uplne_odlisne(target_ideology, other_ideology):
			delta = -IDEOLOGY_RELATION_OPPOSITE_PENALTY

		if is_zero_approx(delta):
			continue

		var old_relation = ziskej_vztah_statu(state, other)
		relation_changes.append({
			"other_state": other,
			"other_ideology": other_ideology,
			"delta": delta,
			"old_relation": old_relation,
			"new_relation": clamp(old_relation + delta, RELATION_MIN, RELATION_MAX)
		})
	return relation_changes

# Preview and apply share same math, aby preview nekecal jinak nez final apply.
# Handles this gameplay/UI path.
func _nahled_nebo_aplikace_ideologie_statistik(state: String, old_ideology: String, new_ideology: String, apply_changes: bool) -> Dictionary:
	# Inputs:
	# - `state`: State tag.
	# - `old_ideology`: Current ideology.
	# - `new_ideology`: Target ideology.
	# - `apply_changes`: `true` applies effects, `false` preview only.
	# Outputs:
	# - `Dictionary`: Preview/apply result with stat and relation deltas.
	# Execution timing: Core worker for ideology preview and commit actions.
	# Steps:
	# 1. Normalize ideologies and compute economic/stat deltas.
	# 2. Compute relation-change impacts with other states.
	# 3. Optionally apply map/relation/finance mutations.
	# 4. Return detailed result payload.
	var old_mods = _ziskej_statove_modifikatory_ideologie(old_ideology)
	var new_mods = _ziskej_statove_modifikatory_ideologie(new_ideology)

	var old_gdp_mult = max(0.01, float(old_mods.get("gdp_mult", 1.0)))
	var new_gdp_mult = max(0.01, float(new_mods.get("gdp_mult", 1.0)))
	var gdp_ratio = new_gdp_mult / old_gdp_mult
	var new_recruit_mult = max(0.01, float(new_mods.get("recruit_mult", 1.0)))

	var total_old_pop := 0
	var total_new_pop := 0
	var total_old_gdp := 0.0
	var total_new_gdp := 0.0
	var total_old_recruit := 0
	var total_new_recruit := 0
	var total_old_soldiers := 0
	var total_new_soldiers := 0
	var modified_provinces := 0

	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue

		modified_provinces += 1
		var old_pop = int(d.get("population", 0))
		var old_gdp = float(d.get("gdp", 0.0))
		var old_soldiers = int(d.get("soldiers", 0))

		var old_cap = int(d.get("base_recruitable_population", d.get("recruitable_population", 0)))
		if old_cap < 0:
			old_cap = 0
		var old_recruit = int(d.get("recruitable_population", old_cap))
		old_recruit = clampi(old_recruit, 0, old_cap)

		var raw_base = int(d.get("base_recruitable_population_raw", old_cap))
		if raw_base < 0:
			raw_base = 0

		var recruit_fill_ratio = 0.0
		if old_cap > 0:
			recruit_fill_ratio = float(old_recruit) / float(old_cap)

		var new_gdp = max(0.0, old_gdp * gdp_ratio)
		var new_cap = max(0, int(round(float(raw_base) * new_recruit_mult)))
		var new_recruit = clampi(int(round(float(new_cap) * recruit_fill_ratio)), 0, new_cap)

		total_old_pop += old_pop
		total_new_pop += old_pop
		total_old_gdp += old_gdp
		total_new_gdp += new_gdp
		total_old_recruit += old_recruit
		total_new_recruit += new_recruit
		total_old_soldiers += old_soldiers
		total_new_soldiers += old_soldiers

		if apply_changes:
			d["gdp"] = new_gdp
			d["base_recruitable_population_raw"] = raw_base
			d["base_recruitable_population"] = new_cap
			d["recruitable_population"] = new_recruit

	var old_econ = _ziskej_ekonomicke_modifikatory_ideologie(old_ideology)
	var new_econ = _ziskej_ekonomicke_modifikatory_ideologie(new_ideology)
	var old_income_rate = BASE_INCOME_RATE * float(old_econ.get("income_rate_mult", 1.0))
	var new_income_rate = BASE_INCOME_RATE * float(new_econ.get("income_rate_mult", 1.0))
	var old_upkeep_per_soldier = BASE_UPKEEP_PER_SOLDIER * float(old_econ.get("upkeep_mult", 1.0))
	var new_upkeep_per_soldier = BASE_UPKEEP_PER_SOLDIER * float(new_econ.get("upkeep_mult", 1.0))
	var old_income = (total_old_gdp * old_income_rate) - (float(total_old_soldiers) * old_upkeep_per_soldier)
	var new_income = (total_new_gdp * new_income_rate) - (float(total_new_soldiers) * new_upkeep_per_soldier)

	return {
		"modified_provinces": modified_provinces,
		"old_totals": {
			"population": total_old_pop,
			"gdp": total_old_gdp,
			"recruitable_population": total_old_recruit
		},
		"new_totals": {
			"population": total_new_pop,
			"gdp": total_new_gdp,
			"recruitable_population": total_new_recruit,
			"soldiers": total_new_soldiers,
			"income": new_income
		},
		"delta": {
			"population": total_new_pop - total_old_pop,
			"gdp": total_new_gdp - total_old_gdp,
			"recruitable_population": total_new_recruit - total_old_recruit,
			"income": new_income - old_income
		},
		"modifiers": {
			"old_gdp_mult": old_gdp_mult,
			"new_gdp_mult": new_gdp_mult,
			"gdp_ratio": gdp_ratio,
			"old_recruit_mult": float(old_mods.get("recruit_mult", 1.0)),
			"new_recruit_mult": new_recruit_mult,
			"old_income_rate": old_income_rate,
			"new_income_rate": new_income_rate,
			"old_upkeep_per_soldier": old_upkeep_per_soldier,
			"new_upkeep_per_soldier": new_upkeep_per_soldier,
			"old_recruit_cost": BASE_RECRUIT_COST_PER_SOLDIER * float(old_econ.get("recruit_cost_mult", 1.0)),
			"new_recruit_cost": BASE_RECRUIT_COST_PER_SOLDIER * float(new_econ.get("recruit_cost_mult", 1.0)),
			"old_gdp_growth": BASE_GDP_GROWTH_PER_TURN * float(old_econ.get("gdp_growth_mult", 1.0)),
			"new_gdp_growth": BASE_GDP_GROWTH_PER_TURN * float(new_econ.get("gdp_growth_mult", 1.0)),
			"old_pop_growth_ratio": BASE_POP_GROWTH_RATIO * float(old_econ.get("population_growth_mult", 1.0)),
			"new_pop_growth_ratio": BASE_POP_GROWTH_RATIO * float(new_econ.get("population_growth_mult", 1.0))
		}
	}

# Handles this gameplay/UI path.
func nahled_zmeny_ideologie_statu(state_tag: String, new_ideology: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `new_ideology`: Target ideology.
	# Outputs:
	# - `Dictionary`: Ideology-change preview payload.
	# Execution timing: Called by ideology-change UI preview.
	# Steps:
	# 1. Resolve current ideology.
	# 2. Delegate to shared preview/apply helper with `apply=false`.
	var state = _normalizuj_tag(state_tag)
	var target_ideology = _normalizuj_ideologii(new_ideology)
	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid country."}
	if target_ideology == "":
		return {"ok": false, "reason": "Invalid ideology."}
	if not _stat_existuje(state):
		return {"ok": false, "reason": "Country does not exist on current map."}

	var old_ideology = _ziskej_ideologii_statu(state)
	var relation_changes: Array = []
	if old_ideology != target_ideology:
		relation_changes = _spocitej_zmeny_vztahu_po_ideologii(state, target_ideology)

	var stat_changes = _nahled_nebo_aplikace_ideologie_statistik(state, old_ideology, target_ideology, false)

	return {
		"ok": true,
		"changed": old_ideology != target_ideology,
		"state": state,
		"old_ideology": old_ideology,
		"new_ideology": target_ideology,
		"relation_changes": relation_changes,
		"stat_changes": stat_changes
	}

func zmen_ideologii_statu(state_tag: String, new_ideology: String) -> Dictionary:
	# Inputs:
	# - `state_tag`: State tag.
	# - `new_ideology`: Target ideology.
	# Outputs:
	# - `Dictionary`: Apply result with updated state data.
	# Execution timing: Called when confirming ideology change.
	# Steps:
	# 1. Validate state and ideology transition.
	# 2. Delegate to shared helper with `apply=true`.
	# 3. Emit updates and return applied result.
	var state = _normalizuj_tag(state_tag)
	var target_ideology = _normalizuj_ideologii(new_ideology)
	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid country."}
	if target_ideology == "":
		return {"ok": false, "reason": "Invalid ideology."}
	if not _stat_existuje(state):
		return {"ok": false, "reason": "Country does not exist on current map."}

	var preview = nahled_zmeny_ideologie_statu(state, target_ideology)
	if not bool(preview.get("ok", false)):
		return preview

	var old_ideology = str(preview.get("old_ideology", ""))
	if not bool(preview.get("changed", false)):
		return preview

	var stat_changes = _nahled_nebo_aplikace_ideologie_statistik(state, old_ideology, target_ideology, true)

	var modified_provinces := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		d["ideology"] = target_ideology
		modified_provinces += 1

	var relation_changes = preview.get("relation_changes", []) as Array
	for change in relation_changes:
		var c = change as Dictionary
		var other = _normalizuj_tag(str(c.get("other_state", "")))
		if other == "":
			continue
		var delta = float(c.get("delta", 0.0))
		_uprav_vztah_statu_bez_cooldown(state, other, delta)

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

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"changed": true,
		"state": state,
		"old_ideology": old_ideology,
		"new_ideology": target_ideology,
		"modified_provinces": modified_provinces,
		"relation_changes": relation_changes,
		"stat_changes": stat_changes
	}

# Runs the local feature logic.
