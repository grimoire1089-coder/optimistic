extends Node
class_name BuildModeController

signal build_mode_changed(enabled: bool)
signal furniture_selection_changed(furniture_scene: PackedScene, furniture_id: StringName, footprint: Vector2i)
signal furniture_rotation_changed(rotation_steps: int, footprint: Vector2i)
signal tool_mode_changed(tool_mode: StringName)

const TOOL_MODE_PLACE: StringName = &"place"
const TOOL_MODE_MOVE: StringName = &"move"
const TOOL_MODE_STORE: StringName = &"store"

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var fallback_room_is_buildable: bool = true

var _room_map: Node
var _build_mode_enabled: bool = false
var _tool_mode: StringName = TOOL_MODE_PLACE
var _selected_furniture_scene: PackedScene
var _selected_furniture_id: StringName = &""
var _selected_base_footprint: Vector2i = Vector2i(1, 1)
var _selected_rotation_steps: int = 0
var _selected_can_rotate: bool = false


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
		set_tool_mode(TOOL_MODE_PLACE)
	build_mode_changed.emit(_build_mode_enabled)


func toggle_build_mode() -> bool:
	set_build_mode_enabled(not _build_mode_enabled)
	return _build_mode_enabled


func set_tool_mode(tool_mode: StringName) -> void:
	var next_mode := tool_mode
	if next_mode != TOOL_MODE_PLACE and next_mode != TOOL_MODE_MOVE and next_mode != TOOL_MODE_STORE:
		next_mode = TOOL_MODE_PLACE
	if _tool_mode == next_mode:
		return
	_tool_mode = next_mode
	if _tool_mode != TOOL_MODE_PLACE:
		clear_selected_furniture()
	tool_mode_changed.emit(_tool_mode)


func get_tool_mode() -> StringName:
	return _tool_mode


func select_furniture_scene(
	furniture_scene: PackedScene,
	furniture_id: StringName,
	footprint: Vector2i,
	can_rotate: bool = false,
	rotation_steps: int = 0
) -> void:
	set_tool_mode(TOOL_MODE_PLACE)
	_selected_furniture_scene = furniture_scene
	_selected_furniture_id = furniture_id
	_selected_base_footprint = Vector2i(maxi(footprint.x, 1), maxi(footprint.y, 1))
	_selected_can_rotate = can_rotate
	_selected_rotation_steps = _normalize_rotation_steps(rotation_steps)
	furniture_selection_changed.emit(_selected_furniture_scene, _selected_furniture_id, get_selected_footprint())
	furniture_rotation_changed.emit(_selected_rotation_steps, get_selected_footprint())


func clear_selected_furniture() -> void:
	if _selected_furniture_scene == null and _selected_furniture_id == &"":
		return
	_selected_furniture_scene = null
	_selected_furniture_id = &""
	_selected_base_footprint = Vector2i(1, 1)
	_selected_rotation_steps = 0
	_selected_can_rotate = false
	furniture_selection_changed.emit(_selected_furniture_scene, _selected_furniture_id, get_selected_footprint())
	furniture_rotation_changed.emit(_selected_rotation_steps, get_selected_footprint())


func rotate_selected_furniture(clockwise: bool = true) -> void:
	if not _selected_can_rotate:
		return
	var delta := 1 if clockwise else -1
	_selected_rotation_steps = _normalize_rotation_steps(_selected_rotation_steps + delta)
	furniture_rotation_changed.emit(_selected_rotation_steps, get_selected_footprint())


func get_selected_furniture_scene() -> PackedScene:
	return _selected_furniture_scene


func get_selected_furniture_id() -> StringName:
	return _selected_furniture_id


func get_selected_footprint() -> Vector2i:
	return _rotate_footprint(_selected_base_footprint, _selected_rotation_steps)


func get_selected_rotation_steps() -> int:
	return _selected_rotation_steps


func get_selected_rotation_degrees() -> float:
	return float(_selected_rotation_steps) * 90.0


func can_selected_furniture_rotate() -> bool:
	return _selected_can_rotate


func _rotate_footprint(footprint: Vector2i, rotation_steps: int) -> Vector2i:
	var normalized_steps := _normalize_rotation_steps(rotation_steps)
	if normalized_steps == 1 or normalized_steps == 3:
		return Vector2i(footprint.y, footprint.x)
	return footprint


func _normalize_rotation_steps(rotation_steps: int) -> int:
	var steps := rotation_steps % 4
	if steps < 0:
		steps += 4
	return steps


func _resolve_room_map() -> void:
	if _room_map != null:
		return
	if room_map_path.is_empty():
		return
	_room_map = get_node_or_null(room_map_path)
