extends Node

signal bgm_finished(stream: AudioStream)

const SFX_POOL_SIZE := 8
const BGM_SILENCE_DB := -80.0

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm: AudioStream = null
var _current_ambience: AudioStream = null
var _bgm_fade_tween: Tween
var _bgm_default_volume_db: float = 0.0
var _pending_bgm: AudioStream = null
var _pending_bgm_position: float = 0.0
var _pending_bgm_fade_in_seconds: float = 0.0


func _ready() -> void:
	_create_bgm_player()
	_create_ambience_player()
	_create_voice_player()
	_create_sfx_pool()


func play_bgm(stream: AudioStream, from_position: float = 0.0, restart_if_same: bool = false) -> void:
	if stream == null:
		return

	if not restart_if_same and _current_bgm == stream and _bgm_player.playing:
		return

	_kill_bgm_fade()
	_clear_pending_bgm()
	_current_bgm = stream
	_bgm_player.stop()
	_bgm_player.volume_db = _bgm_default_volume_db
	_bgm_player.stream = stream
	_bgm_player.play(from_position)


func play_bgm_fade(stream: AudioStream, from_position: float = 0.0, restart_if_same: bool = false, fade_out_seconds: float = 0.5, fade_in_seconds: float = 0.5) -> void:
	if stream == null:
		return

	if not restart_if_same and _current_bgm == stream and _bgm_player.playing:
		return

	var safe_fade_out_seconds: float = maxf(fade_out_seconds, 0.0)
	var safe_fade_in_seconds: float = maxf(fade_in_seconds, 0.0)

	_kill_bgm_fade()
	_clear_pending_bgm()

	if _current_bgm == null or not _bgm_player.playing or safe_fade_out_seconds <= 0.0:
		_start_bgm_with_fade_in(stream, from_position, safe_fade_in_seconds)
		return

	_pending_bgm = stream
	_pending_bgm_position = from_position
	_pending_bgm_fade_in_seconds = safe_fade_in_seconds
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", BGM_SILENCE_DB, safe_fade_out_seconds)
	_bgm_fade_tween.tween_callback(Callable(self, "_play_pending_bgm_after_fade_out"))


func stop_bgm() -> void:
	_kill_bgm_fade()
	_clear_pending_bgm()
	_bgm_player.stop()
	_bgm_player.volume_db = _bgm_default_volume_db
	_current_bgm = null


func pause_bgm() -> void:
	_bgm_player.stream_paused = true


func resume_bgm() -> void:
	_bgm_player.stream_paused = false


func get_current_bgm() -> AudioStream:
	return _current_bgm


func get_bgm_playback_position() -> float:
	if _bgm_player == null:
		return 0.0
	if not _bgm_player.playing:
		return 0.0
	return _bgm_player.get_playback_position()


func play_ambience(stream: AudioStream, from_position: float = 0.0, restart_if_same: bool = false) -> void:
	if stream == null:
		return

	if not restart_if_same and _current_ambience == stream and _ambience_player.playing:
		return

	_current_ambience = stream
	_ambience_player.stop()
	_ambience_player.stream = stream
	_ambience_player.play(from_position)


func stop_ambience() -> void:
	_ambience_player.stop()
	_current_ambience = null


func pause_ambience() -> void:
	_ambience_player.stream_paused = true


func resume_ambience() -> void:
	_ambience_player.stream_paused = false


func play_voice(stream: AudioStream, from_position: float = 0.0) -> void:
	if stream == null:
		return

	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.play(from_position)


func stop_voice() -> void:
	_voice_player.stop()


func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	var player := _get_available_sfx_player()
	if player == null:
		return

	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func stop_all_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()


func stop_all() -> void:
	stop_bgm()
	stop_ambience()
	stop_voice()
	stop_all_sfx()


func is_bgm_playing() -> bool:
	return _bgm_player.playing


func is_ambience_playing() -> bool:
	return _ambience_player.playing


func is_voice_playing() -> bool:
	return _voice_player.playing


func _create_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = String(AudioSettings.BUS_BGM)
	_bgm_player.finished.connect(_on_bgm_player_finished)
	_bgm_default_volume_db = _bgm_player.volume_db
	add_child(_bgm_player)


func _create_ambience_player() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = String(AudioSettings.BUS_AMBIENCE)
	add_child(_ambience_player)


func _create_voice_player() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = String(AudioSettings.BUS_VOICE)
	add_child(_voice_player)


func _create_sfx_pool() -> void:
	_sfx_players.clear()

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = String(AudioSettings.BUS_SFX)
		add_child(player)
		_sfx_players.append(player)


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player

	return _sfx_players[0]


func _start_bgm_with_fade_in(stream: AudioStream, from_position: float, fade_in_seconds: float) -> void:
	if stream == null:
		return

	_current_bgm = stream
	_bgm_player.stop()
	_bgm_player.stream = stream
	if fade_in_seconds > 0.0:
		_bgm_player.volume_db = BGM_SILENCE_DB
	else:
		_bgm_player.volume_db = _bgm_default_volume_db
	_bgm_player.play(from_position)

	if fade_in_seconds <= 0.0:
		return

	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", _bgm_default_volume_db, fade_in_seconds)


func _play_pending_bgm_after_fade_out() -> void:
	var next_bgm: AudioStream = _pending_bgm
	var next_position: float = _pending_bgm_position
	var next_fade_in_seconds: float = _pending_bgm_fade_in_seconds
	_clear_pending_bgm()
	_bgm_fade_tween = null
	_start_bgm_with_fade_in(next_bgm, next_position, next_fade_in_seconds)


func _kill_bgm_fade() -> void:
	if _bgm_fade_tween != null:
		_bgm_fade_tween.kill()
		_bgm_fade_tween = null


func _clear_pending_bgm() -> void:
	_pending_bgm = null
	_pending_bgm_position = 0.0
	_pending_bgm_fade_in_seconds = 0.0


func _on_bgm_player_finished() -> void:
	if _current_bgm == null:
		return
	bgm_finished.emit(_current_bgm)
