extends PanelContainer
class_name CharacterNeedsPanel

@export var bar_width: float = 132.0
@export var bar_height: float = 26.0
@export var row_min_height: float = 38.0
@export var row_separation: int = 10
@export var need_name_width: float = 74.0
@export var need_value_width: float = 40.0
@export var need_font_size: int = 15
@export var high_value_color: Color = Color(0.20, 0.85, 0.28, 1.0)
@export var middle_value_color: Color = Color(0.95, 0.82, 0.18, 1.0)
@export var low_value_color: Color = Color(0.95, 0.22, 0.18, 1.0)
@export var bar_background_color: Color = Color(0.030, 0.045, 0.055, 1.0)
@export_range(0.0, 1.0, 0.01) var high_value_threshold: float = 0.66
@export_range(0.0, 1.0, 0.01) var middle_value_threshold: float = 0.33

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _needs: CharacterNeeds
var _row_by_need_id: Dictionary = {}

func _ready() -> void:
	_apply_rows_layout()
	if _needs != null:
		_rebuild()

func set_character_needs(needs: CharacterNeeds) -> void:
	_disconnect_needs()
	_needs = needs
	_connect_needs()
	if is_node_ready():
		_rebuild()

func set_needs_module(module: CharacterNeedsModule) -> void:
	if module == null:
		set_character_needs(null)
		return
	set_character_needs(module.get_character_needs())

func refresh() -> void:
	if is_node_ready():
		_rebuild()

func _connect_needs() -> void:
	if _needs == null:
		return
	var callable := Callable(self, "_on_need_changed")
	if not _needs.need_changed.is_connected(callable):
		_needs.need_changed.connect(callable)

func _disconnect_needs() -> void:
	if _needs == null:
		return
	var callable := Callable(self, "_on_need_changed")
	if _needs.need_changed.is_connected(callable):
		_needs.need_changed.disconnect(callable)

func _rebuild() -> void:
	_apply_rows_layout()
	_clear_rows()
	_row_by_need_id.clear()
	if _needs == null:
		return
	for need in _needs.needs:
		if need == null or need.definition == null:
			continue
		_create_row(need)

func _apply_rows_layout() -> void:
	if _rows == null:
		return
	_rows.add_theme_constant_override("separation", row_separation)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()

func _create_row(need: NeedInstance) -> void:
	var row := HBoxContainer.new()
	row.name = String(need.definition.need_id)
	row.custom_minimum_size = Vector2(0.0, row_min_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_child(row)

	var name_label := Label.new()
	name_label.text = need.definition.display_name
	name_label.custom_minimum_size = Vector2(need_name_width, row_min_height)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", need_font_size)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = need.definition.max_value
	bar.value = need.value
	bar.custom_minimum_size = Vector2(bar_width, bar_height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_bar_background(bar)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(need_value_width, row_min_height)
	value_label.add_theme_font_size_override("font_size", need_font_size)
	row.add_child(value_label)

	_row_by_need_id[need.definition.need_id] = {
		"bar": bar,
		"value_label": value_label,
	}
	_update_row(need.definition.need_id)

func _update_row(need_id: StringName) -> void:
	if _needs == null:
		return
	if not _row_by_need_id.has(need_id):
		return
	var need := _needs.get_need(need_id)
	if need == null:
		return
	var row_data: Dictionary = _row_by_need_id[need_id]
	var bar: ProgressBar = row_data["bar"]
	var value_label: Label = row_data["value_label"]
	bar.max_value = need.definition.max_value
	bar.value = need.value
	_apply_bar_color(bar, _get_need_ratio(need))
	value_label.text = str(roundi(need.value))

func _get_need_ratio(need: NeedInstance) -> float:
	if need == null or need.definition == null:
		return 0.0
	if need.definition.max_value <= 0.0:
		return 0.0
	return clampf(need.value / need.definition.max_value, 0.0, 1.0)

func _apply_bar_background(bar: ProgressBar) -> void:
	if bar == null:
		return
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = bar_background_color
	background_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", background_style)

func _apply_bar_color(bar: ProgressBar, ratio: float) -> void:
	if bar == null:
		return
	var fill_color := _get_bar_color(ratio)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill_style)

func _get_bar_color(ratio: float) -> Color:
	if ratio >= high_value_threshold:
		return high_value_color
	if ratio >= middle_value_threshold:
		return middle_value_color
	return low_value_color

func _on_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	_update_row(need_id)
