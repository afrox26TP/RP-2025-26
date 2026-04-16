extends Node

# Small loader for alliance CSV data. Nothing fancy, just keeps parsed tables ready.
# Aliances data
var alliances: Dictionary = {}  # alliance_id -> {name, color, founded_year, description}
var country_alliances: Dictionary = {}  # country_iso3 -> [alliance_ids]
var alliance_members: Dictionary = {}  # alliance_id -> [country_iso3s]

func _ready():
	load_alliances()
	load_country_alliance_membership()

# Reads base alliance defs first, then membership is linked in second pass.
func load_alliances():
	"""Load alliances from CSV file"""
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

# Separate pass so missing alliance rows dont instantly break everything.
func load_country_alliance_membership():
	"""Load country-alliance membership mappings"""
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
			if not alliance_members[alliance_id].has(country_iso3):
				alliance_members[alliance_id].append(country_iso3)
		
		# Update alliances dictionary
		if alliances.has(alliance_id):
			if not alliances[alliance_id]["members"].has(country_iso3):
				alliances[alliance_id]["members"].append(country_iso3)
	
	print("Loaded country-alliance memberships")

func get_country_alliances(country_iso3: String) -> Array:
	"""Get list of alliances a country belongs to"""
	return country_alliances.get(country_iso3, [])

func get_alliance_members(alliance_id: String) -> Array:
	"""Get list of countries in an alliance"""
	return alliance_members.get(alliance_id, [])

func get_alliance_info(alliance_id: String) -> Dictionary:
	"""Get alliance details"""
	return alliances.get(alliance_id, {})

func get_alliance_color(alliance_id: String) -> Color:
	"""Get alliance color"""
	if alliances.has(alliance_id):
		return alliances[alliance_id]["color"]
	return Color.WHITE

func get_country_primary_alliance(country_iso3: String) -> String:
	"""Get the first (primary) alliance of a country"""
	var alliances_list = get_country_alliances(country_iso3)
	if alliances_list.size() > 0:
		return alliances_list[0]
	return ""

func print_alliances_info():
	"""Debug: Print all alliances and their members"""
	for alliance_id in alliances:
		var alliance = alliances[alliance_id]
		var members = alliance_members.get(alliance_id, [])
		print("Alliance: ", alliance_id, " (", alliance["name"], ")")
		print("  Members: ", members)
		print("  Color: ", alliance["color"])
