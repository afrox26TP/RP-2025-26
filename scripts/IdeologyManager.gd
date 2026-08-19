extends RefCounted

## Resolves ideology aliases, compatibility groups and economic profiles.

var _economic_modifiers: Dictionary
var _gdp_multipliers: Dictionary
var _recruit_multipliers: Dictionary
var _base_recruit_cost: float
var _base_upkeep: float
var _base_income_rate: float
var _base_gdp_growth: float
var _base_population_growth: float


func _init(modifiers_by_ideology: Dictionary, gdp_multipliers: Dictionary, recruit_multipliers: Dictionary, base_recruit_cost: float, base_upkeep: float, base_income_rate: float, base_gdp_growth: float, base_population_growth: float) -> void:
	_economic_modifiers = modifiers_by_ideology
	_gdp_multipliers = gdp_multipliers
	_recruit_multipliers = recruit_multipliers
	_base_recruit_cost = base_recruit_cost
	_base_upkeep = base_upkeep
	_base_income_rate = base_income_rate
	_base_gdp_growth = base_gdp_growth
	_base_population_growth = base_population_growth


func normalize(ideology: String) -> String:
	var raw = ideology.strip_edges().to_lower()
	match raw:
		"democracy", "democratic": return "demokracie"
		"autocracy", "autocratic", "dictatorship": return "autokracie"
		"communism", "communist", "socialism": return "komunismus"
		"fascism", "fascist": return "fasismus"
		"nazism", "nazismus", "nazi", "national_socialism", "nacismum": return "nacismus"
		"kingdom", "monarchy", "royal", "kralostvi": return "kralovstvi"
		_: return raw


func pair_key(ideology_a: String, ideology_b: String) -> String:
	var a = normalize(ideology_a)
	var b = normalize(ideology_b)
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func economic_modifiers(ideology: String) -> Dictionary:
	var result = {
		"recruit_cost_mult": 1.0,
		"upkeep_mult": 1.0,
		"income_rate_mult": 1.0,
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0
	}
	var source = _economic_modifiers.get(normalize(ideology), {}) as Dictionary
	for key in source:
		result[key] = source[key]
	return result


func economic_profile(ideology: String) -> Dictionary:
	var modifiers = economic_modifiers(ideology)
	var recruit_cost_multiplier = max(0.01, float(modifiers["recruit_cost_mult"]))
	var upkeep_multiplier = max(0.01, float(modifiers["upkeep_mult"]))
	var income_multiplier = max(0.01, float(modifiers["income_rate_mult"]))
	var gdp_growth_multiplier = max(0.01, float(modifiers["gdp_growth_mult"]))
	var population_growth_multiplier = max(0.01, float(modifiers["population_growth_mult"]))
	var recruit_regeneration_multiplier = max(0.01, float(modifiers["recruit_regen_mult"]))
	return {
		"recruit_cost_per_soldier": _base_recruit_cost * recruit_cost_multiplier,
		"upkeep_per_soldier": _base_upkeep * upkeep_multiplier,
		"income_rate_from_gdp": _base_income_rate * income_multiplier,
		"gdp_growth_per_turn": _base_gdp_growth * gdp_growth_multiplier,
		"population_growth_ratio": _base_population_growth * population_growth_multiplier,
		"recruit_regen_ratio_core": 0.10 * recruit_regeneration_multiplier,
		"recruit_regen_ratio_occupied": 0.025 * recruit_regeneration_multiplier,
		"mods": modifiers
	}


func are_similar(ideology_a: String, ideology_b: String) -> bool:
	var a = normalize(ideology_a)
	var b = normalize(ideology_b)
	if a == "" or b == "":
		return false
	if a == b:
		return true
	return {
		"autokracie|fasismus": true,
		"autokracie|kralovstvi": true,
		"autokracie|nacismus": true,
		"demokracie|kralovstvi": true,
		"fasismus|nacismus": true
	}.has(pair_key(a, b))


func are_opposites(ideology_a: String, ideology_b: String) -> bool:
	var a = normalize(ideology_a)
	var b = normalize(ideology_b)
	if a == "" or b == "":
		return false
	return {
		"autokracie|komunismus": true,
		"demokracie|fasismus": true,
		"demokracie|komunismus": true,
		"demokracie|nacismus": true,
		"kralovstvi|fasismus": true,
		"kralovstvi|komunismus": true,
		"kralovstvi|nacismus": true
	}.has(pair_key(a, b))


func state_modifiers(ideology: String) -> Dictionary:
	var key = normalize(ideology)
	return {
		"gdp_mult": float(_gdp_multipliers.get(key, 1.0)),
		"recruit_mult": float(_recruit_multipliers.get(key, 1.0))
	}
