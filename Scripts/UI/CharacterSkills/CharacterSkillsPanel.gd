extends PanelContainer
class_name CharacterSkillsPanel

@export var level_bar_width: float = 132.0
@export var level_bar_color: Color = Color(0.20, 0.72, 1.0, 1.0)
@export var experience_bar_color: Color = Color(0.70, 0.35, 1.0, 1.0)
@export var skill_detail_popup_size: Vector2i = Vector2i(460, 420)

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _skills_module: AICharacterSkillsModule
var _skill_detail_popup: PopupPanel
var _skill_detail_rows: VBoxContainer
var _open_skill_id: StringName = &""


func _ready() -> void:
	if _skills_module != null:
		_rebuild()


func set_skills_module(skills_module: AICharacterSkillsModule) -> void:
	_disconnect_skills_module()
	_skills_module = skills_module
	_connect_skills_module()
	if is_node_ready():
		_rebuild()


func refresh() -> void:
	if is_node_ready():
		_rebuild()


func _connect_skills_module() -> void:
	if _skills_module == null:
		return
	var changed_callable := Callable(self, "_on_skill_changed")
	if not _skills_module.skill_changed.is_connected(changed_callable):
		_skills_module.skill_changed.connect(changed_callable)
	var exp_callable := Callable(self, "_on_skill_experience_changed")
	if not _skills_module.skill_experience_changed.is_connected(exp_callable):
		_skills_module.skill_experience_changed.connect(exp_callable)
	var points_callable := Callable(self, "_on_skill_points_changed")
	if not _skills_module.skill_points_changed.is_connected(points_callable):
		_skills_module.skill_points_changed.connect(points_callable)
	var upgrade_callable := Callable(self, "_on_skill_upgrade_changed")
	if not _skills_module.skill_upgrade_changed.is_connected(upgrade_callable):
		_skills_module.skill_upgrade_changed.connect(upgrade_callable)


func _disconnect_skills_module() -> void:
	if _skills_module == null:
		return
	var changed_callable := Callable(self, "_on_skill_changed")
	if _skills_module.skill_changed.is_connected(changed_callable):
		_skills_module.skill_changed.disconnect(changed_callable)
	var exp_callable := Callable(self, "_on_skill_experience_changed")
	if _skills_module.skill_experience_changed.is_connected(exp_callable):
		_skills_module.skill_experience_changed.disconnect(exp_callable)
	var points_callable := Callable(self, "_on_skill_points_changed")
	if _skills_module.skill_points_changed.is_connected(points_callable):
		_skills_module.skill_points_changed.disconnect(points_callable)
	var upgrade_callable := Callable(self, "_on_skill_upgrade_changed")
	if _skills_module.skill_upgrade_changed.is_connected(upgrade_callable):
		_skills_module.skill_upgrade_changed.disconnect(upgrade_callable)


func _rebuild() -> void:
	_clear_rows()
	if _rows == null or _skills_module == null:
		return
	for row_data in _skills_module.get_skill_rows():
		_create_skill_row(row_data)
	if _is_skill_detail_popup_open():
		_populate_skill_detail_popup(_open_skill_id)
		_clamp_skill_detail_popup_size()


func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _create_skill_row(row_data: Dictionary) -> void:
	var skill_id := StringName(row_data.get("id", &""))
	var display_name := str(row_data.get("display_name", String(skill_id)))
	var level := int(row_data.get("level", 0))
	var max_level := int(row_data.get("max_level", 0))
	var experience := int(row_data.get("experience", 0))
	var next_exp := int(row_data.get("next_level_experience", 0))
	var skill_points := int(row_data.get("skill_points", 0))
	var spent_skill_points := int(row_data.get("spent_skill_points", 0))
	var bonus_multiplier := float(row_data.get("experience_bonus_multiplier", 0.0))
	var bonus_until_level := int(row_data.get("experience_bonus_until_level", 0))

	var row := VBoxContainer.new()
	row.name = String(skill_id)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	_rows.add_child(row)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.custom_minimum_size = Vector2(58.0, 0.0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	header.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "Lv %d / %d" % [level, max_level]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size = Vector2(88.0, 0.0)
	level_label.add_theme_font_size_override("font_size", 13)
	header.add_child(level_label)

	var detail_button := Button.new()
	detail_button.text = "詳細"
	detail_button.custom_minimum_size = Vector2(54.0, 26.0)
	detail_button.pressed.connect(_on_skill_detail_button_pressed.bind(skill_id))
	header.add_child(detail_button)

	var level_bar := ProgressBar.new()
	level_bar.show_percentage = false
	level_bar.min_value = 0.0
	level_bar.max_value = maxf(float(max_level), 1.0)
	level_bar.value = clampf(float(level), 0.0, float(max_level))
	level_bar.custom_minimum_size = Vector2(level_bar_width, 14.0)
	level_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_bar_color(level_bar, level_bar_color)
	row.add_child(level_bar)

	var point_label := Label.new()
	point_label.text = "SP %d" % skill_points
	if spent_skill_points > 0:
		point_label.text += " / 使用済み %d" % spent_skill_points
	point_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45, 0.95))
	point_label.add_theme_font_size_override("font_size", 12)
	row.add_child(point_label)

	var exp_label := Label.new()
	exp_label.text = "EXP 完了" if next_exp <= 0 else "EXP %d / %d" % [experience, next_exp]
	if bonus_multiplier > 0.0 and bonus_until_level > 0:
		exp_label.text += "  +%d%% Lv%dまで" % [roundi(bonus_multiplier * 100.0), bonus_until_level]
	exp_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.92))
	exp_label.add_theme_font_size_override("font_size", 12)
	row.add_child(exp_label)

	var exp_bar := ProgressBar.new()
	exp_bar.show_percentage = false
	exp_bar.min_value = 0.0
	exp_bar.max_value = maxf(float(next_exp), 1.0)
	exp_bar.value = 1.0 if next_exp <= 0 else clampf(float(experience), 0.0, float(next_exp))
	exp_bar.custom_minimum_size = Vector2(level_bar_width, 10.0)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_bar_color(exp_bar, experience_bar_color)
	row.add_child(exp_bar)


func _on_skill_detail_button_pressed(skill_id: StringName) -> void:
	_open_skill_id = skill_id
	var popup := _ensure_skill_detail_popup()
	if popup == null:
		return
	_populate_skill_detail_popup(skill_id)
	popup.popup_centered(skill_detail_popup_size)
	call_deferred("_clamp_skill_detail_popup_size")


func _ensure_skill_detail_popup() -> PopupPanel:
	if _skill_detail_popup != null and is_instance_valid(_skill_detail_popup):
		return _skill_detail_popup
	_skill_detail_popup = PopupPanel.new()
	_skill_detail_popup.name = "SkillDetailPopup"
	_skill_detail_popup.exclusive = true
	add_child(_skill_detail_popup)
	_apply_popup_style(_skill_detail_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_skill_detail_popup.add_child(margin)

	_skill_detail_rows = VBoxContainer.new()
	_skill_detail_rows.name = "Rows"
	_skill_detail_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_detail_rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_skill_detail_rows.add_theme_constant_override("separation", 8)
	margin.add_child(_skill_detail_rows)
	return _skill_detail_popup


func _populate_skill_detail_popup(skill_id: StringName) -> void:
	if _skills_module == null:
		return
	var popup := _ensure_skill_detail_popup()
	if popup == null or _skill_detail_rows == null:
		return
	_clear_skill_detail_popup_rows()

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_detail_rows.add_child(header)

	var title_label := Label.new()
	title_label.text = "%sの取得スキル" % _skills_module.get_skill_display_name(skill_id)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 16)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "閉じる"
	close_button.custom_minimum_size = Vector2(72.0, 30.0)
	close_button.pressed.connect(_on_skill_detail_close_pressed)
	header.add_child(close_button)

	var point_label := Label.new()
	point_label.text = "使用可能SP %d / 使用済み %d" % [
		_skills_module.get_skill_points(skill_id),
		_skills_module.get_spent_skill_points(skill_id),
	]
	point_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45, 0.95))
	point_label.add_theme_font_size_override("font_size", 12)
	_skill_detail_rows.add_child(point_label)

	_create_skill_upgrade_list(_skill_detail_rows, skill_id)
	_clamp_skill_detail_popup_size()


func _clear_skill_detail_popup_rows() -> void:
	if _skill_detail_rows == null:
		return
	for child in _skill_detail_rows.get_children():
		_skill_detail_rows.remove_child(child)
		child.queue_free()


func _create_skill_upgrade_list(parent: VBoxContainer, skill_id: StringName) -> void:
	if parent == null or _skills_module == null:
		return
	if not _skills_module.has_method("get_skill_upgrade_rows"):
		return
	var upgrade_rows: Array = _skills_module.call("get_skill_upgrade_rows", skill_id)
	if upgrade_rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "このスキルで取得できる項目はまだありません。"
		empty_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 0.92))
		empty_label.add_theme_font_size_override("font_size", 12)
		parent.add_child(empty_label)
		return

	for upgrade_data in upgrade_rows:
		if upgrade_data is Dictionary:
			_create_skill_upgrade_card(parent, upgrade_data)


func _create_skill_upgrade_card(parent: VBoxContainer, upgrade_data: Dictionary) -> void:
	var upgrade_id := StringName(upgrade_data.get("id", &""))
	var display_name := str(upgrade_data.get("display_name", String(upgrade_id)))
	var description := str(upgrade_data.get("description", ""))
	var level := int(upgrade_data.get("level", 0))
	var max_level := int(upgrade_data.get("max_level", 0))
	var cost := int(upgrade_data.get("cost", 0))
	var can_acquire := bool(upgrade_data.get("can_acquire", false))
	var is_max_level := bool(upgrade_data.get("is_max_level", false))

	var card := PanelContainer.new()
	card.name = "%sCard" % String(upgrade_id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_style(card)
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(header)

	var name_label := Label.new()
	name_label.text = "%s  Lv %d / %d" % [display_name, level, max_level]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	header.add_child(name_label)

	var acquire_button := Button.new()
	acquire_button.custom_minimum_size = Vector2(72.0, 28.0)
	acquire_button.text = "MAX" if is_max_level else "取得 %dSP" % cost
	acquire_button.disabled = not can_acquire
	acquire_button.pressed.connect(_on_acquire_skill_upgrade_pressed.bind(upgrade_id))
	header.add_child(acquire_button)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 0.92))
	desc_label.add_theme_font_size_override("font_size", 11)
	box.add_child(desc_label)


func _apply_bar_color(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)


func _apply_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.075, 0.095, 0.92)
	panel_style.border_color = Color(0.20, 0.55, 0.78, 0.55)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", panel_style)


func _apply_popup_style(popup: PopupPanel) -> void:
	if popup == null:
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.048, 0.98)
	panel_style.border_color = Color(0.15, 0.78, 1.0, 0.86)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", panel_style)


func _clamp_skill_detail_popup_size() -> void:
	if _skill_detail_popup == null or not is_instance_valid(_skill_detail_popup):
		return
	if not _skill_detail_popup.visible:
		return
	var fixed_size := Vector2(skill_detail_popup_size)
	_skill_detail_popup.size = fixed_size


func _is_skill_detail_popup_open() -> bool:
	return _skill_detail_popup != null and is_instance_valid(_skill_detail_popup) and _skill_detail_popup.visible and _open_skill_id != &""


func _on_acquire_skill_upgrade_pressed(upgrade_id: StringName) -> void:
	if _skills_module == null or not _skills_module.has_method("acquire_skill_upgrade"):
		return
	_skills_module.call("acquire_skill_upgrade", upgrade_id)
	refresh()


func _on_skill_detail_close_pressed() -> void:
	if _skill_detail_popup != null and is_instance_valid(_skill_detail_popup):
		_skill_detail_popup.hide()


func _on_skill_changed(_skill_id: StringName, _old_level: int, _new_level: int) -> void:
	refresh()


func _on_skill_experience_changed(_skill_id: StringName, _new_experience: int) -> void:
	refresh()


func _on_skill_points_changed(_skill_id: StringName, _available_points: int, _spent_points: int) -> void:
	refresh()


func _on_skill_upgrade_changed(_upgrade_id: StringName, _skill_id: StringName, _old_level: int, _new_level: int) -> void:
	refresh()
