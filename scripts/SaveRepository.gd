extends RefCounted

## Handles save-slot paths and filesystem serialization.
## Runtime snapshot assembly and application remain outside this repository.

var _legacy_path: String
var _slots_directory: String
var _slot_extension: String


func _init(initial_legacy_path: String, slots_directory: String, slot_extension: String) -> void:
	_legacy_path = initial_legacy_path
	_slots_directory = slots_directory
	_slot_extension = slot_extension


func normalize_slot_name(slot_name: String) -> String:
	var clean_name = slot_name.strip_edges()
	if clean_name == "":
		clean_name = "save_%s" % Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	for invalid_character in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		clean_name = clean_name.replace(str(invalid_character), "_")
	clean_name = clean_name.replace("\n", "_").replace("\r", "_").replace("\t", "_")
	clean_name = clean_name.strip_edges().replace(" ", "_")
	return clean_name if clean_name != "" else "save"


func slot_path(slot_name: String) -> String:
	return "%s/%s%s" % [_slots_directory, normalize_slot_name(slot_name), _slot_extension]


func ensure_slots_directory() -> void:
	var root_directory = DirAccess.open("user://")
	if root_directory and not root_directory.dir_exists(_slots_directory.trim_prefix("user://")):
		root_directory.make_dir_recursive(_slots_directory.trim_prefix("user://"))


func write_state(path: String, state: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(state, true)
	return true


func read_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw = file.get_var(true)
	return raw as Dictionary if raw is Dictionary else {}


func list_slots() -> Array:
	ensure_slots_directory()
	var slots: Array = []
	var directory = DirAccess.open(_slots_directory)
	if directory == null:
		return slots

	directory.list_dir_begin()
	while true:
		var file_name = directory.get_next()
		if file_name == "":
			break
		if directory.current_is_dir() or not file_name.ends_with(_slot_extension):
			continue
		var path = "%s/%s" % [_slots_directory, file_name]
		slots.append({
			"name": file_name.substr(0, file_name.length() - _slot_extension.length()),
			"path": path,
			"modified": int(FileAccess.get_modified_time(path))
		})
	directory.list_dir_end()
	slots.sort_custom(func(a, b):
		return int((a as Dictionary).get("modified", 0)) > int((b as Dictionary).get("modified", 0))
	)
	return slots


func has_any_save() -> bool:
	return FileAccess.file_exists(_legacy_path) or not list_slots().is_empty()


func delete_slot(slot_name: String) -> bool:
	var path = slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func delete_legacy_save() -> bool:
	if not FileAccess.file_exists(_legacy_path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(_legacy_path)) == OK


func legacy_path() -> String:
	return _legacy_path
