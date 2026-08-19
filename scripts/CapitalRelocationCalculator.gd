extends RefCounted

## Pure distance and price calculations for moving a state capital.

var _base_cost: float
var _gdp_ratio: float
var _distance_step: float
var _distance_ratio_per_step: float
var _maximum_distance_multiplier: float

func _init(base_cost: float, gdp_ratio: float, distance_step: float, distance_ratio_per_step: float, maximum_distance_multiplier: float) -> void:
	_base_cost = base_cost
	_gdp_ratio = gdp_ratio
	_distance_step = distance_step
	_distance_ratio_per_step = distance_ratio_per_step
	_maximum_distance_multiplier = maximum_distance_multiplier

func province_position(map_data: Dictionary, province_id: int) -> Vector2:
	if not map_data.has(province_id):
		return Vector2.ZERO
	var province = map_data[province_id] as Dictionary
	return Vector2(float(province.get("x", 0.0)), float(province.get("y", 0.0)))

func distance_multiplier(map_data: Dictionary, source_province_id: int, target_province_id: int) -> float:
	if source_province_id <= 0 or target_province_id <= 0 or source_province_id == target_province_id:
		return 1.0
	if not map_data.has(source_province_id) or not map_data.has(target_province_id):
		return 1.0
	var distance = province_position(map_data, source_province_id).distance_to(province_position(map_data, target_province_id))
	if distance <= 0.0:
		return 1.0
	var distance_factor = distance / max(1.0, _distance_step) * _distance_ratio_per_step
	return clamp(1.0 + distance_factor, 1.0, _maximum_distance_multiplier)

func relocation_cost(state_gdp: float, distance_multiplier_value: float = 1.0) -> float:
	var base = max(_base_cost, max(0.0, state_gdp) * _gdp_ratio)
	return snapped(base * max(1.0, distance_multiplier_value), 0.01)
