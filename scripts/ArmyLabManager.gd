extends RefCounted

## Owns army-lab grid geometry, unlock validation, placement and bonus aggregation.

var _base_width: int
var _base_height: int
var _maximum_width: int
var _maximum_height: int
var _item_pool: Array
var _level_power_step: float
var _level_cost_step: float


func _init(base_width: int, base_height: int, maximum_width: int, maximum_height: int, item_pool: Array = [], level_power_step: float = 0.22, level_cost_step: float = 0.18) -> void:
	_base_width = base_width
	_base_height = base_height
	_maximum_width = maximum_width
	_maximum_height = maximum_height
	_item_pool = item_pool.duplicate(true)
	_level_power_step = level_power_step
	_level_cost_step = level_cost_step


func unlocked_cells(lab: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell_value in lab.get("unlocked_cells", []) as Array:
		var parts = str(cell_value).split("_")
		if parts.size() != 2:
			continue
		var x = int(parts[0])
		var y = int(parts[1])
		if x >= 0 and y >= 0 and x < _maximum_width and y < _maximum_height:
			result["%d_%d" % [x, y]] = true
	return result


func unlocked_cell_array(unlocked: Dictionary) -> Array:
	var result: Array = []
	for key in unlocked:
		result.append(str(key))
	result.sort()
	return result


func unlocked_grid_size(unlocked: Dictionary) -> Dictionary:
	var maximum_x = _base_width - 1
	var maximum_y = _base_height - 1
	for key_value in unlocked:
		var parts = str(key_value).split("_")
		if parts.size() != 2:
			continue
		maximum_x = max(maximum_x, int(parts[0]))
		maximum_y = max(maximum_y, int(parts[1]))
	return {
		"w": clampi(maximum_x + 1, _base_width, _maximum_width),
		"h": clampi(maximum_y + 1, _base_height, _maximum_height)
	}


func is_expansion_candidate(unlocked: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _maximum_width or y >= _maximum_height:
		return false
	var key = "%d_%d" % [x, y]
	if unlocked.has(key):
		return false

	var row_right := -1
	for current_x in range(_maximum_width):
		if unlocked.has("%d_%d" % [current_x, y]):
			row_right = current_x
	if row_right >= 0 and x == row_right + 1:
		return true

	var column_bottom := -1
	for current_y in range(_maximum_height):
		if unlocked.has("%d_%d" % [x, current_y]):
			column_bottom = current_y
	return column_bottom >= 0 and y == column_bottom + 1


func occupied_cells(grid_items: Array, ignored_uid: String = "") -> Dictionary:
	var occupied: Dictionary = {}
	for item_value in grid_items:
		var item = item_value as Dictionary
		if ignored_uid != "" and str(item.get("offer_uid", "")) == ignored_uid:
			continue
		var start_x = int(item.get("x", 0))
		var start_y = int(item.get("y", 0))
		var width = int(item.get("w", 1))
		var height = int(item.get("h", 1))
		for y in range(start_y, start_y + height):
			for x in range(start_x, start_x + width):
				occupied["%d_%d" % [x, y]] = true
	return occupied


func first_free_position(grid_items: Array, width: int, height: int, grid_width: int, grid_height: int, unlocked: Dictionary = {}) -> Vector2i:
	var item_width = max(1, width)
	var item_height = max(1, height)
	if item_width > grid_width or item_height > grid_height:
		return Vector2i(-1, -1)
	var occupied = occupied_cells(grid_items)
	for y in range(0, grid_height - item_height + 1):
		for x in range(0, grid_width - item_width + 1):
			if _rectangle_is_free(occupied, unlocked, item_width, item_height, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func can_place(grid_items: Array, width: int, height: int, x: int, y: int, grid_width: int, grid_height: int, unlocked: Dictionary = {}, ignored_uid: String = "") -> bool:
	var item_width = max(1, width)
	var item_height = max(1, height)
	if item_width > grid_width or item_height > grid_height or x < 0 or y < 0:
		return false
	if x + item_width > grid_width or y + item_height > grid_height:
		return false
	return _rectangle_is_free(occupied_cells(grid_items, ignored_uid), unlocked, item_width, item_height, x, y)


func calculate_bonus(grid_items: Array) -> Dictionary:
	var total_flat := 0
	var total_percent := 0.0
	for item_value in grid_items:
		var item = item_value as Dictionary
		total_flat += int(item.get("power_flat", 0))
		total_percent += float(item.get("power_pct", 0.0))
	return {"flat": total_flat, "pct": total_percent}


func clamp_quality(level: int) -> int:
	return clampi(level, 0, 8)


func roll_tier(quality_level: int) -> int:
	var quality = clamp_quality(quality_level)
	var roll = randf()
	var tier_three_chance = clamp(0.08 + float(quality) * 0.04, 0.08, 0.45)
	var tier_two_chance = clamp(0.26 + float(quality) * 0.05, 0.26, 0.60)
	if roll < tier_three_chance:
		return 3
	if roll < tier_three_chance + tier_two_chance:
		return 2
	return 1


func roll_level(quality_level: int) -> int:
	var quality = clamp_quality(quality_level)
	var roll = randf()
	var level_four_chance = clamp(0.02 + float(quality) * 0.02, 0.02, 0.18)
	var level_three_chance = clamp(0.08 + float(quality) * 0.05, 0.08, 0.40)
	var level_two_chance = clamp(0.30 + float(quality) * 0.07, 0.30, 0.75)
	if roll < level_four_chance:
		return 4
	if roll < level_four_chance + level_three_chance:
		return 3
	if roll < level_four_chance + level_three_chance + level_two_chance:
		return 2
	return 1


func template_for_tier(tier: int) -> Dictionary:
	var candidates: Array = []
	for template_any in _item_pool:
		var template = template_any as Dictionary
		if int(template.get("tier", 1)) == tier:
			candidates.append(template)
	if candidates.is_empty():
		candidates = _item_pool
	if candidates.is_empty():
		return {}
	return (candidates[randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)


func create_random_offer(quality_level: int) -> Dictionary:
	var tier = roll_tier(quality_level)
	var level = max(roll_level(quality_level), tier)
	var template = template_for_tier(tier)
	if template.is_empty():
		return {}
	var power_multiplier = 1.0 + float(max(0, level - 1)) * _level_power_step
	var cost_multiplier = 1.0 + float(max(0, level - 1)) * _level_cost_step
	return {
		"offer_uid": str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"id": str(template.get("id", "item")),
		"name": str(template.get("name", "Item")),
		"level": level,
		"tier": tier,
		"w": int(template.get("w", 1)),
		"h": int(template.get("h", 1)),
		"cost": snapped(max(1.0, randf_range(float(template.get("cost_min", 10.0)), float(template.get("cost_max", template.get("cost_min", 10.0)))) * cost_multiplier), 0.01),
		"power_flat": int(max(0, round(float(randi_range(int(template.get("flat_min", 40)), int(template.get("flat_max", template.get("flat_min", 40))))) * power_multiplier))),
		"power_pct": max(0.0, randf_range(float(template.get("pct_min", 0.001)), float(template.get("pct_max", template.get("pct_min", 0.001)))) * power_multiplier)
	}


func _rectangle_is_free(occupied: Dictionary, unlocked: Dictionary, width: int, height: int, start_x: int, start_y: int) -> bool:
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			var key = "%d_%d" % [x, y]
			if not unlocked.is_empty() and not unlocked.has(key):
				return false
			if occupied.has(key):
				return false
	return true
