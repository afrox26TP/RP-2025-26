extends Control

@onready var selected_country_label: Label = $CenterPanel/MarginContainer/VBoxContainer/SelectedCountryLabel
@onready var menu_hint_label: Label = $CenterPanel/MarginContainer/VBoxContainer/MenuHint

@onready var btn_new_game: Button = $CenterPanel/MarginContainer/VBoxContainer/MainButtons/NewGameButton
@onready var btn_continue: Button = $CenterPanel/MarginContainer/VBoxContainer/MainButtons/ContinueButton
@onready var btn_settings: Button = $CenterPanel/MarginContainer/VBoxContainer/SecondaryButtons/SettingsButton
@onready var btn_credits: Button = $CenterPanel/MarginContainer/VBoxContainer/SecondaryButtons/CreditsButton
@onready var btn_exit: Button = $CenterPanel/MarginContainer/VBoxContainer/ExitButton

@onready var country_browser_panel: PanelContainer = $CountryBrowserPanel
@onready var btn_close_corner: Button = $CountryBrowserPanel/MarginContainer/RootVBox/HeaderRow/CloseHeaderButton
@onready var browser_subtitle: Label = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserSubtitle
@onready var browser_flow_hint: Label = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserFlowHint
@onready var selected_players_title: Label = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel/SelectedPlayersMargin/SelectedPlayersVBox/SelectedPlayersTitle
@onready var selected_players_list: Label = $CountryBrowserPanel/MarginContainer/RootVBox/SelectedPlayersPanel/SelectedPlayersMargin/SelectedPlayersVBox/SelectedPlayersList
@onready var list_hint: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/ListPanel/ListMargin/ListVBox/ListHint
@onready var country_list: VBoxContainer = $CountryBrowserPanel/MarginContainer/RootVBox/Content/ListPanel/ListMargin/ListVBox/CountryListScroll/CountryList
@onready var detail_flag: TextureRect = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailFlag
@onready var detail_name: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailName
@onready var detail_tag: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailTag
@onready var detail_ideology: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailIdeology
@onready var detail_population: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailPopulation
@onready var detail_gdp: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailGdp
@onready var detail_recruits: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailRecruits
@onready var detail_soldiers: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailSoldiers
@onready var detail_provinces: Label = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailProvinceCount
@onready var detail_info: RichTextLabel = $CountryBrowserPanel/MarginContainer/RootVBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailInfo
@onready var btn_confirm_country: Button = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserButtons/ConfirmCountryButton
@onready var btn_close_browser: Button = $CountryBrowserPanel/MarginContainer/RootVBox/BrowserButtons/CloseBrowserButton

@onready var settings_dialog: AcceptDialog = $Dialogs/SettingsDialog
@onready var credits_dialog: AcceptDialog = $Dialogs/CreditsDialog
@onready var exit_dialog: ConfirmationDialog = $Dialogs/ExitDialog

# List of playable countries (Display Name : Tag)
var hratelne_staty = {
	"Albánie": "ALB",
	"Rakousko": "AUT",
	"Belgie": "BEL",
	"Bulharsko": "BGR",
	"Bosna a Hercegovina": "BIH",
	"Bělorusko": "BLR",
	"Švýcarsko": "CHE",
	"Kypr": "CYP",
	"Česká republika": "CZE",
	"Německo": "DEU",
	"Dánsko": "DNK",
	"Španělsko": "ESP",
	"Estonsko": "EST",
	"Finsko": "FIN",
	"Francie": "FRA",
	"Velká Británie": "GBR",
	"Gruzie": "GEO",
	"Řecko": "GRC",
	"Chorvatsko": "HRV",
	"Maďarsko": "HUN",
	"Irsko": "IRL",
	"Island": "ISL",
	"Itálie": "ITA",
	"Kosovo": "KOS",
	"Litva": "LTU",
	"Lucembursko": "LUX",
	"Lotyšsko": "LVA",
	"Moldavsko": "MDA",
	"Severní Makedonie": "MKD",
	"Černá Hora": "MNE",
	"Nizozemsko": "NLD",
	"Norsko": "NOR",
	"Polsko": "POL",
	"Portugalsko": "PRT",
	"Rumunsko": "ROU",
	"Rusko": "RUS",
	"Srbsko": "SRB",
	"Slovensko": "SVK",
	"Slovinsko": "SVN",
	"Švédsko": "SWE",
	"Turecko": "TUR",
	"Ukrajina": "UKR"
}

const MAP_SCENE_PATH := "res://scenes/map.tscn"
const SAVE_FILE_PATH := "user://savegame.dat"
const PROVINCES_DATA_PATH := "res://map_data/Provinces.txt"
const SETTINGS_DIALOG_TITLE := "Nastaveni"
const SETTINGS_DIALOG_TEXT := "Nastaveni budou doplnena v dalsi iteraci.\n\nOVLADANI:\n- Zoom koleckem\n- Posouvat mapu WSAD\n- Ukoncit kolo mezernikem\n- Pravim tlacitkem cancelovat akce a zavirat dialogy\n- DEv simple conquer tool: C"
const CREDITS_DIALOG_TITLE := "Kredity"
const CREDITS_DIALOG_TEXT := "RP-2025-26\n\nDesign a gameplay: JA (Afrox26TP)\nMapa a data: interni dataset (Muj)"
const EXIT_DIALOG_TITLE := "Potvrzeni"
const EXIT_DIALOG_TEXT := "Opravdu chces ukoncit hru?"

var country_stats: Dictionary = {}
var flag_texture_cache: Dictionary = {}
var normalized_flag_texture_cache: Dictionary = {}
var country_rows: Dictionary = {}
var selected_country_tag_in_browser: String = ""
var selected_country_tag: String = "ALB"
var new_game_browser_flow: bool = false
var local_player_tags: Array = []
var setup_active_player_index: int = 0
const BROWSER_CONFIRM_DEFAULT_TEXT := "Potvrdit vyber"
const BROWSER_CONFIRM_ADD_PLAYER_TEXT := "Pridat hrace"
const BROWSER_CLOSE_DEFAULT_TEXT := "Zavrit"
const BROWSER_CLOSE_START_TEXT := "Spustit hru"

func _load_texture_cached(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not flag_texture_cache.has(path):
		flag_texture_cache[path] = load(path)
	return flag_texture_cache[path]

func _load_normalized_flag_texture(path: String, width: int, height: int):
	var cache_key = "%s|%d|%d" % [path, width, height]
	if normalized_flag_texture_cache.has(cache_key):
		return normalized_flag_texture_cache[cache_key]

	var base_tex = _load_texture_cached(path)
	if base_tex == null:
		return null

	var base_img = base_tex.get_image()
	if base_img == null:
		return base_tex

	var src_w = base_img.get_width()
	var src_h = base_img.get_height()
	if src_w <= 0 or src_h <= 0:
		return base_tex

	var scale_factor = min(float(width) / float(src_w), float(height) / float(src_h))
	var out_w = max(1, int(round(src_w * scale_factor)))
	var out_h = max(1, int(round(src_h * scale_factor)))

	var resized_img = base_img.duplicate()
	resized_img.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	var canvas = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dst_pos = Vector2i((width - out_w) / 2, (height - out_h) / 2)
	canvas.blit_rect(resized_img, Rect2i(Vector2i.ZERO, Vector2i(out_w, out_h)), dst_pos)

	var normalized_tex = ImageTexture.create_from_image(canvas)
	normalized_flag_texture_cache[cache_key] = normalized_tex
	return normalized_tex

func _ready():
	_nastav_texty_dialogu()
	_nacti_data_statu_pro_browser()
	_naplni_browser_seznam()
	_nastav_vychozi_vyber_statu()
	_obnov_text_vyberu()
	_nastav_stav_pokracovani()
	_aktualizuj_browser_napovedu()
	country_browser_panel.hide()

	# Connect UI signals
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_confirm_country.pressed.connect(_on_confirm_country_pressed)
	btn_close_browser.pressed.connect(_on_close_browser_pressed)
	btn_close_corner.pressed.connect(_on_close_browser_corner_pressed)
	exit_dialog.confirmed.connect(_on_exit_confirmed)

func _nastav_texty_dialogu():
	settings_dialog.title = SETTINGS_DIALOG_TITLE
	settings_dialog.dialog_text = SETTINGS_DIALOG_TEXT
	credits_dialog.title = CREDITS_DIALOG_TITLE
	credits_dialog.dialog_text = CREDITS_DIALOG_TEXT
	exit_dialog.title = EXIT_DIALOG_TITLE
	exit_dialog.dialog_text = EXIT_DIALOG_TEXT

func _nastav_vychozi_vyber_statu():
	if country_stats.has(selected_country_tag):
		return

	if country_stats.is_empty():
		selected_country_tag = ""
		return

	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort()
	selected_country_tag = str(vsechny_tagy[0])

func _nacti_data_statu_pro_browser():
	country_stats.clear()
	var file = FileAccess.open(PROVINCES_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("Nepodarilo se nacist Provinces.txt pro browser statu.")
		return

	if not file.eof_reached():
		file.get_line() # header

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		var parts = line.split(";")
		if parts.size() < 20:
			continue

		var typ = parts[4].strip_edges().to_lower()
		var tag = parts[6].strip_edges().to_upper()
		if typ == "sea" or tag == "" or tag == "SEA":
			continue

		if not country_stats.has(tag):
			country_stats[tag] = {
				"tag": tag,
				"country_name_en": parts[11].strip_edges(),
				"ideology": parts[18].strip_edges(),
				"population": 0,
				"gdp": 0.0,
				"recruitable_population": 0,
				"soldiers": 0,
				"province_count": 0
			}

		country_stats[tag]["population"] += int(parts[12])
		country_stats[tag]["gdp"] += float(parts[13])
		country_stats[tag]["recruitable_population"] += int(parts[19])
		country_stats[tag]["province_count"] += 1
		if parts.size() > 20 and parts[20].strip_edges() != "":
			country_stats[tag]["soldiers"] += int(parts[20])

func _naplni_browser_seznam():
	for child in country_list.get_children():
		child.queue_free()

	country_rows.clear()

	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort_custom(func(a, b):
		return _zobrazene_jmeno_statu(str(a)) < _zobrazene_jmeno_statu(str(b))
	)

	for tag in vsechny_tagy:
		var row_btn = _vytvor_radek_statu(str(tag))
		country_list.add_child(row_btn)
		country_rows[str(tag)] = row_btn

	if not vsechny_tagy.is_empty():
		_nastav_detail_statu(str(vsechny_tagy[0]))

	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()

func _vytvor_radek_statu(tag: String) -> Button:
	var stats = country_stats[tag]
	var row_btn = Button.new()
	row_btn.custom_minimum_size = Vector2(0, 74)
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.flat = false
	row_btn.clip_text = true
	row_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var icon_path = "res://map_data/Flags/%s.svg" % tag
	var icon_tex = _load_normalized_flag_texture(icon_path, 56, 36)
	if icon_tex:
		row_btn.icon = icon_tex
		row_btn.expand_icon = false
	row_btn.text = _sestav_text_radku_statu(tag)
	row_btn.tooltip_text = "%s (%s) | Populace: %s | HDP: %.1f" % [
		_zobrazene_jmeno_statu(tag), tag, _formatuj_cislo(int(stats["population"])), float(stats["gdp"])
	]
	row_btn.pressed.connect(func(): _on_country_row_pressed(tag))
	return row_btn

func _sestav_text_radku_statu(tag: String) -> String:
	if not country_stats.has(tag):
		return tag

	var stats = country_stats[tag]
	var badges: Array = []

	if selected_country_tag_in_browser == tag:
		badges.append("VYBRAN")

	var idx = local_player_tags.find(tag)
	if idx != -1:
		badges.append("OBSAZENO")
		badges.append("HRAC %d" % (idx + 1))
		if new_game_browser_flow and idx == setup_active_player_index:
			badges.append("AKTIVNI")

	var prefix = ""
	if not badges.is_empty():
		prefix = "[%s] " % " | ".join(badges)

	return "%s%s (%s)\nPop: %s  |  HDP: %.1f" % [
		prefix,
		_zobrazene_jmeno_statu(tag),
		tag,
		_formatuj_cislo(int(stats["population"])),
		float(stats["gdp"])
	]

func _obnov_texty_radku_statu() -> void:
	for tag in country_rows.keys():
		var row_btn = country_rows[tag]
		if row_btn:
			var tag_txt = str(tag)
			row_btn.text = _sestav_text_radku_statu(tag_txt)
			var je_obsazeno = new_game_browser_flow and local_player_tags.has(tag_txt)
			var je_aktivne_vybrany = selected_country_tag_in_browser == tag_txt

			if je_obsazeno:
				row_btn.disabled = true
				row_btn.modulate = Color(0.62, 0.62, 0.66, 1.0)
			elif je_aktivne_vybrany:
				row_btn.disabled = false
				row_btn.modulate = Color(0.88, 0.95, 1.0, 1.0)
			else:
				row_btn.disabled = false
				row_btn.modulate = Color(1, 1, 1, 1)

func _aktualizuj_panel_vyberu_hracu() -> void:
	if not selected_players_title or not selected_players_list:
		return

	if new_game_browser_flow:
		selected_players_title.text = "Vybrani hraci pro local multiplayer"
		if local_player_tags.is_empty():
			selected_players_list.text = "Zatim nikdo"
		else:
			var lines: Array = []
			for i in range(local_player_tags.size()):
				var tag = str(local_player_tags[i])
				var prefix = "%d." % (i + 1)
				if i == setup_active_player_index:
					prefix = "%d. >" % (i + 1)
				lines.append("%s %s (%s)" % [prefix, _zobrazene_jmeno_statu(tag), tag])
			selected_players_list.text = "\n".join(lines)
	else:
		selected_players_title.text = "Aktualni vyber"
		if selected_country_tag == "":
			selected_players_list.text = "Zatim nikdo"
		else:
			selected_players_list.text = "%s (%s)" % [_zobrazene_jmeno_statu(selected_country_tag), selected_country_tag]

func _zobrazene_jmeno_statu(tag: String) -> String:
	for nazev in hratelne_staty.keys():
		if hratelne_staty[nazev] == tag:
			return nazev
	if country_stats.has(tag):
		return str(country_stats[tag].get("country_name_en", tag))
	return tag

func _nastav_detail_statu(tag: String):
	if not country_stats.has(tag):
		return

	selected_country_tag_in_browser = tag
	for row_tag in country_rows.keys():
		var row_btn = country_rows[row_tag]
		row_btn.disabled = (row_tag == tag)

	var s = country_stats[tag]
	var jmeno = _zobrazene_jmeno_statu(tag)

	detail_name.text = jmeno
	detail_tag.text = "Tag: %s" % tag
	detail_ideology.text = "Ideologie: %s" % str(s["ideology"]).capitalize()
	detail_population.text = "Populace: %s" % _formatuj_cislo(int(s["population"]))
	detail_gdp.text = "HDP: %.2f mld. USD" % float(s["gdp"])
	detail_recruits.text = "Rekruti: %s" % _formatuj_cislo(int(s["recruitable_population"]))
	detail_soldiers.text = "Vojaci: %s" % _formatuj_cislo(int(s["soldiers"]))
	detail_provinces.text = "Provincie: %d" % int(s["province_count"])
	detail_info.text = _vytvor_souhrn_statu(jmeno, s)

	var flag_tex = _load_normalized_flag_texture("res://map_data/Flags/%s.svg" % tag, 240, 150)
	detail_flag.texture = flag_tex

func _vytvor_souhrn_statu(jmeno: String, s: Dictionary) -> String:
	var populace = max(1, int(s.get("population", 0)))
	var hdp = float(s.get("gdp", 0.0))
	var provincie = int(s.get("province_count", 0))
	var rekruti = int(s.get("recruitable_population", 0))
	var vojaci = int(s.get("soldiers", 0))

	var hdp_na_osobu = (hdp * 1000000000.0) / float(populace)
	var mobilizace = float(vojaci) / float(populace)
	var rekrut_podil = float(rekruti) / float(populace)

	var vyspelost = "nizsi"
	if hdp_na_osobu >= 45000.0:
		vyspelost = "vysoka"
	elif hdp_na_osobu >= 25000.0:
		vyspelost = "stredni"

	var velikost = "mensi"
	if provincie >= 35:
		velikost = "velmi rozsahla"
	elif provincie >= 18:
		velikost = "stredne velka"

	var vojenska_sila = "omezena"
	if mobilizace >= 0.015:
		vojenska_sila = "vysoka"
	elif mobilizace >= 0.007:
		vojenska_sila = "solidni"

	var silne = []
	var slabiny = []

	if vyspelost == "vysoka":
		silne.append("silna ekonomika a stabilni zaklad pro dlouhodobou expanzi")
	elif vyspelost == "stredni":
		silne.append("vyvazena ekonomika vhodna pro univerzalni strategii")
	else:
		slabiny.append("nizsi ekonomicky vykon, pomalejsi tempo modernizace")

	if provincie >= 25:
		silne.append("siroke uzemi, vic moznosti manevru a obrany")
	elif provincie <= 8:
		slabiny.append("male uzemi, citlivost na rychly tlak nepratele")

	if rekrut_podil >= 0.09:
		silne.append("nadprumerny zasobnik rekrutu pro posilovani armady")
	elif rekrut_podil <= 0.04:
		slabiny.append("omezeny rust armady kvuli nizsimu podilu rekrutu")

	if vojenska_sila == "vysoka":
		silne.append("silna okamzita bojova pripravenost")
	elif vojenska_sila == "omezena":
		slabiny.append("slabsi vychozi armada, vhodnejsi opatrny start")

	var silne_text = ", ".join(silne) if not silne.is_empty() else "flexibilni start bez vyraznych extremu"
	var slabiny_text = ", ".join(slabiny) if not slabiny.is_empty() else "zadna kriticka slabina na startu"

	return "%s je %s zeme s %s zakladnou a %s vojenskou pripravenosti. Silne stranky: %s. Rizika: %s." % [jmeno, velikost, vyspelost, vojenska_sila, silne_text, slabiny_text]

func _on_country_row_pressed(tag: String):
	if new_game_browser_flow:
		_prirad_stat_aktivnimu_hraci(tag)
		return
	_nastav_detail_statu(tag)
	_obnov_texty_radku_statu()

func _ziskej_setup_tag_aktivniho_hrace() -> String:
	if local_player_tags.is_empty():
		return ""
	if setup_active_player_index < 0 or setup_active_player_index >= local_player_tags.size():
		return ""
	return str(local_player_tags[setup_active_player_index])

func _najdi_prvni_volny_tag() -> String:
	var vsechny_tagy = country_stats.keys()
	vsechny_tagy.sort_custom(func(a, b):
		return _zobrazene_jmeno_statu(str(a)) < _zobrazene_jmeno_statu(str(b))
	)

	for raw_tag in vsechny_tagy:
		var tag = str(raw_tag)
		if not local_player_tags.has(tag):
			return tag

	return ""

func _prirad_stat_aktivnimu_hraci(tag: String) -> void:
	if local_player_tags.is_empty():
		return

	if setup_active_player_index < 0 or setup_active_player_index >= local_player_tags.size():
		return

	var idx_obsazeni = local_player_tags.find(tag)
	if idx_obsazeni != -1 and idx_obsazeni != setup_active_player_index:
		if browser_flow_hint:
			browser_flow_hint.text = "Stat %s je uz obsazeny jinym hracem." % tag
		return

	local_player_tags[setup_active_player_index] = tag
	selected_country_tag_in_browser = tag
	selected_country_tag = str(local_player_tags[0])
	_nastav_detail_statu(tag)
	_obnov_text_vyberu()
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()

func _pridej_dalsiho_hrace_do_setupu() -> void:
	var novy_tag = _najdi_prvni_volny_tag()
	if novy_tag == "":
		if browser_flow_hint:
			browser_flow_hint.text = "Neni dostupny dalsi volny stat pro noveho hrace."
		return

	local_player_tags.append(novy_tag)
	setup_active_player_index = local_player_tags.size() - 1
	selected_country_tag_in_browser = novy_tag
	_nastav_detail_statu(novy_tag)
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()

func _otevri_browser_statu():
	if selected_country_tag != "" and country_stats.has(selected_country_tag):
		_nastav_detail_statu(selected_country_tag)
	_aktualizuj_browser_napovedu()
	country_browser_panel.show()

func _on_confirm_country_pressed():
	if new_game_browser_flow:
		_pridej_dalsiho_hrace_do_setupu()
		return

	if selected_country_tag_in_browser != "":
		selected_country_tag = selected_country_tag_in_browser
		_obnov_text_vyberu()
		_aktualizuj_panel_vyberu_hracu()

	country_browser_panel.hide()

func _on_close_browser_pressed():
	if new_game_browser_flow:
		if local_player_tags.is_empty() and selected_country_tag != "":
			local_player_tags.append(selected_country_tag)
		selected_country_tag = str(local_player_tags[0]) if not local_player_tags.is_empty() else selected_country_tag
		setup_active_player_index = 0
		new_game_browser_flow = false
		btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
		btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
		_obnov_texty_radku_statu()
		_aktualizuj_panel_vyberu_hracu()
		_aktualizuj_browser_napovedu()
		country_browser_panel.hide()
		_spust_hru_vyberem(local_player_tags)
		return

	new_game_browser_flow = false
	btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
	btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	country_browser_panel.hide()

func _on_close_browser_corner_pressed():
	new_game_browser_flow = false
	setup_active_player_index = 0
	btn_confirm_country.text = BROWSER_CONFIRM_DEFAULT_TEXT
	btn_close_browser.text = BROWSER_CLOSE_DEFAULT_TEXT
	local_player_tags.clear()
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	country_browser_panel.hide()

func _obnov_text_vyberu():
	if local_player_tags.size() > 1:
		selected_country_label.text = "Lokalni hraci: %s" % ", ".join(local_player_tags)
		if menu_hint_label:
			menu_hint_label.text = "Pripraveno: %d hraci. Klikni Nova hra pro upravu vyberu nebo Pokracovat pro rychly start." % local_player_tags.size()
		_aktualizuj_panel_vyberu_hracu()
		return

	if selected_country_tag == "":
		selected_country_label.text = "Vybrany stat: zadny"
		return

	var nazev_statu = _zobrazene_jmeno_statu(selected_country_tag)
	selected_country_label.text = "Vybrany stat: %s (%s)" % [nazev_statu, selected_country_tag]
	if menu_hint_label:
		menu_hint_label.text = "Pro multiplayer pridej v Nove hre dalsi staty."
	if country_stats.has(selected_country_tag):
		_nastav_detail_statu(selected_country_tag)
	_aktualizuj_panel_vyberu_hracu()

func _aktualizuj_browser_napovedu():
	if not browser_flow_hint or not browser_subtitle or not list_hint:
		return

	if new_game_browser_flow:
		browser_subtitle.text = "Hrac 1 je automaticky pridan. Klikanim volis stat aktivnimu hraci."
		list_hint.text = "Spustit hru = solo nebo start vice hracu. Pridat hrace = dalsi hrac."
		if local_player_tags.is_empty():
			browser_flow_hint.text = "Pripravuje se vyber hracu..."
		else:
			var cislo_hrace = setup_active_player_index + 1
			var aktivni_tag = _ziskej_setup_tag_aktivniho_hrace()
			browser_flow_hint.text = "Vybiras stat pro HRACE %d. Aktualne: %s" % [cislo_hrace, aktivni_tag]
	else:
		browser_subtitle.text = "Vyber stat pro solo nebo pridej vice statu pro local multiplayer"
		list_hint.text = "Klikni na stat pro detail a pak potvrd vyber"
		browser_flow_hint.text = "Rezim solo: vyber stat a potvrd."

func _nastav_stav_pokracovani():
	var ma_save = FileAccess.file_exists(SAVE_FILE_PATH)
	if GameManager and GameManager.has_method("ma_ulozene_hry"):
		ma_save = bool(GameManager.ma_ulozene_hry())
	btn_continue.disabled = not ma_save
	if ma_save:
		btn_continue.text = "Pokracovat"
	else:
		btn_continue.text = "Pokracovat (bez save)"

func _spust_hru_vyberem(player_tags: Array = []):
	var final_tags = player_tags.duplicate()
	if final_tags.is_empty() and selected_country_tag != "":
		final_tags = [selected_country_tag]
	if final_tags.is_empty():
		return
	selected_country_tag = str(final_tags[0])

	# Start a truly fresh session for New Game and avoid carrying previous run state.
	if GameManager and GameManager.has_method("reset_pro_novou_hru"):
		GameManager.reset_pro_novou_hru()

	# Save selected local players to GameManager.
	if GameManager.has_method("nastav_lokalni_hrace"):
		GameManager.nastav_lokalni_hrace(final_tags)
	else:
		GameManager.hrac_stat = selected_country_tag

	print("Lokalni hraci: ", final_tags)
	
	# Load the main map scene
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_new_game_pressed():
	local_player_tags.clear()
	new_game_browser_flow = true
	setup_active_player_index = 0

	var vychozi_tag = selected_country_tag.strip_edges().to_upper()
	if vychozi_tag == "" or not country_stats.has(vychozi_tag):
		vychozi_tag = _najdi_prvni_volny_tag()
	if vychozi_tag == "":
		vychozi_tag = selected_country_tag

	if vychozi_tag != "":
		local_player_tags = [vychozi_tag]
		selected_country_tag = vychozi_tag
		selected_country_tag_in_browser = vychozi_tag
		_nastav_detail_statu(vychozi_tag)

	btn_confirm_country.text = BROWSER_CONFIRM_ADD_PLAYER_TEXT
	btn_close_browser.text = BROWSER_CLOSE_START_TEXT
	_obnov_text_vyberu()
	_obnov_texty_radku_statu()
	_aktualizuj_panel_vyberu_hracu()
	_aktualizuj_browser_napovedu()
	_otevri_browser_statu()

func _on_continue_pressed():
	var ma_save = FileAccess.file_exists(SAVE_FILE_PATH)
	if GameManager and GameManager.has_method("ma_ulozene_hry"):
		ma_save = bool(GameManager.ma_ulozene_hry())

	if not ma_save:
		_nastav_stav_pokracovani()
		return

	var err = get_tree().change_scene_to_file(MAP_SCENE_PATH)
	if err != OK:
		push_warning("Nepodarilo se otevrit mapu pro Continue. Chyba: %s" % str(err))
		return

	# Wait for map scene setup, then override runtime state with saved data.
	await get_tree().process_frame
	if GameManager and GameManager.has_method("nacti_posledni_hru"):
		if not bool(GameManager.nacti_posledni_hru()):
			push_warning("Continue selhalo: save se nepodarilo nacist.")
	elif GameManager and GameManager.has_method("nacti_hru"):
		if not bool(GameManager.nacti_hru()):
			push_warning("Continue selhalo: save se nepodarilo nacist.")

func _on_settings_pressed():
	settings_dialog.popup_centered()

func _on_credits_pressed():
	credits_dialog.popup_centered()

func _on_exit_pressed():
	exit_dialog.popup_centered()

func _on_exit_confirmed():
	get_tree().quit()

func _formatuj_cislo(cislo: int) -> String:
	var text_cisla = str(cislo)
	var vysledek = ""
	var delka = text_cisla.length()
	for i in range(delka):
		if i > 0 and (delka - i) % 3 == 0:
			vysledek += " "
		vysledek += text_cisla[i]
	return vysledek
