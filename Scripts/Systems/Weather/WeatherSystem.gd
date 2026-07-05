extends Node
class_name GameWeatherSystem

signal weather_changed(weather_id: StringName, display_name: String)
signal daily_weather_updated(day: int, weather_id: StringName, display_name: String)

const WEATHER_SUNNY: StringName = &"sunny"
const WEATHER_RAIN: StringName = &"rain"
const RAIN_AMBIENCE_PATH := "res://Assets/Audio/Ambience/Rain.ogg"

@export var start_weather: StringName = WEATHER_SUNNY
@export_range(0.0, 1.0, 0.01) var rain_chance: float = 0.35
@export var play_ambience_directly: bool = false
@export var rain_ambience_path: String = RAIN_AMBIENCE_PATH

var current_weather_id: StringName = WEATHER_SUNNY
var _last_midnight_update_day: int = -1
var _rng := RandomNumberGenerator.new()
var _rain_ambience: AudioStream


func _ready() -> void:
	add_to_group(&"weather_system")
	_rng.randomize()
	current_weather_id = _normalize_weather_id(start_weather)
	_apply_weather_ambience_if_enabled()
	call_deferred("_connect_game_clock")


func get_weather_id() -> StringName:
	return current_weather_id


func get_weather_display_name(weather_id: StringName = &"") -> String:
	var target_weather_id := current_weather_id if weather_id == &"" else weather_id
	match target_weather_id:
		WEATHER_SUNNY:
			return "晴れ"
		WEATHER_RAIN:
			return "雨"
		_:
			return String(target_weather_id)


func is_rainy() -> bool:
	return current_weather_id == WEATHER_RAIN


func update_daily_weather(day: int) -> void:
	var next_weather_id := _roll_weather_id()
	set_weather(next_weather_id)
	_last_midnight_update_day = day
	daily_weather_updated.emit(day, current_weather_id, get_weather_display_name())


func set_weather(weather_id: StringName) -> void:
	var normalized_weather_id := _normalize_weather_id(weather_id)
	if current_weather_id == normalized_weather_id:
		_apply_weather_ambience_if_enabled()
		return
	current_weather_id = normalized_weather_id
	_apply_weather_ambience_if_enabled()
	weather_changed.emit(current_weather_id, get_weather_display_name())


func get_save_data() -> Dictionary:
	return {
		"current_weather_id": String(current_weather_id),
		"last_midnight_update_day": _last_midnight_update_day,
	}


func apply_save_data(data: Dictionary) -> void:
	current_weather_id = _normalize_weather_id(StringName(str(data.get("current_weather_id", String(WEATHER_SUNNY)))))
	_last_midnight_update_day = int(data.get("last_midnight_update_day", -1))
	_apply_weather_ambience_if_enabled()
	weather_changed.emit(current_weather_id, get_weather_display_name())


func _connect_game_clock() -> void:
	if GameClock == null:
		return
	var callable := Callable(self, "_on_game_clock_hour_changed")
	if not GameClock.hour_changed.is_connected(callable):
		GameClock.hour_changed.connect(callable)


func _on_game_clock_hour_changed(day: int, hour: int) -> void:
	if hour != 0:
		return
	if day == _last_midnight_update_day:
		return
	update_daily_weather(day)


func _roll_weather_id() -> StringName:
	if _rng.randf() < rain_chance:
		return WEATHER_RAIN
	return WEATHER_SUNNY


func _normalize_weather_id(weather_id: StringName) -> StringName:
	match weather_id:
		WEATHER_RAIN:
			return WEATHER_RAIN
		_:
			return WEATHER_SUNNY


func _apply_weather_ambience_if_enabled() -> void:
	if not play_ambience_directly:
		return
	if current_weather_id == WEATHER_RAIN:
		_play_rain_ambience()
		return
	AudioPlayer.stop_ambience()


func _play_rain_ambience() -> void:
	var rain_stream := _get_rain_ambience()
	if rain_stream == null:
		return
	AudioPlayer.play_ambience(rain_stream)


func _get_rain_ambience() -> AudioStream:
	if _rain_ambience != null:
		return _rain_ambience
	if rain_ambience_path.is_empty():
		return null
	if not ResourceLoader.exists(rain_ambience_path):
		return null
	_rain_ambience = load(rain_ambience_path) as AudioStream
	_set_stream_loop_enabled(_rain_ambience)
	return _rain_ambience


func _set_stream_loop_enabled(stream: AudioStream) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if property is Dictionary and StringName(property.get("name", &"")) == &"loop":
			stream.set("loop", true)
			return
