extends Node
class_name BuildModeController

signal build_mode_changed(enabled: bool)
signal furniture_selection_changed(furniture_scene: PackedScene, furniture_id: StringName, footprint: Vector2i)

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var fallback_room_is_buildable: bool = true

var _room_map: Node
var _build_mode_enabled: bool = false
var _selected_furniture_scene: PackedScene
var _selected_furniture_id: StringName = &""
var _selected_footprint: Vector2i = Vector2i(1, 1)


func _ready() -> void:
	_resolve_room_map()


func is_buildable() -> bool:
	_resolve_room_map()
	if _room_map == null:
		return fallback_room_is_buildable
	if _room_map.has_method("is_buildable"):
		return _room_map.call("is_buildable") == true
	if _room_map.has_meta("buildable"):
		return _room_map.get_meta("buildable", fallback_room_is_buildable) == true
	return fallback_room_is_buildable


func is_build_mode_enabled() -> bool:
	return _build_mode_enabled


func set_build_mode_enabled(enabled: bool) -> void:
	var next_enabled := enabled and is_buildable()
	if _build_mode_enabled == next_enabled:
		return
	_build_mode_enabled = next_enabled
	if not _build_mode_enabled:
		clear_selected_furniture()
	build_mode_changed.emit(_build_mode_enabled)


func toggle_build_mode() -> bool:
	set_build_mode_enabled(not _build_mode_enabled)
	return _build_mode_enabled


func select_furniture_scene(furniture_scene: PackedScene, furniture_id: StringName, footprint: Vector2i) -> void:
	_selected_furniture_scene = furniture_scene
	_selected_furniture_id = furniture_id
	_selected_footprint = Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	furniture_selection_changed.emit(_selected_furniture_scene, _selected_furniture_id, _selected_footprint)


func clear_selected_furniture() -> void:
	if _selected_furniture_scene == null and _selected_furniture_id == &"":
		return
	_selected_furniture_scene = null
	_selected_furniture_id = &""
	_selected_footprint = Vector2i(1, 1)
	furniture_selection_changed.emit(_selected_furniture_scene, _selected_furniture_id, _selected_footprint)


func get_selected_furniture_scene() -> PackedScene:
	return _selected_furniture_scene


func get_selected_furniture_id() -> StringName:
	return _selected_furniture_id


func get_selected_footprint() -> Vector2i:
	return _selected_footprint


func _resolve_room_map() -> void:
	if _room_map != null:
		return
	if room_map_path.is_empty():
		return
	_room_map = get_node_or_null(room_map_path)
