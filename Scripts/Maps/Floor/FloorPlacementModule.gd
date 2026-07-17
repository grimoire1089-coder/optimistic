extends Node
class_name FloorPlacementModule

const DEFAULT_FLOOR_TEXTURE_PATH := "res://Assets/Maps/Furniture/Floor/Floor_001.png"
const FLOOR_SURFACE_SCRIPT_PATH := "res://Scripts/Maps/Floor/FloorSurfaceNode.gd"

@export var room_map_path: NodePath = NodePath("../RobinRoomMap")
@export var floor_root_path: NodePath = NodePath("../RobinRoomMap/FloorRoot")
@export var floor_texture_path: String = DEFAULT_FLOOR_TEXTURE_PATH
@export var floor_display_name: String = "角丸フロアパネル"
@export var floor_id: StringName = &"floor_001"
@export var floor_footprint: Vector2i = Vector2i(15, 15)
@export var floor_root_name: StringName = &"FloorRoot"
@export var floor_node_name: StringName = &"Floor_001"
@export var floor_root_z_index: int = -10
@export var floor_z_index: int = 0
@export var auto_sync_floor_to_map: bool = true
@export var resolve_interval_seconds: float = 0.25

var _room_map: RoomMapGridModule
var _floor_root: Node2D
var _floor_node: Node2D
var _resolve_timer := 0.0


func _ready() -> void:
	if not is_in_group(&"floor_placement_module"):
		add_to_group(&"floor_placement_module")
	_resolve_refs()
	if auto_sync_floor_to_map:
		_sync_floor_node()
	set_process(_room_map == null or _floor_root == null)


func _process(delta: float) -> void:
	_resolve_timer -= maxf(delta, 0.0)
	if _resolve_timer > 0.0:
		return
	_resolve_timer = maxf(resolve_interval_seconds, 0.05)
	_resolve_refs()
	if auto_sync_floor_to_map:
		_sync_floor_node()
	if _room_map != null and _floor_root != null:
		set_process(false)


func set_room_map_path(next_room_map_path: NodePath) -> void:
	if room_map_path == next_room_map_path:
		_resolve_refs()
		if auto_sync_floor_to_map:
			_sync_floor_node()
		return
	room_map_path = next_room_map_path
	_room_map = null
	_floor_root = null
	_floor_node = null
	_resolve_refs()
	if auto_sync_floor_to_map:
		_sync_floor_node()
	set_process(_room_map == null or _floor_root == null)


func set_floor_root_path(next_floor_root_path: NodePath) -> void:
	if floor_root_path == next_floor_root_path:
		_resolve_refs()
		if auto_sync_floor_to_map:
			_sync_floor_node()
		return
	floor_root_path = next_floor_root_path
	_floor_root = null
	_floor_node = null
	_resolve_refs()
	if auto_sync_floor_to_map:
		_sync_floor_node()
	set_process(_room_map == null or _floor_root == null)


func configure_floor(next_floor_id: StringName, next_display_name: String, next_texture_path: String, next_floor_node_name: StringName = &"", next_floor_footprint: Vector2i = Vector2i.ZERO) -> void:
	floor_id = next_floor_id
	floor_display_name = next_display_name
	floor_texture_path = next_texture_path
	if next_floor_node_name != &"":
		floor_node_name = next_floor_node_name
	if next_floor_footprint.x > 0 and next_floor_footprint.y > 0:
		floor_footprint = next_floor_footprint
	_floor_node = null
	_resolve_refs()
	_sync_floor_node()


func place_floor() -> Node2D:
	_resolve_refs()
	if _room_map == null:
		return null
	_ensure_floor_root()
	if _floor_root == null:
		return null

	_resolve_existing_floor_node()
	if _floor_node == null:
		var existing_floor := _get_first_floor_node()
		if existing_floor != null:
			_floor_node = existing_floor
		else:
			_floor_node = _create_floor_node()
			if _floor_node == null:
				return null
			_floor_root.add_child(_floor_node)

	_sync_floor_node()
	return _floor_node


func remove_floor() -> bool:
	_resolve_refs()
	_resolve_existing_floor_node()
	if _floor_node == null:
		return false
	_floor_node.queue_free()
	_floor_node = null
	return true


func remove_any_floor() -> bool:
	_resolve_refs()
	var floor_node := _get_first_floor_node()
	if floor_node == null:
		return false
	floor_node.queue_free()
	_floor_node = null
	return true


func toggle_floor() -> bool:
	if has_floor():
		remove_floor()
		return false
	return place_floor() != null


func has_floor() -> bool:
	_resolve_refs()
	_resolve_existing_floor_node()
	return _floor_node != null


func has_any_floor() -> bool:
	_resolve_refs()
	return _get_first_floor_node() != null


func get_floor_footprint() -> Vector2i:
	return _get_active_floor_footprint()


func get_floor_texture_path() -> String:
	return floor_texture_path


func _create_floor_node() -> Node2D:
	var floor_script := load(FLOOR_SURFACE_SCRIPT_PATH) as Script
	if floor_script == null:
		return null
	var floor_node := floor_script.new() as Node2D
	if floor_node == null:
		return null
	floor_node.name = String(floor_node_name)
	floor_node.z_as_relative = true
	floor_node.z_index = floor_z_index
	floor_node.set_meta("floor_id", floor_id)
	_set_property_if_exists(floor_node, &"display_name", floor_display_name)
	_set_property_if_exists(floor_node, &"floor_id", floor_id)
	_set_property_if_exists(floor_node, &"texture_path", floor_texture_path)
	_set_property_if_exists(floor_node, &"grid_footprint", _get_active_floor_footprint())
	if _room_map != null:
		_set_property_if_exists(floor_node, &"cell_size", _room_map.get_cell_size())
	return floor_node


func _sync_floor_node() -> void:
	_resolve_existing_floor_node()
	if _floor_node == null or _room_map == null:
		return

	var footprint := _get_active_floor_footprint()
	_floor_node.name = String(floor_node_name)
	_floor_node.z_index = floor_z_index
	_floor_node.set_meta("floor_id", floor_id)
	_set_property_if_exists(_floor_node, &"display_name", floor_display_name)
	_set_property_if_exists(_floor_node, &"floor_id", floor_id)
	_set_property_if_exists(_floor_node, &"texture_path", floor_texture_path)
	if _floor_node.has_method("set_texture_path"):
		_floor_node.call("set_texture_path", floor_texture_path)
	if _floor_node.has_method("set_grid_footprint"):
		_floor_node.call("set_grid_footprint", footprint)
	else:
		_set_property_if_exists(_floor_node, &"grid_footprint", footprint)
	if _floor_node.has_method("set_grid_cell_size"):
		_floor_node.call("set_grid_cell_size", _room_map.get_cell_size())
	else:
		_set_property_if_exists(_floor_node, &"cell_size", _room_map.get_cell_size())
	_floor_node.global_position = _room_map.grid_to_world_area_center(Vector2i.ZERO, footprint)


func _get_active_floor_footprint() -> Vector2i:
	if _room_map != null and _room_map.has_method("get_grid_size"):
		var map_grid_size: Vector2i = _room_map.get_grid_size()
		if map_grid_size.x > 0 and map_grid_size.y > 0:
			return map_grid_size
	return Vector2i(maxi(floor_footprint.x, 1), maxi(floor_footprint.y, 1))


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _floor_root == null:
		_ensure_floor_root()
	_resolve_existing_floor_node()


func _ensure_floor_root() -> void:
	if _floor_root != null:
		return
	if not floor_root_path.is_empty():
		_floor_root = get_node_or_null(floor_root_path) as Node2D
		if _floor_root != null:
			return
	if _room_map == null:
		return
	_floor_root = _room_map.get_node_or_null(String(floor_root_name)) as Node2D
	if _floor_root != null:
		return
	_floor_root = Node2D.new()
	_floor_root.name = String(floor_root_name)
	_floor_root.z_as_relative = true
	_floor_root.z_index = floor_root_z_index
	_room_map.add_child(_floor_root)


func _resolve_existing_floor_node() -> void:
	if _floor_node != null and is_instance_valid(_floor_node) and not _floor_node.is_queued_for_deletion():
		return
	_floor_node = null
	if _floor_root == null:
		return
	var named_floor := _floor_root.get_node_or_null(String(floor_node_name)) as Node2D
	if named_floor != null and not named_floor.is_queued_for_deletion():
		_floor_node = named_floor


func _get_first_floor_node() -> Node2D:
	if _floor_root == null:
		return null
	for child in _floor_root.get_children():
		var floor_candidate: Node2D = child as Node2D
		if floor_candidate == null or floor_candidate.is_queued_for_deletion():
			continue
		if floor_candidate.has_meta("floor_id"):
			return floor_candidate
		if String(floor_candidate.name).begins_with("Floor_"):
			return floor_candidate
	return null


func _set_property_if_exists(object: Object, property_name: StringName, value: Variant) -> void:
	if object == null:
		return
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			object.set(String(property_name), value)
			return
