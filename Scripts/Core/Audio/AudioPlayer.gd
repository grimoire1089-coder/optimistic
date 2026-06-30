extends Node

const SFX_POOL_SIZE := 8

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm: AudioStream = null
var _current_ambience: AudioStream = null


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

	_current_bgm = stream
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.play(from_position)


func stop_bgm() -> void:
	_bgm_player.stop()
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
