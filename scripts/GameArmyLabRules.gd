extends "res://scripts/GameIdeologyRules.gd"

## Shared army-lab constants and grid rules for the GameManager facade.

const ArmyLabManagerScript = preload("res://scripts/ArmyLabManager.gd")

const ARM_LAB_GRID_W := 3
const ARM_LAB_GRID_H := 3
const ARM_LAB_GRID_MAX_W := 6
const ARM_LAB_GRID_MAX_H := 6
const ARM_LAB_OFFER_COUNT := 3
const ARM_LAB_REROLL_BASE_COST := 8.0
const ARM_LAB_QUALITY_UPGRADE_BASE_COST := 35.0
const ARM_LAB_EXPAND_BASE_COST := 28.0
const ARM_LAB_EXPAND_STEP_COST := 22.0
const ARM_LAB_MERGE_POWER_MULT := 1.25
const ARM_LAB_SELL_RETURN_RATIO := 0.75
const ARM_LAB_LEVEL_POWER_STEP := 0.22
const ARM_LAB_LEVEL_COST_STEP := 0.18
const ARM_LAB_ITEM_POOL := [
	{"id":"weapon_crate", "name":"Weapon", "tier":1, "w":1, "h":1, "cost_min":10.0, "cost_max":16.0, "flat_min":80, "flat_max":140, "pct_min":0.002, "pct_max":0.008},
	{"id":"grenade_pack", "name":"Grenade", "tier":1, "w":1, "h":1, "cost_min":8.0, "cost_max":14.0, "flat_min":50, "flat_max":120, "pct_min":0.001, "pct_max":0.006},
	{"id":"truck_column", "name":"Truck", "tier":1, "w":2, "h":1, "cost_min":14.0, "cost_max":24.0, "flat_min":140, "flat_max":260, "pct_min":0.004, "pct_max":0.012},
	{"id":"ifv_module", "name":"IFV", "tier":2, "w":2, "h":1, "cost_min":24.0, "cost_max":36.0, "flat_min":280, "flat_max":460, "pct_min":0.010, "pct_max":0.020},
	{"id":"tank_platoon", "name":"Tank", "tier":2, "w":2, "h":2, "cost_min":34.0, "cost_max":52.0, "flat_min":420, "flat_max":680, "pct_min":0.015, "pct_max":0.030},
	{"id":"rocket_artillery", "name":"Rocket Launcher", "tier":3, "w":3, "h":1, "cost_min":46.0, "cost_max":70.0, "flat_min":650, "flat_max":980, "pct_min":0.028, "pct_max":0.050},
	{"id":"heavy_tank", "name":"Heavy Tank", "tier":3, "w":2, "h":2, "cost_min":58.0, "cost_max":86.0, "flat_min":780, "flat_max":1200, "pct_min":0.032, "pct_max":0.060}
]

var _army_lab_manager = ArmyLabManagerScript.new(
	ARM_LAB_GRID_W,
	ARM_LAB_GRID_H,
	ARM_LAB_GRID_MAX_W,
	ARM_LAB_GRID_MAX_H,
	ARM_LAB_ITEM_POOL,
	ARM_LAB_LEVEL_POWER_STEP,
	ARM_LAB_LEVEL_COST_STEP
)

func _clamp_arm_lab_quality(level: int) -> int:
	return _army_lab_manager.clamp_quality(level)

func _arm_lab_tier_roll(quality_level: int) -> int:
	return _army_lab_manager.roll_tier(quality_level)

func _arm_lab_level_roll(quality_level: int) -> int:
	return _army_lab_manager.roll_level(quality_level)

func _arm_lab_vyber_sablonu_dle_tieru(tier: int) -> Dictionary:
	return _army_lab_manager.template_for_tier(tier)

func _arm_lab_vytvor_random_offer(quality_level: int) -> Dictionary:
	return _army_lab_manager.create_random_offer(quality_level)

func _arm_lab_odemcene_dict(lab: Dictionary) -> Dictionary:
	return _army_lab_manager.unlocked_cells(lab)

func _arm_lab_odemcene_array(unlocked: Dictionary) -> Array:
	return _army_lab_manager.unlocked_cell_array(unlocked)

func _arm_lab_obsah_mrizky_odemykani(unlocked: Dictionary) -> Dictionary:
	return _army_lab_manager.unlocked_grid_size(unlocked)

func _arm_lab_je_kandidat_expanze(unlocked: Dictionary, x: int, y: int) -> bool:
	return _army_lab_manager.is_expansion_candidate(unlocked, x, y)

func _arm_lab_obsazena_mrizka(grid_items: Array) -> Dictionary:
	return _army_lab_manager.occupied_cells(grid_items)

func _arm_lab_najdi_prvni_volne_misto(grid_items: Array, w: int, h: int, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> Vector2i:
	return _army_lab_manager.first_free_position(grid_items, w, h, grid_w, grid_h, unlocked)

func _arm_lab_muze_umistit_na(grid_items: Array, w: int, h: int, x: int, y: int, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> bool:
	return _army_lab_manager.can_place(grid_items, w, h, x, y, grid_w, grid_h, unlocked)

func _arm_lab_muze_umistit_na_ignorovat(grid_items: Array, w: int, h: int, x: int, y: int, ignore_uid: String, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> bool:
	return _army_lab_manager.can_place(grid_items, w, h, x, y, grid_w, grid_h, unlocked, ignore_uid)

func _arm_lab_spocitej_bonus(grid_items: Array) -> Dictionary:
	return _army_lab_manager.calculate_bonus(grid_items)
