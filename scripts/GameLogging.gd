extends "res://scripts/GamePlayers.gd"

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

func _ziskej_jmeno_statu_podle_tagu(tag: String) -> String:
	var wanted = _normalizuj_tag(tag)
	for province_any in map_data.values():
		var province = province_any as Dictionary
		if _normalizuj_tag(str(province.get("owner", ""))) == wanted:
			var country_name = str(province.get("country_name", wanted)).strip_edges()
			return country_name if country_name != "" else wanted
	return wanted

func _zprava_obsahuje_stat(entry: Dictionary, state_tag: String) -> bool:
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return false
	var full_text = str(entry.get("title", "")) + " " + str(entry.get("text", ""))
	if full_text.to_upper().findn(wanted) != -1:
		return true
	var country_name = _ziskej_jmeno_statu_podle_tagu(wanted).strip_edges()
	return country_name != "" and full_text.to_lower().findn(country_name.to_lower()) != -1

func ziskej_relevantni_zpravy_statu(state_tag: String, limit: int = 160, jen_aktualni_kolo: bool = true) -> Array:
	_udrzba_vsech_logu()
	var wanted = _normalizuj_tag(state_tag)
	if wanted == "":
		return []
	var merged: Array = []
	var seen: Dictionary = {}
	for source_any in [log_zprav_hracu.get(wanted, []) as Array, log_globalnich_zprav]:
		for entry_any in source_any as Array:
			var entry = entry_any as Dictionary
			if jen_aktualni_kolo and int(entry.get("turn", -1)) != aktualni_kolo:
				continue
			if source_any == log_globalnich_zprav and not _zprava_obsahuje_stat(entry, wanted):
				continue
			var key = "%s|%s|%s" % [entry.get("turn", ""), entry.get("title", ""), entry.get("text", "")]
			if not seen.has(key):
				seen[key] = true
				merged.append(entry)
	return merged.slice(max(0, merged.size() - limit), merged.size()) if merged.size() > limit else merged

func _pridej_popup_zucastnenym_hracum(tag_a: String, tag_b: String, title: String, text: String) -> void:
	var first = _normalizuj_tag(tag_a)
	var second = _normalizuj_tag(tag_b)
	var related: Array = []
	for tag in [first, second]:
		if tag != "" and tag != "SEA" and not related.has(tag):
			related.append(tag)
	for tag in related:
		if je_lidsky_stat(tag):
			_pridej_popup_hraci(tag, title, text, false, related)

func _zobraz_cekajici_popupy_aktivniho_hrace() -> void:
	var active = _normalizuj_tag(hrac_stat)
	var queue = cekajici_popupy_hracu.get(active, []) as Array
	if active == "" or queue.is_empty():
		return
	var map_loader = _get_map_loader()
	if map_loader == null or not map_loader.has_method("_ukaz_bitevni_popup"):
		return
	var items = queue.duplicate(true)
	if items.size() > 1:
		var batch: Array = []
		for index in range(min(items.size(), POPUP_BATCH_MAX_ITEMS)):
			var item = items[index] as Dictionary
			if str(item.get("text", "")).strip_edges() != "":
				batch.append(item)
		if items.size() > POPUP_BATCH_MAX_ITEMS:
			batch.append({"title": "System", "text": "+%d additional reports were queued this turn." % (items.size() - POPUP_BATCH_MAX_ITEMS), "state_tags": []})
		if map_loader.has_method("_ukaz_batch_popup"):
			await map_loader._ukaz_batch_popup(batch)
		else:
			var blocks: Array = []
			for item in batch:
				blocks.append("[%s]\n%s" % [item.get("title", "Report"), item.get("text", "")])
			await map_loader._ukaz_bitevni_popup("Reports", "\n\n".join(blocks))
	else:
		var item = items[0] as Dictionary
		await map_loader._ukaz_bitevni_popup(str(item.get("title", "Report")), str(item.get("text", "")), {}, item.get("state_tags", []) as Array)
	queue.clear()
