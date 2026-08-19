extends "res://scripts/GameState.gd"

## Flattened shared foundation and cross-domain services. Keeping these low-level layers together avoids an excessively deep GDScript inheritance chain.

## ---- GameFoundation ----

## Shared scene lookup and country identity services used by domain managers.

const TagNormalizerScript = preload("res://scripts/TagNormalizer.gd")

var _tag_normalizer = TagNormalizerScript.new()


func _invalidate_tag_alias_cache() -> void:
	_tag_normalizer.invalidate()

## ---- GameIdeologyRules ----

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

## ---- GameArmyLabRules ----

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

## ---- GameSaveRepository ----

## Save-slot repository layer. Runtime snapshot construction remains in the facade orchestration layer.

const SaveRepositoryScript = preload("res://scripts/SaveRepository.gd")
const SAVEGAME_STATE_PATH := "user://savegame.dat"
const SAVE_SLOTS_DIR := "user://saves"
const SAVE_SLOT_EXT := ".dat"

var _save_repository = SaveRepositoryScript.new(
	SAVEGAME_STATE_PATH,
	SAVE_SLOTS_DIR,
	SAVE_SLOT_EXT
)

func _normalizuj_nazev_save(slot_name: String) -> String:
	return _save_repository.normalize_slot_name(slot_name)

func _cesta_slotu_save(slot_name: String) -> String:
	return _save_repository.slot_path(slot_name)

func _zajisti_slozku_save() -> void:
	_save_repository.ensure_slots_directory()

func _uloz_state_do_cesty(path: String, state: Dictionary) -> bool:
	return _save_repository.write_state(path, state)

func _nacti_state_z_cesty(path: String) -> Dictionary:
	return _save_repository.read_state(path)

func ziskej_save_sloty() -> Array:
	return _save_repository.list_slots()

func ziskej_save_slot_pro_kolo(turn_number: int) -> String:
	if turn_number <= 0:
		return ""
	for slot_any in ziskej_save_sloty():
		var slot = slot_any as Dictionary
		var slot_path = str(slot.get("path", ""))
		if slot_path == "":
			continue
		var state = _nacti_state_z_cesty(slot_path)
		if state.is_empty():
			continue
		if int(state.get("aktualni_kolo", -1)) == turn_number:
			return str(slot.get("name", ""))
	return ""

func ma_save_pro_kolo(turn_number: int) -> bool:
	return ziskej_save_slot_pro_kolo(turn_number) != ""

func ma_ulozene_hry() -> bool:
	return _save_repository.has_any_save()

func smaz_save_slot(slot_name: String) -> bool:
	return _save_repository.delete_slot(slot_name)

func smaz_legacy_save() -> bool:
	return _save_repository.delete_legacy_save()

## ---- GameRelationships ----

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

## ---- GamePlayers ----

## Local-player ownership, identity, turn order, and per-player finance caches.

func _normalizuj_lidske_staty(staty: Array) -> Array:
	var out: Array = []
	for state_any in staty:
		var tag = _normalizuj_tag(str(state_any))
		if tag == "" or tag == "SEA" or out.has(tag):
			continue
		out.append(tag)
	return out

func nastav_lokalni_hrace(staty: Array) -> void:
	var normalizovane = _normalizuj_lidske_staty(staty)
	if normalizovane.is_empty() and _spectate_mode_active:
		lokalni_hraci_staty = []
		aktivni_hrac_index = 0
		hrac_stat = "SPECTATE"
		hrac_jmeno = ""
		hrac_ideologie = ""
		_hrac_kasa_inicializovana = false
		hrac_kasy.clear()
		hrac_prijmy.clear()
		hrac_kasa_inicializovana.clear()
		cekajici_popupy_hracu.clear()
		notifikace_pujcek_hracu.clear()
		log_zprav_hracu.clear()
		log_globalnich_zprav.clear()
		vyzkum_statu.clear()
		armadni_lab_statu.clear()
		ai_kasy.clear()
		return
	if normalizovane.is_empty():
		normalizovane = [_normalizuj_tag(hrac_stat)]
	_spectate_mode_active = false

	lokalni_hraci_staty = normalizovane
	aktivni_hrac_index = 0
	hrac_stat = str(lokalni_hraci_staty[0])
	var aktivni_tag = _normalizuj_tag(hrac_stat)
	hrac_jmeno = ""
	hrac_ideologie = ""
	_hrac_kasa_inicializovana = false
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	notifikace_pujcek_hracu.clear()
	log_zprav_hracu.clear()
	log_globalnich_zprav.clear()
	vyzkum_statu.clear()
	armadni_lab_statu.clear()
	ai_kasy.clear()

	if not hrac_kasy.has(aktivni_tag):
		hrac_kasy[aktivni_tag] = statni_kasa
	if not hrac_prijmy.has(aktivni_tag):
		hrac_prijmy[aktivni_tag] = celkovy_prijem
	_synchronizuj_jmeno_a_ideologii_hrace()

func je_lidsky_stat(tag: String) -> bool:
	var cisty = _normalizuj_tag(tag)
	if cisty == "":
		return false
	if lokalni_hraci_staty.is_empty():
		return cisty == _normalizuj_tag(hrac_stat)
	return lokalni_hraci_staty.has(cisty)

func _uloz_finance_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	hrac_kasy[aktivni] = statni_kasa
	hrac_prijmy[aktivni] = celkovy_prijem

func _nacti_finance_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	statni_kasa = float(hrac_kasy.get(aktivni, statni_kasa))
	celkovy_prijem = float(hrac_prijmy.get(aktivni, celkovy_prijem))

func _sjednot_multiplayer_finance_cache() -> void:
	if lokalni_hraci_staty.size() <= 1:
		return
	var normalizovani_hraci = _normalizuj_lidske_staty(lokalni_hraci_staty)
	var aktivni_tag = _normalizuj_tag(hrac_stat)
	if aktivni_tag != "" and not normalizovani_hraci.has(aktivni_tag):
		normalizovani_hraci.append(aktivni_tag)
	if normalizovani_hraci.is_empty():
		return
	lokalni_hraci_staty = normalizovani_hraci

	var sjednocene_kasy: Dictionary = {}
	var sjednocene_prijmy: Dictionary = {}
	var sjednocene_inicializace: Dictionary = {}
	for key_any in hrac_kasy.keys():
		var tag = _normalizuj_tag(str(key_any))
		if tag != "" and lokalni_hraci_staty.has(tag) and not sjednocene_kasy.has(tag):
			sjednocene_kasy[tag] = float(hrac_kasy[key_any])
	for key_any in hrac_prijmy.keys():
		var tag = _normalizuj_tag(str(key_any))
		if tag != "" and lokalni_hraci_staty.has(tag) and not sjednocene_prijmy.has(tag):
			sjednocene_prijmy[tag] = float(hrac_prijmy[key_any])
	for key_any in hrac_kasa_inicializovana.keys():
		var tag = _normalizuj_tag(str(key_any))
		if bool(hrac_kasa_inicializovana[key_any]) and tag != "" and lokalni_hraci_staty.has(tag):
			sjednocene_inicializace[tag] = true
	for tag_any in lokalni_hraci_staty:
		var tag = _normalizuj_tag(str(tag_any))
		if tag == "":
			continue
		if not sjednocene_kasy.has(tag):
			sjednocene_kasy[tag] = statni_kasa if tag == aktivni_tag else float(hrac_kasy.get(tag, 0.0))
		if not sjednocene_prijmy.has(tag):
			sjednocene_prijmy[tag] = celkovy_prijem if tag == aktivni_tag else float(hrac_prijmy.get(tag, 0.0))
		if not sjednocene_inicializace.has(tag) and ((tag == aktivni_tag and _hrac_kasa_inicializovana) or bool(hrac_kasa_inicializovana.get(tag, false))):
			sjednocene_inicializace[tag] = true
	if aktivni_tag != "":
		sjednocene_kasy[aktivni_tag] = statni_kasa
		sjednocene_prijmy[aktivni_tag] = celkovy_prijem
	hrac_kasy = sjednocene_kasy
	hrac_prijmy = sjednocene_prijmy
	hrac_kasa_inicializovana = sjednocene_inicializace
	if not lokalni_hraci_staty.has(aktivni_tag):
		aktivni_tag = str(lokalni_hraci_staty[0])
		hrac_stat = aktivni_tag
	aktivni_hrac_index = clampi(lokalni_hraci_staty.find(aktivni_tag), 0, lokalni_hraci_staty.size() - 1)
	_nacti_finance_aktivniho_hrace()

func _synchronizuj_jmeno_a_ideologii_hrace() -> void:
	hrac_jmeno = ""
	hrac_ideologie = ""
	if map_data.is_empty():
		return
	for province_any in map_data.values():
		var province = province_any as Dictionary
		if str(province.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			hrac_jmeno = str(province.get("country_name", hrac_stat))
			hrac_ideologie = str(province.get("ideology", ""))
			return

func _prepni_na_hrace(index: int) -> void:
	if lokalni_hraci_staty.is_empty():
		return
	aktivni_hrac_index = clamp(index, 0, lokalni_hraci_staty.size() - 1)
	hrac_stat = str(lokalni_hraci_staty[aktivni_hrac_index])
	_nacti_finance_aktivniho_hrace()
	_synchronizuj_jmeno_a_ideologii_hrace()

func _prepni_na_dalsiho_hrace() -> void:
	if lokalni_hraci_staty.size() <= 1:
		return
	_prepni_na_hrace((aktivni_hrac_index + 1) % lokalni_hraci_staty.size())

func _je_posledni_hrac_v_poradi() -> bool:
	return lokalni_hraci_staty.size() <= 1 or aktivni_hrac_index >= (lokalni_hraci_staty.size() - 1)

func odeber_lidsky_stat(tag: String) -> void:
	var cisty = _normalizuj_tag(tag)
	var index = lokalni_hraci_staty.find(cisty)
	if cisty == "" or index == -1:
		return
	lokalni_hraci_staty.remove_at(index)
	hrac_kasy.erase(cisty)
	hrac_prijmy.erase(cisty)
	hrac_kasa_inicializovana.erase(cisty)
	cekajici_popupy_hracu.erase(cisty)
	if lokalni_hraci_staty.is_empty():
		return
	if index < aktivni_hrac_index:
		aktivni_hrac_index -= 1
	if aktivni_hrac_index >= lokalni_hraci_staty.size():
		aktivni_hrac_index = 0
	_prepni_na_hrace(aktivni_hrac_index)

## ---- GameLogging ----

## Player notifications, popup queues, and persistent game-event logs.

const GameLogManagerScript = preload("res://scripts/GameLogManager.gd")
const MAX_LOG_ZPRAV := 500
const NON_AGGRESSION_DURATION_TURNS := 10
const POPUP_BATCH_MAX_ITEMS := 12

var _game_log_manager = GameLogManagerScript.new()

func _pridej_popup_hraci(tag: String, title: String, text: String, force_popup: bool = false, state_tags: Array = []) -> void:
	var clean = _normalizuj_tag(tag)
	if clean == "" or not je_lidsky_stat(clean) or title.strip_edges() == "" or text.strip_edges() == "":
		return
	_zaloguj_zpravu_hraci(clean, title, text, "popup")
	if not force_popup and not _je_dulezity_popup(title, text):
		return
	var normalized_tags: Array = []
	for raw_tag in state_tags:
		var related = _normalizuj_tag(str(raw_tag))
		if related != "" and related != "SEA" and not normalized_tags.has(related):
			normalized_tags.append(related)
	if not cekajici_popupy_hracu.has(clean):
		cekajici_popupy_hracu[clean] = []
	(cekajici_popupy_hracu[clean] as Array).append({"title": title, "text": text, "state_tags": normalized_tags})

func _pridej_notifikaci_pujcky_hraci(tag: String, text: String) -> void:
	var clean = _normalizuj_tag(tag)
	if clean == "" or not je_lidsky_stat(clean) or text.strip_edges() == "":
		return
	if not notifikace_pujcek_hracu.has(clean):
		notifikace_pujcek_hracu[clean] = []
	(notifikace_pujcek_hracu[clean] as Array).append(text)

func vyzvedni_notifikace_pujcek_hrace(tag: String) -> Array:
	var clean = _normalizuj_tag(tag)
	if clean == "" or not notifikace_pujcek_hracu.has(clean):
		return []
	var notifications = (notifikace_pujcek_hracu[clean] as Array).duplicate(true)
	notifikace_pujcek_hracu.erase(clean)
	return notifications

func _je_dulezity_popup(title: String, text: String) -> bool:
	return _game_log_manager.is_critical_popup(title, text)

func _normalizuj_kategorii_logu_pro_prioritu(category: String, title: String, text: String) -> String:
	return _game_log_manager.normalize_category(category, title, text)

func _priorita_kategorie_logu(category: String, title: String, text: String) -> int:
	return _game_log_manager.category_priority(category, title, text)

func _odstran_expirovane_historicke_smlouvy(log_entries: Array) -> void:
	_game_log_manager.remove_expired_treaties(log_entries, aktualni_kolo, NON_AGGRESSION_DURATION_TURNS)

func _udrzba_vsech_logu() -> void:
	if _defer_log_maintenance:
		_log_maintenance_dirty = true
		return
	for key in log_zprav_hracu.keys():
		_trim_log_pole(log_zprav_hracu[key] as Array)
	_trim_log_pole(log_globalnich_zprav)
	_log_maintenance_dirty = false

func _najdi_index_zpravy_k_odstraneni(log_entries: Array) -> int:
	return _game_log_manager.removal_candidate(log_entries)

func _trim_log_pole(log_entries: Array, max_items: int = MAX_LOG_ZPRAV) -> void:
	if _defer_log_maintenance:
		_log_maintenance_dirty = true
		return
	_game_log_manager.trim(log_entries, max_items, aktualni_kolo, NON_AGGRESSION_DURATION_TURNS)

func _set_defer_log_maintenance(enabled: bool) -> void:
	if _defer_log_maintenance == enabled:
		return
	_defer_log_maintenance = enabled
	if not enabled and _log_maintenance_dirty:
		_udrzba_vsech_logu()

func _zaloguj_zpravu_hraci(tag: String, title: String, text: String, category: String = "general") -> void:
	var clean = _normalizuj_tag(tag)
	if clean == "" or title.strip_edges() == "" or text.strip_edges() == "":
		return
	if not log_zprav_hracu.has(clean):
		log_zprav_hracu[clean] = []
	for raw_line in text.split("\n", false):
		var line = str(raw_line).strip_edges()
		if line != "":
			(log_zprav_hracu[clean] as Array).append({"turn": aktualni_kolo, "title": title, "text": line, "category": category})
	_trim_log_pole(log_zprav_hracu[clean] as Array)

func _zaloguj_globalni_zpravu(title: String, text: String, category: String = "global") -> void:
	if title.strip_edges() == "" or text.strip_edges() == "":
		return
	log_globalnich_zprav.append({"turn": aktualni_kolo, "title": title, "text": text, "category": category})
	_trim_log_pole(log_globalnich_zprav)

func ziskej_zpravy_hrace(tag: String, limit: int = 120) -> Array:
	_udrzba_vsech_logu()
	var clean = _normalizuj_tag(tag)
	if clean == "" or not log_zprav_hracu.has(clean):
		return []
	var source = log_zprav_hracu[clean] as Array
	var count = clampi(limit, 1, MAX_LOG_ZPRAV)
	return source.slice(max(0, source.size() - count), source.size())

func ziskej_globalni_zpravy(limit: int = 160) -> Array:
	_udrzba_vsech_logu()
	var count = clampi(limit, 1, MAX_LOG_ZPRAV)
	return log_globalnich_zprav.slice(max(0, log_globalnich_zprav.size() - count), log_globalnich_zprav.size())

func ziskej_pocet_zprav_hrace(tag: String) -> int:
	_udrzba_vsech_logu()
	var clean = _normalizuj_tag(tag)
	return (log_zprav_hracu.get(clean, []) as Array).size() if clean != "" else 0

func ziskej_pocet_globalnich_zprav() -> int:
	_udrzba_vsech_logu()
	return log_globalnich_zprav.size()

## ---- GameCore ----
# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

# this script drives a specific gameplay/UI area and keeps related logic together.

# Contract implemented by GameAI. These fallbacks keep the shared domain layer
# independently parseable while preserving virtual dispatch in the final autoload.
func _ai_ziskej_mindset(_state_tag: String) -> Dictionary:
	return {}

func _ai_ziskej_strategicky_cil(_state_tag: String) -> Dictionary:
	return {}

func _ai_goal_signature(_owner_tag: String, _target_tag: String) -> Dictionary:
	return {}

func _ai_spocitej_war_exhaustion(_state_tag: String) -> float:
	return 0.0

func _ai_ziskej_operacni_plan(_state_tag: String) -> Dictionary:
	return {}

func _ai_provincie_hranicni_k_targetu(_state_tag: String, _province_id: int, _target_owner: String) -> bool:
	return false

func _ai_ziskej_recruit_kandidaty(_state_tag: String, _owned: Array, _pressure: float) -> Array:
	return []

func _ai_spocitej_tlak_statu(_state_tag: String, _owned: Array) -> float:
	return 0.0

func zpracuj_tah_ai():
	pass

func _seradene_ai_provincie(_state_tag: String) -> Array:
	return []

func _ai_ma_namorni_prilezitost(_state_tag: String, _from_id: int, _preferred_front_owner: String = "") -> bool:
	return false

func _spocitej_hrozbu_nepratel_u_provincie(_province_id: int, _state_tag: String) -> int:
	return 0

func _navrhni_krizovy_protiutok(_state_tag: String, _from_id: int, _own_capital_id: int, _frontline_cache: Dictionary = {}) -> Dictionary:
	return {}

func _ziskej_ai_vztah_cached(_tag_a: String, _tag_b: String) -> float:
	return 0.0

func _je_pratelsky_vztah_ai_cached(_tag_a: String, _tag_b: String) -> bool:
	return false

func _jsou_ve_valce_ai_cached(_tag_a: String, _tag_b: String) -> bool:
	return false

func _ziskej_uroven_aliance_ai_cached(_tag_a: String, _tag_b: String) -> int:
	return 0

func _ma_neagresivni_smlouvu_ai_cached(_tag_a: String, _tag_b: String) -> bool:
	return false

func _muze_upravit_vztah_ai_cached(_tag_a: String, _tag_b: String) -> bool:
	return false

func _ma_spolecnou_hranici_ai_cached(_tag_a: String, _tag_b: String) -> bool:
	return false

func _je_frontline_cached(_state_tag: String, _province_id: int, _frontline_cache: Dictionary) -> bool:
	return false

func _ai_vycisti_runtime_cache_pro_stat(_state_tag: String) -> void:
	pass

func _ai_vycisti_runtime_cache() -> void:
	pass

func _normalizuj_provincie_cooldowny(_raw_any) -> Dictionary:
	return {}

func _normalizuj_valecne_klice() -> void:
	pass

func _rebuild_turn_cache() -> void:
	pass

func _stat_existuje(_tag: String) -> bool:
	return false

func _ziskej_kasu_statu(_tag: String) -> float:
	return 0.0

func _nastav_kasu_statu(_tag: String, _value: float) -> void:
	pass

func _ziskej_modifikatory_budov_provincie(_prov_id: int) -> Dictionary:
	return {}

func _ziskej_modifikatory_budov_statu(_state_tag: String) -> Dictionary:
	return {}

func _uprav_vztah_statu_bez_cooldown(_tag_a: String, _tag_b: String, _delta: float) -> float:
	return 0.0

func _invalidate_turn_cache() -> void:
	pass

func _ziskej_aktivni_staty() -> Array:
	return []

func spocitej_prijem(_all_provinces: Dictionary, _emit_ui_signal: bool = true):
	pass

func _money_debug_expense(_state_tag: String, _category: String, _amount: float, _treasury_before: float, _treasury_after: float, _detail: String = "") -> void:
	pass

func _money_debug_income_event(_state_tag: String, _category: String, _amount: float, _treasury_before: float, _treasury_after: float, _detail: String = "") -> void:
	pass

func _spocitej_hdp_statu(_tag: String) -> float:
	return 0.0

func _pridej_diplomatickou_zadost(_from_tag: String, _to_tag: String, _req_type: String, _alliance_level: int = ALLIANCE_NONE, _payload: Dictionary = {}) -> bool:
	return false

func _spocitej_cisty_prijem_statu(_tag: String) -> float:
	return 0.0

func ziskej_uroven_aliance(_tag_a: String, _tag_b: String) -> int:
	return ALLIANCE_NONE

func ma_neagresivni_smlouvu(_tag_a: String, _tag_b: String) -> bool:
	return false

func jsou_ve_valce(_tag1: String, _tag2: String) -> bool:
	return false

func zbyva_kol_do_dalsi_valky(_tag_a: String, _tag_b: String) -> int:
	return 0

func ziskej_alianci_podle_id(_alliance_id: String) -> Dictionary:
	return {}

func ziskej_podminky_clenstvi_aliance(_alliance_id: String, _candidate_tag: String) -> Array:
	return []

func _ziskej_profile_statu_pro_mir(_tag: String) -> Dictionary:
	return {}

func vyhlasit_valku(_utocnik: String, _obrance: String):
	pass

func pridej_clena_do_aliance(_alliance_id: String, _tag: String, _ignoruj_vztahove_podminky: bool = false) -> Dictionary:
	return {}

func uzavrit_neagresivni_smlouvu(_tag_a: String, _tag_b: String) -> bool:
	return false

func _mark_ai_war_pair_eval_dirty_pair(_tag_a: String, _tag_b: String) -> void:
	pass

func _klic_pair(_tag_a: String, _tag_b: String) -> String:
	return ""

func ziskej_overlorda_statu(_subject_tag: String) -> String:
	return ""

func muze_vstoupit_na_uzemi(_actor_tag: String, _owner_tag: String) -> bool:
	return false

func uzavri_mir_a_zahaj_konferenci(_tag1: String, _tag2: String, _reason: String = "peace") -> Dictionary:
	return {}

func _klic_valky(_tag_a: String, _tag_b: String) -> String:
	return ""

func _begin_ai_cache_batch() -> void:
	pass

func _end_ai_cache_batch() -> void:
	pass

func _ziskej_core_state_cached(_state_tag: String) -> String:
	return ""

func _navrhni_core_obranu(_state_tag: String, _from_id: int, _core_state: String = "", _frontline_cache: Dictionary = {}) -> Dictionary:
	return {}

func _ai_debug(_msg: String) -> void:
	pass

# Main game state lives here. Kinda giant, but it keeps map, econ and diplo in one place.
# This is the core runtime authority for turn flow, economy, war/diplomacy and save data.
# Simple usage: other scripts read values and call helper methods.
# Hard part: many caches/queues exist to keep end-turn processing fast and avoid UI stutter.

const AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE := 1.25
const AI_DECLARE_WAR_MIN_ATTACK_FORCE := 1800
const AI_DECLARE_WAR_MAX_RELATION := -10.0
const PEACE_WAR_COOLDOWN_TURNS := 5
const PEACE_POINTS_PER_OCCUPIED_CORE := 14
const PEACE_POINTS_CAPITAL_BONUS := 25
const PEACE_POINTS_BASE := 20
const PEACE_COST_PROVINCE := 8
const PEACE_COST_VASSAL := 40
const PEACE_COST_REPARATIONS_PER_TURN := 6
const PEACE_COST_ANNEX_BASE := 18
const PEACE_MAX_REPARATIONS_TURNS := 12
const WAR_REPARATIONS_RATE := 0.10
const WAR_REPARATIONS_MIN_PAYMENT := 0.15
const VASSAL_TRIBUTE_DEFAULT_RATE := 0.15
const VASSAL_TRIBUTE_MIN_RATE := 0.0
const VASSAL_TRIBUTE_MAX_RATE := 0.60
const VASSAL_TRIBUTE_CHANGE_COOLDOWN_TURNS := 3
const AGGRESSION_RELATION_PENALTY := 12.0
const NON_AGGRESSION_MIN_REL := 10.0
var _menu_load_in_progress: bool = false
const NEXT_TURN_INPUT_COOLDOWN_MS := 300
const TURN_PROFILE_ENABLED := false
const TURN_PROFILE_WARN_MS := 1200
const AI_PROFILE_ENABLED := false
const AI_PROFILE_WARN_MS := 500
const AI_MOVEMENT_PROFILE_ENABLED := false
const AI_DECISION_DEBUG_ENABLED := false
const AI_DEBUG_MAX_LINES_PER_TURN := 150
const AI_FASTMODE_ENABLED := false
const AI_STATES_PER_TURN_CAP := 8
const AI_STATES_PER_TURN_CAP_POTATO := 4
const AI_FASTMODE_WINDOW_TURNS := 3
const DEBUG_TURN_HISTORY_MAX := 16
const TURN_STUCK_WATCHDOG_MS := 15000
const TURN_LOG_ENABLED := false
const TURN_FRAME_SLICE_ENABLED := true
# Larger slices reduce end-turn latency by yielding less often, while still keeping UI responsive.
const TURN_FRAME_SLICE_PROVINCES := 1200
const TURN_FRAME_SLICE_AI := 800
const TURN_FRAME_SLICE_AI_STATES := 16
const RESEARCH_PROJECTS_ENABLED := false
const VYZKUM_PROJEKTY := {
	"army_logistics_i": {
		"id": "army_logistics_i",
		"category": "armada",
		"name": "Logistika I",
		"description": "Lepsi zasobovani snizi cenu naboru vojaku.",
		"cost": 35.0,
		"modifiers": {"recruit_cost_mult": 0.92}
	},
	"army_professional_core": {
		"id": "army_professional_core",
		"category": "armada",
		"name": "Profesionalni sbor",
		"description": "Vycvik velitelu snizi udrzbu armady.",
		"cost": 45.0,
		"modifiers": {"upkeep_mult": 0.90}
	},
	"economy_tax_reform_i": {
		"id": "economy_tax_reform_i",
		"category": "ekonomika",
		"name": "Danova reforma I",
		"description": "Efektivnejsi vyber dani zvysi prijmy z HDP.",
		"cost": 40.0,
		"modifiers": {"income_rate_mult": 1.08}
	},
	"economy_industry_i": {
		"id": "economy_industry_i",
		"category": "ekonomika",
		"name": "Industrializace I",
		"description": "Investice do prumyslu zrychli rust HDP.",
		"cost": 55.0,
		"modifiers": {"gdp_growth_mult": 1.12}
	},
	"population_health_i": {
		"id": "population_health_i",
		"category": "populace",
		"name": "Zdravotnictvi I",
		"description": "Lepisi pece zvysi rust populace.",
		"cost": 30.0,
		"modifiers": {"population_growth_mult": 1.10}
	},
	"population_reserves_i": {
		"id": "population_reserves_i",
		"category": "populace",
		"name": "Zalohy I",
		"description": "Lepisi evidence obyvatel zvysi obnovu rekrutu.",
		"cost": 38.0,
		"modifiers": {"recruit_regen_mult": 1.18}
	}
}

const DIP_REQUEST_PRIORITY_PLAYER := 0
const DIP_REQUEST_PRIORITY_PEACE := 1
const DIP_REQUEST_PRIORITY_TRADE := 2
const DIP_REQUEST_PRIORITY_LOAN := 2
const DIP_REQUEST_PRIORITY_ALLIANCE := 3
const DIP_REQUEST_PRIORITY_NON_AGGRESSION := 4
const DIP_REQUEST_PRIORITY_MILITARY_ACCESS := 5

const TRADE_SLOT_GOLD := "gold"
const TRADE_SLOT_PROVINCE := "province"
const TRADE_SLOT_DECLARE_WAR := "declare_war"
const TRADE_SLOT_JOIN_ALLIANCE := "join_alliance"
const TRADE_SLOT_IMPROVE_RELATIONSHIP_WITH := "improve_relationship_with"
const TRADE_SLOT_WORSEN_RELATIONSHIP_WITH := "worsen_relationship_with"
const TRADE_SLOT_NON_AGGRESSION := "non_aggression"
const TRADE_SUPPORTED_SLOTS := {
	TRADE_SLOT_GOLD: true,
	TRADE_SLOT_PROVINCE: true,
	TRADE_SLOT_DECLARE_WAR: true,
	TRADE_SLOT_JOIN_ALLIANCE: true,
	TRADE_SLOT_IMPROVE_RELATIONSHIP_WITH: true,
	TRADE_SLOT_WORSEN_RELATIONSHIP_WITH: true,
	TRADE_SLOT_NON_AGGRESSION: true
}

const LOAN_MIN_TURNS := 1
const LOAN_MAX_TURNS := 36
const LOAN_MIN_INTEREST_PCT := 0.0
const LOAN_MAX_INTEREST_PCT := 100.0
const LOAN_DEFAULT_INTEREST_PCT := 6.0

const AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING := 450
const AI_MAX_ARMY_ORDERS_PER_STATE := 25
const AI_MIN_TREASURY_RESERVE := 25.0
const AI_BUILDING_COST_ECON := 150.0
const AI_BUILDING_COST_RECRUIT := 200.0
const AI_BUILDING_COST_PORT := 250.0
const AI_BUILDING_COST_FARM := 165.0
const AI_BUILDING_COST_ARMY_BASE := 225.0
const AI_BUILDING_COST_FORTRESS := 280.0
const AI_BUILD_MAX_PER_TURN := 1
const AI_ARM_LAB_MIN_SURPLUS := 45.0
const AI_RECRUIT_BASE_FRACTION := 0.32
const AI_RECRUIT_MAX_FRACTION := 0.68
const AI_RECRUIT_EMERGENCY_EXHAUSTION := 0.58
const AI_RECRUIT_EMERGENCY_PRESSURE := 900.0
const AI_RECRUIT_EMERGENCY_SPEND_BOOST := 0.24
const AI_WAR_LIGHT_PASS_THRESHOLD := 10
const AI_RECRUIT_EMERGENCY_ORDER_BONUS := 3
const AI_RECRUIT_EMERGENCY_ORDER_CAP := 12
const AI_GOAL_RETARGET_TURNS := 10
const AI_GOAL_STAGNATION_RETARGET := 7
const AI_GOAL_MIN_AGE_FOR_STAGNATION_RETARGET := 10
const AI_GOAL_RETARGET_JITTER_MAX := 3

const BUILDING_ID_ECON_HUB := "econ_hub"
const BUILDING_ID_RECRUIT_CENTER := "recruit_center"
const BUILDING_ID_PORT := "port"
const BUILDING_ID_FARM := "farm"
const BUILDING_ID_ARMY_BASE := "army_base"
const BUILDING_ID_FORTRESS := "fortress"

const BUILDING_DEFS := {
	BUILDING_ID_ECON_HUB: {
		"name": "Factory",
		"cost": AI_BUILDING_COST_ECON,
		"build_time": 3,
		"gdp_flat": 10.0,
		"max_level": 3
	},
	BUILDING_ID_RECRUIT_CENTER: {
		"name": "Training Camp",
		"cost": AI_BUILDING_COST_RECRUIT,
		"build_time": 3,
		"state_modifiers": {
			"recruit_cost_mult": 0.95
		},
		"max_level": 3
	},
	BUILDING_ID_PORT: {
		"name": "Port",
		"cost": AI_BUILDING_COST_PORT,
		"build_time": 3,
		"grant_port": true,
		"max_level": 1
	},
	BUILDING_ID_FARM: {
		"name": "Farm",
		"cost": AI_BUILDING_COST_FARM,
		"build_time": 3,
		"province_modifiers": {
			"gdp_growth_mult": 1.03,
			"population_growth_mult": 1.06,
			"recruit_regen_mult": 1.08
		},
		"max_level": 3
	},
	BUILDING_ID_ARMY_BASE: {
		"name": "Army Base",
		"cost": AI_BUILDING_COST_ARMY_BASE,
		"build_time": 3,
		"province_modifiers": {
			"upkeep_mult": 0.90
		},
		"max_level": 2
	},
	BUILDING_ID_FORTRESS: {
		"name": "Fortress",
		"cost": AI_BUILDING_COST_FORTRESS,
		"build_time": 4,
		"defense_bonus_pct": 0.18,
		"max_level": 2
	}
}


# Inputs:
# - `titulek`: Popup title.
# - `text`: Popup message.
# Outputs:
# - `bool`: True when message should be shown as critical popup.
# Execution timing: Called before queueing optional player popups.
# Steps:
# 1. Build lowercase combined text from title and body.
# 2. Check for predefined critical war/diplomacy tokens.
# 3. Return true on first token hit, else false.
# Inputs:
# - `category`: Raw log category.
# - `title`: Log title.
# - `text`: Log body.
# Outputs:
# - `String`: Normalized category used for priority/trimming.
# Execution timing: Called whenever log entries are scored or maintained.
# Steps:
# 1. Try explicit category mapping first.
# 2. Fallback to token-based detection from title/text.
# 3. Return normalized bucket (`war`, `alliance`, `treaties`, etc.).
# Inputs:
# - `category`: Raw category.
# - `title`: Log title.
# - `text`: Log text.
# Outputs:
# - `int`: Importance priority (higher = retained longer).
# Execution timing: Called during log trimming candidate selection.
# Steps:
# 1. Normalize category via `_normalizuj_kategorii_logu_pro_prioritu()`.
# 2. Map normalized category to numeric priority.
# 3. Return fallback priority when unknown.
# Inputs:
# - `titulek`: Message title.
# - `text`: Message body.
# - `kategorie`: Message category.
# Outputs: none
# Execution timing: Called for global/world event logging.
# Steps:
# 1. Validate non-empty title and text.
# 2. Append structured log entry with current turn.
# 3. Trim global log array.
# Inputs:
# - `tag`: Player state tag.
# - `limit`: Max messages to return.
# Outputs:
# - `Array`: Tail slice of player's log entries.
# Execution timing: Called by message UI queries.
# Steps:
# 1. Run pending log maintenance.
# 2. Resolve and validate player tag/log existence.
# 3. Clamp requested limit.
# 4. Return newest `limit` entries.
# Inputs:
# - `limit`: Max global messages to return.
# Outputs:
# - `Array`: Tail slice of global message log.
# Execution timing: Called by global/news UI feeds.
# Steps:
# 1. Run pending log maintenance.
# 2. Return empty array if no global entries exist.
# 3. Clamp limit and return newest entries.
# Inputs:
# - `tag`: Player state tag.
# Outputs:
# - `int`: Current number of stored messages for the player.
# Execution timing: Called by UI counters/badges.
# Steps:
# 1. Run maintenance.
# 2. Normalize tag and validate existence.
# 3. Return count or zero.
# Inputs: none
# Outputs:
# - `int`: Count of global log entries.
# Execution timing: Called by UI counters/badges.
# Steps:
# 1. Run maintenance.
# 2. Return global log size.
# Inputs:
# - `tag`: State tag.
# Outputs:
# - `String`: Display country name or normalized tag fallback.
# Execution timing: Called while filtering/matching state-related logs.
# Steps:
# 1. Normalize wanted tag and early-return when map is empty.
# 2. Scan map provinces for matching owner.
# 3. Return province country name when found, otherwise fallback tag.
func _ziskej_jmeno_statu_podle_tagu(tag: String) -> String:
	var wanted = _normalizuj_tag(tag)
	if wanted == "" or map_data.is_empty():
		return wanted
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == wanted:
			var state_name = str(d.get("country_name", wanted)).strip_edges()
			return state_name if state_name != "" else wanted
	return wanted

# Inputs:
# - `entry`: Log entry dictionary.
# - `state_tag`: State tag to test.
# Outputs:
# - `bool`: True when entry references state tag or state name.
# Execution timing: Called when building relevant-news feed for a state.
# Steps:
# 1. Normalize target tag.
# 2. Search title/text for explicit tag hit.
# 3. Resolve state name and search text for name hit.
# 4. Return whether either match succeeded.
func _zprava_obsahuje_stat(entry: Dictionary, state_tag: String) -> bool:
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return false
	var full_text = str(entry.get("title", "")) + " " + str(entry.get("text", ""))
	var hay_upper = full_text.to_upper()
	if hay_upper.findn(wanted) != -1:
		return true
	var country_name = _ziskej_jmeno_statu_podle_tagu(wanted).strip_edges()
	if country_name == "":
		return false
	return full_text.to_lower().findn(country_name.to_lower()) != -1

# Inputs:
# - `state_tag`: Target state tag.
# - `limit`: Max returned entries.
# - `jen_aktualni_kolo`: If true, include only current turn.
# Outputs:
# - `Array`: Deduplicated relevant entries from player and global logs.
# Execution timing: Called by state-focused report views.
# Steps:
# 1. Run maintenance and validate state tag.
# 2. Merge player's own entries with dedupe keying.
# 3. Add global entries mentioning the state.
# 4. Apply limit to newest entries and return.
func ziskej_relevantni_zpravy_statu(state_tag: String, limit: int = 160, jen_aktualni_kolo: bool = true) -> Array:
	_udrzba_vsech_logu()
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return []

	var merged: Array = []
	var seen: Dictionary = {}
	var target_turn = -1
	if jen_aktualni_kolo:
		target_turn = aktualni_kolo

	var player_log = log_zprav_hracu.get(wanted, []) as Array
	for entry_any in player_log:
		var entry = entry_any as Dictionary
		if jen_aktualni_kolo and int(entry.get("turn", -1)) != target_turn:
			continue
		var key = "%s|%s|%s" % [str(entry.get("turn", "")), str(entry.get("title", "")), str(entry.get("text", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(entry)

	for entry_any in log_globalnich_zprav:
		var entry = entry_any as Dictionary
		if jen_aktualni_kolo and int(entry.get("turn", -1)) != target_turn:
			continue
		if not _zprava_obsahuje_stat(entry, wanted):
			continue
		var key = "%s|%s|%s" % [str(entry.get("turn", "")), str(entry.get("title", "")), str(entry.get("text", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(entry)

	if merged.size() > limit:
		return merged.slice(merged.size() - limit, merged.size())
	return merged

# Inputs:
# - `tag_a`: First state tag.
# - `tag_b`: Second state tag.
# - `titulek`: Popup title.
# - `text`: Popup text.
# Outputs: none
# Execution timing: Called by bilateral events (war, diplomacy, etc.).
# Steps:
# 1. Normalize participant tags.
# 2. Build shared popup state-tag context list.
# 3. Send popup to each unique human participant.
func _pridej_popup_zucastnenym_hracum(tag_a: String, tag_b: String, titulek: String, text: String) -> void:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var popup_tags: Array = []
	if a != "" and a != "SEA":
		popup_tags.append(a)
	if b != "" and b != "SEA" and b != a:
		popup_tags.append(b)
	var pridane: Dictionary = {}
	for t in [a, b]:
		if t == "" or pridane.has(t):
			continue
		if je_lidsky_stat(t):
			_pridej_popup_hraci(t, titulek, text, false, popup_tags)
			pridane[t] = true

# Inputs: none
# Outputs: none
# Execution timing: Called when active player UI should flush pending popups.
# Steps:
# 1. Resolve active player and queued popup list.
# 2. Resolve map loader popup API availability.
# 3. Show batch popup when multiple items exist.
# 4. Otherwise show items one by one.
# 5. Clear queue after display.
func _zobraz_cekajici_popupy_aktivniho_hrace() -> void:
	var aktivni = _normalizuj_tag(hrac_stat)
	if aktivni == "":
		return
	if not cekajici_popupy_hracu.has(aktivni):
		return

	var fronta = (cekajici_popupy_hracu[aktivni] as Array)
	if fronta.is_empty():
		return

	var map_loader = _get_map_loader()
	if map_loader == null or not map_loader.has_method("_ukaz_bitevni_popup"):
		return

	var kopie_fronty = fronta.duplicate(true)
	if kopie_fronty.size() > 1:
		var batch_items: Array = []
		var shown = min(kopie_fronty.size(), POPUP_BATCH_MAX_ITEMS)
		for i in range(shown):
			var item_any = kopie_fronty[i]
			var item = item_any as Dictionary
			var t = str(item.get("title", "Report")).strip_edges()
			var msg = str(item.get("text", "")).strip_edges()
			if msg == "":
				continue
			batch_items.append({"title": t if t != "" else "Report", "text": msg, "state_tags": item.get("state_tags", []) as Array})
		var remaining = kopie_fronty.size() - shown
		if remaining > 0:
			batch_items.append({"title": "System", "text": "+%d additional reports were queued this turn." % remaining, "state_tags": []})
		if not batch_items.is_empty():
			if map_loader.has_method("_ukaz_batch_popup"):
				await map_loader._ukaz_batch_popup(batch_items)
			else:
				var bloky: Array = []
				for bi in batch_items:
					bloky.append("[%s]\n%s" % [str(bi.get("title", "Report")), str(bi.get("text", ""))])
				await map_loader._ukaz_bitevni_popup("Reports", "\n\n".join(bloky))
		fronta.clear()
		return

	for item in kopie_fronty:
		var t = str(item.get("title", "Report"))
		var msg = str(item.get("text", ""))
		var msg_tags = item.get("state_tags", []) as Array
		if msg.strip_edges() == "":
			continue
		await map_loader._ukaz_bitevni_popup(t, msg, {}, msg_tags)
	fronta.clear()

func _sjednot_financni_toky_cache() -> void:
	# Inputs: none
	# Outputs: none
	# Execution timing: Called when cleaning tribute/reparations finance flow state.
	# Steps:
	# 1. Normalize vassal relations and tribute rates/cooldowns.
	# 2. Filter and normalize reparations records.
	# 3. Replace runtime structures with cleaned versions.
	_sim_cache_validni = false
	var sjednocene_vztahy: Dictionary = {}
	var sjednocene_odvody: Dictionary = {}
	var sjednocene_cooldowny: Dictionary = {}
	for subject_any in vazalske_vztahy.keys():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or subject == "SEA" or overlord == "" or overlord == "SEA" or subject == overlord:
			continue
		sjednocene_vztahy[subject] = overlord
		var rate_value = float(vazalske_odvody.get(subject_any, vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)))
		sjednocene_odvody[subject] = clamp(rate_value, VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
		var cooldown_value = int(vazalske_odvody_posledni_zmena_kolo.get(subject_any, vazalske_odvody_posledni_zmena_kolo.get(subject, -1000000)))
		if sjednocene_cooldowny.has(subject):
			sjednocene_cooldowny[subject] = max(int(sjednocene_cooldowny[subject]), cooldown_value)
		else:
			sjednocene_cooldowny[subject] = cooldown_value
	vazalske_vztahy = sjednocene_vztahy
	vazalske_odvody = sjednocene_odvody
	vazalske_odvody_posledni_zmena_kolo = sjednocene_cooldowny

	var sjednocene_reparace: Array = []
	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if from_tag == "" or from_tag == "SEA" or to_tag == "" or to_tag == "SEA" or from_tag == to_tag or remaining <= 0:
			continue
		var rate = clamp(float(rep.get("rate", WAR_REPARATIONS_RATE)), 0.01, 0.50)
		sjednocene_reparace.append({
			"from": from_tag,
			"to": to_tag,
			"remaining_turns": remaining,
			"rate": rate
		})
	valecne_reparace = sjednocene_reparace

func _oznac_runtime_cache_jako_studene() -> void:
	# Inputs: none
	# Outputs: none
	# Execution timing: Called after state changes that invalidate warmed caches.
	# Steps:
	# 1. Mark runtime caches as not prewarmed.
	_runtime_caches_warmed = false

# Inputs: none
# Outputs: none
# Execution timing: Called before heavy operations needing ready relation/turn caches.
# Steps:
# 1. Exit when already warm or map is unavailable.
# 2. Load relationship cache.
# 3. Rebuild turn cache.
# 4. Mark runtime caches as warmed.
func _prewarm_runtime_cache_if_needed() -> void:
	if _runtime_caches_warmed:
		return
	if map_data.is_empty():
		return
	_nacti_vztahy_statu()
	_rebuild_turn_cache()
	_runtime_caches_warmed = true

# Inputs: none
# Outputs:
# - `Dictionary`: Current map province dictionary for save snapshotting.
# Execution timing: Called during save-state assembly.
# Steps:
# 1. Try reading live provinces from map loader.
# 2. Fallback to `map_data` if loader/provinces are unavailable.
func _ziskej_data_mapy_pro_ulozeni() -> Dictionary:
	var map_loader = _get_map_loader()
	if map_loader and "provinces" in map_loader:
		return (map_loader.provinces as Dictionary)
	return map_data

# Inputs: none
# Outputs:
# - `Dictionary`: Serialized save-state snapshot, or empty dictionary on failure.
# Execution timing: Called by manual/auto save routines.
# Steps:
# 1. Persist active multiplayer finance state if needed.
# 2. Resolve current live map data and sync `map_data` reference.
# 3. Deep-copy map snapshot for immutable serialization input.
# 4. Return assembled save payload with runtime state fields.
func _vytvor_save_state() -> Dictionary:
	# Multiplayer keeps per-player finance caches; persist active player first.
	if lokalni_hraci_staty.size() > 1:
		_uloz_finance_aktivniho_hrace()
	# Keep runtime map_data bound to live map dictionary; only snapshot is deep-copied.
	var live_map = _ziskej_data_mapy_pro_ulozeni()
	if live_map != map_data:
		map_data = live_map
	# Save always uses a deep-copied map snapshot so runtime refs cannot mutate saved data.
	var map_snapshot = live_map.duplicate(true)
	if map_snapshot.is_empty():
		return {}
	var relationship_state = _get_relationship_store().export_state()

	return {
		"hrac_stat": hrac_stat,
		"spectate_mode_active": _spectate_mode_active,
		"hrac_jmeno": hrac_jmeno,
		"hrac_ideologie": hrac_ideologie,
		"statni_kasa": statni_kasa,
		"celkovy_prijem": celkovy_prijem,
		"aktualni_kolo": aktualni_kolo,
		"map_data": map_snapshot,
		"provincie_cooldowny": provincie_cooldowny.duplicate(true),
		"ai_kasy": ai_kasy.duplicate(true),
		"ai_profily": _ai_profily.duplicate(true),
		"ai_randomized_ideologies_applied": _ai_randomized_ideologies_applied,
		"global_ai_aggression_level": _global_ai_aggression_level,
		"lokalni_hraci_staty": lokalni_hraci_staty.duplicate(true),
		"aktivni_hrac_index": aktivni_hrac_index,
		"hrac_kasy": hrac_kasy.duplicate(true),
		"hrac_prijmy": hrac_prijmy.duplicate(true),
		"hrac_kasa_inicializovana": hrac_kasa_inicializovana.duplicate(true),
		"notifikace_pujcek_hracu": notifikace_pujcek_hracu.duplicate(true),
		"log_zprav_hracu": log_zprav_hracu.duplicate(true),
		"log_globalnich_zprav": log_globalnich_zprav.duplicate(true),
		"vyzkum_statu": vyzkum_statu.duplicate(true),
		"armadni_lab_statu": armadni_lab_statu.duplicate(true),
		"valky": valky.duplicate(true),
		"cekajici_kapitulace": cekajici_kapitulace.duplicate(true),
		"cekajici_mirove_nabidky": cekajici_mirove_nabidky.duplicate(true),
		"cekajici_mirove_konference": cekajici_mirove_konference.duplicate(true),
		"mirove_konference_seq": mirove_konference_seq,
		"mirove_body_peak_dle_smeru": mirove_body_peak_dle_smeru.duplicate(true),
		"vazalske_vztahy": vazalske_vztahy.duplicate(true),
		"vazalske_odvody": vazalske_odvody.duplicate(true),
		"vazalske_odvody_posledni_zmena_kolo": vazalske_odvody_posledni_zmena_kolo.duplicate(true),
		"valecne_reparace": valecne_reparace.duplicate(true),
		"aktivni_pujcky": aktivni_pujcky.duplicate(true),
		"cekajici_pujcky": cekajici_pujcky.duplicate(true),
		"aliance_statu": aliance_statu.duplicate(true),
		"aliance_skupiny": aliance_skupiny.duplicate(true),
		"aliance_skupiny_seq": _aliance_skupiny_seq,
		"neagresivni_smlouvy": neagresivni_smlouvy.duplicate(true),
		"vojensky_pristup": vojensky_pristup.duplicate(true),
		"povalecne_cooldowny": povalecne_cooldowny.duplicate(true),
		"cekajici_diplomaticke_zadosti": cekajici_diplomaticke_zadosti.duplicate(true),
		"cekajici_aliancni_zadosti": cekajici_aliancni_zadosti.duplicate(true),
		"presun_hlavniho_mesta_posledni_kolo": _presun_hlavniho_mesta_posledni_kolo.duplicate(true),
		"vztah_akce_posledni_kolo": relationship_state.get("last_action_turn", {}),
		"vztahy_statu": relationship_state.get("relationships", {}),
		"vztahy_nactene": bool(relationship_state.get("loaded", false)),
		"hrac_kasa_inicializovana_single": _hrac_kasa_inicializovana
	}

# Inputs:
# - `state`: Save-state payload dictionary.
# Outputs:
# - `bool`: True when payload is applied successfully.
# Execution timing: Called right after reading save data from disk.
# Steps:
# 1. Validate payload and load core identity/economy/map fields first.
# 2. Rebuild or clear runtime caches that depend on loaded data.
# 3. Restore diplomacy, economy, and per-player runtime dictionaries.
# 4. Normalize legacy/spectate edge cases and synchronize finance caches.
# 5. Return success when apply flow completes.
func _aplikuj_save_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	# Core identity/state fields must be loaded first because later branches depend on them.
	hrac_stat = str(state.get("hrac_stat", hrac_stat)).strip_edges().to_upper()
	_spectate_mode_active = false
	hrac_jmeno = str(state.get("hrac_jmeno", ""))
	hrac_ideologie = str(state.get("hrac_ideologie", ""))
	statni_kasa = float(state.get("statni_kasa", statni_kasa))
	celkovy_prijem = float(state.get("celkovy_prijem", celkovy_prijem))
	aktualni_kolo = int(state.get("aktualni_kolo", aktualni_kolo))
	var loaded_map_any = state.get("map_data", state.get("provinces", {}))
	if not (loaded_map_any is Dictionary):
		loaded_map_any = {}
	map_data = (loaded_map_any as Dictionary).duplicate(true)
	# Save load invalidates every runtime cache to prevent stale turn-time data.
	_oznac_runtime_cache_jako_studene()
	provincie_cooldowny = _normalizuj_provincie_cooldowny(state.get("provincie_cooldowny", {}))
	ai_kasy = (state.get("ai_kasy", {}) as Dictionary).duplicate(true)
	_ai_profily = (state.get("ai_profily", {}) as Dictionary).duplicate(true)
	_ai_randomized_ideologies_applied = bool(state.get("ai_randomized_ideologies_applied", false))
	_global_ai_aggression_level = float(state.get("global_ai_aggression_level", 0.5))
	_ai_goal_cache.clear()
	_ai_operation_plan_cache.clear()
	lokalni_hraci_staty = (state.get("lokalni_hraci_staty", []) as Array).duplicate(true)
	# Spectate mode is temporarily disabled: normalize legacy saves to normal player flow.
	if lokalni_hraci_staty.is_empty():
		var loaded_player_tag = _normalizuj_tag(hrac_stat)
		if loaded_player_tag == "" or loaded_player_tag == "SPECTATE":
			loaded_player_tag = "ALB"
		lokalni_hraci_staty = [loaded_player_tag]
	if _normalizuj_tag(hrac_stat) == "" or _normalizuj_tag(hrac_stat) == "SPECTATE":
		hrac_stat = str(lokalni_hraci_staty[0])
	aktivni_hrac_index = int(state.get("aktivni_hrac_index", 0))
	hrac_kasy = (state.get("hrac_kasy", {}) as Dictionary).duplicate(true)
	hrac_prijmy = (state.get("hrac_prijmy", {}) as Dictionary).duplicate(true)
	hrac_kasa_inicializovana = (state.get("hrac_kasa_inicializovana", {}) as Dictionary).duplicate(true)
	notifikace_pujcek_hracu = (state.get("notifikace_pujcek_hracu", {}) as Dictionary).duplicate(true)
	log_zprav_hracu = (state.get("log_zprav_hracu", {}) as Dictionary).duplicate(true)
	log_globalnich_zprav = (state.get("log_globalnich_zprav", []) as Array).duplicate(true)
	vyzkum_statu = (state.get("vyzkum_statu", {}) as Dictionary).duplicate(true)
	armadni_lab_statu = (state.get("armadni_lab_statu", {}) as Dictionary).duplicate(true)
	valky = (state.get("valky", {}) as Dictionary).duplicate(true)
	_normalizuj_valecne_klice()
	cekajici_kapitulace = (state.get("cekajici_kapitulace", []) as Array).duplicate(true)
	cekajici_mirove_nabidky = (state.get("cekajici_mirove_nabidky", []) as Array).duplicate(true)
	cekajici_mirove_konference = (state.get("cekajici_mirove_konference", {}) as Dictionary).duplicate(true)
	mirove_konference_seq = int(state.get("mirove_konference_seq", 0))
	mirove_body_peak_dle_smeru = (state.get("mirove_body_peak_dle_smeru", {}) as Dictionary).duplicate(true)
	vazalske_vztahy = (state.get("vazalske_vztahy", {}) as Dictionary).duplicate(true)
	vazalske_odvody = (state.get("vazalske_odvody", {}) as Dictionary).duplicate(true)
	vazalske_odvody_posledni_zmena_kolo = (state.get("vazalske_odvody_posledni_zmena_kolo", {}) as Dictionary).duplicate(true)
	valecne_reparace = (state.get("valecne_reparace", []) as Array).duplicate(true)
	aktivni_pujcky = (state.get("aktivni_pujcky", []) as Array).duplicate(true)
	cekajici_pujcky = (state.get("cekajici_pujcky", []) as Array).duplicate(true)
	aliance_statu = (state.get("aliance_statu", {}) as Dictionary).duplicate(true)
	aliance_skupiny = (state.get("aliance_skupiny", {}) as Dictionary).duplicate(true)
	_aliance_skupiny_seq = int(state.get("aliance_skupiny_seq", 0))
	neagresivni_smlouvy = (state.get("neagresivni_smlouvy", {}) as Dictionary).duplicate(true)
	vojensky_pristup = (state.get("vojensky_pristup", {}) as Dictionary).duplicate(true)
	povalecne_cooldowny = (state.get("povalecne_cooldowny", {}) as Dictionary).duplicate(true)
	cekajici_diplomaticke_zadosti = (state.get("cekajici_diplomaticke_zadosti", {}) as Dictionary).duplicate(true)
	cekajici_aliancni_zadosti = (state.get("cekajici_aliancni_zadosti", []) as Array).duplicate(true)
	_presun_hlavniho_mesta_posledni_kolo = (state.get("presun_hlavniho_mesta_posledni_kolo", {}) as Dictionary).duplicate(true)
	_get_relationship_store().import_state(
		state.get("vztahy_statu", {}) as Dictionary,
		state.get("vztah_akce_posledni_kolo", {}) as Dictionary,
		bool(state.get("vztahy_nactene", true))
	)
	_hrac_kasa_inicializovana = bool(state.get("hrac_kasa_inicializovana_single", _hrac_kasa_inicializovana))
	_sjednot_financni_toky_cache()

	if not lokalni_hraci_staty.is_empty():
		if not lokalni_hraci_staty.has(hrac_stat):
			hrac_stat = str(lokalni_hraci_staty[0])
		aktivni_hrac_index = clampi(aktivni_hrac_index, 0, lokalni_hraci_staty.size() - 1)
		_sjednot_multiplayer_finance_cache()

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data.duplicate(true)
			map_data = map_loader.provinces
		if map_loader.has_method("_invalidate_naval_reachability_cache"):
			map_loader._invalidate_naval_reachability_cache()
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()

	_synchronizuj_jmeno_a_ideologii_hrace()
	_prewarm_runtime_cache_if_needed()
	kolo_zmeneno.emit()
	return true

# Inputs: none
# Outputs: none
# Execution timing: Called when starting a new game.
# Steps:
# 1. Reset core player/economy/turn state.
# 2. Clear map, AI, and runtime caches.
# 3. Reset diplomacy, loans, alliance, and pending-request state.
# 4. Clear turn/relation caches to pristine defaults.
func reset_pro_novou_hru() -> void:
	hrac_stat = "ALB"
	hrac_jmeno = ""
	hrac_ideologie = ""
	statni_kasa = 0.0
	celkovy_prijem = 0.0
	aktualni_kolo = 1

	map_data.clear()
	_oznac_runtime_cache_jako_studene()
	provincie_cooldowny.clear()
	ai_kasy.clear()
	_ai_profily.clear()
	_ai_randomized_ideologies_applied = false
	_global_ai_aggression_level = 0.5
	_spectate_mode_active = false
	_ai_goal_cache.clear()
	_ai_operation_plan_cache.clear()
	_hrac_kasa_inicializovana = false
	lokalni_hraci_staty.clear()
	aktivni_hrac_index = 0
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	notifikace_pujcek_hracu.clear()
	log_zprav_hracu.clear()
	log_globalnich_zprav.clear()
	vyzkum_statu.clear()
	armadni_lab_statu.clear()

	valky.clear()
	cekajici_kapitulace.clear()
	cekajici_mirove_nabidky.clear()
	cekajici_mirove_konference.clear()
	mirove_konference_seq = 0
	mirove_body_peak_dle_smeru.clear()
	vazalske_vztahy.clear()
	vazalske_odvody.clear()
	vazalske_odvody_posledni_zmena_kolo.clear()
	valecne_reparace.clear()
	aktivni_pujcky.clear()
	cekajici_pujcky.clear()
	aliance_statu.clear()
	aliance_skupiny.clear()
	_aliance_skupiny_seq = 0
	neagresivni_smlouvy.clear()
	vojensky_pristup.clear()
	povalecne_cooldowny.clear()
	cekajici_diplomaticke_zadosti.clear()
	cekajici_aliancni_zadosti.clear()
	_presun_hlavniho_mesta_posledni_kolo.clear()

	_core_state_cache.clear()
	_get_relationship_store().reset()
	_turn_cache_valid = false
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()

# Inputs: none
# Outputs:
# - `Array`: Deep-copied list of active loans.
# Execution timing: Called by UI and gameplay systems reading loan state.
# Steps:
# 1. Return deep copy of `aktivni_pujcky`.
func ziskej_aktivni_pujcky() -> Array:
	return aktivni_pujcky.duplicate(true)

# Inputs:
# - `slot_name`: Requested slot name.
# Outputs:
# - `bool`: True when slot save write succeeds.
# Execution timing: Called by manual save and quicksave flows.
# Steps:
# 1. Ensure save directory exists.
# 2. Build save snapshot.
# 3. Write to slot path.
# 4. Also write legacy quicksave path for backward compatibility.
func uloz_hru_do_slotu(slot_name: String) -> bool:
	_zajisti_slozku_save()
	var state = _vytvor_save_state()
	if state.is_empty():
		return false

	var slot_path = _cesta_slotu_save(slot_name)
	var ok_slot = _uloz_state_do_cesty(slot_path, state)
	# Keep legacy quicksave path for backward compatibility with existing flows.
	_uloz_state_do_cesty(SAVEGAME_STATE_PATH, state)
	return ok_slot

# Inputs:
# - `slot_name`: Slot name to load.
# Outputs:
# - `bool`: True when slot state is loaded and applied.
# Execution timing: Called by load slot actions.
# Steps:
# 1. Resolve slot path.
# 2. Read slot state dictionary.
# 3. Apply loaded state to runtime.
func nacti_hru_ze_slotu(slot_name: String) -> bool:
	var slot_path = _cesta_slotu_save(slot_name)
	var state = _nacti_state_z_cesty(slot_path)
	return _aplikuj_save_state(state)

func nacti_posledni_hru() -> bool:
	# Inputs: none
	# Outputs:
	# - `bool`: True when a save was successfully loaded.
	# Execution timing: Called by continue/load-last-game actions.
	# Steps:
	# 1. Try newest slot save first.
	# 2. Fallback to legacy quickload path when needed.
	var slots = ziskej_save_sloty()
	if not slots.is_empty():
		var newest = slots[0] as Dictionary
		var slot_name = str(newest.get("name", ""))
		if slot_name != "" and nacti_hru_ze_slotu(slot_name):
			return true
	return nacti_hru()

# Inputs: none
# Outputs:
# - `bool`: True when quicksave succeeded.
# Execution timing: Called by generic save shortcuts/actions.
# Steps:
# 1. Delegate to slot save using `quicksave` key.
func uloz_hru() -> bool:
	return uloz_hru_do_slotu("quicksave")

# Inputs: none
# Outputs:
# - `bool`: True when either legacy or slot quicksave loads successfully.
# Execution timing: Called by generic load shortcuts/actions.
# Steps:
# 1. Attempt legacy quicksave load.
# 2. If legacy fails, fallback to slot-based quicksave load.
func nacti_hru() -> bool:
	var legacy_state = _nacti_state_z_cesty(SAVEGAME_STATE_PATH)
	if _aplikuj_save_state(legacy_state):
		return true
	# Fallback to slot-based quicksave if legacy file is missing.
	return nacti_hru_ze_slotu("quicksave")

# Ai generated or editted start (priloha_a.txt)
func spust_load_ze_slotu_pres_scenu(slot_key: String, scene_path: String) -> void:
	# Inputs:
	# - `slot_key`: Slot identifier or special legacy key.
	# - `scene_path`: Map scene path to load before applying save data.
	# Outputs: none
	# Execution timing: Called by menu load flow entry point.
	# Steps:
	# 1. Guard against concurrent menu-load operations.
	# 2. Mark load-in-progress.
	# 3. Defer actual load pipeline to scene-safe continuation method.
	if _menu_load_in_progress:
		push_warning("Menu load is already in progress.")
		return
	_menu_load_in_progress = true
	call_deferred("_dokoncit_load_ze_slotu_pres_scenu", slot_key, scene_path)

# Ai generated or editted end (priloha_a.txt)
func _pockej_na_map_loader_pripravenost(tree: SceneTree, max_frames: int = 300) -> bool:
	# Inputs:
	# - `tree`: Active scene tree.
	# - `max_frames`: Max frames to wait for map-loader readiness.
	# Outputs:
	# - `bool`: True when map loader becomes ready before timeout.
	# Execution timing: Called during scene-based load workflow.
	# Steps:
	# 1. Validate tree.
	# 2. Poll map loader each frame.
	# 3. Use readiness method when available, else accept loader presence.
	# 4. Return false after timeout.
	if tree == null:
		return false
	for _i in range(max_frames):
		var loader = _get_map_loader()
		if loader != null:
			if loader.has_method("je_pripraveno_pro_load"):
				if bool(loader.je_pripraveno_pro_load()):
					return true
			else:
				return true
		await tree.process_frame
	return false

# Inputs:
# - `slot_key`: Slot key or legacy sentinel.
# - `scene_path`: Target map scene path.
# Outputs: none
# Execution timing: Deferred continuation for menu load operation.
# Steps:
# 1. Validate scene tree and switch to target map scene.
# 2. Wait for map loader readiness.
# 3. Load requested save source (slot or legacy).
# 4. Fallback to latest save when initial load fails.
# 5. Report failure and clear in-progress flag when needed.
func _dokoncit_load_ze_slotu_pres_scenu(slot_key: String, scene_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		_menu_load_in_progress = false
		push_warning("Load canceled: SceneTree is unavailable.")
		return

	var err = tree.change_scene_to_file(scene_path)
	if err != OK:
		_menu_load_in_progress = false
		push_warning("Failed to open map for Load. Error: %s" % str(err))
		return

	await tree.process_frame
	if not await _pockej_na_map_loader_pripravenost(tree):
		_menu_load_in_progress = false
		push_warning("Load canceled: map scene did not initialize in time.")
		return

	var loaded_ok := false
	if slot_key == "__legacy__":
		loaded_ok = nacti_hru()
	else:
		loaded_ok = nacti_hru_ze_slotu(slot_key)

	if not loaded_ok:
		loaded_ok = nacti_posledni_hru()

	if not loaded_ok:
		_menu_load_in_progress = false
		push_warning("Load failed: save could not be loaded.")
		return

	# Defensive sync for visuals and runtime caches.
	await tree.process_frame
	var loader = _get_map_loader()
	if loader != null and not map_data.is_empty():
		if "provinces" in loader:
			loader.provinces = map_data.duplicate(true)
			map_data = loader.provinces
		if loader.has_method("_rebuild_movement_topology_cache"):
			loader._rebuild_movement_topology_cache()
		if loader.has_method("_invalidate_naval_reachability_cache"):
			loader._invalidate_naval_reachability_cache()
		if loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			loader._aktualizuj_aktivni_mapovy_mod()
		if loader.has_method("aktualizuj_ikony_armad"):
			loader.aktualizuj_ikony_armad()
		if loader.has_method("aktualizuj_vlajky_hlavnich_mest"):
			loader.aktualizuj_vlajky_hlavnich_mest()

	_menu_load_in_progress = false

# Inputs: none
# Outputs:
# - `Node|null`: Active map-loader node implementing army turn methods.
# Execution timing: Called by systems that need runtime map scene access.
# Steps:
# 1. Reuse cached loader when scene and instance are still valid.
# 2. Try current scene as loader.
# 3. Fallback to `Map` child lookup.
# 4. Update cache and return loader or `null`.
func _get_map_loader():
	var current_scene = get_tree().current_scene
	if _map_loader_cache_scene == current_scene and _map_loader_cache != null and is_instance_valid(_map_loader_cache) and _map_loader_cache.has_method("zpracuj_tah_armad"):
		return _map_loader_cache
	var map_loader = current_scene
	if map_loader and map_loader.has_method("zpracuj_tah_armad"):
		_map_loader_cache = map_loader
		_map_loader_cache_scene = current_scene
		return map_loader
	if map_loader:
		var child_map = map_loader.find_child("Map", true, false)
		if child_map and child_map.has_method("zpracuj_tah_armad"):
			_map_loader_cache = child_map
			_map_loader_cache_scene = current_scene
			return child_map
	_map_loader_cache = null
	_map_loader_cache_scene = current_scene
	return null

# Ai generated or editted start (priloha_a.txt)
func _normalizuj_tag(tag: String) -> String:
	_tag_normalizer.set_map_data(map_data)
	return _tag_normalizer.normalize_tag(tag)

# Ai generated or editted end (priloha_a.txt)
func _je_pravdepodobny_stat_tag(value: String) -> bool:
	return TagNormalizerScript.is_likely_country_tag(value)

# Inputs: none
# Outputs: none
# Execution timing: Called when tag alias cache is dirty.
# Steps:
# 1. Clear existing alias cache.
# 2. Register direct owner-tag mappings.
# 3. Build non-conflicting country-name -> owner mappings.
# 4. Merge valid aliases into cache and clear dirty flag.
func _rebuild_tag_alias_cache() -> void:
	_tag_normalizer.set_map_data(map_data)
	_tag_normalizer.invalidate()

# Inputs:
# - `raw_name`: Raw country name.
# Outputs:
# - `String`: Uppercased, trimmed country name.
# Execution timing: Called by owner/name lookup helpers.
# Steps:
# 1. Trim whitespace and uppercase text.
func _normalizuj_nazev_statu(raw_name: String) -> String:
	return _tag_normalizer.normalize_country_name(raw_name)

# Inputs:
# - `owner_tag`: Owner tag.
# Outputs:
# - `String`: Normalized country name for owner, or empty string.
# Execution timing: Called by UI and log matching helpers.
# Steps:
# 1. Normalize requested owner tag.
# 2. Scan map provinces for matching owner.
# 3. Return first non-empty normalized country name.
func _ziskej_nazev_statu_podle_owner(owner_tag: String) -> String:
	_tag_normalizer.set_map_data(map_data)
	return _tag_normalizer.country_name_for_owner(owner_tag)

# Inputs:
# - `level`: Requested quality level.
# Outputs:
# - `int`: Clamped quality in allowed range.
# Execution timing: Called across army-lab quality calculations.
# Steps:
# 1. Clamp level to `0..8`.
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
# Army lab is basically a tiny grid-builder per state, jen schovany tady v manageru.
