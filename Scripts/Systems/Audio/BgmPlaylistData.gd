extends Resource
class_name BgmPlaylistData

@export var playlist_id: StringName = &""
@export var display_name: String = ""
@export var tracks: PackedStringArray = PackedStringArray()
@export var shuffle_tracks: bool = false
@export_range(0, 999, 1) var start_index: int = 0
@export var restart_if_same: bool = true
@export var advance_when_finished: bool = true


func get_track_count() -> int:
	return tracks.size()


func is_empty() -> bool:
	return tracks.is_empty()


func get_normalized_start_index() -> int:
	if tracks.is_empty():
		return -1
	return posmod(start_index, tracks.size())
