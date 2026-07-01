extends Node
class_name AICharacterEntranceTravelBehaviorModule

signal travel_completed(target_map_id: StringName)

@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var map_travel_module_path: NodePath = NodePath("../../MainSceneMapTravelModule")
@export var walk_speed: float = 80.0
@export var arrive_distance: float = 14.0
@export var use_offset_cells: Vector2i = Vector2i(0, -4)
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var use_time_seconds: float = 0.45

var _body: CharacterBody2D
var _room_map: RoomMapGridModule
var _map_travel_module: Node
var _target_entrance: Node2D
var _target_map_id: StringName = &""
var _active := false
var _using := false
var _use_timer := 0.0
var _facing_direction := Vector2.DOWN


func setup(body: CharacterBody2D) -> void:
	_body = body
	_resolve_refs()


func is_active() -> bool:
	return _active


func get_facing_direction() -> Vector2:
	return _facing_direction


func request_travel_to_entrance(entrance: Node2D, target_map_id: StringName) -> bool:
	_resolve_refs()
	if _active:
		return false
	if _body == null or entrance == null or target_map_id == &"":
		return false
	var entrance_map := _get_room_map_for_entrance(entrance)
	if entrance_map != null:
		_room_map = entrance_map
	if _room_map == null:
		return false
	_target_entrance = entrance
	_target_map_id = target_map_id
	_active = true
	_using = false
	_use_timer = 0.0
	return true


func cancel_travel() -> void:
	_reset()


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	if not _active:
		return Vector2.ZERO
	if _body == null or _room_map == null or _target_entrance == null or not is_instance_valid(_target_entrance):
		_reset()
		return Vector2.ZERO

	if _using:
		_tick_use(delta)
		return Vector2.ZERO

	var use_position := _get_entrance_use_position(_target_entrance)
	var to_target := use_position - _body.global_position
	if to_target.length() <= arrive_distance:
		_start_use()
		return Vector2.ZERO
	_facing_direction = to_target.normalized()
	return _facing_direction * walk_speed


func _start_use() -> void:
	_using = true
	_use_timer = 0.0
	_face_entrance()


func _tick_use(delta: float) -> void:
	_face_entrance()
	_use_timer += maxf(delta, 0.0)
	if _use_timer < maxf(use_time_seconds, 0.01):
		return
	var completed_target_map_id := _target_map_id
	_reset()
	_perform_map_travel(completed_target_map_id)
	travel_completed.emit(completed_target_map_id)


func _perform_map_travel(target_map_id: StringName) -> void:
	_resolve_refs()
	if _map_travel_module == null:
		return
	if _map_travel_module.has_method("travel_to_map"):
		_map_travel_module.call("travel_to_map", target_map_id)


func _get_entrance_use_position(entrance: Node2D) -> Vector2:
	if entrance == null:
		return Vector2.ZERO
	if _room_map == null or not entrance.has_meta("grid_position"):
		return entrance.global_position
	var entrance_cell: Vector2i = entrance.get_meta("grid_position", Vector2i.ZERO)
	var actor_footprint := _get_actor_grid_footprint()
	var use_cell := entrance_cell + use_offset_cells
	var grid_size := _room_map.get_grid_size()
	use_cell.x = clampi(use_cell.x, 0, maxi(grid_size.x - actor_footprint.x, 0))
	use_cell.y = clampi(use_cell.y, 0, maxi(grid_size.y - actor_footprint.y, 0))
	return _room_map.grid_to_world_area_center(use_cell, actor_footprint)


func _get_room_map_for_entrance(entrance: Node2D) -> RoomMapGridModule:
	var node := entrance.get_parent()
	while node != null:
		if node is RoomMapGridModule:
			return node as RoomMapGridModule
		node = node.get_parent()
	return null


func _face_entrance() -> void:
	if _body == null or _target_entrance == null or not is_instance_valid(_target_entrance):
		return
	var to_entrance := _target_entrance.global_position - _body.global_position
	if to_entrance.length_squared() > 0.001:
		_facing_direction = to_entrance.normalized()


func _get_actor_grid_footprint() -> Vector2i:
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _reset() -> void:
	_target_entrance = null
	_target_map_id = &""
	_active = false
	_using = false
	_use_timer = 0.0


func _resolve_refs() -> void:
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _map_travel_module == null and not map_travel_module_path.is_empty():
		_map_travel_module = get_node_or_null(map_travel_module_path)
