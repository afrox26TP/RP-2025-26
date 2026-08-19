extends "res://scripts/GameFoundation.gd"

## Shared ideology normalization and economic-rule layer for the GameManager facade.

const IdeologyManagerScript = preload("res://scripts/IdeologyManager.gd")

const IDEOLOGY_RELATION_SIMILAR_BONUS := 8.0
const IDEOLOGY_RELATION_OPPOSITE_PENALTY := 12.0
const IDEOLOGY_GDP_MULTIPLIERS := {
	"demokracie": 1.10,
	"kralovstvi": 1.03,
	"autokracie": 0.98,
	"komunismus": 0.94,
	"nacismus": 0.90,
	"fasismus": 0.90
}
const IDEOLOGY_RECRUIT_MULTIPLIERS := {
	"demokracie": 0.95,
	"kralovstvi": 1.00,
	"autokracie": 1.12,
	"komunismus": 1.20,
	"nacismus": 1.28,
	"fasismus": 1.28
}
const IDEOLOGY_ECONOMIC_MODIFIERS := {
	"demokracie": {
		"recruit_cost_mult": 1.08, "upkeep_mult": 0.96, "income_rate_mult": 1.08,
		"gdp_growth_mult": 1.12, "population_growth_mult": 1.05, "recruit_regen_mult": 0.92
	},
	"kralovstvi": {
		"recruit_cost_mult": 1.00, "upkeep_mult": 0.99, "income_rate_mult": 1.02,
		"gdp_growth_mult": 1.03, "population_growth_mult": 1.02, "recruit_regen_mult": 1.00
	},
	"autokracie": {
		"recruit_cost_mult": 0.94, "upkeep_mult": 1.08, "income_rate_mult": 0.98,
		"gdp_growth_mult": 0.98, "population_growth_mult": 0.99, "recruit_regen_mult": 1.12
	},
	"komunismus": {
		"recruit_cost_mult": 0.88, "upkeep_mult": 1.12, "income_rate_mult": 0.94,
		"gdp_growth_mult": 0.93, "population_growth_mult": 1.03, "recruit_regen_mult": 1.20
	},
	"nacismus": {
		"recruit_cost_mult": 0.82, "upkeep_mult": 1.18, "income_rate_mult": 0.90,
		"gdp_growth_mult": 0.88, "population_growth_mult": 0.96, "recruit_regen_mult": 1.30
	},
	"fasismus": {
		"recruit_cost_mult": 0.82, "upkeep_mult": 1.18, "income_rate_mult": 0.90,
		"gdp_growth_mult": 0.88, "population_growth_mult": 0.96, "recruit_regen_mult": 1.30
	}
}
const BASE_RECRUIT_COST_PER_SOLDIER := 0.05
const BASE_UPKEEP_PER_SOLDIER := 0.001
const BASE_INCOME_RATE := 0.10
const BASE_GDP_GROWTH_PER_TURN := 0.5
const BASE_POP_GROWTH_RATIO := 0.0015

var _ideology_manager = IdeologyManagerScript.new(
	IDEOLOGY_ECONOMIC_MODIFIERS,
	IDEOLOGY_GDP_MULTIPLIERS,
	IDEOLOGY_RECRUIT_MULTIPLIERS,
	BASE_RECRUIT_COST_PER_SOLDIER,
	BASE_UPKEEP_PER_SOLDIER,
	BASE_INCOME_RATE,
	BASE_GDP_GROWTH_PER_TURN,
	BASE_POP_GROWTH_RATIO
)

func _normalizuj_ideologii(ideology: String) -> String:
	return _ideology_manager.normalize(ideology)

func _klic_ideologickeho_paru(ideology_a: String, ideology_b: String) -> String:
	return _ideology_manager.pair_key(ideology_a, ideology_b)

func _ziskej_ekonomicke_modifikatory_ideologie(ideology: String) -> Dictionary:
	return _ideology_manager.economic_modifiers(ideology)

func ziskej_ekonomicke_modifikatory_ideologie(ideology: String) -> Dictionary:
	return _ziskej_ekonomicke_modifikatory_ideologie(ideology)

func ziskej_ideologicky_ekonomicky_profil(ideology: String) -> Dictionary:
	return _ideology_manager.economic_profile(ideology)

func _jsou_ideologie_podobne(ideology_a: String, ideology_b: String) -> bool:
	return _ideology_manager.are_similar(ideology_a, ideology_b)

func _jsou_ideologie_uplne_odlisne(ideology_a: String, ideology_b: String) -> bool:
	return _ideology_manager.are_opposites(ideology_a, ideology_b)

func _ziskej_statove_modifikatory_ideologie(ideology: String) -> Dictionary:
	return _ideology_manager.state_modifiers(ideology)
