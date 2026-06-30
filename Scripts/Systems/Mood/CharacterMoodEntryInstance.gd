extends Resource
class_name CharacterMoodEntryInstance

const MINUTES_PER_DAY := 24 * 60

@export var data: CharacterMoodEntryData
@export var start_season_id: String = ""
@export var start_season_year: int = 1
@export var end_absolute_minute: int = -1

func setup(new_data: CharacterMoodEntryData, game_clock: Node = null) -> void:
	data = new_data
	if game_clock != null:
		if game_clock.has_method("get_season_id"):
			start_season_id = String(game_clock.call("get_season_id"))
		if game_clock.has_method("get_season_year"):
			start_season_year = int(game_clock.call("get_season_year"))
		_setup_time_limit(game_clock)

func get_entry_id() -> StringName:
	if data == null:
		return &""
	return data.entry_id

func get_display_name() -> String:
	if data == null:
		return ""
	return data.display_name

func get_detail_text() -> String:
	if data == null:
		return ""
	return data.detail_text

func get_point() -> int:
	if data == null:
		return 0
	return data.point

func should_end_on_season_changed(new_season_id: String, new_season_year: int) -> bool:
	if data == null:
		return true
	if not data.until_next_season:
		return false
	if start_season_id == "":
		return false
	return new_season_id != start_season_id or new_season_year != start_season_year

func should_end_at_absolute_minute(current_absolute_minute: int) -> bool:
	if end_absolute_minute < 0:
		return false
	return current_absolute_minute >= end_absolute_minute

func _setup_time_limit(game_clock: Node) -> void:
	if data == null:
		return
	if data.duration_game_minutes <= 0:
		return
	end_absolute_minute = _get_absolute_minute(game_clock) + data.duration_game_minutes

func _get_absolute_minute(game_clock: Node) -> int:
	if game_clock == null:
		return 0
	var day_value := int(game_clock.get("day"))
	var minute_value := int(game_clock.get("minute_of_day"))
	return maxi(day_value - 1, 0) * MINUTES_PER_DAY + minute_value
