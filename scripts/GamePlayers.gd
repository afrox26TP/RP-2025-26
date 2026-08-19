extends "res://scripts/GameRelationships.gd"

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
