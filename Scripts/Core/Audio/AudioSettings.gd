extends Node

signal volume_changed(bus_name: StringName, volume: float)

const CONFIG_PATH := "user://audio_settings.cfg"
const CONFIG_SECTION := "audio"
const MIN_RESTORE_VOLUME := 0.01

const BUS_BGM: StringName = &"BGM"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_VOICE: StringName = &"Voice"

const AUDIO_BUSES: Array[StringName] = [
	BUS_BGM,
	BUS_SFX,
	BUS_AMBIENCE,
	BUS_VOICE,
]

const DEFAULT_VOLUMES := {
	"BGM": 0.8,
	"SFX": 0.8,
	"Ambience": 0.8,
	"Voice": 0.8,
}

var _volumes: Dictionary = {}
var _last_non_zero_volumes: Dictionary = {}


func _ready() -> void:
	_setup_audio_buses()
	_load_settings()
	_apply_all_volumes()


func set_volume(bus_name: StringName, volume: float, save_immediately: bool = true) -> void:
	if not AUDIO_BUSES.has(bus_name):
		push_warning("未登録のAudio Busです: %s" % String(bus_name))
		return

	var clamped_volume := clampf(volume, 0.0, 1.0)
	var key := String(bus_name)
	_volumes[key] = clamped_volume

	if clamped_volume > 0.0:
		_last_non_zero_volumes[key] = clamped_volume

	_apply_volume(bus_name, clamped_volume)
	volume_changed.emit(bus_name, clamped_volume)

	if save_immediately:
		save_settings()


func get_volume(bus_name: StringName) -> float:
	var key := String(bus_name)
	return float(_volumes.get(key, DEFAULT_VOLUMES.get(key, 0.8)))


func is_muted(bus_name: StringName) -> bool:
	if not AUDIO_BUSES.has(bus_name):
		return false
	return get_volume(bus_name) <= 0.0


func toggle_mute(bus_name: StringName, fallback_restore_volume: float = -1.0) -> bool:
	if not AUDIO_BUSES.has(bus_name):
		push_warning("未登録のAudio Busです: %s" % String(bus_name))
		return false

	if is_muted(bus_name):
		set_volume(bus_name, _get_restore_volume(bus_name, fallback_restore_volume))
		return false

	set_volume(bus_name, 0.0)
	return true


func reset_to_default() -> void:
	for bus_name: StringName in AUDIO_BUSES:
		var key := String(bus_name)
		set_volume(bus_name, float(DEFAULT_VOLUMES.get(key, 0.8)), false)

	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()

	for bus_name: StringName in AUDIO_BUSES:
		var key := String(bus_name)
		config.set_value(CONFIG_SECTION, key, get_volume(bus_name))

	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_error("音量設定の保存に失敗しました。Error: %s" % err)


func _setup_audio_buses() -> void:
	for bus_name: StringName in AUDIO_BUSES:
		_ensure_bus_exists(bus_name)


func _ensure_bus_exists(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus(AudioServer.get_bus_count())

	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, String(bus_name))
	AudioServer.set_bus_send(bus_index, &"Master")


func _load_settings() -> void:
	_volumes.clear()
	_last_non_zero_volumes.clear()

	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)

	for bus_name: StringName in AUDIO_BUSES:
		var key := String(bus_name)
		var default_volume := float(DEFAULT_VOLUMES.get(key, 0.8))
		var loaded_volume := default_volume

		if err == OK:
			loaded_volume = float(config.get_value(CONFIG_SECTION, key, default_volume))

		loaded_volume = clampf(loaded_volume, 0.0, 1.0)
		_volumes[key] = loaded_volume

		if loaded_volume > 0.0:
			_last_non_zero_volumes[key] = loaded_volume


func _apply_all_volumes() -> void:
	for bus_name: StringName in AUDIO_BUSES:
		_apply_volume(bus_name, get_volume(bus_name))


func _apply_volume(bus_name: StringName, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("Audio Busが見つかりません: %s" % String(bus_name))
		return

	if volume <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return

	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))


func _get_restore_volume(bus_name: StringName, fallback_restore_volume: float) -> float:
	if fallback_restore_volume > 0.0:
		return clampf(fallback_restore_volume, MIN_RESTORE_VOLUME, 1.0)

	var key := String(bus_name)
	var stored_volume := float(_last_non_zero_volumes.get(key, 0.0))
	if stored_volume > 0.0:
		return clampf(stored_volume, MIN_RESTORE_VOLUME, 1.0)

	return clampf(float(DEFAULT_VOLUMES.get(key, 0.8)), MIN_RESTORE_VOLUME, 1.0)
