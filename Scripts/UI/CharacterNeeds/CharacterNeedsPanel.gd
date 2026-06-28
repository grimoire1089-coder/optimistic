extends PanelContainer
class_name CharacterNeedsPanel

@export var bar_width: float = 180.0

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _needs: CharacterNeeds
var _row_by_need_id: Dictionary = {}

func _ready() -> void:
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
	_clear_rows()
	_row_by_need_id.clear()
	if _needs == null:
		return
	for need in _needs.needs:
		if need == null or need.definition == null:
			continue
		_create_row(need)

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()

func _create_row(need: NeedInstance) -> void:
	var row := HBoxContainer.new()
	row.name = String(need.definition.need_id)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(row)

	var name_label := Label.new()
	name_label.text = need.definition.display_name
	name_label.custom_minimum_size = Vector2(72.0, 0.0)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = need.definition.max_value
	bar.value = need.value
	bar.custom_minimum_size = Vector2(bar_width, 18.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(36.0, 0.0)
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
	value_label.text = str(roundi(need.value))

func _on_need_changed(need_id: StringName, _old_value: float, _new_value: float) -> void:
	_update_row(need_id)
