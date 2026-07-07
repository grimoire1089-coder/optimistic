extends RobinRandomWanderModule
class_name AICharacterRandomWanderModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

@export var ai_actor_group_name: StringName = &"ai_character_actor"
@export var use_shared_move_slot: bool = true
@export var avoid_ai_character_grids: bool = true
@export var limit_path_to_one_grid_step: bool = true


func setup(body: Node2D) -> void:
	super.setup(body)
	if _body != null and not _body.is_in_group(ai_actor_group_name):
		_body.add_to_group(ai_actor_group_name)


func get_velocity(delta: float) -> Vector2:
	if _body == null:
		return Vector2.ZERO
	if use_shared_move_slot and not _can_step_now():
		if not is_moving():
			_start_idle()
		return Vector2.ZERO
	var next_velocity := super.get_velocity(delta)
	if use_shared_move_slot and not is_moving():
		MoveSlot.release_move(_body)
	return next_velocity


func _can_step_now() -> bool:
	if _body == null:
		return false
	if MoveSlot.can_move(_body) and is_moving():
		return MoveSlot.request_move(_body)
	if MoveSlot.is_other_actor_moving(_body, ai_actor_group_name):
		return false
	return MoveSlot.request_move(_body)


func _pick_random_walkable_top_left_excluding(excluded_cell: Vector2i) -> Vector2i:
	if not limit_path_to_one_grid_step:
		return super._pick_random_walkable_top_left_excluding(excluded_cell)
	var candidates: Array[Vector2i] = []
	for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		var candidate := excluded_cell + direction
		if _is_actor_grid_area_walkable(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return INVALID_GRID_POSITION
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _get_all_walkable_top_left_cells() -> Array[Vector2i]:
	if not avoid_ai_character_grids:
		return super._get_all_walkable_top_left_cells()
	var cells: Array[Vector2i] = []
	var room_map := _get_room_map()
	if room_map == null:
		return cells
	return AICharacterGridMovementHelper.get_all_walkable_top_left_cells(
		room_map,
		_get_safe_actor_grid_footprint(),
		Callable(self, "_is_actor_grid_area_walkable")
	)


func _is_actor_grid_area_walkable(top_left_cell: Vector2i, footprint_override: Vector2i = Vector2i.ZERO) -> bool:
	if not super._is_actor_grid_area_walkable(top_left_cell, footprint_override):
		return false
	if not avoid_ai_character_grids:
		return true
	return not _has_other_ai_in_grid_area(top_left_cell, _get_effective_footprint(footprint_override))


func _get_effective_footprint(footprint_override: Vector2i) -> Vector2i:
	if footprint_override.x > 0 and footprint_override.y > 0:
		return AICharacterGridMovementHelper.get_safe_footprint(footprint_override)
	return _get_safe_actor_grid_footprint()


func _has_other_ai_in_grid_area(top_left_cell: Vector2i, footprint: Vector2i) -> bool:
	if _body == null or _body.get_tree() == null:
		return false
	var room_map := _get_room_map()
	if room_map == null:
		return false
	var other_footprint := _get_safe_actor_grid_footprint()
	for actor in _body.get_tree().get_nodes_in_group(ai_actor_group_name):
		var other_actor := actor as Node2D
		if other_actor == null or other_actor == _body:
			continue
		var other_top_left := AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
			room_map,
			other_actor.global_position,
			other_footprint,
			INVALID_GRID_POSITION
		)
		if not _is_valid_grid_position(other_top_left):
			continue
		if _grid_areas_overlap(top_left_cell, footprint, other_top_left, other_footprint):
			return true
	return false


func _grid_areas_overlap(a_top_left: Vector2i, a_footprint: Vector2i, b_top_left: Vector2i, b_footprint: Vector2i) -> bool:
	return (
		a_top_left.x < b_top_left.x + b_footprint.x
		and a_top_left.x + a_footprint.x > b_top_left.x
		and a_top_left.y < b_top_left.y + b_footprint.y
		and a_top_left.y + a_footprint.y > b_top_left.y
	)
