class_name RobinRoomBgmListModule
extends Node

@export var playlist: BgmPlaylistData
@export var bgm_paths: PackedStringArray = PackedStringArray()
@export var autoplay: bool = true
@export var advance_when_finished: bool = true
@export var shuffle_tracks: bool = false
@export_range(0, 999, 1) var start_index: int = 0
@export var restart_if_same: bool = true
@export var stop_bgm_on_exit: bool = true

var _current_index: int = -1
var _started: bool = false
var _rng := RandomNumberGenerator.new()
var _track_cache: Dictionary = {}
var _valid_track_count := -1


func _ready() -> void:
	_apply_playlist_settings()
	_rng.randomize()
	set_process(false)
	_connect_audio_player_finished()

	if autoplay:
		play_start_track()


func _exit_tree() -> void:
	_disconnect_audio_player_finished()
	if not stop_bgm_on_exit:
		return
	if not _started:
		return
	if AudioPlayer.get_current_bgm() != _get_current_stream():
		return

	AudioPlayer.stop_bgm()


func set_playlist(next_playlist: BgmPlaylistData, play_immediately: bool = true) -> void:
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
		return

	var index := _normalize_index(start_index)
	_play_first_valid_from(index, 1)


func play_next_track() -> void:
	if _get_valid_track_count() <= 0:
		_started = false
		return

	if shuffle_tracks:
		_play_random_track()
		return

	var next_index := _normalize_index(_current_index + 1)
	_play_first_valid_from(next_index, 1)


func play_previous_track() -> void:
	if _get_valid_track_count() <= 0:
		_started = false
		return

	var previous_index := _normalize_index(_current_index - 1)
	_play_first_valid_from(previous_index, -1)


func stop() -> void:
	_started = false
	AudioPlayer.stop_bgm()


func get_current_index() -> int:
	return _current_index


func get_current_path() -> String:
	var paths := _get_active_bgm_paths()
	if _current_index < 0 or _current_index >= paths.size():
		return ""
	return paths[_current_index]


func clear_track_cache() -> void:
	_track_cache.clear()
	_valid_track_count = -1


func _apply_playlist_settings() -> void:
	if playlist == null:
		return
	shuffle_tracks = playlist.shuffle_tracks
	start_index = playlist.start_index
	restart_if_same = playlist.restart_if_same
	advance_when_finished = playlist.advance_when_finished
	clear_track_cache()


func _get_active_bgm_paths() -> PackedStringArray:
	if playlist != null and not playlist.tracks.is_empty():
		return playlist.tracks
	return bgm_paths


func _connect_audio_player_finished() -> void:
	var finished_callable := Callable(self, "_on_audio_player_bgm_finished")
	if not AudioPlayer.bgm_finished.is_connected(finished_callable):
		AudioPlayer.bgm_finished.connect(finished_callable)


func _disconnect_audio_player_finished() -> void:
	var finished_callable := Callable(self, "_on_audio_player_bgm_finished")
	if AudioPlayer.bgm_finished.is_connected(finished_callable):
		AudioPlayer.bgm_finished.disconnect(finished_callable)


func _on_audio_player_bgm_finished(finished_stream: AudioStream) -> void:
	if not _started:
		return
	if not advance_when_finished:
		return
	if finished_stream == null:
		return
	if finished_stream != _get_current_stream():
		return
	play_next_track()


func _play_first_valid_from(index: int, step: int) -> bool:
	var paths := _get_active_bgm_paths()
	if paths.is_empty():
		return false

	var checked_count := 0
	var next_index := _normalize_index(index)
	var direction := 1 if step >= 0 else -1

	while checked_count < paths.size():
		if _play_index(next_index):
			return true

		next_index = _normalize_index(next_index + direction)
		checked_count += 1

	return false


func _play_random_track() -> bool:
	var valid_count := _get_valid_track_count()
	if valid_count <= 0:
		return false

	if valid_count == 1:
		return _play_first_valid_from(_current_index, 1)

	var paths := _get_active_bgm_paths()
	var attempts := 0
	while attempts < 20:
		var index := _rng.randi_range(0, paths.size() - 1)
		if index != _current_index and _play_index(index):
			return true
		attempts += 1

	return _play_first_valid_from(_normalize_index(_current_index + 1), 1)


func _play_index(index: int) -> bool:
	var stream := _load_track(index)
	if stream == null:
		return false

	_current_index = _normalize_index(index)
	_started = true
	AudioPlayer.play_bgm(stream, 0.0, restart_if_same)
	return true


func _load_track(index: int) -> AudioStream:
	var paths := _get_active_bgm_paths()
	if index < 0 or index >= paths.size():
		return null
	if _track_cache.has(index):
		return _track_cache[index] as AudioStream

	var path := String(paths[index]).strip_edges()
	if path.is_empty():
		_track_cache[index] = null
		return null

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("RobinRoomBgmListModule: BGMを読み込めません: %s" % path)

	_track_cache[index] = stream
	return stream


func _get_current_stream() -> AudioStream:
	if _current_index < 0:
		return null
	return _load_track(_current_index)


func _get_valid_track_count() -> int:
	if _valid_track_count >= 0:
		return _valid_track_count
	var paths := _get_active_bgm_paths()
	var count := 0
	for i in paths.size():
		if _load_track(i) != null:
			count += 1
	_valid_track_count = count
	return _valid_track_count


func _normalize_index(index: int) -> int:
	var paths := _get_active_bgm_paths()
	if paths.is_empty():
		return -1
	return posmod(index, paths.size())
