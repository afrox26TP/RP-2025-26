extends RefCounted

## Pure log classification and retention rules. Runtime log ownership stays in GameState.

func is_critical_popup(title: String, text: String) -> bool:
	var combined = "%s %s" % [title.to_lower(), text.to_lower()]
	for token in [
		"valk", "war", "kapitul", "surrender", "hlavni mesto", "capital",
		"anex", "vyhlasil valku", "declared war", "porazen", "defeated",
		"military access", "vojensky pristup"
	]:
		if combined.findn(token) != -1:
			return true
	return false

func normalize_category(category: String, title: String, text: String) -> String:
	var normalized = category.strip_edges().to_lower()
	match normalized:
		"war":
			return "war"
		"alliance":
			return "alliance"
		"treaty", "treaties", "non_aggression":
			return "treaties"
		"gift", "gifts":
			return "gifts"
		"relations":
			return "relations"

	var body = (title + " " + text).to_lower()
	if _contains_any(body, ["valk", "war", "mir", "peace", "kapitul", "okup", "anex", "surrender"]):
		return "war"
	if _contains_any(body, ["alianc", "alliance", "spojenec"]):
		return "alliance"
	if _contains_any(body, ["neagres", "smlouv", "pakt", "treaty", "truce"]):
		return "treaties"
	if _contains_any(body, ["dar", "gift", "usd", "finance", "financni"]):
		return "gifts"
	if _contains_any(body, ["vztah", "relations"]):
		return "relations"
	return "negotiations" if normalized == "diplomacy" else "other"

func category_priority(category: String, title: String, text: String) -> int:
	match normalize_category(category, title, text):
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

func remove_expired_treaties(log_entries: Array, current_turn: int, duration_turns: int) -> void:
	for index in range(log_entries.size() - 1, -1, -1):
		var item = log_entries[index]
		if not (item is Dictionary):
			continue
		var entry = item as Dictionary
		if normalize_category(str(entry.get("category", "")), str(entry.get("title", "")), str(entry.get("text", ""))) != "treaties":
			continue
		if current_turn - int(entry.get("turn", current_turn)) >= duration_turns:
			log_entries.remove_at(index)

func removal_candidate(log_entries: Array) -> int:
	if log_entries.is_empty():
		return -1
	var chosen_index := -1
	var chosen_priority := 999999
	var chosen_turn := 999999999
	for index in range(log_entries.size()):
		var item = log_entries[index]
		if not (item is Dictionary):
			if chosen_index == -1:
				chosen_index = index
			continue
		var entry = item as Dictionary
		var priority = category_priority(str(entry.get("category", "")), str(entry.get("title", "")), str(entry.get("text", "")))
		var turn = int(entry.get("turn", -1))
		if chosen_index == -1 or priority < chosen_priority or (priority == chosen_priority and (turn < chosen_turn or (turn == chosen_turn and index < chosen_index))):
			chosen_index = index
			chosen_priority = priority
			chosen_turn = turn
	return chosen_index

func trim(log_entries: Array, max_items: int, current_turn: int, treaty_duration_turns: int) -> void:
	remove_expired_treaties(log_entries, current_turn, treaty_duration_turns)
	while log_entries.size() > max_items:
		var index = removal_candidate(log_entries)
		log_entries.remove_at(index if index >= 0 and index < log_entries.size() else 0)

func _contains_any(text: String, tokens: Array) -> bool:
	for token_any in tokens:
		if text.findn(str(token_any)) != -1:
			return true
	return false
