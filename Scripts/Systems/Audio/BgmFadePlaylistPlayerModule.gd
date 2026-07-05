class_name BgmFadePlaylistPlayerModule
extends BgmPlaylistPlayerModule

@export_range(0.0, 10.0, 0.05) var fade_out_seconds: float = 0.5
@export_range(0.0, 10.0, 0.05) var fade_in_seconds: float = 0.5


func _apply_playlist_settings() -> void:
	super._apply_playlist_settings()
	if playlist == null:
		return
	fade_out_seconds = playlist.fade_out_seconds
	fade_in_seconds = playlist.fade_in_seconds


func _play_index(index: int) -> bool:
	var stream := _load_track(index)
	if stream == null:
		return false

	_current_index = _normalize_index(index)
	_started = true
	_play_bgm_stream(stream)
	return true


func _play_bgm_stream(stream: AudioStream) -> void:
	if AudioPlayer.has_method("play_bgm_fade"):
		AudioPlayer.play_bgm_fade(stream, 0.0, restart_if_same, fade_out_seconds, fade_in_seconds)
		return
	AudioPlayer.play_bgm(stream, 0.0, restart_if_same)
