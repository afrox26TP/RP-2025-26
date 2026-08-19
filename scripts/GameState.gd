extends Node

## Shared mutable runtime state for the GameManager facade and domain managers.

# These members intentionally form protected shared state for descendant domain
# layers. Godot's per-file analyzer cannot see inherited usage from those files.
@warning_ignore_start("unused_signal")
@warning_ignore_start("unused_private_class_variable")

signal kolo_zmeneno
signal zpracovani_tahu_zmeneno(aktivni: bool)

var hrac_stat = "ALB"
var hrac_jmeno = ""
var hrac_ideologie = ""
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
var notifikace_pujcek_hracu: Dictionary = {}
var vyzkum_statu: Dictionary = {}
var armadni_lab_statu: Dictionary = {}
var _defer_log_maintenance: bool = false
var _log_maintenance_dirty: bool = false

var valky: Dictionary = {}
var cekajici_kapitulace: Array = []
var cekajici_mirove_nabidky: Array = []
var cekajici_mirove_konference: Dictionary = {}
var mirove_konference_seq: int = 0
var mirove_body_peak_dle_smeru: Dictionary = {}
var vazalske_vztahy: Dictionary = {}
var vazalske_odvody: Dictionary = {}
var vazalske_odvody_posledni_zmena_kolo: Dictionary = {}
var valecne_reparace: Array = []
var aktivni_pujcky: Array = []
var cekajici_pujcky: Array = []
var aliance_statu: Dictionary = {}
var aliance_skupiny: Dictionary = {}
var _aliance_skupiny_seq: int = 0
var neagresivni_smlouvy: Dictionary = {}
var vojensky_pristup: Dictionary = {}
var povalecne_cooldowny: Dictionary = {}
var cekajici_diplomaticke_zadosti: Dictionary = {}
var cekajici_aliancni_zadosti: Array = []

var zpracovava_se_tah: bool = false
var _last_end_turn_request_ms: int = -1000000
var _turn_watchdog_token: int = 0
var _queued_end_turn_requests: int = 0
var _presun_hlavniho_mesta_posledni_kolo: Dictionary = {}
var _core_state_cache: Dictionary = {}
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
var _ai_state_enemies_cache: Dictionary = {}
var _ai_capital_cache: Dictionary = {}
var _ai_econ_mods_cache: Dictionary = {}
var _ai_state_pressure_cache: Dictionary = {}
var _ai_state_core_defense_cache: Dictionary = {}
var _ai_cache_batch_depth: int = 0
var _ai_war_pair_eval_dirty_states: Dictionary = {}
var _ai_profily: Dictionary = {}
var _ai_mindset_cache: Dictionary = {}
var _ai_goal_cache: Dictionary = {}
var _ai_operation_plan_cache: Dictionary = {}
var _ai_war_exhaustion_cache: Dictionary = {}
var _ai_debug_turn_marker: int = -1
var _ai_debug_lines_this_turn: int = 0
var _ai_debug_suppressed_notice_printed: bool = false
var _ai_debug_last_spending_by_state: Dictionary = {}
var _debug_turn_history: Array = []
var _debug_turn_live_events: Array = []
var _debug_last_turn_profile: Dictionary = {}
var _debug_last_ai_profile: Dictionary = {}
var _finance_projection_cash_overrides: Dictionary = {}
var _sim_cache: Dictionary = {}
var _sim_cache_validni: bool = false
var _runtime_caches_warmed: bool = false
var _global_ai_aggression_level: float = 0.5
var _ai_randomized_ideologies_applied: bool = false
var _suppress_relation_global_logs: bool = false
var _map_loader_cache: Node = null
var _map_loader_cache_scene: Node = null
var _potato_mode_enabled: bool = false
var _ai_debug_mode_enabled: bool = false
var _spectate_mode_active: bool = false
var _ai_turn_state_cursor: int = 0
var _ai_fastmode_cached_subset: Array = []
var _ai_fastmode_cached_turn_marker: int = -1000000
