extends Node
class_name AICharacterDepthSortModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)

@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)
@export var update_interval_seconds: float = 0.08
@export var z_offset: int = 0
@export var fallback_to_world_y: bool = true

var _actor: Node2D
var _room_map: RoomMapGridModule
var _update_timer := 0.0


func _ready() -> void:
	_actor = get_parent() as Node2D
	_resolve_refs()
	_update_actor_z_index()
	set_process(true)


func setup(actor: Node2D) -> void:
	_actor = actor
	_resolve_refs()
	_update_actor_z_index()


func _process(delta: float) -> void:
	_update_timer -= maxf(delta, 0.0)
	if _update_timer > 0.0:
		return
	_update_timer = maxf(update_interval_seconds, 0.03)
	_resolve_refs()
	_update_actor_z_index()


func _update_actor_z_index() -> void:
	if _actor == null:
		return
	var next_z_index := _get_depth_z_index()
	_actor.z_as_relative = true
	if _actor.z_index == next_z_index:
		return
	_actor.z_index = next_z_index


func _get_depth_z_index() -> int:
	if _actor == null:
		return 0
	if _room_map != null:
		var footprint := AICharacterGridMovementHelper.get_safe_footprint(actor_grid_footprint)
		var top_left := AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
			_room_map,
			_actor.global_position,
			footprint,
			INVALID_GRID_POSITION
		)
		if AICharacterGridMovementHelper.is_valid_grid_position(top_left, INVALID_GRID_POSITION):
			if _room_map.is_grid_area_inside(top_left, footprint):
				var rect := _room_map.get_grid_area_rect(top_left, footprint)
				return int(round(rect.end.y)) + z_offset
	if fallback_to_world_y:
		return int(round(_actor.global_position.y)) + z_offset
	return z_offset


func _resolve_refs() -> void:
	if _actor == null:
		_actor = get_parent() as Node2D
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
