# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends RefCounted

# Utilities for user-provided country flags stored in `user://custom_flags`.
# Functions here are intentionally static so UI scripts can call them directly.

const CUSTOM_FLAGS_DIR := "user://custom_flags"

static func get_custom_flag_path(state_tag: String) -> String:
	# SEA/empty are ignored because they are not editable playable states.
	var clean = str(state_tag).strip_edges().to_upper()
	if clean == "" or clean == "SEA":
		return ""
	return "%s/%s.png" % [CUSTOM_FLAGS_DIR, clean]

static func has_custom_flag(state_tag: String) -> bool:
	var path = get_custom_flag_path(state_tag)
	return path != "" and FileAccess.file_exists(path)

static func ensure_custom_flags_dir() -> bool:
	var root_dir = DirAccess.open("user://")
	if root_dir == null:
		return false
	if root_dir.dir_exists("custom_flags"):
		return true
	return root_dir.make_dir_recursive("custom_flags") == OK

static func load_custom_flag_texture(state_tag: String, cache: Dictionary = {}):
	# Uses optional cache to avoid reloading image files every UI refresh.
	var path = get_custom_flag_path(state_tag)
	if path == "" or not FileAccess.file_exists(path):
		return null
	if cache.has(path):
		return cache[path]

	var abs_path = ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(abs_path)
	if image == null or image.is_empty():
		return null

	var texture = ImageTexture.create_from_image(image)
	cache[path] = texture
	return texture

static func save_custom_flag_from_source(state_tag: String, source_path: String) -> Dictionary:
	var path = get_custom_flag_path(state_tag)
	if path == "":
		return {"ok": false, "reason": "Invalid state."}
	if source_path.strip_edges() == "":
		return {"ok": false, "reason": "No file selected."}
	if not ensure_custom_flags_dir():
		return {"ok": false, "reason": "Custom flag directory could not be created."}

	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return {"ok": false, "reason": "Selected image could not be loaded."}

	# Always save as png to keep one predictable format for runtime loading.
	var save_err = image.save_png(ProjectSettings.globalize_path(path))
	if save_err != OK:
		return {"ok": false, "reason": "Flag could not be saved.", "error": save_err}

	return {"ok": true, "path": path}

static func clear_custom_flag(state_tag: String) -> bool:
	var path = get_custom_flag_path(state_tag)
	if path == "":
		return false
	if not FileAccess.file_exists(path):
		return true
	var dir = DirAccess.open(CUSTOM_FLAGS_DIR)
	if dir == null:
		return false
	return dir.remove(path.get_file()) == OK

static func clear_custom_flags_for_tags(tags: Array) -> void:
	# Bulk cleanup helper used on new game / reset flows.
	for raw_tag in tags:
		clear_custom_flag(str(raw_tag))

static func clear_all_custom_flags() -> void:
	var dir = DirAccess.open(CUSTOM_FLAGS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name = dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		var lower = name.to_lower()
		# Keep deletion constrained to image extensions to avoid nuking unrelated files.
		if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".bmp"):
			dir.remove(name)
	dir.list_dir_end()

