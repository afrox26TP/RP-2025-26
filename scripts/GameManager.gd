extends Node

signal kolo_zmeneno 
signal zpracovani_tahu_zmeneno(aktivni: bool)

var hrac_stat = "ALB" 
var hrac_jmeno = "" 
var hrac_ideologie = "" 

# Initial treasury is set dynamically from 5% of total state GDP.
var statni_kasa: float = 0.0 
var celkovy_prijem: float = 0.0
var aktualni_kolo: int = 1

var map_data: Dictionary = {}
var provincie_cooldowny: Dictionary = {}
var ai_kasy: Dictionary = {} 
var _hrac_kasa_inicializovana: bool = false
var lokalni_hraci_staty: Array = []
var aktivni_hrac_index: int = 0
var hrac_kasy: Dictionary = {}
var hrac_prijmy: Dictionary = {}
var hrac_kasa_inicializovana: Dictionary = {}
var cekajici_popupy_hracu: Dictionary = {}
var log_zprav_hracu: Dictionary = {}
var log_globalnich_zprav: Array = []
var vyzkum_statu: Dictionary = {}
var armadni_lab_statu: Dictionary = {}
var _defer_log_maintenance: bool = false
var _log_maintenance_dirty: bool = false

const AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE := 1.25
const AI_DECLARE_WAR_MIN_ATTACK_FORCE := 1800
const AI_DECLARE_WAR_MAX_RELATION := -10.0
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
		"recruit_cost_mult": 1.08,
		"upkeep_mult": 0.96,
		"income_rate_mult": 1.08,
		"gdp_growth_mult": 1.12,
		"population_growth_mult": 1.05,
		"recruit_regen_mult": 0.92
	},
	"kralovstvi": {
		"recruit_cost_mult": 1.00,
		"upkeep_mult": 0.99,
		"income_rate_mult": 1.02,
		"gdp_growth_mult": 1.03,
		"population_growth_mult": 1.02,
		"recruit_regen_mult": 1.00
	},
	"autokracie": {
		"recruit_cost_mult": 0.94,
		"upkeep_mult": 1.08,
		"income_rate_mult": 0.98,
		"gdp_growth_mult": 0.98,
		"population_growth_mult": 0.99,
		"recruit_regen_mult": 1.12
	},
	"komunismus": {
		"recruit_cost_mult": 0.88,
		"upkeep_mult": 1.12,
		"income_rate_mult": 0.94,
		"gdp_growth_mult": 0.93,
		"population_growth_mult": 1.03,
		"recruit_regen_mult": 1.20
	},
	"nacismus": {
		"recruit_cost_mult": 0.82,
		"upkeep_mult": 1.18,
		"income_rate_mult": 0.90,
		"gdp_growth_mult": 0.88,
		"population_growth_mult": 0.96,
		"recruit_regen_mult": 1.30
	},
	"fasismus": {
		"recruit_cost_mult": 0.82,
		"upkeep_mult": 1.18,
		"income_rate_mult": 0.90,
		"gdp_growth_mult": 0.88,
		"population_growth_mult": 0.96,
		"recruit_regen_mult": 1.30
	}
}
const BASE_RECRUIT_COST_PER_SOLDIER := 0.05
const BASE_UPKEEP_PER_SOLDIER := 0.001
const BASE_INCOME_RATE := 0.10
const BASE_GDP_GROWTH_PER_TURN := 0.5
const BASE_POP_GROWTH_RATIO := 0.0015
const CAPITAL_RELOCATION_BASE_COST := 25.0
const CAPITAL_RELOCATION_HDP_RATIO := 0.12
const CAPITAL_RELOCATION_DISTANCE_STEP := 250.0
const CAPITAL_RELOCATION_DISTANCE_RATIO_PER_STEP := 0.06
const CAPITAL_RELOCATION_DISTANCE_MULTIPLIER_MAX := 2.25
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
const AGGRESSION_RELATION_PENALTY := 12.0
const NON_AGGRESSION_MIN_REL := 10.0
const NON_AGGRESSION_DURATION_TURNS := 10
const SAVEGAME_STATE_PATH := "user://savegame.dat"
const SAVE_SLOTS_DIR := "user://saves"
const SAVE_SLOT_EXT := ".dat"
const MAX_LOG_ZPRAV := 500
const NEXT_TURN_INPUT_COOLDOWN_MS := 0
const TURN_PROFILE_ENABLED := false
const TURN_PROFILE_WARN_MS := 1200
const AI_PROFILE_ENABLED := false
const AI_PROFILE_WARN_MS := 500
const AI_MOVEMENT_PROFILE_ENABLED := false
const AI_DECISION_DEBUG_ENABLED := true
const TURN_STUCK_WATCHDOG_MS := 15000
const TURN_LOG_ENABLED := false
const TURN_FRAME_SLICE_ENABLED := false
const TURN_FRAME_SLICE_PROVINCES := 140
const TURN_FRAME_SLICE_AI := 90
const TURN_FRAME_SLICE_AI_STATES := 1
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

# Diplomacy
var valky: Dictionary = {}
var cekajici_kapitulace: Array = []
var cekajici_mirove_nabidky: Array = []
var cekajici_mirove_konference: Dictionary = {}
var mirove_konference_seq: int = 0
var vazalske_vztahy: Dictionary = {}
var vazalske_odvody: Dictionary = {}
var vazalske_odvody_posledni_zmena_kolo: Dictionary = {}
var valecne_reparace: Array = []
var aliance_statu: Dictionary = {}
var aliance_skupiny: Dictionary = {}
var _aliance_skupiny_seq: int = 0
var neagresivni_smlouvy: Dictionary = {}
var vojensky_pristup: Dictionary = {}
var povalecne_cooldowny: Dictionary = {}
var cekajici_diplomaticke_zadosti: Dictionary = {}
var cekajici_aliancni_zadosti: Array = []

const DIP_REQUEST_PRIORITY_PLAYER := 0
const DIP_REQUEST_PRIORITY_PEACE := 1
const DIP_REQUEST_PRIORITY_ALLIANCE := 2
const DIP_REQUEST_PRIORITY_NON_AGGRESSION := 3
const DIP_REQUEST_PRIORITY_MILITARY_ACCESS := 4

var zpracovava_se_tah: bool = false
var _last_end_turn_request_ms: int = -1000000
var _turn_watchdog_token: int = 0
var _queued_end_turn_requests: int = 0
var _presun_hlavniho_mesta_posledni_kolo: Dictionary = {}
var _core_state_cache: Dictionary = {}
var _vztahy_statu: Dictionary = {}
var _vztahy_nactene: bool = false
var _vztah_akce_posledni_kolo: Dictionary = {}
var _turn_cache_valid: bool = false
var _turn_state_soldier_power: Dictionary = {}
var _turn_state_hdp: Dictionary = {}
var _turn_border_pairs: Dictionary = {}
var _turn_active_states: Array = []
var _turn_state_owned_provinces: Dictionary = {}
var _turn_owner_by_province: Dictionary = {}
var _turn_soldiers_by_province: Dictionary = {}
var _turn_neighbors_by_province: Dictionary = {}
var _ai_phase_cache_active: bool = false
var _ai_enemy_neighbor_cache: Dictionary = {}
var _ai_threat_cache: Dictionary = {}
var _ai_border_strength_cache: Dictionary = {}
var _ai_war_pair_eval_cache: Dictionary = {}
var _ai_relation_cache: Dictionary = {}
var _ai_allies_cache: Dictionary = {}
var _ai_war_cache: Dictionary = {}
var _ai_alliance_level_cache: Dictionary = {}
var _ai_non_aggr_cache: Dictionary = {}
var _ai_can_adjust_relation_cache: Dictionary = {}
var _ai_border_cache: Dictionary = {}
var _ai_cache_batch_depth: int = 0
var _ai_war_pair_eval_dirty_states: Dictionary = {}
var _ai_profily: Dictionary = {}
var _ai_mindset_cache: Dictionary = {}
var _ai_goal_cache: Dictionary = {}
var _global_ai_aggression_level: float = 0.5
var _ai_randomized_ideologies_applied: bool = false
var _suppress_relation_global_logs: bool = false
var _map_loader_cache: Node = null
var _map_loader_cache_scene: Node = null
var _potato_mode_enabled: bool = false

const AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING := 450
const AI_MAX_ARMY_ORDERS_PER_STATE := 25
const AI_MIN_TREASURY_RESERVE := 25.0
const AI_BUILDING_COST_ECON := 150.0
const AI_BUILDING_COST_RECRUIT := 200.0
const AI_BUILDING_COST_PORT := 250.0
const AI_BUILD_MAX_PER_TURN := 1
const AI_ARM_LAB_MIN_SURPLUS := 45.0
const AI_RECRUIT_BASE_FRACTION := 0.32
const AI_RECRUIT_MAX_FRACTION := 0.68
const AI_GOAL_RETARGET_TURNS := 4
const AI_GOAL_STAGNATION_RETARGET := 2

const RELATIONSHIPS_CSV_PATH := "res://map_data/Relationships.csv"

func _normalizuj_lidske_staty(staty: Array) -> Array:
	var out: Array = []
	for s in staty:
		var tag = _normalizuj_tag(str(s))
		if tag == "" or tag == "SEA":
			continue
		if out.has(tag):
			continue
		out.append(tag)
	return out

func nastav_lokalni_hrace(staty: Array) -> void:
	var normalizovane = _normalizuj_lidske_staty(staty)
	if normalizovane.is_empty():
		normalizovane = [_normalizuj_tag(hrac_stat)]

	lokalni_hraci_staty = normalizovane
	aktivni_hrac_index = 0
	hrac_stat = str(lokalni_hraci_staty[0])
	hrac_jmeno = ""
	hrac_ideologie = ""
	_hrac_kasa_inicializovana = false
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	log_zprav_hracu.clear()
	log_globalnich_zprav.clear()
	vyzkum_statu.clear()
	armadni_lab_statu.clear()
	ai_kasy.clear()

	if not hrac_kasy.has(hrac_stat):
		hrac_kasy[hrac_stat] = statni_kasa
	if not hrac_prijmy.has(hrac_stat):
		hrac_prijmy[hrac_stat] = celkovy_prijem

	_synchronizuj_jmeno_a_ideologii_hrace()

func _pridej_popup_hraci(tag: String, titulek: String, text: String) -> void:
	var cisty_tag = _normalizuj_tag(tag)
	if cisty_tag == "" or not je_lidsky_stat(cisty_tag):
		return
	if titulek.strip_edges() == "" or text.strip_edges() == "":
		return
	_zaloguj_zpravu_hraci(cisty_tag, titulek, text, "popup")
	if not _je_dulezity_popup(titulek, text):
		return
	if not cekajici_popupy_hracu.has(cisty_tag):
		cekajici_popupy_hracu[cisty_tag] = []
	(cekajici_popupy_hracu[cisty_tag] as Array).append({
		"title": titulek,
		"text": text
	})

func _je_dulezity_popup(titulek: String, text: String) -> bool:
	var t = titulek.to_lower()
	var msg = text.to_lower()
	var combined = "%s %s" % [t, msg]

	# Keep visible popups only for critical war-state events.
	var critical_tokens = [
		"valk", "war", "kapitul", "surrender", "hlavni mesto", "capital",
		"anex", "vyhlasil valku", "declared war", "porazen", "defeated",
		"military access", "vojensky pristup"
	]
	for token in critical_tokens:
		if combined.findn(token) != -1:
			return true

	return false

func _normalizuj_kategorii_logu_pro_prioritu(category: String, title: String, text: String) -> String:
	var c = category.strip_edges().to_lower()
	match c:
		"war":
			return "war"
		"alliance":
			return "alliance"
		"treaty", "treaties", "non_aggression":
			return "treaties"
		"diplomacy":
			pass
		"gift", "gifts":
			return "gifts"
		"relations":
			return "relations"
		_:
			pass

	var body = (title + " " + text).to_lower()
	var war_tokens = ["valk", "war", "mir", "peace", "kapitul", "okup", "anex", "surrender"]
	for token in war_tokens:
		if body.findn(token) != -1:
			return "war"

	var alliance_tokens = ["alianc", "alliance", "spojenec"]
	for token in alliance_tokens:
		if body.findn(token) != -1:
			return "alliance"

	var treaty_tokens = ["neagres", "smlouv", "pakt", "treaty", "truce"]
	for token in treaty_tokens:
		if body.findn(token) != -1:
			return "treaties"

	var gift_tokens = ["dar", "gift", "usd", "finance", "financni"]
	for token in gift_tokens:
		if body.findn(token) != -1:
			return "gifts"

	var relation_tokens = ["vztah", "relations"]
	for token in relation_tokens:
		if body.findn(token) != -1:
			return "relations"

	if c == "diplomacy":
		return "negotiations"
	return "other"

func _priorita_kategorie_logu(category: String, title: String, text: String) -> int:
	# Higher number = higher importance, kept longer during trimming.
	match _normalizuj_kategorii_logu_pro_prioritu(category, title, text):
		"war":
			return 7
		"alliance":
			return 6
		"treaties":
			return 5
		"negotiations":
			return 4
		"gifts":
			return 3
		"other":
			return 2
		"relations":
			return 1
		_:
			return 2

func _odstran_expirovane_historicke_smlouvy(log_arr: Array) -> void:
	if log_arr.is_empty():
		return
	for i in range(log_arr.size() - 1, -1, -1):
		var item = log_arr[i]
		if not (item is Dictionary):
			continue
		var entry = item as Dictionary
		var normalized = _normalizuj_kategorii_logu_pro_prioritu(
			str(entry.get("category", "")),
			str(entry.get("title", "")),
			str(entry.get("text", ""))
		)
		if normalized != "treaties":
			continue
		var turn = int(entry.get("turn", aktualni_kolo))
		if (aktualni_kolo - turn) >= NON_AGGRESSION_DURATION_TURNS:
			log_arr.remove_at(i)

func _udrzba_vsech_logu() -> void:
	if _defer_log_maintenance:
		_log_maintenance_dirty = true
		return
	for key in log_zprav_hracu.keys():
		_trim_log_pole(log_zprav_hracu[key] as Array)
	_trim_log_pole(log_globalnich_zprav)
	_log_maintenance_dirty = false

func _najdi_index_zpravy_k_odstraneni(log_arr: Array) -> int:
	if log_arr.is_empty():
		return -1

	var chosen_idx := -1
	var chosen_priority := 999999
	var chosen_turn := 999999999

	for i in range(log_arr.size()):
		var item = log_arr[i]
		if not (item is Dictionary):
			if chosen_idx == -1:
				chosen_idx = i
			continue
		var entry = item as Dictionary
		var prio = _priorita_kategorie_logu(
			str(entry.get("category", "")),
			str(entry.get("title", "")),
			str(entry.get("text", ""))
		)
		var turn = int(entry.get("turn", -1))
		if chosen_idx == -1 or prio < chosen_priority or (prio == chosen_priority and (turn < chosen_turn or (turn == chosen_turn and i < chosen_idx))):
			chosen_idx = i
			chosen_priority = prio
			chosen_turn = turn

	return chosen_idx

func _trim_log_pole(log_arr: Array, max_items: int = MAX_LOG_ZPRAV) -> void:
	if _defer_log_maintenance:
		_log_maintenance_dirty = true
		return
	_odstran_expirovane_historicke_smlouvy(log_arr)
	while log_arr.size() > max_items:
		var idx = _najdi_index_zpravy_k_odstraneni(log_arr)
		if idx < 0 or idx >= log_arr.size():
			log_arr.remove_at(0)
		else:
			log_arr.remove_at(idx)

func _set_defer_log_maintenance(enabled: bool) -> void:
	if _defer_log_maintenance == enabled:
		return
	_defer_log_maintenance = enabled
	if not enabled and _log_maintenance_dirty:
		_udrzba_vsech_logu()

func _zaloguj_zpravu_hraci(tag: String, titulek: String, text: String, kategorie: String = "general") -> void:
	var cisty = _normalizuj_tag(tag)
	if cisty == "" or titulek.strip_edges() == "" or text.strip_edges() == "":
		return
	if not log_zprav_hracu.has(cisty):
		log_zprav_hracu[cisty] = []

	# Each line is stored as a separate event so indexing in the player's feed
	# matches individual diplomatic/relation changes.
	var lines = text.split("\n", false)
	if lines.is_empty():
		lines = [text]

	for raw_line in lines:
		var line = str(raw_line).strip_edges()
		if line == "":
			continue
		var entry = {
			"turn": aktualni_kolo,
			"title": titulek,
			"text": line,
			"category": kategorie
		}
		(log_zprav_hracu[cisty] as Array).append(entry)

	_trim_log_pole(log_zprav_hracu[cisty] as Array)

func _zaloguj_globalni_zpravu(titulek: String, text: String, kategorie: String = "global") -> void:
	if titulek.strip_edges() == "" or text.strip_edges() == "":
		return
	log_globalnich_zprav.append({
		"turn": aktualni_kolo,
		"title": titulek,
		"text": text,
		"category": kategorie
	})
	_trim_log_pole(log_globalnich_zprav)

func ziskej_zpravy_hrace(tag: String, limit: int = 120) -> Array:
	_udrzba_vsech_logu()
	var cisty = _normalizuj_tag(tag)
	if cisty == "" or not log_zprav_hracu.has(cisty):
		return []
	var src = (log_zprav_hracu[cisty] as Array)
	if src.is_empty():
		return []
	var cnt = clampi(limit, 1, MAX_LOG_ZPRAV)
	var from_idx = max(0, src.size() - cnt)
	return src.slice(from_idx, src.size())

func ziskej_globalni_zpravy(limit: int = 160) -> Array:
	_udrzba_vsech_logu()
	if log_globalnich_zprav.is_empty():
		return []
	var cnt = clampi(limit, 1, MAX_LOG_ZPRAV)
	var from_idx = max(0, log_globalnich_zprav.size() - cnt)
	return log_globalnich_zprav.slice(from_idx, log_globalnich_zprav.size())

func ziskej_pocet_zprav_hrace(tag: String) -> int:
	_udrzba_vsech_logu()
	var cisty = _normalizuj_tag(tag)
	if cisty == "" or not log_zprav_hracu.has(cisty):
		return 0
	return (log_zprav_hracu[cisty] as Array).size()

func ziskej_pocet_globalnich_zprav() -> int:
	_udrzba_vsech_logu()
	return log_globalnich_zprav.size()

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

func _pridej_popup_zucastnenym_hracum(tag_a: String, tag_b: String, titulek: String, text: String) -> void:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var pridane: Dictionary = {}
	for t in [a, b]:
		if t == "" or pridane.has(t):
			continue
		if je_lidsky_stat(t):
			_pridej_popup_hraci(t, titulek, text)
			pridane[t] = true

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
	fronta.clear()
	if kopie_fronty.size() > 1:
		var bloky: Array = []
		for item_any in kopie_fronty:
			var item = item_any as Dictionary
			var t = str(item.get("title", "Report")).strip_edges()
			var msg = str(item.get("text", "")).strip_edges()
			if msg == "":
				continue
			bloky.append("[%s]\n%s" % [t if t != "" else "Report", msg])
		if not bloky.is_empty():
			await map_loader._ukaz_bitevni_popup("Reports", "\n\n".join(bloky))
		return

	for item in kopie_fronty:
		var t = str(item.get("title", "Report"))
		var msg = str(item.get("text", ""))
		if msg.strip_edges() == "":
			continue
		await map_loader._ukaz_bitevni_popup(t, msg)

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

func _synchronizuj_jmeno_a_ideologii_hrace() -> void:
	hrac_jmeno = ""
	hrac_ideologie = ""
	if map_data.is_empty():
		return
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			hrac_jmeno = str(d.get("country_name", hrac_stat))
			hrac_ideologie = str(d.get("ideology", ""))
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
	var dalsi_index = (aktivni_hrac_index + 1) % lokalni_hraci_staty.size()
	_prepni_na_hrace(dalsi_index)

func _je_posledni_hrac_v_poradi() -> bool:
	return lokalni_hraci_staty.size() <= 1 or aktivni_hrac_index >= (lokalni_hraci_staty.size() - 1)

func odeber_lidsky_stat(tag: String) -> void:
	var cisty = _normalizuj_tag(tag)
	if cisty == "":
		return

	var idx = lokalni_hraci_staty.find(cisty)
	if idx == -1:
		return

	lokalni_hraci_staty.remove_at(idx)
	hrac_kasy.erase(cisty)
	hrac_prijmy.erase(cisty)
	hrac_kasa_inicializovana.erase(cisty)
	cekajici_popupy_hracu.erase(cisty)

	if lokalni_hraci_staty.is_empty():
		return

	if idx < aktivni_hrac_index:
		aktivni_hrac_index -= 1
	if aktivni_hrac_index >= lokalni_hraci_staty.size():
		aktivni_hrac_index = 0
	_prepni_na_hrace(aktivni_hrac_index)

func _ziskej_data_mapy_pro_ulozeni() -> Dictionary:
	var map_loader = _get_map_loader()
	if map_loader and "provinces" in map_loader:
		return (map_loader.provinces as Dictionary)
	return map_data

func _normalizuj_nazev_save(slot_name: String) -> String:
	var clean_name = slot_name.strip_edges()
	if clean_name == "":
		clean_name = "save_%s" % Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")

	for bad in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		clean_name = clean_name.replace(str(bad), "_")

	clean_name = clean_name.replace("\n", "_").replace("\r", "_").replace("\t", "_")
	clean_name = clean_name.strip_edges().replace(" ", "_")
	if clean_name == "":
		clean_name = "save"
	return clean_name

func _cesta_slotu_save(slot_name: String) -> String:
	return "%s/%s%s" % [SAVE_SLOTS_DIR, _normalizuj_nazev_save(slot_name), SAVE_SLOT_EXT]

func _zajisti_slozku_save() -> void:
	var root_dir = DirAccess.open("user://")
	if root_dir and not root_dir.dir_exists("saves"):
		root_dir.make_dir_recursive("saves")

func _vytvor_save_state() -> Dictionary:
	var map_snapshot = _ziskej_data_mapy_pro_ulozeni().duplicate(true)
	if map_snapshot.is_empty():
		return {}

	map_data = map_snapshot
	return {
		"hrac_stat": hrac_stat,
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
		"log_zprav_hracu": log_zprav_hracu.duplicate(true),
		"log_globalnich_zprav": log_globalnich_zprav.duplicate(true),
		"vyzkum_statu": vyzkum_statu.duplicate(true),
		"armadni_lab_statu": armadni_lab_statu.duplicate(true),
		"valky": valky.duplicate(true),
		"cekajici_kapitulace": cekajici_kapitulace.duplicate(true),
		"cekajici_mirove_nabidky": cekajici_mirove_nabidky.duplicate(true),
		"cekajici_mirove_konference": cekajici_mirove_konference.duplicate(true),
		"mirove_konference_seq": mirove_konference_seq,
		"vazalske_vztahy": vazalske_vztahy.duplicate(true),
		"vazalske_odvody": vazalske_odvody.duplicate(true),
		"vazalske_odvody_posledni_zmena_kolo": vazalske_odvody_posledni_zmena_kolo.duplicate(true),
		"valecne_reparace": valecne_reparace.duplicate(true),
		"aliance_statu": aliance_statu.duplicate(true),
		"aliance_skupiny": aliance_skupiny.duplicate(true),
		"aliance_skupiny_seq": _aliance_skupiny_seq,
		"neagresivni_smlouvy": neagresivni_smlouvy.duplicate(true),
		"vojensky_pristup": vojensky_pristup.duplicate(true),
		"povalecne_cooldowny": povalecne_cooldowny.duplicate(true),
		"cekajici_diplomaticke_zadosti": cekajici_diplomaticke_zadosti.duplicate(true),
		"cekajici_aliancni_zadosti": cekajici_aliancni_zadosti.duplicate(true),
		"presun_hlavniho_mesta_posledni_kolo": _presun_hlavniho_mesta_posledni_kolo.duplicate(true),
		"vztah_akce_posledni_kolo": _vztah_akce_posledni_kolo.duplicate(true),
		"vztahy_statu": _vztahy_statu.duplicate(true),
		"vztahy_nactene": _vztahy_nactene,
		"hrac_kasa_inicializovana_single": _hrac_kasa_inicializovana
	}

func _uloz_state_do_cesty(path: String, state: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(state, true)
	return true

func _nacti_state_z_cesty(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var raw = file.get_var(true)
	if not (raw is Dictionary):
		return {}

	return raw as Dictionary

func _aplikuj_save_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	hrac_stat = str(state.get("hrac_stat", hrac_stat)).strip_edges().to_upper()
	hrac_jmeno = str(state.get("hrac_jmeno", ""))
	hrac_ideologie = str(state.get("hrac_ideologie", ""))
	statni_kasa = float(state.get("statni_kasa", statni_kasa))
	celkovy_prijem = float(state.get("celkovy_prijem", celkovy_prijem))
	aktualni_kolo = int(state.get("aktualni_kolo", aktualni_kolo))
	map_data = (state.get("map_data", {}) as Dictionary).duplicate(true)
	provincie_cooldowny = (state.get("provincie_cooldowny", {}) as Dictionary).duplicate(true)
	ai_kasy = (state.get("ai_kasy", {}) as Dictionary).duplicate(true)
	_ai_profily = (state.get("ai_profily", {}) as Dictionary).duplicate(true)
	_ai_randomized_ideologies_applied = bool(state.get("ai_randomized_ideologies_applied", false))
	_global_ai_aggression_level = float(state.get("global_ai_aggression_level", 0.5))
	_ai_goal_cache.clear()
	lokalni_hraci_staty = (state.get("lokalni_hraci_staty", []) as Array).duplicate(true)
	aktivni_hrac_index = int(state.get("aktivni_hrac_index", 0))
	hrac_kasy = (state.get("hrac_kasy", {}) as Dictionary).duplicate(true)
	hrac_prijmy = (state.get("hrac_prijmy", {}) as Dictionary).duplicate(true)
	hrac_kasa_inicializovana = (state.get("hrac_kasa_inicializovana", {}) as Dictionary).duplicate(true)
	log_zprav_hracu = (state.get("log_zprav_hracu", {}) as Dictionary).duplicate(true)
	log_globalnich_zprav = (state.get("log_globalnich_zprav", []) as Array).duplicate(true)
	vyzkum_statu = (state.get("vyzkum_statu", {}) as Dictionary).duplicate(true)
	armadni_lab_statu = (state.get("armadni_lab_statu", {}) as Dictionary).duplicate(true)
	valky = (state.get("valky", {}) as Dictionary).duplicate(true)
	cekajici_kapitulace = (state.get("cekajici_kapitulace", []) as Array).duplicate(true)
	cekajici_mirove_nabidky = (state.get("cekajici_mirove_nabidky", []) as Array).duplicate(true)
	cekajici_mirove_konference = (state.get("cekajici_mirove_konference", {}) as Dictionary).duplicate(true)
	mirove_konference_seq = int(state.get("mirove_konference_seq", 0))
	vazalske_vztahy = (state.get("vazalske_vztahy", {}) as Dictionary).duplicate(true)
	vazalske_odvody = (state.get("vazalske_odvody", {}) as Dictionary).duplicate(true)
	vazalske_odvody_posledni_zmena_kolo = (state.get("vazalske_odvody_posledni_zmena_kolo", {}) as Dictionary).duplicate(true)
	valecne_reparace = (state.get("valecne_reparace", []) as Array).duplicate(true)
	aliance_statu = (state.get("aliance_statu", {}) as Dictionary).duplicate(true)
	aliance_skupiny = (state.get("aliance_skupiny", {}) as Dictionary).duplicate(true)
	_aliance_skupiny_seq = int(state.get("aliance_skupiny_seq", 0))
	neagresivni_smlouvy = (state.get("neagresivni_smlouvy", {}) as Dictionary).duplicate(true)
	vojensky_pristup = (state.get("vojensky_pristup", {}) as Dictionary).duplicate(true)
	povalecne_cooldowny = (state.get("povalecne_cooldowny", {}) as Dictionary).duplicate(true)
	cekajici_diplomaticke_zadosti = (state.get("cekajici_diplomaticke_zadosti", {}) as Dictionary).duplicate(true)
	cekajici_aliancni_zadosti = (state.get("cekajici_aliancni_zadosti", []) as Array).duplicate(true)
	_presun_hlavniho_mesta_posledni_kolo = (state.get("presun_hlavniho_mesta_posledni_kolo", {}) as Dictionary).duplicate(true)
	_vztah_akce_posledni_kolo = (state.get("vztah_akce_posledni_kolo", {}) as Dictionary).duplicate(true)
	_vztahy_statu = (state.get("vztahy_statu", {}) as Dictionary).duplicate(true)
	_vztahy_nactene = bool(state.get("vztahy_nactene", true))
	_hrac_kasa_inicializovana = bool(state.get("hrac_kasa_inicializovana_single", _hrac_kasa_inicializovana))

	if not lokalni_hraci_staty.is_empty():
		if not lokalni_hraci_staty.has(hrac_stat):
			hrac_stat = str(lokalni_hraci_staty[0])
		aktivni_hrac_index = clampi(aktivni_hrac_index, 0, lokalni_hraci_staty.size() - 1)

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
	kolo_zmeneno.emit()
	return true

func reset_pro_novou_hru() -> void:
	hrac_stat = "ALB"
	hrac_jmeno = ""
	hrac_ideologie = ""
	statni_kasa = 0.0
	celkovy_prijem = 0.0
	aktualni_kolo = 1

	map_data.clear()
	provincie_cooldowny.clear()
	ai_kasy.clear()
	_ai_profily.clear()
	_ai_randomized_ideologies_applied = false
	_global_ai_aggression_level = 0.5
	_ai_goal_cache.clear()
	_hrac_kasa_inicializovana = false
	lokalni_hraci_staty.clear()
	aktivni_hrac_index = 0
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	log_zprav_hracu.clear()
	log_globalnich_zprav.clear()
	vyzkum_statu.clear()
	armadni_lab_statu.clear()

	valky.clear()
	cekajici_kapitulace.clear()
	cekajici_mirove_nabidky.clear()
	cekajici_mirove_konference.clear()
	mirove_konference_seq = 0
	vazalske_vztahy.clear()
	vazalske_odvody.clear()
	vazalske_odvody_posledni_zmena_kolo.clear()
	valecne_reparace.clear()
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
	_vztahy_statu.clear()
	_vztahy_nactene = false
	_vztah_akce_posledni_kolo.clear()
	_turn_cache_valid = false
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()

func ziskej_save_sloty() -> Array:
	_zajisti_slozku_save()
	var slots: Array = []

	var dir = DirAccess.open(SAVE_SLOTS_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(SAVE_SLOT_EXT):
			continue

		var slot_name = file_name.substr(0, file_name.length() - SAVE_SLOT_EXT.length())
		var slot_path = "%s/%s" % [SAVE_SLOTS_DIR, file_name]
		slots.append({
			"name": slot_name,
			"path": slot_path,
			"modified": int(FileAccess.get_modified_time(slot_path))
		})
	dir.list_dir_end()

	slots.sort_custom(func(a, b):
		return int((a as Dictionary).get("modified", 0)) > int((b as Dictionary).get("modified", 0))
	)
	return slots

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
	if FileAccess.file_exists(SAVEGAME_STATE_PATH):
		return true
	return not ziskej_save_sloty().is_empty()

func uloz_hru_do_slotu(slot_name: String) -> bool:
	_zajisti_slozku_save()
	if ma_save_pro_kolo(aktualni_kolo):
		return false
	var state = _vytvor_save_state()
	if state.is_empty():
		return false

	var slot_path = _cesta_slotu_save(slot_name)
	var ok_slot = _uloz_state_do_cesty(slot_path, state)
	# Keep legacy quicksave path for backward compatibility with existing flows.
	_uloz_state_do_cesty(SAVEGAME_STATE_PATH, state)
	return ok_slot

func nacti_hru_ze_slotu(slot_name: String) -> bool:
	var slot_path = _cesta_slotu_save(slot_name)
	var state = _nacti_state_z_cesty(slot_path)
	return _aplikuj_save_state(state)

func smaz_save_slot(slot_name: String) -> bool:
	var clean = _normalizuj_nazev_save(slot_name)
	if clean == "":
		return false

	var slot_path = _cesta_slotu_save(clean)
	if not FileAccess.file_exists(slot_path):
		return false

	var abs_path = ProjectSettings.globalize_path(slot_path)
	return DirAccess.remove_absolute(abs_path) == OK

func smaz_legacy_save() -> bool:
	if not FileAccess.file_exists(SAVEGAME_STATE_PATH):
		return false
	var abs_path = ProjectSettings.globalize_path(SAVEGAME_STATE_PATH)
	return DirAccess.remove_absolute(abs_path) == OK

func nacti_posledni_hru() -> bool:
	var slots = ziskej_save_sloty()
	if not slots.is_empty():
		var newest = slots[0] as Dictionary
		var slot_name = str(newest.get("name", ""))
		if slot_name != "" and nacti_hru_ze_slotu(slot_name):
			return true
	return nacti_hru()

func uloz_hru() -> bool:
	return uloz_hru_do_slotu("quicksave")

func nacti_hru() -> bool:
	var legacy_state = _nacti_state_z_cesty(SAVEGAME_STATE_PATH)
	if _aplikuj_save_state(legacy_state):
		return true
	# Fallback to slot-based quicksave if legacy file is missing.
	return nacti_hru_ze_slotu("quicksave")

# Safely get the map node
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

func _normalizuj_tag(tag: String) -> String:
	return tag.strip_edges().to_upper()

func _clamp_arm_lab_quality(level: int) -> int:
	return clampi(level, 0, 8)

func _zajisti_armadni_lab_statu(tag: String) -> Dictionary:
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

func _arm_lab_odemcene_dict(lab: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var arr = lab.get("unlocked_cells", []) as Array
	for c_any in arr:
		var key = str(c_any)
		var parts = key.split("_")
		if parts.size() != 2:
			continue
		var x = int(parts[0])
		var y = int(parts[1])
		if x < 0 or y < 0 or x >= ARM_LAB_GRID_MAX_W or y >= ARM_LAB_GRID_MAX_H:
			continue
		out["%d_%d" % [x, y]] = true
	return out

func _arm_lab_odemcene_array(unlocked: Dictionary) -> Array:
	var arr: Array = []
	for key in unlocked.keys():
		arr.append(str(key))
	arr.sort()
	return arr

func _arm_lab_obsah_mrizky_odemykani(unlocked: Dictionary) -> Dictionary:
	var max_x = ARM_LAB_GRID_W - 1
	var max_y = ARM_LAB_GRID_H - 1
	for key_any in unlocked.keys():
		var key = str(key_any)
		var p = key.split("_")
		if p.size() != 2:
			continue
		max_x = max(max_x, int(p[0]))
		max_y = max(max_y, int(p[1]))
	return {
		"w": clampi(max_x + 1, ARM_LAB_GRID_W, ARM_LAB_GRID_MAX_W),
		"h": clampi(max_y + 1, ARM_LAB_GRID_H, ARM_LAB_GRID_MAX_H)
	}

func _arm_lab_je_kandidat_expanze(unlocked: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= ARM_LAB_GRID_MAX_W or y >= ARM_LAB_GRID_MAX_H:
		return false
	var key = "%d_%d" % [x, y]
	if unlocked.has(key):
		return false

	var row_right := -1
	for xx in range(ARM_LAB_GRID_MAX_W):
		if unlocked.has("%d_%d" % [xx, y]):
			row_right = xx
	if row_right >= 0 and x == row_right + 1:
		return true

	var col_bottom := -1
	for yy in range(ARM_LAB_GRID_MAX_H):
		if unlocked.has("%d_%d" % [x, yy]):
			col_bottom = yy
	if col_bottom >= 0 and y == col_bottom + 1:
		return true

	return false

func _arm_lab_tier_roll(quality_level: int) -> int:
	var q = _clamp_arm_lab_quality(quality_level)
	var roll = randf()
	var tier3_chance = clamp(0.08 + float(q) * 0.04, 0.08, 0.45)
	var tier2_chance = clamp(0.26 + float(q) * 0.05, 0.26, 0.60)
	if roll < tier3_chance:
		return 3
	if roll < (tier3_chance + tier2_chance):
		return 2
	return 1

func _arm_lab_level_roll(quality_level: int) -> int:
	var q = _clamp_arm_lab_quality(quality_level)
	var roll = randf()
	var lvl4_chance = clamp(0.02 + float(q) * 0.02, 0.02, 0.18)
	var lvl3_chance = clamp(0.08 + float(q) * 0.05, 0.08, 0.40)
	var lvl2_chance = clamp(0.30 + float(q) * 0.07, 0.30, 0.75)
	if roll < lvl4_chance:
		return 4
	if roll < (lvl4_chance + lvl3_chance):
		return 3
	if roll < (lvl4_chance + lvl3_chance + lvl2_chance):
		return 2
	return 1

func _arm_lab_vyber_sablonu_dle_tieru(tier: int) -> Dictionary:
	var pool: Array = []
	for tpl_any in ARM_LAB_ITEM_POOL:
		var tpl = tpl_any as Dictionary
		if int(tpl.get("tier", 1)) == tier:
			pool.append(tpl)
	if pool.is_empty():
		for tpl_any in ARM_LAB_ITEM_POOL:
			pool.append(tpl_any)
	if pool.is_empty():
		return {}
	return (pool[randi_range(0, pool.size() - 1)] as Dictionary)

func _arm_lab_vytvor_random_offer(quality_level: int) -> Dictionary:
	var tier = _arm_lab_tier_roll(quality_level)
	var level = max(_arm_lab_level_roll(quality_level), tier)
	var tpl = _arm_lab_vyber_sablonu_dle_tieru(tier)
	if tpl.is_empty():
		return {}

	var cost_min = float(tpl.get("cost_min", 10.0))
	var cost_max = float(tpl.get("cost_max", cost_min))
	var flat_min = int(tpl.get("flat_min", 40))
	var flat_max = int(tpl.get("flat_max", flat_min))
	var pct_min = float(tpl.get("pct_min", 0.001))
	var pct_max = float(tpl.get("pct_max", pct_min))

	var cost = randf_range(cost_min, cost_max)
	var power_flat = randi_range(flat_min, flat_max)
	var power_pct = randf_range(pct_min, pct_max)
	var lvl_mult_power = 1.0 + float(max(0, level - 1)) * ARM_LAB_LEVEL_POWER_STEP
	var lvl_mult_cost = 1.0 + float(max(0, level - 1)) * ARM_LAB_LEVEL_COST_STEP
	cost *= lvl_mult_cost
	power_flat = int(round(float(power_flat) * lvl_mult_power))
	power_pct *= lvl_mult_power

	return {
		"offer_uid": str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"id": str(tpl.get("id", "item")),
		"name": str(tpl.get("name", "Item")),
		"level": level,
		"tier": tier,
		"w": int(tpl.get("w", 1)),
		"h": int(tpl.get("h", 1)),
		"cost": snapped(max(1.0, cost), 0.01),
		"power_flat": int(max(0, power_flat)),
		"power_pct": max(0.0, power_pct)
	}

func _arm_lab_obsazena_mrizka(grid_items: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for item_any in grid_items:
		var item = item_any as Dictionary
		var x = int(item.get("x", 0))
		var y = int(item.get("y", 0))
		var w = int(item.get("w", 1))
		var h = int(item.get("h", 1))
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				occupied["%d_%d" % [xx, yy]] = true
	return occupied

func _arm_lab_najdi_prvni_volne_misto(grid_items: Array, w: int, h: int, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> Vector2i:
	var iw = max(1, w)
	var ih = max(1, h)
	if iw > grid_w or ih > grid_h:
		return Vector2i(-1, -1)

	var occupied = _arm_lab_obsazena_mrizka(grid_items)
	for y in range(0, grid_h - ih + 1):
		for x in range(0, grid_w - iw + 1):
			var fits := true
			for yy in range(y, y + ih):
				for xx in range(x, x + iw):
					if not unlocked.is_empty() and not unlocked.has("%d_%d" % [xx, yy]):
						fits = false
						break
					if occupied.has("%d_%d" % [xx, yy]):
						fits = false
						break
				if not fits:
					break
			if fits:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _arm_lab_muze_umistit_na(grid_items: Array, w: int, h: int, x: int, y: int, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> bool:
	var iw = max(1, w)
	var ih = max(1, h)
	if iw > grid_w or ih > grid_h:
		return false
	if x < 0 or y < 0:
		return false
	if (x + iw) > grid_w or (y + ih) > grid_h:
		return false

	var occupied = _arm_lab_obsazena_mrizka(grid_items)
	for yy in range(y, y + ih):
		for xx in range(x, x + iw):
			if not unlocked.is_empty() and not unlocked.has("%d_%d" % [xx, yy]):
				return false
			if occupied.has("%d_%d" % [xx, yy]):
				return false
	return true

func _arm_lab_muze_umistit_na_ignorovat(grid_items: Array, w: int, h: int, x: int, y: int, ignore_uid: String, grid_w: int, grid_h: int, unlocked: Dictionary = {}) -> bool:
	var iw = max(1, w)
	var ih = max(1, h)
	if iw > grid_w or ih > grid_h:
		return false
	if x < 0 or y < 0:
		return false
	if (x + iw) > grid_w or (y + ih) > grid_h:
		return false

	var occupied: Dictionary = {}
	for item_any in grid_items:
		var item = item_any as Dictionary
		if str(item.get("offer_uid", "")) == ignore_uid:
			continue
		var ix = int(item.get("x", 0))
		var iy = int(item.get("y", 0))
		var iw_item = int(item.get("w", 1))
		var ih_item = int(item.get("h", 1))
		for yy in range(iy, iy + ih_item):
			for xx in range(ix, ix + iw_item):
				occupied["%d_%d" % [xx, yy]] = true

	for yy in range(y, y + ih):
		for xx in range(x, x + iw):
			if not unlocked.is_empty() and not unlocked.has("%d_%d" % [xx, yy]):
				return false
			if occupied.has("%d_%d" % [xx, yy]):
				return false
	return true

func _arm_lab_zajisti_nabidky(state_tag: String) -> void:
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

func _arm_lab_spocitej_bonus(grid_items: Array) -> Dictionary:
	var total_flat := 0
	var total_pct := 0.0
	for item_any in grid_items:
		var item = item_any as Dictionary
		total_flat += int(item.get("power_flat", 0))
		total_pct += float(item.get("power_pct", 0.0))
	return {
		"flat": total_flat,
		"pct": total_pct
	}

func ziskej_armadni_lab_statu(state_tag: String) -> Dictionary:
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
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"item": item,
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

func kup_armadni_nabidku(state_tag: String, offer_index: int) -> Dictionary:
	return kup_armadni_nabidku_na_pozici(state_tag, offer_index, -1, -1)

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
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()
	return {
		"ok": true,
		"target_uid": target_uid,
		"new_level": int(dst.get("level", 1)),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

func presun_armadni_item(state_tag: String, item_uid: String, target_x: int, target_y: int) -> Dictionary:
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

func rozsirit_armadni_mrizku(state_tag: String) -> Dictionary:
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

func koupit_armadni_bunku(state_tag: String, x: int, y: int) -> Dictionary:
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
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
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

func prodej_armadni_item(state_tag: String, item_uid: String) -> Dictionary:
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
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"item_uid": item_uid,
		"sold_for": sell_value,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

func sloucit_armadni_itemy(state_tag: String, source_uid: String, target_uid: String) -> Dictionary:
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

func reroll_armadni_nabidky(state_tag: String) -> Dictionary:
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
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {"ok": true, "cost": cost, "treasury_after": _ziskej_kasu_statu(cisty)}

func vylepsi_kvalitu_dropu_armady(state_tag: String) -> Dictionary:
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

	# New quality applies immediately with a free offer refresh.
	_arm_lab_zajisti_nabidky(cisty)

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	return {
		"ok": true,
		"new_quality_level": int(lab.get("quality_level", 0)),
		"cost": cost,
		"treasury_after": _ziskej_kasu_statu(cisty)
	}

func _zajisti_vyzkum_statu(tag: String) -> Array:
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

func je_vyzkum_hotovy(state_tag: String, project_id: String) -> bool:
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or project_id.strip_edges() == "":
		return false
	var completed = _zajisti_vyzkum_statu(cisty)
	return completed.has(project_id)

func ziskej_vyzkum_projekty() -> Array:
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

func ziskej_vyzkum_statu(state_tag: String) -> Dictionary:
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "" or cisty == "SEA":
		return {
			"ok": false,
			"reason": "Invalid state.",
			"projects": [],
			"completed": [],
			"treasury": 0.0
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

func proved_vyzkum_projektu(state_tag: String, project_id: String) -> Dictionary:
	var check = muze_vyzkoumat_projekt(state_tag, project_id)
	if not bool(check.get("ok", false)):
		return check

	var cisty = _normalizuj_tag(state_tag)
	var pid = project_id.strip_edges()
	var project = VYZKUM_PROJEKTY[pid] as Dictionary
	var cost = float(project.get("cost", 0.0))

	var current_treasury = _ziskej_kasu_statu(cisty)
	_nastav_kasu_statu(cisty, current_treasury - cost)

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

func _ziskej_modifikatory_vyzkumu_statu(state_tag: String) -> Dictionary:
	var out := {
		"recruit_cost_mult": 1.0,
		"upkeep_mult": 1.0,
		"income_rate_mult": 1.0,
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0
	}

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

func _normalizuj_ideologii(ideology: String) -> String:
	var raw = ideology.strip_edges().to_lower()
	match raw:
		"democracy", "democratic":
			return "demokracie"
		"autocracy", "autocratic", "dictatorship":
			return "autokracie"
		"communism", "communist", "socialism":
			return "komunismus"
		"fascism", "fascist":
			return "fasismus"
		"nazism", "nazismus", "nazi", "national_socialism":
			return "nacismus"
		"kingdom", "monarchy":
			return "kralovstvi"
		"royal":
			return "kralovstvi"
		"nacismum":
			return "nacismus"
		"kralostvi":
			return "kralovstvi"
		_:
			return raw

func _klic_ideologickeho_paru(ideology_a: String, ideology_b: String) -> String:
	var a = _normalizuj_ideologii(ideology_a)
	var b = _normalizuj_ideologii(ideology_b)
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _ziskej_ideologii_statu(tag: String) -> String:
	var wanted = _normalizuj_tag(tag)
	if wanted == "" or wanted == "SEA":
		return ""
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == wanted:
			return _normalizuj_ideologii(str(d.get("ideology", "")))
	return ""

func _ziskej_ekonomicke_modifikatory_ideologie(ideology: String) -> Dictionary:
	var key = _normalizuj_ideologii(ideology)
	var base = {
		"recruit_cost_mult": 1.0,
		"upkeep_mult": 1.0,
		"income_rate_mult": 1.0,
		"gdp_growth_mult": 1.0,
		"population_growth_mult": 1.0,
		"recruit_regen_mult": 1.0
	}
	if IDEOLOGY_ECONOMIC_MODIFIERS.has(key):
		var src = IDEOLOGY_ECONOMIC_MODIFIERS[key] as Dictionary
		for k in src.keys():
			base[k] = src[k]
	return base

func ziskej_ekonomicke_modifikatory_statu(state_tag: String) -> Dictionary:
	var base = _ziskej_ekonomicke_modifikatory_ideologie(_ziskej_ideologii_statu(state_tag))
	var research = _ziskej_modifikatory_vyzkumu_statu(state_tag)
	for k in research.keys():
		if not base.has(k):
			continue
		base[k] = float(base[k]) * float(research[k])
	return base

func ziskej_cenu_za_vojaka(state_tag: String) -> float:
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_RECRUIT_COST_PER_SOLDIER * max(0.01, float(mods.get("recruit_cost_mult", 1.0)))

func ziskej_udrzbu_za_vojaka(state_tag: String) -> float:
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_UPKEEP_PER_SOLDIER * max(0.01, float(mods.get("upkeep_mult", 1.0)))

func ziskej_prijmovou_sazbu_hdp(state_tag: String) -> float:
	var mods = ziskej_ekonomicke_modifikatory_statu(state_tag)
	return BASE_INCOME_RATE * max(0.01, float(mods.get("income_rate_mult", 1.0)))

func ziskej_ekonomicke_modifikatory_ideologie(ideology: String) -> Dictionary:
	return _ziskej_ekonomicke_modifikatory_ideologie(ideology)

func ziskej_ideologicky_ekonomicky_profil(ideology: String) -> Dictionary:
	var mods = _ziskej_ekonomicke_modifikatory_ideologie(ideology)
	var recruit_cost_mult = max(0.01, float(mods.get("recruit_cost_mult", 1.0)))
	var upkeep_mult = max(0.01, float(mods.get("upkeep_mult", 1.0)))
	var income_rate_mult = max(0.01, float(mods.get("income_rate_mult", 1.0)))
	var gdp_growth_mult = max(0.01, float(mods.get("gdp_growth_mult", 1.0)))
	var pop_growth_mult = max(0.01, float(mods.get("population_growth_mult", 1.0)))
	var recruit_regen_mult = max(0.01, float(mods.get("recruit_regen_mult", 1.0)))

	return {
		"recruit_cost_per_soldier": BASE_RECRUIT_COST_PER_SOLDIER * recruit_cost_mult,
		"upkeep_per_soldier": BASE_UPKEEP_PER_SOLDIER * upkeep_mult,
		"income_rate_from_gdp": BASE_INCOME_RATE * income_rate_mult,
		"gdp_growth_per_turn": BASE_GDP_GROWTH_PER_TURN * gdp_growth_mult,
		"population_growth_ratio": BASE_POP_GROWTH_RATIO * pop_growth_mult,
		"recruit_regen_ratio_core": 0.10 * recruit_regen_mult,
		"recruit_regen_ratio_occupied": 0.025 * recruit_regen_mult,
		"mods": {
			"recruit_cost_mult": recruit_cost_mult,
			"upkeep_mult": upkeep_mult,
			"income_rate_mult": income_rate_mult,
			"gdp_growth_mult": gdp_growth_mult,
			"population_growth_mult": pop_growth_mult,
			"recruit_regen_mult": recruit_regen_mult
		}
	}

func _jsou_ideologie_podobne(ideology_a: String, ideology_b: String) -> bool:
	var a = _normalizuj_ideologii(ideology_a)
	var b = _normalizuj_ideologii(ideology_b)
	if a == "" or b == "":
		return false
	if a == b:
		return true

	var similar_pairs := {
		"autokracie|fasismus": true,
		"autokracie|kralovstvi": true,
		"autokracie|nacismus": true,
		"demokracie|kralovstvi": true,
		"fasismus|nacismus": true
	}
	return similar_pairs.has(_klic_ideologickeho_paru(a, b))

func _jsou_ideologie_uplne_odlisne(ideology_a: String, ideology_b: String) -> bool:
	var a = _normalizuj_ideologii(ideology_a)
	var b = _normalizuj_ideologii(ideology_b)
	if a == "" or b == "":
		return false

	var opposite_pairs := {
		"autokracie|komunismus": true,
		"demokracie|fasismus": true,
		"demokracie|komunismus": true,
		"demokracie|nacismus": true,
		"kralovstvi|fasismus": true,
		"kralovstvi|komunismus": true,
		"kralovstvi|nacismus": true
	}
	return opposite_pairs.has(_klic_ideologickeho_paru(a, b))

func _spocitej_zmeny_vztahu_po_ideologii(state: String, target_ideology: String) -> Array:
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

func _ziskej_statove_modifikatory_ideologie(ideology: String) -> Dictionary:
	var key = _normalizuj_ideologii(ideology)
	var gdp_mult = float(IDEOLOGY_GDP_MULTIPLIERS.get(key, 1.0))
	var recruit_mult = float(IDEOLOGY_RECRUIT_MULTIPLIERS.get(key, 1.0))
	return {
		"gdp_mult": gdp_mult,
		"recruit_mult": recruit_mult
	}

func _nahled_nebo_aplikace_ideologie_statistik(state: String, old_ideology: String, new_ideology: String, apply_changes: bool) -> Dictionary:
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

func nahled_zmeny_ideologie_statu(state_tag: String, new_ideology: String) -> Dictionary:
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

func _stat_existuje(tag: String) -> bool:
	var wanted = _normalizuj_tag(tag)
	if wanted == "" or wanted == "SEA":
		return false
	for p_id in map_data:
		var owner_tag = _normalizuj_tag(str(map_data[p_id].get("owner", "")))
		if owner_tag == wanted:
			return true
	return false

func _ziskej_kasu_statu(tag: String) -> float:
	var t = _normalizuj_tag(tag)
	if t == "":
		return 0.0
	if je_lidsky_stat(t):
		if t == _normalizuj_tag(hrac_stat):
			return statni_kasa
		return float(hrac_kasy.get(t, 0.0))
	return float(ai_kasy.get(t, 0.0))

func _nastav_kasu_statu(tag: String, value: float) -> void:
	var t = _normalizuj_tag(tag)
	if t == "":
		return
	var safe_value = value
	if je_lidsky_stat(t):
		hrac_kasy[t] = safe_value
		if t == _normalizuj_tag(hrac_stat):
			statni_kasa = safe_value
	else:
		ai_kasy[t] = safe_value

func _ziskej_pozici_provincie(province_id: int) -> Vector2:
	if not map_data.has(province_id):
		return Vector2.ZERO
	var d = map_data[province_id] as Dictionary
	if d.is_empty():
		return Vector2.ZERO
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))

func _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(source_province_id: int, target_province_id: int) -> float:
	if source_province_id <= 0 or target_province_id <= 0:
		return 1.0
	if source_province_id == target_province_id:
		return 1.0
	if not map_data.has(source_province_id) or not map_data.has(target_province_id):
		return 1.0

	var source_pos = _ziskej_pozici_provincie(source_province_id)
	var target_pos = _ziskej_pozici_provincie(target_province_id)
	var distance = source_pos.distance_to(target_pos)
	if distance <= 0.0:
		return 1.0

	var distance_factor = (distance / max(1.0, CAPITAL_RELOCATION_DISTANCE_STEP)) * CAPITAL_RELOCATION_DISTANCE_RATIO_PER_STEP
	return clamp(1.0 + distance_factor, 1.0, CAPITAL_RELOCATION_DISTANCE_MULTIPLIER_MAX)

func ziskej_cenu_presunu_hlavniho_mesta(state_tag: String, target_province_id: int = -1) -> float:
	var tag = _normalizuj_tag(state_tag)
	if tag == "" or tag == "SEA":
		return 999999.0
	var hdp = _spocitej_hdp_statu(tag)
	var base_cost = max(CAPITAL_RELOCATION_BASE_COST, hdp * CAPITAL_RELOCATION_HDP_RATIO)
	if target_province_id <= 0:
		return snapped(base_cost, 0.01)

	var current_capital_id = _ziskej_hlavni_mesto_statu(tag)
	if current_capital_id <= 0:
		return snapped(base_cost, 0.01)

	var distance_multiplier = _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(current_capital_id, target_province_id)
	return snapped(base_cost * distance_multiplier, 0.01)

func _ziskej_hlavni_mesto_statu(state_tag: String) -> int:
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "" or wanted == "SEA":
		return -1

	# Prefer currently owned capital if it exists.
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != wanted:
			continue
		if bool(d.get("is_capital", false)):
			return int(p_id)

	# Fallback: occupied capital still marked by core owner.
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("core_owner", ""))) != wanted:
			continue
		if bool(d.get("is_capital", false)):
			return int(p_id)

	return -1

func _zrus_cekajici_kapitulace_pro_obrance(obrance_tag: String) -> int:
	var obr = _normalizuj_tag(obrance_tag)
	if obr == "":
		return 0
	var removed := 0
	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		if _normalizuj_tag(str(cekajici_kapitulace[i].get("obrance", ""))) == obr:
			cekajici_kapitulace.remove_at(i)
			removed += 1
	return removed

func _aktualizuj_label_hlavniho_mesta(map_loader: Node, prov_id: int, is_capital: bool, state_tag: String) -> void:
	var labels = map_loader.get_node_or_null("ProvinceLabels")
	if labels == null:
		return

	for lbl in labels.get_children():
		if int(lbl.get("province_id")) != prov_id:
			continue

		lbl.set("is_capital", is_capital)

		var d = map_data.get(prov_id, {}) as Dictionary
		var shown_name = str(d.get("province_name", "Province %d" % prov_id)).replace(" Voivodeship", "").replace(" County", "")
		if is_capital:
			var city_name = str(d.get("capital_name", "")).strip_edges()
			if city_name != "":
				shown_name = city_name

		var label_node = lbl.find_child("Label", true, false)
		if label_node:
			label_node.text = shown_name
		if "plny_nazev" in lbl:
			lbl.set("plny_nazev", shown_name)

		var flag_node = lbl.find_child("Flag", true, false)
		if flag_node:
			if is_capital:
				flag_node.show()
				if map_loader.has_method("_get_flag_texture"):
					var ideology = str(d.get("ideology", ""))
					var tex = map_loader._get_flag_texture(state_tag, ideology)
					if tex:
						flag_node.texture = tex
			else:
				flag_node.hide()

		if lbl.has_method("reset_stav"):
			lbl.reset_stav()
		break

func _aktualizuj_mapu_po_presunu_hlavniho_mesta(old_capital_id: int, new_capital_id: int, state_tag: String) -> void:
	var map_loader = _get_map_loader()
	if map_loader == null:
		return

	if "provinces" in map_loader:
		map_loader.provinces = map_data

	_aktualizuj_label_hlavniho_mesta(map_loader, old_capital_id, false, state_tag)
	_aktualizuj_label_hlavniho_mesta(map_loader, new_capital_id, true, state_tag)

	var labels_manager = map_loader.get_node_or_null("CountryLabelsManager")
	var province_labels = map_loader.get_node_or_null("ProvinceLabels")
	if labels_manager and province_labels and labels_manager.has_method("aktualizuj_labely_statu"):
		labels_manager.aktualizuj_labely_statu(map_data, province_labels)

	if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
		map_loader._aktualizuj_aktivni_mapovy_mod()
	if map_loader.has_method("_aktualizuj_indikatory_kapitulace"):
		map_loader._aktualizuj_indikatory_kapitulace()

func muze_presunout_hlavni_mesto(state_tag: String, target_province_id: int) -> Dictionary:
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return {"ok": false, "reason": "Invalid state."}

	var last_turn = int(_presun_hlavniho_mesta_posledni_kolo.get(state, -1))
	if last_turn == aktualni_kolo:
		return {"ok": false, "reason": "Capital can be moved only once per turn."}

	if not _stat_existuje(state):
		return {"ok": false, "reason": "State does not exist on the current map."}
	if not map_data.has(target_province_id):
		return {"ok": false, "reason": "Target province does not exist."}

	var target = map_data[target_province_id]
	var target_owner = _normalizuj_tag(str(target.get("owner", "")))
	if target_owner != state:
		return {"ok": false, "reason": "Capital can be moved only to your own province."}
	if _normalizuj_tag(str(target.get("core_owner", target_owner))) != state:
		return {"ok": false, "reason": "Target must be a core province of this state."}
	if target_owner == "SEA":
		return {"ok": false, "reason": "Capital cannot be moved to sea."}

	var current_capital_id = _ziskej_hlavni_mesto_statu(state)
	if current_capital_id == -1:
		return {"ok": false, "reason": "State has no available capital to move."}
	if current_capital_id == target_province_id:
		return {"ok": false, "reason": "This province is already the capital."}

	var current_name = "Province %d" % current_capital_id
	if map_data.has(current_capital_id):
		current_name = str(map_data[current_capital_id].get("province_name", current_name))
	var target_name = str(target.get("province_name", "Province %d" % target_province_id))
	var cost = ziskej_cenu_presunu_hlavniho_mesta(state, target_province_id)
	var distance_multiplier = _ziskej_vzdalenostni_nasobic_presunu_hlavniho_mesta(current_capital_id, target_province_id)
	return {
		"ok": true,
		"state": state,
		"cost": cost,
		"distance_multiplier": distance_multiplier,
		"current_capital_id": current_capital_id,
		"current_capital_name": current_name,
		"target_capital_id": target_province_id,
		"target_capital_name": target_name
	}

func ma_dostupny_cil_presunu_hlavniho_mesta(state_tag: String) -> bool:
	var state = _normalizuj_tag(state_tag)
	if state == "" or state == "SEA":
		return false
	if not _stat_existuje(state):
		return false

	for p_id in map_data.keys():
		var pid = int(p_id)
		var check = muze_presunout_hlavni_mesto(state, pid)
		if bool(check.get("ok", false)):
			return true
	return false

func presun_hlavni_mesto(state_tag: String, target_province_id: int, pay_cost: bool = true, emit_ui_signal: bool = true) -> Dictionary:
	var check = muze_presunout_hlavni_mesto(state_tag, target_province_id)
	if not bool(check.get("ok", false)):
		return check

	var state = _normalizuj_tag(str(check.get("state", state_tag)))
	var cost = float(check.get("cost", 0.0))
	if pay_cost:
		var cash_now = _ziskej_kasu_statu(state)
		if cash_now + 0.0001 < cost:
			return {"ok": false, "reason": "Insufficient funds.", "required": cost, "cash": cash_now}
		_nastav_kasu_statu(state, cash_now - cost)

	var old_capital_id = int(check.get("current_capital_id", -1))
	if map_data.has(old_capital_id):
		map_data[old_capital_id]["is_capital"] = false
	map_data[target_province_id]["is_capital"] = true
	_presun_hlavniho_mesta_posledni_kolo[state] = aktualni_kolo

	var canceled_pressure = _zrus_cekajici_kapitulace_pro_obrance(state)
	_aktualizuj_mapu_po_presunu_hlavniho_mesta(old_capital_id, target_province_id, state)
	_invalidate_turn_cache()

	var old_name = str(check.get("current_capital_name", "Province %d" % old_capital_id))
	var new_name = str(check.get("target_capital_name", "Province %d" % target_province_id))
	var log_msg = "%s moved the capital from %s to %s." % [state, old_name, new_name]
	if canceled_pressure > 0:
		log_msg += " This removed the pressure for immediate surrender."
	_zaloguj_globalni_zpravu("War", log_msg, "war")

	if emit_ui_signal:
		kolo_zmeneno.emit()

	return {
		"ok": true,
		"state": state,
		"cost": cost,
		"old_capital_id": old_capital_id,
		"new_capital_id": target_province_id,
		"old_capital_name": old_name,
		"new_capital_name": new_name,
		"canceled_surrender_pressure": canceled_pressure,
		"cash_after": _ziskej_kasu_statu(state)
	}

func daruj_penize_statu(odesilatel: String, prijemce: String, amount: float) -> Dictionary:
	var from_tag = _normalizuj_tag(odesilatel)
	var to_tag = _normalizuj_tag(prijemce)
	var castka = maxf(0.0, amount)

	if from_tag == "" or to_tag == "" or from_tag == to_tag:
		return {"ok": false, "reason": "Invalid countries for gift."}
	if from_tag == "SEA" or to_tag == "SEA":
		return {"ok": false, "reason": "Cannot send gifts to sea provinces."}
	if castka <= 0.0:
		return {"ok": false, "reason": "Gift amount must be greater than 0."}
	if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
		return {"ok": false, "reason": "One of the countries does not exist on the current map."}

	var kasa_odesilatel = _ziskej_kasu_statu(from_tag)
	if kasa_odesilatel + 0.0001 < castka:
		return {"ok": false, "reason": "Insufficient funds."}

	var kasa_prijemce = _ziskej_kasu_statu(to_tag)
	_nastav_kasu_statu(from_tag, kasa_odesilatel - castka)
	_nastav_kasu_statu(to_tag, kasa_prijemce + castka)

	var rel_delta = clamp(castka / 20.0, 1.0, 15.0)
	var new_rel = _uprav_vztah_statu_bez_cooldown(from_tag, to_tag, rel_delta)

	if je_lidsky_stat(from_tag) or je_lidsky_stat(to_tag):
		_pridej_popup_zucastnenym_hracum(
			from_tag,
			to_tag,
			"DIPLOMACY",
			"%s sent a financial gift of %.2f mil. USD to %s (relation %+0.1f)." % [from_tag, castka, to_tag, rel_delta]
		)
	_zaloguj_globalni_zpravu(
		"Gifts",
		"%s sent a financial gift of %.2f mil. USD to %s (relation %+0.1f)." % [from_tag, castka, to_tag, rel_delta],
		"gifts"
	)

	return {
		"ok": true,
		"amount": castka,
		"relation_delta": rel_delta,
		"new_relation": new_rel,
		"from_cash": _ziskej_kasu_statu(from_tag),
		"to_cash": _ziskej_kasu_statu(to_tag)
	}

func _je_more_provincie(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	var d = map_data[prov_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner_tag == "SEA" or typ == "sea"

func je_pobrezni_provincie(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	if _je_more_provincie(prov_id):
		return false
	for n_id in map_data[prov_id].get("neighbors", []):
		if _je_more_provincie(int(n_id)):
			return true
	return false

func provincie_ma_pristav(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	return bool(map_data[prov_id].get("has_port", false))

func muze_postavit_pristav(prov_id: int) -> bool:
	if not map_data.has(prov_id):
		return false
	var owner_tag = str(map_data[prov_id].get("owner", "")).strip_edges().to_upper()
	if owner_tag != hrac_stat:
		return false
	if provincie_cooldowny.has(prov_id):
		return false
	if provincie_ma_pristav(prov_id):
		return false
	return je_pobrezni_provincie(prov_id)

func _klic_vztahu(tag_a: String, tag_b: String) -> String:
	return "%s|%s" % [_normalizuj_tag(tag_a), _normalizuj_tag(tag_b)]

func _klic_vztah_pair(tag_a: String, tag_b: String) -> String:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _nacti_vztahy_statu() -> void:
	if _vztahy_nactene:
		return

	_vztahy_statu.clear()
	var file = FileAccess.open(RELATIONSHIPS_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("Nepodarilo se nacist %s" % RELATIONSHIPS_CSV_PATH)
		_vztahy_nactene = true
		return

	if not file.eof_reached():
		file.get_line() # Skip header

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		var parts = line.split(";")
		if parts.size() < 3:
			continue

		var a = _normalizuj_tag(parts[0])
		var b = _normalizuj_tag(parts[1])
		if a == "" or b == "":
			continue

		var score := 0.0
		var score_txt = str(parts[2]).strip_edges()
		if score_txt != "":
			score = float(score_txt)

		_vztahy_statu[_klic_vztahu(a, b)] = score
		_vztahy_statu[_klic_vztahu(b, a)] = score

	_vztahy_nactene = true

func ziskej_vztah_statu(tag_a: String, tag_b: String) -> float:
	_nacti_vztahy_statu()
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0

	if _ai_phase_cache_active:
		var pair_key = _klic_vztah_pair(a, b)
		if _ai_relation_cache.has(pair_key):
			return float(_ai_relation_cache[pair_key])
		var rel_cached = float(_vztahy_statu.get("%s|%s" % [a, b], 0.0))
		_ai_relation_cache[pair_key] = rel_cached
		return rel_cached

	return float(_vztahy_statu.get("%s|%s" % [a, b], 0.0))

func uprav_vztah_statu(tag_a: String, tag_b: String, delta: float) -> float:
	_nacti_vztahy_statu()
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0
	if not muze_upravit_vztah_statu(a, b):
		return ziskej_vztah_statu(a, b)

	var current = ziskej_vztah_statu(a, b)
	var updated = clamp(current + delta, RELATION_MIN, RELATION_MAX)
	if is_equal_approx(updated, current):
		return current
	_vztahy_statu[_klic_vztahu(a, b)] = updated
	_vztahy_statu[_klic_vztahu(b, a)] = updated
	_ai_relation_cache[_klic_vztah_pair(a, b)] = updated
	_ai_can_adjust_relation_cache[_klic_vztah_pair(a, b)] = false
	_mark_ai_war_pair_eval_dirty_pair(a, b)
	_vztah_akce_posledni_kolo[_klic_vztah_pair(a, b)] = aktualni_kolo
	if not is_zero_approx(delta) and not _suppress_relation_global_logs:
		var action_txt = "improved" if delta > 0.0 else "worsened"
		_zaloguj_globalni_zpravu("Relations", "%s %s relation with %s to %.1f." % [a, action_txt, b, updated], "relations")
	if _vyzaduje_vztahova_synchronizace(current, updated):
		_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return updated

func _uprav_vztah_statu_bez_cooldown(tag_a: String, tag_b: String, delta: float) -> float:
	_nacti_vztahy_statu()
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0

	var current = ziskej_vztah_statu(a, b)
	var updated = clamp(current + delta, RELATION_MIN, RELATION_MAX)
	if is_equal_approx(updated, current):
		return current
	_vztahy_statu[_klic_vztahu(a, b)] = updated
	_vztahy_statu[_klic_vztahu(b, a)] = updated
	_ai_relation_cache[_klic_vztah_pair(a, b)] = updated
	_ai_can_adjust_relation_cache.erase(_klic_vztah_pair(a, b))
	_mark_ai_war_pair_eval_dirty_pair(a, b)
	if not is_zero_approx(delta) and not _suppress_relation_global_logs:
		var action_txt = "improved" if delta > 0.0 else "worsened"
		_zaloguj_globalni_zpravu("Relations", "%s %s relation with %s to %.1f." % [a, action_txt, b, updated], "relations")
	if _vyzaduje_vztahova_synchronizace(current, updated):
		_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return updated

func _uprav_vztah_statu_bez_cooldown_rychle(tag_a: String, tag_b: String, delta: float) -> float:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0.0

	var key_ab = "%s|%s" % [a, b]
	var current = float(_vztahy_statu.get(key_ab, 0.0))
	var updated = clamp(current + delta, RELATION_MIN, RELATION_MAX)
	if is_equal_approx(updated, current):
		return current

	_vztahy_statu[key_ab] = updated
	_vztahy_statu["%s|%s" % [b, a]] = updated
	var pair_key = _klic_vztah_pair(a, b)
	_ai_relation_cache[pair_key] = updated
	_ai_can_adjust_relation_cache.erase(pair_key)
	_mark_ai_war_pair_eval_dirty_pair(a, b)
	if _vyzaduje_vztahova_synchronizace(current, updated):
		_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return updated

func _vyzaduje_vztahova_synchronizace(old_rel: float, new_rel: float) -> bool:
	if new_rel >= old_rel:
		return false
	for threshold in [15.0, ALLIANCE_MIN_REL_DEFENSE, ALLIANCE_MIN_REL_OFFENSE, ALLIANCE_MIN_REL_FULL]:
		if old_rel >= threshold and new_rel < threshold:
			return true
	return false

func zlepsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	return uprav_vztah_statu(tag_a, tag_b, absf(amount))

func zhorsi_vztah_statu(tag_a: String, tag_b: String, amount: float = RELATION_STEP_PLAYER) -> float:
	return uprav_vztah_statu(tag_a, tag_b, -absf(amount))

func _je_pratelsky_vztah(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	return ziskej_vztah_statu(tag_a, tag_b) >= AI_FRIEND_RELATION_THRESHOLD

func muze_upravit_vztah_statu(tag_a: String, tag_b: String) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return false
	return zbyva_kol_do_upravy_vztahu(a, b) <= 0

func zbyva_kol_do_upravy_vztahu(tag_a: String, tag_b: String) -> int:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return 0

	var key = _klic_vztah_pair(a, b)
	if not _vztah_akce_posledni_kolo.has(key):
		return 0

	var last_turn = int(_vztah_akce_posledni_kolo[key])
	var elapsed = aktualni_kolo - last_turn
	return max(0, RELATION_ACTION_COOLDOWN_TURNS - elapsed)

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

func nazev_urovne_aliance(level: int) -> String:
	match level:
		ALLIANCE_DEFENSE:
			return "Defensive Alliance"
		ALLIANCE_OFFENSE:
			return "Offensive Alliance"
		ALLIANCE_FULL:
			return "Full Alliance"
		_:
			return "No Alliance"

func _ma_stat_prijmout_alianci(tag_a: String, tag_b: String, target_level: int) -> bool:
	if _vazal_musi_prijmout_zadost(tag_a, tag_b):
		return true
	var rel = ziskej_vztah_statu(tag_a, tag_b)
	if rel < ALLIANCE_HARD_REJECT_REL:
		return false
	return rel >= _minimalni_vztah_pro_alianci(target_level)

func ziskej_uroven_aliance(tag_a: String, tag_b: String) -> int:
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return ALLIANCE_NONE
	return int(aliance_statu.get(key, ALLIANCE_NONE))

func _nastav_uroven_aliance_bez_kontroly(tag_a: String, tag_b: String, level: int) -> void:
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return
	if level <= ALLIANCE_NONE:
		aliance_statu.erase(key)
		if _ai_phase_cache_active:
			_ai_alliance_level_cache.erase(key)
			_ai_allies_cache.clear()
			_mark_ai_war_pair_eval_dirty_pair(tag_a, tag_b)
		return
	aliance_statu[key] = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if _ai_phase_cache_active:
		_ai_alliance_level_cache[key] = int(aliance_statu[key])
		_ai_allies_cache.clear()
		_mark_ai_war_pair_eval_dirty_pair(tag_a, tag_b)

func nastav_uroven_aliance(tag_a: String, tag_b: String, level: int, ignoruj_vztahove_podminky: bool = false) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var target_level = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if a == "" or b == "" or a == b:
		return false

	if jsou_ve_valce(a, b):
		if target_level > ALLIANCE_NONE:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Alliance cannot be formed during an active war.")
			return false

	var old_level = ziskej_uroven_aliance(a, b)
	if target_level > ALLIANCE_NONE:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if (not ignoruj_vztahove_podminky) and target_level > old_level and not _ma_stat_prijmout_alianci(a, b, target_level):
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				if rel < ALLIANCE_HARD_REJECT_REL:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s and %s do not get along (relation %.1f), alliance rejected." % [a, b, rel])
				else:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s rejects %s: %s requires relation at least %.1f." % [b, a, nazev_urovne_aliance(target_level), needed_rel])
			return false
		if (not ignoruj_vztahove_podminky) and rel < needed_rel:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Relation %.1f is too low for %s (needs %.1f)." % [rel, nazev_urovne_aliance(target_level), needed_rel])
			return false

	_nastav_uroven_aliance_bez_kontroly(a, b, target_level)

	if old_level != target_level:
		_zaloguj_globalni_zpravu("Alliance", "Alliance between %s and %s: %s." % [a, b, nazev_urovne_aliance(target_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var title = "Diplomacy"
			var text = "Alliance between %s and %s: %s" % [a, b, nazev_urovne_aliance(target_level)]
			_pridej_popup_zucastnenym_hracum(a, b, title, text)
	return true

func _synchronizuj_aliance_po_zmene_vztahu(tag_a: String, tag_b: String) -> void:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return

	var current_level = ziskej_uroven_aliance(a, b)
	if current_level <= ALLIANCE_NONE:
		return

	if jsou_ve_valce(a, b):
		_nastav_uroven_aliance_bez_kontroly(a, b, ALLIANCE_NONE)
		return

	var rel = ziskej_vztah_statu(a, b)
	var new_level = current_level
	if rel < ALLIANCE_MIN_REL_DEFENSE:
		new_level = ALLIANCE_NONE
	elif rel < ALLIANCE_MIN_REL_OFFENSE:
		new_level = min(new_level, ALLIANCE_DEFENSE)
	elif rel < ALLIANCE_MIN_REL_FULL:
		new_level = min(new_level, ALLIANCE_OFFENSE)

	if new_level != current_level:
		_nastav_uroven_aliance_bez_kontroly(a, b, new_level)
		_zaloguj_globalni_zpravu("Alliance", "Relations weakened the alliance %s-%s: %s." % [a, b, nazev_urovne_aliance(new_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var text = "Relations weakened the alliance %s-%s: %s" % [a, b, nazev_urovne_aliance(new_level)]
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", text)
		if new_level == ALLIANCE_NONE:
			_expeluj_jednotky_bez_pristupu(a)
			_expeluj_jednotky_bez_pristupu(b)

	_synchronizuj_vojensky_pristup_po_zmene_vztahu(a, b)

func _synchronizuj_vojensky_pristup_po_zmene_vztahu(tag_a: String, tag_b: String) -> void:
	var rel = ziskej_vztah_statu(tag_a, tag_b)
	if rel >= 15.0:
		return
	# Revoke A→B grant if A gave B access
	for pair in [[tag_a, tag_b], [tag_b, tag_a]]:
		var host = pair[0]
		var guest = pair[1]
		var key = "%s|%s" % [host, guest]
		if vojensky_pristup.has(key):
			vojensky_pristup.erase(key)
			_zaloguj_globalni_zpravu("Diplomacy", "Military access %s→%s revoked (relations dropped below 15)." % [host, guest], "diplomacy")
			if je_lidsky_stat(guest):
				_pridej_popup_hraci(guest, "Diplomacy", "Military access in %s revoked — relations dropped too low." % host)
			if je_lidsky_stat(host):
				_pridej_popup_hraci(host, "Diplomacy", "You revoked military access for %s (relations too low)." % guest)
			_expeluj_jednotky_bez_pristupu(guest)

# ---- Alliance Groups ----

func _generuj_id_aliance() -> String:
	_aliance_skupiny_seq += 1
	return "alliance_%d" % _aliance_skupiny_seq

func vytvor_alianci_skupinu(nazev: String, level: int, zakladatel: String, clenove: Array = [], barva: String = "#4488ff") -> Dictionary:
	var founder = _normalizuj_tag(zakladatel)
	if founder == "":
		return {"ok": false, "reason": "Invalid founder tag."}
	var clean_name = nazev.strip_edges()
	if clean_name == "":
		clean_name = "Alliance %d" % (_aliance_skupiny_seq + 1)
	var target_level = clampi(level, ALLIANCE_DEFENSE, ALLIANCE_FULL)

	var alliance_id = _generuj_id_aliance()
	var member_list: Array = [founder]
	for c in clenove:
		var tag = _normalizuj_tag(str(c))
		if tag == "" or tag == "SEA" or tag == founder:
			continue
		if not member_list.has(tag):
			member_list.append(tag)

	var skupina: Dictionary = {
		"id": alliance_id,
		"name": clean_name,
		"level": target_level,
		"founder": founder,
		"members": member_list,
		"created_turn": aktualni_kolo,
		"color": barva
	}
	aliance_skupiny[alliance_id] = skupina

	_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	_zaloguj_globalni_zpravu("Alliance", "%s founded alliance '%s' (%s)." % [founder, clean_name, nazev_urovne_aliance(target_level)], "alliance")
	return {"ok": true, "id": alliance_id}

func upravit_alianci_skupinu(alliance_id: String, novy_nazev: String = "", novy_level: int = -1) -> bool:
	if not aliance_skupiny.has(alliance_id):
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var changed = false
	if novy_nazev.strip_edges() != "":
		skupina["name"] = novy_nazev.strip_edges()
		changed = true
	if novy_level >= ALLIANCE_DEFENSE and novy_level <= ALLIANCE_FULL and novy_level != int(skupina.get("level", 0)):
		skupina["level"] = novy_level
		changed = true
	if changed:
		aliance_skupiny[alliance_id] = skupina
		_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	return changed

func pridej_clena_do_aliance(alliance_id: String, tag: String, ignoruj_vztahove_podminky: bool = false) -> Dictionary:
	if not aliance_skupiny.has(alliance_id):
		return {"ok": false, "reason": "Alliance does not exist."}
	var clean = _normalizuj_tag(tag)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid country tag."}
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	if members.has(clean):
		return {"ok": false, "reason": "%s is already a member." % clean}

	var candidate_overlord = ziskej_overlorda_statu(clean)
	var forced_by_member_overlord = (candidate_overlord != "" and members.has(candidate_overlord))
	var ignore_requirements = ignoruj_vztahove_podminky or forced_by_member_overlord

	var level = int(skupina.get("level", ALLIANCE_DEFENSE))

	if not ignore_requirements:
		for m in members:
			var member_tag = _normalizuj_tag(str(m))
			if member_tag == "" or member_tag == clean:
				continue
			if jsou_ve_valce(clean, member_tag):
				return {"ok": false, "reason": "%s is at war with member %s." % [clean, member_tag]}
			var rel = ziskej_vztah_statu(clean, member_tag)
			var needed = _minimalni_vztah_pro_alianci(level)
			if rel < needed:
				return {"ok": false, "reason": "Relation with %s is %.1f (needs %.1f for %s)." % [member_tag, rel, needed, nazev_urovne_aliance(level)]}

	members.append(clean)
	skupina["members"] = members
	aliance_skupiny[alliance_id] = skupina

	_synchronizuj_bilateralni_aliance_skupiny(alliance_id)
	_zaloguj_globalni_zpravu("Alliance", "%s joined alliance '%s'." % [clean, str(skupina.get("name", ""))], "alliance")
	if je_lidsky_stat(clean):
		_pridej_popup_hraci(clean, "Alliance", "You joined alliance '%s'." % str(skupina.get("name", "")))
	if forced_by_member_overlord and je_lidsky_stat(candidate_overlord):
		_pridej_popup_hraci(candidate_overlord, "Alliance", "%s joined '%s' automatically as your vassal." % [clean, str(skupina.get("name", ""))])
	return {"ok": true}

func odeber_clena_z_aliance(alliance_id: String, tag: String) -> bool:
	if not aliance_skupiny.has(alliance_id):
		return false
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	if not members.has(clean):
		return false

	members.erase(clean)
	skupina["members"] = members

	_zaloguj_globalni_zpravu("Alliance", "%s left alliance '%s'." % [clean, str(skupina.get("name", ""))], "alliance")
	if je_lidsky_stat(clean):
		_pridej_popup_hraci(clean, "Alliance", "You left alliance '%s'." % str(skupina.get("name", "")))

	if members.size() < 2:
		var old_name = str(skupina.get("name", ""))
		aliance_skupiny.erase(alliance_id)
		_zaloguj_globalni_zpravu("Alliance", "Alliance '%s' disbanded (too few members)." % old_name, "alliance")
	else:
		aliance_skupiny[alliance_id] = skupina

	_resynchronizuj_bilateralni_aliance_vsech_skupin()
	return true

func rozpust_alianci(alliance_id: String) -> bool:
	if not aliance_skupiny.has(alliance_id):
		return false
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var old_name = str(skupina.get("name", ""))
	var members = (skupina.get("members", []) as Array).duplicate()
	aliance_skupiny.erase(alliance_id)

	_zaloguj_globalni_zpravu("Alliance", "Alliance '%s' has been disbanded." % old_name, "alliance")
	for m in members:
		if je_lidsky_stat(str(m)):
			_pridej_popup_hraci(str(m), "Alliance", "Alliance '%s' has been disbanded." % old_name)

	_resynchronizuj_bilateralni_aliance_vsech_skupin()
	return true

func ziskej_aliance_statu(tag: String) -> Array:
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		if members.has(clean):
			result.append(skupina.duplicate(true))
	return result

func ziskej_alianci_podle_id(alliance_id: String) -> Dictionary:
	if not aliance_skupiny.has(alliance_id):
		return {}
	return (aliance_skupiny[alliance_id] as Dictionary).duplicate(true)

func ziskej_spolecne_aliance(tag_a: String, tag_b: String) -> Array:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		if members.has(a) and members.has(b):
			result.append(skupina.duplicate(true))
	return result

func ziskej_podminky_clenstvi_aliance(alliance_id: String, candidate_tag: String) -> Array:
	if not aliance_skupiny.has(alliance_id):
		return []
	var clean = _normalizuj_tag(candidate_tag)
	if clean == "":
		return []
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	var candidate_overlord = ziskej_overlorda_statu(clean)
	var forced_by_member_overlord = (candidate_overlord != "" and members.has(candidate_overlord))
	var level = int(skupina.get("level", ALLIANCE_DEFENSE))
	var needed_rel = _minimalni_vztah_pro_alianci(level)
	var conditions: Array = []

	for m in members:
		var member_tag = _normalizuj_tag(str(m))
		if member_tag == "" or member_tag == clean:
			continue
		var rel = ziskej_vztah_statu(clean, member_tag)
		var at_war = jsou_ve_valce(clean, member_tag)
		var oba_lidske = je_lidsky_stat(clean) and je_lidsky_stat(member_tag)
		var forced_pair = forced_by_member_overlord
		var splneno = forced_pair or oba_lidske or (rel >= needed_rel and not at_war)
		conditions.append({
			"member": member_tag,
			"relation": rel,
			"needed": needed_rel,
			"at_war": at_war,
			"both_human": oba_lidske,
			"forced_by_overlord": forced_pair,
			"overlord": candidate_overlord,
			"met": splneno
		})
	return conditions

func _synchronizuj_bilateralni_aliance_skupiny(alliance_id: String) -> void:
	if not aliance_skupiny.has(alliance_id):
		return
	var skupina = aliance_skupiny[alliance_id] as Dictionary
	var members = skupina.get("members", []) as Array
	var level = int(skupina.get("level", ALLIANCE_DEFENSE))

	for i in range(members.size()):
		for j in range(i + 1, members.size()):
			var a = _normalizuj_tag(str(members[i]))
			var b = _normalizuj_tag(str(members[j]))
			if a == "" or b == "":
				continue
			var current = ziskej_uroven_aliance(a, b)
			if level > current:
				_nastav_uroven_aliance_bez_kontroly(a, b, level)

func _resynchronizuj_bilateralni_aliance_vsech_skupin() -> void:
	var max_levels: Dictionary = {}
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = skupina.get("members", []) as Array
		var level = int(skupina.get("level", ALLIANCE_DEFENSE))
		for i in range(members.size()):
			for j in range(i + 1, members.size()):
				var a = _normalizuj_tag(str(members[i]))
				var b = _normalizuj_tag(str(members[j]))
				if a == "" or b == "":
					continue
				var key = _klic_pair(a, b)
				if key == "":
					continue
				var existing = int(max_levels.get(key, ALLIANCE_NONE))
				if level > existing:
					max_levels[key] = level

	for key in aliance_statu.keys().duplicate():
		if not max_levels.has(key):
			aliance_statu.erase(key)
			if _ai_phase_cache_active:
				_ai_alliance_level_cache.erase(key)
				var parts_remove = str(key).split("|")
				if parts_remove.size() == 2:
					_mark_ai_war_pair_eval_dirty_pair(parts_remove[0], parts_remove[1])

	for key in max_levels:
		var level = int(max_levels[key])
		var parts = key.split("|")
		if parts.size() == 2:
			_nastav_uroven_aliance_bez_kontroly(parts[0], parts[1], level)

	if _ai_phase_cache_active:
		_ai_allies_cache.clear()

func _vycisti_aliance_skupiny_mrtve_staty() -> void:
	var active = _ziskej_aktivni_staty()
	var changed = false
	for aid in aliance_skupiny.keys().duplicate():
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = (skupina.get("members", []) as Array).duplicate()
		var new_members: Array = []
		for m in members:
			if active.has(str(m)):
				new_members.append(str(m))
		if new_members.size() != members.size():
			changed = true
			if new_members.size() < 2:
				aliance_skupiny.erase(aid)
			else:
				skupina["members"] = new_members
				aliance_skupiny[aid] = skupina
	if changed:
		_resynchronizuj_bilateralni_aliance_vsech_skupin()

func _ziskej_vsechny_aliance_skupiny() -> Array:
	var result: Array = []
	for aid in aliance_skupiny:
		result.append((aliance_skupiny[aid] as Dictionary).duplicate(true))
	return result

func _ziskej_aliance_kde_je_zakladatel(tag: String) -> Array:
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return []
	var result: Array = []
	for aid in aliance_skupiny:
		var skupina = aliance_skupiny[aid] as Dictionary
		if _normalizuj_tag(str(skupina.get("founder", ""))) == clean:
			result.append(skupina.duplicate(true))
	return result

func _ziskej_spojence_s_min_alianci(state_tag: String, min_level: int) -> Array:
	var out: Array = []
	var cisty = _normalizuj_tag(state_tag)
	if cisty == "":
		return out
	if _ai_phase_cache_active:
		var cache_key = "%s|%d" % [cisty, min_level]
		if _ai_allies_cache.has(cache_key):
			return (_ai_allies_cache[cache_key] as Array).duplicate()

	var active_states: Array = _turn_active_states if _turn_cache_valid else _ziskej_aktivni_staty()
	for other in active_states:
		var tag = _normalizuj_tag(str(other))
		if tag == "" or tag == cisty:
			continue
		if ziskej_uroven_aliance(cisty, tag) >= min_level:
			out.append(tag)

	if _ai_phase_cache_active:
		_ai_allies_cache["%s|%d" % [cisty, min_level]] = out.duplicate()
	return out

func _vycisti_expirovane_neagresivni_smlouvy() -> void:
	var keys = neagresivni_smlouvy.keys().duplicate()
	for k in keys:
		var expiry_turn = int(neagresivni_smlouvy.get(k, -1))
		if expiry_turn < aktualni_kolo:
			neagresivni_smlouvy.erase(k)

func ma_neagresivni_smlouvu(tag_a: String, tag_b: String) -> bool:
	_vycisti_expirovane_neagresivni_smlouvy()
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	return neagresivni_smlouvy.has(key)

func zbyva_kol_neagresivni_smlouvy(tag_a: String, tag_b: String) -> int:
	_vycisti_expirovane_neagresivni_smlouvy()
	var key = _klic_pair(tag_a, tag_b)
	if key == "" or not neagresivni_smlouvy.has(key):
		return 0
	var expiry_turn = int(neagresivni_smlouvy[key])
	return max(0, expiry_turn - aktualni_kolo + 1)

func je_aliancni_zadost_cekajici(odesilatel: String, prijemce: String) -> bool:
	var from_clean = _normalizuj_tag(odesilatel)
	var to_clean = _normalizuj_tag(prijemce)
	if from_clean == "" or to_clean == "" or from_clean == to_clean:
		return false

	for req in cekajici_aliancni_zadosti:
		if _normalizuj_tag(str(req.get("from", ""))) != from_clean:
			continue
		if _normalizuj_tag(str(req.get("to", ""))) != to_clean:
			continue
		return true
	return false

func odeslat_aliancni_zadost(tag_a: String, tag_b: String, level: int, ignoruj_vztahove_podminky: bool = false) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var target_level = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if a == "" or b == "" or a == b:
		return false
	if target_level <= ALLIANCE_NONE:
		return false
	if jsou_ve_valce(a, b):
		return false
	if je_aliancni_zadost_cekajici(a, b):
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "Alliance request already sent. Waiting for response.")
		return false

	if not ignoruj_vztahove_podminky:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if rel < needed_rel:
			if je_lidsky_stat(a):
				_pridej_popup_hraci(a, "Diplomacy", "%s requires relation at least %.1f." % [nazev_urovne_aliance(target_level), needed_rel])
			return false

	cekajici_aliancni_zadosti.append({
		"from": a,
		"to": b,
		"level": target_level,
		"turn": aktualni_kolo
	})
	_zaloguj_globalni_zpravu("Alliance", "%s sent %s alliance request to %s." % [a, nazev_urovne_aliance(target_level), b], "alliance")
	if je_lidsky_stat(a):
		_pridej_popup_hraci(a, "Diplomacy", "Request for %s was sent to %s." % [nazev_urovne_aliance(target_level), b])
	return true

func _vyhodnot_aliancni_zadosti_pred_ai() -> void:
	if cekajici_aliancni_zadosti.is_empty():
		return

	var pending = cekajici_aliancni_zadosti.duplicate(true)
	cekajici_aliancni_zadosti.clear()

	for req in pending:
		var from_tag = _normalizuj_tag(str(req.get("from", "")))
		var to_tag = _normalizuj_tag(str(req.get("to", "")))
		var level = int(req.get("level", ALLIANCE_NONE))
		if from_tag == "" or to_tag == "" or from_tag == to_tag:
			continue
		if level <= ALLIANCE_NONE:
			continue
		if jsou_ve_valce(from_tag, to_tag):
			continue
		if je_lidsky_stat(to_tag):
			# Human recipient decides manually via diplomacy popup queue.
			_pridej_diplomatickou_zadost(from_tag, to_tag, "alliance", level)
			continue

		if _ma_stat_prijmout_alianci(to_tag, from_tag, level):
			nastav_uroven_aliance(from_tag, to_tag, level)
		else:
			_zaloguj_globalni_zpravu("Alliance", "%s declined %s request for %s." % [to_tag, from_tag, nazev_urovne_aliance(level)], "alliance")
			if je_lidsky_stat(from_tag):
				_pridej_popup_hraci(from_tag, "Diplomacy", "Country %s rejected your request for %s." % [to_tag, nazev_urovne_aliance(level)])

func uzavrit_neagresivni_smlouvu(tag_a: String, tag_b: String) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b or a == "SEA" or b == "SEA":
		return false
	var forced_vassal_accept = _vazal_musi_prijmout_zadost(a, b)
	if jsou_ve_valce(a, b):
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Non-aggression pact cannot be signed during war.")
		return false

	var rel = ziskej_vztah_statu(a, b)
	if rel < NON_AGGRESSION_MIN_REL and not forced_vassal_accept:
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "Non-aggression pact requires relation at least %.1f." % NON_AGGRESSION_MIN_REL)
		return false

	var key = _klic_pair(a, b)
	if key == "":
		return false

	neagresivni_smlouvy[key] = aktualni_kolo + NON_AGGRESSION_DURATION_TURNS - 1
	_zaloguj_globalni_zpravu("Diplomacy", "%s and %s signed a non-aggression pact for %d turns." % [a, b, NON_AGGRESSION_DURATION_TURNS], "diplomacy")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, "Diplomacy", "%s and %s signed a non-aggression pact for %d turns." % [a, b, NON_AGGRESSION_DURATION_TURNS])
	return true

# ---- Military access ----
# vojensky_pristup["HOST|GUEST"] = true  →  HOST has granted GUEST right to move troops through HOST's territory.
# Alliance automatically grants mutual access (checked in ma_vojensky_pristup, not stored).

func ma_vojensky_pristup(guest: String, host: String) -> bool:
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "" or g == h:
		return false
	# Any alliance level grants automatic mutual military access.
	if ziskej_uroven_aliance(g, h) > ALLIANCE_NONE:
		return true
	# Manual grant: HOST|GUEST
	return vojensky_pristup.has("%s|%s" % [h, g])

func udelit_vojensky_pristup(host: String, guest: String) -> void:
	var h = _normalizuj_tag(host)
	var g = _normalizuj_tag(guest)
	if h == "" or g == "" or h == g:
		return
	vojensky_pristup["%s|%s" % [h, g]] = true

func odvolej_vojensky_pristup(host: String, guest: String) -> void:
	var h = _normalizuj_tag(host)
	var g = _normalizuj_tag(guest)
	if h == "" or g == "":
		return
	vojensky_pristup.erase("%s|%s" % [h, g])
	_expeluj_jednotky_bez_pristupu(g)

func _najdi_nejblizsi_vlastni_provincii_pro_presun(tag: String, from_prov_id: int) -> int:
	var source = map_data.get(from_prov_id, {})
	var sx = float(source.get("x", 0.0))
	var sy = float(source.get("y", 0.0))
	var best_id = -1
	var best_dist = INF
	for p_id in map_data:
		if p_id == from_prov_id:
			continue
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if owner_tag != tag:
			continue
		var existing_army = _normalizuj_tag(str(d.get("army_owner", "")))
		if existing_army != "" and existing_army != tag:
			continue
		var dx = float(d.get("x", 0.0)) - sx
		var dy = float(d.get("y", 0.0)) - sy
		var dist = dx * dx + dy * dy
		if dist < best_dist:
			best_dist = dist
			best_id = p_id
	return best_id

func _expeluj_jednotky_bez_pristupu(filter_tag: String = "") -> void:
	if map_data.is_empty():
		return
	var ft = _normalizuj_tag(filter_tag)

	var to_expel: Array = []
	for prov_id in map_data:
		var d = map_data[prov_id]
		var army_tag = _normalizuj_tag(str(d.get("army_owner", "")))
		if army_tag == "":
			continue
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if army_tag == owner_tag:
			continue
		if ft != "" and army_tag != ft:
			continue
		var vojaci = int(d.get("soldiers", 0))
		if vojaci <= 0:
			continue
		if not muze_vstoupit_na_uzemi(army_tag, owner_tag):
			to_expel.append({"prov_id": prov_id, "army_tag": army_tag, "soldiers": vojaci, "owner_tag": owner_tag})

	if to_expel.is_empty():
		return

	var notified_tags: Array = []
	for entry in to_expel:
		var prov_id = entry["prov_id"]
		var army_tag = entry["army_tag"]
		var vojaci = entry["soldiers"]

		map_data[prov_id]["army_owner"] = ""
		map_data[prov_id]["soldiers"] = 0

		var target_id = _najdi_nejblizsi_vlastni_provincii_pro_presun(army_tag, prov_id)
		if target_id >= 0:
			map_data[target_id]["army_owner"] = army_tag
			map_data[target_id]["soldiers"] = int(map_data[target_id].get("soldiers", 0)) + vojaci

		if je_lidsky_stat(army_tag) and not notified_tags.has(army_tag):
			notified_tags.append(army_tag)

	for ptag in notified_tags:
		_pridej_popup_hraci(ptag, "Military", "Your units have been expelled from unauthorized territory and have returned home.")

	var ml = _get_map_loader()
	if ml and ml.has_method("aktualizuj_ikony_armad"):
		ml.aktualizuj_ikony_armad()

func pozadej_vojensky_pristup(guest: String, host: String) -> bool:
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "" or g == h:
		return false
	if jsou_ve_valce(g, h):
		if je_lidsky_stat(g):
			_pridej_popup_hraci(g, "Diplomacy", "Cannot request military access during war.")
		return false
	if ma_vojensky_pristup(g, h):
		return false
	# If target is AI, grant immediately when relations ≥ 15, otherwise deny.
	if not je_lidsky_stat(h):
		if _vazal_musi_prijmout_zadost(h, g):
			udelit_vojensky_pristup(h, g)
			_zaloguj_globalni_zpravu("Diplomacy", "%s automatically granted military access to overlord %s." % [h, g], "diplomacy")
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "%s (your vassal) granted you military access automatically." % h)
			return true
		var rel = ziskej_vztah_statu(g, h)
		if rel >= 15.0:
			udelit_vojensky_pristup(h, g)
			_zaloguj_globalni_zpravu("Diplomacy", "%s granted military access to %s." % [h, g], "diplomacy")
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "%s granted you military access to their territory." % h)
			return true
		else:
			if je_lidsky_stat(g):
				_pridej_popup_hraci(g, "Diplomacy", "Military access denied by %s (relations too low: %.0f, need 15)." % [h, rel])
			return false
	# Target is human — send a diplomatic request.
	return _pridej_diplomatickou_zadost(g, h, "military_access")

func _ma_cekajici_zadost_vojenskeho_pristupu(guest: String, host: String) -> bool:
	var g = _normalizuj_tag(guest)
	var h = _normalizuj_tag(host)
	if g == "" or h == "":
		return false
	if not cekajici_diplomaticke_zadosti.has(h):
		return false
	for req in (cekajici_diplomaticke_zadosti[h] as Array):
		if _normalizuj_tag(str(req.get("from", ""))) == g and str(req.get("type", "")) == "military_access":
			return true
	return false

func _pridej_diplomatickou_zadost(from_tag: String, to_tag: String, req_type: String, alliance_level: int = ALLIANCE_NONE) -> bool:
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	if from_clean == "" or to_clean == "" or from_clean == to_clean:
		return false

	if req_type != "alliance" and req_type != "non_aggression" and req_type != "peace" and req_type != "military_access":
		return false

	if not _je_essential_diplomaticka_zadost(from_clean, to_clean, req_type, alliance_level):
		return false

	# Vassals cannot reject overlord diplomacy; apply immediately.
	if _vazal_musi_prijmout_zadost(to_clean, from_clean):
		var forced_req = {
			"from": from_clean,
			"to": to_clean,
			"type": req_type,
			"level": alliance_level,
			"turn": aktualni_kolo
		}
		var forced_ok = _vykonej_prijeti_diplomaticke_zadosti(to_clean, forced_req, true)
		if forced_ok:
			_zaloguj_globalni_zpravu("Diplomacy", "%s automatically accepted %s from overlord %s." % [to_clean, req_type, from_clean], "diplomacy")
		return forced_ok

	if not cekajici_diplomaticke_zadosti.has(to_clean):
		cekajici_diplomaticke_zadosti[to_clean] = []

	var queue = cekajici_diplomaticke_zadosti[to_clean] as Array
	var new_req = {
		"from": from_clean,
		"to": to_clean,
		"type": req_type,
		"level": alliance_level,
		"turn": aktualni_kolo
	}

	# Keep max one visible request per sender to avoid spam; replace only when the
	# new request is more important than the currently queued one.
	for i in range(queue.size()):
		var existing = queue[i] as Dictionary
		if _normalizuj_tag(str(existing.get("from", ""))) != from_clean:
			continue
		if _diplomaticka_zadost_priorita(new_req) < _diplomaticka_zadost_priorita(existing):
			queue[i] = new_req
			_zaloguj_globalni_zpravu("Diplomacy", "%s updated diplomatic request for %s (%s)." % [from_clean, to_clean, req_type], "diplomacy")
			return true
		return false

	queue.append(new_req)
	if req_type == "alliance":
		_zaloguj_globalni_zpravu("Alliance", "%s sent %s alliance proposal (%s)." % [from_clean, to_clean, nazev_urovne_aliance(alliance_level)], "alliance")
	elif req_type == "peace":
		_zaloguj_globalni_zpravu("Diplomacy", "%s sent peace proposal to %s." % [from_clean, to_clean], "diplomacy")
	elif req_type == "non_aggression":
		_zaloguj_globalni_zpravu("Diplomacy", "%s proposed non-aggression pact to %s." % [from_clean, to_clean], "diplomacy")
	elif req_type == "military_access":
		_zaloguj_globalni_zpravu("Diplomacy", "%s requested military access from %s." % [from_clean, to_clean], "diplomacy")
	return true

func _je_essential_diplomaticka_zadost(from_tag: String, to_tag: String, req_type: String, alliance_level: int) -> bool:
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	if from_clean == "" or to_clean == "":
		return false

	# Human initiated diplomacy is always actionable and should never be filtered out.
	if je_lidsky_stat(from_clean):
		return true

	# AI-generated requests are filtered to only critical/important offers.
	match req_type:
		"peace":
			return true
		"alliance":
			# Defensive alliance offers are still strategically important.
			return alliance_level >= ALLIANCE_DEFENSE
		"non_aggression":
			# Show only meaningful NAPs from AI to avoid low-value spam.
			var rel = ziskej_vztah_statu(from_clean, to_clean)
			return rel >= maxf(35.0, NON_AGGRESSION_MIN_REL)
		"military_access":
			return true
		_:
			return false

func _diplomaticka_zadost_priorita(req: Dictionary) -> int:
	var from_tag = _normalizuj_tag(str(req.get("from", "")))
	if je_lidsky_stat(from_tag):
		return DIP_REQUEST_PRIORITY_PLAYER

	match str(req.get("type", "")):
		"peace":
			return DIP_REQUEST_PRIORITY_PEACE
		"alliance":
			return DIP_REQUEST_PRIORITY_ALLIANCE
		"non_aggression":
			return DIP_REQUEST_PRIORITY_NON_AGGRESSION
		"military_access":
			return DIP_REQUEST_PRIORITY_MILITARY_ACCESS
		_:
			return 100

func _ziskej_index_nejvyssi_priority_zadosti(queue: Array) -> int:
	if queue.is_empty():
		return -1

	var best_idx := 0
	var best_priority := _diplomaticka_zadost_priorita(queue[0] as Dictionary)
	var best_turn := int((queue[0] as Dictionary).get("turn", 0))

	for i in range(1, queue.size()):
		var req = queue[i] as Dictionary
		var p = _diplomaticka_zadost_priorita(req)
		var t = int(req.get("turn", 0))
		if p < best_priority or (p == best_priority and t < best_turn):
			best_idx = i
			best_priority = p
			best_turn = t

	return best_idx

func _odeber_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> Dictionary:
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if player_clean == "" or from_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	for i in range(queue.size() - 1, -1, -1):
		var req = queue[i]
		if _normalizuj_tag(str(req.get("from", ""))) != from_clean:
			continue
		queue.remove_at(i)
		return req
	return {}

func ziskej_cekajici_zadost_od_statu(hrac_tag: String, from_tag: String) -> Dictionary:
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if player_clean == "" or from_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	for req in (cekajici_diplomaticke_zadosti[player_clean] as Array):
		if _normalizuj_tag(str(req.get("from", ""))) == from_clean:
			return req.duplicate(true)
	return {}

func ziskej_prvni_cekajici_diplomatickou_zadost(hrac_tag: String) -> Dictionary:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return {}
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return {}

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	if queue.is_empty():
		return {}

	var idx = _ziskej_index_nejvyssi_priority_zadosti(queue)
	if idx < 0:
		return {}
	return (queue[idx] as Dictionary).duplicate(true)

func ziskej_pocet_cekajicich_diplomatickych_zadosti(hrac_tag: String) -> int:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0
	return (cekajici_diplomaticke_zadosti[player_clean] as Array).size()

func ziskej_cekajici_diplomaticke_zadosti(hrac_tag: String) -> Array:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return []
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return []

	var queue = (cekajici_diplomaticke_zadosti[player_clean] as Array).duplicate(true)
	queue.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		var pa = _diplomaticka_zadost_priorita(da)
		var pb = _diplomaticka_zadost_priorita(db)
		if pa != pb:
			return pa < pb
		return int(da.get("turn", 0)) < int(db.get("turn", 0))
	)
	return queue

func _vazal_musi_prijmout_zadost(receiver_tag: String, sender_tag: String) -> bool:
	var receiver = _normalizuj_tag(receiver_tag)
	var sender = _normalizuj_tag(sender_tag)
	if receiver == "" or sender == "" or receiver == sender:
		return false
	return ziskej_overlorda_statu(receiver) == sender

func _vykonej_prijeti_diplomaticke_zadosti(player_clean: String, req: Dictionary, forced_vassal_accept: bool = false) -> bool:
	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatic offer"
	if req_type == "alliance":
		req_name = "alliance offer"
	elif req_type == "peace":
		req_name = "peace offer"
	elif req_type == "non_aggression":
		req_name = "non-aggression pact offer"
	elif req_type == "military_access":
		req_name = "military access request"

	if req_type == "alliance":
		var level = int(req.get("level", ALLIANCE_NONE))
		var obe_strany_lide = je_lidsky_stat(player_clean) and je_lidsky_stat(sender)
		var alliance_ok = false
		if obe_strany_lide:
			# Human-vs-human diplomacy is decided purely by acceptance/rejection.
			alliance_ok = nastav_uroven_aliance(player_clean, sender, level, true)
		else:
			alliance_ok = nastav_uroven_aliance(player_clean, sender, level)
		if alliance_ok:
			# Try to place both into an alliance group
			var placed = false
			var sender_groups = ziskej_aliance_statu(sender)
			for grp in sender_groups:
				if int(grp.get("level", 0)) == level:
					var members = grp.get("members", []) as Array
					if not members.has(player_clean):
						var ignoruj = obe_strany_lide
						var res = pridej_clena_do_aliance(str(grp.get("id", "")), player_clean, ignoruj)
						if res.get("ok", false):
							placed = true
							break
			if not placed:
				var group_name = "%s-%s Pact" % [sender, player_clean]
				vytvor_alianci_skupinu(group_name, level, sender, [player_clean])
			_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return alliance_ok
	if req_type == "non_aggression":
		var nap_ok = uzavrit_neagresivni_smlouvu(player_clean, sender)
		if nap_ok:
			_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return nap_ok
	if req_type == "peace":
		if not jsou_ve_valce(player_clean, sender):
			return false
		uzavri_mir_a_zahaj_konferenci(player_clean, sender, "peace_offer")
		if je_lidsky_stat(player_clean) or je_lidsky_stat(sender):
			_pridej_popup_zucastnenym_hracum(player_clean, sender, "Diplomacy", "Peace offer accepted: %s and %s made peace." % [player_clean, sender])
		_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
		return true
	if req_type == "military_access":
		udelit_vojensky_pristup(player_clean, sender)
		_zaloguj_globalni_zpravu("Diplomacy", "%s granted military access to %s." % [player_clean, sender], "diplomacy")
		if je_lidsky_stat(sender):
			_pridej_popup_hraci(sender, "Diplomacy", "%s granted you military access to their territory." % player_clean)
		return true

	# Keep generic fallback for future diplomatic request types.
	_zaloguj_globalni_zpravu("Diplomacy", "%s accepted %s from %s." % [player_clean, req_name, sender], "diplomacy")
	if forced_vassal_accept and je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, you automatically accepted a diplomatic request from your overlord (%s)." % sender)
	return false

func hrac_prijmi_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	var player_clean = _normalizuj_tag(hrac_tag)
	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false
	return _vykonej_prijeti_diplomaticke_zadosti(player_clean, req)

func hrac_odmitni_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	var player_clean = _normalizuj_tag(hrac_tag)
	var from_clean = _normalizuj_tag(from_tag)
	if _vazal_musi_prijmout_zadost(player_clean, from_clean):
		return hrac_prijmi_diplomatickou_zadost(player_clean, from_clean)

	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false

	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatic offer"
	if req_type == "alliance":
		req_name = "alliance offer"
	elif req_type == "peace":
		req_name = "peace offer"
	elif req_type == "non_aggression":
		req_name = "non-aggression pact offer"
	elif req_type == "military_access":
		req_name = "military access request"
	if je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacy", "You declined a diplomatic request from %s." % sender)
	_zaloguj_globalni_zpravu("Diplomacy", "%s declined %s from %s." % [player_clean, req_name, sender], "diplomacy")
	return true

func hrac_odmitni_vsechny_diplomaticke_zadosti(hrac_tag: String) -> int:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	var queue_copy = queue.duplicate(true)
	var count = queue_copy.size()
	if count <= 0:
		return 0

	var auto_accepted := 0
	for req_any in queue_copy:
		var req = req_any as Dictionary
		var sender = _normalizuj_tag(str(req.get("from", "")))
		if _vazal_musi_prijmout_zadost(player_clean, sender):
			if hrac_prijmi_diplomatickou_zadost(player_clean, sender):
				auto_accepted += 1

	# Re-fetch queue after automatic acceptances and decline only the rest.
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		if auto_accepted > 0 and je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, %d offer(s) from your overlord were accepted automatically." % auto_accepted)
		return 0
	queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	count = queue.size()
	if count <= 0:
		if auto_accepted > 0 and je_lidsky_stat(player_clean):
			_pridej_popup_hraci(player_clean, "Diplomacy", "As a vassal, %d offer(s) from your overlord were accepted automatically." % auto_accepted)
		return 0

	queue.clear()
	if je_lidsky_stat(player_clean):
		if auto_accepted > 0:
			_pridej_popup_hraci(player_clean, "Diplomacy", "You declined %d request(s); %d overlord request(s) were accepted automatically." % [count, auto_accepted])
		else:
			_pridej_popup_hraci(player_clean, "Diplomacy", "You declined all pending diplomatic requests (%d)." % count)
	return count

func hrac_prijmi_vsechny_diplomaticke_zadosti(hrac_tag: String) -> int:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0

	var queue_copy = (cekajici_diplomaticke_zadosti[player_clean] as Array).duplicate(true)
	if queue_copy.is_empty():
		return 0

	var accepted := 0
	for req in queue_copy:
		var from_tag = _normalizuj_tag(str((req as Dictionary).get("from", "")))
		if from_tag == "":
			continue
		if hrac_prijmi_diplomatickou_zadost(player_clean, from_tag):
			accepted += 1

	if accepted > 0 and je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacy", "You accepted pending diplomatic requests (%d)." % accepted)
	return accepted

# Diplomacy helpers
func jsou_ve_valce(tag1: String, tag2: String) -> bool:
	var klic1 = tag1 + "_" + tag2
	var klic2 = tag2 + "_" + tag1
	return valky.has(klic1) or valky.has(klic2)

func vycisti_stat_po_kapitulaci(tag: String):
	var target = tag.strip_edges().to_upper()
	if target == "":
		return
	_presun_hlavniho_mesta_posledni_kolo.erase(target)

	var valky_klice = valky.keys().duplicate()
	for klic in valky_klice:
		var txt = str(klic)
		if txt.begins_with(target + "_") or txt.ends_with("_" + target):
			valky.erase(klic)

	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		var obr = str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper()
		var uto = str(cekajici_kapitulace[i].get("utocnik", "")).strip_edges().to_upper()
		if obr == target or uto == target:
			cekajici_kapitulace.remove_at(i)

	for i in range(cekajici_mirove_nabidky.size() - 1, -1, -1):
		var from_tag = str(cekajici_mirove_nabidky[i].get("from", "")).strip_edges().to_upper()
		var to_tag = str(cekajici_mirove_nabidky[i].get("to", "")).strip_edges().to_upper()
		if from_tag == target or to_tag == target:
			cekajici_mirove_nabidky.remove_at(i)

	var aliance_klice = aliance_statu.keys().duplicate()
	for klic in aliance_klice:
		var parts = str(klic).split("|")
		if parts.size() != 2:
			continue
		if parts[0] == target or parts[1] == target:
			aliance_statu.erase(klic)

	# Remove defeated state from alliance groups
	for aid in aliance_skupiny.keys().duplicate():
		var skupina = aliance_skupiny[aid] as Dictionary
		var members = (skupina.get("members", []) as Array)
		if members.has(target):
			members.erase(target)
			if members.size() < 2:
				aliance_skupiny.erase(aid)
			else:
				skupina["members"] = members
				aliance_skupiny[aid] = skupina

	var smlouvy_klice = neagresivni_smlouvy.keys().duplicate()
	for klic in smlouvy_klice:
		var parts2 = str(klic).split("|")
		if parts2.size() != 2:
			continue
		if parts2[0] == target or parts2[1] == target:
			neagresivni_smlouvy.erase(klic)

	var cooldown_klice = povalecne_cooldowny.keys().duplicate()
	for klic in cooldown_klice:
		var parts_c = str(klic).split("|")
		if parts_c.size() != 2:
			continue
		if parts_c[0] == target or parts_c[1] == target:
			povalecne_cooldowny.erase(klic)

	var zadosti_klice = cekajici_diplomaticke_zadosti.keys().duplicate()
	for receiver in zadosti_klice:
		var receiver_tag = _normalizuj_tag(str(receiver))
		if receiver_tag == target:
			cekajici_diplomaticke_zadosti.erase(receiver)
			continue
		var queue = cekajici_diplomaticke_zadosti[receiver] as Array
		for i in range(queue.size() - 1, -1, -1):
			var from_tag3 = _normalizuj_tag(str(queue[i].get("from", "")))
			if from_tag3 == target:
				queue.remove_at(i)

	for i in range(cekajici_aliancni_zadosti.size() - 1, -1, -1):
		var req = cekajici_aliancni_zadosti[i]
		var from_tag4 = _normalizuj_tag(str(req.get("from", "")))
		var to_tag4 = _normalizuj_tag(str(req.get("to", "")))
		if from_tag4 == target or to_tag4 == target:
			cekajici_aliancni_zadosti.remove_at(i)

	for subject_any in vazalske_vztahy.keys().duplicate():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == target or overlord == target:
			vazalske_vztahy.erase(subject_any)
			vazalske_odvody.erase(subject)

	for i in range(valecne_reparace.size() - 1, -1, -1):
		var rep = valecne_reparace[i] as Dictionary
		var from_tag_rep = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag_rep = _normalizuj_tag(str(rep.get("to", "")))
		if from_tag_rep == target or to_tag_rep == target:
			valecne_reparace.remove_at(i)

	for key_any in cekajici_mirove_konference.keys().duplicate():
		var queue = cekajici_mirove_konference[key_any] as Array
		for i in range(queue.size() - 1, -1, -1):
			var conf = queue[i] as Dictionary
			var winner = _normalizuj_tag(str(conf.get("winner", "")))
			var loser = _normalizuj_tag(str(conf.get("loser", "")))
			if winner == target or loser == target:
				queue.remove_at(i)
		if queue.is_empty():
			cekajici_mirove_konference.erase(key_any)

	ai_kasy.erase(target)
	_core_state_cache.erase(target)

func _vyhlasit_valku_par(utocnik: String, obrance: String, headline: String, details: String) -> bool:
	var a = _normalizuj_tag(utocnik)
	var b = _normalizuj_tag(obrance)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	if jsou_ve_valce(a, b):
		return false

	var klic = a + "_" + b
	valky[klic] = true

	var msg = "%s\n\n%s" % [headline, details]
	if TURN_LOG_ENABLED:
		print(msg.replace("\n\n", " "))
	_zaloguj_globalni_zpravu("War", "%s declared war on %s." % [a, b], "war")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, "DIPLOMACY", msg)
	var old_suppress_logs = _suppress_relation_global_logs
	_suppress_relation_global_logs = _suppress_relation_global_logs or _ai_phase_cache_active
	_aplikuj_diplomatickou_reakci_na_agresi(a, b)
	_suppress_relation_global_logs = old_suppress_logs

	var alliance_level = _ziskej_uroven_aliance_ai_cached(a, b) if _ai_phase_cache_active else ziskej_uroven_aliance(a, b)
	if alliance_level > ALLIANCE_NONE:
		_nastav_uroven_aliance_bez_kontroly(a, b, ALLIANCE_NONE)
	return true

func _aplikuj_diplomatickou_reakci_na_agresi(utocnik: String, obrance: String) -> void:
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "" or attacker == defender:
		return
	_nacti_vztahy_statu()

	var reakce_na_hrace: Dictionary = {}
	var reakce_na_utocnika: Array = []
	var use_ai_cache = _ai_phase_cache_active
	var active_states = _turn_active_states if _turn_cache_valid else _ziskej_aktivni_staty()

	for stat in active_states:
		var observer = _normalizuj_tag(str(stat))
		if observer == "" or observer == "SEA":
			continue
		if observer == attacker or observer == defender:
			continue
		var observer_vs_defender_war = _jsou_ve_valce_ai_cached(observer, defender) if use_ai_cache else jsou_ve_valce(observer, defender)
		if observer_vs_defender_war:
			continue

		var rel_to_defender = _ziskej_ai_vztah_cached(observer, defender) if use_ai_cache else ziskej_vztah_statu(observer, defender)
		if rel_to_defender < AI_FRIEND_RELATION_THRESHOLD:
			continue

		var old_rel_to_attacker = _ziskej_ai_vztah_cached(observer, attacker) if use_ai_cache else ziskej_vztah_statu(observer, attacker)
		if old_rel_to_attacker <= RELATION_MIN + 0.001:
			continue
		var new_rel_to_attacker = _uprav_vztah_statu_bez_cooldown_rychle(observer, attacker, -AGGRESSION_RELATION_PENALTY) if use_ai_cache else _uprav_vztah_statu_bez_cooldown(observer, attacker, -AGGRESSION_RELATION_PENALTY)
		if new_rel_to_attacker >= old_rel_to_attacker:
			continue

		if je_lidsky_stat(observer):
			if not reakce_na_hrace.has(observer):
				reakce_na_hrace[observer] = []
			(reakce_na_hrace[observer] as Array).append("Because of %s aggression against %s, your relation with %s dropped to %.1f." % [attacker, defender, attacker, new_rel_to_attacker])

		if je_lidsky_stat(attacker):
			reakce_na_utocnika.append("%s worsened its relation to you (now %.1f) because you attacked %s." % [observer, new_rel_to_attacker, defender])

	for target_tag in reakce_na_hrace.keys():
		var lines = reakce_na_hrace[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacy", "\n".join(lines))

	if je_lidsky_stat(attacker) and not reakce_na_utocnika.is_empty():
		_pridej_popup_hraci(attacker, "Diplomacy", "\n".join(reakce_na_utocnika))

func _ma_byt_spojenec_povolan(state_tag: String, ally_tag: String, enemy_tag: String, min_alliance_level: int) -> bool:
	if state_tag == "" or ally_tag == "" or enemy_tag == "":
		return false
	if state_tag == ally_tag or state_tag == enemy_tag or ally_tag == enemy_tag:
		return false
	if ally_tag == "SEA":
		return false
	var alliance_state_ally = _ziskej_uroven_aliance_ai_cached(state_tag, ally_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(state_tag, ally_tag)
	if alliance_state_ally < min_alliance_level:
		return false
	var ally_vs_state_war = _jsou_ve_valce_ai_cached(ally_tag, state_tag) if _ai_phase_cache_active else jsou_ve_valce(ally_tag, state_tag)
	if ally_vs_state_war:
		return false
	var ally_vs_enemy_war = _jsou_ve_valce_ai_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else jsou_ve_valce(ally_tag, enemy_tag)
	if ally_vs_enemy_war:
		return false

	var alliance_vs_enemy = _ziskej_uroven_aliance_ai_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(ally_tag, enemy_tag)
	var alliance_vs_state = _ziskej_uroven_aliance_ai_cached(ally_tag, state_tag) if _ai_phase_cache_active else ziskej_uroven_aliance(ally_tag, state_tag)
	if alliance_vs_enemy > alliance_vs_state:
		return false

	var rel_ally_enemy = _ziskej_ai_vztah_cached(ally_tag, enemy_tag) if _ai_phase_cache_active else ziskej_vztah_statu(ally_tag, enemy_tag)
	if rel_ally_enemy >= AI_FRIEND_RELATION_THRESHOLD:
		return false

	return true

func _aktivuj_aliance_po_vyhlaseni_valky(utocnik: String, obrance: String) -> void:
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "":
		return
	var use_ai_cache = _ai_phase_cache_active

	# Defensive call: defender's defense/full allies join against attacker.
	for ally in _ziskej_spojence_s_min_alianci(defender, ALLIANCE_DEFENSE):
		var ally_tag = _normalizuj_tag(str(ally))
		if _turn_cache_valid and not _turn_state_owned_provinces.has(ally_tag):
			continue
		if use_ai_cache and _jsou_ve_valce_ai_cached(ally_tag, attacker):
			continue
		if not _ma_byt_spojenec_povolan(defender, ally_tag, attacker, ALLIANCE_DEFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag,
			attacker,
			"DEFENSIVE ALLIANCE",
			"%s entered the war to defend ally %s against %s." % [ally_tag, defender, attacker]
		)

	# Offensive call: attacker's offense/full allies join against defender.
	for ally in _ziskej_spojence_s_min_alianci(attacker, ALLIANCE_OFFENSE):
		var ally_tag2 = _normalizuj_tag(str(ally))
		if _turn_cache_valid and not _turn_state_owned_provinces.has(ally_tag2):
			continue
		if use_ai_cache and _jsou_ve_valce_ai_cached(ally_tag2, defender):
			continue
		if not _ma_byt_spojenec_povolan(attacker, ally_tag2, defender, ALLIANCE_OFFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag2,
			defender,
			"OFFENSIVE ALLIANCE",
			"%s entered the war alongside ally %s against %s." % [ally_tag2, attacker, defender]
		)

func vyhlasit_valku(utocnik: String, obrance: String):
	var a = _normalizuj_tag(utocnik)
	var b = _normalizuj_tag(obrance)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	_begin_ai_cache_batch()
	if jsou_ve_valce(a, b):
		_end_ai_cache_batch()
		return false
	var zbyva_povalecny_cooldown = zbyva_kol_do_dalsi_valky(a, b)
	if zbyva_povalecny_cooldown > 0:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "After peace, you must wait %d more turns before declaring war on %s again." % [zbyva_povalecny_cooldown, b])
		_end_ai_cache_batch()
		return false
	if ma_neagresivni_smlouvu(a, b):
		if je_lidsky_stat(a):
			var zbyva = zbyva_kol_neagresivni_smlouvy(a, b)
			_pridej_popup_hraci(a, "Diplomacy", "Cannot declare war while non-aggression pact with %s is active (%d turns)." % [b, zbyva])
		_end_ai_cache_batch()
		return false

	if ziskej_uroven_aliance(a, b) > ALLIANCE_NONE:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacy", "Cannot declare war on ally (%s). Cancel the alliance first." % b)
		_end_ai_cache_batch()
		return false

	var created = _vyhlasit_valku_par(
		a,
		b,
		"WAR",
		"%s has declared war on %s!" % [a, b]
	)
	if not created:
		_end_ai_cache_batch()
		return false

	# Revoke any military access between the warring parties.
	odvolej_vojensky_pristup(a, b)
	odvolej_vojensky_pristup(b, a)

	_aktivuj_aliance_po_vyhlaseni_valky(a, b)
	_end_ai_cache_batch()
	return true

func nabidnout_mir(tag1: String, tag2: String):
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()

	if cisty_tag1 == "" or cisty_tag2 == "" or cisty_tag1 == cisty_tag2:
		return
	if not jsou_ve_valce(cisty_tag1, cisty_tag2):
		return
	if je_mirova_nabidka_cekajici(cisty_tag1, cisty_tag2):
		return

	if je_lidsky_stat(cisty_tag2):
		if _pridej_diplomatickou_zadost(cisty_tag1, cisty_tag2, "peace"):
			print("Peace request sent to player: %s -> %s" % [cisty_tag1, cisty_tag2])
		return

	cekajici_mirove_nabidky.append({
		"from": cisty_tag1,
		"to": cisty_tag2,
		"turn": aktualni_kolo
	})

	print("Peace offer sent: %s -> %s" % [cisty_tag1, cisty_tag2])

func je_mirova_nabidka_cekajici(odesilatel: String, prijemce: String) -> bool:
	var from_tag = odesilatel.strip_edges().to_upper()
	var to_tag = prijemce.strip_edges().to_upper()
	for nabidka in cekajici_mirove_nabidky:
		if str(nabidka.get("from", "")).strip_edges().to_upper() == from_tag and str(nabidka.get("to", "")).strip_edges().to_upper() == to_tag:
			return true
	if cekajici_diplomaticke_zadosti.has(to_tag):
		for req in (cekajici_diplomaticke_zadosti[to_tag] as Array):
			if _normalizuj_tag(str(req.get("from", ""))) != from_tag:
				continue
			if str(req.get("type", "")) != "peace":
				continue
			return true
	return false

func _uzavri_mir_mezi(tag1: String, tag2: String, prepis_okupace: bool = true):
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()
	var klic1 = cisty_tag1 + "_" + cisty_tag2
	var klic2 = cisty_tag2 + "_" + cisty_tag1
	_zaloguj_globalni_zpravu("War", "%s and %s made peace." % [cisty_tag1, cisty_tag2], "war")

	valky.erase(klic1)
	valky.erase(klic2)
	_nastav_povalecny_cooldown(cisty_tag1, cisty_tag2)
	if prepis_okupace:
		_prepis_okupace_po_miru(cisty_tag1, cisty_tag2)
	_expeluj_jednotky_bez_pristupu()

	for i in range(cekajici_kapitulace.size() - 1, -1, -1):
		var obr = str(cekajici_kapitulace[i].get("obrance", "")).strip_edges().to_upper()
		var uto = str(cekajici_kapitulace[i].get("utocnik", "")).strip_edges().to_upper()
		var stejna_dvojice = (obr == cisty_tag1 and uto == cisty_tag2) or (obr == cisty_tag2 and uto == cisty_tag1)
		if stejna_dvojice:
			cekajici_kapitulace.remove_at(i)

	for i in range(cekajici_mirove_nabidky.size() - 1, -1, -1):
		var from_tag = str(cekajici_mirove_nabidky[i].get("from", "")).strip_edges().to_upper()
		var to_tag = str(cekajici_mirove_nabidky[i].get("to", "")).strip_edges().to_upper()
		var stejna_dvojice_mir = (from_tag == cisty_tag1 and to_tag == cisty_tag2) or (from_tag == cisty_tag2 and to_tag == cisty_tag1)
		if stejna_dvojice_mir:
			cekajici_mirove_nabidky.remove_at(i)

func _vycisti_expirovane_povalecne_cooldowny() -> void:
	var keys = povalecne_cooldowny.keys().duplicate()
	for k in keys:
		var expiry_turn = int(povalecne_cooldowny.get(k, -1))
		if expiry_turn < aktualni_kolo:
			povalecne_cooldowny.erase(k)

func _nastav_povalecny_cooldown(tag_a: String, tag_b: String) -> void:
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return
	povalecne_cooldowny[key] = aktualni_kolo + PEACE_WAR_COOLDOWN_TURNS - 1

func zbyva_kol_do_dalsi_valky(tag_a: String, tag_b: String) -> int:
	_vycisti_expirovane_povalecne_cooldowny()
	var key = _klic_pair(tag_a, tag_b)
	if key == "" or not povalecne_cooldowny.has(key):
		return 0
	var expiry_turn = int(povalecne_cooldowny[key])
	return max(0, expiry_turn - aktualni_kolo + 1)

func _prepis_okupace_po_miru(tag_a: String, tag_b: String) -> void:
	if map_data.is_empty():
		return

	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return

	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
		if owner_tag == a and core_owner == b:
			d["core_owner"] = a
		elif owner_tag == b and core_owner == a:
			d["core_owner"] = b

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()

func _ma_aktivni_tlak_na_kapitulaci(obrance: String, utocnik: String) -> bool:
	var obr_tag = obrance.strip_edges().to_upper()
	var uto_tag = utocnik.strip_edges().to_upper()
	for zaznam in cekajici_kapitulace:
		if str(zaznam.get("obrance", "")).strip_edges().to_upper() == obr_tag and str(zaznam.get("utocnik", "")).strip_edges().to_upper() == uto_tag:
			return true
	return false

func _ma_stat_cekajici_kapitulaci(state_tag: String) -> bool:
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return false
	for zaznam in cekajici_kapitulace:
		if _normalizuj_tag(str(zaznam.get("obrance", ""))) == wanted:
			return true
	return false

func _ziskej_statove_provincie(owner_tag: String) -> Array:
	var owner_clean = _normalizuj_tag(owner_tag)
	var out: Array = []
	if owner_clean == "" or owner_clean == "SEA":
		return out
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) == owner_clean:
			out.append(int(p_id))
	return out

func _je_mirova_provincie_porazeneho(vitez_tag: String, porazeny_tag: String, d: Dictionary) -> bool:
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "":
		return false
	var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
	if owner_tag == "SEA":
		return false
	var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
	if owner_tag == loser:
		return true
	if owner_tag == winner and core_owner == loser:
		return true
	return false

func _ziskej_mirove_provincie_porazeneho(vitez_tag: String, porazeny_tag: String) -> Array:
	var out: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if _je_mirova_provincie_porazeneho(vitez_tag, porazeny_tag, d):
			out.append(int(p_id))
	return out

func _ziskej_potencialni_mirove_provincie_dle_losera(porazeny_tag: String) -> Array:
	var loser = _normalizuj_tag(porazeny_tag)
	var out: Array = []
	if loser == "":
		return out
	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = _normalizuj_tag(str(d.get("owner", "")))
		if owner_tag == "SEA":
			continue
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_tag)))
		if owner_tag == loser or core_owner == loser:
			out.append(int(p_id))
	return out

func _spocitej_body_mirove_konference(vitez_tag: String, porazeny_tag: String, reason: String = "") -> int:
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	if vitez == "" or porazeny == "" or vitez == porazeny:
		return 0

	var occupied_cores := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != vitez:
			continue
		if _normalizuj_tag(str(d.get("core_owner", ""))) == porazeny:
			occupied_cores += 1

	var body = PEACE_POINTS_BASE + (occupied_cores * PEACE_POINTS_PER_OCCUPIED_CORE)
	var porazeny_capital = _ziskej_hlavni_mesto_statu(porazeny)
	if porazeny_capital > 0 and map_data.has(porazeny_capital):
		if _normalizuj_tag(str(map_data[porazeny_capital].get("owner", ""))) == vitez:
			body += PEACE_POINTS_CAPITAL_BONUS

	if reason == "capitulation":
		body += 10

	var sila_vitez = ziskej_silu_armady_statu(vitez) as Dictionary
	var sila_porazeny = ziskej_silu_armady_statu(porazeny) as Dictionary
	var v_total = int(sila_vitez.get("total", 0))
	var p_total = int(sila_porazeny.get("total", 0))
	if v_total > p_total:
		body += min(25, int(round(float(v_total - p_total) / 1200.0)))

	return max(12, body)

func _spocitej_cenu_mirovych_pozadavku(porazeny_tag: String, provinces_to_take: int, annex_all: bool, make_vassal: bool, reparations_turns: int) -> int:
	var loser = _normalizuj_tag(porazeny_tag)
	var loser_provinces = _ziskej_potencialni_mirove_provincie_dle_losera(loser)
	var max_take = min(provinces_to_take, loser_provinces.size())
	var cost := 0
	if annex_all:
		cost += PEACE_COST_ANNEX_BASE + (loser_provinces.size() * PEACE_COST_PROVINCE)
	else:
		cost += max_take * PEACE_COST_PROVINCE
	if make_vassal:
		cost += PEACE_COST_VASSAL
	var clamped_turns = clampi(reparations_turns, 0, PEACE_MAX_REPARATIONS_TURNS)
	cost += clamped_turns * PEACE_COST_REPARATIONS_PER_TURN
	return max(0, cost)

func spocitej_cenu_mirovych_pozadavku(porazeny_tag: String, provinces_to_take: int, annex_all: bool, make_vassal: bool, reparations_turns: int) -> int:
	return _spocitej_cenu_mirovych_pozadavku(porazeny_tag, provinces_to_take, annex_all, make_vassal, reparations_turns)

func _ziskej_profile_statu_pro_mir(tag: String) -> Dictionary:
	var wanted = _normalizuj_tag(tag)
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != wanted:
			continue
		return {
			"country_name": str(d.get("country_name", wanted)),
			"ideology": str(d.get("ideology", ""))
		}
	# Fallback when the state has no currently owned land (fully occupied),
	# but still has core provinces on map.
	for p_id2 in map_data:
		var d2 = map_data[p_id2]
		if _normalizuj_tag(str(d2.get("core_owner", ""))) != wanted:
			continue
		return {
			"country_name": str(d2.get("country_name", wanted)),
			"ideology": str(d2.get("ideology", ""))
		}
	return {
		"country_name": wanted,
		"ideology": ""
	}

func _obnov_okupovana_uzemi_porazeneho(vitez_tag: String, porazeny_tag: String) -> int:
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "" or winner == loser:
		return 0

	var loser_profile = _ziskej_profile_statu_pro_mir(loser)
	var restored := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(winner, loser, d):
			continue
		if _normalizuj_tag(str(d.get("owner", ""))) == loser:
			continue
		d["owner"] = loser
		d["core_owner"] = loser
		d["country_name"] = str(loser_profile.get("country_name", loser))
		d["ideology"] = str(loser_profile.get("ideology", ""))
		d["army_owner"] = loser if int(d.get("soldiers", 0)) > 0 else ""
		restored += 1

	return restored

func _anektuj_cely_stat(vitez_tag: String, porazeny_tag: String) -> Dictionary:
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	var prevedeno := 0
	var profile = _ziskej_profile_statu_pro_mir(vitez)
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		prevedeno += 1

	# Ensure the winner has exactly one capital.
	var winner_capital = _ziskej_hlavni_mesto_statu(vitez)
	if winner_capital <= 0:
		var provinces = _ziskej_statove_provincie(vitez)
		if not provinces.is_empty() and map_data.has(int(provinces[0])):
			map_data[int(provinces[0])]["is_capital"] = true

	return {"transferred": prevedeno}

func _vezmi_cast_provincii(vitez_tag: String, porazeny_tag: String, count: int) -> Dictionary:
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	var wanted = max(0, count)
	if wanted <= 0:
		return {"transferred": 0}

	var candidates: Array = []
	for p_id in map_data:
		var d = map_data[p_id]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		var score = float(d.get("gdp", 0.0)) * 1000.0 + float(d.get("population", 0))
		if bool(d.get("is_capital", false)):
			score += 5000000.0
		candidates.append({"id": int(p_id), "score": score})

	candidates.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	var profile = _ziskej_profile_statu_pro_mir(vitez)
	var transferred := 0
	for row_any in candidates:
		if transferred >= wanted:
			break
		var row = row_any as Dictionary
		var pid = int(row.get("id", -1))
		if pid < 0 or not map_data.has(pid):
			continue
		var d = map_data[pid]
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		transferred += 1

	return {"transferred": transferred}

func _vezmi_konkretni_provincie(vitez_tag: String, porazeny_tag: String, selected_ids: Array) -> Dictionary:
	var vitez = _normalizuj_tag(vitez_tag)
	var porazeny = _normalizuj_tag(porazeny_tag)
	if selected_ids.is_empty():
		return {"transferred": 0}

	var profile = _ziskej_profile_statu_pro_mir(vitez)
	var transferred := 0
	for raw_id in selected_ids:
		var pid = int(raw_id)
		if not map_data.has(pid):
			continue
		var d = map_data[pid]
		if not _je_mirova_provincie_porazeneho(vitez, porazeny, d):
			continue
		d["owner"] = vitez
		d["core_owner"] = vitez
		d["country_name"] = str(profile.get("country_name", vitez))
		d["ideology"] = str(profile.get("ideology", ""))
		d["army_owner"] = vitez if int(d.get("soldiers", 0)) > 0 else ""
		if bool(d.get("is_capital", false)):
			d["is_capital"] = false
		transferred += 1

	return {"transferred": transferred}

func _nastav_vazala(overlord_tag: String, subject_tag: String) -> void:
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "" or overlord == subject:
		return
	vazalske_vztahy[subject] = overlord
	vazalske_odvody[subject] = float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE))
	_uprav_vztah_statu_bez_cooldown(overlord, subject, 35.0)
	nastav_uroven_aliance(overlord, subject, ALLIANCE_FULL, true)
	if not ma_neagresivni_smlouvu(overlord, subject):
		uzavrit_neagresivni_smlouvu(overlord, subject)

func _uzavri_valky_statu_krome(state_tag: String, except_tags: Array = []) -> void:
	var state = _normalizuj_tag(state_tag)
	if state == "":
		return

	var ignore: Dictionary = {}
	for raw in except_tags:
		var tag = _normalizuj_tag(str(raw))
		if tag != "":
			ignore[tag] = true

	var enemies: Array = []
	for key_any in valky.keys():
		var key = str(key_any)
		var sep = key.find("_")
		if sep <= 0 or sep >= key.length() - 1:
			continue
		var a = _normalizuj_tag(key.substr(0, sep))
		var b = _normalizuj_tag(key.substr(sep + 1))
		if a == state and b != "" and not enemies.has(b):
			enemies.append(b)
		elif b == state and a != "" and not enemies.has(a):
			enemies.append(a)

	for enemy_any in enemies:
		var enemy = _normalizuj_tag(str(enemy_any))
		if enemy == "" or ignore.has(enemy):
			continue
		_uzavri_mir_mezi(state, enemy, true)

func _pridej_valecne_reparace(from_tag: String, to_tag: String, turns: int) -> void:
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	var t = clampi(turns, 0, PEACE_MAX_REPARATIONS_TURNS)
	if from_clean == "" or to_clean == "" or from_clean == to_clean or t <= 0:
		return
	valecne_reparace.append({
		"from": from_clean,
		"to": to_clean,
		"remaining_turns": t,
		"rate": WAR_REPARATIONS_RATE
	})

func _spocitej_cisty_prijem_statu(tag: String) -> float:
	var state = _normalizuj_tag(tag)
	if state == "" or state == "SEA":
		return 0.0
	var hdp := 0.0
	var soldiers := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		hdp += float(d.get("gdp", 0.0))
		soldiers += int(d.get("soldiers", 0))
	var income_rate = ziskej_prijmovou_sazbu_hdp(state)
	var upkeep = ziskej_udrzbu_za_vojaka(state)
	return (hdp * income_rate) - (float(soldiers) * upkeep)

func ziskej_cisty_prijem_statu(tag: String) -> float:
	return _spocitej_cisty_prijem_statu(tag)

func ziskej_financni_rozpad_statu(state_tag: String = "") -> Dictionary:
	var state = _normalizuj_tag(state_tag)
	if state == "":
		state = _normalizuj_tag(hrac_stat)
	if state == "" or state == "SEA":
		return {
			"ok": false,
			"reason": "Invalid state."
		}

	var celkove_hdp := 0.0
	var celkem_vojaku := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if _normalizuj_tag(str(d.get("owner", ""))) != state:
			continue
		celkove_hdp += float(d.get("gdp", 0.0))
		celkem_vojaku += int(d.get("soldiers", 0))

	var prijmova_sazba = ziskej_prijmovou_sazbu_hdp(state)
	var upkeep_za_vojaka = ziskej_udrzbu_za_vojaka(state)
	var prijem_hdp = celkove_hdp * prijmova_sazba
	var vydaj_armada = float(celkem_vojaku) * upkeep_za_vojaka

	var prijem_vazalove := 0.0
	var vydaj_vazalsky_odvod := 0.0
	for subject_any in vazalske_vztahy.keys():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or overlord == "":
			continue

		if overlord == state:
			var rate_in = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
			var subject_income = max(0.0, _spocitej_cisty_prijem_statu(subject))
			var planned_in = subject_income * rate_in
			if planned_in > 0.0:
				var subject_cash = _ziskej_kasu_statu(subject)
				prijem_vazalove += clamp(planned_in, 0.0, max(0.0, subject_cash))

		if subject == state:
			var rate_out = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
			var own_income = max(0.0, _spocitej_cisty_prijem_statu(subject))
			var planned_out = own_income * rate_out
			if planned_out > 0.0:
				var own_cash = _ziskej_kasu_statu(subject)
				vydaj_vazalsky_odvod += clamp(planned_out, 0.0, max(0.0, own_cash))

	var prijem_reparace := 0.0
	var vydaj_reparace := 0.0
	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if remaining <= 0 or from_tag == "" or to_tag == "":
			continue

		if from_tag != state and to_tag != state:
			continue

		var rate = clamp(float(rep.get("rate", WAR_REPARATIONS_RATE)), 0.01, 0.50)
		var base_income = max(0.0, _spocitej_cisty_prijem_statu(from_tag))
		var planned = max(WAR_REPARATIONS_MIN_PAYMENT, base_income * rate)
		var from_cash = _ziskej_kasu_statu(from_tag)
		var paid = clamp(planned, 0.0, max(0.0, from_cash + 100.0))
		if to_tag == state:
			prijem_reparace += paid
		if from_tag == state:
			vydaj_reparace += paid

	var prijem_ostatni := 0.0
	var vydaj_investice := 0.0
	var vydaj_ostatni := vydaj_vazalsky_odvod + vydaj_reparace

	var celkove_prijmy = prijem_hdp + prijem_vazalove + prijem_reparace + prijem_ostatni
	var celkove_vydaje = vydaj_armada + vydaj_investice + vydaj_ostatni
	var profit = celkove_prijmy - celkove_vydaje

	return {
		"ok": true,
		"state": state,
		"income": {
			"gdp": prijem_hdp,
			"vassals": prijem_vazalove,
			"reparations": prijem_reparace,
			"other": prijem_ostatni,
			"total": celkove_prijmy
		},
		"expenses": {
			"army_upkeep": vydaj_armada,
			"investments": vydaj_investice,
			"other": vydaj_ostatni,
			"total": celkove_vydaje
		},
		"profit": profit,
		"cash": _ziskej_kasu_statu(state),
		"base_net_income": (prijem_hdp - vydaj_armada),
		"projected_net_income": profit
	}

func ziskej_vazalsky_odvod(overlord_tag: String, subject_tag: String) -> float:
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return 0.0
	if ziskej_overlorda_statu(subject) != overlord:
		return 0.0
	var rate = float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE))
	return clamp(rate, VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)

func nastav_vazalsky_odvod(overlord_tag: String, subject_tag: String, procenta: float) -> bool:
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return false
	if ziskej_overlorda_statu(subject) != overlord:
		return false
	var rate = clamp(float(procenta) / 100.0, VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
	var current_rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
	if is_equal_approx(current_rate, rate):
		return true
	if ziskej_zbyvajici_cooldown_vazalskeho_odvodu(overlord, subject) > 0:
		return false
	vazalske_odvody[subject] = rate
	vazalske_odvody_posledni_zmena_kolo[subject] = aktualni_kolo
	return true

func ziskej_zbyvajici_cooldown_vazalskeho_odvodu(overlord_tag: String, subject_tag: String) -> int:
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "":
		return 0
	if ziskej_overlorda_statu(subject) != overlord:
		return 0
	var last_turn = int(vazalske_odvody_posledni_zmena_kolo.get(subject, -1000000))
	if last_turn < 0:
		return 0
	var turns_passed = max(0, aktualni_kolo - last_turn)
	return maxi(0, VASSAL_TRIBUTE_CHANGE_COOLDOWN_TURNS - turns_passed)

func _zpracuj_vazalske_odvody_za_kolo() -> void:
	if vazalske_vztahy.is_empty():
		return
	for subject_any in vazalske_vztahy.keys().duplicate():
		var subject = _normalizuj_tag(str(subject_any))
		var overlord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or overlord == "" or subject == overlord:
			continue
		if not _stat_existuje(subject) or not _stat_existuje(overlord):
			continue

		var rate = clamp(float(vazalske_odvody.get(subject, VASSAL_TRIBUTE_DEFAULT_RATE)), VASSAL_TRIBUTE_MIN_RATE, VASSAL_TRIBUTE_MAX_RATE)
		var subject_income = max(0.0, _spocitej_cisty_prijem_statu(subject))
		var planned = subject_income * rate
		if planned <= 0.0:
			continue
		var subject_cash = _ziskej_kasu_statu(subject)
		var paid = clamp(planned, 0.0, max(0.0, subject_cash))
		if paid <= 0.0:
			continue
		_nastav_kasu_statu(subject, subject_cash - paid)
		_nastav_kasu_statu(overlord, _ziskej_kasu_statu(overlord) + paid)

func _zpracuj_valecne_reparace_za_kolo() -> void:
	if valecne_reparace.is_empty():
		return

	var active: Array = []
	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if from_tag == "" or to_tag == "" or from_tag == to_tag or remaining <= 0:
			continue
		if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
			continue

		var rate = clamp(float(rep.get("rate", WAR_REPARATIONS_RATE)), 0.01, 0.50)
		var base_income = max(0.0, _spocitej_cisty_prijem_statu(from_tag))
		var planned = max(WAR_REPARATIONS_MIN_PAYMENT, base_income * rate)
		var from_cash = _ziskej_kasu_statu(from_tag)
		var paid = clamp(planned, 0.0, max(0.0, from_cash + 100.0))
		if paid > 0.0:
			_nastav_kasu_statu(from_tag, from_cash - paid)
			_nastav_kasu_statu(to_tag, _ziskej_kasu_statu(to_tag) + paid)

		rep["remaining_turns"] = remaining - 1
		if int(rep.get("remaining_turns", 0)) > 0:
			active.append(rep)

	valecne_reparace = active

func _odstran_neplatne_mirove_konference() -> void:
	var keys = cekajici_mirove_konference.keys().duplicate()
	for k in keys:
		var player_tag = _normalizuj_tag(str(k))
		if player_tag == "" or not cekajici_mirove_konference.has(k):
			cekajici_mirove_konference.erase(k)
			continue
		var queue = cekajici_mirove_konference[k] as Array
		for i in range(queue.size() - 1, -1, -1):
			var item = queue[i] as Dictionary
			var winner = _normalizuj_tag(str(item.get("winner", "")))
			var loser = _normalizuj_tag(str(item.get("loser", "")))
			if winner == "" or loser == "" or winner == loser:
				queue.remove_at(i)
				continue
			if not _stat_existuje(winner) and not _stat_existuje(loser):
				queue.remove_at(i)
		if queue.is_empty():
			cekajici_mirove_konference.erase(k)

func _vytvor_mirovou_konferenci(vitez_tag: String, porazeny_tag: String, reason: String = "peace") -> Dictionary:
	var winner = _normalizuj_tag(vitez_tag)
	var loser = _normalizuj_tag(porazeny_tag)
	if winner == "" or loser == "" or winner == loser:
		return {}

	mirove_konference_seq += 1
	var points = _spocitej_body_mirove_konference(winner, loser, reason)
	var loser_provinces = _ziskej_mirove_provincie_porazeneho(winner, loser)
	return {
		"id": mirove_konference_seq,
		"winner": winner,
		"loser": loser,
		"reason": reason,
		"points": points,
		"loser_province_count": loser_provinces.size(),
		"max_reparations_turns": PEACE_MAX_REPARATIONS_TURNS
	}

func _auto_navrh_mirovych_podminek(conf: Dictionary) -> Dictionary:
	var points = int(conf.get("points", 0))
	var loser_count = int(conf.get("loser_province_count", 0))
	var take_count = min(loser_count, int(points / max(1, PEACE_COST_PROVINCE)))
	var annex_cost = _spocitej_cenu_mirovych_pozadavku(str(conf.get("loser", "")), 0, true, false, 0)
	var annex_all = points >= annex_cost and loser_count <= 7
	var vassal = (not annex_all) and points >= (PEACE_COST_VASSAL + PEACE_COST_PROVINCE)
	var remaining = max(0, points - _spocitej_cenu_mirovych_pozadavku(str(conf.get("loser", "")), take_count if not annex_all else 0, annex_all, vassal, 0))
	var repar_turns = min(PEACE_MAX_REPARATIONS_TURNS, int(remaining / max(1, PEACE_COST_REPARATIONS_PER_TURN)))
	return {
		"take_provinces": 0 if annex_all else take_count,
		"annex_all": annex_all,
		"make_vassal": vassal,
		"reparations_turns": repar_turns
	}

func _proved_mirovou_konferenci(conf: Dictionary, demands: Dictionary) -> Dictionary:
	var winner = _normalizuj_tag(str(conf.get("winner", "")))
	var loser = _normalizuj_tag(str(conf.get("loser", "")))
	if winner == "" or loser == "" or winner == loser:
		return {"ok": false, "reason": "Invalid peace conference."}

	var points = int(conf.get("points", 0))
	var annex_all = bool(demands.get("annex_all", false))
	var take_count = int(demands.get("take_provinces", 0))
	var selected_raw = (demands.get("selected_provinces", []) as Array).duplicate()
	var selected_provinces: Array = []
	for raw_id in selected_raw:
		var pid = int(raw_id)
		if not map_data.has(pid):
			continue
		if selected_provinces.has(pid):
			continue
		var pd = map_data[pid]
		if not _je_mirova_provincie_porazeneho(winner, loser, pd):
			continue
		selected_provinces.append(pid)
	var make_vassal = bool(demands.get("make_vassal", false))
	var repar_turns = int(demands.get("reparations_turns", 0))
	if not annex_all and not selected_provinces.is_empty():
		take_count = selected_provinces.size()

	var cost = _spocitej_cenu_mirovych_pozadavku(loser, take_count, annex_all, make_vassal, repar_turns)
	if cost > points:
		return {"ok": false, "reason": "Not enough conference points.", "cost": cost, "points": points}

	var transferred := 0
	if annex_all:
		var annex_result = _anektuj_cely_stat(winner, loser)
		transferred = int(annex_result.get("transferred", 0))
	else:
		# Return occupied provinces to the loser first, then apply exact player demands.
		# This allows shaping peace terms (including giving back occupied capital).
		_obnov_okupovana_uzemi_porazeneho(winner, loser)
		var partial_result: Dictionary
		if not selected_provinces.is_empty():
			partial_result = _vezmi_konkretni_provincie(winner, loser, selected_provinces)
		else:
			partial_result = _vezmi_cast_provincii(winner, loser, take_count)
		transferred = int(partial_result.get("transferred", 0))

	if make_vassal and _stat_existuje(loser):
		_nastav_vazala(winner, loser)
		# Protectorate outcome: third-party wars against the new vassal must stop.
		_uzavri_valky_statu_krome(loser, [winner])
		var map_loader_after_vassal = _get_map_loader()
		if map_loader_after_vassal and map_loader_after_vassal.has_method("zrus_cekajici_utoky_na_stat"):
			map_loader_after_vassal.zrus_cekajici_utoky_na_stat(loser)
	if repar_turns > 0 and _stat_existuje(loser):
		_pridej_valecne_reparace(loser, winner, repar_turns)

	if not _stat_existuje(loser):
		vycisti_stat_po_kapitulaci(loser)

	var map_loader = _get_map_loader()
	if map_loader:
		if "provinces" in map_loader:
			map_loader.provinces = map_data
		if map_loader.has_method("_aktualizuj_aktivni_mapovy_mod"):
			map_loader._aktualizuj_aktivni_mapovy_mod()
		if map_loader.has_method("aktualizuj_ikony_armad"):
			map_loader.aktualizuj_ikony_armad()

	_invalidate_turn_cache()
	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
	kolo_zmeneno.emit()

	var msg = "%s used peace points against %s (cost %d/%d)." % [winner, loser, cost, points]
	_zaloguj_globalni_zpravu("War", msg, "war")
	return {
		"ok": true,
		"winner": winner,
		"loser": loser,
		"points": points,
		"cost": cost,
		"transferred": transferred,
		"annex_all": annex_all,
		"make_vassal": make_vassal,
		"reparations_turns": repar_turns
	}

func uzavri_mir_a_zahaj_konferenci(tag1: String, tag2: String, reason: String = "peace") -> Dictionary:
	var a = _normalizuj_tag(tag1)
	var b = _normalizuj_tag(tag2)
	if a == "" or b == "" or a == b:
		return {"ok": false, "reason": "Invalid states."}

	var conf_a = _vytvor_mirovou_konferenci(a, b, reason)
	var conf_b = _vytvor_mirovou_konferenci(b, a, reason)
	# Keep occupation/core state intact until conference demands are finalized,
	# so the winner can return occupied land (including captured capitals).
	_uzavri_mir_mezi(a, b, false)
	var winner_conf = conf_a if int(conf_a.get("points", 0)) >= int(conf_b.get("points", 0)) else conf_b
	if winner_conf.is_empty():
		return {"ok": false, "reason": "Failed to prepare peace conference."}

	var winner = _normalizuj_tag(str(winner_conf.get("winner", "")))
	if je_lidsky_stat(winner):
		if not cekajici_mirove_konference.has(winner):
			cekajici_mirove_konference[winner] = []
		(cekajici_mirove_konference[winner] as Array).append(winner_conf)
		_pridej_popup_hraci(winner, "Peace Conference", "After the war with %s, you can set demands (points: %d)." % [str(winner_conf.get("loser", "?")), int(winner_conf.get("points", 0))])
		return {"ok": true, "queued_for_player": true, "conference": winner_conf}

	var auto_demands = _auto_navrh_mirovych_podminek(winner_conf)
	var result = _proved_mirovou_konferenci(winner_conf, auto_demands)
	result["queued_for_player"] = false
	return result

func ziskej_prvni_mirovou_konferenci_pro_hrace(hrac_tag: String) -> Dictionary:
	_odstran_neplatne_mirove_konference()
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return {}
	var queue = cekajici_mirove_konference[player] as Array
	if queue.is_empty():
		return {}
	return (queue[0] as Dictionary).duplicate(true)

func ziskej_pocet_mirovych_konferenci_pro_hrace(hrac_tag: String) -> int:
	_odstran_neplatne_mirove_konference()
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return 0
	var queue = cekajici_mirove_konference[player] as Array
	return queue.size()

func ma_cekajici_mirovou_konferenci_pro_stat(stat_tag: String) -> bool:
	_odstran_neplatne_mirove_konference()
	var wanted = _normalizuj_tag(stat_tag)
	if wanted == "":
		return false
	for key_any in cekajici_mirove_konference.keys():
		var queue = cekajici_mirove_konference[key_any] as Array
		for item_any in queue:
			var item = item_any as Dictionary
			var winner = _normalizuj_tag(str(item.get("winner", "")))
			var loser = _normalizuj_tag(str(item.get("loser", "")))
			if winner == wanted or loser == wanted:
				return true
	return false

func hrac_uzavri_mirovou_konferenci(hrac_tag: String, conference_id: int, demands: Dictionary) -> Dictionary:
	var player = _normalizuj_tag(hrac_tag)
	if player == "" or not cekajici_mirove_konference.has(player):
		return {"ok": false, "reason": "No pending peace conference found."}
	var queue = cekajici_mirove_konference[player] as Array
	var idx := -1
	for i in range(queue.size()):
		if int((queue[i] as Dictionary).get("id", -1)) == conference_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "Conference is no longer available."}

	var conf = queue[idx] as Dictionary
	if _normalizuj_tag(str(conf.get("winner", ""))) != player:
		return {"ok": false, "reason": "Only the conference winner can confirm terms."}

	var result = _proved_mirovou_konferenci(conf, demands)
	if bool(result.get("ok", false)):
		queue.remove_at(idx)
		if queue.is_empty():
			cekajici_mirove_konference.erase(player)
	return result

func ziskej_vazaly_statu(overlord_tag: String) -> Array:
	var overlord = _normalizuj_tag(overlord_tag)
	var out: Array = []
	if overlord == "":
		return out
	for subject_any in vazalske_vztahy.keys():
		var subject = _normalizuj_tag(str(subject_any))
		var lord = _normalizuj_tag(str(vazalske_vztahy[subject_any]))
		if subject == "" or lord == "":
			continue
		if lord == overlord:
			out.append(subject)
	out.sort()
	return out

func ziskej_overlorda_statu(subject_tag: String) -> String:
	var subject = _normalizuj_tag(subject_tag)
	if subject == "":
		return ""
	return _normalizuj_tag(str(vazalske_vztahy.get(subject, "")))

func je_vazal_statu(subject_tag: String, overlord_tag: String = "") -> bool:
	var subject = _normalizuj_tag(subject_tag)
	if subject == "":
		return false
	var current_lord = ziskej_overlorda_statu(subject)
	if current_lord == "":
		return false
	if _normalizuj_tag(overlord_tag) == "":
		return true
	return current_lord == _normalizuj_tag(overlord_tag)

func jsou_vazalsky_spojeni(tag_a: String, tag_b: String) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return false
	return je_vazal_statu(a, b) or je_vazal_statu(b, a)

func muze_vstoupit_na_uzemi(actor_tag: String, owner_tag: String) -> bool:
	var actor = _normalizuj_tag(actor_tag)
	var owner_state = _normalizuj_tag(owner_tag)
	if actor == "" or owner_state == "":
		return false
	if owner_state == "SEA":
		return true
	if actor == owner_state:
		return true
	if jsou_vazalsky_spojeni(actor, owner_state):
		return true
	if ziskej_uroven_aliance(actor, owner_state) >= ALLIANCE_DEFENSE:
		return true
	if ma_vojensky_pristup(actor, owner_state):
		return true
	return false

func propustit_vazala(overlord_tag: String, subject_tag: String) -> bool:
	var overlord = _normalizuj_tag(overlord_tag)
	var subject = _normalizuj_tag(subject_tag)
	if overlord == "" or subject == "" or overlord == subject:
		return false
	if ziskej_overlorda_statu(subject) != overlord:
		return false
	vazalske_vztahy.erase(subject)
	vazalske_odvody.erase(subject)
	vazalske_odvody_posledni_zmena_kolo.erase(subject)
	_uprav_vztah_statu_bez_cooldown(overlord, subject, -20.0)
	if ziskej_uroven_aliance(overlord, subject) > ALLIANCE_NONE:
		nastav_uroven_aliance(overlord, subject, ALLIANCE_NONE, true)
	return true

func ziskej_aktivni_reparace_statu(state_tag: String) -> Dictionary:
	var state = _normalizuj_tag(state_tag)
	var incoming: Array = []
	var outgoing: Array = []
	if state == "":
		return {"incoming": incoming, "outgoing": outgoing}

	for rep_any in valecne_reparace:
		var rep = rep_any as Dictionary
		var from_tag = _normalizuj_tag(str(rep.get("from", "")))
		var to_tag = _normalizuj_tag(str(rep.get("to", "")))
		var remaining = int(rep.get("remaining_turns", 0))
		if remaining <= 0:
			continue
		if to_tag == state:
			incoming.append(rep.duplicate(true))
		elif from_tag == state:
			outgoing.append(rep.duplicate(true))

	return {"incoming": incoming, "outgoing": outgoing}

func _spocitej_silu_statu(tag: String) -> int:
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

func _ma_ai_prijmout_mir(prijemce: String, odesilatel: String) -> bool:
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

func _ziskej_ai_staty() -> Array:
	var ai_staty: Dictionary = {}
	for state_tag in _ziskej_aktivni_staty():
		var tag = str(state_tag)
		if tag == "" or je_lidsky_stat(tag):
			continue
		ai_staty[tag] = true
	return ai_staty.keys()

func _klic_pair(tag_a: String, tag_b: String) -> String:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b:
		return ""
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _begin_ai_cache_batch() -> void:
	_ai_cache_batch_depth += 1

func _end_ai_cache_batch() -> void:
	if _ai_cache_batch_depth <= 0:
		_ai_cache_batch_depth = 0
		_flush_ai_war_pair_eval_dirty_states()
		return
	_ai_cache_batch_depth -= 1
	if _ai_cache_batch_depth == 0:
		_flush_ai_war_pair_eval_dirty_states()

func _mark_ai_war_pair_eval_dirty_state(tag: String) -> void:
	var clean = _normalizuj_tag(tag)
	if clean == "":
		return
	_ai_war_pair_eval_dirty_states[clean] = true

func _mark_ai_war_pair_eval_dirty_pair(tag_a: String, tag_b: String) -> void:
	_mark_ai_war_pair_eval_dirty_state(tag_a)
	_mark_ai_war_pair_eval_dirty_state(tag_b)
	if _ai_cache_batch_depth == 0:
		_flush_ai_war_pair_eval_dirty_states()

func _flush_ai_war_pair_eval_dirty_states() -> void:
	if _ai_war_pair_eval_dirty_states.is_empty():
		return
	# Full clear is faster than per-key parsing/erase in war-declare bursts.
	# This cache is performance-only and safe to rebuild lazily.
	_ai_war_pair_eval_cache.clear()
	_ai_war_pair_eval_dirty_states.clear()

func _invalidate_turn_cache() -> void:
	_turn_cache_valid = false
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()
	_turn_state_owned_provinces.clear()
	_turn_owner_by_province.clear()
	_turn_soldiers_by_province.clear()
	_turn_neighbors_by_province.clear()

func _rebuild_turn_cache() -> void:
	_invalidate_turn_cache()

	for p_id in map_data:
		var d0 = map_data[p_id]
		var pid0 = int(p_id)
		var n_arr: Array = []
		for n_raw in d0.get("neighbors", []):
			n_arr.append(int(n_raw))
		_turn_neighbors_by_province[pid0] = n_arr
		_turn_owner_by_province[pid0] = str(d0.get("owner", "")).strip_edges().to_upper()
		_turn_soldiers_by_province[pid0] = int(d0.get("soldiers", 0))

	var active: Dictionary = {}
	for p_id in map_data:
		var d = map_data[p_id]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
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

func _refresh_turn_runtime_owner_soldier_cache() -> void:
	if not _turn_cache_valid:
		return
	for p_id in map_data:
		var pid = int(p_id)
		var d = map_data[p_id]
		_turn_owner_by_province[pid] = str(d.get("owner", "")).strip_edges().to_upper()
		_turn_soldiers_by_province[pid] = int(d.get("soldiers", 0))

func _ziskej_aktivni_staty() -> Array:
	if _turn_cache_valid:
		return _turn_active_states.duplicate()

	var ai_staty: Dictionary = {}
	for p_id in map_data:
		var owner_tag = str(map_data[p_id].get("owner", "")).strip_edges().to_upper()
		if owner_tag == "" or owner_tag == "SEA":
			continue
		ai_staty[owner_tag] = true
	return ai_staty.keys()

func _ma_spolecnou_hranici(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	if _turn_cache_valid:
		var cache_key = _klic_pair(tag_a, tag_b)
		return cache_key != "" and _turn_border_pairs.has(cache_key)

	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != tag_a:
			continue
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if n_owner == tag_b:
				return true
	return false

func _zpracuj_ai_diplomacii(ai_staty: Array) -> Array:
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

func _zpracuj_ai_aliance(ai_staty: Array) -> Array:
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

func _zpracuj_ai_neagresivni_smlouvy(ai_staty: Array) -> Array:
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

func _zobraz_hlaseni_neagresivnich_smluv_hrace(zmeny: Array) -> void:
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
			(lines_by_target[a] as Array).append("Non-aggression pact with %s (%d turns)." % [b, NON_AGGRESSION_DURATION_TURNS])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Non-aggression pact with %s (%d turns)." % [a, NON_AGGRESSION_DURATION_TURNS])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacy", "\n".join(lines))

func _zpracuj_ai_opusteni_alianci(ai_staty: Array) -> Array:
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

func _zobraz_hlaseni_opusteni_alianci_hrace(zmeny: Array) -> void:
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

func _zobraz_hlaseni_alianci_hrace(zmeny: Array) -> void:
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

func _zobraz_hlaseni_vztahu_hrace(zmeny: Array):
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

func _vyhodnot_mirove_nabidky_pred_ai():
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
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACY", no_msg)

func zaregistruj_obsazeni_hlavniho_mesta(obrance: String, utocnik: String, capital_province_id: int):
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

func vyhodnot_odlozene_kapitulace() -> Array:
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

func _je_more_provincie_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	if not all_provinces.has(prov_id):
		return false
	var d = all_provinces[prov_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	var typ = str(d.get("type", "")).strip_edges().to_lower()
	return owner_tag == "SEA" or typ == "sea"

func _je_pobrezni_v_datech(all_provinces: Dictionary, prov_id: int) -> bool:
	if not all_provinces.has(prov_id):
		return false
	if _je_more_provincie_v_datech(all_provinces, prov_id):
		return false
	for n_id in all_provinces[prov_id].get("neighbors", []):
		if _je_more_provincie_v_datech(all_provinces, int(n_id)):
			return true
	return false

func _vyber_startovni_port_kandidata(all_provinces: Dictionary, kandidati: Array) -> int:
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

func pridej_startovni_pristavy(all_provinces: Dictionary):
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

func spocitej_prijem(all_provinces: Dictionary, emit_ui_signal: bool = true):
	map_data = all_provinces 
	_synchronizuj_jmeno_a_ideologii_hrace()
	var celkove_hdp = 0.0
	var celkem_vojaku = 0
	
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hrac_stat:
			if hrac_jmeno == "":
				hrac_jmeno = str(d.get("country_name", ""))
				hrac_ideologie = str(d.get("ideology", ""))
			
			celkove_hdp += float(d.get("gdp", 0.0))
			celkem_vojaku += int(d.get("soldiers", 0))

	if lokalni_hraci_staty.size() > 1:
		if not hrac_kasa_inicializovana.has(hrac_stat) and celkove_hdp > 0.0:
			hrac_kasy[hrac_stat] = celkove_hdp * 0.05
			hrac_kasa_inicializovana[hrac_stat] = true
		statni_kasa = float(hrac_kasy.get(hrac_stat, statni_kasa))
	else:
		if not _hrac_kasa_inicializovana and celkove_hdp > 0.0:
			statni_kasa = celkove_hdp * 0.05
			_hrac_kasa_inicializovana = true
			
	# Balanced income: 10% GDP minus army upkeep
	var prijmova_sazba = ziskej_prijmovou_sazbu_hdp(hrac_stat)
	var upkeep_za_vojaka = ziskej_udrzbu_za_vojaka(hrac_stat)
	var prijem_z_hdp = celkove_hdp * prijmova_sazba
	var naklady_na_vojaky = celkem_vojaku * upkeep_za_vojaka
	celkovy_prijem = prijem_z_hdp - naklady_na_vojaky
	if lokalni_hraci_staty.size() > 1:
		hrac_prijmy[hrac_stat] = celkovy_prijem
		hrac_kasy[hrac_stat] = statni_kasa
	
	if TURN_LOG_ENABLED:
		print("HDP Prijem: %.2f | Vydaje Armada: %.2f | Cisty zisk: %.2f" % [prijem_z_hdp, naklady_na_vojaky, celkovy_prijem])
	if emit_ui_signal:
		kolo_zmeneno.emit()

func _spocitej_hdp_statu(tag: String) -> float:
	var hledany = tag.strip_edges().to_upper()
	if hledany == "":
		return 0.0
	if _turn_cache_valid and _turn_state_hdp.has(hledany):
		return float(_turn_state_hdp[hledany])
	var hdp := 0.0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hledany:
			hdp += float(d.get("gdp", 0.0))
	return hdp

func _nastav_stav_zpracovani_tahu(aktivni: bool) -> void:
	if zpracovava_se_tah == aktivni:
		return
	zpracovava_se_tah = aktivni
	zpracovani_tahu_zmeneno.emit(aktivni)

func _spust_turn_watchdog(token: int) -> void:
	await get_tree().create_timer(float(TURN_STUCK_WATCHDOG_MS) / 1000.0).timeout
	if token != _turn_watchdog_token:
		return
	if not zpracovava_se_tah:
		return
	print("[TURN_WATCHDOG] Turn processing timeout reached, forcing UI unlock.")
	_nastav_stav_zpracovani_tahu(false)
	kolo_zmeneno.emit()

func _zrus_turn_watchdog() -> void:
	_turn_watchdog_token += 1

func muze_ukoncit_kolo() -> bool:
	if zpracovava_se_tah:
		return false
	var elapsed = Time.get_ticks_msec() - _last_end_turn_request_ms
	return elapsed >= NEXT_TURN_INPUT_COOLDOWN_MS

func pozaduj_ukonceni_kola() -> bool:
	if zpracovava_se_tah:
		_queued_end_turn_requests += 1
		return true
	if not muze_ukoncit_kolo():
		return false
	_last_end_turn_request_ms = Time.get_ticks_msec()
	ukonci_kolo()
	return true

func _spust_dalsi_pozadovane_kolo() -> void:
	if zpracovava_se_tah:
		return
	if _queued_end_turn_requests <= 0:
		return
	_queued_end_turn_requests -= 1
	_last_end_turn_request_ms = Time.get_ticks_msec()
	ukonci_kolo()

func _dokoncit_ukonceni_kola(turn_start_ms: int, turn_phases: Dictionary) -> void:
	_zrus_turn_watchdog()
	_nastav_stav_zpracovani_tahu(false)
	_log_turn_profile(Time.get_ticks_msec() - turn_start_ms, turn_phases)
	if _queued_end_turn_requests > 0:
		call_deferred("_spust_dalsi_pozadovane_kolo")

func _log_turn_profile(total_ms: int, phases: Dictionary) -> void:
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

func _log_ai_profile(total_ms: int, phases: Dictionary) -> void:
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

func _ai_debug(msg: String) -> void:
	if not AI_DECISION_DEBUG_ENABLED:
		return
	print("[AI_DEBUG][turn=%d] %s" % [aktualni_kolo, msg])

func _turn_slice_wait(counter: int, chunk: int) -> int:
	if not TURN_FRAME_SLICE_ENABLED:
		return counter
	var next_counter = counter + 1
	if next_counter >= max(1, chunk):
		await get_tree().process_frame
		return 0
	return next_counter

func ukonci_kolo():
	if zpracovava_se_tah:
		return
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
	_nastav_stav_zpracovani_tahu(true)
	_turn_watchdog_token += 1
	_spust_turn_watchdog(_turn_watchdog_token)

	if lokalni_hraci_staty.size() > 1 and not _je_posledni_hrac_v_poradi():
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
	turn_phases["armies"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	if lokalni_hraci_staty.size() > 1:
		_uloz_finance_aktivniho_hrace()
		for tag in lokalni_hraci_staty:
			var cisty_tag = _normalizuj_tag(str(tag))
			var kasa = float(hrac_kasy.get(cisty_tag, 0.0)) + float(hrac_prijmy.get(cisty_tag, 0.0))
			hrac_kasy[cisty_tag] = kasa
			if kasa < -100.0:
				await _vyres_bankrot(cisty_tag)
	else:
		statni_kasa += celkovy_prijem
		
		# Bankruptcy at debt below -100
		if statni_kasa < -100.0:
			await _vyres_bankrot(hrac_stat)
	turn_phases["finance"] = Time.get_ticks_msec() - phase_start_ms
	phase_start_ms = Time.get_ticks_msec()

	aktualni_kolo += 1
	_zpracuj_valecne_reparace_za_kolo()
	_zpracuj_vazalske_odvody_za_kolo()
	
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
		if typ_budovy == 2 and map_data.has(prov_id):
			var nazev = str(map_data[prov_id].get("province_name", "Province %d" % int(prov_id)))
			var owner_tag = _normalizuj_tag(str(map_data[prov_id].get("owner", "")))
			if je_lidsky_stat(owner_tag):
				if not hlaseni_dokoncene_stavby.has(owner_tag):
					hlaseni_dokoncene_stavby[owner_tag] = []
				(hlaseni_dokoncene_stavby[owner_tag] as Array).append("Port completed: %s" % nazev)
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
			var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
			var core_owner_tag = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
			var je_okupace = owner_tag != "" and owner_tag != "SEA" and core_owner_tag != "" and core_owner_tag != owner_tag
			if not econ_mods_by_owner.has(owner_tag):
				econ_mods_by_owner[owner_tag] = ziskej_ekonomicke_modifikatory_statu(owner_tag)
			var econ_mods = econ_mods_by_owner[owner_tag] as Dictionary
			var recruit_regen_mult = max(0.01, float(econ_mods.get("recruit_regen_mult", 1.0)))
			var gdp_growth_mult = max(0.01, float(econ_mods.get("gdp_growth_mult", 1.0)))
			var pop_growth_mult = max(0.01, float(econ_mods.get("population_growth_mult", 1.0)))
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

func _aplikuj_bonus(prov_id: int, typ: int):
	if not map_data.has(prov_id): return
	if typ == 0: 
		map_data[prov_id]["gdp"] += 10.0 
	elif typ == 1: 
		map_data[prov_id]["recruitable_population"] += 2000 
	elif typ == 2:
		map_data[prov_id]["has_port"] = true
		var map_loader = _get_map_loader()
		if map_loader and map_loader.has_method("oznac_pristavy_k_aktualizaci"):
			map_loader.oznac_pristavy_k_aktualizaci()

# Bankruptcy logic
func _vyres_bankrot(tag: String):
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

func hrac_verbuje(provincie_id: int, pocet: int) -> bool:
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return false
	
	var d = map_data[provincie_id]
	if str(d.get("owner", "")).strip_edges().to_upper() != hrac_stat: return false
		
	var cena_za_vojaka = ziskej_cenu_za_vojaka(hrac_stat)
	var celkova_cena = pocet * cena_za_vojaka
	
	if statni_kasa >= celkova_cena:
		var dostupni_rekruti = int(d.get("recruitable_population", 0))
		if dostupni_rekruti >= pocet:
			statni_kasa -= celkova_cena
			d["recruitable_population"] -= pocet
			d["soldiers"] += pocet
			map_loader.aktualizuj_ikony_armad()
			kolo_zmeneno.emit() 
			return true
	return false

func _ai_vytvor_profil_pro_ideologii(ideology: String) -> Dictionary:
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

func _ai_ziskej_profil(state_tag: String) -> Dictionary:
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"aggression": 0.5, "defense": 0.55, "unpredictability": 0.30, "ideology": "", "personality": "balanced"}
	if _ai_profily.has(clean):
		return (_ai_profily[clean] as Dictionary)
	var created = _ai_vytvor_profil_pro_ideologii(_ziskej_ideologii_statu(clean))
	_ai_profily[clean] = created
	return created

func ziskej_ai_profil_statu(state_tag: String) -> Dictionary:
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"ok": false, "reason": "Invalid state.", "profile": {}}
	return {
		"ok": true,
		"state": clean,
		"profile": (_ai_ziskej_profil(clean) as Dictionary).duplicate(true)
	}

func nastav_ai_agresivitu_statu(state_tag: String, aggression_0_to_1: float) -> Dictionary:
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

func nastav_globalni_ai_agresi(level: float) -> void:
	_global_ai_aggression_level = clamp(level, 0.0, 1.0)
	# Re-bake all existing profiles so the new setting takes effect immediately.
	for tag in _ai_profily.keys():
		if je_lidsky_stat(str(tag)):
			continue
		var profile = _ai_profily[str(tag)] as Dictionary
		var base = float(profile.get("aggression", 0.5))
		profile["aggression"] = clampf(lerpf(base, _global_ai_aggression_level, 0.70), 0.0, 1.0)
		_ai_profily[str(tag)] = profile

func _ai_randomizuj_ideologie_a_profily(ai_staty: Array) -> void:
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

func _ai_ziskej_nepratele_statu(state_tag: String) -> Array:
	var clean = _normalizuj_tag(state_tag)
	if clean == "":
		return []
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
	return enemies.keys()

func _ai_sdili_nepritele_s(state_a: String, state_b: String) -> bool:
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
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return {"type": "none", "target": "", "expires_turn": aktualni_kolo}

	if _ai_goal_cache.has(clean):
		var cached = _ai_goal_cache[clean] as Dictionary
		var exp = int(cached.get("expires_turn", -1))
		var target_cached = _normalizuj_tag(str(cached.get("target", "")))
		if exp >= aktualni_kolo and (target_cached == "" or _turn_state_owned_provinces.has(target_cached)):
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
		"stagnation": 0,
		"last_signature": {}
	}
	_ai_goal_cache[clean] = out
	return out

func _ai_goal_signature(owner_tag: String, target_tag: String) -> Dictionary:
	var owner = _normalizuj_tag(owner_tag)
	var target = _normalizuj_tag(target_tag)
	var owner_owned := 0
	var owner_cores_held_by_target := 0
	var target_cores_held_by_owner := 0

	if owner == "" or target == "" or owner == target:
		return {
			"owner_owned": owner_owned,
			"owner_cores_held_by_target": owner_cores_held_by_target,
			"target_cores_held_by_owner": target_cores_held_by_owner,
			"border_ratio": 0.0,
			"power_ratio": 0.0
		}

	for p_id in map_data:
		var d = map_data[p_id]
		var owner_now = _normalizuj_tag(str(d.get("owner", "")))
		var core_owner = _normalizuj_tag(str(d.get("core_owner", owner_now)))
		if owner_now == owner:
			owner_owned += 1
		if owner_now == target and core_owner == owner:
			owner_cores_held_by_target += 1
		if owner_now == owner and core_owner == target:
			target_cores_held_by_owner += 1

	var border = _spocitej_silu_na_hranici(owner, target)
	var border_ratio = float(int(border.get("our", 0))) / float(max(1, int(border.get("enemy", 0))))
	var power_ratio = float(max(1, _spocitej_silu_statu(owner))) / float(max(1, _spocitej_silu_statu(target)))
	return {
		"owner_owned": owner_owned,
		"owner_cores_held_by_target": owner_cores_held_by_target,
		"target_cores_held_by_owner": target_cores_held_by_owner,
		"border_ratio": border_ratio,
		"power_ratio": power_ratio
	}

func _ai_aktualizuj_goal_progres(state_tag: String) -> void:
	var owner = _normalizuj_tag(state_tag)
	if owner == "" or not _ai_goal_cache.has(owner):
		return

	var goal = (_ai_goal_cache[owner] as Dictionary).duplicate(true)
	var target = _normalizuj_tag(str(goal.get("target", "")))
	if target == "":
		return

	var sig = _ai_goal_signature(owner, target)
	var prev = goal.get("last_signature", {}) as Dictionary
	var stagnation = int(goal.get("stagnation", 0))

	if prev.is_empty():
		goal["last_signature"] = sig
		goal["stagnation"] = 0
		_ai_goal_cache[owner] = goal
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

	if stagnation >= AI_GOAL_STAGNATION_RETARGET:
		goal["expires_turn"] = aktualni_kolo - 1
		_ai_debug("goal retarget %s reason=stagnation target=%s" % [owner, target])

	_ai_goal_cache[owner] = goal

func _ai_spocitej_war_exhaustion(state_tag: String) -> float:
	var clean = _normalizuj_tag(state_tag)
	if clean == "" or clean == "SEA":
		return 0.0

	var owned = _turn_state_owned_provinces.get(clean, []) as Array
	if owned.is_empty():
		return 1.0

	var own_power = float(max(1, _spocitej_silu_statu(clean)))
	var enemies = _ai_ziskej_nepratele_statu(clean)
	var enemy_power := 0.0
	for e in enemies:
		enemy_power += float(max(1, _spocitej_silu_statu(_normalizuj_tag(str(e)))))
	var war_pressure = enemy_power / own_power if enemy_power > 0.0 else 0.0

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
		clamp(war_pressure - 0.95, 0.0, 1.5) * 0.35 +
		frontline_ratio * 0.28 +
		eco_stress * 0.25 +
		stagnation_stress * 0.22,
		0.0,
		1.0
	)
	return exhaustion

func _ai_ziskej_primarni_front(state_tag: String) -> Dictionary:
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
	for p_any in (_turn_state_owned_provinces.get(clean, []) as Array):
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

func _ai_ziskej_recruit_kandidaty(state_tag: String, owned: Array, pressure: float) -> Array:
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
	var at_war = not _ai_ziskej_nepratele_statu(state_tag).is_empty()
	var base_threat_gate = 260 if at_war else 520

	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		var d = map_data[p_id]
		var recruits = int(d.get("recruitable_population", 0))
		if recruits <= 120:
			continue
		var is_capital = bool(d.get("is_capital", false)) or p_id == cap_id
		var is_frontline = _ma_nepratelskeho_souseda(state_tag, p_id)
		var threat = _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
		var focused_front = false
		if goal_target != "" or front_target != "":
			for n_raw in (_turn_neighbors_by_province.get(p_id, d.get("neighbors", [])) as Array):
				var n_id = int(n_raw)
				if not map_data.has(n_id):
					continue
				var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if n_owner == "" or n_owner == "SEA" or n_owner == state_tag:
					continue
				if n_owner == goal_target or n_owner == front_target:
					focused_front = true
					break

		# Avoid recruiting everywhere: in low-threat areas recruit only if strategic anchor exists.
		if not is_capital and not is_frontline and not focused_front and threat < base_threat_gate:
			continue
		var score = 0.0
		if is_capital:
			score += 3000.0
		if is_frontline:
			score += 1800.0
		if focused_front:
			score += 1300.0
		score += min(2100.0, float(threat) * (0.24 + attack_bias * 0.10))
		score += float(recruits) * 0.12
		score += float(d.get("gdp", 0.0)) * 14.0 * aggression
		score += (320.0 * defense) if is_capital else 0.0
		score -= exhaustion * 220.0
		scored.append({"id": p_id, "score": score})

	if scored.is_empty():
		return []

	scored.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	var war_pressure = 1.0 if not at_war else 1.30
	var pressure_factor = clamp(pressure / 1800.0, 0.0, 1.0)
	var fraction = clamp(0.12 + (pressure_factor * 0.18) + (defense * 0.10) + (attack_bias * 0.08), 0.10, 0.45)
	fraction *= war_pressure
	fraction = clamp(fraction, 0.10, 0.58)
	var max_targets = 2
	if at_war:
		max_targets = 4
	if pressure_factor >= 0.55:
		max_targets += 1
	if attack_bias >= 0.70:
		max_targets += 1
	if exhaustion >= 0.70:
		max_targets = max(2, max_targets - 1)
	var keep_n = clampi(int(ceil(float(scored.size()) * fraction)), 1, min(max_targets, scored.size()))
	var top_score = float((scored[0] as Dictionary).get("score", 0.0))

	var out: Array = []
	for i in range(min(keep_n, scored.size())):
		var row = scored[i] as Dictionary
		var s = float(row.get("score", 0.0))
		if i > 0 and s < max(top_score * 0.46, top_score - 1700.0):
			continue
		out.append(int(row.get("id", -1)))
	return out

func _ai_spocitej_tlak_statu(state_tag: String, owned: Array) -> float:
	var total_threat := 0
	for p_id_any in owned:
		var p_id = int(p_id_any)
		total_threat += _spocitej_hrozbu_nepratel_u_provincie(p_id, state_tag)
	if owned.is_empty():
		return 0.0
	return float(total_threat) / float(max(1, owned.size()))

func _ai_vypocitej_hotovostni_rezervu(state_tag: String, owned: Array) -> float:
	var total_soldiers := 0
	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		total_soldiers += int(map_data[p_id].get("soldiers", 0))
	var upkeep = ziskej_udrzbu_za_vojaka(state_tag)
	var pressure = _ai_spocitej_tlak_statu(state_tag, owned)
	var profile = _ai_ziskej_profil(state_tag)
	var defense_bias = float(profile.get("defense", 0.55))
	var reserve = AI_MIN_TREASURY_RESERVE * (0.9 + defense_bias * 0.6)
	reserve += float(total_soldiers) * upkeep * 2.5
	reserve += min(120.0, pressure * 0.008)
	return reserve

func _ai_skore_vyzkumu(state_tag: String, project: Dictionary, pressure: float, treasury: float) -> float:
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

	return score / cost

func _ai_zvaz_vyzkum(state_tag: String, reserve: float, pressure: float) -> bool:
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

func _ai_stat_ma_pristav(owned: Array) -> bool:
	for p_id_any in owned:
		var p_id = int(p_id_any)
		if not map_data.has(p_id):
			continue
		if bool(map_data[p_id].get("has_port", false)):
			return true
	return false

func _ai_zvaz_stavby(state_tag: String, owned: Array, reserve: float, pressure: float) -> int:
	var built := 0
	if owned.is_empty():
		return built

	var has_port = _ai_stat_ma_pristav(owned)
	var profile = _ai_ziskej_profil(state_tag)
	var defense = float(profile.get("defense", 0.55))
	var aggression = float(profile.get("aggression", 0.50))
	var used: Dictionary = {}
	for _i in range(AI_BUILD_MAX_PER_TURN):
		var treasury = _ziskej_kasu_statu(state_tag)
		var budget = treasury - reserve
		if budget < AI_BUILDING_COST_ECON:
			break

		var best_pid := -1
		var best_building := -1
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
			var gdp = float(d.get("gdp", 0.0))
			var recruits = int(d.get("recruitable_population", 0))
			var is_frontline = _ma_nepratelskeho_souseda(state_tag, p_id)

			if budget >= AI_BUILDING_COST_ECON:
				var score_econ = gdp * 14.0 * (1.05 - defense * 0.2)
				if not is_frontline:
					score_econ += 120.0
				if score_econ > best_score:
					best_score = score_econ
					best_pid = p_id
					best_building = 0
					best_cost = AI_BUILDING_COST_ECON

			if budget >= AI_BUILDING_COST_RECRUIT:
				var score_recruit = float(recruits) * 0.09 + pressure * (0.014 + defense * 0.010)
				if is_frontline:
					score_recruit += 180.0
				if score_recruit > best_score:
					best_score = score_recruit
					best_pid = p_id
					best_building = 1
					best_cost = AI_BUILDING_COST_RECRUIT

			if not has_port and budget >= AI_BUILDING_COST_PORT and muze_postavit_pristav(p_id):
				var score_port = 260.0 + (gdp * (6.0 + aggression * 4.0))
				if score_port > best_score:
					best_score = score_port
					best_pid = p_id
					best_building = 2
					best_cost = AI_BUILDING_COST_PORT

		if best_pid == -1 or best_building == -1:
			break

		_nastav_kasu_statu(state_tag, treasury - best_cost)
		provincie_cooldowny[best_pid] = {"zbyva": 3, "budova": best_building}
		_ai_debug("build start %s prov=%d type=%d cost=%.2f treasury_after=%.2f" % [
			state_tag,
			best_pid,
			best_building,
			best_cost,
			_ziskej_kasu_statu(state_tag)
		])
		used[best_pid] = true
		if best_building == 2:
			has_port = true
		built += 1

	return built

func _ai_zvaz_armadni_lab(state_tag: String, reserve: float) -> bool:
	var treasury = _ziskej_kasu_statu(state_tag)
	var profile = _ai_ziskej_profil(state_tag)
	var aggression = float(profile.get("aggression", 0.50))
	if treasury < reserve + AI_ARM_LAB_MIN_SURPLUS * (0.9 + aggression * 0.4):
		return false

	var lab_state = ziskej_armadni_lab_statu(state_tag)
	if not bool(lab_state.get("ok", false)):
		return false

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
			return true

	var quality_level = int(lab_state.get("quality_level", 0))
	var quality_cost = float(lab_state.get("quality_upgrade_cost", 0.0))
	if quality_level < 5 and treasury - quality_cost >= reserve + 25.0:
		var quality_result = vylepsi_kvalitu_dropu_armady(state_tag)
		if bool(quality_result.get("ok", false)):
			_ai_debug("arm_lab quality %s lvl=%d cost=%.2f treasury_after=%.2f" % [
				state_tag,
				int(quality_result.get("new_quality_level", quality_level + 1)),
				float(quality_result.get("cost", quality_cost)),
				float(quality_result.get("treasury_after", _ziskej_kasu_statu(state_tag)))
			])
			return true

	if bool(lab_state.get("can_expand", false)):
		var expand_cost = float(lab_state.get("expand_cost", 0.0))
		if treasury - expand_cost >= reserve + 25.0:
			var expand_result = rozsirit_armadni_mrizku(state_tag)
			if bool(expand_result.get("ok", false)):
				_ai_debug("arm_lab expand %s cost=%.2f treasury_after=%.2f" % [
					state_tag,
					expand_cost,
					_ziskej_kasu_statu(state_tag)
				])
				return true

	return false

# AI logic

func zpracuj_tah_ai():
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
	var map_loader = _get_map_loader()
	if not map_loader or map_data.is_empty(): return
	_core_state_cache.clear()
	_ai_phase_cache_active = false
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
	_rebuild_turn_cache()
	var ai_staty = _ziskej_ai_staty()
	_ai_randomizuj_ideologie_a_profily(ai_staty)
	ai_phases["setup"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()
	_ai_phase_cache_active = true
	_set_defer_log_maintenance(true)

	# Evaluate pending peace offers before AI plans any attacks.
	_vyhodnot_mirove_nabidky_pred_ai()
	_vyhodnot_aliancni_zadosti_pred_ai()
	
	# Skip diplomacy in potato mode for performance
	if not _potato_mode_enabled:
		var zmeny_neagrese_k_hraci = _zpracuj_ai_neagresivni_smlouvy(ai_staty)
		_zobraz_hlaseni_neagresivnich_smluv_hrace(zmeny_neagrese_k_hraci)
		var zmeny_vztahu_k_hraci = _zpracuj_ai_diplomacii(ai_staty)
		_zobraz_hlaseni_vztahu_hrace(zmeny_vztahu_k_hraci)
		var zmeny_opusteni_alianci = _zpracuj_ai_opusteni_alianci(ai_staty)
		_zobraz_hlaseni_opusteni_alianci_hrace(zmeny_opusteni_alianci)
		var zmeny_alianci_k_hraci = _zpracuj_ai_aliance(ai_staty)
		_zobraz_hlaseni_alianci_hrace(zmeny_alianci_k_hraci)
	
	_set_defer_log_maintenance(false)
	ai_phases["diplomacy"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()

	# Runtime cache mode remains enabled for economy and movement.
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
		
	var ai_state_slice_counter := 0

	for owner_tag_raw in ai_staty:
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

		_ai_zvaz_presun_hlavniho_mesta(owner_tag)
		var treasury_reserve = _ai_vypocitej_hotovostni_rezervu(owner_tag, owned)

		var ai_income_slice_counter := 0
		var prijmova_sazba = ziskej_prijmovou_sazbu_hdp(owner_tag)
		var upkeep_za_vojaka = ziskej_udrzbu_za_vojaka(owner_tag)
		for p_id in owned:
			if not map_data.has(p_id):
				continue
			var d_income = map_data[p_id]
			var gdp = float(d_income.get("gdp", 0.0))
			var vojaci = int(d_income.get("soldiers", 0))
			var prijem = (gdp * prijmova_sazba) - (vojaci * upkeep_za_vojaka)
			ai_kasy[owner_tag] += prijem
			ai_income_slice_counter = await _turn_slice_wait(ai_income_slice_counter, TURN_FRAME_SLICE_AI)

		if ai_kasy[owner_tag] < -100.0:
			_vyres_bankrot(owner_tag)

		var state_pressure = _ai_spocitej_tlak_statu(owner_tag, owned)
		_ai_zvaz_vyzkum(owner_tag, treasury_reserve, state_pressure)
		_ai_zvaz_stavby(owner_tag, owned, treasury_reserve, state_pressure)
		_ai_zvaz_armadni_lab(owner_tag, treasury_reserve)

		var cena_za_vojaka = max(0.001, ziskej_cenu_za_vojaka(owner_tag))

		var recruit_targets = _ai_ziskej_recruit_kandidaty(owner_tag, owned, state_pressure)
		var state_exhaustion = _ai_spocitej_war_exhaustion(owner_tag)
		var state_mindset = _ai_ziskej_mindset(owner_tag)
		var state_attack_bias = float(state_mindset.get("attack_bias", 0.5))
		var at_war_state = not _ai_ziskej_nepratele_statu(owner_tag).is_empty()
		var recruit_order_cap = 2
		if at_war_state:
			recruit_order_cap = 4
		if state_pressure >= 950.0:
			recruit_order_cap += 1
		if state_attack_bias >= 0.70:
			recruit_order_cap += 1
		if state_exhaustion >= 0.72:
			recruit_order_cap = max(2, recruit_order_cap - 1)
		_ai_debug("recruit plan %s targets=%d pressure=%.1f reserve=%.2f treasury=%.2f" % [
			owner_tag,
			recruit_targets.size(),
			state_pressure,
			treasury_reserve,
			_ziskej_kasu_statu(owner_tag)
		])
		var ai_recruit_slice_counter := 0
		var recruited_total := 0
		var recruit_orders_done := 0
		for p_id in recruit_targets:
			if recruit_orders_done >= recruit_order_cap:
				break
			if not map_data.has(p_id):
				continue
			var d = map_data[p_id]
			var rekruti = int(d.get("recruitable_population", 0))
			var core_owner_tag = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
			var je_okupace = core_owner_tag != "" and core_owner_tag != owner_tag
			if je_okupace:
				rekruti = int(floor(float(rekruti) * 0.2))
			if rekruti > 220 and ai_kasy[owner_tag] > treasury_reserve + 5.0:
				var dostupny_rozpocet = max(0.0, ai_kasy[owner_tag] - treasury_reserve)
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
				pocet_k_verbovani = min(pocet_k_verbovani, limit_verbovani)
				d["recruitable_population"] -= pocet_k_verbovani
				d["soldiers"] += pocet_k_verbovani
				ai_kasy[owner_tag] -= (pocet_k_verbovani * cena_za_vojaka)
				recruited_total += pocet_k_verbovani
				recruit_orders_done += 1
			ai_recruit_slice_counter = await _turn_slice_wait(ai_recruit_slice_counter, TURN_FRAME_SLICE_AI)
		_ai_debug("state summary %s recruited=%d treasury_before=%.2f treasury_after=%.2f" % [
			owner_tag,
			recruited_total,
			treasury_before,
			_ziskej_kasu_statu(owner_tag)
		])

		ai_state_slice_counter = await _turn_slice_wait(ai_state_slice_counter, TURN_FRAME_SLICE_AI_STATES)
	ai_phases["economy_recruit"] = Time.get_ticks_msec() - ai_phase_ms
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
	await _naplanuj_ai_presuny(map_loader)
	ai_phases["movement"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()
	# Disable runtime caches after movement and clean up temp maps.
	_ai_phase_cache_active = false
	_ai_enemy_neighbor_cache.clear()
	_ai_threat_cache.clear()
	_ai_border_strength_cache.clear()
	_ai_war_pair_eval_cache.clear()
	_ai_relation_cache.clear()
	_ai_allies_cache.clear()
	_ai_war_cache.clear()
	_ai_alliance_level_cache.clear()
	_ai_can_adjust_relation_cache.clear()
	_ai_border_cache.clear()
	_ai_mindset_cache.clear()
	_invalidate_turn_cache()
	ai_phases["cleanup"] = Time.get_ticks_msec() - ai_phase_ms
	_log_ai_profile(Time.get_ticks_msec() - ai_start_ms, ai_phases)
				
	if TURN_LOG_ENABLED:
		print("--- AI THINKING END ---")

func _vyber_ai_kandidata_pro_presun_hlavniho_mesta(state_tag: String, current_capital_id: int) -> int:
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

func _naplanuj_ai_presuny(map_loader):
	var ai_staty = _ziskej_ai_staty()
	var movement_profile = AI_MOVEMENT_PROFILE_ENABLED
	var movement_start_ms = 0
	var movement_non_attack_ms = 0
	var movement_core_defense_ms = 0
	var movement_offense_ms = 0
	var movement_war_eval_ms = 0
	var movement_war_declare_ms = 0
	var movement_war_eval_count = 0
	var movement_war_declare_count = 0
	var movement_registered = 0
	if movement_profile:
		movement_start_ms = Time.get_ticks_msec()

	if map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()

	var plan_slice_counter := 0

	for owner_tag in ai_staty:
		var moved_from: Dictionary = {}
		var orders_for_state := 0  # Hard limit on movement orders per state (potato mode only)
		var ai_limit_enabled := _potato_mode_enabled
		owner_tag = str(owner_tag)
		var serazene: Array = _seradene_ai_provincie(owner_tag)
		var own_capital_id = _ziskej_hlavni_mesto_statu(owner_tag)
		var core_state: String = _ziskej_core_state_cached(owner_tag)
		var front_info = _ai_ziskej_primarni_front(owner_tag)
		var preferred_front_owner = _normalizuj_tag(str(front_info.get("target", "")))
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
				if str(_turn_owner_by_province.get(n_id, "")) != owner_tag:
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
			var move = _navrhni_neutocny_presun(owner_tag, p_id, frontline_cache)
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

		# 3) Offensive attacks.
		if movement_profile:
			phase_start_ms = Time.get_ticks_msec()
		var offense_orders := 0
		var offense_order_cap := 999999
		if is_consolidating:
			offense_order_cap = 1
		for p_id in serazene:
			if ai_limit_enabled and orders_for_state >= AI_MAX_ARMY_ORDERS_PER_STATE:
				break  # Hard limit reached for this state
			if offense_orders >= offense_order_cap:
				break
			if moved_from.has(p_id):
				continue
			var move = _navrhni_utok(owner_tag, p_id, frontline_cache, preferred_front_owner, coordinated_commitment)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue

			var target_id = int(move["to"])
			var target_owner = str(_turn_owner_by_province.get(target_id, str(map_data[target_id].get("owner", "")).strip_edges().to_upper()))
			if jsou_ve_valce(owner_tag, target_owner):
				if is_consolidating:
					var local_enemy = int(_turn_soldiers_by_province.get(target_id, int(map_data[target_id].get("soldiers", 0))))
					if float(amount) / float(max(1, local_enemy)) < 1.20:
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

	if map_loader.has_method("ukonci_davkovy_presun"):
		map_loader.ukonci_davkovy_presun()

	if movement_profile:
		var movement_total_ms = Time.get_ticks_msec() - movement_start_ms
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

func _seradene_ai_provincie(state_tag: String) -> Array:
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

	ids.sort_custom(func(a, b):
		return int(_turn_soldiers_by_province.get(int(a), int(map_data[a].get("soldiers", 0)))) > int(_turn_soldiers_by_province.get(int(b), int(map_data[b].get("soldiers", 0))))
	)
	return ids

func _ma_nepratelskeho_souseda(state_tag: String, province_id: int) -> bool:
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
		var n_owner = str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")).strip_edges().to_upper()))
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

func _spocitej_hrozbu_nepratel_u_provincie(province_id: int, state_tag: String) -> int:
	if _ai_phase_cache_active:
		var ck = "%s|%d" % [state_tag, province_id]
		if _ai_threat_cache.has(ck):
			return int(_ai_threat_cache[ck])

	if not map_data.has(province_id):
		if _ai_phase_cache_active:
			_ai_threat_cache["%s|%d" % [state_tag, province_id]] = 0
		return 0
	var threat := 0
	var neighbors = (_turn_neighbors_by_province.get(province_id, map_data[province_id].get("neighbors", [])) as Array)
	for n_raw in neighbors:
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_owner = str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")).strip_edges().to_upper()))
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner):
			continue
		threat += int(_turn_soldiers_by_province.get(n_id, int(map_data[n_id].get("soldiers", 0))))
	if _ai_phase_cache_active:
		_ai_threat_cache["%s|%d" % [state_tag, province_id]] = threat
	return threat

func _spocitej_silu_na_hranici(state_tag: String, enemy: String) -> Dictionary:
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
				var n_owner_our = str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")).strip_edges().to_upper()))
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
				var n_owner_enemy = str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")).strip_edges().to_upper()))
				if n_owner_enemy == state_tag:
					enemy_border += soldiers_enemy
					break
		return {"our": our_border, "enemy": enemy_border}

	for p_id in map_data:
		var d = map_data[p_id]
		var p_owner = str(d.get("owner", "")).strip_edges().to_upper()
		if p_owner != state_tag and p_owner != enemy:
			continue
		var soldiers = int(d.get("soldiers", 0))
		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if p_owner == state_tag and n_owner == enemy:
				our_border += soldiers
				break
			if p_owner == enemy and n_owner == state_tag:
				enemy_border += soldiers
				break
	return {"our": our_border, "enemy": enemy_border}

func _ziskej_ai_border_strength_cached(state_tag: String, target_owner: String) -> Dictionary:
	if not _ai_phase_cache_active:
		return _spocitej_silu_na_hranici(state_tag, target_owner)
	var key = "%s>%s" % [state_tag, target_owner]
	if _ai_border_strength_cache.has(key):
		return (_ai_border_strength_cache[key] as Dictionary)
	var computed = _spocitej_silu_na_hranici(state_tag, target_owner)
	_ai_border_strength_cache[key] = computed
	return computed

func _ziskej_ai_war_pair_eval_cached(state_tag: String, target_owner: String) -> Dictionary:
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

func _ma_smyls_vyhlasit_valku(state_tag: String, target_owner: String, from_id: int, to_id: int, amount: int) -> bool:
	if state_tag == "" or target_owner == "" or target_owner == "SEA":
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

func _ai_otevri_valky(ai_staty: Array) -> int:
	var opened := 0
	for owner_any in ai_staty:
		var owner = _normalizuj_tag(str(owner_any))
		if owner == "" or owner == "SEA":
			continue

		var owned = _turn_state_owned_provinces.get(owner, []) as Array
		if owned.is_empty():
			continue

		var profile = _ai_ziskej_profil(owner)
		var goal = _ai_ziskej_strategicky_cil(owner)
		var primary_front = _ai_ziskej_primarni_front(owner)
		var front_target = _normalizuj_tag(str(primary_front.get("target", "")))
		var exhaustion = _ai_spocitej_war_exhaustion(owner)
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
				var n_owner = _normalizuj_tag(str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")))))
				if n_owner == "" or n_owner == "SEA" or n_owner == owner:
					continue
				candidates[n_owner] = true

		var best_target := ""
		var best_score := -INF
		for target in candidates.keys():
			var target_owner = _normalizuj_tag(str(target))
			if target_owner == "":
				continue
			if _jsou_ve_valce_ai_cached(owner, target_owner):
				continue

			var alliance_level = _ziskej_uroven_aliance_ai_cached(owner, target_owner)
			if alliance_level > ALLIANCE_NONE and aggression < 0.82:
				continue
			if _ma_neagresivni_smlouvu_ai_cached(owner, target_owner) and aggression < 0.82:
				continue

			var rel = _ziskej_ai_vztah_cached(owner, target_owner)
			var war_rel_cap = AI_DECLARE_WAR_MAX_RELATION + (aggression * 55.0)
			if rel > war_rel_cap and aggression < 0.92:
				continue

			var own_power = float(max(1, _spocitej_silu_statu(owner)))
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

			var border = _spocitej_silu_na_hranici(owner, target_owner)
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
			var pair_key = _klic_pair(owner, best_target)
			if pair_key != "":
				neagresivni_smlouvy.erase(pair_key)
			if _ziskej_uroven_aliance_ai_cached(owner, best_target) > ALLIANCE_NONE:
				_nastav_uroven_aliance_bez_kontroly(owner, best_target, ALLIANCE_NONE)

		if vyhlasit_valku(owner, best_target):
			opened += 1
			_ai_debug("war opener %s -> %s aggr=%.2f score=%.1f" % [owner, best_target, aggression, best_score])
			_ai_war_cache.clear()
			_ai_war_pair_eval_cache.clear()
			_ai_border_strength_cache.clear()

	return opened

func _navrhni_krizovy_protiutok(state_tag: String, from_id: int, own_capital_id: int, frontline_cache: Dictionary = {}) -> Dictionary:
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

func _ziskej_ai_vztah_cached(tag_a: String, tag_b: String) -> float:
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

func _je_pratelsky_vztah_ai_cached(tag_a: String, tag_b: String) -> bool:
	if tag_a == "" or tag_b == "" or tag_a == tag_b:
		return false
	return _ziskej_ai_vztah_cached(tag_a, tag_b) >= AI_FRIEND_RELATION_THRESHOLD

func _jsou_ve_valce_ai_cached(tag_a: String, tag_b: String) -> bool:
	if not _ai_phase_cache_active:
		return jsou_ve_valce(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_war_cache.has(key):
		return bool(_ai_war_cache[key])
	var is_war = valky.has(key)
	_ai_war_cache[key] = is_war
	return is_war

func _ziskej_uroven_aliance_ai_cached(tag_a: String, tag_b: String) -> int:
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

func _ma_neagresivni_smlouvu_ai_cached(tag_a: String, tag_b: String) -> bool:
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

func _muze_upravit_vztah_ai_cached(tag_a: String, tag_b: String) -> bool:
	if not _ai_phase_cache_active:
		return muze_upravit_vztah_statu(tag_a, tag_b)
	var key = _klic_pair(tag_a, tag_b)
	if key == "":
		return false
	if _ai_can_adjust_relation_cache.has(key):
		return bool(_ai_can_adjust_relation_cache[key])
	var last_turn = int(_vztah_akce_posledni_kolo.get(key, -9999999))
	var ok = (aktualni_kolo - last_turn) >= RELATION_ACTION_COOLDOWN_TURNS
	_ai_can_adjust_relation_cache[key] = ok
	return ok

func _ma_spolecnou_hranici_ai_cached(tag_a: String, tag_b: String) -> bool:
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

func _je_frontline_cached(state_tag: String, province_id: int, frontline_cache: Dictionary) -> bool:
	if frontline_cache.has(province_id):
		return bool(frontline_cache[province_id])
	var is_frontline = _ma_nepratelskeho_souseda(state_tag, province_id)
	frontline_cache[province_id] = is_frontline
	return is_frontline

func _navrhni_neutocny_presun(state_tag: String, from_id: int, frontline_cache: Dictionary = {}) -> Dictionary:
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
		var n_owner = str(_turn_owner_by_province.get(n_id, str(map_data[n_id].get("owner", "")).strip_edges().to_upper()))
		if n_owner != state_tag:
			continue

		var target_soldiers = int(_turn_soldiers_by_province.get(n_id, int(map_data[n_id].get("soldiers", 0))))
		var threatened = _je_frontline_cached(state_tag, n_id, frontline_cache)
		var score = 0.0
		if threatened:
			score += 10000.0
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

func _ziskej_core_state(state_tag: String) -> String:
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != state_tag:
			continue
		if bool(d.get("is_capital", false)):
			return str(d.get("state", ""))
	return ""

func _ziskej_core_state_cached(state_tag: String) -> String:
	if state_tag == "":
		return ""
	if _core_state_cache.has(state_tag):
		return str(_core_state_cache[state_tag])
	var core_state = _ziskej_core_state(state_tag)
	_core_state_cache[state_tag] = core_state
	return core_state

func _je_core_provincie(state_tag: String, province_id: int, core_state: String) -> bool:
	if not map_data.has(province_id):
		return false
	var d = map_data[province_id]
	if str(_turn_owner_by_province.get(province_id, str(d.get("owner", "")).strip_edges().to_upper())) != state_tag:
		return false
	if bool(d.get("is_capital", false)):
		return true
	if core_state != "" and str(d.get("state", "")) == core_state:
		return true
	return false

func _navrhni_core_obranu(state_tag: String, from_id: int, core_state: String = "", frontline_cache: Dictionary = {}) -> Dictionary:
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

func _navrhni_utok(state_tag: String, from_id: int, frontline_cache: Dictionary = {}, preferred_front_owner: String = "", coordinated_commitment: Dictionary = {}) -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci <= 700:
		return {}
	if not _je_frontline_cached(state_tag, from_id, frontline_cache):
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
	var reserve = max(360, int(float(vojaci) * (0.40 - aggression * 0.15 + defense_bias * 0.10 - attack_bias * 0.08)))
	var max_attack = vojaci - reserve
	if max_attack < 280:
		return {}

	for n_raw in (_turn_neighbors_by_province.get(from_id, from_data.get("neighbors", [])) as Array):
		var n_id = int(n_raw)
		if not map_data.has(n_id):
			continue
		var n_prov = map_data[n_id]
		var n_owner = str(_turn_owner_by_province.get(n_id, str(n_prov.get("owner", "")).strip_edges().to_upper()))
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner) and attack_bias < 0.72:
			continue

		var n_vojaci = int(_turn_soldiers_by_province.get(n_id, int(n_prov.get("soldiers", 0))))
		var threat_after_capture = _spocitej_hrozbu_nepratel_u_provincie(n_id, state_tag)
		var needed_for_push = int(float(n_vojaci) * lerpf(1.14, 0.78, attack_bias)) + int(float(threat_after_capture) * lerpf(0.14, 0.04, attack_bias))
		var attack_amount = min(max_attack, int(float(vojaci) * 0.78))
		var source_threat = _spocitej_hrozbu_nepratel_u_provincie(from_id, state_tag)
		var remaining_after = vojaci - attack_amount
		# Do not overextend from threatened source provinces.
		if source_threat > int(float(max(1, remaining_after)) * 1.45):
			if not (goal_type == "reclaim_core" and goal_target != "" and n_owner == goal_target):
				continue
		# Protect capital garrison unless this is a direct reclaim objective.
		if from_id == own_capital_id and remaining_after < max(700, int(float(source_threat) * 0.85)):
			if not (goal_type == "reclaim_core" and goal_target != "" and n_owner == goal_target):
				continue
		var overwhelming = float(vojaci) / float(max(1, n_vojaci)) >= lerpf(4.8, 1.7, attack_bias)
		if attack_amount < max(320, needed_for_push) and not overwhelming:
			continue

		var score = 0.0
		score += float(attack_amount - n_vojaci) * 1.2
		score -= float(threat_after_capture) * 0.30
		var rel = _ziskej_ai_vztah_cached(state_tag, n_owner)
		score += clamp(-rel, 0.0, 100.0) * 12.0
		score += float(n_prov.get("gdp", 0.0)) * 16.0
		score += float(int(n_prov.get("recruitable_population", 0))) * 0.02
		if bool(n_prov.get("is_capital", false)):
			score += 3600.0
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

func nastav_potato_mode(enabled: bool) -> void:
	_potato_mode_enabled = enabled

