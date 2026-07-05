class_name AmbiencePlaylistPlayerModule
extends Node

@export var playlist: AmbiencePlaylistData
@export var ambience_paths: PackedStringArray = PackedStringArray()
@export var autoplay: bool = true
@export var shuffle_tracks: bool = false
@export_range(0, 999, 1) var start_index: int = 0
@export var restart_if_same: bool = false
@export var loop_tracks: bool = true
@export var stop_ambience_on_exit: bool = true
@export_range(0.0, 10.0, 0.05) var fade_out_seconds: float = 0.5
@export_range(0.0, 10.0, 0.05) var fade_in_seconds: float = 0.5

var _current_index: int = -1
var _started: bool = false
var _rng := RandomNumberGenerator.new()
var _track_cache: Dictionary = {}
var _valid_track_count: int = -1


func _ready() -> void:
	_apply_playlist_settings()
	_rng.randomize()
	set_process(false)

	if autoplay:
		play_start_track()


func _exit_tree() -> void:
	if not stop_ambience_on_exit:
		return
	if not _started:
		return
	if AudioPlayer.get_current_ambience() != _get_current_stream():
		return
	AudioPlayer.stop_ambience()


func set_playlist(next_playlist: AmbiencePlaylistData, play_immediately: bool = true) -> void:
	if playlist == next_playlist:
		return
	playlist = next_playlist
	_apply_playlist_settings()
	clear_track_cache()
	_current_index = -1
	_started = false
	if play_immediately and autoplay:
		play_start_track()


func play_start_track() -> void:
	if _get_valid_track_count() <= 0:
		_started = false
		AudioPlayer.stop_ambience()
		return

	var index: int = _normalize_index(start_index)
	if shuffle_tracks:
		_play_random_track()
		return
	_play_first_valid_from(index, 1)


func stop() -> void:
	_started = false
	AudioPlayer.stop_ambience()


func get_current_index() -> int:
	return _current_index


func get_current_path() -> String:
	var paths: PackedStringArray = _get_active_ambience_paths()
	if _current_index < 0 or _current_index >= paths.size():
		return ""
	return paths[_current_index]


func get_current_playlist() -> AmbiencePlaylistData:
	return playlist


func clear_track_cache() -> void:
	_track_cache.clear()
	_valid_track_count = -1


func _apply_playlist_settings() -> void:
	if playlist == null:
		return
	shuffle_tracks = playlist.shuffle_tracks
	start_index = playlist.start_index
	restart_if_same = playlist.restart_if_same
	loop_tracks = playlist.loop_tracks
	fade_out_seconds = playlist.fade_out_seconds
	fade_in_seconds = playlist.fade_in_seconds
	clear_track_cache()


func _get_active_ambience_paths() -> PackedStringArray:
	if playlist != null and not playlist.tracks.is_empty():
		return playlist.tracks
	return ambience_paths


func _play_first_valid_from(index: int, step: int) -> bool:
	var paths: PackedStringArray = _get_active_ambience_paths()
	if paths.is_empty():
		return false

	var checked_count: int = 0
	var next_index: int = _normalize_index(index)
	var direction: int = 1 if step >= 0 else -1

	while checked_count < paths.size():
		if _play_index(next_index):
			return true

		next_index = _normalize_index(next_index + direction)
		checked_count += 1

	return false


func _play_random_track() -> bool:
	var valid_count: int = _get_valid_track_count()
	if valid_count <= 0:
		return false

	if valid_count == 1:
		return _play_first_valid_from(_current_index, 1)

	var paths: PackedStringArray = _get_active_ambience_paths()
	var attempts: int = 0
	while attempts < 20:
		var index: int = _rng.randi_range(0, paths.size() - 1)
		if index != _current_index and _play_index(index):
			return true
		attempts += 1

	return _play_first_valid_from(_normalize_index(_current_index + 1), 1)


func _play_index(index: int) -> bool:
	var stream: AudioStream = _load_track(index)
	if stream == null:
		return false

	_current_index = _normalize_index(index)
	_started = true
	_play_ambience_stream(stream)
	return true


func _load_track(index: int) -> AudioStream:
	var paths: PackedStringArray = _get_active_ambience_paths()
	if index < 0 or index >= paths.size():
		return null
	if _track_cache.has(index):
		return _track_cache[index] as AudioStream

	var path: String = String(paths[index]).strip_edges()
	if path.is_empty():
		_track_cache[index] = null
		return null

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AmbiencePlaylistPlayerModule: 環境音を読み込めません: %s" % path)
	else:
		_apply_stream_loop_setting(stream)

	_track_cache[index] = stream
	return stream


func _play_ambience_stream(stream: AudioStream) -> void:
	if AudioPlayer.has_method("play_ambience_fade"):
		AudioPlayer.play_ambience_fade(stream, 0.0, restart_if_same, fade_out_seconds, fade_in_seconds)
		return
	AudioPlayer.play_ambience(stream, 0.0, restart_if_same)


func _apply_stream_loop_setting(stream: AudioStream) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if property is Dictionary and StringName(property.get("name", &"")) == &"loop":
			stream.set("loop", loop_tracks)
			return


func _get_current_stream() -> AudioStream:
	if _current_index < 0:
		return null
	return _load_track(_current_index)


func _get_valid_track_count() -> int:
	if _valid_track_count >= 0:
		return _valid_track_count
	var paths: PackedStringArray = _get_active_ambience_paths()
	var count: int = 0
	for i in paths.size():
		if _load_track(i) != null:
			count += 1
	_valid_track_count = count
	return _valid_track_count


func _normalize_index(index: int) -> int:
	var paths: PackedStringArray = _get_active_ambience_paths()
	if paths.is_empty():
		return -1
	return posmod(index, paths.size())
