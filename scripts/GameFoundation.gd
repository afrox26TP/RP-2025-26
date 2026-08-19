extends "res://scripts/GameState.gd"

## Shared scene lookup and country identity services used by domain managers.

const TagNormalizerScript = preload("res://scripts/TagNormalizer.gd")

var _tag_normalizer = TagNormalizerScript.new()


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
	_tag_normalizer.set_map_data(map_data)
	return _tag_normalizer.normalize_tag(tag)


func _je_pravdepodobny_stat_tag(value: String) -> bool:
	return TagNormalizerScript.is_likely_country_tag(value)


func _rebuild_tag_alias_cache() -> void:
	_tag_normalizer.set_map_data(map_data)
	_tag_normalizer.invalidate()


func _normalizuj_nazev_statu(raw_name: String) -> String:
	return _tag_normalizer.normalize_country_name(raw_name)


func _ziskej_nazev_statu_podle_owner(owner_tag: String) -> String:
	_tag_normalizer.set_map_data(map_data)
	return _tag_normalizer.country_name_for_owner(owner_tag)


func _invalidate_tag_alias_cache() -> void:
	_tag_normalizer.invalidate()
