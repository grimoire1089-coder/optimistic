extends Node
class_name MainSceneAmbienceLocationModule

@export var registry: AmbiencePlaylistRegistry
@export var ambience_player_path: NodePath = NodePath("../AmbiencePlaylistPlayerModule")
@export var map_travel_module_path: NodePath = NodePath("../MainSceneMapTravelModule")
@export var default_location_id: StringName = &"robin_room"
@export var resolve_interval_seconds: float = 0.25

var _ambience_player: AmbiencePlaylistPlayerModule
var _map_travel_module: Node
var _last_location_id: StringName = &""
var _resolve_timer: float = 0.0
var _connected_to_travel_module: bool = false


func _ready() -> void:
	set_process(true)
	_resolve_refs()
	_try_connect_map_travel_module()
	_sync_initial_location()


func _process(delta: float) -> void:
	_resolve_timer -= maxf(delta, 0.0)
	if _resolve_timer > 0.0:
		return
	_resolve_timer = maxf(resolve_interval_seconds, 0.1)

	_resolve_refs()
	_try_connect_map_travel_module()
	_sync_initial_location()

	if _ambience_player != null and _map_travel_module != null and _connected_to_travel_module:
		set_process(false)


func sync_current_location() -> void:
	var location_id: StringName = _get_current_location_id()
	_apply_location_playlist(location_id)


func _resolve_refs() -> void:
	if _ambience_player == null and not ambience_player_path.is_empty():
		_ambience_player = get_node_or_null(ambience_player_path) as AmbiencePlaylistPlayerModule
	if _map_travel_module == null and not map_travel_module_path.is_empty():
		_map_travel_module = get_node_or_null(map_travel_module_path)


func _try_connect_map_travel_module() -> void:
	if _connected_to_travel_module:
		return
	if _map_travel_module == null:
		return
	if not _map_travel_module.has_signal("active_map_changed"):
		return
	var changed_callable := Callable(self, "_on_active_map_changed")
	if not _map_travel_module.active_map_changed.is_connected(changed_callable):
		_map_travel_module.active_map_changed.connect(changed_callable)
	_connected_to_travel_module = true


func _sync_initial_location() -> void:
	if _ambience_player == null:
		return
	if _last_location_id != &"":
		return
	var location_id: StringName = _get_current_location_id()
	_apply_location_playlist(location_id)


func _get_current_location_id() -> StringName:
	if _map_travel_module != null and _map_travel_module.has_method("get_active_map_id"):
		var active_id_text: String = String(_map_travel_module.call("get_active_map_id"))
		if active_id_text != "":
			return StringName(active_id_text)
	return default_location_id


func _on_active_map_changed(map_id: StringName) -> void:
	_apply_location_playlist(map_id)


func _apply_location_playlist(location_id: StringName) -> void:
	if _ambience_player == null:
		return
	if registry == null:
		return
	if location_id == _last_location_id:
		return
	var playlist: AmbiencePlaylistData = registry.get_playlist_for_location(location_id)
	if playlist == null:
		return
	_last_location_id = location_id
	_ambience_player.set_playlist(playlist, true)
