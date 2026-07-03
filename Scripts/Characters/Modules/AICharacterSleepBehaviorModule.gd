extends Node
class_name AICharacterSleepBehaviorModule

const INVALID_GRID_POSITION := Vector2i(-999999, -999999)
const BUILD_LOCK_META := &"build_locked_by_sleep"
const BUILD_LOCK_REASON_META := &"build_lock_reason"

@export var needs_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterNeedsModule")
@export var need_planner_path: NodePath = NodePath("../AICharacterNeedsBundle/NeedDrivenAIPlanner")
@export var mood_module_path: NodePath = NodePath("../AICharacterNeedsBundle/CharacterMoodModule")
@export var furniture_root_path: NodePath = NodePath("../../RobinRoomMap/FurnitureRoot")
@export var furniture_placement_module_path: NodePath = NodePath("../../FurniturePlacementModule")
@export var room_map_path: NodePath = NodePath("../../RobinRoomMap")
@export var sleep_need_id: StringName = CharacterNeedIds.ENERGY
@export var sleep_action_id: StringName = CharacterNeedActionIds.REST
@export var bedding_ids: Array[StringName] = [&"simple_mattress"]
@export var walk_speed: float = 80.0
@export var arrival_distance: float = 8.0
@export var bedding_sleep_start_distance: float = 14.0
@export var nearby_bedding_sleep_distance: float = 48.0
@export var visual_bedding_overlap_sleep_enabled: bool = true
@export var actor_visual_half_extents: Vector2 = Vector2(35.0, 70.0)
@export var bedding_overlap_margin: float = 4.0
@export var grid_arrival_distance: float = 6.0
@export var wake_ratio: float = 0.98
@export var energy_recovery_per_game_minute: float = 0.31
@export var pause_sleep_need_decay_while_sleeping: bool = true
@export var sleep_request_energy_ratio: float = 0.33
@export var floor_sleep_energy_ratio: float = 0.01
@export var floor_sleep_mood_entry_path: String = "res://Data/Mood/Entries/rough_sleep.tres"
@export var stuck_check_enabled: bool = true
@export var stuck_timeout_seconds: float = 2.0
@export var stuck_position_epsilon: float = 1.0
@export var stuck_sleep_start_distance: float = 24.0
@export var stuck_floor_sleep_enabled: bool = true
@export var snap_to_grid_path_on_stuck: bool = true
@export var use_direct_grid_path_movement: bool = false
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)

var _body: CharacterBody2D
var _needs_module: CharacterNeedsModule
var _need_planner: NeedDrivenAIPlanner
var _mood_module: CharacterMoodModule
var _furniture_root: Node
var _furniture_placement_module: Node
var _room_map: RoomMapGridModule
var _target_bedding: Node2D
var _target_bedding_grid_position: Vector2i = INVALID_GRID_POSITION
var _target_bedding_grid_footprint: Vector2i = Vector2i.ZERO
var _sleeping_bedding: Node2D
var _floor_sleep_mood_entry: CharacterMoodEntryData
var _is_active := false
var _is_sleeping := false
var _is_floor_sleeping := false
var _sleep_need_was_disabled_by_sleep := false
var _facing_direction := Vector2.DOWN
var _last_walk_position := Vector2(INF, INF)
var _stuck_timer := 0.0
var _path_cells: Array[Vector2i] = []
var _path_target_bedding: Node2D
var _path_target_cell: Vector2i = INVALID_GRID_POSITION
var _last_direct_move_target_position: Vector2 = Vector2(INF, INF)


func _ready() -> void:
	add_to_group(&"ai_sleep_behavior")


func setup(body: CharacterBody2D) -> void:
	_body = body
	add_to_group(&"ai_sleep_behavior")
	_resolve_refs()


func is_active() -> bool:
	return _is_active


func is_sleeping() -> bool:
	return _is_sleeping


func is_floor_sleeping() -> bool:
	return _is_floor_sleeping


func is_action_progress_visible() -> bool:
	return _is_active


func get_action_progress_ratio() -> float:
	var safe_wake_ratio := maxf(wake_ratio, 0.01)
	return clampf(_get_energy_ratio() / safe_wake_ratio, 0.0, 1.0)


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_debug_path_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _path_cells:
		result.append(cell)
	return result


func get_debug_target_cell() -> Vector2i:
	return _path_target_cell


func get_debug_next_cell() -> Vector2i:
	if _path_cells.is_empty():
		return INVALID_GRID_POSITION
	return _path_cells[0]


func get_debug_actor_footprint() -> Vector2i:
	return _get_actor_grid_footprint()


func get_debug_last_direct_move_target_position() -> Vector2:
	return _last_direct_move_target_position


func get_debug_movement_summary() -> String:
	return "target_cell=%s next_cell=%s path=%d footprint=%s direct_target=%s" % [
		str(get_debug_target_cell()),
		str(get_debug_next_cell()),
		_path_cells.size(),
		str(get_debug_actor_footprint()),
		str(_last_direct_move_target_position),
	]


func get_velocity(delta: float) -> Vector2:
	_resolve_refs()
	_is_active = false

	if _body == null or _needs_module == null:
		_stop_sleeping()
		return Vector2.ZERO

	if not _should_sleep_now():
		_stop_sleeping()
		return Vector2.ZERO

	if _is_sleeping:
		_is_active = true
		_reset_stuck_watch()
		_recover_energy(delta)
		return Vector2.ZERO

	if _should_floor_sleep_now():
		_start_floor_sleep()
		_recover_energy(delta)
		return Vector2.ZERO

	if not _ensure_bedding_target():
		_stop_sleeping()
		return Vector2.ZERO

	_sync_bedding_path_target_cell()
	var target_cell: Vector2i = _path_target_cell
	if not _is_valid_grid_position(target_cell):
		_stop_sleeping()
		return Vector2.ZERO

	_is_active = true
	var target_position: Vector2 = _get_bedding_sleep_position_from_cell(_target_bedding, target_cell)
	var to_target: Vector2 = target_position - _body.global_position
	var target_distance: float = to_target.length()

	if _can_start_bedding_sleep(target_distance):
		_start_bedding_sleep()
		_recover_energy(delta)
		return Vector2.ZERO

	if use_direct_grid_path_movement and _move_along_grid_path_to_target(target_cell, delta):
		_reset_stuck_watch()
		return Vector2.ZERO

	if _is_stuck_trying_to_reach_bedding(delta):
		if _try_snap_to_sleep_path_cell(target_cell):
			_reset_stuck_watch()
			return Vector2.ZERO
		if target_distance <= stuck_sleep_start_distance or _can_start_bedding_sleep(target_distance):
			_start_bedding_sleep()
		else:
			_handle_stuck_sleep_attempt(target_cell)
		_recover_energy(delta)
		return Vector2.ZERO

	var path_velocity: Vector2 = _get_grid_path_velocity_to_target(target_cell)
	if path_velocity != Vector2.ZERO:
		return path_velocity

	if target_distance > arrival_distance:
		_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
		return _facing_direction * walk_speed

	_start_bedding_sleep()
	_recover_energy(delta)
	return Vector2.ZERO


func _can_start_bedding_sleep(target_distance: float) -> bool:
	if target_distance <= bedding_sleep_start_distance:
		return true
	if _is_close_enough_to_bedding(_target_bedding):
		return true
	if _is_visual_overlapping_bedding(_target_bedding):
		return true
	return false


func _should_sleep_now() -> bool:
	var energy_ratio := _get_energy_ratio()
	if _is_sleeping:
		return energy_ratio < wake_ratio
	if energy_ratio <= sleep_request_energy_ratio:
		return true
	if _need_planner == null:
		return false
	return _need_planner.get_next_action_id() == sleep_action_id


func _should_floor_sleep_now() -> bool:
	return _get_energy_ratio() <= floor_sleep_energy_ratio


func _start_bedding_sleep() -> void:
	var bedding := _target_bedding
	if _body != null and bedding != null:
		_body.global_position = _get_bedding_center_sleep_position(bedding)
	_set_sleeping_bedding(bedding)
	_start_sleeping(false)


func _start_floor_sleep() -> void:
	_set_sleeping_bedding(null)
	_start_sleeping(true)
	_apply_floor_sleep_mood_entry()


func _start_sleeping(floor_sleeping: bool) -> void:
	_is_active = true
	_is_sleeping = true
	_is_floor_sleeping = floor_sleeping
	_clear_bedding_target()
	_facing_direction = Vector2.DOWN
	_reset_stuck_watch()
	_set_sleep_need_decay_enabled(false)


func _recover_energy(delta: float) -> void:
	if _needs_module == null:
		return
	var game_minutes := _get_game_minutes_from_delta(delta)
	if game_minutes <= 0.0:
		return
	_needs_module.add_need_value(sleep_need_id, energy_recovery_per_game_minute * game_minutes)


func _get_game_minutes_from_delta(delta: float) -> float:
	var game_clock := get_node_or_null("/root/GameClock")
	if game_clock != null and game_clock.has_method("get"):
		var seconds_per_minute := float(game_clock.get("real_seconds_per_game_minute"))
		if seconds_per_minute > 0.0:
			return delta / seconds_per_minute
	return delta


func _get_energy_ratio() -> float:
	if _needs_module == null:
		return 0.0
	return _needs_module.get_need_ratio(sleep_need_id, 0.0)


func _ensure_bedding_target() -> bool:
	if _has_valid_bedding_target():
		return true
	_set_bedding_target(_find_nearest_bedding())
	return _target_bedding != null and _is_valid_grid_position(_path_target_cell)


func _has_valid_bedding_target() -> bool:
	if _target_bedding == null:
		return false
	if not is_instance_valid(_target_bedding):
		return false
	if _furniture_root != null and _target_bedding.get_parent() != _furniture_root:
		return false
	if not _is_bedding(_target_bedding):
		return false
	if _get_furniture_grid_position(_target_bedding) != _target_bedding_grid_position:
		return false
	if _get_bedding_footprint(_target_bedding) != _target_bedding_grid_footprint:
		return false
	if _is_valid_grid_position(_path_target_cell):
		if _is_sleep_target_cell_walkable(_path_target_cell, _get_actor_grid_footprint()):
			return true
		if not _is_sleep_target_cell_inside(_path_target_cell, _get_actor_grid_footprint()):
			return false
		return _get_bedding_side_sleep_cell(_target_bedding) == _path_target_cell
	return true


func _set_bedding_target(bedding: Node2D) -> void:
	if bedding == null:
		_clear_bedding_target()
		return
	_target_bedding = bedding
	_target_bedding_grid_position = _get_furniture_grid_position(bedding)
	_target_bedding_grid_footprint = _get_bedding_footprint(bedding)
	_clear_path_target()
	_path_target_bedding = _target_bedding
	_path_target_cell = _get_bedding_side_sleep_cell(_target_bedding)
	_path_cells.clear()


func _clear_bedding_target() -> void:
	_target_bedding = null
	_target_bedding_grid_position = INVALID_GRID_POSITION
	_target_bedding_grid_footprint = Vector2i.ZERO
	_clear_path_target()
	_path_cells.clear()


func _stop_sleeping() -> void:
	_clear_sleeping_bedding_lock()
	_set_sleep_need_decay_enabled(true)
	_is_active = false
	_is_sleeping = false
	_is_floor_sleeping = false
	_clear_bedding_target()
	_reset_stuck_watch()


func _handle_stuck_sleep_attempt(target_cell: Vector2i = INVALID_GRID_POSITION) -> void:
	if _is_valid_grid_position(target_cell):
		_path_cells.clear()
		_reset_stuck_watch()
		return
	if stuck_floor_sleep_enabled:
		_start_floor_sleep()
		return
	_clear_bedding_target()
	_reset_stuck_watch()


func _is_stuck_trying_to_reach_bedding(delta: float) -> bool:
	if not stuck_check_enabled:
		return false
	if _body == null:
		return false
	if _last_walk_position.x == INF or _last_walk_position.y == INF:
		_last_walk_position = _body.global_position
		_stuck_timer = 0.0
		return false

	var moved_distance := _body.global_position.distance_to(_last_walk_position)
	if moved_distance > stuck_position_epsilon:
		_last_walk_position = _body.global_position
		_stuck_timer = 0.0
		return false

	_stuck_timer += delta
	return _stuck_timer >= stuck_timeout_seconds


func _reset_stuck_watch() -> void:
	_last_walk_position = Vector2(INF, INF)
	_stuck_timer = 0.0


func _sync_bedding_path_target_cell() -> void:
	if _target_bedding == null:
		_clear_path_target()
		return
	if _path_target_bedding != _target_bedding:
		_path_target_bedding = _target_bedding
		_path_target_cell = _get_bedding_side_sleep_cell(_target_bedding)
		_path_cells.clear()
		return
	if not _is_valid_grid_position(_path_target_cell):
		_path_target_cell = _get_bedding_side_sleep_cell(_target_bedding)
		_path_cells.clear()


func _clear_path_target() -> void:
	_path_target_bedding = null
	_path_target_cell = INVALID_GRID_POSITION
	_last_direct_move_target_position = Vector2(INF, INF)


func _move_along_grid_path_to_target(target_cell: Vector2i, delta: float) -> bool:
	if _body == null or _room_map == null:
		return false
	if not _is_valid_grid_position(target_cell):
		return false

	if _path_cells.is_empty():
		var start_cell: Vector2i = _get_current_or_nearest_walkable_top_left_cell(false, true)
		if not _is_valid_grid_position(start_cell):
			return false
		if start_cell == target_cell:
			var target_position: Vector2 = _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
			_last_direct_move_target_position = target_position
			_move_body_towards_position(target_position, delta)
			return true
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return false

	var waypoint_cell: Vector2i = _path_cells[0]
	if not _is_sleep_target_cell_inside(waypoint_cell, _get_actor_grid_footprint()):
		_path_cells.clear()
		return false

	var waypoint_position: Vector2 = _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
	_last_direct_move_target_position = waypoint_position
	if _move_body_towards_position(waypoint_position, delta):
		_path_cells.remove_at(0)
	return true


func _move_body_towards_position(target_position: Vector2, delta: float) -> bool:
	if _body == null:
		return false
	var to_target: Vector2 = target_position - _body.global_position
	var distance: float = to_target.length()
	if distance <= grid_arrival_distance:
		_body.global_position = target_position
		_facing_direction = Vector2.DOWN if distance <= 0.001 else AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
		return true

	_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
	var axis_distance: float = absf(to_target.x) if not is_zero_approx(_facing_direction.x) else absf(to_target.y)
	var move_distance: float = minf(walk_speed * maxf(delta, 0.0), axis_distance)
	_body.global_position += _facing_direction * move_distance
	return _body.global_position.distance_to(target_position) <= grid_arrival_distance


func _try_snap_to_sleep_path_cell(target_cell: Vector2i) -> bool:
	if not snap_to_grid_path_on_stuck:
		return false
	if _body == null or _room_map == null:
		return false
	if not _is_valid_grid_position(target_cell):
		return false

	if _path_cells.is_empty():
		var start_cell: Vector2i = _get_current_or_nearest_walkable_top_left_cell(false, true)
		_path_cells = _find_grid_path(start_cell, target_cell)

	if _path_cells.is_empty():
		return false

	var next_cell := _path_cells[0]
	if not _is_sleep_target_cell_inside(next_cell, _get_actor_grid_footprint()):
		_path_cells.clear()
		return false

	_body.global_position = _room_map.grid_to_world_area_center(next_cell, _get_actor_grid_footprint())
	_path_cells.remove_at(0)
	return true


func _set_sleeping_bedding(bedding: Node2D) -> void:
	if _sleeping_bedding == bedding:
		return
	_clear_sleeping_bedding_lock()
	_sleeping_bedding = bedding
	if _sleeping_bedding == null:
		return
	_sleeping_bedding.set_meta(BUILD_LOCK_META, true)
	_sleeping_bedding.set_meta(BUILD_LOCK_REASON_META, "睡眠中")


func _clear_sleeping_bedding_lock() -> void:
	if _sleeping_bedding == null:
		return
	if is_instance_valid(_sleeping_bedding):
		if _sleeping_bedding.has_meta(BUILD_LOCK_META):
			_sleeping_bedding.remove_meta(BUILD_LOCK_META)
		if _sleeping_bedding.has_meta(BUILD_LOCK_REASON_META):
			_sleeping_bedding.remove_meta(BUILD_LOCK_REASON_META)
	_sleeping_bedding = null


func _apply_floor_sleep_mood_entry() -> void:
	if _mood_module == null:
		return
	if _floor_sleep_mood_entry == null:
		_floor_sleep_mood_entry = _load_floor_sleep_mood_entry()
	if _floor_sleep_mood_entry == null:
		return
	_mood_module.add_entry(_floor_sleep_mood_entry)


func _load_floor_sleep_mood_entry() -> CharacterMoodEntryData:
	if floor_sleep_mood_entry_path.is_empty():
		return null
	if not ResourceLoader.exists(floor_sleep_mood_entry_path):
		return null
	var resource := load(floor_sleep_mood_entry_path)
	if resource != null and resource is CharacterMoodEntryData:
		return resource as CharacterMoodEntryData
	return null


func _set_sleep_need_decay_enabled(enabled: bool) -> void:
	if not pause_sleep_need_decay_while_sleeping:
		return
	if _needs_module == null:
		return
	var sleep_need := _needs_module.get_need(sleep_need_id)
	if sleep_need == null:
		return

	if not enabled:
		if not sleep_need.enabled:
			return
		sleep_need.enabled = false
		_sleep_need_was_disabled_by_sleep = true
		return

	if _sleep_need_was_disabled_by_sleep:
		sleep_need.enabled = true
		_sleep_need_was_disabled_by_sleep = false


func _find_nearest_bedding() -> Node2D:
	if _furniture_root == null or _body == null or _room_map == null:
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
		if not _is_bedding(furniture):
			continue
		var sleep_cell: Vector2i = _get_bedding_side_sleep_cell_with_distance_map(furniture, distance_map)
		var score_distance_map := distance_map
		if not _is_valid_grid_position(sleep_cell):
			if fallback_distance_map.is_empty():
				fallback_distance_map = _get_grid_distance_map(start_cell, true)
			sleep_cell = _get_bedding_side_sleep_cell_with_distance_map(furniture, fallback_distance_map, true)
			score_distance_map = fallback_distance_map
		if not _is_valid_grid_position(sleep_cell):
			continue
		var sleep_position := _room_map.grid_to_world_area_center(sleep_cell, _get_actor_grid_footprint())
		var path_score := _get_grid_distance_score(score_distance_map, sleep_cell)
		if path_score < 0.0:
			continue
		var distance_score := _body.global_position.distance_squared_to(sleep_position) / 1000000.0
		var score := path_score + distance_score
		if nearest == null or score < nearest_score:
			nearest = furniture
			nearest_score = score
	return nearest


func _is_bedding(furniture: Node2D) -> bool:
	if furniture == null:
		return false
	if furniture.has_method("is_bedding") and furniture.call("is_bedding") == true:
		return true
	if furniture.has_meta("furniture_id"):
		var meta_id: StringName = furniture.get_meta("furniture_id", &"")
		if bedding_ids.has(meta_id):
			return true
	if _has_property(furniture, &"furniture_id"):
		var property_id: StringName = furniture.get("furniture_id")
		if bedding_ids.has(property_id):
			return true
	return false


func _get_bedding_sleep_position(bedding: Node2D) -> Vector2:
	var sleep_cell: Vector2i = _get_bedding_side_sleep_cell(bedding)
	if _is_valid_grid_position(sleep_cell) and _room_map != null:
		return _get_bedding_sleep_position_from_cell(bedding, sleep_cell)
	return _get_bedding_center_sleep_position(bedding)


func _get_bedding_sleep_position_from_cell(bedding: Node2D, sleep_cell: Vector2i) -> Vector2:
	if _is_valid_grid_position(sleep_cell) and _room_map != null:
		return _room_map.grid_to_world_area_center(sleep_cell, _get_actor_grid_footprint())
	return _get_bedding_center_sleep_position(bedding)


func _get_bedding_center_sleep_position(bedding: Node2D) -> Vector2:
	if bedding == null:
		return Vector2.ZERO
	if bedding.has_method("get_sleep_target_global_position"):
		var target_position: Vector2 = bedding.call("get_sleep_target_global_position")
		return target_position
	return bedding.global_position


func _get_bedding_side_sleep_position(bedding: Node2D) -> Vector2:
	var sleep_cell: Vector2i = _get_bedding_side_sleep_cell(bedding)
	if _is_valid_grid_position(sleep_cell) and _room_map != null:
		return _room_map.grid_to_world_area_center(sleep_cell, _get_actor_grid_footprint())
	return Vector2(INF, INF)


func _get_bedding_side_sleep_cell(bedding: Node2D) -> Vector2i:
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var sleep_cell := _get_bedding_side_sleep_cell_with_distance_map(bedding, _get_grid_distance_map(start_cell))
	if _is_valid_grid_position(sleep_cell):
		return sleep_cell
	return _get_bedding_side_sleep_cell_with_distance_map(bedding, _get_grid_distance_map(start_cell, true), true)


func _get_bedding_side_sleep_cell_with_distance_map(bedding: Node2D, distance_map: Dictionary, allow_occupied: bool = false) -> Vector2i:
	if bedding == null or _room_map == null:
		return INVALID_GRID_POSITION
	if not bedding.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var bedding_cell: Vector2i = bedding.get_meta("grid_position", INVALID_GRID_POSITION)
	if bedding_cell == INVALID_GRID_POSITION:
		return INVALID_GRID_POSITION
	var bedding_footprint := _get_bedding_footprint(bedding)
	var actor_footprint := _get_actor_grid_footprint()
	var candidates := _get_bedding_side_candidate_cells(bedding_cell, bedding_footprint, actor_footprint)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF
	for candidate in candidates:
		if not _is_sleep_target_cell_walkable(candidate, actor_footprint, allow_occupied):
			continue
		var path_score := _get_grid_distance_score(distance_map, candidate)
		if path_score < 0.0:
			continue
		var candidate_position := _room_map.grid_to_world_area_center(candidate, actor_footprint)
		var distance_score := _body.global_position.distance_squared_to(candidate_position) / 1000000.0
		var score := path_score + distance_score
		if nearest_cell == INVALID_GRID_POSITION or score < nearest_score:
			nearest_cell = candidate
			nearest_score = score
	return nearest_cell


func _get_bedding_side_candidate_cells(bedding_cell: Vector2i, bedding_footprint: Vector2i, actor_footprint: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.get_side_candidate_cells(bedding_cell, bedding_footprint, actor_footprint)


func _is_close_enough_to_bedding(bedding: Node2D) -> bool:
	if _body == null or bedding == null:
		return false
	var nearest_position: Vector2 = _get_nearest_point_on_bedding_area(bedding, _body.global_position)
	return _body.global_position.distance_to(nearest_position) <= nearby_bedding_sleep_distance


func _is_visual_overlapping_bedding(bedding: Node2D) -> bool:
	if not visual_bedding_overlap_sleep_enabled:
		return false
	if _body == null or bedding == null or _room_map == null:
		return false
	if not bedding.has_meta("grid_position"):
		return false
	var bedding_cell: Vector2i = bedding.get_meta("grid_position", INVALID_GRID_POSITION)
	if not _is_valid_grid_position(bedding_cell):
		return false
	var bedding_rect: Rect2 = _room_map.get_grid_area_rect(bedding_cell, _get_bedding_footprint(bedding)).grow(bedding_overlap_margin)
	var visual_half_extents := Vector2(maxf(actor_visual_half_extents.x, 1.0), maxf(actor_visual_half_extents.y, 1.0))
	var actor_rect := Rect2(_body.global_position - visual_half_extents, visual_half_extents * 2.0)
	return actor_rect.intersects(bedding_rect)


func _get_nearest_point_on_bedding_area(bedding: Node2D, world_position: Vector2) -> Vector2:
	if bedding == null:
		return world_position
	if _room_map != null and bedding.has_meta("grid_position"):
		var bedding_cell: Vector2i = bedding.get_meta("grid_position", INVALID_GRID_POSITION)
		if _is_valid_grid_position(bedding_cell):
			var bedding_rect: Rect2 = _room_map.get_grid_area_rect(bedding_cell, _get_bedding_footprint(bedding))
			return Vector2(
				clampf(world_position.x, bedding_rect.position.x, bedding_rect.end.x),
				clampf(world_position.y, bedding_rect.position.y, bedding_rect.end.y)
			)
	return bedding.global_position


func _get_grid_path_velocity_to_target(target_cell: Vector2i) -> Vector2:
	if _body == null or _room_map == null:
		return Vector2.ZERO
	if not _is_valid_grid_position(target_cell):
		return Vector2.ZERO

	var start_cell := _get_current_or_nearest_walkable_top_left_cell(true, true)
	if not _is_valid_grid_position(start_cell):
		return Vector2.ZERO

	if start_cell == target_cell:
		_path_cells.clear()
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var to_target := target_position - _body.global_position
		if to_target.length() > grid_arrival_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_target)
			return _facing_direction * walk_speed
		return Vector2.ZERO

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return Vector2.ZERO

	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_sleep_target_cell_inside(waypoint_cell, _get_actor_grid_footprint()):
			_path_cells.clear()
			return Vector2.ZERO

		var waypoint_position := _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrival_distance:
			_facing_direction = AICharacterGridMovementHelper.get_axis_aligned_direction(to_waypoint)
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _get_grid_path_score(start_cell: Vector2i, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(start_cell) or not _is_valid_grid_position(target_cell):
		return -1.0
	if start_cell == target_cell:
		return 0.0
	return _get_grid_distance_score(_get_grid_distance_map(start_cell), target_cell)


func _get_grid_distance_map(start_cell: Vector2i, allow_occupied: bool = false) -> Dictionary:
	var walkable_callable := Callable(self, "_is_sleep_target_cell_walkable")
	if allow_occupied:
		walkable_callable = Callable(self, "_is_sleep_target_cell_inside")
	return AICharacterGridMovementHelper.get_grid_distance_map(
		start_cell,
		_get_actor_grid_footprint(),
		walkable_callable,
		INVALID_GRID_POSITION
	)


func _get_grid_distance_score(distance_map: Dictionary, target_cell: Vector2i) -> float:
	return AICharacterGridMovementHelper.get_grid_distance_score(distance_map, target_cell, INVALID_GRID_POSITION)


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	return AICharacterGridMovementHelper.find_grid_path_with_fallback(
		start_cell,
		target_cell,
		_get_actor_grid_footprint(),
		Callable(self, "_is_sleep_target_cell_walkable"),
		Callable(self, "_is_sleep_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _get_current_or_nearest_walkable_top_left_cell(allow_snap: bool, allow_occupied: bool = false) -> Vector2i:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_sleep_target_cell_walkable(current_cell, _get_actor_grid_footprint()):
		return current_cell
	if allow_occupied and _is_sleep_target_cell_inside(current_cell, _get_actor_grid_footprint()):
		return current_cell

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if allow_snap and _is_valid_grid_position(nearest_cell):
		_body.global_position = _room_map.grid_to_world_area_center(nearest_cell, _get_actor_grid_footprint())
		_path_cells.clear()
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	if _room_map == null or _body == null:
		return INVALID_GRID_POSITION
	return AICharacterGridMovementHelper.get_current_actor_top_left_grid_position(
		_room_map,
		_body.global_position,
		_get_actor_grid_footprint(),
		INVALID_GRID_POSITION
	)


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	if _room_map == null:
		return INVALID_GRID_POSITION
	var nearest_cell := AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_sleep_target_cell_walkable"),
		INVALID_GRID_POSITION
	)
	if _is_valid_grid_position(nearest_cell):
		return nearest_cell
	return AICharacterGridMovementHelper.get_nearest_walkable_top_left_to_world_position(
		_room_map,
		world_position,
		_get_actor_grid_footprint(),
		Callable(self, "_is_sleep_target_cell_inside"),
		INVALID_GRID_POSITION
	)


func _is_sleep_target_cell_walkable(cell: Vector2i, footprint: Vector2i, allow_occupied: bool = false) -> bool:
	if not _is_sleep_target_cell_inside(cell, footprint):
		return false
	if allow_occupied:
		return true
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


func _is_sleep_target_cell_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	return _room_map.is_grid_area_inside(cell, footprint)


func _get_furniture_grid_position(furniture: Node2D) -> Vector2i:
	if furniture == null or not furniture.has_meta("grid_position"):
		return INVALID_GRID_POSITION
	var grid_position: Variant = furniture.get_meta("grid_position", INVALID_GRID_POSITION)
	if grid_position is Vector2i:
		var typed_grid_position: Vector2i = grid_position
		return typed_grid_position
	return INVALID_GRID_POSITION


func _get_bedding_footprint(bedding: Node2D) -> Vector2i:
	if bedding == null:
		return Vector2i(1, 1)
	if bedding.has_method("get_grid_footprint"):
		var method_footprint: Vector2i = bedding.call("get_grid_footprint")
		return Vector2i(maxi(method_footprint.x, 1), maxi(method_footprint.y, 1))
	if bedding.has_meta("grid_footprint"):
		var meta_footprint: Vector2i = bedding.get_meta("grid_footprint", Vector2i(1, 1))
		return Vector2i(maxi(meta_footprint.x, 1), maxi(meta_footprint.y, 1))
	return Vector2i(1, 1)


func _get_actor_grid_footprint() -> Vector2i:
	return AICharacterGridMovementHelper.get_safe_footprint(actor_grid_footprint)


func _grid_key(grid_position: Vector2i) -> String:
	return AICharacterGridMovementHelper.grid_key(grid_position)


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return AICharacterGridMovementHelper.is_valid_grid_position(grid_position, INVALID_GRID_POSITION)


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info in object.get_property_list():
		if not property_info.has("name"):
			continue
		if StringName(property_info["name"]) == property_name:
			return true
	return false


func _resolve_refs() -> void:
	if _body == null:
		_body = get_parent() as CharacterBody2D
	if _needs_module == null and not needs_module_path.is_empty():
		_needs_module = get_node_or_null(needs_module_path) as CharacterNeedsModule
	if _need_planner == null and not need_planner_path.is_empty():
		_need_planner = get_node_or_null(need_planner_path) as NeedDrivenAIPlanner
	if _mood_module == null and not mood_module_path.is_empty():
		_mood_module = get_node_or_null(mood_module_path) as CharacterMoodModule
	if _furniture_root == null and not furniture_root_path.is_empty():
		_furniture_root = get_node_or_null(furniture_root_path)
	if _furniture_placement_module == null and not furniture_placement_module_path.is_empty():
		_furniture_placement_module = get_node_or_null(furniture_placement_module_path)
	if _room_map == null and not room_map_path.is_empty():
		_room_map = get_node_or_null(room_map_path) as RoomMapGridModule
	if _room_map == null and _furniture_root != null:
		_room_map = _furniture_root.get_parent() as RoomMapGridModule
