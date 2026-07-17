extends AICharacterSitBehaviorModule
class_name AICharacterReservedSitBehaviorModule

const MoveSlot := preload("res://Scripts/Characters/Modules/AICharacterMovementCoordinator.gd")

const SEAT_RESERVED_BY_META := &"ai_seat_reserved_by"
const SEAT_RESERVED_NAME_META := &"ai_seat_reserved_name"
const SEAT_RESERVED_REASON_META := &"ai_seat_reserved_reason"

@export var safe_leave_retry_seconds: float = 2.0
@export var action_runner_ai_actor_group_name: StringName = &"ai_character_actor"
@export var action_runner_use_shared_move_slot: bool = true

var _action_runner_controlled := false
var _action_runner_start_requested := false


func _exit_tree() -> void:
	_action_runner_start_requested = false
	cancel_sitting()
	_release_action_runner_move_slot()


func update_action_runner_idle(delta: float) -> void:
	if _action_runner_controlled:
		return
	_tick_retry_cooldown(delta)


func can_start_action_runner_sit() -> bool:
	_resolve_refs()
	if _body == null or not is_instance_valid(_body):
		_action_runner_start_requested = false
		return false
	if _action_runner_start_requested:
		return true
	if _action_runner_controlled or _active or _has_lapis_action_commitment():
		_action_runner_start_requested = true
		return true
	if _retry_cooldown > 0.0:
		return false
	var planned_action := _get_planned_action_id()
	if planned_action == play_action_id:
		_action_runner_start_requested = true
		return true
	if planned_action != idle_action_id:
		return false
	_action_runner_start_requested = _rng.randf() <= clampf(idle_lapis_chance, 0.0, 1.0)
	return _action_runner_start_requested


func get_action_runner_sit_score() -> float:
	if _action_runner_start_requested or _active or _has_lapis_action_commitment():
		return 100.0
	var planned_action := _get_planned_action_id()
	if planned_action == play_action_id:
		return 80.0
	if planned_action == idle_action_id:
		return 10.0
	return -INF


func start_action_runner_sit() -> bool:
	if _body == null or not is_instance_valid(_body):
		_action_runner_start_requested = false
		return false
	_action_runner_start_requested = false
	_action_runner_controlled = true
	_retry_cooldown = 0.0
	return true


func tick_action_runner_sit(delta: float) -> AICharacterActionResult:
	var next_velocity := get_velocity(delta)
	if not is_active():
		_release_action_runner_move_slot()
		return AICharacterActionResult.completed("sit action finished")
	if next_velocity.length_squared() <= 0.0:
		_release_action_runner_move_slot()
		return AICharacterActionResult.running()
	if not _can_action_runner_move_now():
		return AICharacterActionResult.moving(Vector2.ZERO, get_facing_direction())
	return AICharacterActionResult.moving(next_velocity, get_facing_direction())


func cancel_action_runner_sit() -> void:
	_action_runner_start_requested = false
	cancel_sitting()
	_release_action_runner_move_slot()


func cleanup_action_runner_sit() -> void:
	if _action_runner_controlled and is_active():
		cancel_sitting()
	_action_runner_controlled = false
	_action_runner_start_requested = false
	_release_action_runner_move_slot()


func get_action_runner_sit_debug_summary() -> String:
	return "sit runner_controlled=%s requested=%s cooldown=%.2f %s" % [
		str(_action_runner_controlled),
		str(_action_runner_start_requested),
		_retry_cooldown,
		get_debug_movement_summary(),
	]


func _should_start_lapis_now(action_id: StringName) -> bool:
	if _action_runner_controlled:
		return _is_lapis_relevant_action(action_id)
	return super._should_start_lapis_now(action_id)


func _can_action_runner_move_now() -> bool:
	if _body == null:
		return false
	if not action_runner_use_shared_move_slot:
		return true
	if MoveSlot.can_move(_body):
		return MoveSlot.request_move(_body)
	if MoveSlot.is_other_actor_moving(_body, action_runner_ai_actor_group_name):
		return false
	return MoveSlot.request_move(_body)


func _release_action_runner_move_slot() -> void:
	if _body == null or not action_runner_use_shared_move_slot:
		return
	MoveSlot.release_move(_body)


func _find_nearest_stool() -> Node2D:
	if _furniture_root == null or _body == null:
		return null

	var nearest: Node2D = null
	var nearest_score := INF
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var distance_map := _get_grid_distance_map(start_cell)
	var fallback_distance_map: Dictionary = {}
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_stool(furniture):
			continue
		if not _is_stool_available_for_actor(furniture):
			continue
		var use_cell := _get_stool_use_cell_with_distance_map(furniture, distance_map)
		var score_distance_map := distance_map
		if not _is_valid_grid_position(use_cell):
			if fallback_distance_map.is_empty():
				fallback_distance_map = _get_grid_distance_map(start_cell, true)
			use_cell = _get_stool_use_cell_with_distance_map(furniture, fallback_distance_map, true)
			score_distance_map = fallback_distance_map
		if not _is_valid_grid_position(use_cell):
			continue
		var use_position := _get_stool_use_position(use_cell)
		var path_score := _get_grid_distance_score(score_distance_map, use_cell)
		if path_score < 0.0:
			continue
		var distance_score := _body.global_position.distance_squared_to(use_position) / 1000000.0
		var score := path_score + distance_score
		if nearest == null or score < nearest_score:
			nearest = furniture
			nearest_score = score
	return nearest


func _has_valid_target_stool() -> bool:
	if not super._has_valid_target_stool():
		return false
	return _is_stool_available_for_actor(_target_stool)


func _update_sitting(delta: float) -> void:
	_face_stool()
	_recover_fun(delta)
	_sit_timer -= maxf(delta, 0.0)
	if _sit_timer > 0.0:
		return
	if _try_leave_seat_safely():
		_reset()
		_start_retry_cooldown()
		return
	_sit_timer = maxf(safe_leave_retry_seconds, 0.5)


func _try_leave_seat_safely() -> bool:
	if _body == null:
		return false
	var leave_cell := _target_cell
	var footprint := _get_actor_grid_footprint()
	if not _is_valid_grid_position(leave_cell):
		return false
	if not _is_target_cell_walkable(leave_cell, footprint):
		return false
	_body.global_position = _get_stool_use_position(leave_cell)
	_path_cells.clear()
	return true


func _set_target_stool(stool: Node2D) -> void:
	if _target_stool != stool:
		_clear_reserved_stool(_target_stool)
	super._set_target_stool(stool)
	_reserve_target_stool()


func _clear_target() -> void:
	_clear_reserved_stool(_target_stool)
	super._clear_target()


func _set_sitting_stool(stool: Node2D) -> void:
	super._set_sitting_stool(stool)
	_clear_reserved_stool(stool)


func _is_stool_available_for_actor(stool: Node2D) -> bool:
	if stool == null:
		return false
	if stool.has_meta(BUILD_LOCK_META) and stool != _sitting_stool:
		return false
	if not stool.has_meta(SEAT_RESERVED_BY_META):
		return true
	var reserved_by := int(stool.get_meta(SEAT_RESERVED_BY_META, 0))
	return reserved_by == get_instance_id()


func _reserve_target_stool() -> void:
	if _target_stool == null or not is_instance_valid(_target_stool):
		return
	_target_stool.set_meta(SEAT_RESERVED_BY_META, get_instance_id())
	_target_stool.set_meta(SEAT_RESERVED_NAME_META, _body.name if _body != null else name)
	_target_stool.set_meta(SEAT_RESERVED_REASON_META, "SittingTarget")


func _clear_reserved_stool(stool: Node2D) -> void:
	if stool == null or not is_instance_valid(stool):
		return
	if not stool.has_meta(SEAT_RESERVED_BY_META):
		return
	var reserved_by := int(stool.get_meta(SEAT_RESERVED_BY_META, 0))
	if reserved_by != get_instance_id():
		return
	stool.remove_meta(SEAT_RESERVED_BY_META)
	if stool.has_meta(SEAT_RESERVED_NAME_META):
		stool.remove_meta(SEAT_RESERVED_NAME_META)
	if stool.has_meta(SEAT_RESERVED_REASON_META):
		stool.remove_meta(SEAT_RESERVED_REASON_META)
