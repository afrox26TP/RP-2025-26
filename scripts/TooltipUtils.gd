# ==================================================================================================
#  __  __    _    ____  _____   ______   __     _    _____ ____   _____  __
# |  \/  |  / \  |  _ \| ____| | __ ) \ / /    / \  |  ___|  _ \ / _ \ \/ /
# | |\/| | / _ \ | | | |  _|   |  _ \\ V /    / _ \ | |_  | |_) | | | |\  /
# | |  | |/ ___ \| |_| | |___  | |_) || |    / ___ \|  _| |  _ <| |_| /  \
# |_|  |_/_/   \_\____/|_____| |____/ |_|   /_/   \_\_|   |_| \_\\___/_/\_\
# ==================================================================================================

class_name TooltipUtils
extends RefCounted
# this script drives a specific gameplay/UI area and keeps related logic together.

# Builds UI objects and default wiring.
static func create_help_button(tooltip_text: String) -> Button:
	var button := Button.new()
	button.text = "?"
	button.tooltip_text = tooltip_text
	button.custom_minimum_size = Vector2(28, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.19, 0.31, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.45, 0.60, 0.82, 0.85)
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.25, 0.42, 0.98)
	hover.border_color = Color(0.60, 0.78, 0.98, 0.95)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button

# Applies visual/UI updates.
static func show_help_dropdown(owner: Node, anchor: Control, text: String) -> void:
	if owner == null or anchor == null:
		return
	var clean_text := text.strip_edges()
	if clean_text == "":
		return

	var popup := owner.get_node_or_null("__HelpDropdown") as PopupPanel
	var text_label: Label = null
	if popup == null:
		popup = PopupPanel.new()
		popup.name = "__HelpDropdown"
		popup.popup_window = false
		popup.focus_exited.connect(func(): popup.hide())
		popup.mouse_exited.connect(func(): popup.hide())
		owner.add_child(popup)

		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.07, 0.10, 0.18, 0.98)
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 1
		panel_style.border_color = Color(0.45, 0.60, 0.82, 0.88)
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		popup.add_theme_stylebox_override("panel", panel_style)

		var margin := MarginContainer.new()
		margin.name = "MarginContainer"
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		popup.add_child(margin)

		text_label = Label.new()
		text_label.name = "HelpText"
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size = Vector2(316, 0)
		text_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
		margin.add_child(text_label)
	else:
		text_label = popup.get_node_or_null("MarginContainer/HelpText") as Label

	if text_label == null:
		return

	text_label.text = clean_text
	
	var viewport_size: Vector2 = anchor.get_viewport().get_visible_rect().size
	var anchor_global: Vector2 = anchor.get_global_position()
	
	var text_height: float = text_label.get_combined_minimum_size().y
	var popup_height: int = clampi(int(text_height + 40), 60, 300)
	var popup_size: Vector2i = Vector2i(340, popup_height)
	popup.min_size = popup_size
	popup.size = popup_size
	
	var pos: Vector2 = anchor_global + Vector2(0.0, anchor.size.y + 8.0)
	pos.x = clampf(pos.x, 8.0, viewport_size.x - 340.0 - 8.0)
	
	if pos.y + float(popup_size.y) > viewport_size.y - 8.0:
		pos.y = anchor_global.y - float(popup_size.y) - 8.0
		pos.y = maxf(pos.y, 8.0)
	
	popup.position = pos
	popup.popup()

# Applies prepared settings/effects to runtime systems.
static func apply_default_tooltips(root: Node) -> void:
	if root == null:
		return
	_apply_recursive(root)

# Applies prepared settings/effects to runtime systems.
static func _apply_recursive(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if control.tooltip_text.strip_edges() == "":
			var generated := _guess_tooltip(control)
			if generated != "":
				control.tooltip_text = generated

		# Some controls (especially Label) may default to IGNORE, which prevents tooltip hover detection.
		if control.tooltip_text.strip_edges() != "" and control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS

	for child in node.get_children():
		_apply_recursive(child)

# Main runtime logic lives here.
static func _guess_tooltip(control: Control) -> String:
	if control is Button:
		var button_text := (control as Button).text.strip_edges()
		if button_text != "":
			return button_text

	if control is MenuButton:
		var menu_text := (control as MenuButton).text.strip_edges()
		if menu_text != "":
			return menu_text

	if control is OptionButton:
		return "Select option"

	if control is LineEdit:
		var placeholder := (control as LineEdit).placeholder_text.strip_edges()
		if placeholder != "":
			return placeholder
		return "Enter value"

	if control is RichTextLabel:
		var rt_text := (control as RichTextLabel).text.strip_edges()
		if rt_text != "":
			return rt_text.substr(0, min(80, rt_text.length()))

	if control is Label:
		var label_text := (control as Label).text.strip_edges()
		if label_text != "" and label_text.length() <= 80:
			return label_text

	if control is TextureRect:
		if control.name.to_lower().find("flag") != -1:
			return "Country flag"
		return "Graphic element"

	var fallback := control.name.replace("_", " ").strip_edges()
	if fallback != "":
		return fallback

	return ""


