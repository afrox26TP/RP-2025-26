extends RefCounted

## Shared helpers for semicolon-delimited project data.


static func path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


static func first_existing_path(candidates: Array) -> String:
	for candidate in candidates:
		var path = str(candidate)
		if path_exists(path):
			return path
	return str(candidates[candidates.size() - 1]) if not candidates.is_empty() else ""


static func build_column_index(header_line: String, delimiter: String = ";") -> Dictionary:
	var result: Dictionary = {}
	var columns = header_line.split(delimiter)
	for index in range(columns.size()):
		result[str(columns[index]).strip_edges().to_lower()] = index
	return result


static func find_column(column_index: Dictionary, names: Array, fallback_index: int = -1) -> int:
	for raw_name in names:
		var key = str(raw_name).strip_edges().to_lower()
		if column_index.has(key):
			return int(column_index[key])
	return fallback_index


static func read_int(parts: Array, index: int, default_value: int = 0) -> int:
	var raw = read_text(parts, index)
	return int(raw) if raw != "" else default_value


static func read_float(parts: Array, index: int, default_value: float = 0.0) -> float:
	var raw = read_text(parts, index)
	return float(raw) if raw != "" else default_value


static func read_text(parts: Array, index: int, default_value: String = "") -> String:
	if index < 0 or index >= parts.size():
		return default_value
	return str(parts[index]).strip_edges()
