extends RefCounted
class_name CityResidentsPagePresenter

const CARD_MIN_SIZE := Vector2(0.0, 124.0)
const PORTRAIT_SIZE := Vector2(96.0, 96.0)


static func rebuild(list_container: VBoxContainer, residents: Array[NpcResidentData]) -> void:
	if list_container == null:
		return
	_clear_children(list_container)
	if residents.is_empty():
		list_container.add_child(_create_empty_label())
		return
	for resident in residents:
		if resident == null:
			continue
		list_container.add_child(_create_resident_card(resident))


static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


static func _create_empty_label() -> Label:
	var label := Label.new()
	label.text = "登録された住人はいません。"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	return label


static func _create_resident_card(resident: NpcResidentData) -> PanelContainer:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = CARD_MIN_SIZE
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = resident.load_portrait()
	row.add_child(portrait)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 4)
	row.add_child(info_column)

	var name_label := _create_label(resident.display_name, 20)
	info_column.add_child(name_label)

	var status_label := _create_label(_make_status_text(resident), 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(status_label)

	var memo_label := _create_label(resident.status_text, 12)
	memo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(memo_label)

	return card_panel


static func _make_status_text(resident: NpcResidentData) -> String:
	var parts: Array[String] = []
	if not resident.location_text.is_empty():
		parts.append("場所: %s" % resident.location_text)
	if not resident.mood_text.is_empty():
		parts.append("様子: %s" % resident.mood_text)
	if not resident.relationship_text.is_empty():
		parts.append("関係: %s" % resident.relationship_text)
	return "　".join(parts)


static func _create_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


static func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 1.0)
	style.border_color = Color(0.14, 0.8, 0.95, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
