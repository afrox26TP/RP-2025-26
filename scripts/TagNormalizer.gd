extends RefCounted

## Canonicalizes country tags and unambiguous country-name aliases.

var _map_data: Dictionary = {}
var _alias_to_owner: Dictionary = {}
var _cache_dirty: bool = true


func set_map_data(map_data: Dictionary) -> void:
	if _map_data != map_data:
		_map_data = map_data
		invalidate()


func invalidate() -> void:
	_alias_to_owner.clear()
	_cache_dirty = true


func normalize_tag(tag: String) -> String:
	var clean = tag.strip_edges().to_upper()
	if clean == "" or clean == "SEA":
		return clean
	if _cache_dirty:
		_rebuild_alias_cache()
	return str(_alias_to_owner.get(clean, clean))


func normalize_country_name(raw_name: String) -> String:
	return raw_name.strip_edges().to_upper()


func country_name_for_owner(owner_tag: String) -> String:
	var wanted = normalize_tag(owner_tag)
	if wanted == "":
		return ""
	for province_id in _map_data:
		var province = _map_data[province_id] as Dictionary
		if normalize_tag(str(province.get("owner", ""))) != wanted:
			continue
		var country_name = normalize_country_name(str(province.get("country_name", "")))
		if country_name != "":
			return country_name
	return ""


static func is_likely_country_tag(value: String) -> bool:
	var candidate = value.strip_edges().to_upper()
	if candidate.length() != 3:
		return false
	for index in candidate.length():
		var code = candidate.unicode_at(index)
		if code < 65 or code > 90:
			return false
	return true


func _rebuild_alias_cache() -> void:
	_alias_to_owner.clear()
	var country_name_to_owner: Dictionary = {}
	var conflicted_country_names: Dictionary = {}

	for province_id in _map_data:
		var province = _map_data[province_id] as Dictionary
		var owner = str(province.get("owner", "")).strip_edges().to_upper()
		if owner == "":
			continue
		_alias_to_owner[owner] = owner
		if not is_likely_country_tag(owner):
			continue

		var country_name = str(province.get("country_name", "")).strip_edges().to_upper()
		if country_name == "" or conflicted_country_names.has(country_name):
			continue
		if not country_name_to_owner.has(country_name):
			country_name_to_owner[country_name] = owner
		elif str(country_name_to_owner[country_name]) != owner:
			country_name_to_owner.erase(country_name)
			conflicted_country_names[country_name] = true

	for alias_name in country_name_to_owner:
		_alias_to_owner[str(alias_name)] = str(country_name_to_owner[alias_name])
	_cache_dirty = false
