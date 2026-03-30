extends CanvasLayer


@onready var id_label = $PanelContainer/VBoxContainer/IDLabel
@onready var owner_label = $PanelContainer/VBoxContainer/OwnerLabel
@onready var terrain_label = $PanelContainer/VBoxContainer/TerrainLabel
@onready var pop_label = $PanelContainer/VBoxContainer/PopLabel
@onready var recruit_label = $PanelContainer/VBoxContainer/RecruitLabel
@onready var gdp_label = $PanelContainer/VBoxContainer/GdpLabel
@onready var income_label = $PanelContainer/VBoxContainer/IncomeLabel 
@onready var soldiers_label = $PanelContainer/VBoxContainer/SoldiersLabel 

@onready var action_menu = $ActionMenu
@onready var btn_stavet = $ActionMenu/HBoxContainer/StavetMenuButton 
@onready var btn_presunout = $ActionMenu/HBoxContainer/PresunoutButton
@onready var btn_verbovat = $ActionMenu/HBoxContainer/VerbovatButton
@onready var btn_likvidovat = $ActionMenu/HBoxContainer/LikvidovatButton

# Paths to the recruitment popup panel elements
@onready var recruit_popup = $ActionMenu/RecruitPopup
@onready var recruit_info = $ActionMenu/RecruitPopup/VBoxContainer/RecruitInfo
@onready var recruit_slider = $ActionMenu/RecruitPopup/VBoxContainer/RecruitSlider
@onready var btn_potvrdit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/PotvrditBtn
@onready var btn_zrusit = $ActionMenu/RecruitPopup/VBoxContainer/HBoxContainer/ZrusitBtn

# --- NEW: Paths to the Move popup panel elements ---
@onready var move_popup = $ActionMenu/MovePopup
@onready var move_count_label = $ActionMenu/MovePopup/VBoxContainer/CountLabel
@onready var move_slider = $ActionMenu/MovePopup/VBoxContainer/HSlider
@onready var btn_move_potvrdit = $ActionMenu/MovePopup/VBoxContainer/HBoxContainer/PotvrditButton
@onready var btn_move_zrusit = $ActionMenu/MovePopup/VBoxContainer/HBoxContainer/ZrusitButton

# Paths to the liquidation popup panel elements
@onready var likvidace_popup = $ActionMenu/LikvidacePopup
@onready var likvidace_info = $ActionMenu/LikvidacePopup/VBoxContainer/LikvidaceInfo
@onready var likvidace_slider = $ActionMenu/LikvidacePopup/VBoxContainer/LikvidaceSlider
@onready var btn_likvidace_potvrdit = $ActionMenu/LikvidacePopup/VBoxContainer/HBoxContainer/PotvrditButton
@onready var btn_likvidace_zrusit = $ActionMenu/LikvidacePopup/VBoxContainer/HBoxContainer/ZrusitButton

var presun_od_id: int = -1
var presun_do_id: int = -1
var presun_path: Array = []
var hromadny_vyber_ids: Array = []
var je_hromadny_rezim: bool = false
var je_hromadne_verbovani: bool = false
# ---------------------------------------------------

var aktualni_provincie_id: int = -1
var cena_za_vojaka: float = 0.05 # Cost: 50 mil. per 1000 men
var likvidace_vynos_za_vojaka: float = 0.01 # Small refund per removed soldier
var _preview_label: Label
var _metric_rows: Dictionary = {}
var _metric_deltas: Dictionary = {}
var _ideology_preview_active: bool = false
var _stavba_popup: PopupMenu
var _stavba_last_focus_idx: int = -2

func _ziskej_provincie_data() -> Dictionary:
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader and "provinces" in map_loader:
		return map_loader.provinces
	return GameManager.map_data

func _ziskej_map_loader():
	return get_tree().current_scene.find_child("Map", true, false)

func _format_pct_signed(value: float) -> String:
	var pct = int(round(value * 100.0))
	if pct >= 0:
		return "+%d%%" % pct
	return "%d%%" % pct

func _terenni_obranny_bonus_fallback(terrain_raw: String) -> float:
	var key = terrain_raw.strip_edges().to_lower()
	match key:
		"plains", "plain":
			return -0.20
		"forest":
			return 0.0
		"hills", "hill":
			return 0.20
		"mountains", "mountain":
			return 0.40
		"city":
			return 0.80
		_:
			return 0.0

func _ziskej_terenni_obranny_bonus_pro_data(data: Dictionary, terrain_raw: String) -> float:
	var prov_id = int(data.get("id", -1))
	var map_loader = _ziskej_map_loader()
	if map_loader and prov_id >= 0 and map_loader.has_method("ziskej_terenni_obranny_bonus_pct"):
		return float(map_loader.ziskej_terenni_obranny_bonus_pct(prov_id))
	return _terenni_obranny_bonus_fallback(terrain_raw)

func _ziskej_cenu_za_vojaka() -> float:
	if GameManager.has_method("ziskej_cenu_za_vojaka"):
		return float(GameManager.ziskej_cenu_za_vojaka(GameManager.hrac_stat))
	return cena_za_vojaka

func _ziskej_udrzbu_za_vojaka() -> float:
	if GameManager.has_method("ziskej_udrzbu_za_vojaka"):
		return float(GameManager.ziskej_udrzbu_za_vojaka(GameManager.hrac_stat))
	return 0.001

func _ziskej_prijmovou_sazbu_hdp() -> float:
	if GameManager.has_method("ziskej_prijmovou_sazbu_hdp"):
		return float(GameManager.ziskej_prijmovou_sazbu_hdp(GameManager.hrac_stat))
	return 0.1

func _limit_verbovani_v_okupaci(requested: int, prov_data: Dictionary) -> int:
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var core_owner = str(prov_data.get("core_owner", owner_tag)).strip_edges().to_upper()
	var je_okupace = owner_tag != "" and owner_tag != "SEA" and core_owner != "" and core_owner != owner_tag
	if not je_okupace:
		return max(0, requested)
	# Occupation allows only limited local recruitment each action.
	return int(max(0, floor(float(requested) * 0.2)))

func _ready():
	action_menu.hide()
	_setup_inline_delta_rows()
	_vytvor_preview_label()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	if GameManager.has_signal("kolo_zmeneno") and not GameManager.kolo_zmeneno.is_connected(_on_kolo_zmeneno):
		GameManager.kolo_zmeneno.connect(_on_kolo_zmeneno)
	
	var popup_stavba = btn_stavet.get_popup()
	_stavba_popup = popup_stavba
	popup_stavba.clear()
	popup_stavba.add_item("Civilian Factory (150M)", 0)
	popup_stavba.add_item("Arms Factory (200M)", 1)
	popup_stavba.add_item("Port (250M)", 2)
	popup_stavba.id_pressed.connect(_on_stavba_vybrana)
	popup_stavba.about_to_popup.connect(_posun_stavba_menu)
	if popup_stavba.has_signal("popup_hide"):
		popup_stavba.popup_hide.connect(_on_stavba_menu_zavreno)
	if popup_stavba.has_signal("id_focused"):
		popup_stavba.id_focused.connect(_on_stavba_zvyraznena)

	if btn_presunout: btn_presunout.pressed.connect(_on_presunout_pressed)
	btn_verbovat.pressed.connect(_on_verbovat_pressed)
	if btn_likvidovat: btn_likvidovat.pressed.connect(_on_likvidovat_pressed)
	recruit_slider.value_changed.connect(_on_slider_zmenen)
	btn_potvrdit.pressed.connect(_on_potvrdit_verbovani)
	btn_zrusit.pressed.connect(func(): recruit_popup.hide(); _clear_preview_text())
	
	# --- NEW: Připojení tlačítek pro přesun ---
	if move_slider: move_slider.value_changed.connect(_on_move_slider_zmenen)
	if btn_move_potvrdit: btn_move_potvrdit.pressed.connect(_on_potvrdit_presun)
	if btn_move_zrusit: btn_move_zrusit.pressed.connect(func(): move_popup.hide())

	if likvidace_slider: likvidace_slider.value_changed.connect(_on_likvidace_slider_zmenen)
	if btn_likvidace_potvrdit: btn_likvidace_potvrdit.pressed.connect(_on_potvrdit_likvidaci)
	if btn_likvidace_zrusit: btn_likvidace_zrusit.pressed.connect(func(): likvidace_popup.hide())
	_nastav_tooltipy_ui()

func _nastav_tooltipy_ui() -> void:
	id_label.tooltip_text = "Name of the selected province."
	owner_label.tooltip_text = "Current owner of the province."
	terrain_label.tooltip_text = "Terrain type in this province."
	pop_label.tooltip_text = "Province population."
	recruit_label.tooltip_text = "Available recruits in this province."
	gdp_label.tooltip_text = "Economic strength of this province."
	income_label.tooltip_text = "Province income for the owner."
	soldiers_label.tooltip_text = "Number of soldiers or fleet units."
	btn_stavet.tooltip_text = "Build a structure in this province."
	btn_presunout.tooltip_text = "Plan troop movement to another province."
	btn_verbovat.tooltip_text = "Recruit new soldiers for money."
	btn_likvidovat.tooltip_text = "Disband troops in this province and refund part of the cost."
	recruit_info.tooltip_text = "How many soldiers can be recruited."
	recruit_slider.tooltip_text = "Set number of recruits."
	btn_potvrdit.tooltip_text = "Confirm recruitment."
	btn_zrusit.tooltip_text = "Close recruitment window without changes."
	move_count_label.tooltip_text = "How many soldiers will be moved."
	move_slider.tooltip_text = "Set soldier amount for movement."
	btn_move_potvrdit.tooltip_text = "Confirm army movement."
	btn_move_zrusit.tooltip_text = "Cancel army movement."
	likvidace_info.tooltip_text = "How many soldiers will be removed."
	likvidace_slider.tooltip_text = "Set number of soldiers to remove."
	btn_likvidace_potvrdit.tooltip_text = "Confirm partial army disband."
	btn_likvidace_zrusit.tooltip_text = "Close disband window without changes."
	TooltipUtils.apply_default_tooltips(self)

func _vytvor_preview_label() -> void:
	if _preview_label and is_instance_valid(_preview_label):
		return
	var vbox = $PanelContainer/VBoxContainer
	_preview_label = Label.new()
	_preview_label.name = "ActionPreviewLabel"
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.visible = false
	vbox.add_child(_preview_label)

func _wrap_metric_label(key: String, base_label: Label) -> void:
	if base_label == null:
		return
	var parent = base_label.get_parent()
	if parent == null:
		return
	if _metric_rows.has(key):
		return

	var idx = base_label.get_index()
	parent.remove_child(base_label)

	var row = HBoxContainer.new()
	row.name = "MetricRow_%s" % key
	row.size_flags_horizontal = Control.SIZE_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	parent.move_child(row, idx)

	# Keep the value label compact so delta text stays attached to the number.
	base_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(base_label)

	var delta = Label.new()
	delta.name = "Delta_%s" % key
	delta.visible = false
	row.add_child(delta)

	_metric_rows[key] = row
	_metric_deltas[key] = delta

func _setup_inline_delta_rows() -> void:
	_wrap_metric_label("pop", pop_label)
	_wrap_metric_label("recruit", recruit_label)
	_wrap_metric_label("gdp", gdp_label)
	_wrap_metric_label("income", income_label)
	_wrap_metric_label("soldiers", soldiers_label)

func _set_metric_visible(key: String, metric_visible: bool) -> void:
	if _metric_rows.has(key):
		(_metric_rows[key] as Control).visible = metric_visible
	if not metric_visible:
		_set_metric_delta(key, "", Color.WHITE)

func _set_metric_delta(key: String, text: String, color: Color) -> void:
	if not _metric_deltas.has(key):
		return
	var lbl = _metric_deltas[key] as Label
	var clean = text.strip_edges()
	if clean == "":
		lbl.visible = false
		lbl.text = ""
		return
	lbl.text = "(%s)" % clean
	lbl.add_theme_color_override("font_color", color)
	lbl.visible = true

func _clear_inline_deltas() -> void:
	for key in _metric_deltas.keys():
		_set_metric_delta(str(key), "", Color.WHITE)

func _set_preview_text(text: String) -> void:
	if not _preview_label:
		return
	var clean = text.strip_edges()
	if clean == "":
		_preview_label.visible = false
		_preview_label.text = ""
		return
	_preview_label.text = "Preview: " + clean
	_preview_label.visible = true

func _push_overview_deltas(deltas: Dictionary) -> void:
	var game_ui = get_tree().current_scene.find_child("GameUI", true, false)
	if game_ui and game_ui.has_method("nastav_akce_nahled_delta"):
		game_ui.nastav_akce_nahled_delta(deltas)

func _clear_preview_text() -> void:
	_set_preview_text("")
	_clear_inline_deltas()
	_push_overview_deltas({})
	_ideology_preview_active = false

func nastav_nahled_ideologie(preview: Dictionary) -> void:
	if aktualni_provincie_id == -1:
		return
	if preview.is_empty() or not bool(preview.get("ok", false)):
		return

	var state_tag = str(preview.get("state", "")).strip_edges().to_upper()
	if state_tag == "":
		return

	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var d = province_data[aktualni_provincie_id]
	var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
	if owner_tag != state_tag:
		vycisti_nahled_ideologie()
		return

	var stat_changes = preview.get("stat_changes", {}) as Dictionary
	var modifiers = stat_changes.get("modifiers", {}) as Dictionary
	var gdp_ratio = float(modifiers.get("gdp_ratio", 1.0))
	var new_recruit_mult = float(modifiers.get("new_recruit_mult", 1.0))

	var old_gdp = float(d.get("gdp", 0.0))
	var new_gdp = max(0.0, old_gdp * gdp_ratio)
	var delta_gdp = new_gdp - old_gdp

	var old_cap = int(d.get("base_recruitable_population", d.get("recruitable_population", 0)))
	var old_recruit = int(d.get("recruitable_population", old_cap))
	old_recruit = clampi(old_recruit, 0, max(0, old_cap))
	var raw_base = int(d.get("base_recruitable_population_raw", old_cap))
	if raw_base < 0:
		raw_base = 0

	var fill_ratio = 0.0
	if old_cap > 0:
		fill_ratio = float(old_recruit) / float(old_cap)

	var new_cap = max(0, int(round(float(raw_base) * max(0.01, new_recruit_mult))))
	var new_recruit = clampi(int(round(float(new_cap) * fill_ratio)), 0, new_cap)
	var delta_recruit = new_recruit - old_recruit
	var recruit_delta_text = "+" + _formatuj_cislo(delta_recruit) if delta_recruit >= 0 else _formatuj_cislo(delta_recruit)

	_set_metric_delta("gdp", "%+.2f" % delta_gdp, Color(0.20, 0.85, 0.25) if delta_gdp >= 0.0 else Color(0.95, 0.35, 0.35))
	_set_metric_delta("recruit", recruit_delta_text, Color(0.20, 0.85, 0.25) if delta_recruit >= 0 else Color(0.95, 0.35, 0.35))
	_set_metric_delta("pop", "0", Color(0.75, 0.75, 0.75))
	_ideology_preview_active = true

func vycisti_nahled_ideologie() -> void:
	if not _ideology_preview_active:
		return
	_set_metric_delta("gdp", "", Color.WHITE)
	_set_metric_delta("recruit", "", Color.WHITE)
	_set_metric_delta("pop", "", Color.WHITE)
	_ideology_preview_active = false

func _spocitej_stat_hdp_a_vojaky(owner_tag: String, province_data: Dictionary) -> Dictionary:
	var hdp := 0.0
	var vojaci := 0
	var wanted = owner_tag.strip_edges().to_upper()
	for p_id in province_data:
		var d = province_data[p_id]
		if str(d.get("owner", "")).strip_edges().to_upper() != wanted:
			continue
		hdp += float(d.get("gdp", 0.0))
		vojaci += int(d.get("soldiers", 0))
	return {"hdp": hdp, "vojaci": vojaci}

func _nahled_stavby_text(building_id: int, cena: float, prov_data: Dictionary) -> String:
	_clear_inline_deltas()
	var overview_deltas: Dictionary = {}
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var province_data = _ziskej_provincie_data()
	var totals = _spocitej_stat_hdp_a_vojaky(owner_tag, province_data)
	var base_hdp = float(totals.get("hdp", 0.0))
	var base_vojaci = int(totals.get("vojaci", 0))
	var prijmova_sazba = _ziskej_prijmovou_sazbu_hdp()
	var upkeep_za_vojaka = _ziskej_udrzbu_za_vojaka()
	var base_income = (base_hdp * prijmova_sazba) - (float(base_vojaci) * upkeep_za_vojaka)
	var delta_income = 0.0
	var bonus_text = ""

	match building_id:
		0:
			delta_income = 10.0 * prijmova_sazba
			bonus_text = "Civilian Factory: +10 GDP"
		1:
			bonus_text = "Arms Factory: +2,000 recruits"
		2:
			bonus_text = "Port: unlocks naval options"

	var income_after = base_income + delta_income
	var cash_after = GameManager.statni_kasa - cena
	if building_id == 0:
		_set_metric_delta("gdp", "+10.00", Color(0.20, 0.85, 0.25))
		_set_metric_delta("income", "+1.00 / turn", Color(0.20, 0.85, 0.25))
		overview_deltas["gdp"] = {"text": "+10.00", "color": Color(0.20, 0.85, 0.25)}
		_push_overview_deltas(overview_deltas)
		return "%s | Cost: %s | Funds after purchase: %s | Income after completion (3 turns): %s (Delta %s)" % [bonus_text, _format_money_auto(cena, 2), _format_money_auto(cash_after, 2), _format_money_auto(income_after, 2, false, true), _format_money_auto(delta_income, 2, true, true)]
	if building_id == 1:
		_set_metric_delta("recruit", "+2 000", Color(0.20, 0.85, 0.25))
		overview_deltas["recruit"] = {"text": "+2 000", "color": Color(0.20, 0.85, 0.25)}
	if building_id == 2:
		_set_metric_delta("income", "0.00", Color(0.75, 0.75, 0.75))
		overview_deltas["gdp"] = {"text": "0.00", "color": Color(0.75, 0.75, 0.75)}
	_push_overview_deltas(overview_deltas)
	return "%s | Cost: %s | Funds after purchase: %s | No direct income change" % [bonus_text, _format_money_auto(cena, 2), _format_money_auto(cash_after, 2)]

func _nahled_verbovani_text(pocet: int) -> String:
	_clear_inline_deltas()
	var upkeep_delta = -float(pocet) * _ziskej_udrzbu_za_vojaka()
	var projected_income = float(GameManager.celkovy_prijem) + upkeep_delta
	var cena = float(pocet) * _ziskej_cenu_za_vojaka()
	var cash_after = GameManager.statni_kasa - cena
	_set_metric_delta("soldiers", "+%s" % _formatuj_cislo(pocet), Color(0.20, 0.85, 0.25))
	_set_metric_delta("recruit", "-%s" % _formatuj_cislo(pocet), Color(0.95, 0.35, 0.35))
	_set_metric_delta("income", "%+.2f / turn" % upkeep_delta, Color(0.95, 0.35, 0.35))
	_push_overview_deltas({
		"recruit": {"text": "-%s" % _formatuj_cislo(pocet), "color": Color(0.95, 0.35, 0.35)},
		"gdp": {"text": "%+.2f / turn" % upkeep_delta, "color": Color(0.95, 0.35, 0.35)}
	})
	return "Recruitment: %s soldiers | Cost: %s | Funds after purchase: %s | Upkeep: %s | New net income: %s" % [_formatuj_cislo(pocet), _format_money_auto(cena, 2), _format_money_auto(cash_after, 2), _format_money_auto(upkeep_delta, 2, true, true), _format_money_auto(projected_income, 2, false, true)]

func _posun_stavba_menu():
	var p = btn_stavet.get_popup()
	p.position.y = btn_stavet.global_position.y - p.size.y - 5
	_stavba_last_focus_idx = -2
	set_process(true)
	_set_preview_text("Construction finishes in 3 turns. Civilian Factory increases income, Arms Factory boosts recruits, Port unlocks naval access.")

func _on_stavba_zvyraznena(id: int) -> void:
	_nastav_nahled_stavby_podle_id(id)

func _nastav_nahled_stavby_podle_id(id: int) -> void:
	if aktualni_provincie_id == -1:
		return
	var cena = 150.0
	if id == 1:
		cena = 200.0
	elif id == 2:
		cena = 250.0
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	_set_preview_text(_nahled_stavby_text(id, cena, province_data[aktualni_provincie_id]))

func _on_stavba_menu_zavreno() -> void:
	_stavba_last_focus_idx = -2
	set_process(false)

func _process(_delta: float) -> void:
	# Fallback hover tracking for PopupMenu (works even when id_focused is unreliable).
	if _stavba_popup == null or not is_instance_valid(_stavba_popup):
		set_process(false)
		return
	if not _stavba_popup.visible:
		set_process(false)
		return
	if not _stavba_popup.has_method("get_focused_item"):
		return

	var idx = int(_stavba_popup.get_focused_item())
	if idx == _stavba_last_focus_idx:
		return
	_stavba_last_focus_idx = idx
	if idx < 0:
		return
	if idx >= _stavba_popup.item_count:
		return

	_nastav_nahled_stavby_podle_id(int(_stavba_popup.get_item_id(idx)))

func schovej_se():
	$PanelContainer.hide()
	action_menu.hide()
	recruit_popup.hide()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	aktualni_provincie_id = -1
	hromadny_vyber_ids.clear()
	je_hromadny_rezim = false
	je_hromadne_verbovani = false
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if map_loader and map_loader.has_method("vycisti_hromadny_vyber_provincii"):
		map_loader.vycisti_hromadny_vyber_provincii()
	_clear_preview_text()

func zobraz_data(data: Dictionary):
	if data.is_empty():
		schovej_se()
		return
	
	$PanelContainer.show()
	je_hromadny_rezim = false
	je_hromadne_verbovani = false
	hromadny_vyber_ids.clear()
	recruit_popup.hide() 
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()
	aktualni_provincie_id = data.get("id", -1)
	
	var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(data.get("army_owner", "")).strip_edges().to_upper()
	var core_owner = str(data.get("core_owner", owner_tag)).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat and int(data.get("soldiers", 0)) > 0)
	var vojaci = int(data.get("soldiers", 0))
	var ma_pristav = bool(data.get("has_port", false))
	
	var province_name = str(data.get("province_name", "Neznamo"))
	id_label.text = "Province: %s - PORT" % province_name if (not je_more and ma_pristav) else "Province: " + province_name
	if je_more and armada_owner != "":
		owner_label.text = "Owner: SEA (naval army: %s)" % armada_owner
	elif core_owner != "" and core_owner != owner_tag:
		owner_label.text = "Owner: %s (occupation, core: %s)" % [owner_tag, core_owner]
	else:
		owner_label.text = "Owner: " + owner_tag

	terrain_label.visible = true
	var terrain_raw = str(data.get("terrain", "")).strip_edges()
	if terrain_raw == "":
		terrain_raw = "unknown"
	var terrain_def_bonus = _ziskej_terenni_obranny_bonus_pro_data(data, terrain_raw)
	terrain_label.text = "Terrain: %s (defense %s)" % [terrain_raw, _format_pct_signed(terrain_def_bonus)]
	
	if je_more:
		_set_metric_visible("pop", false)
		_set_metric_visible("recruit", false)
		_set_metric_visible("gdp", false)
		_set_metric_visible("income", false)
		if vojaci > 0:
			_set_metric_visible("soldiers", true)
			if armada_owner != "":
				soldiers_label.text = "Fleet (%s): %s men" % [armada_owner, _formatuj_cislo(vojaci)]
			else:
				soldiers_label.text = "Fleet: " + _formatuj_cislo(vojaci) + " men"
		else:
			_set_metric_visible("soldiers", false)
	else:
		_set_metric_visible("pop", true)
		_set_metric_visible("recruit", true)
		_set_metric_visible("gdp", true)
		_set_metric_visible("soldiers", true)
		
		var pop = int(data.get("population", 0))
		pop_label.text = "Population: " + _formatuj_cislo(pop)
		
		var rekruti = int(data.get("recruitable_population", 0))
		recruit_label.text = "Recruits: " + _formatuj_cislo(rekruti)
		
		var gdp = float(data.get("gdp", 0.0))
		gdp_label.text = "GDP: %.2f bn USD" % gdp
		
		soldiers_label.text = "Army: " + _formatuj_cislo(vojaci) + " men"
		
		if je_moje:
			_set_metric_visible("income", true)
			income_label.text = "Income: +%s USD" % _format_money_auto(gdp * 0.05, 2)
		else:
			_set_metric_visible("income", false)

	if (je_moje and not je_more) or je_moje_armada_na_mori:
		var muze_stavet = (je_moje and not je_more)
		var ma_armadu = (vojaci > 0)
		btn_stavet.visible = muze_stavet
		btn_verbovat.visible = muze_stavet
		btn_likvidovat.visible = ma_armadu

		if not muze_stavet:
			btn_stavet.disabled = true
			btn_stavet.text = "Build"
			btn_verbovat.disabled = true
			btn_likvidovat.disabled = not ma_armadu

		if muze_stavet:
			if GameManager.provincie_cooldowny.has(aktualni_provincie_id):
				var zbyva_kol = GameManager.provincie_cooldowny[aktualni_provincie_id]["zbyva"]
				btn_stavet.disabled = true
				btn_stavet.text = "Building (%d turns)" % zbyva_kol
			else:
				btn_stavet.disabled = false
				btn_stavet.text = "Build"
			
		if btn_presunout:
			btn_presunout.visible = (vojaci > 0)
			btn_presunout.disabled = not ma_armadu
			
		if muze_stavet:
			btn_verbovat.disabled = false
		btn_likvidovat.disabled = not ma_armadu
		action_menu.show()
	else:
		action_menu.hide()
		_clear_preview_text()

func _on_likvidovat_pressed():
	if aktualni_provincie_id == -1:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var prov_data = province_data[aktualni_provincie_id]
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(prov_data.get("army_owner", "")).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat)

	if not je_moje and not je_moje_armada_na_mori:
		return

	var pocet_vojaku = int(prov_data.get("soldiers", 0))
	if pocet_vojaku <= 0:
		return

	likvidace_slider.min_value = 1
	likvidace_slider.max_value = pocet_vojaku
	likvidace_slider.value = pocet_vojaku
	_on_likvidace_slider_zmenen(float(pocet_vojaku))

	var rect = Rect2i()
	rect.position = Vector2i(btn_likvidovat.global_position.x, btn_likvidovat.global_position.y - likvidace_popup.size.y - 5)
	rect.size = likvidace_popup.size
	likvidace_popup.popup(rect)

func _on_likvidace_slider_zmenen(hodnota: float):
	if not likvidace_info:
		return
	var pocet = int(hodnota)
	var refundace = float(pocet) * likvidace_vynos_za_vojaka
	likvidace_info.text = "Disband: %s soldiers\nRefund: +%s" % [_formatuj_cislo(pocet), _format_money_auto(refundace, 2)]
	if btn_likvidace_potvrdit:
		btn_likvidace_potvrdit.disabled = (pocet <= 0)

func _on_potvrdit_likvidaci():
	if aktualni_provincie_id == -1:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return

	var prov_data = province_data[aktualni_provincie_id]
	var owner_tag = str(prov_data.get("owner", "")).strip_edges().to_upper()
	var armada_owner = str(prov_data.get("army_owner", "")).strip_edges().to_upper()
	var je_more = (owner_tag == "SEA")
	var je_moje = (owner_tag == GameManager.hrac_stat)
	var je_moje_armada_na_mori = (je_more and armada_owner == GameManager.hrac_stat)

	if not je_moje and not je_moje_armada_na_mori:
		likvidace_popup.hide()
		return

	var dostupni_vojaci = int(prov_data.get("soldiers", 0))
	var pocet_vojaku = clampi(int(likvidace_slider.value), 1, dostupni_vojaci)
	if dostupni_vojaci <= 0 or pocet_vojaku <= 0:
		likvidace_popup.hide()
		return

	var refundace = float(pocet_vojaku) * likvidace_vynos_za_vojaka
	GameManager.statni_kasa += refundace
	prov_data["soldiers"] = max(0, dostupni_vojaci - pocet_vojaku)

	if je_more and int(prov_data.get("soldiers", 0)) <= 0:
		prov_data["army_owner"] = ""
	elif not je_more:
		prov_data["army_owner"] = GameManager.hrac_stat
		prov_data["recruitable_population"] = int(prov_data.get("recruitable_population", 0)) + pocet_vojaku

	likvidace_popup.hide()
	_ukaz_stavbu_info("ARMY DISBAND", "Disbanded %s soldiers. %s USD was returned to state funds." % [_formatuj_cislo(pocet_vojaku), _format_money_auto(refundace, 2)])
	zobraz_data(prov_data)
	GameManager.kolo_zmeneno.emit()

func _on_presunout_pressed():
	if je_hromadny_rezim:
		if hromadny_vyber_ids.is_empty():
			return
		var map_loader_bulk = get_tree().current_scene.find_child("Map", true, false)
		if not map_loader_bulk and get_parent().has_method("aktivuj_rezim_hromadneho_presunu"):
			map_loader_bulk = get_parent()
		if map_loader_bulk and map_loader_bulk.has_method("aktivuj_rezim_hromadneho_presunu"):
			if map_loader_bulk.aktivuj_rezim_hromadneho_presunu(hromadny_vyber_ids):
				schovej_se()
		return

	if aktualni_provincie_id == -1: return
	
	var province_data = _ziskej_provincie_data()
	var prov_data = province_data.get(aktualni_provincie_id, {})
	var dostupni_vojaci = int(prov_data.get("soldiers", 0))
	if dostupni_vojaci <= 0: return
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("aktivuj_rezim_vyberu_cile"):
		map_loader = get_parent()
			
	if map_loader and map_loader.has_method("aktivuj_rezim_vyberu_cile"):
		map_loader.aktivuj_rezim_vyberu_cile(aktualni_provincie_id, dostupni_vojaci)
		
	schovej_se()

# --- NEW: Zobrazí slider po úspěšném kliknutí na souseda v mapě ---
func zobraz_presun_slider(from_id: int, to_id: int, max_troops: int, path: Array = []):
	presun_od_id = from_id
	presun_do_id = to_id
	presun_path = path.duplicate()
	
	move_slider.min_value = 1
	move_slider.max_value = max_troops
	move_slider.value = max_troops
	
	_on_move_slider_zmenen(max_troops)
	
	# Zobrazíme popup (pokud je to PopupPanel, použije popup_centered)
	if move_popup is Popup:
		move_popup.popup_centered()
	else:
		move_popup.show()

func _on_move_slider_zmenen(hodnota: float):
	if move_count_label:
		move_count_label.text = _formatuj_cislo(int(hodnota)) + " soldiers"

func _on_potvrdit_presun():
	var amount = int(move_slider.value)
	move_popup.hide()
	
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("zaregistruj_presun_armady"):
		map_loader = get_parent()
		
	if map_loader and map_loader.has_method("zaregistruj_presun_armady"):
		map_loader.zaregistruj_presun_armady(presun_od_id, presun_do_id, amount, true, presun_path)
# ------------------------------------------------------------------

func _on_stavba_vybrana(id: int):
	if je_hromadny_rezim:
		_postav_hromadne(id)
		return

	if aktualni_provincie_id == -1: return
	var cena = 150.0
	if id == 1:
		cena = 200.0
	elif id == 2:
		cena = 250.0

	if id == 2:
		if not GameManager.muze_postavit_pristav(aktualni_provincie_id):
			_set_preview_text("Port cannot be built: province must be yours, coastal, and not on cooldown.")
			_ukaz_stavbu_info("PORT", "A port can only be built in your own coastal province adjacent to sea, and only once.")
			return

	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	_set_preview_text(_nahled_stavby_text(id, cena, province_data[aktualni_provincie_id]))
	
	if GameManager.statni_kasa >= cena:
		GameManager.statni_kasa -= cena
		GameManager.provincie_cooldowny[aktualni_provincie_id] = {"zbyva": 3, "budova": id}
		btn_stavet.disabled = true
		btn_stavet.text = "Building (3 turns)"
		_ukaz_stavbu_info("CONSTRUCTION STARTED", _nahled_stavby_text(id, cena, province_data[aktualni_provincie_id]))
		GameManager.kolo_zmeneno.emit()
	else:
		_set_preview_text("Insufficient funds: you need %s, you have %s." % [_format_money_auto(cena, 2), _format_money_auto(GameManager.statni_kasa, 2)])
		_ukaz_stavbu_info("INSUFFICIENT FUNDS", "You do not have enough money for this construction.")

func _ukaz_stavbu_info(title: String, text: String):
	var map_loader = get_tree().current_scene.find_child("Map", true, false)
	if not map_loader and get_parent().has_method("_ukaz_bitevni_popup"):
		map_loader = get_parent()

	if map_loader and map_loader.has_method("_ukaz_bitevni_popup"):
		map_loader._ukaz_bitevni_popup(title, text)

func _on_verbovat_pressed():
	if je_hromadny_rezim:
		_otevri_hromadne_verbovani()
		return

	if aktualni_provincie_id == -1: return
	
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	var prov_data = province_data[aktualni_provincie_id]
	var dostupni_rekruti = int(prov_data.get("recruitable_population", 0))
	dostupni_rekruti = _limit_verbovani_v_okupaci(dostupni_rekruti, prov_data)
	var max_za_penize = int(GameManager.statni_kasa / _ziskej_cenu_za_vojaka())
	var max_mozno = min(dostupni_rekruti, max_za_penize)
	
	if max_mozno <= 0: return
	_set_preview_text("Recruitment increases army upkeep (reduces net income per turn).")
		
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = 0
	_on_slider_zmenen(0) 
	
	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	recruit_popup.popup(rect)

func _on_slider_zmenen(hodnota: float):
	var cena = hodnota * _ziskej_cenu_za_vojaka()
	if je_hromadne_verbovani:
		recruit_info.text = "Bulk: %d men\nCost: %s" % [int(hodnota), _format_money_auto(cena, 2)]
	else:
		recruit_info.text = "Men: %d\nCost: %s" % [int(hodnota), _format_money_auto(cena, 2)]
	if hodnota > 0:
		_set_preview_text(_nahled_verbovani_text(int(hodnota)))
	else:
		_clear_inline_deltas()
		_push_overview_deltas({})
		_set_preview_text("Recruitment increases army upkeep (reduces net income per turn).")
	btn_potvrdit.disabled = (hodnota == 0)

func _on_potvrdit_verbovani():
	if je_hromadne_verbovani:
		_potvrd_hromadne_verbovani()
		return

	var pocet_vojaku = int(recruit_slider.value)
	var celkova_cena = pocet_vojaku * _ziskej_cenu_za_vojaka()
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		recruit_popup.hide()
		return
	var prov_data = province_data[aktualni_provincie_id]
	var max_okupace = _limit_verbovani_v_okupaci(int(prov_data.get("recruitable_population", 0)), prov_data)
	if max_okupace <= 0:
		recruit_popup.hide()
		_clear_preview_text()
		_ukaz_stavbu_info("RECRUITMENT", "Recruitment in occupied territory is currently heavily limited.")
		return
	pocet_vojaku = min(pocet_vojaku, max_okupace)
	celkova_cena = pocet_vojaku * _ziskej_cenu_za_vojaka()
	
	GameManager.statni_kasa -= celkova_cena
	prov_data["recruitable_population"] -= pocet_vojaku
	
	if not prov_data.has("soldiers"): prov_data["soldiers"] = 0
	prov_data["soldiers"] += pocet_vojaku
	
	recruit_popup.hide()
	_clear_preview_text()
	zobraz_data(prov_data) 
	GameManager.kolo_zmeneno.emit()

func _on_kolo_zmeneno():
	if je_hromadny_rezim:
		var map_loader = get_tree().current_scene.find_child("Map", true, false)
		if map_loader and map_loader.has_method("ziskej_hromadne_vybrane_provincie"):
			var ids = map_loader.ziskej_hromadne_vybrane_provincie()
			if ids.size() > 1:
				zobraz_hromadna_data(ids, GameManager.map_data)
				return
		return

	if aktualni_provincie_id == -1:
		return
	if not $PanelContainer.visible:
		return
	var province_data = _ziskej_provincie_data()
	if not province_data.has(aktualni_provincie_id):
		return
	zobraz_data(province_data[aktualni_provincie_id])

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0: vysledek += " "
		vysledek += text_cisla[i]
	return vysledek

func _format_money_auto(value: float, mil_decimals: int = 2, signed: bool = false, per_turn: bool = false) -> String:
	if absf(value) < 0.01:
		var tis_decimals = max(1, mil_decimals - 1)
		var fmt_tis = "%" + ("+" if signed else "") + "." + str(tis_decimals) + "f"
		var txt_tis = fmt_tis % (value * 1000.0)
		return txt_tis + "k" + ("/turn" if per_turn else "")
	var fmt_mil = "%" + ("+" if signed else "") + "." + str(mil_decimals) + "f"
	var txt_mil = fmt_mil % value
	return txt_mil + "M" + ("/turn" if per_turn else "")

func zobraz_hromadna_data(ids: Array, all_provinces: Dictionary):
	if ids.size() <= 1:
		if ids.size() == 1 and all_provinces.has(int(ids[0])):
			zobraz_data(all_provinces[int(ids[0])])
		else:
			schovej_se()
		return

	je_hromadny_rezim = true
	je_hromadne_verbovani = false
	hromadny_vyber_ids = ids.duplicate()
	$PanelContainer.show()
	action_menu.show()
	recruit_popup.hide()
	if move_popup: move_popup.hide()
	if likvidace_popup: likvidace_popup.hide()

	var vlastni_pozemni: Array = []
	var vlastni_s_armadou: Array = []
	var total_pop := 0
	var total_recruits := 0
	var total_gdp := 0.0
	var total_soldiers := 0
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not all_provinces.has(pid):
			continue
		var d = all_provinces[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var je_more = (owner_tag == "SEA")
		if owner_tag == GameManager.hrac_stat and not je_more:
			vlastni_pozemni.append(pid)
			total_pop += int(d.get("population", 0))
			total_recruits += int(d.get("recruitable_population", 0))
			total_gdp += float(d.get("gdp", 0.0))
		var army_owner = str(d.get("army_owner", "")).strip_edges().to_upper()
		var moje_more_armada = (je_more and army_owner == GameManager.hrac_stat)
		if (owner_tag == GameManager.hrac_stat and int(d.get("soldiers", 0)) > 0) or moje_more_armada:
			vlastni_s_armadou.append(pid)
			total_soldiers += int(d.get("soldiers", 0))

	id_label.text = "Bulk selection: %d provinces" % hromadny_vyber_ids.size()
	owner_label.text = "Actions for country: %s" % GameManager.hrac_stat
	terrain_label.visible = false
	_set_metric_visible("pop", true)
	_set_metric_visible("recruit", true)
	_set_metric_visible("gdp", true)
	_set_metric_visible("income", false)
	_set_metric_visible("soldiers", true)
	pop_label.text = "Total population: %s" % _formatuj_cislo(total_pop)
	recruit_label.text = "Total recruits: %s" % _formatuj_cislo(total_recruits)
	gdp_label.text = "Total GDP: %.2f bn USD" % total_gdp
	soldiers_label.text = "Total soldiers: %s" % _formatuj_cislo(total_soldiers)

	btn_likvidovat.hide()
	btn_stavet.show()
	btn_verbovat.show()
	btn_presunout.show()
	btn_stavet.disabled = vlastni_pozemni.is_empty()
	btn_verbovat.disabled = vlastni_pozemni.is_empty()
	btn_presunout.disabled = vlastni_s_armadou.is_empty()
	btn_stavet.text = "Build"

func _ziskej_hromadne_vlastni_pozemni() -> Array:
	var out: Array = []
	var province_data = _ziskej_provincie_data()
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		if owner_tag == GameManager.hrac_stat and owner_tag != "SEA":
			out.append(pid)
	return out

func _ziskej_hromadne_zdroje_s_armadou() -> Array:
	var out: Array = []
	var province_data = _ziskej_provincie_data()
	for raw_id in hromadny_vyber_ids:
		var pid = int(raw_id)
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var owner_tag = str(d.get("owner", "")).strip_edges().to_upper()
		var army_owner = str(d.get("army_owner", "")).strip_edges().to_upper()
		var je_more = (owner_tag == "SEA")
		if int(d.get("soldiers", 0)) <= 0:
			continue
		if owner_tag == GameManager.hrac_stat or (je_more and army_owner == GameManager.hrac_stat):
			out.append(pid)
	return out

func _otevri_hromadne_verbovani():
	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	if pozemni.is_empty():
		_ukaz_stavbu_info("BULK RECRUITMENT", "No owned land province is selected.")
		return

	var total_recruits := 0
	var province_data = _ziskej_provincie_data()
	for pid in pozemni:
		if not province_data.has(pid):
			continue
		total_recruits += _limit_verbovani_v_okupaci(int(province_data[pid].get("recruitable_population", 0)), province_data[pid])
	var max_za_penize = int(GameManager.statni_kasa / _ziskej_cenu_za_vojaka())
	var max_mozno = min(total_recruits, max_za_penize)
	if max_mozno <= 0:
		if total_recruits <= 0:
			_ukaz_stavbu_info("BULK RECRUITMENT", "Selected provinces have no available recruits.")
		else:
			_ukaz_stavbu_info("BULK RECRUITMENT", "Not enough money for bulk recruitment.")
		return

	je_hromadne_verbovani = true
	recruit_slider.min_value = 0
	recruit_slider.max_value = max_mozno
	recruit_slider.value = max_mozno
	_on_slider_zmenen(max_mozno)

	var rect = Rect2i()
	rect.position = Vector2i(btn_verbovat.global_position.x, btn_verbovat.global_position.y - recruit_popup.size.y - 5)
	rect.size = recruit_popup.size
	recruit_popup.popup(rect)

func _potvrd_hromadne_verbovani():
	var remaining = int(recruit_slider.value)
	if remaining <= 0:
		recruit_popup.hide()
		return

	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	var total_recruited := 0
	var province_data = _ziskej_provincie_data()
	for pid in pozemni:
		if remaining <= 0:
			break
		if not province_data.has(pid):
			continue
		var d = province_data[pid]
		var available_recruits = int(d.get("recruitable_population", 0))
		var max_allowed_here = _limit_verbovani_v_okupaci(available_recruits, d)
		if max_allowed_here <= 0:
			continue
		var add = min(remaining, max_allowed_here)
		d["recruitable_population"] = available_recruits - add
		d["soldiers"] = int(d.get("soldiers", 0)) + add
		remaining -= add
		total_recruited += add

	if total_recruited > 0:
		GameManager.statni_kasa -= float(total_recruited) * _ziskej_cenu_za_vojaka()
	else:
		_ukaz_stavbu_info("BULK RECRUITMENT", "Recruitment was not performed (0 soldiers recruited).")

	je_hromadne_verbovani = false
	recruit_popup.hide()
	_clear_preview_text()
	GameManager.kolo_zmeneno.emit()

func _postav_hromadne(building_id: int):
	var pozemni = _ziskej_hromadne_vlastni_pozemni()
	if pozemni.is_empty():
		return

	var cena = 150.0
	if building_id == 1:
		cena = 200.0
	elif building_id == 2:
		cena = 250.0

	var postaveno := 0
	var preskoceno := 0
	for pid in pozemni:
		if GameManager.statni_kasa < cena:
			break

		if GameManager.provincie_cooldowny.has(pid):
			preskoceno += 1
			continue

		if building_id == 2 and not GameManager.muze_postavit_pristav(pid):
			preskoceno += 1
			continue

		GameManager.statni_kasa -= cena
		GameManager.provincie_cooldowny[pid] = {"zbyva": 3, "budova": building_id}
		postaveno += 1

	if postaveno > 0:
		GameManager.kolo_zmeneno.emit()

	_ukaz_stavbu_info("BULK CONSTRUCTION", "Built: %d | Skipped: %d" % [postaveno, preskoceno])
