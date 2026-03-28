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
const PEACE_WAR_COOLDOWN_TURNS := 5
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
const NEXT_TURN_INPUT_COOLDOWN_MS := 250
const TURN_PROFILE_ENABLED := true
const TURN_PROFILE_WARN_MS := 1200
const AI_PROFILE_ENABLED := true
const AI_PROFILE_WARN_MS := 500

# Diplomacy
var valky: Dictionary = {}
var cekajici_kapitulace: Array = []
var cekajici_mirove_nabidky: Array = []
var aliance_statu: Dictionary = {}
var neagresivni_smlouvy: Dictionary = {}
var povalecne_cooldowny: Dictionary = {}
var cekajici_diplomaticke_zadosti: Dictionary = {}
var cekajici_aliancni_zadosti: Array = []

const DIP_REQUEST_PRIORITY_PLAYER := 0
const DIP_REQUEST_PRIORITY_PEACE := 1
const DIP_REQUEST_PRIORITY_ALLIANCE := 2
const DIP_REQUEST_PRIORITY_NON_AGGRESSION := 3

var zpracovava_se_tah: bool = false
var _last_end_turn_request_ms: int = -1000000
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

const AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING := 1000

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
		"valk", "war", "kapitul", "surrender", "hlavni mesto", "hlavní město",
		"anex", "vyhlasil valku", "vyhlásil válku", "porazen", "poražen"
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
	for item in kopie_fronty:
		var t = str(item.get("title", "Hlaseni"))
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
		"lokalni_hraci_staty": lokalni_hraci_staty.duplicate(true),
		"aktivni_hrac_index": aktivni_hrac_index,
		"hrac_kasy": hrac_kasy.duplicate(true),
		"hrac_prijmy": hrac_prijmy.duplicate(true),
		"hrac_kasa_inicializovana": hrac_kasa_inicializovana.duplicate(true),
		"log_zprav_hracu": log_zprav_hracu.duplicate(true),
		"log_globalnich_zprav": log_globalnich_zprav.duplicate(true),
		"valky": valky.duplicate(true),
		"cekajici_kapitulace": cekajici_kapitulace.duplicate(true),
		"cekajici_mirove_nabidky": cekajici_mirove_nabidky.duplicate(true),
		"aliance_statu": aliance_statu.duplicate(true),
		"neagresivni_smlouvy": neagresivni_smlouvy.duplicate(true),
		"povalecne_cooldowny": povalecne_cooldowny.duplicate(true),
		"cekajici_diplomaticke_zadosti": cekajici_diplomaticke_zadosti.duplicate(true),
		"cekajici_aliancni_zadosti": cekajici_aliancni_zadosti.duplicate(true),
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
	lokalni_hraci_staty = (state.get("lokalni_hraci_staty", []) as Array).duplicate(true)
	aktivni_hrac_index = int(state.get("aktivni_hrac_index", 0))
	hrac_kasy = (state.get("hrac_kasy", {}) as Dictionary).duplicate(true)
	hrac_prijmy = (state.get("hrac_prijmy", {}) as Dictionary).duplicate(true)
	hrac_kasa_inicializovana = (state.get("hrac_kasa_inicializovana", {}) as Dictionary).duplicate(true)
	log_zprav_hracu = (state.get("log_zprav_hracu", {}) as Dictionary).duplicate(true)
	log_globalnich_zprav = (state.get("log_globalnich_zprav", []) as Array).duplicate(true)
	valky = (state.get("valky", {}) as Dictionary).duplicate(true)
	cekajici_kapitulace = (state.get("cekajici_kapitulace", []) as Array).duplicate(true)
	cekajici_mirove_nabidky = (state.get("cekajici_mirove_nabidky", []) as Array).duplicate(true)
	aliance_statu = (state.get("aliance_statu", {}) as Dictionary).duplicate(true)
	neagresivni_smlouvy = (state.get("neagresivni_smlouvy", {}) as Dictionary).duplicate(true)
	povalecne_cooldowny = (state.get("povalecne_cooldowny", {}) as Dictionary).duplicate(true)
	cekajici_diplomaticke_zadosti = (state.get("cekajici_diplomaticke_zadosti", {}) as Dictionary).duplicate(true)
	cekajici_aliancni_zadosti = (state.get("cekajici_aliancni_zadosti", []) as Array).duplicate(true)
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
	_hrac_kasa_inicializovana = false
	lokalni_hraci_staty.clear()
	aktivni_hrac_index = 0
	hrac_kasy.clear()
	hrac_prijmy.clear()
	hrac_kasa_inicializovana.clear()
	cekajici_popupy_hracu.clear()
	log_zprav_hracu.clear()
	log_globalnich_zprav.clear()

	valky.clear()
	cekajici_kapitulace.clear()
	cekajici_mirove_nabidky.clear()
	aliance_statu.clear()
	neagresivni_smlouvy.clear()
	povalecne_cooldowny.clear()
	cekajici_diplomaticke_zadosti.clear()
	cekajici_aliancni_zadosti.clear()

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

func ma_ulozene_hry() -> bool:
	if FileAccess.file_exists(SAVEGAME_STATE_PATH):
		return true
	return not ziskej_save_sloty().is_empty()

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

func nacti_hru_ze_slotu(slot_name: String) -> bool:
	var slot_path = _cesta_slotu_save(slot_name)
	var state = _nacti_state_z_cesty(slot_path)
	return _aplikuj_save_state(state)

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
	var map_loader = get_tree().current_scene
	if map_loader and map_loader.has_method("zpracuj_tah_armad"):
		return map_loader
	if map_loader:
		var child_map = map_loader.find_child("Map", true, false)
		if child_map and child_map.has_method("zpracuj_tah_armad"):
			return child_map
	return null

func _normalizuj_tag(tag: String) -> String:
	return tag.strip_edges().to_upper()

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
	return _ziskej_ekonomicke_modifikatory_ideologie(_ziskej_ideologii_statu(state_tag))

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
		return {"ok": false, "reason": "Neplatný stát."}
	if target_ideology == "":
		return {"ok": false, "reason": "Neplatná ideologie."}
	if not _stat_existuje(state):
		return {"ok": false, "reason": "Stát neexistuje v aktuální mapě."}

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
		return {"ok": false, "reason": "Neplatný stát."}
	if target_ideology == "":
		return {"ok": false, "reason": "Neplatná ideologie."}
	if not _stat_existuje(state):
		return {"ok": false, "reason": "Stát neexistuje v aktuální mapě."}

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

func daruj_penize_statu(odesilatel: String, prijemce: String, amount: float) -> Dictionary:
	var from_tag = _normalizuj_tag(odesilatel)
	var to_tag = _normalizuj_tag(prijemce)
	var castka = maxf(0.0, amount)

	if from_tag == "" or to_tag == "" or from_tag == to_tag:
		return {"ok": false, "reason": "Neplatné státy pro dar."}
	if from_tag == "SEA" or to_tag == "SEA":
		return {"ok": false, "reason": "Mořským provinciím nelze posílat dary."}
	if castka <= 0.0:
		return {"ok": false, "reason": "Částka daru musí být větší než 0."}
	if not _stat_existuje(from_tag) or not _stat_existuje(to_tag):
		return {"ok": false, "reason": "Jeden ze států neexistuje v aktuální mapě."}

	var kasa_odesilatel = _ziskej_kasu_statu(from_tag)
	if kasa_odesilatel + 0.0001 < castka:
		return {"ok": false, "reason": "Nedostatek prostředků v kase."}

	var kasa_prijemce = _ziskej_kasu_statu(to_tag)
	_nastav_kasu_statu(from_tag, kasa_odesilatel - castka)
	_nastav_kasu_statu(to_tag, kasa_prijemce + castka)

	var rel_delta = clamp(castka / 20.0, 1.0, 15.0)
	var new_rel = _uprav_vztah_statu_bez_cooldown(from_tag, to_tag, rel_delta)

	if je_lidsky_stat(from_tag) or je_lidsky_stat(to_tag):
		_pridej_popup_zucastnenym_hracum(
			from_tag,
			to_tag,
			"DIPLOMACIE",
			"%s poslal finanční dar %.2f mil. USD státu %s (vztah %+0.1f)." % [from_tag, castka, to_tag, rel_delta]
		)
	_zaloguj_globalni_zpravu(
		"Dary",
		"%s poslal financni dar %.2f mil. USD statu %s (vztah %+0.1f)." % [from_tag, castka, to_tag, rel_delta],
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
	_vztahy_statu[_klic_vztahu(a, b)] = updated
	_vztahy_statu[_klic_vztahu(b, a)] = updated
	_ai_relation_cache[_klic_vztah_pair(a, b)] = updated
	_ai_can_adjust_relation_cache[_klic_vztah_pair(a, b)] = false
	_ai_allies_cache.clear()
	_vztah_akce_posledni_kolo[_klic_vztah_pair(a, b)] = aktualni_kolo
	if not is_zero_approx(delta):
		var action_txt = "zlepsil" if delta > 0.0 else "zhorsil"
		_zaloguj_globalni_zpravu("Vztahy", "%s %s vztah k %s na %.1f." % [a, action_txt, b, updated], "relations")
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
	_vztahy_statu[_klic_vztahu(a, b)] = updated
	_vztahy_statu[_klic_vztahu(b, a)] = updated
	_ai_relation_cache[_klic_vztah_pair(a, b)] = updated
	_ai_can_adjust_relation_cache.erase(_klic_vztah_pair(a, b))
	_ai_allies_cache.clear()
	if not is_zero_approx(delta):
		var action_txt = "zlepsil" if delta > 0.0 else "zhorsil"
		_zaloguj_globalni_zpravu("Vztahy", "%s %s vztah k %s na %.1f." % [a, action_txt, b, updated], "relations")
	_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return updated

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
			return "Obranna aliance"
		ALLIANCE_OFFENSE:
			return "Utocna aliance"
		ALLIANCE_FULL:
			return "Plna aliance"
		_:
			return "Bez aliance"

func _ma_stat_prijmout_alianci(tag_a: String, tag_b: String, target_level: int) -> bool:
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
			_ai_war_pair_eval_cache.clear()
		return
	aliance_statu[key] = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if _ai_phase_cache_active:
		_ai_alliance_level_cache[key] = int(aliance_statu[key])
		_ai_allies_cache.clear()
		_ai_war_pair_eval_cache.clear()

func nastav_uroven_aliance(tag_a: String, tag_b: String, level: int, ignoruj_vztahove_podminky: bool = false) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	var target_level = clamp(level, ALLIANCE_NONE, ALLIANCE_FULL)
	if a == "" or b == "" or a == b:
		return false

	if jsou_ve_valce(a, b):
		if target_level > ALLIANCE_NONE:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "Alianci nelze uzavřít během aktivní války.")
			return false

	var old_level = ziskej_uroven_aliance(a, b)
	if target_level > ALLIANCE_NONE:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if (not ignoruj_vztahove_podminky) and target_level > old_level and not _ma_stat_prijmout_alianci(a, b, target_level):
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				if rel < ALLIANCE_HARD_REJECT_REL:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "%s a %s se nemají rádi (vztah %.1f), aliance odmítnuta." % [a, b, rel])
				else:
					_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "%s odmítá %s: pro %s je potřeba vztah alespoň %.1f." % [b, a, nazev_urovne_aliance(target_level), needed_rel])
			return false
		if (not ignoruj_vztahove_podminky) and rel < needed_rel:
			if je_lidsky_stat(a) or je_lidsky_stat(b):
				_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "Vztah %.1f je příliš nízký pro %s (potřeba %.1f)." % [rel, nazev_urovne_aliance(target_level), needed_rel])
			return false

	_nastav_uroven_aliance_bez_kontroly(a, b, target_level)

	if old_level != target_level:
		_zaloguj_globalni_zpravu("Aliance", "Aliance mezi %s a %s: %s." % [a, b, nazev_urovne_aliance(target_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var title = "Diplomacie"
			var text = "Aliance mezi %s a %s: %s" % [a, b, nazev_urovne_aliance(target_level)]
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
		_zaloguj_globalni_zpravu("Aliance", "Vztahy oslabily alianci %s-%s: %s." % [a, b, nazev_urovne_aliance(new_level)], "alliance")
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			var text = "Vztahy oslabily alianci %s-%s: %s" % [a, b, nazev_urovne_aliance(new_level)]
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", text)

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
			_pridej_popup_hraci(a, "Diplomacie", "Žádost o alianci už byla odeslána. Čeká se na odpověď.")
		return false

	if not ignoruj_vztahove_podminky:
		var rel = ziskej_vztah_statu(a, b)
		var needed_rel = _minimalni_vztah_pro_alianci(target_level)
		if rel < needed_rel:
			if je_lidsky_stat(a):
				_pridej_popup_hraci(a, "Diplomacie", "Pro %s je potřeba vztah alespoň %.1f." % [nazev_urovne_aliance(target_level), needed_rel])
			return false

	cekajici_aliancni_zadosti.append({
		"from": a,
		"to": b,
		"level": target_level,
		"turn": aktualni_kolo
	})
	_zaloguj_globalni_zpravu("Aliance", "%s poslal %s zadost o %s." % [a, b, nazev_urovne_aliance(target_level)], "alliance")
	if je_lidsky_stat(a):
		_pridej_popup_hraci(a, "Diplomacie", "Žádost o %s byla odeslána státu %s." % [nazev_urovne_aliance(target_level), b])
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
			_zaloguj_globalni_zpravu("Aliance", "%s odmitl zadost %s o %s." % [to_tag, from_tag, nazev_urovne_aliance(level)], "alliance")
			if je_lidsky_stat(from_tag):
				_pridej_popup_hraci(from_tag, "Diplomacie", "Stát %s odmítl tvou žádost o %s." % [to_tag, nazev_urovne_aliance(level)])

func uzavrit_neagresivni_smlouvu(tag_a: String, tag_b: String) -> bool:
	var a = _normalizuj_tag(tag_a)
	var b = _normalizuj_tag(tag_b)
	if a == "" or b == "" or a == b or a == "SEA" or b == "SEA":
		return false
	if jsou_ve_valce(a, b):
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "Neagresivní smlouvu nelze uzavřít během války.")
		return false

	var rel = ziskej_vztah_statu(a, b)
	if rel < NON_AGGRESSION_MIN_REL:
		if je_lidsky_stat(a) or je_lidsky_stat(b):
			_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "Neagresivní smlouva vyžaduje vztah alespoň %.1f." % NON_AGGRESSION_MIN_REL)
		return false

	var key = _klic_pair(a, b)
	if key == "":
		return false

	neagresivni_smlouvy[key] = aktualni_kolo + NON_AGGRESSION_DURATION_TURNS - 1
	_zaloguj_globalni_zpravu("Diplomacie", "%s a %s uzavrely neagresivni smlouvu na %d kol." % [a, b, NON_AGGRESSION_DURATION_TURNS], "diplomacy")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, "Diplomacie", "%s a %s uzavřely neagresivní smlouvu na %d kol." % [a, b, NON_AGGRESSION_DURATION_TURNS])
	return true

func _pridej_diplomatickou_zadost(from_tag: String, to_tag: String, req_type: String, alliance_level: int = ALLIANCE_NONE) -> bool:
	var from_clean = _normalizuj_tag(from_tag)
	var to_clean = _normalizuj_tag(to_tag)
	if from_clean == "" or to_clean == "" or from_clean == to_clean:
		return false

	if req_type != "alliance" and req_type != "non_aggression" and req_type != "peace":
		return false

	if not _je_essential_diplomaticka_zadost(from_clean, to_clean, req_type, alliance_level):
		return false

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
			_zaloguj_globalni_zpravu("Diplomacie", "%s aktualizoval diplomatickou nabidku pro %s (%s)." % [from_clean, to_clean, req_type], "diplomacy")
			return true
		return false

	queue.append(new_req)
	if req_type == "alliance":
		_zaloguj_globalni_zpravu("Aliance", "%s poslal %s navrh aliance (%s)." % [from_clean, to_clean, nazev_urovne_aliance(alliance_level)], "alliance")
	elif req_type == "peace":
		_zaloguj_globalni_zpravu("Diplomacie", "%s poslal %s navrh miru." % [from_clean, to_clean], "diplomacy")
	elif req_type == "non_aggression":
		_zaloguj_globalni_zpravu("Diplomacie", "%s navrhl %s neagresivni smlouvu." % [from_clean, to_clean], "diplomacy")
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

func hrac_prijmi_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	var player_clean = _normalizuj_tag(hrac_tag)
	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false

	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatickou nabidku"
	if req_type == "alliance":
		req_name = "nabidku aliance"
	elif req_type == "peace":
		req_name = "nabidku miru"
	elif req_type == "non_aggression":
		req_name = "nabidku neagresivni smlouvy"
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
			_zaloguj_globalni_zpravu("Diplomacie", "%s prijal od %s %s." % [player_clean, sender, req_name], "diplomacy")
		return alliance_ok
	if req_type == "non_aggression":
		var nap_ok = uzavrit_neagresivni_smlouvu(player_clean, sender)
		if nap_ok:
			_zaloguj_globalni_zpravu("Diplomacie", "%s prijal od %s %s." % [player_clean, sender, req_name], "diplomacy")
		return nap_ok
	if req_type == "peace":
		if not jsou_ve_valce(player_clean, sender):
			return false
		_uzavri_mir_mezi(player_clean, sender)
		if je_lidsky_stat(player_clean) or je_lidsky_stat(sender):
			_pridej_popup_zucastnenym_hracum(player_clean, sender, "Diplomacie", "Mirova nabidka prijata: %s a %s uzavrely mir." % [player_clean, sender])
		_zaloguj_globalni_zpravu("Diplomacie", "%s prijal od %s %s." % [player_clean, sender, req_name], "diplomacy")
		return true
	_zaloguj_globalni_zpravu("Diplomacie", "%s prijal od %s %s." % [player_clean, sender, req_name], "diplomacy")
	return false

func hrac_odmitni_diplomatickou_zadost(hrac_tag: String, from_tag: String) -> bool:
	var player_clean = _normalizuj_tag(hrac_tag)
	var req = _odeber_diplomatickou_zadost(player_clean, from_tag)
	if req.is_empty():
		return false

	var sender = _normalizuj_tag(str(req.get("from", "")))
	var req_type = str(req.get("type", ""))
	var req_name = "diplomatickou nabidku"
	if req_type == "alliance":
		req_name = "nabidku aliance"
	elif req_type == "peace":
		req_name = "nabidku miru"
	elif req_type == "non_aggression":
		req_name = "nabidku neagresivni smlouvy"
	if je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacie", "Odmítl jsi diplomatickou žádost od státu %s." % sender)
	_zaloguj_globalni_zpravu("Diplomacie", "%s odmitl od %s %s." % [player_clean, sender, req_name], "diplomacy")
	return true

func hrac_odmitni_vsechny_diplomaticke_zadosti(hrac_tag: String) -> int:
	var player_clean = _normalizuj_tag(hrac_tag)
	if player_clean == "":
		return 0
	if not cekajici_diplomaticke_zadosti.has(player_clean):
		return 0

	var queue = cekajici_diplomaticke_zadosti[player_clean] as Array
	var count = queue.size()
	if count <= 0:
		return 0

	queue.clear()
	if je_lidsky_stat(player_clean):
		_pridej_popup_hraci(player_clean, "Diplomacie", "Odmítl jsi všechny čekající diplomatické žádosti (%d)." % count)
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
		_pridej_popup_hraci(player_clean, "Diplomacie", "Přijal jsi čekající diplomatické žádosti (%d)." % accepted)
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
	print(msg.replace("\n\n", " "))
	_zaloguj_globalni_zpravu("Valka", "%s vyhlasil valku statu %s." % [a, b], "war")
	if je_lidsky_stat(a) or je_lidsky_stat(b):
		_pridej_popup_zucastnenym_hracum(a, b, "DIPLOMACIE", msg)
	_aplikuj_diplomatickou_reakci_na_agresi(a, b)

	_synchronizuj_aliance_po_zmene_vztahu(a, b)
	return true

func _aplikuj_diplomatickou_reakci_na_agresi(utocnik: String, obrance: String) -> void:
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "" or attacker == defender:
		return

	var reakce_na_hrace: Dictionary = {}
	var reakce_na_utocnika: Array = []

	for stat in _ziskej_aktivni_staty():
		var observer = _normalizuj_tag(str(stat))
		if observer == "" or observer == "SEA":
			continue
		if observer == attacker or observer == defender:
			continue
		if jsou_ve_valce(observer, defender):
			continue

		var rel_to_defender = ziskej_vztah_statu(observer, defender)
		if rel_to_defender < AI_FRIEND_RELATION_THRESHOLD:
			continue

		var old_rel_to_attacker = ziskej_vztah_statu(observer, attacker)
		var new_rel_to_attacker = _uprav_vztah_statu_bez_cooldown(observer, attacker, -AGGRESSION_RELATION_PENALTY)
		if new_rel_to_attacker >= old_rel_to_attacker:
			continue

		if je_lidsky_stat(observer):
			if not reakce_na_hrace.has(observer):
				reakce_na_hrace[observer] = []
			(reakce_na_hrace[observer] as Array).append("Kvůli agresi státu %s vůči %s se tvůj vztah k %s zhoršil na %.1f." % [attacker, defender, attacker, new_rel_to_attacker])

		if je_lidsky_stat(attacker):
			reakce_na_utocnika.append("%s zhoršilo vztah k tobě (nově %.1f), protože jsi napadl stát %s." % [observer, new_rel_to_attacker, defender])

	for target_tag in reakce_na_hrace.keys():
		var lines = reakce_na_hrace[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacie", "\n".join(lines))

	if je_lidsky_stat(attacker) and not reakce_na_utocnika.is_empty():
		_pridej_popup_hraci(attacker, "Diplomacie", "\n".join(reakce_na_utocnika))

func _ma_byt_spojenec_povolan(state_tag: String, ally_tag: String, enemy_tag: String, min_alliance_level: int) -> bool:
	if state_tag == "" or ally_tag == "" or enemy_tag == "":
		return false
	if state_tag == ally_tag or state_tag == enemy_tag or ally_tag == enemy_tag:
		return false
	if ally_tag == "SEA":
		return false
	if ziskej_uroven_aliance(state_tag, ally_tag) < min_alliance_level:
		return false
	if jsou_ve_valce(ally_tag, state_tag):
		return false
	if jsou_ve_valce(ally_tag, enemy_tag):
		return false

	var alliance_vs_enemy = ziskej_uroven_aliance(ally_tag, enemy_tag)
	var alliance_vs_state = ziskej_uroven_aliance(ally_tag, state_tag)
	if alliance_vs_enemy > alliance_vs_state:
		return false

	if ziskej_vztah_statu(ally_tag, enemy_tag) >= AI_FRIEND_RELATION_THRESHOLD:
		return false

	return true

func _aktivuj_aliance_po_vyhlaseni_valky(utocnik: String, obrance: String) -> void:
	var attacker = _normalizuj_tag(utocnik)
	var defender = _normalizuj_tag(obrance)
	if attacker == "" or defender == "":
		return

	# Defensive call: defender's defense/full allies join against attacker.
	for ally in _ziskej_spojence_s_min_alianci(defender, ALLIANCE_DEFENSE):
		var ally_tag = _normalizuj_tag(str(ally))
		if not _ma_byt_spojenec_povolan(defender, ally_tag, attacker, ALLIANCE_DEFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag,
			attacker,
			"🛡️ OBRANNÁ ALIANCE",
			"%s vstoupilo do války na obranu spojence %s proti státu %s." % [ally_tag, defender, attacker]
		)

	# Offensive call: attacker's offense/full allies join against defender.
	for ally in _ziskej_spojence_s_min_alianci(attacker, ALLIANCE_OFFENSE):
		var ally_tag2 = _normalizuj_tag(str(ally))
		if not _ma_byt_spojenec_povolan(attacker, ally_tag2, defender, ALLIANCE_OFFENSE):
			continue
		_vyhlasit_valku_par(
			ally_tag2,
			defender,
			"⚔️ ÚTOČNÁ ALIANCE",
			"%s vstoupilo do války po boku spojence %s proti státu %s." % [ally_tag2, attacker, defender]
		)

func vyhlasit_valku(utocnik: String, obrance: String):
	var a = _normalizuj_tag(utocnik)
	var b = _normalizuj_tag(obrance)
	if a == "" or b == "" or a == b or b == "SEA":
		return false
	if jsou_ve_valce(a, b):
		return false
	var zbyva_povalecny_cooldown = zbyva_kol_do_dalsi_valky(a, b)
	if zbyva_povalecny_cooldown > 0:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacie", "Po uzavření míru musíš vyčkat ještě %d kol, než můžeš znovu vyhlásit válku státu %s." % [zbyva_povalecny_cooldown, b])
		return false
	if ma_neagresivni_smlouvu(a, b):
		if je_lidsky_stat(a):
			var zbyva = zbyva_kol_neagresivni_smlouvy(a, b)
			_pridej_popup_hraci(a, "Diplomacie", "Nelze vyhlásit válku, dokud běží neagresivní smlouva se státem %s (%d kol)." % [b, zbyva])
		return false

	if ziskej_uroven_aliance(a, b) > ALLIANCE_NONE:
		if je_lidsky_stat(a):
			_pridej_popup_hraci(a, "Diplomacie", "Nelze vyhlásit válku spojenci (%s). Nejprve zruš alianci." % b)
		return false

	var created = _vyhlasit_valku_par(
		a,
		b,
		"⚠️ VÁLKA!",
		"Stát %s právě vyhlásil válku státu %s!" % [a, b]
	)
	if not created:
		return false

	_aktivuj_aliance_po_vyhlaseni_valky(a, b)
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
			print("Mirova zadost hraci odeslana: %s -> %s" % [cisty_tag1, cisty_tag2])
		return

	cekajici_mirove_nabidky.append({
		"from": cisty_tag1,
		"to": cisty_tag2,
		"turn": aktualni_kolo
	})

	print("Mirova nabidka odeslana: %s -> %s" % [cisty_tag1, cisty_tag2])

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

func _uzavri_mir_mezi(tag1: String, tag2: String):
	var cisty_tag1 = tag1.strip_edges().to_upper()
	var cisty_tag2 = tag2.strip_edges().to_upper()
	var klic1 = cisty_tag1 + "_" + cisty_tag2
	var klic2 = cisty_tag2 + "_" + cisty_tag1
	_zaloguj_globalni_zpravu("Valka", "%s a %s uzavrely mir." % [cisty_tag1, cisty_tag2], "war")

	valky.erase(klic1)
	valky.erase(klic2)
	_nastav_povalecny_cooldown(cisty_tag1, cisty_tag2)
	_prepis_okupace_po_miru(cisty_tag1, cisty_tag2)

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

func _spocitej_silu_statu(tag: String) -> int:
	var hledany = tag.strip_edges().to_upper()
	if hledany == "":
		return 0
	if _turn_cache_valid and _turn_state_soldier_power.has(hledany):
		return int(_turn_state_soldier_power[hledany])
	var sila := 0
	for p_id in map_data:
		var d = map_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() == hledany:
			sila += int(d.get("soldiers", 0))
	return sila

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

func _invalidate_turn_cache() -> void:
	_turn_cache_valid = false
	_turn_state_soldier_power.clear()
	_turn_state_hdp.clear()
	_turn_border_pairs.clear()
	_turn_active_states.clear()
	_turn_state_owned_provinces.clear()

func _rebuild_turn_cache() -> void:
	_invalidate_turn_cache()

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

		for n_id in d.get("neighbors", []):
			if not map_data.has(n_id):
				continue
			var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
			if n_owner == "" or n_owner == "SEA" or n_owner == owner_tag:
				continue
			var pair_key = _klic_pair(owner_tag, n_owner)
			if pair_key != "":
				_turn_border_pairs[pair_key] = true

	_turn_active_states = active.keys()
	_turn_cache_valid = true

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
	var zmeny_vztahu_k_hraci: Array = []
	for ai_tag in ai_staty:
		var owner_tag = _normalizuj_tag(str(ai_tag))
		if owner_tag == "":
			continue

		var our_power = float(max(1, _spocitej_silu_statu(owner_tag)))
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
			var their_power = float(max(1, _spocitej_silu_statu(other_tag)))
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
			(lines_by_target[a] as Array).append("Neagresivní smlouva se státem %s (%d kol)." % [b, NON_AGGRESSION_DURATION_TURNS])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Neagresivní smlouva se státem %s (%d kol)." % [a, NON_AGGRESSION_DURATION_TURNS])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacie", "\n".join(lines))

func _zpracuj_ai_opusteni_alianci(ai_staty: Array) -> Array:
	var zmeny_opusteni: Array = []
	var processed_pairs: Dictionary = {}
	var aktivni_staty = _ziskej_aktivni_staty()
	var aktivni_staty_norm: Array = []
	for s in aktivni_staty:
		var t = _normalizuj_tag(str(s))
		if t != "":
			aktivni_staty_norm.append(t)

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

			_nastav_uroven_aliance_bez_kontroly(owner_tag, other_tag, ALLIANCE_NONE)
			if je_lidsky_stat(owner_tag) or je_lidsky_stat(other_tag):
				zmeny_opusteni.append({
					"a": owner_tag,
					"b": other_tag,
					"rel": rel
				})

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
			(lines_by_target[a] as Array).append("Stát %s opustil alianci (vztah %.1f)." % [b, rel])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Stát %s opustil alianci (vztah %.1f)." % [a, rel])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Aliance", "\n".join(lines))

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
			(lines_by_target[a] as Array).append("Aliance se statem %s: %s" % [b, nazev_urovne_aliance(level)])
		if je_lidsky_stat(b):
			if not lines_by_target.has(b):
				lines_by_target[b] = []
			(lines_by_target[b] as Array).append("Aliance se statem %s: %s" % [a, nazev_urovne_aliance(level)])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Aliance", "\n".join(lines))

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
			(lines_by_target[target] as Array).append("%s zlepsil vztah k tobe. Novy vztah: %.1f" % [stat, rel])
		else:
			(lines_by_target[target] as Array).append("%s zhorsil vztah k tobe. Novy vztah: %.1f" % [stat, rel])

	for target_tag in lines_by_target.keys():
		var lines = lines_by_target[target_tag] as Array
		if lines.is_empty():
			continue
		_pridej_popup_hraci(str(target_tag), "Diplomacie", "\n".join(lines))

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
			_uzavri_mir_mezi(odesilatel, prijemce)
			var ok_msg = "Mirova nabidka prijata: %s a %s uzavrely mir." % [odesilatel, prijemce]
			print(ok_msg)
			_zaloguj_globalni_zpravu("Diplomacie", ok_msg, "diplomacy")
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACIE", ok_msg)
		else:
			var no_msg = "Mirova nabidka odmitnuta: %s odmitlo mir se statem %s." % [prijemce, odesilatel]
			print(no_msg)
			_zaloguj_globalni_zpravu("Diplomacie", no_msg, "diplomacy")
			if je_lidsky_stat(odesilatel) or je_lidsky_stat(prijemce):
				_pridej_popup_zucastnenym_hracum(odesilatel, prijemce, "DIPLOMACIE", no_msg)

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
		"Valka",
		"%s obsadilo hlavni mesto statu %s. Pokud ho udrzi do dalsiho kola, nasleduje kapitulace." % [uto, obr],
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

func muze_ukoncit_kolo() -> bool:
	if zpracovava_se_tah:
		return false
	var elapsed = Time.get_ticks_msec() - _last_end_turn_request_ms
	return elapsed >= NEXT_TURN_INPUT_COOLDOWN_MS

func pozaduj_ukonceni_kola() -> bool:
	if not muze_ukoncit_kolo():
		return false
	_last_end_turn_request_ms = Time.get_ticks_msec()
	ukonci_kolo()
	return true

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
		_nastav_stav_zpracovani_tahu(false)
		_log_turn_profile(Time.get_ticks_msec() - turn_start_ms, turn_phases)
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
	
	var hotove_stavby = []
	var hlaseni_dokoncene_stavby: Dictionary = {}
	for prov_id in provincie_cooldowny.keys():
		provincie_cooldowny[prov_id]["zbyva"] -= 1 
		if provincie_cooldowny[prov_id]["zbyva"] <= 0:
			hotove_stavby.append(prov_id)
			
	for prov_id in hotove_stavby:
		var typ_budovy = provincie_cooldowny[prov_id]["budova"]
		provincie_cooldowny.erase(prov_id)
		_aplikuj_bonus(prov_id, typ_budovy)
		if typ_budovy == 2 and map_data.has(prov_id):
			var nazev = str(map_data[prov_id].get("province_name", "Provincie %d" % int(prov_id)))
			var owner_tag = _normalizuj_tag(str(map_data[prov_id].get("owner", "")))
			if je_lidsky_stat(owner_tag):
				if not hlaseni_dokoncene_stavby.has(owner_tag):
					hlaseni_dokoncene_stavby[owner_tag] = []
				(hlaseni_dokoncene_stavby[owner_tag] as Array).append("Pristav dokoncen: %s" % nazev)

	if not map_data.is_empty():
		spocitej_prijem(map_data, false)
		var econ_mods_by_owner: Dictionary = {}
		
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
			_pridej_popup_hraci(str(owner_tag), "Hlaseni", "\n".join(lines))

	print("--- KOLO %d ---" % aktualni_kolo)
	
	if map_loader and map_loader.has_method("aktualizuj_ikony_armad"):
		map_loader.aktualizuj_ikony_armad()

	if lokalni_hraci_staty.size() > 1:
		_prepni_na_hrace(0)
		if not map_data.is_empty():
			spocitej_prijem(map_data, false)
	await _zobraz_cekajici_popupy_aktivniho_hrace()
	turn_phases["popups"] = int(turn_phases["popups"]) + (Time.get_ticks_msec() - phase_start_ms)
	phase_start_ms = Time.get_ticks_msec()
	kolo_zmeneno.emit()
	turn_phases["ui"] = int(turn_phases["ui"]) + (Time.get_ticks_msec() - phase_start_ms)
		
	_nastav_stav_zpracovani_tahu(false)
	_log_turn_profile(Time.get_ticks_msec() - turn_start_ms, turn_phases)

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
			_pridej_popup_hraci(tag, "STÁTNÍ BANKROT", "Dosly penize! %d vojaku dezertovalo." % celkem_dezertovalo)
		else:
			print("📉 BANKROT AI (%s): %d vojaku dezertovalo." % [tag, celkem_dezertovalo])

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

# AI logic

func zpracuj_tah_ai():
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
	_rebuild_turn_cache()
	var ai_staty = _ziskej_ai_staty()
	ai_phases["setup"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()
	_ai_phase_cache_active = true
	_set_defer_log_maintenance(true)

	# Evaluate pending peace offers before AI plans any attacks.
	_vyhodnot_mirove_nabidky_pred_ai()
	_vyhodnot_aliancni_zadosti_pred_ai()
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
		
	var cena_za_vojaka = 0.01

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

		for p_id in owned:
			if not map_data.has(p_id):
				continue
			var d_income = map_data[p_id]
			var gdp = float(d_income.get("gdp", 0.0))
			var vojaci = int(d_income.get("soldiers", 0))
			var prijem = (gdp * 0.1) - (vojaci * 0.001)
			ai_kasy[owner_tag] += prijem

		if ai_kasy[owner_tag] < -100.0:
			_vyres_bankrot(owner_tag)

		for p_id in owned:
			if not map_data.has(p_id):
				continue
			var d = map_data[p_id]
			var rekruti = int(d.get("recruitable_population", 0))
			var core_owner_tag = str(d.get("core_owner", owner_tag)).strip_edges().to_upper()
			var je_okupace = core_owner_tag != "" and core_owner_tag != owner_tag
			if je_okupace:
				rekruti = int(floor(float(rekruti) * 0.2))
			if rekruti > 300 and ai_kasy[owner_tag] > 50.0:
				var pocet_k_verbovani = min(rekruti, int(ai_kasy[owner_tag] / cena_za_vojaka))
				var frontline_bonus = 0
				if _ma_nepratelskeho_souseda(owner_tag, p_id):
					frontline_bonus += 700
				if bool(d.get("is_capital", false)):
					frontline_bonus += 500
				var hrozba = _spocitej_hrozbu_nepratel_u_provincie(p_id, owner_tag)
				frontline_bonus += min(900, int(float(hrozba) * 0.15))
				var limit_verbovani = min(2500, 900 + frontline_bonus)
				if je_okupace:
					limit_verbovani = int(max(120, floor(float(limit_verbovani) * 0.25)))
				pocet_k_verbovani = min(pocet_k_verbovani, limit_verbovani)
				d["recruitable_population"] -= pocet_k_verbovani
				d["soldiers"] += pocet_k_verbovani
				ai_kasy[owner_tag] -= (pocet_k_verbovani * cena_za_vojaka)
	ai_phases["economy_recruit"] = Time.get_ticks_msec() - ai_phase_ms
	ai_phase_ms = Time.get_ticks_msec()

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
	_invalidate_turn_cache()
	ai_phases["cleanup"] = Time.get_ticks_msec() - ai_phase_ms
	_log_ai_profile(Time.get_ticks_msec() - ai_start_ms, ai_phases)
				
	print("--- AI THINKING END ---")

func _naplanuj_ai_presuny(map_loader):
	var ai_staty = _ziskej_ai_staty()

	if map_loader.has_method("zacni_davkovy_presun"):
		map_loader.zacni_davkovy_presun()

	for owner_tag in ai_staty:
		var moved_from: Dictionary = {}
		owner_tag = str(owner_tag)
		var serazene: Array = _seradene_ai_provincie(owner_tag)
		var core_state: String = _ziskej_core_state_cached(owner_tag)

		# 1) Internal non-attacking relocation (rear to frontline by adjacent friendly move).
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_neutocny_presun(owner_tag, p_id)
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
			moved_from[move["from"]] = true

		# 2) Defense of core provinces (capital and provinces in the capital's state).
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_core_obranu(owner_tag, p_id, core_state)
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
			moved_from[move["from"]] = true

		# 3) Offensive attacks.
		for p_id in serazene:
			if moved_from.has(p_id):
				continue
			var move = _navrhni_utok(owner_tag, p_id)
			if move.is_empty():
				continue
			var amount = int(move.get("amount", 0))
			if amount <= 0:
				continue

			var target_owner = str(map_data[move["to"]].get("owner", "")).strip_edges().to_upper()
			if jsou_ve_valce(owner_tag, target_owner):
				map_loader.zaregistruj_presun_armady(
					int(move["from"]),
					int(move["to"]),
					amount,
					false,
					[int(move["from"]), int(move["to"])]
				)
				moved_from[move["from"]] = true
			else:
				if _ma_smyls_vyhlasit_valku(owner_tag, target_owner, int(move["from"]), int(move["to"]), amount):
					vyhlasit_valku(owner_tag, target_owner)
					if jsou_ve_valce(owner_tag, target_owner):
						map_loader.zaregistruj_presun_armady(
							int(move["from"]),
							int(move["to"]),
							amount,
							false,
							[int(move["from"]), int(move["to"])]
						)
						moved_from[move["from"]] = true

	if map_loader.has_method("ukonci_davkovy_presun"):
		map_loader.ukonci_davkovy_presun()

func _seradene_ai_provincie(state_tag: String) -> Array:
	var ids: Array = []
	if _turn_cache_valid and _turn_state_owned_provinces.has(state_tag):
		for p_id in (_turn_state_owned_provinces[state_tag] as Array):
			if not map_data.has(p_id):
				continue
			var d = map_data[p_id]
			if int(d.get("soldiers", 0)) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
				ids.append(p_id)
	else:
		for p_id in map_data:
			var d = map_data[p_id]
			if str(d.get("owner", "")).strip_edges().to_upper() == state_tag:
				if int(d.get("soldiers", 0)) >= AI_MIN_PROVINCE_SOLDIERS_FOR_PLANNING:
					ids.append(p_id)

	ids.sort_custom(func(a, b):
		return int(map_data[a].get("soldiers", 0)) > int(map_data[b].get("soldiers", 0))
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
	for n_id in map_data[province_id].get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
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
	for n_id in map_data[province_id].get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_owner = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner):
			continue
		threat += int(map_data[n_id].get("soldiers", 0))
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
			var d_our = map_data[p_id]
			var soldiers_our = int(d_our.get("soldiers", 0))
			for n_id in d_our.get("neighbors", []):
				if not map_data.has(n_id):
					continue
				var n_owner_our = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
				if n_owner_our == enemy:
					our_border += soldiers_our
					break

		for p_id in (_turn_state_owned_provinces[enemy] as Array):
			if not map_data.has(p_id):
				continue
			var d_enemy = map_data[p_id]
			var soldiers_enemy = int(d_enemy.get("soldiers", 0))
			for n_id in d_enemy.get("neighbors", []):
				if not map_data.has(n_id):
					continue
				var n_owner_enemy = str(map_data[n_id].get("owner", "")).strip_edges().to_upper()
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
	if _je_pratelsky_vztah_ai_cached(state_tag, target_owner):
		out["blocked"] = true
		_ai_war_pair_eval_cache[key] = out
		return out

	var rel = _ziskej_ai_vztah_cached(state_tag, target_owner)
	if rel > AI_DECLARE_WAR_MAX_RELATION:
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
	if amount < AI_DECLARE_WAR_MIN_ATTACK_FORCE:
		return false
	if not map_data.has(from_id) or not map_data.has(to_id):
		return false

	var pair_eval: Dictionary = _ziskej_ai_war_pair_eval_cached(state_tag, target_owner)
	if not pair_eval.is_empty() and bool(pair_eval.get("blocked", false)):
		return false

	var ratio = float(pair_eval.get("border_ratio", 0.0))
	var required_local_ratio = float(pair_eval.get("required_local_ratio", 1.25))
	var strategic_ratio = float(pair_eval.get("strategic_ratio", 0.0))

	if pair_eval.is_empty():
		# Fallback path when AI phase cache is not active.
		if _ziskej_uroven_aliance_ai_cached(state_tag, target_owner) > ALLIANCE_NONE:
			return false
		if _je_pratelsky_vztah_ai_cached(state_tag, target_owner):
			return false
		var rel = _ziskej_ai_vztah_cached(state_tag, target_owner)
		if rel > AI_DECLARE_WAR_MAX_RELATION:
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

	return ratio >= AI_DECLARE_WAR_MIN_BORDER_ADVANTAGE and local_ratio >= required_local_ratio and strategic_ratio >= 0.85

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

func _navrhni_neutocny_presun(state_tag: String, from_id: int) -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci < 1400:
		return {}

	# Keep frontline stacks in place for attacks/defense phases.
	if _ma_nepratelskeho_souseda(state_tag, from_id):
		return {}

	var best_target = -1
	var best_score = -INF
	for n_id in from_data.get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_data = map_data[n_id]
		var n_owner = str(n_data.get("owner", "")).strip_edges().to_upper()
		if n_owner != state_tag:
			continue

		var target_soldiers = int(n_data.get("soldiers", 0))
		var threatened = _ma_nepratelskeho_souseda(state_tag, n_id)
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
	if str(d.get("owner", "")).strip_edges().to_upper() != state_tag:
		return false
	if bool(d.get("is_capital", false)):
		return true
	if core_state != "" and str(d.get("state", "")) == core_state:
		return true
	return false

func _navrhni_core_obranu(state_tag: String, from_id: int, core_state: String = "") -> Dictionary:
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
	for n_id in from_data.get("neighbors", []):
		if not _je_core_provincie(state_tag, n_id, core_state):
			continue
		var n_soldiers = int(map_data[n_id].get("soldiers", 0))
		var score = (2600.0 - float(n_soldiers))
		if bool(map_data[n_id].get("is_capital", false)):
			score += 2200.0
		if _ma_nepratelskeho_souseda(state_tag, n_id):
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

func _navrhni_utok(state_tag: String, from_id: int) -> Dictionary:
	if not map_data.has(from_id):
		return {}
	var from_data = map_data[from_id]
	var vojaci = int(from_data.get("soldiers", 0))
	if vojaci <= 1000:
		return {}
	if not _ma_nepratelskeho_souseda(state_tag, from_id):
		return {}

	var best_target = -1
	var best_score = -INF
	var best_amount = 0
	var reserve = max(650, int(float(vojaci) * 0.25))
	var max_attack = vojaci - reserve
	if max_attack < 450:
		return {}

	for n_id in from_data.get("neighbors", []):
		if not map_data.has(n_id):
			continue
		var n_prov = map_data[n_id]
		var n_owner = str(n_prov.get("owner", "")).strip_edges().to_upper()
		if n_owner == state_tag or n_owner == "SEA":
			continue
		if not _jsou_ve_valce_ai_cached(state_tag, n_owner) and _je_pratelsky_vztah_ai_cached(state_tag, n_owner):
			continue

		var n_vojaci = int(n_prov.get("soldiers", 0))
		var threat_after_capture = _spocitej_hrozbu_nepratel_u_provincie(n_id, state_tag)
		var needed_for_push = int(float(n_vojaci) * 1.15) + int(float(threat_after_capture) * 0.15)
		var attack_amount = min(max_attack, int(float(vojaci) * 0.78))
		if attack_amount < max(550, needed_for_push):
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
		var enemy_core = _ziskej_core_state_cached(n_owner)
		if enemy_core != "" and str(n_prov.get("state", "")) == enemy_core:
			score += 900.0

		if score > best_score:
			best_score = score
			best_target = n_id
			best_amount = attack_amount

	if best_target == -1:
		return {}
	if best_score < 350.0:
		return {}

	return {
		"from": from_id,
		"to": best_target,
		"amount": best_amount
	}
