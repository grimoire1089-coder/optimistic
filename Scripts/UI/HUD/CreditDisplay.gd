extends Label

@export var prefix: String = "CR "
@export var use_separator: bool = true
@export var zero_pad_digits: int = 0
@export var panel_bg_color: Color = Color(0.01, 0.025, 0.04, 0.88)
@export var panel_border_color: Color = Color(0.33, 0.85, 1.0, 0.95)
@export var panel_glow_color: Color = Color(0.12, 0.65, 1.0, 0.38)
@export var text_color: Color = Color(0.86, 0.97, 1.0, 1.0)
@export_range(0, 32, 1) var panel_corner_radius: int = 16
@export_range(0, 32, 1) var panel_glow_size: int = 14


func _ready() -> void:
	_apply_neon_style()
	CreditWallet.balance_changed.connect(_on_balance_changed)
	_refresh(CreditWallet.get_credits())


func _exit_tree() -> void:
	if CreditWallet.balance_changed.is_connected(_on_balance_changed):
		CreditWallet.balance_changed.disconnect(_on_balance_changed)


func _on_balance_changed(new_balance: int, _delta: int, _reason: String) -> void:
	_refresh(new_balance)


func _refresh(value: int) -> void:
	var value_text := _format_credit_value(value)
	text = "%s%s" % [prefix, value_text]


func _apply_neon_style() -> void:
	var panel_container := _find_parent_panel_container()
	if panel_container != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = panel_bg_color
		panel_style.border_color = panel_border_color
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(panel_corner_radius)
		panel_style.shadow_color = panel_glow_color
		panel_style.shadow_size = panel_glow_size
		panel_style.shadow_offset = Vector2.ZERO
		panel_style.set_content_margin_all(0.0)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_shadow_color", Color(panel_border_color.r, panel_border_color.g, panel_border_color.b, 0.55))
	add_theme_font_size_override("font_size", 16)
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 0)
	add_theme_constant_override("shadow_outline_size", 1)


func _find_parent_panel_container() -> PanelContainer:
	var current_node := get_parent()
	while current_node != null:
		if current_node is PanelContainer:
			return current_node
		current_node = current_node.get_parent()
	return null


func _format_credit_value(value: int) -> String:
	var result := str(max(value, 0))

	if zero_pad_digits > 0:
		result = result.pad_zeros(zero_pad_digits)

	if use_separator:
		result = _add_thousands_separator(result)

	return result


func _add_thousands_separator(source: String) -> String:
	var result := ""
	var count := 0

	for i in range(source.length() - 1, -1, -1):
		result = source[i] + result
		count += 1

		if count % 3 == 0 and i != 0:
			result = "," + result

	return result
