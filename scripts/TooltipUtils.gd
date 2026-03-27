class_name TooltipUtils
extends RefCounted

static func apply_default_tooltips(root: Node) -> void:
	if root == null:
		return
	_apply_recursive(root)

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
		return "Vyber moznost"

	if control is LineEdit:
		var placeholder := (control as LineEdit).placeholder_text.strip_edges()
		if placeholder != "":
			return placeholder
		return "Zadej hodnotu"

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
			return "Vlajka statu"
		return "Graficky prvek"

	var fallback := control.name.replace("_", " ").strip_edges()
	if fallback != "":
		return fallback

	return ""
