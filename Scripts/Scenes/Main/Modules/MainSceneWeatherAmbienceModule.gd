extends Node
class_name MainSceneWeatherAmbienceModule

@export var registry: AmbiencePlaylistRegistry
@export var ambience_player_path: NodePath = NodePath("../AmbiencePlaylistPlayerModule")
@export var weather_system_path: NodePath = NodePath("/root/WeatherSystem")
@export var default_weather_id: StringName = &"sunny"
@export var resolve_interval_seconds: float = 0.25

var _ambience_player: AmbiencePlaylistPlayerModule
var _weather_system: Node
var _last_weather_id: StringName = &""
var _resolve_timer: float = 0.0
var _connected_to_weather_system: bool = false


func _ready() -> void:
	set_process(true)
	_resolve_refs()
	_try_connect_weather_system()
	_sync_initial_weather()


func _process(delta: float) -> void:
	_resolve_timer -= maxf(delta, 0.0)
	if _resolve_timer > 0.0:
		return
	_resolve_timer = maxf(resolve_interval_seconds, 0.1)

	_resolve_refs()
	_try_connect_weather_system()
	_sync_initial_weather()

	if _ambience_player != null and _weather_system != null and _connected_to_weather_system:
		set_process(false)


func sync_current_weather() -> void:
	var weather_id: StringName = _get_current_weather_id()
	_apply_weather_playlist(weather_id)


func _resolve_refs() -> void:
	if _ambience_player == null and not ambience_player_path.is_empty():
		_ambience_player = get_node_or_null(ambience_player_path) as AmbiencePlaylistPlayerModule
	if _weather_system == null and not weather_system_path.is_empty():
		_weather_system = get_node_or_null(weather_system_path)


func _try_connect_weather_system() -> void:
	if _connected_to_weather_system:
		return
	if _weather_system == null:
		return
	if not _weather_system.has_signal("weather_changed"):
		return
	var changed_callable := Callable(self, "_on_weather_changed")
	if not _weather_system.weather_changed.is_connected(changed_callable):
		_weather_system.weather_changed.connect(changed_callable)
	_connected_to_weather_system = true


func _sync_initial_weather() -> void:
	if _ambience_player == null:
		return
	if _last_weather_id != &"":
		return
	var weather_id: StringName = _get_current_weather_id()
	_apply_weather_playlist(weather_id)


func _get_current_weather_id() -> StringName:
	if _weather_system != null and _weather_system.has_method("get_weather_id"):
		var weather_id_text: String = String(_weather_system.call("get_weather_id"))
		if weather_id_text != "":
			return StringName(weather_id_text)
	return default_weather_id


func _on_weather_changed(weather_id: StringName, _display_name: String) -> void:
	_apply_weather_playlist(weather_id)


func _apply_weather_playlist(weather_id: StringName) -> void:
	if _ambience_player == null:
		return
	if registry == null:
		return
	if weather_id == _last_weather_id:
		return
	var playlist: AmbiencePlaylistData = registry.get_playlist_for_location(weather_id)
	if playlist == null:
		return
	_last_weather_id = weather_id
	_ambience_player.set_playlist(playlist, true)
