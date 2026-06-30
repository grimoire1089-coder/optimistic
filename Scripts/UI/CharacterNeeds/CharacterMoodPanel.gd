extends PanelContainer
class_name CharacterMoodPanel

@onready var _rows: VBoxContainer = $MarginContainer/Rows

var _mood_module: CharacterMoodModule

func _ready() -> void:
	if _mood_module != null:
		_rebuild()

func set_mood_module(module: CharacterMoodModule) -> void:
	_disconnect_mood_module()
	_mood_module = module
	_connect_mood_module()
	if is_node_ready():
		_rebuild()

func set_character_needs(_needs: CharacterNeeds) -> void:
	set_mood_module(null)

func set_needs_module(_module: CharacterNeedsModule) -> void:
	set_mood_module(null)

func refresh() -> void:
	if is_node_ready():
		_rebuild()

func _connect_mood_module() -> void:
	if _mood_module == null:
		return
	var mood_callable := Callable(self, "_on_mood_changed")
	if not _mood_module.mood_changed.is_connected(mood_callable):
		_mood_module.mood_changed.connect(mood_callable)
	var entries_callable := Callable(self, "_on_entries_changed")
	if not _mood_module.entries_changed.is_connected(entries_callable):
		_mood_module.entries_changed.connect(entries_callable)

func _disconnect_mood_module() -> void:
	if _mood_module == null:
		return
	var mood_callable := Callable(self, "_on_mood_changed")
	if _mood_module.mood_changed.is_connected(mood_callable):
		_mood_module.mood_changed.disconnect(mood_callable)
	var entries_callable := Callable(self, "_on_entries_changed")
	if _mood_module.entries_changed.is_connected(entries_callable):
		_mood_module.entries_changed.disconnect(entries_callable)

func _rebuild() -> void:
	_clear_rows()
	if _rows == null:
		return
	if _mood_module == null:
		_add_message_row("No mood data")
		return

	_add_summary_row()
	var entries := _mood_module.get_entries()
	if entries.is_empty():
		_add_message_row("No mood entries")
		return

	for entry in entries:
		if entry == null:
			continue
		_add_entry_row(entry)

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()

func _add_summary_row() -> void:
	var value := _mood_module.get_mood_value()
	var total := _mood_module.get_total_points()
	var label := Label.new()
	label.text = "Mood: %d / 100   Total: %s" % [value, _get_signed_point_text(total)]
	_rows.add_child(label)

func _add_message_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)

func _add_entry_row(entry: CharacterMoodEntryInstance) -> void:
	var row := VBoxContainer.new()
	_rows.add_child(row)
	var title := Label.new()
	title.text = "%s  %s" % [_get_signed_point_text(entry.get_point()), entry.get_display_name()]
	row.add_child(title)
	var info := Label.new()
	info.text = "Open this entry later."
	row.add_child(info)

func _get_signed_point_text(point: int) -> String:
	if point > 0:
		return "+%d" % point
	return str(point)

func _on_mood_changed(_old_value: int, _new_value: int) -> void:
	_rebuild()

func _on_entries_changed() -> void:
	_rebuild()
