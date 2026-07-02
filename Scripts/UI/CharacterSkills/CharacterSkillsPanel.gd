extends PanelContainer
class_name CharacterSkillsPanel

@export var level_bar_width: float = 132.0
@export var level_bar_color: Color = Color(0.20, 0.72, 1.0, 1.0)
@export var experience_bar_color: Color = Color(0.70, 0.35, 1.0, 1.0)

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _skills_module: AICharacterSkillsModule


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


func _disconnect_skills_module() -> void:
	if _skills_module == null:
		return
	var changed_callable := Callable(self, "_on_skill_changed")
	if _skills_module.skill_changed.is_connected(changed_callable):
		_skills_module.skill_changed.disconnect(changed_callable)
	var exp_callable := Callable(self, "_on_skill_experience_changed")
	if _skills_module.skill_experience_changed.is_connected(exp_callable):
		_skills_module.skill_experience_changed.disconnect(exp_callable)


func _rebuild() -> void:
	_clear_rows()
	if _rows == null or _skills_module == null:
		return
	for row_data in _skills_module.get_skill_rows():
		_create_skill_row(row_data)


func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()


func _create_skill_row(row_data: Dictionary) -> void:
	var skill_id := StringName(row_data.get("id", &""))
	var display_name := str(row_data.get("display_name", String(skill_id)))
	var level := int(row_data.get("level", 0))
	var max_level := int(row_data.get("max_level", 0))
	var experience := int(row_data.get("experience", 0))
	var next_exp := int(row_data.get("next_level_experience", 0))

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

	var level_bar := ProgressBar.new()
	level_bar.show_percentage = false
	level_bar.min_value = 0.0
	level_bar.max_value = maxf(float(max_level), 1.0)
	level_bar.value = clampf(float(level), 0.0, float(max_level))
	level_bar.custom_minimum_size = Vector2(level_bar_width, 14.0)
	level_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_bar_color(level_bar, level_bar_color)
	row.add_child(level_bar)

	var exp_label := Label.new()
	exp_label.text = "EXP 完了" if next_exp <= 0 else "EXP %d / %d" % [experience, next_exp]
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


func _apply_bar_color(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)


func _on_skill_changed(_skill_id: StringName, _old_level: int, _new_level: int) -> void:
	refresh()


func _on_skill_experience_changed(_skill_id: StringName, _new_experience: int) -> void:
	refresh()
