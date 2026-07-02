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
@export var actor_grid_footprint: Vector2i = Vector2i(2, 4)

var _body: CharacterBody2D
var _needs_module: CharacterNeedsModule
var _need_planner: NeedDrivenAIPlanner
var _mood_module: CharacterMoodModule
var _furniture_root: Node
var _furniture_placement_module: Node
var _room_map: RoomMapGridModule
var _target_bedding: Node2D
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


func setup(body: CharacterBody2D) -> void:
	_body = body
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

	_target_bedding = _find_nearest_bedding()
	if _target_bedding == null:
		_stop_sleeping()
		return Vector2.ZERO

	_is_active = true
	var target_cell: Vector2i = _get_bedding_side_sleep_cell(_target_bedding)
	var target_position := _get_bedding_sleep_position(_target_bedding)
	var to_target := target_position - _body.global_position
	var target_distance := to_target.length()

	if target_distance <= bedding_sleep_start_distance:
		_start_bedding_sleep()
		_recover_energy(delta)
		return Vector2.ZERO

	if _is_stuck_trying_to_reach_bedding(delta):
		if _try_snap_to_sleep_path_cell(target_cell):
			_reset_stuck_watch()
			return Vector2.ZERO
		if target_distance <= stuck_sleep_start_distance:
			_start_bedding_sleep()
		else:
			_handle_stuck_sleep_attempt(target_cell)
		_recover_energy(delta)
		return Vector2.ZERO

	var path_velocity := _get_grid_path_velocity_to_target(target_cell)
	if path_velocity != Vector2.ZERO:
		return path_velocity

	if target_distance > arrival_distance:
		_facing_direction = to_target.normalized()
		return _facing_direction * walk_speed

	_start_bedding_sleep()
	_recover_energy(delta)
	return Vector2.ZERO


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
	_target_bedding = null
	_facing_direction = Vector2.DOWN
	_path_cells.clear()
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


func _stop_sleeping() -> void:
	_clear_sleeping_bedding_lock()
	_set_sleep_need_decay_enabled(true)
	_is_active = false
	_is_sleeping = false
	_is_floor_sleeping = false
	_target_bedding = null
	_path_cells.clear()
	_reset_stuck_watch()


func _handle_stuck_sleep_attempt(target_cell: Vector2i = INVALID_GRID_POSITION) -> void:
	if _is_valid_grid_position(target_cell):
		_path_cells.clear()
		_reset_stuck_watch()
		return
	if stuck_floor_sleep_enabled:
		_start_floor_sleep()
		return
	_target_bedding = null
	_path_cells.clear()
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


func _try_snap_to_sleep_path_cell(target_cell: Vector2i) -> bool:
	if not snap_to_grid_path_on_stuck:
		return false
	if _body == null or _room_map == null:
		return false
	if not _is_valid_grid_position(target_cell):
		return false

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
		_path_cells = _find_grid_path(start_cell, target_cell)

	if _path_cells.is_empty():
		return false

	var next_cell := _path_cells[0]
	if not _is_sleep_target_cell_walkable(next_cell, _get_actor_grid_footprint()):
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
	if _furniture_root == null:
		return null

	var nearest: Node2D = null
	var nearest_distance := INF
	for child in _furniture_root.get_children():
		var furniture := child as Node2D
		if furniture == null:
			continue
		if not _is_bedding(furniture):
			continue
		var sleep_cell: Vector2i = _get_bedding_side_sleep_cell(furniture)
		if not _is_valid_grid_position(sleep_cell):
			continue
		var sleep_position := _room_map.grid_to_world_area_center(sleep_cell, _get_actor_grid_footprint())
		var distance := _body.global_position.distance_squared_to(sleep_position)
		if nearest == null or distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
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
	var side_position := _get_bedding_side_sleep_position(bedding)
	if side_position.x != INF and side_position.y != INF:
		return side_position
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
	var start_cell := _get_current_or_nearest_walkable_top_left_cell(false)
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_score := INF
	for candidate in candidates:
		if not _is_sleep_target_cell_walkable(candidate, actor_footprint):
			continue
		var path_score := _get_grid_path_score(start_cell, candidate)
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
	var candidates: Array[Vector2i] = []
	var min_y := bedding_cell.y - actor_footprint.y + 1
	var max_y := bedding_cell.y + bedding_footprint.y - 1
	for y in range(min_y, max_y + 1):
		candidates.append(Vector2i(bedding_cell.x - actor_footprint.x, y))
		candidates.append(Vector2i(bedding_cell.x + bedding_footprint.x, y))

	var min_x := bedding_cell.x - actor_footprint.x + 1
	var max_x := bedding_cell.x + bedding_footprint.x - 1
	for x in range(min_x, max_x + 1):
		candidates.append(Vector2i(x, bedding_cell.y - actor_footprint.y))
		candidates.append(Vector2i(x, bedding_cell.y + bedding_footprint.y))
	return candidates


func _get_grid_path_velocity_to_target(target_cell: Vector2i) -> Vector2:
	if _body == null or _room_map == null:
		return Vector2.ZERO
	if not _is_valid_grid_position(target_cell):
		return Vector2.ZERO

	var start_cell := _get_current_or_nearest_walkable_top_left_cell(true)
	if not _is_valid_grid_position(start_cell):
		return Vector2.ZERO

	if start_cell == target_cell:
		_path_cells.clear()
		var target_position := _room_map.grid_to_world_area_center(target_cell, _get_actor_grid_footprint())
		var to_target := target_position - _body.global_position
		if to_target.length() > grid_arrival_distance:
			_facing_direction = to_target.normalized()
			return _facing_direction * walk_speed
		return Vector2.ZERO

	if _path_cells.is_empty() or _path_cells[_path_cells.size() - 1] != target_cell:
		_path_cells = _find_grid_path(start_cell, target_cell)
		if _path_cells.is_empty():
			return Vector2.ZERO

	while not _path_cells.is_empty():
		var waypoint_cell := _path_cells[0]
		if not _is_sleep_target_cell_walkable(waypoint_cell, _get_actor_grid_footprint()):
			_path_cells.clear()
			return Vector2.ZERO

		var waypoint_position := _room_map.grid_to_world_area_center(waypoint_cell, _get_actor_grid_footprint())
		var to_waypoint := waypoint_position - _body.global_position
		if to_waypoint.length() > grid_arrival_distance:
			_facing_direction = to_waypoint.normalized()
			return _facing_direction * walk_speed

		_body.global_position = waypoint_position
		_path_cells.remove_at(0)

	return Vector2.ZERO


func _get_grid_path_score(start_cell: Vector2i, target_cell: Vector2i) -> float:
	if not _is_valid_grid_position(start_cell) or not _is_valid_grid_position(target_cell):
		return -1.0
	if start_cell == target_cell:
		return 0.0
	var path := _find_grid_path(start_cell, target_cell)
	if path.is_empty():
		return -1.0
	return float(path.size())


func _find_grid_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var footprint := _get_actor_grid_footprint()
	if start_cell == target_cell:
		return path
	if not _is_sleep_target_cell_walkable(start_cell, footprint) or not _is_sleep_target_cell_walkable(target_cell, footprint):
		return path

	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	came_from[_grid_key(start_cell)] = INVALID_GRID_POSITION
	var read_index := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

	while read_index < frontier.size():
		var current := frontier[read_index]
		read_index += 1

		if current == target_cell:
			break

		for step in steps:
			var next_cell := current + step
			var next_key := _grid_key(next_cell)
			if came_from.has(next_key):
				continue
			if not _is_sleep_target_cell_walkable(next_cell, footprint):
				continue
			came_from[next_key] = current
			frontier.append(next_cell)

	var target_key := _grid_key(target_cell)
	if not came_from.has(target_key):
		return path

	var trace_cell := target_cell
	while trace_cell != start_cell:
		path.insert(0, trace_cell)
		trace_cell = came_from[_grid_key(trace_cell)] as Vector2i

	return path


func _get_current_or_nearest_walkable_top_left_cell(allow_snap: bool) -> Vector2i:
	var current_cell := _get_current_actor_top_left_grid_position()
	if _is_sleep_target_cell_walkable(current_cell, _get_actor_grid_footprint()):
		return current_cell

	var nearest_cell := _get_nearest_walkable_top_left_to_world_position(_body.global_position)
	if allow_snap and _is_valid_grid_position(nearest_cell):
		_body.global_position = _room_map.grid_to_world_area_center(nearest_cell, _get_actor_grid_footprint())
		_path_cells.clear()
	return nearest_cell


func _get_current_actor_top_left_grid_position() -> Vector2i:
	if _room_map == null or _body == null:
		return INVALID_GRID_POSITION
	var footprint := _get_actor_grid_footprint()
	var center_cell := _room_map.world_to_grid(_body.global_position)
	return center_cell - Vector2i(floori(float(footprint.x) * 0.5), floori(float(footprint.y) * 0.5))


func _get_nearest_walkable_top_left_to_world_position(world_position: Vector2) -> Vector2i:
	var nearest_cell := INVALID_GRID_POSITION
	var nearest_distance := INF
	if _room_map == null:
		return nearest_cell

	var grid_size := _room_map.get_grid_size()
	var footprint := _get_actor_grid_footprint()
	var max_x := grid_size.x - footprint.x
	var max_y := grid_size.y - footprint.y
	if max_x < 0 or max_y < 0:
		return nearest_cell

	for y in range(max_y + 1):
		for x in range(max_x + 1):
			var cell := Vector2i(x, y)
			if not _is_sleep_target_cell_walkable(cell, footprint):
				continue
			var center := _room_map.grid_to_world_area_center(cell, footprint)
			var distance := world_position.distance_squared_to(center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
	return nearest_cell


func _is_sleep_target_cell_walkable(cell: Vector2i, footprint: Vector2i) -> bool:
	if _room_map == null:
		return false
	if not _room_map.is_grid_area_inside(cell, footprint):
		return false
	if _furniture_placement_module != null and _furniture_placement_module.has_method("can_place_at"):
		return _furniture_placement_module.call("can_place_at", cell, footprint) == true
	return true


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
	return Vector2i(maxi(actor_grid_footprint.x, 1), maxi(actor_grid_footprint.y, 1))


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position != INVALID_GRID_POSITION


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
