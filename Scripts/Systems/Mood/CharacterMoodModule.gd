extends Node
class_name CharacterMoodModule

const MINUTES_PER_DAY := 24 * 60

signal mood_changed(old_value: int, new_value: int)
signal entries_changed()

@export var character_mood: CharacterMood
@export var load_default_entries_on_ready: bool = true
@export var default_entry_paths: Array[String] = [
	"res://Data/Mood/Entries/new_life.tres",
]
@export var game_clock_path: NodePath

var _game_clock: Node

func _ready() -> void:
	_ensure_character_mood()
	_connect_character_mood()
	_resolve_game_clock()
	_connect_game_clock()
	if load_default_entries_on_ready:
		_load_default_entries()

func get_character_mood() -> CharacterMood:
	_ensure_character_mood()
	return character_mood

func get_mood_value() -> int:
	_ensure_character_mood()
	return character_mood.get_mood_value()

func get_total_points() -> int:
	_ensure_character_mood()
	return character_mood.get_total_points()

func get_entries() -> Array[CharacterMoodEntryInstance]:
	_ensure_character_mood()
	return character_mood.entries

func add_entry(data: CharacterMoodEntryData) -> void:
	_ensure_character_mood()
	character_mood.add_entry(data, _get_game_clock())

func forget_entry(entry_id: StringName) -> void:
	_ensure_character_mood()
	character_mood.forget_entry(entry_id)

func has_entry(entry_id: StringName) -> bool:
	_ensure_character_mood()
	return character_mood.has_entry(entry_id)

func refresh_season_limited_entries() -> void:
	var clock := _get_game_clock()
	if clock == null:
		return
	if not clock.has_method("get_season_id"):
		return
	if not clock.has_method("get_season_year"):
		return
	character_mood.update_for_season(String(clock.call("get_season_id")), int(clock.call("get_season_year")))

func refresh_timed_entries() -> void:
	var clock := _get_game_clock()
	if clock == null:
		return
	character_mood.update_for_absolute_minute(_get_absolute_minute(clock))

func _ensure_character_mood() -> void:
	if character_mood != null:
		return
	character_mood = CharacterMood.new()

func _connect_character_mood() -> void:
	if character_mood == null:
		return
	var mood_callable := Callable(self, "_on_mood_changed")
	if not character_mood.mood_changed.is_connected(mood_callable):
		character_mood.mood_changed.connect(mood_callable)
	var entries_callable := Callable(self, "_on_entries_changed")
	if not character_mood.entries_changed.is_connected(entries_callable):
		character_mood.entries_changed.connect(entries_callable)

func _load_default_entries() -> void:
	for path in default_entry_paths:
		if path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			continue
		var resource := load(path)
		if resource != null and resource is CharacterMoodEntryData:
			var entry_data := resource as CharacterMoodEntryData
			if not has_entry(entry_data.entry_id):
				add_entry(entry_data)

func _resolve_game_clock() -> void:
	if _game_clock != null:
		return
	if not game_clock_path.is_empty():
		_game_clock = get_node_or_null(game_clock_path)
	if _game_clock == null:
		_game_clock = get_node_or_null("/root/GameClock")
	if _game_clock == null:
		_game_clock = get_tree().get_first_node_in_group(&"game_clock")

func _connect_game_clock() -> void:
	var clock := _get_game_clock()
	if clock == null:
		return
	if clock.has_signal("season_changed"):
		var season_callable := Callable(self, "_on_season_changed")
		if not clock.season_changed.is_connected(season_callable):
			clock.season_changed.connect(season_callable)
	if clock.has_signal("minute_changed"):
		var minute_callable := Callable(self, "_on_minute_changed")
		if not clock.minute_changed.is_connected(minute_callable):
			clock.minute_changed.connect(minute_callable)

func _get_game_clock() -> Node:
	if _game_clock == null:
		_resolve_game_clock()
	return _game_clock

func _get_absolute_minute(clock: Node) -> int:
	if clock == null:
		return 0
	var day_value := int(clock.get("day"))
	var minute_value := int(clock.get("minute_of_day"))
	return maxi(day_value - 1, 0) * MINUTES_PER_DAY + minute_value

func _on_season_changed(season_id: String, _season_day: int, season_year: int) -> void:
	_ensure_character_mood()
	character_mood.update_for_season(season_id, season_year)

func _on_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	refresh_timed_entries()

func _on_mood_changed(old_value: int, new_value: int) -> void:
	mood_changed.emit(old_value, new_value)

func _on_entries_changed() -> void:
	entries_changed.emit()
