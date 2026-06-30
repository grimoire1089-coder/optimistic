extends PanelContainer
class_name CharacterMoodPanel

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _needs: CharacterNeeds

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
	if _rows == null:
		return
	if _needs == null:
		_add_message_row("気分データなし")
		return

	var mood_count := 0
	for need in _needs.needs:
		if need == null or need.definition == null:
			continue
		if need.is_critical():
			_add_mood_row("危険", _get_mood_text(need, true))
			mood_count += 1
		elif need.is_low():
			_add_mood_row("低下", _get_mood_text(need, false))
			mood_count += 1

	if mood_count <= 0:
		_add_message_row("落ち着いています")

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()

func _add_message_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)

func _add_mood_row(state_text: String, mood_text: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(row)

	var state_label := Label.new()
	state_label.text = state_text
	state_label.custom_minimum_size = Vector2(44.0, 0.0)
	row.add_child(state_label)

	var mood_label := Label.new()
	mood_label.text = mood_text
	mood_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mood_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mood_label)

func _get_mood_text(need: NeedInstance, critical: bool) -> String:
	if need == null or need.definition == null:
		return ""
	var mood_id := need.definition.critical_mood_id if critical else need.definition.low_mood_id
	if mood_id != &"":
		return String(mood_id)
	if critical:
		return "%s がかなり不足しています" % need.definition.display_name
	return "%s が不足気味です" % need.definition.display_name

func _on_need_changed(_need_id: StringName, _old_value: float, _new_value: float) -> void:
	_rebuild()
