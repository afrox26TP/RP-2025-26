extends Control

## Reusable line chart used by the statistics dashboard.

signal chart_point_selected(info: Dictionary)
signal chart_point_hovered(info: Dictionary)

var series: Array = []
var turn_values: Array = []
var y_tick_count: int = 4
var value_suffix: String = ""
var value_decimals: int = 2
var title: String = ""
var _hover_info: Dictionary = {}


func _ready() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		custom_minimum_size = Vector2(780, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.08, 0.12, 0.75), true)
	draw_rect(rect, Color(0.35, 0.47, 0.62, 0.9), false, 1.0)

	var plot_data = _build_plot_data()
	var valid_series = plot_data.get("valid_series", []) as Array
	if valid_series.is_empty():
		return
	var plot = plot_data.get("plot_rect", Rect2()) as Rect2

	for i in range(y_tick_count + 1):
		var ratio = float(i) / float(max(1, y_tick_count))
		var y = lerpf(plot.position.y + plot.size.y, plot.position.y, ratio)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), Color(0.22, 0.30, 0.40, 0.55), 1.0)

	draw_line(Vector2(plot.position.x, plot.position.y), Vector2(plot.position.x, plot.position.y + plot.size.y), Color(0.55, 0.65, 0.78, 0.8), 1.0)
	draw_line(Vector2(plot.position.x, plot.position.y + plot.size.y), Vector2(plot.position.x + plot.size.x, plot.position.y + plot.size.y), Color(0.55, 0.65, 0.78, 0.8), 1.0)

	for series_value in valid_series:
		var data = series_value as Dictionary
		var color = data.get("color", Color(0.95, 0.95, 0.95, 1.0)) as Color
		var points = data.get("points", PackedVector2Array()) as PackedVector2Array
		if points.size() >= 2:
			draw_polyline(points, color, 2.0, true)
			draw_circle(points[points.size() - 1], 3.0, color)

	if _hover_info.is_empty():
		return
	var hover_point = _hover_info.get("point", Vector2(-1000, -1000)) as Vector2
	if hover_point.x <= -999.0:
		return
	draw_line(Vector2(hover_point.x, plot.position.y), Vector2(hover_point.x, plot.position.y + plot.size.y), Color(1, 1, 1, 0.25), 1.0)
	draw_line(Vector2(plot.position.x, hover_point.y), Vector2(plot.position.x + plot.size.x, hover_point.y), Color(1, 1, 1, 0.15), 1.0)
	draw_circle(hover_point, 4.0, Color(1, 1, 1, 0.95))
	_draw_hover_tooltip(hover_point)


func _draw_hover_tooltip(hover_point: Vector2) -> void:
	var text = str(_hover_info.get("text", ""))
	if text == "":
		return
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	if font == null:
		return
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var padding = Vector2(8, 5)
	var box_position = hover_point + Vector2(10, -text_size.y - 14)
	box_position.x = clampf(box_position.x, 4.0, maxf(4.0, size.x - text_size.x - padding.x * 2.0 - 4.0))
	box_position.y = clampf(box_position.y, 4.0, maxf(4.0, size.y - text_size.y - padding.y * 2.0 - 4.0))
	var box = Rect2(box_position, text_size + padding * 2.0)
	draw_rect(box, Color(0.04, 0.06, 0.10, 0.95), true)
	draw_rect(box, Color(0.58, 0.70, 0.86, 0.95), false, 1.0)
	draw_string(font, box.position + Vector2(padding.x, padding.y + text_size.y - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.98, 1.0, 1.0))


func _gui_input(event: InputEvent) -> void:
	if series.is_empty():
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		var mouse_button = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_update_hover(mouse_button.position)
			if not _hover_info.is_empty():
				chart_point_selected.emit(_hover_info.duplicate(true))


func _exit_tree() -> void:
	_hover_info.clear()


func _build_plot_data() -> Dictionary:
	var valid_series: Array = []
	for series_value in series:
		var source = series_value as Dictionary
		var values = source.get("values", []) as Array
		if values.size() >= 2:
			valid_series.append({
				"name": str(source.get("name", "series")),
				"color": source.get("color", Color(0.95, 0.95, 0.95, 1.0)),
				"values": values
			})

	if valid_series.is_empty():
		return {"valid_series": []}

	var left_padding = 44.0
	var right_padding = 12.0
	var top_padding = 12.0
	var bottom_padding = 26.0
	var plot = Rect2(
		Vector2(left_padding, top_padding),
		Vector2(max(1.0, size.x - left_padding - right_padding), max(1.0, size.y - top_padding - bottom_padding))
	)
	var value_range = _find_value_range(valid_series)
	if value_range.is_empty():
		return {"valid_series": []}
	var minimum = float(value_range["minimum"])
	var maximum = float(value_range["maximum"])

	for series_index in range(valid_series.size()):
		var data = valid_series[series_index] as Dictionary
		var values = data.get("values", []) as Array
		var points: PackedVector2Array = []
		for value_index in range(values.size()):
			var x_ratio = float(value_index) / float(max(1, values.size() - 1))
			var x = plot.position.x + plot.size.x * x_ratio
			var value = float(values[value_index])
			var y_ratio = (value - minimum) / (maximum - minimum)
			var y = plot.position.y + plot.size.y - plot.size.y * y_ratio
			points.append(Vector2(x, y))
		data["points"] = points
		valid_series[series_index] = data

	return {
		"valid_series": valid_series,
		"plot_rect": plot,
		"min": minimum,
		"max": maximum
	}


func _find_value_range(valid_series: Array) -> Dictionary:
	var minimum = INF
	var maximum = -INF
	for series_value in valid_series:
		var values = (series_value as Dictionary).get("values", []) as Array
		for raw_value in values:
			var value = float(raw_value)
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
	if not is_finite(minimum) or not is_finite(maximum):
		return {}
	if absf(maximum - minimum) <= 0.000001:
		var padding = maxf(1.0, absf(maximum) * 0.08)
		minimum -= padding
		maximum += padding
	return {"minimum": minimum, "maximum": maximum}


func _format_value(value: float) -> String:
	return "%.*f%s" % [max(0, value_decimals), value, value_suffix]


func _update_hover(local_position: Vector2) -> void:
	var plot_data = _build_plot_data()
	var valid_series = plot_data.get("valid_series", []) as Array
	if valid_series.is_empty():
		_clear_hover()
		return
	var plot = plot_data.get("plot_rect", Rect2()) as Rect2
	if not plot.has_point(local_position):
		_clear_hover()
		return

	var best_distance = INF
	var best: Dictionary = {}
	for series_value in valid_series:
		var data = series_value as Dictionary
		var values = data.get("values", []) as Array
		var points = data.get("points", PackedVector2Array()) as PackedVector2Array
		for index in range(points.size()):
			var point = points[index]
			var distance = point.distance_to(local_position)
			if distance < best_distance:
				best_distance = distance
				var turn = int(turn_values[index]) if index < turn_values.size() else index + 1
				best = {
					"series": str(data.get("name", "series")),
					"series_index": index,
					"turn": turn,
					"value": float(values[index]),
					"point": point,
					"color": data.get("color", Color.WHITE)
				}
	if best.is_empty():
		return
	best["text"] = "%s | T%d | %s" % [
		str(best.get("series", "series")),
		int(best.get("turn", 0)),
		_format_value(float(best.get("value", 0.0)))
	]
	_hover_info = best
	chart_point_hovered.emit(best.duplicate(true))
	queue_redraw()


func _clear_hover() -> void:
	if _hover_info.is_empty():
		return
	_hover_info.clear()
	chart_point_hovered.emit({})
	queue_redraw()
