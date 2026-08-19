extends "res://scripts/GameSaveRepository.gd"

## Bilateral relationship storage and read-only relationship rules.

const RelationshipStoreScript = preload("res://scripts/RelationshipStore.gd")
const RELATIONSHIPS_CSV_PATH := "res://map_data/Relationships.csv"

const RELATION_MIN := -100.0
const RELATION_MAX := 100.0
const RELATION_STEP_PLAYER := 10.0
const RELATION_ACTION_COOLDOWN_TURNS := 3
const AI_FRIEND_RELATION_THRESHOLD := 35.0
const AI_RELATION_STEP := 5.0
const AI_REL_WORSEN_TRIGGER := -25.0
const AI_REL_IMPROVE_TRIGGER := 20.0
const ALLIANCE_NONE := 0
const ALLIANCE_DEFENSE := 1
const ALLIANCE_OFFENSE := 2
const ALLIANCE_FULL := 3
const ALLIANCE_MIN_REL_DEFENSE := 60.0
const ALLIANCE_MIN_REL_OFFENSE := 75.0
const ALLIANCE_MIN_REL_FULL := 90.0
const ALLIANCE_HARD_REJECT_REL := 45.0
const AI_ALLIANCE_LEAVE_REL_MARGIN := 8.0

var _relationship_store = RelationshipStoreScript.new()
var _relationship_store_configured: bool = false

func _get_relationship_store():
	if not _relationship_store_configured:
		_relationship_store.configure(Callable(self, "_normalizuj_tag"), RELATIONSHIPS_CSV_PATH)
		_relationship_store_configured = true
	return _relationship_store

func _klic_vztahu(tag_a: String, tag_b: String) -> String:
	return _get_relationship_store().directional_key(tag_a, tag_b)

func _klic_vztah_pair(tag_a: String, tag_b: String) -> String:
	return _get_relationship_store().pair_key(tag_a, tag_b)

func _nacti_vztahy_statu() -> void:
	_get_relationship_store().ensure_loaded()

func ziskej_vztah_statu(tag_a: String, tag_b: String) -> float:
	var pair_key = _klic_vztah_pair(tag_a, tag_b)
	if _ai_phase_cache_active and pair_key != "" and _ai_relation_cache.has(pair_key):
		return float(_ai_relation_cache[pair_key])
	var relation = _get_relationship_store().get_relation(tag_a, tag_b)
	if _ai_phase_cache_active and pair_key != "":
		_ai_relation_cache[pair_key] = relation
	return relation

func _je_pratelsky_vztah(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	return ziskej_vztah_statu(tag_a, tag_b) >= AI_FRIEND_RELATION_THRESHOLD

func muze_upravit_vztah_statu(tag_a: String, tag_b: String) -> bool:
	return _get_relationship_store().can_adjust(tag_a, tag_b, aktualni_kolo, RELATION_ACTION_COOLDOWN_TURNS)

func zbyva_kol_do_upravy_vztahu(tag_a: String, tag_b: String) -> int:
	return _get_relationship_store().remaining_turns(tag_a, tag_b, aktualni_kolo, RELATION_ACTION_COOLDOWN_TURNS)

func _minimalni_vztah_pro_alianci(level: int) -> float:
	match level:
		ALLIANCE_DEFENSE:
			return ALLIANCE_MIN_REL_DEFENSE
		ALLIANCE_OFFENSE:
			return ALLIANCE_MIN_REL_OFFENSE
		ALLIANCE_FULL:
			return ALLIANCE_MIN_REL_FULL
		_:
			return RELATION_MIN
