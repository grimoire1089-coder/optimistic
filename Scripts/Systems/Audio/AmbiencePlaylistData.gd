extends Resource
class_name AmbiencePlaylistData

@export var playlist_id: StringName = &""
@export var display_name: String = ""
@export var tracks: PackedStringArray = PackedStringArray()
@export var shuffle_tracks: bool = false
@export_range(0, 999, 1) var start_index: int = 0
@export var restart_if_same: bool = false
@export var loop_tracks: bool = true
@export_range(0.0, 10.0, 0.05) var fade_out_seconds: float = 0.5
@export_range(0.0, 10.0, 0.05) var fade_in_seconds: float = 0.5


func get_track_count() -> int:
	return tracks.size()


func is_empty() -> bool:
	return tracks.is_empty()


func get_normalized_start_index() -> int:
	if tracks.is_empty():
		return -1
	return posmod(start_index, tracks.size())
