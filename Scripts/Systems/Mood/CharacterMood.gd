extends Resource
class_name CharacterMood

signal mood_changed(old_value: int, new_value: int)
signal entries_changed()

@export var min_value: int = 0
@export var max_value: int = 100
@export var base_value: int = 50
@export var entries: Array[CharacterMoodEntryInstance] = []

func get_mood_value() -> int:
	return clampi(base_value + get_total_points(), min_value, max_value)

func get_total_points() -> int:
	var total := 0
	for entry in entries:
		if entry == null:
			continue
		total += entry.get_point()
	return total

func add_entry(data: CharacterMoodEntryData, game_clock: Node = null) -> void:
	if data == null:
		return
	if data.entry_id == &"":
		return
	var old_value := get_mood_value()
	forget_entry(data.entry_id, false)
	var entry := CharacterMoodEntryInstance.new()
	entry.setup(data, game_clock)
	entries.append(entry)
	entries_changed.emit()
	_emit_mood_changed_if_needed(old_value)

func forget_entry(entry_id: StringName, emit_signals: bool = true) -> void:
	if entry_id == &"":
		return
	var old_value := get_mood_value()
	for i in range(entries.size() - 1, -1, -1):
		var entry := entries[i]
		if entry == null or entry.get_entry_id() == entry_id:
			entries.remove_at(i)
	if emit_signals:
		entries_changed.emit()
		_emit_mood_changed_if_needed(old_value)

func has_entry(entry_id: StringName) -> bool:
	for entry in entries:
		if entry != null and entry.get_entry_id() == entry_id:
			return true
	return false

func update_for_season(season_id: String, season_year: int) -> void:
	var old_value := get_mood_value()
	var entries_were_removed := false
	for i in range(entries.size() - 1, -1, -1):
		var entry := entries[i]
		if entry == null or entry.should_end_on_season_changed(season_id, season_year):
			entries.remove_at(i)
			entries_were_removed = true
	if entries_were_removed:
		entries_changed.emit()
		_emit_mood_changed_if_needed(old_value)

func update_for_absolute_minute(current_absolute_minute: int) -> void:
	var old_value := get_mood_value()
	var entries_were_removed := false
	for i in range(entries.size() - 1, -1, -1):
		var entry := entries[i]
		if entry == null or entry.should_end_at_absolute_minute(current_absolute_minute):
			entries.remove_at(i)
			entries_were_removed = true
	if entries_were_removed:
		entries_changed.emit()
		_emit_mood_changed_if_needed(old_value)

func _emit_mood_changed_if_needed(old_value: int) -> void:
	var new_value := get_mood_value()
	if old_value == new_value:
		return
	mood_changed.emit(old_value, new_value)
