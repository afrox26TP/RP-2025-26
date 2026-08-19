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
	# Inputs:
	# - `state_tag`: Country/state identifier (expected ISO-like tag).
	# Outputs:
	# - `String`: `user://custom_flags/<TAG>.png` or empty string for invalid tags.
	# Execution timing: Called before any custom-flag read/write operation.
	# Steps:
	# 1. Trim and uppercase the incoming tag.
	# 2. Reject empty tag and `SEA` special case.
	# 3. Build and return normalized custom flag path.
	# SEA/empty are ignored because they are not editable playable states.
	var clean = str(state_tag).strip_edges().to_upper()
	if clean == "" or clean == "SEA":
		return ""
	return "%s/%s.png" % [CUSTOM_FLAGS_DIR, clean]

static func has_custom_flag(state_tag: String) -> bool:
	# Inputs:
	# - `state_tag`: Country/state identifier.
	# Outputs:
	# - `bool`: `true` when resolved path exists as a file.
	# Execution timing: Called by UI logic to decide whether to show custom/default flag.
	# Steps:
	# 1. Resolve normalized custom path from tag.
	# 2. Return `false` for invalid/empty path.
	# 3. Check filesystem existence for the resolved file.
	var path = get_custom_flag_path(state_tag)
	return path != "" and FileAccess.file_exists(path)

static func ensure_custom_flags_dir() -> bool:
	# Inputs: none
	# Outputs:
	# - `bool`: `true` when directory exists or is created successfully.
	# Execution timing: Called before saving custom flags.
	# Steps:
	# 1. Open `user://` root directory.
	# 2. Return `false` if root is unavailable.
	# 3. Return `true` if `custom_flags` already exists.
	# 4. Attempt recursive create and return success status.
	var root_dir = DirAccess.open("user://")
	if root_dir == null:
		return false
	if root_dir.dir_exists("custom_flags"):
		return true
	return root_dir.make_dir_recursive("custom_flags") == OK

static func load_custom_flag_texture(state_tag: String, cache: Dictionary = {}):
	# Inputs:
	# - `state_tag`: Country/state identifier.
	# - `cache`: Optional path -> texture cache dictionary.
	# Outputs:
	# - `Texture2D|null`: Loaded texture when available, otherwise `null`.
	# Execution timing: Called by UI refresh/render flows that need a flag texture.
	# Steps:
	# 1. Resolve flag path and exit if invalid or missing file.
	# 2. Return cached texture when present.
	# 3. Globalize path and load image from disk.
	# 4. Return `null` for load failure/empty image.
	# 5. Create texture, store it in cache, and return it.
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
	# Inputs:
	# - `state_tag`: Country/state identifier.
	# - `source_path`: Absolute/local source image path selected by user.
	# Outputs:
	# - `Dictionary`: Result payload with `ok` flag and either `path` or `reason`/`error`.
	# Execution timing: Called when player confirms custom flag import.
	# Steps:
	# 1. Resolve destination path and validate state.
	# 2. Validate source path is not empty.
	# 3. Ensure custom flags directory exists.
	# 4. Load source image and validate non-empty data.
	# 5. Save image as PNG at destination path.
	# 6. Return structured success or failure dictionary.
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
	# Inputs:
	# - `state_tag`: Country/state identifier.
	# Outputs:
	# - `bool`: `true` when file is absent or removed successfully.
	# Execution timing: Called on reset/remove actions for a single country flag.
	# Steps:
	# 1. Resolve destination path and reject invalid tag.
	# 2. Return `true` if file is already missing.
	# 3. Open custom flags directory.
	# 4. Remove file by basename and return result status.
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
	# Inputs:
	# - `tags`: Array of country/state tags to clear.
	# Outputs: none
	# Execution timing: Called during bulk reset flows for selected countries.
	# Steps:
	# 1. Iterate each raw tag in `tags`.
	# 2. Convert each entry to string.
	# 3. Call `clear_custom_flag()` per tag.
	# Bulk cleanup helper used on new game / reset flows.
	for raw_tag in tags:
		clear_custom_flag(str(raw_tag))

static func clear_all_custom_flags() -> void:
	# Inputs: none
	# Outputs: none
	# Execution timing: Called on full reset/cleanup operations.
	# Steps:
	# 1. Open custom flags directory and exit if unavailable.
	# 2. Iterate all directory entries.
	# 3. Skip subdirectories.
	# 4. Remove files with allowed image extensions only.
	# 5. End directory listing cleanly.
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

