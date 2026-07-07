extends RobinRandomWanderModule
class_name AICharacterRandomWanderModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

@export var ai_actor_group_name: StringName = &"ai_character_actor"
@export var use_shared_move_slot: bool = true
@export var avoid_ai_character_grids: bool = true
@export var keep_step_target_to_one_grid: bool = true


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


func _update_grid_step_movement(delta: float) -> void:
	if not keep_step_target_to_one_grid:
		super._update_grid_step_movement(delta)
		return

	while true:
		if _grid_step_active:
			_grid_step_elapsed += maxf(delta, 0.0)
			var ratio := 1.0
			if _grid_step_duration > 0.0:
				ratio = clampf(_grid_step_elapsed / _grid_step_duration, 0.0, 1.0)
			_body.global_position = _grid_step_start_position.lerp(_grid_step_target_position, ratio)
			if ratio < 1.0:
				return
			_body.global_position = _grid_step_target_position
			_grid_step_active = false
			if not _path_cells.is_empty():
				var completed_waypoint_position := _get_actor_grid_area_center(_path_cells[0])
				if _body.global_position.distance_squared_to(completed_waypoint_position) <= 0.001:
					_path_cells.remove_at(0)
			if _path_cells.is_empty():
				_start_idle()
			return

		if _path_cells.is_empty():
			_start_idle()
			return

		var waypoint_cell := _path_cells[0]
		if not _is_actor_grid_area_inside(waypoint_cell):
			_pick_next_action()
			return

		var waypoint_position := _get_actor_grid_area_center(waypoint_cell)
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length_squared() <= 0.001:
			_body.global_position = waypoint_position
			_path_cells.remove_at(0)
			continue

		var step_target := _get_one_grid_step_target(_body.global_position, waypoint_position)
		var to_step_target := step_target - _body.global_position
		_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_step_target)
		_grid_step_start_position = _body.global_position
		_grid_step_target_position = step_target
		_grid_step_elapsed = 0.0
		_grid_step_duration = maxf(to_step_target.length() / maxf(walk_speed, 1.0), 0.01)
		_grid_step_active = true
		continue


func _get_one_grid_step_target(current_position: Vector2, waypoint_position: Vector2) -> Vector2:
	var room_map := _get_room_map()
	if room_map == null:
		return AICharacterGridMovementHelper.get_axis_aligned_step_target(current_position, waypoint_position)
	var cell_size := room_map.get_cell_size()
	var to_waypoint := waypoint_position - current_position
	var direction := AICharacterGridMovementHelper.get_axis_aligned_direction(to_waypoint)
	if not is_zero_approx(direction.x):
		var step_x := minf(absf(to_waypoint.x), cell_size.x) * signf(to_waypoint.x)
		return Vector2(current_position.x + step_x, current_position.y)
	if not is_zero_approx(direction.y):
		var step_y := minf(absf(to_waypoint.y), cell_size.y) * signf(to_waypoint.y)
		return Vector2(current_position.x, current_position.y + step_y)
	return waypoint_position


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
