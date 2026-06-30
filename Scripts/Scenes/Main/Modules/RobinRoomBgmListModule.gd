class_name RobinRoomBgmListModule
extends Node

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


func _ready() -> void:
	_rng.randomize()
	set_process(advance_when_finished)

	if autoplay:
		play_start_track()


func _exit_tree() -> void:
	if not stop_bgm_on_exit:
		return
	if not _started:
		return
	if AudioPlayer.get_current_bgm() != _get_current_stream():
		return

	AudioPlayer.stop_bgm()


func _process(_delta: float) -> void:
	if not _started:
		return
	if not advance_when_finished:
		return
	if _get_valid_track_count() <= 0:
		return
	if AudioPlayer.get_current_bgm() != _get_current_stream():
		return
	if AudioPlayer.is_bgm_playing():
		return

	play_next_track()


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
	if _current_index < 0 or _current_index >= bgm_paths.size():
		return ""
	return bgm_paths[_current_index]


func _play_first_valid_from(index: int, step: int) -> bool:
	if bgm_paths.is_empty():
		return false

	var checked_count := 0
	var next_index := _normalize_index(index)
	var direction := 1 if step >= 0 else -1

	while checked_count < bgm_paths.size():
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

	var attempts := 0
	while attempts < 20:
		var index := _rng.randi_range(0, bgm_paths.size() - 1)
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
	if index < 0 or index >= bgm_paths.size():
		return null

	var path := String(bgm_paths[index]).strip_edges()
	if path.is_empty():
		return null

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("RobinRoomBgmListModule: BGMを読み込めません: %s" % path)

	return stream


func _get_current_stream() -> AudioStream:
	if _current_index < 0:
		return null
	return _load_track(_current_index)


func _get_valid_track_count() -> int:
	var count := 0
	for i in bgm_paths.size():
		if _load_track(i) != null:
			count += 1
	return count


func _normalize_index(index: int) -> int:
	if bgm_paths.is_empty():
		return -1
	return posmod(index, bgm_paths.size())
