# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

extends Node
# this script drives a specific gameplay/UI area and keeps related logic together.

# Alliance data storage used by diplomacy and UI lookups.
# `alliances` keeps alliance metadata, `country_alliances` is reverse mapping by country,
# and `alliance_members` is a fast members list by alliance id.

# Small loader for alliance CSV data. Nothing fancy, just keeps parsed tables ready.
# Aliances data
var alliances: Dictionary = {}  # alliance_id -> {name, color, founded_year, description}
var country_alliances: Dictionary = {}  # country_iso3 -> [alliance_ids]
var alliance_members: Dictionary = {}  # alliance_id -> [country_iso3s]

# Inputs: none
# Outputs: none
# Execution timing: Called once when this node enters the scene tree.
# Steps:
# 1. Load alliance definitions from `Alliances.csv`.
# 2. Load country membership mappings from `CountryAllianceMembership.csv`.
func _ready():
	load_alliances()
	load_country_alliance_membership()

# Inputs: none
# Outputs: none
# Execution timing: Called during startup from `_ready()`.
# Steps:
# 1. Open `Alliances.csv` and return early on failure.
# 2. Skip CSV header row.
# 3. Parse each non-empty row and validate field count.
# 4. Create alliance entries in `alliances` with metadata and empty members.
# 5. Initialize empty member arrays in `alliance_members`.
# 6. Print total loaded alliances for debugging.
func load_alliances():
	"""Load alliances from CSV file"""
	# First pass: create alliance definitions only.
	# Membership is linked in the second pass to keep parsing resilient.
	var file_path = "res://map_data/Alliances.csv"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		print("ERROR: Cannot load alliances from ", file_path)
		return
	
	file.get_line()
	
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty():
			continue
		
		var parts = line.split(";")
		# Ignore malformed rows instead of aborting whole file load.
		if parts.size() < 5:
			continue
		
		var alliance_id = parts[0].strip_edges()
		var alliance_name = parts[1].strip_edges()
		var color_hex = parts[2].strip_edges()
		var founded_year = int(parts[3].strip_edges())
		var description = parts[4].strip_edges()
		
		alliances[alliance_id] = {
			"name": alliance_name,
			"color": Color.html(color_hex),
			"founded_year": founded_year,
			"description": description,
			"members": []
		}
		
		alliance_members[alliance_id] = []
	
	print("Loaded ", alliances.size(), " alliances")

# Inputs: none
# Outputs: none
# Execution timing: Called during startup from `_ready()`, after `load_alliances()`.
# Steps:
# 1. Open `CountryAllianceMembership.csv` and return early on failure.
# 2. Skip CSV header row.
# 3. Parse each non-empty row and validate field count.
# 4. Add alliance ids to `country_alliances` reverse mapping.
# 5. Add countries to `alliance_members` with duplicate protection.
# 6. Mirror members into `alliances[alliance_id]["members"]` when alliance exists.
# 7. Print completion message for debugging.
func load_country_alliance_membership():
	"""Load country-alliance membership mappings"""
	# Second pass: connect countries to alliances and sync all lookup dictionaries.
	var file_path = "res://map_data/CountryAllianceMembership.csv"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		print("ERROR: Cannot load country alliance membership from ", file_path)
		return
	
	file.get_line()  # Skip header
	
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty():
			continue
		
		var parts = line.split(";")
		if parts.size() < 2:
			continue
		
		var country_iso3 = parts[0].strip_edges()
		var alliance_id = parts[1].strip_edges()
		
		# Add country to alliance list
		if not country_alliances.has(country_iso3):
			country_alliances[country_iso3] = []
		country_alliances[country_iso3].append(alliance_id)
		
		# Add alliance member to alliance
		if alliance_members.has(alliance_id):
			# Duplicate guard is important because csv can contain repeated mappings.
			if not alliance_members[alliance_id].has(country_iso3):
				alliance_members[alliance_id].append(country_iso3)
		
		# Update alliances dictionary
		if alliances.has(alliance_id):
			if not alliances[alliance_id]["members"].has(country_iso3):
				alliances[alliance_id]["members"].append(country_iso3)
	
	print("Loaded country-alliance memberships")

# Inputs:
# - `country_iso3`: ISO3 code of the country to query.
# Outputs:
# - `Array`: Alliance ids for the country, or empty array if none.
# Execution timing: Called whenever another system needs country alliance list.
# Steps:
# 1. Look up `country_iso3` in `country_alliances`.
# 2. Return stored list or `[]` fallback.
func get_country_alliances(country_iso3: String) -> Array:
	"""Get list of alliances a country belongs to"""
	return country_alliances.get(country_iso3, [])

# Inputs:
# - `alliance_id`: Alliance identifier.
# Outputs:
# - `Array`: Country ISO3 member list, or empty array if unknown alliance.
# Execution timing: Called by UI/gameplay systems that need alliance membership.
# Steps:
# 1. Look up `alliance_id` in `alliance_members`.
# 2. Return stored member list or `[]` fallback.
func get_alliance_members(alliance_id: String) -> Array:
	"""Get list of countries in an alliance"""
	return alliance_members.get(alliance_id, [])

# Inputs:
# - `alliance_id`: Alliance identifier.
# Outputs:
# - `Dictionary`: Alliance metadata dictionary, or `{}` when not found.
# Execution timing: Called on demand for full alliance detail reads.
# Steps:
# 1. Look up `alliance_id` in `alliances`.
# 2. Return stored dictionary or `{}` fallback.
func get_alliance_info(alliance_id: String) -> Dictionary:
	"""Get alliance details"""
	return alliances.get(alliance_id, {})

# Inputs:
# - `alliance_id`: Alliance identifier.
# Outputs:
# - `Color`: Alliance color, or `Color.WHITE` fallback.
# Execution timing: Called when visual systems need alliance tint/color.
# Steps:
# 1. Check if `alliance_id` exists in `alliances`.
# 2. Return stored `color` field when present.
# 3. Return `Color.WHITE` when missing.
func get_alliance_color(alliance_id: String) -> Color:
	"""Get alliance color"""
	if alliances.has(alliance_id):
		return alliances[alliance_id]["color"]
	return Color.WHITE

# Inputs:
# - `country_iso3`: ISO3 code of the country.
# Outputs:
# - `String`: First alliance id in list (primary), or empty string when none.
# Execution timing: Called when systems need a single representative alliance.
# Steps:
# 1. Fetch country alliance list via `get_country_alliances()`.
# 2. Return first item if available.
# 3. Return `""` fallback when list is empty.
func get_country_primary_alliance(country_iso3: String) -> String:
	"""Get the first (primary) alliance of a country"""
	var alliances_list = get_country_alliances(country_iso3)
	if alliances_list.size() > 0:
		return alliances_list[0]
	return ""

# Inputs: none
# Outputs: none
# Execution timing: Manual debug utility, called only when explicitly invoked.
# Steps:
# 1. Iterate every alliance id in `alliances`.
# 2. Read alliance metadata and member list.
# 3. Print id/name, members, and color for inspection.
func print_alliances_info():
	"""Debug: Print all alliances and their members"""
	for alliance_id in alliances:
		var alliance = alliances[alliance_id]
		var members = alliance_members.get(alliance_id, [])
		print("Alliance: ", alliance_id, " (", alliance["name"], ")")
		print("  Members: ", members)
		print("  Color: ", alliance["color"])



