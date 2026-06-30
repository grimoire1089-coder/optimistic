extends Resource
class_name CharacterMoodEntryInstance

@export var data: CharacterMoodEntryData
@export var start_season_id: String = ""
@export var start_season_year: int = 1

func setup(new_data: CharacterMoodEntryData, game_clock: Node = null) -> void:
	data = new_data
	if game_clock != null:
		if game_clock.has_method("get_season_id"):
			start_season_id = String(game_clock.call("get_season_id"))
		if game_clock.has_method("get_season_year"):
			start_season_year = int(game_clock.call("get_season_year"))

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
